# -*- mode: CPerl; -*-
# TWiki off-line task management framework addon for the TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2011 Timothe Litt <litt at acm dot org>
# License is at end of module.
# Removal of Copyright and/or License prohibited.


use strict;
use warnings;


=pod

---+ package TWiki::Tasks::Param

Task parameter expansion and monitoring.  Provides the ability for task parameters to accept configuration key names as their
value.  This allows easy configurability, as well as automagically updating paramenter values when the configuration item
used as a value is modified.

=cut

package TWiki::Tasks::Param;

use base 'Exporter';
our @EXPORT_OK = qw/getArgValue/;

use TWiki::Tasks::Globals qw/:param/;
use TWiki::Tasks::Logging;

use Scalar::Util qw/weaken/;

use TWiki;

my( $missedItems, $monitoredTasksTask, %monitoredTasks );

=pod

---++ StaticMethod getArgValue( $value, $setMethod ) -> $string

Expands the value of a user parameter.

If the specified value is a configuration key, returns the value of the configuration item and registers the task to
receive updates via $setMethod when the configuration item is modified.

Otherwise, returns the input value, deregistering any update associated with a previous value.

   * =$value= - Input: user value that may be a configuration key.  Output: effective value.  To specify a string value that would normally be interpreted as a configuration key, use a \ to quote the initial {.  To specify a string with an initial \, use \\.  Note that except for these two cases, the value is *not* interpreted as \-encoded.
   * =$setMethod= - The name of a task method to be called to set the parameter value when the configuration item's value changes.

If the parameter is read-only (that is, a configuration item can be specified as a parameter to =new= ,but not changed thereafter), specify =undef= for =$setMethod=.

Returns expanded value as both an output value and by updating $value.

Intended for task =new= and accessor methods; not for general use.

=cut

sub getArgValue {
    my( $task, $value, $setMethod ) = @_;

    unless( defined $value && !ref( $value ) ) {
        # Can't be a config item key
        _updateItemMonitor( $task, undef, $setMethod ) if( defined $setMethod );
        return $value;
    }

    # Simple value, see if a config item key.

    unless( $value =~ m/^$configItemRegex$/o ) {
        # Not a config item key.  Remove \ quoting of { and \
        if( $value =~ s/^\\([\\\{])/$1/ ) {
            $_[1] = $value;
        }
        # Cancel any previous monitor for method

        _updateItemMonitor( $task, undef, $setMethod ) if( defined $setMethod );
        return $value;
    }

    # Value is a config item key.  Extract value from TWiki::cfg hash.

    my $item = $value;

    $value = eval "die( \"Missing\\n\" ) unless exists \$TWiki::cfg$item;" .
	                 "\$TWiki::cfg$item";
    die "$task->{name}: $setMethod specified item $item is not in configuration (LocalSite.cfg)\n" if( $@ );

    # Register this task for updates to the config item if the parameter has an update method

    _updateItemMonitor( $task, $item, $setMethod ) if( defined $setMethod );

    $_[1] = $value;
    return $value;
}

# ---++ StaticMethod _updateItemMonitor( $task, $item, $setMethod )
# Registers parameters whose value is established by (and tracks the value of) configuration parameters.
#
#   * =$task= - task handle
#   * =$item= - configuration key name to be tracked, or undef if parameter no longer requires a key.
#   * =$setMethod= - The name of a task method to be called to set the parameter value when the configuration item's value changes.
#
# Specify both =$item= and =$setMethod= as undef to cancel all parameter updates for a task.
#
# Manages configuration item monitoring task that executes change callbacks.


sub _updateItemMonitor {
    my( $task, $item, $setMethod ) = @_;

    my $first = !%monitoredTasks;

    if( defined $item ) {
        # Monitor item.  If already monitored (e.g. configure changed value, but same item), no need to adjust watch list
        return if( exists $monitoredTasks{$task->{_uname}}{$setMethod} &&
                   $monitoredTasks{$task->{_uname}}{$setMethod}->[1] eq $item );
        # New item for this task/method
        my $taskItem = [ $task, $item ];
        weaken( $taskItem->[0] );
	$monitoredTasks{$task->{_uname}}{$setMethod} = $taskItem;
    } else {
        if( defined $setMethod ) {
            # Stop monitoring a single method
            my $methodMap = $monitoredTasks{$task->{_uname}} or return;    # Return if task not registered
            return unless( delete $methodMap->{$setMethod} );              # Return if method not registered
            delete $monitoredTasks{$task->{_uname}} unless( %$methodMap ); # Last method for task
        } else {
            return unless( delete $monitoredTasks{$task->{_uname}} );      # Return if task not registered
        }
	unless( %monitoredTasks ) {
	    # Last task with registered method, cancel config task
	    if( $monitoredTasksTask ) {
		$monitoredTasksTask->cancel;
		undef $monitoredTasksTask;
	    }
	    return;
	}
    }

    # Potential change of list of items to monitor.  Collapse all tasks' items into a single monitor list

    my %items;
    foreach my $methodMap (values %monitoredTasks) {
        foreach my $taskItem (values %$methodMap) {
            $items{$taskItem->[1]} = 1;
        }
    }

    # Update or start monitor task
    # Starting monitor task may cause one or more additional scheduled tasks that depend
    # on a configured schedule to be started.  In that case, we would be
    # called recursively before the task handle for the monitor task is returned.
    # $missedItems accounts for that.

    if( !$first ) {
	if( $monitoredTasksTask ) {
	    $monitoredTasksTask->items( [ keys %items ] );
	} else {
	    # Changes inside new monitor task, record latest list
	    $missedItems = [ keys %items ];
	}
	return;
    }

    $monitoredTasksTask = TWiki::Tasks->new( trigger => 'config',
                                             name => 'TaskParameterMonitor',
                                             items => [ keys %items ],
                                             sub => \&_parameterChange,
                                             queue => '_Daemon',
                                           );
    if( $missedItems ) {
	# Apply latest item changes triggered by monitor creation
	$monitoredTasksTask->items( $missedItems );
	undef $missedItems;
    }
    return;
}

=pod

---++ internal TaskExecutionMethod _parameterChange( $twiki, $changes )
Config-triggered task execution.

Monitor task triggered on change of configuration items used as parameters.

Runs on _Daemon queue for access to =%monitoredTasks= and to sychronize access to task data.

   * =$changes= - ref to array of (config key, new value) pairs

Updates parameters of any tasks with a dependency on items that changed.  Rejected updates are logged.

=cut

sub _parameterChange {
    my( $task, $twiki, $changes ) = @_;

    logMsg( DEBUG, "Applying configured parameter changes\n" ) if( $debug );

    # There are probably fewer changes than tasks, items may apply to multiple tasks,
    # and order doesn't matter, so we'll make just one pass over the jobs instead
    # of scanning the changes.

    my %changes = @$changes;

    foreach my $methodMap (values %monitoredTasks ) {
        foreach my $setMethod (keys %$methodMap) {
            my( $task, $item ) = @{$methodMap->{$setMethod}};

            next unless( $task && exists $changes{$item} );

            my $value = $changes{$item};
            logMsg( DEBUG, "$task->{name}: $setMethod( $item = \"$value\" )\n" ) if( $debug );

            # Value is the item name (so it continues to be monitored)

            eval {
                $task->$setMethod( $item );
            };
            if( $@ ) {
                logMsg( ERROR, "$task->{name}: parameter update $setMethod( $item = \"$value\" ) failed: $@\n" );
            }
        }
    }
    return 0;
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
