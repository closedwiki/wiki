# Plugin code for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2007-2008 C-Dot Consultants http://c-dot.co.uk
# Copyright (C) 2008-2010 TWiki Contributor. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root of
# this distribution.
# Author: Crawford Currie
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
# This notice must be retained in all copies or derivatives of this
# code.

package TWiki::Plugins::SafeWikiPlugin::Leaf;

use strict;

sub new {
    my( $class, $text ) = @_;

    my $this = {};

    $this->{text} = $text;

    return bless( $this, $class );
}

sub stringify {
    my( $this ) = @_;
    return $this->{text};
}

sub generate {
    my( $this ) = @_;
    return $this->{text};
}

sub isLeaf {
    return 1;
}

1;
