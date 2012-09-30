# -*- mode: CPerl; -*-
# TWiki off-line task management framework addon for the TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2011 Timothe Litt <litt at acm dot org>
# License is at end of module.
# Removal of Copyright and/or License prohibited.


use strict;
use warnings;


=pod

---+ package TWiki::Tasks::TelnetCx
Select-threaded Telnet connection object.

This subclass of the GenericCx object specializes it for a very minimal subset of the telnet protocol.

See GenericCx for documentation of the methods inherited from it

This does NOT even come close to emulating a traditional telnet server.  It does the minimal things necessary to enable a
standard telnet client to communicate with the debug server.  It does not negotiate parameters or check for compliance with
its demands.

It assumes client support for SGA, LINEMODE EDIT and ECHO.  It removes inbound telnet control sequences from the data stream,
and delivers data in line mode to the local client.  It ensures that output uses the telnet-required line endings.

This approach was chosen because telnet clients are the most widely available remote terminal clients, and the implementation
effort was low.  All of the standard telnet clients for workstation/server operating systems that I know of should work
satisfactorily with this application.

Telnet is defined by a large number of RFCs, which can be consulted for definitions of the protocol elements used here.

All the usual warnings about telnet security apply.  We strongly recommend that the server be configured to listen only on
localhost ports.

=cut

package TWiki::Tasks::TelnetCx;

use base qw/TWiki::Tasks::GenericCx/;

use Socket qw/:crlf/;

=pod

---++ ClassMethod new( $server, $socket ) -> $cx
Constructor for a new TelnetCx object
   * =$server= - server object controlling connection
   * =$socket= - socket from accept()

Create and initialize an HttpCx object.

=cut

sub new {
    my $class = shift;
#    my( $server, $sock ) = @_;

    my $self = $class->SUPER::new( @_ );

    $self->binmode(1);
    my $ctx = $self->{ctx};
    $ctx->{echo} = 1;

    return $self;
}

=pod

---++ ObjectMethod initTelnet()
Send initialization string to telnet client

Not done during new to allow server to decide if telnet will be used on a connection.  This allows authenticating servers
to only prompt if a password isn't supplied on the first command.  And that prevents non-telnet clients from seeing the init string.

=cut

sub initTelnet {
    my $self = shift;

    my $ctx = $self->{ctx};

    if( !$ctx->{telnetInitSent} ) {
        $self->print(
		     chr(255).chr(251).chr( 3) . # Will SGA (full duplex)
		     chr(255).chr(253).chr( 1) . # Do SGA
		     chr(255).chr(253).chr(34) . # Do LINEMODE (Client line editing)
		     chr(255).chr(250).chr(34).chr(1).chr(1).chr(255).chr(240)
		                               # DO SB LINEMODE MODE EDIT SE
		    );
	$ctx->{telnetInitSent} = 1;
    }
    return;
}

=pod

---++ ObjectMethod print( @list )
Write data to a telent connection
   * =@list= - Data to write.  Array elements are simply concatenated.

Maps line endings from local encoding to telnet wire protocol.

=cut

sub print {
    my $self = shift;

    my $text = join( '', @_ );

    $text =~ s/$CR+$LF/\n/gmso;
    $text =~ s/\n/$CRLF/gmso;

    $self->SUPER::print( $text );
}

=pod

---++ ObjectMethod readLine( $data ) -> $maintainCx
Connection receive callback

Called with data from the connection.

The connection is always in binary mode, so data is received in chunks.
Telnet controls are stripped from the received data, and the remainder is delivered to the server =receive= callback in line mode.

If sufficient data to parse a complete telenet control or data line is not available, the available data is buffered until
sufficent data arrives.

Returns 0 to drop the connection, 1 to maintain it.

=cut

sub readLine {
    my( $self, $data ) = @_;

    my $server = $self->server() or return 0;

    # Strip any telnet sequences from received data.
    # If sequence is incomplete, save the partial sequence for future processing.

    my $partialCtl = _stripTelnet( $data );

    # With telnet sequences removed, we can now break into lines for client
    # Note that we do not support client binary mode.

    while( $data =~ /$LF/smo ) {
	$data =~ s/$CR//go;
	my $line;
	($line, $data) = split( /$LF/o, $data, 2 );
	$data = '' unless( defined $data );

	# Deliver line

	return 0 unless( $server->receive( $self, $line ) );
    }

    # Buffer any partial payload line & any partial telnet control sequence for processing with next chunk.
    # Any partial payload can't be handled until the control completes and the EOL arrives.  We could save it
    # somewhere else to avoid re-parsing it, but this shouldn't be a common case and the complexity isn't warranted.
    # Normally, there's not partial control, so we're just waiting for the EOL.

    $self->reinput( $data . $partialCtl );
    return 1;
}

=pod

---++ ObjectMethod echo( $on ) -> $old
Return/set echoing
   * =$on= - True enables echoing, false disables.  No change if not present.

Instructs telnet client to stop echoing typein (e.g. for password input), or to resume echoing.

There is no guarantee that the client will comply.

Returns previous state.

=cut

sub echo {
    my $self = shift;

    my $ctx = $self->{ctx};

    my $old = $ctx->{echo};

    return $old unless( @_ );

    my $wanted = $_[0];

    if( $wanted xor $old ) { # WONT ECHO (client will) : WILL ECHO ( small lie )
	$self->print( ($wanted? chr(255).chr(252).chr(1) : chr(255).chr(251).chr(1) ) );
	$ctx->{echo} = $wanted;
    }
    return $old;
}

# ---++ StaticMethod _stripTelnet( $data ) -> $partialSequence
# strip telnet sequences sent by client
#    * =$data= - Incoming data that may (or may not) contain telnet control sequences interleaved with payload.
#
# Scans $data for telnet control sequences.  Removes telnet sequences, updating $data.
#
# If a partial telnet sequence is encountered, it is returned so that it can be re-parsed when the remainder arrives.
#
# The sequences are not interpreted: we pay no attention to what the client wants or whether it's doing what we want.

sub _stripTelnet {
    my @in = split( //, $_[0] );
    my $out = '';
    my $ctl;

  IN:
    while( @in ) {
	my $c = shift @in;
	my $cn = ord $c;

	unless( $cn == 255 ) { # IAC
	    $out .= $c;
	    next;
	}
        # New control starting
        $ctl = $c;
	goto INCOMPLETE unless( @in );
        $ctl .= $c = shift @in;

	$cn = ord $c;
	if( $cn == 255 ) { # IAC IAC => 255
	    $out .= $c;
            undef $ctl;
	    next;
	}
	if( $cn >= 251 ) { # IAC (WILL, WONT, DO, DONT) option
	    goto INCOMPLETE unless( @in );
            $c = shift @in;
	    undef $ctl;
	    next;
	}
	if( $cn == 250 ) { # IAC SB option string IAC SE
	    goto INCOMPLETE unless( @in );
	    $ctl .= $c = shift @in;

	    while( @in ) {
		$ctl .= $c = shift @in;
		next unless( ord( $c ) == 255 ); # IAC
		goto INCOMPLETE unless( @in );
		$c = shift @in;
                if( ord( $c ) == 240 ) {  # SE
                    undef $ctl;
                    next IN;
                }
                $ctl .= $c;
	    }
	    # Don't have SE yet, wait for more input.
	    goto INCOMPLETE;
	}
	# IAC Something else, assume 2 byte sequence and ignore it.
        undef $ctl;
    }

    # End of data with no incomplete control sequence.  Update $data with payload, return null pending control
    $_[0] = $out;

    return '';

    # Incomplete control sequence.  Return payload in $data and partial control sequence as return value.
    # This allows us to process any payload without waiting for the rest of the control sequence.  Since we
    # ran out of data parsing the last sequence, we know that the sequence follows any payload.

  INCOMPLETE:
    $_[0] = $out;
    return defined( $ctl )? $ctl : '';
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
