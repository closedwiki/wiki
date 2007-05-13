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

package TWiki::Plugins::SendEmailPlugin;

# Always use strict to enforce variable scoping
use strict;
use TWiki::Func;

# $VERSION is referred to by TWiki, and is the only global variable that
# *must* exist in this package
use vars qw( $VERSION $RELEASE $debug $pluginName );
use vars qw( $successMessage $errorMessage $headerDone);

# This should always be $Rev: 11069$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 11069$';
$RELEASE = '1.1.1';

# Name of this Plugin, only used in this module
$pluginName = 'SendEmailPlugin';

$headerDone = 0;

my $RETRY_COUNT                  = 5;
my $ERROR_STATUS_TAG             = 'SendEmailErrorStatus';
my $NOTIFICATION_CSS_CLASS       = 'sendEmailPluginNotification';
my $NOTIFICATION_ERROR_CSS_CLASS = 'sendEmailPluginError';
my $NOTIFICATION_ANCHOR_NAME     = 'FormPluginNotification';
my %ERROR_STATUS = (
    'noerror' => 1,
    'error'   => 2,
);
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

    $debug = TWiki::Func::getPluginPreferencesFlag("DEBUG")
      || TWiki::Func::getPreferencesFlag("SENDEMAILPLUGIN_DEBUG");

    $successMessage =
      TWiki::Func::getPluginPreferencesValue("EMAIL_SENT_SUCCESS_MESSAGE")
      || TWiki::Func::getPluginPreferencesValue(
        "SENDEMAILPLUGIN_EMAIL_SENT_SUCCESS_MESSAGE")
      || '';

    $errorMessage =
      TWiki::Func::getPluginPreferencesValue("EMAIL_SENT_ERROR_MESSAGE")
      || TWiki::Func::getPluginPreferencesValue(
        "SENDEMAILPLUGIN_EMAIL_SENT_ERROR_MESSAGE")
      || '';

    TWiki::Func::registerTagHandler( 'SENDEMAIL', \&_handleSendEmailTag );

    # Plugin correctly initialized
    return 1;
}

=pod

Invoked by bin/sendemail

=cut

sub sendEmail {
    my $session = shift;

    my $to      = '';
    my $from    = '';
    my $cc      = '';
    my $subject = '';
    my $body    = '';

    my $query = TWiki::Func::getCgiQuery();
    return _finishSendEmail( $session, $ERROR_STATUS{'error'} ) if !$query;

    $to = $query->param('to') || $query->param('To');
    return _finishSendEmail( $session, $ERROR_STATUS{'error'} ) if !$to;

    $from = $query->param('from') || $query->param('From') 
      || $TWiki::cfg{WebMasterEmail}
      || TWiki::Func::getPreferencesValue('WIKIWEBMASTER');

    return _finishSendEmail( $session, $ERROR_STATUS{'error'} ) if !$from;

    my $ccParam = $query->param('cc') || $query->param('CC') || '';
    $cc = $ccParam if $ccParam;
    my $subjectParam = $query->param('subject') || $query->param('Subject');
    $subject = $subjectParam if $subjectParam;
    my $bodyParam = $query->param('body') || $query->param('Body') || '';
    $body = $bodyParam if $bodyParam;

    my $mail = <<'HERE';
From: %FROM%
To: %TO%
CC: %CC%
Subject: %SUBJECT%

%BODY%
HERE

    $mail =~ s/%FROM%/$from/go;
    $mail =~ s/%TO%/$to/go;
    $mail =~ s/%CC%/$cc/go;
    $mail =~ s/%SUBJECT%/$subject/go;
    $mail =~ s/%BODY%/$body/go;

    TWiki::Func::writeDebug("mail message=$mail") if $debug;

    my $error = TWiki::Func::sendEmail( $mail, $RETRY_COUNT );
    my $errorStatus = $error ? $ERROR_STATUS{'error'} : $ERROR_STATUS{'noerror'};
    
    TWiki::Func::writeDebug("errorStatus=$errorStatus") if $debug;

    _finishSendEmail( $session, $errorStatus );
}

=pod

=cut

sub _handleSendEmailTag {
    my ( $session, $params, $topic, $web ) = @_;

    _addHeader();

    my $query = TWiki::Func::getCgiQuery();
    return '' if !$query;
    
    my $errorStatus = $query->param($ERROR_STATUS_TAG);
    
    TWiki::Func::writeDebug("_handleSendEmailTag; errorStatus=$errorStatus") if $debug;

    return '' if !defined $errorStatus;

    my $feedbackSuccess = $params->{'feedbackSuccess'} || $successMessage;
    my $feedbackError   = $params->{'feedbackError'}   || $errorMessage;

    my $message = ($errorStatus == $ERROR_STATUS{'error'}) ? $feedbackError : $feedbackSuccess;

    return _wrapHtmlNotificationContainer( $message, $errorStatus );
}

=pod

=cut

sub _finishSendEmail {
    my ( $session, $errorStatus ) = @_;
    my $web   = $session->{webName};
    my $topic = $session->{topicName};

    my $query = TWiki::Func::getCgiQuery();
    
    TWiki::Func::writeDebug("_finishSendEmail errorStatus=$errorStatus") if $debug;

    $query->param( -name => $ERROR_STATUS_TAG, -value => $errorStatus ) if $query;

    TWiki::Func::redirectCgiQuery( undef,
        TWiki::Func::getScriptUrl( $web, $topic, 'view' ), 1 );
    # would pass '#'=>$NOTIFICATION_ANCHOR_NAME but the anchor removes 
    # the ERROR_STATUS_TAG param
}

=pod

=cut

sub _addHeader {

    return if $headerDone;

    my $header = <<'EOF';
<style type="text/css" media="all">
@import url("%PUBURL%/%TWIKIWEB%/SendEmailPlugin/sendemailplugin.css");
</style>
EOF
    TWiki::Func::addToHEAD( 'SENDEMAILPLUGIN', $header );
    $headerDone = 1;
}

=pod

=cut

sub _wrapHtmlNotificationContainer {
    my ( $text, $errorStatus ) = @_;

    my $cssClass = $NOTIFICATION_CSS_CLASS;
    $cssClass .= ' ' . $NOTIFICATION_ERROR_CSS_CLASS if ( $errorStatus == $ERROR_STATUS{'error'} );
    return "#$NOTIFICATION_ANCHOR_NAME\n" . '<div class="' . $cssClass . '">' . $text . '</div>';
}

1;
