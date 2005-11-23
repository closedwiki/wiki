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
        $VERSION $RELEASE $debug $doneHeader
	%prevTopicCache %nextTopicCache %db
	%recentCommentsCache
    );

$VERSION = '$Rev$';
$RELEASE = '0.21';

use TWiki::Contrib::DBCacheContrib;
use TWiki::Contrib::DBCacheContrib::Search;
use TWiki::Plugins::BlogPlugin::WebDB;
use Digest::MD5 qw(md5_hex);

###############################################################################
sub writeDebug {
  &TWiki::Func::writeDebug('- BlogPlugin - ' . $_[0]) if $debug;
}

###############################################################################
sub initPlugin {

  $debug = 0; # toggle me

  $doneHeader = 0;
  %prevTopicCache = ();
  %nextTopicCache = ();
  %db = ();
  %recentCommentsCache = ();

  TWiki::Func::registerTagHandler('CITEBLOG', \&_CITEBLOG);
  TWiki::Func::registerTagHandler('COUNTCOMMENTS', \&_COUNTCOMMENTS);
  TWiki::Func::registerTagHandler('NEXTDOC', \&_NEXTDOC);
  TWiki::Func::registerTagHandler('PREVDOC', \&_PREVDOC);
  TWiki::Func::registerTagHandler('RECENTCOMMENTS', \&_RECENTCOMMENTS);
  TWiki::Func::registerTagHandler('RELATEDENTRIES', \&_RELATEDENTRIES);

  TWiki::Func::registerTagHandler('DBTEST', \&_DBTEST); # for debugging
  TWiki::Func::registerTagHandler('DBQUERY', \&_DBQUERY);
  TWiki::Func::registerTagHandler('DBCALL', \&_DBCALL);

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

  $theTopic = $params->{_DEFAULT} || $params->{topic};
  ($theWeb, $theTopic) = &TWiki::Func::normalizeWebTopicName($theWeb, $theTopic);

  return &inlineError("ERROR: CITEBLOG has no topic argument") 
    unless $theTopic;

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
# lightweighted INCLUDE using stored procedures instead of extracting them
# from the topics again and again
sub _DBCALL {
  my ($session, $params, $theTopic, $theWeb) = @_;

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
  &initDB($thisWeb);

  # get section
  my $topicObj = $db{$thisWeb}->fastget($thisTopic);
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
sub _DBQUERY {
  my ($session, $params, $theTopic, $theWeb) = @_;
  

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
  $theSkip =~ s/[^-\d]//go;
  $theSkip = 0 if $theSkip eq '';
  $theSkip = 0 if $theSkip < 0;
  $theFormat = '' if $theFormat eq 'none';
  $theSep = '' if $theSep eq 'none';
  $theLimit =~ s/[^\d]//go;
  $theLimit = scalar(@topicNames) if $theLimit eq '';
  $theLimit += $theSkip;

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
    my $isFirst = 1;
    foreach my $topicName (@$topicNames) {
      $index++;
      next if $index <= $theSkip;
      my $root = $hits->{$topicName};
      my $format = '';
      $format = $theSep unless $isFirst;
      $isFirst = 0;
      $format .= $theFormat;
      $format =~ s/\$formfield\((.*?)\)/getFormField($theWeb, $topicName, $1)/geo;
      $format =~ s/\$expand\((.*?)\)/expandPath($theWeb, $root, $1)/geo;
      $format =~ s/\$formatTime\((.*?)(?:,\s*'([^']*?)')?\)/TWiki::Func::formatTime(expandPath($theWeb, $root, $1), $2)/geo; # single quoted
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
  my $result = "<noautolink>\n";

  my $size = $db{$theWeb}->size();
  $result .= "---++ size=$size\n";
  foreach my $key1 ('RenderBlogEntry') {
  
    my $value1 = $db{$theWeb}->fastget($key1) || '';
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

  return &inlineError("ERROR: PREVDOC has no \"where\" argument") unless $theWhere;

  my ($thisWeb, $thisTopic) = &TWiki::Func::normalizeWebTopicName($theWeb, $theTopic);

  #writeDebug('theFormat='.$theFormat);
  #writeDebug('theWhere='. $theWhere) if $theWhere;
  
  &initDB($thisWeb);
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
  
  $theTopic = $params->{_DEFAULT} || $params->{topic} || $theTopic;
  my $theFormat = $params->{format} || '$topic';
  my $theWhere = $params->{where};
  my $theOrder = $params->{order} || 'created';
  $theWeb = $params->{web} || $theWeb;

  return &inlineError("ERROR: NEXTDOC has no \"where\" argument") unless $theWhere;

  my ($thisWeb, $thisTopic) = &TWiki::Func::normalizeWebTopicName($theWeb, $theTopic);

  #writeDebug('theFormat='.$theFormat);
  #writeDebug('theWhere='. $theWhere) if $theWhere;

  &initDB($thisWeb);
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
  
  &initDB($theWeb);

  my %blogComments;
  my %baseRefs;
  my $now = time();
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
      my $diff = $now - $topicCreateDate;
      if ($diff > $theAge) {
	#print STDERR "DEBUG: $topicName exipred, diff=$diff\n";
	next;
      }
    }

    # check if referer is enabled and matches the category
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
    my $category = $baseRefForm->fastget('SubjectCategory');
    next unless $category =~ /$theCategory/;

    # found
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
    $theLimit--;
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

  $theBlogRef = $params->{_DEFAULT} || $params->{topic};
  $theFormat = $params->{format} || '$count';
  $theSingle = $params->{single} || $theFormat;
  $theHideNull = $params->{hidenull} || 'off';
  $theNullString = $params->{null} || '0';
  $theOffset = $params->{offset} || 0;
  $theWeb = $params->{web} || $theWeb;

  return &inlineError("ERROR: COUNTCOMMENTS has no topic argument") 
    unless $theBlogRef;

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

  #writeDebug("getRelatedEntries($theWeb, $theTopic, $theDepth) called");
  $theDepth = 1 unless defined $theDepth;
  $theRelatedTopics->{$theTopic} = $theDepth;
  return $theRelatedTopics unless $theDepth > 0;
  
  # get related topics we refer to
  my %relatedTopics = ();
  my $relatedTopics = &getFormField($theWeb, $theTopic, 'Related');
  if (!$relatedTopics) {
    writeDebug("ERROR: no relatedTopics in $theWeb.$theTopic"); 
  } else {
    foreach my $related (split(/, /, $relatedTopics)) {
      next if $theRelatedTopics && $theRelatedTopics->{$related};
      my $state = &getFormField($theWeb, $related, 'State');
      next unless $state eq 'enabled';
      $relatedTopics{$related} = $theDepth;
      writeDebug("found related $related");
    }
  }

  # get related topics that refer to us
  my ($revRelatedTopics) = &dbQuery('Related=~\'\b' . $theTopic . '\b\' AND State=\'enabled\'', $theWeb);
  foreach my $related (@$revRelatedTopics) {
    next if $theRelatedTopics && $theRelatedTopics->{$related};
    $relatedTopics{$related} = $theDepth;
    writeDebug("found rev related $related");
  }

  # get transitive related
  writeDebug("get trans related of $theTopic");
  foreach my $related (keys %relatedTopics) {
    next if $theRelatedTopics && $theRelatedTopics->{$related};
    &getRelatedEntries($theWeb, $related, $relatedTopics{$related}-1, $theRelatedTopics);
  }
  
  writeDebug("theRelatedTopics=" . join(",", sort keys %$theRelatedTopics) . " ... $theTopic in depth $theDepth");
  return $theRelatedTopics;
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

  &initDB($theWeb);

  # get direct related
  my %relatedTopics;
  &getRelatedEntries($theWeb, $theTopic, $theDepth, \%relatedTopics);
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
      my $headline = &getFormField($theWeb, $related, 'Headline');
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

  return (\@topicNames, \%hits, undef);
}

###############################################################################
sub inlineError {
  return '<span class="twikiAlert">' . $_[0] . '</span>' ;
}

1;

