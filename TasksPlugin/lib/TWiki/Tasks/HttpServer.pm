# -*- mode: CPerl; -*-
# TWiki off-line task management framework addon for the TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2011 Timothe Litt <litt at acm dot org>
# License is at end of module.
# Removal of Copyright and/or License prohibited.


use strict;
use warnings;


=pod

---+ package TWiki::Tasks::HttpServer
HTTP server object.

This class specializes a GenericServer to provide a minimal HTTP server.  It should be further subclassed by
the http application.

See GenericServer for documentation of the methods inherited from it.

The server handles connection setup, authentication and provides headers, an error page, and a default data sink.

Caution: Don't call CGI:: or TWiki:: functions that use a CGI object.  This is a LIMITED environment, not a full webserver.  In
particular, request %ENVs aren't setup (we're request-threaded) and IO in CGI blocks and CGI::Q is not context-switched and...

The embedded webserver is only enough to manage the task framework. It's necessary beause the framework does not run under
a full webserver, which is its entire reason for being.  If you think you need additional functions, don't re-invent Apache
here - run your GUI under apache and communicate with files, or a simple network server (see the DebugServer for an example of
how to code the latter).

We strongly recommend that this server be configured to listen only on localhost ports, as strong security is not provided.

Most of the work is handled by the connection module, HttpCx.

=cut

package TWiki::Tasks::HttpServer;


use base qw/TWiki::Tasks::GenericServer/;

use TWiki::Tasks::Globals qw/:httpsrv/;

use Digest::MD5 qw/md5_hex/;
use HTTP::Status qw/:constants/;
use MIME::Base64 qw//;
use Sys::Hostname;

=pod

---++ ClassMethod new( @parlist ) -> $serverRef
Constructor for a new HttpServer object

Subclass of GenericServer::new, which documents the parameters.

Returns server object.

=cut

sub new {
    my $class = shift;

    my $self = $class->SUPER::new( @_ );

    $self->{pname} = 'http';
    $self->{CookieJar} = {};
    return $self;
}

=pod

---++ ObjectMethod accept( $sock, $restarting, $initiator, $textformat ) -> $cx
Accept a new connection to this server.

Subclass of GenericServer::accept, which documents the parameters.

Returns connection object.

=cut

sub accept {
    my( $self, $sock ) = @_;

    require TWiki::Tasks::HttpCx;
    return TWiki::Tasks::HttpCx->new( $self, $sock );
}

=pod

---++ ObjectMethod authenticate( $cx, $info ) -> $status
Authenticates a connection
   * =$cx= - connection object
   * =$info= - (Optional) connection request information object

=$info= provides protocol, method, uri, query & fulluri if it's necessary to discriminate.

Two authentication methods are supported:
   * Standard Basic Authentication for humans, which requires plaintext password.
   * Digest-style authentication, which allows scripts to send a digest of the crypt'd password.  This prevents sending the crypt'd password unencrypted.

The Basic Authentication follows the HTTP standard, and should be compatible with any web browser.  It has the drawback of
transmitting plaintext passwords (until/unless https is implemented).  For this reason, the server should be configured to
run only on =localhost=.  Note that Tasks::CGI provides the ability to have a relatively secure proxy for remote management.

The Digest-style authentication provided here should not be confused with the HTTP DIGEST authentication scheme.  What's done
here is greatly simplified and is not compatible with any known web browser.

This method should be subclassed (at least) so info->{users} can be provided.

Returns true if request authenticates; false if not (and a new challenge has been issued)

=cut

sub authenticate {
    my $self = shift;
    my $cx = shift;
    my $info = shift() || $cx->reqinfo();

    my $now = time;

    unless( exists $self->{secret} ) {
	my $secret= '';
	for( my $i = 0; $i < 20; $i++ ) {
	    $secret .= chr(int rand( 256 ));
	}
	$self->{secret} = $secret;
	$self->{noncectr} = $now;
    }

    foreach my $nonce (keys %{$self->{nonces}}) {
	delete $self->{nonces}{$nonce} if( $now > $self->{nonces}{$nonce} );
    }

    my $realm = $info->{realm} || "Webserver\@" . hostname;

    my $auth = $cx->reqheader( 'authorization' );
    if( defined $auth ) {
	my $type;
	( $type, $auth ) = $auth =~ m/^(\S+)\s+(.*)$/;
 	return eval { # Trap invalid encodings
	    return 0 unless( $type && $type =~ /^Basic$/i && defined $auth );
	    $auth = MIME::Base64::decode_base64( $auth );
	    my( $user, $pass ) = $auth =~ /^([^:]*):(.*)$/;
	    $user = '' unless( defined $user );
	    $pass = '' unless( defined $pass );

	    $auth = $cx->reqheader( 'X-TWiki-Authenticator' );
	    if( defined $auth ) {
		# Internal request - validate nonce
		return 0 unless( exists $self->{nonces}{$auth} &&
				 $now <= $self->{nonces}{$auth} );

		if( exists $info->{users}{$user} &&
                    Digest::MD5::md5_hex( $auth, "$realm:$user:$info->{users}{$user}" ) eq $pass ) {
                    if( $cx->{remuser} ) {
                        $cx->{remuser} .= " as $user";
                    } else {
                        $cx->{remuser} = $user;
                    }
                    return 1;
                }
                return 0;
	    }
	    # Standard user request, validate supplied user/password
	    if ( exists $info->{users}{$user} &&
                 crypt($pass, ($info->{users}{$user} || '')) eq ($info->{users}{$user} || '') ) {
                if( $cx->{remuser} ) {
                    $cx->{remuser} .= " as $user";
                } else {
                    $cx->{remuser} = $user;
                }
                return 1;
            }
            return 0;
	};
    }

    # No authorization, issue a new challenge including an internal challenge.
    #
    # A digest-like scheme is used to allow internal requests to safely use the crypted configure password to authenticate.
    # HTTP Digest is too much work for the threat.

    my $nonce = Digest::MD5::md5_hex( $self->{secret}, ++$self->{noncectr}, $realm );
    $self->{nonces}{$nonce} = $now + ($debug? 600 : 30);

    my $RC = HTTP_UNAUTHORIZED;

    $cx->rspheader( Status => "$RC Authorization Required",
		    WWW_Authenticate => "Basic realm=\"$realm\"",
		    X_TWiki_Authenticator => "$realm,$nonce",
		  );

    $self->htmlHeader( $cx, title => 'Authorizaton Required' );
    $cx->print( "<H1>401 Unauthorized.</H1>" );
    $self->htmlEnd( $cx );

    $cx->send();

    return 0;
}

=pod

---++ ObjectMethod receive( $cx, $method )
HTTP request dispatch
   * =$cx= - Connection object
   * =$method= - Method from request

Receives a parsed http message (in the connection object) and generates a response.

Subclasses validate request method and dispatch.

This default routine provides an error page for unsupported methods.

=cut

sub receive {
    my( $self, $cx, $method ) = @_;

    # Instance doesn't understand method

    return $self->Error( $cx, HTTP_NOT_IMPLEMENTED, "$method not implemented" );
}


=pod

---++ ObjectMethod htmlHeader( $cx, @headerTags )
Generates and buffers an HTTP/HTML response header for an HTTP response
   * =$cx= - Connection object
   * =@headerTags= - list of ( tagname, value ) elements to be inserted in <HEAD>.  'tagname' does *not* include <>s.

Writes a standard html header to the connection, including the HTTP Content-Type, the DOCTYPE, <HTML>, <HEAD> and opening <BODY>
tags.

=cut

sub htmlHeader {
    my $self = shift;
    my $cx = shift;

    $cx->print( <<"EOM" );
Content-Type: text/html

<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
 "http://www.w3.org/TR/1999/REC-html401-19991224/loose.dtd">
<HTML>
  <HEAD>
    <META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=ISO-8859-1">
EOM
    while( @_ ) {
	my $tag = shift;
	my $value = shift;

	$cx->print( "    <$tag>$value</$tag>\n" );
    }
    $cx->print( <<"EOM" );
  </HEAD>
  <BODY>
EOM
}

=pod

---++ ObjectMethod htmlEnd( $cx )
Generates and buffers the closing tags for an HTML response
   * =$cx= - Connection object

Closes an HTTP/HTML response with the closing </BODY> and </HTML> tags.

=cut

sub htmlEnd {
    my $self = shift;
    my $cx = shift;

    $cx->print( <<"EOM" );
</BODY>
</HTML>
EOM
}

=pod

---++ ObjectMethod htmlEnd( $cx, $errnum, $errtxt, @paras )
Generates and buffers an HTML error page for an HTML response
   * =$cx= - Connection object
   * =$errnum= - HTTP status code for error page
   * =$errtxt= - Text for HTTP status line
   * =@paras= - Paragraphs of text for error page body

Discards any partial response that's already buffered and replaces it with an HTML error page.
Sends the response.

=cut

sub Error {
    my( $self, $cx, $errnum, $errtxt ) = @_;

    $cx->cancelRsp();

    $cx->rspheader( Status => "$errnum $errtxt", );

    $self->htmlHeader( $cx, title => "Error: $errtxt" );
    $cx->print( "<h1>Error $errnum: $errtxt</h1>" );

    $cx->print( join( "<p>",  @_[4..$#_] ) ) if( @_[4..$#_] );
    $self->htmlEnd( $cx );

    $cx->send();

    return;
}

1;

__END__

This is an original work by Timothe Litt.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 3
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details, published at
http://www.gnu.org/copyleft/gpl.html
