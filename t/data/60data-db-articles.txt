#!perl

use strict;
use warnings;
$|=1;

use lib 't';
use lib qw(./lib ../lib);

use Test::More tests => 1;
use DBI;
#use DBD::SQLite;
use File::Spec;
use File::Path;
use File::Basename;
use File::Slurp;

my @articles = qw(4766103 4766403 4766801);

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

for my $id (@articles) {
  my $text = read_file('t/samples/'.$id);
  $dbh->do('INSERT INTO articles ( id, article ) VALUES ( ?, ? )', {}, $id, $text );
}

my ($ct) = $dbh->selectrow_array('select count(*) from articles');

$dbh->disconnect;

is($ct, 3, "row count for articles");

