# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2006 MichaelDaum@WikiRing.com
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
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

package TWiki::Plugins::PingBackPlugin;

use strict;
use vars qw( $VERSION $RELEASE $debug $pluginName 
  $currentWeb $currentTopic $currentUser
  $pingbackServerUrl $pingbackServer $pingbackClient 
);

$VERSION = '$Rev$';
$RELEASE = 'v0.01';
$pluginName = 'PingBackPlugin';

$debug = 0; # toggle me

###############################################################################
sub writeDebug {
  &TWiki::Func::writeDebug('- '.$pluginName.' - '.$_[0]) if $debug;
}

###############################################################################
sub initPlugin {
  ($currentTopic, $currentWeb, $currentUser) = @_;

  # check for Plugins.pm versions
  if ($TWiki::Plugins::VERSION < 1.026) {
    TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
    return 0;
  }

  my $pingbackServerUrl = TWiki::Func::getPreferencesValue("\U$pluginName\E_PINGBACKSERVER");
  $pingbackServer = undef;
  $pingbackClient = undef;

  TWiki::Func::registerTagHandler('PINGBACK', \&handlePINGBACK);
  TWiki::Func::registerRESTHandler('server', \&handleRESTServer);
  TWiki::Func::addToHEAD('PINGBACKPLUGIN_LINK',
    "\n<link rel=\"pingback\" href=\"$pingbackServerUrl\" />\n");

  # Plugin correctly initialized
  return 1;
}


###############################################################################
sub handlePINGBACK {
  my ($session, $params, $theTopic, $theWeb) = @_;

  writeDebug("called handlePINGBACK");

  my $query = TWiki::Func::getCgiQuery();
  my $action = $query->param('action') || '';
  my $source;
  my $target;
  my $format = $params->{format} || 
    '<pre style="overflow:auto">%STATUS%: %RESULT%</pre>';

  if ($action eq 'pingback') { 
    # cgi mode
    $source = $query->param('source');
    $target = $query->param('target');
  } else { 
    # tml mode
    $source = $params->{source};
    $target = $params->{target};
  }

  return '' unless $target;
  $source = &TWiki::Func::getViewUrl($theWeb, $theTopic) unless $source;

  writeDebug("source=$source");
  writeDebug("target=$target");

  unless ($pingbackClient) {
    eval 'use TWiki::Plugins::PingBackPlugin::Client;';
    die $@ if $@;
    $pingbackClient = TWiki::Plugins::PingBackPlugin::Client->new();
    die $@ unless $pingbackClient;
  }

  my ($status, $result) = $pingbackClient->ping($source, $target);

  my $text = expandVariables($format, 
    STATUS=>$status,
    RESULT=>$result,
    TARGET=>$target,
    SOURCE=>$source,
  );


  writeDebug("done handlePINGBACK");

  return $text;
}


###############################################################################
sub handleRESTServer {
  my $session = shift;

  writeDebug("called handleRESTServer");

  unless ($pingbackServer) {
    eval 'use TWiki::Plugins::PingBackPlugin::Server;';
    die $@ if $@;
    $pingbackServer = new TWiki::Plugins::PingBackPlugin::Server;
    die $@ unless $pingbackServer; 
  }

  # get the data
  my $query = TWiki::Func::getCgiQuery();
  my $data = $query->param('POSTDATA');

  # process it
  my $result = $pingbackServer->callProcedure($data);

  writeDebug("result=$result");
  writeDebug("done handleRESTServer");

  print $result; # we print out the response ourselves
  return 0; # don't produce any further output
}

################################################################################
sub expandVariables {
  my ($format, %variables) = @_;

  my $text = $format;

  foreach my $key (keys %variables) {
    $text =~ s/\%$key%/$variables{$key}/g;
  }
  $text =~ s/%[A-Z]+%//go;

  return $text;
}

###############################################################################
1;
