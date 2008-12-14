#!/usr/bin/perl -w
use strict;

use Test::More tests => 2;

BEGIN {
	use_ok( 'CPAN::Testers::WWW::Reports::Mailer' );
	use_ok( 'CPAN::Testers::WWW::Reports::Mailer::DBUtils' );
}
