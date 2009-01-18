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
use File::Slurp;
use Getopt::ArgvFile default=>1;
use Getopt::Long;
use LWP::UserAgent;
use Path::Class;
use Parse::CPAN::Authors;
use Template;
use Time::Piece;
use version;

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

# -------------------------------------
# The Public Interface Functions

=head1 FUNCTIONS

=head2 Public Interface Functions

=over 4

=item * init_options

=item * check_reports

=item * check_counts

=back

=cut

sub init_options {
    GetOptions( \%options,
        'config=s',
        'debug',
        'help|h',
        'version|v'
    );

    _help(1)    if($options{help});
    _help(0)    if($options{version});

    die "Configuration file [$options{config}] not found\n" unless(-f $options{config});

    # load configuration
    my $cfg = Config::IniFiles->new( -file => $options{config} );

    # configure databases
    for my $db (qw(CPANSTATS CPANPREFS)) {
        die "No configuration for $db database\n"   unless($cfg->SectionExists($db));
        my %opts = map {$_ => $cfg->val($db,$_);} qw(driver database dbfile dbhost dbport dbuser dbpass);
        $options{$db} = CPAN::Testers::Common::DBUtils->new(%opts);
        die "Cannot configure $db database\n" unless($options{$db});
    }

    $config{DEBUG} = $options{debug} || $cfg->val('SETTINGS','DEBUG');

    $options{pause} = download_mailrc();

    # set up API to Template Toolkit
    $options{tt} = Template->new(
        {
            #    POST_CHOMP => 1,
            #    PRE_CHOMP => 1,
            #    TRIM => 1,
            EVAL_PERL    => 1,
            INCLUDE_PATH => [ 'templates' ],
        }
    );
}

sub check_reports {
    my $last_id = int( get_lastid() );
    my (%reports,%tvars);

    # find all reports since last update
    my $rows = $options{CPANSTATS}->iterator('hash',$phrasebook{'GetReports'},$last_id);
    return  unless($rows);

    while( my $row = $rows->()) {
        $counts{REPORTS}++;
        $last_id = $row->{id};
        $row->{state} = uc $row->{state};
        $counts{$row->{state}}++;
        my $author = get_author($row->{dist}, $row->{version}) || next;

        $row->{version}  ||= '';
        $row->{platform} ||= '';
        $row->{perl}     ||= '';

        # get author preferences
        my $prefs  = get_prefs($author) || next;

        # do we need to worry about this author?
        if($prefs->{active} == 2) {
            $counts{NOMAIL}++;
            next;
        }

        # get distribution preferences
        $prefs  = get_prefs($author, $row->{dist})    || next;
        next    if($prefs->{ignored});
        next    if($prefs->{report} != $REPORT_TYPE);
        next    unless($prefs->{grades}{$row->{state}});

        # check whether only first instance required
        if($prefs->{tuple} eq 'FIRST') {
            my @count = $options{CPANSTATS}->get_query('array',$phrasebook{'GetReportCount'}, $row->{platform}, $row->{perl}, $row->{state}, $row->{id});
            next    if(@count > 1);
        }

        # Check whether distribution version is required.
        # If version set to 'LATEST' check this is the current version, if set
        # to 'ALL' then we should allow EVERYTHING through, otherwise filter
        # on the requested versions.

        if($prefs->{version} && $prefs->{version} ne 'ALL') {
            if($prefs->{version} eq 'LATEST') {
                my @vers = $options{CPANSTATS}->get_query('array',$phrasebook{'GetLatestDistVers'},$row->{dist});
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

    for my $author (keys %reports) {
        my $pause = $options{pause}->author($author);
        $tvars{name}   = $pause ? $pause->name : $author;
        $tvars{author} = $author;
        $tvars{dists}  = ();

        # get author preferences
        my $prefs = get_prefs($author);

        # active:
        # 0 - new author, no correspondance
        # 1 - new author, notification mailed
        # 2 - author requested no mail
        # 3 - author requested summary report

        if(!$prefs->{active} || $prefs->{active} == 0) {
            $tvars{subject} = 'Welcome to CPAN Testers';
            write_mail('notification.eml',\%tvars);
            $options{CPANPREFS}->do_query($phrasebook{'InsertAuthorLogin'}, time(), $author);
            $options{CPANPREFS}->do_query($phrasebook{'InsertDistPrefs'}, $author, '-');
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

        $tvars{dists}   = \@e;
        $tvars{subject} = 'CPAN Testers Daily Report';

        write_mail('mailer.eml',\%tvars);
    }

    get_lastid($last_id);
}

sub check_counts {
    printf( "COUNT: %s\n", emaildate());
    printf( "%7s = %6d\n", $_, $counts{$_} )    for(keys %counts);
}

# -------------------------------------
# The Internal Interface Functions

=head2 Internal Interface Functions

=over 4

=item * help

=item * get_lastid

=item * get_author

=item * get_prefs

=item * parse_prefs

=item * write_mail

=item * emaildate

=item * download_mailrc

=back

=cut

sub _help {
    my $full = shift;

    if($full) {
        print <<HERE;

Usage: $0 \\
         [-config=<file>] [-h] [-v]

  --config=<file>   database configuration file
  -h                this help screen
  -v                program version

HERE

    }

    print "$0 v$VERSION\n";
    exit(0);
}

sub get_lastid {
    my $id = shift;

    overwrite_file( LASTMAIL, 0 ) unless -f LASTMAIL;

    if ($id) {
        overwrite_file( LASTMAIL, $id );
    } else {
        my $id = read_file(LASTMAIL);
        return $id;
    }
}

sub get_author {
    my ($dist,$vers) = @_;
    return  unless($dist && $vers);

    unless($authors{$dist} && $authors{$dist}{$vers}) {
        my @author = $options{CPANSTATS}->get_query('array',$phrasebook{'GetAuthor'}, $dist, $vers);
        $authors{$dist}{$vers} = @author ? $author[0]->[0] : undef;
    }
    return $authors{$dist}{$vers};
}


sub get_prefs {
    my ($author,$dist) = @_;
    my $active = 0;

    # get distribution defaults
    if($author && $dist) {
        if(defined $prefs{$author}{dists}{$dist}) {
            return $prefs{$author}{dists}{$dist};
        }

        my @rows = $options{CPANPREFS}->get_query('hash',$phrasebook{'GetDistPrefs'}, $author,$dist);
        if(@rows) {
            $prefs{$author}{dists}{$dist} = parse_prefs($rows[0]);
            return $prefs{$author}{dists}{$dist};
        }

        # fall through and assume author defaults
    }

    # get author defaults
    if($author) {
        if(defined $prefs{$author}{default}) {
            return $prefs{$author}{default};
        }

        my @auth = $options{CPANPREFS}->get_query('hash',$phrasebook{'GetAuthorPrefs'}, $author);
        if(@auth) {
            $prefs{$author}{default}{active} = $auth[0]->{active} || 0;

            my @rows = $options{CPANPREFS}->get_query('hash',$phrasebook{'GetDefaultPrefs'}, $author);
            if(@rows) {
                $prefs{$author}{default} = parse_prefs($rows[0]);
                $prefs{$author}{default}{active} = $rows[0]->{active} || 0;
                return $prefs{$author}{default};
            } else {
                $options{CPANPREFS}->do_query($phrasebook{'InsertDistPrefs'}, $author, '-');
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

sub parse_prefs {
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

sub write_mail {
    my ($template,$parms) = @_;
    my ($text);

    my $subject = $parms->{subject} || 'CPAN Testers Daily Reports';

    $counts{MAILS}++;
#print "$parms->{author} - $subject\n";
#return;

    my $DATE = emaildate();
    $DATE =~ s/\s+$//;

    $options{tt}->process( $template, $parms, \$text ) || die $options{tt}->error;

    my $cmd = qq!| $HOW $parms->{author}\@cpan.org!;
    my $body = $HEAD . $text;
    $body =~ s/NAME/$parms->{name}/g;
    $body =~ s/EMAIL/$parms->{author}\@cpan.org/g;
    $body =~ s/DATE/$DATE/g;
    $body =~ s/SUBJECT/$subject/g;

    if($config{DEBUG}) {
        print "TEST: $parms->{author}\n";
        return;
    }

    if(my $fh = IO::File->new($cmd)) {
        print $fh $body;
        $fh->close;
        print "GOOD: $parms->{author}\n";
    } else {
        print "BAD:  $parms->{author}\n";
    }
}

sub emaildate {
    my $t = localtime;
    return $t->strftime("%a, %d %b %Y %H:%M:%S +0000");
}

sub download_mailrc {
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

  Copyright (C) 2008 Barbie for Miss Barbell Productions.

  This module is free software; you can redistribute it and/or
  modify it under the same terms as Perl itself.

=cut
