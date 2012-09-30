package TWiki::Tasks::Tasks::TestTask;

# This sample demonstrates how to interface an external task, typically a Contrib
# to the task framework.  TWiki Plugins do not use this method, they simply add
# the equivalent code to initPlugin.  
#
# In this sample, note that "extType" and "ExtName" are used when referring to the 
# namespace assigned to the external task/addon/extension.  

# "Tasks" is the namespace of the task  framework.  Only make entries in the Tasks
# namespace that are documented here.  
#
# Because all the entries for each external task are qualified by the external task's 
# name, collisions should not occur.

# Always use strict to enforce variable scoping
use warnings;
use strict;

require TWiki::Func;    # The plugins API

our( $VERSION, $RELEASE, $DESCRIPTION );

#$VERSION = '$Rev: 15942 (11 Aug 2008) $';
$VERSION = 1.1; # Checked by loader.

$RELEASE = 'V0.000-001';

# $DESCRIPTION is used to identify the task in configure

$DESCRIPTION = 'Test non-plugin task.';

# This is the name of the sample task.  It should match the name of your extension,
# and also appears in the "package" statement above.  You don't have to us a variable
# for the name; it's done this way here so it's easy to use this sample as a basis
# for a real application.

my $taskName = 'TestTask';

my $extType = 'Contrib';
my $extName = 'Test';

# The initTask entry point is required.  The framework will call this entry point
# when this module is loaded.  This is the module's opportunity to schedule its tasks
# and register for events.  Configuration data for this generally comes from the
# TWiki::cfg hash which is maintained by configure.  However, you are free to 
# obtain configuration data elsewhere if necessary.  This is discouraged because
# configure should be the overall management inteface for TWiki.
#
# This is also a good place to load any other modules that the extension requires.
# By structuring your extension this way, it's easy to have a script or even
# stand-alone GUI interface as an alternative.
#
# No actual processing should be done here.  Processing is handled by the task
# and/or event handlers that are configured here.
#
# Note that there is no SESSION available as yet, and that the order in which
# tasks initialize is undefined, and will vary from run to run and release to
# release.

# There are two ways to incorporate schedule configuration items in the configure GUI.
# If you want your item to appear with the rest of your configuration items, include a **SCHEDULE** item in your Config.spec.  **SCHEDULE** will generate a GUI for crontab format schedules.
#
# If you want your schedules to be presented with all the other add-on schedules (e.g. not under your addon's tab), create a $taskName.spec file in the same directory as this interface module.  Items in this file will appear with the automatically generated {Enabled} item for the extension.  This file is optional.
#
# You may also use both methods.  
#
# In any case, you MUST include a field checker.  Use TWiki::Configure::Checkers::CleanupSchedule as a template for your checker.  You need only change the package name to customize it.  Save the customized version in TWiki::Configure::
# *** Experimental - a default is magically provided.
# You don't have to create one unless some particular
# SCVHEDULE item needs unique validation.

sub initDriver {
    my( $topic, $web, $user, $installWeb ) = @_;

    TWiki::Func::writeDebug( "$taskName loaded" );

    unless( TWiki::Func::getContext()->{Task_Daemon} ) {
	die "Configuration error: " . __PACKAGE__ . "$taskName should never be initialzed by a webserver"
    }

###
my $dir = "/home/litt/wikisvn/twiki/trunk/core/working/work_areas/TasksPlugin/test";

    my $dirmon = TWiki::Func::newTask(
				      trigger => 'directory',
				      name => 'DirWatch',
				      file => $dir,
selector => qr/^[^:]+$/,
				      monitor => [ qw/attributes creates deletes writes/ ],
				      sub => sub {
					  my( $self, $twiki, $event, $file ) = @_;
					  $DB::single = 1;
					  print "File $file $event\n";

					  return 0;
				      },
				      queue => 'WatchQueue',
);

###
    # Task definitions, reconfig handler, etc goes here.
my $tn = 0;
if( 0 ) {
    for my $t (10, 15, 15, 20, 5, 12, 25 ) {
	my $testTask = TWiki::Tasks->new( trigger => 'time',
				       name => "TimeTask$t-" . ++$tn,
				       runin => $t,
				       sub => sub { print "Time task $t\n"; return 0; },
				       queue => '_TimeTasks', #'_Default',
				     );
    }
}
#    $DB::single=2;    $DB::single=2;
    my $configItems = ['{CleanupSchedule}',
		       '{Tasks}{StatusServerAddr}+init',
		       '{Tasks}{DebugServerAddr}+init',
		       '{Tasks}{DebugServerEnabled}+init',
		       '{Tasks}{Umask}',
		       '{Tasks}{UserLogin}',
		      ];
    my $exttask = TWiki::Tasks->new( trigger => 'config',
				     name => 'TestExtConfig0',
				     items => $configItems,
				     command => "/home/litt/wikisvn/twiki/trunk/TasksPlugin/tools/Tasks/ExternalTestTask foo baz",
				     queue => 'external Q',
				   );

    $exttask = TWiki::Func::newTask( trigger => 'time',
				  name => 'TestExtConfig1',
				  runin => 30,
				  command => "/home/litt/wikisvn/twiki/trunk/TasksPlugin/tools/Tasks/ExternalTestTask foo baz bat",
				  queue => 'external Q',
				   );
    $exttask = TWiki::Func::getTaskHandle( 'TestExtConfig1' );
return 1;

    my $i = 0;
my $q = '_Default';{#    for my $q ( qw/_Default FastQ SlowQ AnyQ YourQ/) {
	for( my $t = 0; $t < 4; $t++, $i++ ) {
    my $testTask = TWiki::Tasks->new( trigger => 'schedule',
				       name => 'CronTask' . $i,
				       schedule => '{Tasks}{PolledEventsSchedule}',
				       sub => \&testTask,
				       queue => $q, #'_Default',
				     );
}}
    my $dummy = $TWiki::cfg{$extType}{$extName}{Useless};

    # use TWiki::<$extType>::<$extName>
    # return TWiki::<$extType>::<$extName>::init( ... );

    return 1;
}

sub testTask {
    my $self = shift;

    if( $self->{name} =~ /CronTask0$/ ) {
	my $rpcTask = TWiki::Tasks->new( trigger => 'schedule',
					 name => 'CronTaskfromFork',
					 schedule => '{Tasks}{PolledEventsSchedule}',
					 sub => sub {
					     my $self = shift;
	my $x = 1;
	$DB::single = 1;	$DB::single = 1;
print STDERR __PACKAGE__, ' => ', (scalar localtime $self->nextRuntime), "\n";

	$x = $self->cancel if( $x );
print "Cancelled $self->{name} : $x\n";
 					     print "[$$]: I had a dream\n";
					     return 0;
					 },
					 queue => 'AnotherQueue',
				     );
	print "Created new task\n";
	$DB::single = 1;	$DB::single = 1;
	my $rpcTask2 = TWiki::Func::newTask( trigger => 'schedule',
					     name => 'CronTaskfromFork',
					     schedule => '{Tasks}{PolledEventsSchedule}',
					     sub => sub {
					                    my $self = shift;
	my $x = 1;
print STDERR __PACKAGE__, ' => ', (scalar localtime $self->nextRuntime), "\n";

	$x = $self->cancel if( $x );
print "Cancelled $self->{name} : $x\n";
 					     print "[$$]: I had an impossible dream\n";
					     return 0;
					 },
					 queue => 'AnotherQueue',
				     );

	return 0;
    }
    $self->cancel;

    print STDERR "Test brainless\n";

    system( 'echo "1111"' );
    system( 'echo "1111" >&2' );

    sleep 300;

    print "Woke\n";

    return 0;
}

# Task run on standard plugin/contrib cleanup schedule
#
# You need only define this subroutine for it to be called on the admin-defined schedule
# $TWiki::cfg{CleanupSchedule}
#
# For a simple extension, this is all you need.  This sample code simply deletes old files
# in the working area.  The age is configured by a web preference or a config item.
#
# This name (driverCleanup) is required.

sub driverCleanup {
    my( $session, $now ) = @_;

    TWiki::Func::writeDebug( "$taskName: Running driverCleanup: " . (scalar localtime $now) );
    $DB::single=1;    $DB::single=1;
    return 0;

    my $wa = TWiki::Func::getWorkArea($extName);

    # Maximum age for files before they are deleted.
    # Note that updating MaxAge in configure will be reflected here without any code in the task.

    my $maxage =  TWiki::Func::getPreferencesValue( "\U$taskName\E_MAXAGE" ) ||
                  $TWiki::cfg{$extType}{$taskName}{MaxAge} || 24;

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

# Copyright (C) 2000-2011 TWiki Contributors.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# As per the GPL, removal of this notice is prohibited.
