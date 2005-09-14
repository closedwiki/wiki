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
###############################################################################
package TWiki::Plugins::RedDotPlugin;

###############################################################################
use vars qw(
        $web $topic $user $installWeb $VERSION
        $debug $styleLink $doneHeader
    );

$VERSION = '0.91';

###############################################################################
sub writeDebug {
  &TWiki::Func::writeDebug("- RedDotPlugin - " . $_[0]) if $debug;
}

###############################################################################
sub initPlugin {
  ($topic, $web, $user, $installWeb) = @_;

  $debug = 0; # toggle me

  my $styleUrl = "%PUBURL%\/$installWeb/RedDotPlugin/style.css";
  $styleLink = 
    '<link rel="stylesheet" href="' . 
    $styleUrl .
    '" type="text/css" media="all" />';
    
  $doneHeader = 0;
  
  return 1;
}

###############################################################################
sub commonTagsHandler {
  $_[0] =~ s/%REDDOT%/&renderRedDot()/geo;
  $_[0] =~ s/%REDDOT{(.*?)}%/&renderRedDot($1)/geo;

  if (!$doneHeader && 
    $_[0] =~ s/<head>(.*?[\r\n]+)/<head>$1$styleLink\n/) {
    $doneHeader = 1;
  }
}

###############################################################################
sub renderRedDot {
  my $args = shift || '';


  my $theWebTopics;
  if ($theWebTopics = &TWiki::Func::extractNameValuePair($args)) {
    $theWebTopics = &TWiki::Func::expandCommonVariables($theWebTopics);
  } else {
    $theWebTopics = "$web.$topic";
  }

  # find the first webtopic that we have access to
  my $theWeb;
  my $theTopic;
  my $wikiName = &TWiki::Func::getWikiUserName();
  my $hasEditAccess = 0;

  foreach my $webTopic (split(/, /, $theWebTopics)) {
    #writeDebug("testing webTopic=$webTopic");

    if ($webTopic =~ /^(.+)\.(.+?)$/) {
      $theWeb = $1;
      $theTopic = $2;
    } elsif ($webTopic =~ /^(.+)$/) {
      $theWeb = $web;
      $theTopic = $1;
    }

    if (&TWiki::Func::topicExists($theWeb, $theTopic)) {
      $hasEditAccess = &TWiki::Func::checkAccessPermission("CHANGE", 
	$wikiName, '', $theTopic, $theWeb);
      if ($hasEditAccess) {
	last;
      }
    }
  }

  if (!$hasEditAccess) {
    return '';
  }

  #writeDebug("rendering red dot on $theWeb.$theTopic for $wikiName");

  # red dotting
  my $result = 
    '<span class="redDot"><a href="%SCRIPTURLPATH%/edit%SCRIPTSUFFIX%/' .
    "$theWeb/$theTopic" .
    '?t=' . time() . '" ' .
    "title=\"Edit&nbsp;<nop>$theWeb.$theTopic\" " .
    "alt=\"Edit&nbsp;<nop>$theWeb.$theTopic\"" .
    '>.</a></span>';
}


1;
