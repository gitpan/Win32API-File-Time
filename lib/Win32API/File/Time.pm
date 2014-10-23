=head1 NAME

Win32API::File::Time - Set file times, even on open or readonly files.

=head1 SYNOPSIS

 use Win32API::File::Time qw{:win};
 ($atime, $mtime, $ctime) = GetFileTime ($filename);
 SetFileTime ($filename, $atime, $mtime, $ctime);

or

 use Win32API::File::Time qw{utime};
 utime $atime, $mtime, $filename or die $^E;

=head1 DESCRIPTION

The purpose of Win32API::File::Time is to provide maximal access to
the file creation, modification, and access times under MSWin32.

Under Windows, the Perl utime module will not modify the time of an
open file, nor a read-only file. The comments in win32.c indicate
that this is the intended functionality, at least for read-only
files.

This module will read and modify the time on open files, read-only
files, and directories. I<Caveat user.>

This module is based on the SetFileTime function in kernel32.dll.
Perl's utime built-in also makes explicit use of this function if
the "C" run-time version of utime fails. The difference is in how
the filehandle is created. The Perl built-in requests access
GENERIC_READ | GENERIC_WRITE when modifying file dates, whereas
this module requests access FILE_WRITE_ATTRIBUTES.

Nothing is exported by default, but all documented subroutines
are exportable. In addition, the following export tags are
supported:

 :all => exports everything exportable
 :win => exports GetFileTime and SetFileTime

Wide system calls are implemented (based on the truth of
${^WIDE_SYSTEM_CALLS}) but not currently supported. In other words: I
wrote the code, but haven't tested it and don't have any plans to.
Feedback will be accepted, and implemented when I get a sufficient
supply of tuits.

=over 4

=cut

#	Modifications:

# 0.001	13-May-2004	T. R. Wyant
#		Initial version.
# 0.002	02-Oct-2004	T. R. Wyant
#		No code changes. Add the readme file to the manifest,
#		and add the dependencies to Makefile.PL, since they
#		really _should_ be there, and Active State is
#		complaining about them missing.
# 0.003	17-Dec-2004	T. R. Wyant
#		Reimplement time conversion. Also modified the self-
#		test to use a scratch file for the date modification
#		portion of the test.
# 0.003_01 28-Dec-2004	T. R. Wyant
#		Close handles after use. In case of error, preserve
#		the windows error around the close.
# 0.004	13-Jan-2005	T. R. Wyant
#		Fix export tags.
#		Tweak "Bugs" section to more accurately represent what
#			I think is going on.
#		Release to CPAN.
# 0.004_01 28-Apr-2005	T. R. Wyant
#		Assert FILE_FLAG_BACKUP_SEMANTICS when reading times,
#			so that it works for directories under XP and
#			2003 server.
#		Centralize code to close handles on error.
# 0.004_02 04-May-2005	T. R. Wyant
#		Document behaviour of FAT (and change test to
#		accomodate.
# 0.005 04-May-2005	T. R. Wyant
#		Release to CPAN.

use strict;
use warnings;

package Win32API::File::Time;

use base qw{Exporter};
use vars qw{@EXPORT_OK %EXPORT_TAGS $VERSION};
use vars qw{
	$FileTimeToSystemTime
	$FileTimeToLocalFileTime
	$GetFileTime
	$LocalFileTimeToFileTime
	$SetFileTime
	$SystemTimeToFileTime
	};

use Carp;
use Time::Local;
use Win32::API;
use Win32API::File qw{:ALL};

$VERSION = '0.006';

@EXPORT_OK = qw{GetFileTime SetFileTime utime};
%EXPORT_TAGS = (
    all => [@EXPORT_OK],
    win => [qw{GetFileTime SetFileTime}],
    );

=item ($atime, $mtime, $ctime) = GetFileTime ($filename);

This subroutine returns the access, modification, and creation times of
the given file. If it fails, nothing is returned, and the error code
can be found in $^E.

No, there's no additional functionality here versus the stat
built-in. But it was useful for development and testing, and
has been exposed for orthogonality's sake.

=cut

sub GetFileTime {
my $fn = shift or croak "usage: GetFileTime (filename)";
my $fh = _get_handle ($fn) or return;
$GetFileTime ||= _map ('KERNEL32', 'GetFileTime', [qw{N P P P}], 'I');
my ($atime, $mtime, $ctime);
$atime = $mtime = $ctime = pack 'LL', 0, 0;	# Preallocate 64 bits.
$GetFileTime->Call ($fh, $ctime, $atime, $mtime) or
    return _close_handle ($fh);
CloseHandle ($fh);
return _filetime_to_perltime ($atime, $mtime, $ctime);
}


=item SetFileTime (filename, atime, mtime, ctime);

This subroutine sets the access, modification, and creation times of
the given file. The return is true for success, and false for failure.
In the latter case, $^E will contain the error.

If you don't want to set all of the times, pass 0 or undef for the
times you don't want to set. For example,

 $now = time ();
 SetFileTime ($filename, $now, $now);

is equivalent to the "touch" command for the given file.

=cut

sub SetFileTime {
my $fn = shift or croak "usage: SetFileTime (filename, atime, mtime, ctime)";
my $atime = _perltime_to_filetime (shift);
my $mtime = _perltime_to_filetime (shift);
my $ctime = _perltime_to_filetime (shift);
# We assume we can do something useful for an undef.
$SetFileTime ||= _map ('KERNEL32', 'SetFileTime', [qw{N P P P}], 'I');
my $fh = _get_handle ($fn, 1) or return;

$SetFileTime->Call ($fh, $ctime, $atime, $mtime) or
    return _close_handle ($fh);

CloseHandle ($fh);
return 1;
}

=item utime ($atime, $mtime, $filename, ...)

This subroutine overrides the built-in of the same name. It does
exactly the same thing, but has a different idea than the built-in
about what files are legal to change.

Like the core utime, it returns the number of files successfully
modified. If not all files can be modified, $^E contains the last
error encountered.

=cut

sub utime {
my $atime = shift;
my $mtime = shift;
my $num = 0;
foreach my $fn (@_) {
    SetFileTime ($fn, $atime, $mtime) and $num++;
    }
return $num;
}


#######################################################################
#
#	Internal subroutines
#
#	_close_handle
#
#	This subroutine closes the given handle, preserving status
#	around the call.

sub _close_handle {
my $fh = shift;
my $err = Win32::GetLastError ();
CloseHandle ($fh);
$^E = $err;
return;
}


#	_filetime_to_perltime
#
#	This subroutine takes as input a number of Windows file times
#	and converts them to Perl times.
#
#	The algorithm is due to the unsung heros at Hip Communications
#	Inc (currently known as ActiveState), who found a way around
#	the fact that Perl and Windows have a fundamentally different
#	idea of what local time corresponds to a given GMT when summer
#	time was in effect at the given GMT, but not at the time the
#	conversion is made. The given algorithm is consistent with the
#	results of the stat () function.

sub _filetime_to_perltime {
my @result;
$FileTimeToSystemTime ||= _map (
	'KERNEL32', 'FileTimeToSystemTime', [qw{P P}], 'I');
$FileTimeToLocalFileTime ||= _map (
	'KERNEL32', 'FileTimeToLocalFileTime', [qw{P P}], 'I');
my $st = pack 'ssssssss', 0, 0, 0, 0, 0, 0, 0, 0;
foreach my $ft (@_) {
    my ($low, $high) = unpack 'LL', $ft;
    $high or do {
	push @result, undef;
	next;
	};
    my $lf = $ft;	# Just to get the space allocated.
    $FileTimeToLocalFileTime->Call ($ft, $lf) &&
	$FileTimeToSystemTime->Call ($lf, $st) or do {
	push @result, undef;
	next;
	};
    my @tm = unpack 'ssssssss', $st;
    push @result, $tm[0] > 0 ?
	timelocal (@tm[6, 5, 4, 3], $tm[1] - 1, $tm[0]) :
	undef;
    }
return wantarray ? @result : $result[0];
}


#	_get_handle
#
#	This subroutine takes a file name and returns a handle to the
#	file. If the second argument is true, the handle is configured
#	appropriately for  writing attributes; otherwise it is
#	configured appropriately for reading attributes.

sub _get_handle {
my $fn = shift;
my $write = shift;

${^WIDE_SYSTEM_CALLS} ?
    CreateFileW ($fn,
	($write ? FILE_WRITE_ATTRIBUTES : FILE_READ_ATTRIBUTES),
	($write ? FILE_SHARE_WRITE | FILE_SHARE_READ : FILE_SHARE_READ),
	[],
	OPEN_EXISTING,
	($write ? FILE_ATTRIBUTE_NORMAL | FILE_FLAG_BACKUP_SEMANTICS : FILE_FLAG_BACKUP_SEMANTICS),
	0,
	) :
    CreateFile ($fn,
	($write ? FILE_WRITE_ATTRIBUTES : FILE_READ_ATTRIBUTES),
	($write ? FILE_SHARE_WRITE | FILE_SHARE_READ : FILE_SHARE_READ),
	[],
	OPEN_EXISTING,
	($write ? FILE_ATTRIBUTE_NORMAL | FILE_FLAG_BACKUP_SEMANTICS : FILE_FLAG_BACKUP_SEMANTICS),
	0,
	)
  or do {
    $^E = Win32::GetLastError ();
    return;
    };
}


#	_map
#
#	This subroutine calls Win32API to map an entry point.

sub _map {
return Win32::API->new (@_) ||
    croak "Error - Failed to map $_[1] from $_[0]: $^E";
}


#	_perltime_to_filetime
#
#	This subroutine converts perl times to Windows file times.

#	The same considerations apply to the algorithm used here as to
#	the one used in _filetime_to_perltime.

sub _perltime_to_filetime {
my @result;
$SystemTimeToFileTime ||= _map (
	'KERNEL32', 'SystemTimeToFileTime', [qw{P P}], 'I');
$LocalFileTimeToFileTime ||= _map (
	'KERNEL32', 'LocalFileTimeToFileTime', [qw{P P}], 'I');
my $zero = pack 'LL', 0, 0;	# To get a quadword zero.
my ($ft, $lf) = ($zero, $zero);	# To get the space allocated.
foreach my $pt (@_) {
    if (defined $pt) {
	my @tm = localtime ($pt);
	my $st = pack 'ssssssss', $tm[5] + 1900, $tm[4] + 1, 0,
	    @tm[3, 2, 1, 0], 0;
	push @result, $SystemTimeToFileTime->Call ($st, $lf)  &&
	    $LocalFileTimeToFileTime->Call ($lf, $ft) ? $ft : $zero;
	}
      else {
	push @result, $zero;
	}
    }
return wantarray ? @result : $result[0];
}

=back

=head1 HISTORY

 0.001 Initial release
 0.002 Correct MANIFEST and Makefile.PL dependencies.
       Tweak documentation. No code changes.
 0.003 Correct time conversion.
       Modify test to not change own date.
 0.004 Close handles after use. Thanks to Chris
           Camejo for pointing out the leak.
       Fix export tags to agree with docs.
       Tweak "BUGS" documentation.
 0.005 Assert FILE_FLAG_BACKUP_SEMANTICS when reading
           times, so that it works for directories
           under XP and 2003 server. Thanks to Leigh
           Power for pointing out the problem and
           suggesting the solution.
       Document FAT, and accomodate it in self-test.
           Thanks again, Leigh.
       Centralize code to close handles on error.
 0.006 T. R. Wyant
       Re-layout kit, add POD tests.

=head1 BUGS

As implemented, GetFileTime () constitutes an access, and
therefore updates the access time.

The stat () builtin, on the other hand, doesn't report
an access time change even after GetFileTime () has been
used. In fact, it looks to me very much like stat () reports
the modification time in element [8] of the list, but I
find this nowhere documented.

FAT file time resolution is 2 seconds at best, as documented
at F<http://support.microsoft.com/default.aspx?scid=kb;en-us;127830>.
Access time resolution seems to be to the nearest day.

=head1 ACKNOWLEDGMENTS

This module would not exist without the following people:

Aldo Calpini, who gave us Win32::API.

Tye McQueen, who gave us Win32API::File.

Jenda Krynicky, whose "How2 create a PPM distribution"
(F<http://jenda.krynicky.cz/perl/PPM.html>) gave me a leg up on
both PPM and tar distributions.

The folks of ActiveState (F<http://www.activestate.com/>,
formerly known as Hip Communications), who found a way to reconcile
Windows' and Perl's subtly different ideas of what time it is.

The folks of Cygwin (F<http://www.cygwin.com/>), especially those
who worked on times.cc in the Cygwin core. This is the B<only>
implementation of utime I could find which did what B<I> wanted
it to do.


=head1 AUTHOR

Thomas R. Wyant, III (F<Thomas.R.Wyant-III@usa.dupont.com>)

=head1 COPYRIGHT

Copyright 2004, 2005 by
E. I. DuPont de Nemours and Company, Inc.
All rights reserved.

Changes since version 0.005 copyright 2007 by Thomas R. Wyant, III.  All
rights reserved.

=head1 LICENSE

This module is free software; you can use it, redistribute it and/or
modify it under the same terms as Perl itself. Please see
L<http://perldoc.perl.org/index-license.html> for current licenses.

=cut

