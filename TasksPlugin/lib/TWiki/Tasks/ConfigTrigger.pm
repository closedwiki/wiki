# -*- mode: CPerl; -*-
# TWiki off-line task management framework addon for the TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2011 Timothe Litt <litt at acm dot org>
# License is at end of module.
# Removal of Copyright and/or License prohibited.


use strict;
use warnings;


=pod

---+ package TWiki::Tasks::ConfigTrigger

Monitor configuration items service of the TASK daemon.

Provides the 'config' triggered task type.

Always executed in _Daemon context;

=cut

package TWiki::Tasks::ConfigTrigger;

our @ISA = qw/TWiki::Tasks/;


use TWiki::Tasks::Globals qw/:cfgtrigger/;
use TWiki::Tasks::Logging;

use TWiki;

my %cfgModRegistry;
my $cfgFileWatch;

=pod

---++ ClassMethod new( $self )
Constructor for a new TWiki::Tasks::ConfigTrigger object.
   * =$self= - Generic unblessed task hash from TWiki::Tasks->new

---+++ Specialized task parameters
   * =items= - Reference to an array of configuration item keys to be monitored, or a single configuration key name.  Keys may be suffixed with one or more +attribute tags as described below.
   * =item= - May be used instead of =items=.

Either =items= or =item= is required.

N.B. new is invoked by TWiki::Tasks->new, and must not be directly invoked by other code.

---+++ Task activation arguments:
   * =$changes= - Reference to an array describing configuration item changes.  For each item that changed, the array will contain two elements: the key name and the new value.  These will be in the same order as specified in the =items= list, but will not include any attribute tags.

---+++ Task description
Config-triggered tasks run when a change is detected to one or more configuration items in which it has registered interest.

These tasks can be used to activate, deactivate and/or reconfigure services based on administrator's changes made in the configure GUI.

This task type is also used internally by the daemon.

Most services don't need to use config-triggered tasks, since the current value of all configuration items is maintained in the TWiki::cfg hash.  However, any task that caches a configuration item (e.g. by passing its value to a system service) may need notification to update its cache.  Many parameters to daemon services will automatically track changes when their value is specified as a configuration item key.

Tasks that want to be called with the initial value of a parameter can add the '+init' attribute to the configuration item key in the =items= list.

Changes are detected when the LocalSite.cfg file is written - usually by the configure GUI.  The GUI is responsible for validating new values, but the task may have to deal with inconsistencies - such as when an admistrator saves the configuration part way through a multi-item change.

Change notification is not instantaneous.  In addition to detection and queuing delays, the LocalSite.cfg file is not locked during updates, so the contents are re-validated some time after the file is written and before the task is notified.

Exceptions are thrown for invalid arguments.

See the generic Task definition for the standard arguments.

=cut

sub new {
    my $class = shift;
    my $self = shift;

    my $items = $self->{items} || delete $self->{item};
    $items = [ $items ] unless( ref( $items ) );
                             # Allow a single item to be passed as a variable or string
    die "Invalid item list for ConfigTrigger\n" unless( ref( $items ) eq 'ARRAY' && @$items );

    # N.B. Parallel logic in items()
    #
    # Scan item list:
    # o Make sure the items have reasonable syntax:
    #   {key}{subkey}... '+attrib...'
    # Just out of paranoia, delete any duplicates (allows for alternate quoting of identical keys) & make sure items eval.
    # o Identify any +init items

    my( @initItems, %f );
    $self->{items} = [];

    foreach my $item (@$items) {
	my( $key, $attr ) = $item =~ m/^($configItemRegex)(\+\w+)*$/o;
	die "Invalid item \"$item\"\n" unless( $key );
	die "Duplicate item \"$item\"\n" if( eval "\$f$key++" );
        die "Item \"$item\": $@\n" if( $@ );
	push @{$self->{items}}, $item;
	push @initItems, $key if( $attr && $attr =~ /\+init\b/ );
    }

    bless $self, $class;

    my $first = !%cfgModRegistry;

    $cfgModRegistry{$self->{_uname}} = $self;

    if( $first ) {
	# N.B. This may cause a recursive call; our state must be consistent.
	$cfgFileWatch = TWiki::Tasks->new( trigger => 'file',
					   name => 'ConfigMonitor',
					   file =>  $INC{'LocalSite.cfg'},
					   monitor => [ qw/creates writes/ ],
					   sub =>  \&_configMonitorTask,
					   queue => '_Daemon',
					 );
    }

    # If any items are marked for initialization, issue the callback for those items.
    #
    # This enables caller to trigger initialization as if it was just another state change.

    if( @initItems ) {
	my @items = map { my @v = ($_, eval "\$TWiki::cfg$_"); die "Init item $_: $@\n" if( $@ ); @v } @initItems;
	$self->_run( [ @items ] );
	# Handle (unlikely) cancellation in init callback
	return undef unless( $cfgModRegistry{$self->{_uname}} && $cfgModRegistry{$self->{_uname}} == $self );
    }

    return $self;
}

=pod

---++ ObjectMethod items( newlist ) -> @list
Accessor for the  =items= attribute.

Returns the list of configuration item keys being monitored.

Replaces the list of configuration items being monitored if =newlist= is specified.

As with =new()=, =newlist= can be either a reference to an array or a list of items.  At least one item must be specified (use =cancel()= to discontinue monitoring).  The =+init= attribute may be used if an immediate notification for the current value of an item is desired.

May throw an exception for invalid argument.

=cut

sub items {
    my $self = shift;

    my $old = $self->{items};

    return @$old unless( @_ );

    # Update item watch list

    my $items = $_[0];

    if( ref( $items ) eq 'ARRAY' ) {
	shift;
	$items = [ @$items, @_ ] if( @_ );
    } elsif( !ref( $items ) ) {
	$items = [ @_ ];
    } else {
	die "Unknown argument to ConfigTrigger::items\n";
    }

    # Empty item list indicates caller is confused.  Might have meant to cancel.  Don't waste resources.

    @$items or die "Empty item list specified for $self->{name}\n";

    # Handle almost identically to new(), except that we know the monitor task is running and
    # this task is registered.

    my( @initItems, %f );
    $self->{items} = [];

    foreach my $item (@$items) {
	my( $key, $attr ) = $item =~ m/^($configItemRegex)(\+\w+)*$/o;
	die "Invalid item \"$item\"\n" unless( $key );
	die "Duplicate item \"$item\"\n" if( eval "\$f$key++" );
        die "Item \"$item\": $@\n" if( $@ );
	push @{$self->{items}}, $item;
	push @initItems, $key if( $attr && $attr =~ /\+init\b/ );
    }

    # If any items are marked for initialization, issue the callback for those items.

    if( @initItems ) {
	my @items = map { my @v = ($_, eval "\$TWiki::cfg$_"); die "Init item $_: $@\n" if( $@ ); @v } @initItems;
	$self->_run( [ @items ] );
    }

    return @$old;
}

=pod

---++ ObjectMethod cancel( )
Standard task method to cancel a task.

=cut

sub cancel {
    my $self = shift;

    return if( $self->{_cancelled} );

    delete $cfgModRegistry{$self->{_uname}};

    unless( %cfgModRegistry ) {
	if( $cfgFileWatch ) {
	    $cfgFileWatch->cancel;
	    undef $cfgFileWatch;
	}
    }

    $self->SUPER::cancel( @_ );

    return;
}

=pod

---++ ObjectMethod _run( ... ) -> $status
Standard task method to trigger a task instance.

Log changed key names if debugging, then pass on.

=cut

sub _run {
    my $self = shift;

    if( $debug ) {
	my $i = 0; # Even elements are names; odd are values
	logMsg( DEBUG, "Notifying $self->{name} of changes to " . join( ',', grep { ++$i & 1 } @{$_[0]} ) . "\n" ) if( $debug );
    }

    return $self->SUPER::_run( @_ );
}

=pod

---++ ObjectMethod DESTROY( ... )
Destructor: cancel to de-register.

=cut

sub DESTROY {
    my $self = shift;

    $self->cancel unless( $forkedTask );
}

=pod

---++ internal TaskExecutionMethod _configMonitorTask( $twiki, $event, $cfgfile )
file-triggered task execution.

Monitor task triggered on write (or create) of LocalSite.cfg.

Runs on _Daemon queue for access to internal state and to sychronize access to task data.

   * =$event= - =file= event name
   * =$cfgfile= - =file= name of file monitored

Because LocalSite.cfg updates are not locked, We have no good way to tell if the change is complete.  The best we can do is to
wait a while and make sure that (a) no more changes happen and (b) the file contents seem sensible.

This would be simpler if configure -- and editors -- used file locking.

=cut

my $updtask;

sub _configMonitorTask {
    my( $self, $twiki, $event, $cfgfile ) = @_;

    logMsg( DEBUG, "Detected configuration file change ($event)\n" ) if( $debug );

    # Cancel update if a change was detected recently

    $updtask->cancel if( $updtask );
    undef $updtask;

    my $cfgdata = _readConfig( $cfgfile );
    defined( $cfgdata ) or return 0;

    # Schedule update

    $updtask = TWiki::Tasks->new( trigger => 'time',
				  name => 'ConfigUpdate',
				  runin =>  5,
				  context => [ $cfgfile, $cfgdata ],
				  sub =>  \&_configUpdateTask,
				  queue => '_Daemon',
				);
    return 0;
}

=pod

---++ internal TaskExecutionMethod _configMonitorTask( $twiki, $now )
time-triggered task execution.

This task is triggered shortly after a write (or create) of LocalSite.cfg is detected.

Runs on _Daemon queue for access to TWiki::cfg hash and to sychronize access to task data.

   * =$now= - current time

Having waited a while for writes notifications to stop, read the current contents of the configuration file.
If it doesn't validate or is different from the last read, defer processing until the contents stabilize.

Once we have an apparently stable new file, update TWiki::cfg and notify waiting tasks.

=cut

sub _configUpdateTask {
    my( $self, $twiki, $now ) = @_;

    my( $cfgfile, $cfgdata ) = @{$self->{context}};

    my $latestcfg = _readConfig( $cfgfile );

    return 0 unless( defined $latestcfg ); # New data is invalid, wait for next file change

    unless( $latestcfg eq $cfgdata ) {     # Valid but different.  Check again soon.
	$self->cancel;
	$updtask = TWiki::Tasks->new( trigger => 'time',
				      name => 'ConfigUpdate',
				      runin =>  5,
				      context => [ $cfgfile, $latestcfg ],
				      sub =>  \&_configUpdateTask,
				      queue => '_Daemon',
				    );
	return 0;
    }
    $updtask = undef;

    # Two consecutive reads (a few seconds apart) produced the same apparently sane data

    logMsg( DEBUG, "Processing configuration file change\n" ) if( $debug );

    # Since another process could be writing the config file yet again, we
    # won't require it - instead, we'll eval the data that we just sorta-validated.

    require Clone;

    my $oldcfg = Clone::clone( \%TWiki::cfg );
    %TWiki::cfg = ();

    my $sts = eval $latestcfg;
    $sts = 'undef' unless( defined $sts );
    $@ .= " new file returned invalid status ($sts)" unless( $sts eq 1 );
    if( $@ ) {
	%TWiki::cfg = %{ Clone::clone( $oldcfg ) };
	logMsg( WARN, "Continuing with previous configuration: $@\n" );
	return 0;
    }

    foreach my $task (values %cfgModRegistry) {

	# See if change in any registered item(s) of interest to this task

	my @changed;
	foreach my $item (@{$task->{items}}) {
	    $item =~ m/^($configItemRegex)(\+\w+)*$/o;
	    my $key = $1;
	    my $oval = eval "\$oldcfg->$key";
            # Don't check status of old value as it may have a syntax error that's now fixed
	    my $nval = eval "\$TWiki::cfg$key";
            if( $@ ) {
                logMsg( WARN, "Error in configuration item $key: $@\n" );
                next;
            }
	    push @changed, $key, $nval if( (defined($oval) xor defined($nval))
					 || defined($nval) && $oval ne $nval );
	}
	if( @changed ) {
	    $task->_run( [ @changed ] );
	}
    }

    # Task success

    return 0;
}

# ---++ StaticMethod _readConfig( $cfgfile ) -> $data
# Reads and validates configuration file
#
# Strips comments, since the data will be eval'd
#
# Returns undef if can't read file or it doesn't look like TWiki::cfg data
# Otherwise, returns data

sub _readConfig {
    my $cfgfile = shift;

    local $/ = "\n";
    my $cfgdata = '';
    open( my $cfg, '<', $cfgfile ) or return undef;
    while( <$cfg> ) {
	next if( /^\s*#/ );
	$cfgdata .= $_;
    }
    close $cfg or return undef;

    # Look for $TWiki::cfg{ ending with a line containing just  '1;', which is close to an EOF marker.
    # If the file is updated by write...truncate, this won't be accurate.  But
    # truncate ... write, create ... write and tmpfile ... rename should be OK.

    return undef unless( $cfgdata =~ /\$TWiki::cfg\{.*^\s*1;\s*\z/ms );

    return $cfgdata;
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
