#!/usr/bin/perl --
# MonArch - Groundwork Monitor Architect
# monarch_auto.cgi
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

use lib qq(/usr/local/groundwork/monarch/lib);
use strict;

use CGI;
use URI::Escape;
use Time::HiRes qw(usleep);
use Cwd 'realpath';

use MonarchForms;
use MonarchAutoConfig;
use MonarchStorProc;
use MonarchProfileImport;
use MonarchDiscovery;
use MonarchDoc;

$|++;

#
############################################################################
# Global Declarations
#

my $debug = undef;

# Uncomment this next line to spill out details of each query at the end of the result screen.
# $debug = 'Query Parameters:';

my $query = new CGI;

# Adapt to an upgraded CGI package while still maintaining backward compatibility.
my $multi_param = $query->can('multi_param') ? 'multi_param' : 'param';

my $header        = undef;
my $discover_name = $query->param('discover_name');
$discover_name = uri_unescape($discover_name);
$discover_name =~ s/^\s+|\s+$//g if ( defined($discover_name) );
my $automation_name = $query->param('automation_name');
$automation_name = uri_unescape($automation_name);
$automation_name =~ s/^\s+|\s+$//g if ( defined($automation_name) );
my ( $processed_file, $import_file ) = undef;

if ($discover_name) {
    $import_file = "auto-discovery-$discover_name.txt";
    $import_file =~ s/\s|\\|\/|\'|\"|\%|\^|\#|\@|\!|\$/-/g;
    $processed_file = "processed-$discover_name.txt";
    $processed_file =~ s/\s|\\|\/|\'|\"|\%|\^|\#|\@|\!|\$/-/g;
}
elsif ($automation_name) {
    $processed_file = "processed_$automation_name.txt";    # FIX THIS: why does this use underscore, when above two use hyphen?
    $processed_file =~ s/\s|\\|\/|\'|\"|\%|\^|\#|\@|\!|\$/-/g;
}
my %hidden = ();
$hidden{'discover_name'}   = $discover_name;
$hidden{'automation_name'} = $automation_name;
$hidden{'view'}            = $query->param('view');
$hidden{'obj_view'}        = $query->param('obj_view');
$hidden{'user_acct'}       = $query->param('user_acct');
my $session_id = $query->param('CGISESSID');
unless ($session_id) { $session_id = $query->cookie('CGISESSID') }
$session_id =~ s/[[:^xdigit:]]+//g if defined $session_id;
my ( %auth_add, %auth_modify, %auth_delete, %authentication, %profile, %config_settings ) = ();
my $page_title  = 'Monarch Auto Config';
my $userid      = undef;
my $top_menu    = undef;
my $refresh_url = undef;
my $host_record = undef;

foreach my $name ( $query->param ) {
    if ( $name =~ /edit_rec_(\S+)/ ) { $host_record = $1 }
}
my $body       = undef;
my @errors     = ();
my $tab        = 1;
my $page       = undef;
my $empty_data = qq(<?xml version="1.0" encoding="iso-8859-1" ?>
<data>
</data>);

# Some buttons
my %add      = ( 'name' => 'add',      'value' => 'Add' );
my %save     = ( 'name' => 'save',     'value' => 'Save' );
my %delete   = ( 'name' => 'delete',   'value' => 'Delete' );
my %cancel   = ( 'name' => 'cancel',   'value' => 'Cancel' );
my %close    = ( 'name' => 'close',    'value' => 'Close' );
my %next     = ( 'name' => 'next',     'value' => 'Next >>' );
my %back     = ( 'name' => 'back',     'value' => '<< Back' );
my %continue = ( 'name' => 'continue', 'value' => 'Continue' );
my %rename   = ( 'name' => 'rename',   'value' => 'Rename' );
my %yes      = ( 'name' => 'yes',      'value' => 'Yes' );
my %no       = ( 'name' => 'no',       'value' => 'No' );
my %apply    = ( 'name' => 'apply',    'value' => 'Apply' );
my %upload   = ( 'name' => 'upload',   'value' => 'Upload' );
my %refresh  = ( 'name' => 'refresh',  'value' => 'Refresh' );
my %select   = ( 'name' => 'select',   'value' => 'Select' );
my %import   = ( 'name' => 'import',   'value' => 'Import' );
my %discard  = ( 'name' => 'discard',  'value' => 'Discard' );
my %help     = ( 'name' => 'help',     'value' => 'Help' );

my %textsize = ();
$textsize{'short'}   = 50;
$textsize{'long'}    = 75;
$textsize{'address'} = 17;

my $auth = StorProc->dbconnect();
%config_settings = AutoConfig->config_settings();

my $monarch_ver         = $config_settings{'monarch_ver'};
my $auto_path           = "$config_settings{'monarch_home'}/automation";
my $automation_data_dir = "$auto_path/data";
my $import_file_path    = "$automation_data_dir/$import_file"    if defined $import_file;
my $processed_file_path = "$automation_data_dir/$processed_file" if defined $processed_file;

# ================================================================

#
# Default page for nms
#

sub nms_home() {
    if ( $query->param('cacti_sync') ) {
	my %config = AutoConfig->config_settings();

	# check to see if cacti schema is there and import if not
	$automation_name = 'Cacti-host-profile-sync';
	my %schema = StorProc->fetch_one( 'import_schema', 'name', $automation_name );
	unless ( $schema{'name'} ) {
	    my @values = ( \undef, $automation_name, '', '', 'host-profile-sync', '', '', '', '' );
	    my $id = StorProc->insert_obj_id( 'import_schema', \@values, 'schema_id' );
	    if ( $id =~ /error/i ) {
		push @errors, $id;
	    }
	    else {
		@errors = ProfileImporter->apply_automation_template( $id, $automation_name, $config{'monarch_home'} );
		my %description =
		  ( 'description' =>
'<b>This schema is used by the NMS Cacti Host Profile Sync function.</b> It is designed to work with data generated by extract_cacti.pl. Hosts found in the configuration database but not found in the Cacti data source are flagged for deletion.'
		  );
		my $result = StorProc->update_obj( 'import_schema', 'schema_id', $id, \%description );
		if ( $result =~ /error/i ) { push @errors, $result }
	    }
	}
	unless (@errors) {
	    if ( -e "$config{'monarch_home'}/automation/scripts/extract_cacti.pl" ) {
		my $res = qx($config{'monarch_home'}/automation/scripts/extract_cacti.pl);
		if ( $res =~ /error/i ) { push @errors, $res }
	    }
	    else {
		push @errors, "Not found: $config{'monarch_home'}/automation/scripts/extract_cacti.pl cannot extract data.";
	    }
	}
	unless ( $errors[0] ) {
	    $page = advanced_import();
	}
    }
    elsif ( $query->param('nedi_sync') ) {
	my %config = AutoConfig->config_settings();

	# check to see if NeDi schema is there and import if not
	$automation_name = 'NeDi-parent-child-sync';
	my %schema = StorProc->fetch_one( 'import_schema', 'name', $automation_name );
	my $script_folder = '/usr/local/groundwork/monarch/automation/scripts';
	unless ( $schema{'name'} ) {
	    my @values = ( \undef, $automation_name, '', '', 'other-sync', '', '', '', '' );
	    my $id = StorProc->insert_obj_id( 'import_schema', \@values, 'schema_id' );
	    if ( $id =~ /error/i ) {
		push @errors, $id;
	    }
	    else {
		@errors = ProfileImporter->apply_automation_template( $id, $automation_name, $config{'monarch_home'} );
		my %description =
		  ( 'description' =>
'<b>This schema is used by the NMS NeDi Parent-Child Sync function.</b> It is designed to work with data generated by extract_nedi.pl, and will set parent-child relationships.'
		  );
		my $result = StorProc->update_obj( 'import_schema', 'schema_id', $id, \%description );
		if ( $result =~ /error/i ) { push @errors, $result }
	    }
	}
	unless (@errors) {
	    if ( -e "$config{'monarch_home'}/automation/scripts/extract_nedi.pl" ) {
		my $res = qx($config{'monarch_home'}/automation/scripts/extract_nedi.pl);
		if ( $res =~ /error/i ) { push @errors, $res }
	    }
	    else {
		push @errors, "Not found: $config{'monarch_home'}/automation/scripts/extract_nedi.pl cannot extract data.";
	    }
	}
	unless ( $errors[0] ) {
	    $page = advanced_import();
	}
    }
    elsif ( $query->param('nedi_import') ) {
	my %config = AutoConfig->config_settings();

	# check to see if NeDi schema is there and import if not
	$automation_name = 'NeDi-host-import';
	my %schema = StorProc->fetch_one( 'import_schema', 'name', $automation_name );
	my $script_folder = '/usr/local/groundwork/monarch/automation/scripts';
	unless ( $schema{'name'} ) {
	    my @values = ( \undef, $automation_name, '', '', 'host-import', '', '', '', '' );
	    my $id = StorProc->insert_obj_id( 'import_schema', \@values, 'schema_id' );
	    if ( $id =~ /error/i ) {
		push @errors, $id;
	    }
	    else {
		@errors = ProfileImporter->apply_automation_template( $id, $automation_name, $config{'monarch_home'} );
		my %description =
		  ( 'description' =>
'<b>This schema is used by the NMS NeDi Host Import function.</b> It is designed to work with data generated by extract_nedi.pl, and will set parent-child relationships.'
		  );
		my $result = StorProc->update_obj( 'import_schema', 'schema_id', $id, \%description );
		if ( $result =~ /error/i ) { push @errors, $result }
	    }
	}
	unless (@errors) {
	    if ( -e "$config{'monarch_home'}/automation/scripts/extract_nedi.pl" ) {
		my $res = qx($config{'monarch_home'}/automation/scripts/extract_nedi.pl);
		if ( $res =~ /error/i ) { push @errors, $res }
	    }
	    else {
		push @errors, "Not found: $config{'monarch_home'}/automation/scripts/extract_nedi.pl cannot extract data.";
	    }
	}
	unless ( $errors[0] ) {
	    $page = advanced_import();
	}
    }
    elsif ( $query->param('other_import') ) {
	$page = automation_home();
    }
    my $errstr = undef;
    foreach my $err (@errors) {
	$errstr .= "<br>&bull;&nbsp;$err";
    }
    if ($errstr) { $errstr = "Error(s): please correct the following: $errstr" }

    unless ($page) {
	my %doc     = AutoConfig->doc();
	my %options = ();
	my $page    = Forms->form_top( 'NMS Integration Home', '', '2' );
	if ( -e '/usr/local/groundwork/cacti' ) {
	    %{ $options{'cacti_sync'} } = ( 'name' => 'cacti_sync', 'value' => 'Cacti Sync' );
	}
	if ( -e '/usr/local/groundwork/nedi' ) {
	    %{ $options{'nedi_sync'} }   = ( 'name' => 'nedi_sync',   'value' => 'NeDi Sync' );
	    %{ $options{'nedi_import'} } = ( 'name' => 'nedi_import', 'value' => 'NeDi Import' );
	}
	%{ $options{'other_import'} } = ( 'name' => 'other_import', 'value' => 'Other Import' );
	if ($errstr) { $page .= Forms->form_doc("<h7>$errstr</h7>") }
	$page .= AutoConfig->select_nms( \%options );
	$page .= Forms->hidden( \%hidden );
	$page .= Forms->form_bottom_buttons();
	return $page;
    }

# FIX MINOR:  should we return something here?
}

# FIX LATER:  This routine has significant trouble in its concept of what other changes
# to the discovery schema should be saved to the database across an Add Method with an
# empty and a non-empty new method name.  It's an example of similar troubles elsewhere in
# the UI regarding hidden partial saves and sometimes silently losing user modifications.
# Rather than just hack the problem here, we should figure out some global principles to
# apply, such as saving changes to temporary-copy tables and only finally committing them
# to the real tables when a user-initiated Save occurs.
sub discover_home() {

    # GWMON-4681 If duplicate instances are launched by Guava, allow only one to proceed
    my $lockfile = exit_if_locked();

    my $discovery = Discovery->new();

    my $errors;
    my %discover_groups = ();
    ($errors, %discover_groups) = StorProc->get_discovery_groups();
    push @errors, @$errors if @$errors;

    # If there are no discovery definitions, load the default
    unless ( keys %discover_groups ) {
	discovery_load_default( \$discover_name, \@errors, \%discover_groups, \%hidden, \%config_settings );
    }

    my %discover_methods = ();
    ($errors, %discover_methods) = StorProc->get_discovery_methods();
    push @errors, @$errors if @$errors;

    my %filters = StorProc->get_discovery_filters();

    $discovery->set_description( scalar $query->param('description') );

    $discovery->set_method( scalar $query->param('method') );
    $discovery->set_method_description( scalar $query->param('method_description') );    # not used?
    $discovery->set_schema_name( scalar $query->param('schema') );

    my $enable_traceroute   = $query->param('enable_traceroute');
    my $traceroute_max_hops = StorProc->sanitize_string( scalar $query->param('traceroute_max_hops') );
    my $traceroute_timeout  = StorProc->sanitize_string( scalar $query->param('traceroute_timeout') );

    $discovery->set_enable_traceroute( $enable_traceroute );
    $discovery->set_traceroute_command( scalar $query->param('traceroute_command') );
    $discovery->set_traceroute_max_hops( $traceroute_max_hops );
    $discovery->set_traceroute_timeout( $traceroute_timeout );

    $discovery->set_filter( scalar $query->param('filter') );
    $discovery->set_type( scalar $query->param('type') );
    $discovery->set_auto( scalar $query->param('auto') );

    my $discover_name_new = $query->param('discover_name_new');
    $hidden{'obj_view'}      = $query->param('obj_view');
    $hidden{'delete_filter'} = $query->param('delete_filter');
    if ( $query->param('delete_group') ) {
	$discovery->set_flag( 'delete_group', 1 );
    }
    if ( $query->param('delete_method') ) {
	$discovery->set_flag( 'delete_method', 1 );
    }
    my $saved = undef;    # Saved messsage
    foreach my $n ( $query->param ) {
	if ( $n =~ /edit_method_(.*)/ ) {
	    $discovery->set_edit_method($1);
	    $discovery->set_flag( 'save_group', 1 );
	}
	if ( defined($discover_name) && $n =~ /auto_$discover_name/ ) {
	    my $auto = $query->param("auto_$discover_name");
	    $auto =~ s/_$discover_name//;
	    $discovery->set_auto($auto);
	}
	if ( $n =~ /delete_filter_(.*)/ ) {
	    $hidden{'delete_filter'} = $1;
	}
	if ( $n =~ /remove_port/ ) {
	    $discovery->set_flag( 'remove_port', 1 );
	}
    }

    my $old_obj_view = $hidden{'obj_view'};
    if ( $query->param('cancel') ) {
	unless ( ( $hidden{'obj_view'} eq 'manage_group' ) || ( $hidden{'obj_view'} eq 'manage_method' ) ) {
	    delete $hidden{'obj_view'};
	}
    }
    elsif ( $query->param('edit_group') && $discover_name ) {
	$discovery->set_flag( 'save_group', 2 );
    }
    elsif ( $query->param('new_group') ) {
	$hidden{'obj_view'} = 'new_group';
	$discovery->set_flag( 'save_group', 3 );
    }
    elsif ( $query->param('go') && $discover_name ) {
	$discovery->set_flag( 'save_group', 4 );
    }
    elsif ( $query->param('go_discover') ) {
	if ( $query->param('accept') eq 'accept' ) {
	    $hidden{'obj_view'} = 'discover';
	}
	else {
	    delete $hidden{'obj_view'};
	}
    }
    elsif ( $query->param('clear_discovery') ) {
	if ( -e $import_file_path ) {
	    unlink($import_file_path)
	      or ( push @errors, "error: cannot unlink $import_file_path ($!)" );
	}
	if ( -e $processed_file_path ) {
	    unlink($processed_file_path)
	      or ( push @errors, "error: cannot unlink $processed_file_path ($!)" );
	}
    }
    elsif ( $query->param('cancel_discovery') ) {
	if ( -e $import_file_path ) {
	    unlink($import_file_path)
	      or ( push @errors, "error: cannot unlink $import_file_path ($!)" );
	}
	if ( -e $processed_file_path ) {
	    unlink($processed_file_path)
	      or ( push @errors, "error: cannot unlink $processed_file_path ($!)" );
	}
	delete $hidden{'obj_view'};
    }
    elsif ( defined( $hidden{'obj_view'} ) && $hidden{'obj_view'} eq 'discover_disclaimer' && $query->param('process_records') ) {
	$page = advanced_import();
    }
    elsif ( $query->param('close_group') ) {
	$discovery->set_flag( 'save_group', 5 );
    }
    elsif ( $query->param('close_method') ) {
	$hidden{'obj_view'} = 'manage_group';
	$discovery->set_flag( 'save_method', 1 );
    }
    elsif ( $query->param('rename') ) {
	discovery_rename_confirmed( $query, $discovery, \$discover_name, \@errors, \%discover_groups, \%discover_methods, \%hidden );
    }

    #########################################
    # Groups (definitions)
    #########################################
    elsif ( $query->param('create_group') ) {
	$discover_name = $discover_name_new;
	discovery_create_group( $discovery, $query, $discover_name_new, \@errors, \%discover_groups, \%discover_methods, \%hidden );
    }
    elsif ( $query->param('save_group') ) {
	$discovery->set_flag( 'save_group', 7 );
    }
    elsif ( $query->param('delete_group') ) {
	discovery_delete_group_if_confirmed( $query, $discovery, \$discover_name, \@errors, \%discover_groups, \%hidden );
    }

    #########################################
    # Methods
    #########################################
    elsif ( $query->param('add_method') ) {
	discovery_add_method( $empty_data, $query, $discovery, \@errors, \%discover_groups, \%discover_methods, \%hidden );
    }
    elsif ( $query->param('delete_method') ) {
	discovery_delete_method_if_confirmed( $query, $discovery, \@errors, \%discover_methods, \%hidden );
    }
    elsif ( $query->param('add_port') || $discovery->get_flag('remove_port') ) {
	$discovery->set_flag( 'save_method', 1 );
    }
    elsif ( $discover_name && $query->param('save_as_template') ) {
	$discovery->set_flag( 'save_group', 10 );
    }

    #########################################
    # Filters
    #########################################
    elsif ( $query->param('add_filter') ) {
	discovery_add_filter( $query, $discovery, \@errors, \%hidden, \%filters );
    }
    elsif ( $hidden{'delete_filter'} ) {
	discovery_delete_filter_if_confirmed( $query, $discovery, \@errors, \%discover_groups, \%discover_methods, \%hidden, \%filters );
    }

    #
    #############################################################################
    # Save method
    #
    if ( $discovery->get_flag('save_method') ) {
	discovery_save_method( $saved, $query, $discovery, \@errors, \%discover_methods, \%hidden, \%filters );
    }
    elsif ( $query->param('discover_name_select') && ( $query->param('discover_name_select') ne $discover_name ) ) {
	$discovery->set_flag( 'save_group', 13 );
    }

    #
    #############################################################################
    # Save group
    #
    if ( $discovery->get_flag('save_group') && $discover_name ) {
	discovery_save_group( $saved, $query, $discovery, $discover_name, \@errors, \%discover_groups, \%discover_methods, \%hidden,
	    \%filters );
    }
    if ( $discover_name && $query->param('save_as_template') ) {
	discovery_save_as_template( $discovery, $saved, $query, $discover_name, \@errors, \%discover_methods );
    }
    if ( $query->param('go') && $discover_name ) {
	discovery_go( $query, $discover_name, \@errors, \%discover_groups, \%discover_methods, \%hidden, \%filters );
    }
    if ( $query->param('edit_group') && $discover_name ) {
	$hidden{'obj_view'} = 'manage_group';
    }
    if ( $query->param('discover_name_select') ) {
	$discover_name = $query->param('discover_name_select');
	$hidden{'discover_name'} = $discover_name;
    }
    if ( defined( $hidden{'obj_view'} ) && $hidden{'obj_view'} eq 'manage_group' && ! $discovery->get_flag('rename') ) {
	if ( !defined($old_obj_view) || $old_obj_view ne 'manage_group' || $query->param('add_method') || $query->param('add_filter') ) {
	    # Set the values tested to those displayed this time, regardless of whether the user previously made changes to them.
	    $enable_traceroute   = $discover_groups{$discover_name}{enable_traceroute};
	    $traceroute_max_hops = $discover_groups{$discover_name}{traceroute_max_hops};
	    $traceroute_timeout  = $discover_groups{$discover_name}{traceroute_timeout};
	}
	my $bad_max_hops = 0;
	my $bad_timeout  = 0;
	if ($enable_traceroute) {
	    if (!defined($traceroute_max_hops) || $traceroute_max_hops eq '' || $traceroute_max_hops =~ /\D/ || $traceroute_max_hops == 0) {
		$bad_max_hops = 1;
	    }
	    if (!defined($traceroute_timeout) || $traceroute_timeout eq '' || $traceroute_timeout =~ /\D/ || $traceroute_timeout <= 1) {
		$bad_timeout = 1;
	    }
	}
	else {
	    if (defined($traceroute_max_hops) && $traceroute_max_hops ne '' && ($traceroute_max_hops =~ /\D/ || $traceroute_max_hops == 0)) {
		$bad_max_hops = 1;
	    }
	    if (defined($traceroute_timeout) && $traceroute_timeout ne '' && ($traceroute_timeout =~ /\D/ || $traceroute_timeout <= 1)) {
		$bad_timeout = 1;
	    }
	}
	if ($bad_max_hops) {
	    push @errors, 'The traceroute max hops value must be a positive integer.';
	}
	if ($bad_timeout) {
	    push @errors, 'The traceroute timeout value must be an integer greater than 1.';
	}
    }
    if ( $query->param('save_group') && !@errors ) {
	delete $hidden{'obj_view'};
    }

    my $errstr = undef;
    foreach my $err (@errors) {
	$errstr .= "<br>&bull;&nbsp;$err";
    }
    if ($errstr) { $errstr = "Error(s): please correct the following: $errstr" }

    unless ($page) {
	my %doc     = AutoConfig->doc();
	my %options = ();
	if ( $discovery->get_flag('rename') ) {
	    $page = discovery_prompt_for_rename_confirmation( $page, $discovery, $discover_name, $errstr, \%textsize, \%hidden );
	}
	elsif ( $hidden{'delete_filter'} ) {
	    $page = discovery_prompt_for_delete_filter_confirmation( $query, $page, \%discover_groups, \%discover_methods, \%hidden );
	}
	elsif ( $hidden{'delete_method'} ) {
	    $page = discovery_prompt_for_delete_method_confirmation( $page, $discovery, \%discover_groups );
	}
	elsif ( $hidden{'delete_group'} ) {
	    $page = discovery_prompt_for_delete_group_confirmation( $page, $discover_name, \%discover_groups, \%discover_methods );
	}
	elsif ( defined( $hidden{'obj_view'} ) && $hidden{'obj_view'} eq 'new_group' ) {
	    $page = discovery_new_group( $discover_name_new, $page, $errstr, $discovery, \@errors );
	}
	elsif ( defined( $hidden{'obj_view'} ) && $hidden{'obj_view'} eq 'manage_group' ) {
	    $page = discovery_manage_group( $page, $saved, $errstr, \%discover_groups, \%discover_methods, \%filters );
	}
	elsif ( defined( $hidden{'obj_view'} ) && $hidden{'obj_view'} eq 'manage_method' ) {
	    $page = discovery_manage_method( $discovery, $page, $saved, $errstr, \%discover_methods, \%filters );
	}
	elsif ( defined( $hidden{'obj_view'} ) && $hidden{'obj_view'} eq 'discover_disclaimer' ) {
	    $page =
	      discovery_show_disclaimer( $page, $query, $processed_file_path, $import_file_path, $discover_name, $errstr, \%discover_groups,
		\%hidden );
	}
	elsif ( defined( $hidden{'obj_view'} ) && $hidden{'obj_view'} eq 'discover' ) {
	    $page = discovery_do_prep( $page, $query, \%discover_groups, \%discover_methods, \%hidden );
	}
	else {
	    $page = Forms->form_top( 'Auto Discovery', '', '2' );
	    if ($errstr) { $page .= Forms->form_doc("<h7>$errstr</h7>") }
	    if ( defined($saved) ) {
		$page .= Forms->form_doc("<h1>$saved</h1>");
	    }
	    unless ($discover_name) {
		foreach my $group ( sort keys %discover_groups ) {
		    if ($discover_name) {
			last;
		    }
		    else {
			$discover_name = $group;
		    }
		}
	    }
	    $hidden{'discover_name'} = $discover_name;
	    $discover_groups{$discover_name}{'selected'} = 1;
	    $page .= AutoConfig->discover_home( \%discover_groups );
	    $page .= AutoConfig->manage_filters( \%{ $discover_groups{$discover_name} }, \%filters );
	    $hidden{'obj_view'} = 'discover_home';
	    $page .= Forms->hidden( \%hidden );
	    $page .= Forms->form_bottom_buttons();
	}

	unlink($lockfile);

	return $page;
    }

# FIX MINOR:  should we return something here?
}

##################################################
# Automation
#
# Sub for automation view
#

sub automation_home() {
    if (   $query->param('close')
	|| $query->param('continue')
	|| $query->param('cancel') )
    {
	$page = undef;
	delete $hidden{'automation_name'};
    }
    elsif ( $query->param('commit') ) {
	$page = commit();
    }
    elsif ( $query->param('new_schema') ) {
	$page = new_schema();
    }
    elsif ( $host_record || ( $host_record && $query->param('import_host') ) ) {
	$page = edit_host($host_record);
    }
    elsif ( $automation_name && ( $query->param('edit_schema') ) ) {
	$page = edit_schema();
    }
    elsif ( $query->param('import') || $query->param('import_sync') ) {
	$page = advanced_import();
    }
    elsif ( $automation_name && ( $query->param('next') ) ) {
	$page = edit_schema();
    }
    elsif ( defined( $hidden{'obj_view'} ) && $hidden{'obj_view'} eq 'edit_host' && $query->param('cancel') ) {
	$page = advanced_import();
    }
    elsif ( $automation_name && defined( $hidden{'obj_view'} ) && $hidden{'obj_view'} eq 'edit_schema' ) {
	$page = edit_schema();
    }
    elsif ( defined( $hidden{'obj_view'} ) && $hidden{'obj_view'} eq 'import' ) {
	$page = advanced_import();
    }
    elsif ( defined( $hidden{'obj_view'} ) && $hidden{'obj_view'} eq 'new_schema' ) {
	$page = new_schema();
    }
    unless ($page) {
	my %doc         = AutoConfig->doc();
	my %new_schema  = ( 'name' => 'new_schema', 'value' => 'New Schema' );
	my %edit_schema = ( 'name' => 'edit_schema', 'value' => 'Edit Schema' );
	my %back        = ( 'name' => 'close', 'value' => '<< Back' );
	$page = Forms->form_top( 'Automation Home', '', '2' );
	if (@errors) { $page .= Forms->form_errors( \@errors ) }
	my %w       = ();
	my %schemas = StorProc->fetch_list_hash_array( 'import_schema', \%w );
	my %list    = ();

	foreach my $key ( keys %schemas ) {
	    ## FIX THIS: eliminate use of positional arguments in these lines (does that make sense?)
	    $list{ $schemas{$key}[1] }{'description'} = $schemas{$key}[3];
	    $list{ $schemas{$key}[1] }{'type'}        = $schemas{$key}[4];
	}
	$page .= AutoConfig->select_schema( \%list );
	$page .= Forms->hidden( \%hidden );
	$page .= Forms->form_bottom_buttons( \%new_schema, \%next );
    }
    return $page;
}

sub commit() {
    my @results  = ();
    my %file_ref = ();
    my ( $preflight, $commit ) = undef;
    # FIX MAJOR:  drop this
    my $backup = undef;
    $file_ref{'user_acct'}   = $hidden{'user_acct'};                           # user name in file headers
    $file_ref{'commit_step'} = 'preflight';
    $file_ref{'location'}    = "$config_settings{'monarch_home'}/workspace";
    $file_ref{'nagios_etc'}  = "$config_settings{'monarch_home'}/workspace";
    my ( $files, $errors ) = AutoConfig->build_files( \%file_ref, \%config_settings );
    my @errors = @{$errors};

    if (@errors) {
	@results = ( "Unable to create files in $file_ref{'location'}. Commit process aborted ..." );
	push( @results, @errors );
	$preflight = Forms->form_message( 'Pre-flight failed', \@results, '', 1 );
    }
    else {
	$config_settings{'verbose'} = 1;

	# Do preflight
	my ( $preflight_check, $preflight_results ) = AutoConfig->pre_flight_check( \%config_settings );
	my @preflight_results = @{$preflight_results};
	Forms->filter_results( \@preflight_results );
	if ($preflight_check) {
	    @results = ("Pre-flight passed ($preflight_check)");
	    push( @results, @preflight_results );
	    $preflight = Forms->form_message( 'Pre-flight', \@results, '' );

	    ## FIX MAJOR:  drop the backup pass, since it is now being done automatically within a Commit
	    if (0) {
		## if preflight passes, do backup
		my $annotation = $query->param('annotation');
		my $lock       = $query->param('lock');
		$annotation = "Backup auto-created after an Auto-Discovery Commit by user \"$hidden{user_acct}\"." if not $annotation;
		$annotation =~ s/\r//g;
		$annotation =~ s/^\s+|\s+$//g;
		$annotation .= "\n";

		my ( $backup_msg, $errors ) = AutoConfig->backup( \%config_settings, $hidden{'user_acct'}, $annotation, $lock );
		@errors = @{$errors};
		if (@errors) {
		    @results = ('Backup failed! Commit process aborted ...');
		    push( @results, @errors );
		    $backup = Forms->form_message( 'Backup', \@results, '', 1 );
		}
		else {
		    @results = ("Backup folder: $backup_msg");
		    $backup .= Forms->form_message( 'Backup', \@results, '' );
		}
	    }

	    ## FIX MAJOR:  drop the backup pass, since it is now being done automatically within a Commit
	    ## commit if backup passes
	    unless (@errors) {
		$file_ref{'commit_step'} = 'commit';
		$file_ref{'location'}    = "$config_settings{'nagios_etc'}";
		$file_ref{'nagios_etc'}  = "$config_settings{'nagios_etc'}";

		my $res = AutoConfig->copy_files( "$config_settings{'monarch_home'}/workspace", $config_settings{'nagios_etc'} );
		if ( $res =~ /Error/ ) {
		    push @errors, $res;
		}
		else {
		    $res = AutoConfig->rewrite_nagios( "$config_settings{'monarch_home'}/workspace", $config_settings{'nagios_etc'} );
		    if ( defined($res) && $res =~ /Error/ ) { push @errors, $res }
		}

		if (@errors) {
		    @results = ("Commit failed! Unable to create files in $file_ref{'location'}. Commit process aborted ...");
		    push( @results, @errors );
		    $commit = Forms->form_message( 'Commit and Foundation sync', \@results, '', 1 );
		}
		else {
		    my $annotation = $query->param('annotation');
		    my $lock       = $query->param('lock');
		    $annotation = "Backup auto-created after an Auto-Discovery Commit by user \"$hidden{user_acct}\"." if not $annotation;
		    $annotation =~ s/\r//g;
		    $annotation =~ s/^\s+|\s+$//g;
		    $annotation .= "\n";

		    @results = AutoConfig->commit( \%config_settings, $hidden{'user_acct'}, $annotation, $lock );
		    $commit = Forms->form_message( 'Commit and Foundation sync', \@results, '', 1 );
		}
	    }
	}
	else {
	    @results = ("Pre-flight failed ($preflight_check). Commit process aborted ...");
	    push( @results, @preflight_results );
	    $preflight = Forms->form_message( 'Pre-flight', \@results, '', 1 );

	}
    }
    my $page = Forms->form_top( 'Auto Discovery', '', '2' );
    my $message =
        'The commit process is reported in two stages: 1. Pre-flight, and 2. Commit and Foundation sync.'
      . ' A backup is automatically taken within the Commit process if all the Nagios processing succeeds.'
      . ' Please review the results carefully before closing. A pre-flight failure will abort the process.';
    $page .= Forms->wizard_doc( 'Commit Process', $message );
    if ($preflight) { $page .= $preflight }
    ## FIX MAJOR:  drop the backup pass, since it is now being done automatically within a Commit
    if (0) {
	if ($backup) {
	    $page .= $backup;
	}
	else {
	    my @aborted = ('Aborted due to prior errors');
	    $page .= Forms->form_message( 'Backup', \@aborted, '' );
	}
    }
    if ($commit) {
	$page .= $commit;
    }
    else {
	my @aborted = ('Aborted due to prior errors');
	$page .= Forms->form_message( 'Commit and Foundation sync', \@aborted, '' );
    }
    delete $hidden{'obj_view'};
    $page .= Forms->hidden( \%hidden );
    $page .= Forms->form_bottom_buttons( \%close );
    return $page;
}

#
# Page to define a new schema
#

sub new_schema() {
    my $got_form = 0;
    $hidden{'obj_view'} = 'new_schema';
    my $type     = $query->param('type');
    my $template = $query->param('template');
    my %schema   = StorProc->fetch_one( 'import_schema', 'name', $automation_name );
    if ( $query->param('add') ) {
	if ( $schema{'name'} ) {
	    push @errors, "A schema with name \"$automation_name\" already exists";
	}
	elsif ($automation_name) {
	    # FIX THIS:  Should we validate the character set used by $automation_name ?
	    if ($type || $template) {
		my @values = ( \undef, $automation_name, '', '', $type, '', '', '', '' );
		my $id = StorProc->insert_obj_id( 'import_schema', \@values, 'schema_id' );
		if ( $id =~ /error/i ) {
		    push @errors, $id;
		}
		elsif ($template) {
		    my $source = "$auto_path/templates";
		    if ( $template eq 'GroundWork-Default-Pro' ) {
			$template = 'GroundWork-Discovery-Pro';
			$source   = "$auto_path/conf";
		    }
		    elsif ( $template eq 'GroundWork-Default-OS' ) {
			$template = 'GroundWork-Community-Discovery';
			$source   = "$auto_path/conf";
		    }
		    @errors = ProfileImporter->apply_automation_template( $id, $template, $source );
		    unless (@errors) {
			if ($type) {
			    my %values = ( 'type' => $type );
			    my $result = StorProc->update_obj( 'import_schema', 'name', $automation_name, \%values );
			    if ( $result =~ /error/i ) {
				push @errors, $result;
			    }
			}
		    }
		    unless (@errors) {
			$got_form = 1;
			return edit_schema();
		    }
		}
		else {
		    $got_form = 1;
		    return edit_schema();
		}
	    }
	    else {
		push @errors, "You must choose a schema type and/or an existing template.  Selecting both will override the template's schema type.";
	    }
	}
    }
    my $errstr = undef;
    foreach my $err (@errors) {
	$errstr .= "<br>&bull;&nbsp;$err";
    }
    if ($errstr) { $errstr = "Error(s): please correct the following: $errstr" }

    unless ($got_form) {
	my %doc = AutoConfig->doc();
	my $page = Forms->form_top( 'Define Automation Schema', '', '2' );
	my $docs =
"<div style='max-width: 750px;'><ul><li><b>host-import</b>: $doc{'host-import'}</li><li><p class=append><b>host-profile-sync</b>: $doc{'host-profile-sync'}</p></li><li><p class=append><b>other-sync</b>: $doc{'other-sync'}</p></li></ul><p class=append>$doc{'define'}</p></div>";

	$page .= Forms->wizard_doc( 'Schema types', $docs, undef, 1 );
	if ($errstr) { $page .= Forms->form_doc("<h7>$errstr</h7>") }
	$page .= Forms->text_box( 'Automation schema name:', 'automation_name', $automation_name );
	my @types = ( 'host-import', 'host-profile-sync', 'other-sync' );
	my @templates = ();
	if ( -e "$auto_path/conf/schema-template-GroundWork-Discovery-Pro.xml" ) {
	    push @templates, 'GroundWork-Default-Pro';
	}
	elsif ( -e "$auto_path/conf/schema-template-GroundWork-Community-Discovery.xml" ) {
	    push @templates, 'GroundWork-Default-OS';
	}
	if ( !opendir( DIR, "$auto_path/templates" ) ) {
	    push @errors, "error: cannot open $auto_path/templates to read ($!)";
	}
	else {
	    while ( my $file = readdir(DIR) ) {
		if ( $file =~ /schema-template-(\S+)\.xml$/ ) {
		    push @templates, $1;
		}
	    }
	    closedir(DIR);
	}

	$page .= Forms->list_box( 'Schema type (optional):',          'type',     \@types,     $type );
	$page .= Forms->list_box( 'Create from template (optional):', 'template', \@templates, $template );
	$page .= Forms->hidden( \%hidden );
	$page .= Forms->form_bottom_buttons( \%add, \%cancel );
	return $page;
    }

# FIX MINOR:  should we return something here?
}

#
# Form to import a single host
#

sub edit_host($) {
    my $record_esc = shift;
    unless ($record_esc) { $record_esc = $query->param('record') }
    $hidden{'record'} = $record_esc;
    my $host_name        = $query->param('host_name');
    my $record           = uri_unescape($record_esc);
    my $service_selected = $query->param('service_selected');
    if ( $query->param('add_service') ) {
	$service_selected = $query->param('service_add');
    }
    $hidden{"edit_rec_$record"}   = $record;
    $hidden{'processing_records'} = 1;
    my $saved = undef;
    my %doc   = AutoConfig->doc();
    if ( $query->param('cancel_edit') || $query->param('discard') ) {
	delete $hidden{'record'};
	delete $hidden{"edit_rec_$record"};
	$page = advanced_import();
    }
    elsif ( $query->param('import_host') ) {
	if (   $host_name
	    && $query->param('address')
	    && $query->param('alias')
	    && $query->param('profiles_host') )
	{
	    my %import_data         = ();
	    my %host_name           = StorProc->get_table_objects('hosts');
	    my %group_name          = StorProc->get_table_objects('monarch_groups');
	    my %hostgroup_name      = StorProc->get_table_objects('hostgroups');
	    my %contactgroup_name   = StorProc->get_table_objects('contactgroups');
	    my %serviceprofile_name = StorProc->get_table_objects('profiles_service');
	    $import_data{$record}{'Name'} = $host_name;
	    if ( $host_name{ $import_data{$record}{'Name'} } ) {
		$import_data{$record}{'exists'}  = 1;
		$import_data{$record}{'host_id'} = $host_name{ $import_data{$record}{'Name'} };
	    }
	    $import_data{$record}{'Address'}      = $query->param('address');
	    $import_data{$record}{'Alias'}        = $query->param('alias');
	    $import_data{$record}{'Host profile'} = $query->param('profiles_host');
	    $import_data{$record}{'Description'}  = $query->param('description');
	    my @groups = $query->$multi_param('monarch_groups');
	    foreach my $value (@groups) {
		$import_data{$record}{'Group'}{$value} = $group_name{$value};
	    }
	    my @parents = $query->$multi_param('parents');
	    foreach my $value (@parents) {
		$import_data{$record}{'Parent'}{$value} = $hostgroup_name{$value};
	    }
	    my @hostgroups = $query->$multi_param('hostgroups');
	    foreach my $value (@hostgroups) {
		$import_data{$record}{'Host group'}{$value} = $hostgroup_name{$value};
	    }
	    # profiles_service might not exist, but that's okay.
	    my @service_profiles = $query->$multi_param('profiles_service');
	    foreach my $value (@service_profiles) {
		$import_data{$record}{'Service profile'}{$value} = $serviceprofile_name{$value};
	    }
	    my @contactgroups = $query->$multi_param('contactgroups');
	    foreach my $value (@contactgroups) {
		$import_data{$record}{'Contact group'}{$value} = $contactgroup_name{$value};
	    }
	    my @services = $query->$multi_param('services');
	    foreach my $service (@services) {
		my $check_command = $query->param("check_command_$service");
		my $arguments     = $query->param("arguments_$service");
		if ($arguments) {
		    unless ( $arguments =~ /^\!/ ) {
			$arguments = "!$arguments";
		    }
		}
		$import_data{$record}{'Service'}{$service}{'command_line'} = $check_command . $arguments;
		my @service_instances = $query->$multi_param("instances_$service");
		foreach my $instance (@service_instances) {
		    my $arguments = $query->param("instances_arguments_$service\_$instance");
		    $import_data{$record}{'Service'}{$service}{'instance'}{$instance}{'arguments'} = $arguments;
		}
	    }
	    my %results = AutoConfig->process_import_data( \%import_data );
	    if ( $results{'errors'}{$record} ) {
		push @errors, "$host_name: $results{'errors'}{$record}";
	    }
	    else {
		if ( !open( FILE, '>>', "$automation_data_dir/$processed_file" ) ) {
		    push @errors, "error: cannot open $automation_data_dir/$processed_file to append ($!)";
		}
		else {
		    print FILE "$record\n";
		    close(FILE);
		}
		delete $hidden{'record'};
		$saved = '';
	    }
	}
	else {
	    push @errors, 'Required: name, address, alias, and host profile.';
	}
    }

    unless ($page) {
	if ( defined($saved) ) {
	    $page = Forms->form_top( 'Edit Record', '', '2' );
	    $page .= Forms->wizard_doc( 'Processed', "$host_name" );
	    $automation_name = uri_unescape($automation_name);
	    delete $hidden{"edit_rec_$record"};
	    $hidden{'obj_view'}        = 'import';
	    $hidden{'automation_name'} = $automation_name;
	    $page .= Forms->hidden( \%hidden );
	    %continue = ( 'name' => 'import', 'value' => 'Continue' );
	    $page .= Forms->form_bottom_buttons( \%continue );
	}
	else {
	    my %objects = ();
	    @{ $objects{'parents'} }          = StorProc->fetch_list( 'hosts',            'name' );
	    @{ $objects{'contactgroups'} }    = StorProc->fetch_list( 'contactgroups',    'name' );
	    @{ $objects{'profiles_host'} }    = StorProc->fetch_list( 'profiles_host',    'name' );
	    @{ $objects{'profiles_service'} } = StorProc->fetch_list( 'profiles_service', 'name' );
	    @{ $objects{'hostgroups'} }       = StorProc->fetch_list( 'hostgroups',       'name' );
	    @{ $objects{'monarch_groups'} }   = StorProc->fetch_list( 'monarch_groups',   'name' );
	    @{ $objects{'services'} }         = StorProc->fetch_list( 'service_names',    'name' );
	    my ( $import_data, $schema, $errs ) =
	      AutoConfig->advanced_import( $automation_name, $import_file, $processed_file, $config_settings{'monarch_home'} );
	    my %import_data = %{$import_data};
	    push( @errors, @{$errs} );
	    my %host_data    = %{ $import_data{$record} };
	    my %service_objs = ();
	    my @services     = ( $query->$multi_param('services') );
	    if (@services) {
		foreach my $service (@services) {
		    $host_data{'Service'}{$service}{'assigned'} = 1;
		}
	    }
	    foreach my $service ( keys %{ $host_data{'Service'} } ) {
		unless ($service) { next }
		foreach my $instance ( keys %{ $host_data{'Service'}{$service}{'instances'} } ) {
		    $service_objs{$service}{'instances'}{$instance} = $host_data{'Service'}{$service}{'instances'}{$instance}{'arguments'};
		}
	    }
	    my $remove_service = 0;
	    foreach my $name ( $query->param ) {
		if ( $name =~ /remove_service_(.*)/ ) {
		    delete $host_data{'Service'}{$1};
		    delete $service_objs{$1};
		    $hidden{"service_removed_$1"} = '1';
		    if ( defined($service_selected) && $service_selected eq $1 ) { $service_selected = undef }
		    $remove_service = 1;
		}
		if ( $name =~ /service_removed_(.*)/ ) {
		    unless ( defined($service_selected) && $service_selected eq $1 ) {
			delete $host_data{'Service'}{$1};
			delete $service_objs{$1};
			$hidden{"service_removed_$1"} = '1';
		    }
		}
	    }
	    my %check_commands = StorProc->get_table_objects( 'commands', '1' );
	    my %where          = ();
	    my %service_hash   = StorProc->fetch_list_hash_array( 'service_names', \%where );
	    foreach my $sid ( keys %service_hash ) {
		$service_objs{ $service_hash{$sid}[1] }{'id'} = $sid;
		if ( defined($service_selected) && $service_hash{$sid}[1] eq $service_selected ) {
		    $service_objs{ $service_hash{$sid}[1] }{'service_selected'} = $sid;
		    $host_data{'Service'}{$service_selected} = 1;
		}
		if (defined $service_hash{$sid}[4]) {
		    $service_objs{ $service_hash{$sid}[1] }{'check_command'} = $check_commands{ $service_hash{$sid}[4] };
		}
		if (defined $service_hash{$sid}[5]) {
		    $service_hash{$sid}[5] =~ s/$check_commands{$service_hash{$sid}[4]}//;
		    $service_hash{$sid}[5] =~ s/^!//;
		}
		if ( $query->param("arguments_$service_hash{$sid}[1]") ) {
		    $service_objs{ $service_hash{$sid}[1] }{'arguments'} = $query->param("arguments_$service_hash{$sid}[1]");
		}
		else {
		    $service_objs{ $service_hash{$sid}[1] }{'arguments'} = $service_hash{$sid}[5];
		}
		my @instances = $query->$multi_param("instances_$service_hash{$sid}[1]");
		foreach my $instance (@instances) {
		    my $argument = $query->param( "instances_arguments_$service_hash{$sid}[1]\_$instance" );
		    $service_objs{ $service_hash{$sid}[1] }{'instances'}{$instance} = $argument;
		}
	    }
	    my $remove_instance = 0;
	    foreach my $name ( $query->param ) {
		if ( $name =~ /remove_instance_(.*)/ ) {
		    my @instance = split( /:-:/, $1 );
		    delete $service_objs{ $instance[0] }{'instances'}{ $instance[1] };
		    $remove_instance = 1;
		}
	    }
	    if ( $query->param('add_instance') ) {
		my $instance = $query->param('instance_add');
		if ( $service_objs{$service_selected}{'instances'}{$instance} ) {
		    push @errors, "An instance \"$instance\" already exists.";
		}
		elsif ($instance) {
		    my $bad_char = undef;
		    my $count    = length( $config_settings{'illegal_object_name_chars'} );
		    for ( my $i = 0 ; $i <= $count ; $i++ ) {
			my $char = substr( $config_settings{'illegal_object_name_chars'}, $i, '1' );
			unless ($char) { $char = 's' }
			$char = "\\$char";
			if ( $instance =~ /$char/ ) { $bad_char = 1 }
		    }
		    if ($bad_char) {
			push @errors,
			  "An instance cannot contain the following characters or spaces: $config_settings{'illegal_object_name_chars'}.";
		    }
		    else {
			$service_objs{$service_selected}{'instances'}{$instance} = $service_objs{$service_selected}{'arguments'};
		    }
		}
	    }
	    if (   $query->param('services')
		|| $query->param('add_service')
		|| $query->param('add_instance')
		|| $remove_instance
		|| $remove_service )
	    {
		if ( $query->param('host_name') ) {
		    $host_data{'Name'} = $query->param('host_name');
		}
		if ( $query->param('address') ) {
		    $host_data{'Address'} = $query->param('address');
		}
		if ( $query->param('alias') ) {
		    $host_data{'Alias'} = $query->param('alias');
		}
		if ( $query->param('description') ) {
		    $host_data{'Description'} = $query->param('description');
		}
		if ( $query->param('profiles_host') ) {
		    $host_data{'Host profile'} = $query->param('profiles_host');
		}
		if ( $query->param('monarch_groups') ) {
		    my @groups = $query->$multi_param('monarch_groups');
		    foreach my $group (@groups) {
			$host_data{'Group'}{$group} = 1;
		    }
		}
		if ( $query->param('profiles_service') ) {
		    my @service_profiles = $query->$multi_param('profiles_service');
		    foreach my $sp (@service_profiles) {
			$host_data{'Service profile'}{$sp} = 1;
		    }
		}
		if ( $query->param('parents') ) {
		    my @parents = $query->$multi_param('parents');
		    foreach my $p (@parents) {
			$host_data{'Parent'}{$p} = 1;
		    }
		}
		if ( $query->param('hostgroups') ) {
		    my @hostgroups = $query->$multi_param('hostgroups');
		    foreach my $group (@hostgroups) {
			$host_data{'Host group'}{$group} = 1;
		    }
		}
		if ( $query->param('contactgroups') ) {
		    my @contactgroups = $query->$multi_param('contactgroups');
		    foreach my $group (@contactgroups) {
			$host_data{'Contact group'}{$group} = 1;
		    }
		}
	    }
	    my $errstr = undef;
	    foreach my $err (@errors) {
		$errstr .= "<br>&bull;&nbsp;$err";
	    }
	    if ($errstr) {
		$errstr = "Error(s): please correct the following: $errstr";
	    }
	    $page = Forms->form_top( 'Edit Record', '', '2' );
	    if ($errstr) { $page .= Forms->form_doc("<h7>$errstr</h7>") }
	    $page .= Forms->wizard_doc( 'Process Record', $doc{'edit'}, undef, 1 );
	    $hidden{'show_results'} = 1;
	    $page .= AutoConfig->import_edit( $record_esc, \%host_data, \%objects, \%service_objs );
	    $automation_name           = uri_unescape($automation_name);
	    $hidden{'automation_name'} = $automation_name;
	    $hidden{'obj_view'}        = 'edit_host';
	    $page .= Forms->hidden( \%hidden );
	    %cancel = ( 'name' => 'cancel_edit', 'value' => 'Cancel' );
	    %import = ( 'name' => 'import_host', 'value' => 'Process Record' );
	    $page .= Forms->form_bottom_buttons( \%import, \%discard, \%cancel );
	}
    }
    return $page;
}

#
# Form displays contents of data source from button on main form below
#

sub show_data() {
    my $data_source = StorProc->sanitize_string( scalar $query->param('data_source') );
    $data_source = '' if not defined $data_source;
    $page = Forms->form_top( 'Import Data', '', '2', '100%' );
    my $bad_data_source_path = 0;
    my $no_data_source_path  = 0;
    my $abs_data_source_path = '/dev/null';
    if ( $data_source !~ m{^$automation_data_dir/} ) {
	$bad_data_source_path = 1;
    }
    else {
	$abs_data_source_path = realpath($data_source);
	if ( !defined($abs_data_source_path) or $abs_data_source_path !~ m{^$automation_data_dir/} or -l $abs_data_source_path ) {
	    $bad_data_source_path = 1;
	}
	elsif ( !-f $abs_data_source_path ) {
	    $no_data_source_path = 1;
	}
    }
    if ($no_data_source_path) {
	$page .= Forms->form_errors( ["Data source file does not exist."] );
    }
    elsif ($bad_data_source_path) {
	$page .= Forms->form_errors( ["Data source must be a file under the $automation_data_dir/ directory."] );
    }
    $page .= Forms->display_hidden( 'Data source:', '', HTML::Entities::encode($data_source) );
    if ( !$no_data_source_path and !$bad_data_source_path ) {
	my @file_data = AutoConfig->get_import_data($abs_data_source_path);
	$page .= AutoConfig->show_import_data( \@file_data );
    }
    $page .= Forms->form_bottom_buttons();
    return $page;
}

#
# Main form to define schema properties
#

sub edit_schema() {
    my $column_id       = $query->param('column_id');
    my $column_selected = $query->param('column_selected');
    my $match_selected  = $query->param('match_selected');
    my $match_id        = $query->param('match_id');
    my $match_name      = $query->param('match_name');
    my %schema          = StorProc->fetch_schema($automation_name);
    my $description     = StorProc->sanitize_string_but_keep_newlines( scalar $query->param('description') );
    my $type            = $query->param('type');
    my $smart_name      = $query->param('smart_name');
    my $sync_object     = $query->param('sync_object');
    my $default_profile = $query->param('default_profile');
    my $data_source     = StorProc->sanitize_string( scalar $query->param('data_source') );
    my $delimiter       = $query->param('delimiter');
    my $other_delimiter = StorProc->sanitize_string( scalar $query->param('other_delimiter') );
    if ( $query->param('other_delimiter_ckbx') ) {
	$delimiter = $other_delimiter;
    }
    my $order         = $query->param('order');
    my $match_type    = $query->param('match_type');
    my $match_string  = $query->param('match_string');
    my $rule          = $query->param('rule');
    my $object        = $query->param('object');
    my $service_name  = $query->param('service_name');
    my $arguments     = $query->param('arguments');
    my $updated       = undef;
    my $saved         = undef;
    my $delete        = 0;
    my $rename        = 0;
    my $remove_match  = 0;
    my $remove_column = 0;
    my $update_match  = 0;
    my $update_screen = 0;
    my $saveit        = 0;
    my $show_scrolled = 0;
    my @processed     = $query->$multi_param('processed');
    my %col_pos       = ();

    my $bad_data_source_path = 0;
    $data_source = '' if not defined $data_source;
    if ( $data_source !~ m{^$automation_data_dir/} ) {
	$bad_data_source_path = 1;
    }
    else {
	my $abs_data_source_path = realpath($data_source);
	$bad_data_source_path = 1
	  if !defined($abs_data_source_path)
	      or $abs_data_source_path !~ m{^$automation_data_dir/}
	      or ( -e $abs_data_source_path and ( !-f _ or -l $abs_data_source_path ) );
    }

    foreach my $name ( $query->param ) {
	if ( $name =~ /position_(\d+)/ ) {
	    my $col_id = $1;
	    my $pos    = $query->param($name);
	    if ( $col_pos{$pos} ) {
		push @errors, 'Two or more column names occupy the same position.';
	    }
	    else {
		unless ( $pos =~ /^\d+$/ ) {
		    push @errors, 'Column positions must have a numeric value.';
		}
		else {
		    $col_pos{$pos} = 1;
		    $schema{'column'}{$col_id}{'position'} = $pos;
		}
	    }
	}
	if ( $name =~ /match_id_(\d+)/ ) {
	    $match_id      = $1;
	    $update_screen = 1;
	}
	if ( $name =~ /remove_match_(\d+)/ ) {
	    $match_id     = $1;
	    $remove_match = 1;
	}
	if ( $name =~ /column_id_(\d+)/ ) {
	    $column_id     = $1;
	    $update_screen = 1;
	}
	if ( $name =~ /remove_column_(\d+)/ ) {
	    $column_id     = $1;
	    $remove_column = 1;
	}
    }
    $column_selected = '' if not defined $column_selected;
    $match_selected  = '' if not defined $match_selected;
    unless ( $column_selected eq (defined($column_id) ? $column_id : '') ) {
	( $match_id, $match_type, $match_string, $rule, $object, $match_name ) = undef;
    }
    unless ( $column_selected eq (defined($column_id) ? $column_id : '') && $match_selected eq (defined($match_id) ? $match_id : '') ) {
	( $match_type, $match_string, $rule, $object, $match_name ) = undef;
    }
    unless ( $match_selected eq (defined($match_id) ? $match_id : '') ) {
	( $match_type, $match_string, $rule, $object, $match_name ) = undef;
    }
    unless ( $match_name || !defined($column_id) || !defined($match_id) ) {
	$match_name = $schema{'column'}{$column_id}{'match'}{$match_id}{'name'};
    }
    if ( $query->param('import') || $query->param('import_sync') ) {
	$saveit = 1;
    }
    if ( $query->param('save') ) {
	$update_match = 1;
	$saveit       = 1;
    }
    if ( $query->param('rename') ) {
	if ( $query->param('new_name') ) {
	    my $new_name = $query->param('new_name');
	    $new_name =~ s/^\s+|\s+$//g;
	    if ( $new_name eq $automation_name ) {
		$rename = 1;
	    }
	    else {
		my %n = StorProc->fetch_one( 'import_schema', 'name', $new_name );
		if ( $n{'name'} ) {
		    push @errors, "A schema \"$new_name\" already exists.";
		}
		else {
		    my %values = ( 'name' => $new_name );
		    my $result = StorProc->update_obj( 'import_schema', 'name', $automation_name, \%values );
		    if ( $result =~ /error/i ) {
			push @errors, $result;
			$rename = 1;
		    }
		    else {
			$schema{'name'} = $new_name;
			$automation_name = $new_name;
		    }
		}
	    }
	}
	else {
	    $saveit = 1;
	    $rename = 1;
	}
    }
    if ( $query->param('delete') || $query->param('confirm_delete') ) {
	if ( $query->param('confirm_delete') ) {
	    my $result = StorProc->delete_all( 'import_schema', 'name', $automation_name );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	    unless (@errors) { $delete = 'deleted' }
	}
	elsif ( defined( $query->param('task') ) && $query->param('task') eq 'No' ) {
	    $delete = 0;
	}
	else {
	    $delete = 'yesno';
	    foreach my $name ( $query->param ) {
		unless ( $name eq 'nocache' ) {
		    $hidden{$name} = $query->param($name);
		}
	    }
	    $saveit = 1;
	}
    }
    if ( $query->param('add_column') ) {
	$match_id      = undef;
	my $column_pos  = $query->param('column_pos');
	my $column_name = $query->param('column_name');
	$column_pos  =~ s/^\s+|\s+$//g;
	$column_name =~ s/^\s+|\s+$//g;
	if ( $column_name && $column_pos =~ /^\d+$/ ) {
	    if ( $col_pos{$column_pos} ) {
		push @errors, 'Two or more column names cannot occupy the same position.';
	    }
	    else {
		foreach my $key ( keys %{ $schema{'column'} } ) {
		    if ( $schema{'column'}{$key}{'name'} eq $column_name ) {
			push @errors, "A column with name \"$column_name\" already exists.";
		    }
		}
		unless (@errors) {
		    my @vals = ( \undef, $schema{'schema_id'}, $column_name, $column_pos, '' );
		    $column_id = StorProc->insert_obj_id( 'import_column', \@vals, 'column_id' );
		    if ( $column_id =~ /error/i ) {
			push @errors, $column_id;
		    }
		    else {
			$schema{'column'}{$column_id}{'name'}      = $column_name;
			$schema{'column'}{$column_id}{'position'}  = $column_pos;
			$schema{'column'}{$column_id}{'delimiter'} = '';
			$saved                                     = "Column \"$column_name\" added to automation schema \"$automation_name\".";
			$saveit                                    = 1;
		    }
		}
	    }
	}
	else {
	    push @errors, 'A position and column name are required.';
	}
    }
    if ($remove_column) {
	$match_id   = undef;
	$match_name = undef;
	my $result = StorProc->delete_all( 'import_column', 'column_id', $column_id );
	if ( $result =~ /error/i ) {
	    push @errors, $result;
	}
	else {
	    $saved = "Column \"$schema{'column'}{$column_id}{'name'}\" removed from automation schema \"$automation_name\".";
	    delete $schema{'column'}{$column_id};
	    $column_id = undef;
	    $saveit    = 1;
	}
    }
    if ( $query->param('add_match') ) {
	## GWMON-4306 Refactored add_match and remove_match -sparris 23 Feb '08
	## Note: $update_match is no longer set for add_match and remove_match.
	my $new_match_order = $query->param('new_match_order');
	my $new_match_name  = $query->param('new_match_name');
	if ( $new_match_name && $new_match_order =~ /^\d+$/ ) {
	    my %match_order = ();
	    my $i           = 1;
	    foreach my $match ( keys %{ $schema{'column'}{$column_id}{'match'} } ) {
		$match_order{ $schema{'column'}{$column_id}{'match'}{$match}{'order'} } = $match;
		if ( $schema{'column'}{$column_id}{'match'}{$match}{'name'} eq $new_match_name ) {
		    push @errors, "A match task with name \"$new_match_name\" already exists.";
		}
		$i++;
	    }
	    unless (@errors) {
		## Make sure order value falls withing a valid range
		## Note: $i is 1 greater than total matches so we can assign it to the new match if the user entered a bigger number.
		if ( $new_match_order > $i ) { $new_match_order = $i }
		if ( $new_match_order < 1 )  { $new_match_order = 1 }
		unless (@errors) {
		    my @vals = ( \undef, $column_id, $new_match_name, $new_match_order, '', '', '', '', '', '', '' );
		    $match_id = StorProc->insert_obj_id( 'import_match', \@vals, 'match_id' );
		    if ( $match_id =~ /error/i ) {
			push @errors, $match_id;
		    }
		    else {
			$match_name                                                       = $new_match_name;
			$schema{'column'}{$column_id}{'match'}{$match_id}{'name'}         = $new_match_name;
			$schema{'column'}{$column_id}{'match'}{$match_id}{'order'}        = $new_match_order;
			$schema{'column'}{$column_id}{'match'}{$match_id}{'match_type'}   = '';
			$schema{'column'}{$column_id}{'match'}{$match_id}{'match_string'} = '';
			$schema{'column'}{$column_id}{'match'}{$match_id}{'rule'}         = '';
			$schema{'column'}{$column_id}{'match'}{$match_id}{'object'}       = '';
			$schema{'column'}{$column_id}{'match'}{$match_id}{'service_name'} = '';
			$schema{'column'}{$column_id}{'match'}{$match_id}{'arguments'}    = '';
			$saved  = "Match task \"$match_name\" added to column \"$schema{'column'}{$column_id}{'name'}\".";
			$saveit = 1;
		    }
		    foreach my $ord ( keys %match_order ) {
			my $order = $ord;
			if ( $order >= $new_match_order ) {
			    $order++;
			    $schema{'column'}{$column_id}{'match'}{ $match_order{$ord} }{'order'} = $order;
			    my %vals = ( 'match_order' => $order );
			    my $result = StorProc->update_obj( 'import_match', 'match_id', $match_order{$ord}, \%vals );
			    if ( $result =~ /error/i ) { push @errors, $result }
			}
		    }
		}
	    }
	}
	else {
	    push @errors, 'A match order and match task name are required.';
	}
    }
    if ($remove_match) {
	my $result = StorProc->delete_all( 'import_match', 'match_id', $match_id );
	if ( $result =~ /error/i ) {
	    push @errors, $result;
	}
	else {
	    my $vacant_pos = $schema{'column'}{$column_id}{'match'}{$match_id}{'order'};
	    delete $schema{'column'}{$column_id}{'match'}{$match_id};
	    my %match_order = ();
	    foreach my $match ( keys %{ $schema{'column'}{$column_id}{'match'} } ) {
		$match_order{ $schema{'column'}{$column_id}{'match'}{$match}{'order'} } = $match;
	    }
	    foreach my $ord ( keys %match_order ) {
		my $order = $ord;
		if ( $order > $vacant_pos ) {
		    $order--;
		    my %vals = ( 'match_order' => $order );
		    my $result = StorProc->update_obj( 'import_match', 'match_id', $match_order{$ord}, \%vals );
		    if ( $result =~ /error/i ) { push @errors, $result }
		    $schema{'column'}{$column_id}{'match'}{ $match_order{$ord} }{'order'} = $order;
		}
	    }
	    $saved  = "Match task \"$match_name\" removed from column \"$schema{'column'}{$column_id}{'name'}\".";
	    $saveit = 1;
	    ( $match_id, $match_type, $match_string, $rule, $object, $match_name ) = undef;
	}
    }
    if ( $query->param('update_match') ) {
	$saveit        = 1;
	$update_match  = 1;
	$show_scrolled = 1;
    }
    if ( $query->param('save_template') ) {
	$saveit       = 1;
	$update_match = 1;
    }

    # if (we came right back to the same screen, possibly with changed fields) ...
    if ( $query->param('add_column')
	|| $remove_column
	|| $query->param('add_match')
	|| $remove_match
	|| $update_screen
	|| defined($match_type)
	|| defined($rule)
	|| defined($object)
	|| defined($service_name)
    ) {
	$show_scrolled = 1;
    }
    if ( $query->param('save')
	|| $query->param('save_template')
	|| $query->param('add_column')
	|| $remove_column
	|| $query->param('add_match')
	|| $remove_match
	|| $update_match
	|| $update_screen
	|| defined($match_type)
	|| defined($rule)
	|| defined($object)
	|| defined($service_name)
    ) {
	## We probably ought to capture $sync_object as well, if we actually used it anywhere.
	## We don't capture $type here because it's currently not editable; otherwise we would need to.
	$schema{'description'}     = $description;
	$schema{'smart_name'}      = $smart_name;
	$schema{'delimiter'}       = $delimiter;
	$schema{'data_source'}     = $data_source if not $bad_data_source_path;
	$schema{'default_profile'} = $default_profile;
	if ($bad_data_source_path) {
	    push @errors, "Data source must be a file under the $automation_data_dir/ directory.";
	    $data_source = "$automation_data_dir/arbitrary-file.txt";
	    $bad_data_source_path = 0;
	}
    }

    if ($saveit) {
	if ($bad_data_source_path) {
	    push @errors, "Data source must be a file under the $automation_data_dir/ directory.";
	}
	if ( $type eq 'host-profile-sync' && ! $default_profile ) {
	    push @errors, 'You must specify a default host profile for this schema type.';
	}
	unless (@errors) {
	    # FIX THIS;  These saved values MUST match whatever we display later on via corresponding
	    # %schema{} fields, no matter what, so we don't mislead the user into thinking that what
	    # he sees is what he gets (i.e., what got saved here) when that might not be the case!
	    my %values = (
		'description' => $description,
		'type'        => $type,
		'smart_name'  => $smart_name,
		'sync_object' => $sync_object,
		'data_source' => $data_source,
		'delimiter'   => $delimiter
	    );
	    if ($default_profile) {
		my %profile = StorProc->fetch_one( 'profiles_host', 'name', $default_profile );
		## Might be undefined (NULL) if the host profile mysteriously disappears.
		$values{'hostprofile_id'} = $profile{'hostprofile_id'};
	    }
	    else {
		$values{'hostprofile_id'} = undef;
	    }
	    my $disappeared = 0;
	    unless ( $values{'hostprofile_id'} ) {
		if ($default_profile) {
		    ## If the selected host profile disappeared, and that host profile was reference by this schema,
		    ## the entire schema row and all the match data went with it, due to cascading deletes.
		    my %schema = StorProc->fetch_one( 'import_schema', 'name', $automation_name );
		    if ( $schema{'name'} ) {
			push @errors, "Host profile \"$default_profile\" has disappeared since this screen was displayed.";
		    }
		    else {
			push @errors, "Automation scheme \"$automation_name\" has disappeared since this screen was displayed.";
			$disappeared = 1;
		    }
		}
		if ( ! $disappeared && $type eq 'host-profile-sync' ) {
		    push @errors, 'You must specify a different default host profile for this schema type.';
		}
	    }
	    ## If the schema has disappeared, any associated data columns have also disappeared,
	    ## so we won't try to reconstruct the schema here by inserting instead of updating.
	    if (! $disappeared) {
		my $result = StorProc->update_obj( 'import_schema', 'name', $automation_name, \%values );
		if ( $result =~ /error/i ) {
		    push @errors, $result;
		}
		else {
		    foreach my $col_id ( keys %{ $schema{'column'} } ) {
			my %vals = ( 'position' => $schema{'column'}{$col_id}{'position'} );
			my $result = StorProc->update_obj( 'import_column', 'column_id', $col_id, \%vals );
			if ( $result =~ /error/i ) { push @errors, $result }
		    }
		    if ( defined($saved) ) { $saved .= '<br>' }
		    if (! @errors) {
			$saved .= "Changes to \"$automation_name\" saved to database.";
		    }
		}
	    }
	}
    }
    if ($update_match) {
	## GWMON-4306: Refactored order substitution on update -sparris 24 Feb 08
	my $new_match_order = $query->param('order');    # From update match sub form
	$new_match_order =~ s/^\s+|\s+$//g if defined $new_match_order;
	$match_name      =~ s/^\s+|\s+$//g if defined $match_name;
	if ( $match_name && $new_match_order =~ /^\d+$/ ) {
	    my %match_order = ();
	    my $i           = 1;
	    foreach my $match ( keys %{ $schema{'column'}{$column_id}{'match'} } ) {
		unless ( $match_id eq $match ) {
		    $match_order{ $schema{'column'}{$column_id}{'match'}{$match}{'order'} } = $match;
		}
		if ( $match ne $match_id && $schema{'column'}{$column_id}{'match'}{$match}{'name'} eq $match_name ) {
		    push @errors, "A match task with name \"$match_name\" already exists.";
		}
		$i++;
	    }
	    unless (@errors) {
		## See if we need to reset order values (stored value differs from new)
		if ( $schema{'column'}{$column_id}{'match'}{$match_id}{'order'} ne $new_match_order ) {
		    ## Make sure order value falls withing a valid range
		    ## Note: $i is 1 greater than total matches so we can assign it to the match if the user entered a bigger number.
		    if ( $new_match_order > $i ) { $new_match_order = $i }
		    if ( $new_match_order < 1 )  { $new_match_order = 1 }
		    my $vacant_pos = $schema{'column'}{$column_id}{'match'}{$match_id}{'order'};
		    foreach my $ord ( keys %match_order ) {
			my $order = $ord;
			if ( $vacant_pos > $new_match_order ) {
			    if ( $order >= $new_match_order && $order < $vacant_pos ) {
				$order++;
				my %vals = ( 'match_order' => $order );
				my $result = StorProc->update_obj( 'import_match', 'match_id', $match_order{$ord}, \%vals );
				if ( $result =~ /error/i ) {
				    push @errors, $result;
				}
				$schema{'column'}{$column_id}{'match'}{ $match_order{$ord} }{'order'} = $order;
			    }
			}
			else {
			    if ( $order <= $new_match_order && $order > $vacant_pos ) {
				$order--;
				my %vals = ( 'match_order' => $order );
				my $result = StorProc->update_obj( 'import_match', 'match_id', $match_order{$ord}, \%vals );
				if ( $result =~ /error/i ) {
				    push @errors, $result;
				}
				$schema{'column'}{$column_id}{'match'}{ $match_order{$ord} }{'order'} = $order;
			    }
			}
		    }
		}
		my %host_profile = ();
		my %values       = (
		    'name'           => $match_name,
		    'match_order'    => $new_match_order,
		    'match_type'     => $match_type,
		    'match_string'   => $match_string,
		    'rule'           => $rule,
		    'object'         => $object,
		    'hostprofile_id' => '0',
		    'servicename_id' => '0',
		    'arguments'      => ''
		);
		my $results = StorProc->update_obj( 'import_match', 'match_id', $match_id, \%values );
		if ( $results =~ /error/i ) {
		    push @errors, $results;
		}
		else {
		    $schema{'column'}{$column_id}{'match'}{$match_id}{'name'}         = $match_name;
		    $schema{'column'}{$column_id}{'match'}{$match_id}{'order'}        = $new_match_order;
		    $schema{'column'}{$column_id}{'match'}{$match_id}{'match_type'}   = $match_type;
		    $schema{'column'}{$column_id}{'match'}{$match_id}{'match_string'} = $match_string;
		    $schema{'column'}{$column_id}{'match'}{$match_id}{'rule'}         = $rule;
		    $schema{'column'}{$column_id}{'match'}{$match_id}{'object'}       = $object;
		}
		if ( $query->param('assign_host_profile') ) {
		    my $host_profile = $query->param('assign_host_profile');
		    my %profile      = StorProc->fetch_one( 'profiles_host', 'name', $host_profile );
		    my %values       = (
			'hostprofile_id' => $profile{'hostprofile_id'},
			'object'         => 'Host profile'
		    );
		    my $results = StorProc->update_obj( 'import_match', 'match_id', $match_id, \%values );
		    if ( $results =~ /error/i ) {
			push @errors, $results;
		    }
		    else {
			$schema{'column'}{$column_id}{'match'}{$match_id}{'hostprofile'} = $host_profile;
		    }
		}
		elsif ( $query->param('service_name') ) {
		    my $service_name = $query->param('service_name');
		    my $arguments    = $query->param('arguments');
		    my %service      = StorProc->fetch_one( 'service_names', 'name', $service_name );
		    my %values       = (
			'servicename_id' => $service{'servicename_id'},
			'object'         => 'Service',
			'arguments'      => $arguments
		    );
		    my $results = StorProc->update_obj( 'import_match', 'match_id', $match_id, \%values );
		    if ( $results =~ /error/i ) {
			push @errors, $results;
		    }
		    else {
			$schema{'column'}{$column_id}{'match'}{$match_id}{'service'} = $service_name;
		    }
		}
		elsif ( defined $object ) {
		    if ( $object =~ /Host group/ ) {
			@{ $schema{'column'}{$column_id}{'match'}{$match_id}{'hostgroups'} } = ();
			my @hostgroups = $query->$multi_param('objects');
			my %where      = ( 'match_id' => $match_id );
			my $result     = StorProc->delete_one_where( 'import_match_hostgroup', \%where );
			if ( $results =~ /error/i ) {
			    push @errors, $results;
			}
			else {
			    my %hostgroup_name = StorProc->get_table_objects('hostgroups');
			    foreach my $hg (@hostgroups) {
				my @vals = ( $match_id, $hostgroup_name{$hg} );
				my $result = StorProc->insert_obj( 'import_match_hostgroup', \@vals );
				if ( $result =~ /error/i ) {
				    push @errors, $result;
				}
				else {
				    push @{ $schema{'column'}{$column_id}{'match'}{$match_id}{'hostgroups'} }, $hg;
				}
			    }
			}
		    }
		    elsif ( $object =~ /Parent/ ) {
			@{ $schema{'column'}{$column_id}{'match'}{$match_id}{'parents'} } = ();
			my @parents = $query->$multi_param('objects');
			my %where   = ( 'match_id' => $match_id );
			my $result  = StorProc->delete_one_where( 'import_match_parent', \%where );
			if ( $results =~ /error/i ) {
			    push @errors, $results;
			}
			else {
			    my %host_name = StorProc->get_table_objects('hosts');
			    foreach my $p (@parents) {
				my @vals = ( $match_id, $host_name{$p} );
				my $result = StorProc->insert_obj( 'import_match_parent', \@vals );
				if ( $result =~ /error/i ) {
				    push @errors, $result;
				}
				else {
				    push @{ $schema{'column'}{$column_id}{'match'}{$match_id}{'parents'} }, $p;
				}
			    }
			}
		    }
		    elsif ( $object =~ /Contact group/ ) {
			@{ $schema{'column'}{$column_id}{'match'}{$match_id}{'contactgroups'} } = ();
			my @contactgroups = $query->$multi_param('objects');
			my %where         = ( 'match_id' => $match_id );
			my $result        = StorProc->delete_one_where( 'import_match_contactgroup', \%where );
			if ( $results =~ /error/i ) {
			    push @errors, $results;
			}
			else {
			    my %groups_name = StorProc->get_table_objects('contactgroups');
			    foreach my $cg (@contactgroups) {
				my @vals = ( $match_id, $groups_name{$cg} );
				my $result = StorProc->insert_obj( 'import_match_contactgroup', \@vals );
				if ( $result =~ /error/i ) {
				    push @errors, $result;
				}
				else {
				    push @{ $schema{'column'}{$column_id}{'match'}{$match_id}{'contactgroups'} }, $cg;
				}
			    }
			}
		    }
		    elsif ( $object =~ /Group/ ) {
			@{ $schema{'column'}{$column_id}{'match'}{$match_id}{'groups'} } = ();
			my @groups = $query->$multi_param('objects');
			my %where  = ( 'match_id' => $match_id );
			my $result = StorProc->delete_one_where( 'import_match_group', \%where );
			if ( $results =~ /error/i ) {
			    push @errors, $results;
			}
			else {
			    my %groups_name = StorProc->get_table_objects('monarch_groups');
			    foreach my $g (@groups) {
				my @vals = ( $match_id, $groups_name{$g} );
				my $result = StorProc->insert_obj( 'import_match_group', \@vals );
				if ( $result =~ /error/i ) {
				    push @errors, $result;
				}
				else {
				    push @{ $schema{'column'}{$column_id}{'match'}{$match_id}{'groups'} }, $g;
				}
			    }
			}
		    }
		    elsif ( $object =~ /Service profile/ ) {
			@{ $schema{'column'}{$column_id}{'match'}{$match_id}{'serviceprofiles'} } = ();
			my @serviceprofiles = $query->$multi_param('objects');
			my %where           = ( 'match_id' => $match_id );
			my $result          = StorProc->delete_one_where( 'import_match_serviceprofile', \%where );
			if ( $results =~ /error/i ) {
			    push @errors, $results;
			}
			else {
			    my %profiles_name = StorProc->get_table_objects('profiles_service');
			    foreach my $sp (@serviceprofiles) {
				my @vals = ( $match_id, $profiles_name{$sp} );
				my $result = StorProc->insert_obj( 'import_match_serviceprofile', \@vals );
				if ( $result =~ /error/i ) {
				    push @errors, $result;
				}
				else {
				    push @{ $schema{'column'}{$column_id}{'match'}{$match_id}{'serviceprofiles'} }, $sp;
				}
			    }
			}
		    }
		}
	    }
	}
	unless (!defined($match_name) || @errors) {
	    $updated = "Changes to match task \"$match_name\" saved.";
	}
    }

    if ( $query->param('save_template') ) {
	my $s_description     = $schema{'description'};
	my $s_type            = $schema{'type'};
	my $s_delimiter       = $schema{'delimiter'};
	my $s_sync_object     = $schema{'sync_object'};
	my $s_smart_name      = $schema{'smart_name'};
	my $s_data_source     = $schema{'data_source'};
	my $s_default_profile = $schema{'default_profile'};
	$s_description     = '' if not defined $s_description;
	$s_type            = '' if not defined $s_type;
	$s_delimiter       = '' if not defined $s_delimiter;
	$s_sync_object     = '' if not defined $s_sync_object;
	$s_smart_name      = '' if not defined $s_smart_name;
	$s_data_source     = '' if not defined $s_data_source;
	$s_default_profile = '' if not defined $s_default_profile;
	my $output = qq(<?xml version="1.0" encoding="iso-8859-1" ?>
<import_schema>
 <prop name="description"><![CDATA[$s_description]]></prop>
 <prop name="type"><![CDATA[$s_type]]></prop>
 <prop name="delimiter"><![CDATA[$s_delimiter]]></prop>
 <prop name="sync_object"><![CDATA[$s_sync_object]]></prop>
 <prop name="smart_name"><![CDATA[$s_smart_name]]></prop>
 <prop name="data_source"><![CDATA[$s_data_source]]></prop>
 <prop name="default_profile"><![CDATA[$s_default_profile]]></prop>);

	foreach my $column ( keys %{ $schema{'column'} } ) {
	    my $column_prop = $schema{'column'}{$column};
	    my $c_name      = $column_prop->{'name'};
	    my $c_position  = $column_prop->{'position'};
	    my $c_delimiter = $column_prop->{'delimiter'};
	    $c_name      = '' if not defined $c_name;
	    $c_position  = '' if not defined $c_position;
	    $c_delimiter = '' if not defined $c_delimiter;
	    $output .= qq(
 <column>
  <column_prop name="name"><![CDATA[$c_name]]></column_prop>
  <column_prop name="position"><![CDATA[$c_position]]></column_prop>
  <column_prop name="delimiter"><![CDATA[$c_delimiter]]></column_prop>);
	    foreach my $match ( keys %{ $column_prop->{'match'} } ) {
		my $match_prop     = $column_prop->{'match'}{$match};
		my $m_order        = $match_prop->{'order'};
		my $m_name         = $match_prop->{'name'};
		my $m_match_type   = $match_prop->{'match_type'};
		my $m_match_string = $match_prop->{'match_string'};
		my $m_rule         = $match_prop->{'rule'};
		my $m_object       = $match_prop->{'object'};
		$m_order        = '' if not defined $m_order;
		$m_name         = '' if not defined $m_name;
		$m_match_type   = '' if not defined $m_match_type;
		$m_match_string = '' if not defined $m_match_string;
		$m_rule         = '' if not defined $m_rule;
		$m_object       = '' if not defined $m_object;
		$output .= qq(
  <match>
   <match_prop name="order"><![CDATA[$m_order]]></match_prop>
   <match_prop name="name"><![CDATA[$m_name]]></match_prop>
   <match_prop name="match_type"><![CDATA[$m_match_type]]></match_prop>
   <match_prop name="match_string"><![CDATA[$m_match_string]]></match_prop>
   <match_prop name="rule"><![CDATA[$m_rule]]></match_prop>
   <object>
    <object_prop name="object_type"><![CDATA[$m_object]]></object_prop>);
		foreach my $hostgroup ( @{ $match_prop->{'hostgroups'} } ) {
		    $output .= qq(
    <object_prop name="hostgroup"><![CDATA[$hostgroup]]></object_prop>);
		}
		foreach my $group ( @{ $match_prop->{'groups'} } ) {
		    $output .= qq(
    <object_prop name="group"><![CDATA[$group]]></object_prop>);
		}
		foreach my $contactgroup ( @{ $match_prop->{'contactgroups'} } ) {
		    $output .= qq(
    <object_prop name="contactgroup"><![CDATA[$contactgroup]]></object_prop>);
		}
		foreach my $serviceprofile ( @{ $match_prop->{'serviceprofiles'} } ) {
		    $output .= qq(
    <object_prop name="serviceprofile"><![CDATA[$serviceprofile]]></object_prop>);
		}
		foreach my $parent ( @{ $match_prop->{'parents'} } ) {
		    $output .= qq(
    <object_prop name="parent"><![CDATA[$parent]]></object_prop>);
		}
		if ( $match_prop->{'hostprofile'} ) {
		    $output .= qq(
    <object_prop name="hostprofile"><![CDATA[$match_prop->{'hostprofile'}]]></object_prop>);
		}
		if ( $match_prop->{'service_name'} ) {
		    $output .= qq(
    <object_prop name="service_name"><![CDATA[$match_prop->{'service_name'}]]></object_prop>
    <object_prop name="service_args"><![CDATA[$match_prop->{'arguments'}]]></object_prop>);
		}
		$output .= qq(
   </object>
  </match>);
	    }
	    $output .= qq(
 </column>);
	}
	$output .= qq(
</import_schema>);
	my $template_file = "schema-template-$automation_name";
	$template_file =~ s/\s|\\|\/|\'|\"|\%|\^|\#|\@|\!|\$/-/g;
	if ( !open( FILE, '>', "$auto_path/templates/$template_file.xml" ) ) {
	    push @errors, "Error:  cannot open $auto_path/templates/$template_file.xml to write ($!)";
	}
	else {
	    print FILE $output;
	    close FILE;
	    $saved = "Template saved to $auto_path/templates/$template_file.xml.";
	}
    }
    my $errstr = '';
    foreach my $err (@errors) {
	$errstr .= "<br>&bull;&nbsp;$err";
    }
    if ($errstr) { $errstr = "Error(s): please correct the following: $errstr" }
    $hidden{'obj_view'}  = 'edit_schema';
    $hidden{'column_id'} = $column_id;
    if ( $delete eq 'yesno' ) {
	my $message = qq(Are you sure you want to remove automation schema \"$automation_name\"?);
	$page = Forms->are_you_sure( 'Confirm Delete', $message, 'confirm_delete', \%hidden, '', '1' );
    }
    elsif ( $query->param('import') || $query->param('import_sync') ) {
	$page .= advanced_import();
    }
    elsif ( $delete eq 'deleted' ) {
	$page = Forms->form_top( 'Deleted', '', '2' );
	my @message = ("$automation_name");
	$page .= Forms->form_message( 'Removed:', \@message, 'row1' );
	$page .= Forms->hidden( \%hidden );
	$page .= Forms->form_bottom_buttons( \%continue );
    }
    elsif ($rename) {
	$page = Forms->form_top( 'Rename Schema', '', '2' );
	if ($errstr) { $page .= Forms->form_doc("<h7>$errstr</h7>") }
	$page .= Forms->display_hidden( 'Automation schema name:', 'name', $automation_name );
	$page .= Forms->text_box( 'Rename:', 'new_name', '', $textsize{'long'}, '', '', '', $tab++ );
	## $hidden{'obj_view'} = 'rename';
	$page .= Forms->hidden( \%hidden );
	%cancel = ( 'name' => 'cancel_rename', 'value' => 'Cancel' );
	$page .= Forms->form_bottom_buttons( \%rename, \%cancel, $tab++ );
    }
    unless ($page) {
	## Determine the selected column and match task for when first starting.
	my %columns = ();
	foreach my $key ( keys %{ $schema{'column'} } ) {
	    if ($key) {
		$columns{ $schema{'column'}{$key}{'position'} }{'id'} = $key;
	    }
	}
	foreach my $pos ( sort keys %columns ) {
	    unless ($pos) { next }
	    unless ($column_id) { $column_id = $columns{$pos}{'id'} }
	}
	my %order = ();
	foreach my $key ( keys %{ $schema{'column'}{$column_id}{'match'} } ) {
	    $order{ $schema{'column'}{$column_id}{'match'}{$key}{'order'} }{'id'} = $key;
	}
	foreach my $pos ( sort { $a <=> $b } keys %order ) {
	    unless ($pos) { next }
	    unless ($match_id) { $match_id = $order{$pos}{'id'} }
	}
	my @objects = ();
	my @host_profiles = StorProc->fetch_list( 'profiles_host', 'name' );
	my $match_prop = undef;
	if (defined $match_id) {
	    $match_prop = $schema{'column'}{$column_id}{'match'}{$match_id};
	}
	if ( defined($rule) && $rule eq 'Assign service' ) {
	    @objects = StorProc->fetch_list( 'service_names', 'name' );
	}
	elsif ( defined($rule) && $rule eq 'Assign object(s)' && defined($object) ) {
	    if ($object eq 'Contact group') {
		@objects = StorProc->fetch_list( 'contactgroups', 'name' );
	    }
	    elsif ($object eq 'Group') {
		@objects = StorProc->fetch_list( 'monarch_groups', 'name' );
	    }
	    elsif ($object eq 'Host group') {
		@objects = StorProc->fetch_list( 'hostgroups', 'name' );
	    }
	    elsif ($object eq 'Parent') {
		@objects = StorProc->fetch_list( 'hosts', 'name' );
	    }
	    elsif ($object eq 'Service profile') {
		@objects = StorProc->fetch_list( 'profiles_service', 'name' );
	    }
	}
	## FIX THIS:  Why was it necessary to add this condition?
	## In contrast, what are the rest of these conditions testing for,
	## and why don't they use the same kind of formulation?
	elsif ( defined($rule) && $rule =~ 'Assign host profile' ) {
	    @objects = @host_profiles;
	}
	elsif ( defined($match_prop) && defined( $match_prop->{'rule'} ) && $match_prop->{'rule'} =~ /Assign host profile/ ) {
	    @objects = @host_profiles;
	}
	elsif ( defined($match_prop) && defined( $match_prop->{'rule'} ) && $match_prop->{'rule'} eq 'Assign service' ) {
	    @objects = StorProc->fetch_list( 'service_names', 'name' );
	}
	elsif ( defined($match_prop) && defined ( $match_prop->{'object'} ) ) {
	    if ( $match_prop->{'object'} eq 'Contact group' ) {
		@objects = StorProc->fetch_list( 'contactgroups', 'name' );
	    }
	    elsif ( $match_prop->{'object'} eq 'Parent' ) {
		@objects = StorProc->fetch_list( 'hosts', 'name' );
	    }
	    elsif ( $match_prop->{'object'} eq 'Group' ) {
		@objects = StorProc->fetch_list( 'monarch_groups', 'name' );
	    }
	    elsif ( $match_prop->{'object'} eq 'Host group' ) {
		@objects = StorProc->fetch_list( 'hostgroups', 'name' );
	    }
	    elsif ( $match_prop->{'object'} eq 'Service profile' ) {
		@objects = StorProc->fetch_list( 'profiles_service', 'name' );
	    }
	}
	$page = Forms->form_top( 'Modify Automation Schema', '', '2' );
	if ($errstr)           { $page .= Forms->form_doc("<h7>$errstr</h7>") }
	if ( defined($saved) ) { $page .= Forms->form_doc("<h1>$saved</h1>") }
	$show_scrolled = 0 if @errors or $query->param('save');
	$page .= AutoConfig->import_schema( \%schema, $column_id, $match_id, $match_name, \@objects, \@host_profiles, $updated, $discover_name,
	    $match_type, $rule, $object, $show_scrolled );
	$hidden{'match_selected'}  = $match_id;
	$hidden{'column_selected'} = $column_id;
	foreach my $rec (@processed) {
	    my %record = ( 'processed' => $rec );
	    $page .= Forms->hidden( \%record );
	}
	$page .= Forms->hidden( \%hidden );
	$page .= Forms->form_bottom_buttons();
    }
    return $page;
}

#
# Form to manually import data and test schema
#

sub advanced_import() {
    $hidden{'automation_name'} = $automation_name;
    $hidden{'view'}            = 'automation';
    $hidden{'obj_view'}        = 'import';
    my @records   = $query->$multi_param('record');
    my $sort_by   = $query->param('sort_by');
    my $sort_on   = $query->param('sort_on');
    my $select_on = $query->param('select_on');
    if ($select_on) {
	if ( $select_on =~ /exception/i ) {
	    $sort_on = 'exception';
	}
	elsif ( $select_on =~ /exists/i ) {
	    $sort_on = 'exists';
	}
	elsif ( $select_on =~ /delete/i ) {
	    $sort_on = 'delete';
	}
	elsif ( $select_on =~ /new parent/i ) {
	    $sort_on = 'new_parent';
	}
	else {
	    $sort_on = 'new';
	}
    }
    my %processed_records = ();
    if ( $query->param('discard') ) {
	foreach my $record (@records) {
	    my $record_unesc = uri_unescape($record);
	    $processed_records{$record_unesc} = 1;
	}
    }
    my $saved     = undef;
    my %overrides = ();
    $overrides{'profiles_host_checked'} = $query->param('profiles_host_checked');
    $overrides{'profiles_host'}         = $query->param('profiles_host');

    $overrides{'monarch_groups_checked'} = $query->param('monarch_groups_checked');
    $overrides{'monarch_groups_merge'}   = $query->param('monarch_groups_merge');
    @{ $overrides{'monarch_groups'} } = $query->$multi_param('monarch_groups');

    $overrides{'parents_checked'} = $query->param('parents_checked');
    $overrides{'parents_merge'}   = $query->param('parents_merge');
    @{ $overrides{'parents'} } = $query->$multi_param('parents');

    $overrides{'contactgroups_checked'} = $query->param('contactgroups_checked');
    $overrides{'contactgroups_merge'}   = $query->param('contactgroups_merge');
    @{ $overrides{'contactgroups'} } = $query->$multi_param('contactgroups');

    $overrides{'profiles_service_checked'} = $query->param('profiles_service_checked');
    $overrides{'profiles_service_merge'}   = $query->param('profiles_service_merge');
    @{ $overrides{'profiles_service'} } = $query->$multi_param('profiles_service');

    $overrides{'hostgroups_checked'} = $query->param('hostgroups_checked');
    $overrides{'hostgroups_merge'}   = $query->param('hostgroups_merge');
    @{ $overrides{'hostgroups'} } = $query->$multi_param('hostgroups');

    $overrides{'services_checked'} = $query->param('services_checked');
    $overrides{'services_merge'}   = $query->param('services_merge');
    @{ $overrides{'services'} } = $query->$multi_param('services');

    my %hosts         = ();
    my @checked_hosts = $query->$multi_param('host_checked');
    foreach my $host (@checked_hosts) {
	$hosts{$host} = 1;
    }

    # FIX MINOR:  This parameter and array appear to be completely unset and unused.
    # But look at the "Discard" button in the Process Records screen, and how it is handled.
    my @host_discarded = $query->$multi_param('host_discarded');

    if ( $query->param('import') && @records ) {
	my %host_name           = StorProc->get_table_objects('hosts');
	my %group_name          = StorProc->get_table_objects('monarch_groups');
	my %hostgroup_name      = StorProc->get_table_objects('hostgroups');
	my %contactgroup_name   = StorProc->get_table_objects('contactgroups');
	my %serviceprofile_name = StorProc->get_table_objects('profiles_service');
	my %service_name        = StorProc->get_table_objects('service_names');
	my %import_data         = ();
	foreach my $rec (@records) {
	    $import_data{$rec}{'Name'} = $query->param("hostname_$rec");
	    if ( $query->param("delete_$rec") ) {
		$import_data{$rec}{'delete'}  = 1;
		$import_data{$rec}{'host_id'} = $query->param("host_id_$rec");
	    }
	    else {
		if ( $host_name{ $import_data{$rec}{'Name'} } ) {
		    $import_data{$rec}{'exists'}  = 1;
		    $import_data{$rec}{'host_id'} = $host_name{ $import_data{$rec}{'Name'} };
		}
		$import_data{$rec}{'Address'}      = $query->param("address_$rec");
		$import_data{$rec}{'Alias'}        = uri_unescape( scalar $query->param("alias_$rec") );
		$import_data{$rec}{'Description'}  = uri_unescape( scalar $query->param("description_$rec") );
		$import_data{$rec}{'Host profile'} = $query->param("hostprofile_$rec");
		if ( $query->param("new_parent_$rec") ) {
		    $import_data{$rec}{'new_parent'} = $query->param("new_parent_$rec");
		}
		my @parents = $query->$multi_param("parent_$rec");
		foreach my $parent (@parents) {
		    my $unesc = uri_unescape($parent);
		    $import_data{$rec}{'Parent'}{$unesc} = $host_name{$unesc};
		}
		my @groups = $query->$multi_param("group_$rec");
		foreach my $group (@groups) {
		    my $unesc = uri_unescape($group);
		    $import_data{$rec}{'Group'}{$unesc} = $group_name{$unesc};
		}
		my @hostgroups = $query->$multi_param("hostgroup_$rec");
		foreach my $group (@hostgroups) {
		    my $unesc = uri_unescape($group);
		    $import_data{$rec}{'Host group'}{$unesc} = $hostgroup_name{$unesc};
		}
		my @contactgroups = $query->$multi_param("contactgroup_$rec");
		foreach my $group (@contactgroups) {
		    my $unesc = uri_unescape($group);
		    $import_data{$rec}{'Contact group'}{$unesc} = $contactgroup_name{$unesc};
		}
		my @serviceprofiles = $query->$multi_param("serviceprofile_$rec");
		foreach my $serviceprofile (@serviceprofiles) {
		    my $unesc = uri_unescape($serviceprofile);
		    $import_data{$rec}{'Service profile'}{$unesc} = $serviceprofile_name{$unesc};
		}

		my @services = $query->$multi_param("services_$rec");
		foreach my $service (@services) {
		    my $command_line       = $query->param("command_line_$rec-$service");
		    my $unesc              = uri_unescape($service);
		    my $unesc_command_line = uri_unescape($command_line);
		    $import_data{$rec}{'Service'}{$unesc}{'command_line'} = $unesc_command_line;
		    my @service_instances = $query->$multi_param("service_instances_$rec-$service");
		    foreach my $instance (@service_instances) {
			my $unesc_inst      = uri_unescape($instance);
			my $arguments       = $query->param("host_serv_inst_args_$rec-$service-$instance");
			my $unesc_inst_args = uri_unescape($arguments);
			$import_data{$rec}{'Service'}{$unesc}{'instance'}{$unesc_inst}{'arguments'} = $unesc_inst_args;
		    }
		}

		if ( $overrides{'profiles_host_checked'} ) {
		    $import_data{$rec}{'Host profile'} = $overrides{'profiles_host'};
		}
		if ( $overrides{'parents_checked'} ) {
		    if ( $overrides{'parents_merge'} eq 'replace' ) {
			delete $import_data{$rec}{'Parent'};
		    }
		    foreach my $parent ( @{ $overrides{'parents'} } ) {
			$import_data{$rec}{'Parent'}{$parent} = $host_name{$parent};
		    }
		    ## FIX MAJOR:  What's the sense in using an arrayref as a hash key?
		    ## Is this just old leftover code that never got removed?
		    $import_data{$rec}{'Parent'}{ $overrides{'parents'} } = $host_name{ $overrides{'parents'} };
		}
		if ( $overrides{'contactgroups_checked'} ) {
		    if ( $overrides{'contactgroups_merge'} eq 'replace' ) {
			delete $import_data{$rec}{'Contact group'};
		    }
		    foreach my $cg ( @{ $overrides{'contactgroups'} } ) {
			$import_data{$rec}{'Contact group'}{$cg} = $contactgroup_name{$cg};
		    }
		}
		if ( $overrides{'profiles_service_checked'} ) {
		    if ( $overrides{'profiles_service_merge'} eq 'replace' ) {
			delete $import_data{$rec}{'Service profile'};
		    }
		    foreach my $sp ( @{ $overrides{'profiles_service'} } ) {
			$import_data{$rec}{'Service profile'}{$sp} = $serviceprofile_name{$sp};
		    }
		}
		if ( $overrides{'hostgroups_checked'} ) {
		    if ( $overrides{'hostgroups_merge'} eq 'replace' ) {
			delete $import_data{$rec}{'Host group'};
		    }
		    foreach my $hg ( @{ $overrides{'hostgroups'} } ) {
			$import_data{$rec}{'Host group'}{$hg} = $hostgroup_name{$hg};
		    }
		}
		if ( $overrides{'monarch_groups_checked'} ) {
		    if ( $overrides{'monarch_groups_merge'} eq 'replace' ) {
			delete $import_data{$rec}{'Group'};
		    }
		    foreach my $g ( @{ $overrides{'monarch_groups'} } ) {
			$import_data{$rec}{'Group'}{$g} = $group_name{$g};
		    }
		}
		if ( $overrides{'services_checked'} ) {
		    unless ( $overrides{'services_merge'} eq 'merge' ) {
			delete $import_data{$rec}{'Service'};
		    }
		    foreach my $service ( @{ $overrides{'services'} } ) {
			my $check_command = $query->param("check_command_$service");
			my $arguments     = $query->param("arguments_$service");
			if ($arguments) {
			    unless ( $arguments =~ /^\!/ ) {
				$arguments = "!$arguments";
			    }
			}
			$import_data{$rec}{'Service'}{$service}{'command_line'} = $check_command . $arguments;
			my @service_instances = $query->$multi_param("instances_$service");
			foreach my $instance (@service_instances) {
			    my $arguments = $query->param("instances_arguments_$service\_$instance");
			    $import_data{$rec}{'Service'}{$service}{'instance'}{$instance}{'arguments'} = $arguments;
			}
		    }
		}
	    }
	}
	my %results = AutoConfig->process_import_data( \%import_data );
	my $cnt     = 0;
	foreach my $rec ( keys %import_data ) {
	    if ( $results{'errors'}{ $import_data{$rec}{'Name'} } ) {
		push @errors, "$import_data{$rec}{'Name'}: $results{'errors'}{$import_data{$rec}{'Name'}}";
	    }
	    else {
		$processed_records{$rec} = 1;
		$cnt++;
	    }
	}
	$saved = "<h1>$cnt Host" . ( $cnt == 1 ? '' : 's' ) . ' processed</h1>';
	$sort_on = undef;
    }
    my ( $import_data, $schema, $errors ) =
      AutoConfig->advanced_import( $automation_name, $import_file, $processed_file, $config_settings{'monarch_home'} );
    my %schema      = %{$schema};
    my %import_data = %{$import_data};
    if ( @{$errors} ) { push( @errors, @{$errors} ) }
    if ( $query->param('import_sync') ) {
	my %results = AutoConfig->process_import_sync( \%schema, \%import_data );
	if ( $results{'errors'} ) {
	    foreach my $host ( sort keys %{ $results{'errors'} } ) {
		push @errors, "$host: $results{'errors'}{$host}";
	    }
	}
	else {
	    $saved = '<h1>added</h1>';
	}
    }
    my $errstr = undef;
    foreach my $err (@errors) {
	$errstr .= "<br>&bull;&nbsp;$err";
    }

    my %objects = ();
    if ( $schema{'type'} eq 'other-sync' ) {
	if ( defined($saved) ) {
	    $page = Forms->form_top( 'Auto Configuration', '', '2', '100%' );
	    if ( defined($saved) ) {
		$page .= Forms->wizard_doc( 'Imported', $saved );
	    }
	    $page .= Forms->form_bottom_buttons( \%close );
	}
	else {
	    $page = Forms->form_top( 'Auto Configuration', '', '2', '100%' );

	    if ($errstr) {
		$errstr = "Error(s): please correct the following: $errstr";
		$page .= Forms->form_doc("<h7>$errstr</h7>");
	    }
	    if ( defined($saved) ) {
		$page .= Forms->wizard_doc( 'Imported', $saved );
	    }
	    $page .= Forms->wizard_doc( $schema{'name'}, $schema{'description'} );
	    $page .= AutoConfig->import_sync_other( \%schema, \%import_data );
	    %import = ( 'name' => 'import_sync', 'value' => 'Process Records' );
	    my %edit_schema = ( 'name' => 'edit_schema', 'value' => 'Edit Schema' );
	    $page .= Forms->hidden( \%hidden );
	    $page .= Forms->form_bottom_buttons( \%import, \%edit_schema, \%close );
	}
    }
    else {
	$hidden{'processing_records'} = $query->param('processing_records');
	$page = Forms->form_top( 'Auto Configuration', '', '2', '100%' );
	if ( defined($saved) ) {
	    $page .= Forms->wizard_doc( 'Imported', $saved, undef, 1 );
	}
	my $processed_rec = undef;
	foreach my $primary_rec ( keys %import_data ) {
	    if ( $processed_records{$primary_rec} ) {
		delete $import_data{$primary_rec};
		$processed_rec .= "$primary_rec\n";
	    }
	}
	if ( !open( FILE, '>>', "$automation_data_dir/$processed_file" ) ) {
	    push @errors, "error: cannot open $automation_data_dir/$processed_file to append ($!)";
	}
	else {
	    print FILE $processed_rec if defined $processed_rec;
	    close(FILE);
	}

	my $show_overrides = $query->param('show_overrides');
	if ( $query->param('enable_overrides') ) {
	    $show_overrides = 1;
	}
	elsif ( $query->param('disable_overrides') ) {
	    $show_overrides = 0;
	}
	$hidden{'show_overrides'} = $show_overrides;
	my %doc      = AutoConfig->doc();
	my $overview = "\n$doc{'process'}{'overview'}";
	my $total    = keys %import_data;
	my $display  = 100;
	if ( $total <= 100 ) { $display = $total }
	if ( $total == 0 ) {
	    if ($discover_name) { $hidden{'view'} = 'discover' }
	    my $message = 'All records have been processed. Select <b>Commit</b> to push changes to Nagios.';
	    unless ( $hidden{'processing_records'} ) {
		$message =
"There are no records to process. Did the discovery find anything new? Check the $automation_name schema to see if there is a rule to discard records that match existing hosts.";
	    }
	    if (defined $import_file) {
		unlink "$automation_data_dir/$import_file" or push @errors, "error: cannot unlink $automation_data_dir/$import_file ($!)";
	    }
	    if (defined $processed_file) {
		unlink "$automation_data_dir/$processed_file" or push @errors, "error: cannot unlink $automation_data_dir/$processed_file ($!)";
	    }
	    foreach my $err (@errors) {
		$errstr .= "<br>&bull;&nbsp;$err";
	    }
	    if ($errstr) {
		$errstr = "Error(s): please correct the following: $errstr";
		$page .= Forms->form_doc("<h7>$errstr</h7>");
	    }
	    $page .= Forms->hidden( \%hidden );
	    $page .= Forms->wizard_doc( 'Completed', $message );
	    if ( -x "$config_settings{'monarch_home'}/bin/commit_check" ) {
		my $warning = [ qx($config_settings{'monarch_home'}/bin/commit_check) ];
		if (@$warning && $warning->[0] ne "Configuration looks okay.\n") {
		    $page .= Forms->form_errors( $warning );
		}
	    }
	    my @message =
	      (     'Are you sure you want to overwrite your active Nagios configuration and restart Nagios?'
		  . '<p class=append style="max-width: 850px;">If you choose to continue, and the Commit is successful,'
		  . ' a backup of the new configuration will automatically be created.'
		  . '  You may see a list of all previous backups in the "Configuration > Control > Back up and restore" screen.</p>' );

	    $page .= Forms->form_message( 'Nagios&nbsp;commit:', \@message, '', undef, undef, '5%' );
	    my %docs = Doc->backups();
	    $page .= Forms->new_backup( 'Commit-backup metadata', $docs{'commit'}, $docs{'lock'}, 0, $tab++ );
	    $help{url} = StorProc->doc_section_url('How+to+pre+flight%2C+backup%2C+commit');
	    my %commit = ( 'name' => 'commit', 'value' => 'Commit' );
	    $page .= Forms->form_bottom_buttons( \%close, \%commit, \%help, $tab++ );
	}
	elsif ($errstr) {
	    $hidden{'obj_view'} = 'import';
	    if ($errstr) {
		$errstr = "Error(s): please correct the following: $errstr";
		$page .= Forms->form_doc("<h7>$errstr</h7>");
	    }
	    $page .= Forms->hidden( \%hidden );
	    %import = ( 'name' => 'import_sync', 'value' => 'Edit Records' );
	    my %edit_schema = ( 'name' => 'edit_schema', 'value' => 'Edit Schema' );
	    %select = ( 'name' => 'continue', 'value' => 'Select Schema' );
	    $page .= Forms->form_bottom_buttons( \%import, \%edit_schema, \%select );
	}
	else {
	    $hidden{'processing_records'} = 1;
	    my %service_objs = ();
	    if ($show_overrides) {
		@{ $objects{'parents'} }          = StorProc->fetch_list( 'hosts',            'name' );
		@{ $objects{'contactgroups'} }    = StorProc->fetch_list( 'contactgroups',    'name' );
		@{ $objects{'profiles_host'} }    = StorProc->fetch_list( 'profiles_host',    'name' );
		@{ $objects{'profiles_service'} } = StorProc->fetch_list( 'profiles_service', 'name' );
		@{ $objects{'hostgroups'} }       = StorProc->fetch_list( 'hostgroups',       'name' );
		@{ $objects{'monarch_groups'} }   = StorProc->fetch_list( 'monarch_groups',   'name' );
		@{ $objects{'services'} }         = StorProc->fetch_list( 'service_names',    'name' );

		my $service_selected = $query->param('service_selected');
		if ( $query->param('add_service') ) {
		    $service_selected = $query->param('service_add');
		}
		my @services = ( $query->$multi_param('services') );
		if (@services) {
		    foreach my $service (@services) {
			$overrides{'Service'}{$service}{'assigned'} = 1;
		    }
		}
		foreach my $service ( keys %{ $overrides{'Service'} } ) {
		    unless ($service) { next }
		    foreach my $instance ( keys %{ $overrides{'Service'}{$service}{'instances'} } ) {
			$service_objs{$service}{'instances'}{$instance} = $overrides{'Service'}{$service}{'instances'}{$instance}{'arguments'};
		    }
		}
		foreach my $name ( $query->param ) {
		    if ( $name =~ /remove_service_(.*)/ ) {
			delete $overrides{'Service'}{$1};
			delete $service_objs{$1};
			if ( $service_selected eq $1 ) {
			    $service_selected = undef;
			}
		    }
		}
		my %check_commands = StorProc->get_table_objects( 'commands', '1' );
		my %where          = ();
		my %service_hash   = StorProc->fetch_list_hash_array( 'service_names', \%where );
		foreach my $sid ( keys %service_hash ) {
		    $service_objs{ $service_hash{$sid}[1] }{'id'} = $sid;
		    if ( defined($service_selected) && $service_hash{$sid}[1] eq $service_selected ) {
			$service_objs{ $service_hash{$sid}[1] }{'service_selected'} = $sid;
			$overrides{'Service'}{$service_selected} = 1;
		    }
		    if (defined $service_hash{$sid}[4]) {
			$service_objs{ $service_hash{$sid}[1] }{'check_command'} = $check_commands{ $service_hash{$sid}[4] };
		    }
		    if (defined $service_hash{$sid}[5]) {
			$service_hash{$sid}[5] =~ s/$check_commands{$service_hash{$sid}[4]}//;
			$service_hash{$sid}[5] =~ s/^!//;
		    }
		    if ( $query->param("arguments_$service_hash{$sid}[1]") ) {
			$service_objs{ $service_hash{$sid}[1] }{'arguments'} = $query->param("arguments_$service_hash{$sid}[1]");
		    }
		    else {
			$service_objs{ $service_hash{$sid}[1] }{'arguments'} = $service_hash{$sid}[5];
		    }
		    my @instances = $query->$multi_param("instances_$service_hash{$sid}[1]");
		    foreach my $instance (@instances) {
			my $argument = $query->param( "instances_arguments_$service_hash{$sid}[1]\_$instance" );
			$service_objs{ $service_hash{$sid}[1] }{'instances'}{$instance} = $argument;
		    }
		}
		foreach my $name ( $query->param ) {
		    if ( $name =~ /remove_instance_(.*)/ ) {
			my @instance = split( /:-:/, $1 );
			delete $service_objs{ $instance[0] }{'instances'}{ $instance[1] };
		    }
		}

		if ( $query->param('add_instance') ) {
		    my $instance = $query->param('instance_add');
		    if ( $service_objs{$service_selected}{'instances'}{$instance} ) {
			push @errors, "An instance \"$instance\" already exists.";
		    }
		    elsif ($instance) {
			my $bad_char = undef;
			my $count    = length( $config_settings{'illegal_object_name_chars'} );
			for ( my $i = 0 ; $i <= $count ; $i++ ) {
			    my $char = substr( $config_settings{'illegal_object_name_chars'}, $i, '1' );
			    unless ($char) { $char = 's' }
			    $char = "\\$char";
			    if ( $instance =~ /$char/ ) { $bad_char = 1 }
			}
			if ($bad_char) {
			    push @errors,
			      "An instance cannot contain the following characters or spaces: $config_settings{'illegal_object_name_chars'}.";
			}
			else {
			    $service_objs{$service_selected}{'instances'}{$instance} = $service_objs{$service_selected}{'arguments'};
			}
		    }
		}

	    }
	    foreach my $err (@errors) {
		$errstr .= "<br>&bull;&nbsp;$err";
	    }
	    if ($errstr) {
		$errstr = "Error(s): please correct the following: $errstr";
		$page .= Forms->form_doc("<h7>$errstr</h7>");
	    }
	    $page .= Forms->hidden( \%hidden );
	    my %record = ();
	    foreach my $rec (@records) {
		$record{$rec} = 1;
	    }
	    my %overview = (
		'records'  => "Process records ($display of $total displayed)",
		'overview' => $overview
	    );
	    $page .= AutoConfig->import_form( $automation_name, \%import_data, \%objects, \%overrides, $sort_by, $sort_on,
		$select_on, \%record, $show_overrides, \%service_objs, \%overview );
	}
    }
    return $page;
}

# FIX MINOR:  This implementation should probably be replaced with an invocation of
# MonarchLocks lock files, which don't depend on an assumed ordering of process IDs.
sub exit_if_locked {

    # GWMON-4681

    my $pid = $$;

    # FIX MINOR:  Files in /usr/local/groundwork/tmp/ are subject to being asynchronously
    # cleaned out at odd times by the gwservices script.  Choose some other directory.
    my $tmpdir = '/usr/local/groundwork/tmp';
    my $user   = $userid;                       # don't overwrite global $userid
    $user = 'nobody' unless ( defined($user) && $user ne '' );
    my $lockfile = "$tmpdir/gw-auto-discovery-$user.lock.$pid";

    print STDERR "Auto-Discovery process $pid is using lockfile $lockfile\n" if $debug;

    `touch $lockfile`;
    usleep(200_000);    # 200,000 microseconds == 200 milliseconds

    opendir( DIR, $tmpdir ) or die "ERROR: Auto-Discovery cannot open $tmpdir to read ($!).";
    my @locks = grep( /^gw\-auto\-discovery\-$user\.lock\.(\d+)$/, readdir(DIR) );
    closedir(DIR);

    foreach my $lock (@locks) {
	print STDERR "Auto-Discovery process $pid found lockfile [$lock].\n" if $debug;
	if ( $lock =~ /\.(\d+)$/ ) {
	    my $lock_id = $1;
	    my $five_seconds_as_fraction_of_day = 5 * ( 1 / ( 24 * 60 * 60 ) );

	    # if file over five seconds old, clean it up, and move on.
	    # trusting the filesystem timestamp ... watch out if on NFS without NTP
	    if ( -M "$tmpdir/$lock" > $five_seconds_as_fraction_of_day ) {
		unlink("$tmpdir/$lock");
	    }

	    # FIX MINOR:  This code assumes PIDs are sequential, or at least monotonic.  BIG, BAD assumption.
	    elsif ( $lock_id > $pid ) {
		print STDERR "Auto-Discovery process $pid is deleting $lockfile and exiting.\n" if $debug;
		## FIX MINOR:  This log message is being made unconditional for QA debugging purposes.  Let's see if it shows up in testing.
		print STDERR "Auto-Discovery process $pid is deleting $lockfile and exiting.\n";
		unlink($lockfile);
		exit;
	    }
	}
    }
    print STDERR "Auto-Discovery process $pid is continuing on.\n" if $debug;
    return $lockfile;
}

sub discovery_load_default {
    my $discover_name   = shift;
    my $errors          = shift;
    my $discover_groups = shift;
    my $hidden          = shift;
    my $config_settings = shift;

    my ( $template, $description ) = undef;
    if ( -e "$config_settings->{'monarch_home'}/automation/conf/discover-template-GroundWork-Discovery-Pro.xml" ) {
	$template       = 'GroundWork-Discovery-Pro';
	$$discover_name = 'GroundWork-Discovery-Pro';
	$description    = "Advanced discovery for GroundWork Monitor Professional,\n<br>using Nmap TCP and SNMP discovery";
    }
    elsif ( -e "$config_settings->{'monarch_home'}/automation/conf/discover-template-GroundWork-Community-Discovery.xml" ) {
	$template       = 'GroundWork-Community-Discovery';
	$$discover_name = 'GroundWork-Community-Discovery';
	$description    = "Basic discovery for GroundWork Monitor Community Edition,\n<br>using Nmap TCP and SNMP discovery";
    }
    my $enable_traceroute   = '';
    my $traceroute_command  = 'traceroute not found';
    my $traceroute_max_hops = 5;
    my $traceroute_timeout  = 2;
    if ( -e '/bin/traceroute' ) {
	$traceroute_command = '/bin/traceroute';
	$enable_traceroute  = 'enable_traceroute';
    }
    elsif ( -e '/usr/sbin/traceroute' ) {
	$traceroute_command = '/usr/sbin/traceroute';
	$enable_traceroute  = 'enable_traceroute';
    }
    my $data = qq(<?xml version="1.0" encoding="iso-8859-1" ?>
<data>
 <prop name="auto"><![CDATA[Interactive]]>
 </prop>
 <prop name="enable_traceroute"><![CDATA[$enable_traceroute]]>
 </prop>
 <prop name="traceroute_command"><![CDATA[$traceroute_command]]>
 </prop>
 <prop name="traceroute_max_hops"><![CDATA[$traceroute_max_hops]]>
 </prop>
 <prop name="traceroute_timeout"><![CDATA[$traceroute_timeout]]>
 </prop>
</data>);
    if ($template) {
	StorProc->truncate_table('discover_group_method');
	StorProc->truncate_table('discover_group_filter');
	my @values = ( \undef, $$discover_name, $description, $data, '' );
	my $id = StorProc->insert_obj_id( 'discover_group', \@values, 'group_id' );
	if ( $id =~ /error/i ) {
	    push @$errors, $id;
	}
	else {
	    my $source = "$config_settings->{'monarch_home'}/automation/conf";
	    @$errors = ProfileImporter->apply_discovery_template( $id, $template, $source );

	    # FIX THIS: Look for GWMON-4232 issues
	    my $errs;
	    ($errs, %$discover_groups) = StorProc->get_discovery_groups();
	    push @$errors, @$errs if @$errs;
	    $hidden->{'obj_view'} = '';
	    use IO::Socket;
	    use Sys::Hostname;
	    my $hostname = hostname();
	    my $filter_value = inet_ntoa( ( gethostbyname($hostname) )[4] );
	    $filter_value =~ s/\.\d+$//;
	    $filter_value .= '.*';
	    my @values = ( \undef, 'local subnet', 'include', $filter_value );
	    my $id = StorProc->insert_obj_id( 'discover_filter', \@values, 'filter_id' );
	    if ( $id =~ /error/i ) {
		push @$errors, $id;
	    }
	    else {
		my @values = ( $discover_groups->{$$discover_name}{'id'}, $id );
		my $result = StorProc->insert_obj( 'discover_group_filter', \@values );
		if ( $result =~ /error/i ) {
		    push @$errors, $result;
		}
		else {
		    $discover_groups->{$$discover_name}{'filter'}{'local subnet'}{'type'}   = 'include';
		    $discover_groups->{$$discover_name}{'filter'}{'local subnet'}{'filter'} = $filter_value;
		}
	    }
	}
    }
}

sub discovery_rename_confirmed {
    my $query            = shift;
    my $discovery        = shift;
    my $discover_name    = shift;
    my $errors           = shift;
    my $discover_groups  = shift;
    my $discover_methods = shift;
    my $hidden           = shift;

    my $new_name = $query->param('new_name');
    if ($new_name) {
	if ( $hidden->{'obj_view'} eq 'manage_method' ) {
	    if ( $discover_methods->{$new_name} ) {
		push @$errors, "A method with name \"$new_name\" already exists.";
	    }
	    else {
		my %values = ( 'name' => $new_name );
		my $result = StorProc->update_obj( 'discover_method', 'name', $discovery->get_method(), \%values );
		if ( $result =~ /error/i ) { push @$errors, $result }
		%{ $discover_methods->{$new_name} } = %{ $discover_methods->{ $discovery->get_method() } };
		delete $discover_methods->{ $discovery->get_method() };
		$discovery->set_method($new_name);
	    }
	}
	else {
	    if ( $discover_groups->{$new_name} ) {
		push @$errors, "A definition with name \"$new_name\" already exists.";
	    }
	    else {
		my %values = ( 'name' => $new_name );
		my $result = StorProc->update_obj( 'discover_group', 'name', $$discover_name, \%values );
		if ( $result =~ /error/i ) { push @$errors, $result }
		%{ $discover_groups->{$new_name} } = %{ $discover_groups->{$$discover_name} };
		delete $discover_groups->{$$discover_name};
		$$discover_name = $new_name;
	    }
	}
	if (@$errors) { $discovery->set_flag( 'rename', 1 ) }
    }
    else {
	foreach my $qname ( $query->param ) {
	    unless ( $qname =~ /^nocache$|^delete/ ) {
		$hidden->{$qname} = $query->param($qname);
	    }
	}
	$discovery->set_flag( 'rename', 1 );
	if ( $hidden->{'obj_view'} eq 'manage_method' ) {
	    $discovery->set_flag( 'save_method', 1 );
	}
	else {
	    $discovery->set_flag( 'save_group', 6 );
	}
    }
}

sub discovery_do_prep {
    my $page             = shift;
    my $query            = shift;
    my $discover_groups  = shift;
    my $discover_methods = shift;
    my $hidden           = shift;

    $hidden->{'discover_name'} = $discover_name;
    $page .= AutoConfig->ajax_header();
    use CGI::Ajax;
    my $url = AutoConfig->get_scan_url();

    # 'get_host' (no s) below will be exposed as a JavaScript function that maps to the
    # CGI specified in the URL.  In this case, that CGI contains a single line (other
    # than comments and subroutines) which is a call to a get_hosts() (with an s) Perl
    # subroutine, which happens to be in the same file that the URL points to.
    my $pjx = new CGI::Ajax( 'get_host' => $url );
    $pjx->js_encode_function('encodeURIComponent');
    $page .= Forms->form_top( 'Auto Discovery', '', '2', '100%' );

    # Delete saved filters (used for scripted automation) and use user selected values
    delete $discover_groups->{$discover_name}{'filter'};
    $discover_groups->{$discover_name}{'auto'} = $query->param("auto_$discover_name");
    my @filters = $query->$multi_param('filter');
    foreach my $filter (@filters) {
	$discover_groups->{$discover_name}{'filter'}{$filter}{'type'}   = $query->param("type_$filter");
	$discover_groups->{$discover_name}{'filter'}{$filter}{'filter'} = $query->param("filter_$filter");
    }
    if ( $query->param('method') ) {
	delete $discover_groups->{$discover_name}{'method'};
	my @methods = $query->$multi_param('method');
	foreach my $method (@methods) {
	    $discover_groups->{$discover_name}{'method'}{$method} = $discover_methods->{$method};
	}
    }

    my ( $process, $errors ) = AutoConfig->discover_prep( \%{ $discover_groups->{$discover_name} } );
    if ( @{$errors} ) {
	push( @errors, @{$errors} );
	$page .= Forms->form_errors( \@errors );
	$page .= Forms->hidden( \%$hidden );
	$page .= Forms->form_bottom_buttons( \%cancel );
	$page = $pjx->build_html( $query, $page );
	return $page;
    }
    else {
	my ( $detail, $errstr ) =
	  AutoConfig->discover_form( $discover_name, $process, $import_file, $config_settings{'monarch_home'}, $hidden->{'user_acct'} );
	if ($errstr) {
	    $page .= Forms->form_doc("<h7>$errstr</h7>");
	    ## FIX THIS:  use these lines in this case?
	    ## $page .= Forms->hidden( \%$hidden );
	    ## $page .= Forms->form_bottom_buttons( \%cancel );
	    ## $page = $pjx->build_html( $query, $page );
	    ## return $page;
	}
	else {
	    $page .= $detail;
	}
    }

    $page .= Forms->hidden( \%$hidden );
    $page .= Forms->form_bottom_buttons();
    $page = $pjx->build_html( $query, $page );
}

sub discovery_create_group {
    my $discovery         = shift;
    my $query             = shift;
    my $discover_name_new = shift;
    my $errors            = shift;
    my $discover_groups   = shift;
    my $discover_methods  = shift;
    my $hidden            = shift;

    my $auto = $discovery->get_auto();

    my $template = $query->param('template');

    if ( $discover_groups->{$discover_name_new} ) {
	push @$errors, "A discovery definition with name \"$discover_name_new\" already exists.";
    }
    elsif (( $discover_name_new && $discovery->get_schema_name() )
	|| ( $discover_name_new && $template ) )
    {
	my %schema = StorProc->fetch_one( 'import_schema', 'name', $discovery->get_schema_name() );

	unless ($auto) { $auto = 'Interactive'; $discovery->set_auto($auto); }
	my $data = qq(<?xml version="1.0" encoding="iso-8859-1" ?>
<data>
 <prop name="auto"><![CDATA[$auto]]>
 </prop>
</data>);

	my @values = ( \undef, $discover_name_new, $discovery->get_description(), $data, $schema{'schema_id'} );
	my $id = StorProc->insert_obj_id( 'discover_group', \@values, 'group_id' );
	if ( $id =~ /error/i ) {
	    push @$errors, $id;
	}
	else {
	    if ($template) {
		my $source = "$auto_path/templates";
		if ( $template eq 'GroundWork-Default-Pro' ) {
		    $template = 'GroundWork-Discovery-Pro';
		    $source   = "$auto_path/conf";
		}
		elsif ( $template eq 'GroundWork-Default-OS' ) {
		    $template = 'GroundWork-Community-Discovery';
		    $source   = "$auto_path/conf";
		}
		@$errors = ProfileImporter->apply_discovery_template( $id, $template, $source );
	    }
	    my $errs;
	    ($errs, %$discover_groups) = StorProc->get_discovery_groups();
	    push @$errors, @$errs if @$errs;
	    ($errs, %$discover_methods) = StorProc->get_discovery_methods();
	    push @$errors, @$errs if @$errs;
	    $hidden->{'discover_name'} = $discover_name_new;
	    $hidden->{'obj_view'}      = 'manage_group';
	}
    }
    else {
	push @$errors, 'A discovery name and one of import schema or template is required.';
    }
}

sub discovery_delete_group_if_confirmed {
    my $query           = shift;
    my $discovery       = shift;
    my $discover_name   = shift;
    my $errors          = shift;
    my $discover_groups = shift;
    my $hidden          = shift;

    if ( $query->param('yes') ) {
	my $result = StorProc->delete_all( 'discover_group', 'name', $$discover_name );
	if ( $result =~ /^Error/ ) { push @$errors, $result }
	unless (@$errors) {
	    delete $discover_groups->{$$discover_name};
	    delete $hidden->{'obj_view'};
	    $$discover_name = undef;
	    my @method_ids = $query->$multi_param('method_id');
	    foreach my $mid (@method_ids) {
		my $result = StorProc->delete_all( 'discover_method', 'method_id', $mid );
		if ( $result =~ /^Error/ ) { push @$errors, $result }
	    }
	}
    }
    elsif ( $query->param('no') ) {
	delete $hidden->{'delete_group'};
    }
    else {
	foreach my $qname ( $query->param ) {
	    unless ( $qname =~ /^nocache$|^delete/ ) {
		$hidden->{$qname} = $query->param($qname);
	    }
	}
	$hidden->{'delete_group'} = 1;
	$discovery->set_flag( 'save_group', 8 );
    }
}

sub discovery_add_method {
    my $empty_data       = shift;
    my $query            = shift;
    my $discovery        = shift;
    my $errors           = shift;
    my $discover_groups  = shift;
    my $discover_methods = shift;
    my $hidden           = shift;

    my $new_method             = StorProc->sanitize_string( scalar $query->param('new_method') );
    my $new_type               = $query->param('new_type');
    my $new_method_description = StorProc->sanitize_string( scalar $query->param('new_method_description') );
    if ( $discover_methods->{$new_method} ) {
	push @$errors, "A method with name \"$new_method\" already exists.";
    }
    elsif ($new_method) {
	my @values = ( \undef, $new_method, $new_method_description, $empty_data, $new_type );
	my $id = StorProc->insert_obj_id( 'discover_method', \@values, 'method_id' );
	if ( $id =~ /error/i ) {
	    push @$errors, $id;
	}
	else {
	    my @values = ( $discover_groups->{$discover_name}{'id'}, $id );
	    my $result = StorProc->insert_obj( 'discover_group_method', \@values );
	    if ( $result =~ /error/i ) { push @$errors, $result }
	    $discover_groups->{$discover_name}{'method'}{$new_method} = 1;
	    $discover_methods->{$new_method}{'id'}                    = $id;
	    $discover_methods->{$new_method}{'name'}                  = $new_method;
	    $discover_methods->{$new_method}{'description'}           = $new_method_description;
	    $discover_methods->{$new_method}{'type'}                  = $new_type;
	    $hidden->{'obj_view'}                                     = 'manage_method';
	    $discovery->set_method($new_method);
	    $discovery->set_flag( 'save_group', 9 );
	}
    }
}

sub discovery_delete_method_if_confirmed {
    my $query            = shift;
    my $discovery        = shift;
    my $errors           = shift;
    my $discover_methods = shift;
    my $hidden           = shift;

    my $method = $discovery->get_method();

    if ( $query->param('yes') ) {
	my $result = StorProc->delete_all( 'discover_method', 'name', $method );
	if ( $result =~ /^Error/ ) { push @$errors, $result }
	unless (@$errors) {
	    delete $discover_methods->{$method};
	    $hidden->{'obj_view'} = 'manage_group';
	}
    }
    elsif ( $query->param('no') ) {
	delete $hidden->{'delete_method'};
    }
    else {
	foreach my $qname ( $query->param ) {
	    unless ( $qname =~ /^nocache$|^delete/ ) {
		$hidden->{$qname} = $query->param($qname);
	    }
	}
	$hidden->{'delete_method'} = 1;
	$discovery->set_flag( 'save_method', 1 );
    }
}

sub discovery_add_filter {
    my $query     = shift;
    my $discovery = shift;
    my $errors    = shift;
    my $hidden    = shift;
    my $filters   = shift;

    # FIX MINOR:  Not used:  what was this for?
    # my @filters = $query->param('filter');

    # GWMON-4241 Refactored add_filter see also save group and save method  - sparris 24 Feb 08
    my $filter_name  = StorProc->sanitize_string( scalar $query->param('filter_name') );
    my $filter_type  = $query->param('filter_type');
    my $filter_value = StorProc->sanitize_string( scalar $query->param('filter_value') );

    if ( exists $filters->{$filter_name} and $filters->{$filter_name} ) {
	push @$errors, "A filter named \"$filter_name\" already exists";
    }
    else {
	if ( $filter_name && $filter_value ) {
	    my @values = ( \undef, $filter_name, $filter_type, $filter_value );
	    my $id = StorProc->insert_obj_id( 'discover_filter', \@values, 'filter_id' );
	    if ( $id =~ /error/i ) {
		push @$errors, $id;
	    }
	    else {
		$filters->{$filter_name}{'id'}     = $id;
		$filters->{$filter_name}{'type'}   = $filter_type;
		$filters->{$filter_name}{'filter'} = $filter_value;
	    }
	}
	else {
	    push @$errors, 'Required: range/filter name, type, and range/filter pattern.';
	}
    }
    unless (@$errors) {
	if ( $hidden->{'obj_view'} eq 'manage_method' ) {
	    $discovery->set_flag( 'save_method', 1 );
	}
	else {
	    $discovery->set_flag( 'save_group', 11 );
	}
    }
}

sub discovery_delete_filter_if_confirmed {
    my $query            = shift;
    my $discovery        = shift;
    my $errors           = shift;
    my $discover_groups  = shift;
    my $discover_methods = shift;
    my $hidden           = shift;
    my $filters          = shift;

    if ( $query->param('yes') ) {
	my $result = StorProc->delete_all( 'discover_filter', 'name', $hidden->{'delete_filter'} );
	if ( $result =~ /^Error/ ) { push @$errors, $result }
	if (   $hidden->{'obj_view'} eq 'manage_group'
	    || $hidden->{'obj_view'} eq 'discover_home' )
	{
	    delete $discover_groups->{$discover_name}{'filter'}{ $hidden->{'delete_filter'} };
	}
	else {
	    delete $discover_methods->{ $discovery->get_method() }{'filter'}{ $hidden->{'delete_filter'} };
	}
	delete $filters->{ $hidden->{'delete_filter'} };
	delete $hidden->{'delete_filter'};

    }
    elsif ( $query->param('no') ) {
	delete $hidden->{'delete_filter'};
    }
    else {
	foreach my $qname ( $query->param ) {
	    unless ( $qname =~ /^nocache$|^delete/ ) {
		$hidden->{$qname} = $query->param($qname);
	    }
	}
	if (   $hidden->{'obj_view'} eq 'manage_group'
	    || $hidden->{'obj_view'} eq 'discover_home' )
	{
	    $discovery->set_flag( 'save_group', 12 );
	}
	else {
	    $discovery->set_flag( 'save_method', 1 );
	}
    }
}

sub discovery_save_method {
    my $saved            = shift;
    my $query            = shift;
    my $discovery        = shift;
    my $errors           = shift;
    my $discover_methods = shift;
    my $hidden           = shift;
    my $filters          = shift;

    my $method = $discovery->get_method();

    my %values = ( 'description' => $discovery->get_description() );
    $discover_methods->{$method}{'description'} = $discovery->get_description();
    if ( $discover_methods->{$method}{'type'} eq 'Nmap' ) {
	my $timeout        = $query->param('timeout');
	my $snmp_strings   = $query->param('snmp_strings');
	my $tcp_snmp_check = $query->param('tcp_snmp_check');
	my $scan_type      = $query->param('scan_type');
	$timeout        = '' if not defined $timeout;
	$snmp_strings   = '' if not defined $snmp_strings;
	$tcp_snmp_check = '' if not defined $tcp_snmp_check;
	$scan_type      = '' if not defined $scan_type;
	my $data = qq(<?xml version="1.0" encoding="iso-8859-1" ?>
<data>
 <prop name="timeout"><![CDATA[$timeout]]>
 </prop>
 <prop name="tcp_snmp_check"><![CDATA[$tcp_snmp_check]]>
 </prop>
 <prop name="snmp_strings"><![CDATA[$snmp_strings]]>
 </prop>
 <prop name="scan_type"><![CDATA[$scan_type]]>
 </prop>);
	if ( $query->param('add_port') ) {
	    my $add_port   = $query->param('port');
	    my $port_value = $query->param('value');
	    unless ($port_value) { $port_value = 'nmap-default' }
	    $add_port =~ s/\s//g;
	    if ( $discover_methods->{$method}{"port_$add_port"} ) {
		push @$errors, "A port definition \"$add_port\" already exists. Port definitions must be unique.";
	    }
	    else {
		my $check_str = $add_port;
		$check_str =~ s/,|-//g;
		if ( $check_str eq '' || $check_str =~ /\D/ || $add_port =~ /^[-,]|[-,][-,]|[-,]$/ ) {
		    push @$errors,
'Invalid port or port list. Ports must be a single numeric value such as 80, a comma-separated list of ports such as 20,80,8080, or a hyphenated range such as 20-80.';
		}
		else {
		    $saved = "Port $add_port added to method \"$method\".";
		    $discover_methods->{$method}{"port_$add_port"} = $port_value;
		    $data .= qq(
 <prop name="port_$add_port"><![CDATA[$port_value]]>
 </prop>);
		}
	    }
	}

	my @ports = $query->$multi_param('ports');
	foreach my $port (@ports) {
	    if ( $query->param("remove_port_$port") ) {
		delete $discover_methods->{$method}{"port_$port"};
		next;
	    }
	    my $val = $query->param("value_$port");
	    $data .= qq(
 <prop name="port_$port"><![CDATA[$val]]>
 </prop>);
	}
	$data .= "\n</data>";
	$values{'config'} = $data;
    }
    elsif ( $discover_methods->{$method}{'type'} eq 'SNMP' ) {
	my $snmp_ver              = $query->param('snmp_ver');
	my $snmp_v3_user          = $query->param('snmp_v3_user');
	my $snmp_v3_authKey       = $query->param('snmp_v3_authKey');
	my $snmp_v3_privKey       = $query->param('snmp_v3_privKey');
	my $snmp_v3_securityLevel = $query->param('snmp_v3_securityLevel');
	my $snmp_v3_authProtocol  = $query->param('snmp_v3_authProtocol');
	my $snmp_v3_privProtocol  = $query->param('snmp_v3_privProtocol');
	my $snmp_v3_misc          = $query->param('snmp_v3_misc');
	my $community_strings     = $query->param('community_strings');

	$snmp_ver              = '' if not defined $snmp_ver;
	$snmp_v3_user          = '' if not defined $snmp_v3_user;
	$snmp_v3_authKey       = '' if not defined $snmp_v3_authKey;
	$snmp_v3_privKey       = '' if not defined $snmp_v3_privKey;
	$snmp_v3_securityLevel = '' if not defined $snmp_v3_securityLevel;
	$snmp_v3_authProtocol  = '' if not defined $snmp_v3_authProtocol;
	$snmp_v3_privProtocol  = '' if not defined $snmp_v3_privProtocol;
	$snmp_v3_misc          = '' if not defined $snmp_v3_misc;
	$community_strings     = '' if not defined $community_strings;

	my $data = qq(<?xml version="1.0" encoding="iso-8859-1" ?>
<data>
 <prop name="snmp_ver"><![CDATA[$snmp_ver]]>
 </prop>
 <prop name="snmp_v3_user"><![CDATA[$snmp_v3_user]]>
 </prop>
 <prop name="snmp_v3_authKey"><![CDATA[$snmp_v3_authKey]]>
 </prop>
 <prop name="snmp_v3_privKey"><![CDATA[$snmp_v3_privKey]]>
 </prop>
 <prop name="snmp_v3_securityLevel"><![CDATA[$snmp_v3_securityLevel]]>
 </prop>
 <prop name="snmp_v3_authProtocol"><![CDATA[$snmp_v3_authProtocol]]>
 </prop>
 <prop name="snmp_v3_privProtocol"><![CDATA[$snmp_v3_privProtocol]]>
 </prop>
 <prop name="snmp_v3_misc"><![CDATA[$snmp_v3_misc]]>
 </prop>
 <prop name="community_strings"><![CDATA[$community_strings]]>
 </prop>
</data>);
	$values{'config'} = $data;
    }
    elsif ( $discover_methods->{$method}{'type'} eq 'WMI' ) {
	my $wmi_type = $query->param('wmi_type');
	$wmi_type = '' if not defined $wmi_type;
	my $data     = qq(<?xml version="1.0" encoding="iso-8859-1" ?>
<data>
 <prop name="wmi_type"><![CDATA[$wmi_type]]>
 </prop>
</data>);
	$values{'config'} = $data;
    }
    elsif ( $discover_methods->{$method}{'type'} eq 'Script' ) {
	my $script_type  = $query->param('script_type');
	my $run_mode     = $query->param('run_mode');
	my $command_line = StorProc->sanitize_string( scalar $query->param('command_line') );
	$script_type  = '' if not defined $script_type;
	$run_mode     = '' if not defined $run_mode;
	$command_line = '' if not defined $command_line;

	# The XML::LibXML parser we will later use to interpret this fragment probably defaults to a UTF-8
	# encoding, so unless we apply that encoding to the string or explicitly specify some other encoding,
	# we won't be able to stuff 8-bit characters into the command line and have the parser understand it
	# later on.  For now, we just choose a somewhat larger character set than ASCII, not full Unicode,
	# as we have not vetted the entire application for Unicode support.
	my $data = qq(<?xml version="1.0" encoding="iso-8859-1" ?>
<data>
 <prop name="script_type"><![CDATA[$script_type]]>
 </prop>
 <prop name="run_mode"><![CDATA[$run_mode]]>
 </prop>
 <prop name="command_line"><![CDATA[$command_line]]>
 </prop>
</data>);
	$values{'config'} = $data;
    }
    my $result = StorProc->update_obj( 'discover_method', 'name', $method, \%values );
    if ( $result =~ /error/i ) {
	push @$errors, $result;
    }
    else {
	my %where = ( 'method_id' => $discover_methods->{$method}{'id'} );
	my $result = StorProc->delete_one_where( 'discover_method_filter', \%where );
	delete $discover_methods->{$method}{'filter'};
	if ( $result =~ /error/i ) {
	    push @$errors, $result;
	}
	else {
	    my @filters = $query->$multi_param('filter');

	    # GWMON-4241 Set filters on add new filter - sparris 24 Feb 08
	    if ( $query->param('add_filter') ) {
		my $add_filter = StorProc->sanitize_string( scalar $query->param('filter_name') );

		# Avoid undesired auto-vivification here.
		if ( exists $filters->{$add_filter} and $filters->{$add_filter}{'id'} ) {
		    push @filters, $add_filter;
		}
	    }
	    foreach my $filter (@filters) {
		my @values = ( $discover_methods->{$method}{'id'}, $filters->{$filter}{'id'} );
		my $result = StorProc->insert_obj( 'discover_method_filter', \@values );
		if ( $result =~ /error/i ) { push @$errors, $result }
		$discover_methods->{$method}{'filter'}{$filter} = 1;
	    }
	}
    }
    unless (@$errors) {
	unless ( $discovery->get_flag('rename') || $hidden->{'obj_view'} eq 'delete_method' ) {
	    unless ( defined($saved) ) { $saved = "Changes to \"$method\" saved." }
	}
    }
}

sub discovery_save_group {
    my $saved            = shift;
    my $query            = shift;
    my $discovery        = shift;
    my $discover_name    = shift;
    my $errors           = shift;
    my $discover_groups  = shift;
    my $discover_methods = shift;
    my $hidden           = shift;
    my $filters          = shift;

    my $auto = $discovery->get_auto();

    my %values = ();
    if ( $hidden->{'obj_view'} eq 'discover_home' ) {
	$discovery->set_enable_traceroute( $discover_groups->{$discover_name}{'enable_traceroute'} );
	$discovery->set_traceroute_command( $discover_groups->{$discover_name}{'traceroute_command'} );
	$discovery->set_traceroute_max_hops( $discover_groups->{$discover_name}{'traceroute_max_hops'} );
	$discovery->set_traceroute_timeout( $discover_groups->{$discover_name}{'traceroute_timeout'} );
    }
    else {
	$values{'description'} = $query->param('description');
	my %schema = StorProc->fetch_one( 'import_schema', 'name', $discovery->get_schema_name() );
	$values{'schema_id'}                              = $schema{'schema_id'};
	$discover_groups->{$discover_name}{'schema'}      = $discovery->get_schema_name();
	$discover_groups->{$discover_name}{'description'} = $values{'description'};
    }

    my $traceroute_timeout  = $discovery->get_traceroute_timeout();
    my $traceroute_command  = $discovery->get_traceroute_command();
    my $traceroute_max_hops = $discovery->get_traceroute_max_hops();
    my $enable_traceroute   = $discovery->get_enable_traceroute();
    $traceroute_timeout  = '' if not defined $traceroute_timeout;
    $traceroute_command  = '' if not defined $traceroute_command;
    $traceroute_max_hops = '' if not defined $traceroute_max_hops;
    $enable_traceroute   = '' if not defined $enable_traceroute;

    my $data = qq(<?xml version="1.0" encoding="iso-8859-1" ?>
<data>
 <prop name="auto"><![CDATA[$auto]]>
 </prop>
 <prop name="enable_traceroute"><![CDATA[$enable_traceroute]]>
 </prop>
 <prop name="traceroute_command"><![CDATA[$traceroute_command]]>
 </prop>
 <prop name="traceroute_max_hops"><![CDATA[$traceroute_max_hops]]>
 </prop>
 <prop name="traceroute_timeout"><![CDATA[$traceroute_timeout]]>
 </prop>
</data>);
    $values{'config'} = $data;
    my $result = '';
    if ( !( defined( $query->param('new_group') ) && $query->param('new_group') eq 'New' ) ) {    # GWMON-4873
	$result = StorProc->update_obj( 'discover_group', 'name', $discover_name, \%values );
    }
    if ( $result =~ /error/i ) {
	push @$errors, $result;
    }
    else {
	$discover_groups->{$discover_name}{'auto'}                = $auto;
	$discover_groups->{$discover_name}{'enable_traceroute'}   = $enable_traceroute;
	$discover_groups->{$discover_name}{'traceroute_command'}  = $traceroute_command;
	$discover_groups->{$discover_name}{'traceroute_max_hops'} = $traceroute_max_hops;
	$discover_groups->{$discover_name}{'traceroute_timeout'}  = $traceroute_timeout;

	# GWMON-4241 Set filters on add new filter - sparris 24 Feb 08
	my @filters = $query->$multi_param('filter');
	if ( $query->param('add_filter') ) {
	    my $add_filter = StorProc->sanitize_string( scalar $query->param('filter_name') );

	    # Avoid undesired auto-vivification here, to prevent GWMON-5746.
	    if ( exists $filters->{$add_filter} and $filters->{$add_filter}{'id'} ) {
		push @filters, $add_filter;
	    }
	}
	my $result = StorProc->delete_all( 'discover_group_filter', 'group_id', $discover_groups->{$discover_name}{'id'} );
	if ( $result =~ /error/i ) { push @$errors, $result }
	delete $discover_groups->{$discover_name}{'filter'};
	foreach my $filter (@filters) {
	    my @values = ( $discover_groups->{$discover_name}{'id'}, $filters->{$filter}{'id'} );
	    my $result = StorProc->insert_obj( 'discover_group_filter', \@values );
	    if ( $result =~ /error/i ) { push @$errors, $result }
	    $discover_groups->{$discover_name}{'filter'}{$filter} = 1;
	}
	if ( $hidden->{'obj_view'} eq 'manage_group' ) {
	    my @methods = $query->$multi_param('method');
	    my $result = StorProc->delete_all( 'discover_group_method', 'group_id', $discover_groups->{$discover_name}{'id'} );
	    if ( $result =~ /error/i ) { push @$errors, $result }
	    delete $discover_groups->{$discover_name}{'method'};
	    foreach my $method (@methods) {
		my @values = ( $discover_groups->{$discover_name}{'id'}, $discover_methods->{$method}{'id'} );
		my $result = StorProc->insert_obj( 'discover_group_method', \@values );
		if ( $result =~ /error/i ) { push @$errors, $result }
		$discover_groups->{$discover_name}{'method'}{$method} = 1;
	    }
	}
    }
    unless (@$errors) { $saved = "Changes to \"$discover_name\" saved." }
    if ( $query->param('close_group') ) { delete $hidden->{'obj_view'} }
    if ( defined( $discovery->get_edit_method() ) ) {
	$hidden->{'obj_view'} = 'manage_method';
	$discovery->set_method( $discovery->get_edit_method() );
    }
}

sub discovery_save_as_template {
    my $discovery        = shift;
    my $saved            = shift;
    my $query            = shift;
    my $discover_name    = shift;
    my $errors           = shift;
    my $discover_methods = shift;

    my $auto = $query->param('auto');

    my $out_xml = qq(<?xml version="1.0" encoding="iso-8859-1" ?>
<discovery>
 <prop name="name"><![CDATA[$discover_name]]></prop>
 <prop name="description"><![CDATA[) . $discovery->get_description() . qq(]]></prop>
 <prop name="schema"><![CDATA[) . $discovery->get_schema_name() . qq(]]></prop>
 <prop name="auto"><![CDATA[$auto]]></prop>);
    my @methods = $query->$multi_param('method');
    foreach my $method (@methods) {
	$out_xml .= qq(
 <method>
  <method_prop name="name"><![CDATA[$method]]></method_prop>);

	foreach my $prop ( keys %{ $discover_methods->{$method} } ) {
	    unless ( $prop eq 'id' ) {
		my $method_prop = $discover_methods->{$method}{$prop};
		$method_prop = '' if not defined $method_prop;
		$out_xml .= qq(
  <method_prop name="$prop"><![CDATA[$method_prop]]></method_prop>);
	    }
	}
	$out_xml .= "\n </method>";
    }
    $out_xml .= "\n</discovery>";
    my $template_file = "discover-template-$discover_name";
    $template_file =~ s/\s|\\|\/|\\' | \"|\%|\^|\#|\@|\!|\$/-/g;
    if ( !open( FILE, '>', "$auto_path/templates/$template_file.xml" ) ) {
	push @$errors, "error:  cannot open $auto_path/templates/$template_file.xml to write ($!)";
    }
    else {
	print FILE $out_xml;
	close FILE;
    }
    $saved = "Discovery template saved to $auto_path/templates/$template_file.xml.";
    my %schema = StorProc->fetch_schema( $discovery->get_schema_name() );
    my $s_description      = $schema{'description'};
    my $s_type             = $schema{'type'};
    my $s_delimiter        = $schema{'delimiter'};
    my $s_sync_object      = $schema{'sync_object'};
    my $s_smart_name       = $schema{'smart_name'};
    my $s_data_source      = $schema{'data_source'};
    my $s_default_profile  = $schema{'default_profile'};
    $s_description     = '' if not defined $s_description;
    $s_type            = '' if not defined $s_type;
    $s_delimiter       = '' if not defined $s_delimiter;
    $s_sync_object     = '' if not defined $s_sync_object;
    $s_smart_name      = '' if not defined $s_smart_name;
    $s_data_source     = '' if not defined $s_data_source;
    $s_default_profile = '' if not defined $s_default_profile;
    my $output = qq(<?xml version="1.0" encoding="iso-8859-1" ?>
<import_schema>
 <prop name="description"><![CDATA[$s_description]]></prop>
 <prop name="type"><![CDATA[$s_type]]></prop>
 <prop name="delimiter"><![CDATA[$s_delimiter]]></prop>
 <prop name="sync_object"><![CDATA[$s_sync_object]]></prop>
 <prop name="smart_name"><![CDATA[$s_smart_name]]></prop>
 <prop name="data_source"><![CDATA[$s_data_source]]></prop>
 <prop name="default_profile"><![CDATA[$s_default_profile]]></prop>);

    foreach my $column ( keys %{ $schema{'column'} } ) {
	my $column_prop = $schema{'column'}{$column};
	my $c_name      = $column_prop->{'name'};
	my $c_position  = $column_prop->{'position'};
	my $c_delimiter = $column_prop->{'delimiter'};
	$c_name      = '' if not defined $c_name;
	$c_position  = '' if not defined $c_position;
	$c_delimiter = '' if not defined $c_delimiter;
	$output .= qq(
 <column>
  <column_prop name="name"><![CDATA[$c_name]]></column_prop>
  <column_prop name="position"><![CDATA[$c_position]]></column_prop>
  <column_prop name="delimiter"><![CDATA[$c_delimiter]]></column_prop>);
	foreach my $match ( keys %{ $column_prop->{'match'} } ) {
	    my $match_prop     = $column_prop->{'match'}{$match};
	    my $m_order        = $match_prop->{'order'};
	    my $m_name         = $match_prop->{'name'};
	    my $m_match_type   = $match_prop->{'match_type'};
	    my $m_match_string = $match_prop->{'match_string'};
	    my $m_rule         = $match_prop->{'rule'};
	    my $m_object       = $match_prop->{'object'};
	    $m_order        = '' if not defined $m_order;
	    $m_name         = '' if not defined $m_name;
	    $m_match_type   = '' if not defined $m_match_type;
	    $m_match_string = '' if not defined $m_match_string;
	    $m_rule         = '' if not defined $m_rule;
	    $m_object       = '' if not defined $m_object;
	    $output .= qq(
  <match>
   <match_prop name="order"><![CDATA[$m_order]]></match_prop>
   <match_prop name="name"><![CDATA[$m_name]]></match_prop>
   <match_prop name="match_type"><![CDATA[$m_match_type]]></match_prop>
   <match_prop name="match_string"><![CDATA[$m_match_string]]></match_prop>
   <match_prop name="rule"><![CDATA[$m_rule]]></match_prop>
   <object>
    <object_prop name="object_type"><![CDATA[$m_object]]></object_prop>);
	    foreach my $hostgroup ( @{ $match_prop->{'hostgroups'} } ) {
		$output .= qq(
    <object_prop name="hostgroup"><![CDATA[$hostgroup]]></object_prop>);
	    }
	    foreach my $group ( @{ $match_prop->{'groups'} } ) {
		$output .= qq(
    <object_prop name="group"><![CDATA[$group]]></object_prop>);
	    }
	    foreach my $contactgroup ( @{ $match_prop->{'contactgroups'} } ) {
		$output .= qq(
    <object_prop name="contactgroup"><![CDATA[$contactgroup]]></object_prop>);
	    }
	    foreach my $serviceprofile ( @{ $match_prop->{'serviceprofiles'} } ) {
		$output .= qq(
    <object_prop name="serviceprofile"><![CDATA[$serviceprofile]]></object_prop>);
	    }
	    foreach my $parent ( @{ $match_prop->{'parents'} } ) {
		$output .= qq(
    <object_prop name="parent"><![CDATA[$parent]]></object_prop>);
	    }
	    if ( $match_prop->{'hostprofile'} ) {
		$output .= qq(
    <object_prop name="hostprofile"><![CDATA[$match_prop->{'hostprofile'}]]></object_prop>);
	    }
	    if ( $match_prop->{'service_name'} ) {
		$output .= qq(
    <object_prop name="service_name"><![CDATA[$match_prop->{'service_name'}]]></object_prop>
    <object_prop name="service_args"><![CDATA[$match_prop->{'arguments'}]]></object_prop>);
	    }
	    $output .= qq(
   </object>
  </match>);
	}
	$output .= qq(
 </column>);
    }
    $output .= qq(
</import_schema>);
    $template_file = "schema-template-$discover_name";
    $template_file =~ s/\s|\\|\/|\\'|\"|\%|\^|\#|\@|\!|\$/-/g;
    if ( !open( FILE, '>', "$auto_path/templates/$template_file.xml" ) ) {
	push @$errors, "error:  cannot open $auto_path/templates/$template_file.xml to write ($!)";
    }
    else {
	print FILE $output;
	close FILE;
    }
    $saved .= "<br>Automation template saved to $auto_path/templates/$template_file.xml.";
}

sub discovery_go {
    my $query            = shift;
    my $discover_name    = shift;
    my $errors           = shift;
    my $discover_groups  = shift;
    my $discover_methods = shift;
    my $hidden           = shift;
    my $filters          = shift;

    my $got_filters     = 0;
    my $nmap_validation = 0;
    my @filters         = $query->$multi_param('filter');
    foreach my $filter (@filters) {
	if ( $filters->{$filter}{'type'} eq 'include' ) {
	    $got_filters = 1;
	}
    }
    if ( $hidden->{'obj_view'} eq 'manage_group' ) {
	if ( $query->param('method') ) {
	    my @methods = $query->$multi_param('method');
	    foreach my $method (@methods) {
		$discover_groups->{$discover_name}{'method'}{$method} = $discover_methods->{$method};
		if ( $discover_groups->{$discover_name}{'method'}{$method}{'type'} eq 'Nmap' ) {
		    my $got_port = 0;
		    foreach my $key ( keys %{ $discover_groups->{$discover_name}{'method'}{$method} } ) {
			if ( $key =~ /port/ ) { $got_port = 1 }
		    }
		    unless ($got_port) {
			push @$errors,
			  "There are no ports assigned to method $method. You must assign at least one port to use an Nmap mehtod.";
		    }
		}
	    }
	    unless ($got_filters) {
		push @$errors,
"There are no ranges assigned to $discover_name or any of its methods. You must assign or select at least one range to discover.";
	    }
	    unless (@$errors) { $hidden->{'obj_view'} = 'discover_disclaimer' }
	}
	else {
	    push @$errors, 'There are no methods selected. You must select at least one discovery method.';
	}
    }
    elsif ($discover_groups->{$discover_name}{'method'} || $query->param('method') ) {
	if ( $query->param('filter') ) {
	    my @filters = $query->$multi_param('filter');
	    foreach my $filter (@filters) {
		if ( $filters->{$filter}{'type'} eq 'include' ) {
		    $got_filters = 1;
		}
	    }
	}
	foreach my $method ( keys %{ $discover_groups->{$discover_name}{'method'} } ) {
	    foreach my $filter ( keys %{ $discover_groups->{$discover_name}{'method'}{$method}{'filter'} } ) {
		if ( $discover_groups->{$discover_name}{'method'}{$method}{'filter'}{$filter}{'type'} eq 'include' ) {
		    $got_filters = 1;
		}
	    }

	    # Scripts don't necessarily require filters -sparris 24 Feb 08
	    if ( $discover_groups->{$discover_name}{'method'}{$method}{'type'} eq 'Script' ) {
		$got_filters = 1;
	    }
	    if ( $discover_groups->{$discover_name}{'method'}{$method}{'type'} eq 'Nmap' ) {
		my $got_port = 0;
		foreach my $key ( keys %{ $discover_groups->{$discover_name}{'method'}{$method} } ) {
		    if ( $key =~ /port/ ) { $got_port = 1 }
		}
		unless ($got_port) {
		    push @$errors, "There are no ports assigned to method $method. You must assign at least one port to use an Nmap method.";
		}
	    }
	}
	unless ($got_filters) {
	    push @$errors,
	      "There are no ranges assigned to $discover_name or any of its methods. You must assign or select at least one range to discover.";
	}
	unless (@$errors) { $hidden->{'obj_view'} = 'discover_disclaimer' }
    }
    else {
	push @$errors, "There are no methods assigned to $discover_name. You must assign at least one discovery method.";
    }
}

sub discovery_prompt_for_rename_confirmation {
    my $page          = shift;
    my $discovery     = shift;
    my $discover_name = shift;
    my $errstr        = shift;
    my $textsize      = shift;
    my $hidden        = shift;

    $page = Forms->form_top( 'Auto Discovery', '', '2' );
    if ($errstr) { $page .= Forms->form_doc("<h7>$errstr</h7>") }
    if ( $hidden->{'obj_view'} eq 'manage_group' ) {
	$page .= Forms->wizard_doc( "Rename \"$discover_name\"?", undef, undef, 1 );
	$page .= Forms->text_box( 'Auto discovery definition name:', 'new_name', '', $textsize->{'long'} );
    }
    else {
	$page .= Forms->wizard_doc( "Rename \"" . $discovery->get_method() . "\"?", undef, undef, 1 );
	$page .= Forms->text_box( 'Auto discovery method name:', 'new_name', '', $textsize->{'long'} );
    }
    $page .= Forms->hidden( \%$hidden );
    $page .= Forms->form_bottom_buttons( \%rename, \%cancel );
    return $page;
}

sub discovery_prompt_for_delete_filter_confirmation {
    my $query            = shift;
    my $page             = shift;
    my $discover_groups  = shift;
    my $discover_methods = shift;
    my $hidden           = shift;

    $page = Forms->form_top( 'Auto Discovery', '', '2' );
    my $message = qq(Are you sure you want to remove filter \"$hidden->{'delete_filter'}\"?);
    foreach my $group ( sort keys %$discover_groups ) {
	if ( $discover_groups->{$group}{'filter'}{ $hidden->{'delete_filter'} } ) {
	    $message .= "<p class=append>&nbsp;&nbsp;&bull;&nbsp;Filter is used by discovery definition \"$group\".</p>";
	}
    }
    foreach my $method ( sort keys %$discover_methods ) {
	if ( $discover_methods->{$method}{'filter'}{ $hidden->{'delete_filter'} } ) {
	    $message .= "<p class=append>&nbsp;&nbsp;&bull;&nbsp;Filter is used by discovery method \"$method\".</p>";
	}
    }
    if ( $query->param('method') ) {
	my @methods = $query->$multi_param('method');
	foreach my $method (@methods) {
	    $hidden->{"method_$method"} = 1;
	}
    }
    if ( $query->param('filter') ) {
	my @filters = $query->$multi_param('filter');
	foreach my $filter (@filters) {
	    $hidden->{"filter_selected_$filter"} = 1;
	}
    }

    $page .= Forms->wizard_doc( "Delete \"$hidden->{'delete_filter'}\"?", $message, undef, 1 );
    $page .= Forms->hidden( \%$hidden );
    my %yes = ( 'name' => 'yes', 'value' => 'Yes' );
    my %no  = ( 'name' => 'no',  'value' => 'No' );
    $page .= Forms->form_bottom_buttons( \%yes, \%no );
    return $page;
}

sub discovery_prompt_for_delete_method_confirmation {
    my $page            = shift;
    my $discovery       = shift;
    my $discover_groups = shift;

    my $method = $discovery->get_method();

    $page = Forms->form_top( 'Auto Discovery', '', '2' );
    my $message = qq(Are you sure you want to remove discovery method \"$method\"?);
    foreach my $group ( sort keys %$discover_groups ) {
	if ( $discover_groups->{$group}{'method'}{$method} ) {
	    $message .= "<p class=append>&nbsp;&nbsp;&bull;&nbsp;Method is used by discovery definition \"$group\".</p>";
	}
    }
    $page .= Forms->wizard_doc( "Delete \"$method\"?", $message, undef, 1 );
    $page .= Forms->hidden( \%hidden );
    my %yes = ( 'name' => 'yes', 'value' => 'Yes' );
    my %no  = ( 'name' => 'no',  'value' => 'No' );
    $page .= Forms->form_bottom_buttons( \%yes, \%no );
    return $page;
}

sub discovery_prompt_for_delete_group_confirmation {
    my $page             = shift;
    my $discover_name    = shift;
    my $discover_groups  = shift;
    my $discover_methods = shift;

    $page = Forms->form_top( 'Auto Discovery', '', '2' );
    my %methods = ();
    foreach my $method ( sort keys %$discover_methods ) {
	if ( $discover_groups->{$discover_name}{'method'}{$method} ) {
	    $methods{$method} = $discover_methods->{$method};
	}
    }
    $page .= AutoConfig->delete_group( $discover_name, \%methods );
    $page .= Forms->hidden( \%hidden );
    my %yes = ( 'name' => 'yes', 'value' => 'Yes' );
    my %no  = ( 'name' => 'no',  'value' => 'No' );
    $page .= Forms->form_bottom_buttons( \%yes, \%no );
    return $page;
}

sub discovery_new_group {
    my $discover_name_new = shift;
    my $page              = shift;
    my $errstr            = shift;
    my $discovery         = shift;
    my $errors            = shift;

    my $type = $discovery->get_type();

    my @templates = ();
    if ( -e "$auto_path/conf/discover-template-GroundWork-Discovery-Pro.xml" ) {
	push @templates, 'GroundWork-Default-Pro';
    }
    elsif ( -e "$auto_path/conf/discover-template-GroundWork-Community-Discovery.xml" ) {
	push @templates, 'GroundWork-Default-OS';
    }

    if ( !opendir( DIR, "$auto_path/templates" ) ) {
	push @$errors, "error: cannot open $auto_path/templates to read ($!)";
    }
    else {
	while ( my $file = readdir(DIR) ) {
	    if ( $file =~ /discover-template-(\S+)\.xml$/ ) { push @templates, $1 }
	}
	closedir(DIR);
    }
    $page = Forms->form_top( 'New Auto Discovery Definition', '', '2' );
    my @schemas = StorProc->fetch_list( 'import_schema', 'name' );
    if ($errstr) { $page .= Forms->form_doc("<h7>$errstr</h7>") }
    $page .= Forms->text_box( 'Auto discovery definition name:', 'discover_name_new', $discover_name_new, $textsize{'long'} );
    $page .= Forms->text_box( 'Description:', 'description', $discovery->get_description(), $textsize{'long'} );
    $page .= Forms->list_box( 'Import/update automation schema:', 'schema', \@schemas, $discovery->get_schema_name() );
    my @auto = ( 'Interactive', 'Auto', 'Auto-Commit' );
    $page .= Forms->list_box( 'Default control type:', 'auto',     \@auto,      $type );
    $page .= Forms->list_box( 'Create from template:', 'template', \@templates, $type );
    $page .= Forms->hidden( \%hidden );
    my %create = ( 'name' => 'create_group', 'value' => 'Create' );
    $page .= Forms->form_bottom_buttons( \%create, \%cancel );
    return $page;
}

sub discovery_manage_group {
    my $page             = shift;
    my $saved            = shift;
    my $errstr           = shift;
    my $discover_groups  = shift;
    my $discover_methods = shift;
    my $filters          = shift;

    $page = Forms->form_top( 'Auto Discovery Definition', '', '2' );
    if ($errstr)           { $page .= Forms->form_doc("<h7>$errstr</h7>") }
    if ( defined($saved) ) { $page .= Forms->form_doc("<h1>$saved</h1>") }
    my @schemas = StorProc->fetch_list( 'import_schema', 'name' );
    my ( $form, $tab ) = AutoConfig->manage_group( $discover_name, \%{ $discover_groups->{$discover_name} }, \@schemas, $discover_methods );
    $page .= $form;
    $page .= AutoConfig->manage_filters( \%{ $discover_groups->{$discover_name} }, $filters, $tab );
    $page .= Forms->hidden( \%hidden );
    $page .= Forms->form_bottom_buttons();
    return $page;
}

sub discovery_manage_method {
    my $discovery        = shift;
    my $page             = shift;
    my $saved            = shift;
    my $errstr           = shift;
    my $discover_methods = shift;
    my $filters          = shift;

    my $method = $discovery->get_method();

    my %suggestions = (
	'discover-snmp'   => '1',
	'discover-wmi'    => '1',
	'discover-script' => '1'
    );
    if ( $discover_methods->{$method}{'type'} eq 'Nmap' ) {
	my @service_names    = StorProc->fetch_list( 'service_names',    'name' );
	my @service_profiles = StorProc->fetch_list( 'profiles_service', 'name' );
	my @host_profiles    = StorProc->fetch_list( 'profiles_host',    'name' );
	if ( !opendir( DIR, '/usr/local/groundwork/core/profiles' ) ) {
	    $errstr .= "<br>&bull;&nbsp;Error: cannot open /usr/local/groundwork/core/profiles to read ($!)";
	}
	else {
	    while ( my $file = readdir(DIR) ) {
		if ( $file =~ /service|host-profile/ ) {
		    $file =~ s/\.xml//;
		    $suggestions{$file} = 1;
		}
	    }
	    closedir(DIR);
	}
	foreach my $service_name (@service_names) {
	    ## FIX THIS:  we'll have a bug here if there's ever a service name that starts with profile-
	    $suggestions{"service-$service_name"} = 1;
	}
	foreach my $service_profile (@service_profiles) {
	    $suggestions{"service-profile-$service_profile"} = 1;
	}
	foreach my $host_profile (@host_profiles) {
	    $suggestions{"host-profile-$host_profile"} = 1;
	}
    }

    if ( $discover_methods->{$method}{'type'} eq 'Nmap' ) {
	$page = AutoConfig->nmap_header( \%suggestions, $discover_methods->{$method}{'scan_type'} );
    }
    $page .= Forms->form_top( 'Auto Discovery Method', '', '2' );
    # if ($errstr)           { $page .= Forms->form_errors([$errstr]) }
    if ($errstr)           { $page .= Forms->form_doc("<h7>$errstr</h7>") }
    if ( defined($saved) ) { $page .= Forms->form_doc("<h1>$saved</h1>") }
    my ( $form, $tab ) = AutoConfig->manage_method( $discover_name, $method, \%{ $discover_methods->{$method} } );
    $page .= $form;
    unless ( $discover_methods->{$method}{'type'} eq 'WMI' ) {
	$page .= AutoConfig->manage_filters( \%{ $discover_methods->{$method} }, $filters, $tab );
    }
    $page .= Forms->hidden( \%hidden );
    $page .= Forms->form_bottom_buttons();
    return $page;
}

sub discovery_show_disclaimer {
    my $page                = shift;
    my $query               = shift;
    my $processed_file_path = shift;
    my $import_file_path    = shift;
    my $discover_name       = shift;
    my $errstr              = shift;
    my $discover_groups     = shift;
    my $hidden              = shift;

    $hidden->{'discover_name'}   = $discover_name;
    $hidden->{'automation_name'} = $discover_groups->{$discover_name}{'schema'};
    if ( -e $import_file_path ) {
	my @message = ();
	push @message, 'A discovery-import process appears to be in progress. ';
	my $initiate = 'continue';
	if ( ! -e $processed_file_path ) {
	    my $now        = time;
	    my @stats      = stat($import_file_path);
	    my $one_minute = 60;
	    if ( ( $now - $stats[9] ) < ( $one_minute * 5 ) ) {
		push @message, 'The discovery data file was updated within the last five minutes. ';
	    }
	    else {
		my $age = ( ( $now - $stats[9] ) / $one_minute );
		$age =~ s/\.\d+//;
		push @message, "The discovery data file was last updated $age minutes ago. ";
	    }
	    push @message, 'Check to see if another user has initiated the process before continuing. ';
	    $initiate = 'begin';
	}
	push @message, 'To cancel the existing discovery and begin a new one, select <b>Start A New Discovery</b>. ';
	push @message, "To $initiate importing records from the existing discovery, select <b>Process Existing Records</b>. ";
	my $message = join ('', @message);
	$page = Forms->form_top( 'Auto Discovery', '', '2' );
	$page .= Forms->form_doc("<h7>$errstr</h7>") if $errstr;
	$page .= Forms->wizard_doc( 'Delete discovery?', $message, undef, 1 );
	my %clear_discovery = ( 'name' => 'clear_discovery', 'value' => 'Start A New Discovery' );
	my %process_records = (
	    'name'  => 'process_records',
	    'value' => 'Process Existing Records'
	);
	$hidden->{"auto_$discover_name"} = $query->param("auto_$discover_name");
	unless ( $hidden->{"auto_$discover_name"} ) {
	    $hidden->{"auto_$discover_name"} = $query->param('auto');
	}
	my @filters = $query->$multi_param('filter');
	foreach my $filter (@filters) {
	    my $f_type       = $query->param("type_$filter");
	    my $f_filter     = $query->param("filter_$filter");
	    my %filter_props = (
		'filter'         => $filter,
		"type_$filter"   => $f_type,
		"filter_$filter" => $f_filter
	    );
	    $page .= Forms->hidden( \%filter_props );
	}
	my @methods = $query->$multi_param('method');
	foreach my $method (@methods) {
	    my %method = ( 'method' => $method );
	    $page .= Forms->hidden( \%method );
	}

	$page .= Forms->hidden( \%$hidden );
	$page .= Forms->form_bottom_buttons( \%clear_discovery, \%process_records, \%cancel );
    }
    else {
	if ($errstr) {
	    $page = Forms->form_top( 'Auto Discovery', '', '2' );
	    $page .= Forms->form_doc("<h7>$errstr</h7>");
	    my %continue = ( 'name' => 'cancel_discovery', 'value' => 'Continue' );
	    $page .= Forms->hidden( \%$hidden );
	    $page .= Forms->form_bottom_buttons( \%continue );
	}
	else {
	    $page = Forms->form_top( 'Auto Discovery', '', '2' );
	    $page .= AutoConfig->discover_disclaimer();
	    my %go = ( 'name' => 'go_discover', 'value' => 'Go >>', 'disabled' => 1 );
	    $hidden->{'discover_name'}       = $discover_name;
	    $hidden->{"auto_$discover_name"} = $query->param("auto_$discover_name");
	    unless ( $hidden->{"auto_$discover_name"} ) {
		$hidden->{"auto_$discover_name"} = $query->param('auto');
	    }
	    my @filters = $query->$multi_param('filter');
	    foreach my $filter (@filters) {
		my $f_type       = $query->param("type_$filter");
		my $f_filter     = $query->param("filter_$filter");
		my %filter_props = (
		    'filter'         => $filter,
		    "type_$filter"   => $f_type,
		    "filter_$filter" => $f_filter
		);
		$page .= Forms->hidden( \%filter_props );
	    }
	    my @methods = $query->$multi_param('method');
	    foreach my $method (@methods) {
		my %method = ( 'method' => $method );
		$page .= Forms->hidden( \%method );
	    }
	    $page .= Forms->hidden( \%$hidden );
	    $page .= Forms->form_bottom_buttons( \%cancel, \%go );
	}
    }
    return $page;
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

# ================================================================

#
# Check user
#

my $deny_access     = 0;
my $show_login      = 0;
my $session_timeout = 0;

if ( defined( $hidden{'view'} ) && $hidden{'view'} eq 'logout' ) {
    $show_login = 1;
    ( $userid, $session_id ) = undef;
}
elsif ( $config_settings{'is_portal'} || $auth == 1 ) {
    ## Auth level 1 = full access no login.
    $hidden{'user_acct'} = $ENV{'REMOTE_USER'};
    if ( $hidden{'user_acct'} ) {
	if ($session_id) {
	    my $session_user_acct;
	    ( $userid, $session_user_acct, $session_id ) = StorProc->get_session($session_id);
	    if ( !defined($userid) or !defined($session_user_acct) or $session_user_acct ne $hidden{'user_acct'} ) {
		$session_id = undef;
	    }
	}
	if (not $session_id) {
	    ( $userid, $session_id ) = StorProc->set_gwm_session( $hidden{'user_acct'} );
	}
    }
    else {
	$deny_access = 1;
    }
}
elsif ( $auth == 2 ) {
    ## Auth level 2 = active login.
    if ($session_id) {
	( $userid, $hidden{'user_acct'}, $session_id ) = StorProc->get_session($session_id);
	if ( $hidden{'user_acct'} ) {
	    my ( $auth_add, $auth_modify, $auth_delete ) = StorProc->auth_matrix($userid);
	    %auth_add = %{$auth_add};
	    unless ( $auth_add{'import'} ) { $deny_access = 1 }
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
	( $userid, $hidden{'user_acct'}, $session_id ) = StorProc->get_session( $session_id, $auth );

	# does stored user = new user? -- if there is one stored
	unless ( $new_user_acct eq $hidden{'user_acct'} ) {
	    ## no? then see if new user is valid and give them a sessionid if so
	    my %user = StorProc->fetch_one( 'users', 'user_acct', $new_user_acct );
	    $session_id = StorProc->set_session( $user{'user_id'}, $new_user_acct );
	    $hidden{'user_acct'} = $new_user_acct;
	}
    }
    else {
	( $userid, $hidden{'user_acct'}, $session_id ) = StorProc->get_session( $session_id, $auth );
    }
    if ($session_id) {
	my ( $auth_add, $auth_modify, $auth_delete ) = StorProc->auth_matrix($userid);
	%auth_add = %{$auth_add};
	unless ( $auth_add{'import'} ) { $deny_access = 1 }
    }
    else {
	$show_login = 1;
	( $userid, $session_id ) = undef;
    }
}

my $method_type = $query->param('method_type');

if (   $query->param('go_discover')
    && ( defined( $query->param('accept') ) )
    && ( $query->param('accept') eq 'accept' ) )
{
    print 'Content-Type: text/html; charset=ISO-8859-1';
}
elsif ( defined( $hidden{'obj_view'} ) && $hidden{'obj_view'} eq 'manage_method' && defined($method_type) && $method_type eq 'Nmap' ) {
    my $cookie = $query->cookie( CGISESSID => $session_id );
    print $query->header( -cookie => $cookie );
    if (   $query->param('close_method')
	|| $query->param('save_method')
	|| $query->param('delete_method')
	|| $query->param('rename') )
    {
	print Forms->header( $page_title, $session_id, $hidden{'view'} );
    }
}
else {
    my $cookie = $query->cookie( CGISESSID => $session_id );
    print $query->header( -cookie => $cookie );
    print Forms->header( $page_title, $session_id, $hidden{'view'} );
}

my $errors = StorProc->check_version( $monarch_ver );
if ($deny_access) {
    $body = Forms->form_top( 'Configuration', '' );
    $body .= Forms->wizard_doc( 'Access Denied', 'You must be an authenticated user to use this feature.' );
    $body .= Forms->form_bottom_buttons();
}
elsif (@$errors) {
    $body .= schema_mismatch($errors);
}
elsif ( defined( $hidden{'view'} ) && $hidden{'view'} eq 'show_data' ) {
    $body = show_data();
}
elsif ( $query->param('commit') ) {
    $body .= commit();
}
elsif ( $query->param('close') && $discover_name ) {
    $hidden{'view'} = 'discover';
    $body .= discover_home();
}
elsif ( $query->param('manual_process') ) {
    $hidden{'view'}     = 'automation';
    $hidden{'obj_view'} = 'import';
    $body .= automation_home();
}
elsif ( defined( $hidden{'view'} ) && $hidden{'view'} eq 'discover' ) {
    $body .= discover_home();
}
elsif ( defined( $hidden{'view'} ) && $hidden{'view'} eq 'nms_home' ) {
    $body .= nms_home();
}
elsif ( defined( $hidden{'view'} ) && $hidden{'view'} eq 'automation' ) {
    $body .= automation_home();
}

print $body;

if ($debug) {
    $debug .= '<pre>';
    foreach my $name ( sort $query->param ) {
	my @values = $query->$multi_param($name);
	$debug .= "$name = '" . join( "', '", @values ) . "'" . '<br>';

	# ought to be:
	# $debug .= HTML::Entities::encode("$name = '" . join("', '", @values) . "'") . '<br>';
    }
    $debug .= '</pre>';
}

print Forms->footer($debug);

my $result = StorProc->dbdisconnect();
