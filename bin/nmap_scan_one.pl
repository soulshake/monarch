#!/usr/bin/perl -w --

############################################################################
# Release 4.5
# November 2016
############################################################################
#
# Original author: Scott Parris
#
# Copyright (C) 2007-2016 Groundwork Open Source, Inc. (GroundWork)
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
use warnings;

use Nmap::Scanner;

# Become a process group leader, so we can easily terminate all of our descendants.
setpgrp(0,0);

sub kill_process_group {
    kill 'TERM', -$$;
}

sub terminate {
    exit 15;
}

sub show_context {
    my $message = shift;
    print STDERR $message;
    ## Start with the caller's caller.
    my $i = 0;
    while ( my ( $package, $file, $line, $subroutine ) = caller( $i++ ) ) {
	print STDERR "    [in file $file line $line, sub $subroutine]\n";
	last if $file !~ /\(eval/;
    }
}

# The SIGHUP processing mirrors what the system should be doing should we
# end up as an orphaned process group -- effectively, trying to terminate
# the entire group, so it doesn't outlast the process that spawned us.
# But this lets us do the same thing in a simple manner even when the
# process group has not yet been orphaned.

# Doing the same with SIGCONT is an abuse of the signal, but we use it
# because it's the only signal we can send from our parent process,
# given that we will be running setuid.

$SIG{HUP}      = \&kill_process_group;
$SIG{CONT}     = \&kill_process_group;
$SIG{TERM}     = \&terminate;

## This next line may be uncommented to print the call stack (to the STDERR
## stream, so as not to interfere with the normal output of this program) when a
## warning is generated.  However, if the warning is from inside the Nmap::Scanner
## package, the extra output may be only generally indicative, not definitive,
## because of the way that module uses indirect evaluation of as_xml() calls.
# $SIG{__WARN__} = \&show_context;

sub print_usage {
    print "usage:  $0 {IPv4 address, hostname, or scan specification}\n";
    print "where:  A scan specification is of the following form:\n";
    print "        host:-:scan_type:-:timeout:-:ports\n";
}

if ( scalar @ARGV != 1 ) {
    print_usage();
    exit 1;
}

my $args             = $ARGV[0];
my $got_ipv4_address = ( $args =~ /^\d+\.\d+\.\d+\.\d+$/ );
my $got_hostname     = is_valid_dns_hostname($args);
my @args             = split( /:-:/, $args );

# NOTE:  The Perl Nmap::Scanner package needs an extension to pass
# the "-6" flag to nmap before we can support IPv6 addresses here.

if ( $got_ipv4_address || $got_hostname ) {
    # This form is not used by present automation, but can be run from the
    # command line to show the basic data that nmap produces for a given host.
    my $scanner = new Nmap::Scanner;
    $scanner->tcp_syn_scan();
    $scanner->add_scan_port('21,25,80,443,3306,8080,22,79,13,11,7,10');
    $scanner->guess_os();
    $scanner->add_target($args);
    ## nmap now has a default unit of seconds for --max-rtt-timeout,
    ## and it won't take 200 seconds as a legitimate value, so we
    ## must now explicitly specify the units we want.
    $scanner->max_rtt_timeout('200ms');
    my $results = $scanner->scan();
    my $data = $results->as_xml();
    print $data;
}
elsif (@args == 4) {
    # This form is used by Auto-Discovery.
    # args = host:-:scan_type:-:timeout:-:ports
    my $scanner = new Nmap::Scanner;
    if ($args[1] eq 'udp_scan') {
	$scanner->udp_scan();
    } elsif ($args[1] eq 'tcp_connect_scan') {
	$scanner->tcp_connect_scan();
    } else {
	$scanner->tcp_syn_scan();
    }
    if ($args[2] eq 'Insane') {
	$scanner->insane_timing();
    } elsif ($args[2] eq 'Sneaky') {
	$scanner->sneaky_timing();
    } elsif ($args[2] eq 'Paranoid') {
	$scanner->paranoid_timing();
    } elsif ($args[2] eq 'Polite') {
	$scanner->polite_timing();
    } elsif ($args[2] eq 'Aggressive') {
	$scanner->aggressive_timing();
    } else {
	$scanner->normal_timing();
    }
    $scanner->add_scan_port($args[3]);
    $scanner->guess_os();
    $scanner->add_target($args[0]);
    my $results = $scanner->scan();
    my $data = $results->as_xml();
    print $data;
}
else {
    print_usage();
    exit 1;
}

sub is_valid_dns_hostname {
    my $hostname = $_[0];

    # See http://en.wikipedia.org/wiki/Hostname#Restrictions_on_valid_host_names for the tests we run here.
    my $label = '(?:[a-zA-Z0-9](?:[-a-zA-Z0-9]{0,61}[a-zA-Z0-9])?)';
    return ( defined($hostname) and $hostname ne '' and length($hostname) <= 255 and $hostname =~ /^$label(?:\.$label)*$/o );
}

