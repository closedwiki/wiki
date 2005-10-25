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
        $web $topic $user $installWeb $VERSION $RELEASE $debug
        $isGuest $defaultWikiUserName
	$useSpamObfuscator $isBeijing $isDakar $isCairo
	$maxRev $query $urlHost
	$defaultSkin 
	$defaultStyle $defaultStyleBorder $defaultStyleSideBar
	%knownStyles $hasInitKnownStyles
	$knownStyleBorders $knownStyleSidebars
	%skinState $hasInitSkinState
	%emailCollection $nrEmails $doneHeader
	$STARTWW $ENDWW
    );

# from Render.pm
$STARTWW = qr/^|(?<=[\s\(])/m;
$ENDWW = qr/$|(?=[\s\,\.\;\:\!\?\)])/m;

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in ACTIVATED_PLUGINS.
$RELEASE = '2.60';

$defaultSkin    = 'nat';
$defaultStyle   = 'Clean';
$defaultStyleBorder = 'off';
$defaultStyleButtons = 'off';
$defaultStyleSideBar = 'left';
$knownStyleBorders = '^(on|off|thin)$';
$knownStyleButtons = '^(on|off)$';
$knownStyleSidebars = '^(left|right|both|off)$';

###############################################################################
sub writeDebug {
  &TWiki::Func::writeDebug("- NatSkinPlugin - " . $_[0]) if $debug;
  #print STDERR "DEBUG: NatSkinPlugin - " . $_[0] . "\n" if $debug;
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
  $useSpamObfuscator = 1;
  if ($query) { # are we in cgi mode?
    # disable during register context
    my $theAction = $query->url(-relative=>1); # cannot use skinState yet, we are in initPlugin
    my $theSkin = $query->param('skin') || '';
    my $theContentType = $query->param('contenttype');
    writeDebug("theAction=$theAction");
    if ($theAction =~ /^(register|mailnotif|feed)/ || 
	$theSkin eq 'rss' ||
	$theContentType) {
      $useSpamObfuscator = 0;
    }
  } else {
    $useSpamObfuscator = 0; # batch mode, i.e. mailnotification
    writeDebug("no query ... batch mode");
  }
  $nrEmails = 0;
  $doneHeadere = 0;
  writeDebug("useSpamObfuscator=$useSpamObfuscator");

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
  my $theStyleButtons;
  my $theStyleSideBar;
  my $theToggleSideBar;
  my $theRaw;
  my $theReset;
  my $theSwitchStyle;

  my $doStickyStyle = 0;
  my $doStickyBorder = 0;
  my $doStickyButtons = 0;
  my $doStickySideBar = 0;

  # from query
  if ($query) {
    $theRaw = $query->param('raw');
    $theSwitchStyle = $query->param('switchstyle');
    $theReset = $query->param('reset');
    if ($theReset) {
      writeDebug("clearing session values");
      &clearSessionValue('NATSKIN_SKINSTYLE');
      &clearSessionValue('NATSKIN_STYLEBORDER');
      &clearSessionValue('NATSKIN_STYLEBUTTONS');
      &clearSessionValue('NATSKIN_STYLESIDEBAR');
    } else {
      $theStyle = $query->param('style');
      $theStyleBorder = $query->param('styleborder'); 
      $theStyleButtons = $query->param('stylebuttons'); 
      $theStyleSideBar = $query->param('stylesidebar');
      $theToggleSideBar = $query->param('togglesidebar');
    }

    #writeDebug("urlparam style=$theStyle") if $theStyle;
    #writeDebug("urlparam styleborder=$theStyleBorder") if $theStyleBorder;
    #writeDebug("urlparam stylebuttons=$theStyleButtons") if $theStyleButtons;
    #writeDebug("urlparam stylesidebar=$theStyleSideBar") if $theStyleSideBar;
    #writeDebug("urlparam togglesidebar=$theToggleSideBar") if $theToggleSideBar;
  }

  # handle style
  &initKnownStyles();
  if ($theStyle) {
    $doStickyStyle = 1;
  } else {
    if ($skinState{'style'}) {
      #writeDebug("found skinStyle=$skinState{'style'}");
      $theStyle = $skinState{'style'};
    } else {
      #writeDebug("getting skin state from session or pref");
      $theStyle = 
	  &TWiki::Func::getSessionValue('NATSKIN_SKINSTYLE') ||
	  &TWiki::Func::getPreferencesValue("SKINSTYLE") ||
	  $defaultStyle;
    }
  }
  $theStyle =~ s/\s+$//;
  #writeDebug("$theStyle is known") if $knownStyles{$theStyle};
  #writeDebug("$theStyle is UNKNOWN") unless $knownStyles{$theStyle};
  my $found = 0;
  foreach my $style (keys %knownStyles) {
    if ($style eq $theStyle || lc $style eq lc $theStyle) {
      $found = 1;
      $theStyle = $style;
      last;
    }
  }
  $theStyle = $defaultStyle unless $found;
  $skinState{'style'} = $theStyle;

  # cycle styles
  if ($theSwitchStyle) {
    $theSwitchStyle = lc $theSwitchStyle;
    $doStickyStyle = 1;
    my $state = 0;
    my $firstStyle;
    my @knownStyles;
    if ($theSwitchStyle eq 'next') {
      @knownStyles = sort {$a cmp $b} keys %knownStyles #next
    } else {
      @knownStyles = sort {$b cmp $a} keys %knownStyles #prev
    }
    foreach my $style (@knownStyles) {
      $firstStyle = $style unless $firstStyle;
      if ($theStyle eq $style) {
	$state = 1;
	next;
      }
      if ($state == 1) {
	$skinState{'style'} = $style;
	$state = 2;
	last;
      }
    }
    $skinState{'style'} = $firstStyle if $state == 1;
  }

  # handle border
  if ($theStyleBorder) {
    $doStickyBorder = 1;
  } else {
    if ($skinState{'border'}) {
      #writeDebug("found skinStyleBorder=$skinState{'border'}");
      $theStyleBorder = $skinState{'border'};
    } else {
      $theStyleBorder =
	&TWiki::Func::getSessionValue('NATSKIN_STYLEBORDER') ||
	&TWiki::Func::getPreferencesValue("STYLEBORDER") ||
	$defaultStyleBorder;
    }
  }
  $theStyleBorder =~ s/\s+$//;
  $theStyleBorder = $defaultStyleBorder
    if $theStyleBorder !~ /$knownStyleBorders/;
  $skinState{'border'} = $theStyleBorder;

  # handle buttons
  if ($theStyleButtons) {
    $doStickyButtons = 1;
  } else {
    if ($skinState{'buttons'}) {
      #writeDebug("found skinStyleButtons=$skinState{'buttons'}");
      $theStyleButtons = $skinState{'buttons'};
    } else {
      $theStyleButtons =
	&TWiki::Func::getSessionValue('NATSKIN_STYLEBUTTONS') ||
	&TWiki::Func::getPreferencesValue("STYLEBUTTONS") ||
	$defaultStyleButtons;
    }
  }
  $theStyleButtons =~ s/\s+$//;
  $theStyleButtons = $defaultStyleButtons
    if $theStyleButtons !~ /$knownStyleButtons/;
  $skinState{'buttons'} = $theStyleButtons;

  # handle sidebar */
  if ($theStyleSideBar) {
    $doStickySideBar = 1;
  } else {
    if ($skinState{'sidebar'}) {
      #writeDebug("found skinStyleSideBar=$skinState{'sidebar'}");
      $theStyleSideBar = $skinState{'sidebar'};
    } else {
      $theStyleSideBar =
	&TWiki::Func::getSessionValue('NATSKIN_STYLESIDEBAR') ||
	&TWiki::Func::getPreferencesValue("STYLESIDEBAR") ||
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
    &TWiki::Func::getPreferencesValue('BASETABLEATTRIBUTES') ||
    &TWiki::Func::getPreferencesValue('NATSKINPLUGIN_BASETABLEATTRIBUTES') || '';
  my $skinTablePluginAttrs =
    &TWiki::Func::getPreferencesValue("$prefsName") ||
    &TWiki::Func::getPreferencesValue("NATSKINPLUGIN_$prefsName") || '';
  # order matters ... differently *sigh*
  if ($isDakar) {
    $tablePluginAttrs .= ' ' . $skinTablePluginAttrs;
  } else {
    $tablePluginAttrs = $skinTablePluginAttrs . ' ' . $tablePluginAttrs;
  }
  $tablePluginAttrs =~ s/\s+$//;
  $tablePluginAttrs =~ s/^\s+//;
  
  # handle release
  $skinState{'release'} = lc &getReleaseName();

  # handle action
  if ($query) { # are we in cgi mode?
    $skinState{'action'} = $query->url(-relative=>1); 
  }

  # store (part of the) state into session
  # SMELL: this will overwrite per web -> does it work with webs using different settings?
  &TWiki::Func::setSessionValue('NATSKIN_SKINSTYLE', $skinState{'style'}) 
    if $doStickyStyle;
  &TWiki::Func::setSessionValue('NATSKIN_STYLEBORDER', $skinState{'border'})
    if $doStickyBorder;
  &TWiki::Func::setSessionValue('NATSKIN_STYLEBUTTONS', $skinState{'buttons'})
    if $doStickyButtons;
  &TWiki::Func::setSessionValue('NATSKIN_STYLESIDEBAR', $skinState{'sidebar'})
    if $doStickySideBar;
  &TWiki::Func::setSessionValue('TABLEATTRIBUTES', $tablePluginAttrs);

  # temporary toggles
  $theToggleSideBar = 'off' if $theRaw;
  $theToggleSideBar = 'off' if $skinState{'border'} eq 'thin' && 
    $skinState{'action'} =~ /^(edit|manage|rdiff|natsearch|changes|search)$/;
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
  writeDebug("commonTagsHandler called");
  &initSkinState(); # this might already be too late but there is no
                    # handler between initPlugin and beforeCommonTagsHandler
		    # which only matters if you've got a SessionPlugin and the 
		    # TablePlugin installed which most probably is only the 
		    # case on a cairo installation

  # caution: order of tags matters

  $_[0] =~ s/\%FORMATLIST{(.*?)}%/&renderFormatList($1)/geo; # SMELL: be a plugin

  # conditional content
  $_[0] =~ s/(\s*)%IFSKINSTATE{(.*?)}%(\s*)/&renderIfSkinState($2, $1, $3)/geos;
  while ($_[0] =~ s/(\s*)%IFSKINSTATETHEN{(?!.*%IFSKINSTATETHEN)(.*?)}%\s*(.*?)\s*%FISKINSTATE%(\s*)/&renderIfSkinStateThen($2, $3, $1, $4)/geos) {
    # nop
  }
  $_[0] =~ s/(\s*)%IFDEFINED{(.*?)}%(\s*)/&renderIfDefined($2, $1, $3)/geos;
  while ($_[0] =~ s/(\s*)%IFDEFINEDTHEN{(?!.*%IFDEFINEDTHEN)(.*?)}%\s*(.*?)\s*%FIDEFINED%(\s*)/&renderIfDefinedThen($2, $3, $1, $4)/geos) {
    # nop
  }

  $_[0] =~ s/%IFACCESS{(.*?)}%/&renderIfAccess($1)/geo;
  $_[0] =~ s/%NATLOGON%/&renderLogon()/geo;
  $_[0] =~ s/%WEBLINK%/renderWebLink()/geos;
  $_[0] =~ s/%WEBLINK{(.*?)}%/renderWebLink($1)/geos;
  $_[0] =~ s/%USERACTIONS%/&renderUserActions/geo;
  $_[0] =~ s/%FORMBUTTON%/&renderFormButton()/geo;
  $_[0] =~ s/%FORMBUTTON{(.*?)}%/&renderFormButton($1)/geo;
  $_[0] =~ s/%WIKIRELEASENAME%/&getReleaseName()/geo;
  $_[0] =~ s/%GETSKINSTYLE%/&renderGetSkinStyle()/geo;
  $_[0] =~ s/%KNOWNSTYLES%/&renderKnownStyles()/geo;
  $_[0] =~ s/%GROUPSUMMARY%/&renderGroupSummary($_[0])/geo; # SMELL: be a plugin, broken on dakar
  $_[0] =~ s/%ALLUSERS%/&renderAllUsers()/geo;

  # REVISIONS only worked properly for the PatternSkin :(
  # REVARG is expanded for templates only :(
  # MAXREV is different on Cairo, Beijing and Dakar 
  # implementing this stuff again for maximum backwards compatibility
  $_[0] =~ s/%NATREVISIONS%/&renderRevisions()/geo;
  $_[0] =~ s/%PREVREV%/'1.' . &getPrevRevision()/geo;
  $_[0] =~ s/%CURREV%/'1.' . &getCurRevision($web, $topic)/geo; 
  $_[0] =~ s/%NATMAXREV%/1.$maxRev/go;

  # spam obfuscator
  if ($useSpamObfuscator) {
    $_[0] =~ s/\[\[mailto\:([a-zA-Z0-9\-\_\.\+]+\@[a-zA-Z0-9\-\_\.]+\..+?)(?:\s+|\]\[)(.*?)\]\]/&renderEmailAddrs([$1], $2)/ge;
    $_[0] =~ s/$STARTWW(?:mailto\:)?([a-zA-Z0-9\-\_\.\+]+\@[a-zA-Z0-9\-\_\.]+\.[a-zA-Z0-9\-\_]+)$ENDWW/&renderEmailAddrs([$1])/ge;
  }

  if (!$doneHeader && !$isDakar) {
    my $oldUseSpamObfuscator = $useSpamObfuscator;
    $useSpamObfuscator = 0;
    if($_[0] =~ s/<\/head>/&renderEmailObfuscator() . '<\/head>'/geo) {
      writeDebug("wrote email obfuscator");
      $doneHeader = 1;
#      } else {
#	writeDebug("no email obfuscator code");
    }
    $useSpamObfuscator = $oldUseSpamObfuscator;
  }

}

###############################################################################
sub endRenderingHandler {
  $_[0] =~ s/%WEBSIDEBAR%/&renderWebSideBar()/geo;
  $_[0] =~ s/%MYSIDEBAR%/&renderMySideBar()/geo;
  $_[0] =~ s/<a\s+([^>]*?href=(?:\"|\'|&quot;)?)([^\"\'\s>]+(?:\"|\'|\s|&quot;>)?)/'<a '.renderExternalLink($1,$2)/geoi;

  # remove leftover tags of supported plugins if they are not installed
  # so that they are remove from the NatSkin templates
  $_[0] =~ s/%STARTALIASAREA%//go;
  $_[0] =~ s/%STOPALIASAREA%//go;
  $_[0] =~ s/%REDDOT{.*?}%//go;

  if ($isDakar) {
    my $oldUseSpamObfuscator = $useSpamObfuscator;
    $useSpamObfuscator = 0;
    &TWiki::Func::addToHEAD('EMAIL_OBFUSCATOR', &renderEmailObfuscator());
    $useSpamObfuscator = $oldUseSpamObfuscator;
  }
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
  my ($args, $text, $before, $after) = @_;

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
  my $theButtons = &TWiki::Func::extractNameValuePair($args, 'buttons');
  my $theSideBar = &TWiki::Func::extractNameValuePair($args, 'sidebar');
  my $theRelease = lc &TWiki::Func::extractNameValuePair($args, 'release');
  my $theAction = &TWiki::Func::extractNameValuePair($args, 'action');
  my $theGlue = &TWiki::Func::extractNameValuePair($args, 'glue') || 'on';

  $before = '' if ($theGlue eq 'on') || !$before;
  $after = '' if ($theGlue eq 'on') || !$after;
  
  #writeDebug("theStyle=$theStyle");
  #writeDebug("theThen=$theThen");
  #writeDebug("theElse=$theElse");


  # SMELL get a ifSkinStateTImpl
  if ((!$theStyle || $skinState{'style'} =~ /$theStyle/) &&
      (!$theBorder || $skinState{'border'} =~ /$theBorder/) &&
      (!$theButtons || $skinState{'buttons'} =~ /$theButtons/) &&
      (!$theSideBar || $skinState{'sidebar'} =~ /$theSideBar/) &&
      (!$theRelease || $skinState{'release'} =~ /$theRelease/) &&
      (!$theAction || $skinState{'action'} =~ /$theAction/)) {
    writeDebug("match then");
    return $before.$theThen.$after if $theThen;
  } else {
    if ($elsIfArgs) {
      writeDebug("match elsif");
      return $before."%IFSKINSTATETHEN{$elsIfArgs}%$theElse%FISKINSTATE%".$after;
    } else {
      writeDebug("match else");
      return $before.$theElse.$after if $theElse;
    }
  }

  writeDebug("NO match");
  return $before.$after;
  
}

###############################################################################
sub renderIfSkinState {
  my ($args, $before, $after) = @_;

  my $theStyle = &TWiki::Func::extractNameValuePair($args) ||
	      &TWiki::Func::extractNameValuePair($args, 'style');
  my $theThen = &TWiki::Func::extractNameValuePair($args, 'then');
  my $theElse = &TWiki::Func::extractNameValuePair($args, 'else');
  my $theBorder = &TWiki::Func::extractNameValuePair($args, 'border');
  my $theButtons = &TWiki::Func::extractNameValuePair($args, 'buttons');
  my $theSideBar = &TWiki::Func::extractNameValuePair($args, 'sidebar');
  my $theRelease = lc &TWiki::Func::extractNameValuePair($args, 'release');
  my $theAction = &TWiki::Func::extractNameValuePair($args, 'action');
  my $theGlue = &TWiki::Func::extractNameValuePair($args, 'glue') || 'on';


  #writeDebug("called renderIfSkinState($args)");
  #writeDebug("theGlue=$theGlue");
  #writeDebug("releaseName=" . lc &getReleaseName());
  #writeDebug("skinRelease=$skinState{'release'}");
  #writeDebug("theRelease=$theRelease");

  $before = '' if ($theGlue eq 'on') || !$before;
  $after = '' if ($theGlue eq 'on') || !$after;

  # SMELL get a ifSkinStateTImpl
  if ((!$theStyle || $skinState{'style'} =~ /$theStyle/) &&
      (!$theBorder || $skinState{'border'} =~ /$theBorder/) &&
      (!$theButtons || $skinState{'buttons'} =~ /$theButtons/) &&
      (!$theSideBar || $skinState{'sidebar'} =~ /$theSideBar/) &&
      (!$theRelease || $skinState{'release'} =~ /$theRelease/) &&
      (!$theAction || $skinState{'action'} =~ /$theAction/)) {

    &escapeParameter($theThen);
    #writeDebug("match");
    return $before.$theThen.$after if $theThen;
  } else {
    &escapeParameter($theElse);
    #writeDebug("NO match");
    return $before.$theElse.$after if $theElse;
  }

  return $before.$after;
}

###############################################################################
sub renderKnownStyles {

  return join(', ', sort {$a cmp $b} keys %knownStyles);
}

###############################################################################
sub renderGetSkinStyle {

  my $theBorder;
  my $theSideBar;
  my $theButtons;
  my $cssDir = 
    &TWiki::Func::getPubDir() . '/' . 
    &TWiki::Func::getTwikiWebname() . '/NatSkin';

  $theBorder = $skinState{'style'} . 'Border' if $skinState{'border'} eq 'on';
  $theBorder = $skinState{'style'} . 'Thin' if $skinState{'border'} eq 'thin';
  $theSideBar = $skinState{'style'} . 'Right' if $skinState{'sidebar'} eq 'right';
  $theSideBar = 'NoSideBar' if $skinState{'sidebar'} eq 'off';
  $theButtons = $skinState{'style'} . 'Buttons' if $skinState{'buttons'} eq 'on';

  my $text = 
    '<style type="text/css">' . "\n" .
    '@import url("%PUBURL%/%TWIKIWEB%/NatSkin/' . $skinState{'style'} . 'Style.css");' . "\n";

  $text .=
    '@import url("%PUBURL%/%TWIKIWEB%/NatSkin/' . $theBorder . '.css");' . "\n"
    if $theBorder && -e "$cssDir/$theBorder.css";

  $text .=
    '@import url("%PUBURL%/%TWIKIWEB%/NatSkin/' . $theButtons . '.css");' . "\n"
    if $theButtons && -e "$cssDir/$theButtons.css";;

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
sub ifDefinedImpl {
  my ($theVariable, $theAction, $theThen, $theElse, $theElsIfArgs, $before, $after, $theGlue) = @_;

  #writeDebug("called ifDefinedImpl()");
  #writeDebug("theVariable='$theVariable'");
  #writeDebug("theAction='$theAction'");
  #writeDebug("theThen='$theThen'");
  #writeDebug("theElse='$theElse'");
  #writeDebug("theElsIfArgs='$theElsIfArgs'") if $theElsIfArgs;
  
  $before = '' if ($theGlue eq 'on') || !$before;
  $after = '' if ($theGlue eq 'on') || !$after;

  if (!$theAction || $skinState{'action'} =~ /$theAction/) {
    if ($theVariable =~ /^%([A-Z]+)%$/) {
      my $varName = $1;
      if ($isBeijing) {
	my $topicText = &TWiki::Func::readTopic($web, $topic);
	$theVariable = &_getValueFromTopic($web, $topic, $varName, $topicText);
	$theVariable =~ s/^\s+//;
	$theVariable =~ s/\s+$//;
	$theVariable = &TWiki::Func::expandCommonVariables($theVariable);
	$theThen =~ s/%$varName%/$theVariable/g;# SMELL: do we need to backport topic vars?
      } else {
	return $before.$theElse.$after unless $theElsIfArgs;
	$theVariable = '';
      }
    }
    return $before.$theThen.$after if $theVariable ne ''; # variable is defined
  }
  
  return $before."%IFDEFINEDTHEN{$theElsIfArgs}%$theElse%FIDEFINED%".$after if $theElsIfArgs;
  return $before.$theElse.$after; # variable is empty
}

###############################################################################
sub renderIfDefined {

  my ($args, $before, $after) = @_;

  $args = '' unless $args;

  writeDebug("called renderIfDefined($args)");
  
  my $theVariable = &TWiki::Func::extractNameValuePair($args);
  my $theAction = &TWiki::Func::extractNameValuePair($args, 'action') || '';
  my $theThen = &TWiki::Func::extractNameValuePair($args, 'then') || $theVariable;
  my $theElse = &TWiki::Func::extractNameValuePair($args, 'else') || '';
  my $theGlue = &TWiki::Func::extractNameValuePair($args, 'glue') || 'on';

  return &ifDefinedImpl($theVariable, $theAction, $theThen, $theElse, undef, $before, $after, $theGlue);
}

###############################################################################
sub renderIfDefinedThen {
  my ($args, $text, $before, $after) = @_;

  $args = '' unless $args;

  writeDebug("called renderIfDefinedThen($args)");

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

  return &ifDefinedImpl($theVariable, $theAction, $theThen, $theElse, $elsIfArgs, $before, $after, $theGlue);
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
  my $thePattern = &TWiki::Func::extractNameValuePair($args, 'pattern') || '\s*(.*)\s*';
  my $theFormat = &TWiki::Func::extractNameValuePair($args, 'format') || '$1';
  my $theSplit = &TWiki::Func::extractNameValuePair($args, 'split') || ',';
  my $theSeparator = &TWiki::Func::extractNameValuePair($args, 'separator') || ', ';
  my $theLimit = &TWiki::Func::extractNameValuePair($args, 'limit') || -1;
  my $theSort = &TWiki::Func::extractNameValuePair($args, 'sort') || 'off';
  my $theUnique = &TWiki::Func::extractNameValuePair($args, 'unique') ||'';
  my $theExclude = &TWiki::Func::extractNameValuePair($args, 'exclude') || '';

  &escapeParameter($theList);
  $theList = &TWiki::Func::expandCommonVariables($theList, $topic, $web);

  #writeDebug("thePattern='$thePattern'");
  #writeDebug("theFormat='$theFormat'");
  #writeDebug("theSplit='$theSplit'");
  #writeDebug("theSeparator='$theSeparator'");
  #writeDebug("theLimit='$theLimit'");
  #writeDebug("theSort='$theSort'");
  #writeDebug("theUnique='$theUnique'");
  #writeDebug("theExclude='$theExclude'");
  #writeDebug("theList='$theList'");

  my %seen = ();
  my @result;
  foreach my $item (split /$theSplit/, $theList, $theLimit) {
    #writeDebug("found '$item'");
    next if $theExclude && $item =~ /($theExclude)/;
    $item =~ m/$thePattern/;
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
    #writeDebug("after susbst '$item'");
    if ($theUnique) {
      next if $seen{$item};
      $seen{$item} = 1;
    }
    next if $item eq '';
    push @result, $item;
  }

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

  my $result = join($theSeparator, @result);
  &escapeParameter($result);

  #writeDebug("result=$result");

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

  my $action;
  my $actionText;
  if ($isDakar) {
    if ($form) {
      $action = 'replaceform';
    } else {
      $action = 'addform';
    }
  } else {
    $action = 'add form';
  }
  if ($form) {
    $actionText = 'Change form';
  } elsif (&TWiki::Func::getPreferencesValue('WEBFORMS', $web)) {
    $actionText = 'Add form';
  } else {
    return '';
  }
  
  my $text = "<a href=\"javascript:submitEditFormular('save', '$action');\" accesskey=\"f\">$actionText</a>";
  $theFormat =~ s/\$1/$text/;
  return $theFormat;
}

###############################################################################
sub renderEmailAddrs
{
  my ($emailAddrs, $linkText) = @_;

  $linkText = '' unless $linkText;

  #writeDebug("called renderEmailAddrs(".join(", ", @$emailAddrs).", $linkText)");

  my $emailKey = '_email'.$nrEmails;
  $nrEmails++;

  $emailCollection{$emailKey} = [$emailAddrs, $linkText]; 
  my $text = "<span class=\"natEmail\" id=\"$emailKey\">$emailKey</span>";

  #writeDebug("result: $text");
  return $text;
}

###############################################################################
sub renderEmailObfuscator {

  writeDebug("called renderEmailObfuscator()");

  my $text = "\n".
    '<script language="javascript" type="text/javascript">'."\n".
    '<!--'."\n";

  $text .= "function initObfuscator() {\n";
  $text .= "   var addrs = new Array();\n";
  foreach my $emailKey (sort keys %emailCollection) {
    my $emailAddrs = $emailCollection{$emailKey}->[0];
    my $linkText = $emailCollection{$emailKey}->[1];
    my $index = 0;
    foreach my $addr (@$emailAddrs) {
      next unless $addr =~ m/^([a-zA-Z0-9\-\_\.\+]+)\@([a-zA-Z0-9\-\_\.]+)\.(.+?)$/;
      my $theAccount = $1;
      my $theSubDomain = $2;
      my $theTopDomain = $3;
      $text .= "   addrs[$index] = new Array('$theSubDomain','$theAccount','$theTopDomain');\n";
      $index++
    }
    $text .= "   writeEmailAddrs(addrs, '$linkText', '$emailKey');\n";
    $text .= "   delete addrs; addrs = new Array();\n";
  }
  $text .= "}\n";
  $text .= "//-->\n</script>\n";
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
  my ($thePrefix, $theUrl) = @_;



  my $addClass = 0;
  my $text = $thePrefix.$theUrl;

  $theUrl =~ /^http/i && ($addClass = 1); # only for http and hhtps
  $theUrl =~ /^$urlHost/i && ($addClass = 0); # not for own host
  $thePrefix =~ /\sclass="natExternalLink"\s/ && ($addClass = 0); # prevent adding it twice

  if ($addClass) {
#    writeDebug("called renderExternalLink()");
#    writeDebug("thePrefix=$thePrefix");
#    writeDebug("theUrl=$theUrl");
    $text = "class=\"natExternalLink\" target=\"_blank\" $thePrefix$theUrl";
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

###############################################################################
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


1;

