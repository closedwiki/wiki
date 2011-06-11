# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2007 Karl Kaiser kkaiser@bentosys.com
#
# Credit: This plugin was derived from the 
#         ExitPlugin of Ian Bygrave, ian@bygrave.me.uk 
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
# This plugin shortens long URLs to a length of your choice.

# =========================
package TWiki::Plugins::ShortURLPlugin;

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $pluginName
        $debug $disable $urlmaxlen $schemepat
    );

$VERSION = '$Revision: 002 $';
$pluginName = 'ShortURLPlugin';  # Name of this Plugin

# =========================

sub patFromPref
{
    return
        "(?:" .
        join( "|",
              map( quotemeta, split( /\s+/, TWiki::Func::getPluginPreferencesValue( $_[0] ) ) ) )
        . ")" ;
}

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.001 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    # Get plugin debug flag
    $debug = TWiki::Func::getPluginPreferencesFlag( "DEBUG" );
    TWiki::Func::writeDebug( "- ${pluginName} debug  = ${debug}" ) if $debug; 
	
    # Get disable flag
    $disable = TWiki::Func::getPluginPreferencesFlag( "DISABLE" );
    TWiki::Func::writeDebug( "- ${pluginName} disable = ${disable}" ) if $debug;
	
    # Get schemes to redirect
    $schemepat = patFromPref("SCHEMES");
    TWiki::Func::writeDebug( "- ${pluginName} schemepat = ${schemepat}" ) if $debug;

    # Get Maximal URL Length
    $urlmaxlen = TWiki::Func::getPluginPreferencesValue( "URLMAXLENGTH" );
    TWiki::Func::writeDebug( "- ${pluginName} urlmaxlen = ${urlmaxlen}" ) if $debug;
    
    # Plugin correctly initialized
    TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}

# =========================

sub linkreplace
{
    my ( $pretags, $url, $posttags, $text, $close ) = @_;

if ( length($text) > $urlmaxlen && $url eq $text ) {
    	substr($text,($urlmaxlen/2)-2,length($text)-$urlmaxlen+3,'...');
	}

return $pretags.$url.$posttags.$text.$close;
}

$TWikiCompatibility{endRenderingHandler} = 1.1;
sub endRenderingHandler
{
    &postRenderingHandler;
}

sub postRenderingHandler {
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead
    if ( $disable ) {
        TWiki::Func::writeDebug( "- ${pluginName}::endRenderingHandler(disabled by SHORTURLPLUGIN_DISABLE)" ) if $debug;
        return;
    }
    TWiki::Func::writeDebug( "- ${pluginName} text = ${text}" ) if $debug;

    # This handler is called by getRenderedVersion just after the line loop, that is,
    # after almost all XHTML rendering of a topic. <nop> tags are removed after this.
    $_[0] =~ s/(<a\s+[^>]*?href=")($schemepat:\/\/[^"]+)("[^>]*>)(.*?)(<\/a>)/&linkreplace($1,$2,$3,$4,$5)/isgeo;
}

# =========================

1;
