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
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(initDB dbQuery getFormField);

use strict;
use vars qw( $VERSION $RELEASE $debug $pluginName %webDBs);

use TWiki::Contrib::DBCacheContrib;
use TWiki::Contrib::DBCacheContrib::Search;
use TWiki::Plugins::DBCachePlugin::WebDB;

$VERSION = '$Rev$';
$RELEASE = '0.90';
$pluginName = 'DBCachePlugin';
$debug = 0; # toggle me

###############################################################################
sub writeDebug {
  #&TWiki::Func::writeDebug('- '.$pluginName.' - '.$_[0]) if $debug;
  print STDERR "DEBUG: - $pluginName - $_[0]\n" if $debug;
}

###############################################################################
sub initPlugin {
  my ($topic, $web, $user, $installWeb) = @_;

  %webDBs = ();

  TWiki::Func::registerTagHandler('DBQUERY', \&_DBQUERY);
  TWiki::Func::registerTagHandler('DBCALL', \&_DBCALL);

  writeDebug("initialized");
  return 1;
}

###############################################################################
sub _DBQUERY {
  my ($session, $params, $theTopic, $theWeb) = @_;
  
  writeDebug("called _DBQUERY");

  # params
  my $theSearch = $params->{_DEFAULT} || $params->{search};
  my $theTopics = $params->{topics} || $params->{topic};
  
  return &inlineError("ERROR: DBQUERY needs either a \"search\" or a \"topic\" argument ") 
    if !$theSearch && !$theTopics;
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

  my $theDB = &initDB($theWeb);

  #print STDERR "DEBUG: _DBQUERY(" . $params->stringify() . ")\n";

  # get topics
  my @topicNames;
  if ($theTopics) {
    @topicNames = split(/, /, $theTopics);
  } else {
    @topicNames = $theDB->getKeys();
  }
  @topicNames = grep(/$theInclude/, @topicNames) if $theInclude;
  @topicNames = grep(!/$theExclude/, @topicNames) if $theExclude;

  # normalize 
  $theSkip =~ s/[^-\d]//go;
  $theSkip = 0 if $theSkip eq '';
  $theSkip = 0 if $theSkip < 0;
  $theFormat = '' if $theFormat eq 'none';
  $theSep = '' if $theSep eq 'none';
  $theLimit =~ s/[^\d]//go;
  $theLimit = scalar(@topicNames) if $theLimit eq '';
  $theLimit += $theSkip;

  my ($topicNames, $hits, $msg) = &dbQuery($theDB, $theSearch, 
    \@topicNames, $theOrder, $theReverse);
#  print STDERR "DEBUG: topicNames=@$topicNames\n";

  return $msg if $msg;


  my $count = scalar(@$topicNames);
#  print STDERR "DEBUG: count=$count\n";
  return '' if ($count <= $theSkip) && $theHideNull eq 'on';

  # format
  my $text = '';
  if ($theFormat && $theLimit) {
    my $index = 0;
    my $isFirst = 1;
    foreach my $topicName (@$topicNames) {
      $index++;
      next if $index <= $theSkip;
      my $root = $hits->{$topicName};
      my $format = '';
      $format = $theSep unless $isFirst;
      $isFirst = 0;
      $format .= $theFormat;
      $format =~ s/\$formfield\((.*?)\)/getFormField($theDB, $topicName, $1)/geo;
      $format =~ s/\$expand\((.*?)\)/expandPath($theDB, $root, $1)/geo;
      $format =~ s/\$formatTime\((.*?)(?:,\s*'([^']*?)')?\)/TWiki::Func::formatTime(expandPath($theDB, $root, $1), $2)/geo; # single quoted
      #$format =~ s/\$dbcall\((.*?)\)/dbCall($1)/ge; ## TODO
      $format = expandVariables($format, topic=>$topicName, web=>$theWeb, index=>$index, count=>$count);
      $text .= $format;
      last if $index == $theLimit;
    }
  }

  $theHeader = expandVariables($theHeader.$theSep, count=>$count, web=>$theWeb) if $theHeader;
  $theFooter = expandVariables($theSep.$theFooter, count=>$count, web=>$theWeb) if $theFooter;

  $text = &TWiki::Func::expandCommonVariables("$theHeader$text$theFooter");
  #print STDERR "DEBUG: text='$text'\n";
  return $text;
}

###############################################################################
sub _DBCALL {
  my ($session, $params, $theTopic, $theWeb) = @_;

  writeDebug("called _DBCALL");

  # remember args for the key before mangling the params
  my $args = $params->stringify();

  #print STDERR "DEBUG: called DBCALL{$args}\n";

  my $path = $params->remove('_DEFAULT') || '';
  my $section = $params->remove('section') || 'default';
  my $warn = $params->remove('warn') || 'on';
  $warn = ($warn eq 'on')?1:0;

  my ($thisWeb, $thisTopic) = &TWiki::Func::normalizeWebTopicName($theWeb, $path);
  
  # check access rights
  my $wikiUserName = TWiki::Func::getWikiUserName();
  unless (TWiki::Func::checkAccessPermission('VIEW', $wikiUserName, undef, $thisTopic, $thisWeb)) {
    if ($warn) {
      return inlineError("ERROR: DBCALL access to '$thisWeb.$thisTopic' denied");
    } 
    return '';
  }

  # init database
  my $theDB = &initDB($thisWeb);

  # get section
  my $topicObj = $theDB->fastget($thisTopic);
  if (!$topicObj) {
    if ($warn) {
      return inlineError("ERROR: DBCALL can't find topic <nop>$thisWeb.$thisTopic");
    } else {
      return '';
    }
  }
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
  $sectionText = TWiki::Func::expandCommonVariables($sectionText);

  # cleanup
  delete $session->{dbcalls}->{$key};

  return $sectionText;
  #return '<verbatim>'.$sectionText.'</verbatim>';
}

###############################################################################
sub initDB {
  my ($theWeb) = @_;

  return undef unless $theWeb;

  writeDebug("called initDB($theWeb)");

  unless ($webDBs{$theWeb}) {
    my $impl = TWiki::Func::getPreferencesValue('WEBDB', $theWeb) 
      || 'TWiki::Plugins::DBCachePlugin::WebDB';
    $impl =~ s/^\s*(.*?)\s*$/$1/o;
    $webDBs{$theWeb} = new $impl($theWeb);
    $webDBs{$theWeb}->load();
    writeDebug("loaded $webDBs{$theWeb}");
  }

  return $webDBs{$theWeb};
}

###############################################################################
sub dbQuery {
  my ($theDB, $theSearch, $theTopics, $theOrder, $theReverse) = @_;

# TODO return empty result on an emtpy topics list

  $theOrder ||= '';
  $theReverse ||= '';
  $theSearch ||= '';
  $theTopics ||= '';

  writeDebug("called dbQuery($theDB, $theSearch, $theTopics, $theOrder, $theReverse) called");
#  print STDERR "DEBUG: theTopics=" . join(',', @$theTopics) . "\n" if $theTopics;

  my @topicNames = $theTopics?@$theTopics:$theDB->getKeys();
  
  # parse & fetch
  my %hits;
  if ($theSearch) {
    my $search = new TWiki::Contrib::DBCacheContrib::Search($theSearch);
    unless ($search) {
      return (undef, undef, &inlineError("ERROR: can't parse query $theSearch"));
    }
    foreach my $topicName (@topicNames) {
      my $topicObj = $theDB->fastget($topicName);
      if ($search->matches($topicObj)) {
	$hits{$topicName} = $topicObj;
#	print STDERR "DEBUG: adding hit for $topicName\n";
      }
    }
  } else {
    foreach my $topicName (@topicNames) {
      my $topicObj = $theDB->fastget($topicName);
      $hits{$topicName} = $topicObj if $topicObj;
#      print STDERR "DEBUG: adding hit for $topicName\n";
    }
  }

  # sort
  @topicNames = keys %hits;
  if (@topicNames > 1) {
    if ($theOrder eq 'name') {
      @topicNames = sort {$a cmp $b} @topicNames;
    } elsif ($theOrder =~ /^created/) {
      @topicNames = sort {
	expandPath($theDB, $hits{$a}, 'createdate') <=> expandPath($theDB, $hits{$b}, 'createdate')
      } @topicNames;
    } else {
      @topicNames = sort {
	expandPath($theDB, $hits{$a}, $theOrder) cmp expandPath($theDB, $hits{$b}, $theOrder)
      } @topicNames;
    }
    @topicNames = reverse @topicNames if $theReverse eq 'on';
  }

  return (\@topicNames, \%hits, undef);
}

###############################################################################
sub expandPath {
  my ($theDB, $theRoot, $thePath) = @_;

  return '' if !$thePath || !$theRoot;
  $thePath =~ s/^\.//o;
  $thePath =~ s/\[([^\]]+)\]/$1/o;

  #print STDERR "DEBUG: expandPath($theRoot, $thePath)\n";
  if ($thePath =~ /^(.*?) and (.*)$/) {
    my $first = $1;
    my $tail = $2;
    my $result1 = expandPath($theDB, $theRoot, $first);
    return '' unless defined $result1 && $result1 ne '';
    my $result2 = expandPath($theDB, $theRoot, $tail);
    return '' unless defined $result2 && $result2 ne '';
    return $result1.$result2;
  }
  if ($thePath =~ /^'([^']*)'$/) {
    return $1;
  }
  if ($thePath =~ /^(.*?) or (.*)$/) {
    my $first = $1;
    my $tail = $2;
    my $result = expandPath($theDB, $theRoot, $first);
    return $result if (defined $result && $result ne '');
    return expandPath($theDB, $theRoot, $tail);
  }

  if ($thePath =~ m/^(\w+)(.*)$/o) {
    my $first = $1;
    my $tail = $2;
    my $root = $theRoot->fastget($first);
    unless ($root) {
      # try form
      # TODO: try form FIRST
      my $form = $theRoot->fastget('form');
      if ($form) {
	$form = $theRoot->fastget($form);
	$root = $form->fastget($first) if $form;
      }
    }
    return expandPath($theDB, $root, $tail) if ref($root);
    if ($root) {
      my $field = TWiki::urlDecode($root);
      #print STDERR "DEBUG: result=$field\n";
      return $field;
    }
  }

  if ($thePath =~ /^@([^\.]+)(.*)$/) {
    my $first = $1;
    my $tail = $2;
    my $result = expandPath($theDB, $theRoot, $first);
    my $root = ref($result)?$result:$theDB->fastget($result); 
    return expandPath($theDB, $root, $tail)
  }

  #print STDERR "DEBUG: result is empty\n";
  return '';
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
sub getFormField {
  my ($theDB, $theTopic, $theFormField) = @_;

  my $topicObj = $theDB->fastget($theTopic);
  return '' unless $topicObj;
  
  my $form = $topicObj->fastget('form');
  return '' unless $form;

  $form = $topicObj->fastget($form);
  my $formfield = $form->fastget($theFormField) || '';
  return TWiki::urlDecode($formfield);
}

###############################################################################
sub inlineError {
  return '<span class="twikiAlert">' . $_[0] . '</span>' ;
}


###############################################################################
1;
