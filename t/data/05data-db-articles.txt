#!perl

use strict;
use warnings;
$|=1;
use Test::More tests => 1;
use DBI;
#use DBD::SQLite;
use File::Spec;
use File::Path;
use File::Basename;

my $f = File::Spec->catfile('t','_DBDIR','test3.db');
unlink $f if -f $f;
mkpath( dirname($f) );

my $dbh = DBI->connect("dbi:SQLite:dbname=$f", '', '', {AutoCommit=>1});
$dbh->do(q{
  CREATE TABLE articles (
                          id            INTEGER PRIMARY KEY,
                          article       TEXT
  )
});

while(<DATA>){
  chomp;
  $dbh->do('INSERT INTO articles ( id, article ) VALUES ( ?, ? )', {}, split(/\|/,$_) );
}

my ($ct) = $dbh->selectrow_array('select count(*) from articles');

$dbh->disconnect;

is($ct, 2, "row count for articles");

__DATA__
3000001|This is a FAIL
3000002|This is a PASS
