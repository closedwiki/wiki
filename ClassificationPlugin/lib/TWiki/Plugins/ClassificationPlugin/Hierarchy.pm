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

package TWiki::Plugins::ClassificationPlugin::Hierarchy;

use strict;
use TWiki::Plugins::DBCachePlugin::Core;
use TWiki::Plugins::ClassificationPlugin::Category;
use Storable;

use constant OBJECTVERSION => 0.42;
use constant DEBUG => 0; # toggle me

###############################################################################
# static
sub writeDebug {
  #&TWiki::Func::writeDebug('- ClassificationPlugin - '.$_[0]) if DEBUG;
  print STDERR '- ClassificationPlugin::Hierarchy - '.$_[0]."\n" if DEBUG;
}

################################################################################
# static
sub getCacheFile {
  my $web = shift;

  $web =~ s/^\s+//go;
  $web =~ s/\s+$//go;
  $web =~ s/[\/\.]/_/go;

  return TWiki::Func::getWorkArea("ClassificationPlugin").'/'.$web.'.hierarchy';
}

################################################################################
# constructor
sub new {
  my $class = shift;
  my $web = shift;

  #writeDebug("new hierarchy for web $web");
  my $this;
  my $cacheFile = getCacheFile($web);
  
  my $session = $TWiki::Plugins::SESSION;
  my $refresh = '';
  $refresh = $session->{cgiQuery}->param('refresh') || '' if defined $session;
  $refresh = $refresh eq 'on'?1:0;

  unless ($refresh) {
    eval {
      $this = Storable::lock_retrieve($cacheFile);
    };
  }

  if ($this && $this->{_version} == OBJECTVERSION) {
    writeDebug("restored hierarchy object (v$this->{_version}) from $cacheFile");
    return $this;
  } else {
    writeDebug("creating new object");
  }

  $this = {
    web=>$web,
    idCounter=>0,
    @_
  };

  $this = bless($this, $class);
  $this->init();

  $this->{gotUpdate} = 1;
  $this->{_version} = OBJECTVERSION;

  return $this;
}

################################################################################
# does not invalidate this object; it is kept intact to be cached in memory
# in a mod_perl or speedy-cgi setup; we only store it to disk if we updated it 
sub finish {
  my $this = shift;

  my $gotUpdate = $this->{gotUpdate};
  $this->{gotUpdate} = 0;

  foreach my $cat ($this->getCategories()) {
    $gotUpdate ||= $cat->{gotUpdate};
    $cat->{gotUpdate} = 0;
  }

  if ($gotUpdate) {
    writeDebug("saving hierarchy");
    my $cacheFile = getCacheFile($this->{web});
    Storable::lock_store($this, $cacheFile);
  }

}

################################################################################
sub invalidate {
  my $this = shift;

  my $cacheFile = getCacheFile($this->{web});
  writeDebug("invalidating hierarchy in web $this->{web}");
  unlink $cacheFile;
}

################################################################################
# destructor
sub DESTROY {
  my $this = shift;

  foreach my $cat ($this->getCategories()) {
    $cat->DESTROY() if $cat;
  }
  undef $this->{categories};
  undef $this->{_catFields};
  undef $this->{_tagFields};
  undef $this->{_distance};
  undef $this->{_tagIntersection};
  undef $this->{_aclAttribute};
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

    # get all categories of this topic
    my $cats = $this->getCategoriesOfTopic($topicObj);

    if ($topicType =~ /\bCategory\b/) {
      # this topic is a category in itself
      #writeDebug("found category '$topicName'");
      my $cat = $this->getCategory($topicName);
      $cat = $this->createCategory($topicName) unless $cat;

      if ($cats) {
        $cat->setParents(keys %$cats);
      } else {
        $cat->setParents('TopCategory');
      }

      my $summary = $form->fastget("Summary") || '';
      my $title = $form->fastget("TopicTitle") || $topicName;
      $cat->setSummary($summary);
      $cat->setTitle($title);

    } else {
      # process all categories of this topic and add the topic to the category
      writeDebug("found categorized topic $topicName");
      if ($cats) {
        foreach my $name (keys %$cats) {
          writeDebug("adding it to category $name");
          my $cat = $this->getCategory($name);
          $cat = $this->createCategory($name) unless $cat;
          $cat->addTopic($topicName);
        }
      } else {
        #writeDebug("no cats found for $topicName");
      }
    }
  }

  writeDebug("checking for default categories");
  $this->createCategory('TopCategory', title=>'TOP')
    unless defined $this->getCategory('TopCategory'); ; # every hierarchy has one top node

  $this->createCategory('BottomCategory', title=>'BOTTOM')
    unless defined $this->getCategory('BottomCategory');; # every hierarchy has one BOTTOM node

  # init nested structures
  foreach my $cat ($this->getCategories()) {
    $cat->init();
  }

  # compute distances
  $this->computeDistance();

  if (0) {
    foreach my $cat ($this->getCategories()) {
      my $text = "$cat->{name}:";
      foreach my $child ($cat->getChildren()) {
	$text .= " $child->{name}";
      }
      writeDebug($text);
    }
    $this->_printDistanceMatrix();
  }
}

################################################################################
sub _printDistanceMatrix {
  return unless DEBUG;

  my ($this, $distance) = @_;

  $distance ||= $this->{_distance};

  foreach my $catName1 (sort $this->getCategoryNames()) {
    my $cat1 = $this->{categories}{$catName1};
    my $catId1 = $cat1->{id};
    foreach my $catName2 (sort $this->getCategoryNames()) {
      my $cat2 = $this->{categories}{$catName2};
      my $catId2 = $cat2->{id};
      my $distance =  $$distance[$catId1][$catId2];
      next unless $distance;
      my ($min, $max) = @$distance;
      writeDebug("distance($catName1/$catId1, $catName2/$catId2) = $min,$max");
    }
  }
}

################################################################################
# computes the distance between all categories using a modified floyd-warshall
# algorithm for transitive closures
sub computeDistance {
  my $this = shift;

  writeDebug("start computeDistance");

  # init matrix
  my @distance;
  my $bottomCategory = $this->getCategory('BottomCategory');
  my $bottomId = $bottomCategory->{id};

  my %seen = ();
  for my $cat ($this->getCategories()) {
    my $id = $cat->{id};
    $seen{$id} = $cat->{name};
    @{$distance[$id][$id]} = (0,0); # diagonal

    my @children = $cat->getChildren();
    if (@children) {
      foreach my $child (@children) {
        @{$distance[$id][$child->{id}]} = (1,1); # direct contectedness
      }
    } else {
      unless ($id == $bottomId) { # bottom
        @{$distance[$id][$bottomId]} = (1, 1); # leave nodes
      }
    }
  }

  # floyd-warshall algorithm for transitive closure
  # used to computing min- and max distances, reused in
  # subsumption and partof relations
  my $maxId = $this->{idCounter};
  #writeDebug("maxId=$maxId");
  foreach my $catIId (0..$maxId) {

    foreach my $catJId (0..$maxId) {
      next if $catIId == $catJId; # skip current row

      my $distIJ = $distance[$catIId][$catJId];

      foreach my $catKId (0..$maxId) {
        next if $catKId == $catIId; # skip current row

        my $distIK = $distance[$catIId][$catKId];
        next unless $distIK;

        my $distKJ = $distance[$catKId][$catJId];
        next unless $distKJ;

        my $minSum = $$distIK[0]+$$distKJ[0];
        my $maxSum = $$distIK[1]+$$distKJ[1];

        if (!$distIJ) {
          @$distIJ = ($minSum, $maxSum);
        } else {

          $$distIJ[0] = $minSum if $$distIJ[0] > $minSum;
          $$distIJ[1] = $maxSum if $$distIJ[1] < $maxSum;

        }
      }
    }
  }

  # fill other half of the matrix, the reverse relation,
  # we are using qubic memory already anyway
  for my $id1 (0..$maxId) {
    for my $id2 (0..$maxId) {
      next if $id1 == $id2;
      my $dist = $distance[$id1][$id2];
      next unless $dist;
      $distance[$id2][$id1][0] = -$$dist[0];
      $distance[$id2][$id1][1] = -$$dist[1];
    }
  }

  $this->{_distance} = \@distance;
  $this->{gotUpdate} = 1;

  writeDebug("stop computeDistance");
}

################################################################################
# this computes the distance (min and max) between two categories or a topic
# and a category or between two topics. if a non-category topic is under
# consideration then all of its categories are measured against each other
# while computing the overall minimal and maximal distances.  so simplest case
# is measuring the distance between two categories; the most general case is
# computing the min and max distance between two sets of categories.
# returns a list (min, max)
sub distance {
  my ($this, $topic1, $topic2) = @_;

  #writeDebug("called distance($topic1, $topic2)");

  my %catSet1 = ();
  my %catSet2 = ();

  # if topic1/topic2 are of type Category then they are the objects themselves
  # to be taken under consideration

  # check topic1
  #writeDebug("checking topic1");
  my $catObj = $this->getCategory($topic1);
  if ($catObj) { # known category
    $catSet1{$topic1} = $catObj->{id};
  } else {
    my $cats = $this->getCategoriesOfTopic($topic1);
    return undef unless $cats; # no categories, no distance
    foreach my $name (keys %$cats) {
      $catObj = $this->getCategory($name);
      $catSet1{$name} = $catObj->{id} if $catObj;
    }
  }

  # check topic2
  #writeDebug("checking topic2");
  $catObj = $this->getCategory($topic2);
  if ($catObj) { # known category
    $catSet2{$topic2} = $catObj->{id};
  } else {
    my $cats = $this->getCategoriesOfTopic($topic2);
    return undef unless $cats; # no categories, no distance
    foreach my $name (keys %$cats) {
      $catObj = $this->getCategory($name);
      $catSet2{$name} = $catObj->{id} if $catObj
    }
  }

  if (DEBUG) {
    writeDebug("catSet1 = ".join(',', sort keys %catSet1));
    writeDebug("catSet2 = ".join(',', sort keys %catSet2));
  }

  # gather the min and max distances between the two category sets
  my ($min, $max);
  foreach my $id1 (values %catSet1) {
    foreach my $id2 (values %catSet2) {
      my $dist = $this->{_distance}[$id1][$id2];
      next unless $dist;
      $min = abs($dist->[0]) if !defined($min) || abs($min) > abs($dist->[0]);
      $max = abs($dist->[1]) if !defined($max) || abs($max) < abs($dist->[1]);
    }
  }

  # just to make sure
  $min = $max unless defined $min;
  $max = $min unless defined $max;

  # both sets aren't connected
  return undef unless defined($min);

  #writeDebug("min=$min, max=$max");

  return [$min, $max];
}

################################################################################
# fast lookup of the distance between two categories
sub catDistance {
  my ($this, $cat1, $cat2) = @_;

  my $id1;
  my $id2;

  if (ref($cat1)) {
    $id1 = $cat1->{id};
  } else {
    my $catObj = $this->getCategory($cat1);
    return undef unless defined $catObj;
    $id1 = $catObj->{id};
  }

  if (ref($cat2)) {
    $id2 = $cat2->{id};
  } else {
    my $catObj = $this->getCategory($cat2);
    return undef unless defined $catObj;
    $id2 = $catObj->{id};
  }

  return $this->{_distance}[$id1][$id2];
}

################################################################################
sub computeCoocurrence {
  my $this = shift;

  writeDebug("called computeCooccurrence()");

  my $coocc = {};
  my $db = TWiki::Plugins::DBCachePlugin::Core::getDB($this->{web});

  # loop over all topics and collect all cooccurence information
  foreach my $topic ($db->getKeys()) {
    my $topicObj = $db->fastget($topic);
    my $form = $topicObj->fastget("form");
    next unless $form;

    $form = $topicObj->fastget($form);
    next unless $form;

    my $tags = $form->fastget("Tag");
    next unless $tags;

    my @tags = map {$_ =~ s/^\s+//go; $_ =~ s/\s+$//go; $_} split(/\s*,\s*/, $tags);
    my $length = scalar(@tags);
    next unless $length > 0;

    for (my $i = 0; $i < $length; $i++) {
      my $tagI = $tags[$i];
      for (my $j = $i+1; $j < $length; $j++) {
        my $tagJ = $tags[$j];
        next if $tagI eq $tagJ;
        $$coocc{$tagI}{$tagJ}++;
      }
    }
  }

  # reflexivity
  my @tags = keys %{$coocc};
  my $length = scalar(@tags);
  for (my $i = 0; $i < $length; $i++) {
    my $tagI = $tags[$i];
    for (my $j = 0; $j < $length; $j++) {
      my $tagJ = $tags[$j];
      next if $tagI eq $tagJ;
      my $value = $$coocc{$tagI}{$tagJ} || $$coocc{$tagI}{$tagJ};
      next unless $value;
      $$coocc{$tagI}{$tagJ} = $$coocc{$tagJ}{$tagI} = $value;
    }
  }

  if (0) {
    foreach my $tagI (sort keys %{$coocc}) {
      foreach my $tagJ (sort keys %{$$coocc{$tagI}}) {
        writeDebug("'$tagI' cooccurs with '$tagJ' $$coocc{$tagI}{$tagJ} times");
      }
    }
  }

  # cache
  $this->{_coOccurrence} = $coocc;
  $this->{gotUpdate} = 1;

  writeDebug("done computeCooccurrence()");

  return $coocc;
}

################################################################################
# compute the cooccurrence of all tags with each other. this is a 2-dimensional
# matrix of integers. each cell's integer indicates how often one tag cooccurred
# with another.
sub getCooccurrence {
  my ($this, $tag1, $tag2) = @_;

  my $coocc = $this->{_coOccurrence} || $this->computeCoocurrence();

  # mode 1: return full cooccurrence matrix
  return $coocc unless defined($tag1);

  # mode 2: return a hash of tags coocurring with tag1
  return $$coocc{$tag1} unless defined($tag2);

  # mode 3: return coocurrence of tag1 and tag2
  return $$coocc{$tag1}{$tag2};
}

################################################################################
# find all topics that use the same set of tags
# returns a hash of all topics that use intersecting tags.
# hash entries are indexed by topic names. each hash entry
# is of the format
# {
#   tags => @tags,
#   size => scalar(@tags)
# }
# the intersection size is cached to ease sorting later on.
sub getTagIntersection {
  my ($this, $thisTopic) = @_;

  # lookup cache
  my $tagIntersection = $this->{_tagIntersection}{$thisTopic};
  return $tagIntersection if defined $tagIntersection;

  $tagIntersection ||= {};

  # get current tags
  my $db = TWiki::Plugins::DBCachePlugin::Core::getDB($this->{web});
  my $thisTopicObj = $db->fastget($thisTopic);
  return undef unless $thisTopicObj;

  my $thisForm = $thisTopicObj->fastget("form");
  return undef unless $thisForm;

  $thisForm = $thisTopicObj->fastget($thisForm);
  my $tags = $thisForm->fastget('Tag');
  return undef unless $tags;

  # create initial tag hash
  my %thisTagHash = ();
  foreach my $tag (split(/\s*,\s*/,$tags)) {
    $tag =~ s/^\s+//go;
    $tag =~ s/\s+$//go;
    $thisTagHash{$tag} = 1;
  }

  # loop over all topics and collect all intersecting topics
  foreach my $topic ($db->getKeys()) {
    next if $topic eq $thisTopic;

    my $topicObj = $db->fastget($topic);
    my $form = $topicObj->fastget("form");
    next unless $form;

    $form = $topicObj->fastget($form);
    next unless $form;

    my $tags = $form->fastget("Tag");
    next unless $tags;
    
    # count number of intersecting tags
    my %intersection = %thisTagHash;
    foreach my $tag (split(/\s*,\s*/, $tags)) {
      $tag =~ s/^\s+//go;
      $tag =~ s/\s+$//go;
      $intersection{$tag}++;
    }

    # filter out non-intersecting tags
    foreach my $tag (keys %intersection) {
      my $count = $intersection{$tag};
      delete $intersection{$tag} 
        if $count < 2;
    }

    my @tags = keys %intersection;
    my $size = scalar(@tags);

    $tagIntersection->{$topic} = {
      tags => \@tags,
      size => $size
    };
    #writeDebug("$thisTopic and $topic share $size tags");
  }

  # cache
  $this->{_tagIntersection}{$thisTopic} = $tagIntersection;
  $this->{gotUpdate} = 1;

  return $tagIntersection;
}


################################################################################
# return true if cat1 subsumes cat2 (is an ancestor of)
sub subsumes {
  my ($this, $cat1, $cat2) = @_;

  my $distance = $this->catDistance($cat1, $cat2);

  return 0 unless defined $distance;
  my ($min, undef) = @$distance;

  my $result = ($min >= 0)?1:0;
  #writeDebug("subsumes($cat1, $cat2) = $result");

  return $result;
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

  my $form = $topicObj->fastget("form");
  return undef unless $form;
  $form = $topicObj->fastget($form);

  #writeDebug("getCategoriesOfTopic(".$topicObj->fastget('topic').")");

  # get typed topics
  my $topicType = $form->fastget("TopicType");
  return undef unless $topicType;

  my $catFields = $this->getCatFields(split(/\s*,\s*/,$topicType));
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
    foreach my $cat (split(/\s*,\s*/, $cats)) {
      $cat =~ s/^\s+//go;
      $cat =~ s/\s+$//go;
      $cats{$cat} = 1;
      $found = 1;
    }
  }
  return undef unless $found;
  return \%cats;
}


################################################################################
# get names of category formfields of a topictype
sub getCatFields {
  my ($this, @topicTypes) = @_;

  #writeDebug("called getCatFields(".join(',',@topicTypes).")");

  my %allCatFields;
  my $found = 0;
  foreach my $topicType (@topicTypes) {
    # lookup cache
    #writeDebug("looking up '$topicType' in cache");
    my $catFields = $this->{_catFields}{$topicType};
    if (defined($catFields)) {
      $found = 1;
      foreach my $cat (@$catFields) {
        $allCatFields{$cat} = 1;
      }
      next;
    }
    #writeDebug("looking up form definition for $topicType in web $this->{web}");

    # looup form definition -> ASSUMPTION: TopicTypes must be TWikiForms too
    my $db = TWiki::Plugins::DBCachePlugin::Core::getDB($this->{web});
    my $formDef = $db->fastget($topicType);
    next unless $formDef;

    # check if this is a TopicStub
    my $form = $formDef->fastget('form');
    next unless $form; # woops got no form
    $form = $formDef->fastget($form);
    my $type = $form->fastget('TopicType') || '';
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
    $this->{gotUpdate} = 1;
    foreach my $cat (@$catFields) {
      $allCatFields{$cat} = 1;
    }
  }
  my @allCatFields = sort keys %allCatFields;

  #writeDebug("... result=".join(",",@allCatFields));

  return \@allCatFields;
}

###############################################################################
# get names of tag formfields of a topictype
sub getTagFields {
  my ($this, @topicTypes) = @_;

  #writeDebug("called getTagFields(".join(',',@topicTypes).")");

  my %allTagFields;
  my $found = 0;
  foreach my $topicType (@topicTypes) {
    $topicType =~ s/^\s+//go;
    $topicType =~ s/\s+$//go;

    # lookup cache
    #writeDebug("looking up '$topicType' in cache");
    my $tagFields = $this->{_tagFields}{$topicType};
    if (defined($tagFields)) {
      $found = 1;
      foreach my $tag (@$tagFields) {
        $allTagFields{$tag} = 1;
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

    # parse in tag fields
    @$tagFields = ();

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
        next if !$title or $type ne 'tag';
        $title =~ s/<nop>//go;
        push @$tagFields, $title;
      } else {
        $inBlock = 0;
      }
    }

    # cache
    #writeDebug("setting cache for '$topicType' to ".join(',',@$tagFields));
    $this->{_tagFields}{$topicType} = $tagFields;
    $this->{gotUpdate} = 1;
    foreach my $tag (@$tagFields) {
      $allTagFields{$tag} = 1;
    }
  }
  $allTagFields{Tag} = 1 unless $found; # default
  my @allTagFields = sort keys %allTagFields;

  #writeDebug("... result=".join(",",@allTagFields));

  return \@allTagFields;
}

###############################################################################
sub getCategories {
  return values %{$_[0]->{categories}}
}

###############################################################################
sub getCategoryNames {
  return keys %{$_[0]->{categories}}
}


###############################################################################
sub getCategory {
  return $_[0]->{categories}{$_[1]};
}

###############################################################################
sub setCategory {
  $_[0]->{categories}{$_[1]} = $_[2];
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

  #writeDebug("called toHTML for hierarchy in '$this->{web}'");

  my $nrCalls = 0;
  my $top = $params->{top} || 'TopCategory';
  my $header = $params->{header} || '';
  my $footer = $params->{footer} || '';

  my $result = '';
  foreach my $name (split(/\s*,\s*/,$top)) {
    #writeDebug("searching for category $name");
    my $cat = $this->getCategory($name);
    next unless $cat;
    #writeDebug("found category ".$cat->{name});
    $result .= $cat->toHTML($params, \$nrCalls);
  }

  #writeDebug("result=$result");
  #writeDebug("done toHTML");

  return $header.$result.$footer;
}

###############################################################################
# get preferences of a set of categories
sub getPreferences {
  my ($this, @cats) = @_;

  my $session = $TWiki::Plugins::SESSION;

  require TWiki::Prefs;
  my $prefs = new TWiki::Prefs($session);

  require TWiki::Prefs::PrefsCache;
  $prefs = new TWiki::Prefs::PrefsCache($prefs, undef, 'WEB'); 
    # SMELL what kind of type do we need

  foreach my $cat (@cats) {
    $cat =~ s/^\s+//go;
    $cat =~ s/\s+$//go;
    my $catObj = $this->getCategory($cat);
    $prefs = $catObj->getPreferences($prefs);
  }

  return $prefs;
}

###############################################################################
sub checkAccessPermission {
  my ($this, $mode, $user, $topic, $order) = @_;

  # get acl attribute
  my $aclAttribute = $this->{_aclAttribute};

  unless (defined $aclAttribute) {
    $aclAttribute = 
      TWiki::Func::getPreferencesValue('CLASSIFICATIONPLUGIN_ACLATTRIBUTE', $this->{web}) || 
      'Category';
    $this->{_aclAttribute} = $aclAttribute;
  }

  # get categories and gather access control lists
  my $db = TWiki::Plugins::DBCachePlugin::Core::getDB($this->{web});
  my $topicObj = $db->fastget($topic);
  return undef unless $topicObj;

  my $form = $topicObj->fastget('form');
  return undef unless $form;

  $form = $topicObj->fastget($form);
  return undef unless $form;

  my $cats = $form->fastget($aclAttribute);
  return undef unless $cats;

  #my $prefs = $this->getPreferences(split(/\s*,\s*/, $cats));

  my $allowed = 1;

  return $allowed;
}

1;
