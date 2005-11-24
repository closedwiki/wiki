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

use strict;
use vars qw(
        $VERSION $RELEASE $debug $doneHeader
	%prevTopicCache %nextTopicCache
	%recentCommentsCache
    );

$VERSION = '$Rev$';
$RELEASE = '0.30';
$debug = 0; # toggle me

use TWiki::Plugins::DBCachePlugin qw(dbQuery getFormField initDB);
use TWiki::Plugins::BlogPlugin::WebDB;
use Digest::MD5 qw(md5_hex);

###############################################################################
sub writeDebug {
  #&TWiki::Func::writeDebug('- BlogPlugin - ' . $_[0]) if $debug;
  print STDERR "DEBUG - BlogPlugin - $_[0]\n" if $debug;
}

###############################################################################
sub initPlugin {


  $doneHeader = 0;
  %prevTopicCache = ();
  %nextTopicCache = ();
  %recentCommentsCache = ();

  TWiki::Func::registerTagHandler('CITEBLOG', \&_CITEBLOG);
  TWiki::Func::registerTagHandler('COUNTCOMMENTS', \&_COUNTCOMMENTS);
  TWiki::Func::registerTagHandler('NEXTDOC', \&_NEXTDOC);
  TWiki::Func::registerTagHandler('PREVDOC', \&_PREVDOC);
  TWiki::Func::registerTagHandler('RECENTCOMMENTS', \&_RECENTCOMMENTS);
  TWiki::Func::registerTagHandler('RELATEDENTRIES', \&_RELATEDENTRIES);

  TWiki::Func::registerTagHandler('DBTEST', \&_DBTEST); # for debugging

  return 1;
}

###############################################################################
sub commonTagsHandler {

  if (!$doneHeader) {
    my $link = 
      '<link rel="stylesheet" '.
      'href="%PUBURL%/%TWIKIWEB%/BlogPlugin/style.css" '.
      'type="text/css" media="all" />';
    if ($_[0] =~ s/<head>(.*?[\r\n]+)/<head>$1$link\n/o) {
      $doneHeader = 1;
    }
  }
}

###############################################################################
sub _CITEBLOG {
  my ($session, $params, $theTopic, $theWeb) = @_;

  $theTopic = $params->{_DEFAULT} || $params->{topic};
  ($theWeb, $theTopic) = &TWiki::Func::normalizeWebTopicName($theWeb, $theTopic);

  return &inlineError("ERROR: CITEBLOG has no topic argument") 
    unless $theTopic;

  my $theDB = &initDB($theWeb);

  my $text = "[[$theWeb.$theTopic][$theTopic]]";

  my $topicObj = $theDB->fastget($theTopic);
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

  return $theFormat;
}

###############################################################################
sub _DBTEST {
  my ($session, $params, $theTopic, $theWeb) = @_;

  my $theDB = &initDB($theWeb);
  my $result = "<noautolink>\n";

  my $size = $theDB->size();
  $result .= "---++ size=$size\n";
  foreach my $key1 ('RenderBlogEntry') {
  
    my $value1 = $theDB->fastget($key1) || '';
    $result .= "---++ <nobr> $key1 = $value1</nobr>\n";

    foreach my $key2 (sort $value1->getKeys()) {
      my $value2 = $value1->fastget($key2);
      next unless $value2;
      $result .= "---+++ <nobr> $key2\n<verbatim>\n$value2\n</verbatim>\n</nobr>\n";
    }
    my $topicForm = $value1->fastget('form');
    if ($topicForm) {
      $result .= "---++ $topicForm\n";
      $topicForm = $value1->fastget($topicForm);
      foreach my $key2 (sort $topicForm->getKeys()) {
        my $value2 = $topicForm->fastget($key2);
        $result .= "<nobr> $key2 = $value2</nobr><br/>\n" if $value2;
      }
    }
    my $topicInfo = $value1->fastget('info');
    $result .= "---++ info: $topicInfo\n";
    foreach my $key2 (sort $topicInfo->getKeys()) {
      my $value2 = $topicInfo->fastget($key2);
      $result .= "<nobr> $key2 = $value2</nobr><br/>\n" if $value2;
    }
  }
  return $result."\n</noautolink>\n";
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

  return &inlineError("ERROR: PREVDOC has no \"where\" argument") unless $theWhere;

  my ($thisWeb, $thisTopic) = &TWiki::Func::normalizeWebTopicName($theWeb, $theTopic);

  #writeDebug('theFormat='.$theFormat);
  #writeDebug('theWhere='. $theWhere) if $theWhere;
  
  my $theDB = &initDB($thisWeb);
  my ($prevTopic, $nextTopic) = &getPrevNextTopic($theDB, $thisWeb, $thisTopic, $theWhere, $theOrder);
  if ($prevTopic ne '_notfound') {
    return &expandVariables($theFormat, topic=>$prevTopic, web=>$thisWeb);
  }
  return '';
}

###############################################################################
sub _NEXTDOC {
  my ($session, $params, $theTopic, $theWeb) = @_;

  #writeDebug("called _NEXTDOC($theTopic)");
  
  $theTopic = $params->{_DEFAULT} || $params->{topic} || $theTopic;
  my $theFormat = $params->{format} || '$topic';
  my $theWhere = $params->{where};
  my $theOrder = $params->{order} || 'created';
  $theWeb = $params->{web} || $theWeb;

  return &inlineError("ERROR: NEXTDOC has no \"where\" argument") unless $theWhere;

  my ($thisWeb, $thisTopic) = &TWiki::Func::normalizeWebTopicName($theWeb, $theTopic);

  #writeDebug('theFormat='.$theFormat);
  #writeDebug('theWhere='. $theWhere) if $theWhere;

  my $theDB = &initDB($thisWeb);
  my ($prevTopic, $nextTopic) = &getPrevNextTopic($theDB, $thisWeb, $thisTopic, $theWhere, $theOrder);
  if ($nextTopic ne '_notfound') {
    return &expandVariables($theFormat, topic=>$nextTopic, web=>$thisWeb);
    return $theFormat;
  }
  return '';
}

###############################################################################
sub getPrevNextTopic {
  my ($theDB, $theWeb, $theTopic, $theWhere, $theOrder) = @_;

  #print STDERR "DEBUG: getPrevNextTopic($theWeb, $theTopic, $theWhere) called\n";
  my $key = $theWeb.'.'.$theTopic.':'.$theWhere.':'.$theOrder;
  my $prevTopic = $prevTopicCache{$key};
  my $nextTopic = $nextTopicCache{$key};

  if ($prevTopic && $nextTopic) {
    #writeDebug("found in cache: prevTopic=$prevTopic, nextTopic=$nextTopic");
    return ($prevTopic, $nextTopic);
  }

  my ($resultList) = &dbQuery($theDB, $theWhere, undef, $theOrder);
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
sub _RECENTCOMMENTS {
  my ($session, $params, $theTopic, $theWeb) = @_;

  my $key = md5_hex("$theTopic.$theWeb" . $params->stringify());

  #print STDERR "DEBUG: _RECENTCOMMENTS(".$params->stringify().") called\n";
  #print STDERR "DEBUG: key=$key\n";

  my $cacheEntry = $recentCommentsCache{$key};
  if ($cacheEntry) {
    #print STDERR "DEBUG: found in cache\n";
    return $cacheEntry;
  }

  my $theFormat = $params->{_DEFAULT} || $params->{format};
  my $theSeparator = $params->{separator} || '$n';
  my $theLimit = $params->{limit} || -1;
  my $theAge = $params->{age} || 0; # 5184000 are ca 2 months TODO compute TIMESINCE reversely
  my $theHeader = $params->{header} || '';
  my $theFooter = $params->{footer} || '';
  my $theCategory = $params->{category} || '.*';
  $theAge =~ s/[^\d]+//go;
  $theWeb = $params->{web} || $theWeb;

  return &inlineError("ERROR: RECENTCOMMENTS has no \"format\" argument") 
    unless $theFormat;
  
  my $theDB = &initDB($theWeb);

  my %blogComments;
  my %baseRefs;
  my $now = time();
  foreach my $topicName ($theDB->getKeys()) {

    # get blog comment
    my $topicObj = $theDB->fastget($topicName); 
    my $topicForm = $topicObj->fastget('form');
    next unless $topicForm;
    $topicForm = $topicObj->fastget($topicForm);
    my $topicType = $topicForm->fastget('TopicType');
    next unless $topicType;
    next unless $topicType =~ /BlogComment/o;

    # check if blog comment is too old
    my $topicCreateDate = $topicObj->fastget('createdate');
    if ($theAge) {
      my $diff = $now - $topicCreateDate;
      if ($diff > $theAge) {
	#print STDERR "DEBUG: $topicName exipred, diff=$diff\n";
	next;
      }
    }

    # check if referer is enabled and matches the category
    my $baseRefName = $topicForm->fastget('BaseRef');
    next unless $baseRefName;
    my $baseRefObj = $theDB->fastget($baseRefName);
    next unless $baseRefObj;
    my $baseRefForm = $baseRefObj->fastget('form');
    next unless $baseRefForm;
    $baseRefForm = $baseRefObj->fastget($baseRefForm);
    my $state = $baseRefForm->fastget('State');
    next unless $state;
    next unless $state eq 'enabled';
    my $category = $baseRefForm->fastget('SubjectCategory');
    next unless $category =~ /$theCategory/;

    # found
    $theLimit-- unless $baseRefs{$baseRefName};
    
    $blogComments{$topicName}{obj} = $topicObj;
    $blogComments{$topicName}{createdate} = $topicCreateDate;
    $blogComments{$topicName}{author} = $topicForm->fastget('Name');
    $baseRefs{$baseRefName}{obj} = $baseRefObj;

    if (!$baseRefs{$baseRefName}{latestdate} ||
	$baseRefs{$baseRefName}{latestdate} < $topicCreateDate) {
      $baseRefs{$baseRefName}{latestdate} = $topicCreateDate;
    }
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

    last if $theLimit == 0; # zero limit is unlimited
  }

  # sort
  my @baseRefs = sort {
      $baseRefs{$b}{latestdate} <=> $baseRefs{$a}{latestdate}
    } keys %baseRefs;
  foreach my $baseRefName (@baseRefs) {
    @{$baseRefs{$baseRefName}{comments}} = sort {
      $blogComments{$b}{createdate} <=> $blogComments{$b}{'createdate'}
    } @{$baseRefs{$baseRefName}{comments}};
  }

  # render result
  my $result = '';
  my %seen = ();
  foreach my $baseRefName (@baseRefs) { # newest postings first
    next if $seen{$baseRefName};
    $seen{$baseRefName} = 1;

    my $text = $theSeparator if $result && $theSeparator ne 'none';
    $text .= $theFormat;

    # get variables
    my $headline = $baseRefs{$baseRefName}{headline};
    my $commenter = '';

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
      date=>$baseRefs{$baseRefName}{latestdate}
    );
      
    $result .= $text;
  }

  $result = expandVariables($theHeader.$result.$theFooter) if $result;
  $recentCommentsCache{$key} = $result;

  return $result;
}

###############################################################################
sub _COUNTCOMMENTS {
  my ($session, $params, $theTopic, $theWeb) = @_;

  writeDebug("called _COUNTCOMMENTS()");

  my $theBlogRef = $params->{_DEFAULT} || $params->{topic};
  my $theFormat = $params->{format} || '$count';
  my $theSingle = $params->{single} || $theFormat;
  my $theHideNull = $params->{hidenull} || 'off';
  my $theNullString = $params->{null} || '0';
  my $theOffset = $params->{offset} || 0;
  $theWeb = $params->{web} || $theWeb;

  return &inlineError("ERROR: COUNTCOMMENTS has no topic argument") 
    unless $theBlogRef;

  ($theWeb, $theBlogRef) = &TWiki::Func::normalizeWebTopicName($theWeb, $theBlogRef);
  writeDebug("theBlogRef=$theBlogRef");
  writeDebug("theWeb=$theWeb");

  my $theDB = &initDB($theWeb);

  # query topics
  my $nrTopics = &countBlogRefs($theDB, $theBlogRef);

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
# recursion
sub countBlogRefs {
  my ($theDB, $theBlogRef) = @_;

  writeDebug("called countBlogRefs($theDB, $theBlogRef)");
  my $nrTopics = 0;
  if ($theBlogRef) {
    my $queryString = 
      'TopicType=~\'\bBlogComment\b\' AND BlogRef=\''.$theBlogRef.'\'';
    my ($blogRefs, undef, $errMsg) = &dbQuery($theDB, $queryString);

    die $errMsg if $errMsg; # never reach

    foreach my $blogRef (@$blogRefs) {
      $nrTopics += 1 + &countBlogRefs($theDB, $blogRef);
    }
  }

  writeDebug("result is $nrTopics");
  return $nrTopics;
}

###############################################################################
sub _RELATEDENTRIES {
  my ($session, $params, $theTopic, $theWeb) = @_;

  writeDebug("_RELATEDENTRIES() called");

  $theTopic = $params->{_DEFAULT} || $params->{topic};
  my $theFormat = $params->{format} || '$topic';
  my $theHeader = $params->{header} || '';
  my $theFooter = $params->{footer} || '';
  my $theSeparator = $params->{separator} || '$n';
  my $theDepth = $params->{depth} || 2;
  $theWeb = $params->{web} || $theWeb;

  return &inlineError("ERROR: RELATEDENTRIES has no topic argument") 
    unless $theTopic;

  my $theDB = &initDB($theWeb);

  # get direct related
  my %relatedTopics;
  &getRelatedEntries($theDB, $theTopic, $theDepth, \%relatedTopics);
  delete $relatedTopics{$theTopic};
  foreach my $key (keys %relatedTopics) {
    $relatedTopics{$key} = $theDepth - $relatedTopics{$key};
    #print STDERR "DEBUG: $theTopic has relative $key in depth $relatedTopics{$key}\n";
  }
  return '' unless scalar(keys %relatedTopics);
  my @relatedTopics = sort {$relatedTopics{$a} <=> $relatedTopics{$b}} keys %relatedTopics;

  # rendere result
  my $result = $theHeader;
  my $isFirst = 1;
  foreach my $related (@relatedTopics) {
    writeDebug("found related=$related");

    my $text = $theFormat;
    $text =~ s/\$topic/$related/go;
    $text =~ s/\$web/$theWeb/go;
    $text =~ s/\$depth/$relatedTopics{$related}/go;

    # render meta data of related topics
    if ($text =~ /\$headline/) {
      my $headline = &getFormField($theDB, $related, 'Headline');
      $text =~ s/\$headline/$headline/g;
    }

    if ($isFirst) {
      $isFirst = 0;
    } else {
      $result .= $theSeparator if $theSeparator ne 'none';
    }
    $result .= $text;
    writeDebug("result=$result");
  }
  $result .= $theFooter;

  # subst standards
  $result =~ s/\$n/\n/go;
  $result =~ s/\$t\b/\t/go;
  $result =~ s/\$percnt/%/go;
  $result =~ s/\$dollar/\$/go;
  $result =~ s/\$headline//go;

  return $result;
}

###############################################################################
sub getRelatedEntries {
  my ($theDB, $theTopic, $theDepth, $theRelatedTopics) = @_;

  #writeDebug("getRelatedEntries($theTopic, $theDepth) called");
  $theDepth = 1 unless defined $theDepth;
  $theRelatedTopics->{$theTopic} = $theDepth;
  return $theRelatedTopics unless $theDepth > 0;
  
  # get related topics we refer to
  my %relatedTopics = ();
  my $relatedTopics = &getFormField($theDB, $theTopic, 'Related');
  if (!$relatedTopics) {
    writeDebug("ERROR: no relatedTopics in $theTopic"); 
  } else {
    foreach my $related (split(/, /, $relatedTopics)) {
      next if $theRelatedTopics && $theRelatedTopics->{$related};
      my $state = &getFormField($theDB, $related, 'State');
      next unless $state eq 'enabled';
      $relatedTopics{$related} = $theDepth;
      writeDebug("found related $related");
    }
  }

  # get related topics that refer to us
  my ($revRelatedTopics) = &dbQuery($theDB, 'Related=~\'\b' . $theTopic . '\b\' AND State=\'enabled\'');
  foreach my $related (@$revRelatedTopics) {
    next if $theRelatedTopics && $theRelatedTopics->{$related};
    $relatedTopics{$related} = $theDepth;
    writeDebug("found rev related $related");
  }

  # get transitive related
  writeDebug("get trans related of $theTopic");
  foreach my $related (keys %relatedTopics) {
    next if $theRelatedTopics && $theRelatedTopics->{$related};
    &getRelatedEntries($theDB, $related, $relatedTopics{$related}-1, $theRelatedTopics);
  }
  
  writeDebug("theRelatedTopics=" . join(",", sort keys %$theRelatedTopics) . " ... $theTopic in depth $theDepth");
  return $theRelatedTopics;
}

###############################################################################
sub inlineError {
  return '<span class="twikiAlert">' . $_[0] . '</span>' ;
}

1;

