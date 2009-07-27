#!perl

use strict;
use warnings;
$|=1;

use Test::More tests => 14;
use lib 't';
use lib qw(./lib ../lib);

my %COUNTS = (
    REPORTS => 10643,
    PASS    => 9688,
    FAIL    => 896,
    UNKNOWN => 40,
    NA      => 19,
    NOMAIL  => 0,
    MAILS   => 0,
    NEWAUTH => 0,
    GOOD    => 0,
    BAD     => 0,
    TEST    => 0
);

use CTWRM_Testing;
use CPAN::Testers::WWW::Reports::Mailer;

my %files = (
    'lastmail' => 't/_TMPDIR/test-lastmail.txt',
    'logfile'  => 't/_TMPDIR/test-daily.log',
    'mailfile' => 'mailer-debug.log'
);

for(keys %files) {
    unlink $files{$_}   if(-f $files{$_});
}

my ($pa,$pd) = CTWRM_Testing::prefs_db_init(\*DATA);
is($pa,1,'author records added');
is($pd,1,'distro records added');

my $mailer = CPAN::Testers::WWW::Reports::Mailer->new(config => 't/data/preferences-daily.ini');

$mailer->check_reports();
$mailer->check_counts();

is($mailer->{counts}{$_},$COUNTS{$_},"Matched count for $_") for(keys %COUNTS);

ok(-f $files{mailfile} ? 0 : 1,'no mail files sent');


__DATA__
auth|BARBIE|3|NULL
dist|BARBIE|-|0|1|NONE|FIRST|LATEST|1|ALL|ALL
