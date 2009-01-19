#!perl

use strict;
use warnings;
$|=1;

use lib 't';
use CTWRM_Testing;

use Test::More tests => 4;
use File::Spec;
use File::Path;

ok( my $obj = CTWRM_Testing::getObj(), "got object" );

# these shouldn't exist ...  whack just to be sure.
rmtree( File::Spec->catfile('t','_DBDIR')    );
rmtree( File::Spec->catfile('t','_EXPECTED') );

# triple check
ok( ! -d File::Spec->catfile('t','_TMPDIR'),   '_TMPDIR removed'   );
ok( ! -d File::Spec->catfile('t','_DBDIR'),    '_DBDIR removed'    );
ok( ! -d File::Spec->catfile('t','_EXPECTED'), '_EXPECTED removed' );

