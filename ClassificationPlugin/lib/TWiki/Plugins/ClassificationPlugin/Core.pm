# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2006 Michael Daum http://wikiring.com
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

use vars qw(%hierarchies);

sub DEBUG { 0; }


###############################################################################
sub writeDebug {
  #&TWiki::Func::writeDebug('- ClassificationPlugin - '.$_[0]) if DEBUG;
  print STDERR '- ClassificationPlugin::Core - '.$_[0]."\n" if DEBUG;
}

###############################################################################
sub init {
  TWiki::Contrib::DBCacheContrib::Search::addOperator('SUBSUMES', 4, \&OP_subsumes);
  TWiki::Contrib::DBCacheContrib::Search::addOperator('COMPATIBLE', 4, \&OP_compatble);
  TWiki::Contrib::DBCacheContrib::Search::addOperator('ISA', 4, \&OP_isa);
}

###############################################################################
sub OP_subsumes {
  my ($r, $l, $map) = @_;
  my $lval = $l->matches( $map );
  my $rval = $r->matches( $map );
  return 0 unless ( defined $lval  && defined $rval);

  my $hierarchy = getHierarchy($TWiki::Plugins::ClassificationPlugin::currentWeb);
  my $cat1 = $hierarchy->getCategory($lval);
  return 0 unless $cat1;

  my $cat2 = $hierarchy->getCategory($rval);
  return 0 unless $cat2;

  if ($cat1->subsumes($cat2)) {
    #writeDebug("OP_subsumes($lval, $rval)");
    return 1;
  }
  return 0;
}

###############################################################################
sub OP_compatible {
  my ($r, $l, $map) = @_;
  my $lval = $l->matches( $map );
  my $rval = $r->matches( $map );
  return 0 unless ( defined $lval  && defined $rval);
  #writeDebug("OP_compatible($lval, $rval)");

  my $hierarchy = getHierarchy($TWiki::Plugins::ClassificationPlugin::currentWeb);
  my $cat1 = $hierarchy->getCategory($lval);
  return 0 unless $cat1;

  my $cat2 = $hierarchy->getCategory($rval);
  return 0 unless $cat2;

  if ($cat1->compatible($cat2)) {
    #writeDebug("OP_subsumes($lval, $rval)");
    return 1;
  }
  return 0;
}

###############################################################################
sub OP_isa {
  my ($r, $l, $map) = @_;
  my $lval = $l->matches( $map );
  my $rval = $r->matches( $map );

  return 0 unless ( defined $lval  && defined $rval);

  #writeDebug("OP_isa($lval, $rval)");

  my $hierarchy = getHierarchy($TWiki::Plugins::ClassificationPlugin::currentWeb);
  my $cat = $hierarchy->getCategory($rval);
  return 0 unless $cat;

  if ($cat->contains($lval)) {
    #writeDebug("... yes");
    return 1;
  }
  #writeDebug("... no");
  return 0;
}

###############################################################################
sub handleTagRelatedTopics {
  my ($session, $params, $thisTopic, $thisWeb) = @_;

  #writeDebug("called handleTagRelatedTopics(".$params->stringify().")");

  my $theTopic = $params->{_DEFAULT} || $params->{topic} || $thisTopic;
  my $theWeb = $params->{web} || $thisWeb;
  my $theFormat = $params->{format} || '$topic';
  my $theHeader = $params->{header} || '';
  my $theFooter = $params->{footer} || '';
  my $theSep = $params->{separator} || ', ';

  ($theTopic, $theWeb) = TWiki::Func::normalizeWebTopicName($theTopic, $theWeb);

  my $db = TWiki::Plugins::DBCachePlugin::Core::getDB($theWeb);
  my $topicObj = $db->fastget($theTopic);
  return '' unless $topicObj;
  my $form = $topicObj->fastget("form");
  return '' unless $form;
  $form = $topicObj->fastget($form);
  my $tags = $form->fastget('Tag');
  return '' unless $tags;
  my @tags = split(/,\s*/,$tags);
  my $len = scalar(@tags);

  # build query string
  my @query = ();
  for (my $i = 0; $i < $len; $i++) {
    my $tag1 = $tags[$i];
    next unless $tag1;
    for (my $j = $i+1; $j < $len; $j++) {
      my $tag2 = $tags[$j];
      push @query, 'Tag=~\'\b'.$tag1.'\b\' AND Tag=~\'\b'.$tag2.'\b\''
    }
  }
  my $query = '('.join(') OR (', @query).')';
  #writeDebug("query=$query");

  # doit
  my ($topics) = $db->dbQuery($query);
  return '' unless $topics;

  # format result
  my @lines;
  my $count = 0;
  foreach my $topic (sort @$topics) {
    next if $topic eq $theTopic;
    $count++;
    push @lines, expandVariables($theFormat,
      'topic'=>$topic,
      'web'=>$theWeb,
      'index'=>$count,
    );
  }
  return '' unless @lines;

  my $result = $theHeader.join($theSep, @lines).$theFooter;
  return expandVariables($result, 'count'=>$count);
}

###############################################################################
sub handleBrowseCat {
  my ($session, $params, $theTopic, $theWeb) = @_;

  #writeDebug("called handleBrowseCat(".$params->stringify().")");

  my $thisWeb = $params->{_DEFAULT} || $params->{web} || $theWeb;
  $thisWeb =~ s/\./\//go;

  my $hierarchy = getHierarchy($thisWeb);
  return $hierarchy->toHTML($params);
}

###############################################################################
sub handleIsA {
  my ($session, $params, $theTopic, $theWeb) = @_;

  #writeDebug("called handleIsa()");
  my $thisWeb = $params->{web} || $theWeb;
  my $thisTopic = $params->{_DEFAULT} || $params->{topic} || $theTopic;
  my $theCategory = $params->{cat} || '';
  my $theUsage = $params->{usage};

  return 0 unless $theCategory;

  ($thisWeb, $thisTopic) =
    TWiki::Func::normalizeWebTopicName($thisWeb, $thisTopic);

  my $hierarchy = getHierarchy($thisWeb);

  foreach my $catName (split(/,/,$theCategory)) {
    $catName =~ s/^\s+//g;
    $catName =~ s/\s+$//g;
    next unless $catName;
    my $category = $hierarchy->getCategory($catName);
    return 1 if $category && $category->contains($thisTopic);
  }

  return 0;
}

###############################################################################
sub handleSubsumes {
  my ($session, $params, $theTopic, $theWeb) = @_;

  my $thisWeb = $params->{web} || $theWeb;
  my $theCat1 = $params->{_DEFAULT} || $theTopic;
  my $theCat2 = $params->{cat} || '';

  #writeDebug("called handleSubsumes($theCat1, $theCat2)");

  return 0 unless $theCat2;

  my $hierarchy = getHierarchy($thisWeb);
  my $cat1 = $hierarchy->getCategory($theCat1);
  return 0 unless $cat1;

  foreach my $catName (split(/,/,$theCat2)) {
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
sub handleCompatible {
  my ($session, $params, $theTopic, $theWeb) = @_;

  #writeDebug("called handleCompatible()");

  my $thisWeb = $params->{web} || $theWeb;
  my $theCat1 = $params->{_DEFAULT} || $theTopic;
  my $theCat2 = $params->{cat};

  return 0 unless $theCat2;

  my $hierarchy = getHierarchy($thisWeb);
  my $cat1 = $hierarchy->getCategory($theCat1);
  return 0 unless $cat1;

  foreach my $catName (split(/,/,$theCat2)) {
    $catName =~ s/^\s+//g;
    $catName =~ s/\s+$//g;
    next unless $catName;
    my $cat2 = $hierarchy->getCategory($theCat2);
    next unless $cat2;
    return 1 if $cat1->compatible($cat2);
  }

  return 0;
}

###############################################################################
sub handleSubsumtion {
  my ($session, $params, $theTopic, $theWeb) = @_;

  #writeDebug("called handleSubsumtion()");
  my $thisWeb = $params->{web} || $theWeb;

  my $hierarchy = getHierarchy($thisWeb);
  my @allCats = sort {$a->{name} cmp $b->{name}} $hierarchy->getCategories();

  my $result = '<div style="overflow:auto">';
  $result .= '<table class="twikiTable">';
  $result .= '<tr><th>Subsumtion</th>';
  foreach my $cat (@allCats) {
    if ($cat->{name} =~ /^(TOP|BOTTOM)$/) {
      $result .= "<th>$cat->{name}</th>";
    } else {
      $result .= "<th>[[$thisWeb.$cat->{name}][$cat->{name}]]</th>";
    }
  }
  $result .= '</tr>';
  foreach my $cat1 (@allCats) {
    if ($cat1->{name} =~ /^(TOP|BOTTOM)$/) {
      $result .= "<tr><th>$cat1->{name}</th>";
    } else {
      $result .= "<tr><th>[[$thisWeb.$cat1->{name}][$cat1->{name}]]</th>";
    }
    foreach my $cat2 (@allCats) {
      my $subsumtion = $cat1->subsumes($cat2);
      $result .= '<td'.($subsumtion?' style="background:#d0d0d0"':'').">$subsumtion</td>";
    }
    $result .= '</tr>';
  }
  $result .= '</table></div>';

  return $result;
}

###############################################################################
sub handleCompatibility {
  my ($session, $params, $theTopic, $theWeb) = @_;

  #writeDebug("called handleCompatibility()");
  my $thisWeb = $params->{web} || $theWeb;

  my $hierarchy = getHierarchy($thisWeb);
  my @allCats = sort {$a->{name} cmp $b->{name}} $hierarchy->getCategories();

  my $result = '<div style="overflow:auto">';
  $result .= '<table class="twikiTable">';
  $result .= '<tr><th>Compatibility</th>';
  foreach my $cat (@allCats) {
    if ($cat->{name} =~ /^(TOP|BOTTOM)$/) {
      $result .= "<th>$cat->{name}</th>";
    } else {
      $result .= "<th>[[$thisWeb.$cat->{name}][$cat->{name}]]</th>";
    }
  }
  $result .= '</tr>';
  foreach my $cat1 (@allCats) {
    if ($cat1->{name} =~ /^(TOP|BOTTOM)$/) {
      $result .= "<tr><th>$cat1->{name}</th>";
    } else {
      $result .= "<tr><th>[[$thisWeb.$cat1->{name}][$cat1->{name}]]</th>";
    }
    foreach my $cat2 (@allCats) {
      my $compatibility = $cat1->compatible($cat2);
      $result .= '<td'.($compatibility?' style="background:#d0d0d0"':'').">$compatibility</td>";
    }
    $result .= '</tr>';
  }
  $result .= '</table></div>';

  return $result;
}

###############################################################################
sub handleCatField {
  my ($session, $params, $theTopic, $theWeb) = @_;

  #writeDebug("called handleCatField(".$params->stringify().")");

  my $theFormat = $params->{format} || '$cat';
  my $theSep = $params->{separator} || ' ';
  my $theHeader = $params->{header} || '';
  my $theFooter = $params->{footer} || '';
  my $theTypes = $params->{_DEFAULT} || $params->{type} || $params->{types} || '';

  my $thisTopic = $params->{topic} || $theTopic;
  my $thisWeb = $params->{web} || $theWeb;

  ($thisWeb, $thisTopic) = 
    TWiki::Func::normalizeWebTopicName($thisWeb, $thisTopic);

  #writeDebug("thisWeb=$thisWeb, thisTopic=$thisTopic");

  my $hierarchy = getHierarchy($thisWeb);
  my @topicTypes;
  if ($theTypes) {
    @topicTypes = split(/,/,$theTypes);
  } else {
    @topicTypes = $hierarchy->getTopicTypes();
  }
  return '' unless @topicTypes;

  my $catFields = $hierarchy->getCatFields(@topicTypes);
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
# reparent based on the category we are in
# takes the first category in alphabetic order
sub beforeSaveHandler {
  my ( $text, $topic, $web, $meta ) = @_;

  my $doAutoReparent = TWiki::Func::getPreferencesFlag('CLASSIFICATIONPLUGIN_AUTOREPARENT', $web);
  $doAutoReparent = 1 unless defined $doAutoReparent;

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

  my $hierarchy = getHierarchy($web);
  my $catFields = $hierarchy->getCatFields(split(/,/,$topicType));
  my @allCats;
  foreach my $field (@$catFields) {
    my $cats = $meta->get('FIELD',$field);
    next unless $cats;
    $cats = $cats->{value};
    next unless $cats;
    foreach my $cat (split(/,/,$cats)) {
      $cat =~ s/^\s+//go;
      $cat =~ s/\s+$//go;
      push @allCats, $cat;
    }
  }

  # set the new parent topic
  $meta->remove('TOPICPARENT') if $doAutoReparent;
  if (@allCats) {
    @allCats = sort @allCats;
    my $firstCat = shift @allCats;
    $firstCat = $TWiki::cfg{HomeTopic} if $firstCat eq 'TOP';
    $meta->putKeyed('TOPICPARENT', {name=>$firstCat}) if $doAutoReparent;

    # set access rights
    my $access = 0;
    foreach my $catName (@allCats) {
      my $category = $hierarchy->getCategory($catName);
      $access = $category->checkAccessPermission($TWiki::cfg{'DefaultUserWikiName'});
      last if $access;
    }
    $meta->remove('PREFERENCE','DENYTOPICVIEW');
    if ($access) {
      $meta->putKeyed('PREFERENCE',{
        'name'=>'DENYTOPICVIEW', 
        'title'=>'DENYTOPICVIEW', 
        'type'=>'Set', 
        'value'=>''
      });
    }
  } else {
    $meta->putKeyed('TOPICPARENT', {name=>''}) if $doAutoReparent;
  }
}

###############################################################################
sub afterSaveHandler {
  # my ( $text, $topic, $web, $error, $meta ) = @_;

  # reset cache
  foreach my $hierarchy (values %hierarchies) {
    $hierarchy->DESTROY();
  }
  %hierarchies = ();

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
    my $top = $params{_DEFAULT} || $params{top} || 'TOP';
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

