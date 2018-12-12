# MonArch - Groundwork Monitor Architect
# MonarchFoundationREST.pm
#
############################################################################
# Release 4.5
# March 2017
############################################################################
#
# Copyright 2014-2017 GroundWork Open Source, Inc. (GroundWork)
# All rights reserved.
#

use strict;

package FoundationREST;

# --------------------------------------------------------------------------------
# Historical options
# --------------------------------------------------------------------------------

my $sync_logfile = "/usr/local/groundwork/foundation/container/logs/monarch_foundation_sync.log";

# --------------------------------------------------------------------------------
# Options for sending data to Foundation via the Foundation REST API.
# --------------------------------------------------------------------------------

# Where to find credentials for accessing the Foundation REST API.
my $lib_ws_client_config_file = '/usr/local/groundwork/config/ws_client.properties';

# There are six predefined log levels within the Log4perl package:  FATAL, ERROR, WARN, INFO,
# DEBUG, and TRACE (in descending priority).  We define two custom levels at the application
# level to form the full useful set:  FATAL, ERROR, WARN, NOTICE, STATS, INFO, DEBUG, and TRACE.
# To see an individual message appear, your configured logging level here has to at least match
# the priority of that logging message in the code.

# Log levels are specified separately for different REST API instances.
my $GW_RAPID_sync_log_level     = 'STATS';
my $GW_RAPID_auditlog_log_level = 'NOTICE';

# Application-level logging configuration, for that portion of the logging
# which is currently handled by the Log4perl package.
my $lib_log4perl_config = <<EOF;

# Send everything from FATAL through the indicated logging level to the logfile.
log4perl.category.Monarch.Foundation.Sync.GW.RAPID     = $GW_RAPID_sync_log_level,     SyncLogfile
log4perl.category.Monarch.Foundation.Auditlog.GW.RAPID = $GW_RAPID_auditlog_log_level, STDERR

log4perl.appender.SyncLogfile          = Log::Log4perl::Appender::File
log4perl.appender.SyncLogfile.filename = $sync_logfile
log4perl.appender.SyncLogfile.utf8     = 0
log4perl.appender.SyncLogfile.layout   = Log::Log4perl::Layout::PatternLayout
log4perl.appender.SyncLogfile.layout.ConversionPattern = [%d{EEE MMM dd HH:mm:ss yyyy}] %m%n

log4perl.appender.STDERR        = Log::Log4perl::Appender::Screen
log4perl.appender.STDERR.utf8   = 0
log4perl.appender.STDERR.layout = Log::Log4perl::Layout::PatternLayout
log4perl.appender.STDERR.layout.ConversionPattern = [%d{EEE MMM dd HH:mm:ss yyyy}] %m%n

EOF

# --------------------------------------------------------------------------------
# Subroutines
# --------------------------------------------------------------------------------

sub log_outcome {
    my $logfh   = $_[1];
    my $outcome = $_[2];
    my $context = $_[3];

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
    my $logfh   = $_[1];
    my $results = $_[2];
    my $context = $_[3];

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

sub initialize_logger {
    my $logfh           = $_[1];
    my $reinitialize    = $_[2];
    my $log4perl_config = $_[3] || $lib_log4perl_config;
    my $logger_category = $_[4];

    require Log::Log4perl;

    # Basic security:  disallow code in the logging config data.
    Log::Log4perl::Config->allow_code(0);

    # Here we add custom logging levels to form our full standard complement.  There are six
    # predefined log levels:  FATAL, ERROR, WARN, INFO, DEBUG, and TRACE (in descending priority).
    # We add NOTICE and STATS levels to the default set of logging levels supplied by Log4perl,
    # to form the full useful set:  FATAL, ERROR, WARN, NOTICE, STATS, INFO, DEBUG, and TRACE
    # (excepting NONE, I suppose, though there is some hint in the code that OFF is also supported).
    # But calls to Log::Log4perl::Logger::create_custom_level() must be done *before* the call to
    # Log::Log4perl::init(), and we must also accommodate the situation where initialize_logger()
    # (or just Log::Log4perl::init() directly from the application) has previously been called
    # during some earlier action in the same program.

    if ( Log::Log4perl->initialized() && $reinitialize ) {
	Log::Log4perl::Logger->reset();
    }

    if ( not Log::Log4perl->initialized() ) {
	Log::Log4perl::Logger::create_custom_level( "NOTICE", "WARN" )   if not Log::Log4perl::Logger->can('notice');
	Log::Log4perl::Logger::create_custom_level( "STATS",  "NOTICE" ) if not Log::Log4perl::Logger->can('stats');

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
	    Log::Log4perl::init( $log4perl_config =~ m{^/} ? $log4perl_config : \$log4perl_config );
	};
	if ($@) {
	    chomp $@;
	    print $logfh "ERROR:  Could not initialize Log::Log4perl logging:\n$@\n" if defined fileno $logfh;
	    return undef;
	}
    }

    my $logger = Log::Log4perl::get_logger($logger_category);

    return $logger;
}

sub initialize_rest_api {
    my $logfh                 = $_[1];
    my $rest_api_requestor    = $_[2];
    my $ws_client_config_file = $_[3];
    my $logger                = $_[4];
    my $options               = $_[5];

    require GW::RAPID;

    # Initialize the REST API object.
    my %rest_api_options = (
	logger        => $logger,
	access        => $ws_client_config_file,
	interruptible => \$main::shutdown_requested
    );
    if ( defined $options ) {
	$rest_api_options{timeout}         = $options->{timeout}         if defined $options->{timeout};
	$rest_api_options{force_crl_check} = $options->{force_crl_check} if defined $options->{force_crl_check};
	## The handling of "interruptible" is clumsy because it supports backward compatibility.
	delete $rest_api_options{interruptible} if exists( $options->{interruptible} ) and not defined( $options->{interruptible} );
    }
    my $rest_api = GW::RAPID->new( undef, undef, undef, undef, $rest_api_requestor, \%rest_api_options );
    if ( not defined $rest_api ) {
	## The GW::RAPID constructor doesn't directly return any information to the caller on the reason for
	## a failure.  But it will already have used the logger handle to write such detail into the logfile.
	print $logfh "ERROR:  Could not create a GW::RAPID object.\n" if defined fileno $logfh;
	return undef;
    }

    return $rest_api;
}

sub terminate_rest_api {
    my $rest_api_ref = $_[1];

    ## Release our handle to the REST API (if we used it), to force the REST API to call its destructor.
    ## This will attempt to log out before Perl's global destruction pass wipes out resources needed for
    ## logout to work properly.
    $$rest_api_ref = undef;
}

sub create_audit_entries {
    my $rest_api      = $_[1];
    my $logger        = $_[2];
    my $audit_entries = $_[3];
    my $options       = $_[4];
    my $need_rest_api = not defined $rest_api;
    my $need_logger   = not defined $logger;

    if ($need_rest_api) {
	if ($need_logger) {
	    $logger = FoundationREST->initialize_logger( \*STDERR, 0, $lib_log4perl_config, 'Monarch.Foundation.Auditlog.GW.RAPID' );
	    return 0 if not $logger;
	}
	$rest_api = FoundationREST->initialize_rest_api( \*STDERR, 'Monarch', $lib_ws_client_config_file, $logger, $options );
	return 0 if not $rest_api;
    }

    my %outcome;
    my @results;
    my $status = 1;

    if ( not $rest_api->create_auditlogs( $audit_entries, {}, \%outcome, \@results ) ) {
	## Failed.
	## FIX MAJOR:  Log something to STDERR about the failure, if we cannot retrieve the caller's logging handle.
	$status = 0;
    }

    if ($need_rest_api) {
	FoundationREST->terminate_rest_api( \$rest_api );
	# There's apparently no means to destroy an individual $logger (if $need_logger).
    }

    return $status;
}

1;

