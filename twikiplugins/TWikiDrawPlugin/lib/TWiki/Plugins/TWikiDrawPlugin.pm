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
# For increased performance, all handlers except initPlugin are
# disabled. To enable a handler remove the leading DISABLE_ from
# the function name.
# 
# NOTE: To interact with TWiki use the official TWiki functions
# in the &TWiki::Func module. Do not reference any functions or
# variables elsewhere in TWiki!!


# =========================
package TWiki::Plugins::TWikiDrawPlugin; 	# change the package name!!!

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $debug $editButton
    );

$VERSION = '1.000';

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1 ) {
        &TWiki::Func::writeWarning( "Version mismatch between TWikiDrawPlugin and Plugins.pm" );
        return 0;
    }

    # Get plugin debug flag
    $debug = &TWiki::Func::getPreferencesFlag( "TWIKIDRAWPLUGIN_DEBUG" );
    $editButton = &TWiki::Func::getPreferencesValue( "TWIKIDRAWPLUGIN_EDIT_BUTTON" );

    # Plugin correctly initialized
    &TWiki::Func::writeDebug( "- TWiki::Plugins::TWikiDrawPlugin::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}

sub handleDrawing
{
    my( $attributes, $topic, $web ) = @_;
    my $nameVal = TWiki::Func::extractNameValuePair( $attributes );
    if( ! $nameVal ) {
        $nameVal = "untitled";
    }
    $nameVal =~ s/[^A-Za-z0-9_\.\-]//go; # delete special characters

    # should really use TWiki server-side include mechanism....
    my $mapFile = TWiki::Func::getPubDir() . "/$web/$topic/$nameVal.map";
    my $img = "src=\"%ATTACHURLPATH%/$nameVal.gif\"";
    my $editUrl =
      TWiki::Func::getOopsUrl($web, $topic, "twikidraw", $nameVal);
    my $imgText = "";

    if ( -e $mapFile ) {
      my $name = $nameVal;
      $name =~ s/^.*\/([^\/]+)$/$1/o;
      $img .= " usemap=\"#$name\"";
      my $map = TWiki::Func::readFile($mapFile);
      $map = TWiki::Func::expandCommonVariables( $map, $topic );
      $map =~ s/%MAPNAME%/$name/go;
      $map =~ s/%TWIKIDRAW%/$editUrl/go;

      # Add an edit link just above the image if required
      $imgText = "<br><a href=\"$editUrl\">Edit image</a><br>" if ( $editButton == 1 );

      $imgText .= "<img $img>\n$map";
    } else {
      # insensitive drawing; the whole image gets a rather more
      # decorative version of the edit URL
      $imgText = "<a href=\"$editUrl\" ".
	  "onMouseOver=\"".
	    "window.status='Edit drawing [$nameVal] using ".
	      "TWiki Draw applet (requires a Java 1.1 enabled browser)';" .
		"return true;\"".
		  "onMouseOut=\"".
		    "window.status='';".
		      "return true;\">".
			"<img $img ".
			  "alt=\"Edit drawing '$nameVal' ".
			    "(requires a Java enabled browser)\"></a>\n";
    }
    return $imgText;
}

# =========================
sub commonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    &TWiki::Func::writeDebug( "- TWikiDrawPlugin::commonTagsHandler( $_[2].$_[1] )" ) if $debug;

    # This is the place to define customized tags and variables
    # Called by sub handleCommonTags, after %INCLUDE:"..."%

    # do custom extension rule, like for example:
    # $_[0] =~ s/%XYZ%/&handleXyz()/geo;
    # $_[0] =~ s/%XYZ{(.*?)}%/&handleXyz($1)/geo;
    $_[0] =~ s/%DRAWING{(.*?)}%/&handleDrawing($1, $_[1], $_[2])/geo;
    $_[0] =~ s/%DRAWING%/&handleDrawing("untitled", $_[1], $_[2])/geo;
}

# =========================
sub DISABLE_startRenderingHandler
{
### my ( $text, $web ) = @_;   # do not uncomment, use $_[0], $_[1] instead

    &TWiki::Func::writeDebug( "- TWikiDrawPlugin::startRenderingHandler( $_[1].$topic )" ) if $debug;

    # This handler is called by getRenderedVersion just before the line loop

    # do custom extension rule, like for example:
    # $_[0] =~ s/old/new/go;
}

# =========================
sub DISABLE_outsidePREHandler
{
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

#   &TWiki::Func::writeDebug( "- TWikiDrawPlugin::outsidePREHandler( $web.$topic )" ) if $debug;

    # This handler is called by getRenderedVersion, in loop outside of <PRE> tag.
    # This is the place to define customized rendering rules.
    # Note: This is an expensive function to comment out.
    # Consider startRenderingHandler instead
}

# =========================
sub DISABLE_insidePREHandler
{
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

#   &TWiki::Func::writeDebug( "- TWikiDrawPlugin::insidePREHandler( $web.$topic )" ) if $debug;

    # This handler is called by getRenderedVersion, in loop inside of <PRE> tag.
    # This is the place to define customized rendering rules.
    # Note: This is an expensive function to comment out.
    # Consider startRenderingHandler instead
}

# =========================
sub DISABLE_endRenderingHandler
{
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

    &TWiki::Func::writeDebug( "- TWikiDrawPlugin::endRenderingHandler( $web.$topic )" ) if $debug;

    # This handler is called by getRenderedVersion just after the line loop

}

# =========================

1;
