#
# TWiki WikiClone ($wikiversion has version info)
#
# Copyright (C) 2002-2004 Peter Thoeny, Peter@Thoeny.com
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
# This is the EditTablePlugin used to edit tables in place.
#

package TWiki::Plugins::EditTablePlugin;

use vars qw(
            $web $topic $user $VERSION $debug
            $query $renderingWeb
    );

$VERSION = '$Rev$';
$encodeStart = '--EditTableEncodeStart--';
$encodeEnd   = '--EditTableEncodeEnd--';

sub initPlugin {
    ( $topic, $web ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning( "Version mismatch between EditTablePlugin and Plugins.pm" );
        return 0;
    }

    $query = TWiki::Func::getCgiQuery();
    if( ! $query ) {
        return 0;
    }

    # Get plugin debug flag
    $debug = TWiki::Func::getPreferencesFlag( 'EDITTABLEPLUGIN_DEBUG' );

    $prefsInitialized = 0;
    $renderingWeb = $web;

    # Plugin correctly initialized
    TWiki::Func::writeDebug( "- TWiki::Plugins::EditTablePlugin::initPlugin( $web.$topic ) is OK" ) if $debug;

    # Initialize $table such that the code will correctly detect when to
    # read in a topic.
    undef $table;

    return 1;
}

sub commonTagsHandler {
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    return unless $_[0] =~ /%EDIT(TABLE|CELL){(.*)}%/os;

    require TWiki::Plugins::EditTablePlugin::Core;

    TWiki::Plugins::EditTablePlugin::Core::process( @_ );
}

sub postRenderingHandler {
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

    $_[0] =~ s/$encodeStart(.*?)$encodeEnd/decodeValue($1)/geos;
}

sub encodeValue {
    my( $theText ) = @_;

    # FIXME: *very* crude encoding to escape Wiki rendering inside form fields
    $theText =~ s/\./%dot%/gos;
    $theText =~ s/(.)/\.$1/gos;

    # convert <br /> markup to unicode linebreak character for text areas
    $theText =~ s/.<.b.r. .\/.>/&#10;/gos;
    return $encodeStart.$theText.$encodeEnd;
}

sub decodeValue {
    my( $theText ) = @_;

    $theText =~ s/\.(.)/$1/gos;
    $theText =~ s/%dot%/\./gos;
    $theText =~ s/\&([^#a-z])/&amp;$1/go; # escape non-entities
    $theText =~ s/</\&lt;/go;             # change < to entity
    $theText =~ s/>/\&gt;/go;             # change > to entity
    $theText =~ s/\"/\&quot;/go;          # change " to entity

    return $theText;
}

1;
