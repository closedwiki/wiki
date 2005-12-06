# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2003 Othello Maurer <maurer@nats.informatik.uni-hamburg.de>
# Copyright (C) 2003-2005 Michael Daum <micha@nats.informatik.uni-hamburg.de>
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
# =========================
package TWiki::Plugins::AliasPlugin;    # change the package name and $pluginName!!!
# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $RELEASE
        $aliasPattern $debug $aliasWikiWordsOnly
	%seenAliasWebTopics $wordRegex $wikiWordRegex
	$defaultAliasTopic $foundError $isInitialized $insideAliasArea
	%TWikiCompatibility $START $STOP
    );

$VERSION = '$Rev$';
$RELEASE = '1.2';

$START = '(?:^|(?<=[\w\b\s\,\.\;\:\!\?\)\(]))';
$STOP = '(?:$|(?=[\w\b\s\,\.\;\:\!\?\)\(]))';

$TWikiCompatibility{endRenderingHandler} = 1.1;
$TWikiCompatibility{outsidePREHandler} = 1.1;

# 0: off, 1: debug, 2: heavy debug
$debug = 0;

# =========================
sub writeDebug {
  TWiki::Func::writeDebug("AliasPlugin - " . $_[0]) if $debug;
}

# =========================
sub initPlugin
{
  ( $topic, $web, $user, $installWeb ) = @_;

  # check for Plugins.pm versions
  if ($TWiki::Plugins::VERSION < 1) {
    TWiki::Func::writeWarning( "Version mismatch between AliasPlugin and Plugins.pm" );
    return 0;
  }


  # more in doInit if we actually have an alias area
  $isInitialized = 0;
  %seenAliasWebTopics = ();
  $insideAliasArea = 0;
  $foundError = 0;

  # Plugin correctly initialized
  writeDebug("initPlugin( $web.$topic ) is OK" );

  return 1;
}

# =========================
sub doInit {
  return if $isInitialized;
  #writeDebug("doinit() called");


  # for getRegularExpression
  if ($TWiki::Plugins::VERSION < 1.020) {
    eval 'use TWiki::Contrib::CairoContrib;';
    writeDebug("reading in CairoContrib");
  }

  # get plugin flags
  $aliasWikiWordsOnly = 
    TWiki::Func::getPreferencesFlag("ALIASPLUGIN_ALIAS_WIKIWORDS_ONYL");
  $defaultAliasTopic = 
    TWiki::Func::getPreferencesValue("ALIASPLUGIN_DEFAULT_ALIASES");
  
  # decide on how to match alias words
  $wikiWordRegex = &TWiki::Func::getRegularExpression('wikiWordRegex');
  if ($aliasWikiWordsOnly) {
    $wordRegex = $wikiWordRegex;
  } else {
    $wordRegex = '\w+';
  }

  # init globals
  my $topicRegex = &TWiki::Func::getRegularExpression('mixedAlphaNumRegex');
  my $webRegex = &TWiki::Func::getRegularExpression('webNameRegex');

  if ($defaultAliasTopic =~ /^($topicRegex)$/) {
    my $twikiWeb = &TWiki::Func::getTwikiWebname();
    &getAliases(0, "$twikiWeb.$defaultAliasTopic");
  } elsif ($defaultAliasTopic =~ /^($webRegex)\.($topicRegex)$/) {
    &getAliases(0, $defaultAliasTopic);
  }
  &getAliases(1);
  $isInitialized = 1;
}


# =========================
sub commonTagsHandler 
{
  # order matters. example: UNALIAS -> dump all ALIAS -> add one alias
  $_[0] =~ s/%(ALIAS|ALIASES|UNALIAS)(?:{(.*)?})?%/&handleAllAliasCmds($1, $2)/ge;
}

# =========================
sub outsidePREHandler
{

  #writeDebug("outsidePREHandler called for '$_[0]'");
  if ($_[0] =~ /%STARTALIASAREA%/) {
    $insideAliasArea = 1;
    #writeDebug("found STARTALIASAREA") if $debug > 1;
  }
  if ($_[0] =~ /%STOPALIASAREA%/) {
    $insideAliasArea = 0;
    #writeDebug("found STOPALIASAREA") if $debug > 1;
  }

  #writeDebug("insideAliasArea=$insideAliasArea");
  $_[0] = &handleAliasArea($_[0]) if $insideAliasArea;
}

# =========================
sub preRenderingHandler {

  my $result = '';
  foreach my $line (split(/\r?\n/, $_[0])) {
    outsidePREHandler($line);
    $result .= $line . "\n";
  }

  $_[0] = $result;
}

# =========================
sub endRenderingHandler {
  $_[0] =~ s/%STARTALIASAREA%//go;
  $_[0] =~ s/%STOPALIASAREA%//go;
}

# =========================
sub postRenderingHandler {
  $_[0] =~ s/%STARTALIASAREA%//go;
  $_[0] =~ s/%STOPALIASAREA%//go;
}

# =========================
sub handleAllAliasCmds {
  my ($name, $args) = @_;

  &doInit(); # delayed initialization

  return handleAlias($args) if $name eq 'ALIAS';
  return handleAliases($args) if $name eq 'ALIASES';
  return handleUnAlias($args) if $name eq 'UNALIAS';
  return '<font color=\"red\">Error: never reach ...</font>';
}

# =========================
sub handleAliases {
  my $args = shift;

  #writeDebug("handleAliases() called");

  if ($args) {
    my $doMerge = &TWiki::Func::extractNameValuePair($args, "merge") || 'off';
    if ($doMerge eq 'on') {
      $doMerge = 1;
    } elsif ($doMerge eq 'off') {
      $doMerge = 0;
    } else {
      $foundError = 1;
      return '<font color="red">' .
	     'Error in %<nop>ALIASES%: =merge= must be =on= or =off= </font>';
    }

    return "" if &getAliases($doMerge, &TWiki::Func::extractNameValuePair($args));
    $foundError = 1;
    return '<font color="red">' .
	   'Error in %<nop>ALIASES%: no alias definitions found</font>';
  }

  my $text = "<noautolink>\n";
  $text .= "| *Name* | *Value* |\n";
  foreach my $key (sort {uc($a) cmp uc($b)} keys %aliasHash) {
    $text .= "| <nop>$key | $aliasHash{$key} |\n";
  }
  $text .= "</noautolink>\n";
  
  return $text;
}

# =========================
sub handleAlias {
  my $args = shift;

  #writeDebug("handleAlias() called");

  my $thisKey = &TWiki::Func::extractNameValuePair($args, 'name');
  my $thisValue = &TWiki::Func::extractNameValuePair($args, 'value');

  if ($thisKey && $thisValue) {
    $aliasHash{$thisKey} = &getConvenientAlias($thisKey, $thisValue);
    makeAliasPattern();
    writeDebug("handleAlias(): added alias '$thisKey' -> '$thisValue')");
    return "";
  }

  $foundError = 1;
  return '<font color="red">Error in %<nop>ALIAS%: need a =name= and a =value= </font>';
}

# =========================
sub handleUnAlias {
  my $args = shift;

  #writeDebug("handleUnAlias() called");

  if ($args) {
    my $thisKey = &TWiki::Func::extractNameValuePair($args) ||
		  &TWiki::Func::extractNameValuePair($args, 'name');

    if ($thisKey) {
      my $thisValue = $aliasHash{$thisKey};
      if ($thisValue) {
	delete $aliasHash{$thisKey};
	makeAliasPattern();
	#writeDebug("handleUnAlias(): removed alias '$thisKey' -> '$thisValue')");
      }
      return "";
    }

    $foundError = 1;
    return '<font color="red">Error in %<nop>UNALIAS%: don\'t know what to unalias</font>';
  } 

  #writeDebug("handleUnAlias(): dumping all aliases");
  %aliasHash = ();

  return "";
}

# =========================
sub makeAliasPattern {
  $aliasPattern = '';
  foreach my $key (keys %aliasHash) {
    $key =~ s/\\/\\\\/go;
    $key =~ s/\(/\\(/go;
    $key =~ s/\)/\\)/go;
    $key =~ s/\./\\./go;
    $aliasPattern .= '|' if $aliasPattern;
    $aliasPattern .= "(?:$key)";
  }
  writeDebug("makeAliasPattern(): aliasPattern='$aliasPattern'") if $aliasPattern;
}

# =========================
sub getAliases
{
  my ($doMerge, $thisWebTopic) = @_;
  my $thisWeb;
  my $thisTopic;

  # extract web and topic name
  my $topicRegex = &TWiki::Func::getRegularExpression('mixedAlphaNumRegex');
  my $webRegex = &TWiki::Func::getRegularExpression('webNameRegex');

  $thisWebTopic = $defaultAliasTopic unless $thisWebTopic;
  $thisWebTopic =~ s/^\s+//o;
  $thisWebTopic =~ s/\s+$//o;
  if ($thisWebTopic =~ /^($topicRegex)$/) {
    $thisTopic = $1;
    $thisWeb = $web;
  } elsif ($thisWebTopic =~ /^($webRegex)\.($topicRegex)$/) {
    $thisWeb = $1;
    $thisTopic = $2;
  }

  writeDebug("getAliases($doMerge, $thisWeb.$thisTopic) called");


  # find topic with alias definitions

  # look for thisWeb.thisTopic
  #writeDebug("looking for $thisWeb.$thisTopic");
  if (!&TWiki::Func::topicExists($thisWeb, $thisTopic)) {

    # look for TWIKIWEB.thisTopic
    $thisWeb = &TWiki::Func::getTwikiWebname();
    #writeDebug("looking for $thisWeb.$thisTopic");
    if (!&TWiki::Func::topicExists($thisWeb, $thisTopic)) {

      # nothing there
      #writeDebug("getAliases($webTopic) - no alias definitions found");
      return 0;
    }
  }
  # have we alread red these aliaes
  if (defined $seenAliasWebTopics{"$thisWeb.$thisTopic"}) {
    writeDebug("bailing out on $thisWeb.$thisTopic");
    return 1;
  }
  $seenAliasWebTopics{"$thisWeb.$thisTopic"} = 1;
  writeDebug("reading aliases from $thisWeb.$thisTopic");

  # parse the plugin preferences lines
  my $prefText = TWiki::Func::readTopicText($thisWeb, $thisTopic);

  #$prefText =~ s/%INCLUDE{(.*?)}%/&handleIncludeFile($1, $topic, $web)/ge;

  if (!$doMerge) {
    #writeDebug("getAliases(): dumping old aliases");
    %aliasHash = ();
  } else {
    #writeDebug("getAliases(): merging aliases");
  }

  foreach my $line (split /\n/, $prefText) {
    if ($line =~ /^(?:\t| {3})+\* (?:\<nop\>)?($wordRegex): +(.*)$/) {
      my $key = $1;
      my $value = $2;
      $value =~ s/\s+$//go;

      $aliasHash{$key} = &getConvenientAlias($key, $value);

      writeDebug("config match: key='$key', value='$aliasHash{$key}'");
    }
  }
  # handle our ALIAS commands
  commonTagsHandler($prefText);
  makeAliasPattern();

  return 1;
}

# =========================
sub getConvenientAlias {
  my ($key, $value) = @_;

  #writeDebug("getConvenientAlias($key, $value) called");

  # convenience for wiki-links
  if ($value =~ /([^.]+)\.$wikiWordRegex/) {
    $value = "\[\[$value\]\[$key\]\]";
  }

  #writeDebug("returns '$value'");

  return $value;
}

# =========================
sub handleAliasArea {

  my $text = shift;
  return '' unless $text;

  &doInit(); # delayed initialization
  return $text if $foundError || !$aliasPattern;

  writeDebug("handleAliasArea() called for '$text'") if $debug > 1;

  my $result = '';

  $text =~ s/<nop>/NOPTOKEN/g;
  foreach my $line (split(/\n/, $text)) {

    # escape html tags
    while ($line =~ /([^<]*)((?:<[^>]*>)*|<)/g) {
      
      my $substr = $1;
      my $tail = $2;

      #writeDebug("html: substr='$substr', tail='$tail'\n");
      
      # escape twiki tags
      if ($substr) {
	while ($substr =~ /([^%]*)(((%[A-Z][a-zA-Z_0-9]+({[^}]+})?%)*)|%)/g) {
	
	  my $substr = $1;
	  my $tail = $2;

	  #writeDebug("twiki tags: substr='$substr', tail='$tail'\n");
	  
	  # escape twiki links
	  if ($substr) {
	    while ($substr =~ /([^\[]*)((?:\[[^\]]*\])*|\[)/g) {

	      my $substr = $1;
	      my $tail = $2;

	      #writeDebug("twiki links: substr='$substr', tail='$tail'\n");

	      # do the substitution
	      if ($substr) {

		if ($debug > 1) { 
		  $substr =~ s/$START($aliasPattern)$STOP/&_debugSubstitute($1)/ge;
		} else {
		  $substr =~ s/$START($aliasPattern)$STOP/$aliasHash{$1}/gm;
		}
		$result .= $substr;

	      }
	      $result .= $tail if $tail;
	    }
	  }
	  $result .= $tail if $tail;
	}
      }
      $result .= $tail if $tail;
    }
  }
  $result =~ s/NOPTOKEN/<nop>/g;

  writeDebug("result is '$result'") if $debug > 1;
  return $result;
}

# =========================
sub _debugSubstitute
{
  my ($key) = @_;
  my $value = $aliasHash{$key};
  writeDebug("subst '$key' -> '$value'");
  return $value; 
}

1;
