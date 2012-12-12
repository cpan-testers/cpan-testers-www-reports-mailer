#!perl

use strict;
use warnings;
$|=1;
use Test::More tests => 2;
use DBI;
#use DBD::SQLite;
use File::Spec;
use File::Path;
use File::Basename;

my $f = File::Spec->catfile('t','_DBDIR','test2.db');
unlink $f if -f $f;
mkpath( dirname($f) );

my $dbh = DBI->connect("dbi:SQLite:dbname=$f", '', '', {AutoCommit=>1});
$dbh->do(q{
  CREATE TABLE prefs_authors (
                          pauseid       TEXT PRIMARY KEY,
                          active        INTEGER,
                          lastlogin     TEXT
  )
});
$dbh->do(q{
  CREATE TABLE prefs_distributions (
                          pauseid       TEXT,
                          distribution  TEXT,
                          ignored       INTEGER,
                          report        INTEGER,
                          grade         TEXT,
                          tuple         TEXT,
                          version       TEXT,
                          patches       INTEGER,
                          perl          TEXT,
                          platform      TEXT
  )
});

while(<DATA>){
  chomp;
  my ($type,@values) = split(/\|/,$_);
  if($type eq 'auth') {
    $dbh->do('INSERT INTO prefs_authors ( pauseid, active, lastlogin ) VALUES ( ?, ?, ? )', {}, @values );
  } else {
    $dbh->do('INSERT INTO prefs_distributions ( pauseid, distribution, ignored, report, grade, tuple, version, patches, perl, platform ) VALUES ( ?, ?, ?, ?, ?, ?, ?, ?, ?, ? )', {}, @values );
  }
}

my ($pa) = $dbh->selectrow_array('select count(*) from prefs_authors');
my ($pd) = $dbh->selectrow_array('select count(*) from prefs_distributions');

$dbh->disconnect;

is($pa, 16, "row count for prefs_authors");
is($pd, 16, "row count for prefs_distributions");

#select * from prefs_authors where pauseid in ('JHARDING','JBRYAN','VOISCHEV','LBROCARD','JALDHAR','JESSE','INGY','JETEVE','DRRHO','JJORE','ISHIGAKI','ADRIANWIT','SAPER','GARU','ZOFFIX');
#select * from prefs_distributions where pauseid in ('JHARDING','JBRYAN','VOISCHEV','LBROCARD','JALDHAR','JESSE','INGY','JETEVE','DRRHO','JJORE','ISHIGAKI','ADRIANWIT','SAPER','GARU','ZOFFIX');

# pauseid|active|lastlogin
# pauseid|distribution|ignored|report|grade|tuple|version|patches|perl|platform
__DATA__
auth|ADRIANWIT|3|NULL
auth|BARBIE|3|NULL
auth|DRRHO|3|NULL
auth|GARU|3|NULL
auth|INGY|3|NULL
auth|ISHIGAKI|3|NULL
auth|JALDHAR|3|NULL
auth|JBRYAN|3|NULL
auth|JESSE|3|NULL
auth|JETEVE|3|NULL
auth|JHARDING|3|NULL
auth|JJORE|3|NULL
auth|LBROCARD|3|NULL
auth|SAPER|3|NULL
auth|VOISCHEV|3|NULL
auth|ZOFFIX|3|NULL
dist|ADRIANWIT|-|0|1|FAIL|FIRST|LATEST|0|ALL|ALL
dist|BARBIE|-|0|3|ALL|FIRST|LATEST|0|ALL|ALL
dist|DRRHO|-|0|1|FAIL|FIRST|LATEST|0|ALL|ALL
dist|GARU|-|0|1|FAIL|FIRST|LATEST|0|ALL|ALL
dist|INGY|-|0|1|FAIL|FIRST|LATEST|0|ALL|ALL
dist|ISHIGAKI|-|0|1|FAIL|FIRST|LATEST|0|ALL|ALL
dist|JALDHAR|-|0|1|FAIL|FIRST|LATEST|0|ALL|ALL
dist|JBRYAN|-|0|1|FAIL|FIRST|LATEST|0|ALL|ALL
dist|JESSE|-|0|1|FAIL|FIRST|LATEST|0|ALL|ALL
dist|JETEVE|-|0|1|FAIL|FIRST|LATEST|0|ALL|ALL
dist|JHARDING|-|0|1|FAIL|FIRST|LATEST|0|ALL|ALL
dist|JJORE|-|0|1|FAIL|FIRST|LATEST|0|ALL|ALL
dist|LBROCARD|-|0|1|FAIL|FIRST|LATEST|0|ALL|ALL
dist|SAPER|-|0|1|FAIL|FIRST|LATEST|0|ALL|ALL
dist|VOISCHEV|-|0|1|FAIL|FIRST|LATEST|0|ALL|ALL
dist|ZOFFIX|-|0|1|FAIL|FIRST|LATEST|0|ALL|ALL
