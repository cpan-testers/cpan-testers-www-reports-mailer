package CTWRM_Testing;

use strict;
use warnings;

use CPAN::Testers::WWW::Reports::Mailer;
use File::Path;

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

1;

__DATA__

[CPANSTATS]
driver=SQLite
database=t/_DBDIR/test.db

[CPANPREFS]
driver=SQLite
database=t/_DBDIR/test2.db

[SETTINGS]
debug=1
logfile=t/_TMPDIR/cpanreps.log
logclean=1

