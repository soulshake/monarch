#!/usr/bin/perl -w --
# MonArch - Groundwork Monitor Architect
# migrate-monarch.pl
#
############################################################################
# Release 3.7
# May 2013
############################################################################
#
# Original author: Scott Parris
#
# Copyright 2008-2013 GroundWork Open Source, Inc. (GroundWork)
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

use DBI;
use strict;
use XML::LibXML;
use File::Copy;

my $all_is_done     = 0;
my $monarch_version = '3.7';
my $is_portal       = 0;
my $monarch_home    = 0;
my $nagios_bin      = 0;
my $nagios_version  = 0;
my $nagios_etc      = 0;
my $cgi_bin         = 0;
my $doc_root        = 0;
my $web_group       = "apache";
my $sqlstmt         = '';
my $sth             = undef;
my %places          = ();
my %fields          = ();

sub parse_xml($) {
    my $data       = shift;
    my %properties = ();
    if ($data) {
	my $parser = XML::LibXML->new(
	    ext_ent_handler => sub { die "INVALID FORMAT: external entity references are not allowed in XML documents.\n" },
	    no_network      => 1
	);
	my $doc = undef;
	eval {
	    $doc = $parser->parse_string($data);
	};
	if ($@) {
	    my ($package, $file, $line) = caller;
	    print STDERR $@, " called from $file line $line.";
	    ## FIX LATER:  HTMLifying here, along with embedded markup in $properties{'error'}, is something of a hack,
	    ## as it presumes a context not in evidence.  But it's necessary in the browser context.
	    # $@ = HTML::Entities::encode($@);
	    # $@ =~ s/\n/<br>/g;
	    if ($@ =~ s/external entity callback died: // || $@ =~ /external entity references are not allowed/) {
		## First undo the effect of the croak() call in XML::LibXML.
		$@ =~ s/ at \S+ line \d+\n//;
		$properties{'error'} = "Bad XML string (parse_xml):\n$@";
	    }
	    elsif ($@ =~ /Attempt to load network entity/) {
		$properties{'error'} = "Bad XML string (parse_xml):\nINVALID FORMAT: non-local entity references are not allowed in XML documents.\n$@";
	    }
	    else {
		$properties{'error'} = "Bad XML string (parse_xml):\n$@ called from $file line $line.";
	    }
	}
	else {
	    my @nodes  = $doc->findnodes("//prop");
	    foreach my $node (@nodes) {
		if ( $node->hasAttributes() ) {
		    my $property = $node->getAttribute('name');
		    my $value    = $node->textContent;
		    $value =~ s/\s+$|\n//g;
		    if ( $property =~ /command$/ ) {
			my $command_line = '';
			if ($value) {
			    my @command = split( /!/, $value );
			    $properties{$property} = $command[0];
			    if ( $command[1] ) {
				foreach my $c (@command) {
				    $command_line .= "$c!";
				}
			    }
			}
			$command_line =~ s/!$//;
			$properties{'command_line'} = $command_line;
		    }
		    elsif ( $property =~ /last_notification$/ ) {
			my $value = $node->textContent;
			$value =~ s/\s+$|\n//g;
			if ( $value == 0 ) {
			    $properties{$property} = '-zero-';
			}
			else {
			    $properties{$property} = $value;
			}
		    }
		    else {
			$properties{$property} = $value;
		    }
		}
	    }
	}
    }
    else {
	$properties{'error'} = "Empty String (parse_xml)";
    }
    return %properties;
}

my ( $dbhost, $database, $user, $passwd ) = undef;
if ( -e "/usr/local/groundwork/config/db.properties" ) {
    open( FILE, '<', '/usr/local/groundwork/config/db.properties' )
      or die "\n\tCannot open the db.properties file ($!); aborting!\n";
    while ( my $line = <FILE> ) {
	if ( $line =~ /\s*monarch\.dbhost\s*=\s*(\S+)/ )   { $dbhost   = $1 }
	if ( $line =~ /\s*monarch\.database\s*=\s*(\S+)/ ) { $database = $1 }
	if ( $line =~ /\s*monarch\.username\s*=\s*(\S+)/ ) { $user     = $1 }
	if ( $line =~ /\s*monarch\.password\s*=\s*(\S+)/ ) { $passwd   = $1 }
    }
    close(FILE);
    $is_portal      = 1;
    $nagios_version = '3.x';
    $monarch_home   = '/usr/local/groundwork/monarch';
}
else {
    print "\n\tMonarch $monarch_version Update";
    print "\n=============================================================\n";
    print "\n\tReading configuration file ...\n";

    until ($monarch_home) {
	if ( -e "/usr/local/groundwork/monarch/lib/MonarchConf.pm" ) {
	    $monarch_home = "/usr/local/groundwork/monarch";
	    print "\n\tPlease enter the Monarch installation path [ $monarch_home ] : ";
	    my $input = <STDIN>;
	    chomp $input;
	    if ($input) { $monarch_home = $input }
	    my $monarch_test = $monarch_home . '/lib/MonarchConf.pm';
	    unless ( -e $monarch_test ) {
		print "\n\tError: Cannot locate MonarchConf.pm in path $monarch_home [/lib] ...\n";
		$monarch_home = 0;
	    }
	}
	else {
	    print "\n\tPlease enter the Monarch installation path : ";
	    my $input = <STDIN>;
	    chomp $input;
	    if ($input) { $monarch_home = $input }
	    my $monarch_test = $monarch_home . '/lib/MonarchConf.pm';
	    unless ( -e $monarch_test ) {
		print "\n\tError: Cannot locate MonarchConf.pm in path $monarch_home [/lib] ...\n";
		$monarch_home = 0;
	    }
	}
    }
    open( FILE, '<', "$monarch_home/lib/MonarchConf.pm" );
    while ( my $line = <FILE> ) {
	$line =~ s/\'|\"|;//g;
	if ( $line =~ /\s*\$dbhost\s*=\s*(\S+)/ )   { $dbhost   = $1 }
	if ( $line =~ /\s*\$database\s*=\s*(\S+)/ ) { $database = $1 }
	if ( $line =~ /\s*\$dbuser\s*=\s*(\S+)/ )   { $user     = $1 }
	if ( $line =~ /\s*\$dbpass\s*=\s*(\S+)/ )   { $passwd   = $1 }
    }
    close(FILE);
}

##############################################################################
# Connect to DB
##############################################################################

print "\n\tConnecting to $database with user $user ...\n" unless $is_portal;

my $dsn = "DBI:mysql:$database:$dbhost";
my $dbh = undef;

# We turn AutoCommit off because we want to make changes roll back automatically as much as
# possible if we don't get successfully through the entire script.  This is not perfect (i.e.,
# we don't necessarily have all the changes made in a single huge transaction) because some of
# the transformations may implicitly commit previous changes, and there is nothing we can do
# about that.  Still, we do the best we can.
#
# We turn PrintError off because RaiseError is on and we don't want duplicate messages printed.

eval { $dbh = DBI->connect( $dsn, $user, $passwd, { 'AutoCommit' => 0, 'RaiseError' => 1, 'PrintError' => 0 } ) };
if ($@) {
    print "\nError: connect failed ($@)\n";
    die;
}
$dbh->do( "set session transaction isolation level serializable" );

##############################################################################
# Validation
##############################################################################

#-----------------------------------------------------------------------------
# Make sure we're using the right storage engine for Monarch.
#-----------------------------------------------------------------------------

$sqlstmt = 'select @@storage_engine';
my ($storage_engine) = $dbh->selectrow_array($sqlstmt);

if ($storage_engine ne 'InnoDB') {
    print "\n\tError: Monarch is using $storage_engine as the default storage engine instead of InnoDB.\n";
    exit 1;
}

#-----------------------------------------------------------------------------
# Make sure the existing data is clean.
#-----------------------------------------------------------------------------

# If we get duplicate host services, that will prevent our applying a unique {host_id, servicename_id}
# index on the 'services' table.  (Historically, there have been some holes in the code that mistakenly
# allowed such duplicates to be created.)

my $got_duplicates = 0;

$sqlstmt =
    '
    select distinct h.name as hostname, sn.name as servicename, count(*) as num, s.host_id, s.servicename_id
    from hosts h, service_names sn, services s
    where h.host_id = s.host_id
    and sn.servicename_id = s.servicename_id
    group by s.host_id, s.servicename_id
    having num > 1
    ';
$sth     = $dbh->prepare($sqlstmt);
$sth->execute();
my %duplicates = ();
while ( my @values = $sth->fetchrow_array() ) {
    $duplicates{ $values[0] }{ $values[1] } = $values[2];
}
$sth->finish;

if (%duplicates) {
    my $max_host_length    = 4;
    my $max_service_length = 7;
    my $max_count_length   = 5;
    my $host_length;
    my $service_length;
    my $count_length;
    foreach my $host (keys %duplicates) {
	$host_length = length $host;
	if ($max_host_length < $host_length) {
	    $max_host_length = $host_length;
	}
	foreach my $service ( keys %{ $duplicates{$host} } ) {
	    $service_length = length $service;
	    if ($max_service_length < $service_length) {
		$max_service_length = $service_length;
	    }
	    $count_length = length "$duplicates{$host}{$service}";
	    if ($max_count_length < $count_length) {
		$max_count_length = $count_length;
	    }
	}
    }
    print "\n\tWARNING: The following duplicate host services\n";
    print "\t         exist in your \"monarch\" database:\n";
    printf "\t%s-%s-%s\n", '-' x $max_host_length, '-' x $max_service_length, '-' x $max_count_length;
    printf "\t%-${max_host_length}s %-${max_service_length}s %${max_count_length}s\n", 'Host', 'Service', 'Count';
    printf "\t%s-%s-%s\n", '-' x $max_host_length, '-' x $max_service_length, '-' x $max_count_length;
    foreach my $host (sort keys %duplicates) {
	foreach my $service ( sort keys %{ $duplicates{$host} } ) {
	    printf "\t%-${max_host_length}s %-${max_service_length}s %${max_count_length}d\n",
	      $host, $service, $duplicates{$host}{$service};
	}
    }
    printf "\t%s-%s-%s\n", '-' x $max_host_length, '-' x $max_service_length, '-' x $max_count_length;
    $got_duplicates = 1;
}

# If we get duplicate host service instances, that will prevent our applying a unique {service_id, name}
# index on the 'service_instance' table.  (Historically, the Monarch code has prohibited such duplicates
# from being created at the application level, so this is precautionary.)

$sqlstmt =
    '
    select distinct h.name as hostname, sn.name as servicename, si.name as instancename,
	count(*) as num, s.host_id, s.servicename_id, si.service_id
    from hosts h, service_names sn, services s, service_instance si
    where s.service_id = si.service_id
    and h.host_id = s.host_id
    and sn.servicename_id = s.servicename_id
    group by s.host_id, s.servicename_id, si.name
    having num > 1
    ';
$sth     = $dbh->prepare($sqlstmt);
$sth->execute();
%duplicates = ();
while ( my @values = $sth->fetchrow_array() ) {
    $duplicates{ $values[0] }{ $values[1] }{ $values[2] } = $values[3];
}
$sth->finish;

if (%duplicates) {
    my $max_host_length     = 4;
    my $max_service_length  = 7;
    my $max_instance_length = 8;
    my $max_count_length    = 5;
    my $host_length;
    my $service_length;
    my $instance_length;
    my $count_length;
    foreach my $host (keys %duplicates) {
	$host_length = length $host;
	if ($max_host_length < $host_length) {
	    $max_host_length = $host_length;
	}
	foreach my $service ( keys %{ $duplicates{$host} } ) {
	    $service_length = length $service;
	    if ($max_service_length < $service_length) {
		$max_service_length = $service_length;
	    }
	    foreach my $instance ( keys %{ $duplicates{$host}{$service} } ) {
		$instance_length = length $instance;
		if ($max_instance_length < $instance_length) {
		    $max_instance_length = $instance_length;
		}
		$count_length = length "$duplicates{$host}{$service}{$instance}";
		if ($max_count_length < $count_length) {
		    $max_count_length = $count_length;
		}
	    }
	}
    }
    print "\n\tWARNING: The following duplicate host service instances\n";
    print "\t         exist in your \"monarch\" database:\n";
    printf "\t%s-%s-%s-%s\n", '-' x $max_host_length, '-' x $max_service_length, '-' x $max_instance_length, '-' x $max_count_length;
    printf "\t%-${max_host_length}s %-${max_service_length}s %-${max_instance_length}s %${max_count_length}s\n",
	'Host', 'Service', 'Instance', 'Count';
    printf "\t%s-%s-%s-%s\n", '-' x $max_host_length, '-' x $max_service_length, '-' x $max_instance_length, '-' x $max_count_length;
    foreach my $host (sort keys %duplicates) {
	foreach my $service ( sort keys %{ $duplicates{$host} } ) {
	    foreach my $instance ( sort keys %{ $duplicates{$host}{$service} } ) {
		printf "\t%-${max_host_length}s %-${max_service_length}s %-${max_instance_length}s %${max_count_length}d\n",
		  $host, $service, $instance, $duplicates{$host}{$service}{$instance};
	    }
	}
    }
    printf "\t%s-%s-%s-%s\n", '-' x $max_host_length, '-' x $max_service_length, '-' x $max_instance_length, '-' x $max_count_length;
    $got_duplicates = 1;
}

if ($got_duplicates) {
    print "\n\tWARNING:  The duplicates shown above will not be resolved\n";
    print "\t          by the following schema/content migration.\n";
}

##############################################################################
# Distribution
##############################################################################

unless ($is_portal) {
    print "\n\tDistributing files ...\n";

    $sqlstmt = "select name, value from setup where type = 'config'";
    $sth     = $dbh->prepare($sqlstmt);
    $sth->execute();
    my %name_val = ();
    while ( my @values = $sth->fetchrow_array() ) {
	$name_val{ $values[0] } = $values[1];
    }
    $sth->finish;

    until ($doc_root) {
	if ( -e "$name_val{'doc_root'}" ) {
	    $doc_root = $name_val{'doc_root'};
	}
	else {
	    print "\n\n\n\tWhat is the full path to your web server's document root : ";
	    my $input = <STDIN>;
	    chomp $input;
	    if ( -e "$input" ) {
		$doc_root = $input;
	    }
	    else {
		print "\n\n\n\tError: Invalid entry $doc_root does not exist.";
	    }
	}
    }

    until ($cgi_bin) {
	if ( -e "$name_val{'doc_root'}" ) {
	    $cgi_bin = $name_val{'cgi_bin'};
	}
	else {
	    print "\n\n\n\tEnter the full path of your cgi-bin directory [$cgi_bin] : ";
	    my $input = <STDIN>;
	    chomp $input;
	    if ( -e "$input" ) {
		$cgi_bin = $input;
	    }
	    else {
		print "\n\n\n\tError: Invalid entry $cgi_bin does not exist.";
	    }
	}
    }

    opendir( DIR, './images' ) || print "\n\nCannot read ./images ($!)";
    while ( my $file = readdir(DIR) ) {
	if ( $file =~ /^\./ ) { next }
	print "\n\t$doc_root/monarch/images/$file";
	copy( "./images/$file", "$doc_root/monarch/images/$file" )
	  || print "\n\nCannot copy ./images/$file to $doc_root/monarch/images/$file ($!)";
    }
    closedir(DIR);

    if ( !-e "$doc_root/monarch/doc" ) {
	mkdir( "$doc_root/monarch/doc", 0777 )
	  || print "\n\n$doc_root/monarch/doc ($!)";
	system("chmod 777 $doc_root/monarch/doc");
    }

    opendir( DIR, './doc' ) || print "\n\nCannot read ./doc ($!)";
    while ( my $file = readdir(DIR) ) {
	if ( $file =~ /^\.|^images$/ ) { next }
	print "\n\t$doc_root/monarch/doc/$file";
	copy( "./doc/$file", "$doc_root/monarch/doc/$file" )
	  || print "\n\nCannot copy ./doc/$file to $doc_root/monarch/doc/$file ($!)";
    }
    closedir(DIR);

    if ( !-e "$doc_root/monarch/doc/images" ) {
	mkdir( "$doc_root/monarch/doc/images", 0777 )
	  || print "\n\n$doc_root/monarch/doc/images ($!)";
	system("chmod 777 $doc_root/monarch/doc/images");
    }

    opendir( DIR, './doc/images' ) || print "\n\nCannot read ./doc/images ($!)";
    while ( my $file = readdir(DIR) ) {
	if ( $file =~ /^\./ ) { next }
	copy( "./doc/images/$file", "$doc_root/monarch/doc/images/$file" )
	  || print "\n\nCannot copy ./doc/$file to $doc_root/monarch/doc/images/$file ($!)";
    }
    closedir(DIR);

    my @files = (
	'FormValidator.js', 'autosuggest.css',
	'autosuggest2.js',  'blank.html',
	'dtree.css',        'groundwork.css',
	'monarch.css',      'monarch.js',
	'nicetitle.js',     'wz_tooltip.js',
    );
    foreach my $file (@files) {
	copy( "./$file", "$doc_root/monarch/$file" )
	  || print "\n\nCannot copy ./$file to $doc_root/monarch/$file ($!)";
	print "\n\t$doc_root/monarch/$file";
    }

    my $web_group = "www";
    my $web_user  = "wwwrun";
    if ( -e '/etc/redhat-release' ) {
	$web_group = "apache";
	$web_user  = "apache";
    }

    my $validated = 0;
    unless ( -e "$monarch_home/lib/MonarchProfileImport.pm" ) {
	until ($validated) {
	    print "\n\n\n\tEnter web server's user account [$web_user] : ";
	    my $input = <STDIN>;
	    chomp $input;
	    if ($input) { $web_user = $input }
	    my @user = getpwnam($web_user);
	    if ( $user[0] ) {
		$validated = 1;
	    }
	    else {
		print "\n\n\n\tError: Invalid, user $input does not exist.";
	    }
	}
	$validated = 0;
	until ($validated) {
	    print "\n\n\n\tEnter web server's user group [$web_group] : ";
	    my $input = <STDIN>;
	    chomp $input;
	    if ($input) { $web_group = $input }
	    my @grp = getgrnam($web_group);
	    if ( $grp[0] ) {
		$validated = 1;
	    }
	    else {
		print "\n\n\n\tError: Invalid, group $input does not exist.";
	    }
	}
    }

    $validated = 0;
    until ($validated) {
	print "\n\n\n\tEnter web server's user group [$web_group] : ";
	my $input = <STDIN>;
	chomp $input;
	if ($input) { $web_group = $input }
	my @grp = getgrnam($web_group);
	if ( $grp[0] ) {
	    $validated = 1;
	}
	else {
	    print "\n\n\n\tError: Invalid, group $input does not exist.";
	}
    }

    @files = (
	'MonarchFile.pm',          'MonarchStorProc.pm',
	'MonarchExternals.pm',     'MonarchDoc.pm',
	'MonarchLoad.pm',          'MonarchProfileExport.pm',
	'MonarchProfileImport.pm', 'MonarchTree.pm',
	'MonarchAudit.pm',         'MonarchFoundationSync.pm',
	'MonarchAPI.pm',           'MonarchAutoConfig.pm'
    );
    foreach my $file (@files) {
	copy( "./$file", "$monarch_home/lib/$file" )
	  || print "\n\nnot copied ./$file $monarch_home/lib/$file ($!)";
	print "\n\t$monarch_home/lib/$file";
    }

    unless ( -e "$monarch_home/lib/MonarchCallOut.pm" ) {
	copy( "./MonarchCallOut.pm", "$monarch_home/lib/MonarchCallOut.pm" )
	  || print "\n\nnot copied ./MonarchCallOut.pm $monarch_home/lib/MonarchCallOut.pm ($!)";
	print "\n\t$monarch_home/lib/MonarchCallOut.pm";
    }

    unless ( -e "$monarch_home/lib/MonarchDeploy.pm" ) {
	copy( "./MonarchDeploy.pm", "$monarch_home/lib/MonarchDeploy.pm" )
	  || print "\n\nnot copied ./MonarchDeploy.pm $monarch_home/lib/MonarchDeploy.pm ($!)";
	print "\n\t$monarch_home/lib/MonarchDeploy.pm";
    }

    unless ( -e "$monarch_home/lib/MonarchExternals.pm" ) {
	copy( "./MonarchExternals.pm", "$monarch_home/lib/MonarchExternals.pm" )
	  || print "\n\nnot copied ./MonarchExternals.pm $monarch_home/lib/MonarchExternals.pm ($!)";
	print "\n\t$monarch_home/lib/MonarchExternals.pm";
    }
    unless ( -e "$doc_root/favicon.ico" ) {
	copy( "./favicon.ico", "$doc_root/favicon.ico" )
	  || print "\n\nCannot copy ./favicon.ico to $doc_root/favicon.ico ($!)";
    }

    if ($validated) { system("chown -R $web_user:$web_group $monarch_home") }

    @files = ( 'nagios_reload', 'nmap_scan_one' );
    foreach my $file (@files) {
	copy( "./$file", "$monarch_home/bin/$file" )
	  || print "\n\nnot copied ./$file $monarch_home/bin/$file ($!)\n";
	print "\n\t$monarch_home/bin/$file";
    }
    system("chown root:$web_group $monarch_home/bin/nmap_scan_one");
    system("chmod 4750 $monarch_home/bin/nmap_scan_one");

    %places = (
	'MonarchForms.pm' => "$monarch_home/lib",
    );
    foreach my $file (keys %places) {
	my $place = $places{$file};
	my $cgi_line = undef;
	open( FILE, '<', "$place/$file" ) || print "\n\n$place/$file ($!)";
	while ( my $line = <FILE> ) {
	    if ( $line =~ /^\s*my\s+\$cgi_dir/ ) {
		$cgi_line = $line;
	    }
	}
	close(FILE);
	open( FILE, '<', "./$file" ) || print "\n\n./$file ($!)";
	my $out_to_file = undef;
	while ( my $line = <FILE> ) {
	    if ( $line =~ /^\s*my\s+\$cgi_dir/ ) {
		$line = $cgi_line;
	    }
	    $out_to_file .= $line;
	}
	close(FILE);
	print "\n\tWriting $place/$file";
	open( FILE, '>', "$place/$file" ) || print "\n\n$place/$file ($!)";
	print FILE $out_to_file;
	close(FILE);
	system("chmod 664 $place/$file");
    }

    %places = (
	'monarch.cgi'      => $cgi_bin,
	'monarch_ajax.cgi' => $cgi_bin,
	'monarch_auto.cgi' => $cgi_bin,
	'monarch_ez.cgi'   => $cgi_bin,
	'monarch_file.cgi' => $cgi_bin,
	'monarch_scan.cgi' => $cgi_bin,
	'monarch_tree.cgi' => $cgi_bin,
	'nmap_scan_one.pl' => "$monarch_home/bin",
    );
    foreach my $file (keys %places) {
	my $place = $places{$file};
	open( FILE, '<', "./$file" ) || print "\n\n./$file ($!)";
	my $out_to_file = undef;
	while ( my $line = <FILE> ) {
	    if ( $line =~ /^#!/ ) {
		$line = "#!/usr/bin/perl --\n";
	    }
	    if ( $line =~ /^\s*use\s+lib\s+/ ) {
		$line = "use lib qq($monarch_home/lib);\n";
	    }
	    $out_to_file .= $line;
	}
	close(FILE);
	print "\n\tWriting $place/$file";
	open( FILE, '>', "$place/$file" ) || print "\n\n$place/$file ($!)";
	print FILE $out_to_file;
	close(FILE);
	system("chmod 755 $place/$file");
    }
}

##############################################################################
# Update setup
##############################################################################

print "\n\tUpdating setup information ...\n" unless $is_portal;

$sqlstmt = "select value from setup where name = 'nagios_etc'";
($nagios_etc) = $dbh->selectrow_array($sqlstmt);

until ($nagios_etc) {
    if ( -e "/usr/local/nagios/etc/nagios.cfg" ) {
	$nagios_etc = "/usr/local/nagios/etc";
	print "\n\tPlease enter the path in which nagios.cfg resides [ $nagios_etc ] : ";
	my $input = <STDIN>;
	chomp $input;
	if ($input) { $nagios_etc = $input }
	unless ( -e $nagios_etc ) {
	    print "\n\tError: Cannot locate nagios.cfg in path $nagios_etc ...\n";
	    $nagios_etc = 0;
	}
    }
    elsif ( -e "/etc/nagios/nagios.cfg" ) {
	$nagios_etc = "/etc/nagios";
	print "\n\tPlease enter the path in which nagios.cfg resides [ $nagios_etc ] : ";
	my $input = <STDIN>;
	chomp $input;
	if ($input) { $nagios_etc = $input }
	unless ( -e $nagios_etc ) {
	    print "\n\tError: Cannot locate nagios.cfg in path $nagios_etc ...\n";
	    $nagios_etc = 0;
	}
    }
    elsif ( -e "/usr/local/nagios/etc/nagios.cfg" ) {
	$nagios_etc = "/usr/local/nagios/etc";
	print "\n\tPlease enter the path in which nagios.cfg resides [ $nagios_etc ] : ";
	my $input = <STDIN>;
	chomp $input;
	if ($input) { $nagios_etc = $input }
	unless ( -e $nagios_etc ) {
	    print "\n\tError: Cannot locate nagios.cfg in path $nagios_etc ...\n";
	    $nagios_etc = 0;
	}
    }
    else {
	print "\n\tPlease enter the path in which nagios.cfg resides: ";
	my $input = <STDIN>;
	chomp $input;
	if ($input) { $nagios_etc = $input }
	unless ( -e $nagios_etc ) {
	    print "\n\tError: Cannot locate nagios.cfg in path $nagios_etc ...\n";
	    $nagios_etc = 0;
	}
    }
}

# This obsolete code incorrectly sets the nagios_version variable based on a database lookup.
# $sqlstmt = "select value from setup where name = 'nagios_version'";
# $nagios_version = $dbh->selectrow_array($sqlstmt);
# if ($is_portal) { $nagios_version }

until ($nagios_version) {
    $nagios_version = "3";
    print "\n\tPlease enter 1 for Nagios version 1.x, 2 for Nagios version 2.x, or 3 for Nagios 3.x [ $nagios_version ] : ";
    my $input = <STDIN>;
    chomp $input;
    if ( $input =~ /^([1-3])/ ) {
	$nagios_version = $1;
    }
    $nagios_version .= ".x";
}

$sqlstmt = "select value from setup where name = 'nagios_bin'";
($nagios_bin) = $dbh->selectrow_array($sqlstmt);

until ($nagios_bin) {
    if ( -e "/usr/local/nagios/bin" ) {
	$nagios_bin = "/usr/local/nagios/bin";
	print "\n\tPlease enter the path in which the nagios binary resides [ $nagios_bin ] : ";
	my $input = <STDIN>;
	chomp $input;
	if ($input) { $nagios_bin = $input }
	my $nagios_test = $nagios_bin . '/nagios';
	unless ( -e $nagios_test ) {
	    print "\n\tError: Cannot locate nagios binary in path $nagios_bin ...\n";
	    $nagios_bin = 0;
	}
    }
    elsif ( -e "/usr/sbin/nagios" ) {
	$nagios_bin = "/usr/sbin";
	print "\n\tPlease enter the path in which the nagios binary resides [ $nagios_bin ] : ";
	my $input = <STDIN>;
	chomp $input;
	if ($input) { $nagios_bin = $input }
	my $nagios_test = $nagios_bin . '/nagios';
	unless ( -e $nagios_test ) {
	    print "\n\tError: Cannot locate nagios binary in path $nagios_bin ...\n";
	    $nagios_bin = 0;
	}
    }
    elsif ( -e "/usr/local/nagios/bin" ) {
	$nagios_bin = "/usr/local/nagios/bin";
	print "\n\tPlease enter the path in which the nagios binary resides [ $nagios_bin ] : ";
	my $input = <STDIN>;
	chomp $input;
	if ($input) { $nagios_bin = $input }
	my $nagios_test = $nagios_bin . '/nagios';
	unless ( -e $nagios_test ) {
	    print "\n\tError: Cannot locate nagios binary in path $nagios_bin ...\n";
	    $nagios_bin = 0;
	}
    }
    else {
	print "\n\tPlease enter the path in which the nagios binary resides: ";
	my $input = <STDIN>;
	chomp $input;
	if ($input) { $nagios_bin = $input }
	my $nagios_test = $nagios_bin . '/nagios';
	unless ( -e $nagios_test || $nagios_test eq '/tmp/nagios' ) {
	    print "\n\tError: Cannot locate nagios binary in path $nagios_bin ...";
	    print "\n\tNote: If Nagios doesn't run on this machine try any valid path (i.e. /tmp).";
	    $nagios_bin = 0;
	}
    }
}

my %ez      = ();
$sqlstmt = "select name, value from setup where type = 'monarch_ez'";
$sth     = $dbh->prepare($sqlstmt);
$sth->execute;
while ( my @values = $sth->fetchrow_array() ) {
    $ez{ $values[0] } = $values[1];
}
$sth->finish;

$sqlstmt = "select value from setup where name = 'backup_dir'";
my ($backup_dir) = $dbh->selectrow_array($sqlstmt);
unless ($backup_dir) { $backup_dir = "$monarch_home/backup" }
$sqlstmt = "select value from setup where name = 'upload_dir'";
my ($upload_dir) = $dbh->selectrow_array($sqlstmt);
unless ($upload_dir) { $upload_dir = "/tmp" }
$sqlstmt = "select value from setup where name = 'enable_groups'";
my ($enable_groups) = $dbh->selectrow_array($sqlstmt);
unless ($enable_groups) { $enable_groups = "0" }
$sqlstmt = "select value from setup where name = 'enable_externals'";
my ($enable_externals) = $dbh->selectrow_array($sqlstmt);
unless ($enable_externals) { $enable_groups = "0" }

#-----------------------------------------------------------------------------
# Our first act of modifying the database is to update the Monarch version
# number, so it reflects the fact that the schema and content are in transition.

$sqlstmt = "select value from setup where name = 'monarch_version' and type = 'config'";
my ($old_monarch_version) = $dbh->selectrow_array($sqlstmt);

# Create an artificial Monarch version number which we will use to flag the fact that a migration is in progress.
# If the migration completes successfully, this setting will be updated to be the target Monarch version.
# If not, it will remain as an indicator to later users of the database that the schema is in bad shape.
my $transient_monarch_version = $old_monarch_version;
$transient_monarch_version = '-' . $transient_monarch_version
    if defined($transient_monarch_version) && length($transient_monarch_version) && $transient_monarch_version !~ /^-/;

$sqlstmt = "delete from setup where type = 'monarch_ez' or type = 'config'";
$sth     = $dbh->prepare($sqlstmt);
unless ( $sth->execute ) { print "\n\n\tError: $sqlstmt ($sth->errstr)" }
$sth->finish;

# For now, we stuff in a value for the Monarch version that will flag that migration is in progress.
# This will be replaced at the very end if we got through the entire script unscathed.
$sqlstmt = "insert into setup values('monarch_version','config','$transient_monarch_version')";
$sth     = $dbh->prepare($sqlstmt);
unless ( $sth->execute ) { print "Error: $sqlstmt ($sth->errstr)" }
#-----------------------------------------------------------------------------

if ($is_portal) {
    $sqlstmt = "insert into setup values('is_portal','config','1')";
    $sth = $dbh->prepare($sqlstmt);
    unless ( $sth->execute ) { print "Error: $sqlstmt ($sth->errstr)" }
}

$sqlstmt = "insert into setup values('enable_externals','config','$enable_externals')";
$sth     = $dbh->prepare($sqlstmt);
unless ( $sth->execute ) { print "Error: $sqlstmt ($sth->errstr)" }
$sqlstmt = "insert into setup values('enable_groups','config','$enable_groups')";
$sth     = $dbh->prepare($sqlstmt);
unless ( $sth->execute ) { print "Error: $sqlstmt ($sth->errstr)" }
$sqlstmt = "insert into setup values('nagios_version','config','$nagios_version')";
$sth     = $dbh->prepare($sqlstmt);
unless ( $sth->execute ) { print "Error: $sqlstmt ($sth->errstr)" }
$sqlstmt = "insert into setup values('monarch_home','config','$monarch_home')";
$sth     = $dbh->prepare($sqlstmt);
unless ( $sth->execute ) { print "Error: $sqlstmt ($sth->errstr)" }
$sqlstmt = "insert into setup values('backup_dir','config','$backup_dir')";
$sth     = $dbh->prepare($sqlstmt);
unless ( $sth->execute ) { print "Error: $sqlstmt ($sth->errstr)" }
$sqlstmt = "insert into setup values('upload_dir','config','$upload_dir')";
$sth     = $dbh->prepare($sqlstmt);
unless ( $sth->execute ) { print "Error: $sqlstmt ($sth->errstr)" }
$sqlstmt = "insert into setup values('nagios_etc','config','$nagios_etc')";
$sth     = $dbh->prepare($sqlstmt);
unless ( $sth->execute ) { print "Error: $sqlstmt ($sth->errstr)" }
$sqlstmt = "insert into setup values('nagios_bin','config','$nagios_bin')";
$sth     = $dbh->prepare($sqlstmt);
unless ( $sth->execute ) { print "Error: $sqlstmt ($sth->errstr)" }
$sqlstmt = "insert into setup values('doc_root','config','$doc_root')";
$sth     = $dbh->prepare($sqlstmt);
unless ( $sth->execute ) { print "Error: $sqlstmt ($sth->errstr)" }
$sqlstmt = "insert into setup values('cgi_bin','config','$cgi_bin')";
$sth     = $dbh->prepare($sqlstmt);
unless ( $sth->execute ) { print "Error: $sqlstmt ($sth->errstr)" }
$sqlstmt = "insert into setup values('max_tree_nodes','config','3000')";
$sth     = $dbh->prepare($sqlstmt);
unless ( $sth->execute ) { print "Error: $sqlstmt ($sth->errstr)" }
$sqlstmt = "insert into setup values('host_profile','monarch_ez','$ez{host_profile}')";
$sth     = $dbh->prepare($sqlstmt);
unless ( $sth->execute ) { print "Error: $sqlstmt ($sth->errstr)" }
$sqlstmt = "insert into setup values('contactgroup','monarch_ez','$ez{contactgroup}')";
$sth     = $dbh->prepare($sqlstmt);
unless ( $sth->execute ) { print "Error: $sqlstmt ($sth->errstr)" }
$sqlstmt = "insert into setup values('contact_template','monarch_ez','$ez{contact_template}')";
$sth     = $dbh->prepare($sqlstmt);
unless ( $sth->execute ) { print "Error: $sqlstmt ($sth->errstr)" }

##############################################################################
# Prepare for database transformations
##############################################################################

print "\n\tChecking tables ...\n\n";

$sth = $dbh->prepare('show tables');
$sth->execute;
my %tables = ();
while ( my @values = $sth->fetchrow_array() ) {
    $tables{ $values[0] } = 1;
}
$sth->finish;

##############################################################################
# Check for and set InnoDB
##############################################################################

my %table_types = ();
$sqlstmt = 'show table status';
$sth     = $dbh->prepare($sqlstmt);
$sth->execute();
%fields = ();
while ( my @values = $sth->fetchrow_array() ) {
    $table_types{ $values[0] } = $values[1];
}
$sth->finish;

foreach my $table ( keys %table_types ) {
    unless ( $table_types{$table} =~ /InnoDB/i ) {
	$dbh->do("ALTER TABLE $table type = 'InnoDB'");
    }
}

##############################################################################
# New Tables
##############################################################################

#-----------------------------------------------------------------------------
# Service Profile Host Profile
#-----------------------------------------------------------------------------

unless ( $tables{'profile_host_profile_service'} ) {
    $dbh->do(
	"CREATE TABLE profile_host_profile_service (hostprofile_id SMALLINT(4) UNSIGNED,
	    serviceprofile_id SMALLINT(4) UNSIGNED,
	    PRIMARY KEY (hostprofile_id,serviceprofile_id),
	    FOREIGN KEY (serviceprofile_id) REFERENCES profiles_service(serviceprofile_id) ON DELETE CASCADE,
	    FOREIGN KEY (hostprofile_id) REFERENCES profiles_host(hostprofile_id) ON DELETE CASCADE) TYPE=INNODB"
    );
}

#-----------------------------------------------------------------------------
# Service Profile Host
#-----------------------------------------------------------------------------

unless ( $tables{'serviceprofile_host'} ) {
    $dbh->do(
	"CREATE TABLE serviceprofile_host (serviceprofile_id SMALLINT(4) UNSIGNED,
	    host_id INT(6) UNSIGNED,
	    PRIMARY KEY (serviceprofile_id,host_id),
	    FOREIGN KEY (serviceprofile_id) REFERENCES profiles_service(serviceprofile_id) ON DELETE CASCADE,
	    FOREIGN KEY (host_id) REFERENCES hosts(host_id) ON DELETE CASCADE) TYPE=INNODB"
    );
}

#-----------------------------------------------------------------------------
# Service Profile Hostgroup
#-----------------------------------------------------------------------------

unless ( $tables{'serviceprofile_hostgroup'} ) {
    $dbh->do(
	"CREATE TABLE serviceprofile_hostgroup (serviceprofile_id SMALLINT(4) UNSIGNED,
	    hostgroup_id SMALLINT(4) UNSIGNED,
	    PRIMARY KEY (serviceprofile_id,hostgroup_id),
	    FOREIGN KEY (serviceprofile_id) REFERENCES profiles_service(serviceprofile_id) ON DELETE CASCADE,
	    FOREIGN KEY (hostgroup_id) REFERENCES hostgroups(hostgroup_id) ON DELETE CASCADE) TYPE=INNODB"
    );
}

#-----------------------------------------------------------------------------
# Host Profile Overrides
#-----------------------------------------------------------------------------

unless ( $tables{'hostprofile_overrides'} ) {
    $dbh->do(
	"CREATE TABLE hostprofile_overrides (hostprofile_id SMALLINT(4) UNSIGNED PRIMARY KEY,
	    check_period SMALLINT(4) UNSIGNED,
	    notification_period SMALLINT(4) UNSIGNED,
	    check_command SMALLINT(4) UNSIGNED,
	    event_handler SMALLINT(4) UNSIGNED,
	    data TEXT,
	    FOREIGN KEY (hostprofile_id) REFERENCES profiles_host(hostprofile_id) ON DELETE CASCADE) TYPE=INNODB"
    );
}

#-----------------------------------------------------------------------------
# Contact Overrides
#-----------------------------------------------------------------------------

unless ( $tables{'contact_overrides'} ) {
    $dbh->do(
	"CREATE TABLE contact_overrides (contact_id SMALLINT(4) UNSIGNED PRIMARY KEY,
	    host_notification_period SMALLINT(4) UNSIGNED,
	    service_notification_period SMALLINT(4) UNSIGNED,
	    data TEXT,
	    FOREIGN KEY (contact_id) REFERENCES contacts(contact_id) ON DELETE CASCADE)	TYPE=INNODB"
    );
}

#-----------------------------------------------------------------------------
# Contact Command Overrides
#-----------------------------------------------------------------------------

unless ( $tables{'contact_command_overrides'} ) {
    $dbh->do(
	"CREATE TABLE contact_command_overrides (contact_id SMALLINT(4) UNSIGNED,
	    type VARCHAR(50),
	    command_id SMALLINT(4) UNSIGNED,
	    PRIMARY KEY (contact_id,type,command_id),
	    FOREIGN KEY (command_id) REFERENCES commands(command_id) ON DELETE CASCADE,
	    FOREIGN KEY (contact_id) REFERENCES contacts(contact_id) ON DELETE CASCADE) TYPE=INNODB"
    );
}

#-----------------------------------------------------------------------------
# Service Name Overrides
#-----------------------------------------------------------------------------

unless ( $tables{'servicename_overrides'} ) {
    $dbh->do(
	"CREATE TABLE servicename_overrides (servicename_id SMALLINT(4) UNSIGNED PRIMARY KEY,
	    check_period SMALLINT(4) UNSIGNED,
	    notification_period SMALLINT(4) UNSIGNED,
	    event_handler SMALLINT(4) UNSIGNED,
	    data TEXT,
	    FOREIGN KEY (servicename_id) REFERENCES service_names(servicename_id) ON DELETE CASCADE) TYPE=INNODB"
    );
}

#-----------------------------------------------------------------------------
# Service Instance
#-----------------------------------------------------------------------------

unless ( $tables{'service_instance'} ) {
    $dbh->do(
	"CREATE TABLE service_instance (instance_id INT(8) UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	    service_id INT(8) UNSIGNED,
	    name VARCHAR(255) NOT NULL,
	    status TINYINT(1) DEFAULT '0',
	    arguments VARCHAR(255),
	    FOREIGN KEY (service_id) REFERENCES services(service_id) ON DELETE CASCADE) TYPE=INNODB"
    );
}

#-----------------------------------------------------------------------------
# Service Name Dependency
#-----------------------------------------------------------------------------

unless ( $tables{'servicename_dependency'} ) {
    $dbh->do(
	"CREATE TABLE servicename_dependency (id SMALLINT(4) UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	    servicename_id SMALLINT(4) UNSIGNED NOT NULL,
	    depend_on_host_id INT(6) UNSIGNED,
	    template SMALLINT(4) UNSIGNED NOT NULL,
	    INDEX (servicename_id),
	    FOREIGN KEY (servicename_id) REFERENCES service_names(servicename_id) ON DELETE CASCADE,
	    FOREIGN KEY (depend_on_host_id) REFERENCES hosts(host_id) ON DELETE CASCADE) TYPE=INNODB"
    );
}

#-----------------------------------------------------------------------------
# Performance and import tables
#-----------------------------------------------------------------------------

unless ( $tables{'import_hosts'} ) {
    $dbh->do(
	"CREATE TABLE import_hosts (import_hosts_id smallint(4) unsigned NOT NULL auto_increment,
	    name varchar(255) default NULL,
	    alias varchar(255) default NULL,
	    address varchar(255) default NULL,
	    hostprofile_id smallint(4) unsigned default NULL,
	    PRIMARY KEY  (import_hosts_id),
	    UNIQUE KEY name (name)) ENGINE=InnoDB DEFAULT CHARSET=latin1"
    );
}

unless ( $tables{'import_services'} ) {
    $dbh->do(
	"CREATE TABLE import_services (import_services_id smallint(4) unsigned NOT NULL auto_increment,
	    import_hosts_id smallint(4) unsigned default NULL,
	    description varchar(255) default NULL,
	    check_command_id smallint(4) unsigned default NULL,
	    command_line varchar(255) default NULL,
	    command_line_trans varchar(255) default NULL,
	    servicename_id smallint(4) unsigned default NULL,
	    serviceprofile_id smallint(4) unsigned default NULL,
	    PRIMARY KEY  (import_services_id)) ENGINE=InnoDB DEFAULT CHARSET=latin1"
    );
}

unless ( $tables{'datatype'} ) {
    $dbh->do(
	"CREATE TABLE datatype (datatype_id int(8) unsigned NOT NULL auto_increment,
	    type varchar(100) NOT NULL default '',
	    location varchar(255) NOT NULL default '',
	    PRIMARY KEY  (datatype_id)) ENGINE=InnoDB DEFAULT CHARSET=latin1"
    );
}

unless ( $tables{'host_service'} ) {
    $dbh->do(
	"CREATE TABLE host_service (host_service_id int(8) unsigned NOT NULL auto_increment,
	    host varchar(100) NOT NULL default '',
	    service varchar(100) NOT NULL default '',
	    label varchar(100) NOT NULL default '',
	    dataname varchar(100) NOT NULL default '',
	    datatype_id int(8) unsigned default '0',
	    PRIMARY KEY  (host_service_id)) ENGINE=InnoDB DEFAULT CHARSET=latin1"
    );
}

unless ( $tables{'performanceconfig'} ) {
    $dbh->do(
	"CREATE TABLE performanceconfig (
	    performanceconfig_id int(8) unsigned NOT NULL auto_increment,
	    host varchar(100) NOT NULL default '',
	    service varchar(100) NOT NULL default '',
	    type varchar(100) NOT NULL default '',
	    enable tinyint(1) default '0',
	    parseregx_first tinyint(1) default '0',
	    service_regx tinyint(1) default '0',
	    label varchar(100) NOT NULL default '',
	    rrdname varchar(100) NOT NULL default '',
	    rrdcreatestring text NOT NULL,
	    rrdupdatestring text NOT NULL,
	    graphcgi text,
	    perfidstring varchar(100) NOT NULL default '',
	    parseregx varchar(255) NOT NULL default '',
	    PRIMARY KEY  (performanceconfig_id),
	    UNIQUE KEY host (host,service)) ENGINE=InnoDB DEFAULT CHARSET=latin1"
    );

    $dbh->do("LOCK TABLES performanceconfig WRITE");
    $dbh->do(
	"INSERT INTO performanceconfig VALUES
	(1,'*','Current Load','nagios',1,0,0,'Current Load - 15 Minute Average','\$HOST\$_Current_Load.rrd','\$RRDTOOL\$ create \$RRDNAME\$ --step 300 --start n-1yr DS:\$LABEL3\$:GAUGE:1800:U:U RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480','\$RRDTOOL\$ update \$RRDNAME\$ \$LASTCHECK\$:\$VALUE3\$ 2>&1','\'\'','',''),
	(2,'*','Current Users','nagios',1,0,0,'Current Users','\$HOST\$_Current_Users.rrd','\$RRDTOOL\$ create \$RRDNAME\$ --step 300 --start n-1yr DS:\$LABEL1\$:GAUGE:1800:U:U RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480','\$RRDTOOL\$ update \$RRDNAME\$ \$LASTCHECK\$:\$VALUE1\$ 2>&1','','',''),
	(3,'*','Root Partition','nagios',1,0,0,'Disk Utilization','\$HOST\$_Root_Partition.rrd','\$RRDTOOL\$ create \$RRDNAME\$ --step 300 --start n-1yr DS:root:GAUGE:1800:U:U RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480','\$RRDTOOL\$ update \$RRDNAME\$ \$LASTCHECK\$:\$VALUE1\$ 2>&1','','',''),
	(4,'*','snmp_if_','nagios',1,1,1,'Interface Statistics','\$HOST\$_\$SERVICE\$.rrd','\$RRDTOOL\$ create \$RRDNAME\$ --step 300 --start n-1yr DS:in:COUNTER:1800:U:U DS:out:COUNTER:1800:U:U DS:indis:COUNTER:1800:U:U DS:outdis:COUNTER:1800:U:U DS:inerr:COUNTER:1800:U:U  DS:outerr:COUNTER:1800:U:U RRA:AVERAGE:0.5:1:2880 RRA:AVERAGE:0.5:5:4032','\$RRDTOOL\$ update \$RRDNAME\$ -t in:out:indis:outdis:inerr:outerr \$LASTCHECK\$:\$VALUE1\$:\$VALUE2\$:\$VALUE3\$:\$VALUE4\$:\$VALUE5\$:\$VALUE6\$  2>&1','',' ','SNMP OK - (\\d+)\\s(\\d+)\\s(\\d+)\\s(\\d+)\\s(\\d+)\\s(\\d+)'),
	(5,'*','snmp_ifbandwidth_','nagios',1,NULL,1,'Interface Bandwidth Utilization','\$HOST\$_\$SERVICE\$.rrd','\$RRDTOOL\$ create \$RRDNAME\$ --step 300 --start n-1yr DS:in:COUNTER:1800:U:U DS:out:COUNTER:1800:U:U DS:ifspeed:GAUGE:1800:U:U RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480','\$RRDTOOL\$ update \$RRDNAME\$ -t in:out:ifspeed \$LASTCHECK\$:\$VALUE1\$:\$VALUE2\$:\$VALUE3\$ 2>&1','',' ','SNMP OK - (\\d+)\\s+(\\d+)\\s+(\\d+)'),
	(6,'*','ssh_memory','nagios',1,NULL,NULL,'Memory Utilization','\$HOST\$_\$SERVICE\$.rrd','\$RRDTOOL\$ create \$RRDNAME\$ --step 300 --start n-1yr DS:percent:GAUGE:1800:U:U RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480','\$RRDTOOL\$ update \$RRDNAME\$ \$LASTCHECK\$:\$VALUE1\$ 2>&1','',' ','pct:\\s+([\\d\\.]+)'),
	(7,'*','ssh_swap','nagios',1,1,NULL,'Swap Utilization','\$HOST\$_\$SERVICE\$.rrd','\$RRDTOOL\$ create \$RRDNAME\$ --step 300 --start n-1yr DS:percent:GAUGE:1800:U:U RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480','\$RRDTOOL\$ update \$RRDNAME\$ \$LASTCHECK\$:\$VALUE1\$ 2>&1','',' ','([\\d\\.]+)% free'),
	(8,'*','ssh_disk','nagios',1,NULL,1,'Disk Utilization','\$HOST\$_\$SERVICE\$.rrd','\$RRDTOOL\$ create \$RRDNAME\$ --step 300 --start n-1yr DS:disk:GAUGE:1800:U:U DS:warning:GAUGE:1800:U:U DS:critical:GAUGE:1800:U:U RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480','\$RRDTOOL\$ update \$RRDNAME\$ \$LASTCHECK\$:\$VALUE1\$:\$WARN1\$:\$CRIT1\$ 2>&1','',' ',' '),
	(9,'*','ssh_load','nagios',1,NULL,NULL,'Load Averages','\$HOST\$_\$SERVICE\$.rrd','\$RRDTOOL\$ create \$RRDNAME\$ --step 300 --start n-1yr DS:load1:GAUGE:1800:U:U DS:load5:GAUGE:1800:U:U DS:load15:GAUGE:1800:U:U RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480','\$RRDTOOL\$ update \$RRDNAME\$ -t load1:load5:load15 \$LASTCHECK\$:\$VALUE1\$:\$VALUE2\$:\$VALUE3\$ 2>&1','',' ',' '),
	(10,'*','tcp_ssh','nagios',1,NULL,NULL,'SSH Response Time','\$HOST\$_\$SERVICE\$.rrd','\$RRDTOOL\$ create \$RRDNAME\$ --step 300 --start n-1yr DS:number:GAUGE:1800:U:U RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480','\$RRDTOOL\$ update \$RRDNAME\$ \$LASTCHECK\$:\$VALUE1\$ 2>&1','',' ',' '),
	(11,'*','ssh_process','nagios',1,1,1,'Process Count','\$HOST\$_\$SERVICE\$.rrd','\$RRDTOOL\$ create \$RRDNAME\$ --step 300 --start n-1yr DS:number:GAUGE:1800:U:U RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480','\$RRDTOOL\$ update \$RRDNAME\$ \$LASTCHECK\$:\$VALUE1\$ 2>&1','',' ','(\\d+) process'),
	(12,'*','icmp_ping_alive','nagios',1,NULL,NULL,'ICMP Ping Response Time','\$HOST\$_\$SERVICE\$.rrd','\$RRDTOOL\$ create \$RRDNAME\$ --step 300 --start n-1yr DS:\$LABEL1\$:GAUGE:1800:U:U RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480','\$RRDTOOL\$ update \$RRDNAME\$ \$LASTCHECK\$:\$VALUE1\$ 2>&1','',' ',' '),
	(13,'*','icmp_ping','nagios',1,1,0,'ICMP Ping Response Time','\$HOST\$_\$SERVICE\$.rrd','\$RRDTOOL\$ create \$RRDNAME\$ --step 300 --start n-1yr DS:rta:GAUGE:1800:U:U RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480','\$RRDTOOL\$ update \$RRDNAME\$ \$LASTCHECK\$:\$VALUE1\$ 2>&1','rrdtool graph - --imgformat=PNG --title=\"ICMP Performance\" --rigid --base=1000 --height=120 --width=700 --alt-autoscale-max --lower-limit=0 --vertical-label=\"Time and Percent\" --slope-mode DEF:a=\"rrd_source\":ds_source_1:AVERAGE DEF:b=\"rrd_source\":ds_source_0:AVERAGE CDEF:cdefa=b CDEF:cdefb=a,100,/ AREA:cdefa#43C6DB:\"Response Time (ms) \" GPRINT:cdefa:LAST:\"Current\\:%8.2lf %s\" GPRINT:cdefa:AVERAGE:\"Average\\:%8.2lf %s\" GPRINT:cdefa:MAX:\"Maximum\\:%8.2lf %s\\n\" LINE1:cdefb#307D7E:\"Percent Loss       \" GPRINT:cdefb:LAST:\"Current\\:%8.2lf %s\" GPRINT:cdefb:AVERAGE:\"Average\\:%8.2lf %s\" GPRINT:cdefb:MAX:\"Maximum\\:%8.2lf %s\"','',' RTA = ([\\d\\.]+)'),
	(14,'*','local_disk','nagios',1,NULL,1,'Disk Utilization','\$HOST\$_\$SERVICE\$.rrd','\$RRDTOOL\$ create \$RRDNAME\$ --step 300 --start n-1yr \$LISTSTART\$DS:\$LABEL#\$:GAUGE:1800:U:U\$LISTEND\$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480','\$RRDTOOL\$ update \$RRDNAME\$ \$LASTCHECK\$:\$VALUE1\$ 2>&1','\\'rrdtool graph - DEF:a=\"rrd_source\":ds_source_0:AVERAGE CDEF:cdefa=a CDEF:cdefb=a,0.99,* AREA:cdefa#F88017:percent GPRINT:cdefa:MIN:min=%.2lf GPRINT:cdefa:AVERAGE:avg=%.2lf GPRINT:cdefa:MAX:max=%.2lf AREA:cdefb#C35617: -c BACK#FFFFFF -c CANVAS#FFFFFF -c GRID#C0C0C0 -c MGRID#404040 -c ARROW#FFFFFF -Y --height 120 --rigid -u 100 -l 0\\'','',' '),
	(15,'*','local_load','nagios',1,NULL,NULL,'Load Averages','\$HOST\$_\$SERVICE\$.rrd','\$RRDTOOL\$ create \$RRDNAME\$ --step 300 --start n-1yr DS:load1:GAUGE:1800:U:U DS:load5:GAUGE:1800:U:U DS:load15:GAUGE:1800:U:U  RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480','\$RRDTOOL\$ update \$RRDNAME\$ \$LASTCHECK\$:\$VALUE1\$:\$VALUE2\$:\$VALUE3\$ 2>&1','rrdtool graph - --imgformat=PNG --slope-mode DEF:a=rrd_source:load1:AVERAGE DEF:b=rrd_source:load5:AVERAGE DEF:c=rrd_source:load15:AVERAGE CDEF:cdefa=a CDEF:cdefb=b CDEF:cdefc=c AREA:cdefa#FF6600:\"One Minute Load Average\" GPRINT:cdefa:MIN:min=%.2lf GPRINT:cdefa:AVERAGE:avg=%.2lf GPRINT:cdefa:MAX:\"max=%.2lf \n\" LINE2:cdefb#6666CC:\"Five Minute Load Average\" GPRINT:cdefb:MIN:min=%.2lf GPRINT:cdefb:AVERAGE:avg=%.2lf GPRINT:cdefb:MAX:\"max=%.2lf \n\" LINE3:cdefc#999999:\"Fifteen Minute Load Average\"    GPRINT:cdefc:MIN:min=%.2lf GPRINT:cdefc:AVERAGE:avg=%.2lf GPRINT:cdefc:MAX:\"max=%.2lf \n\" -c BACK#FFFFFF -c CANVAS#FFFFFF -c GRID#C0C0C0 -c MGRID#404040 -c ARROW#FFFFFF-Y --height 120\n','',' '),
	(16,'*','local_mem','nagios',1,1,NULL,'Memory Utilization','\$HOST\$_\$SERVICE\$.rrd','\$RRDTOOL\$ create \$RRDNAME\$ --step 300 --start n-1yr DS:percent:GAUGE:1800:U:U RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480','\$RRDTOOL\$ update \$RRDNAME\$ \$LASTCHECK\$:\$VALUE1\$ 2>&1','/graphs/cgi-bin/percent_graph.cgi',' ','([\\d\\.]+)%'),
	(17,'*','local_mysql_engine','nagios',1,1,1,'MySQL Queries Per Second','\$HOST\$_\$SERVICE\$.rrd','\$RRDTOOL\$ create \$RRDNAME\$ --step 300 --start n-1yr DS:number:GAUGE:1800:U:U RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480','\$RRDTOOL\$ update \$RRDNAME\$ \$LASTCHECK\$:\$VALUE1\$ 2>&1','/graphs/cgi-bin/number_graph.cgi',' ','Queries per second avg: ([\\d\\.]+)'),
	(18,'*','local_process','nagios',1,1,1,'Process Count','\$HOST\$_\$SERVICE\$.rrd','\$RRDTOOL\$ create \$RRDNAME\$ --step 300 --start n-1yr DS:number:GAUGE:1800:U:U RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480','\$RRDTOOL\$ update \$RRDNAME\$ \$LASTCHECK\$:\$VALUE1\$ 2>&1','/graphs/cgi-bin/number_graph.cgi',' ','(\\d+) process'),
	(19,'*','local_nagios_latency','nagios',1,NULL,NULL,'Nagios Service Check Latency in Seconds','\$HOST\$_\$SERVICE\$.rrd','\$RRDTOOL\$ create \$RRDNAME\$ --step 300 --start n-1yr DS:min:GAUGE:1800:U:U DS:max:GAUGE:1800:U:U DS:avg:GAUGE:1800:U:U RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480','\$RRDTOOL\$ update \$RRDNAME\$ \$LASTCHECK\$:\$VALUE1\$:\$VALUE2\$:\$VALUE3\$ 2>&1','/graphs/cgi-bin/number_graph.cgi',' ',' '),
	(20,'*','tcp_nsca','nagios',1,NULL,NULL,'NSCA Response Time','\$HOST\$_\$SERVICE\$.rrd','\$RRDTOOL\$ create \$RRDNAME\$ --step 300 --start n-1yr DS:\$LABEL1\$:GAUGE:1800:U:U RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480','\$RRDTOOL\$ update \$RRDNAME\$ \$LASTCHECK\$:\$VALUE1\$ 2>&1','/graphs/cgi-bin/label_graph.cgi',' ',' '),
	(22,'*','local_mysql_database','nagios',1,1,1,'MySQL Queries Per Second','\$HOST\$_\$SERVICE\$.rrd','\$RRDTOOL\$ create \$RRDNAME\$ --step 300 --start n-1yr DS:number:GAUGE:1800:U:U RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480','\$RRDTOOL\$ update \$RRDNAME\$ \$LASTCHECK\$:\$VALUE1\$ 2>&1','/graphs/cgi-bin/number_graph.cgi',' ','Queries per second avg: ([\\d\\.]+)'),
	(28,'*','DEFAULT','nagios',1,0,0,'DO NOT REMOVE THIS ENTRY - USE TO DEFINE DEFAULT GRAPHING SETTINGS','','','','rrdtool graph - \$LISTSTART\$ DEF:\$DEFLABEL#\$:AVERAGE CDEF:cdef\$CDEFLABEL#\$=\$CDEFLABEL#\$ LINE:\$CDEFLABEL#\$\$COLORLABEL#\$:\$DSLABEL#\$ GPRINT:\$CDEFLABEL#\$:MIN:min=%.2lf GPRINT:\$CDEFLABEL#\$:AVERAGE:avg=%.2lf GPRINT:\$CDEFLABEL#\$:MAX:max=%.2lf  \$LISTEND\$  -c BACK#FFFFFF -c CANVAS#FFFFFF -c GRID#C0C0C0 -c MGRID#404040 -c ARROW#FFFFFF -Y --height 120','',''),
	(29,'*','local_users','nagios',1,0,0,'Current Users','\$HOST\$_\$SERVICE\$.rrd','\$RRDTOOL\$ create \$RRDNAME\$ --step 300 --start n-1yr DS:\$LABEL1\$:GAUGE:1800:U:U RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480','\$RRDTOOL\$ update \$RRDNAME\$ \$LASTCHECK\$:\$VALUE1\$ 2>&1','rrdtool graph - --imgformat=PNG --slope-mode DEF:a=rrd_source:ds_source_0:AVERAGE  CDEF:cdefa=a  AREA:cdefa#0033CC:\"Number of logged in users\" -c BACK#FFFFFF -c CANVAS#FFFFFF -c GRID#C0C0C0 -c MGRID#404040 -c ARROW#FFFFFF-Y --height 120','','')"
    );
    $dbh->do("UNLOCK TABLES");
}

#-----------------------------------------------------------------------------
# Groups
#-----------------------------------------------------------------------------

unless ( $tables{'monarch_groups'} ) {
    $dbh->do(
	"CREATE TABLE monarch_groups (group_id SMALLINT(4) UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	    name VARCHAR(255),
	    description VARCHAR(255),
	    location TEXT,
	    status TINYINT(1) DEFAULT '0',
	    data TEXT) TYPE=INNODB"
    );
}

unless ( $tables{'monarch_macros'} ) {
    $dbh->do(
	"CREATE TABLE monarch_macros (macro_id SMALLINT(4) UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	    name VARCHAR(255),
	    value VARCHAR(255),
	    description VARCHAR(255)) TYPE=INNODB"
    );
}

unless ( $tables{'monarch_group_host'} ) {
    $dbh->do(
	"CREATE TABLE monarch_group_host (group_id SMALLINT(4) UNSIGNED,
	    host_id INT(6) UNSIGNED,
	    PRIMARY KEY (group_id,host_id),
	    FOREIGN KEY (group_id) REFERENCES monarch_groups(group_id) ON DELETE CASCADE,
	    FOREIGN KEY (host_id) REFERENCES hosts(host_id) ON DELETE CASCADE) TYPE=INNODB"
    );
}

unless ( $tables{'monarch_group_hostgroup'} ) {
    $dbh->do(
	"CREATE TABLE monarch_group_hostgroup (group_id SMALLINT(4) UNSIGNED,
	    hostgroup_id SMALLINT(4) UNSIGNED,
	    PRIMARY KEY (group_id,hostgroup_id),
	    FOREIGN KEY (group_id) REFERENCES monarch_groups(group_id) ON DELETE CASCADE,
	    FOREIGN KEY (hostgroup_id) REFERENCES hostgroups(hostgroup_id) ON DELETE CASCADE) TYPE=INNODB"
    );
}

unless ( $tables{'monarch_group_child'} ) {
    $dbh->do(
	"CREATE TABLE monarch_group_child (group_id SMALLINT(4) UNSIGNED,
	    child_id SMALLINT(4) UNSIGNED,
	    PRIMARY KEY (group_id,child_id),
	    FOREIGN KEY (group_id) REFERENCES monarch_groups(group_id) ON DELETE CASCADE,
	    FOREIGN KEY (child_id) REFERENCES monarch_groups(group_id) ON DELETE CASCADE) TYPE=INNODB"
    );

}

unless ( $tables{'monarch_group_macro'} ) {
    $dbh->do(
	"CREATE TABLE monarch_group_macro (group_id SMALLINT(4) UNSIGNED,
	    macro_id SMALLINT(4) UNSIGNED,
	    value VARCHAR(255),
	    PRIMARY KEY (group_id,macro_id),
	    FOREIGN KEY (group_id) REFERENCES monarch_groups(group_id) ON DELETE CASCADE,
	    FOREIGN KEY (macro_id) REFERENCES monarch_macros(macro_id) ON DELETE CASCADE) TYPE=INNODB"
    );

}

unless ( $tables{'monarch_group_props'} ) {
    $dbh->do(
	"CREATE TABLE monarch_group_props (prop_id SMALLINT(4) UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	    group_id SMALLINT(4) UNSIGNED,
	    name VARCHAR(255),
	    type VARCHAR(20),
	    value VARCHAR(255),
	    FOREIGN KEY (group_id) REFERENCES monarch_groups(group_id) ON DELETE CASCADE) TYPE=INNODB"
    );
}

unless ( $tables{'sessions'} ) {
    $dbh->do(
	"CREATE TABLE sessions (id CHAR(32) NOT NULL UNIQUE,
	    a_session TEXT NOT NULL)"
    );
}

#-----------------------------------------------------------------------------
# Tables to support integration with other tools 2007-Jan-16
#-----------------------------------------------------------------------------

unless ( $tables{'import_schema'} ) {
    $dbh->do(
	"CREATE TABLE import_schema (schema_id SMALLINT(4) UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	    name VARCHAR(255),
	    delimiter VARCHAR(50),
	    description TEXT,
	    type VARCHAR(255),
	    sync_object varchar(50),
	    smart_name TINYINT(1) DEFAULT '0',
	    hostprofile_id SMALLINT(4) UNSIGNED DEFAULT '0',
	    data_source VARCHAR(255),
	    FOREIGN KEY (hostprofile_id) REFERENCES profiles_host(hostprofile_id) ON DELETE CASCADE) TYPE=INNODB"
    );
}

unless ( $tables{'import_column'} ) {
    $dbh->do(
	"CREATE TABLE import_column (column_id SMALLINT(4) UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	    schema_id SMALLINT(4) UNSIGNED,
	    name VARCHAR(255),
	    position SMALLINT(4) UNSIGNED,
	    delimiter VARCHAR(50),
	    FOREIGN KEY (schema_id) REFERENCES import_schema(schema_id) ON DELETE CASCADE) TYPE=INNODB"
    );
}

unless ( $tables{'import_match'} ) {
    $dbh->do(
	"CREATE TABLE import_match (match_id SMALLINT(4) UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	    column_id SMALLINT(4) UNSIGNED,
	    name VARCHAR(255),
	    match_order SMALLINT(4) UNSIGNED,
	    match_type VARCHAR(255),
	    match_string VARCHAR(255),
	    rule VARCHAR(255),
	    object VARCHAR(255),
	    hostprofile_id SMALLINT(4) UNSIGNED,
	    FOREIGN KEY (hostprofile_id) REFERENCES profiles_host(hostprofile_id) ON DELETE CASCADE,
	    FOREIGN KEY (column_id) REFERENCES import_column(column_id) ON DELETE CASCADE) TYPE=INNODB"
    );
}

unless ( $tables{'import_match_parent'} ) {
    $dbh->do(
	"CREATE TABLE import_match_parent (match_id SMALLINT(4) UNSIGNED,
	    parent_id INT(6) UNSIGNED,
	    PRIMARY KEY (match_id,parent_id),
	    FOREIGN KEY (parent_id) REFERENCES hosts(host_id) ON DELETE CASCADE,
	    FOREIGN KEY (match_id) REFERENCES import_match(match_id) ON DELETE CASCADE) TYPE=INNODB"
    );
}

unless ( $tables{'import_match_hostgroup'} ) {
    $dbh->do(
	"CREATE TABLE import_match_hostgroup (match_id SMALLINT(4) UNSIGNED,
	    hostgroup_id SMALLINT(4) UNSIGNED,
	    PRIMARY KEY (match_id,hostgroup_id),
	    FOREIGN KEY (hostgroup_id) REFERENCES hostgroups(hostgroup_id) ON DELETE CASCADE,
	    FOREIGN KEY (match_id) REFERENCES import_match(match_id) ON DELETE CASCADE) TYPE=INNODB"
    );
}

unless ( $tables{'import_match_group'} ) {
    $dbh->do(
	"CREATE TABLE import_match_group (match_id SMALLINT(4) UNSIGNED,
	    group_id SMALLINT(4) UNSIGNED,
	    PRIMARY KEY (match_id,group_id),
	    FOREIGN KEY (group_id) REFERENCES monarch_groups(group_id) ON DELETE CASCADE,
	    FOREIGN KEY (match_id) REFERENCES import_match(match_id) ON DELETE CASCADE) TYPE=INNODB"
    );
}

unless ( $tables{'import_match_contactgroup'} ) {
    $dbh->do(
	"CREATE TABLE import_match_contactgroup (match_id SMALLINT(4) UNSIGNED,
	    contactgroup_id SMALLINT(4) UNSIGNED,
	    PRIMARY KEY (match_id,contactgroup_id),
	    FOREIGN KEY (contactgroup_id) REFERENCES contactgroups(contactgroup_id) ON DELETE CASCADE,
	    FOREIGN KEY (match_id) REFERENCES import_match(match_id) ON DELETE CASCADE) TYPE=INNODB"
    );
}

unless ( $tables{'import_match_serviceprofile'} ) {
    $dbh->do(
	"CREATE TABLE import_match_serviceprofile (match_id SMALLINT(4) UNSIGNED,
	    serviceprofile_id SMALLINT(4) UNSIGNED,
	    PRIMARY KEY (match_id,serviceprofile_id),
	    FOREIGN KEY (serviceprofile_id) REFERENCES profiles_service(serviceprofile_id) ON DELETE CASCADE,
	    FOREIGN KEY (match_id) REFERENCES import_match(match_id) ON DELETE CASCADE) TYPE=INNODB"
    );
}

#-----------------------------------------------------------------------------
# Tables to support autodiscovery 2007-Sep-18
#-----------------------------------------------------------------------------

unless ( $tables{'discover_group'} ) {
    $dbh->do(
	"CREATE TABLE discover_group (group_id SMALLINT(4) UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	    name VARCHAR(255),
	    description TEXT,
	    config TEXT,
	    schema_id SMALLINT(4) UNSIGNED,
	    FOREIGN KEY (schema_id) REFERENCES import_schema(schema_id) ON DELETE CASCADE) TYPE=INNODB"
    );
}

unless ( $tables{'discover_method'} ) {
    $dbh->do(
	"CREATE TABLE discover_method (method_id SMALLINT(4) UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	    name VARCHAR(255),
	    description TEXT,
	    config TEXT,
	    type VARCHAR(50)) TYPE=INNODB"
    );
}

unless ( $tables{'discover_filter'} ) {
    $dbh->do(
	"CREATE TABLE discover_filter (filter_id SMALLINT(4) UNSIGNED AUTO_INCREMENT PRIMARY KEY,
	    name VARCHAR(255),
	    type VARCHAR(50),
	    filter TEXT) TYPE=INNODB"
    );
}

unless ( $tables{'discover_group_filter'} ) {
    $dbh->do(
	"CREATE TABLE discover_group_filter (group_id SMALLINT(4) UNSIGNED,
	    filter_id SMALLINT(4) UNSIGNED,
	    PRIMARY KEY (group_id,filter_id),
	    FOREIGN KEY (group_id) REFERENCES discover_group(group_id) ON DELETE CASCADE,
	    FOREIGN KEY (filter_id) REFERENCES discover_filter(filter_id) ON DELETE CASCADE) TYPE=INNODB"
    );
}

unless ( $tables{'discover_group_method'} ) {
    $dbh->do(
	"CREATE TABLE discover_group_method (group_id SMALLINT(4) UNSIGNED,
	    method_id SMALLINT(4) UNSIGNED,
	    PRIMARY KEY (group_id,method_id),
	    FOREIGN KEY (method_id) REFERENCES discover_method(method_id) ON DELETE CASCADE,
	    FOREIGN KEY (group_id) REFERENCES discover_group(group_id) ON DELETE CASCADE) TYPE=INNODB"
    );
}

unless ( $tables{'discover_method_filter'} ) {
    $dbh->do(
	"CREATE TABLE discover_method_filter (method_id SMALLINT(4) UNSIGNED,
	    filter_id SMALLINT(4) UNSIGNED,
	    PRIMARY KEY (method_id,filter_id),
	    FOREIGN KEY (method_id) REFERENCES discover_method(method_id) ON DELETE CASCADE,
	    FOREIGN KEY (filter_id) REFERENCES discover_filter(filter_id) ON DELETE CASCADE) TYPE=INNODB"
    );
}

##############################################################################
# Modify Existing Tables
##############################################################################

#-----------------------------------------------------------------------------
# Clean up orphaned associations
#-----------------------------------------------------------------------------

$dbh->do( "delete from profile_host_profile_service where serviceprofile_id not in (select serviceprofile_id from profiles_service)" );
$dbh->do( "delete from profile_host_profile_service where hostprofile_id not in (select hostprofile_id from profiles_host)" );
$dbh->do( "delete from serviceprofile_host where host_id not in (select host_id from hosts)" );
$dbh->do( "delete from serviceprofile where serviceprofile_id not in (select serviceprofile_id from profiles_service)" );
$dbh->do( "delete from serviceprofile where servicename_id not in (select servicename_id from profiles_service)" );
$dbh->do( "delete from escalation_tree_template where template_id not in (select template_id from escalation_templates)" );
$dbh->do( "delete from escalation_tree_template where tree_id not in (select tree_id from escalation_trees)" );
$dbh->do( "delete from tree_template_contactgroup where tree_id not in (select tree_id from escalation_trees)" );
$dbh->do( "delete from tree_template_contactgroup where contactgroup_id not in (select contactgroup_id from contactgroups)" );
$dbh->do( "delete from tree_template_contactgroup where template_id not in (select template_id from escalation_templates)" );

#-----------------------------------------------------------------------------
# Change column types to text
#-----------------------------------------------------------------------------

my %table_text = (
    'performanceconfig' => 'graphcgi',
    'services'          => 'command_line',
    'service_names'     => 'command_line',
    'setup'             => 'value'
);
foreach my $table ( keys %table_text ) {
    $sqlstmt = "describe $table";
    $sth = $dbh->prepare($sqlstmt);
    $sth->execute();
    my %fields = ();
    while ( my @values = $sth->fetchrow_array() ) {
	$fields{ $values[0] } = $values[1];
    }
    $sth->finish;
    unless ( $fields{ $table_text{$table} } =~ /text/i ) {
	$dbh->do("ALTER TABLE $table MODIFY $table_text{$table} TEXT");
    }
}

#-----------------------------------------------------------------------------
# Convert to smallint (while keeping a larger size if already present)
#-----------------------------------------------------------------------------

# Ordered by small to large size.
my %integral_type = (
    tinyint   => 0,
    smallint  => 1,
    mediumint => 2,
    int       => 3,
    bigint    => 4
);

# FIX MAJOR:  None of these alterations will actually do anything (in fact, they
# will likely fail if a field size change is actually attempted) unless we also
# take care to drop the associated foreign key constraints that reference these
# fields, alter those fields as well, and re-create the foreign key constraints.
# But note that some of those constraints are also managed by code elsewhere in
# this script, so we need to be careful about how they are dealt with here.

# time_periods.timeperiod_id:
#   escalation_templates.escalation_period:
#     CONSTRAINT `escalation_templates_ibfk_1` FOREIGN KEY (`escalation_period`) REFERENCES `time_periods` (`timeperiod_id`) ON DELETE SET NULL
#   time_period_exclude.timeperiod_id:
#     CONSTRAINT `time_period_exclude_ibfk_1` FOREIGN KEY (`timeperiod_id`) REFERENCES `time_periods` (`timeperiod_id`) ON DELETE CASCADE,
#   time_period_property.timeperiod_id:
#     CONSTRAINT `time_period_property_ibfk_1` FOREIGN KEY (`timeperiod_id`) REFERENCES `time_periods` (`timeperiod_id`) ON DELETE CASCADE
#
# extended_service_info_templates.serviceextinfo_id:
#   service_names.extinfo
#     CONSTRAINT `service_names_ibfk_1` FOREIGN KEY (`extinfo`) REFERENCES `extended_service_info_templates` (`serviceextinfo_id`) ON DELETE SET NULL,
#   services.serviceextinfo_id
#     CONSTRAINT `services_ibfk_2` FOREIGN KEY (`serviceextinfo_id`) REFERENCES `extended_service_info_templates` (`serviceextinfo_id`) ON DELETE SET NULL,
#
# extended_host_info_templates.hostextinfo_id
#   hosts.hostextinfo_id
#     CONSTRAINT `hosts_ibfk_1` FOREIGN KEY (`hostextinfo_id`) REFERENCES `extended_host_info_templates` (`hostextinfo_id`) ON DELETE SET NULL,
#   profiles_host.host_extinfo_id
#     CONSTRAINT `profiles_host_ibfk_1` FOREIGN KEY (`host_extinfo_id`) REFERENCES `extended_host_info_templates` (`hostextinfo_id`) ON DELETE SET NULL,

my %table_smallint = (
    'time_periods'                    => 'timeperiod_id',
    'extended_service_info_templates' => 'serviceextinfo_id',
    'extended_host_info_templates'    => 'hostextinfo_id'
);
foreach my $table ( keys %table_smallint ) {
    $sqlstmt = "describe $table";
    $sth = $dbh->prepare($sqlstmt);
    $sth->execute();
    my %fields = ();
    while ( my @values = $sth->fetchrow_array() ) {
	$fields{ $values[0] } = $values[1];
    }
    $sth->finish;
    $fields{ $table_smallint{$table} } =~ /^([a-z]*)/;
    if ( $integral_type{$1} < $integral_type{'smallint'} ) {
	$dbh->do( "ALTER TABLE $table MODIFY $table_smallint{$table} SMALLINT(4) UNSIGNED AUTO_INCREMENT" );
    }
}

#-----------------------------------------------------------------------------
# Convert to int
#-----------------------------------------------------------------------------

# GWMON-8036

my %table_int = (
    'datatype'          => { 'datatype_id'          => 'AUTO_INCREMENT' },
    'host_service'      => { 'host_service_id'      => 'AUTO_INCREMENT',
			     'datatype_id'          => "default '0'"    },
    'performanceconfig' => { 'performanceconfig_id' => 'AUTO_INCREMENT' }
);
foreach my $table ( keys %table_int ) {
    $sqlstmt = "describe $table";
    $sth = $dbh->prepare($sqlstmt);
    $sth->execute();
    my %fields = ();
    while ( my @values = $sth->fetchrow_array() ) {
	$fields{ $values[0] } = $values[1];
    }
    $sth->finish;
    foreach my $column ( keys %{ $table_int{$table} } ) {
	$fields{$column} =~ /^([a-z]*)/;
	if ( $integral_type{$1} < $integral_type{'int'} ) {
	    $dbh->do( "ALTER TABLE $table MODIFY $column INT(8) UNSIGNED $table_int{$table}{$column}" );
	}
    }
}

#-----------------------------------------------------------------------------
# Change names to varchar 255
#-----------------------------------------------------------------------------

foreach my $table ( keys %tables ) {
    $sqlstmt = "describe $table";
    $sth = $dbh->prepare($sqlstmt);
    $sth->execute();
    my %fields = ();
    while ( my @values = $sth->fetchrow_array() ) {
	$fields{ $values[0] } = $values[1];
    }
    $sth->finish;
    if ( $fields{'name'} ) {
	unless ( $fields{'name'} =~ /varchar\(255\)/i ) {
	    ## FIX MAJOR:  Also make sure we don't change the Null or Default settings
	    $dbh->do("ALTER TABLE $table MODIFY name varchar(255)");
	}
    }
    if ( $fields{'alias'} ) {
	unless ( $fields{'alias'} =~ /varchar\(255\)/i ) {
	    ## FIX MAJOR:  Also make sure we don't change the Null or Default settings
	    $dbh->do("ALTER TABLE $table MODIFY alias varchar(255)");
	}
    }
    if ( $fields{'address'} ) {
	unless ( $fields{'address'} =~ /varchar\(255\)/i ) {
	    ## FIX MAJOR:  Also make sure we don't change the Null or Default settings
	    $dbh->do("ALTER TABLE $table MODIFY name varchar(255)");
	}
    }
}

#-----------------------------------------------------------------------------
# Change related fields to varchar 255 (GWMON-9292)
#-----------------------------------------------------------------------------

my %short_fields = (
    'host_service'      => [ 'host', 'service' ],
    'performanceconfig' => [ 'host', 'service' ]
);

foreach my $table (keys %short_fields) {
    $sqlstmt = "describe $table";
    $sth = $dbh->prepare($sqlstmt);
    $sth->execute();
    my %fields = ();
    while ( my @values = $sth->fetchrow_array() ) {
	$fields{ $values[0] } = $values[1];
    }
    $sth->finish;
    my @modifications = ();
    foreach my $field (@{ $short_fields{$table} }) {
	if ( $fields{$field} ) {
	    unless ( $fields{$field} =~ /varchar\(255\)/i ) {
		# Extend the field width; leave the Null and Default settings as they were.
		# (We must set the Null and Default settings explicitly, as otherwise they
		# will be reset to values we don't want.)
		push @modifications, "MODIFY $field varchar(255) NOT NULL DEFAULT ''";
	    }
	}
    }
    if (@modifications) {
	$dbh->do("ALTER TABLE $table " . join(', ', @modifications));
    }
}

#-----------------------------------------------------------------------------
# Change contacts column pager and email to text
#-----------------------------------------------------------------------------

$sqlstmt = "describe contacts";
$sth = $dbh->prepare($sqlstmt);
$sth->execute();
%fields = ();
while ( my @values = $sth->fetchrow_array() ) {
    $fields{ $values[0] } = $values[1];
}
$sth->finish;
if ( $fields{'pager'} ) {
    unless ( $fields{'pager'} =~ /TEXT/i ) {
	$dbh->do("ALTER TABLE contacts MODIFY pager TEXT");
    }
}

if ( $fields{'email'} ) {
    unless ( $fields{'email'} =~ /TEXT/i ) {
	$dbh->do("ALTER TABLE contacts MODIFY email TEXT");
    }
}

#-----------------------------------------------------------------------------
# Change users session to varchar
#-----------------------------------------------------------------------------

$sqlstmt = "describe users";
$sth = $dbh->prepare($sqlstmt);
$sth->execute();
%fields = ();
while ( my @values = $sth->fetchrow_array() ) {
    $fields{ $values[0] } = $values[1];
}
$sth->finish;
if ( $fields{'session'} ) {
    unless ( $fields{'pager'} && $fields{'pager'} =~ /int/i ) {
	$dbh->do("ALTER TABLE users MODIFY session varchar(255)");
    }
}

#-----------------------------------------------------------------------------
# Update service templates
#-----------------------------------------------------------------------------

$sqlstmt = "describe service_templates";
$sth = $dbh->prepare($sqlstmt);
$sth->execute();
%fields = ();
while ( my @values = $sth->fetchrow_array() ) {
    $fields{ $values[0] } = $values[1];
}
$sth->finish;
unless ( $fields{'command_line'} ) {
    $dbh->do( "ALTER TABLE service_templates add command_line TEXT after check_command" );
    $sqlstmt = "select servicetemplate_id, data from service_templates";
    $sth     = $dbh->prepare($sqlstmt);
    $sth->execute();
    while ( my @values = $sth->fetchrow_array() ) {
	my %data = parse_xml( $values[1] );
	## FIX MAJOR:  Look for $data{'error'} and take evasive action if found.
	my $xml  = qq(<?xml version="1.0" ?>
<data>);
	my $command_line = '';
	foreach my $name ( keys %data ) {
	    if ( $name eq 'command_line' ) {
		$command_line = $data{$name};
	    }
	    else {
		$xml .= qq(
  <prop name="$name"><![CDATA[$data{$name}]]>
  </prop>);
	    }
	}
	$xml .= "\n</data>";
	$command_line = $dbh->quote($command_line);
	$xml          = $dbh->quote($xml);
	$dbh->do( "update service_templates set command_line = $command_line, data = $xml where servicetemplate_id = $values[0]" );
    }
    $sth->finish;
}

#-----------------------------------------------------------------------------
# Clean up bad service template references
# (This could possibly be extended to dangling references in other tables.)
#-----------------------------------------------------------------------------

# begin cleanup steps
$dbh->do( 'create temporary table service_templates_copy like service_templates' );

# get rid of dangling pointers
$dbh->do( 'insert into service_templates_copy select * from service_templates' );
$dbh->do( 'update service_templates set parent_id = NULL where (parent_id) not in (select servicetemplate_id from service_templates_copy)' );
$dbh->do( 'truncate service_templates_copy' );

# split open one-element loops
$dbh->do( 'update service_templates set parent_id = NULL where parent_id = servicetemplate_id' );

# split open two-element loops
$dbh->do( 'insert into service_templates_copy select * from service_templates' );
$dbh->do( 'update service_templates set parent_id = NULL where servicetemplate_id < parent_id and ' .
    '(servicetemplate_id, parent_id) in (select parent_id, servicetemplate_id from service_templates_copy)' );
$dbh->do( 'truncate service_templates_copy' );

# we won't bother with larger loops, as they're unlikely to occur (though not impossible)

# end cleanup steps
$dbh->do( 'drop table service_templates_copy' );

#-----------------------------------------------------------------------------
# Fix longstanding incorrect path names in the performance configuration
# table (the bad pathnames have been incorrect since at least GW5.1.3).
# This really only applies to existing entries during a migration,
# since we will no longer even use these paths starting with GW5.3.0.
#-----------------------------------------------------------------------------

# The following scripts never existed, as far as we can tell now.  But we will still convert the pathnames.
#    '/nagios/cgi-bin/load_graph.cgi'
#    '/nagios/cgi-bin/sar_cpu_graph.cgi'
#    '/nagios/cgi-bin/wmi_cpu_graph.cgi'
#    '/nagios/cgi-bin/wmi_disk_graph.cgi'
#    '/nagios/cgi-bin/wmi_mem_graph.cgi'
#    '/nagios/cgi-bin/wmi_printque_graph.cgi'
#    '/nagios/cgi-bin/wmi_swap_graph.cgi'
# FIX THIS:  also deal with these two mappings we have seen:
#    "''"                                     => '???',
#    '/'                                      => '???',
my %new_path = (
    '/nagios/cgi-bin/if_bandwidth_graph.cgi'  => '/graphs/cgi-bin/if_bandwidth_graph.cgi',
    '/nagios/cgi-bin/if_bandwidth_graph2.cgi' => '/graphs/cgi-bin/if_bandwidth_graph2.cgi',
    '/nagios/cgi-bin/if_bandwidth_graph3.cgi' => '/graphs/cgi-bin/if_bandwidth_graph3.cgi',
    '/nagios/cgi-bin/if_graph.cgi'            => '/graphs/cgi-bin/if_graph.cgi',
    '/nagios/cgi-bin/if_graph2.cgi'           => '/graphs/cgi-bin/if_graph2.cgi',
    '/nagios/cgi-bin/label_graph.cgi'         => '/graphs/cgi-bin/label_graph.cgi',
    '/nagios/cgi-bin/load_graph.cgi'          => '/graphs/cgi-bin/unixload_graph.cgi',
    '/nagios/cgi-bin/number_graph.cgi'        => '/graphs/cgi-bin/number_graph.cgi',
    '/nagios/cgi-bin/percent_graph.cgi'       => '/graphs/cgi-bin/percent_graph.cgi',
    '/nagios/cgi-bin/sar_cpu_graph.cgi'       => '/graphs/cgi-bin/sar_cpu_graph.cgi',
    '/nagios/cgi-bin/unixload_graph.cgi'      => '/graphs/cgi-bin/unixload_graph.cgi',
    '/nagios/cgi-bin/wmi_cpu_graph.cgi'       => '/graphs/cgi-bin/wmi_cpu_graph.cgi',
    '/nagios/cgi-bin/wmi_disk_graph.cgi'      => '/graphs/cgi-bin/wmi_disk_graph.cgi',
    '/nagios/cgi-bin/wmi_mem_graph.cgi'       => '/graphs/cgi-bin/wmi_mem_graph.cgi',
    '/nagios/cgi-bin/wmi_printque_graph.cgi'  => '/graphs/cgi-bin/wmi_printque_graph.cgi',
    '/nagios/cgi-bin/wmi_swap_graph.cgi'      => '/graphs/cgi-bin/wmi_swap_graph.cgi',
    '/usr/local/groundwork/bin/rrdtool'       => '/usr/bin/rrdtool',
);

foreach my $old_path (keys %new_path) {
    $dbh->do( "update performanceconfig set graphcgi=replace(graphcgi,'$old_path','$new_path{$old_path}') where graphcgi like '\%$old_path\%'" );
}

#-------------------------------------------------------------------------------------
# Idempotently add all the performanceconfig rows that are new with the 6.0 release.
#-------------------------------------------------------------------------------------

# If a row insertion here fails because that row already exists, that's okay.
# But if it fails for some other reason, that's not okay.

sub idempotent_insert {
    my $table     = shift;
    my $row_label = shift;
    my $values    = shift;

    eval {
	$dbh->do( "INSERT INTO $table VALUES $values" );
    };
    if ($@) {
	## if (not a duplicate row)
	if ( $@ !~ / Duplicate entry / ) {
	    die "\tERROR:  insert of $row_label into $table failed:\n\t    $@\n";
	}
	else {
	    # This is here just for initial debugging.  In production use, we don't want
	    # to emit this message, because the stated condition is not considered a failure.
	    # print "\tWARNING:  insert of $row_label into $table failed:\n\t    $@\n";
	}
    }
}

$dbh->do("LOCK TABLES performanceconfig WRITE");

# WARNING:  If you need to edit these lines, watch carefully for the treatment of
# backslash escapes, to make sure you really do get exactly what you want inserted.
# Test like mad.

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# The icmp_ping row is not new with 6.0, so we won't try to insert it here.  But our standard
# definition of this row did change in the 6.0 release.  If we were to insert it, here is how
# we would now do it:
# idempotent_insert ('performanceconfig', 'icmp_ping',
#     "(NULL,'*','icmp_ping','nagios',1,1,0,'ICMP Ping Response Time','\$HOST\$_\$SERVICE\$.rrd','\$RRDTOOL\$ create \$RRDNAME\$ --step 300 --start n-1yr DS:rta:GAUGE:1800:U:U RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480','\$RRDTOOL\$ update \$RRDNAME\$ \$LASTCHECK\$:\$VALUE1\$ 2>&1','rrdtool graph - --imgformat=PNG --title=\"ICMP Performance\" --rigid --base=1000 --height=120 --width=700 --alt-autoscale-max --lower-limit=0 --vertical-label=\"Time and Percent\" --slope-mode DEF:a=\"rrd_source\":ds_source_1:AVERAGE DEF:b=\"rrd_source\":ds_source_0:AVERAGE CDEF:cdefa=b CDEF:cdefb=a,100,/ AREA:cdefa#43C6DB:\"Response Time (ms) \" GPRINT:cdefa:LAST:\"Current\\:%8.2lf %s\" GPRINT:cdefa:AVERAGE:\"Average\\:%8.2lf %s\" GPRINT:cdefa:MAX:\"Maximum\\:%8.2lf %s\\n\" LINE1:cdefb#307D7E:\"Percent Loss       \" GPRINT:cdefb:LAST:\"Current\\:%8.2lf %s\" GPRINT:cdefb:AVERAGE:\"Average\\:%8.2lf %s\" GPRINT:cdefb:MAX:\"Maximum\\:%8.2lf %s\"','',' RTA = ([\\d\\.]+)')" );
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

idempotent_insert ('performanceconfig', 'local_disk',
    "(NULL,'*','local_disk','nagios',1,NULL,1,'Disk Utilization','\$HOST\$_\$SERVICE\$.rrd','\$RRDTOOL\$ create \$RRDNAME\$ --step 300 --start n-1yr \$LISTSTART\$DS:\$LABEL#\$:GAUGE:1800:U:U\$LISTEND\$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480','\$RRDTOOL\$ update \$RRDNAME\$ \$LASTCHECK\$:\$VALUE1\$ 2>&1','\\'rrdtool graph - DEF:a=\"rrd_source\":ds_source_0:AVERAGE CDEF:cdefa=a CDEF:cdefb=a,0.99,* AREA:cdefa#F88017:percent GPRINT:cdefa:MIN:min=%.2lf GPRINT:cdefa:AVERAGE:avg=%.2lf GPRINT:cdefa:MAX:max=%.2lf AREA:cdefb#C35617: -c BACK#FFFFFF -c CANVAS#FFFFFF -c GRID#C0C0C0 -c MGRID#404040 -c ARROW#FFFFFF -Y --height 120 --rigid -u 100 -l 0\\'','',' ')" );
idempotent_insert ('performanceconfig', 'local_load',
    "(NULL,'*','local_load','nagios',1,NULL,NULL,'Load Averages','\$HOST\$_\$SERVICE\$.rrd','\$RRDTOOL\$ create \$RRDNAME\$ --step 300 --start n-1yr DS:load1:GAUGE:1800:U:U DS:load5:GAUGE:1800:U:U DS:load15:GAUGE:1800:U:U  RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480','\$RRDTOOL\$ update \$RRDNAME\$ \$LASTCHECK\$:\$VALUE1\$:\$VALUE2\$:\$VALUE3\$ 2>&1','rrdtool graph - --imgformat=PNG --slope-mode DEF:a=rrd_source:load1:AVERAGE DEF:b=rrd_source:load5:AVERAGE DEF:c=rrd_source:load15:AVERAGE CDEF:cdefa=a CDEF:cdefb=b CDEF:cdefc=c AREA:cdefa#FF6600:\"One Minute Load Average\" GPRINT:cdefa:MIN:min=%.2lf GPRINT:cdefa:AVERAGE:avg=%.2lf GPRINT:cdefa:MAX:\"max=%.2lf \n\" LINE2:cdefb#6666CC:\"Five Minute Load Average\" GPRINT:cdefb:MIN:min=%.2lf GPRINT:cdefb:AVERAGE:avg=%.2lf GPRINT:cdefb:MAX:\"max=%.2lf \n\" LINE3:cdefc#999999:\"Fifteen Minute Load Average\"    GPRINT:cdefc:MIN:min=%.2lf GPRINT:cdefc:AVERAGE:avg=%.2lf GPRINT:cdefc:MAX:\"max=%.2lf \n\" -c BACK#FFFFFF -c CANVAS#FFFFFF -c GRID#C0C0C0 -c MGRID#404040 -c ARROW#FFFFFF-Y --height 120\n','',' ')" );
idempotent_insert ('performanceconfig', 'local_mem',
    "(NULL,'*','local_mem','nagios',1,1,NULL,'Memory Utilization','\$HOST\$_\$SERVICE\$.rrd','\$RRDTOOL\$ create \$RRDNAME\$ --step 300 --start n-1yr DS:percent:GAUGE:1800:U:U RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480','\$RRDTOOL\$ update \$RRDNAME\$ \$LASTCHECK\$:\$VALUE1\$ 2>&1','/graphs/cgi-bin/percent_graph.cgi',' ','([\\d\\.]+)%')" );
idempotent_insert ('performanceconfig', 'local_mysql_engine',
    "(NULL,'*','local_mysql_engine','nagios',1,1,1,'MySQL Queries Per Second','\$HOST\$_\$SERVICE\$.rrd','\$RRDTOOL\$ create \$RRDNAME\$ --step 300 --start n-1yr DS:number:GAUGE:1800:U:U RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480','\$RRDTOOL\$ update \$RRDNAME\$ \$LASTCHECK\$:\$VALUE1\$ 2>&1','/graphs/cgi-bin/number_graph.cgi',' ','Queries per second avg: ([\\d\\.]+)')" );
idempotent_insert ('performanceconfig', 'local_process',
    "(NULL,'*','local_process','nagios',1,1,1,'Process Count','\$HOST\$_\$SERVICE\$.rrd','\$RRDTOOL\$ create \$RRDNAME\$ --step 300 --start n-1yr DS:number:GAUGE:1800:U:U RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480','\$RRDTOOL\$ update \$RRDNAME\$ \$LASTCHECK\$:\$VALUE1\$ 2>&1','/graphs/cgi-bin/number_graph.cgi',' ','(\\d+) process')" );
idempotent_insert ('performanceconfig', 'local_nagios_latency',
    "(NULL,'*','local_nagios_latency','nagios',1,NULL,NULL,'Nagios Service Check Latency in Seconds','\$HOST\$_\$SERVICE\$.rrd','\$RRDTOOL\$ create \$RRDNAME\$ --step 300 --start n-1yr DS:min:GAUGE:1800:U:U DS:max:GAUGE:1800:U:U DS:avg:GAUGE:1800:U:U RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480','\$RRDTOOL\$ update \$RRDNAME\$ \$LASTCHECK\$:\$VALUE1\$:\$VALUE2\$:\$VALUE3\$ 2>&1','/graphs/cgi-bin/number_graph.cgi',' ',' ')" );
idempotent_insert ('performanceconfig', 'tcp_nsca',
    "(NULL,'*','tcp_nsca','nagios',1,NULL,NULL,'NSCA Response Time','\$HOST\$_\$SERVICE\$.rrd','\$RRDTOOL\$ create \$RRDNAME\$ --step 300 --start n-1yr DS:\$LABEL1\$:GAUGE:1800:U:U RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480','\$RRDTOOL\$ update \$RRDNAME\$ \$LASTCHECK\$:\$VALUE1\$ 2>&1','/graphs/cgi-bin/label_graph.cgi',' ',' ')" );
idempotent_insert ('performanceconfig', 'local_mysql_database',
    "(NULL,'*','local_mysql_database','nagios',1,1,1,'MySQL Queries Per Second','\$HOST\$_\$SERVICE\$.rrd','\$RRDTOOL\$ create \$RRDNAME\$ --step 300 --start n-1yr DS:number:GAUGE:1800:U:U RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480','\$RRDTOOL\$ update \$RRDNAME\$ \$LASTCHECK\$:\$VALUE1\$ 2>&1','/graphs/cgi-bin/number_graph.cgi',' ','Queries per second avg: ([\\d\\.]+)')" );
idempotent_insert ('performanceconfig', 'DEFAULT',
    "(NULL,'*','DEFAULT','nagios',1,0,0,'DO NOT REMOVE THIS ENTRY - USE TO DEFINE DEFAULT GRAPHING SETTINGS','','','','rrdtool graph - \$LISTSTART\$ DEF:\$DEFLABEL#\$:AVERAGE CDEF:cdef\$CDEFLABEL#\$=\$CDEFLABEL#\$ LINE:\$CDEFLABEL#\$\$COLORLABEL#\$:\$DSLABEL#\$ GPRINT:\$CDEFLABEL#\$:MIN:min=%.2lf GPRINT:\$CDEFLABEL#\$:AVERAGE:avg=%.2lf GPRINT:\$CDEFLABEL#\$:MAX:max=%.2lf  \$LISTEND\$  -c BACK#FFFFFF -c CANVAS#FFFFFF -c GRID#C0C0C0 -c MGRID#404040 -c ARROW#FFFFFF -Y --height 120','','')" );
idempotent_insert ('performanceconfig', 'local_users',
    "(NULL,'*','local_users','nagios',1,0,0,'Current Users','\$HOST\$_\$SERVICE\$.rrd','\$RRDTOOL\$ create \$RRDNAME\$ --step 300 --start n-1yr DS:\$LABEL1\$:GAUGE:1800:U:U RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480','\$RRDTOOL\$ update \$RRDNAME\$ \$LASTCHECK\$:\$VALUE1\$ 2>&1','rrdtool graph - --imgformat=PNG --slope-mode DEF:a=rrd_source:ds_source_0:AVERAGE  CDEF:cdefa=a  AREA:cdefa#0033CC:\"Number of logged in users\" -c BACK#FFFFFF -c CANVAS#FFFFFF -c GRID#C0C0C0 -c MGRID#404040 -c ARROW#FFFFFF-Y --height 120','','')" );

$dbh->do("UNLOCK TABLES");

#-------------------------------------------------------------------------------------
# GWMON-7942:  Idempotently modify performanceconfig rows previously populated, that
# need ds_source_# adjustments now that the 6.0 release puts in place proper ordering
# of DS source references by sequence in the RRD file definition rather than by
# mysterious and undocumented sorting by DS name.
#-------------------------------------------------------------------------------------

# WARNING:  If you need to edit these lines, watch carefully for the treatment of
# backslash escapes, to make sure you really do get exactly what you want modified.
# Test like mad.

# First, clean up historical improper use of backslash escapes.  Aside from general
# cleanliness, this greatly simplifies later pattern matching, as we won't need to deal
# with doubled and quadrupled and octupled backslashes in patterns (except for right here).
$dbh->do( "update performanceconfig set graphcgi=replace(graphcgi, ' \\\\-',      ' -'     )" );
$dbh->do( "update performanceconfig set graphcgi=replace(graphcgi, ' \\\\AREA',   ' AREA'  )" );
$dbh->do( "update performanceconfig set graphcgi=replace(graphcgi, ' \\\\CDEF',   ' CDEF'  )" );
$dbh->do( "update performanceconfig set graphcgi=replace(graphcgi, ' \\\\DEF',    ' DEF'   )" );
$dbh->do( "update performanceconfig set graphcgi=replace(graphcgi, ' \\\\GPRINT', ' GPRINT')" );
$dbh->do( "update performanceconfig set graphcgi=replace(graphcgi, ' \\\\LINE',   ' LINE'  )" );

my @graphcgi_translations = (
    {
    'service'       => 'http_alive',
    'graph_pattern' => ' --title="HTTP Performance" % --vertical-label="Seconds and KB" ',
    'old_segment'   => ' DEF:a="rrd_source":ds_source_0:AVERAGE DEF:b="rrd_source":ds_source_1:AVERAGE ',
    'new_segment'   => ' DEF:a="rrd_source":ds_source_1:AVERAGE DEF:b="rrd_source":ds_source_0:AVERAGE '
    },
    {
    'service'       => 'http_alive',
    'graph_pattern' => ' --title="HTTP Performance" % --vertical-label="Seconds and KB" ',
    'old_segment'   => '"Response Time"',
    'new_segment'   => '"Response Time (sec) "'
    },
    {
    'service'       => 'http_alive',
    'graph_pattern' => ' --title="HTTP Performance" % --vertical-label="Seconds and KB" ',
    'old_segment'   => 'GPRINT:cdefa:LAST:" Current\\\\:%8.2lf %s"',
    'new_segment'   => 'GPRINT:cdefa:LAST:"Current\\\\:%8.2lf %s"'
    },
    {
    'service'       => 'http_alive',
    'graph_pattern' => ' --title="HTTP Performance" % --vertical-label="Seconds and KB" ',
    'old_segment'   => '"Page Size (KB)"',
    'new_segment'   => '"Page Size (KB)      "'
    },
    {
    'service'       => 'https_alive',
    'graph_pattern' => ' --title="HTTPS Performance" % --vertical-label="Seconds and KB" ',
    'old_segment'   => ' DEF:a="rrd_source":ds_source_0:AVERAGE DEF:b="rrd_source":ds_source_1:AVERAGE ',
    'new_segment'   => ' DEF:a="rrd_source":ds_source_1:AVERAGE DEF:b="rrd_source":ds_source_0:AVERAGE '
    },
    {
    'service'       => 'https_alive',
    'graph_pattern' => ' --title="HTTPS Performance" % --vertical-label="Seconds and KB" ',
    'old_segment'   => '"Response Time"',
    'new_segment'   => '"Response Time (sec) "'
    },
    {
    'service'       => 'https_alive',
    'graph_pattern' => ' --title="HTTPS Performance" % --vertical-label="Seconds and KB" ',
    'old_segment'   => 'GPRINT:cdefa:LAST:" Current\\\\:%8.2lf %s"',
    'new_segment'   => 'GPRINT:cdefa:LAST:"Current\\\\:%8.2lf %s"'
    },
    {
    'service'       => 'https_alive',
    'graph_pattern' => ' --title="HTTPS Performance" % --vertical-label="Seconds and KB" ',
    'old_segment'   => '"Page Size (KB)"',
    'new_segment'   => '"Page Size (KB)      "'
    },
    {
    'service'       => 'icmp_ping',
    'graph_pattern' => ' --title="ICMP Performance" % --vertical-label="Time and Percent" ',
    'old_segment'   => ' DEF:a="rrd_source":ds_source_0:AVERAGE DEF:b="rrd_source":ds_source_1:AVERAGE ',
    'new_segment'   => ' DEF:a="rrd_source":ds_source_1:AVERAGE DEF:b="rrd_source":ds_source_0:AVERAGE '
    },
    {
    'service'       => 'icmp_ping',
    'graph_pattern' => ' --title="ICMP Performance" % --vertical-label="Time and Percent" ',
    'old_segment'   => '"Response Time (Seconds)"',
    'new_segment'   => '"Response Time (ms) "'
    },
    {
    'service'       => 'icmp_ping',
    'graph_pattern' => ' --title="ICMP Performance" % --vertical-label="Time and Percent" ',
    'old_segment'   => 'GPRINT:cdefa:LAST:" Current\\\\:%8.2lf %s"',
    'new_segment'   => 'GPRINT:cdefa:LAST:"Current\\\\:%8.2lf %s"'
    },
    {
    'service'       => 'icmp_ping',
    'graph_pattern' => ' --title="ICMP Performance" % --vertical-label="Time and Percent" ',
    'old_segment'   => '"Maximum\\\\:%8.2lf %s'."\r\n".'"',
    'new_segment'   => '"Maximum\\\\:%8.2lf %s\\\\n"'
    },
    {
    'service'       => 'icmp_ping',
    'graph_pattern' => ' --title="ICMP Performance" % --vertical-label="Time and Percent" ',
    'old_segment'   => '"Percent Loss"',
    'new_segment'   => '"Percent Loss       "'
    },
);

foreach my $translation (@graphcgi_translations) {
    $dbh->do( "update performanceconfig set graphcgi=replace(graphcgi,'$translation->{old_segment}','$translation->{new_segment}') where service = '$translation->{service}' and graphcgi like '%$translation->{graph_pattern}%'" );
}

#-----------------------------------------------------------------------------
# Add check_period for 2.0
#-----------------------------------------------------------------------------

$sqlstmt = 'describe host_templates';
$sth     = $dbh->prepare($sqlstmt);
$sth->execute();
%fields = ();
while ( my @values = $sth->fetchrow_array() ) {
    $fields{ $values[0] } = 1;
}
$sth->finish;
unless ( defined $fields{'check_period'} ) {
    $dbh->do( 'alter table host_templates add check_period SMALLINT(4) UNSIGNED after name' );
}

#-----------------------------------------------------------------------------
# Extend certain tables to support Nagios "notes" at the host/service object
# and group levels, instead of just via extended info templates (GWMON-8764)
#-----------------------------------------------------------------------------

# First add the "comment" field to the servicegroups table, to achieve a construction
# which parallels that of similar tables to which we will be adding a "notes" field.
# We don't need it in the short term, but we want to prepare for clean future evolution.

$sqlstmt = 'describe servicegroups';
$sth     = $dbh->prepare($sqlstmt);
$sth->execute();
%fields = ();
while ( my @values = $sth->fetchrow_array() ) {
    $fields{ $values[0] } = 1;
}
$sth->finish;
unless ( defined $fields{'comment'} ) {
    $dbh->do( "alter table servicegroups add comment text default NULL after escalation_id" );
}

# Then make sure the new "notes" column exists in each table.
my %preceding_field = (
    hosts         => 'comment',
    services      => 'comment',
    hostgroups    => 'comment',
    servicegroups => 'comment',
    stage_hosts   => 'info'
);
foreach my $table (keys %preceding_field) {
    $sqlstmt = "describe $table";
    $sth     = $dbh->prepare($sqlstmt);
    $sth->execute();
    %fields = ();
    while ( my @values = $sth->fetchrow_array() ) {
	$fields{ $values[0] } = 1;
    }
    $sth->finish;
    unless ( defined $fields{'notes'} ) {
	$dbh->do( "alter table $table add notes varchar(4096) default NULL after $preceding_field{$table}" );
    }
}

#-----------------------------------------------------------------------------
# Extend external_host to tell if user edits have happened (GWMON-8509)
#-----------------------------------------------------------------------------

# First, make sure the new "modified" column exists.
$sqlstmt = 'describe external_host';
$sth     = $dbh->prepare($sqlstmt);
$sth->execute();
%fields = ();
while ( my @values = $sth->fetchrow_array() ) {
    $fields{ $values[0] } = 1;
}
$sth->finish;
unless ( defined $fields{'modified'} ) {
    # "default NULL" is intentional here so we can distinguish a newly added
    # column from an existing column when we go to populate the new column values.
    # We might have done that instead by moving the update inside this enclosing
    # condition, but that construction would be ever so slightly subject to failure.
    # That is, if it got interrupted between the alter table and the update, and
    # then re-run, the "modified" flag wouldn't be already set for changed content
    # and that bad information wouldn't be fixed here.
    $dbh->do( 'alter table external_host add modified TINYINT(1) default NULL after data' );
}

# Then, scan all the rows in the external_host table and change any NULL
# values in the modified column to either 0 (the host's host external
# instance content [external_host.data] exactly matches the content of the
# generic host external from which it originated [externals.display where
# externals.external_id = external_host.external_id]) or 1 (the content
# differs).  Don't touch any existing non-NULL values.

$dbh->do(
    '
    update external_host, externals
    set external_host.modified = (external_host.data != externals.display)
    where external_host.modified is NULL
    and externals.external_id = external_host.external_id
    '
);

#-----------------------------------------------------------------------------
# Extend external_service to tell if user edits have happened (GWMON-8463)
#-----------------------------------------------------------------------------

# First, make sure the new "modified" column exists.
$sqlstmt = 'describe external_service';
$sth     = $dbh->prepare($sqlstmt);
$sth->execute();
%fields = ();
while ( my @values = $sth->fetchrow_array() ) {
    $fields{ $values[0] } = 1;
}
$sth->finish;
unless ( defined $fields{'modified'} ) {
    # "default NULL" is intentional here so we can distinguish a newly added
    # column from an existing column when we go to populate the new column values.
    # We might have done that instead by moving the update inside this enclosing
    # condition, but that construction would be ever so slightly subject to failure.
    # That is, if it got interrupted between the alter table and the update, and
    # then re-run, the "modified" flag wouldn't be already set for changed content
    # and that bad information wouldn't be fixed here.
    $dbh->do( 'alter table external_service add modified TINYINT(1) default NULL after data' );
}

# Then, scan all the rows in the external_service table and change any NULL
# values in the modified column to either 0 (the host+service service external
# instance content [external_service.data] exactly matches the content of the
# generic service external from which it originated [externals.display where
# externals.external_id = external_service.external_id]) or 1 (the content
# differs).  Don't touch any existing non-NULL values.

$dbh->do(
    '
    update external_service, externals
    set external_service.modified = (external_service.data != externals.display)
    where external_service.modified is NULL
    and externals.external_id = external_service.external_id
    '
);

#-----------------------------------------------------------------------------
# Fix broken import_schema rows arising from bugs in previous releases.
#-----------------------------------------------------------------------------

$dbh->do( 'update import_schema set type = "host-import" where type is null' );

#-----------------------------------------------------------------------------
# Fix broken import_match rows arising from bugs in previous releases.
#-----------------------------------------------------------------------------

$dbh->do( 'delete from import_match where name is null and match_type is null' );

#-----------------------------------------------------------------------------
# GWMON-4818:  Due to a bug in historic code, the monarch_group_props table
# might contain duplicate entries per group for values of type nagios_cgi and
# nagios_cfg.  To clean this up, we need to eliminate the duplicate entries,
# taking care to always keep the last values saved.  The current Monarch code
# will do the same thing, so in some sense this cleanup is not needed here,
# but it would be needed here should we extend the non-primary index on the
# monarch_group_props table to index at least the {group_id, name} fields as
# unique pairs, and possibly include {type} in this index, to prevent such
# duplication via database constraint.
#-----------------------------------------------------------------------------

# begin cleanup steps
$dbh->do( 'create temporary table monarch_group_props_copy like monarch_group_props' );

# select only the last version of each item
$dbh->do( 'insert into monarch_group_props_copy select * from monarch_group_props' );
$dbh->do( "delete from monarch_group_props where prop_id not in " .
    "(select max(prop_id) from monarch_group_props_copy group by group_id, name, type)" );

# end cleanup steps
$dbh->do( 'drop table monarch_group_props_copy' );

#-----------------------------------------------------------------------------
# Clean up historically poor Nagios resource macro comments.
#-----------------------------------------------------------------------------

$sqlstmt = "select name, value from setup where type = 'resource'";
$sth     = $dbh->prepare($sqlstmt);
$sth->execute();
my %resource = ();
while ( my @values = $sth->fetchrow_array() ) {
    $resource{ $values[0] } = $values[1];
}
$sth->finish;

my $USER18_count = $dbh->selectrow_array( 'select count(*) from commands where data like "%USER18%"' );

if ( defined( $resource{'user1'} ) && $resource{'user1'} eq '/usr/local/nagios/libexec' ) {
    $dbh->do( 'update setup set value="plugin directory" where name="resource_label1" and value="Plugin directory"' );
}

if ( defined( $resource{'user2'} ) && $resource{'user2'} eq '/usr/local/nagios/eventhandlers' ) {
    $dbh->do( 'update setup set value="event handler scripts directory" where name="resource_label2" and value="Eventhandler scripts directory"' );
}

$dbh->do( 'update setup set value="plugin timeout" where name="resource_label3" and value="plug-in timeout"' );

if ( defined( $resource{'user6'} ) && $resource{'user6'} eq 'gwrk' ) {
    $dbh->do( 'update setup set value="default MySQL password for GroundWork databases" where name="resource_label6" and value is NULL' );
}

$dbh->do( 'update setup set value="SNMP community string" where name="resource_label7" and value="SNMP Community string"' );

if ( defined( $resource{'user8'} ) && $resource{'user8'} eq 'itgwrk' ) {
    $dbh->do( 'update setup set value="alternate SNMP community string" where name="resource_label8" and value is NULL' );
}

$dbh->do( 'update setup set value="sendEmail smtp mail relay option (-s) value" where name="resource_label13" and value="Sendmail Reply option (-s <smtpmailrelay>) "' );

if ( defined( $resource{'user17'} ) && $resource{'user17'} eq 'nagios' ) {
    $dbh->do( 'update setup set value="default check_by_ssh remote user name for all SSH checks" where name="resource_label17" and value is NULL' );
}

if ( defined($USER18_count) && $USER18_count == 0 ) {
    if ( defined( $resource{'user18'} ) && $resource{'user18'} eq '/home/nagios' ) {
	$dbh->do( 'update setup set value="" where name="resource_label18" and value is NULL' );
    }
    $dbh->do( 'update setup set value="" where name="user18" and value="/home/nagios"' );
}

if ( defined( $resource{'user22'} ) && $resource{'user22'} eq 'libexec' ) {
    $dbh->do( 'update setup set value="default plugin subdirectory on remote hosts, relative to the home directory of the user you SSH in as" where name="resource_label22" and value is NULL' );
}

$sqlstmt = "select group_id, name, value from monarch_group_props where type = 'resource'";
$sth     = $dbh->prepare($sqlstmt);
$sth->execute();
my %group_resource = ();
while ( my @values = $sth->fetchrow_array() ) {
    $group_resource{ $values[0] }{ $values[1] } = $values[2];
}
$sth->finish;

foreach my $group_id ( keys %group_resource ) {
    if ( defined( $group_resource{$group_id}{'user1'} ) && $group_resource{$group_id}{'user1'} eq '/usr/local/nagios/libexec' ) {
	$dbh->do( "update monarch_group_props set value='plugin directory' where group_id=$group_id and name='resource_label1' and value='Plugin directory'" );
    }

    if ( defined( $group_resource{$group_id}{'user2'} ) && $group_resource{$group_id}{'user2'} eq '/usr/local/nagios/eventhandlers' ) {
	$dbh->do( "update monarch_group_props set value='event handler scripts directory' where group_id=$group_id and name='resource_label2' and value='Eventhandler scripts directory'" );
    }

    $dbh->do( "update monarch_group_props set value='plugin timeout' where group_id=$group_id and name='resource_label3' and value='plug-in timeout'" );

    if ( defined( $group_resource{$group_id}{'user6'} ) && $group_resource{$group_id}{'user6'} eq 'gwrk' ) {
	$dbh->do( "update monarch_group_props set value='default MySQL password for GroundWork databases' where group_id=$group_id and name='resource_label6' and value is NULL" );
    }

    $dbh->do( "update monarch_group_props set value='SNMP community string' where group_id=$group_id and name='resource_label7' and value='SNMP Community string'" );

    if ( defined( $group_resource{$group_id}{'user8'} ) && $group_resource{$group_id}{'user8'} eq 'itgwrk' ) {
	$dbh->do( "update monarch_group_props set value='alternate SNMP community string' where group_id=$group_id and name='resource_label8' and value is NULL" );
    }

    $dbh->do( "update monarch_group_props set value='sendEmail smtp mail relay option (-s) value' where group_id=$group_id and name='resource_label13' and value='Sendmail Reply option (-s <smtpmailrelay>) '" );

    if ( defined( $group_resource{$group_id}{'user17'} ) && $group_resource{$group_id}{'user17'} eq 'nagios' ) {
	$dbh->do( "update monarch_group_props set value='default check_by_ssh remote user name for all SSH checks' where group_id=$group_id and name='resource_label17' and value is NULL" );
    }

    if ( defined($USER18_count) && $USER18_count == 0 ) {
	if ( defined( $group_resource{$group_id}{'user18'} ) && $group_resource{$group_id}{'user18'} eq '/home/nagios' ) {
	    $dbh->do( "update monarch_group_props set value='' where group_id=$group_id and name='resource_label18' and value is NULL" );
	}
	$dbh->do( "update monarch_group_props set value='' where group_id=$group_id and name='user18' and value='/home/nagios'" );
    }

    if ( defined( $group_resource{$group_id}{'user22'} ) && $group_resource{$group_id}{'user22'} eq 'libexec' ) {
	$dbh->do( "update monarch_group_props set value='default plugin subdirectory on remote hosts, relative to the home directory of the user you SSH in as' where group_id=$group_id and name='resource_label22' and value is NULL" );
    }
}

#-----------------------------------------------------------------------------
# Deal with passwords
#-----------------------------------------------------------------------------

unless ($old_monarch_version) {
    print "\n\tConverting passwords ...\n";
    $sqlstmt = 'select user_id, password from users';
    $sth     = $dbh->prepare($sqlstmt);
    $sth->execute();
    my %fields = ();
    while ( my @values = $sth->fetchrow_array() ) {
	$fields{ $values[0] } = 1;
    }
    $sth->finish;

    # encrypt passwords
    $sqlstmt = "select user_acct, password from users";
    $sth     = $dbh->prepare($sqlstmt);
    $sth->execute();
    %fields = ();
    while ( my @values = $sth->fetchrow_array() ) {
	$fields{ $values[0] } = $values[1];
    }
    $sth->finish;
    foreach my $uid ( keys %fields ) {
	if ( $uid eq 'super_user' ) { $fields{$uid} = 'password' }
	my @saltchars = ( 'a' .. 'z', 'A' .. 'Z', '0' .. '9', ',', '/' );
	srand( time() ^ ( $$ + ( $$ << 15 ) ) );
	my $salt = $saltchars[ int( rand(64) ) ];
	$salt .= $saltchars[ int( rand(64) ) ];
	my $newpw = crypt( $fields{$uid}, $salt );
	my $sql = "update users set password = '$newpw' where user_acct = '$uid'";
	$sth = $dbh->prepare($sqlstmt);
	$sth->execute();
	$sth->finish;
    }
}

#=============================================================================
# Host_overrides changes
#=============================================================================

$sqlstmt = 'describe host_overrides';
$sth     = $dbh->prepare($sqlstmt);
$sth->execute();
%fields = ();
while ( my @values = $sth->fetchrow_array() ) {
    $fields{ $values[0] } = 1;
}
$sth->finish;

#-----------------------------------------------------------------------------
#  add check_period
#-----------------------------------------------------------------------------

unless ( defined $fields{'check_period'} ) {
    print "\n\tUpdating table host_overrides ...\n";
    $dbh->do( 'alter table host_overrides add check_period SMALLINT(4) UNSIGNED after host_id' );
}

#-----------------------------------------------------------------------------
#  drop status
#-----------------------------------------------------------------------------

if ( defined $fields{'status'} ) {
    $dbh->do("ALTER TABLE host_overrides drop column status");
}

$sqlstmt = 'describe service_overrides';
$sth     = $dbh->prepare($sqlstmt);
$sth->execute();
%fields = ();
while ( my @values = $sth->fetchrow_array() ) {
    $fields{ $values[0] } = 1;
}
$sth->finish;

#-----------------------------------------------------------------------------
#  drop check_command
#-----------------------------------------------------------------------------

if ( defined $fields{'check_command'} ) {
    print "\n\tUpdating table service_overrides ...\n";
    $dbh->do("ALTER TABLE service_overrides drop column check_command");
}

#-----------------------------------------------------------------------------
#  drop status
#-----------------------------------------------------------------------------

if ( defined $fields{'status'} ) {
    $dbh->do("ALTER TABLE service_overrides drop column status");
}

#-----------------------------------------------------------------------------
# Update access list for super user group
#-----------------------------------------------------------------------------

my $super_gid = $dbh->selectrow_array( "select usergroup_id from user_groups where name = 'super_users'" );
$sqlstmt = "select * from access_list where usergroup_id = '$super_gid'";
$sth     = $dbh->prepare($sqlstmt);
$sth->execute();
my %sgid_assets = ();
while ( my @values = $sth->fetchrow_array() ) {
    $sgid_assets{ $values[0] }{ $values[1] }{ $values[3] } = 1;
}
$sth->finish;

#-----------------------------------------------------------------------------
# service groups
#-----------------------------------------------------------------------------

unless ( $sgid_assets{'servicegroups'} ) {
    $dbh->do( "insert into access_list values('servicegroups','design_manage','$super_gid','add,modify,delete')" );
}

#-----------------------------------------------------------------------------
# Add externals to access_list
#-----------------------------------------------------------------------------

unless ( $sgid_assets{'externals'} ) {
    $dbh->do( "insert into access_list values('externals','design_manage','$super_gid','add,modify,delete')" );
}

#-----------------------------------------------------------------------------
# Add host delete tool to access_list
#-----------------------------------------------------------------------------

unless ( $sgid_assets{'host_delete_tool'} ) {
    $dbh->do( "insert into access_list values('host_delete_tool','tools','$super_gid','add,modify,delete')" );
}

#-----------------------------------------------------------------------------
# Add service delete tool to access_list
#-----------------------------------------------------------------------------

unless ( $sgid_assets{'service_delete_tool'} ) {
    $dbh->do( "insert into access_list values('service_delete_tool','tools','$super_gid','add,modify,delete')" );
}

my @ez_list = (
    'ez_enabled',  'main_ez',          'ez_hosts',  'ez_host_groups',
    'ez_profiles', 'ez_notifications', 'ez_commit', 'ez_setup',
    'ez_discover', 'ez_import'
);
foreach my $ez (@ez_list) {
    unless ( $sgid_assets{$ez} ) {
	$dbh->do( "insert into access_list values('$ez','ez','$super_gid','$ez')" );
    }
}

#-----------------------------------------------------------------------------
# Add group macros to access_list
#-----------------------------------------------------------------------------

unless ( $sgid_assets{'manage'}{'group_macro'} ) {
    $dbh->do( "insert into access_list values('manage','group_macro','$super_gid','manage')" );
}

#-----------------------------------------------------------------------------
# Add servicename_id and arguments to import_match
#-----------------------------------------------------------------------------

$sqlstmt = 'describe import_match';
$sth     = $dbh->prepare($sqlstmt);
$sth->execute();
%fields = ();
while ( my @values = $sth->fetchrow_array() ) {
    $fields{ $values[0] } = 1;
}
$sth->finish;

unless ( defined $fields{'servicename_id'} ) {
    print "\n\tUpdating table import_match ...\n";
    $dbh->do( 'alter table import_match add servicename_id SMALLINT(4) UNSIGNED after hostprofile_id' );
    $dbh->do( "alter table import_match add FOREIGN KEY (servicename_id) REFERENCES service_names(servicename_id) ON DELETE SET NULL" );
    $dbh->do( 'alter table import_match add arguments VARCHAR(255) after servicename_id' );
}

#=============================================================================
# Escalations
#=============================================================================

$sqlstmt = 'describe escalation_templates';
$sth     = $dbh->prepare($sqlstmt);
$sth->execute();
%fields = ();
while ( my @values = $sth->fetchrow_array() ) {
    $fields{ $values[0] } = 1;
}
$sth->finish;

my @table_info = $dbh->selectrow_array("show create table escalation_templates");
if ( defined $fields{'servicename_id'} ) {
    my %tree_template_contactgroup = ();
    $sqlstmt = "select * from tree_template_contactgroup";
    $sth     = $dbh->prepare($sqlstmt);
    $sth->execute();
    while ( my @vals = $sth->fetchrow_array() ) {
	$tree_template_contactgroup{"$vals[0]-$vals[1]-$vals[2]"} = 1;
    }
    $sth->finish;
    $sqlstmt = "select servicename_id from service_names where name = '*'";
    my $splat_id = $dbh->selectrow_array($sqlstmt);
    $sqlstmt = "select template_id, servicename_id from escalation_templates";
    $sth     = $dbh->prepare($sqlstmt);
    $sth->execute();
    while ( my @temp = $sth->fetchrow_array() ) {
	my @template_contactgroups = ();
	$sqlstmt = "select contactgroup_id from contactgroup_assign where object = '$temp[0]' and type like '%escalation%'";
	my $sth2 = $dbh->prepare($sqlstmt);
	$sth2->execute();
	while ( my @cg = $sth2->fetchrow_array() ) {
	    push @template_contactgroups, $cg[0];
	}
	$sth2->finish;
	$sqlstmt = "select tree_id from escalation_tree_template where template_id = '$temp[0]'";
	$sth2 = $dbh->prepare($sqlstmt);
	$sth2->execute();
	while ( my @tree = $sth2->fetchrow_array() ) {
	    foreach my $cg (@template_contactgroups) {
		unless ( $tree_template_contactgroup{"$tree[0]-$temp[1]-$cg"} ) {
		    $dbh->do( "insert into tree_template_contactgroup values('$tree[0]','$temp[0]','$cg')" );
		}
	    }
	    if ( $temp[1] && $temp[1] ne $splat_id ) {
		my @hosts = ();
		$sqlstmt = "select host_id from hosts where host_id in (select host_id from hostgroup_host left join hostgroups on hostgroup_host.hostgroup_id = hostgroups.hostgroup_id where hostgroups.service_escalation_id = '$tree[0]')";
		my $sth3 = $dbh->prepare($sqlstmt);
		$sth3->execute();
		while ( my @host = $sth3->fetchrow_array() ) {
		    push @hosts, $host[0];
		}
		$sth3->finish;
		$sqlstmt = "select host_id from hosts where service_escalation_id = '$tree[0]'";
		$sth3 = $dbh->prepare($sqlstmt);
		$sth3->execute();
		while ( my @host = $sth3->fetchrow_array() ) {
		    push @hosts, $host[0];
		}
		$sth3->finish;
		$dbh->do( "update hostgroups set service_escalation_id = NULL where service_escalation_id =  '$tree[0]'" );
		$dbh->do( "update hosts set service_escalation_id = NULL where service_escalation_id = '$tree[0]'" );
		foreach my $hid (@hosts) {
		    $dbh->do( "update services set escalation_id = '$tree[0]' where host_id = '$hid' and servicename_id = '$temp[1]'" );
		}
	    }
	}
	$sth2->finish;
    }
    $sth->finish;
    if ( $table_info[1] =~ /CONSTRAINT\s*.(escalation_templates_\S+_\d+).\s+FOREIGN KEY\s+\(.servicename_id.\)/ ) {
	$dbh->do("alter table escalation_templates drop foreign key $1");
    }

    $dbh->do("ALTER TABLE escalation_templates drop column servicename_id");
    $dbh->do("delete from contactgroup_assign where type like '%escalation%'");
}

#=============================================================================
# Convert contactgroup_assign
#=============================================================================

if ( $tables{'contactgroup_assign'} ) {

    my $contactgroups_already_migrated =
	$tables{'contactgroup_host'}             &&
	$tables{'contactgroup_service'}          &&
	$tables{'contactgroup_host_template'}    &&
	$tables{'contactgroup_service_template'} &&
	$tables{'contactgroup_host_profile'}     &&
	$tables{'contactgroup_service_name'}     &&
	$tables{'contactgroup_hostgroup'}        &&
	$tables{'contactgroup_group'};

    # create new associative tables:

    unless ( $tables{'contactgroup_host'} ) {
	# contactgroup_host
	$dbh->do(
	    "CREATE TABLE contactgroup_host (contactgroup_id SMALLINT(4) UNSIGNED,
		host_id INT(6) UNSIGNED,
		PRIMARY KEY (contactgroup_id,host_id),
		FOREIGN KEY (host_id) REFERENCES hosts(host_id) ON DELETE CASCADE,
		FOREIGN KEY (contactgroup_id) REFERENCES contactgroups(contactgroup_id) ON DELETE CASCADE) TYPE=INNODB"
	);
    }

    unless ( $tables{'contactgroup_service'} ) {
	# contactgroup_service
	$dbh->do(
	    "CREATE TABLE contactgroup_service (contactgroup_id SMALLINT(4) UNSIGNED,
		service_id INT(8) UNSIGNED,
		PRIMARY KEY (contactgroup_id,service_id),
		FOREIGN KEY (service_id) REFERENCES services(service_id) ON DELETE CASCADE,
		FOREIGN KEY (contactgroup_id) REFERENCES contactgroups(contactgroup_id) ON DELETE CASCADE) TYPE=INNODB"
	);
    }

    unless ( $tables{'contactgroup_host_template'} ) {
	# contactgroup_host_template
	$dbh->do(
	    "CREATE TABLE contactgroup_host_template (contactgroup_id SMALLINT(4) UNSIGNED,
		hosttemplate_id SMALLINT(4) UNSIGNED,
		PRIMARY KEY (contactgroup_id,hosttemplate_id),
		FOREIGN KEY (hosttemplate_id) REFERENCES host_templates(hosttemplate_id) ON DELETE CASCADE,
		FOREIGN KEY (contactgroup_id) REFERENCES contactgroups(contactgroup_id) ON DELETE CASCADE) TYPE=INNODB"
	);
    }

    unless ( $tables{'contactgroup_service_template'} ) {
	# contactgroup_service_template
	$dbh->do(
	    "CREATE TABLE contactgroup_service_template (contactgroup_id SMALLINT(4) UNSIGNED,
		servicetemplate_id SMALLINT(4) UNSIGNED,
		PRIMARY KEY (contactgroup_id,servicetemplate_id),
		FOREIGN KEY (servicetemplate_id) REFERENCES service_templates(servicetemplate_id) ON DELETE CASCADE,
		FOREIGN KEY (contactgroup_id) REFERENCES contactgroups(contactgroup_id) ON DELETE CASCADE) TYPE=INNODB"
	);
    }

    unless ( $tables{'contactgroup_host_profile'} ) {
	# contactgroup_host_profile
	$dbh->do(
	    "CREATE TABLE contactgroup_host_profile (contactgroup_id SMALLINT(4) UNSIGNED,
		hostprofile_id SMALLINT(4) UNSIGNED,
		PRIMARY KEY (contactgroup_id,hostprofile_id),
		FOREIGN KEY (hostprofile_id) REFERENCES profiles_host(hostprofile_id) ON DELETE CASCADE,
		FOREIGN KEY (contactgroup_id) REFERENCES contactgroups(contactgroup_id) ON DELETE CASCADE) TYPE=INNODB"
	);
    }

    unless ( $tables{'contactgroup_service_name'} ) {
	# contactgroup_service_name
	$dbh->do(
	    "CREATE TABLE contactgroup_service_name (contactgroup_id SMALLINT(4) UNSIGNED,
		servicename_id SMALLINT(4) UNSIGNED,
		PRIMARY KEY (contactgroup_id,servicename_id),
		FOREIGN KEY (servicename_id) REFERENCES service_names(servicename_id) ON DELETE CASCADE,
		FOREIGN KEY (contactgroup_id) REFERENCES contactgroups(contactgroup_id) ON DELETE CASCADE) TYPE=INNODB"
	);
    }

    unless ( $tables{'contactgroup_hostgroup'} ) {
	# contactgroup_hostgroup
	$dbh->do(
	    "CREATE TABLE contactgroup_hostgroup (contactgroup_id SMALLINT(4) UNSIGNED,
		hostgroup_id SMALLINT(4) UNSIGNED,
		PRIMARY KEY (contactgroup_id,hostgroup_id),
		FOREIGN KEY (hostgroup_id) REFERENCES hostgroups(hostgroup_id) ON DELETE CASCADE,
		FOREIGN KEY (contactgroup_id) REFERENCES contactgroups(contactgroup_id) ON DELETE CASCADE) TYPE=INNODB"
	);
    }

    unless ( $tables{'contactgroup_group'} ) {
	# contactgroup_group
	$dbh->do(
	    "CREATE TABLE contactgroup_group (contactgroup_id SMALLINT(4) UNSIGNED,
		group_id SMALLINT(4) UNSIGNED,
		PRIMARY KEY (contactgroup_id,group_id),
		FOREIGN KEY (group_id) REFERENCES monarch_groups(group_id) ON DELETE CASCADE,
		FOREIGN KEY (contactgroup_id) REFERENCES contactgroups(contactgroup_id) ON DELETE CASCADE) TYPE=INNODB"
	);
    }

    unless ( $contactgroups_already_migrated ) {
	my %table_by_object = (
	    'hosts'             => 'contactgroup_host',
	    'monarch_group'     => 'contactgroup_group',
	    'services'          => 'contactgroup_service',
	    'host_templates'    => 'contactgroup_host_template',
	    'service_templates' => 'contactgroup_service_template',
	    'host_profiles'     => 'contactgroup_host_profile',
	    'service_names'     => 'contactgroup_service_name',
	    'hostgroups'        => 'contactgroup_hostgroup',
	);

	my %contactgroup_assign = ();
	$sqlstmt = "select * from contactgroup_assign";
	$sth     = $dbh->prepare($sqlstmt);
	$sth->execute();
	while ( my @values = $sth->fetchrow_array() ) {
	    $contactgroup_assign{ $values[1] }{ $values[2] }{ $values[0] } = 1;
	}
	$sth->finish;
	my %objects = ();
	my @tables  = (
	    'hosts',             'services',
	    'hostgroups',        'contactgroups',
	    'profiles_host',     'host_templates',
	    'service_templates', 'service_names'
	);
	foreach my $table (@tables) {
	    $sqlstmt = "select * from $table";
	    $sth     = $dbh->prepare($sqlstmt);
	    $sth->execute();
	    while ( my @values = $sth->fetchrow_array() ) {
		$objects{$table}{ $values[0] } = 1;
	    }
	    $sth->finish;
	}

	# migrate objects to new tables
	foreach my $type ( keys %contactgroup_assign ) {
	    my $table_name = $type;
	    if ( $table_name eq 'host_profiles' ) { $table_name = 'profiles_host' }
	    foreach my $oid ( keys %{ $contactgroup_assign{$type} } ) {
		if ( $objects{$table_name}{$oid} ) {
		    foreach my $cgid ( keys %{ $contactgroup_assign{$type}{$oid} } ) {
			if ( $objects{'contactgroups'}{$cgid} ) {
			    $dbh->do( "insert into $table_by_object{$type} values($cgid,$oid)" );
			}
		    }
		}
	    }
	}
    }

    # Drop contactgroup_assign table
    $dbh->do("drop table contactgroup_assign");
}

#-----------------------------------------------------------------------------
# more escalation stuff
#-----------------------------------------------------------------------------

$dbh->do( "update escalation_templates set type = 'host' where type = 'hostgroup'" );
$dbh->do( "update escalation_trees set type = 'host' where type = 'hostgroup'" );

unless ( defined $fields{'escalation_period'} ) {
    $dbh->do( "ALTER TABLE escalation_templates add escalation_period SMALLINT(4) UNSIGNED after comment" );
}

@table_info = $dbh->selectrow_array("show create table escalation_templates");
unless ( $table_info[1] =~ /FOREIGN KEY\s*\(.escalation_period.\)\s*REFERENCES\s+.time_periods.\s*\(.timeperiod_id.\)\s+ON DELETE SET NULL/i) {
    $dbh->do( "ALTER TABLE escalation_templates add FOREIGN KEY (escalation_period) REFERENCES time_periods(timeperiod_id) ON DELETE SET NULL" );
}

@table_info = $dbh->selectrow_array("show create table escalation_tree_template");
unless ( $table_info[1] =~ /FOREIGN KEY\s*\(.template_id.\)\s*REFERENCES\s+.escalation_templates.\s*\(.template_id.\)\s+ON DELETE CASCADE/i ) {
    $dbh->do( "delete from escalation_tree_template where template_id not in (select template_id from escalation_templates)" );
    $dbh->do( "ALTER TABLE escalation_tree_template add FOREIGN KEY (template_id) REFERENCES escalation_templates(template_id) ON DELETE CASCADE" );
    $dbh->do( "delete from escalation_tree_template where tree_id not in (select tree_id from escalation_trees)" );
    $dbh->do( "ALTER TABLE escalation_tree_template add FOREIGN KEY (tree_id) REFERENCES escalation_trees(tree_id) ON DELETE CASCADE" );
}

@table_info = $dbh->selectrow_array("show create table tree_template_contactgroup");
unless ( $table_info[1] =~ /FOREIGN KEY\s*\(.contactgroup_id.\)\s*REFERENCES\s+.contactgroups.\s*\(.contactgroup_id.\)\s+ON DELETE CASCADE/i ) {
    $dbh->do( "delete from tree_template_contactgroup where contactgroup_id not in (select contactgroup_id from contactgroups)" );
    $dbh->do( "ALTER TABLE tree_template_contactgroup add FOREIGN KEY (contactgroup_id) REFERENCES contactgroups(contactgroup_id) ON DELETE CASCADE" );
    $dbh->do( "delete from tree_template_contactgroup where template_id not in (select template_id from escalation_templates)" );
    $dbh->do( "ALTER TABLE tree_template_contactgroup add FOREIGN KEY (template_id) REFERENCES escalation_templates(template_id) ON DELETE CASCADE" );
    $dbh->do( "delete from tree_template_contactgroup where tree_id not in (select tree_id from escalation_trees)" );
    $dbh->do( "ALTER TABLE tree_template_contactgroup add FOREIGN KEY (tree_id) REFERENCES escalation_trees(tree_id) ON DELETE CASCADE" );
}

#-----------------------------------------------------------------------------
# host
#-----------------------------------------------------------------------------

$sqlstmt = 'describe hosts';
$sth     = $dbh->prepare($sqlstmt);
$sth->execute();
%fields = ();
while ( my @values = $sth->fetchrow_array() ) {
    $fields{ $values[0] } = 1;
}
$sth->finish;

if ( defined $fields{'serviceprofile_id'} ) {
    my $sqlstmt = "select host_id, serviceprofile_id from hosts";
    $sth = $dbh->prepare($sqlstmt);
    $sth->execute();
    while ( my @values = $sth->fetchrow_array() ) {
	if ( $values[1] ) {
	    $dbh->do( "insert into serviceprofile_host values('$values[1]','$values[0]')" );
	}
    }
    $sth->finish;
    $dbh->do("ALTER TABLE hosts drop column serviceprofile_id");
}
@table_info = $dbh->selectrow_array("show create table hosts");
unless ( $table_info[1] =~ /FOREIGN KEY\s*\(.hostextinfo_id.\)\s*REFERENCES\s+.extended_host_info_templates.\s*\(.hostextinfo_id.\)\s+ON DELETE SET NULL/i ) {
    $dbh->do( "update hosts set hostextinfo_id = NULL where hostextinfo_id not in (select hostextinfo_id from extended_host_info_templates)" );
    $dbh->do( "ALTER TABLE hosts add FOREIGN KEY (hostextinfo_id) REFERENCES extended_host_info_templates (hostextinfo_id) ON DELETE SET NULL" );
    $dbh->do( "update hosts set hostprofile_id = NULL where hostprofile_id not in (select hostprofile_id from profiles_host)" );
    $dbh->do( "ALTER TABLE hosts add FOREIGN KEY (hostprofile_id) REFERENCES profiles_host (hostprofile_id) ON DELETE SET NULL" );
    $dbh->do( "update hosts set host_escalation_id = NULL where host_escalation_id not in (select tree_id from escalation_trees)" );
    $dbh->do( "ALTER TABLE hosts add FOREIGN KEY (host_escalation_id) REFERENCES escalation_trees(tree_id) ON DELETE SET NULL" );
    $dbh->do( "update hosts set service_escalation_id = NULL where service_escalation_id not in (select tree_id from escalation_trees)" );
    $dbh->do( "ALTER TABLE hosts add FOREIGN KEY (service_escalation_id) REFERENCES escalation_trees (tree_id) ON DELETE SET NULL" );
}

# Clean up possibly bad existing data.
$dbh->do( "update hosts set alias   = trim(alias)" );
$dbh->do( "update hosts set address = trim(address)" );

#-----------------------------------------------------------------------------
# hostgroup
#-----------------------------------------------------------------------------

$sqlstmt = 'describe hostgroups';
$sth     = $dbh->prepare($sqlstmt);
$sth->execute();
%fields = ();
while ( my @values = $sth->fetchrow_array() ) {
    $fields{ $values[0] } = 1;
}
$sth->finish;

if ( defined $fields{'hostgroup_escalation_id'} ) {
    $sqlstmt = 'select hostgroup_id, hostgroup_escalation_id, host_escalation_id from hostgroups';
    $sth     = $dbh->prepare($sqlstmt);
    $sth->execute();
    while ( my @values = $sth->fetchrow_array() ) {
	unless ( $values[2] ) {
	    $dbh->do( "update hostgroups set host_escalation_id = '$values[1]' where hostgroup_id = '$values[0]'" );
	}
    }
    $sth->finish;
    $dbh->do("ALTER TABLE hostgroups drop column hostgroup_escalation_id");
}

unless ( defined $fields{'hostprofile_id'} ) {
    $dbh->do( "ALTER TABLE hostgroups add hostprofile_id SMALLINT(4) UNSIGNED after alias" );
}

@table_info = $dbh->selectrow_array("show create table hostgroups");
unless ( $table_info[1] =~ /FOREIGN KEY\s*\(.host_escalation_id.\)\s*REFERENCES\s+.escalation_trees.\s*\(.tree_id.\)\s+ON DELETE SET NULL/ ) {
    $dbh->do( "ALTER TABLE hostgroups add FOREIGN KEY (hostprofile_id) REFERENCES profiles_host(hostprofile_id) ON DELETE SET NULL" );
    $dbh->do( "update hostgroups set host_escalation_id = NULL where host_escalation_id not in (select tree_id from escalation_trees)" );
    $dbh->do( "ALTER TABLE hostgroups add FOREIGN KEY (host_escalation_id) REFERENCES escalation_trees(tree_id) ON DELETE SET NULL" );
    $dbh->do( "update hostgroups set service_escalation_id = NULL where service_escalation_id not in (select tree_id from escalation_trees)" );
    $dbh->do( "ALTER TABLE hostgroups add FOREIGN KEY (service_escalation_id) REFERENCES escalation_trees(tree_id) ON DELETE SET NULL" );
}

#-----------------------------------------------------------------------------
# servicegroup
#-----------------------------------------------------------------------------

$sqlstmt = 'describe servicegroups';
$sth     = $dbh->prepare($sqlstmt);
$sth->execute();
%fields = ();
while ( my @values = $sth->fetchrow_array() ) {
    $fields{ $values[0] } = 1;
}
$sth->finish;

unless ( defined $fields{'escalation_id'} ) {
    $dbh->do( "ALTER TABLE servicegroups add escalation_id SMALLINT(4) UNSIGNED after alias" );
}
@table_info = $dbh->selectrow_array("show create table servicegroups");
unless ( $table_info[1] =~ /FOREIGN KEY\s*\(.escalation_id.\)\s*REFERENCES\s+.escalation_trees.\s*\(.tree_id.\)\s+ON DELETE SET NULL/ ) {
    $dbh->do( "ALTER TABLE servicegroups add FOREIGN KEY (escalation_id) REFERENCES escalation_trees(tree_id) ON DELETE SET NULL" );
}

#-----------------------------------------------------------------------------
# service
#-----------------------------------------------------------------------------

@table_info = $dbh->selectrow_array("show create table services");
unless ( $table_info[1] =~ /FOREIGN KEY\s*\(.escalation_id.\)\s*REFERENCES\s+.escalation_trees.\s*\(.tree_id.\)\s+ON DELETE SET NULL/ ) {
    $dbh->do( "update services set serviceextinfo_id = NULL where serviceextinfo_id not in (select serviceextinfo_id from extended_service_info_templates)" );
    $dbh->do( "ALTER TABLE services add FOREIGN KEY (serviceextinfo_id) REFERENCES extended_service_info_templates(serviceextinfo_id) ON DELETE SET NULL" );
    $dbh->do( "update services set escalation_id = NULL where escalation_id not in (select tree_id from escalation_trees)" );
    $dbh->do( "ALTER TABLE services add FOREIGN KEY (escalation_id) REFERENCES escalation_trees(tree_id) ON DELETE SET NULL" );
}

#-----------------------------------------------------------------------------
# Service Names
#-----------------------------------------------------------------------------

$sqlstmt = 'describe service_names';
$sth     = $dbh->prepare($sqlstmt);
$sth->execute();
%fields = ();
while ( my @values = $sth->fetchrow_array() ) {
    $fields{ $values[0] } = 1;
}
$sth->finish;

unless ( $fields{'data'} ) {
    $dbh->do("ALTER TABLE service_names add data TEXT after extinfo");
}

if ( defined $fields{'dependency'} ) {
    $sqlstmt = 'select servicename_id, dependency from service_names';
    $sth     = $dbh->prepare($sqlstmt);
    $sth->execute();
    while ( my @values = $sth->fetchrow_array() ) {
	if ( $values[1] ) {
	    $dbh->do( "insert into servicename_dependency values(NULL,'$values[0]',NULL,'$values[1]')" );
	}
    }
    $sth->finish;
    $dbh->do("ALTER TABLE service_names drop column dependency");
}

@table_info = $dbh->selectrow_array("show create table service_names");
unless ( $table_info[1] =~ /FOREIGN KEY\s*\(.escalation.\)\s*REFERENCES\s+.escalation_trees.\s*\(.tree_id.\)\s+ON DELETE SET NULL/ ) {
    $dbh->do( "update service_names set extinfo = NULL where extinfo not in (select serviceextinfo_id from extended_service_info_templates)" );
    $dbh->do( "ALTER TABLE service_names add FOREIGN KEY (extinfo) REFERENCES extended_service_info_templates(serviceextinfo_id) ON DELETE SET NULL" );
    $dbh->do( "update service_names set escalation = NULL where escalation not in (select tree_id from escalation_trees)" );
    $dbh->do( "ALTER TABLE service_names add FOREIGN KEY (escalation) REFERENCES escalation_trees(tree_id) ON DELETE SET NULL" );
}

#-----------------------------------------------------------------------------
# Host Profiles
#-----------------------------------------------------------------------------

@table_info = $dbh->selectrow_array("show create table profiles_host");
unless ( $table_info[1] =~ /FOREIGN KEY\s*\(.host_extinfo_id.\)\s*REFERENCES\s+.extended_host_info_templates.\s*\(.hostextinfo_id.\)\s+ON DELETE SET NULL/ ) {
    $dbh->do( "update profiles_host set host_extinfo_id = NULL where host_extinfo_id not in (select hostextinfo_id from extended_host_info_templates)" );
    $dbh->do( "ALTER TABLE profiles_host add FOREIGN KEY (host_extinfo_id) REFERENCES extended_host_info_templates(hostextinfo_id) ON DELETE SET NULL" );
    $dbh->do( "update profiles_host set host_escalation_id = NULL where host_escalation_id not in (select tree_id from escalation_trees)" );
    $dbh->do( "ALTER TABLE profiles_host add FOREIGN KEY (host_escalation_id) REFERENCES escalation_trees(tree_id) ON DELETE SET NULL" );
    $dbh->do( "update profiles_host set service_escalation_id = NULL where service_escalation_id not in (select tree_id from escalation_trees)" );
    $dbh->do( "ALTER TABLE profiles_host add FOREIGN KEY (service_escalation_id) REFERENCES escalation_trees(tree_id) ON DELETE SET NULL" );
}

# Add data column for saved settings
$sqlstmt = 'describe profiles_host';
$sth     = $dbh->prepare($sqlstmt);
$sth->execute();
%fields = ();
while ( my @values = $sth->fetchrow_array() ) {
    $fields{ $values[0] } = 1;
}
$sth->finish;
unless ( defined $fields{'data'} ) {
    $dbh->do('alter table profiles_host add data TEXT after file_id');
}

if ( defined $fields{'file_id'} ) {
    $dbh->do('alter table profiles_host drop file_id');
}

# Add data column for saved settings
if ( defined $fields{'serviceprofile_id'} ) {
    my $sqlstmt = "select hostprofile_id, serviceprofile_id from profiles_host";
    $sth = $dbh->prepare($sqlstmt);
    $sth->execute();
    my %fields = ();
    while ( my @values = $sth->fetchrow_array() ) {
	if ( $values[1] ) {
	    $dbh->do( "insert into profile_host_profile_service values('$values[0]','$values[1]')" );
	}
    }
    $sth->finish;
    $dbh->do("ALTER TABLE profiles_host drop column serviceprofile_id");
}

#-----------------------------------------------------------------------------
# Service Profiles
#-----------------------------------------------------------------------------

# Add data column for saved settings
$sqlstmt = 'describe profiles_service';
$sth     = $dbh->prepare($sqlstmt);
$sth->execute();
%fields = ();
while ( my @values = $sth->fetchrow_array() ) {
    $fields{ $values[0] } = 1;
}
$sth->finish;
unless ( defined $fields{'data'} ) {
    $dbh->do('alter table profiles_service add data TEXT after file_id');
}

if ( defined $fields{'file_id'} ) {
    $dbh->do('alter table profiles_service drop file_id');
}

@table_info = $dbh->selectrow_array("show create table serviceprofile");
unless ( $table_info[1] =~ /FOREIGN KEY\s*\(.serviceprofile_id.\)\s*REFERENCES\s+.profiles_service.\s*\(.serviceprofile_id.\) ON DELETE CASCADE/ ) {
    $dbh->do( "ALTER TABLE serviceprofile add FOREIGN KEY (serviceprofile_id) REFERENCES profiles_service(serviceprofile_id) ON DELETE CASCADE" );
    $dbh->do( "ALTER TABLE serviceprofile add FOREIGN KEY (servicename_id) REFERENCES service_names(servicename_id) ON DELETE CASCADE" );
}

##############################################################################
# drop obsolete tables
##############################################################################

my @drop_list = (
    'stage_escalations', 'match_strings',
    'import_schemas',    'stage_status',
    'files',             'file_host',
    'file_service'
);
foreach my $drop (@drop_list) {
    if ( $tables{$drop} ) { $dbh->do("drop table $drop") }
}

##############################################################################
# Modify database content to reflect newer product releases
##############################################################################

#-----------------------------------------------------------------------------
# convert 1.2 macros to 2.x
#-----------------------------------------------------------------------------

if ($is_portal) {
    $sqlstmt = "select command_id, data from commands";
    $sth     = $dbh->prepare($sqlstmt);
    $sth->execute();
    while ( my @values = $sth->fetchrow_array() ) {
	my %command = parse_xml( $values[1] );
	## FIX MAJOR:  Look for $command{'error'} and take evasive action if found.
	if ( $command{'command_line'} =~ /\$PERFDATA\$|\$LASTCHECK\$|\$LASTSTATECHANGE\$|\$LATENCY\$|\$EXECUTIONTIME\$|\$OUTPUT\$|\$STATETYPE\$/ ) {
	    if ($command{'command_line'} =~ /\$SERVICE/) {
		$command{'command_line'} =~ s/\$PERFDATA\$/\$SERVICEPERFDATA\$/g;
		$command{'command_line'} =~ s/\$LASTCHECK\$/\$LASTSERVICECHECK\$/g;
		$command{'command_line'} =~ s/\$LASTSTATECHANGE\$/\$LASTSERVICESTATECHANGE\$/g;
		$command{'command_line'} =~ s/\$LATENCY\$/\$SERVICELATENCY\$/g;
		$command{'command_line'} =~ s/\$EXECUTIONTIME\$/\$SERVICEEXECUTIONTIME\$/g;
		$command{'command_line'} =~ s/\$OUTPUT\$/\$SERVICEOUTPUT\$/g;
		$command{'command_line'} =~ s/\$STATETYPE\$/\$SERVICESTATETYPE\$/g;
	    }
	    else {
		$command{'command_line'} =~ s/\$PERFDATA\$/\$HOSTPERFDATA\$/g;
		$command{'command_line'} =~ s/\$LASTCHECK\$/\$LASTHOSTCHECK\$/g;
		$command{'command_line'} =~ s/\$LASTSTATECHANGE\$/\$LASTHOSTSTATECHANGE\$/g;
		$command{'command_line'} =~ s/\$LATENCY\$/\$HOSTLATENCY\$/g;
		$command{'command_line'} =~ s/\$EXECUTIONTIME\$/\$HOSTEXECUTIONTIME\$/g;
		$command{'command_line'} =~ s/\$OUTPUT\$/\$HOSTOUTPUT\$/g;
		$command{'command_line'} =~ s/\$STATETYPE\$/\$HOSTSTATETYPE\$/g;
	    }
	    my $data = qq(<?xml version="1.0" ?>
<data>
 <prop name="command_line"><![CDATA[$command{'command_line'}]]>
 </prop>
</data>);
	    $data = $dbh->quote($data);
	    $dbh->do( "update commands set data = $data where command_id = '$values[0]'" );
	}
    }
    $sth->finish;
}

#-----------------------------------------------------------------------------
# Nagios 3.0: Remove Nagios configuration options not used in 3.x
#-----------------------------------------------------------------------------

# GWMON-6260:  This cleanup also includes removal of two spurious options
# (misc_name and misc_value) stored in the table by mistake.

if ( $nagios_version =~ /^3\.?/ ) {
    my @obsolete_options = qw(aggregate_status_updates downtime_file comment_file misc_name misc_value);
    foreach my $obsolete_option (@obsolete_options) {
	$sqlstmt = "delete from setup where name = '$obsolete_option'";
	$sth     = $dbh->prepare($sqlstmt);
	$sth->execute();
	$sth->finish;
    }
}

#-----------------------------------------------------------------------------
# Nagios 3.0: Convert old Nagios configuration option names to their 3.x forms
#-----------------------------------------------------------------------------

# An ugly situation we need to allow for here is if the site has restored a pre-3.x
# database backup, then failed to run this migration script, then modified the
# configuration through Monarch.  For each of the renamed options, Monarch will
# insert a copy of the new option name while leaving the old option name still
# in place.  A straight database update in that situation will fail because of a
# duplicate key error.  We need to find some kind of workaround for this situation.

# First, prepare for both this and later migration adjustments.
my @group_id = ();
$sqlstmt = "select distinct group_id from monarch_group_props";
$sth     = $dbh->prepare($sqlstmt);
$sth->execute();
while ( my @values = $sth->fetchrow_array() ) {
    push @group_id, $values[0];
}
$sth->finish;

# Now do the checking and conversion of old-to-new option names.
if ( $nagios_version =~ /^3\.?/ ) {
    my %new_option_names = (
	 'use_agressive_host_checking' => 'use_aggressive_host_checking',
	 'service_reaper_frequency'    => 'check_result_reaper_frequency',
    );

    foreach my $old_option_name (keys %new_option_names) {
	my $new_option_name = $new_option_names{$old_option_name};

	my $old_option_name_exists = $dbh->selectrow_array( "select count(*) from setup where name='$old_option_name'" );
	my $new_option_name_exists = $dbh->selectrow_array( "select count(*) from setup where name='$new_option_name'" );

	my $old_option_name_value = $dbh->selectrow_array( "select value from setup where name='$old_option_name'" );
	my $new_option_name_value = $dbh->selectrow_array( "select value from setup where name='$new_option_name'" );

	if (! defined($old_option_name_value)) {
	    $old_option_name_value = $old_option_name_exists ? 'NULL' : 'DOES NOT EXIST';
	}
	if (! defined($new_option_name_value)) {
	    $new_option_name_value = $new_option_name_exists ? 'NULL' : 'DOES NOT EXIST';
	}

	# These lines were helpful in debugging ...
	# print "\t${old_option_name}_value='$old_option_name_value'\n";
	# print "\t${new_option_name}_value='$new_option_name_value'\n";

	if ($old_option_name_exists && $new_option_name_exists) {
	    if ($old_option_name_value ne $new_option_name_value) {
		(my $user_new_option_name = "\u$new_option_name") =~ s/_/ /g;
		print "\n";
		print "\t====================================================================\n";
		print "\t    WARNING:  For the primary Nagios configuration,\n";
		print "\t        the old $old_option_name value of '$old_option_name_value'\n";
		print "\t    is being ignored in favor of\n";
		print "\t        the new $new_option_name value of '$new_option_name_value'.\n";
		print "\t    (Note the slight option name spelling difference.)\n" if $old_option_name eq 'use_agressive_host_checking';
		print "\n";
		print "\t    This may change the behavior of your system!\n";
		print "\n";
		print "\t    Check the Nagios main configuration pages to set the\n";
		print "\t    '$user_new_option_name' option as you desire.\n";
		print "\t====================================================================\n";
		print "\n";
	    }
	    $dbh->do( "delete from setup where name='$old_option_name'" );
	}

	foreach my $group_id (@group_id) {
	    my $old_option_name_exists  = $dbh->selectrow_array(
		"select count(*) from monarch_group_props where group_id=$group_id and name='$old_option_name'" );
	    my $new_option_name_exists = $dbh->selectrow_array(
		"select count(*) from monarch_group_props where group_id=$group_id and name='$new_option_name'" );

	    my $old_option_name_value  = $dbh->selectrow_array(
		"select value from monarch_group_props where group_id=$group_id and name='$old_option_name'" );
	    my $new_option_name_value = $dbh->selectrow_array(
		"select value from monarch_group_props where group_id=$group_id and name='$new_option_name'" );

	    if (! defined($old_option_name_value)) {
		$old_option_name_value = $old_option_name_exists ? 'NULL' : 'DOES NOT EXIST';
	    }
	    if (! defined($new_option_name_value)) {
		$new_option_name_value = $new_option_name_exists ? 'NULL' : 'DOES NOT EXIST';
	    }

	    # These lines were helpful in debugging ...
	    # print "\t${old_option_name}_value='$old_option_name_value'\n";
	    # print "\t${new_option_name}_value='$new_option_name_value'\n";

	    if ($old_option_name_exists && $new_option_name_exists) {
		if ($old_option_name_value ne $new_option_name_value) {
		    my $group_name = $dbh->selectrow_array( "select name from monarch_groups where group_id=$group_id" );
		    (my $user_new_option_name = "\u$new_option_name") =~ s/_/ /g;
		    print "\n";
		    print "\t====================================================================\n";
		    print "\t    WARNING:  For the Nagios configuration of the '$group_name' Group,\n";
		    print "\t        the old $old_option_name value of '$old_option_name_value'\n";
		    print "\t    is being ignored in favor of\n";
		    print "\t        the new $new_option_name value of '$new_option_name_value'.\n";
		    print "\t    (Note the slight option name spelling difference.)\n" if $old_option_name eq 'use_agressive_host_checking';
		    print "\n";
		    print "\t    This may change the behavior of your system!\n";
		    print "\n";
		    print "\t    Check the Nagios main configuration pages to set the\n";
		    print "\t    '$user_new_option_name' option as you desire.\n";
		    print "\t====================================================================\n";
		    print "\n";
		}
		$dbh->do( "delete from monarch_group_props where group_id=$group_id and name='$old_option_name'" );
	    }
	}

	$sqlstmt = "update setup set name = '$new_option_name' where name = '$old_option_name'";
	$sth     = $dbh->prepare($sqlstmt);
	$sth->execute();
	$sth->finish;

	$sqlstmt = "update monarch_group_props set name = '$new_option_name' where name = '$old_option_name'";
	$sth     = $dbh->prepare($sqlstmt);
	$sth->execute();
	$sth->finish;
    }
}

#-----------------------------------------------------------------------------
# Nagios 3.0: Add Nagios configuration options new in 3.x.
# GWMON-6148: Convert user-added miscellaneous directives to
# now-supported standard directives, when possible.
#-----------------------------------------------------------------------------

# This hash will include data on both standard and miscellaneous directives, but the names of miscellaneous
# directives have a 'key'.rand() extension to distinguish these names from equivalent standard directive names.
# The name change is needed because (as of this writing) the monarch.setup table contains a unique index on
# only the setup.name field, not including the setup.type field (which would otherwise provide the necessary
# distinction between standard and miscellaneous directives ['nagios', 'nagios_cgi', and some others, vs.
# 'nagios_cfg_misc']).  The modified names means there won't be any confusion as to whether a particular
# directive name is a standard (Monarch-supported) or miscellaneous (user-added) directive.
my %setup_props = ();
$sth = $dbh->prepare("select name, value from setup");
$sth->execute();
while ( my @values = $sth->fetchrow_array() ) {
    $setup_props{ $values[0] } = $values[1];
}
$sth->finish;

# This hash will include data on just miscellaneous directives, for the primary main configuration.
my %setup_misc_props = ();
$sth = $dbh->prepare("select name, value from setup where type='nagios_cfg_misc'");
$sth->execute();
while ( my @values = $sth->fetchrow_array() ) {
    (my $directive = $values[0]) =~ s/key\d\.\d+$//;
    $setup_misc_props{$directive}{misc_name} = $values[0];
    $setup_misc_props{$directive}{value}     = $values[1];
}
$sth->finish;

# This hash will include data on both standard and miscellaneous directives.  The latter are distinguished
# not by name, but by monarch_group_props.type='nagios_cfg_misc'.  So we need to be careful about how we
# interpret this data later on.
my %group_props = ();
$sth = $dbh->prepare("select group_id, name, type, value from monarch_group_props");
$sth->execute();
while ( my @values = $sth->fetchrow_array() ) {
    ## We use {$values[2]} here to distinguish between standard and miscellaneous directives with the same name.
    $group_props{ $values[0] }{ $values[1] }{ $values[2] } = $values[3];
}
$sth->finish;

# This hash will include data on just miscellaneous directives, for each group's main configuration.
my %group_misc_props = ();
$sth = $dbh->prepare("select group_id, name, value from monarch_group_props where type='nagios_cfg_misc'");
$sth->execute();
while ( my @values = $sth->fetchrow_array() ) {
    $group_misc_props{ $values[0] }{ $values[1] } = $values[2];
}
$sth->finish;

if ( $nagios_version =~ /^3\.?/ ) {

    # NOTE: there may be more options that are not listed here.
    # This list comes from Gwiki, and is based on the first-cut
    # assessment of which options should be added.  Furthermore,
    # even though these options are added here, that does not
    # necessarily mean that all of them are being used right now.

    (my $nagios_dir = $nagios_etc) =~ s{/etc$}{};

    my %new_options =
	(
	'external_command_buffer_slots' => ['nagios',     ''],
	'use_large_installation_tweaks' => ['nagios',     '1'],
	'enable_environment_macros'     => ['nagios',     '0'],
	'child_processes_fork_twice'    => ['nagios',     '0'],
	'free_child_process_memory'     => ['nagios',     '0'],
	'check_result_path'             => ['nagios',     "$nagios_dir/var/checkresults"],
	'max_check_result_reaper_time'  => ['nagios',     ''],
	'max_check_result_file_age'     => ['nagios',     ''],
	'translate_passive_host_checks' => ['nagios',     '0'],
	'passive_host_checks_are_soft'  => ['nagios',     '0'],
	'cached_host_check_horizon'     => ['nagios',     '15'],
	'cached_service_check_horizon'  => ['nagios',     '15'],
	'precached_object_file'         => ['nagios',     "$nagios_dir/var/objects.precache"],
	'lock_author_names'             => ['nagios_cgi', '0'],
	);

    # Handle any existing miscellaneous directives for the main configuration
    # that might already have a value set for one of the new options.
    foreach my $directive (keys %setup_misc_props) {
	if (exists $new_options{$directive}) {
	    if ( exists $setup_props{$directive} ) {
		## We have a conflict, namely both a standard directive and a miscellaneous directive of the
		## same name.  Take the value of the last one that we would have placed in the nagios.cfg file
		## (i.e., the miscellaneous directive), and use that because it's our best approximation to what
		## would have been the operational configuration without this adjustment.  But since we do have a
		## conflict, also emit a warning message to describe the conflict and how we are resolving it.
		$sqlstmt = "update setup set value=? where name=? and type=?";
		$sth     = $dbh->prepare($sqlstmt);
		unless ( $sth->execute( $setup_misc_props{$directive}{value}, $directive, $new_options{$directive}[0] ) ) {
		    print "Error: $sqlstmt ($sth->errstr)";
		}
		$sth->finish;
		print "\n\tWARNING:  In the Nagios main configuration for the base product\n";
		print "\t          setup, the '$directive' value was defined\n";
		print "\t          both as a standard directive (with value '$setup_props{$directive}') and\n";
		print "\t          as a miscellaneous directive (with value '$setup_misc_props{$directive}{value}').\n";
		print "\t          The latter value will now be used as the value of the\n";
		print "\t          standard directive, while the miscellaneous directive\n";
		print "\t          definition itself has been destroyed.\n";
	    }
	    else {
		## We have a miscellaneous directive with no matching standard directive, where the
		## miscellaneous directive names a new option that should now be a standard directive.
		## Insert the new standard directive, using the value of the miscellaneous directive.
		$sqlstmt = "insert into setup values(?,?,?)";
		$sth     = $dbh->prepare($sqlstmt);
		unless ( $sth->execute( $directive, $new_options{$directive}[0], $setup_misc_props{$directive}{value} ) ) {
		    print "Error: $sqlstmt ($sth->errstr)";
		}
		$sth->finish;
		## Now that we have the option established, don't try to add the option again below.
		$setup_props{$directive} = $setup_misc_props{$directive}{value};
	    }

	    # Destroy the miscellaneous directive, now that we have converted it to a standard directive.
	    $sqlstmt = "delete from setup where name=? and type='nagios_cfg_misc'";
	    $sth     = $dbh->prepare($sqlstmt);
	    unless ( $sth->execute( $setup_misc_props{$directive}{misc_name} ) ) { print "Error: $sqlstmt ($sth->errstr)" }
	    $sth->finish;
	}
    }

    # Do the same for groups as well, processing their own individual miscellaneous directives separately for each group.
    foreach my $group_id (keys %group_misc_props) {
	foreach my $directive (keys %{ $group_misc_props{$group_id} } ) {
	    if ( exists $new_options{$directive} ) {
		my $type = $new_options{$directive}[0];    # just for readability
		## The "type" field in the monarch_group_props table has a different enumeration
		## than it does in the setup table, so we translate here.
		my $group_type = $type eq 'nagios' ? 'nagios_cfg' : $type eq 'nagios_cgi' ? 'nagios_cgi' : 'unknown';
		if ( $group_props{$group_id}{$directive} && exists $group_props{$group_id}{$directive}{$group_type} ) {
		    ## We have a conflict, namely both a standard directive and a miscellaneous directive of the
		    ## same name.  Take the value of the last one that we would have placed in the nagios.cfg file
		    ## (i.e., the miscellaneous directive), and use that because it's our best approximation to what
		    ## would have been the operational configuration without this adjustment.  But since we do have a
		    ## conflict, also emit a warning message to describe the conflict and how we are resolving it.
		    $sqlstmt = "update monarch_group_props set value=? where group_id=? and name=? and type=?";
		    $sth     = $dbh->prepare($sqlstmt);
		    unless ( $sth->execute( $group_misc_props{$group_id}{$directive}, $group_id, $directive, $group_type ) ) {
			print "Error: $sqlstmt ($sth->errstr)";
		    }
		    $sth->finish;
		    my $group_name = $dbh->selectrow_array("select name from monarch_groups where group_id=$group_id");
		    print "\n\tWARNING:  In the Nagios main configuration for the '$group_name'\n";
		    print "\t          configuration group, the '$directive' value was defined\n";
		    print "\t          both as a standard directive (with value '$group_props{$group_id}{$directive}{$group_type}') and\n";
		    print "\t          as a miscellaneous directive (with value '$group_misc_props{$group_id}{$directive}').\n";
		    print "\t          The latter value will now be used as the value of the\n";
		    print "\t          standard directive, while the miscellaneous directive\n";
		    print "\t          definition itself has been destroyed.\n";
		}
		else {
		    ## We have a miscellaneous directive with no matching standard directive, where the
		    ## miscellaneous directive names a new option that should now be a standard directive.
		    ## Insert the new standard directive, using the value of the miscellaneous directive.
		    ## (We could have just updated the type field of the existing row, to avoid chewing up
		    ## an extra monarch_group_props.prop_id value.  Maybe in the future, we'll do that.)
		    $sqlstmt = "insert into monarch_group_props values(NULL,?,?,?,?)";
		    $sth     = $dbh->prepare($sqlstmt);
		    unless ( $sth->execute( $group_id, $directive, $group_type, $group_misc_props{$group_id}{$directive} ) ) {
			print "Error: $sqlstmt ($sth->errstr)";
		    }
		    $sth->finish;
		    ## Now that we have the option established, don't try to add the option again below.
		    $group_props{$group_id}{$directive}{$group_type} = $group_misc_props{$group_id}{$directive};
		}

		# Destroy the miscellaneous directive, now that we have converted it to a standard directive.
		$sqlstmt = "delete from monarch_group_props where group_id=? and name=? and type='nagios_cfg_misc'";
		$sth     = $dbh->prepare($sqlstmt);
		unless ( $sth->execute( $group_id, $directive ) ) { print "Error: $sqlstmt ($sth->errstr)" }
		$sth->finish;
	    }
	}
    }

    foreach my $option ( keys %new_options ) {
	my $type       = $new_options{$option}[0];  # just for readability
	my $value      = $new_options{$option}[1];  # just for readability
	## The "type" field in the monarch_group_props table has a different enumeration
	## than it does in the setup table, so we translate here.
	my $group_type = $type eq 'nagios' ? 'nagios_cfg' : $type eq 'nagios_cgi' ? 'nagios_cgi' : 'unknown';

	unless ( exists $setup_props{$option} ) {
	    $sqlstmt = "insert into setup values(?,?,?)";
	    $sth     = $dbh->prepare($sqlstmt);
	    unless ( $sth->execute( $option, $type, $value ) ) { print "Error: $sqlstmt ($sth->errstr)" }
	    $sth->finish;
	    $setup_props{$option} = $value;
	}

	foreach my $group_id (@group_id) {
	    unless ( exists $group_props{$group_id}{$option}{$group_type} ) {
		$sqlstmt = "insert into monarch_group_props values(NULL,?,?,?,?)";
		$sth     = $dbh->prepare($sqlstmt);
		unless ( $sth->execute( $group_id, $option, $group_type, $value ) ) {
		    print "Error: $sqlstmt ($sth->errstr)";
		}
		$sth->finish;
	    }
	}
    }
}

#-----------------------------------------------------------------------------
# Nagios 3.0: Convert values for specific Nagios configuration options
#-----------------------------------------------------------------------------

# GWMON-6261: remove a single-quote character from the list of illegal macro (plugin) output characters
$dbh->do( "update setup set value = replace(value,'''','') where name = 'illegal_macro_output_chars'" );

# GWMON-6563: do the same for all Monarch Groups
$dbh->do( "update monarch_group_props set value = replace(value,'''','') where name = 'illegal_macro_output_chars'" );

#-----------------------------------------------------------------------------
# Nagios 3.0: Update paths stored in database for BitRock install
#-----------------------------------------------------------------------------

# This should be changed to query the installer version, instead
# of the Nagios version, because the changed paths really relate to
# the BitRock installer, not to the version of Nagios.
if ( $nagios_version =~ /^3\.?/ ) {

    $sqlstmt = "update setup set value = '/usr/local/groundwork/monarch' where name = 'monarch_home'";
    $sth = $dbh->prepare($sqlstmt);
    unless ( $sth->execute ) { print "Error: $sqlstmt ($sth->errstr)" }
    $sth->finish;

    $sqlstmt = "update setup set value = '/usr/local/groundwork/monarch/backup' where name = 'backup_dir'";
    $sth = $dbh->prepare($sqlstmt);
    unless ( $sth->execute ) { print "Error: $sqlstmt ($sth->errstr)" }
    $sth->finish;

    $sqlstmt = "update setup set value = replace(value,'bin/nagios','bin/.nagios.bin') where name = 'nagios_check_command' and type = 'nagios_cgi'";
    $sth = $dbh->prepare($sqlstmt);
    unless ( $sth->execute ) { print "Error: $sqlstmt ($sth->errstr)" }
    $sth->finish;

    $sqlstmt = "update commands set data = replace(data,'bin/nagios','bin/.nagios.bin') where name = 'check_nagios' and type = 'check'";
    $sth = $dbh->prepare($sqlstmt);
    unless ( $sth->execute ) { print "Error: $sqlstmt ($sth->errstr)" }
    $sth->finish;

    $sqlstmt = "update commands set data = replace(data,'/usr/local/groundwork/bin/sendEmail','/usr/bin/sendEmail')";
    $sth = $dbh->prepare($sqlstmt);
    unless ( $sth->execute ) { print "Error: $sqlstmt ($sth->errstr)" }
    $sth->finish;

    $sqlstmt = "update commands set data = replace(data,'/usr/local/groundwork/bin/send_nsca','/usr/bin/send_nsca')";
    $sth = $dbh->prepare($sqlstmt);
    unless ( $sth->execute ) { print "Error: $sqlstmt ($sth->errstr)" }
    $sth->finish;

    $sqlstmt = "update commands set data = replace(data,'/usr/local/groundwork/etc/send_nsca.cfg','/usr/local/nagios/etc/send_nsca.cfg')";
    $sth = $dbh->prepare($sqlstmt);
    unless ( $sth->execute ) { print "Error: $sqlstmt ($sth->errstr)" }
    $sth->finish;

    $sqlstmt = "update import_schema set data_source = replace(data_source,'/usr/local/groundwork/monarch/','/usr/local/groundwork/monarch/')";
    $sth = $dbh->prepare($sqlstmt);
    unless ( $sth->execute ) { print "Error: $sqlstmt ($sth->errstr)" }
    $sth->finish;
}

#-----------------------------------------------------------------------------
# Nagios 3.0: Specify a default value for the check_interval option in
# host templates, as a prophylactic to help avoid rising latencies.
# Also institute a value for max_check_attempts greater than 1 if we do so,
# if there is not already such a value in play, to avoid a possible big
# performance hit.
#-----------------------------------------------------------------------------

# GWMON-7030

my $all_host_template_defaults = qq(<data>
  <prop name=\"check_interval\"><![CDATA[-zero-]]>
  </prop>
  <prop name=\"max_check_attempts\"><![CDATA[3]]>
  </prop>);
my $check_interval_only = qq(<data>
  <prop name=\"check_interval\"><![CDATA[-zero-]]>
  </prop>);
my $max_check_attempts_new_value = qq(<prop name=\"max_check_attempts\"><![CDATA[3]]>);

$dbh->do( "update host_templates set data = replace(data,'<data>','$all_host_template_defaults') where data not like '%\"check_interval\"%' and data not like '%\"max_check_attempts\"%'" );

$dbh->do( "update host_templates set data = replace(replace(data,'<prop name=\"max_check_attempts\"><![CDATA[-zero-]]>','$max_check_attempts_new_value'),'<data>','$check_interval_only') where data not like '%\"check_interval\"%' and data like '%\"max_check_attempts\"><![CDATA[-zero-]]>%'" );

$dbh->do( "update host_templates set data = replace(replace(data,'<prop name=\"max_check_attempts\"><![CDATA[1]]>','$max_check_attempts_new_value'),'<data>','$check_interval_only') where data not like '%\"check_interval\"%' and data like '%\"max_check_attempts\"><![CDATA[1]]>%'" );

$dbh->do( "update host_templates set data = replace(data,'<data>','$check_interval_only') where data not like '%\"check_interval\"%'" );

#-----------------------------------------------------------------------------
# Update commands stored in database for revised plugins
#-----------------------------------------------------------------------------

# GWMON-5206, GWMON-6056

$sqlstmt = "update commands set data = replace(data,'/check_mem.pl -u','/check_mem.pl -U') where name = 'check_by_ssh_mem' and type = 'check'";
$sth = $dbh->prepare($sqlstmt);
unless ( $sth->execute ) { print "Error: $sqlstmt ($sth->errstr)" }
$sth->finish;

$sqlstmt = "update commands set data = replace(data,'/check_mem.pl -u','/check_mem.pl -U') where name = 'check_local_mem' and type = 'check'";
$sth = $dbh->prepare($sqlstmt);
unless ( $sth->execute ) { print "Error: $sqlstmt ($sth->errstr)" }
$sth->finish;

#-----------------------------------------------------------------------------
# GWMON-8762:  Update notification commands stored in the database, to be
# portable across Linux distributions.  (/usr/bin/mail
# will now be a symlink to the local mail program, wherever it resides.)
#-----------------------------------------------------------------------------

$sqlstmt = "update commands set data = replace(data,' /bin/mail ',' /usr/bin/mail ') where type = 'notify'";
$sth = $dbh->prepare($sqlstmt);
unless ( $sth->execute ) { print "Error: $sqlstmt ($sth->errstr)" }
$sth->finish;

#-----------------------------------------------------------------------------
# GWMON-3363:  As of version 5.2, GW Monitor now uses Nagios 2.10, so
# we can undo the workaround previously applied to deal with bug in
# Nagios 2.5 (fixed in Nagios 2.9) where the sense of the performance
# logging verbosity flag was reversed.
#-----------------------------------------------------------------------------

# first check whether we've already removed the workaround, because
# doing it again would toggle the flags back to the wrong settings.

if ($is_portal) {
    #
    # Read current installed Nagios version from /tmp/nagiosversion.txt
    #
    # Daniel P. added some code to the installer that creates the
    # /tmp/nagiosversion.txt file referenced below. Using this technique
    # of checking the version perpetuates a dependency on that old
    # installer. Instead of using this code, we are using the subroutine
    # get_nagios_version_numeric() defined below.
    #
    # # my $data_file = "/tmp/nagiosversion.txt";
    # # Pathname updated for GW 5.3 RPMs, when we were still using RPM installations.
    # my $data_file = "/usr/local/nagios/tmp/nagiosversion.txt";
    # open( DAT, '<', $data_file ) || die("Could not open file: $data_file");
    # my $nvn = <DAT>;
    # chomp($nvn);
    # close(DAT);

    $sqlstmt = "select value from setup where name = 'perflogbug_workaround_removed'";
    my ($workaround_removed) = $dbh->selectrow_array($sqlstmt);
    if ( !defined($workaround_removed) ) {
	print "\tNagios verbosity-flag bug workaround not defined.  Defining ...\n";
	$sqlstmt = "insert into setup values('perflogbug_workaround_removed','nagios','0')";
	$sth     = $dbh->prepare($sqlstmt);
	unless ( $sth->execute ) { print "Error: $sqlstmt ($sth->errstr)" }
	$sth->finish;
	$workaround_removed = 0;
    }

    # TODO: this assumes that during a migration, the new version of
    # Nagios is installed before this script runs. Is that true?
    # my $nagios_version_numeric = $nvn;
    my $nagios_version_numeric = get_nagios_version_numeric();

    # need to swap the current values iff we haven't already AND Nagios is < 2.9
    if ( !$workaround_removed && $nagios_version_numeric < 2.9 ) {
	print "Attempting to Swap Value ...\n";
	$sqlstmt = "update setup set value = 'temp_w' where name = 'host_perfdata_file_mode' and value = 'a'";
	$sth = $dbh->prepare($sqlstmt);
	unless ( $sth->execute ) { print "Error: $sqlstmt ($sth->errstr)" }
	$sth->finish;

	$sqlstmt = "update setup set value = 'a' where name = 'host_perfdata_file_mode' and value = 'w'";
	$sth = $dbh->prepare($sqlstmt);
	unless ( $sth->execute ) { print "Error: $sqlstmt ($sth->errstr)" }
	$sth->finish;

	$sqlstmt = "update setup set value = 'w' where name = 'host_perfdata_file_mode' and value = 'temp_w'";
	$sth = $dbh->prepare($sqlstmt);
	unless ( $sth->execute ) { print "Error: $sqlstmt ($sth->errstr)" }
	$sth->finish;

	$sqlstmt = "update setup set value = 'temp_w' where name = 'service_perfdata_file_mode' and value = 'a'";
	$sth = $dbh->prepare($sqlstmt);
	unless ( $sth->execute ) { print "Error: $sqlstmt ($sth->errstr)" }
	$sth->finish;

	$sqlstmt = "update setup set value = 'a' where name = 'service_perfdata_file_mode' and value = 'w'";
	$sth = $dbh->prepare($sqlstmt);
	unless ( $sth->execute ) { print "Error: $sqlstmt ($sth->errstr)" }
	$sth->finish;

	$sqlstmt = "update setup set value = 'w' where name = 'service_perfdata_file_mode' and value = 'temp_w'";
	$sth = $dbh->prepare($sqlstmt);
	unless ( $sth->execute ) { print "Error: $sqlstmt ($sth->errstr)" }
	$sth->finish;

	# set the flag indicating that we have now removed (undone) the workaround.
	$sqlstmt = "update setup set value = '1' where name = 'perflogbug_workaround_removed'";
	$sth = $dbh->prepare($sqlstmt);
	unless ( $sth->execute ) { print "Error: $sqlstmt ($sth->errstr)" }
	$sth->finish;

	#swap the values in the nagios.cfg file
	fix_nagios_cfg();
    }

    sub fix_nagios_cfg {
	open( NAGIOSCFG, '<', '/usr/local/nagios/etc/nagios.cfg' )
	  || die "Couldn't open nagios.cfg: $!";
	open( CFGTMP, '>', '/tmp/nagios.cfg.tmp' )
	  || die "Couldn't open temp file for nagios.cfg: $!";

	#swap w & a
	while (<NAGIOSCFG>) {
	    my $line = $_;
	    if (   ( $line =~ /host_perfdata_file_mode/ )
		|| ( $line =~ /service_perfdata_file_mode/ ) )
	    {
		my ( $key, $value ) = split( /=/, $line );
		chomp($value);
		if    ( $value eq "w" ) { $value = "a"; }
		elsif ( $value eq "a" ) { $value = "w"; }

		print CFGTMP "${key}=${value}\n";
	    }
	    else {
		print CFGTMP $line;
	    }
	}

	#replace old nagios.cfg with new
	print `/bin/cp /tmp/nagios.cfg.tmp /usr/local/nagios/etc/nagios.cfg`;
	print `/rm -rf /tmp/nagios.cfg.tmp`;
    }

    sub get_nagios_version_numeric {
	my $command = '/usr/local/nagios/bin/nagios';

	# TODO: safe to assume sed is available on path on all platforms?
	open( my $cmd, "($command | sed 's/^/STDOUT:/') 2>&1 |" );
	my $results_stderr;
	my $results_stdout;
	while (<$cmd>) {
	    if (s/^STDOUT://) {
		$results_stdout .= $_;
	    }
	    else {
		$results_stderr .= $_;
	    }
	}
	close($cmd);
	my $version_major;
	my $version_minor;
	my $version_numeric;
	if ( defined($results_stdout) ) {
	    if ( $results_stdout =~ /^[\n\r]*Nagios(?: Core)?\s+(\d+)(?:\.(\d+))?/ ) {
		$version_major   = $1;
		$version_minor   = $2 || '0';
		$version_numeric = "$version_major.$version_minor";
	    }
	}
	return $version_numeric + 0.0;
    }
}

#-----------------------------------------------------------------------------
# Simple modification to improve handling of performanceconfig graphing
#-----------------------------------------------------------------------------

$dbh->do( "update performanceconfig set graphcgi='\\'\\'' where service = 'Current Load' and graphcgi = ''" );

#-----------------------------------------------------------------------------
# Convert to the new service perfdata file processing daemon
#-----------------------------------------------------------------------------

$dbh->do("LOCK TABLES commands WRITE");

# WARNING:  If you need to edit these lines, watch carefully for the treatment of
# backslash escapes, to make sure you really do get exactly what you want inserted.
# Test like mad.

idempotent_insert ('commands', 'launch_perfdata_process',
    "(NULL,'launch_perfdata_process','other','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[\$USER2\$/launch_perf_data_processing]]>\n  </prop>\n</data>',NULL)" );

$dbh->do("UNLOCK TABLES");

my $service_perfdata_file_value                    = undef;
my $service_perfdata_file_mode_value               = undef;
my $service_perfdata_file_processing_command_value = undef;
my $process_service_perfdata_file_data             = undef;
my $delete_process_service_perfdata_file_command   = 0;

$sqlstmt = "select value from setup where name = 'service_perfdata_file'";
($service_perfdata_file_value) = $dbh->selectrow_array($sqlstmt);

$sqlstmt = "select value from setup where name = 'service_perfdata_file_mode'";
($service_perfdata_file_mode_value) = $dbh->selectrow_array($sqlstmt);

$sqlstmt = "select value from setup where name = 'service_perfdata_file_processing_command'";
($service_perfdata_file_processing_command_value) = $dbh->selectrow_array($sqlstmt);

$sqlstmt = "select data from commands where name = 'process_service_perfdata_file'";
($process_service_perfdata_file_data) = $dbh->selectrow_array($sqlstmt);

if (defined($service_perfdata_file_value) and
    defined($service_perfdata_file_mode_value) and
    defined($service_perfdata_file_processing_command_value) and
    defined($process_service_perfdata_file_data) and
    $service_perfdata_file_value                    eq '/usr/local/nagios/eventhandlers/service_perfdata.log' and
    $service_perfdata_file_mode_value               eq 'w' and
    $service_perfdata_file_processing_command_value eq 'process_service_perfdata_file' and
    $process_service_perfdata_file_data             =~ m{/process_service_perf_db_file.pl})
{
    $dbh->do( "update setup set value='/usr/local/nagios/var/service-perfdata.dat' where name = 'service_perfdata_file'" );
    $dbh->do( "update setup set value='a' where name = 'service_perfdata_file_mode'" );
    $dbh->do( "update setup set value='launch_perfdata_process' where name = 'service_perfdata_file_processing_command'" );
    $delete_process_service_perfdata_file_command = 1;
}

foreach my $group_id (@group_id) {
    $sqlstmt = "select value from monarch_group_props where group_id = $group_id and name = 'service_perfdata_file'";
    ($service_perfdata_file_value) = $dbh->selectrow_array($sqlstmt);

    $sqlstmt = "select value from monarch_group_props where group_id = $group_id and name = 'service_perfdata_file_mode'";
    ($service_perfdata_file_mode_value) = $dbh->selectrow_array($sqlstmt);

    $sqlstmt = "select value from monarch_group_props where group_id = $group_id and name = 'service_perfdata_file_processing_command'";
    ($service_perfdata_file_processing_command_value) = $dbh->selectrow_array($sqlstmt);

    if (defined($service_perfdata_file_value) and
	defined($service_perfdata_file_mode_value) and
	defined($service_perfdata_file_processing_command_value) and
	defined($process_service_perfdata_file_data) and
	$service_perfdata_file_value                    eq '/usr/local/nagios/eventhandlers/service_perfdata.log' and
	$service_perfdata_file_mode_value               eq 'w' and
	$service_perfdata_file_processing_command_value eq 'process_service_perfdata_file' and
	$process_service_perfdata_file_data             =~ m{/process_service_perf_db_file.pl})
    {
	$dbh->do( "update monarch_group_props set value='/usr/local/nagios/var/service-perfdata.dat' where group_id = $group_id and name = 'service_perfdata_file'" );
	$dbh->do( "update monarch_group_props set value='a' where group_id = $group_id and name = 'service_perfdata_file_mode'" );
	$dbh->do( "update monarch_group_props set value='launch_perfdata_process' where group_id = $group_id and name = 'service_perfdata_file_processing_command'" );
    }
}

# This action is deferred until last to allow clean re-running of this script in case it somehow
# aborted during the work just above.  I suppose we could accomplish much the same thing if we
# treated these changes as a large transaction that would be rolled back under error conditions.
if ($delete_process_service_perfdata_file_command) {
    $dbh->do( "delete from commands where name = 'process_service_perfdata_file'" );
}

#-----------------------------------------------------------------------------
# Add standard Monarch Groups for support of GDMA (GWMON-8415).
#-----------------------------------------------------------------------------

# This routine creates an index on a single column.  Possibly a future version
# might also allow creating an index that spans multiple columns.  To do that
# not only requires generalizing the arguments passed and the "create index"
# statement, but also how we detect whether the desired index already exists.
# So one cannot use this existing routine for such a purpose by just passing
# a comma-separated list of columns as the $column argument.
sub idempotent_add_index {
    my $qualifier = shift;
    my $table     = shift;
    my $column    = shift;

    my $sth = $dbh->prepare(
	"select INDEX_NAME from information_schema.statistics where "
	  . "table_schema='monarch' and table_name='$table' and column_name='$column';"
    );
    $sth->execute;
    my %indexes = ();
    while ( my @values = $sth->fetchrow_array() ) {
	$indexes{ $values[0] } = 1;
    }
    $sth->finish;

    unless ( $indexes{"$column"} ) {
	# Possibly, creating an index might fail because it imposes a uniqueness constraint
	# and the existing data is not unique.  In that case, we need to catch the error and
	# report it in a form that the user will understand to know how to fix the problem.
	eval {
	    $dbh->do( "create $qualifier index $column on $table ($column)" );
	};
	if ($@) {
	    if ( $@ =~ / Duplicate entry / ) {
		print "\tERROR:  The \"$table\" table contains duplicate values in the \"$column\" column.\n";
	    }
	    die "\tERROR:  creation of index on $table.$column failed:\n\t    $@";
	}
    }
}

# First, we need to idempotently add a unique index on the monarch_groups.name column,
# which will help the Monarch application with automatic sorting for human consumption,
# but most importantly is needed here to allow detection of duplicate rows as we try to
# add them below.  In a future version of this script, adding this index may migrate to
# some place earlier in the script where a bunch more monarch tables will also have new
# indexes added, to properly support various foreign key constraints (references from
# other tables).
#
# Something about adding the index apparently causes it to release an existing table
# lock, so we perform this action outside of the table lock that we impose below for
# adding new data rows to the table.
idempotent_add_index ('unique', 'monarch_groups', 'name');

# idempotent_add of windows-gdma-2.1 and unix-gdma-2.1 to the monarch_groups table
$dbh->do("LOCK TABLES monarch_groups WRITE");

# WARNING:  If you need to edit these lines, watch carefully for the treatment of
# backslash escapes, to make sure you really do get exactly what you want inserted.
# Test like mad.

idempotent_insert ('monarch_groups', 'windows-gdma-2.1',
    "(NULL,'windows-gdma-2.1','Group for configuration of Windows GDMA systems','/usr/local/groundwork/monarch/htdocs/gdma',NULL,'<?xml version=\"1.0\" ?>\n<data>\n <prop name=\"label_enabled\"><![CDATA[]]>\n </prop>\n <prop name=\"label\"><![CDATA[]]>\n </prop>\n <prop name=\"nagios_etc\"><![CDATA[]]>\n </prop>\n <prop name=\"use_hosts\"><![CDATA[]]>\n </prop>\n <prop name=\"inherit_host_active_checks_enabled\"><![CDATA[1]]>\n </prop>\n <prop name=\"inherit_host_passive_checks_enabled\"><![CDATA[1]]>\n </prop>\n <prop name=\"inherit_service_active_checks_enabled\"><![CDATA[1]]>\n </prop>\n <prop name=\"inherit_service_passive_checks_enabled\"><![CDATA[1]]>\n </prop>\n <prop name=\"host_active_checks_enabled\"><![CDATA[-zero-]]>\n </prop>\n <prop name=\"host_passive_checks_enabled\"><![CDATA[-zero-]]>\n </prop>\n <prop name=\"service_active_checks_enabled\"><![CDATA[-zero-]]>\n </prop>\n <prop name=\"service_passive_checks_enabled\"><![CDATA[-zero-]]>\n </prop>\n</data>')" );
idempotent_insert ('monarch_groups', 'unix-gdma-2.1',
    "(NULL,'unix-gdma-2.1','Group for configuration of Linux and Solaris GDMA systems','/usr/local/groundwork/monarch/htdocs/gdma',NULL,'<?xml version=\"1.0\" ?>\n<data>\n <prop name=\"label_enabled\"><![CDATA[]]>\n </prop>\n <prop name=\"label\"><![CDATA[]]>\n </prop>\n <prop name=\"nagios_etc\"><![CDATA[]]>\n </prop>\n <prop name=\"use_hosts\"><![CDATA[]]>\n </prop>\n <prop name=\"inherit_host_active_checks_enabled\"><![CDATA[1]]>\n </prop>\n <prop name=\"inherit_host_passive_checks_enabled\"><![CDATA[1]]>\n </prop>\n <prop name=\"inherit_service_active_checks_enabled\"><![CDATA[1]]>\n </prop>\n <prop name=\"inherit_service_passive_checks_enabled\"><![CDATA[1]]>\n </prop>\n <prop name=\"host_active_checks_enabled\"><![CDATA[-zero-]]>\n </prop>\n <prop name=\"host_passive_checks_enabled\"><![CDATA[-zero-]]>\n </prop>\n <prop name=\"service_active_checks_enabled\"><![CDATA[-zero-]]>\n </prop>\n <prop name=\"service_passive_checks_enabled\"><![CDATA[-zero-]]>\n </prop>\n</data>')" );

$dbh->do("UNLOCK TABLES");

#-----------------------------------------------------------------------------
# GWMON-2118:  Edit the setup for existing Monarch groups to match the new
# construction for specifying whether active and passive checks for hosts
# and services are to be forcibly enabled or disabled by each Monarch group.
#-----------------------------------------------------------------------------

$sqlstmt = "select group_id, name, data from monarch_groups";
$sth     = $dbh->prepare($sqlstmt);
$sth->execute();
while ( my @values = $sth->fetchrow_array() ) {
    my $group_id   = $values[0];
    my $group_name = $values[1];
    my $data       = $values[2];
    ## We need to allow for idempotent conversion without complaint, which accounts for the double test here.
    if ($data =~ /<prop name="checks_enabled">/) {
	if ($data =~ /<prop name="checks_enabled"><!\[CDATA\[([^]]*)\]\]>/) {
	    my $checks_enabled         = $1;
	    my $inherit_checks_enabled = $checks_enabled ? '' : '1';
	    $data =~ s{<prop name="checks_enabled"><!\[CDATA\[$checks_enabled\]\]>}{
		'<prop name="inherit_host_active_checks_enabled"><![CDATA['.$inherit_checks_enabled."]]>\n" .
		" </prop>\n" .
		' <prop name="inherit_host_passive_checks_enabled"><![CDATA['.$inherit_checks_enabled."]]>\n" .
		" </prop>\n" .
		' <prop name="inherit_service_active_checks_enabled"><![CDATA['.$inherit_checks_enabled."]]>\n" .
		" </prop>\n" .
		' <prop name="inherit_service_passive_checks_enabled"><![CDATA['.$inherit_checks_enabled.']]>'
	    }e;
	    if ($data =~ /<prop name="active_checks_enabled"><!\[CDATA\[([^]]*)\]\]>/) {
		my $active_checks_enabled  = $1;
		$data =~ s{<prop name="active_checks_enabled"><!\[CDATA\[$active_checks_enabled\]\]>}{
		    '<prop name="host_active_checks_enabled"><![CDATA['.$active_checks_enabled."]]>\n" .
		    " </prop>\n" .
		    ' <prop name="service_active_checks_enabled"><![CDATA['.$active_checks_enabled.']]>'
		}e;
	    }
	    if ($data =~ /<prop name="passive_checks_enabled"><!\[CDATA\[([^]]*)\]\]>/) {
		my $passive_checks_enabled = $1;
		$data =~ s{<prop name="passive_checks_enabled"><!\[CDATA\[$passive_checks_enabled\]\]>}{
		    '<prop name="host_passive_checks_enabled"><![CDATA['.$passive_checks_enabled."]]>\n" .
		    " </prop>\n" .
		    ' <prop name="service_passive_checks_enabled"><![CDATA['.$passive_checks_enabled.']]>'
		}e;
	    }
	    $sqlstmt = "update monarch_groups set data = ? where group_id = ?";
	    my $sth2 = $dbh->prepare($sqlstmt);
	    $sth2->execute($data, $group_id);
	    $sth2->finish;
	}
	else {
	    print "\n\tWARNING:  The \"active checks enabled\" and \"passive checks enabled\"\n";
	    print "\t          settings of the Monarch group \"$group_name\" could not\n";
	    print "\t          be converted; check and save these settings manually.\n";
	}
    }
}
$sth->finish;

#-----------------------------------------------------------------------------
# GWMON-5006:  Drop support for Nmap Paranoid mode, as it is too slow to be
# of practical use when initiated from the Auto-Discovery user interface.
#-----------------------------------------------------------------------------

$dbh->do( "update discover_method set config = replace(config,'[Paranoid]','[Sneaky]')" );

#-----------------------------------------------------------------------------
# GWMON-9514:  fix the escaping of semicolons in the command-line definitions
# of the host-notify-by-sendemail and service-notify-by-sendemail commands
#-----------------------------------------------------------------------------

# All backslashes are doubled in both the match and replacement strings, because the q{} quoting
# we use here still does recognize and collapse double-backslashes (interpolate "\\" as "\").
my %sendemail_commands = (
    q{host-notify-by-sendemail} =>
	[
	q{/usr/bin/printf "%b" "<html>\\n<table width='auto' style='background-color: #E6DBC3; min-width: 350px;'>\\n<caption style='font-weight: bold; background-color: #B39962;'><b>GroundWork Host<br>$NOTIFICATIONTYPE$ Notification</b></caption>\\n<tr>\\n<td style='background-color: #CCB98F;'>Host:</td>\\n<td><b><a href='http://$USER32$/portal-statusviewer/urlmap?host=$HOSTNAME$'>$HOSTNAME$</a> ($HOSTADDRESS$)</b></td>\\n</tr>\\n<tr>\\n<td style='background-color: #CCB98F;'>Host State:</td>\\n<td style='background-color: #F3EDE1;'><b>$HOSTSTATE$</b></td>\\n</tr>\\n<tr>\\n<td style='background-color: #CCB98F;'>Host Info:</td>\\n<td><b>$HOSTOUTPUT$</b></td>\\n</tr>\\n<tr>\\n<td style='background-color: #CCB98F;'>Time:</td>\\n<td><b>$LONGDATETIME$</b></td>\\n</tr>\\n<tr>\\n<td style='background-color: #CCB98F;'>Host Notes:</td>\\n<td><b>`echo '$HOSTNOTES$' | sed 's/<br>/\\\\n/g'`</b></td>\\n</tr>\\n</table>\\n</html>\\n" | /usr/bin/sendEmail -s $USER13$ -q -f $ADMINEMAIL$ -t $CONTACTEMAIL$ -u "[GW] $NOTIFICATIONTYPE$ alert: $HOSTNAME$ is $HOSTSTATE$"},
	q{/usr/bin/printf "%b" "<html>\\n<table width='auto' style='background-color: #E6DBC3"\\;" min-width: 350px'>\\n<caption style='font-weight: bold"\\;" background-color: #B39962'><b>GroundWork Host<br>$NOTIFICATIONTYPE$ Notification</b></caption>\\n<tr>\\n<td style='background-color: #CCB98F'>Host:</td>\\n<td><b><a href='http://$USER32$/portal-statusviewer/urlmap?host=$HOSTNAME$'>$HOSTNAME$</a> ($HOSTADDRESS$)</b></td>\\n</tr>\\n<tr>\\n<td style='background-color: #CCB98F'>Host State:</td>\\n<td style='background-color: #F3EDE1'><b>$HOSTSTATE$</b></td>\\n</tr>\\n<tr>\\n<td style='background-color: #CCB98F'>Host Info:</td>\\n<td><b>$HOSTOUTPUT$</b></td>\\n</tr>\\n<tr>\\n<td style='background-color: #CCB98F'>Time:</td>\\n<td><b>$LONGDATETIME$</b></td>\\n</tr>\\n<tr>\\n<td style='background-color: #CCB98F'>Host Notes:</td>\\n<td><b>`echo '$HOSTNOTES$' | sed 's/<br>/\\\\n/g'`</b></td>\\n</tr>\\n</table>\\n</html>\\n" | /usr/bin/sendEmail -s $USER13$ -q -f $ADMINEMAIL$ -t $CONTACTEMAIL$ -u "[GW] $NOTIFICATIONTYPE$ alert: $HOSTNAME$ is $HOSTSTATE$"}
	],
    q{service-notify-by-sendemail} =>
	[
	q{/usr/bin/printf "%b" "<html>\\n<table width='auto' style='background-color: #E6DBC3; min-width: 350px;'>\\n<caption style='font-weight: bold; background-color: #B39962;'><b>GroundWork Service<br>$NOTIFICATIONTYPE$ Notification</b></caption>\\n<tr>\\n<td style='background-color: #CCB98F;'>Host:</td>\\n<td><b><a href='http://$USER32$/portal-statusviewer/urlmap?host=$HOSTNAME$'>$HOSTNAME$</a> ($HOSTADDRESS$)</b></td>\\n</tr>\\n<tr>\\n<td style='background-color: #CCB98F;'>Host State:</td>\\n<td><b>$HOSTSTATE$</b></td>\\n</tr>\\n<tr>\\n<td style='background-color: #CCB98F;'>Service:</td>\\n<td><b><a href='http://$USER32$/portal-statusviewer/urlmap?host=$HOSTNAME$&service=$SERVICEDESC$'>$SERVICEDESC$</a></b></td>\\n</tr>\\n<tr>\\n<td style='background-color: #CCB98F;'>Service State:</td>\\n<td style='background-color: #F3EDE1;'><b>$SERVICESTATE$</b></td>\\n</tr>\\n<tr>\\n<td style='background-color: #CCB98F;'>Service Info:</td>\\n<td><b>$SERVICEOUTPUT$</b></td>\\n</tr>\\n<tr>\\n<td style='background-color: #CCB98F;'>Time:</td>\\n<td><b>$LONGDATETIME$</b></td>\\n</tr>\\n<tr>\\n<td style='background-color: #CCB98F;'>Service Notes:</td>\\n<td><b>`echo '$SERVICENOTES$' | sed 's/<br>/\\\\n/g'`</b></td>\\n</tr>\\n</table>\\n</html>\\n" | /usr/bin/sendEmail -s $USER13$ -q -f $ADMINEMAIL$ -t $CONTACTEMAIL$ -u "[GW] $NOTIFICATIONTYPE$ alert: $HOSTNAME$/$SERVICEDESC$ is $SERVICESTATE$"},
	q{/usr/bin/printf "%b" "<html>\\n<table width='auto' style='background-color: #E6DBC3"\\;" min-width: 350px'>\\n<caption style='font-weight: bold"\\;" background-color: #B39962'>GroundWork Service<br>$NOTIFICATIONTYPE$ Notification</caption>\\n<tr>\\n<td style='background-color: #CCB98F'>Host:</td>\\n<td><b><a href='http://$USER32$/portal-statusviewer/urlmap?host=$HOSTNAME$'>$HOSTNAME$</a> ($HOSTADDRESS$)</b></td>\\n</tr>\\n<tr>\\n<td style='background-color: #CCB98F'>Host State:</td>\\n<td><b>$HOSTSTATE$</b></td>\\n</tr>\\n<tr>\\n<td style='background-color: #CCB98F'>Service:</td>\\n<td><b><a href='http://$USER32$/portal-statusviewer/urlmap?host=$HOSTNAME$&service=$SERVICEDESC$'>$SERVICEDESC$</a></b></td>\\n</tr>\\n<tr>\\n<td style='background-color: #CCB98F'>Service State:</td>\\n<td style='background-color: #F3EDE1'><b>$SERVICESTATE$</b></td>\\n</tr>\\n<tr>\\n<td style='background-color: #CCB98F'>Service Info:</td>\\n<td><b>$SERVICEOUTPUT$</b></td>\\n</tr>\\n<tr>\\n<td style='background-color: #CCB98F'>Time:</td>\\n<td><b>$LONGDATETIME$</b></td>\\n</tr>\\n<tr>\\n<td style='background-color: #CCB98F'>Service Notes:</td>\\n<td><b>`echo '$SERVICENOTES$' | sed 's/<br>/\\\\n/g'`</b></td>\\n</tr>\\n</table>\\n</html>\\n" | /usr/bin/sendEmail -s $USER13$ -q -f $ADMINEMAIL$ -t $CONTACTEMAIL$ -u "[GW] $NOTIFICATIONTYPE$ alert: $HOSTNAME$/$SERVICEDESC$ is $SERVICESTATE$"}
	]
);

foreach my $name (keys %sendemail_commands) {
    $sqlstmt = "select command_id, data from commands where name='$name' and type='notify'";
    $sth     = $dbh->prepare($sqlstmt);
    $sth->execute();
    while ( my @values = $sth->fetchrow_array() ) {
	my %command = parse_xml( $values[1] );
	## FIX MAJOR:  Look for $command{'error'} and take evasive action if found.
	# We only patch up an exact match to our original error, to avoid
	# potentially messing up any other customer-specific configuration.
	if ( $command{'command_line'} eq $sendemail_commands{$name}[0] ) {
	    my $data = qq(<?xml version="1.0" ?>
<data>
 <prop name="command_line"><![CDATA[$sendemail_commands{$name}[1]]]>
 </prop>
</data>);
	    $data = $dbh->quote($data);
	    $dbh->do( "update commands set data = $data where command_id = '$values[0]'" );
	}
    }
    $sth->finish;
}

#-----------------------------------------------------------------------------
# GWMON-9506:  change configured cgi.cfg values for Nagios CGI access under
# the revised access controls used in GWMEE 6.4
#-----------------------------------------------------------------------------

# If we haven't previously upgraded the schema to one that includes this change,
# make the modification now.  If we have, just skip it, since we don't want to
# risk undoing any change which was later made manually.
my $base_old_monarch_version = abs($old_monarch_version);
if ( $base_old_monarch_version < 3.5 ) {
    my @nagiosadmin_fields = (
	'authorized_for_all_host_commands',
	'authorized_for_all_hosts',
	'authorized_for_all_service_commands',
	'authorized_for_all_services',
	'authorized_for_configuration_information',
	'authorized_for_system_commands',
	'authorized_for_system_information',
	'default_user_name'
    );

    # Convert the (parent) server's own configuration.
    foreach my $name (@nagiosadmin_fields) {
	my $sth = $dbh->prepare(
	    "select value from setup where name='$name' and type='nagios_cgi' and value like '%nagiosadmin%'"
	);
	$sth->execute;
	while ( my @values = $sth->fetchrow_array() ) {
	    my @users = split( /[ ,]+/, $values[0] );
	    my $changed = 0;
	    foreach (@users) {
		if ( $_ eq 'nagiosadmin' ) {
		    $_       = 'admin';
		    $changed = 1;
		}
	    }
	    if ($changed) {
		$dbh->do( "update setup set value='" . join( ',', @users ) . "' where name='$name' and type='nagios_cgi'" );
	    }
	}
	$sth->finish;
    }

    # Convert the configurations for any child servers.  This is done under the presumption (and general
    # recommendation) that child servers are always upgraded to the current release before their parent
    # server, so while changing their configuration now might be a little late, it will definitely
    # correct the configuration rather than damage anything.
    foreach my $name (@nagiosadmin_fields) {
	my $sth = $dbh->prepare(
	    "select value, group_id from monarch_group_props where name='$name' and type='nagios_cgi' and value like '%nagiosadmin%'"
	);
	$sth->execute;
	while ( my @values = $sth->fetchrow_array() ) {
	    my $group_id = $values[1];
	    my @users    = split( /[ ,]+/, $values[0] );
	    my $changed  = 0;
	    foreach (@users) {
		if ( $_ eq 'nagiosadmin' ) {
		    $_       = 'admin';
		    $changed = 1;
		}
	    }
	    if ($changed) {
		$dbh->do( "update monarch_group_props set value='"
		  . join( ',', @users )
		  . "' where group_id='$group_id' and name='$name' and type='nagios_cgi'" );
	    }
	}
	$sth->finish;
    }
}

#-----------------------------------------------------------------------------
# GWMON-9645:  Minor tweaks to Linux GDMA perf config.  The graph should
# be set up to show that the check is critical when the value drops below
# the critical threshold, not above it.  Ditto for the warning.
#-----------------------------------------------------------------------------

$dbh->do( 'update performanceconfig set graphcgi = replace(graphcgi,
    "CDEF:cdefws=a,cdefw,GT,a,0,IF AREA:cdefws#FFFF00 CDEF:cdefcs=a,cdefc,GT,a,0,IF AREA:cdefcs#FF0033",
    "CDEF:cdefws=a,cdefw,LT,a,0,IF AREA:cdefws#FFFF00 CDEF:cdefcs=a,cdefc,LT,a,0,IF AREA:cdefcs#FF0033"
) where service="gdma_21_linux_mem"' );

#-----------------------------------------------------------------------------
# GWMON-9642:  Add the -p option to a check_cacti.pl invocation as a command
# (which would be used in a plugin context).
#-----------------------------------------------------------------------------

# For complete safety, we make this replacement for any occurrence of the problem,
# even though we only expect it to be present for the "check_cacti" command.
$dbh->do( 'update commands set data = replace(data,"<![CDATA[$USER1$/check_cacti.pl]]>","<![CDATA[$USER1$/check_cacti.pl -p]]>")' );

#-----------------------------------------------------------------------------
# Some table content changes not converted during migration
#-----------------------------------------------------------------------------

# Certain changes to initial values and such are being made to the base product,
# but will not be correspondingly modified during an upgrade so as not to potentially
# upset a working configuration.  For reference, we list here the ones we know about.

# GWMON-1904
# setup table:  command_check_interval changed from 1 to -1
# setup table:  max_concurrent_checks  changed from 0 to 100

# GWMON-6632
# service_templates table:  generic-service has the parallelize_check option dropped
# This and similar changes to customer setup in the service_overrides, service_templates,
# servicename_overrides, and services tables will be ignored during a migration, as the
# continued presence of the parallelize_check option is benign (such settings will not
# appear in the UI, and they wll be henceforth ignored when generating Nagios files).
# Editing and saving a given object in the UI will cause this option to disappear.

##############################################################################
# Migrate Nagios time periods version 2 to 3
##############################################################################

# Add time_period_exclude and time_period_property tables.

unless ( $tables{'time_period_exclude'} ) {
    $dbh->do(
	"CREATE TABLE time_period_exclude (timeperiod_id SMALLINT(4) UNSIGNED,
	    exclude_id SMALLINT(4) UNSIGNED,
	    PRIMARY KEY (timeperiod_id,exclude_id),
	    FOREIGN KEY (timeperiod_id) REFERENCES time_periods(timeperiod_id) ON DELETE CASCADE,
	    FOREIGN KEY (exclude_id) REFERENCES time_periods(timeperiod_id) ON DELETE CASCADE) TYPE=INNODB"
    );
}

unless ( $tables{'time_period_property'} ) {
    $dbh->do(
	"CREATE TABLE time_period_property (timeperiod_id SMALLINT(4) UNSIGNED,
	    name VARCHAR(255),
	    type VARCHAR(255),
	    value VARCHAR(255),
	    comment VARCHAR(255),
	    PRIMARY KEY (timeperiod_id,name),
	    FOREIGN KEY (timeperiod_id) REFERENCES time_periods(timeperiod_id) ON DELETE CASCADE) TYPE=INNODB"
    );
}

# Convert existing data and drop the "data" column from the time_periods table.

$sth = $dbh->prepare('describe time_periods');
$sth->execute();
%fields = ();
while ( my @values = $sth->fetchrow_array() ) {
    $fields{ $values[0] } = 1;
}
$sth->finish;
if ( defined $fields{'data'} ) {

    # We truncate these tables because they might still include info from the original product installation,
    # even though the time_periods table has since been deleted, re-created, and populated with old customer
    # data.  If we just created these tables above, truncation will have no effect.  If not, this cleanup is
    # necessary to keep all the tables consistent, since the fact that the time_periods.data column still
    # exists says the data in time_periods has not yet been migrated.
    $dbh->do( 'truncate time_period_exclude' );
    $dbh->do( 'truncate time_period_property' );

    $sth = $dbh->prepare('select * from time_periods');
    $sth->execute();
    while ( my @values = $sth->fetchrow_array() ) {
	my %wd_values = parse_xml($values[3]);
	## FIX MAJOR:  Look for $wd_values{'error'} and take evasive action if found.
	foreach my $wd (keys %wd_values) {
	    my $nstr = $dbh->quote($wd);
	    my $vstr = $dbh->quote($wd_values{$wd});
	    $dbh->do("insert into time_period_property values($values[0],$nstr,'weekday',$vstr,'')");
	}
    }
    # drop data column as it's no longer needed
    $dbh->do('alter table time_periods drop column data');
}

# Clean up some historical mess.

$dbh->do("update time_periods set comment = 'All day, every day.' where name = '24x7' and comment regexp '^#+\\n*\$'");
$dbh->do("update time_periods set comment = substr(comment,3) where comment regexp '^# '");
$dbh->do("update time_periods set comment = trim(trim('\\n' from comment))");
$dbh->do("update time_periods set comment = trim(trim('\\n' from comment))");

##############################################################################
# Committing Changes
##############################################################################

# After everything else is done, update our proxy flag for all the other changes made above.
$dbh->do( "update setup set value = '$monarch_version' where name = 'monarch_version' and type = 'config'" );

# Commit all previous changes.  Note that some earlier commands may have performed
# implicit commit operations, which is why the very first change we made above was
# to modify the Monarch version number at the start of the script to something that
# would show that we were only partially done migrating the database schema and content.
# There is not much of anything we can do about those implicit commits; there is no
# good way to roll back automatically if some part of the operations that perform
# such implicit commits should fail.  If we find a negative Monarch version number
# after running this script, we know the migration is not completely done.
my $rc = $dbh->commit();

##############################################################################
# Done.
##############################################################################

$all_is_done = 1;

END {
    if ($dbh) {
	# Roll back any uncommitted transaction.  If the $dbh->commit() above
	# did not execute, this will leave the Monarch version in a state where
	# we can later see that the full migration did not complete.
	eval {
	    my $rc = $dbh->rollback();
	};
	if ($@) {
	    print "\n\tError:  rollback failed: ", $dbh->errstr, "\n";
	}
	$dbh->disconnect();
    }
    if (!$all_is_done) {
	print "\n";
	print "\t====================================================================\n";
	print "\t    WARNING:  monarch database migration did not fully complete!\n";
	print "\t====================================================================\n";
	print "\n";
	exit 1;
    }
}

print "\n\tUpdate complete.\n\n";

