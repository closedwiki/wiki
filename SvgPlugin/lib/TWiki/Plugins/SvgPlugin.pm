# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2004 Antonio Terceiro, asaterceiro@inf.ufrgs.br
# Copyright (C) 2008-2011 TWiki Contributors
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
package TWiki::Plugins::SvgPlugin;

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $RELEASE $pluginName
        $debug $defaultSize
    );

use Image::LibRSVG;

$VERSION = '$Rev$';
$RELEASE = '2011-04-06';

$pluginName = 'SvgPlugin';  # Name of this Plugin

# =========================
sub initPlugin
{
  ( $topic, $web, $user, $installWeb ) = @_;

  # check for Plugins.pm versions
  if( $TWiki::Plugins::VERSION < 1.000 ) {
      TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
      return 0;
  }

  # Get plugin debug flag
  $debug = TWiki::Func::getPluginPreferencesFlag("DEBUG");

  # get a default size for pictures
  $defaultSize = TWiki::Func::getPluginPreferencesValue("DEFAULTSIZE");
  if (not($defaultSize =~ m/([0-9]+)x([0-9]+)/))
  {
    $defaultSize = "320x200";
  }

  # Plugin correctly initialized
  TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK" ) if $debug;
  return 1;
}

# =========================
sub commonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

  TWiki::Func::writeDebug( "- ${pluginName}::commonTagsHandler( $_[2].$_[1] )" ) if $debug;

  $_[0] =~ s/%SVG{(.*?)}%/&handleSvg($1,$_[1],$_[2])/ge;
}

sub SvgPluginError
{
  my ($arg) = @_;
  return "<span style='background: #FFFFCC; color: red; text-decoration: underline;'><strong>$pluginName:</strong> $arg</span>";
}

sub handleSvg
{
  my ($args,$topic,$web) = @_;

  # which drawing would we convert?
  my $drawing;
  if ($args =~ m/^"([^"]+)"/)
  {
    $drawing = $1;
  }
  else
  {
    return SvgPluginError("you must specify a drawing to display!");
  }

  #where is the drawing?
  my $where;
  if ($args =~ m/topic="(([^\.]+)\.)?([^"]+)"/)
  {
    if ($2)
    {
      # given a complete topic name, i.e. Web.TheTopic
      $where = "$2/$3";
    }
    else
    {
      # given only a topic name, use current web.
      $where = "$web/$3";
    }
  }
  else
  {
    # nothing given, use current topic
    $where = "$web/$topic";
  }

  # calculate size of the generated image:
  my ($width,$height);
  if ($args =~ m/size="([0-9]+)x([0-9]+)"/)
  {
    $width = $1;
    $height = $2;
  }
  else
  {
    $defaultSize =~ m/([0-9]+)x([0-9]+)/;
    $width = $1;
    $height = $2;
  }

  #get the base name for the generated file:
  my $basename = $drawing;
  $basename =~ s/.svg//;
  
  # source file
  my $fromFilename = TWiki::Func::getPubDir() . "/$where/$drawing";

  # destination file
  my $picture = "$basename-$width" . "x$height.png";
  my $toFilename = TWiki::Func::getPubDir() . "/$where/$picture";
  my $pictureUrl = TWiki::Func::getUrlHost()
                   . TWiki::Func::getPubUrlPath()
                   . "/$where/$picture";

  if (not (-e $fromFilename))
  {
    return SvgPluginError("can't find drawing !$drawing attched at $where.");
  }

  my $svgAge = (-M $fromFilename);
  my $pngAge = (-M $toFilename);

  # (re)generate, if PNG doesn't exist yet or if PNG is older than SVG
  if ((not defined $pngAge) or ($pngAge > $svgAge))
  {
    my $rsvg = new Image::LibRSVG();
    $rsvg->convertAtMaxSize($fromFilename, $toFilename, $width, $height);
  }
 
  return $pictureUrl;
}

# ==========================
1;
