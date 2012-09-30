# -*- mode: CPerl; -*-
# TWiki off-line task management framework addon for the TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2011 Timothe Litt <litt at acm dot org>
# License is at end of module.
# Removal of Copyright and/or License prohibited.


use strict;
use warnings;


=pod

---+ package TWiki::Tasks::GenericCx
Generic select-threaded connection object

Each GenericCx object represents a network connection to a select-threaded server.

This object:
   * Provides async read and write buffering
   * Registers and manages select callbacks
   * Calls registered reader for each line (or data chunk in binmode) read.
   * If requested, closes connection and/or exits after last write is completed.
   * Provides connection status text for the status server

Typically this object is subclassed to layer a protocol on the connection, and the protocol is further subclassed by the
application.

=cut

package TWiki::Tasks::GenericCx;

use TWiki::Tasks::Globals qw/:gcx/;
use TWiki::Tasks::Logging;
use TWiki::Tasks::StatusServer qw/_max/;
use TWiki::Tasks::Schedule qw/schedulerRegisterFds/;

use Fcntl qw/F_GETFD F_SETFD FD_CLOEXEC/;
use Scalar::Util qw/weaken/;
use Socket qw/:crlf :addrinfo/;
use IO::Socket::IP;

=pod

---++ ClassMethod new( $server, $socket )
Constructor for a new GenericCx object
   * =$server= - Server object that owns this connection
   * =$socket= - Network socket (from accept())

Constructs a new object and registers it for input callbacks.

=cut

sub new {
    my( $class, $server, $sock ) = @_;

    my $fd = $sock->can('fileno')? $sock->fileno() : fileno( $sock );

    my $self = {
		server => $server,
		sock => $sock,
		fd => $fd,
		started => time,
		ctx => {},         # Private per-cx context for protocol subclass
		rbuf => '',
		wbuf => '',
		wexit => 0,
		error => '',
                remuser => '',
	       };
    weaken( $self->{server} );

    bless( $self, $class );

    # Enable callbacks for read and exception

    schedulerRegisterFds( $fd, 'r', sub { $self->readConn( @_ ); } );
    schedulerRegisterFds( $fd, 'e', sub { $self->exceptConn( @_ ); } );
    @$self{'ereg','rreg'} = ( 1, 1 );

    return $self;
}

=pod

---++ ObjectMethod fd() -> $fd
Accessor for file descriptor number of connection

Returns fd

=cut

sub fd {
    my $self = shift;

    return $self->{fd};
}

=pod

---++ ObjectMethod server() -> $serverRef
Obtain server object that owns connection

Returns reference to server object

=cut

sub server {
    my $self = shift;

    return $self->{server};
}

=pod

---++ ObjectMethod readConn( $fd, $event )
Select callback for read data ready on this connection
   * =$fd= - fd number of socket
   * =$event= - event code ('r')

Handles actual read, then calls readData to process data.

Can be overridden for protocols needing more elaborate processing.

Errors are handled here.  Should not need to be subclassed.

=cut

sub readConn {
    my( $self, $fd, $event ) = @_;

    my $sock = $self->{sock};

    # Read new data chunk and append to buffer

    my $rn = $sock->sysread( $self ->{rbuf}, 1000, length $self->{rbuf} );

    unless( $rn ) {
        $self->{error} .= "Read error: $!\n" unless( defined $rn );

	schedulerRegisterFds( $fd, '-r', undef );
	$self->{rreg} = 0;
	if( defined $rn ) {
            $self->{error} .= "End of file\n";
	    return; # EOF
	}
	# Error
        $self->errorClose;
	return;
    }

    unless( $self->readData ) {
        $self->close(0);
    }
    return;
}

=pod

---++ ObjectMethod errorClose()
Abruptly close and release a connection due to an error

Closes a connection and deregisters it's select thread(s) when an error occurs.

The error should be one that doesn't allow flushing the write queue (as close() does).

=cut

sub errorClose {
    my $self = shift;

    my $sock = $self->{sock};
    my $fd = $self->{fd};

    schedulerRegisterFds( $fd, '-', undef );
    @$self{'ereg', 'wreg', 'rreg'} = ( 0, 0, 0 );
    delete $parentFds{$fd};
    $sock->close();
    undef $sock;
    delete $self->{sock};
    $self->{server}->cxClosed( $self ) if( defined $self->{server} );
    return;
}

=pod

---++ ObjectMethod readData()
Process input data received on connection

Two modes are supported:
   * Line mode - Default, data is sent to reader in lines delimited by CR LF (network encoded).  The line ending is removed.
   * Binary mode - reader is called each time a new chunk of data arrives, and either consumes all input, or if more data is required, reinput's some or all of the data.

Switching modes can be done at any time - including in the reader.   However, data passed to the reader in line mode can't
be reinput  for binary mode reliably (due to CR/LF removal).

Return false to close connection, true to maintain.

=cut

sub readData {
    my $self = shift;

    # Binary mode

    if( $self->{binmode} ) {
	my $data = $self->{rbuf};
	$self->{rbuf} = '';

	unless( $self->readLine( $data ) ) {
	    return 0;
	}
	return 1 if( $self->{binmode} || !length $self->{rbuf} );
    }

    # Line mode loop - Note that anything following the first $LF can be binary data

    while( my( $line, $rest ) = ($self->{rbuf} =~ /\A(.*?)$LF(.*)\z/mso) ) {
	$rest = '' unless( defined $rest );
	$self->{rbuf} = $rest;

	$line =~ s/$CR//go;

	unless( $self->readLine( $line ) ) {
	    return 0;
	}
	next unless( $self->{binmode} );

	# Switched to binary - deliver remaining data

	$line = $self->{rbuf};
	return 1 unless( length $line );

	$self->{rbuf} = '';

	unless( $self->readLine( $line ) ) {
	    return 0;
	}
	return 1 if( $self->{binmode} );

	# Switched back to line mode - see if a line is ready
    }

    # All available line mode data has been processed.
    return 1;
}

=pod

---++ ObjectMethod exceptConn( $fd, $event )
Select callback for exception ready on this connection
   * =$fd= - fd number of socket
   * =$event= - event code ('r')

Exception is protocol specific (e.g. urgent data for telnet).  Any protocol that needs exception callbacks must subclass
this method.

No return value is expected.

=cut

sub exceptConn {
    my( $self, $fd, $event ) = @_;

    die "exception from fd $fd";
}

=pod

---++ ObjectMethod readLine( $line ) -> $maintainCx
Connection data delivery
   * =$line= - line (or chunk) of data received from connection

Called with data received from the network.

In line mode, called for each line (with line ending already removed).
In binary mode, called each time a new chunk of data arrives.

Unprocessed data can be pushed back into the input buffer with reinput(), and the mode can be changed with binmode().

Return true to maintain connection, false to close it.  When closed, no more data will be delivered, but network close won't
occur until all data queued for write has been delivered to the network.

This method must be subclassed by the next layer.

=cut

sub readLine {
    my $self = shift;
    my $line = shift;

    die "Received data with no client: $line\n";
}

=pod

---++ ObjectMethod reinput( $data )
Replace data in input buffer
   * =$data= - data to be replaced at the beginning of the input buffer

In binary mode, data is received on arbitrary boundaries.  When sufficient data is not presented to complete a transaction,
readLine calls this method to push data back into the input buffer for later consideration.

In line mode, data can be introduced into the input stream.

=cut

sub reinput {
    my( $self, $data ) = @_;

    $self->{rbuf} = $data . $self->{rbuf};

    return;
}


=pod

---++ ObjectMethod binmode( $binmode ) -> $old
Set/return input mode
   * =$binmode= - If specified, true to set binary mode, false to set line mode

Returns previous value: true if in binary mode, false if in line mode.

=cut

# Binary mode

sub binmode {
    my $self = shift;

    my $old = $self->{binmode};

    $self->{binmode} = $_[0] if( @_ );

    return $old;
}

=pod

---++ ObjectMethod error() -> $string
Accessor for error string

Returns string describing any errors

=cut

# Return error string

sub error {
    my $self = shift;

    return $self->{error};
}

=pod

---++ ObjectMethod print( @list )
Write data to connection
   * =@list= - data to be written.  Multiple elements are simply concatenated.

Data is placed into the output buffer, and (if necessary) a select callback is enabled for write ready.

Actual data transfer is defered to the next poll because:
   * The network may not be ready due to a pending write
   * It is likely that more than one print will be done, and merging the writes is more efficient.

=cut

sub print {
    my( $self ) = shift;

    my $dataAvail = length( $self->{wbuf} .= join( '', @_ ) );

    if( $dataAvail && !$self->{wreg} ) {
        # Start write when ready - also allows maximum buffering

        schedulerRegisterFds( $self->{fd}, 'w', sub { $self->writeConn(); } );
        $self->{wreg} = 1;
    }
    return;
}

=pod

---++ ObjectMethod printf( $fmt, @list )
Formatted write to network
   * =$fmt= - sprintf format string
   * =$list= - sprintf argument list

Convenience routine for formatting and writing data to a connection.

=cut

sub printf {
    my $self = shift;
    my $fmt = shift;

    $self->print( sprintf( $fmt, @_ ) );
    return;
}

=pod

---++ ObjectMethod writeConn()
Select callback for write ready on this connection
   * =$fd= - fd number of socket
   * =$event= - event code ('w')

Write as much data as possible to the socket.  If any data remains in the buffer, wait for next select write ready callback.

If write is complete, handle any pending close/exit

=cut

sub writeConn {
    my $self = shift;

    my $sock = $self->{sock};

    # If data is in buffer, attempt to send it

    if( length $self->{wbuf} ) {
	my $written = $sock->syswrite( $self->{wbuf} );
	if( defined $written ) {
	    $self->{wbuf} = substr( $self->{wbuf}, $written );
	} else {
	    $self->{error} = $!;
	    logMsg( WARN, "Network write failed: $!" );
	    $self->{wbuf} = '';
	    $self->{wend} = 1;
	}
    }

    # If data remains, wait for next write ready

    if( length $self->{wbuf} ) {
        unless( $self->{wreg} ) {
            schedulerRegisterFds( $self->{fd}, 'w', sub { $self->writeConn( ); } );
            $self->{wreg} = 1;
        }
	return;
    }

    # No data left

    if( $self->{wend} ) {
        # Queued close
        $self->lastWrite;
    } else {
        # End of current data, de-register write ready callback

        if( $self->{wreg} ) {
            schedulerRegisterFds( $self->{fd}, '-w', undef );
            $self->{wreg} = 0;
        }
    }

    return;
}

=pod

---++ ObjectMethod lastWrite()
Process queued close

Process the final write on a connection marked for close.

=cut

sub lastWrite {
    my $self = shift;

    my $sock = $self->{sock};

#	$sock->shutdown( 1 ); # All data transferred, signal done writing.
	schedulerRegisterFds( $self->{fd}, '-', undef ) if( $sock );
	$self->{wreg} = 0;
	$self->{ereg} = 0;
	$self->{rreg} = 0;
	if( $sock && $self->{wexit} == 2 ) {
	    # Connection to be passed to successor/child
	    my $f = fcntl( $sock, F_GETFD, 0 ) or die "fcntl: $!\n";
	    fcntl( $sock, F_SETFD, $f & ~FD_CLOEXEC ) or die "Fcntl: $!\n";
	} elsif( $sock ) {
	    delete $parentFds{$self->{fd}};
	    $sock->close();
	    delete $self->{sock};
	    # $close routine holds a reference, so call it here
	    $self->{server}->cxClosed( $self ) if( defined $self->{server} );
	}
    return;
}

=pod

---++ ObjectMethod status( $txtformat, $needhdr, $colwids, $prescan ) -> $text
Generate connection status text
   * =$txtformat= - Generate plain text (else html)
   * =$needhdr= - Print a header for connection table
   * =$colwids= - Reference to column width array
   * =$prescan= - True if prescan pass (used to determine column widths for plain text)

Produces a status line for this connection.  Used by StatusServer, not for general use.

Returns status text.

=cut

sub status {
    my( $self, $txtformat, $needhdr, $colwids, $prescan )  = @_;

    my $sock = $self->{sock};

    return '' unless( $sock );

    @$colwids = (2, 5, 4, 4, 7) if( $txtformat && $prescan && !$colwids->[0] );
    my $msg = '';
    if( $needhdr && !$prescan) {
	if( $txtformat ) {
	    $msg = sprintf " Active clients:\n  %*s %-*s %-*s %-*s %-*s\n",
                           $colwids->[0], 'ID',
			   $colwids->[1], 'Local',
			   $colwids->[2], 'Peer',
                           $colwids->[3], 'User',
			   $colwids->[4], 'Started';
	} else {
	    $msg = "<h3>Active clients</h3><table><tr><td><b>ID</b><td><b>Local</b><td><b>Peer</b><td><b>User</b><td><b>Started</b>";
	}
    }

    if( $txtformat ) {
	if( $prescan ) {
	    _max(@$colwids, 0, sprintf( "%u", $self->{fd} ) );
	    _max(@$colwids, 1, $self->sockhost );
	    _max(@$colwids, 2, $self->peerhost );
            _max(@$colwids, 3, $self->{remuser} );
	    _max(@$colwids, 4, (scalar localtime( $self->{started} )) );
	} else {
	    $msg .= sprintf( "  %*u %-*s %-*s %-*s %-*s\n",
			     $colwids->[0], $self->{fd},
			     $colwids->[1], $self->sockhost,
			     $colwids->[2], $self->peerhost,
                             $colwids->[3], $self->{remuser},
			     $colwids->[4], (scalar localtime( $self->{started} ))
			   );
	}
    } else {
	$msg .= "<tr><td>$self->{fd}<td>" . $self->sockhost . '<td>' . $self->peerhost . "<td>$self->{remuser}" .
	             '<td>' . (scalar localtime( $self->{started} ));
    }
    return $msg;
}

=pod

---++ ObjectMethod peeruser() -> $text
Return username of connected client

Returns the username of connected client, or '' if unknown.

=cut

sub peeruser {
    my $self = shift;

    return $self->{remuser};
}


=pod

---++ ObjectMethod peerhost( $textreq ) -> $text
Return name of connected client
   * =$textreq= - True if text is required (undef returned if not available)  False falls back to numeric string if name unavailable

Returns the hostname of client

=cut

sub peerhost {
    my $self = shift;
    my $textreq = shift;

    my $sock = $self->{sock};
    return '<unknown>' unless( $sock && $sock->connected );

    my $host;
    my $port = $sock->peerport; # Port name is likely random

    # hostname will be returned as numeric if no name is available.
    # This isn't specified behavior, so we'll handle either way.

    if( ($host = $sock->peerhostname) && !($sock->sockdomain == AF_INET6 && $host =~ /:/ ||
                                           $sock->sockdomain == AF_INET &&
                                                           $host =~ /^\d+\.\d+\.\d+\.\d+$/) ) {
        return "$host:$port";
    }
    return undef if( $textreq );

    $host = $sock->peerhost;
    if( $sock->sockdomain == AF_INET6 ) {
        return "[$host]:$port";
    }
    return "$host:$port";

#    return ((scalar gethostbyaddr $sock->peeraddr, AF_INET) || ($textreq? undef :
#		    $sock->peerhost())) . ':' .  $sock->peerport();
}

=pod

---++ ObjectMethod sockhost( $textreq ) -> $text
Return hostname of socket
   * =$textreq= - True if text is required (undef returned if not available)  False falls back to numeric string if name unavailable

Returns the hostname of the socket.  If listening on a wildcard address, returns the actual hostname handling this connection.

=cut

sub sockhost {
    my $self = shift;
    my $textreq = shift;

    my $sock = $self->{sock};
    return '<unknown>' unless( $sock && $sock->connected );

    my $host;
    my $port = $sock->sockport; # Port name is likely random

    if( ($host = $sock->sockhostname) && !($sock->sockdomain == AF_INET6 && $host =~ /:/ ||
                                           $sock->sockdomain == AF_INET &&
                                                           $host =~ /^\d+\.\d+\.\d+\.\d+$/) ) {
        return "$host:$port";
    }

    return undef if( $textreq );

    $host = $sock->sockhost;
    if( $sock->sockdomain == AF_INET6 ) {
        return "[$host]:$port";
    }
    return "$host:$port";

#    return ((scalar gethostbyaddr $sock->sockaddr, AF_INET) || ($textreq? undef :
#		    $sock->sockhost())) . ':' .  $sock->sockport();
}

=pod

---++ ObjectMethod close( $exit ) -> $busy
Close connection
   * =$exit= - Action when close completes (0 = just close, 1 = exit, 2 = exec/fork leaving open)

Marks connection object for eventual close.  Close is deferred until all pending write data has been sent to the network, or
a network write fails.

=cut

sub close {
    my $self = shift;
    my $exit = shift;

    $self->{wend} = 1;
    $self->{wexit} = $exit if( $exit );

    $self->{rbuf} = ''; # Flush input & stop reading from connection.

    if( $self->{rreg} ) {
        schedulerRegisterFds( $self->{fd}, '-r', undef );
        $self->{rreg} = 0;
    }

    # Close now unless write pending

    $self->writeConn() unless ( $self->{wreg} );

    return $self->{wreg};
}

# ---++ DESTROY
# Destructor

DESTROY {
    my $self = shift;

    if( $forkedTask ) {
	delete @$self{'sock','server'};
	return;
    }

    my $sock = $self->{sock};

    if( $sock ) {
	schedulerRegisterFds( $self->{fd}, '-', undef ) if( $self->{wreg} || $self->{rreg} || $self->{ereg} );
	$self->{wreg} = 0;
	$self->{rreg} = 0;
	$self->{ereg} = 0;
	delete $parentFds{$self->{fd}};
	$sock->close unless( $self->{wexit} && $self->{wexit} == 2 );
	delete $self->{sock};
    }

    $self->{server}->cxClosed( $self ) if( defined $self->{server} );
    delete $self->{server};

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
