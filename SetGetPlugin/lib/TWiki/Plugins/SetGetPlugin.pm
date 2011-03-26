# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2010-2011 Peter Thoeny, peter@thoeny.org
# Copyright (C) 2010-2011 TWiki Contributors
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
# This is the TWiki SET/GET Plugin.

package TWiki::Plugins::SetGetPlugin;


# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $RELEASE $debug $core
    );

# Plugin version
$VERSION = '$Rev$';
$RELEASE = '2011-11-26';

$moduleLoaded = 0;

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1 ) {
        TWiki::Func::writeWarning( "Version mismatch between SetGetPlugin and Plugins.pm" );
        return 0;
    }

    # Get plugin debug flag
    $debug = TWiki::Func::getPreferencesFlag( "SETGETPLUGIN_DEBUG" );

    TWiki::Func::registerTagHandler( 'GET',    \&_GET );
    TWiki::Func::registerTagHandler( 'SET',    \&_SET );

    # Plugin correctly initialized
    TWiki::Func::writeDebug( "- TWiki::Plugins::SetGetPlugin::initPlugin( $web.$topic ) is OK" ) if $debug;

    return 1;
}

# =========================
sub _GET
{
#   my ( $session, $params, $theTopic, $theWeb ) = @_;

    # Lazy loading, e.g. compile core module only when required
    unless( $core ) {
        require TWiki::Plugins::SetGetPlugin::Core;
        $core = new TWiki::Plugins::SetGetPlugin::Core( $debug );
    }
    return $core->VarGET( @_ );
}

# =========================
sub _SET
{
#   my ( $session, $params, $theTopic, $theWeb ) = @_;

    # Lazy loading, e.g. compile core module only when required
    unless( $core ) {
        require TWiki::Plugins::SetGetPlugin::Core;
        $core = new TWiki::Plugins::SetGetPlugin::Core( $debug );
    }
    return $core->VarSET( @_ );
}

# =========================
1;
