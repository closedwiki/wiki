# Module of TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2001-2004 Peter Thoeny, peter@thoeny.com
#
# For licensing info read license.txt file in the TWiki root.
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at 
# http://www.gnu.org/copyleft/gpl.html
#

=begin twiki

---+ TWiki::Net Module

Object that brokers access to network resources.

=cut

package TWiki::Net;

use strict;
use Assert;

sub new {
    my ( $class, $session ) = @_;
    assert(ref($session) eq "TWiki") if DEBUG;
    my $this = bless( {}, $class );

    $this->{session} = $session;

    $this->{USENETSMTP} = 0;
    $this->{MAILINITIALIZED} = 0;

    return $this;
}

sub users { my $this = shift; return $this->{session}->{users}; }
sub prefs { my $this = shift; return $this->{session}->{prefs}; }
sub store { my $this = shift; return $this->{session}->{store}; }
sub sandbox { my $this = shift; return $this->{session}->{sandbox}; }
sub security { my $this = shift; return $this->{session}->{security}; }
sub templates { my $this = shift; return $this->{session}->{templates}; }
sub renderer { my $this = shift; return $this->{session}->{renderer}; }

=pod

---++ sub getUrl (  $theHost, $thePort, $theUrl, $theUser, $thePass, $theHeader  )

Get the text at the other end of a URL

=cut

sub getUrl {
    my ( $this, $theHost, $thePort, $theUrl, $theUser, $thePass, $theHeader ) = @_;
    assert(ref($this) eq "TWiki::Net") if DEBUG;

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

    my $proxyHost = $this->prefs()->getPreferencesValue("PROXYHOST");
    my $proxyPort = $this->prefs()->getPreferencesValue("PROXYPORT");
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

# =========================
=pod

---++ sub sendEmail (  $theText  )

Send an email specified as MIME format content.

=cut

sub sendEmail {
    # $theText Format: "Date: ...\nFrom: ...\nTo: ...\nCC: ...\nSubject: ...\n\nMailBody..."

    my( $this, $theText, $retries ) = @_;
    assert(ref($this) eq "TWiki::Net") if DEBUG;

    # Put in a Date header, mainly for Qmail
    my $dateStr = TWiki::formatTime(time, 'email');
    $theText = "Date: " . $dateStr . "\n" . $theText;

    # Check if Net::SMTP is available
    unless( $this->{MAILINITIALIZED} ) {
        $this->{MAILINITIALIZED} = 1;
        $this->{MAIL_HOST}  = $this->prefs()->getPreferencesValue( "SMTPMAILHOST" );
        $this->{HELLO_HOST} = $this->prefs()->getPreferencesValue( "SMTPSENDERHOST" );
        if( $this->{MAIL_HOST} ) {
            eval {	# May fail if Net::SMTP not installed
                $this->{USENETSMTP} = require Net::SMTP;
            }
        }
    }

    my $from = "";
    my @to = ();
    if( $this->{USENETSMTP} ) {
        my ( $header, $body ) = split( "\n\n", $theText, 2 );
        my @headerlines = split( /\n/, $header );
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
        if( ! ( $from ) ) {
            return "ERROR: Can't send mail, missing 'From:'";
        }

        # extract @to from 'To:', 'CC:', 'BCC:'
        @arr = grep( /^To: /i, @headerlines );
        my $tmp = "";
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
            return "ERROR: Can't send mail, missing receipient";
        }
    } else {
        # send with sendmail
        my ( $header, $body ) = split( "\n\n", $theText, 2 );
        $header =~ s/([\n\r])(From|To|CC|BCC)(\:\s*)([^\n\r]*)/$1 . $2 . $3 . _fixLineLength( $4 )/geois;
        $theText = "$header\n\n$body";   # rebuild message
    }

    my $errors = "";
    my $back_off = 1; # seconds, doubles on each retry
    while ( $retries ) {
        my $error;
        if( $this->{USENETSMTP} ) {
            $error = $this->_sendEmailByNetSMTP( $from, \@to, $theText );
        } else {
            $error = $this->_sendEmailBySendmail( $theText );
        }
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

    if( open( MAIL, "|-" ) || exec "$TWiki::mailProgram" ) {
        print MAIL $theText;
        close( MAIL );
        return "";
    }
    return "ERROR: Can't send mail using TWiki::mailProgram";
}

sub _sendEmailByNetSMTP {
    my( $this, $from, $toref, $data ) = @_;

    my @to;
    # $to is not a reference then it must be a single email address
    @to = ($toref) unless ref( $toref ); 
    if ( ref( $toref ) =~ /ARRAY/ ) {
        @to = @{$toref};
    }
    return undef unless( scalar @to );

    my $smtp = 0;
    if( $this->{HELLO_HOST} ) {
        $smtp = Net::SMTP->new( $this->{MAIL_HOST},
                                Hello => $this->{HELLO_HOST} );
    } else {
        $smtp = Net::SMTP->new( $this->{MAIL_HOST} );
    }
    my $status = "";
    if ($smtp) {
        {
            $smtp->mail( $from ) or last;
            $smtp->to( @to, { SkipBad => 1 } ) or last;
            $smtp->data( $data ) or last;
            $smtp->dataend() or last;
        }
        $status = ($smtp->ok() ? "" : "ERROR: Can't send mail using Net::SMTP. " . $smtp->message );
        $smtp->quit();
    } else {
        $status = "ERROR: Can't send mail using Net::SMTP (can't connect to '$this->{MAIL_HOST}')";
    }
    return $status;
}

1;
