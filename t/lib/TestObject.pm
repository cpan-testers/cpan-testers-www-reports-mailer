package CTWRM_Testing;

use strict;
use warnings;

use CPAN::Testers::WWW::Reports::Mailer;
use DBI;
#use DBD::SQLite;
use File::Spec;
use File::Path;
use File::Basename;

sub getObj {
  my %opts = @_;
  $opts{config}    ||= \*DATA;

  _cleanDir( 'logs' ) or return;

  my $obj = CPAN::Testers::WWW::Reports::Mailer->new(%opts);

  return $obj;
}

sub _cleanDir {
  my $dir = shift;
  if( -d $dir ){
    rmtree($dir) or return;
  }
  mkpath($dir) or return;
  return 1;
}

sub cleanDir {
  my $obj = shift;
  return _cleanDir( 'logs' );
}

sub whackDir {
  my $obj = shift;
  my $dir = 'logs';
  if( -d $dir ){
    rmtree($dir) or return;
  }
  return 1;
}


sub prefs_db_init {
    my $data = shift;

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

    while(<$data>){
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
    return($pa,$pd);
}

sub mail_check {
    my ($file1,$file2) = @_;
    my $mail1 = readfile($file1);
    my $mail2 = readfile($file2);

    return $mail1 eq $mail2 ? 1 : 0;
}

sub readfile {
    my $file = shift;
    my $text;
    my $fh = IO::File->new($file,'r') or die "Cannot open file [$file]: $!\n";
    while(<$fh>) { 
        next    if(/^Date:/);
        $text .= $_ 
    }
    $fh->close;
    return $text;
}

1;

__DATA__

[CPANSTATS]
driver=SQLite
database=t/_DBDIR/test.db

[CPANPREFS]
driver=SQLite
database=t/_DBDIR/test2.db

[ARTICLES]
driver=SQLite
database=t/_DBDIR/test3.db

[SETTINGS]
mailrc=t/data/01mailrc.txt
verbose=1
nomail=1
logfile=t/_TMPDIR/cpanreps.log
logclean=1

