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
use strict;

=pod

---+ package TWiki::Contrib::MailerContrib::UpData
Object that lazy-scans topics to extract
parent relationships.

=cut

package TWiki::Contrib::MailerContrib::UpData;

=pod

---++ ClassMethod new($web)
   * =$web= - Web we are building parent relationships for
Constructor for a web; initially empty, will lazy-load as topics
are referenced.

=cut

sub new {
    my ( $class, $session, $web ) = @_;
    my $this = bless( {}, $class );
    $this->{web} = $web;
    $this->{session} = $session;
    return $this;
}

=pod

---++ ObjectMethod getParent($topic) -> string
Get the name of the parent topic of the given topic

=cut

sub getParent {
    my ( $this, $topic ) = @_;

    if ( ! defined( $this->{parent}{$topic} )) {
        my( $meta, $text ) =
          $this->{session}->{store}->readTopic( undef, $this->{web}, $topic );
        my $parent = $meta->get("TOPICPARENT");
        $this->{parent}{$topic} = $parent->{name} if $parent;
        $this->{parent}{$topic} ||= "";
    }

    return $this->{parent}{$topic};
}

1;
