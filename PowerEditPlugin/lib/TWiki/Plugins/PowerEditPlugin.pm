# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2003 Motorola, All Rights Reserved
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

package TWiki::Plugins::PowerEditPlugin;

use vars qw(
        $web $topic $user $installWeb $VERSION $pluginName
        $debug
    );

$VERSION = '1.010';
$pluginName = 'PowerEditPlugin';  # Name of this Plugin

sub initPlugin {
  ( $topic, $web, $user, $installWeb ) = @_;

  # check for Plugins.pm versions
  if( $TWiki::Plugins::VERSION < 1 ) {
    TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
    return 0;
  }

  # Get plugin debug flag
  $debug = TWiki::Func::getPreferencesFlag( "\U$pluginName\E_DEBUG" );

  # Plugin correctly initialized
  TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK" ) if $debug;
  return 1;
}

# Edit handler
sub beforeEditHandler {
  ### my ( $text, $topic, $web ) = @_;
  # do not uncomment, use $_[0], $_[1]... instead

  return if ( TWiki::Func::getSkin() ne "power" );

  TWiki::Func::writeDebug( "- ${pluginName}::beforeEditHandler( $_[2].$_[1] )" ) if $debug;

  # read the applet template
  my $tmpl = TWiki::Func::readTemplate( "applet", TWiki::Func::getSkin());
  $tmpl = TWiki::Func::expandCommonVariables( $tmpl, $topic, $web );

  # Note: DO NOT render the text in the template,
  # as it would munge the applet!

  my $controls = TWiki::Func::getPreferencesValue( "POWEREDIT_CONTROLS" );
  if ( ! $controls ) {
    $controls = TWiki::Func::getTwikiWebname() . ".PowerEditControls";
  }
  $controls =~ /(.*)\.(.*)/;
  $controls = TWiki::Func::readTopicText( $1, $2 );
  # Why can't I poweredit PowerEditControls?
  # Remove comments and meta-tags and compact the text for a parameter
  $controls =~ s/^%META:.*$//gom;
  $controls =~ s/^\s*<.*$//gom;
  $controls =~ s/\s+(\".*\")\s*=\s*(\".*\")/$1=$2/go;
  $controls =~ s/\n+/ /gom;

  # Use CGI to correctly escape parameter values
  my $query = new CGI("");
  $controls = $query->hidden( -name=>"controls", -value=>$controls );
  $tmpl =~ s/%CONTROLS%/$controls/go;

  my $text = $query->hidden( -name=>"text", -value=>$_[0] );
  $tmpl =~ s/%TEXT%/$text/go;

  $_[0] = $tmpl;
}

1;
