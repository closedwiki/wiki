#
# TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2004 Wind River Systems Inc.
#
# For licensing info read license.txt file in the TWiki root.
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

use strict;

=begin text

---
---++ package TWiki::Contrib::MailerContrib::Subscription
Object that represents a single subscription of a user to
notification on a page. A subscription is expressed as a page
spec (which may contain wildcards) and a depth of children of
matching pages that the user is subscribed to.

=cut

package TWiki::Contrib::MailerContrib::Subscription;

=begin text

---+++ sub new($pages, $childDepth)
| =$pages= | Wildcarded expression matching subscribed pages |
| =$childDepth= | Depth of children of $topic to notify changes for. Defaults to 0 |
Create a new subscription.

=cut

sub new {
    my ( $class, $topics, $depth ) = @_;

    my $this = bless( {}, $class );

    $this->{topics} = $topics;
    $this->{depth} = $depth;

    $topics =~ s/[^\w\*]//g;
    $topics =~ s/\*/\.\*\?/g;

    $this->{topicsRE} = qr/^$topics$/;

    return $this;
}

=begin text

---+++ sub toString() -> string
Return a string representation of this object, in Web<nop>Notify format.

=cut

sub toString {
    my $this = shift;

    my $record = $this->{topics} . "";
    # convert RE back to wildcard
    $record =~ s/\.\*\?/\*/;
    $record .= " ($this->{depth})" if ( $this->{depth} );
    return $record;
}

=begin text

---+++ sub matches($topic, $db, $depth) -> boolean
| =$topic= | Topic object we are checking |
| =$db= | TWiki::Contrib::MailerContrib::UpData database of parent names |
| =$depth= | If non-zero, check if the parent of the given topic matches as well. undef = 0. |
Check if we match this topic. Recurses up the parenthood tree seeing if
this is a child of a parent that matches within the depth range.

=cut

sub matches {
    my ( $this, $topic, $db, $depth ) = @_;

     unless ($topic) {
         return 0;
     }

    return 1 if ( $topic =~ $this->{topicsRE} );

    $depth = $this->{depth} unless defined( $depth );

    if ( $depth ) {
        my $parent = $db->getParent( $topic );
        return $this->matches( $parent, $db, $depth - 1 ) if ( $parent );
    }

    return 0;
}

1;
