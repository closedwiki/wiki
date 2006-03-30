# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2005-2006 Michael Daum <micha@nats.informatik.uni-hamburg.de>
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

package TWiki::Plugins::DBCachePlugin::WebDB;

use strict;
use TWiki::Contrib::DBCacheContrib;
use TWiki::Plugins::DBCachePlugin;
use TWiki::Attrs;

@TWiki::Plugins::DBCachePlugin::WebDB::ISA = ("TWiki::Contrib::DBCacheContrib");

###############################################################################
sub new {
  my ($class, $web, $cacheName) = @_;

  $cacheName = '_DBCachePluginDB' unless $cacheName;

  my $this = bless($class->SUPER::new($web, $cacheName), $class);
  $this->{_loadTime} = '';
  return $this;
}

###############################################################################
# cache time we loaded the cacheFile
sub load {
  my $this = shift;
  
  # first load
  my $result = $this->SUPER::load();

  # then get the time stamp
  $this->{_loadTime} = $this->_getModificationTime();

  return $result;
}

###############################################################################
sub _getCacheFile {
  my $this = shift;

  return TWiki::Func::getDataDir() . '/' . 
    $this->{_web} . '/' .  $this->{_cachename};
}

###############################################################################
sub _getModificationTime {
  my $this = shift;
  
  my @stat = stat($this->_getCacheFile());

  return $stat[8] || $stat[9] || $stat[10];
}

###############################################################################
sub touch {
  my $this = shift;

  my $atime = time;
  my $mtime = $atime;
  return utime $atime, $mtime, $this->_getCacheFile();
}

###############################################################################
sub isModified {
  my $this = shift;

  if (!defined $this->{_loadTime} || 
    $this->_getModificationTime() != $this->{_loadTime}) {
    return 1;
  } 
  
  return 0;
}

###############################################################################
# called by superclass when one or more topics had
# to be reloaded from disc.
sub onReload {
  my ($this, $topics) = @_;

  #print STDERR "DEBUG: DBCachePlugin::WebDB - called onReload(@_)\n";

  foreach my $topicName (@$topics) {
    my $topic = $this->fastget($topicName);

    # save web
    $topic->set('web', $this->{_web});

    #print STDERR "DEBUG: reloading $topicName\n";

    # createdate
    my ($createDate) = &TWiki::Func::getRevisionInfo($this->{_web}, $topicName, 1);
    $topic->set('createdate', $createDate);

    # stored procedures
    my $text = $topic->fastget('text');

    # get default section
    my $defaultSection = $text;
    $defaultSection =~ s/.*?%STARTINCLUDE%//s;
    $defaultSection =~ s/%STOPINCLUDE%.*//s;
    #applyGlue($defaultSection);
    $topic->set('_sectiondefault', $defaultSection);

    # get named sections

    # CAUTION: %SECTION will be deleted in the near future. 
    # so please convert all %SECTION to %STARTSECTION

    while($text =~ s/%(?:START)?SECTION{(.*?)}%(.*?)%ENDSECTION{[^}]*?"(.*?)"}%//s) {
      my $attrs = new TWiki::Attrs($1);
      my $name = $attrs->{name} || $attrs->{_DEFAULT} || '';
      my $sectionText = $2;
      $topic->set("_section$name", $sectionText);
    }
  }

  #print STDERR "DEBUG: DBCachePlugin::WebDB - done onReload()\n";
}

###############################################################################
sub getFormField {
  my ($this, $theTopic, $theFormField) = @_;

  my $topicObj = $this->fastget($theTopic);
  return '' unless $topicObj;
  
  my $form = $topicObj->fastget('form');
  return '' unless $form;

  $form = $topicObj->fastget($form);
  my $formfield = $form->fastget($theFormField) || '';
  return TWiki::urlDecode($formfield);
}

###############################################################################
sub dbQuery {
  my ($this, $theSearch, $theTopics, $theSort, $theReverse, $theInclude, $theExclude) = @_;

# TODO return empty result on an emtpy topics list

  $theSort ||= '';
  $theReverse ||= '';
  $theSearch ||= '';

  #print STDERR "DEBUG: called dbQuery($theSearch, $theTopics, $theSort, $theReverse) in $this->{_web}\n";

  # get max hit set
  my @topicNames;
  if ($theTopics && @$theTopics) {
    @topicNames = @$theTopics;
  } else {
    @topicNames = $this->getKeys();
  }
  @topicNames = grep(/$theInclude/, @topicNames) if $theInclude;
  @topicNames = grep(!/$theExclude/, @topicNames) if $theExclude;
  
  # parse & fetch
  my %hits;
  if ($theSearch) {
    my $search = new TWiki::Contrib::DBCacheContrib::Search($theSearch);
    unless ($search) {
      return (undef, undef, "ERROR: can't parse query $theSearch");
    }
    foreach my $topicName (@topicNames) {
      my $topicObj = $this->fastget($topicName);
      if ($search->matches($topicObj)) {
	$hits{$topicName} = $topicObj;
      }
    }
  } else {
    foreach my $topicName (@topicNames) {
      my $topicObj = $this->fastget($topicName);
      $hits{$topicName} = $topicObj if $topicObj;
    }
  }

  # sort
  @topicNames = keys %hits;
  if (@topicNames > 1) {
    if ($theSort eq 'name') {
      @topicNames = sort {$a cmp $b} @topicNames;
    } elsif ($theSort =~ /^created/) {
      @topicNames = sort {
	$this->expandPath($hits{$a}, 'createdate') <=> $this->expandPath($hits{$b}, 'createdate')
      } @topicNames;
    } elsif ($theSort =~ /^modified/) {
      @topicNames = sort {
	$this->expandPath($hits{$a}, 'info.date') <=> $this->expandPath($hits{$b}, 'info.date')
      } @topicNames;
    } else {
      @topicNames = sort {
	$this->expandPath($hits{$a}, $theSort) cmp $this->expandPath($hits{$b}, $theSort)
      } @topicNames;
    }
    @topicNames = reverse @topicNames if $theReverse eq 'on';
  }
  #print STDERR "DEBUG: result topicNames=@topicNames\n";

  return (\@topicNames, \%hits, undef);
}

###############################################################################
sub expandPath {
  my ($this, $theRoot, $thePath) = @_;

  return '' if !$thePath || !$theRoot;
  $thePath =~ s/^\.//o;
  $thePath =~ s/\[([^\]]+)\]/$1/o;

  #print STDERR "DEBUG: expandPath($theRoot, $thePath)\n";
  if ($thePath =~ /^(.*?) and (.*)$/) {
    my $first = $1;
    my $tail = $2;
    my $result1 = $this->expandPath($theRoot, $first);
    return '' unless defined $result1 && $result1 ne '';
    my $result2 = $this->expandPath($theRoot, $tail);
    return '' unless defined $result2 && $result2 ne '';
    return $result1.$result2;
  }
  if ($thePath =~ /^'([^']*)'$/) {
    return $1;
  }
  if ($thePath =~ /^(.*?) or (.*)$/) {
    my $first = $1;
    my $tail = $2;
    my $result = $this->expandPath($theRoot, $first);
    return $result if (defined $result && $result ne '');
    return $this->expandPath($theRoot, $tail);
  }

  if ($thePath =~ m/^(\w+)(.*)$/o) {
    my $first = $1;
    my $tail = $2;
    my $root = $theRoot->fastget($first);
    unless ($root) {
      # try form
      # SMELL: try form _first_
      my $form = $theRoot->fastget('form');
      if ($form) {
	$form = $theRoot->fastget($form);
	$root = $form->fastget($first) if $form;
      }
    }
    return $this->expandPath($root, $tail) if ref($root);
    if ($root) {
      my $field = TWiki::urlDecode($root);
      #print STDERR "DEBUG: result=$field\n";
      return $field;
    }
  }

  if ($thePath =~ /^@([^\.]+)(.*)$/) {
    my $first = $1;
    my $tail = $2;
    my $result = $this->expandPath($theRoot, $first);
    my $root = ref($result)?$result:$this->fastget($result); 
    return $this->expandPath($root, $tail)
  }

  #print STDERR "DEBUG: result is empty\n";
  return '';
}

###############################################################################
1;
