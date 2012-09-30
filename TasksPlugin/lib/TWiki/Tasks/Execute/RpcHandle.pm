# -*- mode: CPerl; -*-
# TWiki off-line task management framework addon for the TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2011 Timothe Litt <litt at acm dot org>
# License is at end of module.
# Removal of Copyright and/or License prohibited.


use strict;
use warnings;

# RPC Handles

=pod

---+ package TWiki::Execute::RpcHandle
RpcHandle objects are an abstract class for references to objects that are passed between child forks and the daemon using the
RPC mechanism.

RpcHandle subclasses itself for each abstract class of object that can be passed.  Derived classes of the real object
inherit "normally".

As part of RPC argument/return value marshalling, the procedure's argument list is scanned for known object types (see %objTypes, below).  Any reference to a known object type is replaced by a reference to an RpcHandle object.

RpcHandle objects will AUTOLOAD a stub routine for any indirect object method call that is invoked on them.  This stub
invokes Rpc::rpCall to marshall the arguments, issue the call, and return the result.

In addition to the AUTOLOADed routines, RpcHandle objects inherit two methods from the RpcHandle abstract class:
   * =class= - Returns the class of the proxied object.  N.B. Don't use ref on a RpcHandle object, it won't be what you expect.
   * =_getHandle= - in the daemon context, invokes the proper class method to find the proxied object and return its handle.

This module is included in external tasks that require TWiki::Tasks::Api; its dependencies have been minimized.  It also
is used in ordinary forked tasks.

The methods in this module are called by the the RPC client and server.  Nothing here is intended for general use.  It is
(or should be) magically transparent iff the documented APIs are used.

=cut

package TWiki::Tasks::Execute::RpcHandle;

use base 'Exporter';
our @EXPORT_OK = qw/makeRpcHandles/;

use Scalar::Util qw/blessed/;

# Do not use any module unless it should appear in an external task

our $forkedTask = 1;

# Initialization
#
# In Daemon context, $forkedTask is an alias of the daemon global.
#
# In an external task, it's a local imitation, simply noting that RPC is allowed.

unless( exists $ENV{TWikiTaskAPI} ) {
    # Hopefully the daemon - if an external task not under its control, will
    # fail as this is not supported due to the security complications it would create.

    no warnings 'redefine';
    *forkedTask = \$TWiki::Tasks::Globals::forkedTask;
}

# Map base class of known objects to rpc proxy object subclass name
# Each known object must have a getHandle class method that
# will return the base object given its name
#
# Because the type is chosen based on isa, derrived classes
# are automagically handled - the fork invokes a method name,
# and the daemon executes it against the real object with
# normal inheritance.

my %objTypes = (
		'TWiki::Tasks' => 'Task',
	       );

# Generate subclasses for each known type's rpc proxy object

foreach my $type (values %objTypes) {
    no strict 'refs';
    *{ __PACKAGE__ . "::${type}::ISA" } = [ __PACKAGE__ ];
}

=pod

---++ StaticMethod makeRpcHandles( @arglist )
Turn each argument that's a reference to a known object type  into a reference to a corresponding rpc proxy object.

N.B. Modifies arguments in place, does not modify other arguments.

No return value.

=cut

sub makeRpcHandles {
    while( @_ ) {
	my $ref = ref $_[0] or next;

	blessed( $_[0] ) or next;

	foreach (keys %objTypes) {
	    if( $_[0]->isa( $_ ) ) {
		$_[0] = bless {
			       class => $ref,
			       name => $_[0]->{name},
			       uid => $_[0]->{_uid},
			      }, __PACKAGE__ . "::$objTypes{$_}";
		last;
	    }
	}
    } continue {
	shift;
    }

    return;
}

=pod

---++ ObjectMethod class() -> $class
Return class of proxied object

This method returns the class of the remote (proxied) object.  This may be a subclass of any of the known object types
listed in %objTypes.

The proxied object must have a method of the same name and function, but a local method is more efficient.

Always use this method to find the class of a framework object - ref (or blessed) will not produce the result you expect.

Returns class.

=cut

sub class {
    my $self = shift;

    return $self->{class};
}

=pod

---++ ObjectMethod AUTOLOAD( @args ) -> result
Generates an RPC stub routine for any method invoked on an RPC handle, and invokes that method.
   * =@args= - whatever the remote object wants.  Note that the implicit $self argument is the RpcHandle object.

Inherited by all RpcHandle objects.

Returns: whatever the remote object returns - including exceptions.

=cut

sub AUTOLOAD {
    our $AUTOLOAD;
    my( $method ) = $AUTOLOAD =~ /::(\w+)$/;

    return if( $method eq 'DESTROY' );

    # We could try $_[0]->{class}->can( $method ), but that can be problematic
    # if the underlying class also autoloads.
    # Just send any method that's attempted, and rely on errors (e.g. die)
    # being returned for inappropriate or undefined methods.

    no strict 'refs';
    *$AUTOLOAD = sub {
	                 # Invoking an unknown class method in this package
	                 # would take some work - and I don't know what it means.
	                 # Class methods on the underlying class simply call
	                 # rpCall( 'ClASS->method', ... ).

	                 die "Improper use of " . __PACKAGE__ . "\n"
			   unless( $forkedTask &&
				   ref $_[0] && $_[0]->isa( __PACKAGE__ ) );

                         # N.B. the ';' in the method name is intentional and indicates an indirect object method call

			 return TWiki::Tasks::Execute::Rpc::rpCall( "$method;", @_ );
		     };
    use strict 'refs';
    goto &$AUTOLOAD;
}

=pod

---++ ObjectMethod getHandle() -> $objectRef
Return actual object type

Used by the RPC server to obtain a reference on the real object proxied by an RpcHandle object.

Each proxied class may have a different mechanism for doing the translation, so we call the ClassMethod getHandle of
the underlying class.

The UID is used to ensure that objects that may have been removed from their public registry (e.g. cancelled tasks)
can still find themselves.

Can not be called (meaningless) in a fork.

Returns a reference to the proxied object.

Not for general use.

=cut

# Instance method used in daemon context to return first class object from handle
# Inherited by all rpc proxy objects

sub _getHandle {
    my $self = shift;

    die "Improper use of " . __PACKAGE__ . "\n" if( $forkedTask );

    return $self->{class}->getHandle( $self->{name}, _uid => $self->{uid} );
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
