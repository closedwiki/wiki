# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2001 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001 Peter Thoeny, Peter@Thoeny.com
# Copyright (C) 2002 TWiki:Main.AndyThaller
# Copyright (C) 2008-2011 TWiki Contributors. All Rights Reserved.
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

# =========================
package TWiki::Plugins::AgentPlugin;

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $RELEASE $debug
        $query $browsers $userAgent
    );


$VERSION = '$Rev$';
$RELEASE = '2011-02-01';

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1 ) {
        &TWiki::Func::writeWarning( "Version mismatch between EmptyPlugin and Plugins.pm" );
        return 0;
    }

    %defaults = 
      (check => "msie netscape",
       none  => "unknown");

    # now get defaults from CalendarPlugin topic
    my $v;
    foreach $option (keys %defaults) {
	# read defaults from CalendarPlugin topic
	$v = &TWiki::Func::getPreferencesValue("CALENDARPLUGIN_\U$option\E") || undef;
	$defaults{$option} = $v if defined($v);
    }


    # Get plugin debug flag
    $debug = &TWiki::Func::getPreferencesFlag( "AGENTPLUGIN_DEBUG" );
    $query = &TWiki::Func::getCgiQuery();

    # Plugin correctly initialized
    &TWiki::Func::writeDebug( "- TWiki::Plugins::EmptyPlugin::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}

# =========================
sub commonTagsHandler
{
    &TWiki::Func::writeDebug( "- AgentPlugin::commonTagsHandler($_[2].$_[1])" ) if $debug;
    $_[0] =~ s/%AGENT%/&handleAgent()/geo;
    $_[0] =~ s/%AGENT{(.*?)}%/&handleAgent($1)/geo;
}

# =========================

sub handleAgent
{
  if (!$query || !$userAgent) {
    $query = &TWiki::Func::getCgiQuery();
    $userAgent = $query->user_agent();
  }
  return $userAgent if (! defined $_[0] );

  my $attributes = $_[0];
  my %options = %defaults;
  my $v;
  foreach $option (keys %options) {
    $v = &TWiki::Func::extractNameValuePair($attributes,$option) || undef;
    $options{$option} = $v if defined($v);
  }

  my $check = $options{check};
  my $idList = &TWiki::Func::getPreferencesValue( "AGENTPLUGIN_CHECK".uc($check) ) || $check;
  &TWiki::Func::writeDebug( "- AgentPlugin::handleAgent($_[0]): idList=$idList") if $debug;
  return $options{none} if (!$idList);
  foreach $id (split(/\s+/,$idList)) {
    my $idp= $id; 
    $idp =~ s/[^A-Za-z0-9_]//g; # prune id to allow for '.' in return values
    $exp = &TWiki::Func::extractNameValuePair($attributes,"exp$idp") || undef;
    if (!$exp) { $exp = &TWiki::Func::getPreferencesValue( "AGENTPLUGIN_EXP".uc($idp) ) || undef;}
    if ($exp) {
      return "$id" if ($userAgent =~ m/$exp/);
    }
  }
  return $options{none};
}

1;
