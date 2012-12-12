#!/usr/bin/perl -w
use strict;

$|=1;

# -------------------------------------------------------------------
# Library Modules

use lib qw(t/lib);
use Test::More tests => 7;

use TestObject;

# -------------------------------------------------------------------
# Tests

ok( my $obj = TestObject->load(), "got object" );

isa_ok( $obj, 'CPAN::Testers::WWW::Reports::Mailer', "object type" );

#ok( $obj->{config}, 'config' );
#isa_ok( $obj->{config}, 'GLOB', 'config type' );

isa_ok( $obj->{CPANPREFS},         'CPAN::Testers::Common::DBUtils', 'CPANSTATS' );

isa_ok( $obj->tt,   'Template', 'tt' );
# TODO: should check attributes

is($obj->_defined_or( undef, 1, 2 ), 1);
is($obj->_defined_or( 3, undef, 4 ), 3);
is($obj->_defined_or( 5, 6, undef ), 5);
