# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2005-2006 MichaelDaum@WikiRing.com
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

package TWiki::Plugins::DBCachePlugin;

use strict;
use vars qw( 
  $VERSION $RELEASE $currentWeb $currentTopic $currentUser $isInitialized
);

$VERSION = '$Rev$';
$RELEASE = '1.22';

###############################################################################
# plugin initializer
sub initPlugin {
  ($currentTopic, $currentWeb, $currentUser) = @_;

  # check for Plugins.pm versions
  if ($TWiki::Plugins::VERSION < 1.1) {
    return 0;
  }
  
  TWiki::Func::registerTagHandler('DBQUERY', \&_DBQUERY);
  TWiki::Func::registerTagHandler('DBCALL', \&_DBCALL);
  TWiki::Func::registerTagHandler('DBSTATS', \&_DBSTATS);
  TWiki::Func::registerTagHandler('DBDUMP', \&_DBDUMP); # for debugging

  $isInitialized = 0;

  return 1;
}

###############################################################################
sub initCore {
  return if $isInitialized;
  $isInitialized = 1;

  eval 'use TWiki::Plugins::DBCachePlugin::Core;';
  die $@ if $@;

  my $isScripted = &TWiki::Func::getContext()->{'command_line'};
  unless ($isScripted) {
    my $query = &TWiki::Func::getCgiQuery();
    my $theAction = $ENV{'SCRIPT_NAME'} || '';
    if ($theAction =~ /^.*\/(save|rename|attach|upload)/) {
      # force reload
      %TWiki::Plugins::DBCachePlugin::Core::webDB = ();
    }
  }

  # We don't initialize the webDB hash on every request, see getDB()!
  #%TWiki::Plugins::DBCachePlugin::Core::webDB = ();# uncomment if you don't trust 

  %TWiki::Plugins::DBCachePlugin::Core::webDBIsModified = ();

  $TWiki::Plugins::DBCachePlugin::Core::wikiWordRegex = 
    TWiki::Func::getRegularExpression('wikiWordRegex');
  $TWiki::Plugins::DBCachePlugin::Core::webNameRegex = 
    TWiki::Func::getRegularExpression('webNameRegex');
  $TWiki::Plugins::DBCachePlugin::Core::defaultWebNameRegex = 
    TWiki::Func::getRegularExpression('defaultWebNameRegex');
  $TWiki::Plugins::DBCachePlugin::Core::linkProtocolPattern = 
    TWiki::Func::getRegularExpression('linkProtocolPattern');
}

###############################################################################
# twiki handlers
sub afterSaveHandler {
  initCore();
  return TWiki::Plugins::DBCachePlugin::Core::afterSaveHandler(@_);
}

###############################################################################
# tags
sub _DBQUERY {
  initCore();
  return TWiki::Plugins::DBCachePlugin::Core::handleDBQUERY(@_);
}
sub _DBCALL {
  initCore();
  return TWiki::Plugins::DBCachePlugin::Core::handleDBCALL(@_);
}
sub _DBSTATS {
  initCore();
  return TWiki::Plugins::DBCachePlugin::Core::handleDBSTATS(@_);
}
sub _DBDUMP {
  initCore();
  return TWiki::Plugins::DBCachePlugin::Core::handleDBDUMP(@_);
}

###############################################################################
# perl api
sub getDB {
  initCore();
  return TWiki::Plugins::DBCachePlugin::Core::getDB(@_);
}

###############################################################################
1;
