#!perl -w
use strict;

$|=1;

# -------------------------------------------------------------------
# Library Modules

use lib qw(t/lib);
use Test::More tests => 14;

use CPAN::Testers::WWW::Reports::Mailer;

use TestEnvironment;
use TestObject;

# -------------------------------------------------------------------
# Variables

my %COUNTS = (
    REPORTS => 10643,
    PASS    => 9688,
    FAIL    => 896,
    UNKNOWN => 40,
    NA      => 19,
    NOMAIL  => 0,
    MAILS   => 1,
    NEWAUTH => 0,
    GOOD    => 0,
    BAD     => 0,
    TEST    => 1
);

my @DATA = (
    'auth|BARBIE|3|NULL',
    'dist|BARBIE|-|0|1|FAIL,UNKNOWN,NA|FIRST|LATEST|1|ALL|ALL'
);

my %files = (
    'lastmail' => 't/_TMPDIR/test-lastmail.txt',
    'logfile'  => 't/_TMPDIR/test-daily.log',
    'mailfile' => 'mailer-debug.log'
);

my $CONFIG = 't/_DBDIR/preferences-daily.ini';

# -------------------------------------------------------------------
# Tests

for(keys %files) {
    unlink $files{$_}   if(-f $files{$_});
}

my $handles = TestEnvironment::Handles();
my ($pa,$pd) = TestEnvironment::ResetPrefs(\@DATA);
is($pa,1,'author records added');
is($pd,1,'distro records added');

my $mailer = TestObject->load(config => $CONFIG);

$mailer->check_reports();
$mailer->check_counts();

is($mailer->{counts}{$_},$COUNTS{$_},"Matched count for $_") for(keys %COUNTS);

is(TestObject::mail_check($files{mailfile},'t/data/64daily.eml'),1,'mail files match');
