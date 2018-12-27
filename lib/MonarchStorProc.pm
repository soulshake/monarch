# MonArch - Groundwork Monitor Architect
# MonarchStorProc.pm
#
############################################################################
# Release 4.6
# June 2018
############################################################################
#
# Original author: Scott Parris
#
# Copyright 2007-2018 GroundWork Open Source, Inc. (GroundWork)
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

#use warnings;
use XML::LibXML;
use DBI;
use Time::Local;
use Time::HiRes;
use MonarchConf;
use CGI::Session qw/-ip-match/;
use Config;
use HTML::Entities;

package main;

# This variable is placed in the main namespace so it can be easily shared
# across all modules in the application that might need access to it.
our $shutdown_requested = 0;

package StorProc;

my $debug         = 0;
my $debug_restore = 0;

my $backup_format = 'tar';  # 'tar' or 'plain'

# This variable can be set outside this package for testing purposes, if desired.
our $show_timing = 0;    # Set to 0 for normal operation, 1 to display timing statistics.

# FIX MAJOR:  Put back the proper version number at the end of the release development cycle.
# my $current_gwmon_version   = 'DEV';
my $current_gwmon_version   = '7.2.1';
my $current_monarch_version = '4.6';

# This parameter might need local tuning under adverse circumstances.
my $max_commit_lock_attempts = 20;

my ( $dbh, $err, $rows );
my ( $dbtype, $dbhost, $database, $user, $passwd ) = undef;
my $is_portal = 0;
if ( -e '/usr/local/groundwork/config/db.properties' ) { $is_portal = 1 }

# '0+0' is treated by Perl as true, but by MySQL as zero (it is apparently able
# to convert the string to an expression and evaluate it).  This is what we need
# to sidestep the clumsy and inappropriate code in StorProc->update_obj_where()
# that recodes plain zeros as NULLs.  We need to force a true zero in the database
# to indicate that this value is really defined.
my $DEFINED = '0+0';
my $DEFINED_REF = \$DEFINED;

# It's not clear that this package is where the sanitize routines should reside.
# We're putting them here temporarily as a convenience, and may move them.

sub IsNonNewlineControl {
    return <<'END';
+utf8::IsC
-0a
END
}

sub sanitize_string($$) {
    local $_;

    my $string;
    for ( $string = $_[1] ) {
	if (defined $_) {
	    ## We turn soft hyphens into ordinary hyphens partly because their similar appearance
	    ## would probably cause confusion and failure down the road, and partly because they
	    ## are categorized as Unicode control characters rather than printing characters.
	    ## See http://www.cs.tut.fi/~jkorpela/shy.html for details.  For now, we'll leave
	    ## non-breaking spaces alone, not translating them to ordinary spaces.
	    s/\xAD/-/g;
	    s/\pC//g;
	    s/^\s+|\s+$//g;
	}
    }
    return $string;
}

sub sanitize_string_but_keep_newlines($$) {
    local $_;

    my $string;
    for ( $string = $_[1] ) {
	if (defined $_) {
	    s/\xAD/-/g;
	    s/\p{IsNonNewlineControl}//g;
	    s/^\s+|\s+$//g;
	}
    }
    return $string;
}

sub sanitize_string_array($@) {
    shift;    # drop self-object
    local $_;

    my @strings;
    for ( @strings = @_ ) {
	$_ = sanitize_string( '', $_ );
    }
    return @strings;
}

sub doc_section_url {
    my $doc_article = $_[1];
    my $doc_section = $_[2];
    ## For GWMEE 7.2.0 and before, we use DOC72 and similar two-digit values.
    ## For GWMEE 7.2.1, we use DOC721.  This logic must be revised as needed for future releases.
    my @gwmon_version = split( /\./, $current_gwmon_version );
    my $doc_version = join( '', 'DOC', @gwmon_version[ 0 .. ( $#gwmon_version ? ( $current_gwmon_version eq '7.2.1' ? 2 : 1 ) : 0 ) ] );
    return "https://kb.gwos.com/display/$doc_version/$doc_article" . ( defined($doc_section) ? '#' . $doc_section : '' );
}

sub check_version {
    my $version = $_[1];
    my @errors  = ();

    if ( $current_monarch_version ne $version ) {
	push @errors, "The current supported Monarch version is $current_monarch_version, while your database schema is version $version.";
	my ($cur_major, $cur_minor) = split(/\./, $current_monarch_version);
	my ($got_major, $got_minor) = split(/\./, $version);
	if ( $cur_major > $got_major || ( $cur_major == $got_major && $cur_minor > $got_minor ) ) {
	    my $migration_script = $cur_major < 4
		? '/usr/local/groundwork/monarch/bin/migrate-monarch.pl'
		: '/usr/local/groundwork/monarch/bin/pg_migrate_monarch.pl';
	    push @errors, "You must run the migration script ($migration_script) to convert the schema to the current release.";
	}
	else {
	    push @errors, "Contact GroundWork Support for assistance.";
	}
    }

    return \@errors;
}

#
# get_normalized_hostname
#
# Given a hostname with any capitalization, return the same hostname, but with
# the same capitalization that is already stored in the hosts table of the
# monarch database. If there is no such hostname in the monarch database,
# the original hostname is returned.
sub get_normalized_hostname(@) {
    my $name    = $_[1];
    my $sqlstmt = "select name from hosts where name = '$name'";
    my $sth     = $dbh->prepare($sqlstmt);
    $sth->execute;
    my @values = $sth->fetchrow_array();
    $sth->finish;
    if (@values) {
	return $values[0];
    }
    return $name;    # host was not found in monarch database; return original.
}

sub table_enforce_uniqueness {
    my $table = shift;

    my $restricted_tables = {
	'discover_group_filter'       => [qw(group_id filter_id)],
	'discover_group_method'       => [qw(group_id method_id)],
	'discover_method_filter'      => [qw(method_id filter_id)],
	'import_match_contactgroup'   => [qw(match_id contactgroup_id)],
	'import_match_group'          => [qw(match_id group_id)],
	'import_match_hostgroup'      => [qw(match_id hostgroup_id)],
	'import_match_parent'         => [qw(match_id parent_id)],
	'import_match_servicename'    => [qw(match_id servicename_id)],
	'import_match_serviceprofile' => [qw(match_id serviceprofile_id)],
	'contactgroup_group'          => [qw(contactgroup_id group_id)],      # GWMON-4351
	'contactgroup_contact'        => [qw(contactgroup_id contact_id)],    # GWMON-4351
    };
    return unless defined( $restricted_tables->{$table} );
    return $restricted_tables->{$table};
}

sub dbconnect(;$) {
    $dbh = $_[1];
    if (not defined $dbh) {
	if ($is_portal) {
	    my $config_file = '/usr/local/groundwork/config/db.properties';
	    if ( !open( FILE, '<', $config_file ) ) {
	        die "ERROR:  Cannot read $config_file ($!).\n";
	    }
	    else {
		while ( my $line = <FILE> ) {
		    if ( $line =~ /^\s*global\.db\.type\s*=\s*(\S+)/ )  { $dbtype   = $1 }
		    if ( $line =~ /^\s*monarch\.dbhost\s*=\s*(\S+)/ )   { $dbhost   = $1 }
		    if ( $line =~ /^\s*monarch\.database\s*=\s*(\S+)/ ) { $database = $1 }
		    if ( $line =~ /^\s*monarch\.username\s*=\s*(\S+)/ ) { $user     = $1 }
		    if ( $line =~ /^\s*monarch\.password\s*=\s*(\S+)/ ) { $passwd   = $1 }
		}
		close(FILE);
	    }
	}
	else {
	    ( $dbhost, $database, $user, $passwd, $dbtype ) = Conf->get_dbauth();
	}
	my $dsn = '';
	if ( defined($dbtype) && $dbtype eq 'postgresql' ) {
	    $dsn = "DBI:Pg:dbname=$database;host=$dbhost";
	}
	else {
	    die "ERROR:  DB type not supported.\n";
	}
	$dbh = DBI->connect( $dsn, $user, $passwd, {
	    'AutoCommit' => 1,
	    'RaiseError' => 1,
	    # 'PrintError' => 0  # Should we use this too?  Review all error handling.
	} );
    }
    my $sqlstmt = "select value from setup where name = 'login_authentication'";
    my ($login_type) = $dbh->selectrow_array($sqlstmt);
    if ( defined($login_type) && $login_type eq 'none' ) {
	return 1;
    }
    elsif ( defined($login_type) && $login_type eq 'passive' ) {
	return 3;
    }
    elsif ( defined($login_type) && $login_type eq 'open' ) {
	return 4;
    }
    else {
	return 2;
    }
}

sub set_session(@) {
    my $userid     = $_[1];
    my $user_acct  = $_[2];
    my $sqlstmt    = "select value from setup where name = 'session_timeout'";
    my ($timeout)  = $dbh->selectrow_array($sqlstmt);
    my $session    = new CGI::Session(
	( defined($dbtype) && $dbtype eq 'postgresql' ) ? 'driver:PostgreSQL' : 'driver:MySQL',
	undef, { Handle => $dbh }
    );
    my $session_id = $session->id();
    $session->expire($timeout);
    $session->param( 'userid',    $userid );
    $session->param( 'user_acct', $user_acct );
    my $stale = time + 172800;
    $session->param( 'session_stale', $stale );
    $dbh->do("update users set session = '$session_id' where user_id = '$userid'");
    cleanup_sessions();
    return $session_id;
}

sub set_gwm_session(@) {
    my $user_acct  = $_[1];
    my $sqlstmt    = "select value from setup where name = 'session_timeout'";
    my ($timeout)  = $dbh->selectrow_array($sqlstmt);
    my $session    = new CGI::Session(
	( defined($dbtype) && $dbtype eq 'postgresql' ) ? 'driver:PostgreSQL' : 'driver:MySQL',
	undef, { Handle => $dbh }
    );
    my $session_id = $session->id();
    my $q_user_acct = $dbh->quote($user_acct);
    ## FIX MAJOR:  Revise to not re-use an existing row, but to always insert a new row, as long as we have a
    ## means to clean up old stale rows (perhaps by joining to the sessions table after it is cleaned up).
    $sqlstmt = "select user_id from users where user_acct = $q_user_acct";
    my ($userid) = $dbh->selectrow_array($sqlstmt);
    unless ($userid) {
	$sqlstmt = "select usergroup_id from user_groups where name = 'super_users'";
	my ($gid) = $dbh->selectrow_array($sqlstmt);
	## FIX MAJOR:  always insert a new row (because a new $session_id was just obtained), with a "default" user_id
	$sqlstmt = "insert into users values (default,$q_user_acct,$q_user_acct,'','$session_id')";
	$sqlstmt .= " returning user_id" if defined($dbtype) && $dbtype eq 'postgresql';
	my $sth = undef;
	eval {
	    $sth = $dbh->prepare($sqlstmt);
	    $sth->execute;
	};
	if ($@) {
	    $sth->finish;
	    log_caller( '', $sqlstmt, $@ );
	    return undef, undef;
	}
	else {
	    if ( defined($dbtype) && $dbtype eq 'postgresql' ) {
		$userid = $sth->fetchrow_arrayref()->[0];
	    }
	    else {
		$sth->finish;
		$userid = $dbh->selectrow_array("select last_insert_id() as lastrow from users");
	    }
	    $sth->finish;
	}
	if ( defined($dbtype) && $dbtype eq 'postgresql' ) {
	    eval {
		## Handle exceptions below; suppress PrintError output here.
		local $dbh->{'PrintError'} = 0;    # same as:  local $SIG{__WARN__} = sub { };
		$dbh->do("insert into user_group values('$gid','$userid')");
	    };
	    if ($@) {
		## $@ contains $dbh->errstr value
		unless ( $@ =~ /duplicate key value violates unique constraint/ ) {
		    die "DB insert error: " . $@;
		}
	    }
	}
	else {
	    if ( defined($dbtype) && $dbtype eq 'postgresql' ) {
		if ( not $dbh->selectrow_arrayref("select usergroup_id from user_group where usergroup_id = '$gid' and user_id = '$userid'") ) {
		    ## Catch possible duplicate-key errors anyway, to protect against concurrent inserts.
		    eval {
			$dbh->do("insert into user_group values('$gid','$userid')");
		    };
		    if ($@) {
			if ( $@ !~ /duplicate key value/i ) {
			    chomp $@;
			    die "ERROR:  insert of ($gid, $userid) into user_group failed:\n    $@\n";
			}
		    }
		}
	    }
	    else {
		$dbh->do("replace into user_group values('$gid','$userid')");
	    }
	}
    }
    my $stale = time + 172800;
    $session->param( 'session_stale', $stale );
    $session->param( 'userid',        $userid );
    $session->param( 'user_acct',     $user_acct );
    ## FIX MAJOR:  this update won't be needed when we always insert a new row
    $dbh->do("update users set session = '$session_id' where user_id = '$userid'");
    ## FIX MAJOR:  your stale session can be cleaned up by the actions of some other user, but that should be okay
    cleanup_sessions();
    return $userid, $session_id;
}

sub cleanup_sessions() {
    my $session_stale = time - 172800;
    my $sqlstmt       = "select * from sessions";
    my $sth           = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	if ( $values[1] =~ /'session_stale'\s*=>\s*(\d+)/ ) {
	    if ( $1 < $session_stale ) {
		$dbh->do("delete from sessions where id = '$values[0]'");
	    }
	}
    }
    $sth->finish;
}

sub get_session(@) {
    my $sid          = $_[1];
    my $auth_passive = $_[2];
    my $now          = time;
    my $dt           = StorProc->datetime();

    $sid =~ s/[[:^xdigit:]]+//g if defined $sid;
    my $session = new CGI::Session(
	( defined($dbtype) && $dbtype eq 'postgresql' ) ? 'driver:PostgreSQL' : 'driver:MySQL',
	$sid, { Handle => $dbh }
    );
    if ($session) {
	my $stale = time + 172800;
	$session->param( 'session_stale', $stale );
	if ($is_portal) {
	    my $stale = time + 172800;
	    $session->param( 'session_stale', $stale );
	}
	else {
	    my $sqlstmt = "select value from setup where name = 'session_timeout'";
	    my ($timeout) = $dbh->selectrow_array($sqlstmt);
	    $session->expire($timeout);
	}
	$sid = $session->id();
	my $user_acct = $session->param('user_acct');    # undef, if new session
	my $userid    = $session->param('userid');       # undef, if new session
	return $userid, $user_acct, $sid;
    }
    else {
	## CGI::Session could neither find $sid nor create a new session
	$dbh->do("delete from sessions where id = '$sid'");
	if ($is_portal) {
	    my $sqlstmt = "select user_id, user_acct from users where session = '$sid'";
	    my ( $userid, $user_acct ) = $dbh->selectrow_array($sqlstmt);
	    if ( defined($userid) and defined($user_acct) ) {
		$sqlstmt = "select value from setup where name = 'session_timeout'";
		my ($timeout) = $dbh->selectrow_array($sqlstmt);
		my $session = new CGI::Session(
		    ( defined($dbtype) && $dbtype eq 'postgresql' ) ? 'driver:PostgreSQL' : 'driver:MySQL',
		    undef, { Handle => $dbh }
		);
		if ($session) {
		    $sid = $session->id();
		    my $stale = time + 172800;
		    $session->param( 'session_stale', $stale );
		    $session->param( 'userid',        $userid );
		    $session->param( 'user_acct',     $user_acct );
		    $dbh->do("update users set session = '$sid' where userid = '$userid'");
		    return $userid, $user_acct, $sid;
		}
	    }
	}
	$dbh->do("delete from users where session = '$sid'");
    }
    return undef, undef, undef;
}

sub check_user(@) {
    my $user_acct = $_[1];
    my $password  = $_[2];
    my $error     = undef;
    my $now       = time;
    my $sqlstmt   = "select user_id, session from users where user_acct = '$user_acct'";
    my ( $userid, $session ) = $dbh->selectrow_array($sqlstmt);
    if ($userid) {
	$sqlstmt = "select value from setup where name = 'login_authentication'";
	my ($login_type) = $dbh->selectrow_array($sqlstmt);
	if ( $login_type eq 'active' ) {
	    if ($password) {
		$sqlstmt = "select password from users where user_id = '$userid'";
		my ($ck_password) = $dbh->selectrow_array($sqlstmt);
		if ( crypt( $password, $ck_password ) eq $ck_password ) {
		    my $sth = $dbh->prepare( "update users set session = $now where user_id = '$userid'" );
		    $sth->execute;
		    $sth->finish;
		}
		else {
		    $error = "Invalid username or password";
		}
	    }
	    else {
		$sqlstmt = "select value from setup where name = 'session_timeout'";
		my ($timeout) = $dbh->selectrow_array($sqlstmt);
		if ( ( $now - $session ) > $timeout ) {
		    $error = "Session timed out. Please login.";
		}
		else {
		    my $sth = $dbh->prepare( "update users set session = $now where user_id = '$userid'" );
		    $sth->execute;
		    $sth->finish;
		}
	    }
	}
	else {
	    my $sth = $dbh->prepare("update users set session = $now where user_id = '$userid'");
	    $sth->execute;
	    $sth->finish;
	}
    }
    else {
	$error = "Invalid username or password";
    }
    if ($error) {
	return $error;
    }
    else {
	return $userid;
    }
}

sub auth_matrix(@) {
    my $userid      = $_[1];
    my %auth_add    = ();
    my %auth_modify = ();
    my %auth_delete = ();
    return ( \%auth_add, \%auth_modify, \%auth_delete ) if not defined $userid;
    my $sqlstmt =
      "select usergroup_id, name from user_groups where usergroup_id in (select usergroup_id from user_group where user_id ='$userid')";
    my $sth = $dbh->prepare($sqlstmt);
    $sth->execute;
    my $groupid = undef;
    my $gname   = undef;
    eval { $sth->bind_columns( undef, \$groupid, \$gname ) };

    while ( $sth->fetch() ) {
	my ( $object, $type, $access_values ) = undef;
	$sqlstmt = "select object, type, access_values from access_list where usergroup_id = '$groupid'";
	my $sth2 = $dbh->prepare($sqlstmt);
	$sth2->execute;
	eval { $sth2->bind_columns( undef, \$object, \$type, \$access_values ) };
	while ( $sth2->fetch() ) {
	    if ( $type eq 'design_manage' ) {
		if ( $access_values =~ /add/ ) {
		    $auth_add{$object} = 1;
		    $auth_add{'design'} = 1;
		}
		if ( $access_values =~ /modify/ ) {
		    $auth_modify{$object} = 1;
		    $auth_add{'modify'} = 1;
		}
		if ( $access_values =~ /delete/ ) { $auth_delete{$object} = 1 }
	    }
	    else {
		if ( $type eq 'control' || $gname eq 'super_users' ) {
		    $auth_add{'control'} = 1;
		}
		if ( $type eq 'groups' || $gname eq 'super_users' ) {
		    $auth_add{'groups'} = 1;
		}
		if ( $type eq 'auto_discover' || $gname eq 'super_users' ) {
		    $auth_add{'auto_discover'} = 1;
		}
		$auth_add{$object} = 1;
	    }
	}
	$sth2->finish;
    }
    $sth->finish;
    return ( \%auth_add, \%auth_modify, \%auth_delete );
}

sub logout(@) {
    my $userid = $_[1];
    my $sth    = $dbh->prepare("update users set session = '0' where user_id = '$userid'");
    $sth->execute;
    $sth->finish;
}

sub dbdisconnect() {
    $dbh->disconnect() if $dbh;
}

sub get_hosts() {
    my %hosts   = ();
    my $sqlstmt = "select name, host_id from hosts";
    my $sth     = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	$hosts{ $values[0] } = $values[1];
    }
    $sth->finish;
    return %hosts;
}

# FIX MINOR:  extend this with a second, optional parameter:
# - => ignore parsing errors; 0 => die on parsing error; + => return error info
sub parse_xml(@) {
    my $data       = $_[1];
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
	    $@ = HTML::Entities::encode($@);
	    $@ =~ s/\n/<br>/g;
	    if ($@ =~ s/external entity callback died: // || $@ =~ /external entity references are not allowed/) {
		## First undo the effect of the croak() call in XML::LibXML.
		$@ =~ s/ at \S+ line \d+<br>//;
		$properties{'error'} = "Bad XML string (parse_xml):<br>$@";
	    }
	    elsif ($@ =~ /Attempt to load network entity/) {
		$properties{'error'} = "Bad XML string (parse_xml):<br>INVALID FORMAT: non-local entity references are not allowed in XML documents.<pre>$@</pre>";
	    }
	    else {
		$properties{'error'} = "Bad XML string (parse_xml):<br>$@ called from $file line $line.";
	    }
	}
	else {
	    my @nodes = $doc->findnodes("//prop");
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
			if ( $value =~ /^\d+$/ && $value == 0 ) {
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
	my ($package, $file, $line) = caller;
	$properties{'error'} = "Empty String (parse_xml); called from $file line $line.";
    }
    return %properties;
}

sub parse_profile_xml(@) {
    my $data       = $_[1];
    my %properties = ();
    if ($data) {
	my $parser = XML::LibXML->new(
	    ext_ent_handler => sub { die "INVALID FILE FORMAT: external entity references are not allowed in profiles.\n" },
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
	    $@ = HTML::Entities::encode($@);
	    $@ =~ s/\n/<br>/g;
	    if ($@ =~ s/external entity callback died: // || $@ =~ /external entity references are not allowed/) {
		## First undo the effect of the croak() call in XML::LibXML.
		$@ =~ s/ at \S+ line \d+<br>//;
		$properties{'error'} = "Bad XML string (parse_profile_xml):<br>$@";
	    }
	    elsif ($@ =~ /Attempt to load network entity/) {
		$properties{'error'} = "Bad XML string (parse_profile_xml):<br>INVALID FILE FORMAT: non-local entity references are not allowed in profiles.<pre>$@</pre>";
	    }
	    else {
		$properties{'error'} = "Bad XML string (parse_profile_xml):<br>$@ called from $file line $line.";
	    }
	}
	else {
	    my $type         = '';
	    my @nodes        = ();
	    my @host_profile = $doc->findnodes("/profile/host_profile");
	    if (@host_profile) {
		@nodes = $doc->findnodes("/profile/host_profile/prop");
		$type  = 'host profile';
	    }
	    else {
		my @service_profiles = $doc->findnodes("/profile/service_profile");
		if (@service_profiles) {
		    @nodes = $doc->findnodes("/profile/service_profile/prop");
		    $type  = 'service profile';
		}
		else {
		    my @service_names = $doc->findnodes("/profile/service_name");
		    if (@service_names) {
			@nodes = $doc->findnodes("/profile/service_name/prop");
			$type  = 'service';
		    }
		}
	    }
	    foreach my $node (@nodes) {
		if ( $node->hasAttributes() ) {
		    my $property = $node->getAttribute('name');
		    my $value    = $node->textContent;
		    $value =~ s/\s+$|\n//g;
		    if ( $property eq 'description' ) {
			$properties{$property} = $value;
		    }
		    elsif ( $property eq 'name' && not defined $properties{description} ) {
			$properties{'description'} = "\"$value\" $type";
		    }
		}
	    }
	}
    }
    else {
	my ($package, $file, $line) = caller;
	$properties{'error'} = "Empty String (parse_profile_xml); called from $file line $line.";
    }
    return %properties;
}

sub fetch_last(@) {
    my $table   = $_[1];
    my $sqlstmt = "select max(id) as lastrow from $table";
    my $id      = $dbh->selectrow_array($sqlstmt);
    return $id;
}

sub fetch_one(@) {
    my $table      = $_[1];
    my $name       = $_[2];
    my $value      = $_[3];
    my $values     = undef;
    my %properties = ();
    $value = $dbh->quote($value);
    my $sqlstmt = "select * from $table where $name = $value";
    my $sth     = $dbh->prepare($sqlstmt);
    $sth->execute;
    $values = $sth->fetchrow_hashref();
    if ($values) {
	foreach my $key ( keys %{$values} ) {
	    ## See GWMON-8075.
	    if ( $key eq 'data' && defined( $values->{$key} ) && $values->{$key} ne '' && $table !~ /external/ ) {
		my %data = parse_xml( '', $values->{$key} );
		foreach my $k ( keys %data ) {
		    $properties{$k} = $data{$k};
		}
	    }
	    else {
		$properties{$key} = $values->{$key};
	    }
	}
    }
    $sth->finish;
    return %properties;
}

sub fetch_one_where(@) {
    my $table        = $_[1];
    my $where        = $_[2];
    my %where        = %{$where};
    my $where_clause = '';
    foreach my $name ( keys %where ) {
	unless ( $name =~ /^HASH(?:\(0x[0-9A-Fa-f]+\))?$/ ) {
	    if ( $name eq 'data' ) {
		my $like = '%[CDATA[' . $where{$name} . ']]%';
		$like = $dbh->quote($like);
		$where_clause .= " $name like $like and";
	    }
	    else {
		$where{$name} = $dbh->quote( $where{$name} );
		$where_clause .= " $name = $where{$name} and";
	    }
	}
    }
    $where_clause =~ s/ and$//;
    my %properties = ();
    my $sqlstmt    = "select * from $table where $where_clause";

    ## print STDERR "in fetch_one_where() sql is [$sqlstmt]\n" if $debug;

    my $sth = undef;
    eval {
	$sth = $dbh->prepare($sqlstmt);
	$sth->execute;
    };
    if ($@) {
	log_caller( '', $sqlstmt, $@ );
	## FIX MAJOR:  we die here for now, to exacerbate and expose problems while we are
	## porting to PostgreSQL; perhaps later we should allow the process to proceed
	die "\n";
    }
    else {
	my $values = $sth->fetchrow_hashref();
	if ($values) {
	    foreach my $key ( keys %{$values} ) {
		## print STDERR "in fetch_one_where() key is [$key] and value is [$values->{$key}]\n" if $debug;
		if ( $key eq 'data' && defined( $values->{$key} ) && $values->{$key} ne '' && $table !~ /external/ ) {
		    my %data = parse_xml( '', $values->{$key} );
		    foreach my $k ( keys %data ) {
			$properties{$k} = $data{$k};
		    }
		}
		else {
		    $properties{$key} = $values->{$key};
		}
	    }
	}
    }
    $sth->finish;
    return %properties;
}

sub fetch_list(@) {
    my $table    = $_[1];
    my $list     = $_[2];
    my $orderby  = $_[3];
    my @values   = ();
    my @elements = ();
    if ($orderby) {
	$orderby = " order by $orderby";
    }
    else {
	$orderby = '';
    }
    my $sqlstmt = "select $list from $table$orderby";
    my $sth     = $dbh->prepare($sqlstmt);
    $sth->execute;

    while ( @values = $sth->fetchrow_array() ) {
	unless ( $values[0] eq '*' ) { push @elements, $values[0] }
    }
    $sth->finish;
    return @elements;
}

sub fetch_list_where(@) {
    my $table   = $_[1];
    my $list    = $_[2];
    my $where   = $_[3];
    my $orderby = $_[4];
    if ($orderby) {
	$orderby = " order by $orderby";
    }
    else {
	$orderby = '';
    }
    my %where        = %{$where};
    my $where_clause = '';
    foreach my $name ( keys %where ) {
	unless ( $name =~ /^HASH(?:\(0x[0-9A-Fa-f]+\))?$/ ) {
	    if ( $name eq 'data' ) {
		my $like = '%[CDATA[' . $where{$name} . ']]%';
		$like = $dbh->quote($like);
		$where_clause .= " $name like $like and";
	    }
	    else {
		$where{$name} = $dbh->quote( $where{$name} );
		$where_clause .= " $name = $where{$name} and";
	    }
	}
    }
    $where_clause =~ s/ and$//;
    my $sqlstmt = "select $list from $table where $where_clause$orderby";
    my $sth     = $dbh->prepare($sqlstmt);
    $sth->execute;
    my @elements = ();
    my @values   = ();
    while ( @values = $sth->fetchrow_array() ) {
	unless ( $values[0] eq '*' ) { push @elements, $values[0] }
    }
    $sth->finish;
    return @elements;
}

sub fetch_list_like(@) {
    my $table        = $_[1];
    my $list         = $_[2];
    my $where        = $_[3];
    my %where        = %{$where};
    my $where_clause = '';
    foreach my $name ( keys %where ) {
	unless ( $name =~ /^HASH(?:\(0x[0-9A-Fa-f]+\))?$/ ) {
	    my $like = '%' . $where{$name} . '%';
	    $like = $dbh->quote($like);
	    $where_clause .= " $name like $like and";
	}
    }
    $where_clause =~ s/ and$//;
    my $sqlstmt = "select $list from $table where $where_clause";
    my $sth     = $dbh->prepare($sqlstmt);
    $sth->execute;
    my @elements = ();
    my @values   = ();
    while ( @values = $sth->fetchrow_array() ) {
	push @elements, $values[0];
    }
    $sth->finish;
    return @elements;
}

sub fetch_list_start(@) {
    my $table = $_[1];
    my $list  = $_[2];
    my $name  = $_[3];
    my $value = $_[4];
    $value .= "%";
    $value = $dbh->quote($value);
    my $sqlstmt = "select $list from $table where $name like $value";
    my $sth     = $dbh->prepare($sqlstmt);
    $sth->execute;
    my @elements = ();
    while ( my @values = $sth->fetchrow_array() ) {
	push @elements, $values[0];
    }
    $sth->finish;
    return @elements;
}

sub fetch_distinct_list(@) {
    my $table    = $_[1];
    my $list     = $_[2];
    my @values   = ();
    my @elements = ();
    my $sqlstmt  = "select distinct $list from $table";
    my $sth      = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( @values = $sth->fetchrow_array() ) {
	push @elements, $values[0];
    }
    $sth->finish;
    return @elements;
}

sub fetch_unique(@) {
    my $table    = $_[1];
    my $list     = $_[2];
    my $object   = $_[3];
    my $value    = $_[4];
    my @values   = ();
    my @elements = ();
    $value = $dbh->quote($value);
    my $sqlstmt = "select $list from $table where $object = $value";
    my $sth     = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( @values = $sth->fetchrow_array() ) {
	push @elements, $values[0];
    }
    $sth->finish;
    return @elements;
}

# FIX LATER:  Certain other routines in this package might be defined in terms of fetch_map() and fetch_map_where().
sub fetch_map(@) {
    my $table = $_[1];
    my $key   = $_[2];
    my $value = $_[3];
    my %map   = ();
    my $sqlstmt = "select $key, $value from $table";
    my $sth     = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	$map{ $values[0] } = $values[1];
    }
    $sth->finish;
    return \%map;
}

sub fetch_map_where(@) {
    my $table = $_[1];
    my $key   = $_[2];
    my $value = $_[3];
    my $where = $_[4];
    my %where = %{$where};
    my @where = ();
    foreach my $name ( keys %where ) {
	unless ( $name =~ /^HASH(?:\(0x[0-9A-Fa-f]+\))?$/ ) {
	    push @where,
	      $name eq 'data'
	      ? "$name like " . $dbh->quote( '%[CDATA[' . $where{$name} . ']]%' )
	      : "$name = " . $dbh->quote( $where{$name} );
	}
    }
    my %map     = ();
    my $sqlstmt = "select $key, $value from $table where " . join( ' and ', @where );
    my $sth     = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	$map{ $values[0] } = $values[1];
    }
    $sth->finish;
    return \%map;
}

# Unstable interface, subject to change across releases.
# Once we feel comfortable with the function signature, this will be stabilized and become
# available for wider use.  A companion fetch_fields_where() routine may also be defined.
# Certain other routines in this package might then be defined in terms of these routines.
# FIX LATER:  possibly extend this to pull apart a "data" column if it appears in the table,
# or provide a separate fetch_properties() routine
sub fetch_fields(@) {
    my $table   = $_[1];
    my $key     = $_[2];
    my @fields  = @_[3..$#_];
    my %fields  = ();
    my $sqlstmt = "select $key, " . (join( ', ', @fields )) . " from $table";
    my $sth     = $dbh->prepare($sqlstmt);
    $sth->execute;
    my $index = undef;
    while ( my @values = $sth->fetchrow_array() ) {
	$index = shift @values;
	for (my $i = 0; $i <= $#values; ++$i) {
	    $fields{$index}{ $fields[$i] } = $values[$i];
	}
    }
    $sth->finish;
    return \%fields;
}

sub fetch_list_hash_array(@) {
    my $table        = $_[1];
    my $where        = $_[2];
    my %where        = %{$where};
    my %elements     = ();
    my $where_clause = '';
    foreach my $name ( keys %where ) {
	unless ( $name =~ /^(?:HASH(?:\(0x[0-9A-Fa-f]+\))?)|NONE$/ ) {
	    $where{$name} = $dbh->quote( $where{$name} );
	    $where_clause .= " $name = $where{$name} and";
	}
    }
    if ($where_clause) {
	$where_clause =~ s/ and$//;
	$where_clause = " where $where_clause";
    }
    else {
	$where_clause = '';
    }
    my $sqlstmt = "select * from $table$where_clause";
    my $sth     = undef;
    eval {
	$sth = $dbh->prepare($sqlstmt);
	$sth->execute;
    };
    if ($@) {
	$elements{'error'} = "Error: $@";
	log_caller('', $sqlstmt, $@);
    }
    else {
	while ( my @values = $sth->fetchrow_array() ) {
	    $elements{ $values[0] } = [@values];
	}
    }
    $sth->finish;
    return %elements;
}

# same as fetch_list_hash_array but uses a generated key, useful to dump associative tables
sub fetch_hash_array_generic_key(@) {
    my $table        = $_[1];
    my $where        = $_[2];
    my %where        = %{$where};
    my %elements     = ();
    my $where_clause = '';
    foreach my $name ( keys %where ) {
	unless ( $name =~ /^(?:HASH(?:\(0x[0-9A-Fa-f]+\))?)|NONE$/ ) {
	    $where{$name} = $dbh->quote( $where{$name} );
	    $where_clause .= " $name = $where{$name} and";
	}
    }
    if ($where_clause) {
	$where_clause =~ s/ and$//;
	$where_clause = " where $where_clause";
    }
    else {
	$where_clause = '';
    }
    my $sqlstmt = "select * from $table$where_clause";
    my $sth     = undef;
    eval {
	$sth = $dbh->prepare($sqlstmt);
	$sth->execute;
    };
    if ($@) {
	$elements{'error'} = "Error: $@";
	log_caller('', $sqlstmt, $@);
    }
    else {
	my $key = 1;
	while ( my @values = $sth->fetchrow_array() ) {
	    $elements{$key} = [@values];
	    $key++;
	}
    }
    $sth->finish;
    return %elements;
}

# FIX MAJOR:  Is this the correct prototype?
sub fetch_all($) {
    my $table    = $_[1];
    my %elements = ();
    my @values   = ();
    my $sqlstmt  = "select * from $table";
    my $sth      = undef;
    eval {
	$sth = $dbh->prepare($sqlstmt);
	$sth->execute;
    };
    if ($@) {
	$elements{'error'} = "Error: $@";
	log_caller('', $sqlstmt, $@);
    }
    else {
	while ( @values = $sth->fetchrow_array() ) {
	    $elements{ $values[0] } = [@values];
	}
    }
    $sth->finish;
    return %elements;
}

sub insert_obj(@) {
    my $table  = $_[1];
    my $values = $_[2];
    my @values = @{$values};
    my $valstr = '';
    foreach my $val (@values) {
	if (ref $val) {
	    if (not defined $$val) {
		$val = 'DEFAULT';
	    }
	    elsif ($$val eq $DEFINED) {
		$val = "'0'";
	    }
	    else {
		my ($package, $file, $line) = caller;
		return "Error: invalid value reference found in call from $file line $line.";
	    }
	}
	else {
	    unless ($val) { $val = 'NULL' }
	    $val =~ s/^\s*(.*?)\s*$/$1/ if $table =~ /host/;
	    unless ( $val eq 'NULL' ) { $val = $dbh->quote($val) }
	}
	$valstr .= "$val,";
    }
    chop $valstr;

    if ( $table eq 'service_instance' && $values[2] eq 'NULL' ) {
	print STDERR "warning: attempted to insert record with column 'name' value of NULL into service_instance\n" if $debug;
	# my ($package, $file, $line) = caller;
	# print "Warning: attempted to insert record with column 'name' value of NULL into service_instance; values($valstr); called from $file line $line<br>";
	return 1;
    }

    if ( my $fields = table_enforce_uniqueness($table) ) {
	my $offset = 0;
	my %where  = ();
	foreach my $field (@$fields) {
	    $where{$field} = $values[ $offset++ ];
	    $where{$field} =~ s/^\s*'(.*)'\s*$/$1/;    # prevent double quoting; fetch_one_where() will add quotes.
	}
	print STDERR "warning: more values than expected in table [$table]\n" if ( $debug && $values[$offset] );
	my %result = fetch_one_where( '', $table, \%where );
	if ( keys %result ) {
	    print STDERR "pre-existing record for [$valstr] found in table [$table]; extra insert prevented.\n" if $debug;
	    return 1;                                  # record with these values already exists; return immediately
	}
    }

    my $sqlstmt = "insert into $table values($valstr)";
    print STDERR "in insert_obj() sql is [$sqlstmt]\n" if $debug;
    # Unlike in insert_obj_id(), I haven't yet seen an actual failure to process 8-bit chars correctly
    # without utf::downgrade() applied here, but it seems like it can't hurt to invoke it here as well,
    # given that we should only be carrying around ISO-8859-1 characters internally.
    if (not utf8::downgrade($sqlstmt,1)) {
	my ($package, $file, $line) = caller;
	return "Error: UTF-8 downgrade failed in call from $file line $line.";
    }
    my $sth = undef;
    eval {
	$sth = $dbh->prepare($sqlstmt);
	$sth->execute;
    };
    if ($@) {
	$sth->finish;
	log_caller('', $sqlstmt, $@);
	chomp $@;
	my ($package, $file, $line) = caller;
	return "Error: $sqlstmt ($@) called from $file line $line.";
    }
    else {
	$sth->finish;
	return 1;
    }
}

sub insert_obj_id(@) {
    my $table  = $_[1];
    my $values = $_[2];
    my $id     = $_[3];
    my @values = @{$values};
    my $valstr = '';
    foreach my $val (@values) {
	if (ref $val) {
	    if (not defined $$val) {
		$val = 'DEFAULT';
	    }
	    elsif ($$val eq $DEFINED) {
		$val = "'0'";
	    }
	    else {
		my ($package, $file, $line) = caller;
		return "Error: invalid value reference found in call from $file line $line.";
	    }
	}
	else {
	    unless ($val) { $val = 'NULL' }
	    $val =~ s/^\s*(.*?)\s*$/$1/ if $table =~ /host/;
	    unless ( $val eq 'NULL' ) { $val = $dbh->quote($val) }
	}
	$valstr .= "$val,";
    }
    chop $valstr;

#   Uncomment this if duplicate key errors are encountered and are traced to this subroutine.
#   So far we only have records of such errors happening in insert_obj(), not insert_obj_id().
#   If it turns out this code is needed, check the TODO item below before using.
#
#	if (my $fields = table_enforce_uniqueness($table)) {
#		if ($debug) {
#			my $debug_string = "insert_obj_id(): enforcing uniqueness for table [$table] with fields " . join(":", @$fields) . " and values " . join(":", @values);
#			print STDERR "$debug_string\n" if $debug;
#		}
#		my $offset = 0;
#		my $where = 'where';
#		foreach my $field (@$fields) {
# TODO: check whether single quotes in next line are redundant
#			$where .= " $field = '$values[$offset++]' and";
#		}
#		$where =~ s/ and$//;
#		print STDERR "warning: more values than expected in table [$table]\n" if ($debug && $values[$offset]);
#		my $sqlstmt = "select max($id) as lastrow from $table $where";
#		my $id = $dbh->selectrow_array($sqlstmt);
#		if ($id ne 'NULL') {
#			print STDERR "pre-existing record for [$valstr] found in table [$table]; extra insert prevented.\n" if $debug;
#			return $id;
#		}
#	}

    my $sqlstmt = "insert into $table values($valstr)";
    if ( defined($dbtype) && $dbtype eq 'postgresql' ) {
	## avoid race conditions
	$sqlstmt .= " returning $id";
    }
    if (not utf8::downgrade($sqlstmt,1)) {
	my ($package, $file, $line) = caller;
	return "Error: UTF-8 downgrade failed in call from $file line $line.";
    }
    my $sth      = undef;
    my $id_value = undef;
    eval {
	$sth = $dbh->prepare($sqlstmt);
	$sth->execute;
    };
    if ($@) {
	$sth->finish;
	log_caller('', $sqlstmt, $@);
	chomp $@;
	my ($package, $file, $line) = caller;
	return "Error: $sqlstmt ($@) called from $file line $line.";
    }
    else {
	if ( defined($dbtype) && $dbtype eq 'postgresql' ) {
	    $id_value = $sth->fetchrow_arrayref()->[0];
	}
	else {
	    $sth->finish;
	    ## unsafe -- subject to race conditions; should use last_insert_id() instead
	    $sqlstmt = "select max($id) as lastrow from $table";
	    $id_value = $dbh->selectrow_array($sqlstmt);
	}
	$sth->finish;
	return $id_value;
    }
}

sub update_obj(@) {
    my $table  = $_[1];
    my $name   = $_[2];
    my $obj    = $_[3];
    my $values = $_[4];
    my %values = %{$values};
    my $valstr = '';
    $obj = $dbh->quote($obj);
    foreach my $key ( keys %values ) {
	unless ( $key =~ /^HASH(?:\(0x[0-9A-Fa-f]+\))?$/ ) {
	    if (ref $values{$key}) {
		if (${$values{$key}} eq $DEFINED) {
		    $values{$key} = "'0'";
		}
		else {
		    my ($package, $file, $line) = caller;
		    return "Error: invalid value reference found in call from $file line $line.";
		}
	    }
	    else {
		unless ( $values{$key} ) { $values{$key} = 'NULL' }
		unless ( $values{$key} eq 'NULL' ) {
		    $values{$key} = $dbh->quote( $values{$key} );
		}
	    }
	    $valstr .= "$key = $values{$key},";
	}
    }
    chop $valstr;
    my $sqlstmt = "update $table set $valstr where $name = $obj";
    if (not utf8::downgrade($sqlstmt,1)) {
	my ($package, $file, $line) = caller;
	return "Error: UTF-8 downgrade failed in call from $file line $line.";
    }
    my $sth = undef;
    my $rv  = 0;
    eval {
	$sth = $dbh->prepare($sqlstmt);
	$rv = $sth->execute;
    };
    if ($@) {
	$sth->finish;
	log_caller('', $sqlstmt, $@);
	chomp $@;
	my ($package, $file, $line) = caller;
	return "Error: $sqlstmt ($@) called from $file line $line.";
    }
    else {
	$sth->finish;
	# We return the number of rows updated.  This value is always "true", even when zero (see the DBI doc).
	return $rv;
    }
}

sub update_obj_where(@) {
    my $table  = $_[1];
    my $values = $_[2];
    my $where  = $_[3];
    my %values = %{$values};
    my %where  = %{$where};
    my $valstr = '';
    foreach my $key ( keys %values ) {
	unless ( $key =~ /^HASH(?:\(0x[0-9A-Fa-f]+\))?$/ ) {
	    if (ref $values{$key}) {
		if (${$values{$key}} eq $DEFINED) {
		    $values{$key} = "'0'";
		}
		else {
		    my ($package, $file, $line) = caller;
		    return "Error: invalid value reference found in call from $file line $line.";
		}
	    }
	    else {
		unless ( $values{$key} ) { $values{$key} = 'NULL' }
		unless ( $values{$key} eq 'NULL' ) {
		    $values{$key} = $dbh->quote( $values{$key} );
		}
	    }
	    $valstr .= "$key = $values{$key},";
	}
    }
    chop $valstr;
    my $where_clause = '';
    foreach my $name ( keys %where ) {
	unless ( $name =~ /^HASH(?:\(0x[0-9A-Fa-f]+\))?$/ ) {
	    my $val = $dbh->quote( $where{$name} );
	    $where_clause .= " $name = $val and";
	}
    }
    $where_clause =~ s/ and$//;
    my $sqlstmt = "update $table set $valstr where $where_clause";
    my $sth     = undef;
    my $rv      = 0;
    eval {
	$sth = $dbh->prepare($sqlstmt);
	$rv = $sth->execute;
    };
    if ($@) {
	$sth->finish;
	log_caller('', $sqlstmt, $@);
	chomp $@;
	my ($package, $file, $line) = caller;
	return "Error: $sqlstmt ($@) called from $file line $line.";
    }
    else {
	$sth->finish;
	return $rv;
    }
}

sub delete_all(@) {
    my $table = $_[1];
    my $name  = $_[2];
    my $obj   = $_[3];
    $obj = $dbh->quote($obj);
    my $sqlstmt = "delete from $table where $name = $obj";
    my $sth     = undef;
    eval {
	$sth = $dbh->prepare($sqlstmt);
	$sth->execute;
    };
    if ($@) {
	$sth->finish;
	log_caller('', $sqlstmt, $@);
	return "Error: $sqlstmt ($@)";
    }
    else {
	$sth->finish;
	return 1;
    }
}

sub delete_one_where(@) {
    my $table        = $_[1];
    my $where        = $_[2];
    my %where        = %{$where};
    my $where_clause = '';
    foreach my $name ( keys %where ) {
	unless ( $name =~ /^HASH(?:\(0x[0-9A-Fa-f]+\))?$/ ) {
	    if ( $name eq 'data' ) {
		my $like = '%[CDATA[' . $where{$name} . ']]%';
		$like = $dbh->quote($like);
		$where_clause .= " $name like $like and";
	    }
	    else {
		my $val = $dbh->quote( $where{$name} );
		$where_clause .= " $name = $val and";
	    }
	}
    }
    $where_clause =~ s/ and$//;
    my $sqlstmt = "delete from $table where $where_clause";
    my $sth     = undef;
    eval {
	$sth = $dbh->prepare($sqlstmt);
	$sth->execute;
    };
    if ($@) {
	$sth->finish;
	log_caller('', $sqlstmt, $@);
	return "Error: $sqlstmt ($@)";
    }
    else {
	$sth->finish;
	return 1;
    }
}

# FIX MAJOR:  Is this the correct prototype?
sub get_host_services_using_service_template($) {
    my $stid = $_[1];
    my %host_services = ();
    my $sqlstmt = "select s.service_id, h.name, sn.name from services s, hosts h, service_names sn
	where s.servicetemplate_id = $stid and h.host_id = s.host_id and sn.servicename_id = s.servicename_id";
    my $sth = undef;
    eval {
	$sth = $dbh->prepare($sqlstmt);
	$sth->execute;
    };
    if ($@) {
	$host_services{'error'} = "Error: $@";
	log_caller('', $sqlstmt, $@);
    }
    else {
	while ( my @values = $sth->fetchrow_array() ) {
	    $host_services{ $values[1] }{ $values[2] } = $values[0];
	}
    }
    $sth->finish;
    return \%host_services;
}

sub fetch_service(@) {
    my $sid        = $_[1];
    my @errors     = ();
    my $values     = undef;
    my %properties = ();
    my $sqlstmt    = "select * from services where service_id = '$sid'";
    my $sth        = undef;
    eval {
	$sth = $dbh->prepare($sqlstmt);
	$sth->execute;
	$values = $sth->fetchrow_hashref();
	foreach my $key ( keys %{$values} ) {
	    $properties{$key} = $values->{$key};
	}
    };
    if ($@) {
	push @errors, "$sqlstmt ($@)";
	log_caller('', $sqlstmt, $@);
    }
    $sth->finish if $sth;

    if (%properties) {
	$sqlstmt = "select name from service_names where servicename_id = '$properties{'servicename_id'}'";
	$properties{'service_name'} = $dbh->selectrow_array($sqlstmt);

	$sqlstmt = "select name from service_templates where servicetemplate_id = '$properties{'servicetemplate_id'}'";
	$properties{'template'} = $dbh->selectrow_array($sqlstmt);

	if ( defined $properties{'serviceextinfo_id'} ) {
	    $sqlstmt = "select name from extended_service_info_templates where serviceextinfo_id = '$properties{'serviceextinfo_id'}'";
	    $properties{'ext_info'} = $dbh->selectrow_array($sqlstmt);
	}

	if ( defined $properties{'escalation_id'} ) {
	    $sqlstmt = "select name from escalation_trees where tree_id = '$properties{'escalation_id'}'";
	    $properties{'escalation'} = $dbh->selectrow_array($sqlstmt);
	}

	if ( defined $properties{'check_command'} ) {
	    $sqlstmt = "select name from commands where command_id = '$properties{'check_command'}'";
	    $properties{'check_command'} = $dbh->selectrow_array($sqlstmt);
	}

	# GWMON-10409:  we used to populate 'dependency', but that was misleading, so we break compatibility here
	$sqlstmt = "select name from service_dependency_templates where id in "
	  . "(select template from service_dependency where service_id = '$sid')";
	$sth = undef;
	eval {
	    $sth = $dbh->prepare($sqlstmt);
	    $sth->execute;
	    my @deps   = ();
	    my @values = ();
	    while ( @values = $sth->fetchrow_array() ) {
		push @deps, $values[0];
	    }
	    $properties{'dependencies'} = \@deps;
	};
	if ($@) {
	    push @errors, "$sqlstmt ($@)";
	    log_caller('', $sqlstmt, $@);
	}
	$sth->finish if $sth;
    }
    else {
	push @errors, "Service ID \"$sid\" was not found.";
    }

    if (@errors) {
	$properties{'errors'} = @errors;
    }
    return %properties;
}

sub fetch_host_address(@) {
    ## get only address, given host name
    my $name    = $_[1];
    my $sqlstmt = "select address from hosts where name = '$name'";
    my $address = $dbh->selectrow_array($sqlstmt);
    return $address;
}

sub fetch_host(@) {
    my $name       = $_[1];
    my $by         = $_[2];
    my @errors     = ();
    my $values     = undef;
    my %properties = ();
    my $where      = 'name';
    if ( defined($by) && $by eq 'address' ) { $where = 'address' }
    my $sqlstmt = "select * from hosts where $where = '$name'";
    my $sth     = undef;
    eval {
	$sth = $dbh->prepare($sqlstmt);
	$sth->execute;
    };
    if ($@) {
	push @errors, "$sqlstmt ($@)";
	log_caller('', $sqlstmt, $@);
    }
    else {
	$values = $sth->fetchrow_hashref();
	foreach my $key ( keys %{$values} ) {
	    $properties{$key} = $values->{$key};
	}
    }
    $sth->finish;

    if (%properties) {
	if (defined $properties{'hosttemplate_id'}) {
	    $sqlstmt = "select name from host_templates where hosttemplate_id = '$properties{'hosttemplate_id'}'";
	    $properties{'template'} = $dbh->selectrow_array($sqlstmt);
	}
	else {
	    # FIX MINOR:  Should we do this?
	    # $properties{'template'} = undef;
	}

	# Host parent

	$sqlstmt = "select hosts.name from hosts left join host_parent on hosts.host_id = host_parent.parent_id "
	  . "where host_parent.host_id = '$properties{'host_id'}'";

	# FIX THIS:  this makes more sense:
	# $sqlstmt = "select hosts.name from hosts, host_parent "
	#   . "where host_parent.host_id = '$properties{'host_id'}' and hosts.host_id = host_parent.parent_id";

	$sth = $dbh->prepare($sqlstmt);
	$sth->execute;
	my @names = ();
	while ( my @values = $sth->fetchrow_array() ) { push @names, $values[0] }
	$sth->finish;
	$properties{'parents'} = [@names];

	# FIX THIS:
	# print STDERR "parents of $name are: @names\n";

	# Hostgroups
	$sqlstmt = "select hostgroups.name from hostgroups left join hostgroup_host "
	  . "on hostgroups.hostgroup_id = hostgroup_host.hostgroup_id where host_id = '$properties{'host_id'}'";
	$sth = $dbh->prepare($sqlstmt);
	$sth->execute;
	@names = ();
	while ( my @values = $sth->fetchrow_array() ) { push @names, $values[0] }
	$sth->finish;
	$properties{'hostgroups'} = [@names];

	if ( defined( $properties{'hostextinfo_id'} ) ) {
	    $sqlstmt = "select name from extended_host_info_templates where hostextinfo_id = '$properties{'hostextinfo_id'}'";
	    $properties{'ext_info'} = $dbh->selectrow_array($sqlstmt);
	}

	$sqlstmt = "select data from extended_info_coords where host_id = '$properties{'host_id'}'";
	my $data = $dbh->selectrow_array($sqlstmt);
	my %data = defined($data) ? parse_xml( '', $data ) : ();
	push @errors, delete $data{'error'} if defined $data{'error'};
	$properties{'coords2d'} = $data{'2d_coords'};
	$properties{'coords3d'} = $data{'3d_coords'};

	if ( defined( $properties{'host_escalation_id'} ) ) {
	    $sqlstmt = "select name from escalation_trees where tree_id = '$properties{'host_escalation_id'}'";
	    $properties{'host_escalation'} = $dbh->selectrow_array($sqlstmt);
	}

	if ( defined( $properties{'service_escalation_id'} ) ) {
	    $sqlstmt = "select name from escalation_trees where tree_id = '$properties{'service_escalation_id'}'";
	    $properties{'service_escalation'} = $dbh->selectrow_array($sqlstmt);
	}

	my %overrides = fetch_one( '', 'host_overrides', 'host_id', $properties{'host_id'} );
	if ( $overrides{'status'} ) {
	    foreach my $name ( keys %overrides ) {
		$properties{$name} = $overrides{$name};
	    }
	}
    }
    else {
	push @errors, "Host $where \"$name\" was not found.";
    }

    if (@errors) {
	$properties{'errors'} = \@errors;
    }

    return %properties;
}

# Unstable interface, subject to change across releases.
sub fetch_hosts_for_sync() {
    my @errors     = ();
    my %properties = ();
    my $sqlstmt    = undef;
    my $sth        = undef;
    my %parents    = ();

    $sqlstmt = "select host_parent.host_id, hosts.name from host_parent, hosts where hosts.host_id = host_parent.parent_id";
    eval {
	$sth = $dbh->prepare($sqlstmt);
	$sth->execute;
    };
    if ($@) {
	push @errors, "$sqlstmt ($@)";
	log_caller('', $sqlstmt, $@);
    }
    else {
	while ( my @values = $sth->fetchrow_array() ) {
	    push @{ $parents{ $values[0] } }, $values[1];
	}
    }
    $sth->finish;

    unless (@errors) {
	$sqlstmt = "select * from hosts";
	eval {
	    $sth = $dbh->prepare($sqlstmt);
	    $sth->execute;
	};
	if ($@) {
	    push @errors, "$sqlstmt ($@)";
	    log_caller('', $sqlstmt, $@);
	}
	else {
	    while ( my $row = $sth->fetchrow_hashref() ) {
		%{ $properties{ $$row{'name'} } } = ();
		my $props = $properties{ $$row{'name'} };
		# FIX THIS:  I don't think we need the host_id value.  Check MonarchAudit.pm to see if host_id is used anywhere.
		# $props->{'host_id'}        = $$row{'host_id'};
		$props->{'alias'}          = $$row{'alias'};
		$props->{'address'}        = $$row{'address'};
		$props->{'notes'}          = $$row{'notes'};
		$props->{'hostextinfo_id'} = $$row{'hostextinfo_id'};
		$props->{'parents'}        = defined( $parents{ $$row{'host_id'} } ) ? [ sort @{ $parents{ $$row{'host_id'} } } ] : [];
	    }
	}
	$sth->finish;
    }

    if (@errors) {
	$properties{'errors'} = \@errors;
    }

    return \%properties;
}

sub datetime() {
    my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) = localtime(time);
    $year += 1900;
    $mon++;
    if ( $mon  =~ /^\d{1}$/ ) { $mon  = "0" . $mon }
    if ( $mday =~ /^\d{1}$/ ) { $mday = "0" . $mday }
    if ( $hour =~ /^\d{1}$/ ) { $hour = "0" . $hour }
    if ( $min  =~ /^\d{1}$/ ) { $min  = "0" . $min }
    if ( $sec  =~ /^\d{1}$/ ) { $sec  = "0" . $sec }
    return "$year-$mon-$mday $hour:$min:$sec";
}

sub synchronized_preflight(@) {
    my $user_acct    = $_[1];
    my $nagios_ver   = $_[2];
    my $nagios_etc   = $_[3];
    my $nagios_bin   = $_[4];
    my $monarch_home = $_[5];
    my $group        = $_[6] || '';
    my $filter       = $_[7];
    my @results      = ();
    my $files        = [];
    my $in_progress_lock;
    my $errors;
    my $pids;
    my @errors;

    # We catch SIGTERM, SIGINT, and SIGQUIT so we can stop and clean up when we are asked nicely.
    local $SIG{INT}  = \&handle_exit_signal;
    local $SIG{QUIT} = \&handle_exit_signal;
    local $SIG{TERM} = \&handle_exit_signal;

    use MonarchLocks;

    $errors = Locks->open_and_lock( \*in_progress_lock, $Locks::in_progress_file, $Locks::EXCLUSIVE, $Locks::NON_BLOCKING );
    if (@$errors) {
	if (defined fileno \*in_progress_lock) {
	    my ($pid_errors, $pid_blocks, $pids) = Locks->get_blocking_pids( \*in_progress_lock, $Locks::in_progress_file, $Locks::EXCLUSIVE );
	    if (@$pid_blocks) {
		push @errors, 'Another load or pre-flight or commit operation is already in progress.';
		push @errors, @$pid_blocks;
	    }
	    push @errors, @$pid_errors;
	    Locks->close_and_unlock( \*in_progress_lock );
	}
	push @errors, @$errors;
	return \@errors, \@results, $files;
    }

    if ( @{ Locks->lock_file_exists( \*in_progress_lock, $Locks::in_progress_file ) } ) {
	Locks->close_and_unlock( \*in_progress_lock );
	push @errors, 'Another load or pre-flight or commit operation just completed; please re-try your operation if needed.';
	return \@errors, \@results, $files;
    }

    require MonarchFile;
    ( $files, $errors ) =
      Files->build_files( $user_acct, $group, 'preflight', '', $nagios_ver, $nagios_etc, "$monarch_home/workspace", '' );
    if ($main::shutdown_requested) {
	push @$errors, 'Pre-flight testing was interrupted before completion.';
    }
    unless ( @$errors ) {
	@results = StorProc->pre_flight_check( $nagios_bin, $monarch_home );
	Forms->filter_results( \@results ) if $filter;
    }

    Locks->unlink_and_close( \*in_progress_lock, $Locks::in_progress_file );

    return $errors, \@results, $files;
}

# This routine is strongly deprecated outside the context of interlocking with feeders.
# Use synchronized_preflight() instead.
sub pre_flight_check(@) {
    my $nagios_bin   = $_[1];
    my $monarch_home = $_[2];
    my @results      = ();
    my $results      = qx($nagios_bin/nagios -v -v $monarch_home/workspace/nagios.cfg 2>&1)
      or push @results,
      "Error(s) executing $nagios_bin/nagios -v -v $monarch_home/workspace/nagios.cfg ($!)";
    if ( $results =~ /Things look okay/i ) {
	if ($results =~ /Warning:/) {
	    push @results, "Success [but with Warning(s), shown below]:";
	}
	else {
	    push @results, "Success:";
	}
    }
    elsif ( $results =~ /Error:/i ) {
	push @results, '<h7>Error(s) occurred during processing; see below.</h7>';
    }
    my @res = split( /\n/, $results );
    if ($is_portal) {
	foreach my $msg (@res) {
	    if ( $msg =~ /Warning: Size of service_message struct/ ) {
		next;
	    }
	    elsif ( $msg =~ /Total Warnings: (\d+)/ ) {
		my $warnings = $1;
		$warnings-- unless ( $results =~ /^[\n\r]*Nagios(?: Core)? [345]\./ );
		push @results, "Total Warnings: $warnings";
	    }
	    else {
		push @results, $msg;
	    }
	}
    }
    else {
	push @results, @res;
    }
    return @results;
}

sub get_dir(@) {
    my $dir        = $_[1];
    my $includes   = $_[2];
    my $executable = $_[3];
    my $directory  = $_[4];
    my @includes   = @{$includes} if $includes;
    my @files      = ();
    if ( !opendir( DIR, $dir ) ) {
	push @files, "error: cannot open $dir to read ($!)";
    }
    else {
	$dir =~ s{/$}{};
	while ( my $file = readdir(DIR) ) {
	    if ( ( !$directory && -f "$dir/$file" ) || ( $directory && $file ne '.' && $file ne '..' && -d "$dir/$file" ) ) {
		if ( !$executable || -x "$dir/$file" ) {
		    push @files, $file;
		}
	    }
	}
	closedir(DIR);
    }
    if (@includes) {
	my @inc_files = ();
	foreach my $file (@files) {
	    foreach my $ext (@includes) {
		if ( $file =~ /$ext$/i ) { push @inc_files, $file }
	    }
	}
	@files = @inc_files;
    }
    return @files;
}

sub start_timing {
    my $time_ref = $_[1];
    if ($show_timing) {
	$$time_ref = Time::HiRes::time();
    }
}

sub capture_timing {
    my $timings_ref = $_[1];
    my $time_ref    = $_[2];
    my $task        = $_[3];
    my $period      = $_[4] || 'Phase';
    if ($show_timing) {
	my $endtime = Time::HiRes::time();
	my $elapsed_time = sprintf('%0.3f', $endtime - $$time_ref);
	push @$timings_ref, "$period:  $task took $elapsed_time seconds. [$$time_ref .. $endtime]";
	$$time_ref = $endtime;
    }
}

# Internal routine only.
sub handle_exit_signal {
    my $signame = shift;
    $main::shutdown_requested = 1;

    # FIX LATER
    # for developer debugging only
    # print "ERROR:  Received SIG$signame; aborting!\n";
}

# Internal routine only.
sub prepare_commit {
    my $errors    = $_[0];    # \@errors
    my $results   = $_[1];    # \@results
    my $timings   = $_[2];    # \@timings
    my $starttime = $_[3];    # \$starttime
    my $majortime = $_[4];    # \$majortime
    my $phasetime = $_[5];    # \$phasetime

    my $user_acct    = $_[6];
    my $nagios_ver   = $_[7];
    my $nagios_etc   = $_[8];
    my $nagios_bin   = $_[9];
    my $monarch_home = $_[10];
    my $filter       = $_[11];

    require MonarchFile;

    my ( $files, $file_errors, $time_ref ) =
      Files->build_files( $user_acct, '', 'preflight', '', $nagios_ver, $nagios_etc, "$monarch_home/workspace", '' );
    StorProc->capture_timing( $timings, $phasetime, 'file building' );

    push @$errors, @{$file_errors};
    push @$timings, @$time_ref;

    unless (@$errors) {
	@$results = StorProc->pre_flight_check( $nagios_bin, $monarch_home );
	StorProc->capture_timing( $timings, $phasetime, 'pre-flight' );
	StorProc->capture_timing( $timings, $majortime, 'Verification steps (file building and pre-flight)', 'Summary' );
	my $res_str = pop @$results;
	push @$results, $res_str;
	Forms->filter_results( $results ) if $filter;
	unless ( $res_str =~ /Things look okay/ ) {
	    push @$errors, @$results;
	    push @$errors, "\n";
	    push @$errors, "Make the necessary corrections and run pre flight check.";
	}
    }
}

# Internal routine only.
sub execute_commit {
    my $errors    = $_[0];    # \@errors
    my $results   = $_[1];    # \@results
    my $timings   = $_[2];    # \@timings
    my $starttime = $_[3];    # \$starttime
    my $majortime = $_[4];    # \$majortime
    my $phasetime = $_[5];    # \$phasetime
    local $_;

    my $user_acct    = $_[6];
    my $nagios_etc   = $_[7];
    my $monarch_home = $_[8];
    my $filter       = $_[9];
    my $backup_dir   = $_[10];
    my $annotation   = $_[11];
    my $lock         = $_[12];

    unless (@$errors) {
	my $res = Files->copy_files( "$monarch_home/workspace", $nagios_etc );
	StorProc->capture_timing( $timings, $phasetime, 'file copying' );
	if ( $res =~ /Error/ ) { push @$errors, $res }
    }
    unless (@$errors) {
	my $res = Files->rewrite_nagios_cfg( "$monarch_home/workspace", $nagios_etc );
	StorProc->capture_timing( $timings, $phasetime, 'file rewriting' );
	if ( defined($res) && $res =~ /Error/ ) { push @$errors, $res }
    }
    if ($main::shutdown_requested) {
	push @$errors, 'Shutdown has been requested; Commit has been aborted!';
    }
    unless (@$errors) {
	my ( $time_ref, $commit_results ) = StorProc->timed_commit( $monarch_home, $nagios_etc, $backup_dir, $user_acct, $annotation, $lock );
	push @$timings, @$time_ref;
	my $got_commit_errors = 0;
	foreach (@$commit_results) {
	    if (/error/i) {
		if ( $filter && !/<h7>/ ) {
		    $_ = '<h7>' . $_ . '</h7>';
		}
		$got_commit_errors = 1;
	    }
	}
	if ($got_commit_errors) {
	    unshift( @$results, ( $filter ? '<h7>' : '' ) . 'Error(s) occurred during processing; see below.' . ( $filter ? '</h7>' : '' ) );
	}
	push @$results, @$commit_results;
	StorProc->capture_timing( $timings, $majortime, 'File install, Nagios reload, Monarch backup, Foundation sync, and Callout submit', 'Summary' );
	StorProc->capture_timing( $timings, $starttime, 'Full commit, including all phases,', 'Summary' );
	if ($main::shutdown_requested) {
	    push @$errors, 'Shutdown has been requested; Commit has been aborted!';
	}
    }
}

sub synchronized_commit(@) {
    my $user_acct    = $_[1];
    my $nagios_ver   = $_[2];
    my $nagios_etc   = $_[3];
    my $nagios_bin   = $_[4];
    my $monarch_home = $_[5];
    my $filter       = $_[6];
    my $backup_dir   = $_[7];
    my $annotation   = $_[8];
    my $lock         = $_[9];

    return synchronized_action(
	\&prepare_commit, [ $user_acct, $nagios_ver, $nagios_etc, $nagios_bin, $monarch_home, $filter ],
	\&execute_commit, [ $user_acct, $nagios_etc, $monarch_home, $filter, $backup_dir, $annotation, $lock ]
    );
}

# Internal routine only.
sub synchronized_action(@) {
    my $prepare      = $_[0];
    my $prepare_args = $_[1] || [];
    my $execute      = $_[2];
    my $execute_args = $_[3] || [];
    my $in_progress_lock;
    my $commit_lock;
    my $errors;
    my $pids;
    my $shutdown_message = 'Shutdown requested; will exit.';
    my @errors           = ();
    my @results          = ();
    my @timings          = ();

    # We catch SIGTERM, SIGINT, and SIGQUIT so we can stop and clean up when we are asked nicely.
    local $SIG{INT}  = \&handle_exit_signal;
    local $SIG{QUIT} = \&handle_exit_signal;
    local $SIG{TERM} = \&handle_exit_signal;

    use MonarchLocks;

    $errors = Locks->open_and_lock( \*in_progress_lock, $Locks::in_progress_file, $Locks::EXCLUSIVE, $Locks::NON_BLOCKING );
    if (@$errors) {
	my @blocking_errors = ();
	if (defined fileno \*in_progress_lock) {
	    my ($pid_errors, $pid_blocks, $pids) = Locks->get_blocking_pids( \*in_progress_lock, $Locks::in_progress_file, $Locks::EXCLUSIVE );
	    if (@$pid_blocks) {
		push @blocking_errors, 'Another backup, restore, load, pre-flight, or commit operation is already in progress.';
		push @blocking_errors, 'Underlying detail:' if @$pid_blocks || @$pid_errors;
		push @blocking_errors, @$pid_blocks;
	    }
	    push @blocking_errors, @$pid_errors;
	    Locks->close_and_unlock( \*in_progress_lock );
	}
	push @errors, @blocking_errors;
	push @errors, @$errors if !@blocking_errors;  # excessive detail
	return \@errors, \@results, \@timings;
    }

    if ( @{ Locks->lock_file_exists( \*in_progress_lock, $Locks::in_progress_file ) } ) {
	Locks->close_and_unlock( \*in_progress_lock );
	push @errors, 'Another backup, restore, load, pre-flight, or commit operation just completed; please re-try your operation if needed.';
	return \@errors, \@results, \@timings;
    }

    my $starttime;
    my $majortime;
    my $phasetime;

    StorProc->start_timing( \$starttime );
    $majortime = $starttime;
    $phasetime = $starttime;

    &$prepare( \@errors, \@results, \@timings, \$starttime, \$majortime, \$phasetime, @$prepare_args ) if $prepare;

    if (@errors) {
	Locks->unlink_and_close( \*in_progress_lock, $Locks::in_progress_file );
	return \@errors, \@results, \@timings;
    }

    if ($main::shutdown_requested) {
	Locks->unlink_and_close( \*in_progress_lock, $Locks::in_progress_file );
	push @errors, $shutdown_message;
	return \@errors, \@results, \@timings;
    }

    for ( my $lock_attempts = 1; $lock_attempts <= $max_commit_lock_attempts; ++$lock_attempts ) {
	$errors = Locks->open_and_lock( \*commit_lock, $Locks::commit_lock_file, $Locks::EXCLUSIVE, $Locks::NON_BLOCKING );
	last if !@$errors;
	my @blocking_errors = ();
	my $pid_errors;
	my $pid_blocks;
	my $pids = [];
	if (defined fileno \*commit_lock) {
	    ($pid_errors, $pid_blocks, $pids) = Locks->get_blocking_pids( \*commit_lock, $Locks::commit_lock_file, $Locks::EXCLUSIVE );
	    if (@$pid_blocks) {
		push @blocking_errors, 'Feeders are still operating.';
		push @blocking_errors, 'Underlying detail:' if @$pid_blocks || @$pid_errors;
		push @blocking_errors, @$pid_blocks;
	    }
	    push @blocking_errors, @$pid_errors;
	    Locks->close_and_unlock( \*commit_lock );
	}

	if ($lock_attempts >= $max_commit_lock_attempts) {
	    push @errors, @blocking_errors;
	    push @errors, @$errors if !@blocking_errors;  # excessive detail
	    Locks->unlink_and_close( \*in_progress_lock, $Locks::in_progress_file );
	    StorProc->capture_timing( \@timings, \$phasetime, 'waiting for synchronization file lock' );
	    return \@errors, \@results, \@timings;
	}
	else {
	    ## Uncomment the following lines to identify feeders that refuse to quickly release their locks.
	    ## push @errors, "Lock attempt $lock_attempts:";
	    ## push @errors, @blocking_errors;
	    ## ## push @errors, @$errors;
	}

	kill( 'TERM', @$pids ) if @$pids;
	sleep 3;
	if ($main::shutdown_requested) {
	    Locks->unlink_and_close( \*in_progress_lock, $Locks::in_progress_file );
	    push @errors, $shutdown_message;
	    StorProc->capture_timing( \@timings, \$phasetime, 'waiting for synchronization file lock' );
	    return \@errors, \@results, \@timings;
	}
    }

    utime undef, undef, $Locks::commit_lock_file;
    StorProc->capture_timing( \@timings, \$phasetime, 'waiting for synchronization file lock' );

    &$execute( \@errors, \@results, \@timings, \$starttime, \$majortime, \$phasetime, @$execute_args ) if $execute;

    Locks->close_and_unlock( \*commit_lock );
    Locks->unlink_and_close( \*in_progress_lock, $Locks::in_progress_file );

    return \@errors, \@results, \@timings;
}

# This routine is strongly deprecated outside the context of interlocking with feeders.
# Use synchronized_commit() instead.
sub timed_commit(@) {
    my $monarch_home = $_[1];
    my $nagios_etc   = $_[2];
    my $backup_dir   = $_[3];
    my $user_acct    = $_[4];
    my $annotation   = $_[5];
    my $lock         = $_[6];
    my @results      = ();
    my @timings      = ();
    my $phasetime;
    my $pre_restart_time;
    my $nagios_results;

    start_timing( '', \$phasetime );

    $pre_restart_time = time() - 1;

    # FIX LATER:  possibly rework to overlap the nagios_reload activity with the Audit stuff currently going on within FoundationSync

    $nagios_results = qx($monarch_home/bin/nagios_reload 2>&1);
    push @results, "Error executing $monarch_home/bin/nagios_reload (" . wait_status_message($?) . ")."
      if $? || $nagios_results !~ m{.*Starting nagios: done\.$}si;
    push @results, split( /\n/, $nagios_results );
    capture_timing( '', \@timings, \$phasetime, 'nagios reload' );

    if ( $nagios_results =~ m{.*Starting nagios: done\.$}si ) {
	push @results, "Good. Changes accepted by Nagios.";
	my $time_ref;
	my $sync_results = '';

	# FIX LATER:  Perhaps augment the passed-in annotation with top-level summary information
	# about the numbers of changed objects:  added hosts, deleted hosts, hostgroup membership
	# count changes, etc.  (That would require running the audit phase before doing the backup.)
	my ( $full_backup_dir, $errors ) = StorProc->backup( $nagios_etc, $backup_dir, $user_acct, $annotation, $lock );
	if (@$errors) {
	    push @results, @$errors;
	    push @results, "No Monarch backup was created, due to errors shown above.";
	}
	else {
	    my $results;
	    push @results, "Created Monarch backup in:  $full_backup_dir";
	    ( $errors, $results ) = StorProc->delete_excess_backups($backup_dir);
	    push @results, @$errors;
	    push @results, @$results;
	}
	capture_timing( '', \@timings, \$phasetime, 'Monarch backup management' );

	if ($is_portal) {
	    use MonarchFoundationSync;

	    # FIX LATER
	    # Run the Monarch/Foundation sync, with appropriate timeouts on waits for internal phases to complete.
	    # On phase wait timeout:
	    #     Issue error messages ("Error: Foundation is taking too long to process changes; Commit has been aborted!")
	    #         to the log and to the UI or controlling script error stream.  (FIX LATER:  Compare whatever message we
	    #         actually generate within FoundationSync->sync() with whatever message we generate in the caller.)
	    #     Abort further phase processing.
	    # On shutdown requested during sync:
	    #     Issue error messages ("Error: Shutdown has been requested; Commit has been aborted!")
	    #         to the log and to the UI or controlling script error stream.
	    #     Abort further phase processing.

	    ( $time_ref, $sync_results ) = FoundationSync->sync( undef, $pre_restart_time );
	    push @timings, @$time_ref;
	    push @results, $sync_results;
	    capture_timing( '', \@timings, \$phasetime, 'Audit and Foundation sync' );
	}
	if ( $sync_results =~ /error/i ) {
	    push @results, 'Warning:  Callout submit function was not called due to error(s) above.';
	}
	elsif ($main::shutdown_requested) {
	    push @results, 'Warning:  Callout submit function was not called because early shutdown was requested.';
	}
	else {
	    eval {
		require MonarchCallOut;
	    };
	    if ($@) {
		push @results, 'Error:  Callout submit function was not called because it could not be loaded:';
		push @results, $@;
	    }
	    else {
		my $callout_results = CallOut->submit($monarch_home);
		push @results, $callout_results if defined $callout_results;
		capture_timing( '', \@timings, \$phasetime, 'Callout submit' );
	    }
	}
    }

    if ( join( '', @results ) =~ /error/i ) {
	$annotation = 'Monarch commit failed.';
    }
    else {
	$annotation = '' if not defined $annotation;
	## Limit to what will fit in the database.
	$annotation = substr( $annotation, 0, 4095 );
	chomp $annotation;
    }
    require MonarchFoundationREST;
    my %audit_entry = (
	subsystem   => 'Monarch',
	hostName    => $dbhost,
	action      => 'SYNC',
	description => $annotation || 'Monarch commit completed successfully.',
	username    => $user_acct || 'unknown user'
    );
    FoundationREST->create_audit_entries( undef, undef, [ \%audit_entry ] );

    return \@timings, \@results;
}

# This routine is strongly deprecated, as it has no interlocking with feeders.
# Use synchronized_commit() instead.
sub commit(@) {
    my ($time_ref, $results) = timed_commit(@_);
    return @$results;
}

sub upload(@) {
    my $upload     = $_[1];
    my $filename   = $_[2];
    my $saved_file = $_[3];
    my $validator  = $_[4];
    my @errors     = ();
    my @filedata   = ();
    my $filedata   = '';
    my $bytes_read = undef;

    if ( !defined($filename) || $filename eq '' ) {
	push @errors, qq(Error: no file was selected for upload.);
    }
    elsif ( !defined( fileno $filename )) {
	push @errors, "File uploading is disabled.";
    }

    unless (@errors) {
	# Sanity check for our own protection.
	if ( ( stat $filename )[7] > 1000000 ) {
	    push @errors, qq(Error: Uploaded file "$filename" is too large.);
	}
    }

    unless (@errors) {
	while ( $bytes_read = read( $filename, $filedata, 8192 ) ) {
	    push @filedata, $filedata;
	}
	if ( !defined($bytes_read) ) {
	    push @errors, qq(Error: cannot upload file "$filename" ($!));
	}
	else {
	    $filedata = join( '', @filedata );
	    ## dos 2 unix conversion
	    $filedata =~ s/\r\n/\n/g;
	    if ( length($filedata) == 0 ) {
		push @errors, qq(Error: cannot upload file "$filename" (nonexistent or empty file));
	    }
	}
    }

    unless ( @errors || !$validator ) {
	my $error = &$validator ($filename, $filedata);
	push @errors, $error if $error;
    }

    unless ( @errors || !$saved_file ) {
	use Sys::Hostname;
	my $host = hostname();
	$host =~ s/\..*//;

	# Note that this will attempt to overwrite any existing file of the same name, which is
	# to say we're not getting the effect of the (O_CREAT | O_EXCL) flags on a sysopen() call.
	if ( !open( my $upfile, '>', $saved_file ) ) {
	    push @errors, qq(Error: cannot open "$host:$saved_file" for writing ($!));
	}
	else {
	    chmod 0644, $upfile;
	    binmode $upfile;
	    print $upfile $filedata;
	    close $upfile;
	    my $filesize = ( stat $saved_file )[7];
	    if ( $filesize <= 0 ) {
		push @errors, qq(Error: cannot upload file "$filename" to "$host:$saved_file" (nonexistent or empty file).);
	    }
	    elsif ( $filesize != length($filedata) ) {
		push @errors, qq(Error: cannot upload file "$filename" to "$host:$saved_file" (i/o error).);
	    }
	    unlink($saved_file) if @errors;
	}
    }

    return $filedata, \@errors;
}

sub parse_file(@) {
    my $file      = $_[1];
    my $delimiter = $_[2];
    my $name_pos  = $_[3];
    my %file_data = ();
    unless ($name_pos) { $name_pos = 0 }
    my $i = 1;
    if ( !open( FILE, '<', $file ) ) {
	$file_data{'error'} = "Error: cannot open $file for reading ($!)";
    }
    else {
	while ( my $line = <FILE> ) {
	    unless ( $line =~ /\S+/ ) { next }
	    if ( $delimiter eq 'tab' && $line !~ /\t/ ) {
		next;
	    }
	    elsif ( $line !~ /$delimiter/ ) {
		next;
	    }
	    unless ( $file_data{'line_1'} ) { $file_data{'line_1'} = $line }
	    if ($delimiter) {
		my @fields = split( /$delimiter/, $line );
		if ( $delimiter eq 'tab' ) { @fields = split( /\t/, $line ) }
		$file_data{ $fields[$name_pos] } = $line;
	    }
	    else {
		$file_data{$i} = $line;
		$i++;
	    }
	}
	close(FILE);
    }
    return %file_data;
}

sub process_schema() {
    my $userid   = $_[1];
    my $filename = $_[2];
    my $schema   = $_[3];
    my @errors   = ();
    my %schema   = fetch_one( '', 'import_schemas', 'name', $schema );
    $schema{'host'}--;
    $schema{'alias'}--;
    $schema{'address'}--;
    $schema{'os'}--;
    $schema{'service'}--;
    $schema{'info'}--;
    my ( $service, $host,    $services, $hosts )    = undef;
    my ( $os,      $address, $hostname, $got_host ) = undef;
    my @services = ();
    my @lines    = ();

    if ( !open( FILE, '<', $filename ) ) {
	push @errors, "error: cannot open $filename to read ($!)";
    }
    else {
	while ( my $line = <FILE> ) {
	    $line =~ s/\"//g;
	    push @lines, $line;
	}
	close(FILE);
    }
    push @lines, 'EOF';
    foreach my $line (@lines) {
	my @values = split( /$schema{'field_separator'}/, $line );
	if ( $values[ $schema{'host'} ] eq $hostname ) {
	    my $svc = $values[ $schema{'service'} ];
	    $svc =~ s/^\s+|\s+$//g;
	    my $info = $values[ $schema{'info'} ];
	    $info =~ s/^\s+|\s+$//g;
	    my %service = (
		service => $svc,
		info    => $info
	    );
	    push @services, {%service};
	    $got_host = 1;
	}
	else {
	    if ( $got_host || $line eq 'EOF' ) {
		if ( !$os ) { $os = "nomatch" }
		my @host_vals = split( /\./, $hostname );
		my $name      = shift @host_vals;
		my $alias     = $hostname;
		if ( !$name ) { $name = $address }
		my @host_values = ( $name, $userid, 'import', '0', $alias, $address, $os, '', '', '', '' );
		my $result = insert_obj( '', 'stage_hosts', \@host_values );
		if ( $result =~ /Error/ ) {
		    push @errors, $result;
		}
		else {
		    for my $i ( 0 .. $#services ) {
			my @service_values = ( $services[$i]{'service'}, $userid, $name, 'import', '0', 'NULL' );
			$result = insert_obj( '', 'stage_host_services', \@service_values );
			if ( $result =~ /Error/ ) { push @errors, $result }
		    }
		}
		@services = ();
		$os       = undef;
		$address  = undef;
		$host     = undef;
	    }
	    $hostname = $values[ $schema{'host'} ];
	    $hostname =~ s/^\s+|\s+$//g;
	    $address = $values[ $schema{'address'} ];
	    $address =~ s/^\s+|\s+$//g;
	    $os = $values[ $schema{'os'} ];
	    $os =~ s/^\s+|\s+$//g;
	    if ( $values[ $schema{'service'} ] ) {
		my $svc = $values[ $schema{'service'} ];
		$svc =~ s/^\s+|\s+$//g;
		my $info = $values[ $schema{'info'} ];
		$info =~ s/^\s+|\s+$//g;
		my %service = (
		    service => $svc,
		    info    => $info
		);
		push @services, {%service};
	    }
	}
    }
    return @errors;
}

sub process_nmap(@) {
    my $data = $_[1];
    my %host_values = ();
    my ( $tree, $os, $address, $hostname ) = undef;
    my ( $line, $service, $host, $services, $hosts, $status ) = undef;
    my @errors = ();
    if ($data) {
	my $parser = XML::LibXML->new(
	    ext_ent_handler => sub { die "INVALID FORMAT: external entity references are not allowed in NMAP output.\n" },
	    no_network      => 1
	);
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
	    my $root  = $tree->getDocumentElement;
	    my @nodes = $root->findnodes("//host");
	    foreach my $node (@nodes) {
		my @siblings = $node->getChildnodes();
		foreach my $sibling (@siblings) {
		    if ( $sibling->nodeName() =~ /hostnames$/ ) {
			if ( $sibling->hasChildNodes() ) {
			    my $child = $sibling->getFirstChild();
			    $hostname = $child->getAttribute('name');
			}
		    }
		    elsif ( $sibling->nodeName() =~ /address$/ ) {
			my $addrtype = $sibling->getAttribute('addrtype');
			if ( $addrtype =~ /ip/i ) {
			    $address = $sibling->getAttribute('addr');
			}
		    }
		    elsif ( $sibling->nodeName() =~ /status$/ ) {
			$status = $sibling->getAttribute('state');
		    }
		    elsif ( $sibling->nodeName() =~ /os$/ ) {
			my @children = $sibling->getChildnodes();
			foreach my $child (@children) {
			    if ( $child->nodeName() =~ /osmatch$/ ) {
				$os = $child->getAttribute('name');
			    }
			}
		    }
		}
		if ( !$os ) { $os = "nomatch" }
		my @host_vals = split( /\./, $hostname );
		my $name      = shift @host_vals;
		my $alias     = $hostname;
		unless ($name) { $name = $address }
		%host_values = ( 'name' => $name, 'alias' => $alias, 'os' => $os, 'status' => $status );
	    }
	}
    }
    if (@errors) { $host_values{'errors'} = \@errors }
    return %host_values;
}

sub get_service_name(@) {
    my $sid     = $_[1];
    ## FIX MINOR:  should probably use an inner join, not a left join
    my $sqlstmt = "select service_names.name from service_names left join services on "
      . "service_names.servicename_id = services.servicename_id where services.service_id = '$sid'";
    my $name = $dbh->selectrow_array($sqlstmt);
    return $name;
}

sub get_names_in(@) {
    my $id1    = $_[1];
    my $table1 = $_[2];
    my $table2 = $_[3];
    my $id2    = $_[4];
    my $value  = $_[5];
    my $where  = '';
    if ($value) { $where = " where $id2 = '$value'" }
    my $sqlstmt = "select * from $table1 where $id1 in " . "(select $id1 from $table2$where)";
    my $sth     = $dbh->prepare($sqlstmt);
    $sth->execute;
    my @names = ();
    while ( my @values = $sth->fetchrow_array() ) { push @names, $values[1] }
    $sth->finish;
    return @names;
}

sub get_tree_templates(@) {
    my $id         = $_[1];
    my %properties = ();
    my $sqlstmt = "select * from escalation_templates where template_id in "
      . "(select template_id from escalation_tree_template where tree_id = '$id')";
    my $sth = $dbh->prepare($sqlstmt);
    $sth->execute;
    my @order              = ();
    my %first_notify       = ();
    my %notification_names = ();
    my %name_id            = ();
    while ( my @values = $sth->fetchrow_array() ) {
	my %data = parse_xml( '', $values[3] );
	$first_notify{ $values[0] } = $data{'first_notification'};
	$properties{ $values[0] }   = [@values];
	$name_id{ $values[1] }      = $values[0];
	$notification_names{ $data{'first_notification'} } .= "$values[1],";
    }
    $sth->finish;
    if (defined $notification_names{'-zero-'}) {
	chop $notification_names{'-zero-'};
	my @sort = split( /,/, $notification_names{'-zero-'} );
	@sort = sort @sort;
	foreach my $name (@sort) {
	    push @order, $name_id{$name};
	}
	delete $notification_names{'-zero-'};
    }

    foreach my $notification ( sort keys %notification_names ) {
	my @sort = split( /,/, $notification_names{$notification} );
	@sort = sort @sort;
	foreach my $name (@sort) {
	    push @order, $name_id{$name};
	}
    }

    return \@order, \%first_notify, \%properties;
}

sub get_tree_template_contactgroup(@) {
    my $tree_id    = $_[1];
    my $temp_id    = $_[2];
    my %properties = ();
    my $sqlstmt    = "select contactgroups.name from contactgroups where contactgroup_id in "
      . "(select contactgroup_id from tree_template_contactgroup where tree_id = '$tree_id' and template_id = '$temp_id')";
    my $sth = $dbh->prepare($sqlstmt);
    $sth->execute;
    my @names = ();
    while ( my @values = $sth->fetchrow_array() ) { push @names, $values[0] }
    $sth->finish;
    return @names;
}

sub get_contactgroups(@) {
    my $type    = $_[1];
    my $id      = $_[2];
    my $table   = contactgroup_table_by_object( '', $type );
    my %obj_id  = get_obj_id();
    my $sqlstmt = "select * from contactgroups where contactgroup_id in " .
      ## "(select contactgroup_id from contactgroup_assign where type = '$type' and object = '$obj')";
      "(select contactgroup_id from $table where $obj_id{$table} = '$id')";
    my $sth = $dbh->prepare($sqlstmt);
    $sth->execute;
    my @names = ();
    while ( my @values = $sth->fetchrow_array() ) { push @names, $values[1] }
    $sth->finish;
    return @names;
}

sub get_profile_hostgroup(@) {
    my $pid = $_[1];
    my $sqlstmt =
      "select name from hostgroups where hostgroup_id in " . "(select hostgroup_id from profile_hostgroup where hostprofile_id = '$pid')";
    my $sth = $dbh->prepare($sqlstmt);
    $sth->execute;
    my @names = ();
    while ( my @values = $sth->fetchrow_array() ) { push @names, $values[0] }
    $sth->finish;
    return @names;
}

sub get_externals() {
    my %externals = ();
    my $sqlstmt   = "select * from externals";
    my $sth       = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	$externals{ $values[0] }{'name'} = $values[1];
	$externals{ $values[0] }{'type'} = $values[3];
	$externals{ $values[0] }{'data'} = $values[4];
    }
    $sth->finish;
    return %externals;
}

sub get_profile_external(@) {
    my $pid   = $_[1];
    my @names = ();
    my $sqlstmt =
      "select name from externals where external_id in " . "(select external_id from external_host_profile where hostprofile_id = '$pid')";
    my $sth = undef;
    eval {
	$sth = $dbh->prepare($sqlstmt);
	$sth->execute;
    };
    if ($@) {
	log_caller('', $sqlstmt, $@);
	die "\n";
    }
    else {
	while ( my @values = $sth->fetchrow_array() ) { push @names, $values[0] }
    }
    $sth->finish;
    return @names;
}

sub get_servicename_external(@) {
    my $sid   = $_[1];
    my @names = ();
    my $sqlstmt =
      "select name from externals where external_id in " . "(select external_id from external_service_names where servicename_id = '$sid')";
    my $sth = undef;
    eval {
	$sth = $dbh->prepare($sqlstmt);
	$sth->execute;
    };
    if ($@) {
	log_caller('', $sqlstmt, $@);
	die "\n";
    }
    else {
	while ( my @values = $sth->fetchrow_array() ) { push @names, $values[0] }
    }
    $sth->finish;
    return @names;
}

sub get_profile_parent(@) {
    my $pid     = $_[1];
    my @names   = ();
    my $sqlstmt = "select name from hosts where host_id in " . "(select host_id from profile_parent where hostprofile_id = '$pid')";
    my $sth     = undef;
    eval {
	$sth = $dbh->prepare($sqlstmt);
	$sth->execute;
    };
    if ($@) {
	log_caller('', $sqlstmt, $@);
	die "\n";
    }
    else {
	while ( my @values = $sth->fetchrow_array() ) { push @names, $values[0] }
    }
    $sth->finish;
    return @names;
}

sub get_profiles() {
    my %profiles = ();
    my $sqlstmt  = "select * from profiles_host";
    my $sth      = $dbh->prepare($sqlstmt);
    $sth->execute;
    my @names = ();
    while ( my @values = $sth->fetchrow_array() ) {
	$profiles{ $values[1] }{'description'} = $values[2];
	$sqlstmt =
"select name, description from profiles_service where serviceprofile_id in (select serviceprofile_id from profile_host_profile_service where hostprofile_id = $values[0])";
	my $sth2 = $dbh->prepare($sqlstmt);
	$sth2->execute;
	while ( my @vals = $sth2->fetchrow_array() ) {
	    $profiles{ $values[1] }{ $vals[0] } = $vals[1];
	}
	my %data = parse_xml( '', $values[8] );
	@{ $profiles{ $values[1] }{'hostgroups'} } = ();
	if ( $data{'apply_hostgroups'} ) {
	    $sqlstmt =
"select name from hostgroups where hostgroup_id in (select hostgroup_id from profile_hostgroup where hostprofile_id = '$values[0]')";
	    my $sth3 = $dbh->prepare($sqlstmt);
	    $sth3->execute;
	    while ( my @hgs = $sth3->fetchrow_array() ) {
		push @{ $profiles{ $values[1] }{'hostgroups'} }, $hgs[0];
	    }
	    $sth3->finish;
	}
	$sth2->finish;
    }
    $sth->finish;
    return %profiles;
}

sub get_host_parent(@) {
    my $hid     = $_[1];
    my @names   = ();
    my $sqlstmt = "select name from hosts where host_id in (select parent_id from host_parent where host_id = '$hid')";
    my $sth     = undef;
    eval {
	$sth = $dbh->prepare($sqlstmt);
	$sth->execute;
    };
    if ($@) {
	log_caller('', $sqlstmt, $@);
	die "\n";
    }
    else {
	while ( my @values = $sth->fetchrow_array() ) { push @names, $values[0] }
    }
    $sth->finish;
    return @names;
}

sub get_parents(@) {
    my $sqlstmt = "select name from hosts where host_id in (select distinct parent_id from host_parent)";
    my $sth     = $dbh->prepare($sqlstmt);
    $sth->execute;
    my @names = ();
    while ( my @values = $sth->fetchrow_array() ) { push @names, $values[0] }
    $sth->finish;
    return @names;
}

sub get_host_dep_parents() {
    my $sqlstmt = "select host_id, parent_id from host_dependencies";
    my $sth     = $dbh->prepare($sqlstmt);
    $sth->execute;
    my @dep_hosts = ();
    while ( my @values = $sth->fetchrow_array() ) {
	my %d = fetch_one( '', 'hosts', 'host_id', $values[0] );
	my %p = fetch_one( '', 'hosts', 'host_id', $values[1] );
	push @dep_hosts, "$d{'name'}::--::$p{'name'}";
    }
    $sth->finish;
    return @dep_hosts;
}

sub get_host_dependencies() {
    my $sqlstmt = "select * from host_dependencies";
    my $sth     = $dbh->prepare($sqlstmt);
    $sth->execute;
    my %host_dependencies = ();
    while ( my @values = $sth->fetchrow_array() ) {
	my %data = parse_xml( '', $values[2] );
	foreach my $prop ( keys %data ) {
	    $host_dependencies{ $values[0] }{ $values[1] }{$prop} = $data{$prop};
	}
    }
    $sth->finish;
    return %host_dependencies;
}

sub get_children() {
    my $pid = $_[1];
    my @names = ();
    my $sqlstmt =
      "select hosts.host_id, hosts.name from hosts left join host_parent on hosts.host_id = host_parent.host_id where parent_id = '$pid'";
    my $sth = undef;
    eval {
	$sth = $dbh->prepare($sqlstmt);
	$sth->execute;
    };
    if ($@) {
	log_caller('', $sqlstmt, $@);
	die "\n";
    }
    else {
	while ( my @values = $sth->fetchrow_array() ) { push @names, $values[1] }
    }
    $sth->finish;
    return @names;
}

sub get_hosts_unassigned() {
    my $gid = $_[1];  # undef for non-group
    my $sqlstmt;
    if (defined $gid) {
	# Choose the names of only those hosts which are part of a group but not part of
	# any hostgroup associated with that group.  There are many ways to formulate this
	# query; this one is complicated but was chosen for efficiency.
	$sqlstmt =
	  "select h_name from (select h.name as h_name, h.host_id as h_host_id from monarch_group_host mgh, hosts h " .
	  "where mgh.group_id = '$gid' and h.host_id = mgh.host_id) as tmp1 " .
	  "left join " .
	  "(select hgh.host_id as hgh_host_id from monarch_group_hostgroup mghg, hostgroup_host hgh " .
	    "where mghg.group_id = '$gid' and hgh.hostgroup_id = mghg.hostgroup_id) as tmp2 " .
	    "on h_host_id = hgh_host_id where hgh_host_id is null";
    }
    else {
	## FIX LATER:  perhaps we should use a left join instead, for efficiency:
	## $sqlstmt = "select name from hosts h left join hostgroup_host hgh on hgh.host_id = h.host_id where hgh.host_id is null";
	$sqlstmt = "select name from hosts where host_id not in (select host_id from hostgroup_host)";
    }
    my $sth     = $dbh->prepare($sqlstmt);
    $sth->execute;
    my @names = ();
    while ( my @values = $sth->fetchrow_array() ) { push @names, $values[0] }
    $sth->finish;
    return @names;
}

sub get_hostgroup_hosts(@) {
    my $name    = $dbh->quote( $_[1] );
    my $sqlstmt = "select name from hosts where host_id in (select hostgroup_host.host_id from hostgroup_host "
      . "left join hostgroups on hostgroup_host.hostgroup_id = hostgroups.hostgroup_id where hostgroups.name = $name)";
    my $sth = $dbh->prepare($sqlstmt);
    $sth->execute;
    my @names = ();
    while ( my @values = $sth->fetchrow_array() ) { push @names, $values[0] }
    $sth->finish;
    return @names;
}

# Badly named, and deprecated.  Use get_hostgroup_hosts() instead.
sub get_host_hostgroup(@) {
    return get_hostgroup_hosts(@_);
}

sub get_host_hostgroups(@) {
    my $name    = $_[1];
    my $sqlstmt = "select name from hostgroups where hostgroup_id in (select hostgroup_host.hostgroup_id from "
      . "hostgroup_host left join hosts on hostgroup_host.host_id = hosts.host_id where hosts.name = '$name')";
    my $sth = $dbh->prepare($sqlstmt);
    $sth->execute;
    my @names = ();
    while ( my @values = $sth->fetchrow_array() ) { push @names, $values[0] }
    $sth->finish;
    return @names;
}

# Badly named, and deprecated.  Use get_host_hostgroups() instead.
sub get_hostgroup_host(@) {
    return get_host_hostgroups(@_);
}

sub get_hostgroups_hosts() {
    my $gid        = $_[1] || 0;
    my %hostgroups = ();
    my $sqlstmt =
"select hostgroup_id, name from hostgroups where hostgroup_id in (select hostgroup_id from monarch_group_hostgroup where group_id = '$gid')";
    my $sth = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	$hostgroups{ $values[1] } = $values[0];
    }
    $sth->finish;
    my %members    = ();
    my %nonmembers = ();
    $sqlstmt = "select * from hostgroups";
    $sth     = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	my @hostgroup_hosts = ();
	$sqlstmt =
	  "select name from hosts where host_id in (select host_id from hostgroup_host where hostgroup_id = '$values[0]') order by name";
	my $sth2 = $dbh->prepare($sqlstmt);
	$sth2->execute;
	while ( my @vals = $sth2->fetchrow_array() ) {
	    push @hostgroup_hosts, $vals[0];
	}
	$sth2->finish;
	if ( $hostgroups{ $values[1] } ) {
	    @{ $members{ $values[1] } } = ();
	    @{ $members{ $values[1] } } = @hostgroup_hosts;
	}
	else {
	    @{ $nonmembers{ $values[1] } } = ();
	    @{ $nonmembers{ $values[1] } } = @hostgroup_hosts;
	}
    }
    $sth->finish;
    return \%nonmembers, \%members;
}

sub get_names(@) {
    my $id      = $_[1];
    my $table   = $_[2];
    my $members = $_[3];
    my @names   = ();
    foreach my $mem ( @{$members} ) {
	my %m = fetch_one( '', $table, $id, $mem );
	push @names, $m{'name'};
    }
    return @names;
}

sub get_ids(@) {
    my $id      = $_[1];
    my $table   = $_[2];
    my $members = $_[3];
    my @ids;
    foreach my $mem ( @{$members} ) {
	my %m = fetch_one( '', $table, 'name', $mem );
	push @ids, $m{$id};
    }
    return @ids;
}

sub get_tree_detail(@) {
    my $name      = $_[1];
    my %tree      = ();
    my %ranks     = ();
    my %templates = ();
    my %t         = fetch_one( '', 'escalation_trees', 'name', $name );
    my $sqlstmt =
	"select * from escalation_templates where template_id in "
      . "(select escalation_tree_template.template_id from escalation_tree_template left join escalation_trees on "
      . "escalation_tree_template.tree_id = escalation_trees.tree_id where escalation_trees.name = '$name')";

    my $sth = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	$templates{ $values[1] }{'name'} = $values[1];
	$templates{ $values[1] }{'id'}   = $values[0];
	my %data = parse_xml( '', $values[3] );
	foreach my $k ( keys %data ) {
	    if ( $k eq 'first_notification' ) {
		$tree{ $data{$k} }{ $values[1] } = 1;
	    }
	    ## $data{$k} =~ s/\*/star/g;
	    $templates{ $values[1] }{$k} = $data{$k};
	}
    }
    $sth->finish;
    foreach my $template ( keys %templates ) {
	$sqlstmt = "select name from contactgroups where contactgroup_id in "
	  . "(select contactgroup_id from tree_template_contactgroup where tree_id = '$t{'tree_id'}' and template_id = '$templates{$template}{'id'}')";
	$sth = $dbh->prepare($sqlstmt);
	$sth->execute;
	while ( my @values = $sth->fetchrow_array() ) {
	    $templates{$template}{'contactgroups'} .= "$values[0],";
	}
	$sth->finish;
	chop $templates{$template}{'contactgroups'};
    }
    my $serial = 0;
    foreach my $rank ( sort { $a <=> $b } keys %tree ) {
	foreach my $name ( sort { $a cmp $b } keys %{ $tree{$rank} } ) {
	    $ranks{ ++$serial } = $name;
	}
    }
    return \%ranks, \%templates;
}

# The routines here are for these purposes:
# * when deleting a    host service, see what    host services depended on that    host service [get_dependent_host_services]
# * when deleting a    host service, see what generic services depended on that    host service [get_dependent_services]
# * when deleting a generic service, see what    host services depended on that generic service [get_dependent_host_services]
# * when deleting a generic service, see what generic services depended on that generic service [get_dependent_services]

# Unstable interface, subject to change.
sub get_dependent_host_services(@) {
    my $snid    = $_[1];
    my $hid     = $_[2];
    my $sqlstmt = "select * from service_dependency where ";
    $sqlstmt .= "depend_on_host_id = '$hid' and " if defined $hid;
    $sqlstmt .= "template in (select id from service_dependency_templates where servicename_id = '$snid')";
    my %dependencies = ();
    my $sth          = $dbh->prepare($sqlstmt);
    $sth->execute;
    ## FIX LATER:  This sequence of secondary fetches is pretty awful.
    ## Couldn't we do the same by complexifying the original query,
    ## thus saving a ton of context switches?
    while ( my @values = $sth->fetchrow_array() ) {
	my %t = fetch_one( '', 'service_dependency_templates', 'id', $values[4] );
	my %h = fetch_one( '', 'hosts', 'host_id', $values[2] );
	my %d = fetch_one( '', 'services', 'service_id', $values[1] );
	my %s = fetch_one( '', 'service_names', 'servicename_id', $d{servicename_id} );
	my @vals = ( $t{'name'}, $h{'name'}, $s{'name'} );
	$dependencies{ $values[0] } = [@vals];
    }
    $sth->finish;
    return %dependencies;
}

# Unstable interface, subject to change.
sub get_dependent_services(@) {
    my $snid    = $_[1];
    my $hid     = $_[2];
    my $sqlstmt = "select * from servicename_dependency where ";
    $sqlstmt .= "depend_on_host_id = '$hid' and " if defined $hid;
    $sqlstmt .= "template in (select id from service_dependency_templates where servicename_id = '$snid')";
    my %dependencies = ();
    my $sth          = $dbh->prepare($sqlstmt);
    $sth->execute;
    ## FIX LATER:  This sequence of secondary fetches is pretty awful.
    ## Couldn't we do the same by complexifying the original query,
    ## thus saving a ton of context switches?
    while ( my @values = $sth->fetchrow_array() ) {
	my %t = fetch_one( '', 'service_dependency_templates', 'id', $values[3] );
	my %s = fetch_one( '', 'service_names', 'servicename_id', $values[1] );
	my @vals = ( $t{'name'}, $s{'name'} );
	$dependencies{ $values[0] } = [@vals];
    }
    $sth->finish;
    return %dependencies;
}

sub get_dependencies(@) {
    my $sid          = $_[1];
    my $sqlstmt      = "select * from service_dependency where service_id = '$sid'";
    my %dependencies = ();
    my $sth          = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	my %t = fetch_one( '', 'service_dependency_templates', 'id', $values[4] );
	my %h = fetch_one( '', 'hosts', 'host_id', $values[3] );
	my %s = fetch_one( '', 'service_names', 'servicename_id', $t{servicename_id} );
	my @vals = ( $t{'name'}, $h{'name'}, $s{'name'} );
	$dependencies{ $values[0] } = [@vals];
    }
    $sth->finish;
    return %dependencies;
}

sub get_servicename_dependencies(@) {
    my $sid          = $_[1];
    my $sqlstmt      = "select * from servicename_dependency where servicename_id = '$sid'";
    my %dependencies = ();
    my $sth          = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	my %t = fetch_one( '', 'service_dependency_templates', 'id', $values[3] );
	my %h = fetch_one( '', 'hosts', 'host_id', $values[2] );
	my %s = fetch_one( '', 'service_names', 'servicename_id', $t{servicename_id} );
	unless ( $values[2] ) { $h{'name'} = 'same host' }
	my @vals = ( $t{'name'}, $h{'name'}, $s{'name'} );
	$dependencies{ $values[0] } = [@vals];
    }
    $sth->finish;
    return %dependencies;
}

sub check_dependency() {
    my $sid        = $_[1];
    my $parent     = $_[2];
    my $dependency = $_[3];
    my $result     = 0;
    my $sqlstmt    = undef;
    if ( $parent eq 'same host' ) {
	$sqlstmt =
	  "select id from servicename_dependency where servicename_id = '$sid' and template = '$dependency' and depend_on_host_id is null";
    }
    else {
	$sqlstmt =
	  "select id from servicename_dependency where servicename_id = '$sid' and template = '$dependency' and depend_on_host_id = '$parent'";
    }
    $result = $dbh->selectrow_array($sqlstmt);
    return $result;
}

sub insert_dependency() {
    my $sid        = $_[1];
    my $parent     = $_[2];
    my $dependency = $_[3];
    my $sqlstmt    = undef;
    if ( $parent eq 'same host' ) {
	$sqlstmt = "insert into servicename_dependency values(default,'$sid',null,'$dependency')";
    }
    else {
	$sqlstmt = "insert into servicename_dependency values(default,'$sid','$parent','$dependency')";
    }
    my $sth = undef;
    eval {
	$sth = $dbh->prepare($sqlstmt);
	$sth->execute;
    };
    if ($@) {
	$sth->finish;
	log_caller('', $sqlstmt, $@);
	return "Error: $sqlstmt ($@)";
    }
    else {
	$sth->finish;
	return 1;
    }
}

sub update_dependencies() {
    my $snid         = $_[1];
    my @errors       = ();
    my %service_host = ();
    my $sqlstmt      = "select service_id, host_id from services where servicename_id = '$snid'";
    my $sth          = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	$service_host{ $values[0] } = $values[1];
    }
    $sth->finish;
    my %dependencies = ();
    $sqlstmt = "select id, template, depend_on_host_id from servicename_dependency where servicename_id = '$snid'";
    $sth     = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	unless ( $values[2] ) { $values[2] = 'same_host' }
	$dependencies{ $values[1] }{ $values[2] } = 1;
    }
    $sth->finish;
    foreach my $sid ( keys %service_host ) {
	my $result = delete_all( '', 'service_dependency', 'service_id', $sid );
	if ( $result =~ /^Error/ ) { push @errors, $result }
	foreach my $temp ( keys %dependencies ) {
	    foreach my $depend_on_host ( keys %{ $dependencies{$temp} } ) {
		if ( $depend_on_host eq 'same_host' ) {
		    ## check to see that depend on service exists on host
		    my %t = fetch_one( '', 'service_dependency_templates', 'id', $temp );
		    my %where = (
			'host_id'        => $service_host{$sid},
			'servicename_id' => $t{'servicename_id'}
		    );
		    my %s = fetch_one_where( '', 'services', \%where );
		    if ( $s{'service_id'} ) {
			my @values = ( \undef, $sid, $service_host{$sid}, $service_host{$sid}, $temp, '' );
			my $result = insert_obj( '', 'service_dependency', \@values );
			if ( $result =~ /^Error/ ) { push @errors, $result }
		    }
		}
		else {
		    my @values = ( \undef, $sid, $service_host{$sid}, $depend_on_host, $temp, '' );
		    my $result = insert_obj( '', 'service_dependency', \@values );
		    if ( $result =~ /^Error/ ) { push @errors, $result }
		}
	    }
	}
    }
    return @errors;
}

sub add_dependencies() {
    my $host_id  = $_[1];
    my @errors   = ();
    my %services = ();
    my %snids    = ();
    my $sqlstmt  = "select service_id, servicename_id from services where host_id = '$host_id'";
    my $sth      = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	$services{ $values[0] } = $values[1];
	$snids{ $values[1] }    = 1;
    }
    $sth->finish;
    foreach my $service ( keys %services ) {
	my %dependencies = ();
	$sqlstmt = "select id, template, depend_on_host_id from servicename_dependency where servicename_id = '$services{$service}'";
	my $sth1 = $dbh->prepare($sqlstmt);
	$sth1->execute;
	while ( my @values = $sth1->fetchrow_array() ) {
	    unless ( $values[2] ) { $values[2] = 'same_host' }
	    $dependencies{ $values[1] }{ $values[2] } = 1;
	}
	$sth1->finish;
	foreach my $temp ( keys %dependencies ) {
	    foreach my $depend_on_host ( keys %{ $dependencies{$temp} } ) {
		if ( $depend_on_host eq 'same_host' ) {

		    # make sure the depend on service has been added to the host
		    if ( $snids{ $services{$service} } ) {
			my @values = ( \undef, $service, $host_id, $host_id, $temp, '' );
			my $result = insert_obj( '', 'service_dependency', \@values );
			if ( $result =~ /^Error/ ) { push @errors, $result }
		    }
		}
		else {
		    my @values = ( \undef, $service, $host_id, $depend_on_host, $temp, '' );
		    my $result = insert_obj( '', 'service_dependency', \@values );
		    if ( $result =~ /^Error/ ) { push @errors, $result }
		}
	    }
	}
    }
    return @errors;
}

sub log_caller(@) {
    my $sqlstmt   = $_[1];
    my $exception = $_[2];
    my ($package, $file, $line) = caller(1);  # show the caller's caller
    print STDERR "Error: $sqlstmt ($exception) called from $file line $line.\n";
}

# For occasional use in development debugging.
sub printstack {
    my $i = 0;
    while (my ($package, $filename, $line, $subroutine) = caller($i++)) {
	print "$package, $filename line $line (call to $subroutine)<br>";
    }
}

sub get_dep_on_hosts(@) {
    my $snid    = $_[1];
    my $host_id = $_[2];
    my $sqlstmt = "select name from hosts where host_id in (select host_id from services where servicename_id = '$snid')";
    my $sth     = $dbh->prepare($sqlstmt);
    $sth->execute;
    my @hosts = ();
    my $host  = 0;
    while ( my @values = $sth->fetchrow_array() ) {
	if ( $host_id eq $values[0] ) {
	    $host = 1;
	}
	else {
	    push @hosts, $values[0];
	}
    }
    $sth->finish;
    @hosts = sort @hosts;
    return $host, \@hosts;
}

sub get_host_services(@) {
    my $host_id = $dbh->quote( $_[1] );
    my $sqlstmt =
      "select service_names.name from service_names where servicename_id in (select servicename_id from services where host_id = $host_id)";
    my $sth = $dbh->prepare($sqlstmt);
    $sth->execute;
    my @services = ();
    while ( my @values = $sth->fetchrow_array() ) {
	push @services, $values[0];
    }
    $sth->finish;
    @services = sort @services;
    return @services;
}

sub get_service_hosts(@) {
    my $id      = $_[1];
    my $sqlstmt = "select hosts.name from hosts where host_id in (select host_id from services where servicename_id = '$id')";
    my $sth     = $dbh->prepare($sqlstmt);
    $sth->execute;
    my @hosts = ();
    while ( my @values = $sth->fetchrow_array() ) {
	push @hosts, $values[0];
    }
    $sth->finish;
    @hosts = sort @hosts;
    return @hosts;
}

sub get_upload(@) {
    my $upload_dir = $_[1];
    my $type       = $_[2];
    local $_;

    my @nmaps   = ();
    my @imports = ();
    my @errors  = ();
    if ( !opendir( DIR, $upload_dir ) ) {
	push @errors, "error: cannot open $upload_dir to read ($!)";
    }
    else {
	my @files = readdir DIR;
	@files = grep { -T "$upload_dir/$_" } @files;

	foreach my $file (@files) {
	    if ( !open( FILE, '<', "$upload_dir/$file" ) ) {
		push @errors, "error: cannot open $upload_dir/$file to read ($!)";
	    }
	    else {
		local $/;  # slurp mode
		my $slurp = <FILE>;
		if ( $slurp =~ /nmaprun scanner/ ) {
		    push @nmaps, $file;
		}
		else {
		    push @imports, $file;
		}
		close(FILE);
	    }
	}
	closedir(DIR);
    }
    if ( $type eq 'nmap' ) {
	return \@errors, \@nmaps;
    }
    else {
	return \@errors, \@imports;
    }
}

# FIX LATER:  generalize this to any table, not just service_names
sub get_num_records(@) {
    my $table   = $_[1];
    my $sqlstmt = "select count(*) from service_names";
    my $rows    = $dbh->selectrow_array($sqlstmt);
    return $rows;
}

sub get_host_service(@) {
    my $servicename_id = $_[1];
    my %host_service   = ();
    my $sqlstmt        = "select host_id, service_id from services where servicename_id = '$servicename_id'";
    my $sth            = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	$host_service{ $values[0] } = $values[1];
    }
    $sth->finish;
    return %host_service;
}

sub get_hostname_servicename(@) {
    my $table   = $_[1];
    my $column  = $_[2];
    my $value   = $_[3];
    my @names   = ();
    my $sqlstmt = undef;
    if ( $table eq 'services' ) {
	$sqlstmt = "select host_id, servicename_id from services where $column = '$value'";
    }
    elsif ( $table eq 'service_dependency' ) {
	$sqlstmt = "select services.host_id, services.servicename_id from services left join service_dependency on "
	  . "service_dependency.service_id = services.service_id where $column = '$value'";
    }
    my $sth = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	my %h = fetch_one( '', 'hosts',         'host_id',        $values[0] );
	my %s = fetch_one( '', 'service_names', 'servicename_id', $values[1] );
	if ( $h{'name'} && $s{'name'} ) {
	    my %rec = ( $h{'name'} => $s{'name'} );
	    push @names, \%rec;
	}
    }
    $sth->finish;
    return @names;
}

sub get_contactgroup_object(@) {
    my $value   = $_[1];
    my $obj_id  = $_[2];
    my %obj_id  = %{$obj_id};
    my $sqlstmt = "select type, object from contactgroup_assign where contactgroup_id = '$value'";
    my $sth     = $dbh->prepare($sqlstmt);
    $sth->execute;
    my @names = ();
    while ( my @values = $sth->fetchrow_array() ) {
	my %obj = fetch_one( '', $values[0], $obj_id{ $values[0] }, $values[1] );
	my %rec = ( $values[0] => $obj{'name'} );
	push @names, \%rec;
    }
    $sth->finish;
    return @names;
}

sub get_contact_contactgroup(@) {
    my $value   = $_[1];
    my $sqlstmt = "select contacts.name from contacts left join contactgroup_contact on "
      . "contactgroup_contact.contact_id = contacts.contact_id where contactgroup_id = '$value'";
    my $sth = $dbh->prepare($sqlstmt);
    $sth->execute;
    my @names = ();
    while ( my @values = $sth->fetchrow_array() ) {
	push @names, $values[0];
    }
    $sth->finish;
    return @names;
}

sub get_contactgroup_contact(@) {
    my $value   = $_[1];
    my $sqlstmt = "select contactgroups.name from contactgroups left join contactgroup_contact on "
      . "contactgroup_contact.contactgroup_id = contactgroups.contactgroup_id where contact_id = '$value'";
    my $sth = $dbh->prepare($sqlstmt);
    $sth->execute;
    my @names = ();
    while ( my @values = $sth->fetchrow_array() ) {
	push @names, $values[0];
    }
    $sth->finish;
    return @names;
}

sub get_command_contact_template(@) {
    my $id      = $_[1];
    my $type    = $_[2];
    my $sqlstmt = "select commands.name from commands left join contact_command on commands.command_id = contact_command.command_id "
      . "where contact_command.contacttemplate_id = '$id' and contact_command.type = '$type'";
    my $sth = $dbh->prepare($sqlstmt);
    $sth->execute;
    my @names = ();
    while ( my @values = $sth->fetchrow_array() ) {
	push @names, $values[0];
    }
    $sth->finish;
    return @names;
}

sub get_command_contact(@) {
    my $id   = $_[1];
    my $type = $_[2];
    my $sqlstmt =
	"select commands.name from commands left join contact_command_overrides on commands.command_id = contact_command_overrides.command_id "
      . "where contact_command_overrides.contact_id = '$id' and contact_command_overrides.type = '$type'";
    my $sth = $dbh->prepare($sqlstmt);
    $sth->execute;
    my @names = ();
    while ( my @values = $sth->fetchrow_array() ) {
	push @names, $values[0];
    }
    $sth->finish;
    return @names;
}

sub get_tree_contactgroup(@) {
    my $value   = $_[1];
    my $sqlstmt = "select name from escalation_trees left join tree_template_contactgroup on "
      . "tree_template_contactgroup.tree_id = escalation_trees.tree_id where contactgroup_id = '$value'";
    my $sth = $dbh->prepare($sqlstmt);
    $sth->execute;
    my @names = ();
    while ( my @values = $sth->fetchrow_array() ) {
	push @names, $values[0];
    }
    $sth->finish;
    return @names;
}

sub fetch_scripts(@) {
    my $type    = $_[1];
    my %scripts = ();
    my $sqlstmt = "select name, script from extended_$type\_info_templates where script != ''";
    my $sth     = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	$scripts{ $values[0] } = $values[1];
    }
    $sth->finish;
    return %scripts;
}

sub delete_file(@) {
    my $dir    = $_[1];
    my $file   = $_[2];
    my $result = 1;
    unlink("$dir/$file") or $result = "Error: Unable to remove $dir/$file ($!)";
    return $result;
}

sub fetch_service_extinfo(@) {
    my $extinfo_id = $_[1];
    my $sqlstmt    = "select service_id, servicename_id, host_id from services where serviceextinfo_id = '$extinfo_id'";
    my $sth        = $dbh->prepare($sqlstmt);
    $sth->execute;
    my %service_host = ();
    while ( my @values = $sth->fetchrow_array() ) {
	my %sn = fetch_one( '', 'service_names', 'servicename_id', $values[1] );
	my %h  = fetch_one( '', 'hosts',         'host_id',        $values[2] );
	my @vals = ( $h{'name'}, $sn{'name'} );
	$service_host{ $values[0] } = [@vals];
    }
    $sth->finish;
    return %service_host;
}

sub get_template_properties(@) {
    my $id                 = $_[1];
    my %contactgroups_seen = ();
    my %properties         = fetch_one( '', 'service_templates', 'servicetemplate_id', $id );
    my $sqlstmt            = "select contactgroups.name from contactgroups left join contactgroup_service_template on "
      . "contactgroup_service_template.contactgroup_id = contactgroups.contactgroup_id where servicetemplate_id = '$id'";
    my $sth = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	$contactgroups_seen{"$values[0],"} = 1;
    }
    $sth->finish;
    if ( $properties{'parent_id'} && $properties{'parent_id'} != $id ) {
	my $pid = $properties{'parent_id'};
	my %already_seen = ( $id => 1 );
	until ( !$pid ) {
	    my %parent = fetch_one( '', 'service_templates', 'servicetemplate_id', $pid );
	    foreach my $prop ( keys %parent ) {
		if ( !$properties{$prop} ) {
		    $properties{$prop} = $parent{$prop};
		}
	    }
	    $sqlstmt = "select contactgroups.name from contactgroups left join contactgroup_service_template on "
	      . "contactgroup_service_template.contactgroup_id = contactgroups.contactgroup_id where servicetemplate_id = '$pid'";
	    my $sth1 = $dbh->prepare($sqlstmt);
	    $sth1->execute;
	    while ( my @values = $sth1->fetchrow_array() ) {
		$contactgroups_seen{"$values[0],"} = 1;
	    }
	    $sth1->finish;
	    $already_seen{$pid} = 1;
	    $pid = 0;
	    if ( $parent{'parent_id'} && !$already_seen{ $parent{'parent_id'} } ) {
		$pid = $parent{'parent_id'};
	    }
	}
    }

    # FIX THIS:  how does this deal with a trailing comma?
    my @contactgroups = sort keys %contactgroups_seen;
    $properties{'contactgroup'} = [@contactgroups];
    return %properties;
}

sub get_servicegroup(@) {
    my $id           = $_[1];
    my %host_service = ();
    my $sqlstmt      = "select distinct host_id from servicegroup_service where servicegroup_id = '$id'";
    my $sth          = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	my %host = fetch_one( '', 'hosts', 'host_id', $values[0] );
	my @services = ();
	$sqlstmt = "select service_names.name from service_names left join services on service_names.servicename_id = services.servicename_id "
	  . "where service_id in (select service_id from servicegroup_service where host_id = '$host{'host_id'}' and servicegroup_id = '$id')";
	my $sth2 = $dbh->prepare($sqlstmt);
	$sth2->execute;
	while ( my @vals = $sth2->fetchrow_array() ) {
	    push @services, $vals[0];
	}
	$sth2->finish;
	@services = sort @services;
	$host_service{ $host{'name'} } = [@services];
    }
    $sth->finish;
    return %host_service;
}

sub get_resources() {
    my $sqlstmt = "select name, value from setup where type = 'resource' and name like 'user%'";
    my $sth     = $dbh->prepare($sqlstmt);
    $sth->execute;
    my %resources = ();
    while ( my @values = $sth->fetchrow_array() ) {
	$resources{ $values[0] } = $values[1];
    }
    $sth->finish;
    return %resources;
}

sub get_resources_doc() {
    my $sqlstmt = "select name, value from setup where type = 'resource' and name like 'resource_label%'";
    my $sth     = $dbh->prepare($sqlstmt);
    $sth->execute;
    my %resource_doc = ();
    while ( my @values = $sth->fetchrow_array() ) {
	$resource_doc{ $values[0] } = $values[1];
    }
    $sth->finish;
    return %resource_doc;
}

# See the Config(3pm) man page for details of this magic formulation.
sub system_signal_name {
    my $signal_number = shift;
    local $_;

    my %sig_num;
    my @sig_name;

    unless ( $Config::Config{sig_name} && $Config::Config{sig_num} ) {
	return undef;
    }

    my @names = split ' ', $Config::Config{sig_name};
    @sig_num{@names} = split ' ', $Config::Config{sig_num};
    foreach (@names) {
	$sig_name[ $sig_num{$_} ] ||= $_;
    }

    return $sig_name[$signal_number] || undef;
}

sub wait_status_message {
    my $wait_status   = shift;
    my $exit_status   = $wait_status >> 8;
    my $signal_number = $wait_status & 0x7F;
    my $dumped_core   = $wait_status & 0x80;
    my $signal_name   = system_signal_name($signal_number) || "$signal_number is unknown";
    my $message = "exit status $exit_status" . ( $signal_number ? " (signal $signal_name)" : '' ) . ( $dumped_core ? ' (with core dump)' : '' );
    return $message;
}

# Mirror what goes on inside Nagios 3.x to process command-line argument escapes.
# Only for internal use within StorProc.
sub unescaped_command_args {
    my $argstring = shift;
    local $_;

    my @args      = ();
    my $in_escape = 0;
    my $arg       = '';
    foreach (split //, $argstring) {
	if ( ! $in_escape && /\\/ ) {
	    $in_escape = 1;
	    next;
	}
	if ( ! $in_escape && /!/ ) {
	    push @args, $arg;
	    $arg = '';
	    next;
	}
	$in_escape = 0;
	$arg .= $_;
    }
    push @args, $arg;
    return @args;
}

sub test_command(@) {
    my $name         = $_[1];
    my $command      = $_[2];
    my $host         = $_[3];
    my $arg_string   = $_[4];
    my $monarch_home = $_[5];
    my $service_desc = $_[6];
    my $nagios_ver   = $_[7];
    $arg_string =~ s/^[^!]*$name!// if $name;
    unless ($service_desc) { $service_desc = 'service_desc' }
    my %resources = get_resources();
    my %host = StorProc->fetch_one( 'hosts', 'name', $host );
    unless ( $host{'alias'} )   { $host{'alias'}   = $host }
    unless ( $host{'address'} ) { $host{'address'} = $host }

    foreach my $res ( keys %resources ) {
	if ( $command =~ /$res/i ) {
	    $command =~ s/\$$res\$/$resources{$res}/ig;
	}
    }
    $command =~ s/\$HOSTNAME\$/$host/g;
    $command =~ s/\$HOSTALIAS\$/$host{'alias'}/g;
    $command =~ s/\$HOSTADDRESS\$/$host{'address'}/g;
    $command =~ s/\$HOSTSTATE\$/UP/g;
    $command =~ s/\$HOSTSTATEID\$/0/g;
    $command =~ s/\$SERVICEDESC\$/$service_desc/g;
    $command =~ s/\$SERVICESTATE\$/UP/g;
    $command =~ s/\$SERVICESTATEID\$/0/g;
    $command =~ s/\$SERVICECHECKCOMMAND\$/$name/g;
    my $dt = datetime();
    $command =~ s/\$LONGDATETIME\$/$dt/g;
    $command =~ s/\$SHORTDATETIME\$/$dt/g;
    $command =~ s/\$DATE\$/$dt/g;
    $dt      =~ s/\d+-\d+-\d+\s+//;
    $command =~ s/\$TIME\$/$dt/g;
    my $now = time;
    $command =~ s/\$TIMET\$/$now/g;

    my @args;
    if ( $nagios_ver =~ /^[12]\.x$/ ) {
	@args = split( /!/, $arg_string );
    }
    else {
	@args = unescaped_command_args( $arg_string );
    }
    my $cnt = 1;
    foreach my $a (@args) {
	$command =~ s/\$ARG$cnt\$/$a/g;
	$cnt++;
    }
    $command =~ s/\$\S+\$/-/g;
    my $results = '<b><kbd>' . HTML::Entities::encode($command) . '</kbd></b><br>';
    if ( -x "$monarch_home/bin/monarch_as_nagios" ) {
	$results .= monarch_as_nagios( '', $command, $monarch_home );
    }
    else {
	$! = 0;
	my $output = qx($command 2>&1);
	if ( $output eq "\n" ) {
	    ## Work around <pre>'s suppression of output (and collapsing together
	    ## of top and bottom margins around the enclosed text) in this case.
	    $results .= '<pre><br></pre>';
	}
	elsif ($output) {
	    $results .= '<pre style="overflow: auto;">' . HTML::Entities::encode($output) . '</pre>';
	}
	if ( $? == -1 ) {
	    $results .= "Error executing command ($!)" if $!;
	}
	else {
	    $results .= 'Command returned ' . wait_status_message($?);
	}
    }
    return $results;
}

sub monarch_as_nagios(@) {
    my $command      = $_[1];
    my $monarch_home = $_[2];
    unless ($monarch_home) { $monarch_home = '/usr/local/groundwork/monarch' }
    my $error   = undef;
    my $results = undef;
    my $temp    = "$monarch_home/bin/temp" . rand();
    if ( !open( FILE, '>', $temp ) ) {
	$error = "Cannot open $temp to write ($!)";
    }
    else {
	print FILE "$command";
	close FILE;
    }
    if ($error) { $results = $error }

    unless ($error) {
	my $run_as = "$monarch_home/bin/monarch_as_nagios $temp $monarch_home/bin/monarch_as_nagios.pl";
	$results = qx($monarch_home/bin/monarch_as_nagios $temp $monarch_home/bin/monarch_as_nagios.pl 2>&1)
	  or $results = "Error(s) executing $run_as ($!)";
    }
    unlink($temp);
    return $results;
}

sub xml_blob(@) {
    my $hashref = $_[1];
    my %data    = %$hashref;
    my $data    = '';
    my $escaped = undef;

    foreach my $prop ( keys %data ) {
	if ( defined $data{$prop} ) {
	    ( $escaped = $data{$prop} ) =~ s{]]>}{]]]]><!\[CDATA\[>}g;
	    $data .= "\n  <prop name=\"$prop\"><![CDATA[$escaped]]>\n  </prop>";
	}
    }

    return "<?xml version=\"1.0\" encoding=\"iso-8859-1\" ?>\n<data>" . $data . "\n</data>" if $data;
    return undef;
}

# We don't replace the host's host template id from the profile, nor the host profile id itself, nor
# the host escalation id, nor the service escalation id.  The former two are not copied as part of
# applying a host profile, and the latter two are handled by some callers under separate control.
# FIX MINOR:  Might we need a replace/merge control for this routine, as we have for service_profile_apply()?
# FIX MINOR:  Might we be better off folding in here the application of host externals which are attached to
# the host profile, rather than handling them separately every place this routine is being called?
sub host_profile_apply(@) {
    my $profile       = $_[1];
    my $hosts         = $_[2];
    my $retain_detail = $_[3];    # polarity is set so legacy (undefined) behavior is default
    my $retain_vars   = $_[4];    # ditto
    local $_;

    my @hosts    = @{$hosts};
    my @errors   = ();
    my %update   = ();
    my %hp_props = ();
    my %hp_vars  = ();
    my %hpt_vars = ();
    my $hpt_id   = undef;
    my $sqlstmt  = undef;
    my $sth      = undef;

    return @errors if $retain_detail and $retain_vars;

    $profile = $dbh->quote($profile);

    $sqlstmt = "select * from profiles_host where hostprofile_id = $profile";
    $sth     = $dbh->prepare($sqlstmt);
    $sth->execute;
    my @profile_values = $sth->fetchrow_array();
    push @errors, $sth->errstr if defined $sth->err;
    $sth->finish;
    $hpt_id = $profile_values[3];
    $update{'hostextinfo_id'} = $profile_values[4] if not $retain_detail;

    $sqlstmt = "select * from hostprofile_overrides where hostprofile_id = $profile";
    $sth     = $dbh->prepare($sqlstmt);
    $sth->execute;
    my @hp_overrides = $sth->fetchrow_array();
    push @errors, $sth->errstr if defined $sth->err;
    $sth->finish;

    my %hp_data = defined( $hp_overrides[5] ) ? parse_xml( '', $hp_overrides[5] ) : ();
    push @errors, delete $hp_data{'error'} if defined $hp_data{'error'};
    if (not $retain_detail) {
	%hp_props = map { $_ => $hp_data{$_} } grep( !/^_/, keys %hp_data );
    }
    if (not $retain_vars) {
	%hp_vars = map { $_ => $hp_data{$_} } grep( /^_/, keys %hp_data );
	if (defined $hpt_id) {
	    $sqlstmt = "select * from host_templates where hosttemplate_id = $hpt_id";
	    $sth     = $dbh->prepare($sqlstmt);
	    $sth->execute;
	    my @hpt_values = $sth->fetchrow_array();
	    push @errors, $sth->errstr if defined $sth->err;
	    $sth->finish;
	    my %hpt_data = defined( $hpt_values[6] ) ? parse_xml( '', $hpt_values[6] ) : ();
	    push @errors, delete $hpt_data{'error'} if defined $hpt_data{'error'};
	    %hpt_vars = map { $_ => $hpt_data{$_} } grep( /^_/, keys %hpt_data );
	}
    }

    foreach my $hid (@hosts) {
	$sqlstmt = "select * from host_overrides where host_id = $hid";
	$sth     = $dbh->prepare($sqlstmt);
	$sth->execute;
	my @h_overrides = $sth->fetchrow_array();
	push @errors, $sth->errstr if defined $sth->err;
	$sth->finish;
	my %h_data = defined( $h_overrides[5] ) ? parse_xml( '', $h_overrides[5] ) : ();
	push @errors, delete $h_data{'error'} if defined $h_data{'error'};
	my %h_props = map { $_ => $h_data{$_} } grep( !/^_/, keys %h_data ) if $retain_detail;
	my %h_vars  = map { $_ => $h_data{$_} } grep(  /^_/, keys %h_data );
	if ( not $retain_vars ) {
	    $sqlstmt = "select * from hosts where host_id = $hid";
	    $sth     = $dbh->prepare($sqlstmt);
	    $sth->execute;
	    my @h_values = $sth->fetchrow_array();
	    push @errors, $sth->errstr if defined $sth->err;
	    $sth->finish;
	    my $ht_id = $h_values[5];
	    my %profile_vars = (defined($ht_id) && defined($hpt_id) && $ht_id == $hpt_id) ? %hp_vars : ( %hpt_vars, %hp_vars );
	    @h_vars{keys %profile_vars} = values %profile_vars;
	}
	my %host_data = ( $retain_detail ? %h_props : %hp_props, %h_vars );
	my $host_data = xml_blob( '', \%host_data );
	if ($retain_detail) {
	    if (@h_overrides) {
		my %values = ( data => $host_data );
		my $result = update_obj( '', 'host_overrides', 'host_id', $hid, \%values );
		if ( $result =~ /Error/ ) { push @errors, $result }
	    }
	    else {
		my @values = ( $hid, undef, undef, undef, undef, $host_data );
		my $result = insert_obj( '', 'host_overrides', \@values );
		if ( $result =~ /Error/ ) { push @errors, $result }
	    }
	}
	else {
	    my $result = delete_all( '', 'host_overrides', 'host_id', $hid );
	    if ( $result =~ /Error/ ) { push @errors, $result }
	    my @values = ( $hid, $hp_overrides[1], $hp_overrides[2], $hp_overrides[3], $hp_overrides[4], $host_data );
	    $result = insert_obj( '', 'host_overrides', \@values );
	    if ( $result =~ /Error/ ) { push @errors, $result }
	    $result = update_obj( '', 'hosts', 'host_id', $hid, \%update );
	    if ( $result =~ /Error/ ) { push @errors, $result }
	}
    }
    return @errors;
}

sub service_profile_apply(@) {
    my $profiles          = $_[1];
    my $service           = $_[2];
    my $hosts             = $_[3];
    my $retained_services = $_[4];
    my @profiles          = @{$profiles};
    my @hosts             = @{$hosts};
    my %retained_services = $retained_services ? %$retained_services : ();
    my @errors            = ();
    my $cnt               = 0;
    if (@hosts) {
	my %profile_services      = ();
	my %servicename_overrides = ();
	my %dependencies          = ();
	my %contactgroups         = ();
	my $sqlstmt               = '';
	my %externals             = ();
	my %externals_display     = ();

	foreach my $profile (@profiles) {
	    $sqlstmt =
"select * from service_names where servicename_id in (select servicename_id from serviceprofile where serviceprofile_id = '$profile')";
	    my $sth = $dbh->prepare($sqlstmt);
	    $sth->execute;
	    while ( my @values = $sth->fetchrow_array() ) {
		$profile_services{ $values[0] } = [@values];
	    }
	    push @errors, $sth->errstr if defined $sth->err;
	    $sth->finish;
	}
	$sqlstmt = "select * from servicename_overrides";
	my $sth = $dbh->prepare($sqlstmt);
	$sth->execute;
	while ( my @values = $sth->fetchrow_array() ) {
	    $servicename_overrides{ $values[0] } = [@values];
	}
	push @errors, $sth->errstr if defined $sth->err;
	$sth->finish;
	foreach my $snid ( keys %profile_services ) {
	    $sqlstmt = "select * from servicename_dependency where servicename_id = '$snid'";
	    $sth     = $dbh->prepare($sqlstmt);
	    $sth->execute;
	    while ( my @values = $sth->fetchrow_array() ) {
		$dependencies{$snid}{ $values[0] } = [@values];
	    }
	    push @errors, $sth->errstr if defined $sth->err;
	    $sth->finish;

	    # $sqlstmt = "select contactgroup_id from contactgroup_assign where type = 'service_names' and object = '$snid'";
	    $sqlstmt = "select contactgroup_id from contactgroup_service_name where servicename_id = '$snid'";
	    $sth     = $dbh->prepare($sqlstmt);
	    $sth->execute;
	    while ( my @values = $sth->fetchrow_array() ) {
		push @{ $contactgroups{$snid} }, $values[0];
	    }
	    push @errors, $sth->errstr if defined $sth->err;
	    $sth->finish;

	    $sqlstmt =
"select e.external_id,e.display from external_service_names as esn, externals as e where esn.servicename_id = '$snid' and e.external_id=esn.external_id";
	    $sth = $dbh->prepare($sqlstmt);
	    $sth->execute;
	    while ( my @values = $sth->fetchrow_array() ) {
		if ( $values[0] ) {
		    $externals{$snid}{ $values[0] } = 1;              # Set externals id
		    $externals_display{ $values[0] } = $values[1];    # Set externals data
		}
	    }
	    push @errors, $sth->errstr if defined $sth->err;
	    $sth->finish;
	}
	my %host = ();
	foreach my $hid (@hosts) {
	    unless ( $host{$hid} ) {
		$host{$hid} = 1;
		my %host_service = ();
		if ( $service eq 'replace' ) {
		    $sqlstmt = "delete from services where host_id = $hid";
		    eval { $dbh->do($sqlstmt); };
		    if ($@) {
			push @errors, "Error: $@";
			log_caller('', $sqlstmt, $@);
		    }
		}
		else {
		    $sqlstmt = "select servicename_id, service_id from services where host_id = '$hid'";
		    my $sth = $dbh->prepare($sqlstmt);
		    $sth->execute;
		    while ( my @values = $sth->fetchrow_array() ) {
			if ( $service ne 'modify' || $retained_services{ $values[0] } ) {
			    $host_service{ $values[0] } = $values[1];
			}
			else {
			    $sqlstmt = "delete from services where host_id = $hid and servicename_id = $values[0]";
			    eval { $dbh->do($sqlstmt); };
			    if ($@) {
				push @errors, "Error: $@";
				log_caller('', $sqlstmt, $@);
			    }
			}
		    }
		    push @errors, $sth->errstr if defined $sth->err;
		    $sth->finish;
		}

		foreach my $snid ( keys %profile_services ) {
		    unless ( $host_service{$snid} ) {
			$cnt++;
			my @values = (
			    \undef,                      $hid,
			    $profile_services{$snid}[0], $profile_services{$snid}[3],
			    $profile_services{$snid}[7], $profile_services{$snid}[6],
			    '1',                         $profile_services{$snid}[4],
			    $profile_services{$snid}[5], '',
			    ''
			);
			my $sid = insert_obj_id( '', 'services', \@values, 'service_id' );
			if ( $sid =~ /Error/ ) {
			    push @errors, $sid;
			}
			else {
			    $host_service{$snid} = $sid;
			    if ( $servicename_overrides{$snid} ) {
				my @values = (
				    $sid,
				    $servicename_overrides{$snid}[1],
				    $servicename_overrides{$snid}[2],
				    $servicename_overrides{$snid}[3],
				    $servicename_overrides{$snid}[4]
				);
				my $result = insert_obj( '', 'service_overrides', \@values );
				if ( $result =~ /Error/ ) {
				    push @errors, $result;
				}
			    }
			    if ( $contactgroups{$snid} ) {
				foreach my $cgid ( @{ $contactgroups{$snid} } ) {
				    ## my @values = ($cgid,'services',$sid);
				    ## my $result = insert_obj('','contactgroup_assign',\@values);
				    my @values = ( $cgid, $sid );
				    my $result = insert_obj( '', 'contactgroup_service', \@values );
				    if ( $result =~ /Error/ ) {
					push @errors, $result;
				    }
				}
			    }

			    # FIX LATER:  Should we modify this to do things differently for a merge, modify, or replace
			    # operation (i.e., depend on the passed-in $service value), in particular when this routine
			    # is being called to apply the service profiles associated with a particular host profile?
			    if ( $externals{$snid} ) {
				foreach my $external_id ( keys %{ $externals{$snid} } ) {
				    ## insert external_id, new host id, new service id, data, modified into external_service table
				    my @values = ( $external_id, $hid, $sid, $externals_display{$external_id}, $DEFINED_REF );
				    my $result = insert_obj( '', 'external_service', \@values );
				    if ( $result =~ /Error/ ) {
					push @errors, $result;
				    }
				}
			    }
			}
		    }
		}

		# FIX MINOR:  apply proper foreign key constraints to the service_dependency table, then
		# pull this query out of the enclosing loop over @hosts so it's not endlessly repeated,
		# with adjustments to emulate cascaded deletes in the table due to possible service
		# deletions above; and then perhaps fold the following loop into the one just above
		my %dep_hash = ();
		$sqlstmt = "select * from service_dependency";
		my $sth = $dbh->prepare($sqlstmt);
		$sth->execute;
		while ( my @values = $sth->fetchrow_array() ) {
		    $dep_hash{ $values[1] }{ $values[2] }{ $values[3] }{ $values[4] } = 1;
		}
		push @errors, $sth->errstr if defined $sth->err;
		$sth->finish;
		foreach my $snid ( keys %profile_services ) {
		    if ( $dependencies{$snid} ) {
			foreach my $did ( keys %{ $dependencies{$snid} } ) {
			    my $depend_on_host = $dependencies{$snid}{$did}[2];
			    unless ($depend_on_host) { $depend_on_host = $hid }
			    unless ( $dep_hash{ $host_service{$snid} }{$hid}{$depend_on_host}{ $dependencies{$snid}{$did}[3] } ) {
				my @values = ( \undef, $host_service{$snid}, $hid, $depend_on_host, $dependencies{$snid}{$did}[3], '' );
				my $result = insert_obj( '', 'service_dependency', \@values );
				if ( $result =~ /Error/ ) {
				    push @errors, $result;
				}
			    }
			}
		    }
		}
	    }
	}
    }
    return $cnt, \@errors;
}

sub apply_service_overrides() {
    my $sid    = $_[1];
    my $snid   = $_[2];
    my @errors = ();

    ## my $sqlstmt = "select contactgroup_id from contactgroup_assign where type = 'service_names' and object = '$snid'";
    my $sqlstmt = "select contactgroup_id from contactgroup_service_name where servicename_id = '$snid'";
    my $sth     = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	## my @vals = ($values[0],'services',$sid);
	## my $result = insert_obj('','contactgroup_assign',\@vals);
	my @vals = ( $values[0], $sid );
	my $result = insert_obj( '', 'contactgroup_service', \@vals );
	if ( $result =~ /Error/ ) { push @errors, $result }
    }
    $sth->finish;
    my @values = ($sid);
    $sqlstmt = "select check_period, notification_period, event_handler, data from servicename_overrides where servicename_id = '$snid'";
    my @vals = $dbh->selectrow_array($sqlstmt);
    if (@vals) {
	push( @values, @vals );
	my $result = insert_obj( '', 'service_overrides', \@values );
	if ( $result =~ /Error/ ) { push @errors, $result }
    }
    return @errors;
}

sub service_merge() {
    my $service   = $_[1];
    my %service   = %{$service};
    my %overrides = fetch_one( '', 'servicename_overrides', 'servicename_id', $service{'servicename_id'} );
    my %where     = ( 'servicename_id' => $service{'servicename_id'} );
    my @services  = fetch_list_where( '', 'services', 'service_id', \%where );
    my @errors    = ();
    my $cnt       = 0;
    my %so        = ();
    my $sqlstmt   = "select service_id from service_overrides";
    my $sth       = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @vals = $sth->fetchrow_array() ) { $so{ $vals[0] } = 1 }
    $sth->finish;

    foreach my $sid (@services) {
	$cnt++;
	my %over   = fetch_one( '', 'service_overrides', 'service_id', $sid );
	my %values = ();
	my $data   = "<?xml version=\"1.0\" encoding=\"iso-8859-1\" ?>\n<data>";
	foreach my $name ( keys %over ) {
	    $overrides{$name} = $over{$name};
	}
	foreach my $name ( keys %overrides ) {
	    if ( $name =~ /^check_period$|^notification_period$|^event_handler$/ ) {
		$values{$name} = $overrides{$name};
	    }
	    else {
		$data .= " <prop name=\"$name\"><![CDATA[$overrides{$name}]]>\n";
		$data .= " </prop>\n";
	    }
	}
	$data .= "\n</data>\n";
	$values{'data'} = $data;
	if ( $so{$sid} ) {
	    my $result = update_obj( '', 'service_overrides', 'service_id', $sid, \%values );
	    if ( $result =~ /Error/ ) { push @errors, $result }
	}
	else {
	    my @values = ( $sid, $values{'check_period'}, $values{'notification_period'}, $values{'event_handler'}, $values{'data'} );
	    my $result = insert_obj( '', 'service_overrides', \@values );
	    if ( $result =~ /Error/ ) { push @errors, $result }
	}
    }
    unless (@errors) { $errors[0] = "Changes applied to $cnt services." }
    return @errors;
}

sub service_replace() {
    my %service   = %{ $_[1] };
    my %overrides = fetch_one( '', 'servicename_overrides', 'servicename_id', $service{'servicename_id'} );
    my @errors    = ();
    my $cnt       = 0;
    my %so        = ();
    my $sqlstmt   = "select service_id from service_overrides";
    my $sth       = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @vals = $sth->fetchrow_array() ) { $so{ $vals[0] } = 1 }
    $sth->finish;
    my %where = ( 'servicename_id' => $service{'servicename_id'} );
    my @services = fetch_list_where( '', 'services', 'service_id', \%where );

    foreach my $sid (@services) {
	$cnt++;
	my %values = ();
	my $data   = "<?xml version=\"1.0\" encoding=\"iso-8859-1\" ?>\n<data>";
	foreach my $name ( keys %overrides ) {
	    if ( $name =~ /^check_period$|^notification_period$|^event_handler$/ ) {
		$values{$name} = $overrides{$name};
	    }
	    else {
		$data .= " <prop name=\"$name\"><![CDATA[$overrides{$name}]]>\n";
		$data .= " </prop>\n";
	    }
	}
	$data .= "\n</data>\n";
	$values{'data'} = $data;
	if ( $so{$sid} ) {
	    my $result = update_obj( '', 'service_overrides', 'service_id', $sid, \%values );
	    if ( $result =~ /Error/ ) { push @errors, $result }
	}
	else {
	    my @values = ( $sid, $values{'check_period'}, $values{'notification_period'}, $values{'event_handler'}, $values{'data'} );
	    my $result = insert_obj( '', 'service_overrides', \@values );
	    if ( $result =~ /Error/ ) { push @errors, $result }
	}
    }
    unless (@errors) { $errors[0] = "Changes applied to $cnt services." }
    return @errors;
}

sub clone_service(@) {
    my $name            = $_[1];
    my $clone_service   = $_[2];
    my $assign_profiles = $_[3];
    my @errors          = ();
    my @values          = ( \undef, $name );
    my $sqlstmt =
"select description, template, check_command, command_line, escalation, extinfo, data, servicename_id from service_names where name = '$clone_service'";
    my @vals             = $dbh->selectrow_array($sqlstmt);
    my $clone_service_id = pop @vals;
    push( @values, @vals );
    my $id = insert_obj_id( '', 'service_names', \@values, 'servicename_id' );
    if ( $id =~ /Error/ ) { push @errors, $id }

    unless (@errors) {
	@values = ($id);
	$sqlstmt =
	  "select check_period, notification_period, event_handler, data from servicename_overrides where servicename_id = '$clone_service_id'";

	# push @errors, $sqlstmt;
	@vals = $dbh->selectrow_array($sqlstmt);
	if (@vals) {
	    push( @values, @vals );
	    my $result = insert_obj( '', 'servicename_overrides', \@values );
	    if ( $result =~ /Error/ ) { push @errors, $result }
	}
	unless (@errors) {
	    $sqlstmt = "select depend_on_host_id, template from servicename_dependency where servicename_id = '$clone_service_id'";
	    my $sth = $dbh->prepare($sqlstmt);
	    $sth->execute;
	    while ( my @vals = $sth->fetchrow_array() ) {
		@values = ( \undef, $id );
		push( @values, @vals );
		my $result = insert_obj( '', 'servicename_dependency', \@values );
		if ( $result =~ /Error/ ) { push @errors, $result }
	    }
	    $sth->finish;
	    unless (@errors) {
		## my %where = ('type' => 'service_names', 'object' => $clone_service_id);
		## my @cgids = fetch_list_where('','contactgroup_assign','contactgroup_id',\%where);
		my %where = ( 'servicename_id' => $clone_service_id );
		my @cgids = fetch_list_where( '', 'contactgroup_service_name', 'contactgroup_id', \%where );
		foreach my $cgid (@cgids) {
		    ## @values = ($cgid,'service_names',$id);
		    ## my $result = insert_obj('','contactgroup_assign',\@values);
		    @values = ( $cgid, $id );
		    my $result = insert_obj( '', 'contactgroup_service_name', \@values );
		    if ( $result =~ /Error/ ) { push @errors, $result }
		}
		if ($assign_profiles) {
		    %where = ( 'servicename_id' => $clone_service_id );
		    my @pids = fetch_list_where( '', 'serviceprofile', 'serviceprofile_id', \%where );
		    foreach my $pid (@pids) {
			@values = ( $id, $pid );
			my $result = insert_obj( '', 'serviceprofile', \@values );
			if ( $result =~ /Error/ ) { push @errors, $result }
		    }
		}
	    }
	}
    }
    return @errors;
}

sub clone_host(@) {
    my $host             = $_[1];
    my $clone_name       = $_[2];
    my $clone_alias      = $_[3];
    my $clone_address    = $_[4];
    my @errors           = ();
    my %host             = fetch_one( '', 'hosts', 'name', $host );
    my %where            = ( 'host_id' => $host{'host_id'} );
    my @hostgroups       = fetch_list_where( '', 'hostgroup_host', 'hostgroup_id', \%where );
    my @parents          = fetch_list_where( '', 'host_parent', 'parent_id', \%where );
    my @service_profiles = fetch_list_where( '', 'serviceprofile_host', 'serviceprofile_id', \%where );
    my @contactgroups    = fetch_list_where( '', 'contactgroup_host', 'contactgroup_id', \%where );
    my @values           = (
	\undef, $clone_name, $clone_alias, $clone_address, $host{'os'},
	$host{'hosttemplate_id'}, $host{'hostextinfo_id'}, $host{'hostprofile_id'},
	$host{'host_escalation_id'}, $host{'service_escalation_id'}, '1', '', $host{'notes'}
    );
    my $id = insert_obj_id( '', 'hosts', \@values, 'host_id' );
    if ( $id =~ /Error/ ) { push @errors, $id }
    my @host_over = ($id);
    my $sqlstmt   = "select * from host_overrides where host_id = '$host{'host_id'}'";
    my $sth       = $dbh->prepare($sqlstmt);
    $sth->execute;
    my $values = $sth->fetchrow_hashref();
    $sth->finish;

    if (   $values->{'check_period'}
	|| $values->{'notification_period'}
	|| $values->{'check_command'}
	|| $values->{'event_handler'}
	|| $values->{'data'} )
    {
	@values = (
	    $id,
	    $values->{'check_period'},
	    $values->{'notification_period'},
	    $values->{'check_command'},
	    $values->{'event_handler'},
	    $values->{'data'}
	);
	my $result = insert_obj( '', 'host_overrides', \@values );
	if ( $result =~ /Error/ ) { push @errors, $result }
    }
    foreach my $hg (@hostgroups) {
	@values = ( $hg, $id );
	my $result = insert_obj( '', 'hostgroup_host', \@values );
	if ( $result =~ /Error/ ) { push @errors, $result }
    }
    foreach my $p (@parents) {
	@values = ( $id, $p );
	my $result = insert_obj( '', 'host_parent', \@values );
	if ( $result =~ /Error/ ) { push @errors, $result }
    }
    foreach my $sp (@service_profiles) {
	@values = ( $sp, $id );
	my $result = insert_obj( '', 'serviceprofile_host', \@values );
	if ( $result =~ /Error/ ) { push @errors, $result }
    }
    foreach my $cg (@contactgroups) {
	@values = ( $cg, $id );
	my $result = insert_obj( '', 'contactgroup_host', \@values );
	if ( $result =~ /Error/ ) { push @errors, $result }
    }

    # Handle host externals.
    $sqlstmt = "select external_id, data, modified from external_host where host_id = '$host{'host_id'}'";
    $sth = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @vals = $sth->fetchrow_array() ) {
	@vals = ( $vals[0], $id, $vals[1], $vals[2] || $DEFINED_REF );
	my $result = insert_obj( '', 'external_host', \@vals );
	if ( $result =~ /Error/ ) { push @errors, $result }
    }
    $sth->finish;

    $sqlstmt = "select * from services where host_id = '$host{'host_id'}'";
    $sth     = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	my @vals = ( \undef, $id, @values[2..10] );
	my $sid = insert_obj_id( '', 'services', \@vals, 'service_id' );
	if ( $sid =~ /Error/ ) { push @errors, $sid }
	unless (@errors) {
	    $sqlstmt = "select name, status, arguments from service_instance where service_id = '$values[0]'";
	    my $sth2 = $dbh->prepare($sqlstmt);
	    $sth2->execute;
	    while ( my @vals = $sth2->fetchrow_array() ) {
		@vals = ( \undef, $sid, $vals[0], $vals[1], $vals[2] );
		my $result = insert_obj( '', 'service_instance', \@vals );
		if ( $result =~ /Error/ ) { push @errors, $result }
	    }
	    $sth2->finish;
	    $sqlstmt = "select * from service_overrides where service_id = '$values[0]'";
	    $sth2    = $dbh->prepare($sqlstmt);
	    $sth2->execute;
	    my $ovals = $sth2->fetchrow_hashref();
	    if (   $ovals->{'check_period'}
		|| $ovals->{'notification_period'}
		|| $ovals->{'event_handler'}
		|| $ovals->{'data'} )
	    {
		@vals = ( $sid, $ovals->{'check_period'}, $ovals->{'notification_period'}, $ovals->{'event_handler'}, $ovals->{'data'} );
		my $result = insert_obj( '', 'service_overrides', \@vals );
		if ( $result =~ /Error/ ) { push @errors, $result }
	    }
	    $sth2->finish;
	    $sqlstmt = "select host_id, depend_on_host_id, template from service_dependency where service_id = '$values[0]'";
	    $sth2    = $dbh->prepare($sqlstmt);
	    $sth2->execute;
	    while ( my @vals = $sth2->fetchrow_array() ) {
		if ( $vals[0] eq $vals[1] ) { $vals[1] = $id }
		@vals = ( \undef, $sid, $id, $vals[1], $vals[2], '' );
		my $result = insert_obj( '', 'service_dependency', \@vals );
		if ( $result =~ /Error/ ) { push @errors, $result }
	    }
	    $sth2->finish;
	    my %w = ( 'service_id' => $values[0] );
	    my @contactgroups = fetch_list_where( '', 'contactgroup_service', 'contactgroup_id', \%w );
	    foreach my $cg (@contactgroups) {
		@vals = ( $cg, $sid );
		my $result = insert_obj( '', 'contactgroup_service', \@vals );
		if ( $result =~ /Error/ ) { push @errors, $result }
	    }

	    # Handle service externals.
	    # Trying to populate external_service table - external_id, host_id, service_id, data, modified
	    # Get external data for this service
	    $sqlstmt = "select external_id, data, modified from external_service where host_id = '$host{'host_id'}' and service_id = '$values[0]'";
	    $sth2    = $dbh->prepare($sqlstmt);
	    $sth2->execute;
	    while ( my @vals = $sth2->fetchrow_array() ) {
		## insert external_id, new host id, new service id, data, modified into external_service table
		@vals = ( $vals[0], $id, $sid, $vals[1], $vals[2] || $DEFINED_REF );
		my $result = insert_obj( '', 'external_service', \@vals );
		if ( $result =~ /Error/ ) { push @errors, $result }
	    }
	    $sth2->finish;
	}
    }
    $sth->finish;
    if (@errors) {
	my %w = ( 'host_id' => $id );
	delete_one_where( '', 'hosts', \%w );
    }
    return @errors;
}

sub copy_servicename(@) {
    my $copy_snid = $_[1];
    my $name      = $_[2];
    my $sqlstmt =
"select description, template, check_command, command_line, escalation, extinfo, data from service_names where servicename_id = '$copy_snid'";
    my @vals = $dbh->selectrow_array($sqlstmt);
    my @values = ( \undef, $name );
    push( @values, @vals );
    my $servicename_id = insert_obj_id( '', 'service_names', \@values, 'servicename_id' );
    $sqlstmt = "select check_period, notification_period, event_handler, data from servicename_overrides where servicename_id = '$copy_snid'";
    @vals    = $dbh->selectrow_array($sqlstmt);
    if (@vals) {
	@values = ($servicename_id);
	push( @values, @vals );
	my $result = insert_obj( '', 'servicename_overrides', \@values );
    }
    return $servicename_id;
}

sub copy_service_template(@) {
    my $copy_name = $_[1];
    my $name      = $_[2];
    my $sqlstmt   = "select * from service_templates where name = '$copy_name'";
    my @values    = $dbh->selectrow_array($sqlstmt);
    my $copy_id   = $values[0];
    $values[0] = \undef;
    $values[1] = $name;
    $values[9] = undef;  # empty the comment field
    my $servicetemplate_id = insert_obj_id( '', 'service_templates', \@values, 'servicetemplate_id' );
    return $servicetemplate_id if $servicetemplate_id =~ /^Error/;

    my @cgids = fetch_unique( '', 'contactgroup_service_template', 'contactgroup_id', 'servicetemplate_id', $copy_id );
    foreach my $cgid (@cgids) {
	@values = ($cgid, $servicetemplate_id);
	my $contactgroup_id = insert_obj_id( '', 'contactgroup_service_template', \@values, 'contactgroup_id' );
	if ($contactgroup_id =~ /^Error/) {
	    delete_all( '', 'service_templates', 'servicetemplate_id', $servicetemplate_id );
	    return $contactgroup_id;
	}
    }
    return $servicetemplate_id;
}

sub get_possible_parents() {
    my $template_id      = $_[1];
    my @possible_parents = ();
    my %templates        = ();
    my $sqlstmt          = "select servicetemplate_id, name from service_templates";
    my $sth              = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	$templates{ $values[0] } = $values[1];
    }
    $sth->finish;
    delete $templates{$template_id};
    $sqlstmt = "select servicetemplate_id from service_templates where parent_id = '$template_id'";
    $sth     = $dbh->prepare($sqlstmt);
    $sth->execute;
    my %children = ();
    while ( my @values = $sth->fetchrow_array() ) {
	$children{ $values[0] } = 1;
    }
    $sth->finish;
    my $got_children = 0;
    until ($got_children) {
	my %gchildren = ();
	$got_children = 1;
	foreach my $cid ( keys %children ) {
	    if ( exists $templates{$cid} ) {
		delete $templates{$cid};
		$sqlstmt = "select servicetemplate_id from service_templates where parent_id = '$cid'";
		$sth     = $dbh->prepare($sqlstmt);
		$sth->execute;
		while ( my @values = $sth->fetchrow_array() ) {
		    $gchildren{ $values[0] } = 1;
		    $got_children = 0;
		}
		$sth->finish;
	    }
	}
	%children = %gchildren;
    }

    # Let the user see the current parent, even (especially) if it's part of a
    # cyclical chain, so the need to change it is apparent.  Ugly, but necessary.
    $sqlstmt = "select parent.servicetemplate_id, parent.name from service_templates as child join service_templates as parent "
      . "on parent.servicetemplate_id = child.parent_id where child.servicetemplate_id = '$template_id'";
    $sth = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	$templates{ $values[0] } = $values[1];
    }
    $sth->finish;

    foreach my $t ( keys %templates ) { push @possible_parents, $templates{$t} }
    @possible_parents = sort @possible_parents;
    return @possible_parents;
}

sub host_has_service_profile_via_host {
    my $host_id           = $dbh->quote( $_[1] );
    my $serviceprofile_id = $dbh->quote( $_[2] );

    my $sqlstmt = "select count(*) from serviceprofile_host sph
	where sph.serviceprofile_id = $serviceprofile_id and sph.host_id = $host_id";
    my $rows = $dbh->selectrow_array($sqlstmt);
    return $rows;
}

sub host_has_service_profile_via_hostgroup {
    my $host_id           = $dbh->quote( $_[1] );
    my $serviceprofile_id = $dbh->quote( $_[2] );

    my $sqlstmt = "select count(*) from serviceprofile_hostgroup sphg, hostgroup_host hgh
	where sphg.serviceprofile_id = $serviceprofile_id and hgh.hostgroup_id = sphg.hostgroup_id and hgh.host_id = $host_id";
    my $rows = $dbh->selectrow_array($sqlstmt);
    return $rows;
}

sub host_has_service_profile_via_hostprofile {
    my $host_id           = $dbh->quote( $_[1] );
    my $serviceprofile_id = $dbh->quote( $_[2] );

    my $sqlstmt = "select count(*) from hosts h, profile_host_profile_service phps
	where h.host_id = $host_id and phps.hostprofile_id = h.hostprofile_id and phps.serviceprofile_id = $serviceprofile_id";
    my $rows = $dbh->selectrow_array($sqlstmt);
    return $rows;
}

sub get_service_profiles(@) {
    my $spid          = $_[1];
    my %service_names = ();
    my $sqlstmt =
"select servicename_id, name from service_names where servicename_id in (select servicename_id from serviceprofile where serviceprofile_id = '$spid')";
    my $sth = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	$service_names{ $values[1] } = $values[0];
    }
    $sth->finish;
    return %service_names;
}

sub get_host_profile_service_profiles(@) {
    my $hpid             = $_[1];
    my %service_profiles = ();
    my $sqlstmt =
"select serviceprofile_id, name from profiles_service where serviceprofile_id in (select serviceprofile_id from profile_host_profile_service where hostprofile_id = '$hpid')";
    my $sth = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	$service_profiles{ $values[1] } = $values[0];
    }
    $sth->finish;
    return %service_profiles;
}

sub get_service_profile_services(@) {
    my $profile_id = $_[1];
    my %services   = ();
    my $sqlstmt =
	"select service_names.name, service_names.template, service_templates.name, commands.name, service_names.command_line, "
      . "extended_service_info_templates.name "
      . "from service_names left join commands on service_names.check_command = commands.command_id "
      . "left join service_templates on service_templates.servicetemplate_id = service_names.template "
      . "left join extended_service_info_templates on extended_service_info_templates.serviceextinfo_id = service_names.extinfo "
      . "where service_names.servicename_id in (select servicename_id from serviceprofile where serviceprofile_id = '$profile_id')";
    my $sth = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	if ( $values[4] ) {
	    $values[3] = $values[4];
	}
	unless ( $values[3] ) {
	    my $got_parent   = 0;
	    my $temp_id      = $values[1];
	    my %already_seen = ();
	    until ( $values[3] || $got_parent ) {
		my $sql =
		    "select commands.name, service_templates.command_line, service_templates.parent_id "
		  . "from service_templates left join commands on service_templates.check_command = commands.command_id "
		  . "where service_templates.servicetemplate_id = '$temp_id'";
		my $sth2 = $dbh->prepare($sql);
		$sth2->execute;
		my @vals = $sth2->fetchrow_array();
		$sth2->finish;
		$values[3] = $vals[1] || $vals[0];
		$already_seen{$temp_id} = 1;
		$got_parent = 1;

		if ( !$values[3] && $vals[2] && !$already_seen{ $vals[2] } ) {
		    $temp_id    = $vals[2];
		    $got_parent = 0;
		}
	    }
	}
	$services{ $values[0] }{'template'}   = $values[2];
	$services{ $values[0] }{'command'}    = $values[3];
	$services{ $values[0] }{'dependency'} = $values[5];
	$services{ $values[0] }{'extinfo'}    = $values[6];
    }
    $sth->finish;
    return %services;
}

sub get_service_detail(@) {
    my $name    = $_[1];
    my %service = ();
    my $sqlstmt =
	"select service_names.name, service_names.template, service_templates.name, commands.name, service_names.command_line, "
      . "extended_service_info_templates.name "
      . "from service_names left join commands on service_names.check_command = commands.command_id "
      . "left join service_templates on service_templates.servicetemplate_id = service_names.template "
      . "left join extended_service_info_templates on extended_service_info_templates.serviceextinfo_id = service_names.extinfo "
      . "where service_names.name = '$name'";
    my $sth = $dbh->prepare($sqlstmt);
    $sth->execute;
    my @values = $sth->fetchrow_array();
    $sth->finish;
    if ( $values[4] ) {
	$values[3] = $values[4];
    }
    unless ( $values[3] ) {
	my $got_parent   = 0;
	my $temp_id      = $values[1];
	my %already_seen = ();
	until ( $values[3] || $got_parent ) {
	    my $sql =
		"select commands.name, service_templates.command_line, service_templates.parent_id "
	      . "from service_templates left join commands on service_templates.check_command = commands.command_id "
	      . "where service_templates.servicetemplate_id = '$temp_id'";
	    my $sth2 = $dbh->prepare($sql);
	    $sth2->execute;
	    my @vals = $sth2->fetchrow_array();
	    $sth2->finish;
	    $values[3] = $vals[1] || $vals[0];
	    $already_seen{$temp_id} = 1;
	    $got_parent = 1;

	    if ( !$values[3] && $vals[2] && !$already_seen{ $vals[2] } ) {
		$temp_id    = $vals[2];
		$got_parent = 0;
	    }
	}
    }
    $service{ $values[0] }{'template'} = $values[2];
    $service{ $values[0] }{'command'}  = $values[3];
    $service{ $values[0] }{'extinfo'}  = $values[6];
    return %service;
}

sub get_service_dependencies(@) {
    my $snid                 = $_[1];
    my %service_dependencies = ();
    my $sqlstmt =
"select id, name from service_dependency_templates where id in (select template from servicename_dependency where servicename_id = '$snid' and depend_on_host_id is null)";
    my $sth = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	$service_dependencies{ $values[1] } = $values[0];
    }
    $sth->finish;
    return %service_dependencies;
}

# FIX MINOR:  use a left join instead of nested queries; use a simple count of keys for $host_count
sub get_hosts_services() {
    my %hosts_services = ();
    my %hosts          = ();
    my $sqlstmt        = "select name, host_id from hosts";
    my $sth            = $dbh->prepare($sqlstmt);
    my $host_count     = 0;
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	$hosts{ $values[0] } = $values[1];
	$host_count++;
    }
    $sth->finish;
    foreach my $host ( sort keys %hosts ) {
	@{ $hosts_services{$host} } = ();
	$sqlstmt =
"select service_names.name from service_names where servicename_id in (select servicename_id from services where host_id = '$hosts{$host}')";
	$sth = $dbh->prepare($sqlstmt);
	$sth->execute;
	while ( my @values = $sth->fetchrow_array() ) {
	    push @{ $hosts_services{$host} }, $values[0];
	}
	$sth->finish;
    }
    ## FIX LATER:  bad idea to contaminate this hash; caller should count keys instead
    $hosts_services{'host_count'} = $host_count;
    return %hosts_services;
}

# Unstable interface, subject to change across releases.
sub get_hosts_services_for_sync() {
    my %hosts_services = ();

    # FIX LATER:  use left joins instead?  if so, the nulls that might result have to be anticipated and dealt with downstream
    # my $sqlstmt = "select hosts.name, service_names.name, services.service_id, services.notes, services.serviceextinfo_id from hosts left join services using (host_id) left join service_names using (servicename_id)";
    my $sqlstmt = "select hosts.name, service_names.name, services.service_id, services.notes, services.serviceextinfo_id from hosts join services using (host_id) join service_names using (servicename_id)";
    my $sth     = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	$hosts_services{ $values[0] }{ $values[2] }{'name'}              = $values[1];
	$hosts_services{ $values[0] }{ $values[2] }{'notes'}             = $values[3];
	$hosts_services{ $values[0] }{ $values[2] }{'serviceextinfo_id'} = $values[4];
    }
    $sth->finish;
    return \%hosts_services;
}

# Unstable interface, subject to change across releases.
sub get_service_instances_status_for_sync(@) {
    my %statuses = ();
    my $sqlstmt  = "select service_id, name, status from service_instance";
    my $sth      = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	## status from the database will be 1 if the instance is active,
	## NULL (recoded here from undef to 0) if the instance is inactive.
	## {service_id, name} is unique by database constraint.
	$statuses{ $values[0] }{ $values[1] } = $values[2] || 0;
    }
    $sth->finish;
    return \%statuses;
}

# Unstable interface, subject to change across releases.
sub get_service_instances_for_externals(@) {
    my %service_instances = ();
    my $sqlstmt           = "select service_id, name, status, inherit_ext_args, externals_arguments from service_instance";
    my $sth               = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	## status from the database will be 1 if the instance is active,
	## NULL (undef here) if the instance is inactive.
	## {service_id, name} is unique by database constraint.
	$service_instances{ $values[0] }{ $values[1] } = [ $values[2], $values[3], $values[4] ];
    }
    $sth->finish;
    return \%service_instances;
}

# Unstable interface, subject to change across releases.
sub get_host_services_for_externals(@) {
    my %host_services = ();
    my $sqlstmt       = "select service_id, servicename_id, inherit_ext_args, externals_arguments from services";
    my $sth           = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	$host_services{ $values[0] } = [ $values[1], $values[2], $values[3] ];
    }
    $sth->finish;
    return \%host_services;
}

# Unstable interface, subject to change across releases.
sub get_generic_services_for_externals(@) {
    my %generic_services = ();
    my $sqlstmt          = "select servicename_id, name, externals_arguments from service_names";
    my $sth              = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	$generic_services{ $values[0] } = [ $values[1], $values[2] ];
    }
    $sth->finish;
    return \%generic_services;
}

sub get_host_services_detail(@) {
    my $host_id  = $_[1];
    my %services = ();
    my $sqlstmt  = "select * from services where host_id = '$host_id'";
    my $sth      = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	$services{ $values[0] }{'id'}                 = $values[0];
	$services{ $values[0] }{'servicename_id'}     = $values[2];
	$services{ $values[0] }{'servicetemplate_id'} = $values[3];
	$services{ $values[0] }{'serviceextinfo_id'}  = $values[4];
	$services{ $values[0] }{'check_command'}      = $values[7];
	$services{ $values[0] }{'command_line'}       = $values[8];
	$services{ $values[0] }{'comment'}            = $values[9];
	$sqlstmt                                      = "select * from service_overrides where service_id = '$values[0]'";
	my $sth2 = $dbh->prepare($sqlstmt);
	$sth2->execute;

	while ( my @vals = $sth2->fetchrow_array() ) {
	    $services{ $values[0] }{'check_period'}        = $vals[1];
	    $services{ $values[0] }{'notification_period'} = $vals[2];
	    $services{ $values[0] }{'event_handler'}       = $vals[3];
	    my %data = parse_xml( '', $vals[4] );
	    foreach my $prop ( keys %data ) {
		$services{ $values[0] }{$prop} = $data{$prop};
	    }
	}
	$sth2->finish;

	## $sqlstmt = "select contactgroups.name from contactgroups where contactgroup_id in "
	##   . "(select contactgroup_id from contactgroup_assign where type = 'services' and object = '$values[0]')";
	$sqlstmt = "select contactgroups.name from contactgroups where contactgroup_id in "
	  . "(select contactgroup_id from contactgroup_service where service_id = '$values[0]')";
	$sth2 = $dbh->prepare($sqlstmt);
	$sth2->execute;
	@{ $services{ $values[0] }{'contactgroups'} } = ();
	while ( my @vals = $sth2->fetchrow_array() ) {
	    push @{ $services{ $values[0] }{'contactgroups'} }, $vals[0];
	}
	$sth2->finish;
    }
    $sth->finish;
    return %services;
}

sub get_service_instances(@) {
    my $sid       = $_[1];
    my %instances = ();
    my $sqlstmt   = "select * from service_instance where service_id = '$sid'";
    my $sth       = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	$instances{ $values[2] }{'id'}           = $values[0];
	$instances{ $values[2] }{'status'}       = $values[3];
	$instances{ $values[2] }{'args'}         = $values[4];
	$instances{ $values[2] }{'ext_args'}     = $values[5];
	$instances{ $values[2] }{'inh_ext_args'} = $values[6];
    }
    $sth->finish;
    return %instances;
}

sub get_service_instances_names(@) {
    my $sid       = $_[1];
    my %instances = ();
    my $sqlstmt   = "select * from service_instance where service_id = '$sid'";
    my $sth       = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	$instances{ $values[0] }{'name'} = $values[2];
    }
    $sth->finish;
    return %instances;
}

# Just the active instances for sync (but:  don't we also need to know if there are inactive instances?)
sub get_active_service_instances_names(@) {
    my $sid       = $_[1];
    my %instances = ();
    ## FIX MAJOR:  revisit this to see if we should check for status differently
    my $sqlstmt   = "select * from service_instance where service_id = '$sid' AND NOT status is NULL";
    my $sth       = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	$instances{ $values[0] }{'name'} = $values[2];
    }
    $sth->finish;
    return %instances;
}

sub ez_defaults() {
    my %objects = ();
    my $sqlstmt = "select name, value from setup where type = 'monarch_ez'";
    my $sth     = $dbh->prepare($sqlstmt);
    $sth->execute;
    my %tables = (
	'host_profile'     => 'profiles_host',
	'contact_template' => 'contact_templates',
	'contactgroup'     => 'contactgroups'
    );
    while ( my @values = $sth->fetchrow_array() ) {
	my %obj = fetch_one( '', $tables{ $values[0] }, 'name', $values[1] );
	if ( $obj{'name'} ) {
	    $objects{ $values[0] } = $values[1];
	}
	else {
	    $objects{ $values[0] } = 'not_defined';
	}
    }
    $sth->finish;
    return %objects;
}

sub get_objects() {
    my %objects = ();
    my $sqlstmt = "select value, name from setup where type = 'resource'";
    my $sth     = undef;
    eval {
	$sth = $dbh->prepare($sqlstmt);
	$sth->execute;
    };
    if ($@) {
	$objects{'errors'}{'commands'} = "Error: $@";
	log_caller('', $sqlstmt, $@);
    }
    else {
	while ( my @values = $sth->fetchrow_array() ) {
	    $objects{'resources'}{ $values[1] } = $values[0];
	}
    }
    $sth->finish;

    $sqlstmt = "select command_id, name from commands";
    eval {
	$sth = $dbh->prepare($sqlstmt);
	$sth->execute;
    };
    if ($@) {
	$objects{'errors'}{'commands'} = "Error: $@";
	log_caller('', $sqlstmt, $@);
    }
    else {
	while ( my @values = $sth->fetchrow_array() ) {
	    $objects{'commands'}{ $values[1] } = $values[0];
	}
    }
    $sth->finish;

    $sqlstmt = "select timeperiod_id, name from time_periods";
    eval {
	$sth = $dbh->prepare($sqlstmt);
	$sth->execute;
    };
    if ($@) {
	$objects{'errors'}{'time_periods'} = "Error: $@";
	log_caller('', $sqlstmt, $@);
    }
    else {
	while ( my @values = $sth->fetchrow_array() ) {
	    $objects{'time_periods'}{ $values[1] } = $values[0];
	}
    }
    $sth->finish;

    $sqlstmt = "select hosttemplate_id, name from host_templates";
    eval {
	$sth = $dbh->prepare($sqlstmt);
	$sth->execute;
    };
    if ($@) {
	$objects{'errors'}{'host_templates'} = "Error: $@";
	log_caller('', $sqlstmt, $@);
    }
    else {
	while ( my @values = $sth->fetchrow_array() ) {
	    $objects{'host_templates'}{ $values[1] } = $values[0];
	}
    }
    $sth->finish;

    $sqlstmt = "select hostextinfo_id, name from extended_host_info_templates";
    eval {
	$sth = $dbh->prepare($sqlstmt);
	$sth->execute;
    };
    if ($@) {
	$objects{'errors'}{'extended_host_info_templates'} = "Error: $@";
	log_caller('', $sqlstmt, $@);
    }
    else {
	while ( my @values = $sth->fetchrow_array() ) {
	    $objects{'extended_host_info_templates'}{ $values[1] } = $values[0];
	}
    }
    $sth->finish;

    $sqlstmt = "select serviceextinfo_id, name from extended_service_info_templates";
    eval {
	$sth = $dbh->prepare($sqlstmt);
	$sth->execute;
    };
    if ($@) {
	$objects{'errors'}{'extended_service_info_templates'} = "Error: $@";
	log_caller('', $sqlstmt, $@);
    }
    else {
	while ( my @values = $sth->fetchrow_array() ) {
	    $objects{'extended_service_info_templates'}{ $values[1] } = $values[0];
	}
    }
    $sth->finish;

    $sqlstmt = "select servicetemplate_id, name from service_templates";
    eval {
	$sth = $dbh->prepare($sqlstmt);
	$sth->execute;
    };
    if ($@) {
	$objects{'errors'}{'service_templates'} = "Error: $@";
	log_caller('', $sqlstmt, $@);
    }
    else {
	while ( my @values = $sth->fetchrow_array() ) {
	    $objects{'service_templates'}{ $values[1] } = $values[0];
	}
    }
    $sth->finish;

    $sqlstmt = "select servicename_id, name from service_names";
    eval {
	$sth = $dbh->prepare($sqlstmt);
	$sth->execute;
    };
    if ($@) {
	$objects{'errors'}{'service_names'} = "Error: $@";
	log_caller('', $sqlstmt, $@);
    }
    else {
	while ( my @values = $sth->fetchrow_array() ) {
	    $objects{'service_names'}{ $values[1] } = $values[0];
	}
    }
    $sth->finish;

    $sqlstmt = "select serviceprofile_id, name from profiles_service";
    eval {
	$sth = $dbh->prepare($sqlstmt);
	$sth->execute;
    };
    if ($@) {
	$objects{'errors'}{'profiles_service'} = "Error: $@";
	log_caller('', $sqlstmt, $@);
    }
    else {
	while ( my @values = $sth->fetchrow_array() ) {
	    $objects{'profiles_service'}{ $values[1] } = $values[0];
	}
    }
    $sth->finish;

    $sqlstmt = "select hostprofile_id, name from profiles_host";
    eval {
	$sth = $dbh->prepare($sqlstmt);
	$sth->execute;
    };
    if ($@) {
	$objects{'errors'}{'profiles_host'} = "Error: $@";
	log_caller('', $sqlstmt, $@);
    }
    else {
	while ( my @values = $sth->fetchrow_array() ) {
	    $objects{'profiles_host'}{ $values[1] } = $values[0];
	}
    }
    $sth->finish;

    $sqlstmt = "select external_id, name from externals";
    eval {
	$sth = $dbh->prepare($sqlstmt);
	$sth->execute;
    };
    if ($@) {
	$objects{'errors'}{'profiles_host'} = "Error: $@";
	log_caller('', $sqlstmt, $@);
    }
    else {
	while ( my @values = $sth->fetchrow_array() ) {
	    $objects{'externals'}{ $values[1] } = $values[0];
	}
    }
    $sth->finish;

    return %objects;
}

sub get_table_objects(@) {
    my $table    = $_[1];
    my $id_name  = $_[2];
    my %objects  = ();
    my %table_id = (
	'time_periods'                    => 'timeperiod_id',
	'commands'                        => 'command_id',
	'contactgroups'                   => 'contactgroup_id',
	'contacts'                        => 'contact_id',
	'contact_templates'               => 'contacttemplate_id',
	'discover_method'                 => 'method_id',
	'discover_group'                  => 'group_id',
	'import_schema'                   => 'schema_id',
	'extended_host_info_templates'    => 'hostextinfo_id',
	'extended_service_info_templates' => 'serviceextinfo_id',
	'hosts'                           => 'host_id',
	'host_templates'                  => 'hosttemplate_id',
	'monarch_macros'                  => 'macro_id',
	'monarch_groups'                  => 'group_id',
	'hostgroups'                      => 'hostgroup_id',
	'servicegroups'                   => 'servicegroup_id',
	'service_names'                   => 'servicename_id',
	'service_templates'               => 'servicetemplate_id',
	'escalation_templates'            => 'template_id',
	'escalation_trees'                => 'tree_id',
	'externals'                       => 'external_id',
	'profiles_service'                => 'serviceprofile_id',
	'profiles_host'                   => 'hostprofile_id'
    );
    my $sqlstmt = "select name, $table_id{$table} from $table";
    my $sth     = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	if ($id_name) {
	    $objects{ $values[1] } = $values[0];
	}
	else {
	    $objects{ $values[0] } = $values[1];
	}
    }
    $sth->finish;
    return %objects;
}

sub purge(@) {
    my $purge_option      = $_[1];
    my $escalation_option = $_[2];

    StorProc->delete_all( 'setup', 'type', 'file' );
    my %tables  = ();
    my $sqlstmt =
	( defined($dbtype) && $dbtype eq 'postgresql' )
	? 'select table_name from information_schema.tables where table_catalog = current_catalog and table_schema = current_schema'
	: 'show tables';
    my $sth     = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	$tables{ $values[0] } = 1;
    }
    $sth->finish;

    ## Preserve these tables under all purging options.
    ## Unless listed, all other tables will be truncated.
    delete $tables{'sessions'};
    delete $tables{'monarch_groups'};
    delete $tables{'monarch_group_child'};
    delete $tables{'monarch_group_macro'};
    delete $tables{'monarch_group_props'};
    delete $tables{'monarch_macros'};
    delete $tables{'users'};
    delete $tables{'user_groups'};
    delete $tables{'user_group'};
    delete $tables{'access_list'};
    delete $tables{'setup'};
    delete $tables{'users'};
    delete $tables{'datatype'};
    delete $tables{'host_service'};
    delete $tables{'import_services'};
    delete $tables{'import_hosts'};
    delete $tables{'import_schema'};
    delete $tables{'import_column'};
    delete $tables{'import_match'};
    delete $tables{'import_match_contactgroup'};
    delete $tables{'import_match_group'};
    delete $tables{'import_match_hostgroup'};
    delete $tables{'import_match_parent'};
    delete $tables{'import_match_serviceprofile'};

    if ( $purge_option eq 'purge_nice' ) {
	## Preserve these additional tables under this option.
	delete $tables{'monarch_group_host'};
	delete $tables{'monarch_group_hostgroup'};
	delete $tables{'commands'};
	delete $tables{'timeperiods'};
	delete $tables{'profile_hostgroup'};
	delete $tables{'profile_parent'};
	delete $tables{'profiles_host'};
	delete $tables{'host_templates'};
	delete $tables{'hostgroup_host'};
	delete $tables{'hostgroups'};
	delete $tables{'hostprofile_overrides'};
	delete $tables{'hosts'};
	delete $tables{'contact_command'};
	delete $tables{'contact_command_overrides'};
	delete $tables{'contact_overrides'};
	delete $tables{'contact_templates'};
	## delete $tables{'contactgroup_assign'};
	delete $tables{'contactgroup_contact'};
	delete $tables{'contactgroups'};
	delete $tables{'contacts'};
	delete $tables{'host_dependencies'};
	delete $tables{'host_overrides'};
	delete $tables{'host_parent'};
	delete $tables{'external_host'};
	delete $tables{'external_host_profile'};
	delete $tables{'extended_host_info_templates'};
	delete $tables{'extended_info_coords'};
	delete $tables{'externals'};
	delete $tables{'profiles_service'};
	delete $tables{'serviceprofile'};
	delete $tables{'serviceprofile_host'};
	delete $tables{'serviceprofile_hostgroup'};

	## $dbh->do("delete from contactgroup_assign where type = 'services'");
	## $dbh->do("delete from contactgroup_assign where type = 'service_templates'");
    }
    if ( $purge_option eq 'update' ) {
	## In this update case, list all the tables you wish to truncate, not the ones to preserve.
	my @tables = ('stage_other');
	if ($escalation_option) {
	    push( @tables, ( 'escalation_trees', 'escalation_templates', 'tree_template_contactgroup' ) );
	}
	truncate_table('', @tables);
    }
    else {
	truncate_table('', keys %tables);
    }
}

sub truncate_table(@) {
    my $self   = shift;
    my @tables = @_;
    if ( defined($dbtype) && $dbtype eq 'postgresql' ) {
	## We would like to just:
	##   $dbh->do('truncate table ' . join(',', @tables) . ' restart identity') if @tables;
	## but PostgreSQL insists on having all tables with foreign-key references to a
	## truncated table be included in the same truncation.  Our calling application
	## code is not yet structured to do so.  We could truncate tables that don't have
	## foreign key references to them, but it would be more work to find that out.
	foreach my $table (@tables) {
	    $dbh->do("delete from $table");
	    ## FIX LATER:  find all sequences owned by columns in $table, and "ALTER TABLE $sequence_name RESTART"
	}
    }
    else {
	foreach my $table (@tables) {
	    $dbh->do("truncate table $table");
	}
    }
}

sub get_contact_templates() {
    my %contact_templates = ();
    my $sqlstmt           = "select * from contact_templates";
    my $sth               = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	$contact_templates{ $values[1] }{'id'}                          = $values[0];
	$contact_templates{ $values[1] }{'host_notification_period'}    = $values[2];
	$contact_templates{ $values[1] }{'service_notification_period'} = $values[3];
	my %data = parse_xml( '', $values[4] );
	$contact_templates{ $values[1] }{'host_notification_options'}    = $data{'host_notification_options'};
	$contact_templates{ $values[1] }{'service_notification_options'} = $data{'service_notification_options'};
	my %where = ( 'type' => 'host', 'contacttemplate_id' => $values[0] );
	@{ $contact_templates{ $values[1] }{'host_notification_commands'} } = ();
	@{ $contact_templates{ $values[1] }{'host_notification_commands'} } = fetch_list_where( '', 'contact_command', 'command_id', \%where );
	%where = ( 'type' => 'service', 'contacttemplate_id' => $values[0] );
	@{ $contact_templates{ $values[1] }{'service_notification_commands'} } = ();
	@{ $contact_templates{ $values[1] }{'service_notification_commands'} } =
	  fetch_list_where( '', 'contact_command', 'command_id', \%where );
    }
    $sth->finish;
    return %contact_templates;
}

sub get_host_templates() {
    my %host_templates = ();
    my $sqlstmt        = "select * from host_templates";
    my $sth            = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	$host_templates{ $values[1] }{'id'}                  = $values[0];
	$host_templates{ $values[1] }{'check_period'}        = $values[2];
	$host_templates{ $values[1] }{'notification_period'} = $values[3];
	$host_templates{ $values[1] }{'check_command'}       = $values[4];
	$host_templates{ $values[1] }{'event_handler'}       = $values[5];
	my %data = parse_xml( '', $values[6] );
	foreach my $prop ( keys %data ) {
	    $host_templates{ $values[1] }{$prop} = $data{$prop};
	}

	## my %where = ('type' => 'host_templates','object' => $values[0]);
	my %where = ( 'hosttemplate_id' => $values[0] );
	@{ $host_templates{ $values[1] }{'contactgroups'} } = ();

	## @{$host_templates{$values[1]}{'contactgroups'}} = fetch_list_where('','contactgroup_assign','contactgroup_id',\%where);
	@{ $host_templates{ $values[1] }{'contactgroups'} } = fetch_list_where( '', 'contactgroup_host_template', 'contactgroup_id', \%where );
    }
    $sth->finish;
    return %host_templates;
}

sub get_service_templates() {
    my %service_templates = ();
    my $sqlstmt           = "select * from service_templates";
    my $sth               = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	$service_templates{ $values[1] }{'id'}                  = $values[0];
	$service_templates{ $values[1] }{'parent_id'}           = $values[2];
	$service_templates{ $values[1] }{'check_period'}        = $values[3];
	$service_templates{ $values[1] }{'notification_period'} = $values[4];
	$service_templates{ $values[1] }{'check_command'}       = $values[5];
	$service_templates{ $values[1] }{'command_line'}        = $values[6];
	$service_templates{ $values[1] }{'event_handler'}       = $values[7];
	my %data = parse_xml( '', $values[8] );
	foreach my $prop ( keys %data ) {
	    $service_templates{ $values[1] }{$prop} = $data{$prop};
	}

	## my %where = ('type' => 'service_templates','object' => $values[0]);
	my %where = ( 'servicetemplate_id' => $values[0] );
	@{ $service_templates{ $values[1] }{'contactgroups'} } = ();

	## @{$service_templates{$values[1]}{'contactgroups'}} = fetch_list_where('','contactgroup_assign','contactgroup_id',\%where);
	@{ $service_templates{ $values[1] }{'contactgroups'} } =
	  fetch_list_where( '', 'contactgroup_service_template', 'contactgroup_id', \%where );
    }
    $sth->finish;
    return %service_templates;
}

# Unstable interface, subject to change across releases.
sub get_hostgroups_for_sync(@) {
    my @names      = @{ $_[1] };
    local $_;

    my %names = map { $_ => 1 } @names;
    my %hostgroups = ();
    if (keys %names) {
	my $sqlstmt = "select hostgroup_id, name, alias, notes from hostgroups";
	my $sth     = $dbh->prepare($sqlstmt);
	$sth->execute;
	while ( my @values = $sth->fetchrow_array() ) {
	    if ($names{ $values[1] }) {
		$hostgroups{ $values[1] }{'alias'} = $values[2] if defined $values[2];
		$hostgroups{ $values[1] }{'notes'} = $values[3] if defined $values[3];

		$sqlstmt = "select hosts.name from hosts where host_id in (select host_id from hostgroup_host where hostgroup_id = '$values[0]')";
		my $sth2 = $dbh->prepare($sqlstmt);
		$sth2->execute;
		my @members = ();
		while ( my @vals = $sth2->fetchrow_array() ) {
		    push @members, $vals[0];
		}
		$hostgroups{ $values[1] }{'members'} = \@members;
		$sth2->finish;
	    }
	}
	$sth->finish;
    }
    return \%hostgroups;
}

sub get_hostgroups(@) {
    my $version    = $_[1];
    my %hostgroups = ();
    my $sqlstmt    = "select * from hostgroups";
    my $sth        = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	$hostgroups{ $values[1] }{'id'}                 = $values[0];
	$hostgroups{ $values[1] }{'alias'}              = $values[2];
	$hostgroups{ $values[1] }{'host_escalation'}    = $values[4];
	$hostgroups{ $values[1] }{'service_escalation'} = $values[5];
	$hostgroups{ $values[1] }{'comment'}            = $values[7];
	$hostgroups{ $values[1] }{'notes'}              = $values[8];
	@{ $hostgroups{ $values[1] }{'members'} }       = ();
	@{ $hostgroups{ $values[1] }{'contactgroups'} } = ();
	$sqlstmt = "select hosts.name from hosts where host_id in (select host_id from hostgroup_host where hostgroup_id = '$values[0]')";
	my $sth2 = $dbh->prepare($sqlstmt);
	$sth2->execute;
	my @members = ();
	while ( my @vals = $sth2->fetchrow_array() ) {
	    push @members, $vals[0];
	}
	$hostgroups{ $values[1] }{'members'} = \@members;
	$sth2->finish;

	if ( $version eq '1.x' ) {
	    ## $sqlstmt = "select contactgroups.name from contactgroups where contactgroup_id in "
	    ##     . "(select contactgroup_id from contactgroup_assign where type = 'hostgroups' and object = '$values[0]')";
	    $sqlstmt = "select contactgroups.name from contactgroups where contactgroup_id in "
	      . "(select contactgroup_id from contactgroup_hostgroup where hostgroup_id = '$values[0]')";
	    $sth2 = $dbh->prepare($sqlstmt);
	    $sth2->execute;
	    my @contactgroups = ();
	    while ( my @vals = $sth2->fetchrow_array() ) {
		push @{ $hostgroups{ $values[1] }{'contactgroups'} }, $vals[0];
	    }
	    $sth2->finish;
	}
    }
    $sth->finish;
    return %hostgroups;
}

sub get_hostextinfo_templates(;$) {
    my $by_id = $_[1];
    my $index;
    my %hostextinfo_templates = ();
    my $sqlstmt               = "select * from extended_host_info_templates";
    my $sth                   = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	$index = $by_id ? $values[0] : $values[1];
	$hostextinfo_templates{$index}{'id'}      = $values[0];
	$hostextinfo_templates{$index}{'name'}    = $values[1];
	$hostextinfo_templates{$index}{'comment'} = $values[4];
	my %data = parse_xml( '', $values[2] );
	foreach my $prop ( keys %data ) {
	    $hostextinfo_templates{$index}{$prop} = $data{$prop};
	}
    }
    $sth->finish;
    return %hostextinfo_templates;
}

sub get_serviceextinfo_templates(;$) {
    my $by_id = $_[1];
    my $index;
    my %serviceextinfo_templates = ();
    my $sqlstmt                  = "select * from extended_service_info_templates";
    my $sth                      = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	$index = $by_id ? $values[0] : $values[1];
	$serviceextinfo_templates{$index}{'id'}      = $values[0];
	$serviceextinfo_templates{$index}{'name'}    = $values[1];
	$serviceextinfo_templates{$index}{'comment'} = $values[4];
	my %data = parse_xml( '', $values[2] );
	foreach my $prop ( keys %data ) {
	    $serviceextinfo_templates{$index}{$prop} = $data{$prop};
	}
    }
    $sth->finish;
    return %serviceextinfo_templates;
}

sub get_staged_services() {
    my %services = ();
    my $sqlstmt  = "select * from stage_other where type = 'service'";
    my $sth      = $dbh->prepare($sqlstmt);
    $sth->execute;
    my $i = 1;
    while ( my @values = $sth->fetchrow_array() ) {
	$services{$i}{'name'} = $values[0];
	my %data = parse_xml( '', $values[3] );
	foreach my $prop ( keys %data ) { $services{$i}{$prop} = $data{$prop} }
	$services{$i}{'comment'} = $values[4];
	$i++;
    }
    $sth->finish;
    return %services;
}

sub get_hostid_servicenameid_serviceid() {
    my %hosts_services = ();
    my $sqlstmt        = "select host_id, servicename_id, service_id from services";
    my $sth            = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	$hosts_services{ $values[0] }{ $values[1] } = $values[2];
    }
    $sth->finish;
    return %hosts_services;
}

sub get_escalation_templates() {
    my %escalation_templates = ();
    my $sqlstmt              = "select * from escalation_templates";
    my $sth                  = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	$escalation_templates{ $values[1] }{'id'}                = $values[0];
	$escalation_templates{ $values[1] }{'type'}              = $values[2];
	$escalation_templates{ $values[1] }{'escalation_period'} = $values[5];
	my %data = parse_xml( '', $values[3] );
	foreach my $prop ( keys %data ) {
	    $escalation_templates{ $values[1] }{$prop} = $data{$prop};
	}
    }
    $sth->finish;
    return %escalation_templates;
}

sub get_escalation_trees() {
    my %escalation_trees = ();
    my $sqlstmt          = "select * from escalation_trees";
    my $sth              = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	$escalation_trees{ $values[1] }{'id'}      = $values[0];
	$escalation_trees{ $values[1] }{'comment'} = $values[2];
	$escalation_trees{ $values[1] }{'type'}    = $values[3];
	$sqlstmt = "select escalation_templates.template_id, escalation_templates.name from escalation_templates where template_id in "
	  . "(select template_id from escalation_tree_template where tree_id = '$values[0]')";
	my $sth2 = $dbh->prepare($sqlstmt);
	$sth2->execute;
	while ( my @vals = $sth2->fetchrow_array() ) {
	    @{ $escalation_trees{ $values[1] }{ $vals[1] } } = ();
	    $sqlstmt = "select contactgroups.name from contactgroups where contactgroup_id in "
	      . "(select contactgroup_id from tree_template_contactgroup where tree_id = '$values[0]' and template_id = '$vals[0]')";
	    my $sth3 = $dbh->prepare($sqlstmt);
	    $sth3->execute;
	    while ( my @val = $sth3->fetchrow_array() ) {
		push @{ $escalation_trees{ $values[1] }{ $vals[1] } }, $val[0];
	    }
	    $sth3->finish;
	}
	$sth2->finish;
    }
    $sth->finish;
    return %escalation_trees;
}

sub get_staged_escalation_templates(@) {
    my $type    = $_[1];
    local $_;

    my %objects = ();
    my $sqlstmt = "select * from stage_other where type = 'serviceescalation_template'";
    if ( $type eq 'host' ) {
	$sqlstmt = "select * from stage_other where type = 'hostescalation_template' or type = 'hostgroupescalation_template'";
    }
    my $sth = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	$objects{ $values[0] }{'comment'} = $values[4];
	my %data = parse_xml( '', $values[3] );
	foreach my $prop ( keys %data ) {
	    if ( $prop eq 'escalation_options' ) {
		$data{$prop} =~ s/\s+//g;
		my @opts = split( /,/, $data{$prop} );
		@opts = sort @opts;
		foreach my $opt (@opts) {
		    $objects{ $values[0] }{'escalation_options'} .= "$opt,";
		}
		chop $objects{ $values[0] }{'escalation_options'};
	    }
	    elsif ( $prop eq 'host_name' ) {
		my @host_name = split( /,/, $data{$prop} );
		foreach (@host_name) { $_ =~ s/^\s+|\s+$//g }
		@host_name = sort @host_name;
		foreach my $host_name (@host_name) {
		    $objects{ $values[0] }{'host_name'} .= "$host_name,";
		}
		chop $objects{ $values[0] }{'host_name'};
	    }
	    elsif ( $prop eq 'hostgroup_name' ) {
		my @hostgroup_name = split( /,/, $data{$prop} );
		foreach (@hostgroup_name) { $_ =~ s/^\s+|\s+$//g }
		@hostgroup_name = sort @hostgroup_name;
		foreach my $hostgroup_name (@hostgroup_name) {
		    $objects{ $values[0] }{'hostgroup_name'} .= "$hostgroup_name,";
		}
		chop $objects{ $values[0] }{'hostgroup_name'};
	    }
	    elsif ( $prop eq 'servicegroup_name' ) {
		my @servicegroup_name = split( /,/, $data{$prop} );
		foreach (@servicegroup_name) { $_ =~ s/^\s+|\s+$//g }
		@servicegroup_name = sort @servicegroup_name;
		foreach my $servicegroup_name (@servicegroup_name) {
		    $objects{ $values[0] }{'servicegroup_name'} .= "$servicegroup_name,";
		}
		chop $objects{ $values[0] }{'servicegroup_name'};
	    }
	    elsif ( $prop eq 'service_description' ) {
		my @service_description = split( /,/, $data{$prop} );
		foreach (@service_description) { $_ =~ s/^\s+|\s+$//g }
		@service_description = sort @service_description;
		foreach my $service_description (@service_description) {
		    $objects{ $values[0] }{'service_description'} .= "$service_description,";
		}
		chop $objects{ $values[0] }{'service_description'};
	    }
	    elsif ( $prop eq 'contact_groups' ) {
		my @contact_groups = split( /,/, $data{$prop} );
		@contact_groups = sort @contact_groups;
		foreach my $contact_group (@contact_groups) {
		    $contact_group =~ s/^\s+|\s+$//g;
		    $objects{ $values[0] }{'contact_groups'} .= "$contact_group,";
		}
		chop $objects{ $values[0] }{'contact_groups'};
	    }
	    else {
		$objects{ $values[0] }{$prop} = $data{$prop};
	    }
	}
	unless ( $objects{ $values[0] }{'escalation_options'} ) {
	    $objects{ $values[0] }{'escalation_options'} = 'all';
	}
	unless ( $objects{ $values[0] }{'escalation_period'} ) {
	    $objects{ $values[0] }{'escalation_period'} = '24x7';
	}
    }
    $sth->finish;
    return %objects;
}

sub get_staged_escalations(@) {
    my $type    = $_[1];
    local $_;

    my %objects = ();
    my $sqlstmt = "select * from stage_other where type = 'serviceescalation'";
    if ( $type eq 'host' ) {
	$sqlstmt = "select * from stage_other where type = 'hostescalation' or type = 'hostgroupescalation'";
    }
    my $sth = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	$objects{ $values[0] }{'comment'} = $values[4];
	my %data = parse_xml( '', $values[3] );
	foreach my $prop ( keys %data ) {
	    if ( $prop eq 'escalation_options' ) {
		$data{$prop} =~ s/\s+//g;
		my @opts = split( /,/, $data{$prop} );
		@opts = sort @opts;
		foreach my $opt (@opts) {
		    $objects{ $values[0] }{'escalation_options'} .= "$opt,";
		}
		chop $objects{ $values[0] }{'escalation_options'};
	    }
	    elsif ( $prop eq 'host_name' ) {
		my @host_name = split( /,/, $data{$prop} );
		foreach (@host_name) { $_ =~ s/^\s+|\s+$//g }
		@host_name = sort @host_name;
		foreach my $host_name (@host_name) {
		    $objects{ $values[0] }{'host_name'} .= "$host_name,";
		}
		chop $objects{ $values[0] }{'host_name'};
	    }
	    elsif ( $prop eq 'hostgroup_name' ) {
		my @hostgroup_name = split( /,/, $data{$prop} );
		foreach (@hostgroup_name) { $_ =~ s/^\s+|\s+$//g }
		@hostgroup_name = sort @hostgroup_name;
		foreach my $hostgroup_name (@hostgroup_name) {
		    $objects{ $values[0] }{'hostgroup_name'} .= "$hostgroup_name,";
		}
		chop $objects{ $values[0] }{'hostgroup_name'};
	    }
	    elsif ( $prop eq 'servicegroup_name' ) {
		my @servicegroup_name = split( /,/, $data{$prop} );
		foreach (@servicegroup_name) { $_ =~ s/^\s+|\s+$//g }
		@servicegroup_name = sort @servicegroup_name;
		foreach my $servicegroup_name (@servicegroup_name) {
		    $objects{ $values[0] }{'servicegroup_name'} .= "$servicegroup_name,";
		}
		chop $objects{ $values[0] }{'servicegroup_name'};
	    }
	    elsif ( $prop eq 'service_description' ) {
		my @service_description = split( /,/, $data{$prop} );
		foreach (@service_description) { $_ =~ s/^\s+|\s+$//g }
		@service_description = sort @service_description;
		foreach my $service_description (@service_description) {
		    $objects{ $values[0] }{'service_description'} .= "$service_description,";
		}
		chop $objects{ $values[0] }{'service_description'};
	    }
	    elsif ( $prop eq 'contact_groups' ) {
		my @contact_groups = split( /,/, $data{$prop} );
		foreach (@contact_groups) { $_ =~ s/^\s+|\s+$//g }
		@contact_groups = sort @contact_groups;
		foreach my $contact_group (@contact_groups) {
		    $objects{ $values[0] }{'contact_groups'} .= "$contact_group,";
		}
		chop $objects{ $values[0] }{'contact_groups'};
	    }
	    else {
		$objects{ $values[0] }{$prop} = $data{$prop};
	    }
	}
    }
    $sth->finish;
    return %objects;
}

sub set_default_hostgroup_escalations(@) {
    my $tree_id = $_[1];
    $dbh->do( "update hostgroups set host_escalation_id = '$tree_id' where host_escalation_id is null" );
}

sub set_default_host_escalations(@) {
    my $tree_id = $_[1];
    $dbh->do( "update hosts set host_escalation_id = '$tree_id' where host_escalation_id is null" );
}

sub set_default_servicegroup_escalations(@) {
    my $tree_id = $_[1];
    $dbh->do( "update servicegroups set escalation_id = '$tree_id' where escalation_id is null" );
}

sub set_default_service_escalations(@) {
    my $tree_id = $_[1];
    $dbh->do( "update services set escalation_id = '$tree_id' where escalation_id is null" );
    $dbh->do( "update service_names set escalation = '$tree_id' where escalation is null" );
}

sub get_escalation_assigned() {
    my $tree_id = $_[1];
    my $type    = $_[2];
    my $obj     = $_[3];
    my @objects = ();
    my $sqlstmt = undef;
    if ( $obj eq 'services' ) {
	$sqlstmt = "select name from service_names where escalation = '$tree_id'";
    }
    elsif ( $obj eq 'servicegroups' ) {
	$sqlstmt = "select name from servicegroups where escalation_id = '$tree_id'";
    }
    elsif ( $obj eq 'hostgroups' ) {
	$sqlstmt = "select name from hostgroups where $type\_escalation_id = '$tree_id'";
    }
    elsif ( $obj eq 'hosts' ) {
	$sqlstmt = "select name from hosts where $type\_escalation_id = '$tree_id'";
    }
    my $sth = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) { push @objects, $values[0] }
    $sth->finish;
    return @objects;
}

sub get_host_service_escalation_assigned(@) {
    my $tree_id      = $_[1];
    my %host_service = ();
    my $sqlstmt      = "select service_id, servicename_id, host_id from services where escalation_id = '$tree_id'";
    my $sth          = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	$host_service{ $values[2] }{ $values[0] } = $values[1];
    }
    $sth->finish;
    return %host_service;
}

sub get_service_dependency_templates() {
    my %service_dependency_templates = ();
    my $sqlstmt                      = "select * from service_dependency_templates";
    my $sth                          = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	$service_dependency_templates{ $values[1] }{'id'}             = $values[0];
	$service_dependency_templates{ $values[1] }{'servicename_id'} = $values[2];
	# The comment field isn't managed anywhere in the UI, so it might get out of date during renames, for instance.
	# Until we assure ourselves that the value will be updated when appropriate, we won't export it here.
	# $service_dependency_templates{ $values[1] }{'comment'}        = $values[4];
	my %data = parse_xml( '', $values[3] );
	foreach my $prop ( keys %data ) {
	    $service_dependency_templates{ $values[1] }{$prop} = $data{$prop};
	}
    }
    $sth->finish;
    return %service_dependency_templates;
}

sub get_service_groups() {
    my %service_groups = ();
    my $sqlstmt        = "select * from servicegroups";
    my $sth            = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	$service_groups{ $values[1] }{'id'}            = $values[0];
	$service_groups{ $values[1] }{'name'}          = $values[1];
	$service_groups{ $values[1] }{'alias'}         = $values[2];
	$service_groups{ $values[1] }{'escalation_id'} = $values[3];
	$service_groups{ $values[1] }{'comment'}       = $values[4];
	$service_groups{ $values[1] }{'notes'}         = $values[5];
	$sqlstmt = "select host_id, service_id from servicegroup_service where servicegroup_id = '$values[0]'";
	my $sth2 = $dbh->prepare($sqlstmt);
	$sth2->execute;
	while ( my @vals = $sth2->fetchrow_array() ) {
	    $service_groups{ $values[1] }{'hosts'}{ $vals[0] }{ $vals[1] } = 1;
	}
	$sth2->finish;
    }
    $sth->finish;
    return %service_groups;
}

sub get_macros() {
    my %macros  = ();
    my $sqlstmt = "select * from monarch_macros";
    my $sth     = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	$macros{ $values[1] }{'id'}          = $values[0];
	$macros{ $values[1] }{'description'} = $values[3];
	$macros{ $values[1] }{'value'}       = $values[2];
    }
    $sth->finish;
    return %macros;
}

sub get_group_macros() {
    my $gid    = $_[1];
    my %macros = ();
    my $sqlstmt =
	"select monarch_macros.macro_id, monarch_macros.name, monarch_macros.description, monarch_group_macro.value "
      . "from monarch_macros left join monarch_group_macro on monarch_group_macro.macro_id = monarch_macros.macro_id "
      . "where monarch_group_macro.group_id = '$gid'";
    my $sth = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	$macros{ $values[1] }{'id'}          = $values[0];
	$macros{ $values[1] }{'description'} = $values[2];
	$macros{ $values[1] }{'value'}       = $values[3];
    }
    $sth->finish;
    return %macros;
}

sub get_auth_groups(@) {
    my $user_id = $_[1];
    my $sqlstmt = "select distinct name from monarch_groups left join access_list on access_list.object = monarch_groups.group_id "
      . "where access_list.type = 'group_macro' and access_list.usergroup_id in (select usergroup_id from user_group where user_id = '$user_id')";
    my $sth = $dbh->prepare($sqlstmt);
    $sth->execute;
    my @groups = ();
    while ( my @values = $sth->fetchrow_array() ) {
	push @groups, $values[0];
    }
    $sth->finish;
    return @groups;
}

############################################################################

sub get_group_parents_all() {
    my %parents = ();
    my $sqlstmt = "select name, group_id from monarch_groups where group_id in (select distinct group_id from monarch_group_child)";
    my $sth     = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	$parents{ $values[0] } = $values[1];
    }
    $sth->finish;
    return %parents;
}

sub get_group_parents_top() {
    my %parents = ();
    my $sqlstmt = "select name, group_id from monarch_groups where group_id not in (select distinct child_id from monarch_group_child)";
    my $sth     = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	$parents{ $values[0] } = $values[1];
    }
    $sth->finish;
    return %parents;
}

sub get_groups() {
    my %groups  = ();
    my $sqlstmt = "select * from monarch_groups where group_id > 0";
    my $sth     = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	$groups{ $values[1] }{'description'} = $values[2];
	my $stmt = "select host_id, name from hosts where host_id in (select host_id from monarch_group_host where group_id = '$values[0]') order by name";
	my $sth2 = $dbh->prepare($stmt);
	$sth2->execute;
	while ( my @vals = $sth2->fetchrow_array() ) {
	    $groups{ $values[1] }{'hosts'} .= "$vals[1],";
	}
	chop $groups{ $values[1] }{'hosts'} if defined( $groups{ $values[1] }{'hosts'} );
	$sth2->finish;
    }
    $sth->finish;
    return %groups;
}

sub check_group_children(@) {
    my $parent      = $_[0];
    my $child       = $_[1];
    my $group       = $_[2];
    my $children    = $_[3];
    my $parents     = $_[4];
    my $parents_all = $_[5];
    my $group_ids   = $_[6];
    my %children    = %{$children};
    my %parents_all = %{$parents_all};
    my %group_ids   = %{$group_ids};
    my %g_children  = get_group_children( $group_ids{$group} );
    foreach my $g_child ( sort keys %g_children ) {
	$parents .= "$parent,$group,";
	$children{$parent}{'children'} .= "$g_child,";
	if ( $parent eq $g_child ) {
	    my @parents = split( /,/, $children{$child}{'parents'} );
	    delete $children{$child};
	    $children{'delete_it'} = 1;
	    $parents = undef;
	    next;
	}
	elsif ( $parents_all{$g_child} ) {
	    $parents .= "$group,";
	    ## FIX MINOR:  Should this be a call to check_group_children() instead?
	    %children = check_children( $parent, $child, $g_child, \%children, $parents, \%parents_all, \%group_ids );
	    $children{$g_child}            = $g_children{$g_child};
	    $children{$g_child}{'parents'} = $parents;
	    $parents                       = undef;
	}
	else {
	    $children{$g_child}            = $g_children{$g_child};
	    $children{$g_child}{'parents'} = $parents;
	    $parents                       = undef;
	}
    }
    return %children;
}

sub get_children_group(@) {
    my $name        = $_[1];
    my %parents_all = get_group_parents_all();
    my %group_ids   = get_table_objects( '', 'monarch_groups' );
    my %children    = StorProc->get_group_children( $group_ids{$name} );
    foreach my $child ( keys %children ) {
	$children{$child}{'parents'} .= "$name,";
	if ( $parents_all{$child} ) {
	    my %child = check_group_children( $child, $child, $child, \%children, $name, \%parents_all, \%group_ids );
	    if ( $child{'delete_it'} ) {
		delete $children{$child};
	    }
	    else {
		%children = %child;
	    }
	}
    }
    return %children;
}

sub get_possible_groups(@) {
    my $name        = $_[1];
    my %group_ids   = get_table_objects( '', 'monarch_groups' );
    my %groups      = get_groups();
    my %parents_all = get_group_parents_all();
    my %group_hosts = ();
    my %group_child = ();
    foreach my $group ( keys %groups ) {
	my @order = ();
	my ( $group_hosts, $order ) = StorProc->get_group_hosts( $group, \%parents_all, \%group_ids, \%group_hosts, \@order, \%group_child );
	%group_hosts = %{$group_hosts};
	if ( $group_hosts{$name} ) {
	    delete $groups{$group};
	    delete $group_hosts{$name};
	}
    }
    delete $groups{$name};
    return %groups;
}

############################################################################

sub fetch_one_group() {
    my $gid     = $_[1];
    my $groups  = $_[2];
    my %groups  = %{$groups};
    my $sqlstmt = "select * from monarch_groups where group_id = '$gid'";
    my $sth     = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	my %data = parse_xml( '', $values[5] );
	my $hashref = \%{ $groups{ $values[1] } };
	$hashref->{'description'}                            = $values[2];
	$hashref->{'location'}                               = $values[3];
	$hashref->{'nagios_etc'}                             = $data{'nagios_etc'};
	$hashref->{'label_enabled'}                          = $data{'label_enabled'};
	$hashref->{'label'}                                  = $data{'label'};
	$hashref->{'use_hosts'}                              = $data{'use_hosts'};
	$hashref->{'inherit_host_active_checks_enabled'}     = $data{'inherit_host_active_checks_enabled'};
	$hashref->{'inherit_host_passive_checks_enabled'}    = $data{'inherit_host_passive_checks_enabled'};
	$hashref->{'inherit_service_active_checks_enabled'}  = $data{'inherit_service_active_checks_enabled'};
	$hashref->{'inherit_service_passive_checks_enabled'} = $data{'inherit_service_passive_checks_enabled'};
	$hashref->{'host_active_checks_enabled'}             = $data{'host_active_checks_enabled'};
	$hashref->{'host_passive_checks_enabled'}            = $data{'host_passive_checks_enabled'};
	$hashref->{'service_active_checks_enabled'}          = $data{'service_active_checks_enabled'};
	$hashref->{'service_passive_checks_enabled'}         = $data{'service_passive_checks_enabled'};

	my $stmt =
"select host_id, name from hosts where host_id in (select host_id from monarch_group_host where group_id = '$values[0]')";
	my $sth2 = $dbh->prepare($stmt);
	$sth2->execute;
	my %hosts = ();
	while ( my @vals = $sth2->fetchrow_array() ) {
	    $hosts{ $vals[1] } = $vals[0];
	}
	$sth2->finish;
	%{ $groups{ $values[1] }{'hosts'} } = %hosts;

	$stmt =
"select hostgroup_id, name from hostgroups where hostgroup_id in (select hostgroup_id from monarch_group_hostgroup where group_id = '$values[0]')";
	$sth2 = $dbh->prepare($stmt);
	$sth2->execute;
	my %hostgroups = ();
	while ( my @vals = $sth2->fetchrow_array() ) {
	    $hostgroups{ $vals[1] } = $vals[0];
	}
	$sth2->finish;
	%{ $groups{ $values[1] }{'hostgroups'} } = %hostgroups;

	$stmt =
"select monarch_macros.name, monarch_group_macro.value from monarch_macros left join monarch_group_macro on monarch_macros.macro_id = monarch_group_macro.macro_id where monarch_group_macro.group_id = '$values[0]'";
	$sth2 = $dbh->prepare($stmt);
	$sth2->execute;
	my %macros = ();
	while ( my @vals = $sth2->fetchrow_array() ) {
	    $macros{ $vals[0] } = $vals[1];
	}
	$sth2->finish;
	%{ $groups{ $values[1] }{'macros'} } = %macros;

	## $stmt = "select contactgroup_id, name from contactgroups where contactgroup_id in (select contactgroup_id from contactgroup_assign where type = 'monarch_group' and object = '$values[0]')";
	$stmt =
"select contactgroup_id, name from contactgroups where contactgroup_id in (select contactgroup_id from contactgroup_group where group_id = '$values[0]')";
	$sth2 = $dbh->prepare($stmt);
	$sth2->execute;
	my %contactgroups = ();
	while ( my @vals = $sth2->fetchrow_array() ) {
	    $contactgroups{ $vals[1] } = $vals[0];
	}
	$sth2->finish;
	%{ $groups{ $values[1] }{'contactgroups'} } = %contactgroups;
    }
    $sth->finish;
    return %groups;
}

sub get_group_children(@) {
    my $gid     = $_[1];
    my %groups  = ();
    my $sqlstmt = "select * from monarch_groups where group_id in (select child_id from monarch_group_child where group_id = '$gid')";
    my $sth     = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	my %data = parse_xml( '', $values[5] );
	my $hashref = \%{ $groups{ $values[1] } };
	$hashref->{'description'}                            = $values[2];
	$hashref->{'location'}                               = $values[3];
	$hashref->{'nagios_etc'}                             = $data{'nagios_etc'};
	$hashref->{'label_enabled'}                          = $data{'label_enabled'};
	$hashref->{'label'}                                  = $data{'label'};
	$hashref->{'use_hosts'}                              = $data{'use_hosts'};
	$hashref->{'inherit_host_active_checks_enabled'}     = $data{'inherit_host_active_checks_enabled'};
	$hashref->{'inherit_host_passive_checks_enabled'}    = $data{'inherit_host_passive_checks_enabled'};
	$hashref->{'inherit_service_active_checks_enabled'}  = $data{'inherit_service_active_checks_enabled'};
	$hashref->{'inherit_service_passive_checks_enabled'} = $data{'inherit_service_passive_checks_enabled'};
	$hashref->{'host_active_checks_enabled'}             = $data{'host_active_checks_enabled'};
	$hashref->{'host_passive_checks_enabled'}            = $data{'host_passive_checks_enabled'};
	$hashref->{'service_active_checks_enabled'}          = $data{'service_active_checks_enabled'};
	$hashref->{'service_passive_checks_enabled'}         = $data{'service_passive_checks_enabled'};

	my $stmt =
"select host_id, name from hosts where host_id in (select host_id from monarch_group_host where group_id = '$values[0]')";
	my $sth2 = $dbh->prepare($stmt);
	$sth2->execute;
	my %hosts = ();
	while ( my @vals = $sth2->fetchrow_array() ) {
	    $hosts{ $vals[1] } = $vals[0];
	}
	$sth2->finish;
	%{ $groups{ $values[1] }{'hosts'} } = %hosts;

	$stmt =
"select hostgroup_id, name from hostgroups where hostgroup_id in (select hostgroup_id from monarch_group_hostgroup where group_id = '$values[0]')";
	$sth2 = $dbh->prepare($stmt);
	$sth2->execute;
	my %hostgroups = ();
	while ( my @vals = $sth2->fetchrow_array() ) {
	    $hostgroups{ $vals[1] } = $vals[0];
	}
	$sth2->finish;
	%{ $groups{ $values[1] }{'hostgroups'} } = %hostgroups;

	$stmt =
"select monarch_macros.name, monarch_group_macro.value from monarch_macros left join monarch_group_macro on monarch_macros.macro_id = monarch_group_macro.macro_id where monarch_group_macro.group_id = '$values[0]'";
	$sth2 = $dbh->prepare($stmt);
	$sth2->execute;
	my %macros = ();
	while ( my @vals = $sth2->fetchrow_array() ) {
	    $macros{ $vals[0] } = $vals[1];
	}
	$sth2->finish;
	%{ $groups{ $values[1] }{'macros'} } = %macros;

	## $stmt = "select contactgroup_id, name from contactgroups where contactgroup_id in (select contactgroup_id from contactgroup_assign where type = 'monarch_group' and object = '$values[0]')";
	$stmt =
"select contactgroup_id, name from contactgroups where contactgroup_id in (select contactgroup_id from contactgroup_group where group_id = '$values[0]')";
	$sth2 = $dbh->prepare($stmt);
	$sth2->execute;
	my %contactgroups = ();
	while ( my @vals = $sth2->fetchrow_array() ) {
	    $contactgroups{ $vals[1] } = $vals[0];
	}
	$sth2->finish;
	%{ $groups{ $values[1] }{'contactgroups'} } = %contactgroups;
    }
    $sth->finish;
    return %groups;
}

sub get_group_orphans() {
    my $sqlstmt = "select host_id, name from hosts where host_id not in (SELECT host_id FROM monarch_group_host)";
    my $sth     = $dbh->prepare($sqlstmt);
    $sth->execute;
    my %hosts = ();
    while ( my @vals = $sth->fetchrow_array() ) {
	$hosts{ $vals[1] } = $vals[0];
    }
    $sth->finish;
    $sqlstmt = "select distinct hostgroup_id from monarch_group_hostgroup";
    $sth     = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @vals = $sth->fetchrow_array() ) {
	my $stmt = "select name from hosts where host_id in (select host_id from hostgroup_host where hostgroup_id = '$vals[0]')";
	my $sth2 = $dbh->prepare($stmt);
	$sth2->execute;
	while ( my @val = $sth2->fetchrow_array() ) {
	    delete $hosts{ $val[0] };
	}
	$sth2->finish;
    }
    $sth->finish;
    return %hosts;
}

sub get_group_hosts() {
    my $group       = $_[1];
    my $parents_all = $_[2];
    my $group_ids   = $_[3];
    my $group_hosts = $_[4];
    my $order       = $_[5];
    my $group_child = $_[6];
    my %parents_all = %{$parents_all};
    my %group_ids   = %{$group_ids};
    my %group_hosts = %{$group_hosts};
    my @order       = @{$order};
    my %group_child = %{$group_child};
    my %children    = StorProc->get_group_children( $group_ids{$group} );
    foreach my $child ( sort keys %children ) {
	$group_child{$group}{$child} = 1;
	if ( not defined $group_hosts{$child} ) {
	    $group_hosts{$child} = $children{$child};
	    push @order, $child;
	    if ( $parents_all{$child} ) {
		( $group_hosts, $order, $group_child ) =
		  &get_group_hosts( '', $child, \%parents_all, \%group_ids, \%group_hosts, \@order, \%group_child );
		%group_hosts = %{$group_hosts};
		@order       = @{$order};
		%group_child = %{$group_child};
	    }
	}
    }
    return \%group_hosts, \@order, \%group_child;
}

sub get_group_hosts_old(@) {
    my $gid     = $_[1];
    my %hosts   = ();
    my $sqlstmt = "select host_id from monarch_group_host where group_id = '$gid'";
    my $sth     = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	$hosts{ $values[0] } = 1;
    }
    $sth->finish;
    my %members    = ();
    my %nonmembers = ();
    $sqlstmt = "select * from hosts";
    $sth     = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	if ( $hosts{ $values[0] } ) {
	    $members{ $values[1] }{'alias'}   = $values[2];
	    $members{ $values[1] }{'address'} = $values[3];
	}
	else {
	    $nonmembers{ $values[1] }{'alias'}   = $values[2];
	    $nonmembers{ $values[1] }{'address'} = $values[3];
	}
    }
    $sth->finish;
    return \%nonmembers, \%members;
}

sub get_group_cfg(@) {
    my $gid     = $_[1];
    my %objects = ();
    my $sqlstmt = "select name, type, value from monarch_group_props where type = 'nagios_cfg' and group_id = '$gid'";
    my $sth     = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	$objects{ $values[0] } = [@values];
    }
    $sth->finish;
    return %objects;
}

sub get_group_cgi(@) {
    my $gid     = $_[1];
    my %objects = ();
    my $sqlstmt = "select name, type, value from monarch_group_props where type = 'nagios_cgi' and group_id = '$gid'";
    my $sth     = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	$objects{ $values[0] } = [@values];
    }
    $sth->finish;
    return %objects;
}

sub get_nagios_values(@) {
    my $gid        = $_[1];
    my %nag_values = ();
    my $sqlstmt    = "select name, value from setup where type = 'nagios'";
    if ($gid) {
	$sqlstmt = "select name, value from monarch_group_props where type = 'nagios_cfg' and group_id = '$gid'";
    }
    my $sth = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	$nag_values{ $values[0] } = $values[1];
    }
    $sth->finish;
    return %nag_values;
}

sub get_resource_values(@) {
    my $gid         = $_[1];
    my %user_values = ();
    my $sqlstmt     = "select name, value from setup where type = 'resource'";
    if ($gid) {
	$sqlstmt = "select name, value from monarch_group_props where type = 'resource' and group_id = '$gid'";
    }
    my $sth = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	$user_values{ $values[0] } = $values[1];
    }
    $sth->finish;
    return %user_values;
}

sub count(@) {
    my $sqlstmt = "select count(*) from $_[1]";
    my $count   = $dbh->selectrow_array($sqlstmt);
    return $count;
}

sub count_match {
    my $table   = $_[1];
    my $input   = $_[2];	# optional
    my $type    = $_[3];	# optional
    my $count   = 0;
    my $sqlstmt = '';

    $input =~ s/^\s*(.*?)\s*$/$1/;
    return 0 if ( $input =~ /'/ || $input =~ /^\.$/ );
    $input =~ s{_}{:_}g;

    if ( $table eq 'hosts' && $input =~ /^[.\d]+$/ && $input =~ /\d/ ) {
	$sqlstmt = "select count(*) from hosts where name like '%$input%' escape ':' or address like '%$input%' escape ':'";
    } else {
	$sqlstmt = "select count(*) from $table";
	if ( defined($input) && $input ne '' ) {
	    $sqlstmt .= " where name like '%$input%' escape ':'";
	    if ( defined($type) && $type ne '' ) {
		$sqlstmt .= " and type = '$type'";
	    }
	}
	elsif ( defined($type) && $type ne '' ) {
	    $sqlstmt .= " where type = '$type'";
	}
    }
    $count = $dbh->selectrow_array($sqlstmt);

    return $count;
}

sub search(@) {
    my $input = $_[1];
    my $max_to_show = $_[2] || 20;
    $max_to_show = 20 unless ( $max_to_show =~ /^-?\d+$/ );

    $input =~ s/^\s*(.*?)\s*$/$1/;
    return () if ( $input =~ /'/ || $input =~ /^\.$/ );
    $input =~ s{_}{:_}g;

    # To use '*' as a wildcard instead of '%', do this here and in related routines:
    # $input =~ s/%/:%/g;
    # $input =~ s/\*/%/g;

    my %hosts   = ();
    my $sqlstmt = '';

    # if input contains a digit and only digits and periods, it might be an ip address
    if ( $input =~ /^[.\d]+$/ && $input =~ /\d/ ) {
	$sqlstmt = "select name, address from hosts where address like '%$input%'";
	$sqlstmt .= " limit $max_to_show" unless ( $max_to_show < 1 );
	my $sth = $dbh->prepare($sqlstmt);
	$sth->execute;
	while ( my @values = $sth->fetchrow_array() ) {
	    $hosts{ $values[0] } = $values[1];    # [1] is address
	}
	$sth->finish;
    }

    # if we have not exhausted our limit on returned results ...
    if ($max_to_show < 1 || $max_to_show > scalar(keys %hosts)) {
	$max_to_show -= scalar(keys %hosts) unless ( $max_to_show < 1 );
	my $ci_like = ( defined($dbtype) && $dbtype eq 'postgresql' ) ? 'ilike' : 'like';
	$sqlstmt = "select name from hosts where name $ci_like '%$input%' escape ':'";
	$sqlstmt .= " limit $max_to_show" unless ( $max_to_show < 1 );
	my $sth = $dbh->prepare($sqlstmt);
	$sth->execute;
	while ( my @values = $sth->fetchrow_array() ) {
	    # Show the user the IP address if it matched above.
	    if (! exists $hosts{ $values[0] } ) {
		$hosts{ $values[0] } = $values[0];        # [0] is host
	    }
	}
	$sth->finish;
    }

    return %hosts;
}

sub search_service(@) {
    return search_object( '', $_[1], 'service_names', $_[2] )
}

sub search_command(@) {
    return search_object( '', $_[1], 'commands', $_[2] )
}

sub search_object(@) {
    my $input = $_[1];
    my $table = $_[2];
    my $max_to_show = $_[3] || 20;
    $max_to_show = 20 unless ( $max_to_show =~ /^-?\d+$/ );

    $input =~ s/^\s*(.*?)\s*$/$1/;
    return () if ( $input =~ /'/ || $input =~ /^\.$/ );
    $input =~ s{_}{:_}g;

    my $sqlstmt  = "select name from $table where name like '%$input%' escape ':'";
    $sqlstmt .= " limit $max_to_show" unless ( $max_to_show < 1 );
    my %objects = ();
    my $sth     = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	unless ( $values[0] eq '*' ) { $objects{ $values[0] } = $values[0] }
    }
    $sth->finish;
    return %objects;
}

sub search_external(@) {
    my $input = $_[1];
    my $type  = $_[2];
    my $max_to_show = $_[3] || 20;
    $max_to_show = 20 unless ( $max_to_show =~ /^-?\d+$/ );

    $input =~ s/^\s*(.*?)\s*$/$1/;
    return () if ( $input =~ /'/ || $input =~ /^\.$/ );
    $input =~ s{_}{:_}g;

    my $sqlstmt  = "select name from externals where name like '%$input%' escape ':' and type = '$type'";
    $sqlstmt .= " limit $max_to_show" unless ( $max_to_show < 1 );
    my %externals = ();
    my $sth       = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	unless ( $values[0] eq '*' ) { $externals{ $values[0] } = $values[0] }
    }
    $sth->finish;
    return %externals;
}

sub get_host_search_matrix() {
    my @host_search = ();
    my %addresses   = ();
    my %names       = ();
    my @addr        = fetch_list( '', 'hosts', 'address' );
    my @hosts       = fetch_list( '', 'hosts', 'name' );
    foreach my $add (@addr) {
	if ( $add =~ /(\d+)\.(\d+)\.(\d+)\.\d+/ ) {
	    $addresses{"$1.$2.$3.*"} = 1;
	}
    }
    foreach my $name (@hosts) {
	$name = lc($name);
	if ( $name =~ /(^\S{1})/ ) {
	    $names{"$1*"} = 1;
	}
	if ( $name =~ /(^\S{3})/ ) {
	    $names{"$1*"} = 1;
	}
    }
    foreach my $add ( sort keys %addresses ) {
	push @host_search, $add;
    }
    foreach my $name ( sort { lc($b) cmp lc($a) } keys %names ) {
	push @host_search, $name;
    }
    push @host_search, '*';
    return @host_search;
}

sub get_host_service_rrd() {
    my %host_rrd = ();
    my $sqlstmt =
"select host_service.host, host_service.service, datatype.location from host_service left join datatype on host_service.datatype_id = datatype.datatype_id";
    my $sth = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	$host_rrd{ $values[0] }{ $values[1] } = $values[2];
    }
    $sth->finish;
    return %host_rrd;
}

# monarch_groups.status:
# NULL:  send to Nagios and Foundation
#    1:  send to nobody
#    3:  send to Foundation (only)
# Parameter:
# false:  tell if inactive with respect to Foundation
#  true:  tell if inactive with respect to Nagios
sub get_inactive_hosts() {
    my $wrt_nagios    = $_[1];
    my $filter        = $wrt_nagios ? '& 1' : '';  # too clever, but it works here
    my %host_inactive = ();
    my $sqlstmt       = "select host_id from monarch_group_host where group_id in (select group_id from monarch_groups where status $filter = '1')";
    my $sth           = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	$host_inactive{ $values[0] } = 1;
    }
    $sth->finish;
    $sqlstmt = "select hostgroup_id from monarch_group_hostgroup where group_id in (select group_id from monarch_groups where status $filter = '1')";
    $sth     = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	my $stmt = "select host_id from hostgroup_host where hostgroup_id = '$values[0]'";
	my $sth2 = $dbh->prepare($stmt);
	$sth2->execute;
	while ( my @vals = $sth2->fetchrow_array() ) {
	    $host_inactive{ $vals[0] } = 1;
	}
	$sth2->finish;
    }
    $sth->finish;
    return %host_inactive;
}

sub rename_command(@) {
    my %command  = %{ $_[1] };
    my $new_name = $_[2];
    $dbh->do("update commands set name = '$new_name' where name = '$command{name}'");
    my $sqlstmt = "select service_id, command_line from services where check_command = '$command{'command_id'}'";
    my $sth     = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	$values[1] =~ s/$command{'name'}/$new_name/;
	$dbh->do( "update services set command_line = '$values[1]' where service_id = '$values[0]'" );
    }
    $sth->finish;
    $sqlstmt = "select servicename_id, command_line from service_names where check_command = '$command{'command_id'}'";
    $sth     = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	$values[1] =~ s/$command{'name'}/$new_name/;
	$dbh->do( "update service_names set command_line = '$values[1]' where servicename_id = '$values[0]'" );
    }
    $sth->finish;
    $sqlstmt = "select servicetemplate_id, command_line from service_templates where check_command = '$command{'command_id'}'";
    $sth     = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	$values[1] =~ s/$command{'name'}/$new_name/;
	$dbh->do( "update service_templates set command_line = '$values[1]' where servicetemplate_id = '$values[0]'" );
    }
    $sth->finish;
    return 1;
}

sub get_main_cfg_misc(@) {
    my $gid       = $_[1];
    my %misc_vals = ();
    my $sqlstmt   = "select name, value from setup where type = 'nagios_cfg_misc'";
    if ($gid) {
	$sqlstmt = "select prop_id, name, value from monarch_group_props where group_id = '$gid' and type = 'nagios_cfg_misc'";
    }
    my $sth = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	if ($gid) {
	    $values[2] =~ s/-zero-/0/g;
	    $misc_vals{ $values[0] }{'name'}  = $values[1];
	    $misc_vals{ $values[0] }{'value'} = $values[2];
	}
	else {
	    my $name = $values[0];
	    $name =~ s/key\d+.\d+$//;
	    $values[1] =~ s/-zero-/0/g if defined $values[1];
	    $misc_vals{ $values[0] }{'name'}  = $name;
	    $misc_vals{ $values[0] }{'value'} = $values[1];
	}
    }
    $sth->finish;
    return %misc_vals;
}

sub nagios_defaults(@) {
    my $nagios_ver = $_[1];

    # get from db
    my $nagios_dir = '/usr/local/nagios';
    if ($is_portal) { $nagios_dir = '/usr/local/nagios' }
    my %nagios = ();

    # Notification Options
    $nagios{'enable_notifications'} = '0';
    $nagios{'notification_timeout'} = '30';
    $nagios{'admin_email'}          = 'nagios@localhost';
    $nagios{'admin_pager'}          = 'pagenagios@localhost';

    # Configuration Options
    $nagios{'resource_file'} = $nagios_dir . '/etc/private/resource.cfg';
    $nagios{'website_url'} = '';

    # Time Format Options
    $nagios{'date_format'} = 'us';
    if ( $nagios_ver eq '3.x' ) {
	$nagios{'use_timezone'} = '';
    }

    # Character Constraint Options
    $nagios{'illegal_object_name_chars'}  = q(`~!$%^&*|'"<>?,()'=);
    $nagios{'illegal_macro_output_chars'} = q(`~$&|'"<>);

    # External Interface Options
    $nagios{'check_external_commands'} = '1';
    $nagios{'command_check_interval'}  = '-1';
    $nagios{'command_file'}            = $nagios_dir . '/var/spool/nagios.cmd';
    if ( $nagios_ver eq '3.x' ) {
	$nagios{'external_command_buffer_slots'} = '';
    }
    if ( $nagios_ver =~ /^[23]\.x$/ ) {
	$nagios{'object_cache_file'} = $nagios_dir . '/var/objects.cache';
    }
    if ( $nagios_ver =~ /^[12]\.x$/ ) {
	$nagios{'aggregate_status_updates'} = '1';
    }
    $nagios{'status_file'}            = $nagios_dir . '/var/status.log';
    $nagios{'status_update_interval'} = '15';
    if ($is_portal) {
	$nagios{'broker_module'} = $nagios_dir . '/lib/libbronx.so';
    }

    # Debug Options
    if ( $nagios_ver eq '3.x' ) {
	$nagios{'debug_level'}         = '-zero-';
	$nagios{'debug_verbosity'}     = '1';
	$nagios{'debug_file'}          = $nagios_dir . '/var/nagios.debug';
	$nagios{'max_debug_file_size'} = '1000000';
    }

    # Check Execution Options
    if ( $nagios_ver =~ /^[23]\.x$/ ) {
	$nagios{'execute_host_checks'}        = '1';
	$nagios{'accept_passive_host_checks'} = '1';
    }
    $nagios{'execute_service_checks'}        = '1';
    $nagios{'accept_passive_service_checks'} = '1';

    # Check Scheduling Options
    $nagios{'sleep_time'} = '1';
    if ( $nagios_ver =~ /^[23]\.x$/ ) {
	$nagios{'host_inter_check_delay_method'} = 's';
	$nagios{'max_host_check_spread'}         = '30';
    }
    $nagios{'host_check_timeout'} = '30';
    if ( $nagios_ver eq '3.x' ) {
	$nagios{'cached_host_check_horizon'} = '15';
	$nagios{'enable_predictive_host_dependency_checks'} = '1';
	$nagios{'check_for_orphaned_hosts'}  = '1';
    }
    $nagios{'use_aggressive_host_checking'} = '0';
    if ( $nagios_ver eq '1.x' ) {
	$nagios{'inter_check_delay_method'} = 's';
    }
    else {
	$nagios{'service_inter_check_delay_method'} = 's';
	$nagios{'max_service_check_spread'}         = '30';
    }
    $nagios{'service_check_timeout'} = '60';
    if ( $nagios_ver eq '3.x' ) {
	$nagios{'cached_service_check_horizon'} = '15';
	$nagios{'enable_predictive_service_dependency_checks'} = '1';
    }
    $nagios{'check_for_orphaned_services'} = '0';
    $nagios{'service_interleave_factor'}   = 's';
    $nagios{'max_concurrent_checks'}       = '100';
    $nagios{'interval_length'}             = '60';
    if ( $nagios_ver =~ /^[23]\.x$/ ) {
	$nagios{'auto_reschedule_checks'}     = '0';
	$nagios{'auto_rescheduling_interval'} = '30';
	$nagios{'auto_rescheduling_window'}   = '180';
    }

    # Freshness Check Options
    if ( $nagios_ver =~ /^[23]\.x$/ ) {
	$nagios{'check_host_freshness'}          = '0';
	$nagios{'host_freshness_check_interval'} = '60';
    }
    $nagios{'check_service_freshness'} = '0';
    if ( $nagios_ver =~ /^[12]\.x$/ ) {
	$nagios{'freshness_check_interval'} = '60';
    }
    if ( $nagios_ver eq '3.x' ) {
	$nagios{'service_freshness_check_interval'} = '60';
	$nagios{'additional_freshness_latency'} = '15';
    }

    # Obsessive-Compulsive Processing Options
    if ( $nagios_ver =~ /^[23]\.x$/ ) {
	$nagios{'obsess_over_hosts'} = '0';
	$nagios{'ochp_command'}      = '';
	$nagios{'ochp_timeout'}      = '5';
    }
    $nagios{'obsess_over_services'} = '0';
    $nagios{'ocsp_command'}         = '';
    $nagios{'ocsp_timeout'}         = '5';

    # Check Result Processing Options
    if ( $nagios_ver eq '3.x' ) {
	$nagios{'check_result_path'}             = $nagios_dir . '/var/checkresults';
	$nagios{'check_result_reaper_frequency'} = '10';
	$nagios{'max_check_result_reaper_time'}  = '';
	$nagios{'max_check_result_file_age'}     = '';
    }
    else {
	$nagios{'service_reaper_frequency'} = '10';
    }

    # Object State Processing Options
    if ( $nagios_ver eq '3.x' ) {
	$nagios{'translate_passive_host_checks'} = '0';
	$nagios{'passive_host_checks_are_soft'}  = '0';
    }
    $nagios{'soft_state_dependencies'} = '0';

    # Flapping Control Options
    $nagios{'enable_flap_detection'}       = '0';
    $nagios{'low_host_flap_threshold'}     = '25.0';
    $nagios{'high_host_flap_threshold'}    = '50.0';
    $nagios{'low_service_flap_threshold'}  = '25.0';
    $nagios{'high_service_flap_threshold'} = '50.0';

    # Performance Data Processing Options
    # host_perfdata_file_mode and service_perfdata_file_mode had been set to 'a' prior to GW 5.2,
    # to work around a Nagios bug introduced in Nagios 2.5 and fixed as of Nagios 2.9. See GWMON-3363.
    $nagios{'process_performance_data'} = '1';
    $nagios{'host_perfdata_command'}    = 'process-host-perfdata';
    if ( $nagios_ver =~ /^[23]\.x$/ ) {
	$nagios{'host_perfdata_file'}                     = $nagios_dir . '/var/host-perfdata.dat';
	$nagios{'host_perfdata_file_template'}            = '';
	$nagios{'host_perfdata_file_mode'}                = 'w';
	$nagios{'host_perfdata_file_processing_interval'} = '';
	$nagios{'host_perfdata_file_processing_command'}  = '';
    }
    ## FIX MAJOR:  See GWMON-10487:  These are no longer our standard seed-data values for service perfdata.
    $nagios{'service_perfdata_command'} = 'process-service-perfdata';
    if ( $nagios_ver =~ /^[23]\.x$/ ) {
	$nagios{'service_perfdata_file'}                     = $nagios_dir . '/var/service-perfdata.dat';
	$nagios{'service_perfdata_file_template'}            = '';
	$nagios{'service_perfdata_file_mode'}                = 'w';
	$nagios{'service_perfdata_file_processing_interval'} = '';
	$nagios{'service_perfdata_file_processing_command'}  = '';
    }
    $nagios{'perfdata_timeout'} = '5';

    # Event Handling Options
    $nagios{'enable_event_handlers'}        = '1';
    $nagios{'global_host_event_handler'}    = '';
    $nagios{'global_service_event_handler'} = '';
    $nagios{'event_handler_timeout'}        = '30';

    # Internal Operations Options
    $nagios{'nagios_user'}  = 'nagios';
    $nagios{'nagios_group'} = 'nagios';
    if ($is_portal) {
	$nagios{'lock_file'} = $nagios_dir . '/var/nagios.lock';
    }
    else {
	$nagios{'lock_file'} = '/tmp/nagios.lock';
    }
    if ( $nagios_ver eq '3.x' ) {
	$nagios{'precached_object_file'} = $nagios_dir . '/var/objects.precache';
    }
    $nagios{'temp_file'} = $nagios_dir . '/var/nagios.tmp';
    if ( $nagios_ver eq '3.x' ) {
	$nagios{'temp_path'} = $nagios_dir . '/tmp';
    }

    # State Retention Options
    $nagios{'retain_state_information'}   = '1';
    $nagios{'state_retention_file'}       = $nagios_dir . '/var/nagiosstatus.sav';
    $nagios{'retention_update_interval'}  = '60';
    $nagios{'use_retained_program_state'} = '1';
    if ( $nagios_ver =~ /^[23]\.x$/ ) {
	$nagios{'use_retained_scheduling_info'} = '1';
    }
    if ( $nagios_ver eq '3.x' ) {
	$nagios{'retained_host_attribute_mask'}            = '0';
	$nagios{'retained_process_host_attribute_mask'}    = '0';
	$nagios{'retained_contact_host_attribute_mask'}    = '0';
	$nagios{'retained_service_attribute_mask'}         = '0';
	$nagios{'retained_process_service_attribute_mask'} = '0';
	$nagios{'retained_contact_service_attribute_mask'} = '0';
    }

    # Large Installation Tweaks
    if ( $nagios_ver eq '3.x' ) {
	$nagios{'use_large_installation_tweaks'} = '1';
	$nagios{'enable_environment_macros'}     = '0';
	$nagios{'child_processes_fork_twice'}    = '0';
	$nagios{'free_child_process_memory'}     = '0';
    }

    # Logging Options
    $nagios{'log_file'}              = $nagios_dir . '/var/nagios.log';
    $nagios{'log_rotation_method'}   = 'd';
    $nagios{'log_archive_path'}      = $nagios_dir . '/var/archives';
    $nagios{'log_notifications'}     = '1';
    $nagios{'log_host_retries'}      = '1';
    $nagios{'log_service_retries'}   = '1';
    $nagios{'log_event_handlers'}    = '1';
    $nagios{'log_initial_states'}    = '0';
    $nagios{'log_external_commands'} = '1';
    if ( $nagios_ver eq '1.x' ) {
	$nagios{'log_passive_service_checks'} = '1';
    }
    else {
	$nagios{'log_passive_checks'} = '1';
    }
    $nagios{'use_syslog'} = '0';

    # Miscellaneous Directives

    # Obsolete Directives, not currently folded in to earlier categories
    if ( $nagios_ver =~ /^[12]\.x$/ ) {
	$nagios{'downtime_file'} = $nagios_dir . '/var/nagiosdowntime.log';
	$nagios{'comment_file'}  = $nagios_dir . '/var/nagioscomment.log';
    }

    return %nagios;
}

sub cgi_defaults(@) {
    my $nagios_ver = $_[1];
    my $nagios_dir = '/usr/local/nagios';
    if ($is_portal) { $nagios_dir = '/usr/local/nagios' }
    my %cgi = ();
    $cgi{'physical_html_path'}                = $nagios_dir . '/share';
    $cgi{'url_html_path'}                     = '/nagios';
    $cgi{'show_context_help'}                 = '1';
    if ( $nagios_ver eq '1.x' ) {
	$cgi{'nagios_check_command'} = "$nagios_dir/libexec/check_nagios $nagios_dir/var/status.log 5 '$nagios_dir/bin/.nagios.bin'";
    }
    $cgi{'use_authentication'}                = '1';
    $cgi{'default_user_name'}                 = 'admin';
    $cgi{'authorized_for_read_only'}                 = '';
    $cgi{'authorized_for_configuration_information'} = 'admin,jdoe';
    $cgi{'authorized_for_system_information'}        = 'admin,theboss,jdoe';
    $cgi{'authorized_for_system_commands'}           = 'admin';
    $cgi{'authorized_for_all_hosts'}                 = 'admin,guest';
    $cgi{'authorized_for_all_host_commands'}         = 'admin';
    $cgi{'authorized_for_all_services'}              = 'admin,guest';
    $cgi{'authorized_for_all_service_commands'}      = 'admin';
    $cgi{'authorized_contactgroup_for_read_only'}                 = '';
    $cgi{'authorized_contactgroup_for_configuration_information'} = '';
    $cgi{'authorized_contactgroup_for_system_information'}        = '';
    $cgi{'authorized_contactgroup_for_system_commands'}           = '';
    $cgi{'authorized_contactgroup_for_all_hosts'}                 = '';
    $cgi{'authorized_contactgroup_for_all_host_commands'}         = '';
    $cgi{'authorized_contactgroup_for_all_services'}              = '';
    $cgi{'authorized_contactgroup_for_all_service_commands'}      = '';

    if ( $nagios_ver eq '3.x' ) {
	$cgi{'lock_author_names'} = '0';
    }
    $cgi{'statusmap_background_image'} = 'states.png';
    $cgi{'default_statusmap_layout'}   = '5';
    $cgi{'default_statuswrl_layout'}   = '2';
    $cgi{'refresh_rate'}               = '90';
    $cgi{'statuswrl_include'}          = 'myworld.wrl';
    $cgi{'ping_syntax'}                = '/bin/ping -n -U -c 5 $HOSTADDRESS$';
    $cgi{'host_unreachable_sound'}     = '';
    $cgi{'host_down_sound'}            = '';
    $cgi{'service_critical_sound'}     = '';
    $cgi{'service_warning_sound'}      = '';
    $cgi{'service_unknown_sound'}      = '';
    $cgi{'normal_sound'}               = '';
    if ( $nagios_ver eq '3.x' ) {
	$cgi{'result_limit'} = '75';
    }
    ## FIX LATER:  The following options should really only apply to Nagios 4.3.X and later.
    if ( $nagios_ver eq '3.x' ) {
	$cgi{'ack_no_send'}        = '0';
	$cgi{'ack_no_sticky'}      = '0';
	$cgi{'tac_cgi_hard_only'}  = '0';
	$cgi{'use_pending_states'} = '1';
    }

    if ( $nagios_ver eq '1.x' ) {
	$cgi{'ddb'} = '';
    }
    return %cgi;
}

sub load_nagios_cfg() {
    my $nagios_etc = $_[1];
    my $nagios_ver = $_[2];
    my @errors     = ();
    my $result     = delete_all( '', 'setup', 'type', 'nagios' );
    if ( $result =~ /^Error/ ) { push @errors, $result }
    my %ddb        = ();
    my %nagios     = nagios_defaults( '', $nagios_ver, '' );
    if ( !open( FILE, '<', "$nagios_etc/nagios.cfg" ) ) {
	push @errors, "Error: Unable to open $nagios_etc/nagios.cfg ($!)";
    }
    else {
	while ( my $line = <FILE> ) {
	    if ( $line =~ /^#|^cfg_file|^cfg_dir/ ) { next }
	    if ( $line =~ /(\S+)\s*=\s*(.*)$/ ) {
		my $directive = $1;
		my $value     = $2;
		$nagios{$directive} = $value;
	    }
	    elsif ( $line =~ /^x?ddb_/ ) {
		## $ddb{'ddb'} = $line;
		next;
	    }
	}
	close(FILE);
    }
    foreach my $name ( keys %nagios ) {
	my @vals = ( $name, 'nagios', $nagios{$name} );
	my $result = insert_obj( '', 'setup', \@vals );
	if ( $result =~ /^Error/ ) { push @errors, $result }
    }
    return @errors;
}

sub import_nagios_cfg(@) {
    my $gid      = $_[1];
    my $filename = $_[2];
    my $filedata = $_[3];
    my $replace  = $_[4];
    my @errors   = ();
    my %nagios   = ();
    while ( $filedata =~ /^\s*([^#\s]\S*)[ \t]*=[ \t]*(.*)$/gm ) {
	my $directive = $1;
	my $value     = $2;
	next if ( $directive =~ /^cfg_file|^cfg_dir|^x?ddb_/ );
	$nagios{$directive} = $value;
    }
    if (scalar (keys %nagios) == 0) {
	push @errors, "Error: File \"$filename\" contains no Nagios main configuration definitions.";
    }
    unless (@errors) {
	if ($replace) {
	    my %where = ( 'group_id' => $gid, 'type' => 'nagios_cfg' );
	    my $result = delete_one_where( '', 'monarch_group_props', \%where );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	}
    }
    unless (@errors) {
	## FIX MINOR:  merge operation ($replace == 0) is not supported here yet
	foreach my $name ( keys %nagios ) {
	    my @vals = ( \undef, $gid, $name, 'nagios_cfg', $nagios{$name} );
	    my $result = StorProc->insert_obj( 'monarch_group_props', \@vals );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	}
    }
    return @errors;
}

sub load_nagios_cgi(@) {
    my $nagios_etc = $_[1];
    my $nagios_ver = $_[2];
    my @errors     = ();
    if ( !open( FILE, '<', "$nagios_etc/cgi.cfg" ) ) {
	push @errors, "Error: Unable to open $nagios_etc/cgi.cfg ($!)";
    }
    else {
	my %nagios = cgi_defaults( '', $nagios_ver );
	while ( my $line = <FILE> ) {
	    if ( $line =~ /^#|^main_config_file|^cfg_dir/ ) { next }
	    if ( $line =~ /(\S+)\s*=\s*(.*)$/ ) {
		my $directive = $1;
		my $value     = $2;
		next if ( $directive =~ /ddb_/ );
		$nagios{$directive} = $value;
	    }
	}
	close(FILE);
	my $result = delete_all( '', 'setup', 'type', 'nagios_cgi' );
	if ( $result =~ /^Error/ ) { push @errors, $result }
	foreach my $name ( keys %nagios ) {
	    my @vals = ( $name, 'nagios_cgi', $nagios{$name} );
	    my $result = insert_obj( '', 'setup', \@vals );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	}
    }
    return @errors;
}

sub import_nagios_cgi(@) {
    my $gid      = $_[1];
    my $filename = $_[2];
    my $filedata = $_[3];
    my $replace  = $_[4];
    my @errors   = ();
    my %nagios   = ();
    while ( $filedata =~ /^\s*([^#\s]\S*)[ \t]*=[ \t]*(.*)$/gm ) {
	my $directive = $1;
	my $value     = $2;
	next if ( $directive =~ /^main_config_file|^cfg_dir|ddb_/ );
	$nagios{$directive} = $value;
    }
    if (scalar (keys %nagios) == 0) {
	push @errors, "Error: File \"$filename\" contains no Nagios CGI definitions.";
    }
    unless (@errors) {
	if ($replace) {
	    my %where = ( 'group_id' => $gid, 'type' => 'nagios_cgi' );
	    my $result = delete_one_where( '', 'monarch_group_props', \%where );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	}
    }
    unless (@errors) {
	## FIX MINOR:  merge operation ($replace == 0) is not supported here yet
	foreach my $name ( keys %nagios ) {
	    my @vals = ( \undef, $gid, $name, 'nagios_cgi', $nagios{$name} );
	    my $result = insert_obj( '', 'monarch_group_props', \@vals );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	}
    }
    return @errors;
}

sub import_resource_cfg(@) {
    my $gid      = $_[1];
    my $filename = $_[2];
    my $filedata = $_[3];
    my $replace  = $_[4];
    my @errors   = ();
    my %value    = ();
    my %comment  = ();
    my $comment  = undef;
    my @lines = split( /\n/, $filedata );
    foreach my $line (@lines) {
	if ( $line =~ /^\s*\$USER(\d+)\$\s*=\s*(.*)$/ ) {
	    $value{$1}   = $2;
	    $comment{$1} = $comment;
	    $comment     = undef;
	}
	elsif ($line !~ /^#GW|##GROUNDWORK##/) {
	    $line =~ s/^#\s*//;
	    $comment .= $line;
	}
    }
    if (scalar (keys %value) == 0) {
	push @errors, "Error: File \"$filename\" contains no Nagios resource definitions.";
    }
    unless (@errors) {
	if ($replace) {
	    my %where = ( 'group_id' => $gid, 'type' => 'resource' );
	    my $result = delete_one_where( '', 'monarch_group_props', \%where );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	}
    }
    unless (@errors) {
	## FIX MINOR:  merge operation ($replace == 0) is not supported here yet
	foreach my $num (keys %value) {
	    my @vals = ( \undef, $gid, 'user' . $num, 'resource', $value{$num} );
	    my $result = insert_obj( '', 'monarch_group_props', \@vals );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	    @vals = ( \undef, $gid, 'resource_label' . $num, 'resource', $comment{$num} );
	    $result = insert_obj( '', 'monarch_group_props', \@vals );
	    if ( $result =~ /^Error/ ) { push @errors, $result }
	}
    }
    return @errors;
}

#
# Automation subs for MonarchAutoConfig.pm monarch_auto.cgi added 2007-Jan-16
#
sub get_discovery_groups() {
    my %discover_groups = ();
    my @errors  = ();
    my $sqlstmt =
	"select discover_group.group_id, discover_group.name, discover_group.description, "
      . "discover_group.config, import_schema.schema_id, import_schema.name "
      . "from discover_group, import_schema "
      . "where discover_group.schema_id = import_schema.schema_id";
    my $sth = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	my $discovery_name = $values[1];
	$discover_groups{$discovery_name}{'id'}          = $values[0];
	$discover_groups{$discovery_name}{'description'} = $values[2];
	$discover_groups{$discovery_name}{'schema_id'}   = $values[4];
	$discover_groups{$discovery_name}{'schema'}      = $values[5];
	my %data = parse_xml( '', $values[3] );
	push @errors, delete $data{'error'} if defined $data{'error'};
	foreach my $key ( keys %data ) {
	    $discover_groups{$discovery_name}{$key} = $data{$key};
	}
	$sqlstmt =
"select discover_method.method_id, discover_method.name, discover_method.description, discover_method.config, discover_method.type from discover_method "
	  . "left join discover_group_method on discover_method.method_id = discover_group_method.method_id "
	  . "where discover_group_method.group_id = '$values[0]'";
	my $sth2 = $dbh->prepare($sqlstmt);
	$sth2->execute;
	while ( my @vals = $sth2->fetchrow_array() ) {
	    $discover_groups{$discovery_name}{'method'}{ $vals[1] }{'method_id'}   = $vals[0];
	    $discover_groups{$discovery_name}{'method'}{ $vals[1] }{'description'} = $vals[2];
	    $discover_groups{$discovery_name}{'method'}{ $vals[1] }{'type'}        = $vals[4];
	    %data = parse_xml( '', $vals[3] );
	    push @errors, delete $data{'error'} if defined $data{'error'};
	    foreach my $key ( keys %data ) {
		$discover_groups{$discovery_name}{'method'}{ $vals[1] }{$key} = $data{$key};
	    }
	    $sqlstmt =
		"select discover_filter.filter_id, discover_filter.name, discover_filter.type, discover_filter.filter from discover_filter "
	      . "left join discover_method_filter on discover_filter.filter_id = discover_method_filter.filter_id "
	      . "where discover_method_filter.method_id = '$vals[0]'";
	    my $sth3 = $dbh->prepare($sqlstmt);
	    $sth3->execute;
	    while ( my @f_vals = $sth3->fetchrow_array() ) {
		$discover_groups{$discovery_name}{'method'}{ $vals[1] }{'filter'}{ $f_vals[1] }{'filter_id'} = $f_vals[0];
		$discover_groups{$discovery_name}{'method'}{ $vals[1] }{'filter'}{ $f_vals[1] }{'type'}      = $f_vals[2];
		$discover_groups{$discovery_name}{'method'}{ $vals[1] }{'filter'}{ $f_vals[1] }{'filter'}    = $f_vals[3];
	    }
	    $sth3->finish;
	}
	$sth2->finish;

	$sqlstmt =
	    "select discover_filter.filter_id, discover_filter.name, discover_filter.type, discover_filter.filter from discover_filter "
	  . "left join discover_group_filter on discover_filter.filter_id = discover_group_filter.filter_id "
	  . "where discover_group_filter.group_id = '$values[0]'";
	$sth2 = $dbh->prepare($sqlstmt);
	$sth2->execute;
	while ( my @vals = $sth2->fetchrow_array() ) {
	    $discover_groups{$discovery_name}{'filter'}{ $vals[1] }{'filter_id'} = $vals[0];
	    $discover_groups{$discovery_name}{'filter'}{ $vals[1] }{'type'}      = $vals[2];
	    $discover_groups{$discovery_name}{'filter'}{ $vals[1] }{'filter'}    = $vals[3];
	}
	$sth2->finish;
    }
    $sth->finish;
    return \@errors, %discover_groups;
}

sub get_discovery_methods() {
    my %discover_methods = ();
    my @errors           = ();
    my $sqlstmt          = "select * from discover_method";
    my $sth              = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	$discover_methods{ $values[1] }{'id'}          = $values[0];
	$discover_methods{ $values[1] }{'description'} = $values[2];
	my %data = parse_xml( '', $values[3] );
	push @errors, delete $data{'error'} if defined $data{'error'};
	foreach my $key ( keys %data ) {
	    $discover_methods{ $values[1] }{$key} = $data{$key};
	}
	$discover_methods{ $values[1] }{'type'} = $values[4];
	$sqlstmt =
	    "select discover_filter.filter_id, discover_filter.name, discover_filter.type, discover_filter.filter from discover_filter "
	  . "left join discover_method_filter on discover_filter.filter_id = discover_method_filter.filter_id "
	  . "where discover_method_filter.method_id = '$values[0]'";
	my $sth2 = $dbh->prepare($sqlstmt);
	$sth2->execute;
	while ( my @vals = $sth2->fetchrow_array() ) {
	    $discover_methods{ $values[1] }{'filter'}{ $vals[1] }{'filter_id'} = $vals[0];
	    $discover_methods{ $values[1] }{'filter'}{ $vals[1] }{'type'}      = $vals[2];
	    $discover_methods{ $values[1] }{'filter'}{ $vals[1] }{'filter'}    = $vals[3];
	}
	$sth2->finish;
    }
    $sth->finish;
    return \@errors, %discover_methods;
}

sub get_discovery_filters() {
    my %discover_filters = ();
    my $sqlstmt          = "select * from discover_filter";
    my $sth              = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	$discover_filters{ $values[1] }{'id'}     = $values[0];
	$discover_filters{ $values[1] }{'type'}   = $values[2];
	$discover_filters{ $values[1] }{'filter'} = $values[3];
    }
    $sth->finish;
    return %discover_filters;
}

sub fetch_schema(@) {
    my $name                = $_[1];
    my %host_name           = get_table_objects( '', 'hosts', '1' );
    my %hostgroup_name      = get_table_objects( '', 'hostgroups', '1' );
    my %group_name          = get_table_objects( '', 'monarch_groups', '1' );
    my %contactgroup_name   = get_table_objects( '', 'contactgroups', '1' );
    my %serviceprofile_name = get_table_objects( '', 'profiles_service', '1' );
    my %service_name        = get_table_objects( '', 'service_names', '1' );

    my %schema = fetch_one( '', 'import_schema', 'name', $name );
    if ( $schema{'hostprofile_id'} ) {
	my %profile = fetch_one( '', 'profiles_host', 'hostprofile_id', $schema{'hostprofile_id'} );
	$schema{'default_profile'} = $profile{'name'};
    }
    my $sqlstmt = "select * from import_column where schema_id = '$schema{'schema_id'}'";
    my $sth     = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	$schema{'column'}{ $values[0] }{'name'}      = $values[2];
	$schema{'column'}{ $values[0] }{'position'}  = $values[3];
	$schema{'column'}{ $values[0] }{'delimiter'} = $values[4];
	$sqlstmt                                     = "select * from import_match where column_id = $values[0]";
	my $sth2 = $dbh->prepare($sqlstmt);
	$sth2->execute;
	while ( my @vals = $sth2->fetchrow_array() ) {
	    $schema{'column'}{ $values[0] }{'match'}{ $vals[0] }{'name'}         = $vals[2];
	    $schema{'column'}{ $values[0] }{'match'}{ $vals[0] }{'order'}        = $vals[3];
	    $schema{'column'}{ $values[0] }{'match'}{ $vals[0] }{'match_type'}   = $vals[4];
	    $schema{'column'}{ $values[0] }{'match'}{ $vals[0] }{'match_string'} = $vals[5];
	    $schema{'column'}{ $values[0] }{'match'}{ $vals[0] }{'rule'}         = $vals[6];
	    $schema{'column'}{ $values[0] }{'match'}{ $vals[0] }{'object'}       = $vals[7];
	    if ( $vals[8] ) {
		my %host_profile = fetch_one( '', 'profiles_host', 'hostprofile_id', $vals[8] );
		$schema{'column'}{ $values[0] }{'match'}{ $vals[0] }{'hostprofile'} = $host_profile{'name'};
	    }
	    if ( $vals[9] ) {
		my %service_name = fetch_one( '', 'service_names', 'servicename_id', $vals[9] );
		$schema{'column'}{ $values[0] }{'match'}{ $vals[0] }{'service_name'} = $service_name{'name'};
		$schema{'column'}{ $values[0] }{'match'}{ $vals[0] }{'arguments'}    = $vals[10];
	    }

	    @{ $schema{'column'}{ $values[0] }{'match'}{ $vals[0] }{'parents'} } = ();
	    $sqlstmt = "select parent_id from import_match_parent where match_id = $vals[0]";
	    my $sth3 = $dbh->prepare($sqlstmt);
	    $sth3->execute;
	    while ( my @vals2 = $sth3->fetchrow_array() ) {
		push @{ $schema{'column'}{ $values[0] }{'match'}{ $vals[0] }{'parents'} }, $host_name{ $vals2[0] };
	    }
	    $sth3->finish;

	    @{ $schema{'column'}{ $values[0] }{'match'}{ $vals[0] }{'hostgroups'} } = ();
	    $sqlstmt = "select hostgroup_id from import_match_hostgroup where match_id = $vals[0]";
	    $sth3    = $dbh->prepare($sqlstmt);
	    $sth3->execute;
	    while ( my @vals2 = $sth3->fetchrow_array() ) {
		push @{ $schema{'column'}{ $values[0] }{'match'}{ $vals[0] }{'hostgroups'} }, $hostgroup_name{ $vals2[0] };
	    }
	    $sth3->finish;

	    @{ $schema{'column'}{ $values[0] }{'match'}{ $vals[0] }{'groups'} } = ();
	    $sqlstmt = "select group_id from import_match_group where match_id = $vals[0]";
	    $sth3    = $dbh->prepare($sqlstmt);
	    $sth3->execute;
	    while ( my @vals2 = $sth3->fetchrow_array() ) {
		push @{ $schema{'column'}{ $values[0] }{'match'}{ $vals[0] }{'groups'} }, $group_name{ $vals2[0] };
	    }
	    $sth3->finish;

	    @{ $schema{'column'}{ $values[0] }{'match'}{ $vals[0] }{'contactgroups'} } = ();
	    $sqlstmt = "select contactgroup_id from import_match_contactgroup where match_id = $vals[0]";
	    $sth3    = $dbh->prepare($sqlstmt);
	    $sth3->execute;
	    while ( my @vals2 = $sth3->fetchrow_array() ) {
		push @{ $schema{'column'}{ $values[0] }{'match'}{ $vals[0] }{'contactgroups'} }, $contactgroup_name{ $vals2[0] };
	    }
	    $sth3->finish;

	    @{ $schema{'column'}{ $values[0] }{'match'}{ $vals[0] }{'serviceprofiles'} } = ();
	    $sqlstmt = "select serviceprofile_id from import_match_serviceprofile where match_id = $vals[0]";
	    $sth3    = $dbh->prepare($sqlstmt);
	    $sth3->execute;
	    while ( my @vals2 = $sth3->fetchrow_array() ) {
		push @{ $schema{'column'}{ $values[0] }{'match'}{ $vals[0] }{'serviceprofiles'} }, $serviceprofile_name{ $vals2[0] };
	    }
	    $sth3->finish;
	}
	$sth2->finish;
    }
    $sth->finish;
    return %schema;
}

sub get_hosts_vitals() {
    my %hosts_vitals = ();
    my $sqlstmt      = "select host_id, name, address, alias from hosts";
    my $sth          = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	$hosts_vitals{'name'}{ $values[1] }    = $values[0];
	$hosts_vitals{'address'}{ $values[2] } = $values[0];
	$hosts_vitals{'alias'}{ $values[3] }   = $values[0];
    }
    $sth->finish;
    return %hosts_vitals;
}

sub profile_sync(@) {
    my %import_data = %{ $_[1] };
    my %import_host = %{ $_[2] };
    my %schema      = %{ $_[3] };
    my $sqlstmt     = "select name, host_id from hosts where hostprofile_id = '$schema{'hostprofile_id'}'";
    my $sth         = $dbh->prepare($sqlstmt);
    $sth->execute;
    while ( my @values = $sth->fetchrow_array() ) {
	unless ( $import_host{ $values[0] } ) {
	    my $rec = $values[0];
	    $import_data{$rec}{'delete'}  = 1;
	    $import_data{$rec}{'Name'}    = $values[0];
	    $import_data{$rec}{'host_id'} = $values[1];
	}
    }
    $sth->finish;
    return %import_data;
}

sub parse_form_xml(@) {
    my $data      = $_[1];
    my %externals = $_[2];
    if ($data) {
	my $parser = XML::LibXML->new(
	    ext_ent_handler => sub { die "INVALID FORMAT: external entity references are not allowed in form data.\n" },
	    no_network      => 1
	);
	my $doc = undef;
	eval {
	    $doc = $parser->parse_string($data);
	};
	if ($@) {
	    my ($package, $file, $line) = caller;
	    print STDERR $@, " called from $file line $line.";
	    ## FIX LATER:  HTMLifying here, along with embedded markup in $externals{'error'}, is something of a hack,
	    ## as it presumes a context not in evidence.  But it's necessary in the browser context.
	    $@ = HTML::Entities::encode($@);
	    $@ =~ s/\n/<br>/g;
	    if ($@ =~ s/external entity callback died: // || $@ =~ /external entity references are not allowed/) {
		## First undo the effect of the croak() call in XML::LibXML.
		$@ =~ s/ at \S+ line \d+<br>//;
		$externals{'error'} = "Bad XML string (parse_form_xml):<br>$@";
	    }
	    elsif ($@ =~ /Attempt to load network entity/) {
		$externals{'error'} = "Bad XML string (parse_form_xml):<br>INVALID FORMAT: non-local entity references are not allowed in form data.<pre>$@</pre>";
	    }
	    else {
		$externals{'error'} = "Bad XML string (parse_form_xml):<br>$@ called from $file line $line.";
	    }
	}
	else {
	    my @nodes = $doc->findnodes("//external_checks/external_check");
	    foreach my $node (@nodes) {
		if ( $node->hasAttributes() ) {
		    my $name        = $node->getAttribute('name');
		    my $description = $node->getAttribute('description');
		    my $enable      = $node->getAttribute('enable');
		    if ( $node->hasChildNodes() ) {
			my @children = $node->getChildnodes();
			foreach my $child (@children) {
			    if ( $child->nodeName() eq 'service' ) {
				$externals{$name}{'service_name'} = $child->getAttribute('name');
			    }
			    if ( $child->nodeName() eq 'command' ) {
				$externals{$name}{'command'}{'name'} = $child->getAttribute('name');
				if ( $child->hasChildNodes() ) {
				    my @params = $child->getChildnodes();
				    foreach my $param (@params) {
					if ( $param->hasAttributes() ) {
					    my $pname = $param->getAttribute('name');
					    $externals{$name}{'command'}{$pname}{'value'}       = $param->textContent;
					    $externals{$name}{'command'}{$pname}{'description'} = $param->getAttribute('description')
					      if $param->hasAttributes();
					}
				    }
				}
			    }
			}
		    }
		}
	    }
	}
    }
    else {
	my ($package, $file, $line) = caller;
	$externals{'error'} = "Empty String (parse_form_xml); called from $file line $line.";
    }
    return %externals;
}

# Internal routine only.
sub execute_backup {
    my $errors    = $_[0];    # \@errors
    my $results   = $_[1];    # \@results
    my $timings   = $_[2];    # \@timings
    my $starttime = $_[3];    # \$starttime
    my $majortime = $_[4];    # \$majortime
    my $phasetime = $_[5];    # \$phasetime

    my $nagios_etc = $_[6];
    my $backup_dir = $_[7];
    my $user_acct  = $_[8];
    my $annotation = $_[9];
    my $lock       = $_[10];

    my ( $full_backup_dir, $backup_errors ) = StorProc->backup( $nagios_etc, $backup_dir, $user_acct, $annotation, $lock );
    push @$errors,  @$backup_errors;
    push @$results, $full_backup_dir;
}

sub synchronized_backup(@) {
    my $self = shift;
    return synchronized_action( undef, undef, \&execute_backup, \@_ );
}

# Internal routine only.
sub execute_restore {
    my $errors    = $_[0];    # \@errors
    my $results   = $_[1];    # \@results
    my $timings   = $_[2];    # \@timings
    my $starttime = $_[3];    # \$starttime
    my $majortime = $_[4];    # \$majortime
    my $phasetime = $_[5];    # \$phasetime

    my $backup_dir  = $_[6];
    my $backup_time = $_[7];
    my $user_acct   = $_[8];
    my $interactive = $_[9];
    my $skip_clean  = $_[10];

    if ($interactive) {
	my $restore_errors = StorProc->restore( $backup_dir, $backup_time, $user_acct, $interactive, $skip_clean );
	push @$errors, @$restore_errors;
    }
    else {
	push @$results,
	  'To restore the Monarch database from the selected backup,'
	  . ' log into a terminal window on the GroundWork Monitor server <b>as the nagios user</b>, and run the following command:',
	  '<br><tt>/usr/local/groundwork/monarch/bin/monarch_restore_from_backup -b ' . HTML::Entities::encode($backup_time) . '</tt><br>',
	  "If that fails, use this command instead, to start from a fresh (empty) database:",
	  '<br><tt>/usr/local/groundwork/monarch/bin/monarch_restore_from_backup -f -b ' . HTML::Entities::encode($backup_time) . '</tt><br>';
    }
}

sub synchronized_restore(@) {
    my $self = shift;
    return synchronized_action( undef, undef, \&execute_restore, \@_ );
}

sub delete_one_backup(@) {
    my $backup_dir  = $_[1];
    my $backup_time = $_[2];
    my $force       = $_[3];
    my @errors      = ();
    my @results     = ();

    my $full_backup_dir = "$backup_dir/$backup_time";
    if ( not $backup_time =~ /^\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}$/ ) {
	push @errors, "Error:  Invalid backup time \"$backup_time\".";
    }
    elsif ( -l $full_backup_dir ) {
	push @errors, "Error:  The $full_backup_dir/ directory is a symlink.";
    }
    elsif ( !-d _ ) {
	push @errors, "Error:  The $full_backup_dir/ directory cannot be found ($!).";
    }
    elsif ( !$force && -e "$full_backup_dir/monarch-$backup_time.locked" ) {
	( my $human_time = $backup_time ) =~ s/_(\d\d)-(\d\d)-/&nbsp;$1:$2:/;
	push @errors, "Error:  The $human_time backup is locked, so it will not be deleted.";
    }
    elsif ( not opendir( DIR, $full_backup_dir ) ) {
	push @errors, "Error:  Cannot open the backup directory $full_backup_dir for reading ($!).";
    }
    else {
	require POSIX;
	while ( my $file = readdir(DIR) ) {
	    next if $file eq '.' or $file eq '..';
	    my $backup_file = "$full_backup_dir/$file";
	    if ( !-f $backup_file ) {
		push @errors, "Error:  The backup file $backup_file is not an ordinary file.";
	    }
	    elsif ( not unlink $backup_file ) {
		push @errors, "Error:  Cannot remove the $backup_file file ($!)." if $! != POSIX::ENOENT;
	    }
	}
	closedir DIR;
	if ( not rmdir $full_backup_dir ) {
	    push @errors, "Error:  Cannot remove the $full_backup_dir directory ($!)." if $! != POSIX::ENOENT;
	}
	else {
	    ( my $human_time = $backup_time ) =~ s/_(\d\d)-(\d\d)-/&nbsp;$1:$2:/;
	    push @results, "Removed the $human_time Monarch backup.";
	}
    }

    return \@errors, \@results;
}

sub delete_excess_backups(@) {
    my $backup_dir = $_[1];
    local $_;

    my @errors  = ();
    my @results = ();

    my %p = StorProc->fetch_one( 'setup', 'name', 'max_unlocked_backups' );
    my $max_unlocked_backups = $p{'value'};

    if ($max_unlocked_backups) {
	if ( not opendir( DIR, $backup_dir ) ) {
	    push @errors, "Error:  Could not open the backup base directory $backup_dir for reading ($!).";
	}
	else {
	    my @subdirs = readdir DIR;
	    closedir DIR;

	    my @backup_times = sort grep {
		     /^\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}$/
		  && !-l "$backup_dir/$_"
		  && !-f "$backup_dir/$_/monarch-$_.locked"
		  && ( -f "$backup_dir/$_/monarch-$_.sql.tar"
		    || -f "$backup_dir/$_/monarch-$_.sql" )
	    } @subdirs;

	    if ( @backup_times > $max_unlocked_backups ) {
		splice @backup_times, -$max_unlocked_backups, $max_unlocked_backups;
		foreach my $backup_time (@backup_times) {
		    my ( $errors, $results ) = StorProc->delete_one_backup( $backup_dir, $backup_time );
		    push @errors,  @$errors;
		    push @results, @$results;
		}
	    }
	}
    }

    return \@errors, \@results;
}

# Intended for internal use only; use synchronized_backup() instead.
sub backup(@) {
    my $nagios_etc = $_[1];
    my $backup_dir = $_[2];
    my $user_acct  = $_[3];
    my $annotation = $_[4];
    my $lock       = $_[5];
    local $_;

    my @errors = ();

    if ( !$nagios_etc || !$backup_dir ) {
	push @errors, "Error:  Cannot create a Monarch backup due to missing internal parameters.";
	return undef, \@errors;
    }

    my @files = ("$nagios_etc/nagios.cfg", "$nagios_etc/cgi.cfg");
    my @dirs  = ();
    if ( !open( FILE, '<', "$nagios_etc/nagios.cfg" ) ) {
	push @errors, "Error:  Cannot open $nagios_etc/nagios.cfg to read ($!).";
    }
    else {
	while ( my $line = <FILE> ) {
	    if ( $line =~ /^\s*cfg_file\s*=\s*(\S+)$/ )      { push @files, $1 }
	    if ( $line =~ /^\s*cfg_dir\s*=\s*(\S+)$/ )       { push @dirs,  $1 }
	    if ( $line =~ /^\s*resource_file\s*=\s*(\S+)$/ ) { push @files, $1 }
	}
	close(FILE);
    }
    if ( !open( FILE, '<', "$nagios_etc/cgi.cfg" ) ) {
	push @errors, "Error:  Cannot open $nagios_etc/cgi.cfg to read ($!).";
    }
    else {
	while ( my $line = <FILE> ) {
	    if ( $line =~ /^\s*xedtemplate_config_file\s*=\s*(\S+)$/ ) {
		push @files, $1;
	    }
	}
	close(FILE);
    }
    foreach my $dir (@dirs) {
	if ( !opendir( DIR, $dir ) ) {
	    push @errors, "Error:  Cannot open $dir to read ($!).";
	}
	else {
	    while ( my $file = readdir(DIR) ) {
		if ( $file =~ /^#/ ) { next }
		if ( $file =~ /(\S+\.cfg)$/ ) { push @files, "$dir/$1" }
	    }
	    closedir(DIR);
	}
    }
    my $dt = StorProc->datetime();
    $dt =~ s/\s/_/g;
    $dt =~ s/:/-/g;
    my $full_backup_dir = "$backup_dir/$dt";
    if ( not mkdir( $full_backup_dir, 0770 ) ) {
	push @errors, "Error:  Cannot create backup directory $full_backup_dir ($!).";
    }
    else {
	require File::Copy;

	foreach my $file (@files) {
	    my $fname = '';
	    if ( $file =~ m{.*/(.+\.cfg)} ) { $fname = $1 }
	    if ( not File::Copy::copy( $file, "$full_backup_dir/$fname" ) ) {
		push @errors, "Error:  Unable to copy $file to $full_backup_dir/$fname ($!).";
		last;
	    }
	}

	if ( defined $annotation ) {
	    my $ann_file = "$full_backup_dir/monarch-$dt.annotation";
	    if ( not open( ANN, '>', $ann_file ) ) {
		push @errors, "Error:  Cannot open annotation file $ann_file for writing ($!).";
	    }
	    else {
		$annotation .= "\n" if $annotation !~ /\n$/;
		my $got_errno = '';
		if ( not print ANN $annotation ) {
		    $got_errno = "$!";
		}
		if ( not close(ANN) and not $got_errno ) {
		    $got_errno = "$!";
		}
		if ($got_errno) {
		    push @errors, "Error:  Cannot write annotation to $ann_file ($got_errno).";
		}
	    }
	}
	else {
	    $annotation = '';
	}
	if ($lock) {
	    my $locked_file = "$full_backup_dir/monarch-$dt.locked";
	    if ( !open( LOCKED, '>', $locked_file ) || !close(LOCKED) ) {
		push @errors, "Error:  Cannot touch backup lock file $locked_file ($!).";
	    }
	}

	if ( defined($dbtype) && $dbtype eq 'postgresql' ) {
	    my $postgres_dump = ( -x '/usr/bin/pg_dump' ) ? '/usr/bin/pg_dump' : undef;
	    if (not $postgres_dump) {
		push @errors, "Error:  Cannot find pg_dump!  Unable to back up the $database database.";
	    }
	    else {
		local %ENV = %ENV;
		delete $ENV{PGCLIENTENCODING};
		delete $ENV{PGDATABASE};
		delete $ENV{PGDATESTYLE};
		delete $ENV{PGGEQO};
		delete $ENV{PGHOSTADDR};
		delete $ENV{PGHOST};
		delete $ENV{PGLOCALEDIR};
		delete $ENV{PGOPTIONS};
		delete $ENV{PGPASSFILE};
		delete $ENV{PGPASSWORD};
		delete $ENV{PGPORT};
		delete $ENV{PGSERVICEFILE};
		delete $ENV{PGSERVICE};
		delete $ENV{PGSYSCONFDIR};
		delete $ENV{PGTZ};
		delete $ENV{PGUSER};
		$ENV{PGCONNECT_TIMEOUT} = 20;
		$ENV{PGREQUIREPEER} = 'postgres';
		$ENV{SHELL} = '/bin/false';
		$ENV{PATH} = '/bin:/sbin:/usr/bin:/usr/sbin';

		# For development use only.
		# $backup_format = 'plain' if defined($annotation) and $annotation =~ /plain/i;

		my $sqlfile = "$full_backup_dir/monarch-$dt.sql" . ( $backup_format eq 'tar' ? '.tar' : '' );
		my $dump_command = "$postgres_dump --host=$dbhost --username=$user --no-password"
		  ## FIX LATER:  If we ever want to allow interactive restores as the "monarch" user,
		  ## we would need these commands executed in the database at install time:
		  ##   \connect monarch
		  ##   ALTER SCHEMA public OWNER TO monarch;
		  ## and we would need these two options here in $dump_command as well,
		  ## to suppress commands dealing with the plpgsql extension.
		  ##   . " --schema=public --blobs"
		  . " --file='$sqlfile' --format=$backup_format --clean --encoding=LATIN1 $database 2>&1";
		$ENV{PGPASSWORD} = $passwd;
		my @results     = qx($dump_command);
		delete $ENV{PGPASSWORD};
		my $wait_status = $?;
		push @errors, 'Error:  Got ' . wait_status_message($wait_status) . ' from backup command.' if $wait_status;
		push @errors, @results;

		if ( $backup_format eq 'plain' ) {
		    ## FIX LATER:  Pg 9.4 includes a pg_dump --if-exists option that includes IF EXISTS clauses in the dump, to avoid
		    ## anomalous errors upon restore if certain objects are not already present.  Simulate that here as best we can in Pg 9.1.
		    my $tmpfile = "$sqlfile.tmp";
		    if ( not open SQL, '<', $sqlfile ) {
			push @errors, "Error:  Cannot open generated dump file $sqlfile to add IF EXISTS clauses ($!).";
		    }
		    elsif ( not open TMP, '>', $tmpfile ) {
			close SQL;
			push @errors, "Error:  Cannot open temporary dump file $tmpfile to add IF EXISTS clauses ($!).";
		    }
		    else {
			my $got_errno = '';
			my $in_copy = 0;
			while (<SQL>) {
			    if ($in_copy) {
				$in_copy = 0 if /^\\\.$/;
			    }
			    elsif (/^COPY /) {
				$in_copy = 1;
			    }
			    else {
				## FIX LATER:  Pg 9.2 and 9.3 support ALTER TABLE IF EXISTS.
				## Without that, we just depend on cascaded object deletion during DROP TABLE commands.
				## s/ALTER TABLE ONLY (\S+) DROP CONSTRAINT/ALTER TABLE IF EXISTS ONLY $1 DROP CONSTRAINT IF EXISTS/;
				## s/ALTER TABLE (\S+) ALTER COLUMN (\S+) DROP DEFAULT/ALTER TABLE IF EXISTS $1 ALTER COLUMN $2 DROP DEFAULT/;
				s/(ALTER TABLE ONLY \S+ DROP CONSTRAINT)/-- $1/;
				s/(ALTER TABLE \S+ ALTER COLUMN \S+ DROP DEFAULT)/-- $1/;

				s/DROP EXTENSION/DROP EXTENSION IF EXISTS/;

				# s/DROP INDEX/DROP INDEX IF EXISTS/;  # good for Pg 9.2 or 9.3; in 9.1, depend on DROP TABLE ... CASCADE
				s/(DROP INDEX)/-- $1/;

				s/DROP SCHEMA/DROP SCHEMA IF EXISTS/;

				# s/DROP SEQUENCE/DROP SEQUENCE IF EXISTS/;  # good for Pg 9.2 or 9.3; in 9.1, depend on DROP TABLE ... CASCADE
				s/(DROP SEQUENCE)/-- $1/;

				# s/DROP TABLE/DROP TABLE IF EXISTS/;  # Possible in Pg 9.2 or 9.3.
				s/DROP TABLE (.*);/DROP TABLE IF EXISTS $1 CASCADE;/;    # Workaround in Pg 9.1 for problems above.

				# Keep the restore completely quiet by suppressing SELECT output.
				# With this, we don't need the psql '-o /dev/null' option during a restore.
				s/(SELECT pg_catalog\.setval.*);/DO \$\$DECLARE i bigint; BEGIN $1 INTO i; END\$\$;/;
			    }
			    if ( not print TMP $_ ) {
				$got_errno = "$!";
				last;
			    }
			}
			if ( not close(TMP) && not $got_errno ) {
			    $got_errno = "$!";
			}
			close SQL;
			if ($got_errno) {
			    push @errors, "Error:  Cannot write to temporary dump file $tmpfile to add IF EXISTS clauses ($got_errno).";
			    unlink $tmpfile;
			}
			elsif ( not rename $tmpfile, $sqlfile ) {
			    push @errors, "Error:  Cannot rename temporary dump file $tmpfile to add IF EXISTS clauses ($!).";
			    unlink $tmpfile;
			}
		    }
		}
	    }
	}
	else {
	    push @errors, "Error:  unsupported DB type!  Unable to back up the $database database.";
	}
    }

    if ( not @errors ) {
	## Limit to what will fit in the database.
	$annotation = substr( $annotation, 0, 4095 );
	chomp $annotation;
	require MonarchFoundationREST;
	my %audit_entry = (
	    subsystem   => 'Monarch',
	    hostName    => $dbhost,
	    action      => 'BACKUP',
	    description => $annotation || 'Monarch backup completed successfully.',
	    username    => $user_acct || 'unknown user'
	);
	FoundationREST->create_audit_entries( undef, undef, [ \%audit_entry ] );
    }
    elsif ( !-l $full_backup_dir && -d _ ) {
	## Delete any remaining traces of the backup.
	StorProc->delete_one_backup( $backup_dir, $dt, 1 );
    }

    return "$full_backup_dir/", \@errors;
}

# Intended for internal use only; use synchronized_restore() instead.
sub restore(@) {
    my $backup_dir  = $_[1];
    my $backup_time = $_[2];
    my $user_acct   = $_[3];
    my $interactive = $_[4];
    my $skip_clean  = $_[5];
    my @errors      = ();

    if ( $backup_dir eq '' || $backup_dir =~ /\s/ ) {
	push @errors, "Improper backup base directory supplied.";
    }
    elsif ( not $backup_time =~ /^\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}$/ ) {
	push @errors, "Improper backup time supplied.";
    }
    elsif ( -l "$backup_dir/$backup_time" or !-d _ ) {
	push @errors, "Improper backup directory supplied.";
    }
    elsif ( defined($dbtype) && $dbtype eq 'postgresql' ) {
	my $sqlfile =
	    -f "$backup_dir/$backup_time/monarch-$backup_time.sql.tar" ? "$backup_dir/$backup_time/monarch-$backup_time.sql.tar"
	  : -f "$backup_dir/$backup_time/monarch-$backup_time.sql"     ? "$backup_dir/$backup_time/monarch-$backup_time.sql"
	  :                                                              undef;
	if ( not $sqlfile ) {
	    ( my $human_time = $backup_time ) =~ s/_(\d\d)-(\d\d)-/ $1:$2:/;
	    push @errors, "Error:  Cannot find the $human_time backup file!  Unable to restore the $database database.";
	}
	else {
	    my $pgrestore = $sqlfile =~ /\.tar$/ ? 'pg_restore' : 'psql';
	    my $postgres_restore =
	      ( -x "/usr/bin/$pgrestore" ) ? "/usr/bin/$pgrestore" : undef;
	    if ( not $postgres_restore ) {
		push @errors, "Error:  Cannot find $pgrestore!  Unable to restore the $database database.";
	    }
	    else {
		local %ENV = %ENV;
		delete $ENV{PGCLIENTENCODING};
		delete $ENV{PGDATABASE};
		delete $ENV{PGDATESTYLE};
		delete $ENV{PGGEQO};
		delete $ENV{PGHOSTADDR};
		delete $ENV{PGHOST};
		delete $ENV{PGLOCALEDIR};
		delete $ENV{PGOPTIONS};
		delete $ENV{PGPASSFILE};
		delete $ENV{PGPASSWORD};
		delete $ENV{PGPORT};
		delete $ENV{PGSERVICEFILE};
		delete $ENV{PGSERVICE};
		delete $ENV{PGSYSCONFDIR};
		delete $ENV{PGTZ};
		delete $ENV{PGUSER};
		$ENV{PGCONNECT_TIMEOUT} = 20;
		$ENV{PGREQUIREPEER}     = 'postgres';
		$ENV{SHELL}             = '/bin/false';
		$ENV{PATH}              = '/bin:/sbin:/usr/bin:/usr/sbin';

		# Error messages will be printed on STDERR, not STDOUT, and will be
		# emitted regardless of the setting (or not) of the -o option.
		my $psql_out    = $debug_restore     ? ''                      : '-o /dev/null';
		my $psql_quiet  = $debug_restore > 1 ? '--echo-queries'        : '--quiet --tuples-only';
		my $credentials = $interactive       ? "--username='postgres'" : "--username='$user' --no-password";

		## With pg_restore, --clean gets in the way of restoring a tarball if we try to run a single transaction
		## and/or exit on errors, because various "DROP object" commands without IF EXISTS clauses will fail
		## in a database which is empty or missing certain objects.  The --if-exists option in Pg 9.4 allows
		## control of this, but we're still using an earlier release.  Hence the need for explicit control
		## of whether --clean is applied.  With psql, we have edited the generated plain-format dump to drop
		## certain statements and to add IF EXISTS and CASCADE clauses to other statements, to make the dump
		## restorable whether or not the existing DB is empty.
		my $clean = $skip_clean ? '' : '--clean';

		my $restore_command =
		  $pgrestore eq 'pg_restore'
		  ? "$postgres_restore --host=$dbhost $credentials --single-transaction --exit-on-error $clean --dbname=$database '$sqlfile' 2>&1"
		  : "$postgres_restore --host=$dbhost $credentials --single-transaction $psql_quiet --no-psqlrc --variable=ON_ERROR_STOP= --dbname=$database --file='$sqlfile' $psql_out 2>&1";
		if ( $interactive ) {
		$ENV{PGPASSWORD} = $passwd;
        }
		my @results     = qx($restore_command);
		if ( $interactive ) {
		delete $ENV{PGPASSWORD};
        }
		my $wait_status = $?;
		push @errors, 'Error:  Got ' . wait_status_message($wait_status) . ' from restore command.' if $wait_status;
		push @errors, @results;

		# For now, instead of forcing an ANALYZE immediately after the restore, we simply allow the autovacuum
		# dawmon to analyze the tables based on its normal criteria.
	    }
	}
    }
    else {
	push @errors, "Restoring from a MySQL backup is not implemented.";
    }

    require MonarchFoundationREST;
    my %audit_entry = (
	subsystem   => 'Monarch',
	hostName    => $dbhost,
	action      => 'RESTORE',
	description => "Restore of Monarch $backup_time backup " . ( @errors ? "failed." : "completed successfully." ),
	username    => $user_acct || 'unknown user'
    );
    FoundationREST->create_audit_entries( undef, undef, [ \%audit_entry ] );

    return \@errors;
}

sub property_list() {
    my %property_list = ();
    ## GWMON-6632
    ## FIX LATER:  If we had access to the Nagios version here, we would retain backward compatibility by making this conditional:
    # my $parallelize_check = ( $nagios_ver =~ /^[12]\.x$/ ) ? ',parallelize_check' : '';
    my $parallelize_check = '';
    $property_list{'host_templates'} =
        "name,checks_enabled,active_checks_enabled,passive_checks_enabled,check_command,command_line,check_period,"
      . "check_interval,retry_interval,max_check_attempts,check_freshness,freshness_threshold,obsess_over_host,"
      . "flap_detection_enabled,low_flap_threshold,high_flap_threshold,event_handler_enabled,event_handler,stalking_options,"
      . "process_perf_data,notifications_enabled,notification_options,notification_period,notification_interval,"
      . "contactgroup,retain_status_information,retain_nonstatus_information,custom_object_variables";

    # FIX MINOR:  Why isn't contactgroup part of this list?
    $property_list{'host_overrides'} =
        "checks_enabled,active_checks_enabled,passive_checks_enabled,check_command,command_line,check_period,"
      . "check_interval,retry_interval,max_check_attempts,check_freshness,freshness_threshold,obsess_over_host,"
      . "flap_detection_enabled,low_flap_threshold,high_flap_threshold,event_handler_enabled,event_handler,stalking_options,"
      . "process_perf_data,notifications_enabled,notification_options,notification_period,notification_interval,"
      . "retain_status_information,retain_nonstatus_information";

    $property_list{'hosts'} =
        "name,alias,address,notes,template,parents,checks_enabled,check_command,command_line,max_check_attempts,"
      . "flap_detection_enabled,event_handler_enabled,event_handler,stalking_options,process_perf_data,"
      . "notifications_enabled,notification_options,notification_period,notification_interval,"
      . "retain_status_information,retain_nonstatus_information";

    $property_list{'host_dependencies'} = "dependent_host,master_host,inherits_parent,execution_failure_criteria,notification_failure_criteria";

    $property_list{'extended_host_info_templates'} =
      "name,notes,notes_url,action_url,icon_image,icon_image_alt,vrml_image,statusmap_image,2d_coords,3d_coords";
    $property_list{'extended_host_info'}              = "host_name,notes,notes_url,action_url,template,2d_coords,3d_coords";
    $property_list{'extended_service_info_templates'} = "name,notes,notes_url,action_url,icon_image,icon_image_alt";
    $property_list{'extended_service_info'}           = "template,service_description,host_name,notes,notes_url,action_url";

    $property_list{'hostgroups'} = "name,alias,notes,members,contactgroup,host_escalation_id,service_escalation_id";

    $property_list{'service_templates'} =
        "name,template,active_checks_enabled,passive_checks_enabled,check_command,command_line,check_period,"
      . "normal_check_interval,retry_check_interval,max_check_attempts$parallelize_check,check_freshness,freshness_threshold,"
      . "obsess_over_service,flap_detection_enabled,low_flap_threshold,high_flap_threshold,event_handler_enabled,event_handler,"
      . "is_volatile,stalking_options,process_perf_data,notifications_enabled,notification_options,notification_period,notification_interval,"
      . "contactgroup,retain_status_information,retain_nonstatus_information";

    # FIX MINOR:  Why isn't contactgroup part of this list?
    $property_list{'service_overrides'} =
        "active_checks_enabled,passive_checks_enabled,check_period,normal_check_interval,retry_check_interval,"
      . "max_check_attempts$parallelize_check,check_freshness,freshness_threshold,obsess_over_service,"
      . "flap_detection_enabled,low_flap_threshold,high_flap_threshold,event_handler_enabled,event_handler,"
      . "is_volatile,stalking_options,process_perf_data,notifications_enabled,notification_options,notification_period,notification_interval,"
      . "etain_status_information,retain_nonstatus_information";

    $property_list{'services'} =
        "name,template,host_name,notes,active_checks_enabled,passive_checks_enabled,check_command,check_period,"
      . "normal_check_interval,retry_check_interval,max_check_attempts$parallelize_check,check_freshness,freshness_threshold,"
      . "obsess_over_service,flap_detection_enabled,low_flap_threshold,high_flap_threshold,event_handler_enabled,event_handler,"
      . "is_volatile,stalking_options,process_perf_data,notifications_enabled,notification_options,notification_period,notification_interval,"
      . "contactgroup,retain_status_information,retain_nonstatus_information";

    $property_list{'service_dependency_templates'} = "name,service_name,execution_failure_criteria,notification_failure_criteria";
    $property_list{'service_dependency'}           = "service_name,host_name,depend_on_host,template";
    $property_list{'contact_templates'} =
	"name,host_notification_period,host_notification_options,host_notification_commands,"
      . "service_notification_period,service_notification_options,service_notification_commands,custom_object_variables";
    $property_list{'contacts'}      = "name,template,alias,email,pager";
    $property_list{'contactgroups'} = "name,alias,contact";
    $property_list{'hostgroup_escalation_templates'} =
      "name,contactgroup,type,first_notification,last_notification,notification_interval,escalation_period,escalation_options";
    $property_list{'host_escalation_templates'} =
      "name,type,first_notification,last_notification,notification_interval,escalation_period,escalation_options";
    $property_list{'service_escalation_templates'} =
      "name,type,first_notification,last_notification,notification_interval,escalation_period,escalation_options";

    # Day rules and time period exclusions are not reflected in this list.
    $property_list{'time_periods'} = "name,alias";
    $property_list{'commands'}     = "name,type,command_line";
    $property_list{'escalation_templates'} =
      "name,first_notification,last_notification,notification_interval,escalation_period,escalation_options";
    $property_list{'servicegroups'} = "name,alias,notes,escalation_id";

    $property_list{'profiles_host'} =
      "name,description,host_template_id,host_extinfo_id,host_escalation_id,service_escalation_id,serviceprofile_id";
    $property_list{'profiles_service'} = "name,description";
    $property_list{'service_names'}    = "name,description,template,check_command,command_line,dependency,escalation,extinfo";
    $property_list{'servicename_overrides'} =
        "active_checks_enabled,passive_checks_enabled,check_period,normal_check_interval,retry_check_interval,"
      . "max_check_attempts$parallelize_check,check_freshness,freshness_threshold,obsess_over_service,"
      . "flap_detection_enabled,low_flap_threshold,high_flap_threshold,event_handler_enabled,event_handler,"
      . "is_volatile,stalking_options,process_perf_data,notifications_enabled,notification_options,notification_period,notification_interval,"
      . "retain_status_information,retain_nonstatus_information";

    return %property_list;
}

sub db_values() {
    my %db_values = ();

    # Day rules and time period exclusions are not reflected in this list.
    $db_values{'time_periods'}      = "name,alias,comment";
    $db_values{'commands'}          = "name,type,data,comment";
    $db_values{'contactgroups'}     = "name,alias,comment";
    $db_values{'contact_templates'} = "name,host_notification_period,service_notification_period,data,comment";
    $db_values{'contacts'}          = "name,alias,email,pager,contacttemplate_id,status,comment";
    $db_values{'hosts'} =
      "name,alias,address,os,hosttemplate_id,hostextinfo_id,hostprofile_id,host_escalation_id,service_escalation_id,status,comment,notes";
    $db_values{'host_overrides'}    = "check_period,notification_period,check_command,event_handler,data";
    $db_values{'host_templates'}    = "name,check_period,notification_period,check_command,event_handler,data,comment";
    $db_values{'hostgroups'}        = "name,alias,hostprofile_id,host_escalation_id,service_escalation_id,status,comment,notes";
    $db_values{'service_templates'} = "name,parent_id,check_period,notification_period,check_command,command_line,event_handler,data,comment";
    $db_values{'service_overrides'} = "check_period,notification_period,event_handler,data";
    $db_values{'services'}          = "name,host_name,template,data,comment,notes";
    $db_values{'extended_host_info_templates'}    = "name,data,script,comment";
    $db_values{'extended_info_coords'}            = "data";
    $db_values{'extended_service_info_templates'} = "name,data,script,comment";
    $db_values{'host_dependencies'}               = "host_id,parent_id,data,comment";
    $db_values{'service_dependency'}              = "servicename_id,host_name,depend_on_host,template,comment";
    $db_values{'service_dependency_templates'}    = "name,servicename_id,data,comment";
    $db_values{'stage_hosts'}                     = "name,userid,type,status,alias,address,os,info";
    ## FIX MAJOR:  these values do not comport with the column names and ordering in the stage_host_services table
    $db_values{'stage_host_services'}             = "name,userid,type,status,host,info";
    $db_values{'escalation_templates'}            = "name,type,data,comment,escalation_period";
    $db_values{'profiles_host'}         = "name,description,host_template_id,host_extinfo_id,host_escalation_id,service_escalation_id";
    $db_values{'profiles_service'}      = "name,description";
    $db_values{'service_names'}         = "name,description,template,check_command,command_line,escalation,extinfo,data";
    $db_values{'servicename_overrides'} = "check_period,notification_period,event_handler,data";
    return %db_values;
}

sub contactgroup_table_by_object(@) {
    my $obj                = $_[1];
    my %cg_table_by_object = (
	'hosts'             => 'contactgroup_host',
	'monarch_group'     => 'contactgroup_group',
	'services'          => 'contactgroup_service',
	'host_templates'    => 'contactgroup_host_template',
	'service_templates' => 'contactgroup_service_template',
	'host_profiles'     => 'contactgroup_host_profile',
	'service_names'     => 'contactgroup_service_name',
	'hostgroups'        => 'contactgroup_hostgroup',
    );
    return $cg_table_by_object{$obj};
}

sub get_obj_id() {
    my %obj_id = (
	'hosts'                           => 'host_id',
	'hostgroups'                      => 'hostgroup_id',
	'host_templates'                  => 'hosttemplate_id',
	'host_dependencies'               => 'host_id',
	'host_escalation_templates'       => 'template_id',
	'hostgroup_escalation_templates'  => 'template_id',
	'extended_host_info_templates'    => 'hostextinfo_id',
	'services'                        => 'service_id',
	'servicegroups'                   => 'servicegroup_id',
	'service_templates'               => 'servicetemplate_id',
	'service_dependency'              => 'id',
	'service_dependency_templates'    => 'id',
	'service_escalation_templates'    => 'template_id',
	'extended_service_info_templates' => 'serviceextinfo_id',
	'commands'                        => 'command_id',
	'time_periods'                    => 'timeperiod_id',
	'contacts'                        => 'contact_id',
	'contactgroups'                   => 'contactgroup_id',
	'contact_templates'               => 'contacttemplate_id',
	'escalation_templates'            => 'template_id',
	'escalation_trees'                => 'tree_id',
	'contactgroup_host'               => 'host_id',
	'contactgroup_group'              => 'group_id',
	'contactgroup_service'            => 'service_id',
	'contactgroup_host_template'      => 'hosttemplate_id',
	'contactgroup_service_template'   => 'servicetemplate_id',
	'contactgroup_host_profile'       => 'hostprofile_id',
	'contactgroup_service_name'       => 'servicename_id',
	'contactgroup_hostgroup'          => 'hostgroup_id'
    );
    return %obj_id;
}

1;

