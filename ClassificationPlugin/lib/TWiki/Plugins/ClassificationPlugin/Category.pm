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

package TWiki::Plugins::ClassificationPlugin::Category;

use strict;
use vars qw($idCounter);

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
    id=>$idCounter++,
    hierarchy=>$hierarchy,
    summary=>'',
    title=>$name,
    @_
  };

  $this = bless($this, $class);

  # register to hierarchy
  $hierarchy->setCategory($name, $this);

  return $this;
}

###############################################################################
# destructor
sub DESTROY {
  my $this = shift;

  #writeDebug("called DESTROY for category $this->{name}");

  # breaking cyclic references
  $this->{parents} = ();
  $this->{children} = ();
  $this->{topics} = ();
  $this->{hierarchy} = undef;
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
}

###############################################################################
sub countLeafs {
  my $this = shift;
	
  return $this->{_nrLeafs} if defined $this->{nrLeafs};

  $this->{_nrLeafs} = scalar($this->getTopics());
  foreach my $child ($this->getChildren()) {
    $this->{_nrLeafs} += $child->countLeafs();
  }

  return $this->{_nrLeafs};
}

###############################################################################
# returns 1 if this category subsumes another
sub subsumes {
  my ($this, $that, $seen) = @_;

  my $result = $this->{_subsumes}{$that->{name}};
  return $result if defined $result;

  #writeDebug("subsumes($this->{name}, $that->{name})");
  $result = 0;
  if ($this->{name} eq 'TOP' || 
      $that->{name} eq 'BOTTOM' || 
      $this eq $that) {
    $result = 1;
  } elsif ($that->{name} eq 'TOP') {
    $result = 0;
  } else {
    $seen ||= {};
    unless ($seen->{$this}) {
      $seen->{$this} = 1;
      foreach my $child ($this->getChildren()) {
        #writeDebug("checking child $child->{name}");
        $result = $child->subsumes($that, $seen);
        last if $result;
      }
    }
  }
  #writeDebug("...$result");

  # cache
  $this->{_subsumes}{$that->{name}} = $result;
  return $result;
}

###############################################################################
# return 1 if this category subsumes that or the other way around
sub compatible {
  my ($this, $that) = @_;
  return $this->subsumes($that) || $that->subsumes($this);
}

###############################################################################
# returns 1 if the given topic is in the current category or any sub-category
sub contains {
  my ($this, $topic, $seen) = @_;

  writeDebug("called contains($this->{name}, $topic)");

  my $result = $this->{_contains}{$topic};
  return $result if defined $result;

  if ($this->{topics}{$topic} || $this->{name} eq $topic) {
    $result = 1;
  } else {
    $seen ||= {};
    $result = 0;
    unless ($seen->{$this}) {
      $seen->{$this} = 1;
      foreach my $child ($this->getChildren()) {
        if ($child->contains($topic, $seen)) {
          $result = 1;
          last;
        }
      }
    }
  }

  # cache
  $this->{_contains}{$topic} = $result;
  writeDebug("... $result");
  return $result;
}

###############################################################################
sub setParents {
  my $this = shift;

  writeDebug("called $this->{name}->setParents(@_)");
  foreach my $name (@_) {
    my $parent = $this->{hierarchy}->getCategory($name) || 1;
    $this->{parents}{$name} = $parent;
  }
}

###############################################################################
sub getParents {
  my $this = shift;
  return values %{$this->{parents}};
}

###############################################################################
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
sub addChild {
  my ($this, $category) = @_;

  #writeDebug("called $this->{name}->addChild($category->{name})");
  $this->{children}{$category->{name}} = $category;
}

###############################################################################
sub getChildren {
  my $this = shift;
  return values %{$this->{children}};
}

###############################################################################
sub setUsage { 
  my ($this, $usage) = @_;

  $usage ||= '';
  foreach my $item (split(/,\s/, $usage)) {
    $this->{usage}{$item} = 1;
  }
}

###############################################################################
sub setSummary {
  my ($this, $summary) = @_;
  $summary = TWiki::urlDecode($summary);
  $this->{summary} = $summary;
  return $summary;
}

###############################################################################
sub setTitle {
  my ($this, $title) = @_;
  $title = TWiki::urlDecode($title);
  $this->{title} = $title;
  return $title;
}


###############################################################################
sub isUsedFor {
  my ($this, $usage) = @_;

  return defined($this->{usage}{$usage});
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
  return $result;
}

###############################################################################
sub checkAccessPermission {
  my ($this, $user, $type, $seen) = @_;

return 1;

  return 1 if $this->{name} =~ /^(TOP|BOTTOM)$/;

  $type ||= 'VIEW';
  $seen ||= {};

  # prevent infinit recursions
  return 0 if $seen->{$this};
  $seen->{$this} = 1;

  $user ||= TWiki::Func::getWikiName();

  # lookup cache
  my $access = $this->{_perms}{$type}{$user};

  unless (defined $access) {
    my $topic = $this->{name};
    my $web = $this->{hierarchy}->{web};
    $access = TWiki::Func::checkAccessPermission($type, $user, undef, $topic, $web);
    #writeDebug("checkAccessPermission($type,$user,$web.$topic) = $access");
  
    if ($access) {
      # recurse til access granted
      foreach my $parent (values %{$this->{parents}}) {
        next if $parent->{name} eq 'TOP';
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
sub toHTML {
  my ($this, $params, $nrCalls, $index, $nrSiblings, $seen) = @_;

  return '' unless $this->checkAccessPermission();

  $index ||= 1;
  $nrSiblings ||= 0;
  $seen ||= {};
  return '' if $seen->{$this};
  $seen->{$this} = 1;
  my $subResult = '';
  my $header = $params->{header} || '';
  my $footer = $params->{footer} || '';

  writeDebug("toHTML() nrCalls=$$nrCalls, name=$this->{name}");

  # format sub-categories
  my @children = sort {$a->{name} cmp $b->{name}} $this->getChildren();
  my $nrChildren = @children;
  my $childIndex = 1;
  foreach my $child (@children) {
    $subResult .= $child->toHTML($params, $nrCalls, $childIndex, $nrChildren, $seen);
    $childIndex++;
  }
  $seen->{$this} = 0;

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
  my $format = $params->{format} || '<ul><li>$link ($count) $children</li></ul>';
  $isCyclic = $this->isCyclic() if $format =~ /\$cyclic/;

  $subResult = $header.$subResult.$footer if $subResult;

  return TWiki::Plugins::ClassificationPlugin::Core::expandVariables($format, 
    'link'=>($this->{name} =~ /^(TOP|BOTTOM)$/)?
      "<b>$this->{name}</b>":
      "[[$this->{hierarchy}->{web}.$this->{name}][$this->{name}]]",
    'url'=>($this->{name} =~ /^(TOP|BOTTOM)$/)?"":
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
