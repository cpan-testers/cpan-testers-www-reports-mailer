#!perl

use strict;
use warnings;

use Test::More tests => 9;
use CPAN::Testers::WWW::Reports::Mailer;

use lib 't';
use CTWRM_Testing;

{
    ok( my $obj = CTWRM_Testing::getObj(), "got object" );

    my $f = File::Spec->catfile('t','_DBDIR','lastmail');
    ok($obj->lastmail($f),'reset last mail file');
    is($obj->lastmail,$f, 'reset last mail');

    ok(!-f $f, 'lastmail not created');
    is($obj->_get_lastid,0, 'new last id');
    ok(-f $f, 'lastmail now exists');
    ok($obj->_get_lastid(12), 'set last id');
    is($obj->_get_lastid,12, 'get last id');

    my ($counts,@log);
    my @lines = do { open FILE, '<', $obj->lastmail; <FILE> };
    is($lines[0],12, 'read last id');
}