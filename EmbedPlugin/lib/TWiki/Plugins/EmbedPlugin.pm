# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2003 Peter Thoeny, peter@thoeny.com
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
# This is an empty TWiki plugin. Use it as a template
# for your own plugins; see TWiki.TWikiPlugins for details.
#
# Each plugin is a package that may contain these functions:        VERSION:
#
#   initPlugin              ( $topic, $web, $user, $installWeb )    1.000
#   initializeUserHandler   ( $loginName, $url, $pathInfo )         1.010
#   registrationHandler     ( $web, $wikiName, $loginName )         1.010
#   commonTagsHandler       ( $text, $topic, $web )                 1.000
#   startRenderingHandler   ( $text, $web )                         1.000
#   outsidePREHandler       ( $text )                               1.000
#   insidePREHandler        ( $text )                               1.000
#   endRenderingHandler     ( $text )                               1.000
#   beforeEditHandler       ( $text, $topic, $web )                 1.010
#   afterEditHandler        ( $text, $topic, $web )                 1.010
#   beforeSaveHandler       ( $text, $topic, $web )                 1.010
#   writeHeaderHandler      ( $query )                              1.010  Use only in one Plugin
#   redirectCgiQueryHandler ( $query, $url )                        1.010  Use only in one Plugin
#   getSessionValueHandler  ( $key )                                1.010  Use only in one Plugin
#   setSessionValueHandler  ( $key, $value )                        1.010  Use only in one Plugin
#
# initPlugin is required, all other are optional. 
# For increased performance, all handlers except initPlugin are
# disabled. To enable a handler remove the leading DISABLE_ from
# the function name. Remove disabled handlers you do not need.
#
# NOTE: To interact with TWiki use the official TWiki functions 
# in the TWiki::Func module. Do not reference any functions or
# variables elsewhere in TWiki!!


# =========================
package TWiki::Plugins::EmbedPlugin;    # change the package name and $pluginName!!!

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $pluginName
        $debug $exampleCfgVar
    );

$VERSION = '1.010';
$pluginName = 'EmbedPlugin';  # Name of this Plugin

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    # Get plugin debug flag
    $debug = TWiki::Func::getPreferencesFlag( "\U$pluginName\E_DEBUG" );

    # Get plugin preferences, the variable defined by:          * Set EXAMPLE = ...
    $exampleCfgVar = &TWiki::Prefs::getPreferencesValue( "EMPTYPLUGIN_EXAMPLE" ) || "default";

    # Plugin correctly initialized
    TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}

# =========================
sub DISABLE_initializeUserHandler
{
### my ( $loginName, $url, $pathInfo ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::initializeUserHandler( $_[0], $_[1] )" ) if $debug;

    # Allows a plugin to set the username based on cookies. Called by TWiki::initialize.
    # Return the user name, or "guest" if not logged in.
    # New hook in TWiki::Plugins $VERSION = '1.010'

}

# =========================
sub DISABLE_registrationHandler
{
### my ( $web, $wikiName, $loginName ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::registrationHandler( $_[0], $_[1] )" ) if $debug;

    # Allows a plugin to set a cookie at time of user registration.
    # Called by the register script.
    # New hook in TWiki::Plugins $VERSION = '1.010'

}

# =========================
sub commonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::commonTagsHandler( $_[2].$_[1] )" ) if $debug;

    # This is the place to define customized tags and variables
    # Called by sub handleCommonTags, after %INCLUDE:"..."%

    # do custom extension rule, like for example:
    # $_[0] =~ s/%XYZ%/&handleXyz()/ge;
    # $_[0] =~ s/%XYZ{(.*?)}%/&handleXyz($1)/ge;

    $_[0] =~ s/%EMBED{(.*?)}%/&handleEmbed($1)/ge;
}

# =========================
sub handleEmbed
{
    my ( $theAttributes ) = @_;
    my $filename = &TWiki::extractNameValuePair($theAttributes, "filename");
    my $width = &TWiki::extractNameValuePair($theAttributes, "width") || 200; 
    my $height = &TWiki::extractNameValuePair($theAttributes, "height") || 42; 
    my $autostart = &TWiki::extractNameValuePair($theAttributes, "autostart") || 1; 

    my $string =<<EOM;
      <OBJECT   ID="MediaPlayer"   WIDTH="$width"   HEIGHT="$height" 
       CLASSID="CLSID:22D6F312-B0F6-11D0-94AB-0080C74C7E95" 
       STANDBY="Loading Windows Media Player components..." 
       TYPE="application/x-oleobject">
       
       <PARAM  NAME="Autostart"  VALUE="$autostart">
       <PARAM  NAME="Filename"  VALUE="$filename">
       <EMBED  TYPE="application/x-mplayer2"  src="$filename" 
       NAME="MediaPlayer"  autostart="$autostart"  WIDTH="$width"  HEIGHT="$height">
       </EMBED>
       </OBJECT>
EOM
     $string =~ s/\n/   /g; # not allowed to have newlines else you get rendering
    return $string;

    return "<OBJECT CLASSID=\"clsid:02BF25D5-8C17-4B23-BC80-D3488ABDDC6B\"
 WIDTH=\"$QTFileWidth\" HEIGHT=\"$QTFileHeight\" 
CODEBASE=\"http://www.apple.com/qtactivex/qtplugin.cab\">
 <EMBED SRC=\"$QTFileName\" AUTOPLAY=\"true\" 
CONTROLLER=\"false\" 
PLUGINSPAGE=\"http://www.apple.com/quicktime/download/\">
 </EMBED>
 </OBJECT>";

}

# =========================
sub DISABLEDstartRenderingHandler
{
### my ( $text, $web ) = @_;   # do not uncomment, use $_[0], $_[1] instead

    TWiki::Func::writeDebug( "- ${pluginName}::startRenderingHandler( $_[1] )" ) if $debug;

    # This handler is called by getRenderedVersion just before the line loop

    # do custom extension rule, like for example:
    # $_[0] =~ s/old/new/g;


}

# =========================
sub DISABLE_outsidePREHandler
{
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

    ##TWiki::Func::writeDebug( "- ${pluginName}::outsidePREHandler( $renderingWeb.$topic )" ) if $debug;

    # This handler is called by getRenderedVersion, once per line, before any changes,
    # for lines outside <pre> and <verbatim> tags. 
    # Use it to define customized rendering rules.
    # Note: This is an expensive function to comment out.
    # Consider startRenderingHandler instead

    # do custom extension rule, like for example:
    # $_[0] =~ s/old/new/g;
}

# =========================
sub DISABLE_insidePREHandler
{
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

    ##TWiki::Func::writeDebug( "- ${pluginName}::insidePREHandler( $web.$topic )" ) if $debug;

    # This handler is called by getRenderedVersion, once per line, before any changes,
    # for lines inside <pre> and <verbatim> tags. 
    # Use it to define customized rendering rules.
    # Note: This is an expensive function to comment out.
    # Consider startRenderingHandler instead

    # do custom extension rule, like for example:
    # $_[0] =~ s/old/new/g;
}

# =========================
sub DISABLE_endRenderingHandler
{
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

    TWiki::Func::writeDebug( "- ${pluginName}::endRenderingHandler( $web.$topic )" ) if $debug;

    # This handler is called by getRenderedVersion just after the line loop, that is,
    # after almost all XHTML rendering of a topic. <nop> tags are removed after this.

}

# =========================
sub DISABLE_beforeEditHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::beforeEditHandler( $_[2].$_[1] )" ) if $debug;

    # This handler is called by the edit script just before presenting the edit text
    # in the edit box. Use it to process the text before editing.
    # New hook in TWiki::Plugins $VERSION = '1.010'

}

# =========================
sub DISABLE_afterEditHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::afterEditHandler( $_[2].$_[1] )" ) if $debug;

    # This handler is called by the preview script just before presenting the text.
    # New hook in TWiki::Plugins $VERSION = '1.010'

}

# =========================
sub DISABLE_beforeSaveHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::beforeSaveHandler( $_[2].$_[1] )" ) if $debug;

    # This handler is called by TWiki::Store::saveTopic just before the save action.
    # New hook in TWiki::Plugins $VERSION = '1.010'

}

# =========================
sub DISABLE_writeHeaderHandler
{
### my ( $query ) = @_;   # do not uncomment, use $_[0] instead

    TWiki::Func::writeDebug( "- ${pluginName}::writeHeaderHandler( query )" ) if $debug;

    # This handler is called by TWiki::writeHeader, just prior to writing header. 
    # Return a single result: A string containing HTTP headers, delimited by CR/LF
    # and with no blank lines. Plugin generated headers may be modified by core
    # code before they are output, to fix bugs or manage caching. Plugins should no
    # longer write headers to standard output.
    # Use only in one Plugin.
    # New hook in TWiki::Plugins $VERSION = '1.010'

}

# =========================
sub DISABLE_redirectCgiQueryHandler
{
### my ( $query, $url ) = @_;   # do not uncomment, use $_[0], $_[1] instead

    TWiki::Func::writeDebug( "- ${pluginName}::redirectCgiQueryHandler( query, $_[1] )" ) if $debug;

    # This handler is called by TWiki::redirect. Use it to overload TWiki's internal redirect.
    # Use only in one Plugin.
    # New hook in TWiki::Plugins $VERSION = '1.010'

}

# =========================
sub DISABLE_getSessionValueHandler
{
### my ( $key ) = @_;   # do not uncomment, use $_[0] instead

    TWiki::Func::writeDebug( "- ${pluginName}::getSessionValueHandler( $_[0] )" ) if $debug;

    # This handler is called by TWiki::getSessionValue. Return the value of a key.
    # Use only in one Plugin.
    # New hook in TWiki::Plugins $VERSION = '1.010'

}

# =========================
sub DISABLE_setSessionValueHandler
{
### my ( $key, $value ) = @_;   # do not uncomment, use $_[0], $_[1] instead

    TWiki::Func::writeDebug( "- ${pluginName}::setSessionValueHandler( $_[0], $_[1] )" ) if $debug;

    # This handler is called by TWiki::setSessionValue. 
    # Use only in one Plugin.
    # New hook in TWiki::Plugins $VERSION = '1.010'

}

# =========================

1;
