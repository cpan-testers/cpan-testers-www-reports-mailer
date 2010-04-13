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

my $f = File::Spec->catfile('t','_DBDIR','test.db');
unlink $f if -f $f;
mkpath( dirname($f) );

my $dbh = DBI->connect("dbi:SQLite:dbname=$f", '', '', {AutoCommit=>1});
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

while(<DATA>){
  chomp;
  $dbh->do('INSERT INTO cpanstats ( id, guid, state, postdate, tester, dist, version, platform, perl, osname, osvers, fulldate ) VALUES ( ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ? )', {}, split(/\|/,$_) );
}

$dbh->do(q{ CREATE INDEX distverstate ON cpanstats (dist, version, state) });
$dbh->do(q{ CREATE INDEX ixdate ON cpanstats (postdate) });
$dbh->do(q{ CREATE INDEX ixperl ON cpanstats (perl) });
$dbh->do(q{ CREATE INDEX ixplat ON cpanstats (platform) });

my ($ct) = $dbh->selectrow_array('select count(*) from cpanstats');

$dbh->disconnect;

is($ct, 99, "row count for cpanstats");

#select * from cpanstats where state='cpan' and dist in ('AEAE', 'AI-NeuralNet-BackProp', 'AI-NeuralNet-Mesh', 'AI-NeuralNet-SOM', 'AOL-TOC', 'Abstract-Meta-Class', 'Acme', 'Acme-Anything', 'Acme-BOPE', 'Acme-Brainfuck', 'Acme-Buffy', 'Acme-CPANAuthors-Canadian', 'Acme-CPANAuthors-CodeRepos', 'Acme-CPANAuthors-French', 'Acme-CPANAuthors-Japanese');
# sqlite> select * from cpanstats where postdate=200901 order by dist limit 20;
# id|guid|state|postdate|tester|dist|version|platform|perl|osname|osvers|date
__DATA__
104440|104440-b19f-3f77-b713-d32bba55d77f|unknown|200310|kriegjcb@mi.ruhr-uni-bochum.de ((Jost Krieger))|AI-NeuralNet-Mesh|0.44|sun4-solaris|5.8.1|solaris|2.8|200310061151
1396564|1396564-b19f-3f77-b713-d32bba55d77f|unknown|200805|srezic@cpan.org|Acme-Buffy|1.5|i386-freebsd|5.5.5|freebsd|6.1-release|200805022114
1544358|1544358-b19f-3f77-b713-d32bba55d77f|na|200805|jj@jonallen.info ("JJ")|AI-NeuralNet-SOM|0.07|darwin-2level|5.8.3|darwin|7.9.0|200805290833
1587804|1587804-b19f-3f77-b713-d32bba55d77f|na|200806|jj@jonallen.info ("JJ")|AI-NeuralNet-SOM|0.07|darwin-2level|5.8.1|darwin|7.9.0|200806030648
1717321|1717321-b19f-3f77-b713-d32bba55d77f|na|200806|srezic@cpan.org|Abstract-Meta-Class|0.10|i386-freebsd|5.5.5|freebsd|6.1-release|200806171653
1994346|1994346-b19f-3f77-b713-d32bba55d77f|unknown|200808|srezic@cpan.org|AI-NeuralNet-SOM|0.02|i386-freebsd|5.6.2|freebsd|6.1-release|200808062212
2538246|2538246-b19f-3f77-b713-d32bba55d77f|fail|200811|bingos@cpan.org|Acme-CPANAuthors-French|0.06|i386-freebsd-thread-multi-64int|5.8.8|freebsd|6.2-release|200811021014
2549071|2549071-b19f-3f77-b713-d32bba55d77f|fail|200811|bingos@cpan.org|Acme-CPANAuthors-French|0.07|OpenBSD.i386-openbsd-thread-multi-64int|5.8.8|openbsd|4.2|200811042025
2603754|2603754-b19f-3f77-b713-d32bba55d77f|fail|200811|JOST@cpan.org ("Josts Smokehouse")|AI-NeuralNet-SOM|0.02|i86pc-solaris-64int|5.8.8 patch 34559|solaris|2.11|200811122105
2613077|2613077-b19f-3f77-b713-d32bba55d77f|fail|200811|srezic@cpan.org|Acme-Buffy|1.5|i386-freebsd|5.8.9|freebsd|6.1-release-p23|200811132053
2725989|2725989-b19f-3f77-b713-d32bba55d77f|pass|200812|stro@cpan.org|Acme-CPANAuthors-Canadian|0.0101|MSWin32-x86-multi-thread|5.10.0|MSWin32|5.00|200812011303
2959417|2959417-b19f-3f77-b713-d32bba55d77f|pass|200812|rhaen@cpan.org (Ulrich Habel)|Abstract-Meta-Class|0.11|MSWin32-x86-multi-thread|5.10.0|MSWin32|5.1|200812301529
2964284|2964284-b19f-3f77-b713-d32bba55d77f|pass|200901|imacat@mail.imacat.idv.tw|Acme|1.11111|x86_64-linux-thread-multi-ld|5.10.0|linux|2.6.24-etchnhalf.1-amd64|200901010443
2964285|2964285-b19f-3f77-b713-d32bba55d77f|pass|200901|imacat@mail.imacat.idv.tw|Acme-Buffy|1.5|x86_64-linux-thread-multi-ld|5.10.0|linux|2.6.24-etchnhalf.1-amd64|200901010443
2964537|2964537-b19f-3f77-b713-d32bba55d77f|pass|200901|imacat@mail.imacat.idv.tw|Acme-CPANAuthors-CodeRepos|0.080522|x86_64-linux-thread-multi-ld|5.10.0|linux|2.6.24-etchnhalf.1-amd64|200901010609
2964541|2964541-b19f-3f77-b713-d32bba55d77f|pass|200901|imacat@mail.imacat.idv.tw|Acme-CPANAuthors-Japanese|0.080522|x86_64-linux-thread-multi-ld|5.10.0|linux|2.6.24-etchnhalf.1-amd64|200901010611
2965412|2965412-b19f-3f77-b713-d32bba55d77f|pass|200901|imacat@mail.imacat.idv.tw|Acme-Brainfuck|1.1.1|x86_64-linux-thread-multi-ld|5.10.0|linux|2.6.24-etchnhalf.1-amd64|200901010929
2965930|2965930-b19f-3f77-b713-d32bba55d77f|pass|200901|imacat@mail.imacat.idv.tw|AI-NeuralNet-BackProp|0.89|x86_64-linux-thread-multi-ld|5.10.0|linux|2.6.24-etchnhalf.1-amd64|200901011103
2965931|2965931-b19f-3f77-b713-d32bba55d77f|pass|200901|imacat@mail.imacat.idv.tw|AI-NeuralNet-Mesh|0.44|x86_64-linux-thread-multi-ld|5.10.0|linux|2.6.24-etchnhalf.1-amd64|200901011103
2966360|2966360-b19f-3f77-b713-d32bba55d77f|pass|200901|cpan@sourcentral.org ("Oliver Paukstadt")|AI-NeuralNet-SOM|0.07|s390x-linux|5.10.0|linux|2.6.16.60-0.31-default|200901010542
2966429|2966429-b19f-3f77-b713-d32bba55d77f|pass|200901|cpan@sourcentral.org ("Oliver Paukstadt")|Acme-BOPE|0.01|s390x-linux|5.8.8|linux|2.6.16.60-0.31-default|200901010558
2966541|2966541-b19f-3f77-b713-d32bba55d77f|pass|200901|cpan@sourcentral.org ("Oliver Paukstadt")|Acme-CPANAuthors-Canadian|0.0101|s390x-linux-thread-multi|5.8.8|linux|2.6.18-92.1.18.el5|200901010628
2966560|2966560-b19f-3f77-b713-d32bba55d77f|fail|200901|cpan@sourcentral.org ("Oliver Paukstadt")|Acme-CPANAuthors-French|0.07|s390x-linux-thread-multi|5.8.8|linux|2.6.18-92.1.18.el5|200901010635
2966567|2966567-b19f-3f77-b713-d32bba55d77f|pass|200901|cpan@sourcentral.org ("Oliver Paukstadt")|Acme-CPANAuthors-CodeRepos|0.080522|s390x-linux|5.10.0|linux|2.6.16.60-0.31-default|200901010638
2966771|2966771-b19f-3f77-b713-d32bba55d77f|pass|200901|imacat@mail.imacat.idv.tw|AEAE|0.02|x86_64-linux-thread-multi-ld|5.10.0|linux|2.6.24-etchnhalf.1-amd64|200901011502
2967174|2967174-b19f-3f77-b713-d32bba55d77f|pass|200901|imacat@mail.imacat.idv.tw|AOL-TOC|0.340|x86_64-linux-thread-multi-ld|5.10.0|linux|2.6.24-etchnhalf.1-amd64|200901011645
2967432|2967432-b19f-3f77-b713-d32bba55d77f|fail|200901|andreas.koenig.gmwojprw@franz.ak.mind.de|Acme-CPANAuthors-French|0.07|x86_64-linux|5.10.0|linux|2.6.24-1-amd64|200901011038
2967647|2967647-b19f-3f77-b713-d32bba55d77f|pass|200901|imacat@mail.imacat.idv.tw|Acme-Anything|0.02|x86_64-linux-thread-multi-ld|5.10.0|linux|2.6.24-etchnhalf.1-amd64|200901011830
2969433|2969433-b19f-3f77-b713-d32bba55d77f|pass|200901|CPAN.DCOLLINS@comcast.net|Abstract-Meta-Class|0.11|i686-linux-thread-multi|5.10.0|linux|2.6.24-19-generic|200901010115
2969661|2969661-b19f-3f77-b713-d32bba55d77f|pass|200901|CPAN.DCOLLINS@comcast.net|Abstract-Meta-Class|0.11|i686-linux-thread-multi|5.10.0|linux|2.6.24-19-generic|200901010303
2969663|2969663-b19f-3f77-b713-d32bba55d77f|pass|200901|CPAN.DCOLLINS@comcast.net|Abstract-Meta-Class|0.11|i686-linux-thread-multi|5.10.0|linux|2.6.24-19-generic|200901010303
2970367|2970367-b19f-3f77-b713-d32bba55d77f|pass|200901|CPAN.DCOLLINS@comcast.net|Abstract-Meta-Class|0.11|i686-linux-thread-multi|5.11.0 patch GitLive-blead-163-g28b1dae|linux|2.6.24-19-generic|200901010041
2975969|2975969-b19f-3f77-b713-d32bba55d77f|pass|200901|rhaen@cpan.org (Ulrich Habel)|Acme-CPANAuthors-Japanese|0.090101|MSWin32-x86-multi-thread|5.10.0|MSWin32|5.1|200901021220
11278|11278-b19f-3f77-b713-d32bba55d77f|cpan|200006|JHARDING|AOL-TOC|0.32||0|||200006281749
11422|11422-b19f-3f77-b713-d32bba55d77f|cpan|200007|JHARDING|AOL-TOC|0.33||0|||200007040912
11989|11989-b19f-3f77-b713-d32bba55d77f|cpan|200007|JBRYAN|AI-NeuralNet-BackProp|0.40||0|||200007220918
12095|12095-b19f-3f77-b713-d32bba55d77f|cpan|200007|JBRYAN|AI-NeuralNet-BackProp|0.42||0|||200007261138
12605|12605-b19f-3f77-b713-d32bba55d77f|cpan|200008|JBRYAN|AI-NeuralNet-BackProp|0.77||0|||200008121011
12822|12822-b19f-3f77-b713-d32bba55d77f|cpan|200008|JBRYAN|AI-NeuralNet-BackProp|0.89||0|||200008170921
13051|13051-b19f-3f77-b713-d32bba55d77f|cpan|200008|JHARDING|AOL-TOC|0.340||0|||200008220610
13066|13066-b19f-3f77-b713-d32bba55d77f|cpan|200008|JBRYAN|AI-NeuralNet-Mesh|0.20||0|||200008230741
13133|13133-b19f-3f77-b713-d32bba55d77f|cpan|200008|JBRYAN|AI-NeuralNet-Mesh|0.31||0|||200008251025
13828|13828-b19f-3f77-b713-d32bba55d77f|cpan|200009|JBRYAN|AI-NeuralNet-Mesh|0.43||0|||200009141053
13880|13880-b19f-3f77-b713-d32bba55d77f|cpan|200009|JBRYAN|AI-NeuralNet-Mesh|0.44||0|||200009142256
14426|14426-b19f-3f77-b713-d32bba55d77f|cpan|200009|VOISCHEV|AI-NeuralNet-SOM|0.01||0|||200009292037
14530|14530-b19f-3f77-b713-d32bba55d77f|cpan|200010|VOISCHEV|AI-NeuralNet-SOM|0.02||0|||200010042041
23502|23502-b19f-3f77-b713-d32bba55d77f|cpan|200105|LBROCARD|Acme-Buffy|1.1||0|||200105221815
26042|26042-b19f-3f77-b713-d32bba55d77f|cpan|200108|LBROCARD|Acme-Buffy|1.2||0|||200108121353
36109|36109-b19f-3f77-b713-d32bba55d77f|cpan|200203|LBROCARD|Acme-Buffy|1.3||0|||200203271437
58944|58944-b19f-3f77-b713-d32bba55d77f|cpan|200209|JALDHAR|Acme-Brainfuck|1.0.0||0|||200209032115
104368|104368-b19f-3f77-b713-d32bba55d77f|cpan|200310|JESSE|Acme-Buffy|1.3||0|||200310051219
128571|128571-b19f-3f77-b713-d32bba55d77f|cpan|200403|INGY|Acme|1.00||0|||200403211232
128577|128577-b19f-3f77-b713-d32bba55d77f|cpan|200403|INGY|Acme|1.11||0|||200403211307
128615|128615-b19f-3f77-b713-d32bba55d77f|cpan|200403|INGY|Acme|1.111||0|||200403212239
131264|131264-b19f-3f77-b713-d32bba55d77f|cpan|200404|JALDHAR|Acme-Brainfuck|1.1.0||0|||200404060730
131340|131340-b19f-3f77-b713-d32bba55d77f|cpan|200404|JALDHAR|Acme-Brainfuck|1.1.1||0|||200404061825
194191|194191-b19f-3f77-b713-d32bba55d77f|cpan|200503|INGY|Acme|1.1111||0|||200503270846
283938|283938-b19f-3f77-b713-d32bba55d77f|cpan|200601|INGY|Acme|1.11111||0|||200601190015
286799|286799-b19f-3f77-b713-d32bba55d77f|cpan|200601|JETEVE|AEAE|0.01||0|||200601311729
288796|288796-b19f-3f77-b713-d32bba55d77f|cpan|200602|JETEVE|AEAE|0.02||0|||200602101119
347205|347205-b19f-3f77-b713-d32bba55d77f|cpan|200609|LBROCARD|Acme-Buffy|1.4||0|||200609081831
469300|469300-b19f-3f77-b713-d32bba55d77f|cpan|200704|LBROCARD|Acme-Buffy|1.5||0|||200704281603
502506|502506-b19f-3f77-b713-d32bba55d77f|cpan|200706|DRRHO|AI-NeuralNet-SOM|0.01||0|||200706051723
505918|505918-b19f-3f77-b713-d32bba55d77f|cpan|200706|DRRHO|AI-NeuralNet-SOM|0.02||0|||200706101701
509756|509756-b19f-3f77-b713-d32bba55d77f|cpan|200706|DRRHO|AI-NeuralNet-SOM|0.03||0|||200706142113
510429|510429-b19f-3f77-b713-d32bba55d77f|cpan|200706|DRRHO|AI-NeuralNet-SOM|0.04||0|||200706171333
552718|552718-b19f-3f77-b713-d32bba55d77f|cpan|200708|JJORE|Acme-Anything|0.01||0|||200708020003
759609|759609-b19f-3f77-b713-d32bba55d77f|cpan|200711|JJORE|Acme-Anything|0.02||0|||200711120124
892719|892719-b19f-3f77-b713-d32bba55d77f|cpan|200712|ISHIGAKI|Acme-CPANAuthors-Japanese|0.071226||0|||200712260945
962536|962536-b19f-3f77-b713-d32bba55d77f|cpan|200801|DRRHO|AI-NeuralNet-SOM|0.05||0|||200801162101
1409538|1409538-b19f-3f77-b713-d32bba55d77f|cpan|200805|ADRIANWIT|Abstract-Meta-Class|0.01||0|||200805051729
1415536|1415536-b19f-3f77-b713-d32bba55d77f|cpan|200805|ADRIANWIT|Abstract-Meta-Class|0.03||0|||200805062227
1498300|1498300-b19f-3f77-b713-d32bba55d77f|cpan|200805|ISHIGAKI|Acme-CPANAuthors-Japanese|0.080522||0|||200805211910
1498366|1498366-b19f-3f77-b713-d32bba55d77f|cpan|200805|ISHIGAKI|Acme-CPANAuthors-CodeRepos|0.080522||0|||200805211928
1506861|1506861-b19f-3f77-b713-d32bba55d77f|cpan|200805|DRRHO|AI-NeuralNet-SOM|0.06||0|||200805231024
1511634|1511634-b19f-3f77-b713-d32bba55d77f|cpan|200805|ADRIANWIT|Abstract-Meta-Class|0.04||0|||200805240233
1513135|1513135-b19f-3f77-b713-d32bba55d77f|cpan|200805|DRRHO|AI-NeuralNet-SOM|0.07||0|||200805240907
1516187|1516187-b19f-3f77-b713-d32bba55d77f|cpan|200805|ADRIANWIT|Abstract-Meta-Class|0.05||0|||200805241805
1520619|1520619-b19f-3f77-b713-d32bba55d77f|cpan|200805|ADRIANWIT|Abstract-Meta-Class|0.06||0|||200805251816
1565336|1565336-b19f-3f77-b713-d32bba55d77f|cpan|200805|ADRIANWIT|Abstract-Meta-Class|0.07||0|||200805312254
1572634|1572634-b19f-3f77-b713-d32bba55d77f|cpan|200806|ADRIANWIT|Abstract-Meta-Class|0.08||0|||200806012045
1574627|1574627-b19f-3f77-b713-d32bba55d77f|cpan|200806|ADRIANWIT|Abstract-Meta-Class|0.09||0|||200806020147
1645288|1645288-b19f-3f77-b713-d32bba55d77f|cpan|200806|ADRIANWIT|Abstract-Meta-Class|0.10||0|||200806082355
2159274|2159274-b19f-3f77-b713-d32bba55d77f|cpan|200809|ADRIANWIT|Abstract-Meta-Class|0.11||0|||200809080024
2204397|2204397-b19f-3f77-b713-d32bba55d77f|cpan|200809|SAPER|Acme-CPANAuthors-French|0.01||0|||200809130310
2214457|2214457-b19f-3f77-b713-d32bba55d77f|cpan|200809|SAPER|Acme-CPANAuthors-French|0.02||0|||200809140323
2238296|2238296-b19f-3f77-b713-d32bba55d77f|cpan|200809|SAPER|Acme-CPANAuthors-French|0.03||0|||200809180204
2256533|2256533-b19f-3f77-b713-d32bba55d77f|cpan|200809|SAPER|Acme-CPANAuthors-French|0.04||0|||200809210208
2265432|2265432-b19f-3f77-b713-d32bba55d77f|cpan|200809|GARU|Acme-BOPE|0.01||0|||200809220715
2269831|2269831-b19f-3f77-b713-d32bba55d77f|cpan|200809|SAPER|Acme-CPANAuthors-French|0.05||0|||200809222335
2459148|2459148-b19f-3f77-b713-d32bba55d77f|cpan|200810|ADRIANWIT|Abstract-Meta-Class|0.12||0|||200810191536
2518131|2518131-b19f-3f77-b713-d32bba55d77f|cpan|200810|SAPER|Acme-CPANAuthors-French|0.06||0|||200810292228
2538814|2538814-b19f-3f77-b713-d32bba55d77f|cpan|200811|SAPER|Acme-CPANAuthors-French|0.07||0|||200811022251
2538875|2538875-b19f-3f77-b713-d32bba55d77f|cpan|200811|ZOFFIX|Acme-CPANAuthors-Canadian|0.0101||0|||200811022323
2676844|2676844-b19f-3f77-b713-d32bba55d77f|cpan|200811|ADRIANWIT|Abstract-Meta-Class|0.13||0|||200811240039
2963931|2963931-b19f-3f77-b713-d32bba55d77f|cpan|200812|ISHIGAKI|Acme-CPANAuthors-Japanese|0.090101||0|||200812311942
3000000|3000000-b19f-3f77-b713-d32bba55d77f|cpan|200901|BARBIE|App-Maisha|0.01||0|||200901010135
3000001|3000001-b19f-3f77-b713-d32bba55d77f|fail|200901|cpan@sourcentral.org ("Oliver Paukstadt")|App-Maisha|0.01|s390x-linux-thread-multi|5.8.8|linux|2.6.18-92.1.18.el5|200901010635
3000002|3000002-b19f-3f77-b713-d32bba55d77f|pass|200901|cpan@sourcentral.org ("Oliver Paukstadt")|App-Maisha|0.01|s390x-linux|5.10.0|linux|2.6.16.60-0.31-default|200901010638
