# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2006 Ian Bygrave, ian@bygrave.me.uk
# Copyright (C) 2006-2010 TWiki:TWiki.TWikiContributor
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
# This plugin redirects links to external sites via a page of your choice.

# =========================
package TWiki::Plugins::ExitPlugin;

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSIONi $RELEASE $pluginName
        $debug $disable $initStage $redirectVia $noExit $preMark $postMark $marksInLink $schemepat
    );

$VERSION = '1.6';
$RELEASE = '2010-12-12';
$pluginName = 'ExitPlugin';  # Name of this Plugin

# =========================

sub patFromPref
{
    return
        "(?:" .
        join( "|",
              map( quotemeta, split( /\s+/, TWiki::Func::getPluginPreferencesValue( $_[0] ) ) ) )
        . ")" ;
}

sub partInit
{
# Partial initialization
# stage 0:
#  uninitialized
# stage 1:
#  enough for endRenderingHandler
#  set $debug $schemepat
# stage 2:
#  enough for linkreplace without link rewriting
#  set $noExit
# stage 3:
#  enough for link rewriting
#  load URI::Escape
#  set $redirectVia, $preMark, $postMark, $marksInLink

    return if ($_[0] > 3);

    while ( $initStage < $_[0] ) {

        if ( $initStage == 0 ) {

            # Get plugin debug flag
            $debug = TWiki::Func::getPluginPreferencesFlag( "DEBUG" );

            # Get disable flag
            $disable = TWiki::Func::getPreferencesFlag( "EXITPLUGIN_DISABLEEXITPLUGIN" ) ||
                TWiki::Func::getPreferencesFlag( "DISABLEEXITPLUGIN" );
            TWiki::Func::writeDebug( "- ${pluginName} disable = ${disable}" ) if $debug;

            # Get schemes to redirect
            $schemepat = patFromPref("SCHEMES");
            TWiki::Func::writeDebug( "- ${pluginName} schemepat = ${schemepat}" ) if $debug;

            $initStage = 1;

        } elsif ( $initStage == 1 ) {

            # Get exempt link targets
            $noExit = patFromPref("NOEXIT");
            TWiki::Func::writeDebug( "- ${pluginName} noExit = ${noExit}" ) if $debug;

            $initStage = 2;

        } elsif ( $initStage == 2 ) {

            # Get redirect page
            $redirectVia = TWiki::Func::getPluginPreferencesValue( "REDIRECTVIA" );
            $redirectVia = TWiki::Func::expandCommonVariables( $redirectVia, $topic, $web );
            TWiki::Func::writeDebug( "- ${pluginName} redirectVia = ${redirectVia}" ) if $debug;

            # Get pre- and post- marks
            $preMark = TWiki::Func::getPluginPreferencesValue( "PREMARK" ) || "";
            $preMark = TWiki::Func::expandCommonVariables( $preMark, $topic, $web );
            TWiki::Func::writeDebug( "- ${pluginName} preMark = ${preMark}" ) if $debug;
            $postMark = TWiki::Func::getPluginPreferencesValue( "POSTMARK" ) || "";
            $postMark = TWiki::Func::expandCommonVariables( $postMark, $topic, $web );
            TWiki::Func::writeDebug( "- ${pluginName} postMark = ${postMark}" ) if $debug;

            # Get marksInLink flag
            $marksInLink = TWiki::Func::getPluginPreferencesFlag( "MARKSINLINK" );

            eval { require URI::Escape };

            $initStage = 3;

        }

    }
    return;
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

    $initStage = 0;
    partInit(1);

    # Plugin correctly initialized
    TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}

# =========================

sub linkreplace
{
    my ( $open, $pretags, $url, $posttags, $text, $close ) = @_;
    partInit(2);
    # Is this an exit link?
    if ( !($url =~ /^\w+:\/\/[\w\.]*?$noExit(?:\/.*)?$/o)) {
        partInit(3);
        $url =~ s/( ?) *<\/?(nop|noautolink)\/?>\n?/$1/gois; # Remove <nop> tags.
        $url = URI::Escape::uri_escape($url);
        if ( $marksInLink ) {
            return $open." class='exitlink'".$pretags.$redirectVia.$url.$posttags.$preMark.$text.$postMark.$close;
        } else {
            return $preMark.$open." class='exitlink'".$pretags.$redirectVia.$url.$posttags.$text.$close.$postMark;
        }
    }
    return $open.$pretags.$url.$posttags.$text.$close;
}

$TWikiCompatibility{endRenderingHandler} = 1.1;
sub endRenderingHandler
{
    &postRenderingHandler;
}

sub postRenderingHandler {
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead
    if ( $disable ) {
        TWiki::Func::writeDebug( "- ${pluginName}::endRenderingHandler(disabled by DISABLEEXITPLUGIN)" ) if $debug;
        return;
    }
    TWiki::Func::writeDebug( "- ${pluginName}::endRenderingHandler( $web.$topic )" ) if $debug;

    # This handler is called by getRenderedVersion just after the line loop, that is,
    # after almost all XHTML rendering of a topic. <nop> tags are removed after this.
    $_[0] =~ s/(<a)(\s+[^>]*?href=")($schemepat:\/\/[^"]+)("[^>]*>)(.*?)(<\/a>)/&linkreplace($1,$2,$3,$4,$5,$6)/isgeo;
}

# =========================

1;
