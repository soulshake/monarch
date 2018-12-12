# MonArch - Groundwork Monitor Architect
# MonarchAudit.pm
#
############################################################################
# Release 4.6
# September 2018
############################################################################
#
# Original author: Scott Parris
#
# Copyright 2008-2018 GroundWork Open Source, Inc. (GroundWork)
# All rights reserved.  This program is free software; you can redistribute
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

# Major changes:
#
# Nov 2008 Thomas Stocking
#	Changed to add service group sync for GroundWork Monitor 5.3.
#
# Dec 2008 Thomas Stocking
#	Changed to add host Parents, extended info to Foundation as properties.
#
# Oct 2009 Glenn Herteg
#	Fixed issues with empty hostgroups and servicegroups not being recognized.
#	Optimized database accesses.
#
# Jun 2010 Glenn Herteg
#	Support notes for hosts, host services, hostgroups, and servicegroups.
#	This inclues application of extended info templates, and substitution
#	of certain simple static Nagios macros.
#
# Aug 2010 Glenn Herteg
#	Modify handling of the "__Inactive hosts" hostgroup to at least construct
#	the hostgroup as originally intended.  (FIX MINOR:  Still needs work to
#	force being a member of this hostgroup to suppress monitoring.)
#
# Dec 2010 Glenn Herteg
#	Add service groups to Monarch groups, by intersecting domains.
#	Fix creation of the hostgroup for unassigned hosts in a group.
#
# Feb 2011 Glenn Herteg
#	Drop the "__Inactive hosts" hostgroup, as in fact there is no scenario
#	where it is actually useful.  Instead, filter out inactive hosts from
#	hostgroups, services, and servicegroups; and drop empty hostgroups
#	and servicegroups.
#
# Oct 2012 Glenn Herteg
#	Accommodate non-NAGIOS-apptype hosts in Foundation.
#
# Oct 2014 Glenn Herteg
#	Port to use GW::RAPID.
#
# Oct 2015 DN GWMON-12290 fix (required CollageQuery.pm 
#
# Aug 2016 Glenn Herteg
#	Localize $_ where explicit references are present. 
#
# Sep 2018 Glenn Herteg
#	Convert the form of REST call used to fetch host data from Foundation.

use strict;

use MonarchStorProc;
use CollageQuery;

# For debugging ...
use Data::Dumper;
$Data::Dumper::Indent   = 1;
$Data::Dumper::Sortkeys = 1;

package Audit;

# Option for debug
my $debug = 0;
my $debug_summary = $debug >= 1;
my $debug_changes = $debug >= 2;
my $debug_dumps   = $debug >= 3;

my $use_rest_api = 1;    # set to 1 to use the REST API instead of the $remote_port socket API, 0 otherwise

# TODO:  Add a field in the monarch database flagging whether the database in
# its current state has passed a preflight (meaning that the files generated
# from this DB have passed).  Should only do the sync when the field is set
# to true.  MonarchStorProc.pm would need to manage that field, setting it to
# false after all significant updates and inserts.  Could have separate fields
# for each Monarch group (with each Monarch group representing a child server).
# Also add last_commit_time values in the setup and monarch_group_props tables,
# to track when the last successful commit took place.  That could help external
# programs know when these events occurred.

# Internal routine only, for now.
# FIX LATER:  This first implementation just replaces a small amount of static data such as
# $HOSTNAME$, not the full set of macros that Nagios supports.  Future releases may extend
# this set, possibly including such things as $HOSTACTIONURL$, $HOSTNOTESURL$, $SERVICEGROUPNAME$,
# $SERVICEACTIONURL$, and $SERVICENOTESURL$, and possibly adding support for the $USERn$ macros
# as well.  Macros which are dynamically evaluated by Nagios won't be supported.
sub replace_macros {
    my $string     = shift;
    my $macros_ref = shift;

    if (defined $string) {
	foreach my $macro ( keys %$macros_ref ) {
	    $string =~ s/$macro/$$macros_ref{$macro}/g;
	}
    }

    return $string;
}

# Special note on handling "notes":
# (*) For purposes of comparison here, we normalize undef, '', and ' ' from Foundation
#     to '' for comparison with Monarch.  We normalize undef and '' from Monarch to ''.
# (*) If the normalized Foundation and Monarch values are different, and the Monarch
#     value is '', then we send ' ' to Foundation, not an empty string ('').

sub foundation_sync_group {
    my $self       = shift;
    my $group_name = shift;
    my $rest_api   = shift;

    return foundation_sync( '', { 'group' => $group_name }, $rest_api );
}

sub foundation_sync {
    my $self     = shift;
    my $arg_ref  = shift;
    my $rest_api = shift;
    my $group;
    my @timings = ();
    my $phasetime;
    my $indent_dumps_as_html = 0;
    local $_;

    StorProc->start_timing( \$phasetime );

    # Only accept the group name if it is in named parameter format,
    # because otherwise, when someone accustomed to the old way of
    # using this subroutine passed in a folder name as a parameter,
    # the code would incorrectly treat the folder name as a group name.
    if ( defined($arg_ref) ) {
	if ( defined( $arg_ref->{group} ) ) {
	    $group = $arg_ref->{'group'};
	    $indent_dumps_as_html = 1;
	}
	else {
	    ## warn in the logs. no error needed; will sync everything
	    print STDERR "Warning: invalid argument [$arg_ref] to foundation_sync()\n";
	}
    }

    # else default to no group, the normal case.
    # Folder name args from old-style calls are harmlessly ignored.

    my @errors       = ();
    my %last         = ();
    my %current      = ();
    my %delta        = ();
    my $foundation   = CollageQuery->new();
    my $apptype      = 'NAGIOS';              # Application type used to query Foundation for hosts owned by Monarch.

    my $cascade_deleted_services             = 0;
    my $cascade_deleted_hostgroup_members    = 0;
    my $cascade_deleted_servicegroup_members = 0;
    my $cleared_hostgroup_members            = 0;
    my $cleared_servicegroup_members         = 0;

    # Connect to Monarch database. Disconnect later.
    StorProc->dbconnect();

    my %groups     = ();
    my %group_info = ();
    if ( defined($group) ) {
	# Factor out the common processing we need later for a group.
	my %where = ( 'name' => $group );
	%group_info = StorProc->fetch_one_where( 'monarch_groups', \%where );
	if ( !defined( $group_info{'group_id'} ) ) {
	    print STDERR  "Error:  Invalid group \"$group\".\n";
	    push @errors, "Error:  Invalid group \"$group\".";
	    StorProc->dbdisconnect();
	    return \@errors, \@timings, %delta;
	}
	## FIX MINOR:  StorProc->get_groups() doesn't actually take any arguments
	%groups = StorProc->get_groups( $group_info{'group_id'}, \%groups );
    }

    # get the hosts known to Monarch
    my %host_name = StorProc->get_table_objects( 'hosts', '1' );  # $host_name{$hostid} = $hostname;
    my @m_hosts = ();
    if ( defined($group) ) {
	## Special treatment if using Monarch groups (for parent/child setups).
	## Monarch groups are distinct from hostgroups and other Nagios groups.
	@m_hosts = split( ',', $groups{$group}{'hosts'} ) if ( defined( $groups{$group}{'hosts'} ) );
    }
    else {
	# Could probably replace with "values %host_name" and avoid more DB access.
	@m_hosts = StorProc->fetch_list( 'hosts', 'name' );
    }

    # get the hostgroups known to Monarch (and maybe some additional hosts)
    my @m_hostgroups = ();
    if ( defined($group) ) {
	## Again, special treatment for Monarch groups (for parent/child setups).
	my ( $hosts_in_hostgroups_not_in_group, $hosts_in_hostgroups_in_group ) =
	  StorProc->get_hostgroups_hosts( $group_info{'group_id'} );
	my %hosts_in_hostgroups_in_group = %{ $hosts_in_hostgroups_in_group };
	foreach my $hostgroup ( keys %hosts_in_hostgroups_in_group ) {
	    ## We also have to update the @m_hosts array here, because not doing
	    ## so would miss any hosts that are included under a group only by
	    ## virtue of being in a hostgroup sitting in the group.  This may
	    ## result in duplicates, which we will later eliminate.
	    push @m_hosts,      @{ $hosts_in_hostgroups_in_group{$hostgroup} };
	    push @m_hostgroups, $hostgroup;
	}
    }
    else {
	## not doing a Monarch group; get all hostgroups
	@m_hostgroups = StorProc->fetch_list( 'hostgroups', 'name' );
    }

    # De-dupe and filter the list of hosts, to include just one of each active host.
    my %is_inactive_host_id   = StorProc->get_inactive_hosts(0);
    my %is_inactive_host_name = map { $_ => 1 } @host_name{ keys %is_inactive_host_id };
    my %is_monarch_host = ();
    @is_monarch_host{@m_hosts} = (1) x @m_hosts;
    @m_hosts = grep { not $is_inactive_host_name{$_} } keys %is_monarch_host;

    # Then make a lookup table of all the active hosts, by hostname.
    my %is_active_host = map { $_ => 1 } @m_hosts;

    my $cur_alias;
    my $cur_notes;
    my $hostgroups = StorProc->get_hostgroups_for_sync( \@m_hostgroups );
    foreach my $hostgroup (@m_hostgroups) {
	my %members = map { $_ => 1 } grep { $is_active_host{$_} } @{ $hostgroups->{$hostgroup}{'members'} };
	if (%members) {
	    $current{'hostgroup'}{$hostgroup}{'members'} = \%members;
	    $cur_alias = $hostgroups->{$hostgroup}{'alias'};
	    $cur_alias = '' if not defined $cur_alias;
	    $current{'hostgroup'}{$hostgroup}{'alias'} = $cur_alias;
	    my %hostgroup_macros = (
		'\$HOSTGROUPALIAS\$' => $cur_alias
	    );
	    $cur_notes = $hostgroups->{$hostgroup}{'notes'};
	    $cur_notes = '' if not defined $cur_notes;
	    $current{'hostgroup'}{$hostgroup}{'notes'} = replace_macros($cur_notes, \%hostgroup_macros);
	    ## FIX MINOR:  No $delta{'exists'} member is used anywhere, either here or in MonarchFoundationSync.
	    ## Just drop this and similar code?
	    $delta{'exists'}{'hostgroup'}{$hostgroup} = 1;
	}
    }

    # returns $allhostservices->{host_name}{service_id}{'fieldname'} = value
    my $allhostservices = StorProc->get_hosts_services_for_sync();

    my %hosts_services = StorProc->get_hostid_servicenameid_serviceid();

    # get the servicegroups known to Monarch
    #
    # Service groups are not (yet?) supported as explicitly selected members of a Monarch
    # group, but we can slice down existing service groups to only include services on
    # hosts that are in the Monarch group.  This amounts to implicit inclusion of all
    # service groups, while intersecting them with the Monarch group boundaries.  Hosts
    # are included in Monarch groups as whole objects (i.e., with all of their host
    # services), so we don't need to also intersect with individual services.  This
    # filtering also cleanly drops inactive hosts, even when we're not analyzing the
    # configuration for just a single Monarch group.
    my %m_servicegroups = StorProc->get_service_groups;
    foreach my $servicegroup ( keys %m_servicegroups ) {
	my $sg_hosts = $m_servicegroups{$servicegroup}{'hosts'};
	if (defined $sg_hosts) {
	    foreach my $host_id (keys %$sg_hosts) {
		if ( not $is_active_host{ $host_name{$host_id} } ) {
		    delete $sg_hosts->{$host_id};
		}
	    }
	}
	# We go one step further in the intersection process, and drop empty service groups.
	if (!defined( $sg_hosts ) or !%$sg_hosts) {
	    delete $m_servicegroups{$servicegroup};
	}
    }

    # FIX THIS:  Revise to call StorProc->get_service_instances_status_for_sync() as we do later on,
    # instead of calling StorProc->get_service_instances(), and perhaps then we won't need to call
    # StorProc->get_service_instances_status_for_sync() later on.  Other stuff here can probably be
    # similarly moved and simplified.  Or creatively invoke StorProc->fetch_map() or
    # StorProc->fetch_map_where() to help simplify this code.
    foreach my $servicegroup ( keys %m_servicegroups ) {
	my $sg_hosts = $m_servicegroups{$servicegroup}{hosts};
	if (defined $sg_hosts && %$sg_hosts) {
	    my %servicegroup_macros = (
		'\$SERVICEGROUPALIAS\$' => $m_servicegroups{$servicegroup}{alias}
	    );
	    $cur_notes = $m_servicegroups{$servicegroup}{notes};
	    $cur_notes = '' if not defined $cur_notes;
	    $current{'servicegroupnotes'}{$servicegroup} = replace_macros($cur_notes, \%servicegroup_macros);
	    foreach my $s_group_host_id (keys %$sg_hosts) {
		my $s_grouphost = $host_name{$s_group_host_id};
		my $sg_services = $sg_hosts->{$s_group_host_id};
		my $svc_members = defined($sg_services) ? [ map { $allhostservices->{$s_grouphost}{$_}{'name'} } keys %$sg_services ] : [];
		foreach my $memberservice ( @$svc_members ) {
		    my %where = ( 'name' => $memberservice );
		    my %service_info              = StorProc->fetch_one_where( 'service_names', \%where );
		    my $servicename_id            = $service_info{'servicename_id'};
		    my $service_id                = $hosts_services{$s_group_host_id}{$servicename_id};
		    my %service_instances         = StorProc->get_service_instances_names($service_id);
		    my %service_instance_statuses = StorProc->get_service_instances($service_id);
		    if ( keys %service_instances ) {
			foreach my $instance_id ( keys %service_instances ) {
			    foreach my $instance_suffix ( keys %service_instance_statuses ) {
				## Monarch sets the status to 1 if the instance is active,
				## to NULL if the instance is inactive.
				## FIX THIS:  what is NULL translated to here?
				## FIX THIS:  should we use defined() on the status, or directly test its value instead?
				if ( $service_instance_statuses{$instance_suffix}{'id'} == $instance_id
				  && !$service_instance_statuses{$instance_suffix}{'status'} ) {
				    print STDERR 'Deleting inactive instance of service: ', $memberservice, ': ',
				      $service_instances{$instance_id}{'name'}, "\n" if $debug_changes;
				    delete $service_instances{$instance_id}{'name'};
				}
			    }
			    if ( defined $service_instances{$instance_id}{'name'} ) {
				my $service_instance_suffix = $service_instances{$instance_id}{'name'};
				my $full_sinstance_name     = $memberservice . $service_instance_suffix;
				$current{'servicegroup'}{$servicegroup}{$s_grouphost}{$full_sinstance_name} = 1;
			    }
			}
		    }
		    else {
			$current{'servicegroup'}{$servicegroup}{$s_grouphost}{$memberservice} = 1;
		    }
		}
	    }
	}
    }

    StorProc->capture_timing( \@timings, \$phasetime, 'getting hosts, services, hostgroups, and servicegroups from Monarch' );

    # FIX LATER:  The nested queries to Foundation are terribly inefficient.  As we encounter
    # and are able to test with large configurations that show they consume significant time,
    # replace them with single top-level queries that pull back entire trees of data in one go,
    # making sure that we handle missing data properly (not just depending on inner joins).
    # When we make such conversions, rework the calls to return proper errors, and capture
    # them here.

    # FIX LATER:  Possibly insert stuff in here to periodically tell Apache that this code is
    # still alive; if so, make sure it is also compatible with running outside of that context.
    # But only do so if testing shows the entire audit phase takes a significant period of time.

    # get hosts known to Foundation
    my $err_ref;
    my $time_ref;
    my $f_hosts;
    if ( $use_rest_api && $rest_api ) {
	( $err_ref, $time_ref, $f_hosts ) = getSyncHosts($rest_api);
	push @timings, @$time_ref;
    }
    else {
	( $err_ref, $f_hosts ) = $foundation->getSyncHosts();
    }
    if (@$err_ref) {
	push @errors, @$err_ref;
    }
    else {
	StorProc->capture_timing( \@timings, \$phasetime, 'getting only Sync hosts from Foundation' );

	# FIX MAJOR:  drop this after debugging is complete
	if (0) {
	    print "sync hosts: " . Data::Dumper->Dump( [ $f_hosts ], [qw($f_hosts)] );
	}

	if ( ref($f_hosts) eq 'HASH' ) {
	    my $old_notes;
	    my $f_host;
	    my $last_host;
	    foreach my $host ( keys %{$f_hosts} ) {
		$f_host = $f_hosts->{$host};
		next if $f_host->{'ApplicationType'} ne $apptype and !exists( $f_host->{'Services'} ) and !$is_active_host{$host};
		$last_host = \%{ $last{'host'}{$host} };
		$last_host->{'apptype'} = defined( $f_host->{'ApplicationType'} ) ? $f_host->{'ApplicationType'} : '';
		$last_host->{'address'} = defined( $f_host->{'Identification'} )  ? $f_host->{'Identification'}  : '';
		$last_host->{'alias'}   = defined( $f_host->{'Alias'} )           ? $f_host->{'Alias'}           : '';
		$old_notes              = $f_host->{'HostNotes'};
		$last_host->{'hostnotes'} = ( defined($old_notes) && $old_notes ne ' ' ) ? $old_notes : '';
		$last_host->{'parents'} = defined( $f_host->{'Parents'} ) ? $f_host->{'Parents'} : '';

		# Add queries for other Host properties from Foundation here.

		if ( defined( $f_host->{'Services'} ) ) {
		    foreach my $service ( @{ $f_host->{'Services'} } ) {
			$last_host->{'service'}{$service}      = 1;
			$old_notes                             = $f_host->{'ServiceNotes'}{$service};
			$last_host->{'servicenotes'}{$service} = ( defined($old_notes) && $old_notes ne ' ' ) ? $old_notes : '';

			# Query for specific service properties here.
		    }
		}
	    }
	}
    }

    StorProc->capture_timing( \@timings, \$phasetime, 'getting hosts from Foundation' );

    unless (@errors) {
	## get the hostgroups known to Foundation and managed by Monarch
	my $f_hostgroups;
	if ( $use_rest_api && $rest_api ) {
	    ## FIX MAJOR:  Should this call perform a deeper retrieval that grabs all the associated hostnames
	    ## as well, so we don't need separate getHostsForHostGroup() calls in the following loop?
	    ( $err_ref, $f_hostgroups ) = getHostGroupsByType( $rest_api, $apptype );
	    push @errors, @$err_ref if @$err_ref;
	}
	else {
	    $f_hostgroups = $foundation->getHostGroupsByType($apptype);
	}
	if ( ref($f_hostgroups) eq 'HASH' ) {
	    my $old_alias;
	    my $old_notes;
	    foreach my $hostgroup ( keys %{$f_hostgroups} ) {
		if ( $hostgroup eq '' ) {
		    print STDERR "WARNING:  Audit found empty hostgroup name in Foundation.\n";
		    next;
		}
		$old_alias = $f_hostgroups->{$hostgroup}{'Alias'};
		$last{'hostgroup'}{$hostgroup}{'alias'} = (defined($old_alias) && $old_alias ne ' ') ? $old_alias : '';
		$old_notes = $f_hostgroups->{$hostgroup}{'Description'};
		$last{'hostgroup'}{$hostgroup}{'notes'} = (defined($old_notes) && $old_notes ne ' ') ? $old_notes : '';
		my $f_hosts;
		if ( $use_rest_api && $rest_api ) {
		    ( $err_ref, $f_hosts ) = getHostsForHostGroup( $rest_api, $hostgroup );
		    if (@$err_ref) {
			push @errors, @$err_ref;
			last;
		    }
		}
		else {
		    $f_hosts = $foundation->getHostsForHostGroup($hostgroup);
		}
		%{ $last{'hostgroup'}{$hostgroup}{'members'} } = ();
		if ( ref($f_hosts) eq 'HASH' ) {
		    foreach my $host ( keys %{$f_hosts} ) {
			$last{'hostgroup'}{$hostgroup}{'members'}{$host} = 1;
		    }
		}
	    }
	}
	StorProc->capture_timing( \@timings, \$phasetime, 'getting hostgroups from Foundation' );
    }

    unless (@errors) {
	# get the servicegroups known to Foundation; we don't filter because service groups are (currently) solely a Monarch construct
	# DN GWMON-12290 10/30/15 - that is no longer correct and sg's can be SYSTEM type for example. So filter on NAGIOS app type.
	my $f_servicegroups;
	if ( $use_rest_api && $rest_api ) {
	    ## FIX MAJOR:  Should this call perform a deeper retrieval that grabs all the associated hostnames/servicenames
	    ## as well, so we don't need separate getHostServicesForServiceGroup() calls in the following loop?
	    ( $err_ref, $f_servicegroups ) = getServiceGroups($rest_api);
	    push @errors, @$err_ref if @$err_ref;
	}
	else {
   	    # DN 10/30/15 This is the problem behind GWMON-12290. The CollageQuery->getServiceGroups() method returns groups of all types.
   	    # However, in this context, we only want NAGIOS types, else sg's created by other things, like Admin->custom groups,
   	    # will end up getting deleted. The change was to modify CollageQuery->getServiceGroups() query to return the ApplicationType 
   	    # ie the name eg NAGIOS, SYSTEM, etc. Then that info can be used for filtering against.
	    $f_servicegroups = $foundation->getServiceGroups(); 
	}
	if ( ref($f_servicegroups) eq 'HASH' ) {
	    my $old_notes;
	    foreach my $servicegroup ( keys %{$f_servicegroups} ) {
		if ( $servicegroup eq '' ) {
		    print STDERR "$0: Warning: empty servicegroup\n";
		    next;
		}

		# DN 10/30/15 GWMON-12290
		# Filter to just NAGIOS app type sg's 
		# NOTE: Only tested and developed for XML api, not REST api. Similar fix will need to be done for REST api mode too later if necessary.
		# Check the ApplicationType key exists - it won't if in REST api mode.
		# This filter limits things to just NAGIOS app type sg's.
		if ( exists $f_servicegroups->{$servicegroup}{ApplicationType} and $f_servicegroups->{$servicegroup}{ApplicationType} ne 'NAGIOS' ) {
			next; 
		}

		$old_notes = $f_servicegroups->{$servicegroup}{'Description'};
		$last{'servicegroup'}{$servicegroup}{'notes'} = ( defined($old_notes) && $old_notes ne ' ' ) ? $old_notes : '';
		if ( $use_rest_api && $rest_api ) {
		    my $f_host_services;
		    ( $err_ref, $f_host_services ) = getHostServicesForServiceGroup($rest_api, $servicegroup);
		    if (@$err_ref) {
			push @errors, @$err_ref;
			last;
		    }

		    ## FIX MINOR:  Do we ever really need to make this initialization, in case we find
		    ## a servicegroup in Foundation with no associated host/service combinations?
		    ## Or is this simply a way around a failure of the getHostServicesForServiceGroup()
		    ## call to execute correctly?
		    %{ $last{'servicegroup'}{$servicegroup}{'host'} } = ();

		    foreach my $host ( keys %{$f_host_services} ) {
			my $f_services = $f_host_services->{ $host };
			if ( ref($f_services) eq 'HASH' ) {
			    foreach my $service ( keys %{$f_services} ) {
				$last{'servicegroup'}{$servicegroup}{'host'}{$host}{'service'}{$service} = 1;
			    }
			}
			else {
			    ## FIX MINOR:  does this case even make sense, having a host in the
			    ## servicegroup in Foundation, but with no associated services?
			    %{ $last{'servicegroup'}{$servicegroup}{'host'}{$host}{'service'} } = ();
			}
		    }
		}
		else {
		    ## FIX LATER:  getHostsForServiceGroup() and getHostServicesForServiceGroup() work, but such nested
		    ## queries are a horribly inefficient mechanism.  Replace with something that retrieves in bulk.
		    my $f_hosts = $foundation->getHostsForServiceGroup($servicegroup);

		    ## FIX LATER:  Do we ever really need to make this initialization, in case we find
		    ## a servicegroup in Foundation with no associated host/service combinations?
		    %{ $last{'servicegroup'}{$servicegroup}{'host'} } = ();

		    if ( ref($f_hosts) eq 'HASH' ) {
			foreach my $host ( keys %{$f_hosts} ) {
			    ## Should have been called getServicesForServiceGroupHost().
			    my $f_services = $foundation->getHostServicesForServiceGroup( $servicegroup, $host );
			    if ( ref($f_services) eq 'HASH' ) {
				foreach my $service ( keys %{$f_services} ) {
				    $last{'servicegroup'}{$servicegroup}{'host'}{$host}{'service'}{$service} = 1;
				}
			    }
			    else {
				## FIX THIS:  does this case even make sense, having a host in the
				## servicegroup in Foundation, but with no associated services?
				%{ $last{'servicegroup'}{$servicegroup}{'host'}{$host}{'service'} } = ();
			    }
			}
		    }
		}
	    }
	}
	StorProc->capture_timing( \@timings, \$phasetime, 'getting servicegroups from Foundation' );
    }

    if ( $debug_dumps ) {
	print STDERR "last hash dump:\n";
	my $dump = Data::Dumper->Dump( [ \%last ], [qw(\%last)] );
	$dump =~ s{^( +)}{':&nbsp;&nbsp;&nbsp;'x(length($1)/2)}mge if $indent_dumps_as_html;
	print STDERR $dump;
	StorProc->capture_timing( \@timings, \$phasetime, 'printing last hash' );
    }

    unless (@errors) {
	## Assign hosts and services to delta hash.
	my %extended_host_info_templates    = StorProc->get_hostextinfo_templates('by_id');
	my %extended_service_info_templates = StorProc->get_serviceextinfo_templates('by_id');

	my $allhostproperties = StorProc->fetch_hosts_for_sync();
	StorProc->capture_timing( \@timings, \$phasetime, 'efficiently getting all hostproperties from Monarch' );

	# FIX THIS:  Is there a need to join instance data here through service_instance.instance_id
	# values intead of service_instance.{service_id,name}?

	# returns $allinstancestatuses->{service_id}{instance_suffix} = status
	# from the service_instance table, with status showing up here as either 1 (active) or 0 (inactive).
	# Also, two instances with the same service_id and service_name (if such a thing is possible)
	# will be collapsed together here.  Presumably, some upstream code is preventing such a situation
	# from arising in the first place.
	my $allinstancestatuses = StorProc->get_service_instances_status_for_sync();
	StorProc->capture_timing( \@timings, \$phasetime, 'efficiently getting all service instance statuses from Monarch' );

	my $host_services = undef;
	my $host_notes    = undef;
	my $service_notes = undef;
	## FIX LATER:  The hostgroup and servicegroup membership of inactive hosts will always be deleted in
	## Foundation.  But we might want to make more-subtle choices in how to handle inactive hosts.  Inactive
	## hosts which are not in Foundation should not be added to Foundation (which the current code supports),
	## while inactive hosts (and their services) which are already in Foundation should perhaps be left there
	## unaltered (until such time as the host is either made active [after which the host and its services will
	## be treated normally once again at the next Commit] or deleted from Monarch [after which they will be
	## deleted from Foundation at the next Commit if they are owned by Monarch]).
	##
	## Iterate over all the active hosts in Monarch, ignoring inactive hosts.
	foreach my $host (@m_hosts) {
	    my %host_macros = (
		'\$HOSTNAME\$'      => $host,
		'\$HOSTALIAS\$'     => $allhostproperties->{$host}{'alias'},
		'\$HOSTADDRESS\$'   => $allhostproperties->{$host}{'address'}
		## '\$HOSTGROUPNAME\$' => $xxx
	    );
	    $delta{'exists'}{'host'}{$host} = 1;
	    $current{'host'}{$host}{'alias'}   = $allhostproperties->{$host}{'alias'};
	    $current{'host'}{$host}{'address'} = $allhostproperties->{$host}{'address'};
	    $host_notes =
	      defined( $allhostproperties->{$host}{'notes'} ) ? $allhostproperties->{$host}{'notes'} :
	      defined( $allhostproperties->{$host}{'hostextinfo_id'} ) ?
	      $extended_host_info_templates{ $allhostproperties->{$host}{'hostextinfo_id'} }{'notes'} :
	      undef;
	    $host_notes = '' if not defined $host_notes;
	    $current{'host'}{$host}{'notes'}   = replace_macros($host_notes, \%host_macros);
	    $current{'host'}{$host}{'parents'} = join( ',', @{ $allhostproperties->{$host}{'parents'} } );
	    $host_services = $allhostservices->{$host};
	    foreach my $service_id ( keys %{ $host_services } ) {
		my $service = $host_services->{$service_id}{'name'};
		$service_notes =
		  defined( $host_services->{$service_id}{'notes'} ) ? $host_services->{$service_id}{'notes'} :
		  defined( $host_services->{$service_id}{'serviceextinfo_id'} ) ?
		  $extended_service_info_templates{ $host_services->{$service_id}{'serviceextinfo_id'} }{'notes'} :
		  undef;
		$service_notes = '' if not defined $service_notes;
		if ( defined $allinstancestatuses->{$service_id} ) {
		    # If any service instances are defined, then even if all of them are inactive,
		    # the base unsuffixed service should not be defined.  This is the same rule we
		    # follow when generating Nagios configuration files.
		    if ( defined( $last{'host'}{$host} ) && defined( $last{'host'}{$host}{'service'}{$service} ) ) {
			$delta{'delete'}{'service'}{$host}{$service} = 1;
		    }
		    foreach my $instance_suffix ( keys %{ $allinstancestatuses->{$service_id} } ) {
			if ( $allinstancestatuses->{$service_id}{$instance_suffix} ) {
			    ## Treat each active service instance as being present.

			    # Not sure this precaution is ever needed, but it seems harmless.
			    # FIX LATER:  verify this in the UI
			    next if !defined $instance_suffix;

			    my $full_sinstance_name = $service . $instance_suffix;
			    my %service_macros = (
				'\$SERVICEDESC\$' => $full_sinstance_name
				## '\$SERVICEGROUPNAME\$' => $xxx
			    );
			    $delta{'exists'}{'service'}{$host}{$full_sinstance_name} = 1;
			    $current{'service'}{$host}{$full_sinstance_name} = 1;
			    $current{'servicenotes'}{$host}{$full_sinstance_name} = replace_macros($service_notes, \%service_macros);
			}
			else {
			    ## Each inactive service instance is to be ignored except
			    ## for its effect above in suppressing the base service.
			    ## FIX LATER:  Might altering the hash on-the-fly this way
			    ## interfere with scanning the keys in the enclosing loop?
			    ## If so, we can probably just comment this out.
			    delete $allinstancestatuses->{$service_id}{$instance_suffix};
			}
		    }
		}
		else {
		    # We only have the base host service, with no instances.
		    my %service_macros = (
			'\$SERVICEDESC\$' => $service
			## '\$SERVICEGROUPNAME\$' => $xxx
		    );
		    $delta{'exists'}{'service'}{$host}{$service} = 1;
		    $current{'service'}{$host}{$service} = 1;
		    $current{'servicenotes'}{$host}{$service} = replace_macros($service_notes, \%service_macros);
		}
	    }
	}
	StorProc->capture_timing( \@timings, \$phasetime, 'getting host attributes and service instances from Monarch' );
    }

    unless (@errors) {
	## Special hostgroups -- inactive and unassigned hosts -- assign to delta hash.
	my %group_hosts = ();
	%group_hosts = map { $_ => 1 } split( ',', $groups{$group}{'hosts'} )
	  if ( defined($group) && defined( $groups{$group}{'hosts'} ) );
	## FIX LATER:  drop this code for generating the inactive hostgroup
	## GWMON-9013: inactive hostgroup generation is now disabled
	if (0 && %is_inactive_host_id) {
	    my $inactive_hostgroup = '__Inactive hosts';
	    my $host;
	    foreach my $host_id ( keys %is_inactive_host_id ) {
		$host = $host_name{$host_id};
		next if ( defined($group) && !defined( $group_hosts{$host} ) );
		$current{'hostgroup'}{$inactive_hostgroup}{'members'}{$host} = 1;
	    }
	    if ( $current{'hostgroup'}{$inactive_hostgroup} ) {
		$delta{'exists'}{'hostgroup'}{$inactive_hostgroup} = 1;
		$current{'hostgroup'}{$inactive_hostgroup}{'alias'} = '';
		$current{'hostgroup'}{$inactive_hostgroup}{'notes'} = '';
	    }
	}
	my @unassigned_hosts = StorProc->get_hosts_unassigned( $group_info{'group_id'} );
	if (@unassigned_hosts) {
	    my $unassigned_hostgroup = '__Hosts not in any host group';
	    foreach my $host (@unassigned_hosts) {
		next if $is_inactive_host_name{$host};
		next if ( defined($group) && !defined( $group_hosts{$host} ) );
		$current{'hostgroup'}{$unassigned_hostgroup}{'members'}{$host} = 1;
	    }
	    if ( $current{'hostgroup'}{$unassigned_hostgroup} ) {
		$delta{'exists'}{'hostgroup'}{$unassigned_hostgroup} = 1;
		$current{'hostgroup'}{$unassigned_hostgroup}{'alias'} = '';
		$current{'hostgroup'}{$unassigned_hostgroup}{'notes'} = '';
	    }
	}
    }

    unless (@errors) {
	my $cur_notes;
	my $last_host;
	foreach my $host ( keys %{ $current{'host'} } ) {
	    $last_host = $last{'host'}{$host};
	    if ($last_host) {

		## Check for host properties changes

		## Alias change?
		if ( $last_host->{'alias'} ne $current{'host'}{$host}{'alias'} ) {
		    print STDERR "Comparing $host alias: $last_host->{'alias'} ne $current{'host'}{$host}{'alias'}\n"
		      if $debug_dumps;
		    $delta{'alter'}{'host'}{$host}{'alias'} = $current{'host'}{$host}{'alias'};
		}
		## Address change?
		if ( $last_host->{'address'} ne $current{'host'}{$host}{'address'} ) {
		    print STDERR "Comparing $host address: $last_host->{'address'} ne $current{'host'}{$host}{'address'}\n"
		      if $debug_dumps;
		    $delta{'alter'}{'host'}{$host}{'address'} = $current{'host'}{$host}{'address'};
		}
		## Notes change?
		$cur_notes = $current{'host'}{$host}{'notes'};
		if ( $last_host->{'hostnotes'} ne $cur_notes ) {
		    print STDERR "Comparing $host notes: $last_host->{'notes'} ne $cur_notes\n" if $debug_dumps;
		    $delta{'alter'}{'host'}{$host}{'notes'} = ($cur_notes eq '') ? ' ' : $cur_notes;
		}
		## Parents change?
		if ( $last_host->{'parents'} ne $current{'host'}{$host}{'parents'} ) {
		    print STDERR "Comparing $host parents: $last_host->{'parents'} ne $current{'host'}{$host}{'parents'}\n"
		      if $debug_dumps;
		    $delta{'alter'}{'host'}{$host}{'parents'} = $current{'host'}{$host}{'parents'};
		}

		foreach my $service ( keys %{ $current{'service'}{$host} } ) {
		    if ( exists( $last_host->{'service'}{$service} ) ) {
			$cur_notes = $current{'servicenotes'}{$host}{$service};
			if ( $last_host->{'servicenotes'}{$service} ne $cur_notes ) {
			    # For now, we don't bother with an extra {'notes'} hash at the end of this chain of
			    # hashes, because currently a host service has only this one property.  If someday
			    # we extend a host service to have more than one property, we would create a hash at
			    # the end of the chain to have separate places to save the various property values.
			    $delta{'alter'}{'service'}{$host}{$service} = ($cur_notes eq '') ? ' ' : $cur_notes;
			}
			## Service exists, so delete it from the list of services to be deleted
			## (at this point, that's the $last hash entry)
			delete $last_host->{'service'}{$service};
		    }
		    else {
			## New Service
			$delta{'add'}{'service'}{$host}{$service} = 1;
			$delta{'add'}{'servicenotes'}{$host}{$service} = $current{'servicenotes'}{$host}{$service};
		    }
		}

		# All the services that are left in %last are now known
		# to not be in %current, and can be slated for deletion.
		foreach my $service ( keys %{ $last_host->{'service'} } ) {
		    $delta{'delete'}{'service'}{$host}{$service} = 1;
		}
	    }
	    else {
		## new host
		$delta{'add'}{'host'}{$host}{'alias'}   = $current{'host'}{$host}{'alias'};
		$delta{'add'}{'host'}{$host}{'address'} = $current{'host'}{$host}{'address'};
		$delta{'add'}{'host'}{$host}{'notes'}   = $current{'host'}{$host}{'notes'};
		$delta{'add'}{'host'}{$host}{'parents'} = $current{'host'}{$host}{'parents'};
		foreach my $service ( keys %{ $current{'service'}{$host} } ) {
		    $delta{'add'}{'service'}{$host}{$service} = 1;
		    $delta{'add'}{'servicenotes'}{$host}{$service} = $current{'servicenotes'}{$host}{$service};
		}
	    }
	    delete $last{'host'}{$host};
	}
	foreach my $host ( keys %{ $last{'host'} } ) {
	    $last_host = $last{'host'}{$host};
	    if ($last_host->{'apptype'} eq $apptype) {
		## This host is owned/managed by Monarch.

		# Count the services that will be cascade-deleted when this host is deleted.
		$cascade_deleted_services += scalar( keys %{ $last_host->{'service'} } );

		# Count the hostgroup members that will be cascade-deleted when this host is deleted.
		foreach my $hostgroup ( keys %{ $last{'hostgroup'} } ) {
		    if ( $last{'hostgroup'}{$hostgroup}{'members'}{$host} ) {
			++$cascade_deleted_hostgroup_members;
			delete $last{'hostgroup'}{$hostgroup}{'members'}{$host};
		    }
		}

		# Count the servicegroup members that will be cascade-deleted when this host is deleted.
		foreach my $servicegroup ( keys %{ $last{'servicegroup'} } ) {
		    if ( $last{'servicegroup'}{$servicegroup}{'host'}{$host} ) {
			$cascade_deleted_servicegroup_members += keys %{ $last{'servicegroup'}{$servicegroup}{'host'}{$host}{'service'} };
			delete $last{'servicegroup'}{$servicegroup}{'host'}{$host};
		    }
		}

		$delta{'delete'}{'host'}{$host} = 1;
	    }
	    else {
		## This host is not owned/managed by Monarch, so we cannot delete the host, so we cannot depend on cascade-deletion
		## to delete the associated Monarch objects, so we have to delete them all individually here.

		foreach my $service ( keys %{ $last_host->{'service'} } ) {
		    $delta{'delete'}{'service'}{$host}{$service} = 1;
		}

		# Drop this host from any current hostgroups it belongs to, so the later code will end up deleting it.
		foreach my $hostgroup ( keys %{ $last{'hostgroup'} } ) {
		    if ( $last{'hostgroup'}{$hostgroup}{'members'}{$host} and exists $current{'hostgroup'}{$hostgroup} ) {
			delete $current{'hostgroup'}{$hostgroup}{'members'}{$host};
		    }
		}

		# Drop this host from any current service groups it belongs to, so the later code will end up deleting it.
		foreach my $servicegroup ( keys %{ $last{'servicegroup'} } ) {
		    if ( $last{'servicegroup'}{$servicegroup}{'host'}{$host} and exists $current{'servicegroup'}{$servicegroup} ) {
			delete $current{'servicegroup'}{$servicegroup}{$host};
		    }
		}
	    }
	}
	StorProc->capture_timing( \@timings, \$phasetime, 'computing host and service deltas' );
    }

    unless (@errors) {
	## hostgroups
	## $current{'hostgroup'} might not already exist, but then it will safely auto-vivify here as a reference to an empty hash.
	my $cur_alias;
	my $cur_notes;
	foreach my $hostgroup ( keys %{ $current{'hostgroup'} } ) {
	    if ( $last{'hostgroup'}{$hostgroup} ) {
		my $members_changed = 0;
		foreach my $host ( keys %{ $last{'hostgroup'}{$hostgroup}{'members'} } ) {
		    unless ( $current{'hostgroup'}{$hostgroup}{'members'}{$host} ) {
			$members_changed = 1;
			last;
		    }
		}
		unless ($members_changed) {
		    foreach my $host ( keys %{ $current{'hostgroup'}{$hostgroup}{'members'} } ) {
			unless ( $last{'hostgroup'}{$hostgroup}{'members'}{$host} ) {
			    $members_changed = 1;
			    last;
			}
		    }
		}
		if ($members_changed) {
		    %{ $delta{'alter'}{'hostgroup'}{$hostgroup}{'members'} } = %{ $current{'hostgroup'}{$hostgroup}{'members'} };
		    $cleared_hostgroup_members += keys %{ $last{'hostgroup'}{$hostgroup}{'members'} };
		}
		$cur_alias = $current{'hostgroup'}{$hostgroup}{'alias'};
		if ( $last{'hostgroup'}{$hostgroup}{'alias'} ne $cur_alias ) {
		    $delta{'alter'}{'hostgroup'}{$hostgroup}{'alias'} = ($cur_alias eq '') ? ' ' : $cur_alias;
		}
		$cur_notes = $current{'hostgroup'}{$hostgroup}{'notes'};
		if ( $last{'hostgroup'}{$hostgroup}{'notes'} ne $cur_notes ) {
		    $delta{'alter'}{'hostgroup'}{$hostgroup}{'notes'} = ($cur_notes eq '') ? ' ' : $cur_notes;
		}
	    }
	    else {
		print STDERR "Adding new hostgroup: $hostgroup\n" if $debug_changes;
		%{ $delta{'add'}{'hostgroup'}{$hostgroup}{'members'} } = %{ $current{'hostgroup'}{$hostgroup}{'members'} };
		$delta{'add'}{'hostgroup'}{$hostgroup}{'alias'} = $current{'hostgroup'}{$hostgroup}{'alias'};
		$delta{'add'}{'hostgroup'}{$hostgroup}{'notes'} = $current{'hostgroup'}{$hostgroup}{'notes'};
	    }
	    delete $last{'hostgroup'}{$hostgroup};
	}
	foreach my $hostgroup ( keys %{ $last{'hostgroup'} } ) {
	    print STDERR "Deleting hostgroup: $hostgroup\n" if $debug_changes;

	    # Count the remaining hostgroup members not previously deleted,
	    # that will now be cascade-deleted when this hostgroup is deleted.
	    $cascade_deleted_hostgroup_members += keys %{ $last{'hostgroup'}{$hostgroup}{'members'} };

	    $delta{'delete'}{'hostgroup'}{$hostgroup} = 1;
	}
	StorProc->capture_timing( \@timings, \$phasetime, 'computing hostgroup deltas' );
    }

    unless (@errors) {
	## servicegroups
	## $current{'servicegroup'} might not already exist, but then it will safely auto-vivify here as a reference to an empty hash.
	my $cur_notes;
	foreach my $servicegroup ( keys %{ $current{'servicegroup'} } ) {
	    if ( $last{'servicegroup'}{$servicegroup} ) {
		## The service group exists in Foundation.  Determine membership and see if it needs to be updated.
		## First, look for deletions, to limit the impact of auto-vivification in %last when we look for additions.
		my $members_changed = 0;
		SVC_DEL: foreach my $host ( keys %{ $last{'servicegroup'}{$servicegroup}{'host'} } ) {
		    foreach my $member_service ( keys %{ $last{'servicegroup'}{$servicegroup}{'host'}{$host}{'service'} } ) {
			# Probe carefully, to avoid accidental auto-vivification.
			unless ( defined $current{'servicegroup'}{$servicegroup}
			      && defined $current{'servicegroup'}{$servicegroup}{$host}
			      && defined $current{'servicegroup'}{$servicegroup}{$host}{$member_service} ) {
			    $members_changed = 1;
			    last SVC_DEL;
			}
		    }
		}
		## Now, look for additions.
		unless ($members_changed) {
		    SVC_ADD: foreach my $host ( keys %{ $current{'servicegroup'}{$servicegroup} } ) {
			foreach my $member_service ( keys %{ $current{'servicegroup'}{$servicegroup}{$host} } ) {
			    # Probe carefully, to avoid accidental auto-vivification.
			    unless ( defined $last{'servicegroup'}{$servicegroup}{'host'}{$host}
				  && defined $last{'servicegroup'}{$servicegroup}{'host'}{$host}{'service'}{$member_service} ) {
				$members_changed = 1;
				last SVC_ADD;
			    }
			}
		    }
		}
		if ($members_changed) {
		    # We could have followed our hash-chain convention for other data structures, and used
		    # $current{'servicegroup'}{$servicegroup}{'members'} and
		    # $current{'servicegroup'}{$servicegroup}{'notes'} instead of
		    # $current{'servicegroup'}{$servicegroup} and
		    # $current{'servicegroupnotes'}{$servicegroup}.
		    # But that would have disturbed too much code above.  Plus, we would then perhaps want to set
		    # the $current{'servicegroup'}{$servicegroup} hash size explicitly (small, == 2) then, to avoid
		    # allocating a lot of space for a hash which is known to only need a few elements.
		    %{ $delta{'alter'}{'servicegroup'}{$servicegroup}{'members'} } = %{ $current{'servicegroup'}{$servicegroup} };
		    foreach my $host ( keys %{ $last{'servicegroup'}{$servicegroup}{'host'} } ) {
			$cleared_servicegroup_members += keys %{ $last{'servicegroup'}{$servicegroup}{'host'}{$host}{'service'} };
		    }
		}
		$cur_notes = $current{'servicegroupnotes'}{$servicegroup};
		if ( $last{'servicegroup'}{$servicegroup}{'notes'} ne $cur_notes ) {
		    $delta{'alter'}{'servicegroup'}{$servicegroup}{'notes'} = ($cur_notes eq '') ? ' ' : $cur_notes;
		}
	    }
	    else {
		print STDERR "Adding new servicegroup: $servicegroup\n" if $debug_changes;
		%{ $delta{'add'}{'servicegroup'}{$servicegroup}{'members'} } = %{ $current{'servicegroup'}{$servicegroup} };
		$delta{'add'}{'servicegroup'}{$servicegroup}{'notes'} = $current{'servicegroupnotes'}{$servicegroup};
	    }
	    delete $last{'servicegroup'}{$servicegroup};
	}
	foreach my $servicegroup ( keys %{ $last{'servicegroup'} } ) {
	    print STDERR "Deleting servicegroup: $servicegroup\n" if $debug_changes;

	    # Count the servicegroup members that will be cascade-deleted when this servicegroup is deleted.
	    foreach my $host ( keys %{ $last{'servicegroup'}{$servicegroup}{'host'} } ) {
		$cascade_deleted_servicegroup_members += keys %{ $last{'servicegroup'}{$servicegroup}{'host'}{$host}{'service'} };
	    }

	    $delta{'delete'}{'servicegroup'}{$servicegroup} = 1;
	}
	StorProc->capture_timing( \@timings, \$phasetime, 'computing servicegroup deltas' );
    }

    StorProc->dbdisconnect();

    $delta{'statistics'}{'cascade_deleted_services'}             = $cascade_deleted_services;
    $delta{'statistics'}{'cascade_deleted_hostgroup_members'}    = $cascade_deleted_hostgroup_members;
    $delta{'statistics'}{'cascade_deleted_servicegroup_members'} = $cascade_deleted_servicegroup_members;
    $delta{'statistics'}{'cleared_hostgroup_members'}            = $cleared_hostgroup_members;
    $delta{'statistics'}{'cleared_servicegroup_members'}         = $cleared_servicegroup_members;

    if ( $debug_dumps ) {
	print STDERR "delta hash dump:\n";
	my $dump = Data::Dumper->Dump( [ \%delta ], [qw(\%delta)] );
	$dump =~ s{^( +)}{':&nbsp;&nbsp;&nbsp;'x(length($1)/2)}mge if $indent_dumps_as_html;
	print STDERR $dump;
	StorProc->capture_timing( \@timings, \$phasetime, 'printing delta hash' );
    }

    # FIX MAJOR:  drop this after debugging is complete
    if (0) {
	print "delta hash dump: " . Data::Dumper->Dump( [ \%delta ], [qw(\%delta)] );
    }

    return \@errors, \@timings, %delta;
}

# Unstable interface, subject to change across releases.
# return a reference to a hash of all hosts, or an empty string
sub getSyncHosts {
    my $rest_api = shift;
    my @errors   = ();
    my %hosts    = ();
    my @timings  = ();
    my $phasetime;

    StorProc->start_timing( \$phasetime );

    my $callback = sub {
	StorProc->capture_timing( \@timings, \$phasetime, 'fetching Sync hosts from Foundation REST API' );
    };

    # Because we might have a Monarch-managed host with no associated services that is owned in Foundation by
    # some non-NAGIOS application type, we cannot accomplish all the filtering we might want to at this level.
    # We must instead return data for all hosts to the caller, and allow it to apply appropriate filtering.
    # Services, on the other hand, will always be owned in Foundation by the NAGIOS application type if they
    # are managed by Monarch, so we can apply that filtering here.

    my %outcome;
    my %results;

    # $sql = "select h.HostName, d.Identification, at.Name
    #     from ApplicationType at join Host h using (ApplicationTypeID) left join Device d using (DeviceID);";

    # my %OutsideName = ( Alias => 'Alias', Notes => 'HostNotes', Parent => 'Parents' );
    # foreach my $ptname (keys %OutsideName) {
    # 	    $sql = "select h.HostName, hsp.ValueString
    # 		    from PropertyType pt, HostStatusProperty hsp, Host h
    # 		    where	pt.Name = '$ptname'
    # 		    and		hsp.PropertyTypeID = pt.PropertyTypeID
    # 		    and		h.HostID = hsp.HostStatusID;";
    # 	    $hosts{ $values[0] }{ $OutsideName{$ptname} } = $values[1];
    # }

    # FIX MINOR:  "deep" depth is necessary to pull the particular detail we need here, but
    # it's also pulling perhaps 10 times as much as we need for this purpose.  We could use a
    # "depth => 'sync'" option to limit the retrieved data to exactly what we will use here.
    if ( not $rest_api->get_hosts( [], { depth => 'sync', callback => \&$callback }, \%outcome, \%results ) ) {
	## Possibly failed.  The REST API treats an empty result as a failure, so we need to rule that out.
	if ( $outcome{response_code} != 404 || $outcome{response_status} ne 'Not Found' || %results ) {
	    push @errors, "ERROR $outcome{response_code} ($outcome{response_status}) in getSyncHosts().";
	    StorProc->capture_timing( \@timings, \$phasetime, 'unmarshalling Sync hosts from Foundation REST API' );
	    return \@errors, \@timings, \%hosts;
	}
    }
    StorProc->capture_timing( \@timings, \$phasetime, 'unmarshalling Sync hosts from Foundation REST API' );

    my $result;
    my $properties;
    my $host;
    my $description;
    my $notes;
    foreach my $name ( keys %results ) {
	$result                  = $results{$name};
	$properties              = $result->{properties};
	$host                    = \%{ $hosts{$name} };
	$host->{Identification}  = $result->{deviceIdentification};
	$host->{ApplicationType} = $result->{appType};
	$host->{Alias}     = $properties->{Alias}  if defined $properties->{Alias};
	$host->{HostNotes} = $properties->{Notes}  if defined $properties->{Notes};
	$host->{Parents}   = $properties->{Parent} if defined $properties->{Parent};

	# Service names ...
	#
	# $sql = "select h.HostName, ss.ServiceDescription ...
	#     $sql = "select h.HostName, ss.ServiceDescription
	#	from ApplicationType at, ServiceStatus ss, Host h
	#	where	at.Name = 'NAGIOS'
	#	and	ss.ApplicationTypeID = at.ApplicationTypeID
	#	and	h.HostID = ss.HostID;";
	#
	# Service notes ...
	#
	#     $sql = "select h.HostName, ss.ServiceDescription, ssp.ValueString
	# 	from ApplicationType at, ServiceStatus ss, Host h, ServiceStatusProperty ssp, PropertyType pt
	# 	where	at.Name = 'NAGIOS'
	# 	and	ss.ApplicationTypeID = at.ApplicationTypeID
	# 	and	h.HostID = ss.HostID
	# 	and	ssp.ServiceStatusID = ss.ServiceStatusID
	# 	and	pt.PropertyTypeID = ssp.PropertyTypeID
	# 	and	pt.Name='Notes';";

	foreach my $service ( @{ $result->{services} } ) {
	    if ( $service->{appType} eq 'NAGIOS' ) {
		$description = $service->{description};
		$notes       = $service->{properties}{Notes};
		push @{ $host->{'Services'} }, $description;
		$host->{'ServiceNotes'}{$description} = $notes if defined $notes;
	    }
	}
    }

    StorProc->capture_timing( \@timings, \$phasetime, 'processing Sync hosts from Foundation REST API' );
    return \@errors, \@timings, \%hosts;
}

# return a reference to all hostgroup names, descriptions, and aliases
sub getHostGroupsByType {
    my $rest_api = shift;
    my $apptype  = shift;

    my @errors     = ();
    my %hostgroups = ();

    if (not defined $apptype) {
	push @errors, "ERROR getHostGroupsByType() was called with no application type.";
	return \@errors, \%hostgroups;
    }

    my %options = ( depth => 'simple' );
    if ($apptype) {
	## Sanitize $apptype before inclusion in a query.
	$apptype =~ tr/A-Za-z0-9//cd;
	$options{query} = "appType = '$apptype'";
    }

    my %outcome;
    my %results;

    # my $sql = "select
    #     hg.HostGroupID		as \"HostGroupID\",
    #     hg.Name			as \"Name\",
    #     hg.Description		as \"Description\",
    #     hg.ApplicationTypeID	as \"ApplicationTypeID\",
    #     hg.Alias		as \"Alias\"
    #     from	ApplicationType at join HostGroup hg using (ApplicationTypeID)
    #     where at.Name = $quoted_appType;";

    if ( not $rest_api->get_hostgroups( [], \%options, \%outcome, \%results ) ) {
	## Possibly failed.  The REST API treats an empty result as a failure, so we need to rule that out.
	if ( $outcome{response_code} != 404 || $outcome{response_status} ne 'Not Found' || %results ) {
	    push @errors, "ERROR $outcome{response_code} ($outcome{response_status}) in getHostGroupsByType($apptype).";
	    return \@errors, \%hostgroups;
	}
    }

    foreach my $name ( keys %results ) {
	$hostgroups{$name}{'Description'} = $results{$name}{description};
	$hostgroups{$name}{'Alias'}       = $results{$name}{alias};
    }

    return \@errors, \%hostgroups;
}

# return a reference to a hash of all host names for a designated host group
sub getHostsForHostGroup {
    my $rest_api  = shift;
    my $hostgroup = shift;

    my @errors = ();
    my %hosts  = ();

    if (not defined $hostgroup) {
	push @errors, "ERROR getHostsForHostGroup() was called with no hostgroup.";
	return \@errors, \%hosts;
    }

    my %options = ( depth => 'shallow' );

    my %outcome;
    my %results;

    # my $sql =
    #     "select
    #         h.HostName	as \"HostName\",
    #         h.Description	as \"HostDescription\",
    #         d.Identification	as \"DeviceIdentification\",
    #         d.Description	as \"DeviceDescription\"
    #     from
    #     HostGroup		as hg,
    #     HostGroupCollection	as hgc,
    #     Host			as h,
    #     Device			as d
    #     where	hg.Name = $quoted_hg
    #     and	hgc.HostGroupID = hg.HostGroupID
    #     and	h.HostID = hgc.HostID
    #     and	d.DeviceID = h.DeviceID
    #     ;
    #     ";

    if ( not $rest_api->get_hostgroups( [$hostgroup], \%options, \%outcome, \%results ) ) {
	## Possibly failed.  The REST API treats an empty result as a failure, so we need to rule that out.
	## Given the way in which the calling code found the specific $hostgroup with which to call
	## this routine, we should NEVER get a "Not Found" here, so in that sense it would really be
	## a true error if it did happen.  But all that would apparently mean is that the state of
	## Foundation changed while we glanced away.  If we treat that as an error here, then the
	## analysis will be aborted and we won't be able to use a Commit to heal the configuration.
	## So we just ignore a "Not Found" anyway.
	if ( $outcome{response_code} != 404 || $outcome{response_status} ne 'Not Found' || %results ) {
	    push @errors, "ERROR $outcome{response_code} ($outcome{response_status}) in getHostsForHostGroup($hostgroup).";
	    return \@errors, \%hosts;
	}
    }

    foreach my $hg ( keys %results ) {
	foreach my $host ( @{ $results{$hg}{hosts} } ) {
	    $hosts{ $host->{hostName} } = 1;
	}
    }

    return \@errors, \%hosts;
}

# return a reference to all servicegroup names and descriptions
sub getServiceGroups {
    my $rest_api = shift;

    my @errors        = ();
    my %servicegroups = ();

    my %outcome;
    my %results;

    # my $sql =
    #     "select c.Name as \"Service Group\", c.Description as \"Description\"
    #     from	Category c, EntityType et
    #     where	et.Name = 'SERVICE_GROUP'
    #     and	c.EntityTypeID = et.EntityTypeID
    #     ;";

    # FIX MINOR:  test the effect of depth limiting
    if ( not $rest_api->get_servicegroups( [], { depth => 'simple' }, \%outcome, \%results ) ) {
	## Possibly failed.  The REST API treats an empty result as a failure, so we need to rule that out.
	if ( $outcome{response_code} != 404 || $outcome{response_status} ne 'Not Found' || %results ) {
	    push @errors, "ERROR $outcome{response_code} ($outcome{response_status}) in getServiceGroups().";
	    return \@errors, \%servicegroups;
	}
    }

    foreach my $sgname ( keys %results ) {
	$servicegroups{$sgname}{'Service Group'} = $results{$sgname}{name};
	$servicegroups{$sgname}{'Description'}   = $results{$sgname}{description};
    }

    return \@errors, \%servicegroups;
}

# return a reference to a hash of all host/service names for a designated service group
sub getHostServicesForServiceGroup {
    my $rest_api     = shift;
    my $servicegroup = shift;

    my @errors        = ();
    my %host_services = ();

    if (not defined $servicegroup) {
	push @errors, "ERROR getHostServicesForServiceGroup() was called with no servicegroup.";
	return \@errors, \%host_services;
    }

    my %outcome;
    my %results;

    # my $sql =
    #     "select
    #         h.HostName		as \"HostName\",
    #         ss.ServiceDescription	as \"ServiceDescription\"
    #     from	Host h, ServiceStatus ss, CategoryEntity ce, Category c, EntityType et
    #     where	et.Name = 'SERVICE_GROUP'
    #     and	c.EntityTypeID = et.EntityTypeID
    #     and	c.Name = '$servicegroup'
    #     and	ce.CategoryID = c.CategoryID
    #     and	ss.ServiceStatusID = ce.ObjectID
    #     and	h.HostID = ss.HostID
    #     and	h.HostName = '$sghost'
    #     ;";

    # FIX MINOR:  test the effect of depth limiting
    if ( not $rest_api->get_servicegroups( [$servicegroup], { depth => 'simple' }, \%outcome, \%results ) ) {
	## Possibly failed.  The REST API treats an empty result as a failure, so we need to rule that out.
	## Given the way in which the calling code found the specific $servicegroup with which to call
	## this routine, we should NEVER get a "Not Found" here, so in that sense it would really be
	## a true error if it did happen.  But all that would apparently mean is that the state of
	## Foundation changed while we glanced away.  If we treat that as an error here, then the
	## analysis will be aborted and we won't be able to use a Commit to heal the configuration.
	## So we just ignore a "Not Found" anyway.
	if ( $outcome{response_code} != 404 || $outcome{response_status} ne 'Not Found' || %results ) {
	    push @errors, "ERROR $outcome{response_code} ($outcome{response_status}) in getHostServicesForServiceGroup($servicegroup).";
	    return \@errors, \%host_services;
	}
    }

    foreach my $sgname ( keys %results ) {
	if ( $results{$sgname}{services} ) {
	    foreach my $service ( @{ $results{$sgname}{services} } ) {
		$host_services{ $service->{hostName} }{ $service->{description} } = 1;
	    }
	}
    }

    return \@errors, \%host_services;
}

1;

