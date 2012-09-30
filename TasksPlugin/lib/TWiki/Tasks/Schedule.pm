# -*- mode: CPerl; -*-
# TWiki off-line task management framework addon for the TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2011 Timothe Litt <litt at acm dot org>
# License is at end of module.
# Removal of Copyright and/or License prohibited.


use strict;
use warnings;


=pod

---+ package TWiki::Tasks::Schedule
This module provides task and thread scheduling for the TASK daemon, in conjunction with Schedule::Cron.

It also provides scheduler controls and thread/fork registration functions.

The daemon executes a single unix thread, whose primary path runs from Schedule::Cron, thru this module and back.

Schedule::Cron maintains a queue of schedule-triggered tasks, and executes a call-out to =schedulerService= when
it is idle and would otherwise sleep.  The scheduler service maintains a queue of time-triggered tasks, which it
schedules.  It also runs select() threads for any non-blocking file descriptors that have registered callbacks.

The scheduler service manages daemon shutdown and restart.  It can also suspend and resume task scheduling.
In the =suspend= state, select threads will run, but no tasks will be scheduled.

Code executed from the scheduler thread is said to execute in '_Daemon context' (after the execution queue name used for
tasks directly executed by this thread.)  _Daemon context code runs in the address space of the daemon itself (not a
forked copy).  It must not block, as tasks can only be scheduled (or reaped) by this thread.  Events detected in
_Daemon context generally trigger tasks which execute asynchronously in one of several fork contexts under TWiki::Tasks::Execute
control.

The scheduler thread serves as a synchronization point for many daemon operations.  These include task creation, scheduling and
reaping.  Not as obvious, it also synchronizes fork access to all the daemon's data structures via the RPC mechanism, which runs
as a select thread.  Thus, while externally all daemon operations appear to be (and must be treated as) asynchronous, internally
the daemon is synchronous with respect to data structures.  Select threads are executed synchronously, but must be coded as
non-blocking and deal with maintaining buffers and state for transactions that might require multiple select events.  In that sense,
select threads may be considered asynchronous.

Fork-level scheduling is provided by TWiki::Tasks::Execute, which maintains queues for tasks that are running or ready to run.

=cut

package TWiki::Tasks::Schedule;

use base 'Exporter';
our @EXPORT_OK = qw/schedulerInit schedulerService schedulerRegisterFork
		    schedulerStatus schedulerForkStatus schedulerKillForks
		    schedulerForksBusy
		    suspendScheduling resumeScheduling stopDaemon restartDaemon
		    schedulerRegisterFds
		    @schedulerTimeQueue/;

use TWiki::Tasks::Logging;
use TWiki::Tasks::Globals qw/:schedule/;

use Errno qw(EAGAIN EINTR);
use POSIX qw(:sys_wait_h);

our @schedulerTimeQueue;

my $nextCrontime = 0;
my( $stop, $suspended ) = (0, 0);

my( $reaper, $forkdied, $prevReaper, %forkRegistry ) = ( 'IGNORE', 0 );
my( $rin, $win, $ein ) = ( '', '', '' );
my( $rmin, $wmin, $emin ) = ( 0, 0, 0 );
my( @rwake, @wwake, @ewake );

=pod

---++ StaticMethod schedulerInit()
Initialization for the scheduler

Hookup to Schedule::Cron happened before the startup task was run.  Note that suspend is called before Init.

All that's necessary here is to setup the fork reaper to provide notification of fork exits.

=cut

sub schedulerInit {
    my $prevReaper = $SIG{'CHLD'};
    $reaper = sub {
	              &REAPER();
		      if( $prevReaper && ref $prevReaper eq 'CODE' ) {
			  &$prevReaper();
		      }
		  };
     $SIG{'CHLD'} = $reaper;
}


=pod

---++ StaticMethod schedulerService( $sleepReq, $cron )
Schedule::Cron idle callback
   * =$sleepReq= - Time in seconds until next Schedule::Cron task is scheduled to run
   * =$cron= - The Schedule::Cron object (Ignored because we have the $cronHandle global.)

This is the primary scheduler for the _Daemon context thread.

Schedule::Cron will call this routine whenever it has no jobs to dispatch, expectng us to sleep $sleepReq seconds.
We are permitted to return early - Schedule::Cron assumes that any sleep() may return early and will re-request a
(shorter) sleep in that case.

Several things happen here underneath Schedule::Cron's model:
   * The sleep time is adjusted to allow for any (absolute) time-triggered tasks.
   * We may spin here, servicing just select() threads when told to suspend.
   * Shutdown/restart sequencing is managed

Select threads are run as registered.

Schedule::Cron tasks are not run directly as expected by Schedule::Cron.  Instead, the native job simply triggers a daemon
task via Execute.  The same is true for most events.

Fork reaping is detected via signal, but the actual work happens here.

The continuous operation of this loop is essential to the corect operation of the daemon.  It has been optimized for minimum
overhead in the frequent cases.  No directly-executed thread should block or require significant processing.  All processing
done by a directly-executed thread directly contributes to scheduling latency.

=cut

sub schedulerService {
    my $sleepReq = shift;
#    my( $sleepreq, $cron ) = @_;

    # Save target execution time of next cron task.

    my $now = time;
    $nextCrontime = $now + $sleepReq;

    my( $rout, $wout, $eout );

    # Schedule absolute-time task queue until $nextCrontime; adjust $sleepReq if longer than time to next absolute task.

  RUNQUEUE:
    {
	while( @schedulerTimeQueue && !$suspended ) {
	    my $task = $schedulerTimeQueue[0];
            unless( $task ) {
                shift @schedulerTimeQueue;
                next;
            }
	    my $nextSleep = $task->{runtime} - $now;
	    if( $nextSleep > 0 ) {
		$sleepReq = $nextSleep if( $nextSleep < $sleepReq );
		last;
	    }
	    shift @schedulerTimeQueue;
	    $task->_run( $now );
	    # Account for time spent in task
	    $now = time;
	    $sleepReq = $nextCrontime - $now;
	    $sleepReq = 0 if( $sleepReq < 0 || $cronHandle->{entries_changed} );
	}

	# Schedule select threads until next task's runtime

      SELECT:
	{
	    my( $nfound, $ttg ) = select( $rout=$rin, $wout=$win, $eout=$ein, $sleepReq );
	    if( $nfound ) {
		if( $nfound == -1 ) {
		    unless( $! == EINTR || $! == EAGAIN ) { # Signal delivered => check forks
			die "select() error: $!\n"; # This will be an internal error, such as a stale fd.
		    }
		} else {
		    # For each vector, scan attention bits and call the consumer of each bit that's set.
                    # The wake arrays are no larger than the highest active fd, and the minimum is tracked.
                    # So we need only examine bits from min to the end.  A bit can't be set unless a consumer
                    # is registered.  Note that $xmin can be >= the wake array size when the array is empty.

		    for( my $n = $rmin || 0; $n < @rwake; $n++ ) {
			if( vec( $rout, $n, 1 ) ) {
                            $rwake[$n]->( $n, 'r' );
			}
		    }
		    for( my $n = $wmin; $n < @wwake; $n++ ) {
			if( vec( $wout, $n, 1 ) ) {
			    $wwake[$n]->( $n, 'w' );
			}
		    }
		    for( my $n = $emin; $n < @ewake; $n++ ) {
			if( vec( $eout, $n, 1 ) ) {
			    $ewake[$n]->( $n, 'e' );
			}
		    }
		}
	    }
	    if( $forkdied ) {
		# Clean up fork table and notify Execute to process the queue

		$forkdied = 0;
		# Don't want to delete from hash in signal handler, so do it here
		foreach my $pid (keys %forkRegistry) {
		    unless( $forkRegistry{$pid}{running} ) {
			TWiki::Tasks::Execute::taskExited( $forkRegistry{$pid}{task}, $pid, $forkRegistry{$pid}{status} );
			delete $forkRegistry{$pid};
		    }
		}
	    }

	    if( $suspended ) {
		# We do not want Cron (or absolute time queue) to schedule new jobs
		# a) Shutting down or restarting: need to wait for network writes to complete
		#    and (optionally) for async tasks to exit.
		# b) Management decision to stop scheduling (e.g. for backups)
		#
		# In these cases, we loop here servicing select wakeups

		# $suspended is non-zero if cron job scheduling is suspended for any reason
		# +1 => Hard stop or reset - forks can be killed
		# +2 => Suspended by manager, can resume
		# -1 => Graceful stop or restart - will wait for forks to exit
		#
		# $stop is non-zero if stopping or restarting
		# 0 => Not stopping or restarting (connection close is a poll for busy)
		# 1 => Daemon is stopping
		# 2 => Daemon is restarting (connection close marks fd !FD_CLOEXEC if appropriate)

		if( $suspended < 0 ) { # Graceful shutdown - Don't close net until forks have exited
		    main::scheduleExit( $stop == 2, 0 ); # Restarting, abort
		} elsif( $suspended == 1 ) {
		    main::scheduleExit( $stop == 2, 1 ); # Restarting, abort
		}

		# Small sleep request so we will re-poll shutdown/exit
		$sleepReq = 2;
		redo SELECT;
	    }

	    # Not suspended: return to Cron if time for next job or next job's time might have changed

	    $now = time;
	    last RUNQUEUE if( $now >= $nextCrontime || $cronHandle->{entries_changed} );

	    # Compute time to next cronjob as maximum sleep time.

	    $sleepReq = $nextCrontime - $now;

	    # Run/schedule wakeup for absolute tasks
	    redo RUNQUEUE;
	} # SELECT
    } # RUNQUEUE

    return;
}

=pod

---++ StaticMethod schedulerStatus() -> $text
Return scheduler status

Returns the summary status of the scheduler as a text string.

Intended for internal use, but harmless if called externally.  Output format is not guaranteed.

=cut

sub schedulerStatus {
    return "Task scheduling is suspended" if( $suspended > 0 );
    return sprintf( "Waiting for %d asynchronous tasks to complete", scalar( keys %forkRegistry ) )
      if( $suspended > 0 );

    my $nextRuntime = $nextCrontime;
    for( my $qp = 0; $qp < @schedulerTimeQueue; $qp++ ) {
	my $task = $schedulerTimeQueue[$qp] or next;
        my $nextAbstime = $task->{runtime};
	$nextRuntime = $nextAbstime if( $nextAbstime < $nextCrontime );
        last;
    }

    return "Scheduling tasks: Next due " . (scalar localtime( $nextRuntime ));
}

# ---++ StaticMethod schedulerForkStatus() -> $registryRef
# Private method to deliver forkRegistry to status server
#
# The status server uses the fork registry to display the status of running tasks.
# The data is guaranteed coherrent because the status server runs in _Daemon context.
#
# Not for general use

sub schedulerForkStatus {
    return \%forkRegistry;
}

# ---++ StaticMethod schedulerForksBusy() -> $boolean
# Private method to determine whether any forks are active
#
# This is used by graceful shutdown/restart to determine when to cease operations.
#
# Not for general use
#
# Returns True if any forks still busy.

sub schedulerForksBusy {
    return !!%forkRegistry;
}

# ---++ StaticMethod schedulerKillForks()
# Private method to kill all active forks
#
# Used by shutdown/restart to terminate all child forks.
#
# Not for general use

sub schedulerKillForks {

    foreach my $pid (keys %forkRegistry) {
	kill( 'TERM', $pid ) if( $forkRegistry{$pid}{running} );
    }
    return;
}

=pod

---++ StaticMethod suspendScheduling( $nolog ) -> ( $status, $message )
Suspend task scheduling
   * =$nolog= - Do not log event (internal call)

Administratively suspends task scheduling, e.g. for system backups.  Also used during startup.

Returns true for success, false if already suspended (or restarting).  Also returns message for user.

=cut

sub suspendScheduling {
    my $nolog = shift;

    return (0, "Task scheduling is already suspended\n") if( $suspended );

    $suspended = 2;

    TWiki::Tasks::Execute::suspendScheduling();

    logMsg( INFO, "Daemon is suspending task scheduling" ) unless( $nolog );

    return (1, "Daemon is suspending task scheduling.\n");
}

=pod

---++ StaticMethod resumeScheduling( $nolog ) -> ( $status, $message )
Resume task scheduling
   * =$nolog= - Do not log event (internal call)

Administratively resumes task scheduling if it is suspended.  Also used during startup.

Returns true for success, false if not suspended (or restarting).  Also returns message for user.

=cut

sub resumeScheduling {
    my $nolog = shift;

    return (0, "Task scheduling can not be resumed\n") if( $suspended != 2 );

    $suspended = 0;
    $cronHandle->{entries_changed} = 1; # Force rescheduling due to time loss

    logMsg( INFO, "Daemon is resuming task scheduling" ) unless( $nolog );

    TWiki::Tasks::Execute::resumeScheduling();

    return (1, "Daemon is resuming task scheduling.\n");
}

=pod

---++ StaticMethod stopDaemon( $abort ) ->  ( $status, $message )
Shutdown the daemon
   * =$abort= - True to abort (kill) any running forks.  False to wait for them to complete.

Initiates daemon shutdown.  Always called in _Daemon context, so won't take effect until the next yield to the scheduler.
Callers normally write status to a network connection.  Most of the work is done via the callout to scheduleExit from the
scheduler loop.

User access to this function is thru the internal webserver's /control URI.

Returns true for success, false if already restarting.  Also returns message for user.

=cut

sub stopDaemon {
     my $abort = shift;

    return (0, "Daemon is restarting, stop refused\n") if( $stop == 2 );

    $stop = 1;
    $suspended = $abort? 1 : -1;

    TWiki::Tasks::Execute::flushQueues();

    logMsg( INFO, "Daemon is shutting down " . ($abort? "and aborting running tasks" : "gracefully") );

    return (1, "Daemon is shutting down " . ($abort? "and aborting running tasks" : "gracefully") . "\n");
}

=pod

---++ StaticMethod restartDaemon( $abort ) ->  ( $status, $message )
Restart the daemon
   * =$abort= - True to abort (kill) any running forks.  False to wait for them to complete.

Initiates daemon restart.  Always called in _Daemon context, so won't take effect until the next yield to the scheduler.
Callers normally write status to a network connection.  Most of the work is done via the callout to scheduleExit. from the
scheduler loop

User access to this function is thru the internal webserver's /control URI.

Returns true for success, false if already restarting.  Also returns message for user.

=cut

sub restartDaemon {
    my $abort = shift;

    $stop = 2;
    $suspended = ($abort)? 1 : -1 if( $abort || !$suspended || $suspended > 1 );

    TWiki::Tasks::Execute::flushQueues();

    logMsg( INFO, "Daemon is restarting "  . ($abort? "and aborting running tasks" : "gracefully") );
    if( $abort && $suspended == 1 ) {
	return (2, "Daemon restart initiated; will abort running tasks");
    } else {
	return (2, "Graceful Daemon restart initiated; will wait for running tasks to complete");
    }
}

=pod

---++ StaticMethod schedulerRegisterFork( $pid, $task ) -> $status
Registers a new fork for the reaper

When a task is started as a child fork, it must be registered so that exit processing can be guaranteed.

Care is taken to avoid memory allocation in the signal handler that updates task satus in the forkRegistry.

SIGCHLD recognition must be blocked by caller to prevent a race between fork exit and registration.

=cut

sub schedulerRegisterFork {
    my( $pid, $task ) = @_;

    $forkRegistry{$pid}{running} = 1; # Mark for reaping
    $forkRegistry{$pid}{task} = $task;
    $forkRegistry{$pid}{started} = time();
    $forkRegistry{$pid}{status} = 0;

    logMsg( INFO, "Started $task->{name} as pid $pid" );

    return 1;
}

=pod

---++ StaticMethod REAPER()
Signal handler for SIGCHLD

To avoid interfering with grandchild forks, we only wait for forks that the daemon has explicitly registered.

The exit status is captured and the running state is cleared.  The remaining processing is deferred to the scheduler loop
to ensure proper synchronization.

=cut

sub REAPER {
    local( $!, %!, $?, ${^CHILD_ERROR_NATIVE} );   # don't let waitpid() overwrite current error

    foreach my $pid (keys %forkRegistry) {
	if( $forkRegistry{$pid}{running} ) {
	    my $sts = waitpid( $pid, WNOHANG );
	    if( $sts > 0 ) {
                $forkRegistry{$pid}{status} = $?;
                $forkRegistry{$pid}{running} = 0;
		$forkdied = 1;
	    }
	}
    }
    $SIG{CHLD} = $reaper;  # sysV
}

=pod

---++ StaticMethod schedulerRegisterFds( @list ) -> $status
Manages file descriptor registry for select threads
  * =@list= - triples of ($fd, $mask, &sub) that are to be registered.  An array reference can also be used.

Registers/deregisters callbacks for file descriptor/events.

Non-blocking file descriptors are polled via select in the main scheduler loop.  Registering a file descriptor includes it
in the poll.  Registrations are per fd, and per event.

The elements of a registration triple are:
   * =$fd= - the file descriptor number ($fh->fileno) to be (de-)registered
   * =$mask= - The event(s) for which this callback is to be called.  Prefix with '-' to de-register for an event.
      * =r= - =read= event mask
      * =w= - =write= event mask
      * =e= - =exception= event mask
      * =-= - de-register all events
   * =&sub= - Reference to subroutine to be called on event.  Can be undef if de-registering.  Called with:
      * =$fd= - The file descriptor number that is ready
      * =$m= - One of 'r', 'w', or 'e' indicating which event is ready.

The select event masks are recomputed, along with the minimum and maximum active fd to optimize polling.
We assume (and hope) that there are more polls than registration changes.

=cut

sub schedulerRegisterFds {
    my @desc;
    if( ref( $_[0] ) eq 'ARRAY' ) {
	@desc = @$_[0];
    } else {
	@desc = @_;
    }

    if( $debug ) {
	return 0 if( @desc % 3 );
	for( my $i = 0; $i < @desc; $i += 3 ) {
	    return 0 if( $desc[$i+1] =~ /[^rweRWE-]/ ||
			 !(defined( $desc[$i] ) && $desc[$i] =~ /^\d+$/)  || 
			 (defined $desc[$i+2] && ref( $desc[$i+2] ) ne 'CODE') );
	}
    }

    # For each descriptor that is being registered

    while( @desc ) {
	my( $fd, $msk, $sub ) = splice( @desc, 0, 3 );

	$msk = '-r-w-e' if( $msk eq '-' );

	# Delete callback for events being removed
        #  Remove callback entry & select mask bit
        #  Increase min active fd past this and any additional empty slots (if this was the old min)
        #  Remove any empty slots now at high end of array (if this was the old max)

        if( $msk =~ /-r/ && $fd < @rwake && $rwake[$fd] ) {
            $rwake[$fd] = undef;
            vec( $rin, $fd, 1 ) = 0;
            $rmin++ while( $rmin < @rwake && !$rwake[$rmin] );
            my $max;
            for( $max = $#rwake; $max >= 0; $max-- ) {
                last if( $rwake[$max] );
            }
            $#rwake = $max;
        }
        if( $msk =~ /-w/ && $fd < @wwake && $wwake[$fd] ) {
            $wwake[$fd] = undef;
            vec( $win, $fd, 1 ) = 0;
            $wmin++ while( $wmin < @wwake && !$wwake[$wmin] );
            my $max;
            for( $max = $#wwake; $max >= 0; $max-- ) {
                last if( $wwake[$max] );
            }
            $#wwake = $max;
        }
        if( $msk =~ /-e/ && $fd < @ewake && $ewake[$fd] ) {
            $ewake[$fd] = undef;
            vec( $ein, $fd, 1 ) = 0;
            $emin++ while( $emin < @ewake && !$ewake[$emin] );
            my $max;
            for( $max = $#ewake; $max >= 0; $max-- ) {
                last if( $ewake[$max] );
            }
            $#ewake = $max;
        }
	$msk =~ s/-.//g;

	# Add callbacks for events being added
        #  Decrease minimum active fd if this is the new minimum; set if first entry
        #  Enter callback address, set select mask bit

	if( defined $sub ) {
            if( $msk =~ /r/ ) {
                $rmin = $fd if( $fd < $rmin || !@rwake );
                $rwake[$fd] = $sub;
                vec( $rin, $fd, 1 ) = 1;
            }
            if( $msk =~ /w/ ) {
                $wmin = $fd if( $fd < $wmin || !@wwake );
                $wwake[$fd] = $sub;
                vec( $win, $fd, 1 ) = 1;
            }
            if( $msk =~ /e/ ) {
                $emin = $fd if( $fd < $emin || !@ewake );
                $ewake[$fd] = $sub;
                vec( $ein, $fd, 1 ) = 1;
            }
	} elsif( (1 || $debug) && $msk ) {
	    die "Registering callback with no subroutine\n";
	}
    }

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

