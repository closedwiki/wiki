# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2001-2012 Peter Thoeny, peter[at]thoeny.org
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

# This module is used by configure, and as such must *not* 'use TWiki',
# or any other module that uses it. Always run configure to test after
# changing the module.

package TWiki::Net;

use strict;
use Assert;
use Error qw( :try );

# note that the session is *optional*
sub new {
    my ( $class, $session ) = @_;
    my $this = bless( { session => $session }, $class );

    $this->{mailHandler} = undef;

    return $this;
}

=begin twiki

---++ ObjectMethod finish()
Break circular references.

=cut

# Note to developers; please undef *all* fields in the object explicitly,
# whether they are references or not. That way this method is "golden
# documentation" of the live fields in the object.
sub finish {
    my $this = shift;
    undef $this->{mailHandler};
    undef $this->{HELLO_HOST};
    undef $this->{MAIL_HOST};
    undef $this->{session};
}

=pod

---+++ getExternalResource( $url, @headers ) -> $response

Get whatever is at the other end of a URL (using an HTTP GET request). Will
only work for encrypted protocols such as =https= if the =LWP= CPAN module is
installed.

Note that the =$url= may have an optional user and password, as specified by
the relevant RFC. Any proxy set in =configure= is honored.

Optional headers may be supplied of form 'name1', 'value1', 'name2', 'value2'.
Do not add a User-Agent header, it will be added.

The =$response= is an object that is known to implement the following subset of
the methods of =LWP::Response=. It may in fact be an =LWP::Response= object,
but it may also not be if =LWP= is not available, so callers may only assume
the following subset of methods is available:
| =code()= |
| =message()= |
| =header($field)= |
| =content()= |
| =is_error()= |
| =is_redirect()= |

Note that if LWP is *not* available, this function:
   1 can only really be trusted for HTTP/1.0 urls. If HTTP/1.1 or another
     protocol is required, you are *strongly* recommended to =require LWP=.
   1 Will not parse multipart content

In the event of the server returning an error, then =is_error()= will return
true, =code()= will return a valid HTTP status code
as specified in RFC 2616 and RFC 2518, and =message()= will return the
message that was received from
the server. In the event of a client-side error (e.g. an unparseable URL)
then =is_error()= will return true and =message()= will return an explanatory
message. =code()= will return 400 (BAD REQUEST).

Note: Callers can easily check the availability of other HTTP::Response methods
as follows:

<verbatim>
my $response = TWiki::Func::getExternalResource($url);
if (!$response->is_error() && $response->isa('HTTP::Response')) {
    $text = $response->content();
    # ... other methods of HTTP::Response may be called
} else {
    # ... only the methods listed above may be called
}
</verbatim>

=cut

sub getExternalResource {
    my ( $this, $url, @headers ) = @_;

    my $protocol;
    if( $url =~ m!^([a-z]+):! ) {
        $protocol = $1;
    } else {
        require TWiki::Net::HTTPResponse;
        return new TWiki::Net::HTTPResponse( "Bad URL: $url" );
    }

    eval "use LWP";
    unless( $@ ) {
       return _GETUsingLWP( $this, $url, @headers );
    }

    # Fallback mechanism
    if( $protocol ne 'http') {
        require TWiki::Net::HTTPResponse;
        return new TWiki::Net::HTTPResponse( "LWP not available for handling protocol: $url" );
    }

    my $response;
    try {
        $url =~ s!^\w+://!!; # remove protocol
        my ( $user, $pass );
        if( $url =~ s!([^/\@:]+)(?::([^/\@:]+))?@!! ) {
            ( $user, $pass ) = ( $1, $2 || '');
        }

        unless( $url =~ s!([^:/]+)(?::([0-9]+))?!! ) {
            die "Bad URL: $url";
        }
        my( $host, $port ) = ( $1, $2 || 80);

        require Socket;
        import Socket qw(:all);

        $url = '/' unless( $url );
        my $req = "GET $url HTTP/1.0\r\n";

        $req .= "Host: $host:$port\r\n";
        if( $user ) {
            # Use MIME::Base64 at run-time if using outbound proxy with
            # authentication
            require MIME::Base64;
            import MIME::Base64 ();
            my $base64 = encode_base64( "$user:$pass", "\r\n" );
            $req .= "Authorization: Basic $base64";
        }

        my $useproxy = 1;
        if( defined( $TWiki::cfg{PROXY}{SkipProxyForDomains} ) ) { 
            my @skipdomains = split( /[\,\s]+/,  $TWiki::cfg{PROXY}{SkipProxyForDomains} );
            foreach my $domain ( @skipdomains ) {
                if( $url =~ /$domain$/ ) {
                    $useproxy = 0;
                }
            }
       }
 
        if ($useproxy) {

            # SMELL: Reference to TWiki variables used for compatibility
            my ($proxyHost, $proxyPort);
            if ($this->{session} && $this->{session}->{prefs}) {
                my $prefs = $this->{session}->{prefs};
                $proxyHost = $prefs->getPreferencesValue( 'PROXYHOST' );
                $proxyPort = $prefs->getPreferencesValue( 'PROXYPORT' );
            }
            $proxyHost ||= $TWiki::cfg{PROXY}{HOST};
            $proxyPort ||= $TWiki::cfg{PROXY}{PORT};
            if( $proxyHost && $proxyPort ) {
                $req = "GET http://$host:$port$url HTTP/1.0\r\n";
                $host = $proxyHost;
                $port = $proxyPort;
            }
        }

        '$Rev$'=~/([0-9]+)/;
        my $revstr=$1;

        $req .= 'User-Agent: TWiki::Net/'.$revstr."\r\n";
        if( @headers ) {
            while( my $key = shift @headers ) {
                my $val = shift( @headers );
                $req .= "$key: $val\r\n" if( defined $val );
            }
        }
        $req .= "\r\n\r\n";

        my ( $iaddr, $paddr, $proto );
        $iaddr = inet_aton( $host );
        die "Could not find IP address for $host" unless $iaddr;

        $paddr = sockaddr_in( $port, $iaddr );
        $proto = getprotobyname( 'tcp' );
        unless( socket( *SOCK, &PF_INET, &SOCK_STREAM, $proto ) ) {
            die "socket failed: $!";
        }
        unless( connect( *SOCK, $paddr ) ) {
            die "connect failed: $!";
        }
        select SOCK; $| = 1;
        local $/ = undef;
        print SOCK $req;
        my $result = '';
        $result = <SOCK>;
        unless( close( SOCK ) ) {
            die "close faied: $!";
        }
        select STDOUT;

        # No LWP, but may have HTTP::Response which would make life easier
        # (it has a much more thorough parser)
        eval 'require HTTP::Response';
        if ($@) {
            # Nope, no HTTP::Response, have to do things the hard way :-(
            require TWiki::Net::HTTPResponse;
            $response = TWiki::Net::HTTPResponse->parse( $result );
        } else {
            $response = HTTP::Response->parse( $result );
        }
    } catch Error::Simple with {
        require TWiki::Net::HTTPResponse;
        $response = new TWiki::Net::HTTPResponse( shift );
    };
    return $response;
}

# =======================================
sub _GETUsingLWP {
    my( $this, $url, @headers ) = @_;

    my ( $user, $pass );
    if( $url =~ s!([^/\@:]+)(?::([^/\@:]+))?@!! ) {
        ( $user, $pass ) = ( $1, $2 );
    }
    my $request;
    require HTTP::Request;
    $request = HTTP::Request->new( GET => $url );

    if( $TWiki::cfg{PROXY}{Username} && $TWiki::cfg{PROXY}{Password} ) {
        $request->proxy_authorization_basic( $TWiki::cfg{PROXY}{Username}, $TWiki::cfg{PROXY}{Password} );
    }

    '$Rev$'=~/([0-9]+)/;
    my $revstr=$1;
    my @allHeaders = ( 'User-Agent' => 'TWiki::Net/'.$revstr." libwww-perl/$LWP::VERSION" );
    push( @allHeaders, @headers ) if( @headers );
    $request->header( @allHeaders );
    require TWiki::Net::UserCredAgent;
    my $ua = new TWiki::Net::UserCredAgent( $user, $pass, $url );
    my $response = $ua->request( $request );
    return $response;
}

# pick a default mail handler
# =======================================
sub _installMailHandler {
    my $this = shift;
    my $handler = 0; # Not undef
    if ($this->{session} && $this->{session}->{prefs}) {
        my $prefs = $this->{session}->{prefs};
        $this->{MAIL_HOST}  = $prefs->getPreferencesValue( 'SMTPMAILHOST' );
        $this->{HELLO_HOST} = $prefs->getPreferencesValue( 'SMTPSENDERHOST' );
    }

    $this->{MAIL_HOST}  ||= $TWiki::cfg{SMTP}{MAILHOST};
    $this->{HELLO_HOST} ||= $TWiki::cfg{SMTP}{SENDERHOST};

    if( $this->{MAIL_HOST} ) {
        # See Codev.RegisterFailureInsecureDependencyCygwin for why
        # this must be untainted
        require TWiki::Sandbox;
        $this->{MAIL_HOST} = TWiki::Sandbox::untaintUnchecked( $this->{MAIL_HOST} );
        eval {   # May fail if Net::SMTP not installed
            require Net::SMTP;
        };
        if( $@ ) {
            $this->{session}->writeWarning( "SMTP not available: $@" )
              if ($this->{session});
        } else {
            $handler = \&_sendEmailByNetSMTP;
        }
    }

    if( !$handler && $TWiki::cfg{MailProgram} ) {
        $handler = \&_sendEmailBySendmail;
    }

    $this->setMailHandler( $handler ) if $handler;
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
    $this->{mailHandler} = $fnref;
}

=pod

---++ ObjectMethod sendEmail ( $text, $retries ) -> $error

   * =$text= - text of the mail, including MIME headers
   * =$retries= - number of times to retry the send (default 1)

Send an email specified as MIME format content.
Date: ...\nFrom: ...\nTo: ...\nCC: ...\nSubject: ...\n\nMailBody...

=cut

sub sendEmail {
    my( $this, $text, $retries ) = @_;
    $retries ||= 1;
   
    unless( $TWiki::cfg{EnableEmail} ) {
        return 'Trying to send email while email functionality is disabled';
    }

    unless( defined $this->{mailHandler} ) {
        _installMailHandler( $this );
    }

    return 'No mail handler available' unless( $this->{mailHandler} );

    # Put in a Date header, mainly for Qmail
    require TWiki::Time;
    my $dateStr = TWiki::Time::formatTime( time, '$email' );
    $text = "Date: " . $dateStr . "\n" . $text;

    my $errors = '';
    my $back_off = 1; # seconds, doubles on each retry
    while ( $retries-- ) {
        try {
            &{$this->{mailHandler}}( $this, $text );
            $retries = 0;
        } catch Error::Simple with {
            my $e = shift->stringify();
            $this->{session}->writeWarning( $e );
            # be nasty to errors that we didn't throw. They may be
            # caused by SMTP or perl, and give away info about the
            # install that we don't want to share.
	    $e = join( "\n", grep( /^ERROR/, split( /\n/, $e ) ) );

            unless( $e =~ /^ERROR/ ) {
                $e = "Mail could not be sent - see TWiki warning log.";
            }
            $errors .= $e."\n";
            sleep( $back_off );
            $back_off *= 2;
            $errors .= "Too many failures sending mail"
              unless $retries;
        };
    }
    return $errors;
}

# =======================================
sub _fixLineLength {
    my( $addrs ) = @_;
    # split up header lines that are too long
    $addrs =~ s/(.{60}[^,]*,\s*)/$1\n        /go;
    $addrs =~ s/\n\s*$//gos;
    return $addrs;
}

# =======================================
sub _slurpFile( $ ) {
    my $file = shift;

    unless( open( IN, '<', $file ) ) {
	( $<,$>) = ( $>,$<);
	die( "Failed to open $file: $!\n" );
    }
    my $text = do { local( $/ ); <IN> };

    unless( close IN ) {
	( $<,$>) = ( $>,$<);
	die( "Failed to close $file: $!\n" );
    }

    return $text;
}

# =======================================
sub _sendEmailBySendmail {
    my( $this, $text ) = @_;

    # send with sendmail
    my ( $header, $body ) = split( "\n\n", $text, 2 );
    $header =~ s/([\n\r])(From|To|CC|BCC)(\:\s*)([^\n\r]*)/$1.$2.$3._fixLineLength($4)/geois;
    $text = "$header\n\n$body";   # rebuild message

    if( $TWiki::cfg{SmimeCertificateFile} && $TWiki::cfg{SmimeKeyFile} ) {
	require Crypt::SMIME;

	my $smime = Crypt::SMIME->new();

	$smime->setPrivateKey( _slurpFile( $TWiki::cfg{SmimeKeyFile} ), _slurpFile( $TWiki::cfg{SmimeCertificateFile} ) );
	$text = $smime->sign( $text );
    }
    open( MAIL, '|'.$TWiki::cfg{MailProgram} ) ||
      die "ERROR: Can't send mail using TWiki::cfg{MailProgram}";
    print MAIL $text;
    close( MAIL );
    die "ERROR: Exit code $? from TWiki::cfg{MailProgram}" if $?;
}

# =======================================
sub _sendEmailByNetSMTP {
    my( $this, $text ) = @_;

    my $from = '';
    my @to = ();

    my ( $header, $body ) = split( "\n\n", $text, 2 );
    my @headerlines = split( /\r?\n/, $header );
    $header =~ s/\nBCC\:[^\n]*//os;  #remove BCC line from header
    $header =~ s/([\n\r])(From|To|CC|BCC)(\:\s*)([^\n\r]*)/$1 . $2 . $3 . _fixLineLength( $4 )/geois;
    $text = "$header\n\n$body";   # rebuild message

    # extract 'From:'
    my @arr = grep( /^From: /i, @headerlines );
    if( scalar( @arr ) ) {
        $from = $arr[0];
        $from =~ s/^From:\s*//io;
        $from =~ s/.*<(.*?)>.*/$1/o; # extract "user@host" out of "Name <user@host>"
    }
    unless( $from ) {
        # SMELL: should be a TWiki::inlineAlert
        die "ERROR: Can't send mail, missing 'From:'";
    }

    # extract @to from 'To:', 'CC:', 'BCC:'
    @arr = grep( /^To: /i, @headerlines );
    my $tmp = '';
    if( scalar( @arr ) ) {
        $tmp = $arr[0];
        $tmp =~ s/^To:\s*//io;
        @arr = split( /,\s*/, $tmp );
        push( @to, @arr );
    }
    @arr = grep( /^CC: /i, @headerlines );
    if( scalar( @arr ) ) {
        $tmp = $arr[0];
        $tmp =~ s/^CC:\s*//io;
        @arr = split( /,\s*/, $tmp );
        push( @to, @arr );
    }
    @arr = grep( /^BCC: /i, @headerlines );
    if( scalar( @arr ) ) {
        $tmp = $arr[0];
        $tmp =~ s/^BCC:\s*//io;
        @arr = split( /,\s*/, $tmp );
        push( @to, @arr );
    }
    if( ! ( scalar( @to ) ) ) {
        # SMELL: should be a TWiki::inlineAlert
        die "ERROR: Can't send mail, missing recipient";
    }

    return undef unless( scalar @to );

    # Change SMTP protocol recipient format from 
    # "User Name <userid@domain>" to "userid@domain"
    # for those SMTP hosts that need it just that way.
    foreach (@to) {
        s/^.*<(.*)>$/$1/;
    }

    my $smtp = 0;
    if( $this->{HELLO_HOST} ) {
        $smtp = Net::SMTP->new( $this->{MAIL_HOST},
                                Hello => $this->{HELLO_HOST},
                                Debug => $TWiki::cfg{SMTP}{Debug} || 0 );
    } else {
        $smtp = Net::SMTP->new( $this->{MAIL_HOST},
                                Debug => $TWiki::cfg{SMTP}{Debug} || 0 );
    }
    my $status = '';
    my $mess = "ERROR: Can't send mail using Net::SMTP. ";
    die $mess."Can't connect to '$this->{MAIL_HOST}'" unless $smtp;

    if( $TWiki::cfg{SMTP}{Username} ) {
        $smtp->auth($TWiki::cfg{SMTP}{Username}, $TWiki::cfg{SMTP}{Password});
    }
    $smtp->mail( $from ) || die $mess.$smtp->message;
    $smtp->to( @to, { SkipBad => 1 } ) || die $mess.$smtp->message;
    $smtp->data( $text ) || die $mess.$smtp->message;
    $smtp->dataend() || die $mess.$smtp->message;
    $smtp->quit();
}

1;
