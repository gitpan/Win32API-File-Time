use Config;
use ExtUtils::MakeMaker;

my $vers = sprintf '-%.3f', $];
$vers =~ s/\.0+/./;
$] < 5.008 and $vers = '';

WriteMakefile (
	NAME => 'Win32API::File::Time',
	VERSION_FROM => 'Time.pm',
	PREREQ_PM => {
			'Win32::API' => 0.01,
			'Win32API::File' => 0.09,
			},
#	'linkext' => {LINKTYPE => ''},
	'dist' => {COMPRESS => 'gzip', SUFFIX => 'gz'},
	$] >= 5.005 ? (
		AUTHOR => 'Tom Wyant (Thomas.R.Wyant-III@usa.dupont.com)',
		ABSTRACT => 'Get and set file times in Windows - including open files',
		BINARY_LOCATION => "$Config{archname}$vers/Win32API-File-Time.tar.gz",
		) : (),
	);

