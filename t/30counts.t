#!perl

use strict;
use warnings;

use Test::More tests => 2;
use CPAN::Testers::WWW::Reports::Mailer;

use lib 't';
use CTWRM_Testing;

{
    ok( my $obj = CTWRM_Testing::getObj(), "got object" );

    $obj->check_counts;

    my ($counts,@log);
    open FILE, '<', $obj->logfile;
    while(<FILE>) {
        next    unless($counts || /COUNTS:/);
        $counts = 1;
        chomp;
        push @log, substr($_,21);
    }

    is_deeply(\@log, [
              'INFO: COUNTS:',
              'INFO: REPORTS =      0',
              'INFO:    PASS =      0',
              'INFO:    FAIL =      0',
              'INFO: UNKNOWN =      0',
              'INFO:      NA =      0',
              'INFO:  NOMAIL =      0',
              'INFO:   MAILS =      0',
              'INFO: NEWAUTH =      0',
              'INFO:    GOOD =      0',
              'INFO:     BAD =      0',
              'INFO:    TEST =      0',
    ], "log written");
}