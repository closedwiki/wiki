# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2005-2006 MichaelDaum@WikiRing.com
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

package TWiki::Plugins::DBCachePlugin::Core;

use strict;
use vars qw( 
  $TranslationToken $debug %webDB %webDBIsModified $wikiWordRegex $webNameRegex
  $defaultWebNameRegex $linkProtocolPattern
);

use TWiki::Contrib::DBCacheContrib;
use TWiki::Contrib::DBCacheContrib::Search;
use TWiki::Plugins::DBCachePlugin::WebDB;

$TranslationToken = "\0"; # from TWiki.pm
$debug = 0; # toggle me

###############################################################################
sub writeDebug {
  &TWiki::Func::writeDebug('- DBCachePlugin - '.$_[0]) if $debug;
}

###############################################################################
sub afterSaveHandler {

  # force reload
  my $theDB = getDB($TWiki::Plugins::DBCachePlugin::currentWeb);
  #writeDebug("touching webdb for $TWiki::Plugins::DBCachePlugin::currentWeb");
  $theDB->touch();
  if ($TWiki::Plugins::DBCachePlugin::currentWeb ne $_[2]) {
    $theDB = getDB($_[2]); 
    #writeDebug("touching webdb for $_[2]");
    $theDB->touch();
  }
}

###############################################################################
sub handleDBQUERY {
  my ($session, $params, $theTopic, $theWeb) = @_;

  #writeDebug("called handleDBQUERY(" . $params->stringify() . ")");

  # params
  my $theSearch = $params->{_DEFAULT} || $params->{search};
  my $theTopics = $params->{topics} || $params->{topic};
  
  return '' if $theTopics && $theTopics eq 'none';

  my $theFormat = $params->{format} || '$topic';
  my $theHeader = $params->{header} || '';
  my $theFooter = $params->{footer} || '';
  my $theInclude = $params->{include};
  my $theExclude = $params->{exclude};
  my $theSort = $params->{sort} || $params->{order} || 'name';
  my $theReverse = $params->{reverse} || 'off';
  my $theSep = $params->{separator} || $params->{sep} || '$n';
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
    \@topicNames, $theSort, $theReverse, $theInclude, $theExclude);
  #print STDERR "DEBUG: got topicNames=@$topicNames\n";

  return _inlineError($msg) if $msg;

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
      $format = _expandVariables($format, topic=>$topicName, web=>$topicWeb, index=>$index, count=>$count);
      $text .= $format;
      last if $index == $theLimit;
    }
  }

  $theHeader = _expandVariables($theHeader.$theSep, count=>$count, web=>$theWeb) if $theHeader;
  $theFooter = _expandVariables($theSep.$theFooter, count=>$count, web=>$theWeb) if $theFooter;

  $text = &TWiki::Func::expandCommonVariables("$theHeader$text$theFooter", 
    $TWiki::Plugins::DBCachePlugin::currentTopic, $theWeb);
  return $text;
}

###############################################################################
sub handleDBCALL {
  my ($session, $params, $theTopic, $theWeb) = @_;

  # remember args for the key before mangling the params
  my $args = $params->stringify();

  #writeDebug("called handleDBCALL($args)");

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
      return _inlineError("ERROR: DBCALL can't find topic <nop>$thisTopic in <nop>$thisWeb");
    } else {
      return '';
    }
  }

  # check access rights
  my $wikiUserName = TWiki::Func::getWikiUserName();
  unless (TWiki::Func::checkAccessPermission('VIEW', $wikiUserName, undef, $thisTopic, $thisWeb)) {
    if ($warn) {
      return _inlineError("ERROR: DBCALL access to '$thisWeb.$thisTopic' denied");
    } 
    return '';
  }


  # get section
  my $sectionText = $topicObj->fastget("_section$section") if $topicObj;
  if (!$sectionText) {
    if($warn) {
      return _inlineError("ERROR: DBCALL can't find section '$section' in topic '$thisWeb.$thisTopic'");
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
      return _inlineError("ERROR: DBCALL reached max recursion at '$thisWeb.$thisTopic'");
    }
    return '';
  }
  $session->{dbcalls}->{$key} = 1;

  # substitute variables
  $sectionText =~ s/%INCLUDINGWEB%/$theWeb/g;
  $sectionText =~ s/%INCLUDINGTOPIC%/$theTopic/g;
  foreach my $key (keys %$params) {
    $sectionText =~ s/%$key%/$params->{$key}/g;
  }

  # expand
  $sectionText = TWiki::Func::expandCommonVariables($sectionText, $thisTopic, $thisWeb);

  # from TWiki::_INCLUDE
  if($thisWeb ne $theWeb) {
    my $removed = {};

    # Must handle explicit [[]] before noautolink
    # '[[TopicName]]' to '[[Web.TopicName][TopicName]]'
    $sectionText =~ s/\[\[([^\]]+)\]\]/&_fixIncludeLink($thisWeb, $1)/geo;
    # '[[TopicName][...]]' to '[[Web.TopicName][...]]'
    $sectionText =~ s/\[\[([^\]]+)\]\[([^\]]+)\]\]/&_fixIncludeLink($thisWeb, $1, $2)/geo;

    $sectionText = $session->{renderer}->takeOutBlocks($sectionText, 'noautolink', $removed);

    # 'TopicName' to 'Web.TopicName'
    $sectionText =~ s/(^|[\s(])($webNameRegex\.$wikiWordRegex)/$1$TranslationToken$2/go;
    $sectionText =~ s/(^|[\s(])($wikiWordRegex)/$1\[\[$thisWeb\.$2\]\[$2\]\]/go;
    $sectionText =~ s/(^|[\s(])$TranslationToken/$1/go;

    $session->{renderer}->putBackBlocks( \$sectionText, $removed, 'noautolink');
  }


  # cleanup
  delete $session->{dbcalls}->{$key};

  return $sectionText;
  #return "<verbatim>\n$sectionText\n</verbatim>";
}

###############################################################################
sub handleDBSTATS {
  my ($session, $params, $theTopic, $theWeb) = @_;

  #writeDebug("called handleDBSTATS");

  # get args
  my $theSearch = $params->{_DEFAULT} || $params->{search} || '';
  my $thisWeb = $params->{web} || $theWeb;
  my $thePattern = $params->{pattern} || '(\w+)';
  my $theHeader = $params->{header} || '';
  my $theFormat = $params->{format} || '   * $key: $count';
  my $theFooter = $params->{footer} || '';
  my $theSep = $params->{separator} || $params->{sep} || '$n';
  my $theFields = $params->{fields} || $params->{field} || 'text';
  my $theSort = $params->{sort} || $params->{order} || 'alpha';
  my $theReverse = $params->{reverse} || 'off';
  my $theLimit = $params->{limit} || 0;
  my $theHideNull = $params->{hidenull} || 'off';
  $theLimit =~ s/[^\d]//go;

  #writeDebug("theSearch=$theSearch");
  #writeDebug("thisWeb=$thisWeb");
  #writeDebug("thePattern=$thePattern");
  #writeDebug("theHeader=$theHeader");
  #writeDebug("theFormat=$theFormat");
  #writeDebug("theFooter=$theFooter");
  #writeDebug("theSep=$theSep");
  #writeDebug("theFields=$theFields");

  # build seach object
  my $search = new TWiki::Contrib::DBCacheContrib::Search($theSearch);
  unless ($search) {
    return "ERROR: can't parse query $theSearch";
  }

  # compute statistics
  my %statistics = ();
  my $theDB = getDB($thisWeb);
  my @topicNames = $theDB->getKeys();
  foreach my $topicName (@topicNames) { # loop over all topics
    my $topicObj = $theDB->fastget($topicName);
    next unless $search->matches($topicObj); # that match the query
    my $createdate = $topicObj->fastget('createdate');

    #writeDebug("found topic $topicName");
    
    foreach my $field (split(/,\s/, $theFields)) { # loop over all fields
      my $fieldValue = $topicObj->fastget($field);
      unless ($fieldValue) {
	my $topicForm = $topicObj->fastget('form');
	#writeDebug("found form $topicForm");
	if ($topicForm) {
	  $topicForm = $topicObj->fastget($topicForm);
	  $fieldValue = $topicForm->fastget($field);
	}
      }
      next unless $fieldValue; # unless present
      #writeDebug("reading field $field");

      while ($fieldValue =~ /$thePattern/g) { # loop over all occurrences of the pattern
	my $key = $1;
	my $record = $statistics{$key};
	if ($record) {
	  $record->{count}++;
	  $record->{from} = $createdate if $record->{from} > $createdate;
	  $record->{to} = $createdate if $record->{to} < $createdate;
	} else {
	  my %record = (
	    count=>1,
	    from=>$createdate,
	    to=>$createdate
	  );
	  $statistics{$key} = \%record;
	}
      }
    }
  }
  my $min = 99999999;
  my $max = 0;
  my $sum = 0;
  foreach my $key (keys %statistics) {
    my $record = $statistics{$key};
    $min = $record->{count} if $min > $record->{count};
    $max = $record->{count} if $max < $record->{count};
    $sum += $record->{count};
  }
  my $numkeys = scalar(keys %statistics);
  my $mean = 0;
  $mean = (($sum+0.0) / $numkeys) if $numkeys;
  return '' if $theHideNull eq 'on' && $numkeys == 0;

  # format output
  my $result = '';
  my @sortedKeys;
  if ($theSort =~ /^created(from)?$/) {
    @sortedKeys = sort {
      $statistics{$a}->{from} <=> $statistics{$b}->{from}
    } keys %statistics
  } elsif ($theSort eq 'createdto') {
    @sortedKeys = sort {
      $statistics{$a}->{to} <=> $statistics{$b}->{to}
    } keys %statistics
  } else {
    @sortedKeys = sort keys %statistics;
  }
  @sortedKeys = reverse @sortedKeys if $theReverse eq 'on';
  my $index = 0;
  foreach my $key (@sortedKeys) {
    $index++;
    my $record = $statistics{$key};
    my $text;
    $text = $theSep if $result;
    $text .= $theFormat;
    $result .= &_expandVariables($text, 
      'web'=>$theWeb,
      'key'=>$key,
      'count'=>$record->{count}, 
      'index'=>$index,
      'min'=>$min,
      'max'=>$max,
      'sum'=>$sum,
      'mean'=>$mean,
      'keys'=>$numkeys,
    );
    last if $theLimit && $index == $theLimit;
  }
  $theHeader = &_expandVariables($theHeader);
  $theFooter = &_expandVariables($theFooter);
  $result = &TWiki::Func::expandCommonVariables($theHeader.$result.$theFooter, $theTopic, $theWeb);

  return $result;
}

###############################################################################
sub handleDBDUMP {
  my ($session, $params, $theTopic, $theWeb) = @_;

  #writeDebug("called handleDBDUMP");

  my $thisTopic = $params->{_DEFAULT} || $theTopic;
  my $thisWeb = $params->{web} || $theWeb;
  ($thisWeb, $thisTopic) = TWiki::Func::normalizeWebTopicName($thisWeb, $thisTopic);
  my $theDB = getDB($thisWeb);

  my $topicObj = $theDB->fastget($thisTopic) || '';
  unless ($topicObj) {
    return _inlineError("$thisWeb.$thisTopic not found");
  }
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
sub getDB {
  my $theWeb = shift;

  #writeDebug("called getDB($theWeb)");

  # We do not need to reload the cache if we run on mod_perl or speedy_cgi or
  # whatever perl accelerator that keeps our global variables and 
  # the database wasn't modified!
  my $isModified = 0;
  unless (defined $webDB{$theWeb}) {
    # never loaded
    $isModified = 1;
    #writeDebug("fresh reload");
  } else {
    unless (defined $webDBIsModified{$theWeb}) {
      # never checked
      $webDBIsModified{$theWeb} = $webDB{$theWeb}->isModified();
      if ($debug) {
	if ($webDBIsModified{$theWeb}) {
	  #writeDebug("checking modified webdb for $theWeb");
	} else {
	  #writeDebug("don't need to load webdb for $theWeb");
	}
      }
    }
    $isModified = $webDBIsModified{$theWeb};
  }

  if ($isModified) {
    my $impl = TWiki::Func::getPreferencesValue('WEBDB', $theWeb) 
      || 'TWiki::Plugins::DBCachePlugin::WebDB';
    $impl =~ s/^\s*(.*?)\s*$/$1/o;
    #writeDebug("loading new webdb for $theWeb");
    eval "use $impl;";
    $webDB{$theWeb} = new $impl($theWeb);
    $webDB{$theWeb}->load();
    $webDBIsModified{$theWeb} = 0;
  }

  return $webDB{$theWeb};
}

###############################################################################
# from TWiki::_fixIncludeLink
sub _fixIncludeLink {
  my( $theWeb, $theLink, $theLabel ) = @_;

  # [[...][...]] link
  if($theLink =~ /^($webNameRegex\.|$defaultWebNameRegex\.|$linkProtocolPattern\:|\/)/o) {
    if ( $theLabel ) {
      return "[[$theLink][$theLabel]]";
    } else {
      return "[[$theLink]]";
    }
  } elsif ( $theLabel ) {
    return "[[$theWeb.$theLink][$theLabel]]";
  } else {
    return "[[$theWeb.$theLink][$theLink]]";
  }
}

###############################################################################
sub _expandVariables {
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
  $theFormat =~ s/\$flatten\((.*?)\)/&_flatten($1)/ges;
  $theFormat =~ s/\$encode\((.*)\)/&_encode($1)/ges;
  $theFormat =~ s/\$trunc\((.*?),\s*(\d+)\)/substr($1,0,$2)/ges;

  return $theFormat;
}

###############################################################################
sub _encode {
  my $text = shift;

  $text = "\n<noautolink>\n$text\n</noautolink>\n";
  $text = &TWiki::Func::expandCommonVariables($text);
  $text = &TWiki::Func::renderText($text);
  $text =~ s/<nop>//go;
  $text =~ s/[\n\r]+/ /go;
  $text =~ s/\n*<\/?noautolink>\n*//go;
  $text =~ s/[[\x01-\x09\x0b\x0c\x0e-\x1f"%&'*<=>@[_\|]/'&#'.ord($&).';'/ge;
  $text =~ s/^\s*(.*?)\s*$/$1/gos;

  return $text;
}

###############################################################################
sub _flatten {
  my $text = shift;

  $text =~ s/&lt;/</g;
  $text =~ s/&gt;/>/g;

  $text =~ s/\<[^\>]+\/?\>//g;
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
  $text =~ s/[[\x01-\x09\x0b\x0c\x0e-\x1f"%&'*<=>@[_\|]/'&#'.ord($&).';'/ge;
  $text =~ s/(https?)/<nop>$1/go;
  $text =~ s/\b($wikiWordRegex)\b/<nop>$1/g;

  return $text;
}

###############################################################################
sub _inlineError {
  return "<div class=\"twikiAlert\">$_[0]</div>";
}


###############################################################################
1;
