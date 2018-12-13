#!/usr/bin/perl -w --
#
# MonArch - Groundwork Monitor Architect
# pg_migrate_monarch.pl
#
############################################################################
# Release 4.6
# July 2018
############################################################################
#
# Copyright 2011-2018 GroundWork, Inc. ("GroundWork")
# All rights reserved.
#

# This script is responsible for all systemic changes to the "monarch" database
# from release to release, be they schema or content.  Except for some Nagios
# configuration directive updates from old releases which we allow this script to
# still repair or add, it only handles changes starting from the Monarch 4.0 => 4.1
# transition, corresponding to the GWMEE 6.6 => 6.6.1 release transition.  That is,
# it handles all changes since the initial release of GWMEE under PostgreSQL.

# IMPORTANT NOTES TO DEVELOPERS:
# (*) All actions taken by this script MUST BE IDEMPOTENT!  This script may be
#     run multiple times on a database, and it is important that each action
#     senses the current state of the database and only performs the incremental
#     transformations if they are actually needed.  That is because the script
#     may be run in several different contexts, and may be run multiple times on
#     the same database, either during the same release or on successive upgrades
#     to later releases.
# (*) All error handling in this script must follow consistent conventions for
#     how potential errors are trapped, sensed, and handled.  To begin with,
#     whenever the code performs some database action, it must be aware of the
#     possibility of error.  Also, simply checking returned status is not a
#     sufficient paradigm, because in fact we use the RaiseError capability of
#     the DBI package, so exceptions must be explicitly planned for and caught,
#     if any special action should be taken in response to them.  In general,
#     given that RaiseError is in effect, we simply allow it to function, print
#     error messages, and cause the script to die.  The END block at the end of
#     the script will be executed after that, to attempt to roll back changes
#     made so far and to inform the user that the run did not execute to full
#     completion.
# (*) We attempt to carry out all operations in this script within a database
#     transaction that can be rolled back if the migration fails for any reason.
#     However, there are some types of database alterations, particularly schema
#     changes, that the database engine might not allow inside a transaction.
#     Executing such an alteration will generally end the previous explicitly
#     started transaction, using an implicit commit, before the non-transaction
#     action occurs.  This will obviously interfere with our ability to roll
#     back to the original state of the database should some unrelated error
#     occur later in the script's processing.  To avoid confusing ourselves as
#     to what is and is not contained within a controlled transaction, if at all
#     possible, any non-transactional (implicit-commit) operations should be
#     moved to the front of the script, before all the transactional operations
#     begin.  This will allow the best chance of our maintaining the ability to
#     have rollbacks make sense.  This issue must be re-examined for every new
#     release, according to the changes planned for that release.

# TO DO:
# (*) Validate all exception handling in this script, to make sure it
#     comports with our setting of RaiseError.
# (*) Figure out what kinds of table locking and other transaction and
#     serialization control we ought to be implementing here, and do
#     something about it.

##############################################################################
# SUMMARY OF VERSION CHANGES
##############################################################################

# GWMEE 6.6   => Monarch 4.0 (baseline PostgreSQL schema and content)
# GWMEE 6.6.1 => Monarch 4.1 (simple schema cleanup)
# GWMEE 6.7.0 => Monarch 4.1 (no database changes for this release)
# GWMEE 7.0.0 => Monarch 4.2 (content-only changes and extensions)
# GWMEE 7.0.1 => Monarch 4.3 (content-only changes and extensions)
# GWMEE 7.0.2 => Monarch 4.3 (content-only changes and extensions)
# GWMEE 7.1.0 => Monarch 4.4 (content-only changes and extensions)
# GWMEE 7.1.1 => Monarch 4.5 (simple schema and content extensions)
# GWMEE 7.2.0 => Monarch 4.6 (schema extensions; content removals and extensions)
# GWMEE 7.2.1 => Monarch 4.6 (there are some minor code changes in this release,
#                            but no schema or content changes)
# GWMEE 7.2.2 => Monarch 4.7 (notes on anticipated schema and content changes,
#                            documented here for safekeeping but not yet implemented)

# ----------------------------------------------------------------
# Monarch 4.0 conversions
# ----------------------------------------------------------------
#
# * First PostgreSQL-based release.  All schema and data conversion was handled
#   outside of this script, including duplicate-row cleanup which was necessary
#   before we applied additional unique indexes on some of the PostgreSQL tables.

# ----------------------------------------------------------------
# Monarch 4.1 conversions
# ----------------------------------------------------------------
#
# This upgrade implements only a few minor schema changes.
#
# * Revert all boolean columns back to integral types, as they had been
#   in the Monarch MySQL schema, to deal with odd handling and content of
#   some of these fields within Monarch.

# ----------------------------------------------------------------
# Monarch 4.2 conversions
# ----------------------------------------------------------------
#
# This upgrade implements only a few data-content changes.
#
# * GWMON-11040:  In the fresh-install setup, we are changing the value of the
#   Nagios check_service_freshness option in the Nagios main configuration (for a
#   standalone/parent server, but not also for Monarch Configuration Groups, since we
#   don't supply any already-set Nagios configuration options for the Monarch Groups
#   we define by default in a fresh install).  THe value is being changed from a
#   null value in the database (which is interpreted as this option being unset) to
#   a "1" (which is interpreted as this option being checked, in the UI).  However,
#   we will not force an equivalent change in already-existing customer setups during
#   an upgrade, on the notion that we don't want to mess with an apparently working
#   production configuration.  (We have, however, documented the change in the public
#   "7.0.0 Release Notes for EE", so each site can decide for themselves whether to
#   make this update.)
#
# * GWMON-11057:  In the fresh-install setup, we are changing the command line for the
#   local_process_gw_listener service to refer to the new process arguments for the java
#   process of interest.  This same change must be made during an upgrade to the command
#   line for generic services and any host services that still use the old argument form.
#   Also as part of this fixup, we are modifying the description of this generic service
#   to match its actual function.
#
# * Add a new "service = '^.+\..+'" (otherwise known as "Collector Metric") performance
#   configuration entry to support graphing for CloudHub metrics.

# ----------------------------------------------------------------
# Monarch 4.3 conversions
# ----------------------------------------------------------------
#
# This upgrade implements only a few data-content changes.
#
# * Enable externals in Monarch, if they were not previously enabled.  This change
#   is in accord with adding the rest of the support for automated agent registration,
#   so the system has all of the infrastructure for this capability installed.
#
# * If auto-registration is enabled, then add a default hostgroup for auto-registration,
#   if the one named for this purpose in the register_agent.properties config file is not
#   already present, to provide out-of-the-box support for GDMA auto-registration.  The
#   site is obviously free to rename this hostgroup as desired, both in Monarch and in the
#   config/register_agent.properties file, with the caveat that future upgrades will (if
#   auto-registration is enabled) add back this particular hostgroup (which can then be
#   manually deleted after the upgrade to the later release).  The necessity for such a
#   repeated deletion is ameliorated by using the value set in the config file.
#
# * If auto-registration is enabled, then add a default Monarch configuration group for
#   auto-registration, if the one named for this purpose in the register_agent.properties
#   config file is not already present, to provide out-of-the-box support for GDMA
#   auto-registration.  The site is obviously free to rename this Monarch configuration
#   group as desired, both in Monarch and in the config/register_agent.properties file,
#   with the caveat that future upgrades will (if auto-registration is enabled) add back
#   this particular Monarch configuration group (which can then be manually deleted after
#   the upgrade to the later release).  The necessity for such a repeated deletion is
#   ameliorated by using the value set in the config file.
#
# * If auto-registration is enabled, then add new pre-loaded host profiles, if not already
#   present, to provide out-of-the-box support for GDMA auto-registration:
#
#       gdma-aix-host.xml
#       gdma-linux-host.xml
#       gdma-solaris-host.xml
#       gdma-windows-host.xml
#
#   Future upgrades are expected to only look for the presence of these host
#   profiles, so any changes to them implemented by the customer will be
#   preserved.  If GroundWork wishes to provide updated definitions, that
#   will be done under new host profile names.
#
# * Add new performance-configuration entries, if not already present, to
#   support GDMA-monitored services:
#
#       aix_disk
#       aix_load
#       aix_process_count
#       aix_swap
#
#       linux_disk
#       linux_load
#       linux_mem
#       linux_process_count
#       linux_swap
#
#       solaris_disk
#       solaris_load
#       solaris_process_count
#       solaris_swap
#
#       gdma_21_wmi_cpu
#       gdma_21_wmi_disktransfers
#       gdma_21_wmi_disk_
#       gdma_21_wmi_mem
#       gdma_21_wmi_memory_pages
#
#   These will presumably already be loaded when we load in the new GDMA
#   host profiles, but it's better to be safe than sorry, so we do so
#   explicitly here.
#
#   For the gdma_21_* entries, it's unfortunate that they slipped out into the
#   GWMEE 7.0.0 release with that prefix, since GDMA 2.1 is long gone.  That was
#   not intended, but it happened.  So now we will live with those names, until
#   in some future release we supply some fully cleaned-up alternate to the
#   gdma-windows-host.xml host profile and all of its related objects, and then
#   later change the GDMA installer to refer to this new host profile as the
#   default host profile on the Windows platform.
#
# * Recode certain Nagios Main Configuration option names:
#
#       service_freshness_check_interval (used to be freshness_check_interval)
#
# * Add new Nagios main-configuration directives, to fill out the set with almost
#   all of the options that we have not previously explicitly supported, other
#   than indirectly via the Miscellaneous Directives capability.  The process of
#   adding the new directives must take into account the possibility that the site
#   might have existing parent-config or group-config miscellaneous directives that
#   already mention these options, and convert them to their now-standard forms
#   instead of establishing the default values for these options that we would
#   otherwise supply here.
#
#   Configuration Options
#       use_regexp_matching=<0/1>		[default:  0 (don't add; is unsupported by GroundWork at this time)]
#       use_true_regexp_matching=<0/1>		[default:  0 (don't add; is unsupported by GroundWork at this time)]
#       allow_empty_hostgroup_assignment=[01]	[default:  0 (don't add; is unsupported by GroundWork at this time)]
#
#   Time Format Options
#       use_timezone=<tz>		[default:  unspecified or empty string]
#       Note:  For use_timezone, we trim the value when Monarch saves the value from on-screen data entry,
#       and for an empty or all-whitespace value, we must not generate this directive into Nagios config files.
#
#   Debug Options
#       debug_level=<#>			[default:  0 (or provide a UI for the bitmask options)]
#       debug_verbosity=<#>		[default:  1]
#       debug_file=<file_name>		[default:  /usr/local/nagios/var/nagios.debug]
#       max_debug_file_size=<#>		[default:  1000000]
#
#   Check Scheduling Options
#       enable_predictive_host_dependency_checks=<0/1>		[default:  1]
#       enable_predictive_service_dependency_checks=<0/1>	[default:  1]
#       check_for_orphaned_hosts=<0/1>				[default:  1]
#
#   Freshness Check Options
#       additional_freshness_latency=<#>			[default:  15]
#
#   Internal Operations Options
#       temp_path=<dir_name>					[default:  /tmp]
#       Note:  For temp_path, we trim the value when Monarch saves the value from on-screen data entry,
#       and for an empty or all-whitespace value, we must not generate this directive into Nagios config files.
#
#   State Retention Options
#       retained_host_attribute_mask=<number>			[default:  0 (or provide a UI for the bitmask options)]
#       retained_process_host_attribute_mask=<number>		[default:  0 (or provide a UI for the bitmask options)]
#       retained_contact_host_attribute_mask=<number>		[default:  0 (or provide a UI for the bitmask options)]
#       retained_service_attribute_mask=<number>		[default:  0 (or provide a UI for the bitmask options)]
#       retained_process_service_attribute_mask=<number>	[default:  0 (or provide a UI for the bitmask options)]
#       retained_contact_service_attribute_mask=<number>	[default:  0 (or provide a UI for the bitmask options)]
#
# * GWMON-11182:  Change the performanceconfig.rrdcreatestring entry for the '^.+\..+'
#   service-name pattern, which is used to support CloudHub metrics, to use an xff
#   value ("xfiles factor") of 0.99 for these specific RRAs instead of our usual
#   0.5.  This is to accommodate the possible sporadic or irregular monitoring of
#   CloudHub metrics.  It will mean that a consolidation of 99% UNKNOWN values and
#   only 1% actual known values will be acceptable for creating a supposedly "known"
#   consolidated value, thus highly favoring the available sample data as being truly
#   representative of the metric state during periods when there is really no true
#   measure of reality.  The point here is to allow irregular monitoring of certain
#   statistics, with the edge effects (transitions between monitored periods and
#   unmonitored periods) being dominated in graphs by apparently known data, instead
#   of being dominated by actually unknown data.
#
#   Note that this change will only affect newly created RRD files; it will not reach
#   back and adjust this factor in already-created RRD files.  For that, we would need
#   a separate conversion script to identify the specific RRD files for which this one
#   performanceconfig entry applies, to dump/restore or export/import the data from
#   the existing file to a new file with adjusted parameters, and finally to perform
#   an atomic rename of the new file to be named as the old file.
#
# Some of these changes may be subject to later local revision by the customer (such as
# renaming the auto-registration default hostgroup to something they like better, along
# with perhaps changing the default_hostgroup in the register_agent.properties file).
# Because of that, certain of these changes will be made only conditional on the presence
# of the register_agent.properties file, and having auto-registration configured in that
# file to be enabled.  Also, the actual object names in some cases will be drawn from
# that configuration file.  That is to say, for instance, that if the customer runs this
# script on a Monarch 4.3 database on a system with auto-registration disabled, a missing
# auto-registration default hostgroup will not be added, under the theory that if it was
# once present either from a fresh install or some previous upgrade, it must have been
# explicitly deleted since then because it was not wanted.
#
# The particular deltas we want to hold back are those that involve very public objects,
# such as the auto-registration default hostgroup and perhaps the auto-registration
# Monarch Configuration Group.  We will skip such alterations if auto-registration is
# disabled, so as not to disturb a working setup.  After the upgrade, it will be up to
# the user to establish those changes, if desired, perhaps simply by re-enabling the
# capability and re-running this script.  In contrast, adding what are essentially internal
# objects, such as performance configuration entries or host profiles, will continue to be
# done on subsequent migration attempts because these are essentially internal objects.

# ----------------------------------------------------------------
# Monarch 4.4 conversions
# ----------------------------------------------------------------
#
# This upgrade implements only a few data-content changes.
#
# * GWMON-11843:  In the fresh-install setup, we are adding a new max_unlocked_backups
#   option to control the deletion of excess backups during a Commit.  This same change
#   must be made during an upgrade.
#
# * GWMON-11852:  In the fresh-install setup, we are changing the Nagios temp_path option
#   to be /usr/local/nagios/tmp instead of /tmp as it has been historically.
#   This allows the /tmp directory to be mounted noexec without interfering with the
#   manner in which Nagios loads an event broker (Bronx, in our case).  This same change
#   must be made during an upgrade.
#
# * GWMON-11354:  Add support for the Nagios CGI result_limit directive, both in the
#   Nagios CGI configuration and in similar configuration for any Monarch groups that
#   also already have the CGI configuration set up.
#
# * GWMON-11950:  Correct the RRD Update Command in the performance-configuration entry
#   for the aix_disk service.
#
# * GWMON-11951:  Correct the Custom RRD Graph Command in the performance-configuration
#   entry for several services.
#
# * GWMON-11952:  Reformat all of the RRD commands in the performance-configuration
#   entries, to better display their structure.
#
# * GWMON-10549:  Modify performance configuration definitions to take advantage of
#   $GRAPH_START_TIME$ and $GRAPH_END_TIME$ macros.  Also add a standardized graph
#   title if there is not one already defined, to make the picture content completely
#   self-sufficient in terms of displaying what it represents.
#
# * GWMON-12000:  Clean up certain fields in performance configuration definitions,
#   to remove leading and/or trailing spaces.  This will bring such fields into
#   accord with how the Configuration > Performance tool will now edit said fields
#   before saving new values, to prevent misinterpretation of the values.
#
# * GWMON-12068:  Add a new performance configuration entry to support some common
#   Open Daylight services monitored by GroundWork Net Hub.

# ----------------------------------------------------------------
# Monarch 4.5 conversions
# ----------------------------------------------------------------
#
# This upgrade implements both a few minor schema changes and a few data-content changes.
#
# * GWMON-12679:  In the fresh-install setup, the stage_host_services.host field
#   has been modified to be a maximum of 255 characters instead of 50 characters,
#   to match the maximum length defined for similar fields in other tables.  This
#   same change must be made during an upgrade.
#
# * GWMON-12585:  In the fresh-install setup, the time_period_property.value field
#   has had its length extended from 255 to 400 characters.  This same change must
#   be made during an upgrade.

# ----------------------------------------------------------------
# Monarch 4.6 conversions
# ----------------------------------------------------------------
#
# This upgrade implements both a minor schema change and a few data-content changes.
#
# * GWMON-13059:  Extend the width of the users.user_acct field to accommodate
#   significantly longer user names.
#
# * GWMON-13157:  Extend service-related tables to support externals arguments.
#   to be substituted into service-externals patterns when externals are built.
#
# * GWMON-10303:  Ensure that Bronx is set up in Monarch.  The only way this
#   might not already be the case is if the site started with a really ancient
#   release before Bronx was available or with a Community Edition where it was
#   not configured by default, and upgraded to current release without ever
#   having corrected the situation along the way.  That is, without ever having
#   had the core/migration/migrate-monarch.sql script run on the system or the
#   corrections made by hand.  But still, we never did resolve this JIRA until
#   now, so we will cover our bases here and make an idempotent insertion of the
#   affected records.
#
# * GWMON-10653:  Add host-notify-by-noma and service-notify-by-noma commands
#   to an existing Monarch deployment, if such commands do not already exist.
#   Also correct the alert_via_noma.pl -u, -t, and -A options if such commands
#   do already exist and these options are not specified correctly.
#
# * GWMON-13140:  Remove obsolete directives from our Monarch data, for both
#   parent and child servers.
#
# * GWMON-13140:  Add support for several new directives to our Monarch data,
#   for just the parent server.  It will be up to the site to make such
#   adjustments for any child servers where these options might be relevant.
#
# * UNKNOWN JIRA:  I believe a variety of extensions were previously made to
#   the content of the fresh-install performanceconfig table, in either the
#   7.1.0 or 7.1.1 release, or both.  Those same content changes must now be
#   made during an upgrade.  (These changes may be largely covered by the
#   CLOUDHUB-179, GWMON-12373, and GWMON-12379 JIRAs, as handled for the
#   upgrade to the Monarch 4.6 version, noted below.)
#
# * GWMON-12875:  Add a new service profile, along with companion commands,
#   services, and perf-config entries, for Windows WMIC support.
#
# * GWMON-13054:  Add a couple of new perfconfig entries to support both
#   Windows GDMA and Linux uptime plugins.
#
# * GWMON-12978:  Add new service profiles for Grafana Server and InfluxDB.
#
# * CLOUDHUB-179, GWMON-12373, GWMON-12379:  Review previous changes to Monarch
#   seed data to ensure that they are reflected in similar changes during a
#   migration, whether that be by adding new entries or modifying existing entries.
#
# Certain other changes are not being made either in the seed data or here in the
# migration script.
#
# * GWMON-12897:  Add support for read-only access to the Nagios CGIs,
#   and support for controlling access to the Nagios CGIS via contactgroups
#   (in addition to the existing controls at the individual-user level).
#   This support will be added dynamically to the Monarch configuration if
#   the administrator visits the Nagios CGI configuration screens and adds
#   relevant entries.  Otherwise, the system will continue to operate just
#   fine without them, so there is no incentive to make adjustments either
#   to the seed data or here in this migration script.

# ----------------------------------------------------------------
# Monarch 4.7 conversions
# ----------------------------------------------------------------
#
# These changes are anticipated for Monarch 4.7, but not yet implemented.
#
# * GWMON-10199:  Change two column types in the monarch_group_props table.
#   The column type for "type" should change from "character varying(20)" to
#   "character varying(50)", and the column type for "value" should change
#   from "character varying(1020)" to "text".
#
# * GWMON-13438:  Change the type of the hosts.address field from
#   "character varying(50)" to "character varying(255)", to match the
#   maximum width of the hosts.name field.
#
# * Bump up the nagios_version from "3.x" to "4.x", in conjunction with
#   changes in Monarch itself to better support either new options in
#   Nagios 4, or any changes required because of upstream changes in Nagios
#   4.4.0, 4.4.1, or later.

# ----------------------------------------------------------------
# Monarch 4.8 conversions
# ----------------------------------------------------------------
#
# This section describes changes that might come in a future release.
#
# FIX MINOR:  lock_author_names and perhaps other directives are not in the "Sync
# With Main" group data, and so would not be part of a child-server configuration;
# look for all instances of this, and repair by adding directives as appropriate.
#
# FIX MINOR:  deal with these possibilities
# * Also look for these possibilities that might need attention here (see other conversions listed above):
#   * New directives/macros that were added to support the latest Nagios with GWMEE 7.0.0
#     (Nagios main configuration directives overlooked above, perhaps?)
#     (Nagios main configuration directives, for Monarch Groups?)
#     (service stalking options?)
#   * New directives/macros that should perhaps be added to support Nagios 4
#     (we have not yet investigated to see what might be covered by this idea).
#
# * Add new performance-configuration entries, if not already present, to support
#   GDMA-monitored services, once we have the corresponding platform-specific
#   plugins working:
#       aix_mem
#       solaris_mem
#
# * Potentially, change the check_interval value in certain host templates (GWMON-13341).

##############################################################################
# Perl setup
##############################################################################

use strict;

use DBI;

use MonarchStorProc;
use MonarchProfileImport;

use TypedConfig;

##############################################################################
# Script parameters
##############################################################################

my $auto_registration_config_file = '/usr/local/groundwork/config/register_agent.properties';

my $debug_config = 0;    # if set, spill out certain data about config-file processing to STDOUT

my $reformat_rrd_commands = 0;    # whether to reformat RRD create, update, and graph commands
my $extend_rrd_commands   = 0;    # whether to add graph start/end comments to graph commands

my $max_line_length      = 80;    # where to split long lines in reformatted RRD graph commands
my $debug_line_splitting = 0;     # whether to spill detail when reformatting RRD graph commands

my $print_creat = 0;              # whether to print final reformatted RRD create commands
my $print_updat = 0;              # whether to print final reformatted RRD update commands
my $print_graph = 0;              # whether to print final reformatted RRD graph commands

##############################################################################
# Global variables
##############################################################################

my $all_is_done     = 0;
my $monarch_version = '4.6';
my $nagios_version  = '3.x';
my $nagios_etc      = '';

# This setting will be made conditional on the register_agent.properties
# file being present and containing the "enable_processing = yes" value.
my $auto_registration_is_enabled = undef;

my $default_auto_registration_hostgroup     = undef;
my $default_auto_registration_monarch_group = undef;

my ( $dbhost, $dbname, $dbuser, $dbpass );
my $dbh = undef;
my $sth = undef;
my $sqlstmt;
my $outcome;

##############################################################################
# Global match patterns
##############################################################################

# FIX MAJOR:  Make sure that the RRD command reformatting does not intefere with idempotent inserts into
# the performanceconfig table, either during an upgrade or during future runs of the migration script.

# The following patterns are extremely complex, so it's easier to comprehend them if we lay them on their
# sides, making the component pieces, nesting, and alternation much more visible.

# This pattern uses "bash" semantics for the interpretation of backslashes within a double-quoted string.
# "tcsh" and perhaps other shells do not interpret backslashes within double-quoted strings, so this would
# be an incorrect match if such an RRD graph command were normally being interpreted in such a context.
# In neither bash nor tcsh are backslashes interpreted within single-quoted strings, hence the asymmetry
# within this pattern.
my $balanced_word = qr{
    (?:
	[^'"\s\\]+		# unquoted series of non-whitespace characters
    |
	(?:
	    (?:
		"		# opening double-quote character
		(?:
		    [^"\\]+	# series of characters that cannot terminate the double-quoted string
		|
		    \\.		# a backslash sequence embedded within the double-quoted string
		)*
		"		# closing double-quote character
	    )
	|
	    '[^']*'		# a complete single-quoted string
	|
	    \\.			# a backslash-escaped single character, outside of quoted-string context
	)+
    )+
}x;

my $non_option_word = qr{
    (?!-)			# disallow a leading "-" space in the non-option word
    $balanced_word		# the rest of the non-option word can be any ordinary non-whitespace or quoted string
}x;

my $balanced_phrase = qr{
    \s*
    (?:
	(?:
	    (?:
		-[a-zA-Z0-9]			# a -X (single-character) RRD option name
	    |
		--[a-zA-Z0-9][-a-zA-Z0-9]+
	    )					# a --xname-option (multi-character) RRD option name
	    (?:
		(?:
		    =-*				# optional connection between the option and its value, allowing a -X=-1 negative value
		|
		    \s+				# possible alternate whitespace between the option and its value
		)
		$non_option_word		# the option value, ruling out a coincidental following option name
	    )?					# there might or might not be a value for this option
	)
    |
	$non_option_word			# a non-whitespace or quoted string which is not an option name
    )
}x;

## The list of possible graph elements is drawn from the RRDtool documentation, regardless of
## whether we have actually used any particular set of these in our own RRD graph commands.
my $graph_element = qr{(?:AREA|COMMENT|DEF|CDEF|GPRINT|HRULE|LINE[0-9]*|PRINT|SHIFT|STACK|TEXTALIGN|TICK|VDEF|VRULE):};

##############################################################################
# Perl context initialization
##############################################################################

# Autoflush the standard output on every single write, to avoid problems
# with block i/o and badly interleaved output lines on STDOUT and STDERR.
# This we do by having STDOUT use the same buffering discipline as STDERR,
# namely to flush every line as soon as it is produced.  This is certainly
# a less-efficient use of system resources, but we don't expect this program
# to write much to the STDOUT stream anyway, and this program will not be
# run very often.
STDOUT->autoflush(1);

##############################################################################
# Supporting subroutines
##############################################################################

# If a row insertion here fails because that row already exists, that's okay.
# But if it fails for some other reason, that's not okay.

sub idempotent_insert {
    my $table     = shift;
    my $row_label = shift;
    my $values    = shift;

    eval {
	$dbh->do( "SAVEPOINT before_insert" );
	$dbh->do( "INSERT INTO $table VALUES $values" );
	$dbh->do( "RELEASE SAVEPOINT before_insert" );
    };
    if ($@) {
	## To check:
	## if (not a duplicate row)
	## we look for:  "duplicate key value violates unique constraint" or equivalent
	## (I'm not sure how many different types of similar messages might exist).
	if ( $@ !~ /duplicate key value/i ) {
	    die "ERROR:  insert of $row_label into $table failed:\n    $@\n";
	}
	else {
	    ## This print is here just for initial debugging.  In production use, we don't want
	    ## to emit this message, because the stated condition is not considered a failure.
	    #  print "WARNING:  insert of $row_label into $table failed:\n    $@\n";

	    # Under PostgreSQL (at least), this condition (duplicate key value found) normally
	    # aborts the entire current transaction, meaning that all further commands until the
	    # end of the transaction block will be ignored.  That is obviously not the desired
	    # outcome.  So we either need some way to run a nested transaction, or some way to
	    # disable the usual aborting of the overall transaction.  An explicit savepoint around
	    # the insertion above is sufficient for our purposes.  Otherwise, we would need to
	    # implement some kind of subtransaction (which in effect, the savepoint is).  Or
	    # we would need to use some kind of trigger to check the insertion before actually
	    # executing it; but the difficulty there is that the trigger code would need to find
	    # out all the constraints on a given insertion, since we would not want to hardcode
	    # such associations.  Fortunately, savepoint management here is trivial.
	    $dbh->do( "ROLLBACK TO SAVEPOINT before_insert" );
	}
    }
}

sub idempotently_add_command {
    my $command_name    = shift;
    my $command_type    = shift;
    my $command_line    = shift;
    my $command_comment = shift;

    # Package up the command line into the XML blob it needs to be enclosed in.
    # This allows the caller to simplify its own specification of the command.
    my $command_data =
"<?xml version=\"1.0\" encoding=\"iso-8859-1\" ?>
<data>
  <prop name=\"command_line\"><![CDATA[$command_line]]>
  </prop>
</data>";

    my $quoted_command_data = $dbh->quote($command_data);
    my $quoted_command_comment = defined($command_comment) ? $dbh->quote($command_comment) : 'null';
    idempotent_insert( 'commands', $command_name, "(DEFAULT, '$command_name', '$command_type', $quoted_command_data, $quoted_command_comment)" );
}

sub read_register_agents_config_file {
    my $config_file  = shift;
    my $config_debug = shift;

    # All the config-file processing is wrapped in an eval{}; because TypedConfig
    # throws exceptions when it cannot open the config file or finds bad config data.
    eval {
	my $config = TypedConfig->new( $config_file, $config_debug );

	# Whether to process anything.  This is turned off if you want to completely
	# disable automated agent registration.  If that's the case, we suppress
	# certain Monarch database changes, so as not to pollute your database with
	# objects that have no relevance to your situation.
	$auto_registration_is_enabled = $config->get_boolean('enable_processing');

	$default_auto_registration_hostgroup     = $config->get_scalar('default_hostgroup');
	$default_auto_registration_monarch_group = $config->get_scalar('default_monarch_group');

	# If auto-registration is enabled, we will use certain values later on.  Let's validate
	# them here in a central location so we don't have trouble with creating strange objects
	# in Monarch.  This is a soft validation, in that if one of these names fails our tests,
	# we don't make that problem cause the entire migration to fail.
	if ($auto_registration_is_enabled) {
	    if ($default_auto_registration_hostgroup !~ /^[-\w]+$/) {
		$default_auto_registration_hostgroup = undef;
		print "\nNOTICE:  Found default_hostgroup name in register_agent.properties\n";
		print "         with odd format; later migration code will skip trying to create\n";
		print "         this hostgroup.\n";
	    }
	    if ($default_auto_registration_monarch_group !~ /^[-\w]+$/) {
		$default_auto_registration_monarch_group = undef;
		print "\nNOTICE:  Found default_monarch_group name in register_agent.properties\n";
		print "         with odd format; later migration code will skip trying to create\n";
		print "         this Monarch configuration group.\n";
	    }
	}
    };
    if ($@) {
	chomp $@;
	$@ =~ s/^ERROR:\s+//i;
	print "ERROR:  Cannot read config file $config_file\n  ($@).\n";
	return 0;
    }

    return 1;
}

sub reformat_rrd_creat {
    my $create = shift;

    $create =~ s/\s+/ /g;
    $create =~ s/^\s//;
    $create =~ s/\s$//;

    $create =~ s/\s+DS:/\nDS:/g;

    my @parts = split /(\s*\$LISTSTART\$.*?\$LISTEND\$\s*)/s, $create;
    foreach (@parts) {
	if (/\s*\$LISTSTART\$.*?\$LISTEND\$\s*/s) {
	    s/\s*\$LISTSTART\$\s*/\n\$LISTSTART\$\n/;
	    s/\s+DS:/\n    DS:/g;
	    s/\s*\$LISTEND\$\s*/\n\$LISTEND\$\n/;
	}
    }
    $create = join( '', @parts );

    $create =~ s/\s+RRA:/\nRRA:/g;

    if ($print_creat) {
	print "================================================================\n";
	print "$create\n";
    }

    return $create;
}

sub reformat_rrd_updat {
    my $update = shift;

    $update =~ s/\s+/ /g;
    $update =~ s/^\s//;
    $update =~ s/\s$//;

    if ($print_updat) {
	print "================================================================\n";
	print "$update\n";
    }

    return $update;
}

sub reformat_rrd_graph {
    my $graph = shift;

    $graph =~ s/\r\n/\n/g;
    $graph =~ s/^\s+//;
    $graph =~ s/\s+$//;
    if ( $graph =~ /^'/ && $graph =~ /'$/ ) {
	$graph =~ s/^'//;
	$graph =~ s/'$//;
	$graph =~ s/^\s+//;
	$graph =~ s/\s+$//;
    }
    $graph =~ s/^\s+//mg;
    $graph =~ s{^/$}{};

    # We can't match space both before and after, and still expect overlapping matches.
    # So we need to do these matches and replacements in two separate steps.
    $graph .= ' ';
    $graph =~ s/\s+($graph_element$balanced_word)(?=\s)/\n$1/og;
    $graph =~ s/(?<=\s)($graph_element$balanced_word)\s+/$1\n/og;
    $graph =~ s/\s+$//;

    if ($print_graph) {
	print "================================================================\n";
    }

    my @parts = split /(\s*\$LISTSTART\$.*?\$LISTEND\$\s*)/s, $graph;
    foreach (@parts) {
	if (/\s*\$LISTSTART\$.*?\$LISTEND\$\s*/s) {
	    s/\s*\$LISTSTART\$\s*/\n\$LISTSTART\$\n/;
	    s/\s+($graph_element)/\n    $1/g;
	    s/\s*\$LISTEND\$\s*/\n\$LISTEND\$\n/;
	}
	## Limiting the line length is experimental and not completely working yet.
	else {
	    ## We split this part on whitespace so no line is larger than $max_line_length,
	    ## always keeping $balanced_phrase portions together on the same output line.
	    print "SECTION: '$_'\n" if $debug_line_splitting;
	    my @input_lines  = split /\n/;
	    my @output_lines = ();
	    foreach my $input_line (@input_lines) {
		chomp $input_line;
		## This section not only limits the line length, but also
		## cleans up spacing even in already-short lines.
		my @pieces = split /($balanced_phrase)/, $input_line;
		my @lines  = ();
		my $line   = '';
		foreach my $piece (@pieces) {
		    if ( defined($piece) && $piece ne '' ) {
			print "piece: '$piece'\n" if $debug_line_splitting;
			if ( ( length($line) + length($piece) ) >= $max_line_length ) {
			    $line =~ s/\s+$//;
			    push @lines, $line if $line ne '';
			    ( $line = $piece ) =~ s/^\s+//;
			}
			else {
			    $piece =~ s/^\s+/ /;
			    $line .= $piece;
			}
		    }
		}
		$line =~ s/\s+$//;
		push @lines, $line if $line ne '';
		$input_line = join( "\n", @lines );
		push @output_lines, $input_line if $input_line ne '';
	    }
	    $_ = join( "\n", @output_lines );
	    print "REVISED: '$_'\n" if $debug_line_splitting;
	}
    }
    $graph = join( '', @parts );

    if ($print_graph) {
	print "----------------------------------------------------------------\n" if $debug_line_splitting;
	print "$graph\n";
    }

    return $graph;
}

sub idempotently_add_profiles {
    my $profile_type  = shift;
    my $profile_files = shift;

    # Because of the complexity of host and service profiles, and the fact that they
    # recursively refer to many other objects, we're not going to break them down and
    # insert all of the separate subsidiary objects individually here.  Instead, we're
    # going to call our standard profile-file import routine, and allow it to handle
    # all the detail.

    # Calling ProfileImporter->import_profile() in the usual way to make these changes
    # (call StorProc->dbconnect(), then ProfileImporter->import_profile(), then
    # StorProc->dbdisconnect()) won't work, because we are holding open a transaction on
    # some of the tables we might be querying and modifying.  That blocks any attempt by
    # a second actor (StorProc's own separate database connection) to even query those
    # tables, let alone modify them, which means that this script self-deadlocks if we
    # try to call that routine.  So either we need a way to use StorProc's internal
    # database handle (which would violate whatever security restrictions we want to
    # have in place), or we need a way to force StorProc to use our own database handle
    # instead of the one it normally uses, or we need to break down the objects we want
    # to import, insert their constituents here manually, and make sure they are linked
    # as they would have been had they been handled by the existing import code.
    #
    # Since the StorProc code is considered to be open but the database credentials
    # are not, we have extended StorProc->dbconnect() as of the GWMEE 7.0.0 release to
    # accept a database handle from the caller, and to use that instead of opening a
    # new internal connection.  The caller is then responsible for setting the required
    # connection attributes (here, {AutoCommit => 0, RaiseError => 1, PrintError => 0})
    # to make the StorProc routines function as they need to in this context.  (The
    # normal operational mode for StorProc has AutoCommit turned on, since StorProc
    # itself never begins or commits transactions, while in the present context we
    # intentionally want AutoCommit to be turned off; so we don't intervene here and turn
    # AutoCommit on just because we're calling StorProc routines which usually assume it
    # is on.)  Also, unlike ordinary use of StorProc, the convention here is that the
    # caller must not call StorProc->dbdisconnect(), since that would close its copy of
    # the caller's database handle, and thus both roll back any transactions the caller
    # had not yet committed, and make it impossible for the caller to continue to use
    # that handle for further operations.

    my $auth = StorProc->dbconnect($dbh);

    # Get these files loaded, without overwriting existing objects.
    my $folder                  = '/usr/local/groundwork/monarch/profiles/All';
    my @profile_files_to_import = @$profile_files;
    my $overwrite               = '';
    my @messages                = ();

    my $line_separator = "----------------------------------------------------------------";
    push @messages, $line_separator;
    foreach my $file (@profile_files_to_import) {
	unless ($file) { next }
	push @messages, "Importing $file";
	my @msgs = ProfileImporter->import_profile( $folder, $file, $overwrite );
	unshift @messages, "Error(s) occurred while importing $profile_type profile(s).  See below for details."
	  if ( $msgs[0] =~ /error/i && $messages[0] !~ /error/i );
	map  s{<tt>}{}g, @msgs;
	map s{</tt>}{}g, @msgs;
	push @messages, @msgs;
	push @messages, $line_separator;
    }

    my $got_error = 0;
    if ( $messages[0] =~ /error/i ) {
	push @messages, "Please make the necessary corrections and try again.";
	$got_error = 1;
    }

    unshift @messages, "Importing $profile_type profiles:";
    unshift @messages, '';
    foreach my $message (@messages) {
	print "$message\n";
    }

    die "FATAL:  \u$profile_type profile importing failed.\n" if $got_error;
}

# The table_column_exists() routine is borrowed from the sibling
# pg_migrate_archive_gwcollagedb() script.

sub table_column_exists {
    my $table_name  = shift;
    my $column_name = shift;

    # If RaiseError is not set, and selectrow_arrayref() fails, it will return undef.
    # selectrow_arrayref() will also return undef if there are no more rows; this can
    # be distinguished from an error by checking $dhh->err afterwards or using RaiseError.
    # But we're running with RaiseError, so that should not be a problem.
    my $table_column_array_ref = $dbh->selectrow_arrayref( "
	select column_name
	from information_schema.columns
	where
	    table_catalog = current_catalog
	and table_schema  = current_schema
	and table_name    = '$table_name'
	and column_name   = '$column_name'
    " );
    return defined $table_column_array_ref;
}

# The make_idempotent_column_changes() routine is borrowed from the sibling
# pg_migrate_archive_gwcollagedb.pl script, where it has been extensively
# developed.  See that script for detailed comments.
#
sub make_idempotent_column_changes {
    my $changes = shift;

    foreach my $table ( keys %$changes ) {
	## FIX LATER:  Currently, we assume that each element of the top-level hash has
	## a "columns" hash key.  But in the future, we might extend this to allow this
	## routine to only establish UNIQUE constraints without having to also process some
	## column changes.  In that case, the "columns" hash key might be missing.  If
	## we allow that, then we need to ensure idempotency fof adding UNIQUE constraints,
	## because in the present code, we are pretty much assuming that any constraints we
	## handle here don't already exist (because they either never existed or because
	## they got dropped when the column processing occurred).
	##
	my $column_to_insert = $changes->{$table}{columns}[0][0];

	# Find out whether the first declared column already exists.
	# If the $column_to_insert is not in this $table, add it now.
	#
	if ( not table_column_exists( $table, $column_to_insert ) ) {
	    my @add_column_clauses       = ();
	    my @drop_column_clauses      = ();
	    my @rename_column_clauses    = ();
	    my @update_column_clauses    = ();
	    my @column_qualifier_clauses = ();
	    foreach my $column_definition ( @{ $changes->{$table}{columns} } ) {
		my $column_name = $column_definition->[0];
		if ( $column_name ne $column_to_insert ) {
		    push @update_column_clauses, "new_$column_name = $column_name";
		    push @drop_column_clauses,   "drop column $column_name";
		    push @rename_column_clauses, "rename column new_$column_name to $column_name";
		    $column_name = "new_$column_name";
		}
		my $column_type = $column_definition->[1];
		push @add_column_clauses, "add column $column_name $column_type";
		my $column_qualifiers = $column_definition->[2];
		if ( defined $column_qualifiers ) {
		    push @column_qualifier_clauses, "alter column $column_name set $column_qualifiers";
		}
	    }
	    $dbh->do( "alter table $table " . join( ', ', @add_column_clauses ) );
	    $dbh->do( "update $table set "  . join( ', ', @update_column_clauses ) ) if @update_column_clauses;
	    $dbh->do( "alter table $table " . join( ', ', @column_qualifier_clauses ) ) if @column_qualifier_clauses;
	    $dbh->do( "alter table $table " . join( ', ', @drop_column_clauses ) ) if @drop_column_clauses;
	    $dbh->do( "alter table $table $_" ) for @rename_column_clauses;

	    # FIX LATER:  Check the ownership of added UNIQUE constraints; set here if necessary (but probably not).

	    # After making the column adjustments, restore the UNIQUE constraint(s) that got
	    # dropped, if any, when the original columns were dropped.  And while we're at it,
	    # we can include the new column in the replaced constraints, or add new UNIQUE
	    # constraints for the new column, since those operations are convenient here.
	    if ( exists $changes->{$table}{unique_constraints} ) {
		foreach my $constraint ( keys %{ $changes->{$table}{unique_constraints} } ) {
		    $dbh->do( "alter table $table add constraint \"$constraint\" UNIQUE ("
			  . join( ', ', @{ $changes->{$table}{unique_constraints}{$constraint} } )
			  . ")" );
		}
	    }
	}
    }
}

##############################################################################
# Pick up database-access location and credentials
##############################################################################

if ( -e "/usr/local/groundwork/config/db.properties" ) {
    open( FILE, '<', '/usr/local/groundwork/config/db.properties' )
      or die "\nCannot open the db.properties file ($!); aborting!\n";
    while ( my $line = <FILE> ) {
	if ( $line =~ /^\s*monarch\.dbhost\s*=\s*(\S+)/ )   { $dbhost = $1 }
	if ( $line =~ /^\s*monarch\.database\s*=\s*(\S+)/ ) { $dbname = $1 }
	if ( $line =~ /^\s*monarch\.username\s*=\s*(\S+)/ ) { $dbuser = $1 }
	if ( $line =~ /^\s*monarch\.password\s*=\s*(\S+)/ ) { $dbpass = $1 }
    }
    close(FILE);
}

if ( !defined($dbhost) or !defined($dbname) or !defined($dbuser) or !defined($dbpass) ) {
    my $database_name = defined($dbname) ? $dbname : 'monarch';
    print "ERROR:  Cannot read the \"$database_name\" database configuration.\n";
    exit (1);
}

##############################################################################
# Connect to the database
##############################################################################

print "\nMonarch $monarch_version Update\n";
print "=============================================================\n";

# We deliberately only allow connection to a PostgreSQL database, no longer supporting
# MySQL as an alternative, because we are now free to use (and in some cases require
# the use of) various PostgreSQL capabilities such as savepoints, in our scripting.
my $dsn = "DBI:Pg:dbname=$dbname;host=$dbhost";

# We turn AutoCommit off because we want to make changes roll back automatically as much as
# possible if we don't get successfully through the entire script.  This is not perfect (i.e.,
# we don't necessarily have all the changes made in a single huge transaction) because some of
# the transformations may implicitly commit previous changes, and there is nothing we can do
# about that.  Still, we do the best we can.
#
# We turn PrintError off because RaiseError is on and we don't want duplicate messages printed.

print "\nConnecting to the $dbname database with user $dbuser ...\n";
eval { $dbh = DBI->connect_cached( $dsn, $dbuser, $dbpass, { 'AutoCommit' => 0, 'RaiseError' => 1, 'PrintError' => 0 } ) };
if ($@) {
    chomp $@;
    print "ERROR:  database connect failed ($@)\n";
    exit (1);
}

print "\nEncapsulating the changes in a transaction ...\n";
$dbh->do("set session transaction isolation level serializable");

##############################################################################
# Prepare for changes, in a manner that we can use to tell if the subsequent
# processing got aborted before it was finished.
##############################################################################

print "\nAltering the monarch_version value ...\n";

# Our first act of modifying the database is to update the Monarch version
# number, so it reflects the fact that the schema and content are in transition.

$sqlstmt = "select value from setup where name = 'monarch_version' and type = 'config'";
my ($old_monarch_version) = $dbh->selectrow_array($sqlstmt);

# Create an artificial Monarch version number which we will use to flag the fact that a migration is in progress.
# If the migration completes successfully, this setting will be updated to be the target Monarch version.
# If not, it will remain as an indicator to later users of the database that the schema is in bad shape.
my $transient_monarch_version = defined($old_monarch_version) && length($old_monarch_version) ? $old_monarch_version : '0.1';
$transient_monarch_version = '-' . $transient_monarch_version if $transient_monarch_version !~ /^-/;

# We delete/insert instead of just updating, in case somehow the database is so corrupted
# that it entirely lacks a current monarch_version setting.
$sqlstmt = "delete from setup where name = 'monarch_version' and type = 'config'";
$dbh->do($sqlstmt);

# For now, we stuff in a value for the Monarch version that will flag the fact that migration is in
# progress.  This will be replaced at the very end if we got through the entire script unscathed.
do {
    ## Localize and turn off RaiseError for this block, so we can test explicitly for
    ## certain conditions and emit a more informative error message in some cases.
    local $dbh->{RaiseError};

    $sqlstmt = "insert into setup values('monarch_version','config',?)";
    $outcome = $dbh->do( $sqlstmt, {}, $transient_monarch_version );
    if ( not defined $outcome ) {
	print $dbh->errstr . "\n";
	exit (1);
    }
    if ( $outcome != 1 ) {
	## It's highly unlikely that we would get here if the insert worked,
	## as I don't see any circumstances where the insert would succeed but
	## produce a non-unit outcome.  Nevertheless, if something weird like
	## that happens, it would be more helpful to know about the failure
	## in terms of what it means to this application script.
	print "ERROR:  Could not update the monarch_version setting before migration!\n";
	exit (1);
    }
};

##############################################################################
# Global initialization, to prepare for later stages
##############################################################################

print "\nInitializing ...\n";

$sqlstmt = "select value from setup where name = 'nagios_etc'";
($nagios_etc) = $dbh->selectrow_array($sqlstmt);

until ($nagios_etc) {
    my $default_path = '';
    if ( -e '/usr/local/nagios/etc/nagios.cfg' ) {
	$nagios_etc = '/usr/local/nagios/etc';
    }
    elsif ( -e '/etc/nagios/nagios.cfg' ) {
	$nagios_etc = '/etc/nagios';
    }
    elsif ( -e '/usr/local/nagios/etc/nagios.cfg' ) {
	$nagios_etc = "/usr/local/nagios/etc";
    }

    $default_path = " [ $nagios_etc ]" if $nagios_etc;
    print "\nPlease enter the path in which nagios.cfg resides$default_path: ";
    my $input = <STDIN>;
    chomp $input;
    if ($input) { $nagios_etc = $input; }
    unless ( -e $nagios_etc ) {
	print "\nError: Cannot locate nagios.cfg in path $nagios_etc ...\n";
	$nagios_etc = '';
    }
}

##############################################################################
# Schema changes for the Monarch 4.0 => 4.1 transition
##############################################################################

#-----------------------------------------------------------------------------
# Convert all boolean columns back to integral types,
# as they were under MySQL.
#-----------------------------------------------------------------------------

print "\nConverting columns to integral types, if needed ...\n";

# While the initial conversions we want to run here are all boolean => smallint, we
# define this conversion as generally as we can currently imagine, so this table of
# column conversions can be extended in the future with other transformations.

my $boolean_to_integral = 'using case when {COLUMN} = true then 1 when {COLUMN} = false then 0 else null end';

#                                                                    new
#     table                column             old type   new type    default  conversion
#     -------------------  -----------------  ---------  ----------  -------  --------------------
my @convert_to_4_1_column_types = (
    [ 'contacts',          'status',          'boolean', 'smallint', undef,   $boolean_to_integral ],
    [ 'external_host',     'modified',        'boolean', 'smallint', undef,   $boolean_to_integral ],
    [ 'external_service',  'modified',        'boolean', 'smallint', undef,   $boolean_to_integral ],
    [ 'hostgroups',        'status',          'boolean', 'smallint', undef,   $boolean_to_integral ],
    [ 'hosts',             'status',          'boolean', 'smallint', undef,   $boolean_to_integral ],
    [ 'import_schema',     'smart_name',      'boolean', 'smallint', 0,       $boolean_to_integral ],
    [ 'performanceconfig', 'enable',          'boolean', 'smallint', 0,       $boolean_to_integral ],
    [ 'performanceconfig', 'parseregx_first', 'boolean', 'smallint', 0,       $boolean_to_integral ],
    [ 'performanceconfig', 'service_regx',    'boolean', 'smallint', 0,       $boolean_to_integral ],
    [ 'service_instance',  'status',          'boolean', 'smallint', 0,       $boolean_to_integral ],
    [ 'services',          'status',          'boolean', 'smallint', undef,   $boolean_to_integral ],
);

foreach my $column_to_convert (@convert_to_4_1_column_types) {
    my $table       = $column_to_convert->[0];
    my $column      = $column_to_convert->[1];
    my $old_type    = $column_to_convert->[2];
    my $new_type    = $column_to_convert->[3];
    my $new_default = $column_to_convert->[4];
    my $conversion  = $column_to_convert->[5];

    $sqlstmt = "
	select data_type, column_default
	from information_schema.columns
	where table_name = '$table'
	and column_name = '$column'
    ";
    my ( $data_type, $column_default ) = $dbh->selectrow_array($sqlstmt);

    if ( $data_type eq $old_type ) {
	if ( defined $column_default ) {
	    $sqlstmt = "alter table \"$table\" alter column \"$column\" drop default";
	    $dbh->do($sqlstmt);
	}

	$sqlstmt = "alter table \"$table\" alter column \"$column\" type $new_type";
	if ( defined $conversion ) {
	    $conversion =~ s/{COLUMN}/"$column"/g;
	    $sqlstmt .= " $conversion";
	}
	$dbh->do($sqlstmt);
    }

    if ( defined $new_default ) {
	$sqlstmt = "alter table \"$table\" alter column \"$column\" set default $new_default";
	$dbh->do($sqlstmt);
    }
}

##############################################################################
# Data changes for the Monarch 4.1 => 4.2 transition
##############################################################################

#-----------------------------------------------------------------------------
# GWMON-11040:  Deal with changes to the check_service_freshness option.
#-----------------------------------------------------------------------------

# There is nothing to do here for check_service_freshness in the upgrade
# script, because we don't want to risk modifying a running production setup.

#-----------------------------------------------------------------------------
# GWMON-11057:  In the fresh-install setup for GWMEE 7.0.0, we have changed
# the command line for the local_process_gw_listener service to refer to the
# new process arguments for the java process of interest.  This same change
# must be made during an upgrade to the command line for generic services and
# any host services that still use the old argument form.
#-----------------------------------------------------------------------------

# First convert the generic service, both changing what it monitors
# and fixing its description to match what this service really does.
$dbh->do( "
    update service_names
    set command_line = replace(command_line, 'groundwork/foundation/container/lib/jboss', 'groundwork/foundation/container/jpp/standalone')
    where name='local_process_gw_listener'
" );
$dbh->do( "
    update service_names
    set description = 'Check presence of gwservices process'
    where name='local_process_gw_listener'
    and description = 'Check NSCA port at host'
" );

# Then convert the associated host services (of which we expect there
# will generally be only one per GWMEE server, which probably means always
# the standalone/parent server and presumably each child server as well):
$dbh->do( "
    update services
    set command_line=replace(command_line, 'groundwork/foundation/container/lib/jboss', 'groundwork/foundation/container/jpp/standalone')
    where servicename_id in (select servicename_id from service_names where name = 'local_process_gw_listener')
" );

#-----------------------------------------------------------------------------
# Add a new "service = '^.+\..+'" (otherwise known as "Collector Metric")
# performance configuration entry to support graphing for CloudHub metrics.
# Instead of using the old broken values used in the GWMEE 7.0.0 seed data, we
# now directly use the corrected RRA xff values from the GWMEE 7.0.1 release.
#-----------------------------------------------------------------------------

idempotent_insert ('performanceconfig', 'Collector Metric',
"(DEFAULT, '*', '^.+\\..+', 'nagios', 1, NULL, 1, 'Collector Metric', '\$HOST\$_\$SERVICE\$.rrd',
'\$RRDTOOL\$ create \$RRDNAME\$ --step 300 --start n-1yr DS:metric:GAUGE:1800:U:U RRA:AVERAGE:0.99:1:8640 RRA:AVERAGE:0.99:12:9480',
'\$RRDTOOL\$ update \$RRDNAME\$ \$LASTCHECK\$:\$VALUE1\$ 2>&1',
'rrdtool graph - 
 DEF:a=\"rrd_source\":ds_source_0:AVERAGE 
 CDEF:cdefa=a 
 AREA:cdefa#0000FF:\"Collector Metric\" 
 GPRINT:cdefa:MIN:min=%.2lf 
 GPRINT:cdefa:AVERAGE:avg=%.2lf 
 GPRINT:cdefa:MAX:max=%.2lf 
 -c BACK#FFFFFF 
 -c CANVAS#FFFFFF 
 -c GRID#C0C0C0 
 -c MGRID#404040 
 -c ARROW#FFFFFF 
 -Y --height 120 -l 0',
'', ' ')" );

##############################################################################
# Data changes for the Monarch 4.2 => 4.3 transition
##############################################################################

#-----------------------------------------------------------------------------
# Preliminary setup.
#-----------------------------------------------------------------------------

# First determine whether auto-registration is enabled.  If you happen to have
# it turned off when the upgrade happens, you can just turn it on and run this
# script again to have related objects added.  That's because by design, each
# action in this script must be safe to run against a production database, even
# in the middle of a deployment (i.e., not necessarily just at upgrade time).
if ( not read_register_agents_config_file( $auto_registration_config_file, $debug_config ) ) {
    die "FATAL:  Could not tell whether automated agent registration is enabled.\n";
}

#-----------------------------------------------------------------------------
# Force externals to be enabled in Monarch, to provide out-of-the-box
# support for GDMA auto-registration.
#-----------------------------------------------------------------------------

if ($auto_registration_is_enabled) {
    print "\nEnabling externals ...\n";

    $dbh->do( "update setup set value = '1' where name = 'enable_externals' and type = 'config'" );
}

#-----------------------------------------------------------------------------
# Add a default hostgroup for auto-registration, if the hostgroup named
# for that purpose in the config file is not already present, to provide
# out-of-the-box support for GDMA auto-registration.
#-----------------------------------------------------------------------------

if ($auto_registration_is_enabled) {
    if ($default_auto_registration_hostgroup) {
	print "\nAdding hostgroup \"$default_auto_registration_hostgroup\", if not present ...\n";

	# WARNING:  If you need to edit these lines, watch carefully for the treatment of
	# backslash escapes, to make sure you really do get exactly what you want inserted.
	# Test like mad.

	# I would have appended "See the default_hostgroup in config/register_agent.properties for details."
	# to the notes field, as being more descriptive of the usage of this hostgroup, but that string shows
	# up in the Status Viewer, where that level of detail doesn't really belong.

	my $quoted_hostgroup = $dbh->quote($default_auto_registration_hostgroup);
	idempotent_insert( 'hostgroups', $default_auto_registration_hostgroup,
	    "(DEFAULT, $quoted_hostgroup, 'Auto-registered hosts', null, null, null, null, '# hostgroup',
	    'This hostgroup is used for GDMA auto-registration.')"
	);
    }
    else {
	print "\nWARNING:  Skipping adding a default hostgroup for auto-registration,\n";
	print "          because we could not find a valid name for it in the config file.\n";
    }
}

#-----------------------------------------------------------------------------
# Add a default Monarch configuration group for auto-registration, if the
# Monarch configuration group named for that purposes is not already present,
# to provide out-of-the-box support for GDMA auto-registration.
#-----------------------------------------------------------------------------

if ($auto_registration_is_enabled) {
    if ($default_auto_registration_monarch_group) {
	print "\nAdding Monarch configuration group \"$default_auto_registration_monarch_group\", if not present ...\n";

	# WARNING:  If you need to edit these lines, watch carefully for the treatment of
	# backslash escapes, to make sure you really do get exactly what you want inserted.
	# Test like mad.

	my $quoted_monarch_group = $dbh->quote($default_auto_registration_monarch_group);
	idempotent_insert( 'monarch_groups', $default_auto_registration_monarch_group,
	    "(DEFAULT,
	    $quoted_monarch_group,
	    'Group for management of auto-registered GDMA systems.  See the default_monarch_group in config/register_agent.properties for details.',
	    '/usr/local/groundwork/monarch/htdocs/gdma',
	    null,
	    '<?xml version=\"1.0\" ?>\n<data>\n <prop name=\"label_enabled\"><![CDATA[]]>\n </prop>\n <prop name=\"label\"><![CDATA[]]>\n </prop>\n <prop name=\"nagios_etc\"><![CDATA[]]>\n </prop>\n <prop name=\"use_hosts\"><![CDATA[]]>\n </prop>\n <prop name=\"inherit_host_active_checks_enabled\"><![CDATA[1]]>\n </prop>\n <prop name=\"inherit_host_passive_checks_enabled\"><![CDATA[1]]>\n </prop>\n <prop name=\"inherit_service_active_checks_enabled\"><![CDATA[1]]>\n </prop>\n <prop name=\"inherit_service_passive_checks_enabled\"><![CDATA[1]]>\n </prop>\n <prop name=\"host_active_checks_enabled\"><![CDATA[-zero-]]>\n </prop>\n <prop name=\"host_passive_checks_enabled\"><![CDATA[-zero-]]>\n </prop>\n <prop name=\"service_active_checks_enabled\"><![CDATA[-zero-]]>\n </prop>\n <prop name=\"service_passive_checks_enabled\"><![CDATA[-zero-]]>\n </prop>\n</data>')"
	);
    }
    else {
	print "\nWARNING:  Skipping adding a default Monarch configuration group for\n";
	print "          auto-registration, because we could not find a valid name for it\n";
	print "          in the config file.\n";
    }
}

#-----------------------------------------------------------------------------
# Add new pre-loaded host profiles, if not already present,
# to provide out-of-the-box support for GDMA auto-registration.
#-----------------------------------------------------------------------------

if ($auto_registration_is_enabled) {
    print "\nAdding host profiles for GDMA auto-registration, if not present ...\n";
    idempotently_add_profiles(
	'host',
	[
	    qw(
	      gdma-aix-host.xml
	      gdma-linux-host.xml
	      gdma-solaris-host.xml
	      gdma-windows-host.xml
	      )
	]
    );
}

#-----------------------------------------------------------------------------
# Add new performance-configuration entries, if not already present,
# to support GDMA-monitored services.
#-----------------------------------------------------------------------------

print "\nAdding performance-config entries for GDMA-monitored services, if not present ...\n";

# WARNING:  If you need to edit these lines, watch carefully for the treatment of
# backslash escapes, to make sure you really do get exactly what you want inserted.
# Test like mad.

idempotent_insert ('performanceconfig', 'aix_disk',
"(DEFAULT, '*', 'aix_disk', 'nagios', 1, NULL, 1, 'Disk Utilization', '\$HOST\$_\$SERVICE\$.rrd',
'\$RRDTOOL\$ create \$RRDNAME\$ --step 600 --start n-1yr \$LISTSTART\$DS:\$LABEL#\$:GAUGE:1800:U:U DS:\$LABEL#\$_wn:GAUGE:1800:U:U DS:\$LABEL#\$_cr:GAUGE:1800:U:U DS:\$LABEL#\$_mx:GAUGE:1800:U:U \$LISTEND\$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480',
'RRDTOOL\$ update \$RRDNAME\$ \$LASTCHECK\$:\$VALUE1\$:\$WARN1\$:\$CRIT1\$:\$MAX1\$ 2>&1',
'rrdtool graph - DEF:a=\"rrd_source\":ds_source_0:AVERAGE DEF:w=\"rrd_source\":ds_source_1:AVERAGE DEF:c=\"rrd_source\":ds_source_2:AVERAGE DEF:m=\"rrd_source\":ds_source_3:AVERAGE CDEF:cdefa=a,m,/,100,* CDEF:cdefb=a,0.99,* CDEF:cdefw=w CDEF:cdefc=c CDEF:cdefm=m AREA:a#C35617:\"Space Used\\: \" LINE:cdefa#FFCC00: GPRINT:a:LAST:\"%.2lf MB\\l\" LINE2:cdefw#FFFF00:\"Warning Threshold\\:\" GPRINT:cdefw:AVERAGE:\"%.2lf\" LINE2:cdefc#FF0033:\"Critical Threshold\\:\" GPRINT:cdefc:AVERAGE:\"%.2lf\\l\" GPRINT:cdefa:AVERAGE:\"Percentage Space Used\"=%.2lf GPRINT:cdefm:AVERAGE:\"Maximum Capacity\"=%.2lf CDEF:cdefws=a,cdefw,GT,a,0,IF AREA:cdefws#FFFF00 CDEF:cdefcs=a,cdefc,GT,a,0,IF AREA:cdefcs#FF0033 -c BACK#FFFFFF -c CANVAS#FFFFFF -c GRID#C0C0C0 -c MGRID#404040 -c ARROW#FFFFFF -Y -l 0', ' ', ' ')" );

idempotent_insert ('performanceconfig', 'aix_load',
"(DEFAULT, '*', 'aix_load', 'nagios', 1, NULL, NULL, 'Load Averages', '\$HOST\$_\$SERVICE\$.rrd',
'\$RRDTOOL\$ create \$RRDNAME\$ --step 600 --start n-1yr \$LISTSTART\$ DS:\$LABEL#\$:GAUGE:1800:U:U DS:\$LABEL#\$_wn:GAUGE:1800:U:U DS:\$LABEL#\$_cr:GAUGE:1800:U:U \$LISTEND\$  RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480',
'\$RRDTOOL\$ update \$RRDNAME\$ \$LASTCHECK\$:\$VALUE1\$:\$WARN1\$:\$CRIT1\$:\$VALUE2\$:\$WARN2\$:\$CRIT2\$:\$VALUE3\$:\$WARN3\$:\$CRIT3\$ 2>&1',
'rrdtool graph - --imgformat=PNG --slope-mode DEF:a=rrd_source:ds_source_0:AVERAGE DEF:aw=\"rrd_source\":ds_source_1:AVERAGE DEF:ac=\"rrd_source\":ds_source_2:AVERAGE DEF:b=rrd_source:ds_source_3:AVERAGE DEF:bw=\"rrd_source\":ds_source_4:AVERAGE DEF:bc=\"rrd_source\":ds_source_5:AVERAGE DEF:c=rrd_source:ds_source_6:AVERAGE DEF:cw=\"rrd_source\":ds_source_7:AVERAGE DEF:cc=\"rrd_source\":ds_source_8:AVERAGE CDEF:cdefa=a CDEF:cdefb=b CDEF:cdefc=c AREA:cdefa#FF6600:\"One Minute Load Average\" GPRINT:cdefa:MIN:min=%.2lf  GPRINT:cdefa:AVERAGE:avg=%.2lf GPRINT:cdefa:MAX:\"max=%.2lf\\l\" LINE:aw#FFCC33:\"1 min avg Warning Threshold\" GPRINT:aw:LAST:\"%.1lf\" LINE:ac#FF0000:\"1 min avg Critical Threshold\" GPRINT:ac:LAST:\"%.1lf\\l\" LINE2:cdefb#3300FF:\"Five Minute Load Average\" GPRINT:cdefb:MIN:min=%.2lf GPRINT:cdefb:AVERAGE:avg=%.2lf GPRINT:cdefb:MAX:\"max=%.2lf\\l\" LINE:bw#6666CC:\"5 min avg Warning Threshold\" GPRINT:bw:LAST:\"%.1lf\" LINE:bc#CC0000:\"5 min avg Critical Threshold\" GPRINT:bc:LAST:\"%.1lf\\l\" LINE3:cdefc#999999:\"Fifteen Minute Load Average\" GPRINT:cdefc:MIN:min=%.2lf GPRINT:cdefc:AVERAGE:avg=%.2lf GPRINT:cdefc:MAX:\"max=%.2lf\\l\" LINE:cw#CCCC99:\"15 min avg Warning Threshold\" GPRINT:cw:LAST:\"%.1lf\" LINE:cc#990000:\"15 min avg Critical Threshold\" GPRINT:cc:LAST:\"%.1lf\\l\" -c BACK#FFFFFF -c CANVAS#FFFFFF -c GRID#C0C0C0 -c MGRID#404040 -c ARROW#FFFFFF-Y --height 120', ' ', ' ')" );

idempotent_insert ('performanceconfig', 'aix_process_count',
"(DEFAULT, '*', 'aix_process_count', 'nagios', 1, 1, NULL, 'Process Count', '\$HOST\$_\$SERVICE\$.rrd',
'\$RRDTOOL\$ create \$RRDNAME\$ --step 600 --start n-1yr DS:number:GAUGE:1800:U:U RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480',
'\$RRDTOOL\$ update \$RRDNAME\$ \$LASTCHECK\$:\$VALUE1\$ 2>&1',
'rrdtool graph - DEF:a=\"rrd_source\":ds_source_0:AVERAGE CDEF:cdefa=a AREA:cdefa#0000FF:\"Number of Processes\" GPRINT:cdefa:MIN:min=%.2lf GPRINT:cdefa:AVERAGE:avg=%.2lf GPRINT:cdefa:MAX:max=%.2lf  -c BACK#FFFFFF -c CANVAS#FFFFFF -c GRID#C0C0C0 -c MGRID#404040 -c ARROW#FFFFFF -Y --height 120 -l 0', ' ', '(\\d+) process')" );

idempotent_insert ('performanceconfig', 'aix_swap',
"(DEFAULT, '*', 'aix_swap', 'nagios', 1, NULL, NULL, 'Swap Utilization', '\$HOST\$_\$SERVICE\$.rrd',
'\$RRDTOOL\$ create \$RRDNAME\$ --step 600 --start n-1yr \$LISTSTART\$DS:\$LABEL#\$:GAUGE:1800:U:U DS:\$LABEL#\$_wn:GAUGE:1800:U:U DS:\$LABEL#\$_cr:GAUGE:1800:U:U DS:\$LABEL#\$_mx:GAUGE:1800:U:U \$LISTEND\$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480',
'\$RRDTOOL\$ update \$RRDNAME\$ \$LASTCHECK\$:\$VALUE1\$:\$WARN1\$:\$CRIT1\$:\$MAX1\$ 2>&1',
'rrdtool graph - DEF:a=\"rrd_source\":ds_source_0:AVERAGE DEF:w=\"rrd_source\":ds_source_1:AVERAGE DEF:c=\"rrd_source\":ds_source_2:AVERAGE DEF:m=\"rrd_source\":ds_source_3:AVERAGE CDEF:cdefa=a,m,/,100,* CDEF:cdefw=w CDEF:cdefc=c CDEF:cdefm=m AREA:a#9900FF:\"Swap Free\\: \" LINE2:a#6600FF: GPRINT:a:LAST:\"%.2lf MB\\l\" CDEF:cdefws=a,cdefw,LT,a,0,IF AREA:cdefws#FFFF00 CDEF:cdefcs=a,cdefc,LT,a,0,IF AREA:cdefcs#FF0033 LINE2:cdefw#FFFF00:\"Warning Threshold\\:\" GPRINT:cdefw:AVERAGE:\"%.2lf\" LINE2:cdefc#FF0033:\"Critical Threshold\\:\" GPRINT:cdefc:AVERAGE:\"%.2lf\\l\" GPRINT:cdefa:AVERAGE:\"Percentage Swap Free\"=%.2lf GPRINT:cdefm:AVERAGE:\"Total Swap Space=%.2lf\" -c BACK#FFFFFF -c CANVAS#FFFFFF -c GRID#C0C0C0 -c MGRID#404040 -c ARROW#FFFFFF -Y -l 0', ' ', ' ')" );

idempotent_insert ('performanceconfig', 'linux_disk',
"(DEFAULT, '*', 'linux_disk', 'nagios', 1, NULL, 1, 'Disk Utilization', '\$HOST\$_\$SERVICE\$.rrd',
'\$RRDTOOL\$ create \$RRDNAME\$ --step 600 --start n-1yr \$LISTSTART\$DS:\$LABEL#\$:GAUGE:1800:U:U DS:\$LABEL#\$_wn:GAUGE:1800:U:U DS:\$LABEL#\$_cr:GAUGE:1800:U:U DS:\$LABEL#\$_mx:GAUGE:1800:U:U \$LISTEND\$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480',
'\$RRDTOOL\$ update \$RRDNAME\$ \$LASTCHECK\$:\$VALUE1\$:\$WARN1\$:\$CRIT1\$:\$MAX1\$ 2>&1',
'rrdtool graph - DEF:a=\"rrd_source\":ds_source_0:AVERAGE DEF:w=\"rrd_source\":ds_source_1:AVERAGE DEF:c=\"rrd_source\":ds_source_2:AVERAGE DEF:m=\"rrd_source\":ds_source_3:AVERAGE CDEF:cdefa=a,m,/,100,* CDEF:cdefb=a,0.99,* CDEF:cdefw=w CDEF:cdefc=c CDEF:cdefm=m AREA:a#C35617:\"Space Used\\: \" LINE:cdefa#FFCC00: GPRINT:a:LAST:\"%.2lf MB\\l\" LINE2:cdefw#FFFF00:\"Warning Threshold\\:\" GPRINT:cdefw:AVERAGE:\"%.2lf\" LINE2:cdefc#FF0033:\"Critical Threshold\\:\" GPRINT:cdefc:AVERAGE:\"%.2lf\\l\" GPRINT:cdefa:AVERAGE:\"Percentage Space Used\"=%.2lf GPRINT:cdefm:AVERAGE:\"Maximum Capacity\"=%.2lf CDEF:cdefws=a,cdefw,GT,a,0,IF AREA:cdefws#FFFF00 CDEF:cdefcs=a,cdefc,GT,a,0,IF AREA:cdefcs#FF0033 -c BACK#FFFFFF -c CANVAS#FFFFFF -c GRID#C0C0C0 -c MGRID#404040 -c ARROW#FFFFFF -Y  -l 0', ' ', ' ')" );

idempotent_insert ('performanceconfig', 'linux_load',
"(DEFAULT, '*', 'linux_load', 'nagios', 1, NULL, NULL, 'Load Averages', '\$HOST\$_\$SERVICE\$.rrd',
'\$RRDTOOL\$ create \$RRDNAME\$ --step 600 --start n-1yr \$LISTSTART\$ DS:\$LABEL#\$:GAUGE:1800:U:U DS:\$LABEL#\$_wn:GAUGE:1800:U:U DS:\$LABEL#\$_cr:GAUGE:1800:U:U \$LISTEND\$  RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480',
'\$RRDTOOL\$ update \$RRDNAME\$ \$LASTCHECK\$:\$VALUE1\$:\$WARN1\$:\$CRIT1\$:\$VALUE2\$:\$WARN2\$:\$CRIT2\$:\$VALUE3\$:\$WARN3\$:\$CRIT3\$ 2>&1',
'rrdtool graph - --imgformat=PNG --slope-mode DEF:a=rrd_source:ds_source_0:AVERAGE DEF:aw=\"rrd_source\":ds_source_1:AVERAGE DEF:ac=\"rrd_source\":ds_source_2:AVERAGE DEF:b=rrd_source:ds_source_3:AVERAGE DEF:bw=\"rrd_source\":ds_source_4:AVERAGE DEF:bc=\"rrd_source\":ds_source_5:AVERAGE DEF:c=rrd_source:ds_source_6:AVERAGE DEF:cw=\"rrd_source\":ds_source_7:AVERAGE DEF:cc=\"rrd_source\":ds_source_8:AVERAGE CDEF:cdefa=a CDEF:cdefb=b CDEF:cdefc=c AREA:cdefa#FF6600:\"One Minute Load Average\" GPRINT:cdefa:MIN:min=%.2lf  GPRINT:cdefa:AVERAGE:avg=%.2lf GPRINT:cdefa:MAX:\"max=%.2lf\\l\" LINE:aw#FFCC33:\"1 min avg Warning Threshold\" GPRINT:aw:LAST:\"%.1lf\" LINE:ac#FF0000:\"1 min avg Critical Threshold\" GPRINT:ac:LAST:\"%.1lf\\l\" LINE2:cdefb#3300FF:\"Five Minute Load Average\" GPRINT:cdefb:MIN:min=%.2lf GPRINT:cdefb:AVERAGE:avg=%.2lf GPRINT:cdefb:MAX:\"max=%.2lf\\l\" LINE:bw#6666CC:\"5 min avg Warning Threshold\" GPRINT:bw:LAST:\"%.1lf\" LINE:bc#CC0000:\"5 min avg Critical Threshold\" GPRINT:bc:LAST:\"%.1lf\\l\" LINE3:cdefc#999999:\"Fifteen Minute Load Average\" GPRINT:cdefc:MIN:min=%.2lf GPRINT:cdefc:AVERAGE:avg=%.2lf GPRINT:cdefc:MAX:\"max=%.2lf\\l\" LINE:cw#CCCC99:\"15 min avg Warning Threshold\" GPRINT:cw:LAST:\"%.1lf\" LINE:cc#990000:\"15 min avg Critical Threshold\" GPRINT:cc:LAST:\"%.1lf\\l\" -c BACK#FFFFFF -c CANVAS#FFFFFF -c GRID#C0C0C0 -c MGRID#404040 -c ARROW#FFFFFF-Y --height 120', ' ', ' ')" );

idempotent_insert ('performanceconfig', 'linux_mem',
"(DEFAULT, '*', 'linux_mem', 'nagios', 1, NULL, NULL, 'Memory Utilization', '\$HOST\$_\$SERVICE\$.rrd',
'\$RRDTOOL\$ create \$RRDNAME\$ --step 600 --start n-1yr \$LISTSTART\$ DS:\$LABEL#\$:GAUGE:1800:U:U DS:\$LABEL#\$_wn:GAUGE:1800:U:U DS:\$LABEL#\$_cr:GAUGE:1800:U:U \$LISTEND\$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480',
'\$RRDTOOL\$ update \$RRDNAME\$ \$LASTCHECK\$:\$VALUE1\$:\$WARN1\$:\$CRIT1\$ 2>&1',
'rrdtool graph - DEF:a=\"rrd_source\":ds_source_0:AVERAGE DEF:w=\"rrd_source\":ds_source_1:AVERAGE DEF:c=\"rrd_source\":ds_source_2:AVERAGE CDEF:cdefa=a CDEF:cdefb=a,0.99,* CDEF:cdefw=w CDEF:cdefc=c CDEF:cdefm=c,1.05,* AREA:a#33FFFF AREA:cdefb#3399FF:\"Memory Free\\:\" GPRINT:a:LAST:\"%.2lf Percent\" GPRINT:cdefa:MIN:min=%.2lf GPRINT:cdefa:AVERAGE:avg=%.2lf GPRINT:cdefa:MAX:max=\"%.2lf\\l\" LINE2:cdefw#FFFF00:\"Warning Threshold\\:\" GPRINT:cdefw:LAST:\"%.2lf\" LINE2:cdefc#FF0033:\"Critical Threshold\\:\" GPRINT:cdefc:LAST:\"%.2lf\\l\" COMMENT:\"Service\\: SERVICE\" CDEF:cdefws=a,cdefw,LT,a,0,IF AREA:cdefws#FFFF00 CDEF:cdefcs=a,cdefc,LT,a,0,IF AREA:cdefcs#FF0033 CDEF:cdefwt=a,cdefw,GT,cdefw,0,IF LINE:cdefwt#000000 CDEF:cdefct=a,cdefc,GT,cdefc,0,IF LINE:cdefct#000000 -c BACK#FFFFFF -c CANVAS#FFFFFF -c GRID#C0C0C0 -c MGRID#404040 -c ARROW#FFFFFF -Y -u 100 -l 0 --rigid', ' ', '([\\d\\.]+)%')" );

idempotent_insert ('performanceconfig', 'linux_process_count',
"(DEFAULT, '*', 'linux_process_count', 'nagios', 1, 1, NULL, 'Process Count', '\$HOST\$_\$SERVICE\$.rrd',
'\$RRDTOOL\$ create \$RRDNAME\$ --step 600 --start n-1yr DS:number:GAUGE:1800:U:U RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480',
'\$RRDTOOL\$ update \$RRDNAME\$ \$LASTCHECK\$:\$VALUE1\$ 2>&1',
'rrdtool graph - DEF:a=\"rrd_source\":ds_source_0:AVERAGE CDEF:cdefa=a AREA:cdefa#0000FF:\"Number of Processes\" GPRINT:cdefa:MIN:min=%.2lf GPRINT:cdefa:AVERAGE:avg=%.2lf GPRINT:cdefa:MAX:max=%.2lf  -c BACK#FFFFFF -c CANVAS#FFFFFF -c GRID#C0C0C0 -c MGRID#404040 -c ARROW#FFFFFF -Y --height 120 -l 0', ' ', '(\\d+) process')" );

idempotent_insert ('performanceconfig', 'linux_swap',
"(DEFAULT, '*', 'linux_swap', 'nagios', 1, NULL, NULL, 'Swap Utilization', '\$HOST\$_\$SERVICE\$.rrd',
'\$RRDTOOL\$ create \$RRDNAME\$ --step 600 --start n-1yr \$LISTSTART\$DS:\$LABEL#\$:GAUGE:1800:U:U DS:\$LABEL#\$_wn:GAUGE:1800:U:U DS:\$LABEL#\$_cr:GAUGE:1800:U:U DS:\$LABEL#\$_mx:GAUGE:1800:U:U \$LISTEND\$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480',
'\$RRDTOOL\$ update \$RRDNAME\$ \$LASTCHECK\$:\$VALUE1\$:\$WARN1\$:\$CRIT1\$:\$MAX1\$ 2>&1',
'rrdtool graph - DEF:a=\"rrd_source\":ds_source_0:AVERAGE DEF:w=\"rrd_source\":ds_source_1:AVERAGE DEF:c=\"rrd_source\":ds_source_2:AVERAGE DEF:m=\"rrd_source\":ds_source_3:AVERAGE CDEF:cdefa=a,m,/,100,* CDEF:cdefw=w CDEF:cdefc=c CDEF:cdefm=m AREA:a#9900FF:\"Swap Free\\: \" LINE2:a#6600FF: GPRINT:a:LAST:\"%.2lf MB\\l\" CDEF:cdefws=a,cdefw,LT,a,0,IF AREA:cdefws#FFFF00 CDEF:cdefcs=a,cdefc,LT,a,0,IF AREA:cdefcs#FF0033 LINE2:cdefw#FFFF00:\"Warning Threshold\\:\" GPRINT:cdefw:AVERAGE:\"%.2lf\" LINE2:cdefc#FF0033:\"Critical Threshold\\:\" GPRINT:cdefc:AVERAGE:\"%.2lf\\l\" GPRINT:cdefa:AVERAGE:\"Percentage Swap Free\"=%.2lf GPRINT:cdefm:AVERAGE:\"Total Swap Space=%.2lf\" -c BACK#FFFFFF -c CANVAS#FFFFFF -c GRID#C0C0C0 -c MGRID#404040 -c ARROW#FFFFFF -Y -l 0', ' ', ' ')" );

idempotent_insert ('performanceconfig', 'solaris_disk',
"(DEFAULT, '*', 'solaris_disk', 'nagios', 1, NULL, 1, 'Disk Utilization', '\$HOST\$_\$SERVICE\$.rrd',
'\$RRDTOOL\$ create \$RRDNAME\$ --step 600 --start n-1yr \$LISTSTART\$DS:\$LABEL#\$:GAUGE:1800:U:U DS:\$LABEL#\$_wn:GAUGE:1800:U:U DS:\$LABEL#\$_cr:GAUGE:1800:U:U DS:\$LABEL#\$_mx:GAUGE:1800:U:U \$LISTEND\$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480',
'\$RRDTOOL\$ update \$RRDNAME\$ \$LASTCHECK\$:\$VALUE1\$:\$WARN1\$:\$CRIT1\$:\$MAX1\$ 2>&1',
'rrdtool graph - DEF:a=\"rrd_source\":ds_source_0:AVERAGE DEF:w=\"rrd_source\":ds_source_1:AVERAGE DEF:c=\"rrd_source\":ds_source_2:AVERAGE DEF:m=\"rrd_source\":ds_source_3:AVERAGE CDEF:cdefa=a,m,/,100,* CDEF:cdefb=a,0.99,* CDEF:cdefw=w CDEF:cdefc=c CDEF:cdefm=m AREA:a#C35617:\"Space Used\\: \" LINE:cdefa#FFCC00: GPRINT:a:LAST:\"%.2lf MB\\l\" LINE2:cdefw#FFFF00:\"Warning Threshold\\:\" GPRINT:cdefw:AVERAGE:\"%.2lf\" LINE2:cdefc#FF0033:\"Critical Threshold\\:\" GPRINT:cdefc:AVERAGE:\"%.2lf\\l\" GPRINT:cdefa:AVERAGE:\"Percentage Space Used\"=%.2lf GPRINT:cdefm:AVERAGE:\"Maximum Capacity\"=%.2lf CDEF:cdefws=a,cdefw,GT,a,0,IF AREA:cdefws#FFFF00 CDEF:cdefcs=a,cdefc,GT,a,0,IF AREA:cdefcs#FF0033 -c BACK#FFFFFF -c CANVAS#FFFFFF -c GRID#C0C0C0 -c MGRID#404040 -c ARROW#FFFFFF -Y  -l 0', ' ', ' ')" );

idempotent_insert ('performanceconfig', 'solaris_load',
"(DEFAULT, '*', 'solaris_load', 'nagios', 1, NULL, NULL, 'Load Averages', '\$HOST\$_\$SERVICE\$.rrd',
'\$RRDTOOL\$ create \$RRDNAME\$ --step 600 --start n-1yr \$LISTSTART\$ DS:\$LABEL#\$:GAUGE:1800:U:U DS:\$LABEL#\$_wn:GAUGE:1800:U:U DS:\$LABEL#\$_cr:GAUGE:1800:U:U \$LISTEND\$  RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480',
'\$RRDTOOL\$ update \$RRDNAME\$ \$LASTCHECK\$:\$VALUE1\$:\$WARN1\$:\$CRIT1\$:\$VALUE2\$:\$WARN2\$:\$CRIT2\$:\$VALUE3\$:\$WARN3\$:\$CRIT3\$ 2>&1',
'rrdtool graph - --imgformat=PNG --slope-mode DEF:a=rrd_source:ds_source_0:AVERAGE DEF:aw=\"rrd_source\":ds_source_1:AVERAGE DEF:ac=\"rrd_source\":ds_source_2:AVERAGE DEF:b=rrd_source:ds_source_3:AVERAGE DEF:bw=\"rrd_source\":ds_source_4:AVERAGE DEF:bc=\"rrd_source\":ds_source_5:AVERAGE DEF:c=rrd_source:ds_source_6:AVERAGE DEF:cw=\"rrd_source\":ds_source_7:AVERAGE DEF:cc=\"rrd_source\":ds_source_8:AVERAGE CDEF:cdefa=a CDEF:cdefb=b CDEF:cdefc=c AREA:cdefa#FF6600:\"One Minute Load Average\" GPRINT:cdefa:MIN:min=%.2lf  GPRINT:cdefa:AVERAGE:avg=%.2lf GPRINT:cdefa:MAX:\"max=%.2lf\\l\" LINE:aw#FFCC33:\"1 min avg Warning Threshold\" GPRINT:aw:LAST:\"%.1lf\" LINE:ac#FF0000:\"1 min avg Critical Threshold\" GPRINT:ac:LAST:\"%.1lf\\l\" LINE2:cdefb#3300FF:\"Five Minute Load Average\" GPRINT:cdefb:MIN:min=%.2lf GPRINT:cdefb:AVERAGE:avg=%.2lf GPRINT:cdefb:MAX:\"max=%.2lf\\l\" LINE:bw#6666CC:\"5 min avg Warning Threshold\" GPRINT:bw:LAST:\"%.1lf\" LINE:bc#CC0000:\"5 min avg Critical Threshold\" GPRINT:bc:LAST:\"%.1lf\\l\" LINE3:cdefc#999999:\"Fifteen Minute Load Average\" GPRINT:cdefc:MIN:min=%.2lf GPRINT:cdefc:AVERAGE:avg=%.2lf GPRINT:cdefc:MAX:\"max=%.2lf\\l\" LINE:cw#CCCC99:\"15 min avg Warning Threshold\" GPRINT:cw:LAST:\"%.1lf\" LINE:cc#990000:\"15 min avg Critical Threshold\" GPRINT:cc:LAST:\"%.1lf\\l\" -c BACK#FFFFFF -c CANVAS#FFFFFF -c GRID#C0C0C0 -c MGRID#404040 -c ARROW#FFFFFF-Y --height 120', ' ', ' ')" );

idempotent_insert ('performanceconfig', 'solaris_process_count',
"(DEFAULT, '*', 'solaris_process_count', 'nagios', 1, 1, NULL, 'Process Count', '\$HOST\$_\$SERVICE\$.rrd',
'\$RRDTOOL\$ create \$RRDNAME\$ --step 600 --start n-1yr DS:number:GAUGE:1800:U:U RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480',
'\$RRDTOOL\$ update \$RRDNAME\$ \$LASTCHECK\$:\$VALUE1\$ 2>&1',
'rrdtool graph - DEF:a=\"rrd_source\":ds_source_0:AVERAGE CDEF:cdefa=a AREA:cdefa#0000FF:\"Number of Processes\" GPRINT:cdefa:MIN:min=%.2lf GPRINT:cdefa:AVERAGE:avg=%.2lf GPRINT:cdefa:MAX:max=%.2lf  -c BACK#FFFFFF -c CANVAS#FFFFFF -c GRID#C0C0C0 -c MGRID#404040 -c ARROW#FFFFFF -Y --height 120 -l 0', ' ', '(\\d+) process')" );

idempotent_insert ('performanceconfig', 'solaris_swap',
"(DEFAULT, '*', 'solaris_swap', 'nagios', 1, NULL, NULL, 'Swap Utilization', '\$HOST\$_\$SERVICE\$.rrd',
'\$RRDTOOL\$ create \$RRDNAME\$ --step 600 --start n-1yr \$LISTSTART\$DS:\$LABEL#\$:GAUGE:1800:U:U DS:\$LABEL#\$_wn:GAUGE:1800:U:U DS:\$LABEL#\$_cr:GAUGE:1800:U:U DS:\$LABEL#\$_mx:GAUGE:1800:U:U \$LISTEND\$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480',
'\$RRDTOOL\$ update \$RRDNAME\$ \$LASTCHECK\$:\$VALUE1\$:\$WARN1\$:\$CRIT1\$:\$MAX1\$ 2>&1',
'rrdtool graph - DEF:a=\"rrd_source\":ds_source_0:AVERAGE DEF:w=\"rrd_source\":ds_source_1:AVERAGE DEF:c=\"rrd_source\":ds_source_2:AVERAGE DEF:m=\"rrd_source\":ds_source_3:AVERAGE CDEF:cdefa=a,m,/,100,* CDEF:cdefw=w CDEF:cdefc=c CDEF:cdefm=m AREA:a#9900FF:\"Swap Free\\: \" LINE2:a#6600FF: GPRINT:a:LAST:\"%.2lf MB\\l\" CDEF:cdefws=a,cdefw,LT,a,0,IF AREA:cdefws#FFFF00 CDEF:cdefcs=a,cdefc,LT,a,0,IF AREA:cdefcs#FF0033 LINE2:cdefw#FFFF00:\"Warning Threshold\\:\" GPRINT:cdefw:AVERAGE:\"%.2lf\" LINE2:cdefc#FF0033:\"Critical Threshold\\:\" GPRINT:cdefc:AVERAGE:\"%.2lf\\l\" GPRINT:cdefa:AVERAGE:\"Percentage Swap Free\"=%.2lf GPRINT:cdefm:AVERAGE:\"Total Swap Space=%.2lf\" -c BACK#FFFFFF -c CANVAS#FFFFFF -c GRID#C0C0C0 -c MGRID#404040 -c ARROW#FFFFFF -Y -l 0', ' ', ' ')" );

idempotent_insert ('performanceconfig', 'gdma_21_wmi_cpu',
"(DEFAULT, '*', 'gdma_21_wmi_cpu', 'nagios', 1, NULL, NULL, 'CPU Utilization', '\$HOST\$_\$SERVICE\$.rrd',
'\$RRDTOOL\$ create \$RRDNAME\$ --step 600 --start n-1yr DS:percent:GAUGE:1800:U:U RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480',
'\$RRDTOOL\$ update \$RRDNAME\$ \$LASTCHECK\$:\$VALUE1\$ 2>&1',
'', '', 'CPU Utilization ([\\d\\.]+)%')" );

idempotent_insert ('performanceconfig', 'gdma_21_wmi_disktransfers',
"(DEFAULT, '*', 'gdma_21_wmi_disktransfers', 'nagios', 1, NULL, NULL, 'Disk Transfers Per Second', '\$HOST\$_\$SERVICE\$.rrd',
'\$RRDTOOL\$ create \$RRDNAME\$ --step 600 --start n-1yr DS:transferspersec:GAUGE:1800:U:U RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480',
'\$RRDTOOL\$ update \$RRDNAME\$ \$LASTCHECK\$:\$VALUE1\$ 2>&1',
'', '', ' ')" );

idempotent_insert ('performanceconfig', 'gdma_21_wmi_disk_',
"(DEFAULT, '*', 'gdma_21_wmi_disk_', 'nagios', 1, NULL, 1, 'Disk Utilization', '\$HOST\$_\$SERVICE\$.rrd',
'\$RRDTOOL\$ create \$RRDNAME\$ --step 600 --start n-1yr DS:percent:GAUGE:1800:U:U RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480',
'\$RRDTOOL\$ update \$RRDNAME\$ \$LASTCHECK\$:\$VALUE1\$ 2>&1',
'', '', 'Disk Utilization ([\\d\\.]+)%')" );

idempotent_insert ('performanceconfig', 'gdma_21_wmi_mem',
"(DEFAULT, '*', 'gdma_21_wmi_mem', 'nagios', 1, NULL, NULL, 'Memory Utilization', '\$HOST\$_\$SERVICE\$.rrd',
'\$RRDTOOL\$ create \$RRDNAME\$ --step 600 --start n-1yr DS:percent:GAUGE:1800:U:U RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480',
'\$RRDTOOL\$ update \$RRDNAME\$ \$LASTCHECK\$:\$VALUE1\$ 2>&1',
'', '', 'Memory Utilization ([\\d\\.]+)%')" );

idempotent_insert ('performanceconfig', 'gdma_21_wmi_memory_pages',
"(DEFAULT, '*', 'gdma_21_wmi_memory_pages', 'nagios', 1, NULL, NULL, 'Memory Pages Per Second', '\$HOST\$_\$SERVICE\$.rrd',
'\$RRDTOOL\$ create \$RRDNAME\$ --step 600 --start n-1yr DS:pagespersec:GAUGE:1800:U:U RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480',
'\$RRDTOOL\$ update \$RRDNAME\$ \$LASTCHECK\$:\$VALUE1\$ 2>&1',
'', '', ' ')" );

idempotent_insert ('performanceconfig','RDS',
"(DEFAULT,'*','RDS\.','nagios',1,0,1,'AWS','\$HOST\$_\$SERVICE\$.rrd',
'\$RRDTOOL\$ create \$RRDNAME\$ --step 300 --start n-1yr \$LISTSTART\$ DS:\$LABEL#\$:GAUGE:1800:U:U \$LISTEND\$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480',
'\$RRDTOOL\$ update \$RRDNAME\$ --template \$LABELLIST\$ \$LASTCHECK\$:\$VALUELIST\$ 2>&1',
'','',' ')" );

idempotent_insert ('performanceconfig','EC2',
"(DEFAULT,'*','EC2\.','nagios',1,0,1,'AWS','\$HOST\$_\$SERVICE\$.rrd',
'\$RRDTOOL\$ create \$RRDNAME\$ --step 300 --start n-1yr \$LISTSTART\$ DS:\$LABEL#\$:GAUGE:1800:U:U \$LISTEND\$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480',
'\$RRDTOOL\$ update \$RRDNAME\$ --template \$LABELLIST\$ \$LASTCHECK\$:\$VALUELIST\$ 2>&1',
'','',' ')" );
idempotent_insert ('performanceconfig','EBS',
"(DEFAULT,'*','EBS\.','nagios',1,0,1,'AWS','\$HOST\$_\$SERVICE\$.rrd',
'\$RRDTOOL\$ create \$RRDNAME\$ --step 300 --start n-1yr \$LISTSTART\$ DS:\$LABEL#\$:GAUGE:1800:U:U \$LISTEND\$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480',
'\$RRDTOOL\$ update \$RRDNAME\$ --template \$LABELLIST\$ \$LASTCHECK\$:\$VALUELIST\$ 2>&1',
'','',' ')" );
idempotent_insert ('performanceconfig','memory',
"(DEFAULT,'*','memory','nagios',1,0,0,'OS','\$HOST\$_\$SERVICE\$.rrd',
'\$RRDTOOL\$ create \$RRDNAME\$ --step 300 --start n-1yr \$LISTSTART\$ DS:\$LABEL#\$:GAUGE:1800:U:U \$LISTEND\$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480',
'\$RRDTOOL\$ update \$RRDNAME\$ --template \$LABELLIST\$ \$LASTCHECK\$:\$VALUELIST\$ 2>&1',
'','',' ')" );
idempotent_insert ('performanceconfig','memory_actual',
"(DEFAULT,'*','memory-actual','nagios',1,0,0,'OS','\$HOST\$_\$SERVICE\$.rrd',
'\$RRDTOOL\$ create \$RRDNAME\$ --step 300 --start n-1yr \$LISTSTART\$ DS:\$LABEL#\$:GAUGE:1800:U:U \$LISTEND\$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480',
'\$RRDTOOL\$ update \$RRDNAME\$ --template \$LABELLIST\$ \$LASTCHECK\$:\$VALUELIST\$ 2>&1',
'','',' ')" );
idempotent_insert ('performanceconfig','memory-rss',
"(DEFAULT,'*','memory-rss','nagios',1,0,0,'OS','\$HOST\$_\$SERVICE\$.rrd',
'\$RRDTOOL\$ create \$RRDNAME\$ --step 300 --start n-1yr \$LISTSTART\$ DS:\$LABEL#\$:GAUGE:1800:U:U \$LISTEND\$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480',
'\$RRDTOOL\$ update \$RRDNAME\$ --template \$LABELLIST\$ \$LASTCHECK\$:\$VALUELIST\$ 2>&1',
'','',' ')" );
idempotent_insert ('performanceconfig','syn_cpu',
"(DEFAULT,'*','syn(.)cpu','nagios',1,0,1,'OS','\$HOST\$_\$SERVICE\$.rrd',
'\$RRDTOOL\$ create \$RRDNAME\$ --step 300 --start n-1yr \$LISTSTART\$ DS:\$LABEL#\$:GAUGE:1800:U:U \$LISTEND\$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480',
'\$RRDTOOL\$ update \$RRDNAME\$ --template \$LABELLIST\$ \$LASTCHECK\$:\$VALUELIST\$ 2>&1',
'','',' ')" );
idempotent_insert ('performanceconfig','tap_rx',
"(DEFAULT,'*','tap(.+)_rx','nagios',1,0,1,'OS','\$HOST\$_\$SERVICE\$.rrd',
'\$RRDTOOL\$ create \$RRDNAME\$ --step 300 --start n-1yr \$LISTSTART\$ DS:\$LABEL#\$:GAUGE:1800:U:U \$LISTEND\$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480',
'\$RRDTOOL\$ update \$RRDNAME\$ --template \$LABELLIST\$ \$LASTCHECK\$:\$VALUELIST\$ 2>&1',
'','',' ')" );
idempotent_insert ('performanceconfig','tap_rx_drop',
"(DEFAULT,'*','tap(.+)_rx_drop','nagios',1,0,1,'OS','\$HOST\$_\$SERVICE\$.rrd',
'\$RRDTOOL\$ create \$RRDNAME\$ --step 300 --start n-1yr \$LISTSTART\$ DS:\$LABEL#\$:GAUGE:1800:U:U \$LISTEND\$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480',
'\$RRDTOOL\$ update \$RRDNAME\$ --template \$LABELLIST\$ \$LASTCHECK\$:\$VALUELIST\$ 2>&1',
'','',' ')" );
idempotent_insert ('performanceconfig','tap_rx_errors',
"(DEFAULT,'*','tap(.+)_rx_errors','nagios',1,0,1,'OS','\$HOST\$_\$SERVICE\$.rrd',
'\$RRDTOOL\$ create \$RRDNAME\$ --step 300 --start n-1yr \$LISTSTART\$ DS:\$LABEL#\$:GAUGE:1800:U:U \$LISTEND\$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480',
'\$RRDTOOL\$ update \$RRDNAME\$ --template \$LABELLIST\$ \$LASTCHECK\$:\$VALUELIST\$ 2>&1',
'','',' ')" );
idempotent_insert ('performanceconfig','tap_rx_packets',
"(DEFAULT,'*','tap(.+)_rx_packets','nagios',1,0,1,'OS','\$HOST\$_\$SERVICE\$.rrd',
'\$RRDTOOL\$ create \$RRDNAME\$ --step 300 --start n-1yr \$LISTSTART\$ DS:\$LABEL#\$:GAUGE:1800:U:U \$LISTEND\$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480',
'\$RRDTOOL\$ update \$RRDNAME\$ --template \$LABELLIST\$ \$LASTCHECK\$:\$VALUELIST\$ 2>&1',
'','',' ')" );
idempotent_insert ('performanceconfig','tap_tx',
"(DEFAULT,'*','tap(.+)_tx','nagios',1,0,1,'OS','\$HOST\$_\$SERVICE\$.rrd',
'\$RRDTOOL\$ create \$RRDNAME\$ --step 300 --start n-1yr \$LISTSTART\$ DS:\$LABEL#\$:GAUGE:1800:U:U \$LISTEND\$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480',
'\$RRDTOOL\$ update \$RRDNAME\$ --template \$LABELLIST\$ \$LASTCHECK\$:\$VALUELIST\$ 2>&1',
'','',' ')" );
idempotent_insert ('performanceconfig','tap_tx_drop',
"(DEFAULT,'*','tap(.+)_tx_drop','nagios',1,0,1,'OS','\$HOST\$_\$SERVICE\$.rrd',
'\$RRDTOOL\$ create \$RRDNAME\$ --step 300 --start n-1yr \$LISTSTART\$ DS:\$LABEL#\$:GAUGE:1800:U:U \$LISTEND\$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480',
'\$RRDTOOL\$ update \$RRDNAME\$ --template \$LABELLIST\$ \$LASTCHECK\$:\$VALUELIST\$ 2>&1',
'','',' ')" );
idempotent_insert ('performanceconfig','tap_tx_errors',
"(DEFAULT,'*','tap(.+)_tx_errors','nagios',1,0,1,'OS','\$HOST\$_\$SERVICE\$.rrd',
'\$RRDTOOL\$ create \$RRDNAME\$ --step 300 --start n-1yr \$LISTSTART\$ DS:\$LABEL#\$:GAUGE:1800:U:U \$LISTEND\$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480',
'\$RRDTOOL\$ update \$RRDNAME\$ --template \$LABELLIST\$ \$LASTCHECK\$:\$VALUELIST\$ 2>&1',
'','',' ')" );
idempotent_insert ('performanceconfig','ta_tx_packets',
"(DEFAULT,'*','tap(.+)_tx_packets','nagios',1,0,1,'OS','\$HOST\$_\$SERVICE\$.rrd',
'\$RRDTOOL\$ create \$RRDNAME\$ --step 300 --start n-1yr \$LISTSTART\$ DS:\$LABEL#\$:GAUGE:1800:U:U \$LISTEND\$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480',
'\$RRDTOOL\$ update \$RRDNAME\$ --template \$LABELLIST\$ \$LASTCHECK\$:\$VALUELIST\$ 2>&1',
'','',' ')" );
idempotent_insert ('performanceconfig','vd_read',
"(DEFAULT,'*','vd(.)_read','nagios',1,0,1,'OS','\$HOST\$_\$SERVICE\$.rrd',
'\$RRDTOOL\$ create \$RRDNAME\$ --step 300 --start n-1yr \$LISTSTART\$ DS:\$LABEL#\$:GAUGE:1800:U:U \$LISTEND\$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480',
'\$RRDTOOL\$ update \$RRDNAME\$ --template \$LABELLIST\$ \$LASTCHECK\$:\$VALUELIST\$ 2>&1',
'','',' ')" );
idempotent_insert ('performanceconfig','vd_read_req',
"(DEFAULT,'*','vd(.)_read_req','nagios',1,0,1,'OS','\$HOST\$_\$SERVICE\$.rrd',
'\$RRDTOOL\$ create \$RRDNAME\$ --step 300 --start n-1yr \$LISTSTART\$ DS:\$LABEL#\$:GAUGE:1800:U:U \$LISTEND\$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480',
'\$RRDTOOL\$ update \$RRDNAME\$ --template \$LABELLIST\$ \$LASTCHECK\$:\$VALUELIST\$ 2>&1',
'','',' ')" );
idempotent_insert ('performanceconfig','vd_write',
"(DEFAULT,'*','vd(.)_write','nagios',1,0,1,'OS','\$HOST\$_\$SERVICE\$.rrd',
'\$RRDTOOL\$ create \$RRDNAME\$ --step 300 --start n-1yr \$LISTSTART\$ DS:\$LABEL#\$:GAUGE:1800:U:U \$LISTEND\$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480',
'\$RRDTOOL\$ update \$RRDNAME\$ --template \$LABELLIST\$ \$LASTCHECK\$:\$VALUELIST\$ 2>&1',
'','',' ')" );
idempotent_insert ('performanceconfig','vd_write_req',
"(DEFAULT,'*','vd(.)_write_req','nagios',1,0,1,'OS','\$HOST\$_\$SERVICE\$.rrd',
'\$RRDTOOL\$ create \$RRDNAME\$ --step 300 --start n-1yr \$LISTSTART\$ DS:\$LABEL#\$:GAUGE:1800:U:U \$LISTEND\$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480',
'\$RRDTOOL\$ update \$RRDNAME\$ --template \$LABELLIST\$ \$LASTCHECK\$:\$VALUELIST\$ 2>&1',
'','',' ')" );
idempotent_insert ('performanceconfig','cpu_time',
"(DEFAULT,'*','cpu(.)_time','nagios',1,0,1,'OS','\$HOST\$_\$SERVICE\$.rrd',
'\$RRDTOOL\$ create \$RRDNAME\$ --step 300 --start n-1yr \$LISTSTART\$ DS:\$LABEL#\$:GAUGE:1800:U:U \$LISTEND\$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480',
'\$RRDTOOL\$ update \$RRDNAME\$ --template \$LABELLIST\$ \$LASTCHECK\$:\$VALUELIST\$ 2>&1',
'','',' ')" );
idempotent_insert ('performanceconfig','free_disk_gb',
"(DEFAULT,'*','free_disk_gb','nagios',1,0,0,'OS','\$HOST\$_\$SERVICE\$.rrd',
'\$RRDTOOL\$ create \$RRDNAME\$ --step 300 --start n-1yr \$LISTSTART\$ DS:\$LABEL#\$:GAUGE:1800:U:U \$LISTEND\$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480',
'\$RRDTOOL\$ update \$RRDNAME\$ --template \$LABELLIST\$ \$LASTCHECK\$:\$VALUELIST\$ 2>&1',
'','',' ')" );
idempotent_insert ('performanceconfig','free_ram_mb',
"(DEFAULT,'*','free_ram_mb','nagios',1,0,0,'OS','\$HOST\$_\$SERVICE\$.rrd',
'\$RRDTOOL\$ create \$RRDNAME\$ --step 300 --start n-1yr \$LISTSTART\$ DS:\$LABEL#\$:GAUGE:1800:U:U \$LISTEND\$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480',
'\$RRDTOOL\$ update \$RRDNAME\$ --template \$LABELLIST\$ \$LASTCHECK\$:\$VALUELIST\$ 2>&1',
'','',' ')" );
idempotent_insert ('performanceconfig','running_vms',
"(DEFAULT,'*','running_vms','nagios',1,0,0,'OS','\$HOST\$_\$SERVICE\$.rrd',
'\$RRDTOOL\$ create \$RRDNAME\$ --step 300 --start n-1yr \$LISTSTART\$ DS:\$LABEL#\$:GAUGE:1800:U:U \$LISTEND\$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480',
'\$RRDTOOL\$ update \$RRDNAME\$ --template \$LABELLIST\$ \$LASTCHECK\$:\$VALUELIST\$ 2>&1',
'','',' ')" );
idempotent_insert ('performanceconfig','cpu_util',
"(DEFAULT,'*','cpu_util','nagios',1,0,0,'OS','\$HOST\$_\$SERVICE\$.rrd',
'\$RRDTOOL\$ create \$RRDNAME\$ --step 300 --start n-1yr \$LISTSTART\$ DS:\$LABEL#\$:GAUGE:1800:U:U \$LISTEND\$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480',
'\$RRDTOOL\$ update \$RRDNAME\$ --template \$LABELLIST\$ \$LASTCHECK\$:\$VALUELIST\$ 2>&1',
'','',' ')" );
idempotent_insert ('performanceconfig','disk_read_bytes',
"(DEFAULT,'*','disk\.read\.bytes','nagios',1,0,0,'OS','\$HOST\$_\$SERVICE\$.rrd',
'\$RRDTOOL\$ create \$RRDNAME\$ --step 300 --start n-1yr \$LISTSTART\$ DS:\$LABEL#\$:GAUGE:1800:U:U \$LISTEND\$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480',
'\$RRDTOOL\$ update \$RRDNAME\$ --template \$LABELLIST\$ \$LASTCHECK\$:\$VALUELIST\$ 2>&1',
'','',' ')" );
idempotent_insert ('performanceconfig','summary_quick',
"(DEFAULT,'*','summary\.quick','nagios',1,0,1,'VM','\$HOST\$_\$SERVICE\$.rrd',
'\$RRDTOOL\$ create \$RRDNAME\$ --step 300 --start n-1yr \$LISTSTART\$ DS:\$LABEL#\$:GAUGE:1800:U:U \$LISTEND\$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480',
'\$RRDTOOL\$ update \$RRDNAME\$ --template \$LABELLIST\$ \$LASTCHECK\$:\$VALUELIST\$ 2>&1',
'','',' ')" );
idempotent_insert ('performanceconfig','syn_host',
"(DEFAULT,'*','syn\.host','nagios',1,0,1,'VM','\$HOST\$_\$SERVICE\$.rrd',
'\$RRDTOOL\$ create \$RRDNAME\$ --step 300 --start n-1yr \$LISTSTART\$ DS:\$LABEL#\$:GAUGE:1800:U:U \$LISTEND\$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480',
'\$RRDTOOL\$ update \$RRDNAME\$ --template \$LABELLIST\$ \$LASTCHECK\$:\$VALUELIST\$ 2>&1',
'','',' ')" );
idempotent_insert ('performanceconfig','perfcounter',
"(DEFAULT,'*','perfcounter\.','nagios',1,0,1,'VM','\$HOST\$_\$SERVICE\$.rrd',
'\$RRDTOOL\$ create \$RRDNAME\$ --step 300 --start n-1yr \$LISTSTART\$ DS:\$LABEL#\$:GAUGE:1800:U:U \$LISTEND\$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480',
'\$RRDTOOL\$ update \$RRDNAME\$ --template \$LABELLIST\$ \$LASTCHECK\$:\$VALUELIST\$ 2>&1',
'','',' ')" );
idempotent_insert ('performanceconfig','summary_runtime',
"(DEFAULT,'*','summary\.runtime','nagios',1,0,1,'VM','\$HOST\$_\$SERVICE\$.rrd',
'\$RRDTOOL\$ create \$RRDNAME\$ --step 300 --start n-1yr \$LISTSTART\$ DS:\$LABEL#\$:GAUGE:1800:U:U \$LISTEND\$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480',
'\$RRDTOOL\$ update \$RRDNAME\$ --template \$LABELLIST\$ \$LASTCHECK\$:\$VALUELIST\$ 2>&1',
'','',' ')" );
idempotent_insert ('performanceconfig','summary_storage',
"(DEFAULT,'*','summary\.storage','nagios',1,0,1,'VM','\$HOST\$_\$SERVICE\$.rrd',
'\$RRDTOOL\$ create \$RRDNAME\$ --step 300 --start n-1yr \$LISTSTART\$ DS:\$LABEL#\$:GAUGE:1800:U:U \$LISTEND\$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480',
'\$RRDTOOL\$ update \$RRDNAME\$ --template \$LABELLIST\$ \$LASTCHECK\$:\$VALUELIST\$ 2>&1',
'','',' ')" );
idempotent_insert ('performanceconfig','syn_vm',
"(DEFAULT,'*','syn\.vm\.','nagios',1,0,1,'VM','\$HOST\$_\$SERVICE\$.rrd',
'\$RRDTOOL\$ create \$RRDNAME\$ --step 300 --start n-1yr \$LISTSTART\$ DS:\$LABEL#\$:GAUGE:1800:U:U \$LISTEND\$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480',
'\$RRDTOOL\$ update \$RRDNAME\$ --template \$LABELLIST\$ \$LASTCHECK\$:\$VALUELIST\$ 2>&1',
'','',' ')" );
idempotent_insert ('performanceconfig','summary_capacity',
"(DEFAULT,'*','summary\.capacity','nagios',1,0,0,'VM','\$HOST\$_\$SERVICE\$.rrd',
'\$RRDTOOL\$ create \$RRDNAME\$ --step 300 --start n-1yr \$LISTSTART\$ DS:\$LABEL#\$:GAUGE:1800:U:U \$LISTEND\$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480',
'\$RRDTOOL\$ update \$RRDNAME\$ --template \$LABELLIST\$ \$LASTCHECK\$:\$VALUELIST\$ 2>&1',
'','',' ')" );
idempotent_insert ('performanceconfig','summary_freeSpace',
"(DEFAULT,'*','summary\.freeSpace','nagios',1,0,0,'VM','\$HOST\$_\$SERVICE\$.rrd',
'\$RRDTOOL\$ create \$RRDNAME\$ --step 300 --start n-1yr \$LISTSTART\$ DS:\$LABEL#\$:GAUGE:1800:U:U \$LISTEND\$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480',
'\$RRDTOOL\$ update \$RRDNAME\$ --template \$LABELLIST\$ \$LASTCHECK\$:\$VALUELIST\$ 2>&1',
'','',' ')" );
idempotent_insert ('performanceconfig','summary_uncommitted',
"(DEFAULT,'*','summary\.uncommitted','nagios',1,0,0,'VM','\$HOST\$_\$SERVICE\$.rrd',
'\$RRDTOOL\$ create \$RRDNAME\$ --step 300 --start n-1yr \$LISTSTART\$ DS:\$LABEL#\$:GAUGE:1800:U:U \$LISTEND\$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480',
'\$RRDTOOL\$ update \$RRDNAME\$ --template \$LABELLIST\$ \$LASTCHECK\$:\$VALUELIST\$ 2>&1',
'','',' ')" );
idempotent_insert ('performanceconfig','syn_storage_percent_used',
"(DEFAULT,'*','syn\.storage\.percent\.used','nagios',1,0,0,'VM','\$HOST\$_\$SERVICE\$.rrd',
'\$RRDTOOL\$ create \$RRDNAME\$ --step 300 --start n-1yr \$LISTSTART\$ DS:\$LABEL#\$:GAUGE:1800:U:U \$LISTEND\$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480',
'\$RRDTOOL\$ update \$RRDNAME\$ --template \$LABELLIST\$ \$LASTCHECK\$:\$VALUELIST\$ 2>&1',
'','',' ')" );

#-----------------------------------------------------------------------------
# Convert old Nagios configuration option names to their current forms, in
# both the Main Configuration (for a standalone or parent server) and in
# corresponding configurations for child servers (represented as Monarch
# configuration Groups).
#-----------------------------------------------------------------------------

print "\nConverting old Nagios directive names to current forms, if needed ...\n";

# An ugly situation we need to allow for here is if the site has restored a pre-3.x
# database backup, then failed to run this migration script, then modified the
# configuration through Monarch.  For each of the renamed options, Monarch will
# insert a copy of the new option name while leaving the old option name still
# in place.  A straight database update in that situation will fail because of a
# duplicate key error.  We need to find some kind of workaround for this situation.

# First, prepare for both this and later migration adjustments.
my @group_ids = ();
$sqlstmt = "select distinct group_id from monarch_group_props";
$sth     = $dbh->prepare($sqlstmt);
$sth->execute();
while ( my @values = $sth->fetchrow_array() ) {
    push @group_ids, $values[0];
}
$sth->finish;

# Now do the checking and conversion of old-to-new option names.
if ( $nagios_version =~ /^3\.?/ ) {
    ## We leave some old (MySQL-days) conversions still in place here, in case we still
    ## see the old directive names resulting from an import of Nagios config files from
    ## outside of the GroundWork context.
    my %new_option_names = (
	'use_agressive_host_checking' => 'use_aggressive_host_checking',
	'service_reaper_frequency'    => 'check_result_reaper_frequency',
	'freshness_check_interval'    => 'service_freshness_check_interval',
    );

    foreach my $old_option_name (keys %new_option_names) {
	my $new_option_name = $new_option_names{$old_option_name};

	my $old_option_name_exists = $dbh->selectrow_array( "select count(*) from setup where name='$old_option_name'" );
	my $new_option_name_exists = $dbh->selectrow_array( "select count(*) from setup where name='$new_option_name'" );

	my $old_option_name_value = $dbh->selectrow_array( "select value from setup where name='$old_option_name'" );
	my $new_option_name_value = $dbh->selectrow_array( "select value from setup where name='$new_option_name'" );

	if (! defined($old_option_name_value)) {
	    $old_option_name_value = $old_option_name_exists ? 'NULL' : 'DOES NOT EXIST';
	}
	if (! defined($new_option_name_value)) {
	    $new_option_name_value = $new_option_name_exists ? 'NULL' : 'DOES NOT EXIST';
	}

	# These lines were helpful in debugging ...
	# print "\t${old_option_name}_value='$old_option_name_value'\n";
	# print "\t${new_option_name}_value='$new_option_name_value'\n";

	if ($old_option_name_exists && $new_option_name_exists) {
	    if ($old_option_name_value ne $new_option_name_value) {
		(my $user_new_option_name = "\u$new_option_name") =~ s/_/ /g;
		print "\n";
		print "\t====================================================================\n";
		print "\t    WARNING:  For the primary Nagios configuration,\n";
		print "\t        the old $old_option_name value of '$old_option_name_value'\n";
		print "\t    is being ignored in favor of\n";
		print "\t        the new $new_option_name value of '$new_option_name_value'.\n";
		print "\t    (Note the slight option name spelling difference.)\n" if $old_option_name eq 'use_agressive_host_checking';
		print "\n";
		print "\t    This may change the behavior of your system!\n";
		print "\n";
		print "\t    Check the Nagios main configuration pages to set the\n";
		print "\t    '$user_new_option_name' option as you desire.\n";
		print "\t====================================================================\n";
		print "\n";
	    }
	    $dbh->do( "delete from setup where name='$old_option_name'" );
	}

	foreach my $group_id (@group_ids) {
	    my $old_option_name_exists  = $dbh->selectrow_array(
		"select count(*) from monarch_group_props where group_id=$group_id and name='$old_option_name'" );
	    my $new_option_name_exists = $dbh->selectrow_array(
		"select count(*) from monarch_group_props where group_id=$group_id and name='$new_option_name'" );

	    my $old_option_name_value  = $dbh->selectrow_array(
		"select value from monarch_group_props where group_id=$group_id and name='$old_option_name'" );
	    my $new_option_name_value = $dbh->selectrow_array(
		"select value from monarch_group_props where group_id=$group_id and name='$new_option_name'" );

	    if (! defined($old_option_name_value)) {
		$old_option_name_value = $old_option_name_exists ? 'NULL' : 'DOES NOT EXIST';
	    }
	    if (! defined($new_option_name_value)) {
		$new_option_name_value = $new_option_name_exists ? 'NULL' : 'DOES NOT EXIST';
	    }

	    # These lines were helpful in debugging ...
	    # print "\t${old_option_name}_value='$old_option_name_value'\n";
	    # print "\t${new_option_name}_value='$new_option_name_value'\n";

	    if ($old_option_name_exists && $new_option_name_exists) {
		if ($old_option_name_value ne $new_option_name_value) {
		    my $group_name = $dbh->selectrow_array( "select name from monarch_groups where group_id=$group_id" );
		    (my $user_new_option_name = "\u$new_option_name") =~ s/_/ /g;
		    print "\n";
		    print "\t====================================================================\n";
		    print "\t    WARNING:  For the Nagios configuration of the '$group_name' Group,\n";
		    print "\t        the old $old_option_name value of '$old_option_name_value'\n";
		    print "\t    is being ignored in favor of\n";
		    print "\t        the new $new_option_name value of '$new_option_name_value'.\n";
		    print "\t    (Note the slight option name spelling difference.)\n" if $old_option_name eq 'use_agressive_host_checking';
		    print "\n";
		    print "\t    This may change the behavior of your system!\n";
		    print "\n";
		    print "\t    Check the Nagios main configuration pages to set the\n";
		    print "\t    '$user_new_option_name' option as you desire.\n";
		    print "\t====================================================================\n";
		    print "\n";
		}
		$dbh->do( "delete from monarch_group_props where group_id=$group_id and name='$old_option_name'" );
	    }
	}

	$sqlstmt = "update setup set name = '$new_option_name' where name = '$old_option_name'";
	$sth     = $dbh->prepare($sqlstmt);
	$sth->execute();
	$sth->finish;

	$sqlstmt = "update monarch_group_props set name = '$new_option_name' where name = '$old_option_name'";
	$sth     = $dbh->prepare($sqlstmt);
	$sth->execute();
	$sth->finish;
    }
}

#-----------------------------------------------------------------------------
# Add Nagios configuration options which are new to us since the last time we
# added support for such new options, both for standalone/parent setups and
# for child servers (represented as Monarch Groups).
#
# GWMON-6148: When possible, convert user-added miscellaneous directives,
# if they exist, that correspond to now-supported standard directives,
# in setup both for the parent-server and for all Monarch Groups.  Thus in
# those cases, we preserve the existing user-set values rather than using
# the default values we would use for newly-added directives.
#-----------------------------------------------------------------------------

print "\nAdding standard Nagios directives, if needed ...\n";

# This hash will include data on both standard and miscellaneous directives, but the names of miscellaneous
# directives have a 'key'.rand() extension to distinguish these names from equivalent standard directive names.
# The name change is needed because (as of this writing) the monarch.setup table contains a unique index on
# only the setup.name field, not including the setup.type field (which would otherwise provide the necessary
# distinction between standard and miscellaneous directives ['nagios', 'nagios_cgi', and some others, vs.
# 'nagios_cfg_misc']).  The modified names means there won't be any confusion as to whether a particular
# directive name is a standard (Monarch-supported) or miscellaneous (user-added) directive.
my %setup_props = ();
$sth = $dbh->prepare("select name, value from setup");
$sth->execute();
while ( my @values = $sth->fetchrow_array() ) {
    $setup_props{ $values[0] } = $values[1];
}
$sth->finish;

# This hash will include data on just miscellaneous directives, for the primary main configuration.
my %setup_misc_props = ();
$sth = $dbh->prepare("select name, value from setup where type='nagios_cfg_misc'");
$sth->execute();
while ( my @values = $sth->fetchrow_array() ) {
    (my $directive = $values[0]) =~ s/key\d\.\d+$//;
    $setup_misc_props{$directive}{misc_name} = $values[0];
    $setup_misc_props{$directive}{value}     = $values[1];
}
$sth->finish;

# This hash will include data on both standard and miscellaneous directives.  The latter are distinguished
# not by name, but by monarch_group_props.type='nagios_cfg_misc'.  So we need to be careful about how we
# interpret this data later on.
my %group_props = ();
$sth = $dbh->prepare("select group_id, name, type, value from monarch_group_props");
$sth->execute();
while ( my @values = $sth->fetchrow_array() ) {
    ## We use {$values[2]} here to distinguish between standard and miscellaneous directives with the same name.
    $group_props{ $values[0] }{ $values[1] }{ $values[2] } = $values[3];
}
$sth->finish;

# This hash will include data on just miscellaneous directives, for each group's main configuration.
my %group_misc_props = ();
$sth = $dbh->prepare("select group_id, name, value from monarch_group_props where type='nagios_cfg_misc'");
$sth->execute();
while ( my @values = $sth->fetchrow_array() ) {
    $group_misc_props{ $values[0] }{ $values[1] } = $values[2];
}
$sth->finish;

if ( $nagios_version =~ /^3\.?/ ) {

    my $mission = undef;
    (my $nagios_dir = $nagios_etc) =~ s{/etc$}{};

    my %new_options = (
	## Options dating from MySQL days.  We leave these additions still in place
	## here, in case we ought to add them to a configuration resulting from an
	## import of Nagios config files from outside of the GroundWork context.
	'external_command_buffer_slots' => [ 'nagios',     '' ],
	'use_large_installation_tweaks' => [ 'nagios',     '1' ],
	'enable_environment_macros'     => [ 'nagios',     '0' ],
	'child_processes_fork_twice'    => [ 'nagios',     '0' ],
	'free_child_process_memory'     => [ 'nagios',     '0' ],
	'check_result_path'             => [ 'nagios',     "$nagios_dir/var/checkresults" ],
	'max_check_result_reaper_time'  => [ 'nagios',     '' ],
	'max_check_result_file_age'     => [ 'nagios',     '' ],
	'translate_passive_host_checks' => [ 'nagios',     '0' ],
	'passive_host_checks_are_soft'  => [ 'nagios',     '0' ],
	'cached_host_check_horizon'     => [ 'nagios',     '15' ],
	'cached_service_check_horizon'  => [ 'nagios',     '15' ],
	'precached_object_file'         => [ 'nagios',     "$nagios_dir/var/objects.precache" ],
	'lock_author_names'             => [ 'nagios_cgi', '0' ],

	## Options from the conversion to the Monarch 4.2 release (though these items
	## are not present in the Monarch seed data until the Monarch 4.3 release).
	'use_timezone'        => [ 'nagios', '' ],                               # if empty or all whitespace, don't put in config file
	'debug_level'         => [ 'nagios', '0' ],
	'debug_verbosity'     => [ 'nagios', '1' ],                              # if zero, must be explicitly so in config file
	'debug_file'          => [ 'nagios', "$nagios_dir/var/nagios.debug" ],
	'max_debug_file_size' => [ 'nagios', '1000000' ],                        # if zero, must be explicitly so in config file
	'enable_predictive_host_dependency_checks'    => [ 'nagios', '1' ],      # if zero, must be explicitly so in config file
	'enable_predictive_service_dependency_checks' => [ 'nagios', '1' ],      # if zero, must be explicitly so in config file
	'check_for_orphaned_hosts'                    => [ 'nagios', '1' ],      # if zero, must be explicitly so in config file
	'additional_freshness_latency'                => [ 'nagios', '15' ],     # if zero, must be explicitly so in config file
	'temp_path'                                   => [ 'nagios', '/tmp' ],   # if empty or all whitespace, don't put in config file
	'retained_host_attribute_mask'                => [ 'nagios', '0' ],
	'retained_process_host_attribute_mask'        => [ 'nagios', '0' ],
	'retained_contact_host_attribute_mask'        => [ 'nagios', '0' ],
	'retained_service_attribute_mask'             => [ 'nagios', '0' ],
	'retained_process_service_attribute_mask'     => [ 'nagios', '0' ],
	'retained_contact_service_attribute_mask'     => [ 'nagios', '0' ],
    );

    # Handle any existing miscellaneous directives for the main configuration
    # that might already have a value set for one of the new options.
    $mission = 'Changing old miscellaneous directives to standard Nagios directives';
    foreach my $directive (keys %setup_misc_props) {
	if ( exists $new_options{$directive} ) {
	    if ( exists $setup_props{$directive} ) {
		## We have a conflict, namely both a standard directive and a miscellaneous directive of the
		## same name.  Take the value of the last one that we would have placed in the nagios.cfg file
		## (i.e., the miscellaneous directive), and use that because it's our best approximation to what
		## would have been the operational configuration without this adjustment.  But since we do have a
		## conflict, also emit a warning message to describe the conflict and how we are resolving it.
		$sqlstmt = "update setup set value=? where name=? and type=?";
		eval {
		    $sth = $dbh->prepare($sqlstmt);
		    $sth->execute( $setup_misc_props{$directive}{value}, $directive, $new_options{$directive}[0] );
		};
		if ($@) {
		    print "Error: $sqlstmt for\n    ('$setup_misc_props{$directive}{value}', '$directive', '$new_options{$directive}[0]'):\n$@\n";
		    die "FATAL:  $mission failed.\n";
		}
		$sth->finish;
		print "\n\tWARNING:  In the Nagios main configuration for the base product\n";
		print "\t          setup, the '$directive' value was defined\n";
		print "\t          both as a standard directive (with value '$setup_props{$directive}') and\n";
		print "\t          as a miscellaneous directive (with value '$setup_misc_props{$directive}{value}').\n";
		print "\t          The latter value will now be used as the value of the\n";
		print "\t          standard directive, while the miscellaneous directive\n";
		print "\t          definition itself has been destroyed.\n";
	    }
	    else {
		## We have a miscellaneous directive with no matching standard directive, where the
		## miscellaneous directive names a new option that should now be a standard directive.
		## Insert the new standard directive, using the value of the miscellaneous directive.
		$sqlstmt = "insert into setup values(?,?,?)";
		eval {
		    $sth = $dbh->prepare($sqlstmt);
		    $sth->execute( $directive, $new_options{$directive}[0], $setup_misc_props{$directive}{value} );
		};
		if ($@) {
		    print "Error: $sqlstmt for\n    ('$directive', '$new_options{$directive}[0]', '$setup_misc_props{$directive}{value}'):\n$@\n";
		    die "FATAL:  $mission failed.\n";
		}
		$sth->finish;
		## Now that we have the option established, don't try to add the option again below.
		$setup_props{$directive} = $setup_misc_props{$directive}{value};
	    }

	    # Destroy the miscellaneous directive, now that we have converted it to a standard directive.
	    $sqlstmt = "delete from setup where name=? and type='nagios_cfg_misc'";
	    eval {
		$sth = $dbh->prepare($sqlstmt);
		$sth->execute( $setup_misc_props{$directive}{misc_name} );
	    };
	    if ($@) {
		print "Error: $sqlstmt for\n    ('$setup_misc_props{$directive}{misc_name}'):\n$@\n";
		die "FATAL:  $mission failed.\n";
	    }
	    $sth->finish;
	}
    }

    # Do the same for groups as well, processing their own individual miscellaneous directives separately for each group.
    $mission = 'Changing old miscellaneous directives to standard Nagios directives in Monarch groups';
    foreach my $group_id (keys %group_misc_props) {
	foreach my $directive (keys %{ $group_misc_props{$group_id} } ) {
	    if ( exists $new_options{$directive} ) {
		my $type = $new_options{$directive}[0];    # just for readability
		## The "type" field in the monarch_group_props table has a different enumeration
		## than it does in the setup table, so we translate here.
		my $group_type = $type eq 'nagios' ? 'nagios_cfg' : $type eq 'nagios_cgi' ? 'nagios_cgi' : 'unknown';
		if ( $group_props{$group_id}{$directive} && exists $group_props{$group_id}{$directive}{$group_type} ) {
		    ## We have a conflict, namely both a standard directive and a miscellaneous directive of the
		    ## same name.  Take the value of the last one that we would have placed in the nagios.cfg file
		    ## (i.e., the miscellaneous directive), and use that because it's our best approximation to what
		    ## would have been the operational configuration without this adjustment.  But since we do have a
		    ## conflict, also emit a warning message to describe the conflict and how we are resolving it.
		    $sqlstmt = "update monarch_group_props set value=? where group_id=? and name=? and type=?";
		    eval {
			$sth = $dbh->prepare($sqlstmt);
			$sth->execute( $group_misc_props{$group_id}{$directive}, $group_id, $directive, $group_type );
		    };
		    if ($@) {
			print "Error: $sqlstmt for\n    ('$group_misc_props{$group_id}{$directive}', '$group_id', '$directive', '$group_type'):\n$@\n";
			die "FATAL:  $mission failed.\n";
		    }
		    $sth->finish;
		    my $group_name = $dbh->selectrow_array("select name from monarch_groups where group_id=$group_id");
		    print "\n\tWARNING:  In the Nagios main configuration for the '$group_name'\n";
		    print "\t          configuration group, the '$directive' value was defined\n";
		    print "\t          both as a standard directive (with value '$group_props{$group_id}{$directive}{$group_type}') and\n";
		    print "\t          as a miscellaneous directive (with value '$group_misc_props{$group_id}{$directive}').\n";
		    print "\t          The latter value will now be used as the value of the\n";
		    print "\t          standard directive, while the miscellaneous directive\n";
		    print "\t          definition itself has been destroyed.\n";
		}
		else {
		    ## We have a miscellaneous directive with no matching standard directive, where the
		    ## miscellaneous directive names a new option that should now be a standard directive.
		    ## Insert the new standard directive, using the value of the miscellaneous directive.
		    ## (We could have just updated the type field of the existing row, to avoid chewing up
		    ## an extra monarch_group_props.prop_id value.  Maybe in the future, we'll do that.)
		    $sqlstmt = "insert into monarch_group_props values(DEFAULT,?,?,?,?)";
		    eval {
			$sth = $dbh->prepare($sqlstmt);
			$sth->execute( $group_id, $directive, $group_type, $group_misc_props{$group_id}{$directive} );
		    };
		    if ($@) {
			print "Error: $sqlstmt for\n    ('$group_id', '$directive', 'group_type', '$group_misc_props{$group_id}{$directive}'):\n$@\n";
			die "FATAL:  $mission failed.\n";
		    }
		    $sth->finish;
		    ## Now that we have the option established, don't try to add the option again below.
		    $group_props{$group_id}{$directive}{$group_type} = $group_misc_props{$group_id}{$directive};
		}

		# Destroy the miscellaneous directive, now that we have converted it to a standard directive.
		$sqlstmt = "delete from monarch_group_props where group_id=? and name=? and type='nagios_cfg_misc'";
		eval {
		    $sth = $dbh->prepare($sqlstmt);
		    $sth->execute( $group_id, $directive );
		};
		if ($@) {
		    print "Error: $sqlstmt for\n    ('$group_id', '$directive'):\n$@\n";
		    die "FATAL:  $mission failed.\n";
		}
		$sth->finish;
	    }
	}
    }

    foreach my $option ( keys %new_options ) {
	my $type  = $new_options{$option}[0];    # just for readability
	my $value = $new_options{$option}[1];    # just for readability
	## The "type" field in the monarch_group_props table has a different enumeration
	## than it does in the setup table, so we translate here.
	my $group_type = $type eq 'nagios' ? 'nagios_cfg' : $type eq 'nagios_cgi' ? 'nagios_cgi' : 'unknown';

	$mission = 'Adding standard Nagios directives';
	$sqlstmt = "insert into setup values(?,?,?)";
	unless ( exists $setup_props{$option} ) {
	    eval {
		$sth = $dbh->prepare($sqlstmt);
		$sth->execute( $option, $type, $value );
	    };
	    if ($@) {
		print "Error: $sqlstmt for\n    ('$option', '$type', '$value'):\n$@\n";
		die "FATAL:  $mission failed.\n";
	    }
	    $sth->finish;
	    $setup_props{$option} = $value;
	}

	# Note that this section adds directives to all Monarch groups that are present in some form
	# in the monarch_group_props table, regardless of whether they actually serve as Linux child
	# servers and therefore might need such treatment.  That's not ideal but is tolerable because
	# the extraneous directives presumably won't have any operational effect.  Perhaps a future
	# version of this code could be more discriminating (using the same type of determination
	# that Monarch uses to set default values, namely the absence of the 'resource_file' option).
	# In this case, it would be the presence of that option that would cause us to insert these
	# new rows, as evidence that the Nagios config directives as a whole are present for the group.
	$mission = 'Adding standard Nagios directives to Monarch groups';
	$sqlstmt = "insert into monarch_group_props values(DEFAULT,?,?,?,?)";
	foreach my $group_id (@group_ids) {
	    unless ( exists $group_props{$group_id}{$option}{$group_type} ) {
		eval {
		    $sth = $dbh->prepare($sqlstmt);
		    $sth->execute( $group_id, $option, $group_type, $value );
		};
		if ($@) {
		    print "Error: $sqlstmt for\n    ('$group_id', '$option', '$group_type', '$value'):\n$@\n";
		    die "FATAL:  $mission failed.\n";
		}
		$sth->finish;
	    }
	}
    }
}

#-----------------------------------------------------------------------------
# GWMON-11182:  Change the performanceconfig.rrdcreatestring entry for the
# '^.+\..+' service-name pattern, which is used to support CloudHub metrics,
# to use an xff value ("xfiles factor") of 0.99 for RRAs instead of our usual
# value of 0.5 for this factor in most RRAs.
#-----------------------------------------------------------------------------

print "\nEditing performanceconfig entries, if needed ...\n";

# Correct RRA xff factors for newly created CloudHub metric RRD files, to better
# present possibly irregularly-collected data in graphs.
$dbh->do( "update performanceconfig "
  . "set rrdcreatestring = '\$RRDTOOL\$ create \$RRDNAME\$ --step 300 --start n-1yr DS:metric:GAUGE:1800:U:U RRA:AVERAGE:0.99:1:8640 RRA:AVERAGE:0.99:12:9480' "
  . "where service = '^.+\\..+' "
  . "and rrdcreatestring = '\$RRDTOOL\$ create \$RRDNAME\$ --step 300 --start n-1yr DS:metric:GAUGE:1800:U:U RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480'"
);

# Insert spaces at the end of each line in the CloudHub metric graphing command, for
# cleanliness (to match what we will have as seed data in a fresh GWMEE 7.0.1 install).
# These extra spaces are there both as general protection in case the initial space on
# each secondary line somehow gets dropped, and to make the overall command easier to
# read in psql output, separating the CR (\r) characters from the interesting text on
# each line.
$dbh->do( "update performanceconfig set graphcgi=regexp_replace(graphcgi, E'([^ ])\\r', E'\\\\1 \\r', 'g') where service = '^.+\\..+'" );

##############################################################################
# Data changes for the Monarch 4.3 => 4.4 transition
##############################################################################

#-----------------------------------------------------------------------------
# GWMON-11843:  Add the new Monarch max_unlocked_backups option.
#-----------------------------------------------------------------------------

print "\nAdding Monarch option \"max_unlocked_backups\", if not present ...\n";

idempotent_insert( 'setup', 'max_unlocked_backups', "('max_unlocked_backups', 'config', '10')" );

# FIX MAJOR:  Do we need the same adjustment for any Monarch Groups?  What happens to
# accumulated backup-during-commit files now on a child server when a build-instance
# and deploy action is initiated from the parent server?

#-----------------------------------------------------------------------------
# GWMON-11852:  Edit the Nagios temp_path option.
#-----------------------------------------------------------------------------

print "\nChanging Nagios option \"temp_path\", if previously set to /tmp ...\n";

# Change from '/tmp' to '/usr/local/nagios/tmp'.  Leave any other
# existing value alone.  Do this for parent and all child configurations.

$dbh->do("update setup set value = '/usr/local/nagios/tmp' where name = 'temp_path' and type = 'nagios' and value = '/tmp'");
$dbh->do("update monarch_group_props set value='/usr/local/nagios/tmp' where name='temp_path' and type='nagios_cfg' and value='/tmp'");

#-----------------------------------------------------------------------------
# * GWMON-11354:  Add support for the Nagios CGI result_limit directive.
#-----------------------------------------------------------------------------

print "\nAdding Nagios CGI option \"result_limit\", if not present ...\n";

idempotent_insert( 'setup', 'result_limit', "('result_limit', 'nagios_cgi', '75')" );

# The presence of the 'physical_html_path' directive for a given Monarch group is used as a proxy
# for believing that the whole set of Nagios CGI options is already set for the group.  This follows
# the same decision made in Monarch for similar purposes.
@group_ids = ();
$sqlstmt   = "select distinct group_id from monarch_group_props where name='physical_html_path'"
  . " and group_id not in (select group_id from monarch_group_props where name='result_limit')";
$sth = $dbh->prepare($sqlstmt);
$sth->execute();
while ( my @values = $sth->fetchrow_array() ) {
    push @group_ids, $values[0];
}
$sth->finish;

# Idempotency is tricky here, because we don't yet (but should) have a unique index on (group_id, name) on
# the monarch_group_props table.  Hence the qualification on group_id we performed via the subselect of the
# query above, to exclude Monarch groups that already have this directive set.
foreach my $group_id (@group_ids) {
    idempotent_insert( 'monarch_group_props', 'result_limit', "(DEFAULT, $group_id, 'result_limit', 'nagios_cgi', '75')" );
}

#-----------------------------------------------------------------------------
# * GWMON-11950:  Correct the RRD Update Command in the
#   performance-configuration entry for the aix_disk service.
#-----------------------------------------------------------------------------

print "\nCorrecting RRD Update commands in performance-config entries, if needed ...\n";

$dbh->do("update performanceconfig set rrdupdatestring = replace(rrdupdatestring, 'RRDTOOL\$', '\$RRDTOOL\$') where rrdupdatestring like 'RRDTOOL\$ %'");

#-----------------------------------------------------------------------------
# * GWMON-11951:  Correct the Custom RRD Graph Command in the
#   performance-configuration entry for several services.
#-----------------------------------------------------------------------------

print "\nCorrecting RRD Graph commands in performance-config entries, if needed ...\n";

$dbh->do("update performanceconfig set graphcgi = replace(graphcgi, 'ARROW#FFFFFF-Y', 'ARROW#FFFFFF -Y') where graphcgi like '%-c ARROW#FFFFFF-Y%'");

#-----------------------------------------------------------------------------
# * GWMON-11952:  Reformat all of the RRD commands in the
#   performance-configuration entries, to better display their structure.
#-----------------------------------------------------------------------------

if ($reformat_rrd_commands) {
    print "\nReformatting RRD commands in performance-config entries ...\n";

    my %perf_host = ();
    my %perf_serv = ();
    my %creat_cmd = ();
    my %updat_cmd = ();
    my %graph_cmd = ();
    $sqlstmt = "select performanceconfig_id, host, service, rrdcreatestring, rrdupdatestring, graphcgi from performanceconfig";
    $sth     = $dbh->prepare($sqlstmt);
    $sth->execute();

    while ( my @values = $sth->fetchrow_array() ) {
	$perf_host{ $values[0] } = $values[1];
	$perf_serv{ $values[0] } = $values[2];
	$creat_cmd{ $values[0] } = reformat_rrd_creat( $values[3] );
	$updat_cmd{ $values[0] } = reformat_rrd_updat( $values[4] );
	$graph_cmd{ $values[0] } = reformat_rrd_graph( $values[5] );
    }
    $sth->finish;

    my $mission = 'Reformatting RRD commands in performance-config entries';
    $sqlstmt = "update performanceconfig set rrdcreatestring = ?, rrdupdatestring = ?, graphcgi = ? where performanceconfig_id = ?";
    $sth     = $dbh->prepare($sqlstmt);
    foreach my $performanceconfig_id ( sort { $a <=> $b } keys %graph_cmd ) {
	eval {
	    $sth->execute(
		$creat_cmd{$performanceconfig_id}, $updat_cmd{$performanceconfig_id},
		$graph_cmd{$performanceconfig_id}, $performanceconfig_id
	    );
	};
	if ($@) {
	    print "Error: $sqlstmt for\n"
	      . "    performanceconfig_id $performanceconfig_id"
	      . " (host '$perf_host{$performanceconfig_id}', service '$perf_serv{$performanceconfig_id}'):\n"
	      . "$@\n";
	    die "FATAL:  $mission failed.\n";
	}
	$sth->finish;
    }
}

#-----------------------------------------------------------------------------
# * GWMON-10549:  Modify performance configuration definitions to take
#   advantage of $GRAPH_START_TIME$ and $GRAPH_END_TIME$ macros.  Also
#   add a standardized graph title if there is not one already present.
#-----------------------------------------------------------------------------

# $extend_rrd_commands depends on $reformat_rrd_commands because the latter strips any containing single
# quotes, which must not be present in order that the added COMMENT be part of the graph command.
if ( $reformat_rrd_commands && $extend_rrd_commands ) {
    print "\nAdding graph start/end labels to RRD Graph commands, if needed ...\n";

    my %perf_host = ();
    my %perf_serv = ();
    my %graph_cmd = ();
    $sqlstmt = "select performanceconfig_id, host, service, graphcgi from performanceconfig";
    $sth     = $dbh->prepare($sqlstmt);
    $sth->execute();

    ## FIX MAJOR:  Edit this list of text elements, to ensure that we have exactly the right set.
    my $text_element = qr{(?:AREA|COMMENT|GPRINT|HRULE|LINE[0-9]*|PRINT|SHIFT|STACK|TEXTALIGN|TICK|VRULE):};

    while ( my @values = $sth->fetchrow_array() ) {
	## In addition to testing for the absence of the $GRAPH_START_TIME reference,
	## we first have to make sure this is really otherwise a valid RRD graph command.
	## FIX MAJOR:  Extend this to support $RRDTOOL$ as well, once we support that
	## elsewhere in RRD graph commands.
	if ( $values[3] =~ /^rrdtool graph -/ ) {
	    if ( $values[3] !~ /\$GRAPH_START_TIME/ ) {
		## We also need to reach back to the last previous text element, and if it
		## doesn't end with a '\l' (or '\j' or '\n' or '\c'), add one there.
		##
		## For the moment, let's try to just add an intermediate comment to hold the
		## line break, and see if that suffices (the extra space before this extra
		## comment might itself insert an unwanted line break).  The biggest hassle is
		## if the immediately preceding text alement already ends with such a similar
		## escape sequence, in which case we don't want to add that here.
		##
		## FIX MAJOR:  Test this aspect.  Make sure we recognize all relevant escape
		## sequences that would cause a line break in the preceding text element.
		my $have_preceding_linebreak = 0;
		foreach my $line ( split( "\n", $values[3] ) ) {
		    if ( $line =~ /$text_element/o ) {
			$have_preceding_linebreak = $line =~ /\\l|\\j|\\n|\\c/;
		    }
		}
		my $linebreak = $have_preceding_linebreak ? '' : "\n" . 'COMMENT:"\\l"';
		$values[3] .= $linebreak . "\n" . 'COMMENT:"$GRAPH_START_TIME$ through $GRAPH_END_TIME$\\c"';
	    }
	    if ( $values[3] !~ /\s(--title|-t)(\s|=)/ ) {
		## FIX MAJOR:  Once we recognize $HOST$ and $SERVICE$ for substitutions
		## in RRD graph commands instead of HOST and SERVICE (there's a JIRA on
		## this), change the standardized title here to use the new formulation.
		$values[3] .= "\n" . '--pango-markup --title "<b>HOST: SERVICE</b>"';
	    }
	}
	$perf_host{ $values[0] } = $values[1];
	$perf_serv{ $values[0] } = $values[2];
	$graph_cmd{ $values[0] } = $values[3];
    }
    $sth->finish;

    my $mission = 'Adding graph start/end labels to graph commands in performance-config entries';
    $sqlstmt = "update performanceconfig set graphcgi = ? where performanceconfig_id = ?";
    $sth     = $dbh->prepare($sqlstmt);
    foreach my $performanceconfig_id ( sort { $a <=> $b } keys %graph_cmd ) {
	eval { $sth->execute( $graph_cmd{$performanceconfig_id}, $performanceconfig_id ); };
	if ($@) {
	    print "Error: $sqlstmt for\n"
	      . "    performanceconfig_id $performanceconfig_id"
	      . " (host '$perf_host{$performanceconfig_id}', service '$perf_serv{$performanceconfig_id}'):\n"
	      . "$@\n";
	    die "FATAL:  $mission failed.\n";
	}
	$sth->finish;
    }
}

#-----------------------------------------------------------------------------
# * GWMON-12000:  Clean up certain fields in performance configuration
#   definitions, to remove leading and/or trailing spaces.
#-----------------------------------------------------------------------------

print "\nCorrecting leading/trailing space in performance-config entries, if needed ...\n";

# Since we are possibly altering the UNIQUE CONSTRAINT fields of (host, service) here,
# there is an infinitesimally small but nonzero chance that we could have a collision
# during this editing (wherein the user has one entry with a padded field and another
# entry with an unpadded but otherwise identical field).  If that happens, the entries
# will need to be cleaned up manually, using Configuration > Performance > {entry} >
# Modify (or possibly Delete for some entries), before this script is run.
#
# FIX MINOR:  GWMON-12625, GWMON-12000:  Such a collison has actually happened at a
# customer site.  The adjustments here ought to be generalized to emit a descriptive
# error message instead of the current failure, which looks like this:
#
#     Error: Error running /usr/bin/perl
#         /usr/local/groundwork/monarch/bin/pg_migrate_monarch.pl:
#     DBD::Pg::db do failed: ERROR:  duplicate key value violates unique constraint
#         "performanceconfig_host_service_key"
#     DETAIL:  Key (host, service)=(*, ssh_disk_tsm_log) already exists. at
#         /usr/local/groundwork/monarch/bin/pg_migrate_monarch.pl line 2109.
#
# where the line number in question pointed to the "set service" adjustment just below,
# in the version of the script that was running at the time.  We perhaps ought to have
# a pre-upgrade tool to detect such problems, so they can be fixed beforehand and not
# generate a support case.  Or this code could be generalized to detect such collisions
# before they occur, and if there are no other important differences between the rows,
# do the cleanup automatically here.

$dbh->do("update performanceconfig set host    = btrim(host)    where host    like ' %' or host    like '% '");
$dbh->do("update performanceconfig set service = btrim(service) where service like ' %' or service like '% '");
$dbh->do("update performanceconfig set label   = btrim(label)   where label   like ' %' or label   like '% '");
$dbh->do("update performanceconfig set rrdname = btrim(rrdname) where rrdname like ' %' or rrdname like '% '");

#-----------------------------------------------------------------------------
# * GWMON-12068:  Add a new performance configuration entry to support
#   some common Open Daylight services monitored by GroundWork Net Hub.
#-----------------------------------------------------------------------------

idempotent_insert ('performanceconfig', 'Open Daylight Service',
"(DEFAULT, '*', '-(collisionCount|receive(Bytes|.+Error|Drops|Errors|Packets)|transmit(Bytes|Drops|Errors|Packets))\$',
'nagios', 1, NULL, 1, 'Open Daylight Service', '\$HOST\$_\$SERVICE\$.rrd',
'\$RRDTOOL\$ create \$RRDNAME\$ --step 300 --start n-1yr DS:metric:GAUGE:1800:U:U RRA:AVERAGE:0.99:1:8640 RRA:AVERAGE:0.99:12:9480',
'\$RRDTOOL\$ update \$RRDNAME\$ \$LASTCHECK\$:\$VALUE1\$ 2>&1',
'rrdtool graph - 
 DEF:a=\"rrd_source\":ds_source_0:AVERAGE 
 CDEF:cdefa=a 
 AREA:cdefa#0000FF:\"Network Switch Attribute\" 
 GPRINT:cdefa:MIN:min=%.2lf 
 GPRINT:cdefa:AVERAGE:avg=%.2lf 
 GPRINT:cdefa:MAX:max=%.2lf 
 -c BACK#FFFFFF 
 -c CANVAS#FFFFFF 
 -c GRID#C0C0C0 
 -c MGRID#404040 
 -c ARROW#FFFFFF 
 -Y --height 120 -l 0',
'', ' ')" );

##############################################################################
# Schema changes for the Monarch 4.4 => 4.5 transition
##############################################################################

# FIX MAJOR:  fill in this section with all known schema changes between 4.4 and 4.5;
# compare the actual monarch-db.sql content from different releases

#-----------------------------------------------------------------------------
# Extend the lengths of certain fields, to address problems seen both at
# customer sites and in QA testing.
#-----------------------------------------------------------------------------

# * GWMON-12679:  In the fresh-install setup, the stage_host_services.host field
#   has been modified to be a maximum of 255 characters instead of 50 characters,
#   to match the maximum length defined for similar fields in other tables.  This
#   same change must be made during an upgrade.
#
# * GWMON-12585:  In the fresh-install setup, the time_period_property.value field
#   has had its length extended from 255 to 400 characters.  This same change must
#   be made during an upgrade.

print "\nExtending columns in certain tables, if needed ...\n";

# While the initial conversions we want to run here are all just extensions of the
# max length of character varying fields, we define this conversion as generally
# as we can currently imagine, so this table of column conversions can be extended
# in the future with other transformations.
#
# That said, we don't currently handle any changes to the NOT NULL modifier for a column,
# since we have not yet seen the need for such a change to any column.  That property is
# recorded in the PostgreSQL information_schema.columns table as the separate is_nullable
# field, and if needed, would be handled in the following code by an additional optional
# "ALTER [ COLUMN ] column_name { SET | DROP } NOT NULL" clause in the ALTER TABLE command.

# There's nothing to convert if we simply give a varying field a larger maximum size.
my $extend_character_field = undef;

#                                                                                            new
#     table                   column   old type, old max len     new type, new max len     default  conversion
#     ----------------------  -------  ------------------------  ------------------------  -------  -----------------------
my @convert_to_4_5_column_types = (
    [ 'stage_host_services',  'host',  'character varying',  50, 'character varying', 255, undef,   $extend_character_field ],
    [ 'time_period_property', 'value', 'character varying', 255, 'character varying', 400, undef,   $extend_character_field ]
);

# This routine may be called from multiple places in this script.  If we need to
# extend it in any way, make sure that the specifications of the columns to convert
# are appropriately extended, for all calls.
#
sub convert_column_types {
    my $column_type_conversions = shift;

    foreach my $column_to_convert (@$column_type_conversions) {
	my $table       = $column_to_convert->[0];
	my $column      = $column_to_convert->[1];
	my $old_type    = $column_to_convert->[2];
	my $old_max_len = $column_to_convert->[3];
	my $new_type    = $column_to_convert->[4];
	my $new_max_len = $column_to_convert->[5];
	my $new_default = $column_to_convert->[6];
	my $conversion  = $column_to_convert->[7];

	$sqlstmt = "
	    select data_type, character_maximum_length, column_default
	    from information_schema.columns
	    where table_name = '$table'
	    and column_name = '$column'
	";
	my ( $data_type, $character_maximum_length, $column_default ) = $dbh->selectrow_array($sqlstmt);

	if ( $data_type eq $old_type && ( !defined($character_maximum_length) || $character_maximum_length == $old_max_len ) ) {
	    ## Note that because we will drop any old default value here, if we want to just
	    ## preserve an existing default value, we'll need to specify it in the table above.
	    if ( defined $column_default ) {
		$sqlstmt = "alter table \"$table\" alter column \"$column\" drop default";
		$dbh->do($sqlstmt);
	    }

	    $sqlstmt = "alter table \"$table\" alter column \"$column\" type $new_type" . ( defined($new_max_len) ? "($new_max_len)" : '' );
	    if ( defined $conversion ) {
		$conversion =~ s/{COLUMN}/"$column"/g;
		$sqlstmt .= " $conversion";
	    }
	    $dbh->do($sqlstmt);
	}

	if ( defined $new_default ) {
	    $sqlstmt = "alter table \"$table\" alter column \"$column\" set default $new_default";
	    $dbh->do($sqlstmt);
	}
    }
}

convert_column_types( \@convert_to_4_5_column_types );

##############################################################################
# Data changes for the Monarch 4.4 => 4.5 transition
##############################################################################

# FIX MAJOR:  fill in this section with all known data changes between 4.4 and 4.5;
# compare the actual monarch-seed.sql content from different releases

# In practice, no changes were made in this section for the Monarch 4.5 version.
# Any previously intended changes were deferred to the Monarch 4.6 version.

##############################################################################
# Schema changes for the Monarch 4.5 => 4.6 transition
##############################################################################

#-----------------------------------------------------------------------------
# * GWMON-13059:  Extend the width of the users.user_acct field to accommodate
#   significantly longer user names.
#-----------------------------------------------------------------------------

print "\nExtending columns in certain tables, if needed ...\n";

#                                                                               new
#     table    column       old type, old max len    new type, new max len    default  conversion
#     -------  -----------  -----------------------  -----------------------  -------  -----------------------
my @convert_to_4_6_column_types = (
    [ 'users', 'user_acct', 'character varying', 20, 'character varying', 50, undef,   $extend_character_field ]
);

convert_column_types( \@convert_to_4_6_column_types );

#-----------------------------------------------------------------------------
# * GWMON-13157:  Extend service-related tables to support externals
#   arguments.  to be substituted into service-externals patterns when
#   externals are built.
#-----------------------------------------------------------------------------

print "\nExtending tables to support externals arguments, if necessary ...\n";

# For the present time, we do not support externals arguments at the top level of the
# service-setup inheritance hierarchy, namely in service templates.  That is because we
# do not presently support service externals being associated with service templates.
# After all, the setting of externals arguments really only makes sense in the context
# of knowing what externals they will be substituted into.  If and when we do associate
# externals with service templates, that would be the time to add in such support.  And
# if we did that, we would need to support inheritance of externals setup, in whatever
# form we supply it, from a parent service template to any other service templates that
# use it as a base pattern with subsequent overrides.

# * The service_names table contains information on generic services, not in conjunction
#   with any particular host.
# * The services table contains information on host services, which are generic services
#   copied over to a particular host.  Host services can inherit setup data from the
#   service template assigned to that host service, 

my %add_externals_arguments_columns = (
    'service_names'    => { columns => [ [ 'externals_arguments', 'text', undef ] ] },
    'services'         => { columns => [ [ 'externals_arguments', 'text', undef ] ] },
    'service_instance' => { columns => [ [ 'externals_arguments', 'text', undef ] ] }
);

# Our model of externals_arguments inheritance is a bit complex, and whether or not we
# also add an inherit_ext_args column to each of those tables reflects that complexity.
#
# * Since we are not supporting service externals and externals arguments in service
#   templates, there is no upstream source for a generic service in the service_names
#   table to inherit from.  And thus we don't need a service_names.inherit_ext_args
#   column until some time in the future, if and when we do support externals and
#   externals arguments in service templates.  I don't particularly like the possible
#   asymmetry between table structures of possibly adding some other intermediate
#   column in the meantime, ending up with the externals_arguments and inherit_ext_args
#   columns not adjacent as they will be elsewhere, but I would rather not speculatively
#   add a column we won't be doing anything with at the preent time.
#
# * The purpose of service instances is really to have distinct actions take place for
#   the individual instances, so it only makes sense to inherit the multiple-instance
#   copy of externals arguments from the base-service copy of externals arguments if
#   there is some way to derive the special values for the instances completely from
#   macro substitution -- driven primarily by some macro that references the service
#   instance name suffix.  But we have the $INSTANCESUFFIX$ macro that will strip a
#   possible leading underscore from the service instance name suffix and return the
#   rest, and that provides exactly the one critical point of adaptability that can
#   make such inheritance very useful.  With that available, it does make sense to
#   have a service_instance.inherit_ext_args column in the database.

my %add_inherit_ext_args_columns = (
    'services'         => { columns => [ [ 'inherit_ext_args', 'smallint DEFAULT 1', undef ] ] },
    'service_instance' => { columns => [ [ 'inherit_ext_args', 'smallint DEFAULT 1', undef ] ] }
);

make_idempotent_column_changes( \%add_externals_arguments_columns );
make_idempotent_column_changes( \%add_inherit_ext_args_columns );

##############################################################################
# Data changes for the Monarch 4.5 => 4.6 transition
##############################################################################

# FIX MAJOR:  fill in this section with all known data changes between 4.5 and 4.6;
# compare the actual monarch-seed.sql content from different releases

#-----------------------------------------------------------------------------
# * GWMON-10303:  Ensure that Bronx is set up in Monarch.
#-----------------------------------------------------------------------------

print "\nSetting up Bronx in Monarch, if needed ...\n";

# It's highly unlikely that this fix is needed, since the issue it addresses
# dates back to old MySQL-era releases where the fields involved might not be
# populated.  Still, we now cover our bases here just in case.

# For the record:
#
# * broker_module was '/usr/local/nagios/modules/libbronx.so' for Nagios 2.x
# * broker_module was '/usr/local/groundwork/common/lib/libbronx.so'     for Nagios 3.x
# * event_broker_options should have always been -1 at least as long as it was set
#
# But we are going to ignore the situation in which the Nagios 2.x value of the
# broker_module option was used and might still be in place, because the last
# Nagios 2.x version wa shipped was with GWMEE 5.2.1, and it is highly unlikely
# that any long-term customer has not used some intermediate version between
# 5.3.0 and our current version since then.  Using such an intermediate version
# would have forced a correction to the value if it were present in the database
# but wrong for the running release, because Nagios would have failed to run.

# First, correct the situation for the current server's Nagios Main Configuration.

idempotent_insert( 'setup', 'broker_module',        "('broker_module', 'nagios', '/usr/local/nagios/lib/libbronx.so')" );
idempotent_insert( 'setup', 'event_broker_options', "('event_broker_options', 'nagios', '-1')" );

# We do the same idempotent insertions for Monarch Groups, at least for those
# that do have a Nagios Main Configuration established (such as would support
# Nagios running on a child server).  We make changes one option at a time,
# because of a missing index as explained below.

# The presence of the 'resource_file' directive for a given Monarch group is used as a proxy
# for believing that the whole set of Nagios Main Configuration options is already set for
# the group.  This follows the same decision made in Monarch for similar purposes.
@group_ids = ();
$sqlstmt   = "select distinct group_id from monarch_group_props where name='resource_file'"
  . " and group_id not in (select group_id from monarch_group_props where name='broker_module')";
$sth = $dbh->prepare($sqlstmt);
$sth->execute();
while ( my @values = $sth->fetchrow_array() ) {
    push @group_ids, $values[0];
}
$sth->finish;

# Idempotency is tricky here, because we don't yet (but should) have a unique index on (group_id, name) on
# the monarch_group_props table.  Hence the qualification on group_id we performed via the subselect of the
# query above, to exclude Monarch groups that already have this directive set.
foreach my $group_id (@group_ids) {
    idempotent_insert( 'monarch_group_props', 'broker_module',
	"(DEFAULT, $group_id, 'broker_module', 'nagios_cfg', '/usr/local/nagios/lib/libbronx.so')" );
}

# Lather, rinse, repeat, for the other Event-Broker related option.

@group_ids = ();
$sqlstmt   = "select distinct group_id from monarch_group_props where name='resource_file'"
  . " and group_id not in (select group_id from monarch_group_props where name='event_broker_options')";
$sth = $dbh->prepare($sqlstmt);
$sth->execute();
while ( my @values = $sth->fetchrow_array() ) {
    push @group_ids, $values[0];
}
$sth->finish;

foreach my $group_id (@group_ids) {
    idempotent_insert( 'monarch_group_props', 'event_broker_options',
	"(DEFAULT, $group_id, 'event_broker_options', 'nagios_cfg', '-1')" );
}

#-----------------------------------------------------------------------------
# * GWMON-10653:  Add host-notify-by-noma and service-notify-by-noma commands
#   to an existing Monarch deployment, if such commands do not already exist.
#   Also correct the alert_via_noma.pl -u, -t, and -A options if such commands
#   do already exist and these options are not specified correctly.
#-----------------------------------------------------------------------------

print "\nRepairing existing NoMa notification commands, if needed ...\n";

# The following string replacements are crude, in that they reach into the XML blob
# which contains the command line, and make interior modifications without unpacking
# and re-packing the blob.  But this construction is easy and should suffice.

$dbh->do( "
    update commands
    set data = regexp_replace(
	data,
	'(\\s+)-u(\\s+)\"\\\$(?:HOSTNOTIFICATIONID|HOSTPROBLEMID)\\\$\"',
	'\\1-u\\2\"\$\$(( \$HOSTPROBLEMID\$ ? \$HOSTPROBLEMID\$ : \$LASTHOSTPROBLEMID\$ ))\"',
	'g'
    )
    where name = 'host-notify-by-noma'
" );

$dbh->do( "
    update commands
    set data = regexp_replace(
	data,
	'(\\s+)-u(\\s+)\"\\\$(?:SERVICENOTIFICATIONID|SERVICEPROBLEMID)\\\$\"',
	'\\1-u\\2\"\$\$(( \$SERVICEPROBLEMID\$ ? \$SERVICEPROBLEMID\$ : \$LASTSERVICEPROBLEMID\$ ))\"',
	'g'
    )
    where name = 'service-notify-by-noma'
" );

$dbh->do( "
    update commands
    set data = regexp_replace(
	data,
	'(\\s+)-t(\\s+)\"\\\$SHORTDATETIME\\\$\"',
	'\\1-t\\2\"\$TIMET\$\"',
	'g'
    )
    where name in ('host-notify-by-noma', 'service-notify-by-noma')
" );

$dbh->do( "
    update commands
    set data = regexp_replace(
	data,
	'(\\s+)-A(\\s+)\"\\\$NOTIFICATIONAUTHORALIAS\\\$\"',
	'\\1-A\\2\"\$\$([ -n \"\$NOTIFICATIONAUTHORALIAS\$\" ] && echo \"\$NOTIFICATIONAUTHORALIAS\$\" || echo \"\$NOTIFICATIONAUTHOR\$\")\"',
	'g'
    )
    where name in ('host-notify-by-noma', 'service-notify-by-noma')
" );

print "\nAdding standard NoMa notification commands, if not already present ...\n";

idempotently_add_command( 'host-notify-by-noma', 'notify',
'/usr/local/groundwork/noma/notifier/alert_via_noma.pl -c h -s "$HOSTSTATE$" -H "$HOSTNAME$" -G "$HOSTGROUPNAMES$" -n "$NOTIFICATIONTYPE$" -i "$HOSTADDRESS$" -o "$HOSTOUTPUT$" -t "$TIMET$" -u "$$(( $HOSTPROBLEMID$ ? $HOSTPROBLEMID$ : $LASTHOSTPROBLEMID$ ))" -A "$$([ -n "$NOTIFICATIONAUTHORALIAS$" ] && echo "$NOTIFICATIONAUTHORALIAS$" || echo "$NOTIFICATIONAUTHOR$")" -C "$NOTIFICATIONCOMMENT$" -R "$NOTIFICATIONRECIPIENTS$"',
"# 'host-notify-by-noma' command definition"
);

idempotently_add_command( 'service-notify-by-noma', 'notify',
'/usr/local/groundwork/noma/notifier/alert_via_noma.pl -c s -s "$SERVICESTATE$" -H "$HOSTNAME$" -G "$HOSTGROUPNAMES$" -E "$SERVICEGROUPNAMES$" -S "$SERVICEDESC$" -o "$SERVICEOUTPUT$" -n "$NOTIFICATIONTYPE$" -a "$HOSTALIAS$" -i "$HOSTADDRESS$" -t "$TIMET$" -u "$$(( $SERVICEPROBLEMID$ ? $SERVICEPROBLEMID$ : $LASTSERVICEPROBLEMID$ ))" -A "$$([ -n "$NOTIFICATIONAUTHORALIAS$" ] && echo "$NOTIFICATIONAUTHORALIAS$" || echo "$NOTIFICATIONAUTHOR$")" -C "$NOTIFICATIONCOMMENT$" -R "$NOTIFICATIONRECIPIENTS$"',
"# 'service-notify-by-noma' command definition"
);

#-----------------------------------------------------------------------------
# * GWMON-13140:  Remove obsolete directives from our Monarch data, for both
#   parent and child servers.
#-----------------------------------------------------------------------------

print "\nDropping obsolete Nagios directives, if present ...\n";

$dbh->do( "delete from setup               where name = 'nagios_check_command' and type = 'nagios_cgi'" );
$dbh->do( "delete from monarch_group_props where name = 'nagios_check_command' and type = 'nagios_cgi'" );

# aggregate_status_updates was already obsoleted back in the MySQL days, but some
# back-end support got left in the Monarch code in a way that would plunk it back
# into the database.  Now the code has been corrected, so we remove it for good.
$dbh->do( "delete from setup               where name = 'aggregate_status_updates' and type = 'nagios'" );
$dbh->do( "delete from monarch_group_props where name = 'aggregate_status_updates' and type = 'nagios'" );

#-----------------------------------------------------------------------------
# * GWMON-13140:  Add support for several new directives to our Monarch data,
#   for just the parent server.  It will be up to the site to make such
#   adjustments for any child servers where these options might be relevant.
#-----------------------------------------------------------------------------

print "\nAdding new Nagios directives, if not present ...\n";

idempotent_insert( 'setup', 'ack_no_send',                                           "('ack_no_send',                                           'nagios_cgi', '0')" );
idempotent_insert( 'setup', 'ack_no_sticky',                                         "('ack_no_sticky',                                         'nagios_cgi', '0')" );
idempotent_insert( 'setup', 'authorized_contactgroup_for_all_host_commands',         "('authorized_contactgroup_for_all_host_commands',         'nagios_cgi', NULL)" );
idempotent_insert( 'setup', 'authorized_contactgroup_for_all_hosts',                 "('authorized_contactgroup_for_all_hosts',                 'nagios_cgi', NULL)" );
idempotent_insert( 'setup', 'authorized_contactgroup_for_all_service_commands',      "('authorized_contactgroup_for_all_service_commands',      'nagios_cgi', NULL)" );
idempotent_insert( 'setup', 'authorized_contactgroup_for_all_services',              "('authorized_contactgroup_for_all_services',              'nagios_cgi', NULL)" );
idempotent_insert( 'setup', 'authorized_contactgroup_for_configuration_information', "('authorized_contactgroup_for_configuration_information', 'nagios_cgi', NULL)" );
idempotent_insert( 'setup', 'authorized_contactgroup_for_read_only',                 "('authorized_contactgroup_for_read_only',                 'nagios_cgi', NULL)" );
idempotent_insert( 'setup', 'authorized_contactgroup_for_system_commands',           "('authorized_contactgroup_for_system_commands',           'nagios_cgi', NULL)" );
idempotent_insert( 'setup', 'authorized_contactgroup_for_system_information',        "('authorized_contactgroup_for_system_information',        'nagios_cgi', NULL)" );
idempotent_insert( 'setup', 'authorized_for_read_only',                              "('authorized_for_read_only',                              'nagios_cgi', NULL)" );
idempotent_insert( 'setup', 'normal_sound',                                          "('normal_sound',                                          'nagios_cgi', NULL)" );
idempotent_insert( 'setup', 'tac_cgi_hard_only',                                     "('tac_cgi_hard_only',                                     'nagios_cgi', '0')" );
idempotent_insert( 'setup', 'use_pending_states',                                    "('use_pending_states',                                    'nagios_cgi', '1')" );
idempotent_insert( 'setup', 'website_url',                                           "('website_url',                                           'nagios',     NULL)" );

#-----------------------------------------------------------------------------
# * UNKNOWN JIRA:  I believe a variety of extensions were previously made to
#   the content of the fresh-install performanceconfig table, in either the
#   7.1.0 or 7.1.1 release, or both.  Those same content changes must now be
#   made during an upgrade.
#-----------------------------------------------------------------------------

#-----------------------------------------------------------------------------
# * GWMON-12875:  Add a new service profile, along with companion commands,
#   services, and perf-config entries, for Windows WMIC support.
#-----------------------------------------------------------------------------

if (1) {
    print "\nAdding objects for Windows WMIC support, if not present ...\n";
    idempotently_add_profiles(
	'service',
	[
	    qw(
	      service-profile-Windows-WMIC-based-checks.xml
	      )
	]
    );
}

#-----------------------------------------------------------------------------
# * GWMON-13054:  Add a couple of new perfconfig entries to support both
#   Windows GDMA and Linux uptime plugins.
#-----------------------------------------------------------------------------

print "\nAdding perf-config entries for uptime plugins, if not present ...\n";

idempotent_insert ('performanceconfig', 'gdma_21_wmi_uptime',
"(DEFAULT, '*', 'gdma_21_wmi_uptime', 'nagios', '1', '1', '0', 'Windows Uptime', '\$HOST\$_\$SERVICE\$.rrd',
'\$RRDTOOL\$ create \$RRDNAME\$ --step 600 --start n-1yr DS:number:GAUGE:1800:U:U RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480',
'\$RRDTOOL\$ update \$RRDNAME\$ \$LASTCHECK\$:\$VALUE1\$ 2>&1',
'rrdtool graph - DEF:a=\"rrd_source\":ds_source_0:AVERAGE CDEF:cdefa=a AREA:cdefa#0000FF:\"Uptime in seconds\" GPRINT:cdefa:MIN:min=%.2lf GPRINT:cdefa:AVERAGE:avg=%.2lf GPRINT:cdefa:MAX:max=%.2lf  -c BACK#FFFFFF -c CANVAS#FFFFFF -c GRID#C0C0C0 -c MGRID#404040 -c ARROW#FFFFFF -Y --height 120 -l 0', '', '(\\d+)')" );

idempotent_insert ('performanceconfig', 'linux_uptime',
"(DEFAULT, '*', 'linux_uptime', 'nagios', '1', '1', '0', 'Linux Uptime', '\$HOST\$_\$SERVICE\$.rrd',
'\$RRDTOOL\$ create \$RRDNAME\$ --step 600 --start n-1yr DS:number:GAUGE:1800:U:U RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480',
'\$RRDTOOL\$ update \$RRDNAME\$ \$LASTCHECK\$:\$VALUE1\$ 2>&1',
'rrdtool graph - DEF:a=\"rrd_source\":ds_source_0:AVERAGE CDEF:cdefa=a AREA:cdefa#0000FF:\"Uptime in seconds\" GPRINT:cdefa:MIN:min=%.2lf GPRINT:cdefa:AVERAGE:avg=%.2lf GPRINT:cdefa:MAX:max=%.2lf  -c BACK#FFFFFF -c CANVAS#FFFFFF -c GRID#C0C0C0 -c MGRID#404040 -c ARROW#FFFFFF -Y --height 120 -l 0', '', '(\\d+)')" );

#-----------------------------------------------------------------------------
# * GWMON-12978:  Add new service profiles for Grafana Server and InfluxDB.
#-----------------------------------------------------------------------------

if (1) {
    print "\nAdding service profiles for Grafana Server and InfluxDB, if not present ...\n";
    idempotently_add_profiles(
	'service',
	[
	    qw(
	      service-profile-grafana-server.xml
	      service-profile-influxdb.xml
	      )
	]
    );
}

#-----------------------------------------------------------------------------
# * CLOUDHUB-179, GWMON-12373, GWMON-12379:  Review previous changes to
#   Monarch seed data to ensure that they are reflected in similar changes
#   during a migration, whether that be by adding new entries or modifying
#   existing entries.
#-----------------------------------------------------------------------------

##############################################################################
# Schema changes for the Monarch 4.6 => 4.7 transition
##############################################################################

#-----------------------------------------------------------------------------
# * GWMON-10199:  Change two column types in the monarch_group_props table.
#   The column type for "type" should change from "character varying(20)" to
#   "character varying(50)", and the column type for "value" should change
#   from "character varying(1020)" to "text".
#-----------------------------------------------------------------------------

# FIX MAJOR:  This schema change is not yet implemented.

#-----------------------------------------------------------------------------
# * GWMON-13438:  Change the type of the hosts.address field from
#   "character varying(50)" to "character varying(255)", to match the
#   maximum width of the hosts.name field.
#-----------------------------------------------------------------------------

# FIX MAJOR:  This schema change is not yet implemented.

##############################################################################
# Data changes for the Monarch 4.6 => 4.7 transition
##############################################################################

#-----------------------------------------------------------------------------
# * Bump up the nagios_version from "3.x" to "4.x", in conjunction with
#   changes in Monarch itself to better support either new options in
#   Nagios 4, or any changes required because of upstream changes in Nagios
#   4.4.0, 4.4.1, or later.
#-----------------------------------------------------------------------------

# FIX MAJOR:  This data change is not yet implemented.

##############################################################################
# Committing Changes
##############################################################################

print "\nUpdating the monarch_version value to the current release level ...\n";

# After everything else is done, update our proxy flag for all the other changes made above.
$dbh->do( "update setup set value = '$monarch_version' where name = 'monarch_version' and type = 'config'" );

print "\nCommitting all changes ...\n";

# Commit all previous changes.  Note that some earlier commands may have performed
# implicit commit operations, which is why the very first change we made above was
# to modify the Monarch version number at the start of the script to something that
# would show that we were only partially done migrating the database schema and content.
# There is not much of anything we can do about those implicit commits; there is no
# good way to roll back automatically if some part of the operations that perform
# such implicit commits should fail.  If we find a negative Monarch version number
# after running this script, we know the migration is not completely done.
$dbh->commit();

# Disconnect from the database, and undefine our database handle, so we don't get
# our "Rolling back ..." message from the trailing END block if we really did just
# successfully run the commit.
do {
    ## Localize and turn off RaiseError for this block, because once we have
    ## successfully committed all changes just above, we really don't care if
    ## we somehow get an error during the disconnect operation.
    local $dbh->{RaiseError};

    $dbh->disconnect();
    $dbh = undef;
};

##############################################################################
# Done.
##############################################################################

$all_is_done = 1;

END {
    if ($dbh) {
	## Roll back any uncommitted transaction.  If the $dbh->commit() above did
	## not execute (which should generally be the only way we get here), this
	## will either roll back to the state of the database before this script was
	## run, or (if our enclosing transaction was broken by some earlier implicit
	## commit) it should leave the Monarch version in a state (that is, having
	## a negative value) where we can later see that the full migration did not
	## complete, so there is no confusion as to whether the database is in a
	## usable state.
	print "\nRolling back changes ...\n";
	eval {
	    $dbh->rollback();
	};
	if ($@) {
	    ## For some reason, $dbh->errstr here returns a value from far earlier in the script,
	    ## not reflecting what just failed within this eval{};.  So we need to look instead
	    # at $@ instead for clues as to what just happened.
	    my $errstr = $@;
	    print "\nERROR:  rollback failed", (defined($errstr) ? (":\n" . $errstr) : '; no error detail is available.'), "\n";
	    print "WARNING:  The Monarch database has probably been left in an inconsistent, unusable state.\n";
	}
	else {
	    eval {
		my $sqlstmt = "select value from setup where name = 'monarch_version' and type = 'config'";
		my ($final_monarch_version) = $dbh->selectrow_array($sqlstmt);

		# If the migration had completed successfully, the monarch_version value would have
		# been updated to be the target Monarch version.  Conversely, if the rollback got
		# us all the way back to where we were when we started, we ought to have a standard
		# useable copy of the monarch_version value, even if it is not the current target
		# release.  If not, which is to say either that we didn't start with a fully usable
		# database, or that some implicit commit along the way destroyed our ability to
		# roll back to where we were when we started, the transient value will remain as an
		# indicator to later users of the database that the schema and/or content is in bad
		# shape.  We may as well report that condition now to the user, to avoid confusion.
		if ( !defined($final_monarch_version) or length($final_monarch_version) == 0 or $final_monarch_version =~ /^-/ ) {
		    print "FATAL:  The Monarch database has been left in an inconsistent, unusable state.\n";
		}
	    };
	    if ($@) {
		my $errstr = $@;
		print "\nERROR:  Cannot verify the final Monarch version",
		  ( defined($errstr) ? ( ":\n" . $errstr ) : '; no error detail is available.' ), "\n";
	    }
	}
	$dbh->disconnect();
    }
    if (!$all_is_done) {
	print "\n";
	print "====================================================================\n";
	print "    WARNING:  monarch database migration did not fully complete!\n";
	print "====================================================================\n";
	print "\n";
	exit (1);
    }
}

print "\nUpdate of the monarch database is complete.\n\n";

