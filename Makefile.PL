use ExtUtils::MakeMaker;
WriteMakefile(
    'NAME'          => 'CPAN::Testers::WWW::Reports::Mailer',
    'VERSION_FROM'  => 'lib/CPAN/Testers/WWW/Reports/Mailer.pm',
    'PREREQ_PM'     => {
        'Cwd'                   => 0,       # only for cpanstats.pl
        'Getopt::Long'          => 0,       # only for cpanstats.pl

        'Class::Accessor::Fast' => 0,
        'CPAN::DistnameInfo'    => 0,
        'DBD::mysql'            => 0,
        'DBD::SQLite'           => '1.07',
        'DBI'                   => 0,
        'Email::Simple'         => 0,
        'File::Basename'        => 0,
        'File::Path'            => 0,

        'Test::More'            => 0,       # only for testing
                   },
    'PL_FILES'      => {},
    'INSTALLDIRS'   => 'site',
    'EXE_FILES'     => [ 'bin/cpanstats-mailer' ],
    NO_META             => 1,

    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      (ABSTRACT	=> 'CPAN Testers Reports Mailer toolset',
       AUTHOR	=> 'Barbie <barbie@cpan.org>') : ()),
);
