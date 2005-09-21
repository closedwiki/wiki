# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2001-2004 Peter Thoeny, peter@thoeny.com
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

package TWiki::Plugins::RenderListPlugin;
use strict;

use vars qw( $VERSION $installWeb );

$VERSION = '1.133';

sub initPlugin {
    my( $topic, $web, $user ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning( "Version mismatch between RenderListPlugin and Plugins.pm" );
        return 0;
    }

    $installWeb = $web;

    return 1;
}

sub preRenderingHandler {
### my ( $text, $removed ) = @_;   # do not uncomment, use $_[0], $_[1] instead

    return unless $_[0] =~ /%RENDERLIST{/;

    # Render here, not in commonTagsHandler so that lists produced by
    # Plugins, TOC and SEARCH can be rendered
    require TWiki::Plugins::RenderListPlugin::Core;
    TWiki::Plugins::RenderListPlugin::Core::expand( @_ );
}

1;
