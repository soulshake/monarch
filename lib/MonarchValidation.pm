# MonArch - Groundwork Monitor Architect
# MonarchValidation.pm
#
############################################################################
# Release 4.5
# August 2016
############################################################################
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
package Validation;
use JavaScript::DataFormValidator;

#
# MonarchValidation.pm
#
# This module uses Data::FormValidator (sometimes abbreviated in code as
# DFV or dfv), a popular CPAN module for doing validation of input.
# It also uses JavaScript::DataFormValidator, a glue module that allows use of
# a DataFormValidator, a JavaScript library that borrows the name, approach and
# the profile syntax of DFV. By using these two CPAN modules and the JavaScript
# library, we can do both JavaScript and server-side validation with the same
# set of profiles.
#

#
# dfv_profile_javascript()
#
# Returns a snippet of JavaScript that contains the profile for validating
# the fields in a form. This JavaScript code needs to be included in the same
# page as the form.
#
sub dfv_profile_javascript {
    my $profile_summary = $_[1];
    local $_;

    my $illegal_chars = qq(/\\` ~+!\$\%^&*|'"<>?,()=[]:{}#;\nor any 9-bit or larger Unicode characters);

    # $profile_summary is a hash reference where each key is the name of a form field,
    # and the values are the core of a profile, the constraint and the message. See
    # the example below.
    #
    # Records created prior to Monarch's support for validation may contain data
    # that would not pass current validation rules. Even so, we can still allow
    # their continued use, by passing in the old field values as profile_summary.
    # There are two ways profile_summary data gets applied. If a constraint for
    # fieldname already exists, the profile_summary constraint is added to the
    # existing pattern as an OR, so the input will validate against
    # /existingpattern|profile_summary_pattern/.  If the constraint for fieldname
    # does not exist, it is populated with the value from the constraint in the
    # profile_summary.
    #
    # This should only be used for named constraints, and they should be stored
    # in the array format (note: unless that is the source of the bug that is
    # causing parts of this not to work; see note below in __END__ section),
    # not plain scalar format. In other words, like this:
    #
    #    my $valid_profile = {
    #        ...
    #        constraints => {
    #            fieldname   => [{ name => 'name_main_constraint',
    #            		   constraint => '(?i:[a-z]+)'
    #                           }],
    #        },
    #    ...
    #    };
    #
    # not like this:
    #
    #    my $valid_profile = {
    #        ...
    #        constraints => {
    #            fieldname    => { name => 'name_main_constraint',
    #           		   constraint => '(?i:[a-z]+)'
    #                            },
    #        },
    #    ...
    #    };
    #
    # Constraints must not include enclosing slashes, and any literal slashes
    # within them must be escaped (in general, all PCRE special characters must
    # be escaped, as with + in the example below).  Also, constraints cannot
    # include ^$ tests, because those will already be applied outside of the
    # constraint itself.
    #
    # Calling code example:
    #
    #     my $profile_summary = {
    #         fieldname => {
    #             constraint => 'foo\+bar',
    #             message    => 'input must match "foo+bar"',
    #         },
    #         more fieldnames here ...
    #     };
    #     Validation->dfv_profile_javascript($profile_summary);
    #
    # Note that only one exception can be applied to each field, since they are
    # keyed by the name of the field. If you really need more, construct your
    # own profile_summary using '|' like this: 'foo\+bar|baz'
    #
    # Another way to do this would have been some kind of 'or' validation where
    # constraint1 passes OR constraint2 passes ... but the JavaScript library
    # does not appear to support that.

    my $valid_profile = {
    	required    => [qw(
                            name
	                )],
        optional    => [qw(
                            email
                            select
                       )],
        constraints => {
	    # Note 'name' is an overloaded term in the next line. In the first instance,
	    # it happens to be the name of a field (the name of the field is name.) In
	    # the second instance, it is a reserved word of DataFormValidator, letting
	    # us set the name of the constraint, which in this case is 'name_main_constraint'
	    # meaning 'the main constraint for the field called name'.
	    name        => [{ name => 'name_main_constraint',
			      # this regexp may get updated by %$profile_summary{name} if defined;
			      # FIX THIS:  but in any case the $illegal_chars variable ought to be
			      # updated as well so the message presented to the user accurately
			      # reflects what is being tested
			      # See GWMON-6133 for the ugly truth.  We no longer do case-insensitive matching here.
			      constraint => '/^[^/\\\\` ~\+!\$\%\^\&\*\|\'\"<>\?,\)\(\'=\[\]\{\}\:\#;\\u0100-\\uFFFD]+$/'
			    },
			    { name => 'name_length_constraint',
			      constraint => '/^.{1,255}$/'
			    }],
	    select      => '/test/i',
	    email       => 'email',
	},
	msgs    => {
	    format            => '%s',
	    invalid           => 'Invalid data',
	    invalid_separator => ', ',
	    constraints => {
		name_main_constraint   => "The name field cannot contain any of the following characters:\n$illegal_chars",
		name_length_constraint => "The value of the name field cannot be longer than 255 characters.",
	    },
	},
    };

    if (defined($profile_summary)) {
	if (!ref($profile_summary) && $profile_summary eq 'rename') {
	    $valid_profile->{required} = [qw( new_name )];
	    $valid_profile->{constraints}{new_name} = delete $valid_profile->{constraints}{name};
	    $valid_profile->{constraints}{new_name}[0]->{name} =~ s/name/new_name/;
	    $valid_profile->{constraints}{new_name}[1]->{name} =~ s/name/new_name/;
	    $valid_profile->{msgs}{constraints}{new_name_main_constraint}   = delete $valid_profile->{msgs}{constraints}{name_main_constraint};
	    $valid_profile->{msgs}{constraints}{new_name_length_constraint} = delete $valid_profile->{msgs}{constraints}{name_length_constraint};
	    $valid_profile->{msgs}{constraints}{new_name_main_constraint}   =~ s/name/new name/;
	    $valid_profile->{msgs}{constraints}{new_name_length_constraint} =~ s/name/new name/;
	}
	elsif (ref($profile_summary) eq 'HASH') {
	    foreach my $key (keys %$profile_summary) {
		my $pattern = $profile_summary->{$key}->{constraint};
		my $message = $profile_summary->{$key}->{message};
		if (defined($valid_profile->{constraints}->{$key}[0]->{constraint})) {
		    # add to existing constraint (usually used for exceptions)
		    $valid_profile->{constraints}->{$key}[0]->{constraint} =~ s{^/\^(.*)\$/$}{/^(?:$1|$pattern)\$/};
		    # for this case, do not add to the existing message
		}
		else {
		    # inject a new constraint - here we augment the $valid_profile with new fields
		    my $constraint_name = $key . '_main_constraint';
		    push(@{$valid_profile->{required}}, $key) unless (grep $_ eq $key, @{$valid_profile->{required}});
		    $valid_profile->{constraints}->{$key} = [] unless (defined($valid_profile->{constraints}->{$key}));
		    $valid_profile->{constraints}->{$key}[0]->{name} = $constraint_name;
		    $valid_profile->{constraints}->{$key}[0]->{constraint} = "/^$pattern\$/";
		    $valid_profile->{msgs}->{constraints}->{$constraint_name} = "$message";
		}
	    }
	}
    }

    my $snippet = "\n" . js_dfv_profile( 'monarch_form' => $valid_profile);
    return $snippet;
}


#
# Generate the JavaScript function call that is called on form
# submission. The form id here must match the one used in the profile.
#
sub dfv_onsubmit_javascript {

    my $extra_actions = $_[1];

    # with $extra_actions not defined, this generates:
    # onsubmit="return Data.FormValidator.check_and_report(this, monarch_form);
    my $snippet = js_dfv_onsubmit('monarch_form');

    if (defined($extra_actions)) {
	# no closing quote is not a typo
	$snippet =~ s{onSubmit="(.*)}{onSubmit="$extra_actions;$1};
    }

    return $snippet;
}


# The below is still a dead end, because the JavaScript DataFormValidator
# still has subroutine constraints on its TODO list. Instead the constraints
# need to be passed in as regexps as part of a profile.
sub dfv_constraint_hostname {
    my $data = shift;
    ## FIX THIS:  This match pattern has probably been bungled because of the
    ## formatting across multiple lines.  Dig into it.
    if (
	$data =~ m{^
	    [-_\w]+ # need to improve this regexp
	$}x
      )
    {
	return 1;
    }
    else {
	return 0;
    }
}

1;

__END__

Example of a JavaScript profile generated by the above (formatted):

This profile is suspect because validation on the 'name' field is working,
but validation on the much more simple notification fields is not working.
The only difference I can see between them so far is that the name field
has multiple constraints. Maybe when there is only one constraint, the
name,constraint pair hashref cannot be contained inside an arrayref, as
it is now, but that seems counterintuitive.

var monarch_form = {
    constraints: {
	email: "email",
	first_notification: [ { name: "first_notification_main_constraint", constraint: "/^[0-9]+$/" } ],
	name: [ { name: "name_main_constraint", constraint: "/^[^/\\\\` ~\\+!\\$\\%\\^\\&\\*\\|'\\\"<>\\?,\\)\\('=\\[\\]\\{\\}\\:\\#;]+$/" },
		{ name: "name_length_constraint", constraint: "/^.{1,255}$/" }
	      ],
	notification_interval: [ { name: "notification_interval_main_constraint", constraint: "/^[0-9]+$/" } ],
	last_notification: [ { name: "last_notification_main_constraint", constraint: "/^[0-9]+$/" } ],
	select: "/test/i"
    },
    required: [ "name", "first_notification", "notification_interval", "last_notification" ],
    optional: [ "email", "select" ],
    msgs: {
	constraints: {
	    notification_interval_main_constraint: "Value must be numeric.",
	    first_notification_main_constraint: "Value must be numeric.",
	    name_length_constraint: "The value of the name field cannot be longer than 255 characters.",
	    name_main_constraint: "The name field cannot contain any of the following characters: /\\` ~+!$%^&*|'\"<>?,()=[]:{}#;",
	    last_notification_main_constraint: "Value must be numeric."
	},
	invalid_separator: ", ",
	format: "%s",
	invalid: "Invalid data"
    }
};

