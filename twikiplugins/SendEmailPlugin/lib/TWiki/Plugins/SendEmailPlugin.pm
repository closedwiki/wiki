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

# $VERSION is referred to by TWiki, and is the only global variable that
# *must* exist in this package
use vars qw( $VERSION $RELEASE $debug $pluginName );
use vars qw( $retryCount $emailSent $successMessage $errorMessage);

# This should always be $Rev: 11069$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 11069$';
$RELEASE = '1.0';

# Name of this Plugin, only used in this module
$pluginName = 'SendEmailPlugin';

$retryCount = 5;

=pod

=cut

sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    $debug = TWiki::Func::getPluginPreferencesFlag("DEBUG") || TWiki::Func::getPreferencesFlag("SENDEMAILPLUGIN_DEBUG");
    
    $successMessage = TWiki::Func::getPluginPreferencesValue("EMAIL_SENT_SUCCESS_MESSAGE")
        || TWiki::Func::getPluginPreferencesValue("SENDEMAILPLUGIN_EMAIL_SENT_SUCCESS_MESSAGE")
        || '';
    
    $errorMessage = TWiki::Func::getPluginPreferencesValue("EMAIL_SENT_ERROR_MESSAGE")
        || TWiki::Func::getPluginPreferencesValue("SENDEMAILPLUGIN_EMAIL_SENT_ERROR_MESSAGE")
        || '';

    TWiki::Func::registerTagHandler('SENDEMAIL',\&_handleSendEmail);

    $emailSent = 0;
    
    # Plugin correctly initialized
    return 1;
}

=pod

=cut

sub _handleSendEmail {
    my($session, $params, $topic, $web) = @_;
    
    TWiki::Func::writeDebug("_handleSendEmail - emailSent=$emailSent") if $debug;

    return if $emailSent == 1;
    
    my $query = TWiki::Func::getCgiQuery();
    my $sendmail = $query->param('sendmail') || '';
    
    TWiki::Func::writeDebug("_handleSendEmail - sendmail=$sendmail") if $debug;
    
    return '' if $sendmail ne 'on';

    my $feedbackSucces = $params->{'feedbackSucces'} || $successMessage;
    my $feedbackError = $params->{'feedbackError'} || $errorMessage;
        
    my $to = '';
    my $from = '';
    my $cc = '';
    my $subject = '';
    my $body = '';
    
	$to = $query->param('to');
	$from = $query->param('from')
	    || $TWiki::cfg{WebMasterEmail}
	    || TWiki::Func::getPreferencesValue( 'WIKIWEBMASTER' )
	    || 'twikiwebmaster@example.com';
          
	my $ccParam = $query->param('cc') || '';
	$cc = $ccParam if $ccParam;
	my $subjectParam = $query->param('subject');
	$subject = $subjectParam if $subjectParam;
	my $bodyParam = $query->param('body') || '';
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

    my $error = TWiki::Func::sendEmail( $mail, $retryCount );

    my $feedback = '';
    if ($error) {
        $feedback = $feedbackError;
    } else {
        $feedback = $feedbackSucces;
    }
    $emailSent = 1;
    return $feedback;
}

1;
