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
package TWiki::Plugins::FilterPlugin;

###############################################################################
use vars qw(
        $web $topic $user $VERSION $RELEASE
        $debug
    );

$VERSION = '$Rev$';
$RELEASE = '0.93';
$debug = 0; # toggle me

###############################################################################
sub writeDebug {
  #&TWiki::Func::writeDebug("- FilterPlugin - " . $_[0]) if $debug;
  print STDERR "DEBUG: FilterPlugin - $_[0]\n" if $debug;
}

###############################################################################
sub initPlugin {
  ($topic, $web, $user) = @_;

  return 1;
}

###############################################################################
sub commonTagsHandler {
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
sub handleFilter 
{
  my ($theAttributes, $theMode, $theText) = @_;
  $theAttributes = "" if !$theAttributes;

  writeDebug("called handleFilter");

  writeDebug("handleFilter - theAttributes = $theAttributes");
  writeDebug("handleFilter - theText = '$theText'") if $theText;

  # get parameters
  my $thePattern = &TWiki::Func::extractNameValuePair($theAttributes, "pattern") || '';
  my $theFormat = &TWiki::Func::extractNameValuePair($theAttributes, "format") || '';
  $theFormat =~ s/\\n/\n/g;
  my $theMaxHits = &TWiki::Func::extractNameValuePair($theAttributes, "hits") || 0;
  my $theTopic = &TWiki::Func::extractNameValuePair($theAttributes, "topic") || $topic;
  my $theWeb = $web if !$theWeb;
  if ($theTopic =~ /^(.*)\.(.*)$/) {
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
	$text = &TWiki::Func::expandCommonVariables($text, $topic, $web);
	$text = &TWiki::Func::renderText($text, $web);
      }
    }
  }

  writeDebug("thePattern=$thePattern");
  writeDebug("theFormat=$theFormat");
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
    while($text =~ /$thePattern/gmsi) {
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

  writeDebug("result=$result");
  return $result;
}


1;
