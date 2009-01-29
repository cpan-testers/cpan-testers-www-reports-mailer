#!perl

use strict;
use warnings;

use Test::More tests => 16;
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

    # defaults to daily mode
    ok($obj->_get_lastid(12), 'set last id - daily mode');
    is($obj->_get_lastid,12, 'get last id - daily mode');

    $obj->mode('weekly');
    ok($obj->_get_lastid(14), 'set last id - weekly mode');
    is($obj->_get_lastid,14, 'get last id - weekly mode');

    $obj->mode('reports');
    ok($obj->_get_lastid(16), 'set last id - reports mode');
    is($obj->_get_lastid,16, 'get last id - reports mode');

    $obj->mode('daily');
    is($obj->_get_lastid,12, 'get last id - daily mode still valid');
    $obj->mode('weekly');
    is($obj->_get_lastid,14, 'get last id - weekly mode still valid');
    $obj->mode('reports');
    is($obj->_get_lastid,16, 'get last id - reports mode still valid');


    my ($counts,@log);
    my @lines = do { open FILE, '<', $obj->lastmail; <FILE> };
    is($lines[0],'daily=12,weekly=14,reports=16', 'read last id');
}