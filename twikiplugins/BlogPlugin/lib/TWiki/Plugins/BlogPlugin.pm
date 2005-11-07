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
package TWiki::Plugins::BlogPlugin;

###############################################################################
use vars qw(
        $VERSION $RELEASE $debug @seconds
	%prevTopicCache %nextTopicCache %db %MON2NUM
    );

$VERSION = '$Rev$';
$RELEASE = '0.03';

use Time::Local;
use TWiki::Contrib::DBCacheContrib;
use TWiki::Contrib::DBCacheContrib::Search;
use TWiki::Plugins::BlogPlugin::WebDB;

%MON2NUM = (
  Jan => 0,
  Feb => 1,
  Mar => 2,
  Apr => 3,
  May => 4,
  Jun => 5,
  Jul => 6,
  Aug => 7,
  Sep => 8,
  Oct => 9,
  Nov => 10,
  Dec => 11
);

@seconds = (
  ['year',   60 * 60 * 24 * 365],
  ['month',  60 * 60 * 24 * 30],
  ['week',   60 * 60 * 24 * 7],
  ['day',    60 * 60 * 24],
  ['hour',   60 * 60],
  ['minute', 60],
  ['second', 1]
);


###############################################################################
sub writeDebug {
  &TWiki::Func::writeDebug('- BlogPlugin - ' . $_[0]) if $debug;
}

###############################################################################
sub initPlugin {

  $debug = 0; # toggle me

  %prevTopicCache = ();
  %nextTopicCache = ();
  %db = ();

  TWiki::Func::registerTagHandler('NEXTDOC', \&_NEXTDOC);
  TWiki::Func::registerTagHandler('PREVDOC', \&_PREVDOC);
  TWiki::Func::registerTagHandler('RECENTCOMMENTS', \&_RECENTCOMMENTS);
  TWiki::Func::registerTagHandler('COUNTCOMMENTS', \&_COUNTCOMMENTS);
  TWiki::Func::registerTagHandler('RELATEDENTRIES', \&_RELATEDENTRIES);
  TWiki::Func::registerTagHandler('TIMESINCE', \&_TIMESINCE);
  TWiki::Func::registerTagHandler('CITEBLOG', \&_CITEBLOG);

  TWiki::Func::registerTagHandler('DBTEST', \&_DBTEST); # for debugging
  TWiki::Func::registerTagHandler('DBQUERY', \&_DBQUERY);

  return 1;
}

###############################################################################
sub initDB {
  my $theWeb = shift;

  return unless $theWeb;

  unless ($db{$theWeb}) {
#    print STDERR "DEBUG: init DB for $theWeb\n";
    $db{$theWeb} = new TWiki::Plugins::BlogPlugin::WebDB($theWeb);
    $db{$theWeb}->load();
  }
}

###############################################################################
sub _CITEBLOG {
  my ($session, $params, $theTopic, $theWeb) = @_;

  $theTopic = $params->{_DEFAULT} || $theTopic;
  ($theWeb, $theTopic) = &TWiki::Func::normalizeWebTopicName($theWeb, $theTopic);

  &initDB($theWeb);

  my $text = "[[$theWeb.$theTopic][$theTopic]]";

  my $topicObj = $db{$theWeb}->fastget($theTopic);
  return $text unless $topicObj;
  
  my $form = $topicObj->fastget('form');
  return $text unless $form;
  $form = $topicObj->fastget($form);
  return $text unless $form;
  my $displayText = 
    $form->fastget('Headline') || 
    $form->fastget('TopicDescription') ||
    $form->fastget('Name') ||
    $theTopic;
  my $createDate = TWiki::Func::formatTime($topicObj->fastget('createdate'), '$day $mon $year');
  return "[[$theWeb.$theTopic][$displayText ($createDate)]]";
}

###############################################################################
sub _DBQUERY {
  my ($session, $params, $theTopic, $theWeb) = @_;
  

  # params
  my $theFormat = $params->{format} || '$topic';
  my $theSearch = $params->{_DEFAULT};
  my $theInclude = $params->{include};
  my $theExclude = $params->{exclude};
  my $theOrder = $params->{order} || 'name';
  my $theReverse = $params->{reverse} || 'off';
  my $theSep = $params->{separator} || '$n';
  my $theHeader = $params->{header} || '';
  my $theFooter = $params->{footer} || '';
  my $theLimit = $params->{limit} || '';
  my $theSkip = $params->{skip} || '';
  my $theHideNull = $params->{hidenull} || 'off';
  $theTopics = $params->{topics} || $params->{topic};
  $theWeb = $params->{web} || $theWeb;

  return '' if $theTopics && $theTopics eq 'none';

  &initDB($theWeb);

  #print STDERR "DEBUG: _DBQUERY(" . $params->stringify() . ")\n";

  # get topics
  my @topicNames;
  if ($theTopics) {
    @topicNames = split(/, /, $theTopics);
  } else {
    @topicNames = $db{$theWeb}->getKeys();
  }
  @topicNames = grep(/$theInclude/, @topicNames) if $theInclude;
  @topicNames = grep(!/$theExclude/, @topicNames) if $theExclude;

  # normalize 
  $theSkip =~ s/[^\d]//go;
  $theSkip = 0 if $theSkip =~ /^$/o;
  $theFormat = '' if $theFormat eq 'none';
  $theSep = '' if $theSep eq 'none';
  $theLimit =~ s/[^\d]//go;
  $theLimit = scalar(@topicNames) if $theLimit eq '';

  my ($topicNames, $hits, $msg) = &dbQuery($theSearch, $theWeb, 
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
    foreach my $topicName (@$topicNames) {
      $index++;
      next if $index <= $theSkip;
      my $root = $hits->{$topicName};
      my $format = '';
      $format = $theSep if ($index > 1);
      $format .= $theFormat;
      $format =~ s/\$formfield\((.*?)\)/getFormField($theWeb, $topicName, $1)/geo;
      $format =~ s/\$expand\((.*?)\)/expandPath($theWeb, $root, $1)/geo;
      $format =~ s/\$formatTime\((.*?)(?:,\s*'([^']*?)')?\)/TWiki::Func::formatTime(expandPath($theWeb, $root, $1), $2)/geo; # single quoted
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
sub flatten {
  my $text = shift;

  $text =~ s/[\n\r]+/ /gos;
  return $text;
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
sub expandPath {
  my ($theWeb, $theRoot, $thePath) = @_;

  return '' if !$thePath || !$theRoot;
  $thePath =~ s/^\.//o;
  $thePath =~ s/\[([^\]]+)\]/$1/o;

  #print STDERR "DEBUG: expandPath($theWeb, $theRoot, $thePath)\n";
  if ($thePath =~ /^(.*?) or (.*)$/) {
    my $first = $1;
    my $tail = $2;
    my $result = expandPath($theWeb, $theRoot, $first);
    #print STDERR "DEBUG: result=$result\n";
    return $result if (defined $result && $result ne '');
    return expandPath($theWeb, $theRoot, $tail);
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
    return expandPath($theWeb, $root, $tail) if ref($root);
    if ($root) {
      my $field = TWiki::urlDecode($root);
      #print STDERR "DEBUG: result=$field\n";
      return $field;
    }
  }
  if ($thePath =~ /^@([^\.]+)(.*)$/) {
    my $first = $1;
    my $tail = $2;
    my $result = expandPath($theWeb, $theRoot, $first);
    my $root = ref($result)?$result:$db{$theWeb}->fastget($result); 
    return expandPath($theWeb, $root, $tail)
  }

  #print STDERR "DEBUG: result is empty\n";
  return '';
}


###############################################################################
sub _DBTEST {
  my ($session, $params, $theTopic, $theWeb) = @_;

  &initDB($theWeb);
  my $result;

  my $size = $db{$theWeb}->size();
  $result .= "   * size=$size\n";
  foreach my $key1 ('BlogEntry0') {
  
    my $value1 = $db{$theWeb}->fastget($key1) || '';
    $result .= "   * <nobr> $key1 = $value1</nobr>\n";

    foreach my $key2 (sort $value1->getKeys()) {
      next if $key2 eq 'text';
      my $value2 = $value1->fastget($key2);
      $result .= "      * <nobr> $key2 = $value2</nobr>\n" if $value2;
    }
    my $topicForm = $value1->fastget('form');
    if ($topicForm) {
      $result .= "   * $topicForm:\n";
      $topicForm = $value1->fastget($topicForm);
      foreach my $key2 (sort $topicForm->getKeys()) {
        my $value2 = $topicForm->fastget($key2);
        $result .= "      * <nobr> $key2 = $value2</nobr>\n" if $value2;
      }
    }
    my $topicInfo = $value1->fastget('info');
    $result .= "   * info: $topicInfo\n";
    foreach my $key2 (sort $topicInfo->getKeys()) {
      my $value2 = $topicInfo->fastget($key2);
      $result .= "      * <nobr> $key2 = $value2</nobr>\n" if $value2;
    }
  }
  return $result;

}

###############################################################################
sub getPrevNextTopic {
  my ($theWeb, $theTopic, $theWhere, $theOrder) = @_;

  #print STDERR "DEBUG: getPrevNextTopic($theWeb, $theTopic, $theWhere) called\n";
  my $key = $theWeb.'.'.$theTopic.':'.$theWhere.':'.$theOrder;
  my $prevTopic = $prevTopicCache{$key};
  my $nextTopic = $nextTopicCache{$key};

  if ($prevTopic && $nextTopic) {
    #writeDebug("found in cache: prevTopic=$prevTopic, nextTopic=$nextTopic");
    return ($prevTopic, $nextTopic);
  }
  &initDB($theWeb);

  my ($resultList) = &dbQuery($theWhere, $theWeb, undef, $theOrder);
  my $state = 0;
  foreach my $t (@$resultList) {
    if ($state == 1) {
      $state = 2;
      $nextTopic = $t;
      last;
    }
    $state = 1 if $t eq $theTopic;
    $prevTopic = $t if $state == 0;
    #writeDebug("t=$t, state=$state");
  }
  $prevTopic = '_notfound' if !$prevTopic || $state == 0;
  $nextTopic = '_notfound' if !$nextTopic || !$state == 2;
  $prevTopicCache{$key} = $prevTopic;
  $nextTopicCache{$key} = $nextTopic;
  #writeDebug("prevTopic=$prevTopic, nextTopic=$nextTopic");

  return ($prevTopic, $nextTopic);
}

###############################################################################
sub _PREVDOC {
  my ($session, $params, $theTopic, $theWeb) = @_;

  writeDebug("called _PREVDOC($theTopic)");

  $theTopic = $params->{_DEFAULT} || $theTopic;
  my $theFormat = $params->{format} || '$topic';
  my $theWhere = $params->{where};
  my $theOrder = $params->{order} || 'created';
  $theWeb = $params->{web} || $theWeb;

  my ($thisWeb, $thisTopic) = &TWiki::Func::normalizeWebTopicName($theWeb, $theTopic);

  #writeDebug('theFormat='.$theFormat);
  #writeDebug('theWhere='. $theWhere) if $theWhere;
  
  my ($prevTopic, $nextTopic) = &getPrevNextTopic($thisWeb, $thisTopic, $theWhere, $theOrder);
  if ($prevTopic ne '_notfound') {
    return &expandVariables($theFormat, topic=>$prevTopic, web=>$thisWeb);
  }
  return '';
}

###############################################################################
sub _NEXTDOC {
  my ($session, $params, $theTopic, $theWeb) = @_;

  #writeDebug("called _NEXTDOC($theTopic)");
  
  $theTopic = $params->{_DEFAULT} || $theTopic;
  my $theFormat = $params->{format} || '$topic';
  my $theWhere = $params->{where};
  my $theOrder = $params->{order} || 'created';
  $theWeb = $params->{web} || $theWeb;

  my ($thisWeb, $thisTopic) = &TWiki::Func::normalizeWebTopicName($theWeb, $theTopic);

  #writeDebug('theFormat='.$theFormat);
  #writeDebug('theWhere='. $theWhere) if $theWhere;

  my ($prevTopic, $nextTopic) = &getPrevNextTopic($thisWeb, $thisTopic, $theWhere, $theOrder);
  if ($nextTopic ne '_notfound') {
    return &expandVariables($theFormat, topic=>$nextTopic, web=>$thisWeb);
    return $theFormat;
  }
  return '';
}

###############################################################################
sub _RECENTCOMMENTS {
  my ($session, $params, $theTopic, $theWeb) = @_;

  #print STDERR "DEBUG: _RECENTCOMMENTS(" . $params->stringify() . ") called\n";

  my $theFormat = $params->{_DEFAULT} || $params->{format};
  my $theSeparator = $params->{separator} || '$n';
  my $theLimit = $params->{limit} || -1;
  my $theAge = $params->{age} || 0; # 5184000 are ca 2 months TODO compute TIMESINCE reversely
  my $theHeader = $params->{header} || '';
  my $theFooter = $params->{footer} || '';
  $theAge =~ s/[^\d]+//go;
  $theWeb = $params->{web} || $theWeb;
  
  &initDB($theWeb);

  my %blogComments;
  my %baseRefs;
  foreach my $topicName ($db{$theWeb}->getKeys()) {

    # get blog comment
    my $topicObj = $db{$theWeb}->fastget($topicName); 
    my $topicForm = $topicObj->fastget('form');
    next unless $topicForm;
    $topicForm = $topicObj->fastget($topicForm);
    my $topicType = $topicForm->fastget('TopicType');
    next unless $topicType;
    next unless $topicType =~ /BlogComment/o;

    # check if blog comment is too old
    my $topicCreateDate = $topicObj->fastget('createdate');
    if ($theAge) {
      my $now = time();
      my $diff = $now - $topicCreateDate;
      if ($diff > $theAge) {
	#print STDERR "DEBUG: $topicName exipred, diff=$diff\n";
	next;
      }
    }

    # check if referer is enabled
    my $baseRefName = $topicForm->fastget('BaseRef');
    next unless $baseRefName;
    my $baseRefObj = $db{$theWeb}->fastget($baseRefName);
    next unless $baseRefObj;
    my $baseRefForm = $baseRefObj->fastget('form');
    next unless $baseRefForm;
    $baseRefForm = $baseRefObj->fastget($baseRefForm);
    my $state = $baseRefForm->fastget('State');
    next unless $state;
    next unless $state eq 'enabled';

    # found
    $blogComments{$topicName}{obj} = $topicObj;
    $blogComments{$topicName}{createdate} = $topicCreateDate;
    $blogComments{$topicName}{author} = $topicForm->fastget('Name');
    $baseRefs{$baseRefName}{obj} = $baseRefObj;
    $baseRefs{$baseRefName}{createdate} = $baseRefObj->fastget('createdate');
    $baseRefs{$baseRefName}{count}++;
    $baseRefs{$baseRefName}{headline} = $baseRefForm->fastget('Headline');
    push @{$baseRefs{$baseRefName}{comments}},$topicName;

    #print STDERR "DEBUG: found comment $topicName on $baseRefName\n";
    #print STDERR "DEBUG: blogComment createdate=$blogComments{$topicName}{createdate}\n";
    #print STDERR "DEBUG: blogComment author=$blogComments{$topicName}{author}\n";
    #print STDERR "DEBUG: baseRef createdate=$baseRefs{$baseRefName}{createdate}\n";
    #print STDERR "DEBUG: baseRef count=$baseRefs{$baseRefName}{count}\n";
    #print STDERR "DEBUG: baseRef headline=$baseRefs{$baseRefName}{headline}\n";
    $theLimit--;
    last if $theLimit == 0; # zero limit is unlimited
  }

  # sort
  my @baseRefs = sort {
      $baseRefs{$b}{createdate} <=> $baseRefs{$a}{createdate}
    } keys %baseRefs;
  foreach my $baseRefName (@baseRefs) {
    @{$baseRefs{$baseRefName}{comments}} = sort {
      $blogComments{$b}{createdate} <=> $blogComments{$b}{'createdate'}
    } @{$baseRefs{$baseRefName}{comments}};
  }

  # render result
  my $result;
  my %seen = ();
  foreach my $baseRefName (@baseRefs) { # newest postings first
    next if $seen{$baseRefName};
    $seen{$baseRefName} = 1;

    my $text = $theSeparator if $result;
    $text .= $theFormat;

    # get variables
    my $headline = $baseRefs{$baseRefName}{headline};
    my $commenter = '';
    my $date = '';

    # get latest comment date
    my $latestComment = $baseRefs{$baseRefName}{comments}[0];
    $date = $blogComments{$latestComment}{createdate};
    
    # get commenter
    my @commenter;
    my %seenAuthor;
    foreach my $blogCommentName (@{$baseRefs{$baseRefName}{comments}}) {
      my $author = $blogComments{$blogCommentName}{author};
      next if $seenAuthor{$author};
      $seenAuthor{$author} = 1;
      $commenter .= ', ' if $commenter;
      $commenter .= "[[$baseRefName#$blogCommentName][$author]]";
    }
    $commenter = '<noautolink>'.$commenter.'</noautolink>';

    # render this
    $text = expandVariables($text, 
      topic=>$baseRefName,
      web=>$theWeb,
      count=>$baseRefs{$baseRefName}{count}>1?$baseRefs{$baseRefName}{count}:'',
      headline=>$headline,
      commenter=>$commenter,
      date=>$date
    );
      
    $result .= $text;
  }
  if ($result) {
    $result = expandVariables($theHeader.$result.$theFooter);
    return $result;
  } else {
    return '';
  }
}

###############################################################################
# recursion
sub countBlogRefs {
  my ($theWeb, $theBlogRef) = @_;

  writeDebug("called countBlogRefs($theWeb, $theBlogRef)");
  my $nrTopics = 0;
  if ($theBlogRef) {
    my $queryString = 
      'TopicType=~\'\bBlogComment\b\' AND BlogRef=\''.$theBlogRef.'\'';
    my ($blogRefs) = &dbQuery($queryString, $theWeb);

    foreach my $blogRef (@$blogRefs) {
      ($theWeb, $theBlogRef) = &TWiki::Func::normalizeWebTopicName($theWeb, $blogRef);
      $nrTopics += 1 + &countBlogRefs($theWeb, $theBlogRef);
    }
  }

  writeDebug("result is $nrTopics");
  return $nrTopics;
}

###############################################################################
sub _COUNTCOMMENTS {
  my ($session, $params, $theTopic, $theWeb) = @_;

  #writeDebug("called _COUNTCOMMENTS()");

  $theBlogRef = $params->{_DEFAULT};
  $theFormat = $params->{format} || '$count';
  $theSingle = $params->{single} || $theFormat;
  $theHideNull = $params->{hidenull} || 'off';
  $theNullString = $params->{null} || '0';
  $theOffset = $params->{offset} || 0;
  $theWeb = $params->{web} || $theWeb;

  ($theWeb, $theBlogRef) = &TWiki::Func::normalizeWebTopicName($theWeb, $theBlogRef);
  #writeDebug("theBlogRef=$theBlogRef");
  #writeDebug("theWeb=$theWeb");

  &initDB($theWeb);

  # query topics
  my $nrTopics = &countBlogRefs($theWeb, $theBlogRef);

  # render result
  $nrTopics += $theOffset;
  return '' if $theHideNull eq 'on' && $nrTopics == 0;
  $nrTopics = $theNullString if $theNullString && $nrTopics == 0;
  my $text = ($nrTopics == 1)?$theSingle:$theFormat;
  $text = expandVariables($text,count=>$nrTopics);

  #writeDebug("text=$text");

  return $text;
}

###############################################################################
sub getRelatedEntries {
  my ($theWeb, $theTopic, $theDepth, $theRelatedTopics) = @_;

  writeDebug("getRelatedEntries($theWeb, $theTopic, $theDepth) called");
  $theRelatedTopics->{$theTopic} = 1;
  writeDebug("already got " . join(",", sort keys %$theRelatedTopics));
  $theDepth = 1 unless defined $theDepth;
  return $theRelatedTopics unless $theDepth;
  
  # get related topics we refer to
  my %relatedTopics = ();
  my $relatedTopics = &getFormField($theWeb, $theTopic, 'Related');
  if (!$relatedTopics) {
    writeDebug("ERROR: no relatedTopics in $theWeb.$theTopic"); 
  } else {
    foreach my $related (split(/, /, $relatedTopics)) {
      next if $theRelatedTopics && $theRelatedTopics->{$related};
      $relatedTopics{$related} = 1;
      writeDebug("found related $related");
    }
  }

  # get related topics that refer to us
  my ($revRelatedTopics) = &dbQuery('Related=~\'\b' . $theTopic . '\b\'', $theWeb);
  foreach my $related (@$revRelatedTopics) {
    next if $theRelatedTopics && $theRelatedTopics->{$related};
    $relatedTopics{$related} = 1;
    writeDebug("found rev related $related");
  }

  # get transitive related
  writeDebug("get trans related of $theTopic");
  foreach my $related (keys %relatedTopics) {
    next if $theRelatedTopics && $theRelatedTopics->{$related};
    my $transRelatedTopics = &getRelatedEntries($theWeb, $related, $theDepth - 1, $theRelatedTopics);
    if ($transRelatedTopics) {
      foreach my $transRelated (keys  %$transRelatedTopics) {
	$theRelatedTopics->{$transRelated} = 1;
      }
    }
  }
  
  writeDebug("theRelatedTopics=" . join(",", sort keys %$theRelatedTopics) . " ... $theTopic in depth $theDepth");
  return $theRelatedTopics;
}

###############################################################################
sub _RELATEDENTRIES {
  my ($session, $params, $theTopic, $theWeb) = @_;

  writeDebug("_RELATEDENTRIES() called");

  $theTopic = $params->{_DEFAULT} || return '';
  my $theFormat = $params->{format} || '$topic';
  my $theHeader = $params->{header} || '';
  my $theSeparator = $params->{separator} || '$n';
  my $theDepth = $params->{depth} || 2;
  $theWeb = $params->{web} || $theWeb;

  &initDB($theWeb);

  # get direct related
  my $relatedTopics = &getRelatedEntries($theWeb, $theTopic, $theDepth);

  # sort related topics by creation date
  ($relatedTopics) = &dbQuery("State='enabled' AND name !='$theTopic'", 
    $theWeb, [keys %{$relatedTopics}], 'created', 'on');
  return '' if !$relatedTopics || !@$relatedTopics;

  # rendere result
  my $result = $theHeader;
  my $isFirst = 1;
  foreach my $related (@$relatedTopics) {
    writeDebug("found related=$related");

    my $text = $theFormat;
    $text =~ s/\$topic/$related/go;

    # render meta data of related topics
    if ($text =~ /\$headline/) {
      my $headline = &getFormField($theWeb, $related, 'Headline');
      $text =~ s/\$headline/$headline/g;
    }

    if ($isFirst) {
      $isFirst = 0;
    } else {
      $result .= $theSeparator;
    }
    $result .= $text;
    writeDebug("result=$result");
  }

  # subst standards
  $result =~ s/\$n/\n/go;
  $result =~ s/\$percnt/%/go;
  $result =~ s/\$dollar/\$/go;
  $result =~ s/\$headline//go;

  return $result;
}

###############################################################################
# Adapted from WordPress plugin TimeSince by
# Michael Heilemann (http://binarybonsai.com), 
# Dunstan Orchard (http://www.1976design.com/blog/archive/2004/07/23/redesign-time-presentation/),
# Nataile Downe (http://blog.natbat.co.uk/archive/2003/Jun/14/time_since)
# 
# thanks to all of you
sub _TIMESINCE {
  my ($session, $params, $theTopic, $theWeb) = @_;

  #print STDERR "DEBUG: _TIMESINCE(" . $params->stringify() . ") called\n";

  my $theFrom = $params->{_DEFAULT} || $params->{from} || '';
  my $theTo = $params->{to} || '';
  my $theUnits = $params->{units} || 2;
  my $theSeconds = $params->{seconds} || 'off';
  my $theAbs = $params->{abs} || 'off';
  my $theNull = $params->{null} || 'about now';
  my $theFormat = $params->{format} || '$time';

  if (!$theFrom && !$theTo) {
    # if there's no starting date then get the current revision date
    my ($meta, undef) = &TWiki::Func::readTopic($theWeb, $theTopic);
    ($theFrom) = $meta->getRevisionInfo();
    $theTo = time();
  } else {

    $theFrom =~ s/^\s*(.*)\s*$/$1/go;
    $theTo =~ s/^\s*(.*)\s*$/$1/go;

  
    # convert time to epoch seconds
    if ($theFrom ne '') {
      if ($theFrom !~ /^\d+$/) { # already epoch seconds
	eval {
	  local $SIG{'__DIE__'};
	  $theFrom = &parseTime($theFrom);
	};
	if ($@) {
	  my $message = $@;
	  $message =~ s/\sat\s.*//gos;
	  return &inlineError("ERROR: can't parse from=\"$theFrom\" - $message");
	}
      }
    } else {
      $theFrom = time();
    }
    if ($theTo ne '') {
      if ($theTo !~ /^\d+$/) { # already epoch seconds
	eval {
	  local $SIG{'__DIE__'};
	  $theTo = &parseTime($theTo);
	};
	if ($@) {
	  my $message = $@;
	  $message =~ s/at.*//gos;
	  return &inlineError("ERROR: can't parse to=\"$theTo\" - $message");
	}
      }
    } else {
      $theTo = time();
    }
  }

  my $since = $theTo - $theFrom;
  if ($theAbs eq 'on') {
    $since = abs($since);
  }
   
  #print STDERR "DEBUG: theFrom=$theFrom, theTo=$theTo, since=$since\n";

  # calculate time string
  my $unit;
  my $count;
  my $seconds;
  my $timeString = '';
  my $state = 0;

  # step one: the first chunk
  my $max = ($theSeconds eq 'on')?7:6;
  for (my $i = 0; $i < $max; $i++) {
    $unit = $seconds[$i][0];
    $seconds = $seconds[$i][1];
    $count = int(($since + 0.0) / $seconds);

    #writeDebug("unit=$unit, seconds=$seconds, count=$count, since=$since");

    # finding next unit
    if ($count) {
      $timeString .= ', ' if $state > 0;
      $timeString .= ($count == 1) ? '1 '.$unit : "$count ${unit}s";
      $state++;
    } else {
      next;
    }

    $since -= ($count * $seconds);
    last if $theUnits && $state >= $theUnits;
  }
  
  if ($timeString eq '') {
    return expandVariables($theNull);
  } else {
    return expandVariables($theFormat, 'time'=>$timeString);
  }
}

###############################################################################
# duplication of TWiki::Time::parseTime 
# but using timelocal() instead of timegm()
sub parseTime {
    my( $date ) = @_;

    # NOTE: This routine *will break* if input is not one of below formats!
    
    # FIXME - why aren't ifs around pattern match rather than $5 etc
    # try "31 Dec 2001 - 23:59"  (TWiki date)
    if ($date =~ /([0-9]+)\s+([A-Za-z]+)\s+([0-9]+)[\s\-]+([0-9]+)\:([0-9]+)/) {
        my $year = $3;
        $year -= 1900 if( $year > 1900 );
        # The ($2) will look up the constant so named
        return timelocal( 0, $5, $4, $1, $MON2NUM{$2}, $year );
    }

    # try "31 Dec 2001"
    if ($date =~ /([0-9]+)\s+([A-Za-z]+)\s+([0-9]+)/) {
        my $year = $3;
        $year -= 1900 if( $year > 1900 );
        # The ($2) will look up the constant so named
        return timelocal( 0, 0, 0, $1, $MON2NUM{$2}, $year );
    }

    # try "2001/12/31 23:59:59" or "2001.12.31.23.59.59" (RCS date)
    if ($date =~ /([0-9]+)[\.\/\-]([0-9]+)[\.\/\-]([0-9]+)[\.\s\-]+([0-9]+)[\.\:]([0-9]+)[\.\:]([0-9]+)/) {
        my $year = $1;
        $year -= 1900 if( $year > 1900 );
        return timelocal( $6, $5, $4, $3, $2-1, $year );
    }

    # try "2001/12/31 23:59" or "2001.12.31.23.59" (RCS short date)
    if ($date =~ /([0-9]+)[\.\/\-]([0-9]+)[\.\/\-]([0-9]+)[\.\s\-]+([0-9]+)[\.\:]([0-9]+)/) {
        my $year = $1;
        $year -= 1900 if( $year > 1900 );
        return timelocal( 0, $5, $4, $3, $2-1, $year );
    }

    # try "2001-12-31T23:59:59Z" or "2001-12-31T23:59:59+01:00" (ISO date)
    # FIXME: Calc local to zulu time "2001-12-31T23:59:59+01:00"
    if ($date =~ /([0-9]+)\-([0-9]+)\-([0-9]+)T([0-9]+)\:([0-9]+)\:([0-9]+)/ ) {
        my $year = $1;
        $year -= 1900 if( $year > 1900 );
        return timelocal( $6, $5, $4, $3, $2-1, $year );
    }

    # try "2001-12-31T23:59Z" or "2001-12-31T23:59+01:00" (ISO short date)
    # FIXME: Calc local to zulu time "2001-12-31T23:59+01:00"
    if ($date =~ /([0-9]+)\-([0-9]+)\-([0-9]+)T([0-9]+)\:([0-9]+)/ ) {
        my $year = $1;
        $year -= 1900 if( $year > 1900 );
        return timelocal( 0, $5, $4, $3, $2-1, $year );
    }

    # give up, return start of epoch (01 Jan 1970 GMT)
    return 0;
}

###############################################################################
sub getFormField {
  my ($theWeb, $theTopic, $theFormField) = @_;

  my $topicObj = $db{$theWeb}->fastget($theTopic);
  return '' unless $topicObj;
  
  my $form = $topicObj->fastget('form');
  return '' unless $form;

  $form = $topicObj->fastget($form);
  my $formfield = $form->fastget($theFormField) || '';
  return TWiki::urlDecode($formfield);
}

###############################################################################
sub dbQuery {
  my ($theSearch, $theWeb, $theTopics, $theOrder, $theReverse) = @_;

# TODO return empty result on an emtpy topics list

  $theOrder ||= '';
  $theReverse ||= '';
  $theSearch ||= '';
  $theTopics ||= '';

#  print STDERR "DEBUG: dbQuery($theSearch, $theWeb, $theTopics, $theOrder, $theReverse) called\n";
#  print STDERR "DEBUG: theTopics=" . join(',', @$theTopics) . "\n" if $theTopics;

  my @topicNames = $theTopics?@$theTopics:$db{$theWeb}->getKeys();
  
  # parse & fetch
  my %hits;
  if ($theSearch) {
    my $search = new TWiki::Contrib::DBCacheContrib::Search($theSearch);
    unless ($search) {
      return (undef, undef, &inlineError("ERROR: can't parse query $theSearch"));
    }
    foreach my $topicName (@topicNames) {
      my $topicObj = $db{$theWeb}->fastget($topicName);
      if ($search->matches($topicObj)) {
	$hits{$topicName} = $topicObj;
#	print STDERR "DEBUG: adding hit for $topicName\n";
      }
    }
  } else {
    foreach my $topicName (@topicNames) {
      my $topicObj = $db{$theWeb}->fastget($topicName);
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
	expandPath($theWeb, $hits{$a}, 'createdate') <=> expandPath($theWeb, $hits{$b}, 'createdate')
      } @topicNames;
    } else {
      @topicNames = sort {
	expandPath($theWeb, $hits{$a}, $theOrder) cmp expandPath($theWeb, $hits{$b}, $theOrder)
      } @topicNames;
    }
    @topicNames = reverse @topicNames if $theReverse eq 'on';
  }

  # limit

  return (\@topicNames, \%hits, undef);
}

###############################################################################
sub inlineError {
  return '<span class="twikiAlert">' . $_[0] . '</span>' ;
}

1;

