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

use TWiki::Func;

use TWiki::Plugins::ActionTrackerPlugin::Attrs;
use TWiki::Plugins::ActionTrackerPlugin::Format;
use TWiki::Plugins::ActionTrackerPlugin::Config;

# Perl object that represents a set of actions.
{ package ActionTrackerPlugin::ActionSet;

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

  # PRIVATE place to put sort fields
  my @_sortfields;

  # PUBLIC sort by due date or, if given, by an ordered sequence
  # of attributes by string value
  sub sort {
    my ( $this, $order ) = @_;
    if ( defined( $order ) ) {
      $order =~ s/[^\w,]//g;
      @_sortfields = split( /,/, $order );
      @{$this->{ACTIONS}} = sort {
	foreach my $sf ( @_sortfields ) {
	  my ( $x, $y ) = ( $a->{$sf}, $b->{$sf} );
	  if ( defined( $x ) && defined( $y )) {
	    my $c = ( $x cmp $y );
	    return $c if ( $c != 0 );
	  } elsif ( defined( $x ) ) {
	    return -1;
	  } elsif ( defined( $y ) ) {
	    return 1;
	  }
	}
	# default to sorting on due
	$a->{due} <=> $b->{due};
      } @{$this->{ACTIONS}};
    } else {
      @{$this->{ACTIONS}} =
	sort { $a->{due} <=> $b->{due} } @{$this->{ACTIONS}};
    }
  }

  # PUBLIC Concatenate another action set to this one
  sub concat {
    my ( $this, $actions ) = @_;

    push @{$this->{ACTIONS}}, @{$actions->{ACTIONS}};
  }

  # PUBLIC Search the set of actions for actions that match the given
  # attributes string. Return an ActionSet.
  # If the search expression is empty, all actions match.
  sub search {
    my ( $this, $attrs ) = @_;
    my $attr = new ActionTrackerPlugin::Attrs( $attrs );
    my $action;
    my $chosen = new ActionTrackerPlugin::ActionSet();

    my $sort = $attr->remove( "sort" );

    foreach $action ( @{$this->{ACTIONS}} ) {
      if ( $action->matches( $attr ) ) {
	$chosen->add( $action );
      }
    }

    # by default actions will be sorted by due date
    $chosen->sort( $sort );

    return $chosen;
  }

  sub toString {
    my $this = shift;
    my $txt = "ActionSet{";
    foreach my $action ( @{$this->{ACTIONS}} ) {
      $txt .= "\n " . $action->toString();
    }
    return "$txt\n}";
  }

  # PUBLIC format the action set as an HTML table
  # Pass $type="name" to to get an anchor to a position
  # within the topic, "href" to get a jump. Defaults to "name".
  # Pass $newWindow=1 to get separate browser window,
  # $newWindow=0 to get jump in same window.
  sub formatAsHTML {
    my ( $this, $format, $jump, $newWindow ) = @_;
    return $format->formatHTMLTable( \@{$this->{ACTIONS}}, $jump, $newWindow );
  }

  # PUBLIC format the action set as a plain string
  sub formatAsString {
    my ( $this, $format ) = @_;
    return $format->formatStringTable( \@{$this->{ACTIONS}} );
  }

  # PUBLIC find actions that have changed.
  # Recent actions will have a UID that lets us match them exactly,
  # but older actions will not have a UID and will have to be
  # matched using a fuzzy match tuned for detecting 'interesting'
  # state changes in actions.
  # See Action->fuzzyMatches for details.
  # Changed actions are returned as text in a hash keyed on the
  # names of people who have registered for notification.
  sub findChanges {
    my ( $this, $old, $date, $format, $notifications ) = @_;
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
	my $score = $naction->fuzzyMatches( $oaction );
	if ( $score > 7 ) {
	  $naction->findChanges( $oaction, $format, $notifications );
	  $n = $i + 1;
	  last;
	}
      }
    }
  }

  # PUBLIC get a map of all people who have actions in this action set
  sub getActionees {
    my ( $this, $whos ) = @_;
    my $action;

    foreach $action ( @{$this->{ACTIONS}} ) {
      my @persons = split( /,/, $action->{who} );
      foreach my $person ( @persons ) {
	$whos->{$person} = 1;
      }
    }
  }

  # PUBLIC STATIC get all actions in topics in the given web that
  # match the search expression
  sub allActionsInWeb {
    my ( $web, $attrs ) = @_;
    my $actions = new ActionTrackerPlugin::ActionSet();
    my $dd = TWiki::Func::getDataDir() || "../data";
    # "../data" because this is a cgi script executed in bin

    # SMELL: if there's only one file in the web matching
    # *.txt then the file name won't be printed, at least with GNU
    # grep. The GNU -H switch, which would solve the problem, is
    # non-standard. This problem is ignored because such a web
    # isn't very useful in TWiki.
    # Also assumed: the output of the egrepCmd must be of the form
    # file.txt: ...matched text...
    my $cmd = $ActionTrackerPlugin::Config::egrepCmd;
    my $q = $ActionTrackerPlugin::Config::cmdQuote;
    my $grep = `$cmd $q%ACTION\\{.*\\}%$q $dd/$web/*.txt`;
    my $number = 0;
    my $topics = $attrs->get( "topic" ) || "";
    my $lastTopic = "";
    while ( $grep =~ s/^.*\/([^\/\.\n]+)\.txt:.*%ACTION{([^\}]*)}%([^\r\n]*)//m ) {
      my $topic = $1;
      my $sat = $2;
      my $text = $3;
      $topic =~ s/[\r\n\s]+//go;
      $number = 0 if ( $topic ne $lastTopic );
      if ( ! $topics || $topic =~ /^$topics$/ ) {
	my $action = new ActionTrackerPlugin::Action( $web, $topic, $number++, $sat, $text );
	if ( $action->matches( $attrs ) ) {
	  $actions->add( $action )
	}
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
    my $actions = new ActionTrackerPlugin::ActionSet();
    my $dataDir = TWiki::Func::getDataDir();
    opendir( DIR, "$dataDir" ) or die "could not open $dataDir";
    my @weblist = grep !/^[._].*$/, readdir DIR;
    closedir DIR;
    my $web;
    foreach $web ( @weblist ) {
      if ( -d "$dataDir/$web" && $web =~ /^$webs$/ ) {
	$web =~ s/$ActionTrackerPlugin::Config::securityFilter//go;  # FIXME: This bypasses the official API
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
