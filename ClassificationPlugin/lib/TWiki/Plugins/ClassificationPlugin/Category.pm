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

package TWiki::Plugins::ClassificationPlugin::Category;

use strict;
sub DEBUG { 0; }

###############################################################################
# static
sub writeDebug {
  #&TWiki::Func::writeDebug('- ClassificationPlugin - '.$_[0]) if DEBUG;
  print STDERR '- ClassificationPlugin::Category - '.$_[0]."\n" if DEBUG;
}

################################################################################
# constructor
sub new {
  my $class = shift;
  my $hierarchy = shift;
  my $name = shift;

  my $this = {
    name=>$name,
    id=>$hierarchy->{idCounter}++,
    hierarchy=>$hierarchy,
    summary=>'',
    title=>$name,
    @_
  };
  $this->{gotUpdate} = 1;

  $this = bless($this, $class);

  # register to hierarchy
  $hierarchy->setCategory($name, $this);

  writeDebug("new category name=$this->{name} title=$this->{title} web=$hierarchy->{web}"); 

  return $this;
}

###############################################################################
# destructor
sub DESTROY {
  my $this = shift;

  #writeDebug("called DESTROY for category $this->{name}");

  # breaking cyclic references
  undef $this->{parents};
  undef $this->{children};
  undef $this->{topics};
  undef $this->{hierarchy};
  undef $this->{_subsumes};
  undef $this->{_contains};
  undef $this->{_nrLeafs};
  undef $this->{_isCyclic};
  undef $this->{_perms};
}

###############################################################################
sub init {
  my $this = shift;

  foreach my $name (keys %{$this->{parents}}) {
    my $parent = $this->{parents}{$name};

    # make sure the parents are pointers, not the category names
    unless (ref($parent)) {
      $parent = $this->{hierarchy}->getCategory($name);
      if ($parent) {
        $this->{parents}{$name} = $parent;
      } else {
        delete $this->{parents}{$name};
      }
    }

    # establish child relation
    $parent->addChild($this) if $parent;
  }

  $this->{gotUpdate} = 1;
}

###############################################################################
sub countLeafs {
  my $this = shift;
	
  my $nrLeafs = $this->{_nrLeafs};

  unless (defined $nrLeafs) {
    #writeDebug("counting leafs of $this->{name}");
    $nrLeafs = scalar($this->getLeafs());
    $this->{_nrLeafs} = $nrLeafs;
    $this->{gotUpdate} = 1;
  }

  return $nrLeafs;
}

###############################################################################
sub getLeafs {
  my ($this, $result, $seen) = @_;

  $seen ||= {};
  $result ||= {};

  return keys %$result if $seen->{$this};
  $seen->{$this} = 1;

  foreach my $topic ($this->getTopics()) {
    $result->{$topic} = 1;
  }

  foreach my $child ($this->getChildren()) {
    $child->getLeafs($result, $seen);
  }

  return keys %$result;
}

###############################################################################
sub distance {
  my ($this, $that) = @_;

  return $this->{hierarchy}->catDistance($this, $that);
}

###############################################################################
sub subsumes {
  my ($this, $that) = @_;

  return $this->{hierarchy}->subsumes($this, $that);
}

###############################################################################
# returns 1 if the given topic is in the current category or any sub-category
sub contains {
  my ($this, $topic, $seen) = @_;

  my $result = $this->{_contains}{$topic};
  return $result if defined $result;

  $result = 0;
  my $hierarchy = $this->{hierarchy};
  my $cats = $hierarchy->getCategoriesOfTopic($topic);
  foreach my $cat (keys %$cats) {
    #writeDebug("checking $cat");
    $result = $hierarchy->subsumes($this, $cat);
    last if $result;
  }
  #writeDebug("called contains($this->{name}, $topic) = $result");
  
  # cache
  $this->{_contains}{$topic} = $result;
  $this->{gotUpdate} = 1;
  return $result;
}

###############################################################################
sub setParents {
  my $this = shift;

  #writeDebug("called $this->{name}->setParents(@_)");
  foreach my $name (@_) {
    my $parent = $this->{hierarchy}->getCategory($name) || 1;
    $this->{parents}{$name} = $parent;
  }
  $this->{gotUpdate} = 1;
}

###############################################################################
sub getParents {
  my $this = shift;
  return values %{$this->{parents}};
}

###############################################################################
# register a topic in that category
sub addTopic {
  my ($this, $topic) = @_;

  #writeDebug("called addTopic($topic");
  $this->{topics}{$topic} = 1;
}

###############################################################################
sub getTopics {
  my $this = shift;

  return keys %{$this->{topics}};
}

###############################################################################
# register a subcategory
sub addChild {
  my ($this, $category) = @_;

  #writeDebug("called $this->{name}->addChild($category->{name})");
  $this->{children}{$category->{name}} = $category;
  $this->{gotUpdate} = 1;
}

###############################################################################
sub getChildren {
  my $this = shift;
  return values %{$this->{children}};
}

###############################################################################
sub setSummary {
  my ($this, $summary) = @_;
  $summary = TWiki::urlDecode($summary);
  $this->{summary} = $summary;
  $this->{gotUpdate} = 1;
  return $summary;
}

###############################################################################
sub setTitle {
  my ($this, $title) = @_;
  $title = TWiki::urlDecode($title);
  $this->{title} = $title;
  $this->{gotUpdate} = 1;
  return $title;
}

###############################################################################
sub isCyclic {
  my $this = shift;

  my $result = $this->{_isCyclic};
  return $result if defined $result;

  $result = 0;
  foreach my $child ($this->getChildren()) {
    $result = $child->subsumes($this);
    last if $result;
  }
  
  # cache
  $this->{_isCyclic} = $result;
  $this->{gotUpdate} = 1;
  return $result;
}

###############################################################################
sub checkAccessPermission {
  my ($this, $user, $type, $seen) = @_;

  return 1 if $this->{name} =~ /^(TopCategory|BottomCategory)$/;

  $type ||= 'VIEW';
  $seen ||= {};

  # prevent infinit recursions
  return 0 if $seen->{$this};
  $seen->{$this} = 1;

  # normalize calling parameter not to trash the cache
  $user = TWiki::Func::getWikiName($user);

  # lookup cache
  my $access = $this->{_perms}{$type}{$user};

  unless (defined $access) {
    my $topic = $this->{name};
    my $web = $this->{hierarchy}->{web};
    #writeDebug("checking $type access to category $web.$topic for $user");
    $access = TWiki::Func::checkAccessPermission($type, $user, undef, $topic, $web);
  
    if ($access) {
      # recurse til access granted
      foreach my $parent (values %{$this->{parents}}) {
        next if $parent->{name} eq 'TopCategory';
        $access = $parent->checkAccessPermission($user, $type, $seen);
        last if $access;
      }
    }

    # cache result
    $this->{_perms}{$type}{$user} = $access;
  }

  return $access;
}

###############################################################################
# get all preferences, merged with those from parent categories
sub getPreferences {
}

###############################################################################
sub toHTML {
  my ($this, $params, $nrCalls, $index, $nrSiblings, $seen, $depth) = @_;

  $depth ||= 0;

  my $maxDepth = $params->{depth};
  return '' if $maxDepth && $depth >= $maxDepth;

  $index ||= 1;
  $nrSiblings ||= 0;
  $seen ||= {};
  return '' if $seen->{$this};
  $seen->{$this} = 1;

  return '' unless $this->checkAccessPermission();

  my $subResult = '';
  my $header = $params->{header} || '';
  my $footer = $params->{footer} || '';
  my $format = $params->{format} || '<ul><li>$link ($count) $children</li></ul>';

  #writeDebug("toHTML() nrCalls=$$nrCalls, name=$this->{name}");

  # format sub-categories
  my @children = sort {$a->{name} cmp $b->{name}} $this->getChildren();
  my $nrChildren = @children;
  my $childIndex = 1;
  foreach my $child (@children) {
    $subResult .= $child->toHTML($params, $nrCalls, $childIndex, $nrChildren, $seen, $depth+1);
    $childIndex++;
  }
  $seen->{$this} = 0;

  my $minDepth = $params->{mindepth};
  return $subResult 
    if $minDepth && $depth <= $minDepth;

  return $subResult
    if defined $params->{exclude} && $this->{name} =~ /^($params->{exclude})$/;
  return $subResult
    if defined $params->{include} && $this->{name} !~ /^($params->{include})$/;

  my $nrLeafs = $this->countLeafs();
  return $subResult
    if defined $params->{hidenull} && $params->{hidenull} eq 'on' && !$nrLeafs;
  return $subResult
    if defined $params->{duplicates} && $params->{duplicates} eq 'off' && $params->{seen}{$this->{name}};

  $params->{seen}{$this->{name}} = 1;

  my $nrTopics = scalar(keys %{$this->{topics}});
  my $nrSubcats = scalar(keys %{$this->{children}});
  my $isCyclic = 0;
  $isCyclic = $this->isCyclic() if $format =~ /\$cyclic/;

  $subResult = $header.$subResult.$footer if $subResult;

  return TWiki::Plugins::ClassificationPlugin::Core::expandVariables($format, 
    'link'=>($this->{name} =~ /^(TopCategory|BottomCategory)$/)?
      "<b>$this->{title}</b>":
      "[[$this->{hierarchy}->{web}.$this->{name}][$this->{title}]]",
    'url'=>($this->{name} =~ /^(TopCategory|BottomCategory)$/)?"":
      '%SCRIPTURL{"view"}%/'."$this->{hierarchy}->{web}/$this->{name}",
    'web'=>$this->{hierarchy}->{web}, 
    'topic'=>$this->{name},
    'name'=>$this->{name},
    'summary'=>$this->{summary},
    'title'=>$this->{title},
    'children'=>$subResult,
    'siblings'=>$nrSiblings,
    'count'=>$nrTopics,
    'index'=>$index,
    'subcats'=>$nrSubcats,
    'call'=>$$nrCalls++,
    'leafs'=>$nrLeafs,
    'cyclic'=>$isCyclic,
    'id'=>$this->{id},
  );
}

1;
