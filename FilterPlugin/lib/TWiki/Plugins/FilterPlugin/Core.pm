# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2005-2007 Michael Daum http://wikiring.de
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

package TWiki::Plugins::FilterPlugin::Core;
use strict;

use vars qw($currentTopic $currentWeb $mixedAlphaNum);

sub DEBUG { 0; } # toggle me

###############################################################################
sub init {
  ($currentWeb, $currentTopic) = @_;

  $mixedAlphaNum = TWiki::Func::getRegularExpression('mixedAlphaNum');
}

###############################################################################
sub writeDebug {
  print STDERR "- FilterPlugin - $_[0]\n" if DEBUG;
}


###############################################################################
sub handleFilterArea {
  my ($theAttributes, $theMode, $theText) = @_;

  $theAttributes ||= '';
  #writeDebug("called handleFilterArea($theAttributes)");

  my %params = TWiki::Func::extractParameters($theAttributes);
  return handleFilter(\%params, $theMode, $theText);
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
  my ($params, $theMode, $theText) = @_;

  #writeDebug("called handleFilter");
  #writeDebug("theMode = '$theMode'");

  # get parameters
  my $thePattern = $params->{pattern} || '';
  my $theFormat = $params->{format} || '';
  my $theHeader = $params->{header} || '';
  my $theFooter = $params->{footer} || '';
  my $theLimit = $params->{limit} || $params->{hits} || 100000; 
  my $theSkip = $params->{skip} || 0;
  my $theTopic = $params->{_DEFAULT} || $params->{topic} || $currentTopic;
  my $theWeb = $currentWeb;
  if ($theTopic =~ /^(.*)\.(.*?)$/) { # TODO : put normalizeWebTopicName() into the DakarContrib
    $theWeb = $1;
    $theTopic = $2;
  }
  my $theExpand = $params->{expand} || 'on';
  my $theSeparator = $params->{separator} || '';
  my $theExclude = $params->{exclude} || '';
  my $theSort = $params->{sort} || 'off';
  my $theReverse = $params->{reverse} || '';

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
  #writeDebug("text = '$text'");

  my $result = '';
  my $hits = $theLimit;
  my $skip = $theSkip;
  if ($theMode == 0) {
    # extraction mode
    my @result = ();
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
      next if $theExclude && $match =~ /^($theExclude)$/;
      next if $skip-- > 0;
      push @result,$match;
      $hits--;
      last if $theLimit > 0 && $hits <= 0;
    }
    if ($theSort ne 'off') {
      if ($theSort eq 'alpha' || $theSort eq 'on') {
	@result = sort {uc($a) cmp uc($b)} @result;
      } elsif ($theSort eq 'num') {
	@result = sort {$a <=> $b} @result;
      }
    }
    @result = reverse @result if $theReverse eq 'on';
    $result = join($theSeparator, @result);
  } elsif ($theMode == 1) {
    # substitution mode
    $result = $text;
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
      next if $theExclude && $match =~ /^($theExclude)$/;
      next if $skip-- > 0;
      #writeDebug("match=$match");
      $result =~ s/$thePattern/$match/gmsi;
      #writeDebug("($hits) result=$result");
      $hits--;
      last if $theLimit > 0 && $hits <= 0;
    }
  }
  $result = $theHeader.$result.$theFooter;
  $result = &TWiki::Func::expandCommonVariables($result, $currentTopic, $currentWeb)
    if expandVariables($result);

  #writeDebug("result=$result");
  return $result;
}

###############################################################################
sub handleSubst {
  my ($session, $params, $theTopic, $theWeb) = @_;
  return handleFilter($params, 1);
}

###############################################################################
sub handleExtract {
  my ($session, $params, $theTopic, $theWeb) = @_;
  return handleFilter($params, 0);
}

###############################################################################
sub handleMakeIndex {
  my ($session, $params, $theTopic, $theWeb) = @_;

  writeDebug("### called handleMakeIndex(".$params->stringify.")");
  my $theList = $params->{_DEFAULT} || $params->{list} || '';
  my $theCols = $params->{cols} || 3;
  my $theFormat = $params->{format} || '$item';
  my $theSort = $params->{sort} || 'on';
  my $theSplit = $params->{split} || ',';
  my $theUnique = $params->{unique} || '';
  my $theExclude = $params->{exclude} || '';
  my $theReverse = $params->{reverse} || '';
  my $thePattern = $params->{pattern} || '';
  my $theHeader = $params->{header} || '';
  my $theFooter = $params->{footer} || '';

  # sanitize params
  $theSort = ($theSort eq 'on')?1:0;
  $theUnique = ($theUnique eq 'on')?1:0;

  my $maxCols = $theCols;
  $maxCols =~ s/[^\d]//go;
  $maxCols = 3 if $maxCols eq '';
  $maxCols = 1 if $maxCols < 1;

  # compute the list
  $theList = &TWiki::Func::expandCommonVariables($theList, $theTopic, $theWeb)
    if expandVariables($theList);

  writeDebug("theList=$theList");

  # create the item descriptors for each list item
  my @theList = ();
  my %seen = ();
  foreach my $item (split(/$theSplit/, $theList)) {
    next if $theExclude && $item =~ /^($theExclude)$/;

    $item =~ s/^\s+//go;
    $item =~ s/\s+$//go;
    next unless $item;

    if ($theUnique) {
      next if $seen{$item};
      $seen{$item} = 1;
    }

    my $itemFormat = $theFormat;
    if ($thePattern && $item =~ m/$thePattern/) {
      my $arg1 = $1 || '';
      my $arg2 = $2 || '';
      my $arg3 = $3 || '';
      my $arg4 = $4 || '';
      my $arg5 = $5 || '';
      my $arg6 = $6 || '';
      $item = $arg1 if $arg1;
      $itemFormat =~ s/\$1/$arg1/g;
      $itemFormat =~ s/\$2/$arg2/g;
      $itemFormat =~ s/\$3/$arg3/g;
      $itemFormat =~ s/\$4/$arg4/g;
      $itemFormat =~ s/\$5/$arg5/g;
      $itemFormat =~ s/\$6/$arg6/g;
    }
    my %descriptor = (
      item=>$item,
      format=>$itemFormat,
    );
    push @theList, \%descriptor;
  }

  my $listSize = scalar(@theList);
  return '' unless $listSize;

  # sort it
  @theList = sort {$a->{item} cmp $b->{item}} @theList if $theSort;
  @theList = reverse @theList if $theReverse eq 'on';

  my $result = "<div class='fltMakeIndexWrapper'><table>\n<tr>\n";

  # count number of different first letters
  my $nrGroups = 0;
  my $groupLetter = '';
  foreach my $descriptor (@theList) {
    my $item = $$descriptor{item};
    my $firstLetter = substr($item, 0, 1);
    if ($groupLetter ne $firstLetter) {
      $nrGroups++;
      $groupLetter = $firstLetter;
    }
  }
  $groupLetter = ''; # reset

  # - group letters count 2 rows 
  # - a col should at least contain a single group letter and one additional row 
  my $colSize = int(($listSize + $nrGroups*2 + 0.5) / $maxCols) + 3;
  my $listIndex = 0;
  my $insideList = 0;
  my $itemIndex = 0;

  writeDebug("maxCols=$maxCols, colSize=$colSize, listSize=$listSize");

  foreach my $colIndex (1..$maxCols) {
    $result .= "  <td valign='top'>\n";

    writeDebug("new col");
    my $rowIndex = 1;
    while (1) {
      my $descriptor = $theList[$listIndex];
      my $format = $$descriptor{format};
      my $item = $$descriptor{item};
      writeDebug("listIndex=$listIndex, itemIndex=$itemIndex, colIndex=$colIndex, rowIndex=$rowIndex, item=$item, format=$format");

      # construct group letter
      my $firstLetter = substr($item, 0,1);
      if ($groupLetter ne $firstLetter || $rowIndex == 1) {
        $itemIndex += 2;
        last if $itemIndex % $colSize < 2 && $colIndex < $maxCols; # prevent schusterjunge

        if ($firstLetter eq $groupLetter && $rowIndex == 1) {
          $firstLetter .= ' <span>(cont.)</span>';
        } else {
          $groupLetter = $firstLetter;
        }

        if ($insideList) {
          $result .= "</ul>\n";
          $insideList = 0;
        }
        $result .= "  <h3>$firstLetter</h3>\n";
      }

      # construct line
      my $text = "  <li>$format</li>\n";
      expandVariables($text,
        index=>$listIndex+1,
        count=>$listSize,
        col=>$colIndex,
        row=>$rowIndex,
        item=>$item,
      );

      unless ($insideList) {
        $insideList = 1;
        $result .= "  <ul>\n";
      }

      # add to result
      $result .= $text;

      # keep track if indexes
      $listIndex++;
      $itemIndex++;
      $rowIndex++;
      last unless $itemIndex % $colSize && $listIndex < $listSize;
    }
    if ($insideList) {
      $result .= "  </ul>\n";
      $insideList = 0;
    }
    $result .= "</td>\n";
    last unless $listIndex < $listSize;
  }
  $result .= "</tr>\n</table></div>";

  expandVariables($theHeader, count=>$listSize);
  expandVariables($theFooter, count=>$listSize);
  #writeDebug("result=$result");

  return $theHeader.$result.$theFooter;
}

###############################################################################
sub handleFormatList {
  my ($session, $params, $theTopic, $theWeb) = @_;
  
  #writeDebug("handleFormatList()");

  my $theList = $params->{_DEFAULT} || $params->{list} || '';
  my $thePattern = $params->{pattern} || '\s*(.*)\s*';
  my $theFormat = $params->{format} || '$1';
  my $theHeader = $params->{header} || '';
  my $theFooter = $params->{footer} || '';
  my $theSplit = $params->{split} || '[,\s]+';
  my $theSeparator = $params->{separator} || ', ';
  my $theLimit = $params->{limit} || -1; 
  my $theSkip = $params->{skip} || 0; 
  my $theSort = $params->{sort} || 'off';
  my $theUnique = $params->{unique} || '';
  my $theExclude = $params->{exclude} || '';
  my $theReverse = $params->{reverse} || '';

  $theList = &TWiki::Func::expandCommonVariables($theList, $theTopic, $theWeb)
    if expandVariables($theList);

  #writeDebug("theList='$theList'");
  #writeDebug("thePattern='$thePattern'");
  #writeDebug("theFormat='$theFormat'");
  #writeDebug("theSplit='$theSplit'");
  #writeDebug("theSeparator='$theSeparator'");
  #writeDebug("theLimit='$theLimit'");
  #writeDebug("theSkip='$theSkip'");
  #writeDebug("theSort='$theSort'");
  #writeDebug("theUnique='$theUnique'");
  #writeDebug("theExclude='$theExclude'");

  my %seen = ();
  my @result;
  my $count = 0;
  my $skip = $theSkip;
  foreach my $item (split(/$theSplit/, $theList)) {
    #writeDebug("found '$item'");
    next if $theExclude && $item =~ /^($theExclude)$/;
    next if $item =~ /^$/; # skip empty elements
    my $arg1 = '';
    my $arg2 = '';
    my $arg3 = '';
    my $arg4 = '';
    my $arg5 = '';
    my $arg6 = '';
    if ($item =~ m/$thePattern/) {
      $arg1 = $1 || '';
      $arg2 = $2 || '';
      $arg3 = $3 || '';
      $arg4 = $4 || '';
      $arg5 = $5 || '';
      $arg6 = $6 || '';
    } else {
      next;
    }
    my $line = $theFormat;
    #writeDebug("arg1=$arg1") if $arg1;
    #writeDebug("arg2=$arg2") if $arg2;
    #writeDebug("arg3=$arg3") if $arg3;
    #writeDebug("arg4=$arg4") if $arg4;
    #writeDebug("arg5=$arg5") if $arg5;
    #writeDebug("arg6=$arg6") if $arg6;
    $line =~ s/\$1/$arg1/g;
    $line =~ s/\$2/$arg2/g;
    $line =~ s/\$3/$arg3/g;
    $line =~ s/\$4/$arg4/g;
    $line =~ s/\$5/$arg5/g;
    $line =~ s/\$6/$arg6/g;
    #writeDebug("after susbst '$line'");
    if ($theUnique eq 'on') {
      next if $seen{$line};
      $seen{$line} = 1;
    }
    next if $line eq '';
    $line =~ s/\$index/$count+1/ge;
    if ($skip-- <= 0) {
      push @result, $line;
      $count++;
      last if $theLimit - $count == 0;
    }
  }
  #writeDebug("count=$count");
  return '' if $count == 0;

  if ($theSort ne 'off') {
    if ($theSort eq 'alpha' || $theSort eq 'on') {
      @result = sort {uc($a) cmp uc($b)} @result;
    } elsif ($theSort eq 'num') {
      @result = sort {$a <=> $b} @result;
    }
  }
  @result = reverse @result if $theReverse eq 'on';

  my $result = $theHeader.join($theSeparator, @result).$theFooter;
  $result =~ s/\$count/$count/g;
  $result = &TWiki::Func::expandCommonVariables($result, $theTopic, $theWeb)
    if expandVariables($result);

  $result =~ s/\s+$//go; # SMELL what the hell: where do the linefeeds come from

  #writeDebug("result=$result");

  return $result;
}

###############################################################################
sub expandVariables {
  my ($text, %params) = @_;

  return 0 unless $text;

  my $found = 0;

  foreach my $key (keys %params) {
    $found = 1 if $text =~ s/\$$key\b/$params{$key}/g;
  }

  $found = 1 if $text =~ s/\$percnt/\%/go;
  $found = 1 if $text =~ s/\$nop//go;
  $found = 1 if $text =~ s/\$n([^$mixedAlphaNum]|$)/\n$1/go;
  $found = 1 if $text =~ s/\$dollar/\$/go;

  $_[0] = $text if $found;

  return $found;
}

###############################################################################
sub showError {
  my ($errormessage) = @_;
  return "<font size=\"-1\" color=\"#FF0000\">$errormessage</font>" ;
}

1;
