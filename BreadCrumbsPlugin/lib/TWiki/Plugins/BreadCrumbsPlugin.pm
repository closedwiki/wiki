# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) MichaelDaum@WikiRing.com
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

package TWiki::Plugins::BreadCrumbsPlugin;

use strict;
use vars qw($VERSION $RELEASE $debug $isDakar);

$VERSION = '$Rev$';
$RELEASE = 'v0.03';

$debug = 0; # toggle me

###############################################################################
sub writeDebug {
  &TWiki::Func::writeDebug('- BreadCrumbPlugin - '.$_[0]) if $debug;
}

###############################################################################
sub initPlugin {

  $isDakar = (defined $TWiki::RELEASE)?1:0; # we could do better
  return 1;
}

###############################################################################
sub commonTagsHandler {

  $_[0] =~ s/%BREADCRUMBS%/&renderBreadCrumbs($_[2],$_[1],'')/geo;
  $_[0] =~ s/%BREADCRUMBS{(.*?)}%/&renderBreadCrumbs($_[2], $_[1],$1)/geo;
}

###############################################################################
# wrapper around version differences
sub getMetaData {
  my ($meta, $key) = @_;

  my $result;
  if ($isDakar) {
    $result = $meta->get($key) if $isDakar;
  } else {
    my %tempHash = $meta->findOne($key);
    $result = \%tempHash;
  }

  return $result;
}

###############################################################################
sub getLocationBreadCrumbs {
  my ($thisWeb, $thisTopic, $recurse) = @_;

  my @breadCrumbs = ();

  # collect all parent webs as breadcrumbs
  if ($recurse->{off} || $recurse->{weboff}) {
    my $webName = $thisWeb;
    if ($webName =~ /^(.*)[\.\/](.*?)$/) {
      $webName = $2;
    }
    #writeDebug("adding breadcrumb: target=$thisWeb/WebHome, name=$webName");
    push @breadCrumbs, { target=>"$thisWeb/WebHome", name=>$webName };
  } else {
    my $parentWeb = '';
    my @webCrumbs;
    foreach my $parentName (split(/\//,$thisWeb)) {
      $parentWeb .= '/' if $parentWeb;
      $parentWeb .= $parentName;
      #writeDebug("adding breadcrumb: target=$parentWeb/WebHome, name=$parentName");
      push @webCrumbs, { target=>"$parentWeb/WebHome", name=>$parentName };
    }
    if ($recurse->{once} || $recurse->{webonce}) {
      my @list;
      push @list, pop @webCrumbs;
      push @list, pop @webCrumbs;
      push @breadCrumbs, reverse @list;
    } else {
      push @breadCrumbs, @webCrumbs;
    }
  }

  # collect all parent topics
  unless ($recurse->{off} || $recurse->{topicoff}) {
    my $web = $thisWeb;
    my $topic = $thisTopic;
    my %seen;
    $seen{"$thisWeb.$thisTopic"} = 1;
    my @topicCrumbs;
    while (1) {
      last if $seen{"$web.$topic"};
      $seen{"$web.$topic"} = 1;
      my ($meta, $dumy) = &TWiki::Func::readTopic($web, $topic);
      my $parentMeta = &getMetaData($meta, "TOPICPARENT"); 
      last unless $parentMeta;
      my $parentName = $parentMeta->{name};
      last unless $parentName;
      ($web, $topic) = normalizeWebTopicName($web, $parentName);
      last if $topic eq 'WebHome';
      #writeDebug("adding breadcrumb: target=$web/$topic, name=$topic");
      unshift @topicCrumbs, { target=>"$web/$topic", name=>$topic };
      last if $recurse->{once} || $recurse->{topiconce};
    }
    push @breadCrumbs, @topicCrumbs;
  }
  
  #writeDebug("finally adding breadcrumb: target=$thisWeb/$thisTopic, name=$thisTopic");
  push @breadCrumbs, { target=>"$thisWeb/$thisTopic", name=>$thisTopic };

  return \@breadCrumbs;
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
# local version to run on legacy twiki releases
sub normalizeWebTopicName {
  my ($web, $topic) = @_;

  if ($topic =~ /^(.*)[\.\/](.*?)$/ ) {
    $web = $1;
    $topic = $2;
  }
  
  return ($web, $topic);
}

###############################################################################
sub renderBreadCrumbs {
  my ($currentWeb, $currentTopic, $args) = @_;

  writeDebug("called renderBreadCrumbs($currentWeb, $currentTopic, $args)");

  # get parameters
  my $webTopic = TWiki::Func::extractNameValuePair($args) || "$currentWeb.$currentTopic";
  my $header = TWiki::Func::extractNameValuePair($args, 'header') || '';
  my $format = TWiki::Func::extractNameValuePair($args, 'format') || '[[$target][$name]]';
  my $footer = TWiki::Func::extractNameValuePair($args, 'footer') || '';
  my $separator = TWiki::Func::extractNameValuePair($args, 'separator') || ' ';
  $separator = '' if $separator eq 'none';
  my $recurse = TWiki::Func::extractNameValuePair($args, 'recurse') || 'on';
  my $include = TWiki::Func::extractNameValuePair($args, 'include') || '';
  my $exclude = TWiki::Func::extractNameValuePair($args, 'exclude') || '';

  my %recurseFlags = map {$_ => 1} split (/,\s*/, $recurse);
  #foreach my $key (keys %recurseFlags) {
  #  writeDebug("recurse($key)=$recurseFlags{$key}");
  #}

  # compute breadcrumbs
  my ($web, $topic) = normalizeWebTopicName($currentWeb, $webTopic);
  my $breadCrumbs = getLocationBreadCrumbs($web, $topic, \%recurseFlags);

  # format result
  my @lines = ();
  foreach my $item (@$breadCrumbs) {
    next unless $item;
    next if $exclude ne '' && $item->{name} =~ /^($exclude)$/;
    next if $include ne '' && $item->{name} !~ /^($include)$/;
    my $line = $format;
    $line =~ s/\$name/$item->{name}/g;
    $line =~ s/\$target/$item->{target}/g;
    push @lines, $line;
  }
  my $result = $header.join($separator, @lines).$footer;

  # expand common variables
  escapeParameter($result);
  $result = TWiki::Func::expandCommonVariables($result, $topic, $web);

  return $result;
}


###############################################################################
1;
