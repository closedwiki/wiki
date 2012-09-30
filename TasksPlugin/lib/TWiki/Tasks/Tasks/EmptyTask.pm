# -*- mode: CPerl; -*-
# TWiki off-line task management framework addon for the TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2011 Timothe Litt <litt at acm dot org>
# License is at end of module.
# Removal of Copyright and/or License prohibited.

=pod

---+ package TWiki::Tasks::Tasks::EmptyTask
Sample external task driver for the TASK daemon.

This sample demonstrates how to interface an external task, typically a Contrib to the task framework.  TWiki Plugins do
not use this method, they simply add the equivalent code to initPlugin.

In this sample, note that "extType" and "ExtName" are used when referring to the namespace assigned to the external
task/addon/extension.

"Tasks" is the namespace of the task  framework.  Only make entries in the Tasks namespace that are documented here.

Because all the entries for each external task are qualified by the external task's name, collisions should not occur.

=cut

package TWiki::Tasks::Tasks::EmptyTask;

# Always use strict to enforce variable scoping

use warnings;
use strict;

require TWiki::Func;    # The plugins API

our( $VERSION, $RELEASE, $DESCRIPTION );

#$VERSION = '$Rev$';
$VERSION = 1.1; # Checked by loader.

$RELEASE = 'V0.000-001';

# $DESCRIPTION is used to identify the task in configure

$DESCRIPTION = 'Template non-plugin task for extension developers.';

# This is the name of the sample task.  It should match the name of your extension,
# and also appears in the "package" statement above.  You don't have to us a variable
# for the name; it's done this way here so it's easy to use this sample as a basis
# for a real application.

my $taskName = 'EmptyTask';

my $extType = 'Contrib';
my $extName = 'Empty';

=pod

---++ StaticMethod initDriver( $topic, $web, $user ) -> $success
Driver initialization entry point.

The initTask entry point is required.  The framework will call this entry point when this module is loaded.  This is the
module's opportunity to schedule its tasks and register for events.  Configuration data for this generally comes from the
TWiki::cfg hash which is maintained by configure.  However, you are free to obtain configuration data elsewhere if necessary.
This is discouraged because configure should be the overall management inteface for TWiki.

This is also a good place to load any other modules that the extension requires.  By structuring your extension this way,
it's easy to have a script or even stand-alone GUI interface as an alternative.

No actual processing should be done here.  Processing is handled by the task and/or event handlers that are configured here.

Note that the order in which tasks initialize is undefined, and will vary from run to run and release to release.

If you are only using the automatically defined driverCleanup task, initDriver can simply return 1.

There are two ways to incorporate schedule configuration items in the configure GUI.
If you want your item to appear with the rest of your configuration items, include a **SCHEDULE** item in your Config.spec.
**SCHEDULE** will generate a GUI for crontab format schedules.

If you want your schedules to be presented with all the other add-on schedules (e.g. not under your addon's tab), create
a $taskName.spec file in the same directory as this interface module.  Items in this file will appear with the
automatically generated {Enabled} item for the extension.  This file is optional.

You may also use both methods.

In any case, you may include a field checker.  Use TWiki::Configure::Checkers::CleanupSchedule as a template for your checker.
However, configure will automagically create a checker for SCHEDULE items if a custom checker is not provided.  You don't have
to create one unless some particular SCHEDULE item needs unique validation.  (We'd be interested in understanding use cases
for this.)

=cut

sub initDriver {
    my( $topic, $web, $user ) = @_;

    TWiki::Func::writeDebug( "$taskName loaded" );

    unless( TWiki::Func::getContext()->{Task_Daemon} ) {
	die "Configuration error: " . __PACKAGE__ . "$taskName should never be initialzed by a webserver"
    }

    # Task definitions, reconfig handler, etc goes here.

    my $testTask = TWiki::Tasks->new( trigger => 'schedule',
                                      name => 'CronTask',
                                      schedule => '{Tasks}{PolledEventsSchedule}',
                                      sub => \&_testTask,
                                    );
    if( 0 ) {
        my $testTask = TWiki::Tasks->new( trigger => 'time',
                                          name => 'Maintenance',
                                          runtime => "{$extType}{$extName}{MaintenanceTime}", # "Last Friday in December at 15:00"
                                          command => "{$extType}{$extName}{MaintenanceCommand}", # /usr/sbin/twiddle twaddle "Twyt"
                                          mailto => "{$extType}{$extName}{MaintenanceAdmin}", # 'admin@example.com',
                                          queue => "${extName}_Queue",
                                        );
    }

    my $dummy = $TWiki::cfg{$extType}{$extName}{Useless};

    if( 0 ) {
        return eval "require TWiki::$extType::$extName\n" .
                    "return TWiki::$extType::$extName::init( @_ )\n";
    }

    return 1;
}

# ---++ TaskExecutionMethod testTask( $now ) -> $exitStatus
# Sample task
#
# Runs as a fork, with the session established by ALL plugin and driver initialization.  The task API is available so additional
# tasks can be created/managed.  Any output generated on STDERR/STDOUT will be collected and e-mailed.
#
# Returns exit status (0 is success)

sub _testTask {
    my $self = shift;

    $self->cancel;

#    sleep 300;
    sleep 20;

    print $self->name . "Woke\n";

    return 0;
}

=pod

---++ DriverExecutionMethod driverCleanup( $session, $now ) -> $exitStatus
Automatically created schedule-triggered task, which is run on the standard plugin/contrib cleanup schedule.
   * =$session= - initialized TWiki session
   * =$now= - current time

You need only define this subroutine for it to be called on the admin-defined schedule $TWiki::cfg{CleanupSchedule}

For a simple extension, this is all you need.  This sample code simply deletes old files in the working area.  The age is
configured by a config item.

This name (driverCleanup) is required for an automatic cleanup task to be created.

Returns exit status (0 is success)

=cut

sub driverCleanup {
    my( $session, $now ) = @_;

    TWiki::Func::writeDebug( "$taskName: Running driverCleanup: " . (scalar localtime $now) );

    # Disable sample code

    return 0;

    # If you need the task handle for this task, you can obtain it with:
    # my $self = TWiki::Func::getTaskHandle('$driverCleanup$');

    my $wa = TWiki::Func::getWorkArea($extName);

    # Maximum age for files before they are deleted.
    # Note that updating MaxAge in configure will be reflected here without any code in the task.

    my $maxage = $TWiki::cfg{$extType}{$taskName}{MaxAge} || 24;

    my $oldest = $now - ($maxage*60*60);

    # One might want to select only certain files from the working area and/or log deletions.

    foreach my $wf ( glob( "$wa/*" ) ) {
        next unless( -f $wf );

	my( $uid, $gid, $mtime ) = (stat $wf)[4,5,9];

	if( $uid == $> && $gid == $)+0 && $mtime < $oldest) {
	    $wf =~ /^(.*$)$/;               # Untaint so -T works
	    $wf = $1;
	    unlink $wf or TWiki::Func::writeWarning( "Unable to delete $wf: $!" );
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
