# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2006 MichaelDaum@WikiRing.com
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

package TWiki::Plugins::FlexWebListPlugin::Core;

use strict;
use vars qw($debug);

$debug = 0; # toggle me

###############################################################################
# static
sub writeDebug {
  &TWiki::Func::writeDebug('- FlexWebListPlugin - '.$_[0]) if $debug;
  #print STDERR '- FlexWebListPlugin - '.$_[0]."\n" if $debug;
}

###############################################################################
# constructor
sub new {
  my $class = shift;
  my $this = bless({}, $class);

  $this->{isDakar} = (defined $TWiki::RELEASE)?1:0; # we could do better
  $this->{webCache} = ();

  return $this;
}

###############################################################################
sub handler {
  my ($this, $args, $currentWeb, $currentTopic) = @_;

  writeDebug("*** called hander($args)");

  # extract parameters
  $this->{webs} = 
    TWiki::Func::extractNameValuePair($args) ||
    TWiki::Func::extractNameValuePair($args, 'webs') || 'public';

  $this->{header} = TWiki::Func::extractNameValuePair($args, 'header') || '';
  $this->{format} = TWiki::Func::extractNameValuePair($args, 'format') || '$web ';
  $this->{footer} = TWiki::Func::extractNameValuePair($args, 'footer') || '';
  $this->{separator} = TWiki::Func::extractNameValuePair($args, 'separator') || '';
  $this->{separator} = '' if $this->{separator} eq 'none';

  $this->{subHeader} = TWiki::Func::extractNameValuePair($args, 'subheader') || $this->{header};
  $this->{subFormat} = TWiki::Func::extractNameValuePair($args, 'subformat') || $this->{format};
  $this->{subFooter} = TWiki::Func::extractNameValuePair($args, 'subfooter') || $this->{footer};
  $this->{subSeparator} = TWiki::Func::extractNameValuePair($args, 'subseparator') || $this->{separator};
  $this->{subSeparator} = '' if $this->{subSeparator} eq 'none';

  $this->{markerFormat} = TWiki::Func::extractNameValuePair($args, 'markerformat') || $this->{format};
  $this->{selection} = TWiki::Func::extractNameValuePair($args, 'selection') || '';
  $this->{marker} = TWiki::Func::extractNameValuePair($args, 'marker') || '';
  $this->{exclude} = TWiki::Func::extractNameValuePair($args, 'exclude') || '';
  $this->{include} = TWiki::Func::extractNameValuePair($args, 'include') || '';
  $this->{subWebs} = TWiki::Func::extractNameValuePair($args, 'subwebs') || 'all';

  $this->{selection} =~ s/\,/ /go;
  $this->{selection} = ' '.$this->{selection}.' ';
  $this->{currentWeb} = $currentWeb;
  $this->{currentTopic} = $currentTopic;
  #writeDebug("include filter=/^($this->{include})\$/") if $this->{include};
  #writeDebug("exclude filter=/^($this->{exclude})\$/") if $this->{exclude};

  
  # compute map
  my $theMap = TWiki::Func::extractNameValuePair($args, 'map') || '';
  $this->{map} = ();
  foreach my $entry (split(/,\s*/, $theMap)) {
    if ($entry =~ /^(.*)=(.*)$/) {
      $this->{map}{$1} = $2;
    }
  }
  
  # compute list
  my %seen;
  my @list = ();
  my @websList = map {s/^\s+//go; s/\s+$//go; s/\./\//go; $_} split(/,\s*/, $this->{webs});
  #writeDebug("websList=".join(',', @websList));
  %{$this->{isExplicit}} = map {$_ => 1} grep {!/^(public|webtemplate)$/} @websList;
  my $allWebs = $this->getWebs();

  # collect the list in preserving the given order in webs parameter
  foreach my $aweb (@websList) {
    if ($aweb =~ /^(public|webtemplate)(current)?$/) {
      $aweb = $1;
      my @webs;
      push @webs, $currentWeb if defined $2;
      push @webs, keys %{$this->getWebs($aweb)};
      foreach my $bweb (sort @webs) {
	next if $seen{$bweb};
	next if $this->{isExplicit}{$bweb};
	$seen{$bweb} = 1;
	push @list, $bweb;
      }

    } else {
      next if $seen{$aweb};
      $seen{$aweb} = 1;
      push @list, $aweb if defined $allWebs->{$aweb}; # only add if it exists
    }
  }
  writeDebug("list=".join(',', @list));

  # format result
  my @result;
  foreach my $aweb (@list) {
    my $web = $allWebs->{$aweb};

    # filter explicite subwebs
    next if $this->{subWebs} !~ /^(all|none|only)$/ && $web->{key} !~ /$this->{subWebs}\/[^\/]*$/;

    # start recursion
    my $line = $this->formatWeb($web, $this->{format});
    push @result, $line if $line;
  }

  # reset 'done' flag
  foreach my $aweb (keys %$allWebs) {
    $allWebs->{$aweb}{done} = 0;
  }

  return '' unless @result;

  my $result = join($this->{separator},@result);
  $result =~ s/\$marker//g;
  $result = $this->{header}.$result.$this->{footer};
  escapeParameter($result);
  #writeDebug("result=$result");
  $result = TWiki::Func::expandCommonVariables($result, $currentTopic, $currentWeb);

  writeDebug("*** hander done");

  return $result;
}

###############################################################################
sub formatWeb {
  my ($this, $web, $format) = @_;

  # check conditions to format this web
  return '' if $web->{done};

  # filter webs
  unless ($this->{isExplicit}{$web->{key}}) {
    return '' if $web->{isSubWeb} && $this->{subWebs} eq 'none';
    return '' if $this->{exclude} ne '' && $web->{key} =~ /^($this->{exclude})$/;
    return '' if $this->{include} ne '' && $web->{key} !~ /^($this->{include})$/;
  }

  $web->{done} = 1;
  #writeDebug("formatWeb($web->{key})");

  # format all subwebs recursively
  my $subWebResult = '';
  my @lines;
  foreach my $subWeb (@{$web->{children}}) {
    my $line = $this->formatWeb($subWeb, $this->{subFormat}); # recurse
    push @lines, $line if $line;
  }
  if (@lines) {
    $subWebResult = $this->{subHeader}.join($this->{subSeparator},@lines).$this->{subFooter};
  }

  my $result = '';
  if (!$web->{isSubWeb} && 
      $this->{subWebs} eq 'only' && 
      !$this->{isExplicit}{$web->{key}}) {
    $result = $subWebResult;
  } else {
    if ($this->{selection} =~ / \Q$web->{key}\E /) {
      $format = $this->{markerFormat};
      $format =~ s/\$marker/$this->{marker}/g;
    }
    $result = $format.$subWebResult;
  }
  my $nrSubWebs = @{$web->{children}};
  my $name = $this->{map}{$web->{name}} || $web->{name};
  $result =~ s/\$parent/$web->{parentName}/go;
  $result =~ s/\$name/$name/go;
  $result =~ s/\$origname/$web->{name}/go;
  $result =~ s/\$qname/"$web->{key}"/g;# historical
  $result =~ s/\$web/$web->{key}/go;
  $result =~ s/\$depth/$web->{depth}/go;
  $result =~ s/\$indent\((.+?)\)/$1 x ($web->{depth}+1)/ge;
  $result =~ s/\$indent/'   ' x ($web->{depth}+1)/ge;
  $result =~ s/\$nrsubwebs/$nrSubWebs/g;

  #writeDebug("result=$result");
  writeDebug("done formatWeb($web->{key})");

  return $result;
}

###############################################################################
# get a hash of all webs, each web points to its subwebs, each subweb points
# to its parent
sub getWebs {
  my ($this,$filter) = @_;

  $filter ||= '';

  #writeDebug("getWebs($filter)");

  # lookup cache 
  return $this->{webCache}{$filter} if defined $this->{webCache}{$filter};

  my @webs = ();
  
  # dakar
  if ($this->{isDakar}) {
    if ($filter eq 'public') {
      @webs = TWiki::Func::getListOfWebs('user,public,allowed');
    } elsif ($filter eq 'webtemplate') {
      @webs = TWiki::Func::getListOfWebs('template,allowed');
    } else {
      @webs = TWiki::Func::getListOfWebs($filter);
    }
  } else {

    # cairo, beijing
    if ($filter eq 'public') {
      @webs = TWiki::Func::getPublicWebList();
    } elsif ($filter eq 'webtemplate') {
      @webs = grep { /^\_/o } &TWiki::Store::getAllWebs(''); # no Func API available
    } else {
      @webs = &TWiki::Store::getAllWebs(''); # no Func API available
    }
  }
  my $webs = $this->hashWebs(@webs);

  # cache weblist
  $this->{webCache}{$filter} = $webs;

  #writeDebug("result=".join(',',@webs));
  return $webs;
}

###############################################################################
# convert a flat list of webs to a structured parent-child structure;
# the returned hash contains elements of the form
# {
#   key => the full webname (e.g. Main/Foo/Bar)
#   name => the tail of the webname (e.g. Bar)
#   isSubWeb => 1 if the web is a subweb, 0 if it is a top-level web
#   parentName => only defined for subwebs
#   parent => pointer to parent web structure
#   children => list of pointers to subwebs
# }
sub hashWebs {
  my $this = shift;
  my @webs = @_;

  #writeDebug("hashWebs(".join(',',@webs));

  my %webs;
  # collect all webs
  foreach my $key (@webs) {
    $webs{$key}{key} = $key;
    if ($key =~ /^(.*)\/(.*?)$/) {
      $webs{$key}{isSubWeb} = 1;
      $webs{$key}{parentName} = $1;
      $webs{$key}{name} = $2;
    } else {
      $webs{$key}{name} = $key;
      $webs{$key}{isSubWeb} = 0;
      $webs{$key}{parentName} = '';
    }
    $webs{$key}{depth} = ($key =~ tr/\///);
  }

  # establish parent-child relation
  foreach my $key (@webs) {
    my $parentName = $webs{$key}{parentName};
    if ($parentName) {
      $webs{$key}{parent} = $webs{$parentName};
      push @{$webs{$parentName}{children}}, $webs{$key};
    }
  }

  return \%webs;
}

###############################################################################
sub escapeParameter {
  return '' unless $_[0];

  $_[0] =~ s/\$n/\n/g;
  $_[0] =~ s/\$nop//g;
  $_[0] =~ s/\$percnt/%/g;
  $_[0] =~ s/\$dollar/\$/g;
}



###############################################################################
1;
