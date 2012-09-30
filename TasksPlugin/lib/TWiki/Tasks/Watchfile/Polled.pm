# -*- mode: CPerl; -*-
# TWiki off-line task management framework addon for the TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2011 Timothe Litt <litt at acm dot org>
# License is at end of module.
# Removal of Copyright and/or License prohibited.


use strict;
use warnings;


=pod

---+ package TWiki::Tasks::Watchfile::Polled

Monitor files and directories service of the TASK daemon: polled driver.

Reference implemention: uses polling, stat & readdir for portability.  Note that some events
may be missed - such as moving a file into and out of it's directory within a polling interval.

This implementation assumes that several tasks don't all watch the same directory.  If this
turns out to be false, it might be better to read directories only once per poll.  That
would be a small matter of bookkeeping.  This is a performance/complexity issue, not a functional
bug.

When available, system-specific drivers can be used for better responsiveness/performance/fidelity.
These drivers should produce very similar results.  One difference might be that while this driver
is likely to only report file create, an integrated filesystem driver might report create and
modify events.  Although not guaranteed, it's most useful to report file modifications on close
(when the file is completely written).  But unix doesn't make promises.

Applications should only rely on the capabilities of this implementation.

=cut

package TWiki::Tasks::Watchfile::Polled;

use base 'TWiki::Tasks::Watchfile';

use TWiki::Tasks;
use TWiki::Tasks::Globals qw/:wfpoller/;
use TWiki::Tasks::Logging;

# The file monitor checker verifies that the modules listed in @USES load successfully.
# It should include modules listed as Optional in MANIFEST, but not required modules.
# The checker parses this statement; it must be a simple assignment and a single line.
#
# This driver has no dependencies on optional modules, but the line ends the checker's scan
# as well as providing a placeholder for future drivers that use this as a reference.

our @USES = qw//;

use File::Spec;
use Scalar::Util qw/weaken/;

my $updir = File::Spec->updir();
my $curdir = File::Spec->curdir();

my %watchingTasks;
my $pollTask;

# Valid monitor keywords for files

my %fileEvents = map { $_ => 1 } qw/attributes creates deletes writes/;

# Valid monitor keywords for directories (refer to files in the directories

my %dirEvents = map { $_ => 1 } qw/attributes creates deletes writes/;

=pod

---++ ClassMethod new( $self ) -> $taskObject
Constructor for a new Watchfile::Polled object
   * =$self= - Generic unblessed task hash from TWiki::Tasks->new

N.B. new is invoked by TWiki::Tasks::Watchfile->new, and must not be directly invoked by other code.

This is an instance of the Watchfile object, which documents the task parameters.

=cut

sub new {
    my $class = shift;

    my $self = shift;

    # Validate support for the requested monitor events

    my $valid = $self->{_watchdir}? \%dirEvents : \%fileEvents;
    foreach my $event (@{$self->{monitor}}) {
	$valid->{$event} or
	  die "$self->{name}: Invalid monitor event: $event\n";
    }
    bless $self, $class;

    # Initialize "last poll" to current state

    $self->{_laststat} = [ stat( $self->{file} ) ];
    $self->{_lastdir} = _readdir( $self->{file}, $self->{_selector} ) if( $self->{_watchdir} );

    # Start the polling task unless it's already active

    unless( %watchingTasks ) {
	$pollTask = TWiki::Tasks->new( trigger => 'schedule',
				       name => 'FileMonitor',
				       schedule => '{Tasks}{PolledEventsSchedule}',
				       sub => \&_watchPollerTask,
				       queue => '_Daemon',
				     );
    }

    # Register new task for polling

    weaken( $watchingTasks{$self->{_uname}} = $self );

    return $self;
}

# ---++ internal TaskExecutionMethod _watchPollerTask( $twiki, $now ) -> $exitStatus
# Schedule-triggered task execution.
#
# Polls file or directory monitored for each task.
# If changes are detected that match a task's monitored events, run the task

sub _watchPollerTask {
    my $self = shift;
#    my( $twiki, $now ) = @_;

    # Scan for changes.  Notify later as callbacks might change hash

    my @notify;
    foreach my $task (values %watchingTasks) {
        next unless( $task );

	my $newstat = [ stat( $task->{file} ) ];
	my $laststat = $task->{_laststat};
	$task->{_laststat} = $newstat;

	if( @$newstat xor @$laststat ) {
	    # Target created or deleted

	    if( $task->{_watchdir} ) {
		# Directory disappeared (Shouldn't appear, but races are possible.  That's bad too.)
		push @notify, [ $task, 'Aborted', $task->{file},
				(@$newstat? "Directory appeared" : "Directory deleted") ];
	    } elsif( @$newstat ) {
		next unless( -f $task->{file} ); # Ignore non-regular file objects
		push @notify, [ $task, 'Created', $task->{file} ] if( $task->{_watching}{creates} );
	    } else {
		push @notify, [ $task, 'Deleted', $task->{file} ] if( $task->{_watching}{deletes} );
	    }
	    next;
	}
	# No change in existence

	next if( !@$newstat );  # Target doesn't exist

	# Check for changes to target.  mtime is a good indicator, but attribute changes don't update it

	if( $newstat->[9] != $laststat->[9] || $task->{_watching}{attributes} ) {
	    if( $task->{_watchdir} ) {
		my $old = $task->{_lastdir};
		my $new = _readdir( $task->{file}, $task->{_selector} );
		$task->{_lastdir} = $new;
		push @notify, _cmpdir( $task, $old, $new );
	    } elsif( -f $task->{file} ) { # Ignore non-regular file objects
		push @notify, _cmpfile( $task, $task->{file}, $laststat, $newstat );
	    }
	    next;
	}
    }

    # Issue all notificatons detected in this pass

    while( @notify ) {
	my $event = shift @notify;

	my $task = shift @$event;

	$task->_abort if( $event->[0] eq 'Aborted' );

	logMsg( DEBUG, "File Monitor: $event->[0] $event->[1] $task->{name}\n" ) if( $debug );
	$task->_run( @$event );
    }

    return 0;
}

=pod

---++ StaticMethod _readdir( $path, $selector ) -> $hashReference
Read a directory and record file names and stat() array
   * =$path= - path of directory being monitored
   * =$selector= - regexp to select files from directory (or undef for all files)

Returns hash of filename => reference to stat array for each monitored file in the directory

=cut

sub _readdir {
    my $path = shift;
    my $selector = shift;

    my $data = {};
    opendir( my $dirh, $path ) or return $data;

    while( readdir( $dirh ) ) {
	next if( /^(?:$updir|$curdir)\z/o );
	next if( defined $selector && !/$selector/ );

	$data->{$_} = [ stat( File::Spec->catfile( $path, $_ ) ) ];
    }
    closedir( $dirh );

    return $data;
}

=pod

---++ StaticMethod r( $old, $new ) -> @notify
Compare two directory snapshots and identify monitored changes
   * =$old= - Previous directory snapshot
   * =$new= - Current directory snapshot

Return list of array references to notification lists: ( task reference, event name, file name, detail )

=cut


sub _cmpdir {
    my $task = shift;
    my $old = shift;
    my $new = shift;

    my $path = $task->{file};

    # $old and $new point to snaphots of (selected) file => mtime

    # Generate status of each file in directory
    # File names are relative to directory (readdir)
    # Status:
    #  1 => Only present in old snapshot
    #  2 => Only present in new snapshot
    #  3 => Present in both

    my %fileStatus = map { $_ => 1 } keys %$old;
    $fileStatus{$_} += 2 foreach keys %$new;

    my @notify;
    while( my( $file, $status ) = each %fileStatus ) {
	my $fn = File::Spec->catfile( $path, $file );

	if( $status == 3 ) {
	    push @notify, _cmpfile( $task, $fn, $old->{$file}, $new->{$file} )
	      if( -f $fn );        # Ignore non-regular file objects
	} elsif( $status == 2 ) {
	    push @notify, [ $task, 'Created', $fn ] if( -f $fn && $task->{_watching}{creates} );
	} else {
	    push @notify, [ $task, 'Deleted', $fn ] if( $task->{_watching}{deletes} );
	}
    }
    return @notify;
}

=pod

---++ StaticMethod _cmpfile( $task, $filename, $oldstat, $newstat ) -> @notify
Compare old and new stat results for a file and notify task of monitored changes
   * =$task= - Reference to task object
   * =$filename= - Name of file
   * =$oldstat= - Previous stat array
   * =$newstat= - Current stat array

N.B. Extended attributes might be useful, but seem too expensive.  See File::ExtAttr;
     or File:Attributes::Extended, neither of which install successfully with current Perl.
     They also are expensive for a polling-based scheme, so extended attributes aren't supported.

Return list of references to notification lists

=cut

sub _cmpfile {
    my( $task, $filename, $oldstat, $newstat ) = @_;

    my @notify;
    push @notify, [ $task, 'Modified', $filename ]
      if( $task->{_watching}{writes} && $oldstat->[9] != $newstat->[9] );      # mtime

    # It's tempting to report which attribute changed, but it's unlikely that a
    # high-performance implementation could do this.  (inotify can't.)

    push @notify, [ $task, 'AttributeChanged', $filename ]
      if( $task->{_watching}{attributes} && ( $oldstat->[2] != $newstat->[2] || # mode
					      $oldstat->[3] != $newstat->[3] || # nlink
					      $oldstat->[4] != $newstat->[4] || # uid
					      $oldstat->[5] != $newstat->[5] || # gid
					      $oldstat->[7] != $newstat->[7] || # size
					      $oldstat->[8] != $newstat->[8] || # atime
					      $oldstat->[9] != $newstat->[9] # mtime
					    ) );
    return @notify;
}

=pod

---++ ObjectMethod _abort( $cancel )
Stop watch, but don't cancel task so it can be notified
   * =$cancel= - called from cancel (don't log as abort)

=cut

sub _abort {
    my $self = shift;

    return if( $self->{_cancelled} || $self->{_aborted} );

    delete $watchingTasks{$self->{_uname}};
    unless( %watchingTasks ) {
        # Removed last watch, stop polling
	if( $pollTask ) {
	    $pollTask->cancel;
            undef $pollTask;
	}
    }

    $self->SUPER::_abort( @_ );
    return;
}

=pod

---++ ObjectMethod cancel( )
Standard task method to cancel a task.

=cut

sub cancel {
    my $self = shift;

    return if( $self->{_cancelled} );

    $self->_abort(1);

    $self->SUPER::cancel( @_ );
}

=pod

---++ ObjectMethod DESTROY
Destructor

=cut

sub DESTROY {
    my $self = shift;

    $self->{_destructor} = 1;
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
