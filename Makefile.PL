use Config;
use ExtUtils::MakeMaker;

my $vers = $] >= 5.008 ? '-5.8' : '';

WriteMakefile (
	NAME => 'Win32API::File::Time',
	VERSION_FROM => 'Time.pm',
	PREREQ_PM => {
##0.013			'Win32::API' => 0.01,
			'Win32::API' => 0.01,
			'Win32API::File' => 0.09,
			},
#	'linkext' => {LINKTYPE => ''},
	'dist' => {COMPRESS => 'gzip', SUFFIX => 'gz'},
	$] >= 5.005 ? (
		AUTHOR => 'Tom Wyant (Thomas.R.Wyant-III@usa.dupont.com)',
		ABSTRACT => 'Get and set file times in Windows',
		BINARY_LOCATION => "$Config{archname}$vers/Win32API-File-Time.tar.gz",
		) : (),
	);

