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
use strict;
use integer;

use TWiki;
use TWiki::Plugins::ActionTrackerPlugin::Attrs;
use TWiki::Func;

# Perl object that represents a set of actions.
{ package ActionSet;

  # PUBLIC constructor
  sub new {
    my $class = shift;
    my $this = {};

    $this->{ACTIONS} = [];

    return bless( $this, $class );
  }

  # PUBLIC Add this action to the list of actions
  sub add {
    my ( $this, $action ) = @_;

    push @{$this->{ACTIONS}}, $action;
  }

  # PUBLIC sort by due date
  sub sort {
    my $this = shift;

    @{$this->{ACTIONS}} = sort { $a->{DUE} <=> $b->{DUE} } @{$this->{ACTIONS}};
  }

  # PUBLIC Concatenate another action set to this one
  sub concat {
    my ( $this, $actions ) = @_;

    push @{$this->{ACTIONS}}, @{$actions->{ACTIONS}};
  }

  # PUBLIC Search the set of actions for actions that match the given
  # attributes string. Return an ActionSet.
  sub search {
    my ( $this, $attrs ) = @_;
    my $attr = new ActionTrackerPlugin::Attrs( $attrs );
    my $action;
    my $chosen = ActionSet->new();

    foreach $action ( @{$this->{ACTIONS}} ) {
      if ( $action->matches( $attr ) ) {
	$chosen->add( $action );
      }
    }

    return $chosen;
  }

  # PUBLIC format the action set as an HTML table
  # Pass $type="name" to to get a jump to a position
  # within the topic, "href" to get a jump. Defaults to "name".
  # Pass $newWindow=1 to get separate browser window,
  # $newWindow=0 to get jump in same window.
  sub formatAsTable {
    my ( $this, $type, $newWindow ) = @_;
    my $action;

    my $text = "<table border=$Action::border>\n" .
      "<tr bgcolor=\"$Action::hdrcol\"><th>Assignee</th>" .
	"<th>Due date</th>" .
	  "<th>Description</th>" .
	    "<th>State</th><th>&nbsp;</th></tr>\n";
    foreach $action ( @{$this->{ACTIONS}} ) {
      my $row = $action->formatAsTableData( $type, $newWindow );
      $text .= "<tr valign=\"top\">$row</tr>\n";
    }

    return "$text</table>\n";
  }

  # PUBLIC format the action set as a plain string
  sub formatAsString {
    my ( $this, $type ) = @_;
    my $action;
    my $text = "";

    foreach $action ( @{$this->{ACTIONS}} ) {
      $text .= $action->formatAsString( $type ) . "\n";
    }

    return $text;
  }

  # PUBLIC find actions that have changed. Because action numbering
  # may have changed, the actions are matched using a fuzzy match
  # tuned for detecting 'interesting' state changes in actions.
  # See Action->fuzzyMatches for details.
  # Changed actions are returned as text in a hash keyed on the
  # names of people who have registered for notification.
  sub gatherNotifications {
    my ( $this, $old, $date, $notifications ) = @_;
    my @matchNumber = ();
    my @matchValue = ();

    # Assume the action _order_ is not changed, but actions may have
    # been inserted or deleted. For each old action,
    # find the next new action that fuzzyMatches the old action starting
    # from the most recently matched new action.
    my $n = 0;
    for ( my $o = 0; $o < scalar( @{$old->{ACTIONS}} ); $o++ ) {
      my $oaction = @{$old->{ACTIONS}}[$o];
      for ( my $i = $n; $i < scalar( @{$this->{ACTIONS}} ); $i++ ) {
	my $naction = @{$this->{ACTIONS}}[$i];
	if ( $naction->fuzzyMatches( $oaction ) > 7 ) {
	  $naction->gatherNotifications( $oaction, $notifications );
	  $n = $i + 1;
	  last;
	}
      }
    }
  }

  # PUBLIC get a map of all people who have actions in this action set
  sub getActionees() {
    my $this = shift;
    my $whos = {};
    my $action;

    foreach $action ( @{$this->{ACTIONS}} ) {
      $whos->{$action->who()} = 1;
    }
    return $whos;
  }

  # PUBLIC STATIC get all actions in topics in the given web that
  # match the search expression
  sub allActionsInWeb {
    my ( $web, $attrs ) = @_;
    my $actions = ActionSet->new();
    my $dd = TWiki::Func::getDataDir() || "..";

    # Known problem; if there's only one file in the web matching
    # *.txt then the file name won't be printed, at least with GNU
    # grep. The GNU -H switch, which would solve the problem, is
    # non-standard. This problem is ignored because such a web
    # isn't very useful in TWiki.
    # Also assumed: the output of the egrepCmd must be of the form
    # file.txt: ...matched text...
    chdir( "$dd/$web" );
    my $grep = `${TWiki::egrepCmd} ${TWiki::cmdQuote}%ACTION\\{.*\\}%${TWiki::cmdQuote} *.txt`;
    #&TWiki::Func::writeWarning( "Grep $dd/$web $grep" );
    my $number = 0;
    my $topics = $attrs->get( "topic" ) || "";
    my $lastTopic = "";
    while ( $grep =~ s/^([^\._]+)\.txt:.*%ACTION{([^\}]*)}%([^\r\n]*)//m ) {
      my $topic = $1;
      my $sat = $2;
      my $text = $3;
      $topic =~ s/[\r\n\s]+//go;
      $number = 0 if ( $topic ne $lastTopic );
      if ( ! $topics || $topic =~ /^$topics$/ ) { 
	my $action = Action->new( $web, $topic, $number++, $sat, $text );
	$actions->add( $action ) if ( $action->matches( $attrs ) );
      }
      $lastTopic = $topic;
    }

    return $actions;
  }

  # PUBLIC STATIC get all actions in all webs that
  # match the search in $attrs
  sub allActionsInWebs {
    my ( $theweb, $attrs ) = @_;
    my $webs = $attrs->get( "web" ) || $theweb;
    my $actions = ActionSet->new();
    my $dataDir = TWiki::Func::getDataDir();
    opendir( DIR, "$dataDir" ) or die "could not open $dataDir";
    my @weblist = grep !/^[._].*$/, readdir DIR;
    closedir DIR;
    my $web;
    foreach $web ( @weblist ) {
      if ( -d "$dataDir/$web" && $web =~ /^$webs$/ ) {
	$web =~ s/$TWiki::securityFilter//go;  # FIXME: This bypasses the official API
	$web =~ /(.*)/; # untaint
	$web = $1;
	# Exclude webs flagged as NOSEARCHALL
        my $thisWebNoSearchAll =
	  TWiki::Func::getPreferencesValue( "NOSEARCHALL", $web );
	next if ( $thisWebNoSearchAll =~ /on/i && ( $web ne $theweb ) );
	my $subacts = allActionsInWeb( $web, $attrs );
	$actions->concat( $subacts );
      }
    }
    return $actions;
  }

}

1;
