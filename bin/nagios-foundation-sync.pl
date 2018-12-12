#!/usr/bin/perl --

############################################################################
# Release 4.6
# October 2017
############################################################################
#
# Copyright (c) 2008-2017 Groundwork Open Source, Inc. (GroundWork)
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
## use warnings;

use lib qq(/usr/local/groundwork/monarch/lib);
use MonarchFoundationSync;

# The numeric timestamp must represent a moment in time before Nagios was
# restarted, to correctly timestamp events generated during the sync.
my $usage = "usage:  $0 {group_name} {numeric_timestamp}\n";

die $usage if @ARGV != 2;

my $group_name       = shift;
my $pre_restart_time = shift;

die $usage if $pre_restart_time !~ /^\d+$/;

my $monarch_home = '/usr/local/groundwork/monarch';

# Re-open the STDERR stream as a duplicate of the STDOUT stream, to properly
# interleave any output written to STDERR (from, say, debug messages).
if ( !open( STDERR, '>>&STDOUT' ) ) {
    print "ERROR:  Can't redirect STDERR to STDOUT: $!\n";
}
else {
    ## Autoflush the error output on every single write, to avoid problems
    ## with block i/o and badly interleaved output lines on STDOUT and STDERR.
    STDERR->autoflush(1);
}

if (1) {
    my $result = FoundationSync->sync_group( $group_name, $pre_restart_time );
    $result =~ s/<br>/\n/g;
    chomp $result;
    print "$result\n";
}
else {
    ## Legacy operation, now deprecated.
    print FoundationSync->sync_group($group_name);
}

