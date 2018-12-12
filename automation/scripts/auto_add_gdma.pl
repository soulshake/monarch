#!/usr/local/groundwork/perl/bin/perl
#
# Copyright 2009-2012 GroundWork Open Source, Inc. (GroundWork)
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
# auto_add_gdma.pl
#
# Script that can be run regularly via cron, or manually, to import hosts into
# Monarch using the Configuration API available in GroundWork Monitor 6.0 and higher.
#
# Change log:
#
# 2009-11-18	v0.1	Initial version.  Tested against GroundWork Monitor Enterprise 6.0
# 2010-06-15	v0.2	Fixed so it removes input file after processing.
#			Avoids unlimited growth of file in production.
# 2012-01-12	v0.3	Do not overwrite hosts that already exist in monarch.
# 2012-06-16	v0.4	Reformatted source code so it's understandable.
#			Build externals only for imported hosts, not for all hosts.

# TO DO:
# (*) 2012-01-12 KDS:	Send output to gdma-autohost service rather than STDOUT.
# (*) 2012-01-12 KDS:	Read parameters from gdma_auto.config (what parameters?).
# (*) 2012-01-12 KDS:	Reformat to use main() and subfunctions (but not much point in
#			such a short linear script, as long as it's written cleanly).

BEGIN {
    unshift @INC, "/usr/local/groundwork/core/monarch/lib";
}
use strict;
use dassmonarch;

# BE SURE TO KEEP $version UP TO DATE!
my $version  = "0.4";
my $PROGNAME = "auto_add_gdma.pl";
my $debug    = 0;

# This flag specifies whether hosts which already exist in Monarch will be updated by this script.
# There is no need to check them individually beforehand to see if they already exist.
my $update_existing_hosts = 0;

use Getopt::Long;
use Time::HiRes;
use vars qw($opt_d $opt_f $opt_v);

my $start_time = Time::HiRes::time();

Getopt::Long::Configure('bundling');
my $status = GetOptions( "d=s" => \$opt_d, "debug=s" => \$opt_d, "v" => \$opt_v, "version" => \$opt_v, "f=s" => \$opt_f, "file=s" => \$opt_f );

if ( !$opt_f && !$opt_v ) {
    print "Usage: $PROGNAME [-d|--debug <#>] [-v|--version] -f|--file <FILENAME>
    where <#> is 0 or higher.  Set <#> to 2 or higher for file processing and
    Configuration API messages.\n";
    exit 0;
}

if ($opt_v) {
    print "Version: $PROGNAME $version\n";
    exit 0;
}

if ($opt_d) {
    $debug = $opt_d;
}

# Read the input file
open( DATA, '<', $opt_f ) or die("Error: Unable to read file $opt_f\n");

my $host_hashref = {};

if ( $debug > 1 ) {
    print "debug: processing file $opt_f\n";
}
while ( my $line = <DATA> ) {
    ## Format of file is
    ## host name \t host address \t host alias \t host profile name \t monarch group name
    chomp $line;
    my ( $hostname, $hostaddress, $hostalias, $hostprofile, $monarchgroup ) = split( /\t/, $line );
    $host_hashref->{$hostname}->{hostaddress}  = $hostaddress;
    $host_hashref->{$hostname}->{hostalias}    = $hostalias;
    $host_hashref->{$hostname}->{hostprofile}  = $hostprofile;
    $host_hashref->{$hostname}->{monarchgroup} = $monarchgroup;

    if ( $debug > 1 ) {
	print "debug:   file entry - $line\n";
    }
}
close(DATA);
unlink($opt_f);

# Construct an instance of class dassmonarch
my $monarchapi = dassmonarch->new();

# Set this to error, in order to get minimal debug messages, verbose creates a lot of output
if ( $debug > 1 ) {
    print "debug: submitting hosts to Monarch\n";
    $monarchapi->set_debuglevel('verbose');
}
else {
    $monarchapi->set_debuglevel('none');
}

my @imported_hosts = ();
foreach my $hostname ( keys %{$host_hashref} ) {
    my $result = $monarchapi->import_host_api(
	$hostname,
	$host_hashref->{$hostname}->{hostalias},
	$host_hashref->{$hostname}->{hostaddress},
	$host_hashref->{$hostname}->{hostprofile},
	$update_existing_hosts
    );
    if ( !$result ) {
	print "debug:   import_host exception for host $hostname\n" if $debug > 1;
    }
    else {
	push @imported_hosts, $hostname;

	# Now need to add the host to a relevant monarch group (if defined).
	# This (what?  defining a new group?) needs to be a new function in dassmonarch.
	if ( $host_hashref->{$hostname}->{monarchgroup} ) {
	    if ( !$monarchapi->monarch_group_exists( $host_hashref->{$hostname}->{monarchgroup} ) ) {
		print "debug:  Group $host_hashref->{$hostname}->{monarchgroup} does not exist.\n" if $debug > 1;
	    }
	    elsif ( !$monarchapi->assign_monarch_group_host( $host_hashref->{$hostname}->{monarchgroup}, $hostname ) ) {
		print "debug:  Failed to add host $hostname to group $host_hashref->{$hostname}->{monarchgroup}\n" if $debug > 1;
	    }
	}
    }
}

# Build externals files ONLY for the hosts we just imported.  These files
# should contain only externals inherited via their applied host profiles.
if (@imported_hosts) {
    my $result = $monarchapi->buildSomeExternals( \@imported_hosts );
    if ( !$result && $debug > 1 ) {
	print "debug:   buildSomeExternals exception.\n";
    }
}

# Finish with summary statistics
if ($debug) {
    my $hosts = keys %{$host_hashref};
    print "debug: completed processing of " 
      . $hosts
      . " host records in "
      . sprintf( '%0.3f', ( Time::HiRes::time() - $start_time ) )
      . " seconds.\n";
}

exit 0;
