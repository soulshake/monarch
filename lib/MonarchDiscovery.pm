# MonArch - Groundwork Monitor Architect
# MonarchDiscovery.pm
#
############################################################################
# Release 3.3
# August 2010
############################################################################
#
# Copyright 2007, 2008, 2009, 2010 GroundWork Open Source, Inc. (GroundWork)
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

# NOTE:  This module uses the inside-out object approach outlined in Damian
# Conway's Perl Best Practices, Chapters 15 and 16 (O'Reilly Media).
# See also:  http://perltraining.com.au/tips/2006-03-31.html

# tests in test_md.t

package Discovery;

use strict;
use Carp;
use Class::Std::Utils;
use vars qw( $VERSION );

$VERSION = 0.10;

{
    my %description_of;
    my %schema_name_of;

    my %method_of;
    my %edit_method_of;
    my %method_description_of;

    my %enable_traceroute_of;
    my %traceroute_command_of;
    my %traceroute_timeout_of;
    my %traceroute_max_hops_of;

    my %type_of;
    my %auto_of;
    my %filter_of;

    my %flags_of;

    sub new {
	my ($class) = @_;

	#my ($class, $arg_ref) = @_; # doesn't take any arguments at the moment

	my $new_object = bless \do { my $anon_scalar }, $class;

	$description_of{ ident $new_object }         = '';
	$schema_name_of{ ident $new_object }         = '';
	$method_of{ ident $new_object }              = '';
	$method_description_of{ ident $new_object }  = '';
	$enable_traceroute_of{ ident $new_object }   = '';
	$traceroute_command_of{ ident $new_object }  = '';
	$traceroute_max_hops_of{ ident $new_object } = '';
	$traceroute_timeout_of{ ident $new_object }  = '';
	$filter_of{ ident $new_object }              = '';
	$type_of{ ident $new_object }                = '';
	$auto_of{ ident $new_object }                = '';

	$flags_of{ ident $new_object } = {
	    save_method   => 0,
	    save_group    => 0,
	    delete_filter => 0,
	    delete_group  => 0,
	    delete_method => 0,
	    remove_port   => 0,
	    rename        => 0,
	};

	return $new_object;
    }

    #
    # getters / setters
    #

    sub get_flag {
	my ( $self, $flag ) = @_;

	croak q{Must specify flag} unless ( @_ == 2 );
	croak "error: flag [$flag] not defined in ", ref $self, " object"
	  unless ( ( defined($flag) ) && ( defined( $flags_of{ ident $self }{$flag} ) ) );

	return $flags_of{ ident $self }{$flag};
    }

    sub set_flag {
	my ( $self, $flag, $new_value ) = @_;

	croak q{Must specify both flag and value} unless ( @_ == 3 );
	croak "error: no such flag [$flag] in ", ref $self, " object"
	  unless ( defined( $flags_of{ ident $self }{$flag} ) );

	$flags_of{ ident $self }{$flag} = $new_value;

	return;
    }

    # methods generated by make-method.pl script
    sub get_description {
	my ($self) = @_;
	return $description_of{ ident $self };
    }

    sub set_description {
	my ( $self, $new_description ) = @_;
	$description_of{ ident $self } = $new_description;
	return;
    }

    sub get_schema_name {
	my ($self) = @_;
	return $schema_name_of{ ident $self };
    }

    sub set_schema_name {
	my ( $self, $new_schema_name ) = @_;
	$schema_name_of{ ident $self } = $new_schema_name;
	return;
    }

    sub get_method {
	my ($self) = @_;
	return $method_of{ ident $self };
    }

    sub set_method {
	my ( $self, $new_method ) = @_;
	$method_of{ ident $self } = $new_method;
	return;
    }

    sub get_edit_method {
	my ($self) = @_;
	return $edit_method_of{ ident $self };
    }

    sub set_edit_method {
	my ( $self, $new_edit_method ) = @_;
	$edit_method_of{ ident $self } = $new_edit_method;
	return;
    }

    sub get_method_description {
	my ($self) = @_;
	return $method_description_of{ ident $self };
    }

    sub set_method_description {
	my ( $self, $new_method_description ) = @_;
	$method_description_of{ ident $self } = $new_method_description;
	return;
    }

    sub get_enable_traceroute {
	my ($self) = @_;
	return $enable_traceroute_of{ ident $self };
    }

    sub set_enable_traceroute {
	my ( $self, $new_enable_traceroute ) = @_;
	$enable_traceroute_of{ ident $self } = $new_enable_traceroute;
	return;
    }

    sub get_traceroute_command {
	my ($self) = @_;
	return $traceroute_command_of{ ident $self };
    }

    sub set_traceroute_command {
	my ( $self, $new_traceroute_command ) = @_;
	$traceroute_command_of{ ident $self } = $new_traceroute_command;
	return;
    }

    sub get_traceroute_timeout {
	my ($self) = @_;
	return $traceroute_timeout_of{ ident $self };
    }

    sub set_traceroute_timeout {
	my ( $self, $new_traceroute_timeout ) = @_;
	$traceroute_timeout_of{ ident $self } = $new_traceroute_timeout;
	return;
    }

    sub get_traceroute_max_hops {
	my ($self) = @_;
	return $traceroute_max_hops_of{ ident $self };
    }

    sub set_traceroute_max_hops {
	my ( $self, $new_traceroute_max_hops ) = @_;
	$traceroute_max_hops_of{ ident $self } = $new_traceroute_max_hops;
	return;
    }

    sub get_type {
	my ($self) = @_;
	return $type_of{ ident $self };
    }

    sub set_type {
	my ( $self, $new_type ) = @_;
	$type_of{ ident $self } = $new_type;
	return;
    }

    sub get_auto {
	my ($self) = @_;
	return $auto_of{ ident $self };
    }

    sub set_auto {
	my ( $self, $new_auto ) = @_;
	$auto_of{ ident $self } = $new_auto;
	return;
    }

    sub get_filter {
	my ($self) = @_;
	return $filter_of{ ident $self };
    }

    sub set_filter {
	my ( $self, $new_filter ) = @_;
	$filter_of{ ident $self } = $new_filter;
	return;
    }

    #
    # cleanup when we're done. with inside-out objects, these
    # will not be cleaned up automatically unless we do this.
    #
    sub DESTROY {
	my ($self) = @_;

	delete $description_of{ ident $self };
	delete $schema_name_of{ ident $self };
	delete $method_of{ ident $self };
	delete $edit_method_of{ ident $self };
	delete $method_description_of{ ident $self };
	delete $enable_traceroute_of{ ident $self };
	delete $traceroute_command_of{ ident $self };
	delete $traceroute_max_hops_of{ ident $self };
	delete $traceroute_timeout_of{ ident $self };
	delete $filter_of{ ident $self };
	delete $type_of{ ident $self };
	delete $auto_of{ ident $self };
	delete $flags_of{ ident $self };

	return;
    }

}

1;

