# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2001-2011 Peter Thoeny, peter[at]thoeny.org
#
# For licensing info read LICENSE file in the TWiki root.
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
# As per the GPL, removal of this notice is prohibited.
#
# =========================
#
# This TWiki plugin displays the current local time of many
# cities around the world in a TWiki topic.
# Based on 4.4BSD-style zoneinfo files or on
# http://TWiki.org/cgi-bin/xtra/x?tz= time and date gateway
#
# initPlugin is required, all other are optional.

# =========================
package TWiki::Plugins::LocalCityTimePlugin;

# =========================
our $VERSION = '$Rev$';
our $RELEASE = '2011-07-13';

# Plugin configuration
my $tzDir     = '/usr/share/zoneinfo';                     # root dir of zone info files
my $dateCmd   = '/bin/date';                               # path to date command
my $dateParam = "'+\%a, \%d \%b \%Y \%T \%z \%Z'";         # RFC-822 compliant date format
                                                           # Example: Fri, 14 Nov 2003 23:46:52 -0800 PST
my $gatewayUrl   = "http://TWiki.org/cgi-bin/xtra/tzdate"; # URL of date and time gateway
my $gatewayParam = "?tz=";                                 # parameter of date and time gateway
my $useDateCmd;
my $debug;

# =========================
sub initPlugin
{
    my ( $topic, $web ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1 ) {
        &TWiki::Func::writeWarning( "Version mismatch between LocalCityTimePlugin and Plugins.pm" );
        return 0;
    }

    # Get plugin debug flag
    $debug = &TWiki::Func::getPreferencesFlag( "LOCALCITYTIMEPLUGIN_DEBUG" );

    # Flag to use external date command
    $useDateCmd = &TWiki::Func::getPreferencesFlag( "LOCALCITYTIMEPLUGIN_USEDATECOMMAND" );

    # Plugin correctly initialized
    &TWiki::Func::writeDebug( "- TWiki::Plugins::LocalCityTimePlugin::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}

# =========================
sub commonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    &TWiki::Func::writeDebug( "- LocalCityTimePlugin::commonTagsHandler( $_[2].$_[1] )" ) if $debug;
    $_[0] =~ s/%LOCALCITYTIME{(.*?)}%/&handleCityTime($1)/geo;
    $_[0] =~ s/%LOCALCITYTIME%/&handleCityTime("")/geo;
}

# =========================
sub handleCityTime
{
    my ( $theAttr ) = @_;

    my $text = "";
    my $timeZone = &TWiki::Func::extractNameValuePair( $theAttr );
    $timeZone =~ s/[^\w\-\/\_\+]//gos;
    unless( $timeZone ) {
        # return help
        return '%SYSTEMWEB%.LocalCityTimePlugin help: Write a Continent/City timezone code listed in '
             . $gatewayUrl . ', such as %<nop>LOCALCITYTIME{"Europe/Zurich"}%';
    }

    # try date command and zoneinfo file
    if( $useDateCmd && -d $tzDir && -f $dateCmd ) {
        my $tz = $tzDir . "/" . $timeZone;
        &TWiki::Func::writeDebug( "- LocalCityTimePlugin::handleCityTime: Try zoneinfo file $tz" ) if $debug;
        unless( -f $tz ) {
            return '%SYSTEMWEB%.LocalCityTimePlugin warning: '
                 . "Invalid Timezone '$timeZone'. Use a Continent/City timezone code "
                 . "listed in $gatewayUrl, such as %<nop>LOCALCITYTIME{\"Europe/Zurich\"}%";
        }
        my $saveTZ = $ENV{'TZ'};       # save timezone
        $ENV{'TZ'} = $tz;
        $text = `$dateCmd $dateParam`;
        chomp( $text );
        $ENV{'TZ'} = $saveTZ;          # restore TZ environment
        &TWiki::Func::writeDebug( "- LocalCityTimePlugin::handleCityTime: date cmd returns $text" ) if $debug;
        $text .= " (<a href=\"$gatewayUrl$gatewayParam$timeZone\">$timeZone</a>)";
        return $text;
    }

    # else fall back to slower time & date gateway
    &TWiki::Func::writeDebug( "- LocalCityTimePlugin: getUrl $gatewayUrl$gatewayParam$timeZone" ) if $debug;
    $text = &TWiki::Func::expandCommonVariables( "\%INCLUDE{\"$gatewayUrl$gatewayParam$timeZone\"}\%\n" );
    # &TWiki::Func::writeDebug( "- LocalCityTimePlugin::hand: getUrl has: $text" ) if $debug;

    if( $text =~ /Invalid Timezone/ ) {
        return '%SYSTEMWEB%.LocalCityTimePlugin warning: '
             . "Invalid Timezone '$timeZone'. Use a Continent/City timezone code "
             . "listed in $gatewayUrl, e.g. %<nop>LOCALCITYTIME{\"Europe/Zurich\"}%";
    }
    $text =~ s/.*<!\-\-tzdate:date\-\->(.*?)<\!\-\-\/tzdate:date\-\->.*/$1/os;
    unless( $1 ) {
        return '%SYSTEMWEB%.LocalCityTimePlugin error: '
             . "Can't read $gatewayUrl$gatewayParam$timeZone (due to a "
             . "proxy problem?), or received data has invalid format (due to change in web page layout?).";
    }
    &TWiki::Func::writeDebug( "- LocalCityTimePlugin::handleCityTime: gateway returns <<$text>>" ) if $debug;
    $text .= " (<a href=\"$gatewayUrl$gatewayParam$timeZone\">$timeZone</a>)";

    return $text;
}

# =========================

1;
