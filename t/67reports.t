#!perl -w
use strict;

$|=1;

# -------------------------------------------------------------------
# Library Modules

use lib qw(t/lib);
use File::Basename;
use File::Path;
use File::Slurp;
use Test::More tests => 14;

use CPAN::Testers::WWW::Reports::Mailer;

use TestEnvironment;
use TestObject;

# -------------------------------------------------------------------
# Variables

my %COUNTS = (
    REPORTS => 8,
    PASS    => 5,
    FAIL    => 3,
    UNKNOWN => 0,
    NA      => 0,
    NOMAIL  => 0,
    MAILS   => 3,
    NEWAUTH => 0,
    GOOD    => 0,
    BAD     => 0,
    TEST    => 3
);

my @DATA = (
    'auth|BARBIE|3|NULL',
    'dist|BARBIE|-|0|3|FAIL|FIRST|LATEST|1|ALL|ALL'
);
my %files = (
    'lastmail' => 't/_TMPDIR/test-lastmail.txt',
    'logfile'  => 't/_TMPDIR/test-reports.log',
    'mailfile' => 'mailer-debug.log'
);

my $CONFIG = 't/_DBDIR/preferences-reports.ini';

# -------------------------------------------------------------------
# Tests

for(keys %files) {
    unlink $files{$_}   if(-f $files{$_});
}

mkpath(dirname($files{lastmail}));
overwrite_file($files{lastmail}, 'daily=4766100,weekly=4766100,reports=4766100' );

my $handles = TestEnvironment::Handles();
my ($pa,$pd) = TestEnvironment::ResetPrefs(\@DATA);
is($pa,1,'author records added');
is($pd,1,'distro records added');

my $mailer = TestObject->load(config => $CONFIG);

$mailer->check_reports();
$mailer->check_counts();

is($mailer->{counts}{$_},$COUNTS{$_},"Matched count for $_") for(keys %COUNTS);

is(TestObject::mail_check($files{mailfile},'t/data/67reports.eml'),1,'mail files match');
