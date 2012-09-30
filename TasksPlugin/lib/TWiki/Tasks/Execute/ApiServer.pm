# -*- mode: CPerl; -*-
# TWiki off-line task management framework addon for the TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2011 Timothe Litt <litt at acm dot org>
# License is at end of module.
# Removal of Copyright and/or License prohibited.


use strict;
use warnings;


=pod

---+ package TWiki::Tasks::Execute::ApiServer
Remote Procedure Call service for the TASK daemon

This is a hybrid select-threaded server.  Standard servers listen for connections on TCP sockets; this function is integrated
into TWiki::Tasks::Execute.  As a result, the ApiServer object is actually derived from GenericCx, as it primarily implements
a transport protocol.  To satisfy GenericCx, the object doubles as a Server object, with most of the server routines stubbed out.
This technique is not recomended for the fainthearted...but it works for this application.

Most tasks execute as child forks of the daemon.

The forks request daemon services using the RPC mechanism.  This is the server (daemon) side of the protocol.

This protocol runs on a socketpair created before the fork occurs.  Generally, operation of the protocol - including
calls to this module - are hidden from the user by the API.  The client side of the protocol is synchronous.

The protocol is a simple request/response protocol.  The client requests that a daemon routine be called, and its
arguments are marshalled and sent with the request.  Class, object and static method calls are supported.

Arguments and return values are passed usng Storable, which imposes some restrictions on what can be sent.
See perldoc Storable for the limitations - they don't impact current uses.

The connection is considered secure because the daemon creates the socketpair, the client file descriptor is
inherited by the fork, and the fork contents are specified by a trusted administrator.

Rpc.pm contains the client side of this protocol.

=cut

package TWiki::Tasks::Execute::ApiServer;

use base 'TWiki::Tasks::GenericCx';

use TWiki::Tasks::Execute::RpcHandle qw/makeRpcHandles/;
use TWiki::Tasks::Globals qw/:api/;
use TWiki::Tasks::Logging;

use Scalar::Util qw/blessed weaken/;
use Socket qw/:crlf/;
use Storable qw/freeze thaw/;

=pod

---++ ClassMethod new( $task, $socket ) -> $cx
Constructor for a new TelnetCx object
   * =$task= - Task object of client
   * =$socket= - Server socket from socketpair()

Create and initialize an ApiServer object.

=cut

sub new {
    my $class = shift;
    my( $task, $sock ) = @_;

    my $self = {
		task => $task,
	       };
    weaken( $self->{task} );

    bless( $self, $class );

    $self->{cx} = $class->SUPER::new( $self, $sock );

    return $self;
}

=pod

---++ ObjectMethod readLine( $data ) -> $maintainCx
Connection receive callback

Called with data from the connection.

The connection is established in line mode.

For each RPC received, the first line received contains:
   * The length of the encoded arguments
   * The calling context
   * The subroutine/method name to be called
   * The call type (indirect method or direct)

After receiving the command line, the connection switches to binary mode to receive the arguments.

Receiving an RPC can require multiple calls to readLine if the data arrives in chunks.

Arguments that are RPC handles are mapped to the actual object, and the procedure is called.

The response consists of a line containg:
   * The length of the encoded return data
   * The subroutine name that was called
Followed by the binary response data.

Any errors attributable to the daemon are logged.  Detected client errors will close the connection (and are logged).

Exceptions incurred by the called procedure are reflected to the client.

=cut

sub readLine {
    my( $self, $data ) = @_;

    my $ctx = $self->{ctx};
    my $server = $self->server or return 0;
    my $task = $server->{task} or return 0;

    my $expected = $ctx->{rxlength};

    unless( $expected ) {
        # Parse request line of new RPC
	unless( $data =~ /\A(\d+) ([0\@])?([^;]*)(;)?\z/ ) {
	    logMsg( ERROR, "Received invalid rpc from $task->{name}: $data\n" );
	    return 0;
	}
	@$ctx{'rxlength', 'wantarray', 'subname', 'imethodcall'} = ( $1, $2, $3, $4 );
	$self->binmode(1);
	return 1;
    }

    # Read argument data, buffering until the complete request arrives

    my $len = length $data;
    unless( $len >= $expected ) {
	$self->reinput( $data );
	return 1;
    }

    # Pushback any excess (allows for pipelining)

    if( $len > $expected ) {
	my $extra = substr( $data, $expected, $len - $expected, '' );
	$self->reinput( $extra );
    }
    $ctx->{rxlength} = 0;
    $self->binmode(0);

    # Entire RPC has been received.  Decode and execute

    my $subname = $ctx->{subname};
    my $wantarray = $ctx->{wantarray};

    # Recover argument list from data

    if( $expected == 0 ) {
	logMsg( ERROR, "Rpc $subname from $task->{name} did not contain argument data\n" );
	return 0;
    }

    eval {
	defined( $data = thaw( $data ) ) or
          die "thaw returned undef\n";
    };
    if( $@ ) {
	logMsg( ERROR, "Failed to deserialize rpc $subname from $task->{name}: $@" );
	return 0;
    }

    # Expand all RPC handles in argument list

    foreach (@$data) {
        next unless( blessed $_);

        if( $_->isa( 'TWiki::Tasks::Execute::RpcHandle' ) ) {
            $_ = $_->_getHandle;
        } else { # Defend against method calls to unknown objects
            logMsg( ERROR, "Rpc $subname from $task->{name} called on an unknown object of type " . blessed( $_ ) );
            return 0;
        }
    }

    # Log execution on behalf of (remote) caller

    $TWiki::Tasks::Logging::logPid = $task->{_pid};

    # Based on type of call, invoke method or subroutine to generate response

    my $response;
    if( $ctx->{imethodcall} ) {
	# Instance method invocation

	my $object = shift @$data;

        if( $object && blessed $object ) {
            if( $wantarray ) {
                $response = [ eval { $object->$subname( @$data ); } ];
            } elsif( defined $wantarray ) {
                $response = \scalar eval { $object->$subname( @$data ); };
            } else {
                eval { $object->$subname( @$data ); };
                $response = \undef;
            }
        } else {
            $@ = sprintf( "Rpc method call on %s object", ($object? 'unblessed' : 'null') );
        }
    } else {
	# Class method or ordinary subroutine call

	no strict 'refs';
	if( $wantarray ) {
	    $response = [ eval "$subname( \@\$data )" ];
	} elsif( defined $wantarray ) {
	    $response = \scalar eval "$subname( \@\$data )";
	} else {
	    eval "$subname( \@\$data )";
	    $response = \undef;
	}
    }
    $TWiki::Tasks::Logging::logPid = $$;
    if( $@ ) {
	# Error prevented call or exception occurred in call, return to caller as exception
	$response = \"$@";
	$ctx->{subname} = '_RpcDied_' . $ctx->{subname};
    } elsif( $wantarray ) {
	# Convert any returned object references to handles
	makeRpcHandles( @$response );
    } else {
	# If a single object ref, convert to handle
	makeRpcHandles( $$response );
    }

    # Serialize and send response

    eval {
	defined( $response = freeze( $response ) ) or
          die "freeze returned undef\n";
    };
    if( $@ ) {
	logMsg( ERROR, "Failed to serialize rpc response $subname from $task->{name}: $@" );
	return 0;
    }

    $self->print( length( $response ), " $ctx->{subname}$LF", $response );

    return 1;
}


# ---++ ObjectMethod status
# Stub overriding inapplicable routine from generic connection
#

sub status {
    die "No status";
}

# ---++ ObjectMethod status
# Stub overriding inapplicable routine from generic connection
#

sub peerhost {
    die "No peerhost";
}

# ---++ ObjectMethod status
# Stub overriding inapplicable routine from generic connection
#

sub sockhost {
    die "No sockhost";
}

=pod

---++ ObjectMethod close()
Close server or connection

Because of the hybrid nature of this object, close is called both for the server and for the connection.

Disambiguate and call the correct routine.

=cut

sub close {
    my $self = shift;

    return $self->{cx}->close(@_) if( exists $self->{cx} ); # Server

    return $self->SUPER::close(@_);
}

=pod

---++ ObjectMethod cxClosed( $cx )
Server method called when a connection closes

Normal servers remove connection from the active connection database.

There's actually nothing to do here, but the method is required.

=cut

sub cxClosed {
    my $self = shift;

#    undef $self->{cx};
#    undef $self->{task};
}

=pod

---++ ObjectMethod DESTROY()
Destructor

=cut

sub DESTROY {
    my $self = shift;

    if( $forkedTask ) {
	# This is the API for some other task (copied @fork)

	# We have stale data for that API's sockets, including
	# fds that were closed (as parentFds).  We don't want
	# to close whatever they're conencted to now, but we do
	# need to break any circular references.
	delete @$self{'sock', 'server', 'cx', 'task'};
	return;
    }

    # Normal case: this is the Daemon cleaning up after a task's execution

    # Close connection, not server
    if( exists $self->{cx} ) {
	undef $self->{cx};
	undef $self->{task};
	return;
    }
    $self->close( 0 );
    $self->SUPER::DESTROY();
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
