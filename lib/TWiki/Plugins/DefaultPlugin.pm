#
# TWiki WikiClone ($wikiversion has version info)
#
# Copyright (C) 2000-2001 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001 Peter Thoeny, Peter@Thoeny.com
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
# This is the default TWiki plugin. Use EmptyPlugin.pm as a template
# for your own plugins; see TWiki.TWikiPlugins for details.
#
# Each plugin is a package that contains the subs:
#
#   initPlugin           ( $topic, $web, $user, $installWeb )
#   commonTagsHandler    ( $text, $topic, $web )
#   startRenderingHandler( $text, $web )
#   outsidePREHandler    ( $text )
#   insidePREHandler     ( $text )
#   endRenderingHandler  ( $text )
#
# initPlugin is required, all other are optional. 
# For increased performance, DISABLE handlers you don't need.
#
# NOTE: To interact with TWiki use the official TWiki functions 
# in the &TWiki::Func module. Do not reference any functions or
# variables elsewhere in TWiki!!


# =========================
package TWiki::Plugins::DefaultPlugin;

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $debug
        $doOldInclude $renderingWeb
    );

$VERSION = '1.000';

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1 ) {
        &TWiki::Func::writeWarning( "Version mismatch between DefaultPlugin and Plugins.pm" );
        return 0;
    }

    # Get plugin preferences
    $doOldInclude = &TWiki::Func::getPreferencesFlag( "DEFAULTPLUGIN_OLDINCLUDE" ) || "";

    # Get plugin debug flag
    $debug = &TWiki::Func::getPreferencesFlag( "DEFAULTPLUGIN_DEBUG" );

    $renderingWeb = $web;

    # Plugin correctly initialized
    &TWiki::Func::writeDebug( "- TWiki::Plugins::DefaultPlugin::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}

# =========================
sub commonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    &TWiki::Func::writeDebug( "- DefaultPlugin::commonTagsHandler( $_[2].$_[1] )" ) if $debug;

    # This is the place to define customized tags and variables
    # Called by sub handleCommonTags, after %INCLUDE:"..."%

    # for compatibility for earlier TWiki versions:
    if( $doOldInclude ) {
        # allow two level includes
        $_[0] =~ s/%INCLUDE:"([^%\"]*?)"%/&TWiki::handleIncludeFile( $1, $_[1], $_[2], "" )/geo;
        $_[0] =~ s/%INCLUDE:"([^%\"]*?)"%/&TWiki::handleIncludeFile( $1, $_[1], $_[2], "" )/geo;
    }

    # do custom extension rule, like for example:
    # $_[0] =~ s/%WIKIWEB%/$TWiki::wikiToolName.$web/go;
}

# =========================
sub startRenderingHandler
{
### my ( $text, $web ) = @_;   # do not uncomment, use $_[0], $_[1] instead

    &TWiki::Func::writeDebug( "- DefaultPlugin::startRenderingHandler( $_[1] )" ) if $debug;

    # This handler is called by getRenderedVersion just before the line loop

    $renderingWeb = $_[1];
}

# =========================
sub outsidePREHandler
{
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

    &TWiki::Func::writeDebug( "- DefaultPlugin::outsidePREHandler( $renderingWeb.$topic )" ) if $debug;

    # This handler is called by getRenderedVersion, in loop outside of <PRE> tag
    # This is the place to define customized rendering rules

    # do custom extension rule, like for example:
    # $_[0] =~ s/old/new/go;

    # render depreciated *_text_* as "bold italic" text:
    $_[0] =~ s/(^|\s)\*_([^\s].*?[^\s])_\*(\s|$)/$1<STRONG><EM>$2<\/EM><\/STRONG>$3/go;

    # Use alternate %Web:WikiName% syntax (versus the standard Web.WikiName).
    # This is an old JosWiki render option. (Uncomment for JosWiki compatibility)
#   $_[0] =~ s/(^|\s|\()\%([^\s].*?[^\s]):([^\s].*?[^\s])\%/&TWiki::internalLink($2,$3,"$2:$3",$1,1)/geo;

    # Use "forced" non-WikiName links (i.e. %Linkname%)
    # This is an old JosWiki render option. (Uncomment for JosWiki compatibility)
#   $_[0] =~ s/(^|\s|\()\%([^\s].*?[^\s])\%/&TWiki::internalLink($web,$2,$2,$1,1)/geo;

    # Use "forced" non-WikiName links (i.e. %Web.Linkname%)
    # This is an old JosWiki render option combined with the new Web.LinkName notation
    # (Uncomment for JosWiki compatibility)
#   $_[0] =~ s/(^|\s|\()\%([a-zA-Z0-9]+)\.(.*?[^\s])\%(\s|\)|$)/&TWiki::internalLink($2,$3,$3,$1,1)/geo;
}

# =========================
sub DISABLE_insidePREHandler
{
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

    &TWiki::Func::writeDebug( "- DefaultPlugin::insidePREHandler( $web.$topic )" ) if $debug;

    # This handler is called by getRenderedVersion, in loop inside of <PRE> tag
    # This is the place to define customized rendering rules

    # do custom extension rule, like for example:
    # $_[0] =~ s/old/new/go;
}

# =========================
sub DISABLE_endRenderingHandler
{
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

    &TWiki::Func::writeDebug( "- DefaultPlugin::endRenderingHandler( $web.$topic )" ) if $debug;

    # This handler is called by getRenderedVersion just after the line loop

}

# =========================

1;


