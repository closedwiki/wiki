#
# TWiki WikiClone (see wiki.pm for $wikiversion and other info)
#
# Copyright (C) 2001 Peter Thoeny, Peter@Thoeny.com
#
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
# Notes:
# - Latest version at http://twiki.org/
# - Installation instructions in $dataDir/TWiki/TWikiDocumentation.txt
# - Customize variables in TWiki.cfg when installing TWiki.
#
#  14-02-2001 - Nicholas Lee
#             - Created to partition network related functions from 
#               core TWiki.pm utilities
#             - Moved sendEmail from TWiki.pm 
#             
package TWiki::Net;

use strict;

use vars qw(
        $useSocket $useNetSmtp
        $mailInitialized $mailHost $helloHost
    );

BEGIN {
    $useSocket = 0;
    $useNetSmtp = 0;
    $mailInitialized = 0;
}

# =========================
sub getUrl
{
    my ( $theHost, $thePort, $theUrl, $theHeader ) = @_;

    if( ! $useSocket ) {
        use Socket;
        $useSocket = 1;
    }
    if( $thePort < 1 ) {
        $thePort = 80;
    }
    if( ! $theHeader ) {
        $theHeader = "";
    }
    my $result = '';
    my $req = "GET $theUrl HTTP/1.0\r\n$theHeader\r\n\r\n";
    my ( $iaddr, $paddr, $proto );
    $iaddr   = inet_aton( $theHost );
    $paddr   = sockaddr_in( $thePort, $iaddr );
    $proto   = getprotobyname( 'tcp' );
    unless( socket( SOCK, PF_INET, SOCK_STREAM, $proto ) ) {
        &TWiki::writeWarning( "TWiki::Net::getUrl socket: $!" );
        return "content-type: text/plain\n\nERROR: TWiki::Net::getUrl socket: $!";
    }
    unless( connect( SOCK, $paddr ) ) {
        &TWiki::writeWarning( "TWiki::Net::getUrl connect: $!" );
        return "content-type: text/plain\n\nERROR: TWiki::Net::getUrl connect: $!";
    }
    select SOCK; $| = 1;
    print SOCK $req;
    while( <SOCK> ) { $result .= $_; }
    unless( close( SOCK ) ) {
        &TWiki::writeWarning( "TWiki::Net::getUrl close: $!" );
    }
    select STDOUT;
    return $result;
}

# =========================
sub sendEmail
{
    # $theText Format: "From: ...\nTo: ...\nCC: ...\nSubject: ...\n\nMailBody..."

    my( $theText ) = @_;

    if( ! $mailInitialized ) {
        $mailInitialized = 1;
        $mailHost  = &TWiki::Prefs::getPreferencesValue( "SMTPMAILHOST" );
        $helloHost = &TWiki::Prefs::getPreferencesValue( "SMTPSENDERHOST" );
        if( $mailHost ) {
            eval {
               $useNetSmtp = require Net::SMTP;
            }
        }
    }

    my $error = "";
    if( $useNetSmtp ) {
        my ( $header, $body ) = split( "\n\n", $theText, 2 );
        my @headerlines = split( /\n/, $header );
        $header =~ s/\nBCC\:[^\n]*//os;  #remove BCC line from header
        $theText = "$header\n\n$body";   # rebuild message

        # extract 'From:'
        my $from = "";
        my @arr = grep( /^From: /i, @headerlines );
        if( scalar( @arr ) ) {
            $from = $arr[0];
            $from =~ s/^From:\s*//io;
        }
        if( ! ( $from ) ) {
            return "ERROR: Can't send mail, missing 'From:'";
        }

        # extract @to from 'To:', 'CC:', 'BCC:'
        my @to = ();
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

        $error = _sendEmailByNetSMTP( $from, \@to, $theText );

    } else {
        $error = _sendEmailBySendmail( $theText );
    }
    return $error;
}

# =========================
sub _sendEmailBySendmail
{

    my( $theText ) = @_;

    if( open( MAIL, "|-" ) || exec "$TWiki::mailProgram" ) {
        print MAIL $theText;
        close( MAIL );
        return "";
    }
    return "ERROR: Can't send mail using TWiki::mailProgram";
}

# =========================
sub _sendEmailByNetSMTP
{
    my( $from, $toref, $data ) = @_;

    my @to;
    # $to is not a reference then it must be a single email address
    @to = ($toref) unless ref( $toref ); 
    if ( ref( $toref ) =~ /ARRAY/ ) {
	@to = @{$toref};
    }
    return undef unless( scalar @to );
    
    my $smtp = 0;
    if( $helloHost ) {
        $smtp = Net::SMTP->new( $mailHost, Hello => $helloHost );
    } else {
        $smtp = Net::SMTP->new( $mailHost );
    }
    $smtp->mail( $from );
    $smtp->to( @to, { SkipBad => 1 } );
    $smtp->data( $data );
    $smtp->dataend();
    
    # I think this has to occur before the $smtp->quit, 
    # otherwise we'll miss the status message for the sending of the mail.
    my $status = ($smtp->ok() ? "" : "ERROR: Can't send mail using Net::SMTP" );

    $smtp->quit();
    return $status;    
}

# =========================

1;

# EOF
