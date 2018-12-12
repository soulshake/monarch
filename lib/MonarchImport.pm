# MonArch - Groundwork Monitor Architect
# MonarchImport.pm
#
############################################################################
# Release 4.1
# June 2012
############################################################################
#
# Original author: Scott Parris
#
# Copyright 2007-2012 GroundWork Open Source, Inc. (GroundWork)
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

package Import;

# The import_host() and import_service() routines here currently do not support supplying notes
# associated with these objects.  That might be the subject of a future extension, when we see
# some customer demand for it.  The trick will be to deal cleanly with backward compatibility.

sub import_host() {
    my $name             = $_[1];
    my $alias            = $_[2];
    my $address          = $_[3];
    my $profile_id       = $_[4];
    my $update           = $_[5];
    my @messages         = ();
    my $error            = 0;
    my $host_id          = undef;
    my $auth             = StorProc->dbconnect();
    my %profile          = StorProc->fetch_one( 'profiles_host', 'hostprofile_id', $profile_id );
    my %where            = ( 'hostprofile_id' => $profile_id );
    my @service_profiles = StorProc->fetch_list_where( 'profile_host_profile_service', 'serviceprofile_id', \%where );
    my %host             = StorProc->fetch_one( 'hosts', 'name', $name );

    # Note that service profiles are assigned but not applied.  Maybe you don't want
    # to be calling this import_host(), after all.  Try MonarchAPI.pm instead.
    if ( $host{'name'} ) {
	$host_id = $host{'host_id'};
	if ($update) {
	    ## FIX LATER:  Currently, escalations are not overridden here.  Not sure if this makes sense.
	    my %values = (
		'alias'           => $alias,
		'address'         => $address,
		'hosttemplate_id' => $profile{'host_template_id'},
		'hostextinfo_id'  => $profile{'host_extinfo_id'},
		'hostprofile_id'  => $profile_id,
	    );
	    my $result = StorProc->update_obj( 'hosts', 'name', $name, \%values );
	    if ( $result =~ /Error/ ) {
		push @messages, $result;
		$error = 1;
	    }
	    else {
		my @hosts = ( $host_id );
		$result = StorProc->host_profile_apply( $profile_id, \@hosts );
		if ( $result =~ /Error/ ) { push @messages, $result; $error = 1 }
		my %where = ( 'host_id' => $host_id );
		$result = StorProc->delete_one_where( 'serviceprofile_host', \%where );
		if ( $result =~ /Error/ ) { push @messages, $result; $error = 1 }
		foreach my $spid (@service_profiles) {
		    my @vals = ( $spid, $host_id );
		    $result = StorProc->insert_obj( 'serviceprofile_host', \@vals );
		    if ( $result =~ /Error/ ) { push @messages, $result; $error = 1 }
		}
	    }
	    unless ($error) { push @messages, ("Host $name already exists, updated. UPDATE = YES") }
	}
	else {
	    push @messages, ("Host $name already exists, skipped. UPDATE = NO");
	}
    }
    else {
	my @values = (
	    \undef, $name, $alias, $address, 'n/a',
	    $profile{'host_template_id'},
	    $profile{'host_extinfo_id'},
	    $profile_id,
	    $profile{'host_escalation_id'},
	    $profile{'service_escalation_id'},
	    '1', '', ''
	);
	$host_id = StorProc->insert_obj_id( 'hosts', \@values, 'host_id' );
	if ( $host_id =~ /Error/ ) {
	    push @messages, $host_id;
	    $error = 1;
	}
	else {
	    my @hosts = ($host_id);
	    my $result = StorProc->host_profile_apply( $profile_id, \@hosts );
	    if ( $result =~ /Error/ ) { push @messages, $result; $error = 1 }
	    foreach my $spid (@service_profiles) {
		my @vals = ( $spid, $host_id );
		$result = StorProc->insert_obj( 'serviceprofile_host', \@vals );
		if ( $result =~ /Error/ ) { push @messages, $result; $error = 1 }
	    }
	}
	unless ($error) { push @messages, ("Host $name added.") }
    }
    my $result = StorProc->dbdisconnect();
    return $host_id, \@messages;
}

sub import_service() {
    my $host_id           = $_[1];
    my $servicename_id    = $_[2];
    my $serviceprofile_id = $_[3];
    my $command_id        = $_[4];
    my $command_line      = $_[5];
    my $update            = $_[6];
    my $name              = $_[7];
    my $error             = 0;
    my @messages          = ();
    my $auth              = StorProc->dbconnect();
    my %profile           = StorProc->fetch_one( 'profiles_service', 'serviceprofile_id', $serviceprofile_id );
    my %service_name      = ();
    if ($name) {
	%service_name = StorProc->fetch_one( 'service_names', 'name', $name );
	if ( $service_name{'servicename_id'} ) {
	    $servicename_id = $service_name{'servicename_id'};
	}
	else {
	    $servicename_id = StorProc->copy_servicename( $servicename_id, $name );
	    %service_name = StorProc->fetch_one( 'service_names', 'servicename_id', $servicename_id );
	}
    }
    else {
	%service_name = StorProc->fetch_one( 'service_names', 'servicename_id', $servicename_id );
    }
    my %where = ( 'host_id' => $host_id, 'servicename_id' => $service_name{'servicename_id'} );
    my %service = StorProc->fetch_one_where( 'services', \%where );
    if ( $service{'service_id'} ) {
	if ($update) {
	    my %values = (
		'servicetemplate_id' => $service_name{'template'},
		'serviceextinfo_id'  => $service_name{'extinfo'},
		'escalation_id'      => $service_name{'escalation'},
		'command_line'       => $command_line
	    );
	    my $result = StorProc->update_obj( 'services', 'service_id', $service{'service_id'}, \%values );
	    if ( $result =~ /Error/ ) { push @messages, $result; $error = 1 }

	    my %overrides = StorProc->fetch_one( 'servicename_overrides', 'servicename_id', $service{'servicename_id'} );
	    my %where = ( 'service_id' => $service{'service_id'} );
	    $result = StorProc->delete_one_where( 'service_overrides', \%where );
	    if ( $result =~ /Error/ ) { push @messages, $result; $error = 1 }
	    my $data = "<?xml version=\"1.0\" encoding=\"iso-8859-1\" ?>\n<data>";
	    foreach my $name ( keys %overrides ) {
		unless ( $name =~ /^check_period$|^notification_period$|^event_handler$/ ) {
		    $data .= " <prop name=\"$name\"><![CDATA[$overrides{$name}]]>\n";
		    $data .= " </prop>\n";
		}
	    }
	    $data .= "\n</data>\n";
	    my @values =
	      ( $service{'service_id'}, $overrides{'check_period'}, $overrides{'notification_period'}, $overrides{'event_handler'}, $data );
	    $result = StorProc->insert_obj( 'service_overrides', \@values );
	    if ( $result =~ /Error/ ) { push @messages, $result }
	    unless ($error) { push @messages, ("Service $service_name{'name'} already exists, updated. UPDATE = YES") }
	}
	else {
	    push @messages, ("Service $service_name{'name'} already exists, skipped. UPDATE = NO");
	}
    }
    else {
	my @values = (
	    \undef, $host_id, $servicename_id,
	    $service_name{'template'},
	    $service_name{'extinfo'},
	    $service_name{'escalation'},
	    '1', $command_id, $command_line, '', ''
	);
	my $service_id = StorProc->insert_obj_id( 'services', \@values, 'service_id' );
	if ( $service_id =~ /Error/ ) { push @messages, $service_id; $error = 1 }
	my %overrides = StorProc->fetch_one( 'servicename_overrides', 'servicename_id', $service{'servicename_id'} );
	my $data = "<?xml version=\"1.0\" encoding=\"iso-8859-1\" ?>\n<data>";
	foreach my $name ( keys %overrides ) {
	    unless ( $name =~ /^check_period$|^notification_period$|^event_handler$/ ) {
		$data .= " <prop name=\"$name\"><![CDATA[$overrides{$name}]]>\n";
		$data .= " </prop>\n";
	    }
	}
	$data .= "\n</data>\n";
	@values = ( $service_id, $overrides{'check_period'}, $overrides{'notification_period'}, $overrides{'event_handler'}, $data );
	my $result = StorProc->insert_obj( 'service_overrides', \@values );
	if ( $result =~ /Error/ ) {
	    push @messages, $result;
	}
	else {
	    push @messages, "Service $service_name{'name'} added.";
	}
    }
    my $result = StorProc->dbdisconnect();
    return @messages;
}

1;

