#!/usr/bin/perl -w
use strict;

$|=1;

use DBI;
use File::Path;
use File::Basename;
use IO::File;
use Test::More tests => 1;

my $DATA = 't/data/60data-db-cpanstats.txt';
my $DB   = 't/_DBDIR/test.db';

# rebuild cpanstats db

unlink $DB if -f $DB;
mkpath( dirname($DB) );

my $dbh = DBI->connect("dbi:SQLite:dbname=$DB", '', '', {AutoCommit=>1});
$dbh->do(q{
    CREATE TABLE cpanstats (
        id            INTEGER PRIMARY KEY,
        guid          TEXT,
        state         TEXT,
        postdate      TEXT,
        tester        TEXT,
        dist          TEXT,
        version       TEXT,
        platform      TEXT,
        perl          TEXT,
        osname        TEXT,
        osvers        TEXT,
        fulldate      TEXT
    )
});

my fh = IO::File->new($DATA) or die;
while(<$fh>){
  chomp;
  $dbh->do('INSERT INTO cpanstats ( id, guid, state, postdate, tester, dist, version, platform, perl, osname, osvers, fulldate ) VALUES ( ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ? )', {}, split(/\|/,$_) );
}

$dbh->do(q{ CREATE INDEX distverstate ON cpanstats (dist, version, state) });
$dbh->do(q{ CREATE INDEX ixdate ON cpanstats (postdate) });
$dbh->do(q{ CREATE INDEX ixperl ON cpanstats (perl) });
$dbh->do(q{ CREATE INDEX ixplat ON cpanstats (platform) });

my ($ct) = $dbh->selectrow_array('select count(*) from cpanstats');

$dbh->disconnect;

is($ct, 10976, "row count for cpanstats");

#select * from cpanstats where state='cpan' and dist in ('AEAE', 'AI-NeuralNet-BackProp', 'AI-NeuralNet-Mesh', 'AI-NeuralNet-SOM', 'AOL-TOC', 'Abstract-Meta-Class', 'Acme', 'Acme-Anything', 'Acme-BOPE', 'Acme-Brainfuck', 'Acme-Buffy', 'Acme-CPANAuthors-Canadian', 'Acme-CPANAuthors-CodeRepos', 'Acme-CPANAuthors-French', 'Acme-CPANAuthors-Japanese');
# sqlite> select * from cpanstats where postdate=200901 order by dist limit 20;
# id|guid|state|postdate|tester|dist|version|platform|perl|osname|osvers|date
