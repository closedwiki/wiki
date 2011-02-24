# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2006 Peter Thoeny, peter@thoeny.org
# Copyright (C) 2008-2011 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root of 
# this distribution. NOTE: Please extend that file, not this notice.
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
#
# For licensing info read LICENSE file in the TWiki root.

package TWiki::Plugins::DblClickEditPlugin;

use strict;

use vars qw( $VERSION $RELEASE $debug $pluginName $web $topic );

$VERSION = '$Rev$';
$RELEASE = '2011-02-24';

# Name of this Plugin, only used in this module
$pluginName = 'DblClickEditPlugin';

sub initPlugin {
    my( $atopic, $aweb, $user, $installWeb ) = @_;

    # keep in mind web.topic names
    $topic = $atopic;
    $web = $aweb;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.1 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    # Plugin correctly initialized
    return 1;
}

sub postRenderingHandler {

    return unless( TWiki::Func::getContext()->{'view'} );

    my $dblclickedit = TWiki::Func::getPreferencesValue( "DBLCLICKEDIT" );
    if( $dblclickedit !~ /(no|off|0)/i ) {
        my $url = TWiki::Func::getScriptUrl($web, $topic, "edit") . "?t=". time();
        $_[0] =~ s#<body([^\>]*)>#<body ondblclick="javascript:location.href=\'$url\'" $1>#;
    }
}

1;
