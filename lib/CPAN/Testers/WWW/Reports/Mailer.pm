package CPAN::Testers::WWW::Reports::Mailer;

use warnings;
use strict;

use vars qw($VERSION);
$VERSION = '0.26';

=head1 NAME

CPAN::Testers::WWW::Reports::Mailer - CPAN Testers Reports Mailer

=head1 SYNOPSIS

  use CPAN::Testers::WWW::Reports::Mailer;

  my $mailer = CPAN::Testers::WWW::Reports::Mailer->new(
    config => 'myconfig.ini'
  );

  $mailer->check_reports();
  $mailer->check_counts();

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

=head1 CONFIGURATION

Configuration for this application can occur via the command line, the API and
the configuration file. Of them all, only the configuration file is required.

The configuration file should be in the INI style, with the sections CPANSTATS
and CPANPREFS describing the associated database access required. The general
settings section, SETTINGS, is optional, and can be overridden by the command
line and the API arguments.

=head2 Database Configuration

The CPANSTATS and CPANPREFS sections are required, and should contain the
following key/value pairs to describe access to the specific database.

=over 4

=item * driver

=item * database

=item * dbhost

=item * dbport

=item * dbuser

=item * dbpass

=back

Only 'driver' and 'database' are required for an SQLite database, while the
other key/values may need to be completed for other databases.

=head2 General Configuration

The following options are available, in the configuration file, on the command
line and via the API call to new() as a hash.

=over 4

=item * mode

Processing mode required. This can be one of three values, 'daily', 'weekly' or
'reports'. 'daily' and 'weekly' create the mails for the Daily Summary and
Weekly Summary reports respectively. 'reports' creates individual report mails
for authors.

=item * verbose

If set to a true value, will print additional log messages.

=item * nomail

By default this is set to 1, to avoid accidentally running and sending lots of
mails :) Set to 0 to allow normal processing.

=item * test

If used, must be set to a single NNTPID, which will then be tested in isolation
for the currently set mode. Automatically sets the nomail flag to true.

=item * lastmail

The location of the counter file, that stores the ids of the last reports
processed.

=item * mailrc

The location of the 01mailrc.txt file stored locally. By default the location
is assumed to be 'data/01mailrc.txt'. If the confirguration is not set, or the
file cannot be found, it will be dynamically downloaded from CPAN.

=item * logfile

The location of the logfile. If not provided, logging is disabled.

=item * logclean

By default this is set to 0, append to existing log. If set to 1, will create
a new log or overwrite any existing log, on the first call to log a message,
then will automatically reset to 0, so as to append any further messages.

=back

=cut

# -------------------------------------
# Library Modules

use Compress::Zlib;
use Config::IniFiles;
use CPAN::Testers::Common::DBUtils;
use Email::Address;
use Email::Simple;
use File::Basename;
use File::Path;
use File::Slurp;
use Getopt::ArgvFile default=>1;
use Getopt::Long;
use LWP::UserAgent;
use MIME::Base64;
use MIME::QuotedPrint;
use Path::Class;
use Parse::CPAN::Authors;
use Template;
use Time::Piece;
use version;

use base qw(Class::Accessor::Fast);

# -------------------------------------
# Variables

# default configuration settings
my %default = (
    lastmail    => '_lastmail',
    verbose     => 0,
    nomail      => 1,
    logclean    => 0,
    mode        => 'daily',
    mailrc      => 'data/01mailrc.txt'
);

my (%AUTHORS,%PREFS);

my %MODES = (
    daily   => { type =>  1, period => '24 hours', report => 'Daily Summary'   },
    weekly  => { type =>  2, period => '7 days',   report => 'Weekly Summary'  },   # typically a Saturday
    reports => { type =>  3, period => '',         report => 'Test'            },
    monthly => { type =>  4, period => 'month',    report => 'Monthly Summary' },
    sun     => { type =>  5, period => '7 days',   report => 'Weekly Summary'  },
    mon     => { type =>  6, period => '7 days',   report => 'Weekly Summary'  },
    tue     => { type =>  7, period => '7 days',   report => 'Weekly Summary'  },
    wed     => { type =>  8, period => '7 days',   report => 'Weekly Summary'  },
    thu     => { type =>  9, period => '7 days',   report => 'Weekly Summary'  },
    fri     => { type => 10, period => '7 days',   report => 'Weekly Summary'  },
    sat     => { type => 11, period => '7 days',   report => 'Weekly Summary'  },
);

my $FROM    = 'CPAN Tester Report Server <do_not_reply@cpantesters.org>';
my $HOW     = '/usr/sbin/sendmail -bm';
my $HEAD    = 'To: "NAME" <EMAIL>
From: FROM
Date: DATE
Subject: SUBJECT

';

my @dotw = (    "Sunday",   "Monday", "Tuesday", "Wednesday",
                "Thursday", "Friday", "Saturday" );

my @months = (
        { 'id' =>  1, 'value' => "January",   },
        { 'id' =>  2, 'value' => "February",  },
        { 'id' =>  3, 'value' => "March",     },
        { 'id' =>  4, 'value' => "April",     },
        { 'id' =>  5, 'value' => "May",       },
        { 'id' =>  6, 'value' => "June",      },
        { 'id' =>  7, 'value' => "July",      },
        { 'id' =>  8, 'value' => "August",    },
        { 'id' =>  9, 'value' => "September", },
        { 'id' => 10, 'value' => "October",   },
        { 'id' => 11, 'value' => "November",  },
        { 'id' => 12, 'value' => "December"   },
);

my %phrasebook = (
    'LastReport'        => "SELECT MAX(id) FROM cpanstats",
    'GetEarliest'       => "SELECT id FROM cpanstats WHERE fulldate > ? ORDER BY id LIMIT 1",

    'FindAuthorType'    => "SELECT pauseid FROM prefs_distributions WHERE report = ?",

    'GetReports'        => "SELECT id,dist,version,platform,perl,state FROM cpanstats WHERE id > ? AND state IN ('pass','fail','na','unknown') ORDER BY id",
    'GetReports2'       => "SELECT c.id,c.dist,c.version,c.platform,c.perl,c.state FROM cpanstats AS c INNER JOIN ixlatest AS x ON x.dist=c.dist WHERE c.id > ? AND c.state IN ('pass','fail','na','unknown') AND author IN (%s) ORDER BY id",
    'GetReportCount'    => "SELECT id FROM cpanstats WHERE platform=? AND perl=? AND state=? AND id < ? AND dist=? AND version=? LIMIT 2",
    'GetLatestDistVers' => "SELECT version FROM cpanstats WHERE dist=? AND state='cpan' ORDER BY id DESC LIMIT 1",
    'GetAuthor'         => "SELECT tester FROM cpanstats WHERE dist=? AND version=? AND state='cpan' LIMIT 1",

    'GetAuthorPrefs'    => "SELECT * FROM prefs_authors WHERE pauseid=?",
    'GetDefaultPrefs'   => "SELECT * FROM prefs_authors AS a INNER JOIN prefs_distributions AS d ON d.pauseid=a.pauseid AND d.distribution='-' WHERE a.pauseid=?",
    'GetDistPrefs'      => "SELECT * FROM prefs_distributions WHERE pauseid=? AND distribution=?",
    'InsertAuthorLogin' => 'INSERT INTO prefs_authors (active,lastlogin,pauseid) VALUES (1,?,?)',
    'InsertDistPrefs'   => "INSERT INTO prefs_distributions (pauseid,distribution,ignored,report,grade,tuple,version,patches,perl,platform) VALUES (?,?,0,1,'FAIL','FIRST','LATEST',0,'ALL','ALL')",

    'GetArticle'        => "SELECT * FROM articles WHERE id=?",

    'GetReportTest'     => "SELECT id,dist,version,platform,perl,state FROM cpanstats WHERE id = ? AND state IN ('pass','fail','na','unknown') ORDER BY id",
);

#----------------------------------------------------------------------------
# The Application Programming Interface

__PACKAGE__->mk_accessors(
    qw( lastmail verbose nomail test logfile logclean mode mailrc tt pause ));

# -------------------------------------
# The Public Interface Functions

sub new {
    my $class = shift;
    my %hash  = @_;

    my $self = {};
    bless $self, $class;

    my %options;
    GetOptions( \%options,
        'config=s',
        'lastmail=s',
        'mailrc=s',
        'test=i',
        'logfile=s',
        'logclean',
        'verbose',
        'nomail',
        'mode=s',
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
    for my $db (qw(CPANSTATS CPANPREFS ARTICLES)) {
        die "No configuration for $db database\n"   unless($cfg->SectionExists($db));
        my %opts;
        for my $key (qw(driver database dbfile dbhost dbport dbuser dbpass)) {
            my $val = $cfg->val($db,$key);
            $opts{$key} = $val  if(defined $val);
        }
        $self->{$db} = CPAN::Testers::Common::DBUtils->new(%opts);
        die "Cannot configure $db database\n" unless($self->{$db});
    	$self->{db}->{mysql_auto_reconnect} = 1	if($opts{driver} =~ /mysql/i);
    }

    $self->test(    $self->_defined_or( $options{test},     $hash{test},     $cfg->val('SETTINGS','test'  ), 0 ) );
    $options{nomail} = 1 if($self->test);

    $self->verbose( $self->_defined_or( $options{verbose},  $hash{verbose},  $cfg->val('SETTINGS','verbose'  ), $default{verbose}) );
    $self->nomail(  $self->_defined_or( $options{nomail},   $hash{nomail},   $cfg->val('SETTINGS','nomail'   ), $default{nomail}) );
    $self->lastmail($self->_defined_or( $options{lastmail}, $hash{lastmail}, $cfg->val('SETTINGS','lastmail' ), $default{lastmail}) );
    $self->mailrc(  $self->_defined_or( $options{mailrc},   $hash{mailrc},   $cfg->val('SETTINGS','mailrc'   ), $default{mailrc} ) );
    $self->logfile( $self->_defined_or( $options{logfile},  $hash{logfile},  $cfg->val('SETTINGS','logfile'  ) ) );
    $self->logclean($self->_defined_or( $options{logclean}, $hash{logclean}, $cfg->val('SETTINGS','logclean' ), $default{logclean} ) );
    $self->mode(lc  $self->_defined_or( $options{mode},     $hash{mode},     $cfg->val('SETTINGS','mode'     ), $default{mode} ) );

    my $mode = $self->mode;
    if($mode =~ /day/) {
        $mode = substr($mode,0,3);
        $self->mode($mode);
    }

    unless($mode =~ /^(daily|weekly|reports|monthly|sun|mon|tue|wed|thu|fri|sat)$/) {
        die "mode can MUST be 'daily', 'weekly', 'monthly', 'reports', or a day of the week.\n";
    }

    $self->pause($self->_download_mailrc());

    # set up API to Template Toolkit
    $self->tt( Template->new(
        {
            EVAL_PERL    => 1,
            INCLUDE_PATH => [ 'templates' ],
        }
    ));

    return $self;
}

sub check_reports {
    my $self = shift;
    my $mode = $self->mode;
    my $report_type = $MODES{$mode}->{type};
    my $last_id = int( $self->_get_lastid() );
    my (%reports,%tvars);

    $self->_log( "INFO: START checking reports in '$mode' mode\n" );
    $self->_log( "INFO: last_id=$last_id\n" );

    my $next;
    if($self->test) {
        $next = $self->{CPANSTATS}->iterator('hash',$phrasebook{'GetReportTest'},$self->test);
    } elsif($mode ne 'daily') {
        my @authors = $self->{CPANPREFS}->get_query('hash',$phrasebook{'FindAuthorType'}, $report_type);
        return $self->_set_lastid()  unless(@authors);
        my $sql = sprintf $phrasebook{'GetReports2'}, join(',',map {"'$_->{pauseid}'"} @authors);
        $next = $self->{CPANSTATS}->iterator('hash',$sql,$last_id);
    } else {
        # find all reports since last update
        $next = $self->{CPANSTATS}->iterator('hash',$phrasebook{'GetReports'},$last_id);
        unless($next) {
            $self->_log( "INFO: STOP checking reports\n" );
            return;
        }
    }

    my $rows = 0;
    while( my $row = $next->()) {
        $rows++;
        $self->_log( "DEBUG: processing report: $row->{id}\n" )    if($self->verbose);

        $self->{counts}{REPORTS}++;
        $last_id = $row->{id};
        $row->{state} = uc $row->{state};
        $self->{counts}{$row->{state}}++;

        $self->_log( "DEBUG: dist: $row->{dist} $row->{version} $row->{state}\n" )    if($self->verbose);

        my $author = $self->_get_author($row->{dist}, $row->{version});
        $self->_log( "DEBUG: author: $author\n" )    if($self->verbose);
        next    unless($author);

        unless($author) {
            $self->_log( "WARN: author not found for distribution [$row->{dist}], [$row->{version}]\n" );
            next;
        }

        $row->{version}  ||= '';
        $row->{platform} ||= '';
        $row->{perl}     ||= '';

        # get author preferences
        my $prefs  = $self->_get_prefs($author) || next;

        # do we need to worry about this author?
        if($prefs->{active} == 2) {
            $self->{counts}{NOMAIL}++;
            $self->_log( "DEBUG: author: $author - not active\n" )    if($self->verbose);
            next;
        }

        # get distribution preferences
        $prefs = $self->_get_prefs($author, $row->{dist});
        $self->_log( "DEBUG: dist prefs: " .($prefs ? 'Found' : 'Not Found')."\n" )                             if($self->verbose);
        next    unless($prefs);
        $self->_log( "DEBUG: dist prefs: ignored=" .($prefs->{ignored} || 0)."\n" )                             if($self->verbose);
        next    if($prefs->{ignored});
        $self->_log( "DEBUG: dist prefs: report=$prefs->{report}, report type=$report_type\n" )                 if($self->verbose);
        next    if($prefs->{report} != $report_type);
        $self->_log( "DEBUG: dist prefs: $row->{state}=" .($prefs->{grades}{$row->{state}}||'undef')."\n" )     if($self->verbose);
        $self->_log( "DEBUG: dist prefs: ALL=" .($prefs->{grades}{ALL}||'undef')."\n" )                         if($self->verbose);
        next    unless($prefs->{grades}{$row->{state}} || $prefs->{grades}{'ALL'});
        $self->_log( "DEBUG: dist prefs: CONTINUE\n" )                                                          if($self->verbose);

        # Check whether distribution version is required.
        # If version set to 'LATEST' check this is the current version, if set
        # to 'ALL' then we should allow EVERYTHING through, otherwise filter
        # on the requested versions.

        if($row->{version} && $prefs->{version} && $prefs->{version} ne 'ALL') {
            if($prefs->{version} eq 'LATEST') {
                my @vers = $self->{CPANSTATS}->get_query('array',$phrasebook{'GetLatestDistVers'},$row->{dist});
                $self->_log( "DEBUG: dist prefs: vers=".(scalar(@vers))."\n" )                  if($self->verbose);
                $self->_log( "DEBUG: dist prefs: version=$vers[0]->[0], $row->{version}\n" )    if($self->verbose);
                next    if(@vers && $vers[0]->[0] ne $row->{version});
            } else {
                $prefs->{version} =~ s/\s*//g;
                my %m = map {$_ => 1} split(',',$prefs->{version});
                $self->_log( "DEBUG: dist prefs: $row->{version}\n" )    if($self->verbose);
                next    unless($m{$row->{version}});
            }
        }

        # Check whether this platform is required.
        if($row->{platform} && $prefs->{platform} && $prefs->{platform} ne 'ALL') {
            $prefs->{platform} =~ s/\s*//g;
            $prefs->{platform} =~ s/,/|/g;
            $prefs->{platform} =~ s/\./\\./g;
            $prefs->{platform} =~ s/^(\w+)\|//;
            if($1 && $1 eq 'NOT') {
                $self->_log( "DEBUG: dist prefs: $row->{platform}, =~ $prefs->{platform}\n" )    if($self->verbose);
                next    if($row->{platform} =~ /$prefs->{platform}/);
            } else {
                $self->_log( "DEBUG: dist prefs: $row->{platform}, !~ $prefs->{platform}\n" )    if($self->verbose);
                next    if($row->{platform} !~ /$prefs->{platform}/);
            }
        }

        # Check whether this perl version is required.
        if($row->{perl} && $prefs->{perl} && $prefs->{perl} ne 'ALL') {
            my $perlv = $row->{perl};
            $perlv = $row->{perl};

            $prefs->{perl} =~ s/\s*//g;
            $prefs->{perl} =~ s/,/|/g;
            $prefs->{perl} =~ s/\./\\./g;
            my $v = version->new("$perlv")->numify;
            $prefs->{platform} =~ s/^(\w+)\|//;
            if($1 && $1 eq 'NOT') {
                $self->_log( "DEBUG: dist prefs: $perlv || $v =~ $prefs->{perl}\n" )    if($self->verbose);
                next    if($perlv =~ /$prefs->{perl}/ && $v =~ /$prefs->{perl}/);
            } else {
                $self->_log( "DEBUG: dist prefs: $perlv || $v !~ $prefs->{perl}\n" )    if($self->verbose);
                next    if($perlv !~ /$prefs->{perl}/ && $v !~ /$prefs->{perl}/);
            }
        }

        # Check whether patches are required.
        $self->_log( "DEBUG: dist prefs: patches=$prefs->{patches}, row perl $row->{perl}\n" )    if($self->verbose);
        next    if(!$prefs->{patches} && $row->{perl} =~ /patch/);

        # check whether only first instance required
        if($prefs->{tuple} eq 'FIRST') {
            my @count = $self->{CPANSTATS}->get_query('array',$phrasebook{'GetReportCount'}, 
                $row->{platform}, $row->{perl}, $row->{state}, $row->{id}, $row->{dist}, $row->{version});
            $self->_log( "DEBUG: dist prefs: tuple=FIRST, count=".(scalar(@count))."\n" )    if($self->verbose);
            next    if(@count > 0);
        }

        $self->_log( "DEBUG: report is being added to mailshot\n" )    if($self->verbose);

        if($mode eq 'reports') {
            $self->_send_report($author,$row);
        }

        push @{$reports{$author}->{dists}{$row->{dist}}->{versions}{$row->{version}}->{platforms}{$row->{platform}}->{perls}{$row->{perl}}->{states}{uc $row->{state}}->{value}}, $row->{id};
    }

    return $self->_set_lastid()  unless($rows);

    if($mode ne 'reports') {
        $self->_log( "DEBUG: processing authors: ".(scalar(keys %reports))."\n" )  if($self->verbose);

        for my $author (sort keys %reports) {
            $self->_log( "DEBUG: $author\n" )   if($self->verbose);

            my $pause = $self->pause->author($author);
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
                $self->{counts}{NEWAUTH}++;

                # insert author defaults, however check that they don't already
                # exists in the system first, in case entries are out of sync.
                my @auth = $self->{CPANPREFS}->get_query('hash',$phrasebook{'GetAuthorPrefs'}, $author);
                $self->{CPANPREFS}->do_query($phrasebook{'InsertAuthorLogin'}, time(), $author) unless(@auth);
                my @dist = $self->{CPANPREFS}->get_query('hash',$phrasebook{'GetDistPrefs'}, $author,'-');
                $self->{CPANPREFS}->do_query($phrasebook{'InsertDistPrefs'}, $author, '-')  unless(@dist);
            }

            $self->_log( "DEBUG: $author - distributions = ".(scalar(keys %{$reports{$author}->{dists}}))."\n" ) if($self->verbose);

            my ($reports,@e);
            for my $dist (sort keys %{$reports{$author}->{dists}}) {
                my $v = $reports{$author}->{dists}{$dist};
                my @d;
                for my $version (sort keys %{$v->{versions}}) {
                    my $w = $v->{versions}{$version};
                    my @c;
                    for my $platform (sort keys %{$w->{platforms}}) {
                        my $x = $w->{platforms}{$platform};
                        my @b;
                        for my $perl (sort keys %{$x->{perls}}) {
                            my $y = $x->{perls}{$perl};
                            my @a;
                            for my $state (sort keys %{$y->{states}}) {
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
            if($self->verbose)    { $self->_log( "DEBUG: $author - reports = $reports\n" ) }
            else                { $self->_log( "INFO: $author - dists=".(scalar(keys %{$reports{$author}->{dists}})).", reports=$reports\n" ) }

            $tvars{dists}   = \@e;
            $tvars{period}  = $MODES{$mode}->{period};
            $tvars{report}  = $MODES{$mode}->{report};
            $tvars{subject} = "CPAN Testers $tvars{report} Report";

            $self->_write_mail('mailer.eml',\%tvars);
        }
    }

    $self->_set_lastid($last_id);
}

sub check_counts {
    my $self = shift;
    my $mode = $self->mode;

    $self->_log( "INFO: COUNTS for '$mode' mode:\n" );
    my @counts = qw(REPORTS PASS FAIL UNKNOWN NA NOMAIL MAILS NEWAUTH GOOD BAD);
    push @counts, 'TEST'    if($self->nomail);

    for(@counts) {
        $self->{counts}{$_} ||= 0;
        $self->_log( sprintf "INFO: %7s = %6d\n", $_, $self->{counts}{$_} );
    }
}

sub help {
    my ($self,$full) = @_;

    if($full) {
        print <<HERE;

Usage: $0 --config=<file> \\
         [--logfile=<file> [--logclean]] [--verbose] [--nomail] \\ 
         [--test=<id>] [--lastmail=<file>] \\
         [--mode=(daily|weekly|report|monthly|sun|mon|tue|wed|thu|fri|sat)] \\
         [-h] [-v]

  --config=<file>   database configuration file
  --logfile=<file>  log file (*)
  --logclean        0 = append, 1 = overwrite (*)
  --verbose         print additional log messages
  --nomail          nomail flag, no mail sent if true (*)
  --test=<id>       test an id in debug mode, no mail sent (*)
  --lastmail=<file> lastmail counter file (*)
  --mode            run mode (*)
  -h                this help screen
  -v                program version

  NOTES:
    * - these will override any settings within the configuration file.
HERE

    }

    print "$0 v$VERSION\n";
    exit(0);
}

#----------------------------------------------------------------------------
# Internal Methods

sub _get_lastid {
    my ($self,$id) = @_;
    my $mode = $self->mode;

    unless( -f $self->lastmail ) {
        mkpath(dirname($self->lastmail));
        overwrite_file( $self->lastmail, 'daily=0,weekly=0,reports=0' );
    }

    if (defined $id) {
        my $text = read_file($self->lastmail);
        if($text =~ m!$mode=\d+!) {
            $text =~ s!($mode=)\d+!$1$id!;
        } else {
            $text .= ",$mode=$id";  # auto add mode
        }
        $text =~ s/\s+//g;
        overwrite_file( $self->lastmail, $text );
        return $id;
    }

    my $text = read_file($self->lastmail);
    return $id  if(($id) = $text =~ m!$mode=(\d+)!);
    return $self->_get_earliest();   # mode not found, find earliest id based on mode
}

sub _set_lastid {
    my ($self,$id) = @_;

    if(!defined $id) {
        my @lastid = $self->{CPANSTATS}->get_query('array',$phrasebook{'LastReport'});
        $id = @lastid ? $lastid[0]->[0] : 0;
    }

    $self->_log( "INFO: new last_id=$id\n" );
    $self->_log( "INFO: STOP checking reports\n" );

    return $id  if($self->nomail);

    $self->_get_lastid($id);
}

sub _get_earliest {
    my $self = shift;
    my $mode = $self->mode;

    my @date = localtime(time);
    $date[5] += 1900;
    $date[4] += 1;
    if($mode eq 'monthly') {
        $date[4] -= 1;
        $date[3] = 1;
    } elsif($mode eq 'daily' || $mode eq 'reports') {
        $date[3] -= 1;
    } else {
        $date[3] -=7;
    }

    if($date[3] < 1) {
        $date[4] -= 1;
        if($date[4] == 2 && $date[5] % 4) {
            $date[3] = 28 - $date[3];
        } elsif($date[3] == 2) {
            $date[3] = 29 - $date[3];
        } elsif($date[3] == 4 || $date[3] == 6 || $date[3] == 9 || $date[3] == 11) {
            $date[3] = 30 - $date[3];
        } else {
            $date[3] = 31 - $date[3];
        }
        if($date[4] < 1) {
            $date[4] = 12;
            $date[5] -= 1;
        }
    }

    my $fulldate = sprintf "%04d%02d%02d000000", $date[5], $date[4], $date[3];
    my @report = $self->{CPANSTATS}->get_query('array',$phrasebook{'GetEarliest'}, $fulldate);
    return 0    unless(@report);
    return $report[0]->[0] || 0;
}

sub _get_author {
    my $self = shift;
    my ($dist,$vers) = @_;
    return  unless($dist && $vers);

    unless($AUTHORS{$dist} && $AUTHORS{$dist}{$vers}) {
        my @author = $self->{CPANSTATS}->get_query('array',$phrasebook{'GetAuthor'}, $dist, $vers);
        $AUTHORS{$dist}{$vers} = @author ? $author[0]->[0] : undef;
    }
    return $AUTHORS{$dist}{$vers};
}


sub _get_prefs {
    my $self = shift;
    my ($author,$dist) = @_;
    my $active = 0;

    return  unless($author);

    # get distribution defaults
    if($author && $dist) {
        if(defined $PREFS{$author}{dists}{$dist}) {
            return $PREFS{$author}{dists}{$dist};
        }

        my @rows = $self->{CPANPREFS}->get_query('hash',$phrasebook{'GetDistPrefs'}, $author,$dist);
        if(@rows) {
            $PREFS{$author}{dists}{$dist} = $self->_parse_prefs($rows[0]);
            return $PREFS{$author}{dists}{$dist};
        }

        # fall through and assume author defaults
    }

    # get author defaults
    if($author) {
        if(defined $PREFS{$author}{default}) {
            return $PREFS{$author}{default};
        }

        my @auth = $self->{CPANPREFS}->get_query('hash',$phrasebook{'GetAuthorPrefs'}, $author);
        if(@auth) {
            $PREFS{$author}{default}{active} = $auth[0]->{active} || 0;

            my @rows = $self->{CPANPREFS}->get_query('hash',$phrasebook{'GetDefaultPrefs'}, $author);
            if(@rows) {
                $PREFS{$author}{default} = $self->_parse_prefs($rows[0]);
                $PREFS{$author}{default}{active} = $rows[0]->{active} || 0;
                return $PREFS{$author}{default};
            } else {
                $self->{CPANPREFS}->do_query($phrasebook{'InsertDistPrefs'}, $author, '-');
                $active = $PREFS{$author}{default}{active};
            }
        }

        # fall through and assume new author
    }

    $dist ||= '-';

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
    $PREFS{$author}{dists}{$dist} = \%prefs;
    return \%prefs;
}

sub _parse_prefs {
    my ($self,$row) = @_;
    my %hash;

    $row->{grade} ||= 'FAIL';
    my %grades = map {$_ => 1} split(',',$row->{grade});

    $hash{grades}   = \%grades;
    $hash{ignored}  = $self->_defined_or($row->{ignored},  0);
    $hash{report}   = $self->_defined_or($row->{report},   1);
    $hash{tuple}    = $self->_defined_or($row->{tuple},    'FIRST');
    $hash{version}  = $self->_defined_or($row->{version},  'LATEST');
    $hash{patches}  = $self->_defined_or($row->{patches},  0);
    $hash{perl}     = $self->_defined_or($row->{perl},     'ALL');
    $hash{platform} = $self->_defined_or($row->{platform}, 'ALL');

    return \%hash;
}

sub _send_report {
    my ($self,$author,$row) = @_;

    # get article
    my @rows = $self->{ARTICLES}->get_query('hash',$phrasebook{'GetArticle'}, $row->{id});

    #$self->_log( "ARTICLE: $row->{id}: $rows[0]->{article}\n" );

    # disassemble article
    $rows[0]->{article} = decode_qp($rows[0]->{article})	if($rows[0]->{article} =~ /=3D/);
    my $mail = Email::Simple->new($rows[0]->{article});
    return unless $mail;

    # get from & subject line
    my $from    = $mail->header("From");
    my $subject = $mail->header("Subject");
    return unless $subject;

    my ($address) = Email::Address->parse($from);
    my $reply = sprintf "%s\@%s", $address->user, $address->host;

    # extract the body
    my $encoding = $mail->header('Content-Transfer-Encoding');
    my $body = $mail->body;
    $body = decode_base64($body)  if($encoding && $encoding eq 'base64');

    # set up new mail headers
    my $pause = $self->pause->author($author);
    my %tvars = (
        author  => $author, 
        name    => ($pause ? $pause->name : $author),
        subject => $subject,
        from    => $reply,
        body    => $body,
        reply   => $reply
    );

    # send data
    $self->_write_mail('report.eml',\%tvars);
}

sub _write_mail {
    my ($self,$template,$parms) = @_;

    my $from = $parms->{from} || $FROM;
    my $subject = $parms->{subject} || 'CPAN Testers Daily Reports';
    my $cmd = qq!| $HOW $parms->{author}\@cpan.org!;

    $self->{counts}{MAILS}++;

    my $DATE = $self->_emaildate();
    $DATE =~ s/\s+$//;

    my $text;
    $self->tt->process( $template, $parms, \$text ) || die $self->tt->error;

    my $body;
    $body =  "Reply-To: $parms->{reply}\n"  if($parms->{reply});
    $body .= $HEAD . $text;
    $body =~ s/FROM/$from/g;
    $body =~ s/NAME/$parms->{name}/g;
    $body =~ s/EMAIL/$parms->{author}\@cpan.org/g;
    $body =~ s/DATE/$DATE/g;
    $body =~ s/SUBJECT/$subject/g;

    if($self->nomail) {
        $self->_log( "INFO: TEST: $parms->{author}\n" );
        $self->{counts}{TEST}++;
        my $fh = IO::File->new('mailer-debug.log','a+') or die "Cannot write to debug file [mailer-debug.log]: $!\n";
        print $fh $body;
        $fh->close;
        
    } elsif(my $fh = IO::File->new($cmd)) {

        print $fh $body;
        $fh->close;
        $self->_log( "INFO: GOOD: $parms->{author}\n" );
        $self->{counts}{GOOD}++;

    } else {
        $self->_log( "INFO: BAD:  $parms->{author}\n" );
        $self->{counts}{BAD}++;
    }
}

sub _emaildate {
    my $self = shift;
    my $t = localtime;
    return $t->strftime("%a, %d %b %Y %H:%M:%S +0000");
}

sub _download_mailrc {
    my $self = shift;
    my $file = $self->mailrc;
    my $data;

    if($file && -f $file) {
        $data = read_file($file);

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

=head1 INTERFACE

=head2 The Constructor

=over

=item * new

Instatiates the object CPAN::WWW::Testers. Requires a hash of parameters, with
'config' being the only mandatory key. Note that 'config' can be anything that
L<Config::IniFiles> accepts for the I<-file> option.

=back

=head2 Public Methods

=over 4

=item * check_reports

The core method that analyses the reports and constructs the mails.

=item * check_counts

Prints a summary of the processing.

=item * help

Using the command line option, --help or -h, displays a help screen with
instructions of the command line arguments. See the Configuration section
for further details.

=back

=head2 Accessor Methods

=over 4

=item * lastfile

Path to the file containing the last NNTPID processed.

=item * verbose

Provides the current verbose configuration setting.

=item * nomail

Provides the current nomail configuration setting.

=item * test

Provides a single test ID, if not all NNTPIDs need testing.

=item * logfile

Path to output log file for progress and debugging messages.

=item * logclean

If set to a true value will create/overwrite the logfile, otherwise will
append any messages.

=item * mode

Provides the current mode being executed.

=item * mailrc

Path to the 01mailrc.txt file.

=item * tt

Provides the Template Toolkit object.

=item * pause

Provides the Parse::CPAN::Authors object.

=back

=head2 Internal Methods

=over 4

=item * _get_lastid

Returns the last NNTPID processed for the current mode.

=item * _set_lastid

Sets the given NNTPID for the current mode.

=item * _get_author

Returns the author of a given distribution/version.

=item * _get_prefs

Returns the author preferences.

=item * _parse_prefs

Parse a preferences record and returns a hash instance.

=item * _send_report

Repackages a report as an email for an individual author.

=item * _write_mail

Composes and sends a mail message.

=item * _emaildate

Returns an RFC 2822 compliant formatted date string.

=item * _download_mailrc

Downloads and/or reads a copy of the 01mailrc.txt file.

=back

=head1 SEE ALSO

L<CPAN::Testers::Data::Generator>
L<CPAN::WWW::Testers>
L<CPAN::Testers::WWW::Statistics>

F<http://blog.cpantesters.org/>,
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
