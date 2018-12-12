# MonArch - Groundwork Monitor Architect
# MonarchExternals.pm
#
############################################################################
# Release 4.6
# October 2017
############################################################################
#
# Original author: Scott Parris
#
# Copyright 2007-2017 GroundWork Open Source, Inc. (GroundWork)
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
use DBI;
use MonarchStorProc;

package Externals;

# The $default_location must be specified as an absolute pathname.
my $default_location = '/usr/local/groundwork/distribution';

# Creating secondary symlinks was an experimental feature, now deprecated (GWMON-10525).
my $make_symlinks = 0;

# Note:  The return signature of build_all_externals() is different from
# that of the similar build_externals() routine in previous releases.  The
# routine name has been intentionally changed to force a mismatch and make
# this difference immediately noticeable, in case you try to use an old
# copy of MonarchExternals.pm with the newer release of Monarch.

# Note:  The name of this routine is still subject to change before the 6.0 GA release.

sub build_all_externals(@) {
    my $user_acct  = $_[1];
    my $session_id = $_[2];
    my $via_web_ui = $_[3];
    my $force      = $_[4];
    my ($results, $errors) = build_some_externals('', $user_acct, $session_id, $via_web_ui, undef, $force);
    return $results, $errors;
}

sub build_some_externals(@) {
    my $user_acct  = $_[1];
    my $session_id = $_[2];
    my $via_web_ui = $_[3];
    my $hostsref   = $_[4];	# undef => all hosts; \@hosts => specific host(s) only
    my $force      = $_[5];     # true => regenerate each file even if it matches existing file
    local $_;

    my @results    = ();
    my @errors     = ();
    my %files      = ();
    my %host_id    = StorProc->get_hosts();
    my $host_count = keys %host_id;
    my $host_seq   = 0;
    my %host_seq   = map { $_ => ++$host_seq } keys %host_id;  # unsorted, but all we need is a forced spread

    my @hosts_to_process = defined($hostsref) ? @$hostsref : (keys %host_id);
    # Sorting the list of hosts is bad (pointless and wasteful) for performance,
    # good for getting any generated errors into human-processable order.
    @hosts_to_process = sort @hosts_to_process;

    use MonarchLocks;
    require IO::Handle;

    # FIX MINOR:  handle possible errors from this call
    my $host_vitals = StorProc->fetch_fields('hosts', 'name', 'address', 'alias');

    my ($group_macros, $host_ref, $locations, $errors) = gethostgroupinfo();
    push @errors, @$errors if @$errors;

    # Statistics to track and print:
    # * The total number of hosts.
    # * The total number of hosts processed.
    # * How many processed hosts have no externals.
    # * How many processed hosts have some externals.
    # * How many processed hosts with externals are in no Monarch groups. 
    # * How many processed hosts with externals are only in inactive Monarch groups. 
    # * How many processed hosts with externals are in exactly one active Monarch group.
    # * How many processed hosts with externals are in multiple active Monarch groups. 
    # * How many processed hosts with externals were having externals built by some other actor.
    # * How many externals files were deleted, left unchanged, or written to in each build directory.
    # * The total number of externals files left unchanged, across all directories processed.
    # * The total number of externals files written, across all directories written to.
    my $total_hosts                               = $host_count;
    my $total_hosts_processed                     = 0;
    my $hosts_without_externals                   = 0;
    my $hosts_with_externals                      = 0;
    my $externals_hosts_in_no_groups              = 0;
    my $externals_hosts_only_in_inactive_groups   = 0;
    my $externals_hosts_in_one_active_group       = 0;
    my $externals_hosts_in_multiple_active_groups = 0;
    my $externals_hosts_being_built_elsewhere     = 0;
    my $total_files_unchanged                     = 0;
    my $total_files_written                       = 0;

    my %resources = StorProc->get_resources();
    my $date_time = StorProc->datetime();

    # FIX MINOR:  revise this config-file pathname as needed before formal release
    # of the custom package API
    my $config_file = '/usr/local/groundwork/common/etc/MonarchExternals.conf';
    my $custom_package;
    my $initialize_custom_externals = 0;
    my $validate_custom_externals   = 0;
    my $terminate_custom_externals  = 0;

    unless (@errors) {
	if ( -f $config_file ) {
	    require TypedConfig;

	    sub allow {
		my $package = shift;
		# We're careful to use a form of the require that should provide some protection
		# against Perl-injection attacks through our configuration file, though of course
		# there is no possible protection against what is in the allowed package itself.
		return 0 if ! defined $package || ! $package;
		eval {require "$package.pm";};
		if ($@) {
		    # 'require' died; $package is not available.
		    return 0;
		} else {
		    # 'require' succeeded; $package was loaded.
		    return 1;
		}
	    }

	    ## We use secure_new() instead of just new() in case the config file ends up containing any sensitive data.
	    my $config;
	    eval {
		$config = TypedConfig->secure_new ($config_file);

		my $enable_processing = $config->get_boolean ('enable_processing');
		my $debug_level = $config->get_number ('debug_level');

		# Set to the name of an external package (not including the .pm filename extension) to
		# call to validate the data, or to an empty string if no such package should be used.
		my $custom_externals_package = $config->get_scalar ('custom_externals_package');

		if ($enable_processing) {
		    my $have_custom_externals_package = allow $custom_externals_package;
		    if ($custom_externals_package && ! $have_custom_externals_package) {
			push @errors, "Configured externals package \"$custom_externals_package\" cannot be found: $@";
		    }
		    if ($have_custom_externals_package) {
			$custom_package = $custom_externals_package->new();
			$custom_externals_package->debug($debug_level) if $custom_externals_package->can("debug");

			$initialize_custom_externals = $custom_package->can("initialize_custom_externals");
			$validate_custom_externals   = $custom_package->can("validate_custom_externals");
			$terminate_custom_externals  = $custom_package->can("terminate_custom_externals");
		    }
		}

		if ($initialize_custom_externals) {
		    my ($results, $errors) = $custom_package->initialize_custom_externals();
		    push @results, @$results if $results;
		    # FIX MAJOR:  change the API, or change the condition to "$errors && @$errors"
		    push @errors, @$errors if $errors;
		}
	    };
	    if ($@) {
		push @errors, $@;
	    }
	}
    }

    unless (@errors) {
	# These next two queries could be made even more efficient by using custom retrieval routines that
	# directly return the data in the hash arrays we want, rather than forcing us to shuffle it here.

	my %where = ();

	my %host_external_name = ();
	# This is a full mapping of externals.external_id to externals.name for all host externals (externals.type = 'host').
	# Inasmuch as there is no filtering by host/service type here, we will get service externals back in this query,
	# but we'll ignore them.  This only works because by current convention we have a shared namespace for host and
	# service externals, enforced by Monarch as it creates new externals.  Otherwise, we would need a
	# "where externals.type = 'host'" clause in this query, as shown below.
	%host_external_name = StorProc->get_table_objects( 'externals', '1' );
	# The alternative is presented below.
	# Another alternative would be to implement StorProc->fetch_list_hash(table, key_field, value_field, where),
	# which we might do over time if we see other needs for it.
	if (0) {
	    my %where = ( 'type' => 'host' );
	    %host_external_name = StorProc->fetch_list_hash_array( 'externals', \%where );
	    if ($host_external_name{'error'}) {
		push @errors, $host_external_name{'error'};
		%host_external_name = ();
	    }
	    else {
		foreach my $external_id (keys %host_external_name) {
		    $host_external_name{$external_id} = $host_external_name{$external_id}[1];
		}
	    }
	}

	my %host_externals_by_generic_key = StorProc->fetch_hash_array_generic_key( 'external_host', \%where );
	my %all_host_externals = ();
	foreach my $external_array ( values %host_externals_by_generic_key ) {
	    $all_host_externals{ $$external_array[1] }{ $host_external_name{ $$external_array[0] } } = $$external_array[2];
	}

	my %service_externals_by_generic_key = StorProc->fetch_hash_array_generic_key( 'external_service', \%where );
	my %all_service_externals = ();
	foreach my $external_array ( values %service_externals_by_generic_key ) {
	    push @{ $all_service_externals{ $$external_array[1] }{ $$external_array[2] } }, $$external_array[3];
	}

	my $service_host_map = StorProc->fetch_map( 'services', 'service_id', 'host_id' );
	my %service_ids_for_host_id = ();
	foreach my $service_id (keys %$service_host_map) {
	    push @{ $service_ids_for_host_id{ $service_host_map->{$service_id} } }, $service_id;
	}

	my $generic_services  = StorProc->get_generic_services_for_externals();
	my $host_services     = StorProc->get_host_services_for_externals();
	my $service_instances = StorProc->get_service_instances_for_externals();

	foreach my $host ( @hosts_to_process ) {
	    last if @errors;

	    ++$total_hosts_processed;

	    my $host_externals = $all_host_externals{ $host_id{$host} };

	    if ( !defined($host_externals) || !%$host_externals ) {
		++$hosts_without_externals;
		next;
	    }

	    if ( not defined $host_ref->{$host} ) {
		++$externals_hosts_in_no_groups;
		# We use an invalid Monarch group name so as to avoid collisions with actual groups.
		$host_ref->{$host}{'#LEGACY#'}{'location'} = $default_location;
		# We don't define $host_ref->{$host}{'#LEGACY#'}{'groups'} because there are no groups involved.
	    }
	    else {
		my $in_active_groups = keys %{ $host_ref->{$host} };
		if ($in_active_groups == 0) {
		    ++$externals_hosts_only_in_inactive_groups;
		    next;
		}
		elsif ($in_active_groups == 1) {
		    ++$externals_hosts_in_one_active_group;
		}
		else {
		    ++$externals_hosts_in_multiple_active_groups;
		}
	    }

	    my $body = '';
	    foreach my $host_external_name (keys %$host_externals) {
		$host_externals->{$host_external_name} =~ s/\r//g if defined $host_externals->{$host_external_name};
	    }

	    $body .= join( "\n", grep { defined } values %$host_externals );
	    $body .= "\n" if ($body ne '');

	    my @host_service_externals = ();
	    my %host_service_externals = ();

	    if ( defined $service_ids_for_host_id{ $host_id{$host} } ) {
		foreach my $service_id ( @{ $service_ids_for_host_id{ $host_id{$host} } } ) {
		    my $service_name                        = $generic_services->{ $host_services->{$service_id}[0] }[0];
		    my $generic_service_externals_arguments = $generic_services->{ $host_services->{$service_id}[0] }[1];
		    my $inherit_base_ext_args_from_generic  = $host_services->{$service_id}[1];
		    my $base_service_externals_arguments    = $host_services->{$service_id}[2];

		    # FIX LATER:  Possibly make more substitutions below in all the service-instance and service externals:
		    # (+) $SERVICEGROUPNAME$ (the name of an arbitrary one of possibly multiple service groups for this service)
		    # (+) $SERVICEGROUPNAMES$ (the full comma-separated list of names of service groups for this service)
		    # (+) $SERVICEACTIONURL$
		    # (+) Macros for Custom Object Variables for this service, when we support service-level COVs.

		    my @substituted_externals = ();
		    foreach my $external ( @{ $all_service_externals{ $host_id{$host} }{$service_id} } ) {
			next if not defined $external;    # precautionary
			$external =~ s/\r//g;
			$external =~ s/^\s+//;
			$external =~ s/\s+$//;
			if ( defined $service_instances->{$service_id} ) {
			    my $active_instance_number = 0;
			    ## Sort in a human-friendly order.  Kids, don't try this at home.
			    my $c;
			    my $d;
			    foreach my $instance_name ( map { $_->[0] }
				sort { $b->[1] cmp $a->[1] || ( $a->[1] ? ( $a->[2] <=> $b->[2] ) : ( $a->[3] cmp $b->[3] ) ) }
				map { [ $_, /^_?\d+$/ || 0, scalar( ( $c = $_ ) =~ s/^_//, $c ), lc scalar( ( $d = $_ ) =~ s/^_//, $d ) ] }
				keys %{ $service_instances->{$service_id} } )
			    {
				## Skip inactive instances.
				next if not $service_instances->{$service_id}{$instance_name}[0];
				++$active_instance_number;
				( my $short_name = $instance_name ) =~ s/^_//;
				my $instance_external = $external;
				$instance_external =~ s/\$BASESERVICEDESC\$/$service_name/g;
				$instance_external =~ s/\$SERVICEDESC\$/$service_name$instance_name/g;
				$instance_external =~ s/\$INSTANCE\$/$active_instance_number/g;
				$instance_external =~ s/\$INSTANCESUFFIX\$/$short_name/g;
				push @substituted_externals,
				  substitute_ext_args( $instance_external,
				    !$service_instances->{$service_id}{$instance_name}[1] ? $service_instances->{$service_id}{$instance_name}[2]
				    : !$inherit_base_ext_args_from_generic                ? $base_service_externals_arguments
				    :                                                       $generic_service_externals_arguments );
			    }
			}
			else {
			    $external =~ s/\$BASESERVICEDESC\$/$service_name/g;
			    $external =~ s/\$SERVICEDESC\$/$service_name/g;
			    $external =~ s/\$INSTANCE\$/1/g;
			    $external =~ s/\$INSTANCESUFFIX\$//g;
			    push @substituted_externals,
			      substitute_ext_args( $external,
				 !$inherit_base_ext_args_from_generic
				? $base_service_externals_arguments
				: $generic_service_externals_arguments );
			}
		    }

		    push @host_service_externals, @substituted_externals;
		    @{ $host_service_externals{$service_id} } = @substituted_externals;
		}
	    }

	    # Sort by external text, in a human-friendly order.
	    my $c;
	    my $d;
	    $body .= join( "\n\n",
		map { $_->[0] }
		  sort { $a->[1] cmp $b->[1] || $a->[2] <=> $b->[2] }
		  map { [ $_, scalar( ($c) = /^\s*([^[]*)/, $c ), scalar( ($d) = /(\d+)/, $d || 0 ) ] } @host_service_externals )
	      . "\n"
	      if @host_service_externals;

	    if ($validate_custom_externals) {
		eval {
		    my ($results, $errors) = $custom_package->validate_custom_externals(
			$session_id, $via_web_ui, $host, $host_id{$host}, $host_externals, \%host_service_externals
		    );
		    push @results, @$results if $results;
		    # FIX MAJOR:  change the API, or change the condition to "$errors && @$errors"
		    push @errors, @$errors if $errors;
		};
		if ($@) {
		    push @errors, $@;
		}
	    }

	    if ($body) {
		++$hosts_with_externals;

		if ( ! @errors ) {

		    # The NumHostsInInstallation and HostSequenceNumber lines support creating a roughly even load
		    # across the overall system-wide data collection cycle.  Each GDMA client installation can use
		    # its sequence number and the size of the installation to determine the proper time phase for
		    # sending its data within the system-wide data collection cycle.  The HostSequenceNumber value
		    # is set above for each host irrespective of which hosts we are generating externals for in
		    # this pass, to maintain the proper time spread.

		    my $head = qq(##########GROUNDWORK#############################################################################################
#GW
#GW\tgwmon_$host.cfg generated $date_time by $user_acct from MonarchExternals.pm
#GW
##########GROUNDWORK#############################################################################################

NumHostsInInstallation="$host_count"
HostSequenceNumber="$host_seq{$host}"

);

		    # Nagios resource macro substitutions.  Resource macros in an externals body are substituted
		    # first and are therefore allowed to reference group macros, but not the other way around.
		    # The other ordering might be more useful, but we're following historical tradition here.
		    foreach my $res ( keys %resources ) {
			$body =~ s/\$$res\$/$resources{$res}/ig;
		    }

		    foreach my $groupname ( keys %{ $host_ref->{$host} } ) {
			my $group_body = $body;

			# Monarch group macro substitutions, in order, sub-groups to parent groups up the chain of ancestry
			if ( defined $host_ref->{$host}{$groupname}{'groups'} ) {
			    foreach my $gid ( @{ $host_ref->{$host}{$groupname}{'groups'} } ) {
				my $g_macros = $group_macros->{$gid};
				foreach my $mgmacro ( keys %$g_macros ) {
				    $group_body =~ s/\$$mgmacro\$/$g_macros->{$mgmacro}{'value'}/ig;
				}
			    }
			}

			# FIX LATER:  These substitutions should really be outside of this loop,
			# unless we have documented the substitution order to be as it is.
			#
			# Substitute $HOSTNAME$, $HOSTADDRESS$ and $HOSTALIAS$
			my $address = $host_vitals->{$host}{'address'};
			my $alias   = $host_vitals->{$host}{'alias'};
			$address = '' if not defined $address;
			$alias   = '' if not defined $alias;
			$group_body =~ s/\$HOSTNAME\$/$host/ig;
			$group_body =~ s/\$HOSTADDRESS\$/$address/ig;
			$group_body =~ s/\$HOSTALIAS\$/$alias/ig;

			# FIX LATER:  Also substitute macros for Custom Object Variables for this host (outside of this loop).

			my $dir  = $host_ref->{$host}{$groupname}{'location'};
			my $base = "gwmon_$host.cfg";
			my $file = "$dir/$base";
			my $link = $make_symlinks ? "$dir/gwref_$host_id{$host}.cfg" : "/tmp/dummy_symlink.cfg";
			my $ptr  = undef if $make_symlinks;
			$locations->{$dir}{$host} = 1;

			# Searching for and reading the old file has a performance implication, but normally
			# externals don't change much, and if the old and new files match, we should be able
			# to avoid an even greater amount of i/o.  So the tradeoff seems sound.
			my $same_body = 0;
			if (!$force) {
			    my $oldcontent = '';
			    if (open (my $handle, '<:raw:perlio', $file)) {
				local $/;  # slurp mode
				$oldcontent = <$handle>;
				close $handle;
			    }
			    ## Since the $head changes every time we generate externals (it contains a new
			    ## timestamp, at a minimum), we must only compare the useful body information.
			    (my $old_group_body = $oldcontent) =~ s/.*HostSequenceNumber="\d+"\n\n//s;
			    $same_body = ($group_body eq $old_group_body);
			}

			if ($same_body) {
			    ++$files{$dir}{unchanged};
			    ++$total_files_unchanged;
			}
			else {
			    # GWMON-8827:  atomic file creation
			    my $tempfile = "$file.new";

			    # Compare the construction here to File::Temp.
			    #
			    # The process here protects against collisions from multiple independent
			    # actors (e.g., concurrent access through the UI and through dassmonarch).

			    my $externals_lock;

			    # Note:  In an expression like "(not ((\*externals_lock)->truncate(0)))", all the parentheses
			    # shown are required to obtain the intended operator precedence.  (The unexpected tricky part
			    # is that the open-parenthesis after "not" makes it look like an operator argument, which
			    # makes not(expr) a term, which would have higher precedence than "->" in the expression
			    # "(not (\*externals_lock) -> truncate(0))".)

			    my $errors = Locks->open_and_lock( \*externals_lock, $tempfile, $Locks::EXCLUSIVE, $Locks::NON_BLOCKING );
			    if (@$errors) {
				if (defined fileno \*externals_lock) {
				    # We were able to open the file, but not obtain the lock.
				    # So some other actor must be dealing with this file already.
				    ++$externals_hosts_being_built_elsewhere;
				    Locks->close_and_unlock( \*externals_lock );
				}
				else {
				    # We couldn't even open the file.
				    push @errors, @$errors;
				}
			    }
			    elsif ( @{ Locks->lock_file_exists( \*externals_lock, $tempfile ) } ) {
				# We got the lock, but too late -- somebody else locked and then
				# destroyed the file after we opened it and before we got the lock.
				++$externals_hosts_being_built_elsewhere;
				Locks->close_and_unlock( \*externals_lock );
			    }
			    elsif (! -f \*externals_lock || ! -O _) {
				push @errors, "Error: $tempfile is not a regular file owned by " . (scalar getpwuid($<)) . '.';
				Locks->close_and_unlock( \*externals_lock );
			    }
			    elsif (not ((\*externals_lock)->truncate(0))) {
				push @errors, "Error: Cannot truncate $tempfile ($!).";
				Locks->unlink_and_close( \*externals_lock, $tempfile );
			    }
			    elsif (not ((\*externals_lock)->print( $head . $group_body ))) {
				push @errors, "Error: Cannot write to $tempfile ($!).";
				Locks->unlink_and_close( \*externals_lock, $tempfile );
			    }
			    elsif (not ((\*externals_lock)->flush())) {
				push @errors, "Error: Cannot flush $tempfile ($!).";
				Locks->unlink_and_close( \*externals_lock, $tempfile );
			    }
			    elsif (not ((\*externals_lock)->sync())) {
				push @errors, "Error: Cannot sync $tempfile ($!).";
				Locks->unlink_and_close( \*externals_lock, $tempfile );
			    }
			    elsif ( (\*externals_lock)->error() ) {
				push @errors, "Error: Found i/o error on $tempfile ($!).";
				Locks->unlink_and_close( \*externals_lock, $tempfile );
			    }
			    ## Need to test first to see if it's a link, and only then for existence,
			    ## because -e $link will indirect through a link and test the existence
			    ## of the linked-to file instead of the existence of the link.
			    elsif ( $make_symlinks and !-l $link and -e $link and not unlink $link ) {
				push @errors, "Error: Cannot unlink $link ($!).";
				Locks->unlink_and_close( \*externals_lock, $tempfile );
			    }
			    elsif ( $make_symlinks and ( -l $link or -e $link ) and not defined( $ptr = readlink $link ) ) {
				push @errors, "Error: Cannot read symlink $link ($!).";
				## Attempt to unlink the symlink (to clean up for a future pass),
				## and fail anyway, as we have found a significant system failure.
				unlink $link;
				Locks->unlink_and_close( \*externals_lock, $tempfile );
			    }
			    elsif ( $make_symlinks and defined($ptr) and $ptr ne $base and not unlink $link ) {
				push @errors, "Error: Cannot unlink $link ($!).";
				Locks->unlink_and_close( \*externals_lock, $tempfile );
			    }
			    elsif ( not rename( $tempfile, $file ) ) {
				push @errors, "Error: Unable to rename $tempfile ($!).";
				Locks->unlink_and_close( \*externals_lock, $tempfile );
			    }
			    elsif ( $make_symlinks and !-l $link and not symlink( $base, $link ) ) {
				push @errors, "Error: Unable to make symlink $link ($!).";
				Locks->unlink_and_close( \*externals_lock, $tempfile );
			    }
			    else {
				++$files{$dir}{written};
				++$total_files_written;
				Locks->close_and_unlock( \*externals_lock );
			    }
			}
		    }
		}
	    }
	    else {
		++$hosts_without_externals;
	    }
	}

	if ($terminate_custom_externals) {
	    eval {
		my ($results, $errors) = $custom_package->terminate_custom_externals();
		push @results, @$results if $results;
		# FIX MAJOR:  change the API, or change the condition to "$errors && @$errors"
		push @errors, @$errors if $errors;
	    };
	    if ($@) {
		push @errors, $@;
	    }
	}
    }

    # The presence of errors above may have aborted processing without dealing with many hosts,
    # so we only remove orphaned files here if we completed the processing above without errors.
    # Otherwise, we would probably delete many files that simply didn't get dealt with because
    # of an unrelated preceding error.
    my $path = undef;
    unless (@errors || defined $hostsref) {
	# GWMON-8827:  This won't delete files in locations that no longer appear in any Monarch
	# groups, so it's only a partial solution to the deletion problem, but it does address
	# the most common issue, where individual hosts disappear from a Monarch group.
	foreach my $location (keys %$locations) {
	    # FIX LATER:  Use realpath() for $location, and verify that it is not a symlink,
	    # so as to avoid any possible security hole.  (Our filename pattern matching
	    # already provides the basic protection we need, though.)
	    if (not opendir (LOCATION, $location)) {
		# If no directory, there is nothing to clean up and nothing to complain about.
		if ("$!" ne 'No such file or directory') {
		    push @errors, "Error: Unable to open directory \"$location\" for cleanup ($!).";
		}
	    }
	    else {
		foreach my $file ( readdir LOCATION ) {
		    $path = "$location/$file";
		    if ( $file =~ /^gwmon_([A-Za-z0-9_](?:[-.A-Za-z0-9_]*[A-Za-z0-9_])?)\.cfg(?:\.new)?$/ ) {
			## We don't delete .new files for currently supported hosts any more than we would
			## delete the gwmon_$host.cfg files, for fear of deleting a file which might now
			## be in use by concurrent building of externals files by some other actor.
			if ( not $locations->{$location}{$1} ) {
			    if ( not unlink $path ) {
				push @errors, "Error: Unable to unlink \"$path\" ($!).";
			    }
			    elsif ( $file !~ /\.new$/ ) {
				## We only count deletions of fully-deployed externals files.
				++$files{$location}{deleted};
			    }
			}
		    }
		    elsif ( $make_symlinks and $file =~ /^gwref_\d+\.cfg$/ ) {
			## Delete orphaned symlinks, and other files masquerading as symlinks.
			## Here, the indirection of the -e test on a link comes in handy.
			## We could have tried to do a $host_id -> $host lookup to see if the
			## base file is one that we just generated, but this testing is simpler.
			if ( ( -l $path and !-e $path ) or ( !-l $path and -e $path ) ) {
			    if ( not unlink $path ) {
				push @errors, "Error: Unable to unlink \"$path\" ($!).";
			    }
			    ## For now, we don't bother to count deleted symlinks.
			}
		    }
		}
		closedir LOCATION;
	    }
	}
    }

    my $hosts = ($total_hosts == 1) ? 'host' : 'hosts';
    my $hosts_were = ($total_hosts_processed == 1) ? 'was' : 'were';
    push @results, "Of $total_hosts total $hosts to examine, $total_hosts_processed $hosts_were processed" .
      ($total_hosts_processed != @hosts_to_process ? ' (processing was cut short by errors).' : '.');
    my $are = ($externals_hosts_only_in_inactive_groups == 1) ? 'is' : 'are';
    push @results, "Of the processed hosts, $externals_hosts_only_in_inactive_groups $are only in inactive Monarch groups (and will be ignored).";
    my $have = ($hosts_without_externals == 1) ? 'has' : 'have';
    push @results, "Of the processed hosts, $hosts_without_externals $have only empty or no externals (and will be ignored).";
    $have = ($hosts_with_externals == 1) ? 'has' : 'have';
    push @results, "Of the processed hosts, $hosts_with_externals $have non-empty externals.";
    $are = ($externals_hosts_in_no_groups == 1) ? 'is' : 'are';
    push @results, "Of the processed hosts with non-empty externals, $externals_hosts_in_no_groups $are in no Monarch groups.";
    $are = ($externals_hosts_in_one_active_group == 1) ? 'is' : 'are';
    push @results, "Of the processed hosts with non-empty externals, $externals_hosts_in_one_active_group $are in exactly one active Monarch group.";
    $are = ($externals_hosts_in_multiple_active_groups == 1) ? 'is' : 'are';
    push @results, "Of the processed hosts with non-empty externals, $externals_hosts_in_multiple_active_groups $are in multiple active Monarch groups.";
    my $were = ($externals_hosts_being_built_elsewhere == 1) ? 'was' : 'were';
    push @results, "Of the processed hosts with non-empty externals, $externals_hosts_being_built_elsewhere $were having externals built by some other actor.";
    foreach my $dir ( sort keys %files ) {
	my $deleted   = $files{$dir}{deleted}   || 0;
	my $unchanged = $files{$dir}{unchanged} || 0;
	my $written   = $files{$dir}{written}   || 0;
	my $d_files_were = ( $deleted   == 1 ) ? 'file was' : 'files were';
	my $u_files_were = ( $unchanged == 1 ) ? 'file was' : 'files were';
	my $w_files_were = ( $written   == 1 ) ? 'file was' : 'files were';
	push @results,
	  "In the $dir directory, $deleted $d_files_were deleted, $unchanged $u_files_were left unchanged, $written $w_files_were written.";
    }
    my $u_files_were = ( $total_files_unchanged == 1 ) ? 'file was' : 'files were';
    my $w_files_were = ( $total_files_written   == 1 ) ? 'file was' : 'files were';
    push @results, "$total_files_unchanged total externals $u_files_were left unchanged across all directories.";
    push @results, "$total_files_written total externals $w_files_were written across all directories.";

    unshift @results, 'Externals module executed' . (scalar(@errors) ? ', with errors,' : ',') . ' at ' . (scalar localtime) . '.';

    # If an explicit list of hosts was passed in, the caller probably expected all of them to have externals.
    # So complain if not, if we haven't already complained about other stuff.
    if ( !@errors && defined($hostsref) && $hosts_without_externals ) {
	push @errors, "Error:  " .(@$hostsref == 1 ? "Host \"$hostsref->[0]\" has" : "Some hosts have"). " no externals.";
    }

    return \@results, \@errors;
}

sub substitute_ext_args {
    my $externals = shift;
    my $externals_arguments = shift // '';
    $externals_arguments =~ s/^!//;
    ## $ARG#$ macros are numbered starting with 1.
    ## We provide no possible escape sequence for the arg delimiters.
    my @args = ( '', split( /!/, $externals_arguments ) );
    my @pieces = split( /\$ARG(\d+)\$/, $externals );
    foreach ( my $i = 1 ; $i < @pieces ; $i += 2 ) {
	$pieces[$i] = $args[ $pieces[$i] ] // '';
    }
    return join( '', @pieces );
}

sub gethostgroupinfo {
    my %group_name     = ();
    my %group_macros   = ();
    my %host_ref       = ();
    my %locations      = ();
    my %is_ancestor_of = ();
    my @errors         = ();

    # For simplicity, we always ensure the default location exists.
    foreach my $location ( $default_location ) {
	if ($location =~ m{^/}) {
	    if ( stat($location) ) {
		# Scan this existing directory in later cleanup even if no hosts end up assigned to it in this run.
		$locations{$location} = {};
	    }
	    elsif ( !mkdir($location, 0755) ) {
		push @errors, "Error: Unable to create default build folder \"$location\" ($!).";
		last;
	    }
	}
	else {
	    push @errors, "Error: Found a non-absolute path \"$location\" for the default build folder.";
	    last;
	}
    }
    if (@errors) {
	return \%group_macros, \%host_ref, \%locations, \@errors;
    }

    my ( $dbtype, $dbhost, $database, $user, $passwd ) = undef;
    open( FILE, '<', '/usr/local/groundwork/config/db.properties' );
    while ( my $line = <FILE> ) {
	if ( $line =~ /^\s*global\.db\.type\s*=\s*(\S+)/ )  { $dbtype   = $1 }
	if ( $line =~ /^\s*monarch\.dbhost\s*=\s*(\S+)/ )   { $dbhost   = $1 }
	if ( $line =~ /^\s*monarch\.database\s*=\s*(\S+)/ ) { $database = $1 }
	if ( $line =~ /^\s*monarch\.username\s*=\s*(\S+)/ ) { $user     = $1 }
	if ( $line =~ /^\s*monarch\.password\s*=\s*(\S+)/ ) { $passwd   = $1 }
    }
    close(FILE);

    my $dsn = '';
    if ( defined($dbtype) && $dbtype eq 'postgresql' ) {
	$dsn = "DBI:Pg:dbname=$database;host=$dbhost";
    }
    else {
	$dsn = "DBI:mysql:database=$database;host=$dbhost";
    }
    my $dbh = undef;
    eval {
	$dbh = DBI->connect( $dsn, $user, $passwd, { 'AutoCommit' => 1, 'RaiseError' => 1, 'PrintError' => 0 } );
    };
    if ($@) {
	chomp $@;
	push @errors, "Error: $@";
	return \%group_macros, \%host_ref, \%locations, \@errors;
    }

    my $sqlstmt = 'select * from monarch_groups';
    my $sth     = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	my $gid       = $values[0];
	my $groupname = $values[1];
	my $location  = $values[3];
	my $inactive  = $values[4];  # "status" field:  NULL => active, 1 => totally inactive; 3 => "inactive" but sync with Foundation anyway
	my $data      = $values[5];
	if ( $data !~ /.*prop name=\"nagios_etc\"\>\<\!\[CDATA\[\].*/ ) { next; }
	$location = $default_location if not defined $location;
	if ($location =~ m{^/}) {
	    if ( stat($location) ) {
		# Scan this existing directory in later cleanup even if no hosts end up assigned to it in this run.
		$locations{$location} = {};
	    }
	    elsif ( !$inactive && !mkdir($location, 0755) ) {
		push @errors, "Error: Unable to create build folder \"$location\" for Monarch group \"$groupname\" ($!).";
		last;
	    }
	}
	elsif (not $inactive) {
	    push @errors, "Error: Found a non-absolute path \"$location\" for the Monarch group \"$groupname\" build folder.";
	    $location = undef;
	    last;
	}
	my $stmt = "select host_id, name from hosts where host_id in (select host_id from monarch_group_host where group_id = '$gid') order by name";
	my $sth2 = $dbh->prepare($stmt);
	$sth2->execute;
	while ( my @vals = $sth2->fetchrow_array() ) {
	    if ($inactive) {
		# Auto-vivify $host_ref{ $vals[1] } as an empty hashref if it doesn't already exist.
		delete $host_ref{ $vals[1] }{$groupname};
	    }
	    else {
		$host_ref{ $vals[1] }{$groupname}{'location'} = $location;
		$host_ref{ $vals[1] }{$groupname}{'gid'}      = $gid;  # for monarch group macro substitutions in externals
	    }
	}
	$sth2->finish;
	$stmt = "select hostgroup_id from monarch_group_hostgroup where group_id = '$gid'";
	$sth2 = $dbh->prepare($stmt);
	$sth2->execute;
	while ( my @vals = $sth2->fetchrow_array() ) {
	    $stmt = "select host_id, name from hosts where host_id in (select host_id from hostgroup_host where hostgroup_id = '$vals[0]')";
	    my $sth3 = $dbh->prepare($stmt);
	    $sth3->execute;
	    while ( my @host_vals = $sth3->fetchrow_array() ) {
		if ($inactive) {
		    # Auto-vivify $host_ref{ $host_vals[1] } as an empty hashref if it doesn't already exist.
		    delete $host_ref{ $host_vals[1] }{$groupname};
		}
		else {
		    $host_ref{ $host_vals[1] }{$groupname}{'location'} = $location;
		    $host_ref{ $host_vals[1] }{$groupname}{'gid'}      = $gid;  # for monarch group macro substitutions in externals
		}
	    }
	    $sth3->finish;
	}
	$sth2->finish;
	%{ $group_macros{$gid} } = StorProc->get_group_macros($gid);
	$group_name{$gid} = $groupname;
    }
    $sth->finish;

    unless (@errors) {
	## FIX MINOR:  Similar text should migrate to the Bookshelf, and this text should be dropped.
	#
	# Protect against a host belonging to more than one Monarch group that is configured with
	# the same build folder, outside of a chain of sub-groups.  Also correctly handle sub-groups
	# and beyond, which might validly share the same build folder with the parent group (and
	# siblings, though any given host must only be in at most one such sibling group).
	#
	# Resolve all potential conflicts here, before we attempt to generate any files.  Such
	# conflicts will be resolved partly by taking into account the Monarch-group subgroup
	# relationships.  We will depend on upstream configuration to prevent any circularity in
	# group ancestry.  However, note that while the upstream setup will disallow circular
	# ancestry, it will allow a child to have more than one parent.
	#
	# (*) If a Monarch group containing a given host has multiple parent groups, that will be
	#     considered to be an invalid configuration for this host/Monarch-sub-group combination,
	#     and the externals file for that sub-group will be skipped.  In this implementation,
	#     a hard error will result, which will abort further externals processing for all hosts.
	#     In a future version, we might relax this to just skip this one file, and generate a
	#     warning instead.
	# (*) If some Monarch groups in a parentage chain are inactive, then they will be ignored
	#     from the standpoint of generating files for such inactive groups, but the descendancy
	#     relationships will remain for any active groups in the chain.  Essentially, the chain
	#     will simply be shortened.  Group macros from the inactive groups will be ignored;
	#     only substitutions from active groups will be done.
	# (*) If two active Monarch groups that both contain the same host share the same build
	#     folder, those groups must have a strict parentage relationship (one must be a
	#     descendant of the other).  In this case, we will just drop the ancestor group from
	#     the groups for that host.  If instead the groups are siblings, cousins, any other
	#     relation, or unrelated, the setup will be considered broken and an error will be
	#     recognized.  With these rules and actions, we don't need to process the groups for
	#     a given host in any particular order.  And only one such file for a host in a given
	#     directory will be counted in the run-time statistics as having been written.
	# (*) We do need to keep track of all active-group parentage relationships even when an
	#     ancestor group is dropped from the list of groups for a given host.  That's because
	#     the ancestor's group macros will still be used during substitution.  So we must
	#     clearly distinguish the case of ignoring an active ancestor from that of an inactive
	#     ancestor and from an active ancestor group that did not contain this host.  Thus for
	#     each group containing a host, we must construct and save the sequence of the active
	#     ancestor groups that also contained this host.  Then when we generate the file, we
	#     must substitute macros from all of those active groups in child-to-parent order, so
	#     the child-group values are used in preference to the parent-group values (though a
	#     reference can be made in a child-group macro to the same macro name or a different
	#     macro name in the parent group's macros [note:  this depends on the order of macro
	#     substitution, which is not guaranteed at this time], and the parent-group macro
	#     value will then be used).
	#
	# The upshot should be that we don't need to process the active Monarch groups containing
	# a given host in any specific order, as all the remaining active groups for a given host
	# will target different directories.

	$sqlstmt = 'select group_id, child_id from monarch_group_child';
	$sth     = $dbh->prepare($sqlstmt);
	$sth->execute;
	my $parent_id      = undef;
	my $child_id       = undef;
	my %is_parent_of   = ();
	my %is_child_of    = ();
	while ( my @values = $sth->fetchrow_array() ) {
	    $parent_id = $values[0];
	    $child_id  = $values[1];
	    $is_parent_of{$parent_id}{$child_id} = 1;
	    $is_child_of{$child_id}{$parent_id} = 1;
	}
	$sth->finish;

	# Compute the nth power of the adjacency matrix of the parentage graph, where matrix^^(n) == matrix^^(n+1)
	# [that is, find all ancestor relationships, whether direct or indirect].  These ancestor relationships hold
	# whether or not the particular groups are active.
	while (%is_child_of) {
	    my $deleted_child = 0;
	    foreach $child_id (keys %is_child_of) {
		if (not exists $is_parent_of{$child_id}) {
		    foreach my $parent_id (keys %{ $is_child_of{$child_id} }) {
			$is_ancestor_of{$parent_id}{$child_id} = 1;
			if (exists $is_ancestor_of{$child_id}) {
			    foreach my $descendant_id (keys %{ $is_ancestor_of{$child_id} }) {
				$is_ancestor_of{$parent_id}{$descendant_id} = 1;
			    }
			}
			delete $is_parent_of{$parent_id}{$child_id};
			delete $is_parent_of{$parent_id} if !defined( $is_parent_of{$parent_id} ) || !%{ $is_parent_of{$parent_id} };
		    }
		    delete $is_child_of{$child_id};
		    $deleted_child = 1;
		}
	    }
	    if (not $deleted_child) {
		my $child_gid   = each %is_child_of;
		my $child_group = $group_name{$child_gid};
		push @errors,
		  "Error: Found circular Monarch group/sub-group ancestry, starting with group \"$child_group\"."
		  . " This configuration cannot be used.";
		last;
	    }
	}
    }

    unless (@errors) {
	# Make sure each externals file in a build directory refers to an unambiguous set of group macro substitutions,
	# and collapse redundant file definitions (retaining references to active ancestor groups, for their group macros).
	HOST: foreach my $host ( keys %host_ref ) {
	    my %group_by_location = ();
	    my $href = $host_ref{$host};
	    foreach my $groupname (keys %$href) {
		my $gid      = $href->{$groupname}{'gid'};
		my $location = $href->{$groupname}{'location'};
		my $othergroupname = $group_by_location{$location};
		if (defined $othergroupname) {
		    my $othergid = $href->{$othergroupname}{'gid'};
		    if ($is_ancestor_of{$othergid}{$gid}) {
			$href->{$groupname}{'groups'} = $href->{$othergroupname}{'groups'};
			unshift @{ $href->{$groupname}{'groups'} }, $gid;
			delete $href->{$othergroupname};
			$group_by_location{$location} = $groupname;
		    }
		    elsif ($is_ancestor_of{$gid}{$othergid}) {
			my $inserted = 0;
			my $groups_ref = $href->{$othergroupname}{'groups'};
			# $groups_ref->[0] == $othergid, so there's no point in testing that
			for (my $i = 1; $i < @$groups_ref; ++$i) {
			    if ($is_ancestor_of{ $groups_ref->[$i] }{$gid}) {
				splice @$groups_ref, $i, 0, $gid;
				$inserted = 1;
				last;
			    }
			    elsif (not $is_ancestor_of{$gid}{ $groups_ref->[$i] }) {
				push @errors,
				  "Error: Host $host is in active Monarch group \"$othergroupname\" which has active sub-group ancestor"
				  . " groups \"$groupname\" and \"$group_name{$groups_ref->[$i]}\" also containing this host, which"
				  . " share the same build folder ($location) but which are not themselves related by ancestry."
				  . " This makes it impossible to decide how to substitute group macros.";
				last HOST;
			    }
			}
			if (!$inserted) {
			    push @$groups_ref, $gid;
			}
			delete $href->{$groupname};
		    }
		    else {
			push @errors,
			  "Error: Host $host is contained in active Monarch groups \"$groupname\" and \"$othergroupname\" which"
			  . " share the same build folder ($location) but which are not in a parent-group/sub-group chain."
			  . " This makes it impossible to decide how to substitute group macros.";
			last HOST;
		    }
		}
		else {
		    # {'groups'} will be maintained as a reference to an ordered array of all active groups that contain
		    # this host, starting with the $groupname's gid and working up the non-branching chain of ancestry.
		    $href->{$groupname}{'groups'} = [ $gid ];
		    $group_by_location{$location} = $groupname;
		}
	    }
	}
    }

    $dbh->disconnect() if $dbh;
    return \%group_macros, \%host_ref, \%locations, \@errors;
}

1;

