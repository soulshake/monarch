# Monarch - Groundwork Monitor Architect
# MonarchFoundationDelta.pm
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

use lib qq(/usr/local/groundwork/monarch/lib);
use warnings;

package MonarchFoundationDelta;

use Moose;
use MonarchHashDelta;
use CollageQuery;
use MonarchStorProc;

# the current group name, if any
has 'group' => ( is => 'rw', isa => 'Str' );

# the state of the monarch database (source of the sync)
has 'monarch' => ( is => 'rw', isa => 'HashRef' );

# the state of the foundation database
has 'foundation' => ( is => 'rw', isa => 'HashRef' );

# the difference between the states of monarch and foundation
has 'delta' => ( is => 'rw', isa => 'HashRef' );

# services that can be deleted because they have instances
has 'doomed_services' => ( is => 'rw', isa => 'HashRef' );


sub get_sync_delta {
    my $self  = shift;
    my $group = shift;

    StorProc->dbconnect();

    if ( defined($group) ) {
        $self->group($group);
    }

    update_monarch_state($self);
    update_foundation_state($self);
    update_delta($self);

    StorProc->dbdisconnect();

    return $self->delta();
}

sub update_delta {
    my $self  = shift;
    my $delta = $self->delta();
    my $md    = MonarchHashDelta->new(
        {
            'source' => $self->monarch(),
            'target' => $self->foundation()
        }
    );
    $self->delta( $md->delta() );
}

#
# not yet used
#
sub get_sync_xml {
    my $self  = shift;
    my $delta = $self->delta();

    my $xml = '<xml/>';
    return $xml;
}

#
# update the monarch state data structure. this is the source for the sync.
#
sub update_monarch_state {
    my $self     = shift;
    my $host_ref = {};      # hosts
    my $serv_ref = {};      # services
    my $hg_ref   = {};      # hostgroups
    my $hh_ref   = {};      # host-hostgroup mapping


    # Get hosts. For group sync, get hosts that directly belong to the group
    $host_ref = get_direct_monarch_hosts($self);


    # Get hostgroups. For group sync, get hostgroups directly put in group
    $hg_ref = get_direct_monarch_hostgroups($self);


    # Update $host_ref with all the hosts included in the direct hostgroups
    get_hosts_in_monarch_hostgroups( $hg_ref, $host_ref, $hh_ref );


    # Update $hg_ref with all hostgroups to which any of our hosts belong
    get_implicit_monarch_hostgroups( $self, $host_ref, $hg_ref, $hh_ref );


    # Get all services for all hosts
    my ( $serv_by_host, $serv_with_inst_by_host ) =
      get_monarch_service_state($host_ref);


    # Consolidate all the state we've gathered
    my $state = {};
    foreach my $host ( keys %$host_ref ) {
        $state->{'host'}{$host}{'address'} =
          StorProc->fetch_host_address($host);
    }
    foreach my $hostgroup ( keys %$hg_ref ) {
        $state->{'hostgroup'}{$hostgroup} = {};
    }
    foreach my $hostgroup ( keys %$hh_ref ) {
        debug("doing monarch hostgroup [$hostgroup]");
        foreach my $host ( keys %{ $hh_ref->{$hostgroup} } ) {
            debug("doing monarch host [$host]");
            $state->{'hostgroup'}{$hostgroup}{$host} = 1;
        }
    }
    foreach my $host ( keys %$serv_by_host ) {
        debug("doing monarch host [$host]");
        foreach my $service ( keys %{ $serv_by_host->{$host} } ) {
            debug("doing monarch service [$service] for host [$host]");
            $state->{'service'}{$host}{$service} = 1;
        }
    }


    # Nuke any services that can be deleted because they have instances
    $self->doomed_services($serv_with_inst_by_host);


	# Update the monarch member data variable to hold the state
    $self->monarch($state);

}

#
# get hosts. for group sync, get hosts that directly belong to the group
#
sub get_direct_monarch_hosts {
    my $self    = shift;
    my %m_hosts = ();

    if ( defined( $self->group() ) ) {

        # special treatment if using Monarch groups (for
        # parent/child setups). Monarch groups are distinct
        # from hostgroups and other Nagios groups

        my %groups     = ();
        my $group      = $self->group();
        my %where      = ( 'name' => $group );
        my %group_info = StorProc->fetch_one_where( 'monarch_groups', \%where );
        %groups = StorProc->get_groups( $group_info{'group_id'}, \%groups );
        my @hosts = ();
        @hosts = split( ',', $groups{$group}{'hosts'} )
          if ( defined( $groups{$group}{'hosts'} ) );
        %m_hosts = map { $_ => 1 } @hosts;
    }
    else {
        %m_hosts = map { $_ => 1 } StorProc->fetch_list( 'hosts', 'name' );
    }
    return \%m_hosts;
}

#
# get hostgroups. for group sync, get hostgroups directly put in group
#
sub get_direct_monarch_hostgroups {
    my $self       = shift;
    my %hostgroups = ();

    if ( defined( $self->group() ) ) {

        # again, special treatment for Monarch groups (for parent/child setups)
        my $group      = $self->group();
        my %where      = ( 'name' => $group );
        my %group_info =
	    StorProc->fetch_one_where( 'monarch_groups', \%where );
        my %group_hosts =
          StorProc->get_hostgroups_hosts( $group_info{'group_id'} );

        foreach my $group_hash ( keys %group_hosts ) {
            foreach my $grp_hostgroup ( keys %{ $group_hosts{$group_hash} } ) {
                $hostgroups{$grp_hostgroup} = 1;
            }
        }

    }
    else {

        # not doing a Monarch group; get all hostgroups
        %hostgroups =
          map { $_ => 1 } StorProc->fetch_list( 'hostgroups', 'name' );
    }

    return \%hostgroups;
}

#
# get all the hosts that are included in the direct hostgroups
#
sub get_hosts_in_monarch_hostgroups {
    my $hg_ref     = shift;
    my $hosts_ref  = shift;
    my $hh_ref     = shift;
    my %hostgroups = %$hg_ref;

    foreach my $hostgroup ( keys %hostgroups ) {
        my @members = StorProc->get_hostgroup_hosts($hostgroup);

        # add current group members to the %hosts hash
        foreach my $member (@members) {
            $hosts_ref->{$member} = 1;
            $hh_ref->{$hostgroup}{$member} = 1;
        }
    }
}

#
# update hostgroup list, adding any to which any hosts belong
#
sub get_implicit_monarch_hostgroups {
    my $self      = shift;
    my $hosts_ref = shift;
    my $hg_ref    = shift;
    my $hh_ref    = shift;
    my %hosts     = %$hosts_ref;

    if ( defined( $self->group() ) ) {
        foreach my $host ( keys %hosts ) {
            my @hgroups = StorProc->get_hostgroup_host($host);
            foreach my $hgroup (@hgroups) {
                $hg_ref->{$hgroup} = 1;
                $hh_ref->{$hgroup}{$host} = 1;
            }
        }
    }
}

#
# get all services for all the hosts in our list
#
sub get_monarch_service_state {
    my $hosts_ref                         = shift;
    my %hosts                             = %$hosts_ref;
    my %services_by_host                  = ();
    my %services_having_instances_by_host = ();

    # this call yields services for all hosts, which when we are doing
    # groups is more info than we need. but the extra info doesn't
    # affect any logic, nor does it get propagated, so it's ok.
    my %hosts_services = StorProc->get_hostid_servicenameid_serviceid();

    foreach my $host ( keys %hosts ) {

        my %where = ( 'name' => $host );
        my %host_info = StorProc->fetch_one_where( 'hosts', \%where );
        my @services = StorProc->get_host_services( $host_info{'host_id'} );
        foreach my $service (@services) {

            my %where = ( 'name' => $service );
            my %service_info =
              StorProc->fetch_one_where( 'service_names', \%where );
            my $servicename_id = $service_info{'servicename_id'};
            my $service_id =
              $hosts_services{ $host_info{'host_id'} }{$servicename_id};
            my %service_instances =
              StorProc->get_service_instances_names($service_id);

            if ( keys %service_instances ) {

                foreach my $key ( keys %service_instances ) {

                    my $service_instance_name =
                      $service . $service_instances{$key}{'name'};
                    $services_by_host{$host}{$service_instance_name} = 1;
                }
                $services_having_instances_by_host{$host}{$service} = 1;
            }
            else {

                # no service instances
                $services_by_host{$host}{$service} = 1;
            }
        }
    }
    return ( \%services_by_host, \%services_having_instances_by_host );
}

#
# get updated state of the world as seen by foundation
#
sub update_foundation_state {
    my $self  = shift;
    my $state = {};

    my $foundation = CollageQuery->new();
    $state = get_foundation_host_state( $foundation, $state );
    $state = get_foundation_hostgroup_state( $foundation, $state );

    $self->foundation($state);
}

#
# get list of hosts in foundation
#
sub get_foundation_host_state {
    my $foundation = shift;
    my $state      = shift;

    my $f_hosts = $foundation->getHosts();

    if ( ref($f_hosts) eq 'HASH' ) {

        foreach my $host ( keys %{$f_hosts} ) {

            $state->{'host'}{$host} = {};

            my $services_ref = $foundation->getServiceNamesForHost($host);

            if ( ref($services_ref) eq 'ARRAY' ) {
                foreach my $service (@$services_ref) {

                    # 'service', not 'host'
                    $state->{'service'}{$host}{$service} = 1;
                }
            }
        }
    }
    return $state;
}

#
# get list of hostgroups in foundation
#
sub get_foundation_hostgroup_state {
    my $foundation = shift;
    my $state      = shift;

    # get the hostgroups known to foundation
    my $f_hostgroups = $foundation->getHostGroups();
    if ( ref($f_hostgroups) eq 'HASH' ) {
        foreach my $hostgroup ( keys %{$f_hostgroups} ) {
            if ( $hostgroup eq "" ) {
                print STDERR "$0: warning: empty hostgroup\n";
                next;
            }
            my $f_hosts = $foundation->getHostsForHostGroup($hostgroup);
            if ( ref($f_hosts) eq 'HASH' ) {
                foreach my $host ( keys %{$f_hosts} ) {
                    $state->{'hostgroup'}{$hostgroup}{$host} = 1;
                }
            }
        }
    }

    return $state;
}

sub debug {
    my $str  = shift;
    my $file = "/tmp/debug.log";
    open( DEBUG, '>>', $file ) or die "error opening $file ($!)";
    print DEBUG "$str\n";
    close(DEBUG);
}

1;

