# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (c) 2006 by Meredith Lesly, Kenneth Lavrsen
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# For licensing info read LICENSE file in the TWiki root.

package TWiki::Plugins::FormPlugin;

# Always use strict to enforce variable scoping
use strict;

use TWiki::Func;
use CGI qw( :all );

#use TWiki::Plugins::FormPlugin::Validate qw(CheckFormData);
#use CGI::Validate qw(:vars);

# $VERSION is referred to by TWiki, and is the only global variable that
# *must* exist in this package
use vars qw( $VERSION $RELEASE $debug $pluginName $installWeb);
use vars
  qw( $currentTopic $currentWeb $defaultFormat $defaultTitleFormat $elementcssclass %expandedForms %substitutedForms %uncheckedForms %validatedForms %errorForms %noErrorForms %errorFields $headerDone $currentFormName );

# This should always be $Rev: 11069$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 11069$';
$RELEASE = '1.0';

# Name of this Plugin, only used in this module
$pluginName = 'FormPlugin';

$headerDone = 0;
$defaultTitleFormat = ' $t <br />';
$defaultFormat      = '<p>$titleformat $e $m $h </p>';
%expandedForms      = ();
%validatedForms     = ();
%errorForms         = ();
%noErrorForms       = ();
%uncheckedForms     = ();
%substitutedForms =
  ()
  ; # hash of forms names that have their field tokens substituted by the corresponding field values
%errorFields = ();    # for each field entry: ...

my $STATUS_NO_ERROR  = 'noerror';
my $STATUS_ERROR     = 'error';
my $STATUS_UNCHECKED = 'unchecked';
my $DEFAULT_METHOD   = 'GET';
my $FORM_SUBMIT_TAG  = 'FP_submit';
my $ACTION_URL_TAG   = 'FP_actionurl';
my $VALIDATE_TAG     = 'FP_validate';
my $MULTIPLE_TAG_ID  = '=m';
my %MULTIPLE_TYPES   = (
    'radio'    => 1,
    'select'   => 1,
    'checkbox' => 1
);
my %ERROR_STRINGS = (
    'invalid'     => '- enter a different value',
    'invalidtype' => '- enter a different value',
    'blank'       => '- please enter a value',
    'missing'     => '- please enter a value',
);
my %ERROR_TYPE_HINTS = (
    'integer' => '(a rounded number)',
    'float'   => '(a floating number)',
    'email'   => '(an e-mail address)',
);

# translate from user-friendly names to Validate.pm input
my %REQUIRED_TYPE_TABLE = (
    'int'      => 'i',
    'float'    => 'f',
    'email'    => 'e',
    'nonempty' => 's',
    'string'   => 's',
);
my $NOTIFICATION_ANCHOR_NAME     = 'FormPluginNotification';
my $ELEMENT_ANCHOR_NAME          = 'FormElement';
my $NOTIFICATION_CSS_CLASS       = 'formPluginNotification';
my $ELEMENT_GROUP_CSS_CLASS      = 'formPluginGroup';
my $ELEMENT_GROUP_HINT_CSS_CLASS = 'formPluginGroupWithHint';
my $ERROR_CSS_CLASS              = 'formPluginError';
my $TITLE_CSS_CLASS              = 'formPluginTitle';
my $HINT_CSS_CLASS               = 'formPluginHint';
my $MANDATORY_CSS_CLASS          = 'formPluginMandatory';
my $MANDATORY_STRING             = '*';

=pod

=cut

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    $currentTopic = $topic if !$currentTopic;
    $currentWeb   = $web   if !$currentWeb;

    $debug = TWiki::Func::getPluginPreferencesFlag("DEBUG")
      || TWiki::Func::getPreferencesFlag("DEBUG");

    TWiki::Func::registerTagHandler( 'STARTFORM',   \&_startForm );
    TWiki::Func::registerTagHandler( 'ENDFORM',     \&_endForm );
    TWiki::Func::registerTagHandler( 'FORMELEMENT', \&_formElement );
    TWiki::Func::registerTagHandler( 'FORMSTATUS',  \&_formStatus );

    # Plugin correctly initialized
    return 1;
}

=pod

Process form before any %STARTFORM{}% is expanded:
- substitute tokens
- validate form

Because beforeCommonTagsHandler is called multiple times while rendering, the processed forms are stored and checked each time.

=cut

sub beforeCommonTagsHandler {

    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $text, $topic, $web ) = @_;

    my $query = TWiki::Func::getCgiQuery();
    my $submittedFormName =
      $query->param($FORM_SUBMIT_TAG);    # form name is stored in submit
    if ($submittedFormName) {
        return
          if $substitutedForms{$submittedFormName}
          && $validatedForms{$submittedFormName};
    }

    # substitute values
    if ( $submittedFormName && !$substitutedForms{$submittedFormName} ) {
        _substituteFieldTokens();
        $substitutedForms{$submittedFormName} = $submittedFormName;
    }

    # validate form
    if ( $submittedFormName && !$validatedForms{$submittedFormName} ) {

        my $error = !_validateForm();
        _debug("validation: $submittedFormName: error=$error");
        if ($error) {
            $errorForms{$submittedFormName}   = 1;
            $noErrorForms{$submittedFormName} = 0;
        }
        else {
            $errorForms{$submittedFormName}   = 0;
            $noErrorForms{$submittedFormName} = 1;
        }
        $validatedForms{$submittedFormName} = 1;
    }

}

=pod

Read form field tokens and replace them by the field values.
For instance: if a field contains the value '$about', this string is substituted
by the value of the field with name 'about'.

=cut

sub _substituteFieldTokens {

    my $query = TWiki::Func::getCgiQuery();

    # create quick lookup hash
    my @names = $query->param;
    my %keyValues;
    foreach (@names) {
        my $name = $_;
        next if !$name;
        $keyValues{$name} = $query->param($name);
    }

    foreach ( keys %keyValues ) {
        my $value = $keyValues{$_};
        $value =~ s/(\$(\w+))/$keyValues{$2}/go;
        $query->param( -name => $_, -value => $value );
    }
}

=pod

Retrieves the status of the form. Usage:

%FORMSTATUS{"form_name"}%

or

%FORMSTATUS{"form_name" status="noerror"}%
%FORMSTATUS{"form_name" status="error"}%
%FORMSTATUS{"form_name" status="unchecked"}%

=cut

sub _formStatus {
    my ( $session, $params, $topic, $web ) = @_;

    my $name = $params->{'_DEFAULT'};
    return '' if !$name;

    my $statusFormat = $params->{'status'};
    my %status       = _status($name);

    return $status{$statusFormat} || "0" if $statusFormat;
    return $STATUS_NO_ERROR if ( $noErrorForms{$name} );
    return $STATUS_ERROR    if ( $errorForms{$name} );

    # else
    return $STATUS_UNCHECKED;
}

=pod

=cut

sub _status {
    my ($formName) = @_;
    return (
        $STATUS_NO_ERROR  => $noErrorForms{$formName},
        $STATUS_ERROR     => $errorForms{$formName},
        $STATUS_UNCHECKED => !$noErrorForms{$formName} && !$errorForms{$formName},
    );
}

=pod

=cut

sub _addHeader {

    return if $headerDone;
    
    my $header = <<'EOF';
<style type="text/css" media="all">
@import url("%PUBURL%/%TWIKIWEB%/FormPlugin/formplugin.css");
</style>
EOF
    TWiki::Func::addToHEAD( 'FORMPLUGIN', $header );
    $headerDone = 1;
}

=pod

Order of actions:
- Check if this is the form that has been submitted
- Returns if the form did not validate (has been validated before this call)
- Redirects if an action url has been passed in the form

=cut

sub _startForm {
    my ( $session, $params, $topic, $web ) = @_;

    _addHeader();

    my $name = $params->{'name'};
    return if $expandedForms{$name};

    # else
    $expandedForms{$name} = 1;

    $currentFormName = $name; # retrieved for element rendering
    
    # check if the submitted form is the form at hand
    my $query             = TWiki::Func::getCgiQuery();
    my $submittedFormName = $query->param($FORM_SUBMIT_TAG);

    if ( $submittedFormName && $name eq $submittedFormName ) {
        if ( $errorForms{$submittedFormName} ) {

            # show validation error feedback above form
            return _displayErrors(@_) . _displayForm(@_);
        }

        # redirectto if an action url has been passed in the form
        my $actionurl = $query->param($ACTION_URL_TAG);
        if ($actionurl) {

            # delete temporary parameters
            $query->delete($ACTION_URL_TAG);

# do not delete param $FORM_SUBMIT_TAG as we might want to know if this form is validated
            TWiki::Func::redirectCgiQuery( undef, $actionurl, 1 );
            return;
        }
    }

    return _displayForm(@_);
}

=pod

Returns 1 when validation is ok; 0 if an error has been found.

=cut

sub _validateForm {

    eval 'use TWiki::Plugins::FormPlugin::Validate';

    # Some fields might need to be validated
    # this is set with parameter =validate="s"= in %FORMELEMENT%
    # during parsing of %FORMELEMENT% this has been converted to
    # a new hidden field $VALIDATE_TAG_fieldname

    my $query = TWiki::Func::getCgiQuery();
    my @names = $query->param;
    my %validateFields;
    my $order = 0;
    foreach (@names) {
        my $name = $_;
        next if !$name;

        # the (hidden) field that has set the validation type
        # can be recognized by $VALIDATE_TAG_fieldname
        my $isSettingField = $name =~ m/^$VALIDATE_TAG\_(.+?)$/go;
        if ($isSettingField) {

            # create hash entry:
            # string_fieldname+validation_type => reference_field
            my $fieldName             = $1;
            my $nameAndvalidationType = $query->param($name);
            $nameAndvalidationType =~ s/^(.*?)(\=m)*$/$1/go;
            my $isMultiple = $2 if $2;

            # append order argument
            $nameAndvalidationType .= '=' . $order++;
            if ($isMultiple) {
                my @fieldNameRef;
                $validateFields{$nameAndvalidationType} = \@fieldNameRef
                  if $nameAndvalidationType;
            }
            else {
                my $fieldNameRef;
                $validateFields{$nameAndvalidationType} = \$fieldNameRef
                  if $nameAndvalidationType;
            }
        }
    }

    # return all fine if nothing to be done
    return 1 if !keys %validateFields;

    # allow some fields not to be validated
    # otherwise we get errors on hidden fields we have inserted ourselves
    $TWiki::Plugins::FormPlugin::Validate::IgnoreNonMatchingFields = 1;

    # not need to check for all form elements
    $TWiki::Plugins::FormPlugin::Validate::Complete = 1;

    # test fields
    TWiki::Plugins::FormPlugin::Validate::GetFormData(%validateFields);

    if ($TWiki::Plugins::FormPlugin::Validate::Error) {

        # store field name refs
        for my $href (@TWiki::Plugins::FormPlugin::Validate::ErrorFields) {
            my $fieldNameForRef = $href->{'field'};
            $errorFields{$fieldNameForRef} = 1;
        }
        return 0;
    }

    return 1;
}

=pod

=cut

sub _displayErrors {
    my ( $session, $params, $topic, $web ) = @_;

    

    if (@TWiki::Plugins::FormPlugin::Validate::ErrorFields) {
        my $note = " *Some fields are not filled in correctly:* ";
        my @sortedErrorFields =
          sort { $a->{order} cmp $b->{order} }
          @TWiki::Plugins::FormPlugin::Validate::ErrorFields;
        for my $href (@sortedErrorFields) {
            my $errorType = $href->{'type'};
            my $fieldName = $href->{'field'};
_debug("_displayErrors fieldName=$fieldName");
            my $errorString = $ERROR_STRINGS{$errorType} || '';
            my $expected = $href->{'expected'};
            my $expectedString =
              $expected ? ' ' . $ERROR_TYPE_HINTS{$expected} : '';
            $errorString .= $expectedString;
            my $anchor = _anchorLink($fieldName);

            # preserve state information
            my $currentUrl = _currentUrl(@_);
            $note .=
"\n   * <a href=\"$currentUrl$anchor\">$fieldName</a> $errorString";
        }
        return _wrapHtmlError($note) if scalar @sortedErrorFields;
    }
    return '';
}

=pod

With GET, retrieves the url parameters if any.
With POST, ignores url parameters.

=cut

sub _currentUrl {
    my ( $session, $params, $topic, $web ) = @_;

    my $method     = _method( $params->{'method'} );
    my $currentUrl = CGI::url( -path_info => 1 );
    my $parameters = '';
    if ( $method eq 'GET' ) {
        $parameters = CGI::url( -query => 1 );
        if ( $currentUrl =~ m/$parameters/go ) {

            # complete match, so no url parameters
        }
        else {
            $parameters =~ s/^(.*?)(\?.*?)$/$2/go;

            # make url uniform to urls
            $parameters =~ s/;/&/go;

            # strip private parameters
            $parameters =~ s/(&\.[^&|^$|^#]*)//go;
            $currentUrl .= $parameters;
        }
    }
    return $currentUrl;
}

=pod

=cut

sub _method {
    my ($method) = @_;

    $method ||= $DEFAULT_METHOD;
    return $method;
}

=pod


=cut

sub _displayForm {
    my ( $session, $params, $topic, $web ) = @_;

    my $name = $params->{'name'};

    my $actionParam = $params->{'action'};
    my $method      = _method( $params->{'method'} );
    my $redirectto  = $params->{'redirectto'} || '';
    $elementcssclass = $params->{'elementcssclass'} || '';
    my $formcssclass = $params->{'formcssclass'} || '';
    my $webParam     = $params->{'web'};
    my $topicParam   = $params->{'topic'};
    my $anchor       = $params->{'anchor'} || $NOTIFICATION_ANCHOR_NAME;
    
    if ($topicParam) {
        ( $web, $topic ) =
          TWiki::Func::normalizeWebTopicName( $webParam, $topicParam );
    }
    else {
        $web   = $currentWeb;
        $topic = $currentTopic;
    }

    my $actionUrl = '';
    if ( $actionParam eq 'save' ) {
        $actionUrl = "%SCRIPTURL{save}%/$web/$topic";
    }
    elsif ( $actionParam eq 'edit' ) {
        $actionUrl = "%SCRIPTURL{edit}%/$web/$topic";
    }
    elsif ( $actionParam eq 'view' ) {
        $actionUrl = "%SCRIPTURL{view}%/$web/$topic";
    }
    elsif ( $actionParam eq 'viewauth' ) {
        $actionUrl = "%SCRIPTURL{viewauth}%/$web/$topic";
    }
    else {
        $actionUrl = $actionParam;
    }

    my $currentUrl = _currentUrl(@_);
    $currentUrl .= '#' . $anchor;

    my $formStart = CGI::start_form(
        -name   => $name,
        -method => $method,
        -action =>
          $currentUrl  # first post to current topic and retrieve dynamic values
    );

    my $formClassAttr = $formcssclass ? " class=\"$formcssclass\"" : '';
    $formStart .= "<div$formClassAttr>\n<!--FormPlugin form start-->";

    $formStart .= "\n"
      . CGI::hidden(
        -name    => $ACTION_URL_TAG,
        -default => $actionUrl
      ) if $actionUrl;

    # store name reference in form so it can be retrieved after submitting
    $formStart .= "\n"
      . CGI::hidden(
        -name    => $FORM_SUBMIT_TAG,
        -default => $name
      );

    $formStart .= "\n"
      . CGI::hidden(
        -name    => 'redirectto',
        -default => $redirectto
      ) if $redirectto;

    return $formStart;
}

=pod

=cut

sub _endForm {
    my ( $session, $params, $topic, $web ) = @_;

    return '</div><!--/FormPlugin form end-->' . CGI::end_form();
}

=pod

Lifted out:
# needs to be tested more
    my $formcondition = $params->{'formcondition'};

    if ($formcondition) {
        $formcondition =~ m/^(.*?)\.(.*?)$/;
        my ( $formName, $conditionStatus ) = ( $1, $2 );
        my %status = _status($formName);
        return '' unless isTrue( $status{$conditionStatus} );
        
        my $query = TWiki::Func::getCgiQuery();
        my $default          = $params->{'default'};
        $query->param( -name => $name, -value => $default );
        _debug("test: " . $query->param($name));
    }

| =formcondition= | Display only if the form condition is true. Condition syntax: =form_name.contition_status=, where =contition_status= is one of =unchecked=, =error= or =noerror= |- |- | =formcondition="Mailform.noerror"= |
=cut

sub _formElement {
    my ( $session, $params, $topic, $web ) = @_;

    my $element       = _getFormElementHtml(@_);
    my $type          = $params->{'type'};
    my $name          = $params->{'name'};


    my $format = $params->{'format'} || $defaultFormat;
    if ( $type eq 'hidden' ) {
        $format = '$e';
        $format =~ s/\$e/$element/go;
        $format = _renderFormattingTokens($format);
        return $format;
    }

    my $title = $params->{'title'};
    my $hint = $params->{'hint'} || '';

    $title = _wrapHtmlTitleContainer($title) if $title;

    my $mandatoryParam = $params->{'mandatory'};
    my $isMandatory = isTrue( $mandatoryParam, 0 );
    my $mandatory =
      $isMandatory ? _wrapHtmlMandatoryContainer($MANDATORY_STRING) : '';

    my $titleformat = $params->{'titleformat'} || $defaultTitleFormat;
    $format =~ s/\$titleformat/$titleformat/go if $title;
    $format =~ s/\$e\b/$element/go;
    $format =~ s/\$t\b/$title/go                             if $title;
    $format =~ s/\$m\b/$mandatory/go;

    $hint = _wrapHtmlHintContainer($hint) if $hint;
    $format =~ s/\$h\b/$hint/go;
    my $hintCssClass = $hint ? ' ' . $ELEMENT_GROUP_HINT_CSS_CLASS : '';
    $format =~ s/\$_h/$hintCssClass/go;

    # clean up tokens if no title
    $format =~ s/\$titleformat//go;
    $format = _renderFormattingTokens($format);

    if ( $elementcssclass && $type ne 'hidden' ) {
        my $classAttr = ' class="' . $elementcssclass . '"';
        $format = '<div class="' . $elementcssclass . '">' . $format . '</div>';
    }

    my $validationTypeParam = $params->{'validate'};
    my $validationType =
      $validationTypeParam ? $REQUIRED_TYPE_TABLE{$validationTypeParam} : '';
    if ( !$validationTypeParam && $mandatoryParam ) {
        $validationType = 's';    # non-empty
    }
    if ($validationType) {
        my $validate = '=' . $validationType;
        my $multiple = $MULTIPLE_TYPES{$type} ? $MULTIPLE_TAG_ID : '';
        $format .= "\n"
          . CGI::hidden(
            -name    => $VALIDATE_TAG . '_' . $name,
            -default => "$name$validate$multiple"
          );
    }

    # error?
    my %formStatus = _status($currentFormName);
    if ( $formStatus{$STATUS_ERROR} && $name && $errorFields{$name} ) {
        $format = _wrapHtmlErrorContainer($format);
    }

    # add anchor so individual fields can be targeted from any
    # error feedback
    $format = '#' . _anchorLink($name) . "\n" . $format;

    return $format;
}

=pod

=cut

sub _anchorLink {
    my ($name) = @_;

    my $anchorName = $name || '';
    $anchorName =~ s/[[:punct:][:space:]]//go;
    return $ELEMENT_ANCHOR_NAME . $anchorName;
}

=pod

=cut

sub _getFormElementHtml {
    my ( $session, $params, $topic, $web ) = @_;

    my $name           = $params->{'name'} || '';
    my $type           = $params->{'type'};
    my $hasMultiSelect = $type =~ m/^(.*?)multi$/;
    $type =~ s/^(.*?)multi$/$1/;
    my $value = $params->{'default'} || $params->{'buttonlabel'};

    my $size = $params->{'size'} || '40';
    my $maxlength = $params->{'maxlength'};
    $size = $maxlength if defined $maxlength && $maxlength < $size;

    my ( $options, $labels ) =
      _parseOptions( $params->{'options'}, $params->{'labels'} );

    my $itemformat = $params->{'elementformat'};
    my $class      = $params->{'class'};

    my $selectedoptions = $params->{'default'} || undef;
    my $isMultiple = $MULTIPLE_TYPES{$type};
    if ($isMultiple) {
        my @values = param($name);
        $selectedoptions ||= join( ",", @values );
    }
    else {
        $selectedoptions ||= param($name);
    }

    my $element = '';
    if ( $type eq 'text' ) {
        $element =
          _getTextFieldHtml( $session, $name, $value, $size, $maxlength,
            $class );
    }
    elsif ( $type eq 'password' ) {
        $element =
          _getPasswordFieldHtml( $session, $name, $value, $size, $maxlength,
            $class );
    }
    elsif ( $type eq 'submit' ) {
        $element = _getSubmitButtonHtml( $session, $name, $value, $class );
    }
    elsif ( $type eq 'radio' ) {
        $element =
          _getRadioButtonGroupHtml( $session, $name, $options, $labels,
            $selectedoptions, $itemformat, $class );
    }
    elsif ( $type eq 'checkbox' ) {
        $element =
          _getCheckboxButtonGroupHtml( $session, $name, $options, $labels,
            $selectedoptions, $itemformat, $class );
    }
    elsif ( $type eq 'select' ) {
        $element =
          _getSelectHtml( $session, $name, $options, $labels, $selectedoptions,
            $size, $hasMultiSelect, $class );
    }
    elsif ( $type eq 'dropdown' ) {

        # just a select box with size of 1 and no multiple
        $element =
          _getSelectHtml( $session, $name, $options, $labels, $selectedoptions,
            '1', undef, $class );
    }
    elsif ( $type eq 'textarea' ) {
        my $rows = $params->{'rows'};
        my $cols = $params->{'cols'};
        $element =
          _getTextareaHtml( $session, $name, $value, $rows, $cols, $class );
    }
    elsif ( $type eq 'hidden' ) {
        $element = _getHiddenHtml( $session, $name, $value );
    }
    return $element;
}

=pod

=cut

sub _parseOptions {
    my ( $inOptions, $inLabels ) = @_;

    return ( '', '' ) if !$inOptions;

    my @optionPairs = split( /\s*,\s*/, $inOptions );
    my @optionList;
    my @labelList;
    foreach my $item (@optionPairs) {
        my $label;
        if ( $item =~ m/^(.*?[^\\])=(.*)$/ ) {
            ( $item, $label ) = ( $1, $2 );
        }
        $item =~ s/\\=/=/g;
        push( @optionList, $item );
        push( @labelList, $label ) if $label;
    }
    my $options = join( ",", @optionList );
    my $labels  = join( ",", @labelList );

    $labels ||= $inLabels;

    return ( $options, $labels );
}

=pod

=cut

sub _renderFormattingTokens {
    my ($text) = @_;

    $text =~ s/\$nop//go;
    $text =~ s/\$n/\n/go;
    $text =~ s/\$percnt/%/go;
    $text =~ s/\$dollar/\$/go;
    $text =~ s/\$quot/\"/go;

    return $text;
}

=pod

=cut

sub _getTextFieldHtml {
    my ( $session, $name, $value, $size, $maxlength, $class ) = @_;

    my $cssClass = $class || 'twikiInputField';
    return CGI::textfield(
        -name      => $name,
        -value     => $value,
        -size      => $size,
        -maxlength => $maxlength,
        -class     => $cssClass
    );
}

=pod

=cut

sub _getPasswordFieldHtml {
    my ( $session, $name, $value, $size, $maxlength, $class ) = @_;

    return CGI::password_field(
        -name      => $name,
        -value     => $value,
        -size      => $size,
        -maxlength => $maxlength,
        -class     => $class
    );
}

=pod

=cut

sub _getHiddenHtml {
    my ( $session, $name, $value ) = @_;

    return CGI::hidden( -name => $name, -value => $value );
}

=pod

=cut

sub _getSubmitButtonHtml {
    my ( $session, $name, $value, $class ) = @_;

    my $id       = $name  || undef;
    my $cssClass = $class || 'twikiSubmit';

    if ($id) {
        return CGI::submit(
            -name  => $name,
            -value => $value,
            -id    => $id,
            -class => $cssClass
        );
    }
    else {
        return CGI::submit(
            -name  => $name,
            -value => $value,
            -class => $cssClass
        );
    }
}

=pod

=cut

sub _getTextareaHtml {
    my ( $session, $name, $value, $rows, $cols, $class ) = @_;

    my $cssClass = $class || 'twikiInputField';
    return CGI::textarea(
        -name    => $name,
        -default => $value,
        -rows    => $rows,
        -columns => $cols,
        -class   => $cssClass
    );
}

=pod

=cut

sub _getCheckboxButtonGroupHtml {
    my ( $session, $name, $options, $labels, $selectedoptions, $itemformat,
        $class )
      = @_;

    my @optionList = split( /\s*,\s*/, $options );
    $labels = $options if !$labels;
    my @selectedValueList = split( /\s*,\s*/, $selectedoptions );
    my @labelList         = split( /\s*,\s*/, $labels );
    my %labels;
    @labels{@optionList} = @labelList;

    # ideally we would use CGI::checkbox_group, but this does not
    # generate the correct labels
    # my @checkboxes = CGI::checkbox_group(-name=>$name,
    #                            -values=>\@optionList,
    #                            -default=>\@selectedValueList,
    #                            -linebreak=>'false',
    #                            -labels=>\%labels);

    # so we roll our own while keeping the same interface
    my @items = _checkbox_group(
        -name      => $name,
        -values    => \@optionList,
        -default   => \@selectedValueList,
        -linebreak => 'false',
        -labels    => \%labels
    );

    return _wrapHtmlGroupContainer(
        _mapToItemFormatString( \@items, $itemformat ) );
}

=pod

=cut

sub _checkbox_group {
    my (%options) = @_;

    $options{-type} = 'checkbox';
    return _group(%options);
}

=pod

=cut

sub _getRadioButtonGroupHtml {
    my ( $session, $name, $options, $labels, $selectedoptions, $itemformat,
        $class )
      = @_;

    my @optionList = split( /\s*,\s*/, $options );
    $labels = $options if !$labels;
    my @selectedValueList = split( /\s*,\s*/, $selectedoptions );
    my @labelList         = split( /\s*,\s*/, $labels );
    my %labels;
    @labels{@optionList} = @labelList;
    my @items = _radio_group(
        -name      => $name,
        -values    => \@optionList,
        -default   => \@selectedValueList,
        -linebreak => 'false',
        -labels    => \%labels
    );

    return _wrapHtmlGroupContainer(
        _mapToItemFormatString( \@items, $itemformat ) );
}

=pod

=cut

sub _radio_group {
    my (%options) = @_;

    { $options{-type} = 'radio' };
    return _group(%options);
}

=pod

=cut

sub _mapToItemFormatString {
    my ( $list, $itemformat ) = @_;

    my $format = $itemformat || '$e';
    my $str = join "\n", map {
        my $formatted = $format;
        $formatted =~ s/\$e/$_/go;
        $_ = $formatted;
        $_;
    } @$list;
    return $str;
}

=pod

=cut

sub _getSelectHtml {
    my ( $session, $name, $options, $labels, $selectedoptions, $size,
        $hasMultiSelect, $class )
      = @_;

    my @optionList = split( /\s*,\s*/, $options );
    $labels = $options if !$labels;
    my @selectedValueList = split( /\s*,\s*/, $selectedoptions );
    my @labelList         = split( /\s*,\s*/, $labels );
    my %labels;
    @labels{@optionList} = @labelList;

    my $multiple = $hasMultiSelect ? 'true' : undef;
    my @items = CGI::scrolling_list(
        -name     => $name,
        -values   => \@optionList,
        -default  => \@selectedValueList,
        -labels   => \%labels,
        -size     => $size,
        -multiple => $multiple
    );

    return _mapToItemFormatString( \@items );
}

=pod

=cut

sub _group {
    my (%options) = @_;

    my $type       = $options{-type};
    my $name       = $options{-name};
    my $size       = $options{-size};
    my $values     = $options{ -values };
    my $default    = $options{-default};
    my %defaultSet = map { $_ => 1 } @$default;

    my $labels    = $options{-labels};
    my $linebreak = $options{-linebreak};

    my $optionFormat   = '';
    my $selectedFormat = '';
    if ( $type eq 'radio' ) {
        $optionFormat = '<input $attributes /><label for="$id">$label</label>';
        $selectedFormat = 'checked="checked"';
    }
    elsif ( $type eq 'checkbox' ) {
        $optionFormat = '<input $attributes /><label for="$id">$label</label>';
        $selectedFormat = 'checked="checked"';
    }
    elsif ( $type eq 'select' ) {
        $optionFormat   = '<option $attributes>$label</option>';
        $selectedFormat = 'selected="selected"';
    }

    my @elements;

    foreach (@$values) {
        my $value = $_;
        my $label = $labels->{$value};

        my %attributes = ();
        if ( $type eq 'radio' || $type eq 'checkbox' ) {
            $attributes{'type'} = $type;
        }
        if ( $type eq 'radio' || $type eq 'checkbox' ) {
            $attributes{'name'} = $name;
        }
        $attributes{'value'} = $value;
        my $id = $name . '_' . $value;    # use group name to prevent doublures
        $id =~ s/ /_/go;
        $attributes{'id'} = $id;
        my $attributeString = _getAttributeString(%attributes);

        my $selected = '';
        $selected = $selectedFormat if $defaultSet{$value};

        my $selectedAttributeString = "$attributeString $selected";
        $selectedAttributeString =~ s/ +/ /go;    # remove extra spaces

        my $element = $optionFormat;
        $element =~ s/\$attributes/$selectedAttributeString/go;
        $element =~ s/\$label/$label/go;
        $element =~ s/\$id/$id/go;

        push( @elements, $element );
    }

    return @elements;
}

=pod

=cut

sub _getAttributeString {
    my (%attributes) = @_;

    my @propertyList = map "$_=\"$attributes{$_}\"", sort keys %attributes;
    return join( " ", @propertyList );
}

=pod

=cut

sub _wrapHtmlError {
    my ($text) = @_;

    my $errorIconUrl = "%PUBURL%/%TWIKIWEB%/FormPlugin/error.gif";
    my $errorIconImgTag =
      '<img src="' . $errorIconUrl . '" alt="" width="16" height="16" />';
    return "#$NOTIFICATION_ANCHOR_NAME\n"
      . '<div id="'
      . $ERROR_CSS_CLASS
      . '" class="'
      . $NOTIFICATION_CSS_CLASS . '">'
      . $errorIconImgTag
      . $text
      . '</div>' . "\n";
}

=pod

=cut

sub _wrapHtmlGroupContainer {
    my ($text) = @_;

    return '<fieldset class="'
      . $ELEMENT_GROUP_CSS_CLASS . '$_h">'
      . $text
      . '</fieldset>';
}

=pod

=cut

sub _wrapHtmlErrorContainer {
    my ($text) = @_;

    return '<div class="' . $ERROR_CSS_CLASS . '">' . $text . '</div>';
}

=pod

=cut

sub _wrapHtmlTitleContainer {
    my ($text) = @_;

    return '<span class="' . $TITLE_CSS_CLASS . '">' . $text . '</span>';
}

=pod

=cut

sub _wrapHtmlHintContainer {
    my ($text) = @_;

    return '<span class="' . $HINT_CSS_CLASS . '">' . $text . '</span>';
}

=pod

=cut

sub _wrapHtmlMandatoryContainer {
    my ($text) = @_;

    return '<span class="' . $MANDATORY_CSS_CLASS . '">' . $text . '</span>';
}

=pod

=cut

sub _debug {
    TWiki::Func::writeDebug(@_);
}

=pod

Will be replaced by TWiki::Func::isTrue

=cut

sub isTrue {
    my( $value, $default ) = @_;

    $default ||= 0;

    return $default unless defined( $value );

    $value =~ s/^\s*(.*?)\s*$/$1/gi;
    $value =~ s/off//gi;
    $value =~ s/no//gi;
    $value =~ s/false//gi;
    return ( $value ) ? 1 : 0;
}

1;
