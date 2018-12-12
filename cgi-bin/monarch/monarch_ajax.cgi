#!/usr/local/groundwork/perl/bin/perl --
# MonArch - Groundwork Monitor Architect
# monarch_ajax.cgi
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

use lib qq(/usr/local/groundwork/core/monarch/lib);
use strict;
use CGI;
use MonarchStorProc;

my $query = new CGI();

# Adapt to an upgraded CGI package while still maintaining backward compatibility.
my $multi_param = $query->can('multi_param') ? 'multi_param' : 'param';

my @input = $query->$multi_param('args');
my $debug = 0;

if ($debug) {
    my $now = time;
    open( FILE, '>>', '/tmp/debug.log' );
    print FILE "==============================\n$now\n";
    print FILE "arg 0 $input[0]\n";
    print FILE "arg 1 $input[1]\n";
    print FILE "arg 2 $input[2]\n";
    print FILE "arg 3 $input[3]\n";
    print FILE "arg 4 $input[4]\n";
    print FILE "arg 5 $input[5]\n";
}

sub get_hosts {
    use MonarchForms;
    my $connect     = StorProc->dbconnect();
    my $num_hosts   = 0;
    my %hosts       = ();
    my $max_to_show = 25;
    if ( $input[0] =~ /\S/ ) {
	$num_hosts = StorProc->count_match( 'hosts', $input[0] );
	%hosts = StorProc->search( $input[0], $max_to_show );
    }
    my $num_more = $num_hosts - $max_to_show;
    $num_more = 0 if ( $num_more < 0 );
    my $detail = Forms->search_results( \%hosts, $input[1], '', $num_more );
    my $result = StorProc->dbdisconnect();
    print $detail . '|' . $input[0];
}

sub get_ez {
    use MonarchForms;
    my $connect = StorProc->dbconnect();
    my %hosts   = ();
    if ( $input[1] =~ /\S/ ) { %hosts = StorProc->search( $input[1], -1 ) }
    my $detail = Forms->search_results( \%hosts, $input[2], 'ez' );
    my $result = StorProc->dbdisconnect();
    print $detail . '|' . $input[1];
}

sub get_services {
    use MonarchForms;
    my $connect      = StorProc->dbconnect();
    my $num_services = 0;
    my %services     = ();
    my $max_to_show  = 25;
    if ( $input[1] =~ /\S/ ) {
	$num_services = StorProc->count_match( 'service_names', $input[1] );
	%services = StorProc->search_service( $input[1], $max_to_show );
    }
    my $num_more = $num_services - $max_to_show;
    $num_more = 0 if ( $num_more < 0 );
    my $detail = Forms->search_results( \%services, $input[2], 'service', $num_more );
    my $result = StorProc->dbdisconnect();
    print $detail . '|' . $input[1];
}

sub get_commands {
    use MonarchForms;
    my $connect      = StorProc->dbconnect();
    my $num_commands = 0;
    my %commands     = ();
    my $max_to_show  = 25;
    if ( $input[1] =~ /\S/ ) {
	$num_commands = StorProc->count_match( 'commands', $input[1] );
	%commands = StorProc->search_command( $input[1], $max_to_show );
    }
    my $num_more = $num_commands - $max_to_show;
    $num_more = 0 if ( $num_more < 0 );
    my $detail = Forms->search_results( \%commands, $input[2], 'command', $num_more );
    my $result = StorProc->dbdisconnect();
    print $detail . '|' . $input[1];
}

sub get_externals {
    use MonarchForms;
    my $connect       = StorProc->dbconnect();
    my $num_externals = 0;
    my %externals     = ();
    my $max_to_show   = 25;
    if ( $input[2] =~ /\S/ ) {
	$num_externals = StorProc->count_match( 'externals', $input[2], $input[1] );
	%externals = StorProc->search_external( $input[2], $input[1], $max_to_show );
    }
    my $num_more = $num_externals - $max_to_show;
    $num_more = 0 if ( $num_more < 0 );
    my $detail = Forms->search_results( \%externals, $input[3], "$input[1]_external", $num_more );
    my $result = StorProc->dbdisconnect();
    print $detail . '|' . $input[2];
}

sub process_import {
    my $connect = StorProc->dbconnect();
    use MonarchForms;
    use MonarchLoad;
    my @results = ();
    if ( $input[1] eq 'end' ) {
	my $dt = StorProc->datetime();
	@results = ("$dt~~completed~~Import process ends.");
    }
    elsif ( $input[1] eq 'process_service_escalations' ) {
	@results = Load->process_service_escalations();
	print FILE "$input[1]\n" if $debug;
    }
    elsif ( $input[1] eq 'process_host_escalations' ) {
	@results = Load->process_host_escalations();
	print FILE "$input[1]\n" if $debug;
    }
    elsif ( $input[1] eq 'services' ) {
	@results = Load->process_services();
	print FILE "$input[1]\n" if $debug;
    }
    elsif ( $input[1] eq 'hosts' ) {
	@results = Load->process_hosts();
	print FILE "$input[1]\n" if $debug;
    }
    elsif ( $input[1] eq 'contacts' ) {
	@results = Load->process_contacts();
	print FILE "$input[1]\n" if $debug;
    }
    elsif ( $input[1] eq 'timeperiods' ) {
	@results = Load->process_timeperiods();
	print FILE "$input[1]\n" if $debug;
    }
    elsif ( $input[1] eq 'commands' ) {
	@results = Load->process_commands();
	print FILE "$input[1]\n" if $debug;
    }
    elsif ( $input[1] eq 'stage' ) {
	@results = Load->stage_load( $input[2], $input[3], $input[5] );
	print FILE "$input[1]\n" if $debug;
	print FILE "$input[2]\n" if $debug;
	print FILE "$input[3]\n" if $debug;
	print FILE "$input[5]\n" if $debug;
    }
    elsif ( $input[1] eq 'purge' ) {
	print FILE "$input[1]\n" if $debug;
	print FILE "$input[3]\n" if $debug;
	print FILE "$input[4]\n" if $debug;
	StorProc->purge( $input[3], $input[4] );
	my $dt      = StorProc->datetime();
	my $message = "Preparing stage";
	if ( $input[3] eq 'update' && $input[4] ) {
	    $message .= " - purging escalations.";
	}
	elsif ( $input[3] eq 'update' ) {
	    $message .= " for update.";
	}
	elsif ( $input[3] eq 'purge_all' ) {
	    $message .= " - purging all.";
	}
	elsif ( $input[3] eq 'purge_all_and_import_3x' ) {    # was 'import_3x'
	    $message .= " - importing from Nagios 3.x files.";
	}
	else {
	    $message .= " - purging service related objects.";
	}
	@results = ("$dt~~setup~~$message");
    }
    my $result_str = join( '|', @results );
    print FILE "$result_str\n" if $debug;
    print "Content-type: text/html \n\n";
    print $result_str;
    my $result = StorProc->dbdisconnect();
}

if ( $input[0] eq 'service' ) {
    &get_services;
}
elsif ( $input[0] eq 'command' ) {
    &get_commands;
}
elsif ( $input[0] eq 'external' ) {
    &get_externals;
}
elsif ( $input[0] eq 'process_import' ) {
    &process_import;
}
elsif ( $input[0] eq 'ez' ) {
    &get_ez;
}
else {
    &get_hosts;
}

close FILE if $debug;
