# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (c) 2007-2010 Arthur Clemens, Sven Dowideit, Eugen Mayer
# Copyright (C) 2007-2010 TWiki Contributor. All Rights Reserved.
# TWiki Contributors listed in the AUTHORS file in the root of
# this distribution. NOTE: Please extend that file, not this notice.
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
# For licensing info read LICENSE file in the installation root.

package TWiki::Plugins::FormPlugin;

# Always use strict to enforce variable scoping
use strict;
use warnings;

use TWiki::Func;
use CGI qw(-nosticky :all);
use Data::Dumper;    # for debugging

our $VERSION = '$Rev$';
our $RELEASE = '1.6.2';

# Name of this Plugin, only used in this module
our $pluginName = 'FormPlugin';

our $NO_PREFS_IN_TOPIC = 1;
our $SHORTDESCRIPTION = 'Lets you create simple and advanced web forms';

my $currentTopic;
my $currentWeb;
my $debug;
my $currentForm;
my $doneHeader;
my $defaultTitleFormat;
my $defaultElementFormat;
my $defaultHiddenFieldFormat;
my $expandedForms;
my $validatedForms;
my $errorForms;
my $noErrorForms;
my $substitutedForms;
; # hash of forms names that have their field tokens substituted by the corresponding field values
my $errorFields;    # for each field entry: ...
my $tabCounter;
my $SEP;
my $template;       # template text formplugin.tmpl (or a skin variant)

# constants
my $STATUS_NO_ERROR  = 'noerror';
my $STATUS_ERROR     = 'error';
my $STATUS_UNCHECKED = 'unchecked';
my $DEFAULT_METHOD   = 'post';
my $FORM_NAME_TAG    = 'FP_name';
my $ACTION_URL_TAG   = 'FP_actionurl';
my $VALIDATE_TAG     = 'FP_validate';
my $CONDITION_TAG    = 'FP_condition';
my $FIELDTITLE_TAG   = 'FP_title';
my $NO_REDIRECTS_TAG = 'FP_noredirect';
my $ANCHOR_TAG       = 'FP_anchor';

my $MULTIPLE_TAG_ID = '=m';
my $MULTIPLE_TYPES  = {
    'selectmulti' => 1,
    'checkbox'    => 1
};
my $ERROR_STRINGS;
my $ERROR_TYPE_HINTS;

# translate from user-friendly names to Validate.pm input
my $REQUIRED_TYPE_TABLE = {
    'int'      => 'i',
    'float'    => 'f',
    'email'    => 'e',
    'nonempty' => 's',
    'string'   => 's',
};
my $CONDITION_TYPE_TABLE = {
    'int'      => 'i',
    'float'    => 'f',
    'email'    => 'e',
    'nonempty' => 's',
    'string'   => 's',
};
my $NOTIFICATION_ANCHOR_NAME     = 'FormPluginNotification';
my $ELEMENT_ANCHOR_NAME          = 'FormElement';
my $NOTIFICATION_CSS_CLASS       = 'formPluginNotification';
my $ELEMENT_GROUP_CSS_CLASS      = 'formPluginGroup';
my $ELEMENT_GROUP_HINT_CSS_CLASS = 'formPluginGroupWithHint';
my $ERROR_CSS_CLASS              = 'formPluginError';
my $ERROR_ITEM_CSS_CLASS         = 'formPluginErrorItem';
my $TITLE_CSS_CLASS              = 'formPluginTitle';
my $HINT_CSS_CLASS               = 'formPluginHint';
my $MANDATORY_CSS_CLASS          = 'formPluginMandatory';
my $MANDATORY_STRING             = '*';
my $BEFORE_CLICK_CSS_CLASS       = 'twikiInputFieldBeforeClick';
my $TEXTONLY_CSS_CLASS           = 'formPluginTextOnly';

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

    _initTopicVariables(@_);

    TWiki::Func::registerTagHandler( 'STARTFORM',   \&_startForm );
    TWiki::Func::registerTagHandler( 'ENDFORM',     \&_renderHtmlEndForm );
    TWiki::Func::registerTagHandler( 'FORMELEMENT', \&_formElement );
    TWiki::Func::registerTagHandler( 'FORMSTATUS',  \&_formStatus );
    TWiki::Func::registerTagHandler( 'FORMERROR',   \&_formError );

    # Plugin correctly initialized
    return 1;
}

=pod

=cut

sub _initTopicVariables {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # Untaint is required if use locale is on
    $template =
      TWiki::Func::loadTemplate(
        TWiki::Sandbox::untaintUnchecked( lc($pluginName) ) );

    $currentTopic = $topic if !$currentTopic;
    $currentWeb   = $web   if !$currentWeb;
    $debug        = $TWiki::cfg{Plugins}{FormPlugin}{Debug};

    $currentForm     = {};
    $doneHeader      = 0;
    $defaultTitleFormat =
      TWiki::Func::expandTemplate('formplugin:format:element:title');
    $defaultElementFormat =
      TWiki::Func::expandTemplate('formplugin:format:element');
    $defaultHiddenFieldFormat =
      TWiki::Func::expandTemplate('formplugin:format:element:hidden');
    $expandedForms  = {};
    $validatedForms = {};
    $errorForms     = {};
    $noErrorForms   = {};
    $substitutedForms =
      {}; # hash of forms names that have their field tokens substituted by the corresponding field values
    $errorFields = {};     # for each field entry: ...
    $tabCounter  = 0;
    $SEP         = "\n";

    $ERROR_STRINGS = {
        'invalid' =>
          TWiki::Func::expandTemplate('formplugin:message:error:invalid'),
        'invalidtype' =>
          TWiki::Func::expandTemplate('formplugin:message:error:invalidtype'),
        'blank' =>
          TWiki::Func::expandTemplate('formplugin:message:error:blank'),
        'missing' =>
          TWiki::Func::expandTemplate('formplugin:message:error:missing'),
    };
    $ERROR_TYPE_HINTS = {
        'integer' =>
          TWiki::Func::expandTemplate('formplugin:message:hint:integer'),
        'float' =>
          TWiki::Func::expandTemplate('formplugin:message:hint:float'),
        'email' =>
          TWiki::Func::expandTemplate('formplugin:message:hint:email'),
    };
}

=pod

Called at _startForm

=cut

sub _initFormVariables {

    # form attributes we want to retrieve while parsing FORMELEMENT tags:
    undef $currentForm;
    $currentForm = {
        'name'          => 'untitled',
        'elementformat' => $defaultElementFormat,
        'elementcssclass' => '',
        'noFormHtml'    => '',
        'showErrors'    => 'above',
    };
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
      $query->param($FORM_NAME_TAG);    # form name is stored in submit

    return if !defined $submittedFormName;

    if ($submittedFormName) {

        # process only once
        return
          if $substitutedForms->{$submittedFormName}
              && $validatedForms->{$submittedFormName};
    }

    # substitute dynamic values

    if ( $submittedFormName && !$substitutedForms->{$submittedFormName} ) {
        _substituteFieldTokens();
        $substitutedForms->{$submittedFormName} = $submittedFormName;
    }

    # validate form
    if ( $submittedFormName && !$validatedForms->{$submittedFormName} ) {
        my $ok = _validateForm();
        _debug("\t ok=$ok");
        if ($ok) {
            $errorForms->{$submittedFormName}   = 0;
            $noErrorForms->{$submittedFormName} = 1;
        }
        else {
            $errorForms->{$submittedFormName}   = 1;
            $noErrorForms->{$submittedFormName} = 0;
        }
        $validatedForms->{$submittedFormName} = 1;
    }
}

=pod

_startForm( $session, $params, $topic, $web ) -> $html

Calls _renderHtmlStartForm

Order of actions:
- Check if this is the form that has been submitted
- If not, render the form start html
- Else, returns if the form did not validate (has been validated before this call)
- and redirects if an action url has been passed in the form

=cut

sub _startForm {
    my ( $session, $params, $topic, $web ) = @_;

    _debug("_startForm");

    _initFormVariables();
    _addHeader();

    my $name = $params->{'name'} || '';

    # do not expand the form tag twice
    return '' if $expandedForms->{$name};

    #allow us to replace \n with something else.
    # quite a hack here, isn't it
    # FIXME
    $SEP = $params->{'sep'} if ( defined( $params->{'sep'} ) );

    # else
    $expandedForms->{$name} = 1;

    # check if the submitted form is the form at hand
    my $query             = TWiki::Func::getCgiQuery();
    my $submittedFormName = $query->param($FORM_NAME_TAG);

    if ( $submittedFormName && $name eq $submittedFormName ) {
        return _handleSubmittedForm( $session, $params, $topic, $web,
            $submittedFormName );
    }

    # else
    return _renderHtmlStartForm(@_);
}

=pod

=cut

sub _handleSubmittedForm {
    my ( $session, $params, $topic, $web, $submittedFormName ) = @_;

    _debug("_handleSubmittedForm - this is the form that has been submitted");

    my $query = TWiki::Func::getCgiQuery();
    _debug( "\t params=" . Dumper($params) );
    _debug( "\t query=" . Dumper($query) );

    my $actionUrl;
    if ( $query->param('redirectto') ) {
        $actionUrl = $query->param('redirectto');
    }
    else {
        $actionUrl = $query->param($ACTION_URL_TAG);
    }

    # strip off query and hash from url to get a clean redirect url
    $actionUrl =~ s/^([^\?\#]+).*?$/$1/;

    _debug( "\t current url=" . _currentUrl() );
    _debug("\t actionUrl=$actionUrl");

    # delete temporary parameters
    $query->delete($ACTION_URL_TAG);
    $query->delete($ANCHOR_TAG);

    $currentForm->{'showErrors'} = lc( $params->{'showerrors'} ) || 'above';

    if ( $errorForms->{$submittedFormName} || ( _currentUrl() eq $actionUrl ) )
    {

        my $startFormHtml =
          _renderHtmlStartForm( $session, $params, $currentTopic, $currentWeb );

        if ( !TWiki::Func::isTrue( $currentForm->{'showErrors'} ) ) {
            return $startFormHtml;
        }
        elsif ( $currentForm->{'showErrors'} eq 'below' ) {

            # put validation error feedback below form, so at end form
            return $startFormHtml;
        }
        else {

            # default to show validation error feedback above form

            my $errorOutput = _displayErrors(@_);
            return $errorOutput . $startFormHtml;
        }
    }

    if ( $actionUrl !~ m!^(.*?://[^/]*)! ) {

        # no absolute url, so add anchor
        $actionUrl .= '#' . $query->param($ANCHOR_TAG)
          if $query->param($ANCHOR_TAG);
    }

    $actionUrl
      ? _debug("\t want to redirect: actionUrl=$actionUrl")
      : _debug("\t no actionUrl");

    if ($actionUrl) {

        if ( _allowRedirects($actionUrl) ) {
            _debug("\t redirecting to:$actionUrl");

            # add web and topic params to the query object
            # this is needed for save actions
            my $webParam   = $params->{'web'}   || $web   || $currentWeb;
            my $topicParam = $params->{'topic'} || $topic || $currentTopic;
            my $textParam   = $query->param('text');
            ( $web, $topic ) =
              TWiki::Func::normalizeWebTopicName( $webParam, $topicParam );

            $query->param( -name => 'topic', -value => $topic );
            $query->param( -name => 'web',   -value => $web );

            TWiki::Func::redirectCgiQuery( undef, $actionUrl, 1 );
#            if ($params->{'action'} ne 'save') {
#            	# somehow a save action does not save the updated query when redirecting
#	            print "Status: 307\nLocation: $actionUrl\n\n";
#	        }

            return '';
        }
        elsif ( TWiki::Func::isTrue( $query->param($NO_REDIRECTS_TAG) ) ) {
            return _renderHtmlStartForm(@_);
        }
        else {
            my $title = _wrapHtmlErrorTitleContainer(
                TWiki::Func::expandTemplate(
                    'formplugin:message:no_redirect:title')
            );
            my $message .= _wrapHtmlErrorItem(
                TWiki::Func::expandTemplate(
                    'formplugin:message:no_redirect:body')
            );
            $message =~ s/\$url/$actionUrl/;
            return _wrapHtmlError( $title . $message )
              . _renderHtmlStartForm(@_);
        }
    }
}

=pod

_renderHtmlStartForm( $session, $params, $topic, $web ) -> $html

=cut

sub _renderHtmlStartForm {
    my ( $session, $params, $topic, $web ) = @_;

    _debug( "_renderHtmlStartForm; params=" . Dumper($params) );

    my $noFormHtml = TWiki::Func::isTrue( $params->{'noformhtml'} || 0 );
    if ($noFormHtml) {
        $currentForm->{'noFormHtml'} = 1;
        return '';
    }

    my $name   = $params->{'name'};
    my $action = $params->{'action'};

    if ( !$name && !$action ) {
        $currentForm->{'noFormHtml'} = 1;
        my $message = TWiki::Func::expandTemplate(
            'formplugin:message:author:missing_name_and_action');
        return _wrapHtmlAuthorMessage($message);
    }
    if ( !$action ) {
        $currentForm->{'noFormHtml'} = 1;
        my $message = TWiki::Func::expandTemplate(
            'formplugin:message:author:missing_action');
        $message =~ s/\$name/$name/;
        return _wrapHtmlAuthorMessage($message);
    }
    if ( !$name ) {
        $currentForm->{'noFormHtml'} = 1;
        my $message = TWiki::Func::expandTemplate(
            'formplugin:message:author:missing_name');
        $message =~ s/\$action/$action/;
        return _wrapHtmlAuthorMessage($message);
    }

    my $id = $params->{'id'} || $name;

    my $method = _method( $params->{'method'} || '' );
    $currentForm->{'elementcssclass'} = $params->{'elementcssclass'} || '';
    my $formcssclass = $params->{'formcssclass'} || '';
    my $webParam     = $params->{'web'}          || $web || $currentWeb;
    my $topicParam   = $params->{'topic'}        || $topic || $currentTopic;
    my $disableRedirect = TWiki::Func::isTrue( $params->{'noredirect'} );
    my $restAction      = $params->{'restaction'};

    my $disableValidation =
      defined $params->{'validate'} && $params->{'validate'} eq 'off' ? 1 : 0;

    # store for element rendering
    $currentForm->{'name'}              = $name;
    $currentForm->{'elementformat'}     = $params->{'elementformat'} || '';
    $currentForm->{'disableValidation'} = $disableValidation;

    ( $web, $topic ) =
      TWiki::Func::normalizeWebTopicName( $webParam, $topicParam );

    my $currentUrl = _currentUrl();

    my $actionUrl = '';
    if ( $action =~
m/^(attach|changes|configure|edit|login|logon|logos|manage|oops|preview|rdiff|rdiffauth|register|rename|resetpasswd|save|search|statistics|upload|view|viewauth|viewfile)$/
      )
    {

        # for now, assume that all scripts use script/web/topic
        $actionUrl = "%SCRIPTURL{$1}%/$web/$topic";
    }
    elsif ( $action eq 'rest' ) {
        if ( !$restAction ) {
            $currentForm->{'noFormHtml'} = 1;
            my $message = TWiki::Func::expandTemplate(
                'formplugin:message:author:missing_rest_action');
            return _wrapHtmlAuthorMessage($message);
        }
        my $restActionUrl = "/$restAction" if $restAction;
        $actionUrl = "%SCRIPTURL{rest}%$restActionUrl";
    }
    else {
        $actionUrl = $action;
    }

    my ( $urlParams, $urlParamParts ) = _urlParams();
    if ( $urlParamParts && scalar @{$urlParamParts} ) {

        # append the query string to the url
        # in case of POST, use hidden fields (see below)
        my $queryParamPartsString = join( ';', @{$urlParamParts} );
        $actionUrl .= "?$queryParamPartsString" if $queryParamPartsString;
    }

    if (   defined $params->{'anchor'}
        && $web   eq $currentWeb
        && $topic eq $currentTopic )
    {
        $currentUrl .= '#' . $params->{'anchor'};
    }
    else {
        $currentUrl .= '#' . $NOTIFICATION_ANCHOR_NAME;
    }

    # do not use actionUrl if we do not validate
    #undef $actionUrl if $disableValidation);
    undef $actionUrl if ( $disableValidation && !$action eq 'upload' );

    $actionUrl ? _debug("actionUrl=$actionUrl") : _debug("no actionUrl");

    my $onSubmit = $params->{'onSubmit'} || undef;

    my %startFormParameters = ();
    $startFormParameters{'-name'}     = $name;
    $startFormParameters{'-id'}       = $id;
    $startFormParameters{'-method'}   = $method;
    $startFormParameters{'-onSubmit'} = $onSubmit if $onSubmit;
    $startFormParameters{'-action'} =
      $disableValidation ? $actionUrl : $currentUrl;

    # multi-part is needed for upload. Why not always use it?
    #my $formStart = CGI::start_form(%startFormParameters);
    my $formStart = '<!--FormPlugin form start-->'
      . CGI::start_multipart_form(%startFormParameters);
    $formStart =~ s/\n/$SEP/go
      ; #unhappily, CGI::start_multipart_form adds a \n, which will stuff up tables.
    my $formClassAttr = $formcssclass ? " class=\"$formcssclass\"" : '';
    $formStart .= "<div$formClassAttr>";

    my @hiddenFields = ();

# don't use CGI::hidden as these fields are rendered 'sticky' in an absurd way: you cannot get rid of the query values
    push @hiddenFields, _hiddenField( $ACTION_URL_TAG, $actionUrl )
      if $actionUrl;

    # checks if we should permit redirects or not
    push @hiddenFields, _hiddenField( $NO_REDIRECTS_TAG, 1 )
      if $disableRedirect;

    # store name reference in form so it can be retrieved after submitting
    push @hiddenFields, _hiddenField( $FORM_NAME_TAG, $name );

    if ( $params->{'redirectto'} ) {
        my ( $redirectWeb, $redirectTopic ) =
          TWiki::Func::normalizeWebTopicName( '', $params->{'redirectto'} );
        my $url =
          TWiki::Func::getScriptUrl( $redirectWeb, $redirectTopic, 'view' );
        push @hiddenFields, _hiddenField( 'redirectto', $url );
    }

    push @hiddenFields, _hiddenField( $ANCHOR_TAG, $params->{'anchor'} )
      if $params->{'anchor'};

    if ( lc $method eq 'post' ) {

 # create a hidden field for each url param
 # to keep parameters like =skin=
 # we make sure not to pass POSTed params, but only the params in the url string
        while ( my ( $name, $value ) = each %{$urlParams} ) {

            # do not overwrite FormPlugin fields
            next if $name =~ m/^(FP_.*?)$/;
            push @hiddenFields, _hiddenField( $name, $value );
        }
    }

    my $hiddenFieldsString = join( "$SEP", @hiddenFields );
    $hiddenFieldsString =~ s/\n/$SEP/go if $SEP ne "\n";

    $formStart .= $hiddenFieldsString;
    return $formStart;
}

=pod

_renderHtmlEndForm( $session, $params, $topic, $web ) -> $html

=cut

sub _renderHtmlEndForm {
    my ( $session, $params, $topic, $web ) = @_;

    my $endForm = '';
    $endForm = '</div>' . CGI::end_form() . '<!--/FormPlugin form end-->'
      if !$currentForm->{'noFormHtml'};

    #_initFormVariables();

    if ( $currentForm->{'showErrors'} eq 'below' ) {
        my $errorOutput = _displayErrors(@_);
        $endForm = "$endForm$SEP$errorOutput";
    }

    $endForm =~ s/\n/$SEP/go if $SEP ne "\n";

    return $endForm;
}

=pod

Read form field tokens and replace them by the field values.
For instance: if a field contains the value '$about', this string is substituted
by the value of the field with name 'about'.

=cut

sub _substituteFieldTokens {

    my $query = TWiki::Func::getCgiQuery();
    _debug("_substituteFieldTokens");
    _debug( "query=" . Dumper($query) );

    # create quick lookup hash
    my @names = $query->param;
    my %keyValues;
    my %conditionFields = ();
    foreach my $name (@names) {
        next if !$name;
        _debug("\t name=$name");
        $keyValues{$name} = $query->param($name);
        my @value = $query->param($name);
        $keyValues{$name} = {
            value  => \@value,
            interp => join( ', ', @value )
        };
    }
    foreach ( keys %keyValues ) {
        my $name = $_;
        next if $conditionFields{$name};    # value already set with a condition
        my @values = @{ $keyValues{$_}{value} };
        my ( $referencedFieldName, $meetsCondition ) =
          _meetsCondition( $name, $values[0] )
          ;                                 # just check the first occurrence
        if ($meetsCondition) {
            s/(\$(\w+))/$keyValues{$2}{interp}/go foreach @values;
            $query->param( -name => $name, -value => \@values );
        }
        else {
            $query->param( -name => $referencedFieldName, -value => '' );
            $query->delete( [$referencedFieldName] );
            $conditionFields{$referencedFieldName} = 1;
        }
    }

    _debug( "QQQ END OF SUB query=" . Dumper($query) );

}

=pod

_meetsCondition( $fieldName, $nameAndValidationType ) -> ( $referencedFieldName, $success )

Checks if a field value meets the condition of a referenced field.
For instance:

User input is:
%FORMELEMENT{
name="comment_from_date"
condition="$comment_from_date_input=nonempty"
}%

This has been parsed to:
(hidden) field name: FP_condition_comment_from_date
(hidden) field value: =comment_from_date=s

=cut

sub _meetsCondition {
    my ( $fieldName, $nameAndValidationType ) = @_;

    _debug(
"\t _meetsCondition: fieldName=$fieldName; nameAndValidationType=$nameAndValidationType"
    );

    if ( !( $fieldName =~ m/^$CONDITION_TAG\_(.+?)$/go ) ) {
        _debug("\t\t no condition, so pass");
        return ( $fieldName, 1 );    # no condition, so pass
    }
    else {
        $fieldName = $1;
    }

    my $isValid = 0;

    # string_fieldname+validation_type => reference_field
    if ( $nameAndValidationType =~ m/^(.*)\=(.*?)$/ ) {
        my $referencedFieldName = $1;
        my $type = $2 || '';

        my $query                = TWiki::Func::getCgiQuery();
        my $referencedFieldValue = $query->param($referencedFieldName);

        if ( defined $referencedFieldValue ) {
            if ( $type eq 's' ) {
                $isValid = _checkForString($referencedFieldValue);
            }
            elsif ( $type eq 'i' ) {
                $isValid = _checkForInt($referencedFieldValue);
            }
            elsif ( $type eq 'f' ) {
                $isValid = _checkForFloat($referencedFieldValue);
            }
            elsif ( $type eq 'e' ) {
                $isValid = _checkForEmail($referencedFieldValue);
            }
            else {
                $isValid = _checkForString($referencedFieldValue);
            }
        }
    }

    return ( $fieldName, $isValid );
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

    return ( $status{$statusFormat} || "0" ) if $statusFormat;
    return $STATUS_NO_ERROR if ( $noErrorForms->{$name} );
    return $STATUS_ERROR    if ( $errorForms->{$name} );

    # else
    return $STATUS_UNCHECKED;
}

=pod

Retrieves the error message of the form. Usage:

%FORMERROR{"form_name"}%

=cut

sub _formError {
    my ( $session, $params, $topic, $web ) = @_;

    my $name = $params->{'_DEFAULT'};
    return '' if !$name;

    return _displayErrors(@_);
}

=pod

=cut

sub _status {
    my ($formName) = @_;

    return (
        $STATUS_NO_ERROR  => $noErrorForms->{$formName},
        $STATUS_ERROR     => $errorForms->{$formName},
        $STATUS_UNCHECKED => !$noErrorForms->{$formName}
          && !$errorForms->{$formName},
    );
}

=pod

=cut

sub _addHeader {
    return if $doneHeader;
    $doneHeader = 1;

    my $header = TWiki::Func::expandTemplate('formplugin:header');
    TWiki::Func::addToHEAD( $pluginName, $header );
}

=pod

Returns 1 when validation is ok; 0 if an error has been found.

=cut

sub _validateForm {

    _debug("_validateForm");
    use TWiki::Plugins::FormPlugin::Validate qw(GetFormData);

    # Some fields might need to be validated
    # this is set with parameter =validate="s"= in %FORMELEMENT%
    # during parsing of %FORMELEMENT% this has been converted to
    # a new hidden field $VALIDATE_TAG_fieldname
    my $query = TWiki::Func::getCgiQuery();

    #_debug("query=" . Dumper($query));

    my @names          = $query->param;
    my $validateFields = {};
    my $order          = 0;
    foreach my $name (@names) {
        next if !$name;

        # the (hidden) field that has set the validation type
        # can be recognized by $VALIDATE_TAG_fieldname
        my $isSettingField = $name =~ m/^$VALIDATE_TAG\_(.+?)$/go;
        _debug("\t isSettingField=$isSettingField");
        if ($isSettingField) {
            my $referencedField       = $1;
            my $nameAndValidationType = $query->param($name);
            _createValidationFieldEntry( $validateFields, $referencedField,
                $nameAndValidationType, $order++ );
        }
    }

    _debug( "\t validateFields=" . Dumper($validateFields) );

    # return all fine if nothing to be done
    return 1 if !keys %{$validateFields};

    my $ok = _validateFormFields($validateFields);
    $ok ? _debug("\t validation ok") : _debug("\t validation error found");
    if ( !$ok ) {

        # store field name refs
        for my $href (@TWiki::Plugins::FormPlugin::Validate::ErrorFields) {
            my $fieldNameForRef = $href->{'field'};
            _debug("\t fieldNameForRef=$fieldNameForRef");
            $errorFields->{$fieldNameForRef} = 1;
        }
        return 0;
    }
    return 1;
}

=pod

_createValidationFieldEntry( \%validateFields, $fieldName, $nameAndValidationType, $order )

Populates \%validateFields with key $nameAndValidationType.

=cut

sub _createValidationFieldEntry {
    my ( $validateFields, $fieldName, $nameAndValidationType, $order ) = @_;

    _debug(
"_createValidationFieldEntry; fieldName=$fieldName; nameAndValidationType=$nameAndValidationType"
    );

    # create hash entry:
    # string_fieldname+validation_type => reference_field
    # remove any '=m'
    $nameAndValidationType =~ s/^(.*?)(\=m)*$/$1/go;

    # append order argument
    $nameAndValidationType .= '=' . $order;
    _debug("\t nameAndValidationType=$nameAndValidationType");

    my $isMultiple = $2 ? 1 : 0;
    _debug("\t isMultiple=$isMultiple");
    if ($isMultiple) {
        my @fieldNameRef;
        $validateFields->{$nameAndValidationType} = \@fieldNameRef
          if $nameAndValidationType;
    }
    else {
        my $fieldNameRef;
        $validateFields->{$nameAndValidationType} = \$fieldNameRef
          if $nameAndValidationType;
    }
}

=pod

_validateFormFields( \%fields ) -> success

Use Validator to check fields.

Returns 1 when validation is ok; 0 if an error has been found.

=cut

sub _validateFormFields {
    my ($fields) = @_;

    _debug("_validateFormFields");
    _debug( "\t fields=" . Dumper($fields) );

    use TWiki::Plugins::FormPlugin::Validate qw(GetFormData);

    # allow some fields not to be validated
    # otherwise we get errors on hidden fields we have inserted ourselves
    $TWiki::Plugins::FormPlugin::Validate::IgnoreNonMatchingFields = 1;

    # not need to check for all form elements
    $TWiki::Plugins::FormPlugin::Validate::Complete = 1;

    # test fields
    my $query = TWiki::Func::getCgiQuery();
    TWiki::Plugins::FormPlugin::Validate::GetFormData( $query, %{$fields} );

    if ($TWiki::Plugins::FormPlugin::Validate::Error) {
        _debug("\t validation error");
        return 0;
    }

    return 1;
}

=pod

=cut

sub _displayErrors {
    my ( $session, $params, $topic, $web ) = @_;

    if (@TWiki::Plugins::FormPlugin::Validate::ErrorFields) {

        my $note = _wrapHtmlErrorTitleContainer(
            TWiki::Func::expandTemplate(
                'formplugin:message:not_filled_in_correctly')
        );

        my @sortedErrorFields =
          sort { $a->{order} cmp $b->{order} }
          @TWiki::Plugins::FormPlugin::Validate::ErrorFields;
        for my $href (@sortedErrorFields) {
            my $errorType   = $href->{'type'};
            my $fieldName   = $href->{'field'};
            my $errorString = $ERROR_STRINGS->{$errorType} || '';
            my $expected    = $href->{'expected'};
            my $expectedString =
              $expected ? ' ' . $ERROR_TYPE_HINTS->{$expected} : '';
            $errorString .= $expectedString;
            my $anchor = '#' . _anchorLinkName($fieldName);

            # preserve state information
            my $currentUrl = _currentUrl();
            $note .= _wrapHtmlErrorItem( $errorString, $currentUrl, $anchor,
                $fieldName );
        }
        return _wrapHtmlError($note) if scalar @sortedErrorFields;
    }
    return '';
}

=pod

=cut

sub _currentUrl {

    my $query = TWiki::Func::getCgiQuery();
    my $currentUrl = $query->url( -path_info => 1 );
    return $currentUrl;
}

=pod

_urlParams() -> (\%urlParams, \@urlParamsParts)

Retrieves the url params - not the POSTed variables!
=cut

sub _urlParams {

    my $query = TWiki::Func::getCgiQuery();
    my $url_with_path_and_query = $query->url( -query => 1 );

    my $urlParams     = {};
    my @urlParamParts = ();
    if ( $url_with_path_and_query =~ m/\?(.*)(#|$)/ ) {
        my $queryString = $1;
        my @parts = split( ';', $queryString );
        foreach my $part (@parts) {
            if ( $part =~ m/^(.*?)\=(.*?)$/ ) {
                my $key = $1;

                # retrieve value from param
                my $value = $query->param($key);
                if ( defined $value ) {
                    $urlParams->{$key} = $value if defined $value;
                    _debug("\t key=$key; value=$value");
                    push @urlParamParts, $part;
                }
            }
        }
    }

    #    _debug( "urlParams=" . Dumper($urlParams) );
    #    _debug( "urlParamParts=" . Dumper(@urlParamParts) );
    return ( $urlParams, \@urlParamParts );

}

=pod

=cut

sub _method {
    my ($method) = @_;

    $method ||= $DEFAULT_METHOD;
    return $method;
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
    }

| =formcondition= | Display only if the form condition is true. Condition syntax: =form_name.contition_status=, where =contition_status= is one of =unchecked=, =error= or =noerror= |- |- | =formcondition="Mailform.noerror"= |
=cut

sub _formElement {
    my ( $session, $params, $topic, $web ) = @_;

    _addHeader();

    my $element = '<noautolink>' . _getFormElementHtml(@_) . '</noautolink>';    # prevent wiki words inside form fields
      
    my $type = $params->{'type'};
    my $name = $params->{'name'};

    my $format =
         $params->{'format'}
      || $currentForm->{'elementformat'}
      || $defaultElementFormat;
    $format = $defaultHiddenFieldFormat if ( $type eq 'hidden' );

    my $javascriptCalls = '';
    my $focus           = $params->{'focus'};
    if ($focus) {
        my $focusCall = TWiki::Func::expandTemplate('formplugin:javascript:focus:inline');
        $focusCall =~ s/\$formName/$currentForm->{'name'}/ if $currentForm->{'name'};
        $focusCall =~ s/\$fieldName/$name/;
        $javascriptCalls .= $focusCall;
    }
    my $beforeclick = $params->{'beforeclick'};
    if ($beforeclick) {
        my $formName        = $currentForm->{'name'};
        my $beforeclickCall = TWiki::Func::expandTemplate('formplugin:javascript:beforeclick:inline');
        $beforeclickCall =~ s/\$formName/$currentForm->{'name'}/;
        $beforeclickCall =~ s/\$fieldName/$name/;
        $beforeclickCall =~ s/\$beforeclick/$beforeclick/;
        $javascriptCalls .= $beforeclickCall;
    }

    $format =~ s/(\$e\b)/$1$javascriptCalls/go;

    my $mandatoryParam = $params->{'mandatory'};
    my $isMandatory = TWiki::Func::isTrue( $mandatoryParam, 0 );
    my $mandatory =
      $isMandatory ? _wrapHtmlMandatoryContainer($MANDATORY_STRING) : '';

    if ( !$currentForm->{'disableValidation'} ) {
        my $validationTypeParam = $params->{'validate'};
        my $validationType =
            $validationTypeParam
          ? $REQUIRED_TYPE_TABLE->{$validationTypeParam}
          : '';
        if ( !$validationTypeParam && $mandatoryParam ) {
            $validationType = 's';    # non-empty
        }
        if ($validationType) {
            my $validate = '=' . $validationType;
            my $multiple = $MULTIPLE_TYPES->{$type} ? $MULTIPLE_TAG_ID : '';
            $format .= "$SEP"
              . _hiddenField( $VALIDATE_TAG . '_' . $name,
                "$name$validate$multiple" );
        }
    }

    my $conditionParam = $params->{'condition'};
    if ($conditionParam) {

        # TODO: put in function
        $conditionParam =~ m/^\$(.*)?\=(.*)$/go;
        my $conditionReferencedField = $1;
        my $conditionValue           = $2;
        my $conditionType =
          $conditionValue ? $CONDITION_TYPE_TABLE->{$conditionValue} : '';
        if ($conditionType) {
            my $condition = '=' . $conditionType;
            $format .= "$SEP"
              . _hiddenField( $CONDITION_TAG . '_' . $name,
                "$conditionReferencedField$condition" );
        }
    }

    my $title = $params->{'title'} || '';
    my $hint  = $params->{'hint'}  || '';

    $title = _wrapHtmlTitleContainer($title) if $title;

    my $titleformat = $params->{'titleformat'} || $defaultTitleFormat;
    $format =~ s/\$titleformat/$titleformat/go if $title;
    $format =~ s/\$e\b/$element/go;
    $format =~ s/\$t\b/$title/go;
    $format =~ s/\$m\b/$mandatory/go;

    my $anchorDone = 0;
    if ( $format =~ /\$a\b/ ) {
        $format =~ s/\$a\b/_anchorLinkHtml($name)/geo;
        $anchorDone = 1;
    }

    return $format if ( $type eq 'hidden' );    # do not draw any more html

    $hint = _wrapHtmlHintContainer($hint) if $hint;
    $format =~ s/\$h\b/$hint/go;
    my $hintCssClass = $hint ? ' ' . $ELEMENT_GROUP_HINT_CSS_CLASS : '';
    $format =~ s/\$_h/$hintCssClass/go;

    # clean up tokens if no title
    $format =~ s/\$titleformat//go;
    $format =~ s/\$a//go;
    $format =~ s/\$m//go;

    $format = _renderFormattingTokens($format);

    if ($currentForm->{'elementcssclass'}) {

        # not for hidden classes, but these are returned earlier in sub
        my $classAttr = ' class="' . $currentForm->{'elementcssclass'} . '"';
        $format = CGI::div( { class => $currentForm->{'elementcssclass'} }, $format );
    }

    # error?
    if ( $currentForm->{'name'} ) {
        my %formStatus = _status( $currentForm->{'name'} );
        if ( $formStatus{$STATUS_ERROR} && $name && $errorFields->{$name} ) {
            $format = _wrapHtmlErrorContainer($format);
        }
    }

    if ( !$anchorDone ) {

        # add anchor so individual fields can be targeted from any
        # error feedback
        $format     = _anchorLinkHtml($name) . "$SEP" . $format;
        $anchorDone = 1;
    }

    $format =~ s/\n/$SEP/ge if ( $SEP ne "\n" );

    return $format;
}

=pod

=cut

sub _getFormElementHtml {
    my ( $session, $params, $topic, $web ) = @_;

    my $type = $params->{'type'};
    my $name = $params->{'name'};

    $name = 'submit' if ( !$name and $type eq 'submit' );

    if ( !$type && !$name ) {
        my $message = TWiki::Func::expandTemplate(
            'formplugin:message:author:missing_element_name_and_type');
        return _wrapHtmlAuthorMessage($message);
    }
    if ( !$type ) {
        my $message = TWiki::Func::expandTemplate(
            'formplugin:message:author:missing_element_type');
        $message =~ s/\$name/$name/;
        return _wrapHtmlAuthorMessage($message);
    }
    if ( !$name ) {
        my $message = TWiki::Func::expandTemplate(
            'formplugin:message:author:missing_element_name');
        $message =~ s/\$type/$type/;
        return _wrapHtmlAuthorMessage($message);
    }

    my $hasMultiSelect = $MULTIPLE_TYPES->{$type} ? $MULTIPLE_TAG_ID : '';
    $type =~ s/^(.*?)(multi)*$/$1/;
    my $value = '';
    $value = $params->{'value'} if defined $params->{'value'};
    $value ||= $params->{'default'}     if defined $params->{'default'};
    $value ||= $params->{'buttonlabel'} if defined $params->{'buttonlabel'};

    my $size = $params->{'size'} || ( $type eq 'date' ? '15' : '40' );
    my $maxlength = $params->{'maxlength'};
    $size = $maxlength if defined $maxlength && $maxlength < $size;

# TODO: if no size is passed and we are using options, use the number of items with a maximum
#$size = scalar @{$options} < 10 ? scalar @{$options} : 10 if !defined $params->{'size'};

    my ( $options, $labels ) =
      _parseOptions( $params->{'options'}, $params->{'labels'} );

    my $itemformat = $params->{'fieldformat'};
    my $cssClass = $params->{'cssclass'} || '';
    $cssClass = _normalizeCssClassName($cssClass);

    my $selectedoptions =
      defined $params->{'default'} ? $params->{'default'} : undef;
    my $isMultiple = $MULTIPLE_TYPES->{$type};
    if ($isMultiple) {
        my @values = defined $params->{'value'} ? $params->{'value'} : '';
        $selectedoptions ||= join( ",", @values );
    }
    else {
        $selectedoptions ||= $params->{'value'};
    }

    my $disabled = $params->{'disabled'} ? 'disabled' : undef;
    my $readonly = $params->{'readonly'} ? 'readonly' : undef;

    my (
        $onFocus,     $onBlur,     $onClick, $onChange, $onSelect,
        $onMouseOver, $onMouseOut, $onKeyUp, $onKeyDown
    );
    my $beforeclick = $params->{'beforeclick'};
    if ($beforeclick) {
        $onFocus = 'twiki.Form.clearBeforeFocusText(this)';
        $onBlur  = 'twiki.Form.restoreBeforeFocusText(this)';

        # additional init function in _formElement
    }

    $onFocus     ||= $params->{'onFocus'};
    $onBlur      ||= $params->{'onBlur'};
    $onClick     ||= $params->{'onClick'};
    $onChange    ||= $params->{'onChange'};
    $onSelect    ||= $params->{'onSelect'};
    $onMouseOver ||= $params->{'onMouseOver'};
    $onMouseOut  ||= $params->{'onMouseOut'};
    $onKeyUp     ||= $params->{'onKeyUp'};
    $onKeyDown   ||= $params->{'onKeyDown'};

    my %extraAttributes = ();
    $extraAttributes{'class'}    = $cssClass if $cssClass;
    $extraAttributes{'disabled'} = $disabled if $disabled;
    $extraAttributes{'readonly'} = $readonly if $readonly;
    $extraAttributes{'-tabindex'} = ++$tabCounter;

    # javascript parameters
    $extraAttributes{'-onFocus'}     = $onFocus     if $onFocus;
    $extraAttributes{'-onBlur'}      = $onBlur      if $onBlur;
    $extraAttributes{'-onClick'}     = $onClick     if $onClick;
    $extraAttributes{'-onChange'}    = $onChange    if $onChange;
    $extraAttributes{'-onSelect'}    = $onSelect    if $onSelect;
    $extraAttributes{'-onMouseOver'} = $onMouseOver if $onMouseOver;
    $extraAttributes{'-onMouseOut'}  = $onMouseOut  if $onMouseOut;
    $extraAttributes{'-onKeyUp'}     = $onKeyUp     if $onKeyUp;
    $extraAttributes{'-onKeyDown'}   = $onKeyDown   if $onKeyDown;

    my $element = '';
    if ( $type eq 'text' ) {
        $element =
          _getTextFieldHtml( $session, $name, $value, $size, $maxlength,
            %extraAttributes );
    }
    elsif ( $type eq 'textonly' ) {
        $element =
          _getTextOnlyHtml( $session, $name, $value, %extraAttributes );
    }
    elsif ( $type eq 'password' ) {
        $element =
          _getPasswordFieldHtml( $session, $name, $value, $size, $maxlength,
            %extraAttributes );
    }
    elsif ( $type eq 'upload' ) {
        $element = _getUploadHtml( $session, $name, '', $size, $maxlength,
            %extraAttributes );
    }
    elsif ( $type eq 'submit' ) {
        $element =
          _getSubmitButtonHtml( $session, $name, $value, %extraAttributes );
    }
    elsif ( $type eq 'radio' ) {
        $element = _getRadioButtonGroupHtml( $session, $name, $options, $labels,
            $selectedoptions, $itemformat, %extraAttributes );
    }
    elsif ( $type eq 'checkbox' ) {
        $element =
          _getCheckboxButtonGroupHtml( $session, $name, $options, $labels,
            $selectedoptions, $itemformat, %extraAttributes );
    }
    elsif ( $type eq 'select' ) {
        $element =
          _getSelectHtml( $session, $name, $options, $labels, $selectedoptions,
            $size, $hasMultiSelect, %extraAttributes );
    }
    elsif ( $type eq 'dropdown' ) {

        # just a select box with size of 1 and no multiple
        $element =
          _getSelectHtml( $session, $name, $options, $labels, $selectedoptions,
            '1', undef, %extraAttributes );
    }
    elsif ( $type eq 'textarea' ) {
        my $rows = $params->{'rows'};
        my $cols = $params->{'cols'};
        $element = _getTextareaHtml( $session, $name, $value, $rows, $cols,
            %extraAttributes );
    }
    elsif ( $type eq 'hidden' ) {
        $element = _hiddenField( $name, $value );
    }
    elsif ( $type eq 'date' ) {
        my $dateFormat = $params->{'dateformat'};
        $element =
          _getDateFieldHtml( $session, $name, $value, $size, $maxlength,
            $dateFormat, %extraAttributes );
    }
    return $element;
}

=pod

=cut

sub _anchorLinkName {
    my ($name) = @_;

    my $anchorName = $name || '';
    $anchorName =~ s/[[:punct:][:space:]]//go;
    return $ELEMENT_ANCHOR_NAME . $anchorName;
}

sub _anchorLinkHtml {
    my ($name) = @_;

    my $anchorName = _anchorLinkName($name);
    return '<a name="' . $anchorName . '"><!--//--></a>';
}

=pod

_parseOptions( $optionsString, $labelsString ) -> ( $optionsListString, $labelsListString )

=cut

sub _parseOptions {
    my ( $inOptions, $inLabels ) = @_;

    return ( '', '' ) if !$inOptions;

    _trimSpaces($inOptions);
    _trimSpaces($inLabels);

    my @optionPairs = split( /\s*,\s*/, $inOptions ) if $inOptions;
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
    my ( $session, $name, $value, $size, $maxlength, %extraAttributes ) = @_;

    my %attributes = _textfieldAttributes(@_);

    return CGI::textfield(%attributes);
}

=pod

=cut

sub _getPasswordFieldHtml {
    my ( $session, $name, $value, $size, $maxlength, %extraAttributes ) = @_;

    my %attributes = _textfieldAttributes(@_);
    return CGI::password_field(%attributes);
}

=pod

=cut

sub _getTextOnlyHtml {
    my ( $session, $name, $value, %extraAttributes ) = @_;

    my $element = CGI::span( { class => $TEXTONLY_CSS_CLASS }, $value );
    $element .= _hiddenField( $name, $value );
    return $element;
}

=pod

=cut

sub _getUploadHtml {
    my ( $session, $name, $value, $size, $maxlength, %extraAttributes ) = @_;

    my %attributes = _textfieldAttributes(@_);
    return CGI::filefield(%attributes);
}

=pod

=cut

sub _textfieldAttributes {
    my ( $session, $name, $value, $size, $maxlength, %extraAttributes ) = @_;

    my %attributes = (
        -name      => $name,
        -value     => $value,
        -size      => $size,
        -maxlength => $maxlength
    );
    %attributes = ( %attributes, %extraAttributes );

    my $cssClass = $attributes{'class'} || '';
    $cssClass = 'twikiInputFieldDisabled'
      if ( !$cssClass && $attributes{'disabled'} );
    $cssClass = 'twikiInputFieldReadOnly'
      if ( !$cssClass && $attributes{'readonly'} );
    $cssClass ||= 'twikiInputField';
    $cssClass = _normalizeCssClassName($cssClass);
    $attributes{'class'} = $cssClass if $cssClass;

    return %attributes;
}

=pod

=cut

sub _getSubmitButtonHtml {
    my ( $session, $name, $value, %extraAttributes ) = @_;

    my $id = $name || undef;

    my %attributes = (
        -name  => $name,
        -value => $value
    );
    %attributes = ( %attributes, %extraAttributes );

    my $cssClass = $attributes{'class'} || '';
    $cssClass = 'twikiSubmitDisabled'
      if ( !$cssClass && $attributes{'disabled'} );
    $cssClass ||= 'twikiSubmit';
    $cssClass = _normalizeCssClassName($cssClass);
    $attributes{'class'} = $cssClass if $cssClass;
    return CGI::submit(%attributes);
}

=pod

=cut

sub _getTextareaHtml {
    my ( $session, $name, $value, $rows, $cols, %extraAttributes ) = @_;

    my %attributes = (
        -name    => $name,
        -default => $value,
        -rows    => $rows,
        -columns => $cols
    );
    %attributes = ( %attributes, %extraAttributes );

    my $cssClass = $attributes{'class'} || '';
    $cssClass = 'twikiInputFieldDisabled'
      if ( !$cssClass && $attributes{'disabled'} );
    $cssClass = 'twikiInputFieldReadOnly'
      if ( !$cssClass && $attributes{'readonly'} );
    $cssClass ||= 'twikiInputField';
    $cssClass = _normalizeCssClassName($cssClass);
    $attributes{'class'} = $cssClass if $cssClass;

    return CGI::textarea(%attributes);
}

=pod

=cut

sub _getCheckboxButtonGroupHtml {
    my ( $session, $name, $options, $labels, $selectedoptions, $itemformat,
        %extraAttributes )
      = @_;

    my @optionList = split( /\s*,\s*/, $options ) if $options;
    $labels = $options if !$labels;
    my @selectedValueList = split( /\s*,\s*/, $selectedoptions )
      if defined $selectedoptions;
    my @labelList = split( /\s*,\s*/, $labels ) if $labels;
    my %labels;
    @labels{@optionList} = @labelList if @labelList;

    # ideally we would use CGI::checkbox_group, but this does not
    # generate the correct labels
    # my @checkboxes = CGI::checkbox_group(-name=>$name,
    #                            -values=>\@optionList,
    #                            -default=>\@selectedValueList,
    #                            -linebreak=>'false',
    #                            -labels=>\%labels);

    # so we roll our own while keeping the same interface
    my %attributes = (
        -name      => $name,
        -values    => \@optionList,
        -default   => \@selectedValueList,
        -linebreak => 'false',
        -labels    => \%labels
    );
    %attributes = ( %attributes, %extraAttributes );

    my $cssClass = $attributes{'class'} || '';
    $cssClass = 'twikiCheckbox ' . $cssClass;
    $cssClass = _normalizeCssClassName($cssClass);
    $attributes{'class'} = $cssClass if $cssClass;

    my @items = _checkbox_group(%attributes);

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
        %extraAttributes )
      = @_;

    return "" if !$options;
    my @optionList = split( /\s*,\s*/, $options ) if $options;
    $labels = $options if !$labels;
    my @selectedValueList = split( /\s*,\s*/, $selectedoptions )
      if defined $selectedoptions;
    my @labelList = split( /\s*,\s*/, $labels ) if $labels;
    my %labels;
    @labels{@optionList} = @labelList if @labelList;
    my %attributes = (
        -name      => $name,
        -values    => \@optionList,
        -default   => \@selectedValueList,
        -linebreak => 'false',
        -labels    => \%labels
    );
    %attributes = ( %attributes, %extraAttributes );

    my $cssClass = $attributes{'class'} || '';
    $cssClass = 'twikiInputFieldDisabled'
      if ( !$cssClass && $attributes{'disabled'} );
    $cssClass = 'twikiRadioButton ' . $cssClass;
    $cssClass = _normalizeCssClassName($cssClass);
    $attributes{'class'} = $cssClass if $cssClass;

    my @items = _radio_group(%attributes);
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
    my $str = join " ", map {
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
        $hasMultiSelect, %extraAttributes )
      = @_;

    my @optionList = split( /\s*,\s*/, $options ) if $options;
    $labels = $options if !$labels;
    my @selectedValueList = split( /\s*,\s*/, $selectedoptions )
      if defined $selectedoptions;
    my @labelList = split( /\s*,\s*/, $labels ) if $labels;
    my %labels;
    @labels{@optionList} = @labelList if @labelList;

    my $multiple = $hasMultiSelect ? 'true' : undef;
    my %attributes = (
        -name     => $name,
        -values   => \@optionList,
        -default  => \@selectedValueList,
        -labels   => \%labels,
        -size     => $size,
        -multiple => $multiple
    );
    %attributes = ( %attributes, %extraAttributes );

    my $cssClass = $attributes{'class'} || '';
    $cssClass = 'twikiSelectDisabled'
      if ( !$cssClass && $attributes{'disabled'} );
    $cssClass = 'twikiSelect ' . $cssClass;
    $cssClass = _normalizeCssClassName($cssClass);
    $attributes{'class'} = $cssClass if $cssClass;

    my @items = CGI::scrolling_list(%attributes);
    return _mapToItemFormatString( \@items );
}

=pod

=cut

sub _getDateFieldHtml {
    my ( $session, $name, $value, $size, $maxlength, $dateFormat,
        %extraAttributes )
      = @_;

    my %attributes =
      _textfieldAttributes( $session, $name, $value, $size, $maxlength,
        %extraAttributes );
    my $id = $attributes{'id'}
      || 'cal' . ( $currentForm->{'name'} || '' ) . $name;
    $attributes{'id'} ||= $id;

    my $text = CGI::textfield(%attributes);

    eval 'use TWiki::Contrib::JSCalendarContrib';
    {
        if ($@) {
            my $mess = "WARNING: JSCalendar not installed: $@";
            print STDERR "$mess\n";
            TWiki::Func::writeWarning($mess);
        }
        else {
            TWiki::Contrib::JSCalendarContrib::addHEAD('twiki');

            my $format =
                 $dateFormat
              || $TWiki::cfg{JSCalendarContrib}{format}
              || "%e %B %Y";

            $text .= ' <span class="twikiMakeVisible">';
            my $control = CGI::image_button(
                -class   => 'editTableCalendarButton',
                -name    => 'calendar',
                -onclick => "return showCalendar('$id','$format')",
                -src     => TWiki::Func::getPubUrlPath() . '/'
                  . $TWiki::cfg{SystemWebName}
                  . '/JSCalendarContrib/img.gif',
                -alt   => 'Calendar',
                -align => 'middle'
            );

            #fix generated html
            $control =~ s/MIDDLE/middle/go;
            $text .= $control;
            $text .= '</span>';
        }
    };
    return $text;
}

=pod

=cut

sub _group {
    my (%options) = @_;

    my $type       = $options{-type};
    my $name       = $options{-name};
    my $size       = $options{-size};
    my $values     = $options{-values};
    my $default    = $options{-default};
    my %defaultSet = map { $_ => 1 } @$default;

    my $labels    = $options{-labels};
    my $linebreak = $options{-linebreak};

    my $optionFormat   = '';
    my $selectedFormat = '';
    if ( $type eq 'radio' ) {
        $optionFormat = '<input $attributes /><label for="$id">$label</label>';
        $selectedFormat = 'checked="1"';
    }
    elsif ( $type eq 'checkbox' ) {
        $optionFormat = '<input $attributes /><label for="$id">$label</label>';
        $selectedFormat = 'checked="1"';
    }
    elsif ( $type eq 'select' ) {
        $optionFormat   = '<option $attributes>$label</option>';
        $selectedFormat = 'selected="selected"';
    }

    my $disabledFormat = $options{disabled} ? ' disabled="disabled"' : '';
    my $readonlyFormat = $options{readonly} ? ' readonly="readonly"' : '';
    my $cssClassFormat =
      $options{class} ? ' class="' . $options{class} . '"' : '';

    my $scriptFormat = '';
    $scriptFormat .= ' onclick="' . $options{-onClick} . '" '
      if $options{-onClick};
    $scriptFormat .= ' onfocus="' . $options{-onFocus} . '" '
      if $options{-onFocus};
    $scriptFormat .= ' onblur="' . $options{-onBlur} . '" '
      if $options{-onBlur};
    $scriptFormat .= ' onchange="' . $options{-onChange} . '" '
      if $options{-onChange};
    $scriptFormat .= ' onselect="' . $options{-onSelect} . '" '
      if $options{-onSelect};
    $scriptFormat .= ' onmouseover="' . $options{-onMouseOver} . '" '
      if $options{-onMouseOver};
    $scriptFormat .= ' onmouseout="' . $options{-onMouseOut} . '" '
      if $options{-onMouseOut};

    my @elements;
    my $counter = 0;
    foreach my $value (@$values) {
        $counter++;
        my $label = $labels->{$value};

        my %attributes = ();
        if ( $type eq 'radio' || $type eq 'checkbox' ) {
            $attributes{'type'} = $type;
            $attributes{'name'} = $name;
        }

        #if ( $type eq 'checkbox' ) {
        #    $attributes{'name'} .= "_$counter";
        #}
        $attributes{'value'} = $value;
        my $id = $name . '_' . $value;    # use group name to prevent doublures
        $id =~ s/ /_/go;
        $attributes{'id'} = $id;
        my $attributeString = _getAttributeString(%attributes);

        my $selected = '';
        $selected = $selectedFormat if $defaultSet{$value};

        my $selectedAttributeString =
"$attributeString $selected $disabledFormat $readonlyFormat $scriptFormat $cssClassFormat";
        $selectedAttributeString =~ s/ +/ /go;    # remove extraneous spaces

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

sub _normalizeCssClassName {
    my ($cssString) = @_;
    return '' if !$cssString;
    $cssString =~ s/^\s*(.*?)\s*$/$1/go;    # strip surrounding spaces
    $cssString =~ s/\s+/ /go;               # remove double spaces
    return $cssString;
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

    return "<a name=\"$NOTIFICATION_ANCHOR_NAME\"><!--//--></a>"
      . CGI::div( { class => "$ERROR_CSS_CLASS $NOTIFICATION_CSS_CLASS" },
        $text )
      . "$SEP";
}

=pod

=cut

sub _wrapHtmlErrorItem {
    my ( $errorString, $currentUrl, $anchor, $fieldName ) = @_;

    my $fieldLink =
      defined $fieldName
      ? "<a href=\"$currentUrl$anchor\">$fieldName</a> "
      : '';
    return
      "   * $fieldLink$errorString\n";
}

sub _wrapHtmlAuthorMessage {
    my ($text) = @_;

    return CGI::div( { class => 'twikiAlert' }, $text );
}

=pod

=cut

sub _wrapHtmlGroupContainer {
    my ($text) = @_;

    return
        '<fieldset class="'
      . $ELEMENT_GROUP_CSS_CLASS . '$_h">'
      . $text
      . '</fieldset>';
}

=pod

=cut

sub _wrapHtmlErrorContainer {
    my ($text) = @_;

    return CGI::div( { class => $ERROR_CSS_CLASS }, $text );
}

=pod

=cut

sub _wrapHtmlTitleContainer {
    my ($text) = @_;

    return CGI::span( { class => $TITLE_CSS_CLASS }, $text );
}

=pod

=cut

sub _wrapHtmlErrorTitleContainer {
    my ($text) = @_;

    return "\n   * <strong>$text</strong>\n";
}

=pod

=cut

sub _wrapHtmlHintContainer {
    my ($text) = @_;

    return CGI::span( { class => $HINT_CSS_CLASS }, $text );
}

=pod

=cut

sub _wrapHtmlMandatoryContainer {
    my ($text) = @_;

    return CGI::span( { class => $MANDATORY_CSS_CLASS }, $text );
}

sub _checkForString {
    my $value = shift;
    return 0 if !defined $value;
    ## Any non-zero length string is valid
    return 1 if ( length $value > 0 );
    return 0;
}

sub _checkForInt {
    my $value = shift;
    return 0 if !defined $value;
    return 1 if ( $value =~ /^\d+$/ );
    return;
}

sub _checkForFloat {
    my $value = shift;
    return 0 if !defined $value;

    ## Must be in a "3.0" or "30" format
    #	return 1 if ($value =~ /^\d+\.\d+$/);
    return 1 if ( $value =~ /^\d+.?\d*$/ );
    return;
}

sub _checkForEmail {
    my $value = shift;
    return 0 if !defined $value;

    ## Must look like a "standard" email address.  White space
    ## is permitted on the ends though.
    return 1 if ( $value =~ m/^\s*<?[^@<>]+@[^@.<>]+(?:\.[^@.<>]+)+>?\s*$/ );
}

sub _hiddenField {
    my ( $name, $value ) = @_;

    return "<input type=\"hidden\" name=\"$name\" value=\"$value\" />";
}

sub _trimSpaces {

    #my $text = $_[0]
    return if !$_[0];
    $_[0] =~ s/^[[:space:]]+//s;    # trim at start
    $_[0] =~ s/[[:space:]]+$//s;    # trim at end
}

=pod

Creates a url param string from POST data.

=cut

sub _postDataToUrlParamString {
    my $out   = '';
    my $query = TWiki::Func::getCgiQuery();
    my @names = $query->param;
    foreach my $name (@names) {
        next if !$name;
        $out .= ';' if $out;
        my $value = $query->param($name);
        $value = _urlEncode($value);
        $out .= "$name=" . $value;
    }
    return $out;
}

=pod

Copied from TWiki.pm

=cut

sub _urlEncode {
    my $text = shift;

    $text =~ s/([^0-9a-zA-Z-_.:~!*'()\/%])/'%'.sprintf('%02x',ord($1))/ge;

    return $text;
}

=pod

Evaluates if FormPlugin should redirect if needed. If true: it is allowed to redirect; if false: deny redirects.

=cut

# Tests if the $redirect is an external URL, returning false if
# AllowRedirectUrl is denied
sub _allowRedirects {
    my ($redirect) = @_;

    return 1 if ( $TWiki::cfg{AllowRedirectUrl} );
    return 1 if $redirect =~ m#^/#;    # relative URL - OK

    my $query = TWiki::Func::getCgiQuery();
    return 0 if ( TWiki::Func::isTrue( $query->param($NO_REDIRECTS_TAG) ) );

    #TODO: this should really use URI
    # Compare protocol, host name and port number
    if ( $redirect =~ m!^(.*?://[^/]*)! ) {

        # implicit untaints OK because result not used. uc retaints
        # if use locale anyway.
        my $target = uc($1);

        $TWiki::cfg{DefaultUrlHost} =~ m!^(.*?://[^/]*)!;
        return 1 if ( $target eq uc($1) );

        if ( $TWiki::cfg{PermittedRedirectHostUrls} ) {
            foreach my $red (
                split( /\s*,\s*/, $TWiki::cfg{PermittedRedirectHostUrls} ) )
            {
                $red =~ m!^(.*?://[^/]*)!;
                return 1 if ( $target eq uc($1) );
            }
        }
    }
    return 0;
}

=pod

Shorthand function call.

=cut

sub _debug {
    my ($text) = @_;

    #print STDERR "_debug; debug=$debug; text=$text\n";    # only for unit tests

    TWiki::Func::writeDebug("$pluginName:$text") if $text && $debug;
}

1;
