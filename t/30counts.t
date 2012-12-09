#!/usr/bin/perl -w
use strict;

use CPAN::Testers::WWW::Reports::Mailer;
use File::Slurp;
use Test::More tests => 4;

use lib 't';
use CTWRM_Testing;

my $LOGFILE = 't/_TMPDIR/cpanreps.log';
unlink $LOGFILE if(-f $LOGFILE);

{
    ok( my $obj = CTWRM_Testing::getObj(), "got object" );

    ok(!-f $LOGFILE, 'log not found' );
    $obj->check_counts;
    ok( -f $LOGFILE, 'log created' );

    my ($counts,@log);
    my @lines = read_file($LOGFILE);
    for my $line (@lines) {
        next    unless($counts || /INFO: COUNTS/);
        $counts = 1;
        $line =~ s/\s+$//;
        push @log, substr($_,21);
    }

    is_deeply(\@log, [
              'INFO: COUNTS for \'daily\' mode:',
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
