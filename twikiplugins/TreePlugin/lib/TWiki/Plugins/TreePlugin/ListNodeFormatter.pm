#
# Copyright (C) XXXXXX 2001 - All rights reserved
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

package TWiki::Plugins::TreePlugin::ListNodeFormatter;
use base qw(TWiki::Plugins::TreePlugin::NodeFormatter);

#  class to format the nodes in a tree in a HTML list manner
# for example: Node1<ul><li>Child1</li><li>Child2</li></ul>
#
# each node is appended with its children
#
# node  nodeBeg
#         childBeg child childEnd
#         childBeg child childEnd
#         childBeg child childEnd
#         ....
#       endBeg
#

# Constructor
sub new {
    my ( $class, $nodeBeg, $nodeEnd, $childBeg, $childEnd ) = @_;
    my $this = {};
    $this->{_data} = ();
    bless( $this, $class );
    $this->data( "nodeBeg",  $nodeBeg  || "<ul> " );
    $this->data( "nodeEnd",  $nodeEnd  || " </ul>" );
    $this->data( "childBeg", $childBeg || "<li> " );
    $this->data( "childEnd", $childEnd || " </li>" );
    return $this;
}

sub initNode { }

# the data, set/get data hash values
sub data {
    my $this = shift;
    my $key  = shift;
    return $this->{_data} unless ($key);
    my $val = shift;
    return $this->{_data}->{$key} unless ($val);
    return $this->{_data}->{$key} = $val;
}

sub formatNode {
    my ( $this, $node, $count, $level ) = @_;

    # no formatting applied
    return &TWiki::Plugins::TreePlugin::getLinkName($node);
}

sub formatBranch {
    my ( $this, $node, $childrenText, $count, $level ) = @_;
    return $this->formatNode($node) unless $childrenText;
    return $this->formatNode($node)
      . $this->data("nodeBeg")
      . $childrenText
      . $this->data("nodeEnd");
}

sub formatChild {
    my ( $this, $node, $count, $level ) = @_;

    #return "" if ( $text == "");
    my $res = $node->toHTMLFormat( $this, $count, $level );
    return ($res)
      ? $this->data("childBeg") . $res . $this->data("childEnd")
      : "";
}

1;

