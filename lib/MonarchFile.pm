# MonArch - Groundwork Monitor Architect
# MonarchFile.pm
#
############################################################################
# Release 4.6
# September 2017
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

#use warnings;
use MonarchStorProc;

package Files;

my %options             = ();    # Hash to hold the instructions for generating files
my @errors              = ();
my %use                 = ();    # Tracks which contacts, contact groups, host groups, etc, will be used for a particular instance
my @out_files           = ();    # Holds the list of files for nagios.cfg and export presentation
my @extinfofiles        = ();    # For Nagios 1.x extended info files for nagios.cgi
my @group_process_order = ();    # Holds the parent-child order to process configuration groups
my %property_list       = ();    # Hash containing Nagios directives by object type
my @log                 = ();    # @log gathers content for foundation sync when $audit is set
my $audit               = undef;

my $interrupt_message = 'Processing was interrupted.';

my $log_file    = "config-current.log";    # Audit file name
my $date_time   = undef;                   # timestamp for file headers
my $group       = undef;                   #
my $destination = undef;

my %commands     = ();                     # Holds the contents of the commands table (sub get_commands)
my %command_name = ();                     # Used to translate id to name

my %timeperiods     = ();                  # Holds the contents of the time_periods table (sub get_timeperiods)
my %timeperiod_name = ();                  # Used to translate id to name

my %host_extinfo_templates = ();           # Holds the contents of the extended_host_info_templates table (sub get_hostextinfo)
my %hostextinfo_name       = ();           # Used to translate template id to name

my %host_templates    = ();                # Holds the contents of the host_templates table (sub get_host_templates)
my %hosttemplate_name = ();                # Used to translate id to name

my %hosts                  = ();           # Stores all host records and their services
my %host_name              = ();           # Used to resolve host ids to names
my %host_name_id           = ();           # Used to resolve host names to ids
my %address                = ();           # Holds host addresses
my %host_groups            = ();           # Holds all info for host groups
my %hostgroup_name         = ();           # Used to translate id to name
my %hosts_not_in_hostgroup = ();           # Holder for unassigned hosts
my %host_dependencies      = ();           # Holds the contents of the host_dependencies table (sub host_dependencies)

my %service_templates    = ();             # Holds the contents of the service_templates table (sub get_services)
my %servicetemplate_name = ();             # Used to translate id to name
my %service_groups       = ();             # Holds service group data (sub get_services)
my %service_instances    = ();             # Holds the contents of the service_instances table (sub get_services)
my %servicename_name     = ();             # Used to translate servicename_id to name

my %service_extinfo_templates = ();        # Holds the contents of the extended_service_info_templates table (sub get_services)
my %serviceextinfo_name       = ();        # Used to translate id to name

# Assigned and translated from templates (in process_hostextinfo()) to host extended info (in process_hosts()).
my %host_notes      = ();
my %host_notes_url  = ();
my %host_action_url = ();

# Assigned and translated from templates (in process_serviceextinfo()) to service extended info (in process_services()).
my %service_notes      = ();
my %service_notes_url  = ();
my %service_action_url = ();

my %service_dependency_templates = ();    # Holds the contents of the service_dependency_templates table (sub get_services)
my %service_dependencies         = ();    # Holds the contents of the service_dependencies table (sub get_services)

my %escalation_templates = ();            # Holds the contents of the escalation_templates table (sub get_escalations)
my %escalation_trees     = ();            # Holds the contents of the escalation_trees table (sub get_escalations)

my %contact_groups       = ();            # Holds the contents of the contact_groups table (sub get_contact_groups)
my %contactgroup_name    = ();            # Used to translate id to name
my %contactgroup_contact = ();            # Holds contacts by contact groups (sub get_contact_groups)

my %contacts                  = ();       # Holds the contents of the contacts table (sub get_contacts)
my %contact_name              = ();       # Used to translate id to name
my %contact_command_overrides = ();       # Holds contents of the contact_command_overrides table by contact id (sub get_contacts)
my %contact_overrides         = ();       # Holds contents of the contact_command table by contact id (sub get_contacts)

my %contact_templates     = ();           # Holds the contents of the contact_templates table (sub get_contacts)
my %contact_template_name = ();           # Used to translate id to name

my %monarch_groups     = ();              # Holds all configuration groups
my %group_ids          = ();              # Translates group name to id
my %group_hosts        = ();              # Hash holds the list of configuration groups to process
my %group_child        = ();              #
my %inactive_hosts     = ();              # Hosts to be excluded by processing
my %host_service_group = ();              #
my %host_group         = ();              # Associates a host with its configuration group
my %parents_all        = ();
my %parent_top         = ();

my %nagios_cgi      = ();
my %nagios_cfg      = ();
my %resource_cfg    = ();
my %nagios_cfg_misc = ();

my $debug = 0;

# This sub formats any object for printing to file
sub format_obj(@) {
    my $props    = shift;
    my $type     = shift;
    my $object   = shift;
    my @props    = @{$props};
    my %object   = %{$object};
    my $register = 0;
    my @obj_log  = ();

    push @obj_log, "\n$type";
    if ( $type =~ s/_template// ) {
	$register = 1;
    }

    if ( !defined( $object{'comment'} ) || $object{'comment'} !~ /\n$/ ) {
	$object{'comment'} .= "\n";
    }
    if ( $object{'comment'} !~ /^[#\n]/ ) {
	$object{'comment'} = '# ' . $object{'comment'};
    }
    $object{'comment'} =~ s/\n\n/\n#\n/g;
    $object{'comment'} =~ s/\n([^#])/\n# $1/g;
    my @objout = ();
    push @objout, qq(\n$object{'comment'}define $type \{);

    my ( $tabs, $got_props, $prop );
    foreach $prop (@props) {
	my $pname = $prop;    # property name
	if ( $prop eq 'template' ) {
	    $pname = 'use';
	}
	elsif ( $type eq 'service' && $prop eq 'name' ) {
	    $pname = 'service_description';
	}
	elsif ( $type eq 'host' && $prop eq 'name' ) {
	    $pname = 'host_name';
	}
	elsif ( $type eq 'contactgroup' && $prop eq 'name' ) {
	    $pname = 'contactgroup_name';
	}
	elsif ( $type eq 'contact' && $prop eq 'name' ) {
	    $pname = 'contact_name';
	}
	elsif ( $type eq 'servicegroup' && $prop eq 'name' ) {
	    $pname = 'servicegroup_name';
	}
	elsif ( $type eq 'service_dependency' && $prop eq 'service_name' ) {
	    $pname = 'dependent_service_description';
	}
	elsif ( $type eq 'service_dependency' && $prop eq 'host_name' ) {
	    $pname = 'dependent_host_name';
	}
	elsif ( $type eq 'service_dependency' && $prop eq 'depend_on_host' ) {
	    $pname = 'host_name';
	}
	elsif ( $type eq 'hostgroup_escalation' && $prop eq 'name' ) {
	    $pname = 'hostgroup_name';
	}
	elsif ( $type eq 'host_escalation' && $prop eq 'name' ) {
	    $pname = 'host_name';
	}
	elsif ( $type eq 'timeperiod' && $prop eq 'name' ) {
	    $pname = 'timeperiod_name';
	}
	elsif ( $type eq 'command' && $prop eq 'name' ) {
	    $pname = 'command_name';
	}
	elsif ( $type eq 'hostgroup' && $prop eq 'name' ) {
	    $pname = 'hostgroup_name';
	}
	elsif ( $type eq 'hostgroup' && $prop =~ /hostgroup_escalation_id|host_escalation_id|service_escalation_id/ ) {
	    next;
	}

	if ( $prop eq 'contactgroup' ) {
	    $pname = 'contact_groups';
	}
	elsif ( $register && $prop eq 'name' ) {
	    $pname = 'name';
	}

	# We allow custom object variables through with an empty value.
	if ( $object{$prop} || $prop =~ /^_/ ) {
	    $object{$prop} =~ s/^\s*-zero-\s*$/0/g;
	    my $length = length($pname);
	    if ( $length < 8 ) {
		$tabs = "\t\t\t\t";
	    }
	    elsif ( $length < 16 ) {
		$tabs = "\t\t\t";
	    }
	    elsif ( $length < 24 ) {
		$tabs = "\t\t";
	    }
	    else {
		$tabs = "\t";
	    }
	    my $obj_prop = $object{$prop};
	    $obj_prop =~ s/\n/<br>/g if $prop eq 'notes';
	    push @objout, qq(
	$pname$tabs$obj_prop);
	    $obj_prop =~ s/;;/-/g;

	    # Ouch, it looks like @obj_log's construction relies on a reliable
	    # sorting order for @props coming in, because later (in a now-obsolete
	    # routine in MonarchAudit.pm), it is read by offset (some of @obj_log
	    # gets appended to @log below, which ultimately gets written to
	    # config-current.log.)
	    push @obj_log, ";;$obj_prop";
	}
	$tabs = undef;
    }
    if ($register) {
	push @objout, qq(
	register			0);
    }
    push @objout, "\n}\n";
    if ( $audit && $type =~ /^host$|^hostgroup$|^service$/ ) {
	unless ($register) { push @log, @obj_log }
    }
    return join( '', @objout );
}

sub write_to_text_file {
    my $file = shift or return "Error: write_to_text_file() requires filename argument.";
    my $text = shift or return "Error: write_to_text_file() requires output text argument (writing to $file).";
    my $mode = shift || 0644;

    open( FILE, '>', $file ) or return "Error:  Cannot open $file to write ($!).";
    my $got_errno = '';
    if ( not print FILE $text ) {
	$got_errno = "$!";
    }
    if ( not close(FILE) and not $got_errno ) {
	$got_errno = "$!";
    }
    return "Error:  Cannot write to $file ($got_errno)." if $got_errno;
    if ( defined $mode ) {
	chmod( $mode, $file ) or return "Error:  Cannot change mode on $file ($!).";
    }
    return;
}

############################################################################
# Time periods
############################################################################
# Modified for Nagios 3 2008-11-25 by Scott Parris
#

sub get_timeperiods() {

    # Reinitialize global state to avoid confusion from any prior calls to this routine.
    %timeperiods     = ();
    %timeperiod_name = ();

    # time_periods
    my %prop_list_augment = ();    # need to add exceptions to the time period property list
    my %where             = ();
    my %timeperiod_hash_array = StorProc->fetch_list_hash_array( 'time_periods', \%where );
    foreach my $id ( keys %timeperiod_hash_array ) {
	$timeperiod_name{$id}        = $timeperiod_hash_array{$id}[1];
	$timeperiods{$id}{'name'}    = $timeperiod_hash_array{$id}[1];
	$timeperiods{$id}{'alias'}   = $timeperiod_hash_array{$id}[2];
	$timeperiods{$id}{'comment'} = $timeperiod_hash_array{$id}[3];
    }

    # time_period_property
    my %time_period_property = StorProc->fetch_hash_array_generic_key( 'time_period_property', \%where );
    foreach my $key ( keys %time_period_property ) {
	my $id      = $time_period_property{$key}[0];
	my $name    = $time_period_property{$key}[1];
	my $value   = $time_period_property{$key}[3];
	my $comment = $time_period_property{$key}[4];
	if (defined $comment) {
	    $comment =~ s/\s*\n+/, /g;
	    $comment =~ s/, $//g;
	}
	$timeperiods{$id}{$name} = $value;
	$timeperiods{$id}{$name} .= "\t; $comment" if $comment;

	# Augment the property list for both "weekday" and "exception" types, which is to say, for any type.
	$prop_list_augment{$name} = 1;
    }
    foreach my $prop ( keys %prop_list_augment ) {
	$property_list{'time_periods'} .= ",$prop";
    }

    # time_period_exclude
    my %time_period_exclude = StorProc->fetch_hash_array_generic_key( 'time_period_exclude', \%where );
    foreach my $key ( keys %time_period_exclude ) {
	my $id      = $time_period_exclude{$key}[0];
	my $exclude = $timeperiod_name{ $time_period_exclude{$key}[1] };
	$timeperiods{$id}{'exclude'} .= "$exclude,";
    }
    foreach my $id ( keys %timeperiods ) {
	chop $timeperiods{$id}{'exclude'} if $timeperiods{$id}{'exclude'};
    }
    $property_list{'time_periods'} .= ",exclude";
}

sub process_timeperiods() {
    my $outfile = qq(##########GROUNDWORK#############################################################################################
#GW
#GW\ttime_periods.cfg generated $date_time by $options{'user_acct'} from monarch.cgi nagios v $options{'nagios_version'}
#GW
##########GROUNDWORK#############################################################################################
);
    my @props = split( /,/, $property_list{'time_periods'} );
    foreach my $id ( sort { $timeperiod_name{$a} cmp $timeperiod_name{$b} } keys %timeperiods ) {
	$outfile .= format_obj( \@props, 'timeperiod', \%{ $timeperiods{$id} } );
    }
    push @out_files, 'time_periods.cfg';
    my $error = write_to_text_file( "$destination/time_periods.cfg", $outfile );
    push( @errors, $error ) if ( defined($error) );
}

############################################################################
# Commands
############################################################################

sub get_commands() {
    my %where = ();

    %commands     = ();
    %command_name = ();
    my %commands_hash_array = StorProc->fetch_list_hash_array( 'commands', \%where );
    foreach my $id ( keys %commands_hash_array ) {
	$command_name{$id}        = $commands_hash_array{$id}[1];
	$commands{$id}{'name'}    = $commands_hash_array{$id}[1];
	$commands{$id}{'type'}    = $commands_hash_array{$id}[2];
	$commands{$id}{'comment'} = $commands_hash_array{$id}[4];
	my %data = StorProc->parse_xml( $commands_hash_array{$id}[3] );
	foreach my $name ( keys %data ) {
	    $commands{$id}{$name} = $data{$name};
	}
    }
}

sub process_commands() {
    my $out_check = qq(##########GROUNDWORK#############################################################################################
#GW
#GW\tcheck_commands.cfg generated $date_time by $options{'user_acct'} from monarch.cgi nagios v $options{'nagios_version'}
#GW
##########GROUNDWORK#############################################################################################
);
    my $out_misc = qq(##########GROUNDWORK#############################################################################################
#GW
#GW\tmisccommands.cfg generated $date_time by $options{'user_acct'} from monarch.cgi nagios v $options{'nagios_version'}
#GW
##########GROUNDWORK#############################################################################################
);

    my @props = ( 'name', 'command_line' );
    foreach my $id ( sort { $command_name{$a} cmp $command_name{$b} } keys %command_name ) {
	my %command = %{ $commands{$id} };
	if ( $command{'type'} eq 'check' ) {
	    $out_check .= format_obj( \@props, 'command', \%command );
	}
	else {
	    $out_misc .= format_obj( \@props, 'command', \%command );
	}
    }
    push @out_files, 'check_commands.cfg';
    my $error = write_to_text_file( "$destination/check_commands.cfg", $out_check );
    push( @errors, $error ) if ( defined($error) );
    push @out_files, 'misccommands.cfg';
    $error = write_to_text_file( "$destination/misccommands.cfg", $out_misc );
    push( @errors, $error ) if ( defined($error) );
}

############################################################################
# Host extended info
############################################################################

sub get_hostextinfo() {
    %host_extinfo_templates = StorProc->get_hostextinfo_templates();
}

sub process_hostextinfo() {
    my $outfile = qq(##########GROUNDWORK#############################################################################################
#GW
#GW\textended_host_info_templates.cfg generated $date_time by $options{'user_acct'} from monarch.cgi nagios v $options{'nagios_version'}
#GW
##########GROUNDWORK#############################################################################################
);

    my @props = split( /,/, $property_list{'extended_host_info_templates'} );
    %hostextinfo_name = ();
    %host_notes       = ();
    %host_notes_url   = ();
    %host_action_url  = ();
    foreach my $name ( sort keys %host_extinfo_templates ) {
	if ( defined $host_extinfo_templates{$name}{'error'} ) {
	    push @errors, "For host extended info template \"$name\":";
	    push @errors, '<pre>' . HTML::Entities::encode( $host_extinfo_templates{$name}{'error'} ) . '</pre>';
	}
	else {
	    $hostextinfo_name{ $host_extinfo_templates{$name}{'id'} } = $name;

	    if ( $options{'nagios_version'} eq '1.x' ) {
		delete $host_extinfo_templates{$name}{'notes'};
	    }
	    else {
		$host_notes{ $host_extinfo_templates{$name}{'id'} } = delete $host_extinfo_templates{$name}{'notes'}
		  if defined( $host_extinfo_templates{$name}{'notes'} )
		      and $host_extinfo_templates{$name}{'notes'} =~ /\$HOSTNAME\$|\$HOSTADDRESS\$/;
	    }

	    $host_notes_url{ $host_extinfo_templates{$name}{'id'} } = delete $host_extinfo_templates{$name}{'notes_url'}
	      if defined( $host_extinfo_templates{$name}{'notes_url'} )
		  and $host_extinfo_templates{$name}{'notes_url'} =~ /\$HOSTNAME\$|\$HOSTADDRESS\$/;

	    if ( $options{'nagios_version'} eq '1.x' ) {
		delete $host_extinfo_templates{$name}{'action_url'};
	    }
	    else {
		$host_action_url{ $host_extinfo_templates{$name}{'id'} } = delete $host_extinfo_templates{$name}{'action_url'}
		  if defined( $host_extinfo_templates{$name}{'action_url'} )
		      and $host_extinfo_templates{$name}{'action_url'} =~ /\$HOSTNAME\$|\$HOSTADDRESS\$/;
	    }

	    $outfile .= format_obj( \@props, 'hostextinfo_template', \%{ $host_extinfo_templates{$name} } );
	}
    }

    if ( $options{'nagios_version'} =~ /^[23]\.x$/ ) {
	push @out_files, 'extended_host_info_templates.cfg';
    }
    else {
	push @extinfofiles, 'extended_host_info_templates.cfg';
    }
    my $error = write_to_text_file( "$destination/extended_host_info_templates.cfg", $outfile );
    push( @errors, $error ) if ( defined($error) );
}

############################################################################
# Contact groups
############################################################################

sub get_contact_groups() {
    my %where = ();

    %contact_groups       = ();
    %contactgroup_name    = ();
    %contactgroup_contact = ();
    my %contactgroup_hash_array = StorProc->fetch_list_hash_array( 'contactgroups', \%where );
    foreach my $id ( keys %contactgroup_hash_array ) {
	my $cname = $contactgroup_hash_array{$id}[1];
	$contactgroup_name{$id}            = $cname;
	$contact_groups{$cname}{'name'}    = $cname;
	$contact_groups{$cname}{'id'}      = $id;
	$contact_groups{$cname}{'alias'}   = $contactgroup_hash_array{$id}[2];
	$contact_groups{$cname}{'comment'} = $contactgroup_hash_array{$id}[3];
    }
    my %contactgroup_contact_hash_array = StorProc->fetch_hash_array_generic_key( 'contactgroup_contact', \%where );
    foreach my $key ( keys %contactgroup_contact_hash_array ) {
	my $cname = $contactgroup_name{ $contactgroup_contact_hash_array{$key}[0] };
	push @{ $contactgroup_contact{$cname} }, $contact_name{ $contactgroup_contact_hash_array{$key}[1] };
    }
}

sub process_contactgroups() {
    my $outfile = qq(##########GROUNDWORK#############################################################################################
#GW
#GW\tcontact_groups.cfg generated $date_time by $options{'user_acct'} from monarch.cgi nagios v $options{'nagios_version'}
#GW
##########GROUNDWORK#############################################################################################
);
    my @props = split( /,/, $property_list{'contactgroups'} );
    push @props, 'members';
    foreach my $cname ( sort keys %{ $use{'contactgroups'} } ) {
	if ( defined $contact_groups{$cname} ) {

	    # FIX THIS
	    if ($debug) {
		if ( defined($cname) ) {
		    print STDERR "cname is '$cname'\n";
		    if ( defined( $contact_groups{$cname} ) ) {
			print STDERR "contact_groups{$cname} is '$contact_groups{$cname}'\n";
		    }
		    else {
			print STDERR "contact_groups{$cname} is undefined\n";
		    }
		}
		else {
		    print STDERR "cname is undefined\n";
		}
	    }

	    my %contactgroup = %{ $contact_groups{$cname} };
	    foreach my $contact ( @{ $contactgroup_contact{$cname} } ) {
		$contactgroup{'members'} .= "$contact,";
		$use{'contacts'}{$contact} = 1;
	    }
	    chop $contactgroup{'members'} if defined $contactgroup{'members'};
	    $contactgroup{'name'} =~ s/\s/-/g;
	    $outfile .= format_obj( \@props, 'contactgroup', \%contactgroup );
	}
	else {
	    ## FIX LATER:  push an error about somewhere referencing a contactgroup that does not exist
	}
    }

    push @out_files, 'contact_groups.cfg';
    my $error = write_to_text_file( "$destination/contact_groups.cfg", $outfile );
    push( @errors, $error ) if ( defined($error) );
}

############################################################################
# Host templates
############################################################################

sub get_host_templates() {
    my %where = ();

    %host_templates    = ();
    %hosttemplate_name = ();
    my %host_template_contactgroup = StorProc->fetch_hash_array_generic_key( 'contactgroup_host_template', \%where );
    my %host_template_hash_array   = StorProc->fetch_list_hash_array( 'host_templates', \%where );
    foreach my $id ( keys %host_template_hash_array ) {
	my $tname = $host_template_hash_array{$id}[1];
	$hosttemplate_name{$id}                        = $tname;
	$host_templates{$tname}{'id'}                  = $id;
	$host_templates{$tname}{'check_period'}        = $host_template_hash_array{$id}[2];
	$host_templates{$tname}{'notification_period'} = $host_template_hash_array{$id}[3];
	$host_templates{$tname}{'check_command'}       = $host_template_hash_array{$id}[4];
	$host_templates{$tname}{'event_handler'}       = $host_template_hash_array{$id}[5];
	my %data = StorProc->parse_xml( $host_template_hash_array{$id}[6] );
	## host template comment not used? would be $host_template_hash_array{$id}[7];
	foreach my $name ( keys %data ) {
	    $host_templates{$tname}{$name} = $data{$name};
	}
    }
    foreach my $key ( keys %host_template_contactgroup ) {
	## get the hosttemplate_id ([1]) from %host_template_contactgroup, and use it as a key
	## to dereference hosttemplate_name, returning the name for the hosttemplate.
	my $tname = $hosttemplate_name{ $host_template_contactgroup{$key}[1] };

	# now get the contactgroup id ([0]) and push it onto the contactgroups array for the $tname host template
	push @{ $host_templates{$tname}{'contactgroups'} }, $host_template_contactgroup{$key}[0];
    }

}

sub process_host_templates() {
    my $outfile = qq(##########GROUNDWORK#############################################################################################
#GW
#GW\thost_templates.cfg generated $date_time by $options{'user_acct'} from monarch.cgi nagios v $options{'nagios_version'}
#GW
##########GROUNDWORK#############################################################################################
);

    my @props = split( /,/, $property_list{'host_templates'} );
    if ( $options{'nagios_version'} =~ /^[23]\.x$/ ) {
	push @props, 'contact_groups';
    }
    foreach my $name ( sort keys %host_templates ) {
	my %template     = ();
	my $command_line = undef;
	foreach my $prop ( keys %{ $host_templates{$name} } ) {
	    if ( $prop eq 'contactgroups' ) {
		foreach my $cgid ( @{ $host_templates{$name}{'contactgroups'} } ) {
		    my $cg = $contactgroup_name{$cgid};
		    $cg =~ s/\s/-/g;
		    $template{'contact_groups'} .= "$cg,";
		    $use{'contactgroups'}{ $contactgroup_name{$cgid} } = 1;
		}
		chop $template{'contact_groups'};
	    }
	    elsif ( $prop eq 'event_handler' || $prop eq 'check_command' ) {
		$template{$prop} = $command_name{ $host_templates{$name}{$prop} } if defined $host_templates{$name}{$prop};
	    }
	    elsif ( $prop =~ /^check_period$|^notification_period$/ ) {
		$template{$prop} = $timeperiod_name{ $host_templates{$name}{$prop} } if defined $host_templates{$name}{$prop};
	    }
	    elsif ( $prop eq 'command_line' ) {
		$command_line = $host_templates{$name}{$prop};
	    }
	    else {
		$template{$prop} = $host_templates{$name}{$prop};
	    }
	}
	if ($command_line) { $template{'check_command'} = $command_line }
	$template{'name'} = $name;
	my @ht_props = @props;
	push @ht_props, grep ( /^_/, keys %template );
	$outfile .= format_obj( \@ht_props, 'host_template', \%template );
    }
    push @out_files, 'host_templates.cfg';
    my $error = write_to_text_file( "$destination/host_templates.cfg", $outfile );
    push( @errors, $error ) if ( defined($error) );
}

############################################################################
# Host groups
############################################################################

sub get_hostgroups() {
    my %where = ();

    %host_groups    = ();
    %hostgroup_name = ();
    my %hostgroup_host         = StorProc->fetch_hash_array_generic_key( 'hostgroup_host', \%where );
    my %hostgroup_contactgroup = StorProc->fetch_hash_array_generic_key( 'contactgroup_hostgroup', \%where );
    my %hostgroup_hash_array   = StorProc->fetch_list_hash_array( 'hostgroups', \%where );
    foreach my $id ( keys %hostgroup_hash_array ) {
	my $hgname = $hostgroup_hash_array{$id}[1];
	$hostgroup_name{$id}           = $hgname;
	$host_groups{$hgname}{'name'}  = $hgname;
	$host_groups{$hgname}{'id'}    = $id;
	$host_groups{$hgname}{'alias'} = $hostgroup_hash_array{$id}[2];
	## hostprofile id not used - not a nagios concept. so no [3]
	$host_groups{$hgname}{'host_escalation_id'}    = $hostgroup_hash_array{$id}[4];
	$host_groups{$hgname}{'service_escalation_id'} = $hostgroup_hash_array{$id}[5];
	## status [6]
	$host_groups{$hgname}{'comment'} = $hostgroup_hash_array{$id}[7];
	$host_groups{$hgname}{'notes'}   = $hostgroup_hash_array{$id}[8];
	@{ $host_groups{$hgname}{'members'} } = ();
    }
    foreach my $key ( keys %hostgroup_host ) {
	## %host_name gets populated in get_hosts(), so that must be called before this.
	my $hgname = $hostgroup_name{ $hostgroup_host{$key}[0] };
	my $hname  =      $host_name{ $hostgroup_host{$key}[1] };
	push @{ $host_groups{$hgname}{'members'} }, $hname;
	push @{ $hosts{$hname}{'hostgroups'} },     $hgname;
    }
    foreach my $key ( keys %hostgroup_contactgroup ) {
	my $hgname = $hostgroup_name{ $hostgroup_contactgroup{$key}[1] };
	push @{ $host_groups{$hgname}{'contactgroups'} }, $contactgroup_name{ $hostgroup_contactgroup{$key}[0] };
    }
}

sub process_hostgroups() {
    my $outfile = qq(##########GROUNDWORK#############################################################################################
#GW
#GW\thostgroups.cfg generated $date_time by $options{'user_acct'} from monarch.cgi nagios v $options{'nagios_version'}
#GW
##########GROUNDWORK#############################################################################################
);

    my @props = split( /,/, $property_list{'hostgroups'} );
    if ( $options{'nagios_version'} eq '1.x' ) { push @props, 'contact_groups' }
    foreach my $name ( sort keys %host_groups ) {
	my %hostgroup = ();
	$hostgroup{'name'}    = $name;
	$hostgroup{'alias'}   = $host_groups{$name}{'alias'};
	$hostgroup{'notes'}   = $host_groups{$name}{'notes'};
	$hostgroup{'comment'} = $host_groups{$name}{'comment'};
	foreach my $host ( sort @{ $host_groups{$name}{'members'} } ) {
	    if ( $use{'hosts'}{$host} ) {
		$hostgroup{'members'} .= "$host,";
		delete $hosts_not_in_hostgroup{$host};
	    }
	}
	chop $hostgroup{'members'} if defined $hostgroup{'members'};
	if ( $options{'nagios_version'} eq '1.x' ) {
	    foreach my $cg ( sort @{ $host_groups{$name}{'contactgroups'} } ) {
		$use{'contactgroups'}{$cg} = 1;
		$cg =~ s/\s/-/g;
		$hostgroup{'contact_groups'} .= "$cg,";
	    }
	    chop $hostgroup{'contact_groups'};
	}
	if ( $hostgroup{'members'} ) {
	    $outfile .= format_obj( \@props, 'hostgroup', \%hostgroup );
	    $use{'hostgroups'}{$name} = 1;
	}
    }
    my $members = undef;
    foreach my $host ( sort keys %hosts_not_in_hostgroup ) {
	$members .= "$host,";
    }
    chop $members if defined $members;
    if ( $audit && $members ) {
	push @log, "\nhostgroup;;__Hosts not in any host group;;alias;;$members";
    }

    push @out_files, 'hostgroups.cfg';
    my $error = write_to_text_file( "$destination/hostgroups.cfg", $outfile );
    push( @errors, $error ) if ( defined($error) );
}

############################################################################
# Hosts
############################################################################

sub get_hosts() {
    my %where = ();

    %hosts        = ();
    %host_name    = ();
    %host_name_id = ();
    my %host_hash_array = StorProc->fetch_list_hash_array( 'hosts', \%where );
    foreach my $id ( keys %host_hash_array ) {
	my $hname = $host_hash_array{$id}[1];
	$host_name{$id}           = $hname;
	$host_name_id{$hname}     = $id;
	$hosts{$hname}{'name'}    = $hname;
	$hosts{$hname}{'id'}      = $id;
	$hosts{$hname}{'alias'}   = $host_hash_array{$id}[2];
	$hosts{$hname}{'address'} = $host_hash_array{$id}[3];
	## [4] os
	$hosts{$hname}{'hosttemplate_id'} = $host_hash_array{$id}[5];
	$hosts{$hname}{'hostextinfo_id'}  = $host_hash_array{$id}[6];
	## [7] hostprofile_id
	$hosts{$hname}{'host_escalation_id'}    = $host_hash_array{$id}[8];
	$hosts{$hname}{'service_escalation_id'} = $host_hash_array{$id}[9];
	## [10] status
	$hosts{$hname}{'comment'} = $host_hash_array{$id}[11];
	$hosts{$hname}{'notes'}   = $host_hash_array{$id}[12];
	@{ $hosts{$hname}{'contactgroups'} }        = ();
	@{ $hosts{$hname}{'hostgroups'} }           = ();
	%{ $hosts{$hname}{'overrides'} }            = ();
	%{ $hosts{$hname}{'extended_info_coords'} } = ();
	%{ $hosts{$hname}{'services'} }             = ();
    }

    # Organize host overrides
    my %host_override_hash_array = StorProc->fetch_list_hash_array( 'host_overrides', \%where );
    foreach my $id ( keys %host_override_hash_array ) {
	my %overrides = ();
	$overrides{'check_period'}        = $host_override_hash_array{$id}[1];
	$overrides{'notification_period'} = $host_override_hash_array{$id}[2];
	$overrides{'check_command'}       = $host_override_hash_array{$id}[3];
	$overrides{'event_handler'}       = $host_override_hash_array{$id}[4];
	my %data = defined( $host_override_hash_array{$id}[5] ) ? StorProc->parse_xml( $host_override_hash_array{$id}[5] ) : ();
	foreach my $name ( keys %data ) {
	    $overrides{$name} = $data{$name};
	}
	%{ $hosts{ $host_name{$id} }{'overrides'} } = %overrides;
    }

    # Assign contact groups to host records
    my %host_contactgroup = StorProc->fetch_hash_array_generic_key( 'contactgroup_host', \%where );
    foreach my $key ( keys %host_contactgroup ) {
	push @{ $hosts{ $host_name{ $host_contactgroup{$key}[1] } }{'contactgroups'} }, $contactgroup_name{ $host_contactgroup{$key}[0] };
    }

    # Assign parents to host records
    my %host_parent = StorProc->fetch_hash_array_generic_key( 'host_parent', \%where );
    foreach my $key ( keys %host_parent ) {
	if (   $host_name{ $host_parent{$key}[1] }
	    && $host_name{ $host_parent{$key}[0] } )
	{
	    $hosts{ $host_name{ $host_parent{$key}[0] } }{'parents'} .= "$host_name{$host_parent{$key}[1]},";
	}
    }

    # Assign extended info coords
    my %extended_info_coords = StorProc->fetch_hash_array_generic_key( 'extended_info_coords', \%where );
    foreach my $key ( keys %extended_info_coords ) {
	%{ $hosts{ $host_name{ $extended_info_coords{$key}[0] } }{'extended_info_coords'} } =
	  StorProc->parse_xml( $extended_info_coords{$key}[1] );
    }
}

sub process_hosts() {
    local $_;

    my %files = ();
    my %top_group_host = ();
    if ( defined($group) && $group_hosts{$group}{'use_hosts'} ) {
	## Prepare just once for efficient lookup below.
	my @direct_hosts = keys %{ $group_hosts{$group}{'hosts'} };
	@top_group_host{@direct_hosts} = (1) x @direct_hosts;
	foreach my $hostgroup ( keys %{ $group_hosts{$group}{'hostgroups'} } ) {
	    @top_group_host{ @{ $host_groups{$hostgroup}{'members'} } } = (1) x @{ $host_groups{$hostgroup}{'members'} };
	}
    }
    foreach my $grp (@group_process_order) {
	my %grp_hosts = ();
	%{ $host_service_group{$grp}{'macros'} } = ();
	if ( $group_hosts{$grp}{'macros'} ) {
	    %{ $host_service_group{$grp}{'macros'} } = %{ $group_hosts{$grp}{'macros'} };
	}
	if (   $group_hosts{$grp}{'label_enabled'}
	    && $group_hosts{$grp}{'label'} )
	{
	    $host_service_group{$grp}{'label'} = "$group_hosts{$grp}{'label'}";
	}
	## FIX MAJOR:  "$host_group{$host} = $grp;" assignments in these loops act as though a host can
	## only belong to one group, when in fact a host can belong to multiple leaf sub-groups.  That fact
	## will affect interpretation of this value when we assign contact groups.  (Also examine how it
	## affects group macro substitutions.)  We use a topological sort of @group_process_order to cover
	## group/sub-group conflicts, but that doesn't cover the case of conflicting leaf sub-groups.
	foreach my $host ( keys %{ $group_hosts{$grp}{'hosts'} } ) {
	    if ( $inactive_hosts{ $host_name_id{$host} } ) {
		push @log, "\ninactive_host;;$host" if $audit;
	    }
	    else {
		## check to see if top-level parent group has force hosts checked
		if ( defined($group) && $group_hosts{$group}{'use_hosts'} ) {
		    ## restrict to top-level parent group hosts
		    if ( $top_group_host{$host} ) {
			$use{'hosts'}{$host} = 1;
			$host_group{$host} = $grp;
			$grp_hosts{$host} = 1;
		    }
		}
		else {
		    $use{'hosts'}{$host} = 1;
		    $host_group{$host} = $grp;
		    $grp_hosts{$host} = 1;
		}
	    }
	}
	foreach my $hostgroup ( keys %{ $group_hosts{$grp}{'hostgroups'} } ) {
	    foreach my $host ( @{ $host_groups{$hostgroup}{'members'} } ) {
		if ( $inactive_hosts{ $host_name_id{$host} } ) {
		    push @log, "\ninactive_host;;$host" if $audit;
		}
		else {
		    ## check to see if top-level parent group has force hosts checked
		    if ( defined($group) && $group_hosts{$group}{'use_hosts'} ) {
			## restrict to top-level parent group hosts
			if ( $top_group_host{$host} ) {
			    $use{'hosts'}{$host} = 1;
			    $host_group{$host} = $grp;
			    $grp_hosts{$host} = 1;
			}
		    }
		    else {
			$use{'hosts'}{$host} = 1;
			$host_group{$host} = $grp;
			$grp_hosts{$host} = 1;
		    }
		}
	    }
	}
	@{ $host_service_group{$grp}{'hosts'} } = sort keys %grp_hosts;
    }

    # GWMON-2118 is required reading.
    my %inherit_prop = (
	host_active     => 'inherit_host_active_checks_enabled',
	host_passive    => 'inherit_host_passive_checks_enabled',
	service_active  => 'inherit_service_active_checks_enabled',
	service_passive => 'inherit_service_passive_checks_enabled'
    );
    my %enabled_prop = (
	host_active     => 'host_active_checks_enabled',
	host_passive    => 'host_passive_checks_enabled',
	service_active  => 'service_active_checks_enabled',
	service_passive => 'service_passive_checks_enabled'
    );
    my %forced_prop = (
	host_active     => 'active_checks_enabled',
	host_passive    => 'passive_checks_enabled',
	service_active  => 'forced_active_checks_enabled',
	service_passive => 'forced_passive_checks_enabled'
    );
    my %collisions = (
	host_active     => 0,
	host_passive    => 0,
	service_active  => 0,
	service_passive => 0
    );
    my %descendant_nodes = ();    # descendants of each node
    my %node_hosts       = ();    # hosts for each node
    ## We skip this processing when analyzing the main configuration.
    if ( defined($group) && $group ne '' ) {
	foreach my $node (@group_process_order) {
	    ## Find all descendants of this node.
	    my %heirs = defined( $group_child{$node} ) ? %{ $group_child{$node} } : ();
	    my @new_heirs = keys %heirs;
	    while (@new_heirs) {
		my @fresh_heirs = @new_heirs;
		@new_heirs = ();
		foreach my $new_heir (@fresh_heirs) {
		    if ( not $heirs{$new_heir} ) {
			$heirs{$new_heir} = 1;
			push @new_heirs, $new_heir;
		    }
		}
	    }
	    my @heirs = keys %heirs;
	    @{ $descendant_nodes{$node} } = \@heirs;

	    ## Find all hosts that belong to this one node, irrespective of its descendants.
	    my %belongs = ();
	    foreach my $host ( keys %{ $group_hosts{$node}{'hosts'} } ) {
		$belongs{$host} = 1;
	    }
	    foreach my $hostgroup ( keys %{ $group_hosts{$node}{'hostgroups'} } ) {
		foreach my $host ( @{ $host_groups{$hostgroup}{'members'} } ) {
		    $belongs{$host} = 1;
		}
	    }
	    $node_hosts{$node} = \%belongs;

	    ## Validate the fields we reference below.
	    foreach my $check_type (keys %inherit_prop) {
		if (   !defined( $group_hosts{$node}{ $inherit_prop{$check_type} } )
		    or !defined( $group_hosts{$node}{ $enabled_prop{$check_type} } ) )
		{
		    push @errors, "Error:  Group \"$node\" is not saved correctly.  Revisit its active/passive settings.";
		    last;
		}
	    }
	}
    }

    my $extinfofile = '';
    my @props       = (
	'name',                   'alias',                     'address',                      'template',
	'parents',                'checks_enabled',            'active_checks_enabled',        'passive_checks_enabled',
	'check_interval',         'check_period',              'obsess_over_host',             'check_command',
	'command_line',           'max_check_attempts',        'event_handler_enabled',        'event_handler',
	'process_perf_data',      'retain_status_information', 'retain_nonstatus_information', 'notifications_enabled',
	'notification_interval',  'notification_period',       'notification_options',         'stalking_options',
	'flap_detection_enabled', 'high_flap_threshold',       'low_flap_threshold',           'check_freshness',
	'freshness_threshold'
    );

    if ( $options{'nagios_version'} =~ /^[23]\.x$/ ) {
	push @props, 'contact_groups';
    }
    if ( $options{'nagios_version'} eq '3.x' ) {
	push @props, 'retry_interval', 'notes';
    }
    my @extinfoprops = split( /,/, $property_list{'extended_host_info'} );
    %hosts_not_in_hostgroup = ();
    %address                = ();
    foreach my $host ( sort keys %host_group ) {
	my %host = %{ $hosts{$host} };
	$host{'template'} = $hosttemplate_name{ $host{'hosttemplate_id'} };
	if ( defined $host{'parents'} ) {
	    chop $host{'parents'};  # removes trailing comma from above
	    my @parents = grep { not $inactive_hosts{ $host_name_id{$_} } } split( /,/, $host{'parents'} );
	    if (@parents) {
		$host{'parents'} = join(',', @parents);
	    }
	    else {
		delete $host{'parents'};
	    }
	}
	if ( $options{'nagios_version'} =~ /^[23]\.x$/ ) {
	    my @host_contact_groups = ();
	    foreach my $cg ( @{ $host{'contactgroups'} } ) {
		$use{'contactgroups'}{$cg} = 1;
		$cg =~ s/\s/-/g;    # Nagios didn't like spaces in contact group names
		push @host_contact_groups, $cg;
	    }
	    unless ( @host_contact_groups ) {
		foreach my $hostgroup ( @{ $host{'hostgroups'} } ) {
		    my %cg_use = ();
		    foreach my $cg ( @{ $host_groups{$hostgroup}{'contactgroups'} } ) {
			unless ( $cg_use{$cg} ) {
			    $use{'contactgroups'}{$cg} = 1;
			    $cg_use{$cg} = 1;
			    (my $unaliased_cg = $cg) =~ s/\s/-/g;
			    push @host_contact_groups, $unaliased_cg;
			}
		    }
		}
		unless ( @host_contact_groups ) {
		    if ( $group_hosts{ $host_group{$host} }{'contactgroups'} ) {
			foreach my $cg ( sort keys %{ $group_hosts{ $host_group{$host} }{'contactgroups'} } ) {
			    $use{'contactgroups'}{$cg} = 1;
			    $cg =~ s/\s/-/g;
			    push @host_contact_groups, $cg;
			}
		    }
		}
	    }
	    if (@host_contact_groups) {
		# de-dupe before joining
		my %unique = ();
		@unique{@host_contact_groups} = (undef) x @host_contact_groups;
		$host{'contact_groups'} = join(',', sort keys %unique);
	    }
	}
	$address{$host} = $host{'address'};
	my %overrides = %{ $hosts{$host}{'overrides'} };
	foreach my $name ( keys %overrides ) {
	    if ( $options{'nagios_version'} =~ /^[23]\.x$/ && $name eq 'check_period' ) {
		$host{'check_period'} = defined( $overrides{$name} ) ? $timeperiod_name{ $overrides{$name} } : undef;
	    }
	    elsif ( $name eq 'notification_period' ) {
		$host{'notification_period'} = defined( $overrides{$name} ) ? $timeperiod_name{ $overrides{$name} } : undef;
	    }
	    elsif ( $name eq 'check_command' ) {
		$host{'check_command'} = defined( $overrides{$name} ) ? $command_name{ $overrides{$name} } : undef;
	    }
	    elsif ( $name eq 'event_handler' ) {
		$host{'event_handler'} = defined( $overrides{$name} ) ? $command_name{ $overrides{$name} } : undef;
	    }
	    elsif ( $name eq 'check_freshness' ) {
		unless ( $options{'nagios_version'} eq '1.x' ) {
		    $host{$name} = $overrides{$name};
		}
	    }
	    elsif ( $name eq 'freshness_threshold' ) {
		unless ( $options{'nagios_version'} eq '1.x' ) {
		    $host{$name} = $overrides{$name};
		}
	    }
	    elsif ( $name eq 'obsess_over_host' ) {
		unless ( $options{'nagios_version'} eq '1.x' ) {
		    $host{$name} = $overrides{$name};
		}
	    }
	    elsif ( $name eq 'active_checks_enabled' ) {
		unless ( $options{'nagios_version'} eq '1.x' ) {
		    $host{$name} = $overrides{$name};
		}
	    }
	    elsif ( $name eq 'passive_checks_enabled' ) {
		unless ( $options{'nagios_version'} eq '1.x' ) {
		    $host{$name} = $overrides{$name};
		}
	    }
	    elsif ( $name eq 'checks_enabled' ) {
		if ( $options{'nagios_version'} eq '1.x' ) {
		    $host{$name} = $overrides{$name};
		}
	    }
	    else {
		$host{$name} = $overrides{$name};
	    }
	}

	# GWMON-2118
	if ( defined($group) && $group ne '' ) {
	    my %host_nodes = ();
	    foreach my $node (@group_process_order) {
		$host_nodes{$node} = 1 if $node_hosts{$node}{$host};
	    }

	    foreach my $check_type (keys %inherit_prop) {
		my %forced_host_nodes = ();    # host nodes with a "forced" (non-inherited) setting
		foreach my $node ( keys %host_nodes ) {
		    $forced_host_nodes{$node} = 1 if not $group_hosts{$node}{ $inherit_prop{$check_type} };
		}
		my @effective_leaf_nodes = ();
		foreach my $node ( keys %forced_host_nodes ) {
		    my $leaf = 1;
		    foreach my $descendant ( @{ $descendant_nodes{$node} } ) {
			if ( $forced_host_nodes{$descendant} ) {
			    $leaf = 0;
			    last;
			}
		    }
		    push @effective_leaf_nodes, $node if $leaf;
		}
		next if not @effective_leaf_nodes;    # no override applies to $host for $check_type; main configuration prevails
		my $is_consistent = 1;
		my $e_prop        = $enabled_prop{$check_type};
		my $node_0        = $effective_leaf_nodes[0];
		my $override_0    = $group_hosts{$node_0}{$e_prop};
		foreach my $node_n ( @effective_leaf_nodes[ 1 .. $#effective_leaf_nodes ] ) {
		    if ( $group_hosts{$node_n}{$e_prop} ne $override_0 ) {
			$is_consistent = 0;
			## collision:  for simplicity, just default to the existing main configuration
			if ( $collisions{$check_type}++ == 0 ) {
			    (my $prop = $e_prop) =~ s/_/ /g;
			    push @errors,
				"For host \"$host\", the settings for \"\u$prop\" are in conflict for groups \"$node_0\" and \"$node_n\"."
			      . '  (To avoid a flood of error messages, only the first error of this type is being reported.)';
			}
			last;
		    }
		}
		if ($is_consistent) {
		    if ($check_type =~ /^host_/) {
			## Override the main configuration with the forced setting.
			$host{ $forced_prop{$check_type} } = $override_0;
		    }
		    elsif ($check_type =~ /^service_/) {
			## Save this result globally for use with this host's services.
			$host_service_group{$group}{ $forced_prop{$check_type} }{$host} = $override_0;
		    }
		}
	    }
	}

	my %host_extinfo = ();
	my %coords       = %{ $hosts{$host}{'extended_info_coords'} };
	if (%coords) {
	    $host_extinfo{$host}{'2d_coords'} = $coords{'2d_coords'};
	    $host_extinfo{$host}{'3d_coords'} = $coords{'3d_coords'};
	}
	if ( $host{'hostextinfo_id'} ) {
	    $host_extinfo{$host}{'template'} = $hostextinfo_name{ $host{'hostextinfo_id'} };
	    unless ( $options{'nagios_version'} eq '1.x' ) {
		my $edited_notes = $host_notes{ $host{'hostextinfo_id'} };
		if ( defined $edited_notes ) {
		    $edited_notes =~ s/\$HOSTNAME\$/$host/g;
		    $edited_notes =~ s/\$HOSTADDRESS\$/$host{'address'}/g;
		    $host_extinfo{$host}{'notes'} = $edited_notes;
		}
	    }
	    my $edited_notes_url = $host_notes_url{ $host{'hostextinfo_id'} };
	    if ( defined $edited_notes_url ) {
		$edited_notes_url =~ s/\$HOSTNAME\$/$host/g;
		$edited_notes_url =~ s/\$HOSTADDRESS\$/$host{'address'}/g;
		$host_extinfo{$host}{'notes_url'} = $edited_notes_url;
	    }
	    unless ( $options{'nagios_version'} eq '1.x' ) {
		my $edited_action_url = $host_action_url{ $host{'hostextinfo_id'} };
		if ( defined $edited_action_url ) {
		    $edited_action_url =~ s/\$HOSTNAME\$/$host/g;
		    $edited_action_url =~ s/\$HOSTADDRESS\$/$host{'address'}/g;
		    $host_extinfo{$host}{'action_url'} = $edited_action_url;
		}
	    }
	}
	if (%host_extinfo) {
	    $host_extinfo{$host}{'host_name'} = $host;
	    $extinfofile .= format_obj( \@extinfoprops, 'hostextinfo', \%{ $host_extinfo{$host} } );
	}
	$hosts_not_in_hostgroup{$host} = 1;
	my @h_props = @props;
	push @h_props, grep ( /^_/, keys %host );
	$files{ $host_group{$host} } .= format_obj( \@h_props, 'host', \%host );
    }

    if ( defined($group) && $group ne '' ) {
	foreach my $check_type (keys %inherit_prop) {
	    my $conflicts = $collisions{$check_type};
	    if ($conflicts) {
		(my $prop = $enabled_prop{$check_type}) =~ s/_/ /g;
		push @errors,
		    "Error:  $conflicts conflict"
		  . ( $conflicts == 1 ? '' : 's' )
		  . " in \"\u$prop\" settings "
		  . ( $conflicts == 1 ? 'was' : 'were' )
		  . ' detected in this run.';
	    }
	}
    }

    foreach my $grp ( sort keys %files ) {
	my $file = $grp eq ':all:' ? 'hosts.cfg' : "$grp\_hosts.cfg";
	my $outfile = qq(##########GROUNDWORK#############################################################################################
#GW
#GW\t$file generated $date_time by $options{'user_acct'} from monarch.cgi nagios v $options{'nagios_version'}
#GW
##########GROUNDWORK#############################################################################################

$files{$grp}
);
	push @out_files, $file;
	my $error = write_to_text_file( "$destination/$file", $outfile );
	push( @errors, $error ) if ( defined($error) );
    }

    @extinfofiles = ();

    my $outfile = qq(##########GROUNDWORK#############################################################################################
#GW
#GW\textended_host_info.cfg generated $date_time by $options{'user_acct'} from monarch.cgi nagios v $options{'nagios_version'}
#GW
##########GROUNDWORK#############################################################################################

$extinfofile
);

    if ( $options{'nagios_version'} =~ /^[23]\.x$/ ) {
	push @out_files, 'extended_host_info.cfg';
    }
    else {
	push @extinfofiles, 'extended_host_info.cfg';
    }
    my $error = write_to_text_file( "$destination/extended_host_info.cfg", $outfile );
    push( @errors, $error ) if ( defined($error) );
}

############################################################################
# Host dependencies
############################################################################

sub get_host_dependencies() {
    %host_dependencies = StorProc->get_host_dependencies();
}

sub process_host_dependencies() {
    my $outfile = qq(##########GROUNDWORK#############################################################################################
#GW
#GW\thost_dependencies.cfg generated $date_time by $options{'user_acct'} from monarch.cgi nagios v $options{'nagios_version'}
#GW
##########GROUNDWORK#############################################################################################
);
    my @props = ( 'dependent_host_name', 'host_name', 'inherits_parent', 'execution_failure_criteria', 'notification_failure_criteria' );
    foreach my $host_id ( keys %host_dependencies ) {
	if ( $use{'hosts'}{ $host_name{$host_id} } ) {
	    foreach my $parent_id ( keys %{ $host_dependencies{$host_id} } ) {
		if ( $use{'hosts'}{ $host_name{$parent_id} } ) {
		    my %dependency = (
			'dependent_host_name'           => $host_name{$host_id},
			'host_name'                     => $host_name{$parent_id},
			'notification_failure_criteria' => $host_dependencies{$host_id}{$parent_id}{'notification_failure_criteria'}
		    );
		    if ( $options{'nagios_version'} =~ /^[23]\.x$/ ) {
			$dependency{'inherits_parent'}            = $host_dependencies{$host_id}{$parent_id}{'inherits_parent'};
			$dependency{'execution_failure_criteria'} = $host_dependencies{$host_id}{$parent_id}{'execution_failure_criteria'};
		    }
		    $outfile .= format_obj( \@props, 'hostdependency', \%dependency );
		}
	    }
	}
    }
    push @out_files, 'host_dependencies.cfg';
    my $error = write_to_text_file( "$destination/host_dependencies.cfg", $outfile );
    push( @errors, $error ) if ( defined($error) );
}

############################################################################
# Service extended info
############################################################################

sub get_serviceextinfo() {
    %service_extinfo_templates = StorProc->get_serviceextinfo_templates();
}

sub process_serviceextinfo() {
    my $outfile = qq(##########GROUNDWORK#############################################################################################
#GW
#GW\textended_service_info_templates.cfg generated $date_time by $options{'user_acct'} from monarch.cgi nagios v $options{'nagios_version'}
#GW
##########GROUNDWORK#############################################################################################
);

    %serviceextinfo_name = ();
    %service_notes       = ();
    %service_notes_url   = ();
    %service_action_url  = ();
    my @props = split( /,/, $property_list{'extended_service_info_templates'} );
    foreach my $name ( sort keys %service_extinfo_templates ) {
	if ( defined $service_extinfo_templates{$name}{'error'} ) {
	    push @errors, "For service extended info template \"$name\":";
	    push @errors, '<pre>' . HTML::Entities::encode( $service_extinfo_templates{$name}{'error'} ) . '</pre>';
	}
	else {
	    $serviceextinfo_name{ $service_extinfo_templates{$name}{'id'} } = $name;

	    if ( $options{'nagios_version'} eq '1.x' ) {
		delete $service_extinfo_templates{$name}{'notes'};
	    }
	    else {
		$service_notes{ $service_extinfo_templates{$name}{'id'} } = delete $service_extinfo_templates{$name}{'notes'}
		  if defined( $service_extinfo_templates{$name}{'notes'} )
		      and $service_extinfo_templates{$name}{'notes'} =~
		      /\$HOSTNAME\$|\$HOSTADDRESS\$|\$SERVICENAME\$|\$SERVICEDESC\$|\$SERVICEDESCRIPTION\$/;
	    }

	    $service_notes_url{ $service_extinfo_templates{$name}{'id'} } = delete $service_extinfo_templates{$name}{'notes_url'}
	      if defined( $service_extinfo_templates{$name}{'notes_url'} )
		  and $service_extinfo_templates{$name}{'notes_url'} =~
		  /\$HOSTNAME\$|\$HOSTADDRESS\$|\$SERVICENAME\$|\$SERVICEDESC\$|\$SERVICEDESCRIPTION\$/;

	    if ( $options{'nagios_version'} eq '1.x' ) {
		delete $service_extinfo_templates{$name}{'action_url'};
	    }
	    else {
		$service_action_url{ $service_extinfo_templates{$name}{'id'} } = delete $service_extinfo_templates{$name}{'action_url'}
		  if defined( $service_extinfo_templates{$name}{'action_url'} )
		      and $service_extinfo_templates{$name}{'action_url'} =~
		      /\$HOSTNAME\$|\$HOSTADDRESS\$|\$SERVICENAME\$|\$SERVICEDESC\$|\$SERVICEDESCRIPTION\$/;
	    }

	    $outfile .= format_obj( \@props, 'serviceextinfo_template', \%{ $service_extinfo_templates{$name} } );
	}
    }

    if ( $options{'nagios_version'} =~ /^[23]\.x$/ ) {
	push @out_files, 'extended_service_info_templates.cfg';
    }
    else {
	push @extinfofiles, 'extended_service_info_templates.cfg';
    }
    my $error = write_to_text_file( "$destination/extended_service_info_templates.cfg", $outfile );
    push( @errors, $error ) if ( defined($error) );
}

############################################################################
# Services
############################################################################

sub get_services() {
    my @timings = ();
    my $phasetime;

    StorProc->start_timing( \$phasetime );

    # Get service groups
    %service_groups = StorProc->get_service_groups();
    StorProc->capture_timing( \@timings, \$phasetime, 'getting service groups' );

    # Get service templates
    %servicetemplate_name = ();
    %service_templates = StorProc->get_service_templates();
    foreach my $tname ( keys %service_templates ) {
	$servicetemplate_name{ $service_templates{$tname}{'id'} } = $tname;
    }
    StorProc->capture_timing( \@timings, \$phasetime, 'getting service templates' );

    # Services
    %servicename_name = StorProc->get_table_objects( 'service_names', '1' );
    StorProc->capture_timing( \@timings, \$phasetime, 'getting table objects' );

    %service_instances = ();
    my %where = ();
    my %service_hash_array = StorProc->fetch_list_hash_array( 'services', \%where );
    StorProc->capture_timing( \@timings, \$phasetime, 'getting services hash' );

    my %service_override_hash_array = StorProc->fetch_list_hash_array( 'service_overrides', \%where );
    StorProc->capture_timing( \@timings, \$phasetime, 'getting service overrides hash' );

    my $use_alternate_code = 1;
    if ($use_alternate_code) {
	my %service_contact_groups = ();
	%where = ();
	my %contactgroup_service_hash = StorProc->fetch_hash_array_generic_key( 'contactgroup_service', \%where );
	foreach my $key ( keys %contactgroup_service_hash ) {
	    push @{ $service_contact_groups{ $contactgroup_service_hash{$key}[1] } }, $contactgroup_name{ $contactgroup_service_hash{$key}[0] };
	}
	if (1) {
	    ## FIX THIS:  adopt this as the standard code
	    foreach my $id ( keys %service_hash_array ) {
		%{ $service_instances{$id} } = ();
		my $saref = \@{ $service_hash_array{$id} };
		my $hname = $host_name{ $saref->[1] };
		my $hsref = \%{ $hosts{$hname}{'services'}{$id} };
		$hsref->{'servicename_id'}     = $saref->[2];
		$hsref->{'servicetemplate_id'} = $saref->[3];
		$hsref->{'serviceextinfo_id'}  = $saref->[4];
		$hsref->{'escalation_id'}      = $saref->[5];
		## [6] status
		$hsref->{'check_command'} = $saref->[7];
		$hsref->{'command_line'}  = $saref->[8];
		$hsref->{'comment'}       = $saref->[9];
		$hsref->{'notes'}         = $saref->[10];
		if ( $service_override_hash_array{$id} ) {
		    $hsref->{'check_period'}        = $service_override_hash_array{$id}[1];
		    $hsref->{'notification_period'} = $service_override_hash_array{$id}[2];
		    $hsref->{'event_handler'}       = $service_override_hash_array{$id}[3];
		    ## Note:  this parsing is the current processing-time bottleneck
		    my %data = StorProc->parse_xml( $service_override_hash_array{$id}[4] );
		    foreach my $prop ( keys %data ) {
			$hsref->{$prop} = $data{$prop};
		    }
		}
		if ($service_contact_groups{$id}) {
		    $hsref->{'contactgroups'} = $service_contact_groups{$id};
		}
	    }
	}
	else {
	    ## FIX THIS:  drop this now-obsolete code
	    foreach my $id ( keys %service_hash_array ) {
		%{ $service_instances{$id} } = ();
		my $hname = $host_name{ $service_hash_array{$id}[1] };
		$hosts{$hname}{'services'}{$id}{'servicename_id'}     = $service_hash_array{$id}[2];
		$hosts{$hname}{'services'}{$id}{'servicetemplate_id'} = $service_hash_array{$id}[3];
		$hosts{$hname}{'services'}{$id}{'serviceextinfo_id'}  = $service_hash_array{$id}[4];
		$hosts{$hname}{'services'}{$id}{'escalation_id'}      = $service_hash_array{$id}[5];
		## [6] status
		$hosts{$hname}{'services'}{$id}{'check_command'} = $service_hash_array{$id}[7];
		$hosts{$hname}{'services'}{$id}{'command_line'}  = $service_hash_array{$id}[8];
		$hosts{$hname}{'services'}{$id}{'comment'}       = $service_hash_array{$id}[9];
		$hosts{$hname}{'services'}{$id}{'notes'}         = $service_hash_array{$id}[10];
		if ( $service_override_hash_array{$id} ) {
		    $hosts{$hname}{'services'}{$id}{'check_period'}        = $service_override_hash_array{$id}[1];
		    $hosts{$hname}{'services'}{$id}{'notification_period'} = $service_override_hash_array{$id}[2];
		    $hosts{$hname}{'services'}{$id}{'event_handler'}       = $service_override_hash_array{$id}[3];
		    ## Note:  this parsing is the current processing-time bottleneck
		    my %data = StorProc->parse_xml( $service_override_hash_array{$id}[4] );
		    foreach my $prop ( keys %data ) {
			$hosts{$hname}{'services'}{$id}{$prop} = $data{$prop};
		    }
		}
		if ($service_contact_groups{$id}) {
		    $hosts{$hname}{'services'}{$id}{'contactgroups'} = $service_contact_groups{$id};
		}
	    }
	}
    }
    else {
	foreach my $id ( keys %service_hash_array ) {
	    %where = ( 'service_id' => $id );
	    my %contactgroup_service_hash = StorProc->fetch_hash_array_generic_key( 'contactgroup_service', \%where );
	    %{ $service_instances{$id} } = ();
	    my $hname = $host_name{ $service_hash_array{$id}[1] };
	    $hosts{$hname}{'services'}{$id}{'servicename_id'}     = $service_hash_array{$id}[2];
	    $hosts{$hname}{'services'}{$id}{'servicetemplate_id'} = $service_hash_array{$id}[3];
	    $hosts{$hname}{'services'}{$id}{'serviceextinfo_id'}  = $service_hash_array{$id}[4];
	    $hosts{$hname}{'services'}{$id}{'escalation_id'}      = $service_hash_array{$id}[5];
	    ## [6] status
	    $hosts{$hname}{'services'}{$id}{'check_command'} = $service_hash_array{$id}[7];
	    $hosts{$hname}{'services'}{$id}{'command_line'}  = $service_hash_array{$id}[8];
	    $hosts{$hname}{'services'}{$id}{'comment'}       = $service_hash_array{$id}[9];
	    $hosts{$hname}{'services'}{$id}{'notes'}         = $service_hash_array{$id}[10];
	    if ( $service_override_hash_array{$id} ) {
		$hosts{$hname}{'services'}{$id}{'check_period'}        = $service_override_hash_array{$id}[1];
		$hosts{$hname}{'services'}{$id}{'notification_period'} = $service_override_hash_array{$id}[2];
		$hosts{$hname}{'services'}{$id}{'event_handler'}       = $service_override_hash_array{$id}[3];
		my %data = StorProc->parse_xml( $service_override_hash_array{$id}[4] );
		foreach my $prop ( keys %data ) {
		    $hosts{$hname}{'services'}{$id}{$prop} = $data{$prop};
		}
	    }
	    foreach my $key ( keys %contactgroup_service_hash ) {
		if ( $id == $contactgroup_service_hash{$key}[1] ) {
		    push @{ $hosts{$hname}{'services'}{$id}{'contactgroups'} }, $contactgroup_name{ $contactgroup_service_hash{$key}[0] };
		}
	    }
	}
    }
    StorProc->capture_timing( \@timings, \$phasetime, 'getting contact groups hash' );

    %where = ();
    my %service_instance_hash_array = StorProc->fetch_list_hash_array( 'service_instance', \%where );
    foreach my $id ( keys %service_instance_hash_array ) {
	my $sid   = $service_instance_hash_array{$id}[1];
	my $iname = $service_instance_hash_array{$id}[2];
	$service_instances{$sid}{$iname}{'status'} = $service_instance_hash_array{$id}[3];
	$service_instances{$sid}{$iname}{'args'}   = $service_instance_hash_array{$id}[4];
	$service_instances{$sid}{$iname}{'id'}     = $id;
    }
    StorProc->capture_timing( \@timings, \$phasetime, 'getting service instance hash' );

    %service_dependency_templates = StorProc->get_service_dependency_templates();
    StorProc->capture_timing( \@timings, \$phasetime, 'getting service dependency templates' );

    %service_dependencies = StorProc->fetch_list_hash_array( 'service_dependency', \%where );
    StorProc->capture_timing( \@timings, \$phasetime, 'getting service dependencies' );

    return \@timings;
}

sub process_services() {

    # build all instances of service checks
    my %host_instances   = ();
    my %instance_group   = ();
    my %host_ext_service = ();
    my $extinfofile      = '';
    my @props            = split( /,/, $property_list{'services'} );
    foreach my $grp ( sort keys %host_service_group ) {
	foreach my $host ( sort @{ $host_service_group{$grp}{'hosts'} } ) {
	    my %service_extinfo  = ();
	    my %services = %{ $hosts{$host}{'services'} };

	    my $forced_active  = $host_service_group{$group}{'forced_active_checks_enabled'}{$host};
	    my $forced_passive = $host_service_group{$group}{'forced_passive_checks_enabled'}{$host};

	    # determine all service instances for the host and apply macros to check command
	    foreach my $sid ( keys %services ) {
		## my %instances = StorProc->get_service_instances($sid);
		my %instances = %{ $service_instances{$sid} };
		if (%instances) {
		    foreach my $instance ( keys %instances ) {
			if ( $instances{$instance}{'status'} ) {
			    my $instance_name = "$servicename_name{$services{$sid}{'servicename_id'}}$instance";
			    if ( $host_service_group{$grp}{'label'} ) {
				$instance_name =
				  "$servicename_name{$services{$sid}{'servicename_id'}}$instance$host_service_group{$grp}{'label'}";
			    }

			    # Add all props from the service to the instance
			    foreach my $prop ( keys %{ $services{$sid} } ) {
				unless ( $prop eq 'check_command' ) {
				    $host_instances{$host}{$instance_name}{$prop} = $services{$sid}{$prop};
				}
			    }

			    # apply instance arguments and macros to check command
			    # but has it been processed in a previous group?
			    my $got_match = 0;
			    if ( $host_instances{$host}{$instance_name}{'check_command'} ) {
				## yes - only apply macros
				foreach my $macro ( keys %{ $host_service_group{$grp}{'macros'} } ) {
				    if ( $host_instances{$host}{$instance_name}{'check_command'} =~ /$macro/ ) {
					$got_match = 1;
				    }
				    $host_instances{$host}{$instance_name}{'check_command'} =~
				      s/$macro/$host_service_group{$grp}{'macros'}{$macro}/g;
				}
			    }
			    else {
				## no - get args and apply macros
				if ( $instances{$instance}{'args'} ) {
				    $instances{$instance}{'args'} =~ s/^!//;
				    my $check_command_name = defined( $services{$sid}{'check_command'} ) ?
				      $command_name{ $services{$sid}{'check_command'} } : '';
				    $host_instances{$host}{$instance_name}{'check_command'} = "$check_command_name!$instances{$instance}{'args'}";
				    foreach my $macro ( keys %{ $host_service_group{$grp}{'macros'} } ) {
					if ( $host_instances{$host}{$instance_name}{'check_command'} =~ /$macro/ ) {
					    $got_match = 1;
					}
					$host_instances{$host}{$instance_name}{'check_command'} =~
					  s/$macro/$host_service_group{$grp}{'macros'}{$macro}/g;
				    }
				}
			    }

			    # when processing a group label and there is not a macro match don't use the instance
			    if ( $host_service_group{$grp}{'label'} && !$got_match ) {
				delete $host_instances{$host}{$instance_name};
				next;
			    }

			    # for use in applying dependencies and escalations
			    $use{'services'}{$sid}{$instance_name} = 1;

			    # assigns to file of last group read
			    $instance_group{$host}{$instance_name} = $grp;

			    # this seems to have no purpose: $service_name{$instance_name}{'name'} = 1;
			    $host_instances{$host}{$instance_name}{'name'}      = $instance_name;
			    $host_instances{$host}{$instance_name}{'host_name'} = $host;
			    $host_instances{$host}{$instance_name}{'template'} = $servicetemplate_name{ $services{$sid}{'servicetemplate_id'} };
			    $use{'service_templates'}{ $services{$sid}{'template'} } = 1 if defined $services{$sid}{'template'};
			    $host_instances{$host}{$instance_name}{'check_period'} = defined( $services{$sid}{'check_period'} ) ?
			      $timeperiod_name{ $services{$sid}{'check_period'} } : undef;
			    $host_instances{$host}{$instance_name}{'notification_period'} = defined( $services{$sid}{'notification_period'} ) ?
			      $timeperiod_name{ $services{$sid}{'notification_period'} } : undef;
			    $host_instances{$host}{$instance_name}{'event_handler'} = defined( $services{$sid}{'event_handler'} ) ?
			      $command_name{ $services{$sid}{'event_handler'} } : undef;

			    # we don't want to assign redundant contact groups
			    unless ( $host_instances{$host}{$instance_name}{'contactgroup'} ) {
				foreach my $cg ( @{ $services{$sid}{'contactgroups'} } ) {
				    $use{'contactgroups'}{$cg} = 1;
				    $cg =~ s/\s/-/g;
				    $host_instances{$host}{$instance_name}{'contactgroup'} .= "$cg,";
				}
				chop $host_instances{$host}{$instance_name}{'contactgroup'}
				  if defined( $host_instances{$host}{$instance_name}{'contactgroup'} );
			    }

			    # if we don't have a contact group yet get it from the group
			    unless ( $host_instances{$host}{$instance_name}{'contactgroup'} ) {
				foreach my $cg ( sort keys %{ $group_hosts{ $host_group{$host} }{'contactgroups'} } ) {
				    $use{'contactgroups'}{$cg} = 1;
				    $cg =~ s/\s/-/g;
				    $host_instances{$host}{$instance_name}{'contactgroup'} .= "$cg,";
				}
				chop $host_instances{$host}{$instance_name}{'contactgroup'}
				  if defined( $host_instances{$host}{$instance_name}{'contactgroup'} );
			    }

			    # possibly apply global positive or negative overrides computed earlier
			    $host_instances{$host}{$instance_name}{'active_checks_enabled'}  = $forced_active  if defined $forced_active;
			    $host_instances{$host}{$instance_name}{'passive_checks_enabled'} = $forced_passive if defined $forced_passive;

			    # if extended service info is defined we create an entry for each instance, but only once
			    if ( $services{$sid}{'serviceextinfo_id'} && !$service_extinfo{$instance_name} ) {
				my @extinfoprops = ( 'template', 'service_description', 'host_name', 'notes', 'notes_url', 'action_url' );
				$service_extinfo{$instance_name}{'host_name'}           = $host;
				$service_extinfo{$instance_name}{'service_description'} = $instance_name;
				$service_extinfo{$instance_name}{'template'} = $serviceextinfo_name{ $services{$sid}{'serviceextinfo_id'} };

				unless ( $options{'nagios_version'} eq '1.x' ) {
				    my $edited_notes = $service_notes{ $services{$sid}{'serviceextinfo_id'} };
				    if ( defined $edited_notes ) {
					$edited_notes =~ s/\$HOSTNAME\$/$host/g;
					$edited_notes =~ s/\$HOSTADDRESS\$/$address{$host}/g;
					$edited_notes =~ s/\$SERVICENAME\$|\$SERVICEDESC\$|\$SERVICEDESCRIPTION\$/$instance_name/g;
					$service_extinfo{$instance_name}{'notes'} = $edited_notes;
				    }
				}

				my $edited_notes_url = $service_notes_url{ $services{$sid}{'serviceextinfo_id'} };
				if ( defined $edited_notes_url ) {
				    $edited_notes_url =~ s/\$HOSTNAME\$/$host/g;
				    $edited_notes_url =~ s/\$HOSTADDRESS\$/$address{$host}/g;
				    $edited_notes_url =~ s/\$SERVICENAME\$|\$SERVICEDESC\$|\$SERVICEDESCRIPTION\$/$instance_name/g;
				    $service_extinfo{$instance_name}{'notes_url'} = $edited_notes_url;
				}

				unless ( $options{'nagios_version'} eq '1.x' ) {
				    my $edited_action_url = $service_action_url{ $services{$sid}{'serviceextinfo_id'} };
				    if ( defined $edited_action_url ) {
					$edited_action_url =~ s/\$HOSTNAME\$/$host/g;
					$edited_action_url =~ s/\$HOSTADDRESS\$/$address{$host}/g;
					$edited_action_url =~ s/\$SERVICENAME\$|\$SERVICEDESC\$|\$SERVICEDESCRIPTION\$/$instance_name/g;
					$service_extinfo{$instance_name}{'action_url'} = $edited_action_url;
				    }
				}

				unless ( $host_ext_service{$host}{$instance_name} ) {
				    $extinfofile .= format_obj( \@extinfoprops, 'serviceextinfo', \%{ $service_extinfo{$instance_name} } );
				    $host_ext_service{$host}{$instance_name} = 1;
				}
			    }

			    # for every entry of the service in a service group create an entry for each instance
			    foreach my $sg ( keys %service_groups ) {
				if ( $service_groups{$sg}{'hosts'}{ $host_name_id{$host} }{$sid} ) {
				    $use{'servicegroups'}{$sg} = 1;
				    $service_groups{$sg}{'members'} .= "$host,$instance_name,";
				}
			    }
			}
		    }
		}
		else {
		    my $svcdesc = $servicename_name{ $services{$sid}{'servicename_id'} };
		    if ( $host_service_group{$grp}{'label'} ) {
			$svcdesc = "$svcdesc$host_service_group{$grp}{'label'}";
		    }

		    # Add all props from the service to the instance
		    foreach my $prop ( keys %{ $services{$sid} } ) {
			$host_instances{$host}{$svcdesc}{$prop} = $services{$sid}{$prop};
		    }
		    $host_instances{$host}{$svcdesc}{'check_command'} = $services{$sid}{'command_line'};
		    unless ( $host_instances{$host}{$svcdesc}{'check_command'} ) {
			$host_instances{$host}{$svcdesc}{'check_command'} = defined( $services{$sid}{'check_command'} ) ?
			  $command_name{ $services{$sid}{'check_command'} } : undef;
		    }

		    # FIX MINOR:  This loop and the loops in which it is embedded are ripe for further optimization,
		    # by not running repeated identical hash lookups (here $host_instances{$host}{$svcdesc}, above
		    # $host_instances{$host}{$instance_name}, for example).  Test with large customer configurations.
		    my $got_match = 0;
		    $host_instances{$host}{$svcdesc}{'name'} = $svcdesc;
		    if ( defined $host_instances{$host}{$svcdesc}{'check_command'} ) {
			foreach my $macro ( keys %{ $host_service_group{$grp}{'macros'} } ) {
			    if ( $host_instances{$host}{$svcdesc}{'check_command'} =~ /$macro/ ) {
				$got_match = 1;
			    }
			    $host_instances{$host}{$svcdesc}{'check_command'} =~ s/$macro/$host_service_group{$grp}{'macros'}{$macro}/g;
			}
		    }

		    # when processing a group label and there is not a macro match don't use the instance
		    if ( $host_service_group{$grp}{'label'} && !$got_match ) {
			delete $host_instances{$host}{$svcdesc};
			next;
		    }

		    # for use in applying dependencies and escalations
		    $use{'services'}{$sid}{$svcdesc} = 1;

		    # assigns to file of last group read
		    $instance_group{$host}{$svcdesc} = $grp;

		    # apply values to the rest of the props
		    #  this seems to have no purpose: $service_name{$svcdesc}{'name'} = 1;
		    $host_instances{$host}{$svcdesc}{'host_name'}            = $host;
		    $host_instances{$host}{$svcdesc}{'template'}             = $servicetemplate_name{ $services{$sid}{'servicetemplate_id'} };
		    $use{'service_templates'}{ $services{$sid}{'template'} } = 1 if defined $services{$sid}{'template'};
		    $host_instances{$host}{$svcdesc}{'check_period'} =
		      defined( $services{$sid}{'check_period'} ) ? $timeperiod_name{ $services{$sid}{'check_period'} } : undef;
		    $host_instances{$host}{$svcdesc}{'notification_period'} =
		      defined( $services{$sid}{'notification_period'} ) ? $timeperiod_name{ $services{$sid}{'notification_period'} } : undef;
		    $host_instances{$host}{$svcdesc}{'event_handler'} =
		      defined( $services{$sid}{'event_handler'} ) ? $command_name{ $services{$sid}{'event_handler'} } : undef;

		    # we don't want to assign redundant contact groups
		    unless ( $host_instances{$host}{$svcdesc}{'contactgroup'} ) {
			foreach my $cg ( @{ $services{$sid}{'contactgroups'} } ) {
			    $use{'contactgroups'}{$cg} = 1;
			    $cg =~ s/\s/-/g;
			    $host_instances{$host}{$svcdesc}{'contactgroup'} .= "$cg,";
			}
			chop $host_instances{$host}{$svcdesc}{'contactgroup'}
			  if ( defined( $host_instances{$host}{$svcdesc}{'contactgroup'} ) );
		    }

		    # if we don't have a contact group yet get it from the group
		    unless ( $host_instances{$host}{$svcdesc}{'contactgroup'} ) {
			foreach my $cg ( sort keys %{ $group_hosts{ $host_group{$host} }{'contactgroups'} } ) {
			    $use{'contactgroups'}{$cg} = 1;
			    $cg =~ s/\s/-/g;
			    $host_instances{$host}{$svcdesc}{'contactgroup'} .= "$cg,";
			}
			chop $host_instances{$host}{$svcdesc}{'contactgroup'}
			  if ( defined( $host_instances{$host}{$svcdesc}{'contactgroup'} ) );
		    }

		    # possibly apply global positive or negative overrides computed earlier
		    $host_instances{$host}{$svcdesc}{'active_checks_enabled'}  = $forced_active  if defined $forced_active;
		    $host_instances{$host}{$svcdesc}{'passive_checks_enabled'} = $forced_passive if defined $forced_passive;

		    # if extended service info is defined we create an entry
		    if ( $services{$sid}{'serviceextinfo_id'} ) {
			my @extinfoprops = ( 'template', 'service_description', 'host_name', 'notes', 'notes_url', 'action_url' );
			$service_extinfo{$svcdesc}{'host_name'}           = $host;
			$service_extinfo{$svcdesc}{'service_description'} = $svcdesc;
			$service_extinfo{$svcdesc}{'template'}            = $serviceextinfo_name{ $services{$sid}{'serviceextinfo_id'} };

			unless ( $options{'nagios_version'} eq '1.x' ) {
			    my $edited_notes = $service_notes{ $services{$sid}{'serviceextinfo_id'} };
			    if ( defined $edited_notes ) {
				$edited_notes =~ s/\$HOSTNAME\$/$host/g;
				$edited_notes =~ s/\$HOSTADDRESS\$/$address{$host}/g;
				$edited_notes =~ s/\$SERVICENAME\$|\$SERVICEDESC\$|\$SERVICEDESCRIPTION\$/$svcdesc/g;
				$service_extinfo{$svcdesc}{'notes'} = $edited_notes;
			    }
			}

			my $edited_notes_url = $service_notes_url{ $services{$sid}{'serviceextinfo_id'} };
			if ( defined $edited_notes_url ) {
			    $edited_notes_url =~ s/\$HOSTNAME\$/$host/g;
			    $edited_notes_url =~ s/\$HOSTADDRESS\$/$address{$host}/g;
			    $edited_notes_url =~ s/\$SERVICENAME\$|\$SERVICEDESC\$|\$SERVICEDESCRIPTION\$/$svcdesc/g;
			    $service_extinfo{$svcdesc}{'notes_url'} = $edited_notes_url;
			}

			unless ( $options{'nagios_version'} eq '1.x' ) {
			    my $edited_action_url = $service_action_url{ $services{$sid}{'serviceextinfo_id'} };
			    if ( defined $edited_action_url ) {
				$edited_action_url =~ s/\$HOSTNAME\$/$host/g;
				$edited_action_url =~ s/\$HOSTADDRESS\$/$address{$host}/g;
				$edited_action_url =~ s/\$SERVICENAME\$|\$SERVICEDESC\$|\$SERVICEDESCRIPTION\$/$svcdesc/g;
				$service_extinfo{$svcdesc}{'action_url'} = $edited_action_url;
			    }
			}

			unless ( $host_ext_service{$host}{$svcdesc} ) {
			    $extinfofile .= format_obj( \@extinfoprops, 'serviceextinfo', \%{ $service_extinfo{$svcdesc} } );
			    $host_ext_service{$host}{$svcdesc} = 1;
			}
		    }

		    # for every entry of the service in a service group create an entry for each instance (i.e. label on group)
		    foreach my $sg ( keys %service_groups ) {
			if ( $service_groups{$sg}{'hosts'}{ $host_name_id{$host} }{$sid} ) {
			    $use{'servicegroups'}{$sg} = 1;
			    $service_groups{$sg}{'members'} .= "$host,$svcdesc,";
			}
		    }
		}
	    }
	}
    }

    # Build the service files
    my %files = ();
    foreach my $host ( keys %host_instances ) {
	foreach my $svcdesc ( keys %{ $instance_group{$host} } ) {
	    if ( $host_instances{$host}{$svcdesc} ) {
		$files{ $instance_group{$host}{$svcdesc} } .= format_obj( \@props, 'service', \%{ $host_instances{$host}{$svcdesc} } );
	    }
	}
    }

    foreach my $grp ( sort keys %files ) {
	my $file = $grp eq ':all:' ? 'services.cfg' : "$grp\_services.cfg";
	my $outfile = qq(##########GROUNDWORK#############################################################################################
#GW
#GW\t$file generated $date_time by $options{'user_acct'} from monarch.cgi nagios v $options{'nagios_version'}
#GW
##########GROUNDWORK#############################################################################################

$files{$grp}
);
	push @out_files, $file;
	my $error = write_to_text_file( "$destination/$file", $outfile );
	push( @errors, $error ) if ( defined($error) );
    }

    # service extinfo

    my $outfile = qq(##########GROUNDWORK#############################################################################################
#GW
#GW\textended_service_info.cfg generated $date_time by $options{'user_acct'} from monarch.cgi nagios v $options{'nagios_version'}
#GW
##########GROUNDWORK#############################################################################################

$extinfofile
);

    if ( $options{'nagios_version'} =~ /^[23]\.x$/ ) {
	push @out_files, 'extended_service_info.cfg';
    }
    else {
	push @extinfofiles, 'extended_service_info.cfg';
    }
    my $error = write_to_text_file( "$destination/extended_service_info.cfg", $outfile );
    push( @errors, $error ) if ( defined($error) );

    # service groups

    if ( $options{'nagios_version'} =~ /^[23]\.x$/ ) {
	$outfile = qq(##########GROUNDWORK#############################################################################################
#GW
#GW\tservice_groups.cfg generated $date_time by $options{'user_acct'} from monarch.cgi nagios v $options{'nagios_version'}
#GW
##########GROUNDWORK#############################################################################################
);

	my @props = ( 'name', 'alias', 'members', 'notes' );
	foreach my $sg ( sort keys %service_groups ) {
	    chop $service_groups{$sg}{'members'} if defined $service_groups{$sg}{'members'};
	    if ( $service_groups{$sg}{'members'} ) {
		$outfile .= format_obj( \@props, 'servicegroup', \%{ $service_groups{$sg} } );
	    }
	}
	push @out_files, 'service_groups.cfg';
	$error = write_to_text_file( "$destination/service_groups.cfg", $outfile );
	push( @errors, $error ) if ( defined($error) );
    }
}

sub timed_process_services() {
    my @timings = ();
    my $phasetime;

    StorProc->start_timing( \$phasetime );

    # build all instances of service checks
    my %host_instances   = ();
    my %instance_group   = ();
    my %host_ext_service = ();
    my $extinfofile      = '';
    my @props            = split( /,/, $property_list{'services'} );
    foreach my $grp ( sort keys %host_service_group ) {
	foreach my $host ( sort @{ $host_service_group{$grp}{'hosts'} } ) {
	    my %service_extinfo  = ();
	    my %services = %{ $hosts{$host}{'services'} };

	    my $forced_active  = $host_service_group{$group}{'forced_active_checks_enabled'}{$host};
	    my $forced_passive = $host_service_group{$group}{'forced_passive_checks_enabled'}{$host};

	    # determine all service instances for the host and apply macros to check command
	    foreach my $sid ( keys %services ) {
		## my %instances = StorProc->get_service_instances($sid);
		my %instances = %{ $service_instances{$sid} };
		if (%instances) {
		    foreach my $instance ( keys %instances ) {
			if ( $instances{$instance}{'status'} ) {
			    my $instance_name = "$servicename_name{$services{$sid}{'servicename_id'}}$instance";
			    if ( $host_service_group{$grp}{'label'} ) {
				$instance_name =
				  "$servicename_name{$services{$sid}{'servicename_id'}}$instance$host_service_group{$grp}{'label'}";
			    }

			    # Add all props from the service to the instance
			    foreach my $prop ( keys %{ $services{$sid} } ) {
				unless ( $prop eq 'check_command' ) {
				    $host_instances{$host}{$instance_name}{$prop} = $services{$sid}{$prop};
				}
			    }

			    # apply instance arguments and macros to check command
			    # but has it been processed in a previous group?
			    my $got_match = 0;
			    if ( $host_instances{$host}{$instance_name}{'check_command'} ) {
				## yes - only apply macros
				foreach my $macro ( keys %{ $host_service_group{$grp}{'macros'} } ) {
				    if ( $host_instances{$host}{$instance_name}{'check_command'} =~ /$macro/ ) {
					$got_match = 1;
				    }
				    $host_instances{$host}{$instance_name}{'check_command'} =~
				      s/$macro/$host_service_group{$grp}{'macros'}{$macro}/g;
				}
			    }
			    else {
				## no - get args and apply macros
				if ( $instances{$instance}{'args'} ) {
				    $instances{$instance}{'args'} =~ s/^!//;
				    my $check_command_name = defined( $services{$sid}{'check_command'} ) ?
				      $command_name{ $services{$sid}{'check_command'} } : '';
				    $host_instances{$host}{$instance_name}{'check_command'} = "$check_command_name!$instances{$instance}{'args'}";
				    foreach my $macro ( keys %{ $host_service_group{$grp}{'macros'} } ) {
					if ( $host_instances{$host}{$instance_name}{'check_command'} =~ /$macro/ ) {
					    $got_match = 1;
					}
					$host_instances{$host}{$instance_name}{'check_command'} =~
					  s/$macro/$host_service_group{$grp}{'macros'}{$macro}/g;
				    }
				}
			    }

			    # when processing a group label and there is not a macro match don't use the instance
			    if ( $host_service_group{$grp}{'label'} && !$got_match ) {
				delete $host_instances{$host}{$instance_name};
				next;
			    }

			    # for use in applying dependencies and escalations
			    $use{'services'}{$sid}{$instance_name} = 1;

			    # assigns to file of last group read
			    $instance_group{$host}{$instance_name} = $grp;

			    # this seems to have no purpose: $service_name{$instance_name}{'name'} = 1;
			    $host_instances{$host}{$instance_name}{'name'}      = $instance_name;
			    $host_instances{$host}{$instance_name}{'host_name'} = $host;
			    $host_instances{$host}{$instance_name}{'template'} = $servicetemplate_name{ $services{$sid}{'servicetemplate_id'} };
			    $use{'service_templates'}{ $services{$sid}{'template'} } = 1 if defined $services{$sid}{'template'};
			    $host_instances{$host}{$instance_name}{'check_period'} = defined( $services{$sid}{'check_period'} ) ?
			      $timeperiod_name{ $services{$sid}{'check_period'} } : undef;
			    $host_instances{$host}{$instance_name}{'notification_period'} = defined( $services{$sid}{'notification_period'} ) ?
			      $timeperiod_name{ $services{$sid}{'notification_period'} } : undef;
			    $host_instances{$host}{$instance_name}{'event_handler'} = defined( $services{$sid}{'event_handler'} ) ?
			      $command_name{ $services{$sid}{'event_handler'} } : undef;

			    # we don't want to assign redundant contact groups
			    unless ( $host_instances{$host}{$instance_name}{'contactgroup'} ) {
				foreach my $cg ( @{ $services{$sid}{'contactgroups'} } ) {
				    $use{'contactgroups'}{$cg} = 1;
				    $cg =~ s/\s/-/g;
				    $host_instances{$host}{$instance_name}{'contactgroup'} .= "$cg,";
				}
				chop $host_instances{$host}{$instance_name}{'contactgroup'}
				  if defined( $host_instances{$host}{$instance_name}{'contactgroup'} );
			    }

			    # if we don't have a contact group yet get it from the group
			    unless ( $host_instances{$host}{$instance_name}{'contactgroup'} ) {
				foreach my $cg ( sort keys %{ $group_hosts{ $host_group{$host} }{'contactgroups'} } ) {
				    $use{'contactgroups'}{$cg} = 1;
				    $cg =~ s/\s/-/g;
				    $host_instances{$host}{$instance_name}{'contactgroup'} .= "$cg,";
				}
				chop $host_instances{$host}{$instance_name}{'contactgroup'}
				  if defined( $host_instances{$host}{$instance_name}{'contactgroup'} );
			    }

			    # possibly apply global positive or negative overrides computed earlier
			    $host_instances{$host}{$instance_name}{'active_checks_enabled'}  = $forced_active  if defined $forced_active;
			    $host_instances{$host}{$instance_name}{'passive_checks_enabled'} = $forced_passive if defined $forced_passive;

			    # if extended service info is defined we create an entry for each instance, but only once
			    if ( $services{$sid}{'serviceextinfo_id'} && !$service_extinfo{$instance_name} ) {
				my @extinfoprops = ( 'template', 'service_description', 'host_name', 'notes', 'notes_url', 'action_url' );
				$service_extinfo{$instance_name}{'host_name'}           = $host;
				$service_extinfo{$instance_name}{'service_description'} = $instance_name;
				$service_extinfo{$instance_name}{'template'} = $serviceextinfo_name{ $services{$sid}{'serviceextinfo_id'} };

				unless ( $options{'nagios_version'} eq '1.x' ) {
				    my $edited_notes = $service_notes{ $services{$sid}{'serviceextinfo_id'} };
				    if ( defined $edited_notes ) {
					$edited_notes =~ s/\$HOSTNAME\$/$host/g;
					$edited_notes =~ s/\$HOSTADDRESS\$/$address{$host}/g;
					$edited_notes =~ s/\$SERVICENAME\$|\$SERVICEDESC\$|\$SERVICEDESCRIPTION\$/$instance_name/g;
					$service_extinfo{$instance_name}{'notes'} = $edited_notes;
				    }
				}

				my $edited_notes_url = $service_notes_url{ $services{$sid}{'serviceextinfo_id'} };
				if ( defined $edited_notes_url ) {
				    $edited_notes_url =~ s/\$HOSTNAME\$/$host/g;
				    $edited_notes_url =~ s/\$HOSTADDRESS\$/$address{$host}/g;
				    $edited_notes_url =~ s/\$SERVICENAME\$|\$SERVICEDESC\$|\$SERVICEDESCRIPTION\$/$instance_name/g;
				    $service_extinfo{$instance_name}{'notes_url'} = $edited_notes_url;
				}

				unless ( $options{'nagios_version'} eq '1.x' ) {
				    my $edited_action_url = $service_action_url{ $services{$sid}{'serviceextinfo_id'} };
				    if ( defined $edited_action_url ) {
					$edited_action_url =~ s/\$HOSTNAME\$/$host/g;
					$edited_action_url =~ s/\$HOSTADDRESS\$/$address{$host}/g;
					$edited_action_url =~ s/\$SERVICENAME\$|\$SERVICEDESC\$|\$SERVICEDESCRIPTION\$/$instance_name/g;
					$service_extinfo{$instance_name}{'action_url'} = $edited_action_url;
				    }
				}

				unless ( $host_ext_service{$host}{$instance_name} ) {
				    $extinfofile .= format_obj( \@extinfoprops, 'serviceextinfo', \%{ $service_extinfo{$instance_name} } );
				    $host_ext_service{$host}{$instance_name} = 1;
				}
			    }

			    # for every entry of the service in a service group create an entry for each instance
			    foreach my $sg ( keys %service_groups ) {
				if ( $service_groups{$sg}{'hosts'}{ $host_name_id{$host} }{$sid} ) {
				    $use{'servicegroups'}{$sg} = 1;
				    $service_groups{$sg}{'members'} .= "$host,$instance_name,";
				}
			    }
			}
		    }
		}
		else {
		    my $svcdesc = $servicename_name{ $services{$sid}{'servicename_id'} };
		    if ( $host_service_group{$grp}{'label'} ) {
			$svcdesc = "$svcdesc$host_service_group{$grp}{'label'}";
		    }

		    # Add all props from the service to the instance
		    foreach my $prop ( keys %{ $services{$sid} } ) {
			$host_instances{$host}{$svcdesc}{$prop} = $services{$sid}{$prop};
		    }
		    $host_instances{$host}{$svcdesc}{'check_command'} = $services{$sid}{'command_line'};
		    unless ( $host_instances{$host}{$svcdesc}{'check_command'} ) {
			$host_instances{$host}{$svcdesc}{'check_command'} = defined( $services{$sid}{'check_command'} ) ?
			  $command_name{ $services{$sid}{'check_command'} } : undef;
		    }

		    # FIX MINOR:  This loop and the loops in which it is embedded are ripe for further optimization,
		    # by not running repeated identical hash lookups (here $host_instances{$host}{$svcdesc}, above
		    # $host_instances{$host}{$instance_name}, for example).  Test with large customer configurations.
		    my $got_match = 0;
		    $host_instances{$host}{$svcdesc}{'name'} = $svcdesc;
		    if ( defined $host_instances{$host}{$svcdesc}{'check_command'} ) {
			foreach my $macro ( keys %{ $host_service_group{$grp}{'macros'} } ) {
			    if ( $host_instances{$host}{$svcdesc}{'check_command'} =~ /$macro/ ) {
				$got_match = 1;
			    }
			    $host_instances{$host}{$svcdesc}{'check_command'} =~ s/$macro/$host_service_group{$grp}{'macros'}{$macro}/g;
			}
		    }

		    # when processing a group label and there is not a macro match don't use the instance
		    if ( $host_service_group{$grp}{'label'} && !$got_match ) {
			delete $host_instances{$host}{$svcdesc};
			next;
		    }

		    # for use in applying dependencies and escalations
		    $use{'services'}{$sid}{$svcdesc} = 1;

		    # assigns to file of last group read
		    $instance_group{$host}{$svcdesc} = $grp;

		    # apply values to the rest of the props
		    #  this seems to have no purpose: $service_name{$svcdesc}{'name'} = 1;
		    $host_instances{$host}{$svcdesc}{'host_name'}            = $host;
		    $host_instances{$host}{$svcdesc}{'template'}             = $servicetemplate_name{ $services{$sid}{'servicetemplate_id'} };
		    $use{'service_templates'}{ $services{$sid}{'template'} } = 1 if defined $services{$sid}{'template'};
		    $host_instances{$host}{$svcdesc}{'check_period'} =
		      defined( $services{$sid}{'check_period'} ) ? $timeperiod_name{ $services{$sid}{'check_period'} } : undef;
		    $host_instances{$host}{$svcdesc}{'notification_period'} =
		      defined( $services{$sid}{'notification_period'} ) ? $timeperiod_name{ $services{$sid}{'notification_period'} } : undef;
		    $host_instances{$host}{$svcdesc}{'event_handler'} =
		      defined( $services{$sid}{'event_handler'} ) ? $command_name{ $services{$sid}{'event_handler'} } : undef;

		    # we don't want to assign redundant contact groups
		    unless ( $host_instances{$host}{$svcdesc}{'contactgroup'} ) {
			foreach my $cg ( @{ $services{$sid}{'contactgroups'} } ) {
			    $use{'contactgroups'}{$cg} = 1;
			    $cg =~ s/\s/-/g;
			    $host_instances{$host}{$svcdesc}{'contactgroup'} .= "$cg,";
			}
			chop $host_instances{$host}{$svcdesc}{'contactgroup'}
			  if ( defined( $host_instances{$host}{$svcdesc}{'contactgroup'} ) );
		    }

		    # if we don't have a contact group yet get it from the group
		    unless ( $host_instances{$host}{$svcdesc}{'contactgroup'} ) {
			foreach my $cg ( sort keys %{ $group_hosts{ $host_group{$host} }{'contactgroups'} } ) {
			    $use{'contactgroups'}{$cg} = 1;
			    $cg =~ s/\s/-/g;
			    $host_instances{$host}{$svcdesc}{'contactgroup'} .= "$cg,";
			}
			chop $host_instances{$host}{$svcdesc}{'contactgroup'}
			  if ( defined( $host_instances{$host}{$svcdesc}{'contactgroup'} ) );
		    }

		    # possibly apply global positive or negative overrides computed earlier
		    $host_instances{$host}{$svcdesc}{'active_checks_enabled'}  = $forced_active  if defined $forced_active;
		    $host_instances{$host}{$svcdesc}{'passive_checks_enabled'} = $forced_passive if defined $forced_passive;

		    # if extended service info is defined we create an entry
		    if ( $services{$sid}{'serviceextinfo_id'} ) {
			my @extinfoprops = ( 'template', 'service_description', 'host_name', 'notes', 'notes_url', 'action_url' );
			$service_extinfo{$svcdesc}{'host_name'}           = $host;
			$service_extinfo{$svcdesc}{'service_description'} = $svcdesc;
			$service_extinfo{$svcdesc}{'template'}            = $serviceextinfo_name{ $services{$sid}{'serviceextinfo_id'} };

			unless ( $options{'nagios_version'} eq '1.x' ) {
			    my $edited_notes = $service_notes{ $services{$sid}{'serviceextinfo_id'} };
			    if ( defined $edited_notes ) {
				$edited_notes =~ s/\$HOSTNAME\$/$host/g;
				$edited_notes =~ s/\$HOSTADDRESS\$/$address{$host}/g;
				$edited_notes =~ s/\$SERVICENAME\$|\$SERVICEDESC\$|\$SERVICEDESCRIPTION\$/$svcdesc/g;
				$service_extinfo{$svcdesc}{'notes'} = $edited_notes;
			    }
			}

			my $edited_notes_url = $service_notes_url{ $services{$sid}{'serviceextinfo_id'} };
			if ( defined $edited_notes_url ) {
			    $edited_notes_url =~ s/\$HOSTNAME\$/$host/g;
			    $edited_notes_url =~ s/\$HOSTADDRESS\$/$address{$host}/g;
			    $edited_notes_url =~ s/\$SERVICENAME\$|\$SERVICEDESC\$|\$SERVICEDESCRIPTION\$/$svcdesc/g;
			    $service_extinfo{$svcdesc}{'notes_url'} = $edited_notes_url;
			}

			unless ( $options{'nagios_version'} eq '1.x' ) {
			    my $edited_action_url = $service_action_url{ $services{$sid}{'serviceextinfo_id'} };
			    if ( defined $edited_action_url ) {
				$edited_action_url =~ s/\$HOSTNAME\$/$host/g;
				$edited_action_url =~ s/\$HOSTADDRESS\$/$address{$host}/g;
				$edited_action_url =~ s/\$SERVICENAME\$|\$SERVICEDESC\$|\$SERVICEDESCRIPTION\$/$svcdesc/g;
				$service_extinfo{$svcdesc}{'action_url'} = $edited_action_url;
			    }
			}

			unless ( $host_ext_service{$host}{$svcdesc} ) {
			    $extinfofile .= format_obj( \@extinfoprops, 'serviceextinfo', \%{ $service_extinfo{$svcdesc} } );
			    $host_ext_service{$host}{$svcdesc} = 1;
			}
		    }

		    # for every entry of the service in a service group create an entry for each instance (i.e. label on group)
		    foreach my $sg ( keys %service_groups ) {
			if ( $service_groups{$sg}{'hosts'}{ $host_name_id{$host} }{$sid} ) {
			    $use{'servicegroups'}{$sg} = 1;
			    $service_groups{$sg}{'members'} .= "$host,$svcdesc,";
			}
		    }
		}
	    }
	}
    }
    StorProc->capture_timing( \@timings, \$phasetime, 'processing service detail' );

    # Build the service files
    my %files = ();
    foreach my $host ( keys %host_instances ) {
	foreach my $svcdesc ( keys %{ $instance_group{$host} } ) {
	    if ( $host_instances{$host}{$svcdesc} ) {
		$files{ $instance_group{$host}{$svcdesc} } .= format_obj( \@props, 'service', \%{ $host_instances{$host}{$svcdesc} } );
	    }
	}
    }
    StorProc->capture_timing( \@timings, \$phasetime, 'processing building of service files' );

    foreach my $grp ( sort keys %files ) {
	my $file = $grp eq ':all:' ? 'services.cfg' : "$grp\_services.cfg";
	my $outfile = qq(##########GROUNDWORK#############################################################################################
#GW
#GW\t$file generated $date_time by $options{'user_acct'} from monarch.cgi nagios v $options{'nagios_version'}
#GW
##########GROUNDWORK#############################################################################################

$files{$grp}
);
	push @out_files, $file;
	my $error = write_to_text_file( "$destination/$file", $outfile );
	push( @errors, $error ) if ( defined($error) );
    }

    # service extinfo

    my $outfile = qq(##########GROUNDWORK#############################################################################################
#GW
#GW\textended_service_info.cfg generated $date_time by $options{'user_acct'} from monarch.cgi nagios v $options{'nagios_version'}
#GW
##########GROUNDWORK#############################################################################################

$extinfofile
);

    if ( $options{'nagios_version'} =~ /^[23]\.x$/ ) {
	push @out_files, 'extended_service_info.cfg';
    }
    else {
	push @extinfofiles, 'extended_service_info.cfg';
    }
    my $error = write_to_text_file( "$destination/extended_service_info.cfg", $outfile );
    push( @errors, $error ) if ( defined($error) );

    # service groups

    if ( $options{'nagios_version'} =~ /^[23]\.x$/ ) {
	$outfile = qq(##########GROUNDWORK#############################################################################################
#GW
#GW\tservice_groups.cfg generated $date_time by $options{'user_acct'} from monarch.cgi nagios v $options{'nagios_version'}
#GW
##########GROUNDWORK#############################################################################################
);

	my @props = ( 'name', 'alias', 'members', 'notes' );
	foreach my $sg ( sort keys %service_groups ) {
	    chop $service_groups{$sg}{'members'} if defined $service_groups{$sg}{'members'};
	    if ( $service_groups{$sg}{'members'} ) {
		$outfile .= format_obj( \@props, 'servicegroup', \%{ $service_groups{$sg} } );
	    }
	}
	push @out_files, 'service_groups.cfg';
	$error = write_to_text_file( "$destination/service_groups.cfg", $outfile );
	push( @errors, $error ) if ( defined($error) );
    }

    StorProc->capture_timing( \@timings, \$phasetime, 'processing writing of service files' );

    return \@timings;
}

sub process_service_dependencies() {

    my $outfile = qq(##########GROUNDWORK#############################################################################################
#GW
#GW\tservice_dependency_templates.cfg generated $date_time by $options{'user_acct'} from monarch.cgi nagios v $options{'nagios_version'}
#GW
##########GROUNDWORK#############################################################################################
);
    my %sdtemp_name = ();
    my @props = ( 'name', 'service_description', 'execution_failure_criteria', 'notification_failure_criteria' );
    foreach my $name ( sort keys %service_dependency_templates ) {
	$sdtemp_name{ $service_dependency_templates{$name}{'id'} } = $name;
	$service_dependency_templates{$name}{'name'} = $name;
	$service_dependency_templates{$name}{'service_description'} =
	  $servicename_name{ $service_dependency_templates{$name}{'servicename_id'} };
	$outfile .= format_obj( \@props, 'servicedependency_template', \%{ $service_dependency_templates{$name} } );
    }

    push @out_files, 'service_dependency_templates.cfg';
    my $error = write_to_text_file( "$destination/service_dependency_templates.cfg", $outfile );
    push( @errors, $error ) if ( defined($error) );

    # service dependencies

    $outfile = qq(##########GROUNDWORK#############################################################################################
#GW
#GW\tservice_dependencies.cfg generated $date_time by $options{'user_acct'} from monarch.cgi nagios v $options{'nagios_version'}
#GW
##########GROUNDWORK#############################################################################################
);
    @props = ( 'use', 'dependent_service_description', 'dependent_host_name', 'host_name' );
    foreach my $id ( keys %service_dependencies ) {
	if ( $use{'services'}{ $service_dependencies{$id}[1] } ) {
	    ## for each instance of the service id create a dependency
	    foreach my $name ( sort keys %{ $use{'services'}{ $service_dependencies{$id}[1] } } ) {
		if ( not $inactive_hosts{ $service_dependencies{$id}[3] } ) {
		    my %dependency = ();
		    $dependency{'use'}                           = $sdtemp_name{ $service_dependencies{$id}[4] };
		    $dependency{'dependent_service_description'} = $name;
		    $dependency{'dependent_host_name'}           = $host_name{ $service_dependencies{$id}[2] };
		    $dependency{'host_name'}                     = $host_name{ $service_dependencies{$id}[3] };
		    $dependency{'comment'}                       = $service_dependencies{$id}[5];
		    $outfile .= format_obj( \@props, 'servicedependency', \%dependency );
		}
	    }
	}
    }

    push @out_files, 'service_dependencies.cfg';
    $error = write_to_text_file( "$destination/service_dependencies.cfg", $outfile );
    push( @errors, $error ) if ( defined($error) );
}

sub process_service_templates() {
    my $outfile = qq(##########GROUNDWORK#############################################################################################
#GW
#GW\tservice_templates.cfg generated $date_time by $options{'user_acct'} from monarch.cgi nagios v $options{'nagios_version'}
#GW
##########GROUNDWORK#############################################################################################
);
    my @props = split( /,/, $property_list{'service_templates'} );
    foreach my $name ( sort keys %service_templates ) {
	my %template = ();
	foreach my $prop (@props) {
	    if ( $prop eq 'contactgroup' ) {
		$template{'contactgroup'} = '';
		foreach my $cgid ( @{ $service_templates{$name}{'contactgroups'} } ) {
		    my $cg = $contactgroup_name{$cgid};
		    $cg =~ s/\s/-/g;
		    $template{'contactgroup'} .= "$cg,";
		    $use{'contactgroups'}{ $contactgroup_name{$cgid} } = 1;
		}
		chop $template{'contactgroup'};
		delete $template{'contactgroup'} if $template{'contactgroup'} eq '';
	    }
	    elsif ( $prop eq 'template' ) {
		$template{$prop} = defined( $service_templates{$name}{'parent_id'} ) ?
		  $servicetemplate_name{ $service_templates{$name}{'parent_id'} } : undef;
	    }
	    elsif ( $prop =~ /^check_command$|^event_handler$/ ) {
		$template{$prop} = defined( $service_templates{$name}{$prop} ) ?
		  $command_name{ $service_templates{$name}{$prop} } : undef;
	    }
	    elsif ( $prop =~ /^check_period$|^notification_period$/ ) {
		$template{$prop} = defined( $service_templates{$name}{$prop} ) ?
		  $timeperiod_name{ $service_templates{$name}{$prop} } : undef;
	    }
	    else {
		$template{$prop} = $service_templates{$name}{$prop};
	    }
	}
	if ( $template{'command_line'} ) {
	    $template{'check_command'} = $template{'command_line'};
	}
	delete $template{'command_line'};
	$template{'name'} = $name;
	$outfile .= format_obj( \@props, 'service_template', \%template );
    }

    push @out_files, 'service_templates.cfg';
    my $error = write_to_text_file( "$destination/service_templates.cfg", $outfile );
    push( @errors, $error ) if ( defined($error) );
}

############################################################################
# Escalations
############################################################################

sub get_escalations() {
    my %where = ();

    %escalation_templates = ();
    %escalation_trees     = ();
    my %escalation_name                = ();
    my %escalationtree_name            = ();
    my %escalation_template_hash_array = StorProc->fetch_list_hash_array( 'escalation_templates', \%where );
    foreach my $id ( keys %escalation_template_hash_array ) {
	my $ename = $escalation_template_hash_array{$id}[1];
	$escalation_name{$id}                              = $ename;
	$escalation_templates{$ename}{'id'}                = $id;
	$escalation_templates{$ename}{'type'}              = $escalation_template_hash_array{$id}[2];
	$escalation_templates{$ename}{'escalation_period'} = $escalation_template_hash_array{$id}[5];
	my %data = StorProc->parse_xml( $escalation_template_hash_array{$id}[3] );
	foreach my $prop ( keys %data ) {
	    $escalation_templates{$ename}{$prop} = $data{$prop};
	}
    }
    my %escalation_tree_hash = StorProc->fetch_list_hash_array( 'escalation_trees', \%where );
    foreach my $id ( keys %escalation_tree_hash ) {
	my $name = $escalation_tree_hash{$id}[1];
	$escalationtree_name{$id}        = $name;
	$escalation_trees{$name}{'type'} = $escalation_tree_hash{$id}[3];
	$escalation_trees{$name}{'id'}   = $id;
    }
    my %tree_template_contactgroup_hash = StorProc->fetch_hash_array_generic_key( 'tree_template_contactgroup', \%where );
    foreach my $key ( keys %tree_template_contactgroup_hash ) {
	my $name = $escalationtree_name{ $tree_template_contactgroup_hash{$key}[0] };
	## GWMON-5079:  Why are we using an escalation template id as an escalation id?
	my $esc = $escalation_name{ $tree_template_contactgroup_hash{$key}[1] };
	push @{ $escalation_trees{$name}{'escalations'}{$esc}{'contactgroups'} },
	  $contactgroup_name{ $tree_template_contactgroup_hash{$key}[2] };
    }
}

sub process_escalation_templates() {
    my $outfile = qq(##########GROUNDWORK#############################################################################################
#GW
#GW\tescalation_templates.cfg generated $date_time by $options{'user_acct'} from monarch.cgi nagios v $options{'nagios_version'}
#GW
##########GROUNDWORK#############################################################################################
);
    my @props = split( /,/, $property_list{'host_escalation_templates'} );
    foreach my $name ( sort keys %escalation_templates ) {
	my $type = undef;
	if ( $escalation_templates{$name}{'type'} eq 'hostgroup' ) {
	    $type = 'hostgroupescalation';
	}
	if ( $escalation_templates{$name}{'type'} eq 'host' ) {
	    $type = 'hostescalation';
	}
	if ( $escalation_templates{$name}{'type'} eq 'service' ) {
	    $type = 'serviceescalation';
	}
	if ( defined( $escalation_templates{$name}{'escalation_options'} ) && $escalation_templates{$name}{'escalation_options'} =~ /all/ ) {
	    delete $escalation_templates{$name}{'escalation_options'};
	}
	$escalation_templates{$name}{'escalation_period'} = defined( $escalation_templates{$name}{'escalation_period'} ) ?
	  $timeperiod_name{ $escalation_templates{$name}{'escalation_period'} } : undef;
	if ( $options{'nagios_version'} eq '1.x' ) {
	    delete $escalation_templates{$name}{'escalation_period'};
	    delete $escalation_templates{$name}{'escalation_options'};
	}
	delete $escalation_templates{$name}{'type'};
	$escalation_templates{$name}{'name'} = $name;
	$outfile .= format_obj( \@props, $type . "_template", \%{ $escalation_templates{$name} } );
    }
    push @out_files, 'escalation_templates.cfg';
    my $error = write_to_text_file( "$destination/escalation_templates.cfg", $outfile );
    push( @errors, $error ) if ( defined($error) );
}

sub process_escalations() {
    my $outhostfile = qq(##########GROUNDWORK#############################################################################################
#GW
#GW\thost_escalations.cfg generated $date_time by $options{'user_acct'} from monarch.cgi nagios v $options{'nagios_version'}
#GW
##########GROUNDWORK#############################################################################################
);

    my $outservicefile = qq(##########GROUNDWORK#############################################################################################
#GW
#GW\tservice_escalations.cfg generated $date_time by $options{'user_acct'} from monarch.cgi nagios v $options{'nagios_version'}
#GW
##########GROUNDWORK#############################################################################################
);

    my %host_host_esc            = ();
    my %host_service_esc         = ();
    my %host_service_service_esc = ();
    foreach my $hname ( keys %hosts ) {
	if ( $hosts{$hname}{'host_escalation_id'} ) {
	    push @{ $host_host_esc{ $hosts{$hname}{'host_escalation_id'} } }, $hname;
	}
	if ( $hosts{$hname}{'service_escalation_id'} ) {
	    push @{ $host_service_esc{ $hosts{$hname}{'service_escalation_id'} } }, $hname;
	}
	foreach my $id ( keys %{ $hosts{$hname}{'services'} } ) {
	    if ( $hosts{$hname}{'services'}{$id}{'escalation_id'} ) {
		$host_service_service_esc{ $hosts{$hname}{'services'}{$id}{'escalation_id'} }{$hname}{$id} = 1;
	    }
	}
    }

    my %hostgroup_host_esc    = ();
    my %hostgroup_service_esc = ();
    foreach my $hname ( keys %host_groups ) {
	if ( $host_groups{$hname}{'host_escalation_id'} ) {
	    push @{ $hostgroup_host_esc{ $host_groups{$hname}{'host_escalation_id'} } }, $hname;
	}
	if ( $host_groups{$hname}{'service_escalation_id'} ) {
	    push @{ $hostgroup_service_esc{ $host_groups{$hname}{'service_escalation_id'} } }, $hname;
	}
    }

    my %servicegroup_esc = ();
    foreach my $service_group ( keys %service_groups ) {
	if ( $service_groups{$service_group}{'escalation_id'} ) {
	    push @{ $servicegroup_esc{ $service_groups{$service_group}{'escalation_id'} } }, $service_group;
	}
    }

    foreach my $tree ( sort keys %escalation_trees ) {
	my $tree_id = $escalation_trees{$tree}{'id'};
	if ( $escalation_trees{$tree}{'type'} eq 'host' ) {
	    $outhostfile .= "\n\n#\n# " . (defined( $escalation_trees{$tree}{'comment'} ) ? $escalation_trees{$tree}{'comment'} : '') . "\n#\n\n";
	    delete $escalation_trees{$tree}{'comment'};
	    delete $escalation_trees{$tree}{'id'};
	    delete $escalation_trees{$tree}{'type'};
	    foreach my $esc ( sort keys %{ $escalation_trees{$tree}{'escalations'} } ) {
		my $escalation_id = $escalation_templates{$esc}{'id'};
		my %escalation = ( 'use' => $esc );
		foreach my $cg ( @{ $escalation_trees{$tree}{'escalations'}{$esc}{'contactgroups'} } ) {
		    $use{'contactgroups'}{$cg} = 1;
		    $cg =~ s/\s/-/g;
		    $escalation{'contact_groups'} .= "$cg,";
		}
		chop $escalation{'contact_groups'};
		my @props = ( 'use', 'hostgroup_name', 'contact_groups' );

		#foreach my $hostgroup (@{$hostgroup_host_esc{$escalation_id}}) { ... }
		foreach my $hostgroup ( @{ $hostgroup_host_esc{$tree_id} } ) {
		    if ( $use{'hostgroups'}{$hostgroup} ) {
			$escalation{'hostgroup_name'} .= "$hostgroup,";
		    }
		}
		chop $escalation{'hostgroup_name'} if defined $escalation{'hostgroup_name'};
		if ( $escalation{'hostgroup_name'} ) {
		    $outhostfile .= format_obj( \@props, 'hostescalation', \%escalation );
		}
		@props = ( 'use', 'host_name', 'contact_groups' );

		#foreach my $host (@{$host_host_esc{$escalation_id}}) { ... }
		foreach my $host ( @{ $host_host_esc{$tree_id} } ) {
		    if ( $use{'hosts'}{$host} ) {
			$escalation{'host_name'} .= "$host,";
		    }
		}
		chop $escalation{'host_name'} if defined $escalation{'host_name'};
		if ( $escalation{'host_name'} ) {
		    $outhostfile .= format_obj( \@props, 'hostescalation', \%escalation );
		}
	    }
	}

	if ( defined( $escalation_trees{$tree}{'type'} ) && $escalation_trees{$tree}{'type'} eq 'service' ) {
	    delete $escalation_trees{$tree}{'comment'};
	    delete $escalation_trees{$tree}{'id'};
	    delete $escalation_trees{$tree}{'type'};
	    foreach my $esc ( sort keys %{ $escalation_trees{$tree}{'escalations'} } ) {
		my $escalation_id = $escalation_templates{$esc}{'id'};
		my %escalation = ( 'use' => $esc, 'service_description' => '*' );
		foreach my $cg ( @{ $escalation_trees{$tree}{'escalations'}{$esc}{'contactgroups'} } ) {
		    $use{'contactgroups'}{$cg} = 1;
		    $cg =~ s/\s/-/g;
		    $escalation{'contact_groups'} .= "$cg,";
		}
		chop $escalation{'contact_groups'};
		my @props = ( 'use', 'hostgroup_name', 'service_description', 'contact_groups' );
		foreach my $hostgroup ( @{ $hostgroup_service_esc{$tree_id} } ) {
		    if ( $use{'hostgroups'}{$hostgroup} ) {
			$escalation{'hostgroup_name'} .= "$hostgroup,";
		    }
		}
		if (defined $escalation{'hostgroup_name'}) {
		    chop $escalation{'hostgroup_name'};
		    if ( $escalation{'hostgroup_name'} ) {
			$outservicefile .= format_obj( \@props, 'serviceescalation', \%escalation );
		    }
		}
		@props = ( 'use', 'host_name', 'service_description', 'contact_groups' );
		foreach my $host ( @{ $host_service_esc{$tree_id} } ) {
		    if ( $use{'hosts'}{$host} ) {
			$escalation{'host_name'} .= "$host,";
		    }
		}
		if (defined $escalation{'host_name'}) {
		    chop $escalation{'host_name'};
		    if ( $escalation{'host_name'} ) {
			$outservicefile .= format_obj( \@props, 'serviceescalation', \%escalation );
		    }
		}
		@props = ( 'use', 'servicegroup_name', 'contact_groups' );
		delete $escalation{'service_description'};
		foreach my $sg ( @{ $servicegroup_esc{$tree_id} } ) {
		    if ( $use{'servicegroups'}{$sg} ) {
			$escalation{'servicegroup_name'} .= "$sg,";
		    }
		}
		if (defined $escalation{'servicegroup_name'}) {
		    chop $escalation{'servicegroup_name'};
		    if ( $escalation{'servicegroup_name'} ) {
			$outservicefile .= format_obj( \@props, 'serviceescalation', \%escalation );
		    }
		}
		@props = ( 'use', 'host_name', 'service_description', 'contact_groups' );
		foreach my $host ( sort keys %{ $host_service_service_esc{$tree_id} } ) {
		    $escalation{'host_name'} = $host;
		    foreach my $service_id ( sort keys %{ $host_service_service_esc{$tree_id}{$host} } ) {
			foreach my $sname ( sort keys %{ $use{'services'}{$service_id} } ) {
			    $escalation{'service_description'} = $sname;
			    $outservicefile .= format_obj( \@props, 'serviceescalation', \%escalation );
			}
		    }
		}
	    }
	}
    }
    push @out_files, 'host_escalations.cfg';
    my $error = write_to_text_file( "$destination/host_escalations.cfg", $outhostfile );
    push( @errors, $error ) if ( defined($error) );

    push @out_files, 'service_escalations.cfg';
    $error = undef;
    $error = write_to_text_file( "$destination/service_escalations.cfg", $outservicefile );
    push( @errors, $error ) if ( defined($error) );
}

############################################################################
# Contacts
############################################################################

sub get_contacts() {
    my %where = ();

    %contacts                  = ();
    %contact_name              = ();
    %contact_command_overrides = ();
    %contact_overrides         = ();
    my %contact_hash_array = StorProc->fetch_list_hash_array( 'contacts', \%where );
    foreach my $id ( keys %contact_hash_array ) {
	my $cname = $contact_hash_array{$id}[1];
	$contact_name{$id}                      = $cname;
	$contacts{$cname}{'name'}               = $cname;
	$contacts{$cname}{'alias'}              = $contact_hash_array{$id}[2];
	$contacts{$cname}{'email'}              = $contact_hash_array{$id}[3];
	$contacts{$cname}{'pager'}              = $contact_hash_array{$id}[4];
	$contacts{$cname}{'contacttemplate_id'} = $contact_hash_array{$id}[5];
	$contacts{$cname}{'comments'}           = $contact_hash_array{$id}[7];
	@{ $contact_command_overrides{$cname}{'host'} }    = ();
	@{ $contact_command_overrides{$cname}{'service'} } = ();
	%{ $contact_overrides{$cname} }                    = ();
    }
    my %contact_command_overrides_hash_array = StorProc->fetch_hash_array_generic_key( 'contact_command_overrides', \%where );
    foreach my $key ( keys %contact_command_overrides_hash_array ) {
	my $cname      = $contact_name{ $contact_command_overrides_hash_array{$key}[0] };
	my $contact_id = $contact_command_overrides_hash_array{$key}[0];
	my $type       = $contact_command_overrides_hash_array{$key}[1];
	my $command_id = $contact_command_overrides_hash_array{$key}[2];
	push @{ $contact_command_overrides{$cname}{$type} }, $command_name{$command_id};
    }
    my %contact_overrides_hash_array = StorProc->fetch_hash_array_generic_key( 'contact_overrides', \%where );
    foreach my $key ( keys %contact_overrides_hash_array ) {
	my $cname = $contact_name{ $contact_overrides_hash_array{$key}[0] };
	$contact_overrides{$cname}{'host_notification_period'}    = $contact_overrides_hash_array{$key}[1];
	$contact_overrides{$cname}{'service_notification_period'} = $contact_overrides_hash_array{$key}[2];
	if ( $contact_overrides_hash_array{$key}[3] ) {
	    my %data = StorProc->parse_xml( $contact_overrides_hash_array{$key}[3] );
	    foreach my $name ( keys %data ) {
		$contact_overrides{$cname}{$name} = $data{$name};
	    }
	}
    }
    %contact_templates     = ();
    %contact_template_name = ();
    my %contact_template_hash_array = StorProc->fetch_list_hash_array( 'contact_templates', \%where );
    foreach my $id ( keys %contact_template_hash_array ) {
	my $name = $contact_template_hash_array{$id}[1];
	$contact_template_name{$id}                              = $name;
	$contact_templates{$name}{'name'}                        = $name;
	$contact_templates{$name}{'host_notification_period'}    = $timeperiod_name{ $contact_template_hash_array{$id}[2] };
	$contact_templates{$name}{'service_notification_period'} = $timeperiod_name{ $contact_template_hash_array{$id}[3] };
	my %data = StorProc->parse_xml( $contact_template_hash_array{$id}[4] );
	$contact_templates{$name}{'host_notification_options'}    = $data{'host_notification_options'};
	$contact_templates{$name}{'service_notification_options'} = $data{'service_notification_options'};
	foreach my $prop (keys %data) {
	    $contact_templates{$name}{$prop} = $data{$prop} if $prop =~ /^_/;
	}
    }

    my %contact_template_command_hash_array = StorProc->fetch_hash_array_generic_key( 'contact_command', \%where );
    foreach my $key ( keys %contact_template_command_hash_array ) {
	my $ctname = $contact_template_name{ $contact_template_command_hash_array{$key}[0] };
	if ( $contact_template_command_hash_array{$key}[1] eq 'host' ) {
	    $contact_templates{$ctname}{'host_notification_commands'} .= "$command_name{$contact_template_command_hash_array{$key}[2]},";
	}
	else {
	    $contact_templates{$ctname}{'service_notification_commands'} .= "$command_name{$contact_template_command_hash_array{$key}[2]},";
	}
    }
    foreach my $name ( sort keys %contact_templates ) {
	## We suppress autovivification here.
	chop $contact_templates{$name}{'host_notification_commands'}    if exists $contact_templates{$name}{'host_notification_commands'};
	chop $contact_templates{$name}{'service_notification_commands'} if exists $contact_templates{$name}{'service_notification_commands'};
    }
}

sub process_contact_templates() {
    my $outfile = qq(##########GROUNDWORK#############################################################################################
#GW
#GW\tcontact_templates.cfg generated $date_time by $options{'user_acct'} from monarch.cgi nagios v $options{'nagios_version'}
#GW
##########GROUNDWORK#############################################################################################
);

    my @props = split( /,/, $property_list{'contact_templates'} );
    foreach my $name ( sort keys %contact_templates ) {
	my @ct_props = @props;
	push @ct_props, grep ( /^_/, keys %{ $contact_templates{$name} } );
	$outfile .= format_obj( \@ct_props, 'contact_template', \%{ $contact_templates{$name} } );
    }
    push @out_files, 'contact_templates.cfg';
    my $error = write_to_text_file( "$destination/contact_templates.cfg", $outfile );
    push( @errors, $error ) if ( defined($error) );
}

sub process_contacts() {
    my $outfile = qq(##########GROUNDWORK#############################################################################################
#GW
#GW\tcontacts.cfg generated $date_time by $options{'user_acct'} from monarch.cgi nagios v $options{'nagios_version'}
#GW
##########GROUNDWORK#############################################################################################
);

    foreach my $name ( sort keys %{ $use{'contacts'} } ) {
	my @props = ( 'name', 'use', 'alias', 'email', 'pager' );
	if ( defined $contacts{$name} ) {
	    my %contact = %{ $contacts{$name} };
	    $contact{'use'} = $contact_template_name{ $contact{'contacttemplate_id'} };
	    my %overrides = %{ $contact_overrides{$name} };
	    delete $overrides{'contact_id'};
	    foreach my $prop ( keys %overrides ) {
		if ( $prop eq 'host_notification_period' ) {
		    $contact{'host_notification_period'} = defined( $overrides{$prop} ) ? $timeperiod_name{ $overrides{$prop} } : undef;
		}
		elsif ( $prop eq 'service_notification_period' ) {
		    $contact{'service_notification_period'} = defined( $overrides{$prop} ) ? $timeperiod_name{ $overrides{$prop} } : undef;
		}
		else {
		    $contact{$prop} = $overrides{$prop};
		}
		push @props, $prop;
	    }

	    my @commands = @{ $contact_command_overrides{$name}{'host'} };
	    foreach my $command (@commands) {
		$contact{'host_notification_commands'} .= "$command,";
	    }
	    chop $contact{'host_notification_commands'} if defined $contact{'host_notification_commands'};
	    push @props, 'host_notification_commands';

	    @commands = @{ $contact_command_overrides{$name}{'service'} };
	    foreach my $command (@commands) {
		$contact{'service_notification_commands'} .= "$command,";
	    }
	    chop $contact{'service_notification_commands'} if defined $contact{'service_notification_commands'};
	    push @props, 'service_notification_commands';

	    $outfile .= format_obj( \@props, 'contact', \%contact );
	}
	else {
	    ## FIX LATER:  push an error about somewhere referencing a contact that does not exist
	}
    }
    push @out_files, 'contacts.cfg';
    my $error = write_to_text_file( "$destination/contacts.cfg", $outfile );
    push( @errors, $error ) if ( defined($error) );
}

############################################################################
# nagios.cgi
############################################################################

sub process_nagios_cgi() {
    my @contact_props = (
	'authorized_for_read_only',          'authorized_for_configuration_information',
	'authorized_for_system_information', 'authorized_for_system_commands',
	'authorized_for_all_hosts',          'authorized_for_all_host_commands',
	'authorized_for_all_services',       'authorized_for_all_service_commands',
    );
    my @contactgroup_props = (
	'authorized_contactgroup_for_read_only',          'authorized_contactgroup_for_configuration_information',
	'authorized_contactgroup_for_system_information', 'authorized_contactgroup_for_system_commands',
	'authorized_contactgroup_for_all_hosts',          'authorized_contactgroup_for_all_host_commands',
	'authorized_contactgroup_for_all_services',       'authorized_contactgroup_for_all_service_commands',
    );
    my @cgiprops = (
	'ddb',                        'default_statusmap_layout',
	'default_statuswrl_layout',   'default_user_name',
	'host_down_sound',            'host_unreachable_sound',
	'normal_sound',               'physical_html_path',
	'ping_syntax',                'refresh_rate',
	'service_critical_sound',     'service_unknown_sound',
	'service_warning_sound',      'show_context_help',
	'statusmap_background_image', 'statuswrl_include',
	'url_html_path',              'use_authentication'
    );
    if ( $options{'nagios_version'} eq '3.x' ) {
	push @cgiprops, 'lock_author_names';
	push @cgiprops, 'result_limit';
    }
    push @cgiprops, @contact_props;
    ## FIX LATER:  The following options should really only apply to Nagios 4.3.X and later.
    if ( $options{'nagios_version'} eq '3.x' ) {
	push @cgiprops, 'ack_no_send';
	push @cgiprops, 'ack_no_sticky';
	push @cgiprops, 'tac_cgi_hard_only';
	push @cgiprops, 'use_pending_states';
	push @cgiprops, @contactgroup_props;
    }
    if ( $options{'nagios_version'} eq '1.x' ) {
	push @cgiprops, 'nagios_check_command';
    }
    my $outfile = qq(##########GROUNDWORK#############################################################################################
#GW
#GW\tcgi.cfg generated $date_time by $options{'user_acct'} from monarch.cgi nagios v $options{'nagios_version'}
#GW
##########GROUNDWORK#############################################################################################
);
    my %use_explicit_zero = (
	'ack_no_send'        => 1,
	'ack_no_sticky'      => 1,
	'lock_author_names'  => 1,
	'result_limit'       => 1,
	'show_context_help'  => 1,
	'tac_cgi_hard_only'  => 1,
	'use_authentication' => 1,
	'use_pending_states' => 1,
    );

    $outfile .= "\n# MAIN NAGIOS CONFIGURATION FILE\nmain_config_file=$options{'nagios_home'}/nagios.cfg\n";
    foreach my $prop (@contact_props) {
	if ( defined $nagios_cgi{$prop} ) {
	    for my $contact ( split( ',', $nagios_cgi{$prop} ) ) {
		$contact =~ s/^\s+|\s+$//g;
		if ( $contact ne '' ) {
		    if ( defined $contacts{$contact} ) {
			$use{'contacts'}{$contact} = 1;
		    }
		    else {
			## FIX LATER:  Is it worth breaking the file build by reporting this?
			## push @errors, 'Error:  Contact "' . HTML::Entities::encode($contact) . '" is referenced in CGI setup but does not exist.';
		    }
		}
	    }
	}
    }
    if ( $options{'nagios_version'} eq '3.x' ) {
	foreach my $prop (@contactgroup_props) {
	    if ( defined $nagios_cgi{$prop} ) {
		for my $contactgroup ( split( ',', $nagios_cgi{$prop} ) ) {
		    $contactgroup =~ s/^\s+|\s+$//g;
		    if ( $contactgroup ne '' ) {
			if ( defined $contact_groups{$contactgroup} ) {
			    $use{'contactgroups'}{$contactgroup} = 1;
			}
			else {
			    ( my $field = $prop ) =~ s/_for//;
			    $field =~ s{system}{System/Process};
			    $field =~ s{read_only}{Read-Only};
			    $field =~ s{commands}{command};
			    $field =~ s{all}{global};
			    $field =~ s{s$}{_information};
			    my @field = split( '_', $field );
			    shift @field;
			    push @field, 'access';
			    push @errors,
			        'Error:  Contact group "'
			      . HTML::Entities::encode($contactgroup)
			      . '" is referenced in the "'
			      . join( ' ', map "\u$_", @field )
			      . '" field of the Nagios CGI configuration, but this contactgroup does not exist.';
			}
		    }
		}
	    }
	}
    }
    foreach my $prop ( sort @cgiprops ) {
	my $title = "\U$prop";
	$title =~ s/_/ /g;
	$nagios_cgi{$prop} =~ s/-zero-/0/g if defined $nagios_cgi{$prop};
	my $comment = '';
	if ( exists $use_explicit_zero{$prop} ) {
	    unless ( $nagios_cgi{$prop} ) { $nagios_cgi{$prop} = '0' }
	}
	$comment = '# ' if ( !defined( $nagios_cgi{$prop} ) || $nagios_cgi{$prop} eq '' );
	$outfile .= "\n# $title\n$comment$prop=" . ( defined( $nagios_cgi{$prop} ) ? $nagios_cgi{$prop} : '' ) . "\n";
	if ( @extinfofiles && $prop eq 'nagios_check_command' ) {
	    $outfile .= "\n# XEDTEMPLATE CONFIG FILES\n";
	    foreach my $file ( sort @extinfofiles ) {
		if ( -e "$destination/$file" ) {
		    $outfile .= "xedtemplate_config_file=$options{'nagios_home'}/$file\n";
		}
	    }
	}
    }
    my $error = write_to_text_file( "$destination/cgi.cfg", $outfile );
    push( @errors, $error ) if ( defined($error) );
}

############################################################################
# nagios.cfg
############################################################################

sub process_nagios_cfg() {
    my %nagkeys = StorProc->nagios_defaults( $options{'nagios_version'}, '' );
    my @nagprops = nagios_properties();

    my $outfile = qq(##########GROUNDWORK#############################################################################################
#GW
#GW\tnagios.cfg generated $date_time by $options{'user_acct'} from monarch.cgi nagios v $options{'nagios_version'}
#GW
##########GROUNDWORK#############################################################################################
);

    if ( $options{'nagios_version'} eq '3.x' ) {
	## remove deprecated properties
	@nagprops = grep( !/^(?:aggregate_status_updates|comment_file|downtime_file)$/, @nagprops );
    }

    # This hash implements a workaround (restoring the originally intended meaning of a zero, for particular fields)
    # for the failure (storing NULLs in the database in place of zeroes, because zeroes and empty values are not
    # properly distinguished) of a workaround (recoding empty values to be inserted into the database as NULL, to
    # accommodate missing character data in some fields).  Yuck.  Any item which has a non-zero default in Nagios
    # which would come into play if the user specified a zero (turned into NULL, and then suppressed here because
    # we emit commented-out empty-value directives for NULL values), must be included in this list.
    my %use_explicit_zero = (
	'accept_passive_host_checks'                  => 1,
	'accept_passive_service_checks'               => 1,
	'additional_freshness_latency'                => 1,
	'aggregate_status_updates'                    => 1,
	'auto_reschedule_checks'                      => 1,
	'check_external_commands'                     => 1,
	'check_for_orphaned_hosts'                    => 1,
	'check_for_orphaned_services'                 => 1,
	'check_host_freshness'                        => 1,
	'check_service_freshness'                     => 1,
	'child_processes_fork_twice'                  => 1,
	'debug_verbosity'                             => 1,
	'enable_environment_macros'                   => 1,
	'enable_event_handlers'                       => 1,
	'enable_flap_detection'                       => 1,
	'enable_notifications'                        => 1,
	'enable_predictive_host_dependency_checks'    => 1,
	'enable_predictive_service_dependency_checks' => 1,
	'execute_host_checks'                         => 1,
	'execute_service_checks'                      => 1,
	'free_child_process_memory'                   => 1,
	'log_event_handlers'                          => 1,
	'log_external_commands'                       => 1,
	'log_host_retries'                            => 1,
	'log_initial_states'                          => 1,
	'log_notifications'                           => 1,
	'log_passive_checks'                          => 1,
	'log_passive_service_checks'                  => 1,
	'log_service_retries'                         => 1,
	'max_concurrent_checks'                       => 1,
	'max_debug_file_size'                         => 1,
	'obsess_over_hosts'                           => 1,
	'obsess_over_services'                        => 1,
	'passive_host_checks_are_soft'                => 1,
	'process_performance_data'                    => 1,
	'retain_state_information'                    => 1,
	'translate_passive_host_checks'               => 1,
	'use_aggressive_host_checking'                => 1,
	'use_large_installation_tweaks'               => 1,
	'use_regexp_matching'                         => 1,
	'use_retained_program_state'                  => 1,
	'use_retained_scheduling_info'                => 1,
	'use_syslog'                                  => 1,
	'use_true_regexp_matching'                    => 1,
    );

    foreach my $prop (@nagprops) {
	if ( $prop =~ /^<(.+)>$/ ) {
	    ( my $heading = $1 ) =~ s/_/ /g;
	    $outfile .= "\n# " . ( '=' x 50 ) . "\n# \U$heading\E\n# " . ( '=' x 50 ) . "\n";
	    next;
	}
	my $title = "\U$prop";
	$title =~ s/_/ /g;
	my $comment = '';
	if ( exists $use_explicit_zero{$prop} ) {
	    unless ( $nagios_cfg{$prop} ) { $nagios_cfg{$prop} = '0' }
	}
	$nagios_cfg{$prop} =~ s/-zero-/0/ if defined $nagios_cfg{$prop};
	$comment = '# ' if ( !defined( $nagios_cfg{$prop} ) || $nagios_cfg{$prop} eq '' );
	if ( $prop eq 'resource_file' ) {
	    my ( $folder, $file ) = defined( $nagios_cfg{$prop} ) ? ($nagios_cfg{$prop} =~ /(.*)\/(.*\.cfg)/) : ();
	    if ( $options{'commit_step'} eq 'preflight' ) {
		$outfile .= "\n# $title\n$comment$prop=$destination/$file\n";
	    }
	    else {
		$outfile .= "\n# $title\n$comment$prop=" . (defined( $nagios_cfg{$prop} ) ? $nagios_cfg{$prop} : '') . "\n";
	    }
	}
	elsif ( defined $nagkeys{$prop} ) {
	    $outfile .= "\n# $title\n$comment$prop=" . (defined( $nagios_cfg{$prop} ) ? $nagios_cfg{$prop} : '') . "\n";
	}
	## FIX MAJOR:  use some other flag to get this stuff into the file at the top,
	## or just take this entirely out of the loop, unless the log_file entry must be
	## first to log problems with config files
	if ( $prop eq 'log_file' ) {
	    $outfile .= "\n# " . ( '=' x 50 ) . "\n# OBJECT CONFIGURATION FILE(S)\n# " . ( '=' x 50 ) . "\n\n";
	    foreach my $file ( sort @out_files ) {
		if ( $options{'commit_step'} eq 'preflight' ) {
		    $outfile .= "cfg_file=$destination/$file\n";
		}
		else {
		    $outfile .= "cfg_file=$options{'nagios_home'}/$file\n";
		}
	    }
	}
    }
    if (%nagios_cfg_misc) {
	$outfile .= "\n# MISC DIRECTIVES\n";
	foreach my $misc_prop ( sort keys %nagios_cfg_misc ) {
	    my $directive = $misc_prop;
	    if (! $group) {
		$directive =~ s/key\d+\.\d+$//;
	    }
	    my $value = defined( $nagios_cfg_misc{$misc_prop} ) ? $nagios_cfg_misc{$misc_prop} : '';
	    $value =~ s/-zero-/0/g;
	    $outfile .= "$directive=$value\n";
	}
    }
    my $error = write_to_text_file( "$destination/nagios.cfg", $outfile );
    push( @errors, $error ) if ( defined($error) );
    push @out_files, 'nagios.cfg';

    # Note @extinfofiles is empty unless nagios ver is 1.x
    push( @out_files, @extinfofiles );
    push @out_files, 'cgi.cfg';
}

############################################################################
# resource.cfg
############################################################################

sub process_resource_cfg() {
    my $outfile = qq(##########GROUNDWORK#############################################################################################
#GW
#GW\tresource.cfg generated $date_time by $options{'user_acct'} from monarch.cgi nagios v $options{'nagios_version'}
#GW
##########GROUNDWORK#############################################################################################
);

    for ( my $i = 1 ; $i <= 32 ; $i++ ) {
	my $key = "user$i";
	if ( $resource_cfg{$key} ) {
	    $outfile .= qq(
\$USER$i\$=$resource_cfg{$key}
);
	}
    }
    if ( $nagios_cfg{'resource_file'} ) {
	my ( $res_folder, $res_file ) = $nagios_cfg{'resource_file'} =~ /(.*)\/(.*\.cfg)/;
	if ( $options{'commit_step'} eq 'commit' ) {
	    $res_folder = $destination;
	}
	elsif ( $options{'commit_step'} || $options{'export'} ) {
	    $res_folder = $destination;
	}
	else {
	    unless ( -e "$res_folder" ) {
		mkdir( "$res_folder", 0770 ) || push @errors, "Cannot create $res_folder ($!)";
	    }
	}
	my $error = write_to_text_file( "$res_folder/$res_file", $outfile, 0600 );
	push( @errors, $error ) if ( defined($error) );
	push @out_files, $res_file;
    }
    else {
	push @errors,
	    "Error: You have not yet defined a resource file"
	  . ( $group ? " for the \"$group\" group" : '' )
	  . "!&nbsp; Check the Nagios cfg for this group.";
    }
}

sub get_default_parent() {
    my %default_parent = ();
    %{ $default_parent{'nagios'} }          = ();
    %{ $default_parent{'nagios_cgi'} }      = ();
    %{ $default_parent{'resource'} }        = ();
    %{ $default_parent{'nagios_cfg_misc'} } = ();
    my %where = ();
    my %setup_hash_array = StorProc->fetch_list_hash_array( 'setup', \%where );
    foreach my $prop ( keys %setup_hash_array ) {
	$default_parent{ $setup_hash_array{$prop}[1] }{$prop} = $setup_hash_array{$prop}[2];
    }
    return %default_parent;
}

sub get_groups() {
    my %monarchgroup_name = ();
    my %where             = ();

    %monarch_groups = ();
    %group_ids      = ();
    my %monarch_group_hash_array = StorProc->fetch_list_hash_array( 'monarch_groups', \%where );
    foreach my $id ( keys %monarch_group_hash_array ) {
	my $gname = $monarch_group_hash_array{$id}[1];
	$monarchgroup_name{$id}             = $gname;
	$group_ids{$gname}                  = $id;
	$monarch_groups{$gname}{'location'} = $monarch_group_hash_array{$id}[3];
	$monarch_groups{$gname}{'status'}   = $monarch_group_hash_array{$id}[4];
	%{ $monarch_groups{$gname}{'nagios_cgi'} }      = ();
	%{ $monarch_groups{$gname}{'nagios_cfg'} }      = ();
	%{ $monarch_groups{$gname}{'nagios_cfg_misc'} } = ();
	%{ $monarch_groups{$gname}{'resource'} }        = ();
	my %data = StorProc->parse_xml( $monarch_group_hash_array{$id}[5] );
	push @errors, delete $data{'error'} if defined $data{'error'};
	foreach my $prop ( keys %data ) {
	    $monarch_groups{$gname}{$prop} = $data{$prop};
	}
    }

    # Hosts assigned
    my %monarch_group_host_hash_array = StorProc->fetch_hash_array_generic_key( 'monarch_group_host', \%where );
    foreach my $key ( keys %monarch_group_host_hash_array ) {
	my $gname = $monarchgroup_name{ $monarch_group_host_hash_array{$key}[0] };
	my $hname = $host_name{ $monarch_group_host_hash_array{$key}[1] };
	$monarch_groups{$gname}{'hosts'}{$hname} = $monarch_group_host_hash_array{$key}[1];
    }

    # Host groups assigned
    my %monarch_group_hostgroup_hash_array = StorProc->fetch_hash_array_generic_key( 'monarch_group_hostgroup', \%where );
    foreach my $key ( keys %monarch_group_hostgroup_hash_array ) {
	my $gname  = $monarchgroup_name{ $monarch_group_hostgroup_hash_array{$key}[0] };
	my $hgname =    $hostgroup_name{ $monarch_group_hostgroup_hash_array{$key}[1] };
	$monarch_groups{$gname}{'hostgroups'}{$hgname} = $monarch_group_hostgroup_hash_array{$key}[1];
    }

    # Group macros to apply
    my %monarch_macro_hash_array = StorProc->fetch_list_hash_array( 'monarch_macros', \%where );
    my %monarch_group_macro_hash_array = StorProc->fetch_hash_array_generic_key( 'monarch_group_macro', \%where );
    foreach my $key ( keys %monarch_group_macro_hash_array ) {
	my $gname =        $monarchgroup_name{ $monarch_group_macro_hash_array{$key}[0] };
	my $mname = $monarch_macro_hash_array{ $monarch_group_macro_hash_array{$key}[1] }[1];
	$monarch_groups{$gname}{'macros'}{$mname} = $monarch_group_macro_hash_array{$key}[2];
    }

    # Contact group overrides
    my %contactgroup_group_hash_array = StorProc->fetch_hash_array_generic_key( 'contactgroup_group', \%where );
    foreach my $key ( keys %contactgroup_group_hash_array ) {
	my $gname = $monarchgroup_name{ $contactgroup_group_hash_array{$key}[1] };
	my $cname = $contactgroup_name{ $contactgroup_group_hash_array{$key}[0] };
	$monarch_groups{$gname}{'contactgroups'}{$cname} = $contactgroup_group_hash_array{$key}[0];
    }

    # Group properties -- nagios_cfg, nagios_cgi, and resource
    my %monarch_group_props_hash_array = StorProc->fetch_list_hash_array( 'monarch_group_props', \%where );
    foreach my $key ( keys  %monarch_group_props_hash_array ) {
	my $gname = $monarchgroup_name{ $monarch_group_props_hash_array{$key}[1] };
	my $prop  = $monarch_group_props_hash_array{$key}[2];
	my $type  = $monarch_group_props_hash_array{$key}[3];
	$monarch_groups{$gname}{$type}{$prop} = $monarch_group_props_hash_array{$key}[4];
    }

    # Determine inactive hosts with respect to Nagios.
    %inactive_hosts = ();
    foreach my $gname ( keys %monarch_groups ) {
	if ( ( $monarch_groups{$gname}{'status'} || 0 ) & 1 ) {
	    foreach my $hname ( keys %{ $monarch_groups{$gname}{'hosts'} } ) {
		$inactive_hosts{ $host_name_id{$hname} } = 1;
	    }
	    foreach my $hgname ( keys %{ $monarch_groups{$gname}{'hostgroups'} } ) {
		foreach my $hname ( @{ $host_groups{$hgname}{'members'} } ) {
		    $inactive_hosts{ $host_name_id{$hname} } = 1;
		}
	    }
	}
    }

    %parents_all = StorProc->get_group_parents_all();
    %parent_top  = StorProc->get_group_parents_top();
}

# http://en.wikipedia.org/wiki/Topological_sorting
sub tsort_groups(@) {
    my @top_groups = @_;
    my @sorted     = ();
    my $edges      = 0;

    my %group_parent = ();
    my %group_kid    = ();
    foreach my $parent ( keys %group_child ) {
	foreach my $kid ( keys %{ $group_child{$parent} } ) {
	    $group_parent{$kid}{$parent} = 1;
	    $group_kid{$parent}{$kid}    = 1;
	    ++$edges;
	}
    }

    while (@top_groups) {
	my $node = pop @top_groups;
	push @sorted, $node;
	foreach my $kid ( keys %{ $group_kid{$node} } ) {
	    delete $group_parent{$kid}{$node};
	    delete $group_kid{$node}{$kid};
	    --$edges;
	    push @top_groups, $kid if not %{ $group_parent{$kid} };
	}
    }

    if ($edges) {
	## By construction elsewhere, this should never happen.
	## If it could, we ought to list one element of a cycle.
	push @errors, "Error:  Cycle detected in group/sub-group setup.";
	## We return an empty list to force this situation to be noticed and fixed.
	return ();
    }

    return @sorted;
}

sub process_group() {
    @errors              = ();
    @out_files           = ();
    %use                 = ();
    @extinfofiles        = ();
    @group_process_order = ();
    @log                 = ();
    %host_group          = ();
    %host_service_group  = ();
    %group_hosts         = ();
    %group_child         = ();

    # processing a single instance
    %{ $group_hosts{$group} } = %{ $monarch_groups{$group} };

    $options{'nagios_home'} = $group_hosts{ $options{'group'} }{'nagios_etc'};
    unless ( $options{'commit_step'} eq 'preflight' || $options{'export'} ) {
	$destination = $group_hosts{$group}{'location'};
    }
    push @group_process_order, $group;
    my ( $group_hosts, $order, $group_child ) =
      StorProc->get_group_hosts( $options{'group'}, \%parents_all, \%group_ids, \%group_hosts, \@group_process_order, \%group_child );
    ## Later code depends on an ordering of child groups after parent groups so that contact groups assigned to sub
    ## groups will override contact groups assigned to parent groups.  Hence we need a topological sort here because
    ## get_group_hosts() may not return the groups in such an order if the sub-groups are ever shared between groups.
    %group_hosts         = %{$group_hosts};
    %group_child         = %{$group_child};
    @group_process_order = tsort_groups($group);
    %nagios_cfg          = %{ $monarch_groups{$group}{'nagios_cfg'} };
    %nagios_cgi          = %{ $monarch_groups{$group}{'nagios_cgi'} };
    %resource_cfg        = %{ $monarch_groups{$group}{'resource'} };
    %nagios_cfg_misc     = %{ $monarch_groups{$group}{'nagios_cfg_misc'} };
}

sub process_standalone() {
    @errors              = ();
    @out_files           = ();
    %use                 = ();
    @extinfofiles        = ();
    @group_process_order = ();
    @log                 = ();
    %host_group          = ();
    %host_service_group  = ();
    %group_hosts         = ();
    %group_child         = ();

    %{ $group_hosts{':all:'}{'macros'} }     = ();
    %{ $group_hosts{':all:'}{'hosts'} }      = ();
    %{ $group_hosts{':all:'}{'hostgroups'} } = ();
    $group_hosts{':all:'}{'inherit_host_active_checks_enabled'}     = 1;
    $group_hosts{':all:'}{'inherit_host_passive_checks_enabled'}    = 1;
    $group_hosts{':all:'}{'inherit_service_active_checks_enabled'}  = 1;
    $group_hosts{':all:'}{'inherit_service_passive_checks_enabled'} = 1;
    my %parent_cfg = get_default_parent();
    %nagios_cfg      = %{ $parent_cfg{'nagios'} };
    %nagios_cgi      = %{ $parent_cfg{'nagios_cgi'} };
    %resource_cfg    = %{ $parent_cfg{'resource'} };
    %nagios_cfg_misc = %{ $parent_cfg{'nagios_cfg_misc'} };

    if (%parent_top) {
	## Process parent groups
	foreach my $group ( sort keys %parent_top ) {
	    push @group_process_order, $group;
	    %{ $group_hosts{$group} } = %{ $monarch_groups{$group} };
	    my ( $group_hosts, $order, $group_child ) =
	      StorProc->get_group_hosts( $group, \%parents_all, \%group_ids, \%group_hosts, \@group_process_order, \%group_child );
	    %group_hosts         = %{$group_hosts};
	    %group_child         = %{$group_child};
	    @group_process_order = @{$order};
	}
	@group_process_order = tsort_groups(keys %parent_top);
    }
    else {
	## Useless branch; cannot happen.
	## No parent-child groups, just groups (if any [actually, none at all!]) to organize hosts/services by file.
	foreach my $group ( sort keys %monarch_groups ) {
	    push @group_process_order, $group;
	    %{ $group_hosts{$group} } = %{ $monarch_groups{$group} };
	    my ( $group_hosts, $order, $group_child ) =
	      StorProc->get_group_hosts( $group, \%parents_all, \%group_ids, \%group_hosts, \@group_process_order, \%group_child );
	    %group_hosts         = %{$group_hosts};
	    %group_child         = %{$group_child};
	    @group_process_order = @{$order};
	}
	@group_process_order = tsort_groups(keys %monarch_groups);
    }
    %{ $group_hosts{':all:'}{'hosts'} } = StorProc->get_group_orphans();
    push @group_process_order, ':all:';
}

sub read_db() {
    my $time_ref;
    my @timings = ();
    my $phasetime;

    StorProc->start_timing( \$phasetime );

    unless ($main::shutdown_requested) {
	# Hash contains all Nagios directives by objects
	%property_list = StorProc->property_list();
	StorProc->capture_timing( \@timings, \$phasetime, 'getting propery list' );
    }
    unless ($main::shutdown_requested) {
	# order matters
	get_timeperiods();
	StorProc->capture_timing( \@timings, \$phasetime, 'getting time periods' );
    }
    unless ($main::shutdown_requested) {
	get_commands();
	StorProc->capture_timing( \@timings, \$phasetime, 'getting commands' );
    }
    unless ($main::shutdown_requested) {
	get_contacts();
	StorProc->capture_timing( \@timings, \$phasetime, 'getting contacts' );
    }
    unless ($main::shutdown_requested) {
	get_contact_groups();
	StorProc->capture_timing( \@timings, \$phasetime, 'getting contact groups' );
    }
    unless ($main::shutdown_requested) {
	get_host_templates();
	StorProc->capture_timing( \@timings, \$phasetime, 'getting host templates' );
    }
    unless ($main::shutdown_requested) {
	get_hostextinfo();
	StorProc->capture_timing( \@timings, \$phasetime, 'getting host extended info' );
    }
    unless ($main::shutdown_requested) {
	get_hosts();
	StorProc->capture_timing( \@timings, \$phasetime, 'getting hosts' );
    }
    unless ($main::shutdown_requested) {
	get_hostgroups();
	StorProc->capture_timing( \@timings, \$phasetime, 'getting hostgroups' );
    }
    unless ($main::shutdown_requested) {
	get_host_dependencies();
	StorProc->capture_timing( \@timings, \$phasetime, 'getting host dependencies' );
    }
    unless ($main::shutdown_requested) {
	get_serviceextinfo();
	StorProc->capture_timing( \@timings, \$phasetime, 'getting service extended info' );
    }
    unless ($main::shutdown_requested) {
	$time_ref = get_services();
	push @timings, @$time_ref;
	StorProc->capture_timing( \@timings, \$phasetime, 'getting services' );
    }
    unless ($main::shutdown_requested) {
	get_escalations();
	StorProc->capture_timing( \@timings, \$phasetime, 'getting escalations' );
    }
    unless ($main::shutdown_requested) {
	get_groups();
	StorProc->capture_timing( \@timings, \$phasetime, 'getting groups' );
    }

    return \@timings;
}

sub gen_files() {
    my @timings = ();
    my $phasetime;

    StorProc->start_timing( \$phasetime );

    if ( !$destination ) {
	push( @errors,
		"You have not yet defined a build folder"
	      . ( $group ? " for the \"$group\" group" : '' )
	      . "!&nbsp; Check the Detail -> Build Instance Properties for this group." );
	return \@timings;
    }

    my $dir_exists = -d $destination;
    if ( !$dir_exists ) {
	## We only auto-create a new directory if it resides in certain known directories, doesn't
	## start with a dash or dot, and doesn't contain any slashes, whitespace, or shell metacharacters.
	## Disallowed characters:
	## =*?[]<>{}();|&$!`'"\/^~#@: space \n \r \t nbs all-other-controls soft-hyphen non-ISO-8859-1
	my @allowed_parent_dirs = qw(
	  /usr/local/groundwork/monarch/htdocs
	  /usr/local/nagios/etc
	);
	foreach my $parent_dir (@allowed_parent_dirs) {
	    if ( $destination =~ m{^$parent_dir/([^-./][^/]*)$} ) {
		if ( $group && $1 !~ /[^-%+,.:_0-9A-Za-z\xa1-\xac\xae-\xff]/ ) {
		    ## We will create a new writable directory, but we won't make an existing directory writable.
		    ## That would just invite security problems.
		    my $old_umask = umask 0022;
		    my $status = mkdir $destination, 0755;
		    push @errors, "Cannot create the build folder \"$destination\" ($!)." if not $status;
		    umask $old_umask;
		    $dir_exists = -d $destination;
		}
		last;
	    }
	}
    }
    if ( !$dir_exists || !-w $destination ) {
	use HTML::Entities ();
	my $html_desc = HTML::Entities::encode($destination);
	push( @errors,
		"The build folder"
	      . ( $group ? " for the \"$group\" group" : '' )
	      . " ($html_desc) is not a writable directory.&nbsp; Check the Detail -> Build Instance Properties for this group." );
	return \@timings;
    }

    # Set audit (always generate the audit log) and reset log
    $audit = 1;
    @log   = ();

    # Time stamps for file header
    $date_time = StorProc->datetime();

    unless ($main::shutdown_requested) {
	## Time periods and commands
	process_timeperiods();
	StorProc->capture_timing( \@timings, \$phasetime, 'processing time periods' );
    }
    unless ($main::shutdown_requested) {
	process_commands();
	StorProc->capture_timing( \@timings, \$phasetime, 'processing commands' );
    }
    unless ($main::shutdown_requested) {
	## Create host objects
	process_hostextinfo();
	StorProc->capture_timing( \@timings, \$phasetime, 'processing host extended info' );
    }
    unless ($main::shutdown_requested) {
	process_host_templates();
	StorProc->capture_timing( \@timings, \$phasetime, 'processing host templates' );
    }
    unless ($main::shutdown_requested) {
	process_hosts();
	StorProc->capture_timing( \@timings, \$phasetime, 'processing hosts' );
    }
    unless ($main::shutdown_requested) {
	process_host_dependencies();
	StorProc->capture_timing( \@timings, \$phasetime, 'processing host dependencies' );
    }
    unless ($main::shutdown_requested) {
	process_hostgroups();
	StorProc->capture_timing( \@timings, \$phasetime, 'processing hostgroups' );
    }
    unless ($main::shutdown_requested) {
	## Create service objects
	process_serviceextinfo();
	StorProc->capture_timing( \@timings, \$phasetime, 'processing service extended info' );
    }
    unless ($main::shutdown_requested) {
	process_service_templates();
	StorProc->capture_timing( \@timings, \$phasetime, 'processing service templates' );
    }
    unless ($main::shutdown_requested) {
	## FIX THIS:  adopt the alternate code as standard now, and remove the old process_services() routine
	my $use_alternate_code = 1;
	if ($use_alternate_code) {
	    my $time_ref = timed_process_services();
	    push @timings, @$time_ref;
	}
	else {
	    process_services();
	}
	StorProc->capture_timing( \@timings, \$phasetime, 'processing services' );
    }
    unless ($main::shutdown_requested) {
	process_service_dependencies();
	StorProc->capture_timing( \@timings, \$phasetime, 'processing service dependencies' );
    }
    unless ($main::shutdown_requested) {
	## Escalations
	process_escalation_templates();
	StorProc->capture_timing( \@timings, \$phasetime, 'processing escalation templates' );
    }
    unless ($main::shutdown_requested) {
	process_escalations();
	StorProc->capture_timing( \@timings, \$phasetime, 'processing escalations' );
    }
    unless ($main::shutdown_requested) {
	process_nagios_cgi();
	StorProc->capture_timing( \@timings, \$phasetime, 'processing nagios cgi' );
    }
    unless ($main::shutdown_requested) {
	## Contact objects
	process_contactgroups();
	StorProc->capture_timing( \@timings, \$phasetime, 'processing contact groups' );
    }
    unless ($main::shutdown_requested) {
	process_contact_templates();
	StorProc->capture_timing( \@timings, \$phasetime, 'processing contact templates' );
    }
    unless ($main::shutdown_requested) {
	process_contacts();
	StorProc->capture_timing( \@timings, \$phasetime, 'processing contacts' );
    }
    unless ($main::shutdown_requested) {
	## Nagios configuration files
	process_nagios_cfg();
	StorProc->capture_timing( \@timings, \$phasetime, 'processing nagios configuration' );
    }
    unless ($main::shutdown_requested) {
	process_resource_cfg();
	StorProc->capture_timing( \@timings, \$phasetime, 'processing nagios resources' );
    }
    unless ($main::shutdown_requested) {
	if ( $options{'tarball'} ) {
	    my @outfiles = ();
	    foreach my $file (@out_files) {
		push @outfiles, "$destination/$file";
	    }
	    use Archive::Tar;
	    my $tar = Archive::Tar->new;
	    $tar->add_files(@outfiles);
	    ## GWMON-4870
	    $date_time =~ tr/ :/._/;
	    unless ($group) { $group = 'complete' }
	    my $filename = "$destination/$group-nagios-$date_time.tar";
	    $tar->write($filename);
	    push @out_files, "$group-nagios-$date_time.tar";
	}
	if ($audit) {
	    push @log, "\n";
	    my $error = write_to_text_file( "$destination/$log_file", join( '', @log ) );
	    push( @errors, $error ) if ( defined($error) );
	    push @out_files, "$log_file";
	}
	StorProc->capture_timing( \@timings, \$phasetime, 'processing residual tarball stuff' );
    }

    return \@timings;
}

sub copy_files(@) {
    my $source_folder      = $_[1] or return "Error: copy_files() requires source_folder argument.";
    my $destination_folder = $_[2] or return "Error: copy_files() requires destination_folder argument.";
    require File::Copy;
    opendir( DIR, $source_folder ) or return "Error: Cannot open $source_folder ($!).";
    while ( my $file = readdir(DIR) ) {
	if ( $file =~ /^\./ ) { next }
	File::Copy::copy( "$source_folder/$file", "$destination_folder/$file" )
	  or return "Error: Cannot copy $source_folder/$file to $destination_folder/$file ($!).";
	my ( $dev, $ino, $mode ) = stat("$source_folder/$file")
	  or return "Error: Cannot find file permissions of $source_folder/$file ($!).";
	chmod $mode, "$destination_folder/$file" or return "Error: Cannot set file permissions of $destination_folder/$file ($!).";
    }
    closedir(DIR) or return "Error: Cannot close $source_folder ($!).";
}

sub rewrite_nagios_cfg(@) {
    my $preflight_folder = $_[1] or return "Error: rewrite_nagios_cfg() requires preflight path argument.";
    my $nagios_etc       = $_[2] or return "Error: rewrite_nagios_cfg() requires nagios etc path argument.";
    my @nagios_out       = ();
    open( NAGIOS_CFG, '<', "$preflight_folder/nagios.cfg" ) or return "Error:  Cannot open $preflight_folder/nagios.cfg to read ($!).";
    while ( my $line = <NAGIOS_CFG> ) {
	$line =~ s/$preflight_folder/$nagios_etc/;
	push @nagios_out, $line;
    }
    close(NAGIOS_CFG);
    open( NAGIOS_CFG, '>', "$nagios_etc/nagios.cfg" ) or return "Error:  Cannot open $nagios_etc/nagios.cfg to write ($!).";
    my $got_errno = '';
    if ( not print NAGIOS_CFG join( '', @nagios_out ) ) {
	$got_errno = "$!";
    }
    if ( not close(NAGIOS_CFG) and not $got_errno ) {
	$got_errno = "$!";
    }
    return "Error:  Cannot write to $nagios_etc/nagios.cfg ($got_errno)." if $got_errno;
    return;
}

# FIX LATER:  dead branch -- not called from anywhere; should probably be removed
sub build_instance(@) {
    %options = %{ $_[1] };
    $group   = $options{'group'};
    unless ($group) { $group = 'parent' }
    if ( $options{'commit_step'} eq 'preflight' ) {
	$options{'nagios_home'} = $options{'destination'};
    }
    unless ( ( $options{'commit_step'} eq 'preflight' ) || $options{'export'} ) {
	$audit = 1;
    }

    @errors = ();  # clear global state from previous attempts
    read_db();
    unless (@errors) {
	if ( $group eq 'parent' ) {
	    ## FIX MINOR:  this cannot work, because $destination (needed by later nested calls) is not set
	    ## (unless it's still set from some leftover previous processing and probably not correct for the
	    ## present usage).  Where should this value be picked up from?  Perhaps $options{'destination'} ?
	    process_standalone();
	}
	else {
	    ## This won't work for preflight or export, as $destination won't be defined within process_group() then.
	    process_group();
	}
	gen_files();
    }
    return \@out_files, \@errors;
}

sub build_all_instances(@) {
    %options = %{ $_[1] };
    @errors = ();  # clear global state from previous attempts
    read_db();
    return \@errors if @errors;
    $audit = 1;
    foreach my $grp ( keys %parent_top ) {
	$group = $grp;
	if ( $monarch_groups{$group}{'location'} ) {
	    if ( $options{'commit_step'} eq 'preflight' ) {
		$options{'nagios_home'} = $monarch_groups{$group}{'location'};
	    }
	    ## This $destination is only used for preflight or export; otherwise, it will be overridden within process_group().
	    $destination = $monarch_groups{$group}{'location'};
	    process_group();
	    gen_files();
	}
	return \@errors if @errors;
    }

    # Groups above, and now the main attraction ...
    $group = '';
    $destination = $options{'destination'};
    process_standalone();
    gen_files();

    return \@errors;
}

############################################################################
# build_files() -- this routine is here for backward compatibility,
# and gen_files() now drives file creation.
############################################################################

sub build_files(@) {
    my $user_acct = $_[1];
    $group = $_[2] || '';
    my $commit_step = $_[3];
    my $export      = $_[4];
    my $version     = $_[5];
    my $nagios_home = $_[6];
    $destination = $_[7];	# Will be overridden in process_group() except for preflight or export actions.
    my $tarball = $_[8];
    my $time_ref;
    my @timings = ();
    my $phasetime;
    @errors = ();  # clear global state from previous attempts

    $user_acct = '(unknown user)' if not defined $user_acct;

    StorProc->start_timing( \$phasetime );

    %options   = (
	'user_acct'      => $user_acct,
	'group'          => $group,
	'commit_step'    => $commit_step,
	'export'         => $export,
	'nagios_version' => $version,
	'nagios_home'    => $nagios_home,
	'destination'    => $destination,
	'tarball'        => $tarball
    );

    if ( $options{'commit_step'} eq 'preflight' ) {
	$nagios_home = $options{'destination'};
    }
    unless ( ( $options{'commit_step'} eq 'preflight' ) || $export ) {
	$audit = 1;
    }

    unless ($main::shutdown_requested) {
	$time_ref = read_db();
	push @timings, @$time_ref;
	StorProc->capture_timing( \@timings, \$phasetime, 'reading database' );
    }

    unless (@errors or $main::shutdown_requested) {
	if ( $options{'group'} ) {
	    ## processing a single instance
	    process_group();
	}
	else {
	    ## No group specified, so process standalone
	    process_standalone();
	}
	StorProc->capture_timing( \@timings, \$phasetime, 'processing instances' );
    }

    unless (@errors or $main::shutdown_requested) {
	$time_ref = gen_files();
	push @timings, @$time_ref;
	StorProc->capture_timing( \@timings, \$phasetime, 'generating files' );
    }

    if ($main::shutdown_requested) {
	push @errors, $interrupt_message;
    }

    return \@out_files, \@errors, \@timings;
}

# FIX MAJOR:  the following option names look like they need upgrading:
# inter_check_delay_method (Nagios 1.x only) => service_inter_check_delay_method
# aggregate_status_updates (obsolete as of Nagios 3.x)
# comment_file (obsolete as of Nagios 3.x)
# downtime_file (obsolete as of Nagios 3.x)
sub nagios_properties() {
    my @properties = qw{
	log_file
    <notification_options>
	enable_notifications
	notification_timeout
	admin_email
	admin_pager
    <configuration_options>
	resource_file
	website_url
    <time_format_options>
	date_format
	use_timezone
    <character_constraint_options>
	illegal_object_name_chars
	illegal_macro_output_chars
    <external_interface_options>
	check_external_commands
	command_check_interval
	command_file
	external_command_buffer_slots
	object_cache_file
	status_file
	status_update_interval
	event_broker_options
	broker_module
    <debug_options>
	debug_level
	debug_verbosity
	debug_file
	max_debug_file_size
    <check_execution_options>
	execute_host_checks
	accept_passive_host_checks
	execute_service_checks
	accept_passive_service_checks
    <check_scheduling_options>
	sleep_time
	host_inter_check_delay_method
	max_host_check_spread
	host_check_timeout
	cached_host_check_horizon
	enable_predictive_host_dependency_checks
	check_for_orphaned_hosts
	use_aggressive_host_checking
	service_inter_check_delay_method
	max_service_check_spread
	service_check_timeout
	cached_service_check_horizon
	enable_predictive_service_dependency_checks
	check_for_orphaned_services
	service_interleave_factor
	max_concurrent_checks
	interval_length
	auto_reschedule_checks
	auto_rescheduling_interval
	auto_rescheduling_window
    <freshness_check_options>
	check_host_freshness
	host_freshness_check_interval
	check_service_freshness
	service_freshness_check_interval
	additional_freshness_latency
    <obsessive-compulsive_processing_options>
	obsess_over_hosts
	ochp_command
	ochp_timeout
	obsess_over_services
	ocsp_command
	ocsp_timeout
    <check_result_processing_options>
	check_result_path
	check_result_reaper_frequency
	max_check_result_reaper_time
	max_check_result_file_age
    <object_state_processing_options>
	translate_passive_host_checks
	passive_host_checks_are_soft
	soft_state_dependencies
    <flapping_control_options>
	enable_flap_detection
	low_host_flap_threshold
	high_host_flap_threshold
	low_service_flap_threshold
	high_service_flap_threshold
    <performance_data_processing_options>
	process_performance_data
	host_perfdata_command
	host_perfdata_file
	host_perfdata_file_template
	host_perfdata_file_mode
	host_perfdata_file_processing_interval
	host_perfdata_file_processing_command
	service_perfdata_command
	service_perfdata_file
	service_perfdata_file_template
	service_perfdata_file_mode
	service_perfdata_file_processing_interval
	service_perfdata_file_processing_command
	perfdata_timeout
    <event_handling_options>
	enable_event_handlers
	global_host_event_handler
	global_service_event_handler
	event_handler_timeout
    <internal_operations_options>
	nagios_user
	nagios_group
	lock_file
	precached_object_file
	temp_file
	temp_path
    <state_retention_options>
	retain_state_information
	state_retention_file
	retention_update_interval
	use_retained_program_state
	use_retained_scheduling_info
	retained_host_attribute_mask
	retained_process_host_attribute_mask
	retained_contact_host_attribute_mask
	retained_service_attribute_mask
	retained_process_service_attribute_mask
	retained_contact_service_attribute_mask
    <large_installation_tweaks>
	use_large_installation_tweaks
	enable_environment_macros
	child_processes_fork_twice
	free_child_process_memory
    <logging_options>
	log_rotation_method
	log_archive_path
	log_notifications
	log_host_retries
	log_service_retries
	log_event_handlers
	log_initial_states
	log_external_commands
	log_passive_service_checks
	log_passive_checks
	use_syslog
    <miscellaneous_directives>
    };
    return @properties;
}

if ($debug) {
    %options = (
	'user_acct'      => 'test user',
	'group'          => '',
	'commit_step'    => 'preflight',
	'export'         => '',
	'nagios_version' => '3.x',
	'nagios_home'    => '/etc/nagios',
	'destination'    => '',
	'tarball'        => ''
    );
    StorProc->dbconnect;
    build_all_instances( '', \%options );
    StorProc->dbdisconnect;
}

1;
