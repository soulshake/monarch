#!/usr/local/groundwork/perl/bin/perl
## @file dassmonarch.pm
# Implementation of class dassmonarch
# @brief
# dass IT's interface to monarch
# @author
# Maik Aussendorf
# @version
# \$Id: dassmonarch.pm 42 2018-02-06 13:41:10 PST gherteg $
#
# Copyright (c) 2007-2018
# Maik Aussendorf <maik.aussendorf@dass-it.de> dass IT GmbH
# With modifications by GroundWork Open Source, Inc.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the
#    Free Software Foundation, Inc.
#    59 Temple Place, Suite 330
#    Boston, MA 02111-1307 USA
#

BEGIN {
    unshift @INC, '/usr/local/groundwork/core/monarch/lib';
}

use strict;
use monarchWrapper;
use gwxml;
use Data::Dumper;

## @class
# This class provides methods related to the installed GroundWork
# system like determining GroundWork's release version, etc.
# This version is for use with GW Monitor 6.2 and later releases ONLY.
# @brief Helper class to get information about the installed system
package GWHelper;

use IO::File;

my @FILES = ('/usr/local/groundwork/Info.txt');

## @method string gwbuild (void)
# @return Groundwork build string, empty if not deduceable
sub gwbuild {
    my $build = '';
  SEARCH: foreach my $fname (@FILES) {
	my $fh = new IO::File( $fname, 'r' );
	next if !$fh;
	while ( my $line = $fh->getline() ) {
	    if ( $line =~ /Core\s+\.+\s+(.*)/ ) {
		$build = $1;
		last;
	    }
	}
	$fh->close();
	last if $build;
    }
    return $build;
}

## @method string gwversion (void)
# @return Groundwork version string, empty if not deduceable
sub gwversion {
    my $version = gwbuild();
    if ( $version =~ /(.*?)-/ ) {
	$version = $1;
    }
    return $version;
}

1;

## @class
# This class provides methods to access the monarch database to automatically import and manage configuration data.
# A fair number of these routines can be called in either scalar or list context.  In such cases, the method prototype
# lists only the most common usage.  The description of the method return value gives more detail on how the returned
# data changes with the calling context.
#
# Also note that database errors may occur at any time, for reasons unrelated to this package.  A calling application
# must be aware of that possibility, and be able to recognize when intended operations have not completed as planned.
# To that end, most routines in this package will return undef (in scalar context) or an empty list (in list context)
# when a database error occurs.  An undef in scalar context is sufficiently distinctive that it usually signals
# unambiguously that a failure has occurred.  An empty list might or might not be sufficiently distinctive to conclude
# that a failure has occurred; that depends on the nature of the method being called.  Application code must be
# written to be vigilant about testing returned values and responding accordingly.
# @brief Access monarch
package dassmonarch;

# BE SURE TO KEEP THIS UP-TO-DATE.
# By convention, a Monarch version number is "X.Y".  A dassmonarch version
# originally based on that Monarch version will be labeled as "X.Y.Z", where
# Z will be incremented as necessary.
my $VERSION = '4.4.2';

# Description of debuglevels
my %debug_level = ( none => 0, error => 1, warning => 2, info => 3, verbose => 4 );

my $max_external_description_length = 50;

## @cmethod object new (void)
# @return the new object, or die trying (meaning, you'd better encapsulate your call inside eval{};)
sub new {
    my $invocant = shift;
    my $class = ref($invocant) || $invocant;

    my $VERSION_vstring = pack( 'U*', split( /\./, $VERSION ) );
    my $self = {
	dassmonarch_ver     => $VERSION,
	dassmonarch_vstring => $VERSION_vstring,
	debuglevel          => $debug_level{'verbose'},

	# user_acct Username used for comment in generated nagios config files.
	user_acct        => 'script',
	nagios_ver       => '3.x',
	nagios_etc       => '/usr/local/groundwork/nagios/etc',
	nagios_bin       => '/usr/local/groundwork/nagios/bin/',
	monarch_home     => '/usr/local/groundwork/core/monarch',
	backup_dir       => '/usr/local/groundwork/core/monarch/backup',
	commit_ok_string => 'Synchronization with Foundation completed successfully.',

	# limit_sql since GW 5.2 the monarch search function uses a result limit of 25 by default,
	# will be overridden by this limit_sql
	limit_sql => 10000000,
	debugmsg  => '',
	errormsg  => '',
    };
    ## We bless early, to force a DESTROY (to force a disconnect) if the following code throws an exception.
    bless( $self, $class );

    if ( GWHelper::gwversion() =~ /^v5\.[0-2]\./ || GWHelper::gwversion() =~ /^v[0-4]\./ ) {
	$self->{'nagios_ver'}   = '2.x';
	$self->{'monarch_home'} = '/usr/local/groundwork/monarch';
    }

    # See http://stackoverflow.com/questions/1498042/should-a-perl-constructor-return-an-undef-or-a-invalid-object
    # for a good discussion about how to handle constructor errors.
    my $auth = monarchWrapper->dbconnect();

    my %results = ();
    eval {
	%results = monarchWrapper->fetch_one( 'setup', 'name', 'monarch_version' );
    };
    if ($@) {
	chomp $@;
	die "database access error in dassmonarch::new(): $@\n";
    }

    # Later logic that depends on the Monarch version would fail if it is not available.
    die "Monarch version is not available.\n" if not $results{value};

    my $monarch_version = $results{value};
    my $monarch_vstring = pack( 'U*', split( /\./, $monarch_version ) );

    $self->{'monarch_ver'}     = $monarch_version;
    $self->{'monarch_vstring'} = $monarch_vstring;

    return $self;
}

## @cmethod void DESTROY (void)
# Destructor, closes database connection to monarch.
# Will be called automatically by interpreter, when object goes out of scope or program ends.
sub DESTROY {
    my $self = shift;
    $self->debug( 'info', 'Closing DB handle to Monarch DB' );
    monarchWrapper->disconnect();
}

## @method boolean set_debuglevel (string newlevel)
# Set a new dassmonarch logging debug level.
# @param newlevel the new debuglevel, one of 'error', 'warning', 'info', or 'verbose'
# @return void
sub set_debuglevel {
    my $self     = shift;
    my $newlevel = $_[0];
    $self->{'debuglevel'} = $debug_level{$newlevel};
    if ( !$debug_level{$newlevel} ) { $self->{'debuglevel'} = $debug_level{'none'}; }
}

## @method int get_debuglevel (void)
# Get the dassmonarch logging debug level as an integer.
# @return debuglevel: the current logging level of the dassmonarch package
sub get_debuglevel {
    my $self = shift;
    return $self->{'debuglevel'};
}

## @method void debug (string msglevel, string message)
# Print a debug message to stderr, if it reaches current debuglevel.
# @param msglevel one of 'error', 'warning', 'info', or 'verbose'
# @param message the debug message; will be printed out if msglevel is above the general debuglevel
# @return nothing
sub debug {
    my $self     = shift;
    my $msglevel = $_[0];
    my $message  = $_[1];
    if ( $debug_level{$msglevel} <= $self->{'debuglevel'} ) {
	$self->{'debugmsg'} .= "debug ($msglevel) $message\n";
	print STDERR "($msglevel) $message\n";
    }
    if ( $msglevel eq 'error' ) {
	$self->{'errormsg'} .= "($msglevel) $message\n";
    }
}

## @method string get_debugmessages (void)
# Get all debug messages generated since instantiation.
# @return debugmsg containing all debug messages
sub get_debugmessages {
    my $self = shift;
    return $self->{'debugmsg'};
}

## @method string get_errormessages (void)
# Get all error messages generated since instantiation.
# @return errormsg containing all error messages
sub get_errormessages {
    my $self = shift;
    return $self->{'errormsg'};
}

## @method string dassmonarch_version (void)
# Get the dassmonarch version found by the constructor.
# @return Full dassmonarch version as a string.
sub dassmonarch_version {
    my $self = shift;
    return $self->{'dassmonarch_ver'};
}

## @method vstring dassmonarch_vstring (void)
# Get the dassmonarch version Perl vstring manufactured by the constructor.
# @return dassmonarch version as a Perl vstring.
sub dassmonarch_vstring {
    my $self = shift;
    return $self->{'dassmonarch_vstring'};
}

## @method string monarch_version (void)
# Get the Monarch version found by the constructor.
# @return Full Monarch version as a string.
sub monarch_version {
    my $self = shift;
    return $self->{'monarch_ver'};
}

## @method vstring monarch_vstring (void)
# Get the Monarch version Perl vstring manufactured by the constructor.
# @return Monarch version as a Perl vstring.
sub monarch_vstring {
    my $self = shift;
    return $self->{'monarch_vstring'};
}

## @method string nagios_version (void)
# Get the nagios version used in constructor.
# @return Nagios major version.
sub nagios_version {
    my $self = shift;
    return $self->{'nagios_ver'};
}

## @method boolean update_or_insert_obj (string table, string searchcolumn, string searchvalue, hashref valref)
# Update a database object, or create it if it does not yet exist.
# This method is intended for internal use within dassmonarch, and should not be used directly by applications.
# @param table table to operate on
# @param searchcolumn column to use for searching
# @param searchvalue value to search for in searchcolumn
# @param valref hashreference for key/value pairs
# @return status: true if successful, false otherwise
sub update_or_insert_obj {
    my $self         = shift;
    my $table        = $_[0];
    my $searchcolumn = $_[1];
    my $searchvalue  = $_[2];
    my $valref       = $_[3];
    my $returnvalue;
    my %vals = %$valref;

    # check if entry exists
    my %results = ();
    eval {
	%results = monarchWrapper->fetch_one( $table, $searchcolumn, $searchvalue );
    };
    if ($@) {
	$self->debug( 'error', "database access error in update_or_insert_obj($table, $searchcolumn, $searchvalue, ...)" );
	return undef;
    }
    if (%results) {
	$self->debug( 'verbose', "entry found with $searchvalue in column $searchcolumn of table $table" );
	$returnvalue = monarchWrapper->update_obj( $table, $searchcolumn, $searchvalue, %vals );
	if ( $returnvalue ne '1' ) {
	    $self->debug( 'error', "updating object failed: $returnvalue" );
	    return 0;
	}
    }
    else {
	$self->debug( 'verbose', "No entry found with $searchvalue in column $searchcolumn of table $table" );
    }
    return 1;
}

## @method boolean or hash host_exists (string hostname)
# Find out if a hostname exists.
# @param hostname name of the host to search for
# @return status: in scalar context, true if the host exists, false if the host does not exist,
# or undef if an error occurs, which makes it easy to distinguish an error condition;
# in list context, a hash of the host properties, or an empty list if an error occurs
# (which is indistinguishable from having no such host, so this mode of calling is not robust)
sub host_exists {
    my $self     = shift;
    my $hostname = $_[0];
    my %properties = ();
    eval {
	%properties = monarchWrapper->fetch_one( 'hosts', 'name', $hostname );
    };
    if ($@) {
	$self->debug( 'error', "database access error in host_exists($hostname)" );
	return wantarray ? () : undef;
    }
    return %properties;
}

## @method boolean or hash hostgroup_exists (string hostgroupname)
# Find out if a hostgroup exists.
# @param hostgroupname name of the hostgroup to search for
# @return status: in scalar context, true if the hostgroup exists, false if the hostgroup does
# not exist, or undef if an error occurs, which makes it easy to distinguish an error condition;
# in list context, a hash of the hostgroup properties, or an empty list if an error occurs
# (which is indistinguishable from having no such hostgroup, so this mode of calling is not robust)
sub hostgroup_exists {
    my $self          = shift;
    my $hostgroupname = $_[0];
    my %properties = ();
    eval {
	%properties = monarchWrapper->fetch_one( 'hostgroups', 'name', $hostgroupname );
    };
    if ($@) {
	$self->debug( 'error', "database access error in hostgroup_exists($hostgroupname)" );
	return wantarray ? () : undef;
    }
    return %properties;
}

## @method boolean or hash service_exists (string servicename)
# Find out if a servicename exists.
# @param servicename name of the generic service to search for
# @return status: in scalar context, true if the service exists, false if the service does
# not exist, or undef if an error occurs, which makes it easy to distinguish an error condition;
# in list context, a hash of the service properties, or an empty list if an error occurs
# (which is indistinguishable from having no such service, so this mode of calling is not robust)
sub service_exists {
    my $self        = shift;
    my $servicename = $_[0];
    my %properties = ();
    eval {
	%properties = monarchWrapper->fetch_one( 'service_names', 'name', $servicename );
    };
    if ($@) {
	$self->debug( 'error', "database access error in service_exists($servicename)" );
	return wantarray ? () : undef;
    }
    return %properties;
}

## @method boolean or hash servicegroup_exists (string servicegroupname)
# Find out if a servicegroup exists.
# @param servicegroupname name of the servicegroup to search for
# @return status: in scalar context, true if the servicegroup exists, false if the servicegroup does
# not exist, or undef if an error occurs, which makes it easy to distinguish an error condition;
# in list context, a hash of the servicegroup properties, or an empty list if an error occurs
# (which is indistinguishable from having no such servicegroup, so this mode of calling is not robust)
sub servicegroup_exists {
    my $self             = shift;
    my $servicegroupname = $_[0];
    my %properties = ();
    eval {
	%properties = monarchWrapper->fetch_one( 'servicegroups', 'name', $servicegroupname );
    };
    if ($@) {
	$self->debug( 'error', "database access error in servicegroup_exists($servicegroupname)" );
	return wantarray ? () : undef;
    }
    return %properties;
}

## @method boolean or hash host_extinfo_template_exists (string templatename)
# Find out if a given host extended info template already exists.
# @param templatename name of the host extended info template to search for
# @return status: in scalar context, true if the template exists, false if the template does
# not exist, or undef if an error occurs, which makes it easy to distinguish an error condition;
# in list context, a hash of the template properties, or an empty list if an error occurs
# (which is indistinguishable from having no such template, so this mode of calling is not robust)
sub host_extinfo_template_exists {
    my $self         = shift;
    my $templatename = $_[0];
    my %properties = ();
    eval {
	%properties = monarchWrapper->fetch_one( 'extended_host_info_templates', 'name', $templatename );
    };
    if ($@) {
	$self->debug( 'error', "database access error in host_extinfo_template_exists($templatename)" );
	return wantarray ? () : undef;
    }
    return %properties;
}

## @method boolean or hash service_extinfo_template_exists (string templatename)
# Find out if a given service extended info template already exists.
# @param templatename name of the service extended info template to search for
# @return status: in scalar context, true if the template exists, false if the template does
# not exist, or undef if an error occurs, which makes it easy to distinguish an error condition;
# in list context, a hash of the template properties, or an empty list if an error occurs
# (which is indistinguishable from having no such template, so this mode of calling is not robust)
sub service_extinfo_template_exists {
    my $self         = shift;
    my $templatename = $_[0];
    my %properties = ();
    eval {
	%properties = monarchWrapper->fetch_one( 'extended_service_info_templates', 'name', $templatename );
    };
    if ($@) {
	$self->debug( 'error', "database access error in service_extinfo_template_exists($templatename)" );
	return wantarray ? () : undef;
    }
    return %properties;
}

## @method boolean or hash monarch_group_exists (string monarch_group)
# Find out if a given Monarch Group already exists.
# @param monarch_group name of the Monarch Group to search for
# @return status: in scalar context, true if the Monarch Group exists, false if the Monarch Group does
# not exist, or undef if an error occurs, which makes it easy to distinguish an error condition;
# in list context, a hash of the Monarch Group properties, or an empty list if an error occurs
# (which is indistinguishable from having no such Monarch Group, so this mode of calling is not robust)
sub monarch_group_exists {
    my $self          = shift;
    my $monarch_group = $_[0];
    my %properties = ();
    eval {
	%properties = monarchWrapper->fetch_one( 'monarch_groups', 'name', $monarch_group );
    };
    if ($@) {
	$self->debug( 'error', "database access error in monarch_group_exists($monarch_group)" );
	return wantarray ? () : undef;
    }
    return %properties;
}

## @method int get_host_template_id (string host_template)
# Search for a hosttemplate_id in monarch table host_templates.
# @param host_template name of the hosttemplate to search for
# @return hosttemplate_id: > 0 if the host template exists;
# otherwise, 0 if the search succeeded (but found nothing), undef if the search failed (e.g., due to database error)
sub get_host_template_id {
    my $self          = shift;
    my $host_template = $_[0];
    $self->debug( 'verbose', "called get_host_template_id with $host_template" );

    my %results;
    eval {
	my %where = ( 'name' => $host_template );
	%results = monarchWrapper->fetch_one_where( 'host_templates', \%where );
    };
    if ($@) {
	$self->debug( 'error', "database access error in get_host_template_id($host_template)" );
	return undef;
    }
    return $results{'hosttemplate_id'} || 0;
}

## @method int get_service_template_id (string service_template)
# Search for a servicetemplate_id in monarch table service_templates.
# @param service_template name of the servicetemplate to search for
# @return servicetemplate_id: > 0 if the service template exists;
# otherwise, 0 if the search succeeded (but found nothing), undef if the search failed (e.g., due to database error)
sub get_service_template_id {
    my $self             = shift;
    my $service_template = $_[0];
    $self->debug( 'verbose', "called get_service_template_id with $service_template" );

    my %results;
    eval {
	my %where = ( 'name' => $service_template );
	%results = monarchWrapper->fetch_one_where( 'service_templates', \%where );
    };
    if ($@) {
	$self->debug( 'error', "database access error in get_service_template_id($service_template)" );
	return undef;
    }
    return $results{'servicetemplate_id'} || 0;
}

## @method int get_hostprofileid (string hostprofilename)
# Find the hostprofile_id for a named hostprofile.
# @param hostprofilename name of the host profile to search for
# @return hostprofile_id: > 0 if the host profile exists;
# otherwise, 0 if the search succeeded (but found nothing), undef if the search failed (e.g., due to database error)
sub get_hostprofileid {
    my $self            = shift;
    my $hostprofilename = $_[0];
    $self->debug( 'verbose', "called get_hostprofileid($hostprofilename)" );
    my %results = ();
    eval {
	%results = monarchWrapper->fetch_one( 'profiles_host', 'name', $hostprofilename );
    };
    if ($@) {
	$self->debug( 'error', "database access error in get_hostprofileid($hostprofilename)" );
	return undef;
    }
    return $results{'hostprofile_id'} || 0;
}

## @method int get_serviceprofileid (string serviceprofilename)
# Find the serviceprofile_id for a named serviceprofile.
# @param serviceprofilename name of the service profile to look for
# @return serviceprofile_id: > 0 if the service profile exists;
# otherwise, 0 if the search succeeded (but found nothing), undef if the search failed (e.g., due to database error)
sub get_serviceprofileid {
    my $self               = shift;
    my $serviceprofilename = $_[0];
    $self->debug( 'verbose', "called get_serviceprofileid($serviceprofilename)" );
    my %results = ();
    eval {
	%results = monarchWrapper->fetch_one( 'profiles_service', 'name', $serviceprofilename );
    };
    if ($@) {
	$self->debug( 'error', "database access error in get_serviceprofileid($serviceprofilename)" );
	return undef;
    }
    return $results{'serviceprofile_id'} || 0;
}

## @method int get_serviceid (string servicename)
# Find the servicename_id for a named generic service.
# @param servicename name of the generic service to search for
# @return servicename_id from table service_names, > 0 if the service exists;
# otherwise, 0 if the search succeeded (but found nothing), undef if the search failed (e.g., due to database error)
sub get_serviceid {
    my $self        = shift;
    my $servicename = $_[0];
    my %results     = ();
    eval {
	%results = monarchWrapper->fetch_one( 'service_names', 'name', $servicename );
    };
    if ($@) {
	$self->debug( 'error', "database access error in get_serviceid($servicename)" );
	return undef;
    }
    return $results{'servicename_id'} || 0;
}

## @method int get_hostid (string hostname)
# Find the host_id for a named host.
# @param hostname name of the host to search for
# @return host_id from table hosts, > 0 if the host exists;
# otherwise, 0 if the search succeeded (but found nothing), undef if the search failed (e.g., due to database error)
sub get_hostid {
    my $self     = shift;
    my $hostname = $_[0];
    $self->debug( 'verbose', "called get_hostid($hostname)" );
    my %results = ();
    eval {
	%results = monarchWrapper->fetch_one( 'hosts', 'name', $hostname );
    };
    if ($@) {
	$self->debug( 'error', "database access error in get_hostid($hostname)" );
	return undef;
    }
    return $results{'host_id'} || 0;
}

## @method int get_host_serviceid (string hostname, string servicename)
# Get the database ID of a host / service entry in monarch table services.
# @param hostname name of the host to search for
# @param servicename name of the host service to search for
# @return service_id from table services, > 0 if the host service exists;
# otherwise, 0 if the search succeeded (but found nothing), undef if the search failed (e.g., due to database error)
sub get_host_serviceid {
    my $self        = shift;
    my $hostname    = $_[0];
    my $servicename = $_[1];
    $self->debug( 'verbose', "called get_host_serviceid($hostname, $servicename)" );

    my $hostid = undef;    # must declare separately to avoid ref of global var inside do{}
    $hostid = $self->get_hostid($hostname) or do {
	$self->debug( 'warning', "host $hostname not found" );
	return $hostid;    # either 0 or undef
    };
    $self->debug( 'verbose', "found id $hostid for host $hostname" );

    my $servicename_id = undef;    # must declare separately to avoid ref of global var inside do{}
    $servicename_id = $self->get_serviceid($servicename) or do {
	$self->debug( 'warning', "service $servicename not found" );
	return $servicename_id;    # either 0 or undef
    };

    my %results = ();
    eval {
	my %where = ( 'host_id' => $hostid, 'servicename_id' => $servicename_id );
	%results = monarchWrapper->fetch_one_where( 'services', \%where );
    };
    if ($@) {
	$self->debug( 'error', "database access error in get_host_serviceid($hostname, $servicename)" );
	return undef;
    }
    $self->debug( 'verbose', "got id: $results{'service_id'}\n" );
    return $results{'service_id'} || 0;
}

## @method int get_hostgroupid (string hostgroupname)
# Find the hostgroup_id for a named hostgroup.
# @param hostgroupname name of the hostgroup to search for
# @return hostgroup_id from table hostgroups, > 0 if the hostgroup exists;
# otherwise, 0 if the search succeeded (but found nothing), undef if the search failed (e.g., due to database error)
sub get_hostgroupid {
    my $self          = shift;
    my $hostgroupname = $_[0];
    my %results       = ();
    $self->debug( 'verbose', "called get_hostgroupid with $hostgroupname" );
    eval {
	%results = monarchWrapper->fetch_one( 'hostgroups', 'name', $hostgroupname );
    };
    if ($@) {
	$self->debug( 'error', "database access error in get_hostgroupid($hostgroupname)" );
	return undef;
    }
    return $results{'hostgroup_id'} || 0;
}

## @method int get_command_id (string commandname)
# Find the command_id for a named command.
# @param commandname name of the command to search for
# @return command_id: > 0 if the command exists;
# otherwise, 0 if the search succeeded (but found nothing), undef if the search failed (e.g., due to database error)
sub get_command_id {
    my $self        = shift;
    my $commandname = $_[0];
    $self->debug( 'verbose', "called get_command_id($commandname)" );
    my %results = ();
    eval {
	%results = monarchWrapper->fetch_one( 'commands', 'name', $commandname );
    };
    if ($@) {
	$self->debug( 'error', "database access error in get_command_id($commandname)" );
	return undef;
    }
    my $command_id = $results{'command_id'};
    if ( defined($command_id) && $command_id ) {
	$self->debug( 'verbose', "ID for command $commandname is $command_id" );
	return $command_id;
    }
    else {
	$self->debug( 'warning', "Command $commandname not found" );
	return 0;
    }
}

## @method int get_escalation_tree_id (string escalationtreename, string type)
# Find the escalation tree ID of a given escalation tree name.
# @param escalationtreename name of the escalation tree to search for
# @param type escalation type to search for, one of 'host' or 'service'
# @return tree_id from table escalation_trees, > 0 if the named escalation tree exists;
# otherwise, 0 if the search succeeded (but found nothing), undef if the search failed (e.g., due to database error)
sub get_escalation_tree_id {
    my $self               = shift;
    my $escalationtreename = $_[0];
    my $type               = $_[1];
    my %results            = ();
    $self->debug( 'verbose', "searching for escalationtreename $escalationtreename with type $type" );
    eval {
	my %where = ( 'name' => $escalationtreename, 'type' => $type );
	%results = monarchWrapper->fetch_one_where( 'escalation_trees', \%where );
    };
    if ($@) {
	$self->debug( 'error', "database access error in get_escalation_tree_id($escalationtreename. $type)" );
	return undef;
    }
    return $results{'tree_id'} || 0;
}

## @method int get_extended_host_information_template_id (param extended_host_information_template)
# Find the database ID of a given extended host information template.
# @param extended_host_information_template name of the extended host info template to search for
# @return hostextinfo_id from table extended_host_info_templates, > 0 if the extended host info template exists;
# otherwise, 0 if the search succeeded (but found nothing), undef if the search failed (e.g., due to database error)
sub get_extended_host_information_template_id {
    my $self                               = shift;
    my $extended_host_information_template = $_[0];
    my %results                            = ();
    $self->debug( 'verbose', "searching for host extended template  name $extended_host_information_template" );
    eval {
	my %where = ( 'name' => $extended_host_information_template );
	%results = monarchWrapper->fetch_one_where( 'extended_host_info_templates', \%where );
    };
    if ($@) {
	$self->debug( 'error', "database access error in get_extended_host_information_template_id($extended_host_information_template)" );
	return undef;
    }
    return $results{'hostextinfo_id'} || 0;
}

## @method string get_host_template_name (int hosttemplate_id)
# Get hosttemplatename for a given ID.
# @param hosttemplate_id ID of the hosttemplate to search for
# @return hosttemplatename: the found hosttemplate name if the host template exists;
# otherwise, an empty string if the search succeeded (but found nothing), undef if the search failed (e.g., due to database error)
sub get_host_template_name {
    my $self            = shift;
    my $hosttemplate_id = $_[0];

    my %results;
    eval {
	my %where = ( 'hosttemplate_id' => $hosttemplate_id );
	%results = monarchWrapper->fetch_one_where( 'host_templates', \%where );
    };
    if ($@) {
	$self->debug( 'error', "database access error in get_host_template_name($hosttemplate_id)" );
	return undef;
    }
    return $results{'name'} || '';
}

## @method string get_hostprofilename (int hostprofile_id)
# Find the hostprofile name for a given hostprofile ID.
# @param hostprofile_id ID of the host profile to search for
# @return name of hostprofile if hostprofile exists; otherwise, undefined
sub get_hostprofilename {
    my $self           = shift;
    my $hostprofile_id = $_[0];
    my %results        = ();
    eval {
	%results = monarchWrapper->fetch_one( 'profiles_host', 'hostprofile_id', $hostprofile_id );
    };
    if ($@) {
	$self->debug( 'error', "database access error in get_hostprofilename($hostprofile_id)" );
	return undef;
    }
    return $results{'name'};
}

## @method string get_serviceprofilename (int serviceprofile_id)
# Find the serviceprofile name for a given serviceprofile ID.
# @param serviceprofile_id ID of the service profile to search for
# @return profile name, false (0) otherwise
sub get_serviceprofilename {
    my $self              = shift;
    my $serviceprofile_id = $_[0];
    my %results           = ();
    eval {
	%results = monarchWrapper->fetch_one( 'profiles_service', 'serviceprofile_id', $serviceprofile_id );
    };
    if ($@) {
	$self->debug( 'error', "database access error in get_serviceprofilename($serviceprofile_id)" );
	return undef;
    }
    return $results{'name'};
}

## @method string get_genericservicename (int servicename_id)
# Get the service name for a given generic service name ID.
# @param servicename_id ID of the generic service to search for
# @return service_name: the found servicename; otherwise, undefined (false).
sub get_genericservicename {
    my $self           = shift;
    my $servicename_id = $_[0];

    $self->debug( 'verbose', "called get_genericservicename($servicename_id)" );

    my %results = ();
    eval {
	%results = monarchWrapper->fetch_one('service_names', 'servicename_id', $servicename_id);
    };
    if ($@) {
	$self->debug( 'error', "database access error in get_genericservicename($servicename_id)" );
	return undef;
    }
    return $results{name};
}

## @method string get_hostname (int host_id)
# Get the hostname for a given ID.
# @param host_id ID of the host to search for
# @return hostname: the found hostname; otherwise, undefined (either host not found, or database error)
sub get_hostname {
    my $self    = shift;
    my $host_id = $_[0];
    my %results = ();
    eval {
	%results = monarchWrapper->fetch_one( 'hosts', 'host_id', $host_id );
    };
    if ($@) {
	$self->debug( 'error', "database access error in get_hostname($host_id)" );
	return undef;
    }
    return $results{'name'};
}

## @method string get_servicename (int service_id)
# Get the service name for a given hostservice ID.
# @param service_id ID of the host service to search for
# @return servicename: the found service name; otherwise, undefined
sub get_servicename {
    my $self         = shift;
    my $service_id   = $_[0];
    my $service_name;
    eval {
	$service_name = monarchWrapper->get_service_name($service_id);
    };
    if ($@) {
	$self->debug( 'error', "database access error in get_servicename($service_id)" );
	return undef;
    }
    return $service_name;
}

## @method string get_host_address (string hostname)
# Find the address of a given host.
# @param hostname name of the host to search for
# @return address: the found host address if the host exists;
# otherwise, an empty string if the search succeeded (but found nothing), undef if the search failed (e.g., due to database error)
sub get_host_address {
    my $self     = shift;
    my $hostname = $_[0];
    $self->debug( 'verbose', "called get_host_address with $hostname" );
    my %results;
    eval {
	%results = monarchWrapper->fetch_one( 'hosts', 'name', $hostname );
    };
    if ($@) {
	$self->debug( 'error', "database access error in get_host_address($hostname)" );
	return undef;
    }
    return $results{'address'} || '';
}

## @method arrayref get_hosts_with_address (string address)
# Get the names of hosts that have a given IP address.
# @param address IP address to search for
# @return hostnames: arrayref pointing to a list of matching hostnames, or undef if a database error occurred
sub get_hosts_with_address {
    my $self      = shift;
    my $address   = $_[0];
    my @hostnames = ();
    eval {
	@hostnames = monarchWrapper->fetch_unique( 'hosts', 'name', 'address', $address );
    };
    if ($@) {
	$self->debug( 'error', "database access error in get_hosts_with_address($address)" );
	return undef;
    }
    return \@hostnames;
}

## @method array get_hostlist (void)
# Get a list of all hostnames.
# @return hostnames: array of hostnames, or an empty list if an error occurs
sub get_hostlist {
    my $self     = shift;
    my %hosthash = ();
    eval {
	%hosthash = monarchWrapper->get_hosts();
    };
    if ($@) {
	$self->debug( 'error', "database access error in get_hostlist()" );
	return ();
    }
    return keys %hosthash;
}

## @method arrayref or array get_hostgroups_for_host (string hostname)
# Retrieve a list of all hostgroups containing a given host.
# @param hostname name of the host for which hostgroup membership is desired
# @return hostgroups in list context, an array of names of hostgroups containing this host
sub get_hostgroups_for_host {
    my $self     = shift;
    my $hostname = $_[0];
    my @hostgroups = ();
    eval {
	@hostgroups = monarchWrapper->get_host_hostgroups($hostname);
    };
    if ($@) {
	$self->debug( 'error', "database access error in get_hostgroups_for_host($hostname)" );
	return wantarray ? () : undef;
    }
    return wantarray ? @hostgroups : \@hostgroups;
}

## @method arrayref or array get_hosts_in_hostgroup (string hostgroup)
# Retrieve a list of all hosts in a given hostgroup.
# @param hostgroup name of the hostgroup to search for
# @return hostnames: in list context, a list of hostnames; an empty list if the hostgroup does not exist or has no host members
sub get_hosts_in_hostgroup {
    my $self      = shift;
    my $hostgroup = $_[0];
    my @hosts = ();
    eval {
	@hosts = monarchWrapper->get_hostgroup_hosts($hostgroup);
    };
    if ($@) {
	$self->debug( 'error', "database access error in get_hosts_in_hostgroup($hostgroup)" );
	return wantarray ? () : undef;
    }
    return wantarray ? @hosts : \@hosts;
}

## @method arrayref or array get_hostservice_list (string hostname)
# Retrieve a list of all services on a host.
# @param hostname name of the host to get the services from
# @return servicenames: in list context, a list of the names of services attached to this host;
# an empty list if the host does not exist or has no services attached
sub get_hostservice_list {
    my $self     = shift;
    my $hostname = $_[0];
    my $hostid   = $self->get_hostid($hostname);
    my @services = ();
    eval {
	@services = monarchWrapper->get_host_services($hostid);
    };
    if ($@) {
	$self->debug( 'error', "database access error in get_hostservice_list($hostname)" );
	return wantarray ? () : undef;
    }
    return wantarray ? @services : \@services;
}

## @method arrayref or array get_service_hostlist (string servicename)
# Retrieve a list of all hosts having a particular service assigned.
# @param servicename name of the service to search for on hosts
# @return hostnames: in list context, an array of hostnames, or an empty list if an error occurs
# (which is indistinguishable from having no associated hosts, so this mode of calling is not
# robust); in scalar context, an arrayref for the list of hostnames (which might be legitimately
# empty), or 0 if there was no service of that name, or undef if an error occurs, which makes it
# easy to distinguish an error condition
sub get_service_hostlist {
    my $self        = shift;
    my $servicename = $_[0];

    my $servicename_id = $self->get_serviceid($servicename);
    if ( not $servicename_id ) {
	## Either non-existence or database error.  In list context, our caller won't be able to
	## distinguish.  In scalar context, we return 0 for no-such-service and undef for database error.
	$self->debug( 'error', "Cannot find servicename $servicename" );
	return wantarray ? () : $servicename_id;
    }
    my @hosts = ();
    eval {
	@hosts = monarchWrapper->get_service_hosts($servicename_id);
    };
    if ($@) {
	$self->debug( 'error', "database access error in get_service_hostlist($servicename)" );
	return wantarray ? () : undef;
    }
    return wantarray ? @hosts : \@hosts;
}

## @method arrayref or array get_all_service_dependencies (void)
# Get all service dependencies as a hash.
# @return service_dependencies: in list context, an array of quadruples. Each quadruple consists of
# hostname, servicename, depending host, depending service.  IN scalar context, an arrayref for the
# quadrupples.
sub get_all_service_dependencies {
    my $self   = shift;
    my @result = ();

    ## FIX MAJOR:  handle exceptions here
    my %servicedeplist = monarchWrapper->fetch_all('service_dependency');
    foreach my $dep ( keys(%servicedeplist) ) {
	my $service_id        = $servicedeplist{$dep}[1];
	my $host_id           = $servicedeplist{$dep}[2];
	my $depend_on_host_id = $servicedeplist{$dep}[3];
	my $template          = $servicedeplist{$dep}[4];

	my $hostname              = $self->get_hostname($host_id);
	my $depending_hostname    = $self->get_hostname($depend_on_host_id);
	my $service_name          = $self->get_servicename($service_id);
	my $depending_servicename = '';

	my %template_props = monarchWrapper->fetch_one( 'service_dependency_templates', 'id', $template );
	if (%template_props) {
	    $depending_servicename = $template_props{'name'};
	    $self->debug( 'verbose',
		'template props: ' . $template_props{'name'} . " var:  $depending_servicename id: " . $template_props{'id'} );
	}
	else {
	    $self->debug( 'warning', "No dependency information for template ID $template found" );
	}

	my @servicedep = ( $depending_hostname, $depending_servicename );
	push @result, ( $hostname, $service_name, $depending_hostname, $depending_servicename );
	$self->debug( 'verbose',
		"Dep key: $dep, service_id:  $service_id, name: $service_name, host_id: $host_id,"
	      . " hostname: $hostname, depend_on_host_id: $depend_on_host_id, name: $depending_hostname,"
	      . " template: $template, depending service: $depending_servicename" );
    }

    return wantarray ? @result : \@result;
}

## @method boolean or hash search_service_by_prefix (string substring)
# This routine is misnamed; we search for service names by substring (not just prefix),
# because with GroundWork > 5.2 substrings match instead of prefixes and a limit count has been appended to the search statement.
# @param substring services whose name contains this string will be returned
# @return services: in list context, a hash of matching service names (with identical keys and values),
# or an empty list if an error occurs (which is indistinguishable from having no such services, so this mode
# of calling is not robust); in scalar context, true if some services match, false if no services match,
# or undef if an error occurs, which makes it easy to distinguish an error condition
sub search_service_by_prefix {
    my $self     = shift;
    my $prefix   = $_[0];
    my %services = ();
    eval {
	%services = monarchWrapper->search_service( $prefix, $self->{'limit_sql'} );
    };
    if ($@) {
	$self->debug( 'error', "database access error in search_service_by_prefix($prefix)" );
	return wantarray ? () : undef;
    }
    foreach my $service ( keys(%services) ) {
	if ( $service !~ /^$prefix/ ) {
	    delete $services{$service};
	}
    }
    return %services;
}

## @method boolean import_host (string hostname, string alias, string address, string profile_name, boolean update)
# Import or update a host and apply profiles. This routine performs only a shallow application of the host profile;
# likely, you want import_host_api() instead. If updates are disabled and you try to import an already-existing host,
# nothing will be changed and an error is returned. If update is allowed, all settings of an existing host will
# be overwritten by this import. If the host does not exist yet, it will be created with these settings, regardless
# of the update flag.
# @param hostname name of the host to be imported
# @param alias the host's alias
# @param address the host's IP address
# @param profile_name name of the hostprofile to assign to the host
# @param update (optional) set to 1 (true), if updates to an existing host are allowed
# @return status: true if successful, false otherwise
sub import_host {
    my $self         = shift;
    my $hostname     = $_[0];
    my $alias        = $_[1];
    my $address      = $_[2];
    my $profile_name = $_[3];
    my $update       = $_[4];
    my $newhostid;
    my $importmsg;

    $self->debug( 'verbose',
	"Import Host with name: $hostname, Alias: $alias, Address: $address, Hostprofile: $profile_name, Update: $update" );
    ## FIX MAJOR:  handle exceptions here
    my $auth = monarchWrapper->dbconnect();

    my %hostprofile = monarchWrapper->fetch_one( 'profiles_host', 'name', $profile_name );
    if ( not %hostprofile ) {
	$self->debug( 'error', "No Profile with name $profile_name found in database" );
	return 0;
    }
    else {
	$self->debug( 'verbose', "Id Hostprofile: $hostprofile{'hostprofile_id'}" );
    }

    eval {
	( $newhostid, $importmsg ) = monarchWrapper->import_host( $hostname, $alias, $address, $hostprofile{'hostprofile_id'}, $update );
    };
    if ($@) {
	$self->debug( 'error', "database access error in import_host($hostname, $alias, $address, $profile_name, $update)" );
	return undef;
    }

    # import_host makes a disconnect :-(
    $auth = monarchWrapper->dbconnect();

    $self->debug( 'verbose', 'import result. ' . $newhostid . ' ' . join( ', ', @{$importmsg} ) );

    if ( !grep ( /(added|updated)/, @{$importmsg} ) ) {
	$self->debug( 'error', 'import failed: ' . join( ', ', @{$importmsg} ) );
	return 0;
    }

    # not needed anymore, now done by import_host
    # return $self->assign_and_apply_hostprofile_serviceprofiles($hostname, $profile_name, 1);
    return 1;
}

## @method boolean import_host_api (string hostname, string alias, string address, string profile_name, boolean update)
# Import or update a host and apply profiles using the MonarchAPI version of import_host. This routine performs a deep
# application of the host profile. If updates are disabled and you try to import an already-existing host, nothing will
# be changed and an error is returned. If update is allowed, all settings of an existing host will be overwritten by
# this import. If the host does not exist yet, it will be created with these settings, regardless of the update flag.
# @param hostname name of the host to be imported
# @param alias the host's alias
# @param address the host's IP address
# @param profile_name name of the hostprofile to assign to the host
# @param update (optional) set to 1 (true), if updates to an existing host are allowed
# @return status: true if successful, false otherwise
sub import_host_api {
    my $self         = shift;
    my $hostname     = $_[0];
    my $alias        = $_[1];
    my $address      = $_[2];
    my $profile_name = $_[3];
    my $update       = $_[4];
    my %host         = ();

    $self->debug( 'verbose',
	"Import Host with name: $hostname, Alias: $alias, Address: $address, Hostprofile: $profile_name, Update: $update" );

    # FIX MINOR:  It's not clear why we should reconnect on every call -- get rid of this.
    my $auth = monarchWrapper->dbconnect();

    my %hostprofile = ();
    eval {
	%hostprofile = monarchWrapper->fetch_one( 'profiles_host', 'name', $profile_name );
    };
    if ($@) {
	$self->debug( 'error', "database access error in import_host_api($hostname, $alias, $address, $profile_name, $update)" );
	return undef;
    }
    if ( not %hostprofile ) {
	$self->debug( 'error', "No Profile with name $profile_name found in database" );
	return 0;
    }
    else {
	$self->debug( 'verbose', "Id Hostprofile: $hostprofile{'hostprofile_id'}" );
    }

    my %hostprops = ();
    eval {
	%hostprops = monarchWrapper->fetch_one( 'hosts', 'name', $hostname );
    };
    if ($@) {
	$self->debug( 'error', "database access error in import_host_api($hostname, $alias, $address, $profile_name, $update)" );
	return undef;
    }
    if (%hostprops) {
	$host{'host_id'} = $hostprops{'host_id'};
	$self->debug( 'verbose', "Host $hostname already exists.  host_id is $host{'host_id'}." );
	if ( not $update ) {
	    $self->debug( 'error', "Update flag is false.  Not updating" );
	    return 0;
	}
	$host{'exists'}    = 1;
	$host{'overwrite'} = 1;
    }
    else {
	$host{'new'} = 1;
    }

    $host{'name'}           = $hostname;
    $host{'alias'}          = $alias;
    $host{'address'}        = $address;
    $host{'hostprofile_id'} = $hostprofile{'hostprofile_id'};

    my @results = ();
    eval {
	@results = monarchWrapper->import_host_api( \%host );
    };
    if ($@) {
	$self->debug( 'error', "database access error in import_host_api($hostname, $alias, $address, $profile_name, $update)" );
	return undef;
    }
    my $results = join( "\n", @results );

    if ( $results =~ /error/i ) {
	$self->debug( 'error', "import_host_api returns error message: \n$results" );
	return 0;
    }
    return 1;
}

## @method boolean clone_host (string src_host, string dest_host, string dest_alias, string dest_address)
# Clone a host.
# @param src_host name of the host to be cloned
# @param dest_host name of the resulting host
# @param dest_alias alias for the resulting host
# @param dest_address address of the resulting host
# @return status: true if successful, false otherwise
sub clone_host {
    my $self         = shift;
    my $src_host     = $_[0];
    my $dest_host    = $_[1];
    my $dest_alias   = $_[2];
    my $dest_address = $_[3];

    if ( !$self->host_exists($src_host) ) {
	$self->debug( 'error', "Host $src_host does not exist, cannot clone" );
	return 0;
    }
    if ( $self->host_exists($dest_host) ) {
	$self->debug( 'error', "Clone Target Host $dest_host already exists, cannot clone" );
	return 0;
    }
    my @errors = ();
    eval {
	@errors = monarchWrapper->clone_host( $src_host, $dest_host, $dest_alias, $dest_address );
    };
    if ($@) {
	$self->debug( 'error', "database access error in clone_host($src_host, $dest_host, $dest_alias, $dest_address)" );
	return undef;
    }
    if (@errors) {
	$self->debug( 'error', "Cloning host $src_host to $dest_host produced: @errors" );
	return 0;
    }
    else {
	$self->debug( 'verbose', "Cloning host $src_host to $dest_host done" );
    }
    return 1;
}

## @method boolean clone_service (string src_service, string dest_service)
# Clone a generic service.
# @param src_service name of the service to be cloned
# @param dest_service name of the resulting service
# @return status: true if successful, false otherwise
sub clone_service {
    my $self         = shift;
    my $src_service  = $_[0];
    my $dest_service = $_[1];

    if ( !$self->service_exists($src_service) ) {
	$self->debug( 'error', "Service $src_service does not exist, cannot clone" );
	return 0;
    }
    if ( $self->service_exists($dest_service) ) {
	$self->debug( 'error', "Clone Target Service $dest_service already exists, cannot clone" );
	return 0;
    }
    my @errors = ();
    eval {
	@errors = monarchWrapper->clone_service( $dest_service, $src_service, 0 );
    };
    if ($@) {
	$self->debug( 'error', "database access error in clone_service($src_service, $dest_service)" );
	return undef;
    }
    if (@errors) {
	$self->debug( 'error', "Cloning service $src_service to $dest_service produced: @errors" );
	return 0;
    }
    else {
	$self->debug( 'verbose', "Cloning service $src_service to $dest_service done" );
    }
    return 1;
}

## @method int clone_hostprofile (string source_hostprofile, string target_hostprofile)
# Clone a hostprofile.
# @param source_hostprofile name of the hostprofile to clone
# @param target_hostprofile name of the new cloned hostprofile
# @return hostprofile_id: > 0 if cloning was successful;
# otherwise, 0 if logical problems were found, undef if a database error occurred
sub clone_hostprofile {
    my $self               = shift;
    my $source_hostprofile = $_[0];
    my $target_hostprofile = $_[1];

    my $source_profile_id = $self->get_hostprofileid($source_hostprofile);
    if ( not $source_profile_id ) {
	$self->debug( 'error', "Cannot find hostprofile $source_hostprofile. Nothing to clone." );
	return $source_profile_id;
    }
    if ( $self->get_hostprofileid($target_hostprofile) ) {
	$self->debug( 'error', "Hostprofile with name $target_hostprofile already exists. Cannot clone." );
	return 0;
    }

    $self->debug( 'verbose', "Cloning hostprofile with ID $source_profile_id" );
    my %where = ( 'hostprofile_id' => $source_profile_id );
    my @values = ();
    my $result;
    my $target_profile_id;
    ## Remember that return() from within eval{}; only gets you out of the enclosing eval{};, not out of
    ## the function.  So we have to avoid that situation and be careful how we exit our eval{}; blocks.
    eval {
	## need to copy entry in table profiles_host first
	my %profile = monarchWrapper->fetch_list_hash_array( 'profiles_host', \%where );
	if ( not %profile ) {
	    $self->debug( 'error', "cannot find host profile data for source hostprofile_id $source_profile_id" );
	    die "Cannot find source host profile.\n";
	}
	elsif ( not defined $profile{$source_profile_id} ) {
	    $self->debug( 'error', "Invalid host profile array returned for source hostprofile_id $source_profile_id" );
	    my $error = $profile{error} || 'unknown error';
	    die "Invalid host profile array: $error\n";
	}

	@values = @{ $profile{$source_profile_id} };
	## set hostprofile_id to DEFAULT when inserting
	$values[0] = \undef;
	## set new name
	$values[1] = $target_hostprofile;
	$result = monarchWrapper->insert_obj_id( 'profiles_host', \@values, 'hostprofile_id' );
	if ( $result =~ /Error/ ) {
	    $self->debug( 'error', "insert failed: $result. Could not clone hostprofile" );
	    die "$result\n";
	}
	else {
	    $self->debug( 'verbose', "insert into profiles_host created hostprofile_id $result" );
	}

	$target_profile_id = $self->get_hostprofileid($target_hostprofile);
	if ( not $target_profile_id ) {
	    $self->debug( 'error', "fetch of created hostprofile $target_hostprofile failed. Could not clone hostprofile" );
	    die "Cannot find just-inserted target hostprofile.\n";
	}

	my %profile_overrides = monarchWrapper->fetch_list_hash_array( 'hostprofile_overrides', \%where );
	if (%profile_overrides) {
	    $self->debug( 'verbose', "Analyze profile overrides with profile id: $source_profile_id" );
	    if ( not defined $profile_overrides{$source_profile_id} ) {
		$self->debug( 'error', "Invalid host profile overrides array returned for source hostprofile_id $source_profile_id" );
		my $error = $profile_overrides{error} || 'unknown error';
		die "Invalid host profile overrides array: $error\n";
	    }
	    else {
		## set new ID
		@values = @{ $profile_overrides{$source_profile_id} };
		$values[0] = $target_profile_id;
		$result = monarchWrapper->insert_obj( 'hostprofile_overrides', \@values );
		if ( $result =~ /Error/ ) {
		    $self->debug( 'error', "insert failed: $result. Could not clone hostprofile overrides" );
		    die "$result\n";
		}
		else {
		    $self->debug( 'verbose', "insert into hostprofile_overrides: result $result" );
		}
	    }
	}

	## table profile_parent: multiple entries per profile are possible here
	my @profile_parents = monarchWrapper->get_profile_parent($source_profile_id);
	foreach my $parent (@profile_parents) {
	    my $parent_id = $self->get_hostid($parent);
	    @values = ( $target_profile_id, $parent_id );
	    $result = monarchWrapper->insert_obj( 'profile_parent', \@values );
	    if ( $result =~ /Error/ ) {
		$self->debug( 'error', "insert failed: $result. Could not set parent $parent for cloned hostprofile $target_hostprofile" );
		die "$result\n";
	    }
	    else {
		$self->debug( 'verbose', "insert result: $result for parent $parent, cloned hostprofile $target_hostprofile" );
	    }
	}

	## table profile_hostgroup (multiple entries possible)
	my @profile_hostgroups = monarchWrapper->get_profile_hostgroup($source_profile_id);
	foreach my $hostgroup (@profile_hostgroups) {
	    my $hgrp_id = $self->get_hostgroupid($hostgroup);
	    @values = ( $target_profile_id, $hgrp_id );
	    $result = monarchWrapper->insert_obj( 'profile_hostgroup', \@values );
	    if ( $result =~ /Error/ ) {
		$self->debug( 'error',
		    "insert failed: $result. Could not set hostgroup $hostgroup for cloned hostprofile $target_hostprofile" );
		die "$result\n";
	    }
	    else {
		$self->debug( 'verbose', "insert result: $result for hostgroup $hostgroup, cloned hostprofile $target_hostprofile" );
	    }
	}

	## profile_host_profile_service (multiple entries possible)
	my %profile_service_profiles = monarchWrapper->get_host_profile_service_profiles($source_profile_id);
	foreach my $sp_id ( values %profile_service_profiles ) {
	    @values = ( $target_profile_id, $sp_id );
	    $result = monarchWrapper->insert_obj( 'profile_host_profile_service', \@values );
	    if ( $result =~ /Error/ ) {
		$self->debug( 'error',
		    "insert failed: $result. Could not set service profile with id $sp_id for cloned hostprofile $target_hostprofile" );
		die "$result\n";
	    }
	    else {
		$self->debug( 'verbose', "insert result: $result for service profile id $sp_id, cloned hostprofile $target_hostprofile" );
	    }

	}

	## external_host_profile
	my @externals = monarchWrapper->get_profile_external($source_profile_id);
	foreach my $external (@externals) {
	    @values = ( $self->get_externalid($external), $target_profile_id );
	    $result = monarchWrapper->insert_obj( 'external_host_profile', \@values );
	    if ( $result =~ /Error/ ) {
		$self->debug( 'error', "insert failed: $result. Could not set external $external for cloned hostprofile $target_hostprofile" );
		die "$result\n";
	    }
	    else {
		$self->debug( 'verbose', "insert result: $result for external $external, cloned hostprofile $target_hostprofile" );
	    }
	}

	## contactgroup_host_profile
	my @contactgroups = monarchWrapper->get_contactgroups( 'host_profiles', $source_profile_id );
	foreach my $contactgroup (@contactgroups) {
	    @values = ( $self->get_contactgroup_id($contactgroup), $target_profile_id );
	    $result = monarchWrapper->insert_obj( 'contactgroup_host_profile', \@values );
	    if ( $result =~ /Error/ ) {
		$self->debug( 'error',
		    "insert failed: $result. Could not set contactgroup $contactgroup for cloned hostprofile $target_hostprofile" );
		die "$result\n";
	    }
	    else {
		$self->debug( 'verbose', "insert result: $result for contactgroup $contactgroup, cloned hostprofile $target_hostprofile" );
	    }
	}
    };
    if ($@) {
	$self->debug( 'error', "database access error in clone_hostprofile($source_hostprofile, $target_hostprofile)" );
	## FIX LATER:  We might have early-stage successes and late-stage failures, leaving an inconsistent target profile still
	## in the database.  For that reason, perhaps we should attempt to unwind the whole operation if we got a failure.
	return undef;
    }

    return $target_profile_id;
}

## @method boolean delete_hostprofile (string hostprofilename)
# Delete a hostprofile from the monarch database.
# @param hostprofilename name of the hostprofile to be deleted
# @return status: true if successful; false if the specified hostprofile does not exist or if a database operation has failed.
sub delete_hostprofile {
    my $self            = shift;
    my $hostprofilename = $_[0];

    my $hostprofile_id = $self->get_hostprofileid($hostprofilename);
    if ( not $hostprofile_id ) {
	$self->debug( 'error', "Cannot find hostprofile_id for hostprofile $hostprofilename" );
	return $hostprofile_id;
    }
    $self->debug( 'verbose', "Deleting hostprofile $hostprofilename with ID $hostprofile_id" );
    my $result;
    eval {
	$result = monarchWrapper->delete_all( 'profiles_host', 'hostprofile_id', $hostprofile_id );
    };
    if ($@) {
	$self->debug( 'error', "database access error in delete_hostprofile($hostprofilename)" );
	return undef;
    }
    if ( $result =~ /^Error/ ) {
	$self->debug( 'error', "deleting $hostprofilename failed: $result" );
	return undef;
    }
    return 1;
}

## @method int clone_service_template (string source_servicetemplate, string target_servicetemplate)
# Clone a servicetemplate.
# @param source_servicetemplate name of the servicetemplate to clone
# @param target_servicetemplate name of the new cloned servicetemplate
# @return servicetemplate_id: > 0 if cloning was successful;
# otherwise, 0 if logical problems found, undef if a database error occurred
sub clone_service_template {
    my $self                   = shift;
    my $source_servicetemplate = $_[0];
    my $target_servicetemplate = $_[1];
    my $db_access_error        = "database access error in clone_service_template($source_servicetemplate, $target_servicetemplate)";

    my $source_template_id = $self->get_service_template_id($source_servicetemplate);
    if ( not $source_template_id ) {
	$self->debug( 'error', "servicetemplate $source_servicetemplate not found. Nothing to clone" );
	return $source_template_id;
    }
    if ( $self->get_service_template_id($target_servicetemplate) ) {
	$self->debug( 'error', "servicetemplate with name $target_servicetemplate already exists. Cannot clone" );
	return 0;
    }
    $self->debug( 'verbose', "Cloning servicetemplate with id $source_template_id" );

    # need to copy entry in table templates_service first
    my %template = ();
    eval {
	my %where = ( 'servicetemplate_id' => $source_template_id );
	%template = monarchWrapper->fetch_list_hash_array( 'service_templates', \%where );
    };
    if ($@) {
	$self->debug( 'error', $db_access_error );
	return undef;
    }
    my @values = @{ $template{$source_template_id} };

    # set servicetemplate_id to DEFAULT when inserting
    $values[0] = \undef;

    # set new name
    $values[1] = $target_servicetemplate;

    # $values[9]='comment';
    # $values[8]='data';
    my $result;
    eval {
	$result = monarchWrapper->insert_obj_id( 'service_templates', \@values, 'servicetemplate_id' );
    };
    if ($@) {
	$self->debug( 'error', $db_access_error );
	return undef;
    }
    if ( $result =~ /Error/ ) {
	$self->debug( 'error', "insert failed: $result. Could not clone servicetemplate" );
	return undef;
    }
    else {
	$self->debug( 'verbose', "insert result into templates_service: $result" );
    }
    my $target_template_id = $self->get_service_template_id($target_servicetemplate);

    ## contactgroup_service_template
    eval {
	my @contactgroups = monarchWrapper->get_contactgroups( 'service_templates', $source_template_id );
	foreach my $contactgroup (@contactgroups) {
	    @values = ( $self->get_contactgroup_id($contactgroup), $target_template_id );
	    $result = monarchWrapper->insert_obj( 'contactgroup_service_template', \@values );
	    if ( $result =~ /Error/ ) {
		$self->debug( 'error',
		    "insert failed: $result. Could not set contactgroup $contactgroup for cloned servicetemplate $target_servicetemplate" );
		die "$result\n";
	    }
	    else {
		$self->debug( 'verbose',
		    "insert result: $result for contactgroup $contactgroup, cloned servicetemplate $target_servicetemplate" );
	    }
	}
    };
    if ($@) {
	$self->debug( 'error', $db_access_error );
	return undef;
    }

    return $target_template_id;
}

## @method DEPRECATED boolean assign_host_profile (string hostname, string hostprofilename, boolean replace)
# Assign a host profile and associated service profiles to a host.
# This function is deprecated, due to a misleading name; use assign_and_apply_hostprofile_to_host() instead.
# @param hostname name of the host to which the hostprofile should be applied
# @param hostprofilename name of the hostprofile to assign and apply to the host
# @param replace True, if existing services should be replaced by services in associated service profiles. False, if services should be merged.
# @return status: true if successful, false otherwise
sub assign_host_profile {
    my $self = shift;
    return $self->assign_and_apply_hostprofile_to_host(@_);
}

## @method boolean assign_and_apply_hostprofile_to_host (string hostname, string hostprofilename, boolean replace)
# Assign and apply a host profile and associated service profiles to a host.
# @param hostname name of the host to which the hostprofile should be applied
# @param hostprofilename name of the hostprofile to assign and apply to the host
# @param replace True, if existing services should be replaced by services in associated service profiles. False, if services should be merged.
# @return status: true if successful, false otherwise
sub assign_and_apply_hostprofile_to_host {
    my $self            = shift;
    my $hostname        = $_[0];
    my $hostprofilename = $_[1];
    my $replace         = $_[2];

    my $host_id = $self->get_hostid($hostname);
    if ( not $host_id ) {
	$self->debug( 'error', "no valid host_id for host $hostname found" );
	return $host_id;
    }
    my $hostprofileID = $self->get_hostprofileid($hostprofilename);
    my @host_ids      = ($host_id);

    $self->debug( 'verbose', "Trying to apply hostprofile $hostprofilename to host IDs @host_ids, replace: $replace" );

    my $result = undef;
    eval {
	my %vals = ( 'hostprofile_id' => $hostprofileID );
	$result = monarchWrapper->update_obj( 'hosts', 'host_id', $host_id, \%vals );
    };
    if ($@) {
	$self->debug( 'error', "database access error in assign_and_apply_hostprofile_to_host($hostname, $hostprofilename, $replace)" );
	return undef;
    }

    if ( $result =~ /Error/ ) {
	if ( $result =~ /duplicate/i ) {
	    ## Confused code -- this can never happen.
	    $self->debug( 'verbose', "host profile $hostprofilename was already set for host $hostname" );
	}
	else {
	    $self->debug( 'error', 'could not assign hostprofile_id ' . $hostprofileID . " errors: $result" );
	    return undef;
	}
    }

    eval {
	$result = monarchWrapper->host_profile_apply( $hostprofileID, \@host_ids );
    };
    if ($@) {
	$self->debug( 'error', "database access error in assign_and_apply_hostprofile_to_host($hostname, $hostprofilename, $replace)" );
	return undef;
    }
    if ( $result =~ /Error/ ) {
	$self->debug( 'error', "applying host profile $hostprofilename to host $hostname failed: $result" );
	return undef;
    }

    return $self->assign_and_apply_hostprofile_serviceprofiles( $hostname, $hostprofilename, $replace );
}

## @method boolean apply_hostprofile_to_host (string hostname, string hostprofilename, boolean replace)
# Apply a host profile and associated service profiles to a host.
# This routine is similar to assign_and_apply_hostprofile_to_host(), but it does not permanently assign the host profile to the host.
# (That said, service profiles associated with the host profile are still assigned to the host before they are applied.)
# This routine is provided to support the case where a host is being added to the system and its association with the
# host profile is to be indirect through a hostgroup that is assigned to be managed by the host profile,
# instead of having the host profile be directly assigned to the host.
# @param hostname name of the host to which the hostprofile should be applied
# @param hostprofilename name of the hostprofile to apply to the host
# @param replace True, if existing services should be replaced by services in associated service profiles. False, if services should be merged.
# @return status: true if successful, false otherwise
sub apply_hostprofile_to_host {
    my $self            = shift;
    my $hostname        = $_[0];
    my $hostprofilename = $_[1];
    my $replace         = $_[2];

    my $host_id = $self->get_hostid($hostname);
    if ( not $host_id ) {
	$self->debug( 'error', "no valid host_id for host $hostname found" );
	return $host_id;
    }
    my $hostprofileID = $self->get_hostprofileid($hostprofilename);
    if (not $hostprofileID) {
	$self->debug( 'error', "No Profile with name $hostprofilename found in database" );
	return $hostprofileID;
    }

    my @host_ids = ($host_id);

    $self->debug( 'verbose', "Trying to apply hostprofile $hostprofilename to host IDs @host_ids, replace: $replace" );

    my $result = undef;
    eval {
	$result = monarchWrapper->host_profile_apply( $hostprofileID, \@host_ids );
    };
    if ($@) {
	$self->debug( 'error', "database access error in apply_hostprofile_to_host($hostname, $hostprofilename, $replace)" );
	return undef;
    }
    if ( $result =~ /Error/ ) {
	$self->debug( 'error', "applying host profile $hostprofilename to host $hostname failed: $result" );
	return undef;
    }

    return $self->assign_and_apply_hostprofile_serviceprofiles( $hostname, $hostprofilename, $replace );
}

## @method DEPRECATED boolean apply_hostprofile_service_profiles (string hostname, string hostprofilename, boolean replace)
# Apply all service profiles which are assigned to a host profile to a host.
# This function is deprecated, due to a misleading name; use assign_and_apply_hostprofile_serviceprofiles() instead.
# @param hostname name of the host to which the serviceprofiles should be applied
# @param hostprofilename name of the hostprofile whose serviceprofiles will be assigned to the host
# @param replace True, if existing services should be replaced by services in the host profile's service profiles.
# False, if services should be merged.
# @return status: true if successful, false otherwise
sub apply_hostprofile_service_profiles {
    my $self = shift;
    return $self->assign_and_apply_hostprofile_serviceprofiles(@_);
}

## @method boolean assign_and_apply_hostprofile_serviceprofiles (string hostname, string hostprofilename, boolean replace)
# Apply all service profiles which are assigned to a host profile to a host.
# @param hostname name of the host to which the serviceprofiles should be applied
# @param hostprofilename name of the hostprofile whose serviceprofiles will be assigned to the host
# @param replace True, if existing services should be replaced by services in the host profile's service profiles.
# False, if services should be merged.
# @return status: true if successful, false otherwise
sub assign_and_apply_hostprofile_serviceprofiles {
    my $self            = shift;
    my $hostname        = $_[0];
    my $hostprofilename = $_[1];
    my $replace         = $_[2];

    my $host_id = $self->get_hostid($hostname);
    if ( not $host_id ) {
	$self->debug( 'error', "host $hostname not found" );
	return $host_id;
    }

    my %hostprofile = ();
    eval {
	%hostprofile = monarchWrapper->fetch_one( 'profiles_host', 'name', $hostprofilename );
    };
    if ($@) {
	$self->debug( 'error', "database access error in assign_and_apply_hostprofile_serviceprofiles($hostname, $hostprofilename, $replace)" );
	return undef;
    }

    if ( not %hostprofile ) {
	$self->debug( 'error', "No Profile with name $hostprofilename found in database" );
	return 0;
    }
    else {
	$self->debug( 'verbose', "Id Hostprofile: $hostprofile{'hostprofile_id'}" );
    }

    # Fetch associated Service Profiles
    my %service_profiles = ();
    eval {
	%service_profiles = monarchWrapper->get_host_profile_service_profiles( $hostprofile{'hostprofile_id'} );
    };
    if ($@) {
	$self->debug( 'error', "database access error in assign_and_apply_hostprofile_serviceprofiles($hostname, $hostprofilename, $replace)" );
	return undef;
    }

    my @service_profile_names;
    my @service_profile_ids;
    foreach my $name ( sort keys %service_profiles ) {
	$self->debug( 'verbose', "setting Profile name: $name , ID: $service_profiles{$name}" );
	push @service_profile_names, $name;
	push @service_profile_ids,   $service_profiles{$name};

	my @values = ( $service_profiles{$name}, $host_id );

	# serviceprofile may have to be added to database
	$self->debug( 'verbose', "writing @values to table serviceprofile_host" );
	## FIX MAJOR:  handle exceptions here
	my $result = monarchWrapper->insert_obj( 'serviceprofile_host', \@values );
	if ( $result =~ /Error/ ) {
	    if ( $result =~ /duplicate/i ) {
		$self->debug( 'verbose', "service profile $name was already set for host $hostname" );
	    }
	    else {
		$self->debug( 'error', 'could not assign serviceprofile_id ' . $service_profiles{$name} . " errors: $result" );
		return undef;
	    }
	}
    }

    my $replacestring = $replace ? 'replace' : 'merge';

    $self->debug( 'verbose',
	"applying serviceprofiles @service_profile_names with IDs @service_profile_ids on host $hostname with $replacestring option"
    );

    my $profcnt;
    my $errormsg;
    eval {
	( $profcnt, $errormsg ) = monarchWrapper->service_profile_apply( \@service_profile_ids, $replacestring, [$host_id] );
    };
    if ($@) {
	$self->debug( 'error', "database access error in assign_and_apply_hostprofile_serviceprofiles($hostname, $hostprofilename, $replace)" );
	return undef;
    }

    # return false if errormsg not empty.
    if ( @{$errormsg} ) {
	$self->debug( 'error', 'Error applying service profiles which belong to host profile: ' . join( ', ', @{$errormsg} ) );
	return 0;
    }
    return 1;
}

## @method int create_serviceprofile (string serviceprofilename, string serviceprofile_description)
# Create an empty serviceprofile.
# @param serviceprofilename name of the new profile
# @param serviceprofile_description short text description of the new profile
# @return serviceprofile_id: > 0, if a serviceprofile was created;
# otherwise, 0 if a logical error occurred (e.g., the name already exists), undef if a database error occurred
sub create_serviceprofile {
    my $self                       = shift;
    my $serviceprofilename         = $_[0];
    my $serviceprofile_description = $_[1];

    if ( $self->get_serviceprofileid($serviceprofilename) ) {
	$self->debug( 'error', "Serviceprofile with name $serviceprofilename already exists. Cannot create" );
	return 0;
    }

    # data needs to be an xml string without payload
    my $xml_props = gwxml->new();
    my $data      = $xml_props->toString;

    my $result;
    eval {
	## we need \undef for id and insert_obj_id since 6.7
	my @values = ( \undef, $serviceprofilename, $serviceprofile_description, $data );
	$result = monarchWrapper->insert_obj_id( 'profiles_service', \@values, 'serviceprofile_id' );
    };
    if ($@) {
	$self->debug( 'error', "database access error in create_serviceprofile($serviceprofilename, $serviceprofile_description)" );
	return undef;
    }
    if ( $result =~ /Error/ ) {
	$self->debug( 'error', "insert failed: $result. Could not create serviceprofile $serviceprofilename" );
	return undef;
    }
    else {
	$self->debug( 'verbose', "Created serviceprofile $serviceprofilename with result: $result" );
    }
    ## Could just return $result here and be done with it.
    return $self->get_serviceprofileid($serviceprofilename);
}

## @method boolean assign_service_to_serviceprofile (string servicename, string serviceprofilename, string apply, boolean replace)
# Assign a service to a serviceprofile, and apply that serviceprofile to all hosts to which it is already assigned.
# @param servicename name of the generic service to assign to the serviceprofile
# @param serviceprofilename name of the serviceprofile to which the service should be assigned, and which may be
# re-applied to all hosts to which this serviceprofile is already assigned, depending on the setting of the apply parameter
# @param apply false (default, if not provided), if the serviceprofile should not be apply to any hosts; 'apply-if-new',
# if the serviceprofile should be applied to existing hosts that already have the serviceprofile assigned, but only if the
# named service was not already part of the serviceprofile; 'apply', if the serviceprofile should be applied to existing hosts
# that already have the serviceprofile assigned, whether or not the named service was already part of the serviceprofile
# @param replace Boolean flag. True, if (when applying the service profile to hosts) all existing services on hosts that already have the
# named serviceprofile assigned should be replaced by just the services in the one specified serviceprofile.
# False (default, if not provided) if services from the serviceprofile should be merged into those already attached to such hosts.
# @return status: true, if operation was successful;
# otherwise, false (0) if a logical error occurred (e.g., the named serviceprofile does not exist), undef if a database error occurred
sub assign_service_to_serviceprofile {
    my $self               = shift;
    my $servicename        = $_[0];
    my $serviceprofilename = $_[1];
    my $apply              = $_[2] || 0;
    my $replace            = $_[3] || 0;
    local $_;

    my $sprf_id = $self->get_serviceprofileid($serviceprofilename);
    if ( not $sprf_id ) {
	$self->debug( 'error', "Cannot find serviceprofile with name $serviceprofilename." );
	return $sprf_id;
    }
    my $servicename_id = $self->get_serviceid($servicename);
    if ( not $servicename_id ) {
	$self->debug( 'error', "Cannot find service with name $servicename; cannot assign to serviceprofile $serviceprofilename" );
	return $servicename_id;
    }
    my @services_assigned = $self->get_serviceprofile_services($serviceprofilename);
    if ( grep { $_ eq $servicename } @services_assigned ) {
	$self->debug( 'verbose', "Serviceprofile $serviceprofilename already has service $servicename assigned" );
	return 1 if $apply ne 'apply';
    }
    else {
	my $result;
	eval {
	    my @values = ( $servicename_id, $sprf_id );
	    $result = monarchWrapper->insert_obj( 'serviceprofile', \@values );
	};
	if ($@) {
	    $self->debug( 'error', "database access error in assign_service_to_serviceprofile($servicename, $serviceprofilename, $apply, $replace)" );
	    return undef;
	}
	if ( $result =~ /Error/ ) {
	    $self->debug( 'error', "insert failed: $result. Could not assign $servicename to serviceprofile $serviceprofilename" );
	    return undef;
	}
    }

    if ($apply) {
	my @hostids = $self->get_hosts_with_serviceprofile($serviceprofilename);

	my $replacestring = $replace ? 'replace' : 'merge';

	$self->debug( 'verbose',
	    "applying serviceprofile $serviceprofilename with ID $sprf_id on hosts with IDs @hostids with $replacestring option" );

	my $profcnt;
	my $errormsg;
	eval { ( $profcnt, $errormsg ) = monarchWrapper->service_profile_apply( [$sprf_id], $replacestring, \@hostids ); };
	if ($@) {
	    $self->debug( 'error',
		"database access error in assign_service_to_serviceprofile($servicename, $serviceprofilename, $apply, $replace)" );
	    return undef;
	}
	if (@$errormsg) {
	    $self->debug( 'error', 'Error applying service profile to hosts: ' . join( ', ', @$errormsg ) );
	    return 0;
	}
    }

    return 1;
}

## @method arrayref or array get_serviceprofile_services (string serviceprofilename)
# Get names of generic services assigned to a serviceprofile.
# @param serviceprofilename name of the serviceprofile whose assigned service names are to be retrieved
# @return servicenames:  in list context, an array of services assigned to the specified serviceprofile, or an empty list if the
# search failed (e.g., due to database error); in scalar context, an arrayref to such a list, or undef if the search failed
sub get_serviceprofile_services {
    my $self               = shift;
    my $serviceprofilename = $_[0];
    my @services           = ();

    my $sprf_id = $self->get_serviceprofileid($serviceprofilename);
    if ( not $sprf_id ) {
	## Either non-existence or database error; in list context, our caller won't be able to distinguish.
	$self->debug( 'error', "Cannot find serviceprofile with name $serviceprofilename." );
	return wantarray ? () : $sprf_id;
    }

    my %result;
    eval {
	%result = monarchWrapper->get_service_profiles($sprf_id);
    };
    if ($@) {
	$self->debug( 'error', "database access error in get_serviceprofile_services($serviceprofilename)" );
	return wantarray ? () : undef;
    }
    @services = keys %result;
    return wantarray ? @services : \@services;
}

## @method boolean assign_and_apply_serviceprofile_to_host (string hostname, string serviceprofilename, boolean replace)
# Assign a service profile to a host, and apply the corresponding services to that host.
# @param hostname name of the host to which the serviceprofile is to be assigned and applied
# @param serviceprofilename name of the serviceprofile to assign and apply to the host
# @param replace True, if existing services should be replaced by services in the service profile. False, if services should be merged.
# @return status: true if successful, false otherwise
sub assign_and_apply_serviceprofile_to_host {
    my $self               = shift;
    my $hostname           = $_[0];
    my $serviceprofilename = $_[1];
    my $replace            = $_[2];

    my $host_id = $self->get_hostid($hostname);
    if ( not $host_id ) {
	$self->debug( 'error', "no valid host_id found for host $hostname" );
	## Return 0 or undef.
	return $host_id;
    }
    my $serviceprofile_id = $self->get_serviceprofileid($serviceprofilename);
    if ( not $serviceprofile_id ) {
	$self->debug( 'error', "no valid serviceprofile_id found for service profile $serviceprofilename" );
	## Return 0 or undef.
	return $serviceprofile_id;
    }

    my @values = ( $serviceprofile_id, $host_id );

    my @result = ();
    eval {
	my %where = ( 'serviceprofile_id' => $serviceprofile_id, 'host_id' => $host_id );
	@result = monarchWrapper->fetch_list_where( 'serviceprofile_host', 'host_id', \%where );
    };
    if ($@) {
	$self->debug( 'error', "database access error in assign_and_apply_serviceprofile_to_host($hostname, $serviceprofilename, $replace)" );
	return undef;
    }
    if (@result) {
	$self->debug( 'verbose', "service profile $serviceprofilename was already assigned to host $hostname" );
	## Just because the service profile was previously assigned to the host doesn't mean
	## all the services currently assigned to the profile are also already associated
	## with the host, so we don't stop here; we'll continue on to the apply steps.
    }
    else {
	$self->debug( 'verbose', "writing @values to table serviceprofile_host" );
	## FIX MAJOR:  handle exceptions here
	my $result = monarchWrapper->insert_obj( 'serviceprofile_host', \@values );
	if ( $result =~ /Error/ ) {
	    if ( $result =~ /duplicate/i ) {
		## We checked above, but this can still happen because of concurrent inserts by another actor.
		## In this case, we skip the "apply" portion, under the assmption that the concurrent actor
		## must be taking care of that.
		$self->debug( 'verbose', "service profile $serviceprofilename was being concurrently assigned to host $hostname" );
		return 1;
	    }
	    else {
		$self->debug( 'error', "could not assign serviceprofile_id $serviceprofile_id; error: $result" );
		return undef;
	    }
	}
    }

    my $replacestring = $replace ? 'replace' : 'merge';

    $self->debug( 'verbose',
	"applying serviceprofile $serviceprofilename with ID $serviceprofile_id on host $hostname with $replacestring option" );

    my $profcnt;
    my $errormsg;
    eval {
	( $profcnt, $errormsg ) = monarchWrapper->service_profile_apply( [$serviceprofile_id], $replacestring, [$host_id] );
    };
    if ($@) {
	$self->debug( 'error', "database access error in assign_and_apply_serviceprofile_to_host($hostname, $serviceprofilename, $replace)" );
	return undef;
    }

    # return false if errormsg not empty.
    if ( @{$errormsg} ) {
	$self->debug( 'error', "Error applying service profile $serviceprofilename: " . join( ', ', @{$errormsg} ) );
	return 0;
    }
    return 1;
}

## @method arrayref or array get_hosts_with_serviceprofile (string serviceprofilename)
# Get hosts that have a certain serviceprofile assigned.
# @param serviceprofilename name of the serviceprofile whose associated hostnames are to be retrieved
# @return hostids:  in list context, an array of host_id values for the hosts which have the specified serviceprofile assigned, or an empty list
# if the search failed (e.g., due to database error); in scalar context, an arrayref to such a list, or undef if the search failed
sub get_hosts_with_serviceprofile {
    my $self               = shift;
    my $serviceprofilename = $_[0];
    my @host_ids           = ();

    my $sprf_id = $self->get_serviceprofileid($serviceprofilename);
    if ( not $sprf_id ) {
	## Either non-existence or database error; in list context, our caller won't be able to distinguish.
	$self->debug( 'error', "Cannot find serviceprofile with name $serviceprofilename." );
	return wantarray ? () : $sprf_id;
    }

    eval {
	my %where = ( 'serviceprofile_id' => $sprf_id );
	@host_ids = monarchWrapper->fetch_list_where( 'serviceprofile_host', 'host_id', \%where );
    };
    if ($@) {
	$self->debug( 'error', "database access error in get_hosts_with_serviceprofile($serviceprofilename)" );
	return wantarray ? () : undef;
    }
    return wantarray ? @host_ids : \@host_ids;
}

## @method boolean remove_serviceprofile_from_host (string hostname, string serviceprofilename)
# Remove a directly-assigned service profile from a host.  Will not affect services previously applied using that service profile.
# @param hostname name of the host from which the serviceprofile should be removed
# @param serviceprofilename name of the serviceprofile to remove from the host
# @return status: true if successful, false otherwise
sub remove_serviceprofile_from_host {
    my $self               = shift;
    my $hostname           = $_[0];
    my $serviceprofilename = $_[1];

    $self->debug( 'verbose', "called remove_serviceprofile_from_host($hostname, $serviceprofilename)" );

    my $host_id = $self->get_hostid($hostname);
    if ( not $host_id ) {
	$self->debug( 'error', "host $hostname not found" );
	return $host_id;
    }
    my $serviceprofile_id = $self->get_serviceprofileid($serviceprofilename);
    if ( not $serviceprofile_id ) {
	$self->debug( 'error', "no valid serviceprofile_id found for service profile $serviceprofilename" );
	return $serviceprofile_id;
    }

    my $result;
    eval {
	my %where = ( 'serviceprofile_id' => $serviceprofile_id, 'host_id' => $host_id );
	$result = monarchWrapper->delete_one_where( 'serviceprofile_host', \%where );
    };
    if ($@) {
	$self->debug( 'error', "database access error in remove_serviceprofile_from_host($hostname, $serviceprofilename)" );
	return undef;
    }
    if ( $result =~ /Error/ ) {
	$self->debug( 'error', "service profile $serviceprofilename not removed from host $hostname: $result" );
	return undef;
    }
    return 1;
}

## @method boolean create_hostgroup (string hostgroupname, string alias)
# Create a new hostgroup.
# @param hostgroupname name for the new hostgroup
# @param alias alias for the new hostgroup
# @return status: true if successful, false otherwise
sub create_hostgroup {
    my $self          = shift;
    my $hostgroupname = shift;
    my $alias         = shift;

    if ( $self->hostgroup_exists($hostgroupname) ) {
	$self->debug( 'error', "Hostgroup $hostgroupname exists already" );
	return 0;
    }

    if ( not $alias ) {
	$self->debug( 'error', "Alias for hostgroup $hostgroupname not given, cannot be empty" );
	return 0;
    }

    my $result;
    eval {
	my @vals = ( \undef, $hostgroupname, $alias, '', '', '', '', '', '' );
	$result = monarchWrapper->insert_obj( 'hostgroups', \@vals );
    };
    if ($@) {
	$self->debug( 'error', "database access error in create_hostgroup($hostgroupname, $alias)" );
	return undef;
    }

    if ( $result =~ /^Error/ && $result !~ /duplicate/i ) {
	$self->debug( 'error', "creating hostgroup $hostgroupname results: $result" );
	return undef;
    }
    else {
	$self->debug( 'verbose', "creating hostgroup $hostgroupname results: $result" );
    }

    return 1;
}

## @method boolean assign_hostgroup (string hostname, string hostgroup)
# Assign a host to a hostgroup.
# @param hostname name of the host to be assigned to the hostgroup
# @param hostgroup name of the hostgroup the host shall join
# @return status: true if operation successful, else false
sub assign_hostgroup {
    my $self      = shift;
    my $hostname  = $_[0];
    my $hostgroup = $_[1];
    local $_;

    ## FIX MAJOR:  handle exceptions here
    my $auth = monarchWrapper->dbconnect();
    $self->debug( 'verbose', "Assign Hostgroup $hostgroup to host $hostname" );

    my $host_id = $self->get_hostid($hostname);
    if (not $host_id) {
	$self->debug( 'error', "Host $hostname not found" );
	return $host_id;
    }
    $self->debug( 'verbose', "Host $hostname found with ID: $host_id" );
    my %group = ();
    eval {
	%group = monarchWrapper->fetch_one( 'hostgroups', 'name', $hostgroup );
    };
    if ($@) {
	$self->debug( 'error', "database access error in assign_hostgroup($hostname, $hostgroup)" );
	return undef;
    }
    if (not %group) {
	$self->debug( 'error', "Hostgroup $hostgroup not found" );
	return 0;
    }
    $self->debug( 'verbose', "Hostgroup $hostgroup found with ID: $group{'hostgroup_id'}" );
    my @vals = ( $group{'hostgroup_id'}, $host_id );

    # check if entry is already there
    my @hostgroups = ();
    eval {
	@hostgroups = monarchWrapper->get_host_hostgroups($hostname);
    };
    if ($@) {
	$self->debug( 'error', "database access error in assign_hostgroup($hostname, $hostgroup)" );
	return undef;
    }
    $self->debug( 'verbose', "Assigned hostgroups found: @hostgroups" );
    if ( grep { $_ eq $hostgroup } @hostgroups ) {
	$self->debug( 'info', "Host $hostname is already a member of hostgroup $hostgroup. skipping" );
    }
    else {
	## Insert assignment
	## FIX MAJOR:  handle exceptions here
	my $result = monarchWrapper->insert_obj( 'hostgroup_host', \@vals );
	if ( $result =~ /Error/ ) {
	    $self->debug( 'error', "insert failed: $result" );
	    return undef;
	}
	else {
	    $self->debug( 'verbose', "insert result: $result" );
	}
    }
    return 1;
}

## @method boolean remove_host_from_hostgroup (string hostname, string hostgroup)
# Remove one host from a hostgroup.
# @param hostname name of the host to be removed from the hostgroup
# @param hostgroup name of the hostgroup the host shall be removed from
# @return status: true if operation successful, else false
sub remove_host_from_hostgroup {
    my $self      = shift;
    my $hostname  = $_[0];
    my $hostgroup = $_[1];
    local $_;

    $self->debug( 'verbose', "Remove host $hostname from hostgroup $hostgroup" );

    my $host_id = $self->get_hostid($hostname);
    if ( not $host_id ) {
	$self->debug( 'error', "Host $hostname not found" );
	return $host_id;    # will be either 0 or undef, not an actual host_id
    }
    $self->debug( 'verbose', "Host $hostname found with ID: $host_id" );
    my %group = ();
    eval {
	%group = monarchWrapper->fetch_one( 'hostgroups', 'name', $hostgroup );
    };
    if ($@) {
	$self->debug( 'error', "database access error in remove_host_from_hostgroup($hostname, $hostgroup)" );
	return undef;
    }
    if ( not %group ) {
	$self->debug( 'error', "Hostgroup $hostgroup not found" );
	return 0;
    }
    $self->debug( 'verbose', "Hostgroup $hostgroup found with ID: $group{'hostgroup_id'}" );
    eval {
	my @hostgroups = monarchWrapper->get_host_hostgroups($hostname);
	$self->debug( 'verbose', "Hostgroups assigned to $hostname found as: @hostgroups" );
	if ( not grep { $_ eq $hostgroup } @hostgroups ) {
	    $self->debug( 'info', "Host $hostname is not a member of hostgroup $hostgroup; skipping removal" );
	}
	else {
	    ## Remove assignment
	    my $hostgroup_id = $group{'hostgroup_id'};
	    my %where        = ( 'host_id' => $host_id, 'hostgroup_id' => $hostgroup_id );
	    my $result       = monarchWrapper->delete_one_where( 'hostgroup_host', \%where );
	    if ( $result =~ /Error/ ) {
		$self->debug( 'error', "Delete failed: $result" );
		die "$result\n";
	    }
	    else {
		$self->debug( 'verbose', "Delete result: $result" );
	    }
	}
    };
    if ($@) {
	$self->debug( 'error', "database access error in remove_host_from_hostgroup($hostname, $hostgroup)" );
	return undef;
    }
    return 1;
}

## @method boolean create_servicegroup (string servicegroupname, string alias, string service_escalation, string notes)
# Create a new servicegroup.
# @param servicegroupname name of the new servicegroup
# @param alias alias for the new servicegroup
# @param service_escalation (optional) name of the service escalation tree for the new servicegroup
# @param notes (optional) notes about the new servicegroup
# @return status: true if successful, false otherwise
sub create_servicegroup {
    my $self               = shift;
    my $servicegroupname   = shift;
    my $alias              = shift;
    my $service_escalation = shift;
    my $notes              = shift;
    my $escalation_id      = '';

    if ( $self->servicegroup_exists($servicegroupname) ) {
	$self->debug( 'error', "Servicegroup $servicegroupname already exists" );
	return 0;
    }

    if ( not $alias ) {
	$self->debug( 'error', "Alias for servicegroup $servicegroupname not given; cannot be empty" );
	return 0;
    }

    # we need to find the service_escalation id, if this optional parameter is given
    if ($service_escalation) {
	$escalation_id = $self->get_escalation_tree_id( $service_escalation, 'service' );
	if ( !$escalation_id or $escalation_id < 1 ) {
	    $self->debug( 'warning',
		"Service Escation Tree $service_escalation not found. Ignoring while creating service_group $servicegroupname" );
	    $escalation_id = '';
	}
    }

    if ( not $notes ) {
	$self->debug( 'verbose', "No notes given for service_group $servicegroupname." );
	$notes = '';
    }

    my $result;
    eval {
	my @vals = ( \undef, $servicegroupname, $alias, $escalation_id, '', $notes );
	$result = monarchWrapper->insert_obj( 'servicegroups', \@vals );
    };
    if ($@) {
	## $service_escalation might be undef, so we don't want to force its substitution here.
	$self->debug( 'error', "database access error in create_servicegroup($servicegroupname, $alias, ...)" );
	return undef;
    }
    if ( $result =~ /^Error/ && $result !~ /duplicate/i ) {
	$self->debug( 'error', "creating servicegroup $servicegroupname results: $result" );
	return undef;
    }
    else {
	$self->debug( 'verbose', "creating servicegroup $servicegroupname results: $result" );
    }

    return 1;
}

## @method boolean assign_servicegroup (string host, string service, string servicegroup)
# Assign a specific host's service to a servicegroup.
# @param host name of the host on which the service to be included in the servicegroup resides
# @param service name of the host's service
# @param servicegroup name of the servicegroup which the host service will now be a member of
# @return status: true if successful (if service is already a group member, too); false otherwise
sub assign_servicegroup {
    my $self         = shift;
    my $host         = $_[0];
    my $service      = $_[1];
    my $servicegroup = $_[2];
    my $auth         = monarchWrapper->dbconnect();
    $self->debug( 'verbose', "Assign Service $service on $host to servicegroup $servicegroup" );
    my %svcgrp = ();
    eval {
	%svcgrp = monarchWrapper->fetch_one( 'servicegroups', 'name', $servicegroup );
    };
    if ($@) {
	$self->debug( 'error', "database access error in assign_servicegroup($host, $service, $servicegroup)" );
	return undef;
    }
    if ( not %svcgrp ) {
	$self->debug( 'error', "no servicegroup $servicegroup found." );
	return 0;
    }

    my %h = ();
    eval {
	%h = monarchWrapper->fetch_one( 'hosts', 'name', $host );
    };
    if ($@) {
	$self->debug( 'error', "database access error in assign_servicegroup($host, $service, $servicegroup)" );
	return undef;
    }
    if ( not %h ) {
	$self->debug( 'error', "no host $host found." );
	return 0;
    }
    my %sn = monarchWrapper->fetch_one( 'service_names', 'name', $service );
    my %where = ( 'host_id' => $h{'host_id'}, 'servicename_id' => $sn{'servicename_id'} );
    my %s = monarchWrapper->fetch_one_where( 'services', \%where );
    if ( not %s ) {
	$self->debug( 'error', "no service $service found on host $host." );
	return 0;
    }
    my @values = ( $svcgrp{'servicegroup_id'}, $h{'host_id'}, $s{'service_id'} );
    my $result = monarchWrapper->insert_obj( 'servicegroup_service', \@values );
    if ( $result =~ /^Error/ && $result !~ /duplicate/i ) {
	$self->debug( 'error', "assigning servicegroup $result" );
	return undef;
    }
    else {
	$self->debug( 'verbose', "assigning servicegroup results with: $result" );
    }
    return 1;
}

## @method boolean set_generic_service_command (string servicename, string commandname)
# Set the command for a named generic service.
# @param servicename name of the generic service whose Nagios command should be set
# @param commandname name of the Nagios command that should be assigned to the generic service
# @return status: true if successful, false otherwise
sub set_generic_service_command {
    my $self        = shift;
    my $servicename = $_[0];
    my $commandname = $_[1];

    my $command_id = $self->get_command_id($commandname);
    if ( not $command_id ) {
	## Either non-existence or database error.
	$self->debug( 'error', "Cannot find command_id for command $commandname" );
	return $command_id;
    }
    my $results;
    eval {
	my %values = ( check_command => $command_id );
	$results = monarchWrapper->update_obj( 'service_names', 'name', $servicename, \%values );
    };
    if ($@) {
	$self->debug( 'error', "database access error in set_generic_service_command($servicename, $commandname)" );
	return undef;
    }
    if ( $results == 1 ) {
	$self->debug( 'verbose', "Setting command for service $servicename to $commandname is done" );
	return 1;
    }
    else {
	$self->debug( 'error', "Setting command for service $servicename to $commandname FAILED: $results" );
	return 0;
    }
}

## @method boolean set_generic_service_commandline (string servicename, string commandline)
# Set the commandline for a named generic service.
# @param servicename name of the generic service whose commandline should be set
# @param commandline text of the commandline to be run for the generic service
# @return status: true if successful, false otherwise
sub set_generic_service_commandline {
    my $self        = shift;
    my $servicename = $_[0];
    my $commandline = $_[1];
    my $results;
    eval {
	my %values = ( command_line => $commandline );
	$results = monarchWrapper->update_obj( 'service_names', 'name', $servicename, \%values );
    };
    if ($@) {
	$self->debug( 'error', "database access error in set_generic_service_commandline($servicename, $commandline)" );
	return undef;
    }
    if ( $results == 1 ) {
	$self->debug( 'verbose', "Setting commandline for service $servicename to $commandline done" );
	return 1;
    }
    else {
	$self->debug( 'error', "Setting commandline for service $servicename to $commandline FAILED: $results" );
	return 0;
    }
}

## @method boolean set_host_overrides_properties (string hostname, hashref propref)
# Override host properties for a particular host.
# @param hostname name of the host whose properties are to be overridden
# @param propref reference to a hash which contains key-value pairs of properties to override inherited host template settings
# @return status: true if setting works, false otherwise
sub set_host_overrides_properties {
    my $self     = shift;
    my $hostname = $_[0];
    my $propref  = $_[1];
    local $_;

    my %properties = %$propref;
    my $xml_props  = gwxml->new();
    my $result;
    my $propertystring;

    my $host_id = $self->get_hostid($hostname);
    if ( not $host_id ) {
	$self->debug( 'error', "No ID found for host $hostname " );
	return $host_id;
    }

    foreach my $prop ( keys %properties ) {
	$self->debug( 'verbose', "adding property $prop : $properties{$prop} to $hostname " );
	$xml_props->add_prop( $prop, $properties{$prop} );
    }

    # Check, if there is an existing entry
    my %queryresults = ();
    eval {
	%queryresults = monarchWrapper->fetch_one( 'host_overrides', 'host_id', $host_id );
    };
    if ($@) {
	$self->debug( 'error', "database access error in set_host_overrides_properties($hostname, ...)" );
	return undef;
    }

    if (%queryresults) {
	$self->debug( 'verbose', "entry found with host id $host_id" );

	foreach my $oldprop ( keys %queryresults ) {
	    if (   $oldprop ne 'notification_period'
		&& $oldprop ne 'event_handler'
		&& $oldprop ne 'host_id'
		&& $oldprop ne 'check_period'
		&& $oldprop ne 'check_command' )
	    {
		$self->debug( 'verbose', 'Found Host Property ' . $oldprop . ' with value: ' . $queryresults{$oldprop} );

		# if this oldprop is not to be overwritten by new settings, we have to keep it and write it back to the record
		if ( !( grep { $_ eq $oldprop } ( keys %properties ) ) ) {
		    $self->debug( 'verbose', "Property $oldprop will be kept and not modified" );
		    $xml_props->add_prop( $oldprop, $queryresults{$oldprop} );
		}
	    }
	}

	$propertystring = $xml_props->toString;
	$self->debug( 'verbose', "service xml properties string: $propertystring" );
	eval {
	    my %vals = ( 'data' => $propertystring );
	    $result = monarchWrapper->update_obj( 'host_overrides', 'host_id', $host_id, \%vals );
	};
	if ($@) {
	    $self->debug( 'error', "database access error in set_host_overrides_properties($hostname, ...)" );
	    return undef;
	}
    }
    else {
	$self->debug( 'verbose', "No entry found with host id $host_id" );
	$propertystring = $xml_props->toString;
	$self->debug( 'verbose', "service xml properties string: $propertystring" );
	eval {
	    my @vals = ( $host_id, '', '', '', '', $propertystring );
	    $result = monarchWrapper->insert_obj( 'host_overrides', \@vals );
	};
	if ($@) {
	    $self->debug( 'error', "database access error in set_host_overrides_properties($hostname, ...)" );
	    return undef;
	}
    }

    if ( $result =~ /^Error/ ) {
	$self->debug( 'error', "Could not set properties for host $hostname. Error: $result" );
	return undef;
    }
    else {
	$self->debug( 'verbose', "Successfully set properties $propertystring on $hostname " );
    }

    return 1;
}

## @method boolean set_service_overrides_properties (string hostname, string servicename, hashref propref)
# Override service properties for a particular service definition on a particular host.
# @param hostname name of the host on which the service whose properties are to be overridden resides
# @param servicename name of the service whose properties are to be overridden
# @param propref reference to a hash which contains key-value pairs of properties to override inherited service template settings
# @return status: true if successful, false otherwise
sub set_service_overrides_properties {
    my $self        = shift;
    my $hostname    = $_[0];
    my $servicename = $_[1];
    my $propref     = $_[2];
    local $_;

    my %properties = %$propref;
    my $xml_props  = gwxml->new();
    my $result;
    my $propertystring;

    my $host_service_id = $self->get_host_serviceid( $hostname, $servicename );
    if ( not $host_service_id ) {
	$self->debug( 'error', "No ID found for host $hostname service $servicename" );
	return $host_service_id;
    }

    foreach my $prop ( keys %properties ) {
	$self->debug( 'verbose', "adding property $prop : $properties{$prop} to $hostname / $servicename" );
	$xml_props->add_prop( $prop, $properties{$prop} );
    }

    my %queryresults = ();
    eval {
	%queryresults = monarchWrapper->fetch_one( 'service_overrides', 'service_id', $host_service_id );
    };
    if ($@) {
	$self->debug( 'error', "database access error in set_service_overrides_properties($hostname, $servicename, ...)" );
	return undef;
    }

    if (%queryresults) {
	$self->debug( 'verbose', "entry found with $host_service_id" );
	foreach my $oldprop ( keys %queryresults ) {
	    if ( $oldprop ne 'notification_period' && $oldprop ne 'event_handler' && $oldprop ne 'service_id' && $oldprop ne 'check_period' ) {
		$self->debug( 'verbose', 'Found Property ' . $oldprop . ' with value: ' . $queryresults{$oldprop} );

		# if this oldprop is not to be overwritten by new settings, we have to keep it and write it back to the record
		if ( !( grep { $_ eq $oldprop } ( keys %properties ) ) ) {
		    $self->debug( 'verbose', "Property $oldprop will be kept and not modified" );
		    $xml_props->add_prop( $oldprop, $queryresults{$oldprop} );
		}
	    }
	}
	$propertystring = $xml_props->toString;
	$self->debug( 'verbose', "service xml properties string: $propertystring" );
	eval {
	    my %vals = ( 'data' => $propertystring );
	    $result = monarchWrapper->update_obj( 'service_overrides', 'service_id', $host_service_id, \%vals );
	};
	if ($@) {
	    $self->debug( 'error', "database access error in set_service_overrides_properties($hostname, $servicename, ...)" );
	    return undef;
	}
    }
    else {
	$self->debug( 'verbose', "No entry found with $host_service_id" );
	$propertystring = $xml_props->toString;
	$self->debug( 'verbose', "service xml properties string: $propertystring" );
	eval {
	    my @vals = ( $host_service_id, '', '', '', $propertystring );
	    $result = monarchWrapper->insert_obj( 'service_overrides', \@vals );
	};
	if ($@) {
	    $self->debug( 'error', "database access error in set_service_overrides_properties($hostname, $servicename, ...)" );
	    return undef;
	}
    }

    if ( $result =~ /^Error/ ) {
	$self->debug( 'error', "Could not set properties for service $servicename on host $hostname. Error: $result" );
	return undef;
    }
    else {
	$self->debug( 'verbose', "Successfully set properties $propertystring on $hostname / $servicename" );
    }

    return 1;
}

## @method boolean set_host_service_notification_interval (string hostname, string servicename, int interval)
# Set the notification interval for a host service.
# @param hostname name of the host on which the service resides
# @param servicename name of the service for which the notification interval should be set
# @param interval notification interval in seconds
# @return status: true if successful, false otherwise
sub set_host_service_notification_interval {
    my $self        = shift;
    my $hostname    = $_[0];
    my $servicename = $_[1];
    my $interval    = $_[2];
    if ( $interval == 0 ) { $interval = "-zero-"; }
    my %props = ( 'notification_interval' => $interval );
    return $self->set_service_overrides_properties( $hostname, $servicename, \%props );
}

## @method boolean set_host_service_freshness_threshold (string hostname, string servicename, int threshold)
# Set the freshness threshold for a host service.
# @param hostname name of the host on which the service resides
# @param servicename name of the service for which the freshness threshold should be set
# @param threshold freshness threshold in seconds
# @return status: true if successful, false otherwise
sub set_host_service_freshness_threshold {
    my $self        = shift;
    my $hostname    = $_[0];
    my $servicename = $_[1];
    my $threshold   = $_[2];
    if ( $threshold == 0 ) { $threshold = "-zero-"; }
    my %props = ( 'freshness_threshold' => $threshold );
    return $self->set_service_overrides_properties( $hostname, $servicename, \%props );
}

## @method boolean add_service (string hostname, string service)
# Add a generic service to a host, thereby creating a host service.
# @param hostname name of the host to which the service will be added
# @param service name of the service to add to the host
# @return status: true if successful, false otherwise
sub add_service {
    my $self     = shift;
    my $hostname = $_[0];
    my $service  = $_[1];
    my @errors;
    $self->debug( 'verbose', "Try to add service $service to host $hostname ..." );
    if ($service) {
	my %s = ();
	eval {
	    %s = monarchWrapper->fetch_one( 'service_names', 'name', $service );
	};
	if ($@) {
	    $self->debug( 'error', "database access error in add_service($hostname, $service)" );
	    return undef;
	}
	## FIX MAJOR:  handle exceptions here
	my %properties = monarchWrapper->fetch_host($hostname);
	if ( defined $properties{'errors'} ) {
	    $self->debug( 'error', "Adding $service to host $hostname failed: " . join( "\n", @{ $properties{'errors'} } ) );
	    return 0;
	}
	my @values = (
	    \undef,             $properties{'host_id'}, $s{'servicename_id'}, $s{'template'},
	    $s{'extinfo'},      $s{'escalation'},       '1',                  $s{'check_command'},
	    $s{'command_line'}, '',                     ''
	);
	## FIX MAJOR:  handle exceptions here
	my $id = monarchWrapper->insert_obj_id( 'services', \@values, 'service_id' );
	if ( $id =~ /^Error/ ) {
	    $self->debug( 'error', "Adding $service to host $hostname failed: $id" );
	    return undef;
	}
	else {
	    ## FIX MAJOR:  handle exceptions here
	    my %so = monarchWrapper->fetch_one( 'servicename_overrides', 'servicename_id', $s{'servicename_id'} );
	    my $data = "<?xml version=\"1.0\" encoding=\"iso-8859-1\" ?>\n<data>";
	    foreach my $prop ( keys %so ) {
		unless ( $prop =~ /check_period|notification_period|event_handler|servicename_id/ ) {
		    $data .= "\n  <prop name=\"$prop\"><![CDATA[$so{$prop}]]>\n  </prop>";
		}
	    }
	    $data .= "\n</data>";
	    ## FIX MAJOR:  handle exceptions here
	    @values = ( $id, $so{'check_period'}, $so{'notification_period'}, $so{'event_handler'}, $data );
	    my $result = monarchWrapper->insert_obj( 'service_overrides', \@values );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	    if ( $s{'dependency'} ) {
		## FIX MAJOR:  handle exceptions here
		my %t = monarchWrapper->fetch_one( 'service_dependency_templates', 'name', $s{'dependency'} );
		@values = ( \undef, $id, $properties{'host_id'}, $properties{'host_id'}, $s{'dependency'}, '' );
		my $result = monarchWrapper->insert_obj( 'service_dependency', \@values );
		if ( $result =~ /^Error/ ) { push @errors, $result }
	    }

	    # transfer contactgroups
	    ## FIX MAJOR:  handle exceptions here
	    my %where = ( 'servicename_id' => $s{'servicename_id'} );
	    my @contactgroups = monarchWrapper->fetch_list_where( 'contactgroup_service_name', 'contactgroup_id', \%where );
	    foreach my $group (@contactgroups) {
		my @values = ( $group, $id );
		monarchWrapper->insert_obj( 'contactgroup_service', \@values );
	    }
	}
    }
    if (@errors) {
	$self->debug( 'error', "Adding $service to host $hostname incomplete, errors occurred: " . join( "\n", @errors ) );
	return 0;
    }
    return 1;
}

## @method boolean remove_service (string hostname, string servicename)
# Remove a service from a host.
# @param hostname name of the host from which the service will be removed
# @param servicename name of the service to be removed from the host
# @return status: true if successful, false otherwise
sub remove_service {
    my $self        = shift;
    my $hostname    = $_[0];
    my $servicename = $_[1];

    $self->debug( 'verbose', "called remove_service($hostname, $servicename)" );

    # We delete by host_id and servicename_id instead of by service_id because that way, we
    # don't generate an error during lookup if the particular host service is already gone.
    my $host_id = $self->get_hostid($hostname);
    if ( not $host_id ) {
	$self->debug( 'error', "host $hostname not found" );
	return $host_id;
    }
    my $servicename_id = $self->get_serviceid($servicename);
    if ( not $servicename_id ) {
	$self->debug( 'error', "service $servicename not found" );
	return $servicename_id;
    }

    my $result;
    eval {
	my %where = ( 'host_id' => $host_id, 'servicename_id' => $servicename_id );
	$result = monarchWrapper->delete_one_where( 'services', \%where );
    };
    if ($@) {
	$self->debug( 'error', "database access error in remove_service($hostname, $servicename)" );
	return undef;
    }
    if ( $result =~ /Error/ ) {
	$self->debug( 'error', "service $servicename not removed from host $hostname: $result" );
	return undef;
    }

    # In theory, we perhaps ought to delete from stage_host_services as well,
    # since it doesn't use a foreign key reference with a cascading delete.

    # We don't also delete from the host_service table, because
    # that should be delayed until Commit time, if even then.

    # All other necessary deletes are handled by cascading deletes at the database level.

    return 1;
}

## @method boolean apply_host_template (string hostname, string host_template)
# Apply a host_template to a host.
# @param hostname name of the host to which the host template should be applied
# @param host_template name of the host template to apply
# @return status: true if successful, else false
sub apply_host_template {
    my $self          = shift;
    my $hostname      = $_[0];
    my $host_template = $_[1];
    $self->debug( 'verbose', "Trying to apply host template $host_template to host $hostname" );

    my $host_id = $self->get_hostid($hostname);
    if ( not $host_id ) {
	$self->debug( 'error', "Cannot find host_id for host $hostname" );
	return $host_id;
    }
    my $host_template_id = $self->get_host_template_id($host_template);
    if ( not $host_template_id ) {
	$self->debug( 'error', "Cannot find template ID for host_template $host_template" );
	return $host_template_id;
    }

    my $result;
    eval {
	my %vals = ( 'hosttemplate_id' => $host_template_id );
	$result = monarchWrapper->update_obj( 'hosts', 'host_id', $host_id, \%vals );
    };
    if ($@) {
	$self->debug( 'error', "database access error in apply_host_template($hostname, $host_template)" );
	return undef;
    }
    if ( $result =~ /^Error/ ) {
	$self->debug( 'error', "assigning host_template ID $host_template_id to host with ID $host_id" );
	return undef;
    }
    return 1;
}

## @method boolean apply_service_template (string servicename, string service_template)
# Apply a service_template to a service.
# @param servicename name of the generic service to which the service template should be applied
# @param service_template name of the service template to apply
# @return status: true if successful, else false
sub apply_service_template {
    my $self             = shift;
    my $servicename      = $_[0];
    my $service_template = $_[1];

    my $servicename_id = $self->get_serviceid($servicename);
    if ( not $servicename_id ) {
	$self->debug( 'error', "Cannot find servicename_id for service $servicename" );
	return $servicename_id;
    }
    my $service_template_id = $self->get_service_template_id($service_template);
    if ( not $service_template_id ) {
	$self->debug( 'error', "Cannot find template ID for service_template $service_template" );
	return $service_template_id;
    }

    $self->debug( 'verbose',
	"Trying to apply service template $service_template (ID $service_template_id) to service $servicename (ID $servicename_id)" );
    my $result;
    eval {
	my %vals = ( 'template' => $service_template_id );
	$result = monarchWrapper->update_obj( 'service_names', 'servicename_id', $servicename_id, \%vals );
    };
    if ($@) {
	$self->debug( 'error', "database access error in apply_service_template($servicename, $service_template)" );
	return undef;
    }
    if ( $result =~ /^Error/ ) {
	$self->debug( 'error', "assigning service_template ID $service_template_id to service with ID $servicename_id" );
	return undef;
    }
    return 1;
}

## @method boolean create_extended_host_info_template (string template_name, string notes, string notes_url, string action_url, string icon_image, string icon_image_alt, string statusmap_image, string vrml_image)
# Create an extended host info template. Use empty strings, if particular fields should not be defined.
# @param template_name name for the new extended host info template
# @param notes additional notes
# @param notes_url URL for additional notes
# @param action_url URL for action to display
# @param icon_image icon filename for this extended host info template
# @param icon_image_alt alternative text for icon
# @param statusmap_image filename for the icon to be displayed on the Nagios status map
# @param vrml_image icon filename for 3D VRML map
# @return status: true if successful, false otherwise
sub create_extended_host_info_template {
    my $self          = shift;
    my $template_name = shift;
    my %params        = (
	notes           => $_[0],
	notes_url       => $_[1],
	action_url      => $_[2],
	icon_image      => $_[3],
	icon_image_alt  => $_[4],
	statusmap_image => $_[5],
	vrml_image      => $_[6],
    );

    if ( $self->host_extinfo_template_exists($template_name) ) {
	$self->debug( 'error', "Extended host info template $template_name already exists" );
	return 0;
    }

    my $xml_props = gwxml->new();
    my $propertystring;

    foreach my $prop ( keys(%params) ) {
	if ( $params{$prop} ) {
	    $self->debug( 'verbose', "Adding prop $prop with value " . $params{$prop} . " to template $template_name" );
	    $xml_props->add_prop( $prop, $params{$prop} );
	}
	else {
	    $self->debug( 'verbose', "Prop $prop not set for template $template_name" );
	}
    }

    $propertystring = $xml_props->toString;
    $self->debug( 'verbose', "service xml properties string: $propertystring" );
    my $result;
    eval {
	my @vals = ( \undef, $template_name, $propertystring, '', "# extended_host_info_templates $template_name added by dassmonarch" );
	$result = monarchWrapper->insert_obj( 'extended_host_info_templates', \@vals );
    };
    if ($@) {
	$self->debug( 'error', "database access error in create_extended_host_info_template($template_name, ...)" );
	return undef;
    }

    if ( $result =~ /^Error/ && $result !~ /duplicate/i ) {
	$self->debug( 'error', "creating host_ext_info_template $template_name results: $result" );
	return undef;
    }
    else {
	$self->debug( 'verbose', "creating host_ext_info_template $template_name results with: $result" );
    }

    return 1;
}

## @method boolean apply_extended_host_information_template (string hostname, string extended_host_information_template)
# Apply an extended host information template to a host.
# @param hostname name of the host to apply the template to
# @param extended_host_information_template name of the template to apply
# @return status: true if successful, else false
sub apply_extended_host_information_template {
    my $self                               = shift;
    my $hostname                           = $_[0];
    my $extended_host_information_template = $_[1];
    $self->debug( 'verbose', "Trying to apply extended host information template $extended_host_information_template to host $hostname" );

    my $host_id = $self->get_hostid($hostname);
    if ( not $host_id ) {
	$self->debug( 'error', "no valid host_id for host $hostname found" );
	return $host_id;
    }
    my $extended_host_information_template_id = $self->get_extended_host_information_template_id($extended_host_information_template);
    if ( not $extended_host_information_template_id ) {
	$self->debug( 'error', "no valid id found for extended_host_information_template $extended_host_information_template found" );
	return $extended_host_information_template_id;
    }

    my $result;
    eval {
	my %vals = ( 'hostextinfo_id' => $extended_host_information_template_id );
	$result = monarchWrapper->update_obj( 'hosts', 'host_id', $host_id, \%vals );
    };
    if ($@) {
	$self->debug( 'error',
	    "database access error in apply_extended_host_information_template($hostname, $extended_host_information_template)" );
	return undef;
    }
    if ( $result =~ /^Error/ ) {
	$self->debug( 'error', "assigning extended host information template $extended_host_information_template to host with id $host_id" );
	return undef;
    }
    return 1;
}

## @method int create_contact (string contact_name, string contact_alias, string contact_email, string contact_template, string contact_pager)
# Create a contact using a template.
# @param contact_name name of the new contact
# @param contact_alias alias for the new contact
# @param contact_email the new contact's email address
# @param contact_template name of the contact template to assign to the new contact
# @param contact_pager the new contact's pager number
# @return contact_id: > 0, if a contact was created;
# otherwise, 0 if a logical error occurred (e.g., the name already exists), undef if a database error occurred
sub create_contact {
    my $self             = shift;
    my $contact_name     = $_[0];
    my $contact_alias    = $_[1];
    my $contact_email    = $_[2];
    my $contact_template = $_[3];
    my $contact_pager    = $_[4];

    if ( $self->get_contact_id($contact_name) ) {
	$self->debug( 'error', "Contact with name $contact_name already exists. Cannot create" );
	return 0;
    }
    my $contact_template_id = $self->get_contact_template_id($contact_template);
    if ( not $contact_template_id ) {
	## Either non-existence or database error.
	$self->debug( 'error', "Cannot find ID for contact template $contact_template" );
	return $contact_template_id;
    }
    my $result;
    eval {
	my @values = (
	    \undef, $contact_name, $contact_alias, $contact_email, $contact_pager, $contact_template_id, '1', '# contact added via dassmonarch'
	);
	$result = monarchWrapper->insert_obj_id( 'contacts', \@values, 'contact_id' );
    };
    if ($@) {
	$self->debug( 'error',
	    "database access error in create_contact($contact_name, $contact_alias, $contact_email, $contact_template, $contact_pager)" );
	return undef;
    }
    if ( $result =~ /Error/ ) {
	$self->debug( 'error', "insert failed: $result. Could not create contact $contact_name" );
	return undef;
    }
    else {
	$self->debug( 'verbose', "Created contact $contact_name with result ID: $result" );
    }
    ## Could just return $result here and be done with it.
    return $self->get_contact_id($contact_name);
}

## @method int create_contactgroup (string contactgroup_name, string contactgroup_alias)
# Create an empty contactgroup.
# @param contactgroup_name name of the new contactgroup
# @param contactgroup_alias alias for the new contactgroup
# @return contactgroup_id: > 0, if a contactgroup was created;
# otherwise, 0 if a logical error occurred (e.g., the name already exists), undef if a database error occurred
sub create_contactgroup {
    my $self               = shift;
    my $contactgroup_name  = $_[0];
    my $contactgroup_alias = $_[1];

    if ( $self->get_contactgroup_id($contactgroup_name) ) {
	$self->debug( 'error', "Contact with name $contactgroup_name already exists. Cannot create" );
	return 0;
    }
    my $result;
    eval {
	my @values = ( \undef, $contactgroup_name, $contactgroup_alias, "# contactgroup added via dassmonarch" );
	$result = monarchWrapper->insert_obj_id( 'contactgroups', \@values, 'contactgroup_id' );
    };
    if ($@) {
	$self->debug( 'error', "database access error in create_contactgroup($contactgroup_name, $contactgroup_alias)" );
	return undef;
    }
    if ( $result =~ /Error/ ) {
	$self->debug( 'error', "insert failed: $result. Could not create contactgroup $contactgroup_name" );
	return undef;
    }
    else {
	$self->debug( 'verbose', "Created contactgroup $contactgroup_name with result ID: $result" );
    }
    ## Could just return $result here and be done with it.
    return $self->get_contactgroup_id($contactgroup_name);
}

## @method boolean delete_contact (string contact_name)
# Delete a contact from the monarch database.
# @param contact_name name of the contact to be deleted
# @return status: true if successful; false if the specified contact does not exist or if a database operation has failed.
sub delete_contact {
    my $self         = shift;
    my $contact_name = $_[0];

    my $contact_id = $self->get_contact_id($contact_name);
    if ( not $contact_id ) {
	## Either non-existence or database error.
	$self->debug( 'error', "Cannot find contact_id for contact $contact_name" );
	return $contact_id;
    }
    $self->debug( 'verbose', "Deleting contact $contact_name with ID $contact_id" );
    my $result;
    eval {
	$result = monarchWrapper->delete_all( 'contacts', 'contact_id', $contact_id );
    };
    if ($@) {
	$self->debug( 'error', "database access error in delete_contact($contact_name)" );
	return undef;
    }
    if ( $result ne '1' ) {
	$self->debug( 'error', "deleting contact $contact_name failed: $result" );
	return 0;
    }
    return 1;
}

## @method boolean delete_contactgroup (string contactgroup_name)
# Delete a contactgroup from the monarch database.
# @param contactgroup_name name of the contactgroup to be deleted
# @return status: true if successful; false if the specified contactgroup does not exist or if a database operation has failed.
sub delete_contactgroup {
    my $self             = shift;
    my $contactgroup_name = $_[0];

    my $contactgroup_id = $self->get_contactgroup_id($contactgroup_name);
    if ( not $contactgroup_id ) {
	## Either non-existence or database error.
	$self->debug( 'error', "Cannot find contactgroup_id for contactgroup $contactgroup_name" );
	return $contactgroup_id;
    }
    $self->debug( 'verbose', "Deleting contactgroup $contactgroup_name with ID $contactgroup_id" );
    my $result;
    eval {
	$result = monarchWrapper->delete_all( 'contactgroups', 'contactgroup_id', $contactgroup_id );
    };
    if ($@) {
	$self->debug( 'error', "database access error in delete_contactgroup($contactgroup_name)" );
	return undef;
    }
    if ( $result ne '1' ) {
	$self->debug( 'error', "deleting contactgroup $contactgroup_name failed: $result" );
	return 0;
    }
    return 1;
}

## @method int get_contact_template_id (string contacttemplatename)
# Find the contacttemplate_id for a named contact template.
# @param contacttemplatename name of the contact template to search for
# @return contacttemplate_id from table contact_templates, > 0 if the contact template exists;
# otherwise, 0 if the search succeeded (but found nothing), undef if the search failed (e.g., due to database error)
sub get_contact_template_id {
    my $self            = shift;
    my $contacttemplate = $_[0];
    my %results         = ();
    $self->debug( 'verbose', "called get_contact_template_id with $contacttemplate" );
    eval {
	%results = monarchWrapper->fetch_one( 'contact_templates', 'name', $contacttemplate );
    };
    if ($@) {
	$self->debug( 'error', "database access error in get_contact_template_id($contacttemplate)" );
	return undef;
    }
    return $results{'contacttemplate_id'} || 0;
}

## @method int get_contact_id (string contact_name)
# Find the contact_id for a named contact.
# @param contact_name name of the contact to search for
# @return contact_id from table contacts, > 0 if the contact exists;
# otherwise, 0 if the search succeeded (but found nothing), undef if the search failed (e.g., due to database error)
sub get_contact_id {
    my $self         = shift;
    my $contact_name = $_[0];
    my %results      = ();
    $self->debug( 'verbose', "called get_contact_id with $contact_name" );
    eval {
	%results = monarchWrapper->fetch_one( 'contacts', 'name', $contact_name );
    };
    if ($@) {
	$self->debug( 'error', "database access error in get_contact_id($contact_name)" );
	return undef;
    }
    return $results{'contact_id'} || 0;
}

## @method int get_contactgroup_id (string contactgroup_name)
# Find the contactgroup_id for a named contactgroup.
# @param contactgroup_name name of the contactgroup to search for
# @return contactgroup_id from table contactgroups, > 0 if the contact group exists;
# otherwise, 0 if the search succeeded (but found nothing), undef if the search failed (e.g., due to database error)
sub get_contactgroup_id {
    my $self              = shift;
    my $contactgroup_name = $_[0];
    my %results           = ();
    $self->debug( 'verbose', "called get_contactgroup_id with $contactgroup_name" );
    eval {
	%results = monarchWrapper->fetch_one( 'contactgroups', 'name', $contactgroup_name );
    };
    if ($@) {
	$self->debug( 'error', "database access error in get_contactgroup_id($contactgroup_name)" );
	return undef;
    }
    return $results{'contactgroup_id'} || 0;
}

## @method arrayref or array get_contactgroup_contacts (string contactgroup_name)
# Get a list of the contacts assigned to a certain contactgroup.
# @param contactgroup_name name of the contactgroup to search for
# @return contactnames: In list context, a list of contact names, or an empty list of the contactgroup does not exist,
# it has no associated contacts, or an error occurs (the latter case being indistinguishable from the logical conditions
# that can generate an empty list, so this mode of calling is not robust).  In scalar context, an arrayref for the
# list of contact names (which will be legitimately empty if the contactgroup does not exist or it has no associated
# contactgroups), or undef if an error occurs, which makes it easy to distinguish an error condition.
sub get_contactgroup_contacts {
    my $self              = shift;
    my $contactgroup_name = $_[0];
    my @contacts          = ();
    my $cgrp_id           = $self->get_contactgroup_id($contactgroup_name);
    if ( not $cgrp_id ) {
	## Either non-existence or database error; our caller won't be able to distinguish in array context.
	$self->debug( 'error', "Cannot find contactgroup with name $contactgroup_name." );
	return wantarray ? () : defined($cgrp_id) ? [] : undef;
    }
    eval {
	@contacts = monarchWrapper->get_contactgroup_contacts($cgrp_id);
    };
    if ($@) {
	$self->debug( 'error', "database access error in get_contactgroup_contacts($contactgroup_name)" );
	return wantarray ? () : undef;
    }
    return wantarray ? @contacts : \@contacts;
}

## @method string get_contactgroup_name (int contactgroup_id)
# Get the contactgroup name for a given ID.
# @param contactgroup_id ID of the contactgroup to search for
# @return contactgroup_name: the found contactgroup name if the contact group exists;
# otherwise, an empty string if the search succeeded (but found nothing), undef if the search failed (e.g., due to database error)
sub get_contactgroup_name {
    my $self            = shift;
    my $contactgroup_id = $_[0];
    my %results         = ();
    $self->debug( 'verbose', "called get_contactgroup_name with $contactgroup_id" );
    eval {
	%results = monarchWrapper->fetch_one( 'contactgroups', 'contactgroup_id', $contactgroup_id );
    };
    if ($@) {
	$self->debug( 'error', "database access error in get_contactgroup_name($contactgroup_id)" );
	return undef;
    }
    return $results{'name'} || '';
}

## @method arrayref or array get_hostgroup_contactgroups (string hostgroup_name)
# Get a list of the contactgroups assigned to a certain hostgroup.
# @param hostgroup_name name of the hostgroup to search for
# @return contactgroup_names: In list context, a list of contactgroup names, or an empty list if the hostgroup does
# not exist, it has no associated contactgroups, or an error occurs (the latter case being indistinguishable from the
# logical conditions that can generate an empty list, so this mode of calling is not robust). In scalar context, an
# arrayref for the list of contactgroup names (which will be legitimately empty if the hostgroup does not exist or it
# has no associated contactgroups), or undef if an error occurs, which makes it easy to distinguish an error condition.
sub get_hostgroup_contactgroups {
    my $self           = shift;
    my $hostgroup_name = $_[0];
    local $_;

    my @contactgroups = ();
    my $hgrp_id       = $self->get_hostgroupid($hostgroup_name);
    if ( not $hgrp_id ) {
	$self->debug( 'error', "Cannot find hostgroup with name $hostgroup_name." );
	return wantarray ? () : defined($hgrp_id) ? [] : undef;
    }
    my @cgrp_ids = ();
    eval {
	my %where = ( 'hostgroup_id' => $hgrp_id );
	@cgrp_ids = monarchWrapper->fetch_list_where( 'contactgroup_hostgroup', 'contactgroup_id', \%where );
    };
    if ($@) {
	$self->debug( 'error', "database access error in get_hostgroup_contactgroups($hostgroup_name)" );
	return wantarray ? () : undef;
    }
    my $cgrp_name;
    foreach (@cgrp_ids) {
	$cgrp_name = $self->get_contactgroup_name($_);
	push @contactgroups, $cgrp_name if defined $cgrp_name && $cgrp_name ne '';
    }
    return wantarray ? @contactgroups : \@contactgroups;
}

## @method arrayref or array get_service_contactgroups (string servicename)
# Get a list of the contactgroups directly assigned to a certain generic service;
# this does not include contactgroups indirectly assigned to the generic service via service template inheritance.
# @param servicename name of the generic service to search for
# @return contactgroup_names: In list context, a list of contactgroup names, or an empty list if the generic service does
# not exist, it has no directly associated contactgroups, or an error occurs (the latter case being indistinguishable from
# the logical conditions that can generate an empty list, so this mode of calling is not robust). In scalar context, an
# arrayref for the list of contactgroup names (which will be legitimately empty if the generic service does not exist or it has
# no directly associated contactgroups), or undef if an error occurs, which makes it easy to distinguish an error condition.
sub get_service_contactgroups {
    my $self          = shift;
    my $servicename   = $_[0];
    local $_;

    my @contactgroups  = ();
    my $servicename_id = $self->get_serviceid($servicename);
    if ( not $servicename_id ) {
	$self->debug( 'error', "Cannot find service with name $servicename." );
	return wantarray ? () : defined($servicename_id) ? [] : undef;
    }
    my @cgrp_ids = ();
    eval {
	my %where = ( 'servicename_id' => $servicename_id );
	@cgrp_ids = monarchWrapper->fetch_list_where( 'contactgroup_service_name', 'contactgroup_id', \%where );
    };
    if ($@) {
	$self->debug( 'error', "database access error in get_service_contactgroups($servicename)" );
	return wantarray ? () : undef;
    }
    my $cgrp_name;
    foreach (@cgrp_ids) {
	$cgrp_name = $self->get_contactgroup_name($_);
	push @contactgroups, $cgrp_name if defined $cgrp_name && $cgrp_name ne '';
    }
    return wantarray ? @contactgroups : \@contactgroups;
}

## @method boolean assign_contact_to_contactgroup (string contact_name, string contactgroup_name)
# Assign a contact to a contactgroup.
# @param contact_name name of the the contact to assign
# @param contactgroup_name name of the contactgroup to which the contact should be assigned
# @return status: true, if operation was successful; false otherwise
sub assign_contact_to_contactgroup {
    my $self              = shift;
    my $contact_name      = $_[0];
    my $contactgroup_name = $_[1];
    local $_;

    my $cgrp_id = $self->get_contactgroup_id($contactgroup_name);
    if ( not $cgrp_id ) {
	## Either non-existence or database error.
	$self->debug( 'error', "Cannot find contactgroup with name $contactgroup_name." );
	return $cgrp_id;
    }
    my $contact_id = $self->get_contact_id($contact_name);
    if ( not $contact_id ) {
	## Either non-existence or database error.
	$self->debug( 'error', "Cannot find contact with name $contact_name, so cannot assign to contactgroup $contactgroup_name" );
	return $contact_id;
    }
    my @contacts_assigned = $self->get_contactgroup_contacts($contactgroup_name);
    if ( grep { $_ eq $contact_name } @contacts_assigned ) {
	$self->debug( 'verbose', "Contactgroup $contactgroup_name already has contact $contact_name assigned" );
	return 1;
    }
    my $result;
    eval {
	my @values = ( $cgrp_id, $contact_id );
	$result = monarchWrapper->insert_obj( 'contactgroup_contact', \@values );
    };
    if ($@) {
	$self->debug( 'error', "database access error in assign_contact_to_contactgroup($contact_name, $contactgroup_name)" );
	return undef;
    }
    if ( $result =~ /Error/ ) {
	$self->debug( 'error', "insert failed: $result. Could not assign contact $contact_name to contactgroup $contactgroup_name" );
	return undef;
    }
    return 1;
}

## @method boolean assign_contactgroup_to_hostgroup (string contactgroup_name, string hostgroup_name)
# Assign a contactgroup to a hostgroup.
# @param contactgroup_name name of the contactgroup to assign
# @param hostgroup_name name of the hostgroup to which the contactgroup should be assigned
# @return status: true, if operation was successful; false otherwise
sub assign_contactgroup_to_hostgroup {
    my $self              = shift;
    my $contactgroup_name = $_[0];
    my $hostgroup_name    = $_[1];
    local $_;

    my $hgrp_id = $self->get_hostgroupid($hostgroup_name);
    if ( not $hgrp_id ) {
	## Either non-existence or database error, reflected in $hgrp_id either way.
	$self->debug( 'error', "Cannot find hostgroup with name $hostgroup_name." );
	return $hgrp_id;
    }
    my $contactgroup_id = $self->get_contactgroup_id($contactgroup_name);
    if ( not $contactgroup_id ) {
	## Either non-existence or database error, reflected in $contactgroup_id either way.
	$self->debug( 'error', "Cannot find contactgroup with name $contactgroup_name, so cannot assign to hostgroup $hostgroup_name" );
	return $contactgroup_id;
    }
    my $hostgroup_contactgroups = $self->get_hostgroup_contactgroups($hostgroup_name);
    if (not defined $hostgroup_contactgroups) {
	## Error has already been logged in get_hostgroup_contactgroups().
	return undef;
    }
    if ( grep { $_ eq $contactgroup_name } @$hostgroup_contactgroups ) {
	$self->debug( 'verbose', "Hostgroup $hostgroup_name already has contactgroup $contactgroup_name assigned" );
	return 1;
    }
    my $result;
    eval {
	my @values = ( $contactgroup_id, $hgrp_id );
	$result = monarchWrapper->insert_obj( 'contactgroup_hostgroup', \@values );
    };
    if ($@) {
	$self->debug( 'error', "database access error in assign_contactgroup_to_hostgroup($contactgroup_name, $hostgroup_name)" );
	return undef;
    }
    if ( $result =~ /Error/ ) {
	$self->debug( 'error', "insert failed: $result. Could not assign contactgroup $contactgroup_name to hostgroup $hostgroup_name" );
	return undef;
    }
    return 1;
}

## @method boolean assign_contactgroup_to_servicename (string contactgroup_name, string servicename)
# Assign a contactgroup to a servicename.
# @param contactgroup_name name of the contactgroup to assign
# @param servicename name of the generic service to which the contactgroup should be assigned
# @return status: true, if operation was successful; false otherwise
sub assign_contactgroup_to_servicename {
    my $self              = shift;
    my $contactgroup_name = $_[0];
    my $servicename       = $_[1];
    local $_;

    my $servicename_id = $self->get_serviceid($servicename);
    if ( not $servicename_id ) {
	## Either non-existence or database error.
	$self->debug( 'error', "Cannot find service with name $servicename." );
	return $servicename_id;
    }
    my $contactgroup_id = $self->get_contactgroup_id($contactgroup_name);
    if ( not $contactgroup_id ) {
	## Either non-existence or database error.
	$self->debug( 'error', "Cannot find contactgroup with name $contactgroup_name, so cannot assign to service $servicename" );
	return $contactgroup_id;
    }
    my @service_contactgroups = $self->get_service_contactgroups($servicename);
    if ( grep { $_ eq $contactgroup_name } @service_contactgroups ) {
	$self->debug( 'verbose', "Servicename $servicename already has contactgroup $contactgroup_name assigned" );
	return 1;
    }
    my $result;
    eval {
	my @values = ( $contactgroup_id, $servicename_id ),;
	$result = monarchWrapper->insert_obj( 'contactgroup_service_name', \@values );
    };
    if ($@) {
	$self->debug( 'error', "database access error in assign_contactgroup_to_servicename($contactgroup_name, $servicename)" );
	return undef;
    }
    if ( $result =~ /Error/ ) {
	$self->debug( 'error', "insert failed: $result. Could not assign contactgroup $contactgroup_name to service $servicename" );
	return undef;
    }
    return 1;
}

## @method boolean remove_contactgroup_from_servicename (string contactgroup_name, string servicename)
# Remove a contactgroup from a servicename.
# @param contactgroup_name name of the contactgroup to remove
# @param servicename name of the generic service from which the contactgroup is to be removed
# @return status: true, if operation was successful; false otherwise
sub remove_contactgroup_from_servicename {
    my $self              = shift;
    my $contactgroup_name = $_[0];
    my $servicename       = $_[1];
    local $_;

    my $servicename_id = $self->get_serviceid($servicename);
    if ( not $servicename_id ) {
	## Either non-existence or database error.
	$self->debug( 'error', "Cannot find service with name $servicename." );
	return $servicename_id;
    }
    my $contactgroup_id = $self->get_contactgroup_id($contactgroup_name);
    if ( not $contactgroup_id ) {
	## Either non-existence or database error.
	$self->debug( 'error', "Cannot find contactgroup with name $contactgroup_name, so cannot remove from service $servicename" );
	return $contactgroup_id;
    }
    my @service_contactgroups = $self->get_service_contactgroups($servicename);
    if ( not( grep { $_ eq $contactgroup_name } @service_contactgroups ) ) {
	$self->debug( 'warning', "Service $servicename does not have contactgroup $contactgroup_name assigned, so nothing to remove" );
	return 1;
    }
    my $result;
    eval {
	my %where = ( 'contactgroup_id' => $contactgroup_id, 'servicename_id' => $servicename_id );
	$result = monarchWrapper->delete_one_where( 'contactgroup_service_name', \%where );
    };
    if ($@) {
	$self->debug( 'error', "database access error in remove_contactgroup_from_servicename($contactgroup_name, $servicename)" );
	return undef;
    }
    if ( $result =~ /Error/ ) {
	$self->debug( 'error', "Delete failed: $result" );
	return undef;
    }
    return 1;
}

## @method boolean apply_hostescalation_tree (string hostname, string escalation_tree)
# Apply a host escalation tree to a host.
# @param hostname name of the host to which the escalation tree should be applied
# @param escalation_tree name of the host escalation tree to apply to the host
# @return status: true if successful, else false
sub apply_hostescalation_tree {
    my $self            = shift;
    my $hostname        = $_[0];
    my $escalation_tree = $_[1];
    $self->debug( 'verbose', "Trying to apply escalation tree $escalation_tree to host $hostname" );

    my $host_id = $self->get_hostid($hostname);
    if ( not $host_id ) {
	$self->debug( 'error', "no valid host_id for host $hostname found" );
	return $host_id;
    }
    my $escalation_tree_id = $self->get_escalation_tree_id( $escalation_tree, 'host' );
    if ( not $escalation_tree_id ) {
	$self->debug( 'error', "no valid escalation_id for escalation tree $escalation_tree found" );
	return $escalation_tree_id;
    }

    my $result;
    eval {
	my %vals = ( 'host_escalation_id' => $escalation_tree_id );
	$result = monarchWrapper->update_obj( 'hosts', 'host_id', $host_id, \%vals );
    };
    if ($@) {
	$self->debug( 'error', "database access error in apply_hostescalation_tree($hostname, $escalation_tree)" );
	return undef;
    }
    if ( $result =~ /^Error/ ) {
	$self->debug( 'error', "assigning escalation_id $escalation_tree_id to host with id $host_id" );
	return undef;
    }
    return 1;
}

## @method boolean apply_service_escalation_tree_to_host (string hostname, string escalation_tree)
# Apply a service escalation tree to a host.
# This overwrites existing service escalations for any particular service of that host.
# This means you can only use this option if ALL services on the host are to be escalated following the same tree.
# @param hostname name of the host to which the escalation tree should be applied
# @param escalation_tree name of the service escalation tree to apply
# @return status: true if successful, false otherwise
sub apply_service_escalation_tree_to_host {
    my $self            = shift;
    my $hostname        = $_[0];
    my $escalation_tree = $_[1];
    $self->debug( 'verbose', "Trying to apply escalation tree $escalation_tree to services on host $hostname" );

    my $host_id = $self->get_hostid($hostname);
    if ( not $host_id ) {
	$self->debug( 'error', "no valid host_id for host $hostname found" );
	return $host_id;
    }
    my $escalation_tree_id = $self->get_escalation_tree_id( $escalation_tree, 'service' );
    if ( not $escalation_tree_id ) {
	$self->debug( 'error', "no valid escalation_id for escalation tree $escalation_tree found" );
	return $escalation_tree_id;
    }

    my $result;
    eval {
	my %vals = ( 'service_escalation_id' => $escalation_tree_id );
	$result = monarchWrapper->update_obj( 'hosts', 'host_id', $host_id, \%vals );
    };
    if ($@) {
	$self->debug( 'error', "database access error in apply_service_escalation_tree_to_host($hostname, $escalation_tree)" );
	return undef;
    }
    if ( $result =~ /^Error/ ) {
	$self->debug( 'error', "assigning escalation_id $escalation_tree_id to host with id $host_id" );
	return undef;
    }
    return 1;
}

## @method boolean apply_serviceescalation_tree_to_hostservice (string hostname, string servicename, string escalation_tree)
# Apply a service escalation tree to a particular service on a host.
# @param hostname name of the host on which the service to which the escalation tree should be applied resides
# @param servicename name of the service to which the escalation tree should be applied
# @param escalation_tree name of the service escalation tree to apply
# @return status: true if successful, else false
sub apply_serviceescalation_tree_to_hostservice {
    my $self            = shift;
    my $hostname        = $_[0];
    my $servicename     = $_[1];
    my $escalation_tree = $_[2];

    $self->debug( 'verbose', "Trying to apply escalation tree $escalation_tree to service $servicename on host $hostname" );

    my $hostserviceID = $self->get_host_serviceid( $hostname, $servicename );
    if ( not $hostserviceID ) {
	$self->debug( 'error', "no valid id for host $hostname with service $servicename found" );
	return $hostserviceID;
    }
    my $escalation_tree_id = $self->get_escalation_tree_id( $escalation_tree, 'service' );
    if ( not $escalation_tree_id ) {
	$self->debug( 'error', "no valid escalation_id for escalation tree $escalation_tree found" );
	return $escalation_tree_id;
    }

    my $result;
    eval {
	my %vals = ( 'escalation_id' => $escalation_tree_id );
	$result = monarchWrapper->update_obj( 'services', 'service_id', $hostserviceID, \%vals );
    };
    if ($@) {
	$self->debug( 'error',
	    "database access error in apply_serviceescalation_tree_to_hostservice($hostname, $servicename, $escalation_tree)" );
	return undef;
    }
    if ( $result =~ /^Error/ ) {
	$self->debug( 'error',
	    "assigning escalation_id $escalation_tree_id to service $servicename on host $hostname with hostserviceID $hostserviceID" );
	return undef;
    }
    return 1;
}

## @method boolean apply_serviceescalation_tree_to_all_hostservices (string hostname, string escalation_tree)
# Apply a service escalation tree to all already-defined services on a host.
# Use this, if you want to have different escalation trees for later defined services.
# If you want to have the same tree on definitely all services on a host,
# use apply_service_escalation_tree_to_host() instead.
# @param hostname name of the host on which services to which the escalation tree should be applied reside
# @param escalation_tree name of the service escalation tree to apply
# @return status: true if successful, else false
sub apply_serviceescalation_tree_to_all_hostservices {
    my $self            = shift;
    my $hostname        = $_[0];
    my $escalation_tree = $_[1];
    my $result          = 1;
    $self->debug( 'verbose', "Trying to apply escalation tree $escalation_tree to services on host $hostname" );

    my $host_id = $self->get_hostid($hostname);
    if ( not $host_id ) {
	$self->debug( 'error', "no valid host_id for host $hostname found" );
	return $host_id;
    }

    my $servicelist = $self->get_hostservice_list($hostname);
    if ( not defined $servicelist ) {
	## Error has already been logged in get_hostservice_list().
	return undef;
    }
    $self->debug( 'verbose', "Services on host $hostname: @$servicelist" );
    foreach my $service (@$servicelist) {
	$result = 0 unless $self->apply_serviceescalation_tree_to_hostservice( $hostname, $service, $escalation_tree );
    }

    return $result;
}

## @method boolean delete_host (string hostname)
# Delete a host from the monarch database.
# @param hostname name of the host to be deleted
# @return status: true if successful; false if the specified host does not exist or if a database operation has failed
sub delete_host {
    my $self     = shift;
    my $hostname = $_[0];

    my $host_id = $self->get_hostid($hostname);
    if ( not $host_id ) {
	$self->debug( 'error', "no valid host_id for host $hostname found" );
	return $host_id;
    }
    $self->debug( 'verbose', "Deleting host $hostname with ID $host_id" );
    my $result;
    eval {
	$result = monarchWrapper->delete_all( 'hosts', 'host_id', $host_id );
    };
    if ($@) {
	$self->debug( 'error', "database access error in delete_host($hostname)" );
	return undef;
    }
    if ( $result ne '1' ) {
	$self->debug( 'error', "deleting $hostname failed: $result" );
	return 0;
    }
    return 1;
}

## @method boolean delete_hosts (string searchstring)
# Delete a bunch of hosts.
# @param searchstring all hosts whose names include this substring will be deleted
# @return status: true if successful; false if no hosts with searchstring are found or if one delete action fails
sub delete_hosts {
    my $self         = shift;
    my $searchstring = $_[0];
    my $result       = 1;

    my %hosts = ();
    eval {
	%hosts = monarchWrapper->search( $searchstring, $self->{'limit_sql'} );
    };
    if ($@) {
	$self->debug( 'error', "database access error in delete_hosts($searchstring)" );
	return undef;
    }
    if ( not %hosts ) {
	$self->debug( 'error', "no hosts found whose names include \"$searchstring\"" );
	return 0;
    }

    foreach my $host ( keys(%hosts) ) {
	$self->debug( 'verbose', 'deleting host: ' . $host );
	$self->delete_host($host) or do { $result = 0; };
    }

    return $result;
}

## @method boolean delete_hostgroup_members (string hostgroupname)
# Delete all the members (hosts) from a hostgroup.  Use of this routine is strongly recommended
# instead of deleting and re-creating the hostgroup itself if you just need to change its membership.
# @param hostgroupname name of the hostgroup from which all member hosts are to be deleted
# @return status: true if successful; false if the specified hostgroup does not exist or if a database operation has failed.
sub delete_hostgroup_members {
    my $self          = shift;
    my $hostgroupname = $_[0];

    my %hg = ();
    eval {
	%hg = monarchWrapper->fetch_one( 'hostgroups', 'name', $hostgroupname );
    };
    if ($@) {
	$self->debug( 'error', "database access error in delete_hostgroup_members($hostgroupname)" );
	return undef;
    }
    if ( not defined $hg{'hostgroup_id'} ) {
	$self->debug( 'error', "hostgroup $hostgroupname does not exist" );
	return 0;
    }
    my $result;
    eval {
	$result = monarchWrapper->delete_all( 'hostgroup_host', 'hostgroup_id', $hg{'hostgroup_id'} );
    };
    if ($@) {
	$self->debug( 'error', "database access error in delete_hostgroup_members($hostgroupname)" );
	return undef;
    }
    if ( $result =~ /^Error/ ) {
	$self->debug( 'error', $result );
	return undef;
    }
    return 1;
}

## @method boolean delete_hostgroup (string hostgroupname)
# Delete a hostgroup from the monarch database.
# @param hostgroupname name of the hostgroup to be deleted
# @return status: true if successful; false if the specified hostgroup does not exist or if a database operation has failed
sub delete_hostgroup {
    my $self          = shift;
    my $hostgroupname = $_[0];

    my $hostgroup_id = $self->get_hostgroupid($hostgroupname);
    if ( not $hostgroup_id ) {
	$self->debug( 'error', "no valid hostgroup_id for host $hostgroupname found" );
	return $hostgroup_id;
    }
    $self->debug( 'verbose', "Deleting hostgroup $hostgroupname with ID $hostgroup_id" );
    my $result;
    eval {
	$result = monarchWrapper->delete_all( 'hostgroups', 'hostgroup_id', $hostgroup_id );
    };
    if ($@) {
	$self->debug( 'error', "database access error in delete_hostgroup($hostgroupname)" );
	return undef;
    }
    if ( $result ne '1' ) {
	$self->debug( 'error', "deleting $hostgroupname failed: $result" );
	return 0;
    }
    return 1;
}

## @method boolean delete_service (string servicename)
# Delete a generic service from the monarch database, along with all of the host services with the same name.
# @param servicename name of the generic service to be deleted
# @return status: true if successful, false otherwise
sub delete_service {
    my $self        = shift;
    my $servicename = $_[0];

    # FIX LATER:  As of the GWMEE 7.1.0 release, the monarch database still does not
    # contain a foreign key reference from the services table (representing host services)
    # to the service_names table (representing generic services).  Thus, removing the
    # generic service would leave the services.servicename_id field as a dangling pointer
    # if we did not first delete all the associated host services.  The construction here is
    # rather inefficient, with a lot of duplicate internal queries, but it gets the job done.

    my $hostnames = $self->get_service_hostlist($servicename);
    if ( not $hostnames ) {
	## Non-existence or a database error, reported in the subsidiary routine.
	## Here we return 0 for no-such-service and undef for error.
	return $hostnames;
    }
    foreach my $hostname (@$hostnames) {
	my $status = $self->remove_service( $hostname, $servicename );
	if ( not defined $status ) {
	    ## Error has already been reported in the subsidiary routine.
	    return undef;
	}
    }

    my $servicename_id = $self->get_serviceid($servicename);
    if ( not $servicename_id ) {
	$self->debug( 'error', "no valid servicename_id for service $servicename found" );
	return $servicename_id;
    }
    $self->debug( 'verbose', "Deleting service $servicename with ID $servicename_id" );
    my $result;
    eval {
	$result = monarchWrapper->delete_all( 'service_names', 'servicename_id', $servicename_id );
    };
    if ($@) {
	$self->debug( 'error', "database access error in delete_service($servicename)" );
	return undef;
    }
    if ( $result ne '1' ) {
	$self->debug( 'error', "deleting $servicename failed: $result" );
	return 0;
    }
    return 1;
}

## @method boolean delete_services (string searchstring)
# Delete a bunch of generic services, and along with them, all the host services with the same servicenames.
# @param searchstring all generic services whose names include this substring will be deleted
# @return status: true if successful; false if no services with searchstring are found or if delete action fails
sub delete_services {
    my $self         = shift;
    my $searchstring = $_[0];
    my $result       = 1;

    my %services = $self->search_service_by_prefix($searchstring);
    if ( not %services ) {
	$self->debug( 'error', "no services starting with $searchstring found." );
	return 0;
    }

    foreach my $service ( keys(%services) ) {
	$self->debug( 'verbose', 'deleting service: ' . $service );
	$self->delete_service($service) or do { $result = 0; };
    }

    return $result;
}

## @method boolean delete_host_ext_info_template (string templatename)
# Delete a host extended info template from the monarch database.
# @param templatename name of the host extended info template to be deleted
# @return status: true if successful, false otherwise
sub delete_host_ext_info_template {
    my $self         = shift;
    my $templatename = $_[0];

    my $templateID = $self->get_extended_host_information_template_id($templatename);
    if ( not $templateID ) {
	$self->debug( 'error', "no valid host_ext_info_template_id for template $templatename found" );
	return $templateID;
    }
    $self->debug( 'verbose', "Deleting host_ext_info_template $templatename with ID $templateID" );
    my $result;
    eval {
	$result = monarchWrapper->delete_all( 'extended_host_info_templates', 'hostextinfo_id', $templateID );
    };
    if ($@) {
	$self->debug( 'error', "database access error in delete_host_ext_info_template($templatename)" );
	return undef;
    }
    if ( $result ne '1' ) {
	$self->debug( 'error', "deleting host_ext_info_template $templatename failed: $result" );
	return 0;
    }
    return 1;
}

## @method boolean delete_host_ext_info_template_list (string templatename_prefix)
# Delete from the monarch database all host extended info templates whose name begins with a given prefix.
# @param templatename_prefix host extended info template name prefix to search for
# @return status: true if successful, false otherwise
sub delete_host_ext_info_template_list {
    my $self                = shift;
    my $templatename_prefix = $_[0];
    my $result              = 1;
    my @template_list       = ();
    eval {
	@template_list = monarchWrapper->fetch_list_start( 'extended_host_info_templates', 'name', 'name', $templatename_prefix );
    };
    if ($@) {
	$self->debug( 'error', "database access error in delete_host_ext_info_template_list($templatename_prefix)" );
	return undef;
    }
    if ( not @template_list ) {
	$self->debug( 'error', "No templates starting with $templatename_prefix found" );
	return 0;
    }
    $self->debug( 'verbose', "Deleting the following host_ext_info_templates: @template_list" );
    foreach my $template (@template_list) {
	$self->delete_host_ext_info_template($template) or do {
	    $result = 0;
	    $self->debug( 'error', "deleting host_ext_info_template $template failed" );
	};
    }
    return $result;
}

## @method boolean set_parents (string hostname, arrayref parents)
# Set parents of a host.
# @param hostname name of the host whose parents should be set
# @param parents reference to an array of parent-host names
# @return status: true if all parents could be assigned, false otherwise
sub set_parents {
    my $self     = shift;
    my $hostname = $_[0];
    my $parents  = $_[1];
    my $result   = 1;

    my $host_id = $self->get_hostid($hostname);
    if ( not $host_id ) {
	$self->debug( 'error', "no valid host_id for host $hostname found" );
	return $host_id;
    }
    $self->debug( 'verbose', 'Assigning parents ' . join( ', ', @$parents ) . " to host $hostname with ID $host_id" );

    # delete old parents, if any exist
    if ($host_id) {
	eval {
	    monarchWrapper->delete_all( 'host_parent', 'host_id', $host_id );
	};
	if ($@) {
	    $self->debug( 'error', "database access error in set_parents($hostname, $parents)" );
	    return undef;
	}
    }
    foreach my $myparent ( @$parents ) {
	$self->debug( 'verbose', "parent $myparent found" );
	my $parent_id = $self->get_hostid($myparent);
	if ($parent_id) {
	    my @values = ( $host_id, $parent_id );
	    ## FIX MAJOR:  handle exceptions here
	    monarchWrapper->insert_obj( 'host_parent', \@values ) or do {
		$result = 0;
		$self->debug( 'error', "Could not set parent $myparent for host $hostname" );
	    };
	}
	else {
	    $self->debug( 'error', "no valid host_id for parent $myparent found" );
	    $result = 0;
	}
    }

    return $result;
}

## @method array get_host_parent (string hostname)
# Get parents, if any, of a named host.
# @param hostname name of the host whose parents to deliver
# @return parent_names false otherwise
sub get_host_parent {
    my $self     = shift;
    my $hostname = $_[0];

    my $host_id = $self->get_hostid($hostname);
    if ( not $host_id ) {
	## Either non-existence or database error; our caller won't be able to distinguish.
	$self->debug( 'warning', "no valid host_id for host $hostname found" );
	return wantarray ? () : $host_id;
    }
    my @hosts = ();
    eval {
	@hosts = monarchWrapper->get_host_parent("$host_id");
    };
    if ($@) {
	$self->debug( 'error', "database access error in get_host_parent($hostname)" );
	return wantarray ? () : undef;
    }
    return wantarray ? @hosts : \@hosts;
}

## @method boolean enable_active_host_checks (string hostname)
# Activate host checks.
# @param hostname name of the host to activate hostchecks for
# @return status: true if successful, false otherwise
sub enable_active_host_checks {
    my $self     = shift;
    my $hostname = $_[0];
    my %props    = ( 'active_checks_enabled' => '1' );
    return $self->set_host_overrides_properties( $hostname, \%props );
}

## @method boolean enable_active_service_checks (string hostname, string servicename)
# Activate checks for a dedicated service on a particular host.
# @param hostname name of the host on which the the service resides
# @param servicename name of the service whose active checks are to be enabled
# @return status: true if successful, false otherwise
sub enable_active_service_checks {
    my $self        = shift;
    my $hostname    = $_[0];
    my $servicename = $_[1];
    my %props       = ( 'active_checks_enabled' => '1' );
    return $self->set_service_overrides_properties( $hostname, $servicename, \%props );
}

## @method boolean enable_obsess_host_checks (string hostname)
# Enable obsessing of host checks for a particular host.
# @param hostname name of the host for which obsessing should be activated
# @return status: true if successful, false otherwise
sub enable_obsess_host_checks {
    my $self     = shift;
    my $hostname = $_[0];
    my %props    = ( 'obsess_over_host' => '1' );
    return $self->set_host_overrides_properties( $hostname, \%props );
}

## @method boolean enable_obsess_service_checks (string hostname, string servicename)
# Enable obsessing for a particular service check.
# @param hostname name of the host on which the the service resides
# @param servicename name of the service whose service checks should be obsessed over
# @return status: true if successful, false otherwise
sub enable_obsess_service_checks {
    my $self        = shift;
    my $hostname    = $_[0];
    my $servicename = $_[1];
    my %props       = ( 'obsess_over_service' => '1' );
    return $self->set_service_overrides_properties( $hostname, $servicename, \%props );
}

## @method boolean enable_all_active_service_checks_on_host (string hostname)
# Enable all active service checks on a given host.
# @param hostname name of the host whose active service checks should be enabled
# @return status: true if all operations are successful, false otherwise
sub enable_all_active_service_checks_on_host {
    my $self        = shift;
    my $hostname    = $_[0];
    my $servicelist = $self->get_hostservice_list($hostname);
    if ( not defined $servicelist ) {
	## Error has already been logged in get_hostservice_list().
	return undef;
    }
    my $result = 1;
    $self->enable_active_host_checks($hostname);
    $self->debug( 'verbose', "Services on host $hostname: @$servicelist" );
    foreach my $service (@$servicelist) {
	$self->enable_active_service_checks( $hostname, $service ) or do {
	    $result = 0;
	    $self->debug( 'error', "enabling active service check for service $service failed on $hostname" );
	};
    }
    return $result;
}

## @method boolean enable_all_obsess_service_checks_on_host (string hostname)
# Enable obsessing for all service checks on a host.
# @param hostname name of the host whose service checks should be obsessed over
# @return status: true if successful, false otherwise
sub enable_all_obsess_service_checks_on_host {
    my $self        = shift;
    my $hostname    = $_[0];
    my $result      = 1;
    my $servicelist = $self->get_hostservice_list($hostname);
    if ( not defined $servicelist ) {
	## Error has already been logged in get_hostservice_list().
	return undef;
    }
    $result = $self->enable_obsess_host_checks($hostname);
    $self->debug( 'verbose', "Services on host $hostname: @$servicelist" );
    foreach my $service (@$servicelist) {
	$self->enable_obsess_service_checks( $hostname, $service ) or do {
	    $result = 0;
	    $self->debug( 'error', "enabling obsessing service check for service $service failed on $hostname" );
	};
    }
    return $result;
}

## @method boolean enable_active_service_check_on_hostgroup (string hostgroup, string servicename)
# Enable active checks for a particular service check on all hosts of a given hostgroup.
# @param hostgroup name of the hostgroup containing the hosts on which the named service may reside
# @param servicename name of the service on those hosts whose active service checks should be enabled
# @return status: true if successful, false otherwise
sub enable_active_service_check_on_hostgroup {
    my $self        = shift;
    my $hostgroup   = $_[0];
    my $servicename = $_[1];
    my $result      = 1;
    my @hosts       = $self->get_hosts_in_hostgroup($hostgroup);

    $self->debug( 'verbose', "Hosts in Group $hostgroup found: @hosts" );
    foreach my $host (@hosts) {
	$self->enable_all_active_service_checks_on_host($host) or do {
	    $result = 0;
	    $self->debug( 'error', "enabling active service check for service $servicename failed on $host" );
	};
    }
    return $result;
}

## @method boolean enable_obsess_service_check_on_hostgroup (string hostgroup, string servicename)
# Enable obsessing for a particular service check on all hosts of a given hostgroup.
# @param hostgroup name of the hostgroup containing the hosts on which the named service may reside
# @param servicename name of the service on those hosts whose service checks should be obsessed over
# @return status: true if successful, false otherwise
sub enable_obsess_service_check_on_hostgroup {
    my $self        = shift;
    my $hostgroup   = $_[0];
    my $servicename = $_[1];
    my $result      = 1;
    my @hosts       = $self->get_hosts_in_hostgroup($hostgroup);

    $self->debug( 'verbose', "Hosts in Group $hostgroup found: @hosts" );
    foreach my $host (@hosts) {
	$self->enable_all_obsess_service_checks_on_host($host) or do {
	    $result = 0;
	    $self->debug( 'error', "enabling all obsess service checks for service $servicename failed on host $host" );
	};
    }
    return $result;
}

## @method boolean enable_all_active_service_checks_on_hostgroup (string hostgroup)
# Enable active checks for all services on all hosts of a given hostgroup.
# @param hostgroup name of the hostgroup containing the hosts on which all active service checks should be enabled
# @return status: true if successful, false otherwise
sub enable_all_active_service_checks_on_hostgroup {
    my $self      = shift;
    my $hostgroup = $_[0];
    my $result    = 1;

    my @hosts = $self->get_hosts_in_hostgroup($hostgroup);

    $self->debug( 'verbose', "Hosts in Group $hostgroup found: @hosts" );
    foreach my $host (@hosts) {
	$self->enable_all_active_service_checks_on_host($host) or do {
	    $result = 0;
	    $self->debug( 'error', "enabling all active service checks on $host failed" );
	};
    }
    return $result;
}

## @method boolean enable_all_obsess_service_checks_on_hostgroup (string hostgroup)
# Enable obsessing for all service checks on all hosts in a hostgroup.
# @param hostgroup name of the hostgroup containing the hosts on which service checks should be obsessed over
# @return status: true if successful, false otherwise
sub enable_all_obsess_service_checks_on_hostgroup {
    my $self      = shift;
    my $hostgroup = $_[0];
    my $result    = 1;
    my @hosts     = $self->get_hosts_in_hostgroup($hostgroup);

    if ( not @hosts ) {
	$self->debug( 'error', "No hosts found in hostgroup $hostgroup" );
	return 0;
    }

    $self->debug( 'verbose', "Hosts in Group $hostgroup found: @hosts" );
    foreach my $host (@hosts) {
	$self->enable_all_obsess_service_checks_on_host($host) or do { $result = 0; };
    }

    return $result;
}

## @method boolean disable_active_host_checks (string hostname)
# Disable active hostchecks for a particular host.
# @param hostname name of the host to deactivate hostchecks for
# @return status: true if successful, false otherwise
sub disable_active_host_checks {
    my $self     = shift;
    my $hostname = $_[0];
    my %props    = ( 'active_checks_enabled' => '-zero-' );
    return $self->set_host_overrides_properties( $hostname, \%props );
}

## @method boolean disable_active_service_checks (string hostname, string servicename)
# Disable Checks for a particular service on a dedicated host.
# @param hostname name of the host on which the the service resides
# @param servicename name of the service whose active checks are to be disabled
# @return status: true if successful, false otherwise
sub disable_active_service_checks {
    my $self        = shift;
    my $hostname    = $_[0];
    my $servicename = $_[1];
    my %props       = ( 'active_checks_enabled' => '-zero-' );
    return $self->set_service_overrides_properties( $hostname, $servicename, \%props );
}

## @method boolean disable_obsess_host_checks (string hostname)
# Disable obsessing of host checks for a particular host.
# @param hostname name of the host for which obsessing should be deactivated
# @return status: true if successful, false otherwise
sub disable_obsess_host_checks {
    my $self     = shift;
    my $hostname = $_[0];
    my %props    = ( 'obsess_over_host' => '-zero-' );
    return $self->set_host_overrides_properties( $hostname, \%props );
}

## @method boolean disable_obsess_service_checks (string hostname, string servicename)
# Disable obsessing for a particular service check.
# @param hostname name of the host on which the the service resides
# @param servicename name of the service whose service checks should not be obsessed over
# @return status: true if successful, false otherwise
sub disable_obsess_service_checks {
    my $self        = shift;
    my $hostname    = $_[0];
    my $servicename = $_[1];
    my $result;
    my %props = ( 'obsess_over_service' => '-zero-' );
    $result = $self->set_service_overrides_properties( $hostname, $servicename, \%props );
    $self->debug( 'verbose', "set service overrides returned: $result" );
    return $result;
}

## @method boolean disable_all_active_service_checks_on_host (string hostname)
# Disable all active service checks on a host.
# @param hostname name of the host whose active service checks should be disabled
# @return status: true if operation successful for all services on host, false otherwise
sub disable_all_active_service_checks_on_host {
    my $self        = shift;
    my $hostname    = $_[0];
    my $result      = 1;
    my $servicelist = $self->get_hostservice_list($hostname);
    if ( not defined $servicelist ) {
	## Error has already been logged in get_hostservice_list().
	return undef;
    }
    ## FIX MAJOR:  compare to enabling, which is fine with no services found
    if ( not @$servicelist ) {
	$self->debug( 'error', "no services found on $hostname" );
	return 0;
    }
    $self->debug( 'verbose', "Services on host $hostname: @$servicelist" );
    $result = $self->disable_active_host_checks($hostname);
    foreach my $service (@$servicelist) {
	$self->disable_active_service_checks( $hostname, $service ) or do { $result = 0; };
    }

    return $result;
}

## @method boolean disable_all_obsess_service_checks_on_host (string hostname)
# Disable obsessing for all service checks on a host.
# @param hostname name of the host whose service checks should not be obsessed over
# @return status: true if successful, false otherwise
sub disable_all_obsess_service_checks_on_host {
    my $self        = shift;
    my $hostname    = $_[0];
    my $result      = 1;
    my $servicelist = $self->get_hostservice_list($hostname);
    if ( not defined $servicelist ) {
	## Error has already been logged in get_hostservice_list().
	return undef;
    }
    $self->debug( 'verbose', "Services on host $hostname: @$servicelist" );
    $result = $self->disable_obsess_host_checks($hostname);
    foreach my $service (@$servicelist) {
	$self->disable_obsess_service_checks( $hostname, $service ) or do {
	    $result = 0;
	    $self->debug( 'error', "disabling obsessing service check for service $service failed on $hostname" );
	};
    }
    return $result;
}

## @method boolean disable_active_service_check_on_hostgroup (string hostgroup, string servicename)
# Disable active checks for a particular service check on all hosts of a given hostgroup.
# @param hostgroup name of the hostgroup containing the hosts on which the named service may reside
# @param servicename name of the service on those hosts whose active service checks should be disabled
# @return status: true if successful, false if one of the operations fails.
# Will be also false if the service does not exist for one of the hosts in hostgroup.
sub disable_active_service_check_on_hostgroup {
    my $self        = shift;
    my $hostgroup   = $_[0];
    my $servicename = $_[1];
    my $result      = 1;

    my @hosts = $self->get_hosts_in_hostgroup($hostgroup);
    if ( not @hosts ) {
	$self->debug( 'error', "No hosts found in hostgroup $hostgroup" );
	return 0;
    }

    $self->debug( 'verbose', "Hosts in Group $hostgroup found: @hosts" );
    foreach my $host (@hosts) {
	$self->disable_active_service_checks( $host, $servicename ) or do {
	    $result = 0;
	    $self->debug( 'error', "disabling active service check $servicename on $host failed" );
	};
    }

    return $result;
}

## @method boolean disable_obsess_service_check_on_hostgroup (string hostgroup, string servicename)
# Disable obsessing for a particular service check on all hosts of a given hostgroup.
# @param hostgroup name of the hostgroup containing the hosts on which the named service may reside
# @param servicename name of the service on those hosts whose service checks should not be obsessed over
# @return status: true if successful, false if one of the operations fails. Will be also false if
# the service does not exist for one of the hosts in hostgroup.
sub disable_obsess_service_check_on_hostgroup {
    my $self        = shift;
    my $hostgroup   = $_[0];
    my $servicename = $_[1];
    my $result      = 1;

    my @hosts = $self->get_hosts_in_hostgroup($hostgroup);
    if ( not @hosts ) {
	$self->debug( 'error', "No hosts found in hostgroup $hostgroup" );
	return 0;
    }

    $self->debug( 'verbose', "Hosts in Group $hostgroup found: @hosts" );
    foreach my $host (@hosts) {
	$self->disable_obsess_service_checks( $host, $servicename ) or do {
	    $result = 0;
	    $self->debug( 'error', "disabling obsess service check $servicename on $host failed" );
	};
    }

    return $result;
}

## @method boolean disable_all_active_service_checks_on_hostgroup (string hostgroup)
# Disable active checks for all service check on all hosts of a given hostgroup.
# @param hostgroup name of the hostgroup containing the hosts on which all active service checks should be disabled
# @return status: true if successful, false if one of the operations fails. Will be also false if
# the service does not exist for one of the hosts in hostgroup.
sub disable_all_active_service_checks_on_hostgroup {
    my $self      = shift;
    my $hostgroup = $_[0];
    my $result    = 1;

    my @hosts = $self->get_hosts_in_hostgroup($hostgroup);
    if ( not @hosts ) {
	$self->debug( 'error', "No hosts found in hostgroup $hostgroup" );
	return 0;
    }

    $self->debug( 'verbose', "Hosts in Group $hostgroup found: @hosts" );
    foreach my $host (@hosts) {
	$self->disable_all_active_service_checks_on_host($host) or do {
	    $result = 0;
	    $self->debug( 'error', "disabling all active service checks on $host failed" );
	};
    }

    return $result;
}

## @method boolean disable_all_obsess_service_checks_on_hostgroup (string hostgroup)
# Disable obsessing for all service checks on all hosts in a hostgroup.
# @param hostgroup name of the hostgroup containing the hosts on which service checks should not be obsessed over
# @return status: true if successful, false otherwise
sub disable_all_obsess_service_checks_on_hostgroup {
    my $self      = shift;
    my $hostgroup = $_[0];
    my $result    = 1;

    my @hosts = $self->get_hosts_in_hostgroup($hostgroup);
    if ( not @hosts ) {
	$self->debug( 'error', "No hosts found in hostgroup $hostgroup" );
	return 0;
    }

    $self->debug( 'verbose', "Hosts in Group $hostgroup found: @hosts" );
    foreach my $host (@hosts) {
	$self->disable_all_obsess_service_checks_on_host($host) or do { $result = 0; };
    }

    return $result;
}

## @method boolean enable_host_notifications (string hostname)
# Disable notification for host checks for a particular host.
# @param hostname name of the host for which notifications should be enabled
# @return status: true if successful, false otherwise
sub enable_host_notifications {
    my $self     = shift;
    my $hostname = $_[0];
    my %props    = ( 'notifications_enabled' => '1' );
    return $self->set_host_overrides_properties( $hostname, \%props );
}

## @method boolean disable_host_notifications (string hostname)
# Disable notification for host checks for a particular host.
# @param hostname name of the host for which notifications should be disabled
# @return status: true if successful, false otherwise
sub disable_host_notifications {
    my $self     = shift;
    my $hostname = $_[0];
    my %props    = ( 'notifications_enabled' => '-zero-' );
    return $self->set_host_overrides_properties( $hostname, \%props );
}

## @method boolean enable_host_service_notifications (string hostname, string servicename)
# Disable notifications for a particular service on a dedicated host.
# @param hostname name of the host on which the service resides
# @param servicename name of the service for which notifications should be enabled
# @return status: true if successful, false otherwise
sub enable_host_service_notifications {
    my $self        = shift;
    my $hostname    = $_[0];
    my $servicename = $_[1];
    my %props       = ( 'notifications_enabled' => '1' );
    return $self->set_service_overrides_properties( $hostname, $servicename, \%props );
}

## @method boolean disable_host_service_notifications (string hostname, string servicename)
# Disable notifications for a particular service on a dedicated host.
# @param hostname name of the host on which the service resides
# @param servicename name of the service for which notifications should be disabled
# @return status: true if successful, false otherwise
sub disable_host_service_notifications {
    my $self        = shift;
    my $hostname    = $_[0];
    my $servicename = $_[1];
    my %props       = ( 'notifications_enabled' => '-zero-' );
    return $self->set_service_overrides_properties( $hostname, $servicename, \%props );
}

## @method boolean enable_all_notifications_on_host (string hostname)
# Enable all host-check and service-check notifications on a specified host.
# @param hostname name of the host on which notifications are to be enabled
# @return status: true if the operation was successful for the host check and all service checks on the host, false otherwise
sub enable_all_notifications_on_host {
    my $self        = shift;
    my $hostname    = $_[0];
    my $result      = 1;
    my $servicelist = $self->get_hostservice_list($hostname);
    if (not defined $servicelist) {
	## Error has already been logged in get_hostservice_list().
	return undef;
    }
    if ( not @$servicelist ) {
	## Not strictly illegal or erroneous, but likely unexpected.
	$self->debug( 'error', "no services found on $hostname" );
	return 0;
    }
    $self->debug( 'verbose', "Services on host $hostname: @$servicelist" );
    $result = $self->enable_host_notifications($hostname);
    foreach my $service (@$servicelist) {
	$result = 0 unless $self->enable_host_service_notifications( $hostname, $service );
    }
    return $result;
}

## @method boolean disable_all_notifications_on_host (string hostname)
# Disable all host-check and service-check notifications on a specified host.
# @param hostname name of the host on which notifications are to be disabled
# @return status: true if the operation was successful for the host check and all service checks on the host, false otherwise
sub disable_all_notifications_on_host {
    my $self        = shift;
    my $hostname    = $_[0];
    my $result      = 1;
    my $servicelist = $self->get_hostservice_list($hostname);
    if (not defined $servicelist) {
	## Error has already been logged in get_hostservice_list().
	return undef;
    }
    if ( not @$servicelist ) {
	## Not strictly illegal or erroneous, but likely unexpected.
	$self->debug( 'error', "no services found on $hostname" );
	return 0;
    }
    $self->debug( 'verbose', "Services on host $hostname: @$servicelist" );
    $result = $self->disable_host_notifications($hostname);
    foreach my $service (@$servicelist) {
	$result = 0 unless $self->disable_host_service_notifications( $hostname, $service );
    }
    return $result;
}

## @method boolean enable_host_service_freshness_checks (string hostname, string servicename)
# Activate checks for a dedicated service on a particular host.
# @param hostname name of the host on which the service resides
# @param servicename name of the service for which freshness checks should be enabled
# @return status: true if successful, false otherwise
sub enable_host_service_freshness_checks {
    my $self        = shift;
    my $hostname    = $_[0];
    my $servicename = $_[1];
    my %props       = ( 'check_freshness' => '1' );
    return $self->set_service_overrides_properties( $hostname, $servicename, \%props );
}

## @method boolean disable_host_service_freshness_checks (string hostname, string servicename)
# Disable Checks for a particular service on a dedicated host.
# @param hostname name of the host on which the service resides
# @param servicename name of the service for which freshness checks should be disabled
# @return status: true if successful, false otherwise
sub disable_host_service_freshness_checks {
    my $self        = shift;
    my $hostname    = $_[0];
    my $servicename = $_[1];
    my %props       = ( 'check_freshness' => '-zero-' );
    return $self->set_service_overrides_properties( $hostname, $servicename, \%props );
}

## @method DEPRECATED boolean assign_monarch_group_host (string monarch_group, string hostname)
# Assign a single host to a Monarch Group.
# This function is deprecated; use assign_monarch_group_hosts() instead.
# @param monarch_group name of a Monarch Group
# @param hostname name of a particular single host
# @return status: true if assign_monarch_group_host succeeds, false otherwise.
sub assign_monarch_group_host {
    my $self          = shift;
    my $monarch_group = $_[0];
    my $hostname      = $_[1];

    $self->debug( 'verbose', "Trying to assign host to Monarch Group." );

    # using the same method as seen in monarch.cgi for manipulating Monarch Groups
    my %host = ();
    my %group = ();
    my $assignment_exists;
    eval {
	%host = monarchWrapper->fetch_one( 'hosts', 'name', $hostname );
	my %where = ( 'name' => $monarch_group );
	%group = monarchWrapper->fetch_one_where( 'monarch_groups', \%where );
	%where = ( 'group_id' => $group{'group_id'}, 'host_id' => $host{'host_id'} );
	$assignment_exists = monarchWrapper->fetch_one_where( 'monarch_group_host', \%where );
    };
    if ($@) {
	$self->debug( 'error', "database access error in assign_monarch_group_host($monarch_group, $hostname)" );
	return undef;
    }
    if ( not $assignment_exists ) {
	## FIX MAJOR:  handle exceptions here
	my @values = ( $group{'group_id'}, $host{'host_id'} );
	my $result = monarchWrapper->insert_obj( 'monarch_group_host', \@values );
	if ( $result =~ /^Error/ ) {
	    $self->debug( 'error', "assign_monarch_group_host failed with error: $result" );
	    return undef;
	}
    }
    else {
	$self->debug( 'error', "assign_monarch_group_host failed - host is already assigned." );
	return 0;
    }
    return 1;
}

## @method boolean assign_monarch_group_hosts (string monarch_group, arrayref hosts)
# Assign specified hosts to a Monarch Group.
# @param monarch_group name of the Monarch Group to which hosts should be directly assigned
# @param hosts reference to an array of hostnames to be assigned to the Monarch Group
# @return status: true if assign_monarch_group_hosts completely succeeds, false otherwise.
sub assign_monarch_group_hosts {
    my $self          = shift;
    my $monarch_group = $_[0];
    my $hosts         = $_[1];  # arrayref
    local $_;

    my %group = ();
    eval {
	my %where = ( 'name' => $monarch_group );
	%group = monarchWrapper->fetch_one_where( 'monarch_groups', \%where );
    };
    if ($@) {
	$self->debug( 'error', "database access error in assign_monarch_group_hosts($monarch_group, ...)" );
	return undef;
    }
    if ( not %group ) {
	$self->debug( 'error', "assign_monarch_group_hosts failed: group $monarch_group does not exist" );
	return 0;
    }

    my %host_id = ();
    my @group_host_ids = ();
    eval {
	%host_id = monarchWrapper->get_table_objects('hosts');
	@group_host_ids = monarchWrapper->fetch_unique('monarch_group_host', 'host_id', 'group_id', $group{'group_id'});
    };
    if ($@) {
	$self->debug( 'error', "database access error in assign_monarch_group_hosts($monarch_group, ...)" );
	return undef;
    }

    my %in_group = map { $_ => 1 } @group_host_ids;

    foreach my $host (@$hosts) {
	next if not defined $host;
	if ( not defined $host_id{$host} ) {
	    $self->debug( 'error', "assign_monarch_group_hosts failed: host $host does not exist" );
	    return 0;
	}
	if (not $in_group{ $host_id{$host} }) {
	    ## FIX MAJOR:  handle exceptions here
	    my @values = ( $group{'group_id'}, $host_id{$host} );
	    my $result = monarchWrapper->insert_obj( 'monarch_group_host', \@values );
	    if ( $result =~ /^Error/ ) {
		$self->debug( 'error', "assign_monarch_group_hosts failed: $result" );
		return undef;
	    }
	}
    }

    return 1;
}

## @method boolean assign_monarch_group_hostgroups (string monarch_group, arrayref hostgroups)
# Assign specified hostgroups to a Monarch Group.
# @param monarch_group name of the Monarch Group to which hostgroups should be assigned
# @param hostgroups reference to an array of hostgroup names to be assigned to the Monarch Group
# @return status: true if assign_monarch_group_hostgroups completely succeeds, false otherwise.
sub assign_monarch_group_hostgroups {
    my $self          = shift;
    my $monarch_group = $_[0];
    my $hostgroups    = $_[1];  # arrayref
    local $_;

    my %group = ();
    eval {
	my %where = ( 'name' => $monarch_group );
	%group = monarchWrapper->fetch_one_where( 'monarch_groups', \%where );
    };
    if ($@) {
	$self->debug( 'error', "database access error in assign_monarch_group_hostgroups($monarch_group, ...)" );
	return undef;
    }
    if ( not %group ) {
	$self->debug( 'error', "assign_monarch_group_hostgroups failed: group $monarch_group does not exist" );
	return 0;
    }

    my %hostgroup_id = ();
    my @group_hostgroup_ids = ();
    eval {
	%hostgroup_id = monarchWrapper->get_table_objects('hostgroups');
	@group_hostgroup_ids = monarchWrapper->fetch_unique('monarch_group_hostgroup', 'hostgroup_id', 'group_id', $group{'group_id'});
    };
    if ($@) {
	$self->debug( 'error', "database access error in assign_monarch_group_hostgroups($monarch_group, ...)" );
	return undef;
    }

    my %in_group = map { $_ => 1 } @group_hostgroup_ids;

    foreach my $hostgroup (@$hostgroups) {
	next if not defined $hostgroup;
	if ( not defined $hostgroup_id{$hostgroup} ) {
	    $self->debug( 'error', "assign_monarch_group_hostgroups failed: hostgroup $hostgroup does not exist" );
	    return 0;
	}
	if (not $in_group{ $hostgroup_id{$hostgroup} }) {
	    ## FIX MAJOR:  handle exceptions here
	    my @values = ( $group{'group_id'}, $hostgroup_id{$hostgroup} );
	    my $result = monarchWrapper->insert_obj( 'monarch_group_hostgroup', \@values );
	    if ( $result =~ /^Error/ ) {
		$self->debug( 'error', "assign_monarch_group_hostgroups failed: $result" );
		return undef;
	    }
	}
    }

    return 1;
}

## @method boolean assign_monarch_group_subgroups (string monarch_group, arrayref subgroups)
# Assign specified subgroups to a Monarch Group.
# @param monarch_group name of the Monarch Group to which subgroups should be assigned
# @param subgroups reference to an array of Monarch Group names to be assigned as subgroups of the Monarch Group
# @return status: true if assign_monarch_group_subgroups completely succeeds, false otherwise.
sub assign_monarch_group_subgroups {
    my $self          = shift;
    my $monarch_group = $_[0];
    my $subgroups     = $_[1];  # arrayref
    local $_;

    my %group = ();
    eval {
	my %where = ( 'name' => $monarch_group );
	%group = monarchWrapper->fetch_one_where( 'monarch_groups', \%where );
    };
    if ($@) {
	$self->debug( 'error', "database access error in assign_monarch_group_subgroups($monarch_group, ...)" );
	return undef;
    }
    if ( not %group ) {
	$self->debug( 'error', "assign_monarch_group_subgroups failed: group $monarch_group does not exist" );
	return 0;
    }

    my %group_id = ();
    my @group_child_ids = ();
    eval {
	%group_id = monarchWrapper->get_table_objects('monarch_groups');
	@group_child_ids = monarchWrapper->fetch_unique('monarch_group_child', 'child_id', 'group_id', $group{'group_id'});
    };
    if ($@) {
	$self->debug( 'error', "database access error in assign_monarch_group_subgroups($monarch_group, ...)" );
	return undef;
    }

    my %in_group = map { $_ => 1 } @group_child_ids;

    foreach my $subgroup (@$subgroups) {
	next if not defined $subgroup;
	if ( not defined $group_id{$subgroup} ) {
	    $self->debug( 'error', "assign_monarch_group_subgroups failed: group $subgroup does not exist" );
	    return 0;
	}
	if ( $group{'group_id'} == $group_id{$subgroup} ) {
	    $self->debug( 'error', "assign_monarch_group_subgroups failed: a group cannot be one of its own subgroups" );
	    return 0;
	}
	if (not $in_group{ $group_id{$subgroup} }) {
	    ## FIX MAJOR:  handle exceptions here
	    my @values = ( $group{'group_id'}, $group_id{$subgroup} );
	    my $result = monarchWrapper->insert_obj( 'monarch_group_child', \@values );
	    if ( $result =~ /^Error/ ) {
		$self->debug( 'error', "assign_monarch_group_subgroups failed: $result" );
		return undef;
	    }
	}
    }

    return 1;
}

## @method arrayref get_monarch_group_hosts (string monarch_group)
# Tell which hosts are directly assigned to a Monarch Group.
# @param monarch_group name of the Monarch Group whose directly-assigned hosts are to be retrieved
# @return arrayref (names of assigned hosts) upon success, undef otherwise.
sub get_monarch_group_hosts {
    my $self          = shift;
    my $monarch_group = $_[0];
    local $_;

    my %group = ();
    eval {
	my %where = ( 'name' => $monarch_group );
	%group = monarchWrapper->fetch_one_where( 'monarch_groups', \%where );
    };
    if ($@) {
	$self->debug( 'error', "database access error in get_monarch_group_hosts($monarch_group)" );
	return undef;
    }
    if (not %group) {
	$self->debug( 'error', "get_monarch_group_hosts failed: group $monarch_group does not exist" );
	return undef;
    }

    my %host_name = ();
    my @group_host_ids = ();
    eval {
	%host_name = monarchWrapper->get_table_objects('hosts', 1);
	@group_host_ids = monarchWrapper->fetch_unique('monarch_group_host', 'host_id', 'group_id', $group{'group_id'});
    };
    if ($@) {
	$self->debug( 'error', "database access error in get_monarch_group_hosts($monarch_group)" );
	return undef;
    }

    my @group_host_names = map { $host_name{$_} } @group_host_ids;

    return \@group_host_names;
}

## @method arrayref get_monarch_group_hostgroups (string monarch_group)
# Tell which hostgroups are assigned to a Monarch Group.
# @param monarch_group name of the Monarch Group whose assigned hostgroups are to be retrieved
# @return arrayref (names of assigned hostgroups) upon success, undef otherwise.
sub get_monarch_group_hostgroups {
    my $self          = shift;
    my $monarch_group = $_[0];
    local $_;

    my %group = ();
    eval {
	my %where = ( 'name' => $monarch_group );
	%group = monarchWrapper->fetch_one_where( 'monarch_groups', \%where );
    };
    if ($@) {
	$self->debug( 'error', "database access error in get_monarch_group_hostgroups($monarch_group)" );
	return undef;
    }
    if (not %group) {
	$self->debug( 'error', "get_monarch_group_hostgroups failed: group $monarch_group does not exist" );
	return undef;
    }

    my %hostgroup_name = ();
    my @group_hostgroup_ids = ();
    eval {
	%hostgroup_name = monarchWrapper->get_table_objects('hostgroups', 1);
	@group_hostgroup_ids = monarchWrapper->fetch_unique('monarch_group_hostgroup', 'hostgroup_id', 'group_id', $group{'group_id'});
    };
    if ($@) {
	$self->debug( 'error', "database access error in get_monarch_group_hostgroups($monarch_group)" );
	return undef;
    }

    my @group_hostgroup_names = map { $hostgroup_name{$_} } @group_hostgroup_ids;

    return \@group_hostgroup_names;
}

## @method hashref get_monarch_group_orphans (void)
# Find all hosts not assigned directly or indirectly to any Monarch Group.
# @return hashref with keys being the names of hosts not belonging to any Monarch Group, and values being true; or undef, on failure
sub get_monarch_group_orphans {
    my $self = shift;
    my %hash = ();
    eval {
	%hash = monarchWrapper->get_group_orphans();
    };
    if ($@) {
	$self->debug( 'error', "database access error in get_monarch_group_orphans()" );
	return undef;
    }
    return \%hash;
}

## @method arrayref get_monarch_group_subgroups (string monarch_group)
# Tell which Monarch Groups are assigned as subgroups of a Monarch Group.
# @param monarch_group name of the Monarch Group whose Monarch Group subgroups are to be retrieved
# @return arrayref (names of assigned subgroups) upon success, undef otherwise.
sub get_monarch_group_subgroups {
    my $self          = shift;
    my $monarch_group = $_[0];
    local $_;

    my %group = ();
    eval {
	my %where = ( 'name' => $monarch_group );
	%group = monarchWrapper->fetch_one_where( 'monarch_groups', \%where );
    };
    if ($@) {
	$self->debug( 'error', "database access error in get_monarch_group_subgroups($monarch_group)" );
	return undef;
    }
    if (not %group) {
	$self->debug( 'error', "get_monarch_group_subgroups failed: group $monarch_group does not exist" );
	return undef;
    }

    my %group_name = ();
    my @group_child_ids = ();
    eval {
	%group_name = monarchWrapper->get_table_objects('monarch_groups', 1);
	@group_child_ids = monarchWrapper->fetch_unique('monarch_group_child', 'child_id', 'group_id', $group{'group_id'});
    };
    if ($@) {
	$self->debug( 'error', "database access error in get_monarch_group_subgroups($monarch_group)" );
	return undef;
    }

    my @group_child_names = map { $group_name{$_} } @group_child_ids;

    return \@group_child_names;
}

## @method string get_monarchgroup_location (string monarch_group)
# Get the buildpath for a Monarch Group.
# @param monarch_group name of the Monarch Group to get the path for
# @return location: the path where the config files should be built; an empty string, if not set; undef if a database error occurred
sub get_monarchgroup_location {
    my $self          = shift;
    my $monarch_group = $_[0];
    $self->debug( 'verbose', "searching for location (build path) of Monarch Group $monarch_group" );
    my %results = ();
    eval {
	my %where = ( 'name' => $monarch_group );
	%results = monarchWrapper->fetch_one_where( 'monarch_groups', \%where );
    };
    if ($@) {
	$self->debug( 'error', "database access error in get_monarchgroup_location($monarch_group)" );
	return undef;
    }
    return $results{'location'} || '';
}

## @method boolean remove_monarch_group_hosts (string monarch_group, arrayref hosts)
# Remove specified hosts from a Monarch Group.
# @param monarch_group name of the Monarch Group from which directly-assigned hosts are to be removed
# @param hosts reference to an array of hostnames, or undef to remove all directly-assigned hosts
# @return status: true if remove_monarch_group_hosts completely succeeds, false otherwise.
sub remove_monarch_group_hosts {
    my $self          = shift;
    my $monarch_group = $_[0];
    my $hosts         = $_[1];  # arrayref, or undef (remove all)
    local $_;

    my %group = ();
    eval {
	my %where = ( 'name' => $monarch_group );
	%group = monarchWrapper->fetch_one_where( 'monarch_groups', \%where );
    };
    if ($@) {
	$self->debug( 'error', "database access error in remove_monarch_group_hosts($monarch_group, ...)" );
	return undef;
    }
    if ( not %group ) {
	$self->debug( 'error', "remove_monarch_group_hosts failed: group $monarch_group does not exist" );
	return 0;
    }

    if (defined $hosts) {
	my %host_id = ();
	my @group_host_ids = ();
	eval {
	    %host_id = monarchWrapper->get_table_objects('hosts');
	    @group_host_ids = monarchWrapper->fetch_unique('monarch_group_host', 'host_id', 'group_id', $group{'group_id'});
	};
	if ($@) {
	    $self->debug( 'error', "database access error in remove_monarch_group_hosts($monarch_group, ...)" );
	    return undef;
	}

	my %in_group = map { $_ => 1 } @group_host_ids;

	foreach my $host (@$hosts) {
	    next if not defined $host;
	    next if not defined $host_id{$host};
	    if ($in_group{ $host_id{$host} }) {
		my %w = ( 'group_id' => $group{'group_id'}, 'host_id' => $host_id{$host} );
		my $result = monarchWrapper->delete_one_where( 'monarch_group_host', \%w );
		if ( $result =~ /^Error/ ) {
		    $self->debug( 'error', "remove_monarch_group_hosts failed: $result" );
		    return undef;
		}
	    }
	}
    }
    else {
	my $result;
	eval {
	    $result = monarchWrapper->delete_all( 'monarch_group_host', 'group_id', $group{'group_id'} );
	};
	if ($@) {
	    $self->debug( 'error', "database access error in remove_monarch_group_hosts($monarch_group, ...)" );
	    return undef;
	}
	if ( $result =~ /^Error/ ) {
	    $self->debug( 'error', "remove_monarch_group_hosts failed: $result" );
	    return undef;
	}
    }

    return 1;
}

## @method boolean remove_monarch_group_hostgroups (string monarch_group, arrayref hostgroups)
# Remove specified hostgroups from a Monarch Group.
# @param monarch_group name of the Monarch Group from which hostgroups are to be removed
# @param hostgroups reference to an array of hostgroup names, or undef to remove all hostgroups
# @return status: true if remove_monarch_group_hostgroups completely succeeds, false otherwise.
sub remove_monarch_group_hostgroups {
    my $self          = shift;
    my $monarch_group = $_[0];
    my $hostgroups    = $_[1];  # arrayref, or undef (remove all)
    local $_;

    my %group = ();
    eval {
	my %where = ( 'name' => $monarch_group );
	%group = monarchWrapper->fetch_one_where( 'monarch_groups', \%where );
    };
    if ($@) {
	$self->debug( 'error', "database access error in remove_monarch_group_hostgroups($monarch_group, ...)" );
	return undef;
    }
    if ( not %group ) {
	$self->debug( 'error', "remove_monarch_group_hostgroups failed: group $monarch_group does not exist" );
	return 0;
    }

    if (defined $hostgroups) {
	my %hostgroup_id = ();
	my @group_hostgroup_ids = ();
	eval {
	    %hostgroup_id = monarchWrapper->get_table_objects('hostgroups');
	    @group_hostgroup_ids = monarchWrapper->fetch_unique('monarch_group_hostgroup', 'hostgroup_id', 'group_id', $group{'group_id'});
	};
	if ($@) {
	    $self->debug( 'error', "database access error in remove_monarch_group_hostgroups($monarch_group, ...)" );
	    return undef;
	}

	my %in_group = map { $_ => 1 } @group_hostgroup_ids;

	foreach my $hostgroup (@$hostgroups) {
	    next if not defined $hostgroup;
	    next if not defined $hostgroup_id{$hostgroup};
	    if ($in_group{ $hostgroup_id{$hostgroup} }) {
		my %w = ( 'group_id' => $group{'group_id'}, 'hostgroup_id' => $hostgroup_id{$hostgroup} );
		my $result = monarchWrapper->delete_one_where( 'monarch_group_hostgroup', \%w );
		if ( $result =~ /^Error/ ) {
		    $self->debug( 'error', "remove_monarch_group_hostgroups failed: $result" );
		    return undef;
		}
	    }
	}
    }
    else {
	my $result;
	eval {
	    $result = monarchWrapper->delete_all( 'monarch_group_hostgroup', 'group_id', $group{'group_id'} );
	};
	if ($@) {
	    $self->debug( 'error', "database access error in remove_monarch_group_hostgroups($monarch_group, ...)" );
	    return undef;
	}
	if ( $result =~ /^Error/ ) {
	    $self->debug( 'error', "remove_monarch_group_hostgroups failed: $result" );
	    return undef;
	}
    }

    return 1;
}

## @method boolean remove_monarch_group_subgroups (string monarch_group, arrayref subgroups)
# Remove specified subgroups from a Monarch Group.
# @param monarch_group name of the Monarch Group from which Monarch Group subgroups are to be removed
# @param subgroups reference to an array of subgroup names, or undef to remove all subgroups
# @return status: true if remove_monarch_group_subgroups completely succeeds, false otherwise.
sub remove_monarch_group_subgroups {
    my $self          = shift;
    my $monarch_group = $_[0];
    my $subgroups     = $_[1];  # arrayref, or undef (remove all)
    local $_;

    my %group = ();
    eval {
	my %where = ( 'name' => $monarch_group );
	%group = monarchWrapper->fetch_one_where( 'monarch_groups', \%where );
    };
    if ($@) {
	$self->debug( 'error', "database access error in remove_monarch_group_subgroups($monarch_group, ...)" );
	return undef;
    }
    if ( not %group ) {
	$self->debug( 'error', "remove_monarch_group_subgroups failed: group $monarch_group does not exist" );
	return 0;
    }

    if (defined $subgroups) {
	my %group_id = ();
	my @group_child_ids = ();
	eval {
	    %group_id = monarchWrapper->get_table_objects('monarch_groups');
	    @group_child_ids = monarchWrapper->fetch_unique('monarch_group_child', 'child_id', 'group_id', $group{'group_id'});
	};
	if ($@) {
	    $self->debug( 'error', "database access error in remove_monarch_group_subgroups($monarch_group, ...)" );
	    return undef;
	}

	my %in_group = map { $_ => 1 } @group_child_ids;

	foreach my $subgroup (@$subgroups) {
	    next if not defined $subgroup;
	    next if not defined $group_id{$subgroup};
	    if ($in_group{ $group_id{$subgroup} }) {
		my %w = ( 'group_id' => $group{'group_id'}, 'child_id' => $group_id{$subgroup} );
		my $result = monarchWrapper->delete_one_where( 'monarch_group_child', \%w );
		if ( $result =~ /^Error/ ) {
		    $self->debug( 'error', "remove_monarch_group_subgroups failed: $result" );
		    return undef;
		}
	    }
	}
    }
    else {
	my $result;
	eval {
	    $result = monarchWrapper->delete_all( 'monarch_group_child', 'group_id', $group{'group_id'} );
	};
	if ($@) {
	    $self->debug( 'error', "database access error in remove_monarch_group_subgroups($monarch_group, ...)" );
	    return undef;
	}
	if ( $result =~ /^Error/ ) {
	    $self->debug( 'error', "remove_monarch_group_subgroups failed: $result" );
	    return undef;
	}
    }

    return 1;
}

## @method int create_external (string external_name, string description, string type, string content)
# Create a new free external.
# @param external_name Name of the external.
# @param description Brief comment about the external.
# @param type Type of the external ("host" or "service").
# @param content Content of the external.
# @return external_id: > 0, if definition was successful; 0 otherwise
sub create_external {
    my $self          = shift;
    my $external_name = $_[0];
    my $description   = $_[1];
    my $type          = $_[2];
    my $content       = $_[3];

    $self->debug( 'verbose', "called create_external($external_name, ...)" );

    if ( not defined($external_name) or $external_name eq '' ) {
	$self->debug( 'error', 'external name is invalid' );
	return 0;
    }

    # FIX LATER:  validate the external name more thoroughly
    # if ($external_name =~ /[^-@._%\w]/) {
    #	$self->debug( 'error', 'external name is invalid' );
    #	return 0;
    # }

    if ( defined($description) and length($description) > $max_external_description_length ) {
	$self->debug( 'error', 'external description exceeds maximum allowed length' );
	return 0;
    }

    if ( not defined($type) or ( $type ne 'host' and $type ne 'service' ) ) {
	$self->debug( 'error', "external type '$type' is neither 'host' nor 'service'" );
	return 0;
    }

    if ( not defined $content ) {
	$self->debug( 'error', 'external content is not defined' );
	return 0;
    }

    # Duplicate detection would be better handled by a unique index on the externals.name column, to
    # avoid a race condition here.  We'll add such an index in a future GWMEE release, but we might
    # then leave this code in place to block most duplicate-external attempts in older releases.
    my $e_ref = $self->get_external($external_name);
    if ( not defined $e_ref ) {
	## serious internal failure, already recorded by get_external()
	return undef;
    }
    elsif (%$e_ref) {
	$self->debug( 'error', "external name $external_name is already in use" );
	return 0;
    }

    my $external_id = ( $self->monarch_vstring() ge v4.0 ) ? \undef : '';
    my $handler     = ( $self->monarch_vstring() ge v4.0 ) ? \undef : '';

    my $result   = '';
    my $db_error = 0;

    eval {
	my @values = ( $external_id, $external_name, $description, $type, $content, $handler );
	$result = monarchWrapper->insert_obj_id( 'externals', \@values, 'external_id' );
	if ( $result =~ /Error/ ) {
	    if ( $result =~ /duplicate/i ) {
		## In GWMEE 6.7 and earlier, a duplicate-name condition can still happen because of
		## a race condition between the checking above and inserting here by some independent
		## process, but that won't be detected here.  In some future release, we will apply
		## a unique index on that column to prevent the race condition, and this logic will
		## then be the main method of detecting whether the new name is already in use.
		$self->debug( 'error', "external name $external_name is already in use" );
		return 0;
	    }
	    $db_error = 1;
	}
    };
    if ($@) {
	$result   = $@;
	$db_error = 1;
    }
    if ($db_error) {
	$self->debug( 'error', "creating external $external_name failed: $result" );
	return undef;
    }
    return $result;
}

## @method boolean rename_external (string old_external_name, string new_external_name)
# Rename a free external.
# @param old_external_name Old name of the external.
# @param new_external_name New name of the external.
# @return status: true if successful, false otherwise
sub rename_external {
    my $self              = shift;
    my $old_external_name = $_[0];
    my $new_external_name = $_[1];
    my $result            = '';
    my $db_error          = 0;

    $self->debug( 'verbose', "called rename_external($old_external_name, ...)" );

    my $external_id = $self->get_externalid($old_external_name);
    if ( not $external_id ) {
	$self->debug( 'error', "external $old_external_name not found" );
	return $external_id;
    }

    if ( not defined($new_external_name) or $new_external_name eq '' ) {
	$self->debug( 'error', 'new external name is invalid' );
	return 0;
    }

    # FIX LATER:  validate the new external name more thoroughly
    # if ($new_external_name =~ /[^-@._%\w]/) {
    #   $self->debug( 'error', 'new external name is invalid' );
    #   return 0;
    # }

    # Duplicate detection would be better handled by a unique index on the externals.name column, to
    # avoid a race condition here.  We'll add such an index in a future GWMEE release, but we might
    # then leave this code in place to block most duplicate-external attempts in older releases.
    my $e_ref = $self->get_external($new_external_name);
    if ( not defined $e_ref ) {
	## serious internal failure, already recorded by get_external()
	return undef;
    }
    elsif (%$e_ref) {
	$self->debug( 'error', "new external name $new_external_name is already in use" );
	return 0;
    }

    eval {
	my %values = ( 'name' => $new_external_name );
	$result = monarchWrapper->update_obj( 'externals', 'external_id', $external_id, \%values );
	if ( $result =~ /Error/ ) {
	    if ( $result =~ /duplicate/i ) {
		## In GWMEE 6.7 and earlier, a duplicate-name condition can still happen because of
		## a race condition between the checking above and updating here by some independent
		## process, but that won't be detected here.  In some future release, we will apply
		## a unique index on that column to prevent the race condition, and this logic will
		## then be the main method of detecting whether the new name is already in use.
		$self->debug( 'error', "new external name $new_external_name is already in use" );
		return 0;
	    }
	    $db_error = 1;
	}
    };
    if ($@) {
	$result   = $@;
	$db_error = 1;
    }
    if ($db_error) {
	$self->debug( 'error', "renaming external $old_external_name failed: $result" );
	return undef;
    }
    return 1;
}

## @method boolean delete_external (string external_name)
# Delete a free external and all associated applied externals.
# @param external_name Name of the external to delete.
# @return status: true if successful, false otherwise
sub delete_external {
    my $self          = shift;
    my $external_name = $_[0];
    my $result        = '';
    my $db_error      = 0;

    $self->debug( 'verbose', "called delete_external($external_name)" );

    my $external_id = $self->get_externalid($external_name);
    if ( not $external_id ) {
	$self->debug( 'error', "external $external_name not found" );
	return $external_id;
    }

    eval {
	## We rely on cascaded deletes to drop rows from related tables.
	$result = monarchWrapper->delete_all( 'externals', 'external_id', $external_id );
	if ( $result =~ /Error/ ) {
	    $db_error = 1;
	}
    };
    if ($@) {
	$result   = $@;
	$db_error = 1;
    }
    if ($db_error) {
	$self->debug( 'error', "deleting external $external_name failed: $result" );
	return undef;
    }
    return 1;
}

## @method boolean assign_external_to_hostprofile (string hostprofile_name, string external_name)
# Assign a host external to a host profile.
# @param hostprofile_name Name of the host profile.
# @param external_name Name of the host external.
# @return status: true if successful, false otherwise
sub assign_external_to_hostprofile {
    my $self             = shift;
    my $hostprofile_name = $_[0];
    my $external_name    = $_[1];
    my $result           = '';
    my $db_error         = 0;

    $self->debug( 'verbose', "called assign_external_to_hostprofile($hostprofile_name, $external_name)" );

    my $hostprofile_id = $self->get_hostprofileid($hostprofile_name);
    if ( not $hostprofile_id ) {
	$self->debug( 'error', "host profile $hostprofile_name not found" );
	return $hostprofile_id;
    }

    my $e_ref = $self->get_external($external_name);
    if ( not defined $e_ref ) {
	## serious internal failure, already recorded by get_external()
	return undef;
    }
    elsif ( not %$e_ref ) {
	$self->debug( 'error', "external $external_name not found" );
	return 0;
    }

    my $external_id = $e_ref->{external_id};
    my $type        = $e_ref->{type};

    if ( $type ne 'host' ) {
	$self->debug( 'error', "external $external_name is not a host external" );
	return 0;
    }

    eval {
	my @values = ( $external_id, $hostprofile_id );
	$result = monarchWrapper->insert_obj( 'external_host_profile', \@values );
	if ( $result =~ /Error/ ) {
	    if ( $result =~ /duplicate/i ) {
		$self->debug( 'verbose', "external $external_name was already assigned to host profile $hostprofile_name" );
	    }
	    else {
		$db_error = 1;
	    }
	}
    };
    if ($@) {
	$result   = $@;
	$db_error = 1;
    }
    if ($db_error) {
	$self->debug( 'error', "assigning external $external_name to host profile $hostprofile_name failed: $result" );
	return undef;
    }
    return 1;
}

## @method boolean assign_external_to_service (string service_name, string external_name)
# Assign a service external to a generic service.
# @param service_name Name of the service.
# @param external_name Name of the service external.
# @return status: true if successful, false otherwise
sub assign_external_to_service {
    my $self          = shift;
    my $service_name  = $_[0];
    my $external_name = $_[1];
    my $result        = '';
    my $db_error      = 0;

    $self->debug( 'verbose', "called assign_external_to_service($service_name, $external_name)" );

    my $servicename_id = $self->get_serviceid($service_name);
    if ( not $servicename_id ) {
	$self->debug( 'error', "service $service_name not found" );
	return $servicename_id;
    }

    my $e_ref = $self->get_external($external_name);
    if ( not defined $e_ref ) {
	## serious internal failure, already recorded by get_external()
	return undef;
    }
    elsif ( not %$e_ref ) {
	$self->debug( 'error', "external $external_name not found" );
	return 0;
    }

    my $external_id = $e_ref->{external_id};
    my $type        = $e_ref->{type};

    if ( $type ne 'service' ) {
	$self->debug( 'error', "external $external_name is not a service external" );
	return 0;
    }

    eval {
	my @values = ( $external_id, $servicename_id );
	$result = monarchWrapper->insert_obj( 'external_service_names', \@values );
	if ( $result =~ /Error/ ) {
	    if ( $result =~ /duplicate/i ) {
		$self->debug( 'verbose', "external $external_name was already assigned to service $service_name" );
	    }
	    else {
		$db_error = 1;
	    }
	}
    };
    if ($@) {
	$result   = $@;
	$db_error = 1;
    }
    if ($db_error) {
	$self->debug( 'error', "assigning external $external_name to service $service_name failed: $result" );
	return undef;
    }
    return 1;
}

## @method boolean apply_external_to_host (string host_name, string external_name, boolean modified)
# Apply a host external to a host.  Overwrite existing external content and metadata if this host external was already applied.
# @param host_name Name of the host to which the external is to be applied.
# @param external_name Name of the host external to be applied.
# @param modified True, if the external is to be marked as a custom copy. False, if the external is to be marked as an unmodified copy.
# @return status: true if successful, false otherwise
sub apply_external_to_host {
    my $self          = shift;
    my $host_name     = $_[0];
    my $external_name = $_[1];
    my $modified      = $_[2];
    my $result        = '';
    my $db_error      = 0;

    $self->debug( 'verbose', "called apply_external_to_host($host_name, $external_name, $modified)" );

    my $host_id = $self->get_hostid($host_name);
    if ( not $host_id ) {
	$self->debug( 'error', "host $host_name not found" );
	return $host_id;
    }

    my $e_ref = $self->get_external($external_name);
    if ( not defined $e_ref ) {
	## serious internal failure, already recorded by get_external()
	return undef;
    }
    elsif ( not %$e_ref ) {
	$self->debug( 'error', "external $external_name not found" );
	return 0;
    }

    my $external_id = $e_ref->{external_id};
    my $type        = $e_ref->{type};
    my $content     = $e_ref->{display};

    if ( $type ne 'host' ) {
	$self->debug( 'error', "external $external_name is not a host external" );
	return 0;
    }

    $modified = $modified ? 1 : ( $self->monarch_vstring() ge v4.0 ) ? \'0+0' : '0+0';

    eval {
	my @values = ( $external_id, $host_id, $content, $modified );
	$result = monarchWrapper->insert_obj( 'external_host', \@values );
	if ( $result =~ /Error/ ) {
	    if ( $result =~ /duplicate/i ) {
		my %vals  = ( 'data'        => $content,     'modified' => $modified );
		my %where = ( 'external_id' => $external_id, 'host_id'  => $host_id );
		$result = monarchWrapper->update_obj_where( 'external_host', \%vals, \%where );
		if ( $result =~ /Error/ ) {
		    $self->debug( 'error', "updating external $external_name on host $host_name failed: $result" );
		    return undef;
		}
	    }
	    else {
		$db_error = 1;
	    }
	}
    };
    if ($@) {
	$result   = $@;
	$db_error = 1;
    }
    if ($db_error) {
	$self->debug( 'error', "applying external $external_name to host $host_name failed: $result" );
	return undef;
    }
    $self->debug( 'verbose', "external $external_name applied to host $host_name" );
    return 1;
}

## @method boolean apply_external_to_hostservice (string host_name, string service_name, string external_name, boolean modified)
# Apply a service external to a host service.  Overwrite existing external content and metadata if this service external was already applied.
# @param host_name Name of the host on which the service resides.
# @param service_name Name of the host service to which the external is to be applied.
# @param external_name Name of the host external to be applied.
# @param modified True, if the external is to be marked as a custom copy. False, if the external is to be marked as an unmodified copy.
# @return status: true if successful, false otherwise
sub apply_external_to_hostservice {
    my $self          = shift;
    my $host_name     = $_[0];
    my $service_name  = $_[1];
    my $external_name = $_[2];
    my $modified      = $_[3];
    my $result        = '';
    my $db_error      = 0;

    $self->debug( 'verbose', "called apply_external_to_hostservice($host_name, $service_name, $external_name, $modified)" );

    my $host_id = $self->get_hostid($host_name);
    if ( not $host_id ) {
	$self->debug( 'error', "host $host_name not found" );
	return $host_id;
    }
    my $hostservice_id = $self->get_host_serviceid( $host_name, $service_name );
    if ( not $hostservice_id ) {
	$self->debug( 'error', "no valid ID found for host $host_name service $service_name" );
	return $hostservice_id;
    }

    my $e_ref = $self->get_external($external_name);
    if ( not defined $e_ref ) {
	## serious internal failure, already recorded by get_external()
	return undef;
    }
    elsif ( not %$e_ref ) {
	$self->debug( 'error', "external $external_name not found" );
	return 0;
    }

    my $external_id = $e_ref->{external_id};
    my $type        = $e_ref->{type};
    my $content     = $e_ref->{display};

    if ( $type ne 'service' ) {
	$self->debug( 'error', "external $external_name is not a service external" );
	return 0;
    }

    $modified = $modified ? 1 : ( $self->monarch_vstring() ge v4.0 ) ? \'0+0' : '0+0';

    eval {
	my @values = ( $external_id, $host_id, $hostservice_id, $content, $modified );
	$result = monarchWrapper->insert_obj( 'external_service', \@values );
	if ( $result =~ /Error/ ) {
	    if ( $result =~ /duplicate/i ) {
		my %vals = ( 'data' => $content, 'modified' => $modified );
		my %where = ( 'external_id' => $external_id, 'host_id' => $host_id, 'service_id' => $hostservice_id );
		$result = monarchWrapper->update_obj_where( 'external_service', \%vals, \%where );
		if ( $result =~ /Error/ ) {
		    $self->debug( 'error', "updating external $external_name on host $host_name service $service_name failed: $result" );
		    return undef;
		}
	    }
	    else {
		$db_error = 1;
	    }
	}
    };
    if ($@) {
	$result   = $@;
	$db_error = 1;
    }
    if ($db_error) {
	$self->debug( 'error', "applying external $external_name to host $host_name service $service_name failed: $result" );
	return undef;
    }
    $self->debug( 'verbose', "external $external_name applied to host $host_name service $service_name" );
    return 1;
}

## @method boolean modify_external (string external_name, string description, string content)
# Modify a free external.
# @param external_name Name of the external to modify.
# @param description Replacement comment for the external.  Undefined means leave this field as-is.
# @param content Replacement content of the external.  Undefined means leave this field as-is.
# @return status: true if successful, false otherwise
sub modify_external {
    my $self          = shift;
    my $external_name = $_[0];
    my $description   = $_[1];
    my $content       = $_[2];
    my $result        = '';
    my $db_error      = 0;

    $self->debug( 'verbose', "called modify_external($external_name, ...)" );

    my $external_id = $self->get_externalid($external_name);
    if ( not $external_id ) {
	$self->debug( 'error', "external $external_name not found" );
	return $external_id;
    }

    if ( defined($description) and length($description) > $max_external_description_length ) {
	$self->debug( 'error', 'external description exceeds maximum allowed length' );
	return 0;
    }

    if ( not defined($description) and not defined($content) ) {
	return 1;
    }

    eval {
	my %values = ();
	$values{description} = $description if defined $description;
	$values{display}     = $content     if defined $content;
	$result = monarchWrapper->update_obj( 'externals', 'external_id', $external_id, \%values );
	if ( $result =~ /Error/ ) {
	    $db_error = 1;
	}
    };
    if ($@) {
	$result   = $@;
	$db_error = 1;
    }
    if ($db_error) {
	$self->debug( 'error', "modifying external $external_name failed: $result" );
	return undef;
    }
    return 1;
}

## @method boolean modify_host_external (string host_name, string external_name, string content, boolean modified)
# Modify a host external on a host.  Overwrite existing external content and metadata.
# @param host_name Name of the host on which the external is to be modified.
# @param external_name Name of the host external to be modified.
# @param content Replacement content of the external.  Undefined means leave this field as-is.
# @param modified True, if the updated external is to be marked as a custom copy.
# False, if the updated external is to be marked as an unmodified copy.
# Undefined means leave this field as-is.
# @return status: true if successful, false otherwise
sub modify_host_external {
    my $self          = shift;
    my $host_name     = $_[0];
    my $external_name = $_[1];
    my $content       = $_[2];
    my $modified      = $_[3];
    my $result        = '';
    my $db_error      = 0;

    $self->debug( 'verbose', "called modify_host_external($host_name, $external_name, ...)" );

    my $host_id = $self->get_hostid($host_name);
    if ( not $host_id ) {
	$self->debug( 'error', "host $host_name not found" );
	return $host_id;
    }

    my $e_ref = $self->get_external($external_name);
    if ( not defined $e_ref ) {
	## serious internal failure, already recorded by get_external()
	return undef;
    }
    elsif ( not %$e_ref ) {
	$self->debug( 'error', "external $external_name not found" );
	return 0;
    }

    my $external_id = $e_ref->{external_id};
    my $type        = $e_ref->{type};

    if ( $type ne 'host' ) {
	$self->debug( 'error', "external $external_name is not a host external" );
	return 0;
    }

    $modified = $modified ? 1 : ( $self->monarch_vstring() ge v4.0 ) ? \'0+0' : '0+0' if defined $modified;

    if ( not defined($content) and not defined($modified) ) {
	return 1;
    }

    eval {
	my %values = ();
	$values{data}     = $content  if defined $content;
	$values{modified} = $modified if defined $modified;
	my %where = ( 'external_id' => $external_id, 'host_id' => $host_id );
	$result = monarchWrapper->update_obj_where( 'external_host', \%values, \%where );
	if ( $result =~ /Error/ ) {
	    $db_error = 1;
	}
    };
    if ($@) {
	$result   = $@;
	$db_error = 1;
    }
    if ($db_error) {
	$self->debug( 'error', "modifying external $external_name on host $host_name failed: $result" );
	return undef;
    }
    $self->debug( 'verbose', "external $external_name modified on host $host_name" );
    return 1;
}

## @method boolean modify_hostservice_external (string host_name, string service_name, string external_name, string content, boolean modified)
# Modify a service external on a host service.  Overwrite existing external content and metadata.
# @param host_name Name of the host on which the service resides.
# @param service_name Name of the host service on which the external is to be modified.
# @param external_name Name of the host external to be modified.
# @param content Replacement content of the external.  Undefined means leave this field as-is.
# @param modified True, if the updated external is to be marked as a custom copy.
# False, if the updated external is to be marked as an unmodified copy.
# Undefined means leave this field as-is.
# @return status: true if successful, false otherwise
sub modify_hostservice_external {
    my $self          = shift;
    my $host_name     = $_[0];
    my $service_name  = $_[1];
    my $external_name = $_[2];
    my $content       = $_[3];
    my $modified      = $_[4];
    my $result        = '';
    my $db_error      = 0;

    $self->debug( 'verbose', "called modify_hostservice_external($host_name, $service_name, $external_name, ...)" );

    my $host_id = $self->get_hostid($host_name);
    if ( not $host_id ) {
	$self->debug( 'error', "host $host_name not found" );
	return $host_id;
    }
    my $hostservice_id = $self->get_host_serviceid( $host_name, $service_name );
    if ( not $hostservice_id ) {
	$self->debug( 'error', "no valid ID found for host $host_name service $service_name" );
	return $hostservice_id;
    }

    my $e_ref = $self->get_external($external_name);
    if ( not defined $e_ref ) {
	## serious internal failure, already recorded by get_external()
	return undef;
    }
    elsif ( not %$e_ref ) {
	$self->debug( 'error', "external $external_name not found" );
	return 0;
    }

    my $external_id = $e_ref->{external_id};
    my $type        = $e_ref->{type};

    if ( $type ne 'service' ) {
	$self->debug( 'error', "external $external_name is not a service external" );
	return 0;
    }

    $modified = $modified ? 1 : ( $self->monarch_vstring() ge v4.0 ) ? \'0+0' : '0+0' if defined $modified;

    if ( not defined($content) and not defined($modified) ) {
	return 1;
    }

    eval {
	my %values = ();
	$values{data}     = $content  if defined $content;
	$values{modified} = $modified if defined $modified;
	my %where = ( 'external_id' => $external_id, 'host_id' => $host_id, 'service_id' => $hostservice_id );
	$result = monarchWrapper->update_obj_where( 'external_service', \%values, \%where );
	if ( $result =~ /Error/ ) {
	    $db_error = 1;
	}
    };
    if ($@) {
	$result   = $@;
	$db_error = 1;
    }
    if ($db_error) {
	$self->debug( 'error', "modifying external $external_name on host $host_name service $service_name failed: $result" );
	return undef;
    }
    $self->debug( 'verbose', "external $external_name modified on host $host_name service $service_name" );
    return 1;
}

## @method boolean remove_external_from_hostprofile (string hostprofile_name, string external_name)
# Remove a host external from a host profile.
# @param hostprofile_name Name of the host profile.
# @param external_name Name of the host external.
# @return status: true if successful, false otherwise
sub remove_external_from_hostprofile {
    my $self             = shift;
    my $hostprofile_name = $_[0];
    my $external_name    = $_[1];
    my $result           = '';
    my $db_error         = 0;

    $self->debug( 'verbose', "called remove_external_from_hostprofile($hostprofile_name, $external_name)" );

    my $hostprofile_id = $self->get_hostprofileid($hostprofile_name);
    if ( not $hostprofile_id ) {
	$self->debug( 'error', "host profile $hostprofile_name not found" );
	return $hostprofile_id;
    }
    my $external_id = $self->get_externalid($external_name);
    if ( not $external_id ) {
	$self->debug( 'error', "external $external_name not found" );
	return $external_id;
    }

    eval {
	my %where = ( 'external_id' => $external_id, 'hostprofile_id' => $hostprofile_id );
	$result = monarchWrapper->delete_one_where( 'external_host_profile', \%where );
	if ( $result =~ /Error/ ) {
	    $db_error = 1;
	}
    };
    if ($@) {
	$result   = $@;
	$db_error = 1;
    }
    if ($db_error) {
	$self->debug( 'error', "removing external $external_name from host profile $hostprofile_name failed: $result" );
	return undef;
    }
    return 1;
}

## @method boolean remove_external_from_service (string service_name, string external_name)
# Remove a service external from a generic service.
# @param service_name Name of the service.
# @param external_name Name of the service external.
# @return status: true if successful, false otherwise
sub remove_external_from_service {
    my $self          = shift;
    my $service_name  = $_[0];
    my $external_name = $_[1];
    my $result        = '';
    my $db_error      = 0;

    $self->debug( 'verbose', "called remove_external_from_service($service_name, $external_name)" );

    my $servicename_id = $self->get_serviceid($service_name);
    if ( not $servicename_id ) {
	$self->debug( 'error', "service $service_name not found" );
	return $servicename_id;
    }
    my $external_id = $self->get_externalid($external_name);
    if ( not $external_id ) {
	$self->debug( 'error', "external $external_name not found" );
	return $external_id;
    }

    eval {
	my %where = ( 'external_id' => $external_id, 'servicename_id' => $servicename_id );
	$result = monarchWrapper->delete_one_where( 'external_service_names', \%where );
	if ( $result =~ /Error/ ) {
	    $db_error = 1;
	}
    };
    if ($@) {
	$result   = $@;
	$db_error = 1;
    }
    if ($db_error) {
	$self->debug( 'error', "removing external $external_name from generic service $service_name failed: $result" );
	return undef;
    }
    return 1;
}

## @method boolean remove_external_from_host (string host_name, string external_name)
# Remove a host external from a host.
# @param host_name Name of the host.
# @param external_name Name of the host external.
# @return status: true if successful, false otherwise
sub remove_external_from_host {
    my $self          = shift;
    my $host_name     = $_[0];
    my $external_name = $_[1];
    my $result        = '';
    my $db_error      = 0;

    $self->debug( 'verbose', "called remove_external_from_host($host_name, $external_name)" );

    my $host_id = $self->get_hostid($host_name);
    if ( not $host_id ) {
	$self->debug( 'error', "host $host_name not found" );
	return $host_id;
    }
    my $external_id = $self->get_externalid($external_name);
    if ( not $external_id ) {
	$self->debug( 'error', "external $external_name not found" );
	return $external_id;
    }

    eval {
	my %where = ( 'external_id' => $external_id, 'host_id' => $host_id );
	$result = monarchWrapper->delete_one_where( 'external_host', \%where );
	if ( $result =~ /Error/ ) {
	    $db_error = 1;
	}
    };
    if ($@) {
	$result   = $@;
	$db_error = 1;
    }
    if ($db_error) {
	$self->debug( 'error', "removing external $external_name from host $host_name failed: $result" );
	return undef;
    }
    return 1;
}

## @method boolean remove_external_from_hostservice (string host_name, string service_name, string external_name)
# Removes a service external from a host service.
# @param host_name Name of the host.
# @param service_name Name of the host service from which the external is to be removed.
# @param external_name Name of the service external.
# @return status: true if successful, false otherwise
sub remove_external_from_hostservice {
    my $self          = shift;
    my $host_name     = $_[0];
    my $service_name  = $_[1];
    my $external_name = $_[2];
    my $result        = '';
    my $db_error      = 0;

    $self->debug( 'verbose', "called remove_external_from_hostservice($host_name, $service_name, $external_name)" );

    my $host_id = $self->get_hostid($host_name);
    if ( not $host_id ) {
	$self->debug( 'error', "host $host_name not found" );
	return $host_id;
    }
    my $hostservice_id = $self->get_host_serviceid( $host_name, $service_name );
    if ( not $hostservice_id ) {
	$self->debug( 'error', "no valid ID found for host $host_name service $service_name" );
	return $hostservice_id;
    }
    my $external_id = $self->get_externalid($external_name);
    if ( not $external_id ) {
	$self->debug( 'error', "external $external_name not found" );
	return $external_id;
    }

    eval {
	my %where = ( 'external_id' => $external_id, 'host_id' => $host_id, 'service_id' => $hostservice_id );
	$result = monarchWrapper->delete_one_where( 'external_service', \%where );
	if ( $result =~ /Error/ ) {
	    $db_error = 1;
	}
    };
    if ($@) {
	$result   = $@;
	$db_error = 1;
    }
    if ($db_error) {
	$self->debug( 'error', "removing external $external_name from host $host_name service $service_name failed: $result" );
	return undef;
    }
    return 1;
}

## @method hashref get_external (string external_name)
# Find details of a free external, given an external name.
# @param external_name Name of the external to search for.
# @return hashref pointing to details if external exists;
# false otherwise (reference to empty hash if external does not exist, undefined if search failed)
sub get_external {
    my $self          = shift;
    my $external_name = $_[0];

    $self->debug( 'verbose', "called get_external($external_name)" );

    my %results = ();
    eval {
	%results = monarchWrapper->fetch_one( 'externals', 'name', $external_name );
    };
    if ($@) {
	$self->debug( 'error', "database access error in get_external($external_name)" );
	return undef;
    }
    return \%results;
}

## @method int get_externalid (string external_name)
# Find external ID, given an external name.
# @param external_name Name of the external to search for.
# @return external_id: > 0 if external exists; false otherwise (0 if external does not exist, undefined if search failed)
sub get_externalid {
    my $e_ref = get_external(@_);
    return defined($e_ref) ? $e_ref->{'external_id'} || 0 : undef;
}

## @method string get_externalname (int external_id)
# Find external name, given an external ID.
# @param external_id ID of the external to search for.
# @return name of external if external exists; otherwise, undefined
sub get_externalname {
    my $self        = shift;
    my $external_id = $_[0];

    $self->debug( 'verbose', "called get_externalname($external_id)" );

    my %results = ();
    eval {
	%results = monarchWrapper->fetch_one( 'externals', 'external_id', $external_id );
    };
    if ($@) {
	$self->debug( 'error', "database access error in get_externalname($external_id)" );
	return undef;
    }
    return $results{'name'};
}

## @method hashref get_host_external (string host_name, string external_name)
# Find details of an applied host external.
# @param host_name Name of the host to which the external was applied.
# @param external_name Name of the external to search for.
# @return hashref pointing to details, if external exists;
# reference to empty hash, if the applied host external does not exist;
# undefined, if search failed
sub get_host_external {
    my $self          = shift;
    my $host_name     = $_[0];
    my $external_name = $_[1];

    $self->debug( 'verbose', "called get_host_external($host_name, $external_name)" );

    my %results  = ();
    my $db_error = 0;

    my $host_id     = $self->get_hostid($host_name);
    my $external_id = $self->get_externalid($external_name);
    if ( not defined($host_id) or not defined($external_id) ) {
	$db_error = 1;
    }
    elsif ( not $host_id ) {
	$self->debug( 'error', "host $host_name not found" );
    }
    elsif ( not $external_id ) {
	$self->debug( 'error', "external $external_name not found" );
    }
    else {
	eval {
	    my %where = ( 'external_id' => $external_id, 'host_id' => $host_id );
	    %results = monarchWrapper->fetch_one_where( 'external_host', \%where );
	};
	if ($@) {
	    $db_error = 1;
	}
    }
    if ($db_error) {
	$self->debug( 'error', "database access error in get_host_external($host_name, $external_name)" );
	return undef;
    }
    return \%results;
}

## @method hashref get_hostservice_external (string host_name, string service_name, string external_name)
# Find details of an applied service external.
# @param host_name Name of the host on which the service resides.
# @param service_name Name of the service to which the external was applied.
# @param external_name Name of the external to search for.
# @return hashref pointing to details, if external exists;
# reference to empty hash, if the applied service external does not exist;
# undefined, if search failed
sub get_hostservice_external {
    my $self          = shift;
    my $host_name     = $_[0];
    my $service_name  = $_[1];
    my $external_name = $_[2];

    $self->debug( 'verbose', "called get_hostservice_external($host_name, $service_name, $external_name)" );

    my %results  = ();
    my $db_error = 0;

    my $host_id        = $self->get_hostid($host_name);
    my $hostservice_id = $self->get_host_serviceid($service_name);
    my $external_id    = $self->get_externalid($external_name);
    if ( not defined($host_id) or not defined($hostservice_id) or not defined($external_id) ) {
	$db_error = 1;
    }
    elsif ( not $host_id ) {
	$self->debug( 'error', "host $host_name not found" );
    }
    elsif ( not $hostservice_id ) {
	$self->debug( 'error', "service $service_name not found on host $host_name" );
    }
    elsif ( not $external_id ) {
	$self->debug( 'error', "external $external_name not found" );
    }
    else {
	eval {
	    my %where = ( 'external_id' => $external_id, 'host_id' => $host_id, 'service_id' => $hostservice_id );
	    %results = monarchWrapper->fetch_one_where( 'external_service', \%where );
	};
	if ($@) {
	    $db_error = 1;
	}
    }
    if ($db_error) {
	$self->debug( 'error', "database access error in get_hostservice_external($host_name, $service_name, $external_name)" );
	return undef;
    }
    return \%results;
}

## @method arrayref list_externals (string type)
# List all free externals of a given type (host or service).
# @param type Type of the external to search for ("host" or "service").
# @return arrayref external_names pointing to list of names, if search was successful; undefined, if search failed
sub list_externals {
    my $self = shift;
    my $type = $_[0];

    $self->debug( 'verbose', "called list_externals($type)" );

    if ( not defined($type) or ( $type ne 'host' and $type ne 'service' ) ) {
	$self->debug( 'error', "external type '$type' is neither 'host' nor 'service'" );
	return undef;
    }

    my @external_names = ();
    eval {
	@external_names = monarchWrapper->fetch_unique( 'externals', 'name', 'type', $type );
    };
    if ($@) {
	$self->debug( 'error', "database access error in list_externals($type)" );
	return undef;
    }
    return \@external_names;
}

## @method arrayref list_hostprofile_externals (string hostprofile_name)
# List all externals assigned to a specified host profile.
# @param hostprofile_name Name of the host profile.
# @return arrayref external_names pointing to list of names, if search was successful; undefined, if search failed
sub list_hostprofile_externals {
    my $self             = shift;
    my $hostprofile_name = $_[0];

    $self->debug( 'verbose', "called list_hostprofile_externals($hostprofile_name)" );

    my $hostprofile_id = $self->get_hostprofileid($hostprofile_name) or do {
	$self->debug( 'error', "host profile $hostprofile_name not found" );
	return undef;
    };

    my @external_names = ();
    eval {
	my @external_ids = monarchWrapper->fetch_unique( 'external_host_profile', 'external_id', 'hostprofile_id', $hostprofile_id );
	foreach my $external_id (@external_ids) {
	    my $external_name = $self->get_externalname($external_id);
	    if ( not defined $external_name ) {
		## serious internal failure, already recorded by get_externalname()
		die "\n";
	    }
	    push @external_names, $external_name;
	}
    };
    if ($@) {
	$self->debug( 'error', "database access error in list_hostprofile_externals($hostprofile_name)" );
	return undef;
    }
    return \@external_names;
}

## @method arrayref list_service_externals (string service_name)
# List all externals assigned to a specified generic service.
# @param service_name Name of the service.
# @return arrayref external_names pointing to list of names, if search was successful; undefined, if search failed
sub list_service_externals {
    my $self         = shift;
    my $service_name = $_[0];

    $self->debug( 'verbose', "called list_service_externals($service_name)" );

    my $servicename_id = $self->get_serviceid($service_name) or do {
	$self->debug( 'error', "service $service_name not found" );
	return undef;
    };

    my @external_names = ();
    eval {
	my @external_ids = monarchWrapper->fetch_unique( 'external_service_names', 'external_id', 'servicename_id', $servicename_id );
	foreach my $external_id (@external_ids) {
	    my $external_name = $self->get_externalname($external_id);
	    if ( not defined $external_name ) {
		## serious internal failure, already recorded by get_externalname()
		die "\n";
	    }
	    push @external_names, $external_name;
	}
    };
    if ($@) {
	$self->debug( 'error', "database access error in list_service_externals($service_name)" );
	return undef;
    }
    return \@external_names;
}

## @method arrayref list_host_externals (string host_name)
# List all externals assigned to a specified host.
# @param host_name Name of the host.
# @return arrayref external_names pointing to list of names, if search was successful; undefined, if search failed
sub list_host_externals {
    my $self      = shift;
    my $host_name = $_[0];

    $self->debug( 'verbose', "called list_host_externals($host_name)" );

    my $host_id = $self->get_hostid($host_name) or do {
	$self->debug( 'error', "host $host_name not found" );
	return undef;
    };

    my @external_names = ();
    eval {
	my @external_ids = monarchWrapper->fetch_unique( 'external_host', 'external_id', 'host_id', $host_id );
	foreach my $external_id (@external_ids) {
	    my $external_name = $self->get_externalname($external_id);
	    if ( not defined $external_name ) {
		## serious internal failure, already recorded by get_externalname()
		die "\n";
	    }
	    push @external_names, $external_name;
	}
    };
    if ($@) {
	$self->debug( 'error', "database access error in list_host_externals($host_name)" );
	return undef;
    }
    return \@external_names;
}

## @method arrayref list_hostservice_externals (string host_name, string service_name)
# List all externals assigned to a specified host service.
# @param host_name Name of the host on which the service resides.
# @param service_name Name of the service.
# @return arrayref external_names pointing to list of names, if search was successful; undefined, if search failed
sub list_hostservice_externals {
    my $self         = shift;
    my $host_name    = $_[0];
    my $service_name = $_[1];

    $self->debug( 'verbose', "called list_hostservice_externals($host_name, $service_name)" );

    my $host_id = $self->get_hostid($host_name) or do {
	$self->debug( 'error', "host $host_name not found" );
	return undef;
    };
    my $hostservice_id = $self->get_host_serviceid( $host_name, $service_name ) or do {
	$self->debug( 'error', "no valid ID found for host $host_name service $service_name" );
	return undef;
    };

    my @external_names = ();
    eval {
	my %where = ( 'host_id' => $host_id, 'service_id' => $hostservice_id );
	my @external_ids = monarchWrapper->fetch_list_where( 'external_service', 'external_id', \%where );
	foreach my $external_id (@external_ids) {
	    my $external_name = $self->get_externalname($external_id);
	    if ( not defined $external_name ) {
		## serious internal failure, already recorded by get_externalname()
		die "\n";
	    }
	    push @external_names, $external_name;
	}
    };
    if ($@) {
	$self->debug( 'error', "database access error in list_hostservice_externals($host_name, $service_name)" );
	return undef;
    }
    return \@external_names;
}

## @method arrayref list_hostprofiles_with_external (string external_name)
# List all host profiles with a specified external assigned.
# @param external_name Name of the external to search for.
# @return arrayref hostprofile_names pointing to list of names, if search was successful; undefined, if search failed
sub list_hostprofiles_with_external {
    my $self          = shift;
    my $external_name = $_[0];

    $self->debug( 'verbose', "called list_hostprofiles_with_external($external_name)" );

    my $e_ref = $self->get_external($external_name);
    if ( not defined $e_ref ) {
	## serious internal failure, already recorded by get_external()
	return undef;
    }
    elsif ( not %$e_ref ) {
	$self->debug( 'error', "external $external_name not found" );
	return undef;
    }

    my $external_id = $e_ref->{external_id};
    my $type        = $e_ref->{type};

    if ( $type ne 'host' ) {
	$self->debug( 'error', "external $external_name is not a host external" );
	return undef;
    }

    my @hostprofile_names = ();
    eval {
	my @hostprofile_ids = monarchWrapper->fetch_unique( 'external_host_profile', 'hostprofile_id', 'external_id', $external_id );
	foreach my $hostprofile_id (@hostprofile_ids) {
	    my $hostprofile_name = $self->get_hostprofilename($hostprofile_id);
	    if ( not defined $hostprofile_name ) {
		## serious internal failure, already recorded by get_hostprofilename()
		die "\n";
	    }
	    push @hostprofile_names, $hostprofile_name;
	}
    };
    if ($@) {
	$self->debug( 'error', "database access error in list_hostprofiles_with_external($external_name)" );
	return undef;
    }
    return \@hostprofile_names;
}

## @method arrayref list_services_with_external (string external_name)
# List all generic services with a specified external assigned.
# @param external_name Name of the external to search for.
# @return arrayref service_names pointing to list of names, if search was successful; undefined, if search failed
sub list_services_with_external {
    my $self          = shift;
    my $external_name = $_[0];

    $self->debug( 'verbose', "called list_services_with_external($external_name)" );

    my $e_ref = $self->get_external($external_name);
    if ( not defined $e_ref ) {
	## serious internal failure, already recorded by get_external()
	return undef;
    }
    elsif ( not %$e_ref ) {
	$self->debug( 'error', "external $external_name not found" );
	return undef;
    }

    my $external_id = $e_ref->{external_id};
    my $type        = $e_ref->{type};

    if ( $type ne 'service' ) {
	$self->debug( 'error', "external $external_name is not a service external" );
	return undef;
    }

    my @service_names = ();
    eval {
	my @servicename_ids = monarchWrapper->fetch_unique( 'external_service_names', 'servicename_id', 'external_id', $external_id );
	foreach my $servicename_id (@servicename_ids) {
	    my $service_name = $self->get_genericservicename($servicename_id);
	    if ( not defined $service_name ) {
		## serious internal failure, already recorded by get_servicename()
		die "\n";
	    }
	    push @service_names, $service_name;
	}
    };
    if ($@) {
	$self->debug( 'error', "database access error in list_services_with_external($external_name)" );
	return undef;
    }
    return \@service_names;
}

## @method arrayref list_hosts_with_external (string external_name)
# List all hosts with a specified external assigned.
# @param external_name Name of the host external to search for.
# @return arrayref host_names pointing to list of names, if search was successful; undefined, if search failed
sub list_hosts_with_external {
    my $self          = shift;
    my $external_name = $_[0];

    $self->debug( 'verbose', "called list_hosts_with_external($external_name)" );

    my $e_ref = $self->get_external($external_name);
    if ( not defined $e_ref ) {
	## serious internal failure, already recorded by get_external()
	return undef;
    }
    elsif ( not %$e_ref ) {
	$self->debug( 'error', "external $external_name not found" );
	return undef;
    }

    my $external_id = $e_ref->{external_id};
    my $type        = $e_ref->{type};

    if ( $type ne 'host' ) {
	$self->debug( 'error', "external $external_name is not a host external" );
	return undef;
    }

    my @host_names = ();
    eval {
	my @host_ids = monarchWrapper->fetch_unique( 'external_host', 'host_id', 'external_id', $external_id );
	foreach my $host_id (@host_ids) {
	    my $host_name = $self->get_hostname($host_id);
	    if ( not defined $host_name ) {
		## serious internal failure, already recorded by get_hostname()
		die "\n";
	    }
	    push @host_names, $host_name;
	}
    };
    if ($@) {
	$self->debug( 'error', "database access error in list_hosts_with_external($external_name)" );
	return undef;
    }
    return \@host_names;
}

## @method arrayref list_hostservices_with_external (string external_name)
# List all host services with a specified external assigned.
# @param external_name Name of the external to search for.
# @return hashref hostservices pointing to hash of arrayrefs (host name keys with service name arrayref values),
# if search was successful; undefined, if search failed
sub list_hostservices_with_external {
    my $self          = shift;
    my $external_name = $_[0];

    $self->debug( 'verbose', "called list_hostservices_with_external($external_name)" );

    my $e_ref = $self->get_external($external_name);
    if ( not defined $e_ref ) {
	## serious internal failure, already recorded by get_external()
	return undef;
    }
    elsif ( not %$e_ref ) {
	$self->debug( 'error', "external $external_name not found" );
	return undef;
    }

    my $external_id = $e_ref->{external_id};
    my $type        = $e_ref->{type};

    if ( $type ne 'service' ) {
	$self->debug( 'error', "external $external_name is not a service external" );
	return undef;
    }

    my %hostservices = ();
    eval {
	## FIX LATER:  This is a very clumsy and inefficient implementation.  Better would
	## be a specialized Monarch routine to perform the joins of external_service with
	## hosts and services and service_names to obtain the host and service names
	## directly in just one complete query, not in multiple additional queries, and
	## not pull back the externals content along with the fields we want.
	my %where = ( 'external_id' => $external_id );
	my %service_externals_by_generic_key = monarchWrapper->fetch_hash_array_generic_key( 'external_service', \%where );
	foreach my $external_array ( values %service_externals_by_generic_key ) {
	    my $host_id        = $$external_array[1];
	    my $hostservice_id = $$external_array[2];
	    my $host_name      = $self->get_hostname($host_id);
	    if ( not defined $host_name ) {
		## serious internal failure, already recorded by get_hostname()
		die "\n";
	    }
	    my $service_name = $self->get_servicename($hostservice_id);
	    if ( not defined $service_name ) {
		## serious internal failure, already recorded by get_servicename()
		die "\n";
	    }
	    push @{ $hostservices{$host_name} }, $service_name;
	}
    };
    if ($@) {
	$self->debug( 'error', "database access error in list_hostservices_with_external($external_name)" );
	return undef;
    }
    return \%hostservices;
}

## @method boolean propagate_external (string external_name, boolean replace)
# Propagate a free external to associated applied externals.
# @param external_name Name of the external to propagate.
# @param replace Boolean flag; whether to update (true) or ignore (false) applied externals with their "modified" flag set.
# @return status: true if successful, false otherwise
sub propagate_external {
    my $self          = shift;
    my $external_name = $_[0];
    my $replace       = $_[1];
    my $result        = '';
    my $db_error      = 0;

    $self->debug( 'verbose', "called propagate_external($external_name, $replace)" );

    my $e_ref = $self->get_external($external_name);
    if ( not defined $e_ref ) {
	## serious internal failure, already recorded by get_external()
	return undef;
    }
    elsif ( not %$e_ref ) {
	$self->debug( 'error', "external $external_name not found" );
	return 0;
    }

    my $external_id = $e_ref->{external_id};
    my $type        = $e_ref->{type};
    my $content     = $e_ref->{display};

    eval {
	my %where  = ( 'external_id' => $external_id );
	my %values = ( 'data'        => $content );
	if ($replace) {
	    $values{'modified'} = ( $self->monarch_vstring() ge v4.0 ) ? \'0+0' : '0+0';
	}
	else {
	    $where{'modified'} = 0;
	}
	$result = StorProc->update_obj_where( $type eq 'host' ? 'external_host' : 'external_service', \%values, \%where );
	if ( $result =~ /Error/ ) {
	    $db_error = 1;
	}
    };
    if ($@) {
	$result   = $@;
	$db_error = 1;
    }
    if ($db_error) {
	$self->debug( 'error', "propagating external $external_name failed: $result" );
	return undef;
    }
    return 1;
}

## @method boolean buildAllExternals (boolean force)
# Build externals for all hosts.
# @param force boolean flag; true means force regeneration even if there is no significant change in content
# @return status: true if build_all_externals succeeds, false otherwise.
sub buildAllExternals {
    my $self  = shift;
    my $force = $_[0] || '';

    $self->debug( 'verbose', "Trying to build all externals." );

    my $results;
    my $errors;
    eval {
	( $results, $errors ) =
	  monarchWrapper->build_all_externals( $self->{'user_acct'}, $self->{'session_id'}, $self->{'via_web_ui'}, $force );
    };
    if ($@) {
	$self->debug( 'error', "database access error in buildAllExternals($force)" );
	return undef;
    }
    my @errors  = @{$errors};
    my @results = @{$results};

    if (@errors) {
	$self->debug( 'error', "buildAllExternals returns error message: @errors" );
	return 0;
    }

    return 1;
}

## @method boolean buildSomeExternals (arrayref hostsref, boolean force)
# Build externals for a set of hosts.
# @param hostsref reference to an array of hostnames, to build externals only for particular hosts; undefined, to build externals for all hosts
# @param force boolean flag; true means force regeneration even if there is no significant change in content
# @return status: true if build_some_externals succeeds, false otherwise.
sub buildSomeExternals {
    my $self     = shift;
    my $hostsref = $_[0];
    my $force    = $_[1] || '';

    $self->debug( 'verbose', "Trying to build some externals." );

    my $results;
    my $errors;
    eval {
	( $results, $errors ) =
	  monarchWrapper->build_some_externals( $self->{'user_acct'}, $self->{'session_id'}, $self->{'via_web_ui'}, $hostsref, $force );
    };
    if ($@) {
	$self->debug( 'error', "database access error in buildSomeExternals($hostsref, $force)" );
	return undef;
    }
    my @errors  = @{$errors};
    my @results = @{$results};

    if (@errors) {
	$self->debug( 'error', "buildSomeExternals returns error message: @errors" );
	return 0;
    }

    return 1;
}

## @method boolean pre_flight_check (string monarch_group)
# Perform a Nagios pre-flight check.
# @param monarch_group name of the Monarch Group to check; undefined, to run pre-flight for the Main Configuration instead
# @return status: true if the preflight check succeeds, false otherwise.
sub pre_flight_check {
    my $self             = shift;
    my $monarch_group    = $_[0] || '';
    my $preflight_folder = $self->{'monarch_home'} . '/workspace';

    if ( $monarch_group && !$self->monarch_group_exists($monarch_group) ) {
	$self->debug( 'error', "Monarch Group $monarch_group does not exist" );
	return 0;
    }

    $self->debug( 'verbose', 'Attempting preflight check.' );
    my $errors;
    my $results;
    my $files;
    eval {
	( $errors, $results, $files ) = monarchWrapper->synchronized_preflight(
	    $self->{'user_acct'},
	    $self->{'nagios_ver'},
	    $self->{'nagios_etc'},
	    $self->{'nagios_bin'},
	    $self->{'monarch_home'},
	    $monarch_group,
	    '' );
    };
    if ($@) {
	$self->debug( 'error', "database access error in pre_flight_check($monarch_group)" );
	return undef;
    }
    my @errors  = @{$errors};
    my @results = @{$results};
    my @files   = @{$files};

    $self->debug( 'verbose', "Preflight files are in: $preflight_folder" ) if @files;
    $self->debug( 'info', "Pre-flight results:\n" . join( "\n", @results ) );
    my $res_str = pop @results;
    push @results, $res_str;
    unless ( $res_str =~ /Things look okay/ ) {
	push @errors, 'Make the necessary corrections and run pre-flight check.';
	$self->debug( 'error', "Errors during pre-flight, exiting:\n" . join( "\n", @errors ) );
	return 0;
    }
    return 1;
}

## @method boolean generateAndCommit (string annotation, boolean lock)
# Perform a pre-flight check, do a commit, and create a backup if the Nagios part of the commit succeeds.
# @param annotation notes on what is motivating this Commit; used to describe the associated automatic backup
# @param lock boolean flag; true means make the automatic backup immune from automated deletion
# @return status: true if commit succeeds, false otherwise.
sub generateAndCommit {
    my $self       = shift;
    my $annotation = shift;
    my $lock       = shift || '';

    $annotation = "Backup auto-created after a Commit by user \"$self->{'user_acct'}\"." if not $annotation;
    $annotation =~ s/^\s+|\s+$//g;
    $annotation .= "\n";

    $self->debug( 'verbose', 'Attempting commit.' );
    my $errors;
    my $results;
    my $timings;
    eval {
	( $errors, $results, $timings ) = monarchWrapper->synchronized_commit(
	    $self->{'user_acct'}, $self->{'nagios_ver'}, $self->{'nagios_etc'}, $self->{'nagios_bin'}, $self->{'monarch_home'},
	    '',                   $self->{'backup_dir'}, $annotation,           $lock
	);
    };
    if ($@) {
	$self->debug( 'error', "database access error in generateAndCommit($annotation, $lock)" );
	return undef;
    }
    my @errors  = @{$errors};
    my @results = @{$results};

    $self->debug( 'info', "Commit results:\n" . join( "\n", @results ) );
    if (@errors) {
	$self->debug( 'error', "Errors during pre-flight or commit, exiting:\n" . join( "\n", @errors ) );
	return 0;
    }

    return grep ( $self->{'commit_ok_string'}, @results );
}

## @method boolean build_instance (string monarch_group)
# Build the configuration for a given Monarch Group, in the directory configured in the group's details,
# and call the Monarch Deploy code to push the updated configuration to the child server.
# @param monarch_group name of the Monarch Group to build
# @return status: true if build and deploy succeeds, false otherwise.
sub build_instance {
    my $self          = shift;
    my $monarch_group = $_[0];

    $self->debug( 'verbose', "Trying to build instance for Monarch Group $monarch_group." );

    if ( !$self->monarch_group_exists($monarch_group) ) {
	$self->debug( 'error', "Monarch Group $monarch_group does not exist" );
	return 0;
    }

    my $files;
    my $errors;
    eval {
	( $files, $errors ) =
	  monarchWrapper->build_files( $self->{'user_acct'}, "$monarch_group", 'commit', '',
	    $self->{'nagios_ver'}, $self->{'nagios_etc'}, '', '' );
    };
    if ($@) {
	$self->debug( 'error', "database access error in build_instance($monarch_group)" );
	return undef;
    }
    my @errors = @{$errors};
    my @files  = @{$files};

    if (@errors) {
	$self->debug( 'error', "Build instance for group $monarch_group failed: @errors" );
	return 0;
    }

    $self->debug( 'info',    "Build instance produced these files: @files" );
    $self->debug( 'verbose', "Trying to deploy files for Monarch Group $monarch_group." );

    # Servername seems to be identical with groupname (as far as i understand from the monarch.cgi and deploy code)
    my $location = $self->get_monarchgroup_location($monarch_group);
    if ( not $location ) {
	$self->debug( 'error', "No location (build path) for Monarch Group $monarch_group found" );
	return defined($location) ? 0 : undef;
    }
    else {
	$self->debug( 'verbose', "Found location $location for Monarch Group $monarch_group" );
    }

    my @results = ();
    eval {
	@results = monarchWrapper->deploy( $monarch_group, $location, $self->{'nagios_etc'}, $self->{'monarch_home'} );
    };
    if ($@) {
	$self->debug( 'error', "database access error in build_instance($monarch_group)" );
	return undef;
    }

    my $results = join( "\n", @results );

    if ( $results =~ /Error/i ) {
	$self->debug( 'error', "Deploy returns error message: \n$results" );
	return 0;
    }
    else {
	$self->debug( 'verbose', "Deploy returned with no explicit error message. message was: \n$results" );
	$self->debug( 'info',    "Monarch's deploy function does no error tracking, please check, if everything worked fine." );
    }

    return 1;
}

# FIX MAJOR:  perhaps also provide:
# boolean remove_hostprofile_from_host(string hostname, string hostprofilename)
# sub remove_hostprofile_from_host {
# }

# FIX MAJOR:  perhaps also provide:
# boolean assign_serviceprofile_to_hostprofile(string hostprofilename, string serviceprofilename)
# sub assign_serviceprofile_to_hostprofile {
# }

# FIX MAJOR:  perhaps also provide:
# boolean remove_serviceprofile_from_hostprofile(string hostprofilename, string serviceprofilename)
# sub remove_serviceprofile_from_hostprofile {
# }

1;
