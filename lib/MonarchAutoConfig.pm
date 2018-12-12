# MonArch - Groundwork Monitor Architect
# MonarchAutoConfig.pm
#
############################################################################
# Release 4.5
# September 2016
############################################################################
#
# Original author: Scott Parris
#
# Copyright 2007-2016 GroundWork Open Source, Inc. (GroundWork)
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
use MonarchStorProc;
use MonarchFile;
use MonarchInstrument;

package AutoConfig;

my $SERVER_SOFTWARE = $ENV{SERVER_SOFTWARE};

my $monarch_cgi;
my $monarch_css;
my $monarch_js;
if (defined($SERVER_SOFTWARE) && $SERVER_SOFTWARE eq 'TOMCAT') {
    $monarch_cgi    = '/monarch';
    $monarch_css    = '/monarch/css';
    $monarch_js     = '/monarch/js';
}
elsif ( -e '/usr/local/groundwork/config/db.properties' ) {
    $monarch_cgi    = '/monarch/cgi-bin';
    $monarch_css    = '/monarch';
    $monarch_js     = '/monarch';
}
else {
    # Standalone Monarch (outside of GW Monitor) is no longer supported.
}

my $form_class      = 'row1';
my $global_cell_pad = 3;

my %config_settings = ();

sub dbconnect() {
    return StorProc->dbconnect();
}

sub dbdisconnect() {
    return StorProc->dbdisconnect();
}

sub get_import_data() {
    my $data_source = $_[1];
    my @file_data   = ();
    my @errors      = ();
    if ( !open( FILE, '<', $data_source ) ) {
	push @errors, "error: cannot open $data_source to read ($!)";
    }
    else {
	while ( my $line = <FILE> ) {
	    $line =~ s/[\n\r]+/\n/;
	    next if ( $line =~ /^\s*(?:#.*)?$/ );
	    push @file_data, $line;
	}
	close FILE;
    }
    if (@errors) { @file_data = @errors }
    return @file_data;
}

sub advanced_import(@) {
    my $schema_name    = $_[1];
    my $import_file    = $_[2];
    my $processed_file = $_[3];
    my $monarch_home   = $_[4];
    my %schema         = StorProc->fetch_schema($schema_name);
    if ($import_file) {
	$import_file = "$monarch_home/automation/data/$import_file";
    }
    else {
	$import_file = $schema{'data_source'};
    }
    my %import_data = ();
    my %processed   = ();

    # Determine name and primary record position
    my %name_position = ();
    my %parent_host   = ();
    my %new_parent    = ();
    my @errors        = ();
    foreach my $column ( keys %{ $schema{'column'} } ) {
	foreach my $match ( keys %{ $schema{'column'}{$column}{'match'} } ) {
	    my $object = $schema{'column'}{$column}{'match'}{$match}{'object'};
	    if (defined $object) {
		if ( $object eq 'Primary record' ) {
		    $name_position{'Primary record'} = $schema{'column'}{$column}{'position'};
		}
		if ( $object eq 'Name' ) {
		    $name_position{'Name'} = $schema{'column'}{$column}{'position'};
		}
	    }
	}
    }
    unless ( $name_position{'Primary record'} ) {
	$name_position{'Primary record'} = $name_position{'Name'};
    }
    if ( -e "$monarch_home/automation/data/$processed_file" ) {
	if ( !open( FILE, '<', "$monarch_home/automation/data/$processed_file" ) ) {
	    push @errors, "error: cannot open $monarch_home/automation/data/$processed_file to read ($!)";
	}
	else {
	    while ( my $line = <FILE> ) {
		$line =~ s/[\r\n]+//;
		next if ( $line =~ /^\s*(?:#.*)?$/ );
		$processed{$line} = 1;
	    }
	    close(FILE);
	}
    }
    if ( !open( FILE, '<', $import_file ) ) {
	push @errors, "error: cannot open $import_file to read ($!)";
    }
    else {
	unless (@errors) {
	    my %where        = ();
	    my %hosts_vitals = ();
	    my %hosts_exist  = StorProc->fetch_list_hash_array( 'hosts', \%where );
	    foreach my $host_id ( keys %hosts_exist ) {
		$hosts_vitals{ $hosts_exist{$host_id}[1] }{'id'}                                   = $host_id;
		$hosts_vitals{ $hosts_exist{$host_id}[1] }{'address'}{ $hosts_exist{$host_id}[3] } = 1;
		$hosts_vitals{ $hosts_exist{$host_id}[1] }{'alias'}                                = $hosts_exist{$host_id}[2];
	    }
	    my %service_name = ();
	    my %service_name_hash = StorProc->fetch_list_hash_array( 'service_names', \%where );
	    foreach my $service_id ( keys %service_name_hash ) {
		$service_name{ $service_name_hash{$service_id}[1] }{'id'}           = $service_id;
		$service_name{ $service_name_hash{$service_id}[1] }{'command_line'} = $service_name_hash{$service_id}[5];
	    }
	    my %group_name          = StorProc->get_table_objects('monarch_groups');
	    my %hostgroup_name      = StorProc->get_table_objects('hostgroups');
	    my %contactgroup_name   = StorProc->get_table_objects('contactgroups');
	    my %serviceprofile_name = StorProc->get_table_objects('profiles_service');
	    my %hostprofile_name    = StorProc->get_table_objects('profiles_host');
	    my %add_objects         = ();
	    my %multihomed          = ();
	    my %discard_objects     = ();
	    my %resolve_parent      = ();
	    my $primary_rec         = undef;
	    my $delimiter           = undef;
	    my @chars               = defined( $schema{'delimiter'} ) ? split( //, $schema{'delimiter'} ) : ();

	    if (defined( $schema{'delimiter'} ) && $schema{'delimiter'} eq 'tab') {
		$delimiter = "\t";
	    }
	    elsif (!defined( $schema{'delimiter'} ) || $schema{'delimiter'} eq '') {
		$delimiter = ' ';
	    }
	    else {
		foreach my $char (@chars) {
		    unless ($char) { next }
		    if ( $char =~ /\[|\]|\(|\)|\.|\*|\^|\$|\?|\||\\|\// ) {
			$delimiter .= "\\$char";
		    }
		    else {
			$delimiter .= $char;
		    }
		}
	    }
	    while ( my $line = <FILE> ) {
		$line =~ s/[\r\n]+//;
		next if ( $line =~ /^\s*(?:#.*)?$/ );
		my @line       = split( /$delimiter/, $line );
		my %cell_value = ();
		my $i          = 1;
		foreach my $cell (@line) {
		    $cell =~ s/^\s+|\s+$//g;
		    $cell =~ s/^\"//;
		    $cell =~ s/\"$//;
		    $cell_value{$i} = $cell;
		    $i++;
		}

		next if ( $cell_value{ $name_position{'Primary record'} } eq '0' );

		$cell_value{ $name_position{'Primary record'} } =
		  StorProc->get_normalized_hostname( $cell_value{ $name_position{'Primary record'} } );

		if ( $cell_value{ $name_position{'Primary record'} } ) {
		    $primary_rec = $cell_value{ $name_position{'Primary record'} };
		}
		foreach my $column ( keys %{ $schema{'column'} } ) {
		    my %match_order = ();
		    foreach my $match ( keys %{ $schema{'column'}{$column}{'match'} } ) {
			$match_order{ $schema{'column'}{$column}{'match'}{$match}{'order'} } = $match;
		    }
		    my $cell_value = $cell_value{ $schema{'column'}{$column}{'position'} };
		    foreach my $order ( sort keys %match_order ) {
			my $value = undef;
			if ( $schema{'column'}{$column}{'match'}{ $match_order{$order} }{'match_type'} eq 'use-value-as-is' ) {
			    $value = $cell_value;
			}
			elsif ( $schema{'column'}{$column}{'match'}{ $match_order{$order} }{'match_type'} eq 'exact' ) {
			    if ( defined($cell_value) && $cell_value =~
				/^($schema{'column'}{$column}{'match'}{$match_order{$order}}{'match_string'}(?:::.*)?)$/i )
			    {
				$value = $1;
			    }
			}
			elsif ( $schema{'column'}{$column}{'match'}{ $match_order{$order} }{'match_type'} eq 'contains' ) {
			    if ( defined($cell_value) && $cell_value =~
				/$schema{'column'}{$column}{'match'}{$match_order{$order}}{'match_string'}/i )
			    {
				$value = $cell_value;
			    }
			}
			elsif ( $schema{'column'}{$column}{'match'}{ $match_order{$order} }{'match_type'} eq 'begins-with' ) {
			    if ( defined($cell_value) && $cell_value =~
				/^$schema{'column'}{$column}{'match'}{$match_order{$order}}{'match_string'}/i )
			    {
				$value = $cell_value;
			    }
			}
			elsif ( $schema{'column'}{$column}{'match'}{ $match_order{$order} }{'match_type'} eq 'ends-with' ) {
			    if ( defined($cell_value) && $cell_value =~
				/(.*?$schema{'column'}{$column}{'match'}{$match_order{$order}}{'match_string'}(?:::.*)?)$/i )
			    {
				$value = $1;
			    }
			}
			elsif ( $schema{'column'}{$column}{'match'}{ $match_order{$order} }{'match_type'} eq 'service-definition' ) {
			    if ( defined($cell_value) && $cell_value =~
				/$schema{'column'}{$column}{'match'}{$match_order{$order}}{'match_string'}/)
			    {
				my @vals = split( /$schema{'column'}{$column}{'match'}{$match_order{$order}}{'match_string'}/,
				    $cell_value );
				my $service = $vals[0];
				$service =~ s/^service-//;
				unless ( $service_name{$service}{'id'} ) {
				    if ( -e "/usr/local/groundwork/core/profiles/service-$service.xml" ) {
					my @import_results =
					  import_profile( '', '/usr/local/groundwork/core/profiles', "service-$service.xml", '1' );
					my %sn = StorProc->fetch_one( 'service_names', 'name', $service );
					$service_name{$service}{'id'}           = $sn{'servicename_id'};
					$service_name{$service}{'command_line'} = $sn{'command_line'};
				    }
				}
				if ( $service_name{$service}{'id'} ) {
				    if ( $vals[1] ) {
					$vals[1] =~ s/^!//;
					my @command = split( /!/, $service_name{$service}{'command_line'} );
					if ( $command[1] ) {
					    $import_data{$primary_rec}{'Service'}{$service}{'command_line'} = "$command[0]!$vals[1]";
					}
					else {
					    $import_data{$primary_rec}{'Service'}{$service}{'command_line'} =
					      "$service_name{$service}{'command_line'}!$vals[1]";
					}
				    }
				    else {
					$import_data{$primary_rec}{'Service'}{$service}{'command_line'} =
					  $service_name{$service}{'command_line'};
				    }
				    $import_data{$primary_rec}{'Service'}{$service}{'instances'}{ $vals[2] }{'arguments'} = $vals[3];
				}
			    }
			    else {
				my $service = $cell_value;
				if (defined $service) {
				    $service =~ s/^service-//;
				    unless ( $service_name{$service}{'id'} ) {
					if ( -e "/usr/local/groundwork/core/profiles/service-$service.xml" ) {
					    my @import_results =
					      import_profile( '', '/usr/local/groundwork/core/profiles', "service-$service.xml", '1' );
					    my %sn = StorProc->fetch_one( 'service_names', 'name', $service );
					    $service_name{$service}{'id'}           = $sn{'servicename_id'};
					    $service_name{$service}{'command_line'} = $sn{'command_line'};
					}
				    }
				    if ( $service_name{$service}{'id'} ) {
					$import_data{$primary_rec}{'Service'}{$service}{'command_line'} = $service_name{$service}{'command_line'};
				    }
				}
			    }
			}
			elsif ( $schema{'column'}{$column}{'match'}{ $match_order{$order} }{'match_type'} eq 'is-null' ) {
			    unless ( $cell_value ) {
				$value = 'is-null';
			    }
			}
			elsif ( $schema{'column'}{$column}{'match'}{ $match_order{$order} }{'match_type'} eq 'use-perl-reg-exp' ) {
			    if ( $cell_value =~ /$schema{'column'}{$column}{'match'}{$match_order{$order}}{'match_string'}/i )
			    {
				## the parens, if any, for populating $1 come from a user-supplied expression,
				## which is why they don't appear explicitly in the line above.
				$value = $1;
				unless ($value) {
				    $value = $cell_value;
				}
			    }
			}
			if ($value) {
			    my %obj_name = (
				'Host group'      => 'hostgroups',
				'Contact group'   => 'contactgroups',
				'Group'           => 'groups',
				'Parent'          => 'parents',
				'Service profile' => 'serviceprofiles'
			    );
			    my $object = $schema{'column'}{$column}{'match'}{ $match_order{$order} }{'object'};
			    if ( defined($object) && $object eq 'Address' ) {
				$multihomed{$primary_rec}{$value} = 1;
			    }
			    if ( $schema{'column'}{$column}{'match'}{ $match_order{$order} }{'rule'} eq 'Discard record' ) {
				$import_data{$primary_rec}{'discard'} = 1;
				last;
			    }
			    elsif ( $schema{'column'}{$column}{'match'}{ $match_order{$order} }{'rule'} eq 'Skip column record' ) {
				last;
			    }
			    elsif ( $schema{'column'}{$column}{'match'}{ $match_order{$order} }{'rule'} eq 'Resolve to parent' ) {
				$resolve_parent{$primary_rec}{$value} = 1;
			    }
			    elsif ( $schema{'column'}{$column}{'match'}{ $match_order{$order} }{'rule'} eq 'Discard if match existing host' ) {
				if ( $hosts_vitals{$value} ) {
				    $import_data{$primary_rec}{'discard'} = 1;
				}
			    }
			    elsif ( $schema{'column'}{$column}{'match'}{ $match_order{$order} }{'rule'} eq 'Assign host profile' ) {
				$import_data{$primary_rec}{'Host profile'} =
				  $schema{'column'}{$column}{'match'}{ $match_order{$order} }{'hostprofile'};
			    }
			    elsif ( $schema{'column'}{$column}{'match'}{ $match_order{$order} }{'rule'} eq 'Assign host profile if undefined' )
			    {
				unless ( $import_data{$primary_rec}{'Host profile'} ) {
				    $import_data{$primary_rec}{'Host profile'} =
				      $schema{'column'}{$column}{'match'}{ $match_order{$order} }{'hostprofile'};
				}
			    }
			    elsif ( $schema{'column'}{$column}{'match'}{ $match_order{$order} }{'rule'} eq 'Assign object(s)' ) {
				foreach my $obj_name (
				    @{ $schema{'column'}{$column}{'match'}{ $match_order{$order} }{ $obj_name{ $object } } }
				  )
				{
				    if ( $object eq 'Group' ) {
					$import_data{$primary_rec}{'Group'}{$obj_name} = $group_name{$obj_name};
				    }
				    elsif ( $object eq 'Contact group' ) {
					$import_data{$primary_rec}{'Contact group'}{$obj_name} = $contactgroup_name{$obj_name};
				    }
				    elsif ( $object eq 'Host group' ) {
					$import_data{$primary_rec}{'Host group'}{$obj_name} = $hostgroup_name{$obj_name};
				    }
				    elsif ( $object eq 'Parent' ) {
					$import_data{$primary_rec}{'Parent'}{$obj_name} = 1;
					$parent_host{$obj_name} = 1;
				    }
				    elsif ( $object eq 'Service profile' ) {
					$import_data{$primary_rec}{'Service profile'}{$obj_name} = $serviceprofile_name{$obj_name};
				    }
				}
			    }
			    elsif ( $schema{'column'}{$column}{'match'}{ $match_order{$order} }{'rule'} eq 'Assign value to' ) {
				$import_data{$primary_rec}{$object} = $value;
			    }
			    elsif ( $schema{'column'}{$column}{'match'}{ $match_order{$order} }{'rule'} eq 'Assign value if undefined' ) {
				unless ( $import_data{$primary_rec}{$object} ) {
				    $import_data{$primary_rec}{$object} = $value;
				}
			    }
			    elsif ( $schema{'column'}{$column}{'match'}{ $match_order{$order} }{'rule'} eq 'Assign object if exists' ) {
				if ( $object eq 'Group' ) {
				    if ( $group_name{$value} ) {
					$import_data{$primary_rec}{'Group'}{$value} = $group_name{$value};
				    }
				}
				elsif ( $object eq 'Contact group' ) {
				    if ( $contactgroup_name{$value} ) {
					$import_data{$primary_rec}{'Contact group'}{$value} = $contactgroup_name{$value};
				    }
				}
				elsif ( $object eq 'Host group' ) {
				    if ( $hostgroup_name{$value} ) {
					$import_data{$primary_rec}{'Host group'}{$value} = $hostgroup_name{$value};
				    }
				}
				elsif ( $object eq 'Parent' ) {
				    $import_data{$primary_rec}{'Parent'}{$value} = 1;
				    $parent_host{$value} = 1;
				}
				elsif ( $object eq 'Host profile' ) {
				    unless ( $hostprofile_name{$value} ) {
					$value =~ s/host-profile-//;
					unless ( $hostprofile_name{$value} ) {
					    if ( -e "/usr/local/groundwork/core/profiles/host-profile-$value.xml" ) {
						my @import_results =
						  import_profile( '', '/usr/local/groundwork/core/profiles', "host-profile-$value.xml", '' );
						my %hp = StorProc->fetch_one( 'profiles_host', 'name', $value );
						$import_data{$primary_rec}{'Host profile'}{$value} = $hp{'hostprofile_id'};
						$serviceprofile_name{$value} = $hp{'hostprofile_id'};
					    }
					}
				    }
				    if ( $hostprofile_name{$value} ) {
					$import_data{$primary_rec}{'Host profile'} = $value;
				    }
				}
				elsif ( $object eq 'Service profile' ) {
				    unless ( $serviceprofile_name{$value} ) {
					$value =~ s/service-profile-//;
					unless ( $serviceprofile_name{$value} ) {
					    if ( -e "/usr/local/groundwork/core/profiles/service-profile-$value.xml" ) {
						my @import_results =
						  import_profile( '', '/usr/local/groundwork/core/profiles', "service-profile-$value.xml", '' );
						my %sp = StorProc->fetch_one( 'profiles_service', 'name', $value );
						$import_data{$primary_rec}{'Service profile'}{$value} = $sp{'serviceprofile_id'};
						$serviceprofile_name{$value} = $sp{'serviceprofile_id'};
					    }
					}
				    }
				    if ( $serviceprofile_name{$value} ) {
					$import_data{$primary_rec}{'Service profile'}{$value} = $serviceprofile_name{$value};
				    }
				}
				elsif ( $object eq 'Service' ) {
				    unless ( $service_name{$value} ) {
					$value =~ s/service-//;
					unless ( $service_name{$value}{'id'} ) {
					    if ( -e "/usr/local/groundwork/core/profiles/service-$value.xml" ) {
						my @import_results =
						  import_profile( '', '/usr/local/groundwork/core/profiles', "service-$value.xml", '1' );
						my %sn = StorProc->fetch_one( 'service_names', 'name', $value );
						$service_name{$value}{'id'} = $sn{'servicename_id'};
					    }
					}
				    }
				    if ( $service_name{$value}{'id'} ) {
					$import_data{$primary_rec}{'Service'}{$value}{'name'} = $value;
				    }
				}
			    }
			    elsif (
				$schema{'column'}{$column}{'match'}{ $match_order{$order} }{'rule'} eq 'Add if not exists and assign object' )
			    {
				if ( $object eq 'Group' ) {
				    ## check for MySQL case insensitivity
				    foreach my $group ( keys %group_name ) {
					if ( $value =~ /^$group$/i ) {
					    $value = $group;
					}
				    }
				    if ( $group_name{$value} ) {
					$import_data{$primary_rec}{'Group'}{$value} = $group_name{$value};
				    }
				    else {
					$add_objects{'groups'}{$value}{$primary_rec} = 1;
					$discard_objects{$primary_rec}{'groups'}{$value} = 1;
				    }
				}
				elsif ( $object eq 'Contact group' ) {
				    ## check for MySQL case insensitivity
				    foreach my $contactgroup ( keys %contactgroup_name ) {
					if ( $value =~ /^$contactgroup$/i ) {
					    $value = $contactgroup;
					}
				    }
				    if ( $contactgroup_name{$value} ) {
					$import_data{$primary_rec}{'Contact group'}{$value} = $contactgroup_name{$value};
				    }
				    else {
					$add_objects{'contactgroups'}{$value}{$primary_rec} = 1;
					$discard_objects{$primary_rec}{'contactgroups'}{$value} = 1;
				    }
				}
				elsif ( $object eq 'Host group' ) {
				    ## check for MySQL case insensitivity
				    foreach my $hostgroup ( keys %hostgroup_name ) {
					if ( $value =~ /^$hostgroup$/i ) {
					    $value = $hostgroup;
					}
				    }
				    if ( $hostgroup_name{$value} ) {
					$import_data{$primary_rec}{'Host group'}{$value} = $hostgroup_name{$value};
				    }
				    else {
					$add_objects{'hostgroups'}{$value}{$primary_rec} = 1;
					$discard_objects{$primary_rec}{'hostgroups'}{$value} = 1;
				    }
				}
			    }
			    elsif ( $schema{'column'}{$column}{'match'}{ $match_order{$order} }{'rule'} eq 'Convert dword and assign to' ) {
				use Socket;
				$import_data{$primary_rec}{$object} = inet_ntoa( pack 'N', $value );
			    }
			    elsif ( $schema{'column'}{$column}{'match'}{ $match_order{$order} }{'rule'} eq 'Assign service' ) {
				my $service = $schema{'column'}{$column}{'match'}{ $match_order{$order} }{'service_name'};
				$import_data{$primary_rec}{'Service'}{$service}{'service_id'} = $service_name{$service}{'id'};
			    }
			}
		    }
		}
	    }
	    close(FILE);

	    ############################################################################
	    # determine new hosts and exceptions and apply smart names and apply default profile
	    #
	    foreach my $primary_rec ( sort keys %import_data ) {
		if (   $import_data{$primary_rec}{'Name'}
		    && $import_data{$primary_rec}{'Address'}
		    && $import_data{$primary_rec}{'Alias'} )
		{
		    if ( $hosts_vitals{ $import_data{$primary_rec}{'Name'} }{'id'} ) {
			$import_data{$primary_rec}{'exists'}  = 1;
			$import_data{$primary_rec}{'host_id'} = $hosts_vitals{ $import_data{$primary_rec}{'Name'} }{'id'};
		    }
		    else {
			if ( $parent_host{ $import_data{$primary_rec}{'Name'} } ) {
			    $import_data{$primary_rec}{'new_parent'} = 1;
			}
			$import_data{$primary_rec}{'new'} = 1;
		    }
		}
		elsif ( $schema{'smart_name'} ) {
		    unless ( $import_data{$primary_rec}{'Name'}
			&& $import_data{$primary_rec}{'Address'}
			&& $import_data{$primary_rec}{'Alias'} )
		    {
			unless ( $import_data{$primary_rec}{'Name'} ) {
			    if ( $import_data{$primary_rec}{'Alias'} ) {
				$import_data{$primary_rec}{'Name'} = $import_data{$primary_rec}{'Alias'};
			    }
			    elsif ( $import_data{$primary_rec}{'Address'} ) {
				$import_data{$primary_rec}{'Name'} = $import_data{$primary_rec}{'Address'};
			    }
			    else {
				$import_data{$primary_rec}{'exception'} = 1;
			    }
			}
			unless ( $import_data{$primary_rec}{'Address'} ) {
			    if ( $import_data{$primary_rec}{'Alias'} ) {
				$import_data{$primary_rec}{'Address'} = $import_data{$primary_rec}{'Alias'};
			    }
			    elsif ( $import_data{$primary_rec}{'Name'} ) {
				$import_data{$primary_rec}{'Address'} = $import_data{$primary_rec}{'Name'};
			    }
			    else {
				$import_data{$primary_rec}{'exception'} = 1;
			    }
			}
			unless ( $import_data{$primary_rec}{'Alias'} ) {
			    if ( $import_data{$primary_rec}{'Address'} ) {
				$import_data{$primary_rec}{'Alias'} = $import_data{$primary_rec}{'Address'};
			    }
			    elsif ( $import_data{$primary_rec}{'Name'} ) {
				$import_data{$primary_rec}{'Alias'} = $import_data{$primary_rec}{'Name'};
			    }
			    else {
				$import_data{$primary_rec}{'exception'} = 1;
			    }
			}
			if ( $hosts_vitals{ $import_data{$primary_rec}{'Name'} }{'id'} ) {
			    $import_data{$primary_rec}{'exists'}  = 1;
			    $import_data{$primary_rec}{'host_id'} = $hosts_vitals{ $import_data{$primary_rec}{'Name'} }{'id'};
			}
			else {
			    if ( $parent_host{ $import_data{$primary_rec}{'Name'} } ) {
				$import_data{$primary_rec}{'new_parent'} = 1;
			    }
			    $import_data{$primary_rec}{'new'} = 1;
			}
		    }
		}
		else {
		    $import_data{$primary_rec}{'exception'} = 1;
		}
		if ( $schema{'default_profile'} ) {
		    unless ( $import_data{$primary_rec}{'Host profile'} ) {
			$import_data{$primary_rec}{'Host profile'} = $schema{'default_profile'};
		    }
		}
		unless ( $import_data{$primary_rec}{'Host profile'} ) {
		    $import_data{$primary_rec}{'exception'} = 1;
		}
	    }

	    ############################################################################
	    # Apply the Resolve to parent rule
	    #
	    if ( keys %resolve_parent ) {
		my %new_parent = ();
		foreach my $primary_rec ( sort keys %import_data ) {
		    $hosts_vitals{ $import_data{$primary_rec}{'Name'} }{'alias'} = $import_data{$primary_rec}{'Alias'};
		    foreach my $address ( keys %{ $multihomed{$primary_rec} } ) {
			$hosts_vitals{ $import_data{$primary_rec}{'Name'} }{'address'}{$address} = 1;
		    }
		}

		foreach my $primary_rec ( keys %resolve_parent ) {
		    foreach my $parent ( keys %{ $resolve_parent{$primary_rec} } ) {
			foreach my $host ( keys %hosts_vitals ) {
			    if ( $host eq $parent ) {
				$import_data{$primary_rec}{'Parent'}{$host} = 1;
				unless ( $hosts_vitals{$host}{'id'} ) {
				    $new_parent{$host} = 1;
				}
			    }
			    elsif ( $hosts_vitals{$host}{'alias'} eq $parent ) {
				$import_data{$primary_rec}{'Parent'}{$host} = 1;
				unless ( $hosts_vitals{$host}{'id'} ) {
				    $new_parent{$host} = 1;
				}
			    }
			    else {
				foreach my $address ( keys %{ $hosts_vitals{$host}{'address'} } ) {
				    if ( $address eq $parent ) {
					$import_data{$primary_rec}{'Parent'}{$host} = 1;
					unless ( $hosts_vitals{$host}{'id'} ) {
					    $new_parent{$host} = 1;
					}
				    }
				}
			    }
			}
		    }
		}

		foreach my $primary_rec ( keys %import_data ) {
		    if ( $new_parent{ $import_data{$primary_rec}{'Name'} } ) {
			$import_data{$primary_rec}{'new_parent'} = 1;
		    }
		}
	    }

	    ############################################################################
	    # determine what to keep and what to throw away
	    #
	    foreach my $primary_rec ( keys %import_data ) {
		if ( $processed{$primary_rec} ) {
		    delete $import_data{$primary_rec};
		    next;
		}
		if ( $import_data{$primary_rec}{'discard'} ) {
		    delete $import_data{$primary_rec};
		    delete $resolve_parent{$primary_rec};
		    foreach my $group ( keys %{ $discard_objects{$primary_rec}{'groups'} } ) {
			delete $add_objects{'groups'}{$group};
		    }
		    foreach my $group ( keys %{ $discard_objects{$primary_rec}{'contactgroups'} } ) {
			delete $add_objects{'contactgroups'}{$group};
		    }
		    foreach my $group ( keys %{ $discard_objects{$primary_rec}{'hostgroups'} } ) {
			delete $add_objects{'hostgroups'}{$group};
		    }
		    next;
		}
	    }

	    ############################################################################
	    # add new supporting objects
	    #
	    foreach my $group ( keys %{ $add_objects{'groups'} } ) {
		my @vals = ( \undef, $group, $group, '', '', "<?xml version=\"1.0\" encoding=\"iso-8859-1\" ?>\n<data>\n</data>" );
		my $id = StorProc->insert_obj_id( 'monarch_groups', \@vals, 'group_id' );
		$group_name{$group} = $id;
		foreach my $record ( keys %{ $add_objects{'groups'}{$group} } ) {
		    $import_data{$record}{'Group'}{$group} = $id;
		}
	    }
	    foreach my $group ( keys %{ $add_objects{'contactgroups'} } ) {
		my @vals = ( \undef, $group, $group, '' );
		my $id = StorProc->insert_obj_id( 'contactgroups', \@vals, 'contactgroup_id' );
		$contactgroup_name{$group} = $id;
		foreach my $record ( keys %{ $add_objects{'contactgroups'}{$group} } ) {
		    $import_data{$record}{'Contact group'}{$group} = $id;
		}
	    }
	    foreach my $group ( keys %{ $add_objects{'hostgroups'} } ) {
		my @vals = ( \undef, $group, $group, '', '', '', '1', '', '' );
		my $id = StorProc->insert_obj_id( 'hostgroups', \@vals, 'hostgroup_id' );
		foreach my $record ( keys %{ $add_objects{'hostgroups'}{$group} } ) {
		    $import_data{$record}{'Host group'}{$group} = $id;
		}
	    }

	    ############################################################################
	    # only for host-profile-sync
	    #
	    if ( $schema{'type'} eq 'host-profile-sync' ) {
		my %import_host = ();
		foreach my $primary_rec ( keys %import_data ) {
		    $import_host{ $import_data{$primary_rec}{'Name'} } = 1;
		}
		%import_data = StorProc->profile_sync( \%import_data, \%import_host, \%schema );
	    }
	}
    }
    return \%import_data, \%schema, \@errors;
}

sub process_import_data(@) {
    my %import_data         = %{ $_[1] };
    my %results             = ();
    my %externals           = StorProc->get_externals();
    my %host_name           = StorProc->get_table_objects('hosts');
    my %hostprofile_name    = StorProc->get_table_objects('profiles_host');
    my %serviceprofile_name = StorProc->get_table_objects('profiles_service');
    my %service_name        = ();
    my %where               = ();
    my %service_name_id     = ();
    my %service_name_hash   = StorProc->fetch_list_hash_array( 'service_names', \%where );

    foreach my $service_id ( keys %service_name_hash ) {
	$service_name_id{$service_id}                                        = $service_name_hash{$service_id}[1];
	$service_name{ $service_name_hash{$service_id}[1] }{'id'}            = $service_id;
	$service_name{ $service_name_hash{$service_id}[1] }{'template'}      = $service_name_hash{$service_id}[3];
	$service_name{ $service_name_hash{$service_id}[1] }{'check_command'} = $service_name_hash{$service_id}[4];
	$service_name{ $service_name_hash{$service_id}[1] }{'command_line'}  = $service_name_hash{$service_id}[5];
	$service_name{ $service_name_hash{$service_id}[1] }{'escalation'}    = $service_name_hash{$service_id}[6];
	$service_name{ $service_name_hash{$service_id}[1] }{'extinfo'}       = $service_name_hash{$service_id}[7];
    }
    my %service_name_overrides = ();
    my %service_name_override_hash = StorProc->fetch_list_hash_array( 'servicename_overrides', \%where );
    foreach my $service_id ( keys %service_name_hash ) {
	$service_name_overrides{ $service_name_id{$service_id} }{'id'}                  = $service_id;
	$service_name_overrides{ $service_name_id{$service_id} }{'check_period'}        = $service_name_override_hash{$service_id}[1];
	$service_name_overrides{ $service_name_id{$service_id} }{'notification_period'} = $service_name_override_hash{$service_id}[2];
	$service_name_overrides{ $service_name_id{$service_id} }{'event_handler'}       = $service_name_override_hash{$service_id}[3];
	if ( $service_name_override_hash{$service_id}[4] ) {
	    $service_name_overrides{ $service_name_id{$service_id} }{'data'} = $service_name_override_hash{$service_id}[4];
	}
	else {
	    $service_name_overrides{ $service_name_id{$service_id} }{'data'} = qq(<?xml version="1.0" encoding="iso-8859-1" ?>
<data>
</data>);
	}
    }
    my %service_name_dependency = ();
    my %service_name_dependency_hash = StorProc->fetch_list_hash_array( 'servicename_dependency', \%where );
    foreach my $id ( keys %service_name_dependency_hash ) {
	$service_name_dependency{ $service_name_id{ $service_name_dependency_hash{$id}[1] } }{$id}{'host'} =
	  $service_name_dependency_hash{$id}[2];
	$service_name_dependency{ $service_name_id{ $service_name_dependency_hash{$id}[1] } }{$id}{'template'} =
	  $service_name_dependency_hash{$id}[3];
    }

    %externals = ();
    my %externals_hash = StorProc->fetch_list_hash_array( 'externals', \%where );
    foreach my $id ( keys %externals_hash ) {
	$externals{ $externals_hash{$id}[3] }{$id} = $externals_hash{$id}[4];
    }
    my %service_name_externals = ();
    my %service_name_externals_hash_array = StorProc->fetch_hash_array_generic_key( 'external_service_names', \%where );
    foreach my $key ( keys %service_name_externals_hash_array ) {
	my $external_id    = $service_name_externals_hash_array{$key}[0];
	my $servicename_id = $service_name_externals_hash_array{$key}[1];
	$service_name_externals{$servicename_id}{$external_id} = $external_id;
    }
    my %host_profile_externals = ();
    my %host_profile_externals_hash_array = StorProc->fetch_hash_array_generic_key( 'external_host_profile', \%where );
    foreach my $key ( keys %host_profile_externals_hash_array ) {
	my $external_id    = $host_profile_externals_hash_array{$key}[0];
	my $hostprofile_id = $host_profile_externals_hash_array{$key}[1];
	$host_profile_externals{$hostprofile_id}{$external_id} = $external_id;
    }

    # Arrange process order so that new parent hosts are added first.
    # FIX MINOR:  If a parent is ignored due to a circular parentage loop, then all its children should be ignored as well,
    # so we don't import any of the children without their intended parentage properly defined.
    # FIX MINOR:  Deal appropriately with importing a child with a declared parent which is neither in the set to be imported,
    # nor already existing within Monarch, so we don't import the child without its intended parentage properly defined.
    # FIX MINOR:  If circular parentage loops are discovered, offer the user a choice of whether to cancel the entire import,
    # to import only the hosts not related to those with such parentage problems, or to also import the affected hosts while
    # ignoring their respective claimed parentage.
    my @non_parents = ();
    my %sorted      = ();
    my %new_parents = ();
    my %children    = ();
    my @records     = ();
    foreach my $rec ( keys %import_data ) {
	if ( $import_data{$rec}{'new_parent'} ) {
	    $new_parents{ $import_data{$rec}{'Name'} } = $rec;
	    delete $import_data{$rec}{'Parent'}{ $import_data{$rec}{'Name'} };
	    if ( keys %{ $import_data{$rec}{'Parent'} } ) {
		$children{ $import_data{$rec}{'Name'} } = $rec;
	    }
	    else {
		push @records, $rec;
		$sorted{ $import_data{$rec}{'Name'} } = $rec;
	    }
	}
	else {
	    push @non_parents, $rec;
	}
    }
    my %recursive_parents = ();
    for (my $loop = scalar keys %children; $loop >= 0; --$loop) {
	last unless %children;
	foreach my $child ( keys %children ) {
	    my $have_unsorted_parent = 0;
	    foreach my $parent ( keys %{ $import_data{ $children{$child} }{'Parent'} } ) {
		$recursive_parents{$parent}{$child} = 1;
		if ( $recursive_parents{$child}{$parent} ) {
		    $results{'errors'}{ $child } .= "Host \"$child\" is part of a circular parentage loop (parent is \"$parent\") and is being ignored.";
		    delete $children{$child};
		}
		# FIX MINOR:  What value does the $new_parents{$parent} test add here?
		elsif ( $new_parents{$parent} and not $sorted{$parent} ) {
		    $have_unsorted_parent = 1;
		}
	    }
	    unless ($have_unsorted_parent or not exists $children{$child}) {
		push @records, $children{$child};
		$sorted{$child} = 1;
		delete $children{$child};
	    }
	}
    }
    foreach my $child ( keys %children ) {
	# This covers all loops with more than two members.
	$results{'errors'}{ $child } .= "Host \"$child\" is part of a circular parentage loop and is being ignored.";
    }
    ## FIX THIS:  The handling of $results{'errors'}{$rec} throughout this loop is poor.
    ## We should probably make it an array, push new messages rather than concatenate them,
    ## and adjust all callers accordingly.  Or always bypass further processing upon first error.
    push( @records, @non_parents );
    foreach my $rec (@records) {
	if ( $import_data{$rec}{'delete'} ) {
	    my %where = ( 'host_id' => $import_data{$rec}{'host_id'} );
	    my $result = StorProc->delete_one_where( 'contactgroup_host', \%where );
	    if ( $result =~ /error/i ) { $results{'errors'}{$rec} .= $result }
	    $result = StorProc->delete_all( 'hosts', 'host_id', $import_data{$rec}{'host_id'} );
	    if ( $result =~ /error/i ) { $results{'errors'}{$rec} .= $result }
	    $results{'deleted'}{ $import_data{$rec}{'Name'} } = 'Host removed.';
	}
	elsif ( $import_data{$rec}{'exception'} ) {
	    $results{'exception'}{$rec} = "Record $rec skipped for lack of information.";
	}
	else {
	    my %profile = ();
	    my $id      = undef;
	    my %exists  = ();
	    my %values  = (
		'alias'   => $import_data{$rec}{'Alias'},
		'address' => $import_data{$rec}{'Address'}
	    );
	    if ( $import_data{$rec}{'Host profile'} ) {
		@{ $profile{'service_profiles'} } = ();
		@{ $profile{'externals'} }        = ();
		@{ $profile{'parents'} }          = ();
		unless ( $hostprofile_name{ $import_data{$rec}{'Host profile'} } ) {
		    $import_data{$rec}{'Host profile'} =~ s/host-profile-//;
		    unless ( $hostprofile_name{ $import_data{$rec}{'Host profile'} } ) {
			my @import_results =
			  import_profile( '', '/usr/local/groundwork/core/profiles', "host-profile-$import_data{$rec}{'Host profile'}.xml",
			    '' );
			## FIX THIS:  do something with those results?
		    }
		}
		if ( $hostprofile_name{ $import_data{$rec}{'Host profile'} } ) {
		    %profile = StorProc->fetch_one( 'profiles_host', 'name', $import_data{$rec}{'Host profile'} );
		    my %where = ( 'hostprofile_id' => $profile{'hostprofile_id'} );
		    @{ $profile{'service_profiles'} } =
		      StorProc->fetch_list_where( 'profile_host_profile_service', 'serviceprofile_id', \%where );
		    @{ $profile{'parents'} }    = StorProc->fetch_list_where( 'profile_parent',    'host_id',      \%where );
		    @{ $profile{'hostgroups'} } = StorProc->fetch_list_where( 'profile_hostgroup', 'hostgroup_id', \%where );
		    %where = ( 'hostprofile_id' => $profile{'hostprofile_id'} );
		    @{ $profile{'contactgroups'} } = StorProc->fetch_list_where( 'contactgroup_host_profile', 'contactgroup_id', \%where );
		    $values{'hostprofile_id'}        = $profile{'hostprofile_id'};
		    $values{'host_escalation_id'}    = $profile{'host_escalation_id'};
		    $values{'service_escalation_id'} = $profile{'service_escalation_id'};
		    $values{'hosttemplate_id'}       = $profile{'host_template_id'};
		    $values{'hostextinfo_id'}        = $profile{'host_extinfo_id'};
		}
	    }
	    if ( $import_data{$rec}{'exists'} ) {
		$id = $import_data{$rec}{'host_id'};
		my $result = StorProc->update_obj( 'hosts', 'host_id', $id, \%values );
		if ( $result =~ /error/i ) { $results{'errors'}{$rec} .= $result; }
		$result = StorProc->delete_all( 'serviceprofile_host', 'host_id', $id );
		if ( $result =~ /^Error/ ) { $results{'errors'}{$rec} .= $result; }
		$result = StorProc->delete_all( 'host_parent', 'host_id', $id );
		if ( $result =~ /^Error/ ) { $results{'errors'}{$rec} .= $result; }
		$result = StorProc->delete_all( 'external_host', 'host_id', $id );
		if ( $result =~ /^Error/ ) { $results{'errors'}{$rec} .= $result; }
		$result = StorProc->delete_all( 'hostgroup_host', 'host_id', $id );
		if ( $result =~ /^Error/ ) { $results{'errors'}{$rec} .= $result; }
		$result = StorProc->delete_all( 'monarch_group_host', 'host_id', $id );
		if ( $result =~ /^Error/ ) { $results{'errors'}{$rec} .= $result; }
		my %w = ( 'host_id' => $id );
		$result = StorProc->delete_one_where( 'contactgroup_host', \%w );
		if ( $result =~ /^Error/ ) { $results{'errors'}{$rec} .= $result; }

		unless ( $results{'errors'}{$rec} ) {
		    $results{'updated'}{$rec} = 'host updated';
		}
	    }
	    else {
		my @values = (
		    \undef, $import_data{$rec}{'Name'},
		    $values{'alias'}, $values{'address'}, '',
		    $values{'hosttemplate_id'},
		    $values{'hostextinfo_id'},
		    $values{'hostprofile_id'},
		    $values{'host_escalation_id'},
		    $values{'service_escalation_id'},
		    '1', '', ''
		);
		if ( $host_name{ $import_data{$rec}{'Name'} } ) {
		    $results{'errors'}{$rec} .= "Duplicate, a host with name \"$import_data{$rec}{'Name'}\" already added.";
		}
		elsif ($values{'alias'} eq '') {
		    $results{'errors'}{$rec} .= "No alias is specified for host \"$import_data{$rec}{'Name'}\".";
		}
		elsif ($values{'address'} eq '') {
		    $results{'errors'}{$rec} .= "No address is specified for host \"$import_data{$rec}{'Name'}\".";
		}
		else {
		    $id = StorProc->insert_obj_id( 'hosts', \@values, 'host_id' );
		    if ( $id =~ /error/i ) {
			$results{'errors'}{$rec} .= "Failed to add host \"$import_data{$rec}{'Name'}\": $id";
		    }
		    else {
			$host_name{ $import_data{$rec}{'Name'} } = $id;
			$results{'added'}{$rec} = "Host \"$import_data{$rec}{'Name'}\" added.";
		    }
		}
	    }
	    unless ( $results{'errors'}{$rec} ) {
		if ( $profile{'hostprofile_id'} ) {
		    my @hosts = ($id);
		    my @errors = StorProc->host_profile_apply( $profile{'hostprofile_id'}, \@hosts );
		    $results{'errors'}{$rec} .= join('<br>', @errors) if @errors;
		    my ( $cnt, $err ) = StorProc->service_profile_apply( \@{ $profile{'service_profiles'} }, 'replace', \@hosts );
		    $results{'errors'}{$rec} .= join('<br>', @$err) if @$err;
		    foreach my $spid ( @{ $profile{'service_profiles'} } ) {
			$exists{'service_profiles'}{$spid} = 1;
			my @vals = ( $spid, $id );
			my $result = StorProc->insert_obj( 'serviceprofile_host', \@vals );
			if ( $result =~ /^Error/ ) {
			    $results{'errors'}{$rec} .= $result;
			}
		    }
		    foreach my $pid ( @{ $profile{'parents'} } ) {
			$exists{'parents'}{$pid} = 1;
			unless ( $id eq $pid ) {
			    my @vals = ( $id, $pid );
			    my $result = StorProc->insert_obj( 'host_parent', \@vals );
			    if ( $result =~ /^Error/ ) {
				$results{'errors'}{$rec} .= $result;
			    }
			}
		    }
		    foreach my $ext ( keys %{ $host_profile_externals{ $profile{'hostprofile_id'} } } ) {
			my @vals = ( $ext, $id, $externals{'host'}{$ext}, \'0+0' );
			my $result = StorProc->insert_obj( 'external_host', \@vals );
			if ( $result =~ /^Error/ ) {
			    $results{'errors'}{$rec} .= $result;
			}
		    }
		    foreach my $hgid ( @{ $profile{'hostgroups'} } ) {
			$exists{'hostgroups'}{$hgid} = 1;
			my @vals = ( $hgid, $id );
			my $result = StorProc->insert_obj( 'hostgroup_host', \@vals );
			if ( $result =~ /^Error/ ) {
			    $results{'errors'}{$rec} .= $result;
			}
		    }
		    foreach my $cgid ( @{ $profile{'contactgroups'} } ) {
			$exists{'contactgroups'}{$cgid} = 1;
			my @vals = ( $cgid, $id );
			my $result = StorProc->insert_obj( 'contactgroup_host', \@vals );
			if ( $result =~ /^Error/ ) {
			    $results{'errors'}{$rec} .= $result;
			}
		    }
		}
		foreach my $value ( keys %{ $import_data{$rec}{'Parent'} } ) {
		    if ( $host_name{$value} ) {
			unless ( $exists{'parents'}{ $host_name{$value} } ) {
			    unless ( $id eq $host_name{$value} ) {
				my @values = ( $id, $host_name{$value} );
				my $result = StorProc->insert_obj( 'host_parent', \@values );
				if ( $result =~ /error/i ) {
				    $results{'errors'}{$rec} .= $result;
				}
			    }
			}
		    }
		}
		foreach my $value ( keys %{ $import_data{$rec}{'Contact group'} } ) {
		    if ( $import_data{$rec}{'Contact group'}{$value} ) {
			unless ( $exists{'contactgroups'}{ $import_data{$rec}{'Contact group'}{$value} } ) {
			    my @values = ( $import_data{$rec}{'Contact group'}{$value}, $id );
			    my $result = StorProc->insert_obj( 'contactgroup_host', \@values );
			    if ( $result =~ /error/i ) {
				$results{'errors'}{$rec} .= "contact group \"$value\"=\"$import_data{$rec}{'Contact group'}{$value}\": $result";
			    }
			}
		    }
		}
		foreach my $value ( keys %{ $import_data{$rec}{'Host group'} } ) {
		    if ( $import_data{$rec}{'Host group'}{$value} ) {
			unless ( $exists{'hostgroups'}{ $import_data{$rec}{'Host group'}{$value} } ) {
			    my @values = ( $import_data{$rec}{'Host group'}{$value}, $id );
			    my $result = StorProc->insert_obj( 'hostgroup_host', \@values );
			    if ( $result =~ /error/i ) {
				$results{'errors'}{$rec} .= "host group \"$value\"=\"$import_data{$rec}{'Host group'}{$value}\": $result";
			    }
			}
		    }
		}
		foreach my $value ( keys %{ $import_data{$rec}{'Group'} } ) {
		    if ( $import_data{$rec}{'Group'}{$value} ) {
			unless ( $exists{'groups'}{ $import_data{$rec}{'Group'}{$value} } ) {
			    my @values = ( $import_data{$rec}{'Group'}{$value}, $id );
			    my $result = StorProc->insert_obj( 'monarch_group_host', \@values );
			    if ( $result =~ /error/i ) {
				$results{'errors'}{$rec} .= "group \"$value\"=\"$import_data{$rec}{'Group'}{$value}\": $result";
			    }
			}
		    }
		}
		my @profiles = ();
		foreach my $value ( keys %{ $import_data{$rec}{'Service profile'} } ) {
		    if ( $import_data{$rec}{'Service profile'}{$value} ) {
			unless ( $exists{'service_profiles'}{ $import_data{$rec}{'Service profile'}{$value} } ) {
			    my @values = ( $import_data{$rec}{'Service profile'}{$value}, $id );
			    my $result = StorProc->insert_obj( 'serviceprofile_host', \@values );
			    if ( $result =~ /error/i ) {
				$results{'errors'}{$rec} .=
				  "service profile \"$value\"=\"$import_data{$rec}{'Service profile'}{$value}\": $result";
			    }
			    push @profiles, $import_data{$rec}{'Service profile'}{$value};
			}
		    }
		}
		if (@profiles) {
		    my @hosts = ($id);
		    my ( $cnt, $err ) = StorProc->service_profile_apply( \@profiles, 'merge', \@hosts );
		    $results{'errors'}{$rec} .= join('<br>', @$err) if @$err;
		}
		foreach my $service ( keys %{ $import_data{$rec}{'Service'} } ) {
		    # We cannot use an early call to StorProc->get_hostid_servicenameid_serviceid() above because
		    # the set of services may have been changed just above by StorProc->service_profile_apply().
		    # Thus we must probe now for this individual service.
		    my $sid = undef;
		    my %where = ( 'host_id' => $id, 'servicename_id' => $service_name{$service}{'id'} );
		    my @sids = StorProc->fetch_list_where('services', 'service_id', \%where);
		    if (@sids) {
			if (@sids == 1) {
			    $sid = $sids[0];
			}
			else {
			    # This will be impossible once we have a unique {host_id, servicename_id} index on 'services'.
			    $results{'errors'}{$rec} .= "Error: found duplicates of host $import_data{$rec}{'Name'} service $service.";
			}
		    }
		    else {
			my @values = (
			    \undef,                                                  $id,
			    $service_name{$service}{'id'},                           $service_name{$service}{'template'},
			    $service_name{$service}{'extinfo'},                      $service_name{$service}{'escalation'},
			    '1',                                                     $service_name{$service}{'check_command'},
			    $import_data{$rec}{'Service'}{$service}{'command_line'}, '',
			    ''
			);
			$sid = StorProc->insert_obj_id( 'services', \@values, 'service_id' );
			if ( $sid =~ /^Error/ ) {
			    $results{'errors'}{$rec} .= $sid;
			    $sid = undef;
			}
		    }
		    if (defined $sid) {
			my @values = (
			    $sid,
			    $service_name_overrides{$service}{'check_period'},
			    $service_name_overrides{$service}{'notification_period'},
			    $service_name_overrides{$service}{'event_handler'},
			    $service_name_overrides{$service}{'data'}
			);
			my $result = StorProc->insert_obj( 'service_overrides', \@values );
			if ( $result =~ /^Error/ ) {
			    $results{'errors'}{$rec} .= $result;
			}
			foreach my $dependency_id ( keys %{ $service_name_dependency{$service} } ) {
			    my $depend_on_host = $id;
			    if ( $service_name_dependency{$service}{$dependency_id}{'host'} ) {
				$depend_on_host = $service_name_dependency{$service}{$dependency_id}{'host'};
			    }
			    @values = ( \undef, $sid, $id, $depend_on_host, $service_name_dependency{$service}{$dependency_id}{'template'}, '' );
			    my $result = StorProc->insert_obj( 'service_dependency', \@values );
			    if ( $result =~ /^Error/ ) {
				$results{'errors'}{$rec} .= $result;
			    }
			}
			foreach my $instance ( keys %{ $import_data{$rec}{'Service'}{$service}{'instance'} } ) {
			    @values = ( \undef, $sid, $instance, '1', $import_data{$rec}{'Service'}{$service}{'instance'}{$instance}{'arguments'} );
			    my $result = StorProc->insert_obj( 'service_instance', \@values );
			    if ( $result =~ /^Error/ ) {
				$results{'errors'}{$rec} .= $result;
			    }
			}
			foreach my $ext ( keys %{ $service_name_externals{ $service_name{$service}{'id'} } } ) {
			    @values = ( $ext, $id, $sid, $externals{'service'}{$ext}, \'0+0' );
			    my $result = StorProc->insert_obj( 'external_service', \@values );
			    if ( $result =~ /^Error/ ) {
				$results{'errors'}{$rec} .= $result;
			    }
			}
		    }
		}
	    }
	}
    }

    # Return a hash of hashes describing what happened, key = host name
    return %results;
}

sub process_import_sync(@) {
    my %schema      = %{ $_[1] };
    my %import_data = %{ $_[2] };
    my $data_check  = $_[3];
    my %results     = ();           # Hash of arrays to capture results

    # Translate host attributes name, address, alias to primary key values
    my %hosts_vitals = StorProc->get_hosts_vitals();

    # Get sync objects - the values we want are stored as hash keys so we need to extract them
    # Each record has only one sync object value, but it is stored as a hash key
    my %sync_objs = ();
    foreach my $rec ( keys %import_data ) {
	if ( $schema{'sync_object'} eq 'Host' ) {
	    if ( $import_data{$rec}{'Host name'} ) {
		if ( $hosts_vitals{'name'}{ $import_data{$rec}{'Host name'} } ) {
		    $sync_objs{$rec}{'name'} = $import_data{$rec}{'Host name'};
		    $sync_objs{$rec}{'id'}   = $hosts_vitals{'name'}{ $import_data{$rec}{'Host name'} };
		}
		else {
		    $results{'errors'}{$rec} = "Host \"$import_data{$rec}{'Host name'}\" not defined. Cannot sync non-existant host.";
		}
	    }
	    elsif ( $import_data{$rec}{'Address'} ) {
		if ( $hosts_vitals{'address'}{ $import_data{$rec}{'Address'} } ) {
		    $sync_objs{$rec}{'name'} = $import_data{$rec}{'Address'};
		    $sync_objs{$rec}{'id'}   = $hosts_vitals{'address'}{ $import_data{$rec}{'Address'} };
		}
		else {
		    $results{'errors'}{$rec} =
		      "Host with address \"$import_data{$rec}{'Address'}\" not defined. Cannot sync non-existant host.";
		}
	    }
	    elsif ( $import_data{$rec}{'Alias'} ) {
		if ( $hosts_vitals{'alias'}{ $import_data{$rec}{'Alias'} } ) {
		    $sync_objs{$rec}{'name'} = $import_data{$rec}{'Alias'};
		    $sync_objs{$rec}{'id'}   = $hosts_vitals{'alias'}{ $import_data{$rec}{'Alias'} };
		}
		else {
		    $results{'errors'}{$rec} = "Host with alias \"$import_data{$rec}{'Alias'}\" not defined. Cannot sync non-existant host.";
		}
	    }
	}
	elsif ( $schema{'sync_object'} eq 'Parent' ) {
	    foreach my $obj ( keys %{ $import_data{$rec}{'Parent'} } ) {
		if (   $hosts_vitals{'name'}{$obj}
		    || $hosts_vitals{'address'}{$obj}
		    || $hosts_vitals{'alias'}{$obj} )
		{
		    $sync_objs{$rec}{'name'} = $obj;
		    $sync_objs{$rec}{'id'}   = $import_data{$rec}{'Parent'}{$obj};
		}
		else {
		    $results{'errors'}{$rec} = "Parent \"$obj\" not defined. Cannot use non-existant parent as sync object.";
		}
	    }
	}
	elsif ( $schema{'sync_object'} eq 'Group' ) {
	    foreach my $obj ( keys %{ $import_data{$rec}{'Group'} } ) {
		$sync_objs{$rec}{'name'} = $obj;
		$sync_objs{$rec}{'id'}   = $import_data{$rec}{'Group'}{$obj};
	    }
	}
	elsif ( $schema{'sync_object'} eq 'Host group' ) {
	    foreach my $obj ( keys %{ $import_data{$rec}{'Host group'} } ) {
		$sync_objs{$rec}{'name'} = $obj;
		$sync_objs{$rec}{'id'}   = $import_data{$rec}{'Host group'}{$obj};
	    }
	}
	elsif ( $schema{'sync_object'} eq 'Contact group' ) {
	    foreach my $obj ( keys %{ $import_data{$rec}{'Contact group'} } ) {
		$sync_objs{$rec}{'name'} = $obj;
		$sync_objs{$rec}{'id'}   = $import_data{$rec}{'Contact group'}{$obj};
	    }
	}
    }

    # Clear existing associations before importing new ones
    foreach my $rec ( keys %import_data ) {
	unless ( $results{'errors'}{$rec} ) {
	    if ( $schema{'sync_object'} eq 'Host' ) {
		if ( $sync_objs{$rec}{'id'} ) {
		    if ( $import_data{$rec}{'Contact group'} ) {
			my %where = ( 'host_id' => $sync_objs{$rec}{'id'} );
			my $result = StorProc->delete_one_where( 'contactgroup_host', \%where );
			if ( $result =~ /error/i ) {
			    $results{'errors'}{$rec} = $result;
			}
		    }
		    if ( $import_data{$rec}{'Parent'} ) {
			my $result = StorProc->delete_all( 'host_parent', 'host_id', $sync_objs{$rec}{'id'} );
			if ( $result =~ /error/i ) {
			    $results{'errors'}{$rec} = $result;
			}
		    }
		    if ( $import_data{$rec}{'Group'} ) {
			my $result = StorProc->delete_all( 'monarch_group_host', 'host_id', $sync_objs{$rec}{'id'} );
			if ( $result =~ /error/i ) {
			    $results{'errors'}{$rec} = $result;
			}
		    }
		    if ( $import_data{$rec}{'Host group'} ) {
			my $result = StorProc->delete_all( 'hostgroup_host', 'host_id', $sync_objs{$rec}{'id'} );
			if ( $result =~ /error/i ) {
			    $results{'errors'}{$rec} = $result;
			}
		    }
		}
	    }
	    elsif ( $schema{'sync_object'} eq 'Parent' ) {
		my %processed = ();
		unless ( $processed{ $sync_objs{$rec}{'name'} } ) {
		    if (   $hosts_vitals{'name'}{ $sync_objs{$rec}{'name'} }
			|| $hosts_vitals{'address'}{ $sync_objs{$rec}{'name'} }
			|| $hosts_vitals{'alias'}{ $sync_objs{$rec}{'name'} } )
		    {
			my $result = StorProc->delete_all( 'host_parent', 'parent_id', $sync_objs{$rec}{'id'} );
			if ( $result =~ /error/i ) {
			    $results{'errors'}{$rec} = $result;
			}
			$processed{ $sync_objs{$rec}{'name'} } = 1;
		    }
		}
	    }
	    elsif ( $schema{'sync_object'} eq 'Group' ) {
		my %processed = ();
		if (   $import_data{$rec}{'Host name'}
		    || $import_data{$rec}{'Address'}
		    || $import_data{$rec}{'Alias'} )
		{
		    unless ( $processed{'host'}{ $sync_objs{$rec}{'name'} } ) {
			my $result = StorProc->delete_all( 'monarch_group_host', 'group_id', $sync_objs{$rec}{'id'} );
			if ( $result =~ /error/i ) {
			    $results{'errors'}{$rec} = $result;
			}
			$processed{'host'}{ $sync_objs{$rec}{'name'} } = 1;
		    }
		}
		if ( $import_data{$rec}{'Host group'} ) {
		    unless ( $processed{'hostgroup'}{ $sync_objs{$rec}{'name'} } ) {
			my $result = StorProc->delete_all( 'monarch_group_hostgroup', 'group_id', $sync_objs{$rec}{'id'} );
			if ( $result =~ /error/i ) {
			    $results{'errors'}{$rec} = $result;
			}
			$processed{'hostgroup'}{ $sync_objs{$rec}{'name'} } = 1;
		    }
		}
		if ( $import_data{$rec}{'Contact group'} ) {
		    unless ( $processed{'contactgroup'}{ $sync_objs{$rec}{'name'} } ) {
			my %where = ( 'group_id' => $sync_objs{$rec}{'id'} );
			my $result = StorProc->delete_one_where( 'contactgroup_group', \%where );
			if ( $result =~ /error/i ) {
			    $results{'errors'}{$rec} = $result;
			}
			$processed{'contactgroup'}{ $sync_objs{$rec}{'name'} } = 1;
		    }
		}
	    }
	    elsif ( $schema{'sync_object'} eq 'Host group' ) {
		my %processed = ();
		if (   $import_data{$rec}{'Host name'}
		    || $import_data{$rec}{'Address'}
		    || $import_data{$rec}{'Alias'} )
		{
		    unless ( $processed{'host'}{ $sync_objs{$rec}{'name'} } ) {
			my $result = StorProc->delete_all( 'hostgroup_host', 'hostgroup_id', $sync_objs{$rec}{'id'} );
			if ( $result =~ /error/i ) {
			    $results{'errors'}{$rec} = $result;
			}
			$processed{'host'}{ $sync_objs{$rec}{'name'} } = 1;
		    }
		}
		if ( $import_data{$rec}{'Contact group'} ) {
		    unless ( $processed{'contactgroup'}{ $sync_objs{$rec}{'name'} } ) {
			my %where = ( 'hostgroup_id' => $sync_objs{$rec}{'id'} );
			my $result = StorProc->delete_one_where( 'contactgroup_hostgroup', \%where );
			if ( $result =~ /error/i ) {
			    $results{'errors'}{$rec} = $result;
			}
			$processed{'contactgroup'}{ $sync_objs{$rec}{'name'} } = 1;
		    }
		}
		if ( $import_data{$rec}{'Group'} ) {
		    unless ( $processed{'group'}{ $sync_objs{$rec}{'name'} } ) {
			my $result = StorProc->delete_all( 'monarch_group_hostgroup', 'hostgroup_id', $sync_objs{$rec}{'id'} );
			if ( $result =~ /error/i ) {
			    $results{'errors'}{$rec} = $result;
			}
			$processed{'group'}{ $sync_objs{$rec}{'name'} } = 1;
		    }
		}
	    }
	    elsif ( $schema{'sync_object'} eq 'Contact group' ) {
		my %processed = ();
		if (   $import_data{$rec}{'Host name'}
		    || $import_data{$rec}{'Address'}
		    || $import_data{$rec}{'Alias'} )
		{
		    unless ( $processed{'hosts'}{ $sync_objs{$rec}{'name'} } ) {
			my %where = ( 'contactgroup_id' => $sync_objs{$rec}{'id'} );
			my $result = StorProc->delete_one_where( 'contactgroup_host', \%where );
			if ( $result =~ /error/i ) {
			    $results{'errors'}{$rec} = $result;
			}
			$processed{'hosts'}{ $sync_objs{$rec}{'name'} } = 1;
		    }
		}
		if ( $import_data{$rec}{'Group'} ) {
		    unless ( $processed{'group'}{ $sync_objs{$rec}{'name'} } ) {
			my %where = ( 'contactgroup_id' => $sync_objs{$rec}{'id'} );
			my $result = StorProc->delete_one_where( 'contactgroup_group', \%where );
			if ( $result =~ /error/i ) {
			    $results{'errors'}{$rec} = $result;
			}
			$processed{'group'}{ $sync_objs{$rec}{'name'} } = 1;
		    }
		}
		if ( $import_data{$rec}{'Host group'} ) {
		    unless ( $processed{'hostgroup'}{ $sync_objs{$rec}{'name'} } ) {
			my %where = ( 'contactgroup_id' => $sync_objs{$rec}{'id'} );
			my $result = StorProc->delete_one_where( 'contactgroup_hostgroup', \%where );
			if ( $result =~ /error/i ) {
			    $results{'errors'}{$rec} = $result;
			}
			$processed{'hostgroup'}{ $sync_objs{$rec}{'name'} } = 1;
		    }
		}
	    }
	}
    }

    # Importing new associations
    my %processed = ();
    foreach my $rec ( keys %import_data ) {
	unless ( $results{'errors'}{$rec} ) {

	    # Host
	    # A host name, address, or alias can be synced with parents, and/or monarch groups, and/or host groups, and/or contact groups.
	    if ( $schema{'sync_object'} eq 'Host' ) {
		if ( $sync_objs{$rec}{'id'} ) {
		    if ( $import_data{$rec}{'Parent'} ) {
			foreach my $parent ( keys %{ $import_data{$rec}{'Parent'} } ) {
			    if ( $hosts_vitals{'name'}{$parent} ) {
				unless ( $sync_objs{$rec}{'id'} eq $hosts_vitals{'name'}{$parent} ) {
				    my @values = ( $sync_objs{$rec}{'id'}, $hosts_vitals{'name'}{$parent} );
				    my $result = StorProc->insert_obj( 'host_parent', \@values );
				    if ( $result =~ /error/i ) {
					$results{'errors'}{$rec} = $result;
				    }
				}
			    }
			    else {
				$results{'errors'}{$rec} = "Parent host \"$parent\" does not exist";
			    }
			}
		    }
		    if ( $import_data{$rec}{'Group'} ) {
			foreach my $group ( keys %{ $import_data{$rec}{'Group'} } ) {
			    if ( $import_data{$rec}{'Group'}{$group} ) {
				my @values = ( $sync_objs{$rec}{'id'}, $import_data{$rec}{'Group'}{$group} );
				my $result = StorProc->insert_obj( 'monarch_group_host', \@values );
				if ( $result =~ /error/i ) {
				    $results{'errors'}{$rec} = $result;
				}
			    }
			}
		    }
		    if ( $import_data{$rec}{'Host group'} ) {
			foreach my $group ( keys %{ $import_data{$rec}{'Host group'} } ) {
			    if ( $import_data{$rec}{'Host group'}{$group} ) {
				my @values = ( $sync_objs{$rec}{'id'}, $import_data{$rec}{'Host group'}{$group} );
				my $result = StorProc->insert_obj( 'hostgroup_host', \@values );
				if ( $result =~ /error/i ) {
				    $results{'errors'}{$rec} = $result;
				}
			    }
			}
		    }
		    if ( $import_data{$rec}{'Contact group'} ) {
			foreach my $group ( keys %{ $import_data{$rec}{'Contact group'} } ) {
			    if ( $import_data{$rec}{'Contact group'}{$group} ) {
				my @values = ( $import_data{$rec}{'Contact group'}{$group}, $sync_objs{$rec}{'id'} );
				my $result = StorProc->insert_obj( 'contactgroup_host', \@values );
				if ( $result =~ /error/i ) {
				    $results{'errors'}{$rec} = $result;
				}
			    }
			}
		    }
		}
	    }

	    # Host group
	    # A host group can be synced with one of the three host attributes, and/or monarch groups, and/or contact groups
	    elsif ( $schema{'sync_object'} eq 'Host group' ) {
		if (   $import_data{$rec}{'Host name'}
		    || $import_data{$rec}{'Address'}
		    || $import_data{$rec}{'Alias'} )
		{
		    my $host_id = undef;
		    if ( $import_data{$rec}{'Host name'} ) {
			$host_id = $hosts_vitals{'name'}{ $import_data{$rec}{'Host name'} };
		    }
		    elsif ( $import_data{$rec}{'Address'} ) {
			$host_id = $hosts_vitals{'address'}{ $import_data{$rec}{'Address'} };
		    }
		    elsif ( $import_data{$rec}{'Alias'} ) {
			$host_id = $hosts_vitals{'alias'}{ $import_data{$rec}{'Alias'} };
		    }
		    my @values = ( $sync_objs{$rec}{'id'}, $host_id );
		    my $result = StorProc->insert_obj( 'hostgroup_host', \@values );
		    if ( $result =~ /error/i ) {
			$results{'errors'}{$rec} = $result;
		    }
		}
		if ( $import_data{$rec}{'Contact group'} ) {
		    foreach my $group ( keys %{ $import_data{$rec}{'Contact group'} } ) {
			if ( $import_data{$rec}{'Contact group'}{$group} ) {
			    my @values = ( $import_data{$rec}{'Contact group'}{$group}, $sync_objs{$rec}{'id'} );
			    my $result = StorProc->insert_obj( 'contactgroup_hostgroup', \@values );
			    if ( $result =~ /error/i ) {
				$results{'errors'}{$rec} = $result;
			    }
			}
		    }
		}
		if ( $import_data{$rec}{'Group'} ) {
		    foreach my $group ( keys %{ $import_data{$rec}{'Group'} } ) {
			if ( $import_data{$rec}{'Group'}{$group} ) {
			    my @values = ( $import_data{$rec}{'Group'}{$group}, $sync_objs{$rec}{'id'} );
			    my $result = StorProc->insert_obj( 'monarch_group_hostgroup', \@values );
			    if ( $result =~ /error/i ) {
				$results{'errors'}{$rec} = $result;
			    }
			}
		    }
		}
	    }

	    # Parent
	    # A parent host can be synced with one of the three host attributes
	    elsif ( $schema{'sync_object'} eq 'Parent' ) {
		if (   $import_data{$rec}{'Host name'}
		    || $import_data{$rec}{'Address'}
		    || $import_data{$rec}{'Alias'} )
		{
		    my $host_id = undef;
		    if ( $import_data{$rec}{'Host name'} ) {
			$host_id = $hosts_vitals{'name'}{ $import_data{$rec}{'Host name'} };
		    }
		    elsif ( $import_data{$rec}{'Address'} ) {
			$host_id = $hosts_vitals{'address'}{ $import_data{$rec}{'Address'} };
		    }
		    elsif ( $import_data{$rec}{'Alias'} ) {
			$host_id = $hosts_vitals{'alias'}{ $import_data{$rec}{'Alias'} };
		    }
		    if ($host_id) {
			unless ( $sync_objs{$rec}{'id'} eq $host_id ) {
			    my @values = ( $sync_objs{$rec}{'id'}, $host_id );
			    my $result = StorProc->insert_obj( 'host_parent', \@values );
			    if ( $result =~ /error/i ) {
				$results{'errors'}{$rec} = $result;
			    }
			}
		    }
		}
	    }

	    # Group
	    # A monarch group can be synced with one of the three host attributes, and/or host groups, and/or contact groups
	    elsif ( $schema{'sync_object'} eq 'Group' ) {
		if (   $import_data{$rec}{'Host name'}
		    || $import_data{$rec}{'Address'}
		    || $import_data{$rec}{'Alias'} )
		{
		    my $host_id    = undef;
		    my $host_value = undef;
		    if ( $import_data{$rec}{'Host name'} ) {
			$host_id    = $hosts_vitals{'name'}{ $import_data{$rec}{'Host name'} };
			$host_value = "host name $import_data{$rec}{'Host name'}";
		    }
		    elsif ( $import_data{$rec}{'Address'} ) {
			$host_id    = $hosts_vitals{'address'}{ $import_data{$rec}{'Address'} };
			$host_value = "host address $import_data{$rec}{'Address'}";
		    }
		    elsif ( $import_data{$rec}{'Alias'} ) {
			$host_id    = $hosts_vitals{'alias'}{ $import_data{$rec}{'Alias'} };
			$host_value = "host alias $import_data{$rec}{'Alias'}";
		    }
		    if ($host_id) {
			my @values = ( $sync_objs{$rec}{'id'}, $host_id );
			my $result = StorProc->insert_obj( 'monarch_group_host', \@values );
			if ( $result =~ /error/i ) {
			    $results{'errors'}{$rec} = $result;
			}
		    }
		    else {
			$results{'errors'}{$rec} = "Match not found: $host_value.";
		    }
		}
		if ( $import_data{$rec}{'Host group'} ) {
		    foreach my $group ( keys %{ $import_data{$rec}{'Host group'} } ) {
			if ( $import_data{$rec}{'Host group'}{$group} ) {
			    my @values = ( $sync_objs{$rec}{'id'}, $import_data{$rec}{'Host group'}{$group} );
			    my $result = StorProc->insert_obj( 'monarch_group_hostgroup', \@values );
			    if ( $result =~ /error/i ) {
				$results{'errors'}{$rec} = $result;
			    }
			}
		    }
		}
		if ( $import_data{$rec}{'Contact group'} ) {
		    foreach my $group ( keys %{ $import_data{$rec}{'Contact group'} } ) {
			if ( $import_data{$rec}{'Contact group'}{$group} ) {
			    my @values = ( $import_data{$rec}{'Contact group'}{$group}, $sync_objs{$rec}{'id'} );
			    my $result = StorProc->insert_obj( 'contactgroup_group', \@values );
			    if ( $result =~ /error/i ) {
				$results{'errors'}{$rec} = $result;
			    }
			}
		    }
		}
	    }

	    # Contact group
	    # A contact group can be synced with one of the three host attributes, and/or host groups, and/or monarch groups
	    elsif ( $schema{'sync_object'} eq 'Contact group' ) {
		if (   $import_data{$rec}{'Host name'}
		    || $import_data{$rec}{'Address'}
		    || $import_data{$rec}{'Alias'} )
		{
		    my $host_id    = undef;
		    my $host_value = undef;
		    if ( $import_data{$rec}{'Host name'} ) {
			$host_id    = $hosts_vitals{'name'}{ $import_data{$rec}{'Host name'} };
			$host_value = "host name $import_data{$rec}{'Host name'}";
		    }
		    elsif ( $import_data{$rec}{'Address'} ) {
			$host_id    = $hosts_vitals{'address'}{ $import_data{$rec}{'Address'} };
			$host_value = "host address $import_data{$rec}{'Address'}";
		    }
		    elsif ( $import_data{$rec}{'Alias'} ) {
			$host_id    = $hosts_vitals{'alias'}{ $import_data{$rec}{'Alias'} };
			$host_value = "host alias $import_data{$rec}{'Alias'}";
		    }
		    if ($host_id) {
			my @values = ( $sync_objs{$rec}{'id'}, $host_id );
			my $result = StorProc->insert_obj( 'contactgroup_host', \@values );
			if ( $result =~ /error/i ) {
			    $results{'errors'}{$rec} = $result;
			}
		    }
		    else {
			$results{'errors'}{$rec} = "Match not found: $host_value.";
		    }
		}
		if ( $import_data{$rec}{'Host group'} ) {
		    foreach my $group ( keys %{ $import_data{$rec}{'Host group'} } ) {
			if ( $import_data{$rec}{'Host group'}{$group} ) {
			    my @values = ( $sync_objs{$rec}{'id'}, $import_data{$rec}{'Host group'}{$group} );
			    my $result = StorProc->insert_obj( 'contactgroup_hostgroup', \@values );
			    if ( $result =~ /error/i ) {
				$results{'errors'}{$rec} = $result;
			    }
			}
		    }
		}
		if ( $import_data{$rec}{'Group'} ) {
		    foreach my $group ( keys %{ $import_data{$rec}{'Group'} } ) {
			if ( $import_data{$rec}{'Group'}{$group} ) {
			    my @values = ( $sync_objs{$rec}{'id'}, $import_data{$rec}{'Group'}{$group} );
			    my $result = StorProc->insert_obj( 'contactgroup_group', \@values );
			    if ( $result =~ /error/i ) {
				$results{'errors'}{$rec} = $result;
			    }
			}
		    }
		}
	    }
	    unless ( $results{'errors'}{$rec} ) {
		$results{'updated'}{ $import_data{$rec}{'Name'} } = 'host updated';
	    }
	}
    }

    # Return a hash of hashs describing what happened, with key = host name
    return %results;
}

sub discover_prep(@) {
    my %group   = %{ $_[1] };
    my %process = ();
    my @errors  = ();
    $process{'id'}                  = $group{'id'};
    $process{'name'}                = $group{'name'};
    $process{'description'}         = $group{'description'};
    $process{'auto'}                = $group{'auto'};
    $process{'schema'}              = $group{'schema'};
    $process{'enable_traceroute'}   = $group{'enable_traceroute'};
    $process{'traceroute_command'}  = $group{'traceroute_command'};
    $process{'traceroute_max_hops'} = $group{'traceroute_max_hops'};
    $process{'traceroute_timeout'}  = $group{'traceroute_timeout'};
    @{ $process{'nmaps'} }     = ();
    @{ $process{'udp_nmaps'} } = ();
    @{ $process{'snmps'} }     = ();
    @{ $process{'scripts'} }   = ();
    @{ $process{'wmis'} }      = ();

    # group filters

    my %global = ();
    foreach my $filter ( keys %{ $group{'filter'} } ) {
	my $type = $group{'filter'}{$filter}{'type'};
	my @hosts = split( /,/, $group{'filter'}{$filter}{'filter'} );
	foreach my $host_str (@hosts) {
	    if ( $host_str =~ m{^\s*(\d+)\.(\d+)\.(\d+)\.(\d+)/(\d+)\s*$} ) {
		if ($1 > 255 || $2 > 255 || $3 > 255 || $4 > 255) {
		    push @errors, "Error: IP address $1.$2.$3.$4 in range/filter \"$filter\" is invalid.";
		    last;
		}
		if ($5 < 16 || $5 > 32) {
		    push @errors, "Error: subnet prefix length /$5 in range/filter \"$filter\" is invalid (must be between /16 and /32 inclusive).";
		    last;
		}
		my $ip_base = unpack ('N', pack ('C4', $1, $2, $3, $4));
		my $prefix_len = $5;
		my $_32_bits = 0xffffffff;
		my $netmask = ($_32_bits << (32 - $prefix_len)) & $_32_bits;
		my $hostmask = $_32_bits ^ $netmask;
		my $network_addr   = $ip_base & $netmask;
		my $broadcast_addr = $ip_base | $hostmask;
		if ($ip_base & $hostmask) {
		    my ($b0, $b1, $b2, $b3) = unpack ('C4', pack ('N', $network_addr));
		    push @errors, "Error: illegal CIDR block in range/filter \"$filter\"; "
		      . "base address $1.$2.$3.$4 extends beyond subnet mask /$5 (network address $b0.$b1.$b2.$b3).";
		    last;
		}
		my $min_ip_addr = $network_addr;
		my $max_ip_addr = $broadcast_addr;
		if ($prefix_len <= 30) {
		    ++$min_ip_addr;
		    --$max_ip_addr;
		}
		for (my $host_dword = $min_ip_addr; $host_dword <= $max_ip_addr; ++$host_dword) {
		    my ($b0, $b1, $b2, $b3) = unpack ('C4', pack ('N', $host_dword));
		    $global{$type}{$host_dword} = "$b0.$b1.$b2.$b3";
		}
	    }
	    elsif ( $host_str =~ /^\s*(\d+)\.(\d+)\.(\d+)\.(\d+)\s*-\s*(\d+)\.(\d+)\.(\d+)\.(\d+)\s*$/ ) {
		if ($1 > 255 || $2 > 255 || $3 > 255 || $4 > 255) {
		    push @errors, "Error: IP address $1.$2.$3.$4 in range/filter \"$filter\" is invalid.";
		    last;
		}
		if ($5 > 255 || $6 > 255 || $7 > 255 || $8 > 255) {
		    push @errors, "Error: IP address $5.$6.$7.$8 in range/filter \"$filter\" is invalid.";
		    last;
		}
		if ( $1 != $5 || $2 != $6 ) {
		    ## the user has specified too wide an address range for our taste
		    push @errors, "Error: IP address range '$host_str' in range/filter \"$filter\" is too large; the first two octets much match in this kind of range.";
		    last;
		}
		my $i = $3;
		my $j = $4;
		while ( $i < $7 || ($i == $7 && $j <= $8) ) {
		    my $host_dword = ( ( $1 * 256 + $2 ) * 256 + $i ) * 256 + $j;
		    $global{$type}{$host_dword} = "$1.$2.$i.$j";
		    ## Note:  We intentionally include supposed network (.0) and broadcast (.255) addresses
		    ## in this counting, presuming that the user specified the range exactly as desired.
		    ## Those won't actually be network and broadcast addresses if this is a section of some
		    ## subnet (CIDR block) larger than a Class C subnet.  See RFC 1812 for address conventions.
		    ++$j;
		    if ($j > 255) {
			++$i;
			$j = 0;
		    }
		}
	    }
	    elsif ( $host_str =~ /^\s*(\d+)\.(\d+)\.(\d+)\.(\d+)\s*-\s*(\d+)\s*$/ ) {
		if ($1 > 255 || $2 > 255 || $3 > 255 || $4 > 255) {
		    push @errors, "Error: IP address $1.$2.$3.$4 in range/filter \"$filter\" is invalid.";
		    last;
		}
		if ($5 > 255) {
		    push @errors, "Error: IP address $1.$2.$3.$5 in range/filter \"$filter\" is invalid.";
		    last;
		}
		for ( my $j = $4 ; $j <= $5 ; $j++ ) {
		    my $host_dword = ( ( $1 * 256 + $2 ) * 256 + $3 ) * 256 + $j;
		    $global{$type}{$host_dword} = "$1.$2.$3.$j";
		}
	    }
	    elsif ( $host_str =~ /^\s*(\d+)\.(\d+)\.(\d+)\s*-\s*(\d+)\s*$/ ) {
		if ($1 > 255 || $2 > 255 || $3 > 255) {
		    push @errors, "Error: IP address range $1.$2.$3.* in range/filter \"$filter\" is invalid.";
		    last;
		}
		if ($4 > 255) {
		    push @errors, "Error: IP address range $1.$2.$4.* in range/filter \"$filter\" is invalid.";
		    last;
		}
		for ( my $i = $3 ; $i <= $4 ; $i++ ) {
		    for ( my $j = 1 ; $j < 255 ; $j++ ) {
			my $host_dword = ( ( $1 * 256 + $2 ) * 256 + $i ) * 256 + $j;
			$global{$type}{$host_dword} = "$1.$2.$i.$j";
		    }
		}
	    }
	    elsif ( $host_str =~ /^\s*(\d+)\.(\d+)\.(\d+)\.\*\s*$/ ) {
		if ($1 > 255 || $2 > 255 || $3 > 255) {
		    push @errors, "Error: IP address range $1.$2.$3.* in range/filter \"$filter\" is invalid.";
		    last;
		}
		for ( my $j = 1 ; $j < 255 ; $j++ ) {
		    my $host_dword = ( ( $1 * 256 + $2 ) * 256 + $3 ) * 256 + $j;
		    $global{$type}{$host_dword} = "$1.$2.$3.$j";
		}
	    }
	    elsif ( $host_str =~ /^\s*(\d+)\.(\d+)\.(\d+)\.(\d+)\s*$/ ) {
		if ($1 > 255 || $2 > 255 || $3 > 255 || $4 > 255) {
		    push @errors, "Error: IP address $1.$2.$3.$4 in range/filter \"$filter\" is invalid.";
		    last;
		}
		my $host_dword = ( ( $1 * 256 + $2 ) * 256 + $3 ) * 256 + $4;
		$global{$type}{$host_dword} = "$1.$2.$3.$4";
	    }
	    else {
		$global{$type}{$host_str} = $host_str;
	    }
	}
    }
    foreach my $method ( sort keys %{ $group{'method'} } ) {
	$process{'method'}{$method}{'description'} = $group{'method'}{$method}{'description'};
	if ( $group{'method'}{$method}{'type'} eq 'Nmap' ) {
	    $process{'method'}{$method}{'timeout'}        = $group{'method'}{$method}{'timeout'};
	    $process{'method'}{$method}{'scan_type'}      = $group{'method'}{$method}{'scan_type'};
	    $process{'method'}{$method}{'tcp_snmp_check'} = $group{'method'}{$method}{'tcp_snmp_check'};
	    $process{'method'}{$method}{'snmp_strings'}   = $group{'method'}{$method}{'snmp_strings'};
	    if ( $group{'method'}{$method}{'scan_type'} eq 'udp_scan' ) {
		push @{ $process{'udp_nmaps'} }, $method;
	    }
	    else {
		push @{ $process{'nmaps'} }, $method;
	    }

	    # ports
	    my %ports = ();
	    foreach my $port_definition ( keys %{ $group{'method'}{$method} } ) {
		if ( $port_definition =~ /^port_/ ) {
		    my $value = $group{'method'}{$method}{$port_definition};
		    $port_definition =~ s/^port_//;
		    $process{'method'}{$method}{'port_definition'}{$port_definition} = $value;
		    if ( $port_definition =~ /,/ ) {
			my @ports = split( /,/, $port_definition );
			foreach my $p (@ports) {
			    if ( $p =~ /(\d+)-(\d+)/ ) {
				for ( my $i = $1 ; $i <= $2 ; $i++ ) {
				    $ports{$i} = 1;
				}
			    }
			    else {
				$ports{$p} = 1;
			    }
			}
		    }
		    elsif ( $port_definition =~ /(\d+)-(\d+)/ ) {
			for ( my $i = $1 ; $i <= $2 ; $i++ ) {
			    $ports{$i} = 1;
			}
		    }
		    else {
			$ports{$port_definition} = 1;
		    }
		}
		$process{'method'}{$method}{'port_list'} = join(',', sort { $a cmp $b } keys %ports);
	    }
	}
	elsif ( $group{'method'}{$method}{'type'} eq 'SNMP' ) {
	    push @{ $process{'snmps'} }, $method;
	    $process{'method'}{$method}{'community_strings'} = $group{'method'}{$method}{'community_strings'};
	    $process{'method'}{$method}{'snmp_ver'}          = $group{'method'}{$method}{'snmp_ver'};
	}
	elsif ( $group{'method'}{$method}{'type'} eq 'WMI' ) {
	    push @{ $process{'wmis'} }, $method;
	}
	elsif ( $group{'method'}{$method}{'type'} eq 'Script' ) {
	    $process{'method'}{$method}{'run_mode'} = $group{'method'}{$method}{'run_mode'};
	    if ( $group{'method'}{$method}{'run_mode'} eq 'Batch Mode' ) {
		$group{'method'}{$method}{'command_line'} = 'batch:' . $group{'method'}{$method}{'command_line'}
		  unless ( $group{'method'}{$method}{'command_line'} =~ /^batch:/ );
	    }
	    $process{'method'}{$method}{'command_line'} = $group{'method'}{$method}{'command_line'};
	    push @{ $process{'scripts'} }, $method;
	}

	# method filters
	foreach my $filter ( keys %{ $group{'method'}{$method}{'filter'} } ) {
	    my $type = $group{'method'}{$method}{'filter'}{$filter}{'type'};
	    my @hosts = split( /,/, $group{'method'}{$method}{'filter'}{$filter}{'filter'} );
	    foreach my $host_str (@hosts) {
		if ( $host_str =~ m{^\s*(\d+)\.(\d+)\.(\d+)\.(\d+)/(\d+)\s*$} ) {
		    if ($1 > 255 || $2 > 255 || $3 > 255 || $4 > 255) {
			push @errors, "Error: IP address $1.$2.$3.$4 in range/filter \"$filter\" is invalid.";
			last;
		    }
		    if ($5 < 16 || $5 > 32) {
			push @errors, "Error: subnet prefix length /$5 in range/filter \"$filter\" is invalid (must be between /16 and /32 inclusive).";
			last;
		    }
		    my $ip_base = unpack ('N', pack ('C4', $1, $2, $3, $4));
		    my $prefix_len = $5;
		    my $_32_bits = 0xffffffff;
		    my $netmask = ($_32_bits << (32 - $prefix_len)) & $_32_bits;
		    my $hostmask = $_32_bits ^ $netmask;
		    my $network_addr   = $ip_base & $netmask;
		    my $broadcast_addr = $ip_base | $hostmask;
		    if ($ip_base & $hostmask) {
			my ($b0, $b1, $b2, $b3) = unpack ('C4', pack ('N', $network_addr));
			push @errors, "Error: illegal CIDR block in range/filter \"$filter\"; "
			  . "base address $1.$2.$3.$4 extends beyond subnet mask /$5 (network address $b0.$b1.$b2.$b3).";
			last;
		    }
		    my $min_ip_addr = $network_addr;
		    my $max_ip_addr = $broadcast_addr;
		    if ($prefix_len <= 30) {
			++$min_ip_addr;
			--$max_ip_addr;
		    }
		    for (my $host_dword = $min_ip_addr; $host_dword <= $max_ip_addr; ++$host_dword) {
			my ($b0, $b1, $b2, $b3) = unpack ('C4', pack ('N', $host_dword));
			$process{'method'}{$method}{'host'}{$type}{$host_dword} = "$b0.$b1.$b2.$b3";
		    }
		}
		elsif ( $host_str =~ /^\s*(\d+)\.(\d+)\.(\d+)\.(\d+)\s*-\s*(\d+)\.(\d+)\.(\d+)\.(\d+)\s*$/ ) {
		    if ($1 > 255 || $2 > 255 || $3 > 255 || $4 > 255) {
			push @errors, "Error: IP address $1.$2.$3.$4 in range/filter \"$filter\" is invalid.";
			last;
		    }
		    if ($5 > 255 || $6 > 255 || $7 > 255 || $8 > 255) {
			push @errors, "Error: IP address $5.$6.$7.$8 in range/filter \"$filter\" is invalid.";
			last;
		    }
		    if ( $1 != $5 || $2 != $6 ) {
			## the user has specified too wide an address range for our taste
			push @errors, "Error: IP address range '$host_str' in range/filter \"$filter\" is too large; the first two octets much match in this kind of range.";
			last;
		    }
		    my $i = $3;
		    my $j = $4;
		    while ( $i < $7 || ($i == $7 && $j <= $8) ) {
			my $host_dword = ( ( $1 * 256 + $2 ) * 256 + $i ) * 256 + $j;
			$process{'method'}{$method}{'host'}{$type}{$host_dword} = "$1.$2.$i.$j";
			## Note:  We intentionally include supposed network (.0) and broadcast (.255) addresses
			## in this counting, presuming that the user specified the range exactly as desired.
			## Those won't actually be network and broadcast addresses if this is a section of some
			## subnet (CIDR block) larger than a Class C subnet.  See RFC 1812 for address conventions.
			++$j;
			if ($j > 255) {
			    ++$i;
			    $j = 0;
			}
		    }
		}
		elsif ( $host_str =~ /^\s*(\d+)\.(\d+)\.(\d+)\.(\d+)\s*-\s*(\d+)\s*$/ ) {
		    if ($1 > 255 || $2 > 255 || $3 > 255 || $4 > 255) {
			push @errors, "Error: IP address $1.$2.$3.$4 in range/filter \"$filter\" is invalid.";
			last;
		    }
		    if ($5 > 255) {
			push @errors, "Error: IP address $1.$2.$3.$5 in range/filter \"$filter\" is invalid.";
			last;
		    }
		    for ( my $j = $4 ; $j <= $5 ; $j++ ) {
			my $host_dword = ( ( $1 * 256 + $2 ) * 256 + $3 ) * 256 + $j;
			$process{'method'}{$method}{'host'}{$type}{$host_dword} = "$1.$2.$3.$j";
		    }
		}
		elsif ( $host_str =~ /^\s*(\d+)\.(\d+)\.(\d+)\s*-\s*(\d+)\s*$/ ) {
		    if ($1 > 255 || $2 > 255 || $3 > 255) {
			push @errors, "Error: IP address range $1.$2.$3.* in range/filter \"$filter\" is invalid.";
			last;
		    }
		    if ($4 > 255) {
			push @errors, "Error: IP address range $1.$2.$4.* in range/filter \"$filter\" is invalid.";
			last;
		    }
		    for ( my $i = $3 ; $i <= $4 ; $i++ ) {
			for ( my $j = 1 ; $j < 255 ; $j++ ) {
			    my $host_dword = ( ( $1 * 256 + $2 ) * 256 + $i ) * 256 + $j;
			    $process{'method'}{$method}{'host'}{$type}{$host_dword} = "$1.$2.$i.$j";
			}
		    }
		}
		elsif ( $host_str =~ /^\s*(\d+)\.(\d+)\.(\d+)\.\*\s*$/ ) {
		    if ($1 > 255 || $2 > 255 || $3 > 255) {
			push @errors, "Error: IP address range $1.$2.$3.* in range/filter \"$filter\" is invalid.";
			last;
		    }
		    for ( my $j = 1 ; $j < 255 ; $j++ ) {
			my $host_dword = ( ( $1 * 256 + $2 ) * 256 + $3 ) * 256 + $j;
			$process{'method'}{$method}{'host'}{$type}{$host_dword} = "$1.$2.$3.$j";
		    }
		}
		elsif ( $host_str =~ /^\s*(\d+)\.(\d+)\.(\d+)\.(\d+)\s*$/ ) {
		    if ($1 > 255 || $2 > 255 || $3 > 255 || $4 > 255) {
			push @errors, "Error: IP address $1.$2.$3.$4 in range/filter \"$filter\" is invalid.";
			last;
		    }
		    my $host_dword = ( ( $1 * 256 + $2 ) * 256 + $3 ) * 256 + $4;
		    $process{'method'}{$method}{'host'}{$type}{$host_dword} = "$1.$2.$3.$4";
		}
		else {
		    ## FIX THIS:  why this difference?  is this just a bug?
		    if ( $group{'method'}{$method}{'filter'}{$filter}{'filter'} =~ /,/ ) {
			$process{'method'}{$method}{'host'}{$type}{$host_str} = $host_str;
		    }
		    else {
			$process{'method'}{$method}{'host'}{$type}{$filter} = $filter;
		    }
		}
	    }
	}

	# Apply group global filters to method
	foreach my $host ( keys %{ $global{'include'} } ) {
	    $process{'method'}{$method}{'host'}{'include'}{$host} = $global{'include'}{$host};
	}
	foreach my $host ( keys %{ $global{'exclude'} } ) {
	    delete $process{'method'}{$method}{'host'}{'include'}{$host};
	}

	# Consolidate local filters
	foreach my $host ( keys %{ $process{'method'}{$method}{'host'}{'exclude'} } ) {
	    delete $process{'method'}{$method}{'host'}{'include'}{$host};
	}
	$process{'method'}{$method}{'hosts'} = $process{'method'}{$method}{'host'}{'include'};
	delete $process{'method'}{$method}{'host'}{'include'};
	delete $process{'method'}{$method}{'host'}{'exclude'};
    }

    return \%process, \@errors;
}

# FIX THIS:  The use of a timestamp here as a cache buster is bogus,
# since we will only generate this URL once and the browser will use it
# multiple times to fetch Ajax data from the server.  And even if that
# were not true, a 1-second resolution of the timestamp is hardly enough
# to make this number guaranteed unique across successive hits.  This
# has to be replaced with proper cache control at the header level.  We
# need to likewise look for other attempts to perform cache busting and
# evaluate them for sensibility.
sub get_scan_url() {
    my $nocache = time;
    return "$monarch_cgi/monarch_discover.cgi?nocache=$nocache";
}

sub ajax_header(@) {
    return qq(
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html>
<head>
<title>Discovery</title>
<meta http-equiv="X-UA-Compatible" content="IE=edge">
<META HTTP-EQUIV="CONTENT-TYPE" CONTENT="text/html; charset=windows-1252">
<META HTTP-EQUIV="Pragma" CONTENT="no-cache">
<META HTTP-EQUIV="Expires" CONTENT="-1">
<link rel="stylesheet" type="text/css" href="$monarch_css/monarch.css">
<script type="text/javascript" language=javascript1.1 src="$monarch_js/monarch.js"></script>
</head>
<body bgcolor="#ffffff">);
}

sub nmap_header(@) {
    my %suggestions     = %{ $_[1] };
    my $scan_type       = $_[2];
    my $suggestion_list = undef;
    foreach my $suggestion ( sort keys %suggestions ) {
	$suggestion_list .= qq("$suggestion",);
    }
    chop $suggestion_list;
    $scan_type = '' if not defined $scan_type;
    return qq(
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html>
<head>
<title>Discovery</title>
<meta http-equiv="X-UA-Compatible" content="IE=edge">
<META HTTP-EQUIV="CONTENT-TYPE" CONTENT="text/html; charset=windows-1252">
<META HTTP-EQUIV="Pragma" CONTENT="no-cache">
<META HTTP-EQUIV="Expires" CONTENT="-1">
<link rel="stylesheet" type="text/css" href="$monarch_css/monarch.css">
<link rel="stylesheet" type="text/css" href="$monarch_css/autosuggest.css">
<script type="text/javascript" language=javascript1.1 src="$monarch_js/autosuggest2.js"></script>
<script type="text/javascript" language=JavaScript>
window.onload = function () {
	var oTextbox = new AutoSuggestControl(document.getElementById("value"), new StateSuggestions());
	var scan_type = "$scan_type";
	setScanOpts(scan_type);
}
function StateSuggestions() {
    this.states = [ $suggestion_list ];
}

function setScanOpts(scan) {
	if (scan == 'udp_scan') {
		document.form.tcp_snmp_check.disabled = true;
		document.form.tcp_snmp_check.className = 'disabled';
		document.form.snmp_strings.disabled = true;
		document.form.snmp_strings.className = 'disabled';
	} else {
		document.form.snmp_strings.disabled = false;
		document.form.snmp_strings.className = 'enabled';
		document.form.tcp_snmp_check.disabled = false;
		document.form.tcp_snmp_check.className = 'enabled';
	}
}

StateSuggestions.prototype.requestSuggestions = function (oAutoSuggestControl /*:AutoSuggestControl*/,bTypeAhead /*:boolean*/) {
    var aSuggestions = [];
    var sTextboxValue = oAutoSuggestControl.textbox.value;

    if (sTextboxValue.length > 0){

	//search for matching states
	for (var i=0; i < this.states.length; i++) {
	    if (this.states[i].indexOf(sTextboxValue) == 0) {
		aSuggestions.push(this.states[i]);
	    }
	}
    }

    //provide suggestions to the control
    oAutoSuggestControl.autosuggest(aSuggestions, bTypeAhead);
};


</script>
</head>
<body bgcolor="#ffffff">);
}

sub discover_form(@) {
    my $name           = $_[1];
    my %process        = %{ $_[2] };
    my $import_file    = $_[3];
    my $monarch_home   = $_[4];
    my $user_name      = $_[5];
    my %methods_js     = ();
    my $port_defs_str  = '';
    my $ports_str      = '';
    my $snmp_match_str = '';
    my $tcp_snmp_opt   = '';
    my $snmp_commands  = '';
    my $traceroute     = '';
    if ( $process{'enable_traceroute'} ) {
	$traceroute = "$process{'traceroute_command'}";
	$traceroute .= " -m $process{'traceroute_max_hops'}" if $process{'traceroute_max_hops'};
	$traceroute .= " -w $process{'traceroute_timeout'}"  if $process{'traceroute_timeout'};
    }
    my $traceroute_opt = ", 'traceroute'";
    my $input_tags     = qq(
<input type=hidden id=user_name name=user_name value="$user_name">
<input type=hidden id=traceroute name=traceroute value="$traceroute">
<input type=hidden id=backup name=backup value="backup">
<input type=hidden id=schema name=automation_name value="$process{'schema'}">
<input type=hidden id=automation_type name=automation_type value="$process{'auto'}">
<input type=hidden id=file name=file value="$import_file">
<input type=hidden id=monarch_home name=monarch_home value="$monarch_home">);
    my $method_cnt   = keys %{ $process{'method'} };
    my $nmap_enabled = 0;
    my $i            = $method_cnt;
    if ( $process{'auto'} =~ /Auto/ ) { $i++ }
    if ( $process{'auto'} eq 'Auto-Commit' ) { $i++ }
    $i--;
    my $method_id = 1;

    ## Nmap
    foreach my $method ( @{ $process{'nmaps'} } ) {
	$nmap_enabled = 1;
	$input_tags .= qq(
<input type=hidden id=method_id_$method_id name=method_id_$method_id value="$method_id">
<input type=hidden id=type_$method_id name=type_$method_id value="nmap">
<input type=hidden id=scan_type_$method_id name=scan_type_$method_id value="$process{'method'}{$method}{'scan_type'}">
<input type=hidden id=timeout_$method_id name=timeout_$method_id value="$process{'method'}{$method}{'timeout'}">);
	my $host_cnt = keys %{ $process{'method'}{$method}{'hosts'} };
	$methods_js{$method}{'vars'} .= qq(
methods[$i] = $method_id;
var hosts_$method_id = new Array($host_cnt););
	my $j = $host_cnt;
	$j--;

	foreach my $host ( sort keys %{ $process{'method'}{$method}{'hosts'} } ) {
	    my $message_ele = 'hosts_' . $method_id . '[' . $j . ']';
	    $methods_js{$method}{'hosts'} .= qq(
$message_ele="$process{'method'}{$method}{'hosts'}{$host}";);
	    $input_tags .= qq(
<input type=hidden id="$process{'method'}{$method}{'hosts'}{$host}" name=$host value="$process{'method'}{$method}{'hosts'}{$host}">);
	    $j--;
	}
	my $port_defs = undef;
	foreach my $port_def ( keys %{ $process{'method'}{$method}{'port_definition'} } ) {
	    $port_defs .= qq(port_def_$method_id\_$port_def=$process{'method'}{$method}{'port_definition'}{$port_def}:-:);
	}
	$port_defs =~ s/:-:$//;
	############################################################################
	# An evil IE limitation forced this wasteful kludge
	############################################################################
	#	$port_defs = uri_escape($port_defs);
	$port_defs_str .= "#port_def_$method_id:-:$port_defs\n";

	#	$input_tags .= qq(
	# <input type=hidden id=port_def_$method_id name=port_def_$method_id value="$port_defs">);
	$ports_str .= "#ports_$method_id:-:$process{'method'}{$method}{'port_list'}\n";

	#	$input_tags .= qq(
	# <input type=hidden id=ports_$method_id name=ports_$method_id value="$portlist">);name="snmp_strings"><!
	$snmp_match_str .= "#snmp_match_strings:-:$process{'method'}{$method}{'snmp_strings'}\n";
	$tcp_snmp_opt   .= "#tcp_snmp_opt_$method_id:-:$process{'method'}{$method}{'tcp_snmp_check'}\n";

	$methods_js{$method}{'main'} .= qq(
		} else if (method == "$method_id") {
			document.getElementById("method_status").innerHTML = "$method";
			var type = "type_$method_id";
			var scan_type = "scan_type_$method_id";
			var timeout = "timeout_$method_id";
			var method_id = "method_id_$method_id";
			var port_defs = "port_def_$method_id";
			var host = hosts_$method_id.pop();
			if (host) {
				document.getElementById("status").innerHTML = 'Scanning: ' + host + ' ...';
				get_host( [ host, type, 'file', 'monarch_home', scan_type, timeout, method_id$traceroute_opt ], [ addRow ] );
			} else {
				document.getElementById("status").innerHTML = "Method $method complete";
				method = undefined;
				process_methods();
			});

	$i--;
	$method_id++;
	$traceroute_opt = '';
    }

    ## UDP NMAP
    foreach my $method ( @{ $process{'udp_nmaps'} } ) {
	my $port_defs = undef;
	foreach my $port_def ( keys %{ $process{'method'}{$method}{'port_definition'} } ) {
	    $port_defs .= qq(port_def_$method_id\_$port_def=$process{'method'}{$method}{'port_definition'}{$port_def}:-:);
	}
	$port_defs =~ s/:-:$//;
	$port_defs_str .= "#port_def_$method_id:-:$port_defs\n";
	$ports_str     .= "#ports_$method_id:-:$process{'method'}{$method}{'port_list'}\n";
	if ($nmap_enabled) {
	    $input_tags .= qq(
<input type=hidden id=input_0_$method_id name=input_0_$method_id value="$method_id">
<input type=hidden id=method_id_$method_id name=method_id_$method_id value="$method_id">
<input type=hidden id=type_$method_id name=type_$method_id value="nmap_udp">
<input type=hidden id=scan_type_$method_id name=scan_type_$method_id value="$process{'method'}{$method}{'scan_type'}">
<input type=hidden id=timeout_$method_id name=timeout_$method_id value="$process{'method'}{$method}{'timeout'}">);
	    $methods_js{$method}{'vars'} .= qq(
methods[$i] = $method_id;);

	    $methods_js{$method}{'main'} .= qq(
		} else if (method == "$method_id") {
// alert('debug ' + method_complete);
			document.getElementById("method_status").innerHTML = "$method";
			var type = "type_$method_id";
			var scan_type = "scan_type_$method_id";
			var timeout = "timeout_$method_id";
			var method_id = "method_id_$method_id";
			var input_0 = "input_0_$method_id";
			if (method_complete) {
				document.getElementById("status").innerHTML = "Method $method complete";
				method = undefined;
				method_complete = '';
				process_methods();
			} else {
				document.getElementById("status").innerHTML = 'Running UDP scans ...';
				get_host( [ input_0, type, 'file', 'monarch_home', scan_type, timeout, method_id$traceroute_opt ], [ addRow ] );
// alert('debug after' + method_complete);
			});
	}
	else {
	    $nmap_enabled = 1;
	    $input_tags .= qq(
<input type=hidden id=method_id_$method_id name=method_id_$method_id value="$method_id">
<input type=hidden id=type_$method_id name=type_$method_id value="nmap">
<input type=hidden id=scan_type_$method_id name=scan_type_$method_id value="$process{'method'}{$method}{'scan_type'}">
<input type=hidden id=timeout_$method_id name=timeout_$method_id value="$process{'method'}{$method}{'timeout'}">);
	    my $host_cnt = keys %{ $process{'method'}{$method}{'hosts'} };
	    $methods_js{$method}{'vars'} .= qq(
methods[$i] = $method_id;
var hosts_$method_id = new Array($host_cnt););
	    my $j = $host_cnt;
	    $j--;

	    foreach my $host ( sort keys %{ $process{'method'}{$method}{'hosts'} } ) {
		my $message_ele = 'hosts_' . $method_id . '[' . $j . ']';
		$methods_js{$method}{'hosts'} .= qq(
$message_ele="$process{'method'}{$method}{'hosts'}{$host}";);
		$input_tags .= qq(
<input type=hidden id="$process{'method'}{$method}{'hosts'}{$host}" name=$host value="$process{'method'}{$method}{'hosts'}{$host}">);
		$j--;
	    }

	    my $port_defs = undef;
	    foreach my $port_def ( keys %{ $process{'method'}{$method}{'port_definition'} } ) {
		$port_defs .= qq(port_def_$method_id\_$port_def=$process{'method'}{$method}{'port_definition'}{$port_def}:-:);
	    }

	    $port_defs =~ s/:-:$//;
	    $port_defs_str  .= "#port_def_$method_id:-:$port_defs\n";
	    $ports_str      .= "#ports_$method_id:-:$process{'method'}{$method}{'port_list'}\n";
	    $snmp_match_str .= "#snmp_match_strings:-:$process{'method'}{$method}{'snmp_strings'}\n";

	    $methods_js{$method}{'main'} .= qq(
		} else if (method == "$method_id") {
			document.getElementById("method_status").innerHTML = "$method";
			var type = "type_$method_id";
			var scan_type = "scan_type_$method_id";
			var timeout = "timeout_$method_id";
			var method_id = "method_id_$method_id";
			var host = hosts_$method_id.pop();
			if (host) {
				document.getElementById("status").innerHTML = 'Scanning: ' + host + ' ...';
				get_host( [ host, type, 'file', 'monarch_home', scan_type, timeout, method_id$traceroute_opt ], [ addRow ] );
			} else {
				document.getElementById("status").innerHTML = "Method $method complete";
				method = undefined;
				process_methods();
			});
	}
	$i--;
	$method_id++;
	$traceroute_opt = '';
    }

    ## SNMP
    foreach my $method ( @{ $process{'snmps'} } ) {
	my $snmp_command = '';
	if ( $process{'method'}{$method}{'snmp_ver'} eq '3' ) {
	    $snmp_command .= "#snmp_command_$method_id:-:-u $process{'method'}{$method}{'snmp_v3_user'}";
	    unless ( $process{'method'}{$method}{'snmp_v3_authProtocol'} eq 'none' ) {
		$snmp_command .= " -a $process{'method'}{$method}{'snmp_v3_authProtocol'}";
		$snmp_command .= " -A $process{'method'}{$method}{'snmp_v3_authKey'}" if defined $process{'method'}{$method}{'snmp_v3_authKey'};
	    }
	    unless ( $process{'method'}{$method}{'snmp_v3_privProtocol'} eq 'none' ) {
		$snmp_command .= " -x $process{'method'}{$method}{'snmp_v3_privProtocol'}";
		$snmp_command .= " -X $process{'method'}{$method}{'snmp_v3_privKey'}" if defined $process{'method'}{$method}{'snmp_v3_privKey'};
	    }
	    if ( $process{'method'}{$method}{'snmp_v3_misc'} ) {
		$snmp_command .= " $process{'method'}{$method}{'snmp_v3_misc'}";
	    }
	    $snmp_command .= " -l $process{'method'}{$method}{'snmp_v3_securityLevel'}\n";
	}
	$snmp_commands = $snmp_command;
	$methods_js{$method}{'vars'} .= qq(
methods[$i] = $method_id;);
	$input_tags .= qq(
<input type=hidden id=snmp_command_$method_id name=snmp_command_$method_id value="$snmp_command">
<input type=hidden id=snmp_ver_$method_id name=snmp_ver_$method_id value="$process{'method'}{$method}{'snmp_ver'}">
<input type=hidden id=community_strings_$method_id name=community_strings_$method_id value="$process{'method'}{$method}{'community_strings'}">);

	## NMAP SNMP
	if ($nmap_enabled) {
	    $input_tags .= qq(
<input type=hidden id=input_0_$method_id name=input_0_$method_id value="$method_id">
<input type=hidden id=type_$method_id name=type_$method_id value="nmap_snmp">);

	    $methods_js{$method}{'main'} .= qq(
		} else if (method == "$method_id") {
			document.getElementById("method_status").innerHTML = "$method";
			var type = "type_$method_id";
			var command = "snmp_command_$method_id";
			var community_strings = "community_strings_$method_id";
			var input_0 = "input_0_$method_id";
			var snmp_ver = "snmp_ver_$method_id";
			if (method_complete) {
				document.getElementById("status").innerHTML = "Method $method complete";
				method = undefined;
				method_complete = '';
				process_methods();
			} else {
				if (host) {
					document.getElementById("status").innerHTML = 'Scanning' + host + ' ...';
				} else {
					document.getElementById("status").innerHTML = 'Running SNMP scans ...';
				}
				get_host( [ input_0, type, 'file', 'monarch_home', community_strings, command, snmp_ver ], [ addRow ] );
			});
	}

	## SOLO SNMP
	else {
	    $input_tags .= qq(
<input type=hidden id=snmp_command_$method_id name=snmp_command_$method_id value="$snmp_command">);

	    my $host_cnt = keys %{ $process{'method'}{$method}{'hosts'} };
	    $methods_js{$method}{'vars'} .= qq(
var hosts_$method_id = new Array($host_cnt););
	    my $j = $host_cnt;
	    $j--;
	    foreach my $host ( sort keys %{ $process{'method'}{$method}{'hosts'} } ) {
		my $message_ele = 'hosts_' . $method_id . '[' . $j . ']';
		$methods_js{$method}{'hosts'} .= qq(
$message_ele="$process{'method'}{$method}{'hosts'}{$host}";);
		$input_tags .= qq(
<input type=hidden id="$process{'method'}{$method}{'hosts'}{$host}" name=$host value="$process{'method'}{$method}{'hosts'}{$host}">);
		$j--;
	    }
	    $methods_js{$method}{'main'} .= qq(
		} else if (method == "$method_id") {);
	    $methods_js{$method}{'main'} .= qq(
		document.getElementById("method_status").innerHTML = "$method";);
	    $input_tags .= qq(
<input type=hidden id=type_$method_id name=type_$method_id value="snmp">);
	    $methods_js{$method}{'main'} .= qq(
			var type = "type_$method_id";
			var command = "snmp_command_$method_id";
			var community_strings = "community_strings_$method_id";
			var host = hosts_$method_id.pop();
			var snmp_ver = "snmp_ver_$method_id";
			if (host == undefined) {
				document.getElementById("status").innerHTML = "Method $method complete";
				method = undefined;
				process_methods();
			} else {
				document.getElementById("status").innerHTML = 'Scanning: ' + host + ' ...';
				get_host( [ host, type, 'file', 'monarch_home', community_strings, command, snmp_ver$traceroute_opt ], [ addRow ] );
			});
	}
	$i--;
	$method_id++;
	$traceroute_opt = '';
    }

    ## Scripts
    foreach my $method ( @{ $process{'scripts'} } ) {
	$methods_js{$method}{'vars'} .= qq(
methods[$i] = $method_id;);
	$input_tags .= qq(
<input type=hidden id=script_$method_id name=script_$method_id value="$process{'method'}{$method}{'command_line'}">);

	##### NMAP Scripts
	if (   $nmap_enabled
	    && $process{'method'}{$method}{'run_mode'} ne 'Batch Mode' )
	{
	    $input_tags .= qq(
<input type=hidden id=input_0_$method_id name=input_0_$method_id value="$method_id">
<input type=hidden id=type_$method_id name=type_$method_id value="nmap_script">);

	    $methods_js{$method}{'main'} .= qq(
		} else if (method == "$method_id") {
			document.getElementById("method_status").innerHTML = "$method";
			var type = "type_$method_id";
			var command = "script_$method_id";
			var input_0 = "input_0_$method_id";
			if (method_complete) {
				document.getElementById("status").innerHTML = "Method $method complete";
				method = undefined;
				method_complete = '';
				process_methods();
			} else {
				if (host) {
					document.getElementById("status").innerHTML = 'Scanning' + host + ' ...';
				} else {
					document.getElementById("status").innerHTML = 'Running script scans ...';
				}
				get_host( [ input_0, type, 'file', 'monarch_home', command ], [ addRow ] );
			});

	}
	## Scripts that run over each host in range, regardless of Nmap output
	elsif ( !$nmap_enabled && $process{'method'}{$method}{'run_mode'} ne 'Batch Mode' ) {
	    $input_tags .= qq(
<input type=hidden id=type_$method_id name=type_$method_id value="script">);

	    my $host_cnt = keys %{ $process{'method'}{$method}{'hosts'} };
	    $methods_js{$method}{'vars'} .= qq(
var hosts_$method_id = new Array($host_cnt););
	    my $j = $host_cnt;
	    $j--;
	    foreach my $host ( sort keys %{ $process{'method'}{$method}{'hosts'} } ) {
		my $message_ele = 'hosts_' . $method_id . '[' . $j . ']';
		$methods_js{$method}{'hosts'} .= qq(
$message_ele="$process{'method'}{$method}{'hosts'}{$host}";);
		$input_tags .= qq(
<input type=hidden id="$process{'method'}{$method}{'hosts'}{$host}" name=$host value="$process{'method'}{$method}{'hosts'}{$host}">);
		$j--;
	    }
	    $methods_js{$method}{'main'} .= qq(
		} else if (method == "$method_id") {
			document.getElementById("method_status").innerHTML = "$method";
			var type = "type_$method_id";
			var command = "script_$method_id";
			var host = hosts_$method_id.pop();
			if (host == undefined) {
				document.getElementById("status").innerHTML = "Method $method complete";
				method = undefined;
				process_methods();
			} else {
				document.getElementById("status").innerHTML = 'Scanning: ' + host + ' ...';
				get_host( [ host, type, 'file', 'monarch_home', command ], [ addRow ] );
			});
	}
	## Scripts that run only once (aka SOLO (??) scripts)
	else {
	    $input_tags .= qq(
<input type=hidden id=type_$method_id name=type_$method_id value="script">);
	    $methods_js{$method}{'vars'} .= qq(
var hosts_$method_id = new Array(1););
	    $methods_js{$method}{'hosts'} = "hosts_$method_id" . "[0]=\"batch\";";
	    $input_tags .=
		"<input type=hidden id=\""
	      . $process{'method'}{$method}{'hosts'}{'batch'}
	      . "\" name=batch value=\"$process{'method'}{$method}{'hosts'}{'batch'}\">";
	    $methods_js{$method}{'main'} .= qq(
		} else if (method == "$method_id") {
			document.getElementById("method_status").innerHTML = "$method";
			var type = "type_$method_id";
			var command = "script_$method_id";
			var host = hosts_$method_id.pop();
			if (host == undefined) {
				document.getElementById("status").innerHTML = "Method $method complete";
				method = undefined;
				process_methods();
			} else {
				document.getElementById("status").innerHTML = 'Scanning: ' + host + ' ...';
				get_host( [ host, type, 'file', 'monarch_home', command ], [ addRow ] );
			});
	}

	$i--;
	$method_id++;
    }

    ## WMI
    foreach my $method ( @{ $process{'wmis'} } ) {
	$methods_js{$method}{'vars'} .= qq(
methods[$i] = $method_id;);
	unless ($nmap_enabled) {
	    my $host_cnt = keys %{ $process{'method'}{$method}{'hosts'} };
	    $methods_js{$method}{'vars'} .= qq(
var hosts_$method_id = new Array($host_cnt););
	    my $j = $host_cnt;
	    $j--;
	    foreach my $host ( sort keys %{ $process{'method'}{$method}{'hosts'} } ) {
		my $message_ele = 'hosts_' . $method_id . '[' . $j . ']';
		$methods_js{$method}{'hosts'} .= qq(
$message_ele="$process{'method'}{$method}{'hosts'}{$host}";);
		$input_tags .= qq(
<input type=hidden id="$process{'method'}{$method}{'hosts'}{$host}" name=$host value="$process{'method'}{$method}{'hosts'}{$host}">);
		$j--;
	    }
	}
	$methods_js{$method}{'main'} .= qq(
	} else if (method == "$method_id") {
		document.getElementById("method_status").innerHTML = "$method";);
	if ($nmap_enabled) {
	    $input_tags .= qq(
<input type=hidden id=type_$method_id name=type_$method_id value="wmi_nmap">);
	    $methods_js{$method}{'main'} .= qq(
		var type = "type_$method_id";
		get_host( [ host, type, 'file', 'monarch_home', community_strings ], [ addRow ] );
		method = undefined;
		process_methods(););
	}
	else {
	    $input_tags .= qq(
<input type=hidden id=type_$method_id name=type_$method_id value="wmi">);
	    $methods_js{$method}{'main'} .= qq(
		var type = "wmi";
		var host = hosts_$method_id.pop();
		if (host == undefined) {
			document.getElementById("status").innerHTML = "Method $method complete";
			method = undefined;
			process_methods();
		} else {
			document.getElementById("status").innerHTML = host + ' ...';
			get_host( [ host, type, 'file', 'monarch_home' ], [ addRow ] );
		});
	}

	$i--;
	$method_id++;
    }

    ## Auto import
    if ( $process{'auto'} eq 'Auto' ) {
	$input_tags .= qq(
<input type=hidden id=import_hosts name=import_hosts value="import_hosts">
<input type=hidden id=import_schema name=import_schema value="$process{'schema'}">);
    }

    ## Auto commit
    if ( $process{'auto'} eq 'Auto-Commit' ) {
	$input_tags .= qq(
<input type=hidden id=import_hosts name=import_hosts value="import_hosts">
<input type=hidden id=import_schema name=import_schema value="$process{'schema'}">
<input type=hidden id=preflight_files name=preflight_files value="preflight_files">
<input type=hidden id=preflight name=preflight value="preflight">
<input type=hidden id=commit_files name=commit_files value="commit_files">
<input type=hidden id=commit_sync name=commit_sync value="commit_sync">);
    }

    my $javascript_hosts = '';
    my $javascript_main  = '';
    my $javascript_vars  = '';
    foreach my $method ( keys %methods_js ) {
	$javascript_hosts .= $methods_js{$method}{'hosts'} if defined $methods_js{$method}{'hosts'};
    }
    foreach my $method ( keys %methods_js ) {
	$javascript_main .= $methods_js{$method}{'main'};
    }
    foreach my $method ( keys %methods_js ) {
	$javascript_vars .= $methods_js{$method}{'vars'};
    }

    # FIX MINOR:  SafeAddOnload(process_methods); probably isn't doing anything, because it's called
    # before the function is defined; should the call be moved after the function, or just deleted?
    my $javascript = qq(
<script type="text/javascript" language=JavaScript>
SafeAddOnload(process_methods);
var automation_type = "$process{'auto'}";
var method;
var abort;
var backup_complete;
var import_complete;
var method_complete;
var preflight_files;
var preflight;
var commit_files;
var commit_sync;
var methods = new Array($method_cnt);
$javascript_vars
$javascript_hosts
var ii = 1;
function process_methods() {
	ii++;
	if (abort) {
		document.getElementById("method_status").innerHTML = "Aborted";
		document.getElementById("status").innerHTML = "Discovery process aborted.";
	} else {
		if (method == undefined) {
			method = methods.pop();
		}
//		alert('debug ' + ii + ' ' + automation_type + ' ' + method);
		if (method == undefined) {
//			alert(automation_type);
			if (automation_type == 'Interactive') {
				if (backup_complete) {
					document.getElementById("status").innerHTML = '<b>Discovery stage has completed. Select "Next >>" to process records.</b>';
					document.form.manual_process.className = 'submitbutton';
					document.form.manual_process.disabled = false;
				} else {
					document.getElementById("method_status").innerHTML = "All methods have completed";
					document.getElementById("status").innerHTML = "Discovery has completed. Backing up configuration ...";
					backup_complete = 'true';
					get_host( [ 'automation_type', 'backup', 'file', 'monarch_home', 'user_name' ], [ addRow ] );
				}
			} else if (automation_type == 'Auto') {
				if (import_complete) {
					document.getElementById("status").innerHTML = '<b>All records processed. Select "Commit" to activate changes or go to Configuration to review before commiting.</b>';
					document.form.commit.className = 'submitbutton';
					document.form.commit.disabled = false;
					document.form.cancel_discovery.value = 'Close';
				} else if (backup_complete) {
					document.getElementById("status").innerHTML = "Backup of configuration has completed. Processing records ...";
					import_complete = 'true';
					get_host( [ 'automation_type', 'import_hosts', 'file', 'monarch_home', 'schema' ], [ addRow ] );
				} else {
					document.getElementById("status").innerHTML = "Discovery has completed. Backing up configuration ...";
					backup_complete = 'true';
					get_host( [ 'automation_type', 'backup', 'file', 'monarch_home', 'user_name' ], [ addRow ] );
				}
			} else if (automation_type == 'Auto-Commit') {
				if (commit_sync) {
					document.getElementById("status").innerHTML = "<b>Discovery process has completed. Go to Status to review changes.</b>";
					document.form.cancel_discovery.value = 'Close';
				} else if (commit_files) {
					document.getElementById("status").innerHTML = "Production files created. Committing changes ...";
					commit_sync = 'true';
					get_host( [ 'automation_type', 'commit_sync', 'file', 'monarch_home', 'user_name' ], [ addRow ] );
				} else if (preflight) {
					document.getElementById("status").innerHTML = "Pre-flight check completed. Generating production files ...";
					commit_files = 'true';
					get_host( [ 'automation_type', 'commit_files', 'file', 'monarch_home', 'user_name' ], [ addRow ] );
				} else if (preflight_files) {
					document.getElementById("status").innerHTML = "Files for pre-flight check generated. Running pre-flight check ...";
					preflight = 'true';
					get_host( [ 'automation_type', 'preflight', 'file', 'monarch_home' ], [ addRow ] );
				} else if (import_complete) {
					document.getElementById("status").innerHTML = "All records processed. Generating files for pre-flight check ...";
					preflight_files = 'true';
					get_host( [ 'automation_type', 'preflight_files', 'file', 'monarch_home', 'user_name' ], [ addRow ] );
				} else if (backup_complete) {
					document.getElementById("status").innerHTML = "Backup of configuration has completed. Processing records ...";
					import_complete = 'true';
					get_host( [ 'automation_type', 'import_hosts', 'file', 'monarch_home', 'schema' ], [ addRow ] );
				} else {
					document.getElementById("status").innerHTML = "Discovery has completed. Backing up configuration ...";
					backup_complete = 'true';
					get_host( [ 'automation_type', 'backup', 'file', 'monarch_home', 'user_name' ], [ addRow ] );
				}
			}
$javascript_main
		}
	}
}

function addRow() {
	var entries = arguments[0].split('::');
// alert('debug ret ' + arguments[0]);

	for(i=0; i<entries.length; i++) {
		if (entries[i]) {
			var args = entries[i].split('|');
			if (args[0] == 'error') {
				var tbody = document.getElementById("reportTable").getElementsByTagName("tbody")[0];
				var row = document.createElement("tr");
				var td1 = document.createElement("td");
				td1.className = 'discover_error';
				td1.style.paddingLeft  = '0.5em';
				td1.style.paddingRight = '0.5em';
				td1.vAlign = 'top';
				td1.appendChild(document.createTextNode(args[1]));
				var td2 = document.createElement("td");
				td2.className = 'discover_error';
				td2.style.paddingLeft  = '0.5em';
				td2.style.paddingRight = '0.5em';
				td2.vAlign = 'top';
				td2.appendChild(document.createTextNode(args[0]));
				var td3 = document.createElement("td");
				td3.className = 'discover_error';
				td3.colSpan = 3;
				td3.style.paddingLeft  = '0.5em';
				td3.style.paddingRight = '0.5em';
				td3.vAlign = 'top';
				td3.appendChild(document.createTextNode(args[2]));
				row.appendChild(td1);
				row.appendChild(td2);
				row.appendChild(td3);
				tbody.insertBefore(row, tbody.getElementsByTagName("tr")[1]);
			} else if (args[0] == 'aborted') {
				var tbody = document.getElementById("reportTable").getElementsByTagName("tbody")[0];
				var row = document.createElement("tr");
				var td1 = document.createElement("td");
				td1.className = 'discover_abort';
				td1.style.paddingLeft  = '0.5em';
				td1.style.paddingRight = '0.5em';
				td1.vAlign = 'top';
				td1.appendChild(document.createTextNode(args[1]));
				var td2 = document.createElement("td");
				td2.className = 'discover_abort';
				td2.style.paddingLeft  = '0.5em';
				td2.style.paddingRight = '0.5em';
				td2.vAlign = 'top';
				td2.appendChild(document.createTextNode(args[0]));
				var td3 = document.createElement("td");
				td3.className = 'discover_abort';
				td3.colSpan = 3;
				td3.style.paddingLeft  = '0.5em';
				td3.style.paddingRight = '0.5em';
				td3.vAlign = 'top';
				td3.appendChild(document.createTextNode(args[2]));
				row.appendChild(td1);
				row.appendChild(td2);
				row.appendChild(td3);
				tbody.insertBefore(row, tbody.getElementsByTagName("tr")[1]);
				abort = 1;
			} else if (args[0] == 'import_results') {
				var cssName = 'discover_info';
				if (args[2] == 'exception') {
					cssName = 'info';
				} else if (args[2] == 'error') {
					cssName = 'discover_error';
				} else if (args[2] == 'added') {
					cssName = 'discover_success';
				}
				var tbody = document.getElementById("reportTable").getElementsByTagName("tbody")[0];
				var row = document.createElement("tr");
				var td1 = document.createElement("td");
				td1.className = cssName;
				td1.style.paddingLeft  = '0.5em';
				td1.style.paddingRight = '0.5em';
				td1.vAlign = 'top';
				td1.appendChild(document.createTextNode(args[1]));
				var td2 = document.createElement("td");
				td2.className = cssName;
				td2.style.paddingLeft  = '0.5em';
				td2.style.paddingRight = '0.5em';
				td2.vAlign = 'top';
				td2.appendChild(document.createTextNode(args[2]));
				var td3 = document.createElement("td");
				td3.className = cssName;
				td3.colSpan = 3;
				td3.style.paddingLeft  = '0.5em';
				td3.style.paddingRight = '0.5em';
				td3.vAlign = 'top';
				td3.appendChild(document.createTextNode(args[3]));
				row.appendChild(td1);
				row.appendChild(td2);
				row.appendChild(td3);
				tbody.insertBefore(row, tbody.getElementsByTagName("tr")[1]);
			} else if (args[0] == 'discover_deep') {
				host = args[1];
				var tbody = document.getElementById("reportTable").getElementsByTagName("tbody")[0];
				var row = document.createElement("tr");
				var td1 = document.createElement("td");
				td1.className = 'discover_info';
				td1.style.paddingLeft  = '0.5em';
				td1.style.paddingRight = '0.5em';
				td1.vAlign = 'top';
				td1.appendChild(document.createTextNode(args[2]));
				var td2 = document.createElement("td");
				td2.className = 'discover_info';
				td2.style.paddingLeft  = '0.5em';
				td2.style.paddingRight = '0.5em';
				td2.vAlign = 'top';
				td2.appendChild(document.createTextNode('discovery'));
				var td3 = document.createElement("td");
				td3.className = 'discover_info';
				td3.style.paddingLeft  = '0.5em';
				td3.style.paddingRight = '0.5em';
				td3.vAlign = 'top';
				td3.appendChild(document.createTextNode(args[3]));
				var td4 = document.createElement("td");
				td4.className = 'discover_info';
				td4.style.paddingLeft  = '0.5em';
				td4.style.paddingRight = '0.5em';
				td4.vAlign = 'top';
				td4.appendChild(document.createTextNode(args[4]));
				var td5 = document.createElement("td");
				td5.className = 'discover_info';
				td5.style.paddingLeft  = '0.5em';
				td5.style.paddingRight = '0.5em';
				td5.vAlign = 'top';
				td5.appendChild(document.createTextNode(args[5]));
				row.appendChild(td1);
				row.appendChild(td2);
				row.appendChild(td3);
				row.appendChild(td4);
				row.appendChild(td5);
				tbody.insertBefore(row, tbody.getElementsByTagName("tr")[1]);
			} else if (args[0] == 'discovered' || args[0] == 'method_complete') {
				if (args[0] == 'method_complete') {
					method_complete = 1;
				}
				var tbody = document.getElementById("reportTable").getElementsByTagName("tbody")[0];
				var row = document.createElement("tr");
				var td1 = document.createElement("td");
				td1.className = 'discover_info';
				td1.style.paddingLeft  = '0.5em';
				td1.style.paddingRight = '0.5em';
				td1.vAlign = 'top';
				td1.appendChild(document.createTextNode(args[1]));
				var td2 = document.createElement("td");
				td2.className = 'discover_info';
				td2.style.paddingLeft  = '0.5em';
				td2.style.paddingRight = '0.5em';
				td2.vAlign = 'top';
				td2.appendChild(document.createTextNode('discovery'));
				var td3 = document.createElement("td");
				td3.className = 'discover_info';
				td3.style.paddingLeft  = '0.5em';
				td3.style.paddingRight = '0.5em';
				td3.vAlign = 'top';
				td3.appendChild(document.createTextNode(args[2]));
				var td4 = document.createElement("td");
				td4.className = 'discover_info';
				td4.style.paddingLeft  = '0.5em';
				td4.style.paddingRight = '0.5em';
				td4.vAlign = 'top';
				td4.appendChild(document.createTextNode(args[3]));
				var td5 = document.createElement("td");
				td5.className = 'discover_info';
				td5.style.paddingLeft  = '0.5em';
				td5.style.paddingRight = '0.5em';
				td5.vAlign = 'top';
				td5.appendChild(document.createTextNode(args[4]));
				row.appendChild(td1);
				row.appendChild(td2);
				row.appendChild(td3);
				row.appendChild(td4);
				row.appendChild(td5);
				tbody.insertBefore(row, tbody.getElementsByTagName("tr")[1]);
			} else {
				var tbody = document.getElementById("reportTable").getElementsByTagName("tbody")[0];
				var row = document.createElement("tr");
				var td1 = document.createElement("td");
				td1.className = 'discover_info';
				td1.style.paddingLeft  = '0.5em';
				td1.style.paddingRight = '0.5em';
				td1.vAlign = 'top';
				td1.appendChild(document.createTextNode(args[1]));
				var td2 = document.createElement("td");
				td2.className = 'discover_info';
				td2.style.paddingLeft  = '0.5em';
				td2.style.paddingRight = '0.5em';
				td2.vAlign = 'top';
				td2.appendChild(document.createTextNode(args[2]));
				var td3 = document.createElement("td");
				td3.className = 'discover_info';
				td3.colSpan = 3;
				td3.style.paddingLeft  = '0.5em';
				td3.style.paddingRight = '0.5em';
				td3.vAlign = 'top';
				td3.appendChild(document.createTextNode(args[3]));
				row.appendChild(td1);
				row.appendChild(td2);
				row.appendChild(td3);
				tbody.insertBefore(row, tbody.getElementsByTagName("tr")[1]);
			}
		}
	}
	process_methods();
}
</script>
);

    my $detail = qq(
<tr>
<td class=data0>
<table width="100%" cellpadding=3 cellspacing=0 align=left border=0>
<tr>
<td class=wizard_title_heading style="padding: 0.5em 10px;" valign=top>Discovery ...</td>
</tr>
<tr>
<td class=wizard_body>
<table width="100%" cellpadding=7 cellspacing=0 align=left border=0>
<tr>
<td class=wizard_body>Wait for scan to finish before closing this window. Select "Cancel" to start over.</td>
</tr>
</table>
</td>
</tr>
</table>
</td>
</tr>
<tr>
<td class=data0>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class=$form_class valign=top width=170px>&nbsp;Method:</td>
<td class=$form_class><div id="method_status"></div></td>
</tr>
</table>
</td>
</tr>
<tr>
<td class=data0>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class=$form_class valign=top width=170px>&nbsp;Status:</td>
<td class=$form_class><div id="status"></div></td>
</tr>
</table>
</td>
</tr>
<tr>
<td class=data0>
<table cellpadding=0 cellspacing=7 align=left border=0 width="100%">
<tr>
<td>
$javascript
$input_tags
<table cellpadding=0 cellspacing=0 align=left border=0>
<tr>
<td>
<div class="scroll_area">
<div class="scroll_area_fill" style="display: inline-table;">
<table id="reportTable" cellpadding=0 cellspacing=2 align=left border=0>
<!-- We avoid thead, to sidestep a Chrome margin-collapse bug. -->
<tbody>
<tr>
<th class=column_head align="center" style="padding: 3px;">&nbsp;Time&nbsp;</th>
<th class=column_head align="center" style="padding: 3px;">&nbsp;Event&nbsp;</th>
<th class=column_head align="center" style="padding: 3px;" colspan=3>&nbsp;Detail (typically: Address, Host, Description)&nbsp;</th>
</tr>
<tr style="display: none;"><td></td></tr>
</tbody>
</table>
</div><div style="height: 0px; display: inline-block; overflow-y: scroll; vertical-align: top;"></div>
<!-- The 0-height div reserves horizontal space for the table scrollbar. Don't touch. -->
</div>
</td>
</tr>
</table>
</td>
</tr>
</table>
</td>
</tr>
<tr>
<td style=border:0 align=left>
<input class=submitbutton type=submit name=cancel_discovery value="Cancel" tabindex=2>);
    if ( $process{'auto'} eq 'Interactive' ) {
	$detail .= qq(
&nbsp;
<input class=submitbutton_disabled disabled type=submit name=manual_process value="Next >>" tabindex=1>
&nbsp;);
    }
    if ( $process{'auto'} eq 'Auto' ) {
	$detail .= qq(
&nbsp;
<input class=submitbutton_disabled disabled type=submit name=commit value="Commit" tabindex=1>
&nbsp;);
    }
    $detail .= qq(
</td>
</tr>
</table>
</td>
</tr>);
    my $errstr = undef;
    my $dt     = datetime();
    if ( !open( FILE, '>', "$config_settings{'monarch_home'}/automation/data/$import_file" ) ) {
	$errstr = "Error: Cannot create $config_settings{'monarch_home'}/automation/data/$import_file ($!)";
    }
    else {
	print FILE "\n#$dt Discovery process begins.\n# name;;alias;;address;;description;;parent;;profile;;service profile;;service\n";
	print FILE $port_defs_str . $ports_str . $tcp_snmp_opt . $snmp_match_str . $snmp_commands;
	close FILE;
    }

    return $detail, $errstr;
}

############################################################################
# Subs to support automation scripts
############################################################################

sub config_settings() {
    my %where = ();
    my %objects = StorProc->fetch_list_hash_array( 'setup', \%where );
    $config_settings{'nagios_ver'}   = $objects{'nagios_version'}[2];
    $config_settings{'nagios_bin'}   = $objects{'nagios_bin'}[2];
    $config_settings{'nagios_etc'}   = $objects{'nagios_etc'}[2];
    $config_settings{'monarch_home'} = $objects{'monarch_home'}[2];
    $config_settings{'monarch_ver'}  = $objects{'monarch_version'}[2];
    $config_settings{'backup_dir'}   = $objects{'backup_dir'}[2];
    $config_settings{'commit_type'}  = $objects{'commit_type'}[2];
    unless ( $config_settings{'commit_type'} ) {
	$config_settings{'commit_type'} = 'default';
    }
    $config_settings{'illegal_object_name_chars'} = $objects{'illegal_object_name_chars'}[2];
    $config_settings{'illegal_object_name_chars'} .= "/";
    $config_settings{'is_portal'} = 0;
    if ( -e '/usr/local/groundwork/config/db.properties' ) {
	$config_settings{'is_portal'} = 1;
    }
    return %config_settings;
}

sub backup() {
    %config_settings = %{ $_[1] };
    my $user_acct  = $_[2];
    my $annotation = $_[3];
    my $lock       = $_[4];
    ## FIX MAJOR:  Convert this to a StorProc->synchronized_backup() call.
    my ( $full_backup_dir, $errors ) = StorProc->backup(
	$config_settings{'nagios_etc'},
	$config_settings{'backup_dir'},
	$user_acct,
	$annotation || 'unannotated backup initiated via MonarchAutoConfig',
	$lock
    );
    return $full_backup_dir, $errors;
}

sub build_files(@) {
    my %file_ref = %{ $_[1] };
    %config_settings = %{ $_[2] };
    config_settings();
    my ( $files, $errors ) = Files->build_files(
	$file_ref{'user_acct'}, $file_ref{'group'}, $file_ref{'commit_step'},
	$file_ref{'export'},
	$config_settings{'nagios_ver'},
	$config_settings{'nagios_etc'},
	$file_ref{'location'}, $file_ref{'tarball'}
    );
    if ( !defined( $file_ref{'commit_step'} ) || $file_ref{'commit_step'} =~ /\d/ ) {
	## If an error leads you here, you have been bitten by the well-intentioned renaming of a
	## hash key. Previously the hashkey in question was called variously 'type' or 'preflight',
	## and it had possible values of '' (empty string), 1, or 2, with 1 meaning
	## preflight and 2 meaning commit. Now it is called 'commit_step' and it has possible
	## corresponding values of '' (empty string), 'preflight', and 'commit'.
	print STDERR &$Instrument::show_trace_as_text();
	push( @$errors,
"Error: in MonarchAutoConfig.pm build_files(), file_ref hashref should include a commit_step element with value of '', 'preflight', or 'commit'."
	);
    }
    return $files, \@{$errors};
}

sub pre_flight_check(@) {
    %config_settings = %{ $_[1] };
    my @preflight_results = StorProc->pre_flight_check( $config_settings{'nagios_bin'}, $config_settings{'monarch_home'} );
    my $rc = 0;
    foreach my $msg (@preflight_results) {
	if ( $msg =~ /Things look okay/ ) { $rc = 1 }
    }
    if ( $config_settings{'verbose'} ) {
	return $rc, \@preflight_results;
    }
    else {
	return $rc;
    }
}

sub import_profile(@) {
    my $folder    = $_[1];
    my $file      = $_[2];
    my $overwrite = $_[3];
    my @messages  = ();
    use MonarchProfileImport;
    push @messages, "Importing $file";
    my @msgs = ProfileImporter->import_profile( $folder, $file, $overwrite );
    push( @messages, @msgs );
    push @messages, '-----------------------------------------------------';
    return @messages;
}

sub datetime() {
    my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) = localtime(time);
    $year += 1900;
    $mon++;
    if ( $mon  =~ /^\d{1}$/ ) { $mon  = '0' . $mon }
    if ( $mday =~ /^\d{1}$/ ) { $mday = '0' . $mday }
    if ( $hour =~ /^\d{1}$/ ) { $hour = '0' . $hour }
    if ( $min  =~ /^\d{1}$/ ) { $min  = '0' . $min }
    if ( $sec  =~ /^\d{1}$/ ) { $sec  = '0' . $sec }
    return "$year-$mon-$mday $hour:$min:$sec";
}

sub copy_files(@) {
    my $source      = $_[1];
    my $destination = $_[2];
    my $result      = Files->copy_files( $source, $destination );
    return $result;
}

sub rewrite_nagios(@) {
    my $source      = $_[1];
    my $destination = $_[2];
    my $result      = Files->rewrite_nagios_cfg( $source, $destination );
    return $result;
}

sub commit(@) {
    %config_settings = %{ $_[1] };
    my $user_acct  = $_[2];
    my $annotation = $_[3];
    my $lock       = $_[4];

    # FIX MAJOR:  Call StorProc->synchronized_commit() instead, and deal with the different arguments
    # it returns, making sure we do the right thing with respect to error/result ordering.
    if (1) {
	my @commit_results = StorProc->commit(
	    $config_settings{monarch_home},
	    $config_settings{nagios_etc},
	    $config_settings{backup_dir},
	    $user_acct, $annotation, $lock
	);
	return @commit_results;
    }

    my ( $errors, $results, $timings ) = StorProc->synchronized_commit(
	$user_acct,                   $config_settings{nagios_ver},   $config_settings{nagios_etc},
	$config_settings{nagios_bin}, $config_settings{monarch_home}, 'html',
	$config_settings{backup_dir}, $annotation,                    $lock
    );

    push @$results, @$errors;
    return @$results;
}

############################################################################
# Forms for Auto Configuration interface
############################################################################

sub show_import_data(@) {
    my @file_data = @{ $_[1] };
    my $detail .= qq(
<tr>
<td>
<div class="scroll" style="height: 550px;width: auto">
<table width="100%" cellpadding=3 cellspacing=0 align=left border=0>);
    my $class = 'row_dk';
    foreach my $line (@file_data) {
	if ( $class eq 'row_lt' ) {
	    $class = 'row_dk';
	}
	elsif ( $class eq 'row_dk' ) {
	    $class = 'row_lt';
	}
	$detail .= qq(
	<tr>
	<td class=$class align=left>$line</td>
	</tr>);
    }
    $detail .= qq(
</table>
</div>
</td>
</tr>);
    return $detail;
}

sub js_utils() {
    return qq(
<script type="text/javascript" language=JavaScript>
    // GWMON-9658
    // use browser sniffing to determine if IE or Opera (ugly, but required)
    var isOpera = false;
    var isIE = false;
    if (typeof(window.opera) != 'undefined') {isOpera = true;}
    if (!isOpera && navigator.userAgent.indexOf('MSIE') >= 0) {isIE = true;}
    function open_window(url,name,features) {
	features = features || '';  // GWMON-10363
	if (isIE) {
	    var referLink = document.createElement('a');
	    referLink.href = url;
	    referLink.onclick = function () {
		var safe_url = location.protocol + '//' + location.host + "/portal-core/themes/groundwork/images/favicon.ico";
		window.open(safe_url,name,features);
	    }
	    referLink.target = name;
	    document.body.appendChild(referLink);
	    referLink.click();
	}
	else {
	    window.open(url,name,features);
	}
    }
</script>);
}

sub import_schema(@) {
    my %schema        = %{ $_[1] };
    my $column_id     = $_[2];
    my $match_id      = $_[3];
    my $match_name    = $_[4];
    my @objects       = @{ $_[5] };
    my @host_profiles = @{ $_[6] };
    my $updated       = $_[7];
    my $discover_name = $_[8];
    my $match_type    = $_[9];
    my $rule          = $_[10];
    my $object        = $_[11];
    my $show_scrolled = $_[12];
    my $uri_name      = uri_escape( $schema{'name'} );
    my %doc           = doc();
    my $tab           = 1;
    my $docs          = undef;
    use HTML::Tooltip::Javascript;
    my $tt = HTML::Tooltip::Javascript->new(
	## URL path to where wz_tooltip.js is.
	javascript_dir => $monarch_js,
	options        => {
	    bgcolor     => '#000000',
	    default_tip => 'Tip not defined',
	    delay       => 0,
	    title       => 'Tooltip',
	},
    );
    my %options = (
	borderwidth => '1',
	padding     => '10',
	bordercolor => '#000000',
	bgcolor     => '#FFFFFF',
	width       => '500',
	fontsize    => '12px'
    );
    my $detail = js_utils();
    my $doc_url = StorProc->doc_section_url('Auto+Discovery', 'AutoDiscovery-TheAutomationSubsystem');
    my $scroll_anchor = $show_scrolled ? 'detail' : '';
    $detail .= qq(
<script type="text/javascript" language=JavaScript>
	function show_data() {
		var data_file = document.form.data_source.value;
		var url = "$monarch_cgi/monarch_auto.cgi?view=show_data&data_source=" + data_file;
		open_window(url,'mywindow','width=1000,height=650,resizable');
	}
	function ScrollWindow() {
	    document.getElementById( '$scroll_anchor' ).scrollIntoView();
	}
	if (window.attachEvent) {window.attachEvent('onload', ScrollWindow);}
	else if (window.addEventListener) {window.addEventListener('load', ScrollWindow, false);}
	else {document.addEventListener('load', ScrollWindow, false);}
</script>
<tr>
<td class=data0>
<table width="100%" cellpadding=7 cellspacing=0 align=left border=0>
<tr>
<td class=wizard_title_heading><b>$schema{'name'}</b>
<input type=hidden name=automation_name value="$schema{'name'}" tabindex=@{[$tab++]}>
</td>
<td class=wizard_title_heading style=border:0 align=right>
<input class=submitbutton type=button onclick="open_window('$doc_url')" value="Help" tabindex=@{[$tab++]}> &nbsp;
<input class=submitbutton type=submit name=save value="Save" tabindex=@{[$tab++]}>);
    unless ($discover_name) {
	$detail .= qq(
&nbsp;
<input class=submitbutton type=submit name=delete value="Delete" tabindex=@{[$tab++]}>);
	$detail .= qq(
&nbsp;
<input class=submitbutton type=submit name=rename value="Rename" tabindex=@{[$tab++]}>);
    }
    $tab++;
    $detail .= qq(
&nbsp;
<input class=submitbutton type=submit name=save_template value="Save As Template" tabindex=$tab>&nbsp;);
    $tab++;
    $detail .= qq(
&nbsp;
<input class=submitbutton type=submit name=import value="Process Records" tabindex=$tab>&nbsp;);
    $tab++;
    $detail .= qq(
&nbsp;
<input class=submitbutton type=submit name=close value="Close" tabindex=$tab>&nbsp;
</td>
</tr>
<tr>
<td class=row1 colspan=2>An automation schema is an import/update data mapping tool that can be applied to any data source from which a text delimited file can be extracted.</td>
</tr>
</table>
</td>
</tr>
<tr>
<td class=data0>
<table width="100%" cellpadding=3 cellspacing=0 align=left border=0>
<tr>
<td class=row1 width="15%" valign=top>Description:</td>
<td class=row1>
);
    $tab++;
    my $description = $schema{'description'};
    $description = '' if not defined $description;
    $description = HTML::Entities::encode($description);
    my $lines = ( ( (my @lines) = split( /\n/, $description, 20 ) ) || 1 ) + 1;
    foreach my $line (@lines) {
	$lines += int (length($line) / 100);
    }
    $detail .= qq(
<textarea name=description rows=$lines cols=100 wrap=virtual tabindex=$tab>$description</textarea>
</td>
</tr>
</table>
</td>
</tr>
<tr>
<td class=data0>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class=$form_class width="15%">Schema type:</td>
<td class=$form_class align=left>$schema{'type'}<input type=hidden name=type value="$schema{'type'}"></td>
</tr>
</table>
</td>
</tr>);
    $tab++;

    if ( $schema{'type'} eq 'other-sync' ) {
	$detail .= qq(
<tr>
<td class=data0>
<table width="100%" cellpadding=7 cellspacing=0 align=left border=0>
<tr>
<td class=wizard_title_heading colspan=2><b>Primary Sync Object</b></td>
</tr>
<tr>
<td class=$form_class colspan=2>
Select the primary object type on which to assign child objects. For example, if your data lists parents by host, select Host as the sync object. You can choose to sync with host name, host address, or host alias.
</td>
</tr>
</table>
</td>
</tr>
<tr>
<td class=data0>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class=$form_class width="15%">Primary sync object:</td>
<td class=$form_class align=left>
<select name=sync_object tabindex=$tab>);
	my @sync_objects = ( 'Host', 'Parent', 'Group', 'Host group', 'Contact group' );
	foreach my $item (@sync_objects) {
	    if ( $schema{'sync_object'} eq $item ) {
		$detail .= "\n<option selected value=\"$item\">$item</option>";
	    }
	    else {
		$detail .= "\n<option value=\"$item\">$item</option>";
	    }
	}
	$detail .= qq(
</select>
</td>
</tr>
</table>
</td>
</tr>);
    }
    else {
	my $smart_name = $schema{'smart_name'} ? 'checked' : '';
	$detail .= qq(
<tr>
<td class=data0>
<table width="100%" cellpadding=7 cellspacing=0 align=left border=0>
<tr>
<td class=wizard_title_heading><b>Smart Names Option</b></td>
</tr>
<tr>
<td class=$form_class>
Select this option to satisfy required Name, Address, and Alias values from limited data. If after processing one or more values are left undefined, this option will substitute a defined value.  The order of substitution for Name is Alias then Address, for Address is Alias then Name, and for Alias is Address then Name.
</td>
</tr>
</table>
</td>
</tr>
<tr>
<td>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class=$form_class width="15%">Use smart names:</td>
<td class=$form_class align=left><input class=$form_class type=checkbox name=smart_name value=1 $smart_name tabindex=$tab>
</td>
</tr>
</table>
</td>
</tr>);
    }
    my $class = '';
    if ($discover_name) {
	$detail .= qq(
<input type=hidden name=data_source value="$schema{'data_source'}">
<input type=hidden name=delimiter value="$schema{'delimiter'}">);
    }
    else {
	$options{'title'} = 'Data Source';
	$options{'width'} = 800;
	$options{'left'}  = '1';
	$docs             = "\n$doc{'data-source'}";
	my $tooltip = $tt->tooltip( $docs, \%options );
	delete $options{'left'};

	$tab++;
	my $data_source = $schema{'data_source'};
	$data_source = '' if not defined $data_source;
	$data_source = HTML::Entities::encode($data_source);
	$detail .= qq(
<tr>
<td class=data0>
<table width="100%" cellpadding=7 cellspacing=0 align=left border=0>
<tr>
<td class=wizard_title_heading><b>Input Data</b></td>
</tr>
<tr>
<td class=$form_class>
Specify where to obtain the data, and how it is to be interpreted.
</td>
</tr>
</table>
</td>
</tr>
<tr>
<td class=data0>
<table width="100%" cellpadding=3 cellspacing=0 align=left border=0>
<tr>
<td class=row1 width="15%">Data source:</td>
<td class=row1>
<input type=text size=90 name=data_source id=data_source value="$data_source" tabindex=$tab>&nbsp;
);
	$tab++;
	$detail .= qq(
<input class="submitbutton" type="button" value="View" onclick="show_data()" tabindex=$tab>&nbsp;&nbsp;<a class=orange href="#" $tooltip tabindex="-1">&nbsp;?&nbsp;</a>
</td>
</tr>
</table>
</td>
</tr>
<tr>
<td class=data0>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class=$form_class width="15%">Delimiter:</td>
<td class=$form_class align=left>
);
	$tab++;
	$detail .= qq(<select name=delimiter tabindex=$tab>);
	my $other         = $schema{'delimiter'};
	my @list          = ( '', ',', ':', '::', ';', ';;', 'tab' );
	my $got_delimiter = undef;

	foreach my $item (@list) {
	    if ( defined( $schema{'delimiter'} ) && $item eq $schema{'delimiter'} ) {
		$other = undef;
		$detail .= "\n<option selected value=\"$item\">$item</option>";
	    }
	    else {
		$detail .= "\n<option value=\"$item\">$item</option>";
	    }
	}
	my $checked = $other ? 'checked' : '';
	my $class = 'head';

	$options{'title'} = 'Delimiter';
	$options{'width'} = 400;
	$docs = "\n$doc{'delimiter'}";
	$tooltip = $tt->tooltip( $docs, \%options );
	$tab++;
	$detail .= qq(
</select>
&nbsp;<input type=checkbox class=$form_class name=other_delimiter_ckbx value=1 $checked tabindex=$tab>&nbsp;Other:&nbsp;);
	$tab++;
	$other = '' if not defined $other;
	$other = HTML::Entities::encode($other);
	$detail .=
qq(<input type=text name=other_delimiter size=10 value="$other" tabindex=$tab>&nbsp;&nbsp;<a class=orange href="#" $tooltip tabindex="-1">&nbsp;?&nbsp;</a>
</td>
</tr>
</table>
</td>
</tr>);
    }
    $tab++;
    unless ( $schema{'type'} eq 'other-sync' ) {
	$detail .= qq(
<tr>
<td class=data0>
<table width="100%" cellpadding=7 cellspacing=0 align=left border=0>
<tr>
<td class=wizard_title_heading><b>Default Host Profile</b></td>
</tr>
<tr>
<td class=$form_class>
Required for schema type host-profile-sync. Select a default host profile to ensure any host record can be imported with a working configuration.
</td>
</tr>
</table>
</td>
</tr>
<tr>
<td class=data0>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class=$form_class width="15%">Default host profile:</td>
<td class=$form_class align=left>
<select name=default_profile tabindex=$tab>);
	if ( $schema{'type'} ne 'host-profile-sync' || ! $schema{'default_profile'} || scalar(@host_profiles) == 0) {
	    ## FIX MINOR:  These are illegal value= options; should be value='', perhaps?
	    if ( $schema{'default_profile'} ) {
		$detail .= "\n<option value=>-- no default --</option>";
	    }
	    else {
		$detail .= "\n<option selected value=>-- no default --</option>";
	    }
	}
	@host_profiles = sort { lc($a) cmp lc($b) } @host_profiles;
	foreach my $item (@host_profiles) {
	    if ( defined( $schema{'default_profile'} ) && $schema{'default_profile'} eq $item ) {
		$detail .= "\n<option selected value=\"$item\">$item</option>";
	    }
	    else {
		$detail .= "\n<option value=\"$item\">$item</option>";
	    }
	}
	$detail .= qq(
</select>
</td>
</tr>
</table>
</td>
</tr>);
    }
    $detail .= qq(
<tr>
<td class=data2>
<table width="100%" cellpadding=7 cellspacing=0 align=left border=0>
<tr>
<td class=wizard_title_heading colspan=2><b>Data Columns</b></td>
</tr>
<tr>
<td class=$form_class>
Here you define the format of each row of your input data, and the rules for analyzing it.
<ul>
<li>
You first specify the nature (names) of the columns in each row,
then what should be done with those columns as they are matched in the input stream.
</li>
<li>
The columns you specify here are expected to be separated by the delimiter specified earlier in the automation schema.
Position 1 is the data before the first delimiter in a row.
</li>
<li>
Columns in each row are processed in order as they occur in the row, starting with the first position.
As each column is recognized, an arbitrary number of associated match tasks can be executed, in the order you specify.
</li>
<li>
For the match task selected in the right panel, both the match condition
and the action taken when a match is found are specified in the Match Task Detail below.
</li>
<li>
Details of a given Column Name or Match Task Name are exposed by clicking on that name to select it.
</li>
<li>
Within the Match Task Detail, the choices available in selection lists often depend on the selection made in some other selection list.
The best strategy to ensure that you have the setup you desire is to first choose the Match condition (and Match string, if any),
then the Action rule, then the particular option(s) associated with that rule.
</li>
<li>
Most list selections in the Match Task Detail will immediately update the configuration database with the new setting.
However, it is sometimes necessary to click Update to save the data in text boxes or to get the selection lists to properly refresh.
</li>
<li>
Lots more useful information is available in the pop-up help frames triggered by mousing over the question marks.
</li>
</ul>
</td>
</tr>
</table>
</td>
</tr>
<tr>
<td>
<table width="100%" cellpadding=7 cellspacing=0 align=left border=0>
<tr>
<td class=$form_class width="50%" valign=top>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
	<tr>
	<td class=column_head width="13%" align=center>Position</td>
	<td class=column_head width="87%" align=left colspan=2>Column Name (within your input data)</td>
	</tr>);
    my %columns = ();
    foreach my $key ( keys %{ $schema{'column'} } ) {
	if ($key) {
	    $columns{ $schema{'column'}{$key}{'position'} }{'name'} = $schema{'column'}{$key}{'name'};
	    $columns{ $schema{'column'}{$key}{'position'} }{'id'}   = $key;
	}
    }
    my $arrow = '&nbsp';
    foreach my $pos ( sort { $a <=> $b } keys %columns ) {
	unless ($pos) { next }
	unless ($column_id) { $column_id = $columns{$pos}{'id'} }
	if ( $columns{$pos}{'id'} eq $column_id ) {
	    $class = 'match_selected';
	    ## $arrow = '<b>></b>';
	}
	else {
	    $class = 'column';
	    ## $arrow = '&nbsp';
	}
	$tab++;
	$detail .= qq(
		<tr>
		<td class=$class align=center><input type=text name=position_$columns{$pos}{'id'} size=3 value="$pos" tabindex=$tab></td>);
	$tab++;
	$detail .= qq(
		<td class=$class align=left width="75%"><input type=submit class=$class name=column_id_$columns{$pos}{'id'} value="$columns{$pos}{'name'}" style="white-space: normal;" tabindex=$tab></td>);
	$tab++;
	$detail .= qq(
		<td class=$class width="12%"><input type=submit class=$class name=remove_column_$columns{$pos}{'id'} value="remove" tabindex=$tab></td>
		</tr>);
    }
    $tab++;
    $detail .= qq(
		<tr>
		<td class=row2 colspan=3>
		<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
			<tr>
			<td class=row2>
			<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
				<tr>
				<td class=row2 colspan=3><b>Define Column (Position, and Column Name)</b>
				</td>
				</tr>
				<tr>
				<td class=row2 align=left width="8%"><input type=text name=column_pos size=3 tabindex=$tab></td>);
    $options{'title'} = 'Define Column';
    $options{'width'} = 500;
    $docs =
"\nEnter the position and name of the new column definition.<br><p class='append'><b>Position</b>: $doc{'column'}{'position'}</p><p class='append'>\n<b>Column Name</b>: $doc{'column'}{'name'}</p>";
    my $tooltip = $tt->tooltip( $docs, \%options );

    $tab++;
    $detail .= qq(
				<td class=row2 style="white-space: nowrap;"><input type=text name=column_name size=35 tabindex=$tab>&nbsp;&nbsp;<a class=orange href="#" $tooltip tabindex="-1">&nbsp;?&nbsp;</a></td>);
    $tab++;
    $detail .= qq(
				<td class=row2 valign=top align=right><input class="submitbutton" type="submit" name=add_column value="Add Column" tabindex=$tab>
				</td>
				</tr>
			</table>
			</td>
			</tr>
		</table>
		</td>
		</tr>
	</table>
	</td>
	<td class=$form_class width="50%" valign=top>
	<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
		<tr>
		<td class=column_head align=left width="10%">Order</td>
		<td class=column_head align=left colspan=2>Match Task Name (for the Column Name selected to the left)</td>
		</tr>);
    my %order = ();
    foreach my $key ( keys %{ $schema{'column'}{$column_id}{'match'} } ) {
	$order{ $schema{'column'}{$column_id}{'match'}{$key}{'order'} }{'name'} = $schema{'column'}{$column_id}{'match'}{$key}{'name'};
	$order{ $schema{'column'}{$column_id}{'match'}{$key}{'order'} }{'id'}   = $key;
    }
    foreach my $pos ( sort { $a <=> $b } keys %order ) {
	unless ($pos) { next }
	unless ($match_id) {
	    $match_id = $order{$pos}{'id'};
	    ## FIX THIS:  Do we now also need to wipe out these variables, so they don't mistakenly take
	    ## bad values from the function parameters but instead perhaps get new values assigned below?
	    ## $object, $match_type, $rule, $match_name
	}
	if ( $order{$pos}{'id'} eq $match_id ) {
	    $class = 'match_selected';
	}
	else {
	    $class = 'match';
	}
	$tab++;
	$detail .= qq(
		<tr>
		<td class=$class align=center width="10%">$pos</td>
		<td class=$class align=left><input type=submit class=$class name=match_id_$order{$pos}{'id'} value="$order{$pos}{'name'}" style="white-space: normal;" tabindex=$tab></td>);
	$tab++;
	$detail .= qq(
		<td class=$class align=right><input type=submit class=$class name=remove_match_$order{$pos}{'id'} value="remove" tabindex=$tab></td>
		</tr>);
    }

    if ($column_id) {
	$detail .= qq(
		<tr>
		<td class=row2 colspan=4>
		<input type=hidden name=column_id value=$column_id>
		<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
			<tr>
			<td class=row2>
			<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
				<tr>
				<td class=row2 colspan=3><b>Define Match Task (Order, and Match Task Name)</b></td>
				</tr>
				<tr>);
	$tab++;
	$detail .= qq(
				<td class=row2 align=left width="8%"><input type=text name=new_match_order size=3 tabindex=$tab></td>);

	$options{'title'} = 'Define Match Task';
	$options{'left'}  = '1';
	$docs =
"\nEnter the order and name of the new match definition.<br><p class='append'><b>Order</b>: $doc{'match'}{'order'}</p>\n<p class='append'><b>Match Task Name</b>: $doc{'match'}{'name'}</p>";
	my $tooltip = $tt->tooltip( $docs, \%options );
	delete $options{'left'};

	$tab++;
	$detail .= qq(
				<td class=row2 style="white-space: nowrap;"><input type=text name=new_match_name size=35 tabindex=$tab>&nbsp;&nbsp;<a class=orange href="#" $tooltip tabindex="-1">&nbsp;?&nbsp;</a></td>);
	$tab++;
	$detail .= qq(
				<td class=row2 valign=top align=right><input class="submitbutton" type="submit" name=add_match value="Add Match" tabindex=$tab>
				</td>
				</tr>
			</table>
			</td>
			</tr>
		</table>
		</td>
		</tr>);
    }
    else {
	$detail .= qq(
		<tr>
		<td class=$form_class colspan=4>&nbsp; </td>
		</tr>);
    }
    $detail .= qq(
</table>
</td>
</tr>
</table>
</td>
</tr>);

    my $form_match = 'match_selected';
    if (defined $match_id) {
	$object     = $schema{'column'}{$column_id}{'match'}{$match_id}{'object'}     unless defined($object);
	$match_type = $schema{'column'}{$column_id}{'match'}{$match_id}{'match_type'} unless defined($match_type);
	$rule       = $schema{'column'}{$column_id}{'match'}{$match_id}{'rule'}       unless defined($rule);
    }

    my @match_types =
      ( 'use-value-as-is', 'is-null', 'exact', 'begins-with', 'ends-with', 'contains', 'use-perl-reg-exp', 'service-definition' );

    $detail .= qq(
<tr>
<td class=data0>
<table width="100%" cellpadding=7 cellspacing=0 align=left border=0>
<tr>
<td class=wizard_title_heading colspan=2><a id="detail" name="detail"><b>Match Task Detail (of the Match Task Name selected above)</b></a></td>
</tr>
</table>
</td>
</tr>);

    if ($updated) {
	$detail .= qq(
	    <tr>
	    <td>
	    <table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
	    <tr>
	    <td class=$form_match align=left width="100%">$updated </td>
	    </tr>
	    </table>
	    </td>
	    </tr>);
    }
    elsif ($match_id) {
	unless ($match_name) {
	    $match_name = $schema{'column'}{$column_id}{'match'}{$match_id}{'name'};
	}

	$options{'title'} = 'Match Order';
	$docs = "\n<b>Order</b>: $doc{'match'}{'order'}<br>";
	my $tooltip = $tt->tooltip( $docs, \%options );

	$detail .= qq(
	    <tr>
	    <td>
	    <table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
	    <tr>
	    <td class=$form_match align=left width="3%">Order:&nbsp;&nbsp;<a class=orange href="#" $tooltip tabindex="-1"><b>&nbsp;?&nbsp;</b></a></td>
	    <td class=$form_match align=left width="3%"><input type=text name=order value="$schema{'column'}{$column_id}{'match'}{$match_id}{'order'}" size=3></td>);

	$options{'title'} = 'Match Task Name';
	$options{'width'} = 650;
	$options{'left'}  = '1';
	$docs             = "\n<b>Name</b>: $doc{'match'}{'name'}<br>";
	$tooltip = $tt->tooltip( $docs, \%options );
	delete $options{'left'};

	$detail .= qq(
	    <td class=$form_match align=left width="5%">&nbsp;&nbsp;Match&nbsp;name:&nbsp;&nbsp;<a class=orange href="#" $tooltip tabindex="-1"><b>&nbsp;?&nbsp;</b></a></td>
	    <td class=$form_match align=left width="5%"><input type=text name=match_name value="$match_name" size=50></td>
	    <td class=$form_match></td>
	    <td class=$form_match align=right>
		<input type=hidden name=match_id value=$match_id>
		<input class="submitbutton" type="submit" name=update_match value="Update">
	    </td>
	    </tr>
	    </table>
	    </td>
	    </tr>);

	$options{'title'} = 'Match Types';
	$docs = 'Select the match type to determine what part of the data record to match. All matches are case insensitive.<br>';
	my $select_options = '';
	foreach my $match_item (@match_types) {
	    if ( $match_item eq $match_type ) {
		$select_options .= "\n<option selected value=\"$match_item\">$match_item</option>";
	    }
	    else {
		$select_options .= "\n<option value=\"$match_item\">$match_item</option>";
	    }
	    $docs .= "\n<p class='append'><b>$match_item</b>: $doc{'type'}{$match_item}</p>";
	}
	$tooltip = $tt->tooltip( $docs, \%options );

	$detail .= qq(
	    <tr>
	    <td>
	    <table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
	    <tr>
	    <td class=$form_match align=left width="5%">Match&nbsp;condition:&nbsp;&nbsp;<a class=orange href="#" $tooltip tabindex="-1"><b>&nbsp;?&nbsp;</b></a></td>
	    <td class=$form_match align=left width="5%">
	    <select name=match_type onChange="lowlight();submit()">
	    $select_options
	    </select>
	    </td>);

	my $match_string = $schema{'column'}{$column_id}{'match'}{$match_id}{'match_string'};
	$match_string = '' if not defined $match_string;
	if ( $match_type =~ /exact|begins-with|ends-with|contains|use-perl-reg-exp/ ) {
	    $options{'title'} = 'Match String';
	    $options{'width'} = 600;
	    $options{'left'}  = '1';
	    if ( $match_type eq 'use-perl-reg-exp' ) {
		$docs = "\n<b>use-perl-reg-exp</b>: $doc{'string'}{'use-perl-reg-exp'}";
	    }
	    else {
		$docs = "\n<b>$match_type</b>: $doc{'string'}{'other'}<br>";
	    }
	    $tooltip = $tt->tooltip( $docs, \%options );
	    $detail .= qq(
		    <td class=$form_match align=left width="5%">&nbsp;&nbsp;Match&nbsp;string:&nbsp;&nbsp;<a class=orange href="#" $tooltip tabindex="-1"><b>&nbsp;?&nbsp;</b></a></td>
		    <td class=$form_match align=left><input type=text name=match_string value="$match_string" size=50></td>);
	    delete $options{'left'};
	}
	elsif ( $match_type eq 'service-definition' ) {
	    $options{'title'} = 'Service Delimiter';
	    $options{'width'} = 800;
	    $options{'left'}  = '1';
	    $docs             = "\n<b>service-delimiter</b>: $doc{'string'}{'service-delimiter'}";
	    $tooltip = $tt->tooltip( $docs, \%options );
	    $detail .= qq(
		    <td class=$form_match align=left width="5%">&nbsp;&nbsp;Service&nbsp;delimiter:&nbsp;&nbsp;<a class=orange href="#" $tooltip tabindex="-1"><b>&nbsp;?&nbsp;</b></a></td>
		    <td class=$form_match align=left><input type=text name=match_string value="$match_string" size=5></td>);
	    delete $options{'left'};
	}
	else {
	    $detail .= qq(
		<td class=$form_match align=left width="5%">&nbsp;</td>
		<td class=$form_match align=left>&nbsp;</td>);
	}
	$detail .= qq(
	    </tr>
	    </table>
	    </td>
	    </tr>);

	unless ( $match_type eq 'service-definition' ) {
	    $detail .= qq(
		<tr>
		<td>
		<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
		<tr>);
	    my @rules = ();
	    if ( $schema{'type'} eq 'host-profile-sync' ) {
		if ( $match_type =~ /exact|begins-with|ends-with|contains|use-perl-reg-exp/ ) {
		    @rules = (
			'Assign object(s)',
			'Add if not exists and assign object',
			'Assign value to',
			'Assign value if undefined',
			'Assign host profile if undefined',
			'Convert dword and assign to',
			'Skip column record',
			'Discard record',
			'Discard if match existing host'
		    );
		}
		elsif ( $match_type eq 'is-null' ) {
		    @rules = ( 'Assign object(s)', 'Skip column record', 'Discard record' );
		}
		else {
		    @rules = (
			'Add if not exists and assign object',
			'Assign object if exists',
			'Assign value to',
			'Assign value if undefined',
			'Assign host profile if undefined',
			'Convert dword and assign to',
			'Discard if match existing host',
			'Resolve to parent'
		    );
		}
	    }
	    else {
		if ( $match_type =~ /exact|begins-with|ends-with|contains|use-perl-reg-exp/ ) {
		    @rules = (
			'Assign object(s)',
			'Add if not exists and assign object',
			'Assign value to',
			'Assign value if undefined',
			'Assign host profile if undefined',
			'Assign host profile',
			'Assign service',
			'Convert dword and assign to',
			'Skip column record',
			'Discard record',
			'Discard if match existing host'
		    );
		}
		elsif ( $match_type eq 'is-null' ) {
		    @rules = ( 'Assign object(s)', 'Assign host profile', 'Discard record' );
		}
		else {
		    @rules = (
			'Add if not exists and assign object',
			'Assign object if exists',
			'Assign value to',
			'Assign value if undefined',
			'Assign host profile if undefined',
			'Convert dword and assign to',
			'Discard if match existing host',
			'Resolve to parent'
		    );
		}
	    }
	    $options{'title'} = 'Rules and Objects';
	    $options{'width'} = 750;
	    $docs = 'Select the appropriate rule to determine how the match should be applied.<br>';
	    ## FIX MINOR:  This is an illegal value= option; should be value='', perhaps?
	    my $select_options = '<option value=></option>';
	    foreach my $rule_item (@rules) {
		if ( $rule_item eq $rule ) {
		    $select_options .= "\n<option selected value=\"$rule_item\">$rule_item</option>";
		}
		else {
		    $select_options .= "\n<option value=\"$rule_item\">$rule_item</option>";
		}
		$docs .= "\n<p class='append'><b>$rule_item</b>: $doc{'rule'}{$rule_item}</p>";
	    }
	    $tooltip = $tt->tooltip( $docs, \%options );

	    $detail .= qq(
		    <td class=$form_match align=left width="5%">Action&nbsp;rule:&nbsp;&nbsp;<a class=orange href="#" $tooltip tabindex="-1"><b>&nbsp;?&nbsp;</b></a></td>
		    <td class=$form_match align=left width="5%">
		    <select name=rule onChange="lowlight();submit()">
		    $select_options
		    </select>
		    </td>);

	    my @obj_types = ();
	    my $schema_rule = $schema{'column'}{$column_id}{'match'}{$match_id}{'rule'};
	    if ( $schema{'type'} eq 'host-profile-sync' ) {
		if ( $schema_rule =~ /Assign object/ ) {
		    @obj_types = ( 'Parent', 'Group', 'Host group', 'Service profile', 'Contact group' );
		}
		elsif ( $schema_rule eq 'Add if not exists and assign object' ) {
		    @obj_types = ( 'Contact group', 'Group', 'Host group' );
		}
		elsif ( $schema_rule =~ /discard/i ) {
		    @obj_types = ();
		}
		elsif ( $schema_rule =~
		    /Assign value to|Assign value if undefined|Assign host profile if undefined|Apply|Convert dword and assign to/ )
		{
		    @obj_types = ( 'Primary record', 'Name', 'Address', 'Alias', 'Description' );
		}
	    }
	    elsif ( $schema{'type'} eq 'other-sync' ) {
		if ( $schema_rule =~ /Assign object/ ) {
		    @obj_types = ( 'Parent', 'Group', 'Host group', 'Service profile', 'Contact group' );
		}
		elsif ( $schema_rule eq 'Add if not exists and assign object' ) {
		    @obj_types = ( 'Contact group', 'Group', 'Host group' );
		}
		elsif ( $schema_rule =~ /discard|resolve parent/i ) {
		    @obj_types = ();
		}
		else {
		    @obj_types = ( 'Primary record', 'Name', 'Address', 'Alias', 'Description' );
		}
	    }
	    elsif (defined $schema_rule) {
		if ( $schema_rule eq 'Assign object if exists' ) {
		    @obj_types = ( 'Contact group', 'Group', 'Host group', 'Host profile', 'Parent', 'Service profile', 'Service' );
		}
		elsif ( $schema_rule =~ /Assign object/ ) {
		    @obj_types = ( 'Contact group', 'Group', 'Host group', 'Parent', 'Service profile' );
		}
		elsif ( $schema_rule eq 'Add if not exists and assign object' ) {
		    @obj_types = ( 'Contact group', 'Group', 'Host group' );
		}
		elsif ( $schema_rule =~ /discard/i ) {
		    @obj_types = ();
		}
		elsif ( $schema_rule =~
		    /Assign value to|Assign value if undefined|Assign host profile if undefined|Apply|Convert dword and assign to/ )
		{
		    @obj_types = ( 'Primary record', 'Name', 'Address', 'Alias', 'Description', 'Host profile', );
		}
	    }

	    my %obj_name = (
		'Host group'      => 'hostgroups',
		'Contact group'   => 'contactgroups',
		'Group'           => 'groups',
		'Parent'          => 'parents',
		'Service profile' => 'serviceprofiles'
	    );
	    if (   $rule eq 'Assign host profile'
		|| $rule eq 'Assign host profile if undefined' )
	    {
		$detail .= qq(
		    <td class=$form_match width="5%">&nbsp;&nbsp;Host&nbsp;profile:</td>
		    <td class=$form_match align=left>
		    <select name=assign_host_profile>);
		@objects = sort { lc($a) cmp lc($b) } @objects;
		foreach my $object_item (@objects) {
		    my $hostprofile = $schema{'column'}{$column_id}{'match'}{$match_id}{'hostprofile'};
		    if ( defined($hostprofile) && $object_item eq $schema{'column'}{$column_id}{'match'}{$match_id}{'hostprofile'} ) {
			$detail .= "\n<option selected value=\"$object_item\">$object_item</option>";
		    }
		    else {
			$detail .= "\n<option value=\"$object_item\">$object_item</option>";
		    }
		}
		$detail .= qq(
		    </select>
		    </td>);
	    }
	    elsif ( $rule eq 'Assign service' ) {
		$detail .= qq(
		    <td class=$form_match width="5%">&nbsp;&nbsp;Service&nbsp;name:</td>
		    <td class=$form_match align=left>
		    <select name=service_name>);
		## <select name=service_name onChange="lowlight();submit()">);
		## FIX MINOR:  This is an illegal value= option; should be value='', perhaps?
		$detail .= "\n<option value=></option>";
		@objects = sort { lc($a) cmp lc($b) } @objects;
		foreach my $object_item (@objects) {
		    my $service_name = $schema{'column'}{$column_id}{'match'}{$match_id}{'service_name'};
		    if ( defined($service_name) && $object_item eq $service_name ) {
			$detail .= "\n<option selected value=\"$object_item\">$object_item</option>";
		    }
		    else {
			$detail .= "\n<option value=\"$object_item\">$object_item</option>";
		    }
		}
		$detail .= qq(
		    </select>
		    </td>);
	    }
	    elsif (@obj_types) {
		## FIX THIS:  This is showing up sometimes for some Rule choices when it does not belong on-screen,
		## simply because some stuff is being carried forward from previous screens; it needs more
		## qualification before being displayed.  It may be because one needs to press Update first
		## after changing the Rule, before the old garbage state is cleared out.  Then again, more
		## testing is needed before we can draw any solid conclusions.
		$detail .= qq(
		    <td class=$form_match width="5%" align=right>&nbsp;&nbsp;Object:</td>
		    <td class=$form_match align=left>
		    <select name=object onChange="lowlight();submit()">);
		## FIX MINOR:  This is an illegal value= option; should be value='', perhaps?
		$detail .= "\n<option value=></option>";
		foreach my $object_type_item (@obj_types) {
		    if ( defined($object) && $object_type_item eq $object ) {
			$detail .= "\n<option selected value=\"$object_type_item\">$object_type_item</option>";
		    }
		    else {
			$detail .= "\n<option value=\"$object_type_item\">$object_type_item</option>";
		    }
		}

		$detail .= qq(
		    </select>
		    </td>
		    </tr>);

		# FIX THIS:  should this include the 'Add if not exists and assign object' rule as well?
		if ( $rule eq 'Assign object(s)' && defined($object) && $object ne '' ) {
		    my $objects_size = scalar @objects;
		    my $list_size = $objects_size <= 20 ? $objects_size : 20;
		    $list_size = $list_size >= 3 ? $list_size : 3;
		    (my $obj_type = $object) =~ s/ /&nbsp;/g;
		    $detail .= qq(
			<tr>
			<td class=$form_match align=left width="5%">&nbsp;</td>
			<td class=$form_match align=left>&nbsp;</td>
			<td class=$form_match width="7%" align=right valign=top>&nbsp;&nbsp;$obj_type:</td>
			<td class=$form_match align=left valign=top>
			<select name=objects size=$list_size multiple>);
		    my $got_selected = 0;
		    @objects = sort { lc($a) cmp lc($b) } @objects;
		    foreach my $object_item (@objects) {
			foreach my $selected ( @{ $schema{'column'}{$column_id}{'match'}{$match_id}{ $obj_name{$object} } } ) {
			    if ( $object_item eq $selected ) {
				$got_selected = 1;
			    }
			}
			if ($got_selected) {
			    $got_selected = 0;
			    $detail .= "\n<option selected value=\"$object_item\">$object_item</option>";
			}
			else {
			    $detail .= "\n<option value=\"$object_item\">$object_item</option>";
			}
		    }
		    $detail .= qq(
			</select>
			</td>);
		}
	    }
	    else {
		$detail .= qq(
		    <td class=$form_match width="7%" valign=top></td>
		    <td class=$form_match align=left valign=top></td>);
	    }
	    $detail .= qq(
		</tr>
		</table>
		</td>
		</tr>);
	}
    }
    $detail .= $tt->at_end;
    $tab++;
    return $detail;
}

sub import_form(@) {
    my $name           = $_[1];
    my %import_data    = %{ $_[2] };
    my %objects        = %{ $_[3] };
    my %overrides      = %{ $_[4] };
    my $sort_by        = $_[5];
    my $sort_on        = $_[6];
    my $select_on      = $_[7];
    my %record         = %{ $_[8] };
    my $show_overrides = $_[9];
    my %service_objs   = %{ $_[10] };
    my %overview       = %{ $_[11] };
    my $scroll_px      = '600px';
    $select_on = '' if not defined $select_on;
    if ($show_overrides) { $scroll_px = '300px' }
    my %sort_order = ();
    use URI::Escape;
    use HTML::Tooltip::Javascript;
    my $tt = HTML::Tooltip::Javascript->new(
	## URL path to where wz_tooltip.js is.
	javascript_dir => $monarch_js,
	options        => {
	    bgcolor     => '#000000',
	    default_tip => 'No value is specified.',
	    delay       => 0,
	    title       => 'Tooltip',
	},
    );
    my %options = (
	borderwidth => '1',
	padding     => '10',
	bordercolor => '#000000',
	bgcolor     => '#FFFFFF',
	width       => '450',
	fontsize    => '12px'
    );
    my $debug = 0;
    unless ($sort_by) { $sort_by = 'Primary record' }
    unless ($sort_on) { $sort_on = 'exception' }
    my $i = 1;
    $name = uri_escape($name);
    foreach my $rec ( keys %import_data ) {
	unless ($rec) { next }
	if ( $import_data{$rec}{'exception'} ) {
	    if ( $sort_by eq 'Primary record' ) {
		$sort_order{'exception'}{$rec} = $rec;
	    }
	    elsif ( $import_data{$rec}{$sort_by} ) {
		$sort_order{'exception'}{ $import_data{$rec}{$sort_by} } = $rec;
	    }
	    else {
		$sort_order{'exception'}{"n/a $i"} = $rec;
		$i++;
	    }
	}
	elsif ( $import_data{$rec}{'exists'} ) {
	    if ( $sort_by eq 'Primary record' ) {
		$sort_order{'exists'}{$rec} = $rec;
	    }
	    elsif ( $import_data{$rec}{$sort_by} ) {
		$sort_order{'exists'}{ $import_data{$rec}{$sort_by} } = $rec;
	    }
	    else {
		$sort_order{'exists'}{"n/a $i"} = $rec;
		$i++;
	    }
	}
	elsif ( $import_data{$rec}{'new_parent'} ) {
	    if ( $sort_by eq 'New parent' ) {
		$sort_order{'new_parent'}{$rec} = $rec;
	    }
	    elsif ( $import_data{$rec}{$sort_by} ) {
		$sort_order{'new_parent'}{ $import_data{$rec}{$sort_by} } = $rec;
	    }
	    else {
		$sort_order{'new_parent'}{"n/a $i"} = $rec;
		$i++;
	    }
	}
	elsif ( $import_data{$rec}{'delete'} ) {
	    if ( $sort_by eq 'Primary record' ) {
		$sort_order{'delete'}{$rec} = $rec;
	    }
	    elsif ( $import_data{$rec}{$sort_by} ) {
		$sort_order{'delete'}{ $import_data{$rec}{$sort_by} } = $rec;
	    }
	    else {
		$sort_order{'delete'}{"n/a $i"} = $rec;
		$i++;
	    }
	}
	else {
	    if ( $sort_by eq 'Primary record' ) {
		$sort_order{'new'}{$rec} = $rec;
	    }
	    elsif ( $import_data{$rec}{$sort_by} ) {
		$sort_order{'new'}{ $import_data{$rec}{$sort_by} } = $rec;
	    }
	    else {
		$sort_order{'new'}{"n/a $i"} = $rec;
		$i++;
	    }
	}
	if ($debug) {
	    if ( $import_data{$rec}{'delete'} ) {
		$debug .= "<br>$import_data{$rec}{'Name'} e $import_data{$rec}{'exists'} n $import_data{$rec}{'new'}";
	    }

	    #			$debug .= qq(
	    #<br>$rec $sort_by --- $import_data{$rec}{$sort_by} --- $import_data{$rec}{'Name'});
	}
    }

    my $class        = 'row_dk';
    my $class_top    = 'row_dk_top';
    my $class_status = 'row_good';
    my %doc          = doc();
    my $detail       = js_utils();
    if ($debug) {
	$detail .= qq(
<tr>
<td class=data0>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class=$form_class width="100%">$debug</td>
</tr>
</table>
</td>
</tr>);
    }
    my $doc_url = StorProc->doc_section_url('Auto+Discovery', 'AutoDiscovery-RunningAutomationProcesses');
    $detail .= qq(
<script type="text/javascript" language=JavaScript>
function doCheckAll()
{
  with (document.form) {
    for (var i=0; i < elements.length; i++) {
	if (elements[i].type == 'checkbox' && (elements[i].id == 'record_checked'))
	   elements[i].checked = true;
    }
  }
}
function doUnCheckAll()
{
  with (document.form) {
    for (var i=0; i < elements.length; i++) {
	if (elements[i].type == 'checkbox' && (elements[i].id == 'record_checked'))
	   elements[i].checked = false;
    }
  }
}

</script>

<td class=data0>
<table width="100%" cellpadding=7 cellspacing=0 align=left border=0>
<tr>
<td class=wizard_title_heading>$overview{'records'}</td>
<td class=wizard_title_heading style=border:0 align=right>
<input class="submitbutton" type=button onclick="open_window('$doc_url')" value="Help">&nbsp;&nbsp;
<input class=submitbutton type=submit name=import value="Process Records">&nbsp;&nbsp;
<input class=submitbutton type=submit name=discard value="Discard">&nbsp;&nbsp;
<input class=submitbutton type=submit name=edit_schema value="Edit Schema">&nbsp;&nbsp;
<input class=submitbutton type=submit name=close value="Close">
</td>
</tr>
<tr>
<td class=wizard_body colspan=2>
<table width="100%" cellpadding=7 cellspacing=0 align=left border=0>
<tr>
<td class=wizard_body>
$overview{'overview'}
</td>
</tr>
</table>
</td>
</tr>
</table>
</td>
</tr>
<tr>
<td class=data0>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 border=0>
<tr>
<td class=$form_class>&nbsp;<b>Sort&nbsp;by:&nbsp;</b>
<input type=hidden name=view value=import>
<select name=sort_by onChange="lowlight();submit()">);
    my @list = ( 'Primary record', 'Name', 'Address', 'Alias' );
    foreach my $item (@list) {
	if ( $item eq $sort_by ) {
	    $detail .= "\n<option selected value=\"$item\">$item</option>";
	}
	else {
	    $detail .= "\n<option value=\"$item\">$item</option>";
	}
    }

    $options{'title'} = 'Sort by';
    my $docs = "\n$doc{'process'}{'Sort by'}";
    my $tooltip = $tt->tooltip( $docs, \%options );
    $detail .= qq(
</select>&nbsp;&nbsp;<a class=orange href="#" $tooltip tabindex="-1">&nbsp;?&nbsp;</a>
</td>
<td class=$form_class align=left>
<b>Select records:</b>
<input type=hidden name=sort_on value=$sort_on></td>
<script type="text/javascript" language=JavaScript>
function submit_select_on(val) {
	lowlight();
	document.getElementById(val).click();
}
</script>);

    $options{'title'} = 'New Parent';
    $docs = "\n$doc{'process'}{'New Parent'}";
    $tooltip = $tt->tooltip( $docs, \%options );
    $detail .= qq(
<td class=$form_class align=right width=16px style="padding: 0;">
<div style="width:16px; height:16px; border:1px solid #000099; background-color:#0000CC;" onclick="submit_select_on('new_parent');"></div>
</td>
<td class=$form_class align=left><input class=row1button type=submit name=select_on id=new_parent value="New Parent">&nbsp;<a class=orange href="#" $tooltip tabindex="-1">&nbsp;?&nbsp;</a></td>);

    $options{'title'} = 'New Host';
    $docs = "\n$doc{'process'}{'New Host'}";
    $tooltip = $tt->tooltip( $docs, \%options );
    $detail .= qq(
<td class=$form_class align=right width=16px style="padding: 0;">
<div style="width:16px; height:16px; border:1px solid #000099; background-color:#00FF66;" onclick="submit_select_on('new_host');"></div>
</td>
<td class=$form_class align=left><input class=row1button type=submit name=select_on id=new_host value="New Host">&nbsp;<a class=orange href="#" $tooltip tabindex="-1">&nbsp;?&nbsp;</a></td>);

    $options{'title'} = 'Host Exists';
    $docs = "\n$doc{'process'}{'Host Exists'}";
    $tooltip = $tt->tooltip( $docs, \%options );
    $detail .= qq(
<td class=$form_class align=right width=16px style="padding: 0;">
<div style="width:16px; height:16px; border:1px solid #000099; background-color:#8DD9E0;" onclick="submit_select_on('host_exists');"></div>
</td>
<td class=$form_class align=left><input class=row1button type=submit name=select_on id=host_exists value="Host Exists">&nbsp;<a class=orange href="#" $tooltip tabindex="-1">&nbsp;?&nbsp;</a></td>);

    $options{'title'} = 'Exception';
    $docs = "\n$doc{'process'}{'Exception'}";
    $tooltip = $tt->tooltip( $docs, \%options );
    $detail .= qq(
<td class=$form_class align=right width=16px style="padding: 0;">
<div style="width:16px; height:16px; border:1px solid #000099; background-color:#fca54e;" onclick="submit_select_on('exception');"></div>
</td>
<td class=$form_class align=left><input class=row1button type=submit name=select_on id=exception value="Exception">&nbsp;<a class=orange href="#" $tooltip tabindex="-1">&nbsp;?&nbsp;</a></td>);

    $options{'title'} = 'Delete Host';
    $docs = "\n$doc{'process'}{'Delete Host'}";
    $tooltip = $tt->tooltip( $docs, \%options );
    $detail .= qq(
<td class=$form_class align=right width=16px style="padding: 0;">
<div style="width:16px; height:16px; border:1px solid #000099; background-color:#CC0000;" onclick="submit_select_on('delete_host');"></div>
</td>
<td class=$form_class align=left><input class=row1button type=submit name=select_on id=delete_host value="Delete Host">&nbsp;<a class=orange href="#" $tooltip tabindex="-1">&nbsp;?&nbsp;</a></td>
</tr>
</table>
</td>
</tr>
<tr>
<td width="100%" align=center>
<div class="scroll" style="height: auto; max-height: $scroll_px">
<table width="100%" cellpadding=0 cellspacing=0 align=left border=0>);
    my @sorter = ( 'exception', 'delete', 'exists', 'new_parent', 'new' );
    if ( $sort_on eq 'exists' ) {
	@sorter = ( 'exists', 'new_parent', 'new', 'exception', 'delete' );
    }
    elsif ( $sort_on eq 'new' ) {
	@sorter = ( 'new', 'exception', 'delete', 'exists', 'new_parent' );
    }
    elsif ( $sort_on eq 'new_parent' ) {
	@sorter = ( 'new_parent', 'new', 'exception', 'delete', 'exists' );
    }
    elsif ( $sort_on eq 'delete' ) {
	@sorter = ( 'delete', 'exists', 'new_parent', 'new', 'exception' );
    }
    my $display_recs  = 0;
    my $possible_recs = 0;
    foreach my $sorter (@sorter) {
	foreach my $value ( sort { $a cmp $b } keys %{ $sort_order{$sorter} } ) {
	    $possible_recs++;
	    if ( $display_recs >= 100 ) { last }
	    $display_recs++;
	    unless ($value) { next }
	    my $checked = '';
	    my $label   = '';
	    my $rec     = $sort_order{$sorter}{$value};
	    my $uri_rec = uri_escape($rec);
	    if ( $sorter eq 'exception' ) {
		$class        = 'row_lt';
		$class_top    = 'top_exception';
		$class_status = 'row_exception';
		$label        = 'Exception';
		if ( ( $select_on ne '' && $sort_on eq 'exception' ) || ( $select_on eq '' && defined( $record{$rec} ) ) ) { $checked = 'checked' }
	    }
	    elsif ( $sorter eq 'new_parent' ) {
		$class        = 'row_lt';
		$class_top    = 'top_new_parent';
		$class_status = 'row_new_parent';
		$label        = 'New Parent';
		if ( ( $select_on ne '' && $sort_on eq 'new_parent' ) || ( $select_on eq '' && defined( $record{$rec} ) ) ) { $checked = 'checked' }
	    }
	    elsif ( $sorter eq 'new' ) {
		$class        = 'row_lt';
		$class_top    = 'top_new';
		$class_status = 'row_new';
		$label        = 'New Host';
		if ( ( $select_on ne '' && $sort_on eq 'new' ) || ( $select_on eq '' && defined( $record{$rec} ) ) ) { $checked = 'checked' }
	    }
	    elsif ( $sorter eq 'delete' ) {
		$class        = 'row_lt';
		$class_top    = 'top_delete';
		$class_status = 'row_delete';
		$label        = 'Delete';
		if ( ( $select_on ne '' && $sort_on eq 'delete' ) || ( $select_on eq '' && defined( $record{$rec} ) ) ) { $checked = 'checked' }
	    }
	    else {
		$class        = 'row_lt';
		$class_top    = 'top_exists';
		$class_status = 'row_exists';
		$label        = 'Exists';
		if ( ( $select_on ne '' && $sort_on eq 'exists' ) || ( $select_on eq '' && defined( $record{$rec} ) ) ) { $checked = 'checked' }
	    }
	    my $uriesc_hostname    = uri_escape( $import_data{$rec}{'Name'} );
	    my $uriesc_address     = uri_escape( $import_data{$rec}{'Address'} );
	    my $uriesc_alias       = uri_escape( $import_data{$rec}{'Alias'} );
	    my $uriesc_hostprofile = uri_escape( $import_data{$rec}{'Host profile'} );
	    my $uriesc_description = uri_escape( $import_data{$rec}{'Description'} );
	    my $hostname     = $import_data{$rec}{'Name'}         || '<span class=error_standout>(none)</span>';
	    my $address      = $import_data{$rec}{'Address'}      || '<span class=error_standout>(none)</span>';
	    my $host_profile = $import_data{$rec}{'Host profile'} || '<span class=error_standout>(none)</span>';
	    $uriesc_address     = '' if not defined $uriesc_address;
	    $uriesc_description = '' if not defined $uriesc_description;
	    if ( $import_data{$rec}{'delete'} ) {
		$detail .= qq(
	<tr>
	<td class=$class_status align=left colspan=2><b>&nbsp;Record:&nbsp;$rec&nbsp;</b></td>
	<td class=row1 align=right colspan=6>$label</td>
	</tr>
	<tr>
	<td class=$class_status\_top_left align=left valign=top>&nbsp;Name:&nbsp;&nbsp;$hostname
	<input type=hidden name="delete_$rec" value=1>
	<input type=hidden name="host_id_$rec" value="$import_data{$rec}{'host_id'}">
	<input type=hidden name="hostname_$rec" value="$uriesc_hostname">
	</td>
	<td class=$class_top align=left colspan=6 valign=top>Host flagged for deletion</td>
	<td class=$class_status\_top_right width="5%" align=center valign=top><input class=$class type=checkbox id=record_checked name=record value=$uri_rec $checked></td>
	</tr>
	<tr>
	<td class=$class_status\_bottom align=left valign=top colspan=8>&nbsp;</td>
	</tr>);
	    }
	    else {
		$detail .= qq(
	<tr>
	<td class=$class_status align=left colspan=2><b>&nbsp;Record:&nbsp;$rec&nbsp;</b></td>
	<td class=row1 align=right colspan=6>$label</td>
	</tr>
	<tr>
	<td class=$class_status\_top_left align=left valign=top>&nbsp;Name:&nbsp;$hostname
	<input type=hidden name="hostname_$rec" value="$uriesc_hostname"></td>);
		if ( !defined( $import_data{$rec}{'Alias'} ) || $import_data{$rec}{'Alias'} eq '' ) {
		    $detail .= qq(
	<td class=$class_top\_padded align=left valign=top>Alias:&nbsp;&nbsp;<span class=error_standout>(none)</span>
	<input type=hidden name="alias_$rec" value="">
	</td>);
		}
		else {
		    $options{'title'} = 'Alias';
		    delete $options{'left'};
		    my $tt_alias = $tt->tooltip( $import_data{$rec}{'Alias'}, \%options );
		    $detail .= qq(
	<td class=$class_top\_padded align=left valign=top><a class=orange href="#" $tt_alias tabindex="-1">Alias</a>
	<input type=hidden name="alias_$rec" value="$uriesc_alias"></td>);
		}
		$options{'left'} = "1";
		$detail .= qq(
	<td class=$class_top\_padded align=left valign=top>Host&nbsp;profile:&nbsp;$host_profile
	<input type=hidden name="hostprofile_$rec" value="$uriesc_hostprofile">
	</td>);
		if ( $import_data{$rec}{'Service profile'} ) {
		    my $groups = undef;
		    foreach my $profile ( sort { $a cmp $b } keys %{ $import_data{$rec}{'Service profile'} } ) {
			my $uriesc_p = uri_escape($profile);
			$groups .= "$profile<br>";
			$detail .= qq(
	<input type=hidden name="serviceprofile_$rec" value="$uriesc_p">);
		    }
		    $options{'title'} = 'Service profiles';
		    my $g_list = $tt->tooltip( $groups, \%options );
		    $detail .= qq(
	<td class=$class_top\_padded align=left valign=top><a class=orange href="#" $g_list tabindex="-1">Service profiles</a></td>);
		}
		else {
		    $detail .= qq(
	<td class=$class_top\_padded align=left valign=top><span class=light>Service profiles</span></td>);
		}
		my $services = undef;
		if ( $import_data{$rec}{'Service'} ) {
		    foreach my $service ( sort { $a cmp $b } keys %{ $import_data{$rec}{'Service'} } ) {
			unless ( $service && $import_data{$rec}{'Service'}{$service} ) {
			    next;
			}
			my $uriesc_svc = uri_escape($service);
			my $uriesc_arg = uri_escape( $import_data{$rec}{'Service'}{$service}{'command_line'} );
			$uriesc_arg = '' if not defined $uriesc_arg;
			$detail .= qq(
	<input type=hidden name="services_$rec" value="$uriesc_svc">
	<input type=hidden name="command_line_$rec-$uriesc_svc" value="$uriesc_arg">);
			my $cnt    = 0;
			my %sorted = ();
			foreach my $instance ( keys %{ $import_data{$rec}{'Service'}{$service}{'instances'} } ) {
			    my $key = $instance;
			    $key =~ s/^_//;
			    $sorted{$key} = $instance;
			}
			foreach my $key ( sort { $a <=> $b } keys %sorted ) {
			    my $uriesc_inst = uri_escape( $sorted{$key} );
			    if ( $cnt ) {
				$services .= ",&nbsp;";
				if ( $cnt % 3 == 0 ) { $services .= "<br>"; }
			    }
			    ++$cnt;
			    $services .= "$service$sorted{$key}";
			    my $uriesc_arg = uri_escape( $import_data{$rec}{'Service'}{$service}{'instances'}{ $sorted{$key} }{'arguments'} );
			    my $status     = $import_data{$rec}{'Service'}{$service}{'instance'}{ $sorted{$key} }{'status'};
			    $detail .= qq(
	<input type=hidden name="service_instances_$rec-$uriesc_svc" value="$uriesc_inst">
	<input type=hidden name="host_serv_inst_args_$rec-$uriesc_svc-$uriesc_inst" value="$uriesc_arg">);
			}
			if ( keys %{ $import_data{$rec}{'Service'}{$service}{'instances'} } ) {
			    $services .= "<br>";
			}
			else {
			    $services .= "$service<br>";
			}
		    }
		}
		if ($services) {
		    $options{'title'} = 'Discovered Services';
		    my $g_list = $tt->tooltip( $services, \%options );
		    $detail .= qq(
	<td class=$class_top\_padded align=left valign=top><a class=orange href="#" $g_list tabindex="-1">Discovered Services</a></td>);
		}
		else {
		    $detail .= qq(
	<td class=$class_top\_padded align=left valign=top><span class=light>Discovered Services</span></td>);
		}
		if ( $import_data{$rec}{'Parent'} ) {
		    my $groups = undef;
		    foreach my $parent ( sort { $a cmp $b } keys %{ $import_data{$rec}{'Parent'} } ) {
			my $uriesc_p = uri_escape($parent);
			$groups .= "$parent<br>";
			$detail .= qq(
	<input type=hidden name="parent_$rec" value="$uriesc_p">);
		    }
		    $options{'title'} = 'Parents';
		    my $g_list = $tt->tooltip( $groups, \%options );
		    $detail .= qq(
	<td class=$class_top\_padded align=left valign=top><a class=orange href="#" $g_list tabindex="-1">Parents</a></td>);
		}
		else {
		    $detail .= qq(
	<td class=$class_top\_padded align=left valign=top><span class=light>Parents</span></td>);
		}
		if ( $import_data{$rec}{'Host group'} ) {
		    my $groups = undef;
		    foreach my $hostgroup ( sort { $a cmp $b } keys %{ $import_data{$rec}{'Host group'} } ) {
			my $uriesc_hg = uri_escape($hostgroup);
			$groups .= "$hostgroup<br>";
			$detail .= qq(
	<input type=hidden name="hostgroup_$rec" value="$uriesc_hg">);
		    }
		    $options{'title'} = 'Host Groups';
		    my $g_list = $tt->tooltip( $groups, \%options );
		    $detail .= qq(
	<td class=$class_top\_padded align=left valign=top><a class=orange href="#" $g_list tabindex="-1">Host groups</a></td>);
		}
		else {
		    $detail .= qq(
	<td class=$class_top\_padded align=left valign=top><span class=light>Host groups</span></td>);
		}
		my $new_parent = $import_data{$rec}{'new_parent'};
		$new_parent = '' if not defined $new_parent;
		my $description = $import_data{$rec}{'Description'};
		$description = '' if not defined $description;
		$detail .= qq(
	<td class=$class_status\_top_right align=center><input class=$class type=checkbox id=record_checked name=record value=$uri_rec $checked></td>
	</tr>
	<tr>
	<td class=$class_status\_left align=left valign=top>&nbsp;Address:&nbsp;$address
	<input type=hidden name="address_$rec" value="$uriesc_address">
	</td>
	<td class=$class\_padded align=left valign=top colspan=4>Description:&nbsp;$description
	<input type=hidden name="description_$rec" value="$uriesc_description">
	<input type=hidden name="new_parent_$rec" value="$new_parent">
	</td>);
		if ( $import_data{$rec}{'Group'} ) {
		    my $groups = undef;
		    foreach my $group ( sort { $a cmp $b } keys %{ $import_data{$rec}{'Group'} } ) {
			my $uriesc_g = uri_escape($group);
			$groups .= "$group<br>";
			$detail .= qq(
	<input type=hidden name="group_$rec" value="$uriesc_g">);
		    }
		    $options{'title'} = 'Groups';
		    my $g_list = $tt->tooltip( $groups, \%options );
		    $detail .= qq(
	<td class=$class\_padded align=left valign=top><a class=orange href="#" $g_list tabindex="-1">Groups</a></td>);
		}
		else {
		    $detail .= qq(
	<td class=$class\_padded align=left valign=top><span class=light>Groups</span></td>);
		}
		if ( $import_data{$rec}{'Contact group'} ) {
		    my $groups = undef;
		    foreach my $group ( sort { $a cmp $b } keys %{ $import_data{$rec}{'Contact group'} } ) {
			my $uriesc_g = uri_escape($group);
			$groups .= "$group<br>";
			$detail .= qq(
	<input type=hidden name="contactgroup_$rec" value="$uriesc_g">);
		    }
		    $options{'title'} = 'Contact Groups';
		    my $g_list = $tt->tooltip( $groups, \%options );
		    $detail .= qq(
	<td class=$class\_padded align=left valign=top><a class=orange href="#" $g_list tabindex="-1">Contact&nbsp;groups</a></td>);
		}
		else {
		    $detail .= qq(
	<td class=$class\_padded align=left valign=top><span class=light>Contact&nbsp;groups</span></td>);
		}
		$detail .= qq(
	<td class=$class_status\_right align=center width="5%" valign=top><input type=submit class=smallsubmitbutton name=edit_rec_$uri_rec value="edit"></td>
	</tr>
	<tr>
	<td class=$class_status\_bottom align=left valign=top colspan=8>&nbsp;</td>
	</tr>);
	    }
	}
    }
    $detail .= qq(
</table>
</div>
</td>
</tr>);

    if ( $possible_recs > $display_recs ) {
	$detail .= qq(
<tr>
<td class=data0>
<table width="100%" cellpadding=7 border=0>
<tr>
<td class=wizard_body>
The set above is limited to the first $display_recs records.
Additional records are also available, and will be displayed once these are processed.
The Sort and Select criteria above can also be used to change the order of displayed records and bring others into view.
</td>
</tr>
</table>
</td>
</tr>);
    }

    my $javascript = qq(
<script type="text/javascript" language=JavaScript>
);

    if ($show_overrides) {
	my %checked = ();
	$checked{'profiles_host_checked'}    = $overrides{'profiles_host_checked'}    ? 'checked' : '';
	$checked{'parents_checked'}          = $overrides{'parents_checked'}          ? 'checked' : '';
	$checked{'profiles_service_checked'} = $overrides{'profiles_service_checked'} ? 'checked' : '';
	$checked{'contactgroups_checked'}    = $overrides{'contactgroups_checked'}    ? 'checked' : '';
	$checked{'monarch_groups_checked'}   = $overrides{'monarch_groups_checked'}   ? 'checked' : '';
	$checked{'hostgroups_checked'}       = $overrides{'hostgroups_checked'}       ? 'checked' : '';
	$checked{'services_checked'}         = $overrides{'services_checked'}         ? 'checked' : '';
	if ( defined( $overrides{'profiles_service_merge'} ) && $overrides{'profiles_service_merge'} eq 'replace' ) {
	    $checked{'profiles_service_merge_replace'} = 'checked';
	    $checked{'profiles_service_merge_merge'} = '';
	}
	else {
	    $checked{'profiles_service_merge_replace'} = '';
	    $checked{'profiles_service_merge_merge'} = 'checked';
	}
	if ( defined( $overrides{'contactgroups_merge'} ) && $overrides{'contactgroups_merge'} eq 'replace' ) {
	    $checked{'contactgroups_merge_replace'} = 'checked';
	    $checked{'contactgroups_merge_merge'} = '';
	}
	else {
	    $checked{'contactgroups_merge_replace'} = '';
	    $checked{'contactgroups_merge_merge'} = 'checked';
	}
	if ( defined( $overrides{'monarch_groups_merge'} ) && $overrides{'monarch_groups_merge'} eq 'replace' ) {
	    $checked{'monarch_groups_merge_replace'} = 'checked';
	    $checked{'monarch_groups_merge_merge'} = '';
	}
	else {
	    $checked{'monarch_groups_merge_replace'} = '';
	    $checked{'monarch_groups_merge_merge'} = 'checked';
	}
	if ( defined( $overrides{'hostgroups_merge'} ) && $overrides{'hostgroups_merge'} eq 'replace' ) {
	    $checked{'hostgroups_merge_replace'} = 'checked';
	    $checked{'hostgroups_merge_merge'} = '';
	}
	else {
	    $checked{'hostgroups_merge_replace'} = '';
	    $checked{'hostgroups_merge_merge'} = 'checked';
	}
	if ( defined( $overrides{'services_merge'} ) && $overrides{'services_merge'} eq 'replace' ) {
	    $checked{'services_merge_replace'} = 'checked';
	    $checked{'services_merge_merge'} = '';
	}
	else {
	    $checked{'services_merge_replace'} = '';
	    $checked{'services_merge_merge'} = 'checked';
	}
	my $got_selected = undef;
	$options{'title'} = 'Disable Overrides';
	$docs = "\n$doc{'overrides'}{'disable'}";
	my $disable = $tt->tooltip( $docs, \%options );
	$options{'title'} = 'Overrides';
	$docs             = "\n$doc{'overrides'}{'usage'}";
	my $usage = $tt->tooltip( $docs, \%options );
	$detail .= qq(
<tr>
<td class=buttons>
<table width="100%" cellpadding=0 cellspacing=0 border=0>
<tr>
<td style=border:0 align=left>
<input class=submitbutton type=submit name=disable_overrides value="Disable Overrides">
&nbsp;&nbsp;<a class=orange href="#" $disable tabindex="-1">&nbsp;?&nbsp;</a>
</td>
<td align=right>
<input class=submitbutton type=button value="Check All" onclick=doCheckAll()>&nbsp;&nbsp;
<input class=submitbutton type=button value="Uncheck All" onclick=doUnCheckAll()>
</td>
</tr>
</table>
</td>
</tr>
<tr>
<td class=data0>
<table width="100%" cellpadding=7 cellspacing=0 align=left border=0>
	<tr>
	<td class=wizard_title_heading align=left colspan=2>&nbsp;Override Options&nbsp;&nbsp;<a class=orange href="#" $usage tabindex="-1">&nbsp;?&nbsp;</a></td>
	</tr>
	<tr>
	<td class=$form_class valign=top width="50%" style="padding-right: 2px;">
		<table width="100%" cellpadding=$global_cell_pad cellspacing=2 align=left border=0>
			<tr>
			<td class=row2 valign=top>
				<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
					<tr>
					<td class=row2 align=left width=190px valign=top><input class=$form_class type=checkbox name=profiles_host_checked $checked{'profiles_host_checked'} onclick="modifyWidgets('profiles_host_checked');">&nbsp;<b>Host&nbsp;profile:</b></td>
					<td class=row2 align=left valign=top>
					<select name=profiles_host disabled class=disabled>
					<option value=>&nbsp;&nbsp;&nbsp;&nbsp;</option>);

	foreach my $item ( @{ $objects{'profiles_host'} } ) {
	    if ( defined( $overrides{'profiles_host'} ) && $item eq $overrides{'profiles_host'} ) {
		$detail .= "\n<option selected value=\"$item\">$item</option>";
	    }
	    else {
		$detail .= "\n<option value=\"$item\">$item</option>";
	    }
	}
	$detail .= qq(
					</select>
					</td>
					</tr>
				</table>
			</td>
			</tr>
			<tr>
			<td class=row2 valign=top>
				<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
					<tr>
					<td class=row2 align=left width=190px height=1px valign=top><input class=$form_class type=checkbox name=profiles_service_checked $checked{'profiles_service_checked'} onclick="modifyWidgets('profiles_service_checked');">&nbsp;<b>Service&nbsp;profiles:</b></td>
					<td class=row2 align=left valign=top rowspan=3>
					<select name=profiles_service size=6 multiple disabled class=disabled>
					<option value=>&nbsp;&nbsp;&nbsp;&nbsp;</option>);
	foreach my $item ( @{ $objects{'profiles_service'} } ) {
	    foreach my $selected ( @{ $overrides{'profiles_service'} } ) {
		if ( $item eq $selected ) { $got_selected = 1 }
	    }
	    if ($got_selected) {
		$got_selected = undef;
		$detail .= "\n<option selected value=\"$item\">$item</option>";
	    }
	    else {
		$detail .= "\n<option value=\"$item\">$item</option>";
	    }
	}

	$detail .= qq(
					</select>
					</td>
					<tr>
					<td class=row2_disabled name=profiles_service_label id=profiles_service_label align=left width=190px height=1px valign=top><input type=radio class=radio name=profiles_service_merge value=merge $checked{'profiles_service_merge_merge'} disabled>&nbsp;Merge</td>
					</tr>
					<tr>
					<td class=row2_disabled name=profiles_service_label id=profiles_service_label align=left width=190px valign=top><input type=radio class=radio name=profiles_service_merge value=replace $checked{'profiles_service_merge_replace'} disabled>&nbsp;Replace</td>
					</tr>
				</table>
			</td>
			</tr>
			<tr>
			<td class=row2 valign=top>
				<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
					<tr>
					<td class=row2 align=left width=190px height=1px valign=top><input class=$form_class type=checkbox name=parents_checked $checked{'parents_checked'} onclick="modifyWidgets('parents_checked');">&nbsp;<b>Parent:</b></td>
					<td class=row2 align=left valign=top rowspan=3>
					<select name=parents size=8 multiple disabled class=disabled>
					<option value=>&nbsp;&nbsp;&nbsp;&nbsp;</option>);
	$got_selected = undef;
	foreach my $item ( @{ $objects{'parents'} } ) {
	    if ( $item eq $overrides{'parents'} ) {
		$detail .= "\n<option selected value=\"$item\">$item</option>";
	    }
	    else {
		$detail .= "\n<option value=\"$item\">$item</option>";
	    }
	}
	$detail .= qq(
					</select>
					</td>
					<tr>
					<td class=row2_disabled name=parents_label align=left id=parents_label width=190px height=1px valign=top><input type=radio class=radio name=parents_merge value=merge $checked{'profiles_service_merge_merge'} disabled>&nbsp;Merge</td>
					</tr>
					<tr>
					<td class=row2_disabled name=parents_label id=parents_label align=left width=190px valign=top><input type=radio class=radio name=parents_merge value=replace $checked{'profiles_service_merge_replace'} disabled>&nbsp;Replace</td>
					</tr>
				</table>
			</td>
			</tr>
		</table>
	</td>
	<td class=$form_class valign=top width="50%" style="padding-left: 2px;">
		<table width="100%" cellpadding=$global_cell_pad cellspacing=2 align=left border=0>
			<tr>
			<td class=row2 valign=top>
			<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
				<tr>
				<td class=row2 align=left width=190px height=1px valign=top><input class=$form_class type=checkbox name=monarch_groups_checked $checked{'monarch_groups_checked'} onclick="modifyWidgets('monarch_groups_checked');">&nbsp;<b>Groups:</b></td>
				<td class=row2 align=left valign=top rowspan=3>
				<select name=monarch_groups size=5 multiple disabled class=disabled>
				<option value=>&nbsp;&nbsp;&nbsp;&nbsp;</option>);
	foreach my $item ( @{ $objects{'monarch_groups'} } ) {
	    foreach my $selected ( @{ $overrides{'monarch_groups'} } ) {
		if ( $item eq $selected ) { $got_selected = 1 }
	    }
	    if ($got_selected) {
		$got_selected = undef;
		$detail .= "\n<option selected value=\"$item\">$item</option>";
	    }
	    else {
		$detail .= "\n<option value=\"$item\">$item</option>";
	    }
	}

	$detail .= qq(
				</select>
				</td>
				<tr>
				<td class=row2_disabled name=monarch_groups_label id=monarch_groups_label align=left width=190px height=1px valign=top><input type=radio class=radio name=monarch_groups_merge value=merge $checked{'monarch_groups_merge_merge'} disabled>&nbsp;Merge</td>
				</tr>
				<tr>
				<td class=row2_disabled name=monarch_groups_label id=monarch_groups_label align=left width=190px valign=top><input type=radio class=radio name=monarch_groups_merge value=replace $checked{'monarch_groups_merge_replace'} disabled>&nbsp;Replace</td>
				</tr>
			</table>
			</td>
			</tr>
			<tr>
			<td class=row2 valign=top>
				<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
					<tr>
					<td class=row2 align=left width=190px height=1px valign=top><input class=$form_class type=checkbox name=hostgroups_checked $checked{'hostgroups_checked'} onclick="modifyWidgets('hostgroups_checked');">&nbsp;<b>Host&nbsp;groups:</b></td>
					<td class=row2 align=left valign=top rowspan=3>
					<select name=hostgroups size=5 multiple disabled class=disabled>
					<option value=>&nbsp;&nbsp;&nbsp;&nbsp;</option>);
	foreach my $item ( @{ $objects{'hostgroups'} } ) {
	    foreach my $selected ( @{ $overrides{'hostgroups'} } ) {
		if ( $item eq $selected ) { $got_selected = 1 }
	    }
	    if ($got_selected) {
		$got_selected = undef;
		$detail .= "\n<option selected value=\"$item\">$item</option>";
	    }
	    else {
		$detail .= "\n<option value=\"$item\">$item</option>";
	    }
	}
	$detail .= qq(
					</select>
					</td>
					<tr>
					<td class=row2_disabled name=hostgroups_label id=hostgroups_label align=left width=190px height=1px valign=top><input type=radio class=radio name=hostgroups_merge value=merge $checked{'hostgroups_merge_merge'} disabled>&nbsp;Merge</td>
					</tr>
					<tr>
					<td class=row2_disabled name=hostgroups_label id=hostgroups_label align=left width=190px valign=top><input type=radio class=radio name=hostgroups_merge value=replace $checked{'hostgroups_merge_replace'} disabled>&nbsp;Replace</td>
					</tr>
				</table>
			</td>
			</tr>

			<tr>
			<td class=row2 valign=top>
			<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
				<tr>
				<td class=row2 align=left width=190px height=1px valign=top><input class=$form_class type=checkbox name=contactgroups_checked $checked{'contactgroups_checked'} onclick="modifyWidgets('contactgroups_checked');">&nbsp;<b>Contact&nbsp;groups:</b></td>
				<td class=row2 align=left valign=top rowspan=3>
				<select name=contactgroups size=5 multiple disabled class=disabled>
				<option value=>&nbsp;&nbsp;&nbsp;&nbsp;</option>);
	foreach my $item ( @{ $objects{'contactgroups'} } ) {
	    foreach my $selected ( @{ $overrides{'contactgroups'} } ) {
		if ( $item eq $selected ) { $got_selected = 1 }
	    }
	    if ($got_selected) {
		$got_selected = undef;
		$detail .= "\n<option selected value=\"$item\">$item</option>";
	    }
	    else {
		$detail .= "\n<option value=\"$item\">$item</option>";
	    }
	}

	$detail .= qq(
				</select>
				</td>
				<tr>
				<td class=row2_disabled name=contactgroups_label id=contactgroups_label align=left width=190px height=1px valign=top><input type=radio class=radio name=contactgroups_merge value=merge $checked{'contactgroups_merge_merge'} disabled>&nbsp;Merge</td>
				</tr>
				<tr>
				<td class=row2_disabled name=contactgroups_label id=contactgroups_label align=left width=190px valign=top><input type=radio class=radio name=contactgroups_merge value=replace $checked{'contactgroups_merge_replace'} disabled>&nbsp;Replace</td>
				</tr>
			</table>
			</td>
			</tr>

		</table>
	</td>
	</tr>
	</table>
	</td>
	</tr>
	<tr>
	<td class=data0>
	<table width="100%" cellpadding=7 cellspacing=0 align=left border=0>
	<tr>
	<td class=wizard_title_heading align=left colspan=2 valign=top>
	<input class=$form_class type=checkbox name=services_checked $checked{'services_checked'} onclick="modifyWidgets('services_checked');">&nbsp;Additional Services and Instances&nbsp;&nbsp;
	<span class=wizard_title_heading_disabled name=services_label id=services_label>
	<input type=radio class=radio_disabled name=services_merge value=merge $checked{'services_merge_merge'} disabled>&nbsp;Merge&nbsp;&nbsp;
	<input type=radio class=radio_disabled name=services_merge value=replace $checked{'services_merge_replace'} disabled>&nbsp;Replace
	</span>
	</td>
	</tr>
	<tr>
	<td colspan=2>
	<table width="100%" cellpadding=3 cellspacing=0 align=left border=0>
		<tr>
		<td class=column_head align=left width=15px>&nbsp;</td>
		<td class=column_head align=left width=250px>Service name</td>
		<td class=column_head align=left width=200px>Check command</td>
		<td class=column_head align=left width=300px>Arguments</td>
		<td class=column_head align=left>&nbsp;</td>
		</tr>);
	my $got_services = 0;
	$got_selected = 0;
	foreach my $service ( sort { $a cmp $b } keys %{ $overrides{'Service'} } ) {
	    unless ($service) { next }
	    $got_services = 1;
	    my $class        = 'row1_unpadded';
	    my $button_class = 'column';
	    if ( $service_objs{$service}{'service_selected'} ) {
		$got_selected = 1;
		$button_class = 'match_selected';
		$class        = 'match_selected';
		$detail .= qq(
			<tr>
			<td class=$class name=service_label id=service_label align=left valign=top width=15px><input type=radio class=radio_orange name=service_selected value="$service" checked onClick="lowlight();submit()"></td>);
	    }
	    else {
		$detail .= qq(
			<tr>
			<td class=$class name=service_label id=service_label align=left valign=top width=15px><input type=radio class=radio name=service_selected value="$service" onClick="lowlight();submit()"></td>);
	    }
	    $detail .= qq(
		<td class=$class name=service_label id=service_label align=left valign=top>$service</td>
		<input type=hidden name="services" value="$service">
		<input type=hidden name="check_command_$service" value="$service_objs{$service}{'check_command'}">
		<td class=$class name=service_label id=service_label align=left valign=top>$service_objs{$service}{'check_command'}&nbsp;&nbsp;</td>);
	    if ( $service_objs{$service}{'service_selected'} && !( keys %{ $service_objs{$service}{'instances'} } ) ) {
		$detail .= qq(
		<td class=$class name=service_label id=service_label align=left valign=top><input class=text_disabled type=text size=40 name="arguments_$service" value="$service_objs{$service}{'arguments'}"></td>);
	    }
	    else {
		$detail .= qq(
		<td class=$class name=service_label id=service_label align=left valign=top><input type=hidden name="arguments_$service" value="$service_objs{$service}{'arguments'}">$service_objs{$service}{'arguments'}</td>);
	    }
	    $detail .= qq(
		<td class=$class name=service_label id=service_label align=right valign=top><input class=$button_class\_disabled type="submit" name="remove_service_$service" value="remove service" disabled tabindex=7></td>
		</tr>);
	    my @alph_sorted   = ();
	    my @num_sorted    = ();
	    my %instance_sort = ();
	    foreach my $instance ( keys %{ $service_objs{$service}{'instances'} } ) {
		my $inst = $instance;
		$inst =~ s/^_//;
		$inst .= rand();
		if ( $inst =~ /^\d+/ ) {
		    push @num_sorted, $inst;
		}
		else {
		    push @alph_sorted, $inst;
		}
		$instance_sort{$inst}{'name'} = $instance;
	    }
	    foreach my $inst ( sort { $a <=> $b } @num_sorted ) {
		my $instance = $instance_sort{$inst}{'name'};
		$detail .= qq(
		<tr>
		<td class=$class align=left>&nbsp;</td>
		<td class=$class name=service_label id=service_label align=left>$service$instance</td>
		<input type=hidden name="instances_$service" value="$instance">
		<td class=$class name=service_label id=service_label align=left>$service_objs{$service}{'check_command'}</td>);
		if ( $service_objs{$service}{'service_selected'} ) {
		    $detail .= qq(
		<td class=$class align=left><input class=text_disabled type=text size=40 name="instances_arguments_$service\_$instance" value="$service_objs{$service}{'instances'}{$instance}"></td>
		<td class=$class align=right><input class=$button_class\_disabled type="submit" name="remove_instance_$service\:-:$instance" value="remove instance" disabled tabindex=7></td>
		</tr>);
		}
		else {
		    $detail .= qq(
		<td class=$class name=service_label id=service_label align=left>$service_objs{$service}{'instances'}{$instance}</td>
		<input type=hidden name="instances_$service" value="$instance">
		<input type=hidden name="instances_arguments_$service\_$instance" value="$service_objs{$service}{'instances'}{$instance}">
		<td class=$class align=right><input class=$button_class\_disabled type="submit" name="remove_instance_$service\:-:$instance" value="remove instance" disabled tabindex=7></td>
		</tr>);
		}
	    }
	    foreach my $inst ( sort { lc($a) cmp lc($b) } @alph_sorted ) {
		my $instance = $instance_sort{$inst}{'name'};
		$detail .= qq(
		<tr>
		<td class=$class align=left>&nbsp;</td>
		<td class=$class name=service_label id=service_label align=left>$service$instance</td>
		<input type=hidden name="instances_$service" value="$instance">
		<td class=$class name=service_label id=service_label align=left>$service_objs{$service}{'check_command'}</td>);
		if ( $service_objs{$service}{'service_selected'} ) {
		    $detail .= qq(
		<td class=$class align=left><input class=text_disabled type=text size=40 name="instances_arguments_$service\_$instance" value="$service_objs{$service}{'instances'}{$instance}"></td>
		<td class=$class align=right><input class=$button_class\_disabled type="submit" name="remove_instance_$service\:-:$instance" value="remove instance" disabled tabindex=7></td>
		</tr>);
		}
		else {
		    $detail .= qq(
		<td class=$class name=service_label id=service_label align=left>$service_objs{$service}{'instances'}{$instance}</td>
		<input type=hidden name="instances_$service" value="$instance">
		<input type=hidden name="instances_arguments_$service\_$instance" value="$service_objs{$service}{'instances'}{$instance}">
		<td class=$class align=right><input class=$button_class\_disabled type="submit" name="remove_instance_$service\:-:$instance" value="remove instance" disabled tabindex=7></td>
		</tr>);
		}
	    }
	}
	my $can_add_instance;
	if ( $got_services && $got_selected ) {
	    $can_add_instance = 'true';
	    $javascript .= qq(
function initialInstanceStates() {
	document.form.instance_add.focus();
	self.scrollTo(0,200);
}
SafeAddOnload(initialInstanceStates);
);
	}
	else {
	    $can_add_instance = 'false';
	    $javascript .= qq(
function initialWidgetStates() {
	document.form.profiles_host_checked.focus();
	self.scrollTo(0,200);
}
SafeAddOnload(initialWidgetStates);
);
	}
	unless ($got_services) {
	    $detail .= qq(
		<tr>
		<td class=$form_class\_disabled name=service_label id=service_label align=left colspan=6>No services have been selected.</td>
		</tr>);
	}
	$detail .= qq(
	</table>
	<table width="100%" cellpadding=7 cellspacing=0 align=left border=0 style="margin-top: 7px;">
		<tr>
		<td class=row2>
		<table cellpadding=3 cellspacing=0 align=left border=0>
			<tr>
			<td class=row2_disabled name=service_label id=service_label>Service:
			<select name=service_add disabled class=disabled>
			<option value=></option>);
	foreach my $item ( @{ $objects{'services'} } ) {
	    unless ( $overrides{'Service'}{$item} ) {
		$detail .= "\n\t\t\t<option value=\"$item\">$item</option>";
	    }
	}

	$detail .= qq(
			</select>
			</td>
			<td class=row2 valign=top align=left>&nbsp; <input class=submitbutton_row2_disabled type="submit" name=add_service value="Add Service" disabled tabindex=7></td>
			</tr>
		</table>
		</td>
		<td class=row2>
		<table cellpadding=3 cellspacing=0 align=left border=0>
			<tr>
			<td class=row2_disabled name=instance_label id=instance_label>Service Name Instance Suffix: <input class=text_disabled disabled type=text size=15 name=instance_add value=""></td>
			<td class=row2 valign=top align=left>&nbsp; <input class=submitbutton_row2_disabled type="submit" name=add_instance value="Add Instance" disabled tabindex=7></td>
			</tr>
		</table>
		</td>
		</tr>
	</table>
	</td>
	</tr>
</table>

<script type="text/javascript" language=JavaScript>
function toggleChoices(disabled, buttons, labels) {
	if (typeof(buttons) == 'string') {
		buttons = [ buttons ];
	}
	if (typeof(labels) == 'string') {
		labels = [ labels ];
	}
	for (var but=buttons.length;--but>=0;) {
		var choices = [];
		if (buttons[but].match(/[*]/)) {
			var pattern = new RegExp ('^' + buttons[but].replace(/[*]/, ''));
			var maybe = document.body.getElementsByTagName('input');
			for (var i=maybe.length;--i>=0;) {
				if (typeof(maybe[i].name) == 'string' && maybe[i].name.match(pattern)) {
					choices.push(maybe[i]);
				}
			}
		}
		else {
			choices = document.getElementsByName(buttons[but]);
		}
		for (var i=choices.length;--i>=0;) {
			choices[i].disabled = disabled;
			if (disabled) {
				choices[i].className = choices[i].className.replace(/(_disabled)?\$/, '_disabled');
			}
			else {
				choices[i].className = choices[i].className.replace(/(_disabled)?\$/, '');
			}
		}
	}
	for (var lab=labels.length;--lab>=0;) {
		var ideas = document.getElementsByName(labels[lab]);
		for (var i=ideas.length;--i>=0;) {
			if (disabled) {
				ideas[i].className = ideas[i].className.replace(/(_disabled)?\$/, '_disabled');
			}
			else {
				ideas[i].className = ideas[i].className.replace(/(_disabled)?\$/, '');
			}
		}
	}
}
function modifyWidgets(section) {
	var checked;
	if (section == 'profiles_host_checked') {
		checked = document.form.profiles_host_checked.checked;
		document.form.profiles_host.disabled = !checked;
		document.form.profiles_host.className = checked ? 'enabled' : 'disabled';
	}
	else if (section == 'profiles_service_checked') {
		checked = document.form.profiles_service_checked.checked;
		document.form.profiles_service.disabled = !checked;
		document.form.profiles_service.className = checked ? 'enabled' : 'disabled';
		toggleChoices (!checked, 'profiles_service_merge', 'profiles_service_label');
	}
	else if (section == 'parents_checked') {
		checked = document.form.parents_checked.checked;
		document.form.parents.disabled = !checked;
		document.form.parents.className = checked ? 'enabled' : 'disabled';
		toggleChoices (!checked, 'parents_merge', 'parents_label');
	}
	else if (section == 'monarch_groups_checked') {
		checked = document.form.monarch_groups_checked.checked;
		document.form.monarch_groups.disabled = !checked;
		document.form.monarch_groups.className = checked ? 'enabled' : 'disabled';
		toggleChoices (!checked, 'monarch_groups_merge', 'monarch_groups_label');
	}
	else if (section == 'hostgroups_checked') {
		checked = document.form.hostgroups_checked.checked;
		document.form.hostgroups.disabled = !checked;
		document.form.hostgroups.className = checked ? 'enabled' : 'disabled';
		toggleChoices (!checked, 'hostgroups_merge', 'hostgroups_label');
	}
	else if (section == 'contactgroups_checked') {
		checked = document.form.contactgroups_checked.checked;
		document.form.contactgroups.disabled = !checked;
		document.form.contactgroups.className = checked ? 'enabled' : 'disabled';
		toggleChoices (!checked, 'contactgroups_merge', 'contactgroups_label');
	}
	else if (section == 'services_checked') {
		checked = document.form.services_checked.checked;
		document.form.service_add.disabled = !checked;
		document.form.service_add.className = checked ? 'enabled' : 'disabled';
		toggleChoices (!checked,
			[ 'services_merge', 'service_selected', 'add_service',
				'arguments_*', 'instances_arguments_*', 'remove_service_*', 'remove_instance_*' ],
			[ 'services_label', 'service_label' ]);
		if ($can_add_instance) {
			toggleChoices (!checked, [ 'instance_add', 'add_instance' ], 'instance_label');
		}
	}
}
function modifyAllWidgets() {
	modifyWidgets('profiles_host_checked');
	modifyWidgets('profiles_service_checked');
	modifyWidgets('parents_checked');
	modifyWidgets('monarch_groups_checked');
	modifyWidgets('hostgroups_checked');
	modifyWidgets('contactgroups_checked');
	modifyWidgets('services_checked');
}
// FIX THIS:  For some as-yet unknown reason,
// SafeAddOnload(modifyAllWidgets);
// isn't working here in IE8, though it works elsewhere in IE8.
// Perhaps there is a conflict with one of these calls above:
// SafeAddOnload(initialInstanceStates);
// SafeAddOnload(initialWidgetStates);
// though that would imply that SafeAddOnload() doesn't do what it claims to.
// To work around this for now, we use this alternate formulation instead.
// Like "window.onload = modifyAllWidgets;" but does not override any existing onload handlers.
if (window.attachEvent) {window.attachEvent('onload', modifyAllWidgets);}
else if (window.addEventListener) {window.addEventListener('load', modifyAllWidgets, false);}
else {document.addEventListener('load', modifyAllWidgets, false);}
</script>

</td>
</tr>);
    }
    else {
	$options{'title'} = 'Enable Overrides';
	$docs = "\n$doc{'overrides'}{'enable'}";
	my $tooltip = $tt->tooltip( $docs, \%options );

	$detail .= qq(
<tr>
<td class=buttons>
<table width="100%" cellpadding=0 cellspacing=0 border=0>
<tr>
<td style=border:0 align=left>
<input class=submitbutton type=submit name=enable_overrides value="Enable Overrides">
&nbsp;&nbsp;<a class=orange href="#" $tooltip tabindex="-1">&nbsp;?&nbsp;</a>
</td>
<td align=right>
<input class=submitbutton type=button value="Check All" onclick=doCheckAll()>&nbsp;&nbsp;
<input class=submitbutton type=button value="Uncheck All" onclick=doUnCheckAll()>
</td>
</tr>
</table>
</td>
</tr>);
    }
    $detail .= $tt->at_end;
    $detail .= qq(
</form>
</table>
</td>
</tr>);
    $javascript .= "\n</script>";
    return $javascript . $detail;
}

sub import_edit(@) {
    my $record_esc   = $_[1];
    my %host_data    = %{ $_[2] };
    my %objects      = %{ $_[3] };
    my %service_objs = %{ $_[4] };
    my $got_selected = undef;
    my $record       = uri_unescape($record_esc);
    my $tab          = 0;
    my $javascript   = qq(
<script type="text/javascript" language=JavaScript>
function setSubmit() {
	document.form.add_instance.className = 'submitbutton';
	document.form.instance_add.disabled = false;
}
);

    my $detail = qq(
</script>
<tr>
<td class=data0>
<table width="100%" cellpadding=0 cellspacing=7 border=0>
<tr>
<td class=wizard_title_heading align=left style="padding: 0.5em 2px;" colspan=2>&nbsp;<b>Record: $record</b></td>
</tr>
<tr>
<td class=data width="50%">
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 border=0 style="border-collapse: collapse; border-style: solid; border-width: 0;">
<tr>
<td class=data5 align=left width=100px>Host name:</td>);
    if ( $host_data{'exists'} ) {
	$detail .= qq(
<td class=data5 align=left><input type=hidden name=host_name value="$host_data{'Name'}">$host_data{'Name'}</td>);
    }
    else {
	$detail .= qq(
<td class=data5 align=left><input type=text size=50 name=host_name value="$host_data{'Name'}" tabindex=$tab></td>);
    }
    $tab++;
    $detail .= qq(
</tr>
<tr>
<td class=data5 align=left width=100px>Alias:</td>
<td class=data5 align=left><input type=text size=50 name=alias value="$host_data{'Alias'}" tabindex=$tab></td>
</tr>);
    $tab++;
    $detail .= qq(
<tr>
<td class=data5 align=left width=100px>Host profile:</td>
<td class=data5 align=left>
<select name=profiles_host tabindex=$tab>
<option value=></option>);

    foreach my $item ( @{ $objects{'profiles_host'} } ) {
	if ( $item eq $host_data{'Host profile'} ) {
	    $detail .= "\n<option selected value=\"$item\">$item</option>";
	}
	else {
	    $detail .= "\n<option value=\"$item\">$item</option>";
	}
    }
    $tab++;
    $detail .= qq(
</select>
</td>
</tr>
<tr>
<td class=data5 align=left width=100px valign=baseline>Service&nbsp;profiles:</td>
<td class=data5 align=left valign=top>
<select name=profiles_service size=11 multiple tabindex=$tab>
<option value=></option>);
    foreach my $item ( @{ $objects{'profiles_service'} } ) {
	foreach my $selected ( keys %{ $host_data{'Service profile'} } ) {
	    if ( $item eq $selected ) { $got_selected = 1 }
	}
	if ($got_selected) {
	    $got_selected = undef;
	    $detail .= "\n<option selected value=\"$item\">$item</option>";
	}
	else {
	    $detail .= "\n<option value=\"$item\">$item</option>";
	}
    }

    $tab++;
    $detail .= qq(
</select>
</td>
</tr>
<tr>
<td class=data5 align=left width=100px valign=baseline>Parents:</td>
<td class=data5 align=left valign=top>
<select name=parents size=9 multiple tabindex=$tab>
<option value=></option>);
    foreach my $item ( @{ $objects{'parents'} } ) {
	foreach my $selected ( keys %{ $host_data{'Parent'} } ) {
	    if ( $item eq $selected ) { $got_selected = 1 }
	}
	if ($got_selected) {
	    $got_selected = undef;
	    $detail .= "\n<option selected value=\"$item\">$item</option>";
	}
	else {
	    $detail .= "\n<option value=\"$item\">$item</option>";
	}
    }

    $detail .= qq(
</select>
</td>
</tr>
</table>
</td>
<td class=data width="50%">
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 border=0 style="border-collapse: collapse; border-style: solid; border-width: 0;">);
    $tab++;
    $detail .= qq(
<tr>
<td class=data5 align=left width=100px>Address:</td>
<td class=data5 align=left><input type=text size=20 name=address value="$host_data{'Address'}" tabindex=$tab></td>
</tr>);
    $tab++;
    $detail .= qq(
<tr>
<td class=data5 align=left width=100px>Description:</td>
<td class=data5 align=left><input type=text size=50 name=description value="$host_data{'Description'}" tabindex=$tab></td>
</tr>);
    $tab++;
    $detail .= qq(
<tr>
<td class=data5 align=left width=100px valign=baseline>Groups:</td>
<td class=data5 align=left valign=top>
<select name=monarch_groups size=7 multiple tabindex=$tab>
<option value=></option>);
    foreach my $item ( @{ $objects{'monarch_groups'} } ) {
	foreach my $selected ( keys %{ $host_data{'Group'} } ) {
	    if ( $item eq $selected ) { $got_selected = 1 }
	}
	if ($got_selected) {
	    $got_selected = undef;
	    $detail .= "\n<option selected value=\"$item\">$item</option>";
	}
	else {
	    $detail .= "\n<option value=\"$item\">$item</option>";
	}
    }

    $tab++;
    $detail .= qq(
</select>
</td>
</tr>
<tr>
<td class=data5 align=left width=100px valign=baseline>Host groups:</td>
<td class=data5 align=left valign=top>
<select name=hostgroups size=7 multiple tabindex=$tab>
<option value=></option>);
    foreach my $item ( @{ $objects{'hostgroups'} } ) {
	foreach my $selected ( keys %{ $host_data{'Host group'} } ) {
	    if ( $item eq $selected ) { $got_selected = 1 }
	}
	if ($got_selected) {
	    $got_selected = undef;
	    $detail .= "\n<option selected value=\"$item\">$item</option>";
	}
	else {
	    $detail .= "\n<option value=\"$item\">$item</option>";
	}
    }

    $tab++;
    $detail .= qq(
</select>
</td>
</tr>
<tr>
<td class=data5 align=left width=100px valign=baseline>Contact&nbsp;groups:</td>
<td class=data5 align=left valign=top>
<select name=contactgroups size=7 multiple tabindex=$tab>
<option value=></option>);
    foreach my $item ( @{ $objects{'contactgroups'} } ) {
	foreach my $selected ( keys %{ $host_data{'Contact group'} } ) {
	    if ( $item eq $selected ) { $got_selected = 1 }
	}
	if ($got_selected) {
	    $got_selected = undef;
	    $detail .= "\n<option selected value=\"$item\">$item</option>";
	}
	else {
	    $detail .= "\n<option value=\"$item\">$item</option>";
	}
    }

    $detail .= qq(
</select>
</td>
</tr>
</table>
</td>
</tr>
</table>
</td>
</tr>
<tr>
<td class=data0>
<table width="100%" cellpadding=7 cellspacing=0 align=left border=0>
<tr>
<td class=wizard_title_heading align=left colspan=2 valign=top><b>Discovered and Additional Services and Instances</b></td>
</tr>
	<tr>
	<td colspan=2>
	<table width="100%" cellpadding=3 cellspacing=0 align=left border=0>
		<tr>
		<td class=column_head align=left width=15px>&nbsp;</td>
		<td class=column_head align=left width=250px>Service name</td>
		<td class=column_head align=left width=200px>Check command</td>
		<td class=column_head align=left width=300px>Arguments</td>
		<td class=column_head align=left>&nbsp;</td>
		</tr>);
    my $got_services = 0;
    $got_selected = 0;
    foreach my $service ( sort { $a cmp $b } keys %{ $host_data{'Service'} } ) {
	unless ($service) { next }
	$got_services = 1;
	my $class        = 'row1_unpadded';
	my $button_class = 'column';
	$tab++;
	if ( $service_objs{$service}{'service_selected'} ) {
	    $got_selected = $service;
	    $button_class = 'match_selected';
	    $class        = 'match_selected';
	    $detail .= qq(
		<tr>
		<td class=$class align=left width=15px><input type=radio name=service_selected value="$service" checked onClick="lowlight();submit()" tabindex=$tab></td>);
	}
	else {
	    $detail .= qq(
		<tr>
		<td class=$class align=left width=15px><input type=radio name=service_selected value="$service" onClick="lowlight();submit()" tabindex=$tab></td>);
	}
	$detail .= qq(
		<td class=$class align=left valign=top>$service</td>
		<input type=hidden name="services" value="$service">
		<input type=hidden name="check_command_$service" value="$service_objs{$service}{'check_command'}">
		<td class=$class align=left valign=top>$service_objs{$service}{'check_command'}&nbsp;&nbsp;</td>);
	my $arguments = $service_objs{$service}{'arguments'};
	$arguments = '' if not defined $arguments;
	if ( $service_objs{$service}{'service_selected'} && !( keys %{ $service_objs{$service}{'instances'} } ) ) {
	    $tab++;
	    $detail .= qq(
		<td class=$class align=left valign=top><input type=text size=40 name="arguments_$service" value="$arguments" tabindex=$tab></td>);
	}
	else {
	    $detail .= qq(
		<td class=$class align=left valign=top><input type=hidden name="arguments_$service" value="$arguments">$arguments</td>);
	}
	$tab++;
	$detail .= qq(
		<td class=$class align=right><input class="$button_class" type="submit" name="remove_service_$service" value="remove service" tabindex=7></td>
		</tr>);
	my @alph_sorted   = ();
	my @num_sorted    = ();
	my %instance_sort = ();
	foreach my $instance ( keys %{ $service_objs{$service}{'instances'} } ) {
	    my $inst = $instance;
	    $inst =~ s/^_//;
	    $inst .= rand();
	    if ( $inst =~ /^\d+/ ) {
		push @num_sorted, $inst;
	    }
	    else {
		push @alph_sorted, $inst;
	    }
	    $instance_sort{$inst}{'name'} = $instance;
	}
	foreach my $inst ( sort { $a <=> $b } @num_sorted ) {
	    my $instance = $instance_sort{$inst}{'name'};
	    $detail .= qq(
		<tr>
		<td class=$class align=left>&nbsp;</td>
		<td class=$class align=left>$service$instance</td>
		<input type=hidden name="instances_$service" value="$instance">
		<td class=$class align=left>$service_objs{$service}{'check_command'}</td>);
	    if ( $service_objs{$service}{'service_selected'} ) {
		$tab++;
		$detail .= qq(
		<td class=$class align=left><input type=text size=40 name="instances_arguments_$service\_$instance" value="$service_objs{$service}{'instances'}{$instance}" tabindex=$tab></td>);
		$tab++;
		$detail .= qq(
		<td class=$class align=right><input class="$button_class" type="submit" name="remove_instance_$service\:-:$instance" value="remove instance" tabindex=$tab></td>
		</tr>);
	    }
	    else {
		$tab++;
		$detail .= qq(
		<td class=$class align=left>$service_objs{$service}{'instances'}{$instance}</td>
		<input type=hidden name="instances_$service" value="$instance">
		<input type=hidden name="instances_arguments_$service\_$instance" value="$service_objs{$service}{'instances'}{$instance}">
		<td class=$class align=right><input class="$button_class" type="submit" name="remove_instance_$service\:-:$instance" value="remove instance" tabindex=$tab></td>
		</tr>);
	    }
	}
	foreach my $inst ( sort { lc($a) cmp lc($b) } @alph_sorted ) {
	    my $instance = $instance_sort{$inst}{'name'};
	    $detail .= qq(
		<tr>
		<td class=$class align=left>&nbsp;</td>
		<td class=$class align=left>$service$instance</td>
		<input type=hidden name="instances_$service" value="$instance">
		<td class=$class align=left>$service_objs{$service}{'check_command'}</td>);
	    if ( $service_objs{$service}{'service_selected'} ) {
		$tab++;
		$detail .= qq(
		<td class=$class align=left><input type=text size=40 name="instances_arguments_$service\_$instance" value="$service_objs{$service}{'instances'}{$instance}" tabindex=$tab></td>);
		$tab++;
		$detail .= qq(
		<td class=$class align=right><input class="$button_class" type="submit" name="remove_instance_$service\:-:$instance" value="remove instance"  tabindex=$tab></td>
		</tr>);
	    }
	    else {
		$tab++;
		$detail .= qq(
		<td class=$class align=left>$service_objs{$service}{'instances'}{$instance}</td>
		<input type=hidden name="instances_$service" value="$instance">
		<input type=hidden name="instances_arguments_$service\_$instance" value="$service_objs{$service}{'instances'}{$instance}">
		<td class=$class align=right><input class="$button_class" type="submit" name="remove_instance_$service\:-:$instance" value="remove instance"  tabindex=$tab></td>
		</tr>);
	    }
	}
    }

    if ( $got_services && $got_selected ) {
	$javascript .= qq(
window.onload = function() {
	document.form.instance_add.focus();
}
);
    }
    else {
	$javascript .= qq(
window.onload = function() {
	var instance_label = document.getElementById("instance_label");
	instance_label.className = 'row2_disabled';
	document.form.instance_add.className = 'text_disabled';
	document.form.instance_add.disabled = true;
	document.form.add_instance.className = 'submitbutton_row2_disabled';
	document.form.add_instance.disabled = true;
	document.form.address.focus();
}
);
    }
    unless ($got_services) {
	$detail .= qq(
		<tr>
		<td class=$form_class align=left colspan=6>No services have been assigned.</td>
		</tr>);
    }
    $tab++;
    $detail .= qq(
	</table>
	<table width="100%" cellpadding=3 cellspacing=0 align=left border=0 style="margin-top: 7px;">
		<tr>
		<td class=row2>
		<table cellpadding=3 cellspacing=0 align=left border=0>
			<tr>
			<td class=row2>Service:
			<select name=service_add tabindex=$tab>
			<option value=></option>);
    foreach my $item ( @{ $objects{'services'} } ) {
	unless ( $host_data{'Service'}{$item} ) {
	    $detail .= "\n\t\t\t<option value=\"$item\">$item</option>";
	}
    }

    $tab++;
    $detail .= qq(
			</select>
			</td>
			<td class=row2 valign=top align=left>&nbsp; <input class=submitbutton type="submit" name=add_service value="Add Service" tabindex=$tab></td>
			</tr>
		</table>
		</td>);
    $tab++;
    $detail .= qq(
		<td class=row2>
		<table cellpadding=3 cellspacing=0 align=left border=0>
			<tr>
			<td class=row2 name=instance_label id=instance_label>Service Name Instance Suffix: <input type=text size=15 class=text name=instance_add value=""></td>
			<td class=row2 valign=top align=left>&nbsp; <input class=submitbutton type="submit" name=add_instance value="Add Instance" tabindex=$tab></td>
			</tr>
		</table>
		</td>
		</tr>
	</table>
	</td>
	</tr>
</table>
</td>
</tr>);
    return $javascript . $detail;
}

sub import_sync_other(@) {
    my %schema       = %{ $_[1] };
    my %import_data  = %{ $_[2] };
    my %hosts_vitals = StorProc->get_hosts_vitals();
    my $detail       = qq(
<tr>
<td width="100%" align=center>
<div class="scroll" style="height: 400px;">
<table width="100%" cellpadding=0 cellspacing=0 align=left border=0>
<tr>);
    foreach my $rec ( sort { $a cmp $b } keys %import_data ) {
	if ( $schema{'sync_object'} eq 'Host' ) {
	    if ( $import_data{$rec}{'Name'} ) {
		if ( $hosts_vitals{'name'}{ $import_data{$rec}{'Name'} } ) {
		    my $uriesc_val = uri_unescape( $import_data{$rec}{'Name'} );
		    $detail .= qq(
	<td class=$form_class width="35%" colspan=2 valign=top>
		<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
		<tr>
		<td class=$form_class align=left width=75px valign=top>Name:</td>
		<input type=hidden name=hostname_$rec value="$uriesc_val">
		<td class=$form_class align=left valign=top>$import_data{$rec}{'Name'}</td>
		</tr>
		</table>
	</td>);
		}
		else {
		    $detail .= qq(
	<td class=$form_class width="35%" colspan=2 valign=top>
		<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
		<tr>
		<td class=$form_class align=left width=75px valign=top>Error:</td>
		<td class=$form_class align=left valign=top>Record $rec Host with name $import_data{$rec}{'Name'} does not exist. Nothing to update.</td>
		</tr>
		</table>
	</td>);
		}
	    }
	    elsif ( $import_data{$rec}{'Address'} ) {
		if ( $hosts_vitals{'address'}{ $import_data{$rec}{'Address'} } ) {
		    my $uriesc_val = uri_unescape( $import_data{$rec}{'Address'} );
		    $detail .= qq(
	<td class=$form_class width="35%" colspan=2 valign=top>
		<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
		<tr>
		<td class=$form_class align=left width=75px valign=top>Address:</td>
		<input type=hidden name=hostname_$rec value="$uriesc_val">
		<td class=$form_class align=left valign=top>$import_data{$rec}{'Address'}</td>
		</tr>
		</table>
	</td>);
		}
		else {
		    $detail .= qq(
	<td class=$form_class width="35%" colspan=2 valign=top>
		<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
		<tr>
		<td class=$form_class align=left width=75px valign=top>Error:</td>
		<td class=$form_class align=left valign=top>$rec Host with address $import_data{$rec}{'Address'} does not exist. Nothing to update.</td>
		</tr>
		</table>
	</td>);
		}
	    }
	    elsif ( $import_data{$rec}{'Alias'} ) {
		if ( $hosts_vitals{'alias'}{ $import_data{$rec}{'Alias'} } ) {
		    my $uriesc_val = uri_unescape( $import_data{$rec}{'Alias'} );
		    $detail .= qq(
	<td class=$form_class width="35%" colspan=2 valign=top>
		<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
		<tr>
		<td class=$form_class align=left width=75px valign=top>Alias:</td>
		<input type=hidden name=hostname_$rec value="$uriesc_val">
		<td class=$form_class align=left valign=top>$import_data{$rec}{'Alias'}</td>
		</tr>
		</table>
	</td>);
		}
		else {
		    $detail .= qq(
	<td class=$form_class width="35%" colspan=2 valign=top>
		<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
		<tr>
		<td class=$form_class align=left width=75px valign=top>Error:</td>
		<td class=$form_class align=left valign=top>$rec Host with alias $import_data{$rec}{'Alias'} does not exist. Nothing to update.</td>
		</tr>
		</table>
	</td>);
		}
	    }
	}
	else {
	    if ( $schema{'sync_object'} eq 'Group' && $import_data{$rec}{'Group'} ) {
		## FIX THIS:  what sense does it make to stringify a hash reference?
		my $uriesc_val = uri_unescape( $import_data{$rec}{'Group'} );
		$detail .= qq(
		<td class=$form_class width="35%" colspan=2 valign=top>
			<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
			<tr>
			<td class=$form_class align=left width=75px valign=top>Group:</td>
			<input type=hidden name=hostname_$rec value="$uriesc_val">
			<td class=$form_class align=left valign=top>$import_data{$rec}{'Group'}</td>
			</tr>
			</table>
		</td>);
	    }
	    elsif ( $schema{'sync_object'} eq 'Host group' && $import_data{$rec}{'Host group'} ) {
		## FIX THIS:  what sense does it make to stringify a hash reference?
		my $uriesc_val = uri_unescape( $import_data{$rec}{'Host group'} );
		$detail .= qq(
		<td class=$form_class width="35%" colspan=2 valign=top>
			<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
			<tr>
			<td class=$form_class align=left width=75px valign=top>Host group:</td>
			<input type=hidden name=hostname_$rec value="$uriesc_val">
			<td class=$form_class align=left valign=top>$import_data{$rec}{'Host group'}</td>
			</tr>
			</table>
		</td>);
	    }
	    elsif ( $schema{'sync_object'} eq 'Parent' ) {
		## FIX THIS:  what sense does it make to stringify a hash reference?
		my $uriesc_val = uri_unescape( $import_data{$rec}{'Parent'} );
		if (   $hosts_vitals{'name'}{$uriesc_val}
		    || $hosts_vitals{'address'}{$uriesc_val}
		    || $hosts_vitals{'alias'}{$uriesc_val} )
		{
		    $detail .= qq(
		<td class=$form_class width="35%" colspan=2 valign=top>
			<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
			<tr>
			<td class=$form_class align=left width=75px valign=top>Parent:</td>
			<input type=hidden name=hostname_$rec value="$uriesc_val">
			<td class=$form_class align=left valign=top>$import_data{$rec}{'Parent'}</td>
			</tr>
			</table>
		</td>);
		}
		else {
		    $detail .= qq(
	<td class=$form_class width="35%" colspan=2 valign=top>
		<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
		<tr>
		<td class=$form_class align=left width=75px valign=top>Error:</td>
		<td class=$form_class align=left valign=top>Record $rec Parent $uriesc_val does not exist. Nothing to update.</td>
		</tr>
		</table>
	</td>);
		}
	    }
	    elsif ( $schema{'sync_object'} eq 'Contact group' && $import_data{$rec}{'Contact group'} ) {
		## FIX THIS:  what sense does it make to stringify a hash reference?
		my $uriesc_val = uri_unescape( $import_data{$rec}{'Contact group'} );
		$detail .= qq(
		<td class=$form_class width="35%" colspan=2 valign=top>
			<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
			<tr>
			<td class=$form_class align=left width=75px valign=top>Contact group:</td>
			<input type=hidden name=hostname_$rec value="$uriesc_val">
			<td class=$form_class align=left valign=top>$import_data{$rec}{'Contact group'}</td>
			</tr>
			</table>
		</td>);
	    }
	    else {
		$detail .= qq(
	<td class=$form_class width="35%" colspan=2 valign=top>
		<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
		<tr>
		<td class=$form_class align=left width=75px valign=top>Error:</td>
		<td class=$form_class align=left valign=top>Insufficient data to import.</td>
		</tr>
		</table>
	</td>);
	    }
	}

	if ( $import_data{$rec}{'Group'} ) {
	    $detail .= qq(
	<td class=$form_class width="15%" valign=top>
		<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>);
	    foreach my $group ( sort { $a cmp $b } keys %{ $import_data{$rec}{'Group'} } ) {
		my $uriesc_g = uri_escape($group);
		$detail .= qq(
		    <input type=hidden name=group_$uriesc_g value="$uriesc_g">
		    <tr><td class=$form_class align=left valign=top>$group</td></tr>);
	    }
	    $detail .= qq(
		</table>
	</td>);
	}
	if ( $import_data{$rec}{'Host group'} ) {
	    $detail .= qq(
	<td class=$form_class width="15%" valign=top>
		<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>);
	    foreach my $hostgroup ( sort { $a cmp $b } keys %{ $import_data{$rec}{'Host group'} } ) {
		my $uriesc_hg = uri_escape($hostgroup);
		$detail .= qq(
		    <input type=hidden name=hostgroup_$uriesc_hg value="$uriesc_hg">
		    <tr><td class=$form_class align=left valign=top>$hostgroup</td></tr>);
	    }
	    $detail .= qq(
		</table>
	</td>);
	}
	if ( $import_data{$rec}{'Parent'} ) {
	    $detail .= qq(
	<td class=$form_class width="15%" valign=top>
		<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>);
	    if ( $import_data{$rec}{'Parent'} ) {
		foreach my $parent ( sort { $a cmp $b } keys %{ $import_data{$rec}{'Parent'} } ) {
		    my $uriesc_p = uri_escape($parent);
		    if (   $hosts_vitals{'name'}{$uriesc_p}
			|| $hosts_vitals{'address'}{$uriesc_p}
			|| $hosts_vitals{'alias'}{$uriesc_p} )
		    {
			$detail .= qq(
			<input type=hidden name=parent_$uriesc_p value="$uriesc_p">
			<tr><td class=$form_class align=left valign=top>Parent:</td>
			<td class=$form_class align=left valign=top>$parent</td></tr>);
		    }
		    else {
			$detail .= qq(
			<tr>
			<td class=$form_class align=left width=75px valign=top>Error:</td>
			<td class=$form_class align=left valign=top>Record $rec Parent $parent does not exist. Nothing to update.</td></tr>);
		    }
		}
	    }
	    else {
		$detail .= qq(
			<tr><td class=$form_class align=left valign=top>&nbsp;</td></tr>);
	    }
	    $detail .= qq(
		</table>
	</td>);
	}
	if ( $import_data{$rec}{'Service profile'} ) {
	    $detail .= qq(
	<td class=$form_class width="15%" valign=top>
		<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>);
	    foreach my $profile ( sort { $a cmp $b } keys %{ $import_data{$rec}{'Service profile'} } ) {
		my $uriesc_p = uri_escape($profile);
		$detail .= qq(
		    <input type=hidden name=serviceprofile_$uriesc_p value="$uriesc_p">
		    <tr><td class=$form_class align=left valign=top>$profile</td></tr>);
	    }
	    $detail .= qq(
		</table>
	</td>);
	}
	if ( $import_data{$rec}{'Contact group'} ) {
	    $detail .= qq(
	<td class=$form_class width="15%" valign=top>
		<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>);
	    foreach my $group ( sort { $a cmp $b } keys %{ $import_data{$rec}{'Contact group'} } ) {
		my $uriesc_g = uri_escape($group);
		$detail .= qq(
		    <input type=hidden name=contactgroup_$uriesc_g value="$uriesc_g">
		    <tr><td class=$form_class align=left valign=top>$group</td></tr>);
	    }
	    $detail .= qq(
		</table>
	</td>);
	}
	$detail .= qq(
</tr>);
    }

    $detail .= qq(
</td>
</tr>
</table>
</div>
</td>
</tr>);
    return $detail;
}

sub select_schema(@) {
    my %list = %{ $_[1] };
    use HTML::Tooltip::Javascript;
    my %doc    = doc();
    my $detail = qq(
<script type="text/javascript" language=JavaScript>
function setNext() {
	document.form.next.className = 'submitbutton';
	document.form.next.disabled = false;
}

window.onload = function() {
		document.form.next.className = 'submitbutton_disabled';
		document.form.next.disabled = true;
}
</script>
<tr>
<td class=data0>
<table width="100%" cellpadding=7 cellspacing=0 align=left border=0>
<tr>
<td class=wizard_title_heading><b>Select or define an automation schema</b></td>
</tr>
<tr>
<td class=$form_class>
<div style="max-width: 750px;">
<p class=append style="margin-top: 0;">An automation schema is an import/update data mapping tool that can be applied to any data source from which a text-delimited file can be extracted.</p>
<p class=append>
The automation schema types are:
</p>
<ul>
<li><p class=append>
<b>host-import</b>: $doc{'host-import'}
</p></li>
<li><p class=append>
<b>host-profile-sync</b>: $doc{'host-profile-sync'}
</p></li>
<li><p class=append>
<b>other-sync</b>: $doc{'other-sync'}
</p></li>
</ul>
</div>
</td>
</tr>
</table>
</td>
</tr>
<tr>
<td class=data0>
<table width="100%" cellpadding=7 cellspacing=0 align=left border=0>
<tr>
<td class=$form_class>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class=column_head width="5%">Select</td>
<td class=column_head width="25%">Automation Schema Name</td>
<td class=column_head width="15%">Type</td>
<td class=column_head width="55%">Description</td>
</tr>);
    my $class = 'row_dk';
    foreach my $name ( sort keys %list ) {
	if ( $class eq 'row_dk' ) {
	    $class = 'row_lt';
	}
	else {
	    $class = 'row_dk';
	}
	$detail .= qq(
<tr>
<td class=$class align=left valign=top>&nbsp;&nbsp;&nbsp;<input class=$class type=radio name=automation_name value="$name" onclick="setNext();"></td>
<td class=$class valign=top>$name</td>
<td class=$class valign=top>$list{$name}{'type'}</td>
<td class=$class valign=top>$list{$name}{'description'}</td>
</tr>);
    }
    $detail .= qq(
</table>
</td>
</tr>
</table>
</td>
</tr>);
    return $detail;
}

sub select_nms() {
    my %nms_opts = %{ $_[1] };
    my $tab      = 0;
    use HTML::Tooltip::Javascript;
    my $tt = HTML::Tooltip::Javascript->new(
	## URL path to where wz_tooltip.js is.
	javascript_dir => $monarch_js,
	options        => {
	    bgcolor     => '#000000',
	    default_tip => 'Tip not defined',
	    delay       => 0,
	    title       => 'Tooltip',
	},
    );
    my %options = (
	borderwidth => '1',
	padding     => '10',
	bordercolor => '#000000',
	bgcolor     => '#FFFFFF',
	width       => '600',
	fontsize    => '12px'
    );
    my $detail = qq(
<tr>
<td class=data>
<table width="100%" cellpadding=7 cellspacing=0 align=left border=0>
<tr>
<td class=$form_class><b>NMS Configuration Integration</b></td>
</tr>
<tr>
<td class=$form_class colspan=3>Select the appropriate option to update the GroundWork configuration with data from an NMS application or other data source.
</td>
</tr>
</table>
</td>
</tr>);
    if ( $nms_opts{'cacti_sync'} ) {
	$detail .= qq(
<tr>
<td class=data>
<table width="100%" cellpadding=7 cellspacing=0 align=left border=0>
<tr>
<td class=$form_class valign=top width="15%"><b>Cacti host profile sync</b></td>
<td class=$form_class rowspan=2 width="70%">
Use Cacti Sync to update the host list in the Cacti host profile in GroundWork Configuration. Hosts found in the configuration database but not found in the Cacti data source are flagged for deletion.
The Cacti host profiles sync can be fully ...);

	my $tt_doc =
qq(<p class='append'>The Cacti host profile sync can be fully automated. The process is broken down into two steps: extract the data from Cacti and import the data into GroundWork Configuration.</p>
<p class='append'>
&bull;&nbsp;The script to extract data from Cacti is:
<br>&nbsp;&nbsp;&nbsp;<b>/usr/local/groundwork/core/monarch/automation/scripts/extract_cacti.pl</b>
<br>&nbsp;&nbsp;&nbsp;Please note that the database authentication information for Cacti resides in the script.
</p>
<p class='append'>
&bull;&nbsp;The script to import data into GroundWork Configuration is:<b>
<br>&nbsp;&nbsp;&nbsp;/usr/local/groundwork/core/monarch/automation/scripts/auto_import_cacti.pl Cacti</b>
<br>&nbsp;&nbsp;&nbsp;Please note the the schema name is set in the auto_import_cacti.pl script.
</p>);

	$options{'title'} = 'Automation';
	$options{'width'} = 750;
	my $s_detail = $tt->tooltip( "<b>Cacti host profile sync</b><br>$tt_doc", \%options );

	$detail .= qq(
<a class=orange href="#" $s_detail tabindex="-1">automated</a>.
</td>
</tr>
<tr>
<td class=$form_class valign=top width="15%">
<input class="submitbutton" type="submit" name=cacti_sync value="Cacti Sync" tabindex=$tab></td>
</tr>
</table>
</td>
</tr>);
    }
    if ( $nms_opts{'nedi_sync'} ) {
	$detail .= qq(
<tr>
<td class=data>
<table width="100%" cellpadding=7 cellspacing=0 align=left border=0>
<tr>
<td class=$form_class valign=top width="15%"><b>NeDi parent-child sync</b></td>
<td class=$form_class rowspan=2 width="70%">
Use NeDi Sync to update the host parent-child relationships in GroundWork Configuration. Both parent and child hosts must be present in the GroundWork configuration database. To import new hosts from NeDi data, use NeDi Import.
The NeDi parent-child sync can be fully ...);
	my $tt_doc =
qq(<p class='append'>The NeDi parent-child sync can be fully automated. The process is broken down into two steps: extract the data from NeDi and import the data into GroundWork Configuration.</p>
<p class='append'>
&bull;&nbsp;The script to extract data from NeDi is:
<br>&nbsp;&nbsp;&nbsp;<b>/usr/local/groundwork/core/monarch/automation/scripts/extract_nedi.pl</b>
<br>&nbsp;&nbsp;&nbsp;Please note that the database authentication information for NeDi resides in the script.
</p>
<p class='append'>
&bull;&nbsp;The script to import data into GroundWork Configuration is:
<br>&nbsp;&nbsp;&nbsp;<b>/usr/local/groundwork/core/monarch/automation/scripts/auto_import_nedi_sync.pl NeDi-parent-child-sync</b>
<br>&nbsp;&nbsp;&nbsp;Please note the schema name is set in the auto_import_nedi_sync.pl script.
</p>);
	$options{'title'} = 'Automation';
	my $s_detail = $tt->tooltip( "<b>NeDi parent-child sync</b><br>$tt_doc", \%options );

	$detail .= qq(
<a class=orange href="#" $s_detail tabindex="-1">automated</a>.
</td>
</tr>
<tr>
<td class=$form_class valign=top width="15%">
<input class="submitbutton" type="submit" name=nedi_sync value="NeDi Sync" tabindex=$tab></td>
</tr>
</table>
</td>
</tr>
<tr>
<td class=data>
<table width="100%" cellpadding=7 cellspacing=0 align=left border=0>
<tr>
<td class=$form_class valign=top width="15%"><b>NeDi host import</b></td>
<td class=$form_class rowspan=2 width="70%">
Use NeDi host import to update the GroundWork Configuration with data from NeDi.
The NeDi host import can be fully ...);
	$tt_doc =
qq(<p class='append'>The NeDi host import can be fully automated. The process is broken down into two steps: extract the data from NeDi and import the data into GroundWork Configuration.</p>
<p class='append'>
&bull;&nbsp;The script to extract data from NeDi is:
<br>&nbsp;&nbsp;&nbsp;<b>/usr/local/groundwork/core/monarch/automation/scripts/extract_nedi.pl</b>
<br>&nbsp;&nbsp;&nbsp;Please note that the database authentication information for NeDi resides in the script.
</p>
<p class='append'>
&bull;&nbsp;The script to import data into GroundWork Configuration is:
<br>&nbsp;&nbsp;&nbsp;<b>/usr/local/groundwork/core/monarch/automation/scripts/auto_import_nedi_host.pl NeDi-host-import</b>
<br>&nbsp;&nbsp;&nbsp;Please note the schema name is set in the auto_import_nedi_host.pl script.
</p>);
	$options{'title'} = 'Automation';
	$s_detail = $tt->tooltip( "<b>NeDi host import</b><br>$tt_doc", \%options );

	$detail .= qq(
<a class=orange href="#" $s_detail tabindex="-1">automated</a>.
</td>
</tr>
<tr>
<td class=$form_class width="15%">
<input class="submitbutton" type="submit" name=nedi_import value="NeDi Import" tabindex=$tab></td>
</tr>
</table>
</td>
</tr>);
    }
    $detail .= qq(
<tr>
<td class=data>
<table width="100%" cellpadding=7 cellspacing=0 align=left border=0>
<tr>
<td class=$form_class valign=top width="15%"><b>Import data from another data source</b></td>
<td class=$form_class rowspan=2 width="70%">
Create and select your own schema to import data from any text delimited data source.
</td>
</tr>
<tr>
<td class=$form_class width="15%">
<input class="submitbutton" type="submit" name=other_import value="Other Import" tabindex=$tab></td>
</tr>
</table>
</td>
</tr>
</table>
</td>
</tr>);
    $detail .= $tt->at_end;
    return $detail;
}

sub discover_home(@) {
    my %groups = %{ $_[1] };
    my $tab    = 0;
    my $tt     = HTML::Tooltip::Javascript->new(
	## URL path to where wz_tooltip.js is.
	javascript_dir => $monarch_js,
	options        => {
	    bgcolor     => '#000000',
	    default_tip => 'Tip not defined',
	    delay       => 0,
	    title       => 'Tooltip',
	},
    );
    my %options = (
	borderwidth => '1',
	padding     => '10',
	bordercolor => '#000000',
	bgcolor     => '#FFFFFF',
	width       => '500',
	fontsize    => '12px'
    );

    $options{'title'} = 'Discovery Definitions';
    my $docs =
"\nDiscovery definitions specify methods to find network devices and servers connected to your network. Discovery definitions can be created to match your particular needs and environment.";
    my $tooltip = $tt->tooltip( $docs, \%options );

    my $detail = js_utils();
    my $doc_url = StorProc->doc_section_url('Auto+Discovery', 'AutoDiscovery-AboutAutoDiscovery');
    $detail .= qq(
<tr>
<td class=data0>
<table width="100%" cellpadding=7 cellspacing=0 align=left border=0>
	<tr>
	<td class=wizard_title_heading><b>Discovery Definitions</b>&nbsp;&nbsp;<a class=orange href="#" $tooltip tabindex="-1">&nbsp;?&nbsp;</a></td>
	<td class=wizard_title_heading align=right>
	<input class="submitbutton" type=button onclick="open_window('$doc_url')" value="Help" tabindex=$tab>&nbsp;&nbsp;
	<input class="submitbutton" type="submit" name=new_group value="New" tabindex=$tab>&nbsp;&nbsp;
	<input class="submitbutton" type="submit" name=edit_group value="Edit" tabindex=$tab>&nbsp;&nbsp;
	<input class="submitbutton" type="submit" name=save_group value="Save" tabindex=$tab>&nbsp;&nbsp;
	<input class="submitbutton" type="submit" name=go value="Go >>" tabindex=$tab>
	</td>
	</tr>
	<tr>
	<td class=$form_class colspan=2>
	<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
		<tr>
		<td class=column_head align=left width="15px"></td>
		<td class=column_head align=left width="220px">Discovery&nbsp;Definition&nbsp;Name&nbsp;</td>
		<td class=column_head align=left>Description</td>
		<td class=column_head align=left colspan=6>Control Type</td>
		</tr>);

    my $form_match = 'match_selected';
    my $row_class = 'row_dk';
    foreach my $name ( sort keys %groups ) {
	unless ($name) { next }
	my $radio    = 'radio';
	my %selected = ();
	my %auto     = ();
	if ( $row_class eq 'row_lt' ) {
	    $row_class = 'row_dk';
	}
	elsif ( $row_class eq 'row_dk' ) {
	    $row_class = 'row_lt';
	}
	my $class = $row_class;
	$radio = $class;
	if ( $groups{$name}{'selected'} ) {
	    $class                          = $form_match;
	    $radio                          = 'radio_orange';
	    $selected{$name}                = 'checked';
	    $auto{ $groups{$name}{'auto'} } = 'checked';
	}
	else {
	    $selected{$name} = '';
	}
	my $auto        = $auto{'Auto'};
	my $auto_commit = $auto{'Auto-Commit'};
	my $interactive = $auto{'Interactive'};
	$auto        = '' if not defined $auto;
	$auto_commit = '' if not defined $auto_commit;
	$interactive = '' if not defined $interactive;
	my $description = $groups{$name}{'description'};
	$description = '' if not defined $description;
	$detail .= qq(
		<tr>
		<td class=$class align=left valign=top width=15px><input class=$radio type=radio name=discover_name_select value="$name" $selected{$name} onClick="lowlight();submit()"></td>
		<td class=$class align=left valign=top width=200px>$name</td>
		<td class=$class align=left valign=top width=>$description</td>
		<td class=$class align=left valign=top width=15px><input class=$radio type=radio name="auto_$name" value="Interactive" $interactive></td>
		<td class=$class align=left valign=top width=35px>Interactive</td>
		<td class=$class align=left valign=top width=15px><input class=$radio type=radio name="auto_$name" value="Auto" $auto></td>
		<td class=$class align=left valign=top width=30px>Auto</td>
		<td class=$class align=left valign=top width=15px><input class=$radio type=radio name="auto_$name" value="Auto-Commit" $auto_commit></td>
		<td class=$class align=left valign=top width=85px>Auto-Commit&nbsp;&nbsp;</td>
		</tr>);
    }

    $detail .= $tt->at_end;
    $detail .= qq(
	</table>
	</td>
	</tr>
</table>
</td>
</tr>);
    return $detail;
}

sub manage_group(@) {
    my $name    = $_[1];
    my %group   = %{ $_[2] };
    my @schemas = @{ $_[3] };
    my %methods = %{ $_[4] };
    my $tab     = 0;
    use HTML::Tooltip::Javascript;
    my $tt = HTML::Tooltip::Javascript->new(
	## URL path to where wz_tooltip.js is.
	javascript_dir => $monarch_js,
	options        => {
	    bgcolor     => '#000000',
	    default_tip => 'Tip not defined',
	    delay       => 0,
	    title       => 'Tooltip',
	},
    );
    my %options = (
	borderwidth => '1',
	padding     => '10',
	bordercolor => '#000000',
	bgcolor     => '#FFFFFF',
	width       => '500',
	left        => '1',
	fontsize    => '12px'
    );

    my $detail = js_utils();
    my $doc_url = StorProc->doc_section_url('Auto+Discovery', 'AutoDiscovery-TheDiscoverySubsystem');
    $detail .= qq(
<script type="text/javascript" language=JavaScript>
function methodSet()
{
  box = eval("document.form.set_method");
  if (box.checked == false) {
   with (document.form) {
     for (var i=0; i < elements.length; i++) {
	if (elements[i].type == 'checkbox' && (elements[i].id == 'method_checked'))
	   elements[i].checked = false;
     }
   }
  } else {
   with (document.form) {
     for (var i=0; i < elements.length; i++) {
	if (elements[i].type == 'checkbox' && (elements[i].id == 'method_checked'))
	   elements[i].checked = true;
     }
   }
 }
}
</script>
<tr>
<td class=data0>
<table width="100%" cellpadding=7 cellspacing=0 align=left border=0>
<tr>
<td class=wizard_title_heading><b>$name</b></td>
<input type=hidden name=discover_name value="$name">
<td class=wizard_title_heading align=right>
<input class="submitbutton" type=button onclick="open_window('$doc_url')" value="Help" tabindex=$tab>&nbsp;&nbsp;
<input class="submitbutton" type="submit" name=save_as_template value="Save As Template" tabindex=$tab>&nbsp;&nbsp;
<input class="submitbutton" type="submit" name=rename value="Rename" tabindex=$tab>&nbsp;&nbsp;
<input class="submitbutton" type="submit" name=delete_group value="Delete" tabindex=$tab>&nbsp;&nbsp;
<input class="submitbutton" type="submit" name=save_group value="Save" tabindex=$tab>
<!--
&nbsp;&nbsp;<input class="submitbutton" type="submit" name=go value="Go >>" tabindex=$tab>
-->
</td>
</tr>
<tr>
<td class=$form_class valign=top>Description:</td>);
    $tab++;
    my $description = $group{'description'};
    $description = '' if not defined $description;
    $detail .= qq(
<td class=$form_class><textarea cols=80 wrap=virtual name=description tabindex=$tab>$description</textarea></td>
</tr>
<tr>
<td class=$form_class>Import/update automation schema:</td>);
    $tab++;
    $detail .= qq(
<td class=form_class>
<select name=schema tabindex=$tab>);

    foreach my $schema ( sort @schemas ) {
	if ( $group{'schema'} eq $schema ) {
	    $detail .= "\n<option value=\"$schema\" selected>$schema</option>";
	}
	else {
	    $detail .= "\n<option value=\"$schema\">$schema</option>";
	}
    }
    $detail .= qq(
</select>
</td>
</tr>
<tr>
<td class=$form_class>Default control type:</td>);
    $tab++;
    my @auto = ( 'Interactive', 'Auto', 'Auto-Commit' );
    $detail .= qq(
<td class=$form_class>
<select name=auto tabindex=$tab>);

    foreach my $a (@auto) {
	if ( $group{'auto'} eq $a ) {
	    $detail .= "\n<option value=\"$a\" selected>$a</option>";
	}
	else {
	    $detail .= "\n<option value=\"$a\">$a</option>";
	}
    }
    $detail .= qq(
</select>
</td>
</tr>
</table>
</td>
</tr>);

    $tab++;
    my $traceroute = 'traceroute not found';
    if ( $group{'traceroute_command'} ) {
	if ( -e $group{'traceroute_command'} ) {
	    $traceroute = $group{'traceroute_command'};
	}
	elsif ( $group{'traceroute_command'} eq 'traceroute not found' ) {
	    $traceroute = 'traceroute not found';
	}
	else {
	    $traceroute .= ": $group{'traceroute_command'}";
	}
    }
    elsif ( -e '/bin/traceroute' ) {
	$traceroute = '/bin/traceroute';
    }
    elsif ( -e '/usr/sbin/traceroute' ) {
	$traceroute = '/usr/sbin/traceroute';
    }
    my $checked = $group{'enable_traceroute'} ? 'checked' : '';
    my $colors  = $group{'enable_traceroute'} ?
	'color: #000000; background-color: #FFFFFF;' :
	'color: #707070; background-color: #E6E6E6;';
    $detail .= qq(
<tr>
<td class=data0>
<table width="100%" cellpadding=7 cellspacing=0 align=left border=0>
<tr>
<td class=wizard_title_heading colspan=2><b>Traceroute Option</b></td>
</tr>
<tr>
<td class=$form_class valign=baseline width=15px>
<script type="text/javascript" language=JavaScript>
function condition_traceroute() {
    box = eval("document.form.enable_traceroute");
    if (box.checked == false) {
	with (document.form) {
	    for (var i=0; i < elements.length; i++) {
		if (elements[i].type == 'text' && (
		    elements[i].name == 'traceroute_command'  ||
		    elements[i].name == 'traceroute_max_hops' ||
		    elements[i].name == 'traceroute_timeout')) {
		    elements[i].style.color = '#707070';
		    elements[i].style.backgroundColor = '#E6E6E6';
		}
	    }
	}
    }
    else {
	with (document.form) {
	    for (var i=0; i < elements.length; i++) {
		if (elements[i].type == 'text' && (
		    elements[i].name == 'traceroute_command'  ||
		    elements[i].name == 'traceroute_max_hops' ||
		    elements[i].name == 'traceroute_timeout')) {
		    elements[i].style.color = '#000000';
		    elements[i].style.backgroundColor = '#FFFFFF';
		}
	    }
	}
    }
}
</script>
<input class=checkbox type=checkbox name=enable_traceroute id=enable_traceroute value="enable_traceroute" $checked onClick="condition_traceroute()" tabindex=$tab>
</td>
<td class=$form_class valign=baseline>
Use traceroute to help determine Nagios parent-child relationships.
<p class=append>
(These values must then be defined.  Typical values are 6 for max hops and 2 for timeout.)
</p>
<p class=append>
Command:&nbsp;&nbsp;
);
    if ( $traceroute =~ /traceroute not found/ ) {
	$tab++;
	$detail .= qq(<input type=text name=traceroute_command size=60 value="$traceroute" style="$colors" tabindex=$tab></p><p class=append>);
    }
    else {
	$detail .= qq($traceroute &nbsp;&nbsp;<input type=hidden name=traceroute_command value="$traceroute">&nbsp;&nbsp;);
    }
    my $traceroute_max_hops = $group{'traceroute_max_hops'};
    $traceroute_max_hops = '' if not defined $traceroute_max_hops;
    $tab++;
    $detail .= qq(
max hops (-m)&nbsp;&nbsp;<input type=text name=traceroute_max_hops value="$traceroute_max_hops" size=3 style="$colors" tabindex=$tab>&nbsp;&nbsp;);

    my $traceroute_timeout = $group{'traceroute_timeout'};
    $traceroute_timeout = '' if not defined $traceroute_timeout;
    $tab++;
    $detail .= qq(
timeout (-w)&nbsp;&nbsp;<input type=text name=traceroute_timeout value="$traceroute_timeout" size=3 style="$colors" tabindex=$tab>&nbsp;seconds );

    $detail .= qq(
</p>
</td>
</tr>
</table>
</td>
</tr>);

    $tab++;
    $detail .= qq(
<tr>
<td class=data0>
<table width="100%" cellpadding=7 cellspacing=0 align=left border=0>
	<tr>
	<td class=wizard_title_heading colspan=5><b>Discovery Methods</b></td>
	</tr>
	<tr>
	<td>
	<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
		<tr>
		<td class=column_head align=left width=15px><input class=checkbox_black type=checkbox name=set_method id=set_method value="" onClick="methodSet()"></td>
		<td class=column_head align=left width=200px>Method Name</td>
		<td class=column_head align=left width=100px>Type</td>
		<td class=column_head align=left>Description</td>
		<td class=column_head align=right width=75px>&nbsp;</td>
		</tr>);

    my $color = 'dk';
    foreach my $method ( sort keys %methods ) {
	unless ($method) { next }
	my $selected = $group{'method'}{$method} ? 'checked' : '';
	if ( $color eq 'lt' ) {
	    $color = 'dk';
	}
	elsif ( $color eq 'dk' ) {
	    $color = 'lt';
	}
	$tab++;
	my $description = $methods{$method}{'description'};
	$description = '' if not defined $description;
	$detail .= qq(
		<tr>
		<td class=row_$color valign=baseline><input class=row_$color type=checkbox name=method id=method_checked value="$method" $selected></td>
		<td class=row_$color valign=baseline>$method</td>
		<td class=row_$color valign=baseline>$methods{$method}{'type'}</td>
		<td class=row_$color valign=baseline>$description</td>
		<td class=row_$color valign=baseline align=right><input type=submit class=removebutton_$color name="edit_method_$method" value="edit method" tabindex=$tab></td>
		</tr>);
    }
    $options{'title'} = 'Add Method';
    my $docs = "\nEnter the method name, the type, and a description.";
    my $tooltip = $tt->tooltip( $docs, \%options );

    $detail .= qq(
	</table>
	<table width="100%" cellpadding=7 cellspacing=0 align=left border=0 style="margin-top: 7px;">
		<tr>
		<td class=row2>
		<table width="100%" cellpadding=0 cellspacing=0 align=left border=0>
			<tr>
			<td class=row2_column_head>Method Name</td>
			<td class=row2_column_head>Type</td>
			<td class=row2_column_head>Description</td>
			<td class=row2_column_head></td>
			</tr>
			<tr>
			<td class=row2 width="20%"><input type=text name=new_method size=30 tabindex=$tab></td>);
    $tab++;
    $detail .= qq(
			<td class=row2>
			<select name=new_type tabindex=$tab>
			<option value="Nmap">Nmap</option>
			<option value="SNMP">SNMP</option>
			<option value="Script">Script</option>
			<option value="WMI">WMI</option>
			</select>
			</td>);
    $tab++;
    $detail .= qq(
			<td class=row2 width="50%"><input type=text name=new_method_description size=60 tabindex=$tab>&nbsp;&nbsp;<a class=orange href="#" $tooltip tabindex=-1>&nbsp;?&nbsp;</a></td>);
    $tab++;
    $detail .= qq(
			<td class=row2 width="25%" valign=top align=right><input class="submitbutton" type="submit" name=add_method value="Add Method" tabindex=$tab>
			</td>
			</tr>
		</table>
		</td>
		</tr>
	</table>
	</td>
	</tr>
</table>
</td>
</tr>);
    $detail .= $tt->at_end;

    return $detail, $tab;
}

sub manage_method(@) {
    my $name   = $_[1];
    my $method = $_[2];
    my %method = %{ $_[3] };
    my $tab    = 0;
    use HTML::Tooltip::Javascript;
    my $tt = HTML::Tooltip::Javascript->new(
	## URL path to where wz_tooltip.js is.
	javascript_dir => $monarch_js,
	options        => {
	    bgcolor     => '#000000',
	    default_tip => 'Tip not defined',
	    delay       => 0,
	    title       => 'Tooltip',
	},
    );
    my %options = (
	borderwidth => '1',
	padding     => '10',
	bordercolor => '#000000',
	bgcolor     => '#FFFFFF',
	width       => '500',
	fontsize    => '12px'
    );
    my $bookmark =
	( $method{'type'} eq 'Nmap' ) ? 'AutoDiscovery-NmapDiscoveryMethod' :
	( $method{'type'} eq 'SNMP' ) ? 'AutoDiscovery-SNMPDiscoveryMethod' :
	( $method{'type'} eq 'WMI'  ) ? 'AutoDiscovery-WMIDiscoveryMethod'  : 'AutoDiscovery-ScriptDiscoveryMethod';
    my $doc_url = StorProc->doc_section_url('Auto+Discovery', $bookmark);

    my $detail = js_utils();
    $detail .= qq(
<tr>
<td class=data0>
<table width="100%" cellpadding=7 cellspacing=0 align=left border=0>
<tr>
<td class=wizard_title_heading><b>$method</b></td>
<input type=hidden name=discover_name value="$name">
<input type=hidden name=method value="$method">
<td class=wizard_title_heading align=right>
<input class="submitbutton" type=button onclick="open_window('$doc_url')" value="Help" tabindex=$tab>&nbsp;&nbsp;
<input class="submitbutton" type="submit" name=rename value="Rename" tabindex=$tab>&nbsp;&nbsp;
<input class="submitbutton" type="submit" name=delete_method value="Delete" tabindex=$tab>&nbsp;&nbsp;
<input class="submitbutton" type="submit" name=close_method value="Save" tabindex=$tab>&nbsp;&nbsp;
</td>
</tr>
<tr>
<td class=$form_class>Type:
<input type=hidden name=type value="$method{'type'}">
</td>
<td class=$form_class>$method{'type'}
</td>
</tr>
<tr>
<td class=$form_class valign=top>Description:
</td>);
    $tab++;
    my $description = $method{'description'};
    $description = '' if not defined $description;
    $detail .= qq(
<td class=$form_class valign=top>
<textarea rows=4 cols=100 wrap=virtual name=description tabindex=$tab>$description</textarea>
</td>
</tr>
</table>
</td>
</tr>);

    if ( $method{'type'} eq 'Nmap' ) {
	unless ( $method{'scan_type'} ) {
	    $method{'scan_type'} = 'tcp_syn_scan';
	}
	my %selected = ( $method{'scan_type'} => 'checked' );
	$tab++;
	$options{'title'} = 'TCP SYN SCAN';
	$options{'width'} = 700;
	my $docs =
qq(TCP SYN SCAN is the most popular scan option for good reasons. It can be performed quickly, scanning thousands of ports per second on a fast network not hampered by intrusive firewalls. SYN scan is relatively unobtrusive and stealthy, since it never completes TCP connections. It also works against any compliant TCP stack rather than depending on idiosyncrasies of specific platforms as Nmap's FIN/null/Xmas, Maimon and idle scans do. It also allows clear, reliable differentiation between the open, closed, and filtered states.<br>
<p class='append'>This technique is often referred to as half-open scanning, because you don't open a full TCP connection. You send a SYN packet, as if you are going to open a real connection and then wait for a response. A SYN/ACK indicates the port is listening (open), while a RST (reset) is indicative of a non-listener. If no response is received after several retransmissions, the port is marked as filtered. The port is also marked filtered if an ICMP unreachable error (type 3, code 1,2, 3, 9, 10, or 13) is received.</p>);
	my $tooltip = $tt->tooltip( $docs, \%options );

	my $tcp_syn_scan = $selected{'tcp_syn_scan'};
	$tcp_syn_scan = '' if not defined $tcp_syn_scan;
	$detail .= qq(
<tr>
<td class=data0>
<table width="100%" cellpadding=7 cellspacing=0 align=left border=0>
<tr>
<td class=wizard_title_heading><b>Scan Type</b></td>
<td class=wizard_title_heading></td>
</tr>
<tr>
<td class=$form_class valign=top width=200px><input class=radio type=radio name=scan_type value=tcp_syn_scan $tcp_syn_scan onclick="setScanOpts('tcp_syn_scan');" tabindex=$tab> TCP SYN SCAN
</td>
<td class=$form_class>
    <a class=orange href="#" $tooltip tabindex=-1>TCP SYN SCAN</a> is the most popular scan option. It can be performed quickly, scanning thousands of ports per second on a fast network.
</td>
</tr>);
	$tab++;
	$options{'title'} = 'TCP CONNECT SCAN';
	$docs =
qq(TCP CONNECT SCAN is the scan type to use when the TCP SYN SCAN is not an option. This is the case when a user does not have raw packet privileges or is scanning IPv6 networks. Instead of writing raw packets as most other scan types do, Nmap asks the underlying operating system to establish a connection with the target machine and port by issuing the connect() system call. This is the same high-level system call that web browsers, P2P clients, and most other network-enabled applications use to establish a connection. It is part of a programming interface known as the Berkeley Sockets API. Rather than read raw packet responses off the wire, Nmap uses this API to obtain status information on each connection attempt.<br>
<p class='append'>
    When SYN scan is available, it is usually a better choice. Nmap has less control over the high level connect() call than with raw packets, making it less efficient. The system call completes connections to open target ports rather than performing the half-open reset that SYN scan does. Not only does this take longer and require more packets to obtain the same information, but target machines are more likely to log the connection. A decent IDS will catch either, but most machines have no such alarm system. Many services on your average Unix system will add a note to syslog, and sometimes a cryptic error message, when Nmap connects and then closes the connection without sending data. Truly pathetic services crash when this happens, though that is uncommon. An administrator who sees a bunch of connection attempts in her logs from a single system should know that she has been connect scanned.</p>);
	$tooltip = $tt->tooltip( $docs, \%options );

	my $tcp_connect_scan = $selected{'tcp_connect_scan'};
	$tcp_connect_scan = '' if not defined $tcp_connect_scan;
	$detail .= qq(
<tr>
<td class=$form_class valign=top width=200px><input class=radio type=radio name=scan_type value=tcp_connect_scan $tcp_connect_scan onclick="setScanOpts('tcp_connect_scan');" tabindex=$tab> TCP CONNECT SCAN
</td>
<td class=$form_class>
    <a class=orange href="#" $tooltip tabindex=-1>TCP CONNECT SCAN</a> is the scan type to use when the TCP SYN SCAN is not an option. This is the case when a user does not have raw packet privileges or is scanning IPv6 networks.
</td>
</tr>);
	$tab++;
	$options{'title'} = 'UDP SCAN';
	$docs =
qq(While most popular services on the Internet run over the TCP protocol, UDP services are widely deployed. DNS, SNMP, and DHCP (registered ports 53, 161/162, and 67/68) are three of the most common. Because UDP scanning is generally slower and more difficult than TCP, some security auditors ignore these ports. This is a mistake, as exploitable UDP services are quite common and attackers certainly don\'t ignore the whole protocol. Fortunately, Nmap can help inventory UDP ports.);

	$tooltip = $tt->tooltip( $docs, \%options );
	my $udp_scan = $selected{'udp_scan'};
	$udp_scan = '' if not defined $udp_scan;
	$detail .= qq(
<tr>
<td class=$form_class valign=top width=200px><input class=radio type=radio name=scan_type value=udp_scan $udp_scan onclick="setScanOpts('udp_scan');" tabindex=$tab>UDP SCAN
</td>
<td class=$form_class>
    <a class=orange href="#" $tooltip tabindex=-1>UDP SCAN</a>: While most popular services on the Internet run over the TCP protocol, UDP services are widely deployed. DNS, SNMP, and DHCP (registered ports 53, 161/162, and 67/68) are three of the most common.
</td>
</tr>
</table>
</td>
</tr>);
	my $checked = $method{'tcp_snmp_check'} ? 'checked' : '';
	$options{'title'} = 'UDP SNMP Check';
	$docs =
qq(For scan types TCP SYN SCAN and TCP CONNECT SCAN optionally have a follow-up UDP scan to help determine whether or not the device is SNMP-enabled.  If the UDP scan finds one or more SNMP ports open the device is flagged for further processing. This feature works with discovery definitions that include a UDP SCAN method and/or an SNMP method. Selecting this option will add to the time it takes it takes to discover each device.);
	$tooltip = $tt->tooltip( $docs, \%options );
	$tab++;
	$detail .= qq(
<tr>
<td class=data0>
<table width="100%" cellpadding=7 cellspacing=0 align=left border=0>
<tr>
<td class=wizard_title_heading><b>UDP SNMP Check</b></td>
<td class=wizard_title_heading></td>
</tr>
<tr>
<td class=$form_class valign=top width=200px><input class=checkbox type=checkbox name=tcp_snmp_check value="1" $checked tabindex=$tab></td>
<td class=$form_class>
<a class=orange href="#" $tooltip tabindex=-1>UDP SNMP Check</a>: Optionally have a follow-up UDP scan to check if the device is SNMP-enabled. Note that this option may not work across firewalls, and is recommended for scanning the local area network only. Use for remote networks only when you are sure all the intervening routers and firewalls will forward UDP traffic in both directions.
</td>
</tr>
</table>
</td>
</tr>);

	$options{'title'} = 'SNMP Match Strings';
	$docs =
qq(For scan types TCP SYN SCAN and TCP CONNECT SCAN optionally provide a comma separated list of match strings to flag a discovered operating system as an SNMP-enabled device for further processing. This feature works with discovery definitions that include a UDP SCAN method and/or an SNMP method.);
	$tooltip = $tt->tooltip( $docs, \%options );
	$tab++;

	my $snmp_strings = $method{'snmp_strings'};
	$snmp_strings = '' if not defined $snmp_strings;
	$detail .= qq(
<tr>
<td class=data0>
<table width="100%" cellpadding=7 cellspacing=0 align=left border=0>
<tr>
<td class=wizard_title_heading><b>SNMP Match Strings</b></td>
<td class=wizard_title_heading></td>
</tr>
<tr>
<td class=$form_class valign=top colspan=2><input type=text name=snmp_strings size=70 value="$snmp_strings" tabindex=$tab></td>
</tr>
<tr>
<td class=$form_class valign=top width=200px></td>
<td class=$form_class><a class=orange href="#" $tooltip tabindex=-1>SNMP Match Strings</a>: Optionally provide a comma-separated list of match strings to flag a discovered operating system as an SNMP-enabled device.  This matching is case-insensitive.  Such flagging is in addition to whatever hosts may be discovered to be SNMP-enabled via other checks, and is not a constricting filter on those other results.</td>
</tr>
</table>
</td>
</tr>);

	unless ( $method{'timeout'} ) { $method{'timeout'} = 'Normal' }
	# GWMON-5006
	$method{'timeout'} = 'Sneaky' if $method{'timeout'} eq 'Paranoid';
	%selected = ( $method{'timeout'} => 'selected' );
	$options{'title'} = 'SCAN TIMEOUT';
	$docs =
qq(The timeout methods are sneaky, polite, normal, aggressive, and insane. These timeout algorithms allow the user to specify how aggressive they wish to be, while leaving Nmap to pick the exact timing values.<p class=append>Sneaky mode is for IDS evasion; it scans only one port at a time and waits 15 seconds between probes. Polite mode slows down the scan to use less bandwidth and target machine resources. Normal mode is the default, and includes parallelization. Aggressive mode speeds scans up by making the assumption that you are on a reasonably fast and reliable network. Finally, insane mode assumes that you are on an extraordinarily fast network or are willing to sacrifice some accuracy for speed.</p>);

	$tooltip = $tt->tooltip( $docs, \%options );
	$tab++;

	my $Sneaky     = $selected{'Sneaky'};
	my $Polite     = $selected{'Polite'};
	my $Normal     = $selected{'Normal'};
	my $Aggressive = $selected{'Aggressive'};
	my $Insane     = $selected{'Insane'};
	$Sneaky     = '' if not defined $Sneaky;
	$Polite     = '' if not defined $Polite;
	$Normal     = '' if not defined $Normal;
	$Aggressive = '' if not defined $Aggressive;
	$Insane     = '' if not defined $Insane;

	$detail .= qq(
<tr>
<td class=data0>
<table width="100%" cellpadding=7 cellspacing=0 align=left border=0>
<tr>
<td class=wizard_title_heading colspan=2><b>Scan Timeout</b></td>
</tr>
<tr>
<td class=$form_class width=200px valign=top>
<select name=timeout tabindex=$tab>
	<option value="Sneaky" $Sneaky>Sneaky</option>
	<option value="Polite" $Polite>Polite</option>
	<option value="Normal" $Normal>Normal</option>
	<option value="Aggressive" $Aggressive>Aggressive</option>
	<option value="Insane" $Insane>Insane</option>
</select>
</td>
<td class=$form_class valign=top>
<a class=orange href="#" $tooltip tabindex=-1>SCAN TIMEOUT</a>: The timeout methods are sneaky (slow), polite, normal, aggressive, and insane (fast). These timeout algorithms allow the user to specify how aggressive they wish to be, while leaving Nmap to pick the exact timing values.
</td>
</tr>
</table>
</td>
</tr>
<tr>
<td class=data0>
<table width="100%" cellpadding=7 cellspacing=0 align=left border=0>
<tr>
<td class=wizard_title_heading><b>Ports</b>
</td>
</tr>
<tr>
<td width="100%">
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class=column_head align=left width=225px>Ports</td>
<td class=column_head align=left colspan=2>Match Value</td>
</tr>);
	my $color = 'dk';
	foreach my $port ( sort keys %method ) {
	    if ( $port =~ /port_(\S+)/ ) {
		if ( $color eq 'lt' ) {
		    $color = 'dk';
		}
		elsif ( $color eq 'dk' ) {
		    $color = 'lt';
		}
		$tab++;
		$detail .= qq(
<tr>
<td class=row_$color width=225px>$1
<input type=hidden name=ports value="$1">
</td>
<td class=row_$color>$method{$port}<input type=hidden name=value_$1 value="$method{$port}">
</td>
<td class=row_$color align=right width=75px><input type=submit class=removebutton_$color name=remove_port_$1 value="delete port" tabindex=$tab>
</td>
</tr>);
	    }
	}

	$options{'title'} = 'Add Port';
	$docs =
"\nEnter the port number and optionally the value to store as a match when the port is found to be active. If left blank, the stored match value will be what Nmap returns";
	$tooltip = $tt->tooltip( $docs, \%options );
	$tab++;
	$detail .= qq(
</table>
</td>
</tr>
<tr>
<td class=$form_class colspan=2>
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class=row2 width="100%">
<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
<tr>
<td class=row2 width=220px><input type=text name=port size=7 tabindex=$tab></td>);
	$tab++;
	$detail .= qq(
<td class=row2><input type=text name=value id=value size=60 autocomplete="off" tabindex=$tab>&nbsp;&nbsp;<a class=orange href="#" $tooltip tabindex=-1>&nbsp;?&nbsp;</a></td>);

	$tab++;
	$detail .= qq(
<td class=row2 valign=top width=75px align=right><input class="submitbutton" type="submit" name=add_port value="Add Port" tabindex=$tab>
</td>
</tr>
</table>
</td>
</tr>
</table>
</td>
</tr>
</table>
</td>
</tr>);
    }
    elsif ( $method{'type'} eq 'SNMP' ) {
	$tab++;
	unless ( $method{'snmp_ver'} ) { $method{'snmp_ver'} = '2c' }
	my %checked = ( $method{'snmp_ver'} => 'checked' );
	my %class_v3 = ( 'enabled' => 'enabled',  'disabled' => 'disabled' );
	my %class    = ( 'enabled' => 'disabled', 'disabled' => 'enabled' );
	unless ( $method{'snmp_ver'} ) { $method{'snmp_ver'} = '2c' }
	my $checked_1  = $checked{'1'};
	my $checked_2c = $checked{'2c'};
	my $checked_3  = $checked{'3'};
	$checked_1  = '' if not defined $checked_1;
	$checked_2c = '' if not defined $checked_2c;
	$checked_3  = '' if not defined $checked_3;
	$detail .= qq(
<tr>
<td class=data0>
<table width="100%" cellpadding=7 cellspacing=0 align=left border=0>
<tr>
<td class=wizard_title_heading colspan=2><b>Community strings and SNMP version 3 authorization</b></td>
</tr>
<tr>
<td class=$form_class width=250px>SNMP version:
</td>
<td class=$form_class>
<input type=radio name=snmp_ver id=snmp_ver value="1" $checked_1 onclick="setVersion('1');" tabindex=$tab>&nbsp;1&nbsp;&nbsp;);
	$tab++;
	$detail .= qq(
<input type=radio name=snmp_ver id=snmp_ver value="2c" $checked_2c onclick="setVersion('2c');" tabindex=$tab>&nbsp;2c&nbsp;&nbsp;);
	$tab++;
	$detail .= qq(
<input type=radio name=snmp_ver id=snmp_ver value="3" $checked_3 onclick="setVersion('3');" tabindex=$tab>&nbsp;3
</td>
</tr>);
	my $doc = qq(
	      <table border=1 bgcolor="#d0d0ff">
	<tr bgcolor="#d0ffd0"><th>Parameter</th><th>Command Line Flag</th><th>snmp.conf token</th></tr>
	<tr><td>securityName</td><td>-u <i>NAME</i></td><td>defSecurityName NAME</td></tr>

	<tr><td>authProtocol</td><td>-a <i>(MD5|SHA)</i></td><td>defAuthType (MD5|SHA)</td></tr>
	<tr><td>privProtocol</td><td>-x <i>(AES|DES)</i></td><td>defPrivType DES</td></tr>
	<tr><td>authKey</td><td>-A <i>PASSPHRASE</i></td><td>defAuthPassphrase PASSPHRASE</td></tr>

	<tr><td>privKey</td><td>-X <i>PASSPHRASE</i></td><td>defPrivPassphrase PASSPHRASE</td></tr>
	<tr><td>securityLevel</td><td>-l <i>(noAuthNoPriv|authNoPriv|authPriv)</i></td><td>defSecurityLevel (noAuthNoPriv|authNoPriv|authPriv)</td></tr>
	<tr><td>context</td><td>-n <i>CONTEXTNAME</i></td><td>defContext CONTEXTNAME</td></tr>

      </table>
);
	$tab++;
	my $class_v3_method_snmp_ver_3 = $class_v3{ $method{'snmp_ver_3'} } if defined $method{'snmp_ver_3'};
	$class_v3_method_snmp_ver_3 = '' if not defined $class_v3_method_snmp_ver_3;

	my $snmp_v3_user = $method{'snmp_v3_user'};
	$snmp_v3_user = '' if not defined $snmp_v3_user;
	$detail .= qq(
<tr>
<td class=$form_class width=250px>SNMP v3 user:
</td>
<td class=$class_v3_method_snmp_ver_3><input type=text name=snmp_v3_user size=30 value="$snmp_v3_user" tabindex=$tab>
</td>
</tr>);
	$tab++;

	unless ( $method{'snmp_v3_authProtocol'} ) {
	    $method{'snmp_v3_authProtocol'} = 'none';
	}
	unless ( $method{'snmp_v3_privProtocol'} ) {
	    $method{'snmp_v3_privProtocol'} = 'none';
	}
	unless ( $method{'snmp_v3_securityLevel'} ) {
	    $method{'snmp_v3_securityLevel'} = 'noAuthNoPriv';
	}
	%checked = (
	    $method{'snmp_v3_authProtocol'}  => 'checked',
	    $method{'snmp_v3_privProtocol'}  => 'checked',
	    $method{'snmp_v3_securityLevel'} => 'checked'
	);
	$checked{'authProtocol_none'} = $method{'snmp_v3_authProtocol'} eq 'none' ? 'checked' : '';
	$checked{'privProtocol_none'} = $method{'snmp_v3_privProtocol'} eq 'none' ? 'checked' : '';
	my $class_v3_method_snmp_ver = $class_v3{$method{'snmp_ver'}};
	$class_v3_method_snmp_ver = '' if not defined $class_v3_method_snmp_ver;
	$detail .= qq(
<tr>
<td class=$form_class width=250px>SNMP v3 authentication protocol:
</td>
<td class=$class_v3_method_snmp_ver>
<input type=radio name=snmp_v3_authProtocol value=none $checked{'authProtocol_none'} tabindex=$tab>&nbsp;None&nbsp;&nbsp;);
	$tab++;
	my $MD5 = $checked{'MD5'};
	$MD5 = '' if not defined $MD5;
	$detail .= qq(
<input type=radio name=snmp_v3_authProtocol value=MD5 $MD5 tabindex=$tab>&nbsp;MD5&nbsp;&nbsp;);
	$tab++;
	my $SHA = $checked{'SHA'};
	$SHA = '' if not defined $SHA;
	$detail .= qq(
<input type=radio name=snmp_v3_authProtocol value=SHA $SHA tabindex=$tab>&nbsp;SHA&nbsp;&nbsp;);
	$tab++;
	my $snmp_v3_authKey = $method{'snmp_v3_authKey'};
	$snmp_v3_authKey = '' if not defined $snmp_v3_authKey;
	$detail .= qq(
&nbsp;&nbsp;SNMP v3 authentication key:&nbsp;&nbsp;<input type=password name=snmp_v3_authKey size=30 value="$snmp_v3_authKey" tabindex=$tab>
</td>
</tr>);
	$tab++;
	$detail .= qq(
<tr>
<td class=$form_class width=250px>SNMP v3 privacy protocol:
</td>
<td class=$class_v3_method_snmp_ver>
<input type=radio name=snmp_v3_privProtocol value=none $checked{'privProtocol_none'} tabindex=$tab>&nbsp;None&nbsp;&nbsp;);
	$tab++;
	my $AES = $checked{'AES'};
	$AES = '' if not defined $AES;
	$detail .= qq(
<input type=radio name=snmp_v3_privProtocol value=AES $AES tabindex=$tab>&nbsp;AES&nbsp;&nbsp;);
	$tab++;
	my $DES = $checked{'DES'};
	$DES = '' if not defined $DES;
	$detail .= qq(
<input type=radio name=snmp_v3_privProtocol value=DES $DES tabindex=$tab>&nbsp;DES&nbsp;&nbsp;);
	$tab++;
	my $snmp_v3_privKey = $method{'snmp_v3_privKey'};
	$snmp_v3_privKey = '' if not defined $snmp_v3_privKey;
	$detail .= qq(
&nbsp;&nbsp;&nbsp;SNMP v3 privacy key:&nbsp;&nbsp;<input type=password name=snmp_v3_privKey size=30 value="$snmp_v3_privKey" tabindex=$tab>
</td>
</tr>);
	$tab++;
	my $noAuthNoPriv = $checked{'noAuthNoPriv'};
	$noAuthNoPriv = '' if not defined $noAuthNoPriv;
	$detail .= qq(
<tr>
<td class=$form_class width=250px>SNMP v3 security level:
</td>
<td class=$class_v3_method_snmp_ver>
<input type=radio name=snmp_v3_securityLevel value=noAuthNoPriv $noAuthNoPriv tabindex=$tab>&nbsp;None&nbsp;&nbsp;);
	$tab++;
	my $authNoPriv = $checked{'authNoPriv'};
	$authNoPriv = '' if not defined $authNoPriv;
	$detail .= qq(
<input type=radio name=snmp_v3_securityLevel value=authNoPriv $authNoPriv tabindex=$tab>&nbsp;Authentication only&nbsp;&nbsp;);
	$tab++;
	my $authPriv = $checked{'authPriv'};
	$authPriv = '' if not defined $authPriv;
	$detail .= qq(
<input type=radio name=snmp_v3_securityLevel value=authPriv $authPriv tabindex=$tab>&nbsp;Authentication and privacy&nbsp;&nbsp;);
	$tab++;
	$detail .= qq(
</td>
</tr>);
	$tab++;

	my $snmp_v3_misc = $method{'snmp_v3_misc'};
	$snmp_v3_misc = '' if not defined $snmp_v3_misc;
	$detail .= qq(
<tr>
<td class=$form_class width=250px>SNMP v3 misc options:
</td>
<td class=$class_v3_method_snmp_ver><input type=text name=snmp_v3_misc size=70 value="$snmp_v3_misc" tabindex=$tab>
</td>
</tr>);

	$tab++;
	my $class_method_snmp_ver = $class{$method{'snmp_ver'}};
	$class_method_snmp_ver = '' if not defined $class_method_snmp_ver;

	my $community_strings = $method{'community_strings'};
	$community_strings = '' if not defined $community_strings;
	$detail .= qq(
<tr>
<td class=$form_class width=250px>
<!--
// Use this, or equivalent, when the back end is equipped to correctly handle multiple strings.
Community strings (comma separated list):
-->
Single community string:
</td>
<td class=$class_method_snmp_ver><input type=text name=community_strings size=70 value="$community_strings" tabindex=$tab>
</td>
</tr>
</table>
</td>
</tr>
<script type="text/javascript" language=JavaScript>
var snmp_ver = "$method{'snmp_ver'}";
function setVersion(ver) {
	if (ver == '3') {
		document.form.snmp_v3_user.disabled = false;
		document.form.snmp_v3_user.className = 'enabled';
		document.form.snmp_v3_authKey.disabled = false;
		document.form.snmp_v3_authKey.className = 'enabled';
		document.form.snmp_v3_privKey.disabled = false;
		document.form.snmp_v3_privKey.className = 'enabled';
		document.form.snmp_v3_privProtocol.disabled = false;
		document.form.snmp_v3_privProtocol.className = 'enabled';
		document.form.snmp_v3_securityLevel.disabled = false;
		document.form.snmp_v3_securityLevel.className = 'enabled';
		document.form.snmp_v3_misc.disabled = false;
		document.form.snmp_v3_misc.className = 'enabled';
		document.form.community_strings.disabled = true;
		document.form.community_strings.className = 'disabled';
	} else {
		document.form.snmp_v3_user.disabled = true;
		document.form.snmp_v3_user.className = 'disabled';
		document.form.snmp_v3_authKey.disabled = true;
		document.form.snmp_v3_authKey.className = 'disabled';
		document.form.snmp_v3_privKey.disabled = true;
		document.form.snmp_v3_privKey.className = 'disabled';
		document.form.snmp_v3_privProtocol.disabled = true;
		document.form.snmp_v3_privProtocol.className = 'disabled';
		document.form.snmp_v3_securityLevel.disabled = true;
		document.form.snmp_v3_securityLevel.className = 'disabled';
		document.form.snmp_v3_misc.disabled = true;
		document.form.snmp_v3_misc.className = 'disabled';
		document.form.community_strings.disabled = false;
		document.form.community_strings.className = 'enabled';
	}
}
function initialVersion() {
	setVersion(snmp_ver);
}
// Like "window.onload = initialVersion;" but does not override any existing onload handlers.
if (window.attachEvent) {window.attachEvent('onload', initialVersion);}
else if (window.addEventListener) {window.addEventListener('load', initialVersion, false);}
else {document.addEventListener('load', initialVersion, false);}
</script>);
    }
    elsif ( $method{'type'} eq 'WMI' ) {
	my %selected = defined( $method{'wmi_type'} ) ? ( $method{'wmi_type'} => 'checked' ) : ();
	$tab++;
	my $Server = $selected{'Server'};
	$Server = '' if not defined $Server;
	$detail .= qq(
<tr>
<td class=data0>
<table width="100%" cellpadding=7 cellspacing=0 align=left border=0>
<tr>
<td class=wizard_title_heading colspan=2 valign=top><b>WMI Type</b>
</td>
</tr>
<tr>
<td class=$form_class width=100px valign=top>
<input name=wmi_type type=radio value='Server' $Server tabindex=$tab>&nbsp;Server
</td>
<td class=$form_class valign=top>
Select <b>Server</b> if you have one or more GroundWork Passive WMI Servers running on your network.
</td>
</tr>);
	$tab++;
	my $Proxy = $selected{'Proxy'};
	$Proxy = '' if not defined $Proxy;
	$detail .= qq(
<tr>
<td class=$form_class width=100px valign=top>
<input name=wmi_type type=radio value='Proxy' $Proxy disabled tabindex=$tab>&nbsp;Proxy
</td>
<td class=$form_class valign=top>
Select <b>Proxy</b> if your Windows checks run through one or more WMI proxy servers. You may specify the servers in Ranges and Filters, or combine this method with an Nmap method and let Nmap discover the WMI proxies.
<p class=append>Auto-Discovery using the Proxy option is currently not implemented.</p>
</tr>
</table>
</td>
</tr>);
    }
    else {
	my %selected = defined( $method{'script_type'} ) ? ( $method{'script_type'} => 'checked' ) : ();
	my $batch_mode_checkbox_value = ( defined( $method{'run_mode'} ) && $method{'run_mode'} eq 'Batch Mode' ) ? 'checked' : 'unchecked';
	$tab++;
	$detail .= qq(
<tr>
<td class=data0>
<table width="100%" cellpadding=7 cellspacing=0 align=left border=0>
<tr>
<td class=$form_class width=200px rowspan=2 valign=top><b>Script type</b>
</td>
<td class=$form_class width=150px valign=top>
<input name=script_type type=radio value='Custom' checked tabindex=$tab>&nbsp;Custom
</td>
<td class=$form_class valign=top>
Currently only <b>Custom</b> scripts are supported. Custom scripts can run independent of Ranges and Filters as well as other discovery methods.
</td>
</tr>
</table>
</td>
</tr>);
	$tab++;
	$detail .= qq(
<tr>
<td class=data0>
<table width="100%" cellpadding=7 cellspacing=0 align=left border=0>
<tr>
<td class=$form_class width=200px valign=top><b>Run Mode</b>
</td>
<td class=$form_class width=150px valign=top>
<table width="100%" cellpadding=0 cellspacing=0 align=left border=0>
<tr>
<td class=$form_class valign=top>
<input name=run_mode type=checkbox value='Batch Mode' $batch_mode_checkbox_value tabindex=$tab>
</td>
<td class=$form_class valign=top>&nbsp;Batch&nbsp;Mode</td>
</tr>
</table>
</td>
<td class=$form_class valign=top>
In batch mode, a script will only be executed once during a discovery. When not in batch mode, scripts are executed once for each host with a matching method.
</td>
</tr>
</table>
</td>
</tr>);
	$tab++;
	my $command_line = $method{'command_line'};
	$command_line = '' if not defined $command_line;
	$detail .= qq(
<tr>
<td class=data0>
<table width="100%" cellpadding=7 cellspacing=0 align=left border=0>
<tr>
<td class=wizard_title_heading><b>Command Line</b></td>
</tr>
<tr>
<td class=$form_class style="padding-bottom: 0;" >Enter the full path, script name, and command line arguments. Command line arguments may include Nagios macros such as \$HOST\$.</td>
</tr>
<tr>
<td class=$form_class><input type=text name=command_line size=116 value="$command_line" tabindex=$tab></td>
</tr>
</table>
</td>
</tr>);
    }
    return $detail, $tab;
}

#	filters

sub manage_filters(@) {
    my %object  = %{ $_[1] };
    my %filters = %{ $_[2] };
    my $tab     = $_[3];
    use HTML::Tooltip::Javascript;
    my $tt = HTML::Tooltip::Javascript->new(
	## URL path to where wz_tooltip.js is.
	javascript_dir => $monarch_js,
	options        => {
	    bgcolor     => '#000000',
	    default_tip => 'Tip not defined',
	    delay       => 0,
	    title       => 'Tooltip',
	},
    );
    my %options = (
	borderwidth => '1',
	padding     => '10',
	bordercolor => '#000000',
	bgcolor     => '#FFFFFF',
	width       => '755',
	left        => '1',
	fontsize    => '12px'
    );

    $options{'title'} = 'Ranges and Filters';
    my $docs =
"Ranges and Filters describe the network addresses that will be examined by the discovery method. Various formats are supported, as listed in the help message for the Range/Filter Pattern.\n<br><p class='append'>\nAddresses may be excluded from the range using the same mechanism. Note that excluded addresses and ranges are never probed regardless of the input order.</p>";
    my $tooltip = $tt->tooltip( $docs, \%options );

    my $detail = qq(
<script type="text/javascript" language=JavaScript>
function filterSet()
{
  box = eval("document.form.set_filter");
  if (box.checked == false) {
    with (document.form) {
      for (var i=0; i < elements.length; i++) {
	if (elements[i].type == 'checkbox' && (elements[i].id == 'filter_checked'))
	  elements[i].checked = false;
      }
    }
  } else {
    with (document.form) {
      for (var i=0; i < elements.length; i++) {
	if (elements[i].type == 'checkbox' && (elements[i].id == 'filter_checked'))
	  elements[i].checked = true;
      }
    }
  }
}
</script>
<tr>
<td class=data0>
<table width="100%" cellpadding=7 cellspacing=0 align=left border=0>
	<tr>
	<td class=wizard_title_heading><b>Ranges and Filters</b>&nbsp;&nbsp;<a class=orange href="#" $tooltip tabindex="-1">&nbsp;?&nbsp;</a></td>
	</tr>
	<tr>
	<td>
	<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
		<tr>
		<td class=column_head align=left width=15px><input class=checkbox_black type=checkbox name=set_filter id=set_filter value="" onClick="filterSet()"></td>
		<td class=column_head align=left width=200px>Range/Filter Name</td>
		<td class=column_head align=left width=100px>Type</td>
		<td class=column_head align=left>Range/Filter Pattern</td>
		<td class=column_head align=right width=75px>&nbsp;</td>
		</tr>);

    my $color = 'dk';
    foreach my $filter ( sort keys %filters ) {
	my $selected = $object{'filter'}{$filter} ? 'checked' : '';
	if ( $color eq 'lt' ) {
	    $color = 'dk';
	}
	elsif ( $color eq 'dk' ) {
	    $color = 'lt';
	}
	$tab++;
	my $class="row_$color";
	$detail .= qq(
		<tr>
		<td class=$class valign=top><input class=$class type=checkbox name=filter id=filter_checked value="$filter" $selected></td>
		<td class=$class valign=top>$filter</td>
		<td class=$class valign=top>$filters{$filter}{'type'}</td>
		<input type=hidden name="type_$filter" value="$filters{$filter}{'type'}">
		<td class=$class>$filters{$filter}{'filter'}</td>
		<input type=hidden name="filter_$filter" value="$filters{$filter}{'filter'}">
		<td class=$class align=right valign=top><input type=submit class=removebutton_$color name="delete_filter_$filter" value="delete range/filter" tabindex=$tab></td>
		</tr>);

    }
    $options{'title'} = 'Add Filter';
    $docs =
qq{Range format can be any of:<p class='append'><ul>\n<li>Unqualified hostname (e.g., mybox)\n<li>Qualified hostname (e.g., mybox.mydomain.com)\n<li>Single address (e.g., 192.168.0.1)\n<li>Address range (e.g., 192.168.0.2 - 192.168.0.10)\n<li>Abbreviated address range: (e.g., 192.168.0.10-12)\n<li>Class C subnet (e.g., 192.168.0.*).\n<li>Abbreviated multiple Class C subnets (e.g., 192.168.42-50)\n<li>CIDR block (e.g., 192.168.144.0/20)\n<li>Comma-separated list of any of the above (e.g., 192.168.0.1, 192.168.0.3)\n</ul></p>\n<p class='append'>In Class C specifications, the network (.0) and broadcast (.255) addresses will be automatically ignored. Equivalent addresses will be ignored in CIDR blocks with a subnet prefix smaller than /31.</p>\n<p class='append'>If you are using a discovery script to generate a list of hosts, you need to put a dummy value into this field in order to make the discovery proceed.</p>\n};
    $tooltip = $tt->tooltip( $docs, \%options );

    $tab++;
    $detail .= qq(
	</table>
	<table width="100%" cellpadding=7 cellspacing=0 align=left border=0 style="margin-top: 7px;">
		<tr>
		<td class=row2>
		<table width="100%" cellpadding=0 cellspacing=0 align=left border=0>
			<tr>
			<td class=row2_column_head valign=top>Range/Filter Name</td>
			<td class=row2_column_head valign=top>Type</td>
			<td class=row2_column_head>Range/Filter Pattern&nbsp;&nbsp;<a class=orange href="#" $tooltip tabindex=-1>&nbsp;?&nbsp;</a></td>
			</tr>
			<tr>
			<td class=row2 width="20%" ><input type=text name=filter_name size=30 tabindex=$tab></td>
			<td class=row2>
			<select name=filter_type tabindex=$tab>
			<option value="include">include</option>
			<option value="exclude">exclude</option>
			</select>
			</td>
			<td class=row2 width="40%"><input type=text name=filter_value size=60 tabindex=$tab></td>
			<td class=row2 width="30%" valign=top align=right><input class="submitbutton" type="submit" name=add_filter value="Add Range/Filter" tabindex=$tab>
			</td>
			</tr>
		</table>
		</td>
		</tr>
	</table>
	</td>
	</tr>
</table>);
    $detail .= $tt->at_end;
    $detail .= qq(
</td>
</tr>);
    return $detail;
}

sub delete_group(@) {
    my $name    = $_[1];
    my %methods = %{ $_[2] };
    my $tab     = 0;
    my $detail  = qq(
<script type="text/javascript" language=JavaScript>
function methodSet()
{
  box = eval("document.form.set_method");
  if (box.checked == false) {
   with (document.form) {
     for (var i=0; i < elements.length; i++) {
	if (elements[i].type == 'checkbox' && (elements[i].id == 'method_checked'))
	   elements[i].checked = false;
     }
   }
  } else {
   with (document.form) {
     for (var i=0; i < elements.length; i++) {
	if (elements[i].type == 'checkbox' && (elements[i].id == 'method_checked'))
	   elements[i].checked = true;
     }
   }
 }
}
</script>
<tr>
<td class=data>
<table width="100%" cellpadding=7 cellspacing=0 align=left border=0>
	<tr>
	<td class=wizard_title_heading colspan=5><b>Delete "$name"?</b></td>
	<input type=hidden name=discover_name value="$name">
	<tr>
	<tr>
	<td class=$form_class colspan=5>Are you sure you want to delete discovery definition $name and optionally its associated methods? Note: if you choose to delete methods, they will also be removed from all other discovery definitions.</td>
	<tr>
	<td width="60%">
		<table width="100%" cellpadding=$global_cell_pad cellspacing=0 align=left border=0>
			<tr>
			<td class=column_head align=left width=15px><input type=checkbox name=set_filter id=set_method value="" onClick="methodSet()"></td>
			<td class=column_head align=left width=200px>Method Name</td>
			<td class=column_head align=left width=100px>Type</td>
			<td class=column_head align=left>Description</td>
			</tr>);
    if ( keys %methods ) {

	my $class = 'row_dk';
	foreach my $method ( sort keys %methods ) {
	    if ( $class eq 'row_lt' ) {
		$class = 'row_dk';
	    }
	    elsif ( $class eq 'row_dk' ) {
		$class = 'row_lt';
	    }
	    $tab++;
	    my $description = $methods{$method}{'description'};
	    $description = '' if not defined $description;
	    $detail .= qq(
			<tr>
			<td class=$class width=15px valign=top><input type=checkbox name=method_id id=method_checked value="$methods{$method}{'id'}"></td>
			<td class=$class width=200px valign=top>$method</td>
			<td class=$class width=100px valign=top>$methods{$method}{'type'}</td>
			<td class=$class valign=top>$description</td>
			</tr>);
	}
    }
    else {
	$detail .= qq(
		<tr>
		<td class=$form_class width=15px valign=top>&nbsp;</td>
		<td class=$form_class colspan=3>There are no methods assigned.</td>
		</tr>);
    }
    $detail .= qq(
		</table>
	</td>
	</tr>
</table>
</td>
</tr>);
    return $detail;
}

sub discover_disclaimer(@) {

    my $detail = qq(
<script type="text/javascript" language=JavaScript>
function setSubmit() {
	if (document.form.accept.checked) {
		document.form.go_discover.className = 'submitbutton';
		document.form.go_discover.disabled = false;
	} else {
		document.form.go_discover.className = 'submitbutton_disabled';
		document.form.go_discover.disabled = true;
	}
}
</script>
<tr>
<td class=data>
<table width="100%" cellpadding=7 cellspacing=0 align=left border=0>
<tr>
<td class=wizard_title_heading><b>Start Discovery?</b></td>
</tr>
<tr>
<td class=$form_class>WARNING: This process may have an adverse impact on the networked environment.
You may also need to disable intrusion detection software or any policies which may prevent the
auto-configuration process from running.
</td>
</tr>
</table>
</td>
</tr>
<tr>
<td>
<table width="100%" cellpadding=7 cellspacing=0 align=left border=0>
<tr>
<td class=$form_class>
<input type=checkbox class=checkbox name=accept value=accept onclick="setSubmit();" tabindex=1>&nbsp;Accept&nbsp;&nbsp;&nbsp;
</td>
</tr>
</table>
</td>
</tr>);

    return $detail;
}

########################################
# Documentation
#

sub doc() {
    my %doc = ();
    $doc{'overview'} = qq(An import/update schema can be used with any data source from which a text delimited file can be extracted.);
    $doc{'define'}   = qq(Enter a unique name and either choose the appropriate schema type or create a new schema from an existing template. Selecting both a schema type and a template will override the template's schema type with your selected type.);

    # Schema types
    $doc{'host-import'} =
qq(Use host-import for most import/automation tasks. A full range of options is available to import/update hosts. Everything from assigning host groups and contact groups to parents and profiles can be defined.);
    $doc{'host-profile-sync'} =
qq(Use host-profile-sync when an external data source drives the monitor configuration. The data source determines which hosts are added and which hosts are removed based on host profile assignment.  For example, using Cacti as the data source with a corresponding host profile, a schema can be defined to sync the configuration database with the Cacti database. Hosts missing from the data source but that are part of the host profile assignment are automatically removed. A full range of options is available to import/update hosts. Everything from assigning host groups and contact groups to parents and profiles can be defined.);
    $doc{'other-sync'} =
qq(Use other-sync to align two pieces of data from an external data source. The other-sync schema type requires that host objects have been previously configured, but you can create configuration groups, host groups, and contact groups on the fly.);

    # Import data

    $doc{'data-source'} = qq(
Enter the folder and file name of the text delimited data source. This file must be under the <span style='white-space: nowrap;'><tt>$config_settings{'monarch_home'}/automation/data/</tt></span> directory.
<br>
<p class='append'>
A data source is a text delimited file that contains data records. A data record can be defined to a single line or can span multiple lines. For multiple line records, there must be a unique identifier, usually a host name or address, to tell the parser how to differentiate records. For schema types host-profile-sync and host-import you set the primary record by defining a match to a column of data and assigning it to the primary record object. If the primary record is not defined the parser will use the host name match definition.
</p><p class='append'>
If you have comments in your data, define a match to discard the line. For example, match begins-with &rArr; # &rArr; Discard record.
</p><p class='append'>
<b>Sample multiline data records using ;; as the text separator</b>
</p>
<pre>
# name;;address;;alias;;hostgroup;;contactgroup;;parent;;profile;;service profile<br>
router-1;;10.20.110.1;;router-1.alps.com;;italy-hosts;;italy-contacts;;;;;;<br>
grenoble;;10.20.110.60;;grenoble.alps.com;;france-hosts;;france-contacts;;router-1;;linux-hosts;;ssh-unix<br>
;;;;;;database-hosts;;database-contacts;;;;;;ssh-mysql<br>
;;;;;;;;;;;;;;ssh-ldap<br>
salzburg;;10.20.110.70;;salzburg.alps.com;;austria-hosts;;austria-contacts;;router-1;;linux-hosts;;ssh-unix<br>
;;;;;;network-hosts;;network-contacts;;;;;;ssh-apache<br>
;;;;;;;;;;;;;;ssh-ldap<br>
innsbruck;;10.20.110.80;;innsbruck.alps.com;;austria-hosts;;austria-contacts;;router-1;;linux-hosts;;ssh-unix<br>
;;;;;;database-hosts;;database-contacts;;;;;;ssh-mysql<br>
</pre>);

    $doc{'delimiter'} = qq(Select from the dropdown, or enable Other and enter your own text delimiter.);

    # Column definition

    $doc{'column'}{'position'} =
      qq(Defines the location of a data column. You can have many matches defined to a column but only one position can be defined per column.);
    $doc{'column'}{'name'} = qq(Identifies the column of data. It is not a match, but a unique identifier describing the column of data.);

    # Match definition

    $doc{'match'}{'order'} =
qq(Determines the sequence in which a match is processed. A match order is only useful when used in conjunction with the 'Assign value if undefined' rule or the 'Assign host profile if undefined' rule. It allows the most desirable match to set the property first, and prevents matches of lesser importance overriding the desired match. Properties and objects that can be applied are host name, address, alias and host profile.);
    $doc{'match'}{'name'} = qq(A unique identifier describing an action on a data point.);

    # Match types

    $doc{'type'}{'use-value-as-is'} = qq(use the record exactly as it is, usually to be applied directly to a property or object.);
    $doc{'type'}{'is-null'}         = qq(the match is true if the record has no value.);

    $doc{'type'}{'exact'} =
qq(match the record exactly while ignoring case. Note: Do not use this in combination with columns that contain service-definition records.);
    $doc{'type'}{'begins-with'}      = qq(match the start of the record exactly while ignoring case.);
    $doc{'type'}{'ends-with'}        = qq(match the end of the record exactly while ignoring case.);
    $doc{'type'}{'contains'}         = qq(match a record that contains the string exactly while ignoring case.);
    $doc{'type'}{'use-perl-reg-exp'} = qq(match using a Perl regular expression.);
    $doc{'type'}{'service-definition'} =
      qq(map the record to an existing service object. This match type requires a specific substring definition.);

    # Match string
    $doc{'string'}{'other'}            = qq(Enter the content you wish to match.);
    $doc{'string'}{'use-perl-reg-exp'} = qq(
Enter a Perl expression to match or capture content.
<br>
<p class='append'>
The actual Perl code used in the match is
</p><p class='append'>
&nbsp;&nbsp;\$value =~ / <i>your pattern match string</i> /i
</p><p class='append'>
so therefore DO NOT enter the beginning or ending / characters.
</p><p class='append'>
&nbsp;&nbsp;(\\S+)\\.\\S+\\.\\S+ correct
</p><p class='append'>
&nbsp;&nbsp;/(\\S+)\\.\\S+\\.\\S+/ incorrect
</p><p class='append'>
Example: parsing the host name from a fully qualified domain name ...
</p><p class='append'>
&nbsp;&nbsp;(\\S+)\\.\\S+\\.\\S+ will parse <i>host-name</i> from <i>host-name.domain.com</i>.
</p><p class='append'>
Some useful expression matching operators:
</p><p class='append'>
&nbsp;&nbsp;\\s matches one space character<br>
&nbsp;&nbsp;\\s* matches zero or more space characters<br>
&nbsp;&nbsp;\\s+ matches one or more space characters<br>
&nbsp;&nbsp;\\S matches one non-space character<br>
&nbsp;&nbsp;\\S* matches zero or more non-space characters<br>
&nbsp;&nbsp;\\S+ matches one or more non-space characters<br>
&nbsp;&nbsp;\\d* matches zero or more numeric characters<br>
&nbsp;&nbsp;\\d matches one numeric character<br>
&nbsp;&nbsp;\\d+ matches one or more numeric characters
</p>);
    $doc{'string'}{'service-delimiter'} = qq(
For match type service-definition, enter the substring delimiter for a service definition. A service definition must match an existing service object or the record will be ignored. One to five pieces of information can be included:<br>
<p class='append'></p>
<ol>
<li>
Service name (required) &mdash; A service name must match an existing service object.<br>
</li><li>
Command arguments (optional) &mdash; Provide the arguments to be given to the check command as they would appear in a Nagios definition. If not specified, the definition from the service object will be applied.<br>
</li><li>
Instance name (optional) &mdash; Specify an instance name to be appended to the service description. You may wish to use an underscore as the first character.<br>
</li><li>
Instance arguments (required for instance name) &mdash; Specify the arguments for the instance.<br>
</li><li>
Misc info (optional) &mdash; Miscellaneous information useful for applying other match criteria.<br>
</li>
</ol>
<p class='append'>
Multiple instances can be specified in a multi-line record. This example uses ;; for the main record delimiter and :: as the service substring delimiter:</p>
<p class='append'>
# name;;address;;alias;;hostgroup;;contactgroup;;parent;;profile;;service profile;;service<br>
router-1;;10.20.110.1;;router-1.alps.com;;italy-hosts;;italy-contacts;;;;;;;;snmp_if::::_1::1::<br>
;;;;;;network-hosts;;network-contacts;;;;;;;;snmp_if::::_2::2::<br>
;;;;;;;;;;;;;;;;snmp_if::::_3::3::<br>
;;;;;;;;;;;;;;;;snmp_if::::_4::4::<br>
;;;;;;;;;;;;;;;;snmp_if::::_5::5::<br>
;;;;;;;;;;;;;;;;snmp_if::::_6::6::<br>
;;;;;;;;;;;;;;;;snmp_if::::_7::7::<br>
;;;;;;;;;;;;;;;;snmp_if::::_8::8::<br>
;;;;;;;;;;;;;;;;snmp_if::::_9::9::<br>
;;;;;;;;;;;;;;;;snmp_if::::_10::10::<br>
;;;;;;;;;;;;;;;;snmp_if::::_11::11::<br>
;;;;;;;;;;;;;;;;snmp_if::::_12::12::<br>
;;;;;;;;;;;;;;;;snmp_if::::_13::13::<br>
;;;;;;;;;;;;;;;;snmp_if::::_14::14::<br>
;;;;;;;;;;;;;;;;snmp_if::::_15::15::<br>
;;;;;;;;;;;;;;;;snmp_if::::_16::16::<br>
;;;;;;;;;;;;;;;;snmp_if::::_17::17::<br>
;;;;;;;;;;;;;;;;snmp_if::::_18::18::<br>
;;;;;;;;;;;;;;;;snmp_if::::_19::19::<br>
;;;;;;;;;;;;;;;;snmp_if::::_20::20
</p>);

    $doc{'edit'} =
qq(Select or set the values to apply and choose Process Record to import/update the host. Note that if you process an existing host, the current configuration is always replaced. Select Discard to remove the record from processing, or select Cancel to return to normal processing.);
    $doc{'overrides'}{'disable'} = qq(Deselect records, disable overrides and return to normal processing.);
    $doc{'overrides'}{'enable'} =
      qq(Deselect records and enable overrides to batch process a group of hosts with values that override the schema matched results.);
    $doc{'overrides'}{'usage'} =
qq(To use overrides, select the records you wish to process, check the override checkbox, and then select one or more values. Next, chose the option to merge or replace. Merge will preserve schema matched values whereas replace does not. Note that if you process an existing host, the current configuration is always replaced.);

    # Rules and objects
    $doc{'rule'}{'Add if not exists and assign object'} =
qq(Creates the object and assigns it to the host. The objects that can be created are: contact groups, configuration groups and host groups.);

    $doc{'rule'}{'Assign object(s)'} =
      qq(On match, assign one or more parents, configuration groups, host groups, contact groups, or service profiles.);

    $doc{'rule'}{'Assign object if exists'} =
qq(Test to see if an object is defined and assign it to the host if it does. Objects that can be assigned are: parent hosts, configuration groups, host groups, service profile and contact groups.);

    $doc{'rule'}{'Assign value to'} =
      qq(Use the value to set the primary record or assign it to one of the following host properties: name, address, alias, or description.);

    $doc{'rule'}{'Assign value if undefined'} =
qq(Test to see if the primary record or property has been set by a previous match, and if not, assign the value. The options are: primary record, host name, address, alias, or description.);

    $doc{'rule'}{'Assign host profile if undefined'} =
      qq(Test to see if the host profile has been set by a previous match, and if not, assign the host profile.);

    $doc{'rule'}{'Convert dword and assign to'} =
qq(Convert a doubleword value (NeDi stores IP addresses as doublewords) and assign it to the primary record or one of the following host properties:  primary record, name, address, alias, or description.);

    $doc{'rule'}{'Discard if match existing host'} =
      qq(Don't process the record if a matching host record exists. This rule is important to preserve existing host configurations.);

    $doc{'rule'}{'Resolve to parent'} =
qq(This rule indicates that the current column contains the name of the current device' network parent. Note that this rule directive is only available if the "use-value-as-is" matching filter has been selected.);

    $doc{'rule'}{'Assign host profile'} =
qq(Use the match to assign a host profile. For example, if the description contains the word Cisco, assign a network host profile to the record.);

    $doc{'rule'}{'Assign service'} =
qq(This rule assigns a specified service entry to the currently selected host object, with the field data being used as the service entry name. If this rule is selected, you must also choose the service type to be used for the new service entry.);

    $doc{'rule'}{'Discard record'} =
      qq(Don't process the record if the match is true. Use this rule to exclude data such as comments or unwanted hosts from processing.);

    $doc{'rule'}{'Skip column record'} =
qq(This rule is used whenever a column contains multiple subordinate fields (as typically occurs when SNMP interfaces have been enumerated), and causes the automation processor to skip the current subordinate record in the current column.);

    $doc{'process'}{'overview'} =
qq(Use the sort and select options (see the mouse-over ? for details) to process records individually or in batches. Use edit when changing a single host, or use Enable Overrides and select a group of hosts to modify and process a batch of hosts. Select and Discard records you do not wish to process. If what you see does not look correct, use Edit Schema to make modifications and try again. For example, a common misstep is selecting the wrong delimiter. Records are displayed in blocks of 100.);

    $doc{'process'}{'Sort by'} =
qq(Records are arranged by their status: New Parent, New Host, Host Exists, Exception and Delete Host. Within each status you can sort by Primary record, Name, Address, and Alias.);

    $doc{'process'}{'New Parent'} =
qq(Select new parents for processing. These records have been flagged because they have child dependencies that are in the new host list. It is therefore desirable to process these records first so that parent child relationships are properly set. If child hosts are processed first, the parent host assignment will be ignored. Note that when fully automated, new parents will always be processed first.);

    $doc{'process'}{'New Host'} =
qq(Select new hosts for processing. You can accept the records as is or after selecting, enable overrides to merge or replace new information. You may also use edit to process each record individually.);

    $doc{'process'}{'Host Exists'} =
qq(Select existing hosts for processing. Processing an existing host will replace the current configuration for that host with the new one specified in the record. For automation purposes, you can define a match task to discard existing hosts from processing.);

    $doc{'process'}{'Exception'} =
qq(Select records flagged as exception. Records missing vital pieces of information (name, address, or alias) cannot be processed. Use the Smart Names Option (Edit Schema) to satisfy incomplete data. You may also use edit to process each record individually.);

    $doc{'process'}{'Delete Host'} =
qq(Select host flagged for deletion. You will only see hosts in this category with the schema type host-profile-sync. Hosts that are assigned to the operative host profile but are not in the data source are flagged for deletion.);

    return %doc;
}

1;
