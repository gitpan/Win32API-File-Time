#!/usr/bin/perl

use strict;
use warnings;
use File::Spec;
use POSIX qw{strftime};
use Test;

my $test_num = 1;
my $loaded;
BEGIN { $| = 1; plan (tests => 4);
    print "# Test 1 - Loading the library.\n"}
END {print "not ok 1\n" unless $loaded;}
use Win32API::File::Time qw{GetFileTime SetFileTime utime};
$loaded = 1;
ok ($loaded);

my $me = File::Spec->rel2abs ($0);
my $df = '%d-%b-%Y %H:%M:%S';

print "# This file is $me\n";
my ($patim, $pmtim, $pctim);
(undef, undef, undef, undef, undef, undef, undef, undef,
    $patim, $pmtim, $pctim, undef, undef) = stat ($me);
defined $patim ? pftime ($patim, $pmtim, $pctim) : print <<eod;
# Error - stat $me
#         $!
#         $^E
eod


$test_num++;
my $rslt;
print "# Test $test_num - Get file times.\n";
my ($atime, $mtime, $ctime) = GetFileTime ($me);
$rslt = $mtime == $pmtim && $ctime == $pctim;
ok ($rslt);
$rslt ? pftime ($atime, $mtime, $ctime) : print <<eod;
# GetFileTime failed.
# $^E
eod

$test_num++;
print "# Test $test_num - Set the access and modification with SetFileTime.\n";
my $now = time () - 5;
$rslt = SetFileTime ($me, $now, $now) and do {
    my ($patim, $pmtim, $pctim);
    (undef, undef, undef, undef, undef, undef, undef, undef,
	$patim, $pmtim, $pctim, undef, undef) = stat ($me);
    $rslt = $pmtim == $now;	# Don't test atime, because of resolution.
    };
ok ($rslt);
$rslt or print <<eod;
# SetFileTime failed.
# $^E
eod

$test_num++;
print "# Test $test_num - Set the access and modification with utime.\n";
$now += 5;
$rslt = utime $now, $now, $me and do {
    my ($patim, $pmtim, $pctim);
    (undef, undef, undef, undef, undef, undef, undef, undef,
	$patim, $pmtim, $pctim, undef, undef) = stat ($me);
    $rslt = $pmtim == $now;	# Don't test atime, because of resolution.
    };
ok ($rslt);
$rslt or print <<eod;
# utime failed.
# $^E
eod


sub pftime {
my ($sat, $smt, $sct) = map {strftime $df, localtime $_} @_;
print <<eod;
# Accessed: $sat
# Modified: $smt
#  Created: $sct
eod
}
sub sftime {
map {strftime $df, localtime $_} @_
}

