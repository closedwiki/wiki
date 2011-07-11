# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2011 e-Ecosystems Inc
# Copyright (C) 2011 TWiki Contributors
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

package TWiki::Plugins::UsageStatisticsPlugin;


# =========================
our $VERSION = '$Rev$';
our $RELEASE = '2011-07-10';

my $debug = 0;
my $core;

# =========================
sub initPlugin
{
    my ( $topic, $web ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.2 ) {
        TWiki::Func::writeWarning( "Version mismatch between UsageStatisticsPlugin and Plugins.pm" );
        return 0;
    }

    # Get plugin debug flag
    $debug = TWiki::Func::getPreferencesFlag( "USAGESTATISTICSPLUGIN_DEBUG" );

    TWiki::Func::registerTagHandler( 'USAGESTATISTICS', \&_USAGESTATISTICS );

    # Plugin correctly initialized
    TWiki::Func::writeDebug( "- TWiki::Plugins::UsageStatisticsPlugin::initPlugin( $web.$topic ) is OK" ) if $debug;

    return 1;
}

# =========================
sub _USAGESTATISTICS
{
#   my ( $session, $params, $theTopic, $theWeb ) = @_;

    # Lazy loading, e.g. compile core module only when needed
    unless( $core ) {
        require TWiki::Plugins::UsageStatisticsPlugin::Core;
        $core = new TWiki::Plugins::UsageStatisticsPlugin::Core( $debug );
    }
    return $core->VarUSAGESTATISTICS( @_ );
}

# =========================
1;
