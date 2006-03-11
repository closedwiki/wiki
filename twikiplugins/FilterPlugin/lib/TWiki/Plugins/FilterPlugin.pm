# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2005-2006 Michael Daum <micha@nats.informatik.uni-hamburg.de>
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
package TWiki::Plugins::FilterPlugin;

###############################################################################
use vars qw(
        $currentWeb $currentTopic $user $VERSION $RELEASE
        $debug
    );

$VERSION = '$Rev$';
$RELEASE = '0.94';
$debug = 0; # toggle me

###############################################################################
sub writeDebug {
  &TWiki::Func::writeDebug("- FilterPlugin - " . $_[0]) if $debug;
  #print STDERR "DEBUG: FilterPlugin - $_[0]\n" if $debug;
}

###############################################################################
sub initPlugin {
  ($currentTopic, $currentWeb, $user) = @_;

  return 1;
}

###############################################################################
sub commonTagsHandler {
  $_[0] =~ s/\%FORMATLIST{(.*?)}%/&handleFormatList($1)/geo;
  $_[0] =~ s/%SUBST{(.*?)}%/&handleFilter($1, 1)/geo; 
  $_[0] =~ s/%EXTRACT{(.*?)}%/&handleFilter($1, 0)/geo; 
  while($_[0] =~ s/%STARTSUBST{(?!.*%STARTSUBST)(.*?)}%(.*?)%STOPSUBST%/&handleFilter($1, 1, $2)/ges) {
    # nop
  }
  while($_[0] =~ s/%STARTEXTRACT{(?!.*%STARTEXTRACT)(.*?)}%(.*?)%STOPEXTRACT%/&handleFilter($1, 0, $2)/ges) {
    # nop
  }
}

###############################################################################
# filter a topic or url thru a regular expression
# attributes
#    * pattern
#    * format
#    * hits
#    * topic
#    * expand
#
sub handleFilter {
  my ($theAttributes, $theMode, $theText) = @_;
  $theAttributes = "" if !$theAttributes;

  #writeDebug("called handleFilter");
  #writeDebug("handleFilter - theAttributes = $theAttributes");
  #writeDebug("handleFilter - theText = '$theText'") if $theText;

  # get parameters
  my $thePattern = &TWiki::Func::extractNameValuePair($theAttributes, "pattern") || '';
  my $theFormat = &TWiki::Func::extractNameValuePair($theAttributes, "format") || '';
  my $theMaxHits = &TWiki::Func::extractNameValuePair($theAttributes, "hits") || 0;
  my $theTopic = &TWiki::Func::extractNameValuePair($theAttributes, "topic") || $currentTopic;
  my $theWeb = $currentWeb if !$theWeb;
  if ($theTopic =~ /^(.*)\.(.*)$/) { # TODO : put normalizeWebTopicName() into the DakarContrib
    $theWeb = $1;
    $theTopic = $2;
  }
  my $theExpand = &TWiki::Func::extractNameValuePair($theAttributes, "expand") || 'on';

  # get the source text
  my $text = "";
  if ($theText) { # direct text
    $text = $theText;
  } else { # topic text
    $text = &TWiki::Func::readTopicText($theWeb, $theTopic);
    if ($text =~ /^No permission to read topic/) {
      return showError("$text");
    }
    if ($text =~ /%STARTINCLUDE%(.*)%STOPINCLUDE%/gs) {
      $text = $1;
      if ($theExpand eq 'on') {
	$text = &TWiki::Func::expandCommonVariables($text, $currentTopic, $currentWeb);
	$text = &TWiki::Func::renderText($text, $currentWeb);
      }
    }
  }

  #writeDebug("thePattern=$thePattern");
  #writeDebug("theFormat=$theFormat");
  #writeDebug("theMaxHits=$theMaxHits");
  writeDebug("source text=$text");

  my $result = '';
  if ($theMode == 0) {
    # extraction mode
    my $hits = $theMaxHits;
    while($text =~ /$thePattern/gms) {
      my $arg1 = $1 || '';
      my $arg2 = $2 || '';
      my $arg3 = $3 || '';
      my $arg4 = $4 || '';
      my $arg5 = $5 || '';
      my $arg6 = $6 || '';
      my $match = $theFormat;
      $match =~ s/\$1/$arg1/g;
      $match =~ s/\$2/$arg2/g;
      $match =~ s/\$3/$arg3/g;
      $match =~ s/\$4/$arg4/g;
      $match =~ s/\$5/$arg5/g;
      $match =~ s/\$6/$arg6/g;
      $result .= $match;
      $hits--;
      last if $theMaxHits && $hits <= 0;
    }
    $text = $result;
  } elsif ($theMode == 1) {
    # substitution mode
    my $hits = $theMaxHits;
    while($text =~ /$thePattern/gsi) {
      my $arg1 = $1 || '';
      my $arg2 = $2 || '';
      my $arg3 = $3 || '';
      my $arg4 = $4 || '';
      my $arg5 = $5 || '';
      my $arg6 = $6 || '';
      my $match = $theFormat;
      $match =~ s/\$1/$arg1/g;
      $match =~ s/\$2/$arg2/g;
      $match =~ s/\$3/$arg3/g;
      $match =~ s/\$4/$arg4/g;
      $match =~ s/\$5/$arg5/g;
      $match =~ s/\$6/$arg6/g;
      writeDebug("match=$match");
      $text =~ s/$thePattern/$match/gmsi;
      #writeDebug("($hits) text=$text");
      $hits--;
      last if $theMaxHits && $hits <= 0;
    }
    $result = $text;
  }
  &escapeParameter($result);
  $result = &TWiki::Func::expandCommonVariables($result, $currentTopic, $currentWeb);

  #writeDebug("result=$result");
  return $result;
}

###############################################################################
sub handleFormatList {
  my $args = shift;

  #writeDebug("handleFormatList($args)");

  my $theList = &TWiki::Func::extractNameValuePair($args) ||
    &TWiki::Func::extractNameValuePair($args, 'list') || '';
  my $thePattern = &TWiki::Func::extractNameValuePair($args, 'pattern') || '\s*(.*)\s*';
  my $theFormat = &TWiki::Func::extractNameValuePair($args, 'format') || '$1';
  my $theHeader = &TWiki::Func::extractNameValuePair($args, 'header') || '';
  my $theFooter = &TWiki::Func::extractNameValuePair($args, 'footer') || '';
  my $theSplit = &TWiki::Func::extractNameValuePair($args, 'split') || '[,\s]+';
  my $theSeparator = &TWiki::Func::extractNameValuePair($args, 'separator') || ', ';
  my $theLimit = &TWiki::Func::extractNameValuePair($args, 'limit') || -1;
  my $theSort = &TWiki::Func::extractNameValuePair($args, 'sort') || 'off';
  my $theUnique = &TWiki::Func::extractNameValuePair($args, 'unique') ||'';
  my $theExclude = &TWiki::Func::extractNameValuePair($args, 'exclude') || '';
  my $theReverse = &TWiki::Func::extractNameValuePair($args, 'reverse') || '';

  &escapeParameter($theList);
  $theList = &TWiki::Func::expandCommonVariables($theList, $currentTopic, $currentWeb);

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
  my $count = 0;
  foreach my $item (split /$theSplit/, $theList, $theLimit) {
    #writeDebug("found '$item'");
    next if $theExclude && $item =~ /($theExclude)/;
    next if $item =~ /^$/; # skip empty elements
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
    if ($theUnique eq 'on') {
      next if $seen{$item};
      $seen{$item} = 1;
    }
    next if $item eq '';
    $item =~ s/\$index/$count/g;
    push @result, $item;
    $count++;
  }
  return '' if $count == 0;

  if ($theSort ne 'off') {
    if ($theSort eq 'alpha' || $theSort eq 'on') {
      @result = sort {$a cmp $b} @result;
    } elsif ($theSort eq 'num') {
      @result = sort {$a <=> $b} @result;
    }
  }
  @result = reverse @result if $theReverse eq 'on';

  my $result = $theHeader.join($theSeparator, @result).$theFooter;
  $result =~ s/\$count/$count/g;
  &escapeParameter($result);
  $result = &TWiki::Func::expandCommonVariables($result, $currentTopic, $currentWeb);
  $result =~ s/\s+$//go; # SMELL what the hell: where do the linefeeds come from

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
sub showError {
  my ($errormessage) = @_;
  return "<font size=\"-1\" color=\"#FF0000\">$errormessage</font>" ;
}

1;
