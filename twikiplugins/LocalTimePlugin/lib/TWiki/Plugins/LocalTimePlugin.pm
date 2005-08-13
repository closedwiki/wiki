# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2003 Peter Thoeny, peter@thoeny.com
# Copyright (C) 2003      Nathan Ollerenshaw, chrome@stupendous.net
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


# =========================
package TWiki::Plugins::LocalTimePlugin;

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $pluginName
        $debug $exampleCfgVar
    );

$VERSION = '1.000';
$pluginName = 'LocalTimePlugin';  # Name of this Plugin

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1 ) {
        TWiki::Func::writeWarning( "Version mismatch between LocalTimePlugin and Plugins.pm" );
        return 0;
    }

    # Get plugin debug flag
    $debug = TWiki::Func::getPreferencesFlag( "LOCALTIMEPLUGIN_DEBUG" );

    # Get plugin preferences, the variable defined by:          * Set EXAMPLE = ...
    $timezone = &TWiki::Func::getPreferencesValue( "LOCALTIMEPLUGIN_TIMEZONE" ) || "Asia/Tokyo";

    # Plugin correctly initialized
    TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}

# =========================
sub commonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::commonTagsHandler( $_[2].$_[1] )" ) if $debug;

    $_[0] =~ s/%LOCALTIME%/&handleLocalTime($timezone)/geo;
    $_[0] =~ s/%LOCALTIME{(.*?)}%/&handleLocalTime($1)/geo;
}
# =========================

sub handleLocalTime {
		# Note the distinct lack of error handling.

        use Date::Handler;

		my $tz = shift;
		
		my $date = new Date::Handler({ date => time, time_zone => $tz });

        return sprintf '%s, %d %s %d,  %02d:%02d:%02d (%s)', 
					$date->WeekDayName(),
					$date->Day(),
					$date->MonthName(),
					$date->Year(),
					$date->Hour(),
					$date->Min(),
					$date->Sec(),
					$date->TimeZone();
}

1;
