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

package TWiki::Contrib::DBCacheContrib::Archivist::File;
use strict;

use Data::Dumper;

sub store {
    my( $this, $data, $cache ) = @_;

    open(F, ">$cache" ) || die "$cache: $!";
    # get an exclusive lock on the file (2==LOCK_EX)
    flock( F, 2 ) || die $!;
    print F Data::Dumper->Dump( [ $data ], [ 'data' ] );
    flock( F, 8 ) || die( "LOCK_UN failed: $!" );
    close( F );
}

sub retrieve {
    my( $this, $cache ) = @_;

    open(F, "<$cache") || die "$cache: $!";
    # 1==LOCK_SH
    flock( F, 1 ) || die $!;

    local $/;
    my $conts = <F>;
    flock( F, 8 ) || die( "LOCK_UN failed: $!" );
    close( F );

    # MAJOR SECURITY RISK - eval of file contents
    $conts =~ /^(.*)$/; # unchecked untaint
    my $data;
    eval $conts;

    return $data;
}

1;
