#
# Copyright (C) Motorola 2002 - All rights reserved
#
# TWiki extension that adds tags for action tracking
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
# Based on EmptyPlugin
#

# =========================
package TWiki::Plugins::ActionTrackerPlugin;

use TWiki::Func;
use TWiki::Plugins::ActionTrackerPlugin::Action;
use TWiki::Plugins::ActionTrackerPlugin::ActionSet;
# tempt for test
use TWiki::Plugins::ActionTrackerPlugin::ActionNotify;

# =========================
use vars qw(
	    $web $topic $user $installWeb $VERSION
	    $allActions $useNewWindow $debug $javaScriptIncluded
	    $pluginInitialized $perlTimeParseDateFound
	   );

$VERSION = '1.000';
$pluginInitialized = 0;
$perlTimeParseDateFound = 0;

# =========================
sub initPlugin {
  ( $topic, $web, $user, $installWeb ) = @_;
  
  # check for Plugins.pm versions
  if( $TWiki::Plugins::VERSION < 1 ) {
    &TWiki::Func::writeWarning( "Version mismatch between ActionTrackerPlugin and Plugins.pm" );
    return 0;
  }

  # Get plugin debug flag
  $debug = &TWiki::Prefs::getPreferencesFlag( "ACTIONTRACKERPLUGIN_DEBUG" ) || 0;
  $useNewWindow = &TWiki::Prefs::getPreferencesFlag( "ACTIONTRACKERPLUGIN_USENEWWINDOW" );

  &TWiki::Func::writeDebug( "ActionTrackerPlugin: USENEWWINDOW=$useNewWindow" ) if ( $debug );

  &TWiki::Func::writeDebug( "- TWiki::Plugins::ActionTrackerPlugin::initPlugin($web.$topic) is OK" ) if $debug;
  $pluginInitialized = 0;
  $javaScriptIncluded = 0;
  return 1;
}

# =========================
sub commonTagsHandler {
  ### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead
  
  # This is the place to define customized tags and variables
  # Called by sub handleCommonTags, after %INCLUDE:"..."%
  
  # do custom extension rule, like for example:
  # $_[0] =~ s/%XYZ%/&handleXyz()/geo;
  # $_[0] =~ s/%XYZ{(.*?)}%/&handleXyz($1)/geo;

  if ( $_[0] !~ m/%ACTION.*{.*}%/) {
    # nothing to do
    return;
  }
  unless( $pluginInitialized ) {
    return unless( _init_defaults() );
  }

  my $javaScriptIncluded = 0;
  # Done this way so we get tables built up by
  # collapsing successive actions.
  my $actionNumber = 0;
  while ( $_[0] =~ s/(%ACTION{[^%]*}%[^\n\r]+([\r\n]+[ \t]*%ACTION{[^%]*}%[^\n\r]+)*)/__REPLACTS__/so) {
    my $aset = $1;
    my $actionSet = ActionSet->new();
    while ( $aset =~ s/%ACTION{([^%]*)}%([^\n\r]+)//so ) {
      my $action = Action->new( $_[2], $_[1], $actionNumber++, $1, $2 );
      $actionSet->add( $action );
    }
    $aset = $actionSet->formatAsTable( "name", $useNewWindow );
    $aset = embedJS() . $aset;
    $_[0] =~ s/__REPLACTS__/$aset/so;
  }

  $_[0] =~ s/%ACTIONSEARCH{(.*)}%/&handleActionSearch($web, $1)/geo;

  $_[0] =~ s/%ACTIONCHANGES{(.*)}%/&handleOldActions($web, $1)/geo;
}

# =========================
sub DISABLE_startRenderingHandler {
  ### my ( $text, $web ) = @_;   # do not uncomment, use $_[0], $_[1] instead
  
  # This handler is called by getRenderedVersion just before the line loop
  
  # do custom extension rule, like for example:
  # $_[0] =~ s/old/new/go;
}

# =========================
sub DISABLE_outsidePREHandler {
  ### my ( $text ) = @_;   # do not uncomment, use $_[0] instead
  
  # This handler is called by getRenderedVersion, in loop outside of <PRE> tag.
  # This is the place to define customized rendering rules.
  # Note: This is an expensive function to comment out.
  # Consider startRenderingHandler instead
}

# =========================
sub DISABLE_insidePREHandler {
  ### my ( $text ) = @_;   # do not uncomment, use $_[0] instead
  
  # This handler is called by getRenderedVersion, in loop inside of <PRE> tag.
  # This is the place to define customized rendering rules.
  # Note: This is an expensive function to comment out.
  # Consider startRenderingHandler instead
}

# =========================
sub DISABLE_endRenderingHandler {
  ### my ( $text ) = @_;   # do not uncomment, use $_[0] instead
  
  # This handler is called by getRenderedVersion just after the line loop
}

# =========================

# Perform filtered search for all actions
sub handleActionSearch {
  my ( $web, $expr ) = @_;

  my $actions = ActionSet::allActionsInWebs( $web, ActionTrackerPlugin::Attrs->new( $expr ) );

  $actions->sort();

  return embedJS() . $actions->formatAsTable( "href", $useNewWindow );
}

# =========================
# Lazy initialize of plugin 'cause of performance
sub _init_defaults
{
  $libsFound = 0;
  eval {
    require Exporter;
    $perlTimeParseDateFound = require Time::ParseDate;
    # If the Time::ParseDate module is not found, then there is no use in
    # including any of the following.
    if( $perlTimeParseDateFound ) {
      eval {
        $libsFound = require TWiki::Plugins::ActionTrackerPlugin::Action;
        require TWiki::Plugins::ActionTrackerPlugin::ActionSet;
        require TWiki::Plugins::ActionTrackerPlugin::Attrs;
      };
      unless( $libsFound ) {
        # Could not find ActionTrackerPlugin utility libs possibly because
        # of relative use lib dir and chdir after initialization.
        # Try again with absolute TWiki lib dir path
        eval {
          my $libDir = TWiki::getTWikiLibDir();
          $libDir =~ /(.*)/;
          $libDir = $1;       # untaint
          $libsFound = require "$libDir/TWiki/Plugins/ActionTrackerPlugin/Action.pm";
          require "$libDir/TWiki/Plugins/ActionTrackerPlugin/ActionSet.pm";
          require "$libDir/TWiki/Plugins/ActionTrackerPlugin/Attrs.pm";
        };
      }
#      @TWiki::Plugins::ISA = qw(
#          TWiki::Plugins::ActionTrackerPlugin::Action;
#          TWiki::Plugins::ActionTrackerPlugin::ActionSet;
#          TWiki::Plugins::ActionTrackerPlugin::Attrs;
#        );
    }
  };
  $pluginInitialized = 1;
  return $libsFound;
}

sub embedJS {
    return "" unless ($useNewWindow && !$javaScriptIncluded);
    $javaScriptIncluded = 1;
    return "\n<script language=\"JavaScript\"><!--
function editWindow(url) {
  win = open(url, \"none\", \"titlebar=0,width=700,height=400,resizable,scrollbars\");
  if(win) { win.focus(); }
  return false;
}
-->\n</script>\n";
}

########################################


# Test; handle actions that have changed in all webs
sub handleOldActions {
  my ( $web, $expr ) = @_;

  my $text = ActionNotify::doNotifications( $web, $expr, 1 );

  return $text;
}


1;
