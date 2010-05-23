# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2001-2010 Peter Thoeny, peter@thoeny.org
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html
#
# As per the GPL, removal of this notice is prohibited.
#
# =========================
#
# This is TWiki's Spreadsheet Plugin.
#

package TWiki::Plugins::SpreadSheetPlugin;


# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $RELEASE $debug $skipInclude $doInit
    );

# Plugin version
$VERSION = '$Rev$';
$RELEASE = '2010-05-22';

$doInit = 0;

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1 ) {
        TWiki::Func::writeWarning( "Version mismatch between SpreadSheetPlugin and Plugins.pm" );
        return 0;
    }

    # Get plugin debug flag
    $debug = TWiki::Func::getPreferencesFlag( "SPREADSHEETPLUGIN_DEBUG" );

    # Flag to skip calc if in include
    $skipInclude = TWiki::Func::getPreferencesFlag( "SPREADSHEETPLUGIN_SKIPINCLUDE" );

    # Plugin correctly initialized
    TWiki::Func::writeDebug( "- TWiki::Plugins::SpreadSheetPlugin::initPlugin( $web.$topic ) is OK" ) if $debug;
    $doInit = 1;
    return 1;
}

# =========================
sub commonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- SpreadSheetPlugin::commonTagsHandler( $_[2].$_[1] )" ) if $debug;

    if( ( $_[3] ) && ( $skipInclude ) ) {
        # bail out, handler called from an %INCLUDE{}%
        return;
    }
    unless( $_[0] =~ /%CALC\{.*?\}%/ ) {
        # nothing to do
        return;
    }

    require TWiki::Plugins::SpreadSheetPlugin::Calc;

    if( $doInit ) {
        $doInit = 0;
        TWiki::Plugins::SpreadSheetPlugin::Calc::init( $web, $topic, $debug );
    }
    TWiki::Plugins::SpreadSheetPlugin::Calc::CALC( @_ );
}

1;

# EOF
