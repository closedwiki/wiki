# Plugin for TWiki Collaboration Platform, http://TWiki.org/
# 
# Copyright (C) 2008-2009 Michael Daum http://michaeldaumconsulting.com
# Copyright (C) 2008-2010 TWiki Contributor. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root of
# this distribution.
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

package TWiki::Plugins::RenderPlugin;

require TWiki::Func;
require TWiki::Sandbox;
use strict;

use vars qw( $VERSION $RELEASE $SHORTDESCRIPTION $NO_PREFS_IN_TOPIC );

$VERSION = '$Rev$';
$RELEASE = '3.0';

$SHORTDESCRIPTION = 'Render <nop>TWikiApplications asynchronously';
$NO_PREFS_IN_TOPIC = 1;

use constant DEBUG => 0; # toggle me

###############################################################################
sub writeDebug {
  print STDERR '- RenderPlugin - '.$_[0]."\n" if DEBUG;
}


###############################################################################
sub initPlugin {
  my ($topic, $web, $user, $installWeb) = @_;

  TWiki::Func::registerRESTHandler('tag', \&restTag);
  TWiki::Func::registerRESTHandler('template', \&restTemplate);
  TWiki::Func::registerRESTHandler('expand', \&restExpand);
  TWiki::Func::registerRESTHandler('render', \&restRender);

  return 1;
}

###############################################################################
sub restRender {
  my ($session, $subject, $verb) = @_;

  my $query = TWiki::Func::getCgiQuery();
  my $theTopic = $query->param('topic') || $session->{topicName};
  my $theWeb = $query->param('web') || $session->{webName};
  my ($web, $topic) = TWiki::Func::normalizeWebTopicName($theWeb, $theTopic);

  return TWiki::Func::renderText(restExpand($session, $subject, $verb), $web);
}

###############################################################################
sub restExpand {
  my ($session, $subject, $verb) = @_;

  # get params
  my $query = TWiki::Func::getCgiQuery();
  my $theText = $query->param('text') || '';

  return ' ' unless $theText; # must return at least on char as we get a
                              # premature end of script otherwise
                              
  my $theTopic = $query->param('topic') || $session->{topicName};
  my $theWeb = $query->param('web') || $session->{webName};
  my ($web, $topic) = TWiki::Func::normalizeWebTopicName($theWeb, $theTopic);

  # and render it
  return TWiki::Func::expandCommonVariables($theText, $topic, $web) || ' ';
}

###############################################################################
sub restTemplate {
  my ($session, $subject, $verb) = @_;

  my $query = TWiki::Func::getCgiQuery();
  my $theTemplate = $query->param('name');
  return '' unless $theTemplate;

  my $theExpand = $query->param('expand');
  return '' unless $theExpand;

  my $theRender = $query->param('render') || 0;

  $theRender = ($theRender =~ /^\s*(1|on|yes|true)\s*$/) ? 1:0;
  my $theTopic = $query->param('topic') || $session->{topicName};
  my $theWeb = $query->param('web') || $session->{webName};
  my ($web, $topic) = TWiki::Func::normalizeWebTopicName($theWeb, $theTopic);

  TWiki::Func::loadTemplate($theTemplate);

  require TWiki::Attrs;
  my $attrs = new TWiki::Attrs($theExpand);

  my $tmpl = $session->templates->tmplP($attrs);

  # and render it
  my $result = TWiki::Func::expandCommonVariables($tmpl, $topic, $web) || ' ';
  if ($theRender) {
    $result = TWiki::Func::renderText($result, $web);
  }

  return $result;
}

###############################################################################
sub restTag {
  my ($session, $subject, $verb) = @_;

  #writeDebug("called restTag($subject, $verb)");

  # get params
  my $query = TWiki::Func::getCgiQuery();
  my $theTag = $query->param('name') || 'INCLUDE';
  my $theDefault = $query->param('param') || '';
  my $theRender = $query->param('render') || 0;

  $theRender = ($theRender =~ /^\s*(1|on|yes|true)\s*$/) ? 1:0;

  my $theTopic = $query->param('topic') || $session->{topicName};
  my $theWeb = $query->param('web') || $session->{webName};
  my ($web, $topic) = TWiki::Func::normalizeWebTopicName($theWeb, $theTopic);

  # construct parameters for tag
  my $params = $theDefault?'"'.$theDefault.'"':'';
  foreach my $key ($query->param()) {
    next if $key =~ /^(name|param|render|topic|XForms:Model)$/;
    my $value = $query->param($key);
    $params .= ' '.$key.'="'.$value.'" ';
  }

  # create TML expression
  my $tml = '%'.$theTag;
  $tml .= '{'.$params.'}' if $params;
  $tml .= '%';

  #writeDebug("tml=$tml");

  # and render it
  my $result = TWiki::Func::expandCommonVariables($tml, $topic, $web) || ' ';
  if ($theRender) {
    $result = TWiki::Func::renderText($result, $web);
  }

  #writeDebug("result=$result");

  return $result;
}

1;
