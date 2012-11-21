# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (c) 2007-2010 by Arthur Clemens, Michael Daum
# Copyright (C) 2007-2011 TWiki Contributors 
# All Rights Reserved. TWiki Contributors are listed in the 
# AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
#   Copyright (c) Foswiki Contributors.
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

package TWiki::Plugins::SendEmailPlugin::Core;

# Always use strict to enforce variable scoping
use strict;
use TWiki;
use TWiki::Func;
use TWiki::Plugins;
use MIME::Base64;
use MIME::QuotedPrint;
use CGI qw( :all );

use vars qw( $debug $emailRE );

my $RETRY_COUNT                  =
        $TWiki::cfg{Plugins}{SendEmailPlugin}{Retry} || 1;
my $ERROR_STATUS_TAG             = 'SendEmailErrorStatus';
my $ERROR_MESSAGE_TAG            = 'SendEmailErrorMessage';
my $NOTIFICATION_CSS_CLASS       = 'sendEmailPluginNotification';
my $NOTIFICATION_ERROR_CSS_CLASS = 'sendEmailPluginError';
my $NOTIFICATION_ANCHOR_NAME     = 'SendEmailNotification';
my %ERROR_STATUS                 = (
    'noerror' => 1,
    'error'   => 2,
);
my $EMAIL_SENT_SUCCESS_MESSAGE;
my $EMAIL_SENT_ERROR_MESSAGE;
my $ERROR_INVALID_ADDRESS;
my $ERROR_EMPTY_TO_EMAIL;
my $ERROR_EMPTY_FROM_EMAIL;
my $ERROR_NO_PERMISSION_FROM;
my $ERROR_NO_PERMISSION_TO;
my $ERROR_NO_PERMISSION_CC;

=pod

writes a debug message if the $debug flag is set

=cut

sub _debug {
    TWiki::Func::writeDebug("SendEmailPlugin -- $_[0]")
      if $debug;
}

=pod

some init steps

=cut

sub init {
    my $session = shift;
    $TWiki::Plugins::SESSION = $session; # ||= may fail on mod_perl
    my $pluginName = $TWiki::Plugins::SendEmailPlugin::pluginName;
    $debug = $TWiki::cfg{Plugins}{$pluginName}{Debug} || 0;
    $emailRE = TWiki::Func::getRegularExpression('emailAddrRegex');
    initMessageStrings();
}

sub initMessageStrings {
    my $session = shift;

    my $language = TWiki::Func::getPreferencesValue("LANGUAGE") || 'en';
    my $pluginName = $TWiki::Plugins::SendEmailPlugin::pluginName;

    $EMAIL_SENT_SUCCESS_MESSAGE =
      $TWiki::cfg{Plugins}{$pluginName}{Messages}{SentSuccess}{en};
    $EMAIL_SENT_ERROR_MESSAGE =
      $TWiki::cfg{Plugins}{$pluginName}{Messages}{SentError}{$language};
    $ERROR_INVALID_ADDRESS =
      $TWiki::cfg{Plugins}{$pluginName}{Messages}{InvalidAddress}{$language};
    $ERROR_EMPTY_TO_EMAIL =
      $TWiki::cfg{Plugins}{$pluginName}{Messages}{EmptyTo}{$language};
    $ERROR_EMPTY_FROM_EMAIL =
      $TWiki::cfg{Plugins}{$pluginName}{Messages}{EmptyFrom}{$language};
    $ERROR_NO_PERMISSION_FROM =
      $TWiki::cfg{Plugins}{$pluginName}{Messages}{NoPermissionFrom}
      {$language};
    $ERROR_NO_PERMISSION_TO =
      $TWiki::cfg{Plugins}{$pluginName}{Messages}{NoPermissionTo}{$language};
    $ERROR_NO_PERMISSION_CC =
      $TWiki::cfg{Plugins}{$pluginName}{Messages}{NoPermissionCc}{$language};
}

=pod

Invoked by bin/sendemail

=cut

sub sendEmail {
    my $session = shift;

    _debug("sendEmail");

    init($session);

    my $query        = TWiki::Func::getCgiQuery();
    my $errorMessage = '';
    my $redirectUrl  = $query->param('redirectto');

    return _finishSendEmail( $session, $ERROR_STATUS{'error'}, undef,
        $redirectUrl )
      unless $query;

    # get TO
    my $to = $query->param('to') || $query->param('To');

    return _finishSendEmail( $session, $ERROR_STATUS{'error'},
        $ERROR_EMPTY_TO_EMAIL, $redirectUrl )
      unless $to;

    my @toEmails = ();
    foreach my $thisTo ( split( /\s*,\s*/, $to ) ) {
        my $addrs;

        if ( $thisTo =~ /$emailRE/ ) {

            # regular address
            $addrs = $thisTo;
            # validate TO
            if (!_matchesSetting('Allow', 'MailTo', $addrs) || 
                    _matchesSetting('Deny', 'MailTo', $addrs)) {
                $errorMessage = $ERROR_NO_PERMISSION_TO;
                $errorMessage =~ s/\$EMAIL/$thisTo/go;
                TWiki::Func::writeWarning($errorMessage);
                return _finishSendEmail( $session, $ERROR_STATUS{'error'},
                    $errorMessage, $redirectUrl );
            }
        }
        else {

            # get TO user info
            $addrs = TWiki::Func::wikiToEmail($thisTo);

            unless ($addrs) {

                # no regular address and no address found in user info

                $errorMessage = $ERROR_INVALID_ADDRESS;
                $errorMessage =~ s/\$EMAIL/$thisTo/go;
                return _finishSendEmail( $session, $ERROR_STATUS{'error'},
                    $errorMessage, $redirectUrl );
            }
        }

        push @toEmails, $addrs;
    }
    $to = join( ', ', @toEmails );
    _debug("to=$to");

    # get FROM
    my $from;
    if ( $TWiki::cfg{SendEmailPlugin}{AlwaysFromTheUser} ) {
        $from = TWiki::Func::wikiToEmail(TWiki::Func::getWikiName());
    }
    else {
        $from = $query->param('from') || $query->param('From');
        unless ($from) {
            # get from user settings
            my $emails = TWiki::Func::wikiToEmail();
            my @emails = split( /\s*,*\s/, $emails );
            $from = shift @emails if @emails;
        }
        unless ($from) {
            # fallback to webmaster
            $from = $TWiki::cfg{WebMasterEmail}
              || TWiki::Func::getPreferencesValue('WIKIWEBMASTER');
        }
    }

    # validate FROM
    return _finishSendEmail( $session, $ERROR_STATUS{'error'},
        $ERROR_EMPTY_FROM_EMAIL, $redirectUrl )
      unless $from;

    if (  !_matchesSetting( 'Allow', 'MailFrom', $from )
        || _matchesSetting( 'Deny', 'MailFrom', $from ) )
    {
        $errorMessage = $ERROR_NO_PERMISSION_FROM;
        $errorMessage =~ s/\$EMAIL/$from/go;
        TWiki::Func::writeWarning($errorMessage);
        return _finishSendEmail( $session, $ERROR_STATUS{'error'},
            $errorMessage, $redirectUrl );
    }

    unless ( $from =~ m/$emailRE/ ) {
        $errorMessage = $ERROR_INVALID_ADDRESS;
        $errorMessage =~ s/\$EMAIL/$from/go;
        return _finishSendEmail( $session, $ERROR_STATUS{'error'},
            $errorMessage, $redirectUrl );
    }
    _debug("from=$from");

    # get CC
    my $cc = $query->param('cc') || $query->param('CC') || '';

    if ($cc) {
        my @ccEmails = ();
        foreach my $thisCC ( split( /\s*,\s*/, $cc ) ) {
            my $addrs;

            if ( $thisCC =~ /$emailRE/ ) {
                # normal email address
                $addrs = $thisCC;
                # validate CC
                if (!_matchesSetting('Allow', 'MailCc', $addrs) || 
                    _matchesSetting('Deny', 'MailCc', $addrs)) {
                    $errorMessage = $ERROR_NO_PERMISSION_CC;
                    $errorMessage =~ s/\$EMAIL/$thisCC/go;
                    TWiki::Func::writeWarning($errorMessage);
                    return _finishSendEmail( $session, $ERROR_STATUS{'error'},
                        $errorMessage, $redirectUrl );
                }
            }
            else {

                # get from user info
                $addrs = TWiki::Func::wikiToEmail($thisCC);
                unless ($addrs) {

                    # no regular address and no address found in user info

                    $errorMessage = $ERROR_INVALID_ADDRESS;
                    $errorMessage =~ s/\$EMAIL/$thisCC/go;
                    return _finishSendEmail( $session, $ERROR_STATUS{'error'},
                        $errorMessage, $redirectUrl );
                }
            }

            push @ccEmails, $addrs;
        }
        $cc = join( ', ', @ccEmails );
        _debug("cc=$cc");
    }

    # get SUBJECT
    my $subject = $query->param('subject');
    $subject = $query->param('Subject') unless ( defined($subject) );
    $subject = '' unless ( defined($subject) );
    if ( $subject ) {
	_debug("subject=$subject");
	$subject = TWiki::Func::expandCommonVariables($subject);
	if ( $subject =~ /[\x80-\xff]/ ) {
	    my $charset = $TWiki::cfg{Site}{CharSet} || '';
	    if ( $charset =~ /utf/i ) {
		$subject = "=?$charset?B?" .
		    encode_base64($subject, '') . '?=';
	    }
	    else {
		$subject = "=?$charset?Q?" .
		    encode_qp($subject, '') . '?=';
	    }
	}
    }

    # get BODY
    my $body = $query->param('body') || $query->param('Body') || '';
    _debug("body=$body") if $body;

    # get template
    my $templateName = $query->param('mailtemplate') || 'SendEmailPluginTemplate';
    # remove 'Template' at end - stupid TWiki solution from the old days
    $templateName =~ s/^(.*?)Template$/$1/;
    
    my $template = TWiki::Func::readTemplate($templateName);
    my $expandTmpl = $TWiki::cfg{SendEmailPlugin}{ExpandVariablesInTemplate};
    _debug("templateName=$templateName expand=$expandTmpl");
    unless ($template) {
        if ( $expandTmpl ) {
        $template = <<'HERE';
+From: %SENDEMAIL_FROM%
+To: %SENDEMAIL_TO%
+CC: %SENDEMAIL_CC%
+Subject: %SENDEMAIL_SUBJECT%

%SENDEMAIL_BODY%
HERE
        }
        else {
        $template = <<'HERE';
+From: %FROM%
+To: %_TO%
+CC: %CC%
+Subject: %SUBJECT%

%BODY%
HERE
       }
    }
    _debug("template=$template");

    # format email
    my $mail = $template;
    if ( $expandTmpl ) {
        $mail = TWiki::Func::expandCommonVariables($template);
        # "FROM, TO, CC..." variables are too simple and might cause conflicts easily.
        $mail =~ s/%SENDEMAIL_FROM%/$from/go;
        $mail =~ s/%SENDEMAIL_TO%/$to/go;
        $mail =~ s/%SENDEMAIL_CC%/$cc/go;
        $mail =~ s/%SENDEMAIL_SUBJECT%/$subject/go;
        $mail =~ s/%SENDEMAIL_BODY%/$body/go;
    }
    else {
        $mail =~ s/%FROM%/$from/go;
        $mail =~ s/%TO%/$to/go;
        $mail =~ s/%CC%/$cc/go;
        $mail =~ s/%SUBJECT%/$subject/go;
        $mail =~ s/%BODY%/$body/go;
    }
    _debug("mail=\n$mail");

    # send email
    $errorMessage = TWiki::Func::sendEmail( $mail, $RETRY_COUNT );
    
    # finally
    my $errorStatus =
      $errorMessage ? $ERROR_STATUS{'error'} : $ERROR_STATUS{'noerror'};

    return _finishSendEmail( $session, $errorStatus, $errorMessage,
        $redirectUrl );

    return 0;
}

=pod

Checks if a given value matches a preferences pattern. The pref pattern
actually is a list of patterns. The function returns true if 
at least one of the patterns in the list matches.

=cut

sub _matchesSetting {
    my ( $mode, $key, $value ) = @_;
    _debug("called matchesPreference($mode, $key, $value)");

    my $pluginName = $TWiki::Plugins::SendEmailPlugin::pluginName;
    my $pattern = $TWiki::cfg{Plugins}{$pluginName}{Permissions}{$mode}{$key};

    _debug("called _matchesSetting($mode, $key, $value)");
    _debug("matching pattern=$pattern");
    _debug( "mode=" . ( $mode =~ /Allow/i ? 1 : 0 ) );

    if ( $mode =~ /Deny/i && !$pattern ) {

        # no pattern, so noone is denied
        return 0;
    }

    $pattern =~ s/^\s//o;
    $pattern =~ s/\s$//o;
    $pattern = '(' . join( ')|(', split( /\s*,\s*/, $pattern ) ) . ')';

    _debug("final matching pattern=$pattern");

    my $result = ( $value =~ /$pattern/i ) ? 1 : 0;

    _debug("result=$result");

    return $result;
}

=pod

=cut

sub handleSendEmailTag {
    my ( $session, $params, $topic, $web ) = @_;

    init( $session );
    _addHeader();

    my $query = TWiki::Func::getCgiQuery();
    return '' if !$query;

    my $errorStatus = $query->param($ERROR_STATUS_TAG);
    my $errorMessage = $query->param($ERROR_MESSAGE_TAG) || '';

    my $feedbackSuccess = $params->{'feedbackSuccess'};
    my $feedbackError   = $params->{'feedbackError'};
    my $format          = $params->{'format'};

    _debug("handleSendEmailTag; errorStatus=$errorStatus")
      if $errorStatus;

    return '' if !defined $errorStatus;

    unless ( defined $feedbackSuccess ) {
        $feedbackSuccess = $EMAIL_SENT_SUCCESS_MESSAGE
          || '';
    }
    $feedbackSuccess =~ s/^\s*(.*?)\s*$/$1/go;    # remove surrounding spaces

    unless ( defined $feedbackError ) {
        $feedbackError = $EMAIL_SENT_ERROR_MESSAGE || '';
    }

    my $userMessage =
      ( $errorStatus == $ERROR_STATUS{'error'} )
      ? $feedbackError
      : $feedbackSuccess;

    $userMessage =~ s/^[[:space:]]+//s;           # trim at start
    $userMessage =~ s/[[:space:]]+$//s;           # trim at end

    my $notificationMessage =
      _createNotificationMessage( $userMessage, $errorStatus, $errorMessage,
        defined $format );

    if ($format) {
        $format =~ s/\$message/$notificationMessage/;
        $notificationMessage = $format;
    }
    return _wrapHtmlNotificationContainer($notificationMessage);
}

=pod

=cut

sub _finishSendEmail {
    my ( $session, $errorStatus, $errorMessage, $redirectUrl ) = @_;

    my $query = TWiki::Func::getCgiQuery();

    _debug("_finishSendEmail errorStatus=$errorStatus;")
      if $errorStatus;
    _debug("_finishSendEmail redirectUrl=$redirectUrl;")
      if $redirectUrl;

    $query->param( -name => $ERROR_STATUS_TAG, -value => $errorStatus )
      if $query;

    $errorMessage ||= '';
    _debug("_finishSendEmail errorMessage=$errorMessage;")
      if $errorMessage;

    $query->param( -name => $ERROR_MESSAGE_TAG, -value => $errorMessage )
      if $query;

    my $web     = $session->{webName};
    my $topic   = $session->{topicName};
    my $origUrl = TWiki::Func::getScriptUrl( $web, $topic, 'view' );

    $query->param( -name => 'origurl', -value => $origUrl );

    my $section = $query->param(
        ( $errorStatus == $ERROR_STATUS{'error'} )
        ? 'errorsection'
        : 'successsection'
    );

    $query->param( -name => 'section', -value => $section )
      if $section;

    $redirectUrl ||= $origUrl;
    $redirectUrl = "$redirectUrl#$NOTIFICATION_ANCHOR_NAME";

    _debug("_finishSendEmail redirecting to $redirectUrl");
    TWiki::Func::redirectCgiQuery( undef, $redirectUrl, 1, undef, 1 );
    return 0;
}

=pod

=cut

sub _addHeader {

    my $header = <<'EOF';
<style type="text/css" media="all">
@import url("%PUBURL%/%SYSTEMWEB%/SendEmailPlugin/sendemailplugin.css");
</style>
EOF
    TWiki::Func::addToHEAD( 'SENDEMAILPLUGIN', $header );
}

=pod

=cut

sub _createNotificationMessage {
    my ( $text, $errorStatus, $errorMessage, $customFormat ) = @_;

    if ($customFormat) {
        return "$text $errorMessage";
    }

    my $cssClass = $NOTIFICATION_CSS_CLASS;
    $cssClass .= ' ' . $NOTIFICATION_ERROR_CSS_CLASS
      if ( $errorStatus == $ERROR_STATUS{'error'} );

    return CGI::div( { class => $cssClass }, "$text $errorMessage" );
}

=pod

=cut

sub _wrapHtmlNotificationContainer {
    my ($notificationMessage) = @_;

    return CGI::a( { name => $NOTIFICATION_ANCHOR_NAME }, '<!--#-->' ) . "\n"
      . $notificationMessage;
}

1;
