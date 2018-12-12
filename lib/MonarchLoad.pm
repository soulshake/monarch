# MonArch - Groundwork Monitor Architect
# MonarchLoad.pm
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

use strict;
use MonarchStorProc;

package Load;

my $debug     = 0;
my $gw4       = 0;
my @messages  = ();
my $xml_begin = "<?xml version=\"1.0\" encoding=\"iso-8859-1\" ?>\n<data>\n";
my $xml_end   = "</data>";

sub update_status(@) {
    my $type        = $_[0];
    my $message     = $_[1];
    my $dt          = StorProc->datetime();
    my $message_str = "$dt~~$type~~$message";
    if ($debug) { print "\n$message_str\n" }
    push @messages, $message_str;
}

#
############################################################################
# stage load
#

# FIX THIS:  should we also pass in the purge_escalation flag, here or elsewhere?

sub stage_load(@) {
    my $nagios_home    = $_[1];
    my $action_type    = $_[2];    # only used for Nagios 3.x import: update|purge_all|purge_all_and_import_3x|purge_nice
    my $precached_file = $_[3];
    my $index          = 0;
    my $use_regex      = 0;
    my $result;

    update_status( 'start', "Import process begins" );

    my %objects = ();
    update_status( 'info', "Reading: $nagios_home/nagios.cfg" );

    my @files          = ();
    my @dirs           = ();
    my @resource_files = ();
    if ( !open( FILE, '<', "$nagios_home/nagios.cfg" ) ) {
	update_status( 'error', "error: cannot open $nagios_home/nagios.cfg to read ($!)" );
    }
    else {
	while ( my $line = <FILE> ) {
	    if ( $line =~ /^\s*cfg_file\s*=\s*(.*\.cfg)\s*$/ ) { push @files, $1 }
	    if ( $line =~ /^\s*cfg_dir\s*=\s*(\S+)\s*$/ )      { push @dirs,  $1 }
	    if ( $line =~ /^\s*resource_file\s*=\s*(\S+)\s*$/ ) {
		push @resource_files, $1;
	    }
	    if ( $line =~ /^\s*use_regexp_matching\s*=\s*1\s*$/ ) { $use_regex = 1 }
	}
	close(FILE);
    }
    foreach my $dir (@dirs) {
	if ( !opendir( DIR, $dir ) ) {
	    update_status( 'error', "error: cannot open $dir to read ($!)" );
	}
	else {
	    while ( my $file = readdir(DIR) ) {
		if ( $file =~ /^(\S+\.cfg)$/ ) {
		    my $cfg = $1;
		    push @files, "$dir/$cfg";
		}
	    }
	    closedir(DIR);
	}
    }

    update_status( 'info', "Reading: $nagios_home/cgi.cfg" );
    if ( !open( FILE, '<', "$nagios_home/cgi.cfg" ) ) {
	update_status( 'error', "error: cannot open $nagios_home/cgi.cfg to read ($!)" );
    }
    else {
	while ( my $line = <FILE> ) {
	    if ( $line =~ /^\s*cfg_file\s*=\s*(.+\.cfg)$/ ) {
		push @files, $1;
	    }
	}
	close(FILE);
    }

    if ($use_regex) {
	my @vals = ( 'use_regex', 'config', '1', '', '' );
	$result = StorProc->insert_obj( 'stage_other', \@vals );
	if ( $result =~ /error/i ) {
	    update_status( 'error', $result );
	}
    }

    my $doing_nagios_3_import = 0;
    if ( $action_type eq 'purge_all_and_import_3x' ) {
	$doing_nagios_3_import = 1;
	if ( !$precached_file ) {
	    my %precached_file = StorProc->fetch_one( 'setup', 'name', 'precached_object_file' );
	    $precached_file = $precached_file{'value'};
	}
	unshift( @files, $precached_file );
    }

    foreach my $file (@files) {
	my $host_file    = 0;
	my $service_file = 0;
	my $added        = 0;
	my $rejected     = 0;

	next if ( $file =~ /nagios.cfg|resource.cfg|perfparse.cfg|cgi.cfg/i );
	my @properties = ();
	if ( !open( CFG, '<', $file ) ) {
	    update_status( 'error', "error: cannot open $file to read ($!)" );
	}
	else {
	    while ( my $line = <CFG> ) {
		next if ( $line =~ /#\s*GROUNDWORK#|^#\s*GW|^\s*;/ );
		$line =~ s/\t+/ /g;
		$line =~ s/^\s+|\s+$//g;

		# If at end of a definition -- all lines up to this one in the definition are in @properties.
		# For easy editing, we balance { the extra brace just below.
		if ( $line !~ /^}/ ) {
		    push @properties, $line;
		}
		else {
		    ## each time through, do one definition
		    my @comment = ();
		    my %element = ();
		    $element{'data'} = $xml_begin;
		    foreach my $prop (@properties) {
			## each line is part of a single definition, the current one
			if ( $prop =~ /^define\s+(\S+)\s*\{/i ) {
			    $element{'type'} = $1;
			}
			## For easy editing, we balance } the extra brace just above.

			elsif ( $prop =~ /register\s+0/i ) {
			    $element{'type'} .= '_template';
			}
			elsif ( $prop =~ /register\s+1/i ) {
			    next;
			}
			elsif ( $prop =~ /^\#/ ) {
			    push @comment, "$prop\n";
			}
			elsif ( $prop =~ /\s*(.*?)\s+(\d\d:\d\d-\d\d:\d\d.*)/ ) {
			    my ( $name, $value ) = ( $1, $2 );
			    $name  =~ s/\s+/ /g;
			    $value =~ s/\s+$//;
			    $value =~ s/\s*([;#])\s*/$1/;
			    $value =~ s/^([^;#]+)\s+([^;#]*)([;#])/$1$2$3/g;
			    $element{$name} = $value;
			}
			elsif ( $prop =~ /\s*exclude\s+(.*)/ ) {
			    $element{'exclude'} = $1;
			}
			elsif ( $prop =~ /(\S+)\s+(\S+.*?)(?<!\\);/ ) {
			    my ( $name, $value ) = ( $1, $2 );
			    $value =~ s/\s+$|\s+\;//;
			    if ( $name eq 'members' ) {
				$element{$name} .= "$value,";
			    }
			    else {
				if ( $value eq '0' ) { $value = "-zero-" }
				$element{$name} = $value;
			    }
			}
			elsif ( $prop =~ /(\S+)\s+(\S+.*?)(?:\t.*?)?$/ ) {
			    my ( $name, $value ) = ( $1, $2 );
			    $value =~ s/\s+$|\s+\;//;
			    if ( $name eq 'members' ) {
				$element{$name} .= "$value,";
			    }
			    else {
				if ( $value eq '0' ) { $value = "-zero-" }
				$element{$name} = $value;
			    }
			}
			elsif ($prop) {
			    ## If this becomes annoying, drop it, but it might reveal something interesting.
			    print STDERR "property '$prop' for definition of a '$element{'type'}' is being ignored during Load";
			}
		    }
		    if ( $element{'type'} eq 'host' ) {
			$element{'name'}   .= $element{'host_name'};
			$element{'parent'} .= $element{'host_name'};
			delete $element{'host_name'};
		    }
		    elsif ( $element{'type'} eq 'service' ) {
			if ( defined( $element{'service_description'} ) ) {
			    $element{'name'} = $element{'service_description'};
			    delete $element{'service_description'};
			}
			else {
			    $element{'name'} = $element{'use'};
			}
			if ( $element{'hostgroup_name'} ) {
			    my @h = split( /,/, $element{'hostgroup_name'} );
			    $element{'parent'} = $h[0];
			}
			elsif ( $element{'host_name'} ) {
			    my @h = split( /,/, $element{'host_name'} );
			    $element{'parent'} = $h[0];
			}
			else {
			    $element{'parent'} = $index;
			    $index++;
			}
		    }
		    elsif ( $element{'type'} eq 'hostgroupescalation' ) {
			$element{'name'} = "hostgroupescalation-$index";
			$index++;
		    }
		    elsif ( $element{'type'} eq 'hostescalation' ) {
			if ( $element{'hostgroup_name'} ) {
			    $element{'name'}   = "hostgroup-$index";
			    $element{'parent'} = "hostgroup";
			}
			elsif ( $element{'host_name'} ) {
			    $element{'name'}   = "host-$index";
			    $element{'parent'} = "host";
			}
			$index++;
		    }
		    elsif ( $element{'type'} eq 'serviceescalation' ) {
			if ( $element{'hostgroup_name'} ) {
			    $element{'name'}   = "hostgroup-$index";
			    $element{'parent'} = "hostgroup";
			}
			elsif ($element{'service_description'}
			    && $element{'service_description'} ne '*' )
			{
			    $element{'name'} = "$element{'service_description'}-$index";
			    $element{'type'} = 'serviceescalation';
			    if ( $element{'use'} ) {
				$element{'parent'} = $element{'use'};
			    }
			    else {
				$element{'parent'} = "no-template-$index";
			    }
			}
			elsif ( $element{'servicegroup_name'} ) {
			    $element{'name'}   = "servicegroup-$index";
			    $element{'parent'} = "servicegroup";
			}
			elsif ( $element{'host_name'} ) {
			    $element{'name'}   = "host-$index";
			    $element{'parent'} = "host";
			}
			$index++;
		    }
		    elsif ( $element{'type'} eq 'servicedependency' ) {
			$element{'name'} = "$element{'dependent_service_description'}-$index";
			if ( $element{'dependent_hostgroup_name'} ) {
			    my @h = split( /,/, $element{'dependent_hostgroup_name'} );
			    $element{'parent'} = "$h[0]-$element{'dependent_service_description'}-$index";
			}
			elsif ( $element{'dependent_host_name'} ) {
			    my @h = split( /,/, $element{'dependent_host_name'} );
			    $element{'parent'} = "$h[0]-$element{'dependent_service_description'}-$index";
			}
			$index++;
		    }
		    elsif ( $element{'type'} eq 'hostdependency' ) {
			my @h = split( /,/, $element{'dependent_host_name'} );
			$element{'name'} = "$h[0]-$index";
			@h = split( /,/, $element{'host_name'} );
			$element{'parent'} = $h[0];
			$index++;
		    }
		    elsif ( $element{'type'} eq 'hostextinfo' ) {
			my @h = split( /,/, $element{'host_name'} );
			if ( $h[1] ) {
			    $element{'name'}   = $h[0];
			    $element{'parent'} = $element{'type'};
			}
			else {
			    $element{'name'} = $element{'host_name'};
			    delete $element{'host_name'};
			}
		    }
		    elsif ( $element{'type'} eq 'serviceextinfo' ) {
			$element{'name'}   .= $element{'service_description'};
			$element{'parent'} .= $element{'host_name'};
			delete $element{'host_name'};
			delete $element{'service_description'};
		    }
		    elsif ( $element{'type'} eq 'timeperiod' ) {
			$element{'name'}   .= $element{'timeperiod_name'};
			$element{'parent'} .= $element{'alias'};
			delete $element{'alias'};
			delete $element{'timeperiod_name'};
		    }
		    elsif ( $element{'type'} eq 'command' ) {
			$element{'name'} .= $element{'command_name'};
			delete $element{'command_name'};
		    }
		    elsif ( $element{'type'} eq 'contact' ) {
			$element{'name'}   .= $element{'contact_name'};
			$element{'parent'} .= $element{'alias'};
			delete $element{'alias'};
			delete $element{'contact_name'};
		    }
		    elsif ( $element{'type'} eq 'contactgroup' ) {
			$element{'name'} .= $element{'contactgroup_name'};
			delete $element{'contactgroup_name'};
			$element{'parent'} .= $element{'alias'};
			delete $element{'alias'};
			$element{'members'} =~ s/,$//;
		    }
		    elsif ( $element{'type'} eq 'hostgroup' ) {
			$element{'type'} = 'hostgroup-host';
			$element{'name'} .= $element{'hostgroup_name'};
			delete $element{'hostgroup_name'};
			$element{'parent'} .= $element{'alias'};
			delete $element{'alias'};
			$element{'members'} =~ s/,$//;
		    }
		    elsif ( $element{'type'} eq 'servicegroup' ) {
			$element{'type'} = 'servicegroup';
			$element{'name'} .= $element{'servicegroup_name'};
			delete $element{'servicegroup_name'};
			$element{'parent'} .= $element{'alias'};
			delete $element{'alias'};
			$element{'members'} =~ s/,$//;
		    }
		    elsif ( $element{'type'} eq 'service_template' ) {
			if ( defined( $element{'use'} ) ) {
			    $element{'parent'} = $element{'use'};
			    delete $element{'use'};
			}
			else {
			    $element{'parent'} = 'no-parent';
			}
		    }
		    if ( $element{'type'} =~ /template/ && !$element{'name'} ) {
			next;
		    }
		    foreach my $ele ( keys %element ) {
			if ( !$element{$ele} || $ele =~ /HASH|^name$|^type$|^data$|^parent$/ ) {
			    next;
			}
			$element{'data'} .= " <prop name=\"$ele\"><![CDATA[$element{$ele}]]>\n";
			$element{'data'} .= " </prop>\n";
		    }
		    $element{'parent'} ||= $element{'name'};
		    $element{'data'} .= $xml_end;
		    (my $comment = pop @comment) =~ s/\s+$//;

		    unless ( $objects{"$element{'name'},$element{'type'},$element{'parent'}"} ) {
			$element{'name'} ||= 1;
			my @values = ( $element{'name'}, $element{'type'}, $element{'parent'}, $element{'data'}, $comment );
			$result = StorProc->insert_obj( 'stage_other', \@values );
			if ( $result =~ /error/i ) {
			    update_status( 'error', "Error: $file ($result)" );
			    $rejected++;
			}
			else {
			    ## FIX THIS:  what is this for?
			    ## push object only if
			    ## 1) we are not doing 3.x import OR
			    ## 2) we are doing a precached file OR
			    ## 3) we are doing a template object
			    if ( !$doing_nagios_3_import || $file eq $precached_file || $element{'type'} =~ /_template$/ ) {
				$objects{"$element{'name'},$element{'type'},$element{'parent'}"} = 1;
				## FIX THIS:  is this in the wrong place?
				$added++;
			    }
			}
		    }
		    @properties = ();
		}
	    }
	    close(CFG);
	    update_status( 'info',
		    "File $file: $added object"
		  . ( $added == 1 ? '' : 's' )
		  . " staged; $rejected object"
		  . ( $rejected == 1 ? '' : 's' )
		  . ' rejected.' );
	}
    }

    foreach my $resource_file (@resource_files) {
	update_status( 'info', "Reading: $resource_file" );
	if ( !open( FILE, '<', $resource_file ) ) {
	    update_status( 'error', "error: cannot open $resource_file to read ($!)" );
	}
	else {
	    while ( my $line = <FILE> ) {
		if ( $line =~ /\$USER(\d+)\$=(\S+)\s*$/ ) {
		    if ( $1 >= 1 && $1 <= 32 ) {
			my %w = ( 'name'  => "user$1" );
			my %u = ( 'value' => $2 );
			StorProc->update_obj_where( 'setup', \%u, \%w );
		    }
		}
	    }
	    close(FILE);
	}
    }
    update_status( 'end', 'Stage load completed.' );
    return @messages;
}

############################################################################
######
###### Break
######
############################################################################

# commands

sub process_commands() {
    my $read     = 0;
    my $updated  = 0;
    my $imported = 0;
    my $result;

    update_status( 'start', "Processing." );
    my %command_name = StorProc->get_table_objects('commands');
    update_status( 'info', 'Loading commands ...' );
    my %where = ( 'type' => 'command' );
    my %objects = StorProc->fetch_list_hash_array( 'stage_other', \%where );

    foreach my $key ( keys %objects ) {
	$read++;
	my %data = StorProc->parse_xml( $objects{$key}[3] );
	update_status( 'error', delete $data{'error'} ) if defined $data{'error'};
	my $cmdtype = 'check';
	if ( $data{'command_line'} =~ /\$CONTACTEMAIL\$|\$NOTIFICATIONTYPE\$|\$CONTACTPAGER\$/ ) {
	    $cmdtype = 'notify';
	}
	elsif ( $data{'command_line'} =~ /\$PERFDATA\$|perfdata|performance/i ) {
	    $cmdtype = 'other';
	}
	my $data = $xml_begin;
	$data .= " <prop name=\"command_line\"><![CDATA[$data{'command_line'}]]>\n";
	$data .= " </prop>\n";
	$data .= $xml_end;
	if ( $command_name{ $objects{$key}[0] } ) {
	    my %values = ();
	    $values{'type'}    = $cmdtype;
	    $values{'data'}    = $data;
	    $values{'comment'} = $objects{$key}[4];
	    StorProc->update_obj( 'commands', 'name', $objects{$key}[0], \%values );
	    $updated++;
	}
	else {
	    my @values = ( \undef, $objects{$key}[0], $cmdtype, $data, $objects{$key}[4] );
	    $result = StorProc->insert_obj_id( 'commands', \@values, 'command_id' );
	    if ( $result =~ /error/i ) {
		update_status( 'error', $result );
	    }
	    else {
		$command_name{ $objects{$key}[0] } = $result;
		$imported++;
	    }
	}
    }
    StorProc->delete_one_where( 'stage_other', \%where );
    update_status( 'info', "Commands: $read read, $updated updated, imported $imported." );
    return @messages;
}

############################################################################
######
###### Break
######
############################################################################

# process_timeperiods

# FIX THIS:  It makes no sense to truncate the various time tables unless we know
# we are purging instead of merging.  And if we are merging, we cannot truncate
# the time_periods table, and we must only selectively delete just those rows
# from the time_period_property and time_period_exclude tables that correspond
# to the specific time periods we are updating in the time_periods table.

# FIX THIS:  if we do truncate these tables, what will be the effect on other
# tables that reference these time periods, that have already been populated
# during the loading process?  are such cross-references even constructed
# during a load operation?  or are all tables that might refer to time periods
# deliberately handled after the time period tables are constructed?

sub process_timeperiods() {
    my $read       = 0;
    my $updated    = 0;
    my $imported   = 0;
    my $errors     = 0;
    my %tp_exclude = ();
    my $result;

    StorProc->truncate_table('time_periods', 'time_period_property', 'time_period_exclude');

    # Note that we won't get get anything back if we just truncated the time_periods table.
    my %timeperiod_id = StorProc->get_table_objects('time_periods');
    update_status( 'info', 'Loading timeperiods ...' );
    my %where = ( 'type' => 'timeperiod' );
    my %objects = StorProc->fetch_list_hash_array( 'stage_other', \%where );
    foreach my $key ( keys %objects ) {
	$read++;
	my $tp_name = $objects{$key}[0];

	# Clean up the comment field.  FIX THIS:  It should really be done uniformly for all objects.
	$objects{$key}[4] =~ s/^# //;
	$objects{$key}[4] =~ s/^\s+|\s+$//g;

	if ( $timeperiod_id{$tp_name} ) {
	    my %values = ();
	    $values{'alias'} = $objects{$key}[2];
	    $values{'comment'} = $objects{$key}[4] if $objects{$key}[4];
	    $result = StorProc->update_obj( 'time_periods', 'name', $tp_name, \%values );
	    if ( $result =~ /error/i ) {
		update_status( 'error', $result . " (time period \"$tp_name\")" );
		++$errors;
	    }
	    else {
		$updated++;
	    }
	}
	else {
	    my @values = ( \undef, $tp_name, $objects{$key}[2], $objects{$key}[4] );
	    $result = StorProc->insert_obj_id( 'time_periods', \@values, 'timeperiod_id' );
	    if ( $result =~ /error/i ) {
		update_status( 'error', $result . " (time period \"$tp_name\")" );
		delete $timeperiod_id{$tp_name};
		++$errors;
	    }
	    else {
		$timeperiod_id{$tp_name} = $result;
		$imported++;
	    }
	}
	if ( $timeperiod_id{$tp_name} ) {
	    ## FIX MINOR:  If we don't truncate the various time tables above, we must delete
	    ## right here all the rows in both time_period_property and time_period_exclude
	    ## that have a timeperiod_id of $timeperiod_id{$tp_name}, before we go adding
	    ## new rows in time_period_property for this timeperiod.

	    my %data_values = StorProc->parse_xml( $objects{$key}[3] );
	    update_status( 'error', delete $data_values{'error'} ) if defined $data_values{'error'};
	    $tp_exclude{$tp_name} = $data_values{'exclude'};

	    # Note:  In the future, we might also want to add code here to
	    # also process "use" and "require" directives for time periods.
	    delete $data_values{'exclude'};
	    delete $data_values{'use'};
	    delete $data_values{'require'};

	    foreach my $dayrule ( keys %data_values ) {
		my @values = ();
		$values[0] = $timeperiod_id{$tp_name};
		$values[1] = $dayrule;
		$values[2] = 'exception';
		$values[2] = 'weekday' if $dayrule =~ /^\S+day$/;
		if ( $data_values{$dayrule} =~ /(.*?)[;#](.*)/ ) {
		    $values[3] = $1;
		    $values[4] = $2;
		}
		else {
		    $values[3] = $data_values{$dayrule};
		    $values[4] = '';
		}
		$result = StorProc->insert_obj( 'time_period_property', \@values );
		if ( $result =~ /error/i ) {
		    update_status( 'error', $result . " (time period \"$tp_name\")" );
		    ++$errors;
		}
	    }
	}
    }

    # Process all exclude insertions now, here at the end.  We cannot do this in the earlier loop,
    # because back then we may not yet know all the timeperiod_id values we will want to reference here.

    foreach my $tp_name ( keys %tp_exclude ) {
	my @elist = split( /,/, $tp_exclude{$tp_name} );
	foreach my $excluded_tp_name (@elist) {
	    if ( $timeperiod_id{$excluded_tp_name} ) {
		my @values = ( $timeperiod_id{$tp_name}, $timeperiod_id{$excluded_tp_name} );
		$result = StorProc->insert_obj( 'time_period_exclude', \@values );
		if ( $result =~ /error/i ) {
		    update_status( 'error', $result . " (time period \"$tp_name\")" );
		    ++$errors;
		}
	    }
	    else {
		update_status( 'error', "Error: time period \"$tp_name\" exclusion of time period \"$excluded_tp_name\" has not been saved." );
		++$errors;
	    }
	}
    }

    StorProc->delete_one_where( 'stage_other', \%where );
    update_status( 'info',
	    "Time periods: $read read, $updated updated, $imported imported"
	  . ( $errors == 0 ? '' : ", $errors error" . ( $errors == 1 ? '' : 's' ) )
	  . '.' );
    return @messages;
}

############################################################################
######
###### Break
######
############################################################################

# process_contacts

sub process_contacts() {
    my $read              = 0;
    my $updated           = 0;
    my $imported          = 0;
    my %command_name      = StorProc->get_table_objects('commands');
    my %timeperiod_name   = StorProc->get_table_objects('time_periods');
    my %contact_name      = StorProc->get_table_objects('contacts');
    my %contactgroup_name = StorProc->get_table_objects('contactgroups');
    my %contact_templates = StorProc->get_contact_templates();
    my $result;
    local $_;

    update_status( 'info', 'Loading contact templates ...' );
    my %where = ( 'type' => 'contact_template' );
    my %objects = StorProc->fetch_list_hash_array( 'stage_other', \%where );
    my %contact_use = ();

    foreach my $key ( keys %objects ) {
	$read++;
	my %data = StorProc->parse_xml( $objects{$key}[3] );
	update_status( 'error', delete $data{'error'} ) if defined $data{'error'};
	my $data_xml = $xml_begin;
	if ( $data{'use'} ) { $contact_use{ $objects{$key}[0] } = $data{'use'} }
	$contact_templates{ $objects{$key}[0] }{'host_notification_options'} = $data{'host_notification_options'};
	$data_xml .= " <prop name=\"host_notification_options\"><![CDATA[$data{'host_notification_options'}]]>\n";
	$data_xml .= " </prop>\n";
	$contact_templates{ $objects{$key}[0] }{'service_notification_options'} = $data{'service_notification_options'};
	$data_xml .= " <prop name=\"service_notification_options\"><![CDATA[$data{'service_notification_options'}]]>\n";
	$data_xml .= " </prop>\n";
	$data_xml .= $xml_end;
	$contact_templates{ $objects{$key}[0] }{'host_notification_period'}    = $timeperiod_name{ $data{'host_notification_period'} };
	$contact_templates{ $objects{$key}[0] }{'service_notification_period'} = $timeperiod_name{ $data{'service_notification_period'} };

	if ( $contact_templates{ $objects{$key}[0] }{'id'} ) {
	    my %values = ();
	    $values{'data'}                        = $data_xml;
	    $values{'host_notification_period'}    = $timeperiod_name{ $data{'host_notification_period'} };
	    $values{'service_notification_period'} = $timeperiod_name{ $data{'service_notification_period'} };
	    $values{'comment'}                     = $objects{$key}[4];
	    StorProc->update_obj( 'contact_templates', 'name', $objects{$key}[0], \%values );
	    $updated++;
	}
	else {
	    my @values = (
		\undef, $objects{$key}[0],
		$contact_templates{ $objects{$key}[0] }{'host_notification_period'},
		$contact_templates{ $objects{$key}[0] }{'service_notification_period'},
		$data_xml, $objects{$key}[4]
	    );
	    $result = StorProc->insert_obj_id( 'contact_templates', \@values, 'contacttemplate_id' );
	    if ( $result =~ /error/i ) {
		update_status( 'error', $result );
	    }
	    else {
		$contact_templates{ $objects{$key}[0] }{'id'} = $result;
		$imported++;
	    }
	}
	StorProc->delete_all( 'contact_command', 'contacttemplate_id', $contact_templates{ $objects{$key}[0] }{'id'} );
	@{ $contact_templates{ $objects{$key}[0] }{'host_notification_commands'} }    = ();
	@{ $contact_templates{ $objects{$key}[0] }{'service_notification_commands'} } = ();
	my @h = split( /,/, $data{'host_notification_commands'} );
	foreach my $h (@h) {
	    $h =~ s/^\s+|\s+$//g;
	    if ( $command_name{$h} ) {
		my @vals = ( $contact_templates{ $objects{$key}[0] }{'id'}, 'host', $command_name{$h} );
		$result = StorProc->insert_obj( 'contact_command', \@vals );
		if ( $result =~ /error/i ) {
		    update_status( 'error', $result );
		}
		push @{ $contact_templates{ $objects{$key}[0] }{'host_notification_commands'} }, $command_name{$h};
	    }
	}
	my @s = split( /,/, $data{'service_notification_commands'} );
	foreach my $s (@s) {
	    $s =~ s/^\s+|\s+$//g;
	    if ( $command_name{$s} ) {
		my @vals = ( $contact_templates{ $objects{$key}[0] }{'id'}, 'service', $command_name{$s} );
		$result = StorProc->insert_obj( 'contact_command', \@vals );
		if ( $result =~ /error/i ) {
		    update_status( 'error', $result );
		}
		push @{ $contact_templates{ $objects{$key}[0] }{'service_notification_commands'} }, $command_name{$s};
	    }
	}
    }
    StorProc->delete_one_where( 'stage_other', \%where );
    foreach my $temp ( keys %contact_use ) {
	my %values = ();
	foreach my $prop ( keys %{ $contact_templates{ $contact_use{$temp} } } ) {
	    unless ( $contact_templates{$temp}{$prop} || $prop =~ /command/ ) {
		$values{$prop} = $contact_templates{ $contact_use{$temp} }{$prop};
	    }
	}
	if ( $values{'host_notification_options'} || $values{'service_notification_options'} ) {
	    $values{'data'} = $xml_begin;
	    if ( $values{'host_notification_options'} ) {
		$values{'data'} .= " <prop name=\"host_notification_options\"><![CDATA[$values{'host_notification_options'}]]>\n";
		$values{'data'} .= " </prop>\n";
	    }
	    if ( $values{'service_notification_options'} ) {
		$values{'data'} .= " <prop name=\"service_notification_options\"><![CDATA[$values{'service_notification_options'}]]>\n";
		$values{'data'} .= " </prop>\n";
	    }
	    $values{'data'} .= $xml_end;
	    delete $values{'host_notification_options'};
	    delete $values{'service_notification_options'};
	}
	StorProc->update_obj( 'contact_templates', 'name', $temp, \%values );
	unless ( @{ $contact_templates{$temp}{'host_notification_commands'} } ) {
	    foreach my $cid ( @{ $contact_templates{ $contact_use{$temp} }{'host_notification_commands'} } ) {
		my @vals = ( $contact_templates{$temp}{'id'}, 'host', $cid );
		$result = StorProc->insert_obj( 'contact_command', \@vals );
		if ( $result =~ /error/i ) {
		    update_status( 'error', $result );
		}
	    }
	}
	unless ( @{ $contact_templates{$temp}{'service_notification_commands'} } ) {
	    foreach my $cid ( @{ $contact_templates{ $contact_use{$temp} }{'service_notification_commands'} } ) {
		my @vals = ( $contact_templates{$temp}{'id'}, 'service', $cid );
		$result = StorProc->insert_obj( 'contact_command', \@vals );
		if ( $result =~ /error/i ) {
		    update_status( 'error', $result );
		}
	    }
	}
    }
    update_status( 'info', "Contact templates: $read read, $updated updated, $imported imported." );

    # contacts
    $read = $updated = $imported = 0;
    update_status( 'info', 'Loading contacts ...' );
    %where = ( 'type' => 'contact' );
    %objects = StorProc->fetch_list_hash_array( 'stage_other', \%where );
    my %contact_contactgroups = ();
    my $index                 = 1;
    foreach my $key ( keys %objects ) {
	$read++;
	my %data = StorProc->parse_xml( $objects{$key}[3] );
	update_status( 'error', delete $data{'error'} ) if defined $data{'error'};
	my @h          = split( /,/, $data{'host_notification_commands'} );
	my %h_commands = ();
	foreach my $h (@h) {
	    $h =~ s/^\s+|\s+$//g;
	    $h_commands{$h} = $command_name{$h};
	}
	my @s = split( /,/, $data{'service_notification_commands'} );
	my %s_commands = ();
	foreach my $s (@s) {
	    $s =~ s/^\s+|\s+$//g;
	    $s_commands{$s} = $command_name{$s};
	}
	unless ( $data{'use'} ) {
	    $read++;
	    update_status( 'note', "Contact $objects{$key}[0] does not use a template." );
	    my $bestmatch = 0;
	    my %w         = ();
	    foreach my $temp ( keys %contact_templates ) {
		my $gotmatch = 0;
		foreach my $tc ( @{ $contact_templates{$temp}{'host_notification_commands'} } ) {
		    foreach my $key ( keys %h_commands ) {
			if ( $h_commands{$key} eq $tc ) { $gotmatch++ }
		    }
		}
		foreach my $tc ( @{ $contact_templates{$temp}{'service_notification_commands'} } ) {
		    foreach my $key ( keys %s_commands ) {
			if ( $s_commands{$key} eq $tc ) { $gotmatch++ }
		    }
		}
		if ( $timeperiod_name{ $data{'host_notification_period'} } eq $contact_templates{$temp}{'host_notification_period'} ) {
		    $gotmatch++;
		}
		if ( $timeperiod_name{ $data{'service_notification_period'} } eq $contact_templates{$temp}{'service_notification_period'} ) {
		    $gotmatch++;
		}

		my %t = ();
		my @sort = split( /,/, $data{'host_notification_options'} );
		@sort = sort @sort;
		my $sorted = undef;
		foreach (@sort) { $sorted .= "$_," }
		chop $sorted;
		$data{'host_notification_options'} = $sorted;
		@sort   = split( /,/, $data{'service_notification_options'} );
		@sort   = sort @sort;
		$sorted = undef;
		foreach (@sort) { $sorted .= "$_," }
		chop $sorted;
		$data{'service_notification_options'} = $sorted;
		@sort   = split( /,/, $contact_templates{ $data{'use'} }{'host_notification_options'} );
		@sort   = sort @sort;
		$sorted = undef;
		foreach (@sort) { $sorted .= "$_," }
		chop $sorted;
		$t{'host_notification_period'} = $sorted;
		@sort   = split( /,/, $contact_templates{ $data{'use'} }{'service_notification_options'} );
		@sort   = sort @sort;
		$sorted = undef;
		foreach (@sort) { $sorted .= "$_," }
		chop $sorted;
		$t{'service_notification_period'} = $sorted;

		if ( $data{'host_notification_options'} eq $t{'host_notification_options'} ) {
		    $gotmatch++;
		}
		if ( $data{'service_notification_options'} eq $t{'service_notification_options'} ) {
		    $gotmatch++;
		}

		if ( $gotmatch > $bestmatch ) {
		    $bestmatch = $gotmatch;
		    $data{'use'} = $temp;
		}
	    }
	    if ( $data{'use'} ) {
		update_status( 'action', "Assigned: Contact template $data{'use'} assigned to contact $objects{$key}[0]" );
	    }
	}
	unless ( $data{'use'} ) {
	    my $name     = "generic-contact-$index";
	    my $data_xml = $xml_begin;
	    $contact_templates{$name}{'host_notification_options'} = $data{'host_notification_options'};
	    $data_xml .= " <prop name=\"host_notification_options\"><![CDATA[$data{'host_notification_options'}]]>\n";
	    $data_xml .= " </prop>\n";
	    $contact_templates{$name}{'service_notification_options'} = $data{'service_notification_options'};
	    $data_xml .= " <prop name=\"service_notification_options\"><![CDATA[$data{'service_notification_options'}]]>\n";
	    $data_xml .= " </prop>\n";
	    $data_xml .= $xml_end;
	    $contact_templates{$name}{'host_notification_period'}    = $timeperiod_name{ $data{'host_notification_period'} };
	    $contact_templates{$name}{'service_notification_period'} = $timeperiod_name{ $data{'service_notification_period'} };
	    my $comment = undef;
	    my @values  = (
		\undef, $name,
		$timeperiod_name{ $data{'host_notification_period'} },
		$timeperiod_name{ $data{'service_notification_period'} },
		$data_xml, $comment
	    );
	    $result = StorProc->insert_obj_id( 'contact_templates', \@values, 'contacttemplate_id' );
	    if ( $result =~ /error/i ) {
		update_status( 'error', $result );
	    }
	    else {
		$contact_templates{$name}{'id'} = $result;
	    }

	    foreach my $key ( keys %h_commands ) {
		if ( $command_name{$key} ) {
		    my @vals = ( $contact_templates{$name}{'id'}, 'host', $command_name{$key} );
		    $result = StorProc->insert_obj( 'contact_command', \@vals );
		    if ( $debug && $result =~ /error/i ) {
			update_status( 'error', $result );
		    }
		}
	    }
	    foreach my $key ( keys %s_commands ) {
		if ( $command_name{$key} ) {
		    my @vals = ( $contact_templates{$name}{'id'}, 'service', $command_name{$key} );
		    $result = StorProc->insert_obj( 'contact_command', \@vals );
		    if ( $debug && $result =~ /error/i ) {
			update_status( 'error', $result );
		    }
		}
	    }
	    update_status( 'action', "Added: Contact template $name, assigned to contact $objects{$key}[0]" );
	    $data{'use'} = $name;
	    $index++;
	}
	if ( $contact_name{ $objects{$key}[0] } ) {
	    my %values = ();
	    $values{'alias'}              = $objects{$key}[2];
	    $values{'email'}              = $data{'email'};
	    $values{'pager'}              = $data{'pager'};
	    $values{'contacttemplate_id'} = $contact_templates{ $data{'use'} }{'id'};
	    $values{'status'}             = '1';
	    $values{'comment'}            = $objects{$key}[4];
	    StorProc->update_obj( 'contacts', 'name', $objects{$key}[0], \%values );
	    $updated++;
	}
	else {
	    my @values = (
		\undef, $objects{$key}[0], $objects{$key}[2], $data{'email'}, $data{'pager'}, $contact_templates{ $data{'use'} }{'id'},
		'1', $objects{$key}[4]
	    );
	    $result = StorProc->insert_obj_id( 'contacts', \@values, 'contact_id' );
	    if ( $result =~ /error/i ) {
		update_status( 'error', $result );
	    }
	    else {
		$contact_name{ $objects{$key}[0] } = $result;
		$imported++;
	    }
	}
	if ( $data{'contactgroups'} ) {
	    $contact_contactgroups{ $contact_name{ $objects{$key}[0] } } = $data{'contactgroups'};
	}

	# process overrides
	StorProc->delete_all( 'contact_overrides',         'contact_id', $contact_name{ $objects{$key}[0] } );
	StorProc->delete_all( 'contact_command_overrides', 'contact_id', $contact_name{ $objects{$key}[0] } );
	my $match = 0;
	my $i     = 0;
	foreach my $tc ( @{ $contact_templates{ $data{'use'} }{'host_notification_commands'} } ) {
	    $i++;
	    foreach my $key ( keys %h_commands ) {
		unless ( $h_commands{$key} eq $tc ) { $match++ }
	    }
	}
	unless ( $i == $match ) {
	    foreach my $k ( keys %h_commands ) {
		if ( $h_commands{$k} ) {
		    my @values = ( $contact_name{ $objects{$key}[0] }, 'host', $h_commands{$k} );
		    $result = StorProc->insert_obj( 'contact_command_overrides', \@values );
		    if ( $debug && $result =~ /error/i ) {
			update_status( 'error', $result );
		    }
		}
	    }
	}
	$match = 0;
	$i     = 0;
	foreach my $tc ( @{ $contact_templates{ $data{'use'} }{'service_notification_commands'} } ) {
	    $i++;
	    foreach my $key ( keys %s_commands ) {
		if ( $s_commands{$key} eq $tc ) { $match++ }
	    }
	}
	unless ( $i == $match ) {
	    foreach my $k ( keys %s_commands ) {
		if ( $s_commands{$k} ) {
		    my @values = ( $contact_name{ $objects{$key}[0] }, 'service', $s_commands{$k} );
		    $result = StorProc->insert_obj( 'contact_command_overrides', \@values );
		    if ( $debug && $result =~ /error/i ) {
			update_status( 'error', $result );
		    }
		}
	    }
	}
	my %t         = ();
	my %overrides = ();
	my @sort      = split( /,/, $data{'host_notification_options'} );
	@sort = sort @sort;
	my $sorted = undef;
	foreach (@sort) { $sorted .= "$_," }
	chop $sorted;
	$data{'host_notification_options'} = $sorted;
	@sort   = split( /,/, $data{'service_notification_options'} );
	@sort   = sort @sort;
	$sorted = undef;
	foreach (@sort) { $sorted .= "$_," }
	chop $sorted;
	$data{'service_notification_options'} = $sorted;
	@sort =
	  split( /,/, $contact_templates{ $data{'use'} }{'host_notification_options'} );
	@sort   = sort @sort;
	$sorted = undef;
	foreach (@sort) { $sorted .= "$_," }
	chop $sorted;
	$t{'host_notification_period'} = $sorted;
	@sort   = split( /,/, $contact_templates{ $data{'use'} }{'service_notification_options'} );
	@sort   = sort @sort;
	$sorted = undef;
	foreach (@sort) { $sorted .= "$_," }
	chop $sorted;
	$t{'service_notification_period'} = $sorted;

	unless ( $timeperiod_name{ $data{'host_notification_period'} } eq $contact_templates{ $data{'use'} }{'host_notification_period'} ) {
	    $overrides{'host_notification_period'} = $timeperiod_name{ $data{'host_notification_period'} };
	}
	unless ( $timeperiod_name{ $data{'service_notification_period'} } eq $contact_templates{ $data{'use'} }{'service_notification_period'} )
	{
	    $overrides{'service_notification_period'} = $timeperiod_name{ $data{'service_notification_period'} };
	}
	unless ( $data{'host_notification_options'} eq $t{'host_notification_options'} ) {
	    $overrides{'host_notification_options'} = $data{'host_notification_options'};
	}
	unless ( $data{'service_notification_options'} eq $t{'service_notification_options'} ) {
	    $overrides{'service_notification_options'} = $data{'service_notification_options'};
	}
	my $data = undef;
	foreach my $d ( keys %overrides ) {
	    if ( $d =~ /options/ ) {
		$data .= " <prop name=\"$d\"><![CDATA[$data{$d}]]>\n";
		$data .= " </prop>\n";
	    }
	}
	if ($data) { $data = $xml_begin . $data . $xml_end }
	if (   $data{'host_notification_options'}
	    || $data{'service_notification_options'}
	    || $overrides{'host_notification_period'}
	    || $overrides{'service_notification_period'} )
	{
	    my @values =
	      ( $contact_name{ $objects{$key}[0] }, $overrides{'host_notification_period'}, $overrides{'service_notification_period'}, $data );
	    $result = StorProc->insert_obj( 'contact_overrides', \@values );
	    if ( $debug && $result =~ /error/i ) {
		update_status( 'error', $result );
	    }
	}
    }
    StorProc->delete_one_where( 'stage_other', \%where );
    update_status( 'info', "Contacts: $read read, $updated updated, imported $imported." );

    # contactgroups
    $read = $updated = $imported = 0;
    update_status( 'info', 'Loading contactgroups ...' );
    %where = ( 'type' => 'contactgroup' );
    %objects = StorProc->fetch_list_hash_array( 'stage_other', \%where );
    foreach my $key ( keys %objects ) {
	$read++;
	if ( $contactgroup_name{ $objects{$key}[0] } ) {
	    my %values = ();
	    $values{'alias'}   = $objects{$key}[2];
	    $values{'comment'} = $objects{$key}[4];
	    StorProc->update_obj( 'contactgroups', 'name', $objects{$key}[0], \%values );
	    $updated++;
	}
	else {
	    my @values = ( \undef, $objects{$key}[0], $objects{$key}[2], $objects{$key}[4] );
	    $result = StorProc->insert_obj_id( 'contactgroups', \@values, 'contactgroup_id' );
	    if ( $result =~ /Error/ ) {
		update_status( 'error', $result );
	    }
	    else {
		$contactgroup_name{ $objects{$key}[0] } = $result;
		$imported++;
	    }
	}
	StorProc->delete_all( 'contactgroup_contact', 'contactgroup_id', $contactgroup_name{ $objects{$key}[0] } );
	my %data = StorProc->parse_xml( $objects{$key}[3] );
	update_status( 'error', delete $data{'error'} ) if defined $data{'error'};
	my %members = ();
	my @mems    = split( /,/, $data{'members'} );
	foreach (@mems) { $members{$_} = 1 }
	foreach my $mem ( keys %members ) {
	    $mem =~ s/^\s+|\s+$//g;
	    if ( $contact_name{$mem} ) {
		my @vals = ( $contactgroup_name{ $objects{$key}[0] }, $contact_name{$mem} );
		$result = StorProc->insert_obj( 'contactgroup_contact', \@vals );
		if ( $result =~ /Error/ ) {
		    update_status( 'error', $result );
		}
	    }
	    else {
		update_status( 'info', "\"$mem\" is not a valid contact and so will be ignored." );
	    }
	}
    }
    StorProc->delete_one_where( 'stage_other', \%where );

    foreach my $cid ( keys %contact_contactgroups ) {
	my @cgs = split( /,/, $contact_contactgroups{$cid} );
	foreach my $cname (@cgs) {
	    my @vals = ( $contactgroup_name{$cname}, $cid );
	    $result = StorProc->insert_obj( 'contactgroup_contact', \@vals );
	    if ( $result =~ /Error/ ) {
		update_status( 'error', $result );
	    }
	}
    }
    update_status( 'info', "Contact groups: $read read, $updated updated, imported $imported." );

    return @messages;
}

############################################################################
######
###### Break
######
############################################################################

# hosts

sub process_hosts() {
    my $read                  = 0;
    my $updated               = 0;
    my $imported              = 0;
    my $new                   = 0;
    my %command_name          = StorProc->get_table_objects('commands');
    my %timeperiod_name       = StorProc->get_table_objects('time_periods');
    my %contact_name          = StorProc->get_table_objects('contacts');
    my %contactgroup_name     = StorProc->get_table_objects('contactgroups');
    my %service_name          = StorProc->get_table_objects('service_names');
    my %host_templates        = StorProc->get_host_templates();
    my %hostextinfo_templates = StorProc->get_hostextinfo_templates();
    my %host_name             = StorProc->get_table_objects('hosts');
    my %hostgroup_name        = StorProc->get_table_objects('hostgroups');
    my $result;
    local $_;

    # host templates
    update_status( 'info', 'Loading host templates ...' );
    my %host_template_name    = ();
    my %where                 = ( 'type' => 'host_template' );
    my %template_parents      = ();
    my %template_hostgroups   = ();
    my %redundant_templates   = ();
    my %consolidate_templates = ();
    my %objects               = StorProc->fetch_list_hash_array( 'stage_other', \%where );

    foreach my $key ( keys %objects ) {
	$read++;
	my %data = StorProc->parse_xml( $objects{$key}[3] );
	update_status( 'error', delete $data{'error'} ) if defined $data{'error'};
	my $props = 0;
	foreach ( keys %data ) { $props++ }
	my $data_xml = undef;
	if ( $data{'hostgroups'} ) {
	    $props -= 1;
	    $template_hostgroups{ $objects{$key}[0] } = $data{'hostgroups'};
	    update_status( 'note', "Hostgroup directive on host template $objects{$key}[0]." );
	    update_status( 'action',
		"Hostgroup directive moved: Hostgroups $data{'hostgroups'} moved from host template $objects{$key}[0] to hosts." );
	    delete $data{'hostgroups'};
	}
	if ( $data{'parents'} ) {
	    $props -= 1;
	    $template_parents{ $objects{$key}[0] }{'parents'} = $data{'parents'};
	    update_status( 'note',   "Parent directive on host template $objects{$key}[0]." );
	    update_status( 'action', "Parent directive moved: Parents $data{'parents'} moved from host template $objects{$key}[0] to hosts." );
	    delete $data{'parents'};
	}
	if ( $data{'use'} && $props == 1 ) {
	    $redundant_templates{ $objects{$key}[0] } = $data{'use'};
	    update_status( 'note',
		"Redundant: Host template $objects{$key}[0] is redundant as it references $data{'use'} but has no properties itself." );
	    update_status( 'action',
		"Staged for removal: Host template $objects{$key}[0]. Hosts using $objects{$key}[0] will be referenced to $data{'use'}." );
	}
	else {
	    if ( $data{'use'} ) {
		$consolidate_templates{ $objects{$key}[0] } = $data{'use'};
		update_status( 'note', "Host template $objects{$key}[0] is a host template that references a host template." );
		update_status( 'warning',
"Reference removed: Host template $objects{$key}[0] will no longer reference $data{'use'}. Please check Hosts->Host Templates->$objects{$key}[0] values."
		);
		delete $data{'use'};
	    }
	    $host_templates{ $objects{$key}[0] }{'check_period'}        = $timeperiod_name{ $data{'check_period'} };
	    $host_templates{ $objects{$key}[0] }{'notification_period'} = $timeperiod_name{ $data{'notification_period'} };
	    $host_templates{ $objects{$key}[0] }{'check_command'}       = $command_name{ $data{'check_command'} };
	    $host_templates{ $objects{$key}[0] }{'event_handler'}       = $command_name{ $data{'event_handler'} };
	    delete $data{'notification_period'};
	    delete $data{'check_command'};
	    delete $data{'check_period'};
	    delete $data{'event_handler'};
	    my $template_contactgroups = $data{'contact_groups'};
	    delete $data{'contact_groups'};
	    my $data_xml = $xml_begin;

	    foreach my $prop ( keys %data ) {
		$data_xml .= " <prop name=\"$prop\"><![CDATA[$data{$prop}]]>\n";
		$data_xml .= " </prop>\n";
		$host_templates{ $objects{$key}[0] }{$prop} = $data{$prop};
	    }
	    $data_xml .= $xml_end;
	    if ( $host_templates{ $objects{$key}[0] }{'id'} ) {
		my %values = ();
		$values{'check_period'}        = $host_templates{ $objects{$key}[0] }{'check_period'};
		$values{'notification_period'} = $host_templates{ $objects{$key}[0] }{'notification_period'};
		$values{'check_command'}       = $host_templates{ $objects{$key}[0] }{'check_command'};
		$values{'event_handler'}       = $host_templates{ $objects{$key}[0] }{'event_handler'};
		$values{'data'}                = $data_xml;
		$values{'comment'}             = $objects{$key}[4];
		StorProc->update_obj( 'host_templates', 'name', $objects{$key}[0], \%values );
		$updated++;
	    }
	    else {
		my @values = (
		    \undef,                                                $objects{$key}[0],
		    $host_templates{ $objects{$key}[0] }{'check_period'},  $host_templates{ $objects{$key}[0] }{'notification_period'},
		    $host_templates{ $objects{$key}[0] }{'check_command'}, $host_templates{ $objects{$key}[0] }{'event_handler'},
		    $data_xml,                                             $objects{$key}[4]
		);
		$result = StorProc->insert_obj_id( 'host_templates', \@values, 'hosttemplate_id' );
		if ( $result =~ /Error/ ) {
		    update_status( 'error', $result );
		}
		else {
		    $host_templates{ $objects{$key}[0] }{'id'} = $result;
		    $imported++;
		}
	    }

	    ## my %w = ('type' => 'host_templates','object' => $host_templates{$objects{$key}[0]}{'id'});
	    ## StorProc->delete_one_where('contactgroup_assign',\%w);
	    my %w = ( 'hosttemplate_id' => $host_templates{ $objects{$key}[0] }{'id'} );
	    StorProc->delete_one_where( 'contactgroup_host_template', \%w );

	    my @members = split( /,/, $template_contactgroups );
	    @{ $host_templates{ $objects{$key}[0] }{'contactgroups'} } = ();
	    foreach my $mem (@members) {
		$mem =~ s/^\s+|\s+$//g;
		unless ( $contactgroup_name{$mem} ) {
		    update_status( 'error', "Contact group $mem does not exist for host template $objects{$key}[0]." );
		}
		else {
		    ## my @vals = ($contactgroup_name{$mem},'host_templates',$host_templates{$objects{$key}[0]}{'id'});
		    ## StorProc->insert_obj('contactgroup_assign',\@vals);
		    my @vals = ( $contactgroup_name{$mem}, $host_templates{ $objects{$key}[0] }{'id'} );
		    $result = StorProc->insert_obj( 'contactgroup_host_template', \@vals );
		    if ( $result =~ /Error/ ) { update_status( 'error', $result ) }
		    push @{ $host_templates{ $objects{$key}[0] }{'contactgroups'} }, $contactgroup_name{$mem};
		}
	    }
	}
    }
    ## Collapse host template chains, because Monarch currently only supports one level.
    ## FIX LATER:  deal with additive inheritance here (where the local non-custom string variable contains a leading "+")
    ## FIX LATER:  deal with multiple-level inheritance chains here (i.e., sequence the $temp values according to their level
    ## in the hierarchy, instead of randomly), watching out for possible circular template references in the incoming files
    foreach my $temp ( keys %consolidate_templates ) {
	my %values = ();
	foreach my $prop ( keys %{ $host_templates{ $consolidate_templates{$temp} } } ) {
	    if ( $prop eq 'contactgroups' ) {
		unless ( @{ $host_templates{$temp}{'contactgroups'} } ) {
		    foreach my $cgid ( @{ $host_templates{ $consolidate_templates{$temp} }{$prop} } ) {
			## my @vals = ($cgid,'host_templates',$host_templates{$temp}{'id'});
			## StorProc->insert_obj('contactgroup_assign',\@vals);
			my @vals = ( $cgid, $host_templates{$temp}{'id'} );
			$result = StorProc->insert_obj( 'contactgroup_host_template', \@vals );
			if ( $result =~ /Error/ ) { update_status( 'error', $result ) }
			push @{ $host_templates{$temp}{'contactgroups'} }, $cgid;
		    }
		}
	    }
	    else {
		unless ( defined $host_templates{$temp}{$prop} ) {
		    $host_templates{$temp}{$prop} = $host_templates{ $consolidate_templates{$temp} }{$prop};
		    if ( $prop =~ /^check_period$|^notification_period$|^check_command$|^event_handler$/ ) {
			$values{$prop} = $host_templates{ $consolidate_templates{$temp} }{$prop};
		    }
		}
	    }
	}
	$values{'data'} = $xml_begin;
	foreach my $prop ( keys %{ $host_templates{$temp} } ) {
	    unless ( $prop =~ /^check_period$|^notification_period$|^id$|^contactgroups$|^check_command$|^event_handler$/ ) {
		$values{'data'} .= " <prop name=\"$prop\"><![CDATA[$host_templates{$temp}{$prop}]]>\n";
		$values{'data'} .= " </prop>\n";
	    }
	}
	$values{'data'} .= $xml_end;
	StorProc->update_obj( 'host_templates', 'name', $temp, \%values );
    }
    update_status( 'info', "Host templates: $read read, $updated updated, $imported imported." );

    StorProc->delete_one_where( 'stage_other', \%where );

    # hostextinfo templates
    $read = $updated = $imported = $new = 0;
    update_status( 'info', 'Loading hostextinfo templates ...' );
    %where = ( 'type' => 'hostextinfo_template' );
    %objects = StorProc->fetch_list_hash_array( 'stage_other', \%where );
    my $index = 1;
    foreach my $key ( keys %objects ) {
	$read++;
	my %data = StorProc->parse_xml( $objects{$key}[3] );
	update_status( 'error', delete $data{'error'} ) if defined $data{'error'};
	foreach my $prop ( keys %data ) {
	    $hostextinfo_templates{ $objects{$key}[0] }{$prop} = $data{$prop};
	}
	if ( $hostextinfo_templates{ $objects{$key}[0] }{'id'} ) {
	    my %values = ();
	    $values{'data'}    = $objects{$key}[3];
	    $values{'comment'} = $objects{$key}[4];
	    StorProc->update_obj( 'extended_host_info_templates', 'name', $objects{$key}[0], \%values );
	    $updated++;
	}
	else {
	    my @values = ( \undef, $objects{$key}[0], $objects{$key}[3], '', $objects{$key}[4] );
	    $result = StorProc->insert_obj_id( 'extended_host_info_templates', \@values, 'hostextinfo_id' );
	    if ( $result =~ /Error/ ) {
		update_status( 'error', $result );
	    }
	    else {
		$hostextinfo_templates{ $objects{$key}[0] }{'id'} = $result;
		$imported++;
	    }
	}
    }
    StorProc->delete_one_where( 'stage_other', \%where );

    update_status( 'info', "Host extended info templates: $read read, $updated updated, $imported imported." );

    # hosts
    $read = $updated = $imported = $new = 0;
    update_status( 'info', 'Loading hosts ...' );
    my %host_parents   = ();
    my %host_hostgroup = ();
    %where = ( 'type' => 'host' );
    %objects = StorProc->fetch_list_hash_array( 'stage_other', \%where );
    $index = 1;
    foreach my $key ( keys %objects ) {
	$read++;
	my $status         = 1;
	my %host_overrides = ();
	my %data           = StorProc->parse_xml( $objects{$key}[3] );
	update_status( 'error', delete $data{'error'} ) if defined $data{'error'};
	delete $data{'command_line'};
	my %contactgroups = ();
	my @parents       = ();
	if ( $redundant_templates{ $data{'use'} } ) {
	    $data{'use'} = $redundant_templates{ $data{'use'} };
	}
	if ( $data{'parents'} ) {
	    @parents = split( /,/, $data{'parents'} );
	    delete $data{'parents'};
	}
	if ( $data{'check_period'} ) {
	    if ( $timeperiod_name{ $data{'check_period'} } ) {
		$host_overrides{'check_period'} = $timeperiod_name{ $data{'check_period'} };
	    }
	    else {
		my $tname = $data{'check_period'};
		update_status( 'error',
		    "Time period $data{'check_period'} is specified for host \"$objects{$key}[0]\" but no such time period exists." );
		my @values = ( \undef, $data{'check_period'}, '', $xml_begin . $xml_end, '' );
		$result = StorProc->insert_obj_id( 'time_periods', \@values, 'timeperiod_id' );
		if ( $result =~ /Error/ ) {
		    update_status( 'error', $result );
		}
		else {
		    $timeperiod_name{ $data{'check_period'} } = $result;
		}
		$host_overrides{'check_period'} = $timeperiod_name{ $data{'check_period'} };
		update_status( 'warning',
"Added time period $tname but properties have not been set. WARNING: You must set the properties before attempting preflight or commit!"
		);
	    }
	    delete $data{'check_period'};
	}
	if ( $data{'notification_period'} ) {
	    if ( $timeperiod_name{ $data{'notification_period'} } ) {
		$host_overrides{'notification_period'} = $timeperiod_name{ $data{'notification_period'} };
	    }
	    else {
		my $tname = $data{'notification_period'};
		update_status( 'error',
		    "Time period $data{'notification_period'} is specified for host \"$objects{$key}[0]\" but no such time period exists." );
		my @values = ( \undef, $data{'notification_period'}, '', $xml_begin . $xml_end, '' );
		$result = StorProc->insert_obj_id( 'time_periods', \@values, 'timeperiod_id' );
		if ( $result =~ /Error/ ) {
		    update_status( 'error', $result );
		}
		else {
		    $timeperiod_name{ $data{'notification_period'} } = $result;
		}
		$host_overrides{'notification_period'} = $timeperiod_name{ $data{'notification_period'} };
		update_status( 'warning',
"Added time period $tname but properties have not been set. WARNING: You must set the properties before attempting preflight or commit!"
		);
	    }
	    delete $data{'notification_period'};
	}
	if ( $data{'check_command'} ) {
	    if ( $command_name{ $data{'check_command'} } ) {
		$host_overrides{'check_command'} = $command_name{ $data{'check_command'} };
	    }
	    else {
		my $tname = $data{'check_command'};
		update_status( 'error',
		    "Check command $data{'check_command'} is specified for host \"$objects{$key}[0]\" but no such command definition exists." );
		my @values = ( \undef, $data{'check_command'}, 'check', $xml_begin . $xml_end, '' );
		$result = StorProc->insert_obj_id( 'commands', \@values, 'command_id' );
		if ( $result =~ /Error/ ) {
		    update_status( 'error', $result );
		}
		else {
		    $host_overrides{'check_command'} = $result;
		}
		$command_name{ $data{'check_command'} } = $host_overrides{'check_command'};
		update_status( 'warning',
"Added check command $tname but properties have not been set. WARNING: You must set the properties before attempting preflight or commit!"
		);
	    }
	    delete $data{'check_command'};
	}
	if ( $data{'event_handler'} ) {
	    if ( $command_name{ $data{'event_handler'} } ) {
		$host_overrides{'event_handler'} = $command_name{ $data{'event_handler'} };
	    }
	    else {
		my $tname = $data{'event_handler'};
		update_status( 'error',
		    "Event handler $data{'event_handler'} is specified for host \"$objects{$key}[0]\" but no such command definition exists." );
		my @values = ( \undef, $data{'event_handler'}, 'check', $xml_begin . $xml_end, '' );
		$result = StorProc->insert_obj_id( 'commands', \@values, 'command_id' );
		if ( $result =~ /Error/ ) {
		    update_status( 'error', $result );
		}
		else {
		    $host_overrides{'event_handler'} = $result;
		}
		$command_name{ $data{'event_handler'} } = $host_overrides{'event_handler'};
		update_status( 'warning',
"Added event handler $tname but properties have not been set. WARNING: You must set the properties before attempting preflight or commit!"
		);
	    }
	    delete $data{'event_handler'};
	}
	if ( $data{'contact_groups'} ) {
	    my @cgs = split( /,/, $data{'contact_groups'} );
	    foreach my $cg (@cgs) {
		$cg =~ s/^\s+|\s+$//g;
		if ( $contactgroup_name{$cg} ) {
		    $contactgroups{$cg} = $contactgroup_name{$cg};
		}
	    }
	    delete $data{'contact_groups'};
	}

	foreach my $k ( keys %data ) {
	    $host_overrides{$k} = $data{$k};
	}

	unless ( $data{'use'} ) {
	    update_status( 'note', "Host $objects{$key}[0] does not use a template" );
	    my $bestmatch = 0;
	    foreach my $temp ( keys %host_templates ) {
		my $gotmatch = 0;
		if ( $host_overrides{'check_period'} eq $host_templates{$temp}{'check_period'} ) {
		    $gotmatch++;
		}
		if ( $host_overrides{'notification_period'} eq $host_templates{$temp}{'notification_period'} ) {
		    $gotmatch++;
		}
		if ( $host_overrides{'check_command'} eq $host_templates{$temp}{'check_command'} ) {
		    $gotmatch++;
		}
		if ( $host_overrides{'event_handler'} eq $host_templates{$temp}{'event_handler'} ) {
		    $gotmatch++;
		}
		foreach my $d ( keys %data ) {
		    if ( $d =~ /file_name|address|alias|parents/ ) { next }
		    if ( defined( $host_templates{$temp}{$d} ) && $data{$d} eq $host_templates{$temp}{$d} ) { $gotmatch++ }
		}

		foreach my $cgid ( @{ $host_templates{$temp}{'contactgroups'} } ) {
		    foreach my $cg ( keys %contactgroups ) {
			if ( $contactgroups{$cg} eq $cgid ) { $gotmatch++ }
		    }
		}
		if ( $gotmatch > $bestmatch ) {
		    $bestmatch = $gotmatch;
		    $data{'use'} = $temp;
		}
	    }
	    update_status( 'action', "Assigned host template $data{'use'} to host $objects{$key}[0]." );
	}
	else {
	    unless ( $host_templates{ $data{'use'} }{'id'} ) {
		update_status( 'error', "host $objects{$key}[0] specifies template $data{'use'} but no such template exists." );
		my $data    = $xml_begin . $xml_end;
		my $comment = undef;
		my @values  = ( \undef, $data{'use'}, '', '', '', '', $data, $comment );
		$result = StorProc->insert_obj_id( 'host_templates', \@values, 'hosttemplate_id' );
		if ( $result =~ /Error/ ) {
		    update_status( 'error', $result );
		}
		else {
		    $host_templates{ $data{'use'} }{'id'} = $result;
		}
		update_status( 'warning',
"Added host template $data{'use'}, but properties have not been set. WARNING: You must set the properties before attempting preflight or commit!"
		);
	    }
	}
	unless ( $data{'address'} ) { $data{'address'} = $objects{$key}[0] }
	if ( $host_name{ $objects{$key}[0] } ) {
	    my %values = ();
	    $values{'alias'}           = $data{'alias'};
	    $values{'address'}         = $data{'address'};
	    $values{'hosttemplate_id'} = $host_templates{ $data{'use'} }{'id'};
	    $values{'comment'}         = $objects{$key}[4];
	    StorProc->update_obj( 'hosts', 'name', $objects{$key}[0], \%values );
	    $updated++;
	}
	else {
	    ## FIX MAJOR NOW:  unxmlify the notes
	    my @values = (
		\undef, $objects{$key}[0], $data{'alias'}, $data{'address'}, 'n/a', $host_templates{ $data{'use'} }{'id'},
		'', '', '', '', $status, $objects{$key}[4], $data{'notes'}
	    );
	    $result = StorProc->insert_obj_id( 'hosts', \@values, 'host_id' );
	    if ( $result =~ /Error/ ) {
		update_status( 'error', $result );
	    }
	    else {
		$host_name{ $objects{$key}[0] } = $result;
		$imported++;
	    }
	}
	if (@parents) {
	    foreach my $p (@parents) {
		$host_parents{ $objects{$key}[0] } .= "$p,";
	    }
	    chop $host_parents{ $host_name{ $objects{$key}[0] } };
	}
	elsif ( $template_parents{ $data{'use'} }{'parents'} ) {
	    push @{ $template_parents{ $data{'use'} }{'hosts'} }, $host_name{ $objects{$key}[0] };
	}
	if ( $data{'hostgroups'} ) {
	    $host_hostgroup{ $host_name{ $objects{$key}[0] } } = $data{'hostgroups'};
	}
	elsif ( $template_hostgroups{ $data{'use'} } ) {
	    $host_hostgroup{ $host_name{ $objects{$key}[0] } } = $template_hostgroups{ $data{'use'} };
	}
	StorProc->delete_all( 'host_overrides', 'host_id', $host_name{ $objects{$key}[0] } );
	my $got_covs = 0;
	foreach my $k ( keys %host_overrides ) {
	    if ( $host_templates{ $data{'use'} }{$k} eq $host_overrides{$k} ) {
		delete $host_overrides{$k};
	    }
	    elsif ($k =~ /^_/) {
		$got_covs = 1;
	    }
	}
	## FIX MINOR:  There are probably lots of other possible override fields that we ought to test for here,
	## To force an update.  Should we do so in a blanket way?
	if (   $host_overrides{'check_period'}
	    || $host_overrides{'notification_period'}
	    || $host_overrides{'check_command'}
	    || $host_overrides{'event_handler'}
	    || $host_overrides{'max_check_attempts'}
	    || $host_overrides{'notification_options'}
	    || $host_overrides{'notification_interval'}
	    || $got_covs)
	{
	    my $data_xml = $xml_begin;
	    foreach my $o ( keys %host_overrides ) {
		unless ( $o =~ /alias|address|file_name|check_period|notification_period|check_command|event_handler|^use$/ ) {
		    $data_xml .= " <prop name=\"$o\"><![CDATA[$host_overrides{$o}]]>\n";
		    $data_xml .= " </prop>\n";
		}
	    }
	    $data_xml .= $xml_end;
	    my @values = (
		$host_name{ $objects{$key}[0] },
		$host_overrides{'check_period'},
		$host_overrides{'notification_period'},
		$host_overrides{'check_command'},
		$host_overrides{'event_handler'}, $data_xml
	    );
	    $result = StorProc->insert_obj( 'host_overrides', \@values );
	    if ( $result =~ /Error/ ) { update_status( 'error', $result ) }
	}
	if (%contactgroups) {
	    foreach my $cg ( keys %contactgroups ) {
		if ($cg) {
		    ## my @vals = ($contactgroups{$cg},'hosts',$host_name{$objects{$key}[0]});
		    ## StorProc->insert_obj('contactgroup_assign',\@vals);
		    my @vals = ( $contactgroups{$cg}, $host_name{ $objects{$key}[0] } );
		    $result = StorProc->insert_obj( 'contactgroup_host', \@vals );
		    if ( $result =~ /Error/ && $result !~ /duplicate/i ) {
			update_status( 'error', "$result (contact group $cg, host $objects{$key}[0])" );
		    }
		}
	    }
	}
    }
    StorProc->delete_one_where( 'stage_other', \%where );
    update_status( 'info', "Hosts: $read read, $updated updated, $imported imported." );

    # host parent
    update_status( 'info', "Setting host parent relationships ..." );
    StorProc->truncate_table('host_parent');
    foreach my $host ( keys %host_parents ) {
	my @parents = split( /,/, $host_parents{$host} );
	foreach my $parent (@parents) {
	    $parent =~ s/^\s+|\s+$//g;
	    my @vals = ( $host_name{$host}, $host_name{$parent} );
	    $result = StorProc->insert_obj( 'host_parent', \@vals );
	    if ( $result =~ /Error/ ) { update_status( 'error', $result ) }
	}
    }

    # template parents
    if (%template_parents) {
	update_status( 'info', "Setting parents from templates to hosts ..." );
	foreach my $temp ( keys %template_parents ) {
	    my @parents = split( /,/, $template_parents{$temp}{'parents'} );
	    delete $template_parents{$temp}{'parents'};
	    foreach my $parent (@parents) {
		$parent =~ s/^\s+|\s+$//g;
		foreach my $host ( @{ $template_parents{$temp}{'hosts'} } ) {
		    my $hid = $template_parents{$temp}{$host};
		    my @vals = ( $host, $host_name{$parent} );
		    $result = StorProc->insert_obj( 'host_parent', \@vals );
		    if ( $result =~ /Error/ ) { update_status( 'error', $result ) }
		}
	    }
	}
    }

    # redundant templates
    if (%redundant_templates) {
	update_status( 'info', "Removing redundant templates ..." );
	foreach my $temp ( keys %redundant_templates ) {
	    StorProc->delete_all( 'host_templates', 'name', $temp );
	}
    }
    StorProc->delete_one_where( 'stage_other', \%where );

    # host dependency
    update_status( 'info', 'Loading host dependencies ...' );
    StorProc->truncate_table('host_dependencies');
    %where = ( 'type' => 'hostdependency' );
    %objects = StorProc->fetch_list_hash_array( 'stage_other', \%where );
    foreach my $key ( keys %objects ) {
	my %data = StorProc->parse_xml( $objects{$key}[3] );
	update_status( 'error', delete $data{'error'} ) if defined $data{'error'};
	my @hosts       = split( /,/, $data{'dependent_host_name'} );
	my @parents     = split( /,/, $data{'host_name'} );
	my %master_host = ();
	foreach my $host (@hosts) {
	    $host =~ s/^\s+|\s+$//g;
	    foreach my $parent (@parents) {
		$parent =~ s/^\s+|\s+$//g;
		$master_host{ $host_name{$host} } = $host_name{$parent};
	    }
	}
	my $data_xml = $xml_begin;
	foreach my $d ( keys %data ) {
	    if ( $d =~ /host_name/ ) { next }

	    # The Nagios docs say notification_failure_criteria and execution_failure_criteria but
	    # the Nagios code emits notification_failure_options and execution_failure_options when
	    # it writes a precached object file, for either a host or service dependency.  So we
	    # need to handle either case, to process robustly.
	    my $name = $d;
	    $name = 'notification_failure_criteria' if $name eq 'notification_failure_options';
	    $name = 'execution_failure_criteria'    if $name eq 'execution_failure_options';

	    $data_xml .= " <prop name=\"$name\"><![CDATA[$data{$d}]]>\n";
	    $data_xml .= " </prop>\n";
	}
	$data_xml .= $xml_end;
	foreach my $host ( keys %master_host ) {
	    my @values = ( $host, $master_host{$host}, $data_xml, $objects{$key}[4] );
	    $result = StorProc->insert_obj( 'host_dependencies', \@values );
	    if ( $result =~ /Error/ ) { update_status( 'error', $result ) }
	}
    }
    StorProc->delete_one_where( 'stage_other', \%where );

    # hostextinfo
    update_status( 'info', 'Loading host extended info ...' );
    %where = ( 'type' => 'hostextinfo' );
    %objects = StorProc->fetch_list_hash_array( 'stage_other', \%where );
    $index = StorProc->count('extended_host_info_templates');
    foreach my $key ( keys %objects ) {
	my @hosts   = ();
	my $hoststr = undef;
	my %data    = StorProc->parse_xml( $objects{$key}[3] );
	update_status( 'error', delete $data{'error'} ) if defined $data{'error'};
	if ( $objects{$key}[2] eq 'hostextinfo' ) {
	    @hosts = split( /,/, $data{'host_name'} );
	}
	else {
	    push @hosts, $objects{$key}[0];
	}
	if ( $data{'notes_url'} ) {
	    if ( $hosts[0] && $hosts[0] ne '?' ) {
		$data{'notes_url'} =~ s/$hosts[0]/\$HOSTNAME\$/g;
	    }
	    $data{'notes_url'} =~ s/\s/+/g;
	}
	unless ( $data{'use'} ) {
	    my $props = 0;
	    foreach ( keys %data ) { $props++ }
	    if ( $data{'host_name'} ) { $props -= 1 }
	    if ( $data{'notes_url'} ) { $props -= 1 }
	    if ( $data{'2d_coords'} ) { $props -= 1 }
	    if ( $data{'3d_coords'} ) { $props -= 1 }
	    my %gotmatch = ();
	    foreach my $temp ( keys %hostextinfo_templates ) {
		foreach my $d ( keys %data ) {
		    if ( $d =~ /d_coords|host_name/ ) { next }
		    if ( $data{$d} eq $hostextinfo_templates{$temp}{$d} ) {
			$gotmatch{$temp} += 1;
		    }
		}
	    }
	    my $match = undef;
	    my $best  = 0;
	    foreach my $key ( keys %gotmatch ) {
		if ( $gotmatch{$key} > $best ) {
		    $match = $key;
		    $best  = $gotmatch{$key};
		}
	    }
	    if ( $gotmatch{$match} >= $props ) { $data{'use'} = $match }
	    unless ( $data{'use'} ) {
		my $data_xml = $xml_begin;
		foreach my $d ( keys %data ) {
		    if ( $d =~ /host_name/ ) { next }
		    $data_xml .= " <prop name=\"$d\"><![CDATA[$data{$d}]]>\n";
		    $data_xml .= " </prop>\n";
		}
		$data_xml .= $xml_end;
		my $name = undef;
		if ( $data{'icon_image_alt'} ) {
		    $name = lc("$data{'icon_image_alt'}-$index");
		    $name =~ s/_|\s/-/g;
		}
		elsif ( $data{'icon_image'} ) {
		    $name = lc("$data{'icon_image'}-$index");
		    $name =~ s/_|\s|\./-/g;
		}
		elsif ( $data{'vrml_image'} ) {
		    $name = lc("$data{'vrml_image'}-$index");
		    $name =~ s/_|\s|\./-/g;
		}
		elsif ( $data{'statusmap_image'} ) {
		    $name = lc("$data{'statusmap_image'}-$index");
		    $name =~ s/_|\s|\./-/g;
		}
		else {
		    $name = "generic-hostextinfo-$index";
		}
		my $comment = undef;
		my @values = ( \undef, $name, $data_xml, '', $comment );
		$result = StorProc->insert_obj_id( 'extended_host_info_templates', \@values, 'hostextinfo_id' );
		if ( $result =~ /Error/ ) {
		    update_status( 'error', $result );
		}
		else {
		    $hostextinfo_templates{ $data{'use'} }{'id'} = $result;
		}
		$index++;
	    }
	}
	if ( $data{'2d_coords'} eq $hostextinfo_templates{ $data{'use'} }{'2d_coords'} ) {
	    delete $data{'2dcoords'};
	}
	if ( $data{'3d_coords'} eq $hostextinfo_templates{ $data{'use'} }{'3d_coords'} ) {
	    delete $data{'3dcoords'};
	}
	foreach my $host (@hosts) {
	    my %w = ( 'name'           => $host );
	    my %u = ( 'hostextinfo_id' => $hostextinfo_templates{ $data{'use'} }{'id'} );
	    StorProc->update_obj_where( 'hosts', \%u, \%w );
	    StorProc->delete_all( 'extended_info_coords', 'host_id', $host_name{$host} );
	    if ( $data{'2d_coords'} || $data{'3d_coords'} ) {
		my $data_xml = $xml_begin;
		foreach my $d ( keys %data ) {
		    if ( $d =~ /coords/ ) {
			$data_xml .= " <prop name=\"$d\"><![CDATA[$data{$d}]]>\n";
			$data_xml .= " </prop>\n";
		    }
		}
		$data_xml .= $xml_end;
		my @vals = ( $host_name{$host}, $data_xml );
		$result = StorProc->insert_obj( 'extended_info_coords', \@vals );
		if ( $result =~ /Error/ ) { update_status( 'error', $result ) }
	    }
	}
    }
    StorProc->delete_one_where( 'stage_other', \%where );

    # hostgroup templates
    update_status( 'info', "Removing hostgroup templates ..." );
    my %hostgroup_template = ();
    %where = ( 'type' => 'hostgroup_templates' );
    %objects = StorProc->fetch_list_hash_array( 'stage_other', \%where );
    foreach my $key ( keys %objects ) {
	my %data = StorProc->parse_xml( $objects{$key}[3] );
	update_status( 'error', delete $data{'error'} ) if defined $data{'error'};
	$hostgroup_template{ $objects{$key}[0] } = $data{'contact_groups'};
    }
    StorProc->delete_one_where( 'stage_other', \%where );

    # hostgroups
    $read = $updated = $imported = $new = 0;
    update_status( 'info', 'Loading hostgroups ...' );
    StorProc->truncate_table('hostgroup_host');
    %where = ( 'type' => 'hostgroup-host' );
    %objects = StorProc->fetch_list_hash_array( 'stage_other', \%where );
    foreach my $key ( keys %objects ) {
	$read++;
	my %data = StorProc->parse_xml( $objects{$key}[3] );
	update_status( 'error', delete $data{'error'} ) if defined $data{'error'};
	my @contactgroups = split( /,/, $data{'contact_groups'} );
	if ( $data{'use'} ) {
	    my @cguse = split( /,/, $hostgroup_template{ $data{'use'} } );
	    push( @contactgroups, @cguse );
	}
	if ( $hostgroup_name{ $objects{$key}[0] } ) {
	    $updated++;
	    my %values = ();
	    $values{'alias'}   = $objects{$key}[2];
	    $values{'comment'} = $objects{$key}[4];
	    StorProc->update_obj( 'hostgroups', 'name', $objects{$key}[0], \%values );
	}
	else {
	    $imported++;
	    ## FIX MAJOR NOW:  unxmlify the notes
	    ## FIX MAJOR NOW:  should have profile id here, too, instead of ''
	    ## FIX MAJOR NOW:  should have escalation ids here, too, instead of ''s
	    my @vals = ( \undef, $objects{$key}[0], $objects{$key}[2], '', '', '', '1', $objects{$key}[4], $data{'notes'} );
	    if ($gw4) {
		@vals = ( \undef, $objects{$key}[0], $objects{$key}[2], '', '', '1', $objects{$key}[4] );
	    }
	    $result = StorProc->insert_obj_id( 'hostgroups', \@vals, 'hostgroup_id' );
	    if ( $result =~ /Error/ ) {
		update_status( 'error', $result );
	    }
	    else {
		$hostgroup_name{ $objects{$key}[0] } = $result;
	    }
	}

	## my %w = ('type' => 'hostgroups','object' => $hostgroup_name{$objects{$key}[0]});
	## StorProc->delete_one_where('contactgroup_assign',\%w);
	my %w = ( 'hostgroup_id' => $hostgroup_name{ $objects{$key}[0] } );
	StorProc->delete_one_where( 'contactgroup_hostgroup', \%w );

	foreach my $cg (@contactgroups) {
	    $cg =~ s/^\s+|\s+$//g;
	    ## my @vals = ($contactgroup_name{$cg},'hostgroups',$hostgroup_name{$objects{$key}[0]});
	    ## StorProc->insert_obj('contactgroup_assign',\@vals);
	    my @vals = ( $contactgroup_name{$cg}, $hostgroup_name{ $objects{$key}[0] } );
	    $result = StorProc->insert_obj( 'contactgroup_hostgroup', \@vals );
	    if ( $result =~ /Error/ ) { update_status( 'error', $result ) }

	}
	if ( $data{'members'} eq '*' ) {
	    foreach my $mem ( keys %host_name ) {
		my @vals = ( $hostgroup_name{ $objects{$key}[0] }, $host_name{$mem} );
		$result = StorProc->insert_obj( 'hostgroup_host', \@vals );
		if ( $result =~ /Error/ ) { update_status( 'error', $result ) }
	    }
	}
	else {
	    my %members = ();
	    $data{'members'} =~ s/^\s+|\s+$//g;
	    my @mems = split( /,/, $data{'members'} );
	    foreach (@mems) { $members{$_} = 1 }
	    foreach my $mem ( keys %members ) {
		if ( $host_name{$mem} ) {
		    my @vals = ( $hostgroup_name{ $objects{$key}[0] }, $host_name{$mem} );
		    $result = StorProc->insert_obj( 'hostgroup_host', \@vals );
		    if ( $result =~ /Error/ ) { update_status( 'error', $result ) }
		}
		else {
		    update_status( 'info', "\"$mem\" is not a valid host, and so will be ignored." );
		}
	    }
	}
    }
    StorProc->delete_one_where( 'stage_other', \%where );
    update_status( 'info', "Hostgroups: $read read, $updated updated, $imported imported." );

    # hostgroups on hosts
    foreach my $host ( keys %host_hostgroup ) {
	my @hostgroups = split( /,/, $host_hostgroup{$host} );
	foreach my $hg (@hostgroups) {
	    $hg =~ s/^\s+|\s+$//g;
	    if ( $hostgroup_name{$hg} ) {
		my @vals = ( $hostgroup_name{$hg}, $host );
		$result = StorProc->insert_obj( 'hostgroup_host', \@vals );
		if ( $result =~ /Error/ ) { update_status( 'error', $result ) }
	    }
	    else {
		update_status( 'info', "\"$hg\" is not a valid hostgroup, and so will be ignored." );
	    }
	}
    }
    return @messages;
}

############################################################################
######
###### Break
######
############################################################################

# services

sub process_services() {
    my $read                         = 0;
    my $updated                      = 0;
    my $imported                     = 0;
    my %command_name                 = StorProc->get_table_objects('commands');
    my %timeperiod_name              = StorProc->get_table_objects('time_periods');
    my %contact_name                 = StorProc->get_table_objects('contacts');
    my %contactgroup_name            = StorProc->get_table_objects('contactgroups');
    my %service_name                 = StorProc->get_table_objects('service_names');
    my %host_templates               = StorProc->get_host_templates();
    my %hostextinfo_templates        = StorProc->get_hostextinfo_templates();  # FIX LATER:  not referenced anywhere
    my %host_name                    = StorProc->get_table_objects('hosts');
    my %hostgroup_name               = StorProc->get_table_objects('hostgroups');
    my %service_templates            = StorProc->get_service_templates();
    my %serviceextinfo_templates     = StorProc->get_serviceextinfo_templates();
    my %servicegroup_name            = StorProc->get_table_objects('servicegroups');
    my %service_dependency_templates = StorProc->get_service_dependency_templates('service_dependency_templates');
    my $result;
    local $_;

    # Set special * service
    unless ( $service_name{'*'} ) {
	my @values = ( \undef, '*', 'special use', '', '', '', '', '', "$xml_begin$xml_end" );
	if ($gw4) { pop @values }
	$result = StorProc->insert_obj_id( 'service_names', \@values, 'servicename_id' );
	if ( $result =~ /error/i ) {
	    update_status( 'error', $result );
	}
	else {
	    $service_name{'*'} = $result;
	}
    }

    # service templates
    update_status( 'info', 'Loading service templates ...' );
    my %where = ( 'type' => 'service_template' );
    my %objects               = StorProc->fetch_list_hash_array( 'stage_other', \%where );
    my %service_template_host = ();
    my %parents               = ();
    foreach my $key ( keys %objects ) {
	$read++;
	unless ( $objects{$key}[2] eq 'no-parent' ) {
	    $parents{ $objects{$key}[0] } = $objects{$key}[2];
	}
	my %data = StorProc->parse_xml( $objects{$key}[3] );
	update_status( 'error', delete $data{'error'} ) if defined $data{'error'};
	$service_templates{ $objects{$key}[0] }{'check_period'}        = $timeperiod_name{ $data{'check_period'} };
	$service_templates{ $objects{$key}[0] }{'notification_period'} = $timeperiod_name{ $data{'notification_period'} };
	$service_templates{ $objects{$key}[0] }{'check_command'}       = $command_name{ $data{'check_command'} };
	unless ($gw4) {
	    $service_templates{ $objects{$key}[0] }{'command_line'} = $data{'command_line'};
	}
	$service_templates{ $objects{$key}[0] }{'event_handler'} = $command_name{ $data{'event_handler'} };
	delete $data{'check_period'};
	delete $data{'notification_period'};
	delete $data{'check_command'};
	delete $data{'event_handler'};
	unless ($gw4) { delete $data{'command_line'} }
	if ( $data{'host_name'} ) {
	    $service_template_host{ $objects{$key}[0] }{'hosts'} = $data{'host_name'};
	}
	if ( $data{'hostgroup_name'} ) {
	    $service_template_host{ $objects{$key}[0] }{'hostgroups'} = $data{'hostgroup_name'};
	}
	delete $data{'host_name'};
	delete $data{'hostgroup_name'};
	my $data_xml = $xml_begin;
	foreach my $d ( keys %data ) {
	    if ( $d =~ /contact_groups/ ) { next }
	    $data_xml .= " <prop name=\"$d\"><![CDATA[$data{$d}]]>\n";
	    $data_xml .= " </prop>\n";
	}
	$data_xml .= $xml_end;
	if ( $service_templates{ $objects{$key}[0] }{'id'} ) {
	    $updated++;
	    my %values = ();
	    $values{'parent_id'}           = $service_templates{ $objects{$key}[0] }{'parent_id'};
	    $values{'check_period'}        = $service_templates{ $objects{$key}[0] }{'check_period'};
	    $values{'notification_period'} = $service_templates{ $objects{$key}[0] }{'notification_period'};
	    $values{'check_command'}       = $service_templates{ $objects{$key}[0] }{'check_command'};
	    unless ($gw4) {
		$values{'command_line'} = $service_templates{ $objects{$key}[0] }{'command_line'};
	    }
	    $values{'event_handler'} = $service_templates{ $objects{$key}[0] }{'event_handler'};
	    $values{'data'}          = $data_xml;
	    $values{'comment'}       = $objects{$key}[4];
	    StorProc->update_obj( 'service_templates', 'name', $objects{$key}[0], \%values );
	}
	else {
	    $imported++;
	    my @values = (
		\undef,                                                         $objects{$key}[0],
		'',                                                             $service_templates{ $objects{$key}[0] }{'check_period'},
		$service_templates{ $objects{$key}[0] }{'notification_period'}, $service_templates{ $objects{$key}[0] }{'check_command'},
		$service_templates{ $objects{$key}[0] }{'command_line'},        $service_templates{ $objects{$key}[0] }{'event_handler'},
		$data_xml,                                                      $objects{$key}[4]
	    );
	    if ($gw4) {
		@values = (
		    \undef,                                                         $objects{$key}[0],
		    '',                                                             $service_templates{ $objects{$key}[0] }{'check_period'},
		    $service_templates{ $objects{$key}[0] }{'notification_period'}, $service_templates{ $objects{$key}[0] }{'check_command'},
		    $service_templates{ $objects{$key}[0] }{'event_handler'},       $data_xml,
		    $objects{$key}[4]
		);
	    }
	    $result = StorProc->insert_obj_id( 'service_templates', \@values, 'servicetemplate_id' );
	    if ( $result =~ /error/i ) {
		update_status( 'error', $result );
	    }
	    else {
		$service_templates{ $objects{$key}[0] }{'id'} = $result;
	    }
	}

	## my %w = ('type' => 'service_templates','object' => $service_templates{$objects{$key}[0]}{'id'});
	## StorProc->delete_one_where('contactgroup_assign',\%w);
	my %w = ( 'servicetemplate_id' => $service_templates{ $objects{$key}[0] }{'id'} );
	StorProc->delete_one_where( 'contactgroup_service_template', \%w );

	my @members = split( /,/, $data{'contact_groups'} );
	foreach my $mem (@members) {
	    $mem =~ s/^\s+|\s+$//g;
	    unless ( $contactgroup_name{$mem} ) {
		update_status( 'error', "Contact group $mem does not exist for service template $objects{$key}[0]" );
	    }
	    else {
		## my @vals = ($contactgroup_name{$mem},'service_templates',$service_templates{$objects{$key}[0]}{'id'});
		## StorProc->insert_obj('contactgroup_assign',\@vals);
		my @vals = ( $contactgroup_name{$mem}, $service_templates{ $objects{$key}[0] }{'id'} );
		$result = StorProc->insert_obj( 'contactgroup_service_template', \@vals );
		if ( $result =~ /error/i ) {
		    update_status( 'error', $result );
		}
	    }
	}
    }
    StorProc->delete_one_where( 'stage_other', \%where );
    update_status( 'info', "Service templates: $read read, $updated updated, $imported imported." );

    foreach my $temp ( keys %parents ) {
	my %values = ( 'parent_id' => $service_templates{ $parents{$temp} }{'id'} );
	StorProc->update_obj( 'service_templates', 'name', $temp, \%values );
    }

    %service_templates = StorProc->get_service_templates();

    # service names
    $read = $updated = $imported = 0;
    update_status( 'info', "Creating service names ..." );
    my $index = 1;
    %where = ( 'type' => 'service' );
    %objects = StorProc->fetch_list_hash_array( 'stage_other', \%where );
    my %sn_use     = ();
    my %sn_cmd     = ();
    my %sn_cmdline = ();
    my %sn_dep     = ();
    foreach my $key ( sort keys %objects ) {
	$objects{$key}[0] =~ s/^\s+|\s+$//g;
	unless ( $service_name{ $objects{$key}[0] } ) {
	    $read++;
	    my %data = StorProc->parse_xml( $objects{$key}[3] );
	    update_status( 'error', delete $data{'error'} ) if defined $data{'error'};
	    $sn_cmd{ $objects{$key}[0] }     = $command_name{ $data{'check_command'} };
	    $sn_cmdline{ $objects{$key}[0] } = $data{'command_line'};
	    my $props = 0;
	    delete $data{'host_name'};
	    delete $data{'hostgroup_name'};
	    delete $data{'file_name'};
	    my @cgs = split( /,/, $data{'contact_groups'} );
	    my %contactgroups = ();

	    foreach my $cg (@cgs) {
		$cg =~ s/^\s+|\s+$//g;
		$contactgroups{$cg} = $contactgroup_name{$cg};
	    }
	    if ( $data{'check_period'} ) {
		if ( $timeperiod_name{ $data{'check_period'} } ) {
		    $data{'check_period'} = $timeperiod_name{ $data{'check_period'} };
		}
		else {
		    my $tname = $data{'check_period'};
		    update_status( 'error',
			"Time period $data{'check_period'} is specified for service \"$objects{$key}[0]\" but no such time period exists." );
		    my @values = ( \undef, $data{'check_period'}, '', $xml_begin . $xml_end, '' );
		    $result = StorProc->insert_obj_id( 'time_periods', \@values, 'timeperiod_id' );
		    if ( $result =~ /error/i ) {
			update_status( 'error', $result );
		    }
		    else {
			$timeperiod_name{ $data{'check_period'} } = $result;
		    }
		    $data{'check_period'} = $timeperiod_name{ $data{'check_period'} };
		    update_status( 'warning',
"Added time period $tname but properties have not been set. WARNING: You must set the properties before attempting preflight or commit!"
		    );
		}
	    }
	    if ( $data{'notification_period'} ) {
		if ( $timeperiod_name{ $data{'notification_period'} } ) {
		    $data{'notification_period'} = $timeperiod_name{ $data{'notification_period'} };
		}
		else {
		    my $tname = $data{'notification_period'};
		    update_status( 'error',
"Time period $data{'notification_period'} is specified for service \"$objects{$key}[0]\" but no such time period exists."
		    );
		    my @values = ( \undef, $data{'check_period'}, '', $xml_begin . $xml_end, '' );
		    $result = StorProc->insert_obj_id( 'time_periods', \@values, 'timeperiod_id' );
		    if ( $result =~ /error/i ) {
			update_status( 'error', $result );
		    }
		    else {
			$timeperiod_name{ $data{'notification_period'} } = $result;
		    }
		    $data{'notification_period'} = $timeperiod_name{ $data{'notification_period'} };
		    update_status( 'warning',
"Added time period $tname but properties have not been set. WARNING: You must set the properties before attempting preflight or commit!"
		    );
		}
	    }
	    if ( $data{'check_command'} ) {
		if ( $command_name{ $data{'check_command'} } ) {
		    $data{'check_command'} = $command_name{ $data{'check_command'} };
		}
		else {
		    my $tname = $data{'check_command'};
		    update_status( 'error',
"Check command $data{'check_command'} is specified for service \"$objects{$key}[0]\" but no such command definition exists."
		    );
		    my @values = ( \undef, $data{'check_period'}, '', $xml_begin . $xml_end, '' );
		    $result = StorProc->insert_obj_id( 'commands', \@values, 'command_id' );
		    if ( $result =~ /error/i ) {
			update_status( 'error', $result );
		    }
		    else {
			$command_name{ $data{'check_command'} } = $result;
		    }
		    $data{'check_command'} = $command_name{ $data{'check_command'} };
		    update_status( 'warning',
"Added check command $tname but properties have not been set. WARNING: You must set the properties before attempting preflight or commit!"
		    );
		}
	    }
	    unless ( $data{'use'} ) {
		my $bestmatch = 0;
		unless (%service_templates) {
		    update_status( 'note', "No service templates exist and at least one is required." );
		    my $data = $xml_begin . $xml_end;
		    my @values = ( \undef, 'default-service', '', '', '', '', '', '', $data, '' );
		    $result = StorProc->insert_obj_id( 'service_templates', \@values, 'servicetemplate_id' );
		    if ( $result =~ /error/i ) {
			update_status( 'error', $result );
		    }
		    else {
			$service_templates{'default-service'}{'id'} = $result;
		    }
		    $data{'use'} = 'default-service';
		    update_status( 'warning',
"Added service template 'default-service' but properties have not been set. WARNING: You must set the properties before attempting preflight or commit!"
		    );
		}
		else {
		    foreach my $temp ( keys %service_templates ) {
			my %template   = %{ $service_templates{$temp} };
			my %super_temp = ();
			@{ $super_temp{'contactgroups'} } = ();
			my $got_parent   = 0;
			my %already_seen = ();
			until ($got_parent) {
			    foreach my $t ( keys %template ) {
				unless ( exists $super_temp{$t} ) {
				    $super_temp{$t} = $template{$t};
				}
			    }
			    $already_seen{ $template{'id'} } = 1;
			    $got_parent = 1;
			    if ( $template{'parent_id'} && !$already_seen{ $template{'parent_id'} } ) {
				foreach my $key ( keys %service_templates ) {
				    if ( $template{'parent_id'} eq $service_templates{$key}{'id'} ) {
					%template   = %{ $service_templates{$key} };
					$got_parent = 0;
					last;
				    }
				}
			    }
			}
			foreach my $t ( keys %super_temp ) {
			    my $gotmatch = 0;
			    foreach my $d ( keys %data ) {
				if ( $d =~ /period/ ) {
				    if ( $timeperiod_name{ $data{$d} } eq $super_temp{$d} ) {
					$gotmatch++;
				    }
				}
				elsif ( $d =~ /command|handler/ ) {
				    if ( $command_name{ $data{$d} } eq $super_temp{$d} ) {
					$gotmatch++;
				    }
				}
				else {
				    if ( $data{$d} eq $super_temp{$d} ) {
					$gotmatch++;
				    }
				}
			    }
			    foreach my $cg ( keys %contactgroups ) {
				foreach my $cid ( @{ $super_temp{'contactgroups'} } ) {
				    if ( $cid eq $contactgroups{$cg} ) {
					$gotmatch++;
				    }
				}
			    }
			    if ( $gotmatch > $bestmatch ) {
				$bestmatch = $gotmatch;
				$data{'use'} = $temp;
			    }
			}
		    }
		}
	    }
	    unless ( $service_templates{ $data{'use'} }{'id'} ) {
		update_status( 'error', "Service $objects{$key}[0] specifies template $data{'use'} but no such template exists." );
		my $data = $xml_begin . $xml_end;
		my @values = ( \undef, $data{'use'}, '', '', '', '', '', '', $data, '' );
		$result = StorProc->insert_obj_id( 'service_templates', \@values, 'servicetemplate_id' );
		if ( $result =~ /error/i ) {
		    update_status( 'error', $result );
		}
		else {
		    $service_templates{ $data{'use'} }{'id'} = $result;
		}
		update_status( 'warning',
"Added service template $data{'use'} but properties have not been set. WARNING: You must set the properties before attempting preflight or commit!"
		);
	    }
	    $imported++;
	    my $samesame = 0;
	    foreach my $sname ( keys %service_name ) {
		if ( $sname =~ /^$objects{$key}[0]$/i ) {
		    $service_name{ $objects{$key}[0] } = $service_name{$sname};
		}
	    }
	    unless ( $service_name{ $objects{$key}[0] } ) {
		$sn_use{ $objects{$key}[0] } = $data{'use'};
		my @values = (
		    \undef, $objects{$key}[0], $objects{$key}[0],
		    $service_templates{ $data{'use'} }{'id'},
		    $sn_cmd{ $objects{$key}[0] },
		    $sn_cmdline{ $objects{$key}[0] },
		    '', '', "$xml_begin$xml_end"
		);
		if ($gw4) { pop @values }
		$result = StorProc->insert_obj_id( 'service_names', \@values, 'servicename_id' );
		if ( $result =~ /error/i ) {
		    update_status( 'error', $result );
		}
		else {
		    $service_name{ $objects{$key}[0] } = $result;
		}
		if ( $debug && $service_name{ $objects{$key}[0] } =~ /error/i ) {
		    update_status( 'error', "$service_name{$objects{$key}[0]}" );
		}
	    }
	}

    }
    update_status( 'info', "New service definitions: $imported imported." );

    # services
    $read = $updated = $imported = 0;
    update_status( 'info', 'Loading services ...' );
    my %use_regex      = StorProc->fetch_one( 'stage_other', 'name', 'use_regex' );
    my %host_services  = ();
    my %hosts_services = StorProc->get_hostid_servicenameid_serviceid();
    my %service_groups = ();
    my %services       = StorProc->get_staged_services();
    foreach my $key ( sort keys %services ) {
	$read++;
	my %hosts = ();
	if ( $services{$key}{'hostgroup_name'} ) {
	    my @hostgroups = split( /,/, $services{$key}{'hostgroup_name'} );
	    foreach my $hg (@hostgroups) {
		$hg =~ s/^\s+|\s+$//g;
		my %w = ( 'hostgroup_id' => $hostgroup_name{$hg} );
		my @hosts = StorProc->fetch_list_where( 'hostgroup_host', 'host_id', \%w );
		foreach (@hosts) { $hosts{$_} = 1 }
	    }
	}
	if ( $service_template_host{ $services{$key}{'use'} }{'hosts'} ) {
	    my @hostnames = split( /,/, $service_template_host{ $services{$key}{'use'} }{'hosts'} );
	    foreach my $hn (@hostnames) {
		$hn =~ s/^\s+|\s+$//g;
		foreach my $host ( keys %host_name ) {
		    if ( $host =~ /^$hn$/i ) { $hosts{ $host_name{$host} } = 1 }
		}
	    }
	}
	if ( $service_template_host{ $services{$key}{'use'} }{'hostgroups'} ) {
	    my @hostgroups = split( /,/, $service_template_host{ $services{$key}{'use'} }{'hostgroups'} );
	    foreach my $hg (@hostgroups) {
		$hg =~ s/^\s+|\s+$//g;
		my %w = ( 'hostgroup_id' => $hostgroup_name{$hg} );
		my @hosts = fetch_list_where( 'hostgroup_host', 'host_id', \%w );
		foreach (@hosts) { $hosts{$_} = 1 }
	    }
	}
	if ( $services{$key}{'host_name'} eq '*' ) {
	    foreach my $h ( keys %host_name ) {
		$hosts{ $host_name{$h} } = $host_name{$h};
	    }
	}
	else {
	    my @hostnames = split( /,/, $services{$key}{'host_name'} );
	    foreach my $hn (@hostnames) {
		$hn =~ s/^\s+|\s+$//g;
		foreach my $host ( keys %host_name ) {
		    if ( $host =~ /^$hn$/i ) { $hosts{ $host_name{$host} } = 1 }
		}
	    }
	}
	my %values = ();
	$values{'servicename_id'}     = $service_name{ $services{$key}{'name'} };
	$values{'servicetemplate_id'} = $service_templates{ $services{$key}{'use'} }{'id'};
	$values{'check_command'}      = $command_name{ $services{$key}{'check_command'} };
	$values{'command_line'}       = $services{$key}{'command_line'};
	$values{'comment'}            = $services{$key}{'comment'};
	$values{'notes'}              = $services{$key}{'notes'};
	my $got_parent = 0;
	my %template   = %{ $service_templates{ $services{$key}{'use'} } };
	my %super_temp = ();
	@{ $super_temp{'contactgroups'} } = ();
	%super_temp = %template;
	my %already_seen = ();
	until ($got_parent) {
	    foreach my $t ( keys %template ) {
		unless ( exists $super_temp{$t} ) {
		    $super_temp{$t} = $template{$t};
		}
	    }
	    $already_seen{ $template{'id'} } = 1;
	    $got_parent = 1;
	    if ( $template{'parent_id'} && !$already_seen{ $template{'parent_id'} } ) {
		foreach my $key ( keys %service_templates ) {
		    if ( $template{'parent_id'} eq $service_templates{$key}{'id'} ) {
			%template   = %{ $service_templates{$key} };
			$got_parent = 0;
			last;
		    }
		}
	    }
	}
	my %overrides = ();
	if (   $timeperiod_name{ $services{$key}{'check_period'} }
	    && $timeperiod_name{ $services{$key}{'check_period'} } ne $super_temp{'check_period'} )
	{
	    $overrides{'check_period'} = $timeperiod_name{ $services{$key}{'check_period'} };
	}
	if (   $timeperiod_name{ $services{$key}{'notification_period'} }
	    && $timeperiod_name{ $services{$key}{'notification_period'} } ne $super_temp{'notification_period'} )
	{
	    $overrides{'notification_period'} = $timeperiod_name{ $services{$key}{'notification_period'} };
	}
	if (   $command_name{ $services{$key}{'event_handler'} }
	    && $command_name{ $services{$key}{'event_handler'} } ne $super_temp{'event_handler'} )
	{
	    $overrides{'event_handler'} = $command_name{ $services{$key}{'event_handler'} };
	}
	if ( $services{$key}{'use'} ) {
	    unless ( $service_templates{ $services{$key}{'use'} }{'id'} ) {
		update_status( 'error',
"Service template $services{$key}{'use'} for service $services{$key}{'name'} does not exist. Template $sn_use{$services{$key}{'name'}} assigned."
		);
		$services{$key}{'use'} = $sn_use{ $services{$key}{'name'} };
	    }
	}
	else {
	    $services{$key}{'use'} = $sn_use{ $services{$key}{'name'} };
	}
	delete $services{$key}{'hostgroup_name'};
	delete $services{$key}{'host_name'};
	delete $services{$key}{'use'};
	delete $services{$key}{'check_period'};
	delete $services{$key}{'notification_period'};
	delete $services{$key}{'event_handler'};
	delete $services{$key}{'use'};
	delete $services{$key}{'host_name'};
	delete $services{$key}{'check_command'};
	delete $services{$key}{'command_line'};
	delete $services{$key}{'comment'};
	my $data_xml = undef;

	foreach my $d ( keys %{ $services{$key} } ) {
	    unless ( $d =~ /contact_groups|file_name|servicegroups|^name$/ || $services{$key}{$d} eq $super_temp{$d} ) {
		$data_xml .= " <prop name=\"$d\"><![CDATA[$services{$key}{$d}]]>\n";
		$data_xml .= " </prop>\n";
	    }
	}
	if ($data_xml) { $data_xml = $xml_begin . $data_xml . $xml_end }
	my @cg_overrides = ();
	if ( $services{$key}{'contact_groups'} ) {
	    my %tcgs = ();
	    foreach my $mem ( @{ $super_temp{'contactgroups'} } ) {
		$tcgs{$mem} = 1;
	    }
	    my @cgs = split( /,/, $services{$key}{'contact_groups'} );
	    foreach my $cg (@cgs) {
		$cg =~ s/^\s+|\s+$//g;
		unless ( $tcgs{ $contactgroup_name{$cg} } ) {
		    push @cg_overrides, $contactgroup_name{$cg};
		}
	    }
	}
	foreach my $hostid ( keys %hosts ) {
	    my $service_id = $hosts_services{$hostid}{ $service_name{ $services{$key}{'name'} } };
	    if ($service_id) {
		$updated++;
		StorProc->update_obj( 'services', 'service_id', $service_id, \%values );
	    }
	    else {
		$imported++;
		## FIX MAJOR NOW:  unxmlify the notes
		my @vals = (
		    \undef, $hostid,
		    $values{'servicename_id'},
		    $values{'servicetemplate_id'},
		    '', '', '1', $values{'check_command'},
		    $values{'command_line'}, $values{'comment'}, $values{'notes'}
		);
		$result = StorProc->insert_obj_id( 'services', \@vals, 'service_id' );
		if ( $result =~ /error/i ) {
		    update_status( 'error', $result );
		}
		else {
		    $service_id = $result;
		}
	    }

	    # Service overrides
	    StorProc->delete_all( 'service_overrides', 'service_id', $service_id );
	    if (   $overrides{'check_period'}
		|| $overrides{'notification_period'}
		|| $overrides{'event_handler'}
		|| $data_xml )
	    {
		my @values =
		  ( $service_id, $overrides{'check_period'}, $overrides{'notification_period'}, $overrides{'event_handler'}, $data_xml );
		$result = StorProc->insert_obj( 'service_overrides', \@values );
		if ( $debug && $result =~ /error/i ) {
		    update_status( 'error', $result );
		}
	    }

	    ## do we still need this delete?
	    ## my %w = ('type' => 'services','object' => $service_id);
	    ## StorProc->delete_one_where('contactgroup_assign',\%w);
	    my %w = ( 'service_id' => $service_id );
	    StorProc->delete_one_where( 'contactgroup_service', \%w );

	    my %cg_assigned = ();
	    foreach my $mem (@cg_overrides) {
		unless ( $cg_assigned{$hostid}{$mem} ) {
		    ## my @vals = ($mem,'services',$service_id);
		    ## $result = StorProc->insert_obj('contactgroup_assign',\@vals);
		    my @vals = ( $mem, $service_id );
		    $result = StorProc->insert_obj( 'contactgroup_service', \@vals );
		    if ( $debug && $result =~ /error/i ) {
			update_status( 'error', $result );
		    }
		    $cg_assigned{$hostid}{$mem} = 1;
		}
	    }
	    $host_services{$hostid}{ $services{$key}{'name'} } = $service_id;
	    if ( $services{$key}{'servicegroups'} ) {
		$service_groups{$hostid}{$service_id} = $services{$key}{'servicegroups'};
	    }
	}

    }
    StorProc->delete_one_where( 'stage_other', \%where );
    update_status( 'info', "Services to hosts: $read read, $updated updated, $imported imported." );

    # servicegroups
    $read = $updated = $imported = 0;
    update_status( 'info', 'Loading servicegroups ...' );
    StorProc->truncate_table('servicegroup_service');
    %where = ( 'type' => 'servicegroup' );
    %objects = StorProc->fetch_list_hash_array( 'stage_other', \%where );
    foreach my $key ( keys %objects ) {
	$read++;
	my %data = StorProc->parse_xml( $objects{$key}[3] );
	update_status( 'error', delete $data{'error'} ) if defined $data{'error'};
	my @members = split( /,/, $data{'members'} );
	if ( $servicegroup_name{ $objects{$key}[0] } ) {
	    $updated++;
	    my %values = ();
	    $values{'alias'} = $objects{$key}[2];
	    StorProc->update_obj( 'servicegroups', 'name', $objects{$key}[0], \%values );
	}
	else {
	    ## FIX MAJOR NOW:  unxmlify the notes
	    ## FIX MAJOR NOW:  should have escalation id here, too, instead of ''
	    my @vals = ( \undef, $objects{$key}[0], $objects{$key}[2], '', $objects{$key}[4], $data{'notes'} );
	    $result = StorProc->insert_obj_id( 'servicegroups', \@vals, 'servicegroup_id' );
	    if ( $result =~ /error/i ) {
		update_status( 'error', $result );
	    }
	    else {
		$servicegroup_name{ $objects{$key}[0] } = $result;
		$imported++;
	    }
	}
	if ( $servicegroup_name{ $objects{$key}[0] } ) {
	    my @services = ();
	    my @hosts    = ();
	    my $pairs    = 0;
	    my $i        = 0;
	    foreach my $m (@members) {
		$m =~ s/^\s+|\s+$//g;
		if ( $i == 1 ) {
		    push @services, $m;
		    $i = 0;
		}
		else {
		    push @hosts, $m;
		    $i = 1;
		    $pairs++;
		}
	    }
	    for ( $i = 0 ; $i <= $pairs ; $i++ ) {
		if (   $host_name{ $hosts[$i] }
		    && $host_services{ $host_name{ $hosts[$i] } }{ $services[$i] } )
		{
		    my @vals = (
			$servicegroup_name{ $objects{$key}[0] },
			$host_name{ $hosts[$i] },
			$host_services{ $host_name{ $hosts[$i] } }{ $services[$i] }
		    );
		    $result = StorProc->insert_obj( 'servicegroup_service', \@vals );
		    if ( $result =~ /error/i ) {
			update_status( 'error', $result );
		    }
		}
	    }
	}
    }
    StorProc->delete_one_where( 'stage_other', \%where );
    update_status( 'info', "Service groups: $read read, $updated updated, $imported imported." );

    foreach my $hostid ( keys %service_groups ) {
	foreach my $service_id ( keys %{ $service_groups{$hostid} } ) {
	    my @servicegroups =
	      split( /,/, $service_groups{$hostid}{$service_id} );
	    foreach my $sg (@servicegroups) {
		$sg =~ s/^\s+|\s+$//g;
		my @vals = ( $servicegroup_name{$sg}, $hostid, $service_id );
		$result = StorProc->insert_obj( 'servicegroup_service', \@vals );
		if ( $result =~ /error/i ) {
		    update_status( 'error', $result );
		}
	    }
	}
    }

############################################################################
######
###### Break
######
############################################################################

    # service dependency templates

    update_status( 'info', 'Loading service dependency templates ...' );
    my %temp_no_desc = ();
    %where = ( 'type' => 'servicedependency_template' );
    %objects = StorProc->fetch_list_hash_array( 'stage_other', \%where );
    foreach my $key ( keys %objects ) {
	$read++;
	my %data = StorProc->parse_xml( $objects{$key}[3] );
	update_status( 'error', delete $data{'error'} ) if defined $data{'error'};
	unless ( $data{'service_description'} ) {
	    $temp_no_desc{ $objects{$key}[0] } = 1;
	    $data{'service_description'} = '*';
	}
	unless ( $service_name{ $data{'service_description'} } ) {
	    my @values = ( \undef, $data{'service_description'}, $data{'service_description'}, '0', '0', '0', '', '', "$xml_begin$xml_end" );
	    if ($gw4) { pop @values }
	    $result = StorProc->insert_obj_id( 'service_names', \@values, 'servicename_id' );
	    if ( $result =~ /error/i ) {
		update_status( 'error', $result );
	    }
	    else {
		$service_name{ $data{'service_description'} } = $result;
	    }
	    update_status( 'note',
		"Service name $data{'service_description'} does not exist and is required for dependency template $objects{$key}[0]." );
	    update_status( 'warning',
		"Service name $data{'service_description'} added for dependency template $objects{$key}[0]. Advise you check properties." );
	}
	my $data_xml = $xml_begin;
	foreach my $d ( keys %data ) {
	    if ( $d =~ /notification|execution/ ) {
		$data_xml .= " <prop name=\"$d\"><![CDATA[$data{$d}]]>\n";
		$data_xml .= " </prop>\n";
	    }
	}
	$data_xml .= $xml_end;
	if ( $service_dependency_templates{ $objects{$key}[0] }{'id'} ) {
	    $updated++;
	    my %values = ( 'data' => $data_xml );
	    StorProc->update_obj( 'service_dependency_templates', 'name', $objects{$key}[0], \%values );
	}
	else {
	    $imported++;
	    my @vals = ( \undef, $objects{$key}[0], $service_name{ $data{'service_description'} }, $data_xml, $objects{$key}[4] );
	    $result = StorProc->insert_obj_id( 'service_dependency_templates', \@vals, 'id' );
	    if ( $result =~ /error/i ) {
		update_status( 'error', $result );
	    }
	    else {
		$service_dependency_templates{ $objects{$key}[0] }{'id'} = $result;
	    }
	}
    }
    StorProc->delete_one_where( 'stage_other', \%where );
    update_status( 'info', "Service dependency templates: $read read, $updated updated, $imported imported." );

    # service dependency
    $read = $updated = $imported = 0;
    update_status( 'info', 'Loading service dependencies ...' );
    StorProc->truncate_table('service_dependency');
    %where = ( 'type' => 'servicedependency' );
    %objects = StorProc->fetch_list_hash_array( 'stage_other', \%where );
    $index = StorProc->count('service_dependency_templates');
    foreach my $key ( keys %objects ) {
	$read++;
	my %data = StorProc->parse_xml( $objects{$key}[3] );
	update_status( 'error', delete $data{'error'} ) if defined $data{'error'};
	my $props = 0;

	# The Nagios docs say notification_failure_criteria and execution_failure_criteria but
	# the Nagios code emits notification_failure_options and execution_failure_options when
	# it writes a precached object file, for either a host or service dependency.  So we
	# need to handle either case, to process robustly.
	$data{'notification_failure_criteria'} = $data{'notification_failure_options'} if !$data{'notification_failure_criteria'};
	$data{'execution_failure_criteria'}    = $data{'execution_failure_options'}    if !$data{'execution_failure_criteria'};

	my @notify  = split( /,/, $data{'notification_failure_criteria'} );
	my @execute = split( /,/, $data{'execution_failure_criteria'} );
	foreach (@notify)  { $props++ }
	foreach (@execute) { $props++ }
	# FIX THIS:  it's not at all clear what counting the existence of notification_failure_criteria has
	# to do with the rest of the matching going on in this section of code.  It looks like a hack to me.
	if ( $data{'notification_failure_criteria'} ) { $props++ }

	if ( $temp_no_desc{ $data{'use'} } && $data{'service_description'} ) {
	    my %values = ( 'servicename_id' => $service_name{ $data{'use'} } );
	    StorProc->update_obj( 'service_dependency_templates', 'servicename_id', \%values );
	    delete $temp_no_desc{ $data{'use'} };
	}

	unless ( $data{'use'} ) {
	    foreach my $temp ( keys %service_dependency_templates ) {
		my $gotmatch = 0;
		if ( $service_name{ $data{'service_description'} } eq $service_dependency_templates{$temp}{'servicename_id'} ) {
		    $gotmatch++;
		}
		my %tv      = ();
		my @e_temp  = split( /,/, $service_dependency_templates{$temp}{'execution_failure_criteria'} );
		my @execute = split( /,/, $data{'execution_failure_criteria'} );
		foreach my $e (@e_temp) { $tv{$e} = 1 }
		foreach my $e (@execute) {
		    $e =~ s/^\s+|\s+$//g;
		    if ( $tv{$e} ) { $gotmatch++; }
		}
		%tv = ();
		my @n_temp = split( /,/, $service_dependency_templates{$temp}{'notification_failure_criteria'} );
		foreach my $n (@n_temp) { $tv{$n} = 1 }
		foreach my $n (@notify) {
		    $n =~ s/^\s+|\s+$//g;
		    if ( $tv{$n} ) { $gotmatch++ }
		}
		if ( $gotmatch == $props ) {
		    $data{'use'} = $temp;
		    last;
		}
	    }
	}
	unless ( $data{'use'} ) {
	    my $name = $data{'service_description'};
	    $name =~ s/_/-/g;
	    $name = "dep-$name-n-$data{'notification_failure_criteria'}-e-$data{'execution_failure_criteria'}";
	    $name =~ s/,//g;
	    my $data_xml = $xml_begin;
	    foreach my $d ( keys %data ) {
		unless ( $d =~ /^use$|service_description$|host_name/ ) {
		    $service_dependency_templates{$name}{$d} = $data{$d};
		    $data_xml .= " <prop name=\"$d\"><![CDATA[$data{$d}]]>\n";
		    $data_xml .= " </prop>\n";
		}
	    }
	    $data_xml .= $xml_end;
	    $service_dependency_templates{$name}{'servicename_id'} = $service_name{ $data{'service_description'} };
	    my @vals = ( \undef, $name, $service_name{ $data{'service_description'} }, $data_xml, $objects{$key}[4] );
	    $result = StorProc->insert_obj_id( 'service_dependency_templates', \@vals, 'id' );
	    if ( $result =~ /Error/i ) {
		update_status( 'error', $result );
	    }
	    else {
		$service_dependency_templates{$name}{'id'} = $result;
	    }
	    $data{'use'} = $name;
	}
	my @dhn = split( /,/, $data{'dependent_host_name'} );
	my @dependent_hosts = ();
	foreach my $dhn (@dhn) {
	    $dhn =~ s/^\s+|\s+$//g;
	    push @dependent_hosts, $host_name{$dhn};
	}
	my @mhn = split( /,/, $data{'host_name'} );
	my @master_hosts = ();
	foreach my $mhn (@mhn) {
	    $mhn =~ s/^\s+|\s+$//g;
	    push @master_hosts, $host_name{$mhn};
	}
	@dhn = split( /,/, $data{'dependent_hostgroup_name'} );
	foreach my $dhn (@dhn) {
	    $dhn =~ s/^\s+|\s+$//g;
	    my %w = ( 'hostgroup_id' => $hostgroup_name{$dhn} );
	    my @hids = fetch_list_where( 'hostgroup_host', 'host_id', \%w );
	    push( @dependent_hosts, @hids );
	}
	@mhn = split( /,/, $data{'hostgroup_name'} );
	foreach my $mhn (@mhn) {
	    $mhn =~ s/^\s+|\s+$//g;
	    my %w = ( 'hostgroup_id' => $hostgroup_name{$mhn} );
	    my @hids = fetch_list_where( 'hostgroup_host', 'host_id', \%w );
	    push( @master_hosts, @hids );
	}

	foreach my $dhn (@dependent_hosts) {
	    foreach my $mhn (@master_hosts) {
		$objects{$key}[0] =~ s/-\d+$//;
		if ( $host_services{$dhn}{ $objects{$key}[0] } ) {
		    $updated++;
		    if ( $dhn eq $mhn ) {
			$sn_dep{ $objects{$key}[0] }{'NULL'} = $service_dependency_templates{ $data{'use'} }{'id'};
		    }
		    else {
			$sn_dep{ $objects{$key}[0] }{$mhn} = $service_dependency_templates{ $data{'use'} }{'id'};
		    }
		    my @vals = (
			\undef, $host_services{$dhn}{ $objects{$key}[0] },
			$dhn, $mhn, $service_dependency_templates{ $data{'use'} }{'id'},
			$objects{$key}[4]
		    );
		    $result = StorProc->insert_obj( 'service_dependency', \@vals );
		    if ( $debug && $result =~ /error/i ) {
			update_status( 'error', $result );
		    }
		}
		else {
		    update_status( 'error', "service $objects{$key}[0] does not exist for dependency " );
		}
	    }
	}
    }
    StorProc->delete_one_where( 'stage_other', \%where );
    update_status( 'info', "Service dependencies: $read read, $updated updated, $imported imported." );

    # Update Service names
    $read = $updated = $imported = 0;
    update_status( 'info', "Updating services with dependency info ..." );
    foreach my $service ( keys %sn_dep ) {
	foreach my $mhn ( keys %{ $sn_dep{$service} } ) {
	    my @values = ( \undef, $service_name{$service}, $mhn, $sn_dep{$service}{$mhn} );
	    $result = StorProc->insert_obj( 'servicename_dependency', \@values );
	    if ( $debug && $result =~ /error/i ) {
		update_status( 'error', $result );
	    }
	}
    }

    # serviceextinfo templates
    update_status( 'info', 'Loading service extended info templates ...' );
    my %sn_extinfo = ();
    %where = ( 'type' => 'serviceextinfo_template' );
    %objects = StorProc->fetch_list_hash_array( 'stage_other', \%where );
    foreach my $key ( keys %objects ) {
	$read++;
	my %data = StorProc->parse_xml( $objects{$key}[3] );
	update_status( 'error', delete $data{'error'} ) if defined $data{'error'};
	foreach my $prop ( keys %data ) {
	    unless ( $data{'service_description'} ) {
		$serviceextinfo_templates{ $objects{$key}[0] }{$prop} = $data{$prop};
	    }
	}
	if ( $serviceextinfo_templates{ $objects{$key}[0] }{'id'} ) {
	    $updated++;
	    my %values = ();
	    $values{'data'}    = $objects{$key}[3];
	    $values{'comment'} = $objects{$key}[4];
	    StorProc->update_obj( 'extended_service_info_templates', 'name', $objects{$key}[0], \%values );
	}
	else {
	    $imported++;
	    my @values = ( \undef, $objects{$key}[0], $objects{$key}[3], '', $objects{$key}[4] );
	    $result = StorProc->insert_obj_id( 'extended_service_info_templates', \@values, 'serviceextinfo_id' );
	    if ( $result =~ /Error/i ) {
		update_status( 'error', $result );
	    }
	    else {
		$serviceextinfo_templates{ $objects{$key}[0] }{'id'} = $result;
	    }
	}
	if ( $data{'service_description'} ) {
	    $sn_extinfo{ $data{'service_description'} } = $serviceextinfo_templates{ $objects{$key}[0] }{'id'};
	}
    }
    StorProc->delete_one_where( 'stage_other', \%where );
    update_status( 'info', "Service extended info templates: $read read, $updated updated, $imported imported." );

    # Service extended info
    $read = $updated = $imported = 0;
    use URI::Escape;
    update_status( 'info', 'Loading service extended info ...' );
    %where = ( 'type' => 'serviceextinfo' );
    my %service_desc = ();
    %objects = StorProc->fetch_list_hash_array( 'stage_other', \%where );
    $index = StorProc->count('extended_service_info_templates');
    foreach my $key ( keys %objects ) {
	my %data = StorProc->parse_xml( $objects{$key}[3] );
	update_status( 'error', delete $data{'error'} ) if defined $data{'error'};
	if ( $data{'notes_url'} ) {
	    $data{'notes_url'} = uri_unescape( $data{'notes_url'} );
	    if ( $host_name{ $objects{$key}[2] } ) {
		$data{'notes_url'} =~ s/$objects{$key}[2]/\$HOSTNAME\$/g;
	    }
	    if ( $service_name{ $objects{$key}[0] } ) {
		$data{'notes_url'} =~ s/$objects{$key}[0]/\$SERVICENAME\$/g;
	    }
	    $data{'notes_url'} =~ s/\s/+/g;
	}
	if ( $data{'action_url'} ) {
	    $data{'action_url'} = uri_unescape( $data{'action_url'} );
	    if ( $host_name{ $objects{$key}[2] } ) {
		$data{'action_url'} =~ s/$objects{$key}[2]/\$HOSTNAME\$/g;
	    }
	    if ( $service_name{ $objects{$key}[0] } ) {
		$data{'action_url'} =~ s/$objects{$key}[0]/\$SERVICENAME\$/g;
	    }
	    $data{'action_url'} =~ s/\s/+/g;
	}
	unless ( $data{'use'} ) {
	    my $props = 0;
	    foreach ( keys %data ) { $props++ }
	    if ( $data{'host_name'} )           { $props -= 1 }
	    if ( $data{'service_description'} ) { $props -= 1 }
	    my %gotmatch = ();
	    foreach my $temp ( keys %serviceextinfo_templates ) {
		foreach my $d ( keys %data ) {
		    if ( $data{$d} eq $serviceextinfo_templates{$temp}{$d} ) {
			$gotmatch{$temp} += 1;
		    }
		}
	    }
	    my $match = undef;
	    my $best  = 0;
	    foreach my $key ( keys %gotmatch ) {
		if ( $gotmatch{$key} > $best ) {
		    $match = $key;
		    $best  = $gotmatch{$key};
		}
	    }
	    if ( $gotmatch{$match} == $props ) { $data{'use'} = $match }
	    $sn_extinfo{ $objects{$key}[0] } = $data{'use'};
	    unless ( $data{'use'} ) {
		my $name = undef;
		unless ( $service_desc{ $objects{$key}[0] } ) {
		    $name = lc("$objects{$key}[0]-$index");
		    $name =~ s/_|\s/-/g;
		    $service_desc{ $objects{$key}[0] } = 1;
		}
		elsif ( $data{'icon_image_alt'} ) {
		    $name = lc("$data{'icon_image_alt'}-$index");
		    $name =~ s/_|\s/-/g;
		}
		elsif ( $data{'icon_image'} ) {
		    $name = lc("$data{'icon_image'}-$index");
		    $name =~ s/_|\s|\./-/g;
		}
		else {
		    $name = "generic-serviceextinfo-$index";
		}
		my $data_xml = $xml_begin;
		foreach my $prop ( keys %data ) {
		    if ( $prop =~ /host_name/ ) { next }
		    $data_xml .= " <prop name=\"$prop\"><![CDATA[$data{$prop}]]>\n";
		    $data_xml .= " </prop>\n";
		    $serviceextinfo_templates{ $data{'use'} }{$prop} = $data{$prop};
		}
		$data_xml .= $xml_end;
		$data{'use'} = $name;
		my $comment = undef;
		my @values = ( \undef, $name, $data_xml, '', $comment );
		$result = StorProc->insert_obj_id( 'extended_service_info_templates', \@values, 'serviceextinfo_id' );
		if ( $result =~ /Error/ ) {
		    update_status( 'error', $result );
		}
		else {
		    $serviceextinfo_templates{ $data{'use'} }{'id'} = $result;
		}
	    }
	}
	else {
	    if ( $serviceextinfo_templates{ $data{'use'} }{'id'} && !$serviceextinfo_templates{ $data{'use'} }{'updated'} ) {
		$sn_extinfo{ $objects{$key}[0] } = $serviceextinfo_templates{ $data{'use'} }{'id'};
		my %values = ();
		if ( $data{'notes_url'} ) {
		    unless ( $data{'notes_url'} eq $serviceextinfo_templates{ $data{'use'} }{'notes_url'} ) {
			$serviceextinfo_templates{ $data{'use'} }{'notes_url'} = $data{'notes_url'};
		    }
		}
		if ( $data{'action_url'} ) {
		    unless ( $data{'action_url'} eq $serviceextinfo_templates{ $data{'use'} }{'action_url'} ) {
			$serviceextinfo_templates{ $data{'use'} }{'action_url'} = $data{'action_url'};
		    }
		}
		if ( $data{'notes'} ) {
		    unless ( $data{'notes'} eq $serviceextinfo_templates{ $data{'use'} }{'notes'} ) {
			$serviceextinfo_templates{ $data{'use'} }{'notes'} = $data{'notes'};
		    }
		}
		my $data_xml = $xml_begin;
		foreach my $prop ( keys %{ $serviceextinfo_templates{ $data{'use'} } } ) {
		    unless ( $prop =~ /script|name|id|comment/ ) {
			$data_xml .= " <prop name=\"$prop\"><![CDATA[$serviceextinfo_templates{$data{'use'}}{$prop}]]>\n";
			$data_xml .= " </prop>\n";
		    }
		}
		$data_xml .= $xml_end;
		my %w = ( 'name' => $data{'use'} );
		my %u = ( 'data' => $data_xml );
		StorProc->update_obj_where( 'extended_service_info_templates', \%u, \%w );
		$serviceextinfo_templates{ $data{'use'} }{'updated'} = 1;
	    }
	}
	$sn_extinfo{ $objects{$key}[0] } = $serviceextinfo_templates{ $data{'use'} }{'id'};
    }
    StorProc->delete_one_where( 'stage_other', \%where );

    foreach my $service ( keys %sn_extinfo ) {
	my %w = ( 'name'    => $service );
	my %u = ( 'extinfo' => $sn_extinfo{$service} );
	StorProc->update_obj_where( 'service_names', \%u, \%w );
	%w = ( 'servicename_id'    => $service_name{$service} );
	%u = ( 'serviceextinfo_id' => $sn_extinfo{$service} );
	StorProc->update_obj_where( 'services', \%u, \%w );

    }
    return @messages;
}

############################################################################
######
###### Break
######
############################################################################

# host escalations

sub process_host_escalations() {
    my $temp_created      = 0;
    my $trees_created     = 0;
    StorProc->truncate_table('escalation_tree_template', 'escalation_trees');
    my %timeperiod_name      = StorProc->get_table_objects('time_periods');
    my %contactgroup_name    = StorProc->get_table_objects('contactgroups');
    my %host_name            = StorProc->get_table_objects('hosts');
    my %hostgroup_name       = StorProc->get_table_objects('hostgroups');
    my %escalation_templates = ();
    my $result;

    update_status( 'info', 'Loading host/hostgroup escalation templates ...' );
    my %temp_templates = ();
    my %objects        = StorProc->get_staged_escalation_templates('host');
    my $index          = 0;
    foreach my $obj ( keys %objects ) {
	if ( $objects{$obj}{'contact_groups'} ) {
	    $temp_templates{$obj}{'contact_groups'} = $objects{$obj}{'contact_groups'};
	}
	if ( $objects{$obj}{'host_name'} ) {
	    $temp_templates{$obj}{'host_name'} = $objects{$obj}{'host_name'};
	}
	if ( $objects{$obj}{'hostgroup_name'} ) {
	    $temp_templates{$obj}{'hostgroup_name'} = $objects{$obj}{'hostgroup_name'};
	}
	if ( $objects{$obj}{'first_notification'} ) {
	    $temp_templates{$obj}{'first_notification'} = $objects{$obj}{'first_notification'};
	}
	if ( $objects{$obj}{'last_notification'} ) {
	    $temp_templates{$obj}{'last_notification'} = $objects{$obj}{'last_notification'};
	}
	if ( $objects{$obj}{'notification_interval'} ) {
	    $temp_templates{$obj}{'notification_interval'} = $objects{$obj}{'notification_interval'};
	}
	if ( $objects{$obj}{'escalation_options'} ) {
	    $temp_templates{$obj}{'escalation_options'} = $objects{$obj}{'escalation_options'};
	}
	unless ( $objects{$obj}{'escalation_options'} ) {
	    $objects{$obj}{'escalation_options'} = 'all';
	}
	if ( $objects{$obj}{'escalation_period'} ) {
	    $temp_templates{$obj}{'escalation_period'} = $objects{$obj}{'escalation_period'};
	}
	unless ( $objects{$obj}{'escalation_period'} ) {
	    $objects{$obj}{'escalation_period'} = '24x7';
	}

	# match with existing templates
	my $matched = 0;
	foreach my $temp ( keys %escalation_templates ) {
	    if ( $objects{$obj}{'first_notification'} eq $escalation_templates{$temp}{'first_notification'} ) {
		$matched++;
	    }
	    if ( $objects{$obj}{'last_notification'} eq $escalation_templates{$temp}{'last_notification'} ) {
		$matched++;
	    }
	    if ( $objects{$obj}{'notification_interval'} eq $escalation_templates{$temp}{'notification_interval'} ) {
		$matched++;
	    }
	    if ( $objects{$obj}{'escalation_period'} eq $escalation_templates{$temp}{'escalation_period'} ) {
		$matched++;
	    }
	    if ( $objects{$obj}{'escalation_options'} eq $escalation_templates{$temp}{'escalation_options'} ) {
		$matched++;
	    }
	}
	unless ( $matched == 5 ) {
	    my $escalation = $objects{$obj}{'first_notification'};
	    if ( $escalation eq '-zero-' ) { $escalation = '0' }
	    my $last = $objects{$obj}{'last_notification'};
	    if ( $last eq '-zero-' ) { $last = '0' }
	    my $interval = $objects{$obj}{'notification_interval'};
	    if ( $interval eq '-zero-' ) { $last = '0' }
	    my $options = $objects{$obj}{'escalation_options'};
	    unless ($options) { $options = 'all' }
	    my $period = $objects{$obj}{'escalation_period'};
	    unless ($period) { $period = '24x7' }
	    my $name = "host_escalation_$escalation:last_$last:interval_$interval:options_$options:period_$period";
	    $name =~ s/,/./g;
	    $name =~ s/-zero-/0/g;
	    $escalation_templates{$name}{'first_notification'}    = $objects{$obj}{'first_notification'};
	    $escalation_templates{$name}{'last_notification'}     = $objects{$obj}{'last_notification'};
	    $escalation_templates{$name}{'notification_interval'} = $objects{$obj}{'notification_interval'};
	    $escalation_templates{$name}{'escalation_period'}     = $objects{$obj}{'escalation_period'};
	    $escalation_templates{$name}{'escalation_options'}    = $objects{$obj}{'escalation_options'};
	}
	$matched = 0;
    }

    foreach my $temp ( keys %escalation_templates ) {
	my $data_xml = $xml_begin;
	$data_xml .= " <prop name=\"first_notification\"><![CDATA[$escalation_templates{$temp}{'first_notification'}]]>\n";
	$data_xml .= " </prop>\n";
	$data_xml .= " <prop name=\"last_notification\"><![CDATA[$escalation_templates{$temp}{'last_notification'}]]>\n";
	$data_xml .= " </prop>\n";
	$data_xml .= " <prop name=\"notification_interval\"><![CDATA[$escalation_templates{$temp}{'notification_interval'}]]>\n";
	$data_xml .= " </prop>\n";
	$data_xml .= " <prop name=\"escalation_options\"><![CDATA[$escalation_templates{$temp}{'escalation_options'}]]>\n";
	$data_xml .= " </prop>\n";
	$data_xml .= $xml_end;
	my @values = (
	    \undef, $temp, 'host', $data_xml,
	    $escalation_templates{$temp}{'comment'},
	    $timeperiod_name{ $escalation_templates{$temp}{'escalation_period'} }
	);
	$result = StorProc->insert_obj_id( 'escalation_templates', \@values, 'template_id' );
	if ( $result =~ /Error/ ) {
	    update_status( 'error', $result );
	}
	else {
	    $escalation_templates{$temp}{'id'} = $result;
	    $temp_created++;
	}
    }

    my %staged_escalations = StorProc->get_staged_escalations('host');

    # find or create templates for each escalation
    foreach my $esc ( keys %staged_escalations ) {
	if ( $temp_templates{ $staged_escalations{$esc}{'use'} }{'escalation_period'} ) {
	    unless ( $staged_escalations{$esc}{'escalation_period'} ) {
		$staged_escalations{$esc}{'escalation_period'} = $temp_templates{ $staged_escalations{$esc}{'use'} }{'escalation_period'};
	    }
	}
	unless ( $staged_escalations{$esc}{'escalation_period'} ) {
	    $staged_escalations{$esc}{'escalation_period'} = '24x7';
	}
	if ( $temp_templates{ $staged_escalations{$esc}{'use'} }{'escalation_options'} ) {
	    unless ( $staged_escalations{$esc}{'escalation_options'} ) {
		$staged_escalations{$esc}{'escalation_options'} = $temp_templates{ $staged_escalations{$esc}{'use'} }{'escalation_options'};
	    }
	}
	unless ( $staged_escalations{$esc}{'escalation_options'} ) {
	    $staged_escalations{$esc}{'escalation_options'} = 'all';
	}
	if ( $temp_templates{ $staged_escalations{$esc}{'use'} }{'contact_groups'} ) {
	    unless ( $staged_escalations{$esc}{'contact_groups'} ) {
		$staged_escalations{$esc}{'contact_groups'} = $temp_templates{ $staged_escalations{$esc}{'use'} }{'contact_groups'};
	    }
	}
	if ( $temp_templates{ $staged_escalations{$esc}{'use'} }{'host_name'} ) {
	    unless ( $staged_escalations{$esc}{'host_name'} ) {
		$staged_escalations{$esc}{'host_name'} = $temp_templates{ $staged_escalations{$esc}{'use'} }{'host_name'};
	    }
	}
	if ( $temp_templates{ $staged_escalations{$esc}{'use'} }{'hostgroup_name'} ) {
	    unless ( $staged_escalations{$esc}{'hostgroup_name'} ) {
		$staged_escalations{$esc}{'hostgroup_name'} = $temp_templates{ $staged_escalations{$esc}{'use'} }{'hostgroup_name'};
	    }
	}
	if ( $temp_templates{ $staged_escalations{$esc}{'use'} }{'last_notification'} ) {
	    unless ( $staged_escalations{$esc}{'last_notification'} ) {
		$staged_escalations{$esc}{'last_notification'} = $temp_templates{ $staged_escalations{$esc}{'use'} }{'last_notification'};
	    }
	}
	if ( $temp_templates{ $staged_escalations{$esc}{'use'} }{'first_notification'} ) {
	    unless ( $staged_escalations{$esc}{'first_notification'} ) {
		$staged_escalations{$esc}{'first_notification'} = $temp_templates{ $staged_escalations{$esc}{'use'} }{'first_notification'};
	    }
	}
	if ( $temp_templates{ $staged_escalations{$esc}{'use'} }{'notification_interval'} ) {
	    unless ( $staged_escalations{$esc}{'notification_interval'} ) {
		$staged_escalations{$esc}{'notification_interval'} =
		  $temp_templates{ $staged_escalations{$esc}{'use'} }{'notification_interval'};
	    }
	}
	my $template = undef;
	my $matched  = 0;
	foreach my $temp ( keys %escalation_templates ) {
	    if ( $staged_escalations{$esc}{'first_notification'} eq $escalation_templates{$temp}{'first_notification'} ) {
		$matched++;
	    }
	    if ( $staged_escalations{$esc}{'last_notification'} eq $escalation_templates{$temp}{'last_notification'} ) {
		$matched++;
	    }
	    if ( $staged_escalations{$esc}{'notification_interval'} eq $escalation_templates{$temp}{'notification_interval'} ) {
		$matched++;
	    }
	    if ( $staged_escalations{$esc}{'escalation_period'} eq $escalation_templates{$temp}{'escalation_period'} ) {
		$matched++;
	    }
	    if ( $staged_escalations{$esc}{'escalation_options'} eq $escalation_templates{$temp}{'escalation_options'} ) {
		$matched++;
	    }
	    if ( $matched == 5 ) {
		$template = $temp;
		$staged_escalations{$esc}{'use'} = $temp;
		last;
	    }
	    $matched = 0;
	}

	unless ($template) {
	    my $escalation = $staged_escalations{$esc}{'first_notification'};
	    if ( $escalation eq '-zero-' ) { $escalation = '0' }
	    my $last = $staged_escalations{$esc}{'last_notification'};
	    if ( $last eq '-zero-' ) { $last = '0' }
	    my $interval = $staged_escalations{$esc}{'notification_interval'};
	    if ( $interval eq '-zero-' ) { $last = '0' }
	    my $options = $staged_escalations{$esc}{'escalation_options'};
	    unless ($options) { $options = 'all' }
	    my $period = $staged_escalations{$esc}{'escalation_period'};
	    unless ($period) { $period = '24x7' }
	    my $name = "host_escalation_$escalation:last_$last:interval_$interval:options_$options:period_$period";
	    $name =~ s/,/./g;
	    $name =~ s/-zero-/0/g;
	    $escalation_templates{$name}{'first_notification'}    = $staged_escalations{$esc}{'first_notification'};
	    $escalation_templates{$name}{'last_notification'}     = $staged_escalations{$esc}{'last_notification'};
	    $escalation_templates{$name}{'notification_interval'} = $staged_escalations{$esc}{'notification_interval'};
	    $escalation_templates{$name}{'escalation_period'}     = $staged_escalations{$esc}{'escalation_period'};
	    $escalation_templates{$name}{'escalation_options'}    = $staged_escalations{$esc}{'escalation_options'};
	    $escalation_templates{$name}{'comment'}               = $staged_escalations{$esc}{'comment'};
	    my $data_xml = $xml_begin;
	    $data_xml .= " <prop name=\"first_notification\"><![CDATA[$escalation_templates{$name}{'first_notification'}]]>\n";
	    $data_xml .= " </prop>\n";
	    $data_xml .= " <prop name=\"last_notification\"><![CDATA[$escalation_templates{$name}{'last_notification'}]]>\n";
	    $data_xml .= " </prop>\n";
	    $data_xml .= " <prop name=\"notification_interval\"><![CDATA[$escalation_templates{$name}{'notification_interval'}]]>\n";
	    $data_xml .= " </prop>\n";
	    $data_xml .= " <prop name=\"escalation_options\"><![CDATA[$escalation_templates{$name}{'escalation_options'}]]>\n";
	    $data_xml .= " </prop>\n";
	    $data_xml .= $xml_end;
	    my @values = (
		\undef, $name, 'host', $data_xml,
		$escalation_templates{$name}{'comment'},
		$timeperiod_name{ $escalation_templates{$name}{'escalation_period'} }
	    );
	    $result = StorProc->insert_obj_id( 'escalation_templates', \@values, 'template_id' );
	    if ( $result =~ /Error/ ) {
		update_status( 'error', $result );
	    }
	    else {
		$escalation_templates{$name}{'id'} = $result;
		$staged_escalations{$esc}{'use'} = $name;
		$temp_created++;
	    }
	}
    }

    # create template_contactgroups template_hosts template_hostgroups template_servicegroups template_service

    my %trees     = ();
    my %tree_name = ();
    foreach my $esc ( keys %staged_escalations ) {
	if ( $staged_escalations{$esc}{'host_name'} ) {
	    $trees{ $staged_escalations{$esc}{'host_name'} }{ $staged_escalations{$esc}{'use'} }
	      { $staged_escalations{$esc}{'contact_groups'} } = 1;
	    $tree_name{ $staged_escalations{$esc}{'host_name'} } = 'host';
	}
	if ( $staged_escalations{$esc}{'hostgroup_name'} ) {
	    $trees{ $staged_escalations{$esc}{'hostgroup_name'} }{ $staged_escalations{$esc}{'use'} }
	      { $staged_escalations{$esc}{'contact_groups'} } = 1;
	    $tree_name{ $staged_escalations{$esc}{'hostgroup_name'} } = 'hostgroup';
	}
    }
    $index = 0;
    foreach my $tree ( keys %trees ) {
	my @vals = split( /,/, $tree );
	my $name = $tree_name{$tree};
	if ( $vals[3] ) {
	    $name .= "($vals[0]-$vals[1]-$vals[2]...)";
	}
	elsif ( $vals[2] ) {
	    $name .= "($vals[0]-$vals[1]-$vals[2])";
	}
	elsif ( $vals[1] ) {
	    $name .= "($vals[0]-$vals[1])";
	}
	elsif ( $vals[0] =~ /^\*$|^\.\*$/ ) {
	    $name .= "default";
	}
	elsif ( $vals[0] =~ /\*|\.\*/ ) {
	    $name .= "generic-$index";
	    $index++;
	}
	else {
	    $name .= "$vals[0]";
	}
	my @values = ( \undef, $name, $tree, 'host' );
	$result = StorProc->insert_obj_id( 'escalation_trees', \@values, 'tree_id' );
	if ( $result =~ /Error/ ) {
	    update_status( 'error', $result );
	}
	else {
	    my $tree_id = $result;
	    $trees_created++;
	    if ( $tree_name{$tree} eq 'hostgroup' ) {
		if ( $tree =~ /^\*$|^\.\*$/ ) {
		    StorProc->set_default_hostgroup_escalations($tree_id);
		}
		else {
		    my %hostgroups = ();
		    my @hostgroupnames = split( /,/, $tree );
		    foreach my $hn (@hostgroupnames) {
			$hn =~ s/^\s+|\s+$//g;
			foreach my $hostgroup ( keys %hostgroup_name ) {
			    if ( $hostgroup =~ /^$hn$/i ) {
				## FIX MAJOR:  fix the next line:  Useless use of hash element in void context
				$hostgroups{ $hostgroup_name{$hostgroup} };
			    }
			}
		    }
		    foreach my $hostgroup ( keys %hostgroups ) {
			my %values = ( 'host_escalation_id' => $tree_id );
			my $err = StorProc->update_obj( 'hostgroups', 'hostgroup_id', $hostgroup, \%values );
		    }
		}
	    }
	    else {
		if ( $tree =~ /^\*$|^\.\*$/ ) {
		    StorProc->set_default_host_escalations($tree_id);
		}
		else {
		    my %hosts = ();
		    my @hostnames = split( /,/, $tree );
		    foreach my $hn (@hostnames) {
			$hn =~ s/^\s+|\s+$//g;
			foreach my $host ( keys %host_name ) {
			    if ( $host =~ /^$hn$/i ) {
				$hosts{ $host_name{$host} } = 1;
			    }
			}
		    }
		    foreach my $host ( keys %hosts ) {
			my %values = ( 'host_escalation_id' => $tree_id );
			StorProc->update_obj( 'hosts', 'host_id', $host, \%values );
		    }
		}
	    }
	    foreach my $temp ( keys %{ $trees{$tree} } ) {
		@vals = ( $tree_id, $escalation_templates{$temp}{'id'} );
		$result = StorProc->insert_obj( 'escalation_tree_template', \@vals );
		if ( $result =~ /Error/ ) {
		    update_status( 'error', $result );
		}
		foreach my $contactgroup ( keys %{ $trees{$tree}{$temp} } ) {
		    my @contact_grps = split( /,/, $contactgroup );
		    foreach my $grp (@contact_grps) {
			if ( $contactgroup_name{$grp} ) {
			    @vals = ( $tree_id, $escalation_templates{$temp}{'id'}, $contactgroup_name{$grp} );
			    $result = StorProc->insert_obj( 'tree_template_contactgroup', \@vals );
			    if ( $result =~ /Error/ ) {
				update_status( 'error', $result );
			    }
			}
		    }
		}
	    }
	}
    }
    update_status( 'info', "Host escalations: $temp_created escalations created, $trees_created trees created." );
    return @messages;
}

############################################################################
######
###### Break
######
############################################################################

# service escalations

sub process_service_escalations() {
    my $temp_created         = 0;
    my $trees_created        = 0;
    my %timeperiod_name      = StorProc->get_table_objects('time_periods');
    my %contactgroup_name    = StorProc->get_table_objects('contactgroups');
    my %host_name            = StorProc->get_table_objects('hosts');
    my %hostgroup_name       = StorProc->get_table_objects('hostgroups');
    my %service_name         = StorProc->get_table_objects('service_names');
    my %servicegroup_name    = StorProc->get_table_objects('servicegroups');
    my %escalation_templates = ();
    my $result;

    update_status( 'info', 'Loading service escalation templates ...' );
    my %temp_templates = ();
    my %objects        = StorProc->get_staged_escalation_templates('service');
    my $index          = 0;
    foreach my $obj ( keys %objects ) {
	if ( $objects{$obj}{'contact_groups'} ) {
	    $temp_templates{$obj}{'contact_groups'} = $objects{$obj}{'contact_groups'};
	}
	if ( $objects{$obj}{'host_name'} ) {
	    $temp_templates{$obj}{'host_name'} = $objects{$obj}{'host_name'};
	}
	if ( $objects{$obj}{'hostgroup_name'} ) {
	    $temp_templates{$obj}{'hostgroup_name'} = $objects{$obj}{'hostgroup_name'};
	}
	if ( $objects{$obj}{'service_description'} ) {
	    $temp_templates{$obj}{'service_description'} = $objects{$obj}{'service_description'};
	}
	if ( $objects{$obj}{'servicegroup_name'} ) {
	    $temp_templates{$obj}{'servicegroup_name'} = $objects{$obj}{'servicegroup_name'};
	}
	if ( $objects{$obj}{'first_notification'} ) {
	    $temp_templates{$obj}{'first_notification'} = $objects{$obj}{'first_notification'};
	}
	if ( $objects{$obj}{'last_notification'} ) {
	    $temp_templates{$obj}{'last_notification'} = $objects{$obj}{'last_notification'};
	}
	if ( $objects{$obj}{'notification_interval'} ) {
	    $temp_templates{$obj}{'notification_interval'} = $objects{$obj}{'notification_interval'};
	}
	if ( $objects{$obj}{'escalation_options'} ) {
	    $temp_templates{$obj}{'escalation_options'} = $objects{$obj}{'escalation_options'};
	}
	unless ( $objects{$obj}{'escalation_options'} ) {
	    $objects{$obj}{'escalation_options'} = 'all';
	}
	if ( $objects{$obj}{'escalation_period'} ) {
	    $temp_templates{$obj}{'escalation_period'} = $objects{$obj}{'escalation_period'};
	}
	unless ( $objects{$obj}{'escalation_period'} ) {
	    $objects{$obj}{'escalation_period'} = '24x7';
	}

	# match with existing templates
	my $matched = 0;
	foreach my $temp ( keys %escalation_templates ) {
	    if ( $objects{$obj}{'first_notification'} eq $escalation_templates{$temp}{'first_notification'} ) {
		$matched++;
	    }
	    if ( $objects{$obj}{'last_notification'} eq $escalation_templates{$temp}{'last_notification'} ) {
		$matched++;
	    }
	    if ( $objects{$obj}{'notification_interval'} eq $escalation_templates{$temp}{'notification_interval'} ) {
		$matched++;
	    }
	    if ( $objects{$obj}{'escalation_period'} eq $escalation_templates{$temp}{'escalation_period'} ) {
		$matched++;
	    }
	    if ( $objects{$obj}{'escalation_options'} eq $escalation_templates{$temp}{'escalation_options'} ) {
		$matched++;
	    }
	}
	unless ( $matched == 5 ) {
	    my $escalation = $objects{$obj}{'first_notification'};
	    if ( $escalation eq '-zero-' ) { $escalation = '0' }
	    my $last = $objects{$obj}{'last_notification'};
	    if ( $last eq '-zero-' ) { $last = '0' }
	    my $interval = $objects{$obj}{'notification_interval'};
	    if ( $interval eq '-zero-' ) { $last = '0' }
	    my $options = $objects{$obj}{'escalation_options'};
	    unless ($options) { $options = 'all' }
	    my $period = $objects{$obj}{'escalation_period'};
	    unless ($period) { $period = '24x7' }
	    my $name = "service_escalation_$escalation:last_$last:interval_$interval:options_$options:period_$period";
	    $name =~ s/,/./g;
	    $name =~ s/-zero-/0/g;
	    $escalation_templates{$name}{'first_notification'}    = $objects{$obj}{'first_notification'};
	    $escalation_templates{$name}{'last_notification'}     = $objects{$obj}{'last_notification'};
	    $escalation_templates{$name}{'notification_interval'} = $objects{$obj}{'notification_interval'};
	    $escalation_templates{$name}{'escalation_period'}     = $objects{$obj}{'escalation_period'};
	    $escalation_templates{$name}{'escalation_options'}    = $objects{$obj}{'escalation_options'};
	}
	$matched = 0;
    }

    foreach my $temp ( keys %escalation_templates ) {
	my $data_xml = $xml_begin;
	$data_xml .= " <prop name=\"first_notification\"><![CDATA[$escalation_templates{$temp}{'first_notification'}]]>\n";
	$data_xml .= " </prop>\n";
	$data_xml .= " <prop name=\"last_notification\"><![CDATA[$escalation_templates{$temp}{'last_notification'}]]>\n";
	$data_xml .= " </prop>\n";
	$data_xml .= " <prop name=\"notification_interval\"><![CDATA[$escalation_templates{$temp}{'notification_interval'}]]>\n";
	$data_xml .= " </prop>\n";
	$data_xml .= " <prop name=\"escalation_options\"><![CDATA[$escalation_templates{$temp}{'escalation_options'}]]>\n";
	$data_xml .= " </prop>\n";
	$data_xml .= $xml_end;
	my @values = (
	    \undef, $temp, 'service', $data_xml,
	    $escalation_templates{$temp}{'comment'},
	    $timeperiod_name{ $escalation_templates{$temp}{'escalation_period'} }
	);
	$result = StorProc->insert_obj_id( 'escalation_templates', \@values, 'template_id' );
	if ( $result =~ /Error/ ) {
	    update_status( 'error', $result );
	}
	else {
	    $escalation_templates{$temp}{'id'} = $result;
	    $temp_created++;
	}
    }
    my %staged_escalations = StorProc->get_staged_escalations('service');

    # find or create templates for each escalation
    foreach my $esc ( keys %staged_escalations ) {
	if ( $temp_templates{ $staged_escalations{$esc}{'use'} }{'escalation_period'} ) {
	    unless ( $staged_escalations{$esc}{'escalation_period'} ) {
		$staged_escalations{$esc}{'escalation_period'} = $temp_templates{ $staged_escalations{$esc}{'use'} }{'escalation_period'};
	    }
	}
	unless ( $staged_escalations{$esc}{'escalation_period'} ) {
	    $staged_escalations{$esc}{'escalation_period'} = '24x7';
	}
	if ( $temp_templates{ $staged_escalations{$esc}{'use'} }{'escalation_options'} ) {
	    unless ( $staged_escalations{$esc}{'escalation_options'} ) {
		$staged_escalations{$esc}{'escalation_options'} = $temp_templates{ $staged_escalations{$esc}{'use'} }{'escalation_options'};
	    }
	}
	unless ( $staged_escalations{$esc}{'escalation_options'} ) {
	    $staged_escalations{$esc}{'escalation_options'} = 'all';
	}
	if ( $temp_templates{ $staged_escalations{$esc}{'use'} }{'contact_groups'} ) {
	    unless ( $staged_escalations{$esc}{'contact_groups'} ) {
		$staged_escalations{$esc}{'contact_groups'} = $temp_templates{ $staged_escalations{$esc}{'use'} }{'contact_groups'};
	    }
	}
	if ( $temp_templates{ $staged_escalations{$esc}{'use'} }{'host_name'} ) {
	    unless ( $staged_escalations{$esc}{'host_name'} ) {
		$staged_escalations{$esc}{'host_name'} = $temp_templates{ $staged_escalations{$esc}{'use'} }{'host_name'};
	    }
	}
	if ( $temp_templates{ $staged_escalations{$esc}{'use'} }{'hostgroup_name'} ) {
	    unless ( $staged_escalations{$esc}{'hostgroup_name'} ) {
		$staged_escalations{$esc}{'hostgroup_name'} = $temp_templates{ $staged_escalations{$esc}{'use'} }{'hostgroup_name'};
	    }
	}
	if ( $temp_templates{ $staged_escalations{$esc}{'use'} }{'servicegroup_name'} ) {
	    unless ( $staged_escalations{$esc}{'servicegroup_name'} ) {
		$staged_escalations{$esc}{'servicegroup_name'} = $temp_templates{ $staged_escalations{$esc}{'use'} }{'servicegroup_name'};
	    }
	}
	if ( $temp_templates{ $staged_escalations{$esc}{'use'} }{'service_description'} ) {
	    unless ( $staged_escalations{$esc}{'service_description'} ) {
		$staged_escalations{$esc}{'service_description'} = $temp_templates{ $staged_escalations{$esc}{'use'} }{'service_description'};
	    }
	}
	if ( $temp_templates{ $staged_escalations{$esc}{'use'} }{'last_notification'} ) {
	    unless ( $staged_escalations{$esc}{'last_notification'} ) {
		$staged_escalations{$esc}{'last_notification'} = $temp_templates{ $staged_escalations{$esc}{'use'} }{'last_notification'};
	    }
	}
	if ( $temp_templates{ $staged_escalations{$esc}{'use'} }{'first_notification'} ) {
	    unless ( $staged_escalations{$esc}{'first_notification'} ) {
		$staged_escalations{$esc}{'first_notification'} = $temp_templates{ $staged_escalations{$esc}{'use'} }{'first_notification'};
	    }
	}
	if ( $temp_templates{ $staged_escalations{$esc}{'use'} }{'notification_interval'} ) {
	    unless ( $staged_escalations{$esc}{'notification_interval'} ) {
		$staged_escalations{$esc}{'notification_interval'} =
		  $temp_templates{ $staged_escalations{$esc}{'use'} }{'notification_interval'};
	    }
	}

	my $template = 0;
	my $matched  = 0;
	foreach my $temp ( keys %escalation_templates ) {
	    if ( $staged_escalations{$esc}{'first_notification'} eq $escalation_templates{$temp}{'first_notification'} ) {
		$matched++;
	    }
	    if ( $staged_escalations{$esc}{'last_notification'} eq $escalation_templates{$temp}{'last_notification'} ) {
		$matched++;
	    }
	    if ( $staged_escalations{$esc}{'notification_interval'} eq $escalation_templates{$temp}{'notification_interval'} ) {
		$matched++;
	    }
	    if ( $staged_escalations{$esc}{'escalation_period'} eq $escalation_templates{$temp}{'escalation_period'} ) {
		$matched++;
	    }
	    if ( $staged_escalations{$esc}{'escalation_options'} eq $escalation_templates{$temp}{'escalation_options'} ) {
		$matched++;
	    }
	    if ( $matched == 5 ) {
		$template = $temp;
		$staged_escalations{$esc}{'use'} = $temp;
		last;
	    }
	    $matched = 0;
	}
	unless ($template) {
	    my $escalation = $staged_escalations{$esc}{'first_notification'};
	    if ( $escalation eq '-zero-' ) { $escalation = '0' }
	    my $last = $staged_escalations{$esc}{'last_notification'};
	    if ( $last eq '-zero-' ) { $last = '0' }
	    my $interval = $staged_escalations{$esc}{'notification_interval'};
	    if ( $interval eq '-zero-' ) { $last = '0' }
	    my $options = $staged_escalations{$esc}{'escalation_options'};
	    unless ($options) { $options = 'all' }
	    my $period = $staged_escalations{$esc}{'escalation_period'};
	    unless ($period) { $period = '24x7' }
	    my $name = "service_escalation_$escalation:last_$last:interval_$interval:options_$options:period_$period";
	    $name =~ s/,/./g;
	    $name =~ s/-zero-/0/g;
	    $escalation_templates{$name}{'first_notification'}    = $staged_escalations{$esc}{'first_notification'};
	    $escalation_templates{$name}{'last_notification'}     = $staged_escalations{$esc}{'last_notification'};
	    $escalation_templates{$name}{'notification_interval'} = $staged_escalations{$esc}{'notification_interval'};
	    $escalation_templates{$name}{'escalation_period'}     = $staged_escalations{$esc}{'escalation_period'};
	    $escalation_templates{$name}{'escalation_options'}    = $staged_escalations{$esc}{'escalation_options'};
	    $escalation_templates{$name}{'comment'}               = $staged_escalations{$esc}{'comment'};
	    my $data_xml = $xml_begin;
	    $data_xml .= " <prop name=\"first_notification\"><![CDATA[$escalation_templates{$name}{'first_notification'}]]>\n";
	    $data_xml .= " </prop>\n";
	    $data_xml .= " <prop name=\"last_notification\"><![CDATA[$escalation_templates{$name}{'last_notification'}]]>\n";
	    $data_xml .= " </prop>\n";
	    $data_xml .= " <prop name=\"notification_interval\"><![CDATA[$escalation_templates{$name}{'notification_interval'}]]>\n";
	    $data_xml .= " </prop>\n";
	    $data_xml .= " <prop name=\"escalation_options\"><![CDATA[$escalation_templates{$name}{'escalation_options'}]]>\n";
	    $data_xml .= " </prop>\n";
	    $data_xml .= $xml_end;
	    my @values = (
		\undef, $name, 'service', $data_xml,
		$escalation_templates{$name}{'comment'},
		$timeperiod_name{ $escalation_templates{$name}{'escalation_period'} }
	    );
	    $result = StorProc->insert_obj_id( 'escalation_templates', \@values, 'template_id' );
	    if ( $result =~ /Error/ ) {
		update_status( 'error', $result );
	    }
	    else {
		$escalation_templates{$name}{'id'} = $result;
		$staged_escalations{$esc}{'use'} = $name;
		$temp_created++;
	    }
	}
    }

    # create template_contactgroups template_hosts template_hostgroups template_servicegroups template_service

    my %trees           = ();
    my %tree_name       = ();
    my %tree_service    = ();
    my %tree_hosts      = ();
    my %tree_hostgroups = ();
    foreach my $esc ( keys %staged_escalations ) {
	if ( $staged_escalations{$esc}{'host_name'} && $staged_escalations{$esc}{'service_description'} =~ /\*|\.\*/ ) {
	    $trees{ $staged_escalations{$esc}{'host_name'} }{ $staged_escalations{$esc}{'use'} }
	      { $staged_escalations{$esc}{'contact_groups'} } = 1;
	    $tree_name{ $staged_escalations{$esc}{'host_name'} } = 'host';
	}
	if ( $staged_escalations{$esc}{'hostgroup_name'} && $staged_escalations{$esc}{'service_description'} =~ /\*|\.\*/ ) {
	    $trees{ $staged_escalations{$esc}{'hostgroup_name'} }{ $staged_escalations{$esc}{'use'} }
	      { $staged_escalations{$esc}{'contact_groups'} } = 1;
	    $tree_name{ $staged_escalations{$esc}{'hostgroup_name'} } = 'hostgroup';
	}
	if ( $staged_escalations{$esc}{'servicegroup_name'} && $staged_escalations{$esc}{'service_description'} =~ /\*|\.\*/ ) {
	    $trees{ $staged_escalations{$esc}{'servicegroup_name'} }{ $staged_escalations{$esc}{'use'} }
	      { $staged_escalations{$esc}{'contact_groups'} } = 1;
	    $tree_name{ $staged_escalations{$esc}{'servicegroup_name'} } = 'servicegroup';
	}
	if ( $staged_escalations{$esc}{'service_description'} && $staged_escalations{$esc}{'service_description'} !~ /\*|\.\*/ ) {
	    if ( $staged_escalations{$esc}{'host_name'} ) {
		$trees{ $staged_escalations{$esc}{'host_name'} }{ $staged_escalations{$esc}{'use'} }
		  { $staged_escalations{$esc}{'contact_groups'} } = 1;
		$tree_name{ $staged_escalations{$esc}{'host_name'} }    = 'service';
		$tree_service{ $staged_escalations{$esc}{'host_name'} } = $staged_escalations{$esc}{'service_description'};
		$tree_hosts{ $staged_escalations{$esc}{'host_name'} }   = $staged_escalations{$esc}{'host_name'};
	    }
	    if ( $staged_escalations{$esc}{'hostgroup_name'} ) {
		$trees{ $staged_escalations{$esc}{'hostgroup_name'} }{ $staged_escalations{$esc}{'use'} }
		  { $staged_escalations{$esc}{'contact_groups'} } = 1;
		$tree_name{ $staged_escalations{$esc}{'hostgroup_name'} }       = 'service';
		$tree_service{ $staged_escalations{$esc}{'hostgroup_name'} }    = $staged_escalations{$esc}{'service_description'};
		$tree_hostgroups{ $staged_escalations{$esc}{'hostgroup_name'} } = $staged_escalations{$esc}{'hostgroup_name'};
	    }
	}
    }
    $index = 0;
    foreach my $tree ( keys %trees ) {
	my @vals = split( /,/, $tree );
	my $name = $tree_name{$tree};
	if ( $vals[3] ) {
	    $name .= "-service($vals[0]-$vals[1]-$vals[2]...)";
	}
	elsif ( $vals[2] ) {
	    $name .= "-service($vals[0]-$vals[1]-$vals[2])";
	}
	elsif ( $vals[1] ) {
	    $name .= "-service($vals[0]-$vals[1])";
	}
	elsif ( $vals[0] =~ /^\*$|^\.\*$/ ) {
	    $name .= "-default-service";
	}
	elsif ( $vals[0] =~ /\*|\.\*/ ) {
	    $name .= "-generic-service-$index";
	    $index++;
	}
	else {
	    $name .= "-service-$vals[0]";
	}
	if ( $name =~ /^service-service/ ) { $name =~ s/^service-// }
	my @values = ( \undef, $name, $tree, 'service' );
	$result = StorProc->insert_obj_id( 'escalation_trees', \@values, 'tree_id' );
	if ( $result =~ /Error/ ) {
	    update_status( 'error', $result );
	}
	else {
	    my $tree_id = $result;
	    $trees_created++;
	    if ( $tree_name{$tree} eq 'hostgroup' ) {
		if ( $tree =~ /^\*$|^\.\*$/ ) {
		    StorProc->set_default_hostgroup_escalations($tree_id);
		}
		else {
		    my %hostgroups = ();
		    my @hostgroupnames = split( /,/, $tree );
		    foreach my $hn (@hostgroupnames) {
			$hn =~ s/^\s+|\s+$//g;
			my $got_hostgroup = 0;
			foreach my $hostgroup ( keys %hostgroup_name ) {
			    if ( $hostgroup =~ /^$hn$/i ) {
				$hostgroups{ $hostgroup_name{$hostgroup} } = 1;
			    }
			}
		    }
		    foreach my $hostgroup ( keys %hostgroups ) {
			my %values = ( 'service_escalation_id' => $tree_id );
			my $err = StorProc->update_obj( 'hostgroups', 'hostgroup_id', $hostgroup, \%values );
		    }
		}
	    }
	    elsif ( $tree_name{$tree} eq 'host' ) {
		if ( $tree =~ /^\*$|^\.\*$/ ) {
		    StorProc->set_default_host_escalations($tree_id);
		}
		else {
		    my %hosts = ();
		    my @hostnames = split( /,/, $tree );
		    foreach my $hn (@hostnames) {
			$hn =~ s/^\s+|\s+$//g;
			foreach my $host ( keys %host_name ) {
			    if ( $host eq /^$hn$/i ) {
				$hosts{ $host_name{$host} } = 1;
			    }
			}
		    }
		    foreach my $host ( keys %hosts ) {
			my %values = ( 'service_escalation_id' => $tree_id );
			StorProc->update_obj( 'hosts', 'host_id', $host, \%values );
		    }
		}
	    }
	    elsif ( $tree_name{$tree} eq 'servicegroup' ) {
		if ( $tree =~ /^\*$|^\.\*$/ ) {
		    StorProc->set_default_servicegroup_escalations($tree_id);
		}
		else {
		    my %servicegroups = ();
		    my @servicegroupnames = split( /,/, $tree );
		    foreach my $sgn (@servicegroupnames) {
			$sgn =~ s/^\s+|\s+$//g;
			foreach my $servicegroup ( keys %servicegroup_name ) {
			    if ( $servicegroup =~ /^$sgn$/i ) {
				$servicegroups{ $servicegroup_name{$servicegroup} } = 1;
			    }
			}
		    }
		    foreach my $servicegroup ( keys %servicegroups ) {
			my %values = ( 'escalation_id' => $tree_id );
			StorProc->update_obj( 'servicegroups', 'servicegroup_id', $servicegroup, \%values );
		    }
		}
	    }
	    elsif ( $tree_name{$tree} eq 'service' ) {
		my %services  = ();
		my %hosts     = ();
		my @hostnames = ();
		if ( $tree_hostgroups{$tree} ) {
		    if ( $tree_hostgroups{$tree} =~ /^\*$|^\.\*$/ ) {
			@hostnames = StorProc->fetch_list( 'hosts', 'name' );
		    }
		    else {
			my @hostgroupnames = split( /,/, $tree_hostgroups{$tree} );
			foreach my $host (@hostgroupnames) {
			    my @hosts = StorProc->fetch_list( 'hosts', 'name' );
			    push( @hostnames, (@hosts) );
			}
		    }
		}
		elsif ( $tree_hosts{$tree} ) {
		    if ( $tree_hosts{$tree} =~ /^\*$|^\.\*$/ ) {
			@hostnames = StorProc->fetch_list( 'hosts', 'name' );
		    }
		    else {
			@hostnames = split( /,/, $tree_hosts{$tree} );
		    }
		}
		foreach my $hn (@hostnames) {
		    $hn =~ s/^\s+|\s+$//g;
		    foreach my $host ( keys %host_name ) {
			if ( $host =~ /^$hn$/i ) { $hosts{ $host_name{$host} } = 1 }
		    }
		}
		my @servicenames = split( /,/, $tree_service{$tree} );
		foreach my $sn (@servicenames) {
		    $sn =~ s/^\s+|\s+$//g;
		    foreach my $service ( keys %service_name ) {
			if ( $service =~ /^$sn$/i ) {
			    $services{ $service_name{$service} } = 1;
			}
		    }
		}
		foreach my $service ( keys %services ) {
		    foreach my $hostid ( keys %hosts ) {
			my %where = ( 'host_id' => $hostid, 'servicename_id' => $service );
			my %values = ( 'escalation_id' => $tree_id );
			StorProc->update_obj_where( 'services', \%values, \%where );
		    }
		    my %values = ( 'escalation' => $tree_id );
		    StorProc->update_obj( 'service_names', 'servicename_id', $service, \%values );
		}
	    }
	    my %tcg_exists = ();
	    foreach my $temp ( keys %{ $trees{$tree} } ) {
		@vals = ( $tree_id, $escalation_templates{$temp}{'id'} );
		$result = StorProc->insert_obj( 'escalation_tree_template', \@vals );
		if ( $result =~ /Error/ ) {
		    update_status( 'error', $result );
		}
		foreach my $contactgroup ( keys %{ $trees{$tree}{$temp} } ) {
		    my @contact_grps = split( /,/, $contactgroup );
		    foreach my $grp (@contact_grps) {
			if ( $contactgroup_name{$grp} ) {
			    unless ( $tcg_exists{$tree_id}{ $escalation_templates{$temp}{'id'} }{ $contactgroup_name{$grp} } ) {
				@vals = ( $tree_id, $escalation_templates{$temp}{'id'}, $contactgroup_name{$grp} );
				$result = StorProc->insert_obj( 'tree_template_contactgroup', \@vals );
				if ( $result =~ /Error/ ) {
				    update_status( 'error', $result );
				}
				$tcg_exists{$tree_id}{ $escalation_templates{$temp}{'id'} }{ $contactgroup_name{$grp} } = 1;
			    }
			}
		    }
		}
	    }
	}
    }
    update_status( 'info', "Service escalations: $temp_created escalations created, $trees_created trees created." );
    return @messages;
}

if ($debug) {
    my $connect = StorProc->dbconnect();
    StorProc->purge();
    stage_load( '', '/usr/local/groundwork/nagios/etc', '1' );
    process_commands();
    process_timeperiods();
    process_contacts();
    process_hosts();
    process_services();
    process_host_escalations();
    process_service_escalations();
    my $result = StorProc->dbdisconnect();
}

1;
