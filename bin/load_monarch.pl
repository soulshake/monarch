#!/usr/local/groundwork/perl/bin/perl -w --

# load_monarch.pl

############################################################################
# Release 4.3
# November 2014
############################################################################
#
# Copyright (c) 2008-2014 Groundwork Open Source, Inc. (GroundWork)
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 2
# as published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.

# 2009-03-24	Thomas Stocking
#		Perl version created to support use of standard database credentials.
# 2011-11-03	Glenn Herteg
#		Ported to support PostgreSQL.
# 2012-03-11	Glenn Herteg
#		Fixed bugs in the PostgreSQL support.
# 2013-07-01	Glenn Herteg
#		Fix SQL command filtering to protect against customer data corruption.
# 2013-07-18	Glenn Herteg
#		Implement locking to prevent concurrent-execution collisions,
#		using our standard Commit Synchronization protocol.  This also
#		blocks interference from actual pre-flight and commit actions,
#		and stops feeders while we're reloading the monarch database.
# 2014-09-12	Glenn Herteg
#		Blank out lines containing the word "dblink" from the monarch database
#		dump before loading the database, to stop permissions problems related
#		to the dblink extension on the parent from blocking a successful load.
# 2014-11-18	Glenn Herteg
#		Edit comments about error handling, to provide clues for future evolution.

use strict;

use IO::Handle;
use MonarchLocks;

# Possible debug levels:
# 0 = print only simple-form error messages
# 1 = print error messages with file and line numbers
# 2 = print error messages with file and line numbers, and all SQL responses
#     (voluminous and generally not of great interest)
my $debug = 1;

# Use standard credentials for Monarch DB manipulation.

my $dbtype;
my $dbhost;
my $dbname;
my $dbuser;
my $dbpass;

my $monarch_file    = '/usr/local/groundwork/nagios/etc/monarch.sql';
my $properties_file = '/usr/local/groundwork/config/db.properties';
my $mysql           = '/usr/local/groundwork/mysql/bin/mysql';
my $psql            = '/usr/local/groundwork/postgresql/bin/psql';
# my $env             = '/usr/bin/env';

# This parameter might need local tuning under adverse circumstances.
my $max_commit_lock_attempts = 20;

# This variable is placed in the main namespace so it can be easily shared
# across all modules in the application that might need access to it.
our $shutdown_requested = 0;

# Here is the entire substance of this script, in a one-liner:
exit (main());

sub main {
    my ($errors, $results, $exit_status) = run_protected_load();
    foreach my $res (@$results) {
        print "$res";
    }
    foreach my $err (@$errors) {
        print "$err\n";
    }
    return $exit_status;
}

sub handle_exit_signal {
    my $signame = shift;
    $main::shutdown_requested = 1;

    # for developer debugging only
    # print "ERROR:  Received SIG$signame; aborting!\n";
}

sub run_protected_load {
    my $in_progress_lock;
    my $commit_lock;
    my $errors;
    my $pids;
    my @errors  = ();
    my @results = ();
    my $exit_status = 1;  # default exit status is an error
    my $shutdown_message = 'Error:  Shutdown has been requested; loading has been aborted!';

    # We catch SIGTERM, SIGINT, and SIGQUIT so we can stop and clean up when we are asked nicely.
    local $SIG{INT}  = \&handle_exit_signal;
    local $SIG{QUIT} = \&handle_exit_signal;
    local $SIG{TERM} = \&handle_exit_signal;

    $errors = Locks->open_and_lock( \*in_progress_lock, $Locks::in_progress_file, $Locks::EXCLUSIVE, $Locks::NON_BLOCKING );
    if (@$errors) {
	my @blocking_errors = ();
	if (defined fileno \*in_progress_lock) {
	    my ($pid_errors, $pid_blocks, $pids) = Locks->get_blocking_pids( \*in_progress_lock, $Locks::in_progress_file, $Locks::EXCLUSIVE );
	    if (@$pid_blocks) {
		push @blocking_errors, 'Error:  Another load or pre-flight or commit operation is already in progress.';
		push @blocking_errors, 'Underlying detail:' if @$pid_blocks || @$pid_errors;
		push @blocking_errors, @$pid_blocks;
	    }
	    push @blocking_errors, @$pid_errors;
	    Locks->close_and_unlock( \*in_progress_lock );
	}
	push @errors, @blocking_errors;
	push @errors, @$errors if !@blocking_errors;  # excessive detail
	return \@errors, \@results, $exit_status;
    }

    if ( @{ Locks->lock_file_exists( \*in_progress_lock, $Locks::in_progress_file ) } ) {
	Locks->close_and_unlock( \*in_progress_lock );
	push @errors, 'Another load or pre-flight or commit operation just completed; please re-try your operation if needed.';
	return \@errors, \@results, $exit_status;
    }

    # In other contexts, we would have had some other action at this point that could have generated other errors.
    # In this script, any errors would have caused an earlier return.  But we retain this piece of the general
    # structure here so it's easier to compare this code with our standard Commit Synchronization protocol.
    if (@errors) {
	Locks->unlink_and_close( \*in_progress_lock, $Locks::in_progress_file );
	return \@errors, \@results, $exit_status;
    }

    if ($main::shutdown_requested) {
	Locks->unlink_and_close( \*in_progress_lock, $Locks::in_progress_file );
	push @errors, $shutdown_message;
	return \@errors, \@results, $exit_status;
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
		push @blocking_errors, 'Error:  Feeders are still operating.';
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
	    return \@errors, \@results, $exit_status;
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
	    return \@errors, \@results, $exit_status;
	}
    }

    utime undef, undef, $Locks::commit_lock_file;

    if ($main::shutdown_requested) {
	push @errors, $shutdown_message;
    }
    unless (@errors) {
	my $errors;
	my $results;
	($errors, $results, $exit_status) = load_monarch();
	my $got_load_errors = 0;
	foreach (@$results) {
	    if (/error/i) {
		if (!/<h7>/) {
		    $_ = '<h7>' . $_ . '</h7>';
		}
		$got_load_errors = 1;
	    }
	}
	if ($got_load_errors) {
	    unshift( @results, "<h7>Error(s) occurred during processing; see below.</h7>\n" );
	}
	push @errors, @$errors;
	push @results, @$results;
	if ($main::shutdown_requested) {
	    push @errors, $shutdown_message;
	    $exit_status = 1 if $exit_status == 0;
	}
    }

    Locks->close_and_unlock( \*commit_lock );
    Locks->unlink_and_close( \*in_progress_lock, $Locks::in_progress_file );

    return \@errors, \@results, $exit_status;
}

sub load_monarch {
    my @errors  = ();
    my @results = ();
    my $exit_status = 1;  # default exit status is an error

    use Sys::Hostname;
    my $hostname = hostname();

    if ( !-f $monarch_file || !-r $monarch_file ) {
	push @errors, "Error:  Cannot access $monarch_file on $hostname" . ( $! ? " ($!)." : '' );
	return \@errors, \@results, $exit_status;
    }

    if ( !open( FILE, '<', $properties_file ) ) {
	push @errors, "Error:  Cannot open $properties_file on $hostname ($!).";
	return \@errors, \@results, $exit_status;
    }

    # FIX LATER:  Someday, we should support a possible non-default $dbport
    # here as well, once the properties file contains that information.
    while ( my $line = <FILE> ) {
	if    ( $line =~ /^\s*global\.db\.type\s*=\s*(\S+)/  ) { $dbtype = $1 }
	elsif ( $line =~ /^\s*monarch\.dbhost\s*=\s*(\S+)/   ) { $dbhost = $1 }
	elsif ( $line =~ /^\s*monarch\.database\s*=\s*(\S+)/ ) { $dbname = $1 }
	elsif ( $line =~ /^\s*monarch\.username\s*=\s*(\S+)/ ) { $dbuser = $1 }
	elsif ( $line =~ /^\s*monarch\.password\s*=\s*(\S+)/ ) { $dbpass = $1 }
    }

    close(FILE);

    # Historical default.  Will be 'postgresql' as of GWMEE 6.6.
    $dbtype = 'mysql' if not defined $dbtype;

    if ( !defined($dbname) or !defined($dbhost) or !defined($dbuser) or !defined($dbpass) ) {
	push @errors, "Error:  Cannot read the database configuration on $hostname.";
	return \@errors, \@results, $exit_status;
    }

    # Simple security checks, to prevent command-line injection vulnerabilities below.
    if ( $dbname =~ /['=\\]/ or $dbhost =~ /['\\]/ or $dbuser =~ /['\\]/) {
	push @errors, "Error:  Found invalid database configuration on $hostname.";
	return \@errors, \@results, $exit_status;
    }

    # FIX LATER:  Now that we support remote databases, it would be good if we had
    # a way to identify the parent server and where its database resides, and to
    # prevent overwriting the parent's own database by further validating $dbname.
    # In the meantime, the effective blocking of such a tragedy should still occur
    # because our ~/.pgpass file won't contain access credentials for the parent's
    # database, wherever it resides.

    if ($dbtype eq 'postgresql') {
	## FIX LATER:  This could be modified to call our (future) tools/restore_db.pl
	## script, so we are guaranteed that we run ANALYZE and/or VACUUM as needed
	## every time the database is loaded this say (although we do have autovacuum
	## turned on, so it's not clear that would be useful).  Another possibility
	## is that our restore script might recognize a MySQL dump and automatically
	## convert it into an equivalent PostgreSQL dump before loading it.
	push @results, "Loading the \"$dbname\" database on $hostname ...\n";

	# NOTE:  We would like to use "-v ON_ERROR_STOP=" as well, to get $psql to
	# halt and report a problem in its exit code if an error occurs.  However, if
	# we did that, it might be impossible to recover after an error occurs where
	# certain tables have been dropped and are no longer present.  The dump file
	# starts with commands that try to drop secondary objects (indexes, sequences,
	# etc.) associated with a table, before the table itself is dropped.  If the
	# table is already gone, these initial DROP commands will necessarily fail,
	# which could make it impossible to restore from the dump file if we stopped
	# on the first error.  So we reluctantly don't use ON_ERROR_STOP here.
	#
	# PostgreSQL 9.4, still in beta as of this writing, supports a --if-exists
	# option for dumping, which cures this basic problem by sprinkling the dump
	# commands with IF EXISTS clauses in appropriate places.  That would allow us
	# to restore to an empty database without generating any errors.  Until then,
	# one way around this would be for the upstream dumping to perform the same
	# types of edits that we now have in place for plain-format Monarch backups.

	# NOTE:  We might also want to use the psql --single-transaction option.

	# We don't prepend "$psql" with "$env PGPASSWORD='$dbpass'" because we don't
	# want to stuff critical passwords on command lines where they may be visible.
	# Instead, we depend on a ~/.pgpass setup for the database-access credentials.
	# We also don't want to allow overriding the ~/.pgpass setup with settings
	# in environment variables, so we kill that possibility here.
	local %ENV = %ENV;
	delete $ENV{PGCLIENTENCODING};
	delete $ENV{PGDATABASE};
	delete $ENV{PGDATESTYLE};
	delete $ENV{PGGEQO};
	delete $ENV{PGHOSTADDR};
	delete $ENV{PGHOST};
	delete $ENV{PGLOCALEDIR};
	delete $ENV{PGOPTIONS};
	delete $ENV{PGPASSFILE};
	delete $ENV{PGPASSWORD};
	delete $ENV{PGPORT};
	delete $ENV{PGSERVICEFILE};
	delete $ENV{PGSERVICE};
	delete $ENV{PGSYSCONFDIR};
	delete $ENV{PGTZ};
	delete $ENV{PGUSER};
	$ENV{PGCONNECT_TIMEOUT} = 20;
	$ENV{PGREQUIREPEER} = 'postgres';
	$ENV{SHELL} = '/bin/false';
	$ENV{PATH} = '/bin:/sbin:/usr/bin:/usr/sbin';

	# The statements we want to drop from the dump file are exactly these, because
	# they generate ERROR and WARNING messages of no consequence to our purposes of
	# re-loading an existing database.
	#
	#     DROP EXTENSION plpgsql;
	#     DROP SCHEMA public;
	#     CREATE SCHEMA public;
	#     COMMENT ON SCHEMA public IS 'standard public schema';
	#     COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';
	#     REVOKE ALL ON SCHEMA public FROM PUBLIC;
	#     REVOKE ALL ON SCHEMA public FROM postgres;
	#     GRANT ALL ON SCHEMA public TO postgres;
	#     GRANT ALL ON SCHEMA public TO PUBLIC;
	#
	# We blank the lines rather than delete them, so the line numbers for the rest
	# of the lines in the file remain intact and are still valid with respect to
	# the original file in whatever error messages might be produced in debug mode.
	#
	# Note that it is possible for table data to contain words like SCHEMA that we
	# wish to filter out of the surrounding SQL commands (and this has been seen in
	# actual customer data).  To ensure that there is no corruption of the data, our
	# sed-based filtering must first pass through the blocks of table data ("COPY"
	# through "\.") untouched, before making any changes to the rest of the file.

	# We have a similar issue with lines related to the dblink extension, if that
	# extension got installed in the monarch database on the parent server:
	#
	#     DROP EXTENSION dblink;
	#     CREATE EXTENSION IF NOT EXISTS dblink WITH SCHEMA public;
	#     COMMENT ON EXTENSION dblink IS 'connect to other PostgreSQL databases from within a database';
	#
	# These manipulations require superuser permissions (which we don't have here) to
	# execute, and would therefore cause the loading to fail.  We solve that issue with
	# the same strategy, by blanking out such lines in the dump file before loading.

	# The -f option we use shows "-" as the filename in error/warning messages,
	# so we restore it afterward by filtering the results.
	# Error messages will be printed on STDERR, not STDOUT, and will be emitted
	# regardless of the setting (or not) of the -o option.
	my $in  = $debug >= 1 ? '-f -' : '';
	my $out = $debug >= 2 ? '' : '-o /dev/null';

	(my $escaped_path = $monarch_file) =~ s{/}{\\/}g;

	# We need lots of very careful escaping here, for multiple levels of protection.  In
	# order as the string is interpreted and executed, we protect against Perl string
	# interpretation of backslashes and dollar-signs in the middle of the qx()-quoted
	# string (done with backslashes); to protect against the qx()-system()-shell
	# interpretation of quoting and escaping of backslashes and again the dollar-signs
	# (done with backslashes, at the same time that double-quotes are applied [which do
	# not affect that backslash-quoting]), to protect against bash interpretation of
	# backslashes (done via the single-quoting of the entire sed command expression), and
	# then finally to provide sed escaping of the intended backslash and dot characters
	# in the match pattern, so they are both taken literally.  So in reverse construction,
	# the basic ^\.$ match pattern (with backslash and dot to be interpreted literally)
	# becomes ^\\\.$ as sed needs to see the backslash-escape and magic-dot characters
	# escaped, which then becomes '^\\\.$' as it is single-quoted for protection against
	# bash, which becomes "'^\\\\\\.\$'" as sh needs to see the backslash-escape and
	# dollar-sign characters escaped, which then finally becomes "'^\\\\\\\\\\\\.\\\$'"
	# to protect against Perl string unescaping and interpretation of backslash and
	# dollar-sign characters.
	push @results, qx(bash -c "
	    set -o pipefail;
	    sed -e '/^COPY /,/^\\\\\\\\\\\\.\\\$/{p;d}' -e '/plpgsql/s/.*//' -e '/dblink/s/.*//' -e '/SCHEMA/s/.*//' $monarch_file | \
	    $psql --host='$dbhost' --username='$dbuser' --no-password --dbname='$dbname' $in $out 2>&1 | \
	    sed -e 's/^psql.bin:-:/$escaped_path:/'
	");

	# Report the exit status of the pipeline:  the status of the rightmost command
	# to die or exit with a non-zero status, or zero.  Report the signal with which
	# that process died, else its exit status.  This way, we get some indication of
	# whether the database loading failed.  (Actually, without ON_ERROR_STOP, it's
	# unlikely that $psql will report anything but a zero exit status, since script
	# errors will be ignored.  Still, this will report certain kinds of fatal errors.)
	return \@errors, \@results, ($? & 127 || $? >> 8);
    }
    elsif ($dbtype eq 'mysql') {
	## FIX MINOR:  This should be modified to use a credentials file instead of
	## passing the password on the command line, with a mechanism in place to
	## guarantee removal of the credentials file no matter how the script exits.
	push @results, qx($mysql -u$dbuser -p$dbpass $dbname < $monarch_file);
	return \@errors, \@results, ($? & 127 || $? >> 8);
    }
    else {
	push @errors, "Error:  On $hostname, bad database type (global.db.type) found in db.properties file.";
	return \@errors, \@results, $exit_status;
    }
}
