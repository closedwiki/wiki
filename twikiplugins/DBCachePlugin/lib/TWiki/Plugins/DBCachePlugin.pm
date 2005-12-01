# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2005 Michael Daum <micha@nats.informatik.uni-hamburg.de>
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

package TWiki::Plugins::DBCachePlugin;

use strict;
use vars qw( 
  $VERSION $RELEASE $debug $pluginName %webDB 
  $wikiWordRegex 
  $currentWeb $currentTopic $currentUser $installWeb
);

use TWiki::Contrib::DBCacheContrib;
use TWiki::Contrib::DBCacheContrib::Search;
use TWiki::Plugins::DBCachePlugin::WebDB;

$VERSION = '$Rev$';
$RELEASE = '0.91';
$pluginName = 'DBCachePlugin';
$debug = 0; # toggle me

###############################################################################
sub writeDebug {
  #&TWiki::Func::writeDebug('- '.$pluginName.' - '.$_[0]) if $debug;
  print STDERR "DEBUG: - $pluginName - $_[0]\n" if $debug;
}

###############################################################################
sub initPlugin {
  ($currentTopic, $currentWeb, $currentUser, $installWeb) = @_;

  %webDB = ();

  TWiki::Func::registerTagHandler('DBQUERY', \&_DBQUERY);
  TWiki::Func::registerTagHandler('DBCALL', \&_DBCALL);
  TWiki::Func::registerTagHandler('DBDUMP', \&_DBDUMP); # for debugging

  $wikiWordRegex = TWiki::Func::getRegularExpression('wikiWordRegex');

  #writeDebug("initialized");
  return 1;
}

###############################################################################
sub getDB {
  my $theWeb = shift;

#  writeDebug("called getDB($theWeb)");

  unless ($webDB{$theWeb}) {
    my $impl = TWiki::Func::getPreferencesValue('WEBDB', $theWeb) 
      || 'TWiki::Plugins::DBCachePlugin::WebDB';
    $impl =~ s/^\s*(.*?)\s*$/$1/o;
    $webDB{$theWeb} = new $impl($theWeb);
    $webDB{$theWeb}->load();
  }

  return $webDB{$theWeb};
}

###############################################################################
sub _DBQUERY {
  my ($session, $params, $theTopic, $theWeb) = @_;
  
  #writeDebug("called _DBQUERY(" . $params->stringify() . ")");

  # params
  my $theSearch = $params->{_DEFAULT} || $params->{search};
  my $theTopics = $params->{topics} || $params->{topic};
  
  return '' if $theTopics && $theTopics eq 'none';

  my $theFormat = $params->{format} || '$topic';
  my $theHeader = $params->{header} || '';
  my $theFooter = $params->{footer} || '';
  my $theInclude = $params->{include};
  my $theExclude = $params->{exclude};
  my $theOrder = $params->{order} || 'name';
  my $theReverse = $params->{reverse} || 'off';
  my $theSep = $params->{separator} || '$n';
  my $theLimit = $params->{limit} || '';
  my $theSkip = $params->{skip} || 0;
  my $theHideNull = $params->{hidenull} || 'off';
  $theWeb = $params->{web} || $theWeb;

  my $theDB = getDB($theWeb);

  # get topics
  my @topicNames = ();
  if ($theTopics) {
    @topicNames = split(/, /, $theTopics);
  }

  # normalize 
  $theSkip =~ s/[^-\d]//go;
  $theSkip = 0 if $theSkip eq '';
  $theSkip = 0 if $theSkip < 0;
  $theFormat = '' if $theFormat eq 'none';
  $theSep = '' if $theSep eq 'none';

  my ($topicNames, $hits, $msg) = $theDB->dbQuery($theSearch, 
    \@topicNames, $theOrder, $theReverse, $theInclude, $theExclude);
  #print STDERR "DEBUG: got topicNames=@$topicNames\n";

  return &inlineError($msg) if $msg;

  $theLimit =~ s/[^\d]//go;
  $theLimit = scalar(@$topicNames) if $theLimit eq '';
  $theLimit += $theSkip;


  my $count = scalar(@$topicNames);
  return '' if ($count <= $theSkip) && $theHideNull eq 'on';

  # format
  my $text = '';
  if ($theFormat && $theLimit) {
    my $index = 0;
    my $isFirst = 1;
    foreach my $topicName (@$topicNames) {
      $index++;
      next if $index <= $theSkip;
      my $topicObj = $hits->{$topicName};
      my $topicWeb = $topicObj->fastget('web');
      my $format = '';
      $format = $theSep unless $isFirst;
      $isFirst = 0;
      $format .= $theFormat;
      $format =~ s/\$formfield\((.*?)\)/$theDB->getFormField($topicName, $1)/geo;
      $format =~ s/\$expand\((.*?)\)/$theDB->expandPath($topicObj, $1)/geo;
      $format =~ s/\$formatTime\((.*?)(?:,\s*'([^']*?)')?\)/TWiki::Func::formatTime($theDB->expandPath($topicObj, $1), $2)/geo; # single quoted
      #$format =~ s/\$dbcall\((.*?)\)/dbCall($1)/ge; ## TODO
      $format = expandVariables($format, topic=>$topicName, web=>$topicWeb, index=>$index, count=>$count);
      $text .= $format;
      last if $index == $theLimit;
    }
  }

  $theHeader = expandVariables($theHeader.$theSep, count=>$count, web=>$theWeb) if $theHeader;
  $theFooter = expandVariables($theSep.$theFooter, count=>$count, web=>$theWeb) if $theFooter;

  $text = &TWiki::Func::expandCommonVariables("$theHeader$text$theFooter", $currentTopic, $theWeb);
  return $text;
}

###############################################################################
sub _DBCALL {
  my ($session, $params, $theTopic, $theWeb) = @_;

  #writeDebug("called _DBCALL");

  # remember args for the key before mangling the params
  my $args = $params->stringify();
  my $section = $params->remove('section') || 'default';
  my $warn = $params->remove('warn') || 'on';
  $warn = ($warn eq 'on')?1:0;
  my $thisTopic = $params->remove('_DEFAULT') || '';
  my $thisWeb = $theWeb;
  ($thisWeb, $thisTopic) = &TWiki::Func::normalizeWebTopicName($thisWeb, $thisTopic);

  #writeDebug("thisWeb=$thisWeb thisTopic=$thisTopic");

  # get web and topic
  my $thisDB = getDB($thisWeb);
  my $topicObj = $thisDB->fastget($thisTopic);
  unless ($topicObj) {
    if ($warn) {
      return inlineError("ERROR: DBCALL can't find topic <nop>$thisTopic in <nop>$thisWeb");
    } else {
      return '';
    }
  }

  # check access rights
  my $wikiUserName = TWiki::Func::getWikiUserName();
  unless (TWiki::Func::checkAccessPermission('VIEW', $wikiUserName, undef, $thisTopic, $thisWeb)) {
    if ($warn) {
      return inlineError("ERROR: DBCALL access to '$thisWeb.$thisTopic' denied");
    } 
    return '';
  }


  # get section
  my $sectionText = $topicObj->fastget("_section$section") if $topicObj;
  if (!$sectionText) {
    if($warn) {
      return inlineError("ERROR: DBCALL can't find section '$section' in topic '$thisWeb.$thisTopic'");
    } else {
      return '';
    }
  }

  # prevent recursive calls
  my $key = $thisWeb.'.'.$thisTopic;
  my $count = grep($key, keys %{$session->{dbcalls}});
  $key .= $args;
  if ($session->{dbcalls}->{$key} || $count > 99) {
    if($warn) {
      return inlineError("ERROR: DBCALL reached max recursion at '$thisWeb.$thisTopic'");
    }
    return '';
  }
  $session->{dbcalls}->{$key} = 1;

  # substitute variables
  $sectionText =~ s/%INCLUDINGWEB%/$theWeb/g;
  $sectionText =~ s/%INCLUDINGTOPIC%/$theTopic/g;
  $sectionText =~ s/%WEB%/$thisWeb/g;
  $sectionText =~ s/%TOPIC%/$thisTopic/g;
  foreach my $key (keys %$params) {
    $sectionText =~ s/%$key%/$params->{$key}/g;
  }

  # expand
  $sectionText = TWiki::Func::expandCommonVariables($sectionText, $thisTopic, $thisWeb);

  # cleanup
  delete $session->{dbcalls}->{$key};

  return $sectionText;
  #return '<verbatim>'.$sectionText.'</verbatim>';
}

###############################################################################
sub _DBDUMP {
  my ($session, $params, $theTopic, $theWeb) = @_;

  #writeDebug("called _DBDUMP");

  my $thisTopic = $params->{_DEFAULT} || $theTopic;
  my $thisWeb = $params->{web} || $theWeb;
  ($thisWeb, $thisTopic) = TWiki::Func::normalizeWebTopicName($thisWeb, $thisTopic);
  my $theDB = getDB($thisWeb);

  my $topicObj = $theDB->fastget($thisTopic) || '';
  my $result = "\n<noautolink>\n";
  $result .= "---++ [[$thisWeb.$thisTopic]]\n$topicObj\n";

  # read all keys
  $result .= "<table class=\"twikiTable\">\n";
  foreach my $key (sort $topicObj->getKeys()) {
    my $value = $topicObj->fastget($key);
    $result .= "<tr><th>$key</th>\n<td><verbatim>\n$value\n</verbatim></td></tr>\n";
  }
  $result .= "</table>\n";

  # read info
  my $topicInfo = $topicObj->fastget('info');
  $result .= "<p/>\n---++ Info = $topicInfo\n";
  $result .= "<table class=\"twikiTable\">\n";
  foreach my $key (sort $topicInfo->getKeys()) {
    my $value = $topicInfo->fastget($key);
    $result .= "<tr><th>$key</th><td>$value</td></tr>\n" if $value;
  }
  $result .= "</table>\n";

  # read form
  my $topicForm = $topicObj->fastget('form');
  if ($topicForm) {
    $result .= "<p/>\n---++ Form = $topicForm\n";
    $result .= "<table class=\"twikiTable\">\n";
    $topicForm = $topicObj->fastget($topicForm);
    foreach my $key (sort $topicForm->getKeys()) {
      my $value = $topicForm->fastget($key);
      $result .= "<tr><th>$key</th><td>$value</td>\n" if $value;
    }
    $result .= "</table>\n";
  }

  return $result."\n</noautolink>\n";
}

###############################################################################
sub expandVariables {
  my ($theFormat, %params) = @_;

  return '' unless $theFormat;
  
  foreach my $key (keys %params) {
    if($theFormat =~ s/\$$key/$params{$key}/g) {
      #print STDERR "DEBUG: expanding $key->$params{$key}\n";
    }
  }
  $theFormat =~ s/\$percnt/\%/go;
  $theFormat =~ s/\$dollar/\$/go;
  $theFormat =~ s/\$n/\n/go;
  $theFormat =~ s/\$t\b/\t/go;
  $theFormat =~ s/\$nop//g;
  $theFormat =~ s/\$flatten\((.*)\)/&flatten($1)/ges;
  $theFormat =~ s/\$encode\((.*)\)/&encode($1)/ges;

  return $theFormat;
}

###############################################################################
sub encode {
  my $text = shift;

  $text = "\n<noautolink>\n$text\n</noautolink>\n";
  $text = &TWiki::Func::expandCommonVariables($text);
  $text = &TWiki::Func::renderText($text);
  $text =~ s/[\n\r]+/ /go;
  $text =~ s/\n*<\/?noautolink>\n*//go;
  $text = &TWiki::entityEncode($text);
  $text =~ s/^\s*(.*?)\s*$/$1/gos;

  return $text;
}
###############################################################################
sub flatten {
  my $text = shift;

  $text =~ s/&lt;/</g;
  $text =~ s/&gt;/>/g;

  $text =~ s/\<[^\>]+\/?\>/XXX/g;
  $text =~ s/<\!\-\-.*?\-\->//gs;
  $text =~ s/\&[a-z]+;/ /g;
  $text =~ s/[ \t]+/ /gs;
  $text =~ s/%//gs;
  $text =~ s/_[^_]+_/ /gs;
  $text =~ s/\&[a-z]+;/ /g;
  $text =~ s/\&#[0-9]+;/ /g;
  $text =~ s/[\r\n\|]+/ /gm;
  $text =~ s/\[\[//go;
  $text =~ s/\]\]//go;
  $text =~ s/\]\[//go;
  $text = &TWiki::entityEncode($text);
  $text =~ s/(https?)/<nop>$1/go;
  $text =~ s/\b($wikiWordRegex)\b/<nop>$1/g;

  return $text;
}

###############################################################################
sub inlineError {
  return "<div class=\"twikiAlert\">$_[0]</div>";
}


###############################################################################
1;
