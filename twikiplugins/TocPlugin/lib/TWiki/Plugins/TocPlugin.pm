#
# TWiki WikiClone ($wikiversion has version info)
#
# Copyright (C) 2001 Motorola
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
# This is the plugin interface to the Motorola TOC package
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
# NOTE: To interact with TWiki use the official TWiki functions
# in the &TWiki::Func module. Do not reference any functions or
# variables elsewhere in TWiki!!

# =========================
package TWiki::Plugins::TocPlugin;

use TWiki::Plugins::TocPlugin::TOCIF;
use TWiki::Plugins::TocPlugin::TOC;

# =========================
use vars qw(
            $web $topic $user $installWeb $VERSION $debug
            $wif
           );

$VERSION = '$Rev$';

# =========================
sub initPlugin
{
  ( $topic, $web, $user, $installWeb ) = @_;

  # check for Plugins.pm versions
  if( $TWiki::Plugins::VERSION < 1 ) {
    &TWiki::Func::writeWarning( "Version mismatch between TocPlugin and Plugins.pm" );
    return 0;
  }

  # Get plugin debug flag
  $debug = &TWiki::Func::getPreferencesFlag( "TOCPLUGIN_DEBUG" );

  $wif = TOCIF->getInterface($web, $topic);

  # Plugin correctly initialized
  &TWiki::Func::writeDebug( "- TWiki::Plugins::TocPlugin::initPlugin( $web.$topic ) is OK" ) if $debug;
  return 1;
}

# =========================
sub DISABLE_commonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

#  &TWiki::Func::writeDebug( "- TocPlugin::commonTagsHandler( $_[2].$_[1] )" ) if $debug;

  # This is the place to define customized tags and variables
  # Called by sub handleCommonTags, after %INCLUDE:"..."%

  # do custom extension rule, like for example:
  # $_[0] =~ s/%XYZ%/&handleXyz()/geo;
  # $_[0] =~ s/%XYZ{(.*?)}%/&handleXyz($1)/geo;
}

# =========================
sub startRenderingHandler
{
### my ( $text, $web ) = @_;   # do not uncomment, use $_[0], $_[1] instead

#  &TWiki::Func::writeDebug( "- TocPlugin::startRenderingHandler( $_[1].$topic )" ) if $debug;

  # This handler is called by getRenderedVersion just before the line loop

  # do custom extension rule, like for example:
  # $_[0] =~ s/old/new/go;
  $_[0] = TOC::processTopic($wif, $web, $topic, $_[0]);
}

# =========================
sub DISABLE_outsidePREHandler
{
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

#  &TWiki::Func::writeDebug( "- TocPlugin::outsidePREHandler( $web.$topic )" ) if $debug;

  # This handler is called by getRenderedVersion, in loop outside of <PRE> tag.
  # This is the place to define customized rendering rules.
  # Note: This is an expensive function to comment out.
  # Consider startRenderingHandler instead
}

# =========================
sub DISABLE_insidePREHandler
{
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

#   &TWiki::Func::writeDebug( "- TocPlugin::insidePREHandler( $web.$topic )" ) if $debug;

    # This handler is called by getRenderedVersion, in loop inside of <PRE> tag.
    # This is the place to define customized rendering rules.
    # Note: This is an expensive function to comment out.
    # Consider startRenderingHandler instead
}

# =========================
sub DISABLE_endRenderingHandler
{
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

  &TWiki::Func::writeDebug( "- TocPlugin::endRenderingHandler( $web.$topic )" ) if $debug;

  # This handler is called by getRenderedVersion just after the line loop
  $_[0] = TOC::processTopic($wif, $web, $topic, $_[0]);
}

# =========================

1;
