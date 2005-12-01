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

package TWiki::Plugins::DBCachePlugin::WebDB;

use strict;
use TWiki::Contrib::DBCacheContrib;
use TWiki::Plugins::DBCachePlugin;

@TWiki::Plugins::DBCachePlugin::WebDB::ISA = ("TWiki::Contrib::DBCacheContrib");

###############################################################################
sub new {
  my ($class, $web, $cacheName) = @_;

  $cacheName = '_DBCachePluginDB' unless $cacheName;

  my $this = bless($class->SUPER::new($web, $cacheName), $class);
  return $this;
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

    # stored procedures
    my $text = $topic->fastget('text');

    # get default section
    my $defaultSection = $text;
    $defaultSection =~ s/.*?%STARTINCLUDE%//s;
    $defaultSection =~ s/%STOPINCLUDE%.*//s;
    applyGlue($defaultSection);
    $topic->set('_sectiondefault', $defaultSection);

    # get named sections
    while($text =~ s/%SECTION{[^}]*?"(.*?)"}%(.*?)%ENDSECTION{[^}]*?"(.*?)"}%//s) {
      my $name = $1;
      my $sectionText = $2;
      applyGlue($sectionText);
      $topic->set("_section$name", $sectionText);
    }
  }

  #print STDERR "DEBUG: DBCachePlugin::WebDB - done onReload()\n";
}

###############################################################################
# local copy from GluePlugin
sub applyGlue {

  $_[0] =~ s/%~~\s+([A-Z]+{)/%$1/gos;  # %~~
  $_[0] =~ s/\s*[\n\r]+~~~\s+/ /gos;   # ~~~
  $_[0] =~ s/\s*[\n\r]+\*~~\s+//gos;   # *~~
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
  my ($this, $theSearch, $theTopics, $theOrder, $theReverse, $theInclude, $theExclude) = @_;

# TODO return empty result on an emtpy topics list

  $theOrder ||= '';
  $theReverse ||= '';
  $theSearch ||= '';

  #print STDERR "DEBUG: called dbQuery($theSearch, $theTopics, $theOrder, $theReverse) in $this->{_web}\n";

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
    if ($theOrder eq 'name') {
      @topicNames = sort {$a cmp $b} @topicNames;
    } elsif ($theOrder =~ /^created/) {
      @topicNames = sort {
	$this->expandPath($hits{$a}, 'createdate') <=> $this->expandPath($hits{$b}, 'createdate')
      } @topicNames;
    } elsif ($theOrder =~ /^modified/) {
      @topicNames = sort {
	$this->expandPath($hits{$a}, 'info.date') <=> $this->expandPath($hits{$b}, 'info.date')
      } @topicNames;
    } else {
      @topicNames = sort {
	$this->expandPath($hits{$a}, $theOrder) cmp $this->expandPath($hits{$b}, $theOrder)
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
      # TODO: try form FIRST
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
