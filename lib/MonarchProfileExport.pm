# MonArch - Groundwork Monitor Architect
# MonarchProfileExport.pm
#
############################################################################
# Release 4.5
# August 2016
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

use lib qq(/usr/local/groundwork/core/monarch/lib);
use strict;
use MonarchStorProc;

package ProfileExporter;

my %timeperiods          = ();
my %commands             = ();
my %service_names        = ();
my %service_templates    = ();
my %service_dependencies = ();
my %service_profiles     = ();
my %host_templates       = ();
my %host_extinfo         = ();
my %service_extinfo      = ();
my %host_externals       = ();
my %service_externals    = ();
my %files                = ();
my @errors               = ();
my $debug                = 0;

#
# Host detail
#

sub host_xml($) {
    my $host   = shift;
    my %host   = %{$host};
    my $got_it = 0;
    if ( $host{'type'} eq 'host_template' ) {
	if ( $host_templates{ $host{'hosttemplate_id'} } ) {
	    $got_it = 1;
	}
	else {
	    $host_templates{ $host{'hosttemplate_id'} } = 1;
	}
    }
    unless ($got_it) {
	delete $host{'hosttemplate_id'};
	delete $host{'hostprofile_id'};
	my $xml = qq(
 <$host{'type'}>);
	my $support_xml = '';
	foreach my $name ( keys %host ) {
	    if ( $name eq 'type' ) { next }
	    if ( $name =~ /select$|^apply/ ) { next }
	    unless ( $host{$name} ) { next }
	    if ( $name =~ /check_period|notification_period/ ) {
		$support_xml .= timeperiod_xml( $host{$name} );
		my %n = StorProc->fetch_one( 'time_periods', 'timeperiod_id', $host{$name} );
		$xml .= qq(
  <prop name="$name"><![CDATA[$n{'name'}]]></prop>);
	    }
	    elsif ( $name =~ /check_command|^event_handler$/ ) {
		$support_xml .= command_xml( $host{$name} );
		my %c = StorProc->fetch_one( 'commands', 'command_id', $host{$name} );
		$xml .= qq(
  <prop name="$name"><![CDATA[$c{'name'}]]></prop>);
	    }
	    elsif ( $name eq 'service_profiles' ) {
		foreach my $sp ( @{ $host{'service_profiles'} } ) {
		    $xml .= qq(
  <prop name="service_profile"><![CDATA[$sp]]></prop>);
		}
	    }
	    # FIX MINOR:  make sure the "host_external" fields are picked up during profile import
	    elsif ( $name eq 'host_externals' ) {
		foreach my $ext ( @{ $host{'host_externals'} } ) {
		    $xml .= qq(
  <prop name="host_external"><![CDATA[$ext]]></prop>);
		}
	    }
	    else {
		$xml .= qq(
  <prop name="$name"><![CDATA[$host{$name}]]></prop>);
	    }
	}
	$xml .= qq(
 </$host{'type'}>);
	return "$support_xml$xml";
    }
}

#
# Service detail
#

sub service_xml($) {
    my $service = shift;
    my %service = %{$service};
    my $got_it  = 0;
    if ( $service{'type'} eq 'service' ) {
	if ( $service_templates{ $service{'servicename_id'} } ) {
	    $got_it = 1;
	}
	else {
	    $service_templates{ $service{'servicename_id'} } = 1;
	}
    }
    elsif ( $service{'type'} eq 'service_template' ) {
	if ( $service_templates{ $service{'servicetemplate_id'} } ) {
	    $got_it = 1;
	}
	else {
	    $service_templates{ $service{'servicetemplate_id'} } = 1;
	}
    }
    unless ($got_it) {
	delete $service{'servicetemplate_id'};
	delete $service{'servicename_id'};
	my $xml = qq(
 <$service{'type'}>);
	foreach my $name ( keys %service ) {
	    if ( $name eq 'type' ) { next }
	    unless ( $service{$name} ) { next }
	    if ( $service{$name} eq '-zero-' ) { $service{$name} = '0' }
	    if ( $name =~ /parent_id|template/ ) {
		my %template = StorProc->fetch_one( 'service_templates', 'servicetemplate_id', $service{$name} );
		$xml .= qq(
  <prop name="template"><![CDATA[$template{'name'}]]></prop>);
	    }
	    elsif ( $name =~ /period/ ) {
		my %t = StorProc->fetch_one( 'time_periods', 'timeperiod_id', $service{$name} );
		$xml .= qq(
  <prop name="$name"><![CDATA[$t{'name'}]]></prop>);
	    }
	    elsif ( $name =~ /check_command|event_handler$/ ) {
		my %c = StorProc->fetch_one( 'commands', 'command_id', $service{$name} );
		$xml .= qq(
  <prop name="$name"><![CDATA[$c{'name'}]]></prop>);
	    }
	    elsif ( $name eq 'command_line' ) {
		$xml .= qq(
  <prop name="command_line"><![CDATA[$service{'command_line'}]]></prop>);
	    }
	    elsif ( $name eq 'dependency' ) {
		my %d = StorProc->fetch_one( 'service_dependency_templates', 'id', $service{'dependency'} );
		$xml .= qq(
  <prop name="dependency"><![CDATA[$d{'name'}]]></prop>);
	    }
	    elsif ( $name eq 'dependencies' ) {
		foreach my $dep ( @{ $service{'dependencies'} } ) {
		    $xml .= qq(
  <prop name="dependency"><![CDATA[$dep]]></prop>);
		}
	    }
	    elsif ( $name eq 'service_externals' ) {
		foreach my $ext ( keys %{ $service{'service_externals'} } ) {
		    $xml .= qq(
  <prop name="service_external"><![CDATA[$ext]]></prop>);
		}
	    }
	    elsif ( $name eq 'extinfo' ) {
		$xml .= qq(
  <prop name="extinfo"><![CDATA[$service{'extinfo'}]]></prop>);
	    }
	    else {
		$xml .= qq(
  <prop name="$name"><![CDATA[$service{$name}]]></prop>);
	    }
	}
	$xml .= qq(
 </$service{'type'}>);
	return $xml;
    }
    else {
	return;
    }
}

#
# dependency
#

sub dependency_xml($) {
    my $dep_id = shift;
    if ( $dep_id && !$service_dependencies{$dep_id} ) {
	my %dependency = StorProc->fetch_one( 'service_dependency_templates', 'id', $dep_id );
	my %n = StorProc->fetch_one( 'service_names', 'servicename_id', $dependency{'servicename_id'} );
	delete $dependency{'id'};
	delete $dependency{'servicename_id'};
	$dependency{'service'} = $n{'name'};
	my $xml = qq(
 <service_dependency_template>);
	foreach my $name ( keys %dependency ) {
	    $xml .= qq(
  <prop name="$name"><![CDATA[$dependency{$name}]]></prop>);
	}
	$xml .= qq(
 </service_dependency_template>);
	$service_dependencies{$dep_id} = 1;
	return $xml;
    }
}

#
# Extended Service Info Templates
#

sub service_extinfo_xml($) {
    my $extinfo = shift;
    if ( $extinfo && !$service_extinfo{$extinfo} ) {
	my %extinfo = StorProc->fetch_one( 'extended_service_info_templates', 'name', $extinfo );
	delete $extinfo{'serviceextinfo_id'};

	my $xml = qq(
 <extended_service_info_template>);
	foreach my $name ( keys %extinfo ) {
	    $xml .= qq(
  <prop name="$name"><![CDATA[$extinfo{$name}]]></prop>);
	}
	$xml .= qq(
 </extended_service_info_template>);
	$service_extinfo{$extinfo} = 1;
	return $xml;
    }
}

#
# Extended Host Info Templates
#

sub host_extinfo_xml($) {
    my $extinfo = shift;
    if ( $extinfo && !$host_extinfo{$extinfo} ) {
	my %extinfo = StorProc->fetch_one( 'extended_host_info_templates', 'name', $extinfo );
	delete $extinfo{'hostextinfo_id'};

	my $xml = qq(
 <extended_host_info_template>);
	foreach my $name ( keys %extinfo ) {
	    $xml .= qq(
  <prop name="$name"><![CDATA[$extinfo{$name}]]></prop>);
	}
	$xml .= qq(
 </extended_host_info_template>);
	$host_extinfo{$extinfo} = 1;
	return $xml;
    }

}

#
# Commands
#

sub command_xml($) {
    my $command_id = shift;
    if ( $command_id && !$commands{$command_id} ) {
	my %command = StorProc->fetch_one( 'commands', 'command_id', $command_id );
	my $xml = qq(
 <command>
  <prop name="name"><![CDATA[$command{'name'}]]></prop>
  <prop name="type"><![CDATA[$command{'type'}]]></prop>
  <prop name="command_line"><![CDATA[$command{'command_line'}]]></prop>
 </command>);
	$commands{$command_id} = 1;
	return $xml;
    }
}

#
# Timeperiods
#

sub timeperiod_xml($) {
    my $timeperiod_id = shift;
    if ( $timeperiod_id && !$timeperiods{$timeperiod_id} ) {
	my @xml = ();

	push @xml, qq(
 <time_period>);

	my %timeperiod = StorProc->fetch_one( 'time_periods', 'timeperiod_id', $timeperiod_id );
	delete $timeperiod{'timeperiod_id'};
	foreach my $name ( keys %timeperiod ) {
	    push @xml, qq(
  <prop name="$name"><![CDATA[$timeperiod{$name}]]></prop>);
	}

	my %where = ( 'timeperiod_id' => $timeperiod_id );
	my %time_period_property = StorProc->fetch_hash_array_generic_key( 'time_period_property', \%where );
	foreach my $key ( keys %time_period_property ) {
	    my $name    = $time_period_property{$key}[1];
	    my $value   = $time_period_property{$key}[3];
	    my $comment = $time_period_property{$key}[4];
	    $comment =~ s/\s*\n+/, /g;
	    $comment =~ s/, $//g;
	    $value .= ';' . $comment if $comment;
	    push @xml, qq(
  <prop name="$name"><![CDATA[$value]]></prop>);
	}

	my %timeperiod_name = StorProc->get_table_objects( 'time_periods', 1 );
	my @exclusions = StorProc->fetch_unique( 'time_period_exclude', 'exclude_id', 'timeperiod_id', $timeperiod_id );
	my @excluded_tp_names = ();
	foreach my $exclude_id (@exclusions) {
	    my $excluded_tp_name = $timeperiod_name{$exclude_id};
	    push @excluded_tp_names, $excluded_tp_name if $excluded_tp_name;
	}
	my $excluded_tps = join( ',', @excluded_tp_names );
	if ($excluded_tps) {
	    push @xml, qq(
  <prop name="exclude"><![CDATA[$excluded_tps]]></prop>);
	}

	push @xml, qq(
 </time_period>);

	$timeperiods{$timeperiod_id} = 1;
	return join( '', @xml );
    }
}

sub service_name(@) {
    my $service_id        = $_[1];
    my $serviceprofile_id = $_[2];
    local $_;

    my %service = StorProc->fetch_one( 'service_names', 'servicename_id', $service_id );
    delete $service{'apply_dependencies'};
    delete $service{'apply_escalation_service'};
    delete $service{'apply_contact_service'};
    delete $service{'apply_extinfo_service'};
    delete $service{'apply_check'};
    delete $service{'services'};
    delete $service{'escalation'};

    my %template     = StorProc->fetch_one( 'service_templates', 'servicetemplate_id', $service{'template'} );
    my $xml          = command_xml( $service{'check_command'} );
    my $got_parents  = 0;
    my %already_seen = ();
    until ($got_parents) {
	$template{'type'} = 'service_template';
	$xml .= command_xml( $template{'check_command'} );
	$xml .= command_xml( $template{'event_handler'} );
	$xml .= timeperiod_xml( $template{'notification_period'} );
	$xml .= timeperiod_xml( $template{'check_period'} );
	$xml .= service_xml( \%template );
	$already_seen{ $template{'servicetemplate_id'} } = 1;
	$got_parents = 1;

	if ( $template{'parent_id'} && !$already_seen{ $template{'parent_id'} } ) {
	    %template = StorProc->fetch_one( 'service_templates', 'servicetemplate_id', $template{'parent_id'} );
	    $got_parents = 0 if $template{'servicetemplate_id'};
	}
    }

    my %et = StorProc->fetch_one( 'extended_service_info_templates', 'serviceextinfo_id', $service{'extinfo'} );
    $service{'extinfo'} = $et{'name'};
    $xml .= service_extinfo_xml( $service{'extinfo'} );
    my %dependencies = ();
    my %overrides = StorProc->fetch_one( 'servicename_overrides', 'servicename_id', $service_id );
    $xml .= command_xml( $overrides{'check_command'} );
    $xml .= command_xml( $overrides{'event_handler'} );
    $xml .= timeperiod_xml( $overrides{'notification_period'} );
    $xml .= timeperiod_xml( $overrides{'check_period'} );
    foreach my $name ( keys %overrides ) {
	$service{$name} = $overrides{$name};
    }
    my %where = ( 'servicename_id' => $service_id );
    %dependencies = StorProc->get_service_dependencies($service_id);
    my @deps = ();
    foreach my $dep ( keys %dependencies ) {
	push @deps, $dep;
    }
    $service{'dependencies'} = [@deps];
    delete $service{'dependency'};
    foreach my $dep ( keys %dependencies ) {
	$xml .= dependency_xml( $dependencies{$dep} );
    }

    my %externals = StorProc->get_externals();
    %where = ( 'servicename_id' => $service_id );
    my @s_externals = StorProc->fetch_list_where( 'external_service_names', 'external_id', \%where );
    if ( $s_externals[0] ) {
	my $external_xml .= '\n <service_externals>';
	foreach my $eid (@s_externals) {
	    $service{'service_externals'}{ $externals{$eid}{'name'} } = 1;
	    unless ( $service_externals{ $externals{$eid}{'name'} } ) {
		$service_externals{ $externals{$eid}{'name'} } = 1;
		$xml .= qq(
 <service_external>
  <prop name="name"><![CDATA[$externals{$eid}{'name'}]]></prop>
  <prop name="type"><![CDATA[$externals{$eid}{'type'}]]></prop>
  <prop name="data"><![CDATA[$externals{$eid}{'data'}]]></prop>
 </service_external>);
	    }
	}
    }
    $service{'type'} = 'service_name';
    $xml .= service_xml( \%service );
    if ($serviceprofile_id) {
	return $xml;
    }
    else {
	$xml = "<?xml version=\"1.0\" encoding=\"iso-8859-1\" ?>\n<profile>$xml\n</profile>";
	if ( !open( FILE, '>', "/tmp/service_name_$service{'name'}.xml" ) ) {
	    push @errors, "Error: Unable to write /tmp/service_name_$service{'name'}.xml ($!)";
	}
	else {
	    print FILE $xml;
	    close(FILE);
	}
	my $result = 1;
	if (@errors) {
	    $result = "Error: ";
	    foreach (@errors) { $result .= "$_<br>" }
	}
	return $result;
    }
}

sub service_profile(@) {
    my $profile_id     = $_[1];
    my $hostprofile_id = $_[2];
    local $_;

    my %profile = StorProc->fetch_one( 'profiles_service', 'serviceprofile_id', $profile_id );
    my $xml     = qq(
 <service_profile>
  <prop name="name"><![CDATA[$profile{'name'}]]></prop>
  <prop name="description"><![CDATA[$profile{'description'}]]></prop>);
    my %services    = StorProc->get_service_profiles($profile_id);
    my $xml_service = '';
    foreach my $name ( sort keys %services ) {
	$xml_service .= service_name( '', $services{$name}, $profile_id );
	$xml .= qq(
  <prop name="service"><![CDATA[$name]]></prop>);
    }
    $xml .= qq(
 </service_profile>$xml_service);
    if ($hostprofile_id) {
	return $xml;
    }
    else {
	$xml = "<?xml version=\"1.0\" encoding=\"iso-8859-1\" ?>\n<profile>$xml\n</profile>";
	if ( !open( FILE, '>', "/tmp/service-profile-$profile{'name'}.xml" ) ) {
	    push @errors, "Error: Unable to write /tmp/service-profile-$profile{'name'}.xml ($!)";
	}
	else {
	    # FIX MINOR:  check for i/o errors here and throughout the module
	    print FILE $xml;
	    close(FILE);
	}
	my $result = 1;
	if (@errors) {
	    $result = "Error: ";
	    foreach (@errors) { $result .= "$_<br>" }
	}
	return $result;
    }
}

sub host_profile(@) {
    my $profile_id = $_[1];
    local $_;

    my %profile = StorProc->fetch_one( 'profiles_host', 'hostprofile_id', $profile_id );
    delete $profile{'data'};
    $profile{'type'} = 'host_profile';
    delete $profile{'hostgroups'};
    delete $profile{'host_escalation_id'};	# FIX MINOR:  why is this being ignored?
    delete $profile{'service_escalation_id'};	# FIX MINOR:  why is this being ignored?
    delete $profile{'hostextinfo_id'};		# FIX MINOR:  where might this be from?
    delete $profile{'services'};
    delete $profile{'apply_extinfo'};		# FIX MINOR:  what does this correspond to?
    delete $profile{'apply_services'};
    delete $profile{'apply_host_externals'};
    delete $profile{'apply_detail'};
    delete $profile{'apply_variables'};
    delete $profile{'apply_contactgroups'};
    delete $profile{'apply_escalations'};
    delete $profile{'apply_hostgroups'};
    delete $profile{'apply_parents'};
    delete $profile{'hosts_select'};
    delete $profile{'hostgroups_select'};

    # FIX MINOR:  make sure the "extended_info" field gets picked up during host profile importing
    my %et = StorProc->fetch_one( 'extended_host_info_templates', 'hostextinfo_id', $profile{'host_extinfo_id'} );
    delete $profile{'host_extinfo_id'};
    $profile{'extended_info'} = $et{'name'};
    my $xml = host_extinfo_xml( $profile{'extended_info'} );

    my %template = StorProc->fetch_one( 'host_templates', 'hosttemplate_id', $profile{'host_template_id'} );
    delete $profile{'host_template_id'};
    $template{'type'}         = 'host_template';
    $profile{'host_template'} = $template{'name'};
    $xml .= host_xml( \%template );

    my @s_profiles       = ();
    my %service_profiles = StorProc->get_host_profile_service_profiles($profile_id);
    foreach my $name ( sort keys %service_profiles ) {
	$xml .= service_profile( '', $service_profiles{$name}, $profile_id );
	push @s_profiles, $name;
    }
    $profile{'service_profiles'} = [@s_profiles];

    # FIX MINOR:  extend StorProc->get_externals() so it returns the description too, and include that here as well
    my @h_externals  = ();
    my %externals    = StorProc->get_externals();
    my %where        = ( 'hostprofile_id' => $profile{'hostprofile_id'} );
    my @external_ids = StorProc->fetch_list_where( 'external_host_profile', 'external_id', \%where );
    foreach my $eid (@external_ids) {
	$xml .= qq(
 <host_external>
  <prop name="name"><![CDATA[$externals{$eid}{'name'}]]></prop>
  <prop name="type"><![CDATA[$externals{$eid}{'type'}]]></prop>
  <prop name="data"><![CDATA[$externals{$eid}{'data'}]]></prop>
 </host_external>);
	push @h_externals, $externals{$eid}{'name'};
    }
    $profile{'host_externals'} = [@h_externals];

    my %overrides = StorProc->fetch_one( 'hostprofile_overrides', 'hostprofile_id', $profile_id );
    foreach my $name ( keys %overrides ) {
	$profile{$name} = $overrides{$name};
    }
    $xml .= host_xml( \%profile );

    $xml = "<?xml version=\"1.0\" encoding=\"iso-8859-1\" ?>\n<profile>$xml\n</profile>";

    if ( !open( FILE, '>', "/tmp/$profile{'name'}.xml" ) ) {
	push @errors, "Error: Unable to write /tmp/$profile{'name'}.xml ($!)";
    }
    else {
	print FILE $xml;
	close(FILE);
    }
    my $result = 1;
    if (@errors) {
	$result = "Error: ";
	foreach (@errors) { $result .= "$_<br>" }
    }
    return $result;
}

if ($debug) {
    my $result = StorProc->dbconnect();
    host_profile( '', '1' );
    $result = StorProc->dbdisconnect();
}

1;

