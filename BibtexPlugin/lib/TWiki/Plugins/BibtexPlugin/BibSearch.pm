# Module for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2003 Michael Daum <micha@nats.informatik.uni-hamburg.de>
# Copyright (C) 2006-2010 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root of
# this distribution. NOTE: Please extend that file, not this notice.
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

package TWiki::Plugins::BibtexPlugin::BibSearch;

use strict;
our $debug = 0;

###############################################################################
sub writeDebug {
  &TWiki::Func::writeDebug("bibsearch - " . $_[0]) if $debug;
}

sub writeDebugTimes {
  &TWiki::Func::writeDebugTimes("bibsearch - " . $_[0]) if $debug;
}

###############################################################################
sub bibsearch
{
  my $session = shift;

  $TWiki::Plugins::SESSION = $session;

  my $query = $session->{request};
  my $web   = $session->{webName};
  my $topic = $session->{topicName};

  my $thePathInfo = $query->path_info(); 
  my $theRemoteUser = $query->remote_user();
  my $theUrl = $query->url;

  &writeDebug("starting");

  ##
  # get params
  ##
  my $theTopic = $query->param('bibtopic');
  my $theMatch = $query->param("match") || "all";
  my $theReverse = $query->param("rev");
  my $theSort = join(" ", $query->param("sort"));
  my $theFormat = $query->param("format");
  my $theErrors = $query->param("errors");
  my $theBibfile = $query->param("file");
  my $theStyle = $query->param("bibstyle");
  my $theForm = $query->param("form");
  my $theAbstracts = $query->param("abstracts");
  my $theKeywords = $query->param("keywords");
  my $theTotal = $query->param("total");
  my $theDisplay = $query->param("display");
  my $theSelect = $query->param("select") || "";

  ##
  # map cgi parameters
  ##
  my $mixed = "off";
  my $style = $theStyle;
  if ($theFormat) {
    $mixed = "on" if $theFormat eq "mix";
    $style = "raw" if $theFormat eq "raw";
#    $style = "bibtool" if $theFormat eq "bibtool";
  }

  my @textFields = ("author", "year", "title", "key", "type", "phrase", "inside", "select");
  my @radioFields = ("match", "format", "sort", "rev", "abstracts");

  if (!$theSelect) {
    # build the selection string for handleBibtex()
    my $isFirst = 1;
    foreach my $attrName (@textFields) {
      my $valueString = $query->param($attrName);
      next if !$valueString;

      if ($isFirst) {
	$isFirst = 0;
      } else {
	$theSelect .= " and " if $theMatch eq 'all';
	$theSelect .= " or " if $theMatch eq 'any';
      }

      my $isFirstSpec = 1;
      foreach my $attrSpec (split(/\s/, $valueString)) {
	if ($attrSpec =~ /([<>=:!]*)(.*)/) {
	  my $compare = $1;
	  my $value = $2;
	  if (!$compare) {
	    if ($attrName eq "year") {
	      $compare = "=";
	    } else {
	      $compare = ":";
	    }
	  }
	  if ($isFirstSpec) {
	    $isFirstSpec = 0;
	  } else {
	    $theSelect .= " and " if $theMatch eq 'all';
	    $theSelect .= " or " if $theMatch eq 'any';
	  }

	  my $name;
	  if ($attrName =~ /(key|type)/) {
	    $name = '$' . $attrName;
	  } else {
	    $name = $attrName;
	  }
	  if ($attrName eq "phrase") {
	    $theSelect .= 
	      "((keywords $compare \'$value\') or " .
	      "(title $compare \'$value\') or " .
	      "(abstract $compare \'$value\') or " .
	      "(note $compare \'$value\') or " .
	      "(annote $compare \'$value\') or " .
	      "(\$key $compare \'$value\'))";
	  } elsif ($attrName eq "inside") {
	    $theSelect .=
	      "((journal $compare \'$value\') or " .
	      "(series $compare \'$value\') or " .
	      "(booktitle $compare \'$value\') or " .
	      "(school $compare \'$value\') or " .
	      "(institute $compare \'$value\'))";
	  } else {
	    $theSelect .= "$name $compare \'$value\' ";
	  }
	}
      }
    }
  }

  ##
  # get the view template
  ##
  my $skin = $query->param("skin") || &TWiki::Func::getPreferencesValue("SKIN");
  my ($meta, $text) = &TWiki::Func::readTopic($web, $topic);
  my $tmpl = &TWiki::Func::readTemplate("view", $skin);

  $tmpl = TWiki::Func::expandCommonVariables($tmpl, $topic, $web);
  if( $TWiki::Plugins::VERSION >= 1.1 ) { 
    # Dakar interface 
  } else { 
    # Cairo interface
    $tmpl = &TWiki::handleMetaTags($web, $topic, $tmpl, $meta, 1);
  }
    
  $tmpl = TWiki::Func::renderText($tmpl);
    
  $tmpl =~ s/%SEARCHSTRING%//go;
  $tmpl =~ s/%REVINFO%//go;
  $tmpl =~ s/%REVTITLE%(<nop>)?/bibsearch /go;
  $tmpl =~ s/%REVTITLE%(<nop>)?/bibsearch /go;
  $tmpl =~ s/%REVARG%//go;

  ##
  # call the plugin
  ##
  my $result = &TWiki::Plugins::BibtexPlugin::bibSearch($theTopic, 
    $theBibfile, $theSelect, $style, $theSort, $theReverse, $mixed, 
    $theErrors, 
    $theForm, $theAbstracts, $theKeywords, $theTotal, $theDisplay);

  ##
  # put the topic text into the view template
  ##
  $text =~ s/%BIBTEXRESULT%/$result/g;
  $text =~ s/%BIBTEX%/$result/g;
  $text =~ s/%BIBTEX{[^}]*}%/$result/g;
  $text =~ s/%STARTBIBTEX.*?%.*?%STOPBIBTEX%/$result/gs;

  $text = TWiki::Func::expandCommonVariables($text, $topic, $web);
  $text = TWiki::Func::renderText($text);

  if (0) { 
      # Cairo interface
      $text = &TWiki::handleCommonTags($text, $topic);
      $text = &TWiki::getRenderedVersion($text);
  }
  $tmpl =~ s/%TEXT%/$text/go;

  ##
  # repalce query strings
  ##
  if ($theForm) {
    foreach my $fieldName (@textFields) {
      my $valueString = $query->param($fieldName);
      next if !$valueString;
      $tmpl =~ s/(<input.*name="$fieldName".*value=")[^"]*/$1$valueString/;
    }
    foreach my $fieldName (@radioFields) {
      my $valueString = $query->param($fieldName);
      next if !$valueString;
      $tmpl =~ s/(<input.*name="$fieldName".*)\s*checked="checked"\s/$1/g;
      $tmpl =~ s/(<input.*name="$fieldName".*value="$valueString")/$1 checked="checked" /;
    }
  }

  # remove edit and revisions tags:
  $tmpl =~ s/%EDITTOPIC%//g;
  $tmpl =~ s/%REVISIONS%/ -- /g;

  ##
  # finaly, print out
  ##
  $session->writeCompletePage( $tmpl, 'view' );
  &writeDebug("done");
}

1;
