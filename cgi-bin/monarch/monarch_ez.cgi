#!/usr/bin/perl --
# MonArch - Groundwork Monitor Architect
# monarch_ez.cgi
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

use lib qq(/usr/local/groundwork/monarch/lib);
use strict;
use CGI;
use MonarchForms;
use MonarchStorProc;
use MonarchDoc;
use URI::Escape;
$|++;

#
############################################################################
# Global Declarations
#

my $debug = undef;
my $query = new CGI;

# Adapt to an upgraded CGI package while still maintaining backward compatibility.
my $multi_param = $query->can('multi_param') ? 'multi_param' : 'param';

my $top_menu   = $query->param('top_menu');
my $view       = $query->param('view');
my $user_acct  = $query->param('user_acct');
my $session_id = $query->param('CGISESSID');
unless ($session_id) { $session_id = $query->cookie("CGISESSID") }
$session_id =~ s/[[:^xdigit:]]+//g if defined $session_id;
my $cgi_exe = 'monarch_ez.cgi';
my ( %auth_add, %auth_modify, %auth_delete, %properties, %authentication, %hidden, %defaults, %profile ) = ();
my ( $nagios_ver, $nagios_bin, $nagios_etc, $monarch_home, $backup_dir, $is_portal, $upload_dir ) = undef;
my $page_title  = 'Monarch EZ';
my $monarch_ver = '1.0 Beta';
my $userid      = undef;
my $refresh_url = undef;
my $body        = undef;
my @errors      = ();
my $tab         = 1;

$hidden{'top_menu'}  = $top_menu;
$hidden{'view'}      = $view;
$hidden{'user_acct'} = $user_acct;
$hidden{'nocache'}   = time;

# Some buttons
my %add      = ( 'name' => 'add',      'value' => 'Add' );
my %save     = ( 'name' => 'save',     'value' => 'Save' );
my %delete   = ( 'name' => 'delete',   'value' => 'Delete' );
my %select   = ( 'name' => 'select',   'value' => 'Select' );
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
my %discard  = ( 'name' => 'discard',  'value' => 'Discard' );

my %textsize = ();
$textsize{'short'}   = 50;
$textsize{'long'}    = 75;
$textsize{'address'} = 17;

sub error_out($) {
    my $err = shift;
    $body .= "<h2>$err</h2><br>";
}

sub notifications() {
    my $notify = $query->param('notification');
    if ($notify) {
	my %val = ( 'value' => 1 );
	if ( $notify eq 'off' ) { $val{'value'} = 0 }
	my $result = StorProc->update_obj( 'setup', 'name', 'enable_notifications', \%val );
	if ( $result =~ /^Error/ ) { push @errors, $result }
    }
    else {
	$notify = 'off';
	my %notify = StorProc->fetch_one( 'setup', 'name', 'enable_notifications' );
	if ( $notify{'value'} ) { $notify = 'on' }
    }
    my $page = Forms->header( $page_title, $session_id, $view, '', '', '1' );
    $page .= Forms->form_top( "Enable Notifications", '', '1' );
    if (@errors) { $page .= Forms->form_errors( \@errors ) }
    my @ops = ( 'on', 'off' );
    $page .= Forms->list_box_submit( 'Notifications:', 'notification', \@ops, $notify );
    $hidden{'update_main'} = 1;
    $page .= Forms->hidden( \%hidden );
    $page .= Forms->form_bottom_buttons( \%close );
    return $page;
}

sub apply_profile($) {
    my $hosts_ref      = $_[0];
    my @hosts          = @{$hosts_ref};
    my $apply_services = $query->param('apply_services');
    my %where          = ( 'hostprofile_id' => $profile{'hostprofile_id'} );
    my @profiles       = StorProc->fetch_list_where( 'profile_host_profile_service', 'serviceprofile_id', \%where );
    foreach my $hid (@hosts) {
	my $result = StorProc->delete_all( 'host_parent', 'host_id', $hid );
	if ( $result =~ /^Error/ ) { push @errors, $result }
	my %w = ( 'hostprofile_id' => $profile{'hostprofile_id'} );
	my @parents = StorProc->fetch_list_where( 'profile_parent', 'host_id', \%w );
	foreach my $pid (@parents) {
	    my @vals = ( $hid, $pid );
	    my $result = StorProc->insert_obj( 'host_parent', \@vals );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	}
	unless ( $query->param('hostgroups') ) {
	    if ( $profile{'apply_hostgroups'} ) {
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
	}
	%w = ( 'host_id' => $hid );
	$result = StorProc->delete_one_where( 'contactgroup_host', \%w );
	if ( $result =~ /^Error/ ) { push @errors, $result }
	%w = ( 'hostprofile_id' => $profile{'hostprofile_id'} );
	my @contactgroups = StorProc->fetch_list_where( 'contactgroup_host_profile', 'contactgroup_id', \%w );
	foreach my $cgid (@contactgroups) {
	    my @vals = ( $cgid, $hid );
	    my $result = StorProc->insert_obj( 'contactgroup_host', \@vals );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	}
	$result = StorProc->delete_all( 'serviceprofile_host', 'host_id', $hid );
	if ( $result =~ /^Error/ ) { push @errors, $result }
	foreach my $spid (@profiles) {
	    my %w = ( 'host_id' => $hid, 'serviceprofile_id' => $spid );
	    my %p = StorProc->fetch_one_where( 'serviceprofile_host', \%w );
	    unless ( $p{'host_id'} ) {
		my @vals = ( $spid, $hid );
		my $result = StorProc->insert_obj( 'serviceprofile_host', \@vals );
		if ( $result =~ /^Error/ ) { push @errors, $result }
	    }
	}
    }
    if ( $profile{'apply_escalations'} ) {
	my %vals = ( 'host_escalation_id' => $profile{'host_escalation_id'} );
	my $result = StorProc->update_obj( 'hosts', 'hostprofile_id', $profile{'hostprofile_id'}, \%vals );
	if ( $result =~ /^Error/ ) { push @errors, $result }
	%vals = ( 'service_escalation_id' => $profile{'service_escalation_id'} );
	$result = StorProc->update_obj( 'hosts', 'hostprofile_id', $profile{'hostprofile_id'}, \%vals );
	if ( $result =~ /^Error/ ) { push @errors, $result }
    }
    my %vals = ( 'hosttemplate_id' => $profile{'host_template_id'} );
    my $result = StorProc->update_obj( 'hosts', 'hostprofile_id', $profile{'hostprofile_id'}, \%vals );
    if ( $result =~ /^Error/ ) { push @errors, $result }
    my @errs = StorProc->host_profile_apply( $profile{'hostprofile_id'}, \@hosts );
    if (@errs) { push( @errors, @errs ) }
    %vals = ( 'hostextinfo_id' => $profile{'host_extinfo_id'} );
    $result = StorProc->update_obj( 'hosts', 'hostprofile_id', $profile{'hostprofile_id'}, \%vals );
    if ( $result =~ /^Error/ ) { push @errors, $result }

    my ( $cnt, $err ) = StorProc->service_profile_apply( \@profiles, 'replace', \@hosts );
    if ($err) { push( @errors, @{$err} ) }
    my %w = ( 'hostprofile_id' => $profile{'hostprofile_id'} );
    @hosts = StorProc->fetch_list_where( 'hosts', 'host_id', \%w );
    my @externals = StorProc->fetch_list_where( 'external_host_profile', 'external_id', \%w );
    foreach my $hid (@hosts) {
	my $result = StorProc->delete_all( 'external_host', 'host_id', $hid );
	if ( $result =~ /^Error/ ) { push @errors, $result }
	foreach my $ext (@externals) {
	    my %e = StorProc->fetch_one( 'externals', 'external_id', $ext );
	    my @vals = ( $ext, $hid, $e{'display'}, \'0+0' );
	    $result = StorProc->insert_obj( 'external_host', \@vals );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	}
    }
}

#
##################################################
# Search
#

sub search() {
    my $detail = Forms->header( $page_title, $session_id, $view );
    $detail .= Forms->form_top( 'Search Hosts', '', '1', '100%' );
    $detail .= Forms->search( $session_id, 'ez' );
    $hidden{'update_main'} = '1';
    $hidden{'view'}        = 'search';
    $detail .= Forms->hidden( \%hidden );
    $detail .= Forms->form_bottom_buttons();
    use CGI::Ajax;
    my $url = Forms->get_ajax_url();
    my $pjx = new CGI::Ajax( 'get_ez' => $url );
    $pjx->js_encode_function('escape');
    return $pjx->build_html( $query, $detail );
}

#
##################################################
# Hosts
#

sub hosts() {
    my $page = undef;
    my $name = $query->param('name');
    $name =~ s/^\s+|\s+$//g;
    my $alias      = $query->param('alias');
    my $address    = $query->param('address');
    my @hostgroups = $query->$multi_param('hostgroups');
    my $profile    = $query->param('host_profile');
    my $required   = undef;
    my $got_form   = 0;
    $hidden{'view'}        = $view;
    $hidden{'update_main'} = 1;
    unless ($profile) { $profile = $defaults{'profile'} }
    my %host = StorProc->fetch_one( 'hosts', 'name', $name );
    %profile = StorProc->fetch_one( 'profiles_host', 'name', $profile );

    if ( $query->param('add') ) {
	if ( $name && $alias && $address ) {
	    if ( $host{'name'} ) {
		push @errors, "Host $name already exixts";
	    }
	    else {
		my @values = ( \undef, $name, $alias, $address, '', $profile{'host_template_id'}, '', $profile{'hostprofile_id'}, '', '', '', '', '' );
		my $id = StorProc->insert_obj_id( 'hosts', \@values, 'host_id' );
		if ( $id =~ /error/i ) {
		    push @errors, $id;
		}
		else {
		    my %hostgroup_name = StorProc->get_table_objects('hostgroups');
		    foreach my $hostgroup (@hostgroups) {
			my @vals = ( $hostgroup_name{$hostgroup}, $id );
			my $result = StorProc->insert_obj( 'hostgroup_host', \@vals );
			if ( $result =~ /error/i ) { push @errors, $result }
		    }
		}
		my @hosts = ($id);
		apply_profile( \@hosts );
		unless (@errors) {
		    $page .= Forms->header( $page_title, $session_id, $view, '', '', '1' );
		    $page .= Forms->form_top( 'Host', '', '1' );
		    my @message = ("$name.");
		    $page .= Forms->form_message( 'Added:', \@message, 'row1' );
		    $page .= Forms->hidden( \%hidden );
		    $page .= Forms->form_bottom_buttons( \%continue, $tab++ );
		    $got_form = 1;
		}
	    }
	}
	else {
	    $required = 1;
	    push @errors, "Missing required fields.";
	}
    }
    elsif ( $query->param('save') ) {
	if ( $alias && $address ) {
	    my %values = (
		'alias'          => $alias,
		'address'        => $address,
		'hostprofile_id' => $profile{'hostprofile_id'}
	    );
	    my $result = StorProc->update_obj( 'hosts', 'name', $name, \%values );
	    if ( $result =~ /error/i ) {
		push @errors, $result;
	    }
	    else {
		my $result = StorProc->delete_all( 'hostgroup_host', 'hostgroup_id', $host{'hostgroup_id'} );
		if ( $result =~ /error/i ) {
		    push @errors, $result;
		}
		else {
		    my $result = StorProc->delete_all( 'hostgroup_host', 'host_id', $host{'host_id'} );
		    foreach my $hostgroup (@hostgroups) {
			my %h = StorProc->fetch_one( 'hostgroups', 'name', $hostgroup );
			my @vals = ( $h{'hostgroup_id'}, $host{'host_id'} );
			my $result = StorProc->insert_obj( 'hostgroup_host', \@vals );
			if ( $result =~ /error/i ) { push @errors, $result }
		    }
		    my @hosts = ( $host{'host_id'} );
		    apply_profile( \@hosts );
		    unless (@errors) {
			$page .= Forms->header( $page_title, $session_id, $view, '', '', '1' );
			$page .= Forms->form_top('Host');
			my @message = ("$name.");
			$page .= Forms->form_message( 'Saved:', \@message, 'row1' );
			$page .= Forms->hidden( \%hidden );
			$page .= Forms->form_bottom_buttons( \%continue, $tab++ );
			$got_form = 1;
		    }
		}
	    }
	}
	else {
	    $required = 1;
	    push @errors, "Missing required fields.";
	}
    }
    elsif ( $query->param('delete') ) {
	$hidden{'delete'} = 1;
	$hidden{'name'}   = $name;
	if ( $query->param('yes') ) {
	    my $result = StorProc->delete_all( 'hosts', 'name', $name );
	    if ( $result =~ /error/i ) {
		push @errors, $result;
		delete $hidden{'delete'};
	    }
	    else {
		$page .= Forms->header( $page_title, $session_id, $view, '', '1', '1' );
		$page .= Forms->form_top( 'Host', '', '1' );
		my @message = ("$name.");
		$page .= Forms->form_message( 'Removed:', \@message, 'row1' );
		$page .= Forms->hidden( \%hidden );
		$page .= Forms->form_bottom_buttons( \%continue, $tab++ );
		$got_form = 1;
	    }
	}
	elsif ( $query->param('no') ) {
	    delete $hidden{'delete'};
	}
	else {
	    $page .= Forms->header( $page_title, $session_id, $view, '', '', '1' );
	    $page .= Forms->form_top('Host');
	    my $message = "Are you sure you want to remove host \"$name\"?";
	    $page .= Forms->form_doc($message);
	    $page .= Forms->hidden( \%hidden );
	    $page .= Forms->form_bottom_buttons( \%yes, \%no, $tab++ );
	    $got_form = 1;
	}
    }
    unless ($got_form) {
	my @props  = ( 'alias', 'members' );
	my %docs   = Doc->ez_host();
	my %notify = StorProc->fetch_one( 'setup', 'name', 'enable_notifications' );
	$page .= Forms->header( $page_title, $session_id, $view );
	$page .= Forms->form_top( "Host", 'onsubmit="selIt();"', '1' );
	if (@errors) { $page .= Forms->form_errors( \@errors ) }
	if ( $query->param('new') ) {
	    $page .= Forms->text_box( 'Host name:', 'name', $name, $textsize{'alias'}, $required, $docs{'name'}, '', '' );
	    $hidden{'new'} = 1;
	}
	else {
	    $page .= Forms->display_hidden( 'Host name:', 'name', $host{'name'} );
	}
	unless ($alias) { $alias = $host{'alias'} }
	$page .= Forms->text_box( 'Alias (long name):', 'alias', $alias, $textsize{'long'}, $required, $docs{'alias'}, '', '' );
	unless ($address) { $address = $host{'address'} }
	$page .= Forms->text_box( 'Address:', 'address', $address, $textsize{'address'}, $required, $docs{'address'}, '', '' );
	$page .= Forms->wizard_doc( 'Host Groups', $docs{'hostgroups'} );

	unless (@hostgroups) {
	    @hostgroups = StorProc->get_host_hostgroups($name);
	}
	my @nonmembers = StorProc->fetch_list( 'hostgroups', 'name' );
	$page .= Forms->members( 'Host groups:', 'hostgroups', \@hostgroups, \@nonmembers, '', '', $docs{'hostgroups'} );
	my %profiles = StorProc->get_table_objects('profiles_host');
	my @profiles = ();
	foreach my $p ( sort { uc($a) cmp uc($b) } keys %profiles ) {
	    push @profiles, $p;
	}
	unless ($profile) {
	    my %p = StorProc->fetch_one( 'profiles_host', 'hostprofile_id', $host{'hostprofile_id'} );
	    $profile = $p{'name'};
	}
	my %profiles_detail = StorProc->get_profiles();
	$page .= Forms->form_profiles( $defaults{'host_profile'}, $profile, \@profiles, \%profiles_detail, $docs{'profile'} );
	$page .= Forms->hidden( \%hidden );
	if ( $query->param('new') ) {
	    $page .= Forms->form_bottom_buttons( \%add, \%cancel );
	}
	else {
	    $page .= Forms->form_bottom_buttons( \%save, \%delete, \%cancel );
	}
    }
    return $page;
}

#
##################################################
# Import
#

sub import() {
    my $page = undef;
    my $step = $query->param('step');
    my $file = $query->param('file');
    $hidden{'view'}        = $view;
    $hidden{'update_main'} = 1;

    if ( $query->param('back') ) {
	if ( $step eq 'schema' ) {
	    $step = 'upload';
	    unlink $file;
	}
	elsif ( $step eq 'process' ) {
	    $step = 'schema';
	}
    }
    elsif ( $query->param('next') ) {
	if ( $step eq 'upload' ) {
	    my ($filedata, $errs) = StorProc->upload( $upload_dir, $file, "$upload_dir/$file" );
	    my @errs = @$errs;
	    if (@errs) {
		push @errors, @errs;
	    }
	    else {
		$file = "$upload_dir/$file";
		$step = 'schema';
	    }
	}
	elsif ( $step eq 'schema' ) {
	    $step = 'process';
	}
    }
    $hidden{'file'} = $file;
    $hidden{'step'} = $step;
    my %doc = Doc->import_wizard();
    if ( $step eq 'schema' ) {
	$page .= Forms->header( $page_title, $session_id, $view );
	my $field_sep       = $query->param('field_sep');
	my $delimiter       = $query->param('delimiter');
	my $other_delimiter = $query->param('other_delimiter');
	if ($other_delimiter) { $delimiter = $other_delimiter }
	$page .= Forms->form_top( 'Import Host Wizard', '', '1' );
	my %file_data = StorProc->parse_file( $file, $delimiter );
	if ( $file_data{'error'} ) { push @errors, $file_data{'error'} }
	if (@errors) { $page .= Forms->form_errors( \@errors ) }
	my @values = split( /$delimiter/, $file_data{'line_1'} );

	if ( $delimiter eq 'tab' ) {
	    @values = split( /\t/, $file_data{'line_1'} );
	}
	my @delimiters = ( ',', 'tab', ':', ';' );
	$page .= Forms->wizard_doc( $doc{'step_2_title'}, $doc{'step_2'} );
	$page .= Forms->list_box( 'File delimiter:', 'delimiter', \@delimiters, $delimiter );
	$page .= Forms->text_box( 'Other file delimiter:', 'other_delimiter', $other_delimiter, '2' );
	$page .= Forms->display_hidden( 'Line 1:', '', $file_data{'line_1'} );
	my $i = 0;
	my @columns = ( 'name', 'address', 'alias', 'os', 'profile', 'other' );

	foreach my $val (@values) {
	    $page .= Forms->list_box( "$val:", "field_$i", \@columns, "$columns[$i]" );
	    $i++;
	}
	$page .= Forms->hidden( \%hidden );
	$page .= Forms->form_bottom_buttons( \%back, \%next, \%refresh, \%cancel );
    }
    elsif ( $step eq 'process' ) {
	my $delimiter = $query->param('delimiter');
	my $profile   = $query->param('host_profile');
	$hidden{'process_set'} = 1;
	my ( $sort, $ascdesc ) = undef;
	foreach my $s ( $query->param ) {
	    if ( $s =~ /^sort_(\S+)_(\S+)/ ) {
		$sort    = $1;
		$ascdesc = $2;
	    }
	}
	if ( $sort eq 'name' ) { $sort = 0 }
	my $other_delimiter = $query->param('other_delimiter');
	if ($other_delimiter) { $delimiter = $other_delimiter }
	$hidden{'delimiter'} = $delimiter;
	my @unsorted_hosts = process_hosts();
	my %fields         = ();
	foreach my $field ( $query->param ) {
	    if ( $field =~ /field_(\d+)/ ) {
		my $value = $query->param($field);
		$fields{$value} = $1;
		$hidden{$field} = $value;
	    }
	}
	my $field_sep = $query->param('field_sep');
	my %file_data = StorProc->parse_file( $file, $delimiter, $fields{'name'} );
	delete $file_data{'line_1'};

	unless ( @unsorted_hosts || $query->param('process_set') ) {
	    foreach my $host ( keys %file_data ) {
		my @values = split( /$delimiter/, $file_data{$host} );
		if ( $delimiter eq 'tab' ) {
		    @values = split( /\t/, $file_data{$host} );
		}
		push @unsorted_hosts, $values[ $fields{'name'} ];
	    }
	}
	if ( $file_data{'error'} ) { push @errors, $file_data{'error'} }
	my %exists   = StorProc->get_table_objects('hosts');
	my %profiles = StorProc->get_table_objects('profiles_host');
	$page .= Forms->header( $page_title, $session_id, $view, '', '', '1' );
	$page .= Forms->form_top( 'Import Host Wizard', '', '1' );
	if (@errors) { $page .= Forms->form_errors( \@errors ) }
	$page .= Forms->wizard_doc( $doc{'step_3_title'}, $doc{'step_3'} );
	$page .=
	  Forms->form_process_hosts( \@unsorted_hosts, \%file_data, $delimiter, \%fields, \%exists, \%profiles, $defaults{'host_profile'},
	    $sort, $ascdesc );
	my @profiles = ();

	foreach my $p ( sort { uc($a) cmp uc($b) } keys %profiles ) {
	    push @profiles, $p;
	}
	unless ($profile) { $profile = $defaults{'host_profile'} }
	my %profiles_detail = StorProc->get_profiles();
	$page .= Forms->form_profiles( $defaults{'host_profile'}, $profile, \@profiles, \%profiles_detail, $doc{'profile'} );
	$page .= Forms->hidden( \%hidden );
	$page .= Forms->form_bottom_buttons( \%back, \%add, \%discard, \%close );
    }
    else {
	$page .= Forms->header( $page_title, $session_id, $view );
	$page .= Forms->form_top_file( 'Import Host Wizard', '', '1' );
	if (@errors) { $page .= Forms->form_errors( \@errors ) }
	my @delimiters = ( ',', 'tab', ':', ';' );
	$page .= Forms->wizard_doc( $doc{'step_1_title'}, $doc{'step_1'} );
	$page .= Forms->list_box( 'File delimiter:', 'delimiter', \@delimiters, ',' );
	$page .= Forms->text_box( 'Other file delimiter:', 'other_delimiter', '', '2' );
	$page .= Forms->form_file();
	$hidden{'step'} = 'upload';
	$page .= Forms->hidden( \%hidden );
	$page .= Forms->form_bottom_buttons( \%next, \%cancel );
    }
    return $page;
}

#
##################################################
# Process hosts
#

sub process_hosts() {
    my %hosts             = ();
    my @unsorted_hosts    = ();
    my @unprocessed_hosts = $query->$multi_param('host');
    my @checked_hosts     = $query->$multi_param('host_checked');
    foreach my $host (@checked_hosts) {
	$hosts{$host} = 1;
    }
    if ( $query->param('add') ) {
	my %exists = StorProc->get_table_objects('hosts');
	my @hosts  = ();
	foreach my $host (@checked_hosts) {
	    my $got_host = 0;
	    $host =~ s/^\s+|\s+$//g;
	    foreach my $hname ( keys %exists ) {
		if ( $hname =~ /^$host$/i ) {
		    push @hosts, $exists{$hname};
		    $got_host = 1;
		}
	    }
	    unless ($got_host) {
		my $profile = $query->param("profile_$host");
		if ( $profile =~ /---/ ) {
		    $profile = $query->param('host_profile');
		}
		%profile = StorProc->fetch_one( 'profiles_host', 'name', $profile );
		my $alias   = $query->param("alias_$host");
		my $address = $query->param("address_$host");
		my $os      = $query->param("os_$host");
		my @values = ( \undef, $host, $alias, $address, $os, $profile{'host_template_id'}, '', $profile{'hostprofile_id'}, '', '', '', '', '' );
		my $id = StorProc->insert_obj_id( 'hosts', \@values, 'host_id' );
		if ( $id =~ /error/ ) { push @errors, $id }
		push @hosts, $id;
	    }
	}
	apply_profile( \@hosts );
    }
    foreach my $host (@unprocessed_hosts) {
	if ( $query->param('discard') || $query->param('add') ) {
	    unless ( $hosts{$host} ) { push @unsorted_hosts, $host }
	}
	else {
	    push @unsorted_hosts, $host;
	}
    }
    return @unsorted_hosts;
}

#
##################################################
# Discover
#

sub discover() {
    my $page = undef;
    my $step = $query->param('step');
    my $file = $query->param('file');
    $hidden{'view'}        = $view;
    $hidden{'update_main'} = 1;
    my $oct1 = $query->param('oct1');
    my $oct2 = $query->param('oct2');
    my $oct3 = $query->param('oct3');
    my $oct4 = $query->param('oct4');
    my $oct5 = $query->param('oct5');
    $hidden{'oct1'} = $oct1;
    $hidden{'oct2'} = $oct2;
    $hidden{'oct3'} = $oct3;
    $hidden{'oct4'} = $oct4;
    $hidden{'oct5'} = $oct5;
    my @addresses = ();
    my $elements  = 0;

    if ( $query->param('back') ) {
	if ( $step eq 'get_hosts' ) {
	    $step = '';
	    unlink $file;
	}
	elsif ( $step eq 'process' ) {
	    $step = '';
	}
    }
    elsif ( $query->param('next') ) {
	if ( $step eq 'subnet' ) {
	    if (   $oct1 =~ /\d+/
		&& $oct2 =~ /\d+/
		&& $oct3 =~ /\d+/
		&& $oct4 =~ /\d+|\*/ )
	    {
		my $valid_oct = 1;
		unless ( $oct1 <= 255 ) { $valid_oct = 0 }
		unless ( $oct2 <= 255 ) { $valid_oct = 0 }
		unless ( $oct3 <= 255 ) { $valid_oct = 0 }
		if     ( $oct5 > 0 ) {
		    unless ( $oct4 <= 255 ) { $valid_oct = 0 }
		    unless ( $oct5 <= 255 ) { $valid_oct = 0 }
		    if     ($valid_oct) {
			if ( $oct4 < $oct5 ) {
			    for ( my $i = $oct4 ; $i <= $oct5 ; $i++ ) {
				push @addresses, "$oct1.$oct2.$oct3.$i";
				$elements++;
				$step = 'get_hosts';
			    }
			}
			else {
			    push @errors, "Invalid address range.";
			}
		    }
		    else {
			push @errors, "Invalid address $oct1.$oct2.$oct3.- valid octet ranges 0-255";
		    }
		}
		else {
		    if ($valid_oct) {
			if ( $oct4 eq '*' ) {
			    for ( my $i = 1 ; $i < 255 ; $i++ ) {
				push @addresses, "$oct1.$oct2.$oct3.$i";
				$elements++;
				$step = 'get_hosts';
			    }
			}
			elsif ($oct4) {
			    if ( $oct4 > 0 && $oct4 < 255 ) {
				push @addresses, "$oct1.$oct2.$oct3.$oct4";
				$elements++;
				$step = 'get_hosts';
			    }
			    else {
				push @errors,
				  "Invalid address $oct1.$oct2.$oct3.$oct4 valid octet ranges 0-255. Valid range for last octet 1-254.";
			    }
			}
		    }
		    else {
			push @errors, "Invalid address $oct1.$oct2.$oct3.- valid octet ranges 0-255";
		    }
		}
		my $now = time;
		$file = "monarch_discover_$now.tmp";
		$hidden{'file'} = $file;
	    }
	    else {
		push @errors, "Missing or invalid address $oct1.$oct2.$oct3.$oct4 - valid octet ranges 0-255";
	    }
	}
	elsif ( $step eq 'get_hosts' ) {
	    $step = 'process';
	}
    }
    $hidden{'file'} = $file;
    $hidden{'step'} = $step;
    my %doc = Doc->discover_wizard();

    if ( $step eq 'get_hosts' ) {
	my $now = time;
	$file = "$upload_dir/monarch_import_$now.tmp";
	$page .= Forms->header( $page_title, $session_id, $view, '', '', '1', '1' );
	use CGI::Ajax;
	my $url = Forms->get_scan_url();
	my $pjx = new CGI::Ajax( 'get_host' => $url );
	$page .= Forms->form_top( 'Discover Host Wizard', '', '1' );
	$page .= Forms->wizard_doc( $doc{'step_2_title'}, $doc{'step_2'} );
	$page .= Forms->scan( \@addresses, $elements, $file, $monarch_home );
	$page .= Forms->hidden( \%hidden );
	$page .= Forms->form_bottom_buttons( \%back, \%next, \%cancel );
	$page = $pjx->build_html( $query, $page );
    }
    elsif ( $step eq 'process' ) {
	my $profile = $query->param('host_profile');
	$hidden{'process_set'} = 1;
	my ( $sort, $ascdesc ) = undef;
	foreach my $s ( $query->param ) {
	    if ( $s =~ /^sort_(\S+)_(\S+)/ ) {
		$sort    = $1;
		$ascdesc = $2;
	    }
	}
	if ( $sort eq 'name' ) { $sort = 0 }
	my @unsorted_hosts = process_hosts();
	my %fields         = ();
	$fields{'name'}    = '0';
	$fields{'alias'}   = '1';
	$fields{'address'} = '2';
	$fields{'os'}      = '3';
	$fields{'profile'} = '4';
	$fields{'other'}   = '5';
	my %file_data = StorProc->parse_file( $file, ',', '0' );
	delete $file_data{'line_1'};

	unless ( @unsorted_hosts || $query->param('process_set') ) {
	    foreach my $host ( keys %file_data ) {
		my @values = split( /,/, $file_data{$host} );
		push @unsorted_hosts, $values[ $fields{'name'} ];
	    }
	}
	if ( $file_data{'error'} ) { push @errors, $file_data{'error'} }
	my %exists   = StorProc->get_table_objects('hosts');
	my %profiles = StorProc->get_table_objects('profiles_host');
	my $cookie   = $query->cookie( CGISESSID => $session_id );
	print $query->header( -cookie => $cookie );
	$page .= Forms->header( $page_title, $session_id, $view, '', '', '1' );
	$page .= Forms->form_top( 'Discover Host Wizard', '', '1' );
	if (@errors) { $page .= Forms->form_errors( \@errors ) }
	$page .= Forms->wizard_doc( $doc{'step_3_title'}, $doc{'step_3'} );
	$page .= Forms->form_process_hosts( \@unsorted_hosts, \%file_data, ',', \%fields, \%exists, \%profiles, $defaults{'host_profile'},
	    $sort, $ascdesc );
	my @profiles = ();

	foreach my $p ( sort { uc($a) cmp uc($b) } keys %profiles ) {
	    push @profiles, $p;
	}
	unless ($profile) { $profile = $defaults{'host_profile'} }
	my %profiles_detail = StorProc->get_profiles();
	$page .= Forms->form_profiles( $defaults{'host_profile'}, $profile, \@profiles, \%profiles_detail, $doc{'profile'} );
	$page .= Forms->hidden( \%hidden );
	$page .= Forms->form_bottom_buttons( \%back, \%add, \%discard, \%close );
    }
    else {
	$hidden{'step'} = 'subnet';
	my $cookie = $query->cookie( CGISESSID => $session_id );
	print $query->header( -cookie => $cookie );
	$page .= Forms->header( $page_title, $session_id, $view );
	$page .= Forms->form_top( "Discover Host Wizard", '', '1' );
	if (@errors) { $page .= Forms->form_errors( \@errors ) }
	$page .= Forms->wizard_doc( $doc{'step_1_title'}, $doc{'step_1'} );
	$page .= Forms->form_discover( $hidden{'oct1'}, $hidden{'oct2'}, $hidden{'oct3'}, $hidden{'oct4'}, $hidden{'oct5'} );
	$page .= Forms->hidden( \%hidden );
	$page .= Forms->form_bottom_buttons( \%next, \%cancel );
    }
    return $page;
}

#
##################################################
# Hostgroups
#

sub hostgroups() {
    my $page = undef;
    my $name = $query->param('name');
    $name =~ s/^\s+|\s+$//g;
    my $alias    = $query->param('alias');
    my @hosts    = $query->$multi_param('hosts');
    my $required = undef;
    my $got_form = 0;
    $hidden{'view'}        = $view;
    $hidden{'update_main'} = 1;
    my %hostgroup = StorProc->fetch_one( 'hostgroups', 'name', $name );

    if ( $query->param('add') ) {
	if ( $name && $alias ) {
	    if ( $hostgroup{'name'} ) {
		push @errors, "Hostgroup $name already exixts";
	    }
	    else {
		my @values = ( \undef, $name, $alias, '', '', '', '', '', '' );
		my $id = StorProc->insert_obj_id( 'hostgroups', \@values, 'hostgroup_id' );
		if ( $id =~ /error/i ) {
		    push @errors, $id;
		}
		else {
		    foreach my $host (@hosts) {
			my %h = StorProc->fetch_one( 'hosts', 'name', $host );
			my @vals = ( $id, $h{'host_id'} );
			my $result = StorProc->insert_obj( 'hostgroup_host', \@vals );
			if ( $result =~ /error/i ) { push @errors, $result }
		    }
		}
		unless (@errors) {
		    $page .= Forms->header( $page_title, $session_id, $view, '', '', '1' );
		    $page .= Forms->form_top( 'Host group', '', '1' );
		    my @message = ("$name.");
		    $page .= Forms->form_message( 'Added:', \@message, 'row1' );
		    $page .= Forms->hidden( \%hidden );
		    $page .= Forms->form_bottom_buttons( \%continue, $tab++ );
		    $got_form = 1;
		}
	    }
	}
	else {
	    $required = 1;
	    push @errors, "Missing required fields.";
	}
    }
    elsif ( $query->param('save') ) {
	if ($alias) {
	    my %values = ( 'alias' => $alias );
	    my $result = StorProc->update_obj( 'hostgroups', 'name', $name, \%values );
	    if ( $result =~ /error/i ) {
		push @errors, $result;
	    }
	    else {
		my $result = StorProc->delete_all( 'hostgroup_host', 'hostgroup_id', $hostgroup{'hostgroup_id'} );
		if ( $result =~ /error/i ) {
		    push @errors, $result;
		}
		else {
		    foreach my $host (@hosts) {
			my %h = StorProc->fetch_one( 'hosts', 'name', $host );
			my @vals = ( $hostgroup{'hostgroup_id'}, $h{'host_id'} );
			my $result = StorProc->insert_obj( 'hostgroup_host', \@vals );
			if ( $result =~ /error/i ) { push @errors, $result }
		    }
		    unless (@errors) {
			$page .= Forms->header( $page_title, $session_id, $view, '', '', '1' );
			$page .= Forms->form_top('Host group');
			my @message = ("$name.");
			$page .= Forms->form_message( 'Saved:', \@message, 'row1' );
			$page .= Forms->hidden( \%hidden );
			$page .= Forms->form_bottom_buttons( \%continue, $tab++ );
			$got_form = 1;
		    }
		}
	    }
	}
    }
    elsif ( $query->param('delete') ) {
	$hidden{'delete'} = 1;
	$hidden{'name'}   = $name;
	if ( $query->param('yes') ) {
	    my $result = StorProc->delete_all( 'hostgroups', 'name', $name );
	    if ( $result =~ /error/i ) {
		push @errors, $result;
		delete $hidden{'delete'};
	    }
	    else {
		$page .= Forms->header( $page_title, $session_id, $view, '', '1', '1' );
		$page .= Forms->form_top( 'Host group', '', '1' );
		my @message = ("$name.");
		$page .= Forms->form_message( 'Removed:', \@message, 'row1' );
		$page .= Forms->hidden( \%hidden );
		$page .= Forms->form_bottom_buttons( \%continue, $tab++ );
		$got_form = 1;
	    }
	}
	elsif ( $query->param('no') ) {
	    delete $hidden{'delete'};
	}
	else {
	    $page .= Forms->header( $page_title, $session_id, $view, '', '', '1' );
	    $page .= Forms->form_top('Host group');
	    my $message = "Are you sure you want to remove hostgroup \"$name\"?";
	    $page .= Forms->form_doc($message);
	    $page .= Forms->hidden( \%hidden );
	    $page .= Forms->form_bottom_buttons( \%yes, \%no, $tab++ );
	    $got_form = 1;
	}
    }
    unless ($got_form) {
	my @props = ( 'alias', 'members' );
	my %docs = Doc->properties_doc( 'hostgroups', \@props );
	my %notify = StorProc->fetch_one( 'setup', 'name', 'enable_notifications' );
	$page .= Forms->header( $page_title, $session_id, $view );
	$page .= Forms->form_top( "Host group", 'onsubmit="selIt();"', '1' );
	if (@errors) { $page .= Forms->form_errors( \@errors ) }
	if ( $query->param('new') ) {
	    $page .= Forms->text_box( 'Host group name:', 'name', $name, $textsize{'alias'}, $required, $docs{'name'}, '', '' );
	    $hidden{'new'} = 1;
	}
	else {
	    $page .= Forms->display_hidden( 'Host group name:', 'name', $hostgroup{'name'} );
	}
	unless ($alias) { $alias = $hostgroup{'alias'} }
	$page .= Forms->text_box( 'Alias (long name):', 'alias', $alias, $textsize{'long'}, $required, $docs{'alias'}, '', '' );
	unless (@hosts) {
	    @hosts = StorProc->get_hostgroup_hosts($name);
	}
	my @nonmembers = StorProc->fetch_list( 'hosts', 'name' );
	$page .= Forms->members( 'Hosts:', 'hosts', \@hosts, \@nonmembers, '', '', $docs{'members'} );
	$page .= Forms->hidden( \%hidden );
	if ( $query->param('new') ) {
	    $page .= Forms->form_bottom_buttons( \%add, \%cancel );
	}
	else {
	    $page .= Forms->form_bottom_buttons( \%save, \%delete, \%cancel );
	}
    }
    return $page;
}

#
##################################################
# Profiles
#

sub profiles() {
    my $page     = undef;
    my $got_form = 0;
    my $required = undef;
    my $name     = $query->param('name');
    %profile = StorProc->fetch_one( 'profiles_host', 'name', $name );
    my @hostnames = $query->$multi_param('hosts');
    $hidden{'view'}        = $view;
    $hidden{'update_main'} = 1;
    if ( $query->param('save') ) {
	my @hosts     = ();
	my %host_name = StorProc->get_table_objects('hosts');
	my %w         = ( 'hostprofile_id' => $profile{'hostprofile_id'} );
	my %u         = ( 'hostprofile_id' => '' );
	my $result    = StorProc->update_obj_where( 'hosts', \%u, \%w );
	if ( $result =~ /^Error/ ) { push @errors, $result }
	foreach my $host (@hostnames) {
	    my %vals = ( 'hostprofile_id' => $profile{'hostprofile_id'} );
	    my $result = StorProc->update_obj( 'hosts', 'name', $host, \%vals );
	    push @hosts, $host_name{$host};
	    if ( $result =~ /error/i ) { push @errors, $result }
	}
	apply_profile( \@hosts );
	unless (@errors) {
	    $page .= Forms->header( $page_title, $session_id, $view );
	    $page .= Forms->form_top( "Hostgroup", 'onsubmit="selIt();"', '1' );
	    my @message = ("Host profile \"$name\" applied to hosts.");
	    $page .= Forms->form_message( 'Updated:', \@message, 'row1' );
	    $page .= Forms->hidden( \%hidden );
	    $page .= Forms->form_bottom_buttons( \%continue, $tab++ );
	    $got_form = 1;
	}
    }
    unless ($got_form) {
	my $doc = undef;
	$page .= Forms->header( $page_title, $session_id, $view );
	$page .= Forms->form_top( "Host Profile", 'onsubmit="selIt();"', '1' );
	if (@errors) { $page .= Forms->form_errors( \@errors ) }
	$page .= Forms->display_hidden( 'Host profile name:', 'name', $profile{'name'} );
	my @profiles        = ($name);
	my %profiles_detail = StorProc->get_profiles();
	$page .= Forms->display_hidden( 'Description:', 'desc', $profiles_detail{$name}{'description'} );
	delete $profiles_detail{$name}{'description'};

	if ( $profiles_detail{$name}{'hostgroups'}[0] ) {
	    $doc = "Applied to hosts:\n";
	    foreach my $hg ( sort { $a <=> $b } @{ $profiles_detail{$name}{'hostgroups'} } ) {
		$doc .= "&nbsp;&nbsp;$hg,";
	    }
	    chop $doc;
	    $page .= Forms->wizard_doc( 'Host Groups', $doc );
	}
	delete $profiles_detail{$name}{'hostgroups'};
	$doc = "Applied to hosts:<br><br>\n";
	foreach my $sp ( sort keys %{ $profiles_detail{$name} } ) {
	    $doc .= "&nbsp;&nbsp;$sp:&nbsp;&nbsp; $profiles_detail{$name}{$sp}<br>\n";
	}
	if ($doc) { $page .= Forms->wizard_doc( 'Service Profiles', $doc ) }
	unless (@hostnames) {
	    my %w = ( 'hostprofile_id' => $profile{'hostprofile_id'} );
	    @hostnames = StorProc->fetch_list_where( 'hosts', 'name', \%w );
	}
	my @nonmembers = StorProc->fetch_list( 'hosts', 'name' );
	$page .= Forms->members( 'Hosts:', 'hosts', \@hostnames, \@nonmembers, '', '', '' );
	$page .= Forms->hidden( \%hidden );
	$page .= Forms->form_bottom_buttons( \%save, \%cancel );
    }
    return $page;
}

#
##################################################
# Time periods
#

sub timeperiods() {
    my $page = undef;
    my $name = $query->param('name');
    $name =~ s/^\s+|\s+$//g;
    my $alias = $query->param('alias');
    my %days  = ();
    $days{'sunday'}    = $query->param('sunday');
    $days{'monday'}    = $query->param('monday');
    $days{'tuesday'}   = $query->param('tuesday');
    $days{'wednesday'} = $query->param('wednesday');
    $days{'thursday'}  = $query->param('thursday');
    $days{'friday'}    = $query->param('friday');
    $days{'saturday'}  = $query->param('saturday');
    my @wdays    = ( 'sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday' );
    my $required = undef;
    my $got_form = 0;
    $hidden{'view'}        = $view;
    $hidden{'update_main'} = 1;
    my %have_weekday = ();
    my %timeperiod = StorProc->fetch_one( 'time_periods', 'name', $name );

    foreach my $day (@wdays) {
	my %where = ( 'timeperiod_id' => $timeperiod{'timeperiod_id'}, 'name' => $day );
	my %one_weekday = StorProc->fetch_one_where( 'time_period_property', \%where );
	$timeperiod{$day} = $one_weekday{value};
	$have_weekday{$day} = 1 if %one_weekday;
    }
    if ( $query->param('add') || $query->param('save') ) {
	foreach my $day (@wdays) {
	    $timeperiod{$day} = $days{$day};
	}
    }
    if ( $query->param('add') ) {
	if ( $name && $alias ) {
	    if ( $timeperiod{'name'} ) {
		push @errors, "Time period $name already exists";
	    }
	    else {
		my @values = ( \undef, $name, $alias, '' );
		my $id = StorProc->insert_obj_id( 'time_periods', \@values, 'timeperiod_id' );
		if ( $id =~ /error/i ) { push @errors, $id }
		unless (@errors) {
		    foreach my $day (@wdays) {
			if ( $timeperiod{$day} ) {
			    my @values = ( $id, $day, 'weekend', $timeperiod{$day} );
			    my $result = StorProc->insert_obj( 'time_period_property', \@values );
			    if ( $result =~ /error/i ) { push @errors, $id }
			}
		    }
		}
		unless (@errors) {
		    $page .= Forms->header( $page_title, $session_id, $view, '', '', '1' );
		    $page .= Forms->form_top( 'Time Period', '', '1' );
		    my @message = ("$name.");
		    $page .= Forms->form_message( 'Added:', \@message, 'row1' );
		    $page .= Forms->hidden( \%hidden );
		    $page .= Forms->form_bottom_buttons( \%continue, $tab++ );
		    $got_form = 1;
		}
	    }
	}
	else {
	    $required = 1;
	    push @errors, "Missing required fields.";
	}
    }
    elsif ( $query->param('save') ) {
	if ($alias) {
	    foreach my $day (@wdays) {
		if ( $timeperiod{$day} ) {
		    if ( $have_weekday{$day} ) {
			my %values = ( 'type' => 'weekday', 'value' => $timeperiod{$day} );
			my %where = ( 'timeperiod_id' => $timeperiod{'timeperiod_id'}, 'name' => $day );
			my $result = StorProc->update_obj_where( 'time_period_property', \%values, \%where );
			if ( $result =~ /error/i ) { push @errors, $result }
		    }
		    else {
			my @values = ( $timeperiod{'timeperiod_id'}, $day, 'weekend', $timeperiod{$day} );
			my $result = StorProc->insert_obj( 'time_period_property', \@values );
			if ( $result =~ /error/i ) { push @errors, $result }
		    }
		}
		else {
		    my %where = ( 'timeperiod_id' => $timeperiod{'timeperiod_id'}, 'name' => $day );
		    my $result = StorProc->delete_one_where( 'time_period_property', \%where );
		    if ( $result =~ /error/i ) { push @errors, $result }
		}
	    }
	    my %values = ( 'alias' => $alias );
	    my $result = StorProc->update_obj( 'time_periods', 'name', $name, \%values );
	    if ( $result =~ /error/i ) { push @errors, $result }
	    unless (@errors) {
		$page .= Forms->header( $page_title, $session_id, $view, '', '', '1' );
		$page .= Forms->form_top('Time Period');
		my @message = ("$name.");
		$page .= Forms->form_message( 'Saved:', \@message, 'row1' );
		$page .= Forms->hidden( \%hidden );
		$page .= Forms->form_bottom_buttons( \%continue, $tab++ );
		$got_form = 1;
	    }
	}
	else {
	    push @errors, "Missing required field.";
	    $required = 1;
	}
    }
    elsif ( $query->param('delete') ) {
	$hidden{'delete'} = 1;
	$hidden{'name'}   = $name;
	if ( $query->param('yes') ) {
	    my $result = StorProc->delete_all( 'time_periods', 'name', $name );
	    if ( $result =~ /error/i ) {
		push @errors, $result;
		delete $hidden{'delete'};
	    }
	    else {
		$page .= Forms->header( $page_title, $session_id, 'notifications', '', '1', '1' );
		$page .= Forms->form_top( 'Time Period', '', '1' );
		my @message = ("$name.");
		$page .= Forms->form_message( 'Removed:', \@message, 'row1' );
		$page .= Forms->hidden( \%hidden );
		$page .= Forms->form_bottom_buttons( \%continue, $tab++ );
		$got_form = 1;
	    }
	}
	elsif ( $query->param('no') ) {
	    delete $hidden{'delete'};
	}
	else {
	    $page .= Forms->header( $page_title, $session_id, $view, '', '', '1' );
	    $page .= Forms->form_top('Time Period');
	    my $message = "Are you sure you want to remove time period \"$name\"?";
	    $page .= Forms->form_doc($message);
	    $page .= Forms->hidden( \%hidden );
	    $page .= Forms->form_bottom_buttons( \%yes, \%no, $tab++ );
	    $got_form = 1;
	}
    }
    unless ($got_form) {
	my @props = ( 'alias', 'sunday' );
	my %docs = Doc->properties_doc( 'time_periods', \@props );
	my %notify = StorProc->fetch_one( 'setup', 'name', 'enable_notifications' );
	$page .= Forms->header( $page_title, $session_id, $view );
	$page .= Forms->form_top( "Time Period", 'onsubmit="selIt();"', '1' );
	if (@errors) { $page .= Forms->form_errors( \@errors ) }
	if ( $query->param('new') ) {
	    $page .= Forms->text_box( 'Time period name:', 'name', $name, $textsize{'alias'}, $required, $docs{'name'}, '', '' );
	    $hidden{'new'} = 1;
	}
	else {
	    $page .= Forms->display_hidden( 'Time period name:', 'name', $timeperiod{'name'} );
	}
	unless ($alias) {
	    $alias = $timeperiod{'alias'};
	}
	foreach my $day ( keys %days ) { $days{$day} = $timeperiod{$day} }
	$page .= Forms->text_box( 'Alias (long name):', 'alias', $alias, $textsize{'long'}, $required, $docs{'alias'}, '', '' );
	foreach my $day (@wdays) {
	    $page .= Forms->text_box( "\u$day:", $day, $days{$day}, $textsize{'long'}, '', $docs{$day}, '', '' );
	}
	$page .= Forms->hidden( \%hidden );
	if ( $query->param('new') ) {
	    $page .= Forms->form_bottom_buttons( \%add, \%cancel );
	}
	else {
	    $page .= Forms->form_bottom_buttons( \%save, \%delete, \%cancel );
	}
    }
    return $page;
}

sub contacts() {
    my $page = undef;
    my $name = $query->param('name');
    $name =~ s/^\s+|\s+$//g;
    my $alias        = $query->param('alias');
    my $email        = $query->param('email');
    my $pager        = $query->param('pager');
    my $notification = $query->param('notification');
    my $required     = undef;
    my $got_form     = 0;
    $hidden{'view'}        = $view;
    $hidden{'update_main'} = 1;
    my %contact           = StorProc->fetch_one( 'contacts',          'name',       $name );
    my %contact_overrides = StorProc->fetch_one( 'contact_overrides', 'contact_id', $contact{'contact_id'} );
    my %template          = StorProc->fetch_one( 'contact_templates', 'name',       $defaults{'contact_template'} );
    my $data              = "<?xml version=\"1.0\" encoding=\"iso-8859-1\" ?>\n<data>\n</data>";

    if ( $query->param('add') ) {
	if ( $name && $alias && $notification ) {
	    if ( $contact{'name'} ) {
		push @errors, "Contact $name already exixts";
	    }
	    else {
		my @values = ( \undef, $name, $alias, $email, $pager, $template{'contacttemplate_id'}, '1', '' );
		my $id = StorProc->insert_obj_id( 'contacts', \@values, 'contact_id' );
		if ( $id =~ /error/i ) {
		    push @errors, $id;
		}
		else {
		    my %n = StorProc->fetch_one( 'time_periods', 'name', $notification );
		    unless ( $template{'host_notification_period'} eq $n{'timeperiod_id'} ) {
			my @values = ( $id, $n{'timeperiod_id'}, $n{'timeperiod_id'}, $data );
			my $result = StorProc->insert_obj( 'contact_overrides', \@values );
			if ( $result =~ /error/i ) { push @errors, $result }
		    }
		}
		unless (@errors) {
		    $page .= Forms->header( $page_title, $session_id, 'notifications', '', '1', '1' );
		    $page .= Forms->form_top( 'Contact', '', '1' );
		    my @message = ("$name.");
		    $page .= Forms->form_message( 'Added:', \@message, 'row1' );
		    $page .= Forms->hidden( \%hidden );
		    $page .= Forms->form_bottom_buttons( \%continue, $tab++ );
		    $got_form = 1;
		}
	    }
	}
	else {
	    push @errors, "Missing required fields.";
	    $required = 1;
	}
    }
    elsif ( $query->param('save') ) {
	if ( $alias && $notification ) {
	    my %values = ( 'alias' => $alias, 'email' => $email, 'pager' => $pager );
	    my $result = StorProc->update_obj( 'contacts', 'name', $name, \%values );
	    if ( $result =~ /error/i ) { push @errors, $result }
	    my %n = StorProc->fetch_one( 'time_periods', 'name', $notification );
	    unless ( $template{'host_notification_period'} eq $n{'timeperiod_id'} ) {
		if ( $contact_overrides{'contact_id'} ) {
		    my %values = (
			'host_notification_period'    => $n{'timeperiod_id'},
			'service_notification_period' => $n{'timeperiod_id'},
			'data'                        => $data
		    );
		    my $result = StorProc->update_obj( 'contact_overrides', 'contact_id', $contact{'contact_id'}, \%values );
		    if ( $result =~ /error/i ) { push @errors, $result }
		}
		else {
		    my @values = ( $contact{'contact_id'}, $n{'timeperiod_id'}, $n{'timeperiod_id'}, $data );
		    my $result = StorProc->insert_obj( 'contact_overrides', \@values );
		    if ( $result =~ /error/i ) { push @errors, $result }
		}
	    }
	    unless (@errors) {
		$page .= Forms->header( $page_title, $session_id, $view, '', '', '1' );
		$page .= Forms->form_top('Contact');
		my @message = ("$name.");
		$page .= Forms->form_message( 'Saved:', \@message, 'row1' );
		$page .= Forms->hidden( \%hidden );
		$page .= Forms->form_bottom_buttons( \%continue, $tab++ );
		$got_form = 1;
	    }
	}
	else {
	    push @errors, "Missing required fields.";
	    $required = 1;
	}
    }
    elsif ( $query->param('delete') ) {
	$hidden{'delete'} = 1;
	$hidden{'name'}   = $name;
	if ( $query->param('yes') ) {
	    my $result = StorProc->delete_all( 'contacts', 'name', $name );
	    if ( $result =~ /error/i ) {
		push @errors, $result;
		delete $hidden{'delete'};
	    }
	    else {
		$page .= Forms->header( $page_title, $session_id, 'notifications', '', '1', '1' );
		$page .= Forms->form_top( 'Contact', '', '1' );
		my @message = ("$name.");
		$page .= Forms->form_message( 'Removed:', \@message, 'row1' );
		$page .= Forms->hidden( \%hidden );
		$page .= Forms->form_bottom_buttons( \%continue, $tab++ );
		$got_form = 1;
	    }
	}
	elsif ( $query->param('no') ) {
	    delete $hidden{'delete'};
	}
	else {
	    $page .= Forms->header( $page_title, $session_id, $view, '', '', '1' );
	    $page .= Forms->form_top('Contact');
	    my $message = "Are you sure you want to remove contact \"$name\"?";
	    $page .= Forms->form_doc($message);
	    $page .= Forms->hidden( \%hidden );
	    $page .= Forms->form_bottom_buttons( \%yes, \%no, $tab++ );
	    $got_form = 1;
	}
    }
    unless ($got_form) {
	my @props = ( 'alias', 'email', 'pager', 'notification' );
	my %docs = Doc->properties_doc( 'contacts', \@props );
	my %notify = StorProc->fetch_one( 'setup', 'name', 'enable_notifications' );
	$page .= Forms->header( $page_title, $session_id, $view );
	$page .= Forms->form_top( "Contact", 'onsubmit="selIt();"', '1' );
	if (@errors) { $page .= Forms->form_errors( \@errors ) }
	if ( $query->param('new') ) {
	    $page .= Forms->text_box( 'Contact name:', 'name', $name, $textsize{'alias'}, $required, $docs{'name'}, '', '' );
	    $hidden{'new'} = 1;
	}
	else {
	    $page .= Forms->display_hidden( 'Contact name:', 'name', $contact{'name'} );
	}
	unless ($alias) { $alias = $contact{'alias'} }
	unless ($email) { $email = $contact{'email'} }
	unless ($pager) { $pager = $contact{'pager'} }
	unless ($notification) {
	    my %n = StorProc->fetch_one( 'time_periods', 'timeperiod_id', $contact_overrides{'host_notification_period'} );
	    $notification = $n{'name'};
	    unless ($notification) {
		my %n = StorProc->fetch_one( 'time_periods', 'timeperiod_id', $template{'host_notification_period'} );
		$notification = $n{'name'};
	    }
	}
	$page .= Forms->text_box( 'Alias (long name):', 'alias', $alias, $textsize{'long'}, $required, $docs{'alias'}, '', '' );
	my @timeperiods = StorProc->fetch_list( 'time_periods', 'name' );
	$page .= Forms->list_box( 'Notification period:', 'notification', \@timeperiods, $notification, $required, $docs{'notification'} );
	$page .= Forms->text_box( 'Email:', 'email', $email, $textsize{'short'}, '', $docs{'email'}, '', '' );
	$page .= Forms->text_box( 'Pager:', 'pager', $pager, $textsize{'short'}, '', $docs{'pager'}, '', '' );
	$page .= Forms->hidden( \%hidden );
	if ( $query->param('new') ) {
	    $page .= Forms->form_bottom_buttons( \%add, \%cancel );
	}
	else {
	    $page .= Forms->form_bottom_buttons( \%save, \%delete, \%cancel );
	}
    }
    return $page;
}

sub pre_flight_test() {
    my $page    = undef;
    my @results = ();
    $hidden{'view'}        = $view;
    $hidden{'update_main'} = 1;
    use MonarchFile;
    my %property_list = StorProc->property_list();
    my %nagios        = StorProc->fetch_one( 'setup', 'name', 'nagios_etc' );
    my %monarch_home  = StorProc->fetch_one( 'setup', 'name', 'monarch_home' );
    my $workspace     = $monarch_home{'value'} . '/workspace';
    my %nagios_cfg    = StorProc->fetch_one( 'setup', 'name', 'log_file' );
    my %nagios_cgi    = StorProc->fetch_one( 'setup', 'name', 'default_user_name' );

    if ( $nagios_cfg{'value'} && $nagios_cgi{'type'} ) {
	if ( $query->param('refreshed') ) {
	    use MonarchFile;
	    my ( $files, $errors ) =
	      Files->build_files( $user_acct, '', 'preflight', '', $nagios_ver, $nagios_etc, "$monarch_home/workspace", '' );
	    my @errors = @{$errors};
	    my @files  = @{$files};
	    unless ( $errors[0] ) {
		@results = StorProc->pre_flight_check( $nagios_bin, $monarch_home );
	    }
	    $page .= Forms->header( $page_title, $session_id, $top_menu );
	    $page .= Forms->form_top( 'Nagios Pre Flight Test', '' );
	    if (@errors) {
		$page .= Forms->form_message( "Error(s) building file(s):", \@errors, 'error' );
	    }
	    $page .= Forms->form_message( "Results:", \@results, 'row1' );
	    $hidden{'obj'} = undef;
	    $page .= Forms->hidden( \%hidden );
	    $page .= Forms->form_bottom_buttons( \%continue, $tab++ );
	}
	else {
	    my $now = time;
	    $refresh_url = "?update_main=1&amp;nocache=$now&amp;refreshed=1";
	    foreach my $name ( keys %hidden ) {
		$refresh_url .= qq(&amp;$name=$hidden{$name});
	    }
	    $page .= Forms->header( $page_title, $session_id, $view, $refresh_url, '', '1' );
	    $page .= Forms->form_top( 'Nagios Pre Flight Test', '', '1' );
	    $page .= Forms->form_doc('Running pre-flight check ...');
	    $now = time;
	    $page .= Forms->form_bottom_buttons();
	}
    }
    else {
	$page .= Forms->header( $page_title, $session_id, $view );
	$page .= Forms->form_top( 'Nagios Pre Flight Test', '', '1' );
	unless ( $nagios_cfg{'value'} ) {
	    push @errors, 'Nagios main configuration has not been defined.',
	      'Use Control->Nagios main configuration to load an existing file or set defaults.';
	}
	unless ( $nagios_cgi{'type'} ) {
	    push @errors, 'Nagios CGI configuration has not been defined.',
	      'Use Control->Nagios CGI configuration to load an existing file or set defaults.';
	}
	$page .= Forms->form_message( "Error(s):", \@errors, 'error' );
	$hidden{'obj'} = undef;
	$page .= Forms->hidden( \%hidden );
	$page .= Forms->form_bottom_buttons( \%continue, $tab++ );
    }
    return $page;
}

sub commit() {
    my $page    = undef;
    my @results = ();
    $hidden{'view'}        = $view;
    $hidden{'update_main'} = 1;
    my %abort  = ( 'name' => 'abort',  'value' => 'Abort' );
    my %backup = ( 'name' => 'backup', 'value' => 'Backup' );
    my %commit = ( 'name' => 'commit', 'value' => 'Commit' );
    use MonarchFile;
    my %property_list = StorProc->property_list();
    my %nagios        = StorProc->fetch_one( 'setup', 'name', 'nagios_etc' );
    my %monarch_home  = StorProc->fetch_one( 'setup', 'name', 'monarch_home' );
    my $workspace     = $monarch_home{'value'} . '/workspace';
    my %nagios_cfg    = StorProc->fetch_one( 'setup', 'name', 'log_file' );
    my %nagios_cgi    = StorProc->fetch_one( 'setup', 'name', 'default_user_name' );

    if ( $query->param('backup') ) {
	$page .= Forms->header( $page_title, $session_id, $view );
	$page .= Forms->form_top( 'Commit', '', '1' );
	## FIX MAJOR:  Figure out what earlier screen will have populated the annotation and lock parameters.
	## FIX MAJOR:  A synchronized backup might take a few moments, both because of
	## possible interlock delays with other programs and because the backup itself
	## can take macroscopic time, so we should have an intermediate screen. 
	my $annotation = $query->param('annotation');
	my $lock       = $query->param('lock');
	$annotation =~ s/^\s+|\s+$//g;
	$annotation = "Backup manually created by user \"$user_acct\"." if not $annotation;
	$annotation .= "\n";
	my ( $errors, $results, $timings ) = StorProc->synchronized_backup( $nagios{'value'}, $backup_dir, $user_acct, $annotation, $lock );
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
	$page .= Forms->form_bottom_buttons( \%abort, \%commit, $tab++ );
    }
    elsif ( $query->param('abort') ) {
	$page .= Forms->header( $page_title, $session_id, $view );
	$page .= Forms->form_top( 'Nagios Commit', '', '1' );
	$hidden{'obj'} = undef;
	$page .= Forms->hidden( \%hidden );
	my @message = ("Commit aborted.");
	$page .= Forms->form_message( "Action Canceled:", \@message, '' );
	$page .= Forms->form_bottom_buttons( \%continue, $tab++ );
	$hidden{'obj'} = undef;
    }
    elsif ( $query->param('commit') ) {
	if ( $query->param('refreshed') ) {
	    use MonarchFile;
	    $page .= Forms->header( $page_title, $session_id, $top_menu );
	    my ( $files, $errors ) =
	      Files->build_files( $user_acct, '', 'preflight', '', $nagios_ver, $nagios_etc, "$monarch_home/workspace", '' );
	    my @errors = @{$errors};
	    my @files  = @{$files};
	    if (@errors) {
		$page .= Forms->form_top( 'Commit Errors', '', '' );
		$page .= Forms->form_errors( \@errors );
		$page .= Forms->hidden( \%hidden );
		$page .= Forms->form_bottom_buttons( \%continue, $tab++ );
	    }
	    else {
		@results = StorProc->pre_flight_check( $nagios_bin, $monarch_home );
		my $res_str = pop @results;
		push @results, $res_str;
		unless ( $res_str =~ /Things look okay/ ) {
		    push @errors, "Make the necessary corrections and run pre flight check";
		}
		if (@errors) {
		    $page .= Forms->form_top( 'Commit Errors', '', '' );
		    $page .= Forms->form_errors( \@errors );
		    $page .= Forms->form_message( "Results:", \@results, 'row1' );
		    $page .= Forms->hidden( \%hidden );
		    $page .= Forms->form_bottom_buttons( \%continue, $tab++ );
		}
		else {
		    my ( $files, $errors ) = Files->build_files( $user_acct, '', '', '', $nagios_ver, $nagios_etc, $nagios_etc, '' );
		    my @errors = @{$errors};
		    my @files  = @{$files};
		    if (@errors) {
			$page .= Forms->form_top( 'Commit Errors', '', '' );
			$page .= Forms->form_errors( \@errors );
			$page .= Forms->hidden( \%hidden );
			$page .= Forms->form_bottom_buttons( \%continue, $tab++ );
		    }
		    else {
			## FIX MAJOR:  Figure out what earlier screen will have populated the annotation and lock parameters.
			## FIX MAJOR:  Convert this to a call to StorProc->synchronized_commit() instead, and deal with the
			## different parameters and different arguments it returns, making sure we do the right thing with
			## respect to error/result ordering.
			## FIX MAJOR:  A synchronized commit might take a few moments, both because of
			## possible interlock delays with other programs and because the implicit backup
			## can take macroscopic time, so we should have an intermediate screen.
			my $annotation = $query->param('annotation');
			my $lock       = $query->param('lock');
			$annotation =~ s/^\s+|\s+$//g;
			$annotation = "Backup auto-created after a Commit by user \"$user_acct\"." if not $annotation;
			$annotation .= "\n";
			my @commit = StorProc->commit( $monarch_home, $nagios_etc, $backup_dir, $user_acct, $annotation, $lock );
			push( @results, @commit );
			$page .= Forms->form_top( 'Nagios Commit', '' );
			$page .= Forms->form_message( "Results:", \@results, 'row1' );
			$hidden{'obj'} = undef;
			$page .= Forms->hidden( \%hidden );
			$page .= Forms->form_bottom_buttons( \%continue, $tab++ );
		    }
		}
	    }
	}
	else {
	    my $now = time;
	    $refresh_url = "?nocache=$now&amp;refreshed=1&amp;commit=1";
	    foreach my $name ( keys %hidden ) {
		$refresh_url .= qq(&amp;$name=$hidden{$name});
	    }
	    $page .= Forms->header( $page_title, $session_id, $view, $refresh_url, '', '1' );
	    $page .= Forms->form_top( 'Commit to Nagios', '', '1' );
	    $page .= Forms->form_doc('Running commit ...');
	    $now         = time;
	    $refresh_url = "?update_main=1&amp;nocache=$now&amp;refreshed=1&amp;commit=1";
	    $page .= Forms->form_bottom_buttons();
	}
    }
    elsif ( $nagios_cfg{'value'} && $nagios_cgi{'type'} ) {
	$page .= Forms->header( $page_title, $session_id, $view );
	$page .= Forms->form_top( 'Nagios Commit', '', '1' );
	$page .= Forms->hidden( \%hidden );
	my @message = ( "Are you sure you want to overwrite your active Nagios configuration and restart Nagios?" );
	push @message, ( "Should you choose to continue, it is strongly recommended that you first select the backup option." );
	$page .= Forms->form_message( "Nagios commit:", \@message, '' );
	$page .= Forms->form_bottom_buttons( \%abort, \%backup, \%commit, $tab++ );

    }
    else {
	$page .= Forms->header( $page_title, $session_id, $view );
	$page .= Forms->form_top( 'Nagios Commit', '', '1' );
	unless ( $nagios_cfg{'value'} ) {
	    push @errors, 'Nagios main configuration has not been defined.',
	      'Use Control->Nagios main configuration to load an existing file or set defaults.';
	}
	unless ( $nagios_cgi{'type'} ) {
	    push @errors, 'Nagios CGI configuration has not been defined.',
	      'Use Control->Nagios CGI configuration to load an existing file or set defaults.';
	}
	$page .= Forms->form_message( "Error(s):", \@errors, 'error' );
	$hidden{'obj'} = undef;
	$page .= Forms->hidden( \%hidden );
	$page .= Forms->form_bottom_buttons( \%continue, $tab++ );
    }
    return $page;
}

sub setup() {
    my $page     = undef;
    my $required = undef;
    my $got_form = 0;
    $hidden{'view'}        = $view;
    $hidden{'update_main'} = 1;
    if ( $query->param('save') ) {
	my @proplist = ( 'host_profile', 'contactgroup', 'contact_template' );
	foreach my $prop (@proplist) {
	    unless ( $query->param($prop) ) {
		push @errors, "Required: $prop";
		$required = 1;
	    }
	}
	unless (@errors) {
	    foreach my $prop (@proplist) {
		my %value = ( 'value' => scalar $query->param($prop) );
		my %where = ( 'type' => 'monarch_ez', 'name' => $prop );
		my $result = StorProc->update_obj_where( 'setup', \%value, \%where );
		if ( $result =~ /error/i ) { push @errors, $result }
	    }
	    unless (@errors) {
		$page .= Forms->header( $page_title, $session_id, $view );
		$page .= Forms->form_top( "Configuration Defaults", '', '1' );
		my @message = ("Changes accepted.");
		$page .= Forms->form_message( 'Saved:', \@message, 'row1' );
		$page .= Forms->hidden( \%hidden );
		$page .= Forms->form_bottom_buttons( \%continue );
		$got_form = 1;
	    }
	}
    }
    unless ($got_form) {
	my %docs = Doc->ez_defaults();
	$page .= Forms->header( $page_title, $session_id, $view );
	$page .= Forms->form_top( "Configuration Defaults", '', '1' );
	if (@errors) { $page .= Forms->form_errors( \@errors ) }
	my @profiles = StorProc->fetch_list( 'profiles_host', 'name' );
	$page .= Forms->list_box( 'Host profile:', 'host_profile', \@profiles, $defaults{'host_profile'}, $required, $docs{'profile'} );
	my @contactgroups = StorProc->fetch_list( 'contactgroups', 'name' );
	$page .=
	  Forms->list_box( 'Contact group:', 'contactgroup', \@contactgroups, $defaults{'contactgroup'}, $required, $docs{'contactgroup'} );
	my @contact_templates = StorProc->fetch_list( 'contact_templates', 'name' );
	$page .= Forms->list_box(
	    'Contact template:',
	    'contact_template', \@contact_templates, $defaults{'contact_template'},
	    $required, $docs{'contact_template'}
	);
	$page .= Forms->hidden( \%hidden );
	$page .= Forms->form_bottom_buttons( \%save, \%cancel );
    }
    return $page;
}

sub get_configs() {
    my %where = ( 'type' => 'config' );
    my %objects = StorProc->fetch_list_hash_array( 'setup', \%where );
    if ( -e '/usr/local/groundwork/config/db.properties' ) { $is_portal = 1 }
    $nagios_ver   = $objects{'nagios_version'}[2];
    $nagios_bin   = $objects{'nagios_bin'}[2];
    $nagios_etc   = $objects{'nagios_etc'}[2];
    $monarch_home = $objects{'monarch_home'}[2];
    $backup_dir   = $objects{'backup_dir'}[2];
    $upload_dir   = $objects{'upload_dir'}[2];
}

my $auth = StorProc->dbconnect();
if ( $auth == 1 ) {
    $user_acct = 'super_user';
}

get_configs();

my $show_login = 0;

if ($is_portal) {
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
    }
    else {
	$show_login = 1;
    }
}
elsif ($session_id) {
    my $session_user_acct;
    ( $userid, $session_user_acct, $session_id ) = StorProc->get_session($session_id);
    if ( !defined($userid) or !defined($session_user_acct) or $session_user_acct ne $user_acct ) {
	$session_id = undef;
    }
    $show_login = 2 unless $session_id;
}
else {
    $show_login = 1;
}

$show_login = 1 if !$show_login and not defined $userid;

if ($show_login > 1) {
    print "Content-type: text/html \n\n";
    print Forms->login_redirect;
    ( $userid, $session_id ) = undef;
}
elsif ($show_login) {
    print Forms->login($page_title);
    ( $userid, $session_id ) = undef;
}
else {
    if ( $view eq 'discover' ) {
	if ( $query->param('close') || $query->param('cancel') ) {
	    my $cookie = $query->cookie( CGISESSID => $session_id );
	    print $query->header( -cookie => $cookie );
	}
    }
    elsif ( $view eq 'search' ) {
	## Do nothing session string stored in form
    }
    else {
	my $cookie = $query->cookie( CGISESSID => $session_id );
	print $query->header( -cookie => $cookie );
    }

    if ( $query->param('update_top') ) {
	my @top_menus = ( 'hosts', 'host_groups', 'profiles', 'notifications', 'commit', 'setup' );
	unless ($is_portal) {
	    print Forms->top_frame( $user_acct, $top_menu, \@top_menus, $auth, $monarch_ver, '1', \%auth_add );
	}
    }
    elsif ( $query->param('update_main') ) {
	%defaults = StorProc->ez_defaults();
	foreach my $key ( keys %defaults ) {
	    if ( $defaults{$key} eq 'not_defined' ) {
		unless ( $query->param('host_profile')
		    && $query->param('contactgroup')
		    && $query->param('contact_template') )
		{
		    push @errors, "One or more default values are not defined. All defaults must be set before using this application.";
		    $view = 'setup';
		    last;
		}
	    }
	}
	if (   $query->param('continue')
	    || $query->param('cancel')
	    || $query->param('close') )
	{
	    if ( $view eq 'discover' || $view eq 'import' ) {
		my $file = $query->param('file');
		if ( -e $file ) {
		    unlink $file or print "error: cannot unlink $file ($!)";
		}
	    }
	    $body .= Forms->header( $page_title, $session_id, $view );
	}
	elsif ( $view eq 'hosts' ) {
	    $body .= hosts();
	}
	elsif ( $view eq 'import' ) {
	    $body .= import();
	}
	elsif ( $view eq 'discover' ) {
	    $body .= discover();
	}
	elsif ( $view eq 'host_groups' ) {
	    $body .= hostgroups();
	}
	elsif ( $view eq 'profiles' ) {
	    $body .= profiles();
	}
	elsif ( $view eq 'search' ) {
	    $body .= search();
	}
	elsif ( $view eq 'contacts' ) {
	    $body .= contacts();
	}
	elsif ( $view eq 'time_periods' ) {
	    $body .= timeperiods();
	}
	elsif ( $view eq 'notifications' ) {
	    $body .= notifications();
	}
	elsif ( $view eq 'pre_flight_test' ) {
	    $body .= pre_flight_test();
	}
	elsif ( $view eq 'commit' ) {
	    $body .= commit();
	}
	elsif ( $view eq 'setup' ) {
	    $body .= setup();
	}
	else {
	    $body .= Forms->header( $page_title, $session_id, $view );
	}
	print $body;
	print Forms->footer();
    }
    else {
	unless ($top_menu) { $top_menu = 'hosts' }
	print Forms->frame( $session_id, $top_menu, $is_portal, '1' );
    }
}
my $result = StorProc->dbdisconnect();

