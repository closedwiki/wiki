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
            $web $topic $user $installWeb $VERSION $debug
            $query $renderingWeb
            $mishooHome
    );

$VERSION = '1.024';
$encodeStart = '--EditTableEncodeStart--';
$encodeEnd   = '--EditTableEncodeEnd--';

sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1 ) {
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

    $mishooHome = "%PUBURL%/$installWeb/JSCalendarContrib";

    return 1;
}

sub commonTagsHandler {
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    # Add style sheet for date calendar to skin if needed.
    # Handling of the common tags is done separately for the topic text and view skin
    # The following if statement must be done before the early escape.
    #
    # NOTE:
    # When adding a new button to the table that needs the table to be in the edit mode,
    # be sure to add it below.
    if( ( $_[0] =~ m/^[<][!]DOCTYPE/ ) &&
        ( $query->param( 'etedit' ) || $query->param( 'etaddrow' ) || $query->param( 'etdelrow') ) &&
        (!($_[0] =~ m/calendar-system/) ) ) {

        my $string = " <link type=\"text/css\" rel=\"stylesheet\""
                   . " href=\"$mishooHome/calendar-system.css\" />\n";
        $_[0] =~ s/([<]\/head[>])/$string$1/i;
    }

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

    # WindRiver specific hack to remove SprPlugin rendering
    $theText =~ s/<a href="[\w\/]*sprreport[^>]*>(.*?) (.*?)<\/a>/$1$2/goi;

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
