# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2005-2006 MichaelDaum@WikiRing.com
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
use Error qw( :try );

@TWiki::Plugins::DBCachePlugin::WebDB::ISA = ("TWiki::Contrib::DBCacheContrib");

###############################################################################
sub new {
  my ($class, $web, $cacheName) = @_;

  $cacheName = 'DBCachePluginDB' unless $cacheName;

  my $this = bless($class->SUPER::new($web, $cacheName), $class);
  $this->{_loadTime} = 0;
  $this->{web} = $this->{_web};
  $this->{web} =~ s/\./\//go; 
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

  my $workDir = TWiki::Func::getWorkArea('DBCacheContrib');
  my $web = $this->{web};
  $web =~ s/\//\./go;
  my $cacheFile = "$workDir/$web.$this->{_cachename}";

  return $cacheFile;
}

###############################################################################
sub _getModificationTime {
  my $this = shift;

  my $filename = $this->_getCacheFile();
  my @stat = stat($filename);

  return $stat[9] || $stat[10] || 0;
}

###############################################################################
sub touch {
  my $this = shift;
  
  my $filename = $this->_getCacheFile();

  return utime undef, undef, $filename;
}

###############################################################################
sub isModified {
  my $this = shift;
  
  return 1 if $this->{_loadTime} < $this->_getModificationTime();
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
    $topic->set('web', $this->{web});

    #print STDERR "DEBUG: reloading $topicName\n";

    # createdate
    my ($createDate) = &TWiki::Func::getRevisionInfo($this->{web}, $topicName, 1);
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

  #print STDERR "DEBUG: called dbQuery($theSearch, $theTopics, $theSort, $theReverse) in $this->{web}\n";

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
  my $wikiUserName = TWiki::Func::getWikiUserName();
  my %hits = ();
  if ($theSearch) {
    my $search;
    try {
      $search = new TWiki::Contrib::DBCacheContrib::Search($theSearch);
    } catch Error::Simple with {
      my $error = shift;
    };
    unless ($search) {
      return (undef, undef, "ERROR: can't parse query \"$theSearch\"");
    }
    foreach my $topicName (@topicNames) {
      my $topicObj = $this->fastget($topicName);
      if ($search->matches($topicObj)) {
        if (TWiki::Func::checkAccessPermission('VIEW', $wikiUserName, undef, $topicName, $this->{web})) {
	  $hits{$topicName} = $topicObj;
	}
      }
    }
  } else {
    foreach my $topicName (@topicNames) {
      my $topicObj = $this->fastget($topicName);
      if (TWiki::Func::checkAccessPermission('VIEW', $wikiUserName, undef, $topicName, $this->{web})) {
	$hits{$topicName} = $topicObj if $topicObj;
      }
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
	flexCmp($this->expandPath($hits{$a}, $theSort), $this->expandPath($hits{$b}, $theSort))
      } @topicNames;
    }
    @topicNames = reverse @topicNames if $theReverse eq 'on';
  }
  #print STDERR "DEBUG: result topicNames=@topicNames\n";

  return (\@topicNames, \%hits, undef);
}

###############################################################################
sub flexCmp {

  return $_[0] <=> $_[1] 
    if $_[0] =~ /^[+-]?\d+(\.\d+)?$/ && 
       $_[1] =~ /^[+-]?\d+(\.\d+)?$/;

  return $_[0] cmp $_[1];
}



###############################################################################
sub expandPath {
  my ($this, $theRoot, $thePath) = @_;

  return '' if !$thePath || !$theRoot;
  $thePath =~ s/^\.//o;
  $thePath =~ s/\[([^\]]+)\]/$1/o;

  #print STDERR "DEBUG: expandPath($theRoot, $thePath)\n";

  if ($thePath =~ /^info.author$/) {
    if (defined(&TWiki::Users::getWikiName)) {# TWiki-4.2 onwards
      my $author = $theRoot->fastget('info')->fastget('author');
      my $session = $TWiki::Plugins::SESSION;
      return $session->{users}->getWikiName($author);
    }
  }
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
    #print STDERR "DEBUG: result=$1\n";
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
    my $root;
    my $form = $theRoot->fastget('form');
    $form = $theRoot->fastget($form) if $form;
    $root = $form->fastget($first) if $form;
    $root = $theRoot->fastget($first) unless $root;
    return $this->expandPath($root, $tail) if ref($root);
    return '' unless $root;
    my $field = TWiki::urlDecode($root);
    #print STDERR "DEBUG: result=$field\n";
    return $field;
  }

  if ($thePath =~ /^@([^\.]+)(.*)$/) {
    my $first = $1;
    my $tail = $2;
    my $result = $this->expandPath($theRoot, $first);
    my $root;
    if (ref($result)) {
      $root = $result;
    } else {
      if ($result =~ /^(.*)\.(.*?)$/) {
        my $db = TWiki::Plugins::DBCachePlugin::Core::getDB($1);
        $root = $db->fastget($2);
        return $db->expandPath($root, $tail);
      } else {
        $root = $this->fastget($result); 
      }
    }
    return $this->expandPath($root, $tail)
  }

  if ($thePath =~ /^%/) {
    # SMELL: is topic='' ok?
    $thePath = &TWiki::Func::expandCommonVariables($thePath, '', $this->{web});
    return $this->expandPath($theRoot, $thePath);
  }

  #print STDERR "DEBUG: result is empty\n";
  return '';
}

###############################################################################
1;
