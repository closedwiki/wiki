# -*- mode: CPerl; -*-
# TWiki off-line task management framework addon for the TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2011 Timothe Litt <litt at acm dot org>
# License is at end of module.
# Removal of Copyright and/or License prohibited.


use strict;
use warnings;


=pod

---+ package TWiki::Tasks::Logging
Logging service for the TWiki TASK daemon

Provides Schedule::Cron compatible logging, which the rest of the daemon has adopted by default.
The daemon has more severity levels, so there is a mapping enforced by the interface routine in Startup.

Provides an object that can be tied to STDOUT/STDERR file handles to log output sent there.

Depending on message severity, logs to the TWiki debug and warning log files, as well as a daemon-defined error log.

For debugging, will log to the terminal if run in the foreground.

Maintains a circular buffer of recent log messages which can be accessed by the status and debug servers.  The size of this
buffer can be adjusted with configure.

=cut

package TWiki::Tasks::Logging;

use base 'Exporter';
our @EXPORT = qw/logFmt logMsg DEBUG INFO WARN ERROR/;
our @EXPORT_OK = qw/%logAlert logLines bprint eprint tprint writeError logHistory/;

use TWiki::Tasks::Globals qw/:logging/;

use TWiki::Func;

our( $logPid, %logAlert ) = ( $$ );

my( $logBufferIndex, @logBuffer ) = ( 0 );

# Save the load-time STDOUT for debug logging iff it's a terminal

open( my $DAEOUT, ">>&STDOUT" ) or die "Can't save STDOUT: $!\n" if( -t STDOUT );

# Logging levels
use constant {
                 DEBUG => 0,    # Only output if daemon debugging (-d)
                 INFO => 1,     # General progress and comfort messages
		 WARN => 2,     # Warnings
		 ERROR => 3,    # Serious errors
	     };

=pod

---++ StaticMethod logFmt( $level, $fmt, @args )
Log a message using a format string
   * =$level= - Message level (severity): one of the constants defined above
   * =@fmt= - sprintf format string
   * =@args= - arguments for sprintf

Expands the format string with sprintf and calls logMsg.

Messages are logged depending on severity and environment.

Child forks redirect logging to the daemon via rpc to ensure sequencing and visibility.

=cut

sub logFmt {
    my $level = shift;
    my $fmt = shift;

    logMsg( $level, sprintf( $fmt, @_ ) );
}

=pod

---++ StaticMethod logMsg( $level, @msg )
Log a message
   * =$level= - Message level (severity): one of the constants defined above
   * =@msg= - Message text (elements are simply concatenated)

Messages are logged depending on severity and environment.

Child forks redirect logging to the daemon via rpc to ensure sequencing and visibility.

=cut

sub logMsg {
    my $level = shift;
    my $msg = join( '', @_ );

    my $stamp = localtime();

    $msg = _curse( $msg ) if( $level == DEBUG && $cliOptions{v} > -1 );

    # Log to disk if possible

    if( $TWiki::Plugins::SESSION ) {
	# Note that the TWiki log routines all add a \n to the end of each message.
	if( $level == DEBUG ) {
	    logLines( "Task[$logPid](D): ", $msg, \&TWiki::Func::writeDebug ) if( $debug );
	} elsif( $level == INFO ) {
	    logLines( "Task[$logPid](I): ", $msg, \&TWiki::Func::writeDebug );
	} elsif( $level == WARN ) {
	    logLines( "Task[$logPid](W): ", $msg, \&TWiki::Func::writeWarning );
	} else {
	    logLines( "Task[$logPid](E): ", $msg, sub { eprint( $stamp, @_ ); } );
	}
    }

    # Forks log to Daemon's buffer because it's permanent and available to status & debug servers
    # Likewise, debug terminal

    if( $forkedTask ) {
# Guaranteed to be loaded since Execute runs the task
#	require TWiki::Tasks::Execute::Rpc;

	TWiki::Tasks::Execute::Rpc::rpCall( 'TWiki::Tasks::Logging::_btlog', $stamp, $level, $msg );
	return;
    }

    _btlog( $stamp, $level, $msg );
}

# ---++ StaticMethod _btlog( $stamp, $level, $msg )
# Actual logging management.  Logs to buffer, terminal
#   * =$stamp= - Timestamp
#   * =$level= - Severity level
#   * =$msg= - Message line
#
# This only executes in _Daemon context

sub _btlog {
    my( $stamp, $level, $msg ) = @_;

    # Log to buffer for status (and debug)

    if( $level == DEBUG ) {
	logLines( "[$logPid] DEBUG: $stamp: ", $msg, \&bprint ) if( $debug );
    } elsif( $level == INFO ) {
	logLines( "[$logPid] INFO:  $stamp: ", $msg, \&bprint );
    } elsif( $level == WARN ) {
	logLines( "[$logPid] WARN:  $stamp: ", $msg, \&bprint );
    } else {
	logLines( "[$logPid] ERROR: $stamp: ", $msg, \&bprint );
    }

    if( $DAEOUT && (!$TWiki::Plugins::SESSION || $debug || $cliOptions{f}) ) {

	# Logging to terminal

        if( $level == DEBUG ) {
            logLines( "Task[$logPid](D) $stamp: ", $msg, \&tprint ) if( $debug );
        } elsif( $level == INFO ) {
            logLines( "Task[$logPid](I) $stamp: ", $msg, \&tprint );
        } elsif( $level == WARN ) {
            logLines( "Task[$logPid](W) $stamp: ", $msg, \&tprint );
        } else {
	    logLines( "Task[$logPid](E) $stamp: ", $msg, \&tprint );
	}
    }
}

=pod

---++ StaticMethod logHistory( $n ) -> $text
Return last n lines of log history from buffer
   * =$n= - number of lines to return, default is all (-1)

May return fewer lines if buffer isn't full.

=cut

sub logHistory {
    my $n = shift || -1;

    my $logBufferSize = $TWiki::cfg{Tasks}{LogBufferSize};
    return "No history\n" unless( $logBufferSize && $logBufferSize > 0 );

    $n = $logBufferSize if( $n < 0 || $n > $logBufferSize );

    my $first = $logBufferIndex - $n;
    $first += $logBufferSize if( $first < 0 );

    my $text = '';
    for( my $l = 0; $l < $n; $l++ ) {
	my $i = ($first + $l) % $logBufferSize;

	$text .= $logBuffer[$i] if( defined $logBuffer[$i] );
    }
    return $text;
}

# ---++ StaticMethod _curse( $msg ) -> $msg
# shorten object dumps in debug messages
#    * =$msg= - mesage text
#
# Named for the mess of bless...
#
# Schedule::Cron has a nasty habit of logging task arguments using Data::Dumper, which produces outrageous amounts of output
# when applied to structures such as TWiki session objects.
#
# This routine parses output to replace dumps of blessed objects with ellipses,

sub _curse {
    my $msg = shift;

    my $mout = '';

    while( $msg =~ s/^(.*?bless\( \{)// ) {
	$mout .= $1;
	my @rest = split( //, $msg );
	my $lvl = 0;
	my $end = 0;
	foreach my $c (@rest) {
	    $end++;
	    last if( $c eq '}' && !$lvl );
	    $lvl++, next if( $c eq '{' );
	    $lvl--, next if( $c eq '}' );
	}
	$mout .= '...}';
	$msg = join( '', @rest[$end..$#rest] );
    }
    $mout .= $msg;
    return $mout;
}

# Low-level output routines for logLines

=pod

---++ StaticMethod tprint( $msg )
Print line to terminal

Stub routine for debugging or session not initialized
Print normally - append the \n that TWiki does.

=cut

sub tprint {
    print $DAEOUT ( $_[0], "\n" ) if( $DAEOUT );
}

=pod

---++ StaticMethod bprint( $msg )
Print line to log buffer
   * =$msg= - line of message

Print normally - append the \n that TWiki does.

=cut

sub bprint {
    my $logBufferSize = $TWiki::cfg{Tasks}{LogBufferSize};

    return unless( $logBufferSize && $logBufferSize > 0 );

    my $msg = shift( @_ ) . "\n";

    $logBuffer[$logBufferIndex++] = $msg;
    $logBufferIndex = $logBufferIndex % $logBufferSize;

    # Notify any log listeners

    foreach my $logger (values %logAlert) {
	$logger->( $msg );
    }
}

=pod

---++ StaticMethod eprint( $msg )
Print line to error log and STDERR
   * =$msg= - line of message

Print normally - append the \n that TWiki does.

=cut

sub eprint {
    my $stamp = shift;
    my $message = shift;

    # Write to the (TWiki) error log

    writeError( $message );

    # STDERR may be logging to e-mail -- or it may be /dev/null (or the webserver's log file)
    # Or, it may be tied to logMsg...
    # If it's tied,  write to the FH established at tie (e.g. email temp file)
    # Otherwise, send to the real STDERR

    if( my $self = tied( *STDERR ) ) {
	print {$self->{fh}} "$stamp: $message\n";
    } else {
	print STDERR "$stamp: $message\n";
    }
}

=pod

---++ StaticMethod writeError( @nessage )
Parallel to TWiki::Func::writeWarning (including TWiki::writeWarning)
   * =$msg= - line of message

(Could be a core function)

=cut

sub writeError {
    # Func::writeError
    my( $message ) = @_;
    $message = "(".caller().") " . $message;
    # TWiki::writeError
    $TWiki::Plugins::SESSION->_writeReport( $TWiki::cfg{ErrorFileName}, $message  );
}

=pod

---++ StaticMethod logLines( $pfx, $msg, $print )
Break multi-line messages apart, adding prefix & removing \n
   * =$pfx= - Message prefix
   * =$msg= - Message, possibly multi-line
   * =$print= - coderef to print each line

Return val.

=cut

sub logLines {
    my( $pfx, $msg, $print ) = @_;

    foreach my $line (split( /\n/, $msg )) {
	$line = "$pfx$line";
	$print->( $line );
    }
}

# ##################################################
#
# Allow file handle to be tied to logging
#
# ##################################################

=pod

---++ ClassMethod TIEHANDLE( *fileHandle, $fhName, $level )
Constructor for a new Logging object
   * =*fileHandle= - File handle to tie
   * =$fhName= - File handle name (STDERR)
   * =$level= - Severity for messages logged to this object (ERROR)

tie *FH, 'FH', Level

Tie file handle to this object

=cut

sub TIEHANDLE {
    my $self = {};

    my $class = shift;
    my $FH = shift || 'STDERR';

    # Save dup of FH so logMsg can write non-recursively.

    open( $self->{fh}, ">&$FH" ) or die "Can't save $FH: $!\n";
    select( (select( $self->{fh} ), $| = 1 )[0] );

    # Flag error level as internal call

    $self->{level} = shift || ERROR;

    return bless( $self, $class );
}

=pod

---++ ObjectMethod UNTIE()
Untie object from handle

=cut

sub UNTIE {
    # untie complains about an extra reference unless this subroutine is defined.
    # So far, the alleged reference to this object hasn't surfaced...

}

=pod

---++ ObjectMethod PRINT( @message )
tied print

=cut

sub PRINT {
    my $self = shift;

    return logMsg( $self->{level}, @_ );
}

=pod

---++ ObjectMethod PRINTF( @message )
tied printf

=cut

sub PRINTF {
    my $self = shift;

    return logFmt( $self->{level}, @_ );
}

=pod

---++ ObjectMethod CLOSE( @message )
tied close

=cut

sub CLOSE {
    my $self = shift;

    return close $self->{fh};
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
