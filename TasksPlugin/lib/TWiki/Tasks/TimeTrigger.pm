# -*- mode: CPerl; -*-
# TWiki off-line task management framework addon for the TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2011 Timothe Litt <litt at acm dot org>
# License is at end of module.
# Removal of Copyright and/or License prohibited.


use strict;
use warnings;


=pod

---+ package TWiki::Tasks::TimeTrigger

Absolute time task service of the TASK daemon.

Provides the 'time' triggered task type.

Always executed in _Daemon context;

=cut

package TWiki::Tasks::TimeTrigger;

our @ISA = qw/TWiki::Tasks/;

use TWiki::Tasks::Globals qw/:timetrigger/;
use TWiki::Tasks::Logging;
use TWiki::Tasks::Schedule qw/@schedulerTimeQueue/;

use Scalar::Util qw/weaken/;

=pod

---++ ClassMethod new( $self )
Constructor for a new TWiki::Tasks::TimeTrigger object.
   * =$self= - Generic unblessed task hash from TWiki::Tasks->new

N.B. new is invoked by TWiki::Tasks->new, and must not be directly invoked by other code.

---+++ Specialized task parameters
   * =runtime= - *cfgkey-ro* Absolute time at which task is to be activated.  May be a standard unix time, or any absolute time specifier supported by =Date::Manip=.
   * =runin= - *cfgkey-ro* Relative time (in seconds) after which task is to be activated.

Either =runtime= or =runin= must be specified.

---+++ Task activation arguments:
   * =$now= - Current time

---+++ Task description
time-triggered tasks run exactly once when the =runtime= arrives (or has past).

_perldoc Date::Manip_  provides details of the allowable runtime formats.

Exceptions are thrown for invalid arguments.

See the generic Task definition for the standard arguments.

=cut

sub new {
    my $class = shift;
    my $self = shift;

    bless $self, $class;

    my $name = $self->{name};

    my $runtime;
    if( exists $self->{runtime} ) {
        $runtime = $self->{runtime};
        die "Invalid runtime for $name\n" unless ( defined $runtime );
        die "'runin' is not compatible with 'runtime' for $name\n" if( exists $self->{runin} );

        unless( $runtime =~ /^\d+$/ ) {
            # Parse complex time specifiers
            require Date::Manip;

            $self->_getArgValue( $runtime, undef );

            $runtime = Date::Manip::UnixDate( Date::Manip::ParseDate( $runtime ), "%s" );
        }
    } elsif( exists $self->{runin} ) {
        $runtime = delete $self->{runin} || 0;
        $runtime = time + $self->_getArgValue( $runtime, undef );
    } else {
        die "No runtime specified for $name\n";
    }
    die "Invalid runtime for $name\n" unless( defined $runtime && $runtime =~ /^\d+$/ && $runtime > 0 );
    $self->{runtime} = $runtime;

    $self->{schedule} = 'Once Only';             # Simplifies status display

    # Insert new task following all queued tasks scheduled for the same runtime or earlier

    my $pos = 0;
    $pos++ while( $pos < @schedulerTimeQueue && $runtime >= $schedulerTimeQueue[$pos]{runtime} );
    splice( @schedulerTimeQueue, $pos, 0, $self );
    weaken( $schedulerTimeQueue[$pos] );

    logMsg( INFO, "New time task: " . (scalar localtime $runtime) . " $name" );

    return $self;
}

# ---++ ObjectMethod _done()
# Standard task method called after execution

sub _done {
    my $self = shift;

    # Task has been removed from scheduler queue
    # Runs just once, so deregister

    $self->SUPER::cancel;

    return;
}

=pod

---++ ObjectMethod cancel( )
Standard task method to cancel a task.

=cut

sub cancel {
    my $self = shift;

    return 1 if( $self->{_cancelled} );

    # Can cancel unless running

    my $status = !$self->{_running};

    # Remove from scheduler queue

    # Will not be on scheduler queue if on execution queue - verify this invariant if $debug

    if( !$self->{_queued} || $debug ) {
	for( my $pos = 0; $pos < @schedulerTimeQueue; $pos++ ) {
            my $task = $schedulerTimeQueue[$pos] or next;
	    if( $task == $self ) {
		splice( @schedulerTimeQueue, $pos, 1 );
		die "Time task $self->{name} on scheduler queue while executing\n" if( $self->{_queued} );
		last;
	    }
	}
    }

    # De-register.
    # Remove from execution queues (unless running)

    $self->SUPER::cancel( @_ );

    if( $status ) {
	logMsg( DEBUG, "Cancelled time job: $self->{name}" ) if( $debug );
	return 1;
    }

    logMsg( DEBUG, "Unable to cancel time job: $self->{name}" ) if( $debug );
    return 0;
}

=pod

---++ ObjectMethod nextRuntime() -> $time
Returns the time at which a task is scheduled to run.

Returns a unix time.

=cut

sub nextRuntime {
    my $self = shift;

    return $self->{runtime};
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
