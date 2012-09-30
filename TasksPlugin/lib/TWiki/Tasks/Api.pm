# -*- mode: CPerl; -*-
# TWiki off-line task management framework addon for the TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2011 Timothe Litt <litt at acm dot org>
# License is at end of module.
# Removal of Copyright and/or License prohibited.


use strict;
use warnings;


=pod

---+ package TWiki::Tasks::Api

This provides the API for external tasks running under the daemon.  The TWiki::Tasks::Api package is currently empty, as the
native API lives in the TWiki::Tasks namespace and the convenience API extends the TWiki::Func package.

The API is simply a wrapper around remote procedure calls to the daemon, which occur over a connection inherited by the fork
that survives exec.  Note that the APIs must obey the rpCall restrictions, which include evaluating the calling context one
level above this interface and that all arguments must be _Storable_.

An external task must =use= this module; it can then make API calls of either flavor.  All the other mechanics are handled by
this module and the modules it uses.

This module and any module that it uses can not count on any data living in the daemon, and should minimize their dependencies
and the amount of data and code that they add to a task.

=cut

#package TWiki::Tasks::Api;

=pod

---+ package TWiki::Tasks

Native API
   * =TWiki::Tasks->new=
   * =TWiki::Tasks->getHandle=
   * =TWiki::Tasks::getTaskList=

The calling sequence of each routine is documented in _Tasks.pm_

=cut

package TWiki::Tasks;

# Do not use/require any module unless it should appear in an external task

use TWiki::Tasks::Execute::Rpc qw/rpCall/;
use TWiki::Tasks::Execute::RpcHandle;

sub new {
    return rpCall( 'TWiki::Tasks->new', @_, _caller => (caller())[0] );
}

sub getHandle {
    return rpCall( 'TWiki::Tasks->getHandle', @_, _caller => (caller())[0] );
}

sub getTaskList {
    return rpCall( 'TWiki::Tasks::getTaskList', @_, _caller => (caller())[0] );
}

=pod

---+ package TWiki::Func

Convenience API
   * =TWiki::Func::newTask= --> =TWiki::Tasks->new=
   * =TWiki::Func::getTaskHandle= --> =TWiki::Tasks->getHandle=
   * =TWiki::Func::getTaskList= -->  =TWiki::Tasks::getTaskList=

The calling sequence of each routine is documented for the corresponding native routine in _Tasks.pm_

=cut

package TWiki::Func;

use TWiki::Tasks::Execute::Rpc qw/rpCall/;

die "Task daemon API is not available unless running under the task daemon\n"
  unless( exists $ENV{TWikiTaskAPI} );

# See Startup.pm for the equivalent mappings for internal tasks.

sub newTask {
    return rpCall( 'TWiki::Tasks->new', @_, _caller => (caller())[0] );
}

sub getTaskHandle {
    return rpCall( 'TWiki::Tasks->getHandle', @_, _caller => (caller())[0] );
}

sub getTaskList {
    return rpCall( 'TWiki::Tasks::getTaskList', @_, _caller => (caller())[0] );
}


1;

__END__

# The preceeding 4 lines are removed and two commented-out lines in Startup.pm are enabled for the Foswiki API

=pod

---+ package Foswiki::Func

Convenience API
   * =Foswiki::Func::newTask= --> =TWiki::Tasks->new=
   * =Foswiki::Func::getTaskHandle= --> =TWiki::Tasks->getHandle=
   * =Foswiki::Func::getTaskList= -->  =TWiki::Tasks::getTaskList=

The calling sequence of each routine is documented for the corresponding native routine in _Tasks.pm_

=cut

package Foswiki::Func;

use TWiki::Tasks::Execute::Rpc qw/rpCall/;

sub newTask {
    return rpCall( 'TWiki::Tasks->new', @_, _caller => (caller())[0] );
}

sub getTaskHandle {
    return rpCall( 'TWiki::Tasks->getHandle', @_, _caller => (caller())[0] );
}

sub getTaskList {
    return rpCall( 'TWiki::Tasks::getTaskList', @_, _caller => (caller())[0] );
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
