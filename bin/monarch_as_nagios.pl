#!/usr/bin/perl -w --
# MonArch - Groundwork Monitor Architect
# monarch_as_nagios.pl
#
############################################################################
# Release 3.1
# November 2009
############################################################################
#
# Original author: Scott Parris
#
# Copyright (C) 2007-2009 Groundwork Open Source, Inc. (GroundWork)
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

$ENV{'PATH'} = '/bin:/usr/bin';

my $cmdfile = $ARGV[0];
my $whoami  = qx(whoami);
my $res     = undef;

if ( scalar @ARGV != 1 ) {
    print "usage:  $0 {command_file}\n";
    exit 1;
}

if ( !open (FILE, '<', $cmdfile) ) {
    print "Cannot open $cmdfile for reading ($!)\n";
    exit 1;
}

my $command = <FILE>;
close FILE;

if ($command =~ /(.+)/) { $command = $1 } # untaints data read from file
if ($whoami  =~ /(.+)/) { $whoami  = $1 } # untaints data read from file

$res = qx($command 2>&1) || "Error(s) executing '$command' ($!)";
$res .= " - $whoami\n";
print $res;
