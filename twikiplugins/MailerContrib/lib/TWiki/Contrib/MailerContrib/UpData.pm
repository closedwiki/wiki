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

use TWiki::Func;

=begin text

---++ package TWiki::Contrib::MailerContrib::UpData

Object that lazy-scans topics to extract
parent relationships.

=cut

package TWiki::Contrib::MailerContrib::UpData;

=begin text

---+++ sub new($web)
| =$web= | Web we are building parent relationships for |
Constructor for a web; initially empty, will lazy-load as topics
are referenced.

=cut

sub new {
    my ( $class, $web ) = @_;
    my $this = bless( {}, $class );
    $this->{web} = $web;
    return $this;
}

=begin text

---+++ sub getParent($topic) -> string
Get the name of the parent topic of the given topic

SMELL: *Huge* assumption about topic files containing meta-data!! This
should really do a Search, but there is no published API.

=cut

sub getParent {
    my ( $this, $topic ) = @_;

    if ( ! defined( $this->{topics}{$topic} )) {
        # Not previously loaded
        my $file = TWiki::Func::getDataDir() . "/$this->{web}/$topic.txt";
        my $q = $TWiki::cmdQuote;
        my $c = "egrep -s $q^%META:TOPICPARENT\\{.*\\}%$q $file";
        $c =~ /^(.*)$/;
        my $grep = `$1`;
        if ( $grep =~ /%META:TOPICPARENT{name=\"(.*)\"}%/ ) {
            $this->{topics}{$topic} = $1;
        }
    }

    return $this->{topics}{$topic};
}

1;
