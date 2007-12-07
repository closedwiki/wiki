# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2006 Michael Daum http://wikiring.com
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

package TWiki::Plugins::ClassificationPlugin;

use strict;
use TWiki::Plugins::ClassificationPlugin::Core;

use vars qw( 
  $VERSION $RELEASE $NO_PREFS_IN_TOPIC $SHORTDESCRIPTION
  $doneHeader
);

$VERSION = '$Rev$';
$RELEASE = '0.40';
$NO_PREFS_IN_TOPIC = 1;
$SHORTDESCRIPTION = 'A topic classification plugin and application';

###############################################################################
sub initPlugin {
  my ($baseTopic, $baseWeb) = @_;

  TWiki::Func::registerTagHandler('BROWSECAT', 
    \&TWiki::Plugins::ClassificationPlugin::Core::handleBrowseCat);
  TWiki::Func::registerTagHandler('ISA', 
    \&TWiki::Plugins::ClassificationPlugin::Core::handleIsA);
  TWiki::Func::registerTagHandler('SUBSUMES', 
    \&TWiki::Plugins::ClassificationPlugin::Core::handleSubsumes);
  TWiki::Func::registerTagHandler('CATFIELD', 
    \&TWiki::Plugins::ClassificationPlugin::Core::handleCatField);
  TWiki::Func::registerTagHandler('TAGFIELD', 
    \&TWiki::Plugins::ClassificationPlugin::Core::handleTagField);
  TWiki::Func::registerTagHandler('TAGRELATEDTOPICS', 
    \&TWiki::Plugins::ClassificationPlugin::Core::handleTagRelatedTopics);
  TWiki::Func::registerTagHandler('CATINFO', 
    \&TWiki::Plugins::ClassificationPlugin::Core::handleCatInfo);
  TWiki::Func::registerTagHandler('TAGINFO', 
    \&TWiki::Plugins::ClassificationPlugin::Core::handleTagInfo);
  TWiki::Func::registerTagHandler('DISTANCE', 
    \&TWiki::Plugins::ClassificationPlugin::Core::handleDistance);

  TWiki::Plugins::ClassificationPlugin::Core::init($baseWeb, $baseTopic);
  $doneHeader = 0;
  return 1;
}

###############################################################################
sub commonTagsHandler {

  return if $doneHeader;

  my $link = 
    '<link rel="stylesheet" '.
    'href="%PUBURL%/%TWIKIWEB%/ClassificationPlugin/styles.css" '.
    'type="text/css" media="all" />' . "\n" .
    '<script type="text/javascript" ' .
    'src="%PUBURL%/%TWIKIWEB%/ClassificationPlugin/classification.js">' .
    '</script>';
  
  if ($_[0] =~ s/<head>(.*?[\r\n]+)/<head>$1$link\n/o) {
    $doneHeader = 1;
  }
}

###############################################################################
sub beforeSaveHandler {
  return TWiki::Plugins::ClassificationPlugin::Core::beforeSaveHandler(@_);
}

###############################################################################
sub afterSaveHandler {
  return TWiki::Plugins::ClassificationPlugin::Core::afterSaveHandler(@_);
}

###############################################################################
# SMELL: I'd prefer a proper finishHandler, alas it does not exist
sub modifyHeaderHandler {
  TWiki::Plugins::ClassificationPlugin::Core::finish(@_);
}

###############################################################################
sub renderFormFieldForEditHandler {
  return TWiki::Plugins::ClassificationPlugin::Core::renderFormFieldForEditHandler(@_);
}

###############################################################################
# perl api
sub getHierarchy {
  return TWiki::Plugins::ClassificationPlugin::Core::getHierarchy(@_);
}

1;
