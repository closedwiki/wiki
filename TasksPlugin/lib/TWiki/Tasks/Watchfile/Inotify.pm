# -*- mode: CPerl; -*-
# TWiki off-line task management framework addon for the TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2011 Timothe Litt <litt at acm dot org>
# License is at end of module.
# Removal of Copyright and/or License prohibited.


use strict;
use warnings;


=pod

---+ package TWiki::Tasks::Watchfile::Inotify

Monitor files and directories service of the TASK daemon: Linux inotify driver.

This driver implements the Watchfile mechanism using Linux's inotify service for lower overhead and better responsiveness.

Although inotify provides some capabilities beyond those of the Watchfile::Polled reference driver, those capabilities are
not exported by this driver.

API exception:  Monitoring file attribute changes with this driver my expose changes to extended attributes, such as SeLinux
or ACLs.  This is unavoidable, however  applications need to be able deal with spurrious notifications and should not rely on
this behavior.

=cut

package TWiki::Tasks::Watchfile::Inotify;

use base 'TWiki::Tasks::Watchfile';

use TWiki::Tasks::Globals qw/:inotify/;
use TWiki::Tasks::Logging;
use TWiki::Tasks::Schedule qw/schedulerRegisterFds/;

# The file monitor checker verifies that the modules listed in @USES load successfully.
# It should include modules listed as Optional in MANIFEST, but not required modules.
# The checker parses this statement; it must be a simple assignment and a single line.

our @USES = qw/Linux::Inotify2/;

use File::Spec;
use Linux::Inotify2;

my $updir = File::Spec->updir();
my $curdir = File::Spec->curdir();

my %fileEventMap = (
		    attributes => IN_ATTRIB,
		    creates => IN_CREATE | IN_MOVED_TO,
		    deletes => IN_DELETE | IN_MOVED_FROM,
		    writes => IN_CLOSE_WRITE,
		   );
my %dirEventMap = (
		   attributes => IN_ATTRIB,
		   creates => IN_CREATE | IN_MOVED_TO,
		   deletes => IN_DELETE | IN_MOVED_FROM,
		   writes => IN_CLOSE_WRITE,
		  );

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

    # Regardless of the watch type, we watch directories to ensure that we
    # can monitor target file creation/deletion.

    my $mask = IN_DELETE_SELF | IN_MOVE_SELF | IN_ONLYDIR;        # IN_DONT_FOLLOW
    my $map = $self->{_watchdir}? \%dirEventMap : \%fileEventMap;
    foreach my $event (@{$self->{monitor}}) {
	exists $map->{$event} or
	  die "$self->{name}: Invalid monitor event: $event\n";
	$mask |= $map->{$event};
    }

    my $file;
    if( $self->{_watchdir} ) {
	$file = $self->{file};
    } else {
	$file = $self->{_filedir};
    }

    bless $self, $class;

    # Each task has a unique inotify object because only one watch object per inotify can
    # monitor a given directory.  We may have several tasks watching one directory...

    my $inotify = Linux::Inotify2->new() or
      die "Unable to obtain Inotify object: $!\n";

    $inotify->blocking( 0 );

    my $fd = $inotify->fileno;
    $self->{_fd} = $fd;

    # Inotify doesn't use standard file handles, but we need to close the fd when a child is forked and on restart.
    # The sub registered here will take care of that.
    #
    # We don't want to cancel the watch, because that would also kill it in the parent process.
    # Deleting the $self reference on the inotify object will cause the Inotify destructor to run & close the FD.

    $parentFds{$fd} = sub {
                          # my $fd = shift;
                          # my $restarting = shift;
                            delete $self->{_inotify};
                          };

    schedulerRegisterFds( $fd, 'r', sub {
                                            my $count = $self->{_inotify}->poll();
                                            logMsg( DEBUG, "$count events delivered by inotify\n" ) if( $debug );
                                        } );
    $self->{_inotify} = $inotify;

    defined $inotify->watch( $file, $mask,
                             sub {
                                     my $event = shift;
				     $self->_notify( $event );
				 }
                           ) or die "Watch failed for $self->{file}: $!\n";

    return $self;
}

=pod

---++ ObjectMethod _notify( $event )
Notify task of an inotify event
   * =$event= - Inotify2 event object

Decodes the event provided by inotify and runs the task if appropriate.

The following table maps inotify bits to the watchfile keywords.  See also the validation tables, above.

The enabled events are (a) useful and (b) detectable by Watchfile::Polled.  Do not add inotify events that fail these criteria.

Not for general use.

=cut


my @events = (
	      # Bit                 Report Key          Monitor Key
	      # ---------           -----------         -----------
#	      IN_ACCESS() =>        'Accessed',         # Data read
#	      IN_MODIFY() =>        'Modified',         # Data write
	      IN_ATTRIB() =>        'AttributeChanged', 'attributes',
	      IN_CLOSE_WRITE() =>   'Modified',         'writes',
#	      IN_CLOSE_NOWRITE() => 'Closed',
#	      IN_OPEN() =>          'Opened',
	      IN_MOVED_FROM() =>    'Deleted',          'deletes',
	      IN_MOVED_TO() =>      'Created',          'creates',
	      IN_CREATE() =>        'Created',          'creates',
	      IN_DELETE() =>        'Deleted',          'deletes',
	      #IN_ALL_EVENTS()
	     );

sub _notify {
    my $task = shift;
    my $event = shift;

    my $mask = $event->mask & ~( IN_ONESHOT |IN_ONLYDIR | IN_DONT_FOLLOW | IN_MASK_ADD );

    if( $mask & IN_Q_OVERFLOW ) {
	$task->_run( 'DataLost', $task->{file}, "Kernel inotify event queue overflow" );
    }

    # Check for events that cancel watch.  Since we're always watching the directory,
    # all of these map to aborting the task.  These are DELETE_SELF (dir deleted),
    # UNMOUNT (file system unmounted); IGNORED (umount or file deleted).  Moving the
    # directory doesn't make sense, so it's included too.

    if( $mask & (IN_DELETE_SELF | IN_MOVE_SELF | IN_UNMOUNT | IN_IGNORED) ) {
	$task->_abort;
	$task->_run( 'Aborted', $task->{file}, 
		   (($mask & IN_DELETE_SELF)? "Directory deleted" :
		    (($mask & IN_MOVE_SELF)? "Directory was moved" :
		     "File system was unmounted" ) )
		   );
	return;
    }

    # Events on the directory itself don't cause task notification.
    # These are things like CLOSE and ATTRIB on the directory, which can  be
    # caused by reading or touching the directory... Inotify won't lett us see
    # these events for files without enabling them for the directory.

    return if( $mask & (IN_ISDIR) );

    my $fullname = $event->fullname;

    # For directories, we exclude events referencing files not matched by the user's selector
    # For files, exclude events for other files.

    if( $task->{_watchdir} ) {
	my $name = $event->name;
	return if( $name =~ /^(?:$updir|$curdir)\z/o ||
		   exists $task->{_selector} && $name !~ /$task->{_selector}/ );
	return if( -e $fullname && !-f $fullname ); # Ignore wierd objects
    } else {
	return unless( $event->name eq $task->{_filename} );
	return if( -e $task->{file} && !-f $task->{file} );   # File watch got a wierd object: Should this abort?
    }

    # Remaining events need no special handling.

    for( my $i = 0; $i < $#events && $mask; $i += 3 ) {
	my( $bit, $text, $mkey ) = @events[$i .. $i+2];

	next unless( $mask & $bit );
	$mask &= ~$bit;

	$task->_run( $text, $fullname ) if( $task->{_watching}{$mkey} );
    }
}

=pod

---++ ObjectMethod _abort( $cancel )
Stop watch, but don't cancel task so it can be notified
   * =$cancel= - called from cancel (don't log as abort)

=cut

sub _abort {
    my $self = shift;

    return if( $self->{_cancelled} || $self->{_aborted} );

    if( exists $self->{_fd} ) {
        schedulerRegisterFds( $self->{_fd}, '-', undef );
        delete $parentFds{$self->{_fd}};
        delete $self->{_fd};
    }

    delete $self->{_inotify};

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
