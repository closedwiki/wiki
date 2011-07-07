# Contrib for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2007 Crawford Currie, http://c-dot.co.uk
# Copyright (C) 2007-2011 TWiki Contributor. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root of
# this distribution.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

package TWiki::Contrib::DBCacheContrib::Archivist::Storable;

use strict;

sub store {
    my( $this, $map, $cache ) = @_;
    require Storable;
    Storable::lock_store( $map, $cache );
}

sub retrieve {
    my( $this, $cache ) = @_;
    require Storable;
    return Storable::lock_retrieve( $cache );
}

1;
