# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2005 Michael Daum <micha@nats.informatik.uni-hamburg.de>
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

package TWiki::Plugins::UserInfoPlugin;
use strict;

###############################################################################
use vars qw(
	$web $topic $user $installWeb $VERSION $RELEASE $debug 
	$twikiGuest 
	$isInitialized $sessionDir
);
require TWiki::Plugins::UserInfoPlugin::Render ;
require TWiki::Plugins::UserInfoPlugin::Get ;

# This should always be $Rev: 8773$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in ACTIVATED_PLUGINS.
$RELEASE = '2.0 Dakar Specific';

###############################################################################
sub writeDebug {
  &TWiki::Func::writeDebug("- UserInfoPlugin - " . $_[0]) if $debug;
}

###############################################################################
sub writeWarning {
  &TWiki::Func::writeWarning("- UserInfoPlugin - " . $_[0]);
}

###############################################################################
sub initPlugin {
  ($topic, $web, $user, $installWeb) = @_;

  # check for Plugins.pm versions
  if ($TWiki::Plugins::VERSION < 1) {
    &TWiki::Func::writeWarning ("Version mismatch between UserInfoPlugin and Plugins.pm");
    return 0;
  }

  $debug = 0;
  $isInitialized = 0;

  # plugin correctly initialized
  &writeDebug("initPlugin ($web.$topic) is OK");

  return 1;
}

###############################################################################
sub commonTagsHandler {

	
  $_[0] =~ s/%VISITORS%/&TWiki::Plugins::UserInfoPlugin::Render::renderCurrentVisitors()/ge;
  $_[0] =~ s/%VISITORS{(.*?)}%/&TWiki::Plugins::UserInfoPlugin::Render::renderCurrentVisitors($1)/ge;
  $_[0] =~ s/%NRVISITORS%/&TWiki::Plugins::UserInfoPlugin::Get::getNrVisitors()/ge;

  $_[0] =~ s/%LASTVISITORS%/&TWiki::Plugins::UserInfoPlugin::Render::renderLastVisitors()/ge;
  $_[0] =~ s/%LASTVISITORS{(.*?)}%/&TWiki::Plugins::UserInfoPlugin::Render::renderLastVisitors($1)/ge;
  $_[0] =~ s/%NRLASTVISITORS%/&TWiki::Plugins::UserInfoPlugin::Get::getNrLastVisitors()/ge;
  $_[0] =~ s/%NRLASTVISITORS{(.*?)}%/&TWiki::Plugins::UserInfoPlugin::Get::getNrLastVisitors($1)/ge;

  $_[0] =~ s/%NRUSERS%/&TWiki::Plugins::UserInfoPlugin::Get::getNrUsers()/ge;
  $_[0] =~ s/%NRGUESTS%/&TWiki::Plugins::UserInfoPlugin::Get::getNrGuests()/ge;

  $_[0] =~ s/%NEWUSERS%/&TWiki::Plugins::UserInfoPlugin::Render::renderNewUsers()/ge;
  $_[0] =~ s/%NEWUSERS{(.*?)}%/&TWiki::Plugins::UserInfoPlugin::Render::renderNewUsers($1)/ge;

}


1;

