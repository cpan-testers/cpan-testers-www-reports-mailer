use ExtUtils::MakeMaker;
WriteMakefile(
    'NAME'          => 'CPAN::Testers::WWW::Reports::Mailer',
    'VERSION_FROM'  => 'lib/CPAN/Testers/WWW/Reports/Mailer.pm',
    'PREREQ_PM'     => {

        'Compress::Zlib'                    => 0,
        'Config::IniFiles'                  => 0,
        'Class::Accessor::Chained::Fast'    => 0,
        'CPAN::Testers::Common::DBUtils'    => 0.03,
        'Email::Address'                    => 0,
        'Email::Simple'                     => 0,
        'File::Basename'                    => 0,
        'File::Slurp'                       => 0,
        'Getopt::ArgvFile'                  => 0,
        'Getopt::Long'                      => 0,
        'LWP::UserAgent'                    => 0,
        'MIME::Base64'                      => 0,
        'MIME::QuotedPrint'                 => 0,
        'Path::Class'                       => 0,
        'Parse::CPAN::Authors'              => 0,
        'Template'                          => 0,
        'Time::Piece'                       => 0,
        'version'                           => 0,

        'DBD::mysql'                        => 0,
        'DBD::SQLite'                       => '1.07',

    },

    'INSTALLDIRS'   => 'site',
    'EXE_FILES'     => [ 'bin/cpanreps-mailer' ],

    NO_META             => 1,

    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      (ABSTRACT	=> 'CPAN Testers Reports Mailer',
       AUTHOR	=> 'Barbie <barbie@cpan.org>') : ()),
);
