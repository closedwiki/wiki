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
# This is an empty TWiki plugin. Use it as a template
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
# For increased performance, DISABLE (or comment) handlers you don't need.

# =========================
package TWiki::Plugins::EmptyPlugin; 	# change the package name!!!

# =========================
use vars qw( $web $topic $user $installWeb $myConfigVar );

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # Get plugin preferences
    $myConfigVar = &TWiki::Prefs::getPreferencesFlag( "EMPTYPLUGIN_VAR1" ) || "";
}

# =========================
sub commonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

#    print "DefaultPlugin::commonTagsHandler called<br>";

    # This is the place to define customized tags and variables
    # Called by sub handleCommonTags, after %INCLUDE:"..."%

}

# =========================
sub startRenderingHandler
{
### my ( $text, $web ) = @_;   # do not uncomment, use $_[0], $_[1] instead

#    print "DefaultPlugin::startRenderingHandler called<br>";

    # This handler is called by getRenderedVersion just before the line loop

}

# =========================
sub outsidePREHandler
{
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

#    print "DefaultPlugin::outsidePREHandler called<br>";

    # This handler is called by getRenderedVersion, in loop outside of <PRE> tag
    # This is the place to define customized rendering rules

}

# =========================
sub insidePREHandler
{
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

#    print "DefaultPlugin::insidePREHandler called<br>";

    # This handler is called by getRenderedVersion, in loop inside of <PRE> tag
    # This is the place to define customized rendering rules

}

# =========================
sub endRenderingHandler
{
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

#    print "DefaultPlugin::endRenderingHandler called<br>";

    # This handler is called by getRenderedVersion just after the line loop

}

# =========================

1;


