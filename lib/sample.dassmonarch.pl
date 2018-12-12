#!/usr/local/groundwork/perl/bin/perl -w --
## @file
## A simple sample application for dassmonarch Perl-API to GroundWork's Monarch.
## This is not for the SOAP interface, it's only for the local class.
## @brief Sample for dassmonarch usage; this is in no way suitable for copying
## and production use, as it does not include any form of error checking logic
## to control the script execution.
## @author Maik Aussendorf
# \$Id: sample.dassmonarch.pl 37 2012-06-13 14:24:07Z gherteg $
# Copyright (c) 2007-2012
# Maik Aussendorf <maik.aussendorf@dass-it.de> dass IT GmbH
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

BEGIN {
    unshift @INC, '/usr/local/groundwork/core/monarch/lib';
}

use strict;

# Issue an error, if run as root.
if ( $< == 0 ) {
    print
	"\n",
	"ERROR: You have run this script as user root.\n",
	"That could create some files with the wrong permissions after a commit.\n",
	"Run this script as user nagios instead.\n",
	"\n";
    #	"You may want to run the following commands to clean this up:\n",
    #	"    chown -R nagios.nagios /usr/local/groundwork/nagios/etc/\n",
    #	"    chown -R nagios.nagios /usr/local/groundwork/core/monarch/workspace/\n",
    exit (1);
}

# use the dassmonarch API
use dassmonarch;

# Construct an instance of class dassmonarch
my $monarchapi = dassmonarch->new();

# set this to error, in order to get minimal debug messages, verbose creates a lot of output
$monarchapi->set_debuglevel('verbose');

#$monarchapi->set_debuglevel('info');

# create a new host with name 'myhost', alias 'my alias', IP 10.10.20.3, hostprofile
# 'host-profile-service-ping'.  1 means, update host information, if the host already
# exists.  You must have a hostprofile with name 'host-profile-service-ping' before
# making the call shown here.  The import_host_api() routine will perform a deep copy of
# the host profile onto the host (including host template and host template overrides;
# hostgroups, contact groups, service profiles, parents, and host externals associated
# with the host profile; all the services associated with those service profiles; and
# the templates and template overrides, service groups, contactgroups, and service
# externals, if any, associated with those services).
$monarchapi->import_host_api( 'myhost', 'my alias', '10.10.20.3', 'host-profile-service-ping', 1 );

# create an array (with one element in this case) of parents
my @parents = ('localhost');

# set parents to all names in array @parents
$monarchapi->set_parents( 'myhost', \@parents );

# Assign host to hostgroup 'Linux Servers'
$monarchapi->assign_hostgroup( 'myhost', 'Linux Servers' );

# add service 'tcp_ssh' to host 'myhost'
$monarchapi->add_service( 'myhost', 'tcp_ssh' );

# Assign certain hostgroups to a Monarch group
$monarchapi->assign_monarch_group_hostgroups('unix-gdma-2.1', ['Linux Servers']);

# Assign certain hosts to a Monarch group
$monarchapi->assign_monarch_group_hosts('unix-gdma-2.1', ['myhost']);

# Assign certain Monarch groups as subgroups to a Monarch group
$monarchapi->assign_monarch_group_subgroups('unix-gdma-2.1', ['windows-gdma-2.1']);

# do a preflight check
$monarchapi->pre_flight_check();

# commit, but only if implied preflight check is ok.
# (It is not necessary to perform a separate preflight check beforehand; the call
# you see above is simply for purposes of illustration, for when you want to
# implement a dry-run option in your script.)
# We have this call commented out so you don't accidentally do a commit on a
# production system (although that won't stop all the commands above from
# operating as designed).
# $monarchapi->generateAndCommit( "Created myhost, adjusted various attributes of that host,\nand modified the unix-gdma-2.1 Monarch group.", 0 );

