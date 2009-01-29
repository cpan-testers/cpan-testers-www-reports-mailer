#!perl

use strict;
use warnings;
$|=1;

use Test::More tests => 10;
use lib 't';
use CTWRM_Testing;

ok( my $obj = CTWRM_Testing::getObj(), "got object" );

isa_ok( $obj, 'CPAN::Testers::WWW::Reports::Mailer', "object type" );

#ok( $obj->{config}, 'config' );
#isa_ok( $obj->{config}, 'GLOB', 'config type' );

my $db = File::Spec->catfile('t','_DBDIR','test.db');
isa_ok( $obj->{CPANSTATS},         'CPAN::Testers::Common::DBUtils', 'CPANSTATS' );
is(     $obj->{CPANSTATS}->{database}, $db,                          'CPANSTATS.database' );
is(     $obj->{CPANSTATS}->{driver},   'SQLite',                     'CPANSTATS.database' );

isa_ok( $obj->{CPANPREFS},         'CPAN::Testers::Common::DBUtils', 'CPANPREFS' );

isa_ok( $obj->tt,   'Template', 'tt' );
# TODO: should check attributes

is($obj->_defined_or( undef, 1, 2 ), 1);
is($obj->_defined_or( 3, undef, 4 ), 3);
is($obj->_defined_or( 5, 6, undef ), 5);
