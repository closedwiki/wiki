# -*- mode: CPerl; -*-
# TWiki off-line task management framework addon for the TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2011 Timothe Litt <litt at acm dot org>
# License is at end of module.
# Removal of Copyright and/or License prohibited.


use strict;
use warnings;

=pod

---+ package TWiki::Tasks::TelnetServer
Telnet server object.

This class specializes a GenericServer to provide a limited subset of the telnet protocol.  It should be further subclassed by
the telnet application.

See GenericServer for documentation of the methods inherited from it.

The server handles connection setup, authentication and provides a default data sink.

The server assumes a reasonably functional telent client and does NOT implement most of the protocol.  It is intended to support
the debug server's requirement for a command connection, although it can be used for similar restricted applications.

All the usual warnings about telnet's security apply.  We strongly recommend that this server be configured to listen only on
localhost ports.

Most of the work is handled by the connection module, TelnetCx.

=cut

package TWiki::Tasks::TelnetServer;

use base qw/TWiki::Tasks::GenericServer/;

use Socket qw/:crlf/;

=pod

---++ ClassMethod new( @parlist ) -> $serverRef
Constructor for a new TelnetServer object

Subclass of GenericServer::new, which documents the parameters.

Returns server object.

=cut

sub new {
    my $class = shift;

    my $self = $class->SUPER::new( @_ );

    $self->{pname} = 'telnet';
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

    require TWiki::Tasks::TelnetCx;
    return TWiki::Tasks::TelnetCx->new( $self, $sock );
}

=pod

---++ ObjectMethod authenticate( $cx, $users, $user, $pass ) -> $ok
Authenticate a new connection to this server.
   * =$cx= - connection object
   * =$users= - reference to hash defining valid users: =username= => _crypt_ of =password=
   * =$user= - username provided by client
   * =$pass= - password provided by client

=cut

sub authenticate {
    my( $self, $cx, $users, $user, $pass ) = @_;

    my $correctpass = $users->{$user};
    return 0 unless( defined $correctpass );
    if(  crypt($pass, $correctpass) eq $correctpass ) {
        if( $cx->{remuser} ) {
            $cx->{remuser} .= " as $user";
        } else {
            $cx->{remuser} = $user;
        }
	return 1;
    }
    return 0;
}

=pod

---++ ObjectMethod recieve( $cx, $line ) -> $maintainCx
Called with a line of data received from a telnet connection after telnet control sequences have been processed.
   * =$cx= - Connection object
   * =$line= - line of data

Data has end-of-line characters removed.

This is normally subclassed by the telnet client; the code here should never be executed.

Returns 0 to drop the connection, 1 to maintain it.

=cut

sub receive {
    my( $self, $cx, $line ) = @_;

    $self->print( $cx, "Unknown command: $line$CRLF" );

    return 1;
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
