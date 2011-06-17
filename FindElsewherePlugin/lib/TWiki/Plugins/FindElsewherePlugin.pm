# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2002 Mike Barton, Marco Carnut, Peter HErnst
# Copyright (C) 2003 Martin Cleaver, (C) 2004 Matt Wilkie
# Copyright (C) 2007 Crawford Currie
# Copyright (C) 2002-2011 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root of
# this distribution.
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
# =========================
#
# This is the FindElsewhere TWiki plugin,
# see http://twiki.org/cgi-bin/view/Plugins/FindElsewherePlugin for details.

package TWiki::Plugins::FindElsewherePlugin;

use strict;

our $RELEASE = '$Rev$';
our $VERSION = '2011-06-16';

our $NO_PREFS_IN_TOPIC = 1;
our $SHORTDESCRIPTION = "Automatically link to topic in other web(s) if it isn't found in the current web";
our $disabled;

sub initPlugin {
    #my( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1 ) {
        TWiki::Func::writeWarning( "Version mismatch between FindElsewherePlugin and Plugins.pm" );
        return 0;
    }

    $disabled =
      TWiki::Func::getPreferencesFlag( "DISABLELOOKELSEWHERE" );
    unless( defined( $disabled )) {
        # Compatibility, deprecated
        $disabled =
          TWiki::Func::getPreferencesFlag( "FINDELSEWHEREPLUGIN_DISABLELOOKELSEWHERE" );
    }

    return !$disabled;
}

sub startRenderingHandler {
    # This handler is called by getRenderedVersion just before the line loop
    ### my ( $text, $web ) = @_;
    return if $disabled;

    require TWiki::Plugins::FindElsewherePlugin::Core;

    return TWiki::Plugins::FindElsewherePlugin::Core::handle(@_);
}

1;
