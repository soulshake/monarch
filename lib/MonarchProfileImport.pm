# MonArch - Groundwork Monitor Architect
# MonarchProfileImport.pm
#
############################################################################
# Release 4.6
# October 2017
############################################################################
#
# Original author: Scott Parris
#
# Copyright 2007-2017 GroundWork Open Source, Inc. (GroundWork)
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
use MonarchForms;
use XML::LibXML;

package ProfileImporter;

my $debug     = 0;
my %objects   = ();
my %externals = ();
my %db_values = ();
my %ov        = ( 1 => 'Yes', 2 => 'No' );
my ( $file, $overwrite, $parser, $tree, $root, $monarch_ver ) = 0;
my $objects_read = 0;
my @messages     = ();
my $empty_data   = qq(<?xml version="1.0" encoding="iso-8859-1" ?>
<data>
</data>);

sub data_prep(@) {
    my $obj           = $_[0];
    my %values        = %{ $_[1] };
    my %data_vals     = ();
    my %property_list = StorProc->property_list();
    my @props         = split( /,/, $property_list{$obj} );
    my @db_vals       = split( /,/, $db_values{$obj} );
    foreach my $name ( keys %values ) {
	foreach my $p (@props) {
	    if ( $p eq $name or $p eq 'custom_object_variables' && $name =~ /^_/ ) {
		my $match = undef;
		foreach my $val (@db_vals) {
		    if ( $val eq $name ) {
			$data_vals{$val} = $values{$name};
			$match = 1;
			last;
		    }
		}
		unless ($match) {
		    if ( $values{$p} || defined( $values{$p} ) && $values{$p} eq '0' || $p eq 'custom_object_variables' ) {
			$data_vals{'data'} .= "\n  <prop name=\"$name\"><![CDATA[$values{$name}]]>\n  </prop>";
		    }
		}
	    }
	}
    }
    if ( $data_vals{'data'} ) {
	$data_vals{'data'} = qq(<?xml version="1.0" encoding="iso-8859-1" ?>
<data>$data_vals{'data'}
</data>);
    }
    return %data_vals;
}

#
############################################################################
# Commands
#

sub commands() {
    my @errors     = ();
    my @objs       = $root->findnodes("//command");
    my $cnt        = 0;
    my $add_cnt    = 0;
    my $update_cnt = 0;
    foreach my $obj (@objs) {
	my %name_vals = ();
	$cnt++;
	my $command_name = $obj->findnodes('prop[@name="name"]') || '-- unknown --';
	my @siblings = $obj->getChildnodes();
	foreach my $node (@siblings) {
	    if ( $node->hasAttributes() ) {
		my $property = $node->getAttribute('name');
		my $value    = $node->textContent;
		$name_vals{$property} = $value;
		if ( $property eq 'command_line' ) {
		    if ( $name_vals{'command_line'} =~ /\$(USER\d+)\$\/(\S+)\s/ ) {
			my ( $res, $file ) = ( $1, $2 );
			$res = lc($res);
			unless ( $objects{'resources'}{$res} ) {
			    push @errors, "Resource value \"$res\" for plugin does not exist, for command definition \"$command_name\".";
			}
			unless ( -e "$objects{'resources'}{$res}/$file" ) {
			    push @errors, "Plugin \"$objects{'resources'}{$res}/$2\" does not exist, for command definition \"$command_name\".";
			}
		    }
		}
	    }
	}

	## unless ($errors[0]) {
	my %values = data_prep( 'commands', \%name_vals );
	( $values{'comment'} = $name_vals{'comment'} ) =~ s/^\s+|\s+$//g if defined $name_vals{'comment'};
	foreach my $val ( keys %{ $objects{'commands'} } ) {
	    ## FIX THIS:  case insensitivity in matching command names is probably a bad idea, leading to confusion
	    if ( $val =~ /^$values{'name'}$/i ) {
		$objects{'commands'}{ $values{'name'} } = $objects{'commands'}{$val};
	    }
	}
	if ( $objects{'commands'}{ $values{'name'} } ) {
	    if ( $overwrite == 1 ) {
		my $result = StorProc->update_obj( 'commands', 'name', $values{'name'}, \%values );
		if ( $result =~ /^Error/ ) {
		    push @errors, "Error: $result; continuing ...";
		}
		else {
		    $update_cnt++;
		}
	    }
	}
	else {
	    my @db_vals = split( /,/, $db_values{'commands'} );
	    my @values = ( \undef );
	    foreach my $val (@db_vals) { push @values, $values{$val} }
	    my $id = StorProc->insert_obj_id( 'commands', \@values, 'command_id' );
	    if ( $id =~ /^Error/ ) {
		push @errors, "Error: $id; continuing ...;";
	    }
	    else {
		$objects{'commands'}{ $values{'name'} } = $id;
		$add_cnt++;
	    }
	}
	## }
    }

    my $error_cnt = scalar(@errors);
    $objects_read += $cnt;
    push @messages,
	"Commands: $cnt read, $add_cnt added, $update_cnt updated"
      . ( $error_cnt == 0 ? '' : ", $error_cnt error" . ( $error_cnt == 1 ? '' : 's' ) )
      . " (overwrite existing = $ov{$overwrite}).";
    return @errors;
}

#
############################################################################
# Time periods
#

sub timeperiods() {
    my @errors     = ();
    my $cnt        = 0;
    my $add_cnt    = 0;
    my $update_cnt = 0;
    my $result     = undef;

    eval {
	my $parser = XML::LibXML->new(
	    ext_ent_handler => sub { die "INVALID FORMAT: external entity references are not allowed in XML documents.\n" },
	    no_network      => 1
	);
	my $tree = undef;
	eval {
	    $tree = $parser->parse_file("$file");
	};
	if ($@) {
	    my ( $package, $file, $line ) = caller;
	    print STDERR $@, " called from $file line $line.";
	    my $error = undef;
	    ## FIX LATER:  HTMLifying here, along with embedded markup in $error, is something of a hack,
	    ## as it presumes a context not in evidence.  But it's necessary in the browser context.
	    $@ = HTML::Entities::encode($@);
	    $@ =~ s/\n/<br>/g;
	    if ( $@ =~ s/external entity callback died: // || $@ =~ /external entity references are not allowed/ ) {
		## First undo the effect of the croak() call in XML::LibXML.
		$@ =~ s/ at \S+ line \d+<br>//;
		$error = "Bad XML string (timeperiods):<br>$@";
	    }
	    elsif ( $@ =~ /Attempt to load network entity/ ) {
		$error = "Bad XML string (timeperiods):<br>INVALID FORMAT: non-local entity references are not allowed in XML documents.<pre>$@</pre>";
	    }
	    else {
		$error = "Bad XML string (timeperiods):<br>$@ called from $file line $line.";
	    }
	    push @errors, $error;
	    $@ = '';
	}
	else {
	    my $root       = $tree->getDocumentElement;
	    my @objs       = $root->findnodes("//time_period");
	    my %tp_exclude = ();
	    my %overwrite  = ();

	    foreach my $obj (@objs) {
		my %name_vals = ();
		$cnt++;
		my @siblings = $obj->getChildnodes();
		foreach my $node (@siblings) {
		    if ( $node->hasAttributes() ) {
			my $property = $node->getAttribute('name');
			my $value    = $node->textContent;
			$name_vals{$property} = $value;
		    }
		}
		my %values = data_prep( 'time_periods', \%name_vals );
		( $values{'comment'} = $name_vals{'comment'} ) =~ s/^\s+|\s+$//g if defined $name_vals{'comment'};
		my $tp_name = $values{'name'};

		# FIX THIS:  case insensitivity here and for other objects is likely to lead to massive confusion,
		# partly because it is not handled correctly in subsequent code below and will result in either
		# database corruption or update errors
		foreach my $val ( keys %{ $objects{'time_periods'} } ) {
		    ## FIX THIS:  case insensitivity in matching time period names is probably a bad idea, leading to confusion
		    if ( $val =~ /^$tp_name$/i ) {
			$objects{'time_periods'}{$tp_name} = $objects{'time_periods'}{$val};
		    }
		}
		if ( $objects{'time_periods'}{$tp_name} ) {
		    if ( $overwrite == 1 ) {
			$result = StorProc->update_obj( 'time_periods', 'name', $tp_name, \%values );
			if ( $result =~ /^Error/ ) {
			    push @errors, "Error: $result (time period \"$tp_name\"); continuing ...";
			}
			else {
			    $overwrite{$tp_name} = 1;
			    $update_cnt++;
			}
		    }
		}
		else {
		    my @db_vals = split( /,/, $db_values{'time_periods'} );
		    my @values = ( \undef );
		    foreach my $val (@db_vals) { push @values, $values{$val}; }
		    my $id = StorProc->insert_obj_id( 'time_periods', \@values, 'timeperiod_id' );
		    if ( $id =~ /^Error/ ) {
			push @errors, "Error: $id (time period \"$tp_name\"); continuing ...";
		    }
		    else {
			$objects{'time_periods'}{$tp_name} = $id;
			$overwrite{$tp_name} = 1;
			$add_cnt++;
		    }
		}
		if ( $objects{'time_periods'}{$tp_name} && $overwrite{$tp_name} ) {
		    $result = StorProc->delete_all( 'time_period_property', 'timeperiod_id', $objects{'time_periods'}{$tp_name} );
		    if ( $result =~ /^Error/ ) {
			push @errors, "Error: $result (time period \"$tp_name\"); continuing ...";
		    }
		    $result = StorProc->delete_all( 'time_period_exclude', 'timeperiod_id', $objects{'time_periods'}{$tp_name} );
		    if ( $result =~ /^Error/ ) {
			push @errors, "Error: $result (time period \"$tp_name\"); continuing ...";
		    }

		    $tp_exclude{$tp_name} = $name_vals{'exclude'};

		    my @db_vals = split( /,/, $db_values{'time_periods'} );
		    foreach my $val (@db_vals) { delete $name_vals{$val}; }

		    # Note:  In the future, we might also want to add code here to
		    # also process "use" and "require" directives for time periods.
		    delete $name_vals{'exclude'};
		    delete $name_vals{'use'};
		    delete $name_vals{'require'};

		    foreach my $dayrule ( keys %name_vals ) {
			my @values = ();
			$values[0] = $objects{'time_periods'}{$tp_name};
			$values[1] = $dayrule;
			$values[2] = 'exception';
			$values[2] = 'weekday' if $dayrule =~ /^\S+day$/;
			if ( $name_vals{$dayrule} =~ /(.*?)[;#](.*)/ ) {
			    $values[3] = $1;
			    $values[4] = $2;
			}
			else {
			    $values[3] = $name_vals{$dayrule};
			    $values[4] = '';
			}
			my $result = StorProc->insert_obj( 'time_period_property', \@values );
			if ( $result =~ /error/i ) {
			    push @errors, "Error: $result (time period \"$tp_name\"); continuing ...";
			}
		    }
		}
	    }

	    # We have to wait until now to populate all time_period_exclude rows, so we
	    # know we should have timeperiod_id values for all referenced time periods.

	    foreach my $tp_name ( keys %tp_exclude ) {
		my @elist = defined( $tp_exclude{$tp_name} ) ? split( /,/, $tp_exclude{$tp_name} ) : ();
		foreach my $excluded_tp_name (@elist) {
		    if ( $objects{'time_periods'}{$excluded_tp_name} ) {
			my @values = ( $objects{'time_periods'}{$tp_name}, $objects{'time_periods'}{$excluded_tp_name} );
			$result = StorProc->insert_obj( 'time_period_exclude', \@values );
			if ( $result =~ /error/i ) {
			    push @errors, "Error: $result (time period \"$tp_name\"); continuing ...";
			}
		    }
		    else {
			push @errors,
			  "Error: time period \"$tp_name\" exclusion of time period \"$excluded_tp_name\" has not been saved; continuing ...";
		    }
		}
	    }
	}
    };    # end eval
    if ($@) { push @errors, $@ }

    my $error_cnt = scalar(@errors);
    $objects_read += $cnt;
    push @messages,
	"Time periods: $cnt read, $add_cnt added, $update_cnt updated"
      . ( $error_cnt == 0 ? '' : ", $error_cnt error" . ( $error_cnt == 1 ? '' : 's' ) )
      . " (overwrite existing = $ov{$overwrite}).";
    return @errors;
}

#
############################################################################
# Host templates
#

sub host_templates() {
    my @errors     = ();
    my $cnt        = 0;
    my $add_cnt    = 0;
    my $update_cnt = 0;

    eval {
	my $parser = XML::LibXML->new(
	    ext_ent_handler => sub { die "INVALID FORMAT: external entity references are not allowed in XML documents.\n" },
	    no_network      => 1
	);
	my $tree = undef;
	eval {
	    $tree = $parser->parse_file("$file");
	};
	if ($@) {
	    my ( $package, $file, $line ) = caller;
	    print STDERR $@, " called from $file line $line.";
	    my $error = undef;
	    ## FIX LATER:  HTMLifying here, along with embedded markup in $error, is something of a hack,
	    ## as it presumes a context not in evidence.  But it's necessary in the browser context.
	    $@ = HTML::Entities::encode($@);
	    $@ =~ s/\n/<br>/g;
	    if ( $@ =~ s/external entity callback died: // || $@ =~ /external entity references are not allowed/ ) {
		## First undo the effect of the croak() call in XML::LibXML.
		$@ =~ s/ at \S+ line \d+<br>//;
		$error = "Bad XML string (host_templates):<br>$@";
	    }
	    elsif ( $@ =~ /Attempt to load network entity/ ) {
		$error = "Bad XML string (host_templates):<br>INVALID FORMAT: non-local entity references are not allowed in XML documents.<pre>$@</pre>";
	    }
	    else {
		$error = "Bad XML string (host_templates):<br>$@ called from $file line $line.";
	    }
	    push @errors, $error;
	    $@ = '';
	}
	else {
	    my $root = $tree->getDocumentElement;
	    my @objs = $root->findnodes("//host_template");
	    foreach my $obj (@objs) {
		my %name_vals = ();
		$cnt++;
		my $db_update          = 1;
		my $host_template_name = $obj->findnodes('prop[@name="name"]') || '-- unknown --';
		my @siblings           = $obj->getChildnodes();
		foreach my $node (@siblings) {
		    if ( $node->hasAttributes() ) {
			my $property = $node->getAttribute('name');
			my $value    = $node->textContent;
			if ( $value eq '0' ) { $value = "-zero-" }
			$name_vals{$property} = $value;
			if ($value) {
			    if ( $property =~ /^check_command$|^event_handler$/ ) {
				if ( $objects{'commands'}{$value} ) {
				    $name_vals{$property} = $objects{'commands'}{$value};
				}
				else {
				    $db_update = 0;
				    push @errors,
				      "Command definition \"$value\" for \"$property\" does not exist for host template \"$host_template_name\".";
				}
			    }
			    if ( $property =~ /period/ ) {
				if ( $objects{'time_periods'}{$value} ) {
				    $name_vals{$property} = $objects{'time_periods'}{$value};
				}
				else {
				    $db_update = 0;
				    push @errors,
    "Time period definition \"$value\" for \"$property\" does not exist for host template \"$host_template_name\".";
				}
			    }
			}
		    }
		}
		unless ( $errors[0] ) {
		    my %values = data_prep( 'host_templates', \%name_vals );
		    ( $values{'comment'} = $name_vals{'comment'} ) =~ s/^\s+|\s+$//g if defined $name_vals{'comment'};
		    foreach my $val ( keys %{ $objects{'host_templates'} } ) {
			## FIX THIS:  case insensitivity in matching host template names is probably a bad idea, leading to confusion
			if ( $val =~ /^$values{'name'}$/i ) {
			    $objects{'host_templates'}{ $values{'name'} } = $objects{'host_templates'}{$val};
			}
		    }
		    if ( $objects{'host_templates'}{ $values{'name'} } ) {
			if ( $overwrite == 1 ) {
			    my $result = StorProc->update_obj( 'host_templates', 'name', $values{'name'}, \%values );
			    if ( $result =~ /^Error/ ) {
				push @errors, "Error: $result; continuing ...";
			    }
			    else {
				$update_cnt++;
			    }
			}
		    }
		    else {
			my @db_vals = split( /,/, $db_values{'host_templates'} );
			my @values = ( \undef );
			foreach my $val (@db_vals) { push @values, $values{$val} }
			my $id = StorProc->insert_obj_id( 'host_templates', \@values, 'hosttemplate_id' );
			if ( $id =~ /^Error/ ) {
			    push @errors, "Error: $id; continuing ...";
			}
			else {
			    $objects{'host_templates'}{ $values{'name'} } = $id;
			    $add_cnt++;
			}
		    }
		}
	    }
	}
    };    # end eval
    if ($@) { push @errors, $@ }

    my $error_cnt = scalar(@errors);
    $objects_read += $cnt;
    push @messages,
	"Host templates: $cnt read, $add_cnt added, $update_cnt updated"
      . ( $error_cnt == 0 ? '' : ", $error_cnt error" . ( $error_cnt == 1 ? '' : 's' ) )
      . " (overwrite existing = $ov{$overwrite}).";
    return @errors;
}

#
############################################################################
# Extended Host Info
#

sub hostextinfo_templates() {
    my @errors     = ();
    my $cnt        = 0;
    my $add_cnt    = 0;
    my $update_cnt = 0;
    my @objs       = $root->findnodes("//extended_host_info_template");
    foreach my $obj (@objs) {
	my %name_vals = ();
	$cnt++;
	my @siblings = $obj->getChildnodes();
	foreach my $node (@siblings) {
	    if ( $node->hasAttributes() ) {
		my $property = $node->getAttribute('name');
		my $value    = $node->textContent;
		$name_vals{$property} = $value;
	    }
	}
	my %values = data_prep( 'extended_host_info_templates', \%name_vals );
	( $values{'comment'} = $name_vals{'comment'} ) =~ s/^\s+|\s+$//g if defined $name_vals{'comment'};
	foreach my $val ( keys %{ $objects{'extended_host_info_templates'} } ) {
	    ## FIX THIS:  case insensitivity in matching host extended info template names is probably a bad idea, leading to confusion
	    if ( $val =~ /^$values{'name'}$/i ) {
		$objects{'extended_host_info_templates'}{ $values{'name'} } = $objects{'extended_host_info_templates'}{$val};
	    }
	}
	if ( $objects{'extended_host_info_templates'}{ $values{'name'} } ) {
	    if ( $overwrite == 1 ) {
		my $result = StorProc->update_obj( 'extended_host_info_templates', 'name', $values{'name'}, \%values );
		if ( $result =~ /^Error/ ) {
		    push @errors, "Error: $result; continuing ...";
		}
		else {
		    $update_cnt++;
		}
	    }
	}
	else {
	    my @db_vals = split( /,/, $db_values{'extended_host_info_templates'} );
	    my @values = ( \undef );
	    foreach my $val (@db_vals) { push @values, $values{$val} }
	    my $id = StorProc->insert_obj_id( 'extended_host_info_templates', \@values, 'hostextinfo_id' );
	    if ( $id =~ /^Error/ ) {
		push @errors, "Error: $id; continuing ...";
	    }
	    else {
		$objects{'extended_host_info_templates'}{ $values{'name'} } = $id;
		$add_cnt++;
	    }
	}
    }

    my $error_cnt = scalar(@errors);
    $objects_read += $cnt;
    push @messages,
	"Extended host info templates: $cnt read, $add_cnt added, $update_cnt updated"
      . ( $error_cnt == 0 ? '' : ", $error_cnt error" . ( $error_cnt == 1 ? '' : 's' ) )
      . " (overwrite existing = $ov{$overwrite}).";
    return @errors;
}

#
############################################################################
# Service Templates
#

sub service_templates() {
    my %parent     = ();
    my @errors     = ();
    my $cnt        = 0;
    my $add_cnt    = 0;
    my $update_cnt = 0;
    my @objs       = $root->findnodes("//service_template");
    foreach my $obj (@objs) {
	my %name_vals = ();
	$cnt++;
	my $db_update = 1;

	# We must get the service template name early so we have it ready for use no matter where it appears in sequence.
	my $service_template_name = $obj->findnodes('prop[@name="name"]') || '-- unknown --';
	my @siblings = $obj->getChildnodes();
	foreach my $node (@siblings) {
	    if ( $node->hasAttributes() ) {
		my $property = $node->getAttribute('name');
		my $value    = $node->textContent;
		if ( $value eq '0' ) { $value = "-zero-" }
		$name_vals{$property} = $value;
		if ($value) {
		    if ( $property =~ /^check_command$|^event_handler$/ ) {
			if ( $objects{'commands'}{$value} ) {
			    $name_vals{$property} = $objects{'commands'}{$value};
			}
			else {
			    $db_update = 0;
			    delete $parent{$service_template_name};
			    push @errors,
			      "Command definition \"$value\" for \"$property\" does not exist for service template \"$service_template_name\".";
			}
		    }
		    if ( $property =~ /period/ ) {
			if ( $objects{'time_periods'}{$value} ) {
			    $name_vals{$property} = $objects{'time_periods'}{$value};
			}
			else {
			    $db_update = 0;
			    delete $parent{$service_template_name};
			    push @errors,
"Time period definition \"$value\" for \"$property\" does not exist for service template \"$service_template_name\".";
			}
		    }
		}
		if ( $property eq 'template' && $db_update == 1 ) {
		    $parent{$service_template_name} = $value;
		    $name_vals{'parent_id'} = '';
		    delete $name_vals{'template'};
		}
	    }
	}
	if ( !scalar(%name_vals) ) {

	    # FIX THIS:  Some of our current distributed profiles contain empty service templates.
	    # Until we fix that, we will simply ignore this condition.  Even afterward, we need to
	    # decide whether this should be considered an error or whether we should simply ignore
	    # it as being unimportant.
	    # push @errors, "Found an empty service template.";
	}
	unless ( $errors[0] || !scalar(%name_vals) ) {
	    my %values = data_prep( 'service_templates', \%name_vals );
	    ( $values{'comment'} = $name_vals{'comment'} ) =~ s/^\s+|\s+$//g if defined $name_vals{'comment'};
	    foreach my $val ( keys %{ $objects{'service_templates'} } ) {
		## FIX THIS:  case insensitivity in matching service template names is probably a bad idea, leading to confusion
		if ( $val =~ /^$values{'name'}$/i ) {
		    $objects{'service_templates'}{ $values{'name'} } = $objects{'service_templates'}{$val};
		}
	    }
	    if ( $objects{'service_templates'}{ $values{'name'} } ) {
		if ( $overwrite == 1 ) {
		    my $result = StorProc->update_obj( 'service_templates', 'name', $values{'name'}, \%values );
		    if ( $result =~ /^Error/ ) {
			push @errors, "Error: $result; continuing ...";
		    }
		    else {
			$update_cnt++;
		    }
		}
		else {

		    # If we're not overwriting, it would be inappropriate to update the parent_id link below.
		    delete $parent{ $values{'name'} };
		}
	    }
	    else {
		my @db_vals = split( /,/, $db_values{'service_templates'} );
		my @values = ( \undef );
		foreach my $val (@db_vals) { push @values, $values{$val} }
		my $id = StorProc->insert_obj_id( 'service_templates', \@values, 'servicetemplate_id' );
		if ( $id =~ /^Error/ ) {
		    push @errors, "Error: $id; continuing ...";
		}
		else {
		    $objects{'service_templates'}{ $values{'name'} } = $id;
		    $add_cnt++;
		}
	    }
	}
    }

    foreach my $child ( keys %parent ) {
	my %values = ( 'parent_id' => $objects{'service_templates'}{ $parent{$child} } );
	my $result = StorProc->update_obj( 'service_templates', 'name', $child, \%values );
	if ( $result =~ /^Error/ ) {
	    push @errors, "Error: $result; continuing ...";
	}
    }

    my $error_cnt = scalar(@errors);
    $objects_read += $cnt;
    push @messages,
	"Service templates: $cnt read, $add_cnt added, $update_cnt updated"
      . ( $error_cnt == 0 ? '' : ", $error_cnt error" . ( $error_cnt == 1 ? '' : 's' ) )
      . " (overwrite existing = $ov{$overwrite}).";
    return @errors;
}

#
############################################################################
# Extended Service Info
#

sub serviceextinfo_templates() {
    my @errors     = ();
    my $cnt        = 0;
    my $add_cnt    = 0;
    my $update_cnt = 0;
    my @objs       = $root->findnodes("//extended_service_info_template");
    foreach my $obj (@objs) {
	my %name_vals = ();
	$cnt++;
	my @siblings = $obj->getChildnodes();
	foreach my $node (@siblings) {
	    if ( $node->hasAttributes() ) {
		my $property = $node->getAttribute('name');
		my $value    = $node->textContent;
		$name_vals{$property} = $value;
	    }
	}
	my %values = data_prep( 'extended_service_info_templates', \%name_vals );
	( $values{'comment'} = $name_vals{'comment'} ) =~ s/^\s+|\s+$//g if defined $name_vals{'comment'};
	foreach my $val ( keys %{ $objects{'extended_service_info_templates'} } ) {
	    ## FIX THIS:  case insensitivity in matching service extended info template names is probably a bad idea, leading to confusion
	    if ( $val =~ /^$values{'name'}$/i ) {
		$objects{'extended_service_info_templates'}{ $values{'name'} } = $objects{'extended_service_info_templates'}{$val};
	    }
	}
	if ( $objects{'extended_service_info_templates'}{ $values{'name'} } ) {
	    if ( $overwrite == 1 ) {
		my $result = StorProc->update_obj( 'extended_service_info_templates', 'name', $values{'name'}, \%values );
		if ( $result =~ /^Error/ ) {
		    push @errors, "Error: $result; continuing ...";
		}
		else {
		    $update_cnt++;
		}
	    }
	}
	else {
	    my @db_vals = split( /,/, $db_values{'extended_service_info_templates'} );
	    my @values = ( \undef );
	    foreach my $val (@db_vals) { push @values, $values{$val} }
	    my $id = StorProc->insert_obj_id( 'extended_service_info_templates', \@values, 'serviceextinfo_id' );
	    if ( $id =~ /^Error/ ) {
		push @errors, "Error: $id; continuing ...";
	    }
	    else {
		$objects{'extended_service_info_templates'}{ $values{'name'} } = $id;
		$add_cnt++;
	    }
	}
    }

    my $error_cnt = scalar(@errors);
    $objects_read += $cnt;
    push @messages,
	"Extended service info templates: $cnt read, $add_cnt added, $update_cnt updated"
      . ( $error_cnt == 0 ? '' : ", $error_cnt error" . ( $error_cnt == 1 ? '' : 's' ) )
      . " (overwrite existing = $ov{$overwrite}).";
    return @errors;
}

#
############################################################################
# Services
#

sub services() {
    my @errors     = ();
    my $cnt        = 0;
    my $add_cnt    = 0;
    my $update_cnt = 0;
    my @objs       = $root->findnodes("//service_name");
    foreach my $obj (@objs) {
	my @externals = ();
	my %name_vals = ();
	$cnt++;

	# Who can explain why this magical incantation works?
	my $service_name = $obj->findnodes('prop[@name="name"]') || '-- unknown --';
	my @siblings = $obj->getChildnodes();
	foreach my $node (@siblings) {
	    if ( $node->hasAttributes() ) {
		my $property = $node->getAttribute('name');
		my $value    = $node->textContent;
		if ( $value eq '0' ) { $value = "-zero-" }
		$name_vals{$property} = $value;

		# This old attempt to get the service name would only be good if the name were guaranteed
		# to pop up early in the list of sibling nodes.  Otherwise, it would still be undefined
		# when we need it in an error message.  That's why we now find the $service_name from the
		# XML stream (actually, from the corresponding DOM, above) instead.
		# if ( $property eq 'name' ) { $service_name = $value }

		if ($value) {
		    if ( $property =~ /^(?:check_command|event_handler)$/ ) {
			if ( $objects{'commands'}{$value} ) {
			    $name_vals{$property} = $objects{'commands'}{$value};
			}
			else {
			    push @errors, "Command definition \"$value\" for $property does not exist for the \"$service_name\" service.";
			}
		    }
		    elsif ( $property eq 'template' ) {
			if ( $objects{'service_templates'}{$value} ) {
			    $name_vals{$property} = $objects{'service_templates'}{$value};
			}
			else {
			    push @errors, "Service template \"$value\" does not exist for the \"$service_name\" service.";
			}
		    }
		    elsif ( $property =~ /check_period|notification_period/ ) {
			if ( $objects{'time_periods'}{$value} ) {
			    $name_vals{$property} = $objects{'time_periods'}{$value};
			}
			else {
			    push @errors, "Time periods definition \"$value\" for $property does not exist for the \"$service_name\" service.";
			}
		    }
		    elsif ( $property eq 'extinfo' ) {
			if ( $objects{'extended_service_info_templates'}{$value} ) {
			    $name_vals{$property} = $objects{'extended_service_info_templates'}{$value};
			}
			else {
			    push @errors, "Extended info definition \"$value\" does not exist for the \"$service_name\" service.";
			}
		    }
		    elsif ( $property eq 'service_external' ) {
			if ( $objects{'externals'}{$value} ) {
			    push @externals, $objects{'externals'}{$value};
			}
			else {
			    push @errors, "External definition \"$value\" does not exist for the \"$service_name\" service.";
			}
		    }
		}
	    }
	}
	unless ( $name_vals{'command_line'} ) {
	    $name_vals{'command_line'} = 'NULL';
	}
	unless ( $errors[0] ) {
	    my %values          = data_prep( 'service_names',         \%name_vals );
	    my %override_values = data_prep( 'servicename_overrides', \%name_vals );
	    foreach my $val ( keys %{ $objects{'service_names'} } ) {
		## FIX THIS:  case insensitivity in matching service names is probably a bad idea, leading to confusion
		if ( $val =~ /^$values{'name'}$/i ) {
		    $objects{'service_names'}{ $values{'name'} } = $objects{'service_names'}{$val};
		}
	    }
	    if ( $objects{'service_names'}{ $values{'name'} } ) {
		if ( $overwrite == 1 ) {
		    $update_cnt++;
		    my $result = StorProc->update_obj( 'service_names', 'name', $values{'name'}, \%values );
		    if ( $result =~ /^Error/ ) {
			push @errors, "Error: $result; continuing ...";
		    }
		    elsif (%override_values) {
			my %service          = StorProc->fetch_one( 'service_names',         'name',           $values{'name'} );
			my %service_override = StorProc->fetch_one( 'servicename_overrides', 'servicename_id', $service{'servicename_id'} );
			if ( $service_override{'servicename_id'} ) {
			    $result =
			      StorProc->update_obj( 'servicename_overrides', 'servicename_id', $service{'servicename_id'}, \%override_values );
			    if ( $result =~ /^Error/ ) {
				push @errors, "Error: $result; continuing ...";
			    }
			}
			else {
			    my @db_vals = split( /,/, $db_values{'servicename_overrides'} );
			    my @values = ( $service{'servicename_id'} );
			    foreach my $val (@db_vals) {
				push @values, $override_values{$val};
			    }
			    my $result = StorProc->insert_obj( 'servicename_overrides', \@values );
			    if ( $result =~ /^Error/ ) {
				push @errors, "Error: $result; continuing ...";
			    }
			}
		    }
		    $result = StorProc->delete_all( 'external_service_names', 'servicename_id', $objects{'service_names'}{ $values{'name'} } );
		    if ( $result =~ /^Error/ ) { push @errors, $result }
		    foreach my $eid (@externals) {
			my @values = ( $eid, $objects{'service_names'}{ $values{'name'} } );
			my $result = StorProc->insert_obj( 'external_service_names', \@values );
			if ( $result =~ /^Error/ ) {
			    push @errors, "Error: $result; continuing ...";
			}
		    }

		}
	    }
	    else {
		my @db_vals = split( /,/, $db_values{'service_names'} );
		my @values = ( \undef );
		foreach my $val (@db_vals) { push @values, $values{$val} }
		unless ( $monarch_ver eq '0.97a' ) {
		    pop @values;
		    push @values, $empty_data;
		}
		my $id = StorProc->insert_obj_id( 'service_names', \@values, 'servicename_id' );
		if ( $id =~ /^Error/ ) {
		    push @errors, "Error: $id; continuing ... $db_values{'service_names'}";
		}
		else {
		    if (%override_values) {
			my @db_vals = split( /,/, $db_values{'servicename_overrides'} );
			@values = ($id);
			foreach my $val (@db_vals) {
			    push @values, $override_values{$val};
			}
			my $result = StorProc->insert_obj( 'servicename_overrides', \@values );
			if ( $result =~ /^Error/ ) {
			    push @errors, "Error: $result; continuing ...";
			}
		    }
		    $objects{'service_names'}{ $values{'name'} } = $id;
		    $add_cnt++;
		    foreach my $eid (@externals) {
			my @values = ( $eid, $id );
			my $result = StorProc->insert_obj( 'external_service_names', \@values );
			if ( $result =~ /^Error/ ) {
			    push @errors, "Error: $result; continuing ...";
			}
		    }
		}
	    }
	}
    }

    my $error_cnt = scalar(@errors);
    $objects_read += $cnt;
    push @messages,
	"Services: $cnt read, $add_cnt added, $update_cnt updated"
      . ( $error_cnt == 0 ? '' : ", $error_cnt error" . ( $error_cnt == 1 ? '' : 's' ) )
      . " (overwrite existing = $ov{$overwrite}).";
    return @errors;
}

#
############################################################################
# Service Profiles
#

sub service_profiles() {
    my @errors     = ();
    my @services   = ();
    my $cnt        = 0;
    my $add_cnt    = 0;
    my $update_cnt = 0;
    local $_;

    my @objs = $root->findnodes("//service_profile");
    foreach my $obj (@objs) {
	my %name_vals = ();
	$cnt++;
	my %services             = ();
	my $spid                 = undef;
	my $service_profile_name = $obj->findnodes('prop[@name="name"]') || '-- unknown --';
	my @siblings             = $obj->getChildnodes();
	foreach my $node (@siblings) {
	    if ( $node->hasAttributes() ) {
		my $property = $node->getAttribute('name');
		my $value    = $node->textContent;
		$name_vals{$property} = $value;
		if ( $property eq 'name' ) { $service_profile_name = $value }
		if ( $property eq 'service' ) {
		    if ( $objects{'service_names'}{$value} ) {
			$services{ $objects{'service_names'}{$value} } = 1;
		    }
		    else {
			push @messages, "Service definition \"$value\" does not exist for service profile \"$service_profile_name\".";
		    }
		}
	    }
	}
	foreach my $val ( keys %{ $objects{'profiles_service'} } ) {
	    ## FIX THIS:  case insensitivity in matching service profile names is probably a bad idea, leading to confusion
	    if ( $val =~ /^$name_vals{'name'}$/i ) {
		$objects{'profiles_service'}{ $name_vals{'name'} } = $objects{'profiles_service'}{$val};
	    }
	}
	if ( $objects{'profiles_service'}{ $name_vals{'name'} } ) {
	    push @messages, "Service profile \"$service_profile_name\" already exists.";
	    if ( $overwrite == 1 ) {
		my %vals = ( 'description' => $name_vals{'description'} );
		my $result = StorProc->update_obj( 'profiles_service', 'name', $name_vals{'name'}, \%vals );
		if ( $result =~ /^Error/ ) {
		    push @errors, "Error: $result; continuing ...";
		}
		else {
		    $update_cnt++;
		}
	    }
	}
	else {
	    my @values = ( \undef, $name_vals{'name'}, $name_vals{'description'} );
	    unless ( $monarch_ver eq '0.97a' ) { push @values, $empty_data }
	    my $id = StorProc->insert_obj_id( 'profiles_service', \@values, 'serviceprofile_id' );
	    if ( $id =~ /^Error/ ) {
		push @errors, "Error: $id; continuing ...";
	    }
	    else {
		$add_cnt++;
		$objects{'profiles_service'}{ $name_vals{'name'} } = $id;
	    }
	}
	my %where = ( 'serviceprofile_id' => $objects{'profiles_service'}{ $name_vals{'name'} } );
	my @snids = StorProc->fetch_list_where( 'serviceprofile', 'servicename_id', \%where );
	foreach my $snid ( keys %services ) {
	    my $exists = 0;
	    foreach (@snids) {
		if ( $_ eq $snid ) { $exists = 1 }
	    }
	    unless ($exists) {
		my @vals = ( $snid, $objects{'profiles_service'}{ $name_vals{'name'} } );
		my $result = StorProc->insert_obj( 'serviceprofile', \@vals );
		if ( $result =~ /^Error/ ) {
		    push @errors, "Error: $result; continuing ...";
		}
	    }
	}
    }

    my $error_cnt = scalar(@errors);
    $objects_read += $cnt;
    push @messages,
	"Service profiles: $cnt read, $add_cnt added, $update_cnt updated"
      . ( $error_cnt == 0 ? '' : ", $error_cnt error" . ( $error_cnt == 1 ? '' : 's' ) )
      . " (overwrite existing = $ov{$overwrite}).";
    return @errors;
}

#
############################################################################
# Import Externals - used for both host or service externals
#

sub import_externals($) {
    my $obj_type    = shift;
    my @objs        = ();
    my @errors      = ();
    my $read_cnt    = 0;
    my $added_cnt   = 0;
    my $updated_cnt = 0;

    if ( $obj_type =~ /^(?:host|service)$/ ) {
	my $node_str = '//' . $obj_type . '_external';
	@objs     = $root->findnodes($node_str);
	$read_cnt = scalar @objs;
    }
    else {
	push @errors, "Error: invalid object type [$obj_type] passed to import_externals(); continuing ...";
    }

    foreach my $obj (@objs) {
	my %name_vals = ();
	my @siblings  = $obj->getChildnodes();
	foreach my $node (@siblings) {
	    if ( $node->hasAttributes() ) {
		my $property = $node->getAttribute('name');
		my $value    = $node->textContent;
		$name_vals{$property} = $value;
	    }
	}
	if ( $objects{'externals'}{ $name_vals{'name'} } ) {
	    if ( $overwrite == 1 ) {
		my %values = ( 'type' => $name_vals{'type'}, 'display' => $name_vals{'data'} );
		my $result = StorProc->update_obj( 'externals', 'name', $name_vals{'name'}, \%values );
		if ( $result =~ /^Error/ ) {
		    push @errors, "Error: $result; continuing ...";
		}
		else {
		    $updated_cnt++;
		    $externals{ $objects{'externals'}{ $name_vals{'name'} } } = $name_vals{'data'};
		}
	    }
	    else {
		if ( not defined $externals{ $objects{'externals'}{ $name_vals{'name'} } } ) {
		    my %e = StorProc->fetch_one( 'externals', 'external_id', $objects{'externals'}{ $name_vals{'name'} } );
		    $externals{ $objects{'externals'}{ $name_vals{'name'} } } = $e{'display'};
		}
		if ( $externals{ $objects{'externals'}{ $name_vals{'name'} } } ne $name_vals{'data'} ) {
		    push @messages,
"\u$obj_type external \"$name_vals{'name'}\" already exists <span class=error_standout>(though with different content)</span>.";
		    push @messages, "Action: new value of $obj_type external \"$name_vals{'name'}\" was ignored.";
		}
		else {
		    push @messages, "\u$obj_type external \"$name_vals{'name'}\" already exists.";
		}
	    }
	}
	else {
	    my @values = ( \undef, $name_vals{'name'}, '', $name_vals{'type'}, $name_vals{'data'}, '' );
	    my $id = StorProc->insert_obj_id( 'externals', \@values, 'external_id' );
	    if ( $id =~ /^Error/ ) {
		push @errors, "Error: $id; continuing ...";
	    }
	    else {
		$objects{'externals'}{ $name_vals{'name'} } = $id;
		$added_cnt++;
		$externals{$id} = $name_vals{'data'};
	    }
	}
    }

    my $error_cnt = scalar(@errors);
    $objects_read += $read_cnt;
    push @messages,
	"\u$obj_type externals: $read_cnt read, $added_cnt added, $updated_cnt updated"
      . ( $error_cnt == 0 ? '' : ", $error_cnt error" . ( $error_cnt == 1 ? '' : 's' ) )
      . " (overwrite existing = $ov{$overwrite}).";
    return @errors;
}

#
############################################################################
# Host Profiles
#

sub host_profiles() {
    my @errors     = ();
    my $cnt        = 0;
    my $add_cnt    = 0;
    my $update_cnt = 0;
    local $_;

    my @objs = $root->findnodes("//host_profile");
    foreach my $obj (@objs) {
	my %name_vals = ();
	$cnt++;
	my %host_externals    = ();
	my %service_profiles  = ();
	my $host_profile_name = $obj->findnodes('prop[@name="name"]') || '-- unknown --';
	my @siblings          = $obj->getChildnodes();
	foreach my $node (@siblings) {
	    if ( $node->hasAttributes() ) {
		my $property = $node->getAttribute('name');
		my $value    = $node->textContent;
		## Note that you can have more than one host_external property or service_profile property for the same host profile.
		$name_vals{$property} = $value;
		if ( $property eq 'name' ) { $host_profile_name = $value }
		if ( $property eq 'host_template' ) {
		    if ( $objects{'host_templates'}{$value} ) {
			$name_vals{'host_template_id'} = $objects{'host_templates'}{$value};
		    }
		    else {
			push @errors, "Host template definition \"$value\" does not exist for host profile \"$host_profile_name\".";
		    }
		    delete $name_vals{$property};
		}
		unless ( $errors[0] ) {
		    if ( $property eq 'extended_host_info_templates' ) {
			if ( $objects{'extended_host_info_templates'}{$value} ) {
			    $name_vals{$property} = $objects{'extended_host_info_templates'}{$value};
			}
			else {
			    push @messages, "Extended info definition \"$value\" does not exist for host profile \"$host_profile_name\".";
			    push @messages, "Action: \"$value\" ignored.";
			}
			delete $name_vals{$property};
		    }
		    if ( $property eq 'host_external' ) {
			if ( $objects{'externals'}{$value} ) {
			    $host_externals{ $objects{'externals'}{$value} } = $value;
			}
			else {
			    push @messages, "Host external \"$value\" definition does not exist for host profile \"$host_profile_name\".";
			    push @messages, "Action: host external \"$value\" was ignored.";
			}
			delete $name_vals{$property};
		    }
		    if ( $property eq 'service_profile' ) {
			if ( $objects{'profiles_service'}{$value} ) {
			    if ( $monarch_ver eq '0.97a' ) {
				$name_vals{'serviceprofile_id'} = $objects{'profiles_service'}{$value};
			    }
			    else {
				$service_profiles{ $objects{'profiles_service'}{$value} } = $value;
			    }
			}
			else {
			    push @messages, "Service profile definition \"$value\" does not exist for host profile \"$host_profile_name\".";
			    push @messages, "Action: \"$value\" ignored.";
			}
			delete $name_vals{$property};
		    }
		}
	    }
	}
	unless ( $errors[0] ) {
	    my %values = data_prep( 'profiles_host', \%name_vals );
	    foreach my $val ( keys %{ $objects{'profiles_host'} } ) {
		## FIX THIS:  case insensitivity in matching host profile names is probably a bad idea, leading to confusion
		if ( $val =~ /^$values{'name'}$/i ) {
		    $objects{'profiles_host'}{ $values{'name'} } = $objects{'profiles_host'}{$val};
		}
	    }
	    if ( $objects{'profiles_host'}{ $values{'name'} } ) {
		if ( $overwrite == 1 ) {
		    my $result = StorProc->update_obj( 'profiles_host', 'name', $values{'name'}, \%values );
		    if ( $result =~ /^Error/ ) {
			push @errors, "Error: $result; continuing ...";
		    }
		    else {
			$update_cnt++;
			my $result =
			  StorProc->delete_all( 'external_host_profile', 'hostprofile_id', $objects{'profiles_host'}{ $values{'name'} } );
			if ( $result =~ /^Error/ ) { push @errors, $result }
			foreach my $eid ( keys %host_externals ) {
			    my @values = ( $eid, $objects{'profiles_host'}{ $values{'name'} } );
			    my $result = StorProc->insert_obj( 'external_host_profile', \@values );
			    if ( $result =~ /^Error/ ) {
				push @errors,
"Error: cannot assign host external \"$host_externals{$eid}\" to host profile \"$host_profile_name\" ($result); continuing ...";
			    }
			}

		    }
		}
	    }
	    else {
		my @db_vals = split( /,/, $db_values{'profiles_host'} );
		my @values = ( \undef );
		foreach my $val (@db_vals) { push @values, $values{$val} }
		unless ( $monarch_ver eq '0.97a' ) { push @values, $empty_data }
		my $id = StorProc->insert_obj_id( 'profiles_host', \@values, 'hostprofile_id' );
		if ( $id =~ /^Error/ ) {
		    push @errors, "Error: $id; continuing ...";
		}
		else {
		    $objects{'profiles_host'}{ $values{'name'} } = $id;
		    $add_cnt++;
		    foreach my $eid ( keys %host_externals ) {
			my @values = ( $eid, $id );
			my $result = StorProc->insert_obj( 'external_host_profile', \@values );
			if ( $result =~ /^Error/ ) {
			    push @errors,
"Error: cannot assign host external \"$host_externals{$eid}\" to host profile \"$host_profile_name\" ($result); continuing ...";
			}
		    }
		}
	    }
	    unless ( $monarch_ver eq '0.97a' ) {
		my %where = ( 'hostprofile_id' => $objects{'profiles_host'}{ $values{'name'} } );
		my @spids = StorProc->fetch_list_where( 'profile_host_profile_service', 'serviceprofile_id', \%where );
		foreach my $spid ( keys %service_profiles ) {
		    my $exists = 0;
		    foreach (@spids) {
			if ( $_ eq $spid ) { $exists = 1 }
		    }
		    unless ($exists) {
			my @vals = ( $objects{'profiles_host'}{ $name_vals{'name'} }, $spid );
			my $result = StorProc->insert_obj( 'profile_host_profile_service', \@vals );
			if ( $result =~ /^Error/ ) {
			    push @errors,
"Error: cannot assign service profile \"$service_profiles{$spid}\" to host profile \"$host_profile_name\" ($result); continuing ...";
			}
		    }
		}
	    }

	}
    }

    my $error_cnt = scalar(@errors);
    $objects_read += $cnt;
    push @messages,
	"Host profile: $cnt read, $add_cnt added, $update_cnt updated"
      . ( $error_cnt == 0 ? '' : ", $error_cnt error" . ( $error_cnt == 1 ? '' : 's' ) )
      . " (overwrite existing = $ov{$overwrite}).";
    return @errors;
}

#
# Performance configuration
#

sub parse_perfconfig_xml(@) {
    my $xmlfile    = $_[0];
    my $overwrite  = $_[1];
    my @errors     = ();
    my $data       = '';
    my $end_config = undef;

    if ( !open( XMLFILE, '<', $xmlfile ) ) {
	push @errors, "ERROR: Can't open XML file $xmlfile ($!)";
    }
    else {
	while ( my $line = <XMLFILE> ) {
	    $line =~ s/\r\n/\n/;
	    $data .= $line;
	}
	close(XMLFILE);
    }
    my (
	$host,    $service,         $type,            $enable,   $parseregx_first, $service_regx, $label,
	$rrdname, $rrdcreatestring, $rrdupdatestring, $graphcgi, $perfidstring,    $parseregx
    ) = ();
    if ($data) {
	push @messages, "Performance configuration $xmlfile found.";
	eval {
	    my $parser = XML::LibXML->new(
		ext_ent_handler => sub { die "INVALID FORMAT: external entity references are not allowed in XML documents.\n" },
		no_network      => 1
	    );
	    my $doc = undef;
	    eval {
		$doc = $parser->parse_string($data);
	    };
	    if ($@) {
		my ( $package, $file, $line ) = caller;
		print STDERR $@, " called from $file line $line.";
		my $error = undef;
		## FIX LATER:  HTMLifying here, along with embedded markup in $error, is something of a hack,
		## as it presumes a context not in evidence.  But it's necessary in the browser context.
		$@ = HTML::Entities::encode($@);
		$@ =~ s/\n/<br>/g;
		if ( $@ =~ s/external entity callback died: // || $@ =~ /external entity references are not allowed/ ) {
		    ## First undo the effect of the croak() call in XML::LibXML.
		    $@ =~ s/ at \S+ line \d+<br>//;
		    $error = "Bad XML string (parse_perfconfig_xml):<br>$@";
		}
		elsif ( $@ =~ /Attempt to load network entity/ ) {
		    $error = "Bad XML string (parse_perfconfig_xml):<br>INVALID FORMAT: non-local entity references are not allowed in XML documents.<pre>$@</pre>";
		}
		else {
		    $error = "Bad XML string (parse_perfconfig_xml):<br>$@ called from $file line $line.";
		}
		push @errors, $error;
		$@ = '';
	    }
	    else {
		my @nodes = $doc->findnodes("groundwork_performance_configuration");
		foreach my $node (@nodes) {
		    foreach my $servprof ( $node->getChildnodes ) {
			foreach my $childnode ( $servprof->findnodes("graph") ) {
			    foreach my $key ( $childnode->findnodes("host") ) {
				$host = $key->textContent;
			    }
			    foreach my $key ( $childnode->findnodes("service") ) {
				$service = $key->textContent;
				if ( $key->hasAttributes() ) {
				    $service_regx = $key->getAttribute('regx');
				}
			    }
			    foreach my $key ( $childnode->findnodes("type") ) {
				$type = $key->textContent;
			    }
			    foreach my $key ( $childnode->findnodes("enable") ) {
				$enable = $key->textContent;
			    }
			    foreach my $key ( $childnode->findnodes("label") ) {
				$label = $key->textContent;
			    }
			    foreach my $key ( $childnode->findnodes("rrdname") ) {
				$rrdname = $key->textContent;
			    }
			    foreach my $key ( $childnode->findnodes("rrdcreatestring") ) {
				$rrdcreatestring = $key->textContent;
			    }
			    foreach my $key ( $childnode->findnodes("rrdupdatestring") ) {
				$rrdupdatestring = $key->textContent;
			    }
			    foreach my $key ( $childnode->findnodes("graphcgi") ) {
				$graphcgi = $key->textContent;
			    }
			    foreach my $key ( $childnode->findnodes("perfidstring") ) {
				$perfidstring = $key->textContent;
			    }
			    foreach my $key ( $childnode->findnodes("parseregx") ) {
				$parseregx = $key->textContent;
				if ( $key->hasAttributes() ) {
				    $parseregx_first = $key->getAttribute('first');
				}
			    }

			    # Recoding empty strings to one-character strings is not really desirable, but
			    # we do so because it sidesteps the unfortunate recoding of all false values
			    # to NULL values in StorProc->update_obj_where() and StorProc->insert_obj().
			    unless ($perfidstring) { $perfidstring = ' ' }
			    unless ($parseregx)    { $parseregx    = ' ' }

			    # Recoding the numeric fields to '00' sidesteps the later unfortunate recoding of all false
			    # values to NULL values, but still allows us to insert a simple 0 value into the database.
			    unless ($service_regx)    { $service_regx    = '00' }
			    unless ($enable)          { $enable          = '00' }
			    unless ($parseregx_first) { $parseregx_first = '00' }

			    my %where = ( 'host' => $host, 'service' => $service );
			    my %perf_config = StorProc->fetch_one_where( 'performanceconfig', \%where );

			    if     ( $perf_config{'performanceconfig_id'} ) {
				if ( $overwrite == 1 ) {
				    my %values = (
					'host'            => $host,
					'service'         => $service,
					'type'            => $type,
					'enable'          => $enable,
					'parseregx_first' => $parseregx_first,
					'service_regx'    => $service_regx,
					'label'           => $label,
					'rrdname'         => $rrdname,
					'rrdcreatestring' => $rrdcreatestring,
					'rrdupdatestring' => $rrdupdatestring,
					'graphcgi'        => $graphcgi,
					'perfidstring'    => $perfidstring,
					'parseregx'       => $parseregx
				    );
				    my $result = StorProc->update_obj_where( 'performanceconfig', \%values, \%where );
				    if ( $result =~ /error/i ) {
					push @errors, $result;
				    }
				    else {
					push @messages,
"Performance configuration for host \"<tt>$host</tt>\", service \"<tt>$service</tt>\" updated (overwrite existing = $ov{$overwrite}).";
				    }
				}
				else {
				    push @messages,
"Performance configuration for host \"<tt>$host</tt>\", service \"<tt>$service</tt>\" already exists (overwrite existing = $ov{$overwrite}).";

				}
			    }
			    else {
				unless ($graphcgi) { $graphcgi = '/' }
				my @values = (
				    \undef,           $host,         $service,      $type,    $enable,
				    $parseregx_first, $service_regx, $label,        $rrdname, $rrdcreatestring,
				    $rrdupdatestring, $graphcgi,     $perfidstring, $parseregx
				);
				my $result = StorProc->insert_obj( 'performanceconfig', \@values );
				if ( $result =~ /error/i ) {
				    push @errors, $result;
				}
				else {
				    push @messages,
				      "Performance configuration created for host \"<tt>$host</tt>\", service \"<tt>$service</tt>\".";
				}
			    }
			}
		    }
		}
	    }
	};    # end eval
	if ($@) { push @errors, $@ }
    }
    return @errors;
}

sub apply_discovery_template(@) {
    my $id       = $_[1];
    my $template = $_[2];
    my $source   = $_[3];
    my @errors   = ();
    my $data     = '';
    if ( !open( FILE, '<', "$source/discover-template-$template.xml" ) ) {
	push @errors, "$source/discover-template-$template.xml ($!)";
    }
    else {
	while ( my $line = <FILE> ) {
	    $line =~ s/\r\n/\n/;
	    $data .= $line;
	}
	close(FILE);
    }
    my %schemas = StorProc->get_table_objects('import_schema');
    if ($data) {
	my %values = ();
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
	    ## FIX LATER:  HTMLifying here, along with embedded markup in @errors, is something of a hack,
	    ## as it presumes a context not in evidence.  But it's necessary in the browser context.
	    $@ = HTML::Entities::encode($@);
	    $@ =~ s/\n/<br>/g;
	    if ($@ =~ s/external entity callback died: // || $@ =~ /external entity references are not allowed/) {
		## First undo the effect of the croak() call in XML::LibXML.
		$@ =~ s/ at \S+ line \d+<br>//;
		push @errors, "Bad XML string (apply_discovery_template):<br>$@";
	    }
	    elsif ($@ =~ /Attempt to load network entity/) {
		push @errors, "Bad XML string (apply_discovery_template):<br>INVALID FORMAT: non-local entity references are not allowed in XML documents.<pre>$@</pre>";
	    }
	    else {
		push @errors, "Bad XML string (apply_discovery_template):<br>$@ called from $file line $line.";
	    }
	}
	else {
	    my @nodes = $doc->findnodes("//prop");
	    foreach my $node (@nodes) {
		if ( $node->hasAttributes() ) {
		    my $property = $node->getAttribute('name');
		    my $value    = $node->textContent;
		    $values{$property} = $value;
		}
	    }
	    my %group_methods = ();

	    my @methods = $doc->findnodes("//method");
	    foreach my $method (@methods) {
		my $name  = undef;
		my %props = ();
		if ( $method->hasChildNodes() ) {
		    my @nodes = $method->getChildnodes();
		    foreach my $node (@nodes) {
			if ( $node->hasAttributes() ) {
			    my $property = $node->getAttribute('name');
			    my $value    = $node->textContent;
			    if ( $property eq 'name' ) {
				$name = $value;
			    }
			    else {
				$props{$property} = $value;
			    }
			}
		    }
		}
		%{ $group_methods{$name} } = %props;

		#	foreach my $prop (keys %props) {
		# next statement was commented out, so commenting out entire loop
		#		$group_methods{$name}{$prop} = $props{$prop};
		#	}
	    }
	    if ( $schemas{ $values{'schema'} } ) {
		$values{'schema_id'} = $schemas{ $values{'schema'} };
	    }
	    else {
		my $data = qq(<?xml version="1.0" encoding="iso-8859-1" ?>
<data>
</data>);
		my @vals = ( \undef, $values{'schema'}, '', '', $data, '', '', '', '' );
		my $schema_id = StorProc->insert_obj_id( 'import_schema', \@vals, 'schema_id' );
		if ( $schema_id =~ /error/i ) {
		    push @errors, $schema_id;
		}
		else {
		    my $template = "$values{'schema'}";
		    $values{'schema_id'} = $schema_id;
		    $template =~ s/\s|\\|\/|\'|\"|\%|\^|\#|\@|\!|\$/-/g;
		    if ( -e "$source/schema-template-$template.xml" ) {
			my @errs = apply_automation_template( '', $schema_id, $template, $source );
			if (@errs) { push( @errors, @errs ) }
		    }
		}
	    }
	    delete $values{'name'};
	    delete $values{'auto'};
	    delete $values{'schema'};

	    my $result = StorProc->update_obj( 'discover_group', 'group_id', $id, \%values );
	    my %discover_methods = StorProc->get_table_objects('discover_method');
	    foreach my $method ( keys %group_methods ) {
		unless ( $discover_methods{$method} ) {
		    my ( $description, $type ) = undef;
		    my $config = "<?xml version=\"1.0\" encoding=\"iso-8859-1\" ?>\n<data>";
		    foreach my $prop ( keys %{ $group_methods{$method} } ) {
			if ( $prop eq 'description' ) {
			    $description = $group_methods{$method}{$prop};
			}
			elsif ( $prop eq 'type' ) {
			    $type = $group_methods{$method}{$prop};
			}
			else {
			    $config .= "\n<prop name=\"$prop\"><![CDATA[$group_methods{$method}{$prop}]]></prop>";
			}
		    }
		    $config .= "\n</data>";
		    my @vals = ( \undef, $method, $description, $config, $type );
		    $discover_methods{$method} = StorProc->insert_obj_id( 'discover_method', \@vals, 'method_id' );
		    if ( $discover_methods{$method} =~ /error/i ) {
			push @errors, $discover_methods{$method};
		    }
		}
		unless (@errors) {
		    my @vals = ( $id, $discover_methods{$method} );
		    my $result = StorProc->insert_obj( 'discover_group_method', \@vals );
		    if ( $result =~ /error/i ) { push @errors, $result }
		}
	    }
	}
    }
    return @errors;
}

sub apply_automation_template(@) {
    my $id       = $_[1];
    my $template = $_[2];
    my $source   = $_[3];
    my @errors   = ();
    my $data     = '';
    if ( !open( FILE, '<', "$source/schema-template-$template.xml" ) ) {
	push @errors, "$source/schema-template-$template.xml ($!)";
    }
    else {
	while ( my $line = <FILE> ) {
	    $line =~ s/\r\n/\n/;
	    $data .= $line;
	}
	close(FILE);
    }
    my %serviceprofile_name = StorProc->get_table_objects('profiles_service');
    my %hostprofile_name    = StorProc->get_table_objects('profiles_host');
    my %group_name          = StorProc->get_table_objects('monarch_groups');
    my %host_name           = StorProc->get_table_objects('hosts');
    my %contactgroup_name   = StorProc->get_table_objects('contactgroups');
    my %hostgroup_name      = StorProc->get_table_objects('hostgroups');
    my %service_name        = StorProc->get_table_objects('service_names');
    my %columns             = ();

    if ($data) {
	## use MonarchProfileImport;
	my %values = ();
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
	    ## FIX LATER:  HTMLifying here, along with embedded markup in @errors, is something of a hack,
	    ## as it presumes a context not in evidence.  But it's necessary in the browser context.
	    $@ = HTML::Entities::encode($@);
	    $@ =~ s/\n/<br>/g;
	    if ($@ =~ s/external entity callback died: // || $@ =~ /external entity references are not allowed/) {
		## First undo the effect of the croak() call in XML::LibXML.
		$@ =~ s/ at \S+ line \d+<br>//;
		push @errors, "Bad XML string (apply_automation_template):<br>$@";
	    }
	    elsif ($@ =~ /Attempt to load network entity/) {
		push @errors, "Bad XML string (apply_automation_template):<br>INVALID FORMAT: non-local entity references are not allowed in XML documents.<pre>$@</pre>";
	    }
	    else {
		push @errors, "Bad XML string (apply_automation_template):<br>$@ called from $file line $line.";
	    }
	}
	else {
	    my @nodes = $doc->findnodes("//prop");
	    foreach my $node (@nodes) {
		if ( $node->hasAttributes() ) {
		    my $property = $node->getAttribute('name');
		    my $value    = $node->textContent;
		    if ( $property eq 'default_profile' ) {
			unless ( $hostprofile_name{$value} ) {
			    my $folder = '/usr/local/groundwork/monarch/profiles';
			    my $file   = "host-profile-$value.xml";
			    if ( -e "$folder/$file" ) {
				my @msgs = import_profile( '', $folder, $file, '' );
				my %hp = StorProc->fetch_one( 'profiles_host', 'name', $value );
				$hostprofile_name{$value} = $hp{'hostprofile_id'};
			    }
			}
			if ( $hostprofile_name{$value} ) {
			    $values{'hostprofile_id'} = $hostprofile_name{$value};
			}
		    }
		    else {
			$values{$property} = $value;
		    }
		}
	    }
	    my $result = StorProc->update_obj( 'import_schema', 'schema_id', $id, \%values );
	    if ( $result =~ /error/i ) { push @errors, $result }
	    my $column_key = 0;
	    my $match_key  = 0;
	    my @columns    = $doc->findnodes("//column");
	    foreach my $column (@columns) {
		$column_key++;
		if ( $column->hasChildNodes() ) {
		    my @nodes = $column->getChildnodes();
		    foreach my $node (@nodes) {
			if ( $node->hasAttributes() ) {
			    my $property = $node->getAttribute('name');
			    my $value    = $node->textContent;
			    $columns{$column_key}{$property} = $value;
			}
			elsif ( $node->hasChildNodes() ) {
			    my @matches = $node->getChildnodes();
			    $match_key++;
			    foreach my $match (@matches) {
				if ( $match->hasAttributes() ) {
				    my $property = $match->getAttribute('name');
				    my $value    = $match->textContent;
				    $columns{$column_key}{'match'}{$match_key}{$property} = $value;
				}
				elsif ( $match->hasChildNodes() ) {
				    my @objs      = $match->getChildnodes();
				    my @instances = ();
				    foreach my $obj (@objs) {
					if ( $obj->hasAttributes() ) {
					    my $property = $obj->getAttribute('name');
					    my $value    = $obj->textContent;
					    if ( $property eq 'object_type' ) {
						if ( $value eq 'Host profile' ) {
						    $columns{$column_key}{'match'}{$match_key}{$property} = $value;
						}
						else {
						    $columns{$column_key}{'match'}{$match_key}{$property} = $value;
						    @{ $columns{$column_key}{'match'}{$match_key}
							  { $columns{$column_key}{'match'}{$match_key}{'object_type'} } } = ();
						}
					    }
					    elsif ( $property eq 'service_name' ) {
						$columns{$column_key}{'match'}{$match_key}{'service_name'} = $value;
					    }
					    elsif ( $property eq 'service_args' ) {
						$columns{$column_key}{'match'}{$match_key}{'service_args'} = $value;
					    }
					    else {
						if ( $property eq 'hostprofile' ) {
						    $columns{$column_key}{'match'}{$match_key}{$property} = $value;
						}
						else {
						    push @instances, $value;
						}
					    }
					}
				    }
				    @{ $columns{$column_key}{'match'}{$match_key}{ $columns{$column_key}{'match'}{$match_key}{'object_type'} } }
				      = @instances;
				}
			    }
			}
		    }
		}
	    }
	    foreach my $column_key ( keys %columns ) {
		my @values =
		  ( \undef, $id, $columns{$column_key}{'name'}, $columns{$column_key}{'position'}, $columns{$column_key}{'delimiter'} );
		my $column_id = StorProc->insert_obj_id( 'import_column', \@values, 'column_id' );
		if ( $column_id =~ /error/i ) {
		    push @errors, $column_id;
		}
		else {
		    foreach my $match_key ( keys %{ $columns{$column_key}{'match'} } ) {
			my $hp_name = $columns{$column_key}{'match'}{$match_key}{'hostprofile'};
			unless ( !defined($hp_name) || $hostprofile_name{$hp_name} ) {
			    my $folder = '/usr/local/groundwork/monarch/profiles';
			    my $file   = "host-profile-$hp_name.xml";
			    if ( -e "$folder/$file" ) {
				my @msgs = import_profile( '', $folder, $file, '' );
				my %hp = StorProc->fetch_one( 'profiles_host', 'name', $hp_name );
				$hostprofile_name{$hp_name} = $hp{'hostprofile_id'};
			    }
			}

			my $hostprofile  = $columns{$column_key}{'match'}{$match_key}{'hostprofile'};
			my $service_name = $columns{$column_key}{'match'}{$match_key}{'service_name'};
			my @values       = (
			    \undef,
			    $column_id,
			    $columns{$column_key}{'match'}{$match_key}{'name'},
			    $columns{$column_key}{'match'}{$match_key}{'order'},
			    $columns{$column_key}{'match'}{$match_key}{'match_type'},
			    $columns{$column_key}{'match'}{$match_key}{'match_string'},
			    $columns{$column_key}{'match'}{$match_key}{'rule'},
			    $columns{$column_key}{'match'}{$match_key}{'object_type'},
			    ( defined($hostprofile)  ? $hostprofile_name{$hostprofile} : undef ),
			    ( defined($service_name) ? $service_name{$service_name}    : undef ),
			    $columns{$column_key}{'match'}{$match_key}{'service_args'}
			);
			my $match_id = StorProc->insert_obj_id( 'import_match', \@values, 'match_id' );
			if ( $match_id =~ /error/i ) {
			    push @errors, $match_id;
			}
			else {
			    if ( $columns{$column_key}{'match'}{$match_key}{'object_type'} eq 'Contact group' ) {
				foreach my $obj ( @{ $columns{$column_key}{'match'}{$match_key}{'Contact group'} } ) {
				    if ( $contactgroup_name{$obj} ) {
					my @values = ( $match_id, $contactgroup_name{$obj} );
					my $result = StorProc->insert_obj( 'import_match_contactgroup', \@values );
					if ( $result =~ /error/i ) {
					    push @errors, $result;
					}
				    }
				}
			    }
			    if ( $columns{$column_key}{'match'}{$match_key}{'object_type'} eq 'Host group' ) {
				foreach my $obj ( @{ $columns{$column_key}{'match'}{$match_key}{'Host group'} } ) {
				    if ( $hostgroup_name{$obj} ) {
					my @values = ( $match_id, $hostgroup_name{$obj} );
					my $result = StorProc->insert_obj( 'import_match_hostgroup', \@values );
					if ( $result =~ /error/i ) {
					    push @errors, $result;
					}
				    }
				}
			    }
			    if ( $columns{$column_key}{'match'}{$match_key}{'object_type'} eq 'Group' ) {
				foreach my $obj ( @{ $columns{$column_key}{'match'}{$match_key}{'Group'} } ) {
				    if ( $group_name{$obj} ) {
					my @values = ( $match_id, $group_name{$obj} );
					my $result = StorProc->insert_obj( 'import_match_group', \@values );
					if ( $result =~ /error/i ) {
					    push @errors, $result;
					}
				    }
				}
			    }
			    if ( $columns{$column_key}{'match'}{$match_key}{'object_type'} eq 'Service profile' ) {
				foreach my $obj ( @{ $columns{$column_key}{'match'}{$match_key}{'Service profile'} } ) {
				    unless ( $serviceprofile_name{$obj} ) {
					my $folder = '/usr/local/groundwork/monarch/profiles';
					my $file   = "service-profile-$obj.xml";
					if ( -e "$folder/$file" ) {

					    #my @msgs = ProfileImporter->import_profile($folder,$file,'');
					    my @msgs = import_profile( '', $folder, $file, '' );
					    my %sp = StorProc->fetch_one( 'profiles_service', 'name', $obj );
					    $serviceprofile_name{$obj} = $sp{'serviceprofile_id'};
					}
				    }
				    if ( $serviceprofile_name{$obj} ) {
					my @values = ( $match_id, $serviceprofile_name{$obj} );
					my $result = StorProc->insert_obj( 'import_match_serviceprofile', \@values );
					if ( $result =~ /error/i ) {
					    push @errors, $result;
					}
				    }
				}
			    }
			    if ( $columns{$column_key}{'match'}{$match_key}{'object_type'} eq 'Parent' ) {
				foreach my $obj ( @{ $columns{$column_key}{'match'}{$match_key}{'Parent'} } ) {
				    if ( $host_name{$obj} ) {
					my @values = ( $match_id, $host_name{$obj} );
					my $result = StorProc->insert_obj( 'import_match_parent', \@values );
					if ( $result =~ /error/i ) {
					    push @errors, $result;
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
    return @errors;
}

sub import_profile(@) {
    my $folder  = $_[1];
    my $xmlfile = $_[2];
    $overwrite = $_[3];
    unless ($overwrite) { $overwrite = 2 }
    $file = "$folder/$xmlfile";
    my @errors = ();
    $objects_read = 0;
    @messages     = ();

    if ( !-f $file || !-r $file ) {
	push @errors, "Error: This is not a readable file.";
    }
    if ( -z $file ) {
	push @errors, "Error: This file is empty.";
    }
    unless ( $errors[0] ) {
	my $parser = XML::LibXML->new(
	    ext_ent_handler => sub { die "INVALID FORMAT: external entity references are not allowed in XML documents.\n" },
	    no_network      => 1
	);
	eval {
	    $tree = $parser->parse_file($file)
	};
	if ($@) {
	    my ( $package, $file, $line ) = caller;
	    print STDERR $@, " called from $file line $line.";
	    ## FIX LATER:  HTMLifying here, along with embedded markup in @errors, is something of a hack,
	    ## as it presumes a context not in evidence.  But it's necessary in the browser context.
	    $@ = HTML::Entities::encode($@);
	    $@ =~ s/\n/<br>/g;
	    if ( $@ =~ s/external entity callback died: // || $@ =~ /external entity references are not allowed/ ) {
		## First undo the effect of the croak() call in XML::LibXML.
		$@ =~ s/ at \S+ line \d+<br>//;
		push @errors, "Error: Bad XML string (import_profile):<br>$@";
	    }
	    elsif ( $@ =~ /Attempt to load network entity/ ) {
		push @errors, "Error: Bad XML string (import_profile):<br>INVALID FORMAT: non-local entity references are not allowed in XML documents.<pre>$@</pre>";
	    }
	    else {
		push @errors, "Error: Bad XML string (import_profile):<br>$@ called from $file line $line.";
	    }
	}
    }
    unless ( $errors[0] ) {
	$root    = $tree->getDocumentElement;
	%objects = StorProc->get_objects();
	if ( $objects{'error'} ) {
	    foreach my $table ( keys %{ $objects{'error'} } ) {
		push @errors, $objects{'error'}{$table};
	    }
	}
    }
    unless ( $errors[0] ) {
	%db_values = StorProc->db_values();
	my %monarch_ver = StorProc->fetch_one( 'setup', 'name', 'monarch_version' );
	$monarch_ver = $monarch_ver{'value'};
    }
    unless ( $errors[0] ) {
	@errors = commands();
    }
    unless ( $errors[0] ) {
	@errors = timeperiods();
    }
    unless ( $errors[0] ) {
	@errors = host_templates();
    }
    unless ( $errors[0] ) {
	@errors = hostextinfo_templates();
    }
    unless ( $errors[0] ) {
	@errors = service_templates();
    }
    unless ( $errors[0] ) {
	@errors = serviceextinfo_templates();
    }
    unless ( $errors[0] ) {
	@errors = import_externals('service');
    }
    unless ( $errors[0] ) {
	@errors = import_externals('host');
    }
    unless ( $errors[0] ) {
	@errors = services();
    }
    unless ( $errors[0] ) {
	@errors = service_profiles();
    }
    unless ( $errors[0] ) {
	@errors = host_profiles();
    }
    unless ( $errors[0] ) {
	$xmlfile =~ s/^(?:host-profile-|service-profile-|service-)//;
	my $perfcfg_file = undef;
	if ( !opendir( DIR, $folder ) ) {
	    push @errors, "Error: cannot open $folder to read ($!)";
	}
	else {
	    while ( my $file = readdir(DIR) ) {
		if ( $file =~ /^perfconfig-$xmlfile$/ ) {
		    $perfcfg_file = $file;
		    last;
		}
	    }
	    closedir(DIR);
	}
	if ($perfcfg_file) {
	    @errors = parse_perfconfig_xml( "$folder/$perfcfg_file", $overwrite );
	}
    }

    if ( @errors || $objects_read == 0 ) {
	my $file_link;
	my $via_phrase;
	if ($file) {
	    ( my $relative_file = $file ) =~ s@/usr/local/groundwork/core@@;
	    my $url = Forms->get_file_url($relative_file);
	    if ($url) {
		$file_link  = "<a href=\"$url\" target=\"_blank\"><b><code>$file</code></b></a>";
		$via_phrase = ' via the link above';
	    }
	}
	unless ($file_link) {
	    $file_link  = $file;
	    $via_phrase = '';
	}
	if ( $objects_read == 0 ) {
	    push @errors, "No objects were read from the imported file; check its contents$via_phrase.";
	}
	unshift @messages, "<b>Profile import found error(s) in:</b><br><b>$file_link</b>";
	push @messages, "<b>Error(s) occurred here during profile import:</b>";
	push( @messages, @errors );
	push @messages, "Profile import halted. Make corrections and try again.";
	return @messages;
    }
    else {
	return @messages;
    }
}

if ($debug) {
    my $path      = $ARGV[1];
    my $file      = $ARGV[2];
    my $overwrite = $ARGV[3];
    my @result    = ( my $result ) = StorProc->dbconnect();

    my @res = import_profile( '', $path, $file, $overwrite );
    push( @result, @res );
    $result = StorProc->dbdisconnect();
    print "\nFile: $file\n";
    print "Monarch ver: $monarch_ver\n";
    print "\nResults:\n========================================================================\n";
    foreach my $line (@res) {
	print "\n\t$line";
    }
    print "\n\nEnd=============================================================================\n";
}

1;

