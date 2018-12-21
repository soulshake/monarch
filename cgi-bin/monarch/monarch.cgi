#!/usr/bin/perl --
# MonArch - Groundwork Monitor Architect
# monarch.cgi
#
############################################################################
# Release 4.6
# June 2018
############################################################################
#
# Original author: Scott Parris
#
# Copyright 2007-2018 GroundWork Open Source, Inc. (GroundWork)
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

use CGI;
$CGI::POST_MAX = 1024 * 1024;  # max 1M posts, for security

use lib qq(/usr/local/groundwork/monarch/lib);
use MonarchForms;
use MonarchStorProc;
use MonarchDoc;
use MonarchValidation;
use MonarchInstrument;
use URI::Escape;
use Cwd 'realpath';

$|++;

#
############################################################################
# Global Declarations
#

my $debug = undef;

# Uncomment this next line to spill out details of each query at the end of the result screen.
# $debug = 1;

my @errors = ();
my $query  = new CGI;

# Adapt to an upgraded CGI package while still maintaining backward compatibility.
my $multi_param = $query->can('multi_param') ? 'multi_param' : 'param';

my $cgi_error = $query->cgi_error();
if (defined($cgi_error)) {
    my $page = "Content-type: text/html\n\n";
    $page .= Forms->header( 'Error', 'no_session', 'no_menu' );
    $page .= Forms->form_top( 'Interaction Error', '' );
    if ($cgi_error eq '413 Request entity too large') {
	# We exceeded POST_MAX.
	push @errors, 'You have tried to upload a file which is too large.';
    }
    elsif ($cgi_error eq '400 Bad request (malformed multipart POST)') {
	push @errors, 'A file upload has failed.';
    }
    else {
	push @errors, $cgi_error;
    }
    $page .= Forms->form_errors( \@errors );
    $page .= Forms->footer();
    print $page;
    exit 0;
}

my $top_menu   = $query->param('top_menu');
my $view       = $query->param('view');
my $obj        = $query->param('obj');
my $obj_view   = $query->param('obj_view');
my $task       = $query->param('task');
my $submit     = $query->param('submit');
my $user_acct  = $query->param('user_acct');
my $password   = $query->param('password');
my $session_id = $query->param('CGISESSID');
unless ($session_id) { $session_id = $query->cookie("CGISESSID") }
$session_id =~ s/[[:^xdigit:]]+//g if defined $session_id;
my $ez         = $query->param('ez');
my $page_title = 'Monarch';
my ( %auth_add, %auth_modify, %auth_delete, %properties, %authentication, %hidden ) = ();
my (
    $nagios_ver, $nagios_bin,  $nagios_etc,       $monarch_home,  $backup_dir, $is_portal,
    $upload_dir, $monarch_ver, $enable_externals, $enable_groups, $enable_ez,  $nagios_share
) = 0;
$hidden{'selected'} = $query->param('selected');
$hidden{'top_menu'} = $query->param('top_menu');
$hidden{'view'}     = $view;
$hidden{'obj'}      = $obj;
$hidden{'nocache'}  = time;
unless ($top_menu) { $top_menu = 'hosts' }
if ( $task && $task ne 'No' ) { $hidden{'task'} = $task }
my $table = $obj;
if ( defined($obj) && $obj eq 'commands' ) { $table = 'commands' }
my @messages = ();
my ( $body, $javascript ) = undef;
my $doc_root     = $ENV{'DOCUMENT_ROOT'};
my $userid       = undef;
my $refresh_url  = undef;
my $refresh_left = undef;
my $tab          = 1;

my %property_list = StorProc->property_list();
my %db_values     = StorProc->db_values();

my %required = ();
$required{'commands'}      = "name,type,command_line";
$required{'contactgroups'} = "name,alias";
$required{'contact_templates'} =
  "name,host_notification_period,service_notification_period,host_notification_options,service_notification_options";
$required{'contacts'}          = "name,alias,template";
$required{'contact_overrides'} = "host_notification_period,service_notification_period,host_notification_options,service_notification_options";
$required{'extended_host_info_templates'}    = "name";
$required{'extended_host_info'}              = "name,template";
$required{'extended_service_info'}           = "name";
$required{'extended_service_info_templates'} = "name";
$required{'host_dependencies'}               = "dependent_host,master_host,notification_failure_criteria";
$required{'hostgroups'}                      = "name,alias";
$required{'host_templates'}                  = "name,max_check_attempts,notification_interval,notification_period,notification_options";
$required{'hosts'}                           = "name,alias,address";
$required{'service_dependency'}              = "service_name";
$required{'service_dependency_templates'}    = "name,service_name";
$required{'escalation_templates'}            = "name,first_notification,last_notification,notification_interval";
$required{'service_templates'}               = "name";
$required{'services'}                        = "name,host_name";
$required{'time_periods'}                    = "name,alias";

my %obj_id = StorProc->get_obj_id();

my %obj_template = (
    'contacts'           => 'contact_templates',
    'service_templates'  => 'service_templates',
    'services'           => 'service_templates',
    'service_dependency' => 'service_dependency_templates',
    'hosts'              => 'host_templates'
);

my %obj_template_id = (
    'commands'                        => 'command_id',
    'contact_templates'               => 'contacttemplate_id',
    'contactgroups'                   => 'contactgroup_id',
    'contacts'                        => 'contact_id',
    'escalation_templates'            => 'template_id',
    'escalation_trees'                => 'tree_id',
    'extended_host_info_templates'    => 'hostextinfo_id',
    'extended_service_info_templates' => 'serviceextinfo_id',
    'host_dependencies'               => 'host_id',
    'host_templates'                  => 'hosttemplate_id',
    'hostgroups'                      => 'hostgroup_id',
    'hosts'                           => 'hosttemplate_id',
    'service_dependency'              => 'id',
    'service_dependency_templates'    => 'id',
    'service_templates'               => 'parent_id',
    'servicegroups'                   => 'servicegroup_id',
    'services'                        => 'servicetemplate_id',
    'time_periods'                    => 'timeperiod_id'
);

my %textsize = ();
$textsize{'low_flap_threshold'}    = 6;
$textsize{'high_flap_threshold'}   = 6;
$textsize{'notification_interval'} = 15;
$textsize{'first_notification'}    = 5;
$textsize{'last_notification'}     = 5;
$textsize{'max_check_attempts'}    = 5;
$textsize{'normal_check_interval'} = 15;
$textsize{'retry_check_interval'}  = 15;
$textsize{'check_interval'}        = 15;
$textsize{'retry_interval'}        = 15;
$textsize{'freshness_threshold'}   = 15;
$textsize{'notes'}                 = 75;
$textsize{'notes_url'}             = 75;
$textsize{'action_url'}            = 75;
$textsize{'email'}                 = 75;
$textsize{'pager'}                 = 75;
$textsize{'name'}                  = 50;
$textsize{'alias'}                 = 75;
$textsize{'address'}               = 16;
$textsize{'description'}           = 75;
$textsize{'command_line'}          = 75;
$textsize{'icon_image'}            = 70;
$textsize{'icon_image_alt'}        = 70;
$textsize{'vrml_image'}            = 70;
$textsize{'statusmap_image'}       = 70;
$textsize{'2d_coords'}             = 7;
$textsize{'3d_coords'}             = 7;
$textsize{'sunday'}                = 75;
$textsize{'monday'}                = 75;
$textsize{'tuesday'}               = 75;
$textsize{'wednesday'}             = 75;
$textsize{'thursday'}              = 75;
$textsize{'friday'}                = 75;
$textsize{'saturday'}              = 75;
$textsize{'small'}                 = 5;
$textsize{'file_size'}             = 10;
$textsize{'short_name'}            = 20;
$textsize{'long_name'}             = 70;
$textsize{'very_long_name'}        = 75;
my $empty_data = qq(<?xml version="1.0" encoding="iso-8859-1" ?>
<data>
</data>);

# Some buttons

my %add                 = ( 'name' => 'add',                 'value' => 'Add' );
my %save                = ( 'name' => 'save',                'value' => 'Save' );
my %delete              = ( 'name' => 'delete',              'value' => 'Delete' );
my %remove              = ( 'name' => 'remove',              'value' => 'Remove' );
my %select              = ( 'name' => 'select',              'value' => 'Select' );
my %cancel              = ( 'name' => 'cancel',              'value' => 'Cancel' );
my %close               = ( 'name' => 'close',               'value' => 'Close' );
my %next                = ( 'name' => 'next',                'value' => 'Next >>' );
my %back                = ( 'name' => 'back',                'value' => '<< Back' );
my %continue            = ( 'name' => 'continue',            'value' => 'Continue' );
my %abort               = ( 'name' => 'abort',               'value' => 'Abort' );
# my %host_vitals         = ( 'name' => 'obj_view',            'value' => 'Host Vitals' );
my %service_list        = ( 'name' => 'obj_view',            'value' => 'Service List' );
my %service_detail      = ( 'name' => 'obj_view',            'value' => 'Service Detail' );
my %rename              = ( 'name' => 'rename',              'value' => 'Rename' );
my %yes                 = ( 'name' => 'yes',                 'value' => 'Yes' );
my %no                  = ( 'name' => 'no',                  'value' => 'No' );
my %help                = ( 'name' => 'help',                'value' => 'Help' );
my %save_contact_groups = ( 'name' => 'save_contact_groups', 'value' => 'Save' );

# my %assign_contacts = ( 'name' => 'assign_contacts', 'value' => 'Assign Contacts' );
my %upload  = ( 'name' => 'upload',       'value' => 'Upload' );
my %sync    = ( 'name' => 'sync',         'value' => 'Sync With Main' );
my %default = ( 'name' => 'set_defaults', 'value' => 'Set Defaults' );

# for migration from contactgroup_assign to new separate tables
my %contactgroup_table_by_object = (
    'hosts'             => 'contactgroup_host',
    'monarch_group'     => 'contactgroup_group',
    'services'          => 'contactgroup_service',
    'host_templates'    => 'contactgroup_host_template',
    'service_templates' => 'contactgroup_service_template',
    'host_profiles'     => 'contactgroup_host_profile',
    'service_names'     => 'contactgroup_service_name',
    'hostgroups'        => 'contactgroup_hostgroup',
);

my %nagios_options_step = (
    'Notification'                => 1,
    'Configuration'               => 1,
    'Time Format'                 => 1,
    'Character Constraint'        => 1,
    'External Interface'          => 1,
    'Debug'                       => 1,
    'Check Execution'             => 2,
    'Check Scheduling'            => 2,
    'Freshness Check'             => 2,
    'Obsessive Processing'        => 2,
    'Check Result Processing'     => 3,
    'Object State Processing'     => 3,
    'Flapping Control'            => 3,
    'Performance Data Processing' => 3,
    'Event Handling'              => 3,
    'Internal Operations'         => 4,
    'State Retention'             => 4,
    'Large Installation Tweaks'   => 4,
    'Logging'                     => 4,
    'Miscellaneous Directives'    => 4
);

# '0+0' is treated by Perl as true, but by MySQL as zero (it is apparently able
# to convert the string to an expression and evaluate it).  This is what we need
# to sidestep the clumsy and inappropriate code in StorProc->update_obj_where()
# that recodes plain zeros as NULLs.  We need to force a true zero in the database
# to indicate that this value is really defined.
my $DEFINED = '0+0';
my $DEFINED_REF = \$DEFINED;

#
############################################################################
#	Sub to present errors
#

sub error_out($) {
    my $err = shift;
    $body .= "<h2>$err</h2><br>";
}

#
############################################################################
#	Sub to parse queries
#

sub parse_query($$) {
    my $data   = shift;
    my $object = shift;
    local $_;

    my %data_vals  = ();
    my %data_props = ();
    my %props      = ();

    # explain what each of these are:
    # data_vals
    # data_props
    # properties
    # %overrides in this routine is actually backward from what you would think it means.
    #     A positive value in this hash really means "inherit from template".  It represents
    #     the "inherit" button on each configuration element, which is 'on' if the checkbox
    #     is checked and you want inheritance, but missing (not provided in the CGI parameters)
    #     if the box is unchecked and you want to override the template.
    # db_values
    # name_vals
    # object
    # checks
    # parent group
    # t
    # s

    my @contactgroups = ();
    if ( $db_values{$data} =~ /,data/ ) {
	$data_vals{'data'} = "<?xml version=\"1.0\" encoding=\"iso-8859-1\" ?>\n<data>";
    }
    my %overrides = ();
    foreach my $name ( $query->param ) {
	if ( $name =~ /_override$/ ) {
	    $name =~ s/_override$//;
	    $overrides{$name} = 1;
	    $overrides{'template'} = 1;
	}
    }
    my %name_vals = ();
    foreach my $name ( $query->param ) {
	my $val = StorProc->sanitize_string_but_keep_newlines( scalar $query->param($name) );
	if ( $val eq '0' ) { $val = '-zero-' }
	unless ( $overrides{$name} || $name =~ /_override|nocache|servicename_id|^_|^value__/ ) {
	    $name_vals{$name} = $val;
	}
	if ( $name =~ /^value_(_.+)$/ ) {
	    $name_vals{$1} = $val;
	}
    }

    if ( $object eq 'host_templates' || $object eq 'host_overrides' ) {
	my @checks = ();
	if ( $nagios_ver =~ /^[23]\.x$/ ) {
	    @checks = (
		'notifications_enabled',     'check_freshness',       'obsess_over_host',       'passive_checks_enabled',
		'active_checks_enabled',     'event_handler_enabled', 'flap_detection_enabled', 'process_perf_data',
		'retain_status_information', 'retain_nonstatus_information'
	    );
	}
	else {
	    @checks = (
		'checks_enabled',    'notifications_enabled',     'event_handler_enabled', 'flap_detection_enabled',
		'process_perf_data', 'retain_status_information', 'retain_nonstatus_information'
	    );
	}
	foreach my $check (@checks) {
	    unless ( $name_vals{$check} ) { $name_vals{$check} = '-zero-' }
	}
    }
    if ( $object eq 'service_templates' || $object eq 'service_overrides' ) {
	my @checks = ( 'is_volatile', 'active_checks_enabled', 'passive_checks_enabled' );
	push @checks, 'parallelize_check' if $nagios_ver =~ /^[12]\.x$/;
	push @checks,
	  (
	    'obsess_over_service', 'check_freshness',           'event_handler_enabled',        'flap_detection_enabled',
	    'process_perf_data',   'retain_status_information', 'retain_nonstatus_information', 'notifications_enabled'
	  );
	foreach my $check (@checks) {
	    unless ( $name_vals{$check} ) { $name_vals{$check} = '-zero-' }
	}
    }
    my $use_template_command = $query->param('use_template_command');
    my @db_vals              = split( /,/, $db_values{$data} );
    my @props                = split( /,/, $property_list{$object} );
    foreach my $p (@props) {
	$props{$p} = 1;
    }
    if (   exists( $props{'notifications_enabled'} )
	&& exists( $props{'notification_options'} )
	&& $obj !~ /template/ )
    {
	if (   ( defined( $query->param('notifications_enabled_override') ) || defined( $query->param('notifications_enabled') ) )
	    && ( !defined( $query->param('notification_options_override') ) )
	    && ( !defined( $query->param('notification_options') ) ) )
	{
	    ( my $single_obj = $obj ) =~ s/s$//;
	    push @errors,
"You attempted to save an unsupported configuration. If you wish to turn off all notifications for this $single_obj, do so by turning off <i>Notifications enabled</i> at the template or $single_obj level rather than by disabling all the individual <i>Notification options</i> choices at the $single_obj level. The <i>Notification options</i> choices below have been reset to the selections from the template.";
	}
    }
    foreach my $name ( keys %name_vals ) {
	if ( $name =~ /check_command|^event_handler$/ ) {
	    my %c = StorProc->fetch_one( 'commands', 'name', $name_vals{$name} );
	    $data_vals{$name}  = $c{'command_id'};
	    $properties{$name} = $name_vals{$name};
	    $data_props{$name} = $data_vals{$name};
	}
	elsif ( $name eq 'command_line' ) {
	    unless ( $use_template_command || $object eq 'service_overrides' ) {
		my $command_line = $name_vals{$name};
		$data_vals{'data'} .= "\n  <prop name=\"command_line\"><![CDATA[$command_line]]>\n  </prop>";
		delete $data_vals{$name};
		$properties{$name} = $name_vals{$name};
		$data_props{$name} = $name_vals{$name};
	    }
	}
	elsif ( $name =~ /service_description|service_name/ ) {
	    $properties{$name} = $name_vals{$name};
	    my %s = StorProc->fetch_one( 'service_names', 'name', $properties{$name} );
	    $data_vals{'servicename_id'} = $s{'servicename_id'};
	}
	elsif ( $name eq 'host_profile' ) {
	    my %p = StorProc->fetch_one( 'profiles_host', 'name', $name_vals{$name} );
	    $data_vals{'hostprofile_id'} = $p{'hostprofile_id'};
	    $properties{$name} = $name_vals{$name};
	}
	elsif ( $name eq 'dependent_host' ) {
	    my %h = StorProc->fetch_one( 'hosts', 'name', $name_vals{$name} );
	    $data_vals{'host_id'} = $h{'host_id'};
	    $properties{$name} = $name_vals{$name};
	}
	elsif ( $name eq 'master_host' ) {
	    my %h = StorProc->fetch_one( 'hosts', 'name', $name_vals{$name} );
	    $data_vals{'parent_id'} = $h{'host_id'};
	    $properties{$name} = $name_vals{$name};
	}
	elsif ( $name =~ /members|contact|contactgroup|parents/ ) {
	    my @members = $query->$multi_param($name);
	    delete $properties{$name};
	    if ( $name eq 'contactgroup' && $obj eq 'service_templates' ) {
		@contactgroups = sort @members;
	    }
	    foreach (@members) { $properties{$name} .= "$_," }
	    chop $properties{$name};
	    $data_vals{$name}  = $properties{$name};
	    $data_props{$name} = $properties{$name};
	}
	elsif ( $name =~
	    /notification_options$|^stalking_options$|^notification_failure_criteria$|^execution_failure_criteria$|^escalation_options$/ )
	{
	    my @members = $query->$multi_param($name);
	    $properties{$name} = join( ',', @members );
	}
	elsif ( $name =~ /notification_commands/ ) {
	    my @members = $query->$multi_param($name);
	    delete $properties{$name};
	    foreach my $m (@members) {
		if ($m) {
		    $properties{$name} .= "$m,";
		    my %c = StorProc->fetch_one( 'commands', 'name', $m );
		    $data_vals{$name} .= "$c{'command_id'},";
		}
	    }
	    chop $data_vals{$name} if defined $data_vals{$name};
	    chop $properties{$name} if defined $properties{$name};
	}
	elsif ( $name eq 'last_notification' ) {
	    my $last_notification = $query->param('last_notification');
	    if ( $last_notification eq '0' ) {
		$properties{'last_notification'} = '-zero-';
	    }
	    else {
		$properties{'last_notification'} = $last_notification;
	    }
	}
	elsif ( $name =~ /period/ ) {
	    my %t = StorProc->fetch_one( 'time_periods', 'name', $name_vals{$name} );
	    $data_vals{$name}  = $t{'timeperiod_id'};
	    $data_props{$name} = $data_vals{$name};
	    $properties{$name} = $name_vals{$name};
	}
	elsif ( $name =~ /escalation/ ) {
	    my %t = StorProc->fetch_one( 'escalation_trees', 'name', $name_vals{$name} );
	    $data_vals{$name}  = $t{'tree_id'};
	    $properties{$name} = $name_vals{$name};
	}
	elsif ( $name =~ /template/ ) {
	    my $value = $name_vals{$name};
	    my %t = StorProc->fetch_one( $obj_template{$object}, 'name', $value );
	    $data_vals{ $obj_template_id{ $obj_template{$object} } } = $t{ $obj_template_id{ $obj_template{$object} } };
	    delete $data_vals{'template'};
	    if ( $obj eq 'service_templates' ) {
		$data_props{'parent_id'} = $t{'servicetemplate_id'};
		$data_vals{'parent_id'}  = $t{'servicetemplate_id'};
	    }
	    delete $data_vals{'template'};
	    delete $data_props{'template'};
	    if ( !$properties{'template'} ) {
		$properties{'template'} = $name_vals{$name};
	    }
	}
	elsif ( $name eq 'notes' ) {
	    $name_vals{$name} =~ s/\n/<br>/g;
	    $properties{$name} = $name_vals{$name};
	    $data_props{$name} = $properties{$name};
	}
	else {
	    $properties{$name} = $name_vals{$name};
	    $data_props{$name} = $properties{$name};
	}
	if ( !$overrides{$name} ) {
	    if ( $name eq 'escalation_options' ) {
		$data_vals{'data'} .= "\n  <prop name=\"$name\"><![CDATA[$properties{$name}]]>\n  </prop>";
		$data_props{$name} = $properties{$name};
	    }
	    if ( exists( $props{$name} ) ) {
		unless (
		    $name =~ /^template_id|^event_handler$|command|service_description|members|contact|contactgroup|parents|escalation|period/ )
		{
		    my $match = undef;
		    foreach my $val (@db_vals) {
			unless ( $val =~ /template/ ) {
			    if ( $val eq $name ) {
				$data_vals{$val} = $name_vals{$name};
				$match = 1;
				last;
			    }
			}
		    }
		    if ( !$match && $data_vals{'data'} ) {
			if ( $properties{$name} ) {
			    $data_vals{'data'} .= "\n  <prop name=\"$name\"><![CDATA[$properties{$name}]]>\n  </prop>";
			    $data_props{$name} = $properties{$name};
			}
		    }
		}
	    }
	}
    }

    if ( $obj eq 'hosts' ) {
	## We must pull the applicable template name directly from the query parameters because if you modified the
	## template name on-screen before a save, $properties{template} still contains the old template name.
	my %t = StorProc->fetch_one( 'host_templates', 'name', scalar $query->param('template') );
	$data_vals{'data'} .= custom_variables('hosts', 'manage', 'host_templates', $t{'name'}, \%t);
    }
    elsif ( $obj eq 'host_templates' ) {
	## host template chains are not currently supported
	$data_vals{'data'} .= custom_variables('hosts', 'manage', 'host_templates', undef, {});
    }
    ## Currently, ($obj eq 'profiles') is not reliably present, so we ignore it;
    ## and we don't bother to pre-qualify with ($top_menu eq 'profiles').
    elsif ( $view eq 'host_profile' ) {
	## We must pull the template name directly from the query parameters because
	## %properties doesn't contain either old or new template name for this case.
	my %t = StorProc->fetch_one( 'host_templates', 'name', scalar $query->param('template') );
	$data_vals{'data'} .= custom_variables('hosts', 'manage', 'host_templates', $t{'name'}, \%t);
    }
    elsif ( $obj eq 'contact_templates' ) {
	## contact template chains are not currently supported
	$data_vals{'data'} .= custom_variables('contacts', 'manage', 'contact_templates', undef, {});
    }
    elsif ( $obj eq 'service_templates' ) {
	if ( $data_props{'parent_id'} ) {
	    %data_vals              = ();
	    $data_vals{'parent_id'} = $data_props{'parent_id'};
	    $data_vals{'data'}      = "<?xml version=\"1.0\" encoding=\"iso-8859-1\" ?>\n<data>";
	    my %parent = StorProc->get_template_properties( $data_props{'parent_id'} );
	    foreach my $name ( keys %data_props ) {
		if ( $parent{$name} eq $data_props{$name} ) {
		    delete $data_props{$name};
		}
	    }
	    delete $data_props{'template'};
	    foreach my $name ( keys %data_props ) {
		my $got_it = 0;
		foreach my $p (@props) {
		    if ( $name eq $p ) { $got_it = 1 }
		}
		unless ($got_it) { delete $data_props{$name} }
	    }
	    foreach my $name ( keys %data_props ) {
		if ( $name =~ /^event_handler$|parent_id|check_command|contactgroup|parent|period|name/ ) {
		    $data_vals{$name} = $data_props{$name};    # what is going on here?
		}
		else {
		    $data_vals{'data'} .= "\n  <prop name=\"$name\"><![CDATA[$data_props{$name}]]>\n  </prop>";
		}
	    }

	    # FIX THIS:  what's the point of these loops?
	    foreach my $cg (@contactgroups) {
		my $got_group = 0;
		foreach my $pg ( @{ $parent{'contactgroup'} } ) {
		    if ( $pg eq $cg ) { $got_group = 1 }
		}
	    }
	}
    }

    $properties{'save'} = 1;
    if ( $data_vals{'data'} ) { $data_vals{'data'} .= "\n</data>" }
    return %data_vals;
}

#
############################################################################
# Check Fields - uniqueness/missing info
#

sub check_fields() {
    my @req = split( /,/, $required{$table} );
    my $missing = '';
    foreach my $r (@req) {
	if ( $obj eq 'hostgroups' && $nagios_ver =~ /^[23]\.x$/ && $r eq 'contactgroup' ) {
	    next;
	}
	unless ( $properties{$r} ) {
	    $required{$r} = 1;
	    $required{'missing'} = 1;
	    $missing .= "$r,";
	}
    }
    chop $missing;
    $missing .= ".";

    if ( $required{'missing'} ) {
	push @errors, "Missing required fields: $missing";
    }
    elsif ( $query->param('add') || (defined($submit) && $submit eq 'Add') ) {
	unless ( $obj =~ /host_dependencies/ ) {
	    my %res = StorProc->fetch_one( $table, 'name', $properties{'name'} );
	    if ( $res{'name'} ) {
		my $type = $obj;
		$type =~ s/_/ /g;
		$type =~ s/s$//g;
		$type =~ s/(?:host|service) escalation template$/an escalation named/;
		push @errors, "\u$type \"$properties{'name'}\" already exists.";
	    }
	}
    }
    if (@errors) {
	return 1;
    }
    else {
	return 0;
    }
}

#
############################################################################
# Sub eval errors
#

sub eval_errors($) {
    my @eval   = shift;
    my @errors = ();
    foreach my $err (@eval) {
	unless ( $err =~ /duplicate|1/i ) {
	    push @errors, $err;
	}
    }
    return @errors;
}

#
############################################################################
# Sub to build most forms
#

sub build_form($;$) {
    my $validation_mini_profile = $_[0] || {};
    my $help_url                = $_[1];
    local $_;

    my $form           = undef;
    my $extended_props = undef;
    my $name           = $query->param('name');
    my $source         = $query->param('source');
    my $ext_props      = $query->param('ext_props');

    $hidden{'source'} = $source;
    my $dfv_profile = Validation->dfv_profile_javascript($validation_mini_profile);

    ############################################################################
    # Get Properties
    #

    unless ( $properties{'save'} ) {
	if ( defined($task) && $task eq 'new' ) {
	    my @p_list = split( /,/, $property_list{$obj} );
	    foreach my $p (@p_list) { $properties{$p} = '' }
	    if ( $obj eq 'host_templates' ) {
		## GWMON-7030: set some sensible default values
		$properties{'max_check_attempts'} = '3';
		$properties{'check_interval'} = '0';
	    }
	}
	elsif ( defined($task) && $task =~ /copy|use/ ) {
	    $name = $source;
	    %properties = StorProc->fetch_one( $table, 'name', $name );
	    if ( $task eq 'use' ) { $properties{'template'} = $source }
	    $properties{'name'} = undef;
	}
	else {
	    %properties = StorProc->fetch_one( $table, 'name', $name );
	}
    }

    if ( $obj eq 'contacts' && $task eq 'new' ) {
	$table = 'contact_templates';
	$task  = 'use';
    }
    my @props = split( /,/, $property_list{$obj} );

    if ( defined($task) && $task eq 'modify' ) { $source = $name }

    ############################################################################
    # Top of form
    #
    my $title = undef;
    my @t_parse = split( /_/, $obj );
    foreach (@t_parse) { $_ =~ s/ies/y/g; $title .= "\u$_ "; }
    $title =~ s/s\s$//;
    $title =~ s/Wizard/Extended/;
    my $form_top = undef;
    if ( $title =~ /Escalation/ ) { $title =~ s/Template//; }

    unless ( $obj eq 'service_templates' ) {
	$form_top = Forms->form_top( "$title Properties", Validation->dfv_onsubmit_javascript(
	    "if (this.clicked == 'cancel') { return true; }"
	) );
	if ( defined($task) && $task eq 'modify' ) {
	    $form .= Forms->display_hidden( "\u\L$title\E name:", 'name', $properties{'name'} );
	}
	elsif ( $obj eq 'host_dependencies' ) {
	    my @hosts = StorProc->fetch_list( 'hosts', 'name' );
	    $form .= Forms->list_box( 'Dependent host name:', 'name', \@hosts, $properties{'name'}, $required{'name'} );
	}
	else {
	    $form .= Forms->text_box( "\u\L$title\E name:", 'name', $properties{'name'}, $textsize{'name'}, $required{'name'}, '', '', $tab++ );
	}
    }
    my %props = ();
    foreach my $property (@props) { $props{$property} = $property }
    if ( $obj eq 'service_templates' ) {
	delete $props{'check_command'};
	delete $props{'command_line'};
    }
    if ( $obj eq 'host_templates' ) {
	if ( $nagios_ver eq '1.x' ) {
	    delete $props{'active_checks_enabled'};
	    delete $props{'passive_checks_enabled'};
	    delete $props{'obsess_over_host'};
	    delete $props{'check_period'};
	    delete $props{'check_freshness'};
	    delete $props{'check_interval'};
	    delete $props{'retry_interval'};
	    delete $props{'freshness_threshold'};
	    delete $props{'contactgroup'};
	}
	elsif ( $nagios_ver eq '2.x' ) {
	    delete $props{'retry_interval'};
	}
	else {
	    delete $props{'checks_enabled'};
	}
    }
    if ( $obj =~ /escalation/ && $nagios_ver eq '1.x' ) {
	delete $props{'escalation_period'};
	delete $props{'escalation_options'};
    }
    if ( $obj eq 'hostgroups' ) {
	my $validation_mini_profile = { name => { constraint => '[^/\\\\`~\+!\$\%\^\&\*\|\'\"<>\?,\(\)\'=\[\]\{\}\:\#;]+' } };
	$dfv_profile = Validation->dfv_profile_javascript($validation_mini_profile);
    }

    #
    ##########################################################################
    # Body of form
    #
    if ( defined $properties{'error'} ) {
	$form .= Forms->form_errors( [ '<pre>' . HTML::Entities::encode( $properties{'error'} ) . '</pre>' ] );
    }

    my %docs = Doc->properties_doc( $obj, \@props, $view );
    foreach my $property (@props) {
	$properties{$property} =~ s/-zero-/0/g if defined $properties{$property};
	if ( defined $props{$property} ) {
	    my $p_title = "\u$property:";
	    $p_title =~ s/_/ /g;
	    if (
		$props{$property} =~ /
		    ^is_volatile
		    | ^checks_enabled$
		    | ^notifications_enabled$
		    | ^obsess_over_host
		    | ^obsess_over_service$
		    | ^check_freshness$
		    | ^passive_checks_enabled$
		    | ^active_checks_enabled$
		    | ^event_handler_enabled$
		    | ^flap_detection_enabled$
		    | ^process_perf_data$
		    | ^retain_status_information$
		    | ^retain_nonstatus_information$
		/x
		|| ( $nagios_ver =~ /^[12]\.x$/ && $props{$property} =~ /^parallelize_check$/ )
	      )
	    {
		$form .= Forms->checkbox( $p_title, $property, $properties{$property}, $docs{$property}, '', $tab++ );
	    }
	    elsif ( $props{$property} eq 'contactgroup' ) {
		my @members = ();
		if ( $properties{'save'} ) {
		    @members = split( /,/, $properties{'contactgroup'} ) if defined $properties{'contactgroup'};
		}
		elsif ( defined $properties{ $obj_id{$obj} } ) {
		    @members = StorProc->get_contactgroups( $obj, $properties{ $obj_id{$obj} } );
		}
		my @nonmembers = StorProc->fetch_list( 'contactgroups', 'name' );
		if ( $obj =~ /escalation|host_templates|service_templates/ ) {
		    my $validation_mini_profile =
		      { contactgroup => { constraint => '[- A-Za-z_0-9]+', message => 'Value must be alphanumeric.' }, };
		    $dfv_profile = Validation->dfv_profile_javascript($validation_mini_profile);
		    $form .= Forms->members(
			'Contact Groups:', 'contactgroup', \@members, \@nonmembers, $required{$property}, '10',
			$docs{$property},  '',             $tab++
		    );
		    $form_top = Forms->form_top( "$title Properties", Validation->dfv_onsubmit_javascript('selIt()') );
		    $tab += 3;
		}
		elsif ( $obj eq 'hostgroups' ) {
		    $form .= Forms->members(
			'Contact Groups:', 'contactgroup', \@members, \@nonmembers, $required{$property}, '10',
			$docs{$property},  '',             $tab++
		    );
		    $form_top = Forms->form_top( "$title Properties",
			Validation->dfv_onsubmit_javascript("if (this.clicked.match(/^(delete|rename|cancel)\$/)) { return true; } selIt()") );
		    $tab += 3;
		}
		else {
		    ## Might be a dead branch now.
		    $form .= Forms->list_box_multiple(
			'Contact Groups:',
			'contactgroup', \@nonmembers, \@members, $required{'contactgroup'},
			$docs{$property}, '', $tab++
		    );
		}
	    }
	    elsif ( $props{$property} =~ /^icon_image$|^vrml_image$/ ) {
		if ( -d "$nagios_share/images/logos" ) {
		    my @includes = ( 'gif', 'png', 'jpg', 'jpeg' );
		    my @files = StorProc->get_dir( "$nagios_share/images/logos", \@includes );
		    $form .=
		      Forms->list_box( $p_title, $property, \@files, $properties{$property}, $required{$property}, $docs{$property}, '',
			$tab++ );
		}
		else {
		    $form .=
		      Forms->text_box( $p_title, $property, $properties{$property}, $textsize{$property}, $required{$property},
			$docs{$property}, '', $tab++ );
		}
	    }
	    elsif ( $props{$property} =~ /^statusmap_image$/ ) {
		if ( -d "$nagios_share/images/logos" ) {
		    my @includes = ('gd2');
		    my @files = StorProc->get_dir( "$nagios_share/images/logos", \@includes );
		    $form .=
		      Forms->list_box( $p_title, $property, \@files, $properties{$property}, $required{$property}, $docs{$property}, '',
			$tab++ );
		}
		else {
		    $form .=
		      Forms->text_box( $p_title, $property, $properties{$property}, $textsize{$property}, $required{$property},
			$docs{$property}, '', $tab++ );
		}
	    }
	    elsif ( $props{$property} eq 'members' ) {
		my @members;
		if ( $properties{'save'} ) {
		    @members = split( /,/, ( defined( $properties{'members'} ) ? $properties{'members'} : '' ) );
		}
		elsif ( $task =~ /copy|modify/ ) {
		    @members = StorProc->get_names_in( 'host_id', 'hosts', 'hostgroup_host', 'hostgroup_id', $properties{'hostgroup_id'} );
		}
		my @nonmembers = StorProc->fetch_list( 'hosts', 'name' );
		$form .= Forms->members( $p_title, $property, \@members, \@nonmembers, $required{$property}, '', $docs{$property}, '', $tab++ );
		$form_top = Forms->form_top( "$title Properties",
		    Validation->dfv_onsubmit_javascript("if (this.clicked.match(/^(delete|rename|cancel)\$/)) { return true; } selIt()") );
		$tab += 3;
	    }
	    elsif ( $props{$property} eq 'contact' ) {
		my @members = ();
		if ( $properties{'save'} ) {
		    @members = split( /,/, $properties{'contact'} );
		}
		elsif ( $task =~ /copy|modify/ ) {
		    @members =
		      StorProc->get_names_in( 'contact_id', 'contacts', 'contactgroup_contact', 'contactgroup_id',
			$properties{ $obj_id{$obj} } );
		}
		my @nonmembers = StorProc->fetch_list( 'contacts', 'name' );
		$form .=
		  Forms->members( 'Contacts:', 'contact', \@members, \@nonmembers, $required{$property}, 20, $docs{$property}, '', $tab++ );
		$form_top = Forms->form_top( "$title Properties", 'onsubmit="selIt();"' );
	    }
	    elsif ( $props{$property} eq 'stalking_options' ) {
		my @opts = split( /,/, ( defined( $properties{$property} ) ? $properties{$property} : '' ) );
		$form .= Forms->stalking_options( $obj, \@opts, $required{$property}, $docs{$property}, '', $tab++ );
		$tab += 3;
	    }
	    elsif ( $props{$property} =~ /notification_options|escalation_options/ ) {
		my @opts = split( /,/, ( defined( $properties{$property} ) ? $properties{$property} : '' ) );
		$form .=
		  Forms->notification_options( $obj, $property, \@opts, $required{$property}, $nagios_ver, $docs{$property}, '', $tab++ );
	    }
	    elsif ( $props{$property} =~ /host_name$/ ) {
		my @hosts = StorProc->fetch_list( 'hosts', 'name' );
		$form .=
		  Forms->list_box( $p_title, $property, \@hosts, $properties{$property}, $required{$property}, $docs{$property}, '', $tab++ );
	    }
	    elsif ( $props{$property} =~ /host_escalation|service_escalation/ ) {
		my $type = $property;
		$type    =~ s/_escalation_id//;
		$p_title =~ s/id/tree/;
		my %where = ( 'type' => $type );
		my @list = StorProc->fetch_list_where( 'escalation_trees', 'name', \%where, 'name' );
		my %t = ();
		if (defined $properties{$property} && $properties{$property} ne '') {
		    %where = ( 'tree_id' => $properties{$property} );
		    %t = StorProc->fetch_one_where( 'escalation_trees', \%where );
		}
		$form .= Forms->list_box( $p_title, $property, \@list, $t{'name'}, '', $docs{$property}, '', $tab++ );
	    }
	    elsif ( $props{$property} =~ /service_name$|service_description/ ) {
		unless ( $task eq 'new' || $properties{'save'} ) {
		    my %s = StorProc->fetch_one( 'service_names', 'servicename_id', $properties{'servicename_id'} );
		    $properties{$property} = $s{'name'};
		}
		my @services = ();
		if ( $obj =~ /escalation/ ) { push @services, '*' }
		my @svcs = StorProc->fetch_list( 'service_names', 'name' );
		push( @services, @svcs );
		$form .=
		  Forms->list_box( $p_title, $property, \@services, $properties{$property}, $required{$property}, $docs{$property}, '',
		    $tab++ );
	    }
	    elsif ( $props{$property} =~ /check_command$|event_handler$/ ) {
		unless ( $task eq 'new' || $properties{'save'} ) {
		    my %p = defined( $properties{$property} ) ? StorProc->fetch_one( 'commands', 'command_id', $properties{$property} ) : ();
		    $properties{$property} = $p{'name'};
		}
		my @commands = StorProc->fetch_list( 'commands', 'name' );
		$form .=
		  Forms->list_box( $p_title, $property, \@commands, $properties{$property}, $required{$property}, $docs{$property}, '',
		    $tab++ );
	    }
	    elsif ( $props{$property} eq 'type' ) {
		unless ( $obj =~ /escalation/ ) {
		    my @types = ( 'check', 'notify', 'other' );
		    $form .=
		      Forms->list_box( $p_title, $property, \@types, $properties{$property}, $required{$property}, $docs{$property}, '',
			$tab++ );
		}
	    }
	    elsif ( $props{$property} =~ /notification_commands/ ) {
		my %w = ( 'type' => 'notify' );
		my @commands = StorProc->fetch_list_where( 'commands', 'name', \%w );
		my @selected = split( /,/, ( defined( $properties{$property} ) ? $properties{$property} : '' ) );
		unless ( $task eq 'new' || $properties{'save'} ) {
		    if ( $property =~ /(\S+)_notification_commands/ ) {
			my %w = ( 'type' => $1, 'contacttemplate_id' => $properties{'contacttemplate_id'} );
			@selected = StorProc->fetch_list_where( 'contact_command', 'command_id', \%w );
			my @sel;
			foreach (@selected) {
			    my %p = StorProc->fetch_one( 'commands', 'command_id', $_ );
			    push @sel, $p{'name'};
			}
			@selected = @sel;
		    }
		}
		$form .=
		  Forms->list_box_multiple( $p_title, $property, \@commands, \@selected, $required{$property}, $docs{$property}, '', $tab++ );
	    }
	    elsif ( $props{$property} =~ /notification_period|check_period|escalation_period/ ) {
		unless ( ( defined($task) && $task eq 'new' ) || $properties{'save'} ) {
		    my %p = StorProc->fetch_one( 'time_periods', 'timeperiod_id', $properties{$property} );
		    $properties{$property} = $p{'name'};
		}
		my @periods = StorProc->fetch_list( 'time_periods', 'name' );
		$form .=
		  Forms->list_box( $p_title, $property, \@periods, $properties{$property}, $required{$property}, $docs{$property}, '', $tab++ );
	    }
	    elsif ( $props{$property} =~ /notification_failure_criteria|execution_failure_criteria/ ) {
		my @opts = split( /,/, ( defined( $properties{$property} ) ? $properties{$property} : '' ) );
		$form .= Forms->failure_criteria( $property, \@opts, '', $required{$property}, $docs{$property}, '', $tab++ );
	    }
	    elsif ( $props{$property} eq 'template' && $obj eq 'service_templates' ) {
		my @templates = StorProc->get_possible_parents( $properties{'servicetemplate_id'} );
		my %t =
		  defined( $properties{'parent_id'} )
		  ? StorProc->fetch_one( 'service_templates', 'servicetemplate_id', $properties{'parent_id'} )
		  : ();
		$properties{$property} = $t{'name'};

		# FIX THIS:  change label to 'Parent service template:'?
		$form .= Forms->list_box_submit( 'Use:', $property, \@templates, '', $required{$property}, $docs{$property}, $tab++ );
	    }
	    elsif ( $props{$property} eq 'template' ) {
		if ( $obj eq 'contacts' ) { $table = 'contact_templates' }
		unless ( $obj eq 'service_templates' || $task eq 'new' || $properties{'save'} ) {
		    my %t =
		      StorProc->fetch_one( $obj_template{$obj}, $obj_id{ $obj_template{$obj} }, $properties{ $obj_id{ $obj_template{$obj} } } );
		    $properties{$property} = $t{'name'};
		}
		my @templates = StorProc->fetch_list( $table, 'name' );
		$form .=
		  Forms->list_box( 'Use:', $property, \@templates, $properties{'template'}, $required{$property}, $docs{$property}, '',
		    $tab++ );
	    }
	    elsif ( $props{$property} =~ /^command_line/ ) {
		$form .=
		  Forms->text_area( $p_title, $property, $properties{$property}, '', $textsize{$property}, $required{$property},
		    $docs{$property}, '', $tab++ );
	    }
	    elsif ( $props{$property} eq 'notes' ) {
		my $notes = $properties{$property};
		$notes =~ s/<br>/\n/ig if defined $notes;
		my $lines = ( ( () = split( /\n/, ( defined($notes) ? $notes : '' ), 20 ) ) || 1 ) + 1;
		$form .= Forms->text_area( $p_title, $property, $notes, $lines, '74%', '', $docs{$property}, '', $tab++ );
	    }
	    elsif ( $props{$property} eq 'custom_object_variables' ) {
		my $root_template      = undef;
		my %template_variables = ();
		my %object_variables   = ();
		my @parent_vars        = ();
		if ( $obj eq 'host_templates' or $obj eq 'contact_templates' ) {
		    $root_template = 1;    # host template and contact template chains are not currently supported
		    %object_variables = map { $_ => $properties{$_} } grep( /^_/, keys %properties );
		}
		else {
		    ## FIX MAJOR:  handle whatever other $obj values we might encounter here (related to services and their templates)

		    # FIX MAJOR:  make sure $root_template really reflects whether this is a root template, not just any template
		    $root_template = ( $obj =~ /template/ );

		    # FIX MAJOR:  These values are just for initial testing; instead, pull variables and
		    # values from the appropriate sources (individual object and its ancestor templates).
		    # Follow the template chain upward, pushing onto @parent_vars at each step.
		    %template_variables = ( '_foo' => 'null', '_bar' => 'foo', '_abc' => 'def', '_def' => 'xyz' );
		    %object_variables = (
			'_abc'     => 'MY OBJECT DEFINITION',
			'_obj_foo' => 'obj_bar',
			'_obj_bar' => 'obj_foo',
			'_obj_abc' => 'obj_def',
			'_obj_def' => 'null'
		    );

		    # FIX MAJOR NOW:  derive actual values, something like this:
		    # my %template_variables = map { $_ => $template{$_}        } grep( /^_/, keys %template );
		    # my %object_variables   = map { $_ => $overrides_saved{$_} } grep( /^_/, keys %overrides_saved );
		    my %parent_vars = (
			menu => 'contacts',                 # FIX MAJOR NOW:  adapt to the particular object type being presented
			view => 'manage',                   # FIX MAJOR NOW:  adapt to the particular object type being presented
			type => 'contact_templates',        # FIX MAJOR NOW:  adapt to the particular object type being presented
			name => 'contact-template-name',    # FIX MAJOR NOW:  adapt to the particular object name being presented
			vars => \%template_variables,
		    );
		    push @parent_vars, \%parent_vars;
		}

		my ( $template_names, $template_urls, $template_vars ) = Forms->resolve_template_variables( $session_id, \@parent_vars );

		$form .=
		  Forms->custom_variables( $template_names, $template_urls, $template_vars, \%object_variables, $root_template,
		    $docs{$property}, $tab );
		$tab += 10;
	    }
	    elsif ( $props{$property} ) {
		unless ( $property eq 'name' ) {
		    if ( defined( $properties{'last_notification'} ) && $properties{'last_notification'} eq '-zero-' ) {
			$properties{'last_notification'} = 0;
		    }
		    $form .=
		      Forms->text_box( $p_title, $property, $properties{$property}, $textsize{$property}, $required{$property},
			$docs{$property}, '', $tab++ );
		}
	    }
	}
    }
    if ( $obj eq 'service_templates' ) {
	$form .= $dfv_profile;
	$form .= &$Instrument::show_trace_as_html_comment();
	return $form;
    }
    else {
	$form .= Forms->hidden( \%hidden );
	my $auth = $obj;
	if ( $auth =~ /escalation_templates/ ) {
	    $auth = 'escalations';
	    my $validation_mini_profile = {
		notification_interval => {
		    constraint => '[0-9]+',
		    message    => 'Value must be numeric.'
		},
		first_notification => {
		    constraint => '[0-9]+',
		    message    => 'Value must be numeric.'
		},
		last_notification => {
		    constraint => '[0-9]+',
		    message    => 'Value must be numeric.'
		},
	    };
	    $dfv_profile = Validation->dfv_profile_javascript($validation_mini_profile);
	}
	if ( defined($task) && $task eq 'modify' && $auth_delete{$auth} ) {
	    if ($help_url) {
		$help{url} = $help_url;
		$form .= Forms->form_bottom_buttons( \%save, \%delete, \%rename, \%cancel, \%help, $tab++ );
	    }
	    else {
		$form .= Forms->form_bottom_buttons( \%save, \%delete, \%rename, \%cancel, $tab++ );
	    }
	}
	elsif ( defined($task) && $task eq 'modify' ) {
	    $form .= Forms->form_bottom_buttons( \%save, \%rename, \%cancel, $tab++ );
	}
	else {
	    if ($help_url) {
		$help{url} = $help_url;
		$form .= Forms->form_bottom_buttons( \%add, \%cancel, \%help, $tab++ );
	    }
	    else {
		$form .= Forms->form_bottom_buttons( \%add, \%cancel, $tab++ );
	    }
	}
	my $errstr = @errors ? (Forms->form_errors( \@errors ) . "\n") : '';
	$dfv_profile .= &$Instrument::show_trace_as_html_comment();
	return $dfv_profile . $form_top . "\n" . $errstr . $form;
    }
}

sub build_host_template($) {
    my $name = shift;
    local $_;

    my $form       = undef;
    my $select_all = undef;
    $hidden{'host_id'} = $query->param('host_id');
    my $host_template           = $query->param('template');
    my $command_line            = undef;
    my $check_command           = undef;
    my $check_period            = undef;
    my $event_handler           = undef;
    my $notification_period     = undef;
    my $raw_check_command       = undef;
    my $raw_check_period        = undef;
    my $raw_event_handler       = undef;
    my $raw_notification_period = undef;
    my %host                    = ();
    my %overrides_saved         = ();
    my @override_contactgroup   = ();
    my $hosttemplate_id         = undef;

    # FIX MINOR:  @override_contactgroup is completely ignored; @override_contactgroups is used later instead
    if ( defined($obj) && $obj eq 'hosts' ) {
	%host            = StorProc->fetch_one( 'hosts',          'name',    $name );
	%overrides_saved = StorProc->fetch_one( 'host_overrides', 'host_id', $host{'host_id'} );

	my %where = ( 'host_id' => $host{'host_id'} );
	@override_contactgroup = StorProc->fetch_list_where( 'contactgroup_host', 'contactgroup_id', \%where );

	$hosttemplate_id = $host{'hosttemplate_id'};
    }
    else {
	%host = StorProc->fetch_one( 'profiles_host', 'name', $name );
	push @errors, delete $host{'error'} if defined $host{'error'};
	%overrides_saved = StorProc->fetch_one( 'hostprofile_overrides', 'hostprofile_id', $host{'hostprofile_id'} );
	push @errors, delete $overrides_saved{'error'} if defined $overrides_saved{'error'};
	my %where = ( 'hostprofile_id' => $host{'hostprofile_id'} );
	@override_contactgroup = StorProc->fetch_list_where( 'contactgroup_host_profile', 'contactgroup_id', \%where );
	$hosttemplate_id = $host{'host_template_id'};
    }
    my %override = ();
    my %template = ();
    if ($host_template) {
	%template = StorProc->fetch_one( 'host_templates', 'name', $host_template );
	$hosttemplate_id = $template{'hosttemplate_id'};
    }
    else {
	%template = StorProc->fetch_one( 'host_templates', 'hosttemplate_id', $hosttemplate_id );
	$host_template = $template{'name'};
    }
    my %raw_template = %template;

    my %cp = StorProc->fetch_one( 'time_periods', 'timeperiod_id', $template{'check_period'} );
    $raw_check_period = $cp{'name'};
    if ( $overrides_saved{'check_period'} ) {
	my %cp = StorProc->fetch_one( 'time_periods', 'timeperiod_id', $overrides_saved{'check_period'} );
	$check_period = $cp{'name'};
    }
    else {
	$check_period = $raw_check_period;
    }

    my %np = StorProc->fetch_one( 'time_periods', 'timeperiod_id', $template{'notification_period'} );
    $raw_notification_period = $np{'name'};
    if ( $overrides_saved{'notification_period'} ) {
	my %np = StorProc->fetch_one( 'time_periods', 'timeperiod_id', $overrides_saved{'notification_period'} );
	$notification_period = $np{'name'};
    }
    else {
	$notification_period = $raw_notification_period;
    }

    my %check = StorProc->fetch_one( 'commands', 'command_id', $template{'check_command'} );
    $raw_check_command = $check{'name'};
    if ( $overrides_saved{'check_command'} ) {
	my %check = StorProc->fetch_one( 'commands', 'command_id', $overrides_saved{'check_command'} );
	$check_command = $check{'name'};
    }
    else {
	$check_command = $raw_check_command;
    }

    my %event = StorProc->fetch_one( 'commands', 'command_id', $template{'event_handler'} );
    $raw_event_handler = $event{'name'};
    if ( $overrides_saved{'event_handler'} ) {
	my %event = StorProc->fetch_one( 'commands', 'command_id', $overrides_saved{'event_handler'} );
	$event_handler = $event{'name'};
    }
    else {
	$event_handler = $raw_event_handler;
    }

    my @template_contactgroups = ();
    my @override_contactgroups = ();
    unless ( $nagios_ver eq '1.x' ) {
	## FIX MINOR:  Why is check_period called out specially here, with no parallel code for notification_period?
	## Does it even make sense to handle the check_period here?
	my %cp = StorProc->fetch_one( 'time_periods', 'timeperiod_id', $template{'check_period'} );
	$template{'check_period'} = $cp{'name'};
	my %where = ( 'hosttemplate_id' => $template{'hosttemplate_id'} );
	my @raw_template_contactgroups = StorProc->fetch_list_where( 'contactgroup_host_template', 'contactgroup_id', \%where );
	$override{'contactgroups'} = 'checked';
	foreach (@raw_template_contactgroups) {
	    my %cg = StorProc->fetch_one( 'contactgroups', 'contactgroup_id', $_ );
	    push @template_contactgroups, $cg{'name'};
	}
	## FIX MINOR:  most of this nearly duplicates code just above
	if ( defined($obj) && $obj eq 'hosts' ) {
	    %where = ( 'host_id' => $host{'host_id'} );
	    @override_contactgroups = StorProc->fetch_list_where( 'contactgroup_host', 'contactgroup_id', \%where );
	}
	else {
	    %where = ( 'hostprofile_id' => $host{'hostprofile_id'} );
	    @override_contactgroups = StorProc->fetch_list_where( 'contactgroup_host_profile', 'contactgroup_id', \%where );
	}
    }
    my @contactgroups = @template_contactgroups;

    my @props = split( /,/, $property_list{'host_templates'} );
    foreach (@props) {
	$override{$_} = 'checked';
    }

    if ( $query->param('select_all') ) {
	$select_all = 1;
    }
    else {
	foreach (@props) {
	    if ( $overrides_saved{$_} ) {
		$override{$_} = 'unchecked';
		if ( $_ eq 'notification_period' ) {
		    my %np = StorProc->fetch_one( 'time_periods', 'timeperiod_id', $overrides_saved{'notification_period'} );
		    $template{$_} = $np{'name'};
		}
		elsif ( $_ eq 'check_period' ) {
		    my %cp = StorProc->fetch_one( 'time_periods', 'timeperiod_id', $overrides_saved{'check_period'} );
		    $template{$_} = $cp{'name'};
		}
		elsif ( $_ eq 'check_command' ) {
		    my %check = StorProc->fetch_one( 'commands', 'command_id', $overrides_saved{'check_command'} );
		    $template{$_} = $check{'name'};
		}
		elsif ( $_ eq 'event_handler' ) {
		    my %event = StorProc->fetch_one( 'commands', 'command_id', $overrides_saved{'event_handler'} );
		    $template{$_} = $event{'name'};
		}
		else {
		    $template{$_} = $overrides_saved{$_};
		}
	    }
	}
	unless ( $nagios_ver eq '1.x' ) {
	    if (@override_contactgroups) {
		@contactgroups = ();
		$override{'contactgroups'} = 'unchecked';
		foreach (@override_contactgroups) {
		    my %cg = StorProc->fetch_one( 'contactgroups', 'contactgroup_id', $_ );
		    push @contactgroups, $cg{'name'};
		}
	    }
	}
    }
    my @timeperiods = StorProc->fetch_list( 'time_periods',   'name' );
    my @members     = StorProc->fetch_list( 'host_templates', 'name' );
    my %docs        = Doc->manage_hosts_vitals();
    my $docs_host_template = $docs{'host_template'};

    %docs = Doc->properties_doc( 'host_templates', \@props );
    $form .= Forms->wizard_doc( 'Host Template', undef, undef, 1 );
    $form .= Forms->list_box_submit( 'Host template:', 'template', \@members, $host_template, $required{'template'}, $docs_host_template, $tab++ );
    $form .= Forms->inheritance( '', $docs{'override'}, \%template );

    if ( $nagios_ver eq '1.x' ) {
	## checks_enabled
	$form .= Forms->checkbox(
	    'Checks enabled:',
	    'checks_enabled', $template{'checks_enabled'},
	    $docs{'checks_enabled'}, $override{'checks_enabled'},
	    $tab++, undef, defined( $raw_template{'checks_enabled'} ) ? $raw_template{'checks_enabled'} : ''
	);
    }
    else {
	## active_checks_enabled
	$form .= Forms->checkbox(
	    'Active checks enabled:',
	    'active_checks_enabled',
	    $template{'active_checks_enabled'},
	    $docs{'active_checks_enabled'},
	    $override{'active_checks_enabled'},
	    $tab++,
	    undef,
	    defined( $raw_template{'active_checks_enabled'} ) ? $raw_template{'active_checks_enabled'} : ''
	);
	$form .= Forms->checkbox(
	    'Passive checks enabled:',
	    'passive_checks_enabled',
	    $template{'passive_checks_enabled'},
	    $docs{'passive_checks_enabled'},
	    $override{'passive_checks_enabled'},
	    $tab++,
	    undef,
	    defined( $raw_template{'passive_checks_enabled'} ) ? $raw_template{'passive_checks_enabled'} : ''
	);
    }

    # check_command
    # command_line
    my @commands = StorProc->fetch_list( 'commands', 'name' );
    $form .= Forms->list_box(
	'Check command:',
	'check_command', \@commands, $check_command, '', $docs{'check_command'}, $override{'check_command'},
	$tab++, undef, defined($raw_check_command) ? $raw_check_command : ''
    );

    # FIX MINOR:  GWMON-8146:  add the "Command line" field here?  Why was this code present but commented out?
    # $form .= Forms->text_area('Command line:', 'command_line', $template{'command_line'}, '',
    #     $textsize{'command_line'}, '', $docs{'command_line'}, $override{'command_line'});

    if ( $nagios_ver eq '3.x' ) {
	# check_period
	$form .= Forms->list_box(
	    'Check period:',
	    'check_period', \@timeperiods, $check_period, '',
	    $docs{'check_period'},
	    $override{'check_period'},
	    $tab++, undef, defined($raw_check_period) ? $raw_check_period : ''
	);
    }

    if ( $nagios_ver =~ /^[23]\.x$/ ) {
	## check_interval
	$template{'check_interval'}     =~ s/-zero-/0/ if defined $template{'check_interval'};
	$raw_template{'check_interval'} =~ s/-zero-/0/ if defined $raw_template{'check_interval'};
	$form .= Forms->text_box(
	    'Check interval:',           'check_interval',
	    $template{'check_interval'}, $textsize{'check_interval'},
	    $required{'check_interval'}, $docs{'check_interval'},
	    $override{'check_interval'}, $tab++,
	    undef,                       defined( $raw_template{'check_interval'} ) ? $raw_template{'check_interval'} : ''
	);
    }

    if ( $nagios_ver eq '3.x' ) {
	## retry_interval
	$template{'retry_interval'}     =~ s/-zero-/0/ if defined $template{'retry_interval'};
	$raw_template{'retry_interval'} =~ s/-zero-/0/ if defined $raw_template{'retry_interval'};
	$form .= Forms->text_box(
	    'Retry interval:',           'retry_interval',
	    $template{'retry_interval'}, $textsize{'retry_interval'},
	    $required{'retry_interval'}, $docs{'retry_interval'},
	    $override{'retry_interval'}, $tab++,
	    undef,                       defined( $raw_template{'retry_interval'} ) ? $raw_template{'retry_interval'} : ''
	);
    }

    # max_check_attempts
    $form .= Forms->text_box(
	'Max check attempts:',           'max_check_attempts',
	$template{'max_check_attempts'}, $textsize{'max_check_attempts'},
	$required{'max_check_attempts'}, $docs{'max_check_attempts'},
	$override{'max_check_attempts'}, $tab++,
	undef,                           defined( $raw_template{'max_check_attempts'} ) ? $raw_template{'max_check_attempts'} : ''
    );

    if ( $nagios_ver =~ /^[23]\.x$/ ) {

	# check_freshness
	$form .= Forms->checkbox(
	    'Check freshness:',
	    'check_freshness',
	    $template{'check_freshness'},
	    $docs{'check_freshness'},
	    $override{'check_freshness'},
	    $tab++, undef, defined( $raw_template{'check_freshness'} ) ? $raw_template{'check_freshness'} : ''
	);

	# freshness_threshold
	$template{'freshness_threshold'}     =~ s/-zero-/0/ if defined $template{'freshness_threshold'};
	$raw_template{'freshness_threshold'} =~ s/-zero-/0/ if defined $raw_template{'freshness_threshold'};
	$form .= Forms->text_box(
	    'Freshness threshold:',           'freshness_threshold',
	    $template{'freshness_threshold'}, $textsize{'freshness_threshold'},
	    $required{'freshness_threshold'}, $docs{'freshness_threshold'},
	    $override{'freshness_threshold'}, $tab++,
	    undef,                            defined( $raw_template{'freshness_threshold'} ) ? $raw_template{'freshness_threshold'} : ''
	);

	# obsess_over_host
	$form .= Forms->checkbox(
	    'Obsess over host:',
	    'obsess_over_host',
	    $template{'obsess_over_host'},
	    $docs{'obsess_over_host'},
	    $override{'obsess_over_host'},
	    $tab++, undef, defined( $raw_template{'obsess_over_host'} ) ? $raw_template{'obsess_over_host'} : ''
	);
    }

    # flap_detection_enabled
    $form .= Forms->checkbox(
	'Flap detection enabled:',
	'flap_detection_enabled',
	$template{'flap_detection_enabled'},
	$docs{'flap_detection_enabled'},
	$override{'flap_detection_enabled'},
	$tab++,
	undef,
	defined( $raw_template{'flap_detection_enabled'} ) ? $raw_template{'flap_detection_enabled'} : ''
    );

    # low_flap_threshold
    $template{'low_flap_threshold'}     =~ s/-zero-/0/ if defined $template{'low_flap_threshold'};
    $raw_template{'low_flap_threshold'} =~ s/-zero-/0/ if defined $raw_template{'low_flap_threshold'};
    $form .= Forms->text_box(
	'Low flap threshold:',           'low_flap_threshold',
	$template{'low_flap_threshold'}, $textsize{'low_flap_threshold'},
	$required{'low_flap_threshold'}, $docs{'low_flap_threshold'},
	$override{'low_flap_threshold'}, $tab++,
	undef,                           defined( $raw_template{'low_flap_threshold'} ) ? $raw_template{'low_flap_threshold'} : ''
    );

    # high_flap_threshold
    $template{'high_flap_threshold'}     =~ s/-zero-/0/ if defined $template{'high_flap_threshold'};
    $raw_template{'high_flap_threshold'} =~ s/-zero-/0/ if defined $raw_template{'high_flap_threshold'};
    $form .= Forms->text_box(
	'High flap threshold:',           'high_flap_threshold',
	$template{'high_flap_threshold'}, $textsize{'high_flap_threshold'},
	$required{'high_flap_threshold'}, $docs{'high_flap_threshold'},
	$override{'high_flap_threshold'}, $tab++,
	undef,                            defined( $raw_template{'high_flap_threshold'} ) ? $raw_template{'high_flap_threshold'} : ''
    );

    # event_handler_enabled
    $form .= Forms->checkbox(
	'Event handler enabled:',
	'event_handler_enabled',
	$template{'event_handler_enabled'},
	$docs{'event_handler_enabled'},
	$override{'event_handler_enabled'},
	$tab++, undef, defined( $raw_template{'event_handler_enabled'} ) ? $raw_template{'event_handler_enabled'} : ''
    );

    # event_handler
    $form .= Forms->list_box(
	'Event handler:',
	'event_handler', \@commands, $event_handler, '', $docs{'event_handler'}, $override{'event_handler'},
	$tab++, undef, defined($raw_event_handler) ? $raw_event_handler : ''
    );

    # stalking_options
    my @opts     = split( /,/, ( defined( $template{'stalking_options'} )     ? $template{'stalking_options'}     : '' ) );
    my @raw_opts = split( /,/, ( defined( $raw_template{'stalking_options'} ) ? $raw_template{'stalking_options'} : '' ) );
    $form .= Forms->stalking_options(
	'host_templates', \@opts,
	$required{'stalking_options'},
	$docs{'stalking_options'},
	$override{'stalking_options'},
	$tab++, undef, \@raw_opts
    );

    # process_perf_data
    $form .= Forms->checkbox(
	'Process performance data:',
	'process_perf_data',
	$template{'process_perf_data'},
	$docs{'process_perf_data'},
	$override{'process_perf_data'},
	$tab++, undef, defined( $raw_template{'process_perf_data'} ) ? $raw_template{'process_perf_data'} : ''
    );

    # notifications_enabled
    $form .= Forms->checkbox(
	'Notifications enabled:',
	'notifications_enabled',
	$template{'notifications_enabled'},
	$docs{'notifications_enabled'},
	$override{'notifications_enabled'},
	$tab++, undef, defined( $raw_template{'notifications_enabled'} ) ? $raw_template{'notifications_enabled'} : ''
    );

    # notification_options
    @opts     = split( /,/, ( defined( $template{'notification_options'} )     ? $template{'notification_options'}     : '' ) );
    @raw_opts = split( /,/, ( defined( $raw_template{'notification_options'} ) ? $raw_template{'notification_options'} : '' ) );
    $form .= Forms->notification_options(
	'host_templates', 'notification_options', \@opts, $required{'notification_options'},
	$nagios_ver,
	$docs{'notification_options'},
	$override{'notification_options'},
	$tab++, undef, \@raw_opts
    );

    # notification_period
    $form .= Forms->list_box(
	'Notification period:',
	'notification_period', \@timeperiods, $notification_period, '',
	$docs{'notification_period'},
	$override{'notification_period'},
	$tab++, undef, defined($raw_notification_period) ? $raw_notification_period : ''
    );

    # notification_interval
    $template{'notification_interval'}     =~ s/-zero-/0/ if defined $template{'notification_interval'};
    $raw_template{'notification_interval'} =~ s/-zero-/0/ if defined $raw_template{'notification_interval'};
    $form .= Forms->text_box(
	'Notification interval:',           'notification_interval',
	$template{'notification_interval'}, $textsize{'notification_interval'},
	$required{'notification_interval'}, $docs{'notification_interval'},
	$override{'notification_interval'}, $tab++,
	undef,                              defined( $raw_template{'notification_interval'} ) ? $raw_template{'notification_interval'} : ''
    );

    unless ( $nagios_ver eq '1.x' ) {
	## contactgroups
	my @nonmembers = StorProc->fetch_list( 'contactgroups', 'name' );
	$form .= Forms->members(
	    'Contact groups:',
	    'contactgroup', \@contactgroups, \@nonmembers, '', '10', $docs{'contactgroup'}, $override{'contactgroups'},
	    $tab++, undef, \@template_contactgroups, \@nonmembers
	);
    }

    # retain_status_information
    $form .= Forms->checkbox(
	'Retain status information:',
	'retain_status_information',
	$template{'retain_status_information'},
	$docs{'retain_status_information'},
	$override{'retain_status_information'},
	$tab++,
	undef,
	defined( $raw_template{'retain_status_information'} ) ? $raw_template{'retain_status_information'} : ''
    );

    # retain_nonstatus_information
    $form .= Forms->checkbox(
	'Retain nonstatus information:',
	'retain_nonstatus_information',
	$template{'retain_nonstatus_information'},
	$docs{'retain_nonstatus_information'},
	$override{'retain_nonstatus_information'},
	$tab++,
	undef,
	defined( $raw_template{'retain_nonstatus_information'} ) ? $raw_template{'retain_nonstatus_information'} : ''
    );

    # FIX MAJOR:  If the screen got refreshed because of a change of template, use the equivalent of %overrides_saved
    # from the query parameters rather than from the database, so as not to lose any changes made by the user, though
    # we will then need to filter out the variables which were from the previous template.  Also use the query values
    # if the screen got refreshed because "Set Inheritance" was clicked or because required fields were missing during
    # a contact Add operation.
    my %template_variables = map { $_ => $template{$_}        } grep( /^_/, keys %template );
    my %object_variables   = map { $_ => $overrides_saved{$_} } grep( /^_/, keys %overrides_saved );
    my %parent_vars = (
	menu => 'hosts',
	view => 'manage',
	type => 'host_templates',
	name => $template{'name'},
	vars => \%template_variables,
    );
    my ($template_names, $template_urls, $template_vars) = Forms->resolve_template_variables( $session_id, [ \%parent_vars ] );

    my $root_template = 0;
    $form .= Forms->custom_variables( $template_names, $template_urls, $template_vars, \%object_variables,
      $root_template, $docs{'custom_object_variables'}, $tab );
    $tab += 10;

    return $form;
}

sub build_service_detail($) {
    my $service_id = shift;
    local $_;

    my $form                  = undef;
    my $select_all            = undef;
    my $service_template      = $query->param('template');
    my %service               = ();
    my %overrides_saved       = ();
    my @override_contactgroup = ();
    my $servicetemplate_id    = undef;
    if ( $obj eq 'hosts' ) {
	unless ($service_id) { $service_id = $query->param('service_id') }
	%service         = StorProc->fetch_one( 'services',          'service_id', $service_id );
	%overrides_saved = StorProc->fetch_one( 'service_overrides', 'service_id', $service_id );
	$servicetemplate_id = $service{'servicetemplate_id'};
	my %where = ( 'service_id' => $service{'service_id'} );
	@override_contactgroup = StorProc->fetch_list_where( 'contactgroup_service', 'contactgroup_id', \%where );
    }
    elsif ( $obj eq 'services' ) {
	unless ($service_id) { $service_id = $query->param('servicename_id') }
	%service         = StorProc->fetch_one( 'service_names',         'servicename_id', $service_id );
	%overrides_saved = StorProc->fetch_one( 'servicename_overrides', 'servicename_id', $service_id );
	$servicetemplate_id = $service{'template'};
	my %where = ( 'servicename_id' => $service{'servicename_id'} );
	@override_contactgroup = StorProc->fetch_list_where( 'contactgroup_service_name', 'contactgroup_id', \%where );
    }
    elsif ( $obj eq 'service_templates' ) {
	foreach my $prop ( keys %properties ) {
	    if ( $prop =~ /parent_id/ ) {
		$servicetemplate_id = $properties{$prop};
	    }
	    else {
		$overrides_saved{$prop} = $properties{$prop};
	    }
	}
	my %where = ( 'servicetemplate_id' => $properties{'servicetemplate_id'} );
	@override_contactgroup = StorProc->fetch_list_where( 'contactgroup_service_template', 'contactgroup_id', \%where );
    }
    my %override = ();
    my %template = ();
    if ($service_template) {
	my %t = StorProc->fetch_one( 'service_templates', 'name', $service_template );
	$servicetemplate_id = $t{'servicetemplate_id'};
    }
    else {
	my %t = StorProc->fetch_one( 'service_templates', 'servicetemplate_id', $servicetemplate_id );
	$service_template = $t{'name'};
    }
    my @raw_template_contactgroups = ();
    my $got_contactgroup           = 0;
    my $got_parent                 = 0;
    my %already_seen               = ();
    until ($got_parent) {
	my %tpl = StorProc->fetch_one( 'service_templates', 'servicetemplate_id', $servicetemplate_id );
	my @props = split( /,/, $property_list{'service_templates'} );
	foreach my $t (@props) {
	    unless ( $template{$t} ) {
		if ( $t eq 'check_command' ) {
		    my %c = defined( $tpl{'check_command'} ) ? StorProc->fetch_one( 'commands', 'command_id', $tpl{'check_command'} ) : ();
		    $template{$t} = $c{'name'};
		}
		elsif ( $t eq 'notification_period' ) {
		    my %np = defined( $tpl{'notification_period'} ) ? StorProc->fetch_one( 'time_periods', 'timeperiod_id', $tpl{'notification_period'} ) : ();
		    $template{$t} = $np{'name'};
		}
		elsif ( $t eq 'check_period' ) {
		    my %cp = defined( $tpl{'check_period'} ) ? StorProc->fetch_one( 'time_periods', 'timeperiod_id', $tpl{'check_period'} ) : ();
		    $template{$t} = $cp{'name'};
		}
		elsif ( $t eq 'event_handler' ) {
		    my %e = defined( $tpl{'event_handler'} ) ? StorProc->fetch_one( 'commands', 'command_id', $tpl{'event_handler'} ) : ();
		    $template{$t} = $e{'name'};
		}
		else {
		    $template{$t} = $tpl{$t};
		}
	    }
	}

	# FIX MINOR:  Unlike StorProc->get_template_properties(), we stop accumulating
	# contactgroups here after the first assignment.  Why the different approach?
	unless ($got_contactgroup) {
	    my %where = ( 'servicetemplate_id' => $tpl{'servicetemplate_id'} );
	    @raw_template_contactgroups = StorProc->fetch_list_where( 'contactgroup_service_template', 'contactgroup_id', \%where );
	    if (@raw_template_contactgroups) { $got_contactgroup = 1 }
	}
	$already_seen{$servicetemplate_id} = 1;
	$got_parent = 1;
	if ( $tpl{'parent_id'} && !$already_seen{ $tpl{'parent_id'} } ) {
	    $servicetemplate_id = $tpl{'parent_id'};
	    $got_parent         = 0;
	}
    }

    my @props = split( /,/, $property_list{'service_templates'} );
    foreach (@props) {
	$override{$_}   = 'checked';
	$properties{$_} = $template{$_};
    }
    my @template_contactgroups = ();
    $override{'contactgroups'} = 'checked';
    foreach (@raw_template_contactgroups) {
	my %cg = StorProc->fetch_one( 'contactgroups', 'contactgroup_id', $_ );
	push @template_contactgroups, $cg{'name'};
    }
    my @contactgroups = @template_contactgroups;
    if ( $query->param('select_all') ) {
	$select_all = 1;
    }
    else {
	foreach (@props) {
	    if ( $overrides_saved{$_} ) {
		$override{$_} = 'unchecked';
		if ( $_ eq 'check_command' ) {
		    my %c = StorProc->fetch_one( 'commands', 'command_id', $overrides_saved{'check_command'} );
		    $properties{$_} = $c{'name'};
		}
		elsif ( $_ eq 'notification_period' ) {
		    my %np = StorProc->fetch_one( 'time_periods', 'timeperiod_id', $overrides_saved{'notification_period'} );
		    $properties{$_} = $np{'name'};
		}
		elsif ( $_ eq 'check_period' ) {
		    my %cp = StorProc->fetch_one( 'time_periods', 'timeperiod_id', $overrides_saved{'check_period'} );
		    $properties{$_} = $cp{'name'};
		}
		elsif ( $_ eq 'event_handler' ) {
		    my %e = StorProc->fetch_one( 'commands', 'command_id', $overrides_saved{'event_handler'} );
		    $properties{$_} = $e{'name'};
		}
		else {
		    $properties{$_} = $overrides_saved{$_};
		}
	    }
	}
	if (@override_contactgroup) {
	    @contactgroups = ();
	    $override{'contactgroups'} = 'unchecked';
	    foreach (@override_contactgroup) {
		my %cg = StorProc->fetch_one( 'contactgroups', 'contactgroup_id', $_ );
		push @contactgroups, $cg{'name'};
	    }
	}
    }

    my %docs = Doc->properties_doc( 'service_templates', \@props, $view );
    $form .= Forms->wizard_doc( 'Service Template', undef, undef, 1 );

    my @members = ();
    if ( $obj eq 'service_templates' ) {
	push @members, '-- no base template --';
	my @mems = StorProc->get_possible_parents( $properties{'servicetemplate_id'} );
	push( @members, (@mems) );
    }
    else {
	@members = StorProc->fetch_list( 'service_templates', 'name' );
    }
    # FIX LATER:  change label to 'Parent service template:', at least when ( $obj eq 'service_templates' ) ?
    $form .= Forms->list_box_submit( 'Service template:', 'template', \@members, $service_template, '', $docs{'template'}, $tab++ );

    $form .= Forms->inheritance( '', $docs{'override'}, \%template );

    # active_checks_enabled
    $form .= Forms->checkbox(
	'Active checks enabled:',
	'active_checks_enabled',
	$properties{'active_checks_enabled'},
	$docs{'active_checks_enabled'},
	$override{'active_checks_enabled'},
	$tab++, undef, defined( $template{'active_checks_enabled'} ) ? $template{'active_checks_enabled'} : ''
    );

    # passive_checks_enabled
    $form .= Forms->checkbox(
	'Passive checks enabled:',
	'passive_checks_enabled',
	$properties{'passive_checks_enabled'},
	$docs{'passive_checks_enabled'},
	$override{'passive_checks_enabled'},
	$tab++, undef, defined( $template{'passive_checks_enabled'} ) ? $template{'passive_checks_enabled'} : ''
    );

    # check_period
    my @timeperiods = StorProc->fetch_list( 'time_periods', 'name' );
    $form .= Forms->list_box(
	'Check period:',
	'check_period', \@timeperiods, $properties{'check_period'},
	'', $docs{'check_period'}, $override{'check_period'},
	$tab++, undef, defined( $template{'check_period'} ) ? $template{'check_period'} : ''
    );

    # normal_check_interval
    $properties{'normal_check_interval'} =~ s/-zero-/0/;
    $form .= Forms->text_box(
	'Normal check interval:',             'normal_check_interval',
	$properties{'normal_check_interval'}, $textsize{'normal_check_interval'},
	$required{'normal_check_interval'},   $docs{'normal_check_interval'},
	$override{'normal_check_interval'},   $tab++,
	undef,                                defined( $template{'normal_check_interval'} ) ? $template{'normal_check_interval'} : ''
    );

    # retry_check_interval
    $properties{'retry_check_interval'} =~ s/-zero-/0/;
    $form .= Forms->text_box(
	'Retry check interval:',             'retry_check_interval',
	$properties{'retry_check_interval'}, $textsize{'retry_check_interval'},
	$required{'retry_check_interval'},   $docs{'retry_check_interval'},
	$override{'retry_check_interval'},   $tab++,
	undef,                               defined( $template{'retry_check_interval'} ) ? $template{'retry_check_interval'} : ''
    );

    # max_check_attempts
    $form .= Forms->text_box(
	'Max check attempts:',             'max_check_attempts',
	$properties{'max_check_attempts'}, $textsize{'max_check_attempts'},
	$required{'max_check_attempts'},   $docs{'max_check_attempts'},
	$override{'max_check_attempts'},   $tab++,
	undef,                             defined( $template{'max_check_attempts'} ) ? $template{'max_check_attempts'} : ''
    );

    if ( $nagios_ver =~ /^[12]\.x$/ ) {
	## parallelize_check
	$form .= Forms->checkbox(
	    'Parallelize check:',
	    'parallelize_check',
	    $properties{'parallelize_check'},
	    $docs{'parallelize_check'},
	    $override{'parallelize_check'},
	    $tab++, undef, defined( $template{'parallelize_check'} ) ? $template{'parallelize_check'} : ''
	);
    }

    # check_freshness
    $form .= Forms->checkbox(
	'Check freshness:',
	'check_freshness',
	$properties{'check_freshness'},
	$docs{'check_freshness'},
	$override{'check_freshness'},
	$tab++, undef, defined( $template{'check_freshness'} ) ? $template{'check_freshness'} : ''
    );

    # freshness_threshold
    $properties{'freshness_threshold'} =~ s/-zero-/0/ if defined $properties{'freshness_threshold'};
    $form .= Forms->text_box(
	'Freshness threshold:',             'freshness_threshold',
	$properties{'freshness_threshold'}, $textsize{'freshness_threshold'},
	$required{'freshness_threshold'},   $docs{'freshness_threshold'},
	$override{'freshness_threshold'},   $tab++,
	undef,                              defined( $template{'freshness_threshold'} ) ? $template{'freshness_threshold'} : ''
    );

    # obsess_over_service
    $form .= Forms->checkbox(
	'Obsess over service:',
	'obsess_over_service',
	$properties{'obsess_over_service'},
	$docs{'obsess_over_service'},
	$override{'obsess_over_service'},
	$tab++, undef, defined( $template{'obsess_over_service'} ) ? $template{'obsess_over_service'} : ''
    );

    # flap_detection_enabled
    $form .= Forms->checkbox(
	'Flap detection enabled:',
	'flap_detection_enabled',
	$properties{'flap_detection_enabled'},
	$docs{'flap_detection_enabled'},
	$override{'flap_detection_enabled'},
	$tab++, undef, defined( $template{'flap_detection_enabled'} ) ? $template{'flap_detection_enabled'} : ''
    );

    # low_flap_threshold
    $properties{'low_flap_threshold'} =~ s/-zero-/0/ if defined $properties{'low_flap_threshold'};
    $form .= Forms->text_box(
	'Low flap threshold:',             'low_flap_threshold',
	$properties{'low_flap_threshold'}, $textsize{'low_flap_threshold'},
	$required{'low_flap_threshold'},   $docs{'low_flap_threshold'},
	$override{'low_flap_threshold'},   $tab++,
	undef,                             defined( $template{'low_flap_threshold'} ) ? $template{'low_flap_threshold'} : ''
    );

    # high_flap_threshold
    $properties{'high_flap_threshold'} =~ s/-zero-/0/ if defined $properties{'high_flap_threshold'};
    $form .= Forms->text_box(
	'High flap threshold:',             'high_flap_threshold',
	$properties{'high_flap_threshold'}, $textsize{'high_flap_threshold'},
	$required{'high_flap_threshold'},   $docs{'high_flap_threshold'},
	$override{'high_flap_threshold'},   $tab++,
	undef,                              defined( $template{'high_flap_threshold'} ) ? $template{'high_flap_threshold'} : ''
    );

    # event_handler_enabled
    $form .= Forms->checkbox(
	'Event handler enabled:',
	'event_handler_enabled',
	$properties{'event_handler_enabled'},
	$docs{'event_handler_enabled'},
	$override{'event_handler_enabled'},
	$tab++, undef, defined( $template{'event_handler_enabled'} ) ? $template{'event_handler_enabled'} : ''
    );

    # event_handler
    my @commands = StorProc->fetch_list( 'commands', 'name' );
    $form .= Forms->list_box(
	'Event handler:',
	'event_handler', \@commands,
	$properties{'event_handler'},
	$required{'event_handler'},
	$docs{'event_handler'}, $override{'event_handler'},
	$tab++, undef, defined( $template{'event_handler'} ) ? $template{'event_handler'} : ''
    );

    # is_volatile
    $form .= Forms->checkbox(
	'Is volatile:', 'is_volatile', $properties{'is_volatile'},
	$docs{'is_volatile'}, $override{'is_volatile'},
	$tab++, undef, defined( $template{'is_volatile'} ) ? $template{'is_volatile'} : ''
    );

    # stalking_options
    my @opts     = split( /,/, ( defined( $properties{'stalking_options'} ) ? $properties{'stalking_options'} : '' ) );
    my @raw_opts = split( /,/, ( defined( $template{'stalking_options'} )   ? $template{'stalking_options'}   : '' ) );
    $form .= Forms->stalking_options(
	'service_templates', \@opts,
	$required{'stalking_options'},
	$docs{'stalking_options'},
	$override{'stalking_options'},
	$tab++, undef, \@raw_opts
    );

    # process_perf_data
    $form .= Forms->checkbox(
	'Process perf data:',
	'process_perf_data',
	$properties{'process_perf_data'},
	$docs{'process_perf_data'},
	$override{'process_perf_data'},
	$tab++, undef, defined( $template{'process_perf_data'} ) ? $template{'process_perf_data'} : ''
    );

    # notifications_enabled
    $form .= Forms->checkbox(
	'Notifications enabled:',
	'notifications_enabled',
	$properties{'notifications_enabled'},
	$docs{'notifications_enabled'},
	$override{'notifications_enabled'},
	$tab++, undef, defined( $template{'notifications_enabled'} ) ? $template{'notifications_enabled'} : ''
    );

    # notification_options
    @opts     = split( /,/, ( defined( $properties{'notification_options'} ) ? $properties{'notification_options'} : '' ) );
    @raw_opts = split( /,/, ( defined( $template{'notification_options'} )   ? $template{'notification_options'}   : '' ) );
    $form .= Forms->notification_options(
	'service_templates', 'notification_options', \@opts, $required{'notification_options'},
	$nagios_ver,
	$docs{'notification_options'},
	$override{'notification_options'},
	$tab++, undef, \@raw_opts
    );

    # notification_period
    $form .= Forms->list_box(
	'Notification period:',
	'notification_period', \@timeperiods, $properties{'notification_period'},
	'',
	$docs{'notification_period'},
	$override{'notification_period'},
	$tab++, undef, defined( $template{'notification_period'} ) ? $template{'notification_period'} : ''
    );

    # notification_interval
    $properties{'notification_interval'} =~ s/-zero-/0/;
    $form .= Forms->text_box(
	'Notification interval:',             'notification_interval',
	$properties{'notification_interval'}, $textsize{'notification_interval'},
	$required{'notification_interval'},   $docs{'notification_interval'},
	$override{'notification_interval'},   $tab++,
	undef,                                defined( $template{'notification_interval'} ) ? $template{'notification_interval'} : ''
    );

    # contactgroups
    my @nonmembers = StorProc->fetch_list( 'contactgroups', 'name' );
    $form .= Forms->members( 'Contact Groups:',
	'contactgroup', \@contactgroups, \@nonmembers, '', '10', $docs{'contactgroup'}, $override{'contactgroups'},
	$tab++, undef, \@template_contactgroups, \@nonmembers
    );

    # retain_status_information
    $form .= Forms->checkbox(
	'Retain status information:',
	'retain_status_information',
	$properties{'retain_status_information'},
	$docs{'retain_status_information'},
	$override{'retain_status_information'},
	$tab++,
	undef,
	defined( $template{'retain_status_information'} ) ? $template{'retain_status_information'} : ''
    );

    # retain_nonstatus_information
    $form .= Forms->checkbox(
	'Retain nonstatus information:',
	'retain_nonstatus_information',
	$properties{'retain_nonstatus_information'},
	$docs{'retain_nonstatus_information'},
	$override{'retain_nonstatus_information'},
	$tab++,
	undef,
	defined( $template{'retain_nonstatus_information'} ) ? $template{'retain_nonstatus_information'} : ''
    );

    return $form;
}

#
############################################################################
# Service Template
#

sub service_template() {
    local $_;

    my $form     = '';
    my $obj_view = $query->param('obj_view');
    my $name     = $query->param('name');
    my $source   = $query->param('source');
    $name = uri_unescape($name);
    $name =~ s/^\s+|\s+$//g if defined $name;
    my $host = $query->param('host');
    my $test_results    = undef;
    my $message_applied = undef;
    %properties = defined($name) ? StorProc->fetch_one( 'service_templates', 'name', $name ) : ();
    push @errors, delete $properties{'error'} if defined $properties{'error'};

    if ( defined($task) ) {
	if ( $task eq 'new' ) {
	    $obj_view = 'new';
	}
	elsif ( $task eq 'copy' ) {
	    $obj_view = 'copy';
	}
    }

    if ( $query->param('add') ) {
	if ($name) {
	    unless ( $properties{'name'} ) {
		my $id = undef;
		if ($obj_view eq 'copy') {
		    $id = StorProc->copy_service_template( $source, $name );
		    %properties = StorProc->fetch_one( 'service_templates', 'name', $name );
		    push @errors, delete $properties{'error'} if defined $properties{'error'};
		    $task = 'modify';  # for use in build_form()
		}
		else {
		    # New service template.
		    my @values = ( \undef, $name, '', '', '', '', '', '', '', '' );
		    $id = StorProc->insert_obj_id( 'service_templates', \@values, 'servicetemplate_id' );
		}
		if ( $id =~ /^Error/ ) {
		    push @errors, $id;
		    # $obj_view = 'new';  # or 'copy' ?
		}
		else {
		    $obj_view = 'service_detail';
		    delete $hidden{'task'};
		    $properties{'servicetemplate_id'} = $id;
		    $properties{'name'}               = $name;
		}
	    }
	    else {
		push @errors, "Service template \"$name\" already exists.";
		# $obj_view = 'new';  # or 'copy' ?
		$required{'name'} = 1;
	    }
	}
	else {
	    push @errors, "Service template name required.";
	    # $obj_view = 'new';  # or 'copy' ?
	}
    }
    elsif ($query->param('close')
	|| $query->param('cancel')
	|| $query->param('continue') )
    {
	$obj_view = 'close';
    }
    elsif ( $query->param('test_command') ) {
	my $service_desc = $query->param('service_desc');
	my $arg_string   = $query->param('command_line');
	my $command      = $query->param('command');
	my %cmd          = StorProc->fetch_one( 'commands', 'name', $command );
	$test_results .= StorProc->test_command( $command, $cmd{'command_line'}, $host, $arg_string, $monarch_home, $service_desc, $nagios_ver );
    }
    elsif ( $query->param('save') ) {
	if ( $obj_view eq 'service_detail' ) {
	    my %values = ();
	    my $parent = $query->param('template');
	    my %t      = StorProc->fetch_one( 'service_templates', 'name', $parent );
	    $values{'parent_id'} = $t{'servicetemplate_id'};
	    my %data = parse_query( 'service_templates', 'service_templates' );
	    $values{'check_period'}        = $data{'check_period'};
	    $values{'event_handler'}       = $data{'event_handler'};
	    $values{'notification_period'} = $data{'notification_period'};
	    $values{'data'}                = $data{'data'};
	    my $result = StorProc->update_obj( 'service_templates', 'name', $name, \%values );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	    my %where = ( 'servicetemplate_id' => $properties{'servicetemplate_id'} );
	    $result = StorProc->delete_one_where( 'contactgroup_service_template', \%where );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	    unless ( $query->param('contactgroup_override') ) {
		my @mems = $query->$multi_param('contactgroup');
		foreach (@mems) {
		    my %cg = StorProc->fetch_one( 'contactgroups', 'name', $_ );
		    my @vals = ( $cg{'contactgroup_id'}, $properties{'servicetemplate_id'} );
		    $result = StorProc->insert_obj( 'contactgroup_service_template', \@vals );
		    if ( $result =~ /^Error/ ) { push @errors, $result }
		}
	    }
	    unless (@errors) {
		$obj_view = 'saved';
	    }
	}
	elsif ( $obj_view eq 'service_check' ) {
	    my $service_name = $query->param('service_name');
	    my $service_id   = $query->param('service_id');
	    $hidden{'service_name'} = $service_name;
	    $hidden{'service_id'}   = $service_id;
	    my $check_command = $query->param('command');
	    my $command_line  = $query->param('command_line');
	    if ( $query->param('inherit') ) {
		my %vals = ( 'check_command' => '', 'command_line' => '' );
		my $result = StorProc->update_obj( 'service_templates', 'servicetemplate_id', $properties{'servicetemplate_id'}, \%vals );
		if ( $result =~ /^Error/ ) { push @errors, $result }
	    }
	    else {
		my $result = '';
		my %check  = StorProc->fetch_one( 'commands', 'name', $check_command );
		my %data   = parse_query( 'service_templates', 'service_templates' );
		my %vals   = ( 'check_command' => $check{'command_id'} );
		$command_line =~ s/^\s+|\s+$//g;
		if ( $check{'command_id'} ) {
		    $vals{'command_line'} = $command_line;
		}
		elsif ( $command_line eq '' ) {
		    $vals{'command_line'} = '';
		}
		else {
		    $result = 'Error:  You cannot define a command line without first selecting a command.';
		}
		unless ($result) {
		    $result = StorProc->update_obj( 'service_templates', 'servicetemplate_id', $properties{'servicetemplate_id'}, \%vals );
		}
		if ( $result =~ /^Error/ ) { push @errors, $result }
	    }
	    unless (@errors) {
		$obj_view = 'saved';
		$hidden{'selected'} = 'service_check';
	    }
	}
    }
    elsif ( $query->param('rename') ) {
	if ( $query->param('new_name') ) {
	    my $new_name = $query->param('new_name');
	    $new_name =~ s/^\s+|\s+$//g;
	    my %n = StorProc->fetch_one( 'service_templates', 'name', $new_name );
	    if ( $n{'name'} ) {
		push @errors, "A service template named \"$new_name\" already exists. Please specify another name.";
	    }
	    else {
		my %values = ( 'name' => $new_name );
		my $result = StorProc->update_obj( 'service_templates', 'name', $name, \%values );
		if ( $result =~ /error/i ) {
		    push @errors, $result;
		}
		else {
		    $name         = $new_name;
		    $obj_view     = 'service_detail';
		    $refresh_left = 1;
		    $query->param('name', $name);
		}
	    }
	}
	else {
	    $obj_view = 'rename';
	}
    }
    elsif ( $query->param('delete') || $query->param('confirm_delete') ) {
	if ( $query->param('confirm_delete') ) {
	    my $result = StorProc->delete_all( 'service_templates', 'name', $name );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	    my %where = ( 'servicetemplate_id' => $properties{'servicetemplate_id'} );
	    $result = StorProc->delete_one_where( 'contactgroup_service_template', \%where );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	    ## GWMON-5188
	    ## FIX THIS:  deal also with deletions from the contactgroup_service_template table
	    ##            (may already be handled by DELETE CASCADE, but then why are we deleting
	    ##            explicitly here?  maybe there is some old copy of the database without this clause?
	    ##            are we guaranteed that any upgraded database will contain this clause?)
	    ## FIX THIS:  deal also with deletions from the contact_service_template table (may already be
	    ##            handled by DELETE CASCADE, if that table is used at all [why does a fresh install
	    ##            contain a single row, when none of the code ever references that table?])
	    ## FIX THIS:  deal also with nullification in the services table (or add an ON DELETE SET NULL constraint?)
	    ## FIX THIS:  deal also with nullification of the service_templates.parent_id field in other rows
	    ##            (or add an ON DELETE SET NULL constraint?)
	    unless (@errors) {
		$obj_view     = 'deleted';
		$refresh_left = 1;
	    }
	}
	elsif ( $query->param('task') eq 'No' || $query->param('task') eq 'Back' ) {
	    delete $hidden{'task'};
	    $obj_view = 'service_detail';
	}
	else {
	    foreach my $name ( $query->param ) {
		unless ( $name eq 'nocache' ) {
		    $hidden{$name} = $query->param($name);
		}
	    }
	    delete $hidden{'task'};
	    $obj_view = 'delete';
	}
    }
    my %save = ( 'name'           => 'save', 'value' => 'Save' );
    my %objs = ( 'servicename_id' => $hidden{'servicename_id'} );
    my %docs = Doc->services();
    $hidden{'name'}           = $name;
    $hidden{'servicename_id'} = $query->param('servicename_id');
    unless ( $hidden{'servicename_id'} ) {
	$hidden{'servicename_id'} = $properties{'servicename_id'};
    }
    $objs{'servicename_id'} = $hidden{'servicename_id'};
    unless ($obj_view) { $obj_view = 'service_detail' }
    $hidden{'obj_view'} = $obj_view;
    $form .= Forms->header( $page_title, $session_id, $top_menu, '', $refresh_left );
    if ( $obj_view eq 'service_detail' ) {
	$form .= Forms->service_template_top( $name, $session_id, $obj_view, \%objs, $hidden{'selected'} );
	if (@errors) { $form .= Forms->form_errors( \@errors ) }
	if ( defined( $query->param('template') ) && $query->param('template') eq '-- no base template --' ) {
	    delete $properties{'parent_id'};
	    $form .= build_form('');
	}
	elsif ( $properties{'parent_id'} || $query->param('template') ) {
	    # $properties{'servicetemplate_id'} is actually ignored, in favor of the full %properties
	    $form .= build_service_detail( $properties{'servicetemplate_id'} );
	}
	else {
	    $form .= build_form('');
	}
	$form .= Forms->hidden( \%hidden );
	if ( $auth_delete{'service_templates'} ) {
	    $form .= Forms->form_bottom_buttons( \%save, \%delete, \%rename, \%close, $tab++ );
	}
	else {
	    $form .= Forms->form_bottom_buttons( \%save, \%rename, \%close, $tab++ );
	}
    }
    elsif ( $obj_view eq 'service_check' ) {
	my %template = StorProc->fetch_one( 'service_templates', 'servicetemplate_id', $properties{'parent_id'} );
	my $message  = undef;
	my $inherit  = 0;
	$inherit = $query->param('inherit');
	my %cmd = defined( $properties{'check_command'} ) ?
	  StorProc->fetch_one( 'commands', 'command_id', $properties{'check_command'} ) : ();
	my $command      = $cmd{'name'};
	my $command_save = $cmd{'name'};
	my $command_line = $properties{'command_line'};
	if ( $query->param('command') )      { $command      = $query->param('command') }
	if ( $query->param('command_save') ) { $command_save = $query->param('command_save'); }
	if ( $query->param('command_line') ) { $command_line = $query->param('command_line'); }

	unless ( defined($command) && $command eq $command_save ) {
	    %cmd = defined($command) ? StorProc->fetch_one( 'commands', 'name', $command ) : ();
	    $command_line = undef;
	}
	if ( $inherit or !$command ) {
	    %cmd = defined( $template{'check_command'} ) ?
	      StorProc->fetch_one( 'commands', 'command_id', $template{'check_command'} ) : ();
	    if ( $cmd{'name'} ) {
		$command      = $cmd{'name'};
		$command_line = $template{'command_line'};
		$inherit      = 1;
	    }
	    else {
		my $got_command  = 0;
		my $stid         = $template{'parent_id'};
		my %already_seen = ();
		until ($got_command) {
		    my %t = defined($stid) ? StorProc->fetch_one( 'service_templates', 'servicetemplate_id', $stid ) : ();
		    if ( $t{'check_command'} ) {
			$got_command  = 1;
			%cmd          = StorProc->fetch_one( 'commands', 'command_id', $t{'check_command'} );
			$command      = $cmd{'name'};
			$command_line = $t{'command_line'};
		    }
		    else {
			$already_seen{$stid} = 1;
			if ( $t{'parent_id'} ) {
			    if ( $already_seen{ $t{'parent_id'} } ) {
				$got_command = 1;
				$message     = (
"Note: no parent template (recursively) has a check command defined.<br><b><font color=#FF0000>ERROR:  You have a cyclical chain of parents in your service templates, starting with \"$t{'name'}\".</font></b>"
				);
				$command      = undef;
				$command_line = undef;
			    }
			    else {
				$stid = $t{'parent_id'};
			    }
			}
			else {
			    $got_command  = 1;
			    $message      = ('Note: no parent template (recursively) has a check command defined.');
			    $command      = undef;
			    $command_line = undef;
			}
		    }
		}
	    }
	}
	%cmd = defined($command) ? StorProc->fetch_one( 'commands', 'name', $command ) : ();
	my $arg_string = $command_line;
	$arg_string =~ s/$command!//;
	my $usage = $command;
	my @args = split( /\$ARG/i, ( defined( $cmd{'command_line'} ) ? $cmd{'command_line'} : '' ) );
	if (@args) {
	    my $maxarg = 0;
	    shift @args;    # drop command
	    foreach (@args) {
		if (/^(\d+)\$/) {
		    $maxarg = $1 if $maxarg < $1;
		}
	    }
	    my $args = $maxarg ? join( '!', map "ARG$_", 1 .. $maxarg ) : '';
	    unless ( $command_line =~ /$command/ ) {
		$command_line = "$command!$args";
		$arg_string   = $args;
	    }
	    $usage .= "!$args";
	}
	$form .= Forms->service_template_top( $name, $session_id, $obj_view, \%objs, $hidden{'selected'} );
	if (@errors) { $form .= Forms->form_errors( \@errors ) }

	# FIX LATER:  change label to 'Parent service template:'?
	$form .= Forms->display_hidden( 'Parent template:', '', $template{'name'} );
	$form .= Forms->wizard_doc( 'Service Check', $docs{'service_check'}, undef, 1 );
	if ( $properties{'parent_id'} ) {
	    $form .= Forms->checkbox_override( 'Inherit template check:', 'inherit', $inherit, $docs{'use_parent_check'}, undef, 'Inherit check from the parent service template' );
	}
	my %where = ( 'type' => 'check' );
	my @commands = StorProc->fetch_list_where( 'commands', 'name', \%where );
	if ($message) { $form .= Forms->form_doc($message) }
	$form .= Forms->list_box_submit( 'Check command:', 'command', \@commands, $command, '', $docs{'check_command'}, $tab++, $inherit );
	$form .= Forms->display_hidden( 'Command definition:', '', HTML::Entities::encode( $cmd{'command_line'} ) );
	$form .= Forms->display_hidden( 'Usage:', '', $usage );
	$form .= Forms->text_area( 'Command line:', 'command_line', $command_line, '3', '80', '', $docs{'command_line'}, '', $tab++, undef, undef, $inherit );
	$form .= Forms->test_service_check( $test_results, $host, $arg_string, $tab++ );
	$hidden{'command_save'} = $command;
	$form .= Forms->hidden( \%hidden );
	# FIX MINOR:  We need a Bookshelf page on the content of a template, as opposed to a generic service or host service.
	# $help{url} = StorProc->doc_section_url('How+to+manage+services', 'Howtomanageservices-ServiceCheck');
	$form .= Forms->form_bottom_buttons( \%save, $tab++ );
    }
    elsif ( $obj_view eq 'delete' ) {
	my %properties = StorProc->fetch_one( 'service_templates', 'name', $name );
	## GWMON-5188
	## FIX LATER: Should we change this code to allow deleting a service template if other objects reference
	## it (thereby cascade-deleting or -nullifying those references, once appropriate database foreign key
	## constraints are in place), we will want to extend this code to not just list direct uses of this service
	## template, but also list indirect uses, via other service templates that use this one as a parent,
	## recursively.  The doc messages below will also need updating then, to reflect possible indirection.
	my @st_names = StorProc->fetch_unique( 'service_templates', 'name', 'parent_id', $properties{servicetemplate_id} );
	my $host_services = StorProc->get_host_services_using_service_template( $properties{servicetemplate_id} );
	push @errors, delete $host_services->{error} if $host_services->{error};
	my $message;
	if (@st_names || %$host_services) {
	    $message = qq(Service template "$name" is currently in use by the following);
	    $message .= ' service templates' if @st_names;
	    $message .= ' and' if @st_names && %$host_services;
	    $message .= ' host services' if %$host_services;
	    $message .= ', so it cannot be deleted.';
	    $form .= Forms->form_top( 'Delete Prohibited', '', '', '100%' );
	}
	else {
	    $message = qq(Are you sure you want to remove service template "$name");
	    ## Preparing for the future; see note above.
	    if (@st_names || %$host_services) {
		$message .= ' from the following';
		$message .= ' service templates' if @st_names;
		$message .= ' and' if @st_names && %$host_services;
		$message .= ' host services' if %$host_services;
	    }
	    $message .= '?';
	    $form .= Forms->form_top( 'Confirm Delete', '', '', '100%' );
	}
	$form .= Forms->hidden( \%hidden );
	if (@errors) { $form .= Forms->form_errors( \@errors ) }
	$form .= Forms->wizard_doc( undef, $message );
	if (@st_names) {
	    $form .= Forms->list_box_display( 'Child service templates:', 'templates', \@st_names, 15,
	      "Service templates that reference the &quot;$name&quot; service template." );
	}
	if (%$host_services) {
	    $form .= Forms->hash_hash_display( 'Host services:', $host_services, 35,
	      "Host services that reference the &quot;$name&quot; service template." );
	}
	if (@st_names || %$host_services) {
	    my %back  = ( 'name' => 'task', 'value' => 'Back' );
	    $form .= Forms->form_bottom_buttons( \%back );
	}
	else {
	    my %yes = ( 'name' => 'confirm_delete', 'value' => 'Yes' );
	    my %no  = ( 'name' => 'task', 'value' => 'No' );
	    $form .= Forms->form_bottom_buttons( \%yes, \%no );
	}
    }
    elsif ( $obj_view eq 'deleted' ) {
	$form .= Forms->form_top( 'Service Template Deleted', '' );
	my @message = ("$name");
	$form .= Forms->form_message( 'Removed:', \@message, 'row1' );
	$form .= Forms->hidden( \%hidden );
	$form .= Forms->form_bottom_buttons( \%continue );
    }
    elsif ( $obj_view eq 'saved' ) {
	my %objs = ( 'service_id' => $properties{'servicename_id'}, 'name' => $name );
	$form .= Forms->service_template_top( $name, $session_id, $obj_view, \%objs, $hidden{'selected'} );
	$form .= Forms->display_hidden( 'Saved:', '', $name );
	$form .= Forms->hidden( \%hidden );
	$form .= Forms->form_bottom_buttons( \%close );
    }
    elsif ( $obj_view eq 'rename' ) {
	$form .= Forms->form_top( 'Rename Service Template', '', '' );
	if (@errors) { $form .= Forms->form_errors( \@errors ) }
	$form .= Forms->display_hidden( 'Service template name:', 'name', $name );
	$form .= Forms->text_box( 'Rename to:', 'new_name', '', $textsize{'name'}, '', $docs{'name'}, '', $tab++ );
	$hidden{'obj_view'} = 'rename';
	$form .= Forms->hidden( \%hidden );
	$form .= Forms->form_bottom_buttons( \%rename, \%cancel, $tab++ );
    }
    elsif ( $obj_view eq 'copy' ) {
	$form .= Forms->form_top( 'Copy Service Template', '', '' );
	if (@errors) { $form .= Forms->form_errors( \@errors ) }
	$form .= Forms->display_hidden( 'Copy:', 'source', $source );
	$form .= Forms->text_box( 'Service template name:', 'name', $name, $textsize{'name'}, '', $docs{'name'}, '', $tab++ );
	$form .= Forms->hidden( \%hidden );
	$help{url} = StorProc->doc_section_url('About+Configuration', 'AboutConfiguration-HostandServiceTemplates');
	$form .= Forms->form_bottom_buttons( \%add, \%cancel, \%help, $tab++ );
    }
    elsif ( $obj_view eq 'new' ) {
	$form .= Forms->form_top( 'New Service Template', '', '' );
	if (@errors) { $form .= Forms->form_errors( \@errors ) }
	$form .= Forms->text_box( 'Service template name:', 'name', $name, $textsize{'name'}, '', $docs{'name'}, '', $tab++ );
	$form .= Forms->hidden( \%hidden );
	$help{url} = StorProc->doc_section_url('About+Configuration', 'AboutConfiguration-HostandServiceTemplates');
	$form .= Forms->form_bottom_buttons( \%add, \%cancel, \%help, $tab++ );
    }
    return $form;
}

#
############################################################################
# Build Contact
#

sub build_contact() {
    local $_;

    my $form                            = undef;
    my $select_all                      = undef;
    my $raw_host_notification_period    = undef;
    my $raw_service_notification_period = undef;
    my $name                            = $query->param('name');
    if ( $task eq 'copy' ) {
	$name = $query->param('source');
	delete $hidden{'task'};
    }
    $hidden{'contact_id'} = $query->param('contact_id');
    my %contact  = StorProc->fetch_one( 'contacts', 'name', $name );
    my %template = StorProc->fetch_one( 'contact_templates', 'contacttemplate_id', $contact{'contacttemplate_id'} );
    $contact{'template'} = $template{'name'};
    if ( StorProc->sanitize_string( scalar $query->param('alias') ) ) {
	$contact{'alias'} = StorProc->sanitize_string( scalar $query->param('alias') );
    }
    if ( StorProc->sanitize_string( scalar $query->param('pager') ) ) {
	$contact{'pager'} = StorProc->sanitize_string( scalar $query->param('pager') );
    }
    if ( StorProc->sanitize_string( scalar $query->param('email') ) ) {
	$contact{'email'} = StorProc->sanitize_string( scalar $query->param('email') );
    }

    if ( $query->param('template') ) {
	%template = StorProc->fetch_one( 'contact_templates', 'name', scalar $query->param('template') );
	$contact{'template'} = $query->param('template');
    }
    my %raw_template    = %template;
    my %overrides_saved = StorProc->fetch_one( 'contact_overrides', 'contact_id', $contact{'contact_id'} );
    my %override        = ();
    my @props           = split( /,/, $property_list{'contact_templates'} );
    foreach (@props) {
	$override{$_} = 'checked';
    }

    my %np = StorProc->fetch_one( 'time_periods', 'timeperiod_id', $template{'host_notification_period'} );
    $raw_host_notification_period = $template{'host_notification_period'} = $np{'name'};
    %np = StorProc->fetch_one( 'time_periods', 'timeperiod_id', $template{'service_notification_period'} );
    $raw_service_notification_period = $template{'service_notification_period'} = $np{'name'};

    my @host_commands =
      defined( $template{'contacttemplate_id'} ) ? StorProc->get_command_contact_template( $template{'contacttemplate_id'}, 'host' ) : ();
    my @service_commands =
      defined( $template{'contacttemplate_id'} ) ? StorProc->get_command_contact_template( $template{'contacttemplate_id'}, 'service' ) : ();
    my @raw_host_commands         = @host_commands;
    my @raw_service_commands      = @service_commands;
    my @override_host_commands    = defined( $contact{'contact_id'} ) ? StorProc->get_command_contact( $contact{'contact_id'}, 'host' ) : ();
    my @override_service_commands = defined( $contact{'contact_id'} ) ? StorProc->get_command_contact( $contact{'contact_id'}, 'service' ) : ();

    if ( $query->param('select_all') ) {
	$select_all = 1;
    }
    else {
	foreach (@props) {
	    if ( $overrides_saved{$_} ) {
		$override{$_} = 'unchecked';
		if ( $_ eq 'host_notification_period' ) {
		    %np = StorProc->fetch_one( 'time_periods', 'timeperiod_id', $overrides_saved{'host_notification_period'} );
		    $template{$_} = $np{'name'};
		}
		elsif ( $_ eq 'service_notification_period' ) {
		    %np = StorProc->fetch_one( 'time_periods', 'timeperiod_id', $overrides_saved{'service_notification_period'} );
		    $template{$_} = $np{'name'};
		}
		else {
		    $template{$_} = $overrides_saved{$_};
		}
	    }
	}
	## FIX MAJOR:  I believe there's a JIRA on this.  An empty set of overrides ought to be allowed.
	if (@override_host_commands) {
	    @host_commands = ();
	    $override{'host_notification_commands'} = 'unchecked';
	    foreach (@override_host_commands) {
		push @host_commands, $_;
	    }
	}
	## FIX MAJOR:  I believe there's a JIRA on this.  An empty set of overrides ought to be allowed.
	if (@override_service_commands) {
	    @service_commands = ();
	    $override{'service_notification_commands'} = 'unchecked';
	    foreach (@override_service_commands) {
		push @service_commands, $_;
	    }
	}
    }
    my @contact_props = split( /,/, $property_list{'contacts'} );
    my %docs = Doc->properties_doc( 'contacts', \@contact_props );
    if (@errors) { $form .= Forms->form_errors( \@errors ) }

    #  contact_name
    if ( $view eq 'design' ) {
	$form .= Forms->text_box( 'Contact name:', 'name', $name, $textsize{'name'}, $required{'name'}, $docs{'name'}, '', $tab++ );
    }
    else {
	$form .= Forms->display_hidden( 'Contact name:', 'name', $name );
    }
    $form .= Forms->text_box( 'Alias:', 'alias', $contact{'alias'}, $textsize{'alias'}, $required{'alias'}, $docs{'alias'}, '', $tab++ );
    $form .= Forms->text_box( 'Email:', 'email', $contact{'email'}, $textsize{'email'}, '',                 $docs{'email'}, '', $tab++ );
    $form .= Forms->text_box( 'Pager:', 'pager', $contact{'pager'}, $textsize{'pager'}, '',                 $docs{'pager'}, '', $tab++ );

    my @members = StorProc->fetch_list( 'contact_templates', 'name' );
    my $docs_template = $docs{'template'};

    %docs = Doc->properties_doc( 'contact_templates', \@props );
    $form .= Forms->wizard_doc( 'Contact Template', undef, undef, 1 );
    $form .= Forms->list_box_submit( 'Contact template:', 'template', \@members, $template{'name'}, $required{'template'}, $docs_template, $tab++ );
    $form .= Forms->inheritance( '', $docs{'override'}, \%template, $tab++ );
    my @timeperiods = StorProc->fetch_list( 'time_periods', 'name' );
    my %where = ( 'type' => 'notify' );
    my @commands = StorProc->fetch_list_where( 'commands', 'name', \%where );

    # host_notification_period
    $form .= Forms->list_box(
	'Host notification period:',           'host_notification_period',
	\@timeperiods,                         $template{'host_notification_period'},
	$required{'host_notification_period'}, $docs{'host_notification_period'},
	$override{'host_notification_period'}, $tab++,
	undef,                                 defined($raw_host_notification_period) ? $raw_host_notification_period : ''
    );

    # host_notification_options
    my @opts     = split( /,/, ( defined( $template{'host_notification_options'} )     ? $template{'host_notification_options'}     : '' ) );
    my @raw_opts = split( /,/, ( defined( $raw_template{'host_notification_options'} ) ? $raw_template{'host_notification_options'} : '' ) );
    $form .= Forms->notification_options(
	'contact_templates', 'host_notification_options', \@opts, $required{'host_notification_options'},
	$nagios_ver,
	$docs{'host_notification_options'},
	$override{'host_notification_options'},
	$tab++, undef, \@raw_opts
    );

    # host_notification_commands
    $form .= Forms->list_box_multiple(
	'Host notification commands:',
	'host_notification_commands', \@commands, \@host_commands, '',
	$docs{'host_notification_commands'},
	$override{'host_notification_commands'},
	$tab++, undef, \@raw_host_commands
    );

    # service_notification_period
    $form .= Forms->list_box(
	'Service notification period:',           'service_notification_period',
	\@timeperiods,                            $template{'service_notification_period'},
	$required{'service_notification_period'}, $docs{'service_notification_period'},
	$override{'service_notification_period'}, $tab++,
	undef,                                    defined($raw_service_notification_period) ? $raw_service_notification_period : ''
    );

    # service_notification_options
    @opts     = split( /,/, ( defined( $template{'service_notification_options'} )     ? $template{'service_notification_options'}     : '' ) );
    @raw_opts = split( /,/, ( defined( $raw_template{'service_notification_options'} ) ? $raw_template{'service_notification_options'} : '' ) );
    $form .= Forms->notification_options(
	'contact_templates', 'service_notification_options',
	\@opts, $required{'service_notification_options'},
	$nagios_ver,
	$docs{'service_notification_options'},
	$override{'service_notification_options'},
	$tab++, undef, \@raw_opts
    );

    # service_notification_commands
    $form .= Forms->list_box_multiple(
	'Service notification commands:',
	'service_notification_commands',
	\@commands, \@service_commands, '',
	$docs{'service_notification_commands'},
	$override{'service_notification_commands'},
	$tab++, undef, \@raw_service_commands
    );

    # FIX MAJOR:  If the screen got refreshed because of a change of template, use the equivalent of %overrides_saved
    # from the query parameters rather than from the database, so as not to lose any changes made by the user, though
    # we will then need to filter out the variables which were from the previous template.  Also use the query values
    # if the screen got refreshed because "Set Inheritance" was clicked or because required fields were missing during
    # a contact Add operation.
    my %template_variables = map { $_ => $template{$_}        } grep( /^_/, keys %template );
    my %object_variables   = map { $_ => $overrides_saved{$_} } grep( /^_/, keys %overrides_saved );
    my %parent_vars = (
	menu => 'contacts',
	view => 'manage',
	type => 'contact_templates',
	name => $template{'name'},
	vars => \%template_variables,
    );
    my ($template_names, $template_urls, $template_vars) = Forms->resolve_template_variables( $session_id, [ \%parent_vars ] );

    my $root_template = 0;
    $form .= Forms->custom_variables( $template_names, $template_urls, $template_vars, \%object_variables,
      $root_template, $docs{'custom_object_variables'}, $tab );
    $tab += 20;

    $form .= Forms->wizard_doc( 'Additional Per-Contact Options', undef, undef, 1 );
    # contactgroups
    my @contactgroups = $query->$multi_param('contactgroup');
    unless (@contactgroups or not defined $contact{'contact_id'}) {
	@contactgroups = StorProc->get_contactgroup_contact( $contact{'contact_id'} );
    }
    my @nonmembers = StorProc->fetch_list( 'contactgroups', 'name' );
    $form .= Forms->members( 'Contact groups:', 'contactgroup', \@contactgroups, \@nonmembers, '', '10', $docs{'contactgroup'}, '', $tab++ );

    return $form;
}

#
############################################################################
# Build Command
#

sub command_wizard() {
    my $form = undef;
    my @command_props = split( /,/, $property_list{'commands'} );
    push @command_props, 'usage';
    my %docs = Doc->properties_doc( 'commands', \@command_props );
    my %save = ( 'name' => 'save', 'value' => 'Save' );
    my %done = ( 'name' => 'save', 'value' => 'Done' );
    my %test = ( 'name' => 'test', 'value' => 'Test' );
    my $command      = $query->param('command');
    my $command_line = $query->param('command_line');
    my $name         = $query->param('name');
    my $type         = $query->param('type');
    my $host         = $query->param('host');
    my $arg_string   = $query->param('arg_string');
    my $service_desc = $query->param('service_desc');
    my $results      = undef;
    my $resource_sav = undef;
    my $got_form     = 0;

    if ( $query->param('back') ) {
	## do nothing special
    }
    elsif ( $query->param('bail') ) {
	$task = 'modify';
    }
    elsif ( $task eq 'external' ) {
	$task = 'modify';
    }
    elsif ( $query->param('continue') || $query->param('cancel') ) {
	$form .= Forms->header( $page_title, $session_id, $top_menu );
	$got_form = 1;
    }
    elsif ( $query->param('delete') ) {
	$form .= delete_object( '', $name );
	$got_form = 1;
    }
    elsif ( $query->param('rename') ) {
	$form .= rename_object( '', $name );
	$got_form = 1;
    }
    elsif ( $query->param('add') || $query->param('save') ) {
	if ( $name && $type && $command_line ) {
	    my $data = qq(<?xml version="1.0" encoding="iso-8859-1" ?>
<data>
  <prop name="command_line"><![CDATA[$command_line]]>
  </prop>
</data>);
	    if ( $query->param('add') ) {
		$name =~ s/^\s+|\s+$//g;
		my %command = StorProc->fetch_one( 'commands', 'name', $name );
		if ( $command{'name'} ) {
		    push @errors, "Duplicate: Command \"$name\" already exists.";
		}
		else {
		    my @values = ( \undef, $name, $type, $data, '' );
		    my $result = StorProc->insert_obj( 'commands', \@values );
		    if ( $result =~ /^Error/ ) {
			push @errors, $result;
		    }
		}
	    }
	    else {
		my %values = ( 'type' => $type, 'data' => $data );
		my $result = StorProc->update_obj( 'commands', 'name', $name, \%values );
		if ( $result =~ /^Error/ ) { push @errors, $result }
	    }
	}
	else {
	    $required{'name'}         = 1;
	    $required{'type'}         = 1;
	    $required{'command_line'} = 1;
	    push @errors, 'Missing required fields: Name, Type, Command line.';
	}
	if ( $obj eq 'commands' ) {
	    unless (@errors) {
		$form .= Forms->header( $page_title, $session_id, $top_menu );
		$form .= Forms->form_top( 'Command', '' );
		if ( $query->param('add') ) {
		    my @message = ("Command \"$name\" added.");
		    $form .= Forms->form_message( 'Saved:', \@message, 'row1' );
		}
		else {
		    my @message = ("Command \"$name\" updated.");
		    $form .= Forms->form_message( 'Saved:', \@message, 'row1' );
		}
		delete $hidden{'task'};
		$form .= Forms->hidden( \%hidden );
		$form .= Forms->form_bottom_buttons( \%continue, $tab++ );
		$got_form = 1;
	    }
	}
    }
    elsif ( $query->param('update_resource') ) {
	$resource_sav = $query->param('resource');
	my $resource_value = $query->param('resource_value');
	my $comment        = $query->param('comment');
	my %values         = ( 'value' => $resource_value );
	my $result         = StorProc->update_obj( 'setup', 'name', $resource_sav, \%values );
	if ( $result =~ /error/i ) { push @errors, $result }
	my $label = $resource_sav;
	$label =~ s/user//;
	%values = ( 'value' => $comment );
	$result = StorProc->update_obj( 'setup', 'name', "resource_label$label", \%values );
	if ( $result =~ /error/i ) { push @errors, $result }
    }
    elsif ( $query->param('test_command') ) {
	$results .= StorProc->test_command( $name, $command_line, $host, $arg_string, $monarch_home, $service_desc, $nagios_ver );
    }
    elsif ( $query->param('new_command') ) {
	$task = 'new_command';
	$hidden{'task'} = 'new_command';
    }
    unless ($got_form) {
	$form .= Forms->header( $page_title, $session_id, $top_menu );
	if ( $task eq 'new' ) {
	    my $resource       = undef;
	    my $resource_value = undef;
	    my %resources      = StorProc->get_resources();
	    my %resource_doc   = StorProc->get_resources_doc();
	    my %selected       = ();

	    $resource = $resource_sav || $query->param('resource_macro');
	    $form .= Forms->form_top( 'Command Wizard', '', '', '100%' );
	    if ($resource) {
		$form .= Forms->wizard_doc('Select plugin or a different resource macro', 'Choose the particular plugin you need, then press "Next >>" at the bottom of this screen to edit the rest of the command definition. Or if necessary, choose a different resource macro defining the plugin directory.', undef, 1);
	    }
	    else {
		$form .= Forms->wizard_doc('Select resource macro', 'In this screen, you will specify the plugin (script or program) that your command will call.  To start, choose a resource macro whose value is the absolute pathname of the directory where your plugin lives. This will almost always be <i>USER1</i>.', undef, 1);
	    }
	    if (@errors) { $form .= Forms->form_errors( \@errors ) }
	    if ($resource) {
		$resource_value = $resources{$resource};
		%selected = ( 'name' => $resource, 'value' => $resource_value );
		my %res = StorProc->fetch_one( 'setup', 'name', $resource );
		my @plugins = ();

		# We only look up potential plugins in a directory with an
		# absolute pathname, because the user should not be aware of
		# any notion of the current working directory of this process.
		# WARNING:  We ought to put in more stringent validation here,
		# restricting the view to some selected set of directories.
		# Otherwise, the end-user can use this mechanism to create a
		# list of all the files in any directory on the system.
		if ( $res{'value'} =~ m@^/@ ) {
		    @plugins = StorProc->get_dir( $res{'value'}, '', 1 );
		}
		$hidden{'resource'} = $resource;
		$hidden{'type'}     = 'check';
		$form .= Forms->list_box( 'Plugin:', 'command', \@plugins, '', '', '', '', $tab++ );
	    }
	    $form .= Forms->resource_select( \%resources, \%resource_doc, \%selected, $top_menu, $tab++ );
	    $hidden{'obj_view'} = 'new_command';
	    $form .= Forms->hidden( \%hidden );
	    my %next = ( 'name' => 'new_command', 'value' => 'Next >>' );
	    $help{url} = StorProc->doc_section_url('How+to+define+a+command');
	    $form .= Forms->form_bottom_buttons( \%next, \%help, $tab++ );
	}
	elsif ( $task =~ /new_command|copy|modify/ ) {
	    my $arg_string = $query->param('arg_string');
	    if ( $obj eq 'commands' ) {
		$form .= Forms->form_top( 'Command Wizard', '', '', '100%' );
	    }
	    if ( $task eq 'copy' ) {
		my $source = $query->param('source');
		unless ($name) { $name = "Copy-of-$source" }
		my %command = StorProc->fetch_one( 'commands', 'name', $source );
		push @errors, delete $command{'error'} if defined $command{'error'};
		unless ($command_line) {
		    $command_line = $command{'command_line'};
		}
		unless ($type) { $type = $command{'type'} }
		$form .= Forms->display_hidden( 'Copy:', 'source', $source );
		if (@errors) { $form .= Forms->form_errors( \@errors ) }
		$form .= Forms->text_box( 'Command name:', 'name', $name, $textsize{'name'}, $required{'name'}, '', '', $tab++ );
	    }
	    elsif ( $task eq 'modify' ) {
		my %command = StorProc->fetch_one( 'commands', 'name', $name );
		push @errors, delete $command{'error'} if defined $command{'error'};
		unless ($command_line) {
		    $command_line = $command{'command_line'};
		}
		unless ($type) { $type = $command{'type'} }
		if (@errors) { $form .= Forms->form_errors( \@errors ) }
		$form .= Forms->display_hidden( 'Command name:', 'name', $name );
	    }
	    else {
		if (@errors) { $form .= Forms->form_errors( \@errors ) }
		$form .= Forms->text_box( 'Command name:', 'name', $name, $textsize{'name'}, $required{'name'}, '', '', $tab++ );
		unless ($command_line) {
		    my $command  = $query->param('command');
		    my $resource = $query->param('resource');
		    $command_line = "\$" . uc($resource) . "\$/$command";
		}
	    }
	    my $usage = "$name";
	    my @args = split( /\$ARG/i, $command_line );
	    if (@args) {
		my $maxarg = 0;
		shift @args;    # drop command
		foreach (@args) {
		    if (/^(\d+)\$/) {
			$maxarg = $1 if $maxarg < $1;
		    }
		}
		my $args = $maxarg ? join( '!', map "ARG$_", 1 .. $maxarg ) : '';
		unless ($arg_string) { $arg_string = $args }
		$usage .= "!$args" if $args;
	    }
	    unless ($host) { $host = 'localhost' }
	    my @types = ( 'check', 'notify', 'other' );
	    $form .= Forms->list_box( 'Type:', 'type', \@types, $type, '', $docs{'type'}, '', $tab++ );
	    my $rows = int( length($command_line) / $textsize{'command_line'} ) + 1;
	    ++$rows while $command_line =~ /\S{$textsize{'command_line'}}/g;
	    $rows = 3 if $rows < 3;
	    $form .= Forms->text_area(
		'Command line:', 'command_line', $command_line, $rows, $textsize{'command_line'},
		'', $docs{'command_line'}, '', $tab++
	    );
	    $form .= Forms->display_hidden( 'Usage:', '', $usage );
	    $form .= Forms->command_test( $results, $host, $arg_string, $service_desc, $tab++ );
	    if ( $obj eq 'commands' ) {
		$form .= Forms->hidden( \%hidden );
		$help{url} = StorProc->doc_section_url('How+to+define+a+command', 'Howtodefineacommand-NewCommand');
		if ( $task eq 'modify' ) {
		    if ( $auth_delete{'commands'} ) {
			$form .= Forms->form_bottom_buttons( \%save, \%rename, \%delete, \%cancel, \%help, $tab++ );
		    }
		    else {
			$form .= Forms->form_bottom_buttons( \%save, \%rename, \%cancel, \%help, $tab++ );
		    }
		}
		else {
		    $form .= Forms->form_bottom_buttons( \%add, \%cancel, \%help, $tab++ );
		}
	    }
	}

	#else {
	#	unless ($got_form) {
	#		$form .= Forms->form_top('Command Wizard','');
	#		if (@errors) { $form .= Forms->form_errors(\@errors) }
	#		my @commands = StorProc->fetch_list('commands','name');
	#		my %selected = ();
	#		$form .= Forms->command_select(\@commands,\%selected);
	#		$form .= Forms->hidden(\%hidden);
	#		$form .= Forms->form_bottom_buttons(\%next);
	#	}
	#}
    }
    return $form;
}

#
###########################################################################################################################
# Time Periods Nagios 3 implementations
# 2008-11-21 Scott Parris
#

# The scanf() patterns and comments we use here for our validation model are drawn directly from the Nagios 3.0.5 code.
sub is_valid_day_rule($%) {

    # FIX LATER:  re-jigger this to return some useful error messages,
    # though to do so we will need to pick apart our concatenated tests

    my $day_rule = shift;
    my $weekdays = shift;

    my %month_name = (
	'01' => 'january',
	'02' => 'february',
	'03' => 'march',
	'04' => 'april',
	'05' => 'may',
	'06' => 'june',
	'07' => 'july',
	'08' => 'august',
	'09' => 'september',
	'10' => 'october',
	'11' => 'november',
	'12' => 'december',
    );

    my %days_in_month = (
	january   => 31,
	february  => 29,
	march     => 31,
	april     => 30,
	may       => 31,
	june      => 30,
	july      => 31,
	august    => 31,
	september => 30,
	october   => 31,
	november  => 30,
	december  => 31,
    );

    #	"%4d-%2d-%2d - %4d-%2d-%2d / %d %[0-9:, -]"
    if ( $day_rule =~ m@^(\d{4})-(\d{2})-(\d{2}) - (\d{4})-(\d{2})-(\d{2}) / (\d+)$@ ) {
	my $year_1      = $1;
	my $month_1     = $2;
	my $month_day_1 = $3;
	my $year_2      = $4;
	my $month_2     = $5;
	my $month_day_2 = $6;
	my $divisor     = $7;
	if (
		$year_1 >= 2000
	    and $year_1 <= 9999
	    and $year_2 >= 2000
	    and $year_2 <= 9999
	    and exists( $month_name{$month_1} )
	    and exists( $month_name{$month_2} )
	    and $month_day_1 > 0
	    and $month_day_1 <= $days_in_month{ $month_name{$month_1} }
	    and $month_day_2 > 0
	    and $month_day_2 <= $days_in_month{ $month_name{$month_2} }
	    and (  ( $month_1 != '02' )
		or ( ( $year_1 % 400 != 0 ) and ( ( $year_1 % 100 == 0 ) or ( $year_1 % 4 != 0 ) ) )
		or ( $month_day_1 <= 28 ) )
	    and (  ( $month_2 != '02' )
		or ( ( $year_2 % 400 != 0 ) and ( ( $year_2 % 100 == 0 ) or ( $year_2 % 4 != 0 ) ) )
		or ( $month_day_2 <= 28 ) )
	    and (  ( $year_1 < $year_2 )
		or ( $year_1 == $year_2 and $month_1 < $month_2 )
		or ( $year_1 == $year_2 and $month_1 == $month_2 and $month_day_1 <= $month_day_2 ) )
	    and $divisor > 0
	  )
	{
	    return 1;
	}
	else {
	    return 0;
	}
    }

    #	"%4d-%2d-%2d / %d %[0-9:, -]"
    elsif ( $day_rule =~ m@^(\d{4})-(\d{2})-(\d{2}) / (\d+)$@ ) {
	my $year      = $1;
	my $month     = $2;
	my $month_day = $3;
	my $divisor   = $4;
	if (    $year >= 2000
	    and $year <= 9999
	    and exists( $month_name{$month} )
	    and $month_day > 0
	    and $month_day <= $days_in_month{ $month_name{$month} }
	    and ( ( $month != '02' ) or ( ( $year % 400 != 0 ) and ( ( $year % 100 == 0 ) or ( $year % 4 != 0 ) ) ) or ( $month_day <= 28 ) )
	    and $divisor > 0 )
	{
	    return 1;
	}
	else {
	    return 0;
	}
    }

    #	"%4d-%2d-%2d - %4d-%2d-%2d %[0-9:, -]"
    elsif ( $day_rule =~ m@^(\d{4})-(\d{2})-(\d{2}) - (\d{4})-(\d{2})-(\d{2})$@ ) {
	my $year_1      = $1;
	my $month_1     = $2;
	my $month_day_1 = $3;
	my $year_2      = $4;
	my $month_2     = $5;
	my $month_day_2 = $6;
	if (
		$year_1 >= 2000
	    and $year_1 <= 9999
	    and $year_2 >= 2000
	    and $year_2 <= 9999
	    and exists( $month_name{$month_1} )
	    and exists( $month_name{$month_2} )
	    and $month_day_1 > 0
	    and $month_day_1 <= $days_in_month{ $month_name{$month_1} }
	    and $month_day_2 > 0
	    and $month_day_2 <= $days_in_month{ $month_name{$month_2} }
	    and (  ( $month_1 != '02' )
		or ( ( $year_1 % 400 != 0 ) and ( ( $year_1 % 100 == 0 ) or ( $year_1 % 4 != 0 ) ) )
		or ( $month_day_1 <= 28 ) )
	    and (  ( $month_2 != '02' )
		or ( ( $year_2 % 400 != 0 ) and ( ( $year_2 % 100 == 0 ) or ( $year_2 % 4 != 0 ) ) )
		or ( $month_day_2 <= 28 ) )
	    and (  ( $year_1 < $year_2 )
		or ( $year_1 == $year_2 and $month_1 < $month_2 )
		or ( $year_1 == $year_2 and $month_1 == $month_2 and $month_day_1 <= $month_day_2 ) )
	  )
	{
	    return 1;
	}
	else {
	    return 0;
	}
    }

    #	"%4d-%2d-%2d %[0-9:, -]"
    elsif ( $day_rule =~ m@^(\d{4})-(\d{2})-(\d{2})$@ ) {
	my $year      = $1;
	my $month     = $2;
	my $month_day = $3;
	if (    $year >= 2000
	    and $year <= 9999
	    and exists( $month_name{$month} )
	    and $month_day > 0
	    and $month_day <= $days_in_month{ $month_name{$month} }
	    and ( ( $month != '02' ) or ( ( $year % 400 != 0 ) and ( ( $year % 100 == 0 ) or ( $year % 4 != 0 ) ) ) or ( $month_day <= 28 ) ) )
	{
	    return 1;
	}
	else {
	    return 0;
	}
    }

    # NOTE:  What's the real meaning of this rule?  How much impact does the specification of
    # weekday names have when you've already exactly specified the day of the month?  Does that
    # mean the rule only applies during years when those dates fall on those weekdays?
    #	"%[a-z] %d %[a-z] - %[a-z] %d %[a-z] / %d %[0-9:, -]"
    #	    /* wednesday 1 january - thursday 2 july / 3 */
    elsif ( $day_rule =~ m@^([a-z]+) (-?\d+) ([a-z]+) - ([a-z]+) (-?\d+) ([a-z]+) / (\d+)$@ ) {
	my $weekday_name_1 = $1;
	my $day_1          = $2;
	my $month_name_1   = $3;
	my $weekday_name_2 = $4;
	my $day_2          = $5;
	my $month_name_2   = $6;
	my $divisor        = $7;
	if (    exists( $weekdays->{$weekday_name_1} )
	    and exists( $weekdays->{$weekday_name_2} )
	    and exists( $days_in_month{$month_name_1} )
	    and exists( $days_in_month{$month_name_2} )
	    and ( ( $day_1 > 0 and $day_1 <= 5 ) or ( $day_1 < 0 and $day_1 >= -5 ) )
	    and ( ( $day_2 > 0 and $day_2 <= 5 ) or ( $day_2 < 0 and $day_2 >= -5 ) )
	    and $divisor > 0 )
	{
	    return 1;
	}
	else {
	    return 0;
	}
    }

    #	"%[a-z] %d - %[a-z] %d / %d %[0-9:, -]"
    #	    /* february 1 - march 15 / 3 */
    #	    /* monday 2 - thursday 3 / 2 */
    #	    /* day 4 - day 6 / 2 */
    elsif ( $day_rule =~ m@^([a-z]+) (-?\d+) - ([a-z]+) (-?\d+) / (\d+)$@ ) {
	my $month_or_day_name_1 = $1;
	my $day_1               = $2;
	my $month_or_day_name_2 = $3;
	my $day_2               = $4;
	my $divisor             = $5;
	if (
	    (
		(
			exists( $days_in_month{$month_or_day_name_1} )
		    and exists( $days_in_month{$month_or_day_name_2} )
		    and (  ( $day_1 > 0 and $day_1 <= $days_in_month{$month_or_day_name_1} )
			or ( $day_1 < 0 and $day_1 >= -$days_in_month{$month_or_day_name_1} ) )
		    and (  ( $day_2 > 0 and $day_2 <= $days_in_month{$month_or_day_name_2} )
			or ( $day_2 < 0 and $day_2 >= -$days_in_month{$month_or_day_name_2} ) )
		)
		or (    exists( $weekdays->{$month_or_day_name_1} )
		    and exists( $weekdays->{$month_or_day_name_2} )
		    and ( ( $day_1 > 0 and $day_1 <= 5 ) or ( $day_1 < 0 and $day_1 >= -5 ) )
		    and ( ( $day_2 > 0 and $day_2 <= 5 ) or ( $day_2 < 0 and $day_2 >= -5 ) ) )
		or (    $month_or_day_name_1 eq 'day'
		    and $month_or_day_name_2 eq 'day'
		    and ( ( $day_1 > 0 and $day_1 <= 31 ) or ( $day_1 < 0 and $day_1 >= -31 ) )
		    and ( ( $day_2 > 0 and $day_2 <= 31 ) or ( $day_2 < 0 and $day_2 >= -31 ) ) )
	    )
	    and $divisor > 0
	  )
	{
	    return 1;
	}
	else {
	    return 0;
	}
    }

    #	"%[a-z] %d - %d / %d %[0-9:, -]"
    #	    /* february 1 - 15 / 3 */
    #	    /* monday 2 - 3 / 2 */
    #	    /* day 1 - 25 / 4 */
    elsif ( $day_rule =~ m@^([a-z]+) (-?\d+) - (-?\d+) / (\d+)$@ ) {
	my $month_or_day_name = $1;
	my $day_1             = $2;
	my $day_2             = $3;
	my $divisor           = $4;
	if (
	    (
		(
		    exists( $days_in_month{$month_or_day_name} )
		    and (  ( $day_1 > 0 and $day_1 <= $days_in_month{$month_or_day_name} )
			or ( $day_1 < 0 and $day_1 >= -$days_in_month{$month_or_day_name} ) )
		    and (  ( $day_2 > 0 and $day_2 <= $days_in_month{$month_or_day_name} )
			or ( $day_2 < 0 and $day_2 >= -$days_in_month{$month_or_day_name} ) )
		)
		or (    exists( $weekdays->{$month_or_day_name} )
		    and ( ( $day_1 > 0 and $day_1 <= 5 ) or ( $day_1 < 0 and $day_1 >= -5 ) )
		    and ( ( $day_2 > 0 and $day_2 <= 5 ) or ( $day_2 < 0 and $day_2 >= -5 ) ) )
		or (    $month_or_day_name eq 'day'
		    and ( ( $day_1 > 0 and $day_1 <= 31 ) or ( $day_1 < 0 and $day_1 >= -31 ) )
		    and ( ( $day_2 > 0 and $day_2 <= 31 ) or ( $day_2 < 0 and $day_2 >= -31 ) ) )
	    )
	    and $divisor > 0
	  )
	{
	    return 1;
	}
	else {
	    return 0;
	}
    }

    #	"%[a-z] %d %[a-z] - %[a-z] %d %[a-z] %[0-9:, -]"
    #	    /* wednesday 1 january - thursday 2 july */
    elsif ( $day_rule =~ m@^([a-z]+) (-?\d+) ([a-z]+) - ([a-z]+) (-?\d+) ([a-z]+)$@ ) {
	my $weekday_name_1 = $1;
	my $day_1          = $2;
	my $month_name_1   = $3;
	my $weekday_name_2 = $4;
	my $day_2          = $5;
	my $month_name_2   = $6;
	if (    exists( $weekdays->{$weekday_name_1} )
	    and exists( $weekdays->{$weekday_name_2} )
	    and exists( $days_in_month{$month_name_1} )
	    and exists( $days_in_month{$month_name_2} )
	    and ( ( $day_1 > 0 and $day_1 <= 5 ) or ( $day_1 < 0 and $day_1 >= -5 ) )
	    and ( ( $day_2 > 0 and $day_2 <= 5 ) or ( $day_2 < 0 and $day_2 >= -5 ) ) )
	{
	    return 1;
	}
	else {
	    return 0;
	}
    }

    #	"%[a-z] %d - %d %[0-9:, -]"
    #	    /* february 3 - 5 */
    #	    /* thursday 2 - 4 */
    #	    /* day 1 - 4 */
    elsif ( $day_rule =~ m@^([a-z]+) (-?\d+) - (-?\d+)$@ ) {
	my $month_or_day_name = $1;
	my $day_1             = $2;
	my $day_2             = $3;
	if (
	    (
		exists( $days_in_month{$month_or_day_name} )
		and (  ( $day_1 > 0 and $day_1 <= $days_in_month{$month_or_day_name} )
		    or ( $day_1 < 0 and $day_1 >= -$days_in_month{$month_or_day_name} ) )
		and (  ( $day_2 > 0 and $day_2 <= $days_in_month{$month_or_day_name} )
		    or ( $day_2 < 0 and $day_2 >= -$days_in_month{$month_or_day_name} ) )
	    )
	    or (    exists( $weekdays->{$month_or_day_name} )
		and ( ( $day_1 > 0 and $day_1 <= 5 ) or ( $day_1 < 0 and $day_1 >= -5 ) )
		and ( ( $day_2 > 0 and $day_2 <= 5 ) or ( $day_2 < 0 and $day_2 >= -5 ) ) )
	    or (    $month_or_day_name eq 'day'
		and ( ( $day_1 > 0 and $day_1 <= 31 ) or ( $day_1 < 0 and $day_1 >= -31 ) )
		and ( ( $day_2 > 0 and $day_2 <= 31 ) or ( $day_2 < 0 and $day_2 >= -31 ) ) )
	  )
	{
	    return 1;
	}
	else {
	    return 0;
	}
    }

    #	"%[a-z] %d - %[a-z] %d %[0-9:, -]"
    #	    /* february 1 - march 15 */
    #	    /* monday 2 - thursday 3 */
    #	    /* day 1 - day 5 */
    elsif ( $day_rule =~ m@^([a-z]+) (-?\d+) - ([a-z]+) (-?\d+)$@ ) {
	my $month_or_day_name_1 = $1;
	my $day_1               = $2;
	my $month_or_day_name_2 = $3;
	my $day_2               = $4;
	if (
	    (
		    exists( $days_in_month{$month_or_day_name_1} )
		and exists( $days_in_month{$month_or_day_name_2} )
		and (  ( $day_1 > 0 and $day_1 <= $days_in_month{$month_or_day_name_1} )
		    or ( $day_1 < 0 and $day_1 >= -$days_in_month{$month_or_day_name_1} ) )
		and (  ( $day_2 > 0 and $day_2 <= $days_in_month{$month_or_day_name_2} )
		    or ( $day_2 < 0 and $day_2 >= -$days_in_month{$month_or_day_name_2} ) )
	    )
	    or (    exists( $weekdays->{$month_or_day_name_1} )
		and exists( $weekdays->{$month_or_day_name_2} )
		and ( ( $day_1 > 0 and $day_1 <= 5 ) or ( $day_1 < 0 and $day_1 >= -5 ) )
		and ( ( $day_2 > 0 and $day_2 <= 5 ) or ( $day_2 < 0 and $day_2 >= -5 ) ) )
	    or (    $month_or_day_name_1 eq 'day'
		and $month_or_day_name_2 eq 'day'
		and ( ( $day_1 > 0 and $day_1 <= 31 ) or ( $day_1 < 0 and $day_1 >= -31 ) )
		and ( ( $day_2 > 0 and $day_2 <= 31 ) or ( $day_2 < 0 and $day_2 >= -31 ) ) )
	  )
	{
	    return 1;
	}
	else {
	    return 0;
	}
    }

    #	"%[a-z] %d%*[ \t]%[0-9:, -]"
    #	    /* february 3 */
    #	    /* thursday 2 */
    #	    /* day 1 */
    elsif ( $day_rule =~ m@^([a-z]+) (-?\d+)$@ ) {
	my $month_or_day_name = $1;
	my $day               = $2;
	if (
	    (
		exists( $days_in_month{$month_or_day_name} )
		and
		( ( $day > 0 and $day <= $days_in_month{$month_or_day_name} ) or ( $day < 0 and $day >= -$days_in_month{$month_or_day_name} ) )
	    )
	    or ( exists( $weekdays->{$month_or_day_name} )
		and ( ( $day > 0 and $day <= 5 ) or ( $day < 0 and $day >= -5 ) ) )
	    or ( $month_or_day_name eq 'day'
		and ( ( $day > 0 and $day <= 31 ) or ( $day < 0 and $day >= -31 ) ) )
	  )
	{
	    return 1;
	}
	else {
	    return 0;
	}
    }

    #	"%[a-z] %d %[a-z] %[0-9:, -]"
    #	    /* thursday 3 february */
    elsif ( $day_rule =~ m@^([a-z]+) (-?\d+) ([a-z]+)$@ ) {
	my $weekday_name = $1;
	my $day          = $2;
	my $month_name   = $3;
	if (    exists( $weekdays->{$weekday_name} )
	    and exists( $days_in_month{$month_name} )
	    and ( ( $day > 0 and $day <= 5 ) or ( $day < 0 and $day >= -5 ) ) )
	{
	    return 1;
	}
	else {
	    return 0;
	}
    }

    #	"%[a-z] %[0-9:, -]"
    #	    /* monday */
    elsif ( $day_rule =~ m@^([a-z]+)$@ ) {
	my $weekday_name = $1;
	if ( exists( $weekdays->{$weekday_name} ) ) {
	    return 1;
	}
	else {
	    return 0;
	}
    }

    return 0;
}

sub is_valid_hours($) {
    my $hours = shift;

    # HH:MM-HH:MM[,HH:MM-HH:MM]*
    if ( $hours =~ m@^[0-2]\d:[0-5]\d-[0-2]\d:[0-5]\d(?:,[0-2]\d:[0-5]\d-[0-2]\d:[0-5]\d)*$@ ) {
	while ( $hours =~ s@^([0-2]\d):([0-5]\d)-([0-2]\d):([0-5]\d),?@@ ) {
	    return 0 if ( $1 > 24 || ( $1 == 24 && $2 != 0 ) );
	    return 0 if ( $3 > 24 || ( $3 == 24 && $4 != 0 ) );
	    return 0 if ( $1 > $3 || ( $1 == $3 && $2 > $4 ) );
	}
	return 1;
    }

    return 0;
}

sub get_time_period($) {
    my $name        = shift;
    my %where       = ();
    my %time_period = StorProc->fetch_one( 'time_periods', 'name', $name );
    $where{'timeperiod_id'} = $time_period{'timeperiod_id'};
    my @timeperiod_exclude_list = StorProc->fetch_list_where( 'time_period_exclude', 'exclude_id', \%where );
    foreach my $id (@timeperiod_exclude_list) {
	$time_period{'exclude'}{$id} = 1;
    }
    my %timeperiod_prop_hash = StorProc->fetch_hash_array_generic_key( 'time_period_property', \%where );
    foreach my $key ( keys %timeperiod_prop_hash ) {
	$time_period{ $timeperiod_prop_hash{$key}[2] }{ $timeperiod_prop_hash{$key}[1] }{'value'}   = $timeperiod_prop_hash{$key}[3];
	$time_period{ $timeperiod_prop_hash{$key}[2] }{ $timeperiod_prop_hash{$key}[1] }{'comment'} = $timeperiod_prop_hash{$key}[4];
    }
    return %time_period;
}

sub time_period() {
    my ( $form, $new, $save, $are_you_sure, $deleted, $saved, $rename, $renamed, $remove_weekday, $remove_exception ) = undef;
    my $name    = StorProc->sanitize_string( scalar $query->param('name') );
    my $alias   = StorProc->sanitize_string( scalar $query->param('alias') );
    my $comment = StorProc->sanitize_string_but_keep_newlines( scalar $query->param('comment') );

    # Collapsing extra spaces is probably not necessary since we disallow spaces in time period names, but it won't hurt.
    $name =~ s/\s+/ /g if defined $name;

    $new = 1 if $task eq 'new';
    my %where        = ();
    my %time_periods = ();
    my %time_period  = ();
    my %cancel       = ( 'name' => 'close', 'value' => 'Cancel' );
    my %create       = ( 'name' => 'create', 'value' => 'Create' );
    my %weekdays     = (
	sunday    => 1,
	monday    => 1,
	tuesday   => 1,
	wednesday => 1,
	thursday  => 1,
	friday    => 1,
	saturday  => 1,
    );

    unless ( $task eq 'new' || $query->param('close') ) {
	%time_period = get_time_period($name);
    }
    unless ( $query->param('close') ) {
	my %time_period_hash = StorProc->fetch_list_hash_array( 'time_periods', \%where );
	foreach my $id ( keys %time_period_hash ) {
	    my $tname = $time_period_hash{$id}[1];
	    $time_periods{$tname}{'id'}      = $id;
	    $time_periods{$tname}{'alias'}   = $time_period_hash{$id}[2];
	    $time_periods{$tname}{'comment'} = $time_period_hash{$id}[3];
	}
    }
    if ( $query->param('create') ) {
	if ( $name && $alias ) {
	    if ( $time_periods{$name} ) {
		push @errors, "A time period named \"$name\" already exists. Please specify another name.";
		$name = undef;
	    }
	    else {
		my @vals = ( \undef, $name, $alias, $comment );
		my $id = StorProc->insert_obj_id( 'time_periods', \@vals, 'timeperiod_id' );
		if ( $id =~ /error/i ) {
		    push @errors, $id;
		}
		else {
		    $task                         = 'modify';
		    $hidden{'task'}               = 'modify';
		    $time_period{'timeperiod_id'} = $id;
		    $time_period{'name'}          = $name;
		    $time_period{'alias'}         = $alias;
		    $time_period{'comment'}       = $comment;
		}
	    }
	}
	else {
	    push @errors, "Time period name and alias are required fields.";
	}
    }
    elsif ( $query->param('copy') ) {
	my $source = $query->param('source');
	if ( $name && $alias ) {
	    if ( $time_periods{$name} ) {
		push @errors, "A time period named \"$name\" already exists. Please specify another name.";
		$name = undef;
	    }
	    else {
		my @vals = ( \undef, $name, $alias, $comment );
		my $id = StorProc->insert_obj_id( 'time_periods', \@vals, 'timeperiod_id' );
		if ( $id =~ /error/i ) {
		    push @errors, $id;
		}
		else {
		    my %time_period_source = get_time_period($source);
		    $task                         = 'modify';
		    $hidden{'task'}               = 'modify';
		    %time_period                  = %time_period_source;
		    $time_period{'timeperiod_id'} = $id;
		    $time_period{'name'}          = $name;
		    $time_period{'alias'}         = $alias;
		    $time_period{'comment'}       = $comment;

		    foreach my $day ( sort keys %{ $time_period{'weekday'} } ) {
			my @vals = ( $id, $day, 'weekday', $time_period{'weekday'}{$day}{'value'}, $time_period{'weekday'}{$day}{'comment'} );
			my $res = StorProc->insert_obj( 'time_period_property', \@vals );
			if ( $res =~ /error/i ) { push @errors, $res }
		    }
		    foreach my $day_rule ( sort keys %{ $time_period{'exception'} } ) {
			my @vals = (
			    $id, $day_rule, 'exception',
			    $time_period{'exception'}{$day_rule}{'value'},
			    $time_period{'exception'}{$day_rule}{'comment'}
			);
			my $res = StorProc->insert_obj( 'time_period_property', \@vals );
			if ( $res =~ /error/i ) { push @errors, $res }
		    }
		    foreach my $eid ( keys %{ $time_period{'exclude'} } ) {
			my @vals = ( $id, $eid );
			my $res = StorProc->insert_obj( 'time_period_exclude', \@vals );
			if ( $res =~ /error/i ) { push @errors, $res }
		    }
		}
	    }
	}
	else {
	    push @errors, "Time period name and alias are required fields.";
	}
    }
    elsif ( $query->param('add_exception') ) {
	my $day_rule = StorProc->sanitize_string( scalar $query->param('new_exception') );
	$day_rule =~ s/\s+/ /g;
	$day_rule = lc $day_rule;
	if ($day_rule) {
	    if ( exists $weekdays{$day_rule} ) {
		push @errors,
		  "Specify individual weekdays (such as \"\u$day_rule\") at the top of the page, not as exceptions. Please try again.";
	    }
	    elsif ( $time_period{'exception'}{$day_rule} ) {
		push @errors, "Day rule \"$day_rule\" is already specified for this time period. Please try again.";
	    }
	    elsif ( !is_valid_day_rule( $day_rule, \%weekdays ) ) {
		push @errors, "\"$day_rule\" is not a valid day rule. Please try again.";
	    }
	    else {
		my @values = ( $time_period{'timeperiod_id'}, $day_rule, 'exception', '00:00-24:00', '' );
		my $res = StorProc->insert_obj( 'time_period_property', \@values );
		$time_period{'exception'}{$day_rule}{'value'} = '00:00-24:00';
		if ( $res =~ /error/i ) { push @errors, $res }
	    }
	}
	$save = 1;
    }
    elsif ( $query->param('add_day') ) {
	my $day = $query->param('new_day');
	if ($day) {
	    my @values = ( $time_period{'timeperiod_id'}, $day, 'weekday', '00:00-24:00', '' );
	    my $res = StorProc->insert_obj( 'time_period_property', \@values );
	    $time_period{'weekday'}{$day}{'value'} = '00:00-24:00';
	    if ( $res =~ /error/i ) { push @errors, $res }
	}
	$save = 1;
    }
    elsif ( $query->param('rename') ) {
	if ( $query->param('cancel_rename') ) {
	    $rename = 0;
	}
	else {
	    my $new_name = StorProc->sanitize_string( scalar $query->param('new_name') );
	    if ( $new_name && ( $new_name ne $name ) ) {
		if ( $time_periods{$new_name} ) {
		    push @errors, "A time period named \"$new_name\" already exists. Please specify another name.";
		    $rename = 1;
		}
		else {
		    my %vals = ( 'name' => $new_name );
		    my $res = StorProc->update_obj( 'time_periods', 'timeperiod_id', $time_period{'timeperiod_id'}, \%vals );
		    if ( $res =~ /error/i ) {
			push @errors, $res;
			$rename = 1;
		    }
		    else {
			$rename  = 0;
			$renamed = "Time period name change to \"$new_name\" accepted.";
		    }
		}
	    }
	    else {
		$rename = 1;
		$save   = 1;
	    }
	}
    }
    elsif ( $query->param('delete') ) {
	if ( $query->param('yes') ) {
	    my $res = StorProc->delete_all( 'time_periods', 'timeperiod_id', $time_period{'timeperiod_id'} );
	    if ( $res =~ /error/i ) {
		push @errors, $res;
	    }
	    else {
		$deleted = "Time period \"$name\" successfully removed.";
	    }
	}
	elsif ( $query->param('no') ) {
	    $are_you_sure = 0;
	}
	else {
	    $are_you_sure = "Delete time period \"$name\"?";
	    my %where = ();
	    my %time_period = StorProc->fetch_one( 'time_periods', 'name', $name );
	    $where{'exclude_id'} = $time_period{'timeperiod_id'};
	    my @excluded_by_timeperiods = StorProc->fetch_list_where( 'time_period_exclude', 'timeperiod_id', \%where );
	    if ( scalar @excluded_by_timeperiods ) {
		my %timeperiod_names = StorProc->get_table_objects( 'time_periods', 1 );
		$are_you_sure .=
'<br><br><b><font color=#FF0000>Caution</font></b><p class=normal>This time period is currently excluded by the following other time period'
		  . ( scalar @excluded_by_timeperiods == 1 ? '' : 's' ) . ':</p><ul>';
		foreach my $id (@excluded_by_timeperiods) {
		    $are_you_sure .= "<li>$timeperiod_names{$id}</li>";
		}
		$are_you_sure .= "</ul><p class=normal>If you delete \"$name\", these exclusions will be deleted as well.</p>";
	    }
	    $save = 1;
	}
    }
    else {
	foreach my $pname ( $query->param ) {
	    if ( $pname =~ /remove_weekday_(\S+)/ ) {
		$remove_weekday = $1;
		%where = ( 'timeperiod_id' => $time_period{'timeperiod_id'}, 'name' => $remove_weekday );
		my $res = StorProc->delete_one_where( 'time_period_property', \%where );
		delete $time_period{'weekday'}{$remove_weekday};
		$save = 1;
	    }
	    elsif ( $pname =~ /remove_exception_(.+)/ ) {
		$remove_exception = $1;
		%where = ( 'timeperiod_id' => $time_period{'timeperiod_id'}, 'name' => $remove_exception );
		my $res = StorProc->delete_one_where( 'time_period_property', \%where );
		delete $time_period{'exception'}{$remove_exception};
		$save = 1;
	    }
	}
    }

    if ( $save || $query->param('save') ) {
	my @excludes = $query->$multi_param('exclude');
	my $res = StorProc->delete_all( 'time_period_exclude', 'timeperiod_id', $time_period{'timeperiod_id'} );
	if ( $res =~ /error/i ) { push @errors, $res }
	foreach my $exclude (@excludes) {
	    my @vals = ( $time_period{'timeperiod_id'}, $exclude );
	    $res = StorProc->insert_obj( 'time_period_exclude', \@vals );
	    if ( $res =~ /error/i ) { push @errors, $res }
	    $time_period{'exclude'}{$exclude} = 1;
	}

	# Reverse sort to ensure we process all weekdays before all exceptions.
	foreach my $pname ( sort { $b cmp $a } $query->param ) {
	    if ( $pname =~ /weekday_(\S+)/ ) {
		my $day = $1;
		unless ( defined($remove_weekday) && $day eq $remove_weekday ) {
		    my $value   = StorProc->sanitize_string( scalar $query->param("value_$day") );
		    my $comment = StorProc->sanitize_string( scalar $query->param("comment_$day") );
		    $value =~ s/\s+//g;
		    if ( !is_valid_hours($value) ) {
			push @errors, "Weekday \"\u$day\" hours \"$value\" are invalid. Please try again.";
			$time_period{'weekday'}{$day}{'bad_hours'} = 1;
		    }
		    else {
			%where = ( 'timeperiod_id' => $time_period{'timeperiod_id'}, 'name' => $day );
			my %vals = ( 'value' => $value, 'comment' => $comment );
			$res = StorProc->update_obj_where( 'time_period_property', \%vals, \%where );
			if ( $res =~ /error/i ) { push @errors, $res }
		    }
		    $time_period{'weekday'}{$day}{'value'}   = $value;
		    $time_period{'weekday'}{$day}{'comment'} = $comment;
		}
	    }
	    if ( $pname =~ /exception_(.*)/ ) {
		my $full_old_day_rule = $1;
		my $old_day_rule      = StorProc->sanitize_string($full_old_day_rule);
		$old_day_rule =~ s/\s+/ /g;
		$old_day_rule = lc $old_day_rule;
		unless ( defined($remove_exception) && $full_old_day_rule eq $remove_exception ) {
		    my $new_day_rule = StorProc->sanitize_string( scalar $query->param("exception_$full_old_day_rule") );
		    my $value        = StorProc->sanitize_string( scalar $query->param("value_$full_old_day_rule") );
		    my $comment      = StorProc->sanitize_string( scalar $query->param("comment_$full_old_day_rule") );
		    $new_day_rule =~ s/\s+/ /g;
		    $new_day_rule = lc $new_day_rule;
		    $value =~ s/\s+//g;
		    my $exception_is_valid = 1;
		    if ( !is_valid_day_rule( $new_day_rule, \%weekdays ) ) {
			push @errors,
			  "Day rule \"$new_day_rule\" is invalid. <b>The bad rule formulation has been discarded.</b> Please try again.";
			$time_period{'exception'}{$old_day_rule}{'bad_day_rule'} = 1;
			$exception_is_valid = 0;
		    }
		    if ( !is_valid_hours($value) ) {
			push @errors, "Day rule \"$new_day_rule\" hours \"$value\" are invalid. Please try again.";
			$time_period{'exception'}{$old_day_rule}{'bad_hours'} = 1;
			$exception_is_valid = 0;
		    }
		    if ($exception_is_valid) {
			if ( $time_period{'exception'}{$new_day_rule} && $new_day_rule ne $old_day_rule ) {
			    push @errors, "Day rule \"$new_day_rule\" is already specified for this time period. Please try again.";
			}
			elsif ( $time_period{'weekday'}{$new_day_rule} ) {
			    push @errors,
"Weekday \"$new_day_rule\" is taken for this time period. Specify individual weekdays at the top of the page. Please try again.";
			}
			elsif ( exists $weekdays{$new_day_rule} ) {
			    push @errors,
"Specify individual weekdays (such as \"\u$new_day_rule\") at the top of the page, not as exceptions. Please try again.";
			}
			else {
			    %where = ( 'timeperiod_id' => $time_period{'timeperiod_id'}, 'name' => $old_day_rule );
			    my %vals = ( 'name' => $new_day_rule, 'value' => $value, 'comment' => $comment );
			    $res = StorProc->update_obj_where( 'time_period_property', \%vals, \%where );
			    if ( $res =~ /error/i ) {
				push @errors, $res;
			    }
			    else {
				delete $time_period{'exception'}{$old_day_rule};
				$old_day_rule = $new_day_rule;
			    }
			}
		    }

		    # Keep the UI hours/description fields as the user last left them, as they
		    # are probably the best formulation to continue editing from, even if they
		    # are bad.  If the user wants instead to refresh back to the last known
		    # good values, they can select the time period name from the left side panel.
		    # The day_rule field is different:  we don't keep the user's changes unless
		    # they are good, because we use the day_rule field as a key field to
		    # synchronize it to the database records, and if the on-screen and database
		    # copies diverge, eventually confusion will result and extra rules will
		    # start popping up.  That could be changed by using an explicit {'day_rule'}
		    # string in parallel with the two other fields here, separating the key field
		    # from the displayed value, but it's not (yet) done that way.
		    $time_period{'exception'}{$old_day_rule}{'value'}   = $value;
		    $time_period{'exception'}{$old_day_rule}{'comment'} = $comment;
		}
	    }
	}
	my %vals = ( 'alias' => $alias, 'comment' => $comment );
	$res = StorProc->update_obj( 'time_periods', 'timeperiod_id', $time_period{'timeperiod_id'}, \%vals );
	if ( $res =~ /error/i ) { push @errors, $res }
	$time_period{'alias'}           = $alias;
	$time_period{'comment'}         = $comment;
	$time_periods{$name}{'alias'}   = $alias;
	$time_periods{$name}{'comment'} = $comment;

	unless ( $errors[0] ) {
	    if ( $query->param('save') ) {
		$saved = "Time period \"$name\" successfully updated.";
	    }
	}
    }

    if ( $query->param('close') ) {
	$form .= Forms->header( $page_title, $session_id, $top_menu );
    }
    elsif ($rename) {
	$hidden{'rename'} = 1;
	$form .= Forms->header( $page_title, $session_id, $top_menu );

	my $illegal_chars = qq(/\\` ~+!\$\%^&*|'"<>?,()=[]:{}#;\n or any 9-bit or larger Unicode characters);
	## FIX LATER:  someday we ought to validate the new_name length as well, but for the
	## moment we might not have the capability to add such additional ANDed constraints.
	my $validation_mini_profile = {
	    name => {
		## We override the standard validation to allow essentially anything for an existing name,
		## so we can rename it to something legal.
		constraint => '.+'
	    },
	    new_name => {
		# See GWMON-6133 for the ugly truth.
		constraint => '[^/\\\\` ~\+!\$\%\^\&\*\|\'\"<>\?,\(\)\'=\[\]\{\}\:\#;\\u0100-\\uFFFD]+',
		message    => "The new name field cannot contain any of the following characters:\n$illegal_chars",
	    },
	};

	$form .= Validation->dfv_profile_javascript($validation_mini_profile);
	$form .= &$Instrument::show_trace_as_html_comment();
	$form .= Forms->form_top( 'Rename Time Period', Validation->dfv_onsubmit_javascript(
	    "if (this.clicked == 'cancel_rename') { return true; }"
	) );
	if (@errors) { $form .= Forms->form_errors( \@errors ) }
	$form .= Forms->display_hidden( 'Time period name:', 'name', $name );
	$form .= Forms->text_box( 'Rename:', 'new_name', '', $textsize{'name'}, '', '', '', $tab++ );
	$form .= Forms->hidden( \%hidden );
	%cancel = ( 'name' => 'cancel_rename', 'value' => 'Cancel' );
	$form .= Forms->form_bottom_buttons( \%rename, \%cancel, $tab++ );
    }
    elsif ($renamed) {
	$form .= Forms->header( $page_title, $session_id, $top_menu, '', '1' );
	$form .= Forms->form_top( 'Time Period', '', '' );
	$form .= Forms->display_hidden( 'Renamed:', '', $renamed );
	$form .= Forms->hidden( \%hidden );
	$form .= Forms->form_bottom_buttons( \%close, $tab++ );
    }
    elsif ($are_you_sure) {
	$hidden{'delete'} = 1;
	$hidden{'name'}   = $name;
	$form .= Forms->header( $page_title, $session_id, $top_menu );
	$form .= Forms->form_top( 'Delete Time Period', '', '' );
	$form .= Forms->wizard_doc( 'Remove time period', $are_you_sure, undef, 1 );
	$form .= Forms->hidden( \%hidden );
	$form .= Forms->form_bottom_buttons( \%yes, \%no, $tab++ );
    }
    elsif ($deleted) {
	$form .= Forms->header( $page_title, $session_id, $top_menu, '', '1' );
	$form .= Forms->form_top( 'Time Period', '', '' );
	$form .= Forms->display_hidden( 'Deleted:', '', $deleted );
	$form .= Forms->hidden( \%hidden );
	$form .= Forms->form_bottom_buttons( \%close, $tab++ );
    }
    elsif ($saved) {
	$form .= Forms->header( $page_title, $session_id, $top_menu );
	$form .= Forms->form_top( 'Time Period', '', '' );
	$form .= Forms->display_hidden( 'Saved:', '', $saved );
	$form .= Forms->hidden( \%hidden );
	$form .= Forms->form_bottom_buttons( \%close, $tab++ );
    }
    elsif ( $task eq 'copy' ) {
	my $source = $query->param('source');
	my %copy_src = StorProc->fetch_one( 'time_periods', 'name', $source );
	unless ($name)    { $name    = "Copy_of_$copy_src{'name'}" }
	unless ($alias)   { $alias   = $copy_src{'alias'} }
	unless ($comment) { $comment = $copy_src{'comment'} }
	$hidden{'source'} = $source;
	$hidden{'task'}   = 'copy';
	$form .= Forms->header( $page_title, $session_id, $top_menu );
	$form .= Validation->dfv_profile_javascript();
	$form .= &$Instrument::show_trace_as_html_comment();
	$form .= Forms->form_top( 'Copy Time Period', Validation->dfv_onsubmit_javascript(
	    "if (this.clicked == 'close') { return true; }"
	) );
	if (@errors) { $form .= Forms->form_errors( \@errors ) }
	$form .= Forms->text_box( 'Time period name:', 'name',  $name,  $textsize{'name'}, '', '', '', $tab++ );
	$form .= Forms->text_box( 'Alias:',            'alias', $alias, $textsize{'name'}, '', '', '', $tab++ );
	$form .= Forms->text_area( 'Description:', 'comment', $comment, '3', '70', '', '', '', $tab++ );
	$form .= Forms->hidden( \%hidden );
	my %copy = ( 'name' => 'copy', 'value' => 'Copy' );
	$form .= Forms->form_bottom_buttons( \%copy, \%cancel, $tab++ );
    }
    elsif ( $task eq 'new' ) {
	$hidden{'task'} = 'new';
	$form .= Forms->header( $page_title, $session_id, $top_menu );
	$form .= Validation->dfv_profile_javascript();
	$form .= &$Instrument::show_trace_as_html_comment();
	$form .= Forms->form_top( 'New Time Period', Validation->dfv_onsubmit_javascript(
	    "if (this.clicked == 'close') { return true; }"
	) );
	if (@errors) { $form .= Forms->form_errors( \@errors ) }
	$form .= Forms->text_box( 'Time period name:', 'name',  $name,  $textsize{'name'}, '', '', '', $tab++ );
	$form .= Forms->text_box( 'Alias:',            'alias', $alias, $textsize{'name'}, '', '', '', $tab++ );
	$form .= Forms->text_area( 'Description:', 'comment', $time_period{'comment'}, '3', '70', '', '', '', $tab++ );
	$form .= Forms->hidden( \%hidden );
	$help{url} = StorProc->doc_section_url('How+to+define+time+periods');
	$form .= Forms->form_bottom_buttons( \%create, \%cancel, \%help, $tab++ );
    }
    else {
	$form .= Forms->header( $page_title, $session_id, $top_menu );
	$form .= Forms->form_top( 'Edit Time Period', '', '' );
	if (@errors) { $form .= Forms->form_errors( \@errors ) }
	$form .= Forms->display_hidden( 'Time period name:', 'name', $name );
	$form .= Forms->text_box( 'Alias:', 'alias', $time_period{'alias'}, $textsize{'name'}, '', '', '', $tab++ );
	$form .= Forms->text_area( 'Description:', 'comment', $time_period{'comment'}, '3', '70', '', '', '', $tab++ );
	$form .= Forms->time_period_detail( \%time_period, \%time_periods, $tab++ );
	$form .= Forms->hidden( \%hidden );
	$help{url} = StorProc->doc_section_url('How+to+define+time+periods');
	$form .= Forms->form_bottom_buttons( \%save, \%rename, \%delete, \%close, \%help, $tab++ );
    }
    return $form;
}

#
############################################################################
# Service Groups
#

sub service_group() {
    my $form     = undef;
    my %save     = ( 'name' => 'save', 'value' => 'Save' );
    my %done     = ( 'name' => 'save', 'value' => 'Done' );
    my $got_form = 0;
    my $name     = $query->param('name');
    my $alias    = $query->param('alias');
    my $notes    = $query->param('notes');
    # FIX LATER:  consider fully sanitizing the name (but test what happens if this is defining a new service group)
    $name =~ s/^\s+|\s+$//g if defined $name;
    if (defined $notes) {
	$notes = StorProc->sanitize_string_but_keep_newlines($notes);
	$notes =~ s/\n/<br>/g;
    }
    my %svcgrp = StorProc->fetch_one( 'servicegroups', 'name', $name );
    unless ($alias) { $alias = $svcgrp{'alias'} }
    unless ($notes) { $notes = $svcgrp{'notes'} }
    my %docs = Doc->servicegroups();

    if ( $query->param('continue') || $query->param('cancel') ) {
	$form .= Forms->header( $page_title, $session_id, $top_menu );
	$got_form = 1;
    }
    elsif ( (defined($task) && $task eq 'new') || $query->param('add') ) {
	$got_form = 1;
	my $name     = $query->param('name');
	my $alias    = $query->param('alias');
	my $notes    = $query->param('notes');
	my $validate = $query->param('validate');
	# FIX LATER:  consider fully sanitizing the name (but test what happens if this is defining a new service group)
	$name =~ s/^\s+|\s+$//g if defined $name;
	if (defined $notes) {
	    $notes = StorProc->sanitize_string_but_keep_newlines($notes);
	    $notes =~ s/\n/<br>/g;
	}
	if ( $name && $alias ) {
	    if ( $svcgrp{'name'} ) {
		push @errors, "Duplicate: Service group \"$name\" already exists.";
	    }
	    else {
		my @values = ( \undef, $name, $alias, '', '', $notes );
		my $result = StorProc->insert_obj( 'servicegroups', \@values );
		if ( $result =~ /error/i ) {
		    push @errors, $result;
		}
		else {
		    delete $hidden{'task'};
		    $got_form = 0;
		}
	    }
	}
	elsif ($validate) {
	    $required{'name'}  = 1;
	    $required{'alias'} = 1;
	    push @errors, "Missing required fields: Name, Alias";
	}
	if ($got_form) {
	    $form .= Forms->header( $page_title, $session_id, $top_menu );
	    # Force validation of the service group name field (implicit within Validation).
	    $form .= Validation->dfv_profile_javascript({});
	    $form .= &$Instrument::show_trace_as_html_comment();
	    $form .= Forms->form_top( "Service Group", Validation->dfv_onsubmit_javascript(
		"if (this.clicked == 'cancel') { return true; }"
	    ) );
	    if (@errors) { $form .= Forms->form_errors( \@errors ) }
	    $form .= Forms->text_box( 'Service group name:', 'name', $name, $textsize{'name'}, $required{'name'}, $docs{'name'}, '', $tab++ );
	    $form .= Forms->text_box( 'Alias:', 'alias', $alias, $textsize{'alias'}, $required{'alias'}, $docs{'alias'}, '', $tab++ );
	    $notes =~ s/<br>/\n/ig if defined $notes;
	    my $lines = (( () = split( /\n/, (defined($notes) ? $notes : ''), 20 ) ) || 1) + 1;
	    $form .= Forms->text_area( 'Notes:', 'notes', $notes, $lines, '74%', '', $docs{'notes'}, '', $tab++ );
	    $hidden{'validate'} = 1;
	    $form .= Forms->hidden( \%hidden );
	    $help{url} = StorProc->doc_section_url('How+to+manage+services', 'Howtomanageservices-ServiceGroups');
	    $form .= Forms->form_bottom_buttons( \%add, \%cancel, \%help, $tab++ );
	}
    }
    elsif ( $query->param('add_services') ) {
	my $host     = $query->param('host');
	my @services = $query->$multi_param('services');
	my %h        = StorProc->fetch_one( 'hosts', 'name', $host );
	if ( @services && $host ) {
	    foreach my $service (@services) {
		if ($service ne '') {
		    my %sn = StorProc->fetch_one( 'service_names', 'name', $service );
		    my %where = (
			'host_id'        => $h{'host_id'},
			'servicename_id' => $sn{'servicename_id'}
		    );
		    my %s = StorProc->fetch_one_where( 'services', \%where );
		    my @values = ( $svcgrp{'servicegroup_id'}, $h{'host_id'}, $s{'service_id'} );
		    my $result = StorProc->insert_obj( 'servicegroup_service', \@values );
		    if ( $result =~ /^Error/ && $result !~ /duplicate/i ) {
			push @errors, $result;
		    }
		}
	    }
	}
    }
    elsif ( $query->param('add_hosts') ) {
	my $service = $query->param('service');
	my @hosts   = $query->$multi_param('hosts');
	my %sn      = StorProc->fetch_one( 'service_names', 'name', $service );
	if ( @hosts && $service ) {
	    foreach my $host (@hosts) {
		if ($host ne '') {
		    my %h = StorProc->fetch_one( 'hosts', 'name', $host );
		    my %where = (
			'host_id'        => $h{'host_id'},
			'servicename_id' => $sn{'servicename_id'}
		    );
		    my %s = StorProc->fetch_one_where( 'services', \%where );
		    my @values = ( $svcgrp{'servicegroup_id'}, $h{'host_id'}, $s{'service_id'} );
		    my $result = StorProc->insert_obj( 'servicegroup_service', \@values );
		    if ( $result =~ /^Error/ && $result !~ /duplicate/i ) {
			push @errors, $result;
		    }
		}
	    }
	}
    }
    elsif ( $query->param('remove_service') ) {
	my $host    = $query->param('del_host');
	my $service = $query->param('del_service');
	my %h       = StorProc->fetch_one( 'hosts', 'name', $host );
	my %sn      = StorProc->fetch_one( 'service_names', 'name', $service );
	my %where   = (
	    'host_id'        => $h{'host_id'},
	    'servicename_id' => $sn{'servicename_id'}
	);
	my %s = StorProc->fetch_one_where( 'services', \%where );
	%where = (
	    'servicegroup_id' => $svcgrp{'servicegroup_id'},
	    'service_id'      => $s{'service_id'},
	    'host_id'         => $h{'host_id'}
	);
	my $result = StorProc->delete_one_where( 'servicegroup_service', \%where );
	if ( $result =~ /^Error/ ) { push @errors, $result }
    }
    elsif ( $query->param('save') ) {
	$notes = $query->param('notes');
	if (defined $notes) {
	    $notes = StorProc->sanitize_string_but_keep_newlines($notes);
	    $notes =~ s/\n/<br>/g;
	}
	my %values = ( 'alias' => $alias, 'notes' => $notes );
	my $escalation = $query->param('escalation');
	if ($escalation) {
	    my %esc = StorProc->fetch_one( 'escalation_trees', 'name', $escalation );
	    $values{'escalation_id'} = $esc{'tree_id'};
	}
	my $result = StorProc->update_obj( 'servicegroups', 'name', $name, \%values );
	if ( $result =~ /^Error/ ) { push @errors, $result }
	unless (@errors) {
	    $form .= Forms->header( $page_title, $session_id, $top_menu );
	    $form .= Forms->form_top('Service Group');
	    my @message = ("Changes to \"$name\" accepted.");
	    $form .= Forms->form_message( 'Updated:', \@message, 'row1' );
	    $form .= Forms->hidden( \%hidden );
	    $form .= Forms->form_bottom_buttons( \%continue, $tab++ );
	    $got_form = 1;
	}
    }
    elsif ( $query->param('rename') ) {
	$form .= rename_object( '', $name );
	$got_form = 1;
    }
    elsif ( $query->param('delete') || $query->param('confirm_delete') ) {
	if ( $query->param('confirm_delete') ) {
	    my $result = StorProc->delete_all( 'servicegroups', 'servicegroup_id', $svcgrp{'servicegroup_id'} );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	    unless (@errors) {
		$form .= Forms->header( $page_title, $session_id, $top_menu, '', '1' );
		$form .= Forms->form_top( 'Service Group Deleted', '' );
		my @message = ("$name");
		$form .= Forms->form_message( 'Removed:', \@message, 'row1' );
		$form .= Forms->hidden( \%hidden );
		$form .= Forms->form_bottom_buttons( \%continue, $tab++ );
		$name     = undef;
		$got_form = 1;
	    }
	}
	elsif ( defined( $query->param('task') ) && $query->param('task') eq 'No' ) {
	    $got_form = 0;
	}
	else {
	    foreach my $name ( $query->param ) {
		$hidden{$name} = $query->param($name);
	    }
	    delete $hidden{'task'};
	    $hidden{'delete'} = 1;
	    $form .= Forms->header( $page_title, $session_id, $top_menu );
	    my $message = qq(Are you sure you want to remove \"$name\"?);
	    $form .= Forms->are_you_sure( 'Confirm Delete', $message, 'confirm_delete', \%hidden );
	    $name     = undef;
	    $got_form = 1;
	}
    }
    unless ($got_form) {
	my $host       = $query->param('host');
	my $service    = $query->param('service');
	my $escalation = $query->param('escalation');
	unless ($escalation) {
	    my %esc = StorProc->fetch_one( 'escalation_trees', 'tree_id', $svcgrp{'escalation_id'} );
	    $escalation = $esc{'name'};
	}
	$form .= Forms->header( $page_title, $session_id, $top_menu );
	# Force validation of the service group name field (implicit within Validation).
	$form .= Validation->dfv_profile_javascript({});
	$form .= &$Instrument::show_trace_as_html_comment();
	$form .= Forms->form_top( "Service Group", Validation->dfv_onsubmit_javascript(
	    "if (this.clicked.match(/^(delete|rename)\$/)) { return true; }"
	) );
	if (@errors) { $form .= Forms->form_errors( \@errors ) }
	$form .= Forms->display_hidden( 'Service group name:', 'name', $name );
	$form .= Forms->text_box( 'Alias:', 'alias', $alias, $textsize{'alias'}, $required{'alias'}, $docs{'alias'}, '', $tab++ );
	$notes =~ s/<br>/\n/ig if defined $notes;
	my $lines = (( () = split( /\n/, (defined($notes) ? $notes : ''), 20 ) ) || 1) + 1;
	$form .= Forms->text_area( 'Notes:', 'notes', $notes, $lines, '74%', '', $docs{'notes'}, '', $tab++ );
	my %host_service       = defined( $svcgrp{'servicegroup_id'} ) ? StorProc->get_servicegroup( $svcgrp{'servicegroup_id'} ) : ();
	my %h                  = StorProc->fetch_one( 'hosts', 'name', $host );
	my @host_nonmembers    = defined( $h{'host_id'} ) ? StorProc->get_host_services( $h{'host_id'} ) : ();
	my @hosts              = sort StorProc->fetch_list( 'hosts', 'name' );
	my %s                  = StorProc->fetch_one( 'service_names', 'name', $service );
	my @service_nonmembers = defined( $s{'servicename_id'} ) ? StorProc->get_service_hosts( $s{'servicename_id'} ) : ();
	my @services           = sort StorProc->fetch_list( 'service_names', 'name' );
	$form .= Forms->service_group( $session_id, $view, $name, \%host_service, $host, \@host_nonmembers, \@hosts,
	    $service, \@service_nonmembers, \@services, $tab++ );
	my %where = ( 'type' => 'service' );
	my @serviceesc = StorProc->fetch_list_where( 'escalation_trees', 'name', \%where );
	$form .= Forms->list_box_submit( 'Service escalation tree:',
	    'escalation', \@serviceesc, $escalation, '', $docs{'service_escalation_tree'}, $tab++ );

	if ($escalation) {
	    my ( $ranks, $templates ) = StorProc->get_tree_detail($escalation);
	    my %ranks     = %{$ranks};
	    my %templates = %{$templates};
	    $form .= Forms->escalation_tree( \%ranks, \%templates, 'escalations' );
	}
	$form .= Forms->hidden( \%hidden );
	$help{url} = StorProc->doc_section_url('How+to+configure+notifications+using+Nagios', 'HowtoconfigurenotificationsusingNagios-ConfiguringHostGroupsandServiceGroups');
	if ( $auth_delete{'servicegroups'} ) {
	    $form .= Forms->form_bottom_buttons( \%save, \%delete, \%rename, \%help, $tab++ );
	}
	else {
	    $form .= Forms->form_bottom_buttons( \%save, \%rename, \%help, $tab++ );
	}
    }
    return $form;
}

#
############################################################################
# Host Wizard
#

sub host_wizard() {
    my $service_next = undef;
    my $form         = undef;
    my $test_results = undef;
    my $name         = $query->param('name');
    $name =~ s/^\s+|\s+$//g if defined $name;
    my $host = $query->param('host');
    $hidden{'name'} = $name;
    my %service_detail = ();
    $service_detail{'service'}      = $query->param('service');
    $service_detail{'notes'}        = $query->param('notes');
    $service_detail{'template'}     = $query->param('template');
    $service_detail{'inherit'}      = $query->param('inherit');
    $service_detail{'command'}      = $query->param('command');
    $service_detail{'command_line'} = $query->param('command_line');
    $service_detail{'dependency'}   = $query->param('dependency');
    $service_detail{'ext_info'}     = $query->param('ext_info');
    $service_detail{'escalation'}   = $query->param('escalation');
    $service_detail{'command_save'} = $query->param('command_save');
    if (defined $service_detail{'notes'}) {
	$service_detail{'notes'} = StorProc->sanitize_string_but_keep_newlines($service_detail{'notes'});
	$service_detail{'notes'} =~ s/\n/<br>/g;
    }
    $service_detail{'externals_arguments'} = $query->param('externals_arguments');
    $service_detail{'inherit_ext_args'}    = $query->param('inherit_ext_args');
    %properties = StorProc->fetch_one( 'hosts', 'name', $name );
    my %profile    = StorProc->fetch_one( 'profiles_host', 'hostprofile_id', $properties{'hostprofile_id'} );
    my $step       = $query->param('step');
    my @profiles   = ();
    my @services   = ();
    my %param_vals = ();

    #
    ##########################################################################
    # Check for existing session
    #
    unless ($step) {
	if ( $query->param('yes') ) {
	    my %where = ( 'user_acct' => $session_id, 'type' => 'wizard_design' );
	    my %host = StorProc->fetch_one_where( 'stage_hosts', \%where );
	    # FIX MINOR:  status used to be 'edit_added', not '0'; do we need an enumeration?  is '0' the right value here?
	    %where = (
		'host'      => $name,
		'user_acct' => $session_id,
		'type'      => $view,
		'status'    => '0'
	    );
	    my %service_list = StorProc->fetch_list_hash_array( 'stage_host_services', \%where );
	    my @services = ();
	    foreach my $svc ( keys %service_list ) {
		unless ( $svc =~ /HASH/ ) { push @services, $svc }
	    }
	    @services     = sort @services;
	    $service_next = pop @services;
	    $step         = $host{'info'};
	    if ($service_next) {
		my %where = (
		    'host'      => $name,
		    'user_acct' => $session_id,
		    'type'      => $view,
		    'status'    => '3'
		);
		my %service = StorProc->fetch_one_where( 'stage_host_services', \%where );
		%where = ( 'service_id' => $service{'service_id'} );
		my $result = StorProc->delete_all( 'services', 'service_id', $service{'service_id'} );
		if ( $result =~ /^Error/ ) { push @errors, $result }
		$step = 'service_detail';
	    }
	}
	elsif ( $query->param('no') ) {
	    my $result = StorProc->delete_all( 'hosts', 'name', $name );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	    my %where = ( 'name' => $name, 'user_acct' => $session_id );
	    $result = StorProc->delete_one_where( 'stage_hosts', \%where );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	    %where = ( 'host' => $name, 'user_acct' => $session_id );
	    $result = StorProc->delete_one_where( 'stage_host_services', \%where );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	    $step = 'host_vitals';
	}
	else {
	    my %where = ( 'user_acct' => $session_id, 'type' => 'wizard_design' );
	    my %host = StorProc->fetch_one_where( 'stage_hosts', \%where );
	    if ( $host{'name'} ) {
		$hidden{'name'} = $host{'name'};
		my %h = StorProc->fetch_one( 'hosts', 'name', $host{'name'} );
		$hidden{'host_id'}         = $h{'host_id'};
		$hidden{'host_profile'}    = $host{'hostprofile'};
		$hidden{'service_profile'} = $host{'service_profile'};
		$form .= Forms->header( $page_title, $session_id, $top_menu );
		$form .= Validation->dfv_profile_javascript();
		$form .= &$Instrument::show_trace_as_html_comment();
		$form .= Forms->form_top( 'New Host Wizard', Validation->dfv_onsubmit_javascript() );
		my $message =
qq(An existing host wizard session exists for $host{'name'}. Do you wish to continue with this host definition? (No will delete the host.)&nbsp;);
		$form .= Forms->form_doc($message);
		$form .= Forms->hidden( \%hidden );
		$form .= Forms->form_bottom_buttons( \%yes, \%no, $tab++ );
	    }
	    else {
		$step = 'host_vitals';
	    }
	}
    }
    ##########################################################################
    # Test command
    #
    elsif ( $query->param('test_command') ) {
	my $arg_string = $query->param('command_line');
	my $command    = $query->param('command');
	my %cmd        = StorProc->fetch_one( 'commands', 'name', $command );
	$test_results .=
	  StorProc->test_command( $command, $cmd{'command_line'}, $name, $arg_string, $monarch_home, $service_detail{'service'}, $nagios_ver );
    }
    ######################################################################
    # Save as profile
    #
    elsif ( $query->param('save_as_profile') ) {
	$step = 'save_as_profile';
    }
    elsif ( $query->param('save') ) {
	my $host_profile    = $query->param('host_profile');
	my $service_profile = $query->param('service_profile');
	if ( $service_profile && $host_profile ) {
	    my %h = StorProc->fetch_one( 'profiles_host',    'name', $host_profile );
	    my %s = StorProc->fetch_one( 'profiles_service', 'name', $service_profile );
	    if ( $h{'name'} ) {
		push @errors, "Duplicate: Host profile name \"$host_profile\" is already in use.";
	    }
	    if ( $s{'name'} ) {
		push @errors, "Duplicate: Service profile name \"$service_profile\" is already in use.";
	    }
	    unless (@errors) {
		$service_profile =~ s/^\s+|\s+$//g;
		$host_profile    =~ s/^\s+|\s+$//g;
		my $data       = "<?xml version=\"1.0\" encoding=\"iso-8859-1\" ?>\n<data>\n</data>";
		my %host       = StorProc->fetch_one( 'hosts', 'name', $name );
		my %w          = ( 'host_id' => $host{'host_id'} );
		my @hostgroups = StorProc->fetch_list_where( 'hostgroup_host', 'hostgroup_id', \%w );
		my @parents    = StorProc->fetch_list_where( 'host_parent', 'parent_id', \%w );
		my @services   = StorProc->fetch_list_where( 'services', 'servicename_id', \%w );
		my @sids       = StorProc->fetch_list_where( 'services', 'service_id', \%w );
		my @values     = ( \undef, $service_profile, "saved from host wizard by $session_id", $data );
		my $spid       = StorProc->insert_obj_id( 'profiles_service', \@values, 'serviceprofile_id' );
		if ( $spid =~ /^Error/ ) { push @errors, $spid }

		unless (@errors) {
		    foreach my $snid (@services) {
			@values = ( $snid, $spid );
			my $result = StorProc->insert_obj( 'serviceprofile', \@values );
			if ( $result =~ /^Error/ ) { push @errors, $result }
		    }
		}
		unless (@errors) {
		    @values = (
			\undef, $host_profile,
			"saved from host wizard by $user_acct",
			$host{'hosttemplate_id'},
			$host{'hostextinfo_id'},
			$host{'host_escalation_id'},
			$host{'service_escalation_id'}, $data
		    );
		    my $id = StorProc->insert_obj_id( 'profiles_host', \@values, 'hostprofile_id' );
		    @values = ( $id, $spid );
		    my $result = StorProc->insert_obj( 'profile_host_profile_service', \@values );
		    if ( $result =~ /^Error/ ) { push @errors, $result }
		    foreach my $hgid (@hostgroups) {
			@values = ( $id, $hgid );
			my $result = StorProc->insert_obj( 'profile_hostgroup', \@values );
			if ( $result =~ /^Error/ ) { push @errors, $result }
		    }
		    foreach my $hid (@parents) {
			@values = ( $id, $hid );
			my $result = StorProc->insert_obj( 'profile_parent', \@values );
			if ( $result =~ /^Error/ ) { push @errors, $result }
		    }
		    my %w = ( 'host_id'        => $properties{'host_id'} );
		    my %u = ( 'hostprofile_id' => $id );
		    $result = StorProc->update_obj_where( 'hosts', \%u, \%w );
		    if ( $result =~ /^Error/ ) { push @errors, $result }
		}
	    }
	}
	else {
	    push @errors, "Required host profile name, service profile name.";
	}
	if (@errors) {
	    my $result = StorProc->delete_all( 'profiles_host', 'name', $host_profile );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	    $result = StorProc->delete_all( 'profiles_service', 'name', $service_profile );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	    $step = 'save_as_profile';
	}
	else {
	    $step = 'saved';
	}
    }
    elsif ( $query->param('bail') ) {
	$step = 'host_vitals';
	$name = undef;
    }
    ######################################################################
    # Back
    #
    elsif ( $query->param('back') ) {
	if ( $step eq 'host_attribs' ) {
	    $step = 'host_vitals';
	    %properties = StorProc->fetch_one( 'stage_hosts', 'name', $name );
	    my $result = StorProc->delete_all( 'stage_hosts', 'name', $name );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	    $result = StorProc->delete_all( 'hosts', 'name', $name );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	}
	elsif ( $step eq 'host_attribs2' ) {
	    $step = 'host_attribs';
	    my %values = ( 'info' => $step );
	    my $result = StorProc->update_obj( 'stage_hosts', 'name', $name, \%values );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	}
	elsif ( $step eq 'service_list' ) {
	    $step = 'host_attribs2';
	    my $result = StorProc->delete_all( 'stage_host_services', 'host', $name );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	    my %values = ( 'info' => $step );
	    $result = StorProc->update_obj( 'stage_hosts', 'name', $name, \%values );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	}
	elsif ( $step eq 'service_detail' ) {
	    my %values = (
		'user_acct' => $session_id,
		'status'    => '3',
		'type'      => $view,
		'host'      => $name
	    );
	    my %service_list = StorProc->fetch_list_hash_array( 'stage_host_services', \%values );
	    my @services = ();
	    foreach my $svc ( keys %service_list ) {
		unless ( $svc =~ /HASH/ ) { push @services, $svc }
	    }
	    @services     = sort @services;
	    $service_next = pop @services;
	    if ($service_next) {
		$step = 'service_detail';
		my %where = (
		    'host'      => $name,
		    'user_acct' => $session_id,
		    'name'      => $service_next
		);
		my %service_stage = StorProc->fetch_one_where( 'stage_host_services', \%where );
		my $sid           = $service_stage{'service_id'};
		my $result        = StorProc->delete_all( 'services', 'service_id', $service_stage{'service_id'} );
		if ( $result =~ /^Error/ ) { push @errors, $result }
		# FIX MINOR:  status used to be 'edit', not '2'; do we need an enumeration?  is '2' the right value here?
		my %values = ( 'service_id' => '', 'status' => '2' );
		$result = StorProc->update_obj( 'stage_host_services', 'service_id', $service_stage{'service_id'}, \%values );
		if ( $result =~ /^Error/ ) { push @errors, $result }
	    }
	    else {
		$step = 'service_list';
		my @sids = StorProc->fetch_unique( 'stage_host_services', 'service_id', 'host', $name );
		foreach my $sid (@sids) {
		    my $result = StorProc->delete_all( 'services', 'service_id', $sid );
		    if ( $result =~ /^Error/ ) { push @errors, $result }
		}
		my $result = StorProc->delete_all( 'stage_host_services', 'host', $name );
		if ( $result =~ /^Error/ ) { push @errors, $result }
	    }
	}
    }
    #########################################################################
    # Continue
    #
    elsif ( $query->param('continue') ) {
	$step = 'host_vitals';
    }
    #########################################################################
    # Cancel
    #
    elsif ( $query->param('cancel') ) {
	if ( $step eq 'host_vitals' ) {
	    $step = '';
	    $form .= Forms->header( $page_title, $session_id, $top_menu );
	}
	else {
	    if ( $query->param('yes') ) {
		$step = 'host_vitals';
		%properties = StorProc->fetch_one( 'stage_hosts', 'name', $name );
		my $result = StorProc->delete_all( 'hosts', 'name', $name );
		if ( $result =~ /^Error/ ) { push @errors, $result }
		my %where = ( 'name' => $properties{'name'}, 'user_acct' => $session_id );
		$result = StorProc->delete_one_where( 'stage_hosts', \%where );
		if ( $result =~ /^Error/ ) { push @errors, $result }
		%where = ( 'host' => $properties{'name'}, 'user_acct' => $session_id );
		$result = StorProc->delete_one_where( 'stage_host_services', \%where );
		if ( $result =~ /^Error/ ) { push @errors, $result }
		unless (@errors) { %properties = () }
	    }
	    elsif ( $query->param('no') ) {
		## do nothing
	    }
	    else {
		foreach my $name ( $query->param ) {
		    unless ( $name eq 'task'
			|| $name eq 'nocache'
			|| $name eq 'parents'
			|| $name eq 'hostgroups' )
		    {
			$hidden{$name} = $query->param($name);
		    }
		}
		$form .= Forms->header( $page_title, $session_id, $top_menu );
		$form .= Validation->dfv_profile_javascript();
		$form .= &$Instrument::show_trace_as_html_comment();
		$form .= Forms->form_top( 'New Host Wizard', Validation->dfv_onsubmit_javascript() );
		my $message = qq(Are you sure you want to remove host \"$name\"?);
		$form .= Forms->form_doc($message);

		my @parents = $query->$multi_param('parents');
		foreach my $parent (@parents) {
		    my %hide = ( 'parents' => $parent );
		    $form .= Forms->hidden( \%hide );
		}

		my @hostgroups = $query->$multi_param('hostgroups');
		foreach my $hostgroup (@hostgroups) {
		    my %hide = ( 'hostgroups' => $hostgroup );
		    $form .= Forms->hidden( \%hide );
		}

		$form .= Forms->hidden( \%hidden );
		$form .= Forms->form_bottom_buttons( \%yes, \%no, $tab++ );
		$step = 'cancel';
	    }
	}
    }
    ##########################################################################
    # Next
    #
    elsif ( $query->param('next') ) {
	if ( $step eq 'host_vitals' ) {
	    $submit = 'Add';
	    my %data = parse_query( 'hosts', 'hosts' );
	    my $field_ck = check_fields();
	    if ( $field_ck == 0 ) {
		my $host_profile = $query->param('host_profile');
		$data{'status'} = 1;
		if (defined $data{'notes'}) {
		    # FIX MAJOR NOW:  this editing is probably no longer needed
		    $data{'notes'} = StorProc->sanitize_string_but_keep_newlines($data{'notes'});
		    $data{'notes'} =~ s/\n/<br>/g;
		}
		my @values      = ();
		my $primary_key = \undef;
		push @values, $primary_key;
		my @data_cols = split( /,/, $db_values{$obj} );
		foreach my $val (@data_cols) {
		    $val =~ s/^\s+|\s+$//g;
		    push @values, $data{$val};
		}
		my $id = StorProc->insert_obj_id( 'hosts', \@values, 'host_id' );
		if ( $id =~ /^Error/ ) { push @errors, $id }
		%properties = StorProc->fetch_one( 'hosts',         'name', $name );
		%profile    = StorProc->fetch_one( 'profiles_host', 'name', $host_profile );

		$hidden{'host_id'} = $id;
		# FIX MINOR:  status used to be 'incomplete', not '0'; do we need an enumeration?  is '0' the right value here?
		@values = (
		    $name,       $session_id,   'wizard_design', '0',            $data{'alias'}, $data{'address'},
		    $data{'os'}, $host_profile, '',              'host_attribs', $data{'notes'}
		);
		my $result = StorProc->insert_obj( 'stage_hosts', \@values );
		if ( $result =~ /^Error/ ) { push @errors, $result }

		if ( $profile{'hostprofile_id'} ) {
		    my %w = ( 'hostprofile_id' => $profile{'hostprofile_id'} );
		    my @externals = StorProc->fetch_list_where( 'external_host_profile', 'external_id', \%w );
		    foreach my $ext (@externals) {
			my %e = StorProc->fetch_one( 'externals', 'external_id', $ext );
			my @vals = ( $ext, $id, $e{'display'}, $DEFINED_REF );
			$result = StorProc->insert_obj( 'external_host', \@vals );
			if ( $result =~ /^Error/ ) { push @errors, $result }
		    }
		}
		if ( $profile{'hostprofile_id'} ) {
		    my @hosts = ($id);
		    my @errs = StorProc->host_profile_apply( $profile{'hostprofile_id'}, \@hosts );
		    if (@errs) { push( @errors, @errs ) }
		}
	    }
	    $step = 'host_attribs';
	    if ( @errors || $field_ck == 1 ) {
		$step = 'host_vitals';
	    }
	}
	elsif ( $step eq 'host_attribs' ) {
	    $step = 'host_attribs2';
	    my %values   = ();
	    my $template = $query->param('host_template');
	    my %w        = ( 'name' => $template );
	    my %t        = StorProc->fetch_one_where( 'host_templates', \%w );
	    $values{'hosttemplate_id'} = $t{'hosttemplate_id'};
	    my @parents = $query->$multi_param('parents');
	    if ( !$values{'hosttemplate_id'} ) {
		$required{'host_template'} = 1;
		push @errors, "Required: host template.";
	    }
	    foreach my $parent (@parents) {
		if ( $parent eq $name ) {
		    push @errors, "A host cannot be its own parent.";
		    last;
		}
	    }
	    unless (@errors) {
		my $result = StorProc->update_obj( 'hosts', 'host_id', $properties{'host_id'}, \%values );
		if ( $result =~ /^Error/ ) { push @errors, $result }
		%values = (
		    'serviceprofile' => $hidden{'service_profile'},
		    'info'           => $step
		);
		$result = StorProc->update_obj( 'stage_hosts', 'name', $name, \%values );
		if ( $result =~ /^Error/ ) { push @errors, $result }
		$result = StorProc->delete_all( 'host_parent', 'host_id', $properties{'host_id'} );
		if ( $result =~ /^Error/ ) { push @errors, $result }
		foreach my $parent (@parents) {
		    if ( !$parent ) { next }
		    my %p = StorProc->fetch_one( 'hosts', 'name', $parent );
		    my @values = ( $properties{'host_id'}, $p{'host_id'} );
		    my $result = StorProc->insert_obj( 'host_parent', \@values );
		    if ( $result =~ /^Error/ ) { push @errors, $result }
		}
	    }
	    if (@errors) {
		$step = 'host_attribs';
	    }
	}
	elsif ( $step eq 'host_attribs2' ) {
	    $step = 'service_list';
	    my %values        = ();
	    my @hostgroups    = $query->$multi_param('hostgroups');
	    my $coords2d      = StorProc->sanitize_string( scalar $query->param('coords2d') );
	    my $coords3d      = StorProc->sanitize_string( scalar $query->param('coords3d') );
	    my $extended_info = $query->param('extended_info');
	    my %w             = ( 'name' => $extended_info );
	    my %t             = StorProc->fetch_one_where( 'extended_host_info_templates', \%w );
	    $values{'hostextinfo_id'} = $t{'hostextinfo_id'};
	    my $host_escalation = $query->param('host_escalation');
	    %w = ( 'name' => $host_escalation, 'type' => 'host' );
	    %t = StorProc->fetch_one_where( 'escalation_trees', \%w );
	    $values{'host_escalation_id'} = $t{'tree_id'};
	    my $service_escalation = $query->param('service_escalation');
	    %w = ( 'name' => $service_escalation, 'type' => 'service' );
	    %t = StorProc->fetch_one_where( 'escalation_trees', \%w );
	    $values{'service_escalation_id'} = $t{'tree_id'};
	    $hidden{'service_profile'}       = $query->param('service_profile');

	    unless (@errors) {
		my $result = StorProc->update_obj( 'hosts', 'host_id', $properties{'host_id'}, \%values );
		if ( $result =~ /^Error/ ) { push @errors, $result }
		%values = (
		    'serviceprofile' => $hidden{'service_profile'},
		    'info'           => $step
		);
		$result = StorProc->update_obj( 'stage_hosts', 'name', $name, \%values );
		if ( $result =~ /^Error/ ) { push @errors, $result }
		$result = StorProc->delete_all( 'hostgroup_host', 'host_id', $properties{'host_id'} );
		if ( $result =~ /^Error/ ) { push @errors, $result }
		foreach my $hg (@hostgroups) {
		    if ( !$hg ) { next }
		    my %h = StorProc->fetch_one( 'hostgroups', 'name', $hg );
		    my @values = ( $h{'hostgroup_id'}, $properties{'host_id'} );
		    my $result = StorProc->insert_obj( 'hostgroup_host', \@values );
		    if ( $result =~ /^Error/ ) { push @errors, $result }
		}
		$result = StorProc->delete_all( 'extended_info_coords', 'host_id', $properties{'host_id'} );
		if ( $result =~ /^Error/ ) { push @errors, $result }
		my $data = '';
		if ( defined($coords2d) && $coords2d ne '' ) {
		    $coords2d =~ s{]]>}{]]]]><!\[CDATA\[>}g;
		    $data .= "\n  <prop name=\"2d_coords\"><![CDATA[$coords2d]]>\n  </prop>";
		}
		if ( defined($coords3d) && $coords3d ne '' ) {
		    $coords3d =~ s{]]>}{]]]]><!\[CDATA\[>}g;
		    $data .= "\n  <prop name=\"3d_coords\"><![CDATA[$coords3d]]>\n  </prop>";
		}
		if ($data) {
		    $data = "<?xml version=\"1.0\" encoding=\"iso-8859-1\" ?>\n<data>" . $data . "\n</data>";
		    my @vals = ( $properties{'host_id'}, $data );
		    $result = StorProc->insert_obj( 'extended_info_coords', \@vals );
		    if ( $result =~ /^Error/ ) { push @errors, $result }
		}
	    }
	    if (@errors) {
		$step = 'host_attribs2';
	    }
	}
	elsif ( $step eq 'service_list' ) {
	    my $result = StorProc->delete_all( 'services', 'host_id', $properties{'host_id'} );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	    $result = StorProc->delete_all( 'stage_host_services', 'host', $name );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	    foreach my $service ( $query->param ) {
		if ( $query->param($service) eq 'add' ) {
		    my %s = StorProc->fetch_one( 'service_names', 'name', $service );
		    my @values = (
			\undef,             $properties{'host_id'}, $s{'servicename_id'}, $s{'template'},
			$s{'extinfo'},      $s{'escalation'},       '1',                  $s{'check_command'},
			$s{'command_line'}, '',                     '',                   undef,
			'1'
		    );
		    my $id = StorProc->insert_obj_id( 'services', \@values, 'service_id' );
		    if ( $id =~ /^Error/ ) { push @errors, $id }
		    @values = ( $service, $session_id, $name, $view, '1', $id );
		    $result = StorProc->insert_obj( 'stage_host_services', \@values );
		    if ( $result =~ /^Error/ ) { push @errors, $result }
		    my %w = ( 'servicename_id' => $s{'servicename_id'} );
		    my @externals = StorProc->fetch_list_where( 'external_service_names', 'external_id', \%w );

		    foreach my $ext (@externals) {
			my %e = StorProc->fetch_one( 'externals', 'external_id', $ext );
			my @vals = ( $ext, $properties{'host_id'}, $id, $e{'display'}, $DEFINED_REF );
			$result = StorProc->insert_obj( 'external_service', \@vals );
			if ( $result =~ /^Error/ ) { push @errors, $result }
		    }
		    my @errs = StorProc->apply_service_overrides( $id, $s{'servicename_id'} );
		    if (@errs) { push( @errors, @errs ) }
		}
		elsif ( $query->param($service) eq 'edit' ) {
		    my @values = ( $service, $session_id, $name, $view, '2', '' );
		    my $result = StorProc->insert_obj( 'stage_host_services', \@values );
		    if ( $result =~ /^Error/ ) { push @errors, $result }
		}
	    }
	    $result = StorProc->delete_all( 'serviceprofile_host', 'host_id', $properties{'host_id'} );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	    my %profiles_name = StorProc->get_table_objects('profiles_service');
	    my @profiles      = $query->$multi_param('profiles');
	    foreach my $profile (@profiles) {
		if ( $profiles_name{$profile} ) {
		    my @values = ( $profiles_name{$profile}, $properties{'host_id'} );
		    my $result = StorProc->insert_obj( 'serviceprofile_host', \@values );
		    if ( $result =~ /^Error/ ) { push @errors, $result }
		}
	    }
	    my %values = (
		'user_acct' => $session_id,
		'status'    => '2',
		'type'      => $view,
		'host'      => $name
	    );
	    my %service_list = StorProc->fetch_list_hash_array( 'stage_host_services', \%values );
	    my @services;
	    foreach my $svc ( keys %service_list ) {
		unless ( $svc =~ /HASH/ ) { push @services, $svc }
	    }
	    # Reverse sort -- why?
	    @services = sort { $b cmp $a } @services;
	    $service_next = pop @services;
	    if ($service_next) {
		$step = 'service_detail';
	    }
	    else {
		$step = 'completed';
		my $result = StorProc->delete_all( 'stage_hosts', 'name', $name );
		if ( $result =~ /^Error/ ) { push @errors, $result }
		$result = StorProc->delete_all( 'stage_host_services', 'host', $name );
		if ( $result =~ /^Error/ ) { push @errors, $result }
	    }
	    if (@errors) {
		$step = 'service_list';
	    }
	}
	elsif ( $step eq 'service_detail' ) {
	    my %s = StorProc->fetch_one( 'service_names',     'name', $service_detail{'service'} );
	    my %t = StorProc->fetch_one( 'service_templates', 'name', $service_detail{'template'} );
	    my %c = StorProc->fetch_one( 'commands',          'name', $service_detail{'command'} );
	    my $command_line = $query->param('command_line');
	    if ( $service_detail{'inherit'} ) {
		delete $c{'command_id'};
		delete $service_detail{'command_line'};
	    }
	    my %x = StorProc->fetch_one( 'extended_service_info_templates', 'name', $service_detail{'ext_info'} );
	    my %e = StorProc->fetch_one( 'escalation_trees', 'name', $service_detail{'escalation'} );
	    my $externals_arguments = $service_detail{'externals_arguments'};

	    if ($enable_externals) {
		$externals_arguments = undef if defined($externals_arguments) && $externals_arguments eq '';
	    }

	    my $id;
	    my $result;
	    my @values = (
		\undef,                          $properties{'host_id'}, $s{'servicename_id'},     $t{'servicetemplate_id'},
		$x{'serviceextinfo_id'},         $e{'tree_id'},          '1',                      $c{'command_id'},
		$service_detail{'command_line'}, '',                     $service_detail{'notes'}, $externals_arguments,
		$service_detail{'inherit_ext_args'} || '00'
	    );
	    unless (@errors) {
		$id = StorProc->insert_obj_id( 'services', \@values, 'service_id' );
		if ( $id =~ /^Error/ ) { push @errors, $id }
	    }
	    unless (@errors) {
		my %where = (
		    'name'      => $service_detail{'service'},
		    'user_acct' => $session_id,
		    'host'      => $name
		);
		my %values = ( 'status' => '3', 'service_id' => $id );
		$result = StorProc->update_obj_where( 'stage_host_services', \%values, \%where );
		if ( $result =~ /^Error/ ) { push @errors, $result }
	    }
	    unless (@errors) {
		my %w = ( 'servicename_id' => $s{'servicename_id'} );
		my @externals = StorProc->fetch_list_where( 'external_service_names', 'external_id', \%w );
		foreach my $ext (@externals) {
		    my %e = StorProc->fetch_one( 'externals', 'external_id', $ext );
		    my @vals = ( $ext, $properties{'host_id'}, $id, $e{'display'}, $DEFINED_REF );
		    $result = StorProc->insert_obj( 'external_service', \@vals );
		    if ( $result =~ /^Error/ ) { push @errors, $result }
		}
	    }
	    unless (@errors) {
		my @errs = StorProc->apply_service_overrides( $id, $s{'servicename_id'} );
		if (@errs) { push( @errors, @errs ) }
	    }
	    if (@errors) {
		$step = 'service_detail';
	    }
	    else {
		delete $service_detail{'service'};
		delete $service_detail{'notes'};
		delete $service_detail{'template'};
		delete $service_detail{'inherit'};
		delete $service_detail{'command'};
		delete $service_detail{'command_line'};
		delete $service_detail{'dependency'};
		delete $service_detail{'ext_info'};
		delete $service_detail{'escalation'};
		delete $service_detail{'command_save'};
		delete $service_detail{'use_template_command'};
		delete $service_detail{'externals_arguments'};
		delete $service_detail{'inherit_ext_args'};
		my %values = (
		    'user_acct' => $session_id,
		    'status'    => '2',
		    'type'      => $view,
		    'host'      => $name
		);
		my %service_list = StorProc->fetch_list_hash_array( 'stage_host_services', \%values );
		my @services;
		foreach my $svc ( keys %service_list ) {
		    unless ( $svc =~ /HASH/ ) { push @services, $svc }
		}
		# FIX LATER:  Reverse sort -- why?
		@services = sort { $b cmp $a } @services;
		$service_next = pop @services;
		if ($service_next) {
		    $step = 'service_detail';
		}
		else {
		    $step = 'completed';
		    my $result = StorProc->delete_all( 'stage_hosts', 'name', $name );
		    if ( $result =~ /^Error/ ) { push @errors, $result }
		    $result = StorProc->delete_all( 'stage_host_services', 'host', $name );
		    if ( $result =~ /^Error/ ) { push @errors, $result }
		}
	    }
	}
    }
    elsif ( $query->param('add_profile') || $query->param('add_service') ) {
	$step = 'service_list';
    }
    if ( defined($step) && $step eq 'completed' ) {
	## insert service dependencies
	my $result = StorProc->add_dependencies( $properties{'host_id'} );
	if ( $result =~ /^Error/i ) { push @errors, $result }
    }

    ##########################################################################
    # Pages
    #
    $hidden{'step'} = $step;
    if (defined $step) {
	if ( $step eq 'host_vitals' ) {
	    $form .= Forms->header( $page_title, $session_id, $top_menu );
	    my %docs = Doc->host_wizard_vitals();
	    delete $hidden{'name'};
	    delete $hidden{'host'};
	    $form .= Validation->dfv_profile_javascript();
	    $form .= &$Instrument::show_trace_as_html_comment();
	    $form .= Forms->form_top( 'New Host Wizard', Validation->dfv_onsubmit_javascript(
		"if (this.clicked == 'cancel') { return true; }"
	    ) );
	    if ( !$properties{'host_profile'} ) {
		$properties{'host_profile'} = $query->param('host_profile');
	    }
	    if (@errors) { $form .= Forms->form_errors( \@errors ) }
	    $form .= Forms->wizard_doc('Host Vitals', undef, undef, 1);
	    $form .= Forms->text_box( 'Host name:', 'name', $properties{'name'}, $textsize{'name'}, $required{'name'}, '', '', $tab++ );
	    $form .= Forms->text_box( 'Alias:', 'alias', $properties{'alias'}, $textsize{'alias'}, $required{'alias'}, $docs{'alias'}, '', $tab++ );
	    $form .=
	      Forms->text_box( 'Address:', 'address', $properties{'address'}, $textsize{'address'}, $required{'address'}, $docs{'address'}, '',
		$tab++ );
	    my $notes = $properties{'notes'};
	    $notes =~ s/<br>/\n/ig if defined $notes;
	    my $lines = (( () = split( /\n/, (defined($notes) ? $notes : ''), 20 ) ) || 1) + 1;
	    $form .= Forms->text_area( 'Notes:', 'notes', $notes, $lines, '74%', '', $docs{'notes'}, '', $tab++ );
	    $form .= Forms->wizard_doc( 'Host Profile', undef, undef, 1 );
	    my @profiles = StorProc->fetch_list( 'profiles_host', 'name' );
	    $form .= Forms->list_box(
		'Host profile:',
		'host_profile', \@profiles,
		$properties{'host_profile'},
		$required{'host_profile'},
		$docs{'host_profile'}, '', $tab++
	    );
	    $form .= Forms->hidden( \%hidden );
	    $help{url} = StorProc->doc_section_url('How+to+manage+hosts', 'Howtomanagehosts-CreatingahostusingtheNewHostWizard');
	    $form .= Forms->form_bottom_buttons( \%next, \%cancel, \%help, $tab++ );
	}
	elsif ( $step eq 'host_attribs' ) {
	    $form .= Forms->header( $page_title, $session_id, $top_menu );
	    my %docs     = Doc->host_wizard_attribs_1();
	    my %w        = ( 'hosttemplate_id' => $properties{'hosttemplate_id'} );
	    my %t        = StorProc->fetch_one_where( 'host_templates', \%w );
	    my $template = $t{'name'};
	    unless ($template) {
		my %w = ( 'hosttemplate_id' => $profile{'host_template_id'} );
		my %t = StorProc->fetch_one_where( 'host_templates', \%w );
		$template = $t{'name'};
	    }
	    my @parents = StorProc->get_host_parent( $properties{'host_id'} );
	    unless (@parents or not defined $profile{'hostprofile_id'}) {
		@parents = StorProc->get_profile_parent( $profile{'hostprofile_id'} );
	    }
	    $form .= Validation->dfv_profile_javascript();
	    $form .= &$Instrument::show_trace_as_html_comment();
	    $form .= Forms->form_top( 'New Host Wizard', Validation->dfv_onsubmit_javascript('selIt()') );
	    if (@errors) { $form .= Forms->form_errors( \@errors ) }
	    $form .= Forms->wizard_doc('Host Properties 1', undef, undef, 1);
	    $form .= Forms->display_hidden( 'Host name:', 'name', $name );
	    $form .= Forms->wizard_doc( 'Host Template', undef, undef, 1 );
	    my @members = StorProc->fetch_list( 'host_templates', 'name' );
	    $form .= Forms->list_box(
		'Host template:',
		'host_template', \@members, $template, $required{'host_template'},
		$docs{'host_template'}, '', $tab++
	    );
	    $form .= Forms->wizard_doc( 'Parents', undef, undef, 1 );
	    my @nonmembers = StorProc->fetch_list( 'hosts', 'name' );
	    foreach my $index ( 0 .. $#nonmembers ) {
		if ( $nonmembers[$index] eq $name ) {
		    splice( @nonmembers, $index, 1 );
		    last;
		}
	    }
	    $form .= Forms->members( 'Parents:', 'parents', \@parents, \@nonmembers, '', 20, $docs{'parents'}, '', $tab++ );
	    $form .= Forms->hidden( \%hidden );
	    $help{url} = StorProc->doc_section_url('How+to+manage+hosts', 'Howtomanagehosts-HostProperties1');
	    $form .= Forms->form_bottom_buttons( \%back, \%next, \%cancel, \%help, $tab++ );
	}
	elsif ( $step eq 'host_attribs2' ) {
	    $form .= Forms->header( $page_title, $session_id, $top_menu );
	    my %docs          = Doc->host_wizard_attribs_2();
	    my $coords2d      = StorProc->sanitize_string( scalar $query->param('coords2d') );
	    my $coords3d      = StorProc->sanitize_string( scalar $query->param('coords3d') );
	    my $extended_info = $query->param('extended_info');
	    unless ($extended_info) {
		my %w = ( 'hostextinfo_id' => $properties{'hostextinfo_id'} );
		my %t = StorProc->fetch_one_where( 'extended_host_info_templates', \%w );
		$extended_info = $t{'name'};
		my %coords = StorProc->fetch_one( 'extended_info_coords', 'host_id', $properties{'host_id'} );
		push @errors, delete $coords{'error'} if defined $coords{'error'};
		unless (defined($coords2d) && $coords2d ne '') { $coords2d = $coords{'2d_coords'} }
		unless (defined($coords3d) && $coords3d ne '') { $coords3d = $coords{'3d_coords'} }
	    }
	    unless ($extended_info) {
		my %w = ( 'hostextinfo_id' => $profile{'host_extinfo_id'} );
		my %t = StorProc->fetch_one_where( 'extended_host_info_templates', \%w );
		push @errors, delete $t{'error'} if defined $t{'error'};
		$extended_info = $t{'name'};
		unless (defined($coords2d) && $coords2d ne '') { $coords2d = $t{'2d_coords'} }
		unless (defined($coords3d) && $coords3d ne '') { $coords3d = $t{'3d_coords'} }
	    }
	    my $host_escalation = $query->param('host_escalation');
	    unless ($host_escalation) {
		my %w = (
		    'tree_id' => $properties{'host_escalation_id'},
		    'type'    => 'host'
		);
		my %t = StorProc->fetch_one_where( 'escalation_trees', \%w );
		$host_escalation = $t{'name'};
	    }
	    unless ($host_escalation) {
		my %w = ( 'tree_id' => $profile{'host_escalation_id'}, 'type' => 'host' );
		my %t = StorProc->fetch_one_where( 'escalation_trees', \%w );
		$host_escalation = $t{'name'};
	    }
	    my $service_escalation = $query->param('service_escalation');
	    unless ($service_escalation) {
		my %w = (
		    'tree_id' => $properties{'service_escalation_id'},
		    'type'    => 'service'
		);
		my %t = StorProc->fetch_one_where( 'escalation_trees', \%w );
		$service_escalation = $t{'name'};
	    }
	    unless ($service_escalation) {
		my %w = (
		    'tree_id' => $profile{'service_escalation_id'},
		    'type'    => 'service'
		);
		my %t = StorProc->fetch_one_where( 'escalation_trees', \%w );
		$service_escalation = $t{'name'};
	    }
	    my @hostgroups = $query->$multi_param('hostgroups');
	    unless (@hostgroups) {
		@hostgroups = StorProc->get_host_hostgroups($name);
	    }
	    unless (@hostgroups or not defined $profile{'hostprofile_id'}) {
		@hostgroups = StorProc->get_profile_hostgroup( $profile{'hostprofile_id'} );
	    }
	    $form .= Validation->dfv_profile_javascript();
	    $form .= &$Instrument::show_trace_as_html_comment();
	    $form .= Forms->form_top( 'New Host Wizard', Validation->dfv_onsubmit_javascript('selIt()') );
	    if (@errors) { $form .= Forms->form_errors( \@errors ) }
	    $form .= Forms->wizard_doc('Host Properties 2', undef, undef, 1);
	    $form .= Forms->display_hidden( 'Host name:', 'name', $name );
	    my @nonmembers = StorProc->fetch_list( 'hostgroups', 'name' );
	    $form .= Forms->wizard_doc( 'Hostgroups', undef, undef, 1 );
	    $form .= Forms->members( 'Hostgroups:', 'hostgroups', \@hostgroups, \@nonmembers, '', '', $docs{'hostgroups'}, '', $tab++ );
	    $form .= Forms->wizard_doc( 'Escalation Trees', $docs{'escalations'}, undef, 1 );
	    my %where = ( 'type' => 'host' );
	    my @members = StorProc->fetch_list_where( 'escalation_trees', 'name', \%where );
	    $form .= Forms->list_box(
		'Host escalation tree:',
		'host_escalation', \@members, $host_escalation, '', $docs{'host_escalation_tree'},
		'', $tab++
	    );

	    if ($host_escalation) {
		my ( $ranks, $templates ) = StorProc->get_tree_detail($host_escalation);
		my %ranks     = %{$ranks};
		my %templates = %{$templates};
		$form .= Forms->escalation_tree( \%ranks, \%templates, 'escalations' );
	    }
	    %where = ( 'type' => 'service' );
	    @members = StorProc->fetch_list_where( 'escalation_trees', 'name', \%where );
	    $form .= Forms->list_box(
		'Service escalation tree:',
		'service_escalation', \@members, $service_escalation, '', $docs{'service_escalation_tree'},
		'', $tab++
	    );
	    if ($service_escalation) {
		my ( $ranks, $templates ) = StorProc->get_tree_detail($service_escalation);
		my %ranks     = %{$ranks};
		my %templates = %{$templates};
		$form .= Forms->escalation_tree( \%ranks, \%templates, 'escalations' );
	    }
	    $form .= Forms->wizard_doc( 'Additional Per-Host Options', undef, undef, 1 );
	    @members = StorProc->fetch_list( 'extended_host_info_templates', 'name' );
	    $form .= Forms->list_box( 'Extended host info:', 'extended_info', \@members, $extended_info, '', $docs{'extinfo'}, '', $tab++ );
	    $form .= Forms->text_box( '2d status map coords:', 'coords2d', $coords2d, '10', '', $docs{'coords2d'}, '', $tab++ );
	    $form .= Forms->text_box( '3d status map coords:', 'coords3d', $coords3d, '10', '', $docs{'coords3d'}, '', $tab++ );
	    $form .= Forms->hidden( \%hidden );
	    $help{url} = StorProc->doc_section_url('How+to+manage+hosts', 'Howtomanagehosts-HostProperties2');
	    $form .= Forms->form_bottom_buttons( \%back, \%next, \%cancel, \%help, $tab++ );
	}
	elsif ( $step eq 'service_list' ) {
	    $form .= Forms->header( $page_title, $session_id, $top_menu );
	    my %docs = Doc->host_wizard_select_services();
	    $form .= Validation->dfv_profile_javascript();
	    $form .= &$Instrument::show_trace_as_html_comment();
	    $form .= Forms->form_top( 'New Host Wizard', Validation->dfv_onsubmit_javascript() );
	    if (@errors) { $form .= Forms->form_errors( \@errors ) }
	    $form .= Forms->wizard_doc('Host Properties 3', undef, undef, 1);
	    $form .= Forms->display_hidden( 'Host name:', 'name', $name );
	    $form .= Forms->wizard_doc('Select Services', $docs{'services'}, undef, 1 );
	    my @profiles    = ();
	    my $got_profile = 0;
	    my %selected    = ();

	    if ( $query->param('back') ) {
		my %where = ( 'host' => $name, 'user_acct' => $session_id );
		my @services = StorProc->fetch_list_where( 'stage_host_services', 'name', \%where );
		foreach my $service (@services) { $selected{$service} = 'add' }
	    }
	    else {
		foreach my $service ( $query->param ) {
		    $service = uri_unescape($service);
		    if ( $query->param($service) eq 'add' ) {
			$selected{$service} = 'add';
		    }
		    elsif ( $query->param($service) eq 'edit' ) {
			$selected{$service} = 'edit';
		    }
		    elsif ( $query->param($service) eq 'discard' ) {
			$selected{$service} = 'discard';
		    }
		}
	    }
	    my %sp_selected    = ();
	    my $remove_profile = undef;
	    my @query_profiles = $query->$multi_param('profiles');
	    foreach my $profile (@query_profiles) {
		$got_profile = 1;
		if ( $query->param("remove_$profile") ) {
		    $profile        = uri_unescape($profile);
		    $remove_profile = $profile;
		}
		elsif ($profile) {
		    $profile = uri_unescape($profile);
		    push @profiles, $profile;
		}
	    }
	    unless ($got_profile or not defined $properties{'hostprofile_id'}) {
		my %sps = StorProc->get_host_profile_service_profiles( $properties{'hostprofile_id'} );
		foreach my $sp ( sort keys %sps ) { push @profiles, $sp }
	    }
	    $form .= Forms->profile_list( $session_id, $name, \@profiles );
	    my @query_services = $query->$multi_param('services');
	    foreach my $service (@query_services) {
		if ($service) { $selected{$service} = 'add' }
	    }
	    if ($remove_profile) {
		my %sp  = StorProc->fetch_one( 'profiles_service', 'name', $remove_profile );
		my %svs = StorProc->get_service_profile_services( $sp{'serviceprofile_id'} );
		foreach my $service ( keys %svs ) { delete $selected{$service} }
	    }
	    my %services = ();
	    foreach my $profile (@profiles) {
		$sp_selected{$profile} = 1;
		my %sp  = StorProc->fetch_one( 'profiles_service', 'name', $profile );
		my %svs = StorProc->get_service_profile_services( $sp{'serviceprofile_id'} );
		foreach my $service ( keys %svs ) {
		    $services{$service} = $svs{$service};
		    unless ( defined $selected{$service} ) {
			$selected{$service} = 'add';
		    }
		}
	    }
	    foreach my $service ( keys %selected ) {
		unless ( defined $services{$service} ) {
		    my %svc = StorProc->get_service_detail($service);
		    $services{$service} = $svc{$service};
		}
	    }
	    $form .= Forms->service_select( \%services, \%selected, $tab++ );
	    my @service_profiles = StorProc->fetch_list( 'profiles_service', 'name' );
	    my @profile_list = ();
	    foreach my $s (@service_profiles) {
		unless ( $sp_selected{$s} ) { push @profile_list, $s }
	    }
	    @profile_list = sort @profile_list;
	    $form .= Forms->add_service_profile( \@profile_list, $tab++ );

	    my @service_names = StorProc->fetch_list( 'service_names', 'name' );
	    my @service_list = ();
	    foreach my $s (@service_names) {
		unless ( $selected{$s} ) { push @service_list, $s }
	    }
	    @service_list = sort @service_list;
	    $form .= Forms->add_service( \@service_list, $tab++ );
	    $form .= Forms->hidden( \%hidden );
	    $help{url} = StorProc->doc_section_url('How+to+manage+hosts', 'Howtomanagehosts-SelectServices');
	    $form .= Forms->form_bottom_buttons( \%back, \%next, \%cancel, \%help, $tab++ );
	}
	elsif ( $step eq 'service_detail' ) {
	    $form .= Forms->header( $page_title, $session_id, $top_menu );
	    my %docs = Doc->host_wizard_service_detail();
	    # FIX THIS:  What is $hidden{'file'} being carried forward for?
	    $hidden{'file'} = $query->param('file');
	    my $service = $service_next;
	    unless ($service) { $service = $service_detail{'service'} }
	    my %svc     = StorProc->get_service_detail($service);
	    my %service = ();
	    foreach my $key ( keys %{ $svc{$service_next} } ) {
		if ( $key eq 'command' ) {
		    my @cmd = split( /!/, $svc{$service_next}{$key} );
		    $service{'check_command'} = $cmd[0];
		    $service{'command_line'}  = $svc{$service_next}{$key};
		}
		$service{$key} = $svc{$service_next}{$key};
	    }
	    $form .= Validation->dfv_profile_javascript();
	    $form .= &$Instrument::show_trace_as_html_comment();
	    $form .= Forms->form_top( 'New Host Wizard', Validation->dfv_onsubmit_javascript() );
	    if (@errors) { $form .= Forms->form_errors( \@errors ) }
	    $form .= Forms->wizard_doc('Service Detail', undef, undef, 1);
	    $form .= Forms->display_hidden( 'Host name:', 'name', $name );
	    $form .= Forms->display_hidden( 'Service name:', 'service', $service );

	    # FIX MAJOR (GWMON-13213):  if this host service has already been added to the database (i.e.,
	    # if we got here via the "<< Back" button), pull notes from there instead, so we have a sensible
	    # value.  The same thing goes for the command line and probably other fields as well.

	    my $notes = $service_detail{'notes'};
	    $notes =~ s/<br>/\n/ig if defined $notes;
	    my $lines = (( () = split( /\n/, (defined($notes) ? $notes : ''), 20 ) ) || 1) + 1;
	    $form .= Forms->text_area( 'Notes:', 'notes', $notes, $lines, '74%', '', $docs{'notes'}, '', $tab++ );

	    #
	    # Template
	    #
	    $form .= Forms->wizard_doc( 'Service Template', undef, undef, 1 );
	    my $template = $service_detail{'template'};
	    unless ($template) {
		$template = $service{'template'};
	    }
	    my @members = StorProc->fetch_list( 'service_templates', 'name' );
	    $form .= Forms->list_box_submit( 'Service template:', 'template', \@members, $template, '', $docs{'template'}, $tab++ );
	    my %template = StorProc->fetch_one( 'service_templates', 'name', $template );
	    my %generic = StorProc->fetch_one( 'service_names', 'name', $service );

	    #
	    # Service check
	    #

	    $form .= Forms->wizard_doc( 'Service Check', $docs{'service_check'}, undef, 1 );
	    my $message      = undef;
	    my %cmd          = StorProc->fetch_one( 'commands', 'name', $service{'check_command'} );
	    my $command      = $cmd{'name'};
	    my $command_save = $cmd{'name'};
	    my $command_line = $service{'command_line'};
	    if ( $service_detail{'command'} )      { $command      = $service_detail{'command'}; }
	    if ( $service_detail{'command_save'} ) { $command_save = $service_detail{'command_save'}; }
	    if ( $service_detail{'command_line'} ) { $command_line = $service_detail{'command_line'}; }

	    # If we are returning to this screen because of a change to the inheritance of the command,
	    # preserve what we had going in other parts of the screen as much as possible.  To do that,
	    # we check for "next" or "back", one of which is defined on an initial view of the screen,
	    # both of which are undefined in an inheritance-change refresh.
	    my $inherit;
	    my $inherit_ext_args;
	    my $externals_arguments;
	    ## FIX MINOR (GWMON-13213):  make the right assignments when we got here via "Back"
	    if ( !@errors && ( $query->param('next') || $query->param('back') ) ) {
		## FIX MINOR:  This resets completely, as happens for the command stuff as well.
		## This interaction should be made smoother on a "Back" operation.
		$inherit             = 1;
		$inherit_ext_args    = 1;
		$externals_arguments = undef;
	    }
	    else {
		$inherit             = $service_detail{'inherit'};
		$inherit_ext_args    = $query->param('inherit_ext_args');
		$externals_arguments = $inherit_ext_args ? $service_detail{'externals_arguments'} : $query->param('externals_arguments');
	    }

	    unless ( $command eq $command_save ) {
		%cmd = StorProc->fetch_one( 'commands', 'name', $command );
		$command_line = undef;
	    }
	    if ( $inherit or !$command ) {
		%cmd = StorProc->fetch_one( 'commands', 'command_id', $template{'check_command'} );
		if ( $cmd{'name'} ) {
		    $command      = $cmd{'name'};
		    $command_line = $template{'command_line'};
		    $inherit      = 1;
		}
		else {
		    my $got_command  = 0;
		    my $stid         = $template{'parent_id'};
		    my %already_seen = ();
		    until ($got_command) {
			my %t = StorProc->fetch_one( 'service_templates', 'servicetemplate_id', $stid );
			if ( $t{'check_command'} ) {
			    $got_command  = 1;
			    %cmd          = StorProc->fetch_one( 'commands', 'command_id', $t{'check_command'} );
			    $command      = $cmd{'name'};
			    $command_line = $t{'command_line'};
			}
			else {
			    $already_seen{$stid} = 1;
			    if ( $t{'parent_id'} ) {
				if ( $already_seen{ $t{'parent_id'} } ) {
				    $got_command = 1;
				    $message     = (
    "Note: no parent template (recursively) has a check command defined.<br><b><font color=#FF0000>ERROR:  You have a cyclical chain of parents in your service templates, starting with \"$t{'name'}\".</font></b>"
				    );
				    $required{'check_command'} = 1;
				    $command                   = undef;
				    $command_line              = undef;
				}
				else {
				    $stid = $t{'parent_id'};
				}
			    }
			    else {
				$got_command               = 1;
				$message                   = ('Note: no parent template (recursively) has a check command defined.');
				$required{'check_command'} = 1;
				$command                   = undef;
				$command_line              = undef;
			    }
			}
		    }
		}
	    }
	    %cmd = StorProc->fetch_one( 'commands', 'name', $command );
	    my $arg_string = $command_line;
	    $arg_string =~ s/$command!//;
	    my $usage = $command;
	    my @args = split( /\$ARG/i, $cmd{'command_line'} );
	    if (@args) {
		my $maxarg = 0;
		shift @args;    # drop command
		foreach (@args) {
		    if (/^(\d+)\$/) {
			$maxarg = $1 if $maxarg < $1;
		    }
		}
		my $args = $maxarg ? join( '!', map "ARG$_", 1 .. $maxarg ) : '';
		unless ( $command_line =~ /$command/ ) {
		    $command_line = "$command!$args";
		    $arg_string   = $args;
		}
		$usage .= "!$args";
	    }
	    $form .= Forms->checkbox_override( 'Inherit check from template:', 'inherit', $inherit, $docs{'use_template_command'}, $tab++ );
	    $form .= Forms->form_doc($message) if $message;
	    my %where = ( 'type' => 'check' );
	    my @commands = StorProc->fetch_list_where( 'commands', 'name', \%where );
	    $form .= Forms->list_box_submit( 'Check command:', 'command', \@commands, $command, $required{'check_command'},
	      $docs{'check_command'}, $tab++, $inherit );
	    $form .= Forms->display_hidden( 'Command definition:', '', HTML::Entities::encode( $cmd{'command_line'} ) );
	    $form .= Forms->display_hidden( 'Usage:', '', $usage );
	    $form .= Forms->text_area( 'Command line:', 'command_line', $command_line, '3', '80', '', $docs{'command_line'}, '', $tab++, undef, undef, $inherit );
	    unless ($host) { $host = $name }
	    $form .= Forms->test_service_check( $test_results, $host, '', $tab++ );
	    if ($enable_externals) {
		$form .= Forms->wizard_doc( 'Externals Macro Arguments (optional)', $docs{'macro_arguments'}, undef, 1 );

		$form .= Forms->js_toggle_input();
		$form .= Forms->checkbox(
		    'Inherit externals args:',
		    'inherit_ext_args', $inherit_ext_args, $docs{'inherit_ext_args'},
		    '', $tab++, undef, undef, 'externals_arguments', 'Inherit externals arguments from the generic service'
		);

		my $value  = ( $inherit_ext_args ? $generic{'externals_arguments'} : $externals_arguments )            // '';
		my $tvalue = ( $inherit_ext_args ? $externals_arguments            : $generic{'externals_arguments'} ) // '';
		$tvalue = $generic{'externals_arguments'} // '' if $tvalue eq '';

		$form .= Forms->text_area(
		    'Externals arguments:',
		    'externals_arguments', $value, '3', '80', '', $docs{'externals_arguments'},
		    '', $tab++, undef, $tvalue, $inherit_ext_args
		);

		# We also want to display any assigned externals.  But this host service has not yet been
		# created, so there aren't any yet.  About the best we can do is to instead display any
		# externals assigned to the generic service we are basing this nascent host service on,
		# that will later be assigned to the host service when it is finally created.

		my @service_external_ids =
		  StorProc->fetch_unique( 'external_service_names', 'external_id', 'servicename_id', $generic{'servicename_id'} );

		my %external_data = ();
		if (@service_external_ids) {
		    ## This loop assumes we have uniqueness of service external names.  That is
		    ## currently not enforced at the database level, but is within the Monarch UI.
		    foreach my $external_id ( @service_external_ids ) {
			my $one_external = StorProc->fetch_map_where( 'externals', 'name', 'display', { 'external_id' => $external_id } );
			@external_data{ keys %$one_external } = values %$one_external;
		    }
		}

		if (%external_data) {
		    my $nocache = time();
		    foreach my $external_name ( sort keys %external_data ) {
			my $external = $external_data{$external_name};
			$external =~ s/\n/<br>/g;
			# We must be careful here when linking to the service external editing screen, as it will be the
			# generic service external, not a later host service external (separate copy), and there is no
			# convenient link back to here.  Therefore, to avoid confusion, we don't make this an active link.
			# This is, after all, just a simplified-construction wizard.
			$form .= Forms->wizard_doc( $external_name, "<tt>$external</tt>" );
		    }
		    ## FIX MINOR:  add in a "Test Argument Substitution" button (see GWMON-13210)
		}
		else {
		    $form .= Forms->wizard_doc( undef, "The generic service behind this host service currently has no service externals assigned." );
		}
	    }
	    $hidden{'command_save'} = $command;

	    #
	    # dependency
	    #
	    $form .= Forms->wizard_doc( 'Service Dependency', $docs{'dependencies'}, undef, 1 );
	    my $dependency = $service_detail{'dependency'};
	    unless ($dependency) {
		$dependency = $service{'dependency'};
	    }
	    @members = StorProc->fetch_list( 'service_dependency_templates', 'name' );
	    $form .= Forms->list_box( 'Service dependency:', 'dependency', \@members, $dependency, '', $docs{'dependency'}, '', $tab++ );
	    my $ext_info = $service_detail{'ext_info'};
	    unless ($ext_info) {
		$ext_info = $service{'extinfo'};
	    }

	    $form .= Forms->wizard_doc( 'Additional Per-Host-Service Options', undef, undef, 1 );

	    #
	    # ext_info
	    #
	    @members = StorProc->fetch_list( 'extended_service_info_templates', 'name' );
	    $form .= Forms->list_box( 'Extended info template:', 'ext_info', \@members, $ext_info, '', $docs{'extinfo'}, '', $tab++ );

	    #
	    # escalation
	    #
	    my $escalation = $service_detail{'escalation'};
	    unless ($escalation) {
		$escalation = $service{'escalation'};
	    }
	    %where = ( 'type' => 'service' );
	    @members = StorProc->fetch_list_where( 'escalation_trees', 'name', \%where );
	    $form .= Forms->list_box_submit( 'Service escalation tree:',
		'escalation', \@members, $escalation, '', $docs{'service_escalation_tree'}, $tab++ );
	    if ($escalation) {
		my ( $ranks, $templates ) = StorProc->get_tree_detail($escalation);
		my %ranks     = %{$ranks};
		my %templates = %{$templates};
		$form .= Forms->escalation_tree( \%ranks, \%templates, 'service_detail' );
	    }
	    my @profiles = $query->$multi_param('profiles');
	    foreach my $profile (@profiles) {
		my %prof = ( 'profiles' => $profile );
		$form .= Forms->hidden( \%prof );
	    }
	    $form .= Forms->hidden( \%hidden );
	    $form .= Forms->form_bottom_buttons( \%back, \%next, \%cancel, $tab++ );
	}
	elsif ( $step eq 'completed' ) {
	    $form .= Forms->header( $page_title, $session_id, $top_menu );
	    $form .= Validation->dfv_profile_javascript();
	    $form .= &$Instrument::show_trace_as_html_comment();
	    $form .= Forms->form_top( 'New Host Wizard', Validation->dfv_onsubmit_javascript() );
	    if (@errors) { $form .= Forms->form_errors( \@errors ) }
	    $form .= Forms->display_hidden( 'Added host:', 'name', $name );
	    my @services = StorProc->get_host_services( $properties{'host_id'} );
	    $form .= Forms->form_message( 'Services:', \@services, 'row1' );
	    my %save_to_profile = ( 'name' => 'save_as_profile', 'value' => 'Save As Profile' );
	    $form .= Forms->hidden( \%hidden );
	    $help{url} = StorProc->doc_section_url('How+to+manage+hosts', 'Howtomanagehosts-SaveasProfile');
	    $form .= Forms->form_bottom_buttons( \%save_to_profile, \%continue, \%help, $tab++ );
	}
	elsif ( $step eq 'save_as_profile' ) {
	    $form .= Forms->header( $page_title, $session_id, $top_menu );
	    $form .= Validation->dfv_profile_javascript();
	    $form .= &$Instrument::show_trace_as_html_comment();
	    $form .= Forms->form_top( 'New Host Wizard', Validation->dfv_onsubmit_javascript() );
	    if (@errors) { $form .= Forms->form_errors( \@errors ) }
	    $form .= Forms->display_hidden( 'Host name:', 'name', $name );
	    $form .= Forms->text_box( 'Host profile name:',    'host_profile',    $name, '50', '', '', '', $tab++ );
	    $form .= Forms->text_box( 'Service profile name:', 'service_profile', $name, '50', '', '', '', $tab++ );
	    my %bail = ( 'name' => 'bail', 'value' => 'Cancel' );
	    $form .= Forms->hidden( \%hidden );
	    $form .= Forms->form_bottom_buttons( \%save, \%bail, $tab++ );
	}
	elsif ( $step eq 'saved' ) {
	    $form .= Forms->header( $page_title, $session_id, $top_menu );
	    $form .= Validation->dfv_profile_javascript();
	    $form .= &$Instrument::show_trace_as_html_comment();
	    $form .= Forms->form_top( 'New Host Wizard', Validation->dfv_onsubmit_javascript() );
	    if (@errors) { $form .= Forms->form_errors( \@errors ) }
	    $form .= Forms->display_hidden( 'Profile name:', 'name', $name );
	    $form .= Forms->hidden( \%hidden );
	    $form .= Forms->form_bottom_buttons( \%continue, $tab++ );
	}
    }
    return $form;
}

#
############################################################################
# Design
#

sub design() {
    local $_;

    my $page     = undef;
    my $got_form = undef;
    my $title    = undef;
    my @t_parse  = split( /_/, $obj );
    my %required = ();

    foreach (@t_parse) { $title .= "\u$_ " }
    if (   $query->param('cancel')
	|| $query->param('close')
	|| $query->param('continue') )
    {
	$page .= Forms->header( $page_title, $session_id, $top_menu );
	$got_form = 1;
    }
    else {
	##
	## Contacts
	##
	if ( $obj eq 'contacts' ) {
	    if ( $query->param('add') ) {
		my $name = $query->param('name');
		$name =~ s/^\s+|\s+$//g;
		$hidden{'name'} = $name;
		my %data = parse_query( 'contacts', 'contacts' );
		$properties{'template'} = $query->param('template');
		my $field_ck = check_fields();
		if ( $field_ck == 0 ) {
		    my %t = StorProc->fetch_one( 'contact_templates', 'name', $properties{'template'} );
		    my @vals = ( \undef, $name, $data{'alias'}, $data{'email'}, $data{'pager'}, $t{'contacttemplate_id'}, '1', '' );
		    my $id = StorProc->insert_obj_id( 'contacts', \@vals, 'contact_id' );
		    if ( $id =~ /^Error/ ) { push @errors, $id }
		    unless (@errors) {
			my @mems = $query->$multi_param('contactgroup');
			foreach (@mems) {
			    my %cg = StorProc->fetch_one( 'contactgroups', 'name', $_ );
			    my @vals = ( $cg{'contactgroup_id'}, $id );
			    my $result = StorProc->insert_obj( 'contactgroup_contact', \@vals );
			    if ( $result =~ /^Error/ ) { push @errors, $result }
			}
			my $data = '';
			unless (@errors) {
			    $data .= custom_variables('contacts', 'manage', 'contact_templates', $t{'name'}, \%t);
			}
			unless (@errors) {
			    my %where = ( 'contact_id' => $id );
			    my $result = StorProc->delete_one_where( 'contact_overrides', \%where );
			    if ( $result =~ /^Error/ ) { push @errors, $result }
			    my %values = ();
			    unless ( $query->param('host_notification_period_override') ) {
				my $np = $query->param('host_notification_period');
				my %np = StorProc->fetch_one( 'time_periods', 'name', $np );
				$values{'host_notification_period'} = $np{'timeperiod_id'};
			    }
			    unless ( $query->param('service_notification_period_override') ) {
				my $np = $query->param('service_notification_period');
				my %np = StorProc->fetch_one( 'time_periods', 'name', $np );
				$values{'service_notification_period'} = $np{'timeperiod_id'};
			    }
			    unless ( $query->param('host_notification_options_override') ) {
				my @no  = $query->$multi_param('host_notification_options');
				my $str = undef;
				foreach (@no) { $str .= "$_," }
				chop $str;
				$data .= "\n  <prop name=\"host_notification_options\"><![CDATA[$str]]>\n  </prop>";
			    }
			    unless ( $query->param('service_notification_options_override') ) {
				my @no  = $query->$multi_param('service_notification_options');
				my $str = undef;
				foreach (@no) { $str .= "$_," }
				chop $str;
				$data .= "\n  <prop name=\"service_notification_options\"><![CDATA[$str]]>\n  </prop>";
			    }
			    if ($data) {
				$values{'data'} = "<?xml version=\"1.0\" encoding=\"iso-8859-1\" ?>\n<data>" . $data . "\n</data>";
			    }
			    if (%values) {
				my @vals =
				  ( $id, $values{'host_notification_period'}, $values{'service_notification_period'}, $values{'data'} );
				$result = StorProc->insert_obj( 'contact_overrides', \@vals );
				if ( $result =~ /^Error/ ) { push @errors, $result }
			    }
			    %where = ( 'contact_id' => $id );
			    $result = StorProc->delete_one_where( 'contact_command_overrides', \%where );
			    if ( $result =~ /^Error/ ) { push @errors, $result }
			    unless ( $query->param('host_notification_commands_override') ) {
				my @mems = $query->$multi_param('host_notification_commands');
				foreach (@mems) {
				    my %c = StorProc->fetch_one( 'commands', 'name', $_ );
				    my @vals = ( $id, 'host', $c{'command_id'} );
				    $result = StorProc->insert_obj( 'contact_command_overrides', \@vals );
				    if ( $result =~ /^Error/ ) { push @errors, $result }
				}
			    }
			    unless ( $query->param('service_notification_commands_override') ) {
				my @mems = $query->$multi_param('service_notification_commands');
				foreach (@mems) {
				    my %c = StorProc->fetch_one( 'commands', 'name', $_ );
				    my @vals = ( $id, 'service', $c{'command_id'} );
				    $result = StorProc->insert_obj( 'contact_command_overrides', \@vals );
				    if ( $result =~ /^Error/ ) {
					push @errors, $result;
				    }
				}
			    }
			    unless (@errors) {
				$page .= Forms->header( $page_title, $session_id, $top_menu );
				my $message = "Contact \"$name\" added.";
				$page .= Forms->success( 'Added:', $message, 'continue', \%hidden );
				$got_form = 1;
			    }
			}
		    }
		}
	    }
	    unless ($got_form) {
		$page .= Forms->header( $page_title, $session_id, $top_menu );
		$page .= Forms->form_top( 'Contact Properties', 'onsubmit="selIt();"' );
		$page .= build_contact();
		$page .= Forms->hidden( \%hidden );
		$help{url} = StorProc->doc_section_url('How+to+configure+notifications+using+Nagios', 'HowtoconfigurenotificationsusingNagios-CreatingContacts');
		$page .= Forms->form_bottom_buttons( \%add, \%cancel, \%help, $tab++ );
		$got_form = 1;
	    }
	}

	#
	# Externals
	#
	elsif ( $obj eq 'externals' ) {
	    $page .= externals();
	    $got_form = 1;
	}

	#
	# Other
	#
	elsif ( $query->param('add') ) {
	    my $result = undef;
	    $table = $obj;
	    my %data = parse_query( $table, $obj );
	    my $field_ck = check_fields();
	    if ( $field_ck == 0 ) {
		my @values;
		unless ( $obj =~ /host_dependencies/ ) { push @values, \undef }
		$data{'name'} =~ s/^\s+|\s+$//g;
		my @data_cols = split( /,/, $db_values{$table} );
		foreach my $val (@data_cols) {
		    if ( $val eq 'comment' ) {
			push @values, "# $obj $properties{'name'}";
		    }
		    else {
			if ($val eq 'notes') {
			    if (defined $data{$val}) {
				# FIX MAJOR NOW:  this editing is probably no longer needed
				$data{$val} = StorProc->sanitize_string_but_keep_newlines($data{$val});
				$data{$val} =~ s/\n/<br>/g;
			    }
			}
			push @values, $data{$val};
		    }
		}
		my $id = StorProc->insert_obj_id( $table, \@values, $obj_id{$table} );
		if ( $id =~ /^Error/ ) {
		    if ( $id =~ /duplicate/i ) {
			$id =~ s/ies/y/;
			my $ltitle = $obj;
			$ltitle =~ s/_/ /g;
			$ltitle =~ s/ies$/y/;
			push @errors, "Error: \"\u$ltitle\" already exists.";
		    }
		    else {
			push @errors, $id;
		    }
		}
		else {
		    if ( $data{'members'} ) {
			my @mems = split( /,/, $data{'members'} );
			foreach (@mems) {
			    my %m = StorProc->fetch_one( 'hosts', 'name', $_ );
			    my @vals = ( $id, $m{'host_id'} );
			    $result = StorProc->insert_obj( 'hostgroup_host', \@vals );
			    if ( $result =~ /^Error/ ) { push @errors, $result }
			}
		    }

		    if ( $data{'contact'} ) {
			my @mems = split( /,/, $data{'contact'} );
			foreach (@mems) {
			    my %c = StorProc->fetch_one( 'contacts', 'name', $_ );
			    my @vals = ( $id, $c{'contact_id'} );
			    $result = StorProc->insert_obj( 'contactgroup_contact', \@vals );
			    if ( $result =~ /^Error/ ) { push @errors, $result }
			}
		    }

		    if ( $data{'contactgroup'} ) {
			my %o = StorProc->fetch_one( $table, 'name', $data{'name'} );
			my @mems = split( /,/, $data{'contactgroup'} );
			foreach (@mems) {
			    my %cg = StorProc->fetch_one( 'contactgroups', 'name', $_ );

			    my $table_name = $contactgroup_table_by_object{$obj};
			    my @vals = ( $cg{'contactgroup_id'}, $id );
			    $result = StorProc->insert_obj( $table_name, \@vals );

			    if ( $result =~ /^Error/ ) { push @errors, $result }
			}
		    }

		    if ( $data{'host_notification_commands'} ) {
			my %o = StorProc->fetch_one( $table, 'name', $data{'name'} );
			my %w = (
			    'contacttemplate_id' => $o{'contacttemplate_id'},
			    'type'               => 'host'
			);
			my $result = StorProc->delete_one_where( 'contact_command', \%w );
			my @c =
			  split( /,/, $data{'host_notification_commands'} );
			foreach (@c) {
			    my @vals = ( $o{'contacttemplate_id'}, 'host', $_ );
			    my $result = StorProc->insert_obj( 'contact_command', \@vals );
			    if ( $result =~ /Error/ ) { push @errors, $result }
			}
		    }

		    if ( $data{'service_notification_commands'} ) {
			my %o = StorProc->fetch_one( $table, 'name', $data{'name'} );
			my %w = (
			    'contacttemplate_id' => $o{'contacttemplate_id'},
			    'type'               => 'service'
			);
			my $result = StorProc->delete_one_where( 'contact_command', \%w );
			my @c =
			  split( /,/, $data{'service_notification_commands'} );
			foreach (@c) {
			    my @vals = ( $o{'contacttemplate_id'}, 'service', $_ );
			    my $result = StorProc->insert_obj( 'contact_command', \@vals );
			    if ( $result =~ /Error/ ) { push @errors, $result }
			}
		    }
		}
		unless (@errors) {
		    $page .= Forms->header( $page_title, $session_id, $top_menu );
		    ( my $object_type = lc $title ) =~ s/s\s*$//;
		    my $message = "\u$object_type \"$data{'name'}\" has been saved.";
		    $hidden{'name'} = undef;
		    $hidden{'task'} = undef;
		    $page .= Forms->success( 'Added', $message, 'continue', \%hidden );
		    $got_form = 1;
		}
		else {
		    $page .= Forms->header( $page_title, $session_id, $top_menu );
		    $page .= build_form('');
		    $got_form = 1;
		}
	    }
	    elsif ( $field_ck == 1 ) {
		$page .= Forms->header( $page_title, $session_id, $top_menu );
		$page .= build_form('');
		$got_form = 1;
	    }
	}
	if ( $query->param('bail') ) {
	    $got_form = 0;
	}
	unless ($got_form) {
	    $page .= Forms->header( $page_title, $session_id, $top_menu );
	    my $title   = undef;
	    my $l_title = undef;
	    my @t_parse = split( /_/, $obj );
	    foreach (@t_parse) {
		$l_title .= "$_ ";
		$title   .= "\u$_ ";
	    }
	    $l_title =~ s/s\s$//;
	    $l_title =~ s/ie$/y/;
	    my $template = $query->param('source');
	    if ( $obj eq 'contacts' || $task || $template ) {
		if ( !$template && $task =~ /copy|use/ ) {
		    $page .= Forms->form_top( 'Select', '' );
		    my @templates = StorProc->fetch_list( $table, 'name' );
		    $page .= Forms->list_box( "\u$l_title:", 'source', \@templates );
		    $hidden{'task'} = $task;
		    $page .= Forms->hidden( \%hidden );
		    $page .= Forms->form_bottom_buttons( \%next, \%cancel, $tab++ );
		}
		else {
		    my $help_url =
			( $obj eq 'hostgroups' )
			? StorProc->doc_section_url('How+to+configure+notifications+using+Nagios', 'HowtoconfigurenotificationsusingNagios-ConfiguringHostGroupsandServiceGroups')
		      : ( $obj eq 'host_templates' )
			? StorProc->doc_section_url('About+Configuration', 'AboutConfiguration-HostandServiceTemplates')
		      : ( $obj eq 'service_dependency_templates' )
			? StorProc->doc_section_url('How+to+manage+service+dependencies')
		      : ( $obj eq 'contactgroups' && $task eq 'copy' )
			? StorProc->doc_section_url('How+to+configure+notifications+using+Nagios', 'HowtoconfigurenotificationsusingNagios-CreatingContactGroups')
		      : ( $obj eq 'contactgroups' )
			? StorProc->doc_section_url('About+Notifications+and+Downtime', 'AboutNotificationsandDowntime-NotificationObjects')
		      : ( $obj eq 'contact_templates' )
			? StorProc->doc_section_url('How+to+configure+notifications+using+Nagios', 'HowtoconfigurenotificationsusingNagios-CreatingContactTemplates')
		      : ( $obj eq 'extended_host_info_templates' )
			? StorProc->doc_section_url('How+to+define+extended+info')
		      : '';
		    $page .= build_form( '', $help_url );
		}
	    }
	    elsif ( $obj eq 'contacts' ) {
		$page .= Forms->form_top( 'Select', '' );
		my @templates = StorProc->fetch_list( 'contact_templates', 'name' );
		$page .= Forms->list_box( 'Contact template:', 'source', \@templates );
		$hidden{'task'} = 'use';
		$page .= Forms->hidden( \%hidden );
		$page .= Forms->form_bottom_buttons( \%next, \%cancel, $tab++ );
	    }
	}
    }
    return $page;
}

#
# host_dependencies
#

# There is still some legacy wording here:  "parent" where "master" is meant.

sub host_dependencies() {
    my $got_form       = 0;
    my $page           = undef;
    my $dependent_host = $query->param('dependent_host');
    my $master_host    = $query->param('master_host');
    unless ( $dependent_host && $master_host ) {
	my $name = $query->param('name');
	my @dp = split( /::--::/, (defined( $name ) ? $name : '') );
	$dependent_host = $dp[0];
	$master_host    = $dp[1];
    }
    my %d = StorProc->fetch_one( 'hosts', 'name', $dependent_host );
    my %m = StorProc->fetch_one( 'hosts', 'name', $master_host );
    if ( $query->param('cancel') || $query->param('continue') ) {
	$page .= Forms->header( $page_title, $session_id, $top_menu );
	$got_form = 1;
    }
    elsif ( $query->param('delete') or $query->param('confirm_delete') ) {
	if ( $query->param('confirm_delete') ) {
	    my %where = ( 'host_id' => $d{'host_id'}, 'parent_id' => $m{'host_id'} );
	    my $result = StorProc->delete_one_where( 'host_dependencies', \%where );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	    unless (@errors) {
		my $message = "Host dependency for \"$dependent_host\" depending on master \"$master_host\".";
		$hidden{'name'} = undef;
		$page .= Forms->header( $page_title, $session_id, $top_menu, '', '1' );
		$page .= Forms->success( 'Removed', $message, 'continue', \%hidden );
		$got_form = 1;
	    }
	}
	else {
	    $hidden{'dependent_host'} = $dependent_host;
	    $hidden{'master_host'}    = $master_host;
	    $page .= Forms->header( $page_title, $session_id, $top_menu );
	    my $message = qq(Are you sure you want to remove the host dependency for \"$dependent_host\" depending on master \"$master_host\"?);
	    $page .= Forms->are_you_sure( 'Confirm Delete', $message, 'confirm_delete', \%hidden );
	    $got_form = 1;
	}
    }
    elsif ( $query->param('save') || $query->param('add') ) {
	my $inherits_dependencies = $query->param('inherits_dependencies');
	my @execution             = $query->$multi_param('execution_failure_criteria');
	my @notify                = $query->$multi_param('notification_failure_criteria');
	my $data                  = '';
	if ( $d{'host_id'} && $m{'host_id'} && $notify[0] ) {
	    if ($inherits_dependencies) {
		## Too bad for the misleading property name.
		$data .= qq(
  <prop name="inherits_parent"><![CDATA[$inherits_dependencies]]>
  </prop>);
	    }
	    my $efc = join( ',', @execution );
	    if ($efc) {
		$data .= qq(
  <prop name="execution_failure_criteria"><![CDATA[$efc]]>
  </prop>);
	    }
	    my $nfc = join( ',', @notify );
	    $data .= qq(
  <prop name="notification_failure_criteria"><![CDATA[$nfc]]>
  </prop>);
	    $data = "<?xml version=\"1.0\" encoding=\"iso-8859-1\" ?>\n<data>$data\n</data>";
	    if ( $query->param('save') ) {
		my %values = ( 'data' => $data );
		my %where = ( 'host_id' => $d{'host_id'}, 'parent_id' => $m{'host_id'} );
		my $result = StorProc->update_obj_where( 'host_dependencies', \%values, \%where );
		if ( $result =~ /^Error/ ) { push @errors, $result }
		unless (@errors) {
		    my $message = "Changes to host \"$dependent_host\" depending on master \"$master_host\" have been saved.";
		    $hidden{'name'} = undef;
		    $page .= Forms->header( $page_title, $session_id, $top_menu );
		    $page .= Forms->success( 'Updated', $message, 'continue', \%hidden );
		    $got_form = 1;
		}
	    }
	    else {
		my %where = ( 'parent_id' => $d{'host_id'}, 'host_id' => $m{'host_id'} );
		my %dep = StorProc->fetch_one_where( 'host_dependencies', \%where );
		push @errors, delete $dep{'error'} if defined $dep{'error'};
		if ( $dep{'host_id'} ) {
		    push @errors,
"Cannot create cyclical dependency. Host \"$dependent_host\" is currently the master to proposed master host \"$master_host\".";
		}
		if ( $m{'host_id'} == $d{'host_id'} ) {
		    push @errors, "A host cannot be its own master.";
		}
		unless (@errors) {
		    my %where = ( 'parent_id' => $m{'host_id'}, 'host_id' => $d{'host_id'} );
		    my %dep = StorProc->fetch_one_where( 'host_dependencies', \%where );
		    push @errors, delete $dep{'error'} if defined $dep{'error'};
		    unless ( $dep{'host_id'} ) {
			my @vals = ( $d{'host_id'}, $m{'host_id'}, $data, '' );
			my $result = StorProc->insert_obj( 'host_dependencies', \@vals );
			if ( $result =~ /^Error/ ) { push @errors, $result }
			unless (@errors) {
			    my $message = "Added: host \"$dependent_host\" depending on master \"$master_host\" is saved.";
			    $hidden{'name'} = undef;
			    $page .= Forms->header( $page_title, $session_id, $top_menu );
			    $page .= Forms->success( 'Updated', $message, 'continue', \%hidden );
			    $got_form = 1;
			}
		    }
		    else {
			push @errors, "Already exists: host \"$dependent_host\" depending on master \"$master_host\"";
		    }
		}
	    }
	}
	else {
	    push @errors, "Please correct missing fields. (Dependent host, Master host, and Notification failure criteria are required.)";
	}
    }
    unless ($got_form) {
	$page .= Forms->header( $page_title, $session_id, $top_menu );
	my @props = ( 'dependent_host', 'master_host', 'inherits_dependencies', 'execution_failure_criteria', 'notification_failure_criteria' );
	my %docs = Doc->properties_doc( 'host_dependencies', \@props );
	if ( $query->param('task') eq 'new' ) {
	    my @hosts = StorProc->fetch_list( 'hosts', 'name' );
	    $page .= Forms->form_top( 'Host Dependency Properties', '' );
	    if (@errors) { $page .= Forms->form_errors( \@errors ) }
	    $page .= Forms->list_box(
		"Dependent host:",
		'dependent_host', \@hosts,
		$properties{'dependent_host'},
		$required{'dependent_host'},
		$docs{'dependent_host'}, '', $tab++
	    );
	    $page .= Forms->list_box(
		'Master host:', 'master_host', \@hosts,
		$properties{'master_host'},
		$required{'master_host'},
		$docs{'master_host'}, '', $tab++
	    );
	    if ( $nagios_ver =~ /^[23]\.x$/ ) {
		$page .= Forms->checkbox(
		    'Inherit master host dependencies:',
		    'inherits_dependencies',
		    $properties{'inherits_parent'},
		    $docs{'inherits_dependencies'},
		    '', $tab++
		);
		my @opts = split( /,/, (defined( $properties{'execution_failure_criteria'} ) ? $properties{'execution_failure_criteria'} : '') );
		$page .=
		  Forms->failure_criteria( 'execution_failure_criteria', \@opts, '', 'host_dependencies', $docs{'execution_failure_criteria'},
		    '', $tab++ );
	    }
	    my @opts = split( /,/, (defined( $properties{'notification_failure_criteria'} ) ? $properties{'notification_failure_criteria'} : '') );
	    $page .= Forms->failure_criteria(
		'notification_failure_criteria',
		\@opts, '', 'host_dependencies', $docs{'notification_failure_criteria'},
		'', $tab++
	    );
	    $page .= Forms->hidden( \%hidden );
	    $help{url} = StorProc->doc_section_url('How+to+manage+host+dependencies');
	    $page .= Forms->form_bottom_buttons( \%add, \%cancel, \%help, $tab++ );
	}
	else {
	    my @parents = StorProc->fetch_list( 'hosts', 'name' );
	    my %where = ( 'host_id' => $d{'host_id'}, 'parent_id' => $m{'host_id'} );
	    %properties = StorProc->fetch_one_where( 'host_dependencies', \%where );
	    push @errors, delete $properties{'error'} if defined $properties{'error'};
	    $page .= Forms->form_top( 'Host Dependency Properties', '' );
	    if (@errors) { $page .= Forms->form_errors( \@errors ) }
	    $page .= Forms->display_hidden( 'Dependent host:', 'dependent_host', $dependent_host );
	    $page .= Forms->display_hidden( 'Master host:',    'master_host',    $master_host );
	    if ( $nagios_ver =~ /^[23]\.x$/ ) {
		$page .= Forms->checkbox(
		    'Inherit master host dependencies:',
		    'inherits_dependencies',
		    $properties{'inherits_parent'},
		    $docs{'inherits_dependencies'},
		    '', $tab++
		);
		my @opts = split( /,/, (defined( $properties{'execution_failure_criteria'} ) ? $properties{'execution_failure_criteria'} : '') );
		$page .=
		  Forms->failure_criteria( 'execution_failure_criteria', \@opts, '', 'host_dependencies', $docs{'execution_failure_criteria'},
		    '', $tab++ );
	    }
	    my @opts = split( /,/, $properties{'notification_failure_criteria'} );
	    $page .= Forms->failure_criteria(
		'notification_failure_criteria',
		\@opts, '', 'host_dependencies', $docs{'notification_failure_criteria'},
		'', $tab++
	    );
	    $page .= Forms->hidden( \%hidden );
	    $help{url} = StorProc->doc_section_url('How+to+manage+host+dependencies');
	    $page .= Forms->form_bottom_buttons( \%save, \%delete, \%cancel, \%help, $tab++ );
	}
    }
    return $page;
}

#
# Clone host
#

sub clone_host() {
    my $got_form = 0;
    my $page     = undef;
    if ( $query->param('cancel') ) {
	$page .= Forms->header( $page_title, $session_id, $top_menu );
	$got_form = 1;
    }
    elsif ( $query->param('add_clone_host') ) {
	my $host    = $query->param('host');
	my $name    = $query->param('name');
	my $alias   = StorProc->sanitize_string( scalar $query->param('alias') );
	my $address = StorProc->sanitize_string( scalar $query->param('address') );
	my %exists  = StorProc->fetch_one( 'hosts', 'name', $name );
	if ( $exists{'name'} ) {
	    push @errors, "Host \"$name\" already exists.";
	}
	else {
	    if ( $host && $name && $alias && $address ) {
		@errors = StorProc->clone_host( $host, $name, $alias, $address );
		unless ( $errors[0] ) {
		    $obj = 'hosts';
		    $page .= Forms->header( $page_title, $session_id, $top_menu );
		    $hidden{'view'} = 'manage_host';
		    $page .= manage_host( $name, 'name' );
		    $got_form = 1;
		}
	    }
	    else {
		unless ($host)    { $required{'host'}    = 1 }
		unless ($name)    { $required{'name'}    = 1 }
		unless ($alias)   { $required{'alias'}   = 1 }
		unless ($address) { $required{'address'} = 1 }
		push @errors, "Check required fields.";
	    }
	}
    }
    unless ($got_form) {
	$page .= Forms->header( $page_title, $session_id, $top_menu );
	my %docs    = Doc->host_wizard_vitals();
	my $host    = $query->param('host');
	my $name    = $query->param('name');
	my $alias   = StorProc->sanitize_string( scalar $query->param('alias') );
	my $address = StorProc->sanitize_string( scalar $query->param('address') );
	$page .= Forms->form_top( 'Clone Host', '' );
	if (@errors) { $page .= Forms->form_errors( \@errors ) }
	my @hosts = StorProc->fetch_list( 'hosts', 'name' );
	$page .= Forms->text_box( 'Host name:', 'name',    $name,    '50', $required{'name'},    '',               '', $tab++ );
	$page .= Forms->text_box( 'Alias:',     'alias',   $alias,   '70', $required{'alias'},   $docs{'alias'},   '', $tab++ );
	$page .= Forms->text_box( 'Address:',   'address', $address, '20', $required{'address'}, $docs{'address'}, '', $tab++ );
	$page .= Forms->list_box( 'Host to clone:', 'host', \@hosts, $host, $required{'host'}, '', '', $tab++ );
	$hidden{'view'} = 'clone_host';
	$page .= Forms->hidden( \%hidden );
	my %clone_host = ( 'name' => 'add_clone_host', 'value' => 'Clone Host' );
	$page .= Forms->form_bottom_buttons( \%clone_host, \%cancel, $tab++ );
    }
    return $page;
}

sub delete_hosts() {
    my $page = undef;
    if ( $query->param('close') || $query->param('continue') ) {
	$page .= Forms->header( $page_title, $session_id, $top_menu );
	$obj = 'close';
    }
    elsif ( $query->param('remove_host') ) {
	my @hosts     = $query->$multi_param('delete_host');
	my %host_name = StorProc->get_table_objects('hosts');
	foreach my $host (@hosts) {
	    $host = uri_unescape($host);
	    my $result = StorProc->delete_all( 'hosts', 'name', $host );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	}
    }
    if ( $obj ne 'close' ) {
	my $search = $query->param('search');
	$page .= Forms->header( $page_title, $session_id, $top_menu );
	$page .= Forms->form_top( 'Delete Hosts', '' );
	my @host_search = StorProc->get_host_search_matrix();
	$page .= Forms->list_box_submit( 'Select hosts:', 'search', \@host_search, $search, '', '', $tab++ );
	# $hidden{'view'} = 'delete_hosts';
	$page .= Forms->hidden( \%hidden );
	my %hosts = ();

	if ($search) {
	    my $searstr = $search;
	    chop $searstr;
	    %hosts = StorProc->search( $searstr, -1 );    # -1 means do not limit number of results
	    if (%hosts) {
		$page .= Forms->mass_delete( $session_id, \%hosts );
		my $help_url = StorProc->doc_section_url('How+to+manage+hosts', 'Howtomanagehosts-DeletingMultipleHosts');
		$page .= Forms->toggle_delete($help_url);
	    }
	}
	unless (%hosts) {
	    $help{url} = StorProc->doc_section_url('How+to+manage+hosts', 'Howtomanagehosts-DeletingMultipleHosts');
	    $page .= Forms->form_bottom_buttons( \%close, \%help, $tab++ );
	}
    }

    return $page;
}

sub delete_host_services() {
    my $page = undef;
    if ( $query->param('close') || $query->param('continue') ) {
	$page .= Forms->header( $page_title, $session_id, $top_menu );
	$obj = 'close';
    }
    elsif ( $query->param('delete_host') ) {
	my $service      = $query->param('service');
	my @hosts        = $query->$multi_param('delete_host');
	my %host_name    = StorProc->get_table_objects('hosts');
	my %service_name = StorProc->get_table_objects('service_names');
	my %host_service = StorProc->get_host_service( $service_name{$service} );
	foreach my $host (@hosts) {
	    $host = uri_unescape($host);
	    my %where = (
		'servicename_id' => $service_name{$service},
		'host_id'        => $host_name{$host}
	    );
	    my $result = StorProc->delete_one_where( 'services', \%where );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	}
    }
    if ( $obj ne 'close' ) {
	my $service = $query->param('service');
	$page .= Forms->header( $page_title, $session_id, $top_menu );
	$page .= Forms->form_top( 'Delete Host Services', '' );
	my @services = StorProc->fetch_list( 'service_names', 'name' );
	$page .= Forms->list_box_submit( 'Select service:', 'service', \@services, $service, '', '', $tab++ );
	# $hidden{'view'} = 'delete_host_services';
	$page .= Forms->hidden( \%hidden );
	my @hosts = ();

	if ($service) {
	    my %svc = StorProc->fetch_one( 'service_names', 'name', $service );
	    @hosts = StorProc->get_service_hosts( $svc{'servicename_id'} );
	    if (@hosts) {
		my %host_srv = ();
		foreach my $host ( sort @hosts ) { $host_srv{$host} = $service }
		$page .= Forms->mass_delete( $session_id, \%host_srv );
		my $help_url = StorProc->doc_section_url('How+to+manage+services', 'Howtomanageservices-DeletingMultipleHostServices');
		$page .= Forms->toggle_delete($help_url);
	    }
	}
	unless (@hosts) {
	    $help{url} = StorProc->doc_section_url('How+to+manage+services', 'Howtomanageservices-DeletingMultipleHostServices');
	    $page .= Forms->form_bottom_buttons( \%close, \%help, $tab++ );
	}
    }

    return $page;
}

#
# Parent child
#

sub parent_child() {
    my $got_form = 0;
    my $page     = undef;
    my $name     = $query->param('name');
    my $parent   = $query->param('parent');
    if ( $query->param('continue') || $query->param('cancel') ) {
	$page .= Forms->header( $page_title, $session_id, $top_menu );
	$got_form = 1;
    }
    elsif ( $query->param('save') ) {
	my @children = $query->$multi_param('children');
	if ( $parent && @children ) {
	    foreach my $child (@children) {
		if ( $parent eq $child ) {
		    push @errors, "A host cannot be its own parent.";
		    last;
		}
	    }
	    unless (@errors) {
		my %p = StorProc->fetch_one( 'hosts', 'name', $name );
		my %w = ( 'parent_id' => $p{'host_id'} );
		my $result = StorProc->delete_one_where( 'host_parent', \%w );
		if ( $result =~ /^Error/ ) { push @errors, $result }
		%p = StorProc->fetch_one( 'hosts', 'name', $parent );
		%w = ( 'parent_id' => $p{'host_id'} );
		$result = StorProc->delete_one_where( 'host_parent', \%w );
		if ( $result =~ /^Error/ ) { push @errors, $result }

		foreach my $child (@children) {
		    if ( !$child ) { next }
		    my %h = StorProc->fetch_one( 'hosts', 'name', $child );
		    my @vals = ( $h{'host_id'}, $p{'host_id'} );
		    my $result = StorProc->insert_obj( 'host_parent', \@vals );
		    if ( $result =~ /^Error/ ) { push @errors, $result }
		}
	    }
	    unless (@errors) {
		$page .= Forms->header( $page_title, $session_id, $top_menu );
		$page .= Forms->form_top( 'Saved', '' );
		$page .= Forms->display_hidden( 'Parent:', 'name', $parent );
		$page .= Forms->hidden( \%hidden );
		$page .= Forms->form_bottom_buttons( \%continue, $tab++ );
		$got_form = 1;
	    }
	}
	else {
	    push @errors, "A parent and at least one child must be selected.";
	}
    }
    elsif ( $query->param('bail') ) {
	$got_form = 0;
    }
    elsif ( $query->param('delete') or $query->param('confirm_delete') ) {
	if ( $query->param('confirm_delete') ) {
	    $page .= Forms->header( $page_title, $session_id, $top_menu );
	    my %p = StorProc->fetch_one( 'hosts', 'name', $parent );
	    my %w = ( 'parent_id' => $p{'host_id'} );
	    my $result = StorProc->delete_one_where( 'host_parent', \%w );
	    if ( $result =~ /^Error/ ) {
		push @errors, $result;
	    }
	    else {
		$page .= Forms->header( $page_title, $session_id, $top_menu, '', '1' );
		$page .= Forms->form_top( 'Parent Relationship Deleted', '' );
		my @message = ("$parent");
		$page .= Forms->form_message( 'Removed:', \@message, 'row1' );
		$page .= Forms->hidden( \%hidden );
		$page .= Forms->form_bottom_buttons( \%continue, $tab++ );
		$got_form = 1;
	    }
	}
	else {
	    $page .= Forms->header( $page_title, $session_id, $top_menu );
	    my $message = qq(Are you sure you want to remove \"$name\" as a parent? (Note: \"$name\" will still remain as a host.));
	    $hidden{'name'}   = $parent;
	    $hidden{'parent'} = $parent;
	    $page .= Forms->are_you_sure( 'Confirm Delete', $message, 'confirm_delete', \%hidden );
	    $got_form = 1;
	}
    }
    unless ($got_form) {
	$page .= Forms->header( $page_title, $session_id, $top_menu );
	my @hosts        = StorProc->fetch_list( 'hosts', 'name' );
	my @parents      = StorProc->get_parents();
	my @poss_parents = ();
	foreach my $host (@hosts) {
	    my $got_parent = 0;
	    foreach my $parent (@parents) {
		if ( $host eq $parent ) { $got_parent = 1 }
		if ( defined($name) && $host eq $name ) { $got_parent = 0 }
	    }
	    unless ($got_parent) { push @poss_parents, $host }
	}
	my @children = ();
	if (defined $name) {
	    my %pid = StorProc->fetch_one( 'hosts', 'name', $name );
	    if (defined $pid{'host_id'}) {
		@children = StorProc->get_children( $pid{'host_id'} );
	    }
	}
	my %docs = Doc->parent_child();
	$page .= Forms->header( $page_title, $session_id, $top_menu );
	$page .= Forms->form_top( 'Parent Child', 'onsubmit="selIt();"' );
	if (@errors) { $page .= Forms->form_errors( \@errors ) }
	$page .= Forms->wizard_doc( 'Physical Dependency Relationships', $docs{'physical_dependency'}, undef, 1 );
	$hidden{'name'} = $name;
	$page .= Forms->list_box( "Parent host:", 'parent', \@poss_parents, $name, '', $docs{'parent_host'}, '', $tab++ );
	$page .= Forms->members( 'Children:', 'children', \@children, \@hosts, '', '30', $docs{'children'}, '', $tab++ );
	$page .= Forms->hidden( \%hidden );
	$help{url} = StorProc->doc_section_url('How+to+manage+parent+child+relationships');
	$page .= Forms->form_bottom_buttons( \%save, \%delete, \%cancel, \%help, $tab++ );
    }
    return $page;
}

############################################################################
# Externals
#

sub externals($) {
    my $type = shift;
    my $form = undef;
    unless ($type) { $type = $query->param('type') }
    $hidden{'type'} = $type;
    my $task = $query->param('task');
    $hidden{'task'} = $task;
    my $name = $query->param('name');
    $name =~ s/^\s+|\s+$//g if defined $name;
    my $display  = $query->param('display');
    my $got_form = 0;
    $hidden{'update_main'} = 1;

    my %external = StorProc->fetch_one( 'externals', 'name', $name );

    # On a cancel, we just re-display, as it likely comes from a canceled rename.
    if ( $query->param('continue') || $query->param('close') ) {
	$form .= Forms->header( $page_title, $session_id, $top_menu );
	$got_form = 1;
    }
    elsif ( $query->param('add') ) {
	if ( $name && $type ) {
	    unless ( $external{'name'} ) {
		my @vals = ( \undef, $name, '', $type, $display, '' );
		my $result = StorProc->insert_obj( 'externals', \@vals );
		if ( $result =~ /^Error/ ) { push @errors, $result }
	    }
	    else {
		push @errors, "Record \"$name\" already exists.";
	    }
	}
	else {
	    push @errors, "Please fill in the required fields.";
	    $required{'name'} = 1;
	    $required{'type'} = 1;
	}
	unless (@errors) {
	    $form .= Forms->header( $page_title, $session_id, $top_menu );
	    $form .= Forms->form_top( 'Saved', '' );
	    $form .= Forms->display_hidden( "\u$type external name:", 'name', $name );
	    $form .= Forms->hidden( \%hidden );
	    $form .= Forms->form_bottom_buttons( \%continue, $tab++ );
	    $got_form = 1;
	}
    }
    elsif ( $query->param('save') ) {
	if ($type) {
	    my %values = ( 'type' => $type, 'display' => $display );
	    my $result = StorProc->update_obj( 'externals', 'name', $name, \%values );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	}
	else {
	    push @errors, "Please fill in the required fields.";
	    $required{'type'} = 1;
	}
	unless (@errors) {
	    $form .= Forms->header( $page_title, $session_id, $top_menu, '', '' );
	    $form .= Forms->form_top( 'Saved', '' );
	    $form .= Forms->display_hidden( "\u$type external name:", 'name', $name );
	    $form .= Forms->hidden( \%hidden );
	    my %docs = Doc->externals();
	    $form .= Forms->wizard_doc( 'Replace or Merge Action',
	      $type eq 'host' ? $docs{'apply_host'} : $docs{'apply_service'}, undef, 1 );
	    my %replace = ( 'name' => 'replace', 'value' => 'Replace existing externals' );
	    my %merge   = ( 'name' => 'merge',   'value' => 'Merge with existing externals' );
	    $form .= Forms->form_bottom_buttons( \%replace, \%merge, \%continue, $tab++ );
	    $got_form = 1;
	}
    }
    elsif ( $query->param('rename') ) {
	$form .= rename_object( '', $name );
	$got_form = 1;
    }
    elsif ( $query->param('copy') ) {
	$task           = 'new';
	$hidden{'task'} = $task;
	$name           = "Copy-of-$name";
    }
    elsif ( defined($task) && $task eq 'copy' ) {
	my $source = $query->param('source');
	my %source = StorProc->fetch_one( 'externals', 'name', $source );
	$task           = 'new';
	$hidden{'task'} = $task;
	$name           = "Copy-of-$source";
	$display        = $source{'display'};
    }
    elsif ( $query->param('merge') || $query->param('replace') ) {
	my %w      = ( 'external_id' => $external{'external_id'} );
	my %values = ( 'data'        => $external{'display'} );
	if ($query->param('merge')) {
	    $w{'modified'} = 0;
	}
	else {
	    $values{'modified'} = $DEFINED_REF;
	}
	my $result = StorProc->update_obj_where( $type eq 'host' ? 'external_host' : 'external_service', \%values, \%w );
	if ( $result =~ /^Error/ ) { push @errors, $result }
	unless (@errors) {
	    my $top_phrase = $query->param('merge') ? 'Merged' : 'Replaced';
	    my $msg_phrase = $query->param('merge') ? 'merged with' : 'replaced in';
	    $form .= Forms->header( $page_title, $session_id, $top_menu );
	    $form .= Forms->form_top( $top_phrase, '' );
	    my @message = ("\"$name\" $msg_phrase ${type}s");
	    $form .= Forms->form_message( 'Saved:', \@message, 'row1' );
	    $form .= Forms->hidden( \%hidden );
	    $form .= Forms->form_bottom_buttons( \%continue, $tab++ );
	    $got_form = 1;
	}
    }
    elsif ( $query->param('delete') || $query->param('confirm_delete') ) {
	foreach my $name ( $query->param ) {
	    unless ( $name eq 'nocache' ) {
		$hidden{$name} = $query->param($name);
	    }
	}
	if ( $query->param('confirm_delete') ) {
	    my $result = StorProc->delete_all( 'externals', 'external_id', $external{'external_id'} );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	    unless (@errors) {
		$form .= Forms->header( $page_title, $session_id, $top_menu, '', '1' );
		$form .= Forms->form_top( 'External Deleted', '' );
		my @message = ("$name");
		$form .= Forms->form_message( 'Removed:', \@message, 'row1' );
		$form .= Forms->hidden( \%hidden );
		$form .= Forms->form_bottom_buttons( \%continue, $tab++ );
		$name     = undef;
		$got_form = 1;
	    }
	}
	elsif ( defined($query->param('task')) && $query->param('task') eq 'No' ) {
	    $got_form = 0;
	}
	else {
	    delete $hidden{'task'};
	    # GWMON-5739
	    delete $hidden{'display'};
	    $hidden{'delete'} = 1;
	    $form .= Forms->header( $page_title, $session_id, $top_menu );
	    my $message = qq(Are you sure you want to remove \"$name\"? (Warning: \"$name\" will be removed from all ${type}s and profiles).);
	    $form .= Forms->are_you_sure( 'Confirm Delete', $message, 'confirm_delete', \%hidden );
	    $name     = undef;
	    $got_form = 1;
	}
    }
    unless ($got_form) {
	$form .= Forms->header( $page_title, $session_id, $top_menu );
	$form .= Forms->form_top( "\u$type External", '', '', '100%' );
	if (@errors) { $form .= Forms->form_errors( \@errors ) }
	if ( defined($task) && $task eq 'new' ) {
	    $form .= Forms->text_box( "\u$type external name:", 'name', $name, $textsize{'name'}, $required{'name'}, '', '', $tab++ );
	}
	else {
	    unless ($display) { $display = $external{'display'} }
	    $form .= Forms->display_hidden( "\u$type external name:", 'name', $name );
	    delete $hidden{'task'};
	}
	$form .= Forms->display_hidden( 'Type:', 'type', $type );
	$form .= Forms->text_area( 'Detail:', 'display', $display, '25', '100%', '', '', '', $tab++ );
	$form .= Forms->hidden( \%hidden );
	my %cancel = ( 'name' => 'close', 'value' => 'Cancel' );
	$help{url} = StorProc->doc_section_url('How+to+configure+externals');
	if ( defined($task) && $task eq 'new' ) {
	    $form .= Forms->form_bottom_buttons( \%add, \%cancel, \%help, $tab++ );
	}
	else {
	    my %copy = ( 'name' => 'copy', 'value' => 'Copy' );
	    $form .= Forms->form_bottom_buttons( \%save, \%delete, \%rename, \%copy, \%cancel, \%help, $tab++ );
	}
    }
    return $form;
}

############################################################################
# Escalations
#
sub escalations() {
    my $page = undef;
    my $type = $query->param('type');
    my $name = $query->param('name');
    $table          = "escalation_templates";
    $hidden{'obj'}  = $obj;
    $hidden{'type'} = $type;
    my $got_form = 0;

    # for validation - supposedly not yet hooked up (but already part of build_form(), and redundantly specified below)
    my $validation_mini_profile = {
	notification_interval => { constraint => '[0-9]+', message => 'Value must be numeric.' },
	first_notification    => { constraint => '[0-9]+', message => 'Value must be numeric.' },
	last_notification     => { constraint => '[0-9]+', message => 'Value must be numeric.' },
    };
    my $escalation = $query->param('escalation');
    if (   $query->param('continue')
	|| $query->param('close')
	|| $query->param('cancel') )
    {
	$page .= Forms->header( $page_title, $session_id, $top_menu );
	$got_form = 1;
    }
    elsif ( $query->param('add') ) {
	my %data = parse_query( $table, $obj );
	my $field_ck = check_fields();
	if ( $field_ck == 0 ) {
	    my @values = (\undef);
	    my @data_cols = split( /,/, $db_values{$table} );
	    foreach my $val (@data_cols) {
		$val =~ s/^\s+|\s+$//g;
		if ( $val eq 'comment' ) {
		    push @values, "# $obj $properties{'name'}";
		}
		else {
		    push @values, $data{$val};
		}
	    }
	    my %esc = StorProc->fetch_one( 'escalation_templates', 'name', $properties{'name'} );
	    if ( $esc{'name'} ) {
		push @errors, "An escalation named \"$properties{'name'}\" already exists.";
	    }
	    else {
		my $result = StorProc->insert_obj( 'escalation_templates', \@values, $obj_id{$table} );
		if ( $result =~ /^Error/ ) { push @errors, $result }
	    }
	    unless (@errors) {
		$page .= Forms->header( $page_title, $session_id, $top_menu );
		my $message = "\u$type escalation \"$data{'name'}\" has been saved.";
		$hidden{'name'} = undef;
		$hidden{'task'} = undef;
		$page .= Forms->success( 'Added', $message, 'continue', \%hidden );
		$got_form = 1;
	    }
	    else {
		$page .= Forms->header( $page_title, $session_id, $top_menu );
		$page .= build_form($validation_mini_profile);
		## $page .= build_form('');
		$got_form = 1;
	    }
	}
	elsif ( $field_ck == 1 ) {
	    $page .= Forms->header( $page_title, $session_id, $top_menu );
	    $page .= build_form($validation_mini_profile);
	    ## $page .= build_form('');
	    $got_form = 1;
	}
    }
    elsif ( $query->param('save') ) {
	my %values   = ();
	my %data     = parse_query( $table, $obj );
	my $field_ck = check_fields();
	if ( $field_ck == 0 ) {
	    foreach my $key ( keys %data ) {
		unless ( $key =~ /HASH|^name$|^contactgroup$|members$/ ) {
		    $values{$key} = $data{$key};
		}
	    }
	    my $result = StorProc->update_obj( 'escalation_templates', 'name', $data{'name'}, \%values );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	    unless (@errors) {
		my $message = "Changes to \"$name\" have been saved.";
		$hidden{'name'} = undef;
		$page .= Forms->header( $page_title, $session_id, $top_menu );
		$page .= Forms->success( 'Updated', $message, 'continue', \%hidden );
		$got_form = 1;
	    }
	    else {
		$page .= Forms->header( $page_title, $session_id, $top_menu );
		$page .= build_form($validation_mini_profile);
		## $page .= build_form('');
		$got_form = 1;
	    }
	}
	elsif ( $field_ck == 1 ) {
	    $page .= Forms->header( $page_title, $session_id, $top_menu );
	    $page .= build_form($validation_mini_profile);
	    ## $page .= build_form('');
	    $got_form = 1;
	}
    }
    elsif ( $query->param('rename') ) {
	$page .= rename_object( '', $name );
	$got_form = 1;
    }
    elsif ( $query->param('bail') ) {
	$task = 'modify';
	$hidden{'task'} = 'modify';
    }
    elsif ( $query->param('delete') or $query->param('confirm_delete') ) {
	$hidden{'task'} = 'modify';
	$page .= Forms->header( $page_title, $session_id, $top_menu );
	$page .= delete_object( '', $name );
	$got_form = 1;
    }
    unless ($got_form) {
	if ( $obj =~ /escalation_templates/ ) {
	    $page .= Forms->header( $page_title, $session_id, $top_menu );
	    $hidden{'type'} = $type;
	    $hidden{'task'} = $task;
	    my $help_url = StorProc->doc_section_url('How+to+configure+notifications+using+Nagios', 'HowtoconfigurenotificationsusingNagios-CreatingEscalations');
	    $page .= build_form($validation_mini_profile, $help_url);
	}
    }
    return $page;
}

sub escalation_trees() {
    local $_;

    my @views = ( 'detail', 'assign_hostgroups', 'assign_hosts', 'assign_service_groups', 'assign_services' );
    unless ( defined($obj_view) && $obj_view eq 'assign_contact_groups' ) {
	foreach my $v (@views) {
	    if ( $query->param($v) ) { $obj_view = $v }
	}
    }
    foreach my $name ( $query->param ) {
	if ( $name =~ /assign_contact_group_(\d+)/ ) {
	    $hidden{'id'} = $1;
	    $obj_view = 'assign_contact_groups';
	}
	if ( $name =~ /remove_escalation_(\d+)/ ) {
	    $hidden{'id'} = $1;
	    $obj_view = 'remove_escalation';
	}
    }
    my $message = undef;
    my $page    = undef;
    my $type    = $query->param('type');
    my $name    = $query->param('name');
    $name =~ s/^\s+|\s+$//g if defined $name;
    $hidden{'obj'}  = $obj;
    $hidden{'type'} = $type;
    my %tree = StorProc->fetch_one( 'escalation_trees', 'name', $name );
    my $got_form = 0;

    if ( $query->param('continue') || $query->param('close') ) {
	$page .= Forms->header( $page_title, $session_id, $top_menu );
	$got_form = 1;
    }
    elsif ( $query->param('cancel') ) {
	if ($obj_view eq 'new') {
	    $page .= Forms->header( $page_title, $session_id, $top_menu );
	    $got_form = 1;
	}
	else {
	    $obj_view = 'detail';
	}
    }
    elsif ( $query->param('add') ) {
	my %t = StorProc->fetch_one( 'escalation_trees', 'name', $name );
	if ( $t{'name'} ) {
	    push @errors, "Duplicate: Escalation tree \"$name\" already exists.";
	    $name     = undef;
	    $obj_view = 'new';
	}
	else {
	    my @values = ( \undef, $name, '', $type );
	    my $result = StorProc->insert_obj( 'escalation_trees', \@values );
	    if ( $result =~ /^Error/ ) {
		push @errors, $result;
	    }
	    else {
		$task = undef;
		delete $hidden{'task'};
		$obj_view = 'detail';
	    }
	}
    }
    elsif ( $query->param('save') ) {
	if ( $query->param('save_hostgroups') ) {
	    my %w = ( "$type\_escalation_id" => $tree{'tree_id'} );
	    my %u = ( "$type\_escalation_id" => '' );
	    my $result = StorProc->update_obj_where( 'hostgroups', \%u, \%w );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	    my %hostgroup_name = StorProc->get_table_objects('hostgroups');
	    my @hostgroups     = $query->$multi_param('hostgroups');
	    foreach my $assn (@hostgroups) {
		my %values = ( "$type\_escalation_id" => $tree{'tree_id'} );
		my $result = StorProc->update_obj( 'hostgroups', 'hostgroup_id', $hostgroup_name{$assn}, \%values );
		if ( $result =~ /^Error/ ) { push @errors, $result }
	    }
	    unless (@errors) {
		$obj_view = 'saved';
		$message  = "Hostgroups assigned.";
	    }

	}
	elsif ( $query->param('save_hosts') ) {
	    my %w = ( "$type\_escalation_id" => $tree{'tree_id'} );
	    my %u = ( "$type\_escalation_id" => '' );
	    my $result = StorProc->update_obj_where( 'hosts', \%u, \%w );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	    my %host_name = StorProc->get_table_objects('hosts');
	    my @hosts     = $query->$multi_param('hosts');
	    foreach my $assn (@hosts) {
		my %values = ( "$type\_escalation_id" => $tree{'tree_id'} );
		my $result = StorProc->update_obj( 'hosts', 'host_id', $host_name{$assn}, \%values );
		if ( $result =~ /^Error/ ) { push @errors, $result }
	    }
	    unless (@errors) {
		$obj_view = 'saved';
		$message  = "Hosts assigned.";
	    }
	}
	elsif ( $query->param('save_service_groups') ) {
	    my %w = ( 'escalation_id' => $tree{'tree_id'} );
	    my %u = ( 'escalation_id' => '' );
	    my $result = StorProc->update_obj_where( 'servicegroups', \%u, \%w );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	    my %servicegroup_name = StorProc->get_table_objects('servicegroups');
	    my @servicegroups     = $query->$multi_param('servicegroups');
	    foreach my $assn (@servicegroups) {
		my %values = ( 'escalation_id' => $tree{'tree_id'} );
		my $result = StorProc->update_obj( 'servicegroups', 'servicegroup_id', $servicegroup_name{$assn}, \%values );
		if ( $result =~ /^Error/ ) { push @errors, $result }
	    }
	    unless (@errors) {
		$obj_view = 'saved';
		$message  = "Service groups assigned.";
	    }
	}
	elsif ( $query->param('save_services') ) {
	    my %w = ( 'escalation' => $tree{'tree_id'} );
	    my %u = ( 'escalation' => '' );
	    my $result = StorProc->update_obj_where( 'service_names', \%u, \%w );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	    my %service_name = StorProc->get_table_objects('service_names');
	    my @services     = $query->$multi_param('service_names');
	    foreach my $assn (@services) {
		my %values = ( 'escalation' => $tree{'tree_id'} );
		my $result = StorProc->update_obj( 'service_names', 'servicename_id', $service_name{$assn}, \%values );
		if ( $result =~ /^Error/ ) { push @errors, $result }
		if ( $query->param('apply_hosts') ) {
		    my %values = ( 'escalation_id' => $tree{'tree_id'} );
		    my $result = StorProc->update_obj( 'services', 'servicename_id', $service_name{$assn}, \%values );
		    if ( $result =~ /^Error/ ) { push @errors, $result }
		}
	    }
	    unless (@errors) {
		$obj_view = 'saved';
		$message  = "Services assigned.";
	    }
	}
    }
    elsif ( $query->param('rename') ) {
	$page .= rename_object( '', $name );
	$got_form = 1;
    }
    elsif ( $query->param('bail') ) {
	$task     = 'modify';
	$obj_view = 'detail';
    }
    elsif ( $query->param('delete') or $query->param('confirm_delete') ) {
	$hidden{'task'} = 'modify';
	$page .= Forms->header( $page_title, $session_id, $top_menu );
	$page .= delete_object( '', $name );
	$got_form = 1;
    }
    elsif ( $query->param('add_escalation') ) {
	my $escalation = $query->param('escalation');
	if ($escalation) {
	    my %tree = StorProc->fetch_one( 'escalation_trees',     'name', $name );
	    my %esc  = StorProc->fetch_one( 'escalation_templates', 'name', $escalation );
	    my @values = ( $tree{'tree_id'}, $esc{'template_id'} );
	    my $result = StorProc->insert_obj( 'escalation_tree_template', \@values );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	    unless (@errors) {
		$obj_view = 'assign_contact_groups';
		$hidden{'id'} = $esc{'template_id'};
	    }
	    else {
		$obj_view = 'detail';
	    }
	}
	else {
	    $obj_view = 'detail';
	}
    }
    elsif ( $obj_view eq 'assign_contact_groups' && !$query->param('add_escalation') ) {
	my $id = $query->param('id') || $hidden{'id'};
	my @contactgroups = ();
	if ( $query->param('save_contact_groups') ) {
	    @contactgroups = $query->$multi_param('contactgroups');
	}
	else {

	    # Validate whether this escalation already has any associated contact groups,
	    # irrespective of whether any showed up on-screen at the time the user invoked
	    # the page execution.  (S/he may have modified the on-screen values since they
	    # were originally displayed.)
	    my %esc = StorProc->fetch_one( 'escalation_templates', 'template_id', $id );
	    my @contact_groups = StorProc->fetch_list( 'contactgroups', 'name' );
	    my @assigned = StorProc->get_tree_template_contactgroup( $tree{'tree_id'}, $esc{'template_id'} );
	    my %cgs;
	    foreach (@contact_groups) {
		$cgs{$_} = 1;
	    }
	    foreach (@assigned) {
		if ( defined( $cgs{$_} ) ) {
		    push @contactgroups, $_;
		    last;
		}
	    }
	}
	if ( $contactgroups[0] && $query->param('save_contact_groups') ) {
	    my %w = ( 'template_id' => $id, 'tree_id' => $tree{'tree_id'} );
	    my $result = StorProc->delete_one_where( 'tree_template_contactgroup', \%w );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	    foreach my $cg (@contactgroups) {
		my %c = StorProc->fetch_one( 'contactgroups', 'name', $cg );
		my @values = ( $tree{'tree_id'}, $id, $c{'contactgroup_id'} );
		my $result = StorProc->insert_obj( 'tree_template_contactgroup', \@values );
		if ( $result =~ /^Error/ ) { push @errors, $result }
	    }
	}
	elsif ( !$contactgroups[0] ) {
	    $required{'contactgroup'} = 1;
	    if ( $query->param('save_contact_groups') ) {
		push @errors, "Contact group required.<br>The configuration shown below has been reset to display the current saved setup.";
	    }
	    else {
		push @errors, "Contact group required.";
	    }
	}
	my $escalation = $query->param('escalation');
	if ( @errors || !$escalation ) {
	    $obj_view = 'assign_contact_groups';
	}
	else {
	    $obj_view = 'detail';
	}
    }
    elsif ( $obj_view eq 'remove_escalation' ) {
	my %w = ( 'template_id' => $hidden{'id'}, 'tree_id' => $tree{'tree_id'} );
	my $result = StorProc->delete_one_where( 'escalation_tree_template', \%w );
	if ( $result =~ /^Error/ ) { push @errors, $result }
	%w = ( 'template_id' => $hidden{'id'}, 'tree_id' => $tree{'tree_id'} );
	$result = StorProc->delete_one_where( 'tree_template_contactgroup', \%w );
	if ( $result =~ /^Error/ ) { push @errors, $result }
	$obj_view = 'detail';
    }
    unless ($got_form) {
	my %docs = Doc->escalations();
	$page .= Forms->header( $page_title, $session_id, $top_menu );
	if ( $obj_view eq 'new' ) {
	    my $validation_mini_profile = { name => { constraint => '[^/\\\\`~\+!\$\%\^\&\*\|\'\"<>\?,\(\)\'=\[\]\{\}\:\#;]+' } };
	    $page .= Validation->dfv_profile_javascript($validation_mini_profile);
	    $page .= Forms->form_top( 'Escalation Tree', Validation->dfv_onsubmit_javascript(
		"if (this.clicked == 'cancel') { return true; }"
	    ) );
	    if (@errors) { $page .= Forms->form_errors( \@errors ) }
	    $page .= Forms->text_box( 'Escalation tree name:', 'name', $name, $textsize{'name'}, '', '', '', $tab++ );
	    $page .= Forms->display_hidden( 'Type:', 'type', $type );
	    $hidden{'obj_view'} = 'new';
	    $page .= Forms->hidden( \%hidden );
	    $help{url} = StorProc->doc_section_url('How+to+configure+notifications+using+Nagios', 'HowtoconfigurenotificationsusingNagios-DefiningEscalationTrees');
	    $page .= Forms->form_bottom_buttons( \%add, \%cancel, \%help, $tab++ );
	}
	elsif ( $obj_view eq 'detail' ) {
	    $page .= Forms->escalation_top( $name, $session_id, $obj_view, $type, $nagios_ver );
	    my %tree = StorProc->fetch_one( 'escalation_trees', 'name', $name );
	    my ( $order, $first_notify, $members ) = StorProc->get_tree_templates( $tree{'tree_id'} );
	    my %members        = %{$members};
	    my %w              = ( 'type' => $tree{'type'} );
	    my @templates      = StorProc->fetch_list_where( 'escalation_templates', 'name', \%w, 'name' );
	    my @nonmembers     = ();
	    my %mems           = ();
	    my %ids            = ();
	    my %contact_groups = ();
	    my @members        = ();

	    foreach my $id ( @{$order} ) {
		my %cg   = ();
		my $type = "$tree{'type'}_escalation_templates";
		my @cgs  = StorProc->get_tree_template_contactgroup( $tree{'tree_id'}, $id );
		foreach (@cgs) {
		    $contact_groups{$id} .= "$_, ";
		}
		$contact_groups{$id} =~ s/,\s$// if defined $contact_groups{$id};
		push @members, $members{$id}[1];
		$mems{ $members{$id}[1] } = 1;
		$ids{ $members{$id}[1] }  = $id;
	    }
	    foreach my $temp (@templates) {
		unless ( $mems{$temp} ) { push @nonmembers, $temp }
	    }
	    if (@errors) { $page .= Forms->form_errors( \@errors ) }
	    $page .= Forms->wizard_doc( 'Managing Escalations', $docs{'escalation_tree'}, undef, 1 );
	    $page .=
	      Forms->manage_escalation_tree( $session_id, $view, $type, $name, $tree{'tree_id'}, \%ids, \@members, \@nonmembers,
		\%contact_groups, $first_notify, $tab++ );
	    $page .= Forms->hidden( \%hidden );
	    $help{url} =
	      ( $type eq 'host' )
	      ? StorProc->doc_section_url('How+to+configure+notifications+using+Nagios', 'HowtoconfigurenotificationsusingNagios-AddEscalationstoanEscalationTree')
	      : StorProc->doc_section_url('How+to+configure+notifications+using+Nagios', 'HowtoconfigurenotificationsusingNagios-ConfiguringEscalationTrees');
	    if ( $auth_delete{'escalations'} ) {
		$page .= Forms->form_bottom_buttons( \%delete, \%rename, \%close, \%help, $tab++ );
	    }
	    else {
		$page .= Forms->form_bottom_buttons( \%rename, \%close, \%help, $tab++ );
	    }
	}
	elsif ( $obj_view eq 'assign_contact_groups' ) {
	    $page .= Forms->escalation_top( $name, $session_id, $obj_view, $type, $nagios_ver );
	    unless ( $hidden{'id'} ) { $hidden{'id'} = $query->param('id') }
	    my %esc = StorProc->fetch_one( 'escalation_templates', 'template_id', $hidden{'id'} );
	    $hidden{'obj_view'} = 'assign_contact_groups';
	    $hidden{'type'}     = $type;
	    if (@errors) { $page .= Forms->form_errors( \@errors ) }
	    $page .= Forms->display_hidden( 'Escalation:', 'escalation', $esc{'name'} );
	    my @contact_groups = StorProc->fetch_list( 'contactgroups', 'name' );
	    my @assigned = StorProc->get_tree_template_contactgroup( $tree{'tree_id'}, $esc{'template_id'} );
	    $page .= Forms->wizard_doc( 'Assign Contact Groups', $docs{'contactgroup'}, undef, 1 );
	    $page .=
	      Forms->members( 'Contact groups:', 'contactgroups', \@assigned, \@contact_groups, $required{'contactgroup'}, '', '', '', $tab++ );
	    $page .= Forms->hidden( \%hidden );
	    $page .= Forms->form_bottom_buttons( \%save_contact_groups, $tab++ );
	}
	elsif ( $obj_view eq 'assign_hostgroups' ) {
	    my $doc = $docs{'host_hostgroup'};
	    if ( $type eq 'service' ) { $doc = $docs{'service_hostgroup'} }
	    my @assigned = StorProc->get_escalation_assigned( $tree{'tree_id'}, $type, 'hostgroups' );
	    my @unassigned = StorProc->fetch_list( 'hostgroups', 'name' );
	    $page .= Forms->escalation_top( $name, $session_id, $obj_view, $type, $nagios_ver );
	    $page .= Forms->wizard_doc( 'Assign Hostgroups', $doc, undef, 1 );
	    $page .= Forms->members( 'Host groups:', 'hostgroups', \@assigned, \@unassigned, '', 20, '', '', $tab++ );
	    $hidden{'save_hostgroups'} = 1;
	    $page .= Forms->hidden( \%hidden );
	    $help{url} =
	      ( $type eq 'host' )
	      ? StorProc->doc_section_url('How+to+configure+notifications+using+Nagios', 'HowtoconfigurenotificationsusingNagios-AssigningHostGroups')
	      : StorProc->doc_section_url('How+to+configure+notifications+using+Nagios', 'HowtoconfigurenotificationsusingNagios-ConfiguringEscalationTrees');
	    $page .= Forms->form_bottom_buttons( \%save, \%cancel, \%help, $tab++ );
	}
	elsif ( $obj_view eq 'assign_hosts' ) {
	    my $doc = $docs{'host_host'};
	    if ( $type eq 'service' ) { $doc = $docs{'service_host'} }
	    my @assigned = StorProc->get_escalation_assigned( $tree{'tree_id'}, $type, 'hosts' );
	    my @unassigned = StorProc->fetch_list( 'hosts', 'name' );
	    $page .= Forms->escalation_top( $name, $session_id, $obj_view, $type, $nagios_ver );
	    $page .= Forms->wizard_doc( 'Assign Hosts', $doc, undef, 1 );
	    $page .= Forms->members( 'Hosts:', 'hosts', \@assigned, \@unassigned, '', 20, '', '', $tab++ );
	    $hidden{'save_hosts'} = 1;
	    $page .= Forms->hidden( \%hidden );
	    $page .= Forms->form_bottom_buttons( \%save, \%cancel, $tab++ );
	}
	elsif ( $obj_view eq 'assign_service_groups' ) {
	    my @assigned = StorProc->get_escalation_assigned( $tree{'tree_id'}, 'service', 'servicegroups' );
	    my @unassigned = StorProc->fetch_list( 'servicegroups', 'name' );
	    $page .= Forms->escalation_top( $name, $session_id, $obj_view, $type, $nagios_ver );
	    $page .= Forms->wizard_doc( 'Assign Service Groups', $docs{'servicegroup'}, undef, 1 );
	    $page .= Forms->members( 'Service groups:', 'servicegroups', \@assigned, \@unassigned, '', 20, '', '', $tab++ );
	    $hidden{'save_service_groups'} = 1;
	    $page .= Forms->hidden( \%hidden );
	    $page .= Forms->form_bottom_buttons( \%save, \%cancel, $tab++ );
	}
	elsif ( $obj_view eq 'assign_services' ) {
	    my @assigned = StorProc->get_escalation_assigned( $tree{'tree_id'}, 'service', 'services' );
	    my @unassigned = StorProc->fetch_list( 'service_names', 'name' );
	    $page .= Forms->escalation_top( $name, $session_id, $obj_view, $type, $nagios_ver );
	    $page .= Forms->wizard_doc( 'Assign Services', $docs{'service'}, undef, 1 );
	    $page .= Forms->checkbox_left( 'Apply to hosts', 'apply_hosts', '', '', $tab++ );
	    $page .= Forms->members( 'Services:', 'service_names', \@assigned, \@unassigned, '', 20, '', '', $tab++ );
	    $hidden{'save_services'} = 1;
	    $page .= Forms->hidden( \%hidden );
	    $page .= Forms->form_bottom_buttons( \%save, \%cancel, $tab++ );
	}
	elsif ( $obj_view eq 'saved' ) {
	    $page .= Forms->escalation_top( $name, $session_id, $obj_view, $type, $nagios_ver );
	    $page .= Forms->display_hidden( 'Saved:', '', $message );
	    $page .= Forms->hidden( \%hidden );
	    $page .= Forms->form_bottom_buttons( \%close, $tab++ );
	}
    }
    return $page;
}

#
############################################################################
# Profiles
#
############################################################################
# Host profile
#

sub host_profile() {
    local $_;

    my $name = $query->param('name');
    unless ($obj_view) { $obj_view = 'host_detail' }
    $hidden{'obj_view'} = $obj_view;
    my %profile = StorProc->fetch_one( 'profiles_host', 'name', $name );
    push @errors, delete $profile{'error'} if defined $profile{'error'};
    my $form = undef;

    if ( $query->param('add') ) {
	$name =~ s/^\s+|\s+$//g;
	%profile = StorProc->fetch_one( 'profiles_host', 'name', $name );
	push @errors, delete $profile{'error'} if defined $profile{'error'};
	my $description = $query->param('description');
	my $template    = $query->param('template');
	unless ( $profile{'name'} || $name eq '' ) {
	    if ($template) {
		my $data = "<?xml version=\"1.0\" encoding=\"iso-8859-1\" ?>\n<data>\n</data>";
		$profile{'description'} = $description;
		my %t = StorProc->fetch_one( 'host_templates', 'name', $template );
		$profile{'hosttemplate_id'} = $t{'hosttemplate_id'};
		my @values = ( \undef, $name, $description, $t{'hosttemplate_id'}, '', '', '', $data );
		my $id = StorProc->insert_obj_id( 'profiles_host', \@values, 'hostprofile_id' );
		if ( $id =~ /^Error/ ) {
		    push @errors, $id;
		    %profile = ();
		}
		else {
		    $profile{'hostprofile_id'} = $id;
		}
	    }
	    else {
		push @errors, "Check required fields.";
		$required{'template'} = 1;
	    }
	}
	else {
	    push @errors, "Check the name field. It's either blank or that name is already in use.";
	}
	unless (@errors) { $obj_view = 'host_detail' }
    }
    elsif ($query->param('close')
	|| $query->param('cancel')
	|| $query->param('continue') )
    {
	$form .= Forms->header( $page_title, $session_id, $top_menu );
	$obj_view = 'close';
    }
    elsif ( $query->param('export') ) {
	use MonarchProfileExport;
	my $results = ProfileExporter->host_profile( $profile{'hostprofile_id'}, "$doc_root/monarch/download" );
	if ( $results =~ /^Error/ ) {
	    push @errors, $results;
	}
	else {
	    $obj_view = 'exported';
	}
    }
    elsif ( $query->param('save') ) {
	if ( $obj_view eq 'host_detail' ) {
	    my %data          = parse_query( 'host_templates', 'host_overrides' );
	    my $host_template = $query->param('template');
	    my $extinfo       = $query->param('extended_info');
	    if ($host_template) {
		my %values = ();
		$values{'description'} = $query->param('description');
		my %t = StorProc->fetch_one( 'host_templates', 'name', $host_template );
		$values{'host_template_id'} = $t{'hosttemplate_id'};
		my %e = StorProc->fetch_one( 'extended_host_info_templates', 'name', $extinfo );
		$values{'host_extinfo_id'} = $e{'hostextinfo_id'};
		my $result = StorProc->update_obj( 'profiles_host', 'hostprofile_id', $profile{'hostprofile_id'}, \%values );
		if ( $result =~ /^Error/ ) { push @errors, $result }
		my %where = ( 'hostprofile_id' => $profile{'hostprofile_id'} );
		$result = StorProc->delete_one_where( 'hostprofile_overrides', \%where );
		if ( $result =~ /^Error/ ) { push @errors, $result }

		if (   $data{'check_period'}
		    || $data{'notification_period'}
		    || $data{'check_command'}
		    || $data{'event_handler'}
		    || $data{'data'} )
		{
		    my @values = (
			$profile{'hostprofile_id'}, $data{'check_period'},  $data{'notification_period'},
			$data{'check_command'},     $data{'event_handler'}, $data{'data'}
		    );
		    my $result = StorProc->insert_obj( 'hostprofile_overrides', \@values );
		    if ( $result =~ /^Error/ ) { push @errors, $result }
		}
		if ( $query->param('contactgroup_override') ) {
		    my %where = ( 'hostprofile_id' => $profile{'hostprofile_id'} );
		    my $result = StorProc->delete_one_where( 'contactgroup_host_profile', \%where );
		    if ( $result =~ /^Error/ ) { push @errors, $result }
		}
		else {
		    my %where = ( 'hostprofile_id' => $profile{'hostprofile_id'} );
		    my $result = StorProc->delete_one_where( 'contactgroup_host_profile', \%where );
		    if ( $result =~ /^Error/ ) { push @errors, $result }
		    my @mems = $query->$multi_param('contactgroup');
		    foreach (@mems) {
			my %cg = StorProc->fetch_one( 'contactgroups', 'name', $_ );
			my @vals = ( $cg{'contactgroup_id'}, $profile{'hostprofile_id'} );
			$result = StorProc->insert_obj( 'contactgroup_host_profile', \@vals );
			if ( $result =~ /^Error/ ) { push @errors, $result }
		    }
		}
	    }
	    else {
		push @errors, 'Error: missing required fields.';
		$required{'template'} = 1;
	    }
	    unless (@errors) { $obj_view = 'saved' }
	}
	elsif ( $obj_view eq 'parents' ) {
	    my @parents = $query->$multi_param('parents');
	    my $result = StorProc->delete_all( 'profile_parent', 'hostprofile_id', $profile{'hostprofile_id'} );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	    foreach my $p (@parents) {
		if ( !$p ) { next }
		my %h = StorProc->fetch_one( 'hosts', 'name', $p );
		my @vals = ( $profile{'hostprofile_id'}, $h{'host_id'} );
		$result = StorProc->insert_obj( 'profile_parent', \@vals );
		if ( $result =~ /^Error/ ) { push @errors, $result }
	    }
	    unless (@errors) {
		$obj_view           = 'saved';
		$hidden{'obj_view'} = 'parents';
		$hidden{'apply'}    = 0;
	    }
	}
	elsif ( $obj_view eq 'hostgroups' ) {
	    my @hostgroups = $query->$multi_param('hostgroups');
	    my $result = StorProc->delete_all( 'profile_hostgroup', 'hostprofile_id', $profile{'hostprofile_id'} );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	    foreach my $hg (@hostgroups) {
		if ( !$hg ) { next }
		my %h = StorProc->fetch_one( 'hostgroups', 'name', $hg );
		my @vals = ( $profile{'hostprofile_id'}, $h{'hostgroup_id'} );
		$result = StorProc->insert_obj( 'profile_hostgroup', \@vals );
		if ( $result =~ /^Error/ ) { push @errors, $result }
	    }
	    unless (@errors) {
		$obj_view           = 'saved';
		$hidden{'obj_view'} = 'hostgroups';
		$hidden{'apply'}    = 0;
	    }

	}
	elsif ( $obj_view eq 'escalation_trees' ) {
	    my %values          = ();
	    my $host_escalation = $query->param('host_escalation');
	    my %w               = ( 'name' => $host_escalation, 'type' => 'host' );
	    my %t               = StorProc->fetch_one_where( 'escalation_trees', \%w );
	    $values{'host_escalation_id'} = $t{'tree_id'};
	    my $service_escalation = $query->param('service_escalation');
	    %w = ( 'name' => $service_escalation, 'type' => 'service' );
	    %t = StorProc->fetch_one_where( 'escalation_trees', \%w );
	    $values{'service_escalation_id'} = $t{'tree_id'};
	    my $result = StorProc->update_obj( 'profiles_host', 'name', $name, \%values );

	    if ( $result =~ /^Error/ ) {
		push @errors, $result;
	    }
	    else {
		$obj_view = 'saved';
	    }
	}
	elsif ( $obj_view eq 'externals' ) {
	    my @externals = $query->$multi_param('externals');
	    my $result = StorProc->delete_all( 'external_host_profile', 'hostprofile_id', $profile{'hostprofile_id'} );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	    foreach my $e (@externals) {
		my %e = StorProc->fetch_one( 'externals', 'name', $e );
		my @vals = ( $e{'external_id'}, $profile{'hostprofile_id'} );
		$result = StorProc->insert_obj( 'external_host_profile', \@vals );
		if ( $result =~ /^Error/ ) { push @errors, $result }
	    }
	    unless (@errors) {
		$obj_view           = 'saved';
		$hidden{'obj_view'} = 'externals';
		$hidden{'apply'}    = 1;
	    }

	}
	elsif ( $obj_view eq 'service_profiles' ) {
	    my @service_profile = $query->$multi_param('service_profiles');
	    my $result = StorProc->delete_all( 'profile_host_profile_service', 'hostprofile_id', $profile{'hostprofile_id'} );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	    foreach my $p (@service_profile) {
		my %s = StorProc->fetch_one( 'profiles_service', 'name', $p );
		push @errors, delete $s{'error'} if defined $s{'error'};
		my @vals = ( $profile{'hostprofile_id'}, $s{'serviceprofile_id'} );
		$result = StorProc->insert_obj( 'profile_host_profile_service', \@vals );
		if ( $result =~ /^Error/ ) { push @errors, $result }
	    }
	    unless (@errors) { $obj_view = 'saved' }
	}
	elsif ( $obj_view eq 'assign_hosts' ) {
	    my @hosts  = $query->$multi_param('hosts');
	    my %values = ( 'hostprofile_id' => '0' );
	    my $result = StorProc->update_obj( 'hosts', 'hostprofile_id', $profile{'hostprofile_id'}, \%values );
	    foreach my $host (@hosts) {
		my %values = ( 'hostprofile_id' => $profile{'hostprofile_id'} );
		my $result = StorProc->update_obj( 'hosts', 'name', $host, \%values );
		if ( $result =~ /^Error/ ) { push @errors, $result }
	    }
	    unless (@errors) { $obj_view = 'saved' }

	}
	elsif ( $obj_view eq 'assign_hostgroups' ) {
	    my @hostgroups = $query->$multi_param('hostgroups');
	    my %values     = ( 'hostprofile_id' => '0' );
	    my $result     = StorProc->update_obj( 'hostgroups', 'hostprofile_id', $profile{'hostprofile_id'}, \%values );
	    foreach my $hostgroup (@hostgroups) {
		my %values = ( 'hostprofile_id' => $profile{'hostprofile_id'} );
		my $result = StorProc->update_obj( 'hostgroups', 'name', $hostgroup, \%values );
		if ( $result =~ /^Error/ ) { push @errors, $result }
	    }
	    unless (@errors) { $obj_view = 'saved' }
	}
    }
    elsif ( $query->param('apply') ) {
	my $hostgroups_select    = $query->param('hostgroups_select');
	my $hosts_select         = $query->param('hosts_select');
	my $apply_parents        = $query->param('apply_parents');
	my $apply_hostgroups     = $query->param('apply_hostgroups');
	my $apply_escalations    = $query->param('apply_escalations');
	my $apply_contactgroups  = $query->param('apply_contactgroups');
	my $apply_variables      = $query->param('apply_variables');
	my $apply_detail         = $query->param('apply_detail');
	my $apply_host_externals = $query->param('apply_host_externals');
	my $apply_services       = $query->param('apply_services');

	my $data = "<?xml version=\"1.0\" encoding=\"iso-8859-1\" ?>\n<data>";
	if ($hostgroups_select) {
	    $data .= qq(
  <prop name="hostgroups_select"><![CDATA[checked]]>
  </prop>);
	}
	if ($hosts_select) {
	    $data .= qq(
  <prop name="hosts_select"><![CDATA[checked]]>
  </prop>);
	}
	if ($apply_parents) {
	    $data .= qq(
  <prop name="apply_parents"><![CDATA[checked]]>
  </prop>);
	}
	if ($apply_hostgroups) {
	    $data .= qq(
  <prop name="apply_hostgroups"><![CDATA[checked]]>
  </prop>);
	}
	if ($apply_escalations) {
	    $data .= qq(
  <prop name="apply_escalations"><![CDATA[checked]]>
  </prop>);
	}
	if ($apply_contactgroups) {
	    $data .= qq(
  <prop name="apply_contactgroups"><![CDATA[checked]]>
  </prop>);
	}
	if ($apply_variables) {
	    $data .= qq(
  <prop name="apply_variables"><![CDATA[checked]]>
  </prop>);
	}
	if ($apply_detail) {
	    $data .= qq(
  <prop name="apply_detail"><![CDATA[checked]]>
  </prop>);
	}
	if ($apply_host_externals) {
	    $data .= qq(
  <prop name="apply_host_externals"><![CDATA[checked]]>
  </prop>);
	}
	$data .= qq(
  <prop name="apply_services"><![CDATA[$apply_services]]>
  </prop>);
	$data .= "\n</data>\n";

	my %where = ( 'hostprofile_id' => $profile{'hostprofile_id'} );
	my @profiles = StorProc->fetch_list_where( 'profile_host_profile_service', 'serviceprofile_id', \%where );
	my @hosts = ();
	unless ($hostgroups_select || $hosts_select) {
	    push @errors, 'You must apply to hostgroups and/or hosts for any action to occur.';
	}
	unless (@errors) {
	    if ($hostgroups_select) {
		my %where = ( 'hostprofile_id' => $profile{'hostprofile_id'} );
		my @hgs = StorProc->fetch_list_where( 'hostgroups', 'hostgroup_id', \%where );
		foreach my $hg (@hgs) {
		    %where = ( 'hostgroup_id' => $hg );
		    my @hs = StorProc->fetch_list_where( 'hostgroup_host', 'host_id', \%where );
		    push( @hosts, @hs );
		}
	    }
	    if ($hosts_select) {
		my %where = ( 'hostprofile_id' => $profile{'hostprofile_id'} );
		my @hs = StorProc->fetch_list_where( 'hosts', 'host_id', \%where );
		push( @hosts, @hs );
	    }
	    unless (@hosts) {
		push @errors, 'No chosen hosts reference this host profile.';
	    }
	}
	unless (@errors) {
	    my %hosts = ();
	    foreach my $host (@hosts) {
		$hosts{$host} = 1;
	    }
	    my @distinct_hosts = keys %hosts;
	    foreach my $hid (@distinct_hosts) {
		if ($apply_parents) {
		    my $result = StorProc->delete_all( 'host_parent', 'host_id', $hid );
		    if ( $result =~ /^Error/ ) { push @errors, $result }
		    my %w = ( 'hostprofile_id' => $profile{'hostprofile_id'} );
		    my @parents = StorProc->fetch_list_where( 'profile_parent', 'host_id', \%w );
		    foreach my $pid (@parents) {
			## Because this is a bulk operation against independently established lists of hosts,
			## we simply ignore an attempt to apply a parent to the same host, rather than complain
			## about it.  This adaptive action should make the host profile easier to use in practice.
			unless ( $pid == $hid ) {
			    my @vals = ( $hid, $pid );
			    my $result = StorProc->insert_obj( 'host_parent', \@vals );
			    if ( $result =~ /^Error/ ) { push @errors, $result }
			}
		    }
		}
		if ($apply_hostgroups) {
		    my $result = StorProc->delete_all( 'hostgroup_host', 'host_id', $hid );
		    if ( $result =~ /^Error/ ) { push @errors, $result }
		    my %w = ( 'hostprofile_id' => $profile{'hostprofile_id'} );
		    my @hostgroups = StorProc->fetch_list_where( 'profile_hostgroup', 'hostgroup_id', \%w );
		    foreach my $hgid (@hostgroups) {
			my @vals = ( $hgid, $hid );
			my $result = StorProc->insert_obj( 'hostgroup_host', \@vals );
			if ( $result =~ /^Error/ ) { push @errors, $result }
		    }
		}
		if ($apply_contactgroups) {
		    my %w = ( 'host_id' => $hid );
		    my $result = StorProc->delete_one_where( 'contactgroup_host', \%w );
		    if ( $result =~ /^Error/ ) { push @errors, $result }
		    %w = ( 'hostprofile_id' => $profile{'hostprofile_id'} );
		    my @contactgroups = StorProc->fetch_list_where( 'contactgroup_host_profile', 'contactgroup_id', \%w );
		    foreach my $cgid (@contactgroups) {
			my @vals = ( $cgid, $hid );
			my $result = StorProc->insert_obj( 'contactgroup_host', \@vals );
			if ( $result =~ /^Error/ ) { push @errors, $result }
		    }
		}
		if ( $apply_services eq 'replace' ) {
		    my $result = StorProc->delete_all( 'serviceprofile_host', 'host_id', $hid );
		    if ( $result =~ /^Error/ ) { push @errors, $result }
		    foreach my $spid (@profiles) {
			my @vals = ( $spid, $hid );
			my $result = StorProc->insert_obj( 'serviceprofile_host', \@vals );
			if ( $result =~ /^Error/ ) { push @errors, $result }
		    }
		}
		else {
		    foreach my $spid (@profiles) {
			my %w = ( 'serviceprofile_id' => $spid, 'host_id' => $hid );
			my %p = StorProc->fetch_one_where( 'serviceprofile_host', \%w );
			unless ( $p{'host_id'} ) {
			    my @vals = ( $spid, $hid );
			    my $result = StorProc->insert_obj( 'serviceprofile_host', \@vals );
			    if ( $result =~ /^Error/ ) { push @errors, $result }
			}
		    }
		}
	    }
	    if ($apply_escalations) {
		## FIX MAJOR:  combine the host_escalation_id and service_escalation_id updates into just one database call per host
		## FIX MAJOR:  we are updating the wrong hosts here:  this affects all hosts with the specified host profile,
		## when we should be looping and only updating @distinct_hosts
		my %vals = ( 'host_escalation_id' => $profile{'host_escalation_id'} );
		my $result = StorProc->update_obj( 'hosts', 'hostprofile_id', $profile{'hostprofile_id'}, \%vals );
		## FIX MAJOR:  we are updating the wrong hosts here:  this affects all hosts with the specified host profile,
		## when we should be looping and only updating @distinct_hosts
		if ( $result =~ /^Error/ ) { push @errors, $result }
		%vals = ( 'service_escalation_id' => $profile{'service_escalation_id'} );
		$result = StorProc->update_obj( 'hosts', 'hostprofile_id', $profile{'hostprofile_id'}, \%vals );
		if ( $result =~ /^Error/ ) { push @errors, $result }
	    }
	    if ($apply_detail) {
		## FIX MAJOR:  do we also need to do this updating for references through hostgroups,
		## somehow (via the hostgroups and hostgroup_host tables)?  Or should it all be covered by @distinct_hosts ?
		## FIX MAJOR:  we are updating the wrong hosts here:  this affects all hosts with the specified host profile,
		## when we should be looping and only updating @distinct_hosts
		my %vals = ( 'hosttemplate_id' => $profile{'host_template_id'} );
		my $result = StorProc->update_obj( 'hosts', 'hostprofile_id', $profile{'hostprofile_id'}, \%vals );
		if ( $result =~ /^Error/ ) { push @errors, $result }
		my @errs = StorProc->host_profile_apply( $profile{'hostprofile_id'}, \@distinct_hosts, !$apply_detail, !$apply_variables );
		if (@errs) { push( @errors, @errs ) }
		## FIX MAJOR:  Compare this application of hostextinfo_id to what happens inside
		## StorProc->host_profile_apply().  Why are we overriding that setting?
		## FIX MAJOR:  we are updating the wrong hosts here:  this affects all hosts with the specified host profile,
		## when we should be looping and only updating @distinct_hosts
		## FIX MINOR:  probably just drop these lines, as they seem to be otherwise redundant anyway
		%vals = ( 'hostextinfo_id' => $profile{'host_extinfo_id'} );
		$result = StorProc->update_obj( 'hosts', 'hostprofile_id', $profile{'hostprofile_id'}, \%vals );
		if ( $result =~ /^Error/ ) { push @errors, $result }
	    }
	    elsif ($apply_variables) {
		my @errs = StorProc->host_profile_apply( $profile{'hostprofile_id'}, \@distinct_hosts, !$apply_detail, !$apply_variables );
		if (@errs) { push( @errors, @errs ) }
	    }
	    if ($apply_host_externals) {
		if ($enable_externals) {
		    # FIX LATER:  There is still a lot of nested database access here.  That might be very slow to execute with
		    # a large configuration.  See if we can optimize by pulling complete copies of certain tables back from the
		    # database before we start looping, then just access those local copies within the loop structure here.

		    my %w = ( 'hostprofile_id' => $profile{'hostprofile_id'} );
		    my @externals = StorProc->fetch_list_where( 'external_host_profile', 'external_id', \%w );
		    foreach my $hid (@distinct_hosts) {
			if ( $apply_services eq 'replace' ) {
			    my $result = StorProc->delete_all( 'external_host', 'host_id', $hid );
			    if ( $result =~ /^Error/ ) { push @errors, $result }
			    foreach my $ext (@externals) {
				my %external = StorProc->fetch_one( 'externals', 'external_id', $ext );
				my @vals = ( $ext, $hid, $external{'display'}, $DEFINED_REF );
				$result = StorProc->insert_obj( 'external_host', \@vals );
				if ( $result =~ /^Error/ ) { push @errors, $result }
			    }
			}
			if ( $apply_services eq 'merge' ) {
			    foreach my $ext (@externals) {
				my %where = (
				    'external_id' => $ext,
				    'host_id'     => $hid
				);
				my @host_externals = StorProc->fetch_list_where( 'external_host', 'modified', \%where );
				if (@host_externals) {
				    if ($host_externals[0] == 0) {
					my %external = StorProc->fetch_one( 'externals', 'external_id', $ext );
					my %values = ( 'data' => $external{'display'}, 'modified' => $DEFINED_REF );
					my $result = StorProc->update_obj_where( 'external_host', \%values, \%where );
					if ( $result =~ /^Error/ ) { push @errors, $result }
				    }
				}
				else {
				    my %external = StorProc->fetch_one( 'externals', 'external_id', $ext );
				    my @vals = ( $ext, $hid, $external{'display'}, $DEFINED_REF );
				    my $result = StorProc->insert_obj( 'external_host', \@vals );
				    if ( $result =~ /^Error/ ) { push @errors, $result }
				}
			    }
			}
		    }
		}
	    }
	    # FIX MAJOR:  Ought we to also pass a user-selectable $apply_service_externals flag here, to
	    # control whether service externals within services within the host profile are applied?  And
	    # should we modify the StorProc->service_profile_apply() routine to ensure that we perhaps do
	    # different things for replace and merge actions, with respect to such service externals?
	    my ( $cnt, $err ) = StorProc->service_profile_apply( \@profiles, $apply_services, \@distinct_hosts );
	    if ($err) { push( @errors, @{$err} ) }
	}
	my %value = ( 'data' => $data );
	my $result = StorProc->update_obj( 'profiles_host', 'name', $name, \%value );
	if ( $result =~ /^Error/ ) { push @errors, $result }
	%profile = StorProc->fetch_one( 'profiles_host', 'name', $name );
	push @errors, delete $profile{'error'} if defined $profile{'error'};
	unless (@errors) { $obj_view = 'applied' }
    }
    elsif ( $query->param('rename') ) {
	if ( $query->param('new_name') ) {
	    my $new_name = $query->param('new_name');
	    $new_name =~ s/^\s+|\s+$//g;
	    my %n = StorProc->fetch_one( 'profiles_host', 'name', $new_name );
	    push @errors, delete $n{'error'} if defined $n{'error'};
	    if ( $n{'name'} ) {
		push @errors, "A host profile named \"$new_name\" already exists. Please specify another name.";
	    }
	    else {
		my %values = ( 'name' => $new_name );
		my $result = StorProc->update_obj( 'profiles_host', 'name', $name, \%values );
		if ( $result =~ /error/i ) {
		    push @errors, $result;
		}
		else {
		    $name         = $new_name;
		    $obj_view     = 'host_detail';
		    $refresh_left = 1;
		}
	    }
	}
	else {
	    $obj_view = 'rename';
	}
    }
    elsif ( $query->param('delete') || $query->param('confirm_delete') ) {
	my %w = ( 'hostprofile_id' => $profile{'hostprofile_id'} );
	my @hids = StorProc->fetch_list_where( 'hosts', 'host_id', \%w );
	if ( $query->param('confirm_delete') ) {
	    my %values = ( 'hostprofile_id' => '0' );
	    my $result = StorProc->update_obj( 'hosts', 'hostprofile_id', $profile{'hostprofile_id'}, \%values );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	    $result = StorProc->update_obj( 'hostgroups', 'hostprofile_id', $profile{'hostprofile_id'}, \%values );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	    $result = StorProc->delete_all( 'profiles_host', 'hostprofile_id', $profile{'hostprofile_id'} );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	    unless (@errors) {
		$obj_view     = 'deleted';
		$refresh_left = 1;
	    }
	}
	elsif ( $query->param('task') eq 'No' ) {
	    $obj_view = 'host_detail';
	}
	else {
	    foreach my $name ( $query->param ) {
		unless ( $name eq 'nocache' ) {
		    $hidden{$name} = $query->param($name);
		}
	    }
	    delete $hidden{'task'};
	    $obj_view = 'delete';
	}
    }
    my %docs   = Doc->host_profile();
    my %save   = ( 'name' => 'save', 'value' => 'Save' );
    my %apply  = ( 'name' => 'apply', 'value' => 'Apply' );
    my %export = ( 'name' => 'export', 'value' => 'Export' );
    my %obj    = ();
    $form .= Forms->header( $page_title, $session_id, $top_menu, '', $refresh_left );
    if ( $obj_view eq 'host_detail' ) {
	$form .= Forms->host_profile_top( $name, $session_id, $obj_view, $auth_add{'externals'}, \%obj );
	my $template_form = build_host_template($name);
	if (@errors) { $form .= Forms->form_errors( \@errors ) }
	$form .= Forms->text_box( 'Description:', 'description', $profile{'description'}, $textsize{'description'},
	    '', $docs{'description'}, '', $tab++ );
	$form .= $template_form;
	$form .= Forms->wizard_doc( 'Additional Per-Host-Profile Options', undef, undef, 1 );
	my @members = StorProc->fetch_list( 'extended_host_info_templates', 'name' );
	my %w = ( 'hostextinfo_id' => $profile{'host_extinfo_id'} );
	my %t = StorProc->fetch_one_where( 'extended_host_info_templates', \%w );
	$form .= Forms->list_box(
	    'Extended host info template:',
	    'extended_info', \@members, $t{'name'}, '', $docs{'extended_host_info_template'},
	    '', $tab++
	);
	my $path = $query->param('path');
	$hidden{'obj_view'} = 'host_detail';
	$form .= Forms->hidden( \%hidden );
	$help{url} = StorProc->doc_section_url('How+to+create+host+profiles', 'Howtocreatehostprofiles-HostDetail');
	$form .= Forms->form_bottom_buttons( \%save, \%delete, \%rename, \%export, \%close, \%help, $tab++ );
    }
    elsif ( $obj_view eq 'parents' ) {
	my @parents = StorProc->get_profile_parent( $profile{'hostprofile_id'} );
	$form .= Forms->host_profile_top( $name, $session_id, $obj_view, $auth_add{'externals'}, \%obj );
	if (@errors) { $form .= Forms->form_errors( \@errors ) }
	$form .= Forms->wizard_doc( 'Parents', $docs{'parents'}, undef, 1 );
	my @nonmembers = StorProc->fetch_list( 'hosts', 'name' );
	$form .= Forms->members( 'Parents:', 'parents', \@parents, \@nonmembers, '', 20, $docs{'parents'}, '', $tab++ );
	$form .= Forms->hidden( \%hidden );
	$help{url} = StorProc->doc_section_url('How+to+create+host+profiles', 'Howtocreatehostprofiles-Parents');
	$form .= Forms->form_bottom_buttons( \%save, \%help, $tab++ );
    }
    elsif ( $obj_view eq 'hostgroups' ) {
	my @hostgroups = StorProc->get_profile_hostgroup( $profile{'hostprofile_id'} );
	$form .= Forms->host_profile_top( $name, $session_id, $obj_view, $auth_add{'externals'}, \%obj );
	if (@errors) { $form .= Forms->form_errors( \@errors ) }
	$form .= Forms->wizard_doc( 'Hostgroups', $docs{'hostgroups'}, undef, 1 );
	my @nonmembers = StorProc->fetch_list( 'hostgroups', 'name' );
	$form .= Forms->members( 'Hostgroups:', 'hostgroups', \@hostgroups, \@nonmembers, '', 20, $docs{'hostgroups'} );
	$form .= Forms->hidden( \%hidden );
	$help{url} = StorProc->doc_section_url('How+to+create+host+profiles', 'Howtocreatehostprofiles-HostGroups');
	$form .= Forms->form_bottom_buttons( \%save, \%help, $tab++ );
    }
    elsif ( $obj_view eq 'escalation_trees' ) {
	my $host_escalation    = $query->param('host_escalation');
	my $service_escalation = $query->param('service_escalation');
	$form .= Forms->host_profile_top( $name, $session_id, $obj_view, $auth_add{'externals'}, \%obj );
	if (@errors) { $form .= Forms->form_errors( \@errors ) }
	$form .= Forms->wizard_doc( 'Escalation Trees', $docs{'escalations'}, undef, 1 );
	unless ($host_escalation) {
	    my %w = ( 'tree_id' => $profile{'host_escalation_id'} );
	    my %t = StorProc->fetch_one_where( 'escalation_trees', \%w );
	    $host_escalation = $t{'name'};
	}
	my %where = ( 'type' => 'host' );
	my @members = ();
	@members = ('-- remove escalation tree --') if ($host_escalation && $host_escalation ne '-- no host escalation trees --');
	push( @members, StorProc->fetch_list_where( 'escalation_trees', 'name', \%where ) );
	$form .= Forms->list_box_submit( 'Host escalation tree:',
	    'host_escalation', \@members, $host_escalation, '', $docs{'host_escalation_tree'}, $tab++ );
	if ($host_escalation && $host_escalation ne '-- no host escalation trees --' && $host_escalation ne '-- remove escalation tree --') {
	    my ( $ranks, $templates ) = StorProc->get_tree_detail($host_escalation);
	    my %ranks     = %{$ranks};
	    my %templates = %{$templates};
	    $form .= Forms->escalation_tree( \%ranks, \%templates, 'escalations' );
	}
	unless ($service_escalation) {
	    my %w = ( 'tree_id' => $profile{'service_escalation_id'} );
	    my %t = StorProc->fetch_one_where( 'escalation_trees', \%w );
	    $service_escalation = $t{'name'};
	}
	%where = ( 'type' => 'service' );
	@members = ();
	@members = ('-- remove escalation tree --') if ($service_escalation && $service_escalation ne '-- no service escalation trees --');
	push( @members, StorProc->fetch_list_where( 'escalation_trees', 'name', \%where ) );
	$form .= Forms->list_box_submit( 'Service escalation tree:',
	    'service_escalation', \@members, $service_escalation, '', $docs{'service_escalation_tree'}, $tab++ );
	if ($service_escalation && $service_escalation ne '-- no service escalation trees --' && $service_escalation ne '-- remove escalation tree --') {
	    my ( $ranks, $templates ) = StorProc->get_tree_detail($service_escalation);
	    my %ranks     = %{$ranks};
	    my %templates = %{$templates};
	    $form .= Forms->escalation_tree( \%ranks, \%templates, 'escalations' );
	}
	$form .= Forms->hidden( \%hidden );
	$help{url} = StorProc->doc_section_url('How+to+create+host+profiles', 'Howtocreatehostprofiles-EscalationTrees');
	$form .= Forms->form_bottom_buttons( \%save, \%help, $tab++ );
    }
    elsif ( $obj_view eq 'externals' ) {
	$form .= Forms->host_profile_top( $name, $session_id, $obj_view, $auth_add{'externals'}, \%obj );
	if (@errors) { $form .= Forms->form_errors( \@errors ) }
	my @members    = StorProc->get_profile_external( $profile{'hostprofile_id'} );
	my %where      = ( 'type' => 'host' );
	my @nonmembers = StorProc->fetch_list_where( 'externals', 'name', \%where );
	$form .= Forms->wizard_doc( 'Host Externals', $docs{'host_externals'}, undef, 1 );
	$form .= Forms->members( 'Host externals:', 'externals', \@members, \@nonmembers );
	$form .= Forms->hidden( \%hidden );
	$help{url} = StorProc->doc_section_url('How+to+configure+externals');
	$form .= Forms->form_bottom_buttons( \%save, \%help, $tab++ );
    }
    elsif ( $obj_view eq 'service_profiles' ) {
	$form .= Forms->host_profile_top( $name, $session_id, $obj_view, $auth_add{'externals'}, \%obj );
	if (@errors) { $form .= Forms->form_errors( \@errors ) }
	$form .= Forms->wizard_doc( 'Service Profiles', $docs{'service_profiles'}, undef, 1 );
	my @members = ();
	my %w       = ( 'hostprofile_id' => $profile{'hostprofile_id'} );
	my @sids    = StorProc->fetch_list_where( 'profile_host_profile_service', 'serviceprofile_id', \%w );
	foreach (@sids) {
	    my %s = StorProc->fetch_one( 'profiles_service', 'serviceprofile_id', $_ );
	    push @errors, delete $s{'error'} if defined $s{'error'};
	    if ( $s{'name'} ) { push @members, $s{'name'} }
	}
	my @nonmembers = StorProc->fetch_list( 'profiles_service', 'name' );
	$form .= Forms->members( 'Service profiles:', 'service_profiles', \@members, \@nonmembers, '', '20', $docs{'profiles'}, '', $tab++ );
	$hidden{'obj_view'} = 'service_profiles';
	$form .= Forms->hidden( \%hidden );
	$help{url} = StorProc->doc_section_url('How+to+create+host+profiles', 'Howtocreatehostprofiles-ServiceProfiles');
	$form .= Forms->form_bottom_buttons( \%save, \%help, $tab++ );
    }
    elsif ( $obj_view eq 'assign_hosts' ) {
	$form .= Forms->host_profile_top( $name, $session_id, $obj_view, $auth_add{'externals'}, \%obj );
	if (@errors) { $form .= Forms->form_errors( \@errors ) }
	my %w = ( 'hostprofile_id' => $profile{'hostprofile_id'} );
	my @members = StorProc->fetch_list_where( 'hosts', 'name', \%w );
	my @nonmembers = StorProc->fetch_list( 'hosts', 'name' );
	$form .= Forms->wizard_doc( 'Assign Hosts', $docs{'assign_hosts'}, undef, 1 );
	$form .= Forms->members( 'Hosts:', 'hosts', \@members, \@nonmembers, '', '20', $docs{'hosts'} );
	$form .= Forms->hidden( \%hidden );
	$help{url} = StorProc->doc_section_url('How+to+create+host+profiles', 'Howtocreatehostprofiles-AssignHosts');
	$form .= Forms->form_bottom_buttons( \%save, \%help, $tab++ );
    }
    elsif ( $obj_view eq 'assign_hostgroups' ) {
	$form .= Forms->host_profile_top( $name, $session_id, $obj_view, $auth_add{'externals'}, \%obj );
	if (@errors) { $form .= Forms->form_errors( \@errors ) }
	my %w = ( 'hostprofile_id' => $profile{'hostprofile_id'} );
	my @members = StorProc->fetch_list_where( 'hostgroups', 'name', \%w );
	my @nonmembers = StorProc->fetch_list( 'hostgroups', 'name' );
	$form .= Forms->wizard_doc( 'Assign Hostgroups', $docs{'assign_hostgroups'}, undef, 1 );
	$form .= Forms->members( 'Hostgroups:', 'hostgroups', \@members, \@nonmembers, '', '20', $docs{'hostgroups'} );
	$form .= Forms->hidden( \%hidden );
	$help{url} = StorProc->doc_section_url('How+to+create+host+profiles', 'Howtocreatehostprofiles-AssignHostGroups');
	$form .= Forms->form_bottom_buttons( \%save, \%help, $tab++ );
    }
    elsif ( $obj_view eq 'apply' ) {
	$form .= Forms->host_profile_top( $name, $session_id, $obj_view, $auth_add{'externals'}, \%obj );
	if (@errors) { $form .= Forms->form_errors( \@errors ) }
	$form .= Forms->wizard_doc( 'Apply', $docs{'apply'}, undef, 1 );
	$form .= Forms->apply_select( $view, \%profile, $nagios_ver, $auth_modify{'externals'}, $tab++ );
	$form .= Forms->hidden( \%hidden );
	$form .= Forms->wizard_doc( 'Caution', $docs{'caution'}, 1, 1 );
	$help{url} = StorProc->doc_section_url('How+to+create+host+profiles', 'Howtocreatehostprofiles-Apply');
	$form .= Forms->form_bottom_buttons( \%apply, \%help, $tab++ );
    }
    elsif ( $obj_view eq 'applied' ) {
	$form .= Forms->host_profile_top( $name, $session_id, $obj_view, $auth_add{'externals'}, \%obj );
	my @message = ("Changes to \"$name\" applied to hosts.");
	$form .= Forms->form_message( 'Updated:', \@message, 'row1' );
	$form .= Forms->hidden( \%hidden );
	$form .= Forms->form_bottom_buttons( \%continue, $tab++ );
    }
    elsif ( $obj_view eq 'exported' ) {
	$form .= Forms->host_profile_top( $name, $session_id, $obj_view, $auth_add{'externals'}, \%obj );
	my @message = ("Host profile \"$name\" saved to /tmp/$name.xml .");
	$form .= Forms->form_message( 'Export:', \@message, 'row1' );
	$form .= Forms->hidden( \%hidden );
	$form .= Forms->form_bottom_buttons( \%continue, $tab++ );
    }
    elsif ( $obj_view eq 'saved' ) {
	my %apply = ( 'name' => 'apply', 'value' => 'Apply to Hosts' );
	$form .= Forms->host_profile_top( $name, $session_id, $obj_view, $auth_add{'externals'}, \%obj );
	my $message = "Changes to profile accepted.";
	$form .= Forms->display_hidden( 'Saved:', '', $message );
	$form .= Forms->hidden( \%hidden );
	if ( $hidden{'apply'} ) {
	    $form .= Forms->form_bottom_buttons( \%apply, $tab++ );
	}
	else {
	    $form .= Forms->form_bottom_buttons();
	}
    }
    elsif ( $obj_view eq 'rename' ) {
	$form .= Forms->form_top( 'Rename Host Profile', '' );
	if (@errors) { $form .= Forms->form_errors( \@errors ) }
	$form .= Forms->display_hidden( 'Host profile name:', 'name', $name );
	$form .= Forms->text_box( 'Rename to:', 'new_name', '', $textsize{'name'}, '', $docs{'name'}, '', $tab++ );
	$hidden{'obj_view'} = 'rename';
	$form .= Forms->hidden( \%hidden );
	$form .= Forms->form_bottom_buttons( \%rename, \%cancel, $tab++ );
    }
    elsif ( $obj_view eq 'delete' ) {
	my $message = qq(Are you sure you want to remove \"$name\"?);
	$form .= Forms->are_you_sure( 'Confirm Delete', $message, 'confirm_delete', \%hidden );
    }
    elsif ( $obj_view eq 'deleted' ) {
	$form .= Forms->form_top( 'Host Profile', '' );
	$form .= Forms->display_hidden( 'Deleted:', 'deleted', "\"$name\" removed" );
	$form .= Forms->hidden( \%hidden );
	$form .= Forms->form_bottom_buttons( \%continue, $tab++ );
    }
    elsif ( $obj_view eq 'new' ) {
	my $description = $query->param('description');
	my $template    = $query->param('template');
	$form .= Forms->form_top( 'New Host Profile', '' );
	if (@errors) { $form .= Forms->form_errors( \@errors ) }
	$form .= Forms->text_box( 'Host profile name:', 'name', $name, $textsize{'name'}, '', $docs{'name'}, '', $tab++ );
	$form .= Forms->text_box( 'Description:', 'description', $description, $textsize{'description'}, '', $docs{'description'}, '', $tab++ );
	my @templates = StorProc->fetch_list( 'host_templates', 'name' );
	$form .= Forms->list_box( 'Host template:', 'template', \@templates, $template, $required{'template'}, $docs{'template'}, '', $tab++ );
	$hidden{'obj_view'} = 'new';
	$form .= Forms->hidden( \%hidden );
	$help{url} = StorProc->doc_section_url('How+to+create+host+profiles', 'Howtocreatehostprofiles-HostProfileDefinition');
	$form .= Forms->form_bottom_buttons( \%add, \%cancel, \%help, $tab++ );
    }
    return $form;
}

#
############################################################################
# Service profile
#

sub service_profile() {
    local $_;

    my $form = undef;
    my %docs = Doc->service_profiles();
    @errors = ();
    my $obj_view = $query->param('obj_view');
    my $name     = $query->param('name');
    my %profile  = StorProc->fetch_one( 'profiles_service', 'name', $name );
    push @errors, delete $profile{'error'} if defined $profile{'error'};
    my @message  = ();

    if ( $query->param('add') ) {
	$name =~ s/^\s+|\s+$//g;
	my %p = StorProc->fetch_one( 'profiles_service', 'name', $name );
	push @errors, delete $p{'error'} if defined $p{'error'};
	my $description = $query->param('description');
	unless ( $p{'name'} || $name eq '' ) {
	    my $data   = "<?xml version=\"1.0\" encoding=\"iso-8859-1\" ?>\n<data>\n</data>";
	    my @values = ( \undef, $name, $description, $data );
	    my $id     = StorProc->insert_obj_id( 'profiles_service', \@values, 'serviceprofile_id' );
	    unless ( $id =~ /^Error/ ) {
		$profile{'description'} = $description;
		if ( $obj_view eq 'new' ) {
		    my @services = $query->$multi_param('services');
		    foreach my $service (@services) {
			if ( $service =~ /^\s+$/ ) { next }
			my %s = StorProc->fetch_one( 'service_names', 'name', $service );
			my @vals = ( $s{'servicename_id'}, $id );
			my $result = StorProc->insert_obj( 'serviceprofile', \@vals );
			if ( $result =~ /^Error/ ) { push @errors, $result }
		    }
		}
		elsif ( $obj_view eq 'copy' ) {
		    $profile{'serviceprofile_id'} = $id;
		    my $source  = $query->param('source');
		    my %source  = StorProc->fetch_one( 'profiles_service', 'name', $source );
		    push @errors, delete $source{'error'} if defined $source{'error'};
		    my @nameids = StorProc->fetch_unique( 'serviceprofile', 'servicename_id', 'serviceprofile_id', $source{'serviceprofile_id'} );
		    foreach my $nameid (@nameids) {
			my @vals = ( $nameid, $id );
			my $result = StorProc->insert_obj( 'serviceprofile', \@vals );
			if ( $result =~ /^Error/ ) { push @errors, $result }
		    }
		}
		unless (@errors) {
		    $obj_view = 'services';
		}
	    }
	    else {
		push @errors, $id;
	    }
	}
	else {
	    push @errors, "Check the name field. It's either blank or that name is already in use.";
	}
    }
    elsif ($query->param('close')
	|| $query->param('cancel')
	|| $query->param('continue') )
    {
	$form .= Forms->header( $page_title, $session_id, $top_menu );
	$obj_view = 'close';
    }
    elsif ( $query->param('export') ) {
	use MonarchProfileExport;
	my $results = ProfileExporter->service_profile( $profile{'serviceprofile_id'} );
	if ( $results =~ /^Error/ ) {
	    push @errors, $results;
	}
	else {
	    $obj_view = 'exported';
	}
    }
    elsif ( $query->param('apply') ) {
	my $hostgroups_select = $query->param('hostgroups_select');
	my $hosts_select      = $query->param('hosts_select');
	my $services          = $query->param('apply_services');

	my $data = "<?xml version=\"1.0\" encoding=\"iso-8859-1\" ?>\n<data>";
	if ($hostgroups_select) {
	    $data .= qq(
  <prop name="hostgroups_select"><![CDATA[checked]]>
  </prop>);
	}
	if ($hosts_select) {
	    $data .= qq(
  <prop name="hosts_select"><![CDATA[checked]]>
  </prop>);
	}
	if ($services) {
	    $data .= qq(
  <prop name="apply_services"><![CDATA[$services]]>
  </prop>);
	}
	$data .= "\n</data>\n";

	my @hosts = ();
	unless ($hostgroups_select || $hosts_select) {
	    push @errors, 'You must apply to hostgroups and/or hosts for any action to occur.';
	}
	unless (@errors) {
	    if ($hostgroups_select) {
		my %where = ( 'serviceprofile_id' => $profile{'serviceprofile_id'} );
		my @hgs = StorProc->fetch_list_where( 'serviceprofile_hostgroup', 'hostgroup_id', \%where );
		foreach my $hg (@hgs) {
		    %where = ( 'hostgroup_id' => $hg );
		    my @hs = StorProc->fetch_list_where( 'hostgroup_host', 'host_id', \%where );
		    push( @hosts, @hs );
		}
	    }
	    if ($hosts_select) {
		my %where = ( 'serviceprofile_id' => $profile{'serviceprofile_id'} );
		my @hs = StorProc->fetch_list_where( 'serviceprofile_host', 'host_id', \%where );
		push( @hosts, @hs );
	    }
	    unless (@hosts) {
		push @errors, 'No chosen hosts reference this service profile.';
	    }
	}
	unless (@errors) {
	    my %hosts = ();
	    foreach my $host (@hosts) {
		$hosts{$host} = 1;
	    }
	    my @distinct_hosts = keys %hosts;
	    my @profiles = ( $profile{'serviceprofile_id'} );
	    my ( $cnt, $err ) = StorProc->service_profile_apply( \@profiles, $services, \@distinct_hosts );
	    @errors = @{$err};
	    @message = ( "$cnt host" . ( $cnt == 1 ? '' : 's' ) . " updated." );
	}

	my %value = ( 'data' => $data );
	my $result = StorProc->update_obj( 'profiles_service', 'name', $name, \%value );
	if ( $result =~ /^Error/ ) { push @errors, $result }
	%profile = StorProc->fetch_one( 'profiles_service', 'name', $name );
	push @errors, delete $profile{'error'} if defined $profile{'error'};
	unless (@errors) { $obj_view = 'applied' }
    }
    elsif ( $query->param('save') ) {
	if ( $obj_view eq 'services' ) {
	    my $description = $query->param('description');
	    my %values      = ();
	    $values{'description'} = $description;
	    my $result = StorProc->update_obj( 'profiles_service', 'name', $name, \%values );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	    $result = StorProc->delete_all( 'serviceprofile', 'serviceprofile_id', $profile{'serviceprofile_id'} );
	    if ( $result =~ /^Error/ ) {
		push @errors, $result;
	    }
	    else {
		my @services = $query->$multi_param('services');
		my $cnt      = 0;
		foreach my $service (@services) {
		    if ( $service =~ /^\s+$/ ) { next }
		    my %s = StorProc->fetch_one( 'service_names', 'name', $service );
		    my @vals = ( $s{'servicename_id'}, $profile{'serviceprofile_id'} );
		    my $result = StorProc->insert_obj( 'serviceprofile', \@vals );
		    if ( $result =~ /^Error/ ) { push @errors, $result }
		    $cnt++;
		}
		@message = ( "\"$name\" has $cnt service" . ( $cnt == 1 ? '' : 's' ) . " assigned." );
	    }
	    unless (@errors) { $obj_view = 'saved' }
	    @message = ("Changes to \"$name\" accepted.");
	}
	elsif ( $obj_view eq 'assign_hosts' ) {
	    my @hosts  = $query->$multi_param('hosts');
	    my %w      = ( 'serviceprofile_id' => $profile{'serviceprofile_id'} );
	    my $result = StorProc->delete_one_where( 'serviceprofile_host', \%w );
	    if ( $result =~ /Error/ ) {
		push @errors, $result;
	    }
	    else {
		my $cnt = 0;
		foreach my $host (@hosts) {
		    if ( $host =~ /^\s+$/ ) { next }
		    my %h = StorProc->fetch_one( 'hosts', 'name', $host );
		    my @vals = ( $profile{'serviceprofile_id'}, $h{'host_id'} );
		    my $result = StorProc->insert_obj( 'serviceprofile_host', \@vals );
		    if ( $result =~ /^Error/ ) { push @errors, $result }
		    $cnt++;
		}
		@message = ( "\"$name\" has $cnt host" . ( $cnt == 1 ? '' : 's' ) . " assigned." );
	    }
	    unless (@errors) { $obj_view = 'saved' }
	}
	elsif ( $obj_view eq 'assign_hostgroups' ) {
	    my @hostgroups = $query->$multi_param('hostgroups');
	    my %w          = ( 'serviceprofile_id' => $profile{'serviceprofile_id'} );
	    my $result     = StorProc->delete_one_where( 'serviceprofile_hostgroup', \%w );
	    if ( $result =~ /Error/ ) {
		push @errors, $result;
	    }
	    else {
		my $cnt = 0;
		foreach my $hostgroup (@hostgroups) {
		    if ( $hostgroup =~ /^\s+$/ ) { next }
		    my %h = StorProc->fetch_one( 'hostgroups', 'name', $hostgroup );
		    my @vals = ( $profile{'serviceprofile_id'}, $h{'hostgroup_id'} );
		    my $result = StorProc->insert_obj( 'serviceprofile_hostgroup', \@vals );
		    if ( $result =~ /^Error/ ) { push @errors, $result }
		    $cnt++;
		}
		@message = ( "\"$name\" has $cnt hostgroup" . ( $cnt == 1 ? '' : 's' ) . " assigned." );
	    }
	    unless (@errors) { $obj_view = 'saved' }
	}
	elsif ( $obj_view eq 'host_profiles' ) {
	    my @profiles = $query->$multi_param('host_profiles');
	    my %w        = ( 'serviceprofile_id' => $profile{'serviceprofile_id'} );
	    my $result   = StorProc->delete_one_where( 'profile_host_profile_service', \%w );
	    if ( $result =~ /Error/ ) {
		push @errors, $result;
	    }
	    else {
		my $cnt = 0;
		foreach my $profile (@profiles) {
		    if ( $profile =~ /^\s+$/ ) { next }
		    my %h = StorProc->fetch_one( 'profiles_host', 'name', $profile );
		    my @vals = ( $h{'hostprofile_id'}, $profile{'serviceprofile_id'} );
		    my $result = StorProc->insert_obj( 'profile_host_profile_service', \@vals );
		    if ( $result =~ /^Error/ ) { push @errors, $result }
		    $cnt++;
		}
		@message = ( "\"$name\" has $cnt host profile" . ( $cnt == 1 ? '' : 's' ) . " assigned." );
	    }
	    unless (@errors) { $obj_view = 'saved' }
	}
    }
    elsif ( $query->param('rename') ) {
	if ( $query->param('new_name') ) {
	    my $new_name = $query->param('new_name');
	    $new_name =~ s/^\s+|\s+$//g;
	    if ( $new_name eq $name ) {
		$obj_view = 'services';
	    }
	    else {
		my %n = StorProc->fetch_one( 'profiles_service', 'name', $new_name );
		push @errors, delete $n{'error'} if defined $n{'error'};
		if ( $n{'name'} ) {
		    push @errors, "A service profile named \"$new_name\" already exists. Please specify another name.";
		}
		else {
		    my %values = ( 'name' => $new_name );
		    my $result = StorProc->update_obj( 'profiles_service', 'name', $name, \%values );
		    if ( $result =~ /error/i ) {
			push @errors, $result;
		    }
		    else {
			$name         = $new_name;
			$obj_view     = 'services';
			$refresh_left = 1;
		    }
		}
	    }
	}
	else {
	    $obj_view = 'rename';
	}
    }
    elsif ( $query->param('delete') || $query->param('confirm_delete') ) {
	my $id   = $query->param('id');
	my %w    = ( 'serviceprofile_id' => $id );
	my @hp   = StorProc->fetch_list_where( 'profile_host_profile_service', 'hostprofile_id', \%w );
	my @hids = StorProc->fetch_list_where( 'serviceprofile_host', 'host_id', \%w );
	unless ( $hids[0] || $hp[0] ) {
	    if ( $query->param('confirm_delete') ) {
		my $result = StorProc->delete_all( 'profiles_service', 'serviceprofile_id', $id );
		if ( $result =~ /^Error/ ) { push @errors, $result }
		unless (@errors) {
		    $obj_view     = 'deleted';
		    $refresh_left = 1;
		}
	    }
	    elsif ( $query->param('task') eq 'No' ) {
		$obj_view = 'services';
	    }
	    else {
		foreach my $name ( $query->param ) {
		    unless ( $name eq 'nocache' ) {
			$hidden{$name} = $query->param($name);
		    }
		}
		$hidden{'delete'} = 1;
		$obj_view = 'delete';
	    }
	}
	else {
	    push @errors, "Cannot delete \"$name\" while it is in use.";
	}
    }
    elsif ( $query->param('close') ) {
	$obj_view = undef;
    }
    my %save   = ( 'name' => 'save',   'value' => 'Save' );
    my %apply  = ( 'name' => 'apply',  'value' => 'Apply' );
    my %export = ( 'name' => 'export', 'value' => 'Export' );
    my %objs   = ();
    unless ($obj_view) {
	if ( $query->param('task') eq 'copy' ) {
	    $obj_view = 'copy';
	}
	else {
	    $obj_view = 'services';
	}
    }
    $hidden{'obj_view'} = $obj_view;
    $form .= Forms->header( $page_title, $session_id, $top_menu, '', $refresh_left );

    if ( $obj_view eq 'services' ) {
	my @members = ();
	$form .= Forms->service_profile_top( $name, $session_id, $obj_view, \%objs, $hidden{'selected'} );
	if (@errors) { $form .= Forms->form_errors( \@errors ) }
	$hidden{'id'} = $profile{'serviceprofile_id'};
	my %w = ( 'serviceprofile_id' => $profile{'serviceprofile_id'} );
	my @sids = StorProc->fetch_list_where( 'serviceprofile', 'servicename_id', \%w );
	foreach (@sids) {
	    my %s = StorProc->fetch_one( 'service_names', 'servicename_id', $_ );
	    if ( $s{'name'} ) { push @members, $s{'name'} }
	}
	my $description = $profile{'description'};
	$form .=
	  Forms->text_area( 'Description:', 'description', $description, 4, $textsize{'description'}, '', $docs{'description'}, '', $tab++ );
	my @nonmembers = StorProc->fetch_list( 'service_names', 'name' );
	$form .= Forms->members( 'Services:', 'services', \@members, \@nonmembers, '', '30', $docs{'services'}, '', $tab++ );
	my $path = $query->param('path');
	$form .= Forms->hidden( \%hidden );
	$help{url} = StorProc->doc_section_url('How+to+create+service+profiles', 'Howtocreateserviceprofiles-Services');
	if ( $auth_delete{'profiles'} ) {
	    $form .= Forms->form_bottom_buttons( \%save, \%delete, \%rename, \%export, \%close, \%help, $tab++ );
	}
	else {
	    $form .= Forms->form_bottom_buttons( \%save, \%rename, \%export, \%close, \%help, $tab++ );
	}
    }
    elsif ( $obj_view eq 'assign_hosts' ) {
	$form .= Forms->service_profile_top( $name, $session_id, $obj_view, \%objs, $hidden{'selected'} );
	$form .= Forms->wizard_doc( 'Assign Hosts', $docs{'assign_hosts'}, undef, 1 );
	my @members = ();
	my %w       = ( 'serviceprofile_id' => $profile{'serviceprofile_id'} );
	my @hids    = StorProc->fetch_list_where( 'serviceprofile_host', 'host_id', \%w );
	foreach (@hids) {
	    my %h = StorProc->fetch_one( 'hosts', 'host_id', $_ );
	    if ( $h{'name'} ) { push @members, $h{'name'} }
	}
	my @nonmembers = StorProc->fetch_list( 'hosts', 'name' );
	$form .= Forms->members( 'Hosts:', 'hosts', \@members, \@nonmembers, '', '30', $docs{'hosts'} );
	$form .= Forms->hidden( \%hidden );
	$help{url} = StorProc->doc_section_url('How+to+create+service+profiles', 'Howtocreateserviceprofiles-AssignHosts');
	$form .= Forms->form_bottom_buttons( \%save, \%help, $tab++ );
    }
    elsif ( $obj_view eq 'assign_hostgroups' ) {
	$form .= Forms->service_profile_top( $name, $session_id, $obj_view, \%objs, $hidden{'selected'} );
	$form .= Forms->wizard_doc( 'Assign Hostgroups', $docs{'assign_hostgroups'}, undef, 1 );
	my @members = ();
	my %w       = ( 'serviceprofile_id' => $profile{'serviceprofile_id'} );
	my @hids    = StorProc->fetch_list_where( 'serviceprofile_hostgroup', 'hostgroup_id', \%w );
	foreach (@hids) {
	    my %h = StorProc->fetch_one( 'hostgroups', 'hostgroup_id', $_ );
	    if ( $h{'name'} ) { push @members, $h{'name'} }
	}
	my @nonmembers = StorProc->fetch_list( 'hostgroups', 'name' );
	$form .= Forms->members( 'Hostgroups:', 'hostgroups', \@members, \@nonmembers, '', '30', $docs{'hosts'} );
	$form .= Forms->hidden( \%hidden );
	$help{url} = StorProc->doc_section_url('How+to+create+service+profiles', 'Howtocreateserviceprofiles-AssignHostGroups');
	$form .= Forms->form_bottom_buttons( \%save, \%help, $tab++ );
    }
    elsif ( $obj_view eq 'host_profiles' ) {
	$form .= Forms->service_profile_top( $name, $session_id, $obj_view, \%objs, $hidden{'selected'} );
	$form .= Forms->wizard_doc( 'Host Profiles', $docs{'host_profiles'}, undef, 1 );
	my @members = ();
	my %w       = ( 'serviceprofile_id' => $profile{'serviceprofile_id'} );
	my @hids    = StorProc->fetch_list_where( 'profile_host_profile_service', 'hostprofile_id', \%w );
	foreach (@hids) {
	    my %h = StorProc->fetch_one( 'profiles_host', 'hostprofile_id', $_ );
	    if ( $h{'name'} ) { push @members, $h{'name'} }
	}
	my @nonmembers = StorProc->fetch_list( 'profiles_host', 'name' );
	$form .= Forms->members( 'Host profiles:', 'host_profiles', \@members, \@nonmembers, '', '30', $docs{'host_profiles'} );
	$form .= Forms->hidden( \%hidden );
	$help{url} = StorProc->doc_section_url('How+to+create+service+profiles', 'Howtocreateserviceprofiles-HostProfiles');
	$form .= Forms->form_bottom_buttons( \%save, \%help, $tab++ );
    }
    elsif ( $obj_view eq 'apply' ) {
	$form .= Forms->service_profile_top( $name, $session_id, $obj_view, \%objs, $hidden{'selected'} );
	if (@errors) { $form .= Forms->form_errors( \@errors ) }
	$form .= Forms->wizard_doc( 'Apply', $docs{'apply'}, undef, 1 );
	$form .= Forms->apply_select( $view, \%profile, $nagios_ver, $auth_modify{'externals'}, $tab++ );
	$form .= Forms->hidden( \%hidden );
	$form .= Forms->wizard_doc( 'Caution', $docs{'caution'}, 1, 1 );
	$help{url} = StorProc->doc_section_url('How+to+create+service+profiles', 'Howtocreateserviceprofiles-Apply');
	$form .= Forms->form_bottom_buttons( \%apply, \%help, $tab++ );
    }
    elsif ( $obj_view eq 'applied' ) {
	$form .= Forms->service_profile_top( $name, $session_id, $obj_view, \%objs, $hidden{'selected'} );
	my @message = ("Changes to \"$name\" applied to hosts.");
	$form .= Forms->form_message( 'Updated:', \@message, 'row1' );
	$form .= Forms->hidden( \%hidden );
	$form .= Forms->form_bottom_buttons( \%continue, $tab++ );
    }
    elsif ( $obj_view eq 'exported' ) {
	$form .= Forms->service_profile_top( $name, $session_id, $obj_view, \%objs, $hidden{'selected'} );
	my @message = ("Service profile \"$name\" saved to /tmp/service-profile-$name.xml .");
	$form .= Forms->form_message( 'Export:', \@message, 'row1' );
	$form .= Forms->hidden( \%hidden );
	$form .= Forms->form_bottom_buttons( \%continue, $tab++ );
    }
    elsif ( $obj_view eq 'saved' ) {
	$form .= Forms->service_profile_top( $name, $session_id, $obj_view, \%objs, $hidden{'selected'} );
	$form .= Forms->form_message( 'Updated:', \@message, 'row1' );
	$form .= Forms->hidden( \%hidden );
	$form .= Forms->form_bottom_buttons( \%close );
    }
    elsif ( $obj_view eq 'rename' ) {
	$form .= Forms->form_top( 'Rename Service Profile', '' );
	if (@errors) { $form .= Forms->form_errors( \@errors ) }
	$form .= Forms->display_hidden( 'Service profile name:', 'name', $name );
	$form .= Forms->text_box( 'Rename to:', 'new_name', '', $textsize{'name'}, '', $docs{'name'}, '', $tab++ );
	$hidden{'obj_view'} = 'rename';
	$form .= Forms->hidden( \%hidden );
	$form .= Forms->form_bottom_buttons( \%rename, \%cancel, $tab++ );
    }
    elsif ( $obj_view eq 'delete' ) {
	my $message = qq(Are you sure you want to remove \"$name\"?);
	delete $hidden{'task'};
	$form .= Forms->are_you_sure( 'Confirm Delete', $message, 'confirm_delete', \%hidden );
    }
    elsif ( $obj_view eq 'deleted' ) {
	$form .= Forms->form_top( 'Service Profile', '' );
	$form .= Forms->display_hidden( 'Deleted:', 'deleted', "\"$name\" removed" );
	$form .= Forms->hidden( \%hidden );
	$form .= Forms->form_bottom_buttons( \%continue, $tab++ );
    }
    elsif ( $obj_view eq 'new' ) {
	my $description = $query->param('description');
	$form .= Forms->form_top( 'New Service Profile', '' );
	if (@errors) { $form .= Forms->form_errors( \@errors ) }
	$form .= Forms->text_box( 'Service profile name:', 'name', $name, $textsize{'name'}, '', $docs{'name'}, '', $tab++ );
	$form .= Forms->text_box( 'Description:', 'description', $description, $textsize{'description'}, '', $docs{'description'}, '', $tab++ );
	$hidden{'obj_view'} = 'new';
	$form .= Forms->hidden( \%hidden );
	$help{url} = StorProc->doc_section_url('How+to+create+service+profiles', 'Howtocreateserviceprofiles-ServiceProfileDefinition');
	$form .= Forms->form_bottom_buttons( \%add, \%cancel, \%help, $tab++ );
    }
    elsif ( $obj_view eq 'copy' ) {
	my $source = $query->param('source');
	my $description = $query->param('description');
	unless ($description) {
	    my %source = StorProc->fetch_one( 'profiles_service', 'name', $source );
	    push @errors, delete $source{'error'} if defined $source{'error'};
	    $description = 'Edited copy: ' . (defined( $source{'description'} ) ? $source{'description'} : '');
	}
	unless ($name) { $name = "Copy-of-$source" }
	$form .= Forms->form_top( 'Copy Service Profile', '' );
	if (@errors) { $form .= Forms->form_errors( \@errors ) }
	$form .= Forms->display_hidden( 'Copy:', 'source', $source );
	$form .= Forms->text_box( 'Service profile name:', 'name', $name, $textsize{'name'}, '', $docs{'name'}, '', $tab++ );
	$form .= Forms->text_box( 'Description:', 'description', $description, $textsize{'description'}, '', $docs{'description'}, '', $tab++ );
	$hidden{'obj_view'} = 'copy';
	$form .= Forms->hidden( \%hidden );
	$form .= Forms->form_bottom_buttons( \%add, \%cancel, $tab++ );
    }
    return $form;
}

############################################################################
# Services
#

sub service() {
    local $_;

    my $host_id  = $query->param('host_id');
    my $form     = undef;
    my $obj_view = $query->param('obj_view');
    my $name     = $query->param('name');
    $name =~ s/^\s+|\s+$//g if defined $name;
    my %service = StorProc->fetch_one( 'service_names', 'name', $name );
    push @errors, delete $service{'error'} if defined $service{'error'};
    my $host            = $query->param('host');
    my $test_results    = undef;
    my $message_applied = undef;

    if ( $query->param('add') ) {
	if ($name) {
	    $name =~ s/^\s+|\s+$//g;
	    my %p = StorProc->fetch_one( 'service_names', 'name', $name );
	    push @errors, delete $p{'error'} if defined $p{'error'};
	    unless ( $p{'name'} ) {
		my $template = $query->param('template');
		if ($template) {
		    my %s = StorProc->fetch_one( 'service_templates', 'name', $template );
		    my @values = ( \undef, $name, '', $s{'servicetemplate_id'}, '', '', '', '', '' );
		    my $id = StorProc->insert_obj_id( 'service_names', \@values, 'servicename_id' );
		    if ( $id =~ /^Error/ ) {
			push @errors, $id;
			$obj_view = 'new';
		    }
		    else {
			$obj_view = 'service_detail';
		    }
		}
		else {
		    push @errors, "Template required.";
		    $obj_view = 'new';
		    $required{'template'} = 1;
		}
	    }
	    else {
		push @errors, "Service name \"$name\" already exists.";
		$obj_view             = 'new';
		$required{'name'}     = 1;
		$required{'template'} = 1;
	    }
	}
	else {
	    push @errors, "Service name required.";
	    $obj_view = 'new';
	}
    }
    elsif ($query->param('close')
	|| $query->param('continue')
	|| $query->param('cancel') )
    {
	$form .= Forms->header( $page_title, $session_id, $top_menu );
	$obj_view = undef;
    }
    elsif ( $query->param('next') ) {
	if ($name) {
	    if ( $service{'servicename_id'} ) {
		push @errors, "A service named \"$name\" already exists.";
	    }
	    else {
		my $clone_service = $query->param('clone_service');
		my $apply_profile = $query->param('apply_profile');
		@errors = StorProc->clone_service( $name, $clone_service, $apply_profile );
		unless (@errors) {
		    %service = StorProc->fetch_one( 'service_names', 'name', $name );
		    push @errors, delete $service{'error'} if defined $service{'error'};
		    $obj_view = 'service_detail';
		}
	    }

	}
    }
    elsif ( $query->param('apply') ) {
	my $apply_check              = $query->param('apply_check');
	my $apply_escalation_service = $query->param('apply_escalation_service');
	my $apply_contact_service    = $query->param('apply_contact_service');
	my $apply_extinfo_service    = $query->param('apply_extinfo_service');
	my $apply_dependencies       = $query->param('apply_dependencies');
	my $apply_service_externals  = $query->param('apply_service_externals');
	my $services                 = $query->param('apply_services');
	my $data                     = "<?xml version=\"1.0\" encoding=\"iso-8859-1\" ?>\n<data>";
	if ( $services eq 'replace' ) {
	    $data .= qq(
  <prop name="apply_services"><![CDATA[replace]]>
  </prop>);
	    my %values = ( 'servicetemplate_id' => $service{'template'} );
	    my $result = StorProc->update_obj( 'services', 'servicename_id', $service{'servicename_id'}, \%values );
	    if ( $result =~ /Error/ ) { push @errors, $result }
	    my @errs = StorProc->service_replace( \%service );
	    if ( $errs[0] =~ /applied/ ) {
		$message_applied = $errs[0];
	    }
	    else {
		push( @errors, @errs );
	    }
	}
	if ( $services eq 'merge' ) {
	    $data .= qq(
  <prop name="apply_services"><![CDATA[merge]]>
  </prop>);
	    my %values = ( 'servicetemplate_id' => $service{'template'} );
	    my $result = StorProc->update_obj( 'services', 'servicename_id', $service{'servicename_id'}, \%values );
	    if ( $result =~ /Error/ ) { push @errors, $result }
	    my @errs = StorProc->service_merge( \%service );
	    if ( $errs[0] =~ /applied/ ) {
		$message_applied = $errs[0];
	    }
	    else {
		push( @errors, @errs );
	    }
	}
	if ($apply_extinfo_service) {
	    $data .= qq(
  <prop name="apply_extinfo_service"><![CDATA[checked]]>
  </prop>);
	    my %values = ( 'serviceextinfo_id' => $service{'extinfo'} );
	    my $result = StorProc->update_obj( 'services', 'servicename_id', $service{'servicename_id'}, \%values );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	}
	if ($apply_contact_service) {
	    $data .= qq(
  <prop name="apply_contact_service"><![CDATA[checked]]>
  </prop>);
	    my %where = ( 'servicename_id' => $service{'servicename_id'} );
	    my @sids = StorProc->fetch_list_where( 'services', 'service_id', \%where );
	    %where = ( 'servicename_id' => $service{'servicename_id'} );
	    my @cgids = StorProc->fetch_list_where( 'contactgroup_service_name', 'contactgroup_id', \%where );
	    foreach my $sid (@sids) {
		%where = ( 'service_id' => $sid );
		my $result = StorProc->delete_one_where( 'contactgroup_service', \%where );
		if ( $result =~ /^Error/ ) { push @errors, $result }
		foreach my $cgid (@cgids) {
		    my @vals = ( $cgid, $sid );
		    my $result = StorProc->insert_obj( 'contactgroup_service', \@vals );
		    if ( $result =~ /^Error/ ) { push @errors, $result }
		}
	    }
	}
	if ($apply_escalation_service) {
	    $data .= qq(
  <prop name="apply_escalation_service"><![CDATA[checked]]>
  </prop>);
	    my %values = ( 'escalation_id' => $service{'escalation'} );
	    my $result = StorProc->update_obj( 'services', 'servicename_id', $service{'servicename_id'}, \%values );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	}
	if ($apply_check) {
	    $data .= qq(
  <prop name="apply_check"><![CDATA[checked]]>
  </prop>);
	    my %values = (
		'check_command' => $service{'check_command'},
		'command_line'  => $service{'command_line'}
	    );
	    my $result = StorProc->update_obj( 'services', 'servicename_id', $service{'servicename_id'}, \%values );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	}
	if ($apply_dependencies) {
	    $data .= qq(
  <prop name="apply_dependencies"><![CDATA[checked]]>
  </prop>);
	    my @result = StorProc->update_dependencies( $service{'servicename_id'} );
	    if (@result) { push( @errors, @result ) }
	}
	if ($apply_service_externals) {
	    $data .= qq(
  <prop name="apply_service_externals"><![CDATA[checked]]>
  </prop>);
	    if ($enable_externals) {
		# FIX LATER:  There is still a lot of nested database access here.  That might be very slow to execute with
		# a large configuration.  See if we can optimize by pulling complete copies of certain tables back from the
		# database before we start looping, then just access those local copies within the loop structure here.

		my %w = ( 'servicename_id' => $service{'servicename_id'} );
		my @externals = StorProc->fetch_list_where( 'external_service_names', 'external_id', \%w );
		my %services = StorProc->fetch_list_hash_array( 'services', \%w );
		foreach my $sid ( keys %services ) {
		    if ( $services eq 'replace' ) {
			my $result = StorProc->delete_all( 'external_service', 'service_id', $sid );
			if ( $result =~ /^Error/ ) { push @errors, $result }
			foreach my $ext (@externals) {
			    my %external = StorProc->fetch_one( 'externals', 'external_id', $ext );
			    my @vals = ( $ext, $services{$sid}[1], $sid, $external{'display'}, $DEFINED_REF );
			    $result = StorProc->insert_obj( 'external_service', \@vals );
			    if ( $result =~ /^Error/ ) { push @errors, $result }
			}
		    }
		    if ( $services eq 'merge' ) {
			foreach my $ext (@externals) {
			    my %where = (
				'external_id' => $ext,
				'host_id'     => $services{$sid}[1],
				'service_id'  => $sid
			    );
			    my @host_service_externals = StorProc->fetch_list_where( 'external_service', 'modified', \%where );
			    if (@host_service_externals) {
				if ($host_service_externals[0] == 0) {
				    my %external = StorProc->fetch_one( 'externals', 'external_id', $ext );
				    my %values = ( 'data' => $external{'display'}, 'modified' => $DEFINED_REF );
				    my $result = StorProc->update_obj_where( 'external_service', \%values, \%where );
				    if ( $result =~ /^Error/ ) { push @errors, $result }
				}
			    }
			    else {
				my %external = StorProc->fetch_one( 'externals', 'external_id', $ext );
				my @vals = ( $ext, $services{$sid}[1], $sid, $external{'display'}, $DEFINED_REF );
				my $result = StorProc->insert_obj( 'external_service', \@vals );
				if ( $result =~ /^Error/ ) { push @errors, $result }
			    }
			}
		    }
		}
	    }
	}
	$data .= "\n</data>\n";
	my %value = ( 'data' => $data );
	my $result = StorProc->update_obj( 'service_names', 'name', $name, \%value );
	if ( $result =~ /^Error/ ) { push @errors, $result }
	%service = StorProc->fetch_one( 'service_names', 'name', $name );
	push @errors, delete $service{'error'} if defined $service{'error'};
	unless (@errors) { $obj_view = 'applied' }
    }
    elsif ( $query->param('test_command') ) {
	my $arg_string = $query->param('command_line');
	my $command    = $query->param('command');
	my %cmd        = StorProc->fetch_one( 'commands', 'name', $command );
	$test_results .= StorProc->test_command( $command, $cmd{'command_line'}, $host, $arg_string, $monarch_home, $name, $nagios_ver );
    }
    elsif ( $query->param('save') ) {
	if ( $obj_view eq 'service_detail' ) {
	    my %values = ();
	    $hidden{'servicename_id'} = $service{'servicename_id'};
	    my $ext_info   = $query->param('ext_info');
	    my %x          = StorProc->fetch_one( 'extended_service_info_templates', 'name', $ext_info );
	    my $escalation = $query->param('escalation');
	    my %e          = StorProc->fetch_one( 'escalation_trees', 'name', $escalation );
	    my $template   = $query->param('template');
	    my %t          = StorProc->fetch_one( 'service_templates', 'name', $template );

	    if ($host_id) {
		## This is probably a dead branch of the code, never called in any context.
		my %values     = ();
		my $service_id = $query->param('service_id');
		$hidden{'service_id'} = $service_id;
		# FIX LATER:  reduce redundancy with code above
		my %s          = StorProc->fetch_one( 'service_names', 'name', $name );
		push @errors, delete $s{'error'} if defined $s{'error'};
		my $ext_info   = $query->param('ext_info');
		my %x          = StorProc->fetch_one( 'extended_service_info_templates', 'name', $ext_info );
		my $escalation = $query->param('escalation');
		my %e          = StorProc->fetch_one( 'escalation_trees', 'name', $escalation );
		my $template   = $query->param('template');
		my %t          = StorProc->fetch_one( 'service_templates', 'name', $template );
		my %data       = parse_query( 'service_overrides', 'service_overrides' );
		my %vals       = (
		    'serviceextinfo_id'  => $x{'serviceextinfo_id'},
		    'escalation_id'      => $s{'tree_id'},
		    'servicetemplate_id' => $t{'servicetemplate_id'}
		);
		my $result = StorProc->update_obj( 'services', 'service_id', $service_id, \%vals );
		if ( $result =~ /^Error/ ) { push @errors, $result }
		my %where = ( 'service_id' => $properties{'service_id'} );
		$result = StorProc->delete_one_where( 'service_overrides', \%where );
		if ( $result =~ /^Error/ ) { push @errors, $result }

		if (   $data{'check_period'}
		    || $data{'notification_period'}
		    || $data{'event_handler'}
		    || $data{'data'} )
		{
		    my @values = ( $service_id, $data{'check_period'}, $data{'notification_period'}, $data{'event_handler'}, $data{'data'} );
		    my $result = StorProc->insert_obj( 'service_overrides', \@values );
		    if ( $result =~ /^Error/ ) { push @errors, $result }
		}

		%where = ( 'service_id' => $service_id );
		$result = StorProc->delete_one_where( 'contactgroup_service', \%where );
		if ( $result =~ /^Error/ ) { push @errors, $result }
		unless ( $query->param('contactgroup_override') ) {
		    my @mems = $query->$multi_param('contactgroup');
		    foreach (@mems) {
			my %cg = StorProc->fetch_one( 'contactgroups', 'name', $_ );
			my @vals = ( $cg{'contactgroup_id'}, $service_id );
			$result = StorProc->insert_obj( 'contactgroup_service', \@vals );
			if ( $result =~ /^Error/ ) { push @errors, $result }
		    }
		}
	    }
	    else {
		my %data = parse_query( 'service_overrides', 'service_overrides' );
		my %vals = (
		    'extinfo'    => $x{'serviceextinfo_id'},
		    'escalation' => $e{'tree_id'},
		    'template'   => $t{'servicetemplate_id'}
		);
		my $result = StorProc->update_obj( 'service_names', 'servicename_id', $service{'servicename_id'}, \%vals );
		if ( $result =~ /^Error/ ) { push @errors, $result }
		my %where = ( 'servicename_id' => $service{'servicename_id'} );
		$result = StorProc->delete_one_where( 'servicename_overrides', \%where );
		if ( $result =~ /^Error/ ) { push @errors, $result }
		if (   $data{'check_period'}
		    || $data{'notification_period'}
		    || $data{'event_handler'}
		    || $data{'data'} )
		{
		    my @values =
		      ( $service{'servicename_id'}, $data{'check_period'}, $data{'notification_period'}, $data{'event_handler'},
			$data{'data'} );
		    my $result = StorProc->insert_obj( 'servicename_overrides', \@values );
		    if ( $result =~ /^Error/ ) { push @errors, $result }
		}

		%where = ( 'servicename_id' => $service{'servicename_id'} );
		$result = StorProc->delete_one_where( 'contactgroup_service_name', \%where );
		if ( $result =~ /^Error/ ) { push @errors, $result }
		unless ( $query->param('contactgroup_override') ) {
		    my @mems = $query->$multi_param('contactgroup');
		    foreach (@mems) {
			my %cg = StorProc->fetch_one( 'contactgroups', 'name', $_ );
			my @vals = ( $cg{'contactgroup_id'}, $service{'servicename_id'} );
			$result = StorProc->insert_obj( 'contactgroup_service_name', \@vals );
			if ( $result =~ /^Error/ ) { push @errors, $result }
		    }
		}
	    }
	    unless (@errors) {
		$obj_view = 'saved';
	    }
	}
	elsif ( $obj_view eq 'service_check' ) {
	    my $service_name = $query->param('service_name');
	    my $service_id   = $query->param('service_id');
	    $hidden{'service_name'} = $service_name;
	    $hidden{'service_id'}   = $service_id;
	    my $check_command       = $query->param('command');
	    my $command_line        = $query->param('command_line');
	    my $externals_arguments = undef;
	    my $inherit_ext_args    = undef;

	    if ($enable_externals) {
		$externals_arguments = $query->param('externals_arguments');
		$externals_arguments = undef if defined($externals_arguments) && $externals_arguments eq '';
		$inherit_ext_args    = $query->param('inherit_ext_args');
	    }

	    unless (@errors) {
		if ($host_id) {
		    if ( $query->param('inherit') ) {
			my $required = $query->param('required');
			unless ($required) {
			    my %vals = ( 'check_command' => '', 'command_line' => '' );
			    if ($enable_externals) {
				$vals{'externals_arguments'} = $externals_arguments;
				$vals{'inherit_ext_args'} = $inherit_ext_args || '00';
			    }
			    my $result = StorProc->update_obj( 'services', 'service_id', $service_id, \%vals );
			    if ( $result =~ /^Error/ ) { push @errors, $result }
			}
			else {
			    push @errors, "The service check is not defined on a template so it must be defined here.";
			}
		    }
		    else {
			my %check = StorProc->fetch_one( 'commands', 'name', $check_command );
			my %vals = (
			    'check_command' => $check{'command_id'},
			    'command_line'  => $command_line
			);
			if ($enable_externals) {
			    $vals{'externals_arguments'} = $externals_arguments;
			    $vals{'inherit_ext_args'} = $inherit_ext_args || '00';
			}
			my $result = StorProc->update_obj( 'services', 'service_id', $service_id, \%vals );
			if ( $result =~ /^Error/ ) { push @errors, $result }
		    }
		}
		else {
		    if ( $query->param('inherit') ) {
			my $required = $query->param('required');
			unless ($required) {
			    my %vals = ( 'check_command' => '', 'command_line' => '' );
			    $vals{'externals_arguments'} = $externals_arguments if $enable_externals;
			    my $result = StorProc->update_obj( 'service_names', 'servicename_id', $service{'servicename_id'}, \%vals );
			    if ( $result =~ /^Error/ ) { push @errors, $result }
			}
			else {
			    push @errors, "The service check is not defined on a template so it must be defined here.";
			}
		    }
		    else {
			my %check = StorProc->fetch_one( 'commands', 'name', $check_command );
			my %vals = (
			    'check_command' => $check{'command_id'},
			    'command_line'  => $command_line
			);
			$vals{'externals_arguments'} = $externals_arguments if $enable_externals;
			my $result = StorProc->update_obj( 'service_names', 'servicename_id', $service{'servicename_id'}, \%vals );
			if ( $result =~ /^Error/ ) { push @errors, $result }
		    }
		}
	    }

	    unless (@errors) {
		$obj_view = 'saved';
		$hidden{'selected'} = 'service_check';
	    }
	}
	elsif ( $obj_view eq 'service_profiles' ) {
	    my @profiles = $query->$multi_param('profiles');
	    my $result = StorProc->delete_all( 'serviceprofile', 'servicename_id', $service{'servicename_id'} );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	    foreach my $prof (@profiles) {
		my %p = StorProc->fetch_one( 'profiles_service', 'name', $prof );
		my @values = ( $service{'servicename_id'}, $p{'serviceprofile_id'} );
		$result = StorProc->insert_obj( 'serviceprofile', \@values );
		if ( $result =~ /^Error/ ) { push @errors, $result }
	    }
	    unless (@errors) {
		$obj_view = 'saved';
	    }
	}
    }
    elsif ( $query->param('external_add') ) {
	my @externals = $query->$multi_param('external');
	my $result = StorProc->delete_all( 'external_service_names', 'servicename_id', $hidden{'service_id'} );
	if ( $result =~ /^Error/ ) { push @errors, $result }
	foreach my $ext (@externals) {
	    my %e = StorProc->fetch_one( 'externals', 'name', $ext );
	    if ($e{'external_id'} ne '') {
		my @values = ( $e{'external_id'}, $service{'servicename_id'} );
		$result = StorProc->insert_obj( 'external_service_names', \@values );
		if ( $result =~ /^Error/ ) { push @errors, $result }
	    }
	}
    }
    elsif ( $query->param('remove_dependency') ) {
	my $dep_id = $query->param('dependency_id');
	$dep_id =~ s/\D//g;
	my $table  = $host_id ? 'service_dependency' : 'servicename_dependency';
	my $result = StorProc->delete_all( $table, 'id', $dep_id );
	if ( $result =~ /^Error/ ) { push @errors, $result }
    }
    elsif ( $query->param('add_dependency') ) {
	my $dependency = $query->param('dep_template');
	my $parent     = $query->param('depend_on_host');
	if ( $parent && $dependency ) {
	    if ($host_id) {
		my $dep_template = $query->param('dep_template');
		my $service_name = $query->param('service_name');
		my $service_id   = $query->param('service_id');
		$hidden{'service_name'} = $service_name;
		$hidden{'service_id'}   = $service_id;
		my $parent = $query->param('depend_on_host');
		my %p      = StorProc->fetch_one( 'hosts', 'name', $parent );
		my %d      = StorProc->fetch_one( 'service_dependency_templates', 'name', $dep_template );
		my %w      = (
		    'service_id'        => $service_id,
		    'host_id'           => $properties{'host_id'},
		    'depend_on_host_id' => $p{'host_id'},
		    'template'          => $d{'id'}
		);
		my %check_dep = StorProc->fetch_one_where( 'service_dependency', \%w );

		if ( $dep_template && $service_id && $parent ) {
		    unless ( $check_dep{'id'} ) {
			my @values = ( \undef, $service_id, $properties{'host_id'}, $p{'host_id'}, $d{'id'}, '' );
			my $result = StorProc->insert_obj( 'service_dependency', \@values );
			if ( $result =~ /^Error/ ) { push @errors, $result }
		    }
		    else {
			push @errors, "Already defined. Check existing dependencies.";
		    }
		}
	    }
	    else {
		my %dependency = StorProc->fetch_one( 'service_dependency_templates', 'name', $dependency );
		unless ( $parent eq 'same host' ) {
		    my %p = StorProc->fetch_one( 'hosts', 'name', $parent );
		    $parent = $p{'host_id'};
		}
		my $check_dep = StorProc->check_dependency( $service{'servicename_id'}, $parent, $dependency{'id'} );
		unless ($check_dep) {
		    my $result = StorProc->insert_dependency( $service{'servicename_id'}, $parent, $dependency{'id'} );
		    if ( $result =~ /^Error/ ) { push @errors, $result }
		}
		else {
		    push @errors, "Already defined. Check existing dependencies.";
		}
	    }
	}
    }
    elsif ( $query->param('rename') ) {
	if ( $query->param('new_name') ) {
	    my $new_name = $query->param('new_name');
	    $new_name =~ s/^\s+|\s+$//g;
	    if ( $new_name eq $name ) {
		$obj_view = 'service_detail';
	    }
	    else {
		my %n = StorProc->fetch_one( 'service_names', 'name', $new_name );
		push @errors, delete $n{'error'} if defined $n{'error'};
		if ( $n{'name'} && $n{'name'} != /$new_name/i ) {
		    push @errors, "A service named \"$new_name\" already exists. Please specify another name.";
		}
		else {
		    my %values = ( 'name' => $new_name );
		    my $result = StorProc->update_obj( 'service_names', 'name', $name, \%values );
		    if ( $result =~ /error/i ) {
			push @errors, $result;
		    }
		    else {
			$result = StorProc->delete_all( 'host_service', 'service', $name );
			if ( $result =~ /^Error/ ) { push @errors, $result }
			$name         = $new_name;
			$obj_view     = 'service_detail';
			$refresh_left = 1;
		    }
		}
	    }
	}
	else {
	    $obj_view = 'rename';
	}
    }
    elsif ( $query->param('delete') || $query->param('confirm_delete') ) {
	my %sn = StorProc->fetch_one( 'service_names', 'name', $name );
	push @errors, delete $sn{'error'} if defined $sn{'error'};
	my %where = ( 'servicename_id' => $sn{'servicename_id'} );
	if ( $query->param('confirm_delete') ) {
	    my $result = StorProc->delete_all( 'service_names', 'name', $name );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	    unless (@errors) {
		$result = StorProc->delete_one_where( 'services', \%where );
		if ( $result =~ /^Error/ ) { push @errors, $result }
	    }
	    unless (@errors) {
		$result = StorProc->delete_one_where( 'serviceprofile', \%where );
		if ( $result =~ /^Error/ ) { push @errors, $result }
	    }
	    unless (@errors) {
		$result = StorProc->delete_one_where( 'service_dependency_templates', \%where );
		if ( $result =~ /^Error/ ) { push @errors, $result }
	    }
	    unless (@errors) {
		$result = StorProc->delete_all( 'host_service', 'service', $name );
		if ( $result =~ /^Error/ ) { push @errors, $result }
		$form .= Forms->header( $page_title, $session_id, $top_menu, '', '1' );
		$form .= Forms->form_top( 'Service Deleted', '' );
		my @message = ("$name");
		$form .= Forms->form_message( 'Removed:', \@message, 'row1' );
		$form .= Forms->hidden( \%hidden );
		$form .= Forms->form_bottom_buttons( \%continue, $tab++ );
		$name           = undef;
		$obj_view       = undef;
		$hidden{'name'} = undef;
	    }
	}
	elsif ( defined( $query->param('task') ) && $query->param('task') eq 'No' ) {
	    $obj_view = 'service_detail';
	}
	else {
	    foreach my $name ( $query->param ) {
		unless ( $name eq 'nocache' ) {
		    $hidden{$name} = $query->param($name);
		}
	    }
	    $obj_view = 'delete';
	}
    }
    else {
	foreach my $param ( $query->param ) {
	    if ( $param =~ /remove_external_(\d+)/ ) {
		my $eid   = $1;
		my %where = (
		    'servicename_id' => $service{'servicename_id'},
		    'external_id'    => $eid
		);
		my $result = StorProc->delete_one_where( 'external_service_names', \%where );
		if ( $result =~ /^Error/ ) { push @errors, $result }
	    }
	}
    }
    my %save  = ( 'name' => 'save',  'value' => 'Save' );
    my %apply = ( 'name' => 'apply', 'value' => 'Apply' );
    my %objs = ( 'servicename_id' => $hidden{'servicename_id'} );
    my %docs = Doc->services();
    $hidden{'name'}           = $name;
    $hidden{'obj_view'}       = $obj_view;
    $hidden{'servicename_id'} = $query->param('servicename_id');

    unless ( $hidden{'servicename_id'} ) {
	$hidden{'servicename_id'} = $service{'servicename_id'};
    }
    $objs{'servicename_id'} = $hidden{'servicename_id'};
    $form .= Forms->header( $page_title, $session_id, $top_menu, '', $refresh_left );
    if (defined $obj_view) {
	if ( $obj_view eq 'service_detail' ) {
	    my $ext_info   = $query->param('ext_info');
	    my $escalation = $query->param('escalation');
	    unless ($ext_info) {
		my %w = ( 'serviceextinfo_id' => $service{'extinfo'} );
		my %e = StorProc->fetch_one_where( 'extended_service_info_templates', \%w );
		$ext_info = $e{'name'};
	    }
	    unless ($escalation) {
		my %w = ( 'tree_id' => $service{'escalation'} );
		my %esc = StorProc->fetch_one_where( 'escalation_trees', \%w );
		$escalation = $esc{'name'};
	    }
	    $form .= Forms->service_top( $name, $session_id, $obj_view, \%objs, $auth_add{'externals'}, $hidden{'selected'} );
	    if (@errors) { $form .= Forms->form_errors( \@errors ) }
	    $form .= build_service_detail( $hidden{'servicename_id'} );
	    $form .= Forms->wizard_doc( 'Additional Per-Service Options', undef, undef, 1 );
	    my @members = StorProc->fetch_list( 'extended_service_info_templates', 'name' );
	    $form .= Forms->list_box( 'Extended service info template:', 'ext_info', \@members, $ext_info, '', $docs{'extinfo'}, '', $tab++ );
	    my %where = ( 'type' => 'service' );
	    @members = ();
	    @members = ('-- remove escalation tree --') if ($escalation && $escalation ne '-- no service escalation trees --');
	    push( @members, StorProc->fetch_list_where( 'escalation_trees', 'name', \%where ) );
	    $form .= Forms->list_box_submit( 'Service escalation tree:',
		'escalation', \@members, $escalation, '', $docs{'escalation'}, $tab++ );
	    if ($escalation && $escalation ne '-- no service escalation trees --' && $escalation ne '-- remove escalation tree --') {
		my ( $ranks, $templates ) = StorProc->get_tree_detail($escalation);
		my %ranks     = %{$ranks};
		my %templates = %{$templates};
		$form .= Forms->escalation_tree( \%ranks, \%templates, 'service_detail' );
	    }
	    $form .= Forms->hidden( \%hidden );
	    $help{url} = StorProc->doc_section_url('How+to+manage+services', 'Howtomanageservices-ServiceDetail');
	    if ( $auth_delete{'services'} ) {
		if ($host_id) {
		    $form .= Forms->form_bottom_buttons( \%save, \%delete, \%close, \%help, $tab++ );
		}
		else {
		    $form .= Forms->form_bottom_buttons( \%save, \%delete, \%rename, \%close, \%help, $tab++ );
		}
	    }
	    else {
		if ($host_id) {
		    $form .= Forms->form_bottom_buttons( \%save, \%close, \%help, $tab++ );
		}
		else {
		    $form .= Forms->form_bottom_buttons( \%save, \%rename, \%close, \%help, $tab++ );
		}
	    }
	}
	elsif ( $obj_view eq 'service_check' ) {
	    my %template = StorProc->fetch_one( 'service_templates', 'servicetemplate_id', $service{'template'} );
	    my $message  = undef;
	    my $inherit  = 0;
	    $inherit = $query->param('inherit');
	    my %cmd          = StorProc->fetch_one( 'commands', 'command_id', $service{'check_command'} );
	    my $command      = $cmd{'name'};
	    my $command_save = $cmd{'name'};
	    my $command_line = $service{'command_line'};
	    if ( $query->param('command') )      { $command      = $query->param('command') }
	    if ( $query->param('command_save') ) { $command_save = $query->param('command_save'); }
	    if ( $query->param('command_line') ) { $command_line = $query->param('command_line'); }

	    # If we are returning to this screen because of a change to the inheritance of the command,
	    # preserve what we had going in other parts of the screen as much as possible.  To do that,
	    # we check for host_id, which is defined (though empty) on a direct view of the screen,
	    # undefined in an inheritance-change refresh.
	    my $externals_arguments;
	    if ( defined $query->param('host_id') ) {
		$externals_arguments = $service{'externals_arguments'};
	    }
	    else {
		$externals_arguments = $query->param('externals_arguments');
	    }

	    if ( (defined($command) ||  defined($command_save)) &&
		(!defined($command) || !defined($command_save) || $command ne $command_save ) ) {
		%cmd = StorProc->fetch_one( 'commands', 'name', $command );
		$command_line = undef;
	    }
	    if ( $inherit or !$command ) {
		%cmd = StorProc->fetch_one( 'commands', 'command_id', $template{'check_command'} );
		if ( $cmd{'name'} ) {
		    $command      = $cmd{'name'};
		    $command_line = $template{'command_line'};
		    $inherit      = 1;
		}
		else {
		    my $got_command  = 0;
		    my $stid         = $template{'parent_id'};
		    my %already_seen = ();
		    until ($got_command) {
			my %t = StorProc->fetch_one( 'service_templates', 'servicetemplate_id', $stid );
			if ( $t{'check_command'} ) {
			    $got_command  = 1;
			    %cmd          = StorProc->fetch_one( 'commands', 'command_id', $t{'check_command'} );
			    $command      = $cmd{'name'};
			    $command_line = $t{'command_line'};
			}
			else {
			    $already_seen{$stid} = 1 if defined $stid;
			    if ( $t{'parent_id'} ) {
				if ( $already_seen{ $t{'parent_id'} } ) {
				    $got_command = 1;
				    $message     = (
    "Note: no parent template (recursively) has a check command defined.<br><b><font color=#FF0000>ERROR:  You have a cyclical chain of parents in your service templates, starting with \"$t{'name'}\".</font></b>"
				    );
				    $command      = undef;
				    $command_line = undef;
				}
				else {
				    $stid = $t{'parent_id'};
				}
			    }
			    else {
				$got_command  = 1;
				$message      = ('Note: no parent template (recursively) has a check command defined.');
				$command      = undef;
				$command_line = undef;
			    }
			}
		    }
		}
	    }
	    %cmd = StorProc->fetch_one( 'commands', 'name', $command );
	    my $arg_string = $command_line;
	    $arg_string =~ s/$command!// if defined $command;
	    my $usage = $command;
	    my @args = split( /\$ARG/i, ( defined( $cmd{'command_line'} ) ? $cmd{'command_line'} : '' ) );
	    if (@args) {
		my $maxarg = 0;
		shift @args;    # drop command
		foreach (@args) {
		    if (/^(\d+)\$/) {
			$maxarg = $1 if $maxarg < $1;
		    }
		}
		my $args = $maxarg ? join( '!', map "ARG$_", 1 .. $maxarg ) : '';
		unless ( $command_line =~ /$command/ ) {
		    $command_line = "$command!$args";
		    $arg_string   = $args;
		}
		$usage .= "!$args";
	    }
	    $form .= Forms->service_top( $name, $session_id, $obj_view, \%objs, $auth_add{'externals'}, $hidden{'selected'} );
	    if (@errors) { $form .= Forms->form_errors( \@errors ) }
	    $form .= Forms->wizard_doc( 'Service Template', undef, undef, 1 );
	    $form .= Forms->display_hidden( 'Service template:', '', $template{'name'} );
	    $form .= Forms->wizard_doc( 'Service Check', $docs{'service_check'}, undef, 1 );
	    $form .= Forms->checkbox_override( 'Inherit check from template:', 'inherit', $inherit, $docs{'use_template_command'} );
	    my %where = ( 'type' => 'check' );
	    my @commands = StorProc->fetch_list_where( 'commands', 'name', \%where );
	    $form .= Forms->list_box_submit( 'Check command:', 'command', \@commands, $command, $required{'check_command'},
		$docs{'check_command'}, $tab++, $inherit );
	    $form .= Forms->display_hidden( 'Command definition:', '', HTML::Entities::encode( $cmd{'command_line'} ) );
	    $form .= Forms->display_hidden( 'Usage:', '', $usage );
	    $form .= Forms->text_area( 'Command line:', 'command_line', $command_line, '3', '80', '', $docs{'command_line'}, '', $tab++, undef, undef, $inherit );
	    $form .= Forms->test_service_check( $test_results, $host, '', $tab++ );
	    if ($enable_externals) {
		$form .= Forms->wizard_doc( 'Externals Macro Arguments (optional)', $docs{'macro_arguments'}, undef, 1 );
		$form .= Forms->text_area(
		    'Externals arguments:',
		    'externals_arguments', $externals_arguments, '3', '80', '', $docs{'externals_arguments'},
		    '', $tab++
		);

		my @service_external_ids =
		  StorProc->fetch_unique( 'external_service_names', 'external_id', 'servicename_id', $hidden{'servicename_id'} );

		my %external_data = ();
		if (@service_external_ids) {
		    ## This loop assumes we have uniqueness of service external names.  That is
		    ## currently not enforced at the database level, but is within the Monarch UI.
		    foreach my $external_id ( @service_external_ids ) {
			my $one_external = StorProc->fetch_map_where( 'externals', 'name', 'display', { 'external_id' => $external_id } );
			@external_data{ keys %$one_external } = values %$one_external;
		    }
		}

		if (%external_data) {
		    my $nocache = time();
		    foreach my $external_name ( sort keys %external_data ) {
			my $external = $external_data{$external_name};
			$external =~ s/\n/<br>/g;
			my $link = "/monarch/monarch.cgi?update_main=1&nocache=$nocache&top_menu=services&view=service_externals&obj=service_externals&task=modify&name=$external_name";
			$form .= Forms->wizard_doc( "<a class='visible_link' href='$link'>$external_name</a>", "<tt>$external</tt>" );
		    }
		    ## FIX MINOR:  add in a "Test Argument Substitution" button (see GWMON-13210)
		}
		else {
		    $form .= Forms->wizard_doc( undef, "This generic service currently has no service externals assigned." );
		}
	    }
	    $hidden{'command_save'} = $command;
	    $form .= Forms->hidden( \%hidden );
	    $help{url} = StorProc->doc_section_url('How+to+manage+services', 'Howtomanageservices-ServiceCheck');
	    $form .= Forms->form_bottom_buttons( \%save, \%help, $tab++ );
	}
	elsif ( $obj_view eq 'service_dependencies' ) {
	    my $dep_template = $query->param('dep_template');
	    my @dep_hosts    = ();
	    my $dep_service  = undef;
	    if ($dep_template) {
		my %dep = StorProc->fetch_one( 'service_dependency_templates', 'name', $dep_template );
		my %s = StorProc->fetch_one( 'service_names', 'servicename_id', $dep{servicename_id} );
		push @errors, delete $s{'error'} if defined $s{'error'};
		$dep_service = $s{'name'};
		my ( $host, $hosts ) = StorProc->get_dep_on_hosts( $dep{'servicename_id'}, '0' );
		my @hosts = @{$hosts};
		@dep_hosts = ('same host');
		push( @dep_hosts, @hosts );
	    }
	    $form .= Forms->service_top( $name, $session_id, $obj_view, \%objs, $auth_add{'externals'}, $hidden{'selected'} );
	    if (@errors) { $form .= Forms->form_errors( \@errors ) }
	    $form .= Forms->wizard_doc( 'Service Dependencies', $docs{'dependencies'}, undef, 1 );
	    my %dependencies = StorProc->get_servicename_dependencies( $service{'servicename_id'} );
	    $form .= Forms->dependency_list( $name, 'services', $service{'servicename_id'}, $session_id, \%dependencies );
	    my @dep_templates = StorProc->fetch_list( 'service_dependency_templates', 'name' );
	    $form .= Forms->dependency_add( $dep_template, \@dep_templates, \@dep_hosts, $dep_service, \%docs, $tab++ );
	    $hidden{'name'} = $name;
	    $form .= Forms->hidden( \%hidden );
	    my %add_dependency = ( 'name' => 'add_dependency', 'value' => 'Add Dependency' );
	    $help{url} = StorProc->doc_section_url('How+to+manage+service+dependencies', 'Howtomanageservicedependencies-ApplyingServiceDependenciesthroughManageService');
	    $form .= Forms->form_bottom_buttons( \%add_dependency, \%help, $tab++ );
	}
	elsif ( $obj_view eq 'service_externals' ) {
	    $hidden{'service_id'}   = $query->param('service_id');
	    $hidden{'service_name'} = $query->param('service_name');
	    my %objs = (
		'service_id'   => $hidden{'service_id'},
		'service_name' => $hidden{'service_name'}
	    );
	    $form .= Forms->service_top( $name, $session_id, $obj_view, \%objs, $auth_add{'externals'}, $hidden{'selected'} );
	    my %externals = ();
	    my %where     = ( 'servicename_id' => $service{'servicename_id'} );
	    my @externals = StorProc->fetch_list_where( 'external_service_names', 'external_id', \%where );
	    foreach my $eid (@externals) {
		my %e = StorProc->fetch_one( 'externals', 'external_id', $eid );
		$externals{ $e{'name'} } = $eid;
	    }
	    if (@errors) { $form .= Forms->form_errors( \@errors ) }
	    $form .= Forms->wizard_doc( 'Service Externals', $docs{'service_externals'}, undef, 1 );
	    if (@messages) {
		$form .= Forms->form_message( 'Status:', \@messages, 'msg' );
	    }
	    my %w = ( 'type' => 'service' );
	    my @external_names = StorProc->fetch_list_where( 'externals', 'name', \%w );
	    my @external_list = ();
	    foreach my $s (@external_names) {
		unless ( $externals{$s} ) { push @external_list, $s }
	    }
	    # This call does not include a \%modified parameter because we are dealing here with generic services,
	    # not the host services (instances of the generic services) which are attached to particular hosts.
	    $form .=
	      Forms->external_list( $session_id, $name, \%externals, \@external_list, 'service_name', $hidden{'service_id'},
		$hidden{'service_name'} );
	    $hidden{'type'} = 'service';
	    $hidden{'id'}   = $properties{'host_id'};
	    $hidden{'name'} = $name;
	    $form .= Forms->hidden( \%hidden );
	    $help{url} = StorProc->doc_section_url('How+to+configure+externals');
	    $form .= Forms->form_bottom_buttons( \%help );
	}
	elsif ( $obj_view eq 'service_profiles' ) {
	    $form .= Forms->service_top( $name, $session_id, $obj_view, \%objs, $auth_add{'externals'}, $hidden{'selected'} );
	    if (@errors) { $form .= Forms->form_errors( \@errors ) }
	    $form .= Forms->wizard_doc( 'Service Profiles', $docs{'service_profiles'}, undef, 1 );
	    my @members = ();
	    my %w       = ( 'servicename_id' => $service{'servicename_id'} );
	    my @sids    = StorProc->fetch_list_where( 'serviceprofile', 'serviceprofile_id', \%w );
	    foreach (@sids) {
		my %s = StorProc->fetch_one( 'profiles_service', 'serviceprofile_id', $_ );
		push @members, $s{'name'};
	    }
	    my @nonmembers = StorProc->fetch_list( 'profiles_service', 'name' );
	    $form .= Forms->members( 'Service profiles:', 'profiles', \@members, \@nonmembers, '', '20', $docs{'profiles'}, '', $tab++ );
	    $hidden{'obj_view'} = 'service_profiles';
	    $form .= Forms->hidden( \%hidden );
	    $help{url} = StorProc->doc_section_url('About+Profiles');
	    $form .= Forms->form_bottom_buttons( \%save, \%help, $tab++ );
	}
	elsif ( $obj_view eq 'apply_hosts' ) {
	    $form .= Forms->service_top( $name, $session_id, $obj_view, \%objs, $auth_add{'externals'}, $hidden{'selected'} );
	    if (@errors) { $form .= Forms->form_errors( \@errors ) }
	    $form .= Forms->wizard_doc( 'Apply Hosts', $docs{'apply'}, undef, 1 );
	    my %where = ( 'servicename_id' => $service{'servicename_id'} );
	    my @hosts     = StorProc->fetch_list_where( 'services', 'host_id', \%where );
	    my @host_list = ();
	    my %host_name = StorProc->get_table_objects('hosts', 1);
	    foreach my $hid (@hosts) {
		push @host_list, $host_name{$hid};
	    }
	    if (@host_list) {
		## FIX THIS:  We have sometimes seen the @host_list to contain duplicate hostnames; eliminate them,
		## either by being more careful as we construct the list, or by eliminating the upstream source of
		## the problem (the same service running as separate host-service instances on the same host, even
		## without this being an instanced service).  But for now, we continue to display such duplicates,
		## so we can sense when the problem shows up, so we can debug whatever causes it.
		$form .= Forms->list_box_display( 'Hosts:', 'hosts', \@host_list, 25,
		    "Hosts that have this service. The selected service properties will be applied to the &quot;" . $name .
		    "&quot; host services on these hosts. All of these hosts will be so affected; individual hosts are not selectable." );
	    }
	    else {
		push @host_list, "<h7>No hosts are using the $name service.</h7>";
		$form .= Forms->form_message( 'Hosts:', \@host_list, 'row1' );
	    }
	    $form .= Forms->apply_select( $view, \%service, $nagios_ver, $auth_modify{'externals'}, $tab++ );
	    $form .= Forms->hidden( \%hidden );
	    $form .= Forms->wizard_doc( 'Caution', $docs{'caution'}, 1, 1 );
	    $help{url} = StorProc->doc_section_url('How+to+manage+services', 'Howtomanageservices-ApplyHosts');
	    $form .= Forms->form_bottom_buttons( \%apply, \%help, $tab++ );
	}
	elsif ( $obj_view eq 'delete' ) {
	    my $message = qq(Are you sure you want to remove service \"$name\" from all hosts and profiles?);
	    $form .= Forms->are_you_sure( 'Confirm Delete', $message, 'confirm_delete', \%hidden );

	}
	elsif ( $obj_view eq 'applied' ) {
	    my %objs = ( 'service_id' => $service{'servicename_id'}, 'name' => $name );
	    $form .= Forms->service_top( $name, $session_id, $obj_view, \%objs, $auth_add{'externals'}, $hidden{'selected'} );
	    $form .= Forms->display_hidden( 'Applied:', '', $message_applied );
	    $form .= Forms->hidden( \%hidden );
	    $form .= Forms->form_bottom_buttons();

	}
	elsif ( $obj_view eq 'saved' ) {
	    my %objs = ( 'service_id' => $service{'servicename_id'}, 'name' => $name );
	    $form .= Forms->service_top( $name, $session_id, $obj_view, \%objs, $auth_add{'externals'}, $hidden{'selected'} );
	    $form .= Forms->display_hidden( 'Saved:', '', $name );
	    $form .= Forms->hidden( \%hidden );
	    $form .= Forms->form_bottom_buttons( \%close );
	}
	elsif ( $obj_view eq 'rename' ) {
	    my $illegal_chars = qq(/\\` ~+!\$\%^&*|'"<>?,()=[]:{}#;);
	    ## FIX LATER:  someday we ought to validate the new_name length as well, but for the
	    ## moment we might not have the capability to add such additional ANDed constraints.
	    my $validation_mini_profile = {
		name => {
		    ## We override the standard validation to allow essentially anything for an existing name,
		    ## so we can rename it to something legal.
		    constraint => '.+'
		},
		new_name => {
		    constraint => '[^/\\\\` ~\+!\$\%\^\&\*\|\'\"<>\?,\(\)\'=\[\]\{\}\:\#;]+',
		    message    => "The new name field cannot contain any of the following characters:\n$illegal_chars",
		},
	    };
	    $form .= Validation->dfv_profile_javascript($validation_mini_profile);
	    # $form .= &$Instrument::show_trace_as_html_comment();
	    $form .= Forms->form_top( 'Rename Service', Validation->dfv_onsubmit_javascript(
		"if (this.clicked == 'cancel') { return true; }"
	    ) );
	    if (@errors) { $form .= Forms->form_errors( \@errors ) }
	    $form .= Forms->display_hidden( 'Service name:', 'name', $name );
	    $form .= Forms->text_box( 'Rename to:', 'new_name', '', $textsize{'name'}, '', $docs{'name'}, '', $tab++ );
	    $hidden{'obj_view'} = 'rename';
	    $form .= Forms->hidden( \%hidden );
	    $form .= Forms->form_bottom_buttons( \%rename, \%cancel, $tab++ );
	}
	elsif ( $obj_view eq 'new' ) {
	    my $template = $query->param('template');
	    $form .= Validation->dfv_profile_javascript();
	    $form .= &$Instrument::show_trace_as_html_comment();
	    $form .= Forms->form_top( 'New Service', Validation->dfv_onsubmit_javascript(
		"if (this.clicked == 'cancel') { return true; }"
	    ) );
	    if (@errors) { $form .= Forms->form_errors( \@errors ) }
	    $form .= Forms->text_box( 'Service name:', 'name', $name, $textsize{'name'}, '', $docs{'name'}, '', $tab++ );
	    my @members = StorProc->fetch_list( 'service_templates', 'name' );
	    $form .= Forms->list_box( 'Service template:', 'template', \@members, $template, '', $docs{'service_template'}, '', $tab++ );
	    $form .= Forms->hidden( \%hidden );
	    $help{url} = StorProc->doc_section_url('How+to+manage+services', 'Howtomanageservices-CreatingaNewServiceandManagingExisting');
	    $form .= Forms->form_bottom_buttons( \%add, \%cancel, \%help, $tab++ );
	}
	elsif ( $obj_view eq 'clone' ) {
	    my $clone_service = $query->param('clone_service');
	    my $apply_profile = $query->param('apply_profile');
	    if ( $clone_service ) {
		$form .= Validation->dfv_profile_javascript();
		# $form .= &$Instrument::show_trace_as_html_comment();
		$form .= Forms->form_top( 'Clone Service', Validation->dfv_onsubmit_javascript(
		    "if (this.clicked == 'cancel') { return true; }"
		) );
		if (@errors) { $form .= Forms->form_errors( \@errors ) }
		$hidden{'clone_service'} = $clone_service;
		(my $service_copy = $clone_service . '-copy') =~ tr/-._@a-zA-Z0-9/_/c;
		$form .= Forms->text_box( 'Service name:', 'name', $service_copy, $textsize{'name'}, '', $docs{'name'}, '', $tab++ );
		$form .= Forms->checkbox( 'Apply to profiles:', 'apply_profile', $apply_profile, '', '', $tab++ );
	    }
	    else {
		$form .= Forms->form_top( 'Clone Service', '' );
		if (@errors) { $form .= Forms->form_errors( \@errors ) }
		my @members = StorProc->fetch_list( 'service_names', 'name' );
		$form .= Forms->list_box( 'Select service:', 'clone_service', \@members, $clone_service, '', '', '', $tab++ );
	    }
	    $form .= Forms->hidden( \%hidden );
	    $help{url} = StorProc->doc_section_url('How+to+manage+services', 'Howtomanageservices-CreatingaNewServiceandManagingExisting');
	    $form .= Forms->form_bottom_buttons( \%next, \%cancel, \%help, $tab++ );
	}
    }
    return $form;
}

# This doesn't protect against server-based timing attacks (race
# conditions), but it should protect against client-based attacks.
sub secure_abs_path {
    my $test_path  = $_[0];
    my $abs_prefix = $_[1];
    my $abs_path   = undef;

    if ($abs_prefix =~ m{^/}) {
	$abs_prefix .= '/' if $abs_prefix !~ m{/$};
	if ( $test_path =~ m{^\Q$abs_prefix\E} ) {
	    $abs_path = realpath($test_path);

	    # Validate that the absolute path starts with the same prefix we demand, to avoid
	    # symlink or parent-directory references sidestepping our security precautions.
	    if ( defined($abs_path) ) {
		$abs_path .= '/' if -d $abs_path;
		if ( $abs_path !~ m{^\Q$abs_prefix\E} ) {
		    ## This is the only symlink jump we will tolerate in the pathname.
		    my $gwlink = readlink '/usr/local/groundwork';
		    if ( defined($gwlink) ) {
			if ( $gwlink !~ m{^/} ) {
			    $gwlink = '/usr/local/groundwork/' . $gwlink;
			}
			$gwlink = realpath($gwlink);
		    }
		    if ( defined($gwlink) ) {
			$abs_prefix =~ s{^/usr/local/groundwork}{$gwlink};
			$abs_path = undef if $abs_path !~ m{^\Q$abs_prefix\E};
		    }
		    else {
			$abs_path = undef;
		    }
		}
	    }
	}
    }

    return $abs_path;
}

sub profile_importer() {
    local $_;

    my @files       = $query->$multi_param('file');
    my $folder      = $query->param('folder');
    my $name        = $query->param('name');
    my $task        = $query->param('task');
    my $overwrite   = $query->param('overwrite');
    my $form        = undef;
    my @messages    = ();
    my $base_dir    = '/usr/local/groundwork/monarch/profiles';
    my %links       = ();
    my @dirs        = ();
    my %description = ();

    if ( $query->param('close') ) { $obj_view = 'close' }
    if ( $query->param('delete') ) {
	## We must not depend on the order in which the base file and any symlinks to it
	## get deleted, so we do all verification first and queue files for deletion.
	my @filepaths = ();

	foreach my $file (@files) {
	    next unless defined($file) and $file =~ m{^([^/].*)/(.+\.xml)$};
	    my $rel_dir  = $1;
	    my $filename = $2;

	    next if $rel_dir =~ m{/};  # We only support 1-level classification.

	    my $abs_dir = secure_abs_path( "$folder/$rel_dir", "$base_dir/" );
	    next if !defined($abs_dir) or !-d $abs_dir;
	    my $file_path = "$abs_dir$filename";
	    next if !-l $file_path and !-f _;

	    # If we're in the "All" directory, $folder/$file will be a file, not a symlink.
	    my $abs_file_path = secure_abs_path( "$folder/$file", "$base_dir/" );
	    ## We do want to delete any dead or insecure symlink from within the secure area.
	    next unless defined($abs_file_path) or -l $file_path;

	    my $is_base_file = defined($abs_file_path) && ($abs_file_path eq $file_path);
	    if ( $is_base_file ? !-f "$folder/$file" : !-l "$folder/$file" ) {
		push @errors,
		  HTML::Entities::encode( "The $folder/$file " . ( $is_base_file ? "file" : "symlink" ) . " is not available on the server." );
	    }
	    ## Delete symlinks before files.
	    elsif ( -l "$folder/$file" ) {
		unshift @filepaths, $file;
	    }
	    else {
		push @filepaths, $file;
	    }
	}
	foreach my $file (@filepaths) {
	    my $result = StorProc->delete_file( $folder, $file );
	    if ( $result =~ /error/i ) {
		push @errors, $result;
		## If there is any symlink that we cannot delete, we must not delete the $base_dir/$file itself.
		last;
	    }
	}
    }
    elsif ( $query->param('remove') ) {
	if ( !defined($name) ) {
	    if ( $folder =~ s{/([^/]+)$}{} ) {
		$name = $1;
	    }
	    else {
		$name = '';
	    }
	}
	if ( $name eq '' or !defined( secure_abs_path( "$folder/$name", "$base_dir/" ) ) or !-d "$folder/$name" ) {
	    push @errors, HTML::Entities::encode("The $folder/$name directory is not available on the server.");
	    $folder = undef;
	}
	elsif (@files) {
	    foreach my $file (@files) {
		if (   $file !~ m{^[^/]+\.xml$}
		    or !defined( secure_abs_path( "$folder/$name/$file", "$base_dir/" ) )
		    or !-f "$folder/$name/$file" )
		{
		    ## We should have just *.xml filenames here, with no directories in them.
		    push @errors, HTML::Entities::encode("The $file file is not available on the server.");
		}
		else {
		    if ( $file !~ /^perfconfig/ ) {
			if ( open PROFILE, '<', "$folder/$name/$file" ) {
			    local $/;    # slurp mode
			    my $xml = <PROFILE>;
			    close PROFILE;
			    if ( defined($xml) and $xml ne '' ) {
				my %profile = ();
				eval { %profile = StorProc->parse_profile_xml($xml); };
				if ($@) {
				    chomp $@;
				    push @errors, "<br><b>$file</b>: $@";
				}
				else {
				    $description{$file} = $profile{description};
				}
			    }
			}
		    }

		    # The actual file will be referenced and deleted via the "All -> ." directory-symlink, so we
		    # still count that as a symlink (of sorts).  Also list any associated perfconfig files/links.
		    ( my $suffix = $file ) =~ s/^(?:host-profile-|service-profile-|service-)//;

		    # Find all related files and symlinks, even in sibling directories.  We quote to avoid mistaken globs.
		    my @symlinks = glob "\Q$base_dir\E/*/{\Q$file\E,\Qperfconfig-$suffix\E}";
		    foreach (@symlinks) {
			if (m{/(perfconfig-([^/]+)\.xml)$}) {
			    $description{$1} = "Performance configuration setup for $2 objects.";
			}
			m{$base_dir/(.+)/(.+)};
			$links{$1}{$2} = 1;
		    }
		}
	    }
	    @files = ();
	    foreach my $subdir ( sort keys %links ) {
		foreach my $link ( sort keys %{ $links{$subdir} } ) {
		    push @dirs,  $subdir;
		    push @files, $link;
		}
	    }
	    $obj_view         = 'delete';
	    $hidden{'folder'} = HTML::Entities::encode($folder);
	    $hidden{'name'}   = HTML::Entities::encode($name);
	}
	else {
	    push @errors, "You did not specify any profiles to remove.";
	}
    }
    if ( $query->param('upload') ) {
	@files = ();
	## The filename should have no prefixed directories, but just to be safe ...
	( my $file = $query->param('upload_file') ) =~ s{.*/}{};
	if ( $file eq '' ) {
	    push @errors, "You did not specify an Upload file.";
	}
	elsif ( $file !~ /\.xml$/ ) {
	    push @errors, "You specified an Upload file ($file) that does not have a <tt>\".xml\"</tt> filename extension.";
	}
	elsif ( -l "$base_dir/$file" ) {
	    push @errors, "You cannot replace an existing symlink ($base_dir/$file).";
	}
	elsif ( -e _ and not -f _ ) {
	    push @errors, "You cannot replace an existing non-file ($base_dir/$file).";
	}
	elsif ( -f _ and not $overwrite ) {
	    push @errors, "You cannot replace an existing file unless you select overwriting below.";
	}
	else {
	    my ( $filedata, $errs ) = StorProc->upload(
		$base_dir, $file, "$base_dir/$file",
		## The validator takes ($filename, $filedata) as arguments.
		sub {
		    my %xml_data = ();
		    eval { %xml_data = StorProc->parse_xml( $_[1] ); };
		    if ( $@ || exists $xml_data{'error'} ) {
			my @parse_errors = split( /<br>/, $@ || $xml_data{'error'}, 29 );
			@parse_errors = @parse_errors[ 0 .. 27 ] if @parse_errors > 28;
			my $parse_errors = join( "\n", @parse_errors );
			return "Your uploaded file ($_[0]) does not contain valid XML. Initial parsing errors are:<pre>$parse_errors</pre>";
		    }
		    return '';
		}
	    );
	    my @errs = @$errs;
	    if (@errs) {
		push @errors, @errs;
		if ( $errs[0] =~ m{cannot open "[^:]+:(/usr/local/groundwork/monarch/profiles/.+)" for writing \(Permission denied\)}
		  && -f "$1" && !-w "$1" ) {
		    push @errors, 'Hint: you are not allowed to overwrite an existing read-only file during an upload.  To avoid such collisions, rename your file before uploading.';
		}
	    }
	    elsif ( not symlink "../$file", "$folder/$file" ) {
		push @errors, "Cannot create a symlink in the $folder/ directory to the uploaded file ($!).";
		my $result = StorProc->delete_file( $base_dir, $file );
		if ( $result =~ /error/i ) { push @errors, $result }
	    }
	    else {
		push @files, $file;
	    }
	}
    }
    if ( $query->param('import') ) {
	if ( @files && $files[0] ne '' ) {
	    use MonarchProfileImport;
	    push @messages, "-----------------------------------------------------";
	    foreach my $file (@files) {
		unless ($file) { next }
		push @messages, "Importing $file";
		my @msgs = ProfileImporter->import_profile( $folder, $file, $overwrite );
		unshift @messages, '<b>Error(s) occurred while importing profile(s). See below for details.</b>'
		  if ( $msgs[0] =~ /error/i && $messages[0] !~ /error/i );
		push @messages, @msgs;
		push @messages, "-----------------------------------------------------";
	    }
	}
	else {
	    push @messages, "No profiles were selected.";
	}
	$obj_view = 'status';
    }
    unless ($obj_view) { $obj_view = 'get_file' }
    if ( $query->param('close') ) {
	$form .= Forms->header( $page_title, $session_id, $top_menu );
    }
    elsif ( $obj_view eq 'get_file' ) {
	my %docs = Doc->profile_importer();
	$form .= Forms->header( $page_title, $session_id, $top_menu );
	$form .= Forms->form_top_file( "Profile Importer", '' );
	$help{url} = StorProc->doc_section_url('How+to+import+profiles');
	if ( $task eq 'new' ) {
	    $folder = "$base_dir/Uploaded";
	    if ( !defined( secure_abs_path( $folder, "$base_dir/" ) ) or !-d $folder ) {
		push @errors, HTML::Entities::encode("The $folder directory is not available on the server.");
		$folder = undef;
	    }
	    $form .= Forms->form_errors( \@errors ) if @errors;
	    $form .= Forms->form_status( 'Success:', "The @files profile is now available in the Uploaded folder.", 'row1' ) if @files;
	    $form .= Forms->wizard_doc( 'Upload Profiles', $docs{'profile_uploader'}, undef, 1 );
	    $form .= Forms->hidden( \%hidden );
	    if ( defined $folder ) {
		$form .= Forms->display_hidden( 'Upload folder:', 'folder', HTML::Entities::encode("$folder"), $docs{'upload_folder'} );
		$form .= Forms->form_file( $tab++ );
		$form .= Forms->checkbox( 'Overwrite existing file?', 'overwrite', '', $docs{'overwrite_file'}, '', $tab++ );
		$form .= Forms->form_bottom_buttons( \%upload, \%close, \%help, $tab++ );
	    }
	    else {
		$form .= Forms->form_bottom_buttons( \%close, \%help, $tab++ );
	    }
	}
	else {
	    $folder = "$base_dir/" if not defined $folder;
	    $folder .= '/'   if $folder !~ m{/$};
	    $folder .= $name if defined $name;

	    my @files = ();
	    if ( !defined( secure_abs_path( $folder, "$base_dir/" ) ) or !-d $folder ) {
		push @errors, HTML::Entities::encode("The $folder directory is not available on the server.");
		$folder = undef;
	    }
	    else {
		my @all_files = StorProc->get_dir( "$folder", [qw(.xml)] );
		foreach (@all_files) {
		    if ( $_ =~ /\.xml$/ && $_ !~ /perfconfig/ ) {
			if ( open PROFILE, '<', "$folder/$_" ) {
			    local $/;    # slurp mode
			    my $xml = <PROFILE>;
			    close PROFILE;
			    if ( defined($xml) and $xml ne '' ) {
				my %profile = ();
				eval {
				    %profile = StorProc->parse_profile_xml($xml);
				    die "$profile{'error'}\n" if $profile{'error'};
				};
				if ($@) {
				    chomp $@;
				    ( my $dir = $folder ) =~ s{.*/}{};
				    push @errors, "<br><b>" . HTML::Entities::encode("$dir/$_") . "</b>: $@";
				}
				else {
				    push @files, $_;
				    $description{$_} = $profile{description};
				}
			    }
			}
		    }
		}
	    }
	    $form .= Forms->form_errors( \@errors ) if @errors;
	    $form .= Forms->wizard_doc( 'Import Profiles', $docs{'profile_importer'}, undef, 1 );
	    $form .= Forms->hidden( \%hidden );

	    if ( defined $folder ) {
		$form .= Forms->display_hidden( 'Import folder:', 'folder', HTML::Entities::encode("$folder"), $docs{'import_folder'} );
		if ( open( README, '<', "$folder/README" ) ) {
		    local $/;    # slurp mode
		    my $slurp = <README>;
		    close(README);
		    my ( $heading, $text ) = split /\n/, $slurp, 2;
		    $form .= Forms->wizard_doc( $heading, $text, undef, 1 );
		}
		$form .= Forms->form_files( "$folder", 0, [], \@files, \%description, $tab++ );
	    }

	    if (@files) {
		$form .= Forms->checkbox( 'Overwrite existing objects?', 'overwrite', '', $docs{'overwrite_objects'}, '', $tab++ );
		my %remove = ( 'name' => 'remove', 'value' => 'Remove' );
		my %import = ( 'name' => 'import', 'value' => 'Import' );
		$form .= Forms->form_bottom_buttons( \%import, \%remove, \%close, \%help, $tab++ );
	    }
	    else {
		$form .= Forms->form_bottom_buttons( \%close, \%help, $tab++ );
	    }
	}
    }
    elsif ( $obj_view eq 'delete' ) {
	my %docs = Doc->profile_importer();
	$form .= Forms->header( $page_title, $session_id, $top_menu );
	$form .= Forms->form_top( "Profile Deletion", '' );
	$form .= Forms->form_errors( \@errors ) if @errors;
	$form .= Forms->wizard_doc( 'Delete Profiles', $docs{'profile_delete'}, undef, 1 );
	$form .= Forms->form_files( "$folder", 1, \@dirs, \@files, \%description, $tab++ );
	$form .= Forms->hidden( \%hidden );
	$form .= Forms->form_bottom_buttons( \%delete, \%cancel, $tab++ );
    }
    elsif ( $obj_view eq 'status' ) {
	$form .= Forms->header( $page_title, $session_id, $top_menu );
	$form .= Forms->form_top( "Profile Importer", '' );
	if ( $messages[0] =~ /error/i ) {
	    push @messages, "Please make the necessary corrections and try again.";
	}
	$form .= Forms->profile_import_status( \@messages );
	$form .= Forms->hidden( \%hidden );
	$form .= Forms->form_bottom_buttons( \%close, $tab++ );
    }
    return $form;
}

#
############################################################################
# Manage Host
#

# FIX LATER:  Should this be modified and also called from host_profile() instead of the existing code?
sub apply_host_profile($@) {
    my $profile = shift;
    my @hosts   = @_;
    my $name    = $profile->{'name'};
    my $cnt     = 0;

    my $apply_parents        = $query->param('apply_parents');
    my $apply_hostgroups     = $query->param('apply_hostgroups');
    my $apply_escalations    = $query->param('apply_escalations');
    my $apply_contactgroups  = $query->param('apply_contactgroups');
    my $apply_variables      = $query->param('apply_variables');
    my $apply_detail         = $query->param('apply_detail');
    my $apply_host_externals = $query->param('apply_host_externals');
    my $apply_services       = $query->param('apply_services');

    my %where = ( 'hostprofile_id' => $profile->{'hostprofile_id'} );
    my @profiles = StorProc->fetch_list_where( 'profile_host_profile_service', 'serviceprofile_id', \%where );
    unless (@hosts) {
	push @errors, "No hosts provided to apply host profile \"$name\" to.";
    }
    unless (@errors) {
	my %hosts = ();
	foreach my $host (@hosts) {
	    $hosts{$host} = 1;
	}
	my @distinct_hosts = keys %hosts;
	foreach my $hid (@distinct_hosts) {
	    if ($apply_parents) {
		my $result = StorProc->delete_all( 'host_parent', 'host_id', $hid );
		if ( $result =~ /^Error/ ) { push @errors, $result }
		my %w = ( 'hostprofile_id' => $profile->{'hostprofile_id'} );
		my @parents = StorProc->fetch_list_where( 'profile_parent', 'host_id', \%w );
		foreach my $pid (@parents) {
		    ## Because this is a bulk operation against independently established lists of hosts,
		    ## we simply ignore an attempt to apply a parent to the same host, rather than complain
		    ## about it.  This adaptive action should make the host profile easier to use in practice.
		    unless ( $pid == $hid ) {
			my @vals = ( $hid, $pid );
			my $result = StorProc->insert_obj( 'host_parent', \@vals );
			if ( $result =~ /^Error/ ) { push @errors, $result }
		    }
		}
	    }
	    if ($apply_hostgroups) {
		my $result = StorProc->delete_all( 'hostgroup_host', 'host_id', $hid );
		if ( $result =~ /^Error/ ) { push @errors, $result }
		my %w = ( 'hostprofile_id' => $profile->{'hostprofile_id'} );
		my @hostgroups = StorProc->fetch_list_where( 'profile_hostgroup', 'hostgroup_id', \%w );
		foreach my $hgid (@hostgroups) {
		    my @vals = ( $hgid, $hid );
		    my $result = StorProc->insert_obj( 'hostgroup_host', \@vals );
		    if ( $result =~ /^Error/ ) { push @errors, $result }
		}
	    }
	    if ($apply_contactgroups) {
		my %w = ( 'host_id' => $hid );
		my $result = StorProc->delete_one_where( 'contactgroup_host', \%w );
		if ( $result =~ /^Error/ ) { push @errors, $result }
		%w = ( 'hostprofile_id' => $profile->{'hostprofile_id'} );
		my @contactgroups = StorProc->fetch_list_where( 'contactgroup_host_profile', 'contactgroup_id', \%w );
		foreach my $cgid (@contactgroups) {
		    my @vals = ( $cgid, $hid );
		    my $result = StorProc->insert_obj( 'contactgroup_host', \@vals );
		    if ( $result =~ /^Error/ ) { push @errors, $result }
		}
	    }
	    if ( $apply_services eq 'replace' ) {
		my $result = StorProc->delete_all( 'serviceprofile_host', 'host_id', $hid );
		if ( $result =~ /^Error/ ) { push @errors, $result }
		foreach my $spid (@profiles) {
		    my @vals = ( $spid, $hid );
		    my $result = StorProc->insert_obj( 'serviceprofile_host', \@vals );
		    if ( $result =~ /^Error/ ) { push @errors, $result }
		}
	    }
	    else {
		foreach my $spid (@profiles) {
		    my %w = ( 'serviceprofile_id' => $spid, 'host_id' => $hid );
		    my %p = StorProc->fetch_one_where( 'serviceprofile_host', \%w );
		    unless ( $p{'host_id'} ) {
			my @vals = ( $spid, $hid );
			my $result = StorProc->insert_obj( 'serviceprofile_host', \@vals );
			if ( $result =~ /^Error/ ) { push @errors, $result }
		    }
		}
	    }
	}
	if ($apply_escalations) {
	    my %vals = (
		'host_escalation_id'    => $profile->{'host_escalation_id'},
		'service_escalation_id' => $profile->{'service_escalation_id'}
	    );
	    foreach my $hid (@distinct_hosts) {
		my $result = StorProc->update_obj( 'hosts', 'host_id', $hid, \%vals );
		if ( $result =~ /^Error/ ) { push @errors, $result }
	    }
	}
	if ($apply_detail) {
	    my %vals = ( 'hosttemplate_id' => $profile->{'host_template_id'} );
	    foreach my $hid (@distinct_hosts) {
		my $result = StorProc->update_obj( 'hosts', 'host_id', $hid, \%vals );
		if ( $result =~ /^Error/ ) { push @errors, $result }
	    }
	    my @errs = StorProc->host_profile_apply( $profile->{'hostprofile_id'}, \@distinct_hosts, !$apply_detail, !$apply_variables );
	    if (@errs) { push( @errors, @errs ) }
	    ## FIX THIS:  Compare this application of hostextinfo_id to what happens inside
	    ## StorProc->host_profile_apply().  Why are we overriding that setting?
	    ## FIX MINOR:  just drop these lines, as they seem to be redundant
	    if (0) {
		## FIX MAJOR:  we are updating the wrong hosts here:  this affects all hosts with the specified host profile,
		## when we should be looping and only updating @distinct_hosts
		%vals = ( 'hostextinfo_id' => $profile->{'host_extinfo_id'} );
		my $result = StorProc->update_obj( 'hosts', 'hostprofile_id', $profile->{'hostprofile_id'}, \%vals );
		if ( $result =~ /^Error/ ) { push @errors, $result }
	    }
	}
	elsif ($apply_variables) {
	    my @errs = StorProc->host_profile_apply( $profile->{'hostprofile_id'}, \@distinct_hosts, !$apply_detail, !$apply_variables );
	    if (@errs) { push( @errors, @errs ) }
	}
	if ($apply_host_externals) {
	    if ($enable_externals) {
		# FIX LATER:  There is still a lot of nested database access here.  That might be very slow to execute with
		# a large configuration.  See if we can optimize by pulling complete copies of certain tables back from the
		# database before we start looping, then just access those local copies within the loop structure here.

		my %w = ( 'hostprofile_id' => $profile->{'hostprofile_id'} );
		my @externals = StorProc->fetch_list_where( 'external_host_profile', 'external_id', \%w );
		foreach my $hid (@distinct_hosts) {
		    if ( $apply_services eq 'replace' ) {
			my $result = StorProc->delete_all( 'external_host', 'host_id', $hid );
			if ( $result =~ /^Error/ ) { push @errors, $result }
			foreach my $ext (@externals) {
			    my %external = StorProc->fetch_one( 'externals', 'external_id', $ext );
			    my @vals = ( $ext, $hid, $external{'display'}, $DEFINED_REF );
			    $result = StorProc->insert_obj( 'external_host', \@vals );
			    if ( $result =~ /^Error/ ) { push @errors, $result }
			}
		    }
		    if ( $apply_services eq 'merge' ) {
			foreach my $ext (@externals) {
			    my %where = (
				'external_id' => $ext,
				'host_id'     => $hid
			    );
			    my @host_externals = StorProc->fetch_list_where( 'external_host', 'modified', \%where );
			    if (@host_externals) {
				if ($host_externals[0] == 0) {
				    my %external = StorProc->fetch_one( 'externals', 'external_id', $ext );
				    my %values = ( 'data' => $external{'display'}, 'modified' => $DEFINED_REF );
				    my $result = StorProc->update_obj_where( 'external_host', \%values, \%where );
				    if ( $result =~ /^Error/ ) { push @errors, $result }
				}
			    }
			    else {
				my %external = StorProc->fetch_one( 'externals', 'external_id', $ext );
				my @vals = ( $ext, $hid, $external{'display'}, $DEFINED_REF );
				my $result = StorProc->insert_obj( 'external_host', \@vals );
				if ( $result =~ /^Error/ ) { push @errors, $result }
			    }
			}
		    }
		}
	    }
	}
	# FIX MAJOR:  Ought we to also pass a user-selectable $apply_service_externals flag here, to
	# control whether service externals within services within the host profile are applied?  And
	# should we modify the StorProc->service_profile_apply() routine to ensure that we perhaps do
	# different things for replace and merge actions, with respect to such service externals?
	my $err;
	( $cnt, $err ) = StorProc->service_profile_apply( \@profiles, $apply_services, \@distinct_hosts );
	if ($err) { push( @errors, @{$err} ) }
    }
    return $cnt;
}

sub manage_host() {
    local $_;

    my @views = (
	'host_detail',       'host_profile',     'service_profiles', 'parents',
	'hostgroups',        'escalation_trees', 'host_externals',   'host_external_detail',
	'services',          'service_detail',   'service_check',    'service_dependencies',
	'service_externals', 'service_external_detail'
    );
    foreach my $v (@views) {
	if ( $query->param($v) ) { $obj_view = $v }
    }
    my $by   = 'name';
    my $name = $query->param('name');
    my $host = $query->param('host');
    unless ($name) { $by = 'address' }
    my $form         = undef;
    my $message      = undef;
    my $required     = undef;
    my $results      = undef;
    my $test_results = undef;
    $hidden{'form_service'} = $query->param('form_service');
    %properties = defined($name) ? StorProc->fetch_host( $name, $by ) : ();
    push @errors, @{ $properties{'errors'} } if defined $properties{'errors'};

    if ( $query->param('close') || $query->param('continue') ) {
	$obj_view = 'close';
    }
    elsif ( $query->param('apply') ) {
	if ( $obj_view eq 'host_profile' ) {
	    my $host_profile = $query->param('profile_host');
	    my $hostprofile_id;
	    my %values = ();
	    my %hp = ();
	    if ( !$host_profile || $host_profile eq '-- no host profile --' ) {
		$hostprofile_id = '';
	    }
	    else {
		%hp = StorProc->fetch_one( 'profiles_host', 'name', $host_profile );
		$hostprofile_id = $hp{'hostprofile_id'};
	    }
	    $hidden{'hostprofile_id'} = $hostprofile_id;
	    %values = ( 'hostprofile_id' => $hostprofile_id );
	    my $result = StorProc->update_obj( 'hosts', 'host_id', $properties{'host_id'}, \%values );
	    if ( $result =~ /^Error/ ) { push @errors, $result }

	    my @hosts = ( $properties{'host_id'} );
	    my $cnt = apply_host_profile( \%hp, @hosts );
	    unless (@errors) {
		$obj_view          = 'host_profile_saved_apply';
		$hidden{'host_id'} = $properties{'host_id'};
		$hidden{'name'}    = $name;
		$message           = "Changes to \"$name\" accepted; $cnt service" . ( $cnt == 1 ? '' : 's' ) . " applied.";
	    }
	}
	elsif ( $obj_view eq 'service_profiles' ) {
	    my @service_profiles  = $query->$multi_param('profiles_service');
	    my $services          = $query->param('apply_services');
	    my @profiles          = ();
	    my %retained_services = ();

	    my %where = ( 'host_id' => $properties{'host_id'} );
	    my @h_spids = StorProc->fetch_list_where( 'serviceprofile_host', 'serviceprofile_id', \%where );
	    my %h_spids = ();
	    @h_spids{@h_spids} = (1) x @h_spids;

	    if ($services eq 'replace') {
		$services = 'modify';

		my $host_profile_id     = $properties{'hostprofile_id'};
		my %profile_service_ids = ();
		my %w = ( 'hostprofile_id' => $host_profile_id );
		my @hp_spids = StorProc->fetch_list_where( 'profile_host_profile_service', 'serviceprofile_id', \%w );
		foreach my $hp_spid (@hp_spids) {
		    my %w = ( 'serviceprofile_id' => $hp_spid );
		    my @snids = StorProc->fetch_list_where( 'serviceprofile', 'servicename_id', \%w );
		    @profile_service_ids{@snids} = (1) x @snids;
		}
		my %hp_spids = ();
		@hp_spids{@hp_spids} = (1) x @hp_spids;
		foreach my $h_spid (@h_spids) {
		    if ( not $hp_spids{$h_spid} ) {
			my %w = ( 'serviceprofile_id' => $h_spid, 'host_id' => $properties{'host_id'} );
			my $result = StorProc->delete_one_where( 'serviceprofile_host', \%w );
			if ( $result =~ /^Error/ ) { push @errors, $result }
			delete $h_spids{$h_spid};
		    }
		}
		my %where = ( 'host_id' => $properties{'host_id'} );
		my @snids = StorProc->fetch_list_where( 'services', 'servicename_id', \%where );
		foreach my $snid (@snids) {
		    $retained_services{$snid} = 1 if $profile_service_ids{$snid};
		}
	    }

	    foreach my $spname (@service_profiles) {
		my %sp = StorProc->fetch_one( 'profiles_service', 'name', $spname );
		push @profiles, $sp{'serviceprofile_id'};
		if ( not $h_spids{ $sp{'serviceprofile_id'} } ) {
		    my @vals = ( $sp{'serviceprofile_id'}, $properties{'host_id'} );
		    my $result = StorProc->insert_obj( 'serviceprofile_host', \@vals );
		    if ( $result =~ /^Error/ ) { push @errors, $result }
		}
	    }

	    my @hosts = ( $properties{'host_id'} );
	    my ( $cnt, $err ) = StorProc->service_profile_apply( \@profiles, $services, \@hosts, \%retained_services );
	    if ($err) { push( @errors, @{$err} ) }
	    unless (@errors) {
		$obj_view          = 'service_profiles_saved_apply';
		$hidden{'host_id'} = $properties{'host_id'};
		$hidden{'name'}    = $name;
		$message           = "Changes to \"$name\" accepted; $cnt service" . ( $cnt == 1 ? '' : 's' ) . " applied.";
	    }
	}
	else {
	    my $host_id           = $query->param('host_id');
	    my $hostprofile_id    = $query->param('hostprofile_id');
	    my $serviceprofile_id = $query->param('serviceprofile_id');
	    my %sp                = StorProc->fetch_one( 'profiles_service', 'serviceprofile_id', $serviceprofile_id );
	    my %w                 = ( 'hostprofile_id' => $hostprofile_id );
	    my @externals         = StorProc->fetch_list_where( 'external_host_profile', 'external_id', \%w );
	    my $result            = StorProc->delete_all( 'external_host', 'host_id', $host_id );
	    if ( $result =~ /^Error/ ) { push @errors, $result }

	    # Is this a dead branch of the code?  I cannot seem to find how to navigate here in the UI.

	    foreach my $ext (@externals) {
		my %e = StorProc->fetch_one( 'externals', 'external_id', $ext );
		my @vals = ( $ext, $host_id, $e{'display'}, $DEFINED_REF );
		$result = StorProc->insert_obj( 'external_host', \@vals );
		if ( $result =~ /^Error/ ) { push @errors, $result }
	    }
	    %w = ( 'serviceprofile_id' => $serviceprofile_id );
	    my @services = StorProc->fetch_list_where( 'serviceprofile', 'servicename_id', \%w );
	    $result = StorProc->delete_all( 'services', 'host_id', $host_id );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	    foreach my $sid (@services) {
		my %sn = StorProc->fetch_one( 'service_names', 'servicename_id', $sid );
		%w = ( 'servicename_id' => $sid );
		@externals = StorProc->fetch_list_where( 'external_service_names', 'external_id', \%w );
		my @vals = (
		    \undef, $host_id, $sid, $sn{'template'}, $sn{'extinfo'}, $sn{'escalation'}, '1', $sn{'check_comand'}, $sn{'command_line'},
		    '', '', undef, '1'
		);
		my $service_id = StorProc->insert_obj_id( 'services', \@vals, 'service_id' );
		if ( $service_id =~ /^Error/ ) { push @errors, $service_id }
		if ( $sn{'dependency'} ) {
		    @vals = ( \undef, $service_id, $host_id, $host_id, $sn{'template'}, '' );
		    $result = StorProc->insert_obj( 'service_dependency', \@vals );
		    if ( $result =~ /^Error/ ) { push @errors, $result }
		}
		foreach my $ext (@externals) {
		    my %e = StorProc->fetch_one( 'externals', 'external_id', $ext );
		    @vals = ( $ext, $host_id, $service_id, $e{'display'}, $DEFINED_REF );
		    $result = StorProc->insert_obj( 'external_service', \@vals );
		    if ( $result =~ /^Error/ ) { push @errors, $result }
		}
	    }
	}
    }
    elsif ( $query->param('test_command') ) {
	my $arg_string   = $query->param('command_line');
	my $command      = $query->param('command');
	my $service_name = $query->param('service_name');
	my %cmd          = StorProc->fetch_one( 'commands', 'name', $command );
	$test_results .= StorProc->test_command( $command, $cmd{'command_line'}, $host, $arg_string, $monarch_home, $service_name, $nagios_ver );
    }
    elsif ( $query->param('add_instance') ) {
	my $check_command = $query->param('command');
	my $args          = $query->param('command_line');
	$args =~ s/^$check_command//;

	my $ext_args     = undef;
	my $inh_ext_args = 1;
	$ext_args = $query->param('externals_arguments') if $enable_externals;

	my $service_id = $query->param('service_id');
	my $inst       = $query->param('inst');
	my $range_from = $query->param('range_from');
	my $range_to   = $query->param('range_to');
	my %instances  = StorProc->get_service_instances($service_id);

	$range_from =~ s/^\s+|\s+$//g;
	$range_to   =~ s/^\s+|\s+$//g;

	if (   $range_to   =~ /^\d+$/
	    && $range_from =~ /^\d+$/
	    && $range_from <= $range_to )
	{
	    for ( my $i = $range_from ; $i <= $range_to ; $i++ ) {
		unless ( $instances{"_$i"} ) {
		    my $inst   = "_$i";
		    my @vals   = ( \undef, $service_id, $inst, '1', $args, $ext_args, $inh_ext_args );
		    my $result = StorProc->insert_obj( 'service_instance', \@vals );
		    if ( $result =~ /^Error/ ) { push @errors, $result }
		}
	    }
	}
	elsif ($inst) {
	    $inst =~ s/^\s+|\s+$//g;
	    if ( $instances{$inst} ) {
		@errors = ("Instance \"$inst\" already exists. Instance names must be unique.");
	    }
	    else {
		my @vals = ( \undef, $service_id, $inst, '1', $args, $ext_args, $inh_ext_args );
		my $result = StorProc->insert_obj( 'service_instance', \@vals );
		if ( $result =~ /^Error/ ) { push @errors, $result }
	    }
	}
	elsif ($range_to) {
	    @errors = ('Check values. The range of values must be numeric, and the last value cannot be less than the first.');
	}
    }
    elsif ( $query->param('remove_instance') ) {
	my @rem_instances = $query->$multi_param('rem_inst');
	foreach my $inst (@rem_instances) {
	    my $result = StorProc->delete_all( 'service_instance', 'instance_id', $inst );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	    my $service_name = $query->param('service_name');
	    my $inst_name    = $query->param("instance_$inst");
	    my $service_inst = "$service_name$inst_name";
	    my %where        = ( 'host' => $name, 'service' => $service_inst );
	    $result = StorProc->delete_one_where( 'host_service', \%where );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	}
    }
    elsif ( $query->param('external_add') ) {
	my $external_name = $query->param('external');
	my $service_id    = $query->param('service_id');
	my $host_id       = $query->param('id');
	my $type          = $query->param('type');
	my %w             = ( 'name' => $external_name, 'type' => $type );
	my %e             = StorProc->fetch_one_where( 'externals', \%w );
	if ($e{'external_id'} ne '') {
	    if ( $type eq 'service' ) {
		my @vals = ( $e{'external_id'}, $host_id, $service_id, $e{'display'}, $DEFINED_REF );
		my $result = StorProc->insert_obj( 'external_service', \@vals );
		if ( $result =~ /^Error/ ) { push @errors, $result }
	    }
	    else {
		my @vals = ( $e{'external_id'}, $host_id, $e{'display'}, $DEFINED_REF );
		my $result = StorProc->insert_obj( 'external_host', \@vals );
		if ( $result =~ /^Error/ ) { push @errors, $result }
	    }
	}
    }
    elsif ( $query->param('save') || $query->param('mark') || $query->param('reset') ) {
	if ( $obj_view eq 'host_detail' ) {
	    my %data           = parse_query( 'host_templates', 'host_overrides' );
	    my $alias          = StorProc->sanitize_string( scalar $query->param('alias') );
	    my $address        = StorProc->sanitize_string( scalar $query->param('address') );
	    my $notes          = $query->param('notes');
	    my $host_template  = $query->param('template');
	    my $extinfo        = $query->param('extended_info');
	    my $checks_enabled = $query->param('checks_enabled');
	    my $coords2d       = StorProc->sanitize_string( scalar $query->param('coords2d') );
	    my $coords3d       = StorProc->sanitize_string( scalar $query->param('coords3d') );
	    if (defined $notes) {
		$notes = StorProc->sanitize_string_but_keep_newlines($notes);
		$notes =~ s/\n/<br>/g;
	    }
	    if ( $alias && $address && $host_template ) {
		my %values = ( 'alias' => $alias, 'address' => $address, 'notes' => $notes );
		my %t = StorProc->fetch_one( 'host_templates', 'name', $host_template );
		$values{'hosttemplate_id'} = $t{'hosttemplate_id'};
		my %e = StorProc->fetch_one( 'extended_host_info_templates', 'name', $extinfo );
		$values{'hostextinfo_id'} = $e{'hostextinfo_id'};
		my $result = StorProc->update_obj( 'hosts', 'host_id', $properties{'host_id'}, \%values );
		if ( $result =~ /^Error/ ) { push @errors, $result }
		my %w = ( 'host_id' => $properties{'host_id'} );
		$result = StorProc->delete_one_where( 'extended_info_coords', \%w );
		if ( $result =~ /^Error/ ) { push @errors, $result }
		my $data = '';
		if ( defined($coords2d) && $coords2d ne '' ) {
		    $coords2d =~ s{]]>}{]]]]><!\[CDATA\[>}g;
		    $data .= "\n  <prop name=\"2d_coords\"><![CDATA[$coords2d]]>\n  </prop>";
		}
		if ( defined($coords3d) && $coords3d ne '' ) {
		    $coords3d =~ s{]]>}{]]]]><!\[CDATA\[>}g;
		    $data .= "\n  <prop name=\"3d_coords\"><![CDATA[$coords3d]]>\n  </prop>";
		}
		if ($data) {
		    $data = "<?xml version=\"1.0\" encoding=\"iso-8859-1\" ?>\n<data>" . $data . "\n</data>";
		    my @vals = ( $properties{'host_id'}, $data );
		    $result = StorProc->insert_obj( 'extended_info_coords', \@vals );
		    if ( $result =~ /^Error/ ) { push @errors, $result }
		}
		my %where = ( 'host_id' => $properties{'host_id'} );
		$result = StorProc->delete_one_where( 'host_overrides', \%where );
		if ( $result =~ /^Error/ ) { push @errors, $result }
		if (   $data{'check_period'}
		    || $data{'notification_period'}
		    || $data{'check_command'}
		    || $data{'event_handler'}
		    || $data{'data'} )
		{
		    my @values = (
			$properties{'host_id'}, $data{'check_period'},  $data{'notification_period'},
			$data{'check_command'}, $data{'event_handler'}, $data{'data'}
		    );
		    my $result = StorProc->insert_obj( 'host_overrides', \@values );
		    if ( $result =~ /^Error/ ) { push @errors, $result }
		}
		if ( $query->param('contactgroup_override') ) {
		    my %where = ( 'host_id' => $properties{'host_id'} );
		    my $result = StorProc->delete_one_where( 'contactgroup_host', \%where );
		    if ( $result =~ /^Error/ ) { push @errors, $result }
		}
		else {
		    my %where = ( 'host_id' => $properties{'host_id'} );
		    my $result = StorProc->delete_one_where( 'contactgroup_host', \%where );
		    if ( $result =~ /^Error/ ) { push @errors, $result }
		    my @mems = $query->$multi_param('contactgroup');
		    foreach (@mems) {
			my %cg = StorProc->fetch_one( 'contactgroups', 'name', $_ );
			my @vals = ( $cg{'contactgroup_id'}, $properties{'host_id'} );
			$result = StorProc->insert_obj( 'contactgroup_host', \@vals );
			if ( $result =~ /^Error/ ) { push @errors, $result }
		    }
		}
		unless (@errors) {
		    $obj_view = 'saved';
		    $message  = "Changes to \"$name\" accepted.";
		}
	    }
	    else {
		push @errors, "Required: alias, address, and host template";
		$required = 1;
	    }
	}
	elsif ( $obj_view eq 'escalation_trees' ) {
	    my $host_escalation    = $query->param('host_escalation');
	    my $service_escalation = $query->param('service_escalation');
	    my %w                  = ( 'name' => $host_escalation, 'type' => 'host' );
	    my %he                 = StorProc->fetch_one_where( 'escalation_trees', \%w );
	    %w = ( 'name' => $service_escalation, 'type' => 'service' );
	    my %se = StorProc->fetch_one_where( 'escalation_trees', \%w );
	    my %values = (
		'host_escalation_id'    => $he{'tree_id'},
		'service_escalation_id' => $se{'tree_id'}
	    );
	    my $result = StorProc->update_obj( 'hosts', 'host_id', $properties{'host_id'}, \%values );
	    if ( $result =~ /^Error/ ) { push @errors, $result }

	    unless (@errors) {
		$obj_view = 'saved';
		$message  = "Changes to \"$name\" accepted.";
	    }
	}
	elsif ( $obj_view eq 'parents' ) {
	    my @parents = $query->$multi_param('members');
	    foreach my $parent (@parents) {
		if ( $parent eq $name ) {
		    push @errors, "A host cannot be its own parent.";
		    last;
		}
	    }
	    unless (@errors) {
		my %w = ( 'host_id' => $properties{'host_id'} );
		my $result = StorProc->delete_one_where( 'host_parent', \%w );
		if ( $result =~ /^Error/ ) { push @errors, $result }
		foreach my $parent (@parents) {
		    if ( !$parent ) { next }
		    my %h = StorProc->fetch_one( 'hosts', 'name', $parent );
		    my @vals = ( $properties{'host_id'}, $h{'host_id'} );
		    my $result = StorProc->insert_obj( 'host_parent', \@vals );
		    if ( $result =~ /^Error/ ) { push @errors, $result }
		}
	    }
	    unless (@errors) {
		$obj_view = 'saved';
		$message  = 'Changes to parentage accepted.';
	    }
	}
	elsif ( $obj_view eq 'hostgroups' ) {
	    my %w = ( 'host_id' => $properties{'host_id'} );
	    my $result = StorProc->delete_one_where( 'hostgroup_host', \%w );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	    my @hostgroups = $query->$multi_param('members');
	    foreach my $hg (@hostgroups) {
		if ( !$hg ) { next }
		my %h = StorProc->fetch_one( 'hostgroups', 'name', $hg );
		my @vals = ( $h{'hostgroup_id'}, $properties{'host_id'} );
		my $result = StorProc->insert_obj( 'hostgroup_host', \@vals );
		if ( $result =~ /^Error/ ) { push @errors, $result }
	    }
	    unless (@errors) {
		$obj_view = 'saved';
		$message  = "Changes to \"$name\" hostgroups accepted.";
	    }
	}
	elsif ( $obj_view eq 'host_external_detail' ) {
	    my $data          = $query->param('detail');
	    my $external_id   = $query->param('external_id');
	    my $host_external = $query->param('host_external');
	    my %values = ();
	    if ( $query->param('save') ) {
		$values{'data'} = $data;
		$values{'modified'} = 1;
	    }
	    elsif ( $query->param('mark') ) {
		$values{'modified'} = 1;
	    }
	    elsif ( $query->param('reset') ) {
		# In a reset operation, we update the data field with generic content from the
		# unanchored host external, instead of using data from the user's screen.
		my %external = StorProc->fetch_one( 'externals', 'external_id', $external_id );
		$values{'data'} = $external{'display'};
		$values{'modified'} = $DEFINED_REF;
	    }
	    my %where         = (
		'external_id' => $external_id,
		'host_id'     => $properties{'host_id'}
	    );
	    my $result = StorProc->update_obj_where( 'external_host', \%values, \%where );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	    unless (@errors) {
		$obj_view = 'saved';
		$message  = "Changes to \"$host_external\" external accepted.";
	    }
	}
	elsif ( $obj_view eq 'service_external_detail' ) {
	    my $data             = $query->param('detail');
	    my $external_id      = $query->param('external_id');
	    my $service_name     = $query->param('service_name');
	    my $service_id       = $query->param('service_id');
	    my $service_external = $query->param('service_external');
	    $hidden{'service_name'} = $service_name;
	    $hidden{'service_id'}   = $service_id;
	    my %values = ();
	    if ( $query->param('save') ) {
		$values{'data'} = $data;
		$values{'modified'} = 1;
	    }
	    elsif ( $query->param('mark') ) {
		$values{'modified'} = 1;
	    }
	    elsif ( $query->param('reset') ) {
		# In a reset operation, we update the data field with generic content from the
		# unanchored service external, instead of using data from the user's screen.
		my %external = StorProc->fetch_one( 'externals', 'external_id', $external_id );
		$values{'data'} = $external{'display'};
		$values{'modified'} = $DEFINED_REF;
	    }
	    my %where = (
		'external_id' => $external_id,
		'host_id'     => $properties{'host_id'},
		'service_id'  => $service_id
	    );
	    my $result = StorProc->update_obj_where( 'external_service', \%values, \%where );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	    unless (@errors) {
		$obj_view = 'saved';
		$message  = "Changes to \"$service_external\" external accepted.";
	    }
	}
	elsif ( $obj_view eq 'service_detail' ) {
	    my %values       = ();
	    my $service_name = $query->param('service_name');
	    my $service_id   = $query->param('service_id');
	    my $notes        = $query->param('notes');
	    if (defined $notes) {
		$notes = StorProc->sanitize_string_but_keep_newlines($notes);
		$notes =~ s/\n/<br>/g;
	    }
	    $hidden{'service_name'} = $service_name;
	    $hidden{'service_id'}   = $service_id;
	    my %s          = StorProc->fetch_one( 'service_names', 'name', $service_name );
	    my $ext_info   = $query->param('ext_info');
	    my %x          = StorProc->fetch_one( 'extended_service_info_templates', 'name', $ext_info );
	    my $escalation = $query->param('escalation');
	    my %e          = StorProc->fetch_one( 'escalation_trees', 'name', $escalation );
	    my $template   = $query->param('template');
	    my %t          = StorProc->fetch_one( 'service_templates', 'name', $template );
	    my %data       = parse_query( 'service_overrides', 'service_overrides' );
	    my %vals       = (
		'notes'              => $notes,
		'serviceextinfo_id'  => $x{'serviceextinfo_id'},
		'escalation_id'      => $e{'tree_id'},
		'servicetemplate_id' => $t{'servicetemplate_id'}
	    );
	    my $result = StorProc->update_obj( 'services', 'service_id', $service_id, \%vals );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	    my %where = ( 'service_id' => $properties{'service_id'} );
	    $result = StorProc->delete_one_where( 'service_overrides', \%where );
	    if ( $result =~ /^Error/ ) { push @errors, $result }

	    if (   $data{'check_period'}
		|| $data{'notification_period'}
		|| $data{'event_handler'}
		|| $data{'data'} )
	    {
		my @values = ( $service_id, $data{'check_period'}, $data{'notification_period'}, $data{'event_handler'}, $data{'data'} );
		my $result = StorProc->insert_obj( 'service_overrides', \@values );
		if ( $result =~ /^Error/ ) { push @errors, $result }
	    }

	    %where = ( 'service_id' => $service_id );
	    $result = StorProc->delete_one_where( 'contactgroup_service', \%where );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	    unless ( $query->param('contactgroup_override') ) {
		my @mems = $query->$multi_param('contactgroup');
		foreach (@mems) {
		    my %cg = StorProc->fetch_one( 'contactgroups', 'name', $_ );
		    my @vals = ( $cg{'contactgroup_id'}, $service_id );
		    $result = StorProc->insert_obj( 'contactgroup_service', \@vals );
		    if ( $result =~ /^Error/ ) { push @errors, $result }
		}
	    }
	    unless (@errors) {
		$obj_view = 'saved';
		$message  = "Changes to \"$service_name\" accepted.";
	    }
	}
	elsif ( $obj_view eq 'service_check' ) {
	    my $service_name = $query->param('service_name');
	    my $service_id   = $query->param('service_id');
	    $hidden{'service_name'} = $service_name;
	    $hidden{'service_id'}   = $service_id;
	    my $check_command       = $query->param('command');
	    my $command_line        = $query->param('command_line');
	    my $externals_arguments = undef;
	    my $inherit_ext_args    = undef;
	    my %instances_org       = StorProc->get_service_instances_names( $hidden{'service_id'} );
	    my %instances           = ();

	    if ($enable_externals) {
		$externals_arguments = $query->param('externals_arguments');
		$externals_arguments = undef if defined($externals_arguments) && $externals_arguments eq '';
		$inherit_ext_args    = $query->param('inherit_ext_args');
	    }

	    # We sort instance_ first so the instance name is guaranteed to be available in validation error messages.
	    # After that, we use the incoming field order, which is likely though not guaranteed to match the on-screen order.
	    my $index = 0;
	    foreach my $qname ( map { $_->[0] } sort { $b->[2] <=> $a->[2] || $a->[1] <=> $b->[1] } map { [ $_, $index++, /^instance_/ ] } $query->param ) {
		if ( $qname =~ /^args_(\d+)/ ) {
		    ## GWMON-10037:  strip line breaks
		    $instances{$1}{'args'} = $query->param($qname);
		    $instances{$1}{'args'} =~ s/[\n\r]+//g if defined $instances{$1}{'args'};
		}
		elsif ( $qname =~ /^ext_args_(\d+)/ && $enable_externals ) {
		    ## GWMON-10037:  strip line breaks
		    $instances{$1}{'ext_args'} = $query->param($qname);
		    if ( defined $instances{$1}{'ext_args'} ) {
			$instances{$1}{'ext_args'} =~ s/[\n\r]+//g;
			$instances{$1}{'ext_args'} = undef if $instances{$1}{'ext_args'} eq '';
		    }
		}
		elsif ( $qname =~ /inh_ext_args_(\d+)/ && $enable_externals ) {
		    $instances{$1}{'inh_ext_args'} = 1;
		}
		elsif ( $qname =~ /status_(\d+)/ ) {
		    $instances{$1}{'status'} = 1;
		}
		elsif ( $qname =~ /instance_(\d+)/ ) {
		    $instances{$1}{'instance'} = $query->param($qname);
		}
	    }
	    my %duplicates = ();
	    foreach my $inst ( keys %instances ) {
		if ( $duplicates{ $instances{$inst}{'instance'} } ) {
		    push @errors, "Instance \"$duplicates{$instances{$inst}{'instance'}}\" already exists. Instance names must be unique.";
		}
		else {
		    $duplicates{ $instances{$inst}{'instance'} } = $instances{$inst}{'instance'};
		}
	    }
	    unless (@errors) {
		foreach my $inst ( keys %instances ) {
		    if ( $instances{$inst}{'instance'} ) {
			my %vals = (
			    'name'                => $instances{$inst}{'instance'},
			    'status'              => $instances{$inst}{'status'},
			    'arguments'           => $instances{$inst}{'args'}
			);
			if ($enable_externals) {
			    $vals{'externals_arguments'} = $instances{$inst}{'ext_args'};
			    $vals{'inherit_ext_args'}    = $instances{$inst}{'inh_ext_args'} || '00';
			}
			my $result = StorProc->update_obj( 'service_instance', 'instance_id', $inst, \%vals );
			if ( $result =~ /^Error/ ) { push @errors, $result }
			unless ( $instances_org{$inst}{'name'} eq $instances{$inst}{'instance'} ) {
			    my $service_name = $query->param('service_name');
			    my $inst_name    = $query->param("instance_$inst");
			    my $service_inst = "$service_name$instances_org{$inst}{'name'}";
			    my %where        = ( 'host' => $name, 'service' => $service_inst );
			    $result = StorProc->delete_one_where( 'host_service', \%where );
			    if ( $result =~ /^Error/ ) { push @errors, $result }
			}
		    }
		}
	    }
	    unless (@errors) {
		my %vals = ();
		if ($enable_externals) {
		    $vals{'externals_arguments'} = $externals_arguments;
		    $vals{'inherit_ext_args'} = $inherit_ext_args || '00';
		}
		if ( $query->param('inherit') ) {
		    my $required = $query->param('required');
		    unless ($required) {
			$vals{'check_command'} = '';
			$vals{'command_line'}  = '';
			my $result = StorProc->update_obj( 'services', 'service_id', $service_id, \%vals );
			if ( $result =~ /^Error/ ) { push @errors, $result }
		    }
		    else {
			push @errors, "The service check is not defined on a template so it must be defined here.";
		    }
		}
		else {
		    my %check = StorProc->fetch_one( 'commands', 'name', $check_command );
		    $vals{'check_command'} = $check{'command_id'};
		    $vals{'command_line'}  = $command_line;
		    my $result = StorProc->update_obj( 'services', 'service_id', $service_id, \%vals );
		    if ( $result =~ /^Error/ ) { push @errors, $result }
		}
	    }
	    unless (@errors) {
		$obj_view = 'saved';
		$message  = "Changes to \"$service_name\" accepted.";
	    }
	}
    }
    elsif ( $query->param('add_dependency') ) {
	my $dep_template = $query->param('dep_template');
	my $service_name = $query->param('service_name');
	my $service_id   = $query->param('service_id');
	$hidden{'service_name'} = $service_name;
	$hidden{'service_id'}   = $service_id;
	my $parent = $query->param('depend_on_host');
	my %p      = StorProc->fetch_one( 'hosts', 'name', $parent );
	my %d      = StorProc->fetch_one( 'service_dependency_templates', 'name', $dep_template );
	my %w      = (
	    'service_id'        => $service_id,
	    'host_id'           => $properties{'host_id'},
	    'depend_on_host_id' => $p{'host_id'},
	    'template'          => $d{'id'}
	);
	my %check_dep = StorProc->fetch_one_where( 'service_dependency', \%w );

	if ( $dep_template && $service_id && $parent ) {
	    unless ( $check_dep{'id'} ) {
		my @values = ( \undef, $service_id, $properties{'host_id'}, $p{'host_id'}, $d{'id'}, '' );
		my $result = StorProc->insert_obj( 'service_dependency', \@values );
		if ( $result =~ /^Error/ ) { push @errors, $result }
	    }
	    else {
		push @errors, "Already defined. Check existing dependencies.";
	    }
	}
    }
    elsif ( $obj_view eq 'confirm_delete_service' || ( defined($submit) && $submit eq 'remove_service' ) ) {
	if ( $query->param('cancel') ) {
	    $obj_view = 'services';
	}
	else {
	    my $remove_dependency = $query->param('remove_dependency');
	    if ($remove_dependency) {
		my $generic = $query->param('generic');
		my $dep_id = $query->param('dependency_id');
		$dep_id =~ s/\D//g;
		my $table  = $generic ? 'servicename_dependency' : 'service_dependency';
		my $result = StorProc->delete_all( $table, 'id', $dep_id );
		if ( $result =~ /^Error/ ) { push @errors, $result }
	    }
	    my $service_id = $query->param('service_id');
	    my %s          = StorProc->fetch_one( 'services', 'service_id', $service_id );
	    my %sn         = StorProc->fetch_one( 'service_names', 'servicename_id', $s{'servicename_id'} );
	    my %h          = StorProc->fetch_one( 'hosts', 'name', $name );

	    my %host_service_deps    = StorProc->get_dependent_host_services( $s{'servicename_id'}, $h{'host_id'} );
	    my %generic_service_deps = StorProc->get_dependent_services( $s{'servicename_id'}, $h{'host_id'} );
	    if (!$query->param('delete') && ($remove_dependency || %host_service_deps || %generic_service_deps) ) {
		$obj_view = 'confirm_delete_service';
		$hidden{'obj_view'}   = $obj_view;
		$hidden{'service_id'} = $service_id;
		$form .= Forms->form_top( 'Confirm Host Service Delete', '' );
		$form .= Forms->display_hidden( 'Host name:', 'name', $name );
		$form .= Forms->display_hidden( 'Service name:', 'service_name', $sn{'name'} );
		if (%host_service_deps) {
		    my $message = "The following host services depend on this host service:";
		    $form .= Forms->wizard_doc( 'Dependent Host Services', $message, undef, 1 );
		    $form .= Forms->dependency_list( $name, 'hosts', $service_id, $session_id, \%host_service_deps, 'dependent' );
		}
		if (%generic_service_deps) {
		    my $message = "The following services depend on this host service:";
		    $form .= Forms->wizard_doc( 'Dependent Services', $message, undef, 1 );
		    $form .= Forms->dependency_list( $name, 'hosts', $service_id, $session_id, \%generic_service_deps,
			'dependent', 'generic' );
		}
		my $message = '<p class=initial>';
		if (%host_service_deps || %generic_service_deps) {
		    $message .= qq(Deleting this host service will remove all the dependencies listed above, all at once.</p><p class=append>);
		}
		$message .= qq(Are you sure you want to remove service \"$sn{'name'}\" from host \"$name\"?</p>);
		$form .= Forms->wizard_doc( 'Confirm Delete', $message, undef, 1 );
		$form .= Forms->hidden( \%hidden );
		$form .= Forms->form_bottom_buttons( \%delete, \%cancel, $tab++ );
	    }
	    else {
		foreach my $id (keys %host_service_deps) {
		    my $result = StorProc->delete_all( 'service_dependency', 'id', $id );
		    if ( $result =~ /^Error/ ) { push @errors, $result }
		}
		foreach my $id (keys %generic_service_deps) {
		    my $result = StorProc->delete_all( 'servicename_dependency', 'id', $id );
		    if ( $result =~ /^Error/ ) { push @errors, $result }
		}
		my $result = StorProc->delete_all( 'services', 'service_id', $service_id );
		if ( $result =~ /^Error/ ) { push @errors, $result }
		## FIX LATER:  deleting from host_service should probably be delayed until Commit time
		my %where = ( 'service' => $sn{'name'}, 'host' => $name );
		$result = StorProc->delete_one_where( 'host_service', \%where );
		if ( $result =~ /^Error/ ) { push @errors, $result }
		$obj_view     = 'services';
		$refresh_left = 1;
	    }
	}
    }
    elsif ( $query->param('remove_dependency') ) {
	my $dep_id = $query->param('dependency_id');
	$dep_id =~ s/\D//g;
	my $result = StorProc->delete_all( 'service_dependency', 'id', $dep_id );
	if ( $result =~ /^Error/ ) { push @errors, $result }
    }
    elsif ( $query->param('rename') ) {
	my $new_name = StorProc->sanitize_string( scalar $query->param('new_name') );
	if ($new_name) {
	    my %n = StorProc->fetch_one( 'hosts', 'name', $new_name );
	    if ( $name =~ /^$new_name$/i ) { delete $n{'name'} }
	    if ( $n{'name'} ) {
		push @errors, "Cannot rename. Another host has name \"$new_name\".";
		$obj_view = 'rename';
	    }
	    elsif ( $new_name eq $name ) {
		push @errors, "You cannot rename a host to its own name, unless you change the lettercase.  Did you make a typing mistake?";
	    }
	    else {
		my %values = ( 'name' => $new_name );
		my $result = StorProc->update_obj( 'hosts', 'name', $name, \%values );
		if ( $result =~ /^Error/ ) {
		    push @errors, $result;
		    $obj_view = 'rename';
		}
		else {
		    $result = StorProc->delete_all( 'host_service', 'host', $name );
		    if ( $result =~ /^Error/ ) { push @errors, $result }
		    $name       = $new_name;
		    %properties = StorProc->fetch_host($name);
		    push @errors, @{ $properties{'errors'} } if defined $properties{'errors'};
		    $obj_view     = 'host_detail';
		    $refresh_left = 1;
		}
	    }
	}
	else {
	    $obj_view = 'rename';
	}
    }
    elsif ( defined($submit) && $submit eq 'Add Service(s)' ) {
	my @services          = $query->$multi_param('add_service');
	my %where             = ();
	my %service_names     = ();
	my %service_name_hash = StorProc->fetch_list_hash_array( 'service_names', \%where );
	foreach my $service_id ( keys %service_name_hash ) {
	    $service_names{ $service_name_hash{$service_id}[1] }{'id'}            = $service_id;
	    $service_names{ $service_name_hash{$service_id}[1] }{'template'}      = $service_name_hash{$service_id}[3];
	    $service_names{ $service_name_hash{$service_id}[1] }{'check_command'} = $service_name_hash{$service_id}[4];
	    $service_names{ $service_name_hash{$service_id}[1] }{'command_line'}  = $service_name_hash{$service_id}[5];
	    $service_names{ $service_name_hash{$service_id}[1] }{'escalation'}    = $service_name_hash{$service_id}[6];
	    $service_names{ $service_name_hash{$service_id}[1] }{'extinfo'}       = $service_name_hash{$service_id}[7];
	}
	my %service_name_overrides = ();
	my %service_name_override_hash = StorProc->fetch_list_hash_array( 'servicename_overrides', \%where );
	foreach my $service_id ( keys %service_name_hash ) {
	    $service_name_overrides{$service_id}{'check_period'}        = $service_name_override_hash{$service_id}[1];
	    $service_name_overrides{$service_id}{'notification_period'} = $service_name_override_hash{$service_id}[2];
	    $service_name_overrides{$service_id}{'event_handler'}       = $service_name_override_hash{$service_id}[3];
	    if ( $service_name_override_hash{$service_id}[4] ) {
		$service_name_overrides{$service_id}{'data'} = $service_name_override_hash{$service_id}[4];
	    }
	    else {
		$service_name_overrides{$service_id}{'data'} = qq(<?xml version="1.0" encoding="iso-8859-1" ?>
<data>
</data>);
	    }
	}
	my %service_name_dependency = ();
	my %service_name_dependency_hash = StorProc->fetch_list_hash_array( 'servicename_dependency', \%where );
	foreach my $id ( keys %service_name_dependency_hash ) {
	    $service_name_dependency{ $service_name_dependency_hash{$id}[1] }{$id}{'host'}     = $service_name_dependency_hash{$id}[2];
	    $service_name_dependency{ $service_name_dependency_hash{$id}[1] }{$id}{'template'} = $service_name_dependency_hash{$id}[3];
	}

	my %externals = ();
	my %externals_hash = StorProc->fetch_list_hash_array( 'externals', \%where );
	foreach my $id ( keys %externals_hash ) {
	    $externals{$id} = $externals_hash{$id}[4];
	}
	my %service_name_externals = ();
	my %service_name_externals_hash = StorProc->fetch_list_hash_array( 'external_service_names', \%where );
	foreach my $id ( keys %service_name_externals_hash ) {
	    $service_name_externals{ $service_name_externals_hash{$id}[1] }{$id} = $id;
	}
	foreach my $service_name (@services) {
	    if ($service_name) {
		my @values = (
		    \undef,                                        $properties{'host_id'},
		    $service_names{$service_name}{'id'},           $service_names{$service_name}{'template'},
		    $service_names{$service_name}{'extinfo'},      $service_names{$service_name}{'escalation'},
		    '1',                                           $service_names{$service_name}{'check_command'},
		    $service_names{$service_name}{'command_line'}, '',
		    '',                                            undef,
		    '1'
		);
		my $id = StorProc->insert_obj_id( 'services', \@values, 'service_id' );
		if ( $id =~ /^Error/ ) {
		    push @errors, $id;
		}
		else {
		    @values = (
			$id,
			$service_name_overrides{ $service_names{$service_name}{'id'} }{'check_period'},
			$service_name_overrides{ $service_names{$service_name}{'id'} }{'notification_period'},
			$service_name_overrides{ $service_names{$service_name}{'id'} }{'event_handler'},
			$service_name_overrides{ $service_names{$service_name}{'id'} }{'data'}
		    );
		    my $result = StorProc->insert_obj( 'service_overrides', \@values );
		    if ( $result =~ /^Error/ ) { push @errors, $result }

		    my $service_id     = $id;
		    my $servicename_id = $service_names{$service_name}{'id'};

		    %where = ( 'service_id' => $service_id );
		    $result = StorProc->delete_one_where( 'contactgroup_service', \%where );
		    if ( $result =~ /^Error/ ) { push @errors, $result }
		    %where = ( 'servicename_id' => $servicename_id );
		    my @cgids = StorProc->fetch_list_where( 'contactgroup_service_name', 'contactgroup_id', \%where );
		    foreach (@cgids) {
			my @vals = ( $_, $service_id );
			$result = StorProc->insert_obj( 'contactgroup_service', \@vals );
			if ( $result =~ /^Error/ ) { push @errors, $result }
		    }

		    foreach my $dependency_id ( keys %{ $service_name_dependency{ $service_names{$service_name}{'id'} } } ) {
			my $depend_on_host = $properties{'host_id'};
			if ( $service_name_dependency{ $service_names{$service_name}{'id'} }{$dependency_id}{'host'} ) {
			    $depend_on_host = $service_name_dependency{ $service_names{$service_name}{'id'} }{$dependency_id}{'host'};
			}
			@values = (
			    \undef, $id, $properties{'host_id'}, $depend_on_host,
			    $service_name_dependency{ $service_names{$service_name}{'id'} }{$dependency_id}{'template'}, ''
			);
			$result = StorProc->insert_obj( 'service_dependency', \@values );
			if ( $result =~ /^Error/ ) { push @errors, $result }
		    }
		    foreach my $external_id ( keys %{ $service_name_externals{ $service_names{$service_name}{'id'} } } ) {
			@values = ( $external_id, $properties{'host_id'}, $id, $externals{$external_id}, $DEFINED_REF );
			$result = StorProc->insert_obj( 'external_service', \@values );
			if ( $result =~ /^Error/ ) { push @errors, $result }
		    }
		}
	    }
	}
    }
    elsif ($query->param('delete')
	|| $query->param('confirm_delete_host')
	|| (defined( $query->param('task') ) && $query->param('task') eq 'No') )
    {
	if ( $query->param('confirm_delete_host') ) {
	    ## FIX MINOR:  Should the contactgroup_host deletion happen by an automatic cascade delete instead?
	    ## What about equivalent contactgroup_service deletions?
	    my %where = ( 'host_id' => $properties{'host_id'} );
	    my $result = StorProc->delete_one_where( 'contactgroup_host', \%where );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	    $result = StorProc->delete_all( 'hosts', 'name', $name );
	    if ( $result =~ /^Error/ ) {
		push @errors, $result;
		$obj_view = 'host_detail';
	    }
	    else {
		$result = StorProc->delete_all( 'host_service', 'host', $name );
		if ( $result =~ /^Error/ ) { push @errors, $result }
		$obj_view     = 'deleted';
		$refresh_left = 1;
	    }
	}
	elsif ( defined( $query->param('task') ) && $query->param('task') eq 'No' ) {
	    $obj_view = 'host_detail';
	}
	else {
	    $obj_view = 'delete_host';
	}
    }
    elsif ( $query->param('delete') || $query->param('confirm_delete_service') ) {
	# FIX MINOR:  this entire section may be inaccessible and obsolete
	my $service_name = $query->param('service_name');
	if ( $query->param('confirm_delete_service') ) {
	    my %where = ( 'name' => $service_name, 'host_name' => $name );
	    my %sid = StorProc->fetch_one_where( 'services', \%where );

	    # FIX LATER:  why is this commented out?  is it handled already by a cascade delete?
	    # %where = ('service_id' => $sid{'service_id'});
	    # my $result = StorProc->delete_one_where('contactgroup_service',\%where);
	    # if ($result =~ /^Error/) { push @errors, $result }

	    my $result = StorProc->delete_all( 'services', 'service_id', $sid{'service_id'} );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	    # FIX MAJOR:  also delete from the host_service table, as above?
	    $obj_view = 'Service List';
	}
	elsif ( $query->param('task') eq 'No' ) {
	    $obj_view = 'Service List';
	}
	else {
	    $hidden{'name'}         = $name;
	    $hidden{'obj_view'}     = $obj_view;
	    $hidden{'submit'}       = 'service_delete';
	    $hidden{'service_name'} = $service_name;
	    my $message = qq(Are you sure you want to remove service \"$service_name\" from host \"$name\"?);
	    $form .= Forms->are_you_sure( 'Confirm Delete', $message, 'confirm_delete_service', \%hidden );
	}
    }
    else {
	my $got_obj = 0;
	foreach my $param ( $query->param ) {
	    if ( $param =~ /remove_external_(\d+)/ ) {
		my $eid = $1;
		if ( $obj_view eq 'host_externals' ) {
		    my %where = (
			'host_id'     => $properties{'host_id'},
			'external_id' => $eid
		    );
		    my $result = StorProc->delete_one_where( 'external_host', \%where );
		    if ( $result =~ /^Error/ ) { push @errors, $result }
		}
		else {
		    my $service_id = $query->param('service_id');
		    my %where      = ( 'service_id' => $service_id, 'external_id' => $eid );
		    my $result     = StorProc->delete_one_where( 'external_service', \%where );
		    if ( $result =~ /^Error/ ) { push @errors, $result }
		}
	    }
	    elsif ( $param eq 'select_external' ) {
		if ( $obj_view eq 'host_externals' ) {
		    $properties{'external'} = $query->param('select_external');
		    my %e = StorProc->fetch_one( 'externals', 'name', $properties{'external'} );
		    $properties{'external_id'} = $e{'external_id'};
		    $obj_view                  = 'host_external_detail';
		    $got_obj                   = 1;
		}
		else {
		    $properties{'external'} = $query->param('select_external');
		    my %e = StorProc->fetch_one( 'externals', 'name', $properties{'external'} );
		    $properties{'external_id'} = $e{'external_id'};
		    $obj_view                  = 'service_external_detail';
		    $got_obj                   = 1;
		}
	    }
	}
    }
    delete $hidden{'task'};
    delete $hidden{'obj_view'};
    %save = ( 'name' => 'save', 'value' => 'Save' );
    unless ($obj_view) { $obj_view = 'host_detail' }
    $hidden{'obj_view'} = $obj_view;
    $form .= Forms->header( $page_title, $session_id, $top_menu, '', $refresh_left );
    if ( $obj_view eq 'host_detail' ) {
	my %docs = Doc->manage_hosts_vitals();
	$form .=
	  Forms->host_top( $properties{'name'}, $session_id, $obj_view, $auth_add{'externals'}, $hidden{'selected'}, $hidden{'form_service'} );
	if (@errors) { $form .= Forms->form_errors( \@errors ) }
	$form .= Forms->text_box( 'Alias:', 'alias', $properties{'alias'}, $textsize{'alias'}, $required, $docs{'alias'}, '', $tab++ );
	$form .=
	  Forms->text_box( 'Address:', 'address', $properties{'address'}, $textsize{'address'}, $required, $docs{'address'}, '', $tab++ );
	my $notes = $properties{'notes'};
	$notes =~ s/<br>/\n/ig if defined $notes;
	my $lines = (( () = split( /\n/, (defined($notes) ? $notes : ''), 20 ) ) || 1) + 1;
	$form .= Forms->text_area( 'Notes:', 'notes', $notes, $lines, '74%', '', $docs{'notes'}, '', $tab++ );
	$form .= build_host_template($name);
	$form .= Forms->wizard_doc( 'Additional Per-Host Options', undef, undef, 1 );
	my @members = StorProc->fetch_list( 'extended_host_info_templates', 'name' );
	push @members, 'remove_extended_info';
	$form .= Forms->list_box( 'Extended host info template:',
	    'extended_info', \@members, $properties{'ext_info'}, '', $docs{'extinfo'}, '', $tab++ );
	$form .= Forms->text_box( '2d status coords:', 'coords2d', $properties{'coords2d'}, '10', '', $docs{'coords2d'}, '', $tab++ );
	$form .= Forms->text_box( '3d status coords:', 'coords3d', $properties{'coords3d'}, '15', '', $docs{'coords3d'}, '', $tab++ );
	$hidden{'name'} = $name;
	$form .= Forms->hidden( \%hidden );

	if ( $auth_delete{$obj} ) {
	    $form .= Forms->form_bottom_buttons( \%save, \%delete, \%rename, $tab++ );
	}
	else {
	    $form .= Forms->form_bottom_buttons( \%save, \%rename, $tab++ );
	}
    }
    elsif ( $obj_view eq 'host_profile' ) {
	my %docs         = Doc->manage_hosts_host_profile();
	my @service_ids  = ();
	my $host_profile = $query->param('profile_host');
	$form .=
	  Forms->host_top( $properties{'name'}, $session_id, $obj_view, $auth_add{'externals'}, $hidden{'selected'}, $hidden{'form_service'} );
	if (@errors) { $form .= Forms->form_errors( \@errors ) }
	$form .= Forms->wizard_doc( 'Host profile', $docs{'how_to'}, undef, 1 );

	my $host_profile_id = undef;
	my %profile = ();
	if ($host_profile) {
	    %profile = StorProc->fetch_one( 'profiles_host', 'name', $host_profile );
	    $host_profile_id = $profile{'hostprofile_id'};
	}
	else {
	    %profile = StorProc->fetch_one( 'profiles_host', 'hostprofile_id', $properties{'hostprofile_id'} );
	    $host_profile_id = $properties{'hostprofile_id'};
	    $host_profile    = $profile{'name'};
	}
	unless ($host_profile) { $host_profile = '' }
	my @host_profiles = ('-- no host profile --');
	my @profiles = StorProc->fetch_list( 'profiles_host', 'name' );
	push( @host_profiles, @profiles );
	$form .= Forms->list_box_submit( 'Host profile:', 'profile_host', \@host_profiles, $host_profile, '', $docs{'host_profile'}, $tab++ );

	my %host_profile_service_profiles = ();
	my %w = ( 'hostprofile_id' => $host_profile_id );
	my @spids = StorProc->fetch_list_where( 'profile_host_profile_service', 'serviceprofile_id', \%w );
	foreach my $spid (@spids) {
	    my %sp = StorProc->fetch_one( 'profiles_service', 'serviceprofile_id', $spid );
	    $host_profile_service_profiles{ $sp{'name'} } = 1;
	}
	my @host_profile_service_profiles = sort keys %host_profile_service_profiles;
	$form .= Forms->form_message( 'Service profiles from this host profile:', \@host_profile_service_profiles, 'row1', undef, undef, '25%' );

	my @other_service_profiles = ();
	%w = ( 'host_id' => $properties{'host_id'} );
	@spids = StorProc->fetch_list_where( 'serviceprofile_host', 'serviceprofile_id', \%w );
	foreach my $spid (@spids) {
	    my %sp = StorProc->fetch_one( 'profiles_service', 'serviceprofile_id', $spid );
	    push @other_service_profiles, $sp{'name'} if not $host_profile_service_profiles{ $sp{'name'} };
	}
	@other_service_profiles = sort @other_service_profiles;
	$form .= Forms->form_message( 'Other existing service profiles assigned to this host:', \@other_service_profiles, 'row1', undef, undef, '25%' );

	if ( $host_profile && $host_profile ne '-- no host profile --' ) {
	    my %w = ( 'hostprofile_id' => $host_profile_id );
	    my @spids = StorProc->fetch_list_where( 'profile_host_profile_service', 'serviceprofile_id', \%w );
	    foreach my $spid (@spids) {
		my %w = ( 'serviceprofile_id' => $spid );
		my @sids = StorProc->fetch_list_where( 'serviceprofile', 'servicename_id', \%w );
		push( @service_ids, @sids );
	    }
	}

	my %services = ();
	my %where    = ( 'host_id' => $properties{'host_id'} );
	my @services = StorProc->fetch_list_where( 'services', 'service_id', \%where );
	foreach my $sid (@services) {
	    my $service_name = StorProc->get_service_name($sid);
	    $service_name =~ s/\s/+/g;
	    $services{$service_name} = $sid;
	}
	my @existing_services = sort keys %services;

	my @profile_services = ();
	my %seen             = ();
	foreach my $sid (@service_ids) {
	    unless ( $seen{$sid} ) {
		$seen{$sid} = 1;
		my %s = StorProc->fetch_one( 'service_names', 'servicename_id', $sid );
		if ( $s{'name'} ) { push @profile_services, $s{'name'} }
	    }
	}
	@profile_services = sort @profile_services;
	$form .= Forms->form_message( 'Existing services for this host:', \@existing_services, 'row1', undef, undef, '25%' );
	$form .= Forms->form_message( "Services from this host profile's service profiles:",
	  \@profile_services, 'row1', undef, undef, '25%' );

	$profile{'apply_services'} = 'merge';
	$form .= Forms->apply_select( $view, \%profile, $nagios_ver, $auth_modify{'externals'}, $tab++ );
	$hidden{'name'} = $name;
	$form .= Forms->hidden( \%hidden );
	my %apply = ( 'name' => 'apply', 'value' => 'Assign and Apply' );
	$form .= Forms->form_bottom_buttons( \%apply, $tab++ );
    }
    elsif ( $obj_view eq 'service_profiles' ) {
	my %docs             = Doc->manage_hosts_service_profiles();
	my @service_ids      = ();
	my @service_profiles = $query->$multi_param('profiles_service');
	my $profiles_updated = $query->param('profiles_updated');
	$form .= Forms->host_top( $properties{'name'}, $session_id, $obj_view, $auth_add{'externals'},
	  $hidden{'selected'}, $hidden{'form_service'} );
	if (@errors) { $form .= Forms->form_errors( \@errors ) }
	$form .= Forms->wizard_doc( 'Service profiles', $docs{'how_to'}, undef, 1 );
	my %h = StorProc->fetch_one( 'profiles_host', 'hostprofile_id', $properties{'hostprofile_id'} );
	my $host_profile_id = $properties{'hostprofile_id'};
	my $host_profile    = $h{'name'};
	unless ($host_profile) { $host_profile = '' }
	$form .= Forms->display_hidden( 'Host profile:', '', $host_profile, $docs{'host_profile'} );

	my %existing_service_profiles = ();
	my %where = ( 'host_id' => $properties{'host_id'} );
	my @spids = StorProc->fetch_list_where( 'serviceprofile_host', 'serviceprofile_id', \%where );
	foreach my $spid (@spids) {
	    my %sp = StorProc->fetch_one( 'profiles_service', 'serviceprofile_id', $spid );
	    $existing_service_profiles{ $sp{'name'} } = 1;
	}
	my @profile_service_ids = ();
	my %host_profile_service_profiles = ();
	my %w = ( 'hostprofile_id' => $host_profile_id );
	@spids = StorProc->fetch_list_where( 'profile_host_profile_service', 'serviceprofile_id', \%w );
	foreach my $spid (@spids) {
	    my %sp = StorProc->fetch_one( 'profiles_service', 'serviceprofile_id', $spid );
	    $host_profile_service_profiles{ $sp{'name'} } = 1 if $existing_service_profiles{ $sp{'name'} };
	    my %w = ( 'serviceprofile_id' => $spid );
	    my @sids = StorProc->fetch_list_where( 'serviceprofile', 'servicename_id', \%w );
	    push( @profile_service_ids, @sids );
	}
	my @host_profile_service_profiles = sort keys %host_profile_service_profiles;
	$form .= Forms->form_message( 'Existing service profiles from this host profile:',
	  \@host_profile_service_profiles, 'row1', undef, undef, '25%' );

	if ($profiles_updated) {
	    foreach my $spname (@service_profiles) {
		my %sp = StorProc->fetch_one( 'profiles_service', 'name', $spname );
		my %w  = ( 'serviceprofile_id' => $sp{'serviceprofile_id'} );
		my @sids = StorProc->fetch_list_where( 'serviceprofile', 'servicename_id', \%w );
		push( @service_ids, @sids );
	    }
	}
	else {
	    my %w = ( 'host_id' => $properties{'host_id'} );
	    my @spids = StorProc->fetch_list_where( 'serviceprofile_host', 'serviceprofile_id', \%w );
	    foreach my $spid (@spids) {
		my %sp = StorProc->fetch_one( 'profiles_service', 'serviceprofile_id', $spid );
		if ( not $host_profile_service_profiles{ $sp{'name'} } ) {
		    push @service_profiles, $sp{'name'};
		    my %w = ( 'serviceprofile_id' => $spid );
		    my @sids = StorProc->fetch_list_where( 'serviceprofile', 'servicename_id', \%w );
		    push( @service_ids, @sids );
		}
	    }
	}
	my @nonmembers = StorProc->fetch_list( 'profiles_service', 'name' );
	$form .= Forms->members_submit( 'Service profiles to be directly assigned and applied to this host:',
	  'profiles_service', \@service_profiles, \@nonmembers, '', '5', 1, $docs{'service_profile'}, '', $tab++ );

	my %services = ();
	%where = ( 'host_id' => $properties{'host_id'} );
	my @services = StorProc->fetch_list_where( 'services', 'service_id', \%where );
	foreach my $sid (@services) {
	    my $service_name = StorProc->get_service_name($sid);
	    $service_name =~ s/\s/+/g;  # why?
	    $services{$service_name} = $sid;
	}
	my @existing_services = sort keys %services;

	my @host_profile_services = ();
	my %seen                  = ();
	foreach my $sid (@profile_service_ids) {
	    unless ( $seen{$sid} ) {
		$seen{$sid} = 1;
		my %s = StorProc->fetch_one( 'service_names', 'servicename_id', $sid );
		if ( $s{'name'} && $services{ $s{'name'} } ) { push @host_profile_services, $s{'name'} }
	    }
	}
	@host_profile_services = sort @host_profile_services;

	my @profile_services = ();
	%seen = ();
	foreach my $sid (@service_ids) {
	    unless ( $seen{$sid} ) {
		$seen{$sid} = 1;
		my %s = StorProc->fetch_one( 'service_names', 'servicename_id', $sid );
		if ( $s{'name'} ) { push @profile_services, $s{'name'} }
	    }
	}
	@profile_services = sort @profile_services;
	$form .= Forms->form_message( "Existing services from this host profile's service profiles:",
	  \@host_profile_services, 'row1', undef, undef, '25%' );
	$form .= Forms->form_message( 'Existing services for this host:', \@existing_services, 'row1', undef, undef, '25%' );
	$form .= Forms->form_message( 'Services from the chosen service profiles:', \@profile_services, 'row1', undef, undef, '25%' );
	my %selected = ();
	$selected{'apply_services'} = 'merge';
	$form .= Forms->apply_select( 'direct_profiles', \%selected, $nagios_ver, $auth_modify{'externals'}, $tab++ );
	$hidden{'name'} = $name;
	$hidden{'profiles_updated'} = 1;
	$form .= Forms->hidden( \%hidden );
	my %apply   = ( 'name' => 'apply', 'value' => 'Assign and Apply' );
	$form .= Forms->form_bottom_buttons( \%apply, $tab++ );
    }
    elsif ( $obj_view eq 'parents' ) {
	my %docs = Doc->manage_hosts_parents();
	$form .=
	  Forms->host_top( $properties{'name'}, $session_id, $obj_view, $auth_add{'externals'}, $hidden{'selected'}, $hidden{'form_service'} );
	if (@errors) { $form .= Forms->form_errors( \@errors ) }
	$form .= Forms->wizard_doc( 'Parents', $docs{'parents'}, undef, 1 );
	my @members = @{ $properties{'parents'} };
	my @nonmembers = StorProc->fetch_list( 'hosts', 'name' );
	foreach my $index ( 0 .. $#nonmembers ) {
	    if ( $nonmembers[$index] eq $properties{'name'} ) {
		splice( @nonmembers, $index, 1 );
		last;
	    }
	}
	$form .= Forms->members( 'Parents:', 'members', \@members, \@nonmembers, '', 20, $docs{'parents'}, '', $tab++ );
	$hidden{'name'} = $name;
	$form .= Forms->hidden( \%hidden );
	$form .= Forms->form_bottom_buttons( \%save, $tab++ );
    }
    elsif ( $obj_view eq 'escalation_trees' ) {
	my %docs               = Doc->manage_hosts_escalations();
	my $host_escalation    = $query->param('host_escalation');
	my $service_escalation = $query->param('service_escalation');
	unless ($host_escalation) {
	    my %w = ( 'tree_id' => $properties{'host_escalation_id'} );
	    my %t = StorProc->fetch_one_where( 'escalation_trees', \%w );
	    $host_escalation = $t{'name'};
	}
	unless ($service_escalation) {
	    my %w = ( 'tree_id' => $properties{'service_escalation_id'} );
	    my %t = StorProc->fetch_one_where( 'escalation_trees', \%w );
	    $service_escalation = $t{'name'};
	}
	$form .=
	  Forms->host_top( $properties{'name'}, $session_id, $obj_view, $auth_add{'externals'}, $hidden{'selected'}, $hidden{'form_service'} );
	if (@errors) { $form .= Forms->form_errors( \@errors ) }
	$form .= Forms->wizard_doc( 'Escalation Trees', $docs{'escalations'}, undef, 1 );
	my %where = ( 'type' => 'host' );
	my @members = ();
	@members = ('-- remove escalation tree --') if ($host_escalation && $host_escalation ne '-- no host escalation trees --');
	push( @members, StorProc->fetch_list_where( 'escalation_trees', 'name', \%where ) );
	$form .= Forms->list_box_submit( 'Host escalation tree:',
	    'host_escalation', \@members, $host_escalation, '', $docs{'host_escalation_tree'}, $tab++ );
	if ($host_escalation && $host_escalation ne '-- no host escalation trees --' && $host_escalation ne '-- remove escalation tree --') {
	    my ( $ranks, $templates ) = StorProc->get_tree_detail($host_escalation);
	    my %ranks     = %{$ranks};
	    my %templates = %{$templates};
	    $form .= Forms->escalation_tree( \%ranks, \%templates, 'escalations' );
	}
	%where   = ( 'type' => 'service' );
	@members = ();
	@members = ('-- remove escalation tree --') if ($service_escalation && $service_escalation ne '-- no service escalation trees --');
	push( @members, StorProc->fetch_list_where( 'escalation_trees', 'name', \%where ) );
	$form .= Forms->list_box_submit( 'Service escalation tree:',
	    'service_escalation', \@members, $service_escalation, '', $docs{'service_escalation_tree'}, $tab++ );
	if ($service_escalation && $service_escalation ne '-- no service escalation trees --' && $service_escalation ne '-- remove escalation tree --') {
	    my ( $ranks, $templates ) = StorProc->get_tree_detail($service_escalation);
	    my %ranks     = %{$ranks};
	    my %templates = %{$templates};
	    $form .= Forms->escalation_tree( \%ranks, \%templates, 'escalations' );
	}
	$hidden{'name'} = $name;
	my %save = ( 'name' => 'save', 'value' => 'Save' );
	$form .= Forms->hidden( \%hidden );
	$help{url} = StorProc->doc_section_url('How+to+configure+notifications+using+Nagios', 'HowtoconfigurenotificationsusingNagios-ApplyingEscalationTrees');
	$form .= Forms->form_bottom_buttons( \%save, \%help, $tab++ );
    }
    elsif ( $obj_view eq 'hostgroups' ) {
	my %docs = Doc->manage_hosts_hostgroups();
	$form .=
	  Forms->host_top( $properties{'name'}, $session_id, $obj_view, $auth_add{'externals'}, $hidden{'selected'}, $hidden{'form_service'} );
	if (@errors) { $form .= Forms->form_errors( \@errors ) }
	my @members = StorProc->get_host_hostgroups($name);
	my @nonmembers = StorProc->fetch_list( 'hostgroups', 'name' );
	$form .= Forms->wizard_doc( 'Hostgroups', $docs{'hostgroups'}, undef, 1 );
	$form .= Forms->members( 'Hostgroups:', 'members', \@members, \@nonmembers, '', '', $docs{'hostgroups'}, '', $tab++ );
	$hidden{'name'} = $name;
	$form .= Forms->hidden( \%hidden );
	$form .= Forms->form_bottom_buttons( \%save, $tab++ );
    }
    elsif ( $obj_view eq 'services' ) {
	my %docs = Doc->manage_hosts_services();
	$form .=
	  Forms->host_top( $properties{'name'}, $session_id, $obj_view, $auth_add{'externals'}, $hidden{'selected'}, $hidden{'form_service'} );
	my %services = ();
	my %where    = ( 'host_id' => $properties{'host_id'} );
	my @services = StorProc->fetch_list_where( 'services', 'service_id', \%where );
	foreach my $sid (@services) {
	    my $service_name = StorProc->get_service_name($sid);
	    $service_name =~ s/\s/+/g;
	    $services{$service_name} = $sid;
	}
	if (@errors) { $form .= Forms->form_errors( \@errors ) }
	$form .= Forms->wizard_doc( 'Services', $docs{'services'}, undef, 1 );
	if (@messages) {
	    $form .= Forms->form_message( 'Status:', \@messages, 'msg' );
	}
	my @service_names = StorProc->fetch_list( 'service_names', 'name' );
	my @service_list = ();
	foreach my $s (@service_names) {
	    $s =~ s/\s/+/g;
	    unless ( $services{$s} ) { $s =~ s/\+/ /g; push @service_list, $s }
	}
	@service_list = sort @service_list;
	$form .= Forms->service_list( $session_id, $name, \%services, \@service_list, $hidden{'selected'} );
	$hidden{'name'} = $name;
	$form .= Forms->hidden( \%hidden );
	$form .= Forms->form_bottom_buttons();
    }
    elsif ( $obj_view eq 'host_externals' ) {
	my %docs = Doc->manage_hosts_host_externals();
	$form .=
	  Forms->host_top( $properties{'name'}, $session_id, $obj_view, $auth_add{'externals'}, $hidden{'selected'}, $hidden{'form_service'} );
	my %externals = ();
	my %modified  = ();
	my %where     = ( 'host_id' => $properties{'host_id'} );
	my @externals = StorProc->fetch_list_where( 'external_host', 'external_id', \%where );
	foreach my $eid (@externals) {
	    my %e = StorProc->fetch_one( 'externals', 'external_id', $eid );
	    $externals{ $e{'name'} } = $eid;
	    my %where = (
		'external_id' => $eid,
		'host_id'     => $properties{'host_id'}
	    );
	    my %external = StorProc->fetch_one_where( 'external_host', \%where );
	    $modified { $e{'name'} } = $external{'modified'};
	}
	if (@errors) { $form .= Forms->form_errors( \@errors ) }
	$form .= Forms->wizard_doc( 'Host Externals', $docs{'host_externals'}, undef, 1 );
	if (@messages) {
	    $form .= Forms->form_message( 'Status:', \@messages, 'msg' );
	}
	my %w = ( 'type' => 'host' );
	my @external_names = StorProc->fetch_list_where( 'externals', 'name', \%w );
	my @external_list = ();
	foreach my $s (@external_names) {
	    unless ( $externals{$s} ) { push @external_list, $s }
	}
	@external_list = sort @external_list;
	$form .= Forms->external_list( $session_id, $name, \%externals, \@external_list, 'host', undef, undef, \%modified );
	$hidden{'type'} = 'host';
	$hidden{'name'} = $name;
	$hidden{'id'}   = $properties{'host_id'};
	$form .= Forms->hidden( \%hidden );
	$help{url} = StorProc->doc_section_url('How+to+configure+externals');
	$form .= Forms->form_bottom_buttons( \%help );
    }
    elsif ( $obj_view eq 'host_external_detail' ) {
	$form .=
	  Forms->host_top( $properties{'name'}, $session_id, $obj_view, $auth_add{'externals'}, $hidden{'selected'}, $hidden{'form_service'} );
	if (@errors) { $form .= Forms->form_errors( \@errors ) }
	my $detail        = $query->param('detail');
	my $host_external = $query->param('host_external');
	unless ($host_external) { $host_external = $properties{'external'} }
	my %where = (
	    'external_id' => $properties{'external_id'},
	    'host_id'     => $properties{'host_id'}
	);
	my %external = StorProc->fetch_one_where( 'external_host', \%where );
	unless ($detail) { $detail = $external{'data'} }
	$form .= Forms->wizard_doc( 'Host External', undef, undef, 1 );
	$form .= Forms->display_hidden( 'Host external name:', 'host_external', $host_external );
	$form .= Forms->display_hidden( 'Host external state:', '', $external{'modified'} ? 'locally modified' : 'unmodified from original' );
	$form .= Forms->text_area( 'Detail:', 'detail', $detail, '25', '100%', '', '', '', $tab++ );
	$hidden{'external_id'} = $external{'external_id'};
	$form .= Forms->hidden( \%hidden );
	my %docs = Doc->externals();
	if ($external{'modified'}) {
	    $form .= Forms->wizard_doc( 'Reset vs. Save', $docs{'reset_host'}, undef, 1 );
	    my %reset = ( 'name' => 'reset', 'value' => 'Reset to Generic Detail' );
	    $form .= Forms->form_bottom_buttons( \%reset, \%save, $tab++ );
	}
	else {
	    $form .= Forms->wizard_doc( 'Mark vs. Save', $docs{'mark_host'}, undef, 1 );
	    my %mark = ( 'name' => 'mark', 'value' => 'Mark as Modified' );
	    $form .= Forms->form_bottom_buttons( \%mark, \%save, $tab++ );
	}
    }
    elsif ( $obj_view eq 'service_detail' ) {
	my %docs = Doc->manage_hosts_service_detail();
	$hidden{'service_id'} = $query->param('service_id');
	my $service_name = $query->param('service_name');
	my $notes        = $query->param('notes');
	my $ext_info     = $query->param('ext_info');
	my $escalation   = $query->param('escalation');
	if (defined $notes) {
	    $notes = StorProc->sanitize_string_but_keep_newlines($notes);
	    $notes =~ s/\n/<br>/g;
	}
	unless ( $hidden{'service_name'} ) {
	    $hidden{'service_name'} = $query->param('service_name');
	}
	unless ( $hidden{'service_id'} ) {
	    my %snid = StorProc->fetch_one( 'service_names', 'name', $hidden{'service_name'} );
	    my %where = (
		'host_id'        => $properties{'host_id'},
		'servicename_id' => $snid{'servicename_id'}
	    );
	    my %sid = StorProc->fetch_one_where( 'services', \%where );
	    $hidden{'service_id'} = $sid{'service_id'};
	}
	my %p = StorProc->fetch_one( 'services', 'service_id', $hidden{'service_id'} );
	unless (defined $notes) {
	    $notes = $p{'notes'};
	}
	my %w = ( 'serviceextinfo_id' => $p{'serviceextinfo_id'} );
	my %e = StorProc->fetch_one_where( 'extended_service_info_templates', \%w );
	$ext_info = $e{'name'};
	%w = ( 'tree_id' => $p{'escalation_id'} );
	unless ($escalation) {
	    my %esc = StorProc->fetch_one_where( 'escalation_trees', \%w );
	    $escalation = $esc{'name'};
	}
	my %objs = (
	    'service_id'   => $hidden{'service_id'},
	    'service_name' => $service_name
	);
	$form .=
	  Forms->host_top( $properties{'name'}, $session_id, $obj_view, $auth_add{'externals'}, $hidden{'selected'}, $hidden{'form_service'} );
	if (@errors) { $form .= Forms->form_errors( \@errors ) }
	$form .= Forms->display_hidden( 'Service name:', 'service_name', $service_name );
	$notes =~ s/<br>/\n/ig if defined $notes;
	my $lines = (( () = split( /\n/, (defined($notes) ? $notes : ''), 20 ) ) || 1) + 1;
	$form .= Forms->text_area( 'Notes:', 'notes', $notes, $lines, '74%', '', $docs{'notes'}, '', $tab++ );
	$form .= build_service_detail( $hidden{'service_id'} );
	$form .= Forms->wizard_doc( 'Additional Per-Host-Service Options', undef, undef, 1 );
	my @members = StorProc->fetch_list( 'extended_service_info_templates', 'name' );
	$form .= Forms->list_box( 'Extended info template:', 'ext_info', \@members, $ext_info, '', $docs{'extinfo'}, '', $tab++ );
	my %where = ( 'type' => 'service' );
	@members = ();
	@members = ('-- remove escalation tree --') if ($escalation && $escalation ne '-- no service escalation trees --');
	push( @members, StorProc->fetch_list_where( 'escalation_trees', 'name', \%where ) );
	$form .= Forms->list_box_submit( 'Service escalation tree:',
	    'escalation', \@members, $escalation, '', $docs{'service_escalation_tree'}, $tab++ );
	if ($escalation && $escalation ne '-- no service escalation trees --' && $escalation ne '-- remove escalation tree --') {
	    my ( $ranks, $templates ) = StorProc->get_tree_detail($escalation);
	    my %ranks     = %{$ranks};
	    my %templates = %{$templates};
	    $form .= Forms->escalation_tree( \%ranks, \%templates, 'service_detail' );
	}
	$hidden{'name'} = $name;
	$form .= Forms->hidden( \%hidden );
	my %save = ( 'name' => 'save', 'value' => 'Save' );
	$form .= Forms->form_bottom_buttons( \%save, $tab++ );
    }
    elsif ( $obj_view eq 'service_check' ) {
	my %docs = Doc->manage_hosts_service_check();
	$hidden{'service_id'} = $query->param('service_id');
	my %service      = StorProc->fetch_one( 'services', 'service_id', $hidden{'service_id'} );
	my $service_name = $query->param('service_name');
	my %template     = StorProc->fetch_one( 'service_templates', 'servicetemplate_id', $service{'servicetemplate_id'} );
	my %generic      = StorProc->fetch_one( 'service_names', 'servicename_id', $service{'servicename_id'} );
	my $message      = undef;

	# If we are returning to this screen because of a change to the inheritance of the command,
	# or to the command selected, preserve what we had going in other parts of the screen as
	# much as possible.  To do that, we check for "service_check", which is defined on a direct
	# view of the screen, undefined in an inheritance-change or command-change refresh.
	my $reset_data = $query->param('service_check');

	my %cmd          = StorProc->fetch_one( 'commands', 'command_id', $service{'check_command'} );
	my $command      = $cmd{'name'};
	my $command_save = $cmd{'name'};
	my $command_line = $service{'command_line'};

	my $inherit;
	my $inherit_ext_args;
	my $externals_arguments;
	if ($reset_data) {
	    $inherit = 0;
	    $inherit_ext_args    = $service{'inherit_ext_args'};
	    $externals_arguments = $service{'externals_arguments'};
	}
	else {
	    $inherit = $query->param('inherit');
	    $inherit_ext_args = $query->param('inherit_ext_args');
	    $externals_arguments = $inherit_ext_args ? $service{'externals_arguments'} : $query->param('externals_arguments');
	    if ( $query->param('command') )      { $command      = $query->param('command') }
	    if ( $query->param('command_save') ) { $command_save = $query->param('command_save'); }
	    if ( $query->param('command_line') ) { $command_line = $query->param('command_line'); }
	}

	unless ( defined($command) && defined($command_save) && $command eq $command_save ) {
	    %cmd = StorProc->fetch_one( 'commands', 'name', $command );
	    $command_line = undef;
	}
	if ( $inherit or !$command ) {
	    %cmd = StorProc->fetch_one( 'commands', 'command_id', $template{'check_command'} );
	    if ( $cmd{'name'} ) {
		$command      = $cmd{'name'};
		$command_line = $template{'command_line'};
		$inherit      = 1;
	    }
	    else {
		my $got_command  = 0;
		my $stid         = $template{'parent_id'};
		my %already_seen = ();
		until ($got_command) {
		    my %t = StorProc->fetch_one( 'service_templates', 'servicetemplate_id', $stid );
		    if ( $t{'check_command'} ) {
			$got_command  = 1;
			%cmd          = StorProc->fetch_one( 'commands', 'command_id', $t{'check_command'} );
			$command      = $cmd{'name'};
			$command_line = $t{'command_line'};
		    }
		    else {
			$already_seen{$stid} = 1;
			if ( $t{'parent_id'} ) {
			    if ( $already_seen{ $t{'parent_id'} } ) {
				$got_command = 1;
				$message     = (
"Note: no parent template (recursively) has a check command defined.<br><b><font color=#FF0000>ERROR:  You have a cyclical chain of parents in your service templates, starting with \"$t{'name'}\".</font></b>"
				);
				$required{'check_command'} = 1;
				$command                   = undef;
				$command_line              = undef;
			    }
			    else {
				$stid = $t{'parent_id'};
			    }
			}
			else {
			    $got_command               = 1;
			    $message                   = ('Note: no parent template (recursively) has a check command defined.');
			    $required{'check_command'} = 1;
			    $command                   = undef;
			    $command_line              = undef;
			}
		    }
		}
	    }
	}
	%cmd = StorProc->fetch_one( 'commands', 'name', $command );
	my $arg_string = $command_line;
	$arg_string =~ s/$command!//;
	my $usage = $command;
	my @args = split( /\$ARG/i, $cmd{'command_line'} );
	if (@args) {
	    my $maxarg = 0;
	    shift @args;    # drop command
	    foreach (@args) {
		if (/^(\d+)\$/) {
		    $maxarg = $1 if $maxarg < $1;
		}
	    }
	    my $args = $maxarg ? join( '!', map "ARG$_", 1 .. $maxarg ) : '';
	    unless ( $command_line =~ /$command/ ) {
		$command_line = "$command!$args";
	    }
	    $usage .= "!$args";
	}
	my %objs = (
	    'service_id'   => $hidden{'service_id'},
	    'service_name' => $service_name
	);
	$form .= Forms->host_top( $properties{'name'}, $session_id, $obj_view, $auth_add{'externals'}, $hidden{'selected'},
	    $hidden{'form_service'} );
	if (@errors) { $form .= Forms->form_errors( \@errors ) }
	$form .= Forms->display_hidden( 'Service name:', 'service_name', $service_name );
	$form .= Forms->wizard_doc( 'Service Template', undef, undef, 1 );
	$form .= Forms->display_hidden( 'Service template:', '', $template{'name'});
	$form .= Forms->wizard_doc( 'Service Check', $docs{'service_check'}, undef, 1 );
	$form .= Forms->checkbox_override(
	    'Inherit check from template:',
	    'inherit', $inherit, $docs{'use_template_command'},
	    undef, undef, 'enableAllArgs()'
	);
	my %where = ( 'type' => 'check' );
	my @commands = StorProc->fetch_list_where( 'commands', 'name', \%where );
	$form .= Forms->list_box_submit(
	    'Check command:',
	    'command', \@commands, $command, $required{'check_command'},
	    $docs{'check_command'}, $tab++, $inherit, 'enableAllArgs()'
	);
	$form .= Forms->display_hidden( 'Command definition:', '', HTML::Entities::encode( $cmd{'command_line'} ) );
	$form .= Forms->display_hidden( 'Usage:', '', $usage );
	$form .= Forms->text_area( 'Command line:', 'command_line', $command_line, '3', '80', '', $docs{'command_line'}, '', $tab++, undef, undef, $inherit );
	unless ($host) { $host = $name }
	$form .= Forms->test_service_check( $test_results, $host, '', $tab++, 'enableAllArgs()' );
	my $base_ext_args;
	if ($enable_externals) {
	    $form .= Forms->wizard_doc( 'Externals Macro Arguments (optional)', $docs{'macro_arguments'}, undef, 1 );

	    $form .= Forms->js_toggle_input();
	    $form .= Forms->checkbox(
		'Inherit externals args:',
		'inherit_ext_args', $inherit_ext_args, $docs{'inherit_ext_args'},
		'', $tab++, undef, undef, 'externals_arguments', 'Inherit externals arguments from the generic service'
	    );

	    my $value  = ( $inherit_ext_args ? $generic{'externals_arguments'} : $externals_arguments )            // '';
	    my $tvalue = ( $inherit_ext_args ? $externals_arguments            : $generic{'externals_arguments'} ) // '';
	    $tvalue = $generic{'externals_arguments'} // '' if $tvalue eq '';
	    $base_ext_args = $value;

	    $form .= Forms->text_area(
		'Externals arguments:',
		'externals_arguments', $value, '3', '80', '', $docs{'externals_arguments'},
		'', $tab++, undef, $tvalue, $inherit_ext_args
	    );

	    my $service_externals =
	      StorProc->fetch_map_where( 'external_service', 'external_id', 'data', { 'service_id' => $hidden{'service_id'} } );

	    my %external_ids = ();
	    if (%$service_externals) {
		## This loop assumes we have uniqueness of service external names.  That is
		## currently not enforced at the database level, but is within the Monarch UI.
		foreach my $external_id ( keys %$service_externals ) {
		    my $one_external = StorProc->fetch_map_where( 'externals', 'name', 'external_id', { 'external_id' => $external_id } );
		    @external_ids{ keys %$one_external } = values %$one_external;
		}
	    }

	    if (%external_ids) {
		my $one_host = StorProc->fetch_map_where( 'hosts', 'name', 'host_id', { 'name' => $name } );
		my $host_id  = $one_host->{$name};
		my $nocache  = time();
		foreach my $external_name ( sort keys %external_ids ) {
		    my $external = $service_externals->{ $external_ids{$external_name} };
		    $external =~ s/\n/<br>/g;
		    my $link = "/monarch/monarch.cgi?nocache=$nocache&external&form_service=1&id=$host_id&name=$name&obj=hosts&obj_view=service_externals&select_external=$external_name&service_id=$hidden{service_id}&service_name=$service_name&top_menu=hosts&type=service&update_main=1&view=manage_host";
		    $form .= Forms->wizard_doc( "<a class='visible_link' href='$link'>$external_name</a>", "<tt>$external</tt>" );
		}
		## FIX MINOR:  add in a "Test Argument Substitution" button (see GWMON-13210)
	    }
	    else {
		$form .= Forms->wizard_doc( undef, "This host service currently has no service externals assigned." );
	    }
	}
	$hidden{'command_save'} = $command;
	$hidden{'name'}         = $name;
	my %instances = StorProc->get_service_instances( $hidden{'service_id'} );
	my %inst      = ();
	if ( not $reset_data ) {
	    foreach my $qname ( $query->param ) {
		if ( $qname =~ /^args_(\d+)/ ) {
		    $inst{$1}{'args'} = $query->param($qname);
		}
		elsif ( $qname =~ /^ext_args_(\d+)/ && $enable_externals ) {
		    $inst{$1}{'ext_args'} = $query->param($qname);
		}
		elsif ( $qname =~ /^inh_ext_args_(\d+)/ && $enable_externals ) {
		    $inst{$1}{'inh_ext_args'} = $query->param($qname);
		}
		elsif ( $qname =~ /status_(\d+)/ ) {
		    $inst{$1}{'status'} = 1;
		}
		elsif ( $qname =~ /instance_(\d+)/ ) {
		    $inst{$1}{'instance'} = $query->param($qname);
		    my $iname = $query->param($qname);
		    $instances{$iname}{'id'} = $1;
		}
	    }
	}
	foreach my $i ( keys %instances ) {
	    if ( $inst{ $instances{$i}{'id'} } ) {
		$instances{$i}{'status'} = $inst{ $instances{$i}{'id'} }{'status'};
		$instances{$i}{'args'}   = $inst{ $instances{$i}{'id'} }{'args'};
		if ($enable_externals) {
		    $instances{$i}{'ext_args'}     = $inst{ $instances{$i}{'id'} }{'ext_args'};
		    $instances{$i}{'inh_ext_args'} = $inst{ $instances{$i}{'id'} }{'inh_ext_args'};
		}
	    }
	}
	my @rem_instances = $reset_data ? () : $query->$multi_param('rem_inst');
	foreach my $id (@rem_instances) {
	    foreach my $i ( keys %instances ) {
		if ( $instances{$i}{'id'} eq $id ) { delete $instances{$i} }
	    }
	}
	$form .= Forms->service_instances( \%instances, $auth_modify{'externals'}, $base_ext_args, $docs{'service_instance'}, $tab++ );
	$form .= Forms->hidden( \%hidden );
	my %save = ( 'name' => 'save', 'value' => 'Save', onclick => 'enableAllArgs()' );
	$form .= Forms->form_bottom_buttons( \%save, $tab++ );
    }
    elsif ( $obj_view eq 'service_dependencies' ) {
	my %docs = Doc->manage_hosts_service_dependencies();
	$hidden{'service_id'} = $query->param('service_id');
	my $service_name = $query->param('service_name');
	if (! $service_name) {
	    my @servicename_ids = StorProc->fetch_unique( 'services', 'servicename_id', 'service_id', $hidden{'service_id'} );
	    my $servicename_id = $servicename_ids[0];
	    if ($servicename_id) {
		my @service_names = StorProc->fetch_unique( 'service_names', 'name', 'servicename_id', $servicename_id );
		$service_name = $service_names[0];
	    }
	}
	my %objs = (
	    'service_id'   => $hidden{'service_id'},
	    'service_name' => $service_name
	);
	$form .=
	  Forms->host_top( $properties{'name'}, $session_id, $obj_view, $auth_add{'externals'}, $hidden{'selected'}, $hidden{'form_service'} );
	$form .= Forms->display_hidden( 'Service name:', 'service_name', $service_name );
	$form .= Forms->wizard_doc( 'Service Dependencies', $docs{'dependencies'}, undef, 1 );
	if (@errors) { $form .= Forms->form_errors( \@errors ) }
	my $dep_template = $query->param('dep_template');
	my @dep_hosts    = ();
	my $dep_service  = undef;
	if ($dep_template) {
	    my %dep = StorProc->fetch_one( 'service_dependency_templates', 'name', $dep_template );
	    my %s = StorProc->fetch_one( 'service_names', 'servicename_id', $dep{servicename_id} );
	    $dep_service = $s{'name'};
	    my ( $host, $hosts ) = StorProc->get_dep_on_hosts( $dep{'servicename_id'}, $properties{'host_id'} );
	    my @hosts = @{$hosts};
	    @dep_hosts = ($name) if $host;
	    push( @dep_hosts, @hosts );
	}
	my %dependencies = StorProc->get_dependencies( $hidden{'service_id'} );
	$form .= Forms->dependency_list( $name, 'hosts', $hidden{'service_id'}, $session_id, \%dependencies );
	my @dep_templates = StorProc->fetch_list( 'service_dependency_templates', 'name' );
	$form .= Forms->dependency_add( $dep_template, \@dep_templates, \@dep_hosts, $dep_service, \%docs, $tab++ );
	$hidden{'name'} = $name;
	$form .= Forms->hidden( \%hidden );
	my %add_dependency = ( 'name' => 'add_dependency', 'value' => 'Add Dependency' );
	$help{url} = StorProc->doc_section_url('How+to+manage+service+dependencies', 'Howtomanageservicedependencies-AddingaServiceDependencythroughManageHostService');
	$form .= Forms->form_bottom_buttons( \%add_dependency, \%help, $tab++ );
    }
    elsif ( $obj_view eq 'service_externals' ) {
	my %docs = Doc->manage_hosts_service_externals();
	$hidden{'service_id'}   = $query->param('service_id');
	$hidden{'service_name'} = $query->param('service_name');
	my %objs = (
	    'service_id'   => $hidden{'service_id'},
	    'service_name' => $hidden{'service_name'}
	);
	$form .=
	  Forms->host_top( $properties{'name'}, $session_id, $obj_view, $auth_add{'externals'}, $hidden{'selected'}, $hidden{'form_service'} );
	$form .= Forms->display_hidden( 'Service name:', 'service_name', $hidden{'service_name'} );
	my %externals = ();
	my %modified  = ();
	my %where     = ( 'service_id' => $hidden{'service_id'} );
	my @externals = StorProc->fetch_list_where( 'external_service', 'external_id', \%where );

	foreach my $eid (@externals) {
	    my %e = StorProc->fetch_one( 'externals', 'external_id', $eid );
	    $externals{ $e{'name'} } = $eid;
	    my %where = (
		'external_id' => $eid,
		'host_id'     => $properties{'host_id'},
		'service_id'  => $hidden{'service_id'}
	    );
	    my %external = StorProc->fetch_one_where( 'external_service', \%where );
	    $modified { $e{'name'} } = $external{'modified'};
	}
	if (@errors) { $form .= Forms->form_errors( \@errors ) }
	$form .= Forms->wizard_doc( 'Service Externals', $docs{'service_externals'}, undef, 1 );
	if (@messages) {
	    $form .= Forms->form_message( 'Status:', \@messages, 'msg' );
	}
	my %w = ( 'type' => 'service' );
	my @external_names = StorProc->fetch_list_where( 'externals', 'name', \%w );
	my @external_list = ();
	foreach my $s (@external_names) {
	    unless ( $externals{$s} ) { push @external_list, $s }
	}
	@external_list = sort @external_list;
	$form .= Forms->external_list( $session_id, $name, \%externals, \@external_list,
	  'service', $hidden{'service_id'}, $hidden{'service_name'}, \%modified );
	$hidden{'type'} = 'service';
	$hidden{'id'}   = $properties{'host_id'};
	$hidden{'name'} = $name;
	$form .= Forms->hidden( \%hidden );
	$help{url} = StorProc->doc_section_url('How+to+configure+externals');
	$form .= Forms->form_bottom_buttons( \%help );
    }
    elsif ( $obj_view eq 'service_external_detail' ) {
	my $service_name = $query->param('service_name');
	$hidden{'service_id'} = $query->param('service_id');
	$form .=
	  Forms->host_top( $properties{'name'}, $session_id, $obj_view, $auth_add{'externals'}, $hidden{'selected'}, $hidden{'form_service'} );
	if (@errors) { $form .= Forms->form_errors( \@errors ) }
	my $detail           = $query->param('detail');
	my $service_external = $query->param('service_external');
	unless ($service_external) {
	    $service_external = $properties{'external'};
	}
	my %where = (
	    'external_id' => $properties{'external_id'},
	    'host_id'     => $properties{'host_id'},
	    'service_id'  => $hidden{'service_id'}
	);
	my %external = StorProc->fetch_one_where( 'external_service', \%where );
	unless ($detail) { $detail = $external{'data'} }
	$form .= Forms->display_hidden( 'Service name:', 'service_name', $service_name );
	$form .= Forms->wizard_doc( 'Service External', undef, undef, 1 );
	$form .= Forms->display_hidden( 'Service external name:', 'service_external', $service_external );
	$form .= Forms->display_hidden( 'Service external state:', '', $external{'modified'} ? 'locally modified' : 'unmodified from original' );
	$form .= Forms->text_area( 'Detail:', 'detail', $detail, '25', '100%', '', '', '', $tab++ );
	$hidden{'external_id'} = $external{'external_id'};
	$form .= Forms->hidden( \%hidden );
	my %docs = Doc->externals();
	if ($external{'modified'}) {
	    $form .= Forms->wizard_doc( 'Reset vs. Save', $docs{'reset_service'}, undef, 1 );
	    my %reset = ( 'name' => 'reset', 'value' => 'Reset to Generic Detail' );
	    $form .= Forms->form_bottom_buttons( \%reset, \%save, $tab++ );
	}
	else {
	    $form .= Forms->wizard_doc( 'Mark vs. Save', $docs{'mark_service'}, undef, 1 );
	    my %mark = ( 'name' => 'mark', 'value' => 'Mark as Modified' );
	    $form .= Forms->form_bottom_buttons( \%mark, \%save, $tab++ );
	}
    }
    elsif ( $obj_view eq 'saved' ) {
	# FIX MINOR:  correct $obj_view back to where it came from in all cases
	if ( $hidden{'service_name'} ) { $obj_view = 'service_detail' }
	my $host_external    = $query->param('host_external');
	my $service_external = $query->param('service_external');
	$form .= Forms->host_top( $properties{'name'}, $session_id, $obj_view, $auth_add{'externals'},
	  $hidden{'selected'}, $hidden{'form_service'} );
	$form .= Forms->display_hidden( 'Host external name:', 'host_external', $host_external ) if $host_external;
	$form .= Forms->display_hidden( 'Service name:', 'service_name', $hidden{'service_name'} ) if ( $hidden{'service_name'} );
	$form .= Forms->display_hidden( 'Service external name:', 'service_external', $service_external ) if $service_external;
	$form .= Forms->display_hidden( 'Saved:', '', $message );
	$form .= Forms->hidden( \%hidden );
	$form .= Forms->form_bottom_buttons( \%close );
    }
    elsif ( $obj_view =~ /_saved_apply$/ ) {
	$obj_view =~ s/_saved_apply//;
	$form .= Forms->host_top( $properties{'name'}, $session_id, $obj_view, $auth_add{'externals'},
	  $hidden{'selected'}, $hidden{'form_service'} );
	$form .= Forms->display_hidden( 'Saved:', '', $message );
	$form .= Forms->hidden( \%hidden );
	$form .= Forms->form_bottom_buttons();
    }
    elsif ( $obj_view eq 'rename' ) {
	$form .= Forms->host_top( $properties{'name'}, $session_id, $obj_view, $auth_add{'externals'},
	  $hidden{'selected'}, $hidden{'form_service'} );
	if (@errors) { $form .= Forms->form_errors( \@errors ) }
	my $new_name = StorProc->sanitize_string( scalar $query->param('new_name') );
	$form .= Forms->text_box( 'Rename to:', 'new_name', $new_name, $textsize{'name'}, $required, '', '', $tab++ );
	$hidden{'name'} = $name;
	$form .= Forms->hidden( \%hidden );
	$form .= Forms->form_bottom_buttons( \%rename, $tab++ );
    }
    elsif ( $obj_view eq 'delete_host' ) {
	$hidden{'name'} = $name;
	my $message = qq(Are you sure you want to remove host \"$name\"?);
	$form .= Forms->are_you_sure( 'Confirm Delete', $message, 'confirm_delete_host', \%hidden );
    }
    elsif ( $obj_view eq 'deleted' ) {
	$form .= Forms->form_top( 'Status', '' );
	my @message = ("Host \"$name\".");
	$form .= Forms->form_message( 'Removed:', \@message, 'row1' );
	$form .= Forms->hidden( \%hidden );
	$form .= Forms->form_bottom_buttons( \%continue, $tab++ );
    }
    return $form;
}

#
############################################################################
# Sub Delete Object
#

sub delete_object($$) {
    my $id   = shift;
    my $name = shift;
    local $_;

    my $form  = undef;
    my $title = undef;
    ( my $obj_type = $obj ) =~ s/escalation_template/escalation/;
    my @t_parse = split( /_/, $obj_type );
    foreach (@t_parse) { $_ =~ s/ies/y/g; $title .= "\u$_ "; }
    $title =~ s/s\s$//;
    my %dep_templates = ();
    $dep_templates{'time_periods'}{'host_templates'}                     = [ ('notification_period') ];
    $dep_templates{'time_periods'}{'service_templates'}                  = [ ( 'notification_period', 'check_period' ) ];
    $dep_templates{'time_periods'}{'contact_templates'}                  = [ ( 'host_notification_period', 'service_notification_period' ) ];
    $dep_templates{'commands'}{'host_templates'}                         = [ ( 'check_command', 'event_handler' ) ];
    $dep_templates{'commands'}{'service_templates'}                      = [ ( 'check_command', 'event_handler' ) ];
    $dep_templates{'commands'}{'services'}                               = [ ('check_command') ];
    $dep_templates{'host_templates'}{'hosts'}                            = [ ('hosttemplate_id') ];
    $dep_templates{'host_templates'}{'profiles_host'}                    = [ ('host_template_id') ];
    $dep_templates{'service_templates'}{'service_templates'}             = [ ('parent_id') ];
    $dep_templates{'service_templates'}{'service_names'}                 = [ ('template') ];
    $dep_templates{'service_templates'}{'services'}                      = [ ('servicetemplate_id') ];
    $dep_templates{'contact_templates'}{'contacts'}                      = [ ('contacttemplate_id') ];
    $dep_templates{'service_dependency_templates'}{'service_dependency'} = [ ('template') ];

    #	$dep_templates{'contactgroups'}{'contactgroup_assign'} = [ ('contactgroup_id') ];

    $dep_templates{'contactgroups'}{'tree_template_contactgroup'}      = [ ('contactgroup_id') ];
    $dep_templates{'escalation_templates'}{'escalation_tree_template'} = [ ('template_id') ];
    $dep_templates{'extended_service_info_templates'}{'services'}      = [ ('serviceextinfo_id') ];
    $dep_templates{'extended_service_info_templates'}{'service_names'} = [ ('extinfo') ];
    $dep_templates{'extended_host_info_templates'}{'hosts'}            = [ ('hostextinfo_id') ];
    $dep_templates{'extended_host_info_templates'}{'profiles_host'}    = [ ('host_extinfo_id') ];
    unless ($id) {
	my $otable = $obj;
	if ( $otable =~ /escalation_template/ ) {
	    $otable = 'escalation_templates';
	}
	if ( $otable eq 'escalations' ) { $otable = 'escalation_trees' }
	my %id = StorProc->fetch_one( $otable, 'name', $name );
	$id = $id{ $obj_id{$otable} };
    }
    $hidden{'id'} = $id;
    my $all_clear    = 1;
    my %dependencies = ();
    foreach my $table ( keys %{ $dep_templates{$obj} } ) {
	foreach my $column ( @{ $dep_templates{$obj}{$table} } ) {
	    my @dep = ();
	    if ( $table =~ /services|service_dependency$/ ) {
		my @names = StorProc->get_hostname_servicename( $table, $column, $id );
		for my $i ( 0 .. $#names ) {
		    for my $name ( keys %{ $names[$i] } ) {
			push @dep, "$name - $names[$i]{$name}";
		    }
		}
		$dependencies{'Host - Service'} = [@dep];

		# another special case
		# } elsif ($table eq 'contactgroup_assign') {
		# my @names = StorProc->get_contactgroup_object($id,\%obj_id);
		# for my $i ( 0 .. $#names ) {
		#     for my $name ( keys %{ $names[$i] } ) {
		#         push @dep, "$name - $names[$i]{$name}";
		#     }
		# }
		# $dependencies{'Templates/Hostgroups'} = [ @dep ];

	    }
	    elsif ( $table eq 'tree_template_contactgroup' ) {
		@dep = StorProc->get_tree_contactgroup($id);
		$dependencies{'Escalation trees'} = [@dep];
	    }
	    elsif ( $table eq 'contactgroup_contact' ) {
		@dep = StorProc->get_contact_contactgroup($id);
		$dependencies{'Contacts'} = [@dep];
	    }
	    else {
		my %where = ( $column => $id );
		@dep = StorProc->fetch_list_where( $table, 'name', \%where );
		$dependencies{$table} = [@dep];
	    }
	    if ( $dep[0] ) { $all_clear = 0 }
	}
    }
    if ($all_clear) {
	if ( $query->param('confirm_delete') ) {
	    my $otable = $obj;
	    if ( $otable =~ /escalation_template/ ) {
		$otable = 'escalation_templates';
		$obj    = 'escalation_templates';
	    }
	    if ( $otable eq 'escalations' ) {
		$otable = 'escalation_trees';
		$obj    = 'escalation_trees';
	    }
	    my $result = StorProc->delete_all( $otable, $obj_id{$obj}, $id );
	    if ( $result =~ /^Error/ ) {
		push @errors, "Unable to process request: $result";
		$form .= Forms->header( $page_title, $session_id, $top_menu );
		$form .= Forms->form_top( "Delete $title", '' );
		$form .= Forms->form_errors( \@errors );
	    }
	    else {
		my @message = ("$name");
		$form .= Forms->header( $page_title, $session_id, $top_menu, '', '1' );
		$form .= Forms->form_top( "Delete $title", '' );
		$form .= Forms->form_message( 'Removed:', \@message, 'row1' );
	    }
	    $form .= Forms->hidden( \%hidden );
	    $form .= Forms->form_bottom_buttons( \%continue, $tab++ );
	}
	else {
	    foreach my $name ( $query->param ) {
		unless ( $name eq 'nocache' ) {
		    $hidden{$name} = $query->param($name);
		}
	    }
	    delete $hidden{'task'};
	    delete $hidden{'submit'};
	    if ( $obj =~ /escalation_template/ ) {
		$hidden{'task'} = 'escalation_template';
	    }
	    elsif ( $obj =~ /escalation_trees/ ) {
		$hidden{'task'} = 'escalation_trees';
	    }
	    else {
		$hidden{'task'} = 'modify';
	    }
	    my $message = qq(Are you sure you want to remove \"$name\"?);
	    $form .= Forms->header( $page_title, $session_id, $top_menu );
	    $form .= Forms->are_you_sure( "Confirm Delete of $title", $message, 'confirm_delete', \%hidden, 'bail' );
	    $task = 'delete';
	}
    }
    else {
	$form .= Forms->header( $page_title, $session_id, $top_menu );
	$form .= Forms->form_top( "Delete $title", '' );
	$form .= Forms->display_hidden( "\u\L$title\E name:", 'name', $name );
	my @message = ("Cannot delete until all dependencies are removed/reassigned.");
	$form .= Forms->form_errors( \@message );
	foreach my $dep ( keys %dependencies ) {
	    @message = ($dep);
	    $form .= Forms->form_message( 'Object type:', \@message, 'row1' );
	    $form .= Forms->form_message( '&nbsp;', \@{ $dependencies{$dep} }, 'row1' );
	}
	$form .= Forms->hidden( \%hidden );
	$form .= Forms->form_bottom_buttons( \%close, $tab++ );
    }
    return $form;
}

sub rename_object($$) {
    my $id   = shift;
    my $name = shift;
    local $_;

    my $form   = undef;
    my $title  = undef;
    my $ltitle = undef;
    ( my $obj_type = $obj ) =~ s/escalation_template/escalation/;
    my @t_parse = split( /_/, $obj_type );
    foreach (@t_parse) { $_ =~ s/ies/y/g; $title .= "\u$_ "; $ltitle = "$_ " }
    $title =~ s/s\s$//;
    my $new_name = StorProc->sanitize_string( scalar $query->param('new_name') );
    if ( defined($new_name) && $name eq $new_name ) { $new_name = undef }
    my $saved = 0;
    $table = $obj;
    if ( $table =~ /service_groups/ )      { $table = 'servicegroups' }
    if ( $table =~ /escalation_template/ ) { $table = 'escalation_templates' }
    if ( $table =~ /escalation_tree/ )     { $table = 'escalation_trees' }
    if ( $table =~ /_externals/ )          { $table = 'externals' }

    if ($new_name) {
	my %n = StorProc->fetch_one( $table, 'name', $new_name );
	if ( $name =~ /^$new_name$/i ) { delete $n{'name'} }
	if ( $n{'name'} ) {
	    $obj_view = 'rename';
	    $ltitle =~ s/s\s$//;
	    push @errors, "Cannot rename. Another $ltitle has name \"$new_name\".";
	}
	else {
	    if ( $table eq 'commands' ) {
		my %command = StorProc->fetch_one( 'commands', 'name', $name );
		my $results = StorProc->rename_command( \%command, $new_name );
		$name         = $new_name;
		$saved        = 1;
		$refresh_left = 1;
	    }
	    else {
		my %values = ( 'name' => $new_name );
		my $result = StorProc->update_obj( $table, 'name', $name, \%values );
		if ( $result =~ /^Error/ ) {
		    push @errors, $result;
		}
		else {
		    $name         = $new_name;
		    $saved        = 1;
		    $refresh_left = 1;
		}
	    }
	}
    }
    $form .= Forms->header( $page_title, $session_id, $top_menu, '', $refresh_left );
    if ($saved) {
	$form .= Forms->form_top( "Rename $title", Validation->dfv_onsubmit_javascript() );
	my @message = ("$name");
	$form .= Forms->form_message( 'Renamed:', \@message, 'row1' );
	$form .= Forms->hidden( \%hidden );
	$form .= Forms->form_bottom_buttons( \%continue, $tab++ );
    }
    else {
	# FIX MINOR:  See GWMON-6087 for how this should evolve to constrain names for other objects as well.
	if ( $obj eq 'servicegroups' ) {
	    $form .= Validation->dfv_profile_javascript('rename');
	    $form .= &$Instrument::show_trace_as_html_comment();
	}
	$form .= Forms->form_top( "Rename $title", Validation->dfv_onsubmit_javascript(
	    "if (this.clicked == 'cancel') { return true; }"
	) );
	if (@errors) { $form .= Forms->form_errors( \@errors ) }
	$form .= Forms->display_hidden( "\u\L$title\E name:", 'name', $name );
	$form .= Forms->text_box( 'Rename to:', 'new_name', '', $textsize{'name'}, '', '', '', $tab++ );
	$form .= Forms->hidden( \%hidden );
	$form .= Forms->form_bottom_buttons( \%rename, \%cancel, $tab++ );
    }
    return $form;
}

#
############################################################################
# Manage
#

# GWMON-8039

# FIX MAJOR:  Generalize the custom_variables() calling sequence so we accept an array of template hashrefs, each with its own name,
# to allow for a chain of parent templates, instead of a single name and a single template hashref
sub custom_variables($$$$$) {
    my $var_menu = shift;
    my $var_view = shift;
    my $var_type = shift;
    my $var_name = shift;
    my $var_vars = shift;
    local $_;

    my $data              = '';
    my @custom_variable   = ();  # will always be present, for both template and object variables
    my %inherit_variable  = ();  # may or may not be present for a particular variable
    my %suppress_variable = ();  # may or may not be present for a particular variable
    my %value_variable    = ();  # may or may not be present for a particular variable
    foreach my $param ( $query->param() ) {
	if ( $param =~ /^(_\p{IsWord}+)$/ ) {
	    # FIX MAJOR:  ensure that non-ISO-8859-1 characters are stripped or cause errors to be displayed
	    push @custom_variable, $param;
	}
	elsif ( $param =~ /^inherit_(_\p{IsWord}+)$/ ) {
	    $inherit_variable{$1} = 1;
	}
	elsif ( $param =~ /^suppress_(_\p{IsWord}+)$/ ) {
	    $suppress_variable{$1} = 1;
	}
	elsif ( $param =~ /^value_(_\p{IsWord}+)$/ ) {
	    # FIX MAJOR:  ensure that non-ISO-8859-1 characters are stripped or cause errors to be displayed
	    $value_variable{$1} = StorProc->sanitize_string( scalar $query->param($param) );
	}
    }

    # FIX MAJOR:  handle multiple template hashrefs in $var_vars, to support a chain of parent templates
    # (useful mainly for {service and service template} custom variables)

    my @parent_vars = ();
    if (defined $var_name) {
	my %template_variables = map { $_ => $var_vars->{$_} } grep( /^_/, keys %$var_vars );
	my %parent_vars = (
	    menu => $var_menu,
	    view => $var_view,
	    type => $var_type,
	    name => $var_name,
	    vars => \%template_variables,
	);
	push @parent_vars, \%parent_vars;
    }
    my ($template_names, $template_urls, $template_vars) = Forms->resolve_template_variables( $session_id, \@parent_vars );

    foreach my $var (@custom_variable) {
	if ( exists $template_vars->{$var} ) {
	    if ( $suppress_variable{$var} ) {
		$value_variable{$var} = 'null';
	    }
	    elsif ( $inherit_variable{$var} ) {
		delete $value_variable{$var};
	    }
	}
	else {
	    if ( $inherit_variable{$var} ) {
		push @errors,
"Error:  Custom variable \"$var\" used to be in the template, but the template has since been edited. You must start over to ensure that the displayed setup correctly reflects the underlying data.";
	    }
	    elsif ( $suppress_variable{$var} ) {
		$value_variable{$var} = 'null';
	    }
	}
	if ( exists $value_variable{$var} ) {
	    (my $escaped = $value_variable{$var}) =~ s{]]>}{]]]]><!\[CDATA\[>}g;
	    $data .= "\n  <prop name=\"$var\"><![CDATA[$escaped]]>\n  </prop>";
	}
    }
    return $data;
}

sub manage() {
    local $_;

    my $page                    = undef;
    my $name                    = $query->param('name');
    my $title                   = undef;
    my $validation_mini_profile = '';
    my @t_parse                 = split( /_/, $obj );

    foreach (@t_parse) { $title .= "\u$_ " }
    if ( $query->param('cancel') || $query->param('close') || $query->param('continue') ) {
	$page .= Forms->header( $page_title, $session_id, $top_menu );
    }
    else {
	my $task = $query->param('submit');

	#
	# Contacts
	#
	if ( $obj eq 'contacts' ) {
	    my $name = $query->param('name');
	    $hidden{'name'} = $name;
	    my $got_form = undef;
	    if ( $query->param('delete') || $query->param('confirm_delete') ) {
		unless ( $query->param('bail') ) {
		    $page .= Forms->header( $page_title, $session_id, $top_menu );
		    $page .= delete_object( '', $name );
		    $got_form = 1;
		}
	    }
	    elsif ( $query->param('rename') ) {
		$page .= rename_object( '', $name );
		$got_form = 1;
	    }
	    elsif ( $query->param('save') ) {
		my %contact = StorProc->fetch_one( 'contacts', 'name', $name );
		my %data = parse_query( 'contacts', 'contacts' );
		$properties{'template'} = $query->param('template');
		my $field_ck = check_fields();
		if ( $field_ck == 0 ) {
		    my %t = StorProc->fetch_one( 'contact_templates', 'name', $properties{'template'} );
		    my %vals = (
			'contacttemplate_id' => $t{'contacttemplate_id'},
			'alias'              => $data{'alias'},
			'email'              => $data{'email'},
			'pager'              => $data{'pager'}
		    );
		    my $result = StorProc->update_obj( 'contacts', 'name', $name, \%vals );
		    if ( $result =~ /^Error/ ) { push @errors, $result }
		    my %where = ( 'contact_id' => $contact{'contact_id'} );
		    $result = StorProc->delete_one_where( 'contactgroup_contact', \%where );
		    if ( $result =~ /^Error/ ) { push @errors, $result }
		    my @mems = $query->$multi_param('contactgroup');
		    foreach (@mems) {
			my %cg = StorProc->fetch_one( 'contactgroups', 'name', $_ );
			my @vals = ( $cg{'contactgroup_id'}, $contact{'contact_id'} );
			$result = StorProc->insert_obj( 'contactgroup_contact', \@vals );
			if ( $result =~ /^Error/ ) { push @errors, $result }
		    }
		    my $data = '';
		    unless (@errors) {
			$data .= custom_variables('contacts', 'manage', 'contact_templates', $t{'name'}, \%t);
		    }
		    unless (@errors) {
			my %where = ( 'contact_id' => $contact{'contact_id'} );
			my $result = StorProc->delete_one_where( 'contact_overrides', \%where );
			my %values = ();
			unless ( $query->param('host_notification_period_override') ) {
			    my $np = $query->param('host_notification_period');
			    my %np = StorProc->fetch_one( 'time_periods', 'name', $np );
			    $values{'host_notification_period'} = $np{'timeperiod_id'};
			}
			unless ( $query->param('service_notification_period_override') ) {
			    my $np = $query->param('service_notification_period');
			    my %np = StorProc->fetch_one( 'time_periods', 'name', $np );
			    $values{'service_notification_period'} = $np{'timeperiod_id'};
			}
			unless ( $query->param('host_notification_options_override') ) {
			    my @no  = $query->$multi_param('host_notification_options');
			    my $str = undef;
			    foreach (@no) { $str .= "$_," }
			    chop $str;
			    $data .= "\n  <prop name=\"host_notification_options\"><![CDATA[$str]]>\n  </prop>";
			}
			unless ( $query->param('service_notification_options_override') ) {
			    my @no  = $query->$multi_param('service_notification_options');
			    my $str = undef;
			    foreach (@no) { $str .= "$_," }
			    chop $str;
			    $data .= "\n  <prop name=\"service_notification_options\"><![CDATA[$str]]>\n  </prop>";
			}
			if ($data) {
			    $values{'data'} = "<?xml version=\"1.0\" encoding=\"iso-8859-1\" ?>\n<data>" . $data . "\n</data>";
			}
			if (%values) {
			    my @vals = (
				$contact{'contact_id'},
				$values{'host_notification_period'},
				$values{'service_notification_period'},
				$values{'data'}
			    );
			    $result = StorProc->insert_obj( 'contact_overrides', \@vals );
			    if ( $result =~ /^Error/ ) { push @errors, $result }
			}
			%where = ( 'contact_id' => $contact{'contact_id'} );
			$result = StorProc->delete_one_where( 'contact_command_overrides', \%where );
			if ( $result =~ /^Error/ ) { push @errors, $result }
			unless ( $query->param('host_notification_commands_override') ) {
			    my @mems = $query->$multi_param('host_notification_commands');
			    foreach my $cmd (@mems) {
				if ($cmd) {
				    my %c = StorProc->fetch_one( 'commands', 'name', $cmd );
				    my @vals = ( $contact{'contact_id'}, 'host', $c{'command_id'} );
				    $result = StorProc->insert_obj( 'contact_command_overrides', \@vals );
				    if ( $result =~ /^Error/ ) { push @errors, $result }
				}
			    }
			}
			unless ( $query->param('service_notification_commands_override') ) {
			    my @mems = $query->$multi_param('service_notification_commands');
			    foreach my $cmd (@mems) {
				if ($cmd) {
				    my %c = StorProc->fetch_one( 'commands', 'name', $cmd );
				    my @vals = ( $contact{'contact_id'}, 'service', $c{'command_id'} );
				    $result = StorProc->insert_obj( 'contact_command_overrides', \@vals );
				    if ( $result =~ /^Error/ ) { push @errors, $result }
				}
			    }
			}
			unless (@errors) {
			    $page .= Forms->header( $page_title, $session_id, $top_menu );
			    my $message = "Change to contact \"$name\" accepted.";
			    $page .= Forms->success( 'Saved', $message, 'continue', \%hidden );
			    $got_form = 1;
			}
		    }
		}
	    }
	    unless ($got_form) {
		$page .= Forms->header( $page_title, $session_id, $top_menu );
		$page .= Forms->form_top( 'Contact Properties', 'onsubmit="selIt();"' );
		$page .= build_contact();
		$page .= Forms->hidden( \%hidden );
		%save = ( 'name' => 'save', 'value' => 'Save' );
		$help{url} = StorProc->doc_section_url('How+to+configure+notifications+using+Nagios', 'HowtoconfigurenotificationsusingNagios-CreatingContacts');
		$page .= Forms->form_bottom_buttons( \%save, \%delete, \%rename, \%cancel, \%help, $tab++ );
	    }
	}
	elsif ( $query->param('bail') ) {
	    my $title = undef;
	    my @t_parse = split( /_/, $obj );
	    foreach (@t_parse) { $title .= "\u$_ " }
	    $title =~ s/s$//;
	    $page .= Forms->header( $page_title, $session_id, $top_menu );
	    $page .= build_form('');
	}
	elsif ( $query->param('delete') or $query->param('confirm_delete') ) {
	    if ( $obj =~ /escalation/ ) {
		$hidden{'type'} = $query->param('type');
	    }
	    $page .= Forms->header( $page_title, $session_id, $top_menu );
	    $page .= delete_object( '', $name );
	}
	elsif ( $query->param('save') ) {
	    my %values   = ();
	    my %data     = parse_query( $table, $obj );
	    my $field_ck = check_fields();
	    if ( $field_ck == 0 ) {
		foreach my $key ( keys %data ) {
		    unless ( $key =~ /HASH|^name$|members|^contact$|^contactgroup$|^parents$|notification_commands/ ) {
			if ($key eq 'notes') {
			    if (defined $data{$key}) {
				# FIX MAJOR NOW:  this editing is probably no longer needed
				$data{$key} = StorProc->sanitize_string_but_keep_newlines($data{$key});
				$data{$key} =~ s/\n/<br>/g;
			    }
			}
			$values{$key} = $data{$key};
		    }
		}
		my $result = StorProc->update_obj( $table, 'name', $data{'name'}, \%values );
		if ( $result =~ /^Error/ ) { push @errors, $result }
		if ( $obj eq 'contact_templates' ) {
		    my %o = StorProc->fetch_one( 'contact_templates', 'name', $name );
		    my %w = (
			'contacttemplate_id' => $o{'contacttemplate_id'},
			'type'               => 'host'
		    );
		    my $result = StorProc->delete_one_where( 'contact_command', \%w );
		    if ( $result =~ /^Error/ ) { push @errors, $result }
		    if ( $data{'host_notification_commands'} ) {
			my @c =
			  split( /,/, $data{'host_notification_commands'} );
			foreach (@c) {
			    my @vals = ( $o{'contacttemplate_id'}, 'host', $_ );
			    my $result = StorProc->insert_obj( 'contact_command', \@vals );
			    if ( $result =~ /Error/ ) { push @errors, $result }
			}
		    }
		    %w = (
			'contacttemplate_id' => $o{'contacttemplate_id'},
			'type'               => 'service'
		    );
		    $result = StorProc->delete_one_where( 'contact_command', \%w );
		    if ( $result =~ /^Error/ ) { push @errors, $result }
		    if ( $data{'service_notification_commands'} ) {
			my @c =
			  split( /,/, $data{'service_notification_commands'} );
			foreach (@c) {
			    my @vals = ( $o{'contacttemplate_id'}, 'service', $_ );
			    my $result = StorProc->insert_obj( 'contact_command', \@vals );
			    if ( $result =~ /Error/ ) { push @errors, $result }
			}
		    }
		}
		elsif ( $obj eq 'contactgroups' ) {
		    my %cg = StorProc->fetch_one( 'contactgroups', 'name', $data{'name'} );
		    my $result = StorProc->delete_all( 'contactgroup_contact', 'contactgroup_id', $cg{'contactgroup_id'} );
		    if ( $result =~ /^Error/ ) { push @errors, $result }
		    if ( $data{'contact'} ) {
			my @mems = split( /,/, $data{'contact'} );
			foreach (@mems) {
			    my %c = StorProc->fetch_one( 'contacts', 'name', $_ );
			    my @vals = ( $cg{'contactgroup_id'}, $c{'contact_id'} );
			    $result = StorProc->insert_obj( 'contactgroup_contact', \@vals );
			    if ( $result =~ /^Error/ ) { push @errors, $result }
			}
		    }
		}
		elsif ( $obj eq 'hostgroups' ) {
		    my %n = StorProc->fetch_one( 'hostgroups', 'name', $name );
		    my $result = StorProc->delete_all( 'hostgroup_host', 'hostgroup_id', $n{'hostgroup_id'} );
		    if ( $result =~ /^Error/ ) { push @errors, $result }
		    if ( $data{'members'} ) {
			my @mems = split( /,/, $data{'members'} );
			foreach (@mems) {
			    my %m = StorProc->fetch_one( 'hosts', 'name', $_ );
			    my @vals = ( $n{'hostgroup_id'}, $m{'host_id'} );
			    $result = StorProc->insert_obj( 'hostgroup_host', \@vals );
			    if ( $result =~ /^Error/ ) { push @errors, $result }
			}
		    }
		    my %hostgroup = StorProc->fetch_one( $table, 'name', $name );
		    my %w = ( 'hostgroup_id' => $hostgroup{'hostgroup_id'} );
		    $result = StorProc->delete_one_where( 'contactgroup_hostgroup', \%w );
		    if ( $result =~ /^Error/ ) { push @errors, $result }
		    if ( $data{'contactgroup'} ) {
			my @mems = split( /,/, $data{'contactgroup'} );
			foreach (@mems) {
			    my %cg         = StorProc->fetch_one( 'contactgroups', 'name', $_ );
			    my $table_name = $contactgroup_table_by_object{$obj};
			    my @vals       = ( $cg{'contactgroup_id'}, $hostgroup{'hostgroup_id'} );
			    $result = StorProc->insert_obj( 'contactgroup_hostgroup', \@vals );
			    if ( $result =~ /^Error/ ) { push @errors, $result }
			}
		    }
		}
		elsif ( $obj eq 'host_templates' ) {    # GWMON-4694, GWMON-5062
		    my %o = StorProc->fetch_one( 'host_templates', 'name', $name );
		    my %w = ( 'hosttemplate_id' => $o{'hosttemplate_id'} );
		    my $result = StorProc->delete_one_where( 'contactgroup_host_template', \%w );
		    if ( $result =~ /^Error/ ) { push @errors, $result }
		    if ( $data{'contactgroup'} ) {
			my @cg = split( /,/, $data{'contactgroup'} );
			foreach (@cg) {
			    my %cg_obj = StorProc->fetch_one( 'contactgroups', 'name', $_ );
			    my @vals = ( $cg_obj{'contactgroup_id'}, $o{'hosttemplate_id'} );
			    my $result = StorProc->insert_obj( 'contactgroup_host_template', \@vals );
			    if ( $result =~ /Error/ ) { push @errors, $result }
			}
		    }
		}
		unless (@errors) {
		    my $title = undef;
		    my @t_parse = split( /_/, $obj );
		    foreach (@t_parse) { $_ =~ s/ies/y/g; $title .= "$_ "; }
		    $title =~ s/s\s$//;
		    $title =~ s/Wizard/Extended/;
		    if ( $title =~ /Escalation/ ) { $title =~ s/Template//; }
		    my $message = "Changes to $title \"$name\" have been saved.";
		    $hidden{'name'} = undef;
		    $page .= Forms->header( $page_title, $session_id, $top_menu );
		    $page .= Forms->success( 'Updated', $message, 'continue', \%hidden );
		}
		else {
		    foreach (@errors) { error_out("errors $_") }
		}
	    }
	    elsif ( $field_ck == 1 ) {
		$page .= Forms->header( $page_title, $session_id, $top_menu );
		$page .= build_form('');
	    }
	}
	elsif ( $query->param('rename') ) {
	    $page .= rename_object( '', $name );
	}
	elsif ($name) {
	    my $title = undef;
	    my @t_parse = split( /_/, $obj );
	    foreach (@t_parse) { $title .= "\u$_ " }
	    $title =~ s/s$//;
	    $page .= Forms->header( $page_title, $session_id, $top_menu );
	    my $help_url =
		( $obj eq 'hostgroups' )
		? StorProc->doc_section_url('How+to+configure+notifications+using+Nagios', 'HowtoconfigurenotificationsusingNagios-ConfiguringHostGroupsandServiceGroups')
	      : ( $obj eq 'host_templates' )
		? StorProc->doc_section_url('About+Configuration', 'AboutConfiguration-HostandServiceTemplates')
	      : ( $obj eq 'service_dependency_templates' )
		? StorProc->doc_section_url('How+to+manage+service+dependencies')
	      : ( $obj eq 'contactgroups' )
		? StorProc->doc_section_url('How+to+configure+notifications+using+Nagios', 'HowtoconfigurenotificationsusingNagios-CreatingContactGroups')
	      : ( $obj eq 'contact_templates' )
		? StorProc->doc_section_url('How+to+configure+notifications+using+Nagios', 'HowtoconfigurenotificationsusingNagios-CreatingContactTemplates')
	      : ( $obj eq 'extended_host_info_templates' )
		? StorProc->doc_section_url('How+to+define+extended+info')
	      : '';
	    $page .= build_form( $validation_mini_profile, $help_url );
	}
    }
    return $page;
}

# FIX MINOR:  There ought to be some kind of synchronization locking here, to protect the target directory against concurrent usage.
sub exported_files($$) {
    my $group      = shift;
    my $nagios_etc = shift;
    my $page       = '';
    if ( $query->param('refreshed') ) {
	$page .= Forms->header( $page_title, $session_id, $top_menu );
	my $errors = StorProc->check_version( $monarch_ver );
	push @errors, @$errors if @$errors;
	if (@errors) {
	    $page .= Forms->form_errors( \@errors );
	    @errors = ();
	}
	else {
	    require MonarchFile;
	    my ( $files, $errors ) = Files->build_files( $user_acct, $group, $group ? 'commit' : '', '1', $nagios_ver, $nagios_etc, "$doc_root/monarch/download", '1' );
	    my @errors = @{$errors};
	    my @files  = @{$files};
	    if (@errors) {
		$page .= Forms->form_top( $group ? 'Export Instance Errors' : 'Export Errors', '', '' );
		$page .= Forms->display_hidden( 'Monarch group name:', 'name', $group ) if $group;
		$page .= Forms->form_errors( \@errors );
		$page .= Forms->hidden( \%hidden );
		$page .= Forms->form_bottom_buttons( \%continue, $tab++ );
	    }
	    else {
		my $tarball = pop @files;
		my @list    = ($tarball);
		unshift @list, pop @files if $tarball !~ /.tar$/;  # maybe last file was an audit file instead
		@files = sort @files;
		push( @list, @files );
		my $server = $ENV{'SERVER_NAME'};
		if ($group) {
		    $page .= Forms->group_top( $group, '' );
		}
		else {
		    $page .= Forms->form_top( 'Exported Files', '', '' );
		}
		$page .= Forms->table_download_links( "$doc_root/monarch/download", \@list, $server );
		$help{url} = StorProc->doc_section_url('How+to+import+and+export+Nagios+files', 'HowtoimportandexportNagiosfiles-ExporttoFiles');
		$page .= Forms->hidden( \%hidden );
		$page .= Forms->form_bottom_buttons( \%help, $tab++ );
	    }
	}
    }
    else {
	my $now = time;
	$refresh_url = "?update_main=1&amp;nocache=$now&amp;refreshed=1&amp;name=$group";
	foreach my $name ( keys %hidden ) {
	    $refresh_url .= qq(&amp;$name=) . (defined( $hidden{$name} ) ? $hidden{$name} : '');
	}
	$page .= Forms->header( $page_title, $session_id, $top_menu, $refresh_url );
	if ($group) {
	    $page .= Forms->group_top( $group, '' );
	}
	else {
	    $page .= Forms->form_top( 'Exported Files', '', '' );
	}
	my $errors = StorProc->check_version( $monarch_ver );
	push @errors, @$errors if @$errors;
	if (@errors) { $page .= Forms->form_errors( \@errors ) }
	$page .= Forms->form_doc('Exporting files ...');
	$page .= Forms->form_bottom_buttons();
    }
    return $page;
}

#
############################################################################
# Tools
#

sub tools() {
    my $page = undef;
    if ( $query->param('close') || $query->param('continue') ) {
	$page .= Forms->header( $page_title, $session_id, $top_menu );
	$obj = 'close';
    }
    if ( $obj eq 'import_from_files' ) {
	my %import = ( 'name' => 'import_options', 'value' => 'Import' );
	my $precached_file = undef;
	if ( $query->param('confirm_import') ) {
	    $precached_file = StorProc->sanitize_string( scalar $query->param('precached_file') );

	    # We only want to intercept and confirm the import_3x processing.
	    my $import_option = $query->param('import_option');
	    if ( $import_option ne 'purge_all_and_import_3x' ) {
		$query->param( 'run_import', 'Import' );
	    }
	    else {
		## For import_3x processing, we need to validate the input file.
		## FIX MINOR:  /usr/local/groundwork may be a symlink, and that case is not handled here
		if ($precached_file) {
		    my $abs_path = realpath($precached_file) || '';
		    if (   $abs_path !~ m@^/usr/local/nagios/var/[^/]+@
			&& $abs_path !~ m@^/usr/local/nagios/tmp/[^/]+@
			&& $abs_path !~ m@^/tmp/[^/]+@ )
		    {
			push @errors,
			    'Error:  The precached objects file must reside in one of these directories:<br>'
			  . '<tt>&nbsp; &nbsp; /usr/local/nagios/var</tt><br>'
			  . '<tt>&nbsp; &nbsp; /usr/local/nagios/tmp</tt><br>'
			  . '<tt>&nbsp; &nbsp; /tmp</tt><br>';
		    }
		    elsif ( !-f $abs_path || !-r $abs_path ) {
			$precached_file = $abs_path;
			push @errors, "Error:  \"$precached_file\" is not a readable file.";
		    }
		    if (@errors) {
			$query->param( 'import_options', 'Import' );
		    }
		    else {
			$precached_file = $abs_path;
		    }
		}
	    }
	}
	if ( $query->param('continue') ) {
	    print "Content-type: text/html \n\n";
	    $page .= Forms->header( $page_title, $session_id, $top_menu );
	    if ( $query->param('continue') =~ /$abort{'value'}/ ) {
		$page .= Forms->form_top( 'Import Nagios Configuration', '' );
		$hidden{'obj'} = undef;
		$page .= Forms->hidden( \%hidden );
		my @message = ("Import of Nagios files aborted.");
		$page .= Forms->form_message( 'Action Canceled:', \@message, '' );
		$page .= Forms->form_bottom_buttons( \%continue, $tab++ );
		$hidden{'obj'} = undef;
	    }
	}
	elsif ( $query->param('back_up') ) {
	    $page .= Forms->header( $page_title, $session_id, $top_menu );
	    $page .= Forms->form_top( 'Import Nagios Configuration', '' );
	    ## FIX MINOR:  A synchronized backup might take a few moments, both because of
	    ## possible interlock delays with other programs and because the backup itself
	    ## can take macroscopic time, so we should have an intermediate screen.
	    my $annotation = $query->param('annotation');
	    my $lock       = $query->param('lock');
	    $annotation = "Backup manually created by user \"$user_acct\" before importing from files." if not $annotation;
	    $annotation =~ s/\r//g;
	    $annotation =~ s/^\s+|\s+$//g;
	    $annotation .= "\n";
	    my ( $errors, $results, $timings ) = StorProc->synchronized_backup( $nagios_etc, $backup_dir, $user_acct, $annotation, $lock );
	    my $full_backup_dir = $results->[0];
	    if (@$errors) {
		unshift @$errors, "Problem(s) backing up files and/or database to:<br>&nbsp;&nbsp;&nbsp; $full_backup_dir" if $full_backup_dir;
		$page .= Forms->form_message( '<b>Backup&nbsp;error(s):</b>', $errors, 'error' );
	    }
	    else {
		my @message = ("Files backed up to $full_backup_dir .");
		$page .= Forms->form_message( 'Backup&nbsp;complete:', \@message, '' );
	    }
	    $page .= Forms->hidden( \%hidden );
	    $page .= Forms->form_bottom_buttons( \%import, \%abort, $tab++ );
	}
	elsif ( $query->param('abort') ) {
	    $page .= Forms->header( $page_title, $session_id, $top_menu );
	    $page .= Forms->form_top( 'Import Nagios Configuration', '' );
	    $hidden{'obj'} = undef;
	    $page .= Forms->hidden( \%hidden );
	    my @message = ("Import of Nagios files aborted.");
	    $page .= Forms->form_message( 'Action Canceled:', \@message, '' );
	    $page .= Forms->form_bottom_buttons( \%continue, $tab++ );
	    $hidden{'obj'} = undef;
	}
	elsif ( $query->param('run_import') ) {
	    $page .= Forms->header( $page_title, $session_id, $top_menu, '', '', '', '2' );
	    $page .= Forms->form_top( 'Import Nagios Object Files', '' );
	    $page .= Forms->wizard_doc( 'Import Process', 'Please keep this page open until the Status reads "Finished".', undef, 1 );
	    my $import_option     = $query->param('import_option');
	    my $purge_escalations = $query->param('purge_escalations');
	    $precached_file = StorProc->sanitize_string( scalar $query->param('precached_file') );
	    $hidden{'CGISESSID'} = $session_id;
	    $page .= Forms->hidden( \%hidden );
	    $page .=
	      Forms->process_import( $import_option, $purge_escalations, $nagios_etc, $abort{'value'}, $continue{'value'}, $precached_file );
	    use CGI::Ajax;
	    my $url = Forms->get_ajax_url();                     # "$cgi_dir/monarch_ajax.cgi?nocache=$nocache"
	    my $pjx = new CGI::Ajax( 'process_import' => $url, 'skip_header' => 1 );
	    return $pjx->build_html( $query, $page );
	}
	elsif ( $query->param('import_options') ) {
	    my $import_option = $query->param('import_option');
	    $page .= Forms->header( $page_title, $session_id, $top_menu, '' );
	    $page .= Forms->form_top( 'Import Nagios Object Files', '' );
	    if (@errors) { $page .= Forms->form_errors( \@errors ) }
	    if ( !$precached_file ) {
		my %precached_file = StorProc->fetch_one( 'setup', 'name', 'precached_object_file' );
		$precached_file = $precached_file{'value'};
	    }
	    $page .= Forms->import_options( $import_option, $precached_file, $tab++ );
	    $import{'name'} = 'confirm_import';
	    $page .= Forms->hidden( \%hidden );
	    $page .= Forms->form_bottom_buttons( \%import, \%abort, $tab++ );
	}
	elsif ( $query->param('confirm_import') ) {
	    my %docs = Doc->import_nagios_config();
	    $hidden{'import_option'}     = $query->param('import_option');
	    $hidden{'purge_escalations'} = $query->param('purge_escalations');
	    $hidden{'precached_file'}    = $precached_file;
	    $page .= Forms->header( $page_title, $session_id, $top_menu, '' );
	    $page .= Forms->form_top( 'Confirm Import', '' );
	    $page .= Forms->wizard_doc( 'Caution', $docs{'purge_all_and_import_3x'}, 1, 1 );
	    $import{'name'} = 'run_import';
	    $page .= Forms->hidden( \%hidden );
	    $page .= Forms->form_bottom_buttons( \%import, \%abort, $tab++ );
	}
	# FIX MAJOR:  This is the wrong file to test for, and the wrong time to test for it.
	# We should have a separate import directory to draw from, and it should only be
	# tested for once the user decides to move forward.
	elsif ( -f "$nagios_etc/nagios.cfg" ) {
	    my $doc_url = StorProc->doc_section_url('System+Maintenance');
	    my $help_url = StorProc->doc_section_url('How+to+back+up+and+restore', 'Howtobackupandrestore-MonarchBackupandRestore');
	    my $message =
qq(This tool is for importing Nagios configuration files from standalone Nagios installations,
to bring them under the GroundWork umbrella.
This is an infrequent action, not something you would perform regularly.
Nagios configuration files do not contain all the relationships stored within a GroundWork configuration,
so this is NOT a tool for restoring a GroundWork configuration from a backup.
The Bookshelf contains instructions for that (see <a href="$doc_url" target="_blank">System Maintenance</a>
and <a href="$help_url" target="_blank">How to back up and restore > Configuration Database (monarch)</a>).
<p>
<hr class=row2>
</p>
<p class=append>
You are about to update or drop all configuration records in the GroundWork "monarch" database.
Should you choose to continue, it is strongly recommended that you first back up your existing setup.
</p>);
	    $page .= Forms->header( $page_title, $session_id, $top_menu );
	    $page .= Forms->form_top( 'Import Nagios Configuration', '' );
	    $page .= Forms->hidden( \%hidden );
	    $page .= Forms->wizard_doc( 'Import from nagios.cfg, cgi.cfg, and related files', $message, undef, 1 );
	    my %docs = Doc->backups();
	    $page .= Forms->new_backup( 'Create a new backup', $docs{'annotation'}, $docs{'lock'}, 1, $tab++ );
	    $page .= Forms->wizard_doc( undef, 'Are you sure you want to continue without a backup?' );
	    $help{url} = StorProc->doc_section_url('How+to+import+and+export+Nagios+files', 'HowtoimportandexportNagiosfiles-ImportfromFiles');
	    $page .= Forms->form_bottom_buttons( \%import, \%abort, \%help, $tab++ );
	}
	else {
	    $page .= Forms->header( $page_title, $session_id, $top_menu );
	    $page .= Forms->form_top( 'Error', '' );
	    $hidden{'obj'} = undef;
	    $page .= Forms->hidden( \%hidden );
	    my @message = ("Unable to import $nagios_etc/nagios.cfg (update setup options).");
	    $page .= Forms->form_message( 'Does not exist:', \@message, 'error' );
	    $page .= Forms->form_bottom_buttons( \%continue, $tab++ );
	}
    }
    elsif ( $obj eq 'export_to_files' ) {
	## FIX MAJOR:  drop the old code here, once this new form is shown to work
	if (1) {
	    $page .= exported_files('', $nagios_etc);
	}
	else {
	    require MonarchFile;
	    $page .= Forms->header( $page_title, $session_id, $top_menu );
	    my ( $files, $errors ) = Files->build_files( $user_acct, '', '', '1', $nagios_ver, $nagios_etc, "$doc_root/monarch/download", '1' );
	    if (@$errors) {
		$page .= Forms->form_top( 'Export Errors', '', '' );
		$page .= Forms->form_errors( $errors );
		$page .= Forms->hidden( \%hidden );
		$page .= Forms->form_bottom_buttons( \%continue, $tab++ );
	    }
	    else {
		my @files   = @$files;
		my $tarball = pop @files;
		my @list    = ($tarball);
		unshift @list, pop @files if $tarball !~ /.tar$/;  # maybe last file was an audit file instead
		@files = sort @files;
		push @list, @files;
		my $server = $ENV{'SERVER_NAME'};
		$page .= Forms->form_top( 'Exported Files', '', '' );
		$page .= Forms->table_download_links( "$doc_root/monarch/download", \@list, $server );
		$help{url} = StorProc->doc_section_url('How+to+import+and+export+Nagios+files', 'HowtoimportandexportNagiosfiles-ExporttoFiles');
		$page .= Forms->form_bottom_buttons( \%help, $tab++ );
	    }
	}
    }

    return $page;
}

#
############################################################################
# Build Instance
#

sub build_instance($$$) {
    my $group      = shift;
    my $location   = shift;
    my $nagios_etc = shift;
    my $page       = '';
    if ( $query->param('refreshed') ) {
	$page .= Forms->header( $page_title, $session_id, $top_menu );
	$page .= Forms->form_top( 'Build Instance', '', '' );
	$page .= Forms->display_hidden( 'Monarch group name:', 'name', $group );
	my $errors = StorProc->check_version( $monarch_ver );
	push @errors, @$errors if @$errors;
	if (@errors) {
	    $page .= Forms->form_errors( \@errors );
	    @errors = ();
	}
	else {
	    require MonarchFile;
	    my ( $files, $errors ) = Files->build_files( $user_acct, $group, 'commit', '', $nagios_ver, $nagios_etc, '', '1', '1' );
	    my @errors = @{$errors};
	    my @files  = @{$files};
	    # $page .= Forms->form_message( 'Error(s) building file(s):', $errors, 'error' ) if @$errors;
	    if (@errors) {
		$page .= Forms->form_errors( \@errors );
	    }
	    else {
		my @results = ("Files for the \"$group\" build were generated in $location .");
		use MonarchDeploy;
		push( @results, Deploy->deploy( $group, $location, $nagios_etc, $monarch_home ) );
		$page .= Forms->form_message( 'Status', \@results, 'row1', 1 );
	    }
	}
	$page .= Forms->hidden( \%hidden );
	$page .= Forms->form_bottom_buttons( \%continue, $tab++ );
    }
    else {
	my $now = time;
	$refresh_url = "?update_main=1&amp;nocache=$now&amp;refreshed=1&amp;name=$group";
	foreach my $name ( keys %hidden ) {
	    $refresh_url .= qq(&amp;$name=) . (defined( $hidden{$name} ) ? $hidden{$name} : '');
	}
	$page .= Forms->header( $page_title, $session_id, $top_menu, $refresh_url );
	$page .= Forms->form_top( 'Build Instance', '', '' );
	$page .= Forms->display_hidden( 'Monarch group name:', 'name', $group );
	my $errors = StorProc->check_version( $monarch_ver );
	push @errors, @$errors if @$errors;
	if (@errors) { $page .= Forms->form_errors( \@errors ) }
	$page .= Forms->form_doc('Building instance ...');
	$page .= Forms->form_bottom_buttons();
    }
    return $page;
}

#
############################################################################
# Groups
#

sub groups() {
    my $obj_view = $query->param('obj_view');
    my @views = ( 'detail', 'macros', 'hosts', 'sub_groups', 'rename' );
    foreach my $v (@views) {
	if ( $query->param($v) ) { $obj_view = $v }
    }
    my %save_macros   = ();
    my @remove_macros = ();
    my $form          = undef;
    @errors = ();
    my $name    = StorProc->sanitize_string( scalar $query->param('name') );
    my %group   = StorProc->fetch_one( 'monarch_groups', 'name', $name );
    push @errors, delete $group{'error'} if defined $group{'error'};
    my $message = undef;

    if ( $query->param('add') ) {
	## We follow standard fully-qualified-host-name/IP-address restrictions for group names (alphanumerics plus hyphen
	## and dot, and not beginning or ending with a hyphen or dot, as the group name will be used in the same context.
	unless ( $group{'name'} || $name eq '' || $name =~ /[^a-zA-Z0-9-.]/ || $name =~ /^-|-$/ || $name =~ /^[.]|[.]$/ ) {
	    my $data .= qq(<?xml version="1.0" encoding="iso-8859-1" ?>
<data>
 <prop name="label_enabled"><![CDATA[]]>
 </prop>
 <prop name="label"><![CDATA[]]>
 </prop>
 <prop name="use_hosts"><![CDATA[]]>
 </prop>
 <prop name="nagios_etc"><![CDATA[]]>
 </prop>
 <prop name="inherit_host_active_checks_enabled"><![CDATA[1]]>
 </prop>
 <prop name="inherit_host_passive_checks_enabled"><![CDATA[1]]>
 </prop>
 <prop name="inherit_service_active_checks_enabled"><![CDATA[1]]>
 </prop>
 <prop name="inherit_service_passive_checks_enabled"><![CDATA[1]]>
 </prop>
 <prop name="host_active_checks_enabled"><![CDATA[]]>
 </prop>
 <prop name="host_passive_checks_enabled"><![CDATA[]]>
 </prop>
 <prop name="service_active_checks_enabled"><![CDATA[]]>
 </prop>
 <prop name="service_passive_checks_enabled"><![CDATA[]]>
 </prop>
</data>);
	    my @values = ( \undef, $name, '', '', '', $data );
	    my $id = StorProc->insert_obj_id( 'monarch_groups', \@values, 'group_id' );
	    unless ( $id =~ /^Error/ ) {
		%group = StorProc->fetch_one( 'monarch_groups', 'name', $name );
		push @errors, delete $group{'error'} if defined $group{'error'};
		unless ($is_portal) {
		    my %super_user = StorProc->fetch_one( 'user_groups', 'name', 'super_users' );
		    my @values = ( $id, 'group_macro', $super_user{'usergroup_id'}, $name );
		    my $result = StorProc->insert_obj( 'access_list', \@values );
		    if ( $result =~ /^Error/ ) { push @errors, $result }
		    unless ( $user_acct eq 'super_user' ) {
			my %where = ( 'user_id' => $userid );
			my @user_groups = StorProc->fetch_list_where( 'user_group', 'usergroup_id', \%where );
			foreach my $ugid (@user_groups) {
			    if ( $super_user{'usergroup_id'} eq $ugid ) { next }
			    my @values = ( $id, 'group_macro', $ugid, $name );
			    my $result = StorProc->insert_obj( 'access_list', \@values );
			    if ( $result =~ /^Error/ ) { push @errors, $result }
			}
		    }
		}
		$obj_view = 'detail';
	    }
	    else {
		push @errors, $id;
		$obj_view = 'new';
	    }
	}
	else {
	    push @errors,
"Check the Monarch group name field. It's either blank, contains illegal characters (anything other than a-z, A-Z, 0-9, hyphen, and dot), begins or ends with a hyphen or dot, or this group already exists.";
	    $obj_view = 'new';
	}
    }
    elsif ( $query->param('cancel') &&
      (!defined($obj_view) || ($obj_view ne 'nagios_cgi' && $obj_view ne 'nagios_cfg' && $obj_view ne 'resource_cfg')) ) {
	$obj_view = 'detail';
    }
    elsif ( $query->param('close') || $query->param('continue') ) {
	$form .= Forms->header( $page_title, $session_id, $top_menu );
	$obj_view = 'close';
    }
    elsif ( $query->param('export') ) {
	my $results = undef;
	if ( $results =~ /^Error/ ) {
	    push @errors, $results;
	}
	else {
	    $obj_view = 'exported';
	}
    }
    elsif ( $query->param('rename') && $query->param('new_name') ) {
	my $new_name = StorProc->sanitize_string( scalar $query->param('new_name') );
	my %group_exists = StorProc->fetch_one( 'monarch_groups', 'name', $new_name );
	push @errors, delete $group_exists{'error'} if defined $group_exists{'error'};
	if ( $new_name =~ /[^a-zA-Z0-9-.]/ || $name =~ /^-|-$/ || $name =~ /^[.]|[.]$/ ) {
	    push @errors,
"Check the new Monarch group name (name = \"$new_name\"). Group names cannot contain illegal characters (anything other than a-z, A-Z, 0-9, hyphen, and dot), or begin or end with a hyphen or dot.";
	}
	elsif ( $new_name && !$group_exists{'name'} ) {
	    my %values = ( 'name' => $new_name );
	    my $result = StorProc->update_obj( 'monarch_groups', 'name', $name, \%values );
	    if ( $result =~ /^Error/ ) {
		push @errors, $result;
	    }
	    else {
		$name         = $new_name;
		$refresh_left = 1;
	    }
	}
	else {
	    push @errors, "Check the new Monarch group name (name = \"$new_name\"). It is either blank or this group already exists.";
	}
	unless (@errors) { $obj_view = 'detail' }
    }
    elsif ( $query->param('save') ) {
	my $description = $query->param('description');
	my $inactive    = $query->param('inactive')   || 0;   # param is "1" if set, undef if not
	my $sync_hosts  = $query->param('sync_hosts') || 0;   # param is "2" if set, undef if not; but always undef if inactive is undef
	my $status      = $inactive + $sync_hosts;            # Elsewhere, $status of either undef or 0 is treated like $status of 2.
	my $location    = StorProc->sanitize_string( scalar $query->param('location') );
	my $nagios_etc  = StorProc->sanitize_string( scalar $query->param('nagios_etc') );
	my $use_hosts   = $query->param('use_hosts');
	my $inherit_host_active_checks_enabled     = $query->param('inherit_host_active_checks_enabled');
	my $inherit_host_passive_checks_enabled    = $query->param('inherit_host_passive_checks_enabled');
	my $inherit_service_active_checks_enabled  = $query->param('inherit_service_active_checks_enabled');
	my $inherit_service_passive_checks_enabled = $query->param('inherit_service_passive_checks_enabled');
	my $host_active_checks_enabled             = $query->param('host_active_checks_enabled');
	my $host_passive_checks_enabled            = $query->param('host_passive_checks_enabled');
	my $service_active_checks_enabled          = $query->param('service_active_checks_enabled');
	my $service_passive_checks_enabled         = $query->param('service_passive_checks_enabled');
	$use_hosts                              = '' if not defined $use_hosts;
	$inherit_host_active_checks_enabled     = '' if not defined $inherit_host_active_checks_enabled;
	$inherit_host_passive_checks_enabled    = '' if not defined $inherit_host_passive_checks_enabled;
	$inherit_service_active_checks_enabled  = '' if not defined $inherit_service_active_checks_enabled;
	$inherit_service_passive_checks_enabled = '' if not defined $inherit_service_passive_checks_enabled;
	$host_active_checks_enabled     = '-zero-' unless $host_active_checks_enabled;
	$host_passive_checks_enabled    = '-zero-' unless $host_passive_checks_enabled;
	$service_active_checks_enabled  = '-zero-' unless $service_active_checks_enabled;
	$service_passive_checks_enabled = '-zero-' unless $service_passive_checks_enabled;
	my $data .= qq(<?xml version="1.0" encoding="iso-8859-1" ?>
<data>
 <prop name="label_enabled"><![CDATA[$group{'label_enabled'}]]>
 </prop>
 <prop name="label"><![CDATA[$group{'label'}]]>
 </prop>
 <prop name="nagios_etc"><![CDATA[$nagios_etc]]>
 </prop>
 <prop name="use_hosts"><![CDATA[$use_hosts]]>
 </prop>
 <prop name="inherit_host_active_checks_enabled"><![CDATA[$inherit_host_active_checks_enabled]]>
 </prop>
 <prop name="inherit_host_passive_checks_enabled"><![CDATA[$inherit_host_passive_checks_enabled]]>
 </prop>
 <prop name="inherit_service_active_checks_enabled"><![CDATA[$inherit_service_active_checks_enabled]]>
 </prop>
 <prop name="inherit_service_passive_checks_enabled"><![CDATA[$inherit_service_passive_checks_enabled]]>
 </prop>
 <prop name="host_active_checks_enabled"><![CDATA[$host_active_checks_enabled]]>
 </prop>
 <prop name="host_passive_checks_enabled"><![CDATA[$host_passive_checks_enabled]]>
 </prop>
 <prop name="service_active_checks_enabled"><![CDATA[$service_active_checks_enabled]]>
 </prop>
 <prop name="service_passive_checks_enabled"><![CDATA[$service_passive_checks_enabled]]>
 </prop>
</data>);
	# FIX LATER:  If this error is triggered, we ought to ensure that any changed values the user specified
	# get re-established on the screen for further editing, preferably with this field presented using our
	# standard light-yellow error background, rather than just getting lost without notice.
	push @errors, 'Error:  a non-empty build folder must be specified as an absolute pathname.'
	  if defined $location && $location ne '' && $location !~ m{^/};
	unless (@errors) {
	    my %values = (
		'location'    => $location,
		'description' => $description,
		'status'      => $status,
		'data'        => $data
	    );
	    my $result = StorProc->update_obj( 'monarch_groups', 'name', $name, \%values );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	    my @contactgroups     = $query->$multi_param('contactgroups');
	    my %contactgroup_name = StorProc->get_table_objects('contactgroups');

	    $result = StorProc->delete_all( 'contactgroup_group', 'group_id', $group{'group_id'} );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	    foreach my $cg (@contactgroups) {
		## my @values = ($contactgroup_name{$cg},'monarch_group',$group{'group_id'});
		## my $result = StorProc->insert_obj('contactgroup_assign',\@values);
		my @values = ( $contactgroup_name{$cg}, $group{'group_id'} );
		my $result = StorProc->insert_obj( 'contactgroup_group', \@values );
		if ( $result =~ /^Error/ ) { push @errors, $result }
	    }
	}
	unless (@errors) { $obj_view = 'saved' }
    }
    elsif ( $query->param('set_values') ) {
	my %monarch_macros = StorProc->get_table_objects('monarch_macros');
	my $label_enabled  = 0;
	foreach my $qname ( $query->param ) {
	    if ( $qname =~ /label_enabled/ ) { $label_enabled = 1 }
	    if ( $qname =~ /value_(\S+)/ ) {
		my %where = (
		    'macro_id' => $monarch_macros{$1},
		    'group_id' => $group{'group_id'}
		);
		my $val    = $query->param($qname);
		my %values = ( 'value' => $val );
		my $result = StorProc->update_obj_where( 'monarch_group_macro', \%values, \%where );
		if ( $result =~ /^Error/ ) { push @errors, $result }
	    }
	}
	my $label = $query->param('label');
	my $data .= qq(<?xml version="1.0" encoding="iso-8859-1" ?>
<data>
 <prop name="label_enabled"><![CDATA[$label_enabled]]>
 </prop>
 <prop name="label"><![CDATA[$label]]>
 </prop>
 <prop name="nagios_etc"><![CDATA[$group{'nagios_etc'}]]>
 </prop>
 <prop name="use_hosts"><![CDATA[$group{'use_hosts'}]]>
 </prop>
 <prop name="inherit_host_active_checks_enabled"><![CDATA[$group{'inherit_host_active_checks_enabled'}]]>
 </prop>
 <prop name="inherit_host_passive_checks_enabled"><![CDATA[$group{'inherit_host_passive_checks_enabled'}]]>
 </prop>
 <prop name="inherit_service_active_checks_enabled"><![CDATA[$group{'inherit_service_active_checks_enabled'}]]>
 </prop>
 <prop name="inherit_service_passive_checks_enabled"><![CDATA[$group{'inherit_service_passive_checks_enabled'}]]>
 </prop>
 <prop name="host_active_checks_enabled"><![CDATA[$group{'host_active_checks_enabled'}]]>
 </prop>
 <prop name="host_passive_checks_enabled"><![CDATA[$group{'host_passive_checks_enabled'}]]>
 </prop>
 <prop name="service_active_checks_enabled"><![CDATA[$group{'service_active_checks_enabled'}]]>
 </prop>
 <prop name="service_passive_checks_enabled"><![CDATA[$group{'service_passive_checks_enabled'}]]>
 </prop>
</data>);
	my %values = ( 'data' => $data );
	my $result = StorProc->update_obj( 'monarch_groups', 'name', $name, \%values );
	if ( $result =~ /^Error/ ) { push @errors, $result }
	unless (@errors) {
	    $obj_view = 'saved';
	    $message  = "Macro values and settings updated.";
	}
    }
    elsif ( $query->param('add_macro') ) {
	my %macros         = StorProc->get_macros();
	my %monarch_macros = StorProc->get_table_objects('monarch_macros');
	my @macros         = $query->$multi_param('add_macro_checked');
	foreach my $macro (@macros) {
	    my @values = ( $group{'group_id'}, $macros{$macro}{'id'}, $macros{$macro}{'value'} );
	    my $result = StorProc->insert_obj( 'monarch_group_macro', \@values );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	}
    }
    elsif ( $query->param('remove_macro') ) {
	my %monarch_macros = StorProc->get_table_objects('monarch_macros');
	my @macros         = $query->$multi_param('rem_macro_checked');
	foreach my $macro (@macros) {
	    my %where = (
		'group_id' => $group{'group_id'},
		'macro_id' => $monarch_macros{$macro}
	    );
	    my $result = StorProc->delete_one_where( 'monarch_group_macro', \%where );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	}
    }
    elsif ( $query->param('add_group') ) {
	my %monarch_groups = StorProc->get_table_objects('monarch_groups');
	my @groups         = $query->$multi_param('add_group_checked');
	my %group_hosts    = ();
	my %host_group     = ();
	my @order          = ();
	my %group_child    = ();
	my %parents_all    = StorProc->get_group_parents_all();
	my %group_names    = StorProc->get_table_objects('monarch_groups');

	foreach my $group (@groups) {
	    my ( $group_hosts, $order ) =
	      StorProc->get_group_hosts( $group, \%parents_all, \%group_names, \%group_hosts, \@order, \%group_child );
	    @order = @{$order};
	    foreach my $group (@order) {
		my %where = (
		    'group_id' => $group{'group_id'},
		    'child_id' => $monarch_groups{$group}
		);
		my $result = StorProc->delete_one_where( 'monarch_group_child', \%where );
		if ( $result =~ /^Error/ ) { push @errors, $result }
	    }
	    my @values = ( $group{'group_id'}, $monarch_groups{$group} );
	    my $result = StorProc->insert_obj( 'monarch_group_child', \@values );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	}
    }
    elsif ( $query->param('remove_group') ) {
	my %monarch_groups = StorProc->get_table_objects('monarch_groups');
	my @children       = $query->$multi_param('rem_group_checked');
	foreach my $child (@children) {
	    my %where = (
		'group_id' => $group{'group_id'},
		'child_id' => $monarch_groups{$child}
	    );
	    my $result = StorProc->delete_one_where( 'monarch_group_child', \%where );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	}
    }
    elsif ( $query->param('add_host') ) {
	my %hosts = StorProc->get_table_objects('hosts');
	my @hosts = $query->$multi_param('add_host_checked');
	foreach my $host (@hosts) {
	    my @values = ( $group{'group_id'}, $hosts{$host} );
	    my $result = StorProc->insert_obj( 'monarch_group_host', \@values );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	}
    }
    elsif ( $query->param('add_hostgroup') ) {
	my %hostgroups = StorProc->get_table_objects('hostgroups');
	my @hostgroups = $query->$multi_param('add_hostgroup_checked');
	foreach my $hostgroup (@hostgroups) {
	    my @values = ( $group{'group_id'}, $hostgroups{$hostgroup} );
	    my $result = StorProc->insert_obj( 'monarch_group_hostgroup', \@values );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	}
    }
    elsif ( $query->param('remove_host') ) {
	my %hosts = StorProc->get_table_objects('hosts');
	my @hosts = $query->$multi_param('rem_host_checked');
	foreach my $host (@hosts) {
	    my %where = ( 'group_id' => $group{'group_id'}, 'host_id' => $hosts{$host} );
	    my $result = StorProc->delete_one_where( 'monarch_group_host', \%where );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	}
	my %hostgroups = StorProc->get_table_objects('hostgroups');
	my @hostgroups = $query->$multi_param('rem_hostgroup_checked');
	foreach my $hostgroup (@hostgroups) {
	    my %where = (
		'group_id'     => $group{'group_id'},
		'hostgroup_id' => $hostgroups{$hostgroup}
	    );
	    my $result = StorProc->delete_one_where( 'monarch_group_hostgroup', \%where );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	}
    }
    elsif ( $query->param('delete') || $query->param('confirm_delete') ) {
	if ( $query->param('yes') ) {
	    my $result = StorProc->delete_all( 'monarch_groups', 'group_id', $group{'group_id'} );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	    unless (@errors) {
		unless ($is_portal) {
		    my %where = (
			'object' => $group{'group_id'},
			'type'   => 'group_macro'
		    );
		    my $result = StorProc->delete_one_where( 'access_list', \%where );
		    if ( $result =~ /^Error/ ) { push @errors, $result }
		}
		$obj_view     = 'deleted';
		$refresh_left = 1;
	    }
	}
	elsif ( $query->param('no') ) {
	    $obj_view = 'detail';
	}
	else {
	    foreach my $name ( $query->param ) {
		unless ( $name eq 'nocache' ) {
		    $hidden{$name} = $query->param($name);
		}
	    }
	    $obj_view = 'delete';
	}
    }
    my %docs   = Doc->monarch_groups();
    my %save   = ( 'name' => 'save', 'value' => 'Save' );
    my %apply  = ( 'name' => 'apply', 'value' => 'Apply' );
    my %export = ( 'name' => 'export', 'value' => 'Export' );
    my %obj    = ();
    $form .= Forms->header( $page_title, $session_id, $top_menu, '', $refresh_left );
    if ( $obj_view eq 'detail' ) {
	$hidden{'obj_view'} = 'detail';
	$form .= Forms->group_top( $name, 'detail' );
	if (@errors) { $form .= Forms->form_errors( \@errors ) }
	$form .= Forms->text_box( 'Description:', 'description', $group{'description'}, $textsize{'description'},
	    '', $docs{'description'}, '', $tab++ );
	my @members = StorProc->get_contactgroups( 'monarch_group', $group{'group_id'} );
	my @nonmembers = StorProc->fetch_list( 'contactgroups', 'name' );
	$form .= Forms->group_main( \%group, \%docs, \@members, \@nonmembers, $tab++ );
	$form .= Forms->hidden( \%hidden );
	$help{url} = StorProc->doc_section_url('How+to+define+groups', 'Howtodefinegroups-ManageGroupDetail');
	$form .= Forms->form_bottom_buttons( \%save, \%delete, \%rename, \%close, \%help, $tab++ );
    }
    elsif ( $obj_view eq 'macros' ) {
	$hidden{'obj_view'} = 'macros';
	$form .= Forms->group_top( $name, 'macros' );
	if (@errors) { $form .= Forms->form_errors( \@errors ) }
	$form .= Forms->wizard_doc( 'Group macros', $docs{'macros'}, undef, 1 );
	my %macros       = StorProc->get_macros();
	my %group_macros = StorProc->get_group_macros( $group{'group_id'} );
	foreach my $macro ( keys %macros ) {
	    if ( $group_macros{$macro} ) { delete $macros{$macro} }
	}
	$form .= Forms->group_macros( \%macros, \%group_macros, $group{'label_enabled'}, $group{'label'} );
	$form .= Forms->hidden( \%hidden );
	$form .= Forms->form_bottom_buttons();
    }
    elsif ( $obj_view eq 'hosts' ) {
	$hidden{'obj_view'} = 'hosts';
	$form .= Forms->group_top( $name, 'hosts' );
	if (@errors) { $form .= Forms->form_errors( \@errors ) }
	$form .= Forms->wizard_doc( 'Host Assignment', $docs{'assign_hosts'}, undef, 1 );
	my ( $nonmembers, $members ) = StorProc->get_group_hosts_old( $group{'group_id'} );
	my %nonmembers = %{$nonmembers};
	my %members    = %{$members};
	my ( $hostgroup_nonmembers, $hostgroup_members ) = StorProc->get_hostgroups_hosts( $group{'group_id'} );
	my %hostgroup_nonmembers = %{$hostgroup_nonmembers};
	my %hostgroup_members    = %{$hostgroup_members};
	my $help_url = StorProc->doc_section_url('How+to+define+groups', 'Howtodefinegroups-ManageGroupHostAssignment');
	$form .= Forms->group_hosts( \%members, \%nonmembers, \%hostgroup_members, \%hostgroup_nonmembers, $help_url );
	$form .= Forms->hidden( \%hidden );
	$form .= Forms->form_bottom_buttons();
    }
    elsif ( $obj_view eq 'sub_groups' ) {
	$hidden{'obj_view'} = 'sub_groups';
	$form .= Forms->group_top( $name, 'sub_groups' );
	if (@errors) { $form .= Forms->form_errors( \@errors ) }
	$form .= Forms->wizard_doc( 'Sub Groups', $docs{'sub_groups'}, undef, 1 );
	my %parents_all = StorProc->get_group_parents_all();
	my %group_names = StorProc->get_table_objects('monarch_groups');
	my %group_hosts = ();
	my @order       = ();
	my %group_child = ();
	my %nonmembers  = StorProc->get_possible_groups( $group{'name'} );
	my ( $group_hosts, $order, $group_child ) =
	  StorProc->get_group_hosts( $group{'name'}, \%parents_all, \%group_names, \%group_hosts, \@order, \%group_child );
	%group_hosts = %{$group_hosts};
	@order       = @{$order};
	%group_child = %{$group_child};
	my $help_url = StorProc->doc_section_url('How+to+define+groups', 'Howtodefinegroups-ManageGroupsSubGroups');
	$form .= Forms->group_children( \%group_hosts, \@order, \%group_child, \%nonmembers, $help_url );
	$form .= Forms->hidden( \%hidden );
	$form .= Forms->form_bottom_buttons();
    }
    elsif ( $obj_view eq 'new' ) {
	$form .= Forms->form_top( 'New Monarch Group', Validation->dfv_onsubmit_javascript(), '' );
	if (@errors) { $form .= Forms->form_errors( \@errors ) }
	$form .= Forms->text_box( 'Monarch group name:', 'name', $name, $textsize{'name'}, '', $docs{'name'}, '', $tab++ );
	$form .= Forms->hidden( \%hidden );
	$help{url} = StorProc->doc_section_url('How+to+define+groups');
	$form .= Forms->form_bottom_buttons( \%add, \%cancel, \%help, $tab++ );
    }
    elsif ( $obj_view eq 'nagios_cgi' ) {
	$hidden{'obj_view'} = 'nagios_cgi';
	$hidden{'name'}     = $name;
	my $step = $query->param('step');
	if ( $query->param('next') ) { $step++ }
	if ( $query->param('back') ) { $step-- }
	$form .= nagios_cgi( $group{'group_id'}, $name );
    }
    elsif ( $obj_view eq 'nagios_cfg' or defined $nagios_options_step{$obj_view} ) {
	$hidden{'obj_view'} = 'nagios_cfg';
	$hidden{'name'}     = $name;
	my $step = $query->param('step');
	if ( $query->param('next') ) { $step++ }
	if ( $query->param('back') ) { $step-- }
	$query->param( -name => 'step', -value => $nagios_options_step{$obj_view} );
	$form .= nagios_cfg( $group{'group_id'}, $name );
    }
    elsif ( $obj_view eq 'resource_cfg' ) {
	$hidden{'obj_view'} = 'resource_cfg';
	$hidden{'name'}     = $name;
	$form .= resource_cfg( $group{'group_id'}, $name );
    }
    elsif ( $obj_view eq 'pre_flight_test' ) {
	$hidden{'obj_view'} = 'pre_flight_test';
	$form .= pre_flight($name);
    }
    elsif ( $obj_view eq 'build_instance' ) {
	if (1) {
	    $hidden{'obj_view'} = 'build_instance';
	    $form .= build_instance($name, $group{'location'}, $group{'nagios_etc'});
	}
	else {
	    ## FIX MAJOR:  Older, now-obsolete code.  Should be deleted.
	    require MonarchFile;
	    my ( $files, $errors ) = Files->build_files( $user_acct, $name, 'commit', '', $nagios_ver, $nagios_etc, '', '1', '1' );
	    my @errors = @{$errors};
	    my @files  = @{$files};
	    if (@errors) {
		$form .= Forms->form_top( 'Build Instance', '', '' );
		$form .= Forms->display_hidden( 'Monarch group name:', 'name', $name );
		$form .= Forms->form_errors( \@errors );
		$form .= Forms->hidden( \%hidden );
		$form .= Forms->form_bottom_buttons( \%continue, $tab++ );
	    }
	    else {
		my @results = ("Files for the \"$name\" build were generated in $group{'location'} .");
		use MonarchDeploy;
		push( @results, Deploy->deploy( $name, $group{'location'}, $group{'nagios_etc'}, $monarch_home ) );
		$form .= Forms->form_top( 'Build Instance', '', '' );
		$form .= Forms->display_hidden( 'Monarch group name:', 'name', $name );
		$form .= Forms->form_message( 'Status', \@results, 'row1', 1 );
		$form .= Forms->hidden( \%hidden );
		$form .= Forms->form_bottom_buttons( \%continue, $tab++ );
	    }
	}
    }
    elsif ( $obj_view eq 'export' ) {
	## FIX MAJOR:  drop the old code here, once this new form is shown to work
	if (1) {
	    $hidden{'obj_view'} = 'export';
	    $form .= exported_files($name, $nagios_etc);
	}
	else {
	    require MonarchFile;
	    my ( $files, $errors ) =
	      Files->build_files( $user_acct, $name, 'commit', '1', $nagios_ver, $nagios_etc, "$doc_root/monarch/download", '1' );
	    my @errors = @{$errors};
	    my @files  = @{$files};
	    if (@errors) {
		$form .= Forms->form_top( 'Export Instance', '', '' );
		$form .= Forms->display_hidden( 'Monarch group name:', 'name', $name );
		$form .= Forms->form_errors( \@errors );
		$form .= Forms->hidden( \%hidden );
		$form .= Forms->form_bottom_buttons( \%continue, $tab++ );
	    }
	    else {
		my $tarball = pop @files;
		my @list    = ($tarball);
		unshift @list, pop @files if $tarball !~ /.tar$/;  # maybe last file was an audit file instead
		@files = sort @files;
		push( @list, @files );
		my $server = $ENV{'SERVER_NAME'};
		$form .= Forms->header( $page_title, $session_id, $top_menu );
		$form .= Forms->group_top( $name, '' );
		$form .= Forms->table_download_links( "$doc_root/monarch/download", \@list, $server );
		$help{url} = StorProc->doc_section_url('How+to+import+and+export+Nagios+files', 'HowtoimportandexportNagiosfiles-ExporttoFiles');
		$form .= Forms->hidden( \%hidden );
		$form .= Forms->form_bottom_buttons( \%help, $tab++ );
	    }
	}
    }
    elsif ( $obj_view eq 'delete' ) {
	$form .= Forms->header( $page_title, $session_id, $top_menu );
	$form .= Forms->form_top( 'Groups', '', '' );
	$form .= Forms->wizard_doc( 'Remove group?', $name, undef, 1 );
	$form .= Forms->hidden( \%hidden );
	$form .= Forms->form_bottom_buttons( \%yes, \%no, $tab++ );
    }
    elsif ( $obj_view eq 'rename' ) {
	$form .= Forms->form_top( 'Rename Group', Validation->dfv_onsubmit_javascript(), '' );
	if (@errors) { $form .= Forms->form_errors( \@errors ) }
	$form .= Forms->display_hidden( 'Monarch group name:', 'name', $name );
	$form .= Forms->text_box( 'Rename to:', 'new_name', '', $textsize{'name'}, '', '', '', $tab++ );
	$form .= Forms->hidden( \%hidden );
	$form .= Forms->form_bottom_buttons( \%rename, \%cancel, $tab++ );
    }
    elsif ( $obj_view eq 'saved' ) {
	$form .= Forms->group_top( $name, '' );
	$form .= Forms->display_hidden( 'Saved:', '', $message );
	$form .= Forms->hidden( \%hidden );
	$form .= Forms->form_bottom_buttons( \%close, $tab++ );
    }
    return $form;
}

#
############################################################################
# Build instances
#

# FIX LATER:  This code construction works, but perhaps would be better constructed
# as an Ajax-enabled application, so progress is reported to the user as it occurs.
sub build_instances() {
    my $obj_view   = $query->param('obj_view');
    my $form       = undef;
    my $build_form = undef;
    @errors = ();
    my %groups              = ();
    my %full_monarch_groups = StorProc->fetch_all('monarch_groups');
    if ( defined( $full_monarch_groups{'error'} ) && $full_monarch_groups{'error'} =~ /^Error/ ) {
	push @errors, $full_monarch_groups{'error'};
	delete $full_monarch_groups{'error'};
    }
    else {
	foreach my $group_id ( keys %full_monarch_groups ) {
	    $groups{ $full_monarch_groups{$group_id}[1] } = $full_monarch_groups{$group_id}[2];
	}
    }

    if ( $query->param('build') || $query->param('preflight') || $query->param('deploy') ) {
	my @groups = $query->$multi_param('group');
	if ( scalar @groups == 0 ) {
	    push @errors, 'You have not selected any groups for which to build instances.';
	}
	else {
	    ## attempt to build instances for all the selected groups, and to collect errors for them
	    my %have_group = ();
	    foreach my $group_name (@groups) {
		$have_group{$group_name} = 1;
	    }
	    my %group_props = ();
	    foreach my $group_id ( keys %full_monarch_groups ) {
		my $group_name = $full_monarch_groups{$group_id}[1];
		if ( $have_group{$group_name} ) {
		    $group_props{$group_name}{'location'} = $full_monarch_groups{$group_id}[3];
		    my %group_data = StorProc->parse_xml( $full_monarch_groups{$group_id}[5] );
		    $group_props{$group_name}{'nagios_etc'} = $group_data{'nagios_etc'};
		}
	    }
	    my $file_errors = 0;
	    foreach my $group_name ( sort keys %group_props ) {
		require MonarchFile;
		my $files;
		my $errors;
		## FIX THIS:  account for all cases when building files:  build, preflight, deploy
		## if ( $query->param('deploy') ) {
		    ( $files, $errors ) =
		      Files->build_files( $user_acct, $group_name, 'commit', '', $nagios_ver, $nagios_etc, '', '1', '1' );
		## }
		## else {
		    ## FIX THIS:  validate that all the arguments here are correct, and validate that
		    ## this generation of files will be used during a subsequent pre-flight operation
		    ## ( $files, $errors ) =
		      ## Files->build_files( $user_acct, $group_name, 'preflight', '', $nagios_ver, $nagios_etc, "$monarch_home/workspace", '' );
		## }
		my @file_errors = @{$errors};
		if (@file_errors) {
		    $build_form .= Forms->wizard_doc("Monarch group:&nbsp; $group_name", undef, undef, 1);
		    $build_form .= Forms->form_errors( \@file_errors );
		    $file_errors = 1;
		}
	    }
	    if ($file_errors) {
		## FIX THIS:  test this:  where will the detailed errors show up?
		if ( $query->param('deploy') ) {
		    push @errors, 'Deploying will not be attempted due to the build errors below.';
		}
		elsif ( $query->param('preflight') ) {
		    push @errors, 'Preflight will not be attempted due to the build errors below.';
		}
		else {
		    push @errors, 'Build errors occurred; see below.';
		}
	    }
	    else {
		## FIX THIS:  perhaps stop the deploying of additional groups if we can detect errors along the way
		foreach my $group_name ( sort keys %group_props ) {
		    my @results = ("Files for the \"$group_name\" build were generated in $group_props{$group_name}{'location'} .");
		    if ( $query->param('preflight') ) {
			## FIX THIS:  run a pre-flight operation, but don't re-build the files as part of this action;
			## work out how that affects our need to synchronize with other pre-flights, commits, and feeders
			## FIX THIS:  fit the form-building cleanly into the on-screen output
			## $build_form .= pre_flight($name);
		    }
		    if ( $query->param('deploy') ) {
			use MonarchDeploy;
			push(
			    @results,
			    Deploy->deploy(
				$group_name,
				$group_props{$group_name}{'location'},
				$group_props{$group_name}{'nagios_etc'},
				$monarch_home
			    )
			);
		    }
		    $build_form .= Forms->wizard_doc("Monarch group:&nbsp; $group_name", undef, undef, 1);
		    $build_form .= Forms->form_message( 'Status', \@results, 'row1', 1 );
		}
	    }
	    $obj_view = 'build';
	}
    }
    elsif ( $query->param('close') || $query->param('continue') ) {
	$form .= Forms->header( $page_title, $session_id, $top_menu );
	$obj_view = 'close';
    }
    $form .= Forms->header( $page_title, $session_id, $top_menu, '', $refresh_left );
    if ( defined($obj_view) && $obj_view eq 'build' ) {
	$form .= Forms->form_top( 'Build Instances', '', '' );
	if (@errors) { $form .= Forms->form_message( '', \@errors, 'error' ) }
	if ($build_form) { $form .= $build_form }
	$form .= Forms->hidden( \%hidden );
	$form .= Forms->form_bottom_buttons( \%close, $tab++ );
    }
    elsif ( !defined($obj_view) || $obj_view ne 'close' ) {
	$form .= Forms->form_top( 'Build Instances', '', '' );
	if (@errors) { $form .= Forms->form_errors( \@errors ) }
	$form .= Forms->form_groups( \%groups, $tab++ );
	$form .= Forms->hidden( \%hidden );
	my %build     = ( 'name' => 'build',     'value' => 'Build' );
	my %preflight = ( 'name' => 'preflight', 'value' => 'Build and Pre-Flight' );
	my %deploy    = ( 'name' => 'deploy',    'value' => 'Build and Deploy' );
	if ( scalar keys %groups ) {
	    ## FIX LATER:  put back the pre-flight option, when we have it working
	    ## $form .= Forms->form_bottom_buttons( \%build, \%preflight, \%deploy, \%close, $tab++ );
	    $form .= Forms->form_bottom_buttons( \%build, \%deploy, \%close, $tab++ );
	}
	else {
	    $form .= Forms->form_bottom_buttons( \%close, $tab++ );
	}
    }
    return $form;
}

#
############################################################################
# Macros
#

sub macros() {
    my $form          = undef;
    my $name          = $query->param('name');
    my $rename_macro  = undef;
    my $saved         = undef;
    my $are_you_sure  = undef;
    my %save_macros   = ();
    my @remove_macros = ();
    foreach my $qname ( $query->param ) {
	if ( $qname =~ /rename_(\S+)/ ) {
	    $rename_macro = 1;
	    $name         = $1;
	}
	elsif ( $qname =~ /remove_(\S+)/ ) {
	    push @remove_macros, $1;
	}
	elsif ( $qname =~ /value_(\S+)/ ) {
	    $save_macros{$1}{'value'} = $query->param($qname);
	}
	elsif ( $qname =~ /description_(\S+)/ ) {
	    $save_macros{$1}{'description'} = $query->param($qname);
	}
    }
    if ( $query->param('add') ) {
	$name =~ s/^\s+|\s+$//g;
	my %macro = StorProc->fetch_one( 'monarch_macros', 'name', $name );
	if ( $name =~ /\s|\$|!/ ) {
	    push @errors, "Check the new macro name (name = \"$name\"). Macro names cannot contain illegal characters.";
	}
	elsif ( $name && (!defined( $macro{'name'} ) || $macro{'name'} ne $name) ) {
	    my $description = $query->param('description');
	    my $value       = $query->param('value');
	    my @values      = ( \undef, $name, $value, $description );
	    my $result      = StorProc->insert_obj( 'monarch_macros', \@values );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	}
	else {
	    push @errors, "Check the new macro name (name = \"$name\"). It is either blank or this macro already exists.";
	}
    }
    elsif ( $query->param('save') ) {
	foreach my $macro ( keys %save_macros ) {
	    my %values = (
		'description' => $save_macros{$macro}{'description'},
		'value'       => $save_macros{$macro}{'value'}
	    );
	    my $result = StorProc->update_obj( 'monarch_macros', 'name', $macro, \%values );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	}
	unless (@errors) { $saved = "All changes accepted." }
    }
    elsif ( $query->param('rename') ) {
	$rename_macro = 1;
	my $new_name = $query->param('new_name');
	$new_name =~ s/^\s+|\s+$//g;
	my %macro = StorProc->fetch_one( 'monarch_macros', 'name', $new_name );
	if ( $new_name =~ /\s|\$|!/ ) {
	    push @errors, "Check the new macro name (name = \"$new_name\"). Macro names cannot contain illegal characters.";
	}
	elsif ( $new_name && !$macro{'name'} ) {
	    my %values = ( 'name' => $new_name );
	    my $result = StorProc->update_obj( 'monarch_macros', 'name', $name, \%values );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	}
	else {
	    push @errors, "Check the new macro name (name = \"$new_name\"). It is either blank or this macro already exixts.";
	}
	unless (@errors) { $rename_macro = undef }
    }
    elsif ( $query->param('remove') || $query->param('are_you_sure') ) {
	unless ( $query->param('no') ) {
	    if ( $query->param('yes') ) {
		foreach my $macro (@remove_macros) {
		    my $result = StorProc->delete_all( 'monarch_macros', 'name', $macro );
		    if ( $result =~ /^Error/ ) { push @errors, $result }
		}

	    }
	    else {
		$hidden{'remove'} = 1;
		my @checked = $query->$multi_param('macro_checked');
		$are_you_sure = "Are you sure you want to remove the following macros from all groups and service checks?";
		foreach my $macro (@checked) {
		    $hidden{"remove_$macro"} = 1;
		    $are_you_sure .= "<br>$macro";
		}
	    }
	}
    }
    if ( $query->param('close') || $query->param('continue') ) {
	$form .= Forms->header( $page_title, $session_id, $top_menu );
    }
    elsif ($rename_macro) {
	$form .= Forms->header( $page_title, $session_id, $top_menu );
	$form .= Forms->form_top( 'Rename Macro', Validation->dfv_onsubmit_javascript(), '' );
	if (@errors) { $form .= Forms->form_errors( \@errors ) }
	$form .= Forms->display_hidden( 'Macro name:', 'name', $name );
	$form .= Forms->text_box( 'Rename to:', 'new_name', '', $textsize{'name'}, '', '', '', $tab++ );
	$form .= Forms->hidden( \%hidden );
	$form .= Forms->form_bottom_buttons( \%rename, \%cancel, $tab++ );
    }
    elsif ($are_you_sure) {
	$form .= Forms->header( $page_title, $session_id, $top_menu );
	$form .= Forms->form_top( 'Macros', '', '' );
	$form .= Forms->wizard_doc( 'Remove macros', $are_you_sure, undef, 1 );
	$form .= Forms->hidden( \%hidden );
	$form .= Forms->form_bottom_buttons( \%yes, \%no, $tab++ );
    }
    elsif ($saved) {
	$form .= Forms->header( $page_title, $session_id, $top_menu );
	$form .= Forms->form_top( 'Macros', '', '' );
	$form .= Forms->display_hidden( 'Saved:', '', $saved );
	$form .= Forms->hidden( \%hidden );
	$form .= Forms->form_bottom_buttons( \%continue, $tab++ );
    }
    else {
	my %docs = Doc->monarch_macros();
	$form .= Forms->header( $page_title, $session_id, $top_menu );
	$form .= Forms->form_top( 'Macros', '', '' );
	if (@errors) { $form .= Forms->form_errors( \@errors ) }
	$form .= Forms->wizard_doc( 'Group macros', $docs{'macros'}, undef, 1 );
	my %macros = StorProc->get_macros();
	$form .= Forms->macros( \%macros, $tab++ );
	$form .= Forms->hidden( \%hidden );
	$help{url} = StorProc->doc_section_url('How+to+define+groups', 'Howtodefinegroups-ManageGroupsMacros');
	$form .= Forms->form_bottom_buttons( \%save, \%remove, \%close, \%help, $tab++ );
    }
    return $form;
}

#
############################################################################
# Nagios cgi
#

sub nagios_cgi($$) {
    my $gid     = shift;
    my $gname   = shift;
    my %checks  = ();
    my %objects = ();
    my $step    = $query->param('step');
    if (defined $step) {
	if ( $step eq '1' ) {
	    %checks = ( 'show_context_help' => '0' );
	}
	elsif ( $step eq '2' ) {
	    %checks = (
		'use_authentication' => '0',
		'lock_author_names'  => '0'
	    );
	}
    }
    my %layout_val = (
	'User-defined coordinates' => '-zero-',
	'Depth layers'             => '1',
	'Collapsed tree'           => '2',
	'Balanced tree'            => '3',
	'Circular'                 => '4',
	'Circular (Marked Up)'     => '5',
	'Circular (Balloon)'       => '6'
    );
    my %val_layout = (
	'-zero-' => 'User-defined coordinates',
	'1'      => 'Depth layers',
	'2'      => 'Collapsed tree',
	'3'      => 'Balanced tree',
	'4'      => 'Circular',
	'5'      => 'Circular (Marked Up)',
	'6'      => 'Circular (Balloon)'
    );
    my %integer = ( 'refresh_rate' => 1, 'result_limit' => 1 );
    if ( $query->param('next') ) {
	my %nagios_set = ();
	if ($gid) {
	    my %where = ( 'group_id' => $gid, 'name' => 'physical_html_path' );
	    %nagios_set = StorProc->fetch_one_where( 'monarch_group_props', \%where );
	}
	else {
	    %nagios_set = StorProc->fetch_one( 'setup', 'name', 'physical_html_path' );
	}
	if ( $nagios_set{'name'} ) {
	    my %nag_defined = ();
	    if ($gid) {
		## GWMON-4818:  monarch_group_props contains duplicate entries for nagios_cgi and nagios_cfg per group.
		## Need to loop through hash of table contents to eliminate duplicate entries.
		my %unique_props    = ();
		my %where           = ( 'group_id' => $gid, 'type' => 'nagios_cgi' );
		my %group_prop_hash = StorProc->fetch_list_hash_array( 'monarch_group_props', \%where );

		# process the id's in decending order to keep the latest values saved
		my @keys = keys %group_prop_hash;
		foreach my $id ( sort { $b <=> $a } @keys ) {
		    if ( $unique_props{ $group_prop_hash{$id}[2] } ) {
			%where = ( 'prop_id' => $id );
			my $res = StorProc->delete_one_where( 'monarch_group_props', \%where );
		    }
		    else {
			$unique_props{ $group_prop_hash{$id}[2] } = 1;
			$nag_defined{ $group_prop_hash{$id}[2] }  = 1;
		    }
		}
	    }
	    else {
		my %where = ( 'type' => 'nagios_cgi' );
		%nag_defined = StorProc->fetch_list_hash_array( 'setup', \%where );
	    }
	    foreach my $name ( $query->param ) {
		unless ( $name =~ /^next$|user_acct|^obj$|^nocache$|^step$|^top_menu$|^update_main$|^view$/ ) {
		    my $val = undef;
		    if ( $name =~ /layout/ ) {
			$val = $query->param($name);
			$val = $layout_val{$val};
		    }
		    elsif ( defined $checks{$name} ) {
			$checks{$name} = '1';
		    }
		    else {
			$val = $query->param($name);
			$val =~ s/^\s+//;
			$val =~ s/\s+$//;
			if ($integer{$name} && $val !~ /^\d*$/) {
			    (my $label = "\u$name") =~ s/_/ /g;
			    push @errors, "Error:  The \"$label\" value must be a simple integer or blank.";
			}
			if ( $val eq '0' ) { $val = $DEFINED_REF; }
		    }
		    if ($gid) {
			if ( $nag_defined{$name} ) {
			    my %where = (
				'group_id' => $gid,
				'type'     => 'nagios_cgi',
				'name'     => $name
			    );
			    my %values = ( 'value' => $val );
			    my $result = StorProc->update_obj_where( 'monarch_group_props', \%values, \%where );
			    if ( $result =~ /^Error/ ) { push @errors, $result }
			}
			else {
			    my @values = ( \undef, $gid, $name, 'nagios_cgi', $val );
			    my $result = StorProc->insert_obj( 'monarch_group_props', \@values );
			    if ( $result =~ /^Error/ ) { push @errors, $result }
			}
		    }
		    else {
			if ( $nag_defined{$name} ) {
			    my %values = ( 'value' => $val );
			    my $result = StorProc->update_obj( 'setup', 'name', $name, \%values );
			    if ( $result =~ /^Error/ ) { push @errors, $result }
			}
			else {
			    my @values = ( $name, 'nagios_cgi', $val );
			    my $result = StorProc->insert_obj( 'setup', \@values );
			    if ( $result =~ /^Error/ ) { push @errors, $result }
			}
		    }
		}
	    }

	    foreach my $name ( keys %checks ) {
		if ($gid) {
		    if ( $nag_defined{$name} ) {
			my %where = (
			    'group_id' => $gid,
			    'type'     => 'nagios_cgi',
			    'name'     => $name
			);
			my %values = ( 'value' => $checks{$name} );
			my $result = StorProc->update_obj_where( 'monarch_group_props', \%values, \%where );
			if ( $result =~ /^Error/ ) { push @errors, $result }
		    }
		    else {
			my @values = ( \undef, $gid, $name, 'nagios_cgi', $checks{$name} );
			my $result = StorProc->insert_obj( 'monarch_group_props', \@values );
			if ( $result =~ /^Error/ ) { push @errors, $result }
		    }
		}
		else {
		    if ( $nag_defined{$name} ) {
			my %values = ( 'value' => $checks{$name} );
			my $result = StorProc->update_obj( 'setup', 'name', $name, \%values );
			if ( $result =~ /^Error/ ) { push @errors, $result }
		    }
		    else {
			my @values = ( $name, 'nagios_cgi', $checks{$name} );
			my $result = StorProc->insert_obj( 'setup', \@values );
			if ( $result =~ /^Error/ ) { push @errors, $result }
		    }
		}
	    }
	}
	else {
	    my %cgi_defaults = StorProc->cgi_defaults($nagios_ver);
	    foreach my $name ( keys %cgi_defaults ) {
		if ($gid) {
		    my @values = ( \undef, $gid, $name, 'nagios_cgi', $cgi_defaults{$name} );
		    my $result = StorProc->insert_obj( 'monarch_group_props', \@values );
		    if ( $result =~ /^Error/ ) { push @errors, $result }
		}
		else {
		    my @values = ( $name, 'nagios_cgi', $cgi_defaults{$name} );
		    my $result = StorProc->insert_obj( 'setup', \@values );
		    if ( $result =~ /^Error/ ) { push @errors, $result }
		}
	    }
	    $step = 0;
	}
	unless (@errors) {
	    if ( $step eq '0' ) {
		$step = 1;
	    }
	    elsif ( $step eq '1' ) {
		$step = 2;
	    }
	    elsif ( $step eq '2' ) {
		$step = 'saved';
	    }
	}
    }
    elsif ( $query->param('back') ) {
	$step = $step - 1;
    }
    elsif ( $query->param('sync') ) {
	my %where = ( 'type' => 'nagios_cgi' );
	my %main_object = StorProc->fetch_list_hash_array( 'setup', \%where );
	%where = ( 'group_id' => $gid, 'type' => 'nagios_cgi' );
	my $result = StorProc->delete_one_where( 'monarch_group_props', \%where );
	if ( $result =~ /^Error/ ) { push @errors, $result }
	foreach my $object ( keys %main_object ) {
	    my @vals = ( \undef, $gid, $main_object{$object}[0], 'nagios_cgi', $main_object{$object}[2] );
	    my $result = StorProc->insert_obj( 'monarch_group_props', \@vals );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	}
    }
    elsif ( $query->param('set_defaults') ) {
	my %cgi_defaults = StorProc->cgi_defaults($nagios_ver);
	if ($gid) {
	    my %where = ( 'group_id' => $gid, 'type' => 'nagios_cgi' );
	    my $result = StorProc->delete_one_where( 'monarch_group_props', \%where );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	}
	else {
	    my $result = StorProc->delete_all( 'setup', 'type', 'nagios_cgi' );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	}
	foreach my $name ( keys %cgi_defaults ) {
	    if ($gid) {
		my @vals = ( \undef, $gid, $name, 'nagios_cgi', $cgi_defaults{$name} );
		my $result = StorProc->insert_obj( 'monarch_group_props', \@vals );
		if ( $result =~ /^Error/ ) { push @errors, $result }
	    }
	    else {
		my @values = ( $name, 'nagios_cgi', $cgi_defaults{$name} );
		my $result = StorProc->insert_obj( 'setup', \@values );
		if ( $result =~ /^Error/ ) { push @errors, $result }
	    }
	}
	$step = 1;
    }
    elsif ( $query->param('upload') ) {
	$step = 'upload';
	my $file = $query->param('upload_file');
	if ( $file =~ /cgi\.cfg/ ) {
	    my ($filedata, $errs) = StorProc->upload( '/tmp', $file );
	    my @errs = @$errs;
	    if (@errs) { push @errors, @errs }
	    unless (@errors) {
		my @errs = StorProc->import_nagios_cgi($gid, $file, $filedata, 1);
		if (@errs) { push( @errors, @errs ) }
		$step = 1;
	    }
	}
	elsif ($file) {
	    push @errors, "Invalid file type \"$file\". Filename must contain \"cgi.cfg\".";
	}
    }
    elsif ( $query->param('load_nagios_cgi') ) {
	@errors = StorProc->load_nagios_cgi( $nagios_etc, $nagios_ver );
	$step   = 1;
    }
    elsif ( defined($task) && $task eq 'view_edit' ) {
	$step = 1;
    }
    %next = ( 'name' => 'next', 'value' => 'Save and Next >>' );

    if ($gid) {
	%objects = StorProc->get_group_cgi($gid);
    }
    else {
	my %where = ( 'type' => 'nagios_cgi' );
	%objects = StorProc->fetch_list_hash_array( 'setup', \%where );
    }

    my %docs = Doc->cgi_cfg();
    my $page = undef;
    my $form_title = 'Nagios CGI Configuration';
    if ($gid) { $form_title = "$gname Nagios CGI Configuration" }
    unless ($step) { $step = 1 }

    if ( $step eq '1' ) {
	$hidden{'step'} = 1;
	$page .= Forms->header( $page_title, $session_id, $top_menu );
	$page .= Forms->form_top( "$form_title Page 1", '' );
	if (@errors) { $page .= Forms->form_errors( \@errors ) }

	$page .= Forms->wizard_doc( 'CGI Internal Operations Options', $docs{'cgi_internal_operations_options'}, undef, 1 );
	$page .= Forms->text_box(
	    'Physical HTML path:',
	    'physical_html_path', $objects{'physical_html_path'}[2],
	    $textsize{'long_name'}, '', $docs{'physical_html_path'},
	    '', $tab++, 1
	);
	$page .= Forms->text_box(
	    'URL HTML path:',
	    'url_html_path', $objects{'url_html_path'}[2],
	    $textsize{'long_name'}, '', $docs{'url_html_path'}, '', $tab++, 1
	);
	if ( $nagios_ver eq '1.x' ) {
	    $page .= Forms->text_box(
		'Nagios process check command:',
		'nagios_check_command', $objects{'nagios_check_command'}[2],
		$textsize{'long_name'}, '', $docs{'nagios_check_command'},
		'', $tab++, 1
	    );
	}
	$page .= Forms->text_box( 'Ping syntax:', 'ping_syntax', $objects{'ping_syntax'}[2],
	    $textsize{'long_name'}, '', $docs{'ping_syntax'}, '', $tab++, 1 );
	$page .= Forms->text_box( 'Refresh rate:', 'refresh_rate', $objects{'refresh_rate'}[2], '7', '', $docs{'refresh_rate'}, '', $tab++, 1 );

	$page .= Forms->wizard_doc( 'CGI Content Options', $docs{'cgi_content_options'}, undef, 1 );
	$page .= Forms->checkbox(
	    'Context sensitive help:',
	    'show_context_help',
	    $objects{'show_context_help'}[2],
	    $docs{'show_context_help'},
	    '', $tab++, 1
	);
	$page .= Forms->text_box(
	    'Statusmap background image:',
	    'statusmap_background_image', $objects{'statusmap_background_image'}[2],
	    $textsize{'long_name'}, '', $docs{'statusmap_background_image'},
	    '', $tab++, 1
	);
	my @options = (
	    'User-defined coordinates',
	    'Depth layers',
	    'Collapsed tree',
	    'Balanced tree',
	    'Circular',
	    'Circular (Marked Up)',
	    'Circular (Balloon)'
	);
	$objects{'default_statusmap_layout'}[2] =
	  defined( $objects{'default_statusmap_layout'}[2] ) ? $val_layout{ $objects{'default_statusmap_layout'}[2] } : undef;
	$page .= Forms->list_box(
	    'Default statusmap layout:',
	    'default_statusmap_layout', \@options, $objects{'default_statusmap_layout'}[2],
	    '', $docs{'default_statusmap_layout'},
	    '', $tab++, 1
	);
	@options = ( 'User-defined coordinates', 'Collapsed tree', 'Balanced tree', 'Circular' );
	$objects{'default_statuswrl_layout'}[2] =
	  defined( $objects{'default_statuswrl_layout'}[2] ) ? $val_layout{ $objects{'default_statuswrl_layout'}[2] } : undef;
	$page .= Forms->list_box(
	    'Default statuswrl layout:',
	    'default_statuswrl_layout', \@options, $objects{'default_statuswrl_layout'}[2],
	    '', $docs{'default_statuswrl_layout'},
	    '', $tab++, 1
	);
	$page .= Forms->text_box(
	    'Status wrl include:',
	    'statuswrl_include', $objects{'statuswrl_include'}[2],
	    $textsize{'long_name'}, '', $docs{'statuswrl_include'},
	    '', $tab++, 1
	);
	$page .= Forms->text_box( 'Result limit:', 'result_limit', $objects{'result_limit'}[2], '7', '', $docs{'result_limit'}, '', $tab++, 1 );
	## FIX LATER:  The following options should really only apply to Nagios 4.3.X and later.
	if ( $nagios_ver eq '3.x' ) {
	    $page .= Forms->checkbox(
		'Use pending states:',
		'use_pending_states',
		$objects{'use_pending_states'}[2],
		$docs{'use_pending_states'},
		'', $tab++, 1
	    );
	    $page .= Forms->checkbox(
		'Ack no sticky:',
		'ack_no_sticky',
		$objects{'ack_no_sticky'}[2],
		$docs{'ack_no_sticky'},
		'', $tab++, 1
	    );
	    $page .= Forms->checkbox(
		'Ack no send:',
		'ack_no_send',
		$objects{'ack_no_send'}[2],
		$docs{'ack_no_send'},
		'', $tab++, 1
	    );
	    $page .= Forms->checkbox(
		'TAC CGI hard only:',
		'tac_cgi_hard_only',
		$objects{'tac_cgi_hard_only'}[2],
		$docs{'tac_cgi_hard_only'},
		'', $tab++, 1
	    );
	}

	$page .= Forms->wizard_doc( 'CGI Sound Control Options', $docs{'cgi_sound_control_options'}, undef, 1 );
	$page .= Forms->text_box(
	    'Host unreachable sound:',
	    'host_unreachable_sound', $objects{'host_unreachable_sound'}[2],
	    $textsize{'long_name'}, '', $docs{'sound_options'}, '', $tab++, 1
	);
	$page .= Forms->text_box(
	    'Host down sound:',
	    'host_down_sound', $objects{'host_down_sound'}[2],
	    $textsize{'long_name'}, '', '', '', $tab++, 1
	);
	$page .= Forms->text_box(
	    'Service critical sound:',
	    'service_critical_sound', $objects{'service_critical_sound'}[2],
	    $textsize{'long_name'}, '', '', '', $tab++, 1
	);
	$page .= Forms->text_box(
	    'Service warning sound:',
	    'service_warning_sound', $objects{'service_warning_sound'}[2],
	    $textsize{'long_name'}, '', '', '', $tab++, 1
	);
	$page .= Forms->text_box(
	    'Service unknown sound:',
	    'service_unknown_sound', $objects{'service_unknown_sound'}[2],
	    $textsize{'long_name'}, '', '', '', $tab++, 1
	);
	$page .= Forms->text_box(
	    'Normal sound:',
	    'normal_sound', $objects{'normal_sound'}[2],
	    $textsize{'long_name'}, '', '', '', $tab++, 1
	);
	$page .= Forms->hidden( \%hidden );

	if ($gid) {
	    $page .= Forms->form_bottom_buttons( \%default, \%sync, \%upload, \%next, $tab++ );
	}
	else {
	    my %load = ( 'name' => 'load_nagios_cgi', 'value' => 'Load From File' );
	    $page .= Forms->form_bottom_buttons( \%default, \%load, \%next, $tab++ );
	}
    }
    elsif ( $step eq '2' ) {
	$hidden{'step'} = 2;
	$page .= Forms->header( $page_title, $session_id, $top_menu );
	$page .= Forms->form_top( "$form_title Page 2", '' );
	if (@errors) { $page .= Forms->form_errors( \@errors ) }
	my $value;
	my $rows;

	$page .= Forms->wizard_doc( 'CGI Access Control Options', $docs{'cgi_access_control_options'}, undef, 1 );
	$page .= Forms->checkbox(
	    'Use authentication:',
	    'use_authentication',
	    $objects{'use_authentication'}[2],
	    $docs{'use_authentication'},
	    '', $tab++, 1
	);
	$page .= Forms->text_box(
	    'Default user name:',
	    'default_user_name', $objects{'default_user_name'}[2],
	    $textsize{'short_name'}, '', $docs{'default_user_name'},
	    '', $tab++, 1
	);
	$value = $objects{'authorized_for_read_only'}[2];
	$rows  = int( length($value) / 70 );
	$rows  = 3 if $rows < 3;
	$page .= Forms->text_area(
	    'Read-Only Access:',
	    'authorized_for_read_only',
	    $value, $rows, '75', '', $docs{'authorized_for_read_only'},
	    '', $tab++, 1
	);
	$value = $objects{'authorized_contactgroup_for_read_only'}[2];
	$rows  = int( length($value) / 70 );
	$rows  = 3 if $rows < 3;
	$page .= Forms->text_area(
	    'Contactgroup Read-Only Access:',
	    'authorized_contactgroup_for_read_only',
	    $value, $rows, '75', '', $docs{'authorized_contactgroup_for_read_only'},
	    '', $tab++, 1
	);
	$value = $objects{'authorized_for_configuration_information'}[2];
	$rows  = int( length($value) / 70 );
	$rows  = 3 if $rows < 3;
	$page .= Forms->text_area(
	    'Configuration Information Access:',
	    'authorized_for_configuration_information',
	    $value, $rows, '75', '', $docs{'authorized_for_configuration_information'},
	    '', $tab++, 1
	);
	$value = $objects{'authorized_contactgroup_for_configuration_information'}[2];
	$rows  = int( length($value) / 70 );
	$rows  = 3 if $rows < 3;
	$page .= Forms->text_area(
	    'Contactgroup Configuration Information Access:',
	    'authorized_contactgroup_for_configuration_information',
	    $value, $rows, '75', '', $docs{'authorized_contactgroup_for_configuration_information'},
	    '', $tab++, 1
	);
	$value = $objects{'authorized_for_system_information'}[2];
	$rows  = int( length($value) / 70 );
	$rows  = 3 if $rows < 3;
	$page .= Forms->text_area(
	    'System/Process Information Access:',
	    'authorized_for_system_information',
	    $value, $rows, '75', '', $docs{'authorized_for_system_information'},
	    '', $tab++, 1
	);
	$value = $objects{'authorized_contactgroup_for_system_information'}[2];
	$rows  = int( length($value) / 70 );
	$rows  = 3 if $rows < 3;
	$page .= Forms->text_area(
	    'ContactGroup System/Process Information Access:',
	    'authorized_contactgroup_for_system_information',
	    $value, $rows, '75', '', $docs{'authorized_contactgroup_for_system_information'},
	    '', $tab++, 1
	);
	$value = $objects{'authorized_for_system_commands'}[2];
	$rows  = int( length($value) / 70 );
	$rows  = 3 if $rows < 3;
	$page .= Forms->text_area(
	    'System/Process Command Access:',
	    'authorized_for_system_commands',
	    $value, $rows, '75', '', $docs{'authorized_for_system_commands'},
	    '', $tab++, 1
	);
	$value = $objects{'authorized_contactgroup_for_system_commands'}[2];
	$rows  = int( length($value) / 70 );
	$rows  = 3 if $rows < 3;
	$page .= Forms->text_area(
	    'Contactgroup System/Process Command Access:',
	    'authorized_contactgroup_for_system_commands',
	    $value, $rows, '75', '', $docs{'authorized_contactgroup_for_system_commands'},
	    '', $tab++, 1
	);
	$value = $objects{'authorized_for_all_hosts'}[2];
	$rows  = int( length($value) / 70 );
	$rows  = 3 if $rows < 3;
	$page .= Forms->text_area(
	    'Global Host Information Access:',
	    'authorized_for_all_hosts', $value, $rows, '75', '', $docs{'authorized_for_all_hosts'},
	    '', $tab++, 1
	);
	$value = $objects{'authorized_contactgroup_for_all_hosts'}[2];
	$rows  = int( length($value) / 70 );
	$rows  = 3 if $rows < 3;
	$page .= Forms->text_area(
	    'Contactgroup Global Host Information Access:',
	    'authorized_contactgroup_for_all_hosts', $value, $rows, '75', '', $docs{'authorized_contactgroup_for_all_hosts'},
	    '', $tab++, 1
	);
	$value = $objects{'authorized_for_all_host_commands'}[2];
	$rows  = int( length($value) / 70 );
	$rows  = 3 if $rows < 3;
	$page .= Forms->text_area(
	    'Global Host Command Access:',
	    'authorized_for_all_host_commands',
	    $value, $rows, '75', '', $docs{'authorized_for_all_host_commands'},
	    '', $tab++, 1
	);
	$value = $objects{'authorized_contactgroup_for_all_host_commands'}[2];
	$rows  = int( length($value) / 70 );
	$rows  = 3 if $rows < 3;
	$page .= Forms->text_area(
	    'Contactgroup Global Host Command Access:',
	    'authorized_contactgroup_for_all_host_commands',
	    $value, $rows, '75', '', $docs{'authorized_contactgroup_for_all_host_commands'},
	    '', $tab++, 1
	);
	$value = $objects{'authorized_for_all_services'}[2];
	$rows  = int( length($value) / 70 );
	$rows  = 3 if $rows < 3;
	$page .= Forms->text_area(
	    'Global Service Information Access:',
	    'authorized_for_all_services', $value, $rows, '75', '', $docs{'authorized_for_all_services'},
	    '', $tab++, 1
	);
	$value = $objects{'authorized_contactgroup_for_all_services'}[2];
	$rows  = int( length($value) / 70 );
	$rows  = 3 if $rows < 3;
	$page .= Forms->text_area(
	    'Contactgroup Global Service Information Access:',
	    'authorized_contactgroup_for_all_services', $value, $rows, '75', '', $docs{'authorized_contactgroup_for_all_services'},
	    '', $tab++, 1
	);
	$value = $objects{'authorized_for_all_service_commands'}[2];
	$rows  = int( length($value) / 70 );
	$rows  = 3 if $rows < 3;
	$page .= Forms->text_area(
	    'Global Service Command Access:',
	    'authorized_for_all_service_commands',
	    $value, $rows, '75', '', $docs{'authorized_for_all_service_commands'},
	    '', $tab++, 1
	);
	$value = $objects{'authorized_contactgroup_for_all_service_commands'}[2];
	$rows  = int( length($value) / 70 );
	$rows  = 3 if $rows < 3;
	$page .= Forms->text_area(
	    'Contactgroup Global Service Command Access:',
	    'authorized_contactgroup_for_all_service_commands',
	    $value, $rows, '75', '', $docs{'authorized_contactgroup_for_all_service_commands'},
	    '', $tab++, 1
	);
	if ( $nagios_ver eq '3.x' ) {
	    $page .= Forms->checkbox(
		'Lock author names:',
		'lock_author_names',
		$objects{'lock_author_names'}[2],
		$docs{'lock_author_names'},
		'', $tab++, 1
	    );
	}
	$page .= Forms->hidden( \%hidden );
	%save = ( 'name' => 'next', 'value' => 'Save and Done' );
	$help{url} = StorProc->doc_section_url('How+to+manage+access+to+Nagios+CGIs');
	$page .= Forms->form_bottom_buttons( \%back, \%save, \%help, $tab++ );
    }
    elsif ( $step eq 'upload' ) {
	$page .= Forms->header( $page_title, $session_id, $top_menu );
	$page .= Forms->form_top_file( "$form_title Upload", '' );
	if (@errors) { $page .= Forms->form_errors( \@errors ) }
	$page .= Forms->wizard_doc('Upload Nagios CGI configuration file',
	    "Select the cgi.cfg file you wish to import. The set of values in your file will replace the complete set of Nagios CGI values for the \"$gname\" group.", undef, 1);
	$page .= Forms->form_file( $tab++ );
	$page .= Forms->hidden( \%hidden );
	$page .= Forms->form_bottom_buttons( \%upload, \%cancel, $tab++ );
    }
    elsif ( $step eq 'saved' ) {
	$page .= Forms->header( $page_title, $session_id, $top_menu );
	$page .= Forms->form_top( "$form_title", '' );
	my @message = ("Changes to Nagios CGI configuration completed.");
	$page .= Forms->form_message( 'Saved:', \@message, 'row1' );
	delete $hidden{'task'};
	$page .= Forms->hidden( \%hidden );
	$page .= Forms->form_bottom_buttons( \%continue, $tab++ );
    }
    return $page;
}

#
############################################################################
# Nagios main cfg
#

sub nagios_cfg($$) {
    my $gid       = shift;
    my $gname     = shift;
    my %checks    = ();
    my %objects   = ();
    my %misc_vals = ();
    my $misc_name = '';
    my $misc_value= '';

    my $options = $query->param('options');
    my $step    = defined($options) ? $nagios_options_step{$options} : $query->param('step');

    if ( defined $step ) {
	## These lists of checkbox items must be augmented whenever you add a call to Forms->checkbox() below.
	if ( $step eq '1' ) {
	    %checks = (
		'enable_notifications'     => '0',
		'use_regexp_matching'      => '0',
		'use_true_regexp_matching' => '0',
		'check_external_commands'  => '0'
	    );
	    if ( $nagios_ver =~ /^[12]\.x$/ ) {
		$checks{aggregate_status_updates} = '0';
	    }
	}
	elsif ( $step eq '2' ) {
	    %checks = (
		'execute_host_checks'                         => '0',
		'accept_passive_host_checks'                  => '0',
		'execute_service_checks'                      => '0',
		'accept_passive_service_checks'               => '0',
		'enable_predictive_host_dependency_checks'    => '0',
		'check_for_orphaned_hosts'                    => '0',
		'use_aggressive_host_checking'                => '0',
		'enable_predictive_service_dependency_checks' => '0',
		'check_for_orphaned_services'                 => '0',
		'auto_reschedule_checks'                      => '0',
		'check_host_freshness'                        => '0',
		'check_service_freshness'                     => '0',
		'obsess_over_hosts'                           => '0',
		'obsess_over_services'                        => '0'
	    );
	}
	elsif ( $step eq '3' ) {
	    %checks = (
		'translate_passive_host_checks' => '0',
		'passive_host_checks_are_soft'  => '0',
		'soft_state_dependencies'       => '0',
		'enable_flap_detection'         => '0',
		'process_performance_data'      => '0',
		'enable_event_handlers'         => '0'
	    );
	}
	elsif ( $step eq '4' ) {
	    %checks = (
		'retain_state_information'      => '0',
		'use_retained_program_state'    => '0',
		'use_retained_scheduling_info'  => '0',
		'use_large_installation_tweaks' => '0',
		'enable_environment_macros'     => '0',
		'child_processes_fork_twice'    => '0',
		'free_child_process_memory'     => '0',
		'log_notifications'             => '0',
		'log_host_retries'              => '0',
		'log_service_retries'           => '0',
		'log_event_handlers'            => '0',
		'log_initial_states'            => '0',
		'log_external_commands'         => '0',
		'log_passive_service_checks'    => '0',
		'log_passive_checks'            => '0',
		'use_syslog'                    => '0'
	    );
	}
    }
    if ( $query->param('next') ) {
	my %nagios_set = ();
	if ($gid) {
	    my %where = ( 'group_id' => $gid, 'name' => 'resource_file' );
	    %nagios_set = StorProc->fetch_one_where( 'monarch_group_props', \%where );
	}
	else {
	    %nagios_set = StorProc->fetch_one( 'setup', 'name', 'resource_file' );
	}
	if ( $nagios_set{'name'} ) {
	    my %nag_defined = ();
	    if ($gid) {
		## GWMON-4818:  monarch_group_props contains duplicate entries for nagios_cgi and nagios_cfg per group.
		## Need to loop through hash of table contents to eliminate duplicate entries.
		my %unique_props    = ();
		my %where           = ( 'group_id' => $gid, 'type' => 'nagios_cfg' );
		my %group_prop_hash = StorProc->fetch_list_hash_array( 'monarch_group_props', \%where );

		# process the id's in decending order to keep the latest values saved
		my @keys = keys %group_prop_hash;
		foreach my $id ( sort { $b <=> $a } @keys ) {
		    if ( $unique_props{ $group_prop_hash{$id}[2] } ) {
			%where = ( 'prop_id' => $id );
			my $res = StorProc->delete_one_where( 'monarch_group_props', \%where );
		    }
		    else {
			$unique_props{ $group_prop_hash{$id}[2] } = 1;
			$nag_defined{ $group_prop_hash{$id}[2] }  = 1;
		    }
		}
	    }
	    else {
		my %where = ( 'type' => 'nagios' );
		%nag_defined = StorProc->fetch_list_hash_array( 'setup', \%where );
	    }
	    foreach my $name ( $query->param ) {
		unless ( $name =~ /^next$|user_acct|^misc_name$|^misc_value$|^nocache$|^obj$|^step$|^top_menu$|^update_main$|^view$/ ) {
		    if ( $name =~ /radio_option/ ) {
			my $val = $query->param($name);
			$name =~ s/radio_option_//;
			if ( $val eq 'other' ) {
			    my $other = "other_$name";
			    $val = $query->param($other);
			}
			if ($gid) {
			    if ( $nag_defined{$name} ) {
				my %where = (
				    'group_id' => $gid,
				    'type'     => 'nagios_cfg',
				    'name'     => $name
				);
				my %values = ( 'value' => $val );
				my $result = StorProc->update_obj_where( 'monarch_group_props', \%values, \%where );
				if ( $result =~ /^Error/ ) { push @errors, $result; }
			    }
			    else {
				my @values = ( \undef, $gid, $name, 'nagios_cfg', $val );
				my $result = StorProc->insert_obj( 'monarch_group_props', \@values );
				if ( $result =~ /^Error/ ) { push @errors, $result; }
			    }
			}
			else {
			    if ( $nag_defined{$name} ) {
				my %values = ( 'value' => $val );
				my $result = StorProc->update_obj( 'setup', 'name', $name, \%values );
				if ( $result =~ /^Error/ ) { push @errors, $result; }
			    }
			    else {
				my @values = ( $name, 'nagios', $val );
				my $result = StorProc->insert_obj( 'setup', \@values );
				if ( $result =~ /^Error/ ) { push @errors, $result; }
			    }
			}
		    }
		    else {
			if ( defined $checks{$name} ) {
			    $checks{$name} = '1';
			}
			else {
			    my $val = $query->param($name);

			    # GWMON-9020
			    $val =~ s/[\n\r]+//g if $name =~ /_perfdata_file_template$/;

			    $val =~ s/^\s+//;
			    $val =~ s/\s+$//;
			    ## FIX MINOR:  Insert validation right here to check values that ought to be integers;
			    ## distinguish if signed is allowed.
			    if ( $val eq '0' ) { $val = '-zero-' }
			    if ($gid) {
				if ( $name =~ /^\d+$/ ) {
				    my %values = ( 'value'   => $val );
				    my %where  = ( 'prop_id' => $name );
				    my $result = StorProc->update_obj_where( 'monarch_group_props', \%values, \%where );
				    if ( $result =~ /^Error/ ) { push @errors, $result; }
				}
				elsif ( $nag_defined{$name} ) {
				    my %values = ( 'value' => $val );
				    my %where = (
					'group_id' => $gid,
					'type'     => 'nagios_cfg',
					'name'     => $name
				    );
				    my $result = StorProc->update_obj_where( 'monarch_group_props', \%values, \%where );
				    if ( $result =~ /^Error/ ) { push @errors, $result; }
				}
				else {
				    my @values = ( \undef, $gid, $name, 'nagios_cfg', $val );
				    my $result = StorProc->insert_obj( 'monarch_group_props', \@values );
				    if ( $result =~ /^Error/ ) { push @errors, $result; }
				}
			    }
			    else {
				if ( $name =~ /key\d+.\d+$/ || $nag_defined{$name} ) {
				    my %values = ( 'value' => $val );
				    my $result = StorProc->update_obj( 'setup', 'name', $name, \%values );
				    if ( $result =~ /^Error/ ) { push @errors, $result; }
				}
				else {
				    my @values = ( $name, 'nagios', $val );
				    my $result = StorProc->insert_obj( 'setup', \@values );
				    if ( $result =~ /^Error/ ) { push @errors, $result; }
				}
			    }
			}
		    }
		}
	    }
	    foreach my $name ( keys %checks ) {
		if ($gid) {
		    if ( $nag_defined{$name} ) {
			my %where = (
			    'group_id' => $gid,
			    'type'     => 'nagios_cfg',
			    'name'     => $name
			);
			my %values = ( 'value' => $checks{$name} );
			my $result = StorProc->update_obj_where( 'monarch_group_props', \%values, \%where );
			if ( $result =~ /^Error/ ) { push @errors, $result }
		    }
		    else {
			my @values = ( \undef, $gid, $name, 'nagios_cfg', $checks{$name} );
			my $result = StorProc->insert_obj( 'monarch_group_props', \@values );
			if ( $result =~ /^Error/ ) { push @errors, $result }
		    }
		}
		else {
		    if ( $nag_defined{$name} ) {
			my %values = ( 'value' => $checks{$name} );
			my $result = StorProc->update_obj( 'setup', 'name', $name, \%values );
			if ( $result =~ /^Error/ ) { push @errors, $result }
		    }
		    else {
			my @values = ( $name, 'nagios', $checks{$name} );
			my $result = StorProc->insert_obj( 'setup', \@values );
			if ( $result =~ /^Error/ ) { push @errors, $result }
		    }
		}
	    }
	}
	else {
	    my %nagios_defaults = StorProc->nagios_defaults( $nagios_ver, $is_portal );
	    foreach my $name ( keys %nagios_defaults ) {
		if ($gid) {
		    my @values = ( \undef, $gid, $name, 'nagios_cfg', $nagios_defaults{$name} );
		    my $result = StorProc->insert_obj( 'monarch_group_props', \@values );
		    if ( $result =~ /^Error/ ) { push @errors, $result }
		}
		else {
		    my @values = ( $name, 'nagios', $nagios_defaults{$name} );
		    my $result = StorProc->insert_obj( 'setup', \@values );
		    if ( $result =~ /^Error/ ) { push @errors, $result }
		}
	    }
	    $step = 0;
	}
	unless (@errors) {
	    if    ( $step eq '0' ) { $step = 1; }
	    elsif ( $step eq '1' ) { $step = 2; }
	    elsif ( $step eq '2' ) { $step = 3; }
	    elsif ( $step eq '3' ) { $step = 4; }
	    elsif ( $step eq '4' ) { $step = 'saved'; }
	}
    }
    elsif ( $query->param('rem_misc') ) {
	my @rem_keys = $query->$multi_param('rem_key');
	foreach my $key (@rem_keys) {
	    if ($gid) {
		my $result = StorProc->delete_all( 'monarch_group_props', 'prop_id', $key );
		if ( $result =~ /^Error/ ) { push @errors, $result }
	    }
	    else {
		my $result = StorProc->delete_all( 'setup', 'name', $key );
		if ( $result =~ /^Error/ ) { push @errors, $result }
	    }
	}
    }
    elsif ( $query->param('add_misc') ) {
	$misc_name  = $query->param('misc_name');
	$misc_value = $query->param('misc_value');
	$misc_name  =~ s/^\s+|\s+$//g;
	$misc_value =~ s/^\s+|\s+$//g;
	my $alt_misc_value = ( $misc_value eq '0' ) ? '-zero-' : $misc_value;

	# FIX THIS:  we should probably check for all kinds of illegal object-name characters in the
	# directive name and reject the directive if it violates the specified name constraints

	# Internal whitespace is probably illegal in downstream usage and it also makes the
	# directive impossible to delete, given the current construction of the delete code.
	if ($misc_name =~ /\s/) {
	    push @errors, "A miscellaneous directive name is not allowed to contain whitespace.";
	}
	elsif ($misc_name ne '') {
	    if ($gid) {
		my %where = ( 'group_id' => $gid, 'name' => $misc_name, 'type' => 'nagios_cfg_misc' );
		my @existing = StorProc->fetch_list_where( 'monarch_group_props', 'name', \%where );
		if (scalar @existing) {
		    push @errors, "A miscellaneous directive named '$misc_name' already exists for Group '$gname'.";
		}
		unless (@errors) {
		    %where = ( 'group_id' => $gid, 'name' => $misc_name, 'type' => 'nagios_cfg' );
		    @existing = StorProc->fetch_list_where( 'monarch_group_props', 'name', \%where );
		    if (scalar @existing) {
			push @errors, "The Nagios main configuration for Group '$gname' contains a directive named '$misc_name'; you cannot override that with a miscellaneous directive.";
		    }
		}
		unless (@errors) {
		    %where = ( 'group_id' => $gid, 'name' => $misc_name, 'type' => 'nagios_cgi' );
		    @existing = StorProc->fetch_list_where( 'monarch_group_props', 'name', \%where );
		    if (scalar @existing) {
			push @errors, "The Nagios CGI configuration for Group '$gname' contains a directive named '$misc_name'; you cannot override that with a miscellaneous directive.";
		    }
		}
		unless (@errors) {
		    my @vals = ( \undef, $gid, $misc_name, 'nagios_cfg_misc', $alt_misc_value );
		    my $result = StorProc->insert_obj( 'monarch_group_props', \@vals );
		    if ( $result =~ /^Error/ ) {
			push @errors, $result;
		    }
		    else {
			$misc_name  = '';
			$misc_value = '';
		    }
		}
	    }
	    else {
		my @existing = StorProc->fetch_list_start( 'setup', 'name', 'name', $misc_name . 'key' );
		if (scalar @existing) {
		    push @errors, "A miscellaneous directive named '$misc_name' already exists.";
		}
		unless (@errors) {
		    my %where = ( 'name' => $misc_name, 'type' => 'nagios' );
		    @existing = StorProc->fetch_list_where( 'setup', 'name', \%where );
		    if (scalar @existing) {
			push @errors, "The Nagios main configuration contains a directive named '$misc_name'; you cannot override that with a miscellaneous directive.";
		    }
		}
		unless (@errors) {
		    my %where = ( 'name' => $misc_name, 'type' => 'nagios_cgi' );
		    @existing = StorProc->fetch_list_where( 'setup', 'name', \%where );
		    if (scalar @existing) {
			push @errors, "The Nagios CGI configuration contains a directive named '$misc_name'; you cannot override that with a miscellaneous directive.";
		    }
		}
		unless (@errors) {
		    # We don't need this name suffix above for a miscellaneous directive in a group because
		    # the monarch_group_props.prop_id field already provides the requisite uniqueness.
		    my @vals = ( $misc_name . 'key' . rand(), 'nagios_cfg_misc', $alt_misc_value );
		    my $result = StorProc->insert_obj( 'setup', \@vals );
		    if ( $result =~ /^Error/ ) {
			push @errors, $result;
		    }
		    else {
			$misc_name  = '';
			$misc_value = '';
		    }
		}
	    }
	}
    }
    elsif ( $query->param('back') ) {
	$step = $step - 1;
    }
    elsif ( $query->param('sync') ) {
	my %where = ( 'type' => 'nagios' );
	my %main_object = StorProc->fetch_list_hash_array( 'setup', \%where );
	%where = ( 'group_id' => $gid, 'type' => 'nagios_cfg' );
	my $result = StorProc->delete_one_where( 'monarch_group_props', \%where );
	if ( $result =~ /^Error/ ) { push @errors, $result }
	foreach my $object ( keys %main_object ) {
	    my @vals = ( \undef, $gid, $main_object{$object}[0], 'nagios_cfg', $main_object{$object}[2] );
	    my $result = StorProc->insert_obj( 'monarch_group_props', \@vals );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	}
    }
    elsif ( $query->param('set_defaults') ) {
	my %nagios_defaults = StorProc->nagios_defaults( $nagios_ver, $is_portal );
	if ($gid) {
	    my %where = ( 'group_id' => $gid, 'type' => 'nagios_cfg' );
	    my $result = StorProc->delete_one_where( 'monarch_group_props', \%where );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	}
	else {
	    my $result = StorProc->delete_all( 'setup', 'type', 'nagios' );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	}
	foreach my $name ( keys %nagios_defaults ) {
	    if ($gid) {
		my @vals = ( \undef, $gid, $name, 'nagios_cfg', $nagios_defaults{$name} );
		my $result = StorProc->insert_obj( 'monarch_group_props', \@vals );
		if ( $result =~ /^Error/ ) { push @errors, $result }
	    }
	    else {
		my @values = ( $name, 'nagios', $nagios_defaults{$name} );
		my $result = StorProc->insert_obj( 'setup', \@values );
		if ( $result =~ /^Error/ ) { push @errors, $result }
	    }
	}
	$step = 1;
    }
    elsif ( $query->param('upload') ) {
	$step = 'upload';
	my $file = $query->param('upload_file');
	if ( $file =~ /nagios\.cfg/ ) {
	    my ($filedata, $errs) = StorProc->upload( '/tmp', $file );
	    my @errs = @$errs;
	    if (@errs) { push @errors, @errs }
	    unless (@errors) {
		my @errs = StorProc->import_nagios_cfg($gid, $file, $filedata, 1);
		if (@errs) { push( @errors, @errs ) }
		$step = 1;
	    }
	}
	elsif ($file) {
	    push @errors, "Invalid file type \"$file\". Filename must contain \"nagios.cfg\".";
	}
    }
    elsif ( $query->param('load_nagios_cfg') ) {
	@errors = StorProc->load_nagios_cfg( $nagios_etc, $nagios_ver );
	$step   = 1;
    }
    elsif ( defined($task) && $task eq 'view_edit' ) {
	$step = 1;
    }
    %next = ( 'name' => 'next', 'value' => 'Save and Next >>' );

    if ($gid) {
	%objects = StorProc->get_group_cfg($gid);
    }
    else {
	my %where = ( 'type' => 'nagios' );
	%objects = StorProc->fetch_list_hash_array( 'setup', \%where );
    }

    foreach my $obj ( keys %objects ) { $objects{$obj}[2] =~ s/-zero-/0/ if defined $objects{$obj}[2] }
    my %docs     = Doc->nagios_cfg();
    my %where    = ( 'type' => 'other' );
    my @commands = StorProc->fetch_list_where( 'commands', 'name', \%where );
    my $page     = undef;
    my $form_title = 'Nagios Main Configuration';
    if ($gid) { $form_title = "$gname Nagios Main Configuration" }
    unless ($step) { $step = 1 }

    if ( $step eq '1' ) {
	$hidden{'step'} = 1;
	$page .= Forms->header( $page_title, $session_id, $top_menu );
	$page .= Forms->form_top( "$form_title Page 1", '' );
	if (@errors) { $page .= Forms->form_errors( \@errors ) }

	$page .= Forms->wizard_doc( 'Notification Options', $docs{'notification_options'}, undef, 1 );
	$page .= Forms->checkbox(
	    'Enable notifications:',
	    'enable_notifications',
	    $objects{'enable_notifications'}[2],
	    $docs{'enable_notifications'},
	    '', $tab++, 1
	);
	$page .= Forms->text_box(
	    'Notification timeout:',
	    'notification_timeout', $objects{'notification_timeout'}[2],
	    $textsize{'small'}, '', $docs{'notification_timeout'}, '', $tab++, 1
	);
	$page .= Forms->text_box( 'Admin email:', 'admin_email', $objects{'admin_email'}[2],
	    $textsize{'long_name'}, '', $docs{'admin_email'}, '', $tab++, 1 );
	$page .= Forms->text_box( 'Admin pager:', 'admin_pager', $objects{'admin_pager'}[2],
	    $textsize{'long_name'}, '', $docs{'admin_pager'}, '', $tab++, 1 );

	$page .= Forms->wizard_doc( 'Configuration Options', $docs{'configuration_options'}, undef, 1 );
	$page .= Forms->text_box(
	    'Resource file:',
	    'resource_file', $objects{'resource_file'}[2],
	    $textsize{'long_name'}, '', $docs{'resource_file'}, '', $tab++, 1
	);
	$page .= Forms->text_box(
	    'Website URL:',
	    'website_url', $objects{'website_url'}[2],
	    $textsize{'long_name'}, '', $docs{'website_url'}, '', $tab++, 1
	);

	$page .= Forms->wizard_doc( 'Time Format Options', $docs{'time_format_options'}, undef, 1 );
	$page .= Forms->date_format( $objects{'date_format'}[2], $docs{'date_format'}, $tab++, 1 );
	$page .= Forms->text_box(
	    'Use timezone:',
	    'use_timezone', $objects{'use_timezone'}[2],
	    $textsize{'name'}, '', $docs{'use_timezone'}, '', $tab++, 1
	);

	$page .= Forms->wizard_doc( 'Character Constraint Options', $docs{'character_constraint_options'}, undef, 1 );
	$page .= Forms->text_box(
	    'Illegal object name chars:',
	    'illegal_object_name_chars', $objects{'illegal_object_name_chars'}[2],
	    $textsize{'long_name'}, '', $docs{'illegal_object_name_chars'},
	    '', $tab++, 1
	);
	$page .= Forms->text_box(
	    'Illegal macro output characters:',
	    'illegal_macro_output_chars', $objects{'illegal_macro_output_chars'}[2],
	    $textsize{'long_name'}, '', $docs{'illegal_macro_output_chars'},
	    '', $tab++, 1
	);

	$page .= Forms->wizard_doc( 'External Interface Options', $docs{'external_interface_options'}, undef, 1 );
	$page .= Forms->checkbox(
	    'Check external commands:',
	    'check_external_commands',
	    $objects{'check_external_commands'}[2],
	    $docs{'check_external_commands'},
	    '', $tab++, 1
	);
	$page .= Forms->text_box(
	    'External command check interval:',
	    'command_check_interval', $objects{'command_check_interval'}[2],
	    $textsize{'small'}, '', $docs{'command_check_interval'},
	    '', $tab++, 1
	);
	$page .= Forms->text_box(
	    'External command file:',
	    'command_file', $objects{'command_file'}[2],
	    $textsize{'long_name'}, '', $docs{'command_file'}, '', $tab++, 1
	);

	if ( $nagios_ver eq '3.x' ) {
	    $page .= Forms->text_box(
		'External command buffer slots:',
		'external_command_buffer_slots',
		$objects{'external_command_buffer_slots'}[2],
		$textsize{'small'}, '', $docs{'external_command_buffer_slots'},
		'', $tab++, 1
	    );
	}
	if ( $nagios_ver =~ /^[23]\.x$/ ) {
	    $page .= Forms->text_box(
		'Object cache file:',
		'object_cache_file', $objects{'object_cache_file'}[2],
		$textsize{'long_name'}, '', $docs{'object_cache_file'},
		'', $tab++, 1
	    );
	}
	if ( $nagios_ver =~ /^[12]\.x$/ ) {
	    $page .= Forms->checkbox(
		'Aggregated status updates option:',
		'aggregate_status_updates',
		$objects{'aggregate_status_updates'}[2],
		$docs{'aggregate_status_updates'},
		'', $tab++, 1
	    );
	}
	$page .= Forms->text_box( 'Status file:', 'status_file', $objects{'status_file'}[2],
	    $textsize{'long_name'}, '', $docs{'status_file'}, '', $tab++, 1 );
	$page .= Forms->text_box(
	    'Aggregated status data update interval:',
	    'status_update_interval', $objects{'status_update_interval'}[2],
	    '7', '', $docs{'status_update_interval'},
	    '', $tab++, 1
	);
	if ( $nagios_ver =~ /^[12]\.x$/ ) {
	    $page .= Forms->text_box(
		'Downtime file:',
		'downtime_file', $objects{'downtime_file'}[2],
		$textsize{'long_name'}, '', $docs{'downtime_file'}, '', $tab++, 1
	    );
	    $page .= Forms->text_box(
		'Comment file:',
		'comment_file', $objects{'comment_file'}[2],
		$textsize{'long_name'}, '', $docs{'comment_file'}, '', $tab++, 1
	    );
	}
	if ($is_portal) {
	    $page .= Forms->text_box(
		'Event broker options:',
		'event_broker_options', $objects{'event_broker_options'}[2],
		$textsize{'small'}, '', $docs{'event_broker_options'},
		'', $tab++, 1
	    );
	    ## The Nagios doc says "Use multiple broker_module directives if you want to load more than one module.".
	    ## Currently, we only support one copy of the broker_module directive, with no means to specify more copies.
	    ## If we change that, modify the tooltip content, too.
	    $page .= Forms->text_box(
		'Broker module:',
		'broker_module', $objects{'broker_module'}[2],
		$textsize{'long_name'}, '', $docs{'broker_module'}, '', $tab++, 1
	    );
	}

	$page .= Forms->wizard_doc( 'Debug Options', $docs{'debug_options'}, undef, 1 );
	if ( $nagios_ver eq '3.x' ) {
	    ## FIX MINOR:  use a specialized option-selection routine for debug_level, and revise the doc to match
	    $page .= Forms->text_box( 'Debug level:', 'debug_level', $objects{'debug_level'}[2],
		$textsize{'small'}, '', $docs{'debug_level'}, '', $tab++, 1 );
	    $page .= Forms->debug_verbosity( $objects{'debug_verbosity'}[2], $docs{'debug_verbosity'}, $tab++, 1 );
	    $page .= Forms->text_box( 'Debug file:', 'debug_file', $objects{'debug_file'}[2],
		$textsize{'long_name'}, '', $docs{'debug_file'}, '', $tab++, 1 );
	    $page .= Forms->text_box(
		'Max debug file size:',
		'max_debug_file_size', $objects{'max_debug_file_size'}[2],
		$textsize{'file_size'}, '', $docs{'max_debug_file_size'},
		'', $tab++, 1
	    );
	}

	$page .= Forms->hidden( \%hidden );
	if ($gid) {
	    $page .= Forms->form_bottom_buttons( \%default, \%sync, \%upload, \%next, $tab++ );
	}
	else {
	    %upload = ( 'name' => 'load_nagios_cfg', 'value' => 'Load From File' );
	    $page .= Forms->form_bottom_buttons( \%default, \%upload, \%next, $tab++ );
	}
    }
    elsif ( $step eq '2' ) {
	$hidden{'step'} = 2;
	$page .= Forms->header( $page_title, $session_id, $top_menu );
	$page .= Forms->form_top( "$form_title Page 2", '' );
	if (@errors) { $page .= Forms->form_errors( \@errors ) }

	$page .= Forms->wizard_doc( 'Check Execution Options', $docs{'check_execution_options'}, undef, 1 );
	if ( $nagios_ver =~ /^[23]\.x$/ ) {
	    $page .= Forms->checkbox(
		'Execute host checks',
		'execute_host_checks',
		$objects{'execute_host_checks'}[2],
		$docs{'execute_host_checks'},
		'', $tab++, 1
	    );
	    $page .= Forms->checkbox(
		'Accept passive host checks',
		'accept_passive_host_checks',
		$objects{'accept_passive_host_checks'}[2],
		$docs{'accept_passive_host_checks'},
		'', $tab++, 1
	    );
	}
	$page .= Forms->checkbox(
	    'Execute service checks:',
	    'execute_service_checks',
	    $objects{'execute_service_checks'}[2],
	    $docs{'execute_service_checks'},
	    '', $tab++, 1
	);
	$page .= Forms->checkbox(
	    'Accept passive service checks:',
	    'accept_passive_service_checks',
	    $objects{'accept_passive_service_checks'}[2],
	    $docs{'accept_passive_service_checks'},
	    '', $tab++, 1
	);

	$page .= Forms->wizard_doc( 'Check Scheduling Options', $docs{'check_scheduling_options'}, undef, 1 );
	$page .=
	  Forms->text_box( 'Sleep time:', 'sleep_time', $objects{'sleep_time'}[2], $textsize{'small'}, '', $docs{'sleep_time'}, '', $tab++, 1 );
	if ( $nagios_ver =~ /^[23]\.x$/ ) {
	    $page .= Forms->radio_options(
		'Host inter check delay method:',
		'host_inter_check_delay_method',
		$objects{'host_inter_check_delay_method'}[2],
		$docs{'host_inter_check_delay_method'},
		$tab++, 1
	    );
	    $page .= Forms->text_box(
		'Max host check spread:',
		'max_host_check_spread', $objects{'max_host_check_spread'}[2],
		$textsize{'small'}, '', $docs{'max_host_check_spread'},
		'', $tab++, 1
	    );
	}
	$page .= Forms->text_box(
	    'Host check timeout:',
	    'host_check_timeout', $objects{'host_check_timeout'}[2],
	    $textsize{'small'}, '', $docs{'host_check_timeout'}, '', $tab++, 1
	);
	if ( $nagios_ver eq '3.x' ) {
	    $page .= Forms->text_box(
		'Cached host check horizon:',
		'cached_host_check_horizon', $objects{'cached_host_check_horizon'}[2],
		$textsize{'small'}, '', $docs{'cached_host_check_horizon'},
		'', $tab++, 1
	    );
	    $page .= Forms->checkbox(
		'Enable predictive host dependency checks:',
		'enable_predictive_host_dependency_checks',
		$objects{'enable_predictive_host_dependency_checks'}[2],
		$docs{'enable_predictive_host_dependency_checks'},
		'', $tab++, 1
	    );
	}
	$page .= Forms->checkbox(
	    'Check for orphaned hosts:',
	    'check_for_orphaned_hosts',
	    $objects{'check_for_orphaned_hosts'}[2],
	    $docs{'check_for_orphaned_hosts'},
	    '', $tab++, 1
	);
	$page .= Forms->checkbox(
	    'Use aggressive host checking:',
	    'use_aggressive_host_checking',
	    $objects{'use_aggressive_host_checking'}[2],
	    $docs{'use_aggressive_host_checking'},
	    '', $tab++, 1
	);
	if ( $nagios_ver eq '1.x' ) {
	    $page .= Forms->radio_options(
		'Inter check delay method:',
		'inter_check_delay_method',
		$objects{'inter_check_delay_method'}[2],
		$docs{'inter_check_delay_method'},
		$tab++, 1
	    );
	}
	else {
	    $page .= Forms->radio_options(
		'Service inter check delay method:',
		'service_inter_check_delay_method',
		$objects{'service_inter_check_delay_method'}[2],
		$docs{'service_inter_check_delay_method'},
		$tab++, 1
	    );
	    $page .= Forms->text_box(
		'Max service check spread:',
		'max_service_check_spread', $objects{'max_service_check_spread'}[2],
		$textsize{'small'}, '', $docs{'max_service_check_spread'},
		'', $tab++, 1
	    );
	}
	$page .= Forms->text_box(
	    'Service check timeout:',
	    'service_check_timeout', $objects{'service_check_timeout'}[2],
	    $textsize{'small'}, '', $docs{'service_check_timeout'}, '', $tab++, 1
	);
	if ( $nagios_ver eq '3.x' ) {
	    $page .= Forms->text_box(
		'Cached service check horizon:',
		'cached_service_check_horizon',
		$objects{'cached_service_check_horizon'}[2],
		$textsize{'small'}, '', $docs{'cached_service_check_horizon'},
		'', $tab++, 1
	    );
	    $page .= Forms->checkbox(
		'Enable predictive service dependency checks:',
		'enable_predictive_service_dependency_checks',
		$objects{'enable_predictive_service_dependency_checks'}[2],
		$docs{'enable_predictive_service_dependency_checks'},
		'', $tab++, 1
	    );
	}
	$page .= Forms->checkbox(
	    'Check for orphaned services:',
	    'check_for_orphaned_services',
	    $objects{'check_for_orphaned_services'}[2],
	    $docs{'check_for_orphaned_services'},
	    '', $tab++, 1
	);
	$page .= Forms->radio_options(
	    'Service interleave factor:',
	    'service_interleave_factor',
	    $objects{'service_interleave_factor'}[2],
	    $docs{'service_interleave_factor'},
	    $tab++, 1
	);
	$page .= Forms->text_box(
	    'Maximum concurrent service checks:',
	    'max_concurrent_checks', $objects{'max_concurrent_checks'}[2],
	    $textsize{'small'}, '', $docs{'max_concurrent_checks'},
	    '', $tab++, 1
	);
	$page .= Forms->text_box(
	    'Timing interval length:',
	    'interval_length', $objects{'interval_length'}[2],
	    $textsize{'small'}, '', $docs{'interval_length'},
	    '', $tab++, 1
	);
	if ( $nagios_ver =~ /^[23]\.x$/ ) {
	    $page .= Forms->checkbox(
		'Auto reschedule checks:',
		'auto_reschedule_checks',
		$objects{'auto_reschedule_checks'}[2],
		$docs{'auto_reschedule_checks'},
		'', $tab++, 1
	    );
	    $page .= Forms->text_box(
		'Auto rescheduling interval:',
		'auto_rescheduling_interval', $objects{'auto_rescheduling_interval'}[2],
		$textsize{'small'}, '', $docs{'auto_rescheduling_interval'},
		'', $tab++, 1
	    );
	    $page .= Forms->text_box(
		'Auto rescheduling window:',
		'auto_rescheduling_window', $objects{'auto_rescheduling_window'}[2],
		$textsize{'small'}, '', $docs{'auto_rescheduling_window'},
		'', $tab++, 1
	    );
	}

	$page .= Forms->wizard_doc( 'Freshness Check Options', $docs{'freshness_check_options'}, undef, 1 );
	if ( $nagios_ver =~ /^[23]\.x$/ ) {
	    $page .= Forms->checkbox(
		'Check host freshness:',
		'check_host_freshness',
		$objects{'check_host_freshness'}[2],
		$docs{'check_host_freshness'},
		'', $tab++, 1
	    );
	    $page .= Forms->text_box(
		'Host freshness check interval:',
		'host_freshness_check_interval',
		$objects{'host_freshness_check_interval'}[2],
		$textsize{'small'}, '', $docs{'host_freshness_check_interval'},
		'', $tab++, 1
	    );
	}
	$page .= Forms->checkbox(
	    'Check service freshness:',
	    'check_service_freshness',
	    $objects{'check_service_freshness'}[2],
	    $docs{'check_service_freshness'},
	    '', $tab++, 1
	);
	if ( $nagios_ver =~ /^[12]\.x$/ ) {
	    $page .= Forms->text_box(
		'Service freshness check interval:',
		'freshness_check_interval', $objects{'freshness_check_interval'}[2],
		$textsize{'small'}, '', $docs{'freshness_check_interval'},
		'', $tab++, 1
	    );
	}
	if ( $nagios_ver eq '3.x' ) {
	    $page .= Forms->text_box(
		'Service freshness check interval:',
		'service_freshness_check_interval', $objects{'service_freshness_check_interval'}[2],
		$textsize{'small'}, '', $docs{'service_freshness_check_interval'},
		'', $tab++, 1
	    );
	}
	$page .= Forms->text_box(
	    'Additional freshness latency:',
	    'additional_freshness_latency',
	    $objects{'additional_freshness_latency'}[2],
	    $textsize{'small'}, '', $docs{'additional_freshness_latency'},
	    '', $tab++, 1
	);

	$page .= Forms->wizard_doc( 'Obsessive-Compulsive Processing Options', $docs{'obsessive_options'}, undef, 1 );
	if ( $nagios_ver =~ /^[23]\.x$/ ) {
	    $page .= Forms->checkbox(
		'Obsess over hosts:',
		'obsess_over_hosts',
		$objects{'obsess_over_hosts'}[2],
		$docs{'obsess_over_hosts'},
		'', $tab++, 1
	    );
	    $page .= Forms->text_box(
		'OCHP command:',
		'ochp_command', $objects{'ochp_command'}[2],
		$textsize{'long_name'}, '', $docs{'ochp_command'}, '', $tab++, 1
	    );
	    $page .= Forms->text_box(
		'OCHP timeout:',
		'ochp_timeout', $objects{'ochp_timeout'}[2],
		$textsize{'small'}, '', $docs{'ochp_timeout'}, '', $tab++, 1
	    );
	}
	$page .= Forms->checkbox(
	    'Obsess over services:',
	    'obsess_over_services',
	    $objects{'obsess_over_services'}[2],
	    $docs{'obsess_over_services'},
	    '', $tab++, 1
	);
	$page .= Forms->text_box(
	    'OCSP command:',
	    'ocsp_command', $objects{'ocsp_command'}[2],
	    $textsize{'long_name'}, '', $docs{'ocsp_command'}, '', $tab++, 1
	);
	$page .= Forms->text_box(
	    'OCSP timeout:',
	    'ocsp_timeout', $objects{'ocsp_timeout'}[2],
	    $textsize{'small'}, '', $docs{'ocsp_timeout'}, '', $tab++, 1
	);

	$page .= Forms->hidden( \%hidden );
	$page .= Forms->form_bottom_buttons( \%back, \%next, $tab++ );
    }
    elsif ( $step eq '3' ) {
	$hidden{'step'} = 3;
	$page .= Forms->header( $page_title, $session_id, $top_menu );
	$page .= Forms->form_top( "$form_title Page 3", '' );
	if (@errors) { $page .= Forms->form_errors( \@errors ) }

	$page .= Forms->wizard_doc( 'Check Result Processing Options', $docs{'result_processing_options'}, undef, 1 );
	if ( $nagios_ver =~ /^[12]\.x$/ ) {
	    $page .= Forms->text_box(
		'Service reaper frequency:',
		'service_reaper_frequency', $objects{'service_reaper_frequency'}[2],
		$textsize{'small'}, '', $docs{'service_reaper_frequency'},
		'', $tab++, 1
	    );
	}
	if ( $nagios_ver eq '3.x' ) {
	    $page .= Forms->text_box(
		'Check result path:',
		'check_result_path', $objects{'check_result_path'}[2],
		$textsize{'long_size'}, '', $docs{'check_result_path'},
		'', $tab++, 1
	    );
	    $page .= Forms->text_box(
		'Check result reaper frequency:',
		'check_result_reaper_frequency',
		$objects{'check_result_reaper_frequency'}[2],
		$textsize{'small'}, '', $docs{'check_result_reaper_frequency'},
		'', $tab++, 1
	    );
	    $page .= Forms->text_box(
		'Max check result reaper time:',
		'max_check_result_reaper_time',
		$objects{'max_check_result_reaper_time'}[2],
		$textsize{'small'}, '', $docs{'max_check_result_reaper_time'},
		'', $tab++, 1
	    );
	    $page .= Forms->text_box(
		'Max check result file age:',
		'max_check_result_file_age', $objects{'max_check_result_file_age'}[2],
		$textsize{'small'}, '', $docs{'max_check_result_file_age'},
		'', $tab++, 1
	    );
	}

	$page .= Forms->wizard_doc( 'Object State Processing Options', $docs{'object_state_options'}, undef, 1 );
	if ( $nagios_ver eq '3.x' ) {
	    $page .= Forms->checkbox(
		'Translate passive host checks:',
		'translate_passive_host_checks',
		$objects{'translate_passive_host_checks'}[2],
		$docs{'translate_passive_host_checks'},
		'', $tab++, 1
	    );
	    $page .= Forms->checkbox(
		'Passive host checks are soft:',
		'passive_host_checks_are_soft',
		$objects{'passive_host_checks_are_soft'}[2],
		$docs{'passive_host_checks_are_soft'},
		'', $tab++, 1
	    );
	}
	$page .= Forms->checkbox(
	    'Soft state dependencies:',
	    'soft_state_dependencies',
	    $objects{'soft_state_dependencies'}[2],
	    $docs{'soft_state_dependencies'},
	    '', $tab++, 1
	);

	$page .= Forms->wizard_doc( 'Flapping Control Options', $docs{'flapping_control_options'}, undef, 1 );
	$page .= Forms->checkbox(
	    'Flap detection option:',
	    'enable_flap_detection',
	    $objects{'enable_flap_detection'}[2],
	    $docs{'enable_flap_detection'},
	    '', $tab++, 1
	);
	$page .= Forms->text_box(
	    'Low host flap threshold:',
	    'low_host_flap_threshold', $objects{'low_host_flap_threshold'}[2],
	    $textsize{'small'}, '', $docs{'host_flap_detection_thresholds'},
	    '', $tab++, 1
	);
	$page .= Forms->text_box(
	    'High host flap threshold:',
	    'high_host_flap_threshold', $objects{'high_host_flap_threshold'}[2],
	    $textsize{'small'}, '', '', '', $tab++, 1
	);
	$page .= Forms->text_box(
	    'Low service flap threshold:',
	    'low_service_flap_threshold', $objects{'low_service_flap_threshold'}[2],
	    $textsize{'small'}, '', $docs{'service_flap_detection_thresholds'},
	    '', $tab++, 1
	);
	$page .= Forms->text_box(
	    'High service flap threshold:',
	    'high_service_flap_threshold', $objects{'high_service_flap_threshold'}[2],
	    $textsize{'small'}, '', '', '', $tab++, 1
	);

	$page .= Forms->wizard_doc( 'Performance Data Processing Options', $docs{'performance_data_options'}, undef, 1 );
	$page .= Forms->checkbox(
	    'Process performance data:',
	    'process_performance_data',
	    $objects{'process_performance_data'}[2],
	    $docs{'process_performance_data'},
	    '', $tab++, 1
	);
	$page .= Forms->list_box(
	    'Host perfdata command:',
	    'host_perfdata_command', \@commands, $objects{'host_perfdata_command'}[2],
	    '', $docs{'host_perfdata_command'},
	    '', $tab++, 1
	);
	if ( $nagios_ver =~ /^[23]\.x$/ ) {
	    $page .= Forms->text_box(
		'Host performance data file:',
		'host_perfdata_file', $objects{'host_perfdata_file'}[2],
		$textsize{'long_name'}, '', $docs{'host_perfdata_file'},
		'', $tab++, 1
	    );
	    ## GWMON-9020
	    my $host_temp = $objects{'host_perfdata_file_template'}[2];
	    $host_temp = '' if not defined $host_temp;
	    $page .= Forms->text_area(
		'Host performance data file template:',
		'host_perfdata_file_template', $host_temp, int( ( length($host_temp) + 10 ) / $textsize{'very_long_name'} ) + 1,
		$textsize{'very_long_name'}, '', $docs{'host_perfdata_file_template'},
		'', $tab++, 1
	    );
	    my @opts = ( 'a', 'w' );
	    $page .= Forms->list_box(
		'Host performance data file mode:',
		'host_perfdata_file_mode', \@opts, $objects{'host_perfdata_file_mode'}[2],
		'', $docs{'host_perfdata_file_mode'},
		'', $tab++, 1
	    );
	    $page .= Forms->text_box(
		'Host performance data file processing interval:',
		'host_perfdata_file_processing_interval',
		$objects{'host_perfdata_file_processing_interval'}[2],
		$textsize{'small'}, '', $docs{'host_perfdata_file_processing_interval'},
		'', $tab++, 1
	    );
	    $page .= Forms->list_box(
		'Host performance data file processing command:',
		'host_perfdata_file_processing_command',
		\@commands, $objects{'host_perfdata_file_processing_command'}[2],
		'', $docs{'host_perfdata_file_processing_command'},
		'', $tab++, 1
	    );
	}
	$page .= Forms->list_box(
	    'Service perfdata command:',
	    'service_perfdata_command', \@commands, $objects{'service_perfdata_command'}[2],
	    '', $docs{'service_perfdata_command'},
	    '', $tab++, 1
	);

	if ( $nagios_ver =~ /^[23]\.x$/ ) {
	    $page .= Forms->text_box(
		'Service performance data file:',
		'service_perfdata_file', $objects{'service_perfdata_file'}[2],
		$textsize{'long_name'}, '', $docs{'service_perfdata_file'},
		'', $tab++, 1
	    );
	    ## GWMON-9020
	    my $serv_temp = $objects{'service_perfdata_file_template'}[2];
	    $serv_temp = '' if not defined $serv_temp;
	    $page .= Forms->text_area(
		'Service performance data file template:',
		'service_perfdata_file_template',
		$serv_temp, int( ( length($serv_temp) + 10 ) / $textsize{'very_long_name'} ) + 1,
		$textsize{'very_long_name'}, '', $docs{'service_perfdata_file_template'},
		'', $tab++, 1
	    );
	    my @opts = ( 'a', 'w' );
	    $page .= Forms->list_box(
		'Service performance data file mode:',
		'service_perfdata_file_mode', \@opts, $objects{'service_perfdata_file_mode'}[2],
		'', $docs{'service_perfdata_file_mode'},
		'', $tab++, 1
	    );
	    $page .= Forms->text_box(
		'Service performance data file processing interval:',
		'service_perfdata_file_processing_interval',
		$objects{'service_perfdata_file_processing_interval'}[2],
		$textsize{'small'}, '', $docs{'service_perfdata_file_processing_interval'},
		'', $tab++, 1
	    );
	    $page .= Forms->list_box(
		'Service performance data file processing command:',
		'service_perfdata_file_processing_command',
		\@commands, $objects{'service_perfdata_file_processing_command'}[2],
		'', $docs{'service_perfdata_file_processing_command'},
		'', $tab++, 1
	    );
	}
	$page .= Forms->text_box(
	    'Perfdata timeout:',
	    'perfdata_timeout', $objects{'perfdata_timeout'}[2],
	    $textsize{'small'}, '', $docs{'perfdata_timeout'},
	    '', $tab++, 1
	);

	$page .= Forms->wizard_doc( 'Event Handling Options', $docs{'event_handling_options'}, undef, 1 );
	$page .= Forms->checkbox(
	    'Enable event handlers:',
	    'enable_event_handlers',
	    $objects{'enable_event_handlers'}[2],
	    $docs{'enable_event_handlers'},
	    '', $tab++, 1
	);
	$page .= Forms->list_box(
	    'Global host event handler:',
	    'global_host_event_handler', \@commands, $objects{'global_host_event_handler'}[2],
	    '', $docs{'global_host_event_handler'},
	    '', $tab++, 1
	);
	$page .= Forms->list_box(
	    'Global service event handler:',
	    'global_service_event_handler',
	    \@commands, $objects{'global_service_event_handler'}[2],
	    '', $docs{'global_service_event_handler'},
	    '', $tab++, 1
	);
	$page .= Forms->text_box(
	    'Event handler timeout:',
	    'event_handler_timeout', $objects{'event_handler_timeout'}[2],
	    $textsize{'small'}, '', $docs{'event_handler_timeout'}, '', $tab++, 1
	);

	$page .= Forms->hidden( \%hidden );
	$page .= Forms->form_bottom_buttons( \%back, \%next, $tab++ );
    }
    elsif ( $step eq '4' ) {
	$hidden{'step'} = 4;
	$page .= Forms->header( $page_title, $session_id, $top_menu );
	$page .= Forms->form_top( "$form_title Page 4", '' );
	if (@errors) { $page .= Forms->form_errors( \@errors ) }

	$page .= Forms->wizard_doc( 'Internal Operations Options', $docs{'internal_operations_options'}, undef, 1 );
	$page .= Forms->text_box( 'Nagios user:', 'nagios_user', $objects{'nagios_user'}[2],
	    $textsize{'long_name'}, '', $docs{'nagios_user'}, '', $tab++, 1 );
	$page .= Forms->text_box(
	    'Nagios group:',
	    'nagios_group', $objects{'nagios_group'}[2],
	    $textsize{'long_name'}, '', $docs{'nagios_group'}, '', $tab++, 1
	);
	$page .=
	  Forms->text_box( 'Lock file:', 'lock_file', $objects{'lock_file'}[2], $textsize{'long_name'}, '', $docs{'lock_file'}, '', $tab++, 1 );
	if ( $nagios_ver eq '3.x' ) {
	    $page .= Forms->text_box(
		'Precached object file:',
		'precached_object_file', $objects{'precached_object_file'}[2],
		$textsize{'long_name'}, '', $docs{'precached_object_file'},
		'', $tab++, 1
	    );
	}
	$page .=
	  Forms->text_box( 'Temp file:', 'temp_file', $objects{'temp_file'}[2], $textsize{'long_name'}, '', $docs{'temp_file'}, '', $tab++, 1 );
	$page .=
	  Forms->text_box( 'Temp path:', 'temp_path', $objects{'temp_path'}[2], $textsize{'long_name'}, '', $docs{'temp_path'}, '', $tab++, 1 );

	$page .= Forms->wizard_doc( 'State Retention Options', $docs{'state_retention_options'}, undef, 1 );
	$page .= Forms->checkbox(
	    'State retention option:',
	    'retain_state_information',
	    $objects{'retain_state_information'}[2],
	    $docs{'retain_state_information'},
	    '', $tab++, 1
	);
	$page .= Forms->text_box(
	    'State retention file:',
	    'state_retention_file', $objects{'state_retention_file'}[2],
	    $textsize{'long_name'}, '', $docs{'state_retention_file'},
	    '', $tab++, 1
	);
	$page .= Forms->text_box(
	    'Retention update interval:',
	    'retention_update_interval', $objects{'retention_update_interval'}[2],
	    $textsize{'small'}, '', $docs{'retention_update_interval'},
	    '', $tab++, 1
	);
	$page .= Forms->checkbox(
	    'Use retained program state:',
	    'use_retained_program_state',
	    $objects{'use_retained_program_state'}[2],
	    $docs{'use_retained_program_state'},
	    '', $tab++, 1
	);
	if ( $nagios_ver =~ /^[23]\.x$/ ) {
	    $page .= Forms->checkbox(
		'Use retained scheduling info:',
		'use_retained_scheduling_info',
		$objects{'use_retained_scheduling_info'}[2],
		$docs{'use_retained_scheduling_info'},
		'', $tab++, 1
	    );
	}
	if ( $nagios_ver eq '3.x' ) {
	    $page .= Forms->text_box(
		'Retained host attribute mask:',
		'retained_host_attribute_mask',
		$objects{'retained_host_attribute_mask'}[2],
		$textsize{'small'}, '', $docs{'retained_host_attribute_mask'},
		'', $tab++, 1
	    );
	    $page .= Forms->text_box(
		'Retained process host attribute mask:',
		'retained_process_host_attribute_mask',
		$objects{'retained_process_host_attribute_mask'}[2],
		$textsize{'small'}, '', $docs{'retained_process_host_attribute_mask'},
		'', $tab++, 1
	    );
	    $page .= Forms->text_box(
		'Retained contact host attribute mask:',
		'retained_contact_host_attribute_mask',
		$objects{'retained_contact_host_attribute_mask'}[2],
		$textsize{'small'}, '', $docs{'retained_contact_host_attribute_mask'},
		'', $tab++, 1
	    );
	    $page .= Forms->text_box(
		'Retained service attribute mask:',
		'retained_service_attribute_mask',
		$objects{'retained_service_attribute_mask'}[2],
		$textsize{'small'}, '', $docs{'retained_service_attribute_mask'},
		'', $tab++, 1
	    );
	    $page .= Forms->text_box(
		'Retained process service attribute mask:',
		'retained_process_service_attribute_mask',
		$objects{'retained_process_service_attribute_mask'}[2],
		$textsize{'small'}, '', $docs{'retained_process_service_attribute_mask'},
		'', $tab++, 1
	    );
	    $page .= Forms->text_box(
		'Retained contact service attribute mask:',
		'retained_contact_service_attribute_mask',
		$objects{'retained_contact_service_attribute_mask'}[2],
		$textsize{'small'}, '', $docs{'retained_contact_service_attribute_mask'},
		'', $tab++, 1
	    );
	}

	if ( $nagios_ver eq '3.x' ) {
	    $page .= Forms->wizard_doc( 'Large Installation Tweaks', $docs{'large_installation_tweaks'}, undef, 1 );
	    $page .= Forms->checkbox(
		'Use large installation tweaks:',
		'use_large_installation_tweaks',
		$objects{'use_large_installation_tweaks'}[2],
		$docs{'use_large_installation_tweaks'},
		'', $tab++, 1
	    );
	    $page .= Forms->checkbox(
		'Enable environment macros:',
		'enable_environment_macros',
		$objects{'enable_environment_macros'}[2],
		$docs{'enable_environment_macros'},
		'', $tab++, 1
	    );
	    $page .= Forms->checkbox(
		'Child processes fork twice:',
		'child_processes_fork_twice',
		$objects{'child_processes_fork_twice'}[2],
		$docs{'child_processes_fork_twice'},
		'', $tab++, 1
	    );
	    $page .= Forms->checkbox(
		'Free child process memory:',
		'free_child_process_memory',
		$objects{'free_child_process_memory'}[2],
		$docs{'free_child_process_memory'},
		'', $tab++, 1
	    );
	}

	$page .= Forms->wizard_doc( 'Logging Options', $docs{'logging_options'}, undef, 1 );
	$page .=
	  Forms->text_box( 'Log file:', 'log_file', $objects{'log_file'}[2], $textsize{'long_name'}, '', $docs{'log_file'}, '', $tab++, 1 );
	my @list = ( 'n', 'h', 'd', 'w', 'm' );
	$page .= Forms->list_box(
	    'Log rotation method:',
	    'log_rotation_method', \@list, $objects{'log_rotation_method'}[2],
	    '', $docs{'log_rotation_method'},
	    '', $tab++, 1
	);
	$page .= Forms->text_box(
	    'Log archive path:',
	    'log_archive_path', $objects{'log_archive_path'}[2],
	    $textsize{'long_name'}, '', $docs{'log_archive_path'},
	    '', $tab++, 1
	);
	$page .= Forms->checkbox(
	    'Notification logging option:',
	    'log_notifications',
	    $objects{'log_notifications'}[2],
	    $docs{'log_notifications'},
	    '', $tab++, 1
	);
	$page .= Forms->checkbox(
	    'Host check retry logging option',
	    'log_host_retries',
	    $objects{'log_host_retries'}[2],
	    $docs{'log_host_retries'},
	    '', $tab++, 1
	);
	$page .= Forms->checkbox(
	    'Service check retry logging option:',
	    'log_service_retries',
	    $objects{'log_service_retries'}[2],
	    $docs{'log_service_retries'},
	    '', $tab++, 1
	);
	$page .= Forms->checkbox(
	    'Event handler logging option',
	    'log_event_handlers',
	    $objects{'log_event_handlers'}[2],
	    $docs{'log_event_handlers'},
	    '', $tab++, 1
	);
	$page .= Forms->checkbox(
	    'Initial states logging option:',
	    'log_initial_states',
	    $objects{'log_initial_states'}[2],
	    $docs{'log_initial_states'},
	    '', $tab++, 1
	);
	$page .= Forms->checkbox(
	    'External command logging option:',
	    'log_external_commands',
	    $objects{'log_external_commands'}[2],
	    $docs{'log_external_commands'},
	    '', $tab++, 1
	);

	if ( $nagios_ver eq '1.x' ) {
	    $page .= Forms->checkbox(
		'Log passive service checks:',
		'log_passive_service_checks',
		$objects{'log_passive_service_checks'}[2],
		$docs{'log_passive_service_checks'},
		'', $tab++, 1
	    );
	}
	else {
	    $page .= Forms->checkbox(
		'Passive check logging option:',
		'log_passive_checks',
		$objects{'log_passive_checks'}[2],
		$docs{'log_passive_checks'},
		'', $tab++, 1
	    );
	}
	$page .= Forms->checkbox( 'Syslog logging option:', 'use_syslog', $objects{'use_syslog'}[2], $docs{'use_syslog'}, '', $tab++, 1 );

	$page .= Forms->wizard_doc( 'Miscellaneous Directives (optional)', $docs{'miscellaneous_options'}, undef, 1 );
	%misc_vals = StorProc->get_main_cfg_misc($gid);
	$page .= Forms->main_cfg_misc( \%misc_vals, $misc_name, $misc_value, $docs{'misc_directives'}, $tab++ );

	$page .= Forms->hidden( \%hidden );
	%save = ( 'name' => 'next', 'value' => 'Save and Done' );
	$page .= Forms->form_bottom_buttons( \%back, \%save, $tab++ );
    }
    elsif ( $step eq 'upload' ) {
	$page .= Forms->header( $page_title, $session_id, $top_menu );
	$page .= Forms->form_top_file("$form_title Upload");
	if (@errors) { $page .= Forms->form_errors( \@errors ) }
	$page .= Forms->wizard_doc('Upload Nagios main configuration file',
	    "Select the nagios.cfg file you wish to import. The set of values in your file will replace the complete set of Nagios main configuration values for the \"$gname\" group.", undef, 1);
	$page .= Forms->form_file( $tab++ );
	$page .= Forms->hidden( \%hidden );
	$page .= Forms->form_bottom_buttons( \%upload, \%cancel, $tab++ );
    }
    elsif ( $step eq 'saved' ) {
	$page .= Forms->header( $page_title, $session_id, $top_menu );
	$page .= Forms->form_top( "$form_title", '' );
	my @message = ("Changes to nagios configuration completed.");
	$page .= Forms->form_message( 'Saved:', \@message, 'row1' );
	delete $hidden{'task'};
	$page .= Forms->hidden( \%hidden );
	$page .= Forms->form_bottom_buttons( \%continue, $tab++ );
    }
    return $page;
}

#
############################################################################
# Nagios resource macros
#

sub resource_cfg($$) {
    my $gid          = shift;
    my $gname        = shift;
    my $task         = $query->param('submit');
    my $saved        = 0;
    my $resource     = undef;
    my $resource_sav = undef;
    my $file         = $query->param('upload_file');
    my $upload       = $query->param('upload');
    if ( $query->param('update_resource') ) {
	$resource_sav = $query->param('resource');
	my $resource_value = $query->param('resource_value');
	my $comment        = $query->param('comment');
	my %values         = ( 'value' => $resource_value );
	## FIX THIS:  Should we strip leading/trailing space from $resource_value, too?
	$comment =~ s/^\s+|\s+$//g;

	# We cannot use "insert ... on duplicate key update" because monarch_group_props
	# does not (yet) have a unique index on {group_id, name} and perhaps including
	# {type} as well, though it should.  So we simulate it here.
	if ($gid) {
	    my %where = ( 'group_id' => $gid, 'name' => $resource_sav );
	    my $result = StorProc->update_obj_where( 'monarch_group_props', \%values, \%where );
	    if ( $result =~ /error/i ) {
		push @errors, $result;
	    }
	    elsif ( $result == 0 ) {
		my @vals = ( \undef, $gid, $resource_sav, 'resource', $resource_value );
		my $result = StorProc->insert_obj( 'monarch_group_props', \@vals );
		if ( $result =~ /^Error/ ) { push @errors, $result }
	    }
	}
	else {
	    my $result = StorProc->update_obj( 'setup', 'name', $resource_sav, \%values );
	    if ( $result =~ /error/i ) {
		push @errors, $result;
	    }
	    elsif ( $result == 0 ) {
		my @vals = ( $resource_sav, 'resource', $resource_value );
		my $result = StorProc->insert_obj( 'setup', \@vals );
		if ( $result =~ /^Error/ ) { push @errors, $result }
	    }
	}

	my $label = $resource_sav;
	$label =~ s/user//;
	%values = ( 'value' => $comment );

	if ($gid) {
	    my %where = ( 'group_id' => $gid, 'name' => "resource_label$label" );
	    my $result = StorProc->update_obj_where( 'monarch_group_props', \%values, \%where );
	    if ( $result =~ /error/i ) {
		push @errors, $result;
	    }
	    elsif ( $result == 0 ) {
		my @vals = ( \undef, $gid, "resource_label$label", 'resource', $comment );
		my $result = StorProc->insert_obj( 'monarch_group_props', \@vals );
		if ( $result =~ /^Error/ ) { push @errors, $result }
	    }
	}
	else {
	    my $result = StorProc->update_obj( 'setup', 'name', "resource_label$label", \%values );
	    if ( $result =~ /error/i ) {
		push @errors, $result;
	    }
	    elsif ( $result == 0 ) {
		my @vals = ( "resource_label$label", 'resource', $comment );
		my $result = StorProc->insert_obj( 'setup', \@vals );
		if ( $result =~ /^Error/ ) { push @errors, $result }
	    }
	}

	unless (@errors) {
	    $resource_sav = undef;
	    $resource     = undef;
	    $query->delete('resource_macro');
	}
    }
    elsif ( $query->param('sync') ) {
	my %where = ( 'type' => 'resource' );
	my %main_object = StorProc->fetch_list_hash_array( 'setup', \%where );
	%where = ( 'group_id' => $gid, 'type' => 'resource' );
	my $result = StorProc->delete_one_where( 'monarch_group_props', \%where );
	if ( $result =~ /^Error/ ) { push @errors, $result }
	foreach my $object ( keys %main_object ) {
	    my @vals = ( \undef, $gid, $main_object{$object}[0], 'resource', $main_object{$object}[2] );
	    my $result = StorProc->insert_obj( 'monarch_group_props', \@vals );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	}
    }
    elsif ( $upload && $file ) {
	my ($filedata, $errs) = StorProc->upload( '/tmp', $file );
	my @errs = @$errs;
	if (@errs) { push @errors, @errs }
	unless (@errors) {
	    my @errs = StorProc->import_resource_cfg($gid, $file, $filedata, 1);
	    if (@errs) { push( @errors, @errs ) }
	}
	unless (@errors) { $upload = undef }
    }
    my $page = Forms->header( $page_title, $session_id, $top_menu );
    if ($upload) {
	$page .= Forms->form_top_file("$gname Nagios Resource Macros Upload");
	if (@errors) { $page .= Forms->form_errors( \@errors ) }
	$page .= Forms->wizard_doc('Upload Nagios resource macro file',
	    "Select the resource.cfg file you wish to import. The set of values in your file will replace the complete set of \$USERn\$ values for the \"$gname\" group.", undef, 1);
	$page .= Forms->form_file( $tab++ );
	$page .= Forms->hidden( \%hidden );
	$page .= Forms->form_bottom_buttons( \%upload, \%cancel, $tab++ );
    }
    else {
	$page .= Forms->form_top("$gname Nagios Resource Macros", '', '', '100%' );
	my $resource_value = undef;
	if (@errors) { $page .= Forms->form_errors( \@errors ) }
	my %resources    = StorProc->get_resource_values($gid);
	my %resource_doc = ();
	my %selected     = ();

	$resource = $resource_sav || $query->param('resource_macro');
	if ($resource) {
	    $resource_value = $resources{$resource};
	    %selected = ( 'name' => $resource, 'value' => $resource_value );
	}
	else {
	    $page .= Forms->wizard_doc('Edit resource macros',
		'In this screen, you may modify the values of the Nagios resource macros. These values can be symbolically referenced in commands as $USER1$ through $USER32$. Using these symbols instead of literal values in your commands makes it much easier to modify all related commands at one time, in this central place.', undef, 1);
	}
	$page .= Forms->resource_select( \%resources, \%resource_doc, \%selected, $top_menu, $tab++ );
	$page .= Forms->hidden( \%hidden );
	if ($gid) {
	    my %sync = ( 'name' => 'sync', 'value' => 'Sync With Main' );
	    $page .= Forms->form_bottom_buttons( \%close, \%upload, \%sync, $tab++ );
	}
	else {
	    $page .= Forms->form_bottom_buttons( \%close, $tab++ );
	}
    }
    return $page;
}

#
############################################################################
# Pre-Flight Test
#

sub pre_flight($) {
    my $group   = shift;
    my $page    = undef;
    if ( $query->param('refreshed') ) {
	my $group = $query->param('group');
	$page .= Forms->header( $page_title, $session_id, $top_menu );
	$page .= Forms->form_top( 'Nagios Pre-Flight Test', '' );
	my $errors = StorProc->check_version( $monarch_ver );
	push @errors, @$errors if @$errors;
	if (@errors) { $page .= Forms->form_errors( \@errors ); @errors = (); }
	my $results;
	my $files;
	( $errors, $results, $files ) =
	  StorProc->synchronized_preflight( $user_acct, $nagios_ver, $nagios_etc, $nagios_bin, $monarch_home, $group, 'html' );
	$page .= Forms->form_message( 'Error(s) building file(s):', $errors, 'error' ) if @$errors;
	## FIX THIS:  make the fourth argument a pattern, not a binary flag
	$page .= Forms->form_message( 'Results:', $results, 'row1', 1, 1 ) if @$results;
	$hidden{'obj'} = undef;
	$page .= Forms->hidden( \%hidden );
	$page .= Forms->form_bottom_buttons( \%continue, $tab++ );
    }
    else {
	my $now = time;
	$refresh_url = "?update_main=1&amp;nocache=$now&amp;refreshed=1&amp;group=$group";
	foreach my $name ( keys %hidden ) {
	    $refresh_url .= qq(&amp;$name=) . (defined( $hidden{$name} ) ? $hidden{$name} : '');
	}
	$page .= Forms->header( $page_title, $session_id, $top_menu, $refresh_url );
	$page .= Forms->form_top( 'Nagios Pre-Flight Test', '' );
	my $errors = StorProc->check_version( $monarch_ver );
	push @errors, @$errors if @$errors;
	if (@errors) { $page .= Forms->form_errors( \@errors ) }
	$page .= Forms->form_doc('Running pre-flight check ...');
	$page .= Forms->form_bottom_buttons();
    }
    return $page;
}

#
############################################################################
# Control Center
#

sub build_externals() {
    my $page = '';
    if ( $query->param('refreshed') ) {
	use MonarchExternals;
	my ( $results, $errors ) = Externals->build_all_externals( $user_acct, $session_id, '1' );
	my @results = @$results;
	my @errors  = @$errors;
	$page .= Forms->header( $page_title, $session_id, $top_menu );
	$page .= Forms->form_top( 'Build Externals', '' );
	$page .= Forms->form_message( 'Error(s):', \@errors, 'error' ) if @errors;
	$page .= Forms->form_message( 'Results:', \@results, 'row1' );
	$hidden{'obj'} = undef;
	$page .= Forms->hidden( \%hidden );
	$page .= Forms->form_bottom_buttons( \%continue, $tab++ );
    }
    else {
	my $now = time;
	$refresh_url = "?update_main=1&amp;nocache=$now&amp;refreshed=1";
	foreach my $name ( keys %hidden ) {
	    $refresh_url .= qq(&amp;$name=) . ( defined( $hidden{$name} ) ? $hidden{$name} : '' );
	}
	$page .= Forms->header( $page_title, $session_id, $top_menu, $refresh_url );
	$page .= Forms->form_top( 'Build Externals', '' );
	my $errors = StorProc->check_version($monarch_ver);
	push @errors, @$errors if @$errors;
	$page .= Forms->form_errors( \@errors ) if @errors;
	$page .= Forms->form_doc('Building externals ...');
	$page .= Forms->form_bottom_buttons();
    }
    return $page;
}

sub control() {
    local $_;

    my @menus = ();
    my $page  = undef;
    if (   $query->param('close')
	|| $query->param('continue')
	|| ( $query->param('cancel') && defined($obj) && $obj ne 'back_up_and_restore' ) )
    {
	$page .= Forms->header( $page_title, $session_id, $top_menu );
    }
    else {
	##
	######################################################################
	# Users
	#
	if ( $obj eq 'users' ) {
	    @errors = ();
	    $table  = 'users';
	    my $user      = $query->param('mod_user');
	    my $user_name = $query->param('user_name');
	    my @password  = $query->$multi_param('passwd');
	    if ( $query->param('task') eq 'No' ) { $task = 'modify' }
	    if ( $query->param('add') && $user ) {
		my $id = undef;
		$user =~ s/^\s+|\s+$//g;
		my %p = StorProc->fetch_one( 'users', 'user_acct', $user );
		if ( !$password[1] ) { $password[1] = 1 }
		unless ( $authentication{'disabled'} ) {
		    if ( $password[0] eq $password[1] ) { $password[1] = undef }
		}
		else {
		    $password[1] = undef;
		}
		unless ( $p{'user_acct'} || $user eq '' || $password[1] ) {
		    my $now = time;
		    $now = $now - 100000;
		    my @saltchars = ( 'a' .. 'z', 'A' .. 'Z', '0' .. '9', ',', '/' );
		    srand( time() ^ ( $$ + ( $$ << 15 ) ) );
		    my $salt = $saltchars[ int( rand(64) ) ];
		    $salt .= $saltchars[ int( rand(64) ) ];
		    my $newpw = crypt( $password[0], $salt );
		    my @values = ( \undef, $user, $user_name, $newpw, $now );
		    $id = StorProc->insert_obj_id( $table, \@values, 'user_id' );
		    if ( $id =~ /^Error/ ) { push @errors, $id }
		}
		else {
		    if ( $p{'user_acct'} ) {
			push @errors, "User id \"$user\" already exists.";
		    }
		    if ( $user eq '' ) { push @errors, "Required: User id" }
		    if ( $password[1] ) {
			push @errors, "Check password fields. They are either blank or a mismatch.";
		    }
		}
		unless (@errors) {
		    my @user_groups = $query->$multi_param('user_groups');
		    my @ugs = StorProc->get_ids( 'usergroup_id', 'user_groups', \@user_groups );
		    foreach (@ugs) {
			my @values = ( $_, $id );
			my $result = StorProc->insert_obj( 'user_group', \@values );
			if ( $result =~ /^Error/ ) { push @errors, $result }
		    }
		}
		unless (@errors) {
		    $page .= Forms->header( $page_title, $session_id, $top_menu );
		    $page .= Forms->form_top( "User Account", '' );
		    my @message = ("User \"$user\" added.");
		    $page .= Forms->form_message( 'Added:', \@message, 'row1' );
		    ( $task, $user ) = undef;
		    delete $hidden{'task'};
		    $page .= Forms->hidden( \%hidden );
		    $page .= Forms->form_bottom_buttons( \%continue, $tab++ );
		}
	    }
	    elsif ( $query->param('save') ) {
		my %values = ();
		if ( !$password[1] ) { $password[1] = 1 }
		if ( $query->param('set_password') ) {
		    if ( $password[0] eq $password[1] ) { $password[1] = undef }
		}
		else {
		    $password[1] = undef;
		}
		unless ( $password[1] ) {
		    $values{'user_name'} = $user_name;
		    my @saltchars = ( 'a' .. 'z', 'A' .. 'Z', '0' .. '9', ',', '/' );
		    srand( time() ^ ( $$ + ( $$ << 15 ) ) );
		    my $salt = $saltchars[ int( rand(64) ) ];
		    $salt .= $saltchars[ int( rand(64) ) ];
		    $values{'password'} = crypt( $password[0], $salt );
		    my $result = StorProc->update_obj( 'users', 'user_acct', $user, \%values );
		    if ( $result =~ /^Error/ ) { push @errors, $result }

		    unless ( $user eq 'super_user' ) {
			my %u = StorProc->fetch_one( 'users', 'user_acct', $user );
			$result = StorProc->delete_all( 'user_group', 'user_id', $u{'user_id'} );
			if ( $result =~ /^Error/ ) { push @errors, $result }
			my @user_groups = $query->$multi_param('user_groups');
			my @ugs = StorProc->get_ids( 'usergroup_id', 'user_groups', \@user_groups );
			foreach (@ugs) {
			    my @values = ( $_, $u{'user_id'} );
			    my $result = StorProc->insert_obj( 'user_group', \@values );
			    if ( $result =~ /^Error/ ) { push @errors, $result }
			}
		    }
		}
		else {
		    push @errors, "Check password field. It's either blank or a mismatch.";
		}
		unless (@errors) {
		    $page .= Forms->header( $page_title, $session_id, $top_menu );
		    my $message = "Changes accepted.";
		    $page .= Forms->form_top( "User Account", '' );
		    my @message = ("Changes to \"$user\" accepted.");
		    $page .= Forms->form_message( 'Saved:', \@message, 'row1' );
		    ( $task, $user ) = undef;
		    delete $hidden{'task'};
		    $page .= Forms->hidden( \%hidden );
		    $page .= Forms->form_bottom_buttons( \%continue, $tab++ );
		}
	    }
	    elsif ( $query->param('confirm_delete') ) {
		my $result = StorProc->delete_all( 'users', 'user_acct', $user );
		if ( $result =~ /^Error/ ) { push @errors, $result }
		unless (@errors) {
		    $page .= Forms->header( $page_title, $session_id, $top_menu, '', '1' );
		    my $message = "User \"$user\" deleted.";
		    $page .= Forms->form_top( "User Account", '' );
		    my @message = ("Changes to \"$user\" accepted.");
		    $page .= Forms->form_message( 'Removed:', \@message, 'row1' );
		    ( $task, $user ) = undef;
		    delete $hidden{'task'};
		    $page .= Forms->hidden( \%hidden );
		    $page .= Forms->form_bottom_buttons( \%continue, $tab++ );
		}
	    }
	    elsif ( $query->param('delete') ) {
		$page .= Forms->header( $page_title, $session_id, $top_menu );
		$hidden{'mod_user'} = $user;
		my $message = qq(Are you sure you want to remove \"$user\"?);
		$page .= Forms->are_you_sure( 'Confirm Delete', $message, 'confirm_delete', \%hidden );
		$user = undef;
		$task = 'Delete';
	    }
	    if ( @errors || $user || $task =~ /Add|new/i ) {
		$page .= Forms->header( $page_title, $session_id, $top_menu );
		my @members = $query->$multi_param('user_groups');
		$page .= Forms->form_top( 'User Account', 'onsubmit="selIt();"' );
		if (@errors) { $page .= Forms->form_errors( \@errors ) }
		if ( $task =~ /Add|new/ ) {
		    $page .= Forms->text_box( 'Userid:', 'mod_user', $user, $textsize{'short_name'}, $required{'user_acct'} );
		    $page .= Forms->text_box( 'User name:', 'user_name', $user_name, $textsize{'long_name'} );
		    $hidden{'set_password'} = 1;
		}
		else {
		    my %p = StorProc->fetch_one( 'users', 'user_acct', $user );
		    if ( !$members[0] ) {
			@members = StorProc->get_names_in( 'usergroup_id', 'user_groups', 'user_group', 'user_id', $p{'user_id'} );
		    }
		    $page .= Forms->display_hidden( 'User id:', 'mod_user', $user );
		    $page .= Forms->text_box( 'User name:', 'user_name', $p{'user_name'}, $textsize{'long_name'} );
		    $page .= Forms->checkbox( 'Set password:', 'set_password', scalar $query->param('set_password') );
		}
		$page .= Forms->password_box( 'Password:',         'passwd', $textsize{'short_name'}, $required{'password'} );
		$page .= Forms->password_box( 'Password confirm:', 'passwd', $textsize{'short_name'}, $required{'password'} );
		%save = ( 'name' => 'save', 'value' => 'Save' );
		unless ( $user eq 'super_user' ) {
		    my @nonmembers = StorProc->fetch_list( 'user_groups', 'name' );
		    $page .= Forms->members( 'User groups:', 'user_groups', \@members, \@nonmembers );
		    $page .= Forms->hidden( \%hidden );
		    if ( $task =~ /Add|new/ ) {
			$page .= Forms->form_bottom_buttons( \%add, \%cancel, $tab++ );
		    }
		    else {
			$page .= Forms->form_bottom_buttons( \%save, \%delete, \%cancel, $tab++ );
		    }
		}
		else {
		    $page .= Forms->hidden( \%hidden );
		    $page .= Forms->form_bottom_buttons( \%save, \%cancel, $tab++ );
		}
	    }
	}

	#
	#################################################################
	# User Groups
	#
	elsif ( $obj eq 'user_groups' ) {
	    @errors = ();
	    $table  = 'user_groups';
	    my $groupid     = $query->param('groupid');
	    my $description = $query->param('description');
	    if ( $query->param('task') eq 'No' ) { $task = 'access_list' }
	    my $access_set = $query->param('access_set');
	    if ($access_set) { $task = 'access_list' }
	    my $access_type   = $query->param('access_type');
	    my $update_assets = undef;
	    my $saved         = 0;
	    my @message       = ();

	    if (   $query->param('continue')
		|| $query->param('close')
		|| $query->param('cancel') )
	    {
		$page .= Forms->header( $page_title, $session_id, $top_menu );
	    }
	    elsif ( $query->param('add') && $groupid ) {
		$groupid =~ s/^\s+|\s+$//g;
		my %p = StorProc->fetch_one( 'user_groups', 'name', $groupid );
		unless ( $p{'name'} ) {
		    my @values = ( \undef, $groupid, $description );
		    my $result = StorProc->insert_obj( $table, \@values );
		    if ( $result =~ /^Error/ ) { push @errors, $result }
		}
		else {
		    push @errors, "Check the name field. It's either blank or that name is already in use.";
		}
		unless (@errors) {
		    $task = 'access_list';
		}
	    }
	    elsif ( $query->param('save') ) {
		my %values = ();
		$values{'description'} = $description;
		my $result = StorProc->update_obj( $table, 'name', $groupid, \%values );
		if ( $result =~ /^Error/ ) { push @errors, $result }
		$task = 'saved';
	    }
	    elsif ( $query->param('update_access') ) {
		my %g      = StorProc->fetch_one( 'user_groups', 'name', $groupid );
		my $type   = undef;
		my @assets = $query->$multi_param('access_list');
		if ( $access_set eq 'tools' || $access_set eq 'control' ) {
		    my %where = (
			'usergroup_id' => $g{'usergroup_id'},
			'type'         => $access_set
		    );
		    my $result = StorProc->delete_one_where( 'access_list', \%where );
		    if ( $result =~ /^Error/ ) { push @errors, $result }
		    foreach my $asset (@assets) {
			my @values = ( $asset, $access_set, $g{'usergroup_id'}, 'full_control' );
			my $result = StorProc->insert_obj( 'access_list', \@values );
			if ( $result =~ /^Error/ ) { push @errors, $result }
		    }
		}
		elsif ( $access_set eq 'EZ' ) {
		    my %where = ( 'usergroup_id' => $g{'usergroup_id'}, 'type' => 'ez' );
		    my $result = StorProc->delete_one_where( 'access_list', \%where );
		    if ( $result =~ /^Error/ ) { push @errors, $result }
		    my $enable_ez = $query->param('enable_ez');
		    if ($enable_ez) {
			my @values = ( $enable_ez, 'ez', $g{'usergroup_id'}, $enable_ez );
			my $result = StorProc->insert_obj( 'access_list', \@values );
			if ( $result =~ /^Error/ ) { push @errors, $result }
		    }
		    my $ez_view = $query->param('ez_view');
		    if ($ez_view) {
			my @values = ( $ez_view, 'ez', $g{'usergroup_id'}, $ez_view );
			my $result = StorProc->insert_obj( 'access_list', \@values );
			if ( $result =~ /^Error/ ) { push @errors, $result }
		    }
		    if ( $result =~ /^Error/ ) { push @errors, $result }
		    foreach my $asset (@assets) {
			my @values = ( "ez_$asset", 'ez', $g{'usergroup_id'}, "ez_$asset" );
			my $result = StorProc->insert_obj( 'access_list', \@values );
			if ( $result =~ /^Error/ ) { push @errors, $result }
		    }
		}
		elsif ( $access_set eq 'groups' ) {
		    my %group_name = StorProc->get_table_objects('monarch_groups');
		    my %where      = (
			'usergroup_id' => $g{'usergroup_id'},
			'type'         => 'group_macro'
		    );
		    my $result = StorProc->delete_one_where( 'access_list', \%where );
		    if ( $result =~ /^Error/ ) { push @errors, $result }
		    foreach my $asset (@assets) {
			if ( $asset eq 'manage' ) {
			    my @values = ( $asset, 'group_macro', $g{'usergroup_id'}, 'manage' );
			    my $result = StorProc->insert_obj( 'access_list', \@values );
			    if ( $result =~ /^Error/ ) { push @errors, $result }
			}
			else {
			    my @values = ( $group_name{$asset}, 'group_macro', $g{'usergroup_id'}, $asset );
			    my $result = StorProc->insert_obj( 'access_list', \@values );
			    if ( $result =~ /^Error/ ) { push @errors, $result }
			}
		    }
		}
		else {
		    my %assets = ();
		    my %vals   = ();
		    my %where  = (
			'usergroup_id' => $g{'usergroup_id'},
			'type'         => $access_set
		    );
		    my $result = StorProc->delete_one_where( 'access_list', \%where );
		    if ( $result =~ /^Error/ ) { push @errors, $result }
		    foreach my $asset ( $query->param ) {
			if ( $asset eq 'nocache' ) { next }
			if ( $asset =~ /(^\S+)-(\S+)-(.*)/ ) {
			    my $obj = $3;
			    $assets{$obj} = $1;
			    $vals{$obj} .= "$2,";
			}
		    }
		    foreach my $asset ( keys %assets ) {
			$vals{$asset} =~ s/,$//;
			my @values = ( $asset, $assets{$asset}, $g{'usergroup_id'}, $vals{$asset} );
			my $result = StorProc->insert_obj( 'access_list', \@values );
			if ( $result =~ /^Error/ ) { push @errors, $result }
		    }
		}
		unless (@errors) {
		    @message = ("Changes to access set \"$access_set\" accepted.");
		    $saved   = 1;
		}
		$task = 'access_list';
	    }
	    elsif ($groupid ne 'super_users' && $query->param('confirm_delete') ) {
		my $result = StorProc->delete_all( 'user_groups', 'name', $groupid );
		if ( $result =~ /^Error/ ) { push @errors, $result }
		unless (@errors) {
		    $page .= Forms->header( $page_title, $session_id, $top_menu, '', '1' );
		    $page .= Forms->form_top( "User Group", '' );
		    my @message = ("User group \"$groupid\" deleted.");
		    $page .= Forms->form_message( 'Removed:', \@message, 'row1' );
		    ( $task, $groupid ) = undef;
		    delete $hidden{'task'};
		    $page .= Forms->hidden( \%hidden );
		    $page .= Forms->form_bottom_buttons( \%continue, $tab++ );
		    $task = 'delete';
		}
		else {
		    $task = 'access_list';
		}
	    }
	    elsif ( $groupid ne 'super_users' && $query->param('delete') ) {
		$page .= Forms->header( $page_title, $session_id, $top_menu );
		$hidden{'groupid'} = $groupid;
		$hidden{'task'}    = 'access_list';
		my $message = qq(Are you sure you want to remove \"$groupid\"?);
		$page .= Forms->are_you_sure( 'Confirm Delete', $message, 'confirm_delete', \%hidden );
		$groupid = undef;
		$task    = 'delete';
	    }
	    if ( $task eq 'new' ) {
		$page .= Forms->header( $page_title, $session_id, $top_menu );
		$page .= Forms->form_top( 'User Group', '' );
		if (@errors) { $page .= Forms->form_errors( \@errors ) }
		$page .= Forms->text_box( 'Group id:', 'groupid', '', $textsize{'short_name'}, $required{'groupid'} );
		$page .= Forms->text_box( 'Description:', 'description', $description, $textsize{'long_name'} );
		delete $hidden{'task'};
		$page .= Forms->hidden( \%hidden );
		$page .= Forms->form_bottom_buttons( \%add, \%cancel, $tab++ );
	    }
	    elsif ( $task eq 'access_list' || $query->param('access_list') ) {
		unless ( $groupid eq 'super_users' ) {
		    $page .= Forms->header( $page_title, $session_id, $top_menu );
		    my %access_button = ();
		    if (@errors) { $page .= Forms->form_errors( \@errors ) }
		    my %p = StorProc->fetch_one( 'user_groups', 'name', $groupid );
		    $description = $p{'description'};
		    if ( !$access_set ) { $access_set = 'design_manage' }
		    $hidden{'groupid'}    = $groupid;
		    $hidden{'access_set'} = $access_set;
		    my @menus = ( 'design_manage', 'groups', 'tools', 'control' );
		    if ($enable_ez) { push @menus, 'EZ' }
		    $page .= Forms->access_top( $groupid, $session_id, $access_set, \@menus );
		    my %g = StorProc->fetch_one( 'user_groups', 'name', $groupid );

		    if ($saved) {
			$page .= Forms->hidden( \%hidden );
			$page .= Forms->form_message( 'Saved:', \@message, 'row1' );
		    }
		    elsif ( $access_set eq 'tools' ) {
			my @tool_menus = ( 'import_from_files', 'export_to_files' );
			$access_type = 'tools';
			my %values = (
			    'usergroup_id' => $g{'usergroup_id'},
			    'type'         => 'tools'
			);
			my @selected = ();
			my %selected_hash = StorProc->fetch_list_hash_array( 'access_list', \%values );
			foreach my $key ( keys %selected_hash ) {
			    push @selected, $key;
			}
			$page .= Forms->hidden( \%hidden );
			$page .= Forms->access_checkbox_list( 'Tools:', 'access_list', \@tool_menus, \@selected, 1 );
		    }
		    elsif ( $access_set eq 'control' ) {
			my @control_menus = (
			    'users', 'user_groups', 'setup', 'nagios_cgi_configuration', 'nagios_main_configuration', 'nagios_resource_macros',
			    'pre_flight_test', 'commit'
			);
			$access_type = 'control';
			my %assets_selected = undef;
			my %values          = (
			    'usergroup_id' => $g{'usergroup_id'},
			    'type'         => 'control'
			);
			my @selected = ();
			my %selected_hash = StorProc->fetch_list_hash_array( 'access_list', \%values );
			foreach my $key ( keys %selected_hash ) {
			    push @selected, $key;
			}
			$page .= Forms->hidden( \%hidden );
			$page .= Forms->access_checkbox_list( 'Control list:', 'access_list', \@control_menus, \@selected, 1 );
		    }
		    elsif ( $access_set eq 'groups' ) {
			my %docs     = Doc->access_list();
			my @selected = ();
			my %where    = (
			    'usergroup_id' => $g{'usergroup_id'},
			    'type'         => 'group_macro'
			);
			my %selected_hash = StorProc->fetch_list_hash_array( 'access_list', \%where );
			my @monarch_group_macro = ('manage');
			if ( $selected_hash{'manage'} ) {
			    @selected = ('manage');
			}
			$page .= Forms->wizard_doc( 'Groups', $docs{'groups'}, undef, 1 );
			$page .= Forms->checkbox_list( 'Groups and macros:', 'access_list', \@monarch_group_macro, \@selected );
			my %group_name = StorProc->get_table_objects( 'monarch_groups', '1' );
			my @groups = StorProc->fetch_list( 'monarch_groups', 'name' );
			foreach my $key ( keys %selected_hash ) {
			    push @selected, $group_name{$key};
			}
			$page .= Forms->hidden( \%hidden );
			$page .= Forms->access_checkbox_list( 'Administered groups:', 'access_list', \@groups, \@selected );
		    }
		    elsif ( $access_set eq 'EZ' ) {
			my %docs     = Doc->access_list();
			my @selected = ();
			my %where    = (
			    'usergroup_id' => $g{'usergroup_id'},
			    'type'         => 'ez'
			);
			my %selected_hash = StorProc->fetch_list_hash_array( 'access_list', \%where );
			foreach my $key ( keys %selected_hash ) {
			    $key =~ s/ez_//;
			    push @selected, $key;
			}
			my @ez_set = ( 'enable', 'primary_interface', 'only_interface' );
			if ( $selected_hash{'manage'} ) {
			    @selected = ('manage');
			}
			$page .= Forms->wizard_doc( 'EZ Interface', $docs{'ez'}, undef, 1 );
			$page .= Forms->access_settings_ez( \%selected_hash );
			my @ez_options = ( 'hosts', 'import', 'discover', 'host_groups', 'profiles', 'notifications', 'commit', 'setup' );
			$page .= Forms->hidden( \%hidden );
			$page .= Forms->access_checkbox_list( 'EZ options:', 'access_list', \@ez_options, \@selected, 1 );
		    }
		    else {
			my @access_list =
			  ( 'time_periods', 'commands', 'contact_templates', 'contacts', 'contactgroups', 'escalations', 'profiles' );
			push( @access_list,
			    ( 'hosts', 'host_templates', 'extended_host_info_templates', 'hostgroups', 'parent_child', 'host_dependencies' ) );
			push @access_list,
			  ( 'services', 'service_templates', 'service_dependency_templates', 'extended_service_info_templates' );
			if ( $nagios_ver =~ /^[23]\.x$/ ) {
			    push @access_list, 'service_groups';
			}
			if ($enable_externals) {
			    push @access_list, 'externals';
			}
			$access_type = 'design_manage';
			my %assets_selected = undef;
			my %values          = (
			    'usergroup_id' => $g{'usergroup_id'},
			    'type'         => $access_type
			);
			my %access_list_values = StorProc->fetch_list_hash_array( 'access_list', \%values );
			foreach my $key ( keys %access_list_values ) {
			    $assets_selected{$key} = $access_list_values{$key}[3];
			}
			$page .= Forms->hidden( \%hidden );
			$page .= Forms->access_list( 'Design/Manage', \@access_list, \%assets_selected, $access_type );
		    }
		}
	    }
	    elsif ( $task eq 'saved' ) {
		$page .= Forms->header( $page_title, $session_id, $top_menu );
		$page .= Forms->form_top( 'User Group', '' );
		$page .= Forms->display_hidden( 'Saved:', '', $groupid );
		$page .= Forms->hidden( \%hidden );
		$page .= Forms->form_bottom_buttons( \%close );
	    }
	    elsif ( $task eq 'modify' ) {
		my $groupid = $query->param('name');
		$page .= Forms->header( $page_title, $session_id, $top_menu );
		my %p = StorProc->fetch_one( 'user_groups', 'name', $groupid );
		$description = $p{'description'};
		$page .= Forms->form_top( 'User Group', '' );
		$page .= Forms->display_hidden( 'Group id:', 'groupid', $groupid );
		$page .= Forms->text_box( 'Description:', 'description', $description, $textsize{'long_name'} );
		$page .= Forms->hidden( \%hidden );
		my %set = ( 'name' => 'access_list', 'value' => 'Set Access Values' );

		if ( $groupid eq 'super_users' ) {
		    $page .= Forms->form_bottom_buttons( \%save, \%close );
		}
		else {
		    $page .= Forms->form_bottom_buttons( \%save, \%set, \%delete, \%close );
		}
	    }
	}

	#
	##################################################################
	# Setup
	#
	elsif ( $obj eq 'setup' ) {
	    @errors = ();
	    my $saved = 0;
	    if ( $query->param('save') ) {
		my %where       = ();
		my %cfg         = StorProc->fetch_list_hash_array( 'setup', \%where );
		my @setup_props = (
		    'cgi_home',             'login_authentication', 'session_timeout', 'nagios_etc',
		    'nagios_bin',           'nagios_version',       'upload_dir',      'backup_dir',
		    'max_unlocked_backups', 'enable_externals',     'enable_groups',   'enable_ez'
		);
		foreach my $name (@setup_props) {
		    my %values = ();
		    my $value  = $query->param($name);
		    $value =~ s/^\s+|\s+$//g;
		    unless ($value) { $value = 0 }
		    if ( $name eq 'max_unlocked_backups' && ( $value !~ /^\d+$/ || ( $value != 0 && $value < 10 ) ) ) {
			push @errors, 'You specified an invalid value for "Max unlocked backups".  It must be blank, 0, or at least 10.  The previous value has been retained.';
		    }
		    else {
			if ( $cfg{$name}[0] ) {
			    $values{'value'} = $value;
			    my $result = StorProc->update_obj( 'setup', 'name', $name, \%values );
			    if ( $result =~ /^Error/ ) { push @errors, $result }
			}
			else {
			    my @vals = ( $name, 'config', $value );
			    my $result = StorProc->insert_obj( 'setup', \@vals );
			    if ( $result =~ /^Error/ ) { push @errors, $result }
			}
		    }
		}
		unless (@errors) { $saved = 1 }
	    }
	    if ($saved) {
		$refresh_left = 1;  # in case externals support changed
		$page .= Forms->header( $page_title, $session_id, $top_menu, '', $refresh_left );
		$page .= Forms->form_top( 'Setup', '' );
		$page .= Forms->form_doc('Updated: Changes to setup accepted.');
		$page .= Forms->hidden( \%hidden );
		$page .= Forms->form_bottom_buttons( \%close, $tab++ );
	    }
	    else {
		my %docs = Doc->setup();
		$page .= Forms->header( $page_title, $session_id, $top_menu );
		$page .= Forms->form_top( 'Setup', '' );
		my $errors = StorProc->check_version( $monarch_ver );
		push @errors, @$errors if @$errors;
		if (@errors) { $page .= Forms->form_errors( \@errors ) }
		$page .= Forms->display_hidden( 'Monarch version:', 'monarch_version', $monarch_ver, $docs{'monarch_version'} );
		if ($is_portal) {
		    $page .= Forms->display_hidden( 'Nagios version:',     'nagios_version', $nagios_ver,   $docs{'nagios_version'} );
		    $page .= Forms->display_hidden( 'Nagios etc:',         'nagios_etc',     $nagios_etc,   $docs{'nagios_etc'} );
		    $page .= Forms->display_hidden( 'Nagios bin:',         'nagios_bin',     $nagios_bin,   $docs{'nagios_bin'} );
		    $page .= Forms->display_hidden( 'Configuration home:', 'monarch_home',   $monarch_home, $docs{'monarch_home'} );
		    $page .= Forms->display_hidden( 'Backup directory:',   'backup_dir',     $backup_dir,   $docs{'backup_home'} );
		    $hidden{'upload_dir'}    = $upload_dir;
		    $hidden{'enable_groups'} = 1;
		    $hidden{'enable_ez'}     = 1;
		}
		else {
		    my %p = StorProc->fetch_one( 'setup', 'name', 'login_authentication' );
		    my @members = ( 'active', 'passive', 'none' );
		    $page .= Forms->list_box( 'Login authentication:',
			'login_authentication', \@members, $p{'value'}, '', $docs{'login_authentication'} );
		    %p = StorProc->fetch_one( 'setup', 'name', 'session_timeout' );
		    $page .= Forms->text_box( 'Session timeout seconds:', 'session_timeout', $p{'value'}, '5', '', $docs{'session_timeout'} );
		    @members = ( '1.x', '2.x', '3.x' );
		    $page .= Forms->list_box( 'Nagios version:', 'nagios_version', \@members, $nagios_ver, '', $docs{'nagios_version'} );
		    $page .= Forms->text_box( 'Nagios etc:', 'nagios_etc', $nagios_etc, $textsize{'long_name'}, '', $docs{'nagios_etc'} );
		    $page .= Forms->text_box( 'Nagios bin:', 'nagios_bin', $nagios_bin, $textsize{'long_name'}, '', $docs{'nagios_bin'} );
		    $page .= Forms->display_hidden( 'Monarch home:', 'monarch_home', $monarch_home, $docs{'monarch_home'} );
		    $page .= Forms->text_box( 'Backup directory:', 'backup_dir', $backup_dir, $textsize{'long_name'}, '', $docs{'backup_dir'} );
		    $page .= Forms->text_box( 'Upload dir:',       'upload_dir', $upload_dir, $textsize{'long_name'}, '', $docs{'upload_dir'} );
		    $page .= Forms->checkbox( 'Enable groups:', 'enable_groups', $enable_groups, $docs{'enable_groups'} );
		    $page .= Forms->checkbox( 'Enable EZ:',     'enable_ez',     $enable_ez,     $docs{'ez'} );
		}
		my %p = StorProc->fetch_one( 'setup', 'name', 'max_unlocked_backups' );
		$page .= Forms->text_box( 'Max unlocked backups:', 'max_unlocked_backups', $p{'value'}, $textsize{'small'}, '', $docs{'max_unlocked_backups'}, '', $tab++);
		$page .= Forms->checkbox( 'Enable externals:', 'enable_externals', $enable_externals, $docs{'enable_externals'}, '', $tab++ );
		$page .= Forms->hidden( \%hidden );
		$help{url} = StorProc->doc_section_url('How+to+configure+externals');
		$page .= Forms->form_bottom_buttons( \%save, \%cancel, \%help, $tab++ );
	    }
	}

	#
	##################################################################
	# Nagios cgi
	#
	elsif ( $obj eq 'nagios_cgi_configuration' ) {
	    my $step = $query->param('step');
	    $page .= nagios_cgi( '', '' );
	}

	#
	##################################################################
	# Nagios main
	#
	elsif ( $obj eq 'nagios_main_configuration' ) {
	    my $step = $query->param('step');
	    $page .= nagios_cfg( '', '' );
	}

	#
	##################################################################
	# Resource
	#
	elsif ( $obj eq 'nagios_resource_macros' ) {
	    $page .= resource_cfg( '', '' );
	}

	#
	##################################################################
	# Pre-Flight Test
	#
	elsif ( $obj eq 'pre_flight_test' ) {
	    $page .= pre_flight('');
	}

	#
	##################################################################
	# Commit
	#
	elsif ( $obj eq 'commit' ) {
	    my %abort        = ( 'name' => 'abort', 'value' => 'Abort' );
	    my %commit       = ( 'name' => 'commit', 'value' => 'Commit' );
	    my %monarch_home = StorProc->fetch_one( 'setup', 'name', 'monarch_home' );
	    my $workspace    = $monarch_home{'value'} . '/workspace';
	    my %nagios_cfg   = StorProc->fetch_one( 'setup', 'name', 'log_file' );
	    my %nagios_cgi   = StorProc->fetch_one( 'setup', 'name', 'default_user_name' );

	    if ( $query->param('abort') ) {
		$page .= Forms->header( $page_title, $session_id, $top_menu );
		$page .= Forms->form_top( 'Nagios Commit', '' );
		$hidden{'obj'} = undef;
		$page .= Forms->hidden( \%hidden );
		my @message = ("Commit aborted.");
		$page .= Forms->form_message( 'Action&nbsp;canceled:', \@message, '' );
		$page .= Forms->form_bottom_buttons( \%continue, $tab++ );
		$hidden{'obj'} = undef;
	    }
	    elsif ( $query->param('commit') ) {
		if ( $query->param('refreshed') ) {
		    my $annotation = $query->param('annotation');
		    my $lock       = $query->param('lock');
		    $annotation = "Backup auto-created after a Commit by user \"$user_acct\"." if not $annotation;
		    $annotation =~ s/\r//g;
		    $annotation =~ s/^\s+|\s+$//g;
		    $annotation .= "\n";

		    my ( $errors, $results, $timings ) = StorProc->synchronized_commit(
			$user_acct, $nagios_ver, $nagios_etc, $nagios_bin, $monarch_home,
			'html',     $backup_dir, $annotation, $lock
		    );
		    $page .= Forms->header( $page_title, $session_id, $top_menu );
		    if (@$errors) {
			$page .= Forms->form_top( 'Commit Errors', '', '' );
			$page .= Forms->form_errors( $errors );
			if (@$timings) {
			    if (0) {
				grep s/ \[[\d.]+ \.\. [\d.]+\]*//, @$timings;
				$page .= Forms->form_message( 'Timings:', $timings, 'row1' ) if @$timings;
			    }
			    else {
				require MonarchGraphs;
				my ($errors, $image_file, $image_x, $image_y, $time_ref) = Graphs->graph_commit( $timings );
				$page .= Forms->form_errors( $errors ) if @$errors;
				$page .= Forms->form_image( $image_file, $image_x, $image_y, 'row1' ) if $image_file;
				$page .= Forms->form_message( 'Timings:', $time_ref, 'row1' ) if @$time_ref;
			    }
			}
			$page .= Forms->hidden( \%hidden );
			$page .= Forms->form_bottom_buttons( \%close, $tab++ );
		    }
		    else {
			$page .= Forms->form_top( 'Nagios Commit', '' );
			$page .= Forms->form_errors( \@errors ) if @errors;
			if (@$timings) {
			    require MonarchGraphs;
			    my ( $errors, $image_file, $image_x, $image_y, $time_ref ) = Graphs->graph_commit($timings);
			    $page .= Forms->form_errors($errors) if @$errors;
			    $page .= Forms->form_image( $image_file, $image_x, $image_y, 'row1' ) if $image_file;
			    $page .= Forms->form_message( 'Timings:', $time_ref, 'row1' ) if @$time_ref;
			}
			$page .= Forms->form_message( 'Results:', $results, 'row1' );
			$hidden{'obj'} = undef;
			$page .= Forms->hidden( \%hidden );
			$page .= Forms->form_bottom_buttons( \%close, $tab++ );
		    }
		}
		else {
		    my $annotation = $query->param('annotation');
		    my $lock       = $query->param('lock');
		    $annotation = '' if not $annotation;
		    $annotation =~ s/\r//g;
		    $annotation =~ s/^\s+|\s+$//g;
		    $hidden{'lock'} = $lock if $lock;

		    my $now = time;
		    $refresh_url = "nocache=$now&amp;refreshed=1&amp;commit=1";
		    foreach my $name ( keys %hidden ) {
			$refresh_url .= qq(&amp;$name=) . ( defined( $hidden{$name} ) ? uri_escape( $hidden{$name} ) : '' );
		    }

		    # We pass the annotation explictly here as the last element of the refresh URL, so
		    # in case it is very long it is the only parameter that gets truncated (or omitted).
		    $refresh_url .= qq(&amp;annotation=) . uri_escape($annotation);

		    # Apache limits a URL to 8190 characters; browsers may have much shorter limits, just above 2000 characters.
		    # See:  http://stackoverflow.com/questions/417142/what-is-the-maximum-length-of-a-url-in-different-browsers
		    # If we have a really long URL, we refresh using a POST instead of a GET.
		    $page .= Forms->header( $page_title, $session_id, $top_menu, ( length($refresh_url) < 2000 ? '?' : '' ) . $refresh_url );
		    $page .= Forms->form_top( 'Commit to Nagios', '' );
		    $page .= Forms->form_doc('Running commit ...');
		    ## $now = time;
		    ## $refresh_url = "?nocache=$now&amp;refreshed=1&amp;commit=1&amp;update_main=1";
		    $page .= Forms->form_bottom_buttons();
		}
	    }
	    elsif ( $nagios_cfg{'value'} && $nagios_cgi{'type'} ) {
		$page .= Forms->header( $page_title, $session_id, $top_menu );
		$page .= Forms->form_top( 'Nagios Commit', '' );
		my $errors = StorProc->check_version( $monarch_ver );
		push @errors, @$errors if @$errors;
		$page .= Forms->form_errors( \@errors ) if @errors;
		$page .= Forms->hidden( \%hidden );
		if ( -x "$monarch_home/bin/commit_check" ) {
		    my $warning = [ qx($monarch_home/bin/commit_check) ];
		    if (@$warning && $warning->[0] ne "Configuration looks okay.\n") {
			$page .= Forms->form_errors( $warning );
		    }
		}
		my @message =
		  (     'Are you sure you want to overwrite your active Nagios configuration and restart Nagios?'
		      . '<p class=append>If you choose to continue, and the Commit is successful,'
		      . ' a backup of the new configuration will automatically be created.'
		      . '  You may see a list of all previous backups in the "Back up and restore" screen.</p>' );
		$page .= Forms->form_message( 'Nagios&nbsp;commit:', \@message, '' );
		my %docs = Doc->backups();
		$page .= Forms->new_backup( 'Commit-backup metadata', $docs{'commit'}, $docs{'lock'}, 0, $tab++ );
		$help{url} = StorProc->doc_section_url('How+to+pre+flight%2C+backup%2C+commit');
		$page .= Forms->form_bottom_buttons( \%abort, \%commit, \%help, $tab++ );
	    }
	    else {
		$page .= Forms->header( $page_title, $session_id, $top_menu );
		$page .= Forms->form_top( 'Nagios Commit', '' );
		unless ( $nagios_cfg{'value'} ) {
		    push @errors,
		      'Nagios main configuration has not been defined.',
		      'Use Control->Nagios main configuration to load an existing file or set defaults.';
		}
		unless ( $nagios_cgi{'type'} ) {
		    push @errors,
		      'Nagios CGI configuration has not been defined.',
		      'Use Control->Nagios CGI configuration to load an existing file or set defaults.';
		}
		$page .= Forms->form_message( 'Error(s):', \@errors, 'error' );
		$hidden{'obj'} = undef;
		$page .= Forms->hidden( \%hidden );
		$page .= Forms->form_bottom_buttons( \%continue, $tab++ );
	    }
	}
	elsif ( $obj eq 'back_up_and_restore' ) {
	    my %Restore = ( 'name' => 'confirm', 'value' => 'Restore' );
	    my %Lock    = ( 'name' => 'lock',    'value' => 'Lock' );
	    my %Unlock  = ( 'name' => 'confirm', 'value' => 'Unlock' );
	    my %Delete  = ( 'name' => 'confirm', 'value' => 'Delete' );
	    my @results = ();
	    $help{url} = StorProc->doc_section_url('How+to+back+up+and+restore', 'Howtobackupandrestore-MonarchBackupandRestore');

	    $page .= Forms->header( $page_title, $session_id, $top_menu );
	    $page .= Forms->form_top( 'Back up and Restore', '' );

	    if ( $query->param('back_up') ) {
		## FIX MINOR:  A synchronized backup might take a few moments, both because of
		## possible interlock delays with other programs and because the backup itself
		## can take macroscopic time, so we should have an intermediate screen.
		my $annotation = $query->param('annotation');
		my $lock       = $query->param('lock');
		$annotation = "Backup manually created by user \"$user_acct\"." if not $annotation;
		$annotation =~ s/\r//g;
		$annotation =~ s/^\s+|\s+$//g;
		$annotation .= "\n";
		my ( $errors, $results, $timings ) = StorProc->synchronized_backup( $nagios_etc, $backup_dir, $user_acct, $annotation, $lock );
		my $full_backup_dir = $results->[0];
		if (@$errors) {
		    unshift @$errors, "Problem(s) backing up files and/or database to:<br>&nbsp;&nbsp;&nbsp; $full_backup_dir" if $full_backup_dir;
		    $page .= Forms->form_message( '<b>Backup&nbsp;error(s):</b>', $errors, 'error' );
		}
		else {
		    my @message = ("Files backed up to $full_backup_dir .");
		    $page .= Forms->form_message( 'Backup&nbsp;complete:', \@message, '' );
		}
	    }
	    elsif ( $query->param('restore') ) {
		my @backup_times = $query->$multi_param('backup_time');
		if ( @backup_times == 0 ) {
		    push @errors, "You did not select any backup to restore.";
		}
		elsif ( @backup_times > 1 ) {
		    push @errors, "You selected more than one backup to restore.";
		}
		else {
		    ## FIX MINOR:  A synchronized restore might take a few moments, both because of
		    ## possible interlock delays with other programs and because the restore itself
		    ## can take macroscopic time, so we should have an intermediate screen.
		    my ( $errors, $results, $timings ) = StorProc->synchronized_restore( $backup_dir, $backup_times[0], $user_acct );
		    if (@$errors) {
			push @errors, @$errors;
		    }
		    else {
			my %docs = Doc->backups();
			if (@$results) {
			    ## We label this as "command" instead of "results" because the UI currently doesn't run the restore.
			    $page .= Forms->form_message( 'Restore&nbsp;command:', $results, '' );
			}
			else {
			    ( my $human_time = $backup_times[0] ) =~ s/_(\d\d)-(\d\d)-/&nbsp;$1:$2:/;
			    $page .= Forms->form_message( 'Restore&nbsp;complete:', ["Backup $human_time has been restored."], '' );
			}
			$page .= Forms->wizard_doc( undef, $docs{'restore_advice'} );
		    }
		}
	    }
	    elsif ( $query->param('lock') ) {
		my @backup_times = $query->$multi_param('backup_time');
		if ( @backup_times == 0 ) {
		    push @errors, "You did not select any backups to lock.";
		}
		else {
		    foreach my $backup_time (@backup_times) {
			if ( not $backup_time =~ /^\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}$/ ) {
			    push @errors, "Invalid backup time:  " . HTML::Entities::encode($backup_time);
			}
			elsif ( !-d "$backup_dir/$backup_time" ) {
			    push @errors, "The $backup_dir/$backup_time/ backup cannot be found ($!).";
			}
			else {
			    my $locked_file = "$backup_dir/$backup_time/monarch-$backup_time.locked";
			    if ( !open( LOCKED, '>', $locked_file ) || !close(LOCKED) ) {
				push @errors, "Cannot touch backup lock file $locked_file ($!).";
			    }
			}
		    }
		}
	    }
	    elsif ( $query->param('unlock') ) {
		my @backup_times = $query->$multi_param('backup_time');
		if ( @backup_times == 0 ) {
		    push @errors, "You did not select any backups to unlock.";
		}
		else {
		    require POSIX;
		    foreach my $backup_time (@backup_times) {
			if ( not $backup_time =~ /^\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}$/ ) {
			    push @errors, "Invalid backup time:  " . HTML::Entities::encode($backup_time);
			}
			elsif ( -d "$backup_dir/$backup_time" ) {
			    my $locked_file = "$backup_dir/$backup_time/monarch-$backup_time.locked";
			    if ( not unlink $locked_file ) {
				push @errors, "Cannot remove backup lock file $locked_file ($!)." if $! != POSIX::ENOENT;
			    }
			}
			else {
			    push @errors, "The $backup_dir/$backup_time/ backup cannot be found ($!).";
			}
		    }
		}
	    }
	    elsif ( $query->param('delete') ) {
		my @backup_times = $query->$multi_param('backup_time');
		if ( @backup_times == 0 ) {
		    push @errors, "You did not select any backups to delete.";
		}
		else {
		    foreach my $backup_time (@backup_times) {
			my ( $errors, $results ) = StorProc->delete_one_backup( $backup_dir, $backup_time );
			push @errors,  @$errors;
			push @results, @$results;
		    }
		}
	    }
	    if (@errors) {
		s/^error:\s+//i for @errors;
		$page .= Forms->form_errors( \@errors );
	    }
	    @errors = ();
	    $page .= Forms->form_message( 'Results:', \@results, 'row1' ) if @results;

	    sub check_for_backups {
		my $backup_times = shift;
		my $annotated    = shift;
		my $locked       = shift;

		foreach my $backup_time (@$backup_times) {
		    next if not $backup_time =~ /^\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}$/;
		    my $annotation = '';
		    if (
			!-l "$backup_dir/$backup_time"
			&& (   -f "$backup_dir/$backup_time/monarch-$backup_time.sql.tar"
			    || -f "$backup_dir/$backup_time/monarch-$backup_time.sql" )
		      )
		    {
			my $annfile = "$backup_dir/$backup_time/monarch-$backup_time.annotation";
			if ( open ANN, '<', $annfile ) {
			    while ( my $line = <ANN> ) {
				chomp $line;
				$annotation .= HTML::Entities::encode($line) . "<br>\n";
			    }
			    close ANN;
			}
			$annotation = 'No annotation is available.' if not $annotation;
			$annotated->{$backup_time} = $annotation;
			$locked->{$backup_time} = 1 if -f "$backup_dir/$backup_time/monarch-$backup_time.locked";
		    }
		}
	    }

	    my $got_form = 0;
	    my $confirm = $query->param('confirm');
	    if ($confirm) {
		my %restore = ( 'name' => 'restore', 'value' => 'Restore' );
		my %unlock  = ( 'name' => 'unlock',  'value' => 'Unlock' );
		$confirm = "\l$confirm";
		my %action = (
		    restore => 'restoration',
		    unlock  => 'unlocking',
		    delete  => 'deletion'
		);
		my %button = (
		    restore => \%restore,
		    unlock  => \%unlock,
		    delete  => \%delete
		);
		my @backup_times = $query->$multi_param('backup_time');
		if ( @backup_times == 0 ) {
		    push @errors, "You did not select any backup to $confirm.";
		}
		elsif ( $confirm eq 'restore' && @backup_times > 1 ) {
		    push @errors, 'You selected more than one backup to restore.';
		}
		else {
		    $page .= Forms->hidden( \%hidden );
		    my %annotated = ();
		    my %locked    = ();
		    check_for_backups( \@backup_times, \%annotated, \%locked );
		    if (%annotated) {
			if ( $confirm eq 'delete' ) {
			    foreach my $backup_time ( sort keys %annotated ) {
				if ( not $backup_time =~ /^\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}$/ ) {
				    push @errors, "Invalid backup time:  " . HTML::Entities::encode($backup_time);
				}
				elsif ( -l "$backup_dir/$backup_time" ) {
				    push @errors, "The $backup_dir/$backup_time/ directory is a symlink.";
				}
				elsif ( !-d _ ) {
				    push @errors, "The $backup_dir/$backup_time/ backup cannot be found ($!).";
				}
				elsif ( -e "$backup_dir/$backup_time/monarch-$backup_time.locked" ) {
				    ( my $human_time = $backup_time ) =~ s/_(\d\d)-(\d\d)-/&nbsp;$1:$2:/;
				    push @errors, "The $human_time backup is locked, so it will not be deleted.";
				}
			    }
			}
			unless (@errors) {
			    my %docs = Doc->backups();
			    $page .= Forms->wizard_doc( undef, $docs{$confirm} );
			    $page .= Forms->backup_select( "Confirm backup $action{$confirm}", 0, \%annotated, \%locked, $docs{explain}, $tab++ );
			    foreach my $backup_time ( keys %annotated ) {
				$page .= Forms->hidden( { backup_time => $backup_time } );
			    }
			    $tab += scalar keys %annotated;
			    $page .= Forms->form_bottom_buttons( $button{$confirm}, \%cancel, \%help, $tab++ );
			    $got_form = 1;
			}
		    }
		    else {
			push @errors, 'None of the selected backups are still available.';
		    }
		}
		$page .= Forms->form_errors( \@errors ) if @errors;
	    }

	    unless ($got_form) {
		$page .= Forms->hidden( \%hidden );
		my %docs = Doc->backups();
		$page .= Forms->new_backup( 'Create a new backup', $docs{'annotation'}, $docs{'lock'}, 1, $tab++ );
		if ( not opendir( DIR, $backup_dir ) ) {
		    push @errors, "Could not open the backup base directory $backup_dir for reading ($!).";
		    $page .= Forms->form_errors( \@errors );
		    $page .= Forms->form_bottom_buttons( \%continue, \%help, $tab++ );
		}
		else {
		    my %annotated = ();
		    my %locked    = ();
		    my @subdirs   = readdir DIR;
		    closedir DIR;
		    check_for_backups (\@subdirs, \%annotated, \%locked);
		    if (%annotated) {
			$page .= Forms->backup_select( 'Manage existing backups', 1, \%annotated, \%locked, $docs{explain}, $tab++ );
			$tab += scalar keys %annotated;
			$page .= Forms->form_bottom_buttons( \%Restore, \%Lock, \%Unlock, \%Delete, \%help, $tab++ );
		    }
		    else {
			$page .= Forms->form_status( 'Status:', 'No backups are available.', '' );
			$page .= Forms->form_bottom_buttons( \%help, $tab++ );
		    }
		}
	    }
	}

	#
	##################################################################
	# Run Ext info scripts
	#
	elsif ( $obj eq 'run_extended_info_scripts' ) {
	    $page .= Forms->header( $page_title, $session_id, $top_menu );
	    my $ext_info = $query->param('ext_info');
	    my $type     = $query->param('type');
	    if ($ext_info) {
		my @results = ();
		if ( $type eq 'host' ) {
		    my %x = StorProc->fetch_one( 'extended_host_info_templates', 'name', $ext_info );
		    my %w = ( 'hostextinfo_id' => $x{'hostextinfo_id'} );
		    my @hosts = StorProc->fetch_list_where( 'hosts', 'name', \%w );
		    push @results, "Script $x{'script'} from $x{'name'} launched for:";
		    push @results, "<hr>";
		    foreach my $host (@hosts) {
			my $script = $x{'script'};
			$script =~ s/\$HOSTNAME\$/$host/g;
			system("$script &");
			push @results, "$host '$script'";
			push @results, "<br>";
		    }
		}
		elsif ( $type eq 'service' ) {
		    my %x = StorProc->fetch_one( 'extended_service_info_templates', 'name', $ext_info );
		    my %service_hosts = StorProc->fetch_service_extinfo( $x{'serviceextinfo_id'} );
		    push @results, "Script $x{'script'} from $x{'name'} launched for:";
		    push @results, "<hr>";
		    foreach my $sid ( keys %service_hosts ) {
			my $script = $x{'script'};
			$script =~ s/\$HOSTNAME\$/$service_hosts{$sid}[0]/g;
			$script =~ s/\$SERVICENAME\$/$service_hosts{$sid}[1]/g;
			system("$script &");
			push @results, "$service_hosts{$sid}[0] $service_hosts{$sid}[1] '$script'";
			push @results, "<br>";
		    }
		}
		$page .= Forms->form_top( 'External Script', '' );
		if (@errors) {
		    $page .= Forms->form_message( 'Error(s):', \@errors, 'error' );
		}
		$page .= Forms->form_message( 'Results:', \@results, 'row1' );
		$page .= Forms->hidden( \%hidden );
		$page .= Forms->form_bottom_buttons( \%continue, $tab++ );
	    }
	    else {
		my %scripts = StorProc->fetch_scripts('host');
		$page .= Forms->table_script_links( $session_id, 'host', \%scripts );
		%scripts = StorProc->fetch_scripts('service');
		$page .= Forms->table_script_links( $session_id, 'service', \%scripts );
	    }
	}

	#
	##################################################################
	# Build externals files
	#
	elsif ( $obj eq 'build_externals' ) {
	    if (1) {
		$page .= build_externals();
	    }
	    else {
		## FIX MAJOR:  Older, now-obsolete code.  Should be deleted once the newer code is proven.
		use MonarchExternals;
		my ($results, $errors) = Externals->build_all_externals($user_acct, $session_id, '1');
		my @results = @$results;
		my @errors  = @$errors;
		$page .= Forms->header( $page_title, $session_id, $top_menu );
		$page .= Forms->form_top( 'Build Externals', '' );
		if (@errors) {
		    $page .= Forms->form_message( 'Error(s):', \@errors, 'error' );
		}
		$page .= Forms->form_message( 'Results:', \@results, 'row1' );
		$hidden{'obj'} = undef;
		$page .= Forms->hidden( \%hidden );
		$page .= Forms->form_bottom_buttons( \%continue, $tab++ );
	    }
	}
    }
    return $page;
}

#
############################################################################
# Search
#

sub search() {
    my $detail = Forms->header( $page_title, $session_id, $top_menu );
    $detail .= Forms->form_top( 'Search Hosts', 'onsubmit="find_names(); return false;"', '', '100%' );
    $detail .= Forms->search($session_id);
    $hidden{'view'}      = 'search_hosts';
    $hidden{'CGISESSID'} = $session_id;
    $detail .= Forms->hidden( \%hidden );
    $detail .= Forms->form_bottom_buttons();
    use CGI::Ajax;
    my $url = Forms->get_ajax_url();
    my $pjx = new CGI::Ajax( 'get_hosts' => $url );
    return $pjx->build_html( $query, $detail );
}

sub search_services() {
    my $detail = Forms->header( $page_title, $session_id, $top_menu );
    $detail .= Forms->form_top( 'Search Services', 'onsubmit="find_names(); return false;"', '', '100%' );
    $detail .= Forms->search( $session_id, 'services' );
    $hidden{'view'}      = 'search_services';
    $hidden{'CGISESSID'} = $session_id;
    $detail .= Forms->hidden( \%hidden );
    $detail .= Forms->form_bottom_buttons();
    use CGI::Ajax;
    my $url = Forms->get_ajax_url();
    my $pjx = new CGI::Ajax( 'get_services' => $url );
    return $pjx->build_html( $query, $detail );
}

sub search_commands() {
    my $detail = Forms->header( $page_title, $session_id, $top_menu );
    $detail .= Forms->form_top( 'Search Commands', 'onsubmit="find_names(); return false;"', '', '100%' );
    $detail .= Forms->search( $session_id, 'commands' );
    $hidden{'view'}      = 'search_commands';
    $hidden{'CGISESSID'} = $session_id;
    $detail .= Forms->hidden( \%hidden );
    $detail .= Forms->form_bottom_buttons();
    use CGI::Ajax;
    my $url = Forms->get_ajax_url();
    my $pjx = new CGI::Ajax( 'get_commands' => $url );
    return $pjx->build_html( $query, $detail );
}

sub search_externals($) {
    my $type = shift;
    my $detail = Forms->header( $page_title, $session_id, $top_menu );
    $detail .= Forms->form_top( "Search \u$type Externals", 'onsubmit="find_names(); return false;"', '', '100%' );
    $detail .= Forms->search( $session_id, "$type\_externals" );
    $hidden{'view'}      = "search_$type\_external";
    $hidden{'CGISESSID'} = $session_id;
    $detail .= Forms->hidden( \%hidden );
    $detail .= Forms->form_bottom_buttons();
    use CGI::Ajax;
    my $url = Forms->get_ajax_url();
    my $pjx = new CGI::Ajax( 'get_externals' => $url );
    return $pjx->build_html( $query, $detail );
}

sub schema_mismatch {
    my $errors = shift;
    my $page = '';
    $page .= Forms->header( $page_title, $session_id, $top_menu, $refresh_url );
    $page .= Forms->form_top( 'Database Schema Mismatch', '' );
    $page .= Forms->form_errors( $errors );
    $page .= Forms->form_bottom_buttons();
    return $page;
}

sub server_context {
    my $bare    = shift;
    my $env     = shift;
    my $break   = $bare ? '' : '<br>';
    my $mark    = $bare ? '=== ' : '';
    my $context = "${break}${mark}Query Parameters:${break}\n";
    $context .= "<pre>\n" if not $bare;
    foreach my $param ( sort $query->param ) {
	my @values = $query->$multi_param($param);
	$context .=
	  $bare
	  ? "$param = '" . join( "', '", @values ) . "'" . "\n"
	  : HTML::Entities::encode( "$param = '" . join( "', '", @values ) . "'" ) . "\n";
    }
    $context .= "</pre>\n" if not $bare;
    if ($env) {
	$context .= "${mark}Server environment variables available when this page was constructed:${break}\n";
	$context .= "<pre>\n" if not $bare;
	foreach my $key ( sort keys %ENV ) {
	    $context .= $bare ? "$key=$ENV{$key}\n" : HTML::Entities::encode("$key=$ENV{$key}\n");
	}
	$context .= "</pre>\n" if not $bare;
    }
    return $context;
}

#
# Begin processing request
#

# db connection
my $auth = StorProc->dbconnect();
if ( $auth == 4 ) {
    ## Auth level 4 = open portal admin access no login.
    $ENV{'REMOTE_USER'} = 'admin';
    $auth = 1;
}

# get config info
my %where = ();
my %objects = StorProc->fetch_list_hash_array( 'setup', \%where );
if ( -e '/usr/local/groundwork/config/db.properties' ) { $is_portal = 1 }
$nagios_ver       = $objects{'nagios_version'}[2];
$nagios_bin       = $objects{'nagios_bin'}[2];
$nagios_etc       = $objects{'nagios_etc'}[2];
$monarch_home     = $objects{'monarch_home'}[2];
$monarch_ver      = $objects{'monarch_version'}[2];
$backup_dir       = $objects{'backup_dir'}[2];
$upload_dir       = $objects{'upload_dir'}[2];
$enable_externals = $objects{'enable_externals'}[2];
$enable_groups    = $objects{'enable_groups'}[2];
$enable_ez        = $objects{'enable_ez'}[2];
$nagios_share     = $objects{'physical_html_path'}[2];
if ($is_portal) {
    $doc_root = '/usr/local/groundwork/monarch/htdocs';
}

#
# Check user
#

my $deny_access     = 0;
my $show_login      = 0;
my $session_timeout = 0;

if ( defined($view) && $view eq 'logout' ) {
    $show_login = 1;
    ( $userid, $session_id ) = undef;
}
elsif ( $is_portal || $auth == 1 ) {
    ## Auth level 1 = full access no login.
    $user_acct = $ENV{'REMOTE_USER'};
    if ($user_acct) {
	if ($session_id) {
	    my $session_user_acct;
	    ( $userid, $session_user_acct, $session_id ) = StorProc->get_session($session_id);
	    if ( !defined($userid) or !defined($session_user_acct) or $session_user_acct ne $user_acct ) {
		$session_id = undef;
	    }
	}
	if ( not $session_id ) {
	    ( $userid, $session_id ) = StorProc->set_gwm_session($user_acct);
	}
	my ( $auth_add, $auth_modify, $auth_delete ) = StorProc->auth_matrix( $userid, $auth );
	%auth_add    = %{$auth_add};
	%auth_modify = %{$auth_modify};
	%auth_delete = %{$auth_delete};
    }
    else {
	$deny_access = 1;
    }
}
elsif ( $auth == 2 ) {
    ## Auth level 2 = active login.
    if ( $query->param('process_login') ) {
	$userid = StorProc->check_user( $user_acct, $password );
	my ( $auth_add, $auth_modify, $auth_delete ) = StorProc->auth_matrix($userid);
	%auth_add    = %{$auth_add};
	%auth_modify = %{$auth_modify};
	%auth_delete = %{$auth_delete};
	if ( $auth_add{'enable_ez'}
	    && ( $auth_add{'ez_main'} || $auth_add{'ez'} ) )
	{
	    $ez = 1;
	}
	if ( $userid =~ /^\d+/ ) {
	    $session_id = StorProc->set_session( $userid, $user_acct );
	}
	else {
	    $show_login = 1;
	}
    }
    elsif ($session_id) {
	( $userid, $user_acct, $session_id ) = StorProc->get_session($session_id);
	if ($user_acct) {
	    my ( $auth_add, $auth_modify, $auth_delete ) = StorProc->auth_matrix($userid);
	    %auth_add    = %{$auth_add};
	    %auth_modify = %{$auth_modify};
	    %auth_delete = %{$auth_delete};
	}
	else {
	    $session_timeout = 1;
	}
    }
    else {
	$show_login = 1;
	( $userid, $session_id ) = undef;
    }
}
elsif ( $auth == 3 ) {
    ## Auth level 3 = passive login - single sign on.
    ## first check if we have a new user being passed
    my $new_user_acct = $ENV{'REMOTE_USER'};
    ## unless ($new_user_acct) { $new_user_acct = $query->param('user_acct') }
    if ($new_user_acct) {
	## now check for session info
	( $userid, $user_acct, $session_id ) = StorProc->get_session( $session_id, $auth );

	# does stored user = new user? -- if there is one stored
	unless ( $new_user_acct eq $user_acct ) {
	    ## no? then see if new user is valid and give them a sessionid if so
	    my %user = StorProc->fetch_one( 'users', 'user_acct', $new_user_acct );
	    $session_id = StorProc->set_session( $user{'user_id'}, $new_user_acct );
	    $user_acct = $new_user_acct;
	}
    }
    else {
	( $userid, $user_acct, $session_id ) = StorProc->get_session( $session_id, $auth );
    }
    if ($session_id) {
	my ( $auth_add, $auth_modify, $auth_delete ) = StorProc->auth_matrix($userid);
	%auth_add    = %{$auth_add};
	%auth_modify = %{$auth_modify};
	%auth_delete = %{$auth_delete};
    }
    else {
	$show_login = 1;
	( $userid, $session_id ) = undef;
    }
}

$deny_access = 1 if not defined $userid;

#
# Create frames and content
#

unless ( (defined($view) && $view =~ /search/) || $show_login ) {
    my $cookie = $query->cookie( CGISESSID => $session_id );
    print $query->header( -cookie => $cookie );
}
unless ($enable_externals) {
    delete $auth_add{'externals'};
    delete $auth_modify{'externals'};
    delete $auth_delete{'externals'};
}
unless ($enable_groups) {
    delete $auth_add{'groups'};
    delete $auth_modify{'groups'};
    delete $auth_delete{'groups'};
}

if ($show_login) {
    print "Content-type: text/html \n\n";
    print Forms->login( $page_title, $userid );
}
elsif ($deny_access) {
    ## print "Content-type: text/html \n\n";
    print Forms->header( 'Error', 'no_session', 'no_menu' );
    print Forms->form_top( 'Configuration', '' );
    print Forms->wizard_doc( 'Access Denied', 'To use this feature, you must log out, then log in again.', undef, 1 );
    print Forms->form_bottom_buttons();
    ## FIX MAJOR:  clean up this logging once we know what the problem is.
    my $context_for_log = "=== FAILED ACCESS TO MONARCH ===\n" . server_context( 1, 1 );
    print STDERR $context_for_log;
    my $context = $debug ? server_context( 0, 1 ) : undef;
    print Forms->footer($context);
}
elsif ( $query->param('update_top') ) {
    my @top_menus = ();
    my $login     = $query->param('login');
    if ($session_timeout) {
	print Forms->login_redirect;
    }
    elsif ($ez) {
	for my $object (qw(hosts host_groups profiles notifications commit setup)) {
	    no strict 'refs';
	    push( @top_menus, $object ) if ( $auth == 1 || $auth_add{ 'ez_' . $object } );
	}
	my $login = $query->param('login');
    }
    else {
	for my $object (qw(hosts services profiles commands time_periods contacts escalations)) {
	    push( @top_menus, $object ) if ( $auth == 1 || $auth_add{$object} || $auth_modify{$object} );
	}
	for my $object (qw(groups control)) {
	    push( @top_menus, $object ) if ( $auth == 1 || $auth_add{$object} );
	}
	push @top_menus, 'tools';
    }
    push @top_menus, 'help';
    print Forms->top_frame( $session_id, $top_menu, \@top_menus, $auth, $monarch_ver, $enable_ez, $ez, \%auth_add, $login );
}
elsif ( $query->param('update_main') ) {
    $hidden{'update_main'} = 1;
    my $errors = StorProc->check_version( $monarch_ver );
    if ($session_timeout) {
	if ( $view =~ /search/ ) { print "Content-type: text/html \n\n" }
	$body .= Forms->login_redirect;
    }
    elsif (@$errors) {
	if ( $view =~ /search/ ) { print "Content-type: text/html \n\n" }
	$body .= schema_mismatch($errors);
    }
    elsif ( $view eq 'host_wizard' ) {
	$body .= host_wizard();
    }
    elsif ( $view eq 'host_profile' ) {
	$body .= host_profile();
    }
    elsif ( $view eq 'service_profile' ) {
	$body .= service_profile();
    }
    elsif ( $view eq 'service_template' ) {
	$body .= service_template();
    }
    elsif ( $view eq 'service_group' ) {
	$body .= service_group();
    }
    elsif ( $view eq 'service' ) {
	$body .= service();
    }
    elsif ( $view eq 'service_externals' ) {
	$body .= externals('service');
    }
    elsif ( $view eq 'host_externals' ) {
	$body .= externals('host');
    }
    elsif ( $view eq 'profile_importer' ) {
	$body .= profile_importer();
    }
    elsif ( $view eq 'manage_host' ) {
	$body .= manage_host();
    }
    elsif ( $view eq 'search_hosts' ) {
	$body .= search();
    }
    elsif ( $view eq 'search_services' ) {
	$body .= search_services();
    }
    elsif ( $view eq 'search_commands' || ( defined($obj) && $obj eq 'commands' && $view eq 'search' ) ) {
	$body .= search_commands();
    }
    elsif ( $view eq 'search_host_externals' ) {
	$body .= search_externals('host');
    }
    elsif ( $view eq 'search_service_externals' ) {
	$body .= search_externals('service');
    }
    elsif ( $view eq 'clone_host' ) {
	$body .= clone_host();
    }
    elsif ( $view eq 'delete_hosts' ) {
	$body .= delete_hosts();
    }
    elsif ( $view eq 'delete_host_services' ) {
	$body .= delete_host_services();
    }
    elsif ( $view eq 'host_dependencies' ) {
	$body .= host_dependencies();
    }
    elsif ( $view eq 'parent_child' ) {
	$body .= parent_child();
    }
    elsif ( $view eq 'escalations' ) {
	$body .= escalations();
    }
    elsif ( $view eq 'escalation_trees' ) {
	$body .= escalation_trees();
    }
    elsif ( $view eq 'commands' ) {
	$body .= command_wizard();
    }
    elsif ( defined($obj) && $obj eq 'time_periods' ) {
	$body = time_period();
    }
    elsif ( $view eq 'tools' ) {
	$body .= tools();
    }
    elsif ( $view eq 'manage' ) {
	$body .= manage();
    }
    elsif ( $view eq 'design' ) {
	$body .= design();
    }
    elsif ( $view eq 'groups' ) {
	$body .= groups();
    }
    elsif ( $view eq 'macros' ) {
	$body .= macros();
    }
    elsif ( $view eq 'build_instances' ) {
	$body .= build_instances();
    }
    elsif ( $view eq 'control' ) {
	$body .= control();
    }
    else {
	$body .= Forms->header( $page_title, $session_id, $top_menu );
    }

    print $body;
    my $context = $debug ? server_context( 0, 1 ) : undef;
    print Forms->footer($context);
}
else {
    print Forms->frame( $session_id, $top_menu, $is_portal, $ez );
}

my $result = StorProc->dbdisconnect();

