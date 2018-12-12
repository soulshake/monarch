#!/usr/local/groundwork/perl/bin/perl
## @file
# Implements a xml helper class used for some properties settings by monarch
# @brief
# xml helper for monarch
# @author
# Holger Mueller
# @version
# \$Id: gwxml.pm 40 2010-11-23 23:15:31Z gherteg $
#
# Copyright (C) 2008-2009
# Holger Mueller <holger.mueller@dass-it.de> dass IT GmbH
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the
#    Free Software Foundation, Inc.
#    59 Temple Place, Suite 330
#    Boston, MA 02111-1307 USA
#

BEGIN {
    unshift @INC, '/usr/local/groundwork/core/monarch/lib';
}

use strict;

## @class
# This class helps to produce proper xml strings, which GroundWork likes to store in its MySQL Database for some configuration items.
## @brief xml helper class
package gwxml;

## @cmethod object new
# The constructor, creates header and footer
sub new {
    my $invocant = shift;
    my $class = ref($invocant) || $invocant;

    my $self = { header => '<?xml version="1.0" encoding="iso-8859-1" ?> <data> ', footer => ' </data> ', content => [], };
    bless( $self, $class );
    return $self;
}

## @method
# Adds a property to the xml
# @param name Property name
# @param value Property Value
sub add_prop {
    my $self = shift;
    my ( $name, $value ) = @_;

    push @{ $self->{'content'} }, [ $name, $value ];
}

## @method
# Returns a string containing all given properties as a xml string
# @return a string wiht xml data.
sub toString {
    my $self = shift;

    my $str = $self->{'header'};

    foreach my $kv ( @{ $self->{'content'} } ) {
	$str .= ' <prop name="' . $kv->[0] . '">';
	$str .= '<![CDATA[' . $kv->[1] . ']]>';
	$str .= ' </prop> ';
    }
    $str .= $self->{'footer'};

    return $str;
}

1;
