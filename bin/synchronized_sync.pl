#!/usr/bin/perl --
# MonArch - Groundwork Monitor Architect
# synchronized_sync.pl
#
############################################################################
# Release 4.0
# November 2011
############################################################################
#
# Author: Glenn Herteg
#
# Copyright 2011 GroundWork Open Source, Inc. (GroundWork)
# All rights reserved. Use is subject to GroundWork commercial license terms.
#
# This script runs a Monarch-to-Foundation sync operation, which is synchronized
# with respect to any pre-flight or commit operations which might be concurrently
# attempted via other means.  That is, interlocks are provided to prevent collisions.
# The effort here takes no action to build Nagios files to construct an updated setup,
# to run a pre-flight operation to validate the setup, or to restart Nagios.

# FIX MINOR:  We need to test what happens if the database is ever inaccessible
# at any point, which can be critical here considering that this script will
# typically be run in an environment with a remote database.

use strict;

# use warnings;

# This parameter might need local tuning under adverse circumstances.
# We cannot access the StorProc copy because it is declared as "my".
my $max_commit_lock_attempts = 20;

use MonarchStorProc;

# Extend MonarchStorProc to provide the additional routines we need.
package StorProc;

sub synchronized_sync(@) {
    my $monarch_home = $_[1];
    my $in_progress_lock;
    my $commit_lock;
    my $errors;
    my $pids;
    my @errors = ();
    my $shutdown_message = 'Shutdown requested; will exit.';
    my @results = ();
    my @timings = ();

    # We catch SIGTERM, SIGINT, and SIGQUIT so we can stop and clean up when we are asked nicely.
    local $SIG{INT}  = \&handle_exit_signal;
    local $SIG{QUIT} = \&handle_exit_signal;
    local $SIG{TERM} = \&handle_exit_signal;

    use MonarchLocks;

    $errors = Locks->open_and_lock( \*in_progress_lock, $Locks::in_progress_file, $Locks::EXCLUSIVE, $Locks::NON_BLOCKING );
    if (@$errors) {
	my @blocking_errors = ();
	if (defined fileno \*in_progress_lock) {
	    my ($pid_errors, $pid_blocks, $pids) = Locks->get_blocking_pids( \*in_progress_lock, $Locks::in_progress_file, $Locks::EXCLUSIVE );
	    if (@$pid_blocks) {
		push @blocking_errors, 'Another pre-flight or commit operation is already in progress.';
		push @blocking_errors, 'Underlying detail:' if @$pid_blocks || @$pid_errors;
		push @blocking_errors, @$pid_blocks;
	    }
	    push @blocking_errors, @$pid_errors;
	    Locks->close_and_unlock( \*in_progress_lock );
	}
	push @errors, @blocking_errors;
	push @errors, @$errors if !@blocking_errors;  # excessive detail
	return \@errors, \@results, \@timings;
    }

    if ( @{ Locks->lock_file_exists( \*in_progress_lock, $Locks::in_progress_file ) } ) {
	Locks->close_and_unlock( \*in_progress_lock );
	push @errors, 'Another pre-flight or commit operation just completed; please re-try your operation if needed.';
	return \@errors, \@results, \@timings;
    }

    my $starttime;
    my $majortime;
    my $phasetime;

    StorProc->start_timing( \$starttime );
    $majortime = $starttime;
    $phasetime = $starttime;

    if ($main::shutdown_requested) {
	Locks->unlink_and_close( \*in_progress_lock, $Locks::in_progress_file );
	push @errors, $shutdown_message;
	return \@errors, \@results, \@timings;
    }

    for ( my $lock_attempts = 1; $lock_attempts <= $max_commit_lock_attempts; ++$lock_attempts ) {
	$errors = Locks->open_and_lock( \*commit_lock, $Locks::commit_lock_file, $Locks::EXCLUSIVE, $Locks::NON_BLOCKING );
	last if !@$errors;
	my @blocking_errors = ();
	my $pid_errors;
	my $pid_blocks;
	my $pids = [];
	if (defined fileno \*commit_lock) {
	    ($pid_errors, $pid_blocks, $pids) = Locks->get_blocking_pids( \*commit_lock, $Locks::commit_lock_file, $Locks::EXCLUSIVE );
	    if (@$pid_blocks) {
		push @blocking_errors, 'Feeders are still operating.';
		push @blocking_errors, 'Underlying detail:' if @$pid_blocks || @$pid_errors;
		push @blocking_errors, @$pid_blocks;
	    }
	    push @blocking_errors, @$pid_errors;
	    Locks->close_and_unlock( \*commit_lock );
	}

	if ($lock_attempts >= $max_commit_lock_attempts) {
	    push @errors, @blocking_errors;
	    push @errors, @$errors if !@blocking_errors;  # excessive detail
	    Locks->unlink_and_close( \*in_progress_lock, $Locks::in_progress_file );
	    StorProc->capture_timing( \@timings, \$phasetime, 'waiting for synchronization file lock' );
	    return \@errors, \@results, \@timings;
	}
	else {
	    ## Uncomment the following lines to identify feeders that refuse to quickly release their locks.
	    ## push @errors, "Lock attempt $lock_attempts:";
	    ## push @errors, @blocking_errors;
	    ## ## push @errors, @$errors;
	}

	kill( 'TERM', @$pids ) if @$pids;
	sleep 3;
	if ($main::shutdown_requested) {
	    Locks->unlink_and_close( \*in_progress_lock, $Locks::in_progress_file );
	    push @errors, $shutdown_message;
	    StorProc->capture_timing( \@timings, \$phasetime, 'waiting for synchronization file lock' );
	    return \@errors, \@results, \@timings;
	}
    }

    utime undef, undef, $Locks::commit_lock_file;
    StorProc->capture_timing( \@timings, \$phasetime, 'waiting for synchronization file lock' );

    if ($main::shutdown_requested) {
	push @errors, 'Shutdown has been requested; Sync has been aborted!';
    }
    unless (@errors) {
	my ($time_ref, $results) = StorProc->timed_sync($monarch_home);
	push @timings, @$time_ref;
	my $got_sync_errors = 0;
	foreach (@$results) {
	    if (/error/i) {
		$got_sync_errors = 1;
	    }
	}
	if ($got_sync_errors) {
	    unshift( @results, 'Error(s) occurred during processing; see below.' );
	}
	push @results, @$results;
	StorProc->capture_timing( \@timings, \$majortime, 'Foundation sync, and Callout submit', 'Summary' );
	StorProc->capture_timing( \@timings, \$starttime, 'Full sync, including all phases,', 'Summary' );
	if ($main::shutdown_requested) {
	    push @errors, 'Shutdown has been requested; Sync has been aborted!';
	}
    }

    Locks->close_and_unlock( \*commit_lock );
    Locks->unlink_and_close( \*in_progress_lock, $Locks::in_progress_file );

    return \@errors, \@results, \@timings;
}

sub timed_sync(@) {
    my $monarch_home = $_[1];
    my @results      = ();
    my @timings      = ();
    my $phasetime;

    start_timing( '', \$phasetime );

    my $sync_results = '';
    my $time_ref;

    use MonarchFoundationSync;

    # FIX LATER
    # Run the Monarch/Foundation sync, with appropriate timeouts on waits for internal phases to complete.
    # On phase wait timeout:
    #     Issue error messages ("Error: Foundation is taking too long to process changes; Sync has been aborted!")
    #         to the log and to the UI or controlling script error stream.   (FIX LATER:  Compare whatever message we
    #         actually generate within FoundationSync->sync() with whatever message we generate in the caller.)
    #     Abort further phase processing.
    # On shutdown requested during sync:
    #     Issue error messages ("Error: Shutdown has been requested; Sync has been aborted!")
    #         to the log and to the UI or controlling script error stream.
    #     Abort further phase processing.

    ($time_ref, $sync_results) = FoundationSync->sync();
    push @timings, @$time_ref;
    push @results, $sync_results;
    capture_timing( '', \@timings, \$phasetime, 'Audit and Foundation sync' );

    if ( $sync_results =~ /error/i ) {
	push @results, 'Warning:  Callout submit function was not called due to error(s) above.';
    }
    elsif ($main::shutdown_requested) {
	push @results, 'Warning:  Callout submit function was not called because early shutdown was requested.';
    }
    else {
	use MonarchCallOut;

	my $callout_results = CallOut->submit($monarch_home);
	push @results, $callout_results if defined $callout_results;
	capture_timing( '', \@timings, \$phasetime, 'Callout submit' );
    }

    return \@timings, \@results;
}

# Now for the main action.

package main;

# Re-open the STDERR stream as a duplicate of the STDOUT stream, to properly
# interleave any output written to STDERR (from, say, debug messages).
if (! open (STDERR, '>>&STDOUT')) {
    print "ERROR:  Can't redirect STDERR to STDOUT: $!\n";
}
else {
    # Autoflush the error output on every single write, to avoid problems
    # with block i/o and badly interleaved output lines on STDOUT and STDERR.
    STDERR->autoflush(1);
}

my $auth = StorProc->dbconnect();

# get config info
my %where = ();
my %objects = StorProc->fetch_list_hash_array( 'setup', \%where );
my $monarch_home = $objects{'monarch_home'}[2];

my ($errors, $results, $timings) = StorProc->synchronized_sync( $monarch_home );

# print "Timings:\n" if @$timings;
print "$_\n" foreach (@$timings);
# print "Results:\n" if @$results;
print "$_\n" foreach (@$results);
# print "Errors:\n"  if @$errors;
print "$_\n" foreach (@$errors);

my $result = StorProc->dbdisconnect();

exit (@$errors ? 1 : 0);

