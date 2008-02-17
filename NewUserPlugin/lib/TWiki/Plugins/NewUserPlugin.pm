# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2006-2008 Michael Daum http://michaeldaumconsulting.com
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

###############################################################################
package TWiki::Plugins::NewUserPlugin;

use strict;
use vars qw( $VERSION $RELEASE $SHORTDESCRIPTION $NO_PREFS_IN_TOPIC $done);

use constant DEBUG => 0; # toggle me

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';
$RELEASE = 'v1.04';
$SHORTDESCRIPTION = 'Create a user topic if it does not exist yet';
$NO_PREFS_IN_TOPIC = 1;

###############################################################################
sub writeDebug {
  #print STDERR 'NewUserPlugin - '.$_[0]."\n" if DEBUG;
  TWiki::Func::writeDebug("NewUserPlugin - $_[0]") if DEBUG;
}

###############################################################################
sub writeWarning {
  writeDebug('WARNING: '.$_[0]);
  TWiki::Func::writeWarning("NewUserPlugin - ".$_[0]);
}

###############################################################################
sub initPlugin {
#  my ($topic, $web, $user) = @_;

  $done = 0;
  return 1;
}

###############################################################################
# unfortunately we can't use the initializeUserHandler as TWiki is not 
# fully initialized then. even the beforeCommonTagsHandler get's called in
# a half-init state in the middle of TWiki::new. so we have to wait for
# the TWiki object to be fully initialized, i.e. its i18n subsystem
sub beforeCommonTagsHandler {
  return if !defined($TWiki::Plugins::SESSION->{i18n}) || $done;
  $done = 1;

  writeDebug("called beforeCommonTagsHandler");

  my $wikiUserName = TWiki::Func::getWikiUserName();
  my $mainWeb = TWiki::Func::getMainWebname();

  return if TWiki::Func::topicExists($mainWeb, $wikiUserName);

  writeDebug("NO home topic found for $wikiUserName");
  createUserTopic($wikiUserName)
}

###############################################################################
# creates a user topic for the given wikiUserName
sub createUserTopic {
  my $wikiUserName = shift;

  my $twikiWeb = TWiki::Func::getTwikiWebname();
  my $mainWeb = TWiki::Func::getMainWebname();
  my $newUserTemplate = 
    TWiki::Func::getPreferencesValue('NEWUSERTEMPLATE') || 'NewLdapUserTemplate';
  my $tmplTopic;
  my $tmplWeb;

  # search the NEWUSERTEMPLATE 
  $newUserTemplate =~ s/^\s+//go;
  $newUserTemplate =~ s/\s+$//go;
  $newUserTemplate =~ s/\%TWIKIWEB\%/$twikiWeb/g;
  $newUserTemplate =~ s/\%SYSTEMWEB\%/$twikiWeb/g;
  $newUserTemplate =~ s/\%MAINWEB\%/$mainWeb/g;

  # in Main
  ($tmplWeb, $tmplTopic) = 
    TWiki::Func::normalizeWebTopicName($mainWeb, $newUserTemplate);

  unless (TWiki::Func::topicExists($tmplWeb, $tmplTopic)) {

    # in TWiki
    ($tmplWeb, $tmplTopic) = 
      TWiki::Func::normalizeWebTopicName($twikiWeb, $newUserTemplate);

    unless (TWiki::Func::topicExists($tmplWeb, $tmplTopic)) {
      writeWarning("no new user template found"); # not found
      return;
    }
  }

  writeDebug("newusertemplate = $tmplWeb.$tmplTopic");

  # read the template
  my $text = TWiki::Func::readTopicText($tmplWeb, $tmplTopic);
  unless ($text) {
    writeWarning("can't read $tmplWeb.$tmplTopic");
    return;
  }

  # insert data
  my $wikiName = TWiki::Func::getWikiName();
  my $loginName = TWiki::Func::wikiToUserName($wikiName);
  $text =~ s/\$nop//go;
  $text =~ s/\%WIKINAME\%/$wikiName/go;
  $text =~ s/\%USERNAME\%/$loginName/go;
  $text =~ s/\%WIKIUSERNAME\%/$wikiUserName/go;

  writeDebug("saving new home topic $mainWeb.$wikiName");
  my $errorMsg = TWiki::Func::saveTopicText($mainWeb, $wikiName, $text);

  if ($errorMsg) {
    writeWarning("error during save of $tmplWeb.$tmplTopic: $errorMsg");
  }
}

1;
