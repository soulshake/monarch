#!/usr/bin/perl --
# MonArch - Groundwork Monitor Architect
# monarch_tree.cgi
#
############################################################################
# Release 4.6
# September 2018
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

# Note:  The CGI::Ajax doc is required reading.

use lib qq(/usr/local/groundwork/monarch/lib);
use strict;
use CGI;
use CGI::Ajax;
use MonarchTree;
use MonarchStorProc;
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

my $top_menu     = $query->param('top_menu');
my $ez           = $query->param('ez');
my $session_id   = $query->param('CGISESSID');
my $refresh_left = $query->param('refresh_left');
my $auth         = StorProc->dbconnect();
$session_id =~ s/[[:^xdigit:]]+//g if defined $session_id;
my ( $userid, $user_acct ) = StorProc->get_session($session_id);
my ( %auth_add, %auth_modify, %auth_delete ) = ();
my ( $is_portal, $enable_externals ) = 0;
if ( -e '/usr/local/groundwork/config/db.properties' ) { $is_portal = 1 }

sub nocase {
    lc($a) cmp lc($b);
}

my @nagios_cfg_nodes = (
    '<gap>',
    'Notification',
    'Configuration',
    'Time Format',
    'Character Constraint',
    'External Interface',
    'Debug',
    '<gap>',
    'Check Execution',
    'Check Scheduling',
    'Freshness Check',
    'Obsessive Processing',
    '<gap>',
    'Check Result Processing',
    'Object State Processing',
    'Flapping Control',
    'Performance Data Processing',
    'Event Handling',
    '<gap>',
    'Internal Operations',
    'State Retention',
    'Large Installation Tweaks',
    'Logging',
    'Miscellaneous Directives',
    '<gap>'
);

if ( $is_portal || $auth == 1 ) {
    unless ($userid) {
	$user_acct = $ENV{'REMOTE_USER'};
	## unless ($user_acct) { $user_acct = 'super_user' }
	( $userid, $session_id ) = StorProc->set_gwm_session($user_acct);
    }
    my ( $auth_add, $auth_modify, $auth_delete ) = StorProc->auth_matrix( $userid, '1' );
    %auth_add    = %{$auth_add};
    %auth_modify = %{$auth_modify};
    %auth_delete = %{$auth_delete};
    my %where = ( 'type' => 'config' );
    my %objects = StorProc->fetch_list_hash_array( 'setup', \%where );
    $enable_externals = $objects{'enable_externals'}[2];
}
elsif ($userid) {
    my ( $auth_add, $auth_modify, $auth_delete ) = StorProc->auth_matrix($userid);
    %auth_add    = %{$auth_add};
    %auth_modify = %{$auth_modify};
    %auth_delete = %{$auth_delete};
    my %where = ( 'type' => 'config' );
    my %objects = StorProc->fetch_list_hash_array( 'setup', \%where );
    $enable_externals = $objects{'enable_externals'}[2];
}
else {
    require MonarchForms;
    print "Content-type: text/html \n\n";
    print Forms->login_redirect();
}

if ( $top_menu && $userid ) {
    my @menus     = ();
    my %sub_menus = ();
    if ( $ez && $top_menu eq 'hosts' ) {
	if ( $is_portal || $auth == 1 ) {
	    @menus = ( 'new', 'import', 'discover', 'search', 'hosts' );
	}
	else {
	    @menus = ('new');
	    if ( $auth_add{'ez_import'} ) { push @menus, 'import' }
	    ## if ($auth_add{'ez_discover'}) { push @menus, 'discover' }
	    push( @menus, ( 'search', 'hosts' ) );
	}
	$sub_menus{'hosts'} = 1;
    }
    elsif ( $ez && $top_menu eq 'profiles' ) {
	@menus = ('profiles');
	$sub_menus{'profiles'} = 1;
    }
    elsif ( $top_menu eq 'host_groups' ) {
	@menus = ( 'new', 'modify' );
	$sub_menus{'modify'} = 1;
    }
    elsif ( $top_menu eq 'notifications' ) {
	@menus = ( 'notifications', 'time_periods', 'contacts' );
	$sub_menus{'time_periods'} = 1;
	$sub_menus{'contacts'}     = 1;
    }
    elsif ( $top_menu eq 'commit' ) {
	@menus = ( 'pre_flight_test', 'commit' );
    }
    elsif ( $top_menu eq 'setup' ) {
	@menus = ('setup');
    }
    elsif ( $top_menu eq 'hosts' ) {
	my @host_menus = (
	    'host_wizard',    'clone_host',        'delete_hosts', 'delete_host_services',
	    'search_hosts',   'hosts',             'host_groups',  'parent_child',
	    'host_templates', 'host_dependencies', 'host_extended_info'
	);
	if ($enable_externals) {
	    push @host_menus, 'search_host_externals';
	    push @host_menus, 'host_externals';
	}
	foreach my $menu (@host_menus) {
	    if ( $is_portal || $auth == 1 ) {
		push @menus, $menu;
	    }
	    else {
		if ( $menu =~ /wizard|clone/ && $auth_add{'hosts'} ) {
		    push @menus, $menu;
		}
		elsif ( ( $menu eq 'search_hosts' || $menu eq 'hosts' ) && $auth_modify{'hosts'} ) {
		    push @menus, $menu;
		}
		elsif ( $menu eq 'host_groups' && ( $auth_add{'hostgroups'} || $auth_modify{'hostgroups'} ) ) {
		    push @menus, $menu;
		}
		elsif (
		    $menu eq 'host_extended_info'
		    && ( $auth_add{'extended_host_info_templates'} || $auth_modify{'extended_host_info_templates'} )
		  )
		{
		    push @menus, $menu;
		}
		elsif ( $menu =~ /host_externals/ && ( $auth_add{'externals'} || $auth_modify{'externals'} ) ) {
		    push @menus, $menu;
		}
		elsif ( $auth_add{$menu} || $auth_modify{$menu} ) {
		    push @menus, $menu;
		}
	    }
	}
	$sub_menus{'hosts'}              = 1;
	$sub_menus{'host_groups'}        = 1;
	$sub_menus{'parent_child'}       = 1;
	$sub_menus{'host_templates'}     = 1;
	$sub_menus{'host_extended_info'} = 1;
	$sub_menus{'host_dependencies'}  = 1;
	$sub_menus{'host_externals'}     = 1;
    }
    elsif ( $top_menu eq 'services' ) {
	my @service_menus = (
	    'new_service',    'clone_service',     'search_services',      'services',
	    'service_groups', 'service_templates', 'service_dependencies', 'service_extended_info'
	);
	if ($enable_externals) {
	    push @service_menus, 'search_service_externals';
	    push @service_menus, 'service_externals';
	}
	foreach my $menu (@service_menus) {
	    if ( $is_portal || $auth == 1 ) {
		push @menus, $menu;
	    }
	    else {
		if ( $menu =~ /new|clone/ && $auth_add{'services'} ) {
		    push @menus, $menu;
		}
		elsif ( $menu eq 'search_services' && $auth_modify{'services'} ) {
		    push @menus, $menu;
		}
		elsif (
		    $menu eq 'service_dependencies'
		    && ( $auth_add{'service_dependency_templates'} || $auth_modify{'service_dependency_templates'} )
		  )
		{
		    push @menus, $menu;
		}
		elsif (
		    $menu eq 'service_extended_info'
		    && ( $auth_add{'extended_service_info_templates'} || $auth_modify{'extended_service_info_templates'} )
		  )
		{
		    push @menus, $menu;
		}
		elsif ( $menu eq 'service_groups' && ( $auth_add{'servicegroups'} || $auth_modify{'servicegroups'} ) ) {
		    push @menus, $menu;
		}
		elsif ( $menu =~ /service_externals/ && ( $auth_add{'externals'} || $auth_modify{'externals'} ) ) {
		    push @menus, $menu;
		}
		elsif ( $auth_add{$menu} || $auth_modify{$menu} ) {
		    push @menus, $menu;
		}
	    }
	}
	$sub_menus{'services'}              = 1;
	$sub_menus{'service_templates'}     = 1;
	$sub_menus{'service_dependencies'}  = 1;
	$sub_menus{'service_groups'}        = 1;
	$sub_menus{'service_extended_info'} = 1;
	$sub_menus{'service_externals'}     = 1;
    }
    elsif ( $top_menu eq 'profiles' ) {
	my @profile_menus = ( 'host_profiles', 'service_profiles', 'profile_importer' );
	foreach my $menu (@profile_menus) {
	    if ( $is_portal || $auth == 1 ) {
		push @menus, $menu;
	    }
	    elsif ( $auth_add{'profiles'} || $auth_modify{'profiles'} ) {
		push @menus, $menu;
	    }
	}
	$sub_menus{'host_profiles'}    = 1;
	$sub_menus{'service_profiles'} = 1;
	$sub_menus{'profile_importer'} = 1;
    }
    elsif ( $top_menu eq 'contacts' ) {
	my @contact_menus = ( 'contacts', 'contact_groups', 'contact_templates' );
	foreach my $menu (@contact_menus) {
	    if ( $is_portal || $auth == 1 ) {
		push @menus, $menu;
	    }
	    elsif ( $auth_add{$menu} || $auth_modify{$menu} ) {
		push @menus, $menu;
	    }
	    elsif ( $menu eq 'contact_groups' && ( $auth_add{'contactgroups'} || $auth_modify{'contactgroups'} ) ) {
		push @menus, $menu;
	    }
	}
	$sub_menus{'contacts'}          = 1;
	$sub_menus{'contact_groups'}    = 1;
	$sub_menus{'contact_templates'} = 1;
    }
    elsif ( $top_menu eq 'commands' ) {
	my @command_menus = ( 'new', 'copy', 'search', 'modify' );
	foreach my $menu (@command_menus) {
	    if ( $is_portal || $auth == 1 ) {
		push @menus, $menu;
	    }
	    elsif ( $menu =~ /new|copy/ && $auth_add{'commands'} ) {
		push @menus, $menu;
	    }
	    elsif ( $auth_modify{'commands'} ) {
		push @menus, $menu;
	    }
	}
	$sub_menus{'copy'}   = 1;
	$sub_menus{'modify'} = 1;
    }
    elsif ( $top_menu eq 'time_periods' ) {
	my @time_period_menus = ( 'new', 'copy', 'modify' );
	foreach my $menu (@time_period_menus) {
	    if ( $is_portal || $auth == 1 ) {
		push @menus, $menu;
	    }
	    elsif ( $menu =~ /new|copy/ && $auth_add{'time_periods'} ) {
		push @menus, $menu;
	    }
	    elsif ( $auth_modify{'time_periods'} ) {
		push @menus, $menu;
	    }
	}
	$sub_menus{'copy'}   = 1;
	$sub_menus{'modify'} = 1;
    }
    elsif ( $top_menu eq 'escalations' ) {
	my @escalation_menus = ( 'escalations', 'escalation_trees' );
	foreach my $menu (@escalation_menus) {
	    if ( $is_portal || $auth == 1 ) {
		push @menus, $menu;
	    }
	    elsif ( $menu eq 'escalation_trees' && ( $auth_add{'escalations'} || $auth_modify{'escalations'} ) ) {
		push @menus, $menu;
	    }
	    elsif ( $auth_add{$menu} || $auth_modify{$menu} ) {
		push @menus, $menu;
	    }
	}
	$sub_menus{'escalations'}      = 1;
	$sub_menus{'escalation_trees'} = 1;
    }
    elsif ( $top_menu eq 'groups' ) {
	my @group_menus = ( 'new', 'groups', 'macros', 'build_instances' );
	foreach my $menu (@group_menus) {
	    push @menus, $menu;
	}
	$sub_menus{'groups'} = 1;
    }
    elsif ( $top_menu eq 'control' ) {
	my @control_menus = (
	    'setup',           'nagios_cgi_configuration', 'nagios_main_configuration', 'nagios_resource_macros',
	    'pre_flight_test', 'commit',                   'back_up_and_restore'
	);
	unshift @control_menus, 'users', 'user_groups' if not $is_portal;
	foreach my $menu (@control_menus) {
	    if ( $is_portal || $auth == 1 ) {
		push @menus, $menu;
	    }
	    else {
		if ( $enable_externals && $auth_add{$menu} && $menu ) { }
		if ( $auth_add{$menu} ) { push @menus, $menu }
	    }
	}
	if ( $enable_externals && $auth_add{'commit'} ) {
	    push @menus, 'build_externals';
	}
	$sub_menus{'nagios_main_configuration'} = 1;
	$sub_menus{'user_groups'}               = 1;
	$sub_menus{'users'}                     = 1;
    }
    elsif ( $top_menu eq 'tools' ) {
	my @tool_menus = ( 'import_from_files', 'export_to_files' );
	foreach my $menu (@tool_menus) {
	    if ( $is_portal || $auth == 1 ) {
		push @menus, $menu;
	    }
	    elsif ( $auth_add{$menu} ) {
		push @menus, $menu;
	    }
	}
    }
    my $detail = Tree->header( 'Monarch', $refresh_left );
    $detail .= Tree->root_tree( \@menus, \%sub_menus, $top_menu, $session_id, $ez );
    my $url = Tree->get_ajax_url();
    my $pjx = new CGI::Ajax( 'get_tree' => $url );
    print $pjx->build_html( $query, $detail );
    print Tree->footer();
    print "<br>";  # vertical space at bottom of entire menu
}
elsif ( $query->param('args') && $session_id ) {
    my @input = $query->$multi_param('args');
    if ($debug) {
	my $now = time;
	if ( open( FILE, '>', '/tmp/debug.log' ) ) {
	    print FILE "==============================\n$now\n";
	    for (my $i = 0; $i < @input; ++$i) {
		print FILE "arg $i = $input[$i]\n";
	    }
	    print FILE "userid = $userid\n";
	    print FILE "user_acct = $user_acct\n";
	    print FILE "debug = $debug\n";
	    close(FILE);
	}
    }
    $input[3] = uri_unescape( $input[3] );
    my @nodes  = ();
    my $detail = undef;
    if ( $input[1] eq 'hosts' ) {
	if ( $input[6] ) {
	    if ( $input[2] == 1 ) {
		$input[4] .= 'view=hosts&name=';
		@nodes = sort StorProc->fetch_list( 'hostgroups', 'name' );
		push @nodes, 'unassigned';
	    }
	    elsif ( $input[2] == 2 ) {
		if ( $input[3] eq 'unassigned' ) {
		    @nodes = sort StorProc->get_hosts_unassigned();
		}
		else {
		    @nodes = sort StorProc->get_hostgroup_hosts( $input[3] );
		}
	    }
	    $detail = Tree->child_tree( \@nodes, $input[1], $input[2], '2', $input[3], $input[4], $input[5], $input[6] );
	}
	else {
	    if ( $input[2] == 1 ) {
		$input[4] .= 'view=manage_host&obj=hosts';
		@nodes = sort StorProc->fetch_list( 'hostgroups', 'name' );
		push @nodes, 'unassigned';
	    }
	    elsif ( $input[2] == 2 ) {
		if ( $input[3] eq 'unassigned' ) {
		    @nodes = sort StorProc->get_hosts_unassigned();
		}
		else {
		    @nodes = sort StorProc->get_hostgroup_hosts( $input[3] );
		}
	    }
	    elsif ( $input[2] == 3 ) {
		my %host = StorProc->fetch_one( 'hosts', 'name', $input[3] );
		@nodes = StorProc->get_host_services( $host{'host_id'} );
		$input[1] = 'host_services';
	    }
	    $detail = Tree->child_tree( \@nodes, $input[1], $input[2], '3', $input[3], $input[4] );
	}
    }
    elsif ( $input[0] eq 'host_groups' ) {
	$input[1] = 'host_groups';
	$input[4] .= 'view=host_groups&name=';
	@nodes = sort StorProc->fetch_list( 'hostgroups', 'name' );
	$detail = Tree->child_tree( \@nodes, $input[1], $input[2], '1', $input[3], $input[4], $input[5], $input[6] );
    }
    elsif ( $input[1] eq 'host_groups' ) {
	if ( $input[2] == 1 ) {
	    if ( $is_portal || $auth == 1 ) {
		@nodes = ( 'new', 'copy', 'modify' );
	    }
	    else {
		if ( $auth_add{'hostgroups'} )    { push @nodes, ( 'new', 'copy' ) }
		if ( $auth_modify{'hostgroups'} ) { push @nodes, 'modify' }
	    }
	}
	elsif ( $input[2] == 2 ) {
	    if ( $input[3] eq 'copy' ) {
		$input[4] .= 'view=design&obj=hostgroups&task=copy&source=';
	    }
	    elsif ( $input[3] eq 'modify' ) {
		$input[4] .= 'view=manage&obj=hostgroups&task=modify&name=';
	    }
	    @nodes = sort StorProc->fetch_list( 'hostgroups', 'name' );
	}
	$detail = Tree->child_tree( \@nodes, $input[1], $input[2], '2', $input[3], $input[4] );
    }
    elsif ( $input[1] eq 'parent_child' ) {
	if ( $input[2] == 1 ) {
	    if ( $is_portal || $auth == 1 ) {
		@nodes = ( 'new', 'modify' );
	    }
	    else {
		if ( $auth_add{'parent_child'} )    { push @nodes, 'new' }
		if ( $auth_modify{'parent_child'} ) { push @nodes, 'modify' }
	    }
	    $detail = Tree->child_tree( \@nodes, $input[1], $input[2], '2', $input[3], $input[4] );
	}
	elsif ( $input[2] == 2 ) {
	    $input[4] .= 'view=parent_child&obj=parent_child&task=modify&name=';
	    @nodes = sort StorProc->get_parents();
	    $detail = Tree->child_tree( \@nodes, $input[1], $input[2], '2', $input[3], $input[4] );
	}
    }
    elsif ( $input[1] eq 'host_templates' ) {
	if ( $input[2] == 1 ) {
	    if ( $is_portal || $auth == 1 ) {
		@nodes = ( 'new', 'copy', 'modify' );
	    }
	    else {
		if ( $auth_add{'host_templates'} )    { push @nodes, ( 'new', 'copy' ) }
		if ( $auth_modify{'host_templates'} ) { push @nodes, 'modify' }
	    }
	    $detail = Tree->child_tree( \@nodes, $input[1], $input[2], '2', $input[3], $input[4] );
	}
	elsif ( $input[2] == 2 ) {
	    if ( $input[3] eq 'copy' ) {
		$input[4] .= 'view=design&obj=host_templates&task=copy&source=';
	    }
	    elsif ( $input[3] eq 'modify' ) {
		$input[4] .= 'view=manage&obj=host_templates&task=modify&name=';
	    }
	    @nodes = sort StorProc->fetch_list( 'host_templates', 'name' );
	    $detail = Tree->child_tree( \@nodes, $input[1], $input[2], '2', $input[3], $input[4] );
	}
    }
    elsif ( $input[1] eq 'host_extended_info' ) {
	if ( $input[2] == 1 ) {
	    if ( $is_portal || $auth == 1 ) {
		@nodes = ( 'new', 'copy', 'modify' );
	    }
	    else {
		if ( $auth_add{'extended_host_info_templates'} )    { push @nodes, ( 'new', 'copy' ) }
		if ( $auth_modify{'extended_host_info_templates'} ) { push @nodes, 'modify' }
	    }
	    $detail = Tree->child_tree( \@nodes, $input[1], $input[2], '2', $input[3], $input[4] );
	}
	elsif ( $input[2] == 2 ) {
	    if ( $input[3] eq 'copy' ) {
		$input[4] .= 'view=design&obj=extended_host_info_templates&task=copy&source=';
	    }
	    elsif ( $input[3] eq 'modify' ) {
		$input[4] .= 'view=manage&obj=extended_host_info_templates&task=modify&name=';
	    }
	    @nodes = sort StorProc->fetch_list( 'extended_host_info_templates', 'name' );
	    $detail = Tree->child_tree( \@nodes, $input[1], $input[2], '2', $input[3], $input[4] );
	}
    }
    elsif ( $input[1] eq 'host_dependencies' ) {
	if ( $input[2] == 1 ) {
	    if ( $is_portal || $auth == 1 ) {
		@nodes = ( 'new', 'modify' );
	    }
	    else {
		if ( $auth_add{'host_dependencies'} )    { push @nodes, 'new' }
		if ( $auth_modify{'host_dependencies'} ) { push @nodes, 'modify' }
	    }
	    $detail = Tree->child_tree( \@nodes, $input[1], $input[2], '2', $input[3], $input[4] );
	}
	elsif ( $input[2] == 2 ) {
	    $input[4] .= 'view=host_dependencies&obj=host_dependencies&task=modify&name=';
	    @nodes = sort StorProc->get_host_dep_parents();
	    $detail = Tree->child_tree( \@nodes, $input[1], $input[2], '2', $input[3], $input[4] );
	}
    }
    elsif ( $input[1] eq 'host_externals' ) {
	if ( $input[2] == 1 ) {
	    if ( $is_portal || $auth == 1 ) {
		@nodes = ( 'new', 'copy', 'modify' );
	    }
	    else {
		if ( $auth_add{'externals'} )    { push @nodes, ( 'new', 'copy' ) }
		if ( $auth_modify{'externals'} ) { push @nodes, 'modify' }
	    }
	    $detail = Tree->child_tree( \@nodes, $input[1], $input[2], '2', $input[3], $input[4] );
	}
	elsif ( $input[2] == 2 ) {
	    if ( $input[3] eq 'copy' ) {
		$input[4] .= 'view=host_externals&obj=host_externals&task=copy&source=';
	    }
	    elsif ( $input[3] eq 'modify' ) {
		$input[4] .= 'view=host_externals&obj=host_externals&task=modify&name=';
	    }
	    my %where = ( 'type' => 'host' );
	    # We have no index on externals.name, so we get back an
	    # unsorted list of names that we need to sort ourselves.
	    @nodes = sort StorProc->fetch_list_where( 'externals', 'name', \%where );
	    $detail = Tree->child_tree( \@nodes, $input[1], $input[2], '2', $input[3], $input[4] );
	}
    }
    elsif ( $input[1] eq 'services' ) {
	$input[4] .= 'view=service&obj=services&obj_view=service_detail&name=';
	# We have a unique index on service_names.name, but inexplicably the MySQL database does not sort
	# ISO-8859-1 chars in the expected collation sequence (e.g., a-umlaut before u-umlaut).
	@nodes = sort StorProc->fetch_list( 'service_names', 'name' );
	$detail = Tree->child_tree( \@nodes, $input[1], $input[2], '1', $input[3], $input[4] );
    }
    elsif ( $input[1] eq 'service_templates' ) {
	if ( $input[2] == 1 ) {
	    if ( $is_portal || $auth == 1 ) {
		@nodes = ( 'new', 'copy', 'modify' );
	    }
	    else {
		if ( $auth_add{'service_templates'} )    { push @nodes, 'new', 'copy' }
		if ( $auth_modify{'service_templates'} ) { push @nodes, 'modify' }
	    }
	    $detail = Tree->child_tree( \@nodes, $input[1], $input[2], '2', $input[3], $input[4] );
	}
	elsif ( $input[2] == 2 ) {
	    if ( $input[3] eq 'copy' ) {
		$input[4] .= 'view=service_template&obj=service_templates&task=copy&source=';
	    }
	    elsif ( $input[3] eq 'modify' ) {
		$input[4] .= 'view=service_template&obj=service_templates&task=modify&name=';
	    }
	    @nodes = sort StorProc->fetch_list( 'service_templates', 'name' );
	    $detail = Tree->child_tree( \@nodes, $input[1], $input[2], '2', $input[3], $input[4] );
	}
    }
    elsif ( $input[1] eq 'service_dependencies' ) {
	if ( $input[2] == 1 ) {
	    if ( $is_portal || $auth == 1 ) {
		@nodes = ( 'new', 'copy', 'modify' );
	    }
	    else {
		## fixed service_dependencies 2007-01-22
		if ( $auth_add{'service_dependency_templates'} )    { push @nodes, ( 'new', 'copy' ) }
		if ( $auth_modify{'service_dependency_templates'} ) { push @nodes, 'modify' }
	    }
	    $detail = Tree->child_tree( \@nodes, $input[1], $input[2], '2', $input[3], $input[4] );
	}
	elsif ( $input[2] == 2 ) {
	    if ( $input[3] eq 'copy' ) {
		$input[4] .= 'view=design&obj=service_dependency_templates&task=copy&source=';
	    }
	    elsif ( $input[3] eq 'modify' ) {
		$input[4] .= 'view=manage&obj=service_dependency_templates&task=modify&name=';
	    }
	    @nodes = sort StorProc->fetch_list( 'service_dependency_templates', 'name' );
	    $detail = Tree->child_tree( \@nodes, $input[1], $input[2], '2', $input[3], $input[4] );
	}
    }
    elsif ( $input[1] eq 'service_groups' ) {
	if ( $input[2] == 1 ) {
	    if ( $is_portal || $auth == 1 ) {
		@nodes = ( 'new', 'modify' );
	    }
	    else {
		if ( $auth_add{'servicegroups'} )    { push @nodes, 'new' }
		if ( $auth_modify{'servicegroups'} ) { push @nodes, 'modify' }
	    }
	    $detail = Tree->child_tree( \@nodes, $input[1], $input[2], '2', $input[3], $input[4] );
	}
	elsif ( $input[2] == 2 ) {
	    $input[4] .= 'view=service_group&obj=servicegroups&task=modify&name=';
	    @nodes = sort StorProc->fetch_list( 'servicegroups', 'name' );
	    $detail = Tree->child_tree( \@nodes, $input[1], $input[2], '2', $input[3], $input[4] );
	}
    }
    elsif ( $input[1] eq 'service_extended_info' ) {
	if ( $input[2] == 1 ) {
	    if ( $is_portal || $auth == 1 ) {
		@nodes = ( 'new', 'copy', 'modify' );
	    }
	    else {
		if ( $auth_add{'extended_service_info_templates'} )    { push @nodes, ( 'new', 'copy' ) }
		if ( $auth_modify{'extended_service_info_templates'} ) { push @nodes, 'modify' }
	    }
	    $detail = Tree->child_tree( \@nodes, $input[1], $input[2], '2', $input[3], $input[4] );
	}
	elsif ( $input[2] == 2 ) {
	    if ( $input[3] eq 'copy' ) {
		$input[4] .= 'view=design&obj=extended_service_info_templates&task=copy&source=';
	    }
	    elsif ( $input[3] eq 'modify' ) {
		$input[4] .= 'view=manage&obj=extended_service_info_templates&task=modify&name=';
	    }
	    @nodes = sort StorProc->fetch_list( 'extended_service_info_templates', 'name' );
	    $detail = Tree->child_tree( \@nodes, $input[1], $input[2], '2', $input[3], $input[4] );
	}
    }
    elsif ( $input[1] eq 'service_externals' ) {
	if ( $input[2] == 1 ) {
	    if ( $is_portal || $auth == 1 ) {
		@nodes = ( 'new', 'copy', 'modify' );
	    }
	    else {
		if ( $auth_add{'externals'} )    { push @nodes, ( 'new', 'copy' ) }
		if ( $auth_modify{'externals'} ) { push @nodes, 'modify' }
	    }
	    $detail = Tree->child_tree( \@nodes, $input[1], $input[2], '2', $input[3], $input[4] );
	}
	elsif ( $input[2] == 2 ) {
	    if ( $input[3] eq 'copy' ) {
		$input[4] .= 'view=service_externals&obj=service_externals&task=copy&source=';
	    }
	    elsif ( $input[3] eq 'modify' ) {
		$input[4] .= 'view=service_externals&obj=service_externals&task=modify&name=';
	    }
	    my %where = ( 'type' => 'service' );
	    # We have no index on externals.name, so we get back an
	    # unsorted list of names that we need to sort ourselves.
	    @nodes = sort StorProc->fetch_list_where( 'externals', 'name', \%where );
	    $detail = Tree->child_tree( \@nodes, $input[1], $input[2], '2', $input[3], $input[4] );
	}
    }
    elsif ( $input[1] eq 'profiles' ) {
	if ( $input[2] == 1 ) {
	    $input[4] .= 'view=profiles&name=';
	    @nodes = sort StorProc->fetch_list( 'profiles_host', 'name' );
	    $detail = Tree->child_tree( \@nodes, $input[1], $input[2], '1', $input[3], $input[4], $input[5], $input[6] );
	}
    }
    elsif ( $input[1] eq 'host_profiles' ) {
	if ( $input[2] == 1 ) {
	    @nodes = ( 'new', 'modify' );
	    $detail = Tree->child_tree( \@nodes, $input[1], $input[2], '2', $input[3], $input[4] );
	}
	elsif ( $input[2] == 2 ) {
	    $input[4] .= 'view=host_profile&obj=profiles&task=modify&name=';
	    @nodes = sort StorProc->fetch_list( 'profiles_host', 'name' );
	    $detail = Tree->child_tree( \@nodes, $input[1], $input[2], '2', $input[3], $input[4] );
	}
    }
    elsif ( $input[1] eq 'service_profiles' ) {
	if ( $input[2] == 1 ) {
	    @nodes = ( 'new', 'copy', 'modify' );
	    $detail = Tree->child_tree( \@nodes, $input[1], $input[2], '2', $input[3], $input[4] );
	}
	elsif ( $input[2] == 2 ) {
	    if ( $input[3] eq 'copy' ) {
		$input[4] .= 'view=service_profile&obj=profiles&task=copy&source=';
	    }
	    elsif ( $input[3] eq 'modify' ) {
		$input[4] .= 'view=service_profile&obj=profiles&task=modify&name=';
	    }
	    @nodes = sort StorProc->fetch_list( 'profiles_service', 'name' );
	    $detail = Tree->child_tree( \@nodes, $input[1], $input[2], '2', $input[3], $input[4] );
	}
    }
    elsif ( $input[1] eq 'profile_importer' ) {
	if ( $input[2] == 1 ) {
	    @nodes = ( 'new', 'import' );
	    $detail = Tree->child_tree( \@nodes, $input[1], $input[2], '2', $input[3], $input[4] );
	}
	elsif ( $input[2] == 2 ) {
	    $input[4] .= 'view=profile_importer&obj=profiles&task=import&name=';
	    @nodes = sort nocase grep { $_ ne 'cgi-bin' && $_ ne 'WEB-INF' } StorProc->get_dir( '/usr/local/groundwork/monarch/profiles', '', 1, 1 );
	    $detail = Tree->child_tree( \@nodes, $input[1], $input[2], '2', $input[3], $input[4] );
	}
    }
    elsif ( $input[1] eq 'contacts' ) {
	if ( $input[2] == 1 ) {
	    if ( $is_portal || $auth == 1 ) {
		@nodes = ( 'new', 'copy', 'modify' );
	    }
	    else {
		if ( $auth_add{'contacts'} )    { push @nodes, ( 'new', 'copy' ) }
		if ( $auth_modify{'contacts'} ) { push @nodes, 'modify' }
	    }
	    if ( $input[6] ) { @nodes = ( 'new', 'modify' ) }
	    $detail = Tree->child_tree( \@nodes, $input[1], $input[2], '2', $input[3], $input[4], $input[5], $input[6] );
	}
	elsif ( $input[2] == 2 ) {
	    if ( $input[3] eq 'copy' ) {
		$input[4] .= 'view=design&obj=contacts&task=copy&source=';
	    }
	    elsif ( $input[3] eq 'modify' ) {
		if ( $input[6] ) {
		    $input[5] = $input[3];
		    $input[4] .= 'view=contacts&task=modify&name=';
		}
		else {
		    $input[4] .= 'view=manage&obj=contacts&task=modify&name=';
		}
	    }
	    @nodes = sort StorProc->fetch_list( 'contacts', 'name' );
	    $detail = Tree->child_tree( \@nodes, $input[1], $input[2], '2', $input[3], $input[4], $input[5], $input[6] );
	}
    }
    elsif ( $input[1] eq 'contact_groups' ) {
	if ( $input[2] == 1 ) {
	    if ( $is_portal || $auth == 1 ) {
		@nodes = ( 'new', 'copy', 'modify' );
	    }
	    else {
		if ( $auth_add{'contactgroups'} )    { push @nodes, ( 'new', 'copy' ) }
		if ( $auth_modify{'contactgroups'} ) { push @nodes, 'modify' }
	    }
	    $detail = Tree->child_tree( \@nodes, $input[1], $input[2], '2', $input[3], $input[4] );
	}
	elsif ( $input[2] == 2 ) {
	    if ( $input[3] eq 'copy' ) {
		$input[4] .= 'view=design&obj=contactgroups&task=copy&source=';
	    }
	    elsif ( $input[3] eq 'modify' ) {
		$input[4] .= 'view=manage&obj=contactgroups&task=modify&name=';
	    }
	    @nodes = sort StorProc->fetch_list( 'contactgroups', 'name' );
	    $detail = Tree->child_tree( \@nodes, $input[1], $input[2], '2', $input[3], $input[4] );
	}
    }
    elsif ( $input[1] eq 'contact_templates' ) {
	if ( $input[2] == 1 ) {
	    if ( $is_portal || $auth == 1 ) {
		@nodes = ( 'new', 'copy', 'modify' );
	    }
	    else {
		if ( $auth_add{'contact_templates'} )    { push @nodes, ( 'new', 'copy' ) }
		if ( $auth_modify{'contact_templates'} ) { push @nodes, 'modify' }
	    }
	    $detail = Tree->child_tree( \@nodes, $input[1], $input[2], '2', $input[3], $input[4] );
	}
	elsif ( $input[2] == 2 ) {
	    if ( $input[3] eq 'copy' ) {
		$input[4] .= 'view=design&obj=contact_templates&task=copy&source=';
	    }
	    elsif ( $input[3] eq 'modify' ) {
		$input[4] .= 'view=manage&obj=contact_templates&task=modify&name=';
	    }
	    @nodes = sort StorProc->fetch_list( 'contact_templates', 'name' );
	    $detail = Tree->child_tree( \@nodes, $input[1], $input[2], '2', $input[3], $input[4] );
	}
    }
    elsif ( $input[6] && $input[1] eq 'time_periods' ) {
	if ( $input[2] == 1 ) {
	    @nodes = ( 'new', 'modify' );
	}
	elsif ( $input[3] eq 'modify' ) {
	    $input[4] .= 'view=time_periods&name=';
	    @nodes = sort StorProc->fetch_list( 'time_periods', 'name' );
	}
	$detail = Tree->child_tree( \@nodes, $input[1], $input[2], '2', $input[3], $input[4], $input[5], $input[6] );
    }
    elsif ( $input[0] eq 'time_periods' ) {
	if ( $input[3] eq 'copy' ) {
	    $input[4] .= 'view=design&obj=time_periods&task=copy&source=';
	}
	elsif ( $input[3] eq 'modify' ) {
	    $input[4] .= 'view=manage&obj=time_periods&task=modify&name=';
	}
	@nodes = sort StorProc->fetch_list( 'time_periods', 'name' );
	$detail = Tree->child_tree( \@nodes, $input[0], $input[2], '1', $input[3], $input[4] );
    }
    elsif ( $input[0] eq 'commands' ) {
	if ( $input[3] eq 'copy' ) {
	    $input[4] .= 'view=commands&obj=commands&task=copy&source=';
	}
	elsif ( $input[3] eq 'modify' ) {
	    $input[4] .= 'view=commands&obj=commands&task=modify&name=';
	}
	@nodes = sort StorProc->fetch_list( 'commands', 'name' );
	$detail = Tree->child_tree( \@nodes, $input[0], $input[2], '1', $input[3], $input[4] );
    }
    elsif ( $input[1] eq 'escalations' ) {
	$input[3] =~ s/ escalation//;    # compensate for extra word in @nodes just below
	if ( $input[2] == 1 ) {
	    @nodes = ( 'host escalation', 'service escalation' );
	    $detail = Tree->child_tree( \@nodes, $input[1], $input[2], '3', $input[3], $input[4] );
	}
	elsif ( $input[2] == 2 ) {
	    $input[4] .= "view=escalations&obj=$input[3]\_escalation_templates&";
	    if ( $is_portal || $auth == 1 ) {
		@nodes = ( 'new', 'modify' );
	    }
	    else {
		if ( $auth_add{'escalations'} )    { push @nodes, 'new' }
		if ( $auth_modify{'escalations'} ) { push @nodes, 'modify' }
	    }
	    $detail = Tree->child_tree( \@nodes, $input[1], $input[2], '3', $input[3], $input[4], $input[3] );
	}
	elsif ( $input[2] == 3 ) {
	    my $esc_type = 'host';
	    if ( $input[4] =~ /obj=service/ ) { $esc_type = 'service' }
	    $input[4] .= "task=modify&name=";
	    my %where = ( 'type' => $esc_type );
	    @nodes = sort StorProc->fetch_list_where( 'escalation_templates', 'name', \%where );
	    $detail = Tree->child_tree( \@nodes, $input[1], $input[2], '3', $input[3], $input[4], $input[5] );
	}
    }
    elsif ( $input[1] eq 'escalation_trees' ) {
	$input[3] =~ s/ escalation tree//;    # compensate for extra words in @nodes just below
	if ( $input[2] == 1 ) {
	    @nodes = ( 'host escalation tree', 'service escalation tree' );
	    $detail = Tree->child_tree( \@nodes, $input[1], $input[2], '3', $input[3], $input[4] );
	}
	elsif ( $input[2] == 2 ) {
	    $input[4] .= "view=escalation_trees&obj=escalation_trees&type=$input[3]&";
	    if ( $is_portal || $auth == 1 ) {
		@nodes = ( 'new', 'modify' );
	    }
	    else {
		if ( $auth_add{'escalations'} )    { push @nodes, 'new' }
		if ( $auth_modify{'escalations'} ) { push @nodes, 'modify' }
	    }
	    $detail = Tree->child_tree( \@nodes, $input[1], $input[2], '3', $input[3], $input[4], $input[3] );
	}
	elsif ( $input[2] == 3 ) {
	    my $esc_type = 'host';
	    if ( $input[4] =~ /type=service/ ) { $esc_type = 'service' }
	    $input[4] .= "obj_view=detail&task=modify&name=";
	    my %where = ( 'type' => $esc_type );
	    @nodes = sort StorProc->fetch_list_where( 'escalation_trees', 'name', \%where );
	    $detail = Tree->child_tree( \@nodes, $input[1], $input[2], '3', $input[3], $input[4], $input[5] );
	}
    }
    elsif ( $input[1] eq 'groups' ) {
	if ( $input[2] == 1 ) {
	    if ( $is_portal || $auth == 1 || $user_acct eq 'super_user' ) {
		# We have no index on monarch_groups.name, so we get back an
		# unsorted list of names that we need to sort ourselves.
		# (Or we could have provided an $orderby parameter to fetch_list(),
		# instead, and let the database do the sorting according to its own
		# collation sequence, which might be different from Perl's.)
		@nodes = sort StorProc->fetch_list( 'monarch_groups', 'name' );
	    }
	    else {
		@nodes = sort StorProc->get_auth_groups($userid);
	    }
	    $detail = Tree->child_tree( \@nodes, $input[0], $input[2], '2', $input[3], $input[4] );
	}
	elsif ( $input[2] == 2 ) {
	    my %sub_menus = ();
	    $input[4] .= "view=groups&";
	    @nodes = ( 'detail', 'nagios_cgi', 'nagios_cfg', 'resource_cfg', 'pre_flight_test', 'build_instance', 'export' );
	    $sub_menus{'nagios_cfg'} = 1;
	    $detail = Tree->child_tree( \@nodes, $input[0], $input[2], '2', $input[3], $input[4], $input[3], undef, \%sub_menus );
	}
	elsif ( $input[2] == 3 ) {
	    if ( $input[3] eq 'nagios_cfg' ) {
		@nodes = @nagios_cfg_nodes;
	    }
	    else {
		@nodes = ();
	    }
	    $detail = Tree->child_tree( \@nodes, $input[0], $input[2], '3', $input[3], $input[4], $input[5] );
	}
    }
    elsif ( $input[1] eq 'nagios_main_configuration' ) {
	@nodes = @nagios_cfg_nodes;
	$input[4] .= 'view=control&obj=nagios_main_configuration&options=';
	$detail = Tree->child_tree( \@nodes, $input[1], $input[2], '1', $input[3], $input[4] );
    }
    elsif ( $input[1] eq 'users' ) {
	if ( $input[2] == 1 ) {
	    @nodes = ( 'new', 'modify' );
	    $detail = Tree->child_tree( \@nodes, $input[1], $input[2], '2', $input[3], $input[4] );
	}
	elsif ( $input[2] == 2 ) {
	    $input[4] .= 'view=control&obj=users&task=modify&mod_user=';
	    @nodes = sort StorProc->fetch_list( 'users', 'user_acct' );
	    $detail = Tree->child_tree( \@nodes, $input[1], $input[2], '2', $input[3], $input[4] );
	}
    }
    elsif ( $input[1] eq 'user_groups' ) {
	if ( $input[2] == 1 ) {
	    @nodes = ( 'new', 'modify' );
	    $detail = Tree->child_tree( \@nodes, $input[1], $input[2], '2', $input[3], $input[4] );
	}
	elsif ( $input[2] == 2 ) {
	    $input[4] .= 'view=control&obj=user_groups&task=modify&name=';
	    @nodes = sort StorProc->fetch_list( 'user_groups', 'name' );
	    $detail = Tree->child_tree( \@nodes, $input[1], $input[2], '2', $input[3], $input[4] );
	}
    }

    if ($debug) {
	my $now = time;
	if ( open( FILE, '>>', '/tmp/debug.log' ) ) {
	    print FILE "==============================\n$now\n";
	    print FILE "$detail\n";
	    close(FILE);
	}
    }

    print "\n";  # needed for the JBoss environment
    print $detail;
}

my $result = StorProc->dbdisconnect();

