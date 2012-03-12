# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2012 Hypertek lnc
# Copyright (C) 2012 Peter Thoeny, peter[at]thoeny.org
# Copyright (C) 2012 TWiki Contributors.
# All Rights Reserved. TWiki Contributors are listed in the AUTHORS
# file in the root of this distribution.
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

package TWiki::Plugins::SendMailPlugin;
use strict;
our $pluginName = 'SendMailPlugin';

require TWiki::Func;    # The plugins API
require TWiki::Plugins; # For the API version

our $VERSION = '$Rev$';
our $RELEASE = '2012-03-12';

# One line description, is shown in the %SYSTEMWEB%.TextFormattingRules topic:
our $SHORTDESCRIPTION = 'Send mail from TWiki topics, useful for workflow automation';

our $NO_PREFS_IN_TOPIC = 1;
our $debug;

#=====================================================================
sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.1 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    $debug = $TWiki::cfg{Plugins}{SendMailPlugin}{Debug} || 0;

    TWiki::Func::registerTagHandler( 'SENDMAIL', \&_SENDMAIL );

    # Plugin correctly initialized
    return 1;
}

#=====================================================================
sub _SENDMAIL {
    my($session, $params, $theTopic, $theWeb, $meta, $textRef) = @_;

    my $action = $params->{action};
    return '' unless( $action eq 'send' );

    my $from    = expandEmail( $TWiki::cfg{Plugins}{SendMailPlugin}{From}
                  || $params->{from} || '$webmastername <$webmasteremail>' );
    my $to      = expandEmail( $TWiki::cfg{Plugins}{SendMailPlugin}{To}
                  || $params->{to}   || '$webmastername <$webmasteremail>' );;
    my $cc      = expandEmail( $TWiki::cfg{Plugins}{SendMailPlugin}{CC}
                  || $params->{cc}   || '' );
    my $bcc     = expandEmail( $TWiki::cfg{Plugins}{SendMailPlugin}{BCC}
                  || $params->{bcc}  || '' );
    my $subject = TWiki::Func::decodeFormatTokens( $params->{subject}
                  || 'SendMailPlugin Note: For subject specify subject="..." parameter' );
    my $text    = TWiki::Func::decodeFormatTokens( $params->{text}
                  || 'SendMailPlugin Note: For e-mail body specify text="..." parameter' );
    my $success = TWiki::Func::decodeFormatTokens( $params->{success} || '' );
    my $error   = TWiki::Func::decodeFormatTokens( $params->{error}   || '$error' );

    my $email = "From: $from\n";
    $email   .= "To: $to\n";
    $email   .= "CC: $cc\n"   if( $cc  && $cc  !~ /^disable$/i );
    $email   .= "BCC: $bcc\n" if( $bcc && $bcc !~ /^disable$/i );
    $email   .= "Subject: $subject\n\n";
    $email   .= "$text\n";
    if( $debug ) {
        TWiki::Func::writeDebug( "TWiki::Plugins::SendMailPlugin e-mail:" );
        TWiki::Func::writeDebug( "===( START )=============" );
        TWiki::Func::writeDebug( "$email" );
        TWiki::Func::writeDebug( "===(  END  )=============" );
    }
    my $sendErr = TWiki::Func::sendEmail( $email );
    if( $sendErr ) {
        $sendErr =~ s/[\n\r]/ /go;
        if( $debug ) {
            TWiki::Func::writeDebug( "TWiki::Plugins::SendMailPlugin e-mail error: $sendErr" );
        }
        $error =~ s/\$error/$sendErr/g;
        return $error;
    }
    return $success;
}

#=====================================================================
sub expandEmail {
    my( $text ) = @_;

    return '' unless( $text );
    my $userEmail = join( ', ', TWiki::Func::wikinameToEmails() );
    my $userWikiName = TWiki::Func::getWikiName();
    $text =~ s/\$useremail/ join( ', ', TWiki::Func::wikinameToEmails() ) /geo;
    $text =~ s/\$username/ TWiki::Func::getWikiName() /geo;
    $text =~ s/\$webmasteremail/$TWiki::cfg{WebMasterEmail}/go;
    $text =~ s/\$webmastername/$TWiki::cfg{WebMasterName}/go;
    return $text;
}

#=====================================================================
1;
