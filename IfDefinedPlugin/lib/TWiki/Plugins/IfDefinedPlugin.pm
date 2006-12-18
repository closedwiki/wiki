# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2006 Michael Daum <micha@nats.informatik.uni-hamburg.de>
#
# Based on the NatSkinPlugin
# Copyright (C) 2003-2006 Michael Daum <micha@nats.informatik.uni-hamburg.de>
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

package TWiki::Plugins::IfDefinedPlugin;

use strict;
use vars qw( 
  $VERSION $RELEASE $debug 
  $currentAction 
  $currentWeb $currentTopic
  $NO_PREFS_IN_TOPIC $SHORTDESCRIPTION
);

$VERSION = '$Rev$';
$RELEASE = 'v0.96';
$NO_PREFS_IN_TOPIC = 1;
$SHORTDESCRIPTION = 'Render content conditionally';
$debug = 0; # toggle me

###############################################################################
sub writeDebug {
  #&TWiki::Func::writeDebug('- IfDefinedPlugin - '.$_[0]) if $debug;
  print STDERR '- IfDefinedPlugin - '.$_[0]."\n" if $debug;
}

###############################################################################
sub initPlugin {
  ($currentTopic, $currentWeb) = @_;

  $currentAction = undef;
  return 1;
}

###############################################################################
sub commonTagsHandler {
  $_[0] =~ s/(\s*)%IFDEFINED{(.*?)}%(\s*)/&renderIfDefined($2, $1, $3)/geos;
  $_[0] =~ s/(\s*)%IFACCESS{(.*?)}%(\s*)/&renderIfAccess($2, $1, $3)/geos;
  while ($_[0] =~ s/(\s*)%IFDEFINEDTHEN{(?!.*%IFDEFINEDTHEN)(.*?)}%\s*(.*?)\s*%FIDEFINED%(\s*)/&renderIfDefinedThen($2, $3, $1, $4)/geos) {
    # nop
  }
}

###############################################################################
sub renderIfDefined {
  my ($args, $before, $after) = @_;

  $args = '' unless $args;

  #writeDebug("called renderIfDefined($args)");
  
  my $theVariable = &TWiki::Func::extractNameValuePair($args);
  my $theAction = &TWiki::Func::extractNameValuePair($args, 'action') || '';
  my $theThen = &TWiki::Func::extractNameValuePair($args, 'then') || $theVariable;
  my $theElse = &TWiki::Func::extractNameValuePair($args, 'else') || '';
  my $theGlue = &TWiki::Func::extractNameValuePair($args, 'glue') || 'on';
  my $theAs = &TWiki::Func::extractNameValuePair($args, 'as') || '.+';

  &escapeParameter($theThen);
  &escapeParameter($theElse);

  return &ifDefinedImpl($theVariable, $theAction, $theThen, $theElse, undef, $before, $after, $theGlue, $theAs);
}

###############################################################################
sub renderIfDefinedThen {
  my ($args, $text, $before, $after) = @_;

  $args = '' unless $args;

  #writeDebug("called renderIfDefinedThen($args)");

  my $theThen = $text; 
  my $theElse = '';
  my $elsIfArgs = '';

  if ($text =~ /^(.*?)\s*%ELSIFDEFINED{(.*?)}%\s*(.*)\s*$/gos) {
    $theThen = $1;
    $elsIfArgs = $2;
    $theElse = $3;
  } elsif ($text =~ /^(.*?)\s*%ELSEDEFINED%\s*(.*)\s*$/gos) {
    $theThen = $1;
    $theElse = $2;
  }

  my $theVariable = &TWiki::Func::extractNameValuePair($args);
  my $theAction = &TWiki::Func::extractNameValuePair($args, 'action') || '';
  my $theGlue = &TWiki::Func::extractNameValuePair($args, 'glue') || 'on';
  my $theAs = &TWiki::Func::extractNameValuePair($args, 'as') || '.+';

  return &ifDefinedImpl($theVariable, $theAction, $theThen, $theElse, $elsIfArgs, $before, $after, $theGlue, $theAs);
}


###############################################################################
sub ifDefinedImpl {
  my ($theVariable, $theAction, $theThen, $theElse, $theElsIfArgs, $before, $after, $theGlue, $theAs) = @_;

  #writeDebug("called ifDefinedImpl()");
  #writeDebug("theVariable='$theVariable'");
  #writeDebug("theAction='$theAction'");
  #writeDebug("theThen='$theThen'");
  #writeDebug("theElse='$theElse'");
  #writeDebug("theElsIfArgs='$theElsIfArgs'") if $theElsIfArgs;
  #writeDebug("theAs='$theAs'");
  
  $before = '' if ($theGlue eq 'on') || !$before;
  $after = '' if ($theGlue eq 'on') || !$after;

  if(&escapeParameter($theVariable)) {
    $theVariable = TWiki::Func::expandCommonVariables($theVariable, $currentTopic, $currentWeb);
  }
  if(&escapeParameter($theAs)) {
    $theAs = TWiki::Func::expandCommonVariables($theAs, $currentTopic, $currentWeb);
  }

  unless (defined $currentAction) {
    $currentAction = getCgiAction();
  }

  if (!$theAction || $currentAction =~ /$theAction/) {
    if ($theVariable =~ /^%([A-Za-z][A-Za-z0-9_]*)%$/) {
      $theVariable = '';
    }
    if ($theVariable =~ /^($theAs)$/s) {
      if ($theThen =~ s/\$nop//go) {
	$theThen = TWiki::Func::expandCommonVariables($theThen, $currentTopic, $currentWeb);
      }
      $theThen =~ s/\$(test|variable)/$theVariable/g;
      $theThen =~ s/\$value/$theAs/g;
      return $before.$theThen.$after;
    }
  }
  
  return $before."%IFDEFINEDTHEN{$theElsIfArgs}%$theElse%FIDEFINED%".$after if $theElsIfArgs;

  if ($theElse =~ s/\$nop//go) {
    $theElse = TWiki::Func::expandCommonVariables($theElse, $currentTopic, $currentWeb);
  }

  $theElse =~ s/\$test/$theVariable/g;
  $theElse =~ s/\$value/$theAs/g;
  return $before.$theElse.$after; # variable is empty
}

###############################################################################
sub renderIfAccess {
  my ($args, $before, $after) = @_;

  $args = '' unless $args;

  #writeDebug("called renderIfAccess($args)");
  
  my $theWebTopic = &TWiki::Func::extractNameValuePair($args) || $currentTopic;
  my $theType = &TWiki::Func::extractNameValuePair($args, 'type') || 'view';
  my $theUser = &TWiki::Func::extractNameValuePair($args, 'user') || TWiki::Func::getWikiName();
  my $theThen = &TWiki::Func::extractNameValuePair($args, 'then') || '1';
  my $theElse = &TWiki::Func::extractNameValuePair($args, 'else') || '0';
  my $theGlue = &TWiki::Func::extractNameValuePair($args, 'glue') || 'on';

  my ($thisWeb, $thisTopic) = TWiki::Func::normalizeWebTopicName($currentWeb, $theWebTopic);
  my $hasAccess = TWiki::Func::checkAccessPermission($theType, $theUser, undef, $thisTopic, $thisWeb);
  #writeDebug("hasAccess=$hasAccess");
  #writeDebug("theUser=$theUser hasAccess=$hasAccess thisWeb=$thisWeb thisTopic=$thisTopic");

  my $result = ($hasAccess)?$theThen:$theElse;

  $result = TWiki::Func::expandCommonVariables($result, $currentTopic, $currentWeb)
    if &escapeParameter($result);

  #writeDebug("result=$result");

  $before = '' if ($theGlue eq 'on') || !$before;
  $after = '' if ($theGlue eq 'on') || !$after;

  return $before.$result.$after;
}

###############################################################################
sub escapeParameter {
  return 0 unless $_[0];

  my $found = 0;

  $found = 1 if $_[0] =~ s/\\n/\n/g;
  $found = 1 if $_[0] =~ s/\$n/\n/g;
  $found = 1 if $_[0] =~ s/\\%/%/g;
  $found = 1 if $_[0] =~ s/\$nop//g;
  $found = 1 if $_[0] =~ s/\$percnt/%/g;
  $found = 1 if $_[0] =~ s/\$dollar/\$/g;

  return $found;
}


###############################################################################
# take the REQUEST_URI, strip off the PATH_INFO from the end, the last word
# is the action; this is done that complicated as there may be different
# paths for the same action depending on the apache configuration (rewrites, aliases)
sub getCgiAction {

  my $pathInfo = $ENV{'PATH_INFO'} || '';
  my $theAction = $ENV{'REQUEST_URI'} || '';
  if ($theAction =~ /^.*?\/([^\/]+)$pathInfo.*$/) {
    $theAction = $1;
  } else {
    $theAction = 'view';
  }

  #writeDebug("PATH_INFO=$ENV{'PATH_INFO'}");
  #writeDebug("REQUEST_URI=$ENV{'REQUEST_URI'}");
  #writeDebug("theAction=$theAction");

  return $theAction;
}

###############################################################################
1;
