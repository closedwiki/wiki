# -*- mode: CPerl; -*-
# Copyright (c) 2011 Tmothe Litt <litt at acm dot org>
# TWiki off-line task management framework addon for the TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# License is at end of module.
# Removal of Copyright and/or License prohibited.


use strict;
use warnings;


=pod

---+ package TWiki::Tasks::Watchfile

Monitor files and directories service of the TASK daemon.

This is the base class for the =file= and =directory= triggered tasks.  These tasks are triggered (run) when monitored events
occur to a specified file or directory.

As part of startup, this task loads the subclass configured by the system administrator.  The default subclass
=TWiki::Tasks::Watchfile::Polled= implements monitoring by polling for changes on a timed basis.  It is intended to be
system-independent, and is the reference implementation for all subclasses.

More efficient, but system-specific subclasses can be written, such as the =inotify= based =TWiki::Tasks::Watchfile::Inotify=
class for Linux included in the initial distribution.

To ensure application compatibility across all systems, all subclasses must implement the same monitoring functions, and
should keep their behaviors as similar to the reference implementation's as is practical.  However, because the timing of
file system events is inherently unpredictable, and file system monitoring systems vary greatly, applications should be
written to be tolerant of missed events and/or varying timing.

This class handles request setup in =new=, provides accessor methods for the task parameters, and provides task control.

As with all tasks, the application MUST consider the task handle to be opaque, since in addition to the variations caused
by drivers, the base class varies by execution environment.

=cut

package TWiki::Tasks::Watchfile;

our @ISA = qw/TWiki::Tasks/;

use TWiki::Tasks::Globals qw/:watchfile/;
use TWiki::Tasks::Logging;

use File::Spec;

# Load the system-specific driver, defaulting to the generic polled driver

my $driver = $TWiki::cfg{Tasks}{FileMonitor} || 'TWiki::Tasks::Watchfile::Polled';

eval "require $driver;";
if( $@ ) {
    die "Unable to load file monitor: $driver: $@\n";
}
logMsg( DEBUG, "Loaded File Monitor $driver\n" ) if( $debug );

=pod

---++ ClassMethod new( $self ) -> $taskObject

Constructor for a new TWiki::Tasks::Watchfile object.
   * =$self= - Generic unblessed task hash from TWiki::Tasks->new

N.B. new is invoked by TWiki::Tasks->new, and must not be directly invoked by other code.

---+++ Specialized task parameters
   * =trigger= - Both =file= and =directory= triggers are processed by this class.
   * =file= - Name of file or directory to be monitored.  Must be absolute.
   * =monitor= - Reference to an array of event names that the task wants monitored, or a single scalar event name.  One or more of:
      * =attributes= - file attributes change: any of mode, link count, uid, gid, size, access time, modification time.  Extended attributes (such as ACLs, !SeLinux, etc) may or may not be monitored.
      * =creates= - file creation
      * =deletes= - file deletion
      * =writes= - file modification
   * =maxrequeue= - Defaults to -1 (infinite) for directory triggers
   * =selector= - String specifying a regex that selects which files in a directory are monitored.

---+++ Task activation arguments:
   * =eventName= - Name of event detected
      * =AttributeChanged= - Monitored file / file in monitored directory attribute changed.
      * =Created= - Monitored file / file in monitored directory was created
      * =Deleted= - Monitored file / file in monitored directory was deleted
      * =Modified= - Monitored file / file in monitored directory was modified, as indicated by =mtime= change or =write=
      * =Aborted= - The task has been cancelled due to an unrecoverable event.  These include: 
         * A monitored directory is deleted or moved
         * A filesystem containing a monitored directory is unmounted
      * =DataLost= - Event(s) have probably been lost.  In some cases, these events might not have been reported to the task if not lost.  In other cases, events can be lost without this notification.  Consider it a hint.
   * =eventData= - Event-specific data: For =Aborted= and =DataLost= events, string providing more detail.

---+++ Task description
Watchfile tasks are triggered when a filesystem monitor detects specified events.  They can be used to service a work queue
or update a parameter file.

When a file is monitored, it need not exist when the task is created.  If the path does exist, it must not be a directory.

When a directory is monitored, the events are based on files in that directory, not the directory itself.

Non-regular files (e.g. sockets, subdirectories) are not reported for creates/writes/attributes, but may be reported for
deletes (since the object doesn't exist after deletion, the monitor can't tell.)

File renames and moves may be detected as modifications, attribute changes, creates or deletes depending on the filesystem
and/or driver.

Exceptions are thrown for invalid arguments.

See the generic Task definition for the standard arguments.

=cut

sub new {
    my $class = shift;
    my $self = shift;

    $self->_getArgValue( $self->{file}, undef );
    die "No file specified for $self->{name}\n"
      unless( $self->{file} && File::Spec->file_name_is_absolute( $self->{file} ) );

    unless( ref $self->{monitor} ) {
        my $value = $self->_getArgValue( $self->{monitor}, undef );
        $self->{monitor} = [ split( /\s*,\s*/, $value ) ];
    }
    my $events = $self->{monitor};
    die "No events montored for $self->{name} $self->{file}\n" unless( @$events );


    # Ensure that regex problems are detected here, and save compiled version

    $self->{_selector} = qr/$self->{selector}/ if( defined $self->{selector} && length $self->{selector} );

    # Directory watches only track contents, and the directory must exist
    #
    # File watches allow non-existent files (may be created/deleted under watch).
    # Some drivers may implement file watches as directory watches with a selector.

    if( $self->{trigger} eq 'directory' ) {
	-d $self->{file} or
	  die "$self->{file}: not a directory\n";
	$self->{_watchdir} = 1;
 	$self->{maxrequeue} = -1 unless( exists $self->{maxrequeue} );
    } else {
	-e $self->{file} && !-f $self->{file} and
	  die "$self->{file}: not a regular file\n";
	my @path = File::Spec->splitpath( $self->{file} );
	$self->{_filedir} = File::Spec->catdir( @path[0,1] );
	$self->{_filename} = $path[2];
	$self->{maxrequeue} = 1 unless( exists $self->{maxrequeue} );
    }

    # Create a map indicating which events are being monitored

    foreach my $event (@$events) {
	$self->{_watching}{$event} = 1;
    }

    # Invoke driver's routine to initialize and re-bless

    $self = $driver->new( $self );

    return $self;
}

=pod

---++ ObjectMethod maxrequeue( $new ) -> $old
Accessor for the  =maxrequeue= attribute.

Replaces maxrequeue if $new is specified.  undef defaults.  Note that the default differs based on trigger type.

Returns previous value.

=maxrequeue= is the maximum number of times that a task can appear in an execution queue.  1 means that the task can be 
requeued once while executing.  -1 means unlimited.

=cut

sub maxrequeue {
    my $self = shift;

    if( @_ && !defined $_[0] ) {
        return $self->SUPER::maxrequeue( ($self->trigger eq 'directory')? -1 : 1 );
    }

    return $self->SUPER::maxrequeue( @_ );
}

=pod

---++ ObjectMethod file() -> $file
Accessor for the read-only =file= attribute.

Returns monitored file/directory name.

=cut

sub file {
    my $self = shift;

    return $self->{file};
}

=pod

---++ ObjectMethod monitor() -> @list
Accessor for the read-only =monitor= attribute.

Returns keyword array.

=cut

sub monitor {
    my $self = shift;

    return @{$self->{monitor}};
}

=pod

---++ ObjectMethod selector( $new ) -> $old
Accessor for the  =selector= attribute.

Replaces selector if $new is specified, removing it if $new is undef or ''.

Returns previous selector.

May throw an exception if $new is not a valid regex.

=cut

sub selector {
    my $self = shift;

    my $old = $self->{selector};

    if( @_  ) {
	my $selector = shift;

	if( defined $selector && length( $selector ) ) {
	    $self->{_selector} = qr/$selector/;
	    $self->{selector} = $selector;
	} else {
	    delete @$self{'selector', '_selector'};
	}
    }
    return $old;
}

=pod

---++ ObjectMethod status( ) -> $string
Provides status of task.

Primarily useful to determine if a task has been aborted, but not yet cancelled.

=cut

sub status {
    my $self = shift;

    return $self->{_cancelled}? 'cancelled' : ( $self->{_aborted}? 'inactive' : 'active' );
}

=pod

---++ ObjectMethod cancel( )
Standard task method to cancel a task.

=cut

sub cancel {
    my $self = shift;

    return if( $self->{_cancelled} );

    logMsg( DEBUG, "Cancelled watchfile: $self->{name} $self->{file}" ) unless( $self->{_destructor} );

    $self->SUPER::cancel( @_ );
}

=pod

---++ ObjectMethod _run( ... ) -> $status
Standard task method to trigger a task instance.

Log event name/file and pass on.

=cut

sub _run {
    my $self = shift;

    logMsg( DEBUG, "$self->{name}: $_[0] $_[1] \n" ) if( $debug );

    return $self->SUPER::_run( @_ );
}

# ---++ driver ObjectMethod _abort( $cancel )
# Generic Abort watch - error such as watched directory disappearing
#    * =$cancel= - called from cancel (don't log as abort)

sub _abort {
    my $self = shift;
    my $cancel = shift;

    return if( $self->{_cancelled} || $self->{_aborted} );

    $self->{_aborted} = 1;

    logMsg( INFO, "Aborted watchfile: $self->{name} $self->{file}" )
      unless( $cancel || $self->{_destructor} );
}

=pod

---++ ObjectMethod _done()
Standard task method invoked for cleanup after an activation.

If abort was delivered,  cancel task.

=cut

sub _done {
    my $self = shift;

    $self->cancel if( $self->{_aborted} );

    return;
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
