#!/usr/local/groundwork/perl/bin/perl -w --
#
#       gdma_auto v5.0    2012-06-24
#
#       Copyright 2008-2012 GroundWork Open Source, Inc. ("GroundWork")
#       All rights reserved. Use is subject to GroundWork commercial license terms.
#       http://www.groundworkopensource.com
#
#       Unless required by applicable law or agreed to in writing, software
#       distributed under the License is distributed on an "AS IS" BASIS,
#       WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#       See the License for the specific language governing permissions and
#       limitations under the License.
#

# Changelog:
#
# 2009-11-18	Kevin Stone
#		Initial Release
#
# 2010-06-15	Thomas Stocking
#		Fixed parsing to not use the whole log, and to look for SERVICE ALERT,
#		not passive check received messages.
#
# 2011-12-16	Kevin Stone
#		Added solaris 2.8 fingerprint.
#
# 2012-06-16	GH
#		Source code reformatted for clarity.  uniq() routine redone.
#		Seek file overhauled to detect a rolled input file.
#		Cleaned up handling of OS fingerprints.
#		Merged fingerprints from different script versions.
#
# 2012-06-24	GH
#		Fix a file descriptor problem.

use strict;
use Getopt::Std;

my %opt       = ();
my $debug     = 0;
my $logfile   = "/usr/local/groundwork/nagios/var/nagios.log";
my $output    = "/usr/local/groundwork/core/monarch/automation/data/gdma_auto.txt";
my $seek_file = "/usr/local/groundwork/core/monarch/automation/data/nagios.log.seek";

# Entries in the following array are specified as:
#     string;host_profile;monarch_group
# where the string is interpreted as the content of a regular expression (not just
# literal characters) which is matched against the incoming OS information.
# Note especially the matching of "."; we use \Q...\E to quote, for simplicity.
# The incoming data is matched against the entries in order,
# so put more specific matches first, as the first match wins.
my @os_list = (
    "\QMSWin32 5.00\E;gdma-21-windows-host;windows-gdma-2.1",
    "MSWin32;gdma-21-windows-host;windows-gdma-2.1",
    # "MSWin32;host-profile-gdma-win;gdma",
    "aix;host-profile-gdma-aix;gdma",
    "\Qlinux 2.6.9-42.0.3.elsmp\E;gdma-21-linux-host;unix-gdma-2.1",
    "linux;gdma-21-linux-host;unix-gdma-2.1",
    # "linux;host-profile-gdma-linux;gdma",
    "solaris;host-profile-gdma-sun;gdma"
);

&main;

sub main {
    &initoptions();
    my ( $group, @result, $rec, $profile, $ip, $hostname, @hostrec, $hostspec, $os_string, @list, @line, @words, @ossplit ) = ();
    my $ahost    = "gdma-autohost";
    my $aservice = "gdma_auto";
    $ahost    = $opt{H} if defined( $opt{H} );
    $aservice = $opt{S} if defined( $opt{S} );
    $debug    = $opt{d};

    my @file = breakfile($logfile);
    foreach (@file) {
	unless ( $_ =~ m/$ahost;$aservice/ )      { next }
	unless ( $_ =~ m/SERVICE ALERT/ )         { next }
	unless ( $_ =~ m/No configuration file/ ) { next }
	@words = split( /No configuration file.*?:/, $_ );
	push( @list, $words[1] );
    }
    @list = uniq( \@list );

    # Input (physical):
    # 2000pro [192.168.11.72] running MSWin32 5.00
    # standby-60 [192.168.11.212] running linux 2.6.9-42.0.3.elsmp

    # Output (logical):
    # host name, host address, host alias, host profile, monarch group

    foreach (@list) {
	@ossplit   = split( /\ running\ /, $_ );
	$hostspec  = $ossplit[0];
	$os_string = $ossplit[1];
	@hostrec   = split( /\[/, $hostspec );
	$hostname  = $hostrec[0];
	$hostname =~ s/\s//g;
	$ip = $hostrec[1];
	$ip =~ s/]//g;
	( $profile, $group ) = getprofile($os_string);

	if ( defined($profile) and defined($group) ) {
	    $profile =~ s/\ //g;
	    $group   =~ s/\ //g;
	    $rec = "$hostname\t$ip\t$hostname\t$profile\t$group";
	    push( @result, $rec );
	}
    }

    if ( $opt{i} ) {
	print "Hostname\ Address\ Alias\ Host_Profile\ Monarch_Group\n";
	foreach (@result) { print; print "\n" }
	exit;
    }

    if (@result) {
	if (open( FILE, '>>', $output )) {
	    foreach (@result) {
		print FILE "$_\n";
		print "$_\tWritten to $output\n" if $debug;
	    }
	    close(FILE);
	}
    }
}

sub getprofile {
    my $spec = shift;
    my ( $string, $profile, @words, $group ) = ();
    foreach (@os_list) {
	@words = split( /;/, $_ );
	$string = $words[0];
	if ( $spec =~ m/$string/ ) {
	    $profile = $words[1];
	    $group   = $words[2];
	    last;
	}
    }
    return ( $profile, $group );
}

# Note that our seek-handling of the event file presumes that Nagios line-buffers the file,
# so we never read to the end and discover only half a message there that should be re-read
# on some future cycle.
sub breakfile {
    my $eventfile = shift;
    my @result    = ();

    # We store the device and inode numbers in the seek file as well as the position to which we have
    # previously read, so we can tell if the seek file really still refers to the same event file.

    my $eventfile_device = -1;
    my $eventfile_inode  = -1;
    my @seek_pos         = ( 0, $eventfile_device, $eventfile_inode );    # seek position, ...

    # We open the event file before running the stat() call, so we don't have
    # any race conditions in sensing its device and inode numbers.
    open( LOG_FILE, '<', $eventfile ) or die "NOTICE:  Unable to open log file $eventfile ($!).\n";

    my ( $dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size, @rest ) = stat(LOG_FILE);
    $eventfile_device = $dev;
    $eventfile_inode  = $ino;
    if ( not defined $eventfile_inode ) {
	my $status = "$!";
	close(LOG_FILE);
	die "Unable to stat log file $eventfile ($status).\n";
    }

    # Try to open the log seek file.  If this open fails, we will default to reading from the beginning
    # of the event file.  We use the (possibly missing) device and inode numbers as well to detect a
    # different event file now in use.  Note that there is an open hole here -- if the event file was
    # rolled since the last time we read it, there may be some unprocessed messages at the end of the
    # old event file that will now never be read and processed.  That is one reason to keep the cycle
    # time for this processing relatively short, to minimize the number of such missed events.  On the
    # other hand, if we miss a few records, it should be no big deal because the respective GDMA clients
    # will eventually complain once again that they cannot find their config files, and we should catch
    # them in some future cycle.

    if ( open( SEEK_FILE, '<', $seek_file ) ) {
	chomp( @seek_pos = <SEEK_FILE> );
	close(SEEK_FILE);

	# Provide default values if the file is empty or doesn't (yet) include the device/inode numbers.
	# (device == -1 && inode == -1) means we assume the same $eventfile file is still in play.
	$seek_pos[0] = 0  if ( !defined( $seek_pos[0] ) || $seek_pos[0] !~ /\d/ );    # default seek position
	$seek_pos[1] = -1 if ( !defined( $seek_pos[1] ) || $seek_pos[1] !~ /\d/ );    # default device number
	$seek_pos[2] = -1 if ( !defined( $seek_pos[2] ) || $seek_pos[2] !~ /\d/ );    # default inode number

	# If the seek file is empty, there is no need to seek ...
	if ( $seek_pos[0] != 0 ) {
	    ## Compare seek position to actual file size.  If the file size is smaller
	    ## then we just start from the beginning; i.e., the file was rotated, etc.,
	    ## even if it somehow still has the same device and inode numbers.
	    if (   ( $seek_pos[1] == -1 || $seek_pos[1] == $eventfile_device )
		&& ( $seek_pos[2] == -1 || $seek_pos[2] == $eventfile_inode )
		&& $seek_pos[0] <= $size )
	    {
		seek( LOG_FILE, $seek_pos[0], 0 );
	    }
	}
    }
    else {
	$seek_pos[0] = 0;
    }
    $seek_pos[1] = $eventfile_device;
    $seek_pos[2] = $eventfile_inode;

    while (<LOG_FILE>) {
	push( @result, $_ );
    }

    # All new events in the event file are now read.  Overwrite the log seek file and print
    # the byte position we have read to.  Updating now presumes we will successfully process
    # all the lines we read, so there will be no need to go back and re-read those lines.
    # If there was any danger of that, we could defer updating the seek file until we really
    # knew that all the data was processed, or just update it now with:
    #     print SEEK_FILE "$seek_pos[0]\n$eventfile_device\n$eventfile_inode\n";
    # (to make sure the position/device/inode parameters are up-to-date) and update the
    # seek file again later with the $file_pos and other parameters.

    my $file_pos = tell(LOG_FILE);
    open( SEEK_FILE, '>', $seek_file ) or die "Unable to open seek position file $seek_file ($!).\n";
    print "Writing to seek position file $seek_file -- position $file_pos\n" if $debug;
    print SEEK_FILE "$file_pos\n$eventfile_device\n$eventfile_inode\n";
    close(SEEK_FILE);

    close(LOG_FILE);
    return (@result);
}

sub initoptions {
    my $helpstring = "
This script parses the nagios.log for gdma_auto passive service results, looking for hosts to import.

Options: 
    -i interactive mode write results to STDOUT (with an extra heading)
                        instead of writing to $output
    -H autohost name    default [gdma-autohost]
    -S autohost service default [gdma_auto]
    -d                  Debug mode.  Will output additional messages. 
    -h or -help         Displays help message.
";

    getopts( "H:S:idh", \%opt );
    if ( $opt{h} or $opt{help} ) {
	print $helpstring;
	exit 3;
    }

    return 0;
}

# Clever use of hash slice here.  See Programming Perl, 3/e, page 94.
sub uniq {
    my $list   = shift;
    my %unique = ();
    @unique{@$list} = (undef) x @$list;
    my @list = sort keys %unique;
    return @list;
}
