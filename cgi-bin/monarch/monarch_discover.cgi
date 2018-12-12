#!/usr/local/groundwork/perl/bin/perl --
# MonArch - Groundwork Monitor Architect
# monarch_discover.cgi
#
############################################################################
# Release 4.5
# November 2016
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
use Nmap::Scanner;
use MonarchAutoConfig;
use XML::LibXML;
use Socket;
use POSIX qw(:signal_h);

my $debug        = 0;
my $monarch_home = undef;

my $timeout_context             = '';
my $timeout_max_seconds         = 0;
my $timeout_seconds             = 0;
my $timeout_start_time          = 0;
my $default_timeout_max_seconds = 900;
my $default_timeout_seconds     = 120;

sub timeout_alarm {
    my $now = time;
    if ($now - $timeout_start_time >= $timeout_max_seconds) {
	print STDERR "timing out $timeout_context\n";
	die "time limit reached for $timeout_context\n";
    }
    else {
	# Keep Apache happy so it doesn't time out the execution of this script (us, not our descendants).
	print STDERR "continuing $timeout_context\n";
	alarm($timeout_seconds);
    }
}

sub run_program {
    my $program          = shift;
    $timeout_context     = shift;
    $timeout_max_seconds = shift;
    $timeout_seconds     = shift;
    $timeout_start_time  = time;
    my @output = ();
    my $error  = undef;
    # We need to guarantee no intermediate shell is used, so our direct
    # descendant is the process that establishes the process group.
    my @program = split(' ', $program);

    my $oldblockset = POSIX::SigSet->new;
    my $newblockset = POSIX::SigSet->new(SIGCHLD);
    if (not sigprocmask(SIG_BLOCK, $newblockset, $oldblockset)) {
	$error = "Could not block SIGCHLD ($!)";
    }
    else {
	my $kid = open(PROGRAM, '-|', @program);
	if ($kid) {
	    print STDERR "initiating $timeout_context\n";
	    eval {
		local $SIG{ALRM} = \&timeout_alarm;
		eval {
		    alarm($timeout_seconds);
		    @output = <PROGRAM>;
		};
		alarm(0);
		die( $@ =~ /\n$/ ? $@ : "$@\n" ) if $@;
	    };
	    if ($@ && $@ =~ /^time limit reached/) {
		# We must kill our immediate child process and any of its descendants that might be writing to
		# the same output stream, so the close of our PROGRAM filehandle will not wait nearly forever
		# for such processes to exit.  We send a signal to the child process' process group, given
		# that we have the child set up to become its own process group leader.  But remember that our
		# direct child runs as a setuid-root program, so we won't have permission to send most signals
		# to it directly.  SIGCONT is the exception, so we (ab)use that, sending it instead of SIGTERM.
		# The child is equipped to transform the SIGCONT signal into a SIGTERM sent to its own process
		# group, to halt the rest of the descendant processes.
		kill 'CONT', $kid;      # in case it isn't a process group leader yet
		kill 'CONT', 0 - $kid;  # in case it is, and has live descendants (wake them up so they can die)

		# child wait status will be non-zero if it was killed, so just skip that
		$error = (!close(PROGRAM) && $!) ? "Could not run $program ($!)" : $@;
	    }
	    else {
		$error = close(PROGRAM) ? $@ : $! ? "Could not run $program ($!)" : "$program returned wait status $?";
	    }
	    print STDERR "saw end of $timeout_context\n";
	}
	else {
	    $error = "Could not run $program ($!)";
	}
	if (not sigprocmask(SIG_SETMASK, $oldblockset)) {
	    $error = "Could not restore SIGCHLD signal ($!)";
	}
    }

    return join('', @output), $error;
}

sub process_nmap($) {
    my $data   = $_[0];
    my %hosts  = ();
    my @errors = ();
    if ($data) {
	my $parser = XML::LibXML->new(
	    ext_ent_handler => sub { die "INVALID FORMAT: external entity references are not allowed in NMAP output.\n" },
	    no_network      => 1
	);
	my $tree = undef;
	eval {
	    $tree = $parser->parse_string($data);
	};
	if ($@) {
	    my ($package, $file, $line) = caller;
	    print STDERR $@, " called from $file line $line.";
	    ## FIX LATER:  HTMLifying here, along with embedded markup in @errors, is something of a hack,
	    ## as it presumes a context not in evidence.  But it's necessary in the browser context.
	    $@ = HTML::Entities::encode($@);
	    $@ =~ s/\n/<br>/g;
	    if ($@ =~ s/external entity callback died: // || $@ =~ /external entity references are not allowed/) {
		## First undo the effect of the croak() call in XML::LibXML.
		$@ =~ s/ at \S+ line \d+<br>//;
		push @errors, "Bad XML string (process_nmap):<br>$@";
	    }
	    elsif ($@ =~ /Attempt to load network entity/) {
		push @errors, "Bad XML string (process_nmap):<br>INVALID FORMAT: non-local entity references are not allowed in NMAP output.<pre>$@</pre>";
	    }
	    else {
		push @errors, "Bad XML string (process_nmap):<br>$@ called from $file line $line.";
	    }
	}
	else {
	    my $root     = $tree->getDocumentElement;
	    my @nodes    = $root->findnodes("//host");
	    my $host_key = 1;
	    foreach my $node (@nodes) {
		my %ports = ();
		my ( $os, $address, $hostname, $description, $status ) = undef;
		my @siblings = $node->getChildnodes();
		foreach my $sibling (@siblings) {
		    if ( $sibling->nodeName() eq 'hostnames' ) {
			if ( $sibling->hasChildNodes() ) {
			    my @hostnames = $sibling->getChildnodes();
			    foreach my $hname (@hostnames) {
				if ( $hname->nodeName() eq 'hostname' && $hname->hasAttributes() ) {
				    $hostname = $hname->getAttribute('name');
				}
			    }
			}
		    }
		    elsif ( $sibling->nodeName() eq 'address' ) {
			if ( $sibling->hasAttributes() ) {
			    my $addrtype = $sibling->getAttribute('addrtype');
			    if ( $addrtype =~ /ip/i ) {
				$address = $sibling->getAttribute('addr');
			    }
			}
		    }
		    elsif ( $sibling->nodeName() eq 'status' ) {
			if ( $sibling->hasAttributes() ) {
			    $status = $sibling->getAttribute('state');
			}
		    }
		    elsif ( $sibling->nodeName() eq 'os' ) {
			my @children = $sibling->getChildnodes();
			foreach my $child (@children) {
			    if ( $child->nodeName() eq 'osmatch' && $child->hasAttributes() ) {
				$description = $child->getAttribute('name');
				## There may be multiple osmatch elements, but nmap apparently always
				## returns the highest-accuracy match first.  So we quit while we're
				## ahead, without examining later matches and comparing their accuracy.
				last if $description;
			    }
			}
		    }
		    elsif ( $sibling->nodeName() eq 'ports' && $sibling->hasChildNodes() ) {
			my @children = $sibling->getChildnodes();
			foreach my $child (@children) {
			    my ( $port, $service, $state ) = undef;
			    if ( $child->nodeName() eq 'port' && $child->hasAttributes() && $child->hasChildNodes() ) {
				$port = $child->getAttribute('portid');
				my @g_children = $child->getChildnodes();
				foreach my $g_child (@g_children) {
				    if ( $g_child->nodeName() eq 'state' && $g_child->hasAttributes() ) {
					$state = $g_child->getAttribute('state');
				    }
				    if ( $g_child->nodeName() eq 'service' && $g_child->hasAttributes() ) {
					$service = $g_child->getAttribute('name');
				    }
				}
				if ( $state =~ /open/ && $service ) { $ports{$port} = $service }
			    }
			}
		    }
		}
		%{ $hosts{$host_key}{'ports'} } = %ports;
		unless ($description) { $description = "no_os_match" }
		unless ( $hosts{$host_key}{'description'} ) { $hosts{$host_key}{'description'} = $description }
		my @host_names = split( /\./, $hostname );
		my $short_name = $host_names[0];
		if ($hostname =~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)(\..+)?$/ && $1 <= 255 && $2 <= 255 && $3 <= 255 && $4 <= 255) {
		    $short_name = "$1.$2.$3.$4";
		}
		$hosts{$host_key}{'name'} = $short_name;
		unless ( $hosts{$host_key}{'name'} )  { $hosts{$host_key}{'name'}  = $hostname }
		unless ( $hosts{$host_key}{'alias'} ) { $hosts{$host_key}{'alias'} = $hostname }
		$hosts{$host_key}{'address'} = $address;
		$hosts{$host_key}{'status'}  = $status;
		unless ( $hosts{$host_key}{'alias'} ) { $hosts{$host_key}{'alias'} = $address }
		unless ( $hosts{$host_key}{'name'} )  { $hosts{$host_key}{'name'}  = $address }
		$host_key++;
	    }
	}
    }
    return \@errors, %hosts;
}

sub port_definitions($) {
    my $portdefs         = shift;
    my @port_defs        = split( /:-:/, $portdefs );
    my %port_definitions = ();
    foreach my $port_def (@port_defs) {
	$port_def =~ s/port_def_\d+_//;
	my @def_value = split( /=/, $port_def );
	$port_definitions{$port_def}{'value'} = $def_value[1];
	if ( $def_value[0] =~ /,/ ) {
	    my @ports = split( /,/, $def_value[0] );
	    foreach my $p (@ports) {
		if ( $p =~ /(\d+)-(\d+)/ ) {
		    for ( my $i = $1 ; $i <= $2 ; $i++ ) {
			$port_definitions{$port_def}{'ports'}{$i} = 1;
		    }
		}
		else {
		    $port_definitions{$port_def}{'ports'}{$p} = 1;
		}
	    }
	}
	elsif ( $def_value[0] =~ /(\d+)-(\d+)/ ) {
	    for ( my $i = $1 ; $i <= $2 ; $i++ ) {
		$port_definitions{$port_def}{'ports'}{$i} = 1;
	    }
	}
	else {
	    $port_definitions{$port_def}{'ports'}{ $def_value[0] } = 1;
	}
    }
    return %port_definitions;
}

sub run_script(@) {
    my $ip     = shift;
    my $script = shift;
    $script =~ s/(?<!\\)\+/ /g;
    $script =~ s/\\\+/+/g;
    $script =~ s/\$HOST\$/$ip/g;
    my $errstr           = undef;
    my $out_lines        = '';
    my $part_return_info = undef;
    my $dt               = AutoConfig->datetime();
    my $lines            = qx($script 2>&1) or $errstr = "Error executing $script ($!)";
    print DEBUG "\n-script $script" if $debug;

    if ($errstr) {
	$part_return_info = "$dt|$ip|$errstr";
    }
    else {
	my @lines = split (/\n/, $lines);
	foreach my $line (@lines) {
	    print DEBUG "\n-line $line-\n" if $debug;
	    chomp $line;
	    if ( $line =~ /^#(.*)/ ) {
		$part_return_info = "$dt|$ip|$1";
	    }
	    else {
		$out_lines .= "$line\n";
	    }
	}
    }
    unless ($part_return_info) { $part_return_info = "$dt|$ip|-----" }
    return $out_lines, $part_return_info;
}

sub get_parent(@) {
    my $command    = shift;
    my $host       = shift;
    my @traceroute = qx($command $host 2>&1);
    my $host_line  = pop(@traceroute);
    my $parent     = pop(@traceroute);
    if ( defined($parent) ) {
	if ( $parent =~ /^traceroute to/i ) {
	    $parent = undef;
	}
	elsif ( $parent =~ /\((\d+\.\d+\.\d+\.\d+)\)/i ) {
	    $parent = $1;
	}
	else {
	    $parent = undef;
	}
    }
    return $parent;
}

sub get_snmp(@) {
    my $ip                   = shift;
    my $snmp_ver             = shift;
    my $community            = shift;
    my $snmp_v3_command_opts = shift;
    my $parent               = shift;
    my $command              = '/usr/local/groundwork/common/bin/snmpwalk';
    my $errstr               = undef;
    my %ifDescr              = ();
    my %ifIndex              = ();
    my %ifSpeed              = ();
    my %ifAdminStatus        = ();
    my $results              = undef;
    my $dt                   = AutoConfig->datetime();
    my $out_lines            = '';
    my $part_return_info     = undef;
    my $useful_cstring       = '';

    if ( $snmp_ver eq '3' ) {
	$results = qx($command -v 3 -On $snmp_v3_command_opts $ip .1.3.6.1.2.1.2.2.1 2>&1)
	  or $errstr = "Error(s) executing $command -v 3 -On $snmp_v3_command_opts $ip .1.3.6.1.2.1.2.2.1 2>&1 ($!)";
    }
    else {
	my $got_cstring = 0;
	# FIX LATER:  Generalize this to break apart the incoming data into individual community strings.
	# The trick is to construct the array carefully; just split()ting on a particular separator character
	# is not good enough, as we need to allow the separator itself to be escaped and included in a cstring.
	# my @community = split (/,/, $community);
	my @community = ( $community );
	foreach my $cstring (@community) {
	    if ($cstring eq '') {
		next;
	    }
	    $got_cstring = 1;
	    $cstring =~ s/'/'"'"'/g;
	    $results = qx($command -v $snmp_ver -On -c '$cstring' $ip .1.3.6.1.2.1.2.2.1 2>&1)
	      or $errstr = "Error(s) executing $command -v $snmp_ver -c '$cstring' $ip ($!)";
	    if ($errstr) {
		last;
	    }
	    if ( $results !~ /Timeout: No Response from $ip/i ) {
		$useful_cstring = $cstring;
		last;
	    }
	}
	unless ($got_cstring) {
	    $errstr = 'No community strings are provided in this discovery definition.';
	}
    }
    if ($errstr) {
	$part_return_info = "$dt|$ip|$errstr";
    }
    unless ($part_return_info) {
	my @lines = split( /\n/, $results );
	foreach my $line (@lines) {
	    chomp $line;
	    if ( $line =~ /Timeout: No Response from $ip/i ) {
		$part_return_info = "$dt|$ip|No response";
		last;
	    }

	    #.1.3.6.1.2.1.2.2.1.1.1
	    #if ($line =~ /ifIndex\.(\d+) = INTEGER:\s+(\d+)/i) { # ... }
	    if ( $line =~ /.1.3.6.1.2.1.2.2.1.1.(\d+) = INTEGER:\s+(\d+)/i ) {
		$ifIndex{$1} = $2;
	    }

	    #if ($line =~ /ifDescr\.(\d+) = STRING:\s+(\S+)/i) { # ... }
	    if ( $line =~ /.1.3.6.1.2.1.2.2.1.2.(\d+) = STRING:\s+(\S+)/i ) {
		$ifDescr{$1} = $2;
	    }

	    #if ($line =~ /ifSpeed\.(\d+) = Gauge32:\s+(\d+)/i) { # ... }
	    if ( $line =~ /.1.3.6.1.2.1.2.2.1.5.(\d+) = Gauge32:\s+(\d+)/i ) {
		$ifSpeed{$1} = $2;
	    }

	    # ifAdminStatus .1.3.6.1.2.1.2.2.1.7.1 = INTEGER: up(1)
	    if ( $line =~ /.1.3.6.1.2.1.2.2.1.7.(\d+) = INTEGER: up\((\d+)\)/i ) {
		$ifAdminStatus{$1} = $2;
	    }
	}
    }
    unless ($part_return_info) {
	my $line;
	my $getcommand = '/usr/local/groundwork/common/bin/snmpget';

	# If we have a config file of OID match strings, read it into a hash.
	my %singleoid = ();
	if ( open( SINGLEOIDS, '<', "$monarch_home/automation/conf/snmp_scan_input.cfg" ) ) {
	    my @oids = <SINGLEOIDS>;
	    close SINGLEOIDS;
	    for ( my $i = 0 ; $i < @oids ; $i++ ) {
		my @oidsplit = split( "=", $oids[$i] );
		$singleoid{ $oidsplit[0] } = $oidsplit[1];
	    }
	}

	# Look in optional conf file hash for more OIDs to match
	my $j = 0;
	my @oidsout;
	my @valsout;
	while ( my ( $oid_number, $oid_symbol ) = each(%singleoid) ) {
	    if ( $snmp_ver eq '3' ) {
		$line = `$getcommand -v 3 -On $snmp_v3_command_opts $ip $oid_number 2>&1`;
	    }
	    else {
		$line = `$getcommand -v $snmp_ver -On -c '$useful_cstring' $ip $oid_number 2>&1`;
	    }
	    if ( $line =~ /$oid_number/i && $line !~ /(?:Unknown Object Identifier|No Such Object|Failed object)/i ) {
		my @vals = split( /: /, $line );
		chomp $vals[1];
		$valsout[$j] = $vals[1];
		chomp $oid_symbol;
		$oidsout[$j] = $oid_symbol;
		$j++;
	    }
	}

	# Get the system type for parsing in the schema
	if ( $snmp_ver eq '3' ) {
	    $line = `$getcommand -v 3 -On $snmp_v3_command_opts $ip 1.3.6.1.2.1.1.2.0 2>&1`;
	}
	else {
	    $line = `$getcommand -v $snmp_ver -On -c '$useful_cstring' $ip 1.3.6.1.2.1.1.2.0 2>&1`;
	}

	my $systype = '';
	if ( $line =~ /1.3.6.1.2.1.1.2.0 = OID:\s+(.*)/i ) {
	    $systype = $1;
	}

	# GWMON-4829:  The DNS hostname is considered more reliable than the SNMP hostname.
	# And if we cannot get it from DNS, we use the IP address as the hostname, as our
	# NMAP TCP method does.
	my $host_name = lc( gethostbyaddr(inet_aton($ip), AF_INET) ) || $ip;
	## Obsolete code:  fall back to using whatever SNMP returns.
	unless ($host_name) {
	    ## Get the hostname with snmpget (faster than a full walk).
	    if ( $snmp_ver eq '3' ) {
		$line = `$getcommand -v 3 -On $snmp_v3_command_opts $ip .1.3.6.1.2.1.1.5.0 2>&1`;
	    }
	    else {
		$line = `$getcommand -v $snmp_ver -On -c '$useful_cstring' $ip .1.3.6.1.2.1.1.5.0 2>&1`;
	    }
	    if ( $line =~ /.1.3.6.1.2.1.1.5.0 = STRING:\s+(.*)/i ) {
		$host_name = lc($1);
	    }
	}

	# Set up the output
	my @host_names = split( /\./, $host_name );
	my $short_name = $host_names[0];
	if ($host_name =~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)(\..+)?$/ && $1 <= 255 && $2 <= 255 && $3 <= 255 && $4 <= 255) {
	    $short_name = "$1.$2.$3.$4";
	}
	$out_lines .= "$short_name;;$host_name;;$ip;;;;$parent\n";
	my $csv_prefix = ';;;;;;;;;;;;;;';
	foreach my $index ( sort keys %ifIndex ) {
	    my $csv_suffix =
"_$ifIndex{$index}::$ifIndex{$index}::ifDescr($ifDescr{$index})-ifSpeed($ifSpeed{$index})-ifAdminStatus($ifAdminStatus{$index})\n";
	    $out_lines .= $csv_prefix . 'snmp_if::::' . $csv_suffix;
	    $out_lines .= $csv_prefix . 'snmp_ifbandwidth::::' . $csv_suffix;
	    $out_lines .= $csv_prefix . 'snmp_ifoperstatus::::' . $csv_suffix;
	}
	for ( my $i = 0 ; $i < @oidsout ; $i++ ) {
	    ## location is a currently unimplemented service; we would want to pick up
	    ## the data recorded in the device and use that as the command argument.
	    ## For all other services, we will pick up the command arguments from the
	    ## existing Monarch setup, not from probing the device.
	    if ($oidsout[$i] eq 'location') {
		$out_lines .= $csv_prefix . "$oidsout[$i]::$valsout[$i]::::::$systype\n";
	    }
	    else {
		$out_lines .= $csv_prefix . "$oidsout[$i]::::::::$systype\n";
	    }
	}
	$part_return_info = "$dt|$ip|$short_name";
    }
    return $out_lines, $part_return_info;
}

sub url_decode {
    my $text = shift;
    $text =~ tr/ /+/;
    $text =~ s{%([a-f0-9][a-f0-9])}{chr(hex($1))}eig;
    return $text;
}

sub http_timestamp {
    my ( $sec, $min, $hour, $mday, $mon, $year, $wday ) = gmtime;
    my $month    = (qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec))[$mon];
    my $weekday  = (qw(Sun Mon Tue Wed Thu Fri Sat))[$wday];
    return sprintf ("%s, %02d %s %04d %02d:%02d:%02d GMT", $weekday, $mday, $month, $year + 1900, $hour, $min, $sec);
}

sub get_hosts {
    my $now   = http_timestamp();
    my $query = new CGI();

    # Adapt to an upgraded CGI package while still maintaining backward compatibility.
    my $multi_param = $query->can('multi_param') ? 'multi_param' : 'param';

    my $dt    = AutoConfig->datetime();
    my @input = $query->$multi_param('args');
    for ( my $i = 0 ; $i < scalar @input ; $i++ ) {
	unless ( $input[$i] =~ m{/traceroute} ) {
	    $input[$i] = url_decode( $input[$i] );
	}
    }
    $monarch_home = $input[3];
    if ( -e "$input[3]/automation/data/$input[2]" ) {
	if ($debug) {
	    open( DEBUG, '>>', '/tmp/auto-discover-debug.txt' );
	    print DEBUG "$dt\n input[0] $input[0] input[1] $input[1]\nfile $input[2] monarch home $input[3]\n";
	    print DEBUG "$dt\n input[4] $input[4] input[5] $input[5]\n";
	}

	my $ret_info      = '';
	my $part_ret_info = '';
	if ( $input[1] eq 'backup' ) {
	    my $connect         = AutoConfig->dbconnect();
	    my %config_settings = AutoConfig->config_settings();
	    my %file_ref        = ();
	    $file_ref{'user_acct'} = $input[4];    # user name in file headers

	    ## FIX MINOR:  It probably doesn't make sense to attempt to draw the annotation and lock from query parameters here.
	    my $annotation = $query->param('annotation');
	    my $lock       = $query->param('lock');
	    $annotation = "Backup auto-created during an Auto-Discovery by user \"$file_ref{user_acct}\"." if not $annotation;
	    $annotation =~ s/\r//g;
	    $annotation =~ s/^\s+|\s+$//g;
	    $annotation .= "\n";

	    my ( $backup_msg, $errs ) = AutoConfig->backup( \%config_settings, $file_ref{'user_acct'}, $annotation, $lock );
	    my @errors = @{$errs};
	    if (@errors) {
		foreach my $err (@errors) {
		    ## print DEBUG "\n--------error------$err----------\n" if $debug;
		    $ret_info .= "error|$dt|$err\::";
		}
		$ret_info .= "aborted|$dt|Backup Failed!";
	    }
	    else {
		$ret_info .= "backup_results|$dt|backup|Backup written to: $backup_msg.\::";
		$ret_info .= "backup_results|$dt|backup|Backup successfully completed.";
	    }
	    my $result = AutoConfig->dbdisconnect();
	}
	elsif ( $input[1] eq 'import_hosts' ) {
	    ## print DEBUG "\n------import_hosts-------\n" if $debug;

	    ######################################################
	    # Inputs
	    ######################################################
	    # import_hosts, import_schema, 'file', 'monarch_home'
	    ######################################################
	    my $connect = AutoConfig->dbconnect();
	    my ( $import_data, $schema, $errs ) = AutoConfig->advanced_import( $input[4], $input[2], '', $input[3] );
	    my %schema      = %{$schema};
	    my %import_data = %{$import_data};
	    my @errors      = @{$errs};
	    if (@errors) {
		## print DEBUG "\n----import_hosts---errors-------$errors[0]-----------\n" if $debug;
		foreach my $err (@errors) {
		    $ret_info .= "error|$dt|$err\::";
		    print DEBUG "\nerror import_hosts $err" if $debug;
		}
	    }
	    my %results = AutoConfig->process_import_data( \%import_data );
	    my $result  = AutoConfig->dbdisconnect();
	    foreach my $record ( sort keys %{ $results{'errors'} } ) {
		print DEBUG "\nerror\trecord $record\t$results{'errors'}{$record}" if $debug;
		$ret_info .= "import_results|$dt|error|$record $results{'errors'}{$record}\::";
	    }
	    my $messages        = undef;
	    my $hosts_exception = keys %{ $results{'exception'} };
	    foreach my $record ( sort keys %{ $results{'exception'} } ) {
		print DEBUG "\nexception\trecord $record\t$results{'exception'}{$record}" if $debug;
		$messages .= "import_results|$dt|exception|record $record did not meet the requirements (name,address,alias) to import.\::";
	    }
	    if ( $hosts_exception > 100 ) {
		$ret_info .=
"import_results|$dt|exception|$hosts_exception records skipped because they did not meet the requirements (name,address,alias) to import.\::";
	    }
	    else {
		$ret_info .= $messages;
	    }
	    $messages = undef;
	    my $hosts_deleted = keys %{ $results{'deleted'} };
	    foreach my $host ( sort keys %{ $results{'deleted'} } ) {
		print DEBUG "\ndeleted\t$host\t$results{'deleted'}{$host}" if $debug;
		$messages .= "import_results|$dt|deleted|host $host deleted per type host-profile-sync.\::";
	    }
	    if ( $hosts_exception > 100 ) {
		$ret_info .= "import_results|$dt|deleted|$hosts_deleted hosts deleted per type host-profile-sync.\::";
	    }
	    else {
		$ret_info .= $messages;
	    }
	    $messages = undef;
	    my $hosts_updated = keys %{ $results{'updated'} };
	    foreach my $host ( sort keys %{ $results{'updated'} } ) {
		print DEBUG "\nupdated\trecord $host\t$results{'updated'}{$host}" if $debug;
		$messages .= "import_results|$dt|updated|host $host\::";
	    }
	    if ( $hosts_updated > 100 ) {
		$ret_info .= "import_results|$dt|updated|$hosts_updated hosts updated.\::";
	    }
	    else {
		$ret_info .= $messages;
	    }
	    $messages = undef;
	    my $hosts_added = keys %{ $results{'added'} };
	    foreach my $host ( sort keys %{ $results{'added'} } ) {
		print DEBUG "\nadded\t$host\t$results{'added'}{$host}" if $debug;
		$ret_info .= "import_results|$dt|processed|host $host\::";
	    }
	    if ( $hosts_added > 100 ) {
		$ret_info .= "import_results|$dt|imported|$hosts_added hosts processed.\::";
	    }
	    else {
		$ret_info .= $messages;
	    }
	    print DEBUG "\nret_info $ret_info" if $debug;
	    $ret_info .= "import_results|$dt|complete|Record processing completed.";
	    if ( $input[0] eq 'Auto' ) {
		unlink("$input[3]/automation/data/$input[2]");
		my $processed_file = "processed_$input[4].txt";
		$processed_file =~ s/\s|\\|\/|\'|\"|\%|\^|\#|\@|\!|\$/-/g;
		unlink("$input[3]/automation/data/$processed_file");
	    }
	}
	elsif ( $input[1] eq 'preflight_files' ) {
	    my $connect         = AutoConfig->dbconnect();
	    my %config_settings = AutoConfig->config_settings();
	    my %file_ref        = ();
	    $file_ref{'user_acct'}   = $input[4];                                      # user name in file headers
	    $file_ref{'commit_step'} = 'preflight';
	    $file_ref{'location'}    = "$config_settings{'monarch_home'}/workspace";
	    $file_ref{'nagios_etc'}  = "$config_settings{'monarch_home'}/workspace";
	    my ( $files, $errs ) = AutoConfig->build_files( \%file_ref, \%config_settings );
	    my @errors = @{$errs};

	    if (@errors) {
		foreach my $err (@errors) {
		    $ret_info .= "error|$dt|$err\::";
		}
		$ret_info .= "aborted|$dt|Unable to create files in $file_ref{'location'}. Commit process aborted ...";
	    }
	    else {
		$ret_info .= "preflight_files|$dt|pre-flight|Pre-flight files successfully built.";
	    }
	    my $result = AutoConfig->dbdisconnect();
	}
	elsif ( $input[1] eq 'preflight' ) {
	    my $connect         = AutoConfig->dbconnect();
	    my %config_settings = AutoConfig->config_settings();
	    $config_settings{'verbose'} = 1;
	    my ( $preflight_check, $pf_results ) = AutoConfig->pre_flight_check( \%config_settings );
	    my @preflight_results = reverse @{$pf_results};
	    my $preflight         = undef;
	    foreach my $msg (@preflight_results) {
		if ($msg) { $ret_info .= "preflight|$dt|pre-flight|$msg\::" }
	    }
	    if ($preflight_check) {
		$ret_info .= "preflight|$dt|pre-flight|Pre-flight completed.";
	    }
	    else {
		$ret_info .= "aborted|$dt|Pre-flight failed! Commit process aborted ...";
	    }
	    my $result = AutoConfig->dbdisconnect();
	}
	elsif ( $input[1] eq 'commit_files' ) {
	    my $connect         = AutoConfig->dbconnect();
	    my %config_settings = AutoConfig->config_settings();
	    my %file_ref        = ();
	    $file_ref{'user_acct'}   = $input[4];                          # user name in file headers
	    $file_ref{'commit_step'} = 'commit';
	    $file_ref{'location'}    = "$config_settings{'nagios_etc'}";
	    $file_ref{'nagios_etc'}  = "$config_settings{'nagios_etc'}";

	    my @errors = ();
	    my $res = AutoConfig->copy_files( "$config_settings{'monarch_home'}/workspace", $config_settings{'nagios_etc'} );
	    if ( $res =~ /Error/ ) {
		push @errors, $res;
	    }
	    else {
		$res = AutoConfig->rewrite_nagios( "$config_settings{'monarch_home'}/workspace", $config_settings{'nagios_etc'} );
		if ( $res =~ /Error/ ) { push @errors, $res }
	    }

	    if (@errors) {
		foreach my $err (@errors) {
		    $ret_info .= "error|$dt|$err\::";
		}
		$ret_info .= "aborted|$dt|Unable to create files in $file_ref{'location'}. Commit process aborted ...";
	    }
	    else {
		$ret_info .= "commit_files|$dt|commit|Production files successfully built.";
	    }
	    my $result = AutoConfig->dbdisconnect();
	}
	elsif ( $input[1] eq 'commit_sync' ) {
	    my $connect         = AutoConfig->dbconnect();
	    my %config_settings = AutoConfig->config_settings();
	    my %file_ref        = ();
	    $file_ref{'user_acct'} = $input[4];    # user name in file headers
	    if ( -x "$config_settings{'monarch_home'}/bin/commit_check" ) {
		my $warning = [qx($config_settings{'monarch_home'}/bin/commit_check)];
		push @$warning, 'Configuration check failed.' if not @$warning;
		if ( $warning->[0] ne "Configuration looks okay.\n" ) {
		    foreach my $err (@$warning) {
			$ret_info .= "error|$dt|$err\::" if $err;
		    }
		}
		else {
		    ## FIX MINOR:  It probably doesn't make sense to attempt to draw the annotation and lock from query parameters here.
		    my $annotation = $query->param('annotation');
		    my $lock       = $query->param('lock');
		    $annotation = "Backup auto-created after an Auto-Discovery Commit by user \"$file_ref{user_acct}\"." if not $annotation;
		    $annotation =~ s/\r//g;
		    $annotation =~ s/^\s+|\s+$//g;
		    $annotation .= "\n";

		    my @results = AutoConfig->commit( \%config_settings, $file_ref{'user_acct'}, $annotation, $lock );
		    foreach my $msg (@results) {
			$ret_info .= "commit|$dt|commit|$msg\::" if $msg;
		    }
		    $ret_info .= "commit|$dt|commit|Commit and Foundation sync completed.";
		}
	    }
	    else {
		$ret_info .= "error|$dt|Cannot check your configuration before a commit.\::";
	    }
	    unlink("$input[3]/automation/data/$input[2]");
	    my $processed_file = "processed_$input[4].txt";
	    $processed_file =~ s/\s|\\|\/|\'|\"|\%|\^|\#|\@|\!|\$/-/g;
	    unlink("$input[3]/automation/data/$processed_file");
	    my $result = AutoConfig->dbdisconnect();
	}
	else {
	    print DEBUG "\n-input[0]-$input[0]:input[1]-$input[1]:input[2]-$input[2]:input[3]-$input[3]-------\n" if $debug;
	    my $lines = '';

	    #        auto = auto, 'file', 'monarch_home'
	    # auto-commit = auto, 'file', 'monarch_home'
	    #        nmap = host, type, 'file', 'monarch_home', scan_type, timeout, method_id, traceroute
	    #        snmp = host, type, 'file', 'monarch_home', version, community_strings
	    #         wmi = host, type, 'file', 'monarch_home'
	    #      script = host, type, 'file', 'monarch_home'
	    ##########################################################
	    if ( $input[1] eq 'nmap' ) {
		my ( $ports, $port_defs, $tcp_snmp_opt, $snmp_strings ) = undef;
		my %hosts            = ();
		my %port_definitions = ();
		if (not open( FILE, '<', "$input[3]/automation/data/$input[2]" )) {
		    $ret_info = "error|$dt|$input[3]/automation/data/$input[2] ($!)\::";
		}
		else {
		    while ( my $line = <FILE> ) {
			$line =~ s/[\n\r]+//;
			if ( $line =~ /^#port_def_$input[6]:-:(.*)/ )  { $port_defs    = $1 }
			if ( $line =~ /^#ports_$input[6]:-:(.*)/ )     { $ports        = $1 }
			if ( $line =~ /^#tcp_snmp_opt_$input[6]:-:1/ ) { $tcp_snmp_opt = 1 }
		    }
		    close FILE;

		    # argument string = host, type, 'file', 'monarch_home', scan_type, timeout, method_id, 'traceroute'
		    my $argstr = "$input[0]:-:$input[4]:-:$input[5]:-:$ports";
		    my ($data, $error) = run_program( "$input[3]/bin/nmap_scan_one $argstr", "Nmap $input[4] on $input[0]",
		      $default_timeout_max_seconds, $default_timeout_seconds );
		    if ($error) {
			chomp $error;
			$ret_info = "error|$dt|$error\::";
		    }
		    elsif (!$data) {
			$error = "$!" || 'returned no data';
			$ret_info = "error|$dt|$input[3]/bin/nmap_scan_one $argstr ($error)\::";
		    }
		    else {
			my $errors;
			($errors, %hosts) = process_nmap($data);
			if (@$errors) {
			    chomp $errors->[0];
			    $ret_info = "error|$dt|$input[3]/bin/nmap_scan_one error: $errors->[0]\::";
			}
		    }
		    %port_definitions = port_definitions($port_defs);
		    foreach my $host_key ( keys %hosts ) {
			if ( $hosts{$host_key}{'status'} eq 'up' ) {
			    my $parent = undef;
			    if ( $input[7] ) {
				$parent = get_parent( $input[7], $input[0] );
			    }
			    $lines .=
"$hosts{$host_key}{'name'};;$hosts{$host_key}{'alias'};;$hosts{$host_key}{'address'};;$hosts{$host_key}{'description'};;$parent\n";
			}
			my %ports_matched = ();
			$hosts{$host_key}{'host_profile'} = '&nbsp;-&nbsp;';
			foreach my $port_def ( keys %port_definitions ) {
			    my $got_match = 1;
			    foreach my $port ( keys %{ $port_definitions{$port_def}{'ports'} } ) {
				if ( $hosts{$host_key}{'ports'}{$port} && $port_definitions{$port_def}{'value'} ) {
				    $ports_matched{$port} = 1;
				}
				else {
				    $got_match = 0;
				}
			    }
			    if ( $got_match && $port_definitions{$port_def}{'value'} ) {
				if ( $port_definitions{$port_def}{'value'} =~ /host-profile/ ) {
				    $lines .= ";;;;;;;;;;$port_definitions{$port_def}{'value'}\n";
				    $hosts{$host_key}{'host_profile'} = $port_definitions{$port_def}{'value'};
				}
				elsif ( $port_definitions{$port_def}{'value'} =~ /service-profile/ ) {
				    $lines .= ";;;;;;;;;;;;$port_definitions{$port_def}{'value'}\n";
				}
				else {
				    $lines .= ";;;;;;;;;;;;;;$port_definitions{$port_def}{'value'}\n";
				}
			    }
			}
			foreach my $port ( keys %{ $hosts{$host_key}{'ports'} } ) {
			    unless ( $ports_matched{$port} ) {
				$lines .= ";;;;;;;;;;;;;;$hosts{$host_key}{'ports'}{$port}\n";
			    }
			}
			if ($tcp_snmp_opt) {
			    $ports = "161";
			    my $argstr = "$input[0]:-:udp_scan:-:$input[5]:-:$ports";
			    my ($data, $error) = run_program( "$input[3]/bin/nmap_scan_one $argstr", "Nmap udp_scan on $input[0]",
			      $default_timeout_max_seconds, $default_timeout_seconds );
			    if ($error) {
				chomp $error;
				$ret_info .= "error|$dt|$error\::";
			    }
			    elsif (!$data) {
				$error = "$!" || 'returned no data';
				$ret_info .= "error|$dt|$input[3]/bin/nmap_scan_one $argstr ($error)\::";
			    }
			    else {
				my ($errors, %hosts) = process_nmap($data);
				if (@$errors) {
				    chomp $errors->[0];
				    $ret_info .= "error|$dt|$input[3]/bin/nmap_scan_one error: $errors->[0]\::";
				}
				else {
				    print DEBUG "\n 161 $hosts{'1'}{'ports'}{'161'}\n" if $debug;
				    if ( $hosts{'1'}{'ports'}{'161'} || $hosts{'1'}{'ports'}{'162'} ) {
					$lines .= ";;;;;;;;;;;;;;;;discover-snmp\n";
				    }
				}
			    }
			}
			$ret_info .= "discovered|$dt|$hosts{$host_key}{'address'}|$hosts{$host_key}{'name'}|$hosts{$host_key}{'description'}";
		    }
		}
	    }
	    elsif ( $input[1] eq 'nmap_udp' ) {
		my ( $ports, $port_defs, $snmp_strings ) = undef;
		my ( $next, $got_host ) = undef;
		my $record               = undef;
		my %processed_snmp_nodes = ();
		my @snmp_nodes           = ();
		my %got_snmp_nodes       = ();
		my @snmp_strings         = ('discover-snmp');

		# name;;alias;;address;;description;;parent;;profile;;service profile;;service
		if (not open( FILE, '<', "$input[3]/automation/data/$input[2]" )) {
		    $ret_info = "error|$dt|$input[3]/automation/data/$input[2] ($!)\::";
		}
		else {
		    while ( my $line = <FILE> ) {
			$line =~ s/[\n\r]+//;

			# TODO: need to change this so comments are not used to hold significant data.
			if ( $line =~ /^#(?:port_def_$input[6]|ports_$input[6]:-:|processed_udp_\S+|snmp_match_strings:-:)/ ) {
			    if ( $line =~ /^#port_def_$input[6]:-:(.*)/ ) {
				$port_defs = $1;
			    }
			    if ( $line =~ /^#ports_$input[6]:-:(.*)/ ) {
				$ports = $1;
			    }
			    if ( $line =~ /^#processed_udp_(\S+)/ ) {
				$processed_snmp_nodes{$1} = 1;
			    }
			    if ( $line =~ /^#snmp_match_strings:-:(.*)/ ) {
				push( @snmp_strings, split( ',', $1 ) );
			    }
			}
			else {
			    ## Skip all other comment lines. but note for those matched in
			    ## the above if, we need to continue, as they are significant.
			    next if ( $line =~ /^\s*(?:#.*)?$/ );
			}
			my @values = split( /;;/, $line );
			if ( $values[2] ) {
			    $record = $values[2];
			}
			foreach my $snmp_str (@snmp_strings) {
			    my $got_snmp = 0;
			    if ( $values[3] =~ /$snmp_str/i ) { $got_snmp = 1 }
			    if ( $got_snmp && !$got_snmp_nodes{$record} ) {
				push @snmp_nodes, $record;
				$got_snmp_nodes{$record} = 1;
			    }
			}
		    }
		    close FILE;

		    my %hosts = ();
		    foreach my $host (@snmp_nodes) {
			if ($got_host) {
			    $next = $host;
			    last;
			}
			if ( !$processed_snmp_nodes{$host} ) {
			    my $argstr = "$host:-:$input[4]:-:$input[5]:-:$ports";
			    my ($data, $error) = run_program( "$input[3]/bin/nmap_scan_one $argstr", "Nmap $input[4] on $host",
			      $default_timeout_max_seconds, $default_timeout_seconds );
			    if ($error) {
				chomp $error;
				$ret_info .= "error|$dt|$error\::";
			    }
			    elsif (!$data) {
				$error = "$!" || 'returned no data';
				$ret_info .= "error|$dt|$input[3]/bin/nmap_scan_one $argstr ($error)\::";
			    }
			    else {
				my $errors;
				($errors, %hosts) = process_nmap($data);
				if (@$errors) {
				    chomp $errors->[0];
				    $ret_info .= "error|$dt|$input[3]/bin/nmap_scan_one error: $errors->[0]\::";
				}
			    }
			    $got_host = 1;
			}
		    }
		    my %port_definitions = port_definitions($port_defs);
		    foreach my $host_key ( keys %hosts ) {
			if ( $hosts{$host_key}{'status'} eq 'up' ) {
			    $lines .= "$hosts{$host_key}{'name'};;$hosts{$host_key}{'alias'};;$hosts{$host_key}{'address'};;;;\n";
			}
			my %ports_matched = ();
			$hosts{$host_key}{'host_profile'} = '&nbsp;-&nbsp;';
			foreach my $port_def ( keys %port_definitions ) {
			    my $got_match = 1;
			    foreach my $port ( keys %{ $port_definitions{$port_def}{'ports'} } ) {
				if ( $hosts{$host_key}{'ports'}{$port} && $port_definitions{$port_def}{'value'} ) {
				    $ports_matched{$port} = 1;
				}
				else {
				    $got_match = 0;
				}
			    }
			    if ( $got_match && $port_definitions{$port_def}{'value'} ) {
				if ( $port_definitions{$port_def}{'value'} =~ /host-profile/ ) {
				    $lines .= ";;;;;;;;;;$port_definitions{$port_def}{'value'}\n";
				    $hosts{$host_key}{'host_profile'} = $port_definitions{$port_def}{'value'};
				}
				elsif ( $port_definitions{$port_def}{'value'} =~ /service-profile/ ) {
				    $lines .= ";;;;;;;;;;;;$port_definitions{$port_def}{'value'}\n";
				}
				else {
				    $lines .= ";;;;;;;;;;;;;;$port_definitions{$port_def}{'value'}\n";
				}
			    }
			}
			foreach my $port ( keys %{ $hosts{$host_key}{'ports'} } ) {
			    unless ( $ports_matched{$port} ) {
				$lines .= ";;;;;;;;;;;;;;$hosts{$host_key}{'ports'}{$port}\n";
			    }
			}
			$lines    .= "#processed_udp_$hosts{$host_key}{'address'}\n";
			# FIX MAJOR:  This needs testing to make sure it works, and to drop obsolete code.
			# $ret_info .= "discovered|$dt|$hosts{$host_key}{'address'}|$hosts{$host_key}{'name'}|UDP SCAN\::";
			$part_ret_info = "$dt|$hosts{$host_key}{'address'}|$hosts{$host_key}{'name'}";
		    }
		    foreach my $node ( keys %processed_snmp_nodes ) {
			if ( $got_snmp_nodes{$node} ) { delete $got_snmp_nodes{$node} }
		    }
		}
		my $keys = keys %got_snmp_nodes;
		if ( $keys > 1 ) {
		    $ret_info .= "discover_deep|$next|$part_ret_info|UDP SCAN";
		}
		elsif ( $keys == 1 ) {
		    $ret_info .= "method_complete|$part_ret_info|UDP SCAN";
		}
		else {
		    $ret_info .= "method_complete|$dt|no hosts to scan|No SNMP string matches were found.|UDP SCAN";
		}
	    }
	    elsif ( $input[1] eq 'nmap_snmp' ) {
		my $snmp_command         = undef;
		my $record               = undef;
		my %processed_snmp_nodes = ();
		my @snmp_nodes           = ();
		my %got_snmp_nodes       = ();
		my @snmp_strings         = ('discover-snmp');
		my $next                 = '';

		# name;;alias;;address;;description;;parent;;profile;;service profile;;service
		if (not open( FILE, '<', "$input[3]/automation/data/$input[2]" )) {
		    $ret_info = "error|$dt|$input[3]/automation/data/$input[2] ($!)\::";
		}
		else {
		    while ( my $line = <FILE> ) {
			$line =~ s/[\n\r]+//;

			# TODO: need to change this so comments are
			# not used to hold significant data.
			#snmp_match_strings:-:cisco,laserjet
			if ( $line =~ /^#(?:snmp_match_strings:-:|processed_snmp_\S+)/ ) {
			    if ( $line =~ /^#snmp_match_strings:-:(.*)/ ) {
				push( @snmp_strings, split( ',', $1 ) );
			    }
			    if ( $line =~ /^#processed_snmp_(\S+)/ ) {
				$processed_snmp_nodes{$1} = 1;
			    }
			}
			else {
			    ## Skip all other comment lines. but note for those matched in
			    ## the above if, we need to continue, as they are significant.
			    next if ( $line =~ /^\s*(?:#.*)?$/ );
			}
			my @values = split( /;;/, $line );
			if ( $values[2] ) {
			    $record = $values[2];
			}
			my $got_snmp = 0;
			if ( $line =~ /discover-snmp/ ) {
			    unless ( $got_snmp_nodes{$record} ) {
				push @snmp_nodes, $record;
				$got_snmp_nodes{$record} = 1;
			    }
			}
			foreach my $snmp_str (@snmp_strings) {
			    if ( $values[3] =~ /$snmp_str/i ) { $got_snmp = 1 }
			}
			if ( $got_snmp && !$got_snmp_nodes{$record} ) {
			    push @snmp_nodes, $record;
			    $got_snmp_nodes{$record} = 1;
			}
		    }
		    close FILE;

		    my $got_host = undef;
		    foreach my $host (@snmp_nodes) {
			if ($got_host) {
			    $next = $host;
			    last;
			}
			if ( !$processed_snmp_nodes{$host} ) {
			    ( $lines, $part_ret_info ) = get_snmp( $host, $input[6], $input[4], $snmp_command );
			    $lines .= "#processed_snmp_$host\n";
			    $got_host = 1;
			}
		    }
		    foreach my $node ( keys %processed_snmp_nodes ) {
			if ( $got_snmp_nodes{$node} ) { delete $got_snmp_nodes{$node} }
		    }
		}
		my $keys = keys %got_snmp_nodes;
		if ( $keys > 1 ) {
		    $ret_info = "discover_deep|$next|$part_ret_info|SNMP SCAN";
		}
		elsif ( $keys == 1 ) {
		    $ret_info = "method_complete|$part_ret_info|SNMP SCAN";
		}
		else {
		    $ret_info .= "method_complete|$dt|no hosts to scan|No SNMP string matches were found.|SNMP SCAN";
		}
	    }
	    elsif ( $input[1] eq 'nmap_script' ) {
		my $batch_mode = 0;
		if ( $input[4] =~ /^batch:(.*)/ ) {
		    $input[4] = $1;
		    $batch_mode = 1;
		}
		my $record                 = undef;
		my %processed_script_nodes = ();
		my @script_nodes           = ();
		my %got_script_nodes       = ();
		my $next                   = '';

		# name;;alias;;address;;description;;parent;;profile;;service profile;;service
		if (not open( FILE, '<', "$input[3]/automation/data/$input[2]" )) {
		    $ret_info = "error|$dt|$input[3]/automation/data/$input[2] ($!)\::";
		}
		else {
		    while ( my $line = <FILE> ) {
			$line =~ s/[\n\r]+//;

			# TODO: need to change this so comments are
			# not used to hold significant data.
			#snmp_match_strings:-:cisco,laserjet
			# need the outer 'if' for the else.
			# otherwise, if we just did next if without
			# the else, then the code that follows
			# the next if would not be executed
			# for this line of input.
			if ( $line =~ /^#(?:processed_script_\S+)/ ) {
			    if ( $line =~ /^#processed_script_(\S+)/ ) {
				$processed_script_nodes{$1} = 1;
			    }
			}
			else {
			    ## Skip all other comment lines. but note for those matched in
			    ## the above if, we need to continue, as they are significant.
			    next if ( $line =~ /^\s*(?:#.*)?$/ );
			}
			my @values = split( /;;/, $line );
			if ( $values[2] ) {
			    $record = $values[2];
			}
			my $got_script = 0;
			if ($batch_mode) {
			    @script_nodes = ("batch");        # do not use push()
			    $got_script_nodes{"batch"} = 1;
			}
			elsif ( $line =~ /discover-script/i ) {
			    $got_script = 1;
			}
			if ( $got_script && !$got_script_nodes{$record} ) {
			    push @script_nodes, $record;
			    $got_script_nodes{$record} = 1;
			}
		    }
		    close FILE;

		    my $got_host   = 0;
		    my $batch_done = 0;
		    foreach my $host (@script_nodes) {
			next if ($batch_done);
			if ($got_host) {
			    $next = $host;
			    last;
			}
			if ( !$processed_script_nodes{$host} ) {
			    ( $lines, $part_ret_info ) = run_script( $host, $input[4] );
			    if ($batch_mode) {
				$batch_done = 1;
			    }
			    $lines .= "#processed_script_$host\n";
			    $got_host = 1;
			}
		    }
		    foreach my $node ( keys %processed_script_nodes ) {
			if ( $got_script_nodes{$node} ) { delete $got_script_nodes{$node} }
		    }
		}
		my $keys = keys %got_script_nodes;
		if ( $keys > 1 ) {
		    $ret_info = "discover_deep|$next|$part_ret_info|SCRIPT SCAN";
		}
		elsif ( $keys == 1 ) {
		    $ret_info = "method_complete|$part_ret_info|SCRIPT SCAN";
		}
		else {
		    $ret_info .= "method_complete|$dt|no hosts to scan|No discover-script string matches were found.|SCRIPT SCAN";
		}
	    }
	    elsif ( $input[1] eq 'snmp' ) {
		my $parent = undef;
		if ( $input[7] ) {
		    $parent = get_parent( $input[7], $input[0] );
		}
		( $lines, $part_ret_info ) = get_snmp( $input[0], $input[6], $input[4], $input[5], $parent );
		$ret_info = "discovered|$part_ret_info|SNMP SCAN";
	    }
	    elsif ( $input[1] eq 'script' ) {
		if ( $input[4] =~ /^batch:(.*)/ ) {
		    $input[4] = $1;
		}
		( $lines, $part_ret_info ) = run_script( $input[0], $input[4] );
		$ret_info = "discovered|$part_ret_info|SCRIPT SCAN";
	    }
	    elsif ( $input[1] eq 'wmi' ) {
		# Note that $input[3] and $input[4] may not make it out onto the screen.
		$ret_info = "discovered|$dt|$input[0]|$input[1]|$input[2]|$input[3]|$input[4]";
	    }
	    else {
		$ret_info = "$input[0]|$input[1]|$input[2]|$input[3]|$input[4]";
	    }
	    if ( $lines && -e "$input[3]/automation/data/$input[2]" ) {
		if (not open( FILE, '>>', "$input[3]/automation/data/$input[2]" )) {
		    $ret_info = "error|$dt|$input[3]/automation/data/$input[2] ($!)\::";
		}
		else {
		    print FILE $lines;
		    close FILE;
		}
	    }
	}
	if ($debug) {
	    close DEBUG;
	}

	# Do everything we can here to set headers to prevent caching of the result by the browser.
	print join '',
	    "Date: $now\n",
	    "Pragma: no-cache\n",
	    "Cache-Control: no-store, no-cache, must-revalidate, post-check=0, pre-check=0\n",
	    "Expires: 0\n",
	    "Vary: *\n",
	    "Last-Modified: $now\n",
	    "If-Modified-Since: $now\n",
	    "Content-Type: text/plain \n\n",
	    $ret_info;
    }
    else {
	# Do everything we can here to set headers to prevent caching of the result by the browser.
	print join '',
	    "Date: $now\n",
	    "Pragma: no-cache\n",
	    "Cache-Control: no-store, no-cache, must-revalidate, post-check=0, pre-check=0\n",
	    "Expires: 0\n",
	    "Vary: *\n",
	    "Last-Modified: $now\n",
	    "If-Modified-Since: $now\n",
	    "Content-Type: text/plain \n\n",
	    "aborted|$dt|This discovery has been canceled by the action of another session.";
    }
}

&get_hosts;

__END__

sub get_hosts {
    my $query = new CGI();

    # Adapt to an upgraded CGI package while still maintaining backward compatibility.
    my $multi_param = $query->can('multi_param') ? 'multi_param' : 'param';

    my $dt = AutoConfig->datetime();
    my @input = $query->$multi_param('args');
    my $ret_info = "commit_results|$dt|$input[0]\::";
    my $line = "$input[0];;$input[0];;$input[0];;Description\n";
    if (not open (FILE, '>>', "$input[2]")) {
	$ret_info = "error|$dt|$input[2] ($!)\::";
    }
    else {
	print FILE $line;
	close FILE;
    }
    print "Content-Type: text/plain \n\n";
    print $ret_info;
}
&get_hosts;

