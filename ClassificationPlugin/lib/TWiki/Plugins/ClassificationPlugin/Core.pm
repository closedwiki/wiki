# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2006-2007 Michael Daum http://michaeldaumconsulting.com
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

package TWiki::Plugins::ClassificationPlugin::Core;

use strict;
use TWiki::Plugins::DBCachePlugin::Core;
use TWiki::Contrib::DBCacheContrib::Search;
use TWiki::Plugins::ClassificationPlugin::Hierarchy;

use vars qw(%hierarchies $baseWeb $baseTopic);

use constant DEBUG => 0; # toggle me

###############################################################################
sub writeDebug {
  print STDERR 'ClassificationPlugin::Core - '.$_[0]."\n" if DEBUG;
}

###############################################################################
sub init {
  ($baseWeb, $baseTopic) = @_;


  TWiki::Contrib::DBCacheContrib::Search::addOperator(
    name=>'SUBSUMES', 
    prec=>4,
    arity=>2,
    exec=>\&OP_subsumes,
  );
  TWiki::Contrib::DBCacheContrib::Search::addOperator(
    name=>'ISA', 
    prec=>4,
    arity=>2,
    exec=>\&OP_isa,
  );
  TWiki::Contrib::DBCacheContrib::Search::addOperator(
    name=>'DISTANCE', 
    prec=>5,
    arity=>2,
    exec=>\&OP_distance,
  );
}

###############################################################################
sub finish {

  foreach my $hierarchy (values %hierarchies) {
    $hierarchy->finish() if defined $hierarchy;
  }
}


###############################################################################
sub OP_subsumes {
  my ($r, $l, $map) = @_;
  my $lval = $l->matches( $map );
  my $rval = $r->matches( $map );
  return 0 unless ( defined $lval  && defined $rval);

  my $hierarchy = getHierarchy($baseWeb);
  return $hierarchy->subsumes($lval, $rval);
}

###############################################################################
sub OP_isa {
  my ($r, $l, $map) = @_;
  my $lval = $l->matches( $map );
  my $rval = $r->matches( $map );
  return 0 unless ( defined $lval  && defined $rval);

  my $hierarchy = getHierarchy($baseWeb);
  my $cat = $hierarchy->getCategory($rval);
  return 0 unless $cat;

  return ($cat->contains($lval))?1:0;
}

###############################################################################
sub OP_distance {
  my ($r, $l, $map) = @_;
  my $lval = $l->matches( $map );
  my $rval = $r->matches( $map );

  return 0 unless ( defined $lval  && defined $rval);

  my $hierarchy = getHierarchy($baseWeb);
  my $distance = $hierarchy->distance($lval, $rval);
  return '' unless $distance;
  my ($min, undef) = @$distance;

  return $min;
}

###############################################################################
sub handleTAGCOOCCURRENCE {
  my ($session, $params, $theTopic, $theWeb) = @_;

  my $theTag1 = $params->{tag1};
  my $theTag2 = $params->{tag2};
  my $thisTopic = $params->{_DEFAULT} || $params->{topic} || $baseTopic;
  my $thisWeb = $params->{web} || $baseWeb;
  my $theFormat = $params->{format} || '   * $tag1, $tag2: $count$n';
  my $theSep = $params->{separator} || '';
  my $theHeader = $params->{header} || '';
  my $theFooter = $params->{footer} || '';
  my $theArrayFormat = $params->{arrayformat} || '$tag2 ($count)';
  my $theArraySep = $params->{arrayseparator};
  my $theAllPairs = $params->{allpairs} || 'on';

  $theAllPairs = ($theAllPairs eq 'on')?1:0;

  $theArraySep = ',' unless defined($theArraySep);

  my $hierarchy = getHierarchy($thisWeb);
  my $coocc = $hierarchy->getCooccurrence($theTag1, $theTag2);

  my $result = '';

  # format
  my @result = ();
  if (defined($theTag1)) {
    if (defined($theTag2)) {
      # mode 3: coocurrences of tag1 and tag2
      my $count = $$coocc{$theTag1}{$theTag2};
      if (defined($count)) {
        push @result,  expandVariables($theFormat,
          tag1=>$theTag1,
          tag2=>$theTag2,
          count=>$count,
        );
      }
    } else {
      # mode 2: all coocurrences of tag1
      my @coocurringTags = sort keys %{$$coocc{$theTag1}};
      my $arrayResult = '';
      if ($theFormat =~ /\$array/) {
        my @arrayResult = ();
        foreach my $tag (@coocurringTags) {
          push @arrayResult, expandVariables($theArrayFormat,
            tag2=>$tag,
            count=>$$coocc{$theTag1}{$tag},
          );
        }
        $arrayResult = join($theArraySep, @arrayResult);
      }
      foreach my $theTag2 (@coocurringTags) {
        my $count = $$coocc{$theTag1}{$theTag2};
        if (defined($count)) {
          push @result,  expandVariables($theFormat,
            tag1=>$theTag1,
            tag2=>$theTag2,
            count=>$count,
            array=>$arrayResult,
          );
        }
      }
    }
  } else {
    if (defined($theTag2)) {
      # mode 2: all coocurrences of tag1
      my @coocurringTags = sort keys %{$$coocc{$theTag2}};
      my $arrayResult = '';
      if ($theFormat =~ /\$array/) {
        my @arrayResult = ();
        foreach my $tag (@coocurringTags) {
          push @arrayResult, expandVariables($theArrayFormat,
            tag2=>$tag,
            count=>$$coocc{$theTag1}{$tag},
          );
        }
        $arrayResult = join($theArraySep, @arrayResult);
      }
      foreach my $theTag1 (@coocurringTags) {
        my $count = $$coocc{$theTag1}{$theTag2};
        if (defined($count)) {
          push @result,  expandVariables($theFormat,
            tag1=>$theTag1,
            tag2=>$theTag2,
            count=>$count,
            array=>$arrayResult,
          );
        }
      }
    } else {
      # mode 1: full cooccurrence matrix
      foreach my $theTag1 (sort keys %{$coocc}) {
        my @coocurringTags = sort keys %{$$coocc{$theTag1}};
        writeDebug("coocurringTags($theTag1)=@coocurringTags");
        my $arrayResult = '';
        if ($theFormat =~ /\$array/) {
          my @arrayResult = ();
          my %seen;
          foreach my $tag (@coocurringTags) {
            next if $seen{$theTag1}{$tag};
            next if $seen{$tag}{$theTag1};
            $seen{$theTag1}{$tag} = 1;
            push @arrayResult, expandVariables($theArrayFormat,
              tag2=>$tag,
              count=>$$coocc{$theTag1}{$tag},
            );
          }
          $arrayResult = join($theArraySep, @arrayResult);
        }

        if ($theAllPairs) {
          my %seen;
          foreach my $theTag2 (@coocurringTags) {
            next if $seen{$theTag1}{$theTag2};
            next if $seen{$theTag2}{$theTag1};
            $seen{$theTag1}{$theTag2} = 1;
            my $count = $$coocc{$theTag1}{$theTag2};
            if (defined($count)) {
              push @result,  expandVariables($theFormat,
                tag1=>$theTag1,
                tag2=>$theTag2,
                count=>$count,
                array=>$arrayResult,
              );
            }
          }
        } else {
          push @result,  expandVariables($theFormat,
            tag1=>$theTag1,
            array=>$arrayResult,
          );
        }
      }
    }
  }
  
  $theHeader = expandVariables($theHeader);
  $theFooter = expandVariables($theFooter);
  $theSep = expandVariables($theSep);

  return $theHeader.join($theSep, @result).$theFooter;
}

###############################################################################
sub handleTAGRELATEDTOPICS {
  my ($session, $params, $theTopic, $theWeb) = @_;

  #writeDebug("called handleTAGRELATEDTOPICS()");

  my $thisTopic = $params->{_DEFAULT} || $params->{topic} || $baseTopic;
  my $thisWeb = $params->{web} || $baseWeb;
  my $theFormat = $params->{format} || '$topic';
  my $theHeader = $params->{header} || '';
  my $theFooter = $params->{footer} || '';
  my $theSep = $params->{separator};
  my $theIntersect = $params->{intersect} || 2;
  my $theMax = $params->{max} || 0;

  # sanitice parameters
  $theIntersect =~ s/[^\d]//g;
  $theIntersect = 2 if $theIntersect eq '';
  $theMax =~ s/[^\d]//g;
  $theMax = 0 if $theMax eq '';
  $theSep = ', ' unless defined $theSep;
  ($thisTopic, $thisWeb) = 
    TWiki::Func::normalizeWebTopicName($thisTopic, $thisWeb);

  my $hierarchy = getHierarchy($thisWeb);
  my $tagIntersection = $hierarchy->getTagIntersection($thisTopic);

  # sort most intersecting first
  my @foundTopics = 
    sort {$$tagIntersection{$b}{size} <=> $$tagIntersection{$a}{size}} 
      grep {$$tagIntersection{$_}{size} >= $theIntersect}
        keys %$tagIntersection;

  # format result
  my @lines;
  my $count = 0;
  foreach my $topic (@foundTopics) {
    $count++;
    last if $theMax && $count > $theMax;
    push @lines, expandVariables($theFormat,
      'topic'=>$topic,
      'web'=>$thisWeb,
      'index'=>$count,
      'size'=>$$tagIntersection{$topic}{size},
      'tags'=>join(', ', sort @{$$tagIntersection{$topic}{tags}}),
    );
  }

  #writeDebug("done handleTAGRELATEDTOPICS()");

  return '' unless @lines;
  $theHeader = expandVariables($theHeader, count=>$count);
  $theFooter = expandVariables($theFooter, count=>$count);
  $theSep = expandVariables($theSep);

  return $theHeader.join($theSep, @lines).$theFooter;
}

###############################################################################
sub handleHIERARCHY {
  my ($session, $params, $theTopic, $theWeb) = @_;

  #writeDebug("called handleHIERARCHY(".$params->stringify().")");

  my $thisWeb = $params->{_DEFAULT} || $params->{web} || $baseWeb;
  $thisWeb =~ s/\./\//go;

  my $hierarchy = getHierarchy($thisWeb);
  return $hierarchy->toHTML($params);
}

###############################################################################
sub handleISA {
  my ($session, $params, $theTopic, $theWeb) = @_;

  #writeDebug("called handleISA()");
  my $thisWeb = $params->{web} || $baseWeb;
  my $thisTopic = $params->{_DEFAULT} || $params->{topic} || $baseTopic;
  my $theCategory = $params->{cat} || '';

  return 0 unless $theCategory;

  ($thisWeb, $thisTopic) =
    TWiki::Func::normalizeWebTopicName($thisWeb, $thisTopic);

  my %lookingForCategory = map {$_=>1} split(/\s*,\s*/,$theCategory);
  my $hierarchy = getHierarchy($thisWeb);

  foreach my $catName (keys %lookingForCategory) {
    my $cat = $hierarchy->getCategory($catName);
    next unless $cat;
    return 1 if $cat->contains($thisTopic);
  }

  return 0;
}

###############################################################################
sub handleSUBSUMES {
  my ($session, $params, $theTopic, $theWeb) = @_;

  my $thisWeb = $params->{web} || $baseWeb;
  my $theCat1 = $params->{_DEFAULT} || $baseTopic;
  my $theCat2 = $params->{cat} || '';

  #writeDebug("called handleSUBSUMES($theCat1, $theCat2)");

  return 0 unless $theCat2;

  my $hierarchy = getHierarchy($thisWeb);
  my $cat1 = $hierarchy->getCategory($theCat1);
  return 0 unless $cat1;

  foreach my $catName (split(/\s*,\s*/,$theCat2)) {
    $catName =~ s/^\s+//g;
    $catName =~ s/\s+$//g;
    next unless $catName;
    my $cat2 = $hierarchy->getCategory($catName);
    next unless $cat2;
    return 1 if $cat1->subsumes($cat2);
  }


  return 0;
}

###############################################################################
sub handleDISTANCE {
  my ($session, $params, $theTopic, $theWeb) = @_;

  my $thisWeb = $params->{web} || $baseWeb;
  my $theFrom = $params->{_DEFAULT} || $params->{from} || $baseTopic;
  my $theTo = $params->{to} || 'TopCategory';
  my $theFormat = $params->{format} || '$min';
  my $theAbs = $params->{abs} || 'off';

  #writeDebug("called handleDISTANCE($theFrom, $theTo)");

  my $hierarchy = getHierarchy($thisWeb);

  my $distance = $hierarchy->distance($theFrom, $theTo);
  return '' unless defined $distance;
  my ($min, $max) = @$distance;

  if ($theAbs eq 'on') {
    $min = abs($min);
    $max = abs($max);
  }

  #writeDebug("distance=@$distance");

  my $result = $theFormat;
  $result =~ s/\$min/$min/g;
  $result =~ s/\$max/$max/g;

  return $result;
}

###############################################################################
sub handleCATFIELD {
  my ($session, $params, $theTopic, $theWeb) = @_;

  #writeDebug("called handleCATFIELD(".$params->stringify().")");

  my $theFormat = $params->{format} || '$cat';
  my $theSep = $params->{separator};
  my $theHeader = $params->{header} || '';
  my $theFooter = $params->{footer} || '';
  my $theTypes = $params->{type} || $params->{types} || '';
  my $thisTopic = $params->{_DEFAULT} || $params->{topic} || $baseTopic;
  my $thisWeb = $params->{web} || $baseWeb;

  $theSep = ', ' unless defined $theSep;

  ($thisWeb, $thisTopic) = 
    TWiki::Func::normalizeWebTopicName($thisWeb, $thisTopic);

  my $topicTypes;
  if ($theTypes) {
    #writeDebug("type mode");
    @{$topicTypes} = split(/\s*,\s*/,$theTypes);
  } else {
    #writeDebug("topic mode");
    $topicTypes = getTopicTypes($thisWeb, $thisTopic);
  }
  return '' unless $topicTypes && @$topicTypes;

  my $hierarchy = getHierarchy($thisWeb);
  my $catFields = $hierarchy->getCatFields(@$topicTypes);
  #writeDebug("found catFields=".join(',',@$catFields));
  my @result;
  my $count = @$catFields;
  my $index = 1;
  foreach my $catField (@$catFields) {
    my $line = $theFormat;
    $line =~ s/\$cat\b/$catField/g;
    $line =~ s/\$index\b/$index/g;
    $index++;
    push @result, $line;
  }

  my $result = $theHeader.join($theSep, @result).$theFooter;
  $result = expandVariables($result, 'count'=>$count);

  #writeDebug("result=$result");
  return $result;
}

###############################################################################
sub handleTAGFIELD {
  my ($session, $params, $theTopic, $theWeb) = @_;

  #writeDebug("called handleTAGFIELD(".$params->stringify().")");

  my $theFormat = $params->{format} || '$tag';
  my $theSep = $params->{separator};
  my $theHeader = $params->{header} || '';
  my $theFooter = $params->{footer} || '';
  my $theTypes = $params->{_DEFAULT} || $params->{type} || $params->{types} || '';

  $theSep = ', ' unless defined $theSep;

  my $thisTopic = $params->{topic} || $baseTopic;
  my $thisWeb = $params->{web} || $baseWeb;

  ($thisWeb, $thisTopic) = 
    TWiki::Func::normalizeWebTopicName($thisWeb, $thisTopic);

  #writeDebug("thisWeb=$thisWeb, thisTopic=$thisTopic");

  my $topicTypes;
  if ($theTypes) {
    @{$topicTypes} = split(/\s*,\s*/,$theTypes);
  } else {
    $topicTypes = getTopicTypes($thisWeb, $thisTopic);
  }
  return '' unless $topicTypes && @$topicTypes;

  my $hierarchy = getHierarchy($thisWeb);

  my $tagFields = $hierarchy->getTagFields(@$topicTypes);
  #writeDebug("found tagFields=".join(',',@$tagFields));
  my @result;
  my $count = @$tagFields;
  my $index = 1;
  foreach my $tagField (@$tagFields) {
    my $line = $theFormat;
    $line =~ s/\$tag\b/$tagField/g;
    $line =~ s/\$index\b/$index/g;
    $index++;
    push @result, $line;
  }

  my $result = $theHeader.join($theSep, @result).$theFooter;
  $result = expandVariables($result, 'count'=>$count);

  #writeDebug("result=$result");
  return $result;
}

###############################################################################
sub handleCATINFO {
  my ($session, $params, $theTopic, $theWeb) = @_;

  #writeDebug("called handleCATINFO(".$params->stringify().")");
  my $theCat = $params->{cat};
  my $theFormat = $params->{format} || '$link';
  my $theSep = $params->{separator};
  my $theHeader = $params->{header} || '';
  my $theFooter = $params->{footer} || '';
  my $thisWeb = $params->{web} || $baseWeb;
  my $thisTopic = $params->{_DEFAULT} || $params->{topic} || $baseTopic;

  $theSep = ', ' unless defined $theSep;

  ($thisWeb, $thisTopic) = 
    TWiki::Func::normalizeWebTopicName($thisWeb, $thisTopic);

  my $hierarchy = getHierarchy($thisWeb);
  return '' unless $hierarchy;

  my $categories;
  $categories = $hierarchy->getCategoriesOfTopic($thisTopic)
    unless defined $theCat;
  $categories->{$theCat} = 1 if defined $theCat;

  my @categories = keys %$categories;
  #@categories = grep (!/^(TopCategory|BottomCategory)$/, @categories);
  return '' unless @categories;
  
  my @result;
  foreach my $catName (sort @categories) {
    if ($catName =~ /^(TopCategory|BottomCategory)$/ &&
        !TWiki::Func::topicExists($thisWeb, $catName)) {
      next;
    }
    my $category = $hierarchy->getCategory($catName);
    my $line = $theFormat;
    my $parents = '';
    if ($line =~ /\$parents/) {
      my @links = ();
      foreach my $parent ($category->getParents()) {
        push @links, "[[$thisWeb.$parent->{name}][$parent->{title}]]";
      }
      $parents = join(', ', @links);
    }
    my $isCyclic = 0;
    $isCyclic = $category->isCyclic() if $theFormat =~ /\$cyclic/;
    my $title = $category->{title} || $catName;
    my $link = "[[$thisWeb.$catName][$title]]";
    my $url = TWiki::Func::getScriptUrl($thisWeb, $catName, 'view');
    my $summary = $category->{summary} || $title;
    $line =~ s/\$link/$link/g;
    $line =~ s/\$url/$url/g;
    $line =~ s/\$web/$thisWeb/g;
    $line =~ s/\$name/$catName/g;
    $line =~ s/\$title/$title/g;
    $line =~ s/\$summary/$summary/g;
    $line =~ s/\$parents/$parents/g;
    $line =~ s/\$cyclic/$isCyclic/g;
    push @result, $line;
  }
  return '' unless @result;
  my $result = $theHeader.join($theSep, @result).$theFooter;
  $result = expandVariables($result, 'count'=>scalar(@categories));

  #writeDebug("result=$result");
  return $result;
}

###############################################################################
sub handleTAGINFO {
  my ($session, $params, $theTopic, $theWeb) = @_;

  #writeDebug("called handleTAGINFO(".$params->stringify().")");
  my $theCat = $params->{cat};
  my $theFormat = $params->{format} || '$link';
  my $theSep = $params->{separator};
  my $theHeader = $params->{header} || '';
  my $theFooter = $params->{footer} || '';
  my $thisWeb = $params->{web} || $baseWeb;
  my $thisTopic = $params->{_DEFAULT} || $params->{topic} || $baseTopic;

  $theSep = ', ' unless defined $theSep;

  ($thisWeb, $thisTopic) = 
    TWiki::Func::normalizeWebTopicName($thisWeb, $thisTopic);

  # get tags
  my $db = TWiki::Plugins::DBCachePlugin::Core::getDB($thisWeb);
  return '' unless $db;
  my $topicObj = $db->fastget($thisTopic);
  return '' unless $topicObj;
  my $form = $topicObj->fastget('form');
  return '' unless $form;
  my $formObj = $topicObj->fastget($form);
  return '' unless $formObj;
  my $tags = $formObj->fastget('Tag');
  return '' unless $tags;
  my @tags = split(/\s*,\s*/, $tags);

  my @result;
  foreach my $tag (sort @tags) {
    $tag =~ s/^\s+//go;
    $tag =~ s/\s+$//go;
    my $line = $theFormat;
    my $url = TWiki::Func::getScriptUrl($thisWeb, "WebTagCloud", "view", search=>$tag);
    my $link = "<a href='$url'>$tag</a>";
    $line =~ s/\$url/$url/g;
    $line =~ s/\$link/$link/g;
    $line =~ s/\$web/$thisWeb/g;
    $line =~ s/\$name/$tag/g;
    push @result, $line;
  }
  my $result = $theHeader.join($theSep, @result).$theFooter;
  $result = expandVariables($result, 'count'=>scalar(@tags));

  #writeDebug("result='$result'");
  return $result;
}

###############################################################################
# reparent based on the category we are in
# takes the first category in alphabetic order
sub beforeSaveHandler {
  my ( $text, $topic, $web, $meta ) = @_;

  my $doAutoReparent = TWiki::Func::getPreferencesFlag('CLASSIFICATIONPLUGIN_AUTOREPARENT', $web);
  $doAutoReparent = 1 unless defined $doAutoReparent;

  return unless $doAutoReparent;

  unless ($meta) {
    my $session = $TWiki::Plugins::SESSION;
    $meta = new TWiki::Meta($session, $web, $topic );
    $session->{store}->extractMetaData( $meta, \$text );
  }

  # get categories of this topic,
  # must get it from current meta data
  my $topicType = $meta->get('FIELD', 'TopicType');
  return unless $topicType;
  $topicType = $topicType->{value};
  return unless $topicType =~ /ClassifiedTopic|CategorizedTopic|Category/;

  my @allCats;
  my $hierarchy = getHierarchy($web);
  my $catFields = $hierarchy->getCatFields(split(/\s*,\s*/,$topicType));

  # get categories from meta data
  foreach my $field (@$catFields) {
    my $cats = $meta->get('FIELD',$field);
    next unless $cats;
    $cats = $cats->{value};
    next unless $cats;
    foreach my $cat (split(/\s*,\s*/,$cats)) {
      $cat =~ s/^\s+//go;
      $cat =~ s/\s+$//go;
      push @allCats, $cat;
    }
  }

  # set the new parent topic
  $meta->remove('TOPICPARENT');
  if (@allCats) {
    @allCats = sort @allCats;
    my $firstCat = shift @allCats;
    # TODO: check if the firstCat exists and only then set the parent
    # don't autoset to HomeTopic if TopCategory
    $firstCat = $TWiki::cfg{HomeTopic} if $firstCat eq 'TopCategory';
    $meta->putKeyed('TOPICPARENT', {name=>$firstCat});

  } else {
    $meta->putKeyed('TOPICPARENT', {name=>''});
  }
}

###############################################################################
# TODO: only invalidate the hierarchy if relevant information has changed
sub afterSaveHandler {
  # my ( $text, $topic, $web, $error, $meta ) = @_;
  my $web = $_[2];

  # reset cache
  my $hierarchy = getHierarchy($web);
  $hierarchy->invalidate();
  $hierarchy->DESTROY();
  $hierarchies{$web} = undef;
}

###############################################################################
sub renderFormFieldForEditHandler {
  my ($name, $type, $size, $value, $attrs, $possibleValues) = @_;
  return undef unless $type =~ /^(cat|tag|widget)$/;

  #writeDebug("called renderFormFieldForEditHandler($name, $type, $size, $value, $attrs, $possibleValues)");

  my $widget = '';

  # category widget
  if ($type eq 'cat') {
    my %params = TWiki::Func::extractParameters($possibleValues);
    my $web = $params{web} || '';
    my $top = $params{_DEFAULT} || $params{top} || 'TopCategory';
    my $exclude = $params{exclude} || '';

    $widget = '%DBCALL{"Applications.ClassificationApp.RenderEditCategoryBrowser" '
      .'NAME="$name" VALUE="$value" TOP="$top" EXCLUDE="$exclude" THEWEB="$web"}%';

    $widget =~ s/\$web/$web/g;
    $widget =~ s/\$top/$top/g;
    $widget =~ s/\$exclude/$exclude/g;
  } 
  
  # tagging widget
  elsif ($type eq 'tag') {
    my %params = TWiki::Func::extractParameters($possibleValues);
    my $web = $params{web} || '';
    my $filter = $params{filter} || '';

    $widget = '%DBCALL{"Applications.ClassificationApp.RenderEditTagCloud" '
      .'NAME="$name" VALUE="$value" FILTER="$filter" THEWEB="$web"}%';

    $widget =~ s/\$web/$web/g;
    $widget =~ s/\$filter/$filter/g;
  }

  # generic widget
  else {
    $widget = $possibleValues;
    $widget =~ s/\$nop//go;
  }

  $widget =~ s/\$name/$name/g;
  $widget =~ s/\$type/$type/g;
  $widget =~ s/\$size/$size/g;
  $widget =~ s/\$value/$value/g;
  $widget =~ s/\$attrs/$attrs/g;
  $widget = TWiki::Func::expandCommonVariables($widget);

  # SMELL: fix for TwistyPlugin
  $widget =~ s/\%_TWISTYSCRIPT{\"(.*?)\"}\%/<script type="text\/javascript\"\>$1<\/script>/g;

  #writeDebug("widget=$widget");

  return $widget;
}

###############################################################################
sub getTopicTypes {
  my ($web, $topic) = @_;

  my $db = TWiki::Plugins::DBCachePlugin::Core::getDB($web);
  return undef unless $db;

  my $topicObj = $db->fastget($topic);
  return undef unless $db;

  my $form = $topicObj->fastget("form");
  return undef unless $form;

  $form = $topicObj->fastget($form);
  return undef unless $form;

  my $topicTypes = $form->fastget('TopicType');
  return undef unless $topicTypes;

  my @topicTypes = split(/\s*,\s*/, $topicTypes);

  return \@topicTypes;
}


###############################################################################
# returns the hierarchy object for a given web; construct a new one if
# not already done
sub getHierarchy {
  my $web = shift;

  unless (defined $hierarchies{$web}) {
    $hierarchies{$web} = new TWiki::Plugins::ClassificationPlugin::Hierarchy($web);
  }

  return $hierarchies{$web};
}

###############################################################################
sub expandVariables {
  my ($theFormat, %params) = @_;

  #writeDebug("called expandVariables($theFormat)");

  foreach my $key (keys %params) {
    die "params{$key} undefined" unless defined($params{$key});
    $theFormat =~ s/\$$key\b/$params{$key}/g;
  }
  $theFormat =~ s/\$percnt/\%/go;
  $theFormat =~ s/\$nop//g;
  $theFormat =~ s/\$n/\n/go;
  $theFormat =~ s/\$t\b/\t/go;
  $theFormat =~ s/\$dollar/\$/go;

  #writeDebug("result='$theFormat'");

  return $theFormat;
}


###############################################################################
1;

