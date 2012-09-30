# -*- mode: CPerl; -*-
# TWiki off-line task management framework addon for the TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2011 Timothe Litt <litt at acm dot org>
# License is at end of module.
# Removal of Copyright and/or License prohibited.


use strict;
use warnings;

=pod

---+ package TWiki::Tasks::DebugServer
Provides a minimalist debugger/commmand line for the task framework.

As with any system daemon, debugging can be a challenge.  This optional module provides a telnet-compatible command server that
allows the debug user to view the daemon's status / internal logs and cause the daemon to evaluate perl expressions.  Although
simple, it is a powerful tool and as such can be abused.

This is intended *only* for programmers, not for administrator or for general users.

It is only available when enabled by expert settings in configure.  We recomend that this is *not* enabled in production or
sensitive environments as it allows a user to execute ANY perl statement as the webserver user.

The debug server can be enabled or disabled from configure without restarting the daemon.

=configure= describes the expert settings and considerations in detail.

This is a select-threaded server, and as such executes in _Daemon context.

=cut

package TWiki::Tasks::DebugServer;

use base qw/TWiki::Tasks::TelnetServer/;

#use TWiki::Tasks::Globals qw/:debugsrv/;
use TWiki::Tasks::Schedule qw/suspendScheduling resumeScheduling stopDaemon restartDaemon/;
use TWiki::Tasks::Logging qw/:DEFAULT logHistory %logAlert/;

use Data::Dumper;
$Data::Dumper::Sortkeys = 1;

use IO::CaptureOutput;
use IO::Handle;
use SelectSaver;
use Socket qw/:crlf/;
use Sys::Hostname;

=pod

---++ ObjectMethod connect( $sock, $restarting, $initiator, $textformat ) -> $cx
Associate a new connection's socket with this server.

Subclass of GenericServer::connect, which documents the parameters.

Logs connection and initializes the telnet protocol.  Handles host-level authentication.

Returns connection object.

=cut

sub connect {
    my $self = shift;
    my( $sock, $restarting, $initiator, $textformat ) = @_;

    my $cx = $self->SUPER::connect( @_ );

    return unless( $cx );

    my $peerhost = $cx->peerhost || '';
    logMsg( INFO, "Debugger connection established from " . $peerhost );
    $cx->{ctx}{peername} = $peerhost;

    if( $restarting ) {
	if( $initiator ) {
	    $cx->print( "\nRestart successful\n\n" );
	} else {
	    $cx->print( "\n *** Daemon has restarted ***\n\n" );
	}
    }

    $cx->{ctx}{package} = 'main';

    # ---------
    # The authentication scheme was designed for scripts to be
    # able to interact privately using $TWiki::cfg{Password} as
    # a shared secret.  Since we have web-based status now,
    # this is obsolete.  But just in case it's useful later,
    # I left the code in receive() behind and added the next few lines
    # to bypass it.  You still need the configure password for access.
    #
    # Note this is not something to use casually, as eval provides the
    # equivalent of sudo -u <webserver> <anything>

    $cx->initTelnet;
    $cx->{ctx}{interactive} = 1;

    my $host = hostname;

    # For a VERY secure environment (perhaps everything on a single-user
    # client with the webserver in a constrained VM-only network), you
    # can trust remote host:ports matching this regex.  In this case, no
    # password is required.  This is dangerous; use at your own risk.

    if( $TWiki::cfg{Tasks}{DebugTrustedHost} && $peerhost =~ qr($TWiki::cfg{Tasks}{DebugTrustedHost})i ) {
	logMsg( INFO, "Passwordless debugger login from trusted host $peerhost" );
	$cx->print(  "Wiki tasking debug shell on $host$CRLF${CRLF}[$$]: ", `id`, "$CRLF$CRLF>> " );
        $cx->{remuser} = 'Trusted Host Autologin';
	$cx->{ctx}{Authenticated} = 1;
	$cx->echo(1);
    } else {
	$cx->echo(0);
	$cx->print( "Wiki tasking debug shell on $host$CRLF${CRLF}Password: " );
    }
    # ---------

    return $cx;
}

=pod

---++ ObjectMethod cxClosed( $cx )
Called when a connection closes

=cut

sub cxClosed {
    my $self = shift;
    my $cx = shift;

    delete $logAlert{$cx};

    logMsg( INFO, "Debugger connection from " . $cx->{ctx}{peername} . " closed" ) unless( $cx->{_closeLogged} );
    $cx->{_closeLogged} = 1;

    $self->SUPER::cxClosed( $cx );
}

=pod

---++ ObjectMethod recieve( $cx, $line ) -> $maintainCx
Called with a line of data received from a telnet connection after telnet control sequences have been processed.
   * =$cx= - Connection object
   * =$line= - line of data

Data has end-of-line characters removed.

This implements authentication and command parsing.

To support both script and human clients, the authentication scheme is a bit messy.  Scripts can
append the crypt'd password at the end of a command.  Humans have to type <CR> to get a password prompt.

Somewhat ugly, but then the humans are debuggers, and the scripts don't want to have to deal with telnet
sequences in their data...

Returns 0 to drop the connection, 1 to maintain it.

=cut

sub receive {
    my( $self, $cx, $line ) = @_;

    my $ctx = $cx->{ctx};

    my $cmd = '';
    my $qual = '';

    unless( $cx->echo ) {
	$cx->print( $CRLF );
	if( $self->authenticate( $cx, {
				       debugger => ($TWiki::cfg{Password} || ''),
				      }, 'debugger', $line ) ) {
	    $ctx->{Authenticated} = 1;
	    $ctx->{interactive} = 1;
	    $cx->echo(1);
	    logMsg( INFO, "Successful debugger login from " . $cx->{ctx}{peername} );
	    $cx->print(  "[$$]: ", `id`, "$CRLF$CRLF>> " );
	} else {
	    logMsg( WARN, "Debug connection from " . $cx->{ctx}{peername} . " provided invalid password" );
	    $cx->print( "${CRLF}Password: " );
	}
	return 1;
    }
    # Internal commands append :password to avoid prompt

    if( $line =~ /^\s*(\S+)(?:\s+(.+))?$/ && $ctx->{interactive} ||
	$line =~ /^([^:]+):(?:([^:]*):)*(.*)$/ ) {
	$cmd = $1;
	$qual = $2;
	my $pass = $3;
	$pass = '' unless( defined $pass );
	if( $pass eq ($TWiki::cfg{Password} || '') ) {
	    $ctx->{Authenticated} = 1;
	}
    }
    unless( $ctx->{Authenticated} ) {
	$cx->initTelnet;
	$cx->echo(0);
	$cx->print( "${CRLF}Password: " );
	return 1;
    }

    if( defined $cmd ) {
	if( $ctx->{Authenticated} ) {
	    my( $ctype, $txt );
	    if( $cmd =~ m/^status$/i ) {
		$cx->print( TWiki::Tasks::StatusServer::statusText( 1, $qual ) );
	    } elsif( $cmd =~ m/^help$/i ) {
		$cx->print( <<"EOH" );
Commands:
break           Request breakpoint in Daemon context.
cancel taskname Cancel a task
eval expr       Evaluate perl expression, print value.  Captures output & exceptions.
help            This text
log [n | watch | off]
                Show n log messages, enable watcher for new or disable watch.
package name    Eval executes in specified package (default main).
restart         Restart daemon
resume          Resume task scheduling
status [brief | list | detail]
                Task daemon status.  Default 'brief'.
suspend         Stop scheduling tasks
stop   [abort]  Shut down daemon.  abort doesn't wait for active tasks.
quit            Exit debugger
EOH
	    } elsif( $cmd =~ m/^stop$/i ) {
		($ctype, $txt) = stopDaemon( $qual && lc( $qual ) eq 'abort' );
		$cx->print( $txt );
		$cx->close( $ctype );
	    } elsif( $cmd =~ m/^restart$/i ) {
		($ctype, $txt) = restartDaemon(  $qual && lc( $qual ) eq 'abort' );
		$cx->print( $txt );
		main::listRestartCxs( $cx, 's' );
		$cx->close( $ctype );
		return 1;
	    } elsif( $cmd =~ m/^suspend$/i ) {
		($ctype, $txt) = suspendScheduling();
		$cx->print( $txt );
	    } elsif( $cmd =~ m/^resume$/i ) {
		($ctype, $txt) = resumeScheduling();
		$cx->print( $txt );
	    } elsif( $cmd =~ /^can(?:cel)?$/i ) {
		if( $qual && (my $task = TWiki::Tasks->getHandle( $qual )) ) {
		    eval {
			$task->cancel;
		    }; $@ = "Task $qual cancelled\n" unless( $@ );
		} else {
		    $@ = "No such task: $qual\n";
		}
		$cx->print( $@ );
	    } elsif( $cmd =~ /^log$/i ) {
		if( $qual && lc( $qual ) eq 'off' ) {
		    delete $logAlert{$cx};
		    $cx->print( "Log watcher disabled\n" );
		} elsif( $qual && $qual =~ /^(?:watch|on)$/i ) {
		    $logAlert{$cx} = sub {
			                     $cx->print( "\n$_[0]>> " );
					 };
		    $cx->print( "Log watcher enabled\n" );
		} else {
		    $cx->print( logHistory( ($qual && $qual =~ /^\d+$/)? $qual : -1 ) );
		}
	    } elsif( $cmd =~ /^ev(?:al)?$/i ) {
		my( $r, $a );
		my $output = '';
		{
		    local( *STDOUT, *STDERR, @SIG{'__WARN__', '__DIE__'} ) = (
			   IO::Handle->new_from_fd( 1, '>' ),
			   IO::Handle->new_from_fd( 2, '>' ),
									     );
		    my $select = SelectSaver->new( \*STDOUT );

		    $SIG{__WARN__} = sub { print STDERR 'WARN: ', @_; };
		    $SIG{__DIE__} = sub {
                                            return if( $^S || !defined $^S ); # In an eval or compiling a use/require
					    print STDERR 'DIE: ', @_;
					};
		    $qual = '' unless( defined $qual );
		    IO::CaptureOutput::capture( sub {
						        $r = eval "package $ctx->{package};\n$qual";
						    } => ( \$output, \$output ) );
		    $a = $@;
		}
		$cx->print( $output );
		if( $a ) {
		    chomp $a;
		    $cx->print( $a, $CRLF );
		} elsif( defined $r ) {
		    if( ref( $r ) ) {
			$cx->print( Data::Dumper::Dumper( $r ) );
		    } else {
			chomp $r;
			$cx->print( $r, $CRLF );
		    }
		} else {
		    $cx->print( "undef$CRLF" );
		}
	    } elsif( $cmd =~ /^pack(?:age)?$/i ) {
		if( $qual ) {
		    $ctx->{package} = $qual;
		} else {
		    $cx->print( $ctx->{package}, $CRLF );
		}
	    } elsif( $cmd =~ /^b(?:reak)?$/i ) {
		if( exists $INC{'perl5db.pl'} ) {
		    $cmd = $DB::single;          # Break Command
		    $DB::single = 2;             # Break Command
		} else {
		    $cx->print( "Debugger not loaded$CRLF" );
		}
	    } elsif( $cmd =~ /^q(?:uit)?$/i ) {
		return 0;
	    } else {
		$cx->print( "Unknown command $cmd$CRLF" ) if( length $cmd );
	    }
	} else {
	    $cx->print( "Not authorized$CRLF" );
	}
    } else {
	$cx->print( "No command$CRLF" );
    }

    if( $ctx->{Authenticated} && $ctx->{interactive} ) {
	$cx->print( '>> ' );
	return 1;
    }

    # Close connection

    return 0;
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
