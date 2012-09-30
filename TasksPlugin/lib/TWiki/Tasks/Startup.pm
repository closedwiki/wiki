# -*- mode: CPerl; -*-
# TWiki off-line task management framework addon for the TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (c) 2011 Tmothe Litt <litt at acm dot org>
# License is at end of module.
# Removal of Copyright and/or License prohibited.

use strict;
use warnings;


=pod

---+ package TWiki::Tasks::Startup

Intitalization and startup for the TASKS daemon

This dynamically loaded module is the bootstrap for the daemon proper.

The boot process happens in four phases:

The first phase is the loading of additional modules by perl =use= statements.  This can go several levels deep, and
can be configuration-dependent.  Several modules are mutually-dependent - care has been taken to prevent recursive =use=
loops.

The second phase executes in the context of the start command.  It handles the mechanics of passing required state from
any previous instance, and initialization of Schedule::Cron, which is the basis of the main event loop.  Normally,
Schedule::Cron forks a daemon process, and the start command exits.  (Debugging is a different matter.)

The third phase executes as a Schedule::Cron task.  This phase executes once the initial process has been daemonized and the
final pid is known.  It establishes the environment for executing tasks, including installing the API, initializing the TWiki
session object (which loads plugins), loading application drivers (interfaces to off-line applications), setting up logging, and
starting the daemon's internal tasks.  The final phase of restart processing - resuming any network connections - also happens here.
This phase ends when the Startup task exits (returns to Schedule::Cron).

The fourth phase loads additional modules as events require them.  It has no formal end.

Interface routines required by Schedule::Cron and signal handlers (for debug) complete this module.

TWiki::Tasks defines the task objects and provides the native API for creating and managing them.
Subclasses of TWiki::Tasks provide triggering on several types of evebts.  However, note that the public interface is only thru
TWiki::Tasks.

TWiki::Tasks::Internal contains internal tasks that detect and generate some of the events that trigger tasks.

TWiki::Tasks::Schedule and TWiki::Tasks::Execute schedule and execute tasks once Startup completes.

=cut

package TWiki::Tasks::Startup;

use TWiki::Tasks;
use TWiki::Tasks::Globals qw/:startup/;
use TWiki::Tasks::Internal;
use TWiki::Tasks::Logging qw/:DEFAULT logLines tprint/;
use TWiki::Tasks::Execute;
use TWiki::Tasks::Execute::Rpc qw/rpCall/;
use TWiki::Tasks::Schedule qw/schedulerInit schedulerService schedulerKillForks/;

use Fcntl qw/F_GETFD F_SETFD FD_CLOEXEC/;
use File::Basename;
use FindBin;
use Socket qw/IPPROTO_TCP SOCK_STREAM/;
#use IO::Socket::INET;
use IO::Socket::IP;
use Schedule::Cron;

=pod

---++ StaticMethod StartCmd

Processes the daemon start command.  This routine handles startup phase 1.

Unless debugging, forks the daemon process.

Returns exit status to command script.  Does not return if debugging.

=cut

sub startCmd {
    # Perl debugger uses these for dynamic window creation.
    # Disable them unless running a private daemon (-f) or
    # the debugger is active in the daemon itself.

    @termEnvs = qw/TERM DISPLAY XAUTHORITY TERM_PROGRAM TERM_PROGRAM_VERSION/;

    unless( $cliOptions{f} || $ENV{PERLDB_PIDS} ) {
	delete @ENV{@termEnvs};
    }

    # Schedule::Cron will handle daemonization

    # Schedule Cron tasks are run single-threaded, but Execute will disperse when appropriate.
    #
    # Exceptions in a task will be caught and logged
    # Each task's exit status is checked

    my $cron = Schedule::Cron->new( \&defaultSched, {
                                                     nofork => 1,
                                                     catch => 1,
                                                     after_job => \&checkJob,
                                                     log => sub {
                                                         # Map Schedule::Cron error levels to ours.
                                                         #           0     1      2
                                                         logMsg( ( DEBUG, WARN, ERROR )[$_[0]], $_[1] );
                                                     },
                                                      loglevel => $cliOptions{v},
                                                     nostatus => 1,
                                                     processprefix => $FindBin::Script,
						    } );
    $cronHandle = $cron;

    # Setup signal handlers for status and termination

    $SIG{HUP} = \&sigHUP;
    $SIG{TERM} = \&sigTERM;
    $SIG{INT} = \&sigINT;
    $SIG{PIPE} = 'IGNORE';

    my @net;

    if( @restartFds ) {
	# Restarting, commanding FD & any debug session FDs need to be passed to daemon
	#
	# We're about to fork, so we must clear close-on-exec.  At the same time, get
	# IO::Socket::IP objects, as we'll need them on the other side of the fork.
	#
	# @restartFds is structured as triples of server index, # of fds, and list of fds.
	# The non-fd data is used later, but we have to skip it here.

	my @rs = @restartFds;
	while( @rs ) {
	    my $s = shift @rs;
	    my $n = shift @rs;

	    my @fds = splice( @rs, 0, $n );
	    foreach my $fd (@fds) {
		my $sock = IO::Socket::IP->new_from_fd( $fd, '+<' );
                # new_from_fd doesn't record the socket characteristics that are used later.
                # Reaching into library structures like this is ugly,
                # but these particular symbols are well-known.
                if( !defined $sock->sockdomain ) {
                    my $af = sockaddr_family( getpeername( $sock ) );
                    ${*$sock}{'io_socket_domain'} = $af;
                }
                if( !defined $sock->socktype ) {
                    ${*$sock}{'io_socket_type'} = SOCK_STREAM;
                    ${*$sock}{'io_socket_proto'} = IPPROTO_TCP;
                }
                $parentFds{$fd} = $sock;
		push @net, $sock;
		my $f = fcntl( $sock, F_GETFD, 0 ) or die "fcntl: $!\n";
		fcntl( $sock, F_SETFD, $f & ~FD_CLOEXEC ) or die "Fcntl: $!\n";
	    }
	}
    }

    # Create the startup task, which will run as soon as the Daemon context is established.
    #
    # N.B. First arg of entry is used as an ID, so it must be the task name

    $cron->add_entry( "* * * * * *", { subroutine => \&startupTask, 
				       args => [ __PACKAGE__ . '::Startup',
						 { # Minimal pseudo-task for logging
						  trigger => 'startup',
						  name => __PACKAGE__ . '::Startup',
						  queue => '_Daemon',
						  maxrequeue => 0,
						  _uid => 1,
						 },
						 1, # uid
						 \@net ],
				      } );

    # Setup execution parameters for Schedle::Cron

    my %runopts = (
		   pid_file => $cliOptions{p},
		   detach => 1,
		   sleep => \&schedulerService,
		  );
    if( $cliOptions{f} ) {
	delete $runopts{detach};
	unless( -e $runopts{pid_file} ) {
	    # Allow command line to see -f daemon
	    if( open( my $pf, '>', $runopts{pid_file} ) ) {
		print $pf ( "$$\n" );
		close( $pf );
	    }
	}
    }

    # If debugging, this will never return and will process in the foreground.
    # Normally, it forks and returns leaving us to clean up & report startup.

    my $pid = $cron->run( \%runopts );

    # Daemon has been spawned.  Close our copy of any restart FDs and report new Daemon's pid

    foreach my $fh (@net) {
	$fh->close;
    }

    print "Started Daemon ($pid)\n";

    return 0;
}

# ##################################################
#
# Schedule::Cron interface
#
# ##################################################

# ---++ private StaticMethod defaultSched( @cronjobArgs )
#
# Default entry scheduler.  Should never be called,
# since we never create the type of entry that uses it.

sub defaultSched {
    # An entry exists without a task subroutine
    # We don't ever do this.

    die "Default dispatcher called: @_";
}

=pod

---++ StaticMethod checkJob( $sts, $name, $task, ... )

Run at the end of every task - by Schedule::Cron for cron tasks, and by the execution environment for other task types.

Logs completion status - warning if task returns an error status.

Most tasks are run as forks; for those tasks, the status checked here is the result of enqueueing the task to its
fork queue, not the result of the fork's execution.

   * =$sts= - exit status returned by the task
   * =$name= - the task's name
   * =$task= - reference to the task object

Return value is ignored.

=cut

sub checkJob {
    my $sts = shift;
    my $name = shift;
    my $task = shift;

    $sts = 1 unless( defined $sts );

    if( $task->{queue} eq '_Daemon' ) {
	if( $sts ) {
	    logMsg( WARN, ucfirst( $task->{trigger} ) . " task $name exited with status $sts" );
	} elsif( $debug ) {
	    logMsg( DEBUG, ucfirst( $task->{trigger} ) . " task $name finished successfully" );
	}
    } else {
	if( $sts ) {
	    logMsg( WARN, ucfirst( $task->{trigger} ) . " task $name enqueue failure on $task->{queue}: status $sts" );
	} elsif( $debug ) {
	    logMsg( DEBUG, ucfirst( $task->{trigger} ) . " task $name queued on $task->{queue}" ) if( $sts == 0 && $debug );
	}
    }
}

# ---++ private StaticMethod startupTask( $name, undef, undef, $net )
#
# This raw Sched::Cron task is scheduled for the first event recognized by Schedule::Cron, and handles startup phase 3.
#
# This avoids initialzing the TWiki session for the command shell, as well as providing the usual exception handling/logging.
# At this point we've forked to the daemon process, so the daemon's pid is known.
#
# Initialize the session, enabling all plugins/extensions to schedule their tasks.
#
#    * =$name= - the task's name
#    * =undef= - undocumented arguments required for compatibility with real Daemon task services (such as logging).
#    * =$net= - reference to the array of sockets for connections carried forward from a previous instance.
#
# N.B. This is a raw Sched::Cron task, NOT a Daemon (TaskExecutionMethod) task.  Thus, the $name arg and supplemental arguments.
#      The full Daemon task infrastructure isn't bootstrapped yet - that happens here.
#
# Returns task exit staus

sub startupTask {
    my( $name, undef, undef, $net ) = @_;

    # Update logging pid to reflect Daemonization

    $TWiki::Tasks::Logging::logPid = $$;

    # Cron chdir'd to / in the daemon tradition (so we don't prevent umounts).  This will prevent late requires from
    # working - and as long as we're running we really DO want to hold a reference on the wiki's paths.

    chdir $cwd or die "Can't re-establish $cwd: $!\n";

    logFmt( DEBUG, "Daemon startup task is running%s\n", (@restartFds? ' after restart' : '') );

    # Remove the only entry - the one that called us.  At least one Sched::Cron task must be registered before we return, and
    # at all times thereafter to prevent Sched::Cron from aborting.  This is arguably a misfeature of Sched::Cron, but we
    # satisfy it by starting the Cleanup task.

    $cronHandle->clean_timetable();

    # Suspend scheduling to prevent any other tasks (created from here on) from running until initialization completes.

    TWiki::Tasks::Schedule::suspendScheduling( 1 );

    # Export the API to the TWiki::Func:: namespace for consistency, and to the Foswiki::Func:: namespace for compatibility.
    #
    # Do everything twice to suppress "Name used only once" errors.
    #
    # See also TWiki::Tasks::Execute::Api (for parallel definitions used by external tasks)
               # 1 => class method, 0 => static method
    my @apis = ( 1, newTask => 'new',
		 1, getTaskHandle => 'getHandle',
		 0, getTaskList => 'TWiki::Tasks::getTaskList',
	       );
    while( @apis ) {
	my( $type, $xname, $iname ) = splice( @apis, 0, 3 );
	no warnings 'redefine';
	no strict 'refs';
#       Enable the following two lines + remove the first __END__ in Api.pm for Foswiki API
#  	*{ "Foswiki::Func::$xname" } =
#          *{ "Foswiki::Func::$xname" } =
          *{ "TWiki::Func::$xname" } =
	  *{ "TWiki::Func::$xname" } = $type? sub {
	      return rpCall( "TWiki::Tasks->$iname", @_, _caller => (caller())[0] ) if( $forkedTask );
	      return TWiki::Tasks->$iname( @_, _caller => (caller())[0] );
	  } : sub {
	      return rpCall( $iname, @_, _caller => (caller())[0] ) if( $forkedTask );
	      return &$iname( @_, _caller => (caller())[0] );
	  };
    }

    # Capture Daemon's unique name (Multi-daemon systems exist) - use backlink from Daemon script location

    my $ini =  File::Spec->catfile( $FindBin::RealBin, $FindBin::RealScript . '_init' );

    $daemonName = (-l $ini ? (fileparse( readlink( $ini )))[0] : 'TwikiTaskDaemon');

    schedulerInit();

    # Initialize the session

    # Plugins will register their tasks as they initialize.
    #
    # Caution: NO FORKING allowed until after initialization: init routines that think they need to do this must schedule
    # a task.  (Forking would get semi-initialized twiki & init fds.)  No forked task will be run since scheduling is
    # initially suspended.

    $twiki = TWiki->new( $TWiki::cfg{Tasks}{UserLogin}, undef, {
                                                                command_line => 1,
                                                                Task_Daemon => 1,
                                                               } );
    $TWiki::Plugins::SESSION = $twiki;

    # Intercept STDERR -- N.B. Requires session because otherwise prints to STDERR...
    #
    # Intercepting DIE seems somewhat silly, as we should ALWAYs be in some sort of eval.  But it will catch
    # any problems in Schedule::Cron itself.

    tie *STDERR, 'TWiki::Tasks::Logging';
    $SIG{__WARN__} = sub { logMsg( ERROR,  @_ ) };
    $SIG{__DIE__} = sub {
                            return if( $^S || !defined $^S ); # In an eval or compiling a late use/require
			    logMsg( ERROR,  @_ );
			};

    logMsg( DEBUG, "Wiki session initialized, loading drivers" );

    # Contribs and other external (non-plugin) tasks  don't have plugins to TWiki, so they have drivers that are initialized
    # here.  This is similar to a plugin's initPlugin, except that there's no installWeb. (Topic-based preferences are deprecated.)
    #
    # Find the drivers (analogous to plugins) on disk, then consult the cfg hash to see if it's enabled and if it has a version
    # constraint.

    while( <$main::twikiLibPath/TWiki/Tasks/Tasks/*Task.pm> ) {
	s!^$main::twikiLibPath/(TWiki/.*)\.pm$!$1!;
	s!/!::!g;
	my $module = $_;
	s!^.*:([^:]*)!$1!;
	my $mod = $_;
	$driverRegistry{$mod}{Module} = $module;
	my $modver = $TWiki::cfg{Tasks}{Tasks}{$mod}{Version};

	if( !$TWiki::cfg{Tasks}{Tasks}{$mod}{Enabled} ) {
	    $driverRegistry{$mod}{error} = "Disabled by configure";
	} else {
	    eval
	        "require $module;\n" .
	        ((defined $modver)? "${module}->VERSION($modver);\n" : '') . # Check version if configured
	        "\$driverRegistry{$mod}{Version} = \$${module}::VERSION if( defined \$${module}::VERSION );\n" .
	        "\$driverRegistry{$mod}{Release} = \$${module}::RELEASE if( defined \$${module}::RELEASE );\n" .
	        "\$driverRegistry{$mod}{Description} = \$${module}::DESCRIPTION if( defined \$${module}::DESCRIPTION );\n" .
	        "${module}::initDriver( \$twiki->{topicName}, \$twiki->{webName}, \$TWiki::cfg{Tasks}{UserLogin} )\n" .
                                  "    or die \"$module initialization failed\";\n"
	    ;
	    if( $@ ) {
		$driverRegistry{$mod}{error} = $@;
		logMsg( ERROR, "Unable to load $module: $@" );
	    } else {
		logMsg( INFO, "Loaded task $module" );
	    }
	}
    }

    # Start internal tasks and scan modules/plugins for cleanup tasks

    TWiki::Tasks::Internal::startup;

    # Release any forked tasks and enable scheduling

    TWiki::Tasks::Schedule::resumeScheduling( 1 );

    # Finally, we are initialized  If we are restarting, tell the requestor

    return 0 unless( @restartFds );

    # Restart, report success to controller and any other persistent connections from previous instance.

    logMsg( INFO, "Resuming from restart" );

    require CGI;

    # Reconnect fds inherited from previous instance
    #
    # The list of fds starts with the one that issued the restart command.
    #
    # The server index allows us to associate the fd with the correct server.
    #
    # Each server index is followed by the number of fds, and the fd #s.  This repeats for each server with preserved fds.

    my @rs = @restartFds;

    while( @rs ) {
	my $s = shift @rs;
	my $n = shift @rs;

	my @fds = splice( @rs, 0, $n );
	foreach my $fd (@fds) {
	    my $sock = shift @$net;
	    if( $serverRegistry[$s] ) {
		$serverRegistry[$s]->connect( $sock, 1, ($s == $restartFds[0] && $fd == $restartFds[2]), $cliOptions{R} );
	    } else {
                # Server for inherited fd isn't running; close socket.
                close $sock;
                delete $parentFds{$fd};
            }
	}
    }

    return 0;
}

# ##################################################
#
# Signal handlers - used for debugging.
#
# ##################################################

# ---++ private StaticMethod sigHUP
#
# Activate Perl Debugger.  NOP if not loaded.

sub sigHUP {
    $DB::single = 2;          # sigHUP
}

# ---++ private StaticMethod sigINT
#
# Print status on terminal for ^C.  Use "n" to conveniently kill forks before exiting.

sub sigINT {
    unlink( $cliOptions{p} );

    logMsg( WARN, "Received SIGINT\n" );

    if( $debug ) {
	print "Exiting.  Status at exit:\n";
	logLines( "\t", TWiki::Tasks::StatusServer::statusText( 'text', 'debug' ), \&tprint );
    }
    $DB::single = 2;          # sigINT
    schedulerKillForks();
    exit 1;
}

# ---++ private StaticMethod sigTERM
#
# Exit - not very gracefully

sub sigTERM {

    unlink( $cliOptions{p} );

    logMsg( WARN, "Received SIGTERM\n" );

    $DB::single = 2;          # sigTERM
    schedulerKillForks();
    exit 0;
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
