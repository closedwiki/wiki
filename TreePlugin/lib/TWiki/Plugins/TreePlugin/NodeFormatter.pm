#
# Copyright (C) Slava Kozlov 2002 - All rights reserved
#
# TWiki extension  TWiki::Plugins::TreePlugin::NodeFormatter
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html
#

package TWiki::Plugins::TreePlugin::NodeFormatter;

# abstract interface to format the nodes in a tree

# Constructor
sub new { }

sub initNode { _unimplemented( "initNode", @_ ); }

#
sub formatNode { _unimplemented( "formatNode", @_ ); }

#
sub formatChild { _unimplemented( "formatChild", @_ ); }

#
sub formatBranch { _unimplemented( "formatBranch", @_ ); }

#
sub _unimplemented {
    my $routine = shift;
    my $class   = shift;
    die "$routine not implemented for $class with params ("
      . join( ", ", @_ ) . ")";
}

1;
