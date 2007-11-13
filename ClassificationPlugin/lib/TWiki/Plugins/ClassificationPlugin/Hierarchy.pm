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

package TWiki::Plugins::ClassificationPlugin::Hierarchy;

use strict;
use TWiki::Plugins::DBCachePlugin::Core;
use TWiki::Plugins::ClassificationPlugin::Category;

sub DEBUG { 0; }

###############################################################################
# static
sub writeDebug {
  #&TWiki::Func::writeDebug('- ClassificationPlugin - '.$_[0]) if DEBUG;
  print STDERR '- ClassificationPlugin::Hierarchy - '.$_[0]."\n" if DEBUG;
}

################################################################################
# constructor
sub new {
  my $class = shift;
  my $web = shift;

  #writeDebug("new hierarchy for web $web");

  my $this = {
    web=>$web,
    @_
  };

  $this = bless($this, $class);
  $this->createCategory('TOP'); # every hierarchy has one top node
  $this->createCategory('BOTTOM'); # every hierarchy has one BOTTOM node
  $this->init();

  return $this;
}

################################################################################
# destructor
sub DESTROY {
  my $this = shift;

  #writeDebug("called DESTROY for hierarchy");
  foreach my $category ($this->getCategories()) {
    $category->DESTROY() if $category;
  }
  $this->{categories} = ();
  $this->{topicTypes} = ();
  $this->{_catFields} = undef;
}

################################################################################
sub init {
  my $this = shift;

  #writeDebug("called Hierarchy::init");

  my $db = TWiki::Plugins::DBCachePlugin::Core::getDB($this->{web});


  # itterate over all topics and collect categories
  foreach my $topicName ($db->getKeys()) {
    my $topicObj = $db->fastget($topicName);
    my $form = $topicObj->fastget("form");
    next unless $form;
    $form = $topicObj->fastget($form);

    # get topic types
    my $topicType = $form->fastget("TopicType");
    next unless $topicType;

    foreach my $type (split(/,/,$topicType)) {
      $type =~ s/^\s+//go;
      $type =~ s/\s+$//go;
      $this->{topicTypes}{$type} = 1;
    }

    # get all categories of this topic
    my $cats = $this->getCategoriesOfTopic($topicObj);

    if ($topicType =~ /\bCategory\b/) {
      # this topic is a category in itself
      #writeDebug("found category '$topicName'");
      my $category = $this->getCategory($topicName);
      $category = $this->createCategory($topicName) unless $category;

      if ($cats) {
        $category->setParents(@$cats);
      } else {
        $category->setParents('TOP');
      }

      my $usage = $form->fastget("Usage");
      my $summary = $form->fastget("Summary") || '';
      my $title = $form->fastget("Title") || $topicName;
      $category->setUsage($usage);
      $category->setSummary($summary);
      $category->setTitle($title);

    } else {
      # process all categories of this topic and add the topic to the category
      #writeDebug("found categorized topic $topicName");
      if ($cats) {
        foreach my $name (@$cats) {
          #writeDebug("adding it to category $name");
          my $category = $this->getCategory($name);
          $category = $this->createCategory($name) unless $category;
          $category->addTopic($topicName);
        }
      } else {
        #writeDebug("no cats found for $topicName");
      }
    }
  }

  # init nested structures
  foreach my $category ($this->getCategories()) {
    $category->init();
  }

  if (DEBUG) {
    foreach my $category ($this->getCategories()) {
      my $text = "$category->{name}:";
      foreach my $child ($category->getChildren()) {
	$text .= " $child->{name}";
      }
      #writeDebug($text);
    }
  }
}

################################################################################
sub getCategoriesOfTopic {
  my ($this, $topic) = @_;

  # allow topicName or topicObj
  my $topicObj;
  if (ref($topic)) {
    $topicObj = $topic;
  } else {
    my $db = TWiki::Plugins::DBCachePlugin::Core::getDB($this->{web});
    $topicObj = $db->fastget($topic);
  }
  return undef unless $topicObj;

  #writeDebug("getCategoriesOfTopic(".$topicObj->fastget('topic').")");

  my $form = $topicObj->fastget("form");
  return undef unless $form;
  $form = $topicObj->fastget($form);

  # get typed topics
  my $topicType = $form->fastget("TopicType");
  return undef unless $topicType;

  my $catFields = $this->getCatFields(split(/,/,$topicType));
  return undef unless $catFields;

  # get all categories in all category formfields
  my %cats;
  my $found = 0;
  foreach my $catField (@$catFields) {
    # get category formfield
    #writeDebug("looking up '$catField'");
    my $cats = $form->fastget($catField);
    next unless $cats;
    #writeDebug("$catField=$cats");
    foreach my $cat (split(/,/, $cats)) {
      $cat =~ s/^\s+//go;
      $cat =~ s/\s+$//go;
      $cats{$cat} = 1;
      $found = 1;
    }
  }
  return undef unless $found;
  my @cats = sort keys %cats;
  return \@cats;
}

################################################################################
sub getTopicTypes {
  my $this = shift;

  return keys %{$this->{topicTypes}};
}

################################################################################
# get names of category formfields of a topictype
sub getCatFields {
  my ($this, @topicTypes) = @_;

  #writeDebug("called getCatFields(".join(',',@topicTypes).")");

  my %allCatFields;
  my $found = 0;
  foreach my $topicType (@topicTypes) {
    $topicType =~ s/^\s+//go;
    $topicType =~ s/\s+$//go;

    # lookup cache
    #writeDebug("looking up '$topicType' in cache");
    my $catFields = $this->{_catFields}{$topicType};
    if (defined($catFields)) {
      $found = 1;
      foreach my $cat (@$catFields) {
        $allCatFields{$cat} = 1;
      }
      #writeDebug("... found");
      next;
    }
    #writeDebug("looking up form definition for $topicType");

    # looup form definition -> ASSUMPTION: TopicTypes must be TWikiForms too
    my $db = TWiki::Plugins::DBCachePlugin::Core::getDB($this->{web});
    my $formDef = $db->fastget($topicType);
    next unless $formDef;

    # check if this is a TopicStub
    my $form = $formDef->fastget('form');
    next unless $form; # woops got no form
    $form = $formDef->fastget($form);
    my $type = $form->fastget('TopicType');
    #writeDebug("type=$type");

    if ($type =~ /\bTopicStub\b/) {
      #writeDebug("reading stub");
      # this is a TopicStub, lookup the target
      my ($targetWeb, $targetTopic) = 
        TWiki::Func::normalizeWebTopicName($this->{web}, $form->fastget('Target'));

      $db = TWiki::Plugins::DBCachePlugin::Core::getDB($targetWeb);
      $formDef = $db->fastget($targetTopic);
      next unless $formDef;# never reach
    }

    # parse in cat fields
    @$catFields = ();

    my $text = $formDef->fastget('text');
    my $inBlock = 0;
    $text =~ s/\r//g;
    $text =~ s/\\\n//g; # remove trailing '\' and join continuation lines
    # | *Name:* | *Type:* | *Size:* | *Value:*  | *Tooltip message:* | *Attributes:* |
    # Tooltip and attributes are optional
    foreach my $line ( split( /\n/, $text ) ) {
      if ($line =~ /^\s*\|.*Name[^|]*\|.*Type[^|]*\|.*Size[^|]*\|/) {
        $inBlock = 1;
        next;
      }
      if ($inBlock && $line =~ s/^\s*\|\s*//) {
        $line =~ s/\\\|/\007/g; # protect \| from split
        my ($title, $type, $size, $vals) =
          map { s/\007/|/g; $_ } split( /\s*\|\s*/, $line );
        $type ||= '';
        $type = lc $type;
        $type =~ s/^\s*//go;
        $type =~ s/\s*$//go;
        next if !$title or $type ne 'cat';
        $title =~ s/<nop>//go;
        push @$catFields, $title;
      } else {
        $inBlock = 0;
      }
    }

    # cache
    #writeDebug("setting cache for '$topicType' to ".join(',',@$catFields));
    $this->{_catFields}{$topicType} = $catFields;
    foreach my $cat (@$catFields) {
      $allCatFields{$cat} = 1;
    }
  }
  $allCatFields{Category} = 1 unless $found; # default
  my @allCatFields = sort keys %allCatFields;

  #writeDebug("... result=".join(",",@allCatFields));

  return \@allCatFields;
}


###############################################################################
sub getCategories {
  my $this = shift;
  return values %{$this->{categories}}
}

###############################################################################
sub getCategory {
  my ($this, $name) = @_;
  return $this->{categories}{$name};
}

###############################################################################
sub setCategory {
  my ($this, $name, $cat) = @_;
  $this->{categories}{$name} = $cat
}

###############################################################################
sub createCategory {
  return new TWiki::Plugins::ClassificationPlugin::Category(@_);
}

###############################################################################
# static
sub inlineError {
  return '<span class="twikiAlert">' . $_[0] . '</span>' ;
}

###############################################################################
sub toHTML {
  my ($this, $params) = @_;

  #writeDebug("called toHTML");

  my $nrCalls = 0;
  my $top = $params->{top} || 'TOP';
  my $header = $params->{header} || '';
  my $footer = $params->{footer} || '';

  my $result = '';
  foreach my $name (split(/,\s*/,$top)) {
    #writeDebug("searching for category '$name'");
    my $category = $this->getCategory($name);
    next unless $category;
    #writeDebug("found category ".$category->{name});
    $result .= $category->toHTML($params, \$nrCalls);
  }

  #writeDebug("result=$result");
  #writeDebug("done toHTML");

  return $header.$result.$footer;
}

1;
