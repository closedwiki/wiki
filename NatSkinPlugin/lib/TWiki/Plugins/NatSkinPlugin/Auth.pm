###############################################################################
# TWiki WikiClone ($wikiversion has version info)
#
# Copyright (C) 2005 Michael Daum <micha@nats.informatik.uni-hamurg.de>
#
# Based on photonsearch
# Copyright (C) 2001 Esteban Manchado Velázquez, zoso@foton.es
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
###############################################################################
package TWiki::Plugins::NatSkinPlugin::Auth;

use strict;
use vars qw($isInitialized $debug $defaultWikiUserName);
use TWiki::Plugins::NatSkinPlugin;

###############################################################################
sub writeDebug {
  TWiki::Func::writeDebug("- NatSkinPlugin::Auth - " . $_[0]) if $debug;
}

##############################################################################
sub doInit {
  return if $isInitialized;
  $isInitialized = 1;
  $debug = 0; # toggle me

  writeDebug("called doInit");

  $defaultWikiUserName = &TWiki::Func::getDefaultUserName();
  $defaultWikiUserName = &TWiki::Func::userToWikiName($defaultWikiUserName, 1);
}

###############################################################################
sub logon {
  my ($query, $topic, $web) = @_;

  &doInit();
  writeDebug("called logon");


  my $thePathInfo = $query->path_info(); 
  my $theRemoteUser = $query->remote_user();
  my $theUrl = $query->url;
  my $theUser = $query->param('username');
  my $theWeb = $query->param('web') || $web;
  my $theTopic = $query->param('topic') || $topic;
  my $theAction = $query->param('action') || "view";
  my $thePasswd = $query->param('password');

  if (!$theUser && !$thePasswd) {
    $theUrl = &TWiki::Func::getOopsUrl($theWeb, $theTopic, "oopslogon");
    &TWiki::Func::redirectCgiQuery($query, $theUrl);
    writeDebug("redirecting to oopslogon");
    return;
  }
  
  # check if required fields are filled in
  if(!$theUser || (!$thePasswd && $theUser ne $defaultWikiUserName))  {
    $theUrl = &TWiki::Func::getOopsUrl($theWeb, $theTopic, "oopsregrequ");
    &TWiki::Func::redirectCgiQuery($query, $theUrl);
    writeDebug("redirecting to oopsregrequ");
    return;
  }

  # init the NatSkinPlugin explicitely
  &TWiki::Plugins::NatSkinPlugin::doInit();

  # check for existing user
  if (!&_existsUser($theUser)) {
    $theUrl = &TWiki::Func::getOopsUrl($theWeb, $theTopic, "oopsnotwikiuser", $theUser);
    &TWiki::Func::redirectCgiQuery($query, $theUrl);
    writeDebug("redirecting to oopsnotwikiuser");
    return;
  }

  # check password
  if ($theUser ne $defaultWikiUserName) {
    if (!&_checkPasswd($theUser, $thePasswd)) {
      $theUrl = &TWiki::Func::getOopsUrl($theWeb, $theTopic, "oopswrongpassword");
      &_setAuthUser($defaultWikiUserName);
      &TWiki::Func::redirectCgiQuery($query, $theUrl);
      writeDebug("redirecting to oopswrongpassword");
      return;
    }
  }

  # allright, go on 
  my $mainWeb = &TWiki::Func::getMainWebname();
  if ($theUser eq $defaultWikiUserName) {
    # logout
    $theUrl = &TWiki::Func::getScriptUrl($theWeb, $theTopic, $theAction);
    #$theUrl =~ s/^https:/http:/o; SMELL SMELL SMELL 
  } else {
    # logon
    #&_getPrefsFromTopic($mainWeb, $theUser);
    my $logonWebTopic = &TWiki::Func::getPreferencesValue("LOGONTOPIC");
    my $logonWeb = $theWeb;
    my $logonTopic = $theTopic;
    
    if ($logonWebTopic && $logonWebTopic ne 'current') { 
      if ($logonWebTopic =~ /^(.*)\.(.*)$/) {
	$logonWeb = $1;
	$logonTopic = $2;
      } else {
	$logonTopic = $logonWebTopic;
      }
    }

    writeDebug("logonWeb=$logonWeb, logonTopic=$logonTopic");
    $theUrl = &TWiki::Func::getScriptUrl($logonWeb, $logonTopic, $theAction);
  }

  &_setAuthUser($theUser);
  writeDebug("setting AUTHUSER to $theUser");
  &TWiki::Func::redirectCgiQuery($query, $theUrl);
  writeDebug("done logon");
}

###############################################################################
sub _existsUser {
  my $theUser = shift;

  writeDebug("called _existsUser");

  # beijing
  if ($TWiki::Plugins::NatSkinPlugin::isBeijing) {
    return &TWiki::Access::htpasswdExistUser($theUser);
  } 

  # dakar
  if ($TWiki::Plugins::NatSkinPlugin::isDakar) {
    return $TWiki::Plugins::SESSION->{users}->findUser($theUser, undef, 1);
  }
  
  # well ... cairo ?
  return &TWiki::User::UserPasswordExists($theUser);
}

###############################################################################
sub _checkPasswd {
  my ($theUser, $thePasswd) = @_;

  writeDebug("called _checkPasswd");

  # beijing
  if ($TWiki::Plugins::NatSkinPlugin::isBeijing) {
    my $oldcrypt = &TWiki::Access::htpasswdReadPasswd($theUser);
    return &TWiki::Access::htpasswdCheckPasswd($thePasswd, $oldcrypt);
  } 

  # dakar
  if ($TWiki::Plugins::NatSkinPlugin::isDakar) {
    require TWiki::Users::HtPasswdUser;
    my $htPasswdUser = new TWiki::Users::HtPasswdUser($TWiki::Plugins::SESSION);
    return $htPasswdUser->checkPassword($theUser, $thePasswd);
  }
  
  # well ... cairo ?
  return &TWiki::User::CheckUserPasswd($theUser, $thePasswd);
}

###############################################################################
sub _setAuthUser {
  my $theUser = shift;

  if ($TWiki::Plugins::NatSkinPlugin::isDakar) {
    $theUser = undef if $theUser eq $defaultWikiUserName;
    $TWiki::Plugins::SESSION->{client}->userLoggedIn($theUser);
  } else {
    eval 'require TWiki::Plugins::SessionPlugin';
    my $authUserSessionVar = $TWiki::Plugins::SessionPlugin::authUserSessionVar;
    my $session = $TWiki::Plugins::SessionPlugin::session;
    if ($theUser eq $defaultWikiUserName) {
      $session->clear($authUserSessionVar);
    }  else {
      $session->param($authUserSessionVar, $theUser);
    }
    $session->flush();
  }
}

###############################################################################
sub _getPrefsFromTopic {
  my ($thisWeb, $thisUser) = @_;

  # dakar
  if ($TWiki::Plugins::NatSkinPlugin::isDakar) {
    $TWiki::Plugins::SESSION->{prefs}->getPrefsFromTopic($thisWeb, $thisUser);
  } 
  
  # non-dakar
  else {
    &TWiki::Prefs::getPrefsFromTopic($thisWeb, $thisUser);
  }
}

1;
