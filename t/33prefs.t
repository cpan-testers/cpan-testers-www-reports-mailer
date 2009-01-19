#!perl

use strict;
use warnings;

use Test::More tests => 5;
use CPAN::Testers::WWW::Reports::Mailer;

use lib 't';
use CTWRM_Testing;

{
    ok( my $obj = CTWRM_Testing::getObj(), "got object" );

    my %prefs = (
        LBROCARD => {
          'version' => 'LATEST',
          'ignored' => 0,
          'perl' => 'ALL',
          'report' => '1',
          'tuple' => 'FIRST',
          'platform' => 'ALL',
          'patches' => 0,
          'grades' => {
                        'FAIL' => 1
                      }
        },
        SAPER => {
          'version' => 'LATEST',
          'active' => '3',
          'ignored' => 0,
          'perl' => 'ALL',
          'report' => '1',
          'tuple' => 'FIRST',
          'platform' => 'ALL',
          'patches' => 0,
          'grades' => {
                        'FAIL' => 1
                      }
        },
    );

    is_deeply($obj->_get_prefs('LBROCARD','-'),                     $prefs{LBROCARD},   'found author prefs - LBROCARD');
    is_deeply($obj->_get_prefs('SAPER','Acme-CPANAuthors-French'),  $prefs{SAPER},      'found author prefs - SAPER');

use Data::Dumper;
#print STDERR Dumper($obj->_get_prefs('LBROCARD','-'));
#print STDERR Dumper($obj->_get_prefs('SAPER','Acme-CPANAuthors-French','-'));

    my $row  = {};
    my $hash = {
          'version' => 'LATEST',
          'ignored' => 0,
          'perl' => 'ALL',
          'report' => 1,
          'tuple' => 'FIRST',
          'platform' => 'ALL',
          'patches' => 0,
          'grades' => {
                        'FAIL' => 1
                      }
    };

    is_deeply($obj->_parse_prefs($row), $hash, 'default prefs parse');
#print STDERR Dumper($obj->_parse_prefs($row));

    $row = {
        grade       => 'PASS,FAIL,UNKNOWN,NA',
        ignored     => 1,
        report      => 0,
        tuple       => 'ALL',
        version     => 'ALL',
        patches     => 1,
        perl        => '5.8.8',
        platform    => 'Linux'
    };
    $hash = {
          'version' => 'ALL',
          'ignored' => 1,
          'perl' => '5.8.8',
          'report' => 0,
          'tuple' => 'ALL',
          'platform' => 'Linux',
          'patches' => 1,
          'grades' => {
                        'PASS' => 1,
                        'FAIL' => 1,
                        'UNKNOWN' => 1,
                        'NA' => 1
                      }
    };

    is_deeply($obj->_parse_prefs($row), $hash, 'default prefs parse');
#print STDERR Dumper($obj->_parse_prefs($row));


}


