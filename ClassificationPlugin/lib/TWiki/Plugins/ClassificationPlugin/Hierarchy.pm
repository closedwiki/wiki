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
use Storable;

use constant OBJECTVERSION => 0.1;

sub DEBUG { 1; }

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

  $web =~ s/[\/\.]/_/go;
  return TWiki::Func::getWorkArea("ClassificationPlugin")."/$web.hierarchy";
}

################################################################################
# constructor
sub new {
  my $class = shift;
  my $web = shift;

  #writeDebug("new hierarchy for web $web");
  my $this;
  my $cacheFile = getCacheFile($web);
  
  eval {
    $this = Storable::lock_retrieve($cacheFile);
  };

  if ($this && $this->{_version} == OBJECTVERSION) {
    #writeDebug("restored hierarchy object (v$this->{_version}) from $cacheFile");
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
  $this->createCategory('TOP'); # every hierarchy has one top node
  $this->createCategory('BOTTOM'); # every hierarchy has one BOTTOM node
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
        $cat->setParents('TOP');
      }

      my $summary = $form->fastget("Summary") || '';
      my $title = $form->fastget("Title") || $topicName;
      $cat->setSummary($summary);
      $cat->setTitle($title);

    } else {
      # process all categories of this topic and add the topic to the category
      #writeDebug("found categorized topic $topicName");
      if ($cats) {
        foreach my $name (keys %$cats) {
          #writeDebug("adding it to category $name");
          my $cat = $this->getCategory($name);
          $cat = $this->createCategory($name) unless $cat;
          $cat->addTopic($topicName);
        }
      } else {
        #writeDebug("no cats found for $topicName");
      }
    }
  }

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
    foreach my $cat1 (sort $this->getCategories()) {
      foreach my $cat2 (sort $this->getCategories()) {
        my $distance = $this->catDistance($cat1, $cat2);
        if (defined $distance) {
          my ($min, $max) = @$distance;
          writeDebug("distance($cat1->{name}, $cat2->{name}) = $min,$max");
        }
      }
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

  for my $cat ($this->getCategories()) {
    my $id = $cat->{id};
    @{$distance[$id][$id]} = (0,0); # diagonal

    my @children = $cat->getChildren();
    if (@children) {
      foreach my $child (@children) {
        @{$distance[$id][$child->{id}]} = (1,1); # direct contectedness
      }
    } else {
      unless ($id == 1) { # bottom
        @{$distance[$id][1]} = (1, 1); # leave nodes
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
      next if $distIJ && $$distIJ[0] < 2 && $$distIJ[1] < 2; # already optimal

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
  if ($topic1 eq 'TOP') {
    $catSet1{$topic1} = 0;
  } elsif ($topic1 eq 'BOTTOM') {
    $catSet1{$topic1} = 1;
  } else {
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
  }

  # check topic2
  #writeDebug("checking topic2");
  if ($topic2 eq 'TOP') {
    $catSet2{$topic2} = 0;
  } elsif ($topic2 eq 'BOTTOM') {
    $catSet2{$topic2} = 2;
  } else {
    my $catObj = $this->getCategory($topic2);
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
  }

  if (0) {
    writeDebug("catSet1 = ".join(',', sort keys %catSet1));
    writeDebug("catSet2 = ".join(',', sort keys %catSet2));
  }

  # gather the min and max distances between the two category sets
  my ($min, $max);
  foreach my $id1 (values %catSet1) {
    foreach my $id2 (values %catSet2) {
      my $dist = $this->{_distance}[$id1][$id2];
      next unless $dist;
      $min = $dist->[0] if !defined($min) || $min > $dist->[0];
      $max = $dist->[1] if !defined($max) || $max < $dist->[1];
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
  foreach my $name (split(/\s*,\s*/,$top)) {
    #writeDebug("searching for category '$name'");
    my $cat = $this->getCategory($name);
    next unless $cat;
    #writeDebug("found category ".$cat->{name});
    $result .= $cat->toHTML($params, \$nrCalls);
  }

  #writeDebug("result=$result");
  #writeDebug("done toHTML");

  return $header.$result.$footer;
}



1;
