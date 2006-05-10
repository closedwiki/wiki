# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2006 Meredith Lesly, msnomer@spamcop.net
#
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# For licensing info read LICENSE file in the TWiki root.

package TWiki::Plugins::ImgPlugin;

use strict;

use vars qw( $VERSION $RELEASE $imgCore $doneHeader $imgStyle $baseWeb $baseTopic);

$VERSION = '$Rev$';
$RELEASE = 'Dakar';

###############################################################################
sub initPlugin {
  ($baseTopic, $baseWeb) = @_;

  # check for Plugins.pm versions
  if( $TWiki::Plugins::VERSION < 1.026 ) {
    TWiki::Func::writeWarning( "Version mismatch between ImgPlugin and Plugins.pm" );
    return 0;
  }

  # init plugin variables
  $imgCore = undef;
  $doneHeader = 0;
  $imgStyle = TWiki::Func::getPreferencesValue('IMGPLUGIN_STYLE') ||
    '%PUBURL%/%TWIKIWEB%/ImgPlugin/ImgPlugin.css';
  $imgStyle = 
    '<link rel="stylesheet" '.
    'href="'.$imgStyle.'" '.
    'type="text/css" media="all" />';


  # register the tag handlers
  TWiki::Func::registerTagHandler( 'IMG', \&_IMG);
  TWiki::Func::registerTagHandler( 'IMAGE', \&_IMAGE);

  # Plugin correctly initialized
  return 1;
} 

###############################################################################
# only used to insert the link style
sub commonTagsHandler {
  return if $doneHeader;

  if ($_[0] =~ s/<head>(.*?[\r\n]+)/<head>$1$imgStyle\n/o) {
    $doneHeader = 1;
  }
}

###############################################################################
# lazy initializer
sub getCore {
  return $imgCore if $imgCore;
  
  eval 'use TWiki::Plugins::ImgPlugin::Core;';
  die $@ if $@;

  $imgCore = new TWiki::Plugins::ImgPlugin::Core(@_);
  return $imgCore;
}

###############################################################################
# schedule tag handlers
sub _IMG { getCore($baseWeb, $baseTopic)->handleIMG(@_); }
sub _IMAGE { getCore($baseWeb, $baseTopic)->handleIMAGE(@_); }

###############################################################################
1;

