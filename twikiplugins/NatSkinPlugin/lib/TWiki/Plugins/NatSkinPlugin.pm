###############################################################################
# NatSkinPlugin.pm - Plugin handler for the NatSkin.
# 
# Copyright (C) 2003-2005 Michael Daum <micha@nats.informatik.uni-hamburg.de>
#
# Based on GnuSkin Copyright (C) 2001 Dresdner Kleinwort Wasserstein
# 
# Fixes for the GnuSkin by Joachim Nilsson <joachim AT vmlinux DOT org>
#
# Thanks also to SteveRoe and JohnTalintyre, see http://twiki.org
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

package TWiki::Plugins::NatSkinPlugin;
use TWiki::Plugins;

###############################################################################
use vars qw(
        $web $topic $user $installWeb $VERSION $debug
        $isGuest $defaultWikiUserName
	$useSpamObfuscator $isBeijing $isDakar $isCairo
	$maxRev $query $urlHost
	$defaultSkin 
	$defaultStyle $defaultStyleBorder $defaultStyleSideBar
	%knownStyles $hasInitKnownStyles
	$knownStyleBorders $knownStyleSidebars
	%skinState $hasInitSkinState
    );

$VERSION = '2.10';

$defaultSkin    = 'nat';
$defaultStyle   = 'Clean';
$defaultStyleBorder = 'off';
$defaultStyleSideBar = 'left';
$knownStyleBorders = '^(on|off|thin)$';
$knownStyleSidebars = '^(left|right|both|off)$';

###############################################################################
sub writeDebug {
  &TWiki::Func::writeDebug("- NatSkinPlugin - " . $_[0]) if $debug;
}


###############################################################################
# initPlugin: 
#
#  Called for all plugins.
#
sub initPlugin
{
  ($topic, $web, $user, $installWeb) = @_;
    
  $debug = 0; # toggle me

  &doInit();

  writeDebug("done initPlugin");
  return 1;
}

###############################################################################
sub doInit {

  writeDebug("called doInit");

  # check TWiki version: let's eat spagetti
  $isDakar = (defined $TWiki::cfg{LogFileName})?1:0;
  if ($isDakar) {# dakar
    writeDebug("wikiVersion=$TWiki::VERSION (dakar)");
    $isBeijing = 0;
    $isCairo = 0;
  } else {# non-dakar
    my $wikiVersion = $TWiki::wikiversion; 

    if ($wikiVersion =~ /^01 Feb 2003/) {
      $isBeijing = 1; # beijing
      $isCairo = 0;
      eval "use TWiki::Access;";
      writeDebug("wikiVersion=$wikiVersion (beijing)");
    } else {
      $isBeijing = 0; # cairo
      $isCairo = 1;
      eval "use TWiki::User;";
      writeDebug("wikiVersion=$wikiVersion (cairo)");
    }
  }

  writeDebug("isDakar=$isDakar isBeijing=$isBeijing isCairo=$isCairo");

  
  # get skin state from session
  $hasInitKnownStyles = 0;
  $hasInitSkinState = 0;
  &initKnownStyles();

  $defaultWikiUserName = &TWiki::Func::getDefaultUserName();
  $defaultWikiUserName = &TWiki::Func::userToWikiName($defaultWikiUserName, 1);
  my $wikiUserName = &TWiki::Func::userToWikiName($user, 1);

  $isGuest = ($wikiUserName eq $defaultWikiUserName)?1:0;
  #writeDebug("defaultWikiUserName=$defaultWikiUserName, wikiUserName=$wikiUserName, isGuest=$isGuest");

  $query = &TWiki::Func::getCgiQuery();
  if ($query) { # are we in cgi mode?
    # disable during register context
    my $theAction = $query->url(-relative=>1); # cannot use skinState yet, we are in initPlugin
    $useSpamObfuscator = ($theAction =~ /^register/)?0:1; 
  } else {
    $useSpamObfuscator = 0; # batch mode, i.e. mailnotification
    writeDebug("no query ... batch mode");
  }

  # Plugin correctly initialized
  writeDebug("initPlugin ($web.$topic) is OK");

  # gather revision information
  if ($isDakar) {
    $maxRev = $TWiki::Plugins::SESSION->{store}->getRevisionNumber($web, $topic);
  } else {
    $maxRev = &TWiki::Store::getRevisionNumber($web, $topic);
  }
  $maxRev =~ s/r?1\.//go;  # cut 'r' and major
#  writeDebug("maxRev=$maxRev");

  $urlHost = &TWiki::Func::getUrlHost();

  writeDebug("done doInit");
}

###############################################################################
sub initKnownStyles {

  return if $hasInitKnownStyles;
  $hasInitKnownStyles = 1;
  %knownStyles = ();
  
  my $twikiWeb = &TWiki::Func::getTwikiWebname();
  my ($meta, undef) = &TWiki::Func::readTopic($twikiWeb, 'NatSkin');
  foreach my $attachment ($meta->find('FILEATTACHMENT')) {
    my $styleName = $attachment->{name};
    next if $styleName !~ /.*Style\.css$/;
    $styleName =~ s/Style.css//g;
    $knownStyles{$styleName} = 1;
  }
}


###############################################################################
sub initSkinState {
  writeDebug("called initSkinState");

  return if $hasInitSkinState;
  $hasInitSkinState = 1;
  %skinState = ();

  writeDebug("initializing the skin state");

  my $theStyle;
  my $theStyleBorder;
  my $theStyleSideBar;
  my $theRaw;

  if ($query) {
    $theStyle = $query->param('style');
    $theStyleBorder = $query->param('styleborder'); # SMELL: add toggles for the others
    $theStyleSideBar = $query->param('stylesidebar');
    $theToggleSideBar = $query->param('togglesidebar');

    $theRaw = $query->param('raw');

    writeDebug("urlparam style=$theStyle") if $theStyle;
    writeDebug("urlparam styleborder=$theStyleBorder") if $theStyleBorder;
    writeDebug("urlparam stylesidebar=$theStyleSideBar") if $theStyleSideBar;
    writeDebug("urlparam togglesidebar=$theToggleSideBar") if $theToggleSideBar;
  }

  # handle style
  &initKnownStyles();
  if (!$theStyle) {
    if ($skinState{'style'}) {
      writeDebug("found skinStyle=$skinState{'style'}");
      $theStyle = $skinState{'style'};
    } else {
      $theStyle = 
	  &TWiki::Func::getSessionValue('NATSKIN_STYLE') ||
	  &TWiki::Func::getPreferencesValue("SKINSTYLE", $web) ||
	  $defaultStyle;
    }
  }
  $theStyle =~ s/\s+$//;
  writeDebug("$theStyle is known") if $knownStyles{$theStyle};
  writeDebug("$theStyle is UNKNOWN") unless $knownStyles{$theStyle};
  $theStyle = $defaultStyle unless $knownStyles{$theStyle};
  $skinState{'style'} = $theStyle;

  # handle border
  if (!$theStyleBorder) {
    if ($skinState{'border'}) {
      writeDebug("found skinStyleBorder=$skinState{'border'}");
      $theStyleBorder = $skinState{'border'};
    } else {
      $theStyleBorder =
	&TWiki::Func::getSessionValue('NATSKIN_STYLEBORDER') ||
	&TWiki::Func::getPreferencesValue("STYLEBORDER", $web) ||
	$defaultStyleBorder;
    }
  }
  $theStyleBorder =~ s/\s+$//;
  $theStyleBorder = $defaultStyleBorder
    if $theStyleBorder !~ /$knownStyleBorders/;
  $skinState{'border'} = $theStyleBorder;

  # handle sidebar */
  if (!$theStyleSideBar) {
    if ($skinState{'sidebar'}) {
      writeDebug("found skinStyleSideBar=$skinState{'sidebar'}");
      $theStyleSideBar = $skinState{'sidebar'};
    } else {
      $theStyleSideBar =
	&TWiki::Func::getSessionValue('NATSKIN_STYLESIDEBAR') ||
	&TWiki::Func::getPreferencesValue("STYLESIDEBAR", $web) ||
	$defaultStyleSideBar;
    }
  }
  $theStyleSideBar =~ s/\s+$//;
  $theStyleSideBar = $defaultStyleSideBar
    if $theStyleSideBar !~ /$knownStyleSidebars/;
  $skinState{'sidebar'} = $theStyleSideBar;

  # handle TablePlugin attributes
  my $prefsName = "\U$theStyle\ETABLEATTRIBUTES";
  my $tablePluginAttrs = 
    &TWiki::Func::getPreferencesValue('NATSKINPLUGIN_BASETABLEATTRIBUTES') || '';
  my $skinTablePluginAttrs =
    &TWiki::Func::getPreferencesValue("NATSKINPLUGIN_$prefsName") || '';
  $tablePluginAttrs .= ' ' . $skinTablePluginAttrs;
  $tablePluginAttrs =~ s/\s+$//;
  $tablePluginAttrs =~ s/^\s+//;
  
  # handle release
  $skinState{'release'} = lc &getReleaseName();

  # handle action
  if ($query) { # are we in cgi mode?
    $skinState{'action'} = $query->url(-relative=>1); 
  }

  # store (part of the) state into session
  &TWiki::Func::setSessionValue('NATSKIN_STYLE', $skinState{'style'});
  &TWiki::Func::setSessionValue('NATSKIN_STYLEBORDER', $skinState{'border'});
  &TWiki::Func::setSessionValue('NATSKIN_STYLESIDEBAR', $skinState{'sidebar'});
  &TWiki::Func::setSessionValue('TABLEATTRIBUTES', $tablePluginAttrs);

  # temporary toggles
  $theToggleSideBar = 'off' if $theRaw;
  $theToggleSideBar = 'off' if $skinState{'border'} eq 'thin' && 
    $skinState{'action'} =~ /^(edit|manage|rdiff|natsearch|changes|search)$/o;
    # SMELL get away with this hardcode

  $skinState{'sidebar'} = $theToggleSideBar 
    if $theToggleSideBar && $theToggleSideBar ne '';
}


###############################################################################
# commonTagsHandler:
# $_[0] - The text
# $_[1] - The topic
# $_[2] - The web
sub commonTagsHandler
{
  &initSkinState();

  $_[0] =~ s/%NATLOGON%/&renderLogon()/geo;
  $_[0] =~ s/%WEBLINK%/renderWebLink()/geos;
  $_[0] =~ s/%WEBLINK{(.*?)}%/renderWebLink($1)/geos;
  $_[0] =~ s/%USERWEBS%/&renderUserWebs()/geo;

  $_[0] =~ s/%USERACTIONS%/&renderUserActions/geo;

  $_[0] =~ s/%GROUPSUMMARY%/&renderGroupSummary($_[0])/geo;
  $_[0] =~ s/%ALLUSERS%/&renderAllUsers()/geo;
  $_[0] =~ s/%FORMBUTTON%/&renderFormButton()/geo;
  $_[0] =~ s/%FORMBUTTON{(.*?)}%/&renderFormButton($1)/geo;

  $_[0] =~ s/%FORMATLIST{(.*?)}%/&renderFormatList($1)/geo; # undocumented

  # spam obfuscator
  if ($useSpamObfuscator) {
    $_[0] =~ s/([\s\(])(?:mailto\:)?([a-zA-Z0-9\-\_\.\+]+\@[a-zA-Z0-9\-\_\.]+\.[a-zA-Z0-9\-\_]+)(?=[\s\.\,\;\:\!\?\)])/$1 . &renderEmailAddrs([$2])/ge;
    $_[0] =~ s/\[\[mailto\:([a-zA-Z0-9\-\_\.\+]+\@[a-zA-Z0-9\-\_\.]+\..+?)(\s+|\]\[)(.*?)\]\]/&renderEmailAddrs([$1], $3)/ge;
  }

  # conditional content
  $_[0] =~ s/%IFSKINSTATE{(.*?)}%/&renderIfSkinState($1)/geo;
  while ($_[0] =~ s/\s*%IFSKINSTATETHEN{(?!.*%IFSKINSTATETHEN)(.*?)}%\s*(.*?)\s*%FISKINSTATE%\s*/&renderIfSkinStateThen($1, $2)/geos) {
    # nop
  }
  $_[0] =~ s/%IFACCESS{(.*?)}%/&renderIfAccess($1)/geo;
  $_[0] =~ s/%WIKIRELEASENAME%/&getReleaseName()/geo;

  $_[0] =~ s/%GETSKINSTYLE%/&renderGetSkinStyle()/geo;
  $_[0] =~ s/%KNOWNSTYLES%/&renderKnownStyles()/geo;

  # REVISIONS only worked properly for the PatternSkin :(
  # REVARG is expanded for templates only :(
  # MAXREV is different on Cairo, Beijing and Dakar 
  # implementing this stuff again for maximum backwards compatibility
  $_[0] =~ s/%NATREVISIONS%/&renderRevisions()/geo;
  $_[0] =~ s/%PREVREV%/'1.' . &getPrevRevision()/geo;
  $_[0] =~ s/%CURREV%/'1.' . &getCurRevision($web, $topic)/geo; 
  $_[0] =~ s/%NATMAXREV%/1.$maxRev/go;
}

###############################################################################
sub endRenderingHandler {
  $_[0] =~ s/%WEBSIDEBAR%/&renderWebSideBar()/geo;
  $_[0] =~ s/%MYSIDEBAR%/&renderMySideBar()/geo;
  $_[0] =~ s/(<a .*?href=[\"\']?)([^\"\'\s]+[\"\']?)(\s*[a-z]*)/renderExternalLink($1,$2,$3)/geoi;
}

###############################################################################
sub renderIfAccess {
  my $args = shift;

  my $theWebTopic = 
    &TWiki::Func::extractNameValuePair($args) ||
    &TWiki::Func::extractNameValuePair($args, 'topic') || '';

  my $theAction = 
    &TWiki::Func::extractNameValuePair($args, 'action') || 'VIEW';

  my $theThen =
    &TWiki::Func::extractNameValuePair($args, 'then') || $theWebTopic;

  my $theElse =
    &TWiki::Func::extractNameValuePair($args, 'else') || '';


  my $theMode =
    &TWiki::Func::extractNameValuePair($args, 'mode') || '';

  my $theThenArgs = 
    &TWiki::Func::extractNameValuePair($args, 'args') || 
    &TWiki::Func::extractNameValuePair($args, 'then_args') || '';

  my $theElseArgs = 
    &TWiki::Func::extractNameValuePair($args, 'else_args') || '';


  my $theTopic = $topic;
  my $theWeb = $web;

  if ($theWebTopic =~ /^(.*)\.(.*)$/) {
    $theWeb = $1;
    $theTopic = $2;
  } elsif ($theWebTopic) {
    $theTopic = $theWebTopic;
  }

  my $wikiName = &TWiki::Func::getWikiUserName();
  my $hasAccess = &TWiki::Func::checkAccessPermission($theAction,
    $wikiName, '', $theTopic, $theWeb);

  if ($theMode eq 'include') {
    if ($theThen) {
      $theThen = '%INCLUDE{"' . $theThen . '" ' .  $theThenArgs . '}%';
    }
    if ($theElse) {
      $theThen = '%INCLUDE{"' . $theElse . '" ' .  $theElseArgs . '}%';
    }
  }
  
  if ($hasAccess) {
    return $theThen;
  } else {
    return $theElse;
  }
}

###############################################################################
sub getReleaseName {
  return 'Beijing' if $isBeijing;
  return 'Cairo' if $isCairo;
  return 'Dakar' if $isDakar;
}

###############################################################################
sub renderIfSkinStateThen {
  my ($args, $text) = @_;

  $args = '' unless $args;

  writeDebug("called renderIfSkinStateThen($args)");


  my $theThen = $text; 
  my $theElse = '';
  my $elsIfArgs;

  if ($text =~ /^(.*?)\s*%ELSIFSKINSTATE{(.*?)}%\s*(.*)\s*$/gos) {
    $theThen = $1;
    $elsIfArgs = $2;
    $theElse = $3;
  } elsif ($text =~ /^(.*?)\s*%ELSESKINSTATE%\s*(.*)\s*$/gos) {
    $theThen = $1;
    $theElse = $2;
  }

  my $theStyle = &TWiki::Func::extractNameValuePair($args) ||
	      &TWiki::Func::extractNameValuePair($args, 'style');
  my $theBorder = &TWiki::Func::extractNameValuePair($args, 'border');
  my $theSideBar = &TWiki::Func::extractNameValuePair($args, 'sidebar');
  my $theRelease = lc &TWiki::Func::extractNameValuePair($args, 'release');
  my $theAction = &TWiki::Func::extractNameValuePair($args, 'action');

  writeDebug("theStyle=$theStyle");
  writeDebug("theThen=$theThen");
  writeDebug("theElse=$theElse");

  if ((!$theStyle || $skinState{'style'} =~ /$theStyle/) &&
      (!$theBorder || $skinState{'border'} =~ /$theBorder/) &&
      (!$theSideBar || $skinState{'sidebar'} =~ /$theSideBar/) &&
      (!$theRelease || $skinState{'release'} =~ /$theRelease/) &&
      (!$theAction || $skinState{'action'} =~ /$theAction/)) {
    writeDebug("match then");
    return $theThen if $theThen;
  } else {
    if ($elsIfArgs) {
      writeDebug("match elsif");
      return "%IFSKINSTATETHEN{$elsIfArgs}%$theElse%FISKINSTATE%";
    } else {
      writeDebug("match else");
      return $theElse if $theElse;
    }
  }

  writeDebug("NO match");
  return '';
  
}

###############################################################################
sub renderIfSkinState {
  my $args = shift;


  my $theStyle = &TWiki::Func::extractNameValuePair($args) ||
	      &TWiki::Func::extractNameValuePair($args, 'style');
  my $theThen = &TWiki::Func::extractNameValuePair($args, 'then');
  my $theElse = &TWiki::Func::extractNameValuePair($args, 'else');
  my $theBorder = &TWiki::Func::extractNameValuePair($args, 'border');
  my $theSideBar = &TWiki::Func::extractNameValuePair($args, 'sidebar');
  my $theRelease = lc &TWiki::Func::extractNameValuePair($args, 'release');
  my $theAction = &TWiki::Func::extractNameValuePair($args, 'action');


  #writeDebug("called renderIfSkinState($args)");
  #writeDebug("releaseName=" . lc &getReleaseName());
  #writeDebug("skinRelease=$skinState{'release'}");
  #writeDebug("theRelease=$theRelease");

  if ((!$theStyle || $skinState{'style'} =~ /$theStyle/) &&
      (!$theBorder || $skinState{'border'} =~ /$theBorder/) &&
      (!$theSideBar || $skinState{'sidebar'} =~ /$theSideBar/) &&
      (!$theRelease || $skinState{'release'} =~ /$theRelease/) &&
      (!$theAction || $skinState{'action'} =~ /$theAction/)) {

    &escapeParameter($theThen);
    #writeDebug("match");
    return $theThen if $theThen;
  } else {
    &escapeParameter($theThen);
    #writeDebug("NO match");
    return $theElse if $theElse;
  }

  return '';
}

###############################################################################
sub renderKnownStyles {

  return join(', ', sort {$a cmp $b} keys %knownStyles);
}

###############################################################################
sub renderGetSkinStyle {

  my $theBorder;
  my $theSideBar;


  $theBorder = $skinState{'style'} . 'Border' if $skinState{'border'} eq 'on';
  $theBorder = $skinState{'style'} . 'Thin' if $skinState{'border'} eq 'thin';
  $theSideBar = $skinState{'style'} . 'Right' if $skinState{'sidebar'} eq 'right';
  $theSideBar = 'NoSideBar' if $skinState{'sidebar'} eq 'off';

  my $text = 
    '<style type="text/css">' . "\n" .
    '@import url("%PUBURL%/%TWIKIWEB%/NatSkin/' . $skinState{'style'} . 'Style.css");' . "\n";

  $text .=
    '@import url("%PUBURL%/%TWIKIWEB%/NatSkin/' . $theBorder . '.css");' . "\n"
    if $theBorder;
#  $text .=
#    '@import url("%PUBURL%/%TWIKIWEB%/NatSkin/' . $theSideBar . '.css");' . "\n"
#    if $theSideBar;

  $text .= '</style>';

  return $text;
}


###############################################################################
# renderUserActions: render the USERACTIONS variable:
# display advanced topic actions for non-guests
sub renderUserActions {
  return "" if $isGuest;

  my $curRev = '';
  my $theRaw;
  if ($query) {
    $curRev = $query->param('rev') || '';
    $theRaw = $query->param('raw');
  }

  my $rev = &getCurRevision($web, $topic, $curRev);

  my $rawAction;
  if ($theRaw) {
    $rawAction =
      '<a href="' . 
      &TWiki::Func::getScriptUrl($web, $topic, "view") . 
      "?rev=1.$rev\" accesskey=\"r\">View</a>";
  } else {
    $rawAction =
      '<a href="' .  
      &TWiki::Func::getScriptUrl($web, $topic, "view") .  
      "?raw=on&rev=1.$rev\" accesskey=\"r\">Raw</a>";
  }
  
  my $text;
  $curRev =~ s/r?1\.//go;
  if ($curRev && $curRev < $maxRev) {
    $text =
      '<strike>Edit</strike> | ' .
      '<strike>Attach</strike> | ' .
      '<strike>Move</strike> | ';
  } else {
    #writeDebug("get WHITEBOARD from $web.$topic");
    my $whiteBoard = _getValueFromTopic($web, $topic, 'WHITEBOARD') || '';
    $whiteBoard =~ s/^\s*(.*?)\s*$/$1/g;
    my $formAction = '';
    $formAction = '&action=form' if $whiteBoard eq 'off';
    $text = 
      '<a rel="nofollow" href="'
      . &TWiki::Func::getScriptUrl($web, $topic, "edit") 
      . '?t=' . time() 
      . $formAction
      . '" accesskey="e">Edit</a> | ' .
      '<a rel="nofollow" href="'
      . &TWiki::Func::getScriptUrl($web, $topic, "attach") 
      . '" accesskey="a">Attach</a> | ' .
      '<a rel="nofollow" href="'
      . &TWiki::Func::getScriptUrl($web, $topic, "rename")
      . '" accesskey="m">Move</a> | ';
  }

  $text .=
      $rawAction . ' | ' .
      '<a rel="nofollow" href="' . &TWiki::Func::getScriptUrl($web, $topic, "oops") . '?template=oopsrev&param1=%PREVREV%&param2=%CURREV%&param3=%NATMAXREV%" accesskey="d">Diffs</a> | ' .
      '<a rel="nofollow" href="' . &TWiki::Func::getScriptUrl($web, $topic, "oops") . '?template=oopsmore" accesskey="x">More</a>';


  return $text;
}

###############################################################################
sub renderMySideBar {
  
  #writeDebug("called renderMySideBar");

  my $wikiName = &TWiki::Func::getWikiName();
  my $mySideBar = $wikiName . 'SideBar';
  my $mainWeb  = &TWiki::Func::getMainWebname();

  # get personal sidebar
  if (!&TWiki::Func::topicExists($mainWeb, $mySideBar)) {
    return '';
  }

  my ($meta, $text) =
    &TWiki::Func::readTopic($mainWeb, $mySideBar);
    
  # extract INCLUD area
  if ($text =~ /%STARTINCLUDE%(.*?)%STOPINCLUDE%/gs) {
    $text = $1;
  }
  $text =~ s/^\s*//;
  $text =~ s/\s*$//;

  #writeDebug("text='$text'");
  $text = &TWiki::Func::expandCommonVariables($text, $topic, $web);
  $text = &TWiki::Func::renderText($text, $web);

  # ignore permission warnings here ;)
  $text =~ s/No permission to read.*//g;

  return $text;
}

###############################################################################
sub renderWebSideBar {

  writeDebug("called renderWebSideBar()");


  if ($skinState{'sidebar'} eq 'off') {
    return '';
  }


  # get sidebar for web
  my $text;
  my $meta;
  my $theWeb;
  if (&TWiki::Func::topicExists($web, "WebSideBar")) {
    ($meta, $text) = &TWiki::Func::readTopic($web, "WebSideBar");
    $theWeb = $web;
  } else {
    $theWeb = &TWiki::Func::getTwikiWebname ();
    ($meta, $text) = &TWiki::Func::readTopic($theWeb, "WebSideBar");
  }

  writeDebug("renderWebSideBar() from $theWeb.WebSideBar");

  # extract INCLUD area
  if ($text =~ /%STARTINCLUDE%(.*?)%STOPINCLUDE%/gs) {
    $text = $1;
  }
  $text =~ s/^\s+//;
  $text =~ s/\s+$//;

  writeDebug("expandCommonVariables(text,$topic,$web)");
  #writeDebug("text=$text");
  $text = &TWiki::Func::expandCommonVariables($text, $topic, $theWeb);
  #writeDebug("renderText(text,$theWeb");
  $text = &TWiki::Func::renderText($text, $theWeb);

  # ignore permission warnings here ;)
  $text =~ s/No permission to read.*//g;

  writeDebug("done renderWebSideBar()");

  return $text;
}

###############################################################################
sub renderUserWebs {

  my @publicWebs = &TWiki::Func::getPublicWebList(); 
    # deprecated on dakar ... but still there

  my $mainWeb = &TWiki::Func::getMainWebname();
  my $twikiWeb = &TWiki::Func::getTwikiWebname();

  my @webs;
  foreach my $web (@publicWebs) {
    next if # TODO add an 'exlcude' parameter
      $web eq $mainWeb ||
      $web eq $twikiWeb ||
      $web eq 'Main' ||
      $web eq 'TWiki' ||
      $web eq 'TestCases' ||
      $web eq 'Sandbox' || 
      $web eq 'User' ||
      $web eq 'Support';
    push @webs, $web;
  }
  
  return join(',', @webs);
}

###############################################################################
sub renderWebLink {
  my $args = shift || '';

  my $theWeb = &TWiki::Func::extractNameValuePair($args) || 
    &TWiki::Func::extractNameValuePair($args, 'web') || $web;
  my $theName =
    &TWiki::Func::extractNameValuePair($args, 'name') || $theWeb;

  my $result = 
    '<span class="natWebLink"><a href="%SCRIPTURLPATH%/view%SCRIPTSUFFIX%/' . "$theWeb/WebHome\"";

  my $popup = _getValueFromTopic($theWeb , 'WebPreferences', "SITEMAPUSETO");
  if ($popup) {
    $popup =~ s/"/&quot;/g;
    $popup =~ s/<nop>/#nop#/g;
    $popup =~ s/<[^>]*>//g;
    $popup =~ s/#nop#/<nop>/g;
    $result .= " title=\"$popup\"";
  }

  $result .= ">$theName</a></span>";

  return $result;
}

###############################################################################
# renderGroupSummary: render variable %GROUPSUMMARY%
sub renderGroupSummary
{
  my $result = "";
  my $text = shift;

  writeDebug("called renderGroupSummary()");

  my %usersEmail;
  my @emailAddrs;
  my @users = &TWiki::Access::getUsersOfGroup($topic); # FIXME on dakar

  if ("@users" =~ /%ALLUSERS%/) {
    @users = getAllUsers();
  }

  writeDebug("users=" . join(',', @users));
  foreach my $user (@users) {
    $user =~ s/^.*\.//;	
    next if $usersEmail{$user};
    my ($email) = &TWiki::getEmailOfUser($user); # FIXME on dakar
    $usersEmail{$user} = $email;
    if ($email) {
      push @emailAddrs, $email if $email;
    }
  }

  my %adminsEmail;
  my @adminAddrs;
  my $value = _getValueFromTopic($web, $topic, "ALLOWTOPICCHANGE", $text);
  foreach my $admin (split(/[\,\s]+/, $value)) {
    if ($admin =~ /Group$/) {
      foreach my $admin (&TWiki::Access::getUsersOfGroup($admin)) { # FIXME on dakar
	$admin =~ s/^.*\.//;	
	next if $adminsEmail{$admin};
	my ($email) = &TWiki::getEmailOfUser($admin); # FIXME on dakar
	$adminsEmail{"$admin"} = $email;
	push @adminAddrs, $email if $email;
      }
    } else {
      next if $adminsEmail{$admin};
      my ($email) = &TWiki::getEmailOfUser($admin); # FIXME on dakar
      $adminsEmail{"$admin"} = $email;
      push @adminAddrs, $email if $email;
    }
  }

  # render members
  $result .= "---++ Members \n";
  foreach my $user (sort keys %usersEmail) {
    my $email = $usersEmail{$user};
    if ($email) {
      $result .= "\t1 $user: $email \n";
    } else {
      $result .= "\t1 $user\n";
    }
  }
  if (@emailAddrs) {
    $result .= "Contact " . 
      &renderEmailAddrs(\@emailAddrs, 'all members') .
      ".<br>\n";
  }

  $result .= "---++ Maintainer\n";

  # render maintainers
  if (@adminAddrs > 1) {
    foreach my $admin (sort keys %adminsEmail) {
      my $email = $adminsEmail{$admin};
      if ($email) {
	$result .= "\t1 $admin: $email \n";
      } else {
	$result .= "\t1 $admin\n";
      }
    }
    $result .= "Contact " . 
      &renderEmailAddrs(\@emailAddrs, 'all maintainers') .
      ".<br>\n";
  } else {
    my $email;
    my $admin;
    foreach $admin (keys %adminsEmail) {
      $email = $adminsEmail{$admin};
      if ($email) {
	$result .= "$admin: $email <br>\n";
	last;
      }
    }
    if (!$email) {
      ($admin) = keys %adminsEmail;
      $result .= "$admin <br/>\n" if $admin;
    }
  }

  return $result;
}

###############################################################################
# renderLogon: replace the %NATLOGON% variable
#
# Displays the username when logged in.
#
sub renderLogon {

  my $dispUser = "";
  my $logonScriptUrl = &TWiki::Func::getScriptUrl($web, $topic, "natlogon");
  if ($isGuest) {
    my $registerUrl = &TWiki::Func::getScriptUrl(&TWiki::Func::getTwikiWebname(), "TWikiRegistration", "view");
    if ($TWiki::doEncryptConnection) { # FIXME
      $logonScriptUrl =~ s/http:/https:/;
      $registerUrl =~ s/http:/https:/;
    }
    $dispUser .= '<a rel="nofollow" href="' 
	      . $logonScriptUrl 
	      . '" accesskey="l">Logon</a>'
	      . ' | <a href="' 
	      . $registerUrl 
	      . '" accesskey="r">Register</a>';
  } else {
    my $wikiName = &TWiki::Func::getWikiName();
    my $mainWeb  = &TWiki::Func::getMainWebname();
    my $viewScriptUrl = &TWiki::Func::getScriptUrl($mainWeb, $wikiName, "view");
    my $logoutWeb = $mainWeb;
    my $logoutTopic = 'WebHome';
    if (&TWiki::Func::checkAccessPermission('VIEW', $defaultWikiUserName, '', 
      $topic, $web)) {
      $logoutWeb = $web;
      $logoutTopic = $topic;
    }

    $dispUser .= '<a href="' 
	      . $viewScriptUrl 
	      . '" accesskey="h">' 
	      . $wikiName 
	      . '</a> | <a href="'
	      . $logonScriptUrl 
	      . '?web='
	      . $logoutWeb
	      . '&amp;topic='
	      . $logoutTopic
	      . '&amp;username='
	      . $defaultWikiUserName
	      . '" accesskey="l">Logout</a>';
  }

  return $dispUser;
}

###############################################################################
# _getValue: my version to get the value of a variable in a topic
sub _getValueFromTopic
{
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


###############################################################################
sub registrationHandler
{
### my ($web, $wikiName, $loginName, $formData) = @_;   # do not uncomment, use $_[0], $_[1]... instead
 # $formData is a reference to a %formData which contains formName,formValue pairs 

  writeDebug("starting registrationHandler");

  if (! $_[3]) {
    &TWiki::Func::writeDebug("NatSkinPlugin: WARNING: no formData submitted by registrationHander");
    &TWiki::Func::writeDebug("NatSkinPlugin: WARNING: no confirmation email willl be send to maintainers");
    return;
  }
    
  # extract register form data
  my $formData = $_[3];
  my $firstLastName = $formData->{"Name"} || '';
  my $wikiName = $formData->{"Wiki Name"} || '';
  my $emailAdress = $formData->{"Email"} || '';
  my $group = $formData->{"Group"} || '';
  my $comment = $formData->{"Comment"} || '';

  # get maintainers of the group
  my %adminsEmail;
  my @adminAddrs;
  my $value = _getValueFromTopic("User", $group, "ALLOWTOPICCHANGE");
  foreach my $admin (split(/[\,\s]+/, $value)) {
    if ($admin =~ /Group$/) {
      foreach my $admin (&TWiki::Access::getUsersOfGroup($admin)) { # FIXME on dakar
	$admin =~ s/^.*\.//;	
	my ($email) = &TWiki::getEmailOfUser($admin); # FIXME on dakar
	$adminsEmail{"$admin"} = $email;
	push @adminAddrs, $email if $email;
      }
    } else {
      my ($email) = &TWiki::getEmailOfUser($admin); # FIXME on dakar
      $adminsEmail{"$admin"} = $email;
      push @adminAddrs, $email if $email
    }
  }

  # create recipients string
  my $recipients = join(', ', @adminAddrs);
  $recipients =~ s/\r//g; #remove carriage returns
  
  writeDebug("group maintainers are: @adminAddrs");
  
  my $text = <<EOM;
From: %WIKIWEBMASTER%
To: $recipients
Subject: Fwd: %WIKITOOLNAME% - Registration for $wikiName to group $group
MIME-Version: 1.0
Content-Type: text/plain; charset=%CHARSET%
Content-Transfer-Encoding: 7bit

You are receiving this Email because you are a maintainer 
of the $group.

A new user registered to %WIKITOOLNAME% and requested for 
participating the $group.

User Details:

Name: $firstLastName
WikiName: $wikiName
Email Adress: $emailAdress

You may add the user to the $group topic at
%SCRIPTURL%/view%SCRIPTSUFFIX%/User/$group 
EOM

  $useSpamObfuscator = 0; # temporarily disable it
  $text = &TWiki::Func::expandCommonVariables($text, $wikiName);
 
  writeDebug("This Email will be send:\n$text");
  my $senderr = &TWiki::Net::sendEmail($text); # FIXME on dakar
  if ($senderr) {
    writeDebug("notification mail to administrators could not be sent. return code: $senderr.");
  } else {
    writeDebug("notification mail to administrators sent.");
  }

  $useSpamObfuscator = 1; # enabling it again
  return;
}

###############################################################################
sub getAllUsers {

  writeDebug("called getAllUsers");

  my $wikiUsersTopicname = ($isDakar)?$TWiki::cfg{UsersTopicName}:$TWiki::wikiUsersTopicname;
  my $mainWeb = &TWiki::Func::getMainWebname();

  my (undef, $topicText) = 
    &TWiki::Func::readTopic($mainWeb, $wikiUsersTopicname);

  my @users;
  foreach my $line (split(/\n/, $topicText)) {
    my $isList = ($line =~ /^\t\*\s([A-Z][a-zA-Z0-9]*)\s\-/go);
    next if ! $isList;
    next if $1 =~ /^.$/;
    push @users, $1;
  }

  writeDebug("result=" . join(',', @users));

  return @users;
}

###############################################################################
sub renderAllUsers {
  return join(', ', getAllUsers());
}

###############################################################################
sub renderFormatList {
  my $args = shift;

  #writeDebug("renderFormatList($args)");

  my $theList = &TWiki::Func::extractNameValuePair($args) ||
    &TWiki::Func::extractNameValuePair($args, 'list') || '';
  my $thePattern = &TWiki::Func::extractNameValuePair($args, 'pattern') || '(.*)';
  my $theFormat = &TWiki::Func::extractNameValuePair($args, 'format') || '%s';
  my $theSplit = &TWiki::Func::extractNameValuePair($args, 'split') || ',';
  my $theJoin = &TWiki::Func::extractNameValuePair($args, 'join') || ', ';
  my $theLimit = &TWiki::Func::extractNameValuePair($args, 'limit') || -1;
  my $theSort = &TWiki::Func::extractNameValuePair($args, 'sort') || 'off';

  $theList = &TWiki::Func::expandCommonVariables($theList, $topic, $web);

  my @result = 
    map { 
      $_ =~ m/$thePattern/;
      my $arg1 = $1 || '';
      my $arg2 = $2 || '';
      my $arg3 = $3 || '';
      my $arg4 = $4 || '';
      my $arg5 = $5 || '';
      my $arg6 = $6 || '';
      my $item = $theFormat;
      $item =~ s/\$1/$arg1/g;
      $item =~ s/\$2/$arg2/g;
      $item =~ s/\$3/$arg3/g;
      $item =~ s/\$4/$arg4/g;
      $item =~ s/\$5/$arg5/g;
      $item =~ s/\$6/$arg6/g;
      $_ = $item;
    } split /$theSplit/, $theList, $theLimit;

  if ($theSort ne 'off') {
    if ($theSort eq 'alpha' || $theSort eq 'on') {
      @result = sort {$a cmp $b} @result;
    } elsif ($theSort eq 'revalpha') {
      @result = sort {$b cmp $a} @result;
    } elsif ($theSort eq 'num') {
      @result = sort {$a <=> $b} @result;
    } elsif ($theSort eq 'revnum') {
      @result = sort {$b <=> $a} @result;
    }
  }

  my $result = join($theJoin, @result);

  &escapeParameter($result);
  #writeDebug("result=$result");


  $result = &TWiki::Func::expandCommonVariables($result);
  $result = &TWiki::Func::renderText($result);
  return $result;
}

###############################################################################
sub showError {
  my ($errormessage) = @_;
  return "<font size=\"-1\" color=\"#FF0000\">$errormessage</font>" ;
}

###############################################################################
sub renderFormButton {

  my $saveCmd = '';
  $saveCmd = $query->param('cmd') || '' if $query;
  return '' if $saveCmd eq 'repRev';

  my $args = shift || '';
  my $theFormat = &TWiki::Func::extractNameValuePair($args) ||
		  &TWiki::Func::extractNameValuePair($args, 'format');

  my ($meta, $dumy) = &TWiki::Func::readTopic($web, $topic);
  my $formMeta = &getMetaData($meta, "FORM"); 
  my $form = '';
  $form = $formMeta->{"name"} if $formMeta;
  my $text = "<a href=\"javascript:submitEditFormular('save', 'add form');\" accesskey=\"f\">";
  if ($form) {
    $text .= "Change form</a>";
  } elsif (&TWiki::Func::getPreferencesValue("WEBFORMS", $web)) {
    $text .= "Add form</a>";
  } else {
    return ''
  }

  $theFormat =~ s/\$1/$text/;
  return $theFormat;
}

###############################################################################
sub renderEmailAddrs
{
  my ($emailAddrs, $linkText) = @_;

  $linkText = '' unless $linkText;

  writeDebug("called renderEmailAddrs");

  my $thisDebug = 0;
  if ($thisDebug) {
    TWiki::Func::writeDebug("called renderEmailAddrs(" . 
    join(", ", @$emailAddrs) .  ", $linkText)");
  }

  my $text = 
    '<script language="javascript" type="text/javascript">' .
    "{ var addrs = new Array(); ";

  my $index = 0;
  foreach my $addr (@$emailAddrs) {
    TWiki::Func::writeDebug("addr='$addr'") if $thisDebug;
    next unless $addr =~ m/^([a-zA-Z0-9\-\_\.\+]+)\@([a-zA-Z0-9\-\_\.]+)\.(.+?)$/;
    my $theAccount = $1;
    my $theSubDomain = $2;
    my $theTopDomain = $3;
    $text .= "addrs[$index] = new Array('$theAccount','$theSubDomain','$theTopDomain'); ";
    $index++;
  }
  $text .= "writeEmailAddrs(addrs, '$linkText'); }</script>";

  TWiki::Func::writeDebug("result: $text") if $thisDebug;
  return $text;
}

###############################################################################
sub renderRevisions {

  writeDebug("called renderRevisions");

  my $rev1;
  my $rev2;
  $rev1 = $query->param("rev1") if $query;
  $rev2 = $query->param("rev2") if $query;

  my $topicExists = &TWiki::Func::topicExists($web, $topic);
  if ($topicExists) {
    
    $rev1 = 0 unless $rev1;
    $rev2 = 0 unless $rev2;
    $rev1 =~ s/r?1\.//go;  # cut 'r' and major
    $rev2 =~ s/r?1\.//go;  # cut 'r' and major

    $rev1 = $maxRev if $rev1 < 1;
    $rev1 = $maxRev if $rev1 > $maxRev;
    $rev2 = 1 if $rev2 < 1;
    $rev2 = $maxRev if $rev2 > $maxRev;

    $revTitle1 = "r1.$rev1";
    
    $revInfo1 = getRevInfo($web, $rev1, $topic);
    if ($rev1 != $rev2) {
      $revTitle2 = "r1.$rev2";
      $revInfo2 = getRevInfo($web, $rev2, $topic);
    }

    #writeDebug("revInfo1=$revInfo1, revInfo2=$revInfo2, revTitle1=$revTitle1, revTitle2=$revTitle2");
    
  } else {
    $rev1 = 1;
    $rev2 = 1;
  }

  my $revisions = "";
  my $nrrevs = $rev1 - $rev2;
  my $numberOfRevisions = 
    ($isDakar)?$TWiki::cfg{NumberOfRevisions}:$TWiki::numberOfRevisions;

  if ($nrrevs > $numberOfRevisions) {
    $nrrevs = $numberOfRevisions;
  }

  #writeDebug("rev1=$rev1, rev2=$rev2, nrrevs=$nrrevs");

  my $j = $rev1 - $nrrevs;
  my $scriptUrlPath = &TWiki::Func::getScriptUrlPath();
  for (my $i = $rev1; $i >= $j; $i -= 1) {
    $revisions .= " | <a href=\"$scriptUrlPath/view%SCRIPTSUFFIX%/%WEB%/%TOPIC%?rev=1.$i\">r1.$i</a>";
    if ($i == $j) {
      my $torev = $j - $nrrevs;
      $torev = 1 if $torev < 0;
      if ($j != $torev) {
	$revisions = "$revisions | <a href=\"$scriptUrlPath/rdiff%SCRIPTSUFFIX%/%WEB%/%TOPIC%?rev1=1.$j&amp;rev2=1.$torev\">...</a>";
      }
      last;
    } else {
      $revisions .= " | <a href=\"$scriptUrlPath/rdiff%SCRIPTSUFFIX%/%WEB%/%TOPIC%?rev1=1.$i&amp;rev2=1.". ($i - 1) . "\">&gt;</a>";
    }
  }

  return $revisions;
}

###############################################################################
# reused code from the BlackListPlugin
sub renderExternalLink
{
  my ($thePrefix, $theUrl, $thePostfix) = @_;

  my $addClass = 0;
  my $text = "$thePrefix$theUrl$thePostfix";

  $theUrl =~ /^http/i && ($addClass = 1); # only for http and hhtps
  $theUrl =~ /^$urlHost/i && ($addClass = 0); # not for own host
  $thePostfix =~ /^\s?class/ && ($addClass = 0); # prevent adding it twice

  if ($addClass) {
    $text = "$thePrefix$theUrl class=\"natExternalLink\"$thePostfix";
#    writeDebug("got external link '$text'");
#  } else {
#    writeDebug("no external link '$text'");
  }

  return $text;
}


###############################################################################
sub getCurRevision {
  my ($thisWeb, $thisTopic, $thisRev) = @_;

  my $rev;
  $rev = $query->param("rev") if $query;
  if ($rev) {
    $rev =~ s/r?1\.//go;
    return $rev;
  }

  $thisRev = '' unless $thisRev;

  my ($date, $user);

  if ($isBeijing) { # frelled
    ($date, $user, $rev) = &TWiki::Store::getRevisionInfo($thisWeb, $thisTopic, $thisRev);
  } else {
    ($date, $user, $rev) = &TWiki::Func::getRevisionInfo($thisWeb, $thisTopic, $thisRev);
  }

  return $rev;
}

###############################################################################
sub getPrevRevision {

  my $rev;
  $rev = $query->param("rev") if $query;

  my $numberOfRevisions = 
    ($isDakar)?$TWiki::cfg{NumberOfRevisions}:$TWiki::numberOfRevisions;

  $rev = $maxRev unless $rev;
  $rev =~ s/r?1\.//go; # cut major
  if ($rev > $numberOfRevisions) {
    $rev -= $numberOfRevisions;
    $rev = 1 if $rev < 1;
  } else {
    $rev = 1;
  }

  return $rev;
}


###############################################################################
# local copy with beijing backwards compatibility
sub getRevInfo {
  my ($thisWeb, $rev, $thisTopic) = @_;

  writeDebug("called getRevInfo");

  my ($date, $user);
  
  if ($isBeijing) { # frelled
    ($date, $user) = &TWiki::Store::getRevisionInfo($thisWeb, $thisTopic, "1.$rev");
  } else {
    ($date, $user) = &TWiki::Func::getRevisionInfo($thisWeb, $thisTopic, "1.$rev");
  }

  $user = &TWiki::Func::renderText(&TWiki::Func::userToWikiName($user));
  $date = &TWiki::Func::formatTime($date) unless $isBeijing;

  my $revInfo = "$date - $user";
  $revInfo =~ s/[\n\r]*//go;

  writeDebug("revInfo=$revInfo");
  writeDebug("done getRevInfo");
  return $revInfo;
}

###############################################################################
sub getMetaData {
  my ($meta, $key) = @_;

  my $result;
  if ($isDakar) {
    $result = $meta->get($key) if $isDakar;
  } else {
    my %tempHash = $meta->findOne($key);
    $result = \%tempHash;
  }

  return $result;
}

###############################################################################
sub escapeParameter {
  return '' unless $_[0];

  $_[0] =~ s/\\n/\n/g;
  $_[0] =~ s/\$n/\n/g;
  $_[0] =~ s/\\%/%/g;
  $_[0] =~ s/\$nop//g;
  $_[0] =~ s/\$percnt/%/g;
  $_[0] =~ s/\$dollar/\$/g;
}

1;

