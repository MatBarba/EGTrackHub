use 5.10.0;
use ExtUtils::MakeMaker;

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME         => 'Bio::EnsEMBL::TrackHub',
    VERSION_FROM => 'modules/Bio/EnsEMBL/TrackHub.pm',
    PREREQ_PM    => {
        'HTTP::Request::Common' => '0',
        'JSON'                  => '0',
        'Log::Log4perl'         => '0',
        'LWP::UserAgent'        => '0',
        'Moose'                 => '0',
        'namespace::autoclean'  => '0',
        'Perl6::Slurp'          => '0',
        'Readonly'              => '0',
        'Test::Exception'       => '0',
        'Test::File'            => '0',
    },
    #ABSTRACT_FROM => 'modules/Bio/EnsEMBL/TrackHub.pm',
    AUTHOR        => 'mbarba <mbarba@ebi.ac.uk>',
    LICENSE       => 'apache',
);
