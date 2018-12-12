# Monarch - Groundwork Monitor Architect
# MonarchHashDelta.pm
#
############################################################################
# Release 4.5
# September 2016
############################################################################
#
# Copyright 2008-2016 GroundWork Open Source, Inc. (GroundWork)
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
use warnings;

package MonarchHashDelta;

use Moose;
use Data::Dumper;

has 'source' => ( is => 'rw', isa => 'HashRef', default => undef );
has 'target' => ( is => 'rw', isa => 'HashRef', default => undef );

# TODO: upcoming changes:
# 1. Get basic sync working properly
# 2. Add syncing of servicegroups. These will be captured as (?):
#    $delta{'alter'}{'servicegroup'}{$sg}{'service'}{$host}{$service} = 1;
# 3. Add syncing of hosts' parents
# 4. Add syncing of alias as description for hosts, hostgroups, servicegroups

sub delta {
    my $self = shift;
    my %delta = ( 'add' => {}, 'delete' => {}, 'alter' => {}, 'exists' => {} );


    foreach my $type (qw(host hostgroup service)) { # TODO: servicegroup

        # start with the canonical source, Monarch data
        if ( ref( $self->source()->{$type} ) eq 'HASH' ) {

            foreach my $object ( keys %{ $self->source()->{$type} } ) {
                if ( ref( $self->source()->{$type}{$object} ) eq 'HASH' ) {

                    # it's a hash ref; drill down
                    my @to_add = ();
                    foreach
                      my $item ( keys %{ $self->source()->{$type}{$object} } )
                    {

                        $delta{exists}{$type}{$object}{$item} =
                          $self->source()->{$type}{$object}{$item};

                        # if it isn't already in the target, add it
                        if ( !defined( $self->target()->{$type}{$object} ) ) {
                            push( @to_add, $item );
                        }
                        elsif (
                            !deep_match(
                                $self->target()->{$type}{$object},
                                $self->source()->{$type}{$object}
                            )
                          )
                        {
                            $delta{'add'}{$type}{$object}{$item} =
                              $self->source()->{$type}{$object}{$item}
                              unless ( $type eq 'host' && $item eq 'address' );
                        }
                    }
                    foreach my $item (@to_add) {
                        $delta{'add'}{$type}{$object}{$item} =
                          $self->source()->{$type}{$object}{$item};
                    }
                }
                else {
                    $delta{exists}{$type}{$object} =
                      $self->source()->{$type}{$object}
                      if ( defined( $self->source()->{$type}{$object} ) );
                    if ( !defined( $self->target()->{$type}{$object} )
                        || $self->target()->{$type}{$object} ne
                        $self->source()->{$type}{$object} )
                    {
                        $delta{'add'}{$type}{$object} =
                          $self->source()->{$type}{$object};
                    }
                }
            }
        }
        else {

            # still source; doing a single value, not a hash
            # we don't handle arrays for now.
            $delta{exists}{$type} = $self->source()->{$type}
              if ( defined( $self->source()->{$type} ) );
            if ( !defined( $self->target()->{$type} ) ) {
                $delta{'add'}{$type} = $self->source()->{$type};
            }
            elsif ( $self->target()->{$type} ne $self->source()->{$type}
                && ( $type ne 'host' ) )
            {
                $delta{'add'}{$type} = $self->source()->{$type};
            }
        }

        # now inspect the data of the target, the last state of Foundation
        if ( ref( $self->target()->{$type} ) eq 'HASH' ) {
            foreach my $object ( keys %{ $self->target()->{$type} } ) {
                if ( ref( $self->target()->{$type}{$object} ) eq 'HASH' ) {

                    # it's a hash ref; drill down
                    foreach
                      my $item ( keys %{ $self->target()->{$type}{$object} } )
                    {
                        $delta{delete}{$type}{$object}{$item} =
                          $self->target()->{$type}{$object}{$item}
                          unless (
                            defined( $self->source()->{$type}{$object}{$item} )
                          );
                    }
                }
                else {
                    $delta{delete}{$type}{$object} =
                      $self->target()->{$type}{$object}
                      unless ( defined( $self->source()->{$type}{$object} ) );
                }
            }
        }
        else {
            $delta{delete}{$type} = $self->target()->{$type}
              unless ( defined( $self->source()->{$type} ) );
        }
    }


    #
    # create the 'alter' directives
    #
    my %source_hosts_by_hostgroup = %{$self->source()->{'hostgroup'}};
    foreach my $hostgroup (keys %source_hosts_by_hostgroup) {
	next if (defined($delta{'delete'}{'hostgroup'}{$hostgroup}));
	my $changed = 0;
	my @hosts = keys %{$source_hosts_by_hostgroup{$hostgroup}};
	foreach my $host (@hosts) {
	    $changed = 1 if ( defined($delta{'delete'}{'host'}{$host})
			      ||
			      defined($delta{'add'}{'host'}{$host}) );
	}
	if ($changed) {
	  foreach my $host (keys %{$source_hosts_by_hostgroup{$hostgroup}}) {
	    $delta{'alter'}{'hostgroup'}{$hostgroup}{'members'}{$host} = 1;
	  }
	}
    }

    return \%delta;

}

sub deep_match {
    my $href1 = shift;
    my $href2 = shift;
    return 0 if ( !defined($href1) );
    return 0 if ( !defined($href2) );
    my %hash1 = %$href1;
    my %hash2 = %$href2;

    foreach my $key ( keys %hash1 ) {
        if ( ref( $hash1{$key} ) eq 'HASH' ) {
            return 0 unless ( deep_match( $hash1{$key}, $hash2{$key} ) );
        }
        else {

           # handle values of 'undef' (not to be confused with undefined values)
            if ( !defined( $hash1{$key} ) || !defined( $hash2{$key} ) ) {
                return 0
                  if ( !defined( $hash1{$key} ) xor !defined( $hash2{$key} ) );
            }
            else {
                return 0 if ( $hash1{$key} ne $hash2{$key} );
            }
        }
    }
    foreach my $key ( keys %hash2 ) {
        if ( ref( $hash2{$key} ) eq 'HASH' ) {
            return 0 unless ( deep_match( $hash2{$key}, $hash1{$key} ) );
        }
        else {

           # handle values of 'undef' (not to be confused with undefined values)
            if ( !defined( $hash1{$key} ) || !defined( $hash2{$key} ) ) {
                return 0
                  if ( !defined( $hash1{$key} ) xor !defined( $hash2{$key} ) );
            }
            else {
                return 0 if ( $hash2{$key} ne $hash1{$key} );
            }
        }
    }
    return 1;
}

sub debug {
    my $str  = shift;
    my $file = "/tmp/debug.log";
    open( DEBUG, '>>', $file ) or die "error opening $file ($!)";
    print DEBUG "$str\n";
    close(DEBUG);
}

1;

