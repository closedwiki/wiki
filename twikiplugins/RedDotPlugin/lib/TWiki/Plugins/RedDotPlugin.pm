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
        $web $topic $user $installWeb $VERSION $RELEASE
        $debug $styleLink $doneHeader $hasInitRedirector
    );

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in ACTIVATED_PLUGINS.
$RELEASE = '1.25';

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
  $hasInitRedirector = 0;
  
  return 1;
}

###############################################################################
sub commonTagsHandler {

  &initRedirector();

  $_[0] =~ s/%REDDOT%/&renderRedDot()/geo;
  $_[0] =~ s/%REDDOT{(.*?)}%/&renderRedDot($1)/geo;

  if (!$doneHeader && 
    $_[0] =~ s/<head>(.*?[\r\n]+)/<head>$1$styleLink\n/) {
    $doneHeader = 1;
  }


}

###############################################################################
# TODO don't drop anchors
sub initRedirector {

  return if $hasInitRedirector;
  $hasInitRedirector = 1;

  writeDebug("called initRedirector");

  my $query = &TWiki::Func::getCgiQuery();
  return unless $query;

  my $theAction = $query->url(-relative=>1); 
  writeDebug("theAction=$theAction");

  my $sessionKey = "REDDOT_REDIRECT_$web.$topic";

  # init redirect
  if ($theAction =~ /^edit/) {
    writeDebug("found edit");
    my $theRedirect = $query->param('redirect');
    if ($theRedirect) {
      writeDebug("found theRedirect=$theRedirect");
      &TWiki::Func::setSessionValue($sessionKey, $theRedirect);
      writeDebug("init redirect to $theRedirect");
    }
  }

  # exectute redirect
  if ($theAction =~ /^(view|save)/) {
    my $theRedirect;
    if ($theAction =~ /^view/) {
      writeDebug("found view");
      $theRedirect = &TWiki::Func::getSessionValue($sessionKey);
      &clearSessionValue($sessionKey);
    } else {
      writeDebug("found save");
      $theRedirect = $query->param('redirect');
    }
    if ($theRedirect) {
      writeDebug("found theRedirect=$theRedirect");
      my $toWeb = $web;
      my $toTopic = $theRedirect;
      if ($theRedirect =~ /(.*)\.(.*)/) {
	$toWeb = $1;
	$toTopic = $2;
      } 
      my $redirectUrl = &TWiki::Func::getViewUrl($toWeb,$toTopic);
      if ($redirectUrl ne &TWiki::Func::getViewUrl($web,$topic)) {
	&writeDebug("redirecting to $redirectUrl");
	&TWiki::Func::redirectCgiQuery($query,$redirectUrl);
      }
    }
  }
}

###############################################################################
# wrapper
sub clearSessionValue {
  my $key = shift;

  # using dakar's client 
  if (defined &TWiki::Client::clearSessionValue) {
    return $TWiki::Plugins::SESSION->{client}->clearSessionValue($key);
  }
  
  # using the SessionPlugin
  if (defined &TWiki::Plugins::SessionPlugin::clearSessionValueHandler) {
    return &TWiki::Plugins::SessionPlugin::clearSessionValueHandler($key);
  }

  # last resort
  return &TWiki::Func::setSessionValue($key, undef);
}

###############################################################################
sub renderRedDot {
  my $args = shift;

  $args = '' unless $args;

  my $theWebTopics;
  if ($theWebTopics = &TWiki::Func::extractNameValuePair($args)) {
    $theWebTopics = &TWiki::Func::expandCommonVariables($theWebTopics);
  } else {
    $theWebTopics = "$web.$topic";
  }
  my $theRedirect = &TWiki::Func::extractNameValuePair($args, 'redirect') 
    || "$web.$topic";
  my $theText = &TWiki::Func::extractNameValuePair($args, 'text') || '.';
  my $theStyle = &TWiki::Func::extractNameValuePair($args, 'style') || '';
  my $theGrant = &TWiki::Func::extractNameValuePair($args, 'grant') || '.*';

  # find the first webtopic that we have access to
  my $theWeb;
  my $theTopic;
  my $hasEditAccess = 0;
  my $wikiName = &TWiki::Func::getWikiName();

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
      writeDebug("checking access on $theWeb.$theTopic for $wikiName");
      $hasEditAccess = &TWiki::Func::checkAccessPermission("CHANGE", 
	$wikiName, '', $theTopic, $theWeb);
      if ($hasEditAccess) {
	$hasEditAccess = 0 unless $wikiName =~ /$theGrant/; 
	# SMELL: use the twiki users and groups functions to check
	# if we are in theGrant
      }
      if ($hasEditAccess) {
	writeDebug("granted");
	last;
      }
    }
  }

  if (!$hasEditAccess) {
    return '';
  }

  #writeDebug("rendering red dot on $theWeb.$theTopic for $wikiName");

  # red dotting
  my $whiteBoard = _getValueFromTopic($theWeb, $theTopic, 'WHITEBOARD') || '';
  my $result = 
    '<span class="redDot" ';
  $result .=
    '><a href="%SCRIPTURLPATH%/edit%SCRIPTSUFFIX%/' .
    "$theWeb/$theTopic" .
    '?t=' . time();
  $result .= 
    "&redirect=$theRedirect" if $theRedirect ne "$theWeb.$theTopic";
  $result .= 
    '&action=form' if $whiteBoard =~ /off/;
  $result .= '" ';
  $result .= "style=\"$theStyle\" " if $theStyle;
  $result .=
    "title=\"Edit&nbsp;<nop>$theWeb.$theTopic\" " .
    "alt=\"Edit&nbsp;<nop>$theWeb.$theTopic\"" .
    ">$theText</a></span>";

  return $result;
}

###############################################################################
# _getValue: my version to get the value of a variable in a topic
sub _getValueFromTopic {
  my ($theWeb, $theTopic, $theKey, $text) = @_;

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

  return '';
}




1;
