# -*- mode: CPerl; -*-
# TWiki off-line task management framework addon for the TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2011 Timothe Litt <litt at acm dot org>
# License is at end of module.
# Removal of Copyright and/or License prohibited.

use strict;
use warnings;


=pod

---+ package TWiki::Tasks

This implements the native public tasks API for the tasks framework.
It is also the internal base class for all task types.

This package implements the off-line task framework API.  Conceptually, it runs "over" TWiki, providing additional functions.
It can also be considered an execution environment that replaces a webserver, in that it activates tasks which then
operate on TWiki sessions.

Unlike a webserver, the framework can be called from TWiki modules to schedule tasks.  (Similar, perhaps, to MOD_PERL.)
However, tasks in this environment will not be disrupted by a user hitting refresh or changing pages.  It is suitable for
periodic maintenance functions such as the built-in login session expiration.  It is also suitable for a limited form of
batch/background processing, as might be used by an indexing service or format converter.

TWiki::Tasks is present only when executing under the task daemon.  Its presence can be detected using the =Tasks_Daemon=
context variable.

Public functions are aliased into the TWiki::Func namespace for consistency.

Tasks are execution threads triggered by a system event.  The thread is usually a perl subroutine, but external commands can
also be used (with fewer benefits).

Triggering events can be:
   * =schedule= - crontab format schedule  (vixiecron + optional seconds column)
   * =time= - an absolute time
   * =file= - a change to a specific file (including modify, create, delete, etc)
   * =directory= - a change to files in a specific directory
   * =config= - a change to a TWiki configuration parameter

When a triggering event is detected, a task is scheduled for execution.  It receives standard and event-specific parameters.

Each task is associated in an execution queue.  Although any number of execution queues can exist, at most one task can be
executing in each queue at any instant.  Within each queue, tasks are executed in the order that events are detected, which
may not be the order in which they occured due to imprecise detection.  Tasks that do not finish processing an event before
another is detected will be executed for each subsequent  events at the end of their execution queue.  The permitted depth
of the event queue for a task is specified when the task is created.  Execution queues are scheduled independently; if
more than one queue as a task ready, they will be run concurrently.

Tasks are executed in one of 3 environments:
   * =internal fork= - The task's subroutine is run as a fork of the daemon.  It inherits an initialized TWiki session.
   * =command fork= - A shell command is run (_exec_) as a fork of the daemon.
   * =_Daemon context= - The task's subroutine is run directly in the daemon.  It has direct access to the master TWiki session
and the daemon's internal data structures.  Execution blocks all other daemon activity.  Used internally, *not* for general use.

The daemon also maintains a number of internal threads of execution that provide scheduling and other services.  These aren't full
tasks, but can be considered to be executing in _Daemon context.

The execution environment for a task is determined when the task object is created by the =queue= parameter, and by the =sub=
or =command= parameter.

Queue names beginning with _ (underscore) are reserved for internal use.  The _Default queue and all
user queue names provide a fork environment.  The _Daemon queue provides a _Daemon context.  _Default is used when no
queue name is explicitly specified for a task.

Forked tasks have access to the full API - they can create, modify, and cancel themselves or any other task.  This
requires communication with the daemon, which is handled by various forms of magic.  Communication isn't free, and is
serialized within the daemon.  So it is not advisable to repeatedly request the same information or to supply unduly
large arguments.  The daemon regards its clients as trusted components, and does not defend itself against such
denial of service attacks.

Internal forks are of type =TaskExecutionMethod=.  These are user subroutines whose parameters are:
   * =$self= - an opaque handle for their task object
   * =$session= - a reference to the initialized TWiki session
   * =@eventParams= - event-specific parameters.

They return an exit status code (0 == success).  Non-success status is logged.

Command forks that use the API must be coded as perl scripts - but of course can use =system()= or =fork= to run other programs.
They receive arguments as shell-quoted strings.  The first argument is always an opaque string that can be used to obtain
a handle on the running task instance.  Any event-specific parameters follow.  Finally, any parameters on the command line.

When passed to command forks, event-specific parameters are quoted and translated to a form compatible with shell parameters.
Any task handle will be provided as an opaque string.  Any arrayref will be passed as the literal string '[', the array
contents, and ']'.  (E.g.. [1, 2] will be passed as 4 parameters \[ "1" "2" \]).  Similarly, any hashref will be
passed as "key" "value" pairs delimited by '{' and '}'.  Hash keys are sorted.  These encodings can be nested; e.g.
\{ "a" \[ "2" \] \}

All tasks execute with STDOUT and STDERR redirected to a temporary file.  If any output is generated, it may be mailed
to an administrator.

Because the framework has several forms of interactions with external code, and is non-trivial itself, the question of
what interfaces are "public" can appear confusing.  Actually, it's quite simple.  The framework has exactly three public
interfaces for making requests:  TWki::Tasks::new, TWiki::Tasks::getHandle and TWiki::Tasks::getTasklist.  These are aliased
in the TWiki::Func namespace.  In addition, plugins and drivers receive control at their initPlugin and initDriver entry points.
Optionally, plugins and drivers can receive control at their pluginCleanup and driverCleanup entry points if these are defined.
Finally, Plugins and drivers can interact with =configure= through spec files and item checkers.

Except for these, every interface is private to the Framework.  Parameters beginning with _ and any aspect of an otherwise
public interface marked "private" or "not for general use" are also private and subject to change without notice.

Additional detail is provided with each interface.

=cut

package TWiki::Tasks;

use TWiki::Tasks::ConfigTrigger;
use TWiki::Tasks::Execute qw/runTask/;
use TWiki::Tasks::Execute::Rpc qw/rpCall/;
use TWiki::Tasks::Globals qw/:tasks/;
use TWiki::Tasks::Logging;
use TWiki::Tasks::Param;
use TWiki::Tasks::ScheduleTrigger;
use TWiki::Tasks::TimeTrigger;
use TWiki::Tasks::Watchfile;

use Text::ParseWords qw//;

my %taskRegistry;

# Each instantiation of a task has a UID to ensure that RPC matches the intended
# instance.  Note that this is the instance of a task definition - not it's activation
# (which would be it's PID for a forked task, or undefined for a _Daemon queue task.)

use constant {
    UIDMAX =>  2_147_483_647,
};
my $uid = int( rand( UIDMAX ) );

=pod

---++ ClassMethod new( @arglist ) => $handle

Constructor for a new TWiki::Tasks object
   * =@arglist= - list of $parameterName, $value pairs.  The first parameter may be a hashref or arrayref containing these
pairs; in that case, any remaining arguments are added to the hash or array contents.

Every new task is defined with *standard parameters*.  In addition, each =trigger= type defines *specialized parameters* that
apply only to that task type.

Many parameters can be specified as configuration item keys, using the syntax '{My}{Itemkey}'.  If specified in this way, the
parameter's value is taken from the named configuration item.  Further, if the parameter is modifiable at runtime, any change
to the configuration item will be propagated to the task.  If you don't want this magic, include a leading \ in the value; if you
want a leading backslash, double it.  E.g. '\\{foo}' will have the value {foo}, but no magic.  '\\\\a' will have the value 'a'.
Note that except for these cases, backslash encoding is *not* applied to parameters.

---+++ Standard parameters
Parameters marked *Required* must be specified.  Parameters marked *cfgkey* have the magic configuration item behavior
described above.  Parameters marked *cfgkey-ro* can be specified as configuration items when a task is created, but are
not modifiable at runtime.  (To change these, a task must be cancelled and redefined.)

Each parameter has an access method that may be used to retrieve, and in some cases, update its value.  In addition to the
summary provided here, additional  information about each paameter may be found with each access method.

   * =trigger= - *Required* The type of event that triggers execution of this task:
      * =schedule= - A periodic cron-like schedule
      * =time= - An absolute time (runs once)
      * =directory= - Changes within a directory
      * =file= - Changes to a file
      * =config= - Changes to a TWiki configuration item (those items in LocalSite.cfg, managed by configure)
   * =name= - *Required* Name of the task, which must be unique within the caller's package, and may not contain :: or
any of the {}[]()<> or $ characters.
   * =sub= - *TaskExecutionMethod* coderef to be executed when event triggers.  Either =sub= or =command= must be specified.
Standard arguments:
      * =$self= - an opaque handle for their task object
      * =$session= - a reference to the initialized TWiki session
      * Additional event-specific arguments are documented with each trigger type
   * =command= - *cfgkey* shell command to be executed when event triggers.  Either =command= or =sub= must be specified. Standard arguments;
      * =self= - opaque handle of task
      * Shell-encoded event-specific parameters are documented with each trigger type.  Shell encoding is documented above.
   * =queue= - *cfgkey-ro* *Optional* Execution queue name for this task.  Queue names starting with _ are reserved; otherwise
any convenient name can be used.  All tasks assigned to the same queue are executed serially when triggered.  Tasks assigned
to different queues will be executed in parallel.  It is not necessary (or possible) to predefine a queue name; queues appear
when a task is assigned to them.  Two public queue names are defined by the framework:
      * *_Default* - default queue for tasks.  Task will execute as a fork.
      * *_Daemon* - Not for general use.  Task will execute as part of the daemon.
   * =maxrequeue= - *cfgkey* *Optional* If a task's trigger event recurrs before a previous execution has completed, the subsequent
events will be queued up to =maxrequeue= times.  Events beyond =maxrequeue= are dropped, as this indicates a scheduling or system
overload problem.  The default is 1 for most trigger types.  -1 does not limit the event queue depth (but eventually daemon
memory will.)
   * =context= - *Optional* Stored by the daemon, but not used.  May be anything useful to the task - typically a ref.
   * =mailto= - *cfgkey* *Optional* e-mail address to receive any output from this task.  If not specified,
{Tasks}{AdministratorEmail}, then {WebMasterEmail}.  '-none-' if no email is desired.
   * =debug=  - *cfgkey* *Optional* for _Daemon and internal forks, calls the debugger before running task if Daemon is
running -d.  To debug external tasks, simply put -d in the #! switches (and the Daemon need not be running -d).  The
debug argument in the task is ignored for external tasks.  If the external task is not a perl executable, you're on your own.

---+++ Task activation arguments:

Each triggering event causes a new instance of the task to run (usually a fork).  These run serially in the specified queue,
in the order detected (which may not be the order of occurance.)  Small amounts of state may be maintained between instances
in the task's =context= variable; larger amounts of state and state that must persist across bootstraps are the application's
responsibility.

=cut

sub new {
    my $class = shift;

    my @caller = ( _caller =>  (caller())[0] );

    my $self;
    my $t = ref( $_[0] );
    if( $t eq 'HASH' ) {
	$t = shift;
	$self = { @caller, %{$t}, @_ };
    } elsif( $t eq 'ARRAY' ) {
	$t = shift;
	$self = { @caller, @{$t}, @_ };
    } else {
	$self = { @caller, @_ };
    }

    return rpCall( 'TWiki::Tasks->new', $self ) if( $forkedTask );

    my $name = $self->{name} || '';
    die "Invalid task name: $name\n" unless( $name && $name !~ /::/  && $name !~ /[\[\]\(\)\{\}<>]/ );

    $name = "$self->{_caller}::$self->{name}";
    $self->{name} = $name;

    die "Name already in use: $name\n" if( exists $taskRegistry{$name} );

    $self->{_uid} = $uid++ % UIDMAX;
    $self->{_uname} = $self->{name} . $self->{_uid};

    # Temporary blessing to enable magic parameters

    bless $self, $class;

    my $trigger = $self->{trigger} or die "No trigger specified for $name\n";

    $self->_getArgValue( $self->{queue} ||= '_Default', undef );

    if( exists $self->{maxrequeue} ) {
        $self->_getArgValue( $self->{maxrequeue}, 'maxrequeue' );
        $self->{maxrequeue} =~ /^-?\d+$/ or die "maxrequeue: value '$self->{maxrequeue}' is not numeric\n";
    } else {
	$self->{maxrequeue} = 1 unless( $trigger =~ /^(?:directory|file)$/ );
    }

    if( exists $self->{command} ) {
        $self->command( $self->{command}, 'command' );
    } else {
	delete $self->{_cmdprog};
	die "No subroutine specified for $name\n" unless( $self->{sub} && ref( $self->{sub} ) eq 'CODE' );
    }

    if( exists $self->{debug} ) {
        $self->_getArgValue( $self->{debug}, 'debug' );
    }

    $taskRegistry{$name}  = $self;

    # Note that we can be called recursively, since tasks are free to implement services that depend on other tasks.
    # For example: a cron task may have a schedule dependency on a config item, which is monitored by a config task,
    # which may in turn use a cron task to detect changes.  Thus, the task registry must be stable at this point.

    eval {
        if( $trigger =~ 'schedule' ) {
            $self = TWiki::Tasks::ScheduleTrigger->new( $self );
        } elsif( $trigger eq 'time' ) {
            $self = TWiki::Tasks::TimeTrigger->new( $self );
        } elsif( $trigger =~ /^(?:file|directory)$/ ) {
            $self = TWiki::Tasks::Watchfile->new( $self );
        } elsif( $trigger eq 'config' ) {
            $self = TWiki::Tasks::ConfigTrigger->new( $self );
        } else {
            die "Unknown task trigger $trigger for $name\n";
        }
    };
    if( $@ ) {
        $self->cancel;
        die $@;
    }

    $self->isa( __PACKAGE__ ) or
      die "$trigger did not create a " . __PACKAGE__ . " object for $self->{name}\n";

    return $self;
}

=pod

---++ ClassMethod getHandle( $name )
Obtain a handle on a task by name.
   * =$name= - task name or script task handle

The task name defaults to the caller's namespace, although a namespace can be specified.

A script task handle is an opaque string used to pass a task handle to an external program or script.

Returns an opaque handle on the task that will respond to documented methods.

Accesses via an object handle are the only supported means of interacting with a task.
The object handle rarely is of the class of the underlying object.

This is a class method because each underlying object class can have a different getHandle method.

=cut

sub getHandle {
    my $class = shift;
    my $name = shift;

    defined( $name ) or die "getHandle:: No name specifed";

    return rpCall( "${class}->getHandle", $name, _caller => (caller())[0], @_ ) if( $forkedTask );

    my %args = ( _caller => (caller())[0], @_ );

    my $caller = $args{_caller};
    $name = "${caller}::$name" unless( $name =~ /::/ );

    if( $name =~ s/\{(\d+)\}$// ) {
	# Script handle /u unique format names include uid.
	# RPC object resolution includes _uid, which dominates
	$args{_uid} = $1 unless( exists $args{_uid} );
    }

    if( exists $taskRegistry{$name} ) {
	my $task = $taskRegistry{$name};

	if( exists $args{_uid} ) {
	    return $task if( $task->{_uid} == $args{_uid} );
	} else {
	    return $task;
	}
    } else {
	return undef unless( exists $args{_uid} );
    }

    # Caller specified a UID, task could be running but cancelled (thus not registered).
    # This will happen when a forked task cancels itself, then does an RPC referencing itself.
    # Obviously, it can also happen if someone else has a handle on a cancelled task.
    #
    # Name could have been recycled (causing UID mismatch on newer registered task)

    my $uid = $args{_uid};

    foreach (TWiki::Tasks::Execute::getRunningTasks()) {
	return $_ if( $_->{_uid} == $uid && $_->{name} eq $name );
    }
    return undef;
}

=pod

---++ ObjectMethod command( $new ) -> $string
Accessor for the  =command= attribute.

Returns the command string that will activate a task implemented as an external program.

Replaces with $new if specified.

Returns undef if the task is not implemented as an external program.

=command= is parsed using shell quoting rules, and will be sent to the system shell when the task is triggered.

=command= is not valid for _Daemon queue tasks or with a =sub= parameter.

May throw an exception for invalid argument.

=cut

sub command {
    my $self = shift;

    exists $self->{command} or return undef;

    my $old = $self->{command};

    if( @_) {
	die "Both subroutine and external command specified for $self->{name}\n" if( $self->{sub} );
	die "External command illegal in _Daemon queue for $self->{name}\n" if( $self->{queue} eq '_Daemon' );

        my $new = shift;
        $self->_getArgValue( $new, 'command' );

	defined $new && length( $new ) or
	  die "Null command specified for $self->{name}\n";

	my @words = Text::ParseWords::parse_line( '\s+', 1, $new );
	defined $words[0] && length $words[0] or
	  die "No program specified in $new for $self->{name}\n";

	my $prog = (Text::ParseWords::parse_line( '\s+', 0, $words[0] ))[0];
	-x $prog or die "$self->{name}: $prog is not executable\n";

        $self->{command} = $new;
	$self->{_cmdprogfn} = $prog;

	# Save with quotes preserved for shell command line

	$self->{_cmdprog} = shift @words;
	$self->{_cmdargs} = [ @words ];
    }
    return $old;
}

=pod

---++ ObjectMethod context( $new ) -> $old
Accessor for the  =context= attribute.

Replaces context if $new is specified;

Returns previous context.

Context is application-defined; it can be used to pass state from one activation of a task to another.

Context can be a scalar value or a reference.  It should be kept to a reasonable size.  If a reference, it must be
Storable (e.g. the referent can not contain GLOBs, stringified refs as hash keys, FORMLINEs, REGEXPs.)  However, note
that the context does not survive daemon restarts.  For that level of persistence, use files.

=cut

sub context {
    my $self = shift;

    my $old = $self->{context};
    $self->{context} = $_[0] if( @_ );

    return $old;
}

=pod

---++ ObjectMethod debug( $new ) -> $old
Accessor for the  =debug= attribute.

Replaces debug if $new is specified.

Returns previous value.

=debug= is a boolean that will cause the perl debugger to be called before _Daemon and internal forked tasks are dispatched.

=debug= is ignored for external executables.  (Use -d in the $! line for these.)

=cut

sub debug {
    my $self = shift;

    my $old = $self->{debug};

    if( @_ ) {
        my $self->{debug} = shift;
        $self->_getArgValue( $self->{debug}, 'debug' );
    }
    return $old;
}


=pod

---++ ObjectMethod maxrequeue( $new ) -> $old
Accessor for the  =maxrequeue= attribute.

Replaces maxrequeue if $new is specified.  undef defaults.

Returns previous value.

=maxrequeue= is the maximum number of times that a task can appear in an execution queue.  1 means that the task can be 
requeued once while executing.  -1 means unlimited.

=cut

sub maxrequeue {
    my $self = shift;

    my $old = $self->{maxrequeue};

    if( @_ ) {
        my $new = shift;

        $self->_getArgValue( $new, 'maxrequeue' );
        $new = 1 unless( defined $new );
        $new =~ /^-?\d+$/ or die "maxrequeue: value '$new' is not numeric\n";
    }
    return $old;
}


=pod

---++ ObjectMethod mailto( $new ) -> $old
Accessor for the  =mailto= attribute.

Replaces mailto if $new is specified.  Specify '-none-' if no output is desired.
Specify undef or '' if the system default is desired.

Returns previous effective mailto - undef if no output is desired.

=mailto= is the e-mail address to which task output (to STDOUT/STDERR) will be sent.

=cut

sub mailto {
    my $self = shift;

    # This seems awkward, but we check the cfg items for each mail sent.

    my $mailto = $self->{mailto} || $TWiki::cfg{Tasks}{AdministratorEmail};
    $mailto = qq("$TWiki::cfg{WebMasterName}" <$TWiki::cfg{WebMasterEmail}>) unless( $mailto );
    $mailto = undef if( $mailto eq '-none-' );

    if( @_ ) {
        my $new = shift;
        $self->_getArgValue( $new, 'mailto' );
        $new = undef if( defined( $new ) && !length( $new ) );
        $self->{mailto} = $new;
    }

    return $mailto;
}

=pod

---++ ObjectMethod name( format => $format ) -> $name
Accessor for the =name= attribute
   * =$format= desired task name format - =short= is the default
      * =short= - unqualified task name (no package)
      * =full= - fully qualified task name (includes owing package - package of new's caller)
      * =unique= - opaque string naming task instance (varies between new(name), cancel, new(samename)).

Returns task name

=cut

sub name {
    my $self = shift;

    my %args = ( format => 'short', @_ );

    $self->{name} =~ /([^:]*)$/;
    return ($args{format} eq 'unique')? "$self->{name}\{$self->{_uid}\}" :
           ($args{format} eq 'full')? $self->{name} : $1;
}

=pod

---++ ObjectMethod class() -> $class
Accessor for the =class= attribute

Not for general use.

Returns class of actual task object (not class of handle).

=cut

sub class {
    my $self = shift;

    return ref $self;
}

=pod

---++ ObjectMethod rCan( $methodName ) -> $boolean
Determines if the real object _can_ $methodName

Similar to UNIVERSAL::can, but always evaluates real object, not RpcHandle.

Note that unlike UNIVERSAL::can, _rCan_ returns a boolean, *not* a coderef.

Returns true if the real object has a method named $methodName

=cut

sub rCan {
    my( $self, $method ) = @_;

    return $self->can( $method )? 1 : 0;
}

=pod

---++ ObjectMethod rIsa( $className ) -> $boolean
Determines if the real object _isa_ $className

Equivalent to UNIVERSAL::isa, but always evaluates real object, not RpcHandle.

Returns true if the real object is, or is derived from $className

=cut

sub rIsa {
    my( $self, $class ) = @_;

    return $self->isa( $class );
}

=pod

---++ ObjectMethod pid() -> $pid
Obtain pid of a running task

If a task runs as a fork and is running, returns its pid.  There is no guarantee that the task is still running when the
call returns.  However, the value can be used to _kill_ a misbehaving process.

If a task runs on the _Daemon queue and is running, it can only ask about itself - since this is tautological, and
using _kill_ on a _Daemon process is not permissible, undef is returned.

If a task isn't running, undef is returned.

=cut

sub pid {
    my $self = shift;

    return $self->{_pid};
}

=pod

---++ ObjectMethod queue() -> $queue
Accessor for the =queue= attribute

Returns task execution queue name

=cut

sub queue {
    my $self = shift;

    return $self->{queue};
}

=pod

---++ ObjectMethod trigger() -> $trigger
Accessor for the =trigger= attribute

Returns task trigger name

=cut

sub trigger {
    my $self = shift;

    return $self->{trigger};
}

=pod

---++ ObjectMethod cancel( )
Standard task method to cancel a task.

Cancelling a task will prevent future trigger events from activating it, and will de-register its name.

If the task is already running, it will not be aborted, but will disappear when it exits.

Entities with a valid handle on the task can access a task following cancellation, but new handles can not be obtained.
This allows a task to utilize its accessor methods until it exits.

Subclasses ordinarily have a cancel method that releases resources held by the task.  They must ensure that all references
to the task object are released to prevent memory leaks.

=cut

sub cancel {
    my $self = shift;

    return if( $self->{_cancelled} );

    TWiki::Tasks::Param::_updateItemMonitor( $self, undef, undef );

    delete $taskRegistry{$self->{name}};

    # Set _cancelled and handle execution queues

    TWiki::Tasks::Execute::cancel( $self );
}

=pod

---++ ObjectMethod _run( ... ) -> $status
Internal method run in _Daemon context that causes the task object to run.

In the case of the _Daemon queue, this is immediate; forked tasks may be queued.

Any arguments are passed to the task as activation arguments.

The return value is interpreted as a task exit status, but may simply be the queuing status.

This is the only place that Execute::run should be called.  It provides a single place for logging activation events.

This can be subclassed to enable intelligent logging of activation parameters.

=cut

sub _run {
    my $self = shift;

    logMsg( DEBUG, "Queueing $self->{trigger} task $self->{name} on $self->{queue}" ) if( $debug );

    return runTask( $self, @_ );
}

=pod

---++ ObjectMethod _done()
Internal method run in _Daemon context at end of run.

Called in daemon context just before output collected - *Not* in fork context.

Provided for subclasses that need to do specialized end-of-run processing, such as cancelling a task following delivery of a fatal
error notification.

This default method does nothing so that _done can be called for any task.

=cut

sub _done {
#    my $self = shift;

    return;
}


=pod

---++ internal ObjectMethod _getArgValue( $value, $setMethod ) -> $string
Convenience wrapper for TWiki::Tasks::Param::getArgValue, allowing it to be called as an object method.

Used internally by task creation and accessor methods, not for general use.

=cut

*_getArgValue = \&TWiki::Tasks::Param::getArgValue;


=pod

---++ StaticMethod getTaskList( _selectors_ ) -> @taskHandles
Returns list of handles for defined tasks.

Optionally, applies selectors to the list.
   * _selectors_ - list of ($selectorName, $value) pairs.  First may be a hash or array reference, in which case it is 
deferenced to obtain the list, and any subsequent parameters added.

Selector items:
   * =$owner= - Owning package of tasks to be returned.  Default is caller's package.
   * =$class= - Type of tasks to be returned, an =->isa()= test.  Default is '*'.  Not for general use

Selector values can be '*' to select all tasks regardless of the selector's value.  To be selected, a task must match all
selectors.

Returns list of opaque task handles for tasks matching selectors.

The returned list does not include tasks that have been cancelled, but are still executing.

=cut

sub getTaskList {
    my @caller = ( _caller =>  (caller())[0] );

    my $args;
    my $t = ref( $_[0] );
    if( $t eq 'HASH' ) {
	$t = shift;
	$args = { @caller, %{$t}, @_ };
    } elsif( $t eq 'ARRAY' ) {
	$t = shift;
	$args = { @caller, @{$t}, @_ };
    } else {
	$args = { @caller, @_ };
    }

    return rpCall( 'TWiki::Tasks::getTaskList', $args ) if( $forkedTask );

    my $owner = $args->{owner} || $args->{_caller};
    my $class = $args->{class} || '*';

    # Optimize 'return all'

    if( $class eq '*' && $owner eq '*' ) {
	return values  %taskRegistry;
    }

    # Selection requires walking the registry

    my @selected;
    foreach my $name (keys %taskRegistry) {
	my $task = $taskRegistry{$name};

	next unless( defined $task ); # Global destruction only

	push @selected, $task, if( ($class eq '*' || $task->isa( $class )) &&
				   ($owner eq '*' || $name =~ /^$owner::(.+)+$/ &&
				                     $1 !~ /::/) );
    }
    return @selected;
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
