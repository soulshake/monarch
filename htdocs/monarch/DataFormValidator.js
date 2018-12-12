/* Data::FormValidator javascript support methods */
/*********************************************************************
 *********************************************************************
 **  Data.FormValidator                                             **
 *********************************************************************
 *********************************************************************/
/*

=pod

=head1 NAME

Data.FormValidator - Validate HTML form input based on input profile.

=head1 SYNOPSIS

 <FORM onSubmit="return myValidate(this);">
 ...
 </FORM>
 <SCRIPT LANGUAGE="javascript"><!--
 var click_once = 0;
 function myValidate (frmObj) {
    var goodColor = "#FFFFFF";
    var badColor  = "#FFFF99";

    var profile = new Object();
    // define profile ...

    // put any extras you'd like in here
    if (click_once == 0) {
        click_once = 1;
        var passed = Data.FormValidator.check_and_report(frmObj, profile, goodColor, badColor);
        if (passed) {
            return true;
        } else {
            // reset click_once, so they can re-fillout the form
            click_once = 0;
            return false;
        }
    }
 };
 // --></SCRIPT>

ALTERNATIVELY: the following is a more detailed handling, and is actually what happens in when the above convenience method, C<check_and_report()>, is called.

 <FORM onSubmit="return myValidate(this);">
 ...
 </FORM>
 <SCRIPT LANGUAGE="javascript"><!--
 function myValidate (frmObj) {
    var goodColor = "#FFFFFF";
    var badColor  = "#FFFF99";

    var profile = new Object();
    // define profile ...
    var results = Data.FormValidator.check(frmObj, profile);
    // clean up colors from form
    results.cleanForm(frmObj, goodColor);
    if (! results.success()) {
        var error_text = "";
        var msgs = results.msgs();
        for (field in results.missing_required) {
            results.changeStyle(frmObj, field, badColor);
            error_text += "Field ["+field+"] is required.\n";
        }
        for (field in results.missing_dependency) {
            for (i in results.missing_dependency[field]) {
                var dep = results.missing_dependency[field][i];
                results.changeStyle(frmObj, dep, badColor);
                error_text += "Marking field ["+field+"] requires field ["+dep+"] also be filled in.\n";
            }
        }
        for (group in results.missing_depgroup) {
            var completed  = results.missing_depgroup[group]['completed'];
            var incomplete = results.missing_depgroup[group]['incomplete'];
            for (i in incomplete) {
                results.changeStyle(frmObj, incomplete[i], badColor);
            }
            error_text += "Marking field(s) ["+completed.join(', ')+"] requires field(s) ["+incomplete.join(', ')+"] also be filled in.\n";
        }
        for (field in results.invalid) {
            results.changeStyle(frmObj, field, badColor);
            error_text += (msgs[field]) ? "Field ["+field+"]: "+msgs[field] :
                                          "Improperly formatted data in field ["+field+"].";
            error_text += "\n";
        }

        alert("There is a problem with your form.\n\n"+error_text);
        return false;

    } else {
        // do something with results.valid ?
        return true;
    } 
 };
 // --></SCRIPT>

=head1 DESCRIPTION

Data.FormValidator's aim is to bring all the benefits of the perl module L<Data::FormValidator|Data::FormValidator> over to javascript, using the same input profiles (they can be dumped into javascript objects using the perl module L<Data::JavaScript|Data::JavaScript>).

Data.FormValidator lets you define profiles which declare the
required and optional fields and any constraints they might have.

The results are provided as an object which makes it easy to handle 
missing and invalid results, return error messages about which constraints
failed, or process the resulting valid data.

=head1 TODO

There are many features missing from this library, that are available in the perl version. The big ones have been marked in the code with the text "TODO". There are too many things missing to explain them all at this time, but we've attempted to note below when feature are not available, work differently, or only exist here.

=head1 VALIDATING INPUT

=head2 B<new Data.FormValidator()>

Constructor. Currently takes NO options. (TODO: this should optionally support taking in defaults).

Returns a Data.FormValidator object (referred to from here on out as "dfv").

=cut

*/

/* Set up the namespace */
if ( typeof Data == "undefined" ) var Data = { };
// if (Data               == undefined) var Data               = function () {};
// if (Data.FormValidator == undefined)     Data.FormValidator = function () {};

Data.FormValidator = function () {
    // TODO: add support for profile defaults
    var profile_file, profiles, defaults;
    this.profile_file = profile_file;
    this.profiles     = profiles;
    this.defaults     = defaults;
};

// Includes slight modifications by GroundWork.
Data.FormValidator.VERSION = '0.071';

/*

=head2 B<dfv.validate(formObject, profile);>

***DEPRECATED***

"validate()" provides a deprecated alternative to "check()". It has the
same input syntax, but returns a four element array, containing the following 
elements from the "Results" object (the return value of the "check()" method).

    results.valid()
    results.missing()
    results.validate_invalid()
    results.unknown()

See L<Data::FormValidator|Data::FormValidator>, and the following documentation on C<Data.FormValidator.Results> for more info.

=cut

*/
Data.FormValidator.prototype.validate = function (frmObj, profile) {
    var data_set = this.check(frmObj, profile);

    var returnVal = new Array();
    returnVal[0]    = data_set.valid();
    returnVal[1]    = data_set.missing();
    returnVal[2]    = data_set.validate_invalid || new Array();
    returnVal[3]    = data_set.unknown();

    return returnVal;
};

/*

=head2 B<dfv.check()>

 var results = Data.FormValidator.check(formObject, dfv_profile);

C<check> is the recommended method to use to validate forms. It returns it's results as a
L<Data.FormValidator.Results|Data.FormValidator.Results> object.  A
deprecated method C<validate> is also available, returning it's results as an
array described above.

 var results = Data.FormValidator.check(formObject, dfv_profile);

Here, C<check()> is used as a class method***, and takes two required parameters.
It can also be called as an instance method:

 var dfv = new Data.FormValidator();
 var results = dfv.check(formObject, dfv_profile);

The first argument is a javascript DOM object pointing to the form to be validated.

The second argument is a reference to the profile you are validating.

The resulting "results" object can be used to call has_missing(), has_invalid(), and their ilk.

*** NOTE: "class method" is what it's called on the perl side. Here, it's an object constructor, which just happens to take care of some stuff in the Data.FormValidator namespace behind the scenes for you.

=cut

*/
Data.FormValidator.prototype.check = function (frmObj, profile) {
    var defaults = new Object();
    defaults.profile_file = this.profile_file;
    defaults.profiles     = this.profiles;
    defaults.defaults     = this.defaults;
    var dfvc = new Data.FormValidator.check(frmObj, profile, defaults);
    return dfvc;
};

/*********************************************************************
 *********************************************************************
 **  Data.FormValidator.check                                       **
 *********************************************************************
 *********************************************************************/
// NOTE: check() can be called as a class method for simple cases
Data.FormValidator.check = function (frmObj, profile, defaults) {
    // TODO: we currently ignore any defaults passed in.

    var dfv = new Data.FormValidator();

    this.frmObj     = frmObj;
    if (typeof(profile) == "string") {
        // TODO: load in profile from file ...
        // dfv._load_profiles();
        // this.profile = this.profiles[profile];
        // if (! this.profile) {
        //  alert("No such profile "+profile);
        //  return false;
        // }
        alert("TOOD: UNSUPPORTED PROFILE TYPE 'string'");
        return false;
    } else {
        this.profile = profile;
    }

    // TODO: merge profile with defaults
    // if (defaults['defaults']) { this.profile = this._mergeProfiles(defaults.defaults, this.profile); }

    // TODO: profile syntax checker (fluf, so we're skipping for now
    // dfv._check_profile_syntax(this.profile);

    var results = new Data.FormValidator.Results(profile, frmObj);

    // TODO: As a special case, pass through any defaults for the 'msgs' key.
    // $results->msgs(defaults.msgs) if default.msgs;

    return results;
};

/*

=head2 B<Data.FormValidator.check_and_report(formObject, dfv_profile [, goodColor, badColor] )>

 var success = Data.FormValidator.check_and_report(formObject, dfv_profile);

This is a convenience method. It takes care of calling C<check()>, processing the results, building a helpful error message if it erred out, and reporting the errors to the user (via javascript alert() box). If C<check()> succeeds, it returns "true"; returns "false" on failure.

This is the recommended way to use this library. If you require more advanced usage, this method can be used as a good starting point to base your processing upon.

Options:

=over

=item formObject:

javascript DOM object pointing to the form to be validated.

=item dfv_profile:

Reference to the profile you are validating.

=item goodColor (optional):

Hex value of a color to set the form field backgrounds to if the field is valid.

=item badColor (optional):

Hex value of a color to set the form field backgrounds to if the field is invalid.

=back

=cut

*/

/*********************************************************************
 *********************************************************************
 **  Data.FormValidator.check_and_report                            **
 *********************************************************************
 *********************************************************************/
// NOTE: check() can be called as a class method for simple cases
Data.FormValidator.check_and_report = function (frmObj, profile, goodColor, badColor) {
    goodColor = goodColor || "#FFFFFF";
    badColor  = badColor  || "#FFFF99";

    var results = Data.FormValidator.check(frmObj, profile);
    results.cleanForm(frmObj, goodColor);
    if (! results.success()) {
        var error_text = "";
        var msgs = results.msgs();
        for (field in results.missing_required) {
            results.changeStyle(frmObj, field, badColor);
            error_text += "Field ["+field+"] is required.\n";
        }
        for (field in results.missing_dependency) {
            for (i in results.missing_dependency[field]) {
                var dep = results.missing_dependency[field][i];
                results.changeStyle(frmObj, dep, badColor);
                error_text += "Marking field ["+field+"] requires field ["+dep+"] also be filled in.\n";
            }
        }
        for (group in results.missing_depgroup) {
            var completed  = results.missing_depgroup[group]['completed'];
            var incomplete = results.missing_depgroup[group]['incomplete'];
            for (i in incomplete) {
                results.changeStyle(frmObj, incomplete[i], badColor);
            }
            error_text += "Marking field(s) ["+completed.join(', ')+"] requires field(s) ["+incomplete.join(', ')+"] also be filled in.\n";
        }
        for (field in results.invalid) {
            results.changeStyle(frmObj, field, badColor);
            error_text += (msgs[field]) ? "Field ["+field+"]: "+msgs[field] :
                                          "Improperly formatted data in field ["+field+"].";
            error_text += "\n";
        }

        alert("There is a problem with your form.\n\n"+error_text);
        return false;

    } else {
        // do something with results.valid ?
        return true;
    } 
};

/*

TODO: these need written and incorporated

=head2 B<dfv.load_profiles()> (TODO)

=head2 B<dfv._mergeProfiles()> (TODO)

=head2 B<dfv._check_profile_syntax()> (TODO)

=cut

*/
Data.FormValidator.prototype.load_profiles = function () {
};
Data.FormValidator.prototype._mergeProfiles = function (defaults, profile) {
};
Data.FormValidator.prototype._check_profile_syntax = function (profile) {
};

/*

=head1 INPUT PROFILE SPECIFICATION

Please see the pod documentation for the perl module L<Data::FormValidator|Data::FormValidator>.

NOTE: Constraint support is currently limited. This library currently supports:

=over

=item * Regular Expression Constraints

Only as quoted strings (eg "/regexp/", not qr/regexp/).

=item * Built in Constraints

Those offered by Data::FormValidator (see L<Data.FormValidator.Constraints|Data.FormValidator.Constraints> below), but NOT the extra RegExp::Common ones (thought those are on the TODO list now).

=back

The profile spec for this library, is the result of running a perl C<Data::FormValidator> profile through the module L<Data::JavaScript|Data::JavaScript>. You may construct it by hand, but the specifics of such are outside the scope of this document. Please read on for some more info.

L<Data::JavaScript|Data::JavaScript> dumps perl data structures out to a javascript object/array structure.

Here is a very simple input profile in perl:

    my $profile = {
        optional => [qw( company fax country )],
        required => [qw( fullname age phone email address )],
        constraints => {
            email => { name => "valid_email",
                       constraint => "/^(([a-z0-9_\\.\\+\\-\\=\\?\\^\\#]){1,64}\\@(([a-z0-9\\-]){1,251}\\.){1,252}[a-z0-9]{2,4})$/i" },
            age => { name => "valid_age",
                     constraint => "/^1?\d?\d$/" },
        },
        msgs => {
            constraints => {
                valid_email => "Invalid e-mail address format",
                valid_age   => "Age entered must be between 0 and 199",
            }
        },
    };

Here is the same profile output by C<Data::JavaScript::jsdump()>:

    var profile = new Object;
    profile.constraints = new Object;
    profile.constraints.email = new Object;
    profile.constraints.email.name = 'valid_email';
    profile.constraints.email.constraint = '\/\^\(\(\[a\-z0\-9_\\\.\\\+\\\-\\\=\\\?\\\^\\\#\]\)\{1\,64\}\\\@\(\(\[a\-z0\-9\\\-\]\)\{1\,251\}\\\.\)\{1\,252\}\[a\-z0\-9\]\{2\,4\}\)\012i';
    profile.constraints.age = new Object;
    profile.constraints.age.name = 'valid_email';
    profile.constraints.age.constraint = '\/\^1\?\\d\?\\d\012';
    profile.required = new Array;
    profile.required[0] = 'fullname';
    profile.required[1] = 'phone';
    profile.required[2] = 'email';
    profile.required[3] = 'address';
    profile.optional = new Array;
    profile.optional[0] = 'company';
    profile.optional[1] = 'fax';
    profile.optional[2] = 'country';
    profile.msgs = new Object;
    profile.msgs.constraints = new Object;
    profile.msgs.constraints.valid_email = 'Invalid e\-mail address format';
    profile.msgs.constraints.valid_age = 'Age entered must be between 0 and 199';

Your profile may contain anything that the perl module L<Data::FormValidator> contains, but only a subset of it will be supported by this library. The following keys are supported.

=over

=item required

Array of required fields (required means they must not be blank, nor consist only of spaces). Valid fields listed here will be returned in the results.valid object.

=item optional

Array of optional fields (if filled in, constraints placed on these fields will also be checked). Valid fields listed here will be returned in the results.valid object, as well as blank ones.

=item dependencies

 dependencies   => {
    # If cc_no is entered, make cc_type and cc_exp required
    "cc_no" => [ qw( cc_type cc_exp ) ],
 },


This is for the case where an optional field has other requirements.  The
dependent fields can be specified with an array.

=item dependency_groups

 dependency_groups  => {
     # if either field is filled in, they all become required
     password_group => [qw/password password_confirmation/],
 }

The key is an arbitrary name you create. The values are arrays of field names in each group. If any field in the group is filled in, all fields in the group must be filled in.

=item constraints

 constraints => {
    fieldName1  => '/regexp/i',
    fieldName2  => { name => 'all_numbers', constraint => '/^\\d+$/' },
    fieldName3  => [ { name => 'no_spaces', constraint => '/^\\S*$/' },
                     { name => 'word_chars', constraint => '/^\\w+$/' } ],
    fieldName4  => 'valid_email',
 }

The second and third form above are recommended, as they allow you to tie the constraint to a custom error message (through the msgs hash).

We support a very narrow range of constraints options (we do not support constraint_methods as of yet, nor named closures ( "field => email()" ), nor subroutine references, nor compiled regexps(qr/regexp/) ). The ones listed above will all work, namely, quoted regexp and quoted named constraints.

=item msgs

This key is used to define parameters related to formatting error messages
returned to the user.

Please see L<Data::FormValidator|Data::FormValidator> for more detailed information.

The important thing to note is that 

A) the constraint must be named. Eg:

    profile => {
        constraints => {
            fieldName   => { name => 'someName', constraint => '/\\d+/' },
        },
    };

B) the msgs hash references the "name =>", not the field name. Eg:

    profile => {
        msgs    => {
            constraints => {
                someName    => "Error message goes here",
            },
        },
    };

The rest is important too, but easy to grasp from the L<Data::FormValidator|Data::FormValidator> documentation.

=back

=cut

*/


/*********************************************************************
 *********************************************************************
 **  Data.FormValidator.Results                                     **
 *********************************************************************
 *********************************************************************/

/*

=head1 NAME

Data.FormValidator.Results - results of form input validation.

=head1 SYNOPSIS

    var results = Data.FormValidator.check(formObject, dfv_profile);

    var msgs = results.msgs();

    // Print the name of missing fields
    if ( results.has_missing() ) {
        for (f in results.missing) {
            alert(f + " is missing\n");
        }
    }

    // Print the name of invalid fields
    if ( results.has_invalid() ) {
        for (f in results.invalid) {
            alert(f + " is invalid: " + msgs[f] + "\n");
        }
    } 

    // Print unknown fields
    if ( results.has_unknown() ) {
        for (f in results.unknown) {
            alert(f + " is unknown\n");
        }
    } 

    // Print valid fields
    for (f in results.valid) {
        alert(f + " = " + results.valid[f] + "\n");
    }

=head1 DESCRIPTION

This object is returned by the L<Data.FormValidator> C<check> method. 
It can be queried for information about the validation results.

=cut

*/

Data.FormValidator.Results = function (profile, frmObject) {
    this.profile     = profile;
// TODO: not sure if we need defaults or not?
//    this.defaults     = defaults;

    this.constraints = new Data.FormValidator.Constraints();

    this._process(profile, frmObject);
};

/*

=head1 RESULTS METHODS

=head2 B<results.success()>

This method returns true if there were no invalid or missing fields,
else it returns false.

=cut

*/
Data.FormValidator.Results.prototype.success = function () {
    return !(this.has_invalid() || this.has_missing());
};
/*

=head2 B<results.has_missing()>

Returns a count of missing fields (zero for none).

=head2 B<results.has_invalid()>

Returns a count of invalid fields (zero for none).

=head2 B<results.has_unknown()>

Returns a count of unknown fields (zero for none).

=head2 B<results.has_missing_required()>

Returns a count of required fields that were missing (zero for none).

=head2 B<results.has_missing_dependency()>

Returns a count of dependency fields that were missing (zero for none).

=head2 B<results.has_missing_depgroup()>

Returns a count of dependency group fields that were missing (zero for none).

=cut

*/
Data.FormValidator.Results.prototype.has_missing = function () {
    var count = 0;
    for (i in this.missing) {
        count++;
    }
    return count;
};

Data.FormValidator.Results.prototype.has_invalid = function () {
    var count = 0;
    for (i in this.invalid) {
        count++;
    }
    return count;
};

Data.FormValidator.Results.prototype.has_unknown = function () {
    var count = 0;
    for (i in this.unknown) {
        count++;
    }
    return count;
};

Data.FormValidator.Results.prototype.has_missing_required = function () {
    var count = 0;
    for (i in this.missing_required) {
        count++;
    }
    return count;
};

Data.FormValidator.Results.prototype.has_missing_dependency = function () {
    var count = 0;
    for (i in this.missing_dependency) {
        count++;
    }
    return count;
};

Data.FormValidator.Results.prototype.has_missing_depgroup = function () {
    var count = 0;
    for (i in this.missing_depgroup) {
        count++;
    }
    return count;
};

/*

=head1 DATA ACCESSOR STRUCTURES

=head2 B<results.valid>

Object data structure.

Access Single element:

    results.valid.element
    results.valid['element']

Iterate over all valid items:

    for (field in results.valid) {
        // do something with "field"
    }

=head2 B<results.invalid>

Object data structure.

Access Single element:

    results.invalid.element
    results.invalid['element']

Iterate over all valid items:

    for (field in results.valid) {
        for (i in results.valid[field]) {
            var testName = results.valid[field][i];
        }
        // do something with "field"
    }

=head2 B<results.validate_invalid>

Array data structure.

Array of Arrays.

First element of each row is the "fieldName". The remainder of the elements are the test names that failed. Eg.

    for (i in results.validate_invalid) {
        var fieldName = results.validate_invalid[i];
        var failedTests = new Array();
        for (var j=1; j<results.validate_invalid.length; j++) {
            failedTests[failedTests.length] = results.validate_invalid[j];
        }
    }

=head2 B<results.missing>

Object data structure. Contains all missing fields (those listed in "required" but not filled in, those listed as a dependency to an optional field that was filled in, those blank from a dependency group that had one or more members filled in). There are more specific missing_* objects you can use to get at each category of missing individually (NOTE: the more specific ones are NOT available in the perl version of L<Data::FormValidator|Data::FormValidator>).

Access Single element:

    results.missing.element
    results.missing['element']

Iterate over all items:

    for (field in results.missing) {
        // do something with "field"
    }

=head2 B<results.missing_required>

Object data structure. (NOTE: this property is not available in the perl version of L<Data::FormValidator|Data::FormValidator>)

Access Single element:

    results.missing_required.element
    results.missing_required['element']

Iterate over all items:

    for (field in results.missing_required) {
        // do something with "field"
    }

=head2 B<results.missing_dependency>

Object data structure. (NOTE: this property is not available in the perl version of L<Data::FormValidator|Data::FormValidator>)

This data structure is a bit more complex. The first level contains the "fieldName" which triggered the dependency. As its value, is an array of dependencies that were not completed. Eg.

    for (fieldName in this.missing_dependency) {
        // fieldName triggered this dependency
        alert("field["+fieldName+"] required the following fields also be completed: "+ this.missing_dependency[fieldName].join(", ") );
    }

=head2 B<results.missing_depgroup>

Object data structure. (NOTE: this property is not available in the perl version of L<Data::FormValidator|Data::FormValidator>)

This data structure is a bit more complex. The first level contains the "dependency group name" that failed the test. It is an object which has two properties: "completed" and "incomplete". Each of those properties holds and array of completed and incomplete fields respectively.

Ex.

    for (group in results.missing_depgroup) {
        var completed  = results.missing_depgroup[group]['completed'];
        var incomplete = results.missing_depgroup[group]['incomplete'];
        for (i in incomplete) {
            results.changeStyle(frmObj, incomplete[i], badColor);
        }
        error_text += "Marking field(s) ["+completed.join(', ')+"] requires field(s) ["+incomplete.join(', ')+"] also be filled in.\n";
    }

=head2 B<results.unknown>

Object data structure. List of all fields found in the form that are not listed as required nor optional in the dfv_profile.

Access Single element:

    results.unknown.element
    results.unknown['element']

Iterate over all items:

    for (field in results.unknown) {
        // do something with "field"
    }

=cut

*/

/*********************************************************************
 *********************************************************************
 ** These commented out methods were needed in the perl version     **
 ** but we can use the built in data accessors instead              **
 *********************************************************************
 *********************************************************************
 * missing( [field] )                                               *
 * Called with one argument, returns true if that field was missing *
 * Called with no arguments, returns an array of missing fields     *
Data.FormValidator.Results.prototype.missing = function (key) {
    if (typeof(key) != "undefined") return this.missing[key];

    return this.missing;
};

 * valid( [[field] [,value]] );                                      *
 * Called with no arguments, returns an array of fields which        *
 * contain valid values.                                             *
 *                                                                   *
 * Called with one argument, returns the value of that field if it   *
 * contains valid data, undefined otherwise.                         *
 *                                                                   *
 * Called with two arguments, sets the value of "field" to "value".  *
 * This form is useful to alter the results from withing some        *
 * constraints.                                                      *
Data.FormValidator.Results.prototype.valid = function (key, val) {
    if ((typeof(key) != "undefined") && (typeof(val) != "undefined")) this.valid[key] = val;

    if (typeof(key) != "undefined") return this.valid[key];

    // if we got this far, there were no arguments passed.
    var rv = new Array();
    for (fieldName in this.valid) {
        rv[rv.length] = fieldName;
    }
    return rv;
};
 *********************************************************************
 *********************************************************************
 ** End commented out ex-perl stuff                                 **
 *********************************************************************
 *********************************************************************/

/* _process() does the real form checking, dispacthing to testing *
 * methods, etc etc.                                              */
Data.FormValidator.Results.prototype._process = function (profile, frmObj) {

    /* TODO: We only support a subset of the available constraint checks,   *
     *       among other limitations. However, we also support additional   *
     *       reporting methods, so you can tell if the field was missing    *
     *       because it was part of a dependency group, and stuff like that.*
     *       The TODO here, implement the rest of it.                       */

    /* TODO: The profile datastructure MUST be checked at some point, cause *
     *       we're being very risky trusting it all over the place in here  */

    this.valid   = new Object();
    this.invalid = new Object();
    this.validate_invalid = new Array(); // depreciated old interface
    this.missing = new Object();
    this.unknown = new Object();
    // Extended (more detailed) lookup hashes
    this.missing_required   = new Object();
    this.missing_dependency = new Object();
    this.missing_depgroup   = new Object();

    // pre-compile the acceptable regexp test
    this.regexp_test = new RegExp('^/(.*)/(g|i|gi|ig)?$');

    // Build lookup of required and optional fields
    this.required = new Object();
    this.optional = new Object();
    if (this.isArray(profile.required)) {
        for (i in profile.required) {
            this.required[profile.required[i]] = 1;
        }
    }
    if (this.isArray(profile.optional)) {
        for (i in profile.optional) {
            this.optional[profile.optional[i]] = 1;
        }
    }

    // Check required fields
    if (this.isArray(profile.required)) {
        for (i in profile.required) {
            if (this.emptyField(frmObj, profile.required[i])) {
                this.missing[profile.required[i]] = 1;
                this.missing_required[profile.required[i]] = 1;
            }
        }
    }

    // Check dependencies
    if ( (typeof(profile.dependencies)=="object") && 
         ( !this.isArray(profile.dependencies)) ) {
        for (fieldName in profile.dependencies) {
            if (! this.emptyField(frmObj, fieldName)) {
                if (this.isArray(profile.dependencies[fieldName])) {
                    for (i in profile.dependencies[fieldName]) {
                        var dep = profile.dependencies[fieldName][i];
                        if (this.emptyField(frmObj, dep)) {
                            this.missing[dep] = 1;
                            // Create an array of missing deps keyed by field
                            if (! this.isArray(this.missing_dependency[fieldName])) {
                                this.missing_dependency[fieldName] = new Array();
                            }
                            this.missing_dependency[fieldName][this.missing_dependency[fieldName].length] = dep;
                        }
                    }
                }
            }
        }
    }

    // Check dependency groups
    if ( (typeof(profile.dependency_groups)=="object") && 
         ( !this.isArray(profile.dependency_groups)) ) {
        for (group in profile.dependency_groups) {
            if (this.isArray(profile.dependency_groups[group])) {
                var require_all = false;
                var completed   = new Array();
                var incomplete  = new Array();
                for (i in profile.dependency_groups[group]) {
                    var fieldName = profile.dependency_groups[group][i];
                    if (! this.emptyField(frmObj, fieldName)) {
                        require_all = true;
                        completed[completed.length] = fieldName;
                    }
                }
                if (require_all) {
                    var missed_depgroup = false;
                    for (i in profile.dependency_groups[group]) {
                        var fieldName = profile.dependency_groups[group][i];
                        if (this.emptyField(frmObj, fieldName)) {
                            this.missing[fieldName] = 1;
                            incomplete[incomplete.length] = fieldName;
                            missed_depgroup = true;
                        }
                    }
                    if (missed_depgroup) {
                        this.missing_depgroup[group] = new Object();
                        this.missing_depgroup[group]['completed']  = completed;
                        this.missing_depgroup[group]['incomplete'] = incomplete;
                    }
                }
            }
        }
    }

    // Check constraints
    if ( (typeof(profile.constraints)=="object") && 
         ( !this.isArray(profile.constraints)) ) {
        for (fieldName in profile.constraints) {
            // Only test stuff from 'required' or 'optional'
            if ((!this.required[fieldName]) && (!this.optional[fieldName])) {
                continue;
            }
            if (! this.emptyField(frmObj, fieldName) ) {
                // pull out this constraint(s)
                var checks;
                if (this.isArray(profile.constraints[fieldName])) {
                    checks = profile.constraints[fieldName];
                } else if ( (typeof(profile.constraints[fieldName])=="object") ||
                            (typeof(profile.constraints[fieldName])=="string") ) {
                    checks = new Array();
                    checks[0] = profile.constraints[fieldName];
                } else {
                    // TODO: possibly an unsupported constraint type, like a
                    //       subroutine reference.
                    // alert("INVALID constraint type in profile for field name ["+fieldName+"]");
                    continue;
                }
                for (i in checks) {
                    var check = checks[i];
                    // Determine waht the name and constraint are for this check
                    var c = new Object();
                    c.name       = check;
                    c.constraint = check;
                    // Constraints can be passed in directly or via hash
                    if ( (typeof(check)=="object") && 
                         ( !this.isArray(check)) ) {
                        // TODO: we don't actually support constraint_method
                        c.constraint = check.constraint_method || check.constraint;
                        c.name       = check.name;
                        c.params     = check.params;
                        c.is_method  = (check.constraint_method) ? 1 : 0; // unsupported
                    }

                    /* TODO: we curretly only support regex checks, and they must
                     * conform to javascript regex format standards (not verified here)
                     * js regex standard: http://docs.sun.com/source/816-6408-10/regexp.htm
                     * NOTE: Data::FormValidator supports extended regexes: m@^\s*(/.+/|m(.).+\2)[cgimosx]*\s*$@
                     */
                    var failedTest = false;
                    // Test for RegExp style check
                    var re_parts;
                    if (re_parts = this.regexp_test.exec(c.constraint)) {
                        var constraint = new RegExp(re_parts[1], re_parts[2]);
                        var fieldValues = this.getField(frmObj, fieldName);
                        /* NOTE: every value must pass (not one pass and all pass */
                        for (var x=0; x<fieldValues.length; x++) {
                            if (! constraint.test(fieldValues[x])) {
                                failedTest = true;
                            }
                        }

                    // Test for built in constraint
                    } else if ( this.constraints.supported(c.constraint) ||
                                this.constraints.supported('valid_'+c.constraint) ||
                                this.constraints.supported('match_'+c.constraint)    ) {
                        var constraint = this.constraints.supported(c.constraint)          ? c.constraint :
                                         this.constraints.supported("valid_"+c.constraint) ? "valid_"+c.constraint :
                                         this.constraints.supported("match_"+c.constraint) ? "match_"+c.constraint :
                                                                                             "unknown";
                        var fieldValues = this.getField(frmObj, fieldName);
                        /* NOTE: every value must pass (not one pass and all pass */
                        for (var x=0; x<fieldValues.length; x++) {
                            if (! this.constraints[constraint](fieldValues[x])) {
                                failedTest = true;
                            }
                        }

                    // TODO: we default to true for now, if the constraint
                    //       is not supported
                    } else {
                        failedTest = false;
                    }

                    // Handle constraint failures
                    if (failedTest) {
                        // this.invalid is a hash keyed by invalid field
                        // names. Value is an array of the checks it failed.
                        if (! this.isArray(this.invalid[fieldName])) {
                            this.invalid[fieldName] = new Array();
                        }
                        this.invalid[fieldName][this.invalid[fieldName].length] = c.name;
                    }
                }
            }
        }
    }

    // the older interface to validate returned things differently
    for (fieldName in this.invalid) {
        if (this.isArray(this.invalid[fieldName])) {
            var tempArray = new Array();
            tempArray[0] = fieldName;
            for (i in this.invalid[fieldName]) {
                tempArray[tempArray.length] = this.invalid[fieldName][i];
            }
            this.validate_invalid[this.validate_invalid.length] = tempArray;
        }
    }

    // Build the valid field list
    // (every field in .required or .optional, that is NOT invalid NOR missing
    for (fieldName in this.required) {
        if ( (!this.missing[fieldName]) && (!this.invalid[fieldName]) ) {
            this.valid[fieldName] = 1;
        }
    }
    for (fieldName in this.optional) {
        if ( (!this.missing[fieldName]) && (!this.invalid[fieldName]) ) {
            this.valid[fieldName] = 1;
        }
    }
};


/*********************************************************************
 *********************************************************************
 **  Data.FormValidator.Constraints                                 **
 *********************************************************************
 *********************************************************************/

/*

=head1 NAME

Data.FormValidator.Constraints - Basic sets of constraints on input profile.

=head1 SYNOPSIS

    var constraints = new Data.FormValidator.Constraints();
    if (constraints.supported('email')) {
        var match;
        if (match = constraints.email(value)) {
            // match has untainted data that is valid
        } else {
            // failed test
        }
    } else {
        // constraint is not supported
    }

=head1 DESCRIPTION

The following built in constraints are provided:

=over

=item supported

Given a constraint name, returns true if we currently support that, and false otherwise. This is handy, because code calling built in constraints does not have to change as we add new ones, as it will have a bit of introspection to this object.

NOTE: UGLY HACK: I do not know of any methods like "can" for JavaScript, but that is all that this is really trying to do.

=item email

Checks if the email LOOKS LIKE an email address. This should be sufficient
99% of the time. 

Look elsewhere if you want something super fancy that matches every possible variation
that is valid in the RFC, or runs out and checks some MX records.

=item state_or_province

This one checks if the input correspond to an american state or a canadian
province.

=item state

This one checks if the input is a valid two letter abbreviation of an 
american state.

=item province
    
This checks if the input is a two letter canadian province
abbreviation.
    
=item zip_or_postcode

This constraints checks if the input is an american zipcode or a
canadian postal code.

=item postcode

This constraints checks if the input is a valid Canadian postal code.

=item zip

This input validator checks if the input is a valid american zipcode :
5 digits followed by an optional mailbox number.

=item phone

This one checks if the input looks like a phone number, (if it
contains at least 6 digits.)

=item american_phone

This constraints checks if the number is a possible North American style
of phone number : (XXX) XXX-XXXX. It has to contains 7 or more digits.

=item cc_number

TODO: this is currently implemented, but does not work, because constraint_methods in the profile are not supported. So, because this method relies on knowing the value of two fields, it will not work yet.

This constraint references the value of a credit card type field.

 constraint_methods => {
    cc_no      => cc_number({fields => ['cc_type']}),
  }


The number is checked only for plausibility, it checks if the number could
be valid for a type of card by checking the checksum and looking at the number
of digits and the number of digits of the number.

This functions is only good at catching typos. IT DOESN'T
CHECK IF THERE IS AN ACCOUNT ASSOCIATED WITH THE NUMBER.

=item cc_exp

This one checks if the input is in the format MM/YY or MM/YYYY and if
the MM part is a valid month (1-12) and if that date is not in the past.

=item cc_type

This one checks if the input field starts by M(asterCard), V(isa),
A(merican express) or D(iscovery).

=item ip_address

This checks if the input is formatted like an IP address (v4)
    
=back

=head1 REGEXP::COMMON SUPPORT

(TODO) this is not yet supported. It will require a port of RegExp::Common over to JavaScript, whish should actually be fairly trivial.

=cut

*/
 
Data.FormValidator.Constraints = function () {
    this.state_list = " AL AK AZ AR CA CO CT DE FL GA HI ID IL IN IA KS KY LA ME MD MA MI MN MS MO MT NE NV NH NJ NM NY NC ND OH OK OR PA PR RI SC SD TN TX UT VT VA WA WV WI WY DC AP FP FPO APO GU VI ";
    this.province_list = " AB BC MB NB NF NL NS NT NU ON PE QC SK YT YK ";
};

Data.FormValidator.Constraints.prototype.supported = function (val) {
    var t = new Array();
    t['match_email']             = 1;
    t['match_state_or_province'] = 1;
    t['match_state']             = 1;
    t['match_province']          = 1;
    t['match_zip_or_postcode']   = 1;
    t['match_postcode']          = 1;
    t['match_zip']               = 1;
    t['match_phone']             = 1;
    t['match_american_phone']    = 1;
    t['match_cc_number']         = 1;
    t['match_cc_exp']            = 1;
    t['match_cc_type']           = 1;
    t['match_ip_address']        = 1;
    return t[val] ? true : false;
};

Data.FormValidator.Constraints.prototype.constraint_match_re = function (val, re, re_opt) {
    var re = new RegExp(re, re_opt);
    var re_parts;
    if (re_parts = re.exec(val)) {
        return re_parts[1];
    } else {
        return false;
    }
};

Data.FormValidator.Constraints.prototype.match_email = function (val) {
    return this.constraint_match_re(val, '^(([a-z0-9_\\.\\+\\-\\=\\?\\^\\#]){1,64}\\@(([a-z0-9\\-]){1,251}\\.){1,252}[a-z0-9]{2,4})$','i');
};
Data.FormValidator.Constraints.prototype.match_postcode = function (val) {
    return this.constraint_match_re(val, '^([ABCEGHJKLMNPRSTVXYabceghjklmnprstvxy][_\\W]*\\d[_\\W]*[A-Za-z][_\\W]*[- ]?[_\\W]*\\d[_\\W]*[A-Za-z][_\\W]*\\d[_\\W]*)$');
};
Data.FormValidator.Constraints.prototype.match_zip = function (val) {
    // js doesn't support the look-ahead (?:) : '^\\s*(\\d{5}(?:[-]\\d{4})?)\\s*$'
    return this.constraint_match_re(val, '^\\s*(\\d{5}(\\-\\d{4})?)\\s*$');
};
Data.FormValidator.Constraints.prototype.match_phone = function (val) {
    // TODO: I don't like this check, because it allows "asdfasfd123432sfdasfd23".
    //       But, it's what Data::FormValidator.pm uses.
    // js doesn't support the look-ahead (?:) : '^((?:\\D*\\d\\D*){6,})$'
    return this.constraint_match_re(val, '^((\\D*\\d\\D*){6,})$');
};
Data.FormValidator.Constraints.prototype.match_american_phone = function (val) {
    // TODO: I don't like this check, because it allows "asdfasfd123432sfdasfd23".
    //       But, it's what Data::FormValidator.pm uses.
    // js doesn't support the look-ahead (?:) : '^((?:\\D*\\d\\D*){7,})$'
    return this.constraint_match_re(val, '^((\\D*\\d\\D*){7,})$');
};
Data.FormValidator.Constraints.prototype.match_state = function (val) {
    var uc_val = val.toUpperCase();
    if (this.state_list.indexOf(" "+uc_val+" ") == -1) {
        return false;
    } else {
        return uc_val;
    }
};
Data.FormValidator.Constraints.prototype.match_province = function (val) {
    var uc_val = val.toUpperCase();
    if (this.province_list.indexOf(" "+uc_val+" ") == -1) {
        return false;
    } else {
        return uc_val;
    }
};
Data.FormValidator.Constraints.prototype.match_state_or_province = function (val) {
    var match;
    if (match = this.match_state(val)) {
        return match;
    }
    if (match = this.match_province(val)) {
        return match;
    }
    return false;
};
Data.FormValidator.Constraints.prototype.match_zip_or_postcode = function (val) {
    var match;
    if (match = this.match_zip(val)) {
        return match;
    }
    if (match = this.match_postcode(val)) {
        return match;
    }
    return false;
};

Data.FormValidator.Constraints.prototype.match_cc_number = function (the_card, card_type) {
card_type = 'visa';
    card_type = card_type || "UNKNOWN";
    var card_type_abbr = card_type.toLowerCase().charAt(0);

    // get rid of any extra cruft in the card number
    var card_re = /\D/gi;
    var new_card = the_card.toString().replace(card_re, '');

    if (new_card.length == 0) return false;

    var card_type_re = /^[admv]/i;
    if (! card_type_re.test(card_type_abbr)) return false;

    if ( (card_type_abbr == 'v' && new_card.substr(0,1) != '4') ||
         (card_type_abbr == 'm' && new_card.substr(0,1) != '5') ||
         (card_type_abbr == 'd' && new_card.substr(0,4) != '6011') ||
         (card_type_abbr == 'a' && new_card.substr(0,2) != '34' &&
                                   new_card.substr(0,2) != '37') ) {
        return false;
    }

    var card_first_digit = new_card.charAt(0);
    var card_length      = new_card.length;
    if ( (card_first_digit == '3' && card_length != 15) ||
         (card_first_digit == '4' && card_length != 13 && card_length != 16) ||
         (card_first_digit == '5' && card_length != 16) ||
         (card_first_digit == '6' && card_length != 14 && card_length != 16) ) {
        return false;
    }

    // calculate checksum.
    var the_sum = 0;
    var multiplier = 2; // alternates between 2 and 1, starting w/ 2
    for (var i=(card_length -2); i >= 0; i--) {
        var digit = parseInt(new_card.charAt(i), 10);
        var product = multiplier * digit;
        the_sum += (product > 9) ? product - 9 : product;
        multiplier = 3 - multiplier;
    }
    the_sum %= 10;
    if (the_sum) the_sum = 10 - the_sum;

    // return whether the checksum matched
    if (the_sum == new_card.charAt(card_length -1)) {
        /* NOTE: I'd feel fine returning "new_card", since we already  *
         *       make sure it was solid digits, but the below behavior *
         *       is that of Data::FormValidator.pm, and consistency is *
         *       more important than my druthers.                      */
        var final_re = /^([\d\s]*)$/;
        var re_parts;
        if (re_parts = final_re.exec(the_card)) {
            return re_parts[1];
        } else {
            return false;
        }
    } else {
        return false;
    }
};

Data.FormValidator.Constraints.prototype.match_cc_exp = function (val) {
    var matched_month;
    var matched_year;

    var re = new RegExp('^(\\d+)/(\\d+)$');
    var re_parts;
    if (re_parts = re.exec(val)) {
        matched_month = parseInt(re_parts[1],10);
        matched_year  = parseInt(re_parts[2],10);
    } else {
        return false;
    }

    if (matched_month < 1 || matched_month > 12) return false;
    if (matched_year < 1900) {
        matched_year += (matched_year < 70) ? 2000 : 1900;
    }
    var now = new Date();
    var nowMonth = now.getMonth();
    // getFullYear is only supported in js 1.3, and getYear
    // is inconsitent, but oh well.
    var nowYear = now.getYear();
    if (nowYear.toString().length < 4) {
        nowYear += 1900;
    }

    if ( (matched_year < nowYear) ||
         (matched_year == nowYear && matched_month <= nowMonth) ) {
        return false;
    }

    return "" + matched_month + "/" + matched_year;
};

Data.FormValidator.Constraints.prototype.match_cc_type = function (val) {
    return this.constraint_match_re(val, '^([admv])','i');
};

// TODO: I don't like this check, because it doesn't account
//       for non-dotted quads. But, it's what Data::FormValidator.pm uses.
Data.FormValidator.Constraints.prototype.match_ip_address = function (val) {
    var ip = this.constraint_match_re(val, '^(\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3})$');
    if (! ip) return false;

    // make sure each segment of the dotted quad is between 0 and 255
    var quad = ip.split('.', 4);
    for (var i=0; i<4; i++) {
        if ( quad[i] < 0 || quad[i] > 255 ) return false;
    }

    return ip;
};


/*

=head1 UTILITY METHODS

=head2 B<results.msgs()>

This method returns an object data structure of error messages. The exact format
is determined by parameters in the C<msgs> area of the validation profile,
described in the L<Data::FormValidator> documentation.

This method does NOT yet support the optional "controls" parameter.

The data structure returned can be accesses like so:

    var msgs = results.msgs();
    for (field in results.invalid) {
        error_text += msgs[field] + "\n";
    }

NOTE: the messages for missing data sets are very bland. You'd be better off producing your own on the fly in those cases. But, this is quite helpful with invalid data :-)

=cut

*/

/* msgs()                                                                *
 * This method returns a hash reference to error messages.               */
Data.FormValidator.Results.prototype.msgs = function (controls) {

    var profile = new Object();
    profile.prefix  = '';
    profile.missing = 'Missing';
    profile.invalid = 'Invalid';
    profile.invalid_separator = ' ';
    profile.format  = '<span style="color:red;font-weight:bold"><span class="dfv_errors">* %s</span></span>';
    profile.constraints = new Object();
    if ( (typeof(this.profile.msgs)=="object") &&
         (! this.isArray(this.profile.msgs)) ) {
        for (key in this.profile.msgs) {
            profile[key] = this.profile.msgs[key];
        }
    }

    var msgs = new Object();

    /* Add invalid messages to hash                          *
     * look at all the constraints, look up their messages   *
     * (or provide a default)                                *
     * add field + formatted constraint message to hash      */
    if (this.has_invalid()) {
        for (field in this.invalid) {
            var invalidTests = new Array();
            for (i in this.invalid[field]) {
                var invalidName = this.invalid[field][i];
                var err_msg = profile.constraints[invalidName] || profile.invalid;
                invalidTests[invalidTests.length] = err_msg;
            }
            msgs[field] = invalidTests.join( profile.invalid_separator );
        }
    }

    /* Add missing messages, if any */
    if (this.has_missing()) {
        for (field in this.missing) {
            msgs[field] = profile.missing;
        }
    }

    return msgs;
};

/*

=head2 B<results.changeStyle(formObject, fieldName, rgbColor)>

This will change the background color of all form elements by the given name in the given form, to the given color (defaults to #FFFF99).

This is an especially handy method, as you don't have to worry about how many times the form field "password" shows up on the page, nor even what type of field it is (ex. changing the background of a select list is different from a text field), and you can even have mixed types of fields with the same name.

TODO: create similar method to change the CSS class of the element.

NOTE / TODO: This method doesn't really belong in this namespace, but it provides a substantial benefit, and the supporting code library is already here, so it's likely to stick around for a while.

=cut

*/
/* Given a form object, and field name, changes the element color to badColor */
Data.FormValidator.Results.prototype.changeStyle = function (frmObj, fieldName, badColor) {
    var fieldList = this.getElementListByName(frmObj, fieldName);
    // make sure we have form elements
    if (! this.isArray(fieldList)) {
        return false;
    }

    if (! badColor.length) {
        badColor = "#FFFF99";
    }

    for (var i=0; i<fieldList.length; i++) {
        var type = this.fieldType(fieldList[i]);
        if (type == "radio") {
            // radio buttons don't support the .style method
        } else if (type == "button" || type == "reset" || type == "submit") {
            // we could change these, but we don't, cause it looks bad
        } else {
            if (fieldList[i].length) {
                var fieldObj = fieldList[i];
                /* select objects need the outter node, and each individual node changed */
                if ( type.substr(0,6) == "select" ) {
                    fieldObj.style.backgroundColor = badColor;
                }
                for (var i=0; i<fieldObj.length; i++) {
                    fieldObj[i].style.backgroundColor = badColor;
                }
            } else {
                fieldList[i].style.backgroundColor = badColor;
            }
        }
    }
    return true;
};

/*

=head2 B<results.cleanForm(formObject, rgbColor)>

Changes the background color of every element in the given form to the given color (defaults to #FFFFFF).

Useful to call prior to processing all the invalid fields.

TODO: create similar method to change the CSS class of the element.

NOTE / TODO: This method doesn't really belong in this namespace, but it provides a substantial benefit, and the supporting code library is already here, so it's likely to stick around for a while.

=cut

*/
/* Given a form object, changes all element colors to goodColor */
Data.FormValidator.Results.prototype.cleanForm = function (frmObj, goodColor) {
    if (! goodColor.length) {
        goodColor = "#FFFFFF";
    }

    var el,e = 0;
    while (el = frmObj.elements[e++]) {
        var type = this.fieldType(el);
        // radio buttons don't support the .style method
        // we could change these others, but we don't, cause it looks bad
        if (type != "radio" && type != "button" && 
            type != "reset" && type != "submit"    ) {
            if (el.length) { // for select-*
                /* select objects need the outter node, and each individual node changed */
                if ( type.substr(0,6) == "select" ) {
                    el.style.background = goodColor;
                }
                for (var i=0; i<el.length; i++) {
                    el[i].style.background = goodColor;
                }
            } else {
                el.style.background = goodColor;
            }
        }
    }
};



/*********************************************************************
 *********************************************************************
 ****                                                             ****
 ****   Below be only internal methods.                           ****
 ****                                                             ****
 *********************************************************************
 *********************************************************************/

/*

=head1 INTERNAL METHODS

The following methods are only noted here so you know of their existence. They are used internally to the Data.FormValidator.Results object. If you find them useful for other purposes, feel free to yank them out and do as you wish (within the bound of the license agreement of course).

=over

=item B<getElementListByName(frmObj, elementName)>

Takes the form object, and a form element name
Returns an array of elements, or false if it doesn't exist.

=item B<isArray(thisObject)>

verify that something is an array

=item B<isValidObject(thisObject)>

verify that an object exists and is valid

=item B<hasSelected(selectObj)>

return array of selected item values, or false if nothing was selected

NOTE: this method has some work around for the broken IE 5, 5.5, and 6. The work arounds currently make all platforms behave less than perfect, as they currently do not include any browser detection. TODO: add browser detection.

=item B<hasChecked(checkboxObj)>

Dispatch off to hasRadioOrCheckbox

=item B<hasRadio(radioObj)>

Dispatch off to hasRadioOrCheckbox

=item B<hasRadioOrCheckbox(thisObj)>

return array of selected item values, or false if nothing was selected

=item B<hasMCEText(mceObj)>

return array of text values, with empty elements if the field(s) are blank

=item B<hasText(textObj)>

return array of text values, with empty elements if the field(s) are blank

=item B<blankText(textObj)>

step through a string, and see if it's nothing but blank

=item B<fieldType(Obj)>

method to determine type of form field. We use this, cause we support meta types like tinymce.

NOTE: MUST pass in a single form element, not some jacked up frmObj['field'] thing.

=item B<emptyField(frmObj, fieldName)>

dispatching function - sends check to appropriate typed check

returns true if the field is empty

=item B<getField(frmObj, fieldName)>

dispatching function - snags the data for the requested field (all instances of such named field).
NOTE: this always returns an array

=back

=cut

*/

/* Takes the form object, and a form element name              *
 * Returns an array of elements, or false if it doesn't exist. */
Data.FormValidator.Results.prototype.getElementListByName = function (frmObj, elementName) {
    var elList = new Array();
    if ( (!frmObj.length) || (frmObj.length <= 0) ) {
        return false; // bad form passed in
    }
    var el,e = 0;
    while (el = frmObj.elements[e++]) {
        // don't have to worry about el.length, cause each individual is returned.
        if (el.name == elementName) {
            elList[elList.length] = el;
        }
    }
    return (elList.length > 0) ? elList : false;
};

/* verify that something is an array */
Data.FormValidator.Results.prototype.isArray = function (thisObject) {
    return this.isValidObject(thisObject) && thisObject.constructor == Array;
};

/* verify that an object exists and is valid */
Data.FormValidator.Results.prototype.isValidObject = function (thisObject) {
    if (null == thisObject) {
        return false;
    } else if ('undefined' == typeof(thisObject) ) {
        return false;
    } else {
        return true;
    }
};

/* return array of selected item values, or false if nothing was selected */
Data.FormValidator.Results.prototype.hasSelected = function (selectObj) {
    /* TODO: add browser detection to make this better */
    /* hasSelected() NOTES:                                                                *
     *   In IE, if value= is not explicitly set, it will NOT fall back to text.            *
     *   We have a semi-complex way of compensating ...                                    *
     *   If the .value is populated (.value.length > 0) we use that.                       *
     *   If the .value.length == 0 (or false), then we see if we should use the .text      *
     *       - If selectedIndex == 0, we use the blank .value                              *
     *       - If selectedIndex > 0,  we use the the .text                                 */
    var allData = new Array();
    if (selectObj.type.indexOf("multiple")!=-1) {
        for (var a=0; a<selectObj.options.length; a++) {
            /* if select AND not blank, add to allData */
            var t_value = (a == 0)                            ?
                              selectObj.options[a].value      :
                          (selectObj.options[a].value.length) ?
                              selectObj.options[a].value      :
                              selectObj.options[a].text       ;
            if (selectObj.options[a].selected &&
                (! this.blankText(t_value) ) ) {
                allData[allData.length] = t_value; // add to end
            }
        }
    } else if (selectObj.options.selectedIndex.toString().length>0) {
        /* NOTE: In IE, if value= is not explicitly set, it will NOT fall back to text */
        var t_index = selectObj.options.selectedIndex;
        var t_value = (t_index == 0)                            ?
                          selectObj.options[t_index].value      :
                      (selectObj.options[t_index].value.length) ?
                          selectObj.options[t_index].value      :
                          selectObj.options[t_index].text       ;
        if (! this.blankText(t_value) ) {
            allData[allData.length] = t_value;
        }
    }

    return (allData.length > 0) ? allData : false;
};

Data.FormValidator.Results.prototype.hasChecked = function (checkboxObj) {
    return this.hasRadioOrCheckbox(checkboxObj);
};
Data.FormValidator.Results.prototype.hasRadio = function (radioObj) {
    return this.hasRadioOrCheckbox(radioObj);
};
/* return array of selected item values, or false if nothing was selected */
Data.FormValidator.Results.prototype.hasRadioOrCheckbox = function (thisObj) {
    /* return checked state */
    var allData = new Array();
    if (thisObj.checked) {
        allData[allData.length] = thisObj.value;
    }
    return (allData.length > 0) ? allData : false;
};

/* return array of text values, with empty elements if the field(s) are blank */
Data.FormValidator.Results.prototype.hasMCEText = function (mceObj) {
    var allData = new Array();
    /* If tinyMCE is loaded (we guess based on the namespace)   *
     * then we use calls from the TinyMCE library.              *
     * Otherwise, we treat this like a normal text field, and   *
     * hope for the best.                                       */
    var fieldName = mceObj.name;
    if ( typeof tinyMCE == "undefined" ) {    
        var txtData = this.hasText(mceObj);
        if (txtData) allData = txtData;
    } else {
        /* tinymce-1.x requires a focus prior to grabbing the text. *
         * In tinymce-2.x, the focus overrides "submit", which will *
         * break your form, so we should NOT use it there.          */
        if ( (typeof tinyMCE.majorVersion == "undefined") ||
             (typeof tinyMCE.majorVersion != "undefined" && tinyMCE.majorVersion < 2) ) {
            // running 1.x tinymce code
            tinyMCE.execInstanceCommand(fieldName, 'mceFocus');
        }
        allData[allData.length] = tinyMCE.getContent(tinyMCE.getEditorId(fieldName));
    }
    return (allData.length > 0) ? allData : false;
};

/* return array of text values, with empty elements if the field(s) are blank */
Data.FormValidator.Results.prototype.hasText = function (textObj) {
    var allData = new Array();
    // used to only populate on filled in fields, but
    // that conflicts with the behavior from Data::FormValidator
    // if ( ! this.blankText(textObj.value) ) {
        allData[allData.length] = textObj.value;
    // }
    return (allData.length > 0) ? allData : false;
};

/* step through a string, and see if it's nothing but blank */
Data.FormValidator.Results.prototype.blankText = function (textObj) {
    if (textObj==null) { return true; }
    for (var i=0; i<textObj.length; i++) {
        if ( (textObj.charAt(i)!=' ')  &&
             (textObj.charAt(i)!="\t") &&
             (textObj.charAt(i)!="\n") &&
             (textObj.charAt(i)!="\r")    ) {
            return false;
        }
    }
    return true;
};

/* method to determine type of form field                *
 * we use this, cause we support meta types like tinymce *
 * NOTE: MUST pass in a single form element, not some    *
 *       jacked up frmObj['field'] thing.                */
Data.FormValidator.Results.prototype.fieldType = function (Obj) {
    if (! this.isValidObject(Obj)) {
        return false;
    }
    var type = Obj.type.toString();
    /* test to see if the element is a TinyMCE element */
    if (type.substr(0,4) == "text") {
        var mce_trigger = Obj ? Obj.getAttribute("mce_editable") : "";
        /* TODO: we only support fields marked by mce_editable="true" for now */
        if (mce_trigger == "true") {
            type = "tinymce";
        }
    }
    return type;
};

/* dispatching function - sends check to appropriate typed check */
/* returns true if the field is empty */
Data.FormValidator.Results.prototype.emptyField = function (frmObj, fieldName) {
    /* grab data from getField, and then see if they're all blank */
    var dataList = this.getField(frmObj, fieldName);

    if ( !this.isArray(dataList) ) {
        return true;
    }

    var hasData = false;
    for (var i=0; i<dataList.length; i++) {
        if (! this.blankText(dataList[i]) ) {
            hasData = true;
        }
    }
    return hasData ? false : true;
};

/* dispatching function - snags the data for the requested field     *
 * (all instances of such named field).                              *
 * NOTE: this always returns an array                                */
Data.FormValidator.Results.prototype.getField = function (frmObj, fieldName) {
    var returnValue = new Array();

    var elList = this.getElementListByName(frmObj, fieldName);
    if (! this.isArray(elList)) { // make sure we have form elements
        return returnValue;
    }

    var el,e = 0;
    while (el = elList[e++]) {
        var type = this.fieldType(el);

        var dataList;
        if ( (type.substr(0,4) == "text")   || 
             (type.substr(0,4) == "pass")   ||
             (type             == "file")   ||
             (type             == "hidden") ||
             (type             == "reset")  ||
             (type             == "submit")    ) {
            /* "text" "textarea" "password" "submit" */
            dataList = this.hasText(el);

        } else if ( type == "tinymce" ) {
            /* "tinymce" overridden textarea type */
            dataList = this.hasMCEText(el);

        } else if ( type.substr(0,6) == "select" ) {
            /* "select-one" "select-multiple" */
            dataList = this.hasSelected(el);

        } else if ( type == "radio" ) {
            dataList = this.hasRadio(el);

        } else if ( type == "checkbox" ) {
            dataList = this.hasChecked(el);

        } else {
            // There should be no else!!!
            alert("FORM ERROR: element type ["+ type +"] not recognized");
        }

        if (this.isArray(dataList)) {
            for (var i=0; i<dataList.length; i++) {
                returnValue[returnValue.length] = dataList[i];
            }
        }
    }

    return returnValue;
};


/*

=head1 DEMO

A live demo is available at the developer site:

L<http://formvalidatorjs.berlios.de/>

=head1 BUGS

L<http://developer.berlios.de/bugs/?group_id=4847>

=head1 CONTRIBUTING

This project is hosted by berlios.de (a sourceforge-ish place). Patches, questions and feedback are welcome.

L<http://developer.berlios.de>

=head1 SEE ALSO

JSAN listing L<http://www.openjsan.org/doc/u/un/unrtst/Data/FormValidator/>

L<Data::FormValidator>, L<Data::FormValidator::Results>,
L<Data::FormValidator::Constraints>, L<Data::FormValidator::ConstraintsFactory>,
L<Data::FormValidator::Filters>

=head1 AUTHOR

Joshua I. Miller <jmiller@purifieddata.net>

=head1 COPYRIGHT

Copyright (c) 2005 by CallTech Communications, LLC.

Portions Copyright (c) 1999,2000 iNsu Innovations Inc.

This program is free software; you can redistribute it and/or modify
it under the terms as perl itself.

=cut

*/
