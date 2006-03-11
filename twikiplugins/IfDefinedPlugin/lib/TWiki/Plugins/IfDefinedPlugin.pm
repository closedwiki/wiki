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
  $isBeijing $isCairo $isDakar
);

$VERSION = '$Rev$';
$RELEASE = 'v0.91';
$debug = 0; # toggle me

###############################################################################
sub writeDebug {
  &TWiki::Func::writeDebug('- IfDefinedPlugin - '.$_[0]) if $debug;
}

###############################################################################
sub initPlugin {
  ($currentTopic, $currentWeb) = @_;

  $currentAction = $ENV{SCRIPT_NAME} || '';
  $currentAction =~ s/^.*\/(.*?)$/$1/go;

  #writeDebug("currentAction=$currentAction");

  $isDakar = (defined $TWiki::RELEASE)?1:0;
  if ($isDakar) {
    $isBeijing = 0;
    $isCairo = 0;
  } else {
    my $wikiVersion = $TWiki::wikiversion; 
    if ($wikiVersion =~ /^01 Feb 2003/) {
      $isBeijing = 1; # beijing
      $isCairo = 0;
    } else {
      $isBeijing = 0; # cairo
      $isCairo = 1;
    }
  }
  #writeDebug("isDakar=$isDakar isBeijing=$isBeijing isCairo=$isCairo");

  
  return 1;
}

###############################################################################
sub commonTagsHandler {
  $_[0] =~ s/(\s*)%IFDEFINED{(.*?)}%(\s*)/&renderIfDefined($2, $1, $3)/geos;
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

  if (!$theAction || $currentAction =~ /$theAction/) {
    if ($theVariable =~ /^%([A-Za-z][A-Za-z0-9]*)%$/) {
      my $varName = $1;
      if ($isBeijing) {
	my $topicText = &TWiki::Func::readTopic($currentWeb, $currentTopic);
	$theVariable = &_getValueFromTopic($currentWeb, $currentTopic, $varName, $topicText);
	$theVariable =~ s/^\s+//;
	$theVariable =~ s/\s+$//;
	$theVariable = &TWiki::Func::expandCommonVariables($theVariable, $currentTopic, $currentWeb);
	$theThen =~ s/%$varName%/$theVariable/g;# SMELL: do we need to backport topic vars?
      } else {
	$theVariable = '';
      }
    }
    if ($theVariable =~ /^($theAs)$/) {
      if ($theThen =~ s/\$nop//go) {
	$theThen = TWiki::Func::expandCommonVariables($theThen, $currentTopic, $currentWeb);
      }
      return $before.$theThen.$after;
    }
  }
  
  return $before."%IFDEFINEDTHEN{$theElsIfArgs}%$theElse%FIDEFINED%".$after if $theElsIfArgs;

  if ($theElse =~ s/\$nop//go) {
    $theElse = TWiki::Func::expandCommonVariables($theElse, $currentTopic, $currentWeb);
  }
  return $before.$theElse.$after; # variable is empty
}

###############################################################################
# _getValue: my version to get the value of a variable in a topic
sub _getValueFromTopic {
  my ($theWeb, $theTopic, $theKey, $text) = @_;

  if ($isDakar) {
    my $value = 
      $TWiki::Plugins::SESSION->{prefs}->getTopicPreferencesValue($theKey, 
	$theWeb, $theTopic) || '';
    return $value;
  } else {
    if (!$text) {
      my $meta;
      ($meta, $text) = &TWiki::Func::readTopic($theWeb, $theTopic);
    }

    foreach my $line (split(/\n/, $text)) {
      if ($line =~ /^(?:\t|\s\s\s)+\*\sSet\s$theKey\s\=\s*(.*)/) {
	my $value = defined $1 ? $1 : "";
	return $value;
      }
    }
  }

  return '';
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
1;
