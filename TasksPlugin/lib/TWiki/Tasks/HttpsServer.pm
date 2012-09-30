# -*- mode: CPerl; -*-
# TWiki off-line task management framework addon for the TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2011 Timothe Litt <litt at acm dot org>
# License is at end of module.
# Removal of Copyright and/or License prohibited.


use strict;
use warnings;

# Note that this file also contains the HttpsCx package

=pod

---+ package TWiki::Tasks::HttpsServer
HTTPS server object.

This class specializes a HttpServer to provide SSL.  It should be further subclassed by the http application.

See HttpServer for documentation of the methods inherited from it.

The server handles connection setup, authentication and provides headers, an error page, and a default data sink.

See all the caveats in HttpServer.

=cut

package TWiki::Tasks::HttpsServer;

use base qw/TWiki::Tasks::HttpServer/;

use TWiki::Tasks::Logging;
use TWiki::Tasks::Schedule qw/schedulerRegisterFds/;

#use IO::Socket::INET;
use IO::Socket::IP;
use IO::Socket::SSL; # ( qw/debug3/ ); # debug3 should suffice, debug4 prints everything, including data


=pod

---++ ClassMethod new( @parlist ) -> $serverRef
Constructor for a new HttpsServer object

Subclass of GenericServer::new, which documents the parameters.

Returns server object.

=cut

sub new {
    my $class = shift;

    my $self = $class->SUPER::new( @_ );

    #?? Setup connection cache? - Given that we always close, is this worthwhile?  "No" for now.

    # I don't know how to support preserving an SSL connection across a restart.

    $self->{svc}{preserve} = 0;

    # Set protocol name for status

    $self->{pname} = "https ($TWiki::cfg{Tasks}{StatusServerSslVersion})";
    return $self;
}


=pod
---++ ObjectMethod preserve( $ccx )
Support routine for preserving connections across daemon restart
   * =$ccx= - connection object that commanded restart

This server can't preserve connections. SSL makes that infeasible.

=cut

sub preserve {
    my $self = shift;

    return $self->neverPreserve( @_ );
}


=pod

---++ ObjectMethod accept( $sock, $restarting, $initiator, $textformat ) -> $cx
Accept a new connection to this server.

Subclass of GenericServer::accept, which documents the parameters.

Creates an Https connection object, and starts SSL negotiation with the client.

Returns connection object, or undef if negotiation couldn't even start.

=cut

sub accept {
    my( $self, $sock, $restarting ) = @_;

    my $cx = TWiki::Tasks::HttpsCx->new( $self, $sock );

    $! = 0;
    # start_SSL returns the same socket, with upgrade to SSL started.  Handshake is done asynchronously in ssl_accept.

    my @sslConfig = ( SSL_server => 1, SSL_startHandshake => 0,
                      SSL_cert_file => $TWiki::cfg{Tasks}{StatusServerCertificate},
                      SSL_key_file => $TWiki::cfg{Tasks}{StatusServerKey},
                      SSL_passwd_cb => sub { return $TWiki::cfg{Tasks}{StatusServerKeyPassword}; },
                      SSL_version => $TWiki::cfg{Tasks}{StatusServerSslVersion},
                      SSL_cipher_list => $TWiki::cfg{Tasks}{StatusServerCiphers},
                    );

    # Enable client certificate verification if configured

    if( $TWiki::cfg{Tasks}{StatusServerVerifyClient} ) {
        push @sslConfig, ( SSL_verify_mode => SSL_VERIFY_PEER | SSL_VERIFY_FAIL_IF_NO_PEER_CERT, );
        if( $TWiki::cfg{Tasks}{StatusServerCAFile} ) {
            push @sslConfig, ( SSL_ca_file => $TWiki::cfg{Tasks}{StatusServerCAFile} );
        } elsif( $TWiki::cfg{Tasks}{StatusServerCAPath} ) {
            push @sslConfig, ( SSL_ca_path => $TWiki::cfg{Tasks}{StatusServerCAPath} );
        } else {
            # Misconfigured - reported in configure's checker.
            return undef;
        }
        if( $TWiki::cfg{Tasks}{StatusServerCheckCRL} ) {
            push @sslConfig, ( SSL_check_crl => 1 );
            if( $TWiki::cfg{Tasks}{StatusServerCrlFile} ) {
                push @sslConfig, ( SSL_crl_file =>  $TWiki::cfg{Tasks}{StatusServerCrlFile} )
            } elsif( !$TWiki::cfg{Tasks}{StatusServerCAPath} ) {
                 # Misconfigured - reported in configure's checker.
                return undef;
            }
        }
    }

    unless( IO::Socket::SSL->start_SSL( $sock, @sslConfig ) ) {
        logMsg( ERROR, "$self->{svc}{name}: Unable to start SSL connection: $SSL_ERROR\n" );
        return undef;
    }

    $sock->blocking( 0 );

    $cx->ssl_accept;

    return $cx;
}

# ##################################################################################################################################
# ##################################################################################################################################
# ##################################################################################################################################

=pod

---+ package TWiki::Tasks::HttpsCx
HTTPS connection object.

This class specializes a HttpCx to provide SSL.

See HttpCx for documentation of the methods inherited from it.

HTTPS communicates bidirectionally underneath the application protocol to negotiate connection parameters, session keys, etc.
As result, the select thread model is complicated in that the protocol may need to read when the application wants to write,
and vice-versa.  IO::Socket::SSL exposes this by returing SSL_WANT_READ and SSL_WANT_WRITE in $SSL_ERROR.  It also is supposed
to set $! to EAGAIN - but this isn't quite as reliable in non-blocking mode as we'd like.

See all the caveats in HttpCx.

=cut

package TWiki::Tasks::HttpsCx;

our @ISA = qw/TWiki::Tasks::HttpCx/;

require TWiki::Tasks::HttpCx;
use TWiki::Tasks::Logging;
use TWiki::Tasks::Schedule qw/schedulerRegisterFds/;

use Errno qw(EAGAIN);
use Fcntl qw/F_GETFD F_SETFD FD_CLOEXEC/;
use IO::Socket::SSL;

=pod

---++ ObjectMethod ssl_accept()
Negotiates ssl connection with client

Called initially on connect to start SSL negotiations, then as a read or write select thread callback until negotiations end.

IO::Socket::SSL expects a half-duplex communications pattern with explicit turn-arounds.  So, that's what we do.  This is
effectively a connection state, in which the application doesn't (yet) have access to the connection.

No user data is transferred during negotiations.

When negotiations succeed, the standard (SSL) select read (and possibly write) callback is established.

=cut

sub ssl_accept {
    my $self = shift;

    my $sock = $self->{sock};
    my $fd = $self->{fd};

    # See if negotiations are complete

    $! = 0;
    if( $sock->accept_SSL ) {
        # If verified client certificate, check for issuer and/or subject constraints
        if( $TWiki::cfg{Tasks}{StatusServerVerifyClient} ) {
            if( my $ire = $TWiki::cfg{Tasks}{StatusServerClientIssuer} ) {
                my $issuer = $sock->peer_certificate('issuer');
                unless( $issuer && $issuer =~ $ire ) {
                    logMsg( DEBUG, "Rejected SSL connection: issuer mismatch on $issuer\n" );
                    return $self->errorClose;
                }
            }
            if( my $sre = $TWiki::cfg{Tasks}{StatusServerClientSubject} ) {
                my $subject = $sock->peer_certificate('subject');
                unless( $subject && $subject =~ $sre ) {
                    logMsg( DEBUG, "Rejected SSL connection: subject mismatch on $subject\n" );
                    return $self->errorClose;
                }
            }
            logFmt(  DEBUG, "Accepted SSL connection using %s from \"%s\"\@%s",
                     $sock->get_cipher, ($self->{remuser} = $sock->peer_certificate('cn') || '??'), $self->peerhost );
        } else {
            logFmt( DEBUG, "Accepted SSL connection using %s from %s", $sock->get_cipher, $self->peerhost );
        }

        # Switch to application state by registering the application callbacks

        schedulerRegisterFds( $fd, 'r-w', sub { $self->readConn; } );

        $self->{rreg} = 1;
        $self->{wreg} = 0;
        $self->writeConn;
        return;
    }

    # $! is supposed to contain EAGAIN if SSL reads/writes need to be posted.  However, it seems to return random
    # errors in non-blocking mode.  So we check $SSL_ERROR unconditionally, and look for the unexpected last.

#    if( $! != EAGAIN ) {
#        my $server = $self->server or return $self->close(0);
#        logMsg( WARN, $server->name, ": SSL negotiation with ", $self->peerhost, " failed: $!|$SSL_ERROR\n" );
#        return $self->close(0);
#    }

    # If SSL needs a read, register for a read callback

    if( $SSL_ERROR == SSL_WANT_READ ) {
        schedulerRegisterFds( $fd, 'r-w', sub { $self->ssl_accept; } );
        $self->{rreg} = 1;
        $self->{wreg} = 0;
        return;
    }

    # If SSL needs a write, register for a write callback.

    if( $SSL_ERROR == SSL_WANT_WRITE ) {
        schedulerRegisterFds( $fd, '-rw', sub { $self->ssl_accept; } );
        $self->{rreg} = 0;
        $self->{wreg} = 1;
        return;
    }

    # Something else went wrong

    my $server = $self->server or return $self->close(0);

    # Suppress noisy message that usually indicates HTTP connect to an SSL port
    logMsg( WARN, $server->name, ": SSL negotiation with ", $self->peerhost, " failed",
            ($SSL_ERROR =~ /SSL routines:SSL3_GET_RECORD:wrong version number$/)? "\n" : ": $! $SSL_ERROR\n" );
    return $self->errorClose;
}

=pod

---++ ObjectMethod readConn( $fd, $event )
Select callback for read data ready on this connection
   * =$fd= - fd number of socket
   * =$event= - event code ('r')

Handle socket IO, including SSL read/write multiplexing.  Deliver data to readData.

=cut

sub readConn {
    my( $self, $fd, $event ) = @_;

    my $sock = $self->{sock};

    # Read new data chunk and append to buffer

    $! = 0;
    my $rn = $sock->sysread( $self ->{rbuf}, 1000, length $self->{rbuf} );

    unless( $rn ) {
        # No data read

	schedulerRegisterFds( $fd, '-r-w', undef );
	$self->{rreg} = 0;
	$self->{wreg} = 0;

	if( defined $rn ) {
            $self->{error} .= "End of file\n";
	    return; # EOF
	}

        # Not EOF, check for fatal error

        unless( $! == EAGAIN ) {
            # Error
            $self->{error} .= "Read error: $! $SSL_ERROR\n";
            $self->errorClose;
            return;
        }

        # Should be SSL multiplexing

        if( $SSL_ERROR == SSL_WANT_WRITE ) {
            schedulerRegisterFds( $fd, 'w', sub { $self->readConn } );
            $self->{wreg} = 1;
            return;
        } elsif( $SSL_ERROR == SSL_WANT_READ ) {
            schedulerRegisterFds( $fd, 'r', sub { $self->readConn } );
            $self->{rreg} = 1;
            return;
        }

        # Some other SSL error
        $self->errorClose;
        return;
    }

    # Deliver application data

    unless( $self->readData ) {
        $self->close(0);
    }

    # Start any application write since multiplexing may have deregistered normal write thread.

    $self->writeConn;
    return;
}

=pod

---++ ObjectMethod writeConn()
Select callback for write ready on this connection
   * =$fd= - fd number of socket
   * =$event= - event code ('w')

Write as much data as possible to the socket.  If any data remains in the buffer, wait for next select write ready callback.

Handles SSL read/write multiplexing, otherwise identical to the base routine.

If write is complete, handle any pending close/exit

=cut

sub writeConn {
    my $self = shift;

    my $sock = $self->{sock};

    # If data is in buffer, attempt to send it

    if( length $self->{wbuf} ) {
        $! = 0;
	my $written = $sock->syswrite( $self->{wbuf} );
	if( defined $written ) {
            # Wrote something, remove from buffer

	    $self->{wbuf} = substr( $self->{wbuf}, $written );
	}  elsif( $! == EAGAIN ) {
            if( $SSL_ERROR == SSL_WANT_READ ) {
                # SSL layer needs a read before write can proceed

                schedulerRegisterFds( $self->{fd}, 'r-w', sub { $self->writeConn; } );
                $self->{rreg} = 1;
                $self->{wreg} = 0;
                return;
            } else {
                # SSL layer needs an internal write ready before user write can proceed.

                schedulerRegisterFds( $self->{fd}, '-rw', sub { $self->writeConn; } );
                $self->{rreg} = 0;
                $self->{wreg} = 1;
                return;
            }
        } else {
            # Some other error, force close
	    $self->{error} = $!;
	    $self->{wbuf} = '';
	    $self->{wend} = 1;
	}
    }

    # If data remains to be written, wait for next write ready

    if( length $self->{wbuf} ) {
        unless( $self->{wreg} ) {
            schedulerRegisterFds( $self->{fd}, 'w', sub { $self->writeConn; } );
           $self->{wreg} = 1;
        }
	return;
    }

    # No data left to write

    if( $self->{wend} ) {
        # Queued close

        $self->lastWrite;
    } else {
        # End of current data, de-register write ready callback & make sure we have a read open

        schedulerRegisterFds( $self->{fd}, 'r-w', sub { $self->readConn; } );
        $self->{rreg} = 1;
        $self->{wreg} = 0;
    }

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
