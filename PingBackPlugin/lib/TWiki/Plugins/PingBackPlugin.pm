# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2006 MichaelDaum@WikiRing.com
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
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

package TWiki::Plugins::PingBackPlugin;

use strict;
use vars qw( $VERSION $RELEASE 
  $currentWeb $currentTopic $currentUser
);

$VERSION = '$Rev$';
$RELEASE = 'v0.02';

use TWiki::Contrib::XmlRpcContrib;

###############################################################################
sub initPlugin {
  ($currentTopic, $currentWeb, $currentUser) = @_;

  # check for Plugins.pm versions
  if ($TWiki::Plugins::VERSION < 1.026) {
    TWiki::Func::writeWarning( "Version mismatch between PingBackPlugin and Plugins.pm" );
    return 0;
  }

  TWiki::Func::registerTagHandler('PINGBACK', \&handlePingbackTag);
  TWiki::Contrib::XmlRpcContrib::registerXMLHandler('pingback.ping', \&handlePingbackCall);

  my $xmlRpcUrl = TWiki::Func::getScriptUrl($currentWeb, $currentTopic, 'xmlrpc');

  TWiki::Func::addToHEAD('PINGBACKPLUGIN_LINK',
    "\n<link rel=\"pingback\" href=\"$xmlRpcUrl\" />\n");

  # Plugin correctly initialized
  return 1;
}

###############################################################################
sub handlePingbackTag {

  eval 'use TWiki::Plugins::PingBackPlugin::Core';
  die $@ if $@;

  return TWiki::Plugins::PingBackPlugin::Core::handlePingbackTag(@_);
}

###############################################################################
sub handlePingbackCall {

  eval 'use TWiki::Plugins::PingBackPlugin::Core';
  die $@ if $@;

  return TWiki::Plugins::PingBackPlugin::Core::handlePingbackCall(@_);
}

1;
