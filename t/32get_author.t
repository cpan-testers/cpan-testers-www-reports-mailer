#!perl

use strict;
use warnings;

use Test::More tests => 5;
use CPAN::Testers::WWW::Reports::Mailer;

use lib 't';
use CTWRM_Testing;

{
    ok( my $obj = CTWRM_Testing::getObj(), "got object" );

    is($obj->_get_author('Abstract-Meta-Class','0.11'),'ADRIANWIT','found author ADRIANWIT');
    is($obj->_get_author('Acme-CPANAuthors-French','0.07'),'SAPER','found author SAPER');
    is($obj->_get_author('Acme-Buffy','1.5'),'LBROCARD','found author LBROCARD');
    is($obj->_get_author('AI-NeuralNet-Mesh','0.44'),'JBRYAN','found author JBRYAN');
}