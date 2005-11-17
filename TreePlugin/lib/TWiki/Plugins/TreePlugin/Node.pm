#
# Copyright (C) XXXXX 2001 - All rights reserved
#
# TWiki extension XXXXX
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


package TWiki::Plugins::TreePlugin::Node;

use strict;


# Constructor
sub new {
    my ($class, $name) = @_;
    my $this = {};
    my @children = ();
    $this->{_children} = \@children;
    $this->{_parent} = "";
    $this->{_name} = $name || "";
    return bless($this, $class);
}

# PUBLIC the name, set/get
sub name {
    my $this = shift;
    if (@_) { $this->{_name} = shift; };
    return $this->{_name};
}

# PUBLIC the name, set/get
sub parent {
    my $this = shift;
    if (@_) { $this->{_parent} = shift; };
    return $this->{_parent};
}

# PUBLIC gets a ref to the children
sub children {
    my $this = shift;
    return $this->{_children};
}

# PUBLIC adds a child to the node
sub add_child {
    my ($this, $child) = @_;
#   should one check for cirrect type?
#   return 0 unless (isa($child, 'TWiki::Plugins::TreePlugin::Node'));
    $child->parent($this);
    push @{$this->{_children}}, $child;
}

# Generate a string representation for debugging
sub toString {
    my ($this) = shift;
    my $res = "(".$this->name();
    if ( scalar(@{$this->children()}) ) {
    	foreach my $node (@{$this->children()} ){
    		$res .= $node->toString();
    	}
    }
    return $res.")";
}

# Generate a string representation for formatting
# 
# this works ok:  "<ul>", "</ul>", "<li>, "</ li>"
# mainly for debugging

sub toHTML {
    my ($this) = shift;
    my ($nodeBeg, $nodeEnd, $childBeg, $childEnd) = @_;
    my $res = $this->name();
    if ( scalar(@{$this->children()}) ) {
    	$res = $res.$nodeBeg;
    	foreach my $node (@{$this->children()} ){
    		$res .= $childBeg.$node->toHTML($nodeBeg, $nodeEnd, $childBeg, $childEnd).$childEnd;
    	}
    	$res .=  $nodeEnd;
    }
    return $res;
}

1;
