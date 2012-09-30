# -*- mode: CPerl; -*-
# TWiki off-line task management framework addon for the TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2011 Timothe Litt <litt at acm dot org>
# License is at end of module.
# Removal of Copyright and/or License prohibited.


use strict;
use warnings;


=pod

---+ package TWiki::Tasks::Internal

This module implements the internal tasks of the  TASK daemon.

These are the tasks used by the daemon itself, as well as tasks created on behalf of plugins and drivers that use the
simplified API.  TWiki periodic maintenance functions formerly handled by an independent cron script (tick_twki.pl)
are also handled by an internal task.  The tasks implemented here are persistent and are required for the daemon
to operate.

Some daemon services also create service tasks.  Although these are "internal" to the daemon, their function is tightly bound
to the service.  They can be found in other modules.  Many of these are created (and cancelled) based on demand for their service.

=cut

package TWiki::Tasks::Internal;

use TWiki::Tasks::Globals qw/:internal/;
use TWiki::Tasks::Logging;

# **** Original TWiki code ****
use TWiki;
use TWiki::LoginManager;
# **** End original TWiki code ****

my( $configTask, @cleanupTasks );

=pod

---++ StaticMethod startup()
Framework initialization - create startup internal tasks and plugin/driver cleanup tasks.

=cut

sub startup {
    # Create task to run former tick_twiki cleanup and daemon cleanup

    push @cleanupTasks, TWiki::Tasks->new( trigger => 'schedule',
					   name => 'Cleanup',
					   schedule => '{CleanupSchedule}',
					   sub => \&_cleanupTask,
					   queue => '_Daemon',
					   maxrequeue => 0,
					   _noncancelable => 1, # Protected to ensure that Schedule::Cron always has 1 job.
					                        # Not for general use.
					 );

    # Create task to monitor configuration items that control daemon operations

    my $configItems = ['{Tasks}{StatusServerProtocol}',
                       '{Tasks}{StatusServerAddr}+init',
		       '{Tasks}{DebugServerAddr}+init',
		       '{Tasks}{DebugServerEnabled}+init',
		       '{Tasks}{Umask}',
		       '{Tasks}{UserLogin}',
		      ];

    $configTask = TWiki::Tasks->new( trigger => 'config',
				      name => 'ConfigMonitor',
				      items => $configItems,
				      sub => \&_reconfig,
				      queue => '_Daemon',
				      maxrequeue => -1,
				    );

    # Create tasks for plugins and drivers with defined Cleanup subroutines

    return if( $cliOptions{g} );

    # Scan enabled plugins

    foreach my $plugin ( @{$twiki->{plugins}{plugins}} ) {
	next if( $plugin->{disabled} );

	my $cleanup = $plugin->{module} . '::pluginCleanup';

	if( defined( &$cleanup ) ) {
	    no strict 'refs';
	    my $sub = eval "\\&$cleanup";
	    use strict 'refs';
	    die "Can't get reference to $cleanup: $@\n" if( $@ );

            # Create task for this plugin, using simplified callback

	    push @cleanupTasks, TWiki::Tasks->new( trigger => 'schedule',
						   name => '$pluginCleanup$',
						   _caller => $plugin->{module},
						   schedule => '{CleanupSchedule}',
						   sub => $sub,
						   _driver => 1,
						   maxrequeue => 0,
						 );
	}
    }

    # And do the same for Drivers

    foreach my $driver ( keys %driverRegistry ) {
	my $module = $driverRegistry{$driver}{Module};
	next unless( defined $module && !$driverRegistry{$driver}{error} );

        my $cleanup = "${module}::driverCleanup";

        if( defined( &$cleanup ) ) {
            no strict 'refs';
            my $sub = eval "\\&$cleanup";
            use strict 'refs';
            die "Can't get reference to $cleanup: $@\n" if( $@ );

            # Create task for this driver, using simplified callback

            push @cleanupTasks, TWiki::Tasks->new( trigger => 'schedule',
                                                   name => '$driverCleanup$',
                                                   _caller => $module,
                                                   schedule => '{CleanupSchedule}',
                                                   sub => $sub,
                                                   _driver => 1,
                                                   maxrequeue => 0,
                                                 );
        }
    }

    return;
}

=pod

---++ internal TaskExecutionMethod _cleanupTask( $twiki, $now )
Cron-triggered task execution.

Periodic maintenance functions.

Runs on _Daemon queue to synchronize internal cleanup with task management.

   * =$now= - Current time

Expires unused sessions and cleans up stale edit locks, replacing the traditional tick_twiki script.

Runs Daemon cleanup.

This is the task which can not be cancelled and so guarantees that Schedule::Cron's requirement for at least one task is met.

=cut

sub _cleanupTask {
    my( $self, $twiki, $now ) = @_;

    unless( $cliOptions{l} ) {
	logMsg( DEBUG, "Expire sessions" ) if( $debug );

	# **** Original TWiki code ****
	# This will expire sessions that have not been used for
	# |{Sessions}{ExpireAfter}| seconds i.e. if you set {Sessions}{ExpireAfter}
	# to -36000 or 36000 it will expire sessions that have not been used for
	# more than 100 hours,

	TWiki::LoginManager::expireDeadSessions();
	# **** End original TWiki code ****
    }

    unless( $cliOptions{x} ) {
	logMsg( DEBUG, "Expire leases" ) if( $debug );

	# **** Original TWiki code ****
	# This will remove topic leases that have expired. Topic leases may be
	# left behind when users edit a topic and then navigate away without
	# cancelling the edit.


	my $store = $twiki->{store};

	foreach my $web ( $store->getListOfWebs()) {
	    $store->removeSpuriousLeases($web);
	    foreach my $topic ( $store->getTopicNames( $web )) {
		my $lease = $store->getLease( $web, $topic );
		if( $lease && $lease->{expires} < $now) {
		    $store->clearLease( $web, $topic );
		}
	    }
	}
	# **** End original TWiki code ****
    }

    # Execution cleanup

    TWiki::Tasks::Execute::_cleanup( $self, $now );

    return 0;
}

=pod

---++ internal TaskExecutionMethod _reconfig( $twiki, $changes )
Config-triggered task execution.

Monitor task triggered on change of configuration items that control the daemon.

Runs on _Daemon queue for access to =%monitoredTasks= and to sychronize access to task data.

   * =$changes= - ref to array of (config key, new value) pairs

The configuration items monitored control aspects of the daemon that invoke actions when their value changes.

=cut

sub _reconfig {
    my( $self, $twiki, $changes ) = @_;

    while( @$changes ) {
	my( $change, $value ) = splice( @$changes, 0, 2 );
	({
	     '{Tasks}{Umask}' => sub {
		                            my( $change, $value ) = @_;
		                            umask( $value || 007 );
				        },
#	     '{Tasks}{UserLogin}' => sub {
#		                               my( $change, $value ) = @_;
#		                               $twiki->change_user_name( $value );
#	                                   },
             '{Tasks}{StatusServerProtocol}' => \&_statusServerChange,
	     '{Tasks}{StatusServerAddr}' => \&_statusServerChange,
	     '{Tasks}{DebugServerEnabled}' => \&_debugServerChange,
	     '{Tasks}{DebugServerAddr}' => \&_debugServerChange,
	}->{$change} || sub { })->($change, $value);
    }

    return 0;
}

# ---++ StaticMethod _statusServerChange( $change, $value )
# Handle changes to debug server configuration
#
# Changes address and/or protocol of debug server.
#

sub _statusServerChange {
    my( $change, $value ) = @_;

    # Shut down any old instance

    if( defined $serverRegistry[0] ) {
        $serverRegistry[0]->close(0);
        $serverRegistry[0] = undef;
    }

    # Starting new requires an address - we don't officially support not having one, but a null address wil disable the server.
    # That's not a good idea...

    if( $TWiki::cfg{Tasks}{StatusServerAddr} ) {
        require TWiki::Tasks::StatusServer;
        $serverRegistry[0] = TWiki::Tasks::StatusServer->new( LocalAddr => $TWiki::cfg{Tasks}{StatusServerAddr},
#                                                             onlypeer => qr/^127\.0\.0\.(?:\d{1,3})$/,
                                                              name => 'Task Status Server',
                                                              number => 0,
                                                            );
        logMsg( ERROR, $serverRegistry[0]->error . "\n" ) if( $serverRegistry[0]->error );
    }
}

# ---++ StaticMethod _debugServerChange( $change, $value )
# Handle changes to debug server configuration
#
# Starts, stops and changes address of debug server.
#

sub _debugServerChange {
    my( $change, $value ) = @_;

    # $value isn't worth using since called on both Enabled and Addr

    if( $TWiki::cfg{Tasks}{DebugServerEnabled} ) {
	eval {
	    require TWiki::Tasks::DebugServer;
	}; if( $@ ) {
	    logMsg( ERROR, "Unable to load debugger: $@\n");
	} else {
	    if( defined $serverRegistry[1] ) {
		$serverRegistry[1]->close(0);
		$serverRegistry[1] = undef;
	    }
	    $serverRegistry[1] = TWiki::Tasks::DebugServer->new( LocalAddr => $TWiki::cfg{Tasks}{DebugServerAddr},
#								 onlypeer => qr/^127\.0\.0\.(?:\d{1,3})$/,
								 name => 'Task Debug Server',
								 number => 1,
								 preserve => 1,
							       );
	    logMsg( ERROR, $serverRegistry[1]->error . "\n" ) if( $serverRegistry[1]->error );
	}
    } else {
	if( defined $serverRegistry[1] ) {
	    $serverRegistry[1]->close(0);
	    $serverRegistry[1] = undef;
	}
    }
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

Approximately 27 lines of code are from
  the TWiki Collaboration Platform, http://TWiki.org/

and are Copyright (C) 2005-2007 TWiki Contributors.
These are clearly marked in the source and are licensed under GPL.
