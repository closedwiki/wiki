# -*- mode: CPerl; -*-
# TWiki off-line task management framework addon for the TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2011 Timothe Litt <litt at acm dot org>
# License is at end of module.
# Removal of Copyright and/or License prohibited.


use strict;
use warnings;

=pod

---+ package TWiki::Tasks::GenericServer
Asynchronous network service base class

Creates and runs a select-threaded server for any purpose
  Listens on the specified address:port and creates
  TWiki::Tasks::GenericCx objects for each connection.

  Registers each client connection for status and cleanup.

Subclass with a protocol-specific class.

=cut

package TWiki::Tasks::GenericServer;

use IO::Socket::IP;

use TWiki::Tasks::Globals qw/:gserver/;
use TWiki::Tasks::Schedule qw/schedulerRegisterFds/;
use TWiki::Tasks::Logging;

=pod

---++ ClassMethod new( @parlist ) -> $serverRef
Constructor for a new GenericServer object
   * =@parList= - First element can be a hash reference, remainder are parameter => value pairs

Parameters:
   * =LocalAddr= - interface address:port to listen to (IO::Socket:IP)
   * =onlypeer= - qr// (optional) expression that peer must match to connect
   * =name= - server name string
   * =number= - server id number
   * =preserve= - true if connections are preserved across restart

Returns new server object.  Check for errors with $obj->error()

=cut

sub new {
    my $class = shift;
    my $service = ref( $_[0] ) eq "HASH"? { %{$_[0]}, @_[1..$#_] } : { @_ };

    my $self = {
		svc => $service,
                pname => 'generic',
	       };

    bless( $self, $class );

    $service->{LocalAddr} ||= 'localhost:80';

    if( my $lsock = $self->newListeningSocket ) {
	my $lfd = fileno($lsock);
	$self->{lfd} = $lfd;
	$parentFds{$lfd} = $lsock;
	schedulerRegisterFds( $lfd, 'r', sub { $self->_newConn( @_ ); } );
    } else {
	$self->{error} = "Unable to open $service->{LocalAddr}: $!";
    }

    return $self;
}

=pod

---++ ObjectMethod newListeningSocket() -> $socket
Obtains a new listening (server) socket

Obtains a new listening, non-blocking stream socket.

This default routine produces an IPV4 TCP socket, but servers can subclass to provide other protocols
such as IPV6 or DECnet.

Returns socket (or undef).

=cut

sub newListeningSocket {
    my $self = shift;

    #require IO::Socket::INET;
    require IO::Socket::IP;
    IO::Socket::IP->import;

    my $sock;
    $self->{lsock} = $sock = IO::Socket::IP->new(
                                                 LocalAddr => $self->{svc}->{LocalAddr},
                                                 Proto => 'tcp',
                                                 Type => SOCK_STREAM(),
                                                 Listen => 5,
                                                 ReuseAddr => 1,
                                                 Blocking => 0,
                                                );
    return $sock;
}

# ---++ ObjectMethod _newConn( $fd, $m )
# Select callback for read event on listening socket
#   * =$fd= - listening socket's fd
#   * =$m= - event ID (must be 'r' because of registration)
#
# Accept connection, validate peer, register connection object

sub _newConn {
    my( $self, $fd, $m ) = @_;

    my $sock = $self->{lsock}->accept();
    unless( $sock ) {
        logMsg( WARN, "$self->{name}: accept() failed: $!\n" );
        return;
    }
    $parentFds{fileno($sock)} = $sock;

    $self->connect( $sock );
}

=pod

---++ ObjectMethod connect( $sock, $restarting, $initiator, $textformat ) -> $cx
Associate a new connection's socket with this server.
   * =$sock= - socket
   * =$restarting= - true if connection is being resumed due to a daemon restart
   * =$initiator= - true if this connection initiated the restart
   * =$textformat= - true if connection is in text mode (default is html)

Connection may be new (from listening socket) or resumed (from a previous instance of the daemon).

Returns connection object or undef if connection failed.

=cut

sub connect {
    my $self = shift;
    my( $sock, $restarting, $initiator ) = @_;

    my $cfd = fileno( $sock );
    $parentFds{$cfd} = $sock;

    delete $self->{clients}{$cfd};

    # Paranoia: Check peer restriction if specified

    my $peer = $sock->peerhost();
    if( $self->{svc}{onlypeer} && $peer !~ $self->{svc}{onlypeer} ) {
	delete $parentFds{$cfd};
	$sock->close();
	logMsg( WARN, "Rejected unauthorized connection from $peer" );
	return;
    }

    $sock->blocking( 0 );

    my $cx = $self->accept( @_ );
    unless( $cx ) {
        schedulerRegisterFds( $cfd, '-', undef );
	delete $parentFds{$cfd};
	$sock->close();
        return undef;
    }

    $self->{clients}{$cfd} = $cx;

    return $cx;
}

=pod

---++ ObjectMethod accept( $sock, $restarting, $initiator, $textformat ) -> $cx
Accept a new connection to this server.
   * =$sock= - socket
   * =$restarting= - true if connection is being resumed due to a daemon restart
   * =$initiator= - true if this connection initiated the restart
   * =$textformat= - true if connection is in text mode (default is html)

Connection may be new (from listening socket) or resumed (from a previous instance of the daemon).

Returns connection object.

=cut

sub accept {
    my $self = shift;
    my( $sock, $restarting, $initiator ) = @_;

    require TWiki::Tasks::GenericCx;
    return TWiki::Tasks::GenericCx::new( $self, @_ );
}

=pod

---++ ObjectMethod cxClosed( $cx )
Called when a connection closes

Remove connection from the active connection database.

=cut

sub cxClosed {
    my $self = shift;
    my $cx = shift;

    delete $self->{clients}{$cx->fd};
}

=pod

---++ ObjectMethod error() -> $string
Accessor for the error string.

=cut

sub error {
    my $self = shift;

    return $self->{error};
}

=pod

---++ ObjectMethod name() -> $string
Accessor for the server name

=cut

sub name {
    my $self = shift;

    return $self->{svc}{name};
}

=pod

---++ ObjectMethod number() -> $index
Accessor for the server number

=cut

sub number {
    my $self = shift;

    return $self->{svc}{number};
}

# ---++ ObjectMethod preserve( $ccx )
# Support routine for preserving connections across daemon restart
#   * =$ccx= - connection object that commanded restart
#
# In scalar context, returns true if this connection is to be preserved
#
# In array context, returns list of file descriptors of connections that are to be preserved.  Commanding connection's fd is
# is guaranteed to be first.
#
# neverPreserve can be called from a derived class if that class can't preserve ANY connections - e.g. because there's
# too much connection state for it to be feasible.  Note that 
#
# Not for general use.

sub neverPreserve {
    my( $self, $ccx ) = @_;

    # Use caller's caller's context - this should only be called from a subclass's own preserve().

    my $wantarray =  (caller(1))[5];

    return 0 unless( $wantarray );

    $self->{restartcx} = $ccx;

    return ();
}

sub preserve {
    my $self = shift;
    my $ccx = shift; # Commanding connection

    unless( wantarray ) {
	# Return true if specified cx is to be preserved
	return( defined($self->{restartcx}) && $ccx == $self->{restartcx} ||
		$self->{svc}{preserve} );
    }
    $self->{restartcx} = $ccx;

    my @list;
    foreach my $fd ( keys %{$self->{clients} } ) {
	my $cx = $self->{clients}{$fd};
	if( $cx == $ccx ) {
	    unshift @list, $fd;
	} elsif( $self->{svc}{preserve} ) {
	    push @list, $fd;
	    $cx->close(2);
	}
    }
    return @list
}

=pod

---++ ObjectMethod status( $textformat ) -> $text
Generate server status string for display.
   * =$textformat= - true for text format, false for html

Generates status report for this server, calling each connection for its contribution.

Returns status text.

=cut

sub status {
    my $self = shift;
    my $txtformat = shift;

    my $msg = '';
    my @colwids;
    if( $txtformat ) {
	foreach my $cfd (keys %{$self->{clients}}) {
	    my $client = $self->{clients}{$cfd};
	    $msg .= $client->status( $txtformat, !length $msg, \@colwids, 1 );
	}
    }
    foreach my $cfd (sort keys %{$self->{clients}}) {
	my $client = $self->{clients}{$cfd};
	$msg .= $client->status( $txtformat, !length $msg, \@colwids, 0 );
    }
    if( $msg ) {
	$msg .= '</table>' unless( $txtformat );
    } else {
	if( $txtformat ) {
	    $msg = "  No active clients\n";
	} else {
	    $msg .= "<p>No active clients";
	}
    }

    my $v6tag = ($self->{lsock}->sockdomain == PF_INET6)? ' over IPV6' : '';


    if( $txtformat ) {
	return "\n$self->{svc}{name} is running $self->{pname} on $self->{svc}{LocalAddr}$v6tag\n$msg";
    } else {
	return "\n<h2>$self->{svc}{name} is running $self->{pname} on $self->{svc}{LocalAddr}$v6tag</h2>\n$msg";
    }
}

=pod

---++ ObjectMethod close( $type ) -> $busy
Shutdown server, closing active connections.
   * =$type= - 0 normal, poll; 1 = hard, stop; 2 = exec, restart

Shutdown may not be instantaneous since connections may have pending write data (waiting for network buffers).
May be called multiple times to determine when close is complete.

Returns true if any connection is busy, false when close is complete.

=cut

sub close {
    my $self = shift;
    my $type = shift;

    if( my $lsock = $self->{lsock} ) {
	my $lfd = $self->{lfd};
	schedulerRegisterFds( $lfd, '-', undef );
	delete $parentFds{$lfd};
	close $lsock;
	delete $self->{lsock};
    }
    my $busy = 0;
    foreach my $fd (keys %{$self->{clients}}) {
	my $cx = $self->{clients}{$fd};
	if( defined $cx ) {
	    if( $cx->close( 0 ) ) {
		$busy = 1;
	    } else {
		delete $self->{clients}{$fd} unless( $type == 2 && $self->preserve( $cx ) );
	    }
	}
    }

    return $busy;
}

=pod

---++ ObjectMethod DESTROY()
Destructor

=cut

sub DESTROY {
    my $self = shift;

    if( $forkedTask ) {
	delete $self->{clients};
	return;
    }

    # ** Wait for close?  Would need a select loop - in DESTROY?
    $self->close( 0 );
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
