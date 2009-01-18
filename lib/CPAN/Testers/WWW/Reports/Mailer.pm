package CPAN::Testers::WWW::Reports::Mailer;

use warnings;
use strict;

use vars qw($VERSION);
$VERSION = '0.11';

=head1 NAME

CPAN::Testers::WWW::Reports::Mailer - CPAN Testers Reports Mailer

=head1 SYNOPSIS

  use CPAN::Testers::WWW::Reports::Mailer;

  # TO BE COMPLETED

=head1 DESCRIPTION

The CPAN Testers Reports Mailer takes the preferences set within the CPANPREFS
database, and uses them to filter out reports that the author does or does not
wish to be made aware of.

New authors are added to the system as a report for their first reported
distribution is submitted by a tester. Default settings are applied in the
first instance, with the author able to update these via the preferences
website.

Initially only a Daily Summary Report is available, in time a Weekly Summary
Report and the individual reports will also be available.

=cut

# -------------------------------------
# Library Modules

use Compress::Zlib;
use Config::IniFiles;
use CPAN::Testers::Common::DBUtils;
use File::Basename;
use File::Path;
use File::Slurp;
use Getopt::ArgvFile default=>1;
use Getopt::Long;
use LWP::UserAgent;
use Path::Class;
use Parse::CPAN::Authors;
use Template;
use Time::Piece;
use version;

use base qw(Class::Accessor::Chained::Fast);

# -------------------------------------
# Variables

# force default configuration into debug mode
my %config = (DEBUG => 1);

my (%options,%authors,%prefs,%counts);

use constant    LASTMAIL            => '_lastmail';
use constant    DAILY_SUMMARY       => 1;
use constant    WEEKLY_SUMMARY      => 2;
use constant    INDIVIDUAL_REPORTS  => 3;

my $REPORT_TYPE = DAILY_SUMMARY;

my $HOW  = '/usr/sbin/sendmail -bm';
my $HEAD = 'To: "NAME" <EMAIL>
From: CPAN Tester Report Server <do_not_reply@cpantesters.org>
Date: DATE
Subject: SUBJECT

';

my @dotw = (    "Sunday",   "Monday", "Tuesday", "Wednesday",
                "Thursday", "Friday", "Saturday" );

my @months = (
        { 'id' =>  1,   'value' => "January",   },
        { 'id' =>  2,   'value' => "February",  },
        { 'id' =>  3,   'value' => "March",     },
        { 'id' =>  4,   'value' => "April",     },
        { 'id' =>  5,   'value' => "May",       },
        { 'id' =>  6,   'value' => "June",      },
        { 'id' =>  7,   'value' => "July",      },
        { 'id' =>  8,   'value' => "August",    },
        { 'id' =>  9,   'value' => "September", },
        { 'id' => 10,   'value' => "October",   },
        { 'id' => 11,   'value' => "November",  },
        { 'id' => 12,   'value' => "December"   },
);

my %phrasebook = (
    'GetReports'        => "SELECT id,dist,version,platform,perl,state FROM cpanstats WHERE id > ? AND state IN ('pass','fail','na','unknown') ORDER BY id",
    'GetReportCount'    => "SELECT id FROM cpanstats WHERE platform=? AND perl=? AND state=? AND id < ? LIMIT 2",
    'GetLatestDistVers' => "SELECT version FROM cpanstats WHERE dist=? AND state='cpan' ORDER BY id DESC LIMIT 1",
    'GetAuthor'         => "SELECT tester FROM cpanstats WHERE dist=? AND version=? AND state='cpan' LIMIT 1",

    'GetAuthorPrefs'    => "SELECT * FROM prefs_authors WHERE pauseid=?",
    'GetDefaultPrefs'   => "SELECT * FROM prefs_authors AS a INNER JOIN prefs_distributions AS d ON d.pauseid=a.pauseid AND d.distribution='-' WHERE a.pauseid=?",
    'GetDistPrefs'      => "SELECT * FROM prefs_distributions WHERE pauseid=? AND distribution=?",
    'InsertAuthorLogin' => 'INSERT INTO prefs_authors (active,lastlogin,pauseid) VALUES (1,?,?)',
    'InsertDistPrefs'   => "INSERT INTO prefs_distributions (pauseid,distribution,ignored,report,grade,tuple,version,patches,perl,platform) VALUES (?,?,0,1,'FAIL','FIRST','LATEST',0,'ALL','ALL')",
);

#----------------------------------------------------------------------------
# The Application Programming Interface

__PACKAGE__->mk_accessors(
    qw( debug logfile logclean tt pause ));

# -------------------------------------
# The Public Interface Functions

=head1 INTERFACE

=head2 The Constructor

=over

=item * new

Instatiates the object CPAN::WWW::Testers. Requires a hash of parameters, with
'config' being the only mandatory key. Note that 'config' can be anything that
L<Config::IniFiles> accepts for the I<-file> option.

=back

=cut

sub new {
    my $class = shift;
    my %hash  = @_;

    my $self = {};
    bless $self, $class;

    GetOptions( \%options,
        'config=s',
        'logfile=s',
        'logclean',
        'debug',
        'help|h',
        'version|v'
    );

    $self->help(1)    if($options{help});
    $self->help(0)    if($options{version});

    # ensure we have a configuration file
    my $config = $self->_defined_or($options{config}, $hash{config});
    die "Must specify a configuration file\n"       unless($config);
    die "Configuration file [$config] not found\n"  unless(-f $config);

    # load configuration
    my $cfg = Config::IniFiles->new( -file => $config );

    # configure databases
    for my $db (qw(CPANSTATS CPANPREFS)) {
        die "No configuration for $db database\n"   unless($cfg->SectionExists($db));
        my %opts = map {$_ => $cfg->val($db,$_);} qw(driver database dbfile dbhost dbport dbuser dbpass);
        $self->{$db} = CPAN::Testers::Common::DBUtils->new(%opts);
        die "Cannot configure $db database\n" unless($self->{$db});
    }

    $self->debug(   $self->_defined_or( $options{debug},    $hash{debug},    $cfg->val('SETTINGS','DEBUG'    ) ) );
    $self->logfile( $self->_defined_or( $options{logfile},  $hash{logfile},  $cfg->val('SETTINGS','logfile'  ) ) );
    $self->logclean($self->_defined_or( $options{logclean}, $hash{logclean}, $cfg->val('SETTINGS','logclean' ), 0 ) );

    $self->pause (_download_mailrc());

    # set up API to Template Toolkit
    $self->tt( Template->new(
        {
            EVAL_PERL    => 1,
            INCLUDE_PATH => [ 'templates' ],
        }
    ));

    return $self;
}

=head2 Methods

=over

=item * check_reports

=item * check_counts

=item * help

=back

=cut

sub check_reports {
    my $self = shift;
    my $last_id = int( $self->_get_lastid() );
    my (%reports,%tvars);

    $self->_log( "INFO: START checking reports\n" );
    $self->_log( "INFO: last_id=$last_id\n" );

    # find all reports since last update
    my $rows = $self->{CPANSTATS}->iterator('hash',$phrasebook{'GetReports'},$last_id);
    unless($rows) {
        $self->_log( "INFO: STOP checking reports\n" );
        return;
    }

    while( my $row = $rows->()) {
        $self->_log( "DEBUG: processing report: $row->{id}\n" )    if($self->debug);

        $counts{REPORTS}++;
        $last_id = $row->{id};
        $row->{state} = uc $row->{state};
        $counts{$row->{state}}++;
        my $author = $self->_get_author($row->{dist}, $row->{version}) || next;

        $row->{version}  ||= '';
        $row->{platform} ||= '';
        $row->{perl}     ||= '';

        # get author preferences
        my $prefs  = $self->_get_prefs($author) || next;

        # do we need to worry about this author?
        if($prefs->{active} == 2) {
            $counts{NOMAIL}++;
            next;
        }

        # get distribution preferences
        $prefs  = $self->_get_prefs($author, $row->{dist})    || next;
        next    if($prefs->{ignored});
        next    if($prefs->{report} != $REPORT_TYPE);
        next    unless($prefs->{grades}{$row->{state}});

        # check whether only first instance required
        if($prefs->{tuple} eq 'FIRST') {
            my @count = $self->{CPANSTATS}->get_query('array',$phrasebook{'GetReportCount'}, $row->{platform}, $row->{perl}, $row->{state}, $row->{id});
            next    if(@count > 1);
        }

        # Check whether distribution version is required.
        # If version set to 'LATEST' check this is the current version, if set
        # to 'ALL' then we should allow EVERYTHING through, otherwise filter
        # on the requested versions.

        if($prefs->{version} && $prefs->{version} ne 'ALL') {
            if($prefs->{version} eq 'LATEST') {
                my @vers = $self->{CPANSTATS}->get_query('array',$phrasebook{'GetLatestDistVers'},$row->{dist});
                next    if(@vers && $vers[0]->[0] ne $row->{version});
            } else {
                $prefs->{version} =~ s/\s*//g;
                my %m = map {$_ => 1} split(',',$prefs->{version});
                next    unless($m{$row->{version}});
            }
        }

        # Check whether this platform is required.
        if($prefs->{platform} && $prefs->{platform} ne 'ALL') {
            $prefs->{platform} =~ s/\s*//g;
            $prefs->{platform} =~ s/,/|/g;
            $prefs->{platform} =~ s/\./\\./g;
            $prefs->{platform} =~ s/^(\w+)\|//;
            if($1 eq 'NOT') {
                next    if($row->{platform} =~ /$prefs->{platform}/);
            } else {
                next    if($row->{platform} !~ /$prefs->{platform}/);
            }
        }

        # Check whether this perl version is required.
        if($prefs->{perl} && $prefs->{perl} ne 'ALL') {
            $prefs->{perl} =~ s/\s*//g;
            $prefs->{perl} =~ s/,/|/g;
            $prefs->{perl} =~ s/\./\\./g;
            my $v = version->new("$row->{perl}")->numify;
            $prefs->{platform} =~ s/^(\w+)\|//;
            if($1 eq 'NOT') {
                next    if($row->{perl} =~ /$prefs->{perl}/ && $v =~ /$prefs->{perl}/);
            } else {
                next    if($row->{perl} !~ /$prefs->{perl}/ && $v !~ /$prefs->{perl}/);
            }
        }

        # Check whether patches are required.
        next    if(!$prefs->{patches} && $row->{perl} =~ /patch/);

        push @{$reports{$author}->{dists}{$row->{dist}}->{versions}{$row->{version}}->{platforms}{$row->{platform}}->{perls}{$row->{perl}}->{states}{uc $row->{state}}->{value}}, $row->{id};
    }

    $self->_log( "DEBUG: processing authors: ".(scalar(keys %reports))."\n" )  if($self->debug);

    for my $author (sort keys %reports) {
        $self->_log( "DEBUG: processing mail for author: $author\n" )    if($self->debug);

        my $pause = $$self->pause->author($author);
        $tvars{name}   = $pause ? $pause->name : $author;
        $tvars{author} = $author;
        $tvars{dists}  = ();

        # get author preferences
        my $prefs = $self->_get_prefs($author);

        # active:
        # 0 - new author, no correspondance
        # 1 - new author, notification mailed
        # 2 - author requested no mail
        # 3 - author requested summary report

        if(!$prefs->{active} || $prefs->{active} == 0) {
            $tvars{subject} = 'Welcome to CPAN Testers';
            $self->_write_mail('notification.eml',\%tvars);
            $self->{CPANPREFS}->do_query($phrasebook{'InsertAuthorLogin'}, time(), $author);
            $self->{CPANPREFS}->do_query($phrasebook{'InsertDistPrefs'}, $author, '-');
        }

        my ($reports,@e);
        for my $dist (keys %{$reports{$author}->{dists}}) {
            my $v = $reports{$author}->{dists}{$dist};
            my @d;
            for my $version (keys %{$v->{versions}}) {
                my $w = $v->{versions}{$version};
                my @c;
                for my $platform (keys %{$w->{platforms}}) {
                    my $x = $w->{platforms}{$platform};
                    my @b;
                    for my $perl (keys %{$x->{perls}}) {
                        my $y = $x->{perls}{$perl};
                        my @a;
                        for my $state (keys %{$y->{states}}) {
                            my $z = $y->{states}{$state};
                            push @a, {state => $state, ids => $z->{value}};
                            $reports++;
                        }
                        push @b, {perl => $perl, states => \@a};
                    }
                    push @c, {platform => $platform, perls => \@b};
                }
                push @d, {version => $version, platforms => \@c};
            }
            push @e, {dist => $dist, versions => \@d};
        }

        next    unless($reports);
        $self->_log( "DEBUG: reports for author: $author = $reports\n" )   if($self->debug);

        $tvars{dists}   = \@e;
        $tvars{subject} = 'CPAN Testers Daily Report';

        $self->_write_mail('mailer.eml',\%tvars);
    }

    $self->_get_lastid($last_id);
    $self->_log( "INFO: STOP checking reports\n" );
}

sub check_counts {
    my $self = shift;
    $self->_log( "INFO: COUNTS:\n" );
    $self->_log( sprintf "INFO: %7s = %6d\n", $_, $counts{$_} )    for(keys %counts);
}

sub help {
    my $self = shift;
    my $full = shift;

    if($full) {
        print <<HERE;

Usage: $0 --config=<file> \\
         [--logfile=<file> [--logclean]] [--debug] [-h] [-v]

  --config=<file>   database configuration file
  --logfile=<file>  log file
  --logclean        0 = append, 1 = overwrite
  --debug           debug mode, no mail sent
  -h                this help screen
  -v                program version

HERE

    }

    print "$0 v$VERSION\n";
    exit(0);
}

#----------------------------------------------------------------------------
# Internal Methods

=head2 Internal Methods

=over 4

=item * _get_lastid

=item * _get_author

=item * _get_prefs

=item * _parse_prefs

=item * _write_mail

=item * _emaildate

=item * _download_mailrc

=back

=cut

sub _get_lastid {
    my $self = shift;
    my $id = shift;

    overwrite_file( LASTMAIL, 0 ) unless -f LASTMAIL;

    if ($id) {
        overwrite_file( LASTMAIL, $id );
    } else {
        my $id = read_file(LASTMAIL);
        return $id;
    }
}

sub _get_author {
    my $self = shift;
    my ($dist,$vers) = @_;
    return  unless($dist && $vers);

    unless($authors{$dist} && $authors{$dist}{$vers}) {
        my @author = $self->{CPANSTATS}->get_query('array',$phrasebook{'GetAuthor'}, $dist, $vers);
        $authors{$dist}{$vers} = @author ? $author[0]->[0] : undef;
    }
    return $authors{$dist}{$vers};
}


sub _get_prefs {
    my $self = shift;
    my ($author,$dist) = @_;
    my $active = 0;

    # get distribution defaults
    if($author && $dist) {
        if(defined $prefs{$author}{dists}{$dist}) {
            return $prefs{$author}{dists}{$dist};
        }

        my @rows = $self->{CPANPREFS}->get_query('hash',$phrasebook{'GetDistPrefs'}, $author,$dist);
        if(@rows) {
            $prefs{$author}{dists}{$dist} = $self->_parse_prefs($rows[0]);
            return $prefs{$author}{dists}{$dist};
        }

        # fall through and assume author defaults
    }

    # get author defaults
    if($author) {
        if(defined $prefs{$author}{default}) {
            return $prefs{$author}{default};
        }

        my @auth = $self->{CPANPREFS}->get_query('hash',$phrasebook{'GetAuthorPrefs'}, $author);
        if(@auth) {
            $prefs{$author}{default}{active} = $auth[0]->{active} || 0;

            my @rows = $self->{CPANPREFS}->get_query('hash',$phrasebook{'GetDefaultPrefs'}, $author);
            if(@rows) {
                $prefs{$author}{default} = $self->_parse_prefs($rows[0]);
                $prefs{$author}{default}{active} = $rows[0]->{active} || 0;
                return $prefs{$author}{default};
            } else {
                $self->{CPANPREFS}->do_query($phrasebook{'InsertDistPrefs'}, $author, '-');
                $active = $prefs{$author}{default}{active};
            }
        }

        # fall through and assume new author
    }

    # use global defaults
    my %prefs = (
            active      => $active,
            ignored     => 0,
            report      => 1,
            grades      => {'FAIL' => 1},
            tuple       => 'FIRST',
            version     => 'LATEST',
            patches     => 0,
            perl        => 'ALL',
            platform    => 'ALL',
        );
    return \%prefs;
}

sub _parse_prefs {
    my $self = shift;
    my $row = shift;
    my %hash;

    $row->{grade} ||= 'FAIL';
    my %grades = map {$_ => 1} split(',',$row->{grade});

    $hash{grades}   = \%grades;
    $hash{ignored}  = $row->{ignored}   || 0;
    $hash{report}   = $row->{report}    || 1;
    $hash{tuple}    = $row->{tuple}     || 'FIRST';
    $hash{version}  = $row->{version}   || 'LATEST';
    $hash{patches}  = $row->{patches}   || 0;
    $hash{perl}     = $row->{perl}      || 'ALL';
    $hash{platform} = $row->{platform}  || 'ALL';

    return \%hash;
}

sub _write_mail {
    my $self = shift;
    my ($template,$parms) = @_;
    my ($text);

    my $subject = $parms->{subject} || 'CPAN Testers Daily Reports';

    $counts{MAILS}++;
#print "$parms->{author} - $subject\n";
#return;

    my $DATE = $self->_emaildate();
    $DATE =~ s/\s+$//;

    $self->tt->process( $template, $parms, \$text ) || die $self->tt->error;

    my $cmd = qq!| $HOW $parms->{author}\@cpan.org!;
    my $body = $HEAD . $text;
    $body =~ s/NAME/$parms->{name}/g;
    $body =~ s/EMAIL/$parms->{author}\@cpan.org/g;
    $body =~ s/DATE/$DATE/g;
    $body =~ s/SUBJECT/$subject/g;

    if($self->debug) {
        $self->_log( "INFO: TEST: $parms->{author}\n" );
        return;
    }

    if(my $fh = IO::File->new($cmd)) {
        print $fh $body;
        $fh->close;
        $self->_log( "INFO: GOOD: $parms->{author}\n" );
    } else {
        $self->_log( "INFO: BAD:  $parms->{author}\n" );
    }
}

sub _emaildate {
    my $self = shift;
    my $t = localtime;
    return $t->strftime("%a, %d %b %Y %H:%M:%S +0000");
}

sub _download_mailrc {
    my $self = shift;
    my $data;

    if(-f 'data/01mailrc.txt') {
        $data = read_file('data/01mailrc.txt');

    } else {
        my $url = 'http://www.cpan.org/authors/01mailrc.txt.gz';
        my $ua  = LWP::UserAgent->new;
        $ua->timeout(180);
        my $response = $ua->get($url);

        if ($response->is_success) {
            my $gzipped = $response->content;
            $data = Compress::Zlib::memGunzip($gzipped);
            die "Error uncompressing data from $url" unless $data;
        } else {
            die "Error fetching $url";
        }
    }

    my $p = Parse::CPAN::Authors->new($data);
    die "Cannot parse data from 01mailrc.txt"   unless($p);
    return $p;
}

sub _log {
    my $self = shift;
    my $log = $self->logfile or return;
    mkpath(dirname($log))   unless(-f $log);

    my $t = localtime;
    my $s = $t->strftime("%Y/%m/%d %H:%M:%S");

    my $mode = $self->logclean ? 'w+' : 'a+';
    $self->logclean(0);

    my $fh = IO::File->new($log,$mode) or die "Cannot write to log file [$log]: $!\n";
    print $fh "$s: " . join(' ', @_);
    $fh->close;
}

sub _defined_or {
    my $self = shift;
    while(@_) {
        my $value = shift;
        return $value   if(defined $value);
    }

    return;
}

1;

__END__

=head1 SEE ALSO

L<CPAN::WWW::Testers::Generator>
L<CPAN::WWW::Testers>
L<CPAN::Testers::WWW::Statistics>

F<http://www.cpantesters.org/>,
F<http://stats.cpantesters.org/>,
F<http://wiki.cpantesters.org/>

=head1 BUGS, PATCHES & FIXES

There are no known bugs at the time of this release. However, if you spot a
bug or are experiencing difficulties, that is not explained within the POD
documentation, please send bug reports and patches to the RT Queue (see below).

Fixes are dependant upon their severity and my availablity. Should a fix not
be forthcoming, please feel free to (politely) remind me.

RT Queue -
http://rt.cpan.org/Public/Dist/Display.html?Name=CPAN-Testers-WWW-Reports-Mailer

=head1 AUTHOR

Barbie, <barbie@missbarbell.co.uk> for
Miss Barbell Productions, L<http://www.missbarbell.co.uk/>

=head1 COPYRIGHT & LICENSE

  Copyright (C) 2008-2009 Barbie for Miss Barbell Productions.

  This module is free software; you can redistribute it and/or
  modify it under the same terms as Perl itself.

=cut
