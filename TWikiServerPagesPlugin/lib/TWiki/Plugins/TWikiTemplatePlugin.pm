# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2010 Peter Thoeny, peter@thoeny.org and TWiki
# Contributors.
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
# This is TWiki's Template Plugin.

package TWiki::Plugins::TWikiTemplatePlugin;


# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $RELEASE $debug
    );

# Plugin version
$VERSION = '$Rev$';
$RELEASE = '2010-06-29';

$moduleLoaded = 0;

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1 ) {
        TWiki::Func::writeWarning( "Version mismatch between TWikiTemplatePlugin and Plugins.pm" );
        return 0;
    }

    # Get plugin debug flag
    $debug = TWiki::Func::getPreferencesFlag( "TWIKITEMPLATEPLUGIN_DEBUG" );

    TWiki::Func::registerTagHandler( 'GET',    \&_GET );
    TWiki::Func::registerTagHandler( 'SET',    \&_SET );

    # Plugin correctly initialized
    TWiki::Func::writeDebug( "- TWiki::Plugins::TWikiTemplatePlugin::initPlugin( $web.$topic ) is OK" ) if $debug;
    $doInit = 1;
    return 1;
}

# =========================
sub _GET
{
#   my ( $session, $params, $theTopic, $theWeb ) = @_;
    require TWiki::Plugins::TWikiTemplatePlugin::Core;
    return  TWiki::Plugins::TWikiTemplatePlugin::Core::VarGET( @_ );
}

# =========================
sub _SET
{
#   my ( $session, $params, $theTopic, $theWeb ) = @_;
    require TWiki::Plugins::TWikiTemplatePlugin::Core;
    return  TWiki::Plugins::TWikiTemplatePlugin::Core::VarSET( @_ );
}

1;

# EOF
