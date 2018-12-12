# MonArch - Groundwork Monitor Architect
# MonarchFoundationSync.pm
#
############################################################################
# Release 4.6
# September 2018
############################################################################
#
# Copyright 2007-2018 GroundWork Open Source, Inc. (GroundWork)
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

package FoundationSync;

use Fcntl qw(F_GETFL F_SETFL O_APPEND);
use IO::Socket;
use Carp;
use Time::HiRes;
use DBI;
use MonarchStorProc;
use MonarchAudit;

# FIX LATER:  If we ever fully drop support for counting Foundation objects via
# direct queries to gwcollagedb, this package inclusion should be dropped.
use CollageQuery;

# FIX MAJOR:  When using the REST API, make sure that we log details of what got sent
# to be changed at the level of POSTed JSON or any URLs that carry no JSON payload,
# even when there are no errors to report.

# --------------------------------------------------------------------------------
# Historical options
# --------------------------------------------------------------------------------

my $use_sync_start_action = 1;    # Leave as 1 to get Foundation to flush its internal queues of results already received.
my $use_sync_stop_action  = 0;    # Leave as 0.

my $foundation_msg_count = 0;
my $remote_host          = "127.0.0.1";
my $remote_port          = 4913;
my $logfile              = "/usr/local/groundwork/foundation/container/logs/monarch_foundation_sync.log";
my $maxhostsendcount     = 256;   # a power of 2 makes division faster
my $max_bulk_host_add    = 200;
my $single_obj_timeout   = 0.350; # Estimated max seconds per object deletion or insertion.
my $wait_sleep_seconds   = 3;     # May be set to a fractional value.
my $abort_on_error       = 1;     # If set, abort Commit after first error seen.

# Identifier for this instance of Nagios; theoretically should be `hostname -s`, but in practice we always use localhost.
my $thisnagios = 'localhost';

# FIX THIS:  set these values as needed for production use
my $show_timeouts = 1;     # Set to 0 to suppress, 1 to show timeout messages.
my $show_napping  = 1;     # Set to 0 for normal operation, 1 to emit napping messages to Apache error log.
			   # (Set to 1 for now to guarantee Apache does not give up on a long-running commit operation.)

our $logging      = 1;     # Set to 0 to disable debug logging
			   # and to 1 for debug instance logging (a static file is overwritten)
			   # and to 2 for persistent logging (file will grow).
my $log_as_utf8   = 0;     # Set to 0 to log Foundation messages as ISO-8859-1, to 1 to log as UTF-8.

my $debug         = 0;
my $debug_waits   = $debug >= 1;

# --------------------------------------------------------------------------------
# Options for sending change data to Foundation via the Foundation REST API.
# --------------------------------------------------------------------------------

my $use_rest_api      = 0;    # set to 1 to use the REST API instead of the $remote_port socket API, 0 otherwise
my $verify_rest_calls = 1;    # set to 1 to wait for confirmation at the database level after REST calls, 0 otherwise

# The application name by which the MonarchFoundationSync.pm processing
# will be known to the Foundation REST API.
my $rest_api_requestor = 'Monarch Foundation Sync';

# Where to find credentials for accessing the Foundation REST API.
my $ws_client_config_file = '/usr/local/groundwork/config/ws_client.properties';

# There are six predefined log levels within the Log4perl package:  FATAL, ERROR, WARN, INFO,
# DEBUG, and TRACE (in descending priority).  We define two custom levels at the application
# level to form the full useful set:  FATAL, ERROR, WARN, NOTICE, STATS, INFO, DEBUG, and TRACE.
# To see an individual message appear, your configured logging level here has to at least match
# the priority of that logging message in the code.
my $GW_RAPID_log_level = 'STATS';

# Application-level logging configuration, for that portion of the logging
# which is currently handled by the Log4perl package.
my $log4perl_config = <<EOF;

# Use this to send everything from FATAL through $GW_RAPID_log_level to the logfile.
log4perl.category.Monarch.Foundation.Sync.GW.RAPID = $GW_RAPID_log_level, Logfile

# Send all Log4perl lines to the same log file as the rest of this application.
log4perl.appender.Logfile          = Log::Log4perl::Appender::File
log4perl.appender.Logfile.filename = $logfile
log4perl.appender.Logfile.utf8     = 0
log4perl.appender.Logfile.layout   = Log::Log4perl::Layout::PatternLayout
log4perl.appender.Logfile.layout.ConversionPattern = [%d{EEE MMM dd HH:mm:ss yyyy}] %m%n

EOF

# Limit the number of objects passed to GW::RAPID in any one call.  Since all calls here
# are synchronous, these numbers can be made fairly high without worrying about losing any
# advantage of possible concurrency.  FIX MINOR:  $max_rest_member_objects must currently
# be limited to something less than 1600 (GWMON-11826); the exact limit is not yet known.
my $max_rest_objects        = 30;
my $max_rest_member_objects = 50;

# --------------------------------------------------------------------------------
# Working variables
# --------------------------------------------------------------------------------

my $socket      = undef;
my $collage_dbh = undef;
my $change_time = undef;
my $report_time = undef;
my $rest_api    = undef;

# --------------------------------------------------------------------------------
# Subroutines
# --------------------------------------------------------------------------------

sub log_outcome {
    my $logfh   = $_[0];
    my $outcome = $_[1];
    my $context = $_[2];

    if ($logfh) {
	if (%$outcome) {
	    print $logfh "ERROR:  Outcome of $context:\n";
	    foreach my $key ( sort keys %$outcome ) {
		print $logfh "    $key => $outcome->{$key}\n";
	    }
	}
	else {
	    print $logfh "ERROR:  No outcome data returned for failed $context.\n";
	}
    }
}

sub log_results {
    my $logfh   = $_[0];
    my $results = $_[1];
    my $context = $_[2];

    if ($logfh) {
	if ( ref $results eq 'HASH' ) {
	    if (%$results) {
		print $logfh "ERROR:  Results of $context:\n";
		foreach my $key ( sort keys %$results ) {
		    if ( ref $results->{$key} eq 'HASH' ) {
			foreach my $subkey ( sort keys %{ $results->{$key} } ) {
			    if ( ref $results->{$key}{$subkey} eq 'HASH' ) {
				foreach my $subsubkey ( sort keys %{ $results->{$key}{$subkey} } ) {
				    if ( ref $results->{$key}{$subkey}{$subsubkey} eq 'HASH' ) {
					foreach my $subsubsubkey ( sort keys %{ $results->{$key}{$subkey}{$subsubkey} } ) {
					    print $logfh "    ${key}{$subkey}{$subsubkey}{$subsubsubkey} => '$results->{$key}{$subkey}{$subsubkey}{$subsubsubkey}'\n";
					}
				    }
				    else {
					print $logfh "    ${key}{$subkey}{$subsubkey} => '$results->{$key}{$subkey}{$subsubkey}'\n";
				    }
				}
			    }
			    else {
				print $logfh "    ${key}{$subkey} => '$results->{$key}{$subkey}'\n";
			    }
			}
		    }
		    else {
			print $logfh "    $key => '$results->{$key}'\n";
		    }
		}
	    }
	    else {
		print $logfh "ERROR:  No results data returned for failed $context.\n";
	    }
	}
	elsif ( ref $results eq 'ARRAY' ) {
	    if (@$results) {
		print $logfh "ERROR:  Results of $context:\n";
		my $i = 0;
		foreach my $result (@$results) {
		    if ( ref $result eq 'HASH' ) {
			foreach my $key ( keys %$result ) {
			    print $logfh "    result[$i]{$key} => '$result->{$key}'\n";
			}
		    }
		    else {
			print $logfh "    result[$i]:  $result\n";
		    }
		    ++$i;
		}
	    }
	    else {
		print $logfh "ERROR:  No results data returned for failed $context.\n";
	    }
	}
	else {
	    print $logfh 'ERROR:  Internal programming error when displaying results (' . code_coordinates() . ").\n";
	}
    }
}

sub code_coordinates {
    my $package;
    my $filename;
    my $parent_line;
    my $grandparent_line;
    my $great_grandparent_line;
    my $myself;
    my $parent;
    my $grandparent;

    ( $package, $filename, $parent_line,            $myself )      = caller(0);
    ( $package, $filename, $grandparent_line,       $parent )      = caller(1);
    ( $package, $filename, $great_grandparent_line, $grandparent ) = caller(2);
    return "at $parent() line $parent_line, called from $grandparent, line $grandparent_line";
}

sub initialize_rest_api {
    my $phase = $_[0];
    my $logfh = $_[1];

    require GW::RAPID;

    # Basic security:  disallow code in the logging config data.
    Log::Log4perl::Config->allow_code(0);

    # Here we add custom logging levels to form our full standard complement.  There are six
    # predefined log levels:  FATAL, ERROR, WARN, INFO, DEBUG, and TRACE (in descending priority).
    # We add NOTICE and STATS levels to the default set of logging levels supplied by Log4perl,
    # to form the full useful set:  FATAL, ERROR, WARN, NOTICE, STATS, INFO, DEBUG, and TRACE
    # (excepting NONE, I suppose, though there is some hint in the code that OFF is also supported).
    # This *must* be done before the call to Log::Log4perl::init(), and we must also accommodate
    # the situation where initialize_rest_api() has previously been called during some earlier sync
    # in the same program.
    if ($phase eq 'started') {
	Log::Log4perl::Logger::create_custom_level( "NOTICE", "WARN" )   if not Log::Log4perl::Logger->can('notice');
	Log::Log4perl::Logger::create_custom_level( "STATS",  "NOTICE" ) if not Log::Log4perl::Logger->can('stats');
    }

    # If we wanted to support logging either through a syslog appender (I'm not sure how this would
    # be done; presumably via something other than Log::Dispatch::Syslog, since that is still
    # Log::Dispatch) or through Log::Dispatch, the following code extensions would come in handy.
    # (Frankly, I'm not really sure that Log4perl even supports syslog logging other than through
    # Log::Log4perl::JavaMap::SyslogAppender, which just wraps Log::Dispatch::Syslog.)
    #
    # use Sys::Syslog qw(:macros);
    # use Log::Dispatch;
    # my $log_null = Log::Dispatch->new( outputs => [ [ 'Null', min_level => 'debug' ] ] );
    # Log::Log4perl::Logger::create_custom_level("NOTICE", "WARN", LOG_NOTICE, $log_null->_level_as_number('notice'));
    # Log::Log4perl::Logger::create_custom_level("STATS", "NOTICE", LOG_INFO, $log_null->_level_as_number('info'));

    # This logging setup is an application-global initialization for the Log::Log4perl package, so
    # it only makes sense to initialize it at the application level, not in some lower-level package.
    #
    # It's not documented, but apparently Log::Log4perl::init() always returns 1, even if
    # it is handed a garbage configuration as a literal string.  That makes it hard to tell
    # if you really have it configured correctly.  On the other hand, if it's handed the
    # path to a missing config file, it throws an exception (also undocumented).
    eval {
	## If the value starts with a leading slash, we interpret it as an absolute path to a file that
	## contains the logging configuration data.  Otherwise, we interpret it as the data itself.
	## Apparently, init() can be run more than once, so this is working even if initialize_rest_api()
	## has already been called during some earlier sync in the same program.
	##
	## FIX MINOR:  This initialization, along with the previous calls to create_custom_level(),
	## presume that the application as a whole that calls FoundationSync->sync() has never called
	## Log::Log4perl::init() to initialize its own logging.  That might cause problems if an
	## application does want to do so.
	Log::Log4perl::init( $log4perl_config =~ m{^/} ? $log4perl_config : \$log4perl_config );
    };
    if ($@) {
	chomp $@;
	print $logfh "ERROR:  Could not initialize Log::Log4perl logging:\n$@\n" if defined fileno $logfh;
	return 0;
    }

    # Initialize the REST API object.
    my %rest_api_options = (
	logger        => Log::Log4perl::get_logger("Monarch.Foundation.Sync.GW.RAPID"),
	access        => $ws_client_config_file,
	interruptible => \$main::shutdown_requested
    );
    $rest_api = GW::RAPID->new( undef, undef, undef, undef, $rest_api_requestor, \%rest_api_options );
    if ( not defined $rest_api ) {
	## The GW::RAPID constructor doesn't directly return any information to the caller on the reason for
	## a failure.  But it will already have used the logger handle to write such detail into the logfile.
	print $logfh "ERROR:  Could not create a GW::RAPID object.\n" if defined fileno $logfh;
	return 0;
    }

    return 1;
}

sub terminate_rest_api {
    ## Release our handle to the REST API (if we used it), to force the REST API to call its destructor.
    ## This will attempt to log out before Perl's global destruction pass wipes out resources needed for
    ## logout to work properly.
    $rest_api = undef;
}

sub connect_to_rest_api {
    my $phase = $_[0];
    my $logfh = $_[1];
    if ( not initialize_rest_api( $phase, $logfh ) ) {
	return 0;
    }
    ## FIX MAJOR:  replace as needed with code appropriate for our current purposes
    if (0) {
	## FIX MAJOR:  use 'host' here (which currently works), or 'hostName' instead?
#	push @rest_event_messages,
#	  {
#	    consolidationName => 'SYSTEM',
#	    appType           => 'SYSTEM',
#	    monitorServer     => 'localhost',
#	    host              => $thisnagios,
#	    device            => '127.0.0.1',
#	    severity          => 'OK',
#	    monitorStatus     => 'OK',
#	    textMessage       => "Monarch Commit process $phase.",
#	    reportDate        => unix_to_rest_time(time)
#	  };
#	$message_counter = send_pending_events( $message_counter, 1 );
    }
    return 1;
}

# FIX THIS:  RaiseError, PrintError?  what about the same in the event feeder?
sub collage_connect {
    my ( $dbname, $dbhost, $dbuser, $dbpass, $dbtype ) = CollageQuery::readGroundworkDBConfig('collage');
    my $dsn = '';
    if ( defined($dbtype) && $dbtype eq 'postgresql' ) {
	$dsn = "DBI:Pg:dbname=$dbname;host=$dbhost";
    }
    else {
	return "Can't connect to db type. Error: unsupported";
    }
    $collage_dbh = DBI->connect( $dsn, $dbuser, $dbpass, { 'AutoCommit' => 1, 'RaiseError' => 1 } )
      or return "Can't connect to database $dbname. Error:" . $DBI::errstr;
    return '';
}

sub collage_disconnect {
    $collage_dbh->disconnect();
}

# FIX MAJOR:  These counts are gathered using direct queries to the gwcollagedb database.
# Replace with GW::RAPID calls, if we can get them to be efficient.
sub count_objects {
    my $obj_type = $_[0];
    my $errs     = [];
    my $count;
    my $sqlstmt;

    if ($obj_type eq 'hosts') {
	## This count does not necessarily include all hosts known to Monarch, but it does include all hosts owned/managed by Monarch.
	## So it therefore includes all hosts that might be added or can be deleted by Monarch, and as such it serves adequately as the
	## basis for deciding whether all host deletes and host adds are complete.
	$sqlstmt = "select count(*) from ApplicationType at, Host h where at.Name = 'NAGIOS' and h.ApplicationTypeID = at.ApplicationTypeID";
    }
    elsif ($obj_type eq 'services') {
	## We count only services owned/managed by Monarch.
	$sqlstmt = "select count(*) from ApplicationType at, ServiceStatus ss where at.Name = 'NAGIOS' and ss.ApplicationTypeID = at.ApplicationTypeID";
    }
    elsif ($obj_type eq 'hostgroups') {
	## We count only hostgroups owned/managed by Monarch.
	$sqlstmt = "select count(*) from ApplicationType at, HostGroup hg where at.Name = 'NAGIOS' and hg.ApplicationTypeID = at.ApplicationTypeID";
    }
    elsif ($obj_type eq 'hostgroup members') {
	## We count only hosts in hostgroups owned/managed by Monarch, but regardless of whether the individual
	## hosts in those hostgroups are also owned/managed by Monarch, since Monarch has the power to add to and
	## delete hosts from such hostgroups regardless of whether Monarch actually owns the hosts themselves.
	## There is some danger that a host not owned by Monarch but known to Monarch and added to a hostgroup
	## could be entirely deleted from Foundation by the host's owner and thus cascade-deleted from the
	## hostgroup without our knowledge, but there is little we can do about that here.
	$sqlstmt = "select count(*) from ApplicationType at, HostGroup hg, HostGroupCollection hgc, Host h
	    where at.Name = 'NAGIOS' and hg.ApplicationTypeID = at.ApplicationTypeID and hgc.HostGroupID = hg.HostGroupID and h.HostID = hgc.HostID";
    }
    elsif ($obj_type eq 'servicegroups') {
	## Originally, service groups were entirely a Monarch construct, so we didn't bother with filtering by
	## ApplicationType.  But now we have Custom Service Groups in the product (GWMON-12290).  So now, when
	## we count servicegroups in MonarchAudit, we should be using a CollageQuery query that qualifies by
	## ApplicationType being NAGIOS (or maybe also NULL, for legacy compatibility), and we want to use a
	## more complex query here that also imposes such a qualification.  That means we must take into account
	## possible VEMA-managed hosts and services.
	# Original query:
	# $sqlstmt = "select count(*) from Category c, EntityType et where et.Name = 'SERVICE_GROUP' and c.EntityTypeID = et.EntityTypeID";
	# GWMON-12290 as part of this JIRA fix, this count need query should be fixed.
	# Query as updated for GWMON-12290:
	$sqlstmt = "select count(*) from Category c, EntityType et where et.Name = 'SERVICE_GROUP' and c.EntityTypeID = et.EntityTypeID
		    and ( c.applicationtypeid is null or c.applicationtypeid = ( select applicationtypeid from applicationtype where name = 'NAGIOS' ) )";
    }
    elsif ($obj_type eq 'servicegroup members') {
	## We don't bother to check whether individual services in a service group are owned by Monarch, because
	## Monarch has full control over the service group membership.  But Monarch-owned services on foreign-owned
	## hosts can be part of a service group, so this counting is subject to the same kind of asynchronous
	## foreign-owner host deletion that can occur with hostgroup members.  Someday, when we count servicegroups
	## and servicegroup members in MonarchAudit using CollageQuery queries that qualify by ApplicationType being
	## NAGIOS, we will want to use a more complex query here that also imposes such qualifications.  But any
	## change like that now has to take into account possible VEMA-managed hosts and services.
	$sqlstmt =
	    "select count(*)
	    from   ServiceStatus ss, CategoryEntity ce, Category c, EntityType et
	    where  et.Name = 'SERVICE_GROUP'
	    and    c.EntityTypeID = et.EntityTypeID
	    and    ce.CategoryID = c.CategoryID
	    and    ss.ServiceStatusID = ce.ObjectID";
    }
    else {
	push @$errs, "Error:  bad object type '$obj_type'";
	return (undef, $errs);
    }

    $count = $collage_dbh->selectrow_array($sqlstmt);
    push @$errs, "Error:  cannot count $obj_type: ", $collage_dbh->errstr if not defined $count;
    return ($count, $errs);
}

sub wait_for_foundation {
    # my $self    = $_[0];
    my $change    = $_[1];
    my $obj_type  = $_[2];
    my $obj_delta = $_[3];
    my $obj_count = $_[4];
    my $starttime = Time::HiRes::time();
    my $timeout   = $obj_delta * $single_obj_timeout;  # Seconds to wait before issuing a warning.
    my @warnings  = ();
    my @errors    = ();
    my $now;
    my $timeleft;

    # FIX THIS:  This is just a temporary override, to guarantee we won't run into timeouts during development,
    # until we all have the things that might time out optimized so they shouldn't ever.
    # $timeout = 900;

    print STDERR "=== Waiting for $change of $obj_delta $obj_type, to end up with $obj_count.\n" if $debug_waits;

    # FIX THIS?
    # return \@errors if ($obj_delta == 0);

    my $count;
    my $errs;
    my $prev_count = -1;
    my $napped     = 0;
    for (;;) {
	last if $main::shutdown_requested;
	($count, $errs) = count_objects($obj_type);
	if (@$errs) {
	    print STDERR join("\n", @$errs), "\n";
	    push @errors, @$errs;
	    $napped = 0;
	    last;
	}
	last if ($count == $obj_count);
	if ($prev_count >= 0 &&
	    ( ( $change eq 'add' && $count < $prev_count ) || ( ( $change eq 'delete' || $change eq 'clear' ) && $count > $prev_count ) )
	  )
	{
	    # FIX LATER:  when we get back to aborting when timeouts occur, this should be an error, not a warning
	    print STDERR "Warning:  In $change of $obj_delta $obj_type, object count is "
	      . ($change eq 'add' ? 'decreasing' : 'increasing') . " (now have $count).\n";
	    push @warnings, "Warning:  Count of $obj_type is going in the wrong direction for $change.";
	    last;
	}
	$prev_count = $count;

	# To accommodate very small changes without spurious errors, we don't
	# enforce a timeout until we have waited at least one napping cycle.
	$now = Time::HiRes::time();
	if ( $napped && ($now - $starttime) > $timeout ) {
	    if ( $show_timeouts ) {
		push @warnings, "Notice:  Expecting $obj_count, have $count $obj_type;";
		push @warnings, "$change of $obj_delta $obj_type is taking more than estimated $timeout seconds.";
	    }
	    # FIX THIS:  someday, when we no longer warn but only issue errors on timeouts, we can put these lines back.
	    # print STDERR ">>> Have $count $obj_type; Foundation is taking too long; Commit will be aborted!\n" if ($show_napping || $debug_waits);
	    # push @errors, "Error:  Foundation is taking too long to process changes; Commit has been aborted!";
	    print STDERR ">>> Have $count $obj_type; Foundation is taking too long; Commit will continue without a full wait.\n" if ($show_napping || $debug_waits);
	    push @warnings, "Warning:  Foundation is taking too long to process changes; Commit will continue without a full wait.";
	    last;
	}
	$timeleft = $starttime + $timeout - $now;
	$timeleft = 0 if $timeleft < 0;
	$timeleft = sprintf('%0.3f', $timeleft);
	print STDERR "napping for $change of $obj_delta $obj_type; want $obj_count, have $count so far; $timeleft secs left\n" if $show_napping;
	select undef, undef, undef, $wait_sleep_seconds;
	$napped = 1;
    }
    if ($napped && $show_napping && defined($count) && $count == $obj_count) {
	$now = Time::HiRes::time();
	my $waittime = $now - $starttime;
	$waittime = sprintf('%0.3f', $waittime);
	print STDERR "napping for $change of $obj_delta $obj_type is over; waiting took $waittime secs\n";
    }

    return \@warnings, \@errors;
}

# sync() - Synchronize the monarch and foundation databases for a single Monarch group
#
sub sync_group {
    ## my $self          = $_[0];
    my $group            = $_[1];
    my $pre_restart_time = $_[2];

    sync( '', { 'group' => $group }, $pre_restart_time );
}

# sync() - Synchronize the monarch and foundation databases.

# This comment is old and now merely suggestive.
# Stop event broker (actually, all of nagios, including the event feeder, outside of this routine).
# Call Audit->foundation_sync() to build data structure containing
#     delta between previous state and current state, based on
#     difference between monarch and foundation databases.
# Preserve current state of modified objects with calls to CollageQuery methods.  (???)
# Prepare commands in XML format for consumption by Foundation, and
#     send them to a socket on which Foundation is listening.
# Restart event broker (all of nagios, including the event feeder, outside of this routine).

sub sync($$$) {
    ## my $self          = $_[0];
    my $arg_ref          = $_[1];
    my $pre_restart_time = $_[2];
    my @warnings         = ();
    my @errors           = ();
    my @timing           = ();
    my $warn_ref         = undef;
    my $err_ref          = undef;
    my $time_ref         = undef;
    my $errorstring      = undef;
    my %delta            = ();
    my $phasetime;

    StorProc->start_timing( \$phasetime );

    my $logfh;
    if ( $logging == 1 ) {
	if ( open( $logfh, '>', $logfile ) ) {
	    $logfh->autoflush(1);
	    ## We must set $logfh into append mode so it interleaves correctly with any appended GW::RAPID log output.
	    my $flags = undef;
	    $flags = fcntl( $logfh, F_GETFL, 0 );
	    if ( not defined $flags ) {
		push @errors, "ERROR:  Foundation sync is in debug mode but cannot get flags of log file $logfile ($!).";
	    }
	    elsif ( not fcntl( $logfh, F_SETFL, $flags | O_APPEND ) ) {
		push @errors, "ERROR:  Foundation sync is in debug mode but cannot set append mode of log file $logfile ($!).";
	    }
	}
	else {
	    push @errors, "ERROR:  Foundation sync is in debug mode but cannot write to log file $logfile ($!).";
	}
    }
    elsif ( $logging == 2 ) {
	if ( open( $logfh, '>>', $logfile ) ) {
	    $logfh->autoflush(1);
	}
	else {
	    push @errors, "ERROR:  Foundation sync is in debug mode but cannot append to log file $logfile ($!).";
	}
    }
    print $logfh "[" . ( scalar localtime ) . "] === Starting up (process $$). ===\n" if defined fileno $logfh;

    if ( not defined $pre_restart_time ) {
	push @errors, 'ERROR:  Software compatibility problem in sync():  pre-restart timestamp is missing.';
    }

    if (@errors) {
	print $logfh join( "\n", @errors ) . "\n" if defined fileno $logfh;
	print STDERR join( "\n", @errors ) . "\n";
	$errorstring = join( '<br>', @errors );
	terminate_rest_api() if $use_rest_api;
	return \@timing, $errorstring;
    }

    if ( $use_rest_api and not connect_to_rest_api( 'started', $logfh ) ) {
	push @errors, 'ERROR:  Failed to connect to the Foundation REST API';
    }

    if (@errors) {
	print $logfh join( "\n", @errors ) . "\n" if defined fileno $logfh;
	print STDERR join( "\n", @errors ) . "\n";
	$errorstring = join( '<br>', @errors );
	terminate_rest_api() if $use_rest_api;
	return \@timing, $errorstring;
    }

    # FIX MINOR:  it would probably be more efficient to pass back a hashref, rather than copy the whole big %delta structure
    if ( defined($arg_ref) && defined( $arg_ref->{'group'} ) ) {
	( $err_ref, $time_ref, %delta ) = Audit->foundation_sync_group( $arg_ref->{'group'}, $rest_api );
    }
    else {
	( $err_ref, $time_ref, %delta ) = Audit->foundation_sync( undef, $rest_api );
    }
    push @errors, @$err_ref;
    push @timing, @$time_ref;

    StorProc->capture_timing( \@timing, \$phasetime, 'running Audit' );

    if (@errors) {
	push @errors, 'ERROR:  Could not run comparison of Monarch and Foundation databases.';
	push @errors, "See $logfile (and possibly framework.log) for details." if $logging;
	print $logfh join( "\n", @errors ) . "\n" if $logging;
	$errorstring = join( '<br>', @errors );
	terminate_rest_api() if $use_rest_api;
	return \@timing, $errorstring;
    }

    # snapshot from monarch -- check this before auto-vivification below changes the picture
    unless ($delta{'add'} || $delta{'delete'} || $delta{'alter'}) {
	$errorstring = "Synchronization with Foundation completed successfully. No changes were needed.";
	print $logfh "$errorstring\n" if $logging;
	terminate_rest_api() if $use_rest_api;
	return \@timing, $errorstring;
    }

    my $deleted_hosts         = scalar keys %{ $delta{'delete'}{'host'} };
    my $deleted_hostgroups    = scalar keys %{ $delta{'delete'}{'hostgroup'} };
    my $deleted_services      = 0;
    my $deleted_servicegroups = scalar keys %{ $delta{'delete'}{'servicegroup'} };

    foreach my $host (keys %{ $delta{'delete'}{'service'} }) {
	$deleted_services += scalar keys %{ $delta{'delete'}{'service'}{$host} };
    }

    # We need to count as well the objects that are not individually deleted but will be automatically
    # cascade-deleted when containing objects are deleted, so the final counts we wait for will be correct.
    my $cascade_deleted_services             = $delta{'statistics'}{'cascade_deleted_services'};
    my $cascade_deleted_hostgroup_members    = $delta{'statistics'}{'cascade_deleted_hostgroup_members'};
    my $cascade_deleted_servicegroup_members = $delta{'statistics'}{'cascade_deleted_servicegroup_members'};

    my $added_hosts           = scalar keys %{ $delta{'add'}{'host'} };
    my $added_hostgroups      = scalar keys %{ $delta{'add'}{'hostgroup'} };
    my $added_services        = 0;
    my $added_servicegroups   = scalar keys %{ $delta{'add'}{'servicegroup'} };

    foreach my $host (keys %{ $delta{'add'}{'service'} }) {
	$added_services += scalar keys %{ $delta{'add'}{'service'}{$host} };
    }

    # FIX THIS:  calculate the proper values to assign here, and do so (I believe this is correct, but do some testing)
    my $cleared_hostgroup_members    = $delta{'statistics'}{'cleared_hostgroup_members'};
    my $cleared_servicegroup_members = $delta{'statistics'}{'cleared_servicegroup_members'};

    my $added_hostgroup_members = 0;
    foreach my $hostgroup (sort keys %{ $delta{'add'}{'hostgroup'} }) {
	$added_hostgroup_members += keys %{ $delta{'add'}{'hostgroup'}{$hostgroup}{'members'} };
	## printf $logfh "hostgroup $hostgroup adding members:  " . join( ' ', sort keys %{ $delta{'add'}{'hostgroup'}{$hostgroup}{'members'} } ) . "\n" if $logging;
    }

    my $altered_hostgroup_members = 0;
    foreach my $hostgroup (sort keys %{ $delta{'alter'}{'hostgroup'} }) {
	if (exists $delta{'alter'}{'hostgroup'}{$hostgroup}{'members'}) {
	    $altered_hostgroup_members += keys %{ $delta{'alter'}{'hostgroup'}{$hostgroup}{'members'} };
	    ## printf $logfh "hostgroup $hostgroup altered members:  " . join( ' ', sort keys %{ $delta{'alter'}{'hostgroup'}{$hostgroup}{'members'} } ) . "\n" if $logging;
	}
    }

    my $added_servicegroup_members = 0;
    foreach my $servicegroup (keys %{ $delta{'add'}{'servicegroup'} }) {
	foreach my $host (keys %{ $delta{'add'}{'servicegroup'}{$servicegroup}{'members'} }) {
	    $added_servicegroup_members += scalar keys %{ $delta{'add'}{'servicegroup'}{$servicegroup}{'members'}{$host} };
	}
    }

    my $altered_servicegroup_members = 0;
    foreach my $servicegroup (keys %{ $delta{'alter'}{'servicegroup'} }) {
	if (exists $delta{'alter'}{'servicegroup'}{$servicegroup}{'members'}) {
	    foreach my $host (keys %{ $delta{'alter'}{'servicegroup'}{$servicegroup}{'members'} }) {
		$altered_servicegroup_members += scalar keys %{ $delta{'alter'}{'servicegroup'}{$servicegroup}{'members'}{$host} };
	    }
	}
    }

    # this is only for development debugging
    if (0 && $logging) {
	printf $logfh "\n";
	printf $logfh "     added_hostgroup_members = $added_hostgroup_members\n";
	printf $logfh "   altered_hostgroup_members = $altered_hostgroup_members\n";
	printf $logfh "  added_servicegroup_members = $added_servicegroup_members\n";
	printf $logfh "altered_servicegroup_members = $altered_servicegroup_members\n";
    }

    my $updated_hostgroup_members    = $added_hostgroup_members    + $altered_hostgroup_members;
    my $updated_servicegroup_members = $added_servicegroup_members + $altered_servicegroup_members;

    # FIX MAJOR:  This direct connection to gwcollagedb should be ignored if we are using the REST API
    # and have some other means of efficiently collecting the object-count information.
    my $status = collage_connect();
    push @errors, $status if $status;

    if (@errors) {
	print $logfh join( "\n", @errors ) . "\n" if $logging;
	print STDERR join( "\n", @errors ) . "\n";
	$errorstring = join( '<br>', @errors );
	terminate_rest_api() if $use_rest_api;
	return \@timing, $errorstring;
    }

    # Initial numbers of objects in Foundation, to which deletes and adds will be applied.
    # FIX THIS:  should these numbers be derived from these hashes instead?
    # %delta{'exists'}{'hostgroup'}
    # %delta{'exists'}{'service'}
    # %delta{'exists'}{'host'}
    # %delta{'exists'}{}         # maybe 'servicegroup' ?  need to prove it first

    my $initial_host_count;
    my $initial_hostgroup_count;
    my $initial_service_count;
    my $initial_servicegroup_count;
    my $initial_hostgroup_member_count;
    my $initial_servicegroup_member_count;

    my $errs = [];
    ( $initial_host_count,                $errs ) = count_objects('hosts')                unless @$errs;
    ( $initial_hostgroup_count,           $errs ) = count_objects('hostgroups')           unless @$errs;
    ( $initial_service_count,             $errs ) = count_objects('services')             unless @$errs;
    ( $initial_servicegroup_count,        $errs ) = count_objects('servicegroups')        unless @$errs;
    ( $initial_hostgroup_member_count,    $errs ) = count_objects('hostgroup members')    unless @$errs;
    ( $initial_servicegroup_member_count, $errs ) = count_objects('servicegroup members') unless @$errs;
    if (@$errs) {
	print $logfh join( "\n", @$errs ) . "\n" if $logging;
	print STDERR join( "\n", @$errs ) . "\n";
	$errorstring = join( '<br>', @$errs );
	terminate_rest_api() if $use_rest_api;
	return \@timing, $errorstring;
    }

    # The $low_service_count value here corresponds to after deleting individual services but not yet
    # taking account of additional services that will be cascade-deleted when deleting entire hosts.
    my $low_host_count         = $initial_host_count         - $deleted_hosts;
    my $low_hostgroup_count    = $initial_hostgroup_count    - $deleted_hostgroups;
    my $low_service_count      = $initial_service_count      - $deleted_services;
    my $low_servicegroup_count = $initial_servicegroup_count - $deleted_servicegroups;

    # The $high_service_count value here must take into account all services that were cascade-deleted.
    my $high_host_count         = $low_host_count         + $added_hosts;
    my $high_hostgroup_count    = $low_hostgroup_count    + $added_hostgroups;
    my $high_service_count      = $low_service_count      - $cascade_deleted_services + $added_services;
    my $high_servicegroup_count = $low_servicegroup_count + $added_servicegroups;

    # FIX THIS
    my $low_hostgroup_member_count    = $initial_hostgroup_member_count    - $cascade_deleted_hostgroup_members    - $cleared_hostgroup_members;
    my $low_servicegroup_member_count = $initial_servicegroup_member_count - $cascade_deleted_servicegroup_members - $cleared_servicegroup_members;

    my $high_hostgroup_member_count    = $low_hostgroup_member_count    + $updated_hostgroup_members;
    my $high_servicegroup_member_count = $low_servicegroup_member_count + $updated_servicegroup_members;

    if (not $use_rest_api) {
	## Make a socket connection
	my $max_connect_attempts = 3;
	unless ($errorstring) {
	    my $status;
	    for (my $i = 0; $i <= $max_connect_attempts; $i++) {
		if ($i == $max_connect_attempts) {
		    print $logfh "Couldn't connect to $remote_host:$remote_port : $status\n" if $logging;
		    $errorstring = "<h7>Error:  Unable to connect to Foundation port (check gwservices).</h7>\n";
		} else {
		    $socket = IO::Socket::INET->new( PeerAddr => $remote_host, PeerPort => $remote_port, Proto => "tcp", Type => SOCK_STREAM );
		    if ($socket) {
			# FIX THIS:  this is perhaps also something we want to send to $socket;
			# there's no point in logging it here unless we do so
			# print $logfh "<GENERICLOG consolidation='SYSTEM' ApplicationType='SYSTEM' MonitorServerName='localhost' Device='$remote_host' Severity='OK' MonitorStatus='OK' TextMessage='Foundation-Monarch sync process completed. It might take up to 30 sec. for changes to show up in the status pages.' />\n" if $logging;
			# Ensure that we push out all the data we write, before
			# we go waiting for Foundation to finish processing it.
			$socket->autoflush(1);
			last;
		    } else {
			$status = $!;
			sleep 1;
		    }
		}
	    }
	}
    }

    if ($logging) {
	printf $logfh "\n";
	printf $logfh "Objects:            initial - deleted = low; + added = final\n";
	printf $logfh "hosts:                %5d - %5d = %5d; + %5d = %5d\n",
	    $initial_host_count, $deleted_hosts, $low_host_count, $added_hosts, $high_host_count;
	printf $logfh "hostgroups:           %5d - %5d = %5d; + %5d = %5d\n",
	    $initial_hostgroup_count, $deleted_hostgroups, $low_hostgroup_count, $added_hostgroups, $high_hostgroup_count;
	printf $logfh "Objects:          initial - deleted = low; - cascade + added = final\n";
	printf $logfh "services:             %5d - %5d = %5d; - %5d + %5d = %5d\n",
	    $initial_service_count, $deleted_services, $low_service_count, $cascade_deleted_services, $added_services, $high_service_count;
	printf $logfh "servicegroups:        %5d - %5d = %5d; + %5d = %5d\n",
	    $initial_servicegroup_count, $deleted_servicegroups, $low_servicegroup_count, $added_servicegroups, $high_servicegroup_count;
	printf $logfh "Group members:      initial - cascade - clear = low; + added = final\n";
	printf $logfh "hostgroup members:    %5d - %5d - %5d = %5d; + %5d = %5d\n",
	    $initial_hostgroup_member_count, $cascade_deleted_hostgroup_members, $cleared_hostgroup_members, $low_hostgroup_member_count,
	    $updated_hostgroup_members, $high_hostgroup_member_count;
	printf $logfh "servicegroup members: %5d - %5d - %5d = %5d; + %5d = %5d\n",
	    $initial_servicegroup_member_count, $cascade_deleted_servicegroup_members, $cleared_servicegroup_members, $low_servicegroup_member_count,
	    $updated_servicegroup_members, $high_servicegroup_member_count;
	printf $logfh "\n";
    }

    StorProc->capture_timing( \@timing, \$phasetime, 'data preparation and Foundation connection' );

    push @errors, $errorstring if defined $errorstring;

    if ($use_rest_api) {
	if (not @errors) {
	    ## push all changes to Foundation, in measured stages

	    # We only call this once, because we expect that time formatting is an expensive operation when done
	    # repeatedly, and we don't need any finer resolution than the moment at which the entire sync is run.
	    $change_time = get_current_rest_time($pre_restart_time);
	    $report_time = get_current_rest_time(time);

	    # As a general rule, we need to to wait for deletions to finish before starting the corresponding
	    # additions, bacause we cannot tell if the additions are truly done unless we are truly sure that
	    # all the deletions are also done.  (Otherwise, we might still have some offsetting delete/add
	    # pairs still outstanding, leading to a matching count when the work is not yet done.)

	    # FIX MINOR:  Once we have this REST API code basically working, set $verify_rest_calls=0 above.

	    unless ( $main::shutdown_requested || ( @errors && $abort_on_error ) ) {
		$err_ref = delete_services_via_rest( \%delta, $logfh );
		push @errors, @$err_ref;
		StorProc->capture_timing( \@timing, \$phasetime, "delete of $deleted_services services" );
		if ($verify_rest_calls) {
		    ( $warn_ref, $err_ref ) = wait_for_foundation( '', 'delete', 'services', $deleted_services, $low_service_count );
		    push @warnings, @$warn_ref;
		    push @errors,   @$err_ref;
		    StorProc->capture_timing( \@timing, \$phasetime, "wait for $deleted_services deleted services" );
		}
	    }
	    unless ( $main::shutdown_requested || ( @errors && $abort_on_error ) ) {
		$err_ref = delete_hosts_via_rest( \%delta, $logfh );
		push @errors, @$err_ref;
		StorProc->capture_timing( \@timing, \$phasetime, "delete of $deleted_hosts hosts" );
		if ($verify_rest_calls) {
		    ( $warn_ref, $err_ref ) = wait_for_foundation( '', 'delete', 'hosts', $deleted_hosts, $low_host_count );
		    push @warnings, @$warn_ref;
		    push @errors,   @$err_ref;
		    StorProc->capture_timing( \@timing, \$phasetime, "wait for $deleted_hosts deleted hosts" );
		}
	    }
	    unless ( $main::shutdown_requested || ( @errors && $abort_on_error ) ) {
		$err_ref = add_hosts_via_rest( \%delta, $logfh );
		push @errors, @$err_ref;
		StorProc->capture_timing( \@timing, \$phasetime, "add of $added_hosts hosts" );
		if ($verify_rest_calls) {
		    ( $warn_ref, $err_ref ) = wait_for_foundation( '', 'add', 'hosts', $added_hosts, $high_host_count );
		    push @warnings, @$warn_ref;
		    push @errors,   @$err_ref;
		    StorProc->capture_timing( \@timing, \$phasetime, "wait for $added_hosts added hosts" );
		}
	    }
	    unless ( $main::shutdown_requested || ( @errors && $abort_on_error ) ) {
		$err_ref = add_services_via_rest( \%delta, $logfh );
		push @errors, @$err_ref;
		StorProc->capture_timing( \@timing, \$phasetime, "add of $added_services services" );
		if ($verify_rest_calls) {
		    ( $warn_ref, $err_ref ) = wait_for_foundation( '', 'add', 'services', $added_services, $high_service_count );
		    push @warnings, @$warn_ref;
		    push @errors,   @$err_ref;
		    StorProc->capture_timing( \@timing, \$phasetime, "wait for $added_services added services" );
		}
	    }
	    unless ( $main::shutdown_requested || ( @errors && $abort_on_error ) ) {
		$err_ref = delete_hostgroups_via_rest( \%delta, $logfh );
		push @errors, @$err_ref;
		StorProc->capture_timing( \@timing, \$phasetime, "delete of $deleted_hostgroups hostgroups" );
		if ($verify_rest_calls) {
		    ( $warn_ref, $err_ref ) = wait_for_foundation( '', 'delete', 'hostgroups', $deleted_hostgroups, $low_hostgroup_count );
		    push @warnings, @$warn_ref;
		    push @errors,   @$err_ref;
		    StorProc->capture_timing( \@timing, \$phasetime, "wait for $deleted_hostgroups deleted hostgroups" );
		}
		$err_ref = delete_servicegroups_via_rest( \%delta, $logfh );
		push @errors, @$err_ref;
		StorProc->capture_timing( \@timing, \$phasetime, "delete of $deleted_servicegroups servicegroups" );
		if ($verify_rest_calls) {
		    ( $warn_ref, $err_ref ) = wait_for_foundation( '', 'delete', 'servicegroups', $deleted_servicegroups, $low_servicegroup_count );
		    push @warnings, @$warn_ref;
		    push @errors,   @$err_ref;
		    StorProc->capture_timing( \@timing, \$phasetime, "wait for $deleted_servicegroups deleted servicegroups" );
		}
	    }
	    unless ( $main::shutdown_requested || ( @errors && $abort_on_error ) ) {
		$err_ref = add_hostgroups_via_rest( \%delta, $logfh );
		push @errors, @$err_ref;
		StorProc->capture_timing( \@timing, \$phasetime, "add of $added_hostgroups hostgroups" );
		if ($verify_rest_calls) {
		    ( $warn_ref, $err_ref ) = wait_for_foundation( '', 'add', 'hostgroups', $added_hostgroups, $high_hostgroup_count );
		    push @warnings, @$warn_ref;
		    push @errors,   @$err_ref;
		    StorProc->capture_timing( \@timing, \$phasetime, "wait for $added_hostgroups added hostgroups" );
		}
		$err_ref = add_servicegroups_via_rest( \%delta, $logfh );
		push @errors, @$err_ref;
		StorProc->capture_timing( \@timing, \$phasetime, "add of $added_servicegroups servicegroups" );
		if ($verify_rest_calls) {
		    ( $warn_ref, $err_ref ) = wait_for_foundation( '', 'add', 'servicegroups', $added_servicegroups, $high_servicegroup_count );
		    push @warnings, @$warn_ref;
		    push @errors,   @$err_ref;
		    StorProc->capture_timing( \@timing, \$phasetime, "wait for $added_servicegroups added servicegroups" );
		}
	    }
	    unless ( $main::shutdown_requested || ( @errors && $abort_on_error ) ) {
		$err_ref = add_hostgroup_members_via_rest( \%delta, $logfh );
		push @errors, @$err_ref;
		StorProc->capture_timing( \@timing, \$phasetime, "add host members to hostgroups" );
		$err_ref = add_servicegroup_members_via_rest( \%delta, $logfh );
		push @errors, @$err_ref;
		StorProc->capture_timing( \@timing, \$phasetime, "add service members to servicegroups" );
		$err_ref = update_hostgroups_via_rest( \%delta, $logfh );
		push @errors, @$err_ref;
		StorProc->capture_timing( \@timing, \$phasetime, "update hostgroups" );
		$err_ref = update_servicegroups_via_rest( \%delta, $logfh );
		push @errors, @$err_ref;
		StorProc->capture_timing( \@timing, \$phasetime, "update servicegroups" );
		$err_ref = update_hosts_via_rest( \%delta, $logfh );
		push @errors, @$err_ref;
		StorProc->capture_timing( \@timing, \$phasetime, "update hosts" );
		$err_ref = update_services_via_rest( \%delta, $logfh );
		push @errors, @$err_ref;
		StorProc->capture_timing( \@timing, \$phasetime, "update services" );
	    }

	    my $groundwork_host = foundation_host();
	    if (defined $groundwork_host) {
		$report_time = get_current_rest_time(time);
		## FIX MINOR:  Should we set lastInsertDate here as well, to the $report_time value?  Test this.
		my @events = (
		    {
			host              => $groundwork_host,
			consolidationName => 'SYSTEM',
			appType           => 'SYSTEM',
			monitorServer     => 'localhost',
			device            => $remote_host,
			severity          => @errors ? 'CRITICAL' : @warnings ? 'WARNING' : 'OK',
			monitorStatus     => @errors ? 'CRITICAL' : @warnings ? 'WARNING' : 'OK',
			textMessage =>
			    @errors   ? 'Foundation-Monarch sync failed.'       :
			    @warnings ? 'Foundation-Monarch sync had warnings.' :
			    'Foundation-Monarch sync completed. It might take up to 30 sec. for changes to show up in the status pages.',
			reportDate        => $report_time
		    }
		);

		my %outcome;
		my @results;

		if ( not $rest_api->create_events( \@events, {}, \%outcome, \@results ) ) {
		    log_outcome $logfh, \%outcome, 'logging Monarch sync execution status';
		    log_results $logfh, \@results, 'logging Monarch sync execution status';
		    push @errors, "ERROR:  Failed to log Monarch sync execution status to Foundation.";
		}
	    }
	}
    }
    elsif ($socket) {
	if (not @errors) {
	    my $xml_out = '';

	    ## print $logfh "Begin process ...\n" if $logging;

	    if ($use_sync_start_action) {
		$xml_out = "<SYNC action='start'/>\n";
		print $socket $xml_out;
		print $logfh $xml_out if $logging;
		$xml_out = '';
	    }

	    # push all changes to Foundation, in measured stages

	    # We only call this once, because we expect that time formatting is an expensive operation when done
	    # repeatedly, and we don't need any finer resolution than the moment at which the entire sync is run.
	    $change_time = get_last_state_change($pre_restart_time);
	    $report_time = get_last_state_change(time);

	    # As a general rule, we need to to wait for deletions to finish before starting the corresponding
	    # additions, bacause we cannot tell if the additions are truly done unless we are truly sure that
	    # all the deletions are also done.  (Otherwise, we might still have some offsetting delete/add
	    # pairs still outstanding, leading to a matching count when the work is not yet done.)

	    unless ($main::shutdown_requested || (@errors && $abort_on_error)) {
		delete_services( \%delta, $socket, $logfh );
		($warn_ref, $err_ref) = wait_for_foundation( '', 'delete', 'services', $deleted_services, $low_service_count );
		push @warnings, @$warn_ref;
		push @errors, @$err_ref;
		StorProc->capture_timing( \@timing, \$phasetime, "delete of $deleted_services services" );
	    }
	    unless ($main::shutdown_requested || (@errors && $abort_on_error)) {
		delete_hosts( \%delta, $socket, $logfh );
		($warn_ref, $err_ref) = wait_for_foundation( '', 'delete', 'hosts', $deleted_hosts, $low_host_count );
		push @warnings, @$warn_ref;
		push @errors, @$err_ref;
		StorProc->capture_timing( \@timing, \$phasetime, "delete of $deleted_hosts hosts" );
	    }
	    unless ($main::shutdown_requested || (@errors && $abort_on_error)) {
		add_hosts( \%delta, $socket, $logfh );
		($warn_ref, $err_ref) = wait_for_foundation( '', 'add', 'hosts', $added_hosts, $high_host_count );
		push @warnings, @$warn_ref;
		push @errors, @$err_ref;
		StorProc->capture_timing( \@timing, \$phasetime, "add of $added_hosts hosts" );
	    }
	    unless ($main::shutdown_requested || (@errors && $abort_on_error)) {
		add_services( \%delta, $socket, $logfh );
		($warn_ref, $err_ref) = wait_for_foundation( '', 'add', 'services', $added_services, $high_service_count );
		push @warnings, @$warn_ref;
		push @errors, @$err_ref;
		StorProc->capture_timing( \@timing, \$phasetime, "add of $added_services services" );
	    }
	    unless ($main::shutdown_requested || (@errors && $abort_on_error)) {
		delete_hostgroups   ( \%delta, $socket, $logfh );
		delete_servicegroups( \%delta, $socket, $logfh );
		($warn_ref, $err_ref) = wait_for_foundation( '', 'delete', 'hostgroups', $deleted_hostgroups, $low_hostgroup_count );
		push @warnings, @$warn_ref;
		push @errors, @$err_ref;
		StorProc->capture_timing( \@timing, \$phasetime, "delete of $deleted_hostgroups hostgroups" );
		($warn_ref, $err_ref) = wait_for_foundation( '', 'delete', 'servicegroups', $deleted_servicegroups, $low_servicegroup_count );
		push @warnings, @$warn_ref;
		push @errors, @$err_ref;
		StorProc->capture_timing( \@timing, \$phasetime, "delete of $deleted_servicegroups servicegroups" );
	    }
	    unless ($main::shutdown_requested || (@errors && $abort_on_error)) {
		add_hostgroups   ( \%delta, $socket, $logfh );
		add_servicegroups( \%delta, $socket, $logfh );
		($warn_ref, $err_ref) = wait_for_foundation( '', 'add', 'hostgroups', $added_hostgroups, $high_hostgroup_count );
		push @warnings, @$warn_ref;
		push @errors, @$err_ref;
		StorProc->capture_timing( \@timing, \$phasetime, "add of $added_hostgroups hostgroups" );
		($warn_ref, $err_ref) = wait_for_foundation( '', 'add', 'servicegroups', $added_servicegroups, $high_servicegroup_count );
		push @warnings, @$warn_ref;
		push @errors, @$err_ref;
		StorProc->capture_timing( \@timing, \$phasetime, "add of $added_servicegroups servicegroups" );
	    }
	    unless ($main::shutdown_requested || (@errors && $abort_on_error)) {
		add_hostgroup_members   ( \%delta, $socket, $logfh );
		add_servicegroup_members( \%delta, $socket, $logfh );
		update_hostgroups       ( \%delta, $socket, $logfh );
		update_servicegroups    ( \%delta, $socket, $logfh );
		update_hosts            ( \%delta, $socket, $logfh );
		update_services         ( \%delta, $socket, $logfh );
		($warn_ref, $err_ref) = wait_for_foundation( '', 'update', 'hostgroup members', $updated_hostgroup_members, $high_hostgroup_member_count );
		push @warnings, @$warn_ref;
		push @errors, @$err_ref;
		($warn_ref, $err_ref) = wait_for_foundation( '', 'update', 'servicegroup members', $updated_servicegroup_members, $high_servicegroup_member_count );
		push @warnings, @$warn_ref;
		push @errors, @$err_ref;
		StorProc->capture_timing( \@timing, \$phasetime, "sending of final hostgroup, servicegroup, host, and service changes" );
	    }

	    if ($use_sync_stop_action) {
		$xml_out = "<SYNC action='stop'/>\n";
	    }
	    $xml_out .= "<GENERICLOG consolidation='SYSTEM' ApplicationType='SYSTEM' MonitorServerName='localhost' Device='$remote_host' Severity='OK' MonitorStatus='OK' TextMessage='Foundation-Monarch sync process completed. It might take up to 30 sec. for changes to show up in the status pages.' />\n";
	    print $socket $xml_out;
	    print $logfh  $xml_out if $logging;
	    $xml_out = '<SERVICE-MAINTENANCE command="close" />';
	    print $socket $xml_out;
	    print $logfh "$xml_out\n\n" if $logging;
	}

	if (not close $socket) {
	    ## FIX LATER:  This is probably an incomplete test.  We should probably test every print to the $socket.
	    push @errors, "Error:  Writing to Foundation was incomplete ($!).";
	}
	$socket = undef;
    }

    # FIX MAJOR:  This direct connection to gwcollagedb should be ignored if we are using the REST API
    # and have some other means of efficiently collecting the object-count information.
    collage_disconnect();

    if ($main::shutdown_requested) {
	push @errors, 'Error:  Processing was interrupted.';
    }

    terminate_rest_api() if $use_rest_api;

    StorProc->capture_timing( \@timing, \$phasetime, "closing of all external connections" );

    if (@errors) {
	# FIX THIS:  I'd like a cleaner way to hand back all the error strings.
	# Also, the warnings and errors won't necessarily appear here interleaved in the order they originally occurred.
	if ($logging) {
	    print $logfh join( "\n", @warnings, @errors ) . "\n";
	    close $logfh;
	}
	$errorstring = join( '<br>', @warnings, @errors );
	return \@timing, $errorstring;
    } else {
	if ($logging) {
	    print $logfh join( "\n", @warnings, "Synchronization with Foundation completed successfully. Changes were required.\n" );
	    close $logfh;
	}
	$errorstring = join( '<br>', @warnings, "Synchronization with Foundation completed successfully. Changes were required." );
	return \@timing, $errorstring;
    }
}

# Find out the name of the GroundWork Monitor server as known by Foundation.
# Return undef if we can't figure it out.
sub foundation_host {
    my $hostname       = `/bin/hostname`;
    my $long_hostname  = `/bin/hostname -f`;
    my $short_hostname = `/bin/hostname -s`;
    my @hostnames      = ();
    chomp $hostname       if $hostname;
    chomp $long_hostname  if $long_hostname;
    chomp $short_hostname if $short_hostname;
    push @hostnames, $hostname       if $hostname;
    push @hostnames, $long_hostname  if $long_hostname;
    push @hostnames, $short_hostname if $short_hostname;
    my %outcome;
    my %results;

    if (@hostnames) {
	my %unique = ();
	@unique{@hostnames} = (undef) x @hostnames;
	@hostnames = keys %unique;
	if ( $rest_api->get_hosts( \@hostnames, { depth => 'simple' }, \%outcome, \%results ) ) {
	    return ( ( sort keys %results )[0] ) if %results;
	}
    }
    if ( $rest_api->get_hosts( ['localhost'], { depth => 'simple' }, \%outcome, \%results ) ) {
	return ( ( keys %results )[0] ) if %results;
    }
    return undef;
}

sub delete_hosts {
    my $delta  = $_[0];
    my $socket = $_[1];
    my $logfh  = $_[2];

    my $cnt       = 0;
    my @xmlstring = ();
    foreach my $host (keys %{ $delta->{'delete'}{'host'} }) {
	push @xmlstring, "\t<Host Host='".$host."' />\n";
	if (++$cnt == $max_bulk_host_add) {
	    write_command_xml( $socket, $logfh, "REMOVE", join( '', @xmlstring ) );
	    @xmlstring = ();
	    $cnt = 0;
	}
    }
    write_command_xml( $socket, $logfh, "REMOVE", join( '', @xmlstring ) ) if (@xmlstring);
}

sub delete_hosts_via_rest {
    my $delta = $_[0];
    my $logfh = $_[1];

    my %outcome = ();
    my @results = ();
    my @errors  = ();

    my $cnt       = 0;
    my @hostnames = ();
    foreach my $host ( keys %{ $delta->{'delete'}{'host'} } ) {
	push @hostnames, $host;
	if ( ++$cnt == $max_rest_objects ) {
	    if ( not $rest_api->delete_hosts( \@hostnames, {}, \%outcome, \@results ) ) {
		log_outcome $logfh, \%outcome, 'host deletion';
		log_results $logfh, \@results, 'host deletion';
		push @errors, "ERROR:  Failed to delete all intended hosts." if not @errors;
	    }
	    @hostnames = ();
	    $cnt       = 0;
	}
    }
    if ( @hostnames and not $rest_api->delete_hosts( \@hostnames, {}, \%outcome, \@results ) ) {
	log_outcome $logfh, \%outcome, 'host deletion';
	log_results $logfh, \@results, 'host deletion';
	push @errors, "ERROR:  Failed to delete all intended hosts." if not @errors;
    }
    return \@errors;
}

sub delete_services {
    my $delta  = $_[0];
    my $socket = $_[1];
    my $logfh  = $_[2];

    my $cnt       = 0;
    my @xmlstring = ();
    foreach my $host (keys %{ $delta->{'delete'}{'service'} }) {
	foreach my $service (keys %{ $delta->{'delete'}{'service'}{$host} }) {
	    push @xmlstring, "\t<Service Host='".$host."' ServiceDescription='".$service."' />\n";
	    if (++$cnt == $max_bulk_host_add) {
		write_command_xml( $socket, $logfh, "REMOVE", join( '', @xmlstring ) );
		@xmlstring = ();
		$cnt = 0;
	    }
	}
    }
    write_command_xml( $socket, $logfh, "REMOVE", join( '', @xmlstring ) ) if (@xmlstring);
}

sub delete_services_via_rest {
    my $delta = $_[0];
    my $logfh = $_[1];

    my %outcome = ();
    my @results = ();
    my @errors  = ();

    my $cnt          = 0;
    my @hostnames    = ();
    my @servicenames = ();
    foreach my $host ( keys %{ $delta->{'delete'}{'service'} } ) {
	foreach my $service ( keys %{ $delta->{'delete'}{'service'}{$host} } ) {
	    push @hostnames,    $host;
	    push @servicenames, $service;
	    if ( ++$cnt == $max_rest_objects ) {
		if ( not $rest_api->delete_services( \@servicenames, { hostname => \@hostnames }, \%outcome, \@results ) ) {
		    log_outcome $logfh, \%outcome, 'service deletion';
		    log_results $logfh, \@results, 'service deletion';
		    push @errors, "ERROR:  Failed to delete all intended host services." if not @errors;
		}
		@hostnames    = ();
		@servicenames = ();
		$cnt          = 0;
	    }
	}
    }
    if ( @servicenames and not $rest_api->delete_services( \@servicenames, { hostname => \@hostnames }, \%outcome, \@results ) ) {
	log_outcome $logfh, \%outcome, 'service deletion';
	log_results $logfh, \@results, 'service deletion';
	push @errors, "ERROR:  Failed to delete all intended host services." if not @errors;
    }
    return \@errors;
}

sub add_hosts {
    my $delta  = $_[0];
    my $socket = $_[1];
    my $logfh  = $_[2];

    my $cnt       = 0;
    my @xmlstring = ();
    my $alias;
    my $notes;
    foreach my $host (keys %{ $delta->{'add'}{'host'} }) {
	$alias = $delta->{'add'}{'host'}{$host}{'alias'};
	$notes = $delta->{'add'}{'host'}{$host}{'notes'};

	# FIX LATER:  Is the existence of an alias guaranteed here?  Yes, supposedly.
	$alias =~ s/\n/ /g;
	$alias =~ s/<br>/ /ig;
	$alias =~ s/&/&amp;/g;
	$alias =~ s/"/&quot;/g;
	$alias =~ s/'/&apos;/g;
	$alias =~ s/</&lt;/g;
	$alias =~ s/>/&gt;/g;

	if (defined $notes) {
	    $notes =~ s/&/&amp;/g;
	    $notes =~ s/"/&quot;/g;
	    $notes =~ s/'/&apos;/g;
	    $notes =~ s/</&lt;/g;
	    $notes =~ s/>/&gt;/g;
	}

	push @xmlstring,
	    "\t<Host Host='",      $host,
	    "' Description='",     $host,
	    ((defined($notes) && $notes ne '') ? ("' Notes='" . $notes) : ''),
	    "' Device='",          $delta->{'add'}{'host'}{$host}{'address'},
	    "' DisplayName='",     $host,
	    "' LastStateChange='", $change_time,
	    "' Parent='",          $delta->{'add'}{'host'}{$host}{'parents'},
	    "' Alias='",           $alias,
	    "' />\n";

	my @xml_message = ();
	push @xml_message, "\t<LogMessage ";
	push @xml_message, "MonitorServerName=\"$thisnagios\" ";
	push @xml_message, "Host=\"$host\" ";
	## if have IP address, use it; else set device to host name
	my $hostipaddress =
	  ( exists $delta->{'add'}{'host'}{$host}{'address'} )
	  ? $delta->{'add'}{'host'}{$host}{'address'}
	  : (     exists $delta->{'alter'}{'host'}
	      and exists $delta->{'alter'}{'host'}{$host}
	      and exists $delta->{'alter'}{'host'}{$host}{'address'} )
	  ? $delta->{'alter'}{'host'}{$host}{'address'}
	  : '';
	push @xml_message, $hostipaddress ? "Device=\"$hostipaddress\" " : "Device=\"$host\" ";
	push @xml_message, 'Severity="LOW" ';
	push @xml_message, 'MonitorStatus="PENDING" ';
	push @xml_message, "TextMessage=\"New $host host is awaiting first check result.\" ";
	push @xml_message, "ReportDate=\"$report_time\" ";
	push @xml_message, "LastInsertDate=\"$change_time\" ";
	push @xml_message, "SubComponent=\"$host\" ";
	push @xml_message, 'ErrorType="HOST ALERT" ';
	push @xml_message, "/>\n";

	push @xmlstring, join( '', @xml_message );

	if (++$cnt == $max_bulk_host_add) {
	    write_command_xml( $socket, $logfh, "ADD", join( '', @xmlstring ) );
	    @xmlstring = ();
	    $cnt = 0;
	}
    }
    write_command_xml( $socket, $logfh, "ADD", join( '', @xmlstring ) ) if (@xmlstring);
}

# FIX MAJOR:  The Socket API would, in addition to adding a host, send a log message
# to Foundation announcing the new birth.  Will the REST API do the same internally?
# Among other fields, that log message would set Severity, ReportDate, LastInsertDate,
# and TextMessage.  Possibly, Status Viewer might depend in some way on such stuff.
sub add_hosts_via_rest {
    my $delta = $_[0];
    my $logfh = $_[1];

    my %outcome = ();
    my @results = ();
    my @errors  = ();

    my $cnt   = 0;
    my @hosts = ();
    my $alias;
    my $notes;
    my $parents;
    foreach my $host ( keys %{ $delta->{'add'}{'host'} } ) {
	$alias   = $delta->{'add'}{'host'}{$host}{'alias'};
	$notes   = $delta->{'add'}{'host'}{$host}{'notes'};
	$parents = $delta->{'add'}{'host'}{$host}{'parents'};

	# FIX LATER:  Is the existence of an alias guaranteed here?  Yes, supposedly.
	$alias =~ s/\n/ /g;
	$alias =~ s/<br>/ /ig;

	my %h_object = (
	    hostName             => $host,
	    description          => $host,
	    monitorStatus        => 'PENDING',
	    appType              => 'NAGIOS',
	    deviceIdentification => $delta->{'add'}{'host'}{$host}{'address'},
	    deviceDisplayName    => $host
	);

	my %properties = (
	    LastStateChange => $change_time,
	    Alias           => $alias
	);
	$properties{Notes}  = $notes   if defined($notes)   && $notes   ne '';
	$properties{Parent} = $parents if defined($parents) && $parents ne '';

	$h_object{properties} = \%properties;

	push @hosts, \%h_object;
	if ( ++$cnt == $max_rest_objects ) {
	    if ( not $rest_api->upsert_hosts( \@hosts, {}, \%outcome, \@results ) ) {
		log_outcome $logfh, \%outcome, 'host addition';
		log_results $logfh, \@results, 'host addition';
		push @errors, "ERROR:  Failed to add all intended hosts." if not @errors;
	    }
	    @hosts = ();
	    $cnt   = 0;
	}
    }
    if ( @hosts and not $rest_api->upsert_hosts( \@hosts, {}, \%outcome, \@results ) ) {
	log_outcome $logfh, \%outcome, 'host addition';
	log_results $logfh, \@results, 'host addition';
	push @errors, "ERROR:  Failed to add all intended hosts." if not @errors;
    }
    return \@errors;
}

# Add new services
sub add_services {
    my $delta  = $_[0];
    my $socket = $_[1];
    my $logfh  = $_[2];

    my $cnt       = 0;
    my @xmlstring = ();
    my $notes;
    foreach my $host (keys %{ $delta->{'add'}{'service'} }) {
	foreach my $service (keys %{ $delta->{'add'}{'service'}{$host} }) {
	    $notes = $delta->{'add'}{'servicenotes'}{$host}{$service};

	    if (defined $notes) {
		$notes =~ s/&/&amp;/g;
		$notes =~ s/"/&quot;/g;
		$notes =~ s/'/&apos;/g;
		$notes =~ s/</&lt;/g;
		$notes =~ s/>/&gt;/g;
	    }

	    push @xmlstring,
		"\t<Service Host='", $host,
		"' ServiceDescription='", $service,
		((defined($notes) && $notes ne '') ? ("' Notes='" . $notes) : ''),
		"' CheckType='ACTIVE' StateType='SOFT' MonitorStatus='PENDING' LastHardState='PENDING' LastStateChange='",
		$change_time, "' />\n";

	    my @xml_message = ();
	    push @xml_message, "\t<LogMessage ";
	    push @xml_message, "MonitorServerName=\"$thisnagios\" ";
	    push @xml_message, "Host=\"$host\" ";
	    ## if have IP address, use it; else set device to host name
	    my $hostipaddress =
	      (       exists $delta->{'add'}{'host'}
		  and exists $delta->{'add'}{'host'}{$host}
		  and exists $delta->{'add'}{'host'}{$host}{'address'} )
	      ? $delta->{'add'}{'host'}{$host}{'address'}
	      : (     exists $delta->{'alter'}{'host'}
		  and exists $delta->{'alter'}{'host'}{$host}
		  and exists $delta->{'alter'}{'host'}{$host}{'address'} )
	      ? $delta->{'alter'}{'host'}{$host}{'address'}
	      : '';
	    push @xml_message, $hostipaddress ? "Device=\"$hostipaddress\" " : "Device=\"$host\" ";
	    push @xml_message, "ServiceDescription=\"$service\" ";
	    push @xml_message, 'Severity="LOW" ';
	    push @xml_message, 'MonitorStatus="PENDING" ';
	    push @xml_message, "TextMessage=\"New $service service is awaiting first check result.\" ";
	    push @xml_message, "ReportDate=\"$report_time\" ";
	    push @xml_message, "LastInsertDate=\"$change_time\" ";
	    push @xml_message, "SubComponent=\"$host:$service\" ";
	    push @xml_message, 'ErrorType="SERVICE ALERT" ';
	    push @xml_message, "/>\n";

	    push @xmlstring, join( '', @xml_message );

	    if (++$cnt == $max_bulk_host_add)  {
		write_command_xml( $socket, $logfh, "ADD", join( '', @xmlstring ) );
		@xmlstring = ();
		$cnt = 0;
	    }
	}
    }
    write_command_xml( $socket, $logfh, "ADD", join( '', @xmlstring ) ) if (@xmlstring);
}

# FIX MAJOR:  The Socket API would, in addition to adding a host service, send a log message
# to Foundation announcing the new birth.  Will the REST API do the same internally?
# Among other fields, that log message would set Severity, ReportDate, LastInsertDate,
# and TextMessage.  Possibly, Status Viewer might depend in some way on such stuff.
sub add_services_via_rest {
    my $delta = $_[0];
    my $logfh = $_[1];

    my %outcome = ();
    my @results = ();
    my @errors  = ();

    my $cnt      = 0;
    my @services = ();
    my $notes;
    foreach my $host ( keys %{ $delta->{'add'}{'service'} } ) {
	foreach my $service ( keys %{ $delta->{'add'}{'service'}{$host} } ) {
	    $notes = $delta->{'add'}{'servicenotes'}{$host}{$service};

	    my %s_object = (
		hostName        => $host,
		description     => $service,
		appType         => 'NAGIOS',
		checkType       => 'ACTIVE',
		stateType       => 'SOFT',
		monitorStatus   => 'PENDING',
		lastHardState   => 'PENDING',
		lastStateChange => $change_time
	    );

	    my %properties = ();
	    $properties{Notes} = $notes if defined($notes) && $notes ne '';
	    $s_object{properties} = \%properties if %properties;

	    push @services, \%s_object;
	    if ( ++$cnt == $max_rest_objects ) {
		if ( not $rest_api->upsert_services( \@services, {}, \%outcome, \@results ) ) {
		    log_outcome $logfh, \%outcome, 'service addition';
		    log_results $logfh, \@results, 'service addition';
		    push @errors, "ERROR:  Failed to add all intended host services." if not @errors;
		}
		@services = ();
		$cnt      = 0;
	    }
	}
    }
    if ( @services and not $rest_api->upsert_services( \@services, {}, \%outcome, \@results ) ) {
	log_outcome $logfh, \%outcome, 'service addition';
	log_results $logfh, \@results, 'service addition';
	push @errors, "ERROR:  Failed to add all intended host services." if not @errors;
    }
    return \@errors;
}

sub update_hosts {
    my $delta  = $_[0];
    my $socket = $_[1];
    my $logfh  = $_[2];

    my $cnt       = 0;
    my @xmlstring = ();
    my $alias;
    my $address;
    my $notes;
    my $parents;
    foreach my $host (keys %{ $delta->{'alter'}{'host'} }) {
	$alias   = $delta->{'alter'}{'host'}{$host}{'alias'};
	$address = $delta->{'alter'}{'host'}{$host}{'address'};
	$notes   = $delta->{'alter'}{'host'}{$host}{'notes'};
	$parents = $delta->{'alter'}{'host'}{$host}{'parents'};
	push @xmlstring, "\t<Host Host='", $host, "' Description='", $host, "'";
	if (defined $alias) {
	    $alias =~ s/\n/ /g;
	    $alias =~ s/<br>/ /ig;
	    $alias =~ s/&/&amp;/g;
	    $alias =~ s/"/&quot;/g;
	    $alias =~ s/'/&apos;/g;
	    $alias =~ s/</&lt;/g;
	    $alias =~ s/>/&gt;/g;
	    push @xmlstring, " Alias='", $alias, "'";
	}
	if (defined $address) {
	    push @xmlstring, " Device='", $address , "'";
	}
	if (defined $notes) {
	    $notes =~ s/&/&amp;/g;
	    $notes =~ s/"/&quot;/g;
	    $notes =~ s/'/&apos;/g;
	    $notes =~ s/</&lt;/g;
	    $notes =~ s/>/&gt;/g;
	    push @xmlstring, " Notes='", $notes, "'";
	}
	if (defined $parents) {
	    push @xmlstring, " Parent='", $parents, "'";
	}
	push @xmlstring, " />\n";
	if (++$cnt == $max_bulk_host_add) {
	    write_command_xml( $socket, $logfh, "MODIFY", join( '', @xmlstring ) );
	    @xmlstring = ();
	    $cnt = 0;
	}
    }
    write_command_xml( $socket, $logfh, "MODIFY", join( '', @xmlstring ) ) if (@xmlstring);
}

sub update_hosts_via_rest {
    my $delta = $_[0];
    my $logfh = $_[1];

    my %outcome = ();
    my @results = ();
    my @errors  = ();

    my $cnt   = 0;
    my @hosts = ();
    my $alias;
    my $address;
    my $notes;
    my $parents;
    foreach my $host ( keys %{ $delta->{'alter'}{'host'} } ) {
	$alias   = $delta->{'alter'}{'host'}{$host}{'alias'};
	$address = $delta->{'alter'}{'host'}{$host}{'address'};
	$notes   = $delta->{'alter'}{'host'}{$host}{'notes'};
	$parents = $delta->{'alter'}{'host'}{$host}{'parents'};

	my %h_object = ();
	$h_object{hostName}             = $host;
	$h_object{description}          = $host;
	$h_object{deviceIdentification} = $address if defined $address;

	my %properties = ();
	if ( defined $alias ) {
	    $alias =~ s/\n/ /g;
	    $alias =~ s/<br>/ /ig;
	    $properties{Alias} = $alias;
	}
	$properties{Notes}  = $notes   if defined($notes);
	$properties{Parent} = $parents if defined($parents);

	$h_object{properties} = \%properties if %properties;

	push @hosts, \%h_object;
	if ( ++$cnt == $max_rest_objects ) {
	    if ( not $rest_api->upsert_hosts( \@hosts, {}, \%outcome, \@results ) ) {
		log_outcome $logfh, \%outcome, 'host updating';
		log_results $logfh, \@results, 'host updating';
		push @errors, "ERROR:  Failed to update all intended hosts." if not @errors;
	    }
	    @hosts = ();
	    $cnt   = 0;
	}
    }
    if ( @hosts and not $rest_api->upsert_hosts( \@hosts, {}, \%outcome, \@results ) ) {
	log_outcome $logfh, \%outcome, 'host updating';
	log_results $logfh, \@results, 'host updating';
	push @errors, "ERROR:  Failed to update all intended hosts." if not @errors;
    }
    return \@errors;
}

# Change existing service properties
sub update_services {
    my $delta  = $_[0];
    my $socket = $_[1];
    my $logfh  = $_[2];

    my $cnt       = 0;
    my @xmlstring = ();
    my $notes;
    foreach my $host (keys %{ $delta->{'alter'}{'service'} }) {
	foreach my $service (keys %{ $delta->{'alter'}{'service'}{$host} }) {
	    ## No {'notes'} appended, for now.  See the audit routine for this construction.
	    $notes = $delta->{'alter'}{'service'}{$host}{$service};

	    if (defined $notes) {
		$notes =~ s/&/&amp;/g;
		$notes =~ s/"/&quot;/g;
		$notes =~ s/'/&apos;/g;
		$notes =~ s/</&lt;/g;
		$notes =~ s/>/&gt;/g;
	    }

	    push @xmlstring,
		"\t<Service Host='", $host,
		"' ServiceDescription='", $service,
		((defined($notes) && $notes ne '') ? ("' Notes='" . $notes) : ''),
		"' />\n";
	    if (++$cnt == $max_bulk_host_add)  {
		write_command_xml( $socket, $logfh, "MODIFY", join( '', @xmlstring ) );
		@xmlstring = ();
		$cnt = 0;
	    }
	}
    }
    write_command_xml( $socket, $logfh, "MODIFY", join( '', @xmlstring ) ) if (@xmlstring);
}

sub update_services_via_rest {
    my $delta = $_[0];
    my $logfh = $_[1];

    my %outcome = ();
    my @results = ();
    my @errors  = ();

    my $cnt      = 0;
    my @services = ();
    my $notes;
    foreach my $host ( keys %{ $delta->{'alter'}{'service'} } ) {
	foreach my $service ( keys %{ $delta->{'alter'}{'service'}{$host} } ) {
	    ## No {'notes'} appended, for now.  See the audit routine for this construction.
	    $notes = $delta->{'alter'}{'service'}{$host}{$service};

	    my %s_object = ();
	    $s_object{hostName}    = $host;
	    $s_object{description} = $service;

	    my %properties = ();
	    ## FIX MINOR:  This code currently simply mirrors the legacy update_services() routine, but why
	    ## should we apply the ($notes ne '') condition here?  We're not doing it when we update notes for
	    ## hosts, and we might want to allow it anyway when we eventually have full lifecycle support for
	    ## such fields (GWMON-11446), allowing an empty value to delete the existing property entirely.
	    $properties{Notes} = $notes if defined($notes) && $notes ne '';
	    $s_object{properties} = \%properties if %properties;

	    push @services, \%s_object;
	    if ( ++$cnt == $max_rest_objects ) {
		if ( not $rest_api->upsert_services( \@services, {}, \%outcome, \@results ) ) {
		    log_outcome $logfh, \%outcome, 'service updating';
		    log_results $logfh, \@results, 'service updating';
		    push @errors, "ERROR:  Failed to update all intended host services." if not @errors;
		}
		@services = ();
		$cnt      = 0;
	    }
	}
    }
    if ( @services and not $rest_api->upsert_services( \@services, {}, \%outcome, \@results ) ) {
	log_outcome $logfh, \%outcome, 'service updating';
	log_results $logfh, \@results, 'service updating';
	push @errors, "ERROR:  Failed to update all intended host services." if not @errors;
    }
    return \@errors;
}

sub delete_hostgroups {
    my $delta  = $_[0];
    my $socket = $_[1];
    my $logfh  = $_[2];

    my $cnt       = 0;
    my @xmlstring = ();
    foreach my $hostgroup (keys %{ $delta->{'delete'}{'hostgroup'} }) {
	push @xmlstring, "\t<HostGroup HostGroup='$hostgroup' />\n";
	if (++$cnt == $max_bulk_host_add)  {
	    write_command_xml( $socket, $logfh, "REMOVE", join( '', @xmlstring ) );
	    @xmlstring = ();
	    $cnt = 0;
	}
    }
    write_command_xml( $socket, $logfh, "REMOVE", join( '', @xmlstring ) ) if (@xmlstring)
}

sub delete_hostgroups_via_rest {
    my $delta = $_[0];
    my $logfh = $_[1];

    my %outcome = ();
    my @results = ();
    my @errors  = ();

    my $cnt            = 0;
    my @hostgroupnames = ();
    foreach my $hostgroup ( keys %{ $delta->{'delete'}{'hostgroup'} } ) {
	push @hostgroupnames, $hostgroup;
	if ( ++$cnt == $max_rest_objects ) {
	    if ( not $rest_api->delete_hostgroups( \@hostgroupnames, {}, \%outcome, \@results ) ) {
		log_outcome $logfh, \%outcome, 'hostgroup deletion';
		log_results $logfh, \@results, 'hostgroup deletion';
		push @errors, "ERROR:  Failed to delete all intended hostgroups." if not @errors;
	    }
	    @hostgroupnames = ();
	    $cnt            = 0;
	}
    }
    if ( @hostgroupnames and not $rest_api->delete_hostgroups( \@hostgroupnames, {}, \%outcome, \@results ) ) {
	log_outcome $logfh, \%outcome, 'hostgroup deletion';
	log_results $logfh, \@results, 'hostgroup deletion';
	push @errors, "ERROR:  Failed to delete all intended hostgroups." if not @errors;
    }
    return \@errors;
}

sub delete_servicegroups {
    my $delta  = $_[0];
    my $socket = $_[1];
    my $logfh  = $_[2];

    my $cnt       = 0;
    my @xmlstring = ();
    foreach my $servicegroup (keys %{ $delta->{'delete'}{'servicegroup'} }) {
	push @xmlstring, "\t<ServiceGroup ServiceGroup='$servicegroup' />\n";
	if (++$cnt == $max_bulk_host_add)  {
	    write_command_xml( $socket, $logfh, "REMOVE", join( '', @xmlstring ) );
	    @xmlstring = ();
	    $cnt = 0;
	}
    }
    write_command_xml( $socket, $logfh, "REMOVE", join( '', @xmlstring ) ) if (@xmlstring);
}

sub delete_servicegroups_via_rest {
    my $delta = $_[0];
    my $logfh = $_[1];

    my %outcome = ();
    my @results = ();
    my @errors  = ();

    my $cnt               = 0;
    my @servicegroupnames = ();
    foreach my $servicegroup ( keys %{ $delta->{'delete'}{'servicegroup'} } ) {
	push @servicegroupnames, $servicegroup;
	if ( ++$cnt == $max_rest_objects ) {
	    if ( not $rest_api->delete_servicegroups( \@servicegroupnames, {}, \%outcome, \@results ) ) {
		log_outcome $logfh, \%outcome, 'servicegroup deletion';
		log_results $logfh, \@results, 'servicegroup deletion';
		push @errors, "ERROR:  Failed to delete all intended servicegroups." if not @errors;
	    }
	    @servicegroupnames = ();
	    $cnt               = 0;
	}
    }
    if ( @servicegroupnames and not $rest_api->delete_servicegroups( \@servicegroupnames, {}, \%outcome, \@results ) ) {
	log_outcome $logfh, \%outcome, 'servicegroup deletion';
	log_results $logfh, \@results, 'servicegroup deletion';
	push @errors, "ERROR:  Failed to delete all intended servicegroups." if not @errors;
    }
    return \@errors;
}

sub add_hostgroups {
    my $delta  = $_[0];
    my $socket = $_[1];
    my $logfh  = $_[2];

    my $cnt       = 0;
    my @xmlstring = ();
    my $alias;
    my $notes;
    foreach my $hostgroup (keys %{ $delta->{'add'}{'hostgroup'} }) {
	## build hostgroup in chunks
	$alias = $delta->{'add'}{'hostgroup'}{$hostgroup}{'alias'};
	$notes = $delta->{'add'}{'hostgroup'}{$hostgroup}{'notes'};

	if (defined $alias) {
	    $alias =~ s/\n/ /g;
	    $alias =~ s/<br>/ /ig;
	    $alias =~ s/&/&amp;/g;
	    $alias =~ s/"/&quot;/g;
	    $alias =~ s/'/&apos;/g;
	    $alias =~ s/</&lt;/g;
	    $alias =~ s/>/&gt;/g;
	}
	if (defined $notes) {
	    $notes =~ s/&/&amp;/g;
	    $notes =~ s/"/&quot;/g;
	    $notes =~ s/'/&apos;/g;
	    $notes =~ s/</&lt;/g;
	    $notes =~ s/>/&gt;/g;
	}

	push @xmlstring,
	    "\t<HostGroup HostGroup='", $hostgroup,
	    ((defined($alias) && $alias ne '') ? ("' Alias='" . $alias) : ''),
	    ((defined($notes) && $notes ne '') ? ("' Description='" . $notes) : ''),
	    "' />\n";
	if (++$cnt == $max_bulk_host_add)  {
	    write_command_xml( $socket, $logfh, "ADD", join( '', @xmlstring ) );
	    @xmlstring = ();
	    $cnt = 0;
	}
    }
    write_command_xml( $socket, $logfh, "ADD", join( '', @xmlstring ) ) if (@xmlstring);
}

sub add_hostgroups_via_rest {
    my $delta = $_[0];
    my $logfh = $_[1];

    my %outcome = ();
    my @results = ();
    my @errors  = ();

    my $cnt        = 0;
    my @hostgroups = ();
    my $alias;
    my $notes;
    foreach my $hostgroup ( keys %{ $delta->{'add'}{'hostgroup'} } ) {
	## build hostgroup in chunks
	$alias = $delta->{'add'}{'hostgroup'}{$hostgroup}{'alias'};
	$notes = $delta->{'add'}{'hostgroup'}{$hostgroup}{'notes'};

	if ( defined $alias ) {
	    $alias =~ s/\n/ /g;
	    $alias =~ s/<br>/ /ig;
	}

	my %hg_object = ();
	$hg_object{name}        = $hostgroup;
	$hg_object{appType}     = 'NAGIOS';
	$hg_object{alias}       = $alias if defined($alias) && $alias ne '';
	$hg_object{description} = $notes if defined($notes) && $notes ne '';
	push @hostgroups, \%hg_object;
	if ( ++$cnt == $max_rest_objects ) {
	    if ( not $rest_api->upsert_hostgroups( \@hostgroups, {}, \%outcome, \@results ) ) {
		log_outcome $logfh, \%outcome, 'hostgroup addition';
		log_results $logfh, \@results, 'hostgroup addition';
		push @errors, "ERROR:  Failed to add all intended hostgroups." if not @errors;
	    }
	    @hostgroups = ();
	    $cnt        = 0;
	}
    }
    if ( @hostgroups and not $rest_api->upsert_hostgroups( \@hostgroups, {}, \%outcome, \@results ) ) {
	log_outcome $logfh, \%outcome, 'hostgroup addition';
	log_results $logfh, \@results, 'hostgroup addition';
	push @errors, "ERROR:  Failed to add all intended hostgroups." if not @errors;
    }
    return \@errors;
}

sub add_servicegroups {
    my $delta  = $_[0];
    my $socket = $_[1];
    my $logfh  = $_[2];

    my $cnt       = 0;
    my @xmlstring = ();
    my $notes;
    foreach my $servicegroup (keys %{ $delta->{'add'}{'servicegroup'} }) {
	## build servicegroup in chunks
	$notes = $delta->{'add'}{'servicegroup'}{$servicegroup}{'notes'};

	if (defined $notes) {
	    $notes =~ s/&/&amp;/g;
	    $notes =~ s/"/&quot;/g;
	    $notes =~ s/'/&apos;/g;
	    $notes =~ s/</&lt;/g;
	    $notes =~ s/>/&gt;/g;
	}

	push @xmlstring,
	    "\t<ServiceGroup ServiceGroup='", $servicegroup,
	    ((defined($notes) && $notes ne '') ? ("' Description='" . $notes) : ''),
	    "' />\n";
	if (++$cnt == $max_bulk_host_add)  {
	    write_command_xml( $socket, $logfh, "ADD", join( '', @xmlstring ) );
	    @xmlstring = ();
	    $cnt = 0;
	}
    }
    write_command_xml( $socket, $logfh, "ADD", join( '', @xmlstring ) ) if (@xmlstring);
}

sub add_servicegroups_via_rest {
    my $delta = $_[0];
    my $logfh = $_[1];

    my %outcome = ();
    my @results = ();
    my @errors  = ();

    my $cnt       = 0;
    my @servicegroups = ();
    my $notes;
    foreach my $servicegroup (keys %{ $delta->{'add'}{'servicegroup'} }) {
	## build servicegroup in chunks
	$notes = $delta->{'add'}{'servicegroup'}{$servicegroup}{'notes'};

	my %sg_object = ();
	$sg_object{name}        = $servicegroup;
	$sg_object{appType}     = 'NAGIOS';
	$sg_object{description} = $notes if defined($notes) && $notes ne '';
	## FIX MAJOR:  Derive an agent ID from somewhere to populate here.
	## (Implement a monarch_guid field in the monarch.setup table, of type "config",
	## and figure out how to treat this for child server deployments.  Perhaps have
	## similar fields in the monarch.monarch_group_props table, and somehow transfer
	## the values as needed for each individual child server.)
	# $sg_object{agentId}     = 'FIX MAJOR';
	push @servicegroups, \%sg_object;
	if (++$cnt == $max_rest_objects)  {
	    if ( not $rest_api->upsert_servicegroups( \@servicegroups, {}, \%outcome, \@results ) ) {
		log_outcome $logfh, \%outcome, 'servicegroup addition';
		log_results $logfh, \@results, 'servicegroup addition';
		push @errors, "ERROR:  Failed to add all intended servicegroups." if not @errors;
	    }
	    @servicegroups = ();
	    $cnt = 0;
	}
    }
    if ( @servicegroups and not $rest_api->upsert_servicegroups( \@servicegroups, {}, \%outcome, \@results ) ) {
	log_outcome $logfh, \%outcome, 'servicegroup addition';
	log_results $logfh, \@results, 'servicegroup addition';
	push @errors, "ERROR:  Failed to add all intended servicegroups." if not @errors;
    }
    return \@errors;
}

# FIX LATER:  bundle the socket writes here
sub add_hostgroup_members {
    my $delta  = $_[0];
    my $socket = $_[1];
    my $logfh  = $_[2];

    foreach my $hostgroup (keys %{ $delta->{'add'}{'hostgroup'} }) {
	my $total_keys = keys %{ $delta->{'add'}{'hostgroup'}{$hostgroup}{'members'} };
	my $key_index  = 0;
	my @members    = ();
	foreach my $host (keys %{ $delta->{'add'}{'hostgroup'}{$hostgroup}{'members'} }) {
	    push @members, "\t\t<Host Host='".$host."' />\n";
	    if (++$key_index == $total_keys || ($key_index % $maxhostsendcount) == 0) {
		my $xmlstring = join( '', "\t<HostGroup HostGroup='$hostgroup' >\n", @members, "\t</HostGroup>\n" );
		write_command_xml( $socket, $logfh, "MODIFY", $xmlstring );
		@members = ();
	    }
	}
    }
}

# FIX MAJOR:  Perhaps we need a paradigm shift in that we should no longer be clearing out all the hostgroup
# members and then adding all of them back in, when using the REST API.  And if we do still clear them all out,
# where is that supposed to be happening now?  (Or is that not corresponding to the use of this routine, which
# depends on the 'add' branch of the delta (and thereby only new hostgroups, which start out empty?)
#
# FIX MAJOR:  Test updating host-membership lists in multiple hostgroups in the same Commit operation.
#
# FIX MAJOR:  Ask Roger if there is any issue here comparable to that in the Socket API, where we limited
# the number of hosts that could be added to a given hostgroup in any one packet.  In contrast, in the
# REST API, it seems that we can only ever set the hostgroup membership as a whole.
sub add_hostgroup_members_via_rest {
    my $delta = $_[0];
    my $logfh = $_[1];

    my %outcome = ();
    my @results = ();
    my @errors  = ();

    my $cnt        = 0;
    my @hostgroups = ();
    foreach my $hostgroup ( keys %{ $delta->{'add'}{'hostgroup'} } ) {
	my @members = ();
	## FIX MAJOR:  Make sure that we include all members of the hostgroup, even those that existed before.
	foreach my $host ( keys %{ $delta->{'add'}{'hostgroup'}{$hostgroup}{'members'} } ) {
	    push @members, { hostName => $host };
	}
	if (@members) {
	    my @first_members = splice @members, 0, $max_rest_member_objects;
	    push @hostgroups, { name => $hostgroup, hosts => \@first_members };
	    ## FIX MAJOR:  We might want to use 1 instead of $max_rest_objects here.
	    if ( ++$cnt == $max_rest_objects || @members ) {
		do {
		    if ( not $rest_api->upsert_hostgroups( \@hostgroups, {}, \%outcome, \@results ) ) {
			log_outcome $logfh, \%outcome, 'hostgroup member addition';
			log_results $logfh, \@results, 'hostgroup member addition';
			push @errors, "ERROR:  Failed to add all intended hostgroup members." if not @errors;
		    }
		    @first_members = splice @members, 0, $max_rest_member_objects;
		    @hostgroups = (
			{
			    name  => $hostgroup,
			    hosts => \@first_members
			}
		    );
		} while (@first_members);
		@hostgroups = ();
		$cnt        = 0;
	    }
	}
    }
    if ( @hostgroups and not $rest_api->upsert_hostgroups( \@hostgroups, {}, \%outcome, \@results ) ) {
	log_outcome $logfh, \%outcome, 'hostgroup member addition';
	log_results $logfh, \@results, 'hostgroup member addition';
	push @errors, "ERROR:  Failed to add all intended hostgroup members." if not @errors;
    }
    return \@errors;
}

# FIX LATER:  bundle the socket writes here
sub add_servicegroup_members {
    my $delta  = $_[0];
    my $socket = $_[1];
    my $logfh  = $_[2];

    foreach my $servicegroup (keys %{ $delta->{'add'}{'servicegroup'} }) {
	## Find the total number of host+services in this group
	my $total_keys = 0;
	foreach my $host (keys %{ $delta->{'add'}{'servicegroup'}{$servicegroup}{'members'} }) {
	    $total_keys += scalar keys %{ $delta->{'add'}{'servicegroup'}{$servicegroup}{'members'}{$host} };
	}
	my $key_index = 0;
	my @members   = ();
	foreach my $host (keys %{ $delta->{'add'}{'servicegroup'}{$servicegroup}{'members'} }) {
	    foreach my $service (keys %{ $delta->{'add'}{'servicegroup'}{$servicegroup}{'members'}{$host} }) {
		push @members, "\t\t<Service Host='".$host."' ServiceDescription='".$service."' />\n";
		if (++$key_index == $total_keys || ($key_index % $maxhostsendcount) == 0) {
		    my $xmlstring = join( '', "\t<ServiceGroup ServiceGroup='$servicegroup' >\n", @members, "\t</ServiceGroup>\n" );
		    write_command_xml( $socket, $logfh, "MODIFY", $xmlstring );
		    @members = ();
		}
	    }
	}
    }
}

# FIX MAJOR:  Perhaps we need a paradigm shift in that we should no longer be clearing out all the servicegroup
# members and then adding all of them back in, when using the REST API.  And if we do still clear them all out,
# where is that supposed to be happening now?  (Or is that not corresponding to the use of this routine, which
# depends on the 'add' branch of the delta (and thereby only new servicegroups, which start out empty?)
#
# FIX MAJOR:  Test updating service-membership lists in multiple servicegroups in the same Commit operation.
#
# FIX MAJOR:  Ask Roger if there is any issue here comparable to that in the Socket API, where we limited
# the number of host services that could be added to a given servicegroup in any one packet.  In contrast,
# in the REST API, it seems that we can only ever set the servicegroup membership as a whole.
sub add_servicegroup_members_via_rest {
    my $delta = $_[0];
    my $logfh = $_[1];

    my %outcome = ();
    my @results = ();
    my @errors  = ();

    my $cnt           = 0;
    my @servicegroups = ();
    foreach my $servicegroup ( keys %{ $delta->{'add'}{'servicegroup'} } ) {
	my @members = ();
	## FIX MAJOR:  Make sure that we include all members of the servicegroup, even those that existed before.
	foreach my $host ( keys %{ $delta->{'add'}{'servicegroup'}{$servicegroup}{'members'} } ) {
	    foreach my $service ( keys %{ $delta->{'add'}{'servicegroup'}{$servicegroup}{'members'}{$host} } ) {
		push @members, { host => $host, service => $service };
	    }
	}
	if (@members) {
	    push @servicegroups, { name => $servicegroup, services => \@members };
	    ## FIX MAJOR:  We might want to use 1 instead of $max_rest_objects here.
	    if ( ++$cnt == $max_rest_objects ) {
		if ( not $rest_api->upsert_servicegroups( \@servicegroups, {}, \%outcome, \@results ) ) {
		    log_outcome $logfh, \%outcome, 'servicegroup member addition';
		    log_results $logfh, \@results, 'servicegroup member addition';
		    push @errors, "ERROR:  Failed to add all intended servicegroup members." if not @errors;
		}
		@servicegroups = ();
		$cnt           = 0;
	    }
	}
    }
    if ( @servicegroups and not $rest_api->upsert_servicegroups( \@servicegroups, {}, \%outcome, \@results ) ) {
	log_outcome $logfh, \%outcome, 'servicegroup member addition';
	log_results $logfh, \@results, 'servicegroup member addition';
	push @errors, "ERROR:  Failed to add all intended servicegroup members." if not @errors;
    }
    return \@errors;
}

# FIX LATER:  perhaps bundle the socket writes here
sub update_hostgroups {
    my $delta  = $_[0];
    my $socket = $_[1];
    my $logfh  = $_[2];

    ## rebuild host groups in chunks
    foreach my $hostgroup (keys %{ $delta->{'alter'}{'hostgroup'} }) {
	my $alias = $delta->{'alter'}{'hostgroup'}{$hostgroup}{'alias'};
	my $notes = $delta->{'alter'}{'hostgroup'}{$hostgroup}{'notes'};
	if (defined $alias) {
	    $alias =~ s/\n/ /g;
	    $alias =~ s/<br>/ /ig;
	    $alias =~ s/&/&amp;/g;
	    $alias =~ s/"/&quot;/g;
	    $alias =~ s/'/&apos;/g;
	    $alias =~ s/</&lt;/g;
	    $alias =~ s/>/&gt;/g;
	}
	if (defined $notes) {
	    $notes =~ s/&/&amp;/g;
	    $notes =~ s/"/&quot;/g;
	    $notes =~ s/'/&apos;/g;
	    $notes =~ s/</&lt;/g;
	    $notes =~ s/>/&gt;/g;
	}
	my @xmlstring = ();
	if (exists $delta->{'alter'}{'hostgroup'}{$hostgroup}{'members'}) {
	    # CLEAR must be bundled in the same <Adapter> packet with MODIFY
	    # of membership for a given hostgroup, to ensure serialization.
	    my $xmlstring = "\t<HostGroup HostGroup='$hostgroup' />\n";
	    push @xmlstring, "    <Command Action='CLEAR' ApplicationType='NAGIOS'>\n$xmlstring    </Command>\n";
	    my $total_keys = keys %{ $delta->{'alter'}{'hostgroup'}{$hostgroup}{'members'} };
	    my $key_index  = 0;
	    my @members    = ();
	    foreach my $host (keys %{ $delta->{'alter'}{'hostgroup'}{$hostgroup}{'members'} }) {
		push @members,
		    "\t\t<Host Host='", $host,
		    "' />\n";
		if (++$key_index == $total_keys || ($key_index % $maxhostsendcount) == 0) {
		    my $xmlstring = join( '',
			"\t<HostGroup HostGroup='", $hostgroup,
			((defined($alias) && $alias ne '') ? ("' Alias='" . $alias) : ''),
			((defined($notes) && $notes ne '') ? ("' Description='" . $notes) : ''),
			"' >\n", @members, "\t</HostGroup>\n" );
		    push @xmlstring, "    <Command Action='MODIFY' ApplicationType='NAGIOS'>\n$xmlstring    </Command>\n";
		    $alias = undef;
		    $notes = undef;
		    @members = ();
		}
	    }
	}
	if (defined $alias || defined $notes) {
	    my $xmlstring = join( '',
		"\t<HostGroup HostGroup='", $hostgroup,
		((defined($alias) && $alias ne '') ? ("' Alias='" . $alias) : ''),
		((defined($notes) && $notes ne '') ? ("' Description='" . $notes) : ''),
		"' >\n", "\t</HostGroup>\n" );
	    push @xmlstring, "    <Command Action='MODIFY' ApplicationType='NAGIOS'>\n$xmlstring    </Command>\n";
	}
	write_adapter_xml( $socket, $logfh, join( '', @xmlstring ) ) if @xmlstring;
    }
}

# FIX MAJOR:  Limit the membership additions to $max_rest_member_objects per hostgroup per call.
sub update_hostgroups_via_rest {
    my $delta = $_[0];
    my $logfh = $_[1];

    my %outcome = ();
    my @results = ();
    my @errors  = ();

    my $cnt                 = 0;
    my @hostgroups          = ();
    my @hostgroups_to_clear = ();
    foreach my $hostgroup ( keys %{ $delta->{'alter'}{'hostgroup'} } ) {
	my $alias = $delta->{'alter'}{'hostgroup'}{$hostgroup}{'alias'};
	my $notes = $delta->{'alter'}{'hostgroup'}{$hostgroup}{'notes'};
	if ( defined $alias ) {
	    $alias =~ s/\n/ /g;
	    $alias =~ s/<br>/ /ig;
	}

	my %hg_object     = ();
	my @members       = ();
	my @first_members = ();
	if ( exists $delta->{'alter'}{'hostgroup'}{$hostgroup}{'members'} ) {
	    push @hostgroups_to_clear, $hostgroup;
	    foreach my $host ( keys %{ $delta->{'alter'}{'hostgroup'}{$hostgroup}{'members'} } ) {
		push @members, { hostName => $host };
	    }
	    ## FIX MINOR:  clean up this old code
	    ## $hg_object{hosts} = \@members if @members;
	    if (@members) {
		@first_members = splice @members, 0, $max_rest_member_objects;
		$hg_object{hosts} = \@first_members;
	    }
	}
	$hg_object{alias}       = $alias if defined($alias) && $alias ne '';
	$hg_object{description} = $notes if defined($notes) && $notes ne '';
	if (%hg_object) {
	    $hg_object{name} = $hostgroup;
	    push @hostgroups, \%hg_object;

	    ## FIX MAJOR:  check elsewhere in the code to see if the socket-api stuff did conditional writes,
	    ## and make sure we reflect such conditionality into the rest-api branches
	    ## FIX MAJOR:  We might want to use 1 instead of $max_rest_objects here.
	    if ( ++$cnt == $max_rest_objects || @members ) {
		if (@hostgroups_to_clear) {
		    if ( not $rest_api->clear_hostgroups( \@hostgroups_to_clear, {}, \%outcome, \@results ) ) {
			log_outcome $logfh, \%outcome, 'hostgroup clearing';
			log_results $logfh, \@results, 'hostgroup clearing';
			push @errors, "ERROR:  Failed to clear all intended hostgroups." if not @errors;
		    }
		    @hostgroups_to_clear = ();
		}
		do {
		    if ( not $rest_api->upsert_hostgroups( \@hostgroups, {}, \%outcome, \@results ) ) {
			log_outcome $logfh, \%outcome, 'hostgroup updating';
			log_results $logfh, \@results, 'hostgroup updating';
			push @errors, "ERROR:  Failed to update all intended hostgroups." if not @errors;
		    }
		    @first_members = splice @members, 0, $max_rest_member_objects;
		    @hostgroups = (
			{
			    name  => $hostgroup,
			    hosts => \@first_members
			}
		    );
		} while (@first_members);
		@hostgroups = ();
		$cnt        = 0;
	    }
	}
    }
    if ( @hostgroups_to_clear and not $rest_api->clear_hostgroups( \@hostgroups_to_clear, {}, \%outcome, \@results ) ) {
	log_outcome $logfh, \%outcome, 'hostgroup clearing';
	log_results $logfh, \@results, 'hostgroup clearing';
	push @errors, "ERROR:  Failed to clear all intended hostgroups." if not @errors;
    }
    if ( @hostgroups and not $rest_api->upsert_hostgroups( \@hostgroups, {}, \%outcome, \@results ) ) {
	log_outcome $logfh, \%outcome, 'hostgroup updating';
	log_results $logfh, \@results, 'hostgroup updating';
	push @errors, "ERROR:  Failed to update all intended hostgroups." if not @errors;
    }
    return \@errors;
}

# FIX LATER:  perhaps bundle the socket writes here
sub update_servicegroups {
    my $delta  = $_[0];
    my $socket = $_[1];
    my $logfh  = $_[2];

    # rebuild service groups in chunks
    foreach my $servicegroup (keys %{ $delta->{'alter'}{'servicegroup'} }) {
	my $notes = $delta->{'alter'}{'servicegroup'}{$servicegroup}{'notes'};
	if (defined $notes) {
	    $notes =~ s/&/&amp;/g;
	    $notes =~ s/"/&quot;/g;
	    $notes =~ s/'/&apos;/g;
	    $notes =~ s/</&lt;/g;
	    $notes =~ s/>/&gt;/g;
	}
	my @xmlstring = ();
	if (exists $delta->{'alter'}{'servicegroup'}{$servicegroup}{'members'}) {
	    # CLEAR must be bundled in the same <Adapter> packet with MODIFY
	    # of membership for a given servicegroup, to ensure serialization.
	    my $xmlstring = "\t<ServiceGroup ServiceGroup='$servicegroup' />\n";
	    push @xmlstring, "    <Command Action='CLEAR' ApplicationType='NAGIOS'>\n$xmlstring    </Command>\n";
	    ## Find the total number of host+services
	    my $total_keys = 0;
	    foreach my $host (keys %{ $delta->{'alter'}{'servicegroup'}{$servicegroup}{'members'} }) {
		$total_keys += scalar keys %{ $delta->{'alter'}{'servicegroup'}{$servicegroup}{'members'}{$host} };
	    }
	    my $key_index = 0;
	    my @members   = ();
	    foreach my $host (keys %{ $delta->{'alter'}{'servicegroup'}{$servicegroup}{'members'} }) {
		foreach my $service (keys %{ $delta->{'alter'}{'servicegroup'}{$servicegroup}{'members'}{$host} }) {
		    push @members,
			"\t\t<Service Host='", $host,
			"' ServiceDescription='", $service,
			"' />\n";
		    if (++$key_index == $total_keys || ($key_index % $maxhostsendcount) == 0) {
			my $xmlstring = join( '',
			    "\t<ServiceGroup ServiceGroup='", $servicegroup,
			    ((defined($notes) && $notes ne '') ? ("' Description='" . $notes) : ''),
			    "' >\n", @members, "\t</ServiceGroup>\n" );
			push @xmlstring, "    <Command Action='MODIFY' ApplicationType='NAGIOS'>\n$xmlstring    </Command>\n";
			$notes = undef;
			@members = ();
		    }
		}
	    }
	}
	if (defined $notes) {
	    my $xmlstring = join( '',
		"\t<ServiceGroup ServiceGroup='", $servicegroup,
		"' Description='", $notes,
		"' >\n", "\t</ServiceGroup>\n" );
	    push @xmlstring, "    <Command Action='MODIFY' ApplicationType='NAGIOS'>\n$xmlstring    </Command>\n";
	}
	write_adapter_xml( $socket, $logfh, join( '', @xmlstring ) ) if @xmlstring;
    }
}

# FIX MAJOR:  Compare the action of "clearing" a hostgroup with whatever we do or don't do
# in that regard for servicegroups.  How did that question get resolved?
#
# FIX MAJOR:  Test what happens with empty notes -- should those be used to delete an existing
# description, and therefore be allowed through?
#
# FIX MAJOR:  Test what happens if you completely empty out all members of a servicegroup.
#
# FIX MAJOR:  Convert this code to use GW::RAPID.  Follow the model in update_hostgroups_via_rest()
# as much as is sensible, but following the data structures from update_servicegroups().
sub update_servicegroups_via_rest {
    my $delta = $_[0];
    my $logfh = $_[1];

    my %outcome = ();
    my @results = ();
    my @errors  = ();

    my $cnt           = 0;
    my @servicegroups = ();
    foreach my $servicegroup ( keys %{ $delta->{'alter'}{'servicegroup'} } ) {
	my $notes = $delta->{'alter'}{'servicegroup'}{$servicegroup}{'notes'};

	my %sg_object = ();
	if ( exists $delta->{'alter'}{'servicegroup'}{$servicegroup}{'members'} ) {
	    my @members = ();
	    foreach my $host ( keys %{ $delta->{'alter'}{'servicegroup'}{$servicegroup}{'members'} } ) {
		foreach my $service ( keys %{ $delta->{'alter'}{'servicegroup'}{$servicegroup}{'members'}{$host} } ) {
		    push @members, { host => $host, service => $service };
		}
	    }
	    $sg_object{services} = \@members;
	}
	$sg_object{description} = $notes if defined($notes) && $notes ne '';
	if (%sg_object) {
	    $sg_object{name} = $servicegroup;
	    ## FIX MINOR:  force the servicegroup AppType here, as well?
	    push @servicegroups, \%sg_object;

	    ## FIX MAJOR:  check elsewhere in the code to see if the socket-api stuff did conditional writes,
	    ## and make sure we reflect such conditionality into the rest-api branches
	    ## FIX MAJOR:  We might want to use 1 instead of $max_rest_objects here.
	    if ( ++$cnt == $max_rest_objects ) {
		if ( not $rest_api->upsert_servicegroups( \@servicegroups, {}, \%outcome, \@results ) ) {
		    log_outcome $logfh, \%outcome, 'servicegroup updating';
		    log_results $logfh, \@results, 'servicegroup updating';
		    push @errors, "ERROR:  Failed to update all intended servicegroups." if not @errors;
		}
		@servicegroups = ();
		$cnt           = 0;
	    }
	}
    }
    if ( @servicegroups and not $rest_api->upsert_servicegroups( \@servicegroups, {}, \%outcome, \@results ) ) {
	log_outcome $logfh, \%outcome, 'servicegroup updating';
	log_results $logfh, \@results, 'servicegroup updating';
	push @errors, "ERROR:  Failed to update all intended servicegroups." if not @errors;
    }
    return \@errors;
}

sub write_adapter_xml {
    my $socket     = $_[0];
    my $log_fh     = $_[1];
    my $xml_string = $_[2];

    $foundation_msg_count++;
    my $xml_out = "<Adapter Session=\"$foundation_msg_count\" AdapterType=\"SystemAdmin\">\n$xml_string</Adapter>\n";
    print $log_fh $xml_out if $logging && !$log_as_utf8;
    utf8::encode($xml_out);
    my $status = print $socket $xml_out;
    my $error = "$!";
    print $log_fh $xml_out if $logging && $log_as_utf8;
    print $log_fh "<!-- ERROR:  Printing that Adapter block to the socket failed ($error). -->\n" if $logging && !$status;
}

sub write_command_xml {
    my $socket     = $_[0];
    my $log_fh     = $_[1];
    my $action     = $_[2];
    my $xml_string = $_[3];

    $foundation_msg_count++;
    my $xml_out = "<Adapter Session=\"$foundation_msg_count\" AdapterType=\"SystemAdmin\">\n    <Command Action='$action' ApplicationType='NAGIOS'>\n$xml_string    </Command>\n</Adapter>\n";
    print $log_fh $xml_out if $logging && !$log_as_utf8;
    utf8::encode($xml_out);
    my $status = print $socket $xml_out;
    my $error = "$!";
    print $log_fh $xml_out if $logging && $log_as_utf8;
    print $log_fh "<!-- ERROR:  Printing that Adapter block to the socket failed ($error). -->\n" if $logging && !$status;
}

sub unindent {
    $_[0] =~ s/^[\n\r]*//;
    my ($indent) = ($_[0] =~ /^([ \t]+)/);
    $_[0] =~ s/^$indent//gm;
}

# Subroutine for getting the current time in SQL Date format
sub get_last_state_change {
    my $timestamp = shift;
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($timestamp);
    return sprintf("%04d-%02d-%02d %02d:%02d:%02d", $year+1900, $mon+1, $mday, $hour, $min, $sec);
}

# FIX MAJOR:  Test to see the downstream effect of using Zulu time here, as it
# pertains to timestamps that might show up in Status Viewer and Event Console.
#
# Here are the accepted REST formats of possible interest to us:
# "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
# "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
# For simplicity, so as not to need fiddling with the local timezone,
# we simply choose the latter (Zulu time), and ignore any sub-second values.
sub get_current_rest_time {
    my $timestamp = shift;
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime($timestamp);
    return sprintf("%04d-%02d-%02dT%02d:%02d:%02d.000Z", $year+1900, $mon+1, $mday, $hour, $min, $sec);
}

1;

