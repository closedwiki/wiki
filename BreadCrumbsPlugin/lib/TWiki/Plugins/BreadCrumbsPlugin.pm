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
use vars qw($VERSION $RELEASE $debug $NO_PREFS_IN_TOPIC $SHORTDESCRIPTION);

$VERSION = '$Rev$';
$RELEASE = 'v0.10';
$NO_PREFS_IN_TOPIC = 1;
$SHORTDESCRIPTION = 'A flexible way to display breadcrumbs navigation';

$debug = 0; # toggle me

###############################################################################
sub writeDebug {
  #&TWiki::Func::writeDebug('- BreadCrumbPlugin - '.$_[0]) if $debug;
  print STDERR '- BreadCrumbPlugin - '.$_[0]."\n" if $debug;
}

###############################################################################
sub initPlugin {

  TWiki::Func::registerTagHandler('BREADCRUMBS', \&renderBreadCrumbs);
  return 1;
}

###############################################################################
sub renderBreadCrumbs {
  my ($session, $params, $currentTopic, $currentWeb) = @_;

  #writeDebug("called renderBreadCrumbs($currentWeb, $currentTopic)");

  # get parameters
  my $webTopic = $params->{_DEFAULT} || "$currentWeb.$currentTopic";
  my $header = $params->{header} || '';
  my $format = $params->{format} || '[[$webtopic][$name]]';
  my $footer = $params->{footer} || '';
  my $separator = $params->{separator} || ' ';
  $separator = '' if $separator eq 'none';
  my $recurse = $params->{recurse} || 'on';
  my $include = $params->{include} || '';
  my $exclude = $params->{exclude} || '';

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
    my $webtopic = $item->{target};
    $webtopic =~ s/\//./go;
    $line =~ s/\$name/$item->{name}/g;
    $line =~ s/\$target/$item->{target}/g;
    $line =~ s/\$webtopic/$webtopic/g;
    writeDebug("... added");
    push @lines, $line;
  }
  my $result = $header.join($separator, @lines).$footer;

  # expand common variables
  escapeParameter($result);
  $result = TWiki::Func::expandCommonVariables($result, $topic, $web);

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
  my %seen;
  unless ($recurse->{off} || $recurse->{topicoff}) {
    my $web = $thisWeb;
    my $topic = $thisTopic;
    my @topicCrumbs;

    while (1) {
      # get parent
      my ($meta, $dumy) = &TWiki::Func::readTopic($web, $topic);
      my $parentMeta = $meta->get('TOPICPARENT'); 
      last unless $parentMeta;
      my $parentName = $parentMeta->{name};
      last unless $parentName;
      ($web, $topic) = normalizeWebTopicName($web, $parentName);

      # check end of loop
      last if 
	$seen{"$web.$topic"} || 
	$topic eq 'WebHome' ||
	!TWiki::Func::topicExists($web,$topic);

      # add breadcrumb
      #writeDebug("adding breadcrumb: target=$web/$topic, name=$topic");
      unshift @topicCrumbs, { target=>"$web/$topic", name=>$topic };
      $seen{"$web.$topic"} = 1;

      # check for bailout
      last if 
	$recurse->{once} || 
	$recurse->{topiconce};
    }
    push @breadCrumbs, @topicCrumbs;
  }
  
  # maybe add this topic if it was not covered yet
  unless ($seen{"$thisWeb.$thisTopic"}) {
    #writeDebug("finally adding breadcrumb: target=$thisWeb/$thisTopic, name=$thisTopic");
    push @breadCrumbs, { target=>"$thisWeb/$thisTopic", name=>$thisTopic };
  }

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
1;
