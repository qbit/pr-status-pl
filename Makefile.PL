use ExtUtils::MakeMaker;

WriteMakefile(
    NAME              => 'pr-status',
    VERSION_FROM      => 'pr-status.pl',
    EXE_FILES         => [qw(pr-status.pl)],
    LICENSE           => 'ISC',
    MIN_PERL_VERSION  => '5.006',
    META_MERGE => {
        'meta-spec' => { version => 2 },
        resources => {
            repository => {
                type => 'git',
                url  => 'https://github.com/qbit/pr-status.git',
                web  => 'https://github.com/qbit/pr-status',
            },
        },
    },
    PREREQ_PM         => {
	    'JSON' => '0',
	    'Mojolicious' => '0',
	    'Git' => '0',
    },
);
