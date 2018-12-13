# MonArch - Groundwork Monitor Architect
# MonarchGraphs.pm
#
############################################################################
# Release 4.5
# August 2016
############################################################################
#
# Original author: Glenn Herteg
#
# Copyright 2009-2016 GroundWork Open Source, Inc. (GroundWork)
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
# use warnings;

package Graphs;

use POSIX;
use RRDs;

sub graph_commit {
    my $time_ref  = $_[1];
    my @phases    = ();
    my $min_start = 2**32;
    my $max_end   = 0;
    my $rrd_steps = 0;
    my $timespan  = 0;
    my @errors    = ();
    my $print_ref;
    my $graph_x;
    my $graph_y;
    local $_;

    foreach my $phase (@$time_ref) {
	if ( $phase =~ /Phase:\s+(.*) took ([\d.]+) seconds.*\[([\d.]+)\s*\.\.\s*([\d.]+)\]/ ) {
	    my $name     = $1;
	    my $interval = $2;
	    my $start    = $3;
	    my $end      = $4;
	    $name =~ s/,$//;
	    $name = sprintf( "%7.3f sec\\:  %s", $interval, $name );
	    $min_start = $start if $start < $min_start;
	    $max_end   = $end   if $end   > $max_end;
	    push @phases, [$name, $interval, $start, $end];
	}
    }
    $timespan  = sprintf( "%.3f", $max_end - $min_start );
    $min_start = int ($min_start) - 1;
    $max_end   = int ($max_end)   + 1;
    $rrd_steps = $max_end - $min_start + 1;

    # Sort @phases by the earlier start time; and if equal, then by the longest interval;
    # and if still equal, somewhat arbitrarily by the name.
    my @periods = sort { $$a[2] <=> $$b[2] || $$b[1] <=> $$a[1] || $$a[0] cmp $$b[0] } @phases;

    my $commit_rrd          = 'commit.rrd';
    my $internal_image_path = '/usr/local/nagios/share/images/commit.png';
    my $external_image_path = '/nagios/images/commit.png';

    # FIX FUTURE:  Change the image paths to the apache2/htdocs/ directory?
    # my $internal_image_path = '/usr/local/groundwork/apache2/htdocs/commit.png';
    # my $external_image_path = '/commit.png';

    # Simple cache buster.
    $external_image_path .= '?time=' . time;

    my @command_args = ();
    my $rrd_start = $min_start - 1;
    push @command_args, $commit_rrd;
    push @command_args, "--start=$rrd_start";
    push @command_args, "--step=1";
    for (my $i = 0; $i < @periods; ++$i) {
	push @command_args, "DS:period_$i:GAUGE:2:0:U";
    }
    push @command_args, "RRA:MAX:0.5:1:$rrd_steps";
    RRDs::create(@command_args);
    my $ERR = RRDs::error;
    if ($ERR) {
	push @errors, "Error:  Failed RRD create command: $ERR";
    }
    unless (@errors) {
	@command_args = ();
	push @command_args, $commit_rrd;
	for (my $moment = $min_start; $moment <= $max_end; ++$moment) {
	    my @data = ();
	    foreach my $period (@periods) {
		push @data, ($$period[2] <= $moment && $moment <= $$period[3]) ? '1' : '0';
	    }
	    push @command_args, join( ':', $moment, @data);
	}
	RRDs::update(@command_args);
	my $ERR = RRDs::error;
	if ($ERR) {
	    push @errors, "Error:  Failed RRD update command: $ERR";
	}
    }
    unless (@errors) {
	my $max_height = @periods;
	my $min_height = $max_height;
	my @height     = ($max_height) x @periods;

	# make the height depend on how many later phases start before this one ends
	for (my $i = 0; $i < @periods; ++$i) {
	    my $end_i = $periods[$i][3];
	    for (my $j = $i + 1; $j < @periods; ++$j) {
		last if $periods[$j][2] >= $end_i;
		$end_i = $periods[$j][3] if $periods[$j][3] > $end_i;
		$height[$j] = $height[$i] - 1;
		$min_height = $height[$j] if $height[$j] < $min_height;
	    }
	}
	# make adjustments to bring the heights up to the maximal values possible
	--$min_height;
	for (@height) {
	    $_ -= $min_height;
	}

	my @colors = (
	    'ABCDEF', 'FEDCBA', 'FF00FF', 'BAFEDC', 'FFBB00', 'FF0000', 'DCBAFE', 'FFFF00',
	    '555555', 'BBFF00', '5555FF', '00FF00', 'EFABCD', '00FFFF', 'CDEFAB', 'CBA987',
	    'CCCCCC', '87CBA9', '000000', 'A987CB', 'B03060', '3060B0', 'FFDAB9', '60B030',
	    'CD5C5C', '87CEEB', 'B06030', '888888', '00FF7F', '6030B0', 'F09060'
	);

	require Sys::Hostname;
	my $hostname = Sys::Hostname::hostname();
	$hostname =~ s/\..*//;

	# FIX FUTURE:  Overlay this commit-phase graph with lines representing the CPU and disk load
	# from various system components:  monarch.cgi, java (Foundation), nagios and all
	# its child processes (summarized), nagios2collage_socket.pl, nagios2collage_eventlog,pl,
	# overall system load, etc.  Or create a companion graph, if complexity and/or color conflict
	# becomes an issue.

	@command_args = ();
	push @command_args, $internal_image_path;
	push @command_args, "--start=$min_start";
	push @command_args, "--end=$max_end";
	push @command_args, "--title=Nagios/Foundation Commit Phase Timing ($timespan seconds) on $hostname";
	push @command_args, "--vertical-label=Parallel Phases";
	push @command_args, "--y-grid=none";
	push @command_args, "--width=600";
	push @command_args, "--height=120";
	push @command_args, "--lower-limit=0";
	for (my $i = 0; $i < @periods; ++$i) {
	    my $name  = $periods[$i][0];
	    my $color = $colors[$i % @colors];
	    push @command_args, "DEF:period_$i=$commit_rrd:period_$i:MAX";
	    push @command_args, "CDEF:area_$i=period_$i,$height[$i],*";
	    push @command_args, "AREA:area_$i#$color:$name\\l";
	}
	my $timestamp_format = '%A, %B %e, %Y at %H\:%M\:%S %Z\c';
	(my $graph_end_time = strftime( $timestamp_format, localtime($max_end) )) =~ s/\s+/ /g;
	push @command_args, "COMMENT:$graph_end_time";
	($print_ref, $graph_x, $graph_y) = RRDs::graph(@command_args);
	$ERR = RRDs::error;
	if ($ERR) {
	    push @errors, "Error:  Failed RRD graph command: $ERR";
	    ## If you really need to know failure details ...
	    ## push @errors, @command_args;
	}
    }

    @$time_ref = grep !/^Phase:/, @$time_ref;
    grep s/\s*\[[\d.]+\s*\.\.\s*[\d.]+\]//, @$time_ref;
    $external_image_path = undef if (@errors);
    return \@errors, $external_image_path, $graph_x, $graph_y, $time_ref;
}

1;
