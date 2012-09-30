# -*- mode: CPerl; -*-
# TWiki off-line task management framework addon for the TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2011 Timothe Litt <litt at acm dot org>
# License is at end of module.
# Removal of Copyright and/or License prohibited.


use strict;
use warnings;


=pod

---+ package TWiki::Tasks::Execute
Execution manager for the TASK daemon

This module manages the execution of tasks.  It maintains the task execution queues, captures and delivers output, and cooperates
with the scheduler and task object as required.

The execution manager provides the execution context for a task based on its assigned queue and type.

Tasks assigned to the _Daemon queue are normally executed in-line by the daemon thread when they are activated.  However, if
scheduling is suspended, they may be queued.  The _Daemon queue can block daemon operations and is intended for internal tasks.
Applications might use this queue to update the master TWiki seesion after initialization, but care must be taken to avoid
unintended consequences.

All other execution queues cause tasks to execute as a fork of the daemon.
   * Tasks with a =sub= parameter execute with the pre-initialized TWiki session in the forked copy of the daemon's address space.
   * Tasks with a =command= parameter =exec= the command and do not benefit from the session.

Queues are created automatically when a task is created that references a queue.  They are destroyed when the last task using a
queue exits.

Each execution queue can have at most one task running, the task at its head.  Thus, all ready tasks assigned to any given
execution queue will execute serially.  However, if more than one execution queue has a ready task, the tasks at the head of
each queue will execute in parallel.

Tasks on the execution queue that have started running are not effected by suspension of scheduling; they can be signaled.

All three environments can access the daemon's public API; _Daemon context tasks directly and the others via a remote procedure
call (RPC) mechanism.

Note that the execution manager does not manage select-threads.

=cut

package TWiki::Tasks::Execute;

use base 'Exporter';
our @EXPORT_OK = qw/runTask/;

use TWiki::Tasks::Execute::ApiServer;
use TWiki::Tasks::Execute::Rpc;
use TWiki::Tasks::Execute::RpcHandle qw/makeRpcHandles/;
use TWiki::Tasks::Globals qw/:execute/;
use TWiki::Tasks::Logging;
use TWiki::Tasks::Schedule qw/schedulerRegisterFork/;

use TWiki::Func;

use Config qw/%Config/;
use Errno;
use Fcntl qw/F_GETFD F_SETFD FD_CLOEXEC/;
use File::Basename;
use File::Temp qw/:seekable/;
use FindBin;
use IO::File;
use IO::Handle;
use IO::Socket;
use POSIX;
use Scalar::Util qw/blessed/;

my( $suspended, $workdir, %sigmap, %execQueue, @daemonQueue ) = ( 0 );

# Map signal names to numbers and numbers to names
{
    my @nums = split( ' ', $Config{sig_num} );
    my @names = split( ' ', $Config{sig_name} );
    while( @nums ) {
	$sigmap{$names[0]} = $nums[0];
	$sigmap{shift(@nums)} = shift(@names);
    }
}

=pod

---++ StaticMethod runTask( $task, @args ) -> $exitStatus
Run a task in response to a trigger event
   * =$task= - Reference to task object
   * =@args= - Task activation arguments

Runs the specified task, providing the specified activation arguments (and some others, depending on the task type.)

Tasks return $exitStatus - that is, 0 for success.  Non-zero will be logged.

Execution might be immediate - in which case the return value of runTask is the task's exit status.

However, any task's execution can be queued (even _Daemon queue tasks).  In that case, runTask returns success.

Because of queuing, any references passed to a task need to be safe an indeterminate time in the future; generally that
means that they should be anonymous or 'static'.

Activation arguments vary by task trigger and are documented with each trigger's new() method.

Note that RPC and command tasks impose restrictions on what arguments can be passed, and may transform arguments so that
they are useful to the task.  E.g. task references become RPC handles, and non-scalars are transformed for shell commands.

=cut

sub runTask {
    my $task = shift;

    my $queue = $task->{queue} or die "No queue for $task->{name}\n";
    return 251 if( $task->{_cancelled} );

    if( $queue ne '_Daemon' ) {
        # Simple case first, enqueue to run as a fork

        # Add activation arguments and check requeue limit if already queued

        my $pending = push @{$task->{_args}}, [ @_ ];
        --$pending unless( $task->{_running} );

        if( $task->{_queued} ) {
            return 0 if( $task->{maxrequeue} < 0 || $pending < $task->{maxrequeue} || $suspended );

            # Backlog is over the limit, discard this activation event.
            logMsg( WARN, "$task->{name} queue limit ($task->{maxrequeue}) exceeded, event lost.\n" );
            pop @{$task->{_args}};
            return 0;
        }

        die "Running but not queued: $task->{name}\n" if( $task->{_running} );

        # Enqueue the task and run queue if this is the head

        $task->{_queued} = 1;

        # N.B. This push may create the queue

        if( push( @{$execQueue{$queue}}, $task ) == 1 ) {
            # First entry, so queue is idle.
            _runQueue( $queue );
        }

        return 0;
    }

    # _Daemon queue task.  Run it here unless scheduling is suspended.

    my $status;

    if( $suspended ) {
        # Must queue _Daemon task when suspended.  We don't enforce requeue limit since this is not the tasks's fault.
        # Always enqueue the activation arguments on the task, but only enqueue the task if it is the first activation.
        if( push( @{$task->{_args}}, [ @_ ] ) == 1 ) {
            push @daemonQueue, $task;
        }
        return 0;
    }

    # Setup to run task

    $workdir = TWiki::Func::getWorkArea( "TasksPlugin" ) unless( defined $workdir );

    {   # Output management scope
        # None of this needs to be registered in %parentFds because we are NOT forking

        $task->{_output} = File::Temp->new( SUFFIX => '.output', DIR => $workdir );
        $task->{_output}->autoflush(1);

        # Arrange to capture any output, while still logging errors and warnings.
        # Autoflush is required because of the dup'd fd between STDOUT and STDERR.

        open( my $DAEOUT, ">>&STDOUT" ) or die "Can't save STDOUT: $!\n";
        untie *STDERR if( tied( *STDERR ) );
        open( my $DAEERR, ">>&STDERR" ) or die "Can't save STDERR: $!\n";

        open( STDOUT, "+>>&" . fileno($task->{_output}) ) or die "Can't connect $task->{name} to output: $!\n";
        open( STDERR, '>>&STDOUT' ) or die "Can't dup $task->{name} stdout: $!";
        select STDERR;
        $| = 1;
        select STDOUT;
        $| = 1;

        tie *STDERR, 'TWiki::Tasks::Logging';

        local( @SIG{'__WARN__', '__DIE__'} );
        $SIG{__WARN__} = sub { logMsg( ERROR,  @_ ) };
        $SIG{__DIE__} = sub {
                                return if( $^S || !defined $^S ); # In an eval or compiling a late use/require
                                logMsg( ERROR,  @_ );
                            };

        unshift @_, $twiki;
        # Driver and plugin simple Cleanup callbacks don't get task id
        unshift @_, $task unless( $task->{_driver} );

        # Apply umask from configure

        my $umask = $TWiki::cfg{Tasks}{Umask};
        $umask = 007 unless( defined $umask );
        $umask = umask( $umask );

        # Setup complete, run the task

        $status = eval {
                           if( $task->{debug} ) {
                               # This can only work if the daemon is running -d
                               # It is ignored otherwise.
                               $DB::single = 2;          # Task debug
                           }
                           $task->{sub}( @_ );
                       };
        if( $@ ) { # STDERR will also capture since logMsg ERROR prints to STDERR
            logMsg( ERROR, "Exception in _Daemon task $task->{name}: $@\n" );
            $status = $! || ($? >> 8) || 254;
        }

        # Post-run cleanup

        umask( $umask );

        close STDOUT;
        untie *STDERR;
        close STDERR;
        open STDOUT, '>>&' . fileno($DAEOUT) or die "Can't restore STDOUT: $!\n";
        open STDERR, '>>&' . fileno($DAEERR) or die "Can't restore STDERR: $!\n";
        select STDERR;
        $| = 1;
        select STDOUT;
        $| = 1;
        tie *STDERR, 'TWiki::Tasks::Logging';
    }

    # Notify task that it has been run.

    $task->_done;

    _deliverOutput( $task );

    # Cron jobs will call checkJob from the scheduler; other types are done here

    unless( $task->{trigger} eq 'schedule' ) {
        TWiki::Tasks::Startup::checkJob( $status, $task->{name}, $task );
    }

    return $status;
}

=pod

---++ StaticMethod _runQueue( $queueName ) -> $success
Run task at the head of a queue as a fork
   * =$queueName= - name of selected queue

Attempts to run the task at the head of the queue, performing some queue maintenance along the way.

Similar to the _Daemon queue tasks handled in runTask (above), output is captured/delivered.

In addition, the environment for forks includes an API (rpc) server.  Command tasks' arguments are transformed.

The parent process simply returns success to the daemon.

The child handle most of its environment setup, and exits.

Post run cleanup is triggered by SIGCHLD when the child exits.

The caller guarantees that _runQueue is only called when the named queue is idle and has a candidate task.

=cut

sub _runQueue {
    my $queue = shift;

    # Find a task to run, handling any pending cancellations and weakened refs

    my $task;
    while( @{$execQueue{$queue}} ) {
        unless( $task = $execQueue{$queue}[0] ) {
            shift @{$execQueue{$queue}};
            redo if( @{$execQueue{$queue}} );
            delete $execQueue{$queue};
            return 0;
        }
        last unless( $task->{_cancelled} );

        # Task has been cancelled.  A running task was removed at exit and so should never be on an execution queue here.
        # Tasks cancelled while waiting to execute should never be marked running.

        shift @{$execQueue{$queue}};
        delete $task->{_queued} or die "Cancelled in $queue but not queued: $task->{name}\n";
        delete $task->{_running} and die "Cancelled in $queue but running: $task->{name}\n";
        redo if( @{$execQueue{$queue}} );
        delete $execQueue{$queue};
        return 0;
    }
    defined $task or die "No task in $queue\n";

    die "Task $task->{name} already running\n" if( $task->{_running} );
    return 0 if( $suspended );

    # Run selected task

    $task->{_running} = 1;

    # Get arguments for this run of task

    my $args = shift @{$task->{_args}};

    # Create a daemon-owned Temp file to hold any ouput, which
    # will be handled by the daemon after fork exits.

    $workdir = TWiki::Func::getWorkArea( "TasksPlugin" ) unless( defined $workdir );

    $task->{_output} = File::Temp->new( SUFFIX => '.output', DIR => $workdir );
    $task->{_output}->autoflush(1);

    my $f = fcntl( $task->{_output}, F_GETFD, 0 ) or die "fcntl: $!\n";
	    fcntl( $task->{_output}, F_SETFD, $f & ~FD_CLOEXEC ) or die "Fcntl: $!\n";

    # Create a socket pair for exporting the Daemon API to the task's fork

    ( $task->{_daeapi}, $task->{_tskapi} ) = IO::Socket->socketpair( AF_UNIX, SOCK_STREAM, PF_UNSPEC ) or die "socketpair: $!\n";
    $parentFds{fileno($task->{_daeapi})} = $task->{_daeapi};
    $task->{_daeapi}->blocking(0);

    $f = fcntl( $task->{_tskapi}, F_GETFD, 0 ) or die "fcntl: $!\n";
	 fcntl( $task->{_tskapi}, F_SETFD, $f & ~FD_CLOEXEC ) or die "Fcntl: $!\n";

    # Create a fork for the task

    # Prevent SIGCHLD before fork is registered, and block signals caught
    # by daemon that will be defaulted in child until %SIG is updated.

    my $daesset = POSIX::SigSet->new;
    my $blocksset = POSIX::SigSet->new(SIGCHLD, SIGHUP, SIGTERM, SIGINT);

    defined sigprocmask( SIG_BLOCK, $blocksset, $daesset ) or
	      die "Can't update daemon signal mask: $!\n";

  FORK:
    {
	my $pid;
	if( $pid = fork ) {
	    # Parent: register fork, setup API server

	    setpgid( $pid, 0 ) or warn "setpgid: $!\n";
	    $task->{_pid} = $pid;
	    schedulerRegisterFork( $pid, $task );
	    close( delete $task->{_tskapi} );

	    $task->{_apiserver} = TWiki::Tasks::Execute::ApiServer->new( $task, $task->{_daeapi} );

	    # Restore signal mask & resume daemon

	    defined sigprocmask( SIG_SETMASK, $daesset ) or
	      die "Can't restore daemon signal mask: $!\n";

	    return 0;
	}

	unless( defined $pid ) {
	    # Parent: fork failed

	    if( $! == EAGAIN ) {
		# Might be better to unwind and schedule for later, but since
		# any other fork would probably fail, we won't.  Perhaps another time.
                #
                # Note that this block the main scheduling loop, which is a bad thing.

		sleep 5;
		redo FORK;
	    } else {
		die "Unable to fork $task->{name}: $!\n";
	    }
	}
    }

    # *** Child ***

    # Breakpoints set here will have parentFds inherited by debugger's xterm processes.  Avoid this if possible.

    # Forked task initialization

    $TWiki::Tasks::Logging::logPid = $$;

    setpgid( 0, 0 ) or warn "setpgid:: $!\n";

    # Apply umask from configure

    my $umask = $TWiki::cfg{Tasks}{Umask};
    $umask = 007 unless( defined $umask );
    umask( $umask );

    # Do not inherit signal handlers

    $SIG{HUP} = 'DEFAULT';
    $SIG{TERM} = 'DEFAULT';
    $SIG{INT} = 'DEFAULT';
    $SIG{PIPE} = 'DEFAULT';
    $SIG{CHLD} = 'DEFAULT';

    $forkedTask = 2;

    # We're still inside an eval back from the parent; going back there would be hopelessly confusing.
    # So there's no point in establishing a __DIE__ handler, but we do need a local eval to catch any setup problems.

    eval {
        # Initialize to no blocked signals (regardless of what the daemon had)

        defined $daesset->emptyset or die "emptyset failed: $!\n";
        defined sigprocmask( SIG_SETMASK, $daesset ) or
          die "Can't initialize task's signal mask: $!\n";
        undef $daesset;
        undef $blocksset;

        # Close file descriptors in child fork - as we usually don't exec anything, it's not automagic
        # There are various approaches to finding all the fds, but none that return the perl FHs.
        # Closing fds out from under the perlio library is not good.  So we track the FHs that
        # the parent has open & close them here.

        foreach my $fd (keys %parentFds) {
            my $fh = $parentFds{$fd};
            if( ref( $fh ) eq 'CODE' ) {
                &$fh( $fd, 0 );
            } else {
                close( $fh );
            }
        }
        undef %parentFds;

        # Breakpoints are safer after this point.

        # Provide API socket to Rpc library

        $TWiki::Tasks::Execute::Rpc::forkedTaskApiSock = $task->{_tskapi};

        $0 = $FindBin::Script . " $task->{name}";
        @ARGV = ();

        # Do not inherit random number seed (Among other reasons, File::Temp)

        eval {
            my $rnd;
            open( $rnd, '<', '/dev/urandom' ) or die "No random source\n";
            my $raw;
            my $n = sysread( $rnd, $raw, 8 );
            close $rnd;
            $n == 8 or die "Not enough randomness\n";

            my $seed = 0;
            while( length $raw ) {
                $seed = ($seed << 8) + ord( $raw );
                $raw = substr( $raw, 1 );
            }
            srand( $seed );
        }; if( @_ ) {
            srand( time ^ ($$ + ($$ << 15)) );
        }

        open( STDIN, '</dev/null' ) or die "Can't read /dev/null: $!";

        # Arrange to capture any output , while still logging errors and warnings.
        # Autoflush is required because of the dup'd fd between STDOUT and STDERR.
        #
        # N.B. Parent has opened _output and parent's desructor will dispose of it.
        # See File::Temp, taskExited and _deliverOutput.

        untie *STDERR if( tied( *STDERR ) );
        close STDOUT;
        close STDERR;
        open( STDOUT, "+>>&" . fileno($task->{_output}) ) or die "Can't connect $task->{name} to output: $!\n";
        close $task->{_output};
        open( STDERR, '>>&STDOUT' ) or die "Can't dup $task->{name} stdout: $!";
        select STDERR;
        $| = 1;
        select STDOUT;
        $| = 1;

        tie *STDERR, 'TWiki::Tasks::Logging';

        $SIG{__WARN__} = sub { logMsg( ERROR,  @_ ) };
#       $SIG{__DIE__} = sub {
#                               return if( $^S || !defined $^S ); # In an eval or compiling a late use/require
#			        logMsg( ERROR,  @_ );
#			    };

        # Catch any bugs where a fork tries to access the scheduler

        undef $cronHandle;

        my $sts;

        if( $task->{_cmdprog} ) {
            # External task - exec

            # Task name, handle on self, arguments for this run, arguments from command line

            my $cmdline = join( ' ',
                                $task->{_cmdprog},
                                _expandArgs( $task, @$args ),
                                @{$task->{_cmdargs}},
                              );

            $ENV{PERL5LIB} = join( ':', @INC );

            # Initialize debugger if it's used by the external task

            if( debugEnabled( $task->{_cmdprogfn} ) ) {
                # It seems to be necessary to create our own debugger tty for exec'd tasks, as otherwise
                # perldb creates a window but doesn't attach to it.  This probably has something to do with /dev/tty
                # being shared, but I haven't puzzled out why it is only unhappy after exec.  Hopefully this can
                # be removed at some point...

                unless( $cliOptions{f}  || $ENV{PERLDB_PIDS} ) {
                    # System daemon, apply requested DebugTerminal options

                    my @envs = split( /\s*\|\s*/, ($TWiki::cfg{Tasks}{DebugTerminal} || '') );
                    my %valid = map { $_ => 1 } @termEnvs;
                    foreach (@envs) {
                        my @env = split( /=/, $_, 2 );
                        @env == 2 && $env[0] && $valid{$env[0]} or die "Invalid {Tasks}{DebugTerminal}\n";
                        $ENV{$env[0]} = $env[1];
                    }
                }
                delete $ENV{PERLDB_PIDS};

                # Make sure API socket is not inherited by debug TTY related forks

                $f = fcntl( $task->{_tskapi}, F_GETFD, 0 ) or die "fcntl: $!\n";
                     fcntl( $task->{_tskapi}, F_SETFD, $f | FD_CLOEXEC ) or die "Fcntl: $!\n";

                # When the daemon is running detached, this will only work if
                # DISPLAY and TERM are set to something reasonable on X-based systems
                # (TERM_PROGRAM under darwin)

                my $tty = getDebugTTY( basename( $task->{_cmdprog} ) );

                # Point debugger to new terminal
                # Don't let it override warning or die handling as that exposes
                # the guts of rpc.  (Set to 1 to debug rpc.)

                if( defined $tty ) {
                    $ENV{PERLDB_OPTS} = "TTY=$tty dieLevel=0 warnLevel=0";
                } else {
                    $task->cancel;
                    die "Unable to create a debugger window, task aborted\n";
                }
                # Inhibit Readline (which causes still to be resolved hangs
                # between Xterm & resize after exec),  resize accesses /dev/tty,
                # it smells like another read is pending.  Not clear why the
                # attempt doesn't time out - we are not blocking alarm signal

                $ENV{PERL5DB}='BEGIN { $DB::rl = 0; $DB::CreateTTY = 3; require \'perl5db.pl\';}';
            }

            # Now that any debugger-related forks have been spawned, export API to new program and any grandchildren
            # (using TWiki::Func or TWiki::Tasks in TWiki::Tasks::Api)

            $ENV{TWikiTaskAPI} = $task->{_tskapi}->fileno;
            $f = fcntl( $task->{_tskapi}, F_GETFD, 0 ) or die "fcntl: $!\n";
                 fcntl( $task->{_tskapi}, F_SETFD, $f & ~FD_CLOEXEC ) or die "Fcntl: $!\n";

            # Allow shell quotes, redirection,etc - we are trusting anyone who can create a task.

            { exec $cmdline };

            $@ = "exec $cmdline failed: $!";
        } else {
            # Internal fork

            # Provide API to any grandchildren (using TWiki::Func or TWiki::Tasks in TWiki::Tasks::Api)

            $ENV{TWikiTaskAPI} = $task->{_tskapi}->fileno;
            $f = fcntl( $task->{_tskapi}, F_GETFD, 0 ) or die "fcntl: $!\n";
                 fcntl( $task->{_tskapi}, F_SETFD, $f & ~FD_CLOEXEC ) or die "Fcntl: $!\n";

            # add system arguments & call

            unshift @$args, $twiki;

            # Driver and plugin simple Cleanup callbacks don't get task id
            # Convert all known object refs in arglist to rpc handles.

            unshift @$args, $task unless( $task->{_driver} );
            makeRpcHandles( @$args );

            $sts = eval {
                if( $task->{debug} ) {
                    # This can only work if the daemon is running -d
                    # It is ignored otherwise.
                    $DB::single = 2;          # Task debug
                }
                $task->{sub}( @$args );
            };
        }
        if( $@ ) {
            logMsg( ERROR, "Exception in $task->{name}: $@\n" );
            $sts = $! || ($? >> 8) || 254;
        } elsif( $sts ) {
            logMsg( ERROR, "$task->{name} returned with error status ($sts)" );
        } else {
            logMsg( INFO, "$task->{name} completed successfully" );
            $sts ||= 0;
        }
        exit $sts;
    };

    logMsg( ERROR, "Exception in setup for $task->{name}: $@\n" );
    exit( $! || ($? >> 8) || 255 );
}

# ---++ StaticMethod _expandArgs( @list )
# Expand argument list for external command tasks
#
# Turns argument list into a form that can be processed by an external command (e.g. shell or perl script)
#
# Task object references become opaque strings suitable for getHandle.
#
# array ref items become (recursively) [ @item ]
#
# Hash ref items become (recusively) { key value ... }, sorted by key to make life slightly more predictable for scripts.
#
# Shell quoting of terminals is done
#
# Returns expanded/quoted argument list

sub _expandArgs {
    my @out;

    foreach (@_) {
	my $ref = ref( $_ );
	if( $ref ) {
	    if( $ref eq 'ARRAY' ) {
		push @out, '\[', _expandArgs( @$_ ), '\]';
	    } elsif( blessed( $_ ) && $_->isa( 'TWiki::Tasks' ) ) {
		push @out, qq("$_->{name}\{$_->{_uid}\}");
            } elsif( $ref eq 'HASH' ) {
                push @out, '\{';
                foreach my $key (sort keys %$_) {
                    push @out, _expandArgs( $key ), _expandArgs( $_->{$key} );
                }
                push @out, '\}';
	    } else {
		die "_expandArgs: $ref is not a supported argument type\n";
	    }
	} else {
            my $val = $_;
            $val =~ s/([\$"\\\`])/\\$1/gms;
	    push @out, qq("$val");
	}
    }
    return @out;
}

# ---++ debugEnabled( $script ) -> $yes
# Determine if an executable is a perl script with -d
#   * =$script= - script path
#
# Requires read access to the script.  Rather ugly because of the odd ways that perl switches are defined.
#
# Reads the #! line and scans the perl switches for -d
#
# This only looks for -d, and does not support -d:debugger.
#
# Returns true if -d is found; false if not

sub debugEnabled {
    my $script = shift;

    # Open script and read #!

    open my $fh, '<', $script or return 0;

    my $line = <$fh>;
    close $fh or return 0;
    chomp $line;

    # Parsing starts after first 'perl', remove  leading junk

    $line && $line =~ s/^#!.*?perl\s+(.*)$/$1/ or return 0;

    return 0 unless( $line );

    # Split words into args

    my @args = split( /\s+/, $line );

    while( @args ) {
	my $arg = shift @args;

	# Skip anything not a switch and stop on --
	next unless( $arg =~ /^-(.)/ );
	return 0 if( $1 eq '-' );
	my $s = $1;

	# Special -* and -space - perl skips for emacs tags
	next if( $s =~ /^[* ]$/ );

	# Split words into characters and discard -
	my @arg = split( //, $arg );
	shift @arg;

	# Scan characters
	# last to skip rest of bundle & get next word
	# next to check next bundled switch
	while( @arg ) {
	    $s = shift @arg;
	    # -d (see V for :debugger, but we aren't smart enough to distinguish)
	    return 1 if( $s eq 'd' );
	    # Single char (bundleable) switches
	    next if( $s =~ /^[acfnpsStTuUvwWX]$/ );
	    # Switch with optional : arg
	    if( $s eq 'V' ) {
		last if( @arg && $arg[0] eq ':' );
		next;
	    }
	    # Takes (possibly optional) attached argument
	    last if( $s =~ /^[0CDFilmMx]$/ );
	    # Requires arg, possibly attached
	    if( $s =~ /^[eI]$/ ) {
		shift @args unless( @arg );
		last;
	    }
	    # Unknown switch, assume bundleable
	    warn "Unknown switch $s in #! line of $script, assuming no argument";
	}
    }
    return 0;
}

# ---++ StaticMethod getDebugTTY( $wname ) -> $tty
# Create a terminal window for a debugger
#    * =$wname= - Name/title for windw
#
# Command tasks that are run -d (with debugging) need an independent terminal window.  This is a platform-dependent, non-trivial
# undertaking, which we attempt for a couple of common platforms.  This is further complicated by the fact that the task to be
# debugged is running under a detached daemon.  This solution has been validated under Linux (Fedora 15).
#
# A common problem for X-windows is X authentication.  Make sure that you have a *current* .Xauthority in the webserver user's
# home directory, and check it's ownership and permissions.  Also, if you run the daemon locally, make sure you are
# actually the webserver user; e.g. sudo -u apache /etc/init.d/TWikiTaskDaemon start
#
# Returns name of terminal

sub getDebugTTY {
    my $wname = shift;

    # Extracted from perl5db.pl, which also supports OS/2, but that isn't
    # convenient because it connects filehandles instead of returning a name.
    #
    # @termEnvs in Startup contains the list of ENV keys that can be specified
    # in configure; update it (and Config.spec) if other keys are referenced here.

    if( defined $ENV{TERM}                       # If we know what kind
                                                 # of terminal this is,
        and $ENV{TERM} eq 'xterm'                # and it's an xterm,
        and defined $ENV{DISPLAY}                # and what display it's on,
      )
    {
	# Create a new Xterm
        #
        # The X authentication process relies on HOME and sometimes the USERNAME (win32) or XAUTHORITY symbols.

        # Various things can go wrong.  Although errors go to STDOUT (and get mailed), these are sufficiently hard to diagnose
        # that a few handstands to get them into the error log are worthwhile.  STDERR is an alias for STDOUT, but STDOUT is
        # open for update so we use it to read any errors.

        seek( STDOUT, 0, SEEK_END ) or die "DebugTTY: seek failed:$!\n";
        my $initialPos = tell( STDOUT );

        # Create an Xterm, having it execute a long sleep to keep it around.  Output the name of the terminal.

	open( XT,
	      qq[3>&1 xterm -title "Perl debugger $$ $wname" -e sh -c 'tty 1>&3 && sleep 10000000' |] ) or return undef;
	my $f = fcntl(XT, F_GETFD, 0 ) or die "DebugTTY: fcntl: $!\n";
	        fcntl( XT, F_SETFD, $f & ~FD_CLOEXEC ) or die "DebugTTY: Fcntl: $!\n";

        # Collect created tty name

	my $tty = <XT>;

        # If any error text was written, collect it from output file and log

        seek( STDOUT, 0, SEEK_END ) or die "DebugTTY: eof seek failed:$!\n";

        if( (my $errorLength = tell(STDOUT)) - $initialPos ) {
            seek( STDOUT, $initialPos, SEEK_SET ) or die "DebugTTY: seek: $!\n";
            my $errorText;
            defined read( STDOUT, $errorText, $errorLength ) or die "DebugTTY: error read: $!\n";
            # Seek required to switch FH back to writing
            seek( STDOUT, 0, SEEK_END ) or die "DebugTTY: restoring seek: $!\n";
            logMsg( ERROR, "DebugTTY: Error creating Xterm: $errorText\n" );
        }

        # If no tty created, kill process

        unless( defined $tty ) {
            close XT;
            return undef;
        }

	chomp $tty;
	return $tty;
    }

    # This has not been validated, but is expected to work - or be close as the perl debugger's version is reported to work.

    if( $^O eq 'darwin'                           # If this is Mac OS X
	     and defined $ENV{TERM_PROGRAM}       # and we're running inside
	     and $ENV{TERM_PROGRAM} eq 'Apple_Terminal' # Terminal.app
	   ) {
	my @script_versions = (
	  [237, <<"__LEOPARD__"],
tell application "Terminal"
    do script "clear;exec sleep 100000"
    tell first tab of first window
        copy tty to thetty
        set custom title to "Perl debugger for $wname"
        set title displays custom title to true
        repeat while (length of first paragraph of (get contents)) > 0
            delay 0.1
        end repeat
    end tell
end tell
thetty
__LEOPARD__

	   [100, <<"__JAGUAR_TIGER__"],
tell application "Terminal"
    do script "clear;exec sleep 100000"
    tell first window
        set title displays shell path to false
        set title displays window size to false
        set title displays file name to false
        set title displays device name to true
        set title displays custom title to true
        set custom title to ""
        copy "/dev/" & name to thetty
        set custom title to "Perl debugger for $wname"
        repeat while (length of first paragraph of (get contents)) > 0
            delay 0.1
        end repeat
    end tell
end tell
thetty
__JAGUAR_TIGER__
			      );

	my($version,$script,$pipe,$tty);

	return unless $version=$ENV{TERM_PROGRAM_VERSION};
	foreach my $entry (@script_versions) {
	    if ($version>=$entry->[0]) {
		$script=$entry->[1];
		last;
	    }
	}
	return unless defined($script);
	return unless open($pipe,'-|','/usr/bin/osascript','-e',$script);
	$tty=readline($pipe);
	close($pipe);
	return undef unless defined($tty) && $tty =~ m(^/dev/);
	chomp $tty;
	return $tty;
    }
    return undef;
}

=pod

---++ ObjectMethod taskExited( $pid, $status )
Process fork exit notification
   * =$pid= - PID of task that exited
   * =$status= - Termination status of task captured by waitpid in $?

Called in _Daemon context when a fork has exited.

Reset the task state.  Collect and deliver any output, release daemon resources allocated to managing this fork, and invoke
any trigger-specific post-run processing.

Remove the task from its queue & start next task for that queue.

=cut

sub taskExited {
    my $task = shift;
    my $pid = shift;
    my $status = shift;

    if( WIFEXITED($status) ) {
        logMsg( (WEXITSTATUS($status)? WARN : DEBUG),
                ucfirst( $task->{trigger} ) . " task $task->{name} $pid exited with status " . WEXITSTATUS($status) . "\n" );
    } elsif( WIFSIGNALED($status) ) {
        logMsg( INFO, ucfirst( $task->{trigger} ) . " task $task->{name} $pid terminated by SIG" .
                                                                         ($sigmap{WTERMSIG($status)} || WTERMSIG($status)) . "\n" );
    }

    my $queue = $task->{queue} or die "No queue for $task->{name}\n";

    # Since we are only running one task per queue, verify that exiting task is at head
    # If we ran several, would have to scan 0 - execution max - and change several other
    # places where we assume only one.

    die "Queue $queue confused: $task->{name} ($pid) not at head\n" unless( $execQueue{$queue}[0] == $task && 
									    delete $task->{_queued} && 
									    delete $task->{_running} && 
									    $pid == delete $task->{_pid} );

    # Release monitoring resources

    $task->{_apiserver}->close(0);

    delete @$task{'_daeapi', '_apiserver'};

    # Remove from queue

    shift @{$execQueue{$queue}};

    # Notify task that it has been run.

    $task->_done;

    _deliverOutput( $task );

    # If shutting down cancel task to de-register and prevent re-running

    $task->cancel if( $suspended == 2 );

    # If task was re-requested while running, re-queue it (at the end for fairness).

    if( @{$task->{_args}} && !$task->{_cancelled}  ) {
	$task->{_queued} = 1;
	push @{$execQueue{$queue}}, $task;
    }

    # If the queue has a task, run it.  Otherwise, remove the queue.

    if( @{$execQueue{$queue}} ) {
	_runQueue( $queue );
    } else {
        delete $execQueue{$queue};
    }
}

=pod

---++ ObjectMethod cancel()
Cancel a task

Called when a task has been cancelled to cleanup execution state.  Cancel semantics are to prevent any future execution, but do
not include aborting a running task.

If task is running, it will be dequeued when it exits since we don't kill a running task.

If it is not running, it is removed from any execution queue.

=cut

sub cancel {
    my $task = shift or return; # Destruction...

    $task->{_cancelled} = 1;

    # If scheduling is suspended && task has been queued on _Daemon queue, remove it

    if( $suspended && $task->{_args} && @{$task->{_args}} && $task->{queue} eq '_Daemon' ) {
        for( my $qpos = 0; $qpos < @daemonQueue; $qpos++ ) {
            my $qe = $daemonQueue[$qpos] or next;
            if( $qe == $task ) {
                splice( @daemonQueue, $qpos, 1 );
                delete $task->{_args};
                return;
            }
        }
        die "Cancelled task $task->{name} should be on daemonQueue but isn't\n";
    }

    # Return unless on execution queue and not running.

    return if( $task->{_running} || !delete $task->{_queued} );

    my $queue = $execQueue{$task->{queue}};
    for( my $qpos = 0; $qpos < @$queue; $qpos++ ) {
        my $qe = $queue->[$qpos] or next;
	if( $qe == $task ) {
	    splice( @$queue, $qpos, 1 );
            delete $execQueue{$task->{queue}} unless( @$queue );
	    return;
	}
    }
    die "Cancelled task $task->{name} marked queued, but not found on $task->{queue} queue\n";
}

=pod

---++ StaticMethod getRunningTasks() -> @list
Returns list of tasks that are running

Some tasks  may have been cancelled or even exited.

Required to allow Tasks to find cancelled tasks that are still running but no longer registered.

Not for general use.

=cut

sub getRunningTasks {
    my @list = @daemonQueue;

    foreach my $queue (values %execQueue) {
	next unless( @$queue );

	my $head = $queue->[0];
	push @list, $head if( $head->{_running} );
    }
    return @list;
}

# ##################################################
#
# Scheduling controls
#
# ##################################################

=pod

---++ StaticMethod suspendScheduling()
Stop taking tasks off the run queues

=cut

sub suspendScheduling {
    $suspended = 1;

    return;
}

=pod

---++ StaticMethod resumeScheduling()
Resume taking tasks off the run queues

Start any queue whose head isn't running.

Run any delayed _Daemon queue tasks

=cut

sub resumeScheduling {
    $suspended = 0;

    # If queues contain tasks, but the head isn't running (due to the suspend), start the queue.  The head may be running
    # if the suspend was short enough that it never stopped.
    #
    # This is the only case where execution of the _Daemon queue isn't immediate...

    while( @daemonQueue ) {
        my $task = shift @daemonQueue;

        while( @{$task->{_args}} ) {
            runTask( $task, @{shift @{$task->{_args}}} );
        }
        delete $task->{_args};
    }

    foreach my $qname (keys %execQueue) {
        my $queue= $execQueue{$qname};
	next unless( @$queue );

	_runQueue( $qname ) unless( $queue->[0]{_running} );
    }

    return;
}

=pod

---++ StaticMethod flushQueues()
Removes all non-running tasks from the execution queues.

Required for clean daemon shutdown.

=cut

sub flushQueues {
    $suspended = 2;

    # We are shutting down/restarting.  Any running tasks will exit normally or via kill.
    # Queued tasks need to be removed so their references go away.

    foreach my $queue (values %execQueue) {
	for( my $i = 0; $i < @$queue; $i++ ) {
	    my $task = $queue->[$i];

	    next if( $task->{_running} );

            # Remove from queue, next task moves into this slot

	    splice( @$queue, $i--, 1 );
            delete $task->{_queued};

	    $task->cancel;
	}
        # No point deleting empty queues as we're shutting down -- we don't have the queue name handy
    }

    return;
}

=pod

---++ ObjectMethod _cleanup( $now ) -> $exitStatus
Cleanup work area by collecting any inactive output files

Called by Internal::_cleanupTask

=cut

sub _cleanup {
    my $self = shift;
#    my $now = shift;

    $workdir = TWiki::Func::getWorkArea( "TasksPlugin" ) unless( defined $workdir );

  FILE:
    foreach my $of ( glob( "$workdir/*.output" ) ) {
	# This task's output is in use (_Daemon 'queue' is not in %execQueue & can't have active tasks/output)
	next if( exists $self->{_output} && $of eq $self->{_output}->filename );

	# See if an executing task claims this file (serialized because taskExited also runs in _Daemon queue)

	for my $queue (values %execQueue) {
	    next FILE if( @$queue && exists $queue->[0]{_output} && $queue->[0]{_output}->filename eq $of );
	}

	# File is an orphan.

	my( $size, $mtime ) = (stat $of)[7,9];

	$of =~ /^(.*$)$/;               # Untaint so -T works
	$of = $1;

	# Attempt to deliver any output contained in the orphan somewhere

	if( $size ) {
	    # Fabricate a minimal "task" for _deliverOutput.

	    my $task = {
			   name => ' stranded task last active ' . scalar( localtime($mtime) ),
			  _output => IO::File->new( $of, '<' ),
		       };

	    # Define mailto by hand since fake task isn't blessed.

	    $task->{mailto} = TWiki::Tasks::mailto( $task );

	    $task->{_output} or next;
	    _deliverOutput( $task );
	}

	unlink $of or logMsg( WARN, "Unable to delete orphaned task output $of: $!" );
    }

    return 0;
}

=pod

---++ ObjectMethod _deliverOutput()
If task generated any output, e-mail it to the administrator

Following the _cron_ model, any output that a task generates on STDOUT or STDERR is e-mailed to the administrator.

If output starts with MIME headers (also Precedence or Importance), they are added to the e-mail headers so that formatted e-mail
can be sent.  All other headers are rejected (will appear in the message body) due to security issues.

Otherwise, the SMTP default Text/Plain, charset=us_ascii Content-Type is used.

=cut

sub _deliverOutput {
    my $task = shift;

    # This should be the only remaining reference to the tempfile handle,
    # so it will be deleted after sending.

    my $output = delete $task->{_output} or return;
    $output->flush();
    ($output->stat)[7] or return;

    $output->seek( 0, SEEK_SET );

    # Look in task first to handle cleanup's fake task

    my $mailto = $task->{mailto} || $task->mailto or return;

    my $message = <<"HEADERS";
To: $mailto
From: "$TWiki::cfg{WebMasterName}" <$TWiki::cfg{WebMasterEmail}>
Subject: TWiki execution of $task->{name}
HEADERS

    # Autodetect MIME headers in case a task produces formatted mail
    # Disallow other headers since webserver user is often trusted by mailer.

    my $inHdrs = 1;

    while(<$output>) {
	if( $inHdrs ) {
	    if( /^(?:MIME-Version|Content-Type|Content-ID|Content-Transfer-Encoding|Content-Description|Precedence|Importance):/i ) {
		$inHdrs = 2;
	    } else {
		if( $inHdrs > 1 ) {
		    $message .= "\n" unless( $message eq "\n" );
		} else {
		    $message .= "Content-Type: text/plain; charset=us_ascii\n\n"
		}
		$inHdrs = 0;
	    }
	}
	$message .= $_;
    }

    # **** This is slow and perhaps should fork an asynchronous task.

    my $error = TWiki::Func::sendEmail( $message );
    logMsg( WARN, "Unable to send task output e-mail\n$message\n" ) if( $error );
}

# ---++ StaticMethod _queuedTaskList() -> $hashRef
# Return execution queues
#
# Used by status generator - perhaps status should be generated here instead.
#
# Definitely not for general use.


sub _queuedTaskList {

    return \%execQueue;
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

The routine getDebugTTY is adapted from xterm_get_fork_TTY and
macosx_get_fork_TTY routines in the perl5db.pl file of the Perl
v5.12.4 distribution.  perl5db.pl is Copyright 1987-2010, Larry Wall
and is licensed under GPL.
