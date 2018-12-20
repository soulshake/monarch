# MonArch - Groundwork Monitor Architect
# MonarchAPI.pm
#
############################################################################
# Release 4.4
# February 2015
############################################################################
#
# Copyright 2008-2015 GroundWork Open Source, Inc. (GroundWork)
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
use MonarchStorProc;
use MonarchFile;

package API;

my @errors          = ();
my %config_settings = ();

# '0+0' is treated by Perl as true, but by MySQL as zero (it is apparently able
# to convert the string to an expression and evaluate it).  This is what we need
# to sidestep the clumsy and inappropriate code in StorProc->update_obj_where()
# that recodes plain zeros as NULLs.  We need to force a true zero in the database
# to indicate that this value is really defined.
my $DEFINED = '0+0';
my $DEFINED_REF = \$DEFINED;

sub dbconnect() {
    return StorProc->dbconnect();
}

sub dbdisconnect() {
    return StorProc->dbdisconnect();
}

sub config_settings() {
    my %where = ();
    my %objects = StorProc->fetch_list_hash_array( 'setup', \%where );
    $config_settings{'nagios_ver'}   = $objects{'nagios_version'}[2];
    $config_settings{'nagios_bin'}   = $objects{'nagios_bin'}[2];
    $config_settings{'nagios_etc'}   = $objects{'nagios_etc'}[2];
    $config_settings{'monarch_home'} = $objects{'monarch_home'}[2];
    $config_settings{'backup_dir'}   = $objects{'backup_dir'}[2];
    return %config_settings;
}

sub backup() {
    %config_settings = %{ $_[1] };
    my $user_acct  = $_[2];
    my $annotation = $_[3];
    my $lock       = $_[4];
    ## FIX MAJOR:  Convert this to a StorProc->synchronized_backup() call.
    my ( $full_backup_dir, $errors ) = StorProc->backup(
	$config_settings{'nagios_etc'},
	$config_settings{'backup_dir'},
	$user_acct,
	$annotation || 'unannotated backup initiated via MonarchAPI',
	$lock
    );
    return $full_backup_dir, $errors;
}

sub build_files(@) {
    my %file_ref = %{ $_[1] };
    %config_settings = %{ $_[2] };
    config_settings();
    my ( $files, $errors ) = Files->build_files(
	$file_ref{'user_acct'}, $file_ref{'group'}, $file_ref{'commit_step'},
	$file_ref{'export'},
	$config_settings{'nagios_ver'},
	$config_settings{'nagios_etc'},
	$file_ref{'location'}, $file_ref{'tarball'}
    );
    if ( !defined( $file_ref{'commit_step'} ) ) {

	# If an error leads you here, you have been bitten by the well-intentioned renaming of a
	# hash key. Previously the hashkey in question was called variously 'type' or 'preflight',
	# and it had possible values of '' (empty string), 1, or 2, with 1 meaning
	# preflight and 2 meaning commit. Now it is called 'commit_step' and it has possible
	# corresponding values of '' (empty string), 'preflight', and 'commit'.
	push( @$errors,
"Error: in MonarchAPI.pm build_files(), file_ref hashref should include a commit_step element with value of '', 'preflight', or 'commit'."
	);
    }
    return $files, $errors;
}

sub pre_flight_check(@) {
    %config_settings = %{ $_[1] };
    my @preflight_results = StorProc->pre_flight_check( $config_settings{'nagios_bin'}, $config_settings{'monarch_home'} );
    my $rc = 0;
    foreach my $msg (@preflight_results) {
	if ( $msg =~ /Things look okay/ ) { $rc = 1 }
    }
    return $rc;
}

sub commit(@) {
    %config_settings = %{ $_[1] };
    my $user_acct  = $_[2];
    my $annotation = $_[3];
    my $lock       = $_[4];

    # FIX MAJOR:  Call StorProc->synchronized_commit() instead, and deal with the different arguments
    # it returns, making sure we do the right thing with respect to error/result ordering.
    if (1) {
	my @commit_results = StorProc->commit(
	    $config_settings{monarch_home},
	    $config_settings{nagios_etc},
	    $config_settings{backup_dir},
	    $user_acct, $annotation, $lock
	);
	return @commit_results;
    }

    my ( $errors, $results, $timings ) = StorProc->synchronized_commit(
	$user_acct,                   $config_settings{nagios_ver},   $config_settings{nagios_etc},
	$config_settings{nagios_bin}, $config_settings{monarch_home}, 'html',
	$config_settings{backup_dir}, $annotation,                    $lock
    );

    push @$results, @$errors;
    return @$results;
}

sub get_objects() {
    my %objects = ();
    %{ $objects{'contacts'} }         = StorProc->get_table_objects('contacts');
    %{ $objects{'contact_groups'} }   = StorProc->get_table_objects('contactgroups');
    %{ $objects{'host_groups'} }      = StorProc->get_table_objects('hostgroups');
    %{ $objects{'groups'} }           = StorProc->get_table_objects('monarch_groups');
    %{ $objects{'service_groups'} }   = StorProc->get_table_objects('servicegroups');
    %{ $objects{'service_names'} }    = StorProc->get_table_objects('service_names');
    %{ $objects{'host_profiles'} }    = StorProc->get_table_objects('profiles_host');
    %{ $objects{'service_profiles'} } = StorProc->get_table_objects('profiles_service');
    %{ $objects{'escalations'} }      = StorProc->get_table_objects('escalation_trees');
    %{ $objects{'commands'} }         = StorProc->get_table_objects('commands');
    %{ $objects{'externals'} }        = StorProc->get_table_objects('externals');
    return %objects;
}

sub get_groups() {
    my %groups      = ();
    my %where       = ();
    my %groups_hash = StorProc->fetch_list_hash_array( 'monarch_groups', \%where );
    foreach my $id ( keys %groups_hash ) {
	$groups{ $groups_hash{$id}[1] } = $groups_hash{$id}[3];
    }
    return %groups;
}

# comment and notes fields are optional
sub add_service_group(@) {
    my %service_group = %{ $_[1] };
    my %escalation    = StorProc->fetch_one( 'escalation_trees', 'name', $service_group{'service_escalation'} );
    my @values        = ( \undef, $service_group{'name'}, $service_group{'alias'}, $escalation{'tree_id'},
      $service_group{'comment'}, $service_group{'notes'} );
    my $id            = StorProc->insert_obj_id( 'servicegroups', \@values, 'servicegroup_id' );
    return $id;
}

sub add_contact_group(@) {
    my %contact_group = %{ $_[1] };
    my @values        = ( \undef, $contact_group{'name'}, $contact_group{'alias'}, '' );
    my $id            = StorProc->insert_obj_id( 'contactgroups', \@values, 'contactgroup_id' );
    return $id;
}

# comment and notes fields are optional
sub add_host_group(@) {
    my %host_group         = %{ $_[1] };
    my @results            = ();
    my %profile            = StorProc->fetch_one( 'profiles_host', 'name', $host_group{'host_profile'} );
    my %host_escalation    = StorProc->fetch_one( 'escalation_trees', 'name', $host_group{'host_escalation'} );
    my %service_escalation = StorProc->fetch_one( 'escalation_trees', 'name', $host_group{'service_escalation'} );
    my @values             = (
	\undef, $host_group{'name'}, $host_group{'alias'},
	$profile{'hostprofile_id'},
	$host_escalation{'tree_id'},
	$service_escalation{'tree_id'},
	'1', $host_group{'comment'}, $host_group{'notes'}
    );
    my $id = StorProc->insert_obj_id( 'hostgroups', \@values, 'hostgroup_id' );
    if ( $host_group{'groups'} ) {

	foreach my $group ( keys %{ $host_group{'groups'} } ) {
	    my @vals = ( $host_group{'groups'}{$group}, $id );
	    my $result = StorProc->insert_obj( 'monarch_group_hostgroup', \@vals );
	    if ( $result =~ /error/i ) { push @results, $result }
	}
    }
    return @results;
}

sub get_host(@) {
    my $host = $_[1];
    my %host = StorProc->fetch_one( 'hosts', 'name', $host );
    if ( $host{'name'} ) {
	@{ $host{'services'} } = ();
	my @services = StorProc->get_host_services( $host{'host_id'} );
	if ( $services[0] ) { push( @{ $host{'services'} }, @services ) }
    }
    return %host;
}

sub import_host(@) {
    my %host = %{ $_[1] };
    @errors = ();
    my @results = ();
    my %profile = StorProc->fetch_one( 'profiles_host', 'hostprofile_id', $host{'hostprofile_id'} );
    unless ( $host{'host_escalation_id'} ) {
	$host{'host_escalation_id'} = $profile{'host_escalation_id'};
    }
    unless ( $host{'service_escalation_id'} ) {
	$host{'service_escalation_id'} = $profile{'service_escalation_id'};
    }
    if ( $host{'exists'} && $host{'overwrite'} ) {
	my %values = (
	    'alias'                 => $host{'alias'},
	    'address'               => $host{'address'},
	    'hosttemplate_id'       => $profile{'host_template_id'},
	    'hostextinfo_id'        => $profile{'host_extinfo_id'},
	    'hostprofile_id'        => $host{'hostprofile_id'},
	    'host_escalation_id'    => $host{'host_escalation_id'},
	    'service_escalation_id' => $host{'service_escalation_id'},
	    'comment'               => $host{'comment'},
	    'notes'                 => $host{'notes'}
	);
	my $result = StorProc->update_obj( 'hosts', 'name', $host{'name'}, \%values );
	if ( $result =~ /error/i ) { push @errors, $result }

    }
    elsif ( $host{'new'} ) {
	my @values = (
	    \undef, $host{'name'}, $host{'alias'}, $host{'address'}, '',
	    $profile{'host_template_id'},
	    $profile{'host_extinfo_id'},
	    $host{'hostprofile_id'},
	    $host{'host_escalation_id'},
	    $host{'service_escalation_id'},
	    '',
	    $host{'comment'},
	    $host{'notes'}
	);
	my $id = StorProc->insert_obj_id( 'hosts', \@values, 'host_id' );
	if ( $id =~ /error/i ) {
	    push @errors, $id;
	}
	else {
	    push @results, " Host $host{'name'} added";
	    $host{'host_id'} = $id;
	}
    }
    unless ( $errors[0] ) {
	my %where = ();
	my %externals_hash = StorProc->fetch_list_hash_array( 'externals', \%where );
	if ( $host{'new'} || $host{'overwrite'} ) {
	    my @hosts = ( $host{'host_id'} );
	    my @errs = StorProc->host_profile_apply( $profile{'hostprofile_id'}, \@hosts );
	    if ( $errs[0] ) { push( @results, @errs ) }

	    # Apply host groups
	    if ( $host{'exists'} ) {
		my $result = StorProc->delete_all( 'hostgroup_host', 'host_id', $host{'host_id'} );
		if ( $result =~ /error/i ) { push @results, $result }
	    }
	    %where = ( 'hostprofile_id' => $host{'hostprofile_id'} );
	    my @hostgroups = StorProc->fetch_list_where( 'profile_hostgroup', 'hostgroup_id', \%where );
	    ## FIX LATER:  This and similar patterns below could be made more compact.
	    foreach my $group ( keys %{ $host{'host_groups'} } ) {
		my $got_group = 0;
		foreach my $id (@hostgroups) {
		    if ( $host{'host_groups'}{$group} eq $id ) {
			$got_group = 1;
			last;
		    }
		}
		unless ($got_group) {
		    push @hostgroups, $host{'host_groups'}{$group};
		}
	    }
	    foreach my $id (@hostgroups) {
		my @vals = ( $id, $host{'host_id'} );
		my $result = StorProc->insert_obj( 'hostgroup_host', \@vals );
		if ( $result =~ /error/i ) { push @results, $result }
	    }

	    # Apply contact groups
	    if ( $host{'exists'} ) {
		my %where = ( 'host_id' => $host{'host_id'} );
		my @services = StorProc->fetch_list_where( 'services', 'service_id', \%where );

		# delete then add host_id to table contactgroup_host
		# delete then add service_id to table contactgroup_service
		%where = ( 'host_id' => $host{'host_id'} );
		my $result = StorProc->delete_one_where( 'contactgroup_host', \%where );
		if ( $result =~ /error/i ) { push @results, $result }
		foreach my $id (@services) {
		    %where = ( 'service_id' => $id );
		    my $result = StorProc->delete_one_where( 'contactgroup_service', \%where );
		    if ( $result =~ /error/i ) { push @results, $result }
		}
	    }

	    my %where = ( 'hostprofile_id' => $host{'hostprofile_id'} );
	    my @contact_groups = StorProc->fetch_list_where( 'contactgroup_host_profile', 'contactgroup_id', \%where );
	    foreach my $group ( keys %{ $host{'contact_groups'} } ) {
		my $got_group = 0;
		foreach my $id (@contact_groups) {
		    if ( $host{'contact_groups'}{$group} eq $id ) {
			$got_group = 1;
			last;
		    }
		}
		unless ($got_group) {
		    push @contact_groups, $host{'contact_groups'}{$group};
		}
	    }
	    foreach my $id (@contact_groups) {
		my @vals = ( $id, $host{'host_id'} );
		my $result = StorProc->insert_obj( 'contactgroup_host', \@vals );
		if ( $result =~ /error/i ) { push @results, $result }
	    }

	    # Apply parents from host profile
	    if ( $host{'exists'} ) {
		my $result = StorProc->delete_all( 'host_parent', 'host_id', $host{'host_id'} );
		if ( $result =~ /error/i ) { push @results, $result }
	    }
	    %where = ( 'hostprofile_id' => $host{'hostprofile_id'} );
	    my @parents = StorProc->fetch_list_where( 'profile_parent', 'host_id', \%where );
	    foreach my $id (@parents) {
		my @vals = ( $host{'host_id'}, $id );
		my $result = StorProc->insert_obj( 'host_parent', \@vals );
		if ( $result =~ /error/i ) { push @results, $result }
	    }

	    # Apply host externals
	    if ( $host{'exists'} ) {
		my $result = StorProc->delete_all( 'external_host', 'host_id', $host{'host_id'} );
		if ( $result =~ /error/i ) { push @results, $result }
	    }
	    my $extcnt = 0;
	    %where = ( 'hostprofile_id' => $host{'hostprofile_id'} );
	    my @externals = StorProc->fetch_list_where( 'external_host_profile', 'external_id', \%where );
	    foreach my $id (@externals) {
		my $got_ext = 0;
		my $extcnt  = 0;
		foreach my $ext ( keys %{ $host{'host_externals'} } ) {
		    if ( $id eq $host{'host_externals'}{$ext}{'external_id'} ) {
			$got_ext = 1;
			last;
		    }
		}
		unless ($got_ext) {
		    $extcnt++;
		    $host{'host_externals'}{$extcnt}{'external_id'} = $id;
		    $host{'host_externals'}{$extcnt}{'value'}       = $externals_hash{$id}[4];
		    $host{'host_externals'}{$extcnt}{'unmodified'}  = 1;
		}
	    }
	    foreach my $ext ( keys %{ $host{'host_externals'} } ) {
		if ( $host{'host_externals'}{$ext}{'value'} =~ /\@default\@/ ) {
		    $host{'host_externals'}{$ext}{'value'} = $externals_hash{ $host{'host_externals'}{$ext}{'external_id'} }[4];
		    $host{'host_externals'}{$ext}{'unmodified'} = 1;
		}
		my @vals = (
		    $host{'host_externals'}{$ext}{'external_id'}, $host{'host_id'},
		    $host{'host_externals'}{$ext}{'value'},
		    $host{'host_externals'}{$ext}{'unmodified'} ? $DEFINED_REF : '1'
		);
		my $result = StorProc->insert_obj( 'external_host', \@vals );
		if ( $result =~ /error/i ) { push @results, $result }
	    }

	    # Apply service profiles
	    if ( $host{'exists'} ) {
		my $result = StorProc->delete_all( 'services', 'host_id', $host{'host_id'} );
		if ( $result =~ /error/i ) { push @results, $result }
		$result = StorProc->delete_all( 'serviceprofile_host', 'host_id', $host{'host_id'} );
		if ( $result =~ /error/i ) { push @results, $result }
	    }
	    %where = ( 'hostprofile_id' => $host{'hostprofile_id'} );
	    my @service_profiles = StorProc->fetch_list_where( 'profile_host_profile_service', 'serviceprofile_id', \%where );
	    foreach my $spname ( keys %{ $host{'service_profiles'} } ) {
		my $got_sp = 0;
		foreach my $sp (@service_profiles) {
		    if ( $host{'service_profiles'}{$spname} eq $sp ) {
			$got_sp = 1;
			last;
		    }
		}
		unless ($got_sp) {
		    push @service_profiles, $host{'service_profiles'}{$spname};
		}
	    }
	    @hosts = ( $host{'host_id'} );
	    foreach my $sp (@service_profiles) {
		my @vals = ( $sp, $host{'host_id'} );
		my $result = StorProc->insert_obj( 'serviceprofile_host', \@vals );
		if ( $result =~ /error/i ) { push @results, $result }
	    }
	    @errs = StorProc->service_profile_apply( \@service_profiles, 'replace', \@hosts );
	    if ( $errs[0] =~ /error/i ) { push( @results, @errs ) }
	}

	# Apply services
	if ( $host{'new'} || $host{'service_overwrites'} || $host{'overwrite'} ) {
	    foreach my $service ( keys %{ $host{'services'} } ) {

		# Add/update service
		if ( $host{'exists'} ) {
		    if (   $host{'services'}{$service}{'overwrite'}
			|| $host{'services'}{$service}{'delete'}
			|| $host{'overwrite'} )
		    {
			my %where = (
			    'host_id'        => $host{'host_id'},
			    'servicename_id' => $host{'services'}{$service}{'servicename_id'}
			);
			my %service = StorProc->fetch_one_where( 'services', \%where );

			%where = ( 'service_id' => $service{'service_id'} );
			my $result = StorProc->delete_one_where( 'contactgroup_service', \%where );

			if ( $result =~ /error/i ) { push @results, $result }
			%where = (
			    'host_id'    => $host{'host_id'},
			    'service_id' => $service{'service_id'}
			);
			$result = StorProc->delete_one_where( 'servicegroup_service', \%where );
			if ( $result =~ /error/i ) { push @results, $result }
			$result = StorProc->delete_one_where( 'external_service', \%where );
			if ( $result =~ /error/i ) { push @results, $result }
			## FIX MAJOR:  Should we delete from the services table, too?
			if ( $host{'services'}{$service}{'delete'} ) { next }
		    }
		    else {
			delete $host{'services'}{$service};
			next;
		    }
		}
		my %service_name = StorProc->fetch_one( 'service_names', 'servicename_id', $host{'services'}{$service}{'servicename_id'} );
		if ( $host{'services'}{$service}{'check_command_id'} ) {
		    $service_name{'check_command'} = $host{'services'}{$service}{'check_command_id'};
		    $service_name{'command_line'}  = $host{'services'}{$service}{'check_command'};
		}
		if ( $host{'services'}{$service}{'service_escalation_id'} ) {
		    $service_name{'escalation'} = $host{'services'}{$service}{'service_escalation_id'};
		}
		my @vals = (
		    \undef, $host{'host_id'},
		    $host{'services'}{$service}{'servicename_id'},
		    $service_name{'template'},
		    $service_name{'extinfo'},
		    $service_name{'escalation'},
		    '1',
		    $service_name{'check_command'},
		    $service_name{'command_line'},
		    $host{'services'}{$service}{'comment'},
		    $host{'services'}{$service}{'notes'}
		);
		my $service_id = StorProc->insert_obj_id( 'services', \@vals, 'service_id' );
		if ( $service_id =~ /^Error/ ) {
		    push @results, $service_id;
		    next;
		}

		my %overrides = StorProc->fetch_one( 'servicename_overrides', 'servicename_id', $service_name{'servicename_id'} );
		my %values    = ();
		my $data      = "<?xml version=\"1.0\" encoding=\"iso-8859-1\" ?>\n<data>";
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
		my @values =
		  ( $service_id, $values{'check_period'}, $values{'notification_period'}, $values{'event_handler'}, $values{'data'} );
		my $result = StorProc->insert_obj( 'service_overrides', \@values );
		if ( $result =~ /Error/ ) { push @results, $result }

		my %where = ( 'servicename_id' => $service_name{'servicename_id'} );
		my %dependencies = StorProc->fetch_list_hash_array( 'servicename_dependency', \%where );
		foreach my $did ( keys %dependencies ) {
		    unless ( $dependencies{$did}[2] ) {
			$dependencies{$did}[2] = $host{'host_id'};
		    }
		    my @vals = ( \undef, $service_id, $host{'host_id'}, $dependencies{$did}[2], $dependencies{$did}[3], '' );
		    $result = StorProc->insert_obj( 'service_dependency', \@vals );
		    if ( $result =~ /^Error/ ) { push @results, $result }
		}

		# Apply contact groups
		%where = ( 'servicename_id' => $host{'services'}{$service}{'servicename_id'} );
		my @contact_groups = StorProc->fetch_list_where( 'contactgroup_service_name', 'contactgroup_id', \%where );
		foreach my $group ( keys %{ $host{'services'}{$service}{'contact_groups'} } ) {
		    my $got_group = 0;
		    foreach my $id (@contact_groups) {
			if ( $host{'services'}{$service}{'contact_groups'}{$group} eq $id ) {
			    $got_group = 1;
			    last;
			}
		    }
		    unless ($got_group) {
			push @contact_groups, $host{'services'}{$service}{'contact_groups'}{$group};
		    }
		}
		foreach my $id (@contact_groups) {
		    my @vals = ( $id, $service_id );
		    my $result = StorProc->insert_obj( 'contactgroup_service', \@vals );
		    if ( $result =~ /error/i ) { push @results, $result }
		}

		# Apply service groups
		foreach my $group ( keys %{ $host{'services'}{$service}{'service_groups'} } ) {
		    my @vals = ( $host{'services'}{$service}{'service_groups'}{$group}, $host{'host_id'}, $service_id );
		    my $result = StorProc->insert_obj( 'servicegroup_service', \@vals );
		    if ( $result =~ /error/i ) { push @results, $result }
		}

		# Apply service externals
		my $extcnt = 0;
		%where = ( 'servicename_id' => $service_name{'servicename_id'} );
		my @externals = StorProc->fetch_list_where( 'external_service_names', 'external_id', \%where );
		foreach my $id (@externals) {
		    my $got_ext = 0;
		    foreach my $ext ( keys %{ $host{'services'}{$service}{'service_externals'} } ) {
			if ( $host{'services'}{$service}{'service_externals'}{$ext}{'external_id'} eq $id ) {
			    $got_ext = 1;
			    last;
			}
		    }
		    unless ($got_ext) {
			$extcnt++;
			$host{'services'}{$service}{'service_externals'}{$extcnt}{'external_id'} = $id;
			$host{'services'}{$service}{'service_externals'}{$extcnt}{'value'}       = $externals_hash{$id}[4];
			$host{'services'}{$service}{'service_externals'}{$extcnt}{'unmodified'}  = 1;
		    }
		}
		foreach my $ext ( keys %{ $host{'services'}{$service}{'service_externals'} } ) {
		    if ( $host{'services'}{$service}{'service_externals'}{$ext}{'value'} =~ /\@default\@/ ) {
			$host{'services'}{$service}{'service_externals'}{$ext}{'value'} =
			  $externals_hash{ $host{'services'}{$service}{'service_externals'}{$ext}{'external_id'} }[4];
			$host{'services'}{$service}{'service_externals'}{$ext}{'unmodified'} = 1;
		    }
		    my @vals = (
			$host{'services'}{$service}{'service_externals'}{$ext}{'external_id'}, $host{'host_id'}, $service_id,
			$host{'services'}{$service}{'service_externals'}{$ext}{'value'},
			$host{'services'}{$service}{'service_externals'}{$ext}{'unmodified'} ? $DEFINED_REF : '1'
		    );
		    $result = StorProc->insert_obj( 'external_service', \@vals );
		    if ( $result =~ /^Error/ ) { push @results, $result }
		}
	    }
	}
    }
    else {
	push( @results, @errors );
    }
    return @results;
}

sub delete_host(@) {
    my $host = $_[1];
    @errors = ();
    my %host   = StorProc->fetch_one( 'hosts', 'name', $host );
    my %where  = ( 'host_id' => $host{'host_id'} );
    my $result = StorProc->delete_one_where( 'contactgroup_host', \%where );
    if ( $result =~ /^Error/ ) { push @errors, $result }
    %where = ( 'host_id' => $host{'host_id'} );
    my @services = StorProc->fetch_list_where( 'services', 'service_id', \%where );
    foreach my $sid (@services) {
	my %where = ( 'service_id' => $sid );
	$result = StorProc->delete_one_where( 'contactgroup_service', \%where );
	if ( $result =~ /^Error/ ) { push @errors, $result }
    }
    $result = StorProc->delete_all( 'hosts', 'name', $host );
    if ( $result =~ /^Error/ ) {
	push @errors, $result;
    }
    else {
	$result = StorProc->delete_all( 'host_service', 'host', $host );
	if ( $result =~ /^Error/ ) { push @errors, $result }
    }
    my @results = ();
    if (@errors) {
	push( @results, @errors );
    }
    else {
	push @results, "Host $host deleted";
    }
    return @results;
}

sub set_host_parent(@) {
    my %hosts = %{ $_[1] };
    @errors = ();
    my %host_names = StorProc->get_table_objects('hosts');
    foreach my $host ( keys %hosts ) {
	my $got_parent   = 0;
	my @host_parents = StorProc->get_host_parent( $host_names{$host} );
	foreach my $parent ( keys %{ $hosts{$host}{'parents'} } ) {
	    my $got_parent = 0;
	    foreach my $eparent (@host_parents) {
		if ( $host_names{$eparent} eq $host_names{$parent} ) {
		    $got_parent = 1;
		}
	    }
	    unless ($got_parent) {
		my @vals = ( $host_names{$host}, $host_names{$parent} );
		my $result = StorProc->insert_obj( 'host_parent', \@vals );
		if ( $result =~ /^Error/ ) { push @errors, $result }
	    }
	}
    }
    return @errors;
}

sub add_external(@) {
    my $name   = $_[1];
    my $type   = $_[2];
    my $detail = $_[3];
    my @values = ( \undef, $name, '', $type, $detail, '' );
    my $id     = StorProc->insert_obj_id( 'externals', \@values, 'external_id' );
    return $id;
}

sub import_profile(@) {
    my $folder    = $_[1];
    my $file      = $_[2];
    my $overwrite = $_[3];
    my @messages  = ();
    use MonarchProfileImport;
    push @messages, "Importing $file";
    my @msgs = ProfileImporter->import_profile( $folder, $file, $overwrite );
    push( @messages, @msgs );
    push @messages, "-----------------------------------------------------";
    return @messages;
}

sub parse_input_xml(@) {
    my $file = $_[1];
    my $data = undef;
    if ( !open( FILE, '<', $file ) ) {
	## FIX MINOR:  This message is never visible anywhere.
	push @errors, "error:  cannot open $file to read ($!)";
    }
    else {
	while ( my $line = <FILE> ) {
	    $line =~ s/\r\n/\n/;
	    $data .= $line;
	}
	close(FILE);
    }
    my %input = ();
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
	    ## FIX LATER:  HTMLifying here, along with embedded markup in $input{'error'}, is something of a hack,
	    ## as it presumes a context not in evidence.  But it's necessary in the browser context.
	    $@ = HTML::Entities::encode($@);
	    $@ =~ s/\n/<br>/g;
	    if ($@ =~ s/external entity callback died: // || $@ =~ /external entity references are not allowed/) {
		## First undo the effect of the croak() call in XML::LibXML.
		$@ =~ s/ at \S+ line \d+<br>//;
		$input{'error'} = "Bad XML string (parse_input_xml):<br>$@";
	    }
	    elsif ($@ =~ /Attempt to load network entity/) {
		$input{'error'} = "Bad XML string (parse_input_xml):<br>INVALID FORMAT: non-local entity references are not allowed in XML documents.<pre>$@</pre>";
	    }
	    else {
		$input{'error'} = "Bad XML string (parse_input_xml):<br>$@ called from $file line $line.";
	    }
	}
	else {
	    my @nodes = $doc->findnodes("//setup");
	    foreach my $node (@nodes) {
		if ( $node->hasChildNodes() ) {
		    my @children = $node->getChildnodes();
		    foreach my $child (@children) {
			if ( $child->hasAttributes() ) {
			    my $prop  = $child->getAttribute('name');
			    my $value = $child->textContent;
			    $input{'setup'}{$prop} = $value;
			}
		    }
		}
	    }
	    @nodes = $doc->findnodes("//service_group");
	    foreach my $node (@nodes) {
		my ( $name, $alias, $escalation ) = undef;
		if ( $node->hasChildNodes() ) {
		    my @children = $node->getChildnodes();
		    foreach my $child (@children) {
			if ( $child->hasAttributes() ) {
			    my $prop  = $child->getAttribute('name');
			    my $value = $child->textContent;
			    if ( $prop eq 'service_group_name' ) { $name = $value }
			    if ( $prop eq 'service_group_alias' ) {
				$alias = $value;
			    }
			    if ( $prop eq 'service_escalation' ) {
				$escalation = $value;
			    }
			}
		    }
		}
		$input{'service_groups'}{$name}{'name'}               = $name;
		$input{'service_groups'}{$name}{'alias'}              = $alias;
		$input{'service_groups'}{$name}{'service_escalation'} = $escalation;
	    }
	    @nodes = $doc->findnodes("//host_group");
	    foreach my $node (@nodes) {
		my %groups = ();
		my ( $name, $alias, $host_profile, $host_escalation, $service_escalation ) = undef;
		if ( $node->hasChildNodes() ) {
		    my @children = $node->getChildnodes();
		    foreach my $child (@children) {
			if ( $child->hasAttributes() ) {
			    my $prop  = $child->getAttribute('name');
			    my $value = $child->textContent;
			    if ( $prop eq 'host_group_name' )  { $name  = $value }
			    if ( $prop eq 'host_group_alias' ) { $alias = $value }
			    if ( $prop eq 'host_profile' ) {
				$host_profile = $value;
			    }
			    if ( $prop eq 'host_escalation' ) {
				$host_escalation = $value;
			    }
			    if ( $prop eq 'service_escalation' ) {
				$service_escalation = $value;
			    }
			    if ( $prop eq 'group' ) { $groups{$value} = $value }
			}
		    }
		}
		$input{'host_groups'}{$name}{'name'}               = $name;
		$input{'host_groups'}{$name}{'alias'}              = $alias;
		$input{'host_groups'}{$name}{'host_profile'}       = $host_profile;
		$input{'host_groups'}{$name}{'host_escalation'}    = $host_escalation;
		$input{'host_groups'}{$name}{'service_escalation'} = $service_escalation;
		%{ $input{'host_groups'}{$name}{'groups'} } = ();
		foreach my $key ( keys %groups ) {
		    $input{'host_groups'}{$name}{'groups'}{$key} = $key;
		}
	    }
	    @nodes = $doc->findnodes("//contact_group");
	    foreach my $node (@nodes) {
		my ( $name, $alias ) = undef;
		if ( $node->hasChildNodes() ) {
		    my @children = $node->getChildnodes();
		    foreach my $child (@children) {
			if ( $child->hasAttributes() ) {
			    my $prop  = $child->getAttribute('name');
			    my $value = $child->textContent;
			    if ( $prop eq 'contact_group_name' ) { $name = $value }
			    if ( $prop eq 'contact_group_alias' ) {
				$alias = $value;
			    }
			}
		    }
		}
		$input{'contact_groups'}{$name}{'name'}  = $name;
		$input{'contact_groups'}{$name}{'alias'} = $alias;
	    }
	    @nodes = $doc->findnodes("//host");
	    foreach my $node (@nodes) {
		my %services            = ();
		my %service_profiles    = ();
		my %host_externals      = ();
		my %host_contact_groups = ();
		my %host_groups         = ();
		my %host_parent         = ();
		my ( $name, $alias, $address, $host_profile, $group, $overwrite, $delete, $host_escalation, $host_service_escalation ) = undef;
		if ( $node->hasAttributes() ) {
		    $overwrite = $node->getAttribute('overwrite');
		    $delete    = $node->getAttribute('delete');
		}
		if ( $node->hasChildNodes() ) {
		    my @children = $node->getChildnodes();
		    foreach my $child (@children) {
			if ( $child->nodeName() eq 'service' ) {
			    my ( $service_name, $check_command, $contact_group, $service_group, $sv_overwrite, $sv_delete, $service_escalation ) =
			      undef;
			    if ( $child->hasChildNodes() ) {
				if ( $child->hasAttributes() ) {
				    $sv_overwrite = $child->getAttribute('overwrite');
				    $sv_delete    = $child->getAttribute('delete');
				}
				my %service_externals = ();
				my %contact_groups    = ();
				my %service_groups    = ();
				my @service_props     = $child->getChildnodes();
				foreach my $sp (@service_props) {
				    if ( $sp->nodeName() eq 'service_external' ) {
					if ( $sp->hasAttributes() ) {
					    my $prop  = $sp->getAttribute('name');
					    my $value = $sp->textContent;
					    $service_externals{$prop} = $value;
					}
				    }
				    elsif ( $sp->hasAttributes() ) {
					my $prop  = $sp->getAttribute('name');
					my $value = $sp->textContent;
					if ( $prop eq 'service_name' ) {
					    $service_name = $value;
					}
					if ( $prop eq 'check_command' ) {
					    $check_command = $value;
					}
					if ( $prop eq 'service_escalation' ) {
					    $service_escalation = $value;
					}
					if ( $prop eq 'contact_group' ) {
					    $contact_groups{$value} = $value;
					}
					if ( $prop eq 'service_group' ) {
					    $service_groups{$value} = $value;
					}
				    }
				}
				if ($sv_overwrite) {
				    $input{'hosts'}{$name}{'service_overwrites'} = 1;
				    $services{$service_name}{'overwrite'} = $sv_overwrite;
				}
				if ($sv_delete) {
				    $input{'hosts'}{$name}{'service_deletes'} = 1;
				    $services{$service_name}{'delete'} = $sv_delete;
				}
				$services{$service_name}{'name'}               = $service_name;
				$services{$service_name}{'check_command'}      = $check_command;
				$services{$service_name}{'service_escalation'} = $service_escalation;
				%{ $services{$service_name}{'contact_groups'} } = ();
				foreach my $key ( keys %contact_groups ) {
				    $services{$service_name}{'contact_groups'}{$key} = $key;
				}
				%{ $services{$service_name}{'service_groups'} } = ();
				foreach my $key ( keys %service_groups ) {
				    $services{$service_name}{'service_groups'}{$key} = $key;
				}
				%{ $services{$service_name}{'service_externals'} } = ();
				foreach my $key ( keys %service_externals ) {
				    $services{$service_name}{'service_externals'}{$key}{'name'}  = $key;
				    $services{$service_name}{'service_externals'}{$key}{'value'} = $service_externals{$key};
				}
			    }
			}
			elsif ( $child->nodeName() eq 'host_external' ) {
			    if ( $child->hasAttributes() ) {
				my $prop  = $child->getAttribute('name');
				my $value = $child->textContent;
				$host_externals{$prop} = $value;
			    }
			}
			elsif ( $child->hasAttributes() ) {
			    my $prop  = $child->getAttribute('name');
			    my $value = $child->textContent;
			    if ( $prop eq 'host_name' )    { $name    = $value }
			    if ( $prop eq 'host_alias' )   { $alias   = $value }
			    if ( $prop eq 'host_address' ) { $address = $value }
			    if ( $prop eq 'host_profile' ) {
				$host_profile = $value;
			    }
			    if ( $prop eq 'group' ) { $group = $value }

			    if ( $prop eq 'host_escalation' ) {
				$host_escalation = $value;
			    }
			    if ( $prop eq 'service_escalation' ) {
				$host_service_escalation = $value;
			    }
			    if ( $prop eq 'service_profile' ) {
				$service_profiles{$value} = $value;
			    }
			    if ( $prop eq 'contact_group' ) {
				$host_contact_groups{$value} = $value;
			    }
			    if ( $prop eq 'host_group' ) {
				$host_groups{$value} = $value;
			    }
			    if ( $prop eq 'host_parent' ) {
				$host_parent{$value} = $value;
			    }
			}
		    }
		}
		$input{'hosts'}{$name}{'overwrite'}          = $overwrite;
		$input{'hosts'}{$name}{'delete'}             = $delete;
		$input{'hosts'}{$name}{'name'}               = $name;
		$input{'hosts'}{$name}{'alias'}              = $alias;
		$input{'hosts'}{$name}{'address'}            = $address;
		$input{'hosts'}{$name}{'host_profile'}       = $host_profile;
		$input{'hosts'}{$name}{'group'}              = $group;
		$input{'hosts'}{$name}{'host_escalation'}    = $host_escalation;
		$input{'hosts'}{$name}{'service_escalation'} = $host_service_escalation;
		%{ $input{'hosts'}{$name}{'services'} } = ();

		foreach my $key ( keys %services ) {
		    $input{'hosts'}{$name}{'services'}{$key} = $services{$key};
		}
		%{ $input{'hosts'}{$name}{'host_externals'} } = ();
		foreach my $key ( keys %host_externals ) {
		    $input{'hosts'}{$name}{'host_externals'}{$key}{'name'}  = $key;
		    $input{'hosts'}{$name}{'host_externals'}{$key}{'value'} = $host_externals{$key};
		}
		%{ $input{'hosts'}{$name}{'contact_groups'} } = ();
		foreach my $key ( keys %host_contact_groups ) {
		    $input{'hosts'}{$name}{'contact_groups'}{$key} = $key;
		}
		%{ $input{'hosts'}{$name}{'service_profiles'} } = ();
		foreach my $key ( keys %service_profiles ) {
		    $input{'hosts'}{$name}{'service_profiles'}{$key} = $key;
		}
		%{ $input{'hosts'}{$name}{'host_groups'} } = ();
		foreach my $key ( keys %host_groups ) {
		    $input{'hosts'}{$name}{'host_groups'}{$key} = $key;
		}
		foreach my $key ( keys %host_parent ) {
		    $input{'hosts'}{$name}{'parents'}{$key} = $key;
		}
	    }
	}
    }
    else {
	$input{'error'} = "Empty String (parse_input_xml)";
    }
    return %input;
}

1;

