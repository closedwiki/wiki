# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2006 Craig Meyer, meyercr@gmail.com
# Copyright (C) 2006-2008 Michael Daum http://michaeldaumconsulting.com
# Copyright (C) 2006-2010 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root of
# this distribution.
#
# Based on ImgPlugin
# Copyright (C) 2006 Meredith Lesly, msnomer@spamcop.net
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

package TWiki::Plugins::ImagePlugin;

use strict;
use vars qw( $VERSION $RELEASE $doneHeader $imageCore $imgStyle $baseWeb $baseTopic);

$VERSION = '$Rev$';
$RELEASE = '2010-08-01';

###############################################################################
sub initPlugin {
  ($baseTopic, $baseWeb) = @_;

  # check for Plugins.pm versions
  if( $TWiki::Plugins::VERSION < 1.026 ) {
    TWiki::Func::writeWarning( "Version mismatch between ImagePlugin and Plugins.pm" );
    return 0;
  }

  # init plugin variables
  $imageCore = undef;
  $doneHeader = 0;
  $imgStyle = 
    '<link rel="stylesheet" '.
    'href="%PUBURL%/%TWIKIWEB%/ImagePlugin/style.css" '.
    'type="text/css" media="all" />';


  # register the tag handlers
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
  return $imageCore if $imageCore;
  
  eval 'use TWiki::Plugins::ImagePlugin::Core;';
  die $@ if $@;

  $imageCore = new TWiki::Plugins::ImagePlugin::Core(@_);
  return $imageCore;
}

###############################################################################
# schedule tag handlers
sub _IMAGE { getCore($baseWeb, $baseTopic)->handleIMAGE(@_); }

1;

