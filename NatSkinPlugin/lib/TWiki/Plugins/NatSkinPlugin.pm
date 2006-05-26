###############################################################################
# NatSkinPlugin.pm - Plugin handler for the NatSkin.
# 
# Copyright (C) 2003-2006 MichaelDaum@WikiRing.com
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
        $baseWeb $baseTopic $currentWeb $currentTopic 
	$currentUser $VERSION $RELEASE $debug
        $isGuest $defaultWikiUserName $isEnabled
	$useSpamObfuscator $isBeijing $isDakar $isCairo
	$query $urlHost
	$defaultSkin $defaultVariation $defaultStyleSearchBox
	$defaultStyle $defaultStyleBorder $defaultStyleSideBar
	%maxRevs
	$hasInitKnownStyles $hasInitSkinState
	%knownStyles 
	%knownVariations 
	%knownBorders 
	%knownThins 
	%knownButtons 
	%skinState 
	%emailCollection $nrEmails $doneHeader
	$STARTWW $ENDWW
	%TWikiCompatibility
    );

$TWikiCompatibility{endRenderingHandler} = 1.1;

$debug = 0; # toggle me

# from Render.pm
$STARTWW = qr/^|(?<=[\s\(])/m;
$ENDWW = qr/$|(?=[\s\,\.\;\:\!\?\)])/m;

$VERSION = '$Rev$';
$RELEASE = '2.9996';

# TODO generalize and reduce the ammount of variables 
$defaultSkin    = 'nat';
$defaultStyle   = 'Clean';
$defaultStyleBorder = 'off';
$defaultStyleButtons = 'off';
$defaultStyleSideBar = 'left';
$defaultVariation = 'off';
$defaultStyleSearchBox = 'top';

###############################################################################
sub writeDebug {
  &TWiki::Func::writeDebug("- NatSkinPlugin - " . $_[0]) if $debug;
  #print STDERR "DEBUG: NatSkinPlugin - " . $_[0] . "\n" if $debug;
}


###############################################################################
sub initPlugin {
  ($baseTopic, $baseWeb, $currentUser) = @_;

  # check TWiki version: let's eat spagetti
  $isDakar = (defined $TWiki::RELEASE)?1:0;
  if ($isDakar) {# dakar
    $isBeijing = 0;
    $isCairo = 0;
  } else {# non-dakar
    my $wikiVersion = $TWiki::wikiversion; 

    if ($wikiVersion =~ /^01 Feb 2003/) {
      $isBeijing = 1; # beijing
      $isCairo = 0;
    } else {
      $isBeijing = 0; # cairo
      $isCairo = 1;
    }
  }
  writeDebug("isDakar=$isDakar isBeijing=$isBeijing isCairo=$isCairo");
  
  # check skin
  my $skin = TWiki::Func::getSkin();

  # clear NatSkinPlugin traces from session
  unless ($skin =~ /\b(nat|plain|rss|rssatom|atom)\b/) {
    &clearSessionValue('SKINSTYLE');
    &clearSessionValue('STYLEBORDER');
    &clearSessionValue('STYLEBUTTONS');
    &clearSessionValue('STYLESIDEBAR');
    &clearSessionValue('STYLEVARIATION');
    &clearSessionValue('STYLESEARCHBOX');
    &clearSessionValue('TABLEATTRIBUTES');

    #TWiki::Func::writeWarning("NatSkinPlugin used with skin $skin");
    $isEnabled = 0; # disable the plugin if it is used with a foreign skin, i.e. kupu
  } else {
    $isEnabled = 1;
  }

  &doInit();

  writeDebug("done initPlugin");
  return 1;
}

###############################################################################
sub doInit {

  writeDebug("called doInit");

  # get skin state from session
  $hasInitKnownStyles = 0;
  $hasInitSkinState = 0;
  &initKnownStyles();

  $defaultWikiUserName = &TWiki::Func::getDefaultUserName();
  $defaultWikiUserName = &TWiki::Func::userToWikiName($defaultWikiUserName, 1);
  my $wikiUserName = &TWiki::Func::userToWikiName($currentUser, 1);

  $isGuest = ($wikiUserName eq $defaultWikiUserName)?1:0;
  #writeDebug("defaultWikiUserName=$defaultWikiUserName, wikiUserName=$wikiUserName, isGuest=$isGuest");

  my $isScripted;
  $query = &TWiki::Func::getCgiQuery();
  if ($isDakar) {
    $isScripted = &TWiki::Func::getContext()->{'command_line'};
  } else {
    $isScripted = defined $query;
  }

  $useSpamObfuscator = &TWiki::Func::getPreferencesFlag('OBFUSCATEEMAIL');
  if ($useSpamObfuscator) {
    if ($isScripted || !$query) { # are we in cgi mode?
      $useSpamObfuscator = 0; # batch mode, i.e. mailnotification
      #writeDebug("no query ... batch mode");
    } else {
      # disable during register context
      my $theAction = $ENV{'SCRIPT_NAME'} || '';
      my $theSkin = $query->param('skin') || TWiki::Func::getSkin();
      my $theContentType = $query->param('contenttype');
      $theAction =~ s/^.*\///o;
      if (!$theAction || $theAction =~ /^(register|mailnotif)/ || 
	  $theSkin =~ /^rss/ ||
	  $theContentType) {
	$useSpamObfuscator = 0;
      }
    }
  }
  $nrEmails = 0;
  $doneHeader = 0;
  writeDebug("useSpamObfuscator=$useSpamObfuscator");

  $urlHost = &TWiki::Func::getUrlHost();
  %maxRevs = ();

  #writeDebug("done doInit");
}

###############################################################################
sub initKnownStyles {

  return if $hasInitKnownStyles;

  writeDebug("called initKnownStyles");
  $hasInitKnownStyles = 1;
  %knownStyles = ();
  %knownVariations = ();
  %knownBorders = ();
  %knownButtons = ();
  %knownThins = ();
  
  my $twikiWeb = &TWiki::Func::getTwikiWebname();
  my $stylePath = &TWiki::Func::getPreferencesValue('STYLEPATH') 
    || "$twikiWeb.NatSkin";
  my $pubDir = &TWiki::Func::getPubDir();

  foreach my $styleWebTopic (split(/[\s,]+/, $stylePath)) {
    my $styleWeb;
    my $styleTopic;
    if ($styleWebTopic =~ /^(.*)\.(.*?)$/) {
      $styleWeb = $1;
      $styleWeb =~ s/\./\//go;
      $styleTopic = $2;
    } else {
      next;
    }
    my $styleWebTopic = $styleWeb.'/'.$styleTopic;
    my $cssDir = $pubDir.'/'.$styleWebTopic;

    if (opendir(DIR, $cssDir))  {
      foreach my $fileName (readdir(DIR)) {
	if ($fileName =~ /((.*)Style\.css)$/) {
	  $knownStyles{$2} = $styleWebTopic.'/'.$1 unless $knownStyles{$2};
	} elsif ($fileName =~ /((.*)Variation\.css)$/) {
	  $knownVariations{$2} = $styleWebTopic.'/'.$1 unless $knownVariations{$2};
	} elsif ($fileName =~ /((.*)Border\.css)$/) {
	  $knownBorders{$2} = $styleWebTopic.'/'.$1 unless $knownBorders{$2};
	} elsif ($fileName =~ /((.*)Buttons\.css)$/) {
	  $knownButtons{$2} = $styleWebTopic.'/'.$1 unless $knownButtons{$2};
	} elsif ($fileName =~ /((.*)Thin\.css)$/) {
	  $knownThins{$2} = $styleWebTopic.'/'.$1 unless $knownThins{$1};
	}
      }
      closedir(DIR);
    }
  }
}

###############################################################################
sub initSkinState {

  return if $hasInitSkinState;

  $hasInitSkinState = 1;
  %skinState = ();

  writeDebug("called initSkinState");

  my $theStyle;
  my $theStyleBorder;
  my $theStyleButtons;
  my $theStyleSideBar;
  my $theStyleVariation;
  my $theStyleSearchBox;
  my $theToggleSideBar;
  my $theRaw;
  my $theReset;
  my $theSwitchStyle;
  my $theSwitchVariation;

  my $doStickyStyle = 0;
  my $doStickyBorder = 0;
  my $doStickyButtons = 0;
  my $doStickySideBar = 0;
  my $doStickySearchBox = 0;
  my $doStickyVariation = 0;

  # get finalisations
  
  # SMELL: we only get the WebPreferences' FINALPREFERENCES here
  my $finalPreferences = TWiki::Func::getPreferencesValue("FINALPREFERENCES");
  writeDebug("finalPreferences=$finalPreferences"); 
  my $isFinalStyle = 0;
  my $isFinalBorder = 0;
  my $isFinalButtons = 0;
  my $isFinalSideBar = 0;
  my $isFinalVariation = 0;
  my $isFinalSearchBox = 0;
  if ($finalPreferences) {
    my @finalPreferences = split(/[\s,]+/, $finalPreferences);
    $skinState{final} = ();
    push @{$skinState{final}}, 'style' if 
      ($isFinalStyle = grep(/^SKINSTYLE$/, @finalPreferences));
    push @{$skinState{final}}, 'border' if 
      ($isFinalBorder = grep(/^STYLEBORDER$/, @finalPreferences));
    push @{$skinState{final}}, 'buttons' if 
      ($isFinalButtons = grep(/^STYLEBUTTONS$/, @finalPreferences));
    push @{$skinState{final}}, 'sidebar' if 
      ($isFinalSideBar = grep(/^STYLESIDEBAR$/, @finalPreferences));
    push @{$skinState{final}}, 'variation' if 
      ($isFinalVariation = grep(/^STYLEVARIATION$/, @finalPreferences));
    push @{$skinState{final}}, 'searchbox' if 
      ($isFinalSearchBox = grep(/^STYLESEARCHBOX$/, @finalPreferences));
    push @{$skinState{final}}, 'switches' if 
      $isFinalBorder && $isFinalSideBar && $isFinalButtons && $isFinalSearchBox;
    push @{$skinState{final}}, 'all' if 
      $isFinalStyle && $isFinalVariation && $isFinalBorder && $isFinalSideBar &&
      $isFinalButtons && $isFinalSearchBox;
  }

  # from query
  if ($query) {
    $theRaw = $query->param('raw');
    $theSwitchStyle = $query->param('switchstyle');
    $theSwitchVariation = $query->param('switchvariation');
    $theReset = $query->param('resetstyle');
    $theStyle = $query->param('style') || '';
    if ($theReset || $theStyle eq 'reset') {
      writeDebug("clearing session values");
      $theStyle = '';
      &clearSessionValue('SKINSTYLE');
      &clearSessionValue('STYLEBORDER');
      &clearSessionValue('STYLEBUTTONS');
      &clearSessionValue('STYLESIDEBAR');
      &clearSessionValue('STYLEVARIATION');
      &clearSessionValue('STYLESEARCHBOX');
      &clearSessionValue('TABLEATTRIBUTES');
      my $redirectUrl = TWiki::Func::getViewUrl($baseWeb, $baseTopic);
      TWiki::Func::redirectCgiQuery($query, $redirectUrl); 
	# we need to force a new request because the session value preferences
	# are still loaded in the preferences cache; only clearing them in
	# the session object is not enough right now but will be during the next
	# request; so we redirect to the current url
    } else {
      $theStyleBorder = $query->param('styleborder'); 
      $theStyleButtons = $query->param('stylebuttons'); 
      $theStyleSideBar = $query->param('stylesidebar');
      $theStyleVariation = $query->param('stylevariation');
      $theStyleSearchBox = $query->param('stylesearchbox');
      $theToggleSideBar = $query->param('togglesidebar');
    }

    writeDebug("urlparam style=$theStyle") if $theStyle;
    writeDebug("urlparam styleborder=$theStyleBorder") if $theStyleBorder;
    writeDebug("urlparam stylebuttons=$theStyleButtons") if $theStyleButtons;
    writeDebug("urlparam stylesidebar=$theStyleSideBar") if $theStyleSideBar;
    writeDebug("urlparam stylevariation=$theStyleVariation") if $theStyleVariation;
    writeDebug("urlparam stylesearchbox=$theStyleSearchBox") if $theStyleSearchBox;
    writeDebug("urlparam togglesidebar=$theToggleSideBar") if $theToggleSideBar;
    writeDebug("urlparam switchvariation=$theSwitchVariation") if $theSwitchVariation;
  }

  # handle style
  &initKnownStyles();
  my $prefStyle = &TWiki::Func::getPreferencesValue('SKINSTYLE') || 
    $defaultStyle;
  $prefStyle =~ s/^\s*(.*)\s*$/$1/go;
  if ($theStyle && !$isFinalStyle) {
    $theStyle =~ s/^\s*(.*)\s*$/$1/go;
    $doStickyStyle = 1 if $theStyle ne $prefStyle;
  } else {
    $theStyle = $prefStyle;
  }
  if ($theStyle =~ /^(off|none)$/o) {
    $theStyle = 'off';
  } else {
    my $found = 0;
    foreach my $style (keys %knownStyles) {
      if ($style eq $theStyle || lc $style eq lc $theStyle) {
	$found = 1;
	$theStyle = $style;
	last;
      }
    }
    $theStyle = $defaultStyle unless $found;
  }
  $theStyle = $defaultStyle unless $knownStyles{$theStyle};
  $skinState{'style'} = $theStyle;
  writeDebug("theStyle=$theStyle");

  # cycle styles
  if ($theSwitchStyle && !$isFinalStyle) {
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
  my $prefStyleBorder = &TWiki::Func::getPreferencesValue('STYLEBORDER') ||
    $defaultStyleBorder;
  $prefStyleBorder =~ s/^\s*(.*)\s*$/$1/go;
  if ($theStyleBorder && !$isFinalBorder) {
    $theStyleBorder =~ s/^\s*(.*)\s*$/$1/go;
    $doStickyBorder = 1 if $theStyleBorder ne $prefStyleBorder;
  } else {
    $theStyleBorder = $prefStyleBorder;
  }
  $theStyleBorder = $defaultStyleBorder 
    if $theStyleBorder !~ /^(on|off|thin)$/;
  $theStyleBorder = $defaultStyleBorder 
    if $theStyleBorder eq 'on' && !$knownBorders{$theStyle};
  $theStyleBorder = $defaultStyleBorder 
    if $theStyleBorder eq 'thin' && !$knownThins{$theStyle};
  $skinState{'border'} = $theStyleBorder;

  # handle buttons
  my $prefStyleButtons = &TWiki::Func::getPreferencesValue('STYLEBUTTONS') ||
    $defaultStyleButtons;
  $prefStyleButtons =~ s/^\s*(.*)\s*$/$1/go;
  if ($theStyleButtons && !$isFinalButtons) {
    $theStyleButtons =~ s/^\s*(.*)\s*$/$1/go;
    $doStickyButtons = 1 if $theStyleButtons ne $prefStyleButtons;
  } else {
    $theStyleButtons = $prefStyleButtons;
  }
  $theStyleButtons = $defaultStyleButtons
    if $theStyleButtons !~ /^(on|off)$/;
  $theStyleButtons = $defaultStyleButtons
    if $theStyleButtons eq 'on' && !$knownButtons{$theStyle};
  $skinState{'buttons'} = $theStyleButtons;

  # handle sidebar 
  my $prefStyleSideBar = &TWiki::Func::getPreferencesValue('STYLESIDEBAR') ||
    $defaultStyleSideBar;
  $prefStyleSideBar =~ s/^\s*(.*)\s*$/$1/go;
  if ($theStyleSideBar && !$isFinalSideBar) {
    $theStyleSideBar =~ s/^\s*(.*)\s*$/$1/go;
    $doStickySideBar = 1 if $theStyleSideBar ne $prefStyleSideBar;
  } else {
    $theStyleSideBar = $prefStyleSideBar;
  }
  $theStyleSideBar = $defaultStyleSideBar
    if $theStyleSideBar !~ /^(left|right|both|off)$/;
  $skinState{'sidebar'} = $theStyleSideBar;
  $theToggleSideBar = undef
    if $theToggleSideBar && $theToggleSideBar !~ /^(left|right|both|off)$/;

  # handle searchbox
  my $prefStyleSearchBox = &TWiki::Func::getPreferencesValue('STYLESEARCHBOX') ||
    $defaultStyleSearchBox;
  $prefStyleSearchBox =~ s/^\s*(.*)\s*$/$1/go;
  if ($theStyleSearchBox && !$isFinalSearchBox) {
    $theStyleSearchBox =~ s/^\s*(.*)\s*$/$1/go;
    $doStickySearchBox = 1 if $theStyleSearchBox ne $prefStyleSearchBox;
  } else {
    $theStyleSearchBox = $prefStyleSearchBox;
  }
  $theStyleSearchBox = $defaultStyleSearchBox
    if $theStyleSearchBox !~ /^(top|pos1|pos2|pos3|off)$/;
  $skinState{'searchbox'} = $theStyleSearchBox;

  # handle variation 
  my $prefStyleVariation = &TWiki::Func::getPreferencesValue('STYLEVARIATION') ||
    $defaultVariation;
  $prefStyleVariation =~ s/^\s*(.*)\s*$/$1/go;
  if ($theStyleVariation && !$isFinalVariation) {
    $theStyleVariation =~ s/^\s*(.*)\s*$/$1/go;
    $doStickyVariation = 1 if $theStyleVariation ne $prefStyleVariation;
  } else {
    $theStyleVariation = $prefStyleVariation;
  }
  $found = 0;
  foreach my $variation (keys %knownVariations) {
    if ($variation eq $theStyleVariation || lc $variation eq lc $theStyleVariation) {
      $found = 1;
      $theStyleVariation = $variation;
      last;
    }
  }
  $theStyleVariation = $defaultVariation unless $found;
  $skinState{'variation'} = $theStyleVariation;

  # cycle styles
  if ($theSwitchVariation && !$isFinalVariation) {
    $theSwitchVariation = lc $theSwitchVariation;
    $doStickyVariation = 1;
    my $state = 0;
    my @knownVariations;
    if ($theSwitchVariation eq 'next') {
      @knownVariations = sort {$a cmp $b} keys %knownVariations #next
    } else {
      @knownVariations = sort {$b cmp $a} keys %knownVariations #prev
    }
    push @knownVariations, 'off';
    my $firstVari;
    foreach my $vari (@knownVariations) {
      $firstVari = $vari unless $firstVari;
      if ($theStyleVariation eq $vari) {
	$state = 1;
	next;
      }
      if ($state == 1) {
	$skinState{'variation'} = $vari;
	$state = 2;
	last;
      }
    }
    $skinState{'variation'} = $firstVari if $state == 1;
  }

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
    $skinState{'action'} = $ENV{'SCRIPT_NAME'} || '';
    $skinState{'action'} =~ s/^.*\///o;
  }

  # store sticky state into session
  &TWiki::Func::setSessionValue('SKINSTYLE', $skinState{'style'}) 
    if $doStickyStyle;
  &TWiki::Func::setSessionValue('STYLEBORDER', $skinState{'border'})
    if $doStickyBorder;
  &TWiki::Func::setSessionValue('STYLEBUTTONS', $skinState{'buttons'})
    if $doStickyButtons;
  &TWiki::Func::setSessionValue('STYLESIDEBAR', $skinState{'sidebar'})
    if $doStickySideBar;
  &TWiki::Func::setSessionValue('STYLEVARIATION', $skinState{'variation'})
    if $doStickyVariation;
  &TWiki::Func::setSessionValue('STYLESEARCHBOX', $skinState{'searchbox'})
    if $doStickySearchBox;
  &TWiki::Func::setSessionValue('TABLEATTRIBUTES', $tablePluginAttrs);

  # temporary toggles
  $theToggleSideBar = 'off' if $theRaw;
  $theToggleSideBar = 'off' if $skinState{'border'} eq 'thin' && 
    $skinState{'action'} =~ /^(login|logon|oops|edit|manage|rdiff|natsearch|changes|search)$/;

  # switch the sidebar off if we need to authenticate
  if ($isDakar && 
    $TWiki::cfg{AuthScripts} =~ /\b$skinState{'action'}\b/ &&
    !&TWiki::Func::getContext()->{authenticated}) {
    $theToggleSideBar = 'off';
  }

  $skinState{'sidebar'} = $theToggleSideBar 
    if $theToggleSideBar && $theToggleSideBar ne '';
}

###############################################################################
# commonTagsHandler:
# $_[0] - The text
# $_[1] - The topic
# $_[2] - The web
sub commonTagsHandler {
  return unless $isEnabled;
  $currentTopic = $_[1];
  $currentWeb = $_[2];

  &initSkinState(); # this might already be too late but there is no
                    # handler between initPlugin and beforeCommonTagsHandler
		    # which only matters if you've got a SessionPlugin and the 
		    # TablePlugin installed which most probably is only the 
		    # case on a cairo installation
  $_[0] =~ s/%SETSKINSTATE{(.*?)}%/&renderSetSkinStyle($1)/geo;

  # conditional content
  $_[0] =~ s/(\s*)%IFSKINSTATE{(.*?)}%(\s*)/&renderIfSkinState($2, $1, $3)/geos;
  while ($_[0] =~ s/(\s*)%IFSKINSTATETHEN{(?!.*%IFSKINSTATETHEN)(.*?)}%\s*(.*?)\s*%FISKINSTATE%(\s*)/&renderIfSkinStateThen($2, $3, $1, $4)/geos) {
    # nop
  }
  $_[0] =~ s/%IFACCESS{(.*?)}%/&renderIfAccess($1)/geo;# deprecated
  $_[0] =~ s/%NATLOGON%/&renderLogon()/geo;
  $_[0] =~ s/%NATLOGOUT%/&renderLogout()/geo;
  $_[0] =~ s/%WEBLINK%/renderWebLink()/geos;
  $_[0] =~ s/%WEBLINK{(.*?)}%/renderWebLink($1)/geos;
  $_[0] =~ s/%USERACTIONS%/&renderUserActions/geo;
  $_[0] =~ s/%FORMBUTTON%/&renderFormButton()/geo;
  $_[0] =~ s/%FORMBUTTON{(.*?)}%/&renderFormButton($1)/geo;
  
  $_[0] =~ s/%WIKIRELEASENAME%/&getReleaseName()/geo;
  $_[0] =~ s/%GETSKINSTYLE%/&renderGetSkinStyle()/geo;
  $_[0] =~ s/%KNOWNSTYLES%/&renderKnownStyles()/geo;
  $_[0] =~ s/%KNOWNVARIATIONS%/&renderKnownVariations()/geo;

  # REVISIONS only worked properly for the PatternSkin :(
  # REVARG is expanded for templates only :(
  # MAXREV is different on Cairo, Beijing and Dakar 
  # implementing this stuff again for maximum backwards compatibility
  $_[0] =~ s/%NATREVISIONS%/&renderRevisions()/geo;
  $_[0] =~ s/%PREVREV%/'1.' . &getPrevRevision()/geo;
  $_[0] =~ s/%CURREV%/'1.' . &getCurRevision()/geo; 
  $_[0] =~ s/%NATMAXREV%/'1.'.&getMaxRevision()/geo;

  # spam obfuscator
  if ($useSpamObfuscator) {
    $_[0] =~ s/\[\[mailto\:([a-zA-Z0-9\-\_\.\+]+\@[a-zA-Z0-9\-\_\.]+\..+?)(?:\s+|\]\[)(.*?)\]\]/&renderEmailAddrs([$1], $2)/ge;
    $_[0] =~ s/$STARTWW(?:mailto\:)?([a-zA-Z0-9\-\_\.\+]+\@[a-zA-Z0-9\-\_\.]+\.[a-zA-Z0-9\-\_]+)$ENDWW/&renderEmailAddrs([$1])/ge;
  }

  if (!$doneHeader && !$isDakar) {
    my $oldUseSpamObfuscator = $useSpamObfuscator;
    $useSpamObfuscator = 0;
    if($_[0] =~ s/<\/head>/&renderEmailObfuscator() . '<\/head>'/geo) {
      #writeDebug("wrote email obfuscator");
      $doneHeader = 1;
#      } else {
#	writeDebug("no email obfuscator code");
    }
    $useSpamObfuscator = $oldUseSpamObfuscator;
  }
  $_[0] =~ s/%WEBCOMPONENT{(.*?)}%/&renderWebComponent($1)/geo;
}

###############################################################################
sub endRenderingHandler {
  return unless $isEnabled;

  $_[0] =~ s/<a\s+([^>]*?href=(?:\"|\'|&quot;)?)([^\"\'\s>]+(?:\"|\'|\s|&quot;>)?)/'<a '.renderExternalLink($1,$2)/geoi;

  # remove leftover tags of supported plugins if they are not installed
  # so that they are remove from the NatSkin templates
  $_[0] =~ s/%STARTALIASAREA%//go;
  $_[0] =~ s/%STOPALIASAREA%//go;
  $_[0] =~ s/%ALIAS{.*?}%//go;
  $_[0] =~ s/%REDDOT{.*?}%//go;
}

###############################################################################
sub postRenderingHandler { 
  return unless $isEnabled;
  
  endRenderingHandler(@_); 

  if ($useSpamObfuscator) {
    $useSpamObfuscator = 0;
    &TWiki::Func::addToHEAD('EMAIL_OBFUSCATOR', &renderEmailObfuscator());
    $useSpamObfuscator = 1;
  }
}

###############################################################################
# deprecated
sub renderIfAccess {
  my $args = shift;

  my $theWebTopic = 
    &TWiki::Func::extractNameValuePair($args) ||
    &TWiki::Func::extractNameValuePair($args, 'topic') || '';

  my $theAction = 
    &TWiki::Func::extractNameValuePair($args, 'action') || 'view';

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


  my $theTopic = $currentTopic;
  my $theWeb = $currentWeb;

  if ($theWebTopic =~ /^(.*)\.(.*?)$/) {
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
    &escapeParameter($theThen);
    return TWiki::Func::expandCommonVariables($theThen, $currentTopic, $currentWeb);
  } else {
    &escapeParameter($theElse);
    return TWiki::Func::expandCommonVariables($theElse, $currentTopic, $currentWeb);
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

  #writeDebug("called renderIfSkinStateThen($args)");


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
  my $theSearchBox = &TWiki::Func::extractNameValuePair($args, 'searchbox');
  my $theVariation = &TWiki::Func::extractNameValuePair($args, 'variation');
  my $theRelease = lc &TWiki::Func::extractNameValuePair($args, 'release');
  my $theAction = &TWiki::Func::extractNameValuePair($args, 'action');
  my $theGlue = &TWiki::Func::extractNameValuePair($args, 'glue') || 'on';
  my $theFinal = &TWiki::Func::extractNameValuePair($args, 'final');

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
      (!$theSearchBox || $skinState{'searchbox'} =~ /$theSearchBox/) &&
      (!$theVariation || $skinState{'variation'} =~ /$theVariation/) &&
      (!$theRelease || $skinState{'release'} =~ /$theRelease/) &&
      (!$theAction || $skinState{'action'} =~ /$theAction/) &&
      (!$theFinal || grep(/$theFinal/, @{$skinState{'final'}}))) {
    #writeDebug("match then");
    if ($theThen =~ s/\$nop//go) {
      $theThen = TWiki::Func::expandCommonVariables($theThen, $currentTopic, $currentWeb);
    }
    return $before.$theThen.$after if $theThen;
  } else {
    if ($elsIfArgs) {
      #writeDebug("match elsif");
      return $before."%IFSKINSTATETHEN{$elsIfArgs}%$theElse%FISKINSTATE%".$after;
    } else {
      #writeDebug("match else");
      if ($theElse =~ s/\$nop//go) {
	$theElse = TWiki::Func::expandCommonVariables($theElse, $currentTopic, $currentWeb);
      }
      return $before.$theElse.$after if $theElse;
    }
  }

  #writeDebug("NO match");
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
  my $theVariation = &TWiki::Func::extractNameValuePair($args, 'variation');
  my $theSideBar = &TWiki::Func::extractNameValuePair($args, 'sidebar');
  my $theSearchBox = &TWiki::Func::extractNameValuePair($args, 'searchbox');
  my $theRelease = lc &TWiki::Func::extractNameValuePair($args, 'release');
  my $theAction = &TWiki::Func::extractNameValuePair($args, 'action');
  my $theGlue = &TWiki::Func::extractNameValuePair($args, 'glue') || 'on';
  my $theFinal = &TWiki::Func::extractNameValuePair($args, 'final');


  #writeDebug("called renderIfSkinState($args)");
  #writeDebug("theGlue=$theGlue");
  #writeDebug("releaseName=" . lc &getReleaseName());
  #writeDebug("skinRelease=$skinState{'release'}");
  #writeDebug("theRelease=$theRelease");

  $before = '' if ($theGlue eq 'on') || !$before;
  $after = '' if ($theGlue eq 'on') || !$after;

  # SMELL do a ifSkinStateImpl
  if ((!$theStyle || $skinState{'style'} =~ /$theStyle/) &&
      (!$theBorder || $skinState{'border'} =~ /$theBorder/) &&
      (!$theButtons || $skinState{'buttons'} =~ /$theButtons/) &&
      (!$theSideBar || $skinState{'sidebar'} =~ /$theSideBar/) &&
      (!$theSearchBox || $skinState{'searchbox'} =~ /$theSearchBox/) &&
      (!$theVariation || $skinState{'variation'} =~ /$theVariation/) &&
      (!$theRelease || $skinState{'release'} =~ /$theRelease/) &&
      (!$theAction || $skinState{'action'} =~ /$theAction/) &&
      (!$theFinal || grep(/$theFinal/, @{$skinState{'final'}}))) {

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
sub renderKnownVariations {
  return join(', ', sort {$a cmp $b} keys %knownVariations);
}

###############################################################################
# TODO: prevent illegal skin states
sub renderSetSkinStyle {
  my $args = shift;
  my $theButtons = &TWiki::Func::extractNameValuePair($args, 'buttons');
  my $theSideBar = &TWiki::Func::extractNameValuePair($args, 'sidebar');
  my $theVariation = &TWiki::Func::extractNameValuePair($args, 'variation');
  my $theStyle = &TWiki::Func::extractNameValuePair($args, 'style');
  my $theSearchBox = &TWiki::Func::extractNameValuePair($args, 'searchbox');
  my $theBorder = &TWiki::Func::extractNameValuePair($args, 'border');

  $skinState{'buttons'} = $theButtons if $theButtons;
  $skinState{'sidebar'} = $theSideBar if $theSideBar;
  $skinState{'variation'} = $theSideBar if $theVariation;
  $skinState{'style'} = $theStyle if $theStyle;
  $skinState{'searchbox'} = $theSearchBox if $theSearchBox;
  $skinState{'border'} = $theBorder if $theBorder;

  return '';
}

###############################################################################
sub renderGetSkinStyle {
 

  my $theStyle;
  my $theVariation;

  $theStyle = $skinState{'style'};

  return '' if $theStyle eq 'off';

  $theVariation = $skinState{'variation'} unless $skinState{'variation'} =~ /^(off|none)$/;

  # SMELL: why not use <link rel="stylesheet" href="..." type="text/css" media="all" />
  my $text = '';

  $text = 
    '<link rel="stylesheet" href="%PUBURL%/'.
    $knownStyles{$theStyle}.'"  type="text/css" media="all" />'."\n";

  if ($skinState{'border'} eq 'on') {
    $text .= 
      '<link rel="stylesheet" href="%PUBURL%/'.
      $knownBorders{$theStyle}.'"  type="text/css" media="all" />'."\n";
  } elsif ($skinState{'border'} eq 'thin') {
    $text .= 
      '<link rel="stylesheet" href="%PUBURL%/'.
      $knownThins{$theStyle}.'"  type="text/css" media="all" />'."\n";
  }

  if ($skinState{'buttons'} eq 'on') {
    $text .=
      '<link rel="stylesheet" href="%PUBURL%/'.
      $knownButtons{$theStyle}.'" type="text/css" media="all" />'."\n";
  }

  $text .=
    '<link rel="stylesheet" href="%PUBURL%/'.
    $knownVariations{$theVariation}.'" type="text/css" media="all" />'."\n" if $theVariation;

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

  my $rev = &getCurRevision($baseWeb, $baseTopic, $curRev);

  my $rawAction;
  if ($theRaw) {
    $rawAction =
      '<a href="' . 
      &TWiki::Func::getScriptUrl($baseWeb, $baseTopic, "view") . 
      "?rev=1.$rev\" accesskey=\"r\" title=\"View formatted topic\">View</a>";
  } else {
    $rawAction =
      '<a href="' .  
      &TWiki::Func::getScriptUrl($baseWeb, $baseTopic, "view") .  
      "?raw=on&rev=1.$rev\" accesskey=\"r\" title=\"View raw topic\">Raw</a>";
  }
  
  my $text;
  $curRev =~ s/r?1\.//go;
  my $maxRev = &getMaxRevision();
  if ($curRev && $curRev < $maxRev) {
    $text =
      '<strike>Edit</strike> | ' .
      '<strike>Attach</strike> | ' .
      '<strike>Move</strike> | ';
  } else {
    #writeDebug("get WHITEBOARD from $baseWeb.$baseTopic");
    my $whiteBoard = _getValueFromTopic($baseWeb, $baseTopic, 'WHITEBOARD') || '';
    $whiteBoard =~ s/^\s*(.*?)\s*$/$1/g;
    my $editUrlParams = '';
    my $useWysiwyg = &TWiki::Func::getPreferencesFlag('USEWYSIWYG');
    if ($TWiki::cfg{Plugins}{WysiwygPlugin} && $useWysiwyg) {
      $editUrlParams = '&skin=kupu';
    }  else {
      $editUrlParams = '&action=form' if $whiteBoard eq 'off';
    }
    $text = 
      '<a rel="nofollow" href="'
      . &TWiki::Func::getScriptUrl($baseWeb, $baseTopic, "edit") 
      . '?t=' . time() 
      . $editUrlParams
      . '" accesskey="e" title="Edit this topic">Edit</a> | ' .
      '<a rel="nofollow" href="'
      . &TWiki::Func::getScriptUrl($baseWeb, $baseTopic, "attach") 
      . '" accesskey="a" title="Attach image or document to this topic">Attach</a> | ' .
      '<a rel="nofollow" href="'
      . &TWiki::Func::getScriptUrl($baseWeb, $baseTopic, "rename")
      . '" accesskey="m" title="Move or rename this topic">Move</a> | ';
  }

  $text .=
      $rawAction . ' | ' .
      '<a rel="nofollow" href="' . &TWiki::Func::getScriptUrl($baseWeb, $baseTopic, "oops") . '?template=oopsrev&param1=%PREVREV%&param2=%CURREV%&param3=%NATMAXREV%" accesskey="d" title="View topic history">Diffs</a> | ' .
      '<a rel="nofollow" href="' . &TWiki::Func::getScriptUrl($baseWeb, $baseTopic, "oops") . '?template=oopsmore" accesskey="x" title="More topic actions">More</a>';


  return $text;
}

###############################################################################
sub renderWebComponent {
  my $args = shift;

  my $theComponent = &TWiki::Func::extractNameValuePair($args);
  my $name = lc $theComponent;
  $name =~ s/^currentWeb//o;

  return '' if $skinState{$name} && $skinState{$name} eq 'off';

  my $text = getWebComponent($theComponent);
  $text .= "\n" if $name eq 'sidebar'; # SMELL: extra linefeed hack for sidebars

  return $text
}

###############################################################################
# search path 
# 1. search TheComponent in current web
# 2. search TWikiTheComponent in Main web
# 3. search TWikiTheComponent in TWiki web
# 4. search TheComponent in TWiki web
# (like: TheComponent = WebSideBar)
sub getWebComponent {
  my $component = shift;

  #writeDebug("called getWebComponent($component)");

  # get component for web
  my $text = '';
  my $meta = '';
  my $mainWeb = &TWiki::Func::getMainWebname();
  my $twikiWeb = &TWiki::Func::getTwikiWebname();

  my $theWeb = $baseWeb; # NOTE: don't use the currentWeb
  my $theComponent = $component;
  if (&TWiki::Func::topicExists($theWeb, $theComponent)) { # current
    ($meta, $text) = &TWiki::Func::readTopic($theWeb, $theComponent);
  } else {
    $theWeb = $mainWeb;
    $theComponent = 'TWiki'.$component;
    if (&TWiki::Func::topicExists($theWeb, $theComponent)) { # main
      ($meta, $text) = &TWiki::Func::readTopic($theWeb, $theComponent);
    } else {
      $theWeb = $twikiWeb;
      #$theComponent = 'TWiki'.$component;
      if (&TWiki::Func::topicExists($theWeb, $theComponent)) { # twiki
	($meta, $text) = &TWiki::Func::readTopic($theWeb, $theComponent);
      } else {
	$theWeb = $twikiWeb;
	$theComponent = $component;
	if (&TWiki::Func::topicExists($theWeb, $theComponent)) {
	  ($meta, $text) = &TWiki::Func::readTopic($theWeb, $theComponent);
	} else {
	  return ''; # not found
	}
      }
    }
  }

  # extract INCLUDE area
  if ($text =~ /%STARTINCLUDE%(.*?)%STOPINCLUDE%/gs) {
    $text = $1;
  }
  #$text =~ s/^\s*//o;
  #$text =~ s/\s*$//o;
  $text = &TWiki::Func::expandCommonVariables($text, $component, $theWeb);

  # ignore permission warnings here ;)
  $text =~ s/No permission to read.*//g;

  #writeDebug("done getWebComponent()");

  return $text;
}

###############################################################################
sub renderWebLink {
  my $args = shift || '';

  my $theWeb = &TWiki::Func::extractNameValuePair($args) || 
    &TWiki::Func::extractNameValuePair($args, 'web') || $baseWeb;
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
# display url to login
sub renderLogon {

  my $logonCgi = 'natlogon';
  if ($isDakar) {
    if ($TWiki::cfg{LoginManager} =~ /TemplateLogin/) {
      $logonCgi = 'login';
    } elsif ($TWiki::cfg{LoginManager} =~ /ApacheLogin/) {
      $logonCgi = 'viewauth';
    }
  }
  my $logonScriptUrl = &TWiki::Func::getScriptUrl($baseWeb, $baseTopic, $logonCgi);
  return '<a rel="nofollow" href="'.$logonScriptUrl.'" accesskey="l" title="Login to <nop>%WIKITOOLNAME%">Login</a>';

  return $dispUser;
}

###############################################################################
# display url to logout
sub renderLogout {

  my $logoutCgi = 'natlogon';
  if ($isDakar) {
    if ($TWiki::cfg{LoginManager} =~ /TemplateLogin/) {
      $logoutCgi = 'view';
    } elsif ($TWiki::cfg{LoginManager} =~ /ApacheLogin/) {
      return ''; # cant logout
    }
  }
  my $logoutWeb = &TWiki::Func::getMainWebname(); 
  my $logoutTopic = 'WebHome';
  if (&TWiki::Func::checkAccessPermission('VIEW', $defaultWikiUserName, '', 
    $baseTopic, $baseWeb)) {
    $logoutWeb = $baseWeb;
    $logoutTopic = $baseTopic;
  }
  my $logoutScriptUrl = &TWiki::Func::getScriptUrl($logoutWeb, $logoutTopic, $logoutCgi);

  if ($logoutCgi eq 'natlogon') {
    return '| <a rel="nofollow" href="'
	   . $logoutScriptUrl 
	   . '?web='
	   . $logoutWeb
	   . '&amp;topic='
	   . $logoutTopic
	   . '&amp;username='
	   . $defaultWikiUserName
	   . '" accesskey="l" title="Logout of <nop>%WIKITOOLNAME%">Logout</a>';
  } else {
    return '| <a rel="nofollow" href="'
	   . $logoutScriptUrl 
	   . '?logout=1'
	   . '" accesskey="l" title="Logout of <nop>%WIKITOOLNAME%">Logout</a>';
  }
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
sub renderFormButton {

  my $saveCmd = '';
  $saveCmd = $query->param('cmd') || '' if $query;
  return '' if $saveCmd eq 'repRev';

  my $args = shift || '';
  my $theFormat = &TWiki::Func::extractNameValuePair($args) ||
		  &TWiki::Func::extractNameValuePair($args, 'format');

  my ($meta, $dumy) = &TWiki::Func::readTopic($baseWeb, $baseTopic);
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
  } elsif (&TWiki::Func::getPreferencesValue('WEBFORMS', $baseWeb)) {
    $actionText = 'Add form';
  } else {
    return '';
  }
  
  my $text = "<a href=\"javascript:submitEditFormular('save', '$action');\" accesskey=\"f\" title=\"$actionText\">$actionText</a>";
  $theFormat =~ s/\$1/$text/;
  return $theFormat;
}

###############################################################################
sub renderEmailAddrs {
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

  #writeDebug("called renderEmailObfuscator()");

  my $text = "\n".
    '<script type="text/javascript">'."\n".
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

  #writeDebug("called renderRevisions");

  my $rev1;
  my $rev2;
  $rev1 = $query->param("rev1") if $query;
  $rev2 = $query->param("rev2") if $query;

  my $topicExists = &TWiki::Func::topicExists($baseWeb, $baseTopic);
  if ($topicExists) {
    
    $rev1 = 0 unless $rev1;
    $rev2 = 0 unless $rev2;
    $rev1 =~ s/r?1\.//go;  # cut 'r' and major
    $rev2 =~ s/r?1\.//go;  # cut 'r' and major

    my $maxRev = &getMaxRevision();
    $rev1 = $maxRev if $rev1 < 1;
    $rev1 = $maxRev if $rev1 > $maxRev;
    $rev2 = 1 if $rev2 < 1;
    $rev2 = $maxRev if $rev2 > $maxRev;

    $revTitle1 = "r1.$rev1";
    
    $revInfo1 = getRevInfo($baseWeb, $rev1, $baseTopic);
    if ($rev1 != $rev2) {
      $revTitle2 = "r1.$rev2";
      $revInfo2 = getRevInfo($baseWeb, $rev2, $baseTopic);
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
sub renderExternalLink {
  my ($thePrefix, $theUrl) = @_;

  my $addClass = 0;
  my $text = $thePrefix.$theUrl;
  my $httpsUrlHost = $urlHost;
  $httpsUrlHost =~ s/^http:\/\//https:\/\//go;

  $theUrl =~ /^http/i && ($addClass = 1); # only for http and hhtps
  $theUrl =~ /^$urlHost/i && ($addClass = 0); # not for own host
  $theUrl =~ /^$httpsUrlHost/i && ($addClass = 0); # not for own host
  $thePrefix =~ /class="nop"/ && ($addClass = 0); # prevent adding it 
  $thePrefix =~ /class="natExternalLink"/ && ($addClass = 0); # prevent adding it twice

  if ($addClass) {
    #writeDebug("called renderExternalLink($thePrefix, $theUrl)");
    $text = "class=\"natExternalLink\" target=\"_blank\" $thePrefix$theUrl";
    #writeDebug("text=$text");
  }

  return $text;
}


###############################################################################
sub getCurRevision {
  my ($thisWeb, $thisTopic, $thisRev) = @_;

  $thisWeb = $baseWeb unless $thisWeb;
  $thisTopic = $baseTopic unless $thisTopic;

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

  $rev = &getMaxRevision() unless $rev;
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

  #writeDebug("called getRevInfo");

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

  #writeDebug("revInfo=$revInfo");
  #writeDebug("done getRevInfo");
  return $revInfo;
}

###############################################################################
sub getMaxRevision {
  my ($thisWeb, $thisTopic) = @_;

  $thisWeb = $baseWeb unless $thisWeb;
  $thisTopic = $baseTopic unless $thisTopic;

  my $maxRev = $maxRevs{"$thisWeb.$thisTopic"};
  return $maxRev if defined $maxRev;

  if ($isDakar) {
    $maxRev = $TWiki::Plugins::SESSION->{store}->getRevisionNumber($thisWeb, $thisTopic);
  } else {
    $maxRev = &TWiki::Store::getRevisionNumber($thisWeb, $thisTopic);
  }
  $maxRev =~ s/r?1\.//go;  # cut 'r' and major
  $maxRevs{"$thisWeb.$thisTopic"} = $maxRev;
  return $maxRev;
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

  # using dakar's Func API
  if ($isDakar) {
    #return $TWiki::Plugins::SESSION->{client}->clearSessionValue($key);
    return &TWiki::Func::clearSessionValue($key);
  }
  
  # using the SessionPlugin
  if (defined &TWiki::Plugins::SessionPlugin::clearSessionValueHandler) {
    return &TWiki::Plugins::SessionPlugin::clearSessionValueHandler($key);
  }

  # last resort
  return &TWiki::Func::setSessionValue($key, undef);
}


1;

