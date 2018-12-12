#!/usr/bin/perl --
# MonArch - Groundwork Monitor Architect
# monarch_scan.cgi
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
use Nmap::Scanner;
use MonarchStorProc;

sub get_hosts {
    my $query = new CGI();

    # Adapt to an upgraded CGI package while still maintaining backward compatibility.
    my $multi_param = $query->can('multi_param') ? 'multi_param' : 'param';

    my @input = $query->$multi_param('args');
    unless ( $input[0] ) {
	$input[0] = '/tmp/monarch_discover_test.tmp';
	$input[1] = '172.28.113.209';
	$input[2] = '/usr/local/groundwork/monarch';
    }
    my $ret_info = '';
    my $data = undef;
    if (not $data = qx($input[2]/bin/nmap_scan_one $input[1])) {
	$ret_info = "Error(s) executing $input[2]/bin/nmap_scan_one $input[1] ($!)";
    }
    else {
	my %host_info = StorProc->process_nmap($data);
	if (defined $host_info{'errors'}) {
	    # Could be more, but for now we just print the first one.
	    $ret_info = "Error(s) parsing \"$input[2]/bin/nmap_scan_one $input[1]\" output: $host_info{'errors'}[0]";
	}
	else {
	    unless ( $host_info{'status'} eq 'up' ) { $host_info{'status'} = 'down (no response from host)' }
	    if (not open( FILE, '>>', $input[0] )) {
		$ret_info = "$!| $input[0]";
	    }
	    else {
		$ret_info = "$host_info{'name'}|$host_info{'alias'}|$input[1]|$host_info{'os'}|$host_info{'status'}";
		print FILE  "$host_info{'name'},$host_info{'alias'},$input[1],$host_info{'os'},$host_info{'status'}\n";
		close FILE;
	    }
	}
    }
    print "Content-type: text/html \n\n";
    print $ret_info;
}

&get_hosts;
