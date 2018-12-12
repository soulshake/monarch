# MonArch - Groundwork Monitor Architect
# MonarchDeploy.pm
#
############################################################################
# Release 3.0
# January 2009
############################################################################
#
# Author: Scott Parris
#
# Copyright 2007, 2008, 2009 GroundWork Open Source, Inc. (GroundWork)
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
package Deploy;

sub deploy_sample(@) {
    my $group = $_[1];
    my $build_folder = $_[2];
    my $target_etc = $_[3];
    my $monarch_home = $_[4];
    my @results = ();

    # ============================
    # Enter your custom code here.
    # ============================

    return @results;
}

############################################################################
# Default Example: This sample assumes you have ssh keys published on the target hosts and can perform scp and ssh without password prompts
#
sub deploy(@) {
    my $group = $_[1]; # group name is dns resolved host name
    my $build_folder = $_[2]; # defined in groups detail
    my $target_etc = $_[3]; # defined in groups detail
    my $monarch_home = $_[4]; # set during installation
    my @results = (); # used to gather and return messages for display in browser
    my @files = ();
    my $debug = 0;
    # Opens nagios.cfg to find files to deploy
    if (! open(FILE, '<', "$build_folder/nagios.cfg")) {
	push @results, "error: cannot open $build_folder/nagios.cfg to read ($!)";
    } else {
	while (my $line = <FILE>) {
	    if ($line =~ /^\s*resource_file\s*=\s*(\S+)$/) {
		push @results, "/usr/bin/scp $build_folder/resource.cfg nagios\@$group:$1" if $debug;
		qx(scp $build_folder/resource.cfg nagios\@$group:$1 2>&1);
		push @results, "$!" if $!;
	    } elsif ($line =~ /^\s*cfg_file\s*=\s*(.*\.cfg)$/) {
		my $file = $1;
		$file =~ s/$target_etc\///;
		push @files, $file;
	    }
	}
	close(FILE);
    }
    push @files, "nagios.cfg";
    push @files, "cgi.cfg";
    foreach my $file (@files) {
	push @results, "<br>scp $build_folder/$file nagios\@$group:$target_etc/$file<br>" if $debug;
	qx(scp $build_folder/$file nagios\@$group:$target_etc/$file 2>&1);
	push @results, "$!" if $!;
    }
    # nagios_reload has been deployed to the target machine with the setuid bit (chmod 4750 nagios_reload)
    push @results, "ssh nagios\@$group /usr/local/groundwork/core/monarch/bin/nagios_reload" if $debug;
    my $res = qx(ssh nagios\@$group /usr/local/groundwork/core/monarch/bin/nagios_reload 2>&1) || push @results, "$!";
    $res =~ s/\n/<br>/;
    push @results, $res;
    return @results;
}

############################################################################
# This sub will commit the parent node and could be called from the main deploy sub
#
sub commit_parent_sample() {
    use MonarchStorProc;
    my @results = ();
    my %where = ('type' => 'config');
    my %objects = StorProc->fetch_list_hash_array('setup',\%where);
    my $user_acct = $ENV{'REMOTE_USER'};
    my $nagios_ver = $objects{'nagios_version'}[2];
    my $nagios_etc = $objects{'nagios_etc'}[2];
    my $monarch_home = $objects{'monarch_home'}[2];
    my ($files, $errors) = Files->build_files($user_acct,'','','',$nagios_ver,$nagios_etc,$nagios_etc,'');
    my @errors = @{$errors};
    my @files = @{$files};
    unless (@errors) {
	my @commit = StorProc->commit($monarch_home);
	push (@results, @commit);
    }
    return @results;
}

1;
