#!perl

use strict;
use warnings;
$|=1;

use Test::More tests => 47;
use lib 't';
use lib qw(./lib ../lib);

my %COUNTS = (
    REPORTS => 777,
    PASS    => 718,
    FAIL    => 34,
    UNKNOWN => 25,
    NA      => 0,
    NOMAIL  => 0,
    MAILS   => 1,
    NEWAUTH => 0,
    GOOD    => 0,
    BAD     => 0,
    TEST    => 1
);

use CTWRM_Testing;
use CPAN::Testers::WWW::Reports::Mailer;
use File::Slurp;
use File::Path;
use File::Basename;

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
is($pd,6,'distro records added');

mkpath(dirname($files{lastmail}));
overwrite_file($files{lastmail}, 'daily=4587509,weekly=4587509,reports=4587509' );
run_mailer();

$COUNTS{REPORTS} = 394;
$COUNTS{PASS}    = 365;
$COUNTS{FAIL}    = 27;
$COUNTS{UNKNOWN} = 2;
overwrite_file($files{lastmail}, 'daily=4722317,weekly=4722317,reports=4722317' );
run_mailer();

$COUNTS{MAILS}   = 1;
$COUNTS{REPORTS} = 286;
$COUNTS{PASS}    = 262;
$COUNTS{TEST}    = 1;
$COUNTS{FAIL}    = 23;
$COUNTS{UNKNOWN} = 1;
overwrite_file($files{lastmail}, 'daily=4766000,weekly=4766000,reports=4766000' );
run_mailer();

$COUNTS{MAILS}   = 1;
$COUNTS{REPORTS} = 285;
$COUNTS{FAIL}    = 22;
overwrite_file($files{lastmail}, 'daily=4766100,weekly=4766100,reports=4766100' );
run_mailer();

sub run_mailer {
    my $mailer = CPAN::Testers::WWW::Reports::Mailer->new(config => 't/data/preferences-daily.ini');
    $mailer->check_reports();
    $mailer->check_counts();

    is($mailer->{counts}{$_},$COUNTS{$_},"Matched count for $_") for(keys %COUNTS);
}

is(CTWRM_Testing::mail_check($files{mailfile},'t/data/71daily.eml'),1,'mail files match');

__DATA__
auth|DCANTRELL|3|1248533160
dist|DCANTRELL|-|0|1|FAIL,UNKNOWN|FIRST|LATEST|1|ALL|ALL
dist|DCANTRELL|Acme-Licence|1|1|FAIL|FIRST|LATEST|0|ALL|ALL
dist|DCANTRELL|Acme-Pony|1|1|FAIL|FIRST|LATEST|0|ALL|ALL
dist|DCANTRELL|Acme-Scurvy-Whoreson-BilgeRat|1|1|FAIL|FIRST|LATEST|0|ALL|ALL
dist|DCANTRELL|Bryar|1|1|FAIL|FIRST|LATEST|0|ALL|ALL
dist|DCANTRELL|Pony|1|1|FAIL|FIRST|LATEST|0|ALL|ALL
