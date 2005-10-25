###############################################################################
# TWiki WikiClone ($wikiversion has version info)
#
# Copyright (C) 2005 Michael Daum <micha@nats.informatik.uni-hamurg.de>
#
# Based on photonsearch
# Copyright (C) 2001 Esteban Manchado Velázquez, zoso@foton.es
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
package TWiki::Plugins::NatSkinPlugin::Search;

use strict;
use vars qw($isInitialized $debug $includeWeb $excludeWeb 
            $includeTopic $excludeTopic $renderTopicSummary);
use URI::Escape;
use TWiki::Plugins::NatSkinPlugin;
use TWiki::Plugins::NatSkinPlugin::Sandbox;

###############################################################################
sub writeDebug {
  &TWiki::Func::writeDebug("- NatSkinPlugin::Search - " . $_[0]) if $debug;
}

##############################################################################
sub doInit {
  return if $isInitialized;
  $isInitialized = 1;
  $debug = 0; # toggle me

  &TWiki::Plugins::NatSkinPlugin::doInit();
  writeDebug("done init()");
}

##############################################################################
sub natSearch {
  my ($query, $topic, $web) = @_;

  &doInit();

  writeDebug("called natSearch()");

  my $wikiUserName = &TWiki::Func::getWikiUserName();
  my $theSearchString = $query->param('search') || '';
  my $theWeb = $query->param('web') || '';
  my $theIgnoreCase = $query->param('ignorecase') || '';
  my $origSearch = $theSearchString;

  # get web preferences
  $includeWeb = &TWiki::Func::getPreferencesValue('NATSEARCHINCLUDEWEB', $theWeb) || '';
  $excludeWeb = &TWiki::Func::getPreferencesValue('NATSEARCHEXCLUDEWEB', $theWeb) || '';
  $includeTopic = &TWiki::Func::getPreferencesValue('NATSEARCHINCLUDETOPIC', $theWeb) || '';
  $excludeTopic = &TWiki::Func::getPreferencesValue('NATSEARCHEXCLUDETOPIC', $theWeb) || '';
  $renderTopicSummary = &TWiki::Func::getPreferencesValue('NATSEARCHTOPICSUMMARY', $theWeb) || '';
  $includeWeb =~ s/^\s*(.*)\s*$/$1/o;
  $excludeWeb =~ s/^\s*(.*)\s*$/$1/o;
  $includeTopic =~ s/^\s*(.*)\s*$/$1/o;
  $excludeTopic =~ s/^\s*(.*)\s*$/$1/o;
  $renderTopicSummary =~ s/^\s*(.*)\s*$/$1/o;

  writeDebug("search=$theSearchString");
  writeDebug("wikiUserName=$wikiUserName");
  writeDebug("theWeb=$theWeb");
  writeDebug("theIgnoreCase=$theIgnoreCase");
  writeDebug("includeWeb=$includeWeb");
  writeDebug("excludeWeb=$excludeWeb");
  writeDebug("includeTopic=$includeTopic");
  writeDebug("excludeTopic=$excludeTopic");
  
  # separate and process options
  my $options = "";
  if ($theSearchString =~ s/^(.*?)://) {
    $options = $1;
  }

  my $doIgnoreCase = ($options =~ /u/ || $theIgnoreCase) ? '' : 'i';
  writeDebug("options=$options");

  # construct the list of webs to search in
  my @webList;
  if ($options =~ /l/ || $theWeb eq $web) {
    @webList = ($theWeb) if $theWeb;
  } else {
    @webList = TWiki::Func::getPublicWebList();
    @webList = grep (/^$includeWeb$/, @webList) if $includeWeb;
    @webList = grep (!/^$excludeWeb$/, @webList) if $excludeWeb;
  }
  $theWeb ||= $web;
  writeDebug("webList=" . join(',', @webList));

  # redirect according to the look of the string
  # (1) the string starts with an uppercase letter: 
  #     (1.1) try a GO
  #     (1.2) fallback to a topic search when (1.1) fails
  #     (1.3) fallback to content search when (1.2) fails
  # (2) the string starts with a / 
  #     normal content search
  # (3) the string does not start with an upper case letter or /
  #     (3.1) try a topic search
  #     (3.2) fallback to content search
  my ($results, $nrHits);
  if ($theSearchString =~ /^[A-Z]/) { 
    if ($theSearchString =~ /(.*)\.(.*)/) {  # Special web.topic notation
      $theWeb = $1;
      $theSearchString = $2;
    }

    # (1.1) normal Go behaviour
    if (&TWiki::Func::topicExists($theWeb, $theSearchString)) {
      my $viewUrl = &TWiki::Func::getViewUrl($theWeb, $theSearchString);
      &TWiki::Func::redirectCgiQuery($query, $viewUrl);
      writeDebug("done");
      return;
    } 
    
    # (1.2) fallback to topic search
    else {
      ($results, $nrHits) = 
	natTopicSearch($theSearchString, \@webList, $doIgnoreCase, $wikiUserName);

      # (1.3) fallback to content search
      if ($nrHits == 0) { 
	($results, $nrHits) = 
	  natContentsSearch($theSearchString, \@webList, $doIgnoreCase, $wikiUserName);
      } 
    }
  } 
  
  # (2) content search
  elsif ($theSearchString =~ /^\/(.+)/) { # Normal search
    $theSearchString = $1; 
    ($results, $nrHits) = 
      natContentsSearch($theSearchString, \@webList, $doIgnoreCase, $wikiUserName);
  }
  
  # (3)
  else { 
  
    # (3.1) topic name search
    ($results, $nrHits) = 
      natTopicSearch($theSearchString, \@webList, $doIgnoreCase, $wikiUserName);

    # (3.2) fallback to content search
    if ($nrHits == 0) { 
      ($results, $nrHits) = 
	natContentsSearch($theSearchString, \@webList, $doIgnoreCase, $wikiUserName);
    }
  }
      
  # If there is only one result, redirect to that node
  if ($nrHits == 1) {
    my $resultWeb = (keys %$results)[0];
    my $resultTopic = $results->{$resultWeb}[0];
    my $viewUrl = &TWiki::Func::getViewUrl($resultWeb, $resultTopic);
    &TWiki::Func::redirectCgiQuery($query, $viewUrl);
    writeDebug("done");
    return;
  }

  # Else, print them
  &TWiki::Func::writeHeader($query);
  my $tmpl = &TWiki::Func::readTemplate('search');
  my ($tmplHead, $tmplSearch, $tmplTable, $tmplNumber, $tmplTail) = 
    split(/%SPLIT%/,$tmpl);

  $tmplHead = &TWiki::Func::expandCommonVariables($tmplHead, $topic);
  $tmplHead = &TWiki::Func::renderText($tmplHead);
  $tmplHead =~ s|</*nop/*>||goi;
  $tmplHead =~ s/%TOPIC%/$topic/go;
  $tmplHead =~ s/%SEARCHSTRING%/$origSearch/go;

  print $tmplHead;

  #$tmplSearch = &TWiki::Func::expandCommonVariables($tmplSearch, $topic);
  #$tmplNumber = &TWiki::Func::expandCommonVariables($tmplNumber, $topic);

  if ($nrHits) {
    _natPrintSearchResult($tmplTable, $results, $theSearchString);
  } else {
    print '<div class="natSearchMessage">Nothing found. Try again!</div>' . 
      "\n";
  }

  # print last part of full HTML page
  $tmplTail = &TWiki::Func::expandCommonVariables($tmplTail, $topic);
  $tmplTail = &TWiki::Func::renderText($tmplTail);
  $tmplTail =~ s|</*nop/*>||goi;   # remove <nop> tag
  print $tmplTail;

  writeDebug("done natSearch()");
}

##############################################################################
sub natTopicSearch
{
  my ($theSearchString, $theWebList, $doIgnoreCase, $theUser) = @_;

  my $nrHits = 0;
  my $results = {};

  if ($debug) {
    writeDebug("called natTopicSearch()");
    writeDebug("doIgnoreCase=$doIgnoreCase");
    writeDebug("theWebList=" . join(" ", @$theWebList));
  }

  if ($theSearchString eq '') {
    writeDebug("empty search string");
    return ($results, $nrHits);
  }

  my @searchTerms = _getSearchTerms($theSearchString);

  # collect the results for each web, put them in $results->{}
  my $dataDir = &TWiki::Func::getDataDir();
  foreach my $thisWebName (@$theWebList) {
    # get all topics
    my $webDir = &normalizeFileName("$dataDir/$thisWebName");
    opendir(DIR, $webDir) || die "can't opendir $webDir: $!";
    my @topics = 
      map {s/\.txt$//; $_} grep {/\.txt$/} readdir(DIR);
    @topics = grep(/$includeTopic/, @topics) if $includeTopic;
    @topics = grep(!/$excludeTopic/, @topics) if $excludeTopic;
    closedir DIR;

    # filter topics
    foreach my $searchTerm (@searchTerms) {
      my $pattern = $searchTerm;
      eval {
	if ($pattern =~ s/^-//) {
	  if ($doIgnoreCase) {
	    @topics = grep(!/$pattern/i, @topics);
	  } else {
	    @topics = grep(!/$pattern/, @topics);
	  }
	} else {
	  if ($doIgnoreCase) {
	    @topics = grep(/$pattern/i, @topics);
	  } else {
	    @topics = grep(/$pattern/, @topics);
	  }
	}
      };
      if ($@) {
	&TWiki::Func::writeWarning("natsearch: pattern=$pattern failed to compile");
	return ({}, 0);
      }
    }

    # filter out non-viewable topics
    @topics = 
      grep {&TWiki::Func::checkAccessPermission("view", $theUser, "", $_, $thisWebName);}
      @topics;


    if (@topics) {
      $nrHits += scalar @topics;
      $results->{$thisWebName} = [@topics] ;
      writeDebug("in $thisWebName: found topics " . join(", ", @topics));
    } else {
      writeDebug("nothing found in $thisWebName");
    }
  }

  writeDebug("done natTopicSearch()");
  return ($results, $nrHits);
}

##############################################################################
sub natContentsSearch {
  my ($theSearchString, $theWebList, $doIgnoreCase, $theUser) = @_;

  if ($debug) {
    writeDebug("called natContentsSearch()");
    writeDebug("doIgnoreCase=$doIgnoreCase");
    writeDebug("theWebList=" . join(" ", @$theWebList));
  }

  my $cmdTemplate = "/bin/egrep -l$doIgnoreCase %PATTERN|E% %FILES|F%";
  my $dataDir = &TWiki::Func::getDataDir();
  my $results = {};
  my $nrHits = 0;
  my @searchTerms = _getSearchTerms($theSearchString);

  if (!@searchTerms) {
    return ($results, $nrHits);
  }

  # Collect the results for each web, put them in $results->{}
  foreach my $thisWebName (@$theWebList) {

    writeDebug("searching in $thisWebName");

    # get all topics
    my $webDir = &normalizeFileName("$dataDir/$thisWebName");
    opendir(DIR, $webDir) || die "can't opendir $webDir: $!";
    my @bag = grep {/\.txt$/} readdir(DIR);
    @bag = grep(/$includeTopic/, @bag) if $includeTopic;
    @bag = grep(!/$excludeTopic/, @bag) if $excludeTopic;
    closedir DIR;
    chdir($webDir);

    # grep files in bag
    foreach my $searchTerm (@searchTerms) {
      next unless $searchTerm;
      writeDebug("before bag=@bag");

      # can't modify $searchTerm directly
      my $pattern = $searchTerm;

      writeDebug("pattern=$pattern");

      if ($pattern =~ s/^-//) {
	my @notfiles = "";
	eval {
	  my ($result, $code) = &readFromProcess($cmdTemplate,
	    PATTERN => $pattern, FILES => \@bag);
	  @notfiles = split(/\r?\n/, $result);
	};
	if ($@) {
	  &TWiki::Func::writeWarning("natsearch: pattern=$pattern files=@bag - $@");
	  return ({}, 0);
	}
	chomp(@notfiles);

	# substract notfiles from bag
	my @f = ();
	foreach my $k (@bag) {
	  push @f, $k unless grep { $k eq $_ } @notfiles;
	}
	@bag = @f;
      } else {
	eval {
	  my ($result, $code) = 
	    &readFromProcess($cmdTemplate, PATTERN => $pattern, FILES => \@bag); 
	  @bag = split(/\r?\n/, $result);
	  writeDebug("code=$code, result=$result");
	};
	if ($@) {
	  &TWiki::Func::writeWarning("natsearch: pattern=$pattern files=@bag - $@");
	  return ({}, 0);
	}
	chomp(@bag);
      }
    }
    writeDebug("after bag=@bag");

    # strip ".txt" extension
    @bag = map { s/\.txt$//; $_ } @bag;


    # filter out non-viewable topics
    @bag = 
      grep {&TWiki::Func::checkAccessPermission("view", $theUser, "", $_, $thisWebName);} @bag;

    if (@bag) {
      $nrHits += scalar @bag;
      $results->{$thisWebName} = [ @bag ] ;
    }
  }

  writeDebug("done natContentsSearch()");
  return ($results, $nrHits);
}

##############################################################################
sub _natPrintSearchResult
{
  my ($theTemplate, $theResults, $theSearchString) = @_;

  my $noSpamPadding =
    $TWiki::Plugins::NatSkinPlugin::isDakar?
      $TWiki::cfg{AntiSpam}{EmailPadding}:$TWiki::noSpamPadding;
      
  # print hits in all webs
  foreach my $thisWeb (sort keys %{$theResults}) {
    my ($beforeText, $repeatText, $afterText) = split(/%REPEAT%/, $theTemplate);

    # print web header
    $beforeText =~ s/%WEB%/$thisWeb/o;
    $beforeText = &TWiki::Func::expandCommonVariables($beforeText, $thisWeb);
    $afterText  = &TWiki::Func::expandCommonVariables($afterText, $thisWeb);
    $beforeText = &TWiki::Func::renderText($beforeText, $thisWeb);
    $beforeText =~ s|</*nop/*>||goi;   # remove <nop> tag
    print $beforeText;

    # print hits in all topics
    my $index = 0;
    foreach my $thisTopic (@{$theResults->{$thisWeb} }) {
      my $tempVal = $repeatText;

      # get topic information
      my ($meta, $text) = &TWiki::Func::readTopic($thisWeb, $thisTopic);
      my ($revDate, $revUser, $revNum) = &getRevisionInfoFromMeta($thisWeb, $thisTopic, $meta); 
      writeDebug("revDate=$revDate, revUser=$revUser, revNum=$revNum");
      $revUser = &TWiki::Func::userToWikiName($revUser);
      $revDate = &TWiki::Func::formatTime($revDate) 
	unless $TWiki::Plugins::NatSkinPlugin::isBeijing;

      # insert the topic information into the template
      $tempVal =~ s/%WEB%/$thisWeb/go;
      $tempVal =~ s/%TOPICNAME%/$thisTopic/go;
      $tempVal =~ s/%TIME%/$revDate/go;
      if ($revNum > 1) {
	$revNum = "r1.$revNum";
      } else {
	$revNum = '<span class="natSearchNewTopic">New</span>';
      } 
      $tempVal =~ s/%REVISION%/$revNum/go;
      $tempVal =~ s/%AUTHOR%/$revUser/go;

      # render twiki markup
      $tempVal = &TWiki::Func::expandCommonVariables($tempVal, $thisTopic);
      $tempVal = &TWiki::Func::renderText($tempVal);

      # remove mail trace
      $text =~ s/([A-Za-z0-9\.\+\-\_]+)\@([A-Za-z0-9\.\-]+\..+?)/$1$noSpamPadding$2/go;

      # render search hit
      if ($renderTopicSummary) {
	$text = '%INCLUDE{"'.$renderTopicSummary.'" THISTOPIC="'.$thisTopic.'" THISWEB="'.$thisWeb.'" warn="off"}%';
	$text = &TWiki::Func::expandCommonVariables($text, $thisTopic, $thisWeb);
      }
      my @searchTerms = _getSearchTerms($theSearchString);
      my $summary = _getTopicSummary($text, $thisTopic, $thisWeb, @searchTerms);
      
      $tempVal =~ s/%TEXTHEAD%/$summary/go;
      $tempVal =~ s|</*nop/*>||goi;   # remove <nop> tag

      # fiddle in even/odd CSS classes
      my $hitClass = ($index % 2)?'natSearchEvenHit':'natSearchOddHit';
      $index++;
      $tempVal =~ s/(class="natSearchHit)"/$1 $hitClass"/g;

      # print this hit
      print $tempVal;
    }

    $afterText = &TWiki::Func::renderText($afterText, $thisWeb);
    $afterText =~ s|</*nop/*>||goi;   # remove <nop> tag
    print $afterText;
  }
}

##############################################################################
sub _getTopicSummary
{
  my ($theText, $theTopic, $theWeb, @theKeywords) = @_;

  my $wikiToolName = &TWiki::Func::getWikiToolName() || '';
  my $htext = $theText;
  $htext =~ s/<\!\-\-.*?\-\->//gos;  # remove all HTML comments
  $htext =~ s/<\!\-\-.*$//os;        # remove cut HTML comment
  $htext =~ s/<[^>]*>//go;           # remove all HTML tags
  $htext =~ s/%WEB%/$theWeb/go;      # resolve web
  $htext =~ s/%TOPIC%/$theTopic/go;  # resolve topic
  $htext =~ s/%WIKITOOLNAME%/$wikiToolName/go; # resolve TWiki tool
  $htext =~ s/%META:.*?%//go;        # Remove meta data variables
  $htext =~ s/[\%\[\]\*\|=_]/ /go;   # remove Wiki formatting chars & defuse %VARS%
  $htext =~ s/\-\-\-+\+*/ /go;       # remove heading formatting
  $htext =~ s/\s+[\+\-]*/ /go;       # remove newlines and special chars

  # store first found word (some of them can be found in metadata instead of
  # in the text)
  my $firstfound = undef;
  my $errorFound = 0;
  foreach my $keyWord (@theKeywords) {
    eval {
      if ($htext =~ /$keyWord/i) {
	$firstfound = $keyWord;
      }
    };
    if ($@) {
      &TWiki::Func::writeWarning("natsearch: keyWord=$keyWord failed to compile");
      $errorFound = 1;
      last;
    }
    last if $firstfound;
  }
  return "" if $errorFound;

  # limit to 162 chars, according to the position of the first keyword ...
  if (defined $firstfound) {
    $htext =~ s/^.*?([a-zA-Z0-9]*.{0,81})($firstfound)(.{0,81}[a-zA-Z0-9]*).*?$/$1$2$3/gi;
  } else {
    $htext =~ s/(.{162})([a-zA-Z0-9]*)(.*?)$/$1$2/go;
  }
  $htext = substr($htext, 0, 300) . " ..."; # Limit string length

  # ... but hilight all of them
  foreach my $k (@theKeywords) {
    $htext =~ s:$k:<font color="#cc0000">$&</font>:gi;
  }

  # inline search renders text, 
  # so prevent linking of external and internal links:
  $htext =~ s/([\-\*\s])((http|ftp|gopher|news|file|https)\:)/$1<nop>$2/go;
  $htext =~ s/([\s\(])([A-Z]+[a-z0-9]*\.[A-Z]+[a-z]+[A-Z]+[a-zA-Z0-9]*)/$1<nop>$2/go;
  $htext =~ s/([\s\(])([A-Z]+[a-z]+[A-Z]+[a-zA-Z0-9]*)/$1<nop>$2/go;
  $htext =~ s/([\s\(])([A-Z]{3,})/$1<nop>$2/go;
  $htext =~ s/@([a-zA-Z0-9\-\_\.]+)/@<nop>$1/go;

  $htext = &TWiki::Func::renderText($htext, $theWeb);
  return $htext;
}

##############################################################################
sub _getSearchTerms {
  my $theSearchString = shift ;

  # Figure out search terms
  my @searchTerms = ();
  while($theSearchString =~ s/(-?)"([^"]*)"//) {
    push @searchTerms, $1 . $2;
  }
  # Escape unmatched quotes
  $theSearchString =~ s/"/\\"/;
  push @searchTerms, split(' ', $theSearchString);

  return @searchTerms;
}

##############################################################################
sub getRevisionInfoFromMeta {
  my ($thisWeb, $thisTopic, $meta) = @_;

  my ($revDate, $revUser, $revNum);

  if ($TWiki::Plugins::NatSkinPlugin::isDakar) {
    ($revDate, $revUser, $revNum ) = $meta->getRevisionInfo();
    $revUser = $revUser->webDotWikiName() if $revUser;
  } else {
    ($revDate, $revUser, $revNum) = 
      &TWiki::Store::getRevisionInfoFromMeta($thisWeb, $thisTopic, $meta); 
  }

  return ($revDate, $revUser, $revNum);
}


1;
