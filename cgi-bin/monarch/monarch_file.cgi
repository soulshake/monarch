#!/usr/bin/perl --
# MonArch - Groundwork Monitor Architect
# monarch_file.cgi
#
############################################################################
# Release 4.5
# September 2016
############################################################################
#
# Original author: Glenn Herteg
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

use strict;
use CGI;
use Cwd 'realpath';

sub abs_filepath {
    my $rel_path   = $_[0];
    my $rel_prefix = $_[1];
    my $abs_prefix = $_[2];
    my $abs_path   = undef;

    if ( $rel_path =~ m@^$rel_prefix@ ) {
	$abs_path = realpath( $abs_prefix . $rel_path );

	# Validate that the absolute path starts with the same prefix as we just prepended, to
	# avoid symlink or parent-directory references sidestepping our security precautions.
	if ( defined($abs_path) && $abs_path !~ m@^$abs_prefix@ ) {
	    ## This is the only symlink jump we will tolerate in the pathname.
	    my $gwlink = readlink '/usr/local/groundwork';
	    if ( defined($gwlink) ) {
		if ($gwlink !~ m{^/}) {
		    $gwlink = '/usr/local/groundwork/' . $gwlink;
		}
		$gwlink = realpath($gwlink);
	    }
	    if ( defined($gwlink) ) {
		$abs_prefix =~ s{^/usr/local/groundwork}{$gwlink};
		$abs_path = realpath( $abs_prefix . $rel_path );
		if ( defined($abs_path) && $abs_path !~ m@^$abs_prefix@ ) {
		    $abs_path = undef;
		}
	    }
	    else {
		$abs_path = undef;
	    }
	}
    }

    return $abs_path;
}

sub show_file {
    my $query = new CGI();
    my $absolute_path;
    my $relative_path = $query->param('file');

    # Apply security constraints before we spill just anything out to the user.
    if (   $relative_path !~ m@^/monarch/download/@
	&& $relative_path !~ m@^/monarch/workspace/@
	&& $relative_path !~ m@^/profiles/@ )
    {
	print "Content-type: text/plain \n\n";
	print "Illegal file path.";
	return;
    }

    $absolute_path =
	 abs_filepath( $relative_path, '/monarch/download/',  '/usr/local/groundwork/monarch/htdocs' )
      || abs_filepath( $relative_path, '/monarch/workspace/', '/usr/local/groundwork' )
      || abs_filepath( $relative_path, '/profiles/',          '/usr/local/groundwork/monarch' );

    if ( !defined($absolute_path) || !-f $absolute_path || !-r $absolute_path ) {
	print "Content-type: text/plain \n\n";
	print "Error: \"$relative_path\" cannot be accessed.";
	return;
    }
    if (0) {
	## simple form:  let somebody else do the heavy lifting
	print "Content-type: text/plain \n\n";
	print `/bin/cat -n $absolute_path`;
    }
    else {
	## fancy form:  highlight the line numbers to separate them from the file content
	if ( !open( FILE, '<', $absolute_path ) ) {
	    print "Content-type: text/plain \n\n";
	    print "\"$relative_path\": $!";
	    return;
	}
	( my $file = $absolute_path ) =~ s@.*/@@;
	print "Content-type: text/html \n\n";
	print "<html><head><title>$file</title></head><body><pre style='white-space: pre-wrap; white-space: -moz-pre-wrap !important; white-space: -pre-wrap; white-space: -o-pre-wrap; word-wrap: break-word; overflow-wrap: break-word; word-break: break-all; -ms-word-break: break-all; line-break: loose;'>\n";
	my $line = 0;
	while (<FILE>) {
	    ++$line;
	    printf( qq(<a name="line%d" style="color: #DD0000;">%6d  </a>), $line, $line );
	    s/&/&amp;/g;
	    s/</&lt;/g;
	    s/>/&gt;/g;

	    # FIX THIS:  possibly also expand tabs here, too, to support browsers that don't do so properly
	    print $_;
	}
	print "</pre></body></html>\n";
	close FILE;
    }
}

&show_file;
