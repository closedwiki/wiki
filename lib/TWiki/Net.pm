# TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 1999-2005 Peter Thoeny, peter@thoeny.com
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
# As per the GPL, removal of this notice is prohibited.

=begin twiki

---+ package TWiki::Net

Object that brokers access to network resources.

=cut

package TWiki::Net;

use strict;
use Assert;
use TWiki::Time;
use TWiki::Sandbox;

sub new {
    my ( $class, $session ) = @_;
    ASSERT($session->isa( 'TWiki')) if DEBUG;
    my $this = bless( {}, $class );

    $this->{session} = $session;
    $this->{mailHandler} = undef;

    return $this;
}

=pod

---++ ObjectMethod getUrl (  $theHost, $thePort, $theUrl, $theUser, $thePass, $theHeader  ) -> $text

Get the text at the other end of a URL

=cut

sub getUrl {
    my ( $this, $theHost, $thePort, $theUrl, $theUser, $thePass, $theHeader ) = @_;
    ASSERT($this->isa( 'TWiki::Net')) if DEBUG;

    # Run-time use of Socket module when needed
    require Socket;
    import Socket qw(:all);

    if( $thePort < 1 ) {
        $thePort = 80;
    }
    my $base64;
    my $result = '';
    $theUrl = "/" unless( $theUrl );
    my $req = "GET $theUrl HTTP/1.0\r\n";

    $req .= "Host: $theHost:$thePort\r\n";
    if( $theUser && $thePass ) {
        # Use MIME::Base64 at run-time if using outbound proxy with
        # authentication
        require MIME::Base64;
        import MIME::Base64 ();
        $base64 = encode_base64( "$theUser:$thePass", "\r\n" );
        $req .= "Authorization: Basic $base64";
    }

    my $prefs = $this->{session}->{prefs};
    my $proxyHost = $prefs->getPreferencesValue('PROXYHOST') ||
      $TWiki::cfg{PROXY}{HOST};
    my $proxyPort = $prefs->getPreferencesValue('PROXYPORT') ||
      $TWiki::cfg{PROXY}{PORT};
    if($proxyHost && $proxyPort) {
        $req = "GET http://$theHost:$thePort$theUrl HTTP/1.0\r\n";
        $theHost = $proxyHost;
        $thePort = $proxyPort;
    }

    $req .= $theHeader if( $theHeader );
    $req .= "\r\n\r\n";

    my ( $iaddr, $paddr, $proto );
    $iaddr   = inet_aton( $theHost );
    $paddr   = sockaddr_in( $thePort, $iaddr );
    $proto   = getprotobyname( 'tcp' );
    unless( socket( *SOCK, &PF_INET, &SOCK_STREAM, $proto ) ) {
        $this->{session}->writeWarning( "TWiki::Net::getUrl socket: $!" );
        return "content-type: text/plain\n\nERROR: TWiki::Net::getUrl socket: $!.";
    }
    unless( connect( *SOCK, $paddr ) ) {
        $this->{session}->writeWarning( "TWiki::Net::getUrl connect: $!" );
        return "content-type: text/plain\n\nERROR: TWiki::Net::getUrl connect: $!. \n$req";
    }
    select SOCK; $| = 1;
    print SOCK $req;
    while( <SOCK> ) { $result .= $_; }
    unless( close( SOCK ) ) {
        $this->{session}->writeWarning( "TWiki::Net::getUrl close: $!" );
    }
    select STDOUT;
    return $result;
}

# pick a default mail handler
sub _installMailHandler {
    my $this = shift;
    my $useNetSMTP = 0;
    my $prefs = $this->{session}->{prefs};

    $this->{MAIL_HOST}  = $prefs->getPreferencesValue( 'SMTPMAILHOST' ) ||
      $TWiki::cfg{SMTP}{MAILHOST};
    $this->{HELLO_HOST} = $prefs->getPreferencesValue( 'SMTPSENDERHOST' ) ||
      $TWiki::cfg{SMTP}{SENDERHOST};
    if( $this->{MAIL_HOST} ) {
        # See Codev.RegisterFailureInsecureDependencyCygwin for why
        # this must be untainted
        $this->{MAIL_HOST} =
          TWiki::Sandbox::untaintUnchecked( $this->{MAIL_HOST} );
        eval {	# May fail if Net::SMTP not installed
            $useNetSMTP = require Net::SMTP;
        }
    }
    if( $useNetSMTP ) {
        $this->setMailHandler( \&_sendEmailByNetSMTP );
    } else {
        $this->setMailHandler( \&_sendEmailBySendmail );
    }
}

=pod

---++ setMailHandler( \&fn )
   * =\&fn= - reference to a function($) (see _sendEmailBySendmail for proto)
Install a handler function to take over mail sending from the default
SMTP or sendmail methods. This is provided mainly for tests that
need to be told when a mail is sent, without actually sending it. It
may also be useful in the event that someone needs to plug in an
alternative mail handling method.

=cut

sub setMailHandler {
    my( $this, $fnref ) = @_;
    ASSERT( $fnref ) if DEBUG;
    $this->{mailHandler} = $fnref;
}

=pod

---++ ObjectMethod sendEmail ( $theText, $retries ) -> $error
   * =$theText= - text of the mail, including MIME headers
   * =$retries= - number of times to retry the send (default 1)

Send an email specified as MIME format content.
Date: ...\nFrom: ...\nTo: ...\nCC: ...\nSubject: ...\n\nMailBody...

=cut

sub sendEmail {
    my( $this, $theText, $retries ) = @_;
    ASSERT($this->isa( 'TWiki::Net')) if DEBUG;
    $retries ||= 1;

    unless( defined $this->{mailHandler} ) {
        $this->_installMailHandler();
    }

    # Put in a Date header, mainly for Qmail
    my $dateStr = TWiki::Time::formatTime(time, '$email');
    $theText = "Date: " . $dateStr . "\n" . $theText;

    my $errors = '';
    my $back_off = 1; # seconds, doubles on each retry
    while ( $retries ) {
        my $error = &{$this->{mailHandler}}( $this, $theText );
        if( $error ) {
            $errors .= "$error\n";
            if ( --$retries ) {
                sleep( $back_off );
                $back_off *= 2;
            } else {
                $this->{session}->writeWarning( "Net::sendEmail: too many failures; aborting send" );
                return $errors;
            }
        } else {
            #$this->{session}->writeDebug( "Mailed $mail" );
            return undef;
        }
    }
    return undef;
}

sub _fixLineLength {
    my( $theAddrs ) = @_;
    # split up header lines that are too long
    $theAddrs =~ s/(.{60}[^,]*,\s*)/$1\n        /go;
    $theAddrs =~ s/\n\s*$//gos;
    return $theAddrs;
}

sub _sendEmailBySendmail {
    my( $this, $theText ) = @_;

    # send with sendmail
    my ( $header, $body ) = split( "\n\n", $theText, 2 );
    $header =~ s/([\n\r])(From|To|CC|BCC)(\:\s*)([^\n\r]*)/$1.$2.$3._fixLineLength($4)/geois;
    $theText = "$header\n\n$body";   # rebuild message

    # SMELL: This should use the sandbox, shouldn't it?
    if( open( MAIL, "|-" ) || exec "$TWiki::cfg{MailProgram}" ) {
        print MAIL $theText;
        close( MAIL );
        return '';
    }
    # SMELL: should be a TWiki::inlineAlert
    return "ERROR: Can't send mail using TWiki::cfg{MailProgram}";
}

sub _sendEmailByNetSMTP {
    my( $this, $theText ) = @_;

    my $from = '';
    my @to = ();

    my ( $header, $body ) = split( "\n\n", $theText, 2 );
    my @headerlines = split( /\r?\n/, $header );
    $header =~ s/\nBCC\:[^\n]*//os;  #remove BCC line from header
    $header =~ s/([\n\r])(From|To|CC|BCC)(\:\s*)([^\n\r]*)/$1 . $2 . $3 . _fixLineLength( $4 )/geois;
    $theText = "$header\n\n$body";   # rebuild message

    # extract 'From:'
    my @arr = grep( /^From: /i, @headerlines );
    if( scalar( @arr ) ) {
        $from = $arr[0];
        $from =~ s/^From:\s*//io;
        $from =~ s/.*<(.*?)>.*/$1/o; # extract "user@host" out of "Name <user@host>"
    }
    unless( $from ) {
        # SMELL: should be a TWiki::inlineAlert
        return "ERROR: Can't send mail, missing 'From:'";
    }

    # extract @to from 'To:', 'CC:', 'BCC:'
    @arr = grep( /^To: /i, @headerlines );
    my $tmp = '';
    if( scalar( @arr ) ) {
        $tmp = $arr[0];
        $tmp =~ s/^To:\s*//io;
        @arr = split( /[,\s]+/, $tmp );
        push( @to, @arr );
    }
    @arr = grep( /^CC: /i, @headerlines );
    if( scalar( @arr ) ) {
        $tmp = $arr[0];
        $tmp =~ s/^CC:\s*//io;
        @arr = split( /[,\s]+/, $tmp );
        push( @to, @arr );
    }
    @arr = grep( /^BCC: /i, @headerlines );
    if( scalar( @arr ) ) {
        $tmp = $arr[0];
        $tmp =~ s/^BCC:\s*//io;
        @arr = split( /[,\s]+/, $tmp );
        push( @to, @arr );
    }
    if( ! ( scalar( @to ) ) ) {
        # SMELL: should be a TWiki::inlineAlert
        return "ERROR: Can't send mail, missing recipient";
    }

    return undef unless( scalar @to );

    my $smtp = 0;
    if( $this->{HELLO_HOST} ) {
        $smtp = Net::SMTP->new( $this->{MAIL_HOST},
                                Hello => $this->{HELLO_HOST} );
    } else {
        $smtp = Net::SMTP->new( $this->{MAIL_HOST} );
    }
    my $status = '';
    if ($smtp) {
        {
            $smtp->mail( $from ) or last;
            $smtp->to( @to, { SkipBad => 1 } ) or last;
            $smtp->data( $theText ) or last;
            $smtp->dataend() or last;
        }
        # SMELL: should be a TWiki::inlineAlert
        $status = ($smtp->ok() ? '' : "ERROR: Can't send mail using Net::SMTP. " . $smtp->message );
        $smtp->quit();
    } else {
        # SMELL: should be a TWiki::inlineAlert
        $status = "ERROR: Can't send mail using Net::SMTP (can't connect to '$this->{MAIL_HOST}')";
    }
    return $status;
}

1;
