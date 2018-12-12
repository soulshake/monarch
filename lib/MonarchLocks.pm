# MonArch - Groundwork Monitor Architect
# MonarchLocks.pm
#
############################################################################
# Release 3.3
# September 2010
############################################################################
#
# Original author: Glenn Herteg
#
# Copyright 2009, 2010 GroundWork Open Source, Inc. (GroundWork)
# All rights reserved. This program is free software; you can redistribute
# it and/or modify it under the terms of the GNU General Public License
# version 2 as published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
#

use strict;
# use warnings;

package Locks;

use Fcntl qw(:DEFAULT :seek);
require File::FcntlLock;

our $in_progress_file = '/usr/local/nagios/var/COMMIT_IN_PROGRESS';
our $commit_lock_file = '/usr/local/nagios/var/COMMIT_LOCKFILE';
our $EXCLUSIVE    = 'exclusive';
our $SHARED       = 'shared';
our $BLOCKING     = 0;
our $NON_BLOCKING = 1;

# FIX FUTURE:  possibly provide a block-with-timeout option, so the caller's loop doesn't need to use non-blocking and sleep;
# that would provide faster lock acquisition when it does finally become available, as the process would not then be asleep
sub open_and_lock {
    my $handle = $_[1];  # passed in to allow locks on multiple files
    my $path   = $_[2];  # path to lock file
    my $type   = $_[3];  # 'shared' or 'exclusive'
    my $try    = $_[4];  # optional; if set, don't block
    my @errors = ();

    my $old_umask = umask 0117;
    if ( !sysopen( $handle, $path, (($type eq $EXCLUSIVE) ? (O_WRONLY | O_APPEND) : (O_RDONLY)) | O_CREAT | O_NOFOLLOW, 0660 ) ) {
	umask $old_umask;
	push @errors, "Cannot open $path: $!";
	return \@errors;
    }
    umask $old_umask;
    my $fs = new File::FcntlLock;
    $fs->l_type( ($type eq $SHARED) ? F_RDLCK : F_WRLCK );
    $fs->l_whence(SEEK_SET);
    $fs->l_start(0);
    $fs->l_len(0);
    # usually a blocking call ...
    if ( !$fs->lock( $handle, $try ? F_SETLK : F_SETLKW ) ) {
	push @errors, "Cannot lock $path: $! (" . $fs->error() . ')';
	return \@errors;
    }

    return \@errors;
}

sub get_blocking_pids {
    my $handle = $_[1];
    my $path   = $_[2];  # path to lock file
    my $type   = $_[3];  # 'shared' or 'exclusive'
    my @errors = ();
    my @blocks = ();
    my @pids   = ();

    # This implementation is Linux-specific.  We use it in preference to fcntl(F_GETLK) because that call
    # just returns one arbitrarily chosen PID of possibly many active locks or blocked lock attempts.
    my ($handdev, $handino) = stat($handle);
    if ( !defined($handdev) ) {
	push @errors, "Error:  cannot stat lockfile ($path).";
	return \@errors, \@blocks, \@pids;
    }
    my $file_id = sprintf ('%02x:%02x:%d', ($handdev >> 8) & 0x00ff, $handdev & 0x00ff, $handino);
    if ( !open (LOCKS, '<', '/proc/locks' ) ) {
	push @errors, "Error:  cannot open /proc/locks to find competing file locks.";
    }
    else {
	while (<LOCKS>) {
	    # 0   1      2         3     4    5
	    # 18: FLOCK  ADVISORY  WRITE 3640 08:03:4686328 0 EOF
	    # 19: POSIX  ADVISORY  WRITE 3616 08:03:4686324 0 EOF
	    # FLOCK is from older flock(); POSIX is from newer lockf() or fcntl()
	    my @fields = split;
	    if ($fields[5] eq $file_id && $fields[1] eq 'POSIX' && ($type eq 'exclusive' || $fields[3] eq 'WRITE') ) {
		push @pids, $fields[4];
		push @blocks, "Process $fields[4] holds a $fields[3] lock on: $path";
	    }
	}
	close LOCKS;
    }
    return \@errors, \@blocks, \@pids;
}

sub lock_file_exists {
    my $handle = $_[1];
    my $path   = $_[2];  # path to lock file
    my @errors = ();

    my ($handdev, $handino) = stat($handle);
    my ($pathdev, $pathino) = stat($path);
    if ( !defined($pathdev) || !defined($handdev) || $pathdev != $handdev || $pathino != $handino) {
	push @errors, "Error:  bad file ($path) is being used for locking.";
	return \@errors;
    }

    return \@errors;
}

sub wait_for_file_to_disappear {
    my $path         = $_[1];
    my $logging_ref  = $_[2];
    my $shutdown_ref = $_[3];

    while ( -e $path ) {
	&$logging_ref("Waiting for $path to disappear.");
	sleep 10;
	return 0 if $$shutdown_ref;
    }
    return 1;
}

# Takes a file handle previously opened by open_and_lock();
# releases the lock and all associated resources.
sub close_and_unlock {
    close $_[1];
}

sub unlink_and_close {
    my $handle = $_[1];
    my $path   = $_[2];  # path to lock file

    unlink $path if $path;
    close $handle;
}

1;

