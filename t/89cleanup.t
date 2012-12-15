#!/usr/bin/perl -w
use strict;

$|=1;

# -------------------------------------------------------------------
# Library Modules

use File::Path;
use Test::More tests => 2;

# -------------------------------------------------------------------
# Tests

# these shouldn't exist ...  whack just to be sure.
#rmtree( 't/_TMPDIR'   );
#rmtree( 't/_DBDIR'    );

# triple check
ok( ! -d 't/_TMPDIR',   '_TMPDIR removed'   );
ok( ! -d 't/_DBDIR',    '_DBDIR removed'    );
