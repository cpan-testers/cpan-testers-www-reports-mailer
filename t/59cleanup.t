#!perl

use strict;
use warnings;
$|=1;

use Test::More tests => 3;
use File::Spec;
use File::Path;

# these shouldn't exist ...  whack just to be sure.
rmtree( File::Spec->catfile('t','_TMPDIR')    );
rmtree( File::Spec->catfile('t','_DBDIR')    );
rmtree( File::Spec->catfile('t','_EXPECTED') );

# triple check
ok( ! -d File::Spec->catfile('t','_TMPDIR'),   '_TMPDIR removed'   );
ok( ! -d File::Spec->catfile('t','_DBDIR'),    '_DBDIR removed'    );
ok( ! -d File::Spec->catfile('t','_EXPECTED'), '_EXPECTED removed' );

