# -*- mode: CPerl; -*-
# TWiki off-line task management framework addon for the TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2011 Timothe Litt <litt at acm dot org>
# License is at end of module.
# Removal of Copyright and/or License prohibited.


use strict;
use warnings;


=pod

---+ package TWiki::Tasks::ScheduleTrigger

Periodic task service of the TASK daemon.

Provides the 'schedule' triggered task type.

Always executed in _Daemon context;

=cut

package TWiki::Tasks::ScheduleTrigger;

our @ISA = qw/TWiki::Tasks/;

use TWiki::Tasks::Globals qw/:schtrigger/;
use TWiki::Tasks::Logging;

=pod

---++ ClassMethod new( $self )
Constructor for a new TWiki::Tasks::ScheduleTrigger object.
   * =$self= - Generic unblessed task hash from TWiki::Tasks->new

N.B. new is invoked by TWiki::Tasks->new, and must not be directly invoked by other code.

---+++ Specialized task parameters
   * =schedule= - *cfgkey* *Required* __cron__ format schedule for activation.  =schedule= is in vixie-cron format, with an optional additional column for seconds.  It can be specified as an configuration item key, in which case it will automagically track changes to that key's value.

---+++ Task activation arguments:
   * =$now= - Current time

---+++ Task description
Schedule-triggered tasks run periodically when the __cron__ schedule condition is satisfied.

_man 5 crontab_ and _perldoc Schedule::Cron_ provide details of the schedule format.

Exceptions are thrown for invalid arguments.

See the generic Task definition for the standard arguments.

=cut

sub new {
    my $class = shift;
    my $self = shift;

    bless $self, $class;

    my $name = $self->{name};
    die "Duplicate task name: $name" if( defined $cronHandle->check_entry($name) );

    my $schedule = $self->_getArgValue( $self->{schedule}, 'schedule' );

    unless( $schedule ) {
        $self->cancel;
        die "No schedule for cron task $self->{name}\n";
    }

    # Subroutine arguments *are* used, despite the simple closure seen here:
    # name - required for Cron::Schedule to find job by name
    # self - used by checkJob and various sanity checks

    my $cronjob = $cronHandle->add_entry( $schedule, {
						      subroutine => sub {
							  return $self->_run( time );
						      },
						      args => [ $name,
								$self,
								$self->{_uid},
							      ],
						     }, );

    logMsg( INFO, "New cron task (job $cronjob): $schedule $name" );

    return $self;
}

# ---++ ObjectMethod cronjob( $selector ) -> retval
# Private method to obtain the Schedule::Cron attributes for a schedule-triggered task.
#
#   * =$selector= - True to return cron entry hash, false to return cron job number.  Ignored in array context.
#
# This information is volatile and not for general use.
#
# In array context, returns ( job#, cron entry hash)
# In scalar context, returns selected value.
#
# On error, returns either undef or (undef,undef)

sub cronjob {
    my $self = shift;
    my $wantqe = shift;

    # Get entry number from scheduler database - this is volatile and changes during the life
    # of a task as other tasks come and go.

    my $cronjob = $cronHandle->check_entry( $self->{name} );
    defined( $cronjob ) or goto RET_ERROR;

    # Name isn't unique in the face of cancellation/re-creation, so check uid

    my $qe = $cronHandle->get_entry( $cronjob );
    defined( $qe ) or goto RET_ERROR;

    $self->{_uid} == $qe->{args}[2] or goto RET_ERROR;

    return ($cronjob, $qe) if( wantarray );

    return $wantqe? $qe : $cronjob;

  RET_ERROR:
    return ( undef, undef ) if( wantarray );
    return undef;
}

=pod

---++ ObjectMethod schedule( $newschedule ) -> $oldschedule
Accessor for the  =schedule= attribute.

   * =$newschedule= - *cfgkey* *Optional* Replacement for current task execution schedule.

Returns the current execution schedule in crontab format.

Replaces the current schedule with $newschedule if =newschedule= is specified.

May throw an exception for invalid argument.

=cut

sub schedule {
    my $self = shift;

    my $old = $self->{schedule};

    return $old unless( @_ );

    # Doesn't make sense to replace if task has been cancelled (and Sched::Cron has no entry)

    return undef if( $self->{_cancelled} );

    my( $schedule ) = @_;

    my( $cronjob, $qe ) = $self->cronjob;
    defined $cronjob && defined $qe or
      die "$self->{name} is not in scheduler database\n";

    $self->_getArgValue( $schedule, 'schedule' );

    unless( $schedule ) {
        die "No schedule for cron job $cronjob $self->{name} (replace)\n";
    }
    my $name = $self->{name};

    $qe->{time} = $schedule;

    defined( $cronHandle->update_entry( $cronjob, $qe ) ) or
	die "Internal error: Cron job $cronjob ($name) replace schedule update failed\n";

    # Work-around for bug in Sched::Cron - force its scheduler to recompute next entry
    $cronHandle->{entries_changed} = 1;

    logMsg( DEBUG, "New schedule for cron job $cronjob $name: $schedule" ) if( $debug );
    $self->{schedule} = $schedule;

    return $old;
}

=pod

---++ ObjectMethod cancel( )
Standard task method to cancel a task.

=cut

sub cancel {
    my $self = shift;

    return 0 if( $self->{_cancelled} );

    # Non-cancelable is a bad idea, but one task is required by Schedule::Cron.

    die "Cancel: $self->{name} is non-cancelable\n" if( $self->{_noncancelable} );

    my $cronjob = $self->cronjob;

    unless( defined $cronjob && defined $cronHandle->delete_entry( $cronjob ) ) {
	$cronjob = '<missing>' unless( defined $cronjob );
	logMsg( WARN, "Unable to cancel cron job $cronjob: $self->{name}" );
	return 0;
    }

    $self->SUPER::cancel( @_ );

    logMsg( DEBUG, "Cancelled cron job $cronjob: $self->{name}" ) if( $debug );

    return 1;
}

=pod

---++ ObjectMethod nextRuntime() -> $time
Computes and returns the next scheduled runtime for a task.

Returns a unix time.

=cut

sub nextRuntime {
    my $self = shift;

    my $qe = $self->cronjob(1);
    return 0 unless( defined $qe );

    my $next = $cronHandle->get_next_execution_time( $qe->{time}, 0 );

    return $next || 0;  # Don't return undef
}

# ---++ ObjectMethod DESTROY
# Destructor
#

sub DESTROY {
    my $self = shift;

    delete $self->{_noncancelable};
    $self->cancel unless( $forkedTask );
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
