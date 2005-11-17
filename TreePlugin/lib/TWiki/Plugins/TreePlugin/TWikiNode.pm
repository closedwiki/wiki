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


package TWiki::Plugins::TreePlugin::TWikiNode;
use base qw(TWiki::Plugins::TreePlugin::Node);

use strict;


# Constructor
sub new {
    my ($class, $name) = @_;
    my $this  = $class->SUPER::new();
    $this->name($name);
    return bless($this, $class);
}

sub data {
    my $this = shift;
    my $key = shift;
    return "" unless ($key);
    my $val = shift;
    return $this->{"_$key"} unless ($val);
    return $this->{"_$key"} = $val;
}

########
# need to move all these data accessors
# into one hash like data above (which fails in CGI mode for some reason)


# PUBLIC the , set/get
sub onum {
    my $this = shift;
    if (@_) { $this->{_onum} = shift; };
    return $this->{_onum}; # added to give root an onum
}

##################


# takes a NodeFormatter object and applies its methods to format this
#	node
#
# call order:	

sub toHTMLFormat {
    my $this = shift;
    my $formatter = shift; # should we check for correct class?
    my $num = shift || 0;
    my $level = shift || 0;

	# return "<!-- Reached stoplevel -->" this causes problems with |-table formatting
	my $stoplevel = $formatter->data("stoplevel") || 999; # big number!
	return ""
		if ($stoplevel < $level);

	$formatter->initNode($this, $num, $level);
	
    my $childrenText = "";
    if ( scalar(@{$this->children()}) ) {
		my $count = 0;
    	foreach my $node (@{$this->children()} ){ 	# accumulate childrens' format
			$node->data("count", $count++);	# remember this node's sibling order
			$childrenText .= $formatter->formatChild( $node, $count, $level + 1);
		}
    }
    return ($childrenText) 
    	? $formatter->formatBranch( $this, $childrenText, $num, $level)
    	: $formatter->formatNode( $this, $num, $level);
}

1;






