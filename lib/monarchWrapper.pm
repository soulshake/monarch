#!/usr/local/groundwork/perl/bin/perl
## @file
# A wrapper to monarch lib functions
# @brief
# Wrapper to monarch lib
# @author
# Maik Aussendorf
# @version
# \$Id: monarchWrapper.pm 37 2014-11-05 20:59:00Z gherteg $
#
# Copyright (C) 2008-2014
# Maik Aussendorf <maik.aussendorf@dass-it.de> dass IT GmbH
# With modifications by GroundWork Open Source, Inc.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the
#    Free Software Foundation, Inc.
#    59 Temple Place, Suite 330
#    Boston, MA 02111-1307 USA
#

BEGIN {
    unshift @INC, '/usr/local/groundwork/core/monarch/lib';
}

use strict;
use MonarchStorProc;
use MonarchImport;
use MonarchFile;
use MonarchDeploy;
use MonarchExternals;
use MonarchAPI;

## @class
# Simplified wrapper for Monarch function calls.  Calls functions from MonarchStorProc, MonarchFile, MonarchImport,
# MonarchDeploy, MonarchExternals, and MonarchAPI.  Most of these are not documented in the original source;
# some are documented here.
# @brief  Wrapper for Monarch calls.
package monarchWrapper;

sub fetch_one {
    shift;
    return StorProc->fetch_one(@_);
}

sub fetch_one_where {
    shift;
    return StorProc->fetch_one_where(@_);
}

sub fetch_list_where {
    shift;
    return StorProc->fetch_list_where(@_);
}

sub fetch_list_start {
    shift;
    return StorProc->fetch_list_start(@_);
}

sub fetch_unique {
    shift;
    return StorProc->fetch_unique(@_);
}

sub fetch_all {
    shift;
    return StorProc->fetch_all(@_);
}

sub fetch_list_hash_array {
    shift;
    return StorProc->fetch_list_hash_array(@_);
}

sub fetch_hash_array_generic_key {
    shift;
    return StorProc->fetch_hash_array_generic_key(@_);
}

## @method hash fetch_service (int host_serviceid)
# Gets properties of a host service.
# @param host_serviceid Host service ID of the desired host service.
# @return Hash containing all properties of the host service.
sub fetch_service {
    shift;
    return StorProc->fetch_service(@_);
}

## @method hash parse_xml (string data)
# Parses XML data.
# @param data XML data to be parsed
# @return Hash containing all properties contained in the XML data.
sub parse_xml(@) {
    shift;
    return StorProc->parse_xml(@_);
}

## @method array get_names (string id_field, string table, arrayref members)
# Gets names corresponding to ID values.
# @param id_field table column to search
# @param table name of the Monarch table to search
# @param members individual ID values (generally integers) to search for
# @return array Names corresponding to member ID values
sub get_names {
    shift;
    return StorProc->get_names(@_);
}

sub dbconnect {
    shift;
    return StorProc->dbconnect(@_);
}

# Badly named, and deprecated.  Use get_hostgroup_hosts() instead.
sub get_host_hostgroup {
    shift;
    return StorProc->get_hostgroup_hosts(@_);
}

sub get_hostgroup_hosts {
    shift;
    return StorProc->get_hostgroup_hosts(@_);
}

# Badly named, and deprecated.  Use get_host_hostgroups() instead.
sub get_hostgroup_host {
    shift;
    return StorProc->get_host_hostgroups(@_);
}

sub get_host_hostgroups {
    shift;
    return StorProc->get_host_hostgroups(@_);
}

sub get_host_services {
    shift;
    return StorProc->get_host_services(@_);
}

sub get_service_name {
    shift;
    return StorProc->get_service_name(@_);
}

sub host_profile_apply {
    shift;
    return StorProc->host_profile_apply(@_);
}

sub insert_obj {
    shift;
    return StorProc->insert_obj(@_);
}

sub insert_obj_id {
    shift;
    return StorProc->insert_obj_id(@_);
}

sub delete_all {
    shift;
    return StorProc->delete_all(@_);
}

sub delete_one_where {
    shift;
    return StorProc->delete_one_where(@_);
}

sub clone_service {
    shift;
    return StorProc->clone_service(@_);
}

sub clone_host {
    shift;
    return StorProc->clone_host(@_);
}

sub get_profile_parent {
    shift;
    return StorProc->get_profile_parent(@_);
}

sub get_profile_hostgroup {
    shift;
    return StorProc->get_profile_hostgroup(@_);
}

sub get_profile_external {
    shift;
    return StorProc->get_profile_external(@_);
}

sub get_contactgroups {
    shift;
    return StorProc->get_contactgroups(@_);
}

sub host_has_service_profile_via_host {
    shift;
    return StorProc->host_has_service_profile_via_host(@_);
}

sub host_has_service_profile_via_hostgroup {
    shift;
    return StorProc->host_has_service_profile_via_hostgroup(@_);
}

sub host_has_service_profile_via_hostprofile {
    shift;
    return StorProc->host_has_service_profile_via_hostprofile(@_);
}

sub get_contactgroup_contacts {
    shift;
    return StorProc->get_contact_contactgroup(@_);
}

sub get_host_profile_service_profiles {
    shift;
    return StorProc->get_host_profile_service_profiles(@_);
}

## @fn
# Find services assigned to a serviceprofile.
# @param int serviceprofile ID
# @return a hash of servicename => servicename_id pairs for the services in the specified serviceprofile
sub get_service_profiles {
    shift;
    return StorProc->get_service_profiles(@_);
}

sub service_profile_apply {
    shift;
    return StorProc->service_profile_apply(@_);
}

sub fetch_host {
    shift;
    return StorProc->fetch_host(@_);
}

sub update_obj {
    shift;
    return StorProc->update_obj(@_);
}

sub update_obj_where {
    shift;
    return StorProc->update_obj_where(@_);
}

## @fn
# Return a hash with all hostnames as keys and their IDs as values
# @return Hashref
sub get_hosts {
    shift;
    return StorProc->get_hosts(@_);
}

## @fn
# Returns a list of all parents of a given host
# @param hostname The host to look for
# @return Array of hostnames, which are the parents of the param
sub get_host_parent {
    shift;
    return StorProc->get_host_parent(@_);
}

## @fn
# Returns a list of all hostnames which are parent on any other host
# @return Array of hostnames, which are parent
sub get_parents {
    shift;
    return StorProc->get_parents(@_);
}

sub get_table_objects {
    shift;
    return StorProc->get_table_objects(@_);
}

sub get_service_hosts {
    shift;
    return StorProc->get_service_hosts(@_);
}

# pre_flight_check() has no interlocking with feeders.
sub pre_flight_check {
    shift;
    my @results = (
	"monarchWrapper->pre_flight_check() is now obsolete.",
	"Use monarchWrapper->synchronized_preflight() instead.",
	"Note that the arguments to synchronized_preflight() are much more complex."
    );
    return @results;
}

sub synchronized_preflight {
    shift;
    return StorProc->synchronized_preflight(@_);
}

# commit() has no interlocking with feeders.
sub commit {
    shift;
    my @results = (
	"monarchWrapper->commit() is now obsolete.",
	"Use monarchWrapper->synchronized_commit() instead.",
	"Note that the arguments to synchronized_commit() are much more complex."
    );
    return @results;
}

sub synchronized_commit {
    shift;
    return StorProc->synchronized_commit(@_);
}

=pod

=item disconnect()

This function disconnects from the monarch database.

=cut

sub disconnect {
    shift;
    return StorProc->dbdisconnect(@_);
}

sub search {
    shift;
    return StorProc->search(@_);
}

sub search_service {
    shift;
    return StorProc->search_service(@_);
}

sub get_group_orphans {
    shift;
    return StorProc->get_group_orphans(@_);
}

# --------------------------------
# subs from other package files
# --------------------------------

sub import_host {
    shift;
    return Import->import_host(@_);
}

sub rewrite_nagios_cfg {
    shift;
    return Files->rewrite_nagios_cfg(@_);
}

sub copy_files {
    shift;
    return Files->copy_files(@_);
}

sub build_files {
    shift;
    return Files->build_files(@_);
}

sub deploy {
    shift;
    return Deploy->deploy(@_);
}

## @method (arrayref, arrayref) build_all_externals (string user_acct, string session_id, boolean via_web_ui)
# Runs the build_all_externals routine in MonarchExternals.pm
# @param user_acct Name of the user which is generating the externals
# @param session_id Session ID for the user session
# @param via_web_ui boolean flag, true if being executed in an HTML-display context
# @param force (true means force regeneration even if there is no significant change in content)
# @return refs to results array and errors array
sub build_all_externals {
    shift;
    return Externals->build_all_externals(@_);
}

## @method (arrayref, arrayref) build_some_externals (string user_acct, string session_id, boolean via_web_ui, arrayref hostsref, boolean force)
# Runs the build_some_externals routine in MonarchExternals.pm
# @param user_acct Name of the user which is generating the externals
# @param session_id Session ID for the user session
# @param via_web_ui boolean flag, true if being executed in an HTML-display context
# @param hostsref undefined, for all hosts; ref to an array of hostnames, for particular hosts
# @param force true means force regeneration even if there is no significant change in content
# @return refs to results array and errors array
sub build_some_externals {
    shift;
    return Externals->build_some_externals(@_);
}

## @method array import_host_api (hashref host)
# Runs the import_host routine in MonarchAPI.pm
# @param host details of the host to import, along with import-command metadata
# @return results array, which may contain errors
sub import_host_api {
    shift;
    return API->import_host(@_);
}

1;
