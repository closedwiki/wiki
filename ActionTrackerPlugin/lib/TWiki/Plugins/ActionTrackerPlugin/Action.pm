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

use Text::Soundex;
use Time::ParseDate;

# Perl object that represents a single action
{ package Action;

  use vars qw ( $latecol $badcol $hdrcol $border );

  # Colour for warning of late actions
  $latecol = "yellow";
  # Colour for an unparseable date
  $badcol = "red";
  # Colour for table header rows
  $hdrcol = "FFCC66";
  # Border width for tables
  $border = "1";

  my $now = time();
  my $mainweb = TWiki::Func::getMainWebname();

  # Options for parsedate
  my %pdopt = ( NO_RELATIVE => 1, DATE_REQUIRED => 1, WHOLE => 1 );

  # PUBLIC Constructor
  sub new {
    my ( $class, $web, $topic, $number, $attrs, $descr ) = @_;
    my $this = {};

    my $attr = new ActionTrackerPlugin::Attrs( $attrs );
    my $who = _canonicalName( $attr->get( "who" ) );
    $this->{WEB} = $web;
    $this->{TOPIC} = $topic;
    $this->{ACTION_NUMBER} = $number;
    $this->{WHO} = $who;
    $this->{DUE} = Time::ParseDate::parsedate( $attr->get( "due" ), %pdopt );
    $this->{TEXT} = $descr;
    $this->{NOTIFY} = $attr->get( "notify" );

    my $state;
    if (defined $attr->get( "state" )) {
      $this->{STATE} = $attr->get( "state" );
    } elsif (defined $attr->get( "closed" )) {
      $this->{STATE} = "closed";
    } else {
      $this->{STATE} = "open";
    }

    return bless( $this, $class );
  }

  # PRIVATE STATIC make a canonical name (including the web) for a user
  sub _canonicalName {
    my $who = shift;

    return undef if !defined( $who );
    $who = TWiki::Func::getWikiName() if ( $who eq "me" );
    $who = "$mainweb.$who" unless $who =~ /\./o;
    return $who;
  }

  # PUBLIC For testing only, force current time to a known value
  sub forceTime {
    $now = shift;
  }

  # PUBLIC the containing web
  sub web {
    my $this = shift;
    if (@_) { $this->{WEB} = shift; };
    return $this->{WEB};
  }

  # PUBLIC the containing topic
  sub topic {
    my $this = shift;
    if (@_) { $this->{TOPIC} = shift; };
    return $this->{TOPIC};
  }

  # PUBLIC the guilty party
  sub who {
    my $this = shift;
    if (@_) { $this->{WHO} = shift; };
    return $this->{WHO};
  }

  # PUBLIC the action number
  sub actionNumber {
    my $this = shift;
    if (@_) { $this->{ACTION_NUMBER} = shift; };
    return $this->{ACTION_NUMBER};
  }

  # PUBLIC due time, as an absolute time
  sub due {
    my $this = shift;
    if (@_) { $this->{DUE} = shift; };
    return $this->{DUE};
  }

  # PUBLIC description of the action
  sub text {
    my $this = shift;
    if (@_) { $this->{TEXT} = shift; };
    return $this->{TEXT};
  }

  # PUBLIC state of the action, as a string
  sub state {
    my $this = shift;
    if (@_) { $this->{STATE} = shift; };
    return $this->{STATE};
  }

  # PUBLIC due time, as a date string
  sub dueString {
    my $this = shift;
    my $stime;
    if ( defined( $this->{DUE} )) {
      $stime = localtime( $this->{DUE} );
      $stime =~
	s/([^\s]+)\s+([^\s]+)\s+([^\s]+)\s+([^\s]+)\s+([^\s]+)/$1, $3 $2 $5/o;
    } else {
      $stime = "BAD DATE FORMAT see Plugins.ActionTrackerPlugin#DateFormats";
    }
    return $stime;
  }

  # PUBLIC return number of days to go before due date, negative if action
  # is late, 0 if it's due today
  sub daysToGo {
    my $this = shift;
    # 60 * 60 * 24 seconds in a days
    $now = time() unless ( defined( $now ) );
    if ( defined( $this->{DUE} )) {
	return ( $this->{DUE} - $now ) / (60 * 60 * 24);
    } else {
	return -1;
    }
  }

  # PUBLIC true if due time is before now and not closed
  sub isLate {
    my $this = shift;
    return ( ($this->{DUE} - $now) <= 0 && $this->{STATE} ne "closed" );
  }

  # PUBLIC true if the action matches the search attributes
  sub matches {
    my ( $this, $a ) = @_;

    if ( defined($a->get("web")) ) {
      my $web = $a->get("web");
      if ( $web ) {
	return 0 unless ( $this->{WEB} =~ /^$web$/ );
      }
    }

    if ( defined($a->get("topic")) ) {
      my $topic = $a->get("topic");
      if ( $topic ) {
	return 0 unless ( $this->{TOPIC} =~ /^$topic$/ );
      }
    }

    if ( defined($a->get("who")) ) {
      my $who = $a->get("who");
      if ( $who ) {
        $who = _canonicalName( $who );
        return 0 unless ( $this->{WHO} eq $who );
      }
    }

    my $state = "";
    if (defined $a->get( "state" )) {
      $state = $a->get( "state" );
    } elsif (defined $a->get( "closed" )) {
      $state = "closed";
    } elsif (defined $a->get( "open" )) {
      $state = "open";
    } elsif (defined $a->get( "late" )) {
      $state = "late";
    }

    if ( $state eq "late" ) {
      return 0 unless $this->daysToGo() < 0 && $this->{STATE} ne "closed";
    } elsif ( $state ) {
      return 0 unless $this->{STATE} eq $state;
    }

    if ( defined($a->get("within")) ) {
      my $within = $a->get("within");
      if ( $within ) {
        return 0 unless $this->daysToGo() <= $within;
      }
    }

    return 1;
  }

  # PUBLIC action formatted as HTML table row
  # Pass $type="name" to to get a jump to a position
  # within the topic, "href" to get a jump. Defaults to "name".
  # Pass $newWindow=1 to get separate browser window,
  # $newWindow=0 to get jump in same window.
  sub formatAsTableData {
    my ( $this, $type, $newWindow ) = @_;

    # Anchor must be a wiki word
    my $anchor = "AcTion" . $this->{ACTION_NUMBER};
    $anchor =~ s/\W+//go;

    my $text = "<td> " . $this->{WHO} . " </td><td";
    if ( !defined($this->{DUE}) ) {
      $text .= " bgcolor=\"$badcol\"";
    } elsif ( $this->isLate() ) {
      $text .= " bgcolor=\"$latecol\"";
    }
    $text .= "> " . $this->dueString();
    #debug $text .= " (" . $this->daysToGo() . " days to go)";
    $text .= " </td><td> ";
    if ( defined( $type ) && $type eq "href" ) {
      # Generate a jump-to in wiki syntax
      my $rest = $this->{TEXT};
      $rest =~ s/<br ?\/?>/\n/sgo;
      $rest =~ s/^([^\n]*)(.*)/$2/so;
      my $fline = $1;
      $text .= "[[" . $this->{WEB} . "." . $this->{TOPIC} . "#$anchor][ ";
      $text .= "$fline ]] $rest";
    } else {
      # Generate an anchor. Can't use wiki syntax for a
      # point that will be in the middle of a table
      my $tmp = $this->{TEXT};
      $tmp =~ s/<br ?\/?>/\n/sgo;
      $text .= "<a name=\"$anchor\"></a> " . $tmp;
    }
    $text .= " </td><td> " . $this->{STATE} . " </td>";

    $text .= "<td><a ";

    my $url = "%SCRIPTURLPATH%/editaction%SCRIPTSUFFIX%/" .
      $this->{WEB} . "/" . $this->{TOPIC} .
	"?action=" . $this->{ACTION_NUMBER};

    if ($newWindow) {
      # Javascript window call
      $text .= "onClick=\"return editWindow('$url')\" ";
    }

    $text .= "href=\"$url\">edit</a></td>";

    return $text;
  }

  # PUBLIC action formatted as a simple string
  sub formatAsString {
    my ( $this, $type ) = @_;

    my $text = "";
    my $sep = " ";
    if ( defined( $type ) && $type eq "href" ) {
      # generate multi line string with link
      $sep = "\n  ";
      my $anchor = "AcTion" . $this->{ACTION_NUMBER};
      $anchor =~ s/[^A-Za-z0-9]//go;
      $text .= TWiki::Func::getViewUrl( $this->{WEB}, $this->{TOPIC} )
             . "#$anchor" . $sep;
    } else {
      # generate single line string without link
      $text .= $this->{WEB} . "." . $this->{TOPIC} . "/"
             . $this->{ACTION_NUMBER} . ":" . $sep;
    }

    if ( $this->{STATE} eq "open" ) {
      $text .= "Open";
    } else {
      $text .= "Closed";
    }
    $text .= " action for " . $this->{WHO} . ", due " . $this->dueString();
    $text .= " (LATE)" if ( $this->isLate() );
    my $descr = $this->{TEXT}; # keep only first line
    $descr =~ s/(<br \/>|\n).*//so;
    $descr =~ s/^\s*//o;
    $text .= ":" . $sep . $descr . $sep;

    return $text;
  }

  # PUBLIC see if this other action matches according to fuzzy
  # rules. Return a number indicating the quality of the match, which
  # is the sum of:
  # action number identical - 3
  # who identical - 2
  # notify identical - 2
  # due identical - 1
  # state identical - 1
  # text identical - length of matching text
  # text sounds match - number of matching sounds
  sub fuzzyMatches {
    my ( $this, $old ) = @_;
    my $sum = 0;

    # identical text
    if ( $this->{TEXT} =~ m/^$old->{TEXT}/ ) {
      $sum += length( $this->{TEXT} );
    } else {
      $sum += _partialMatch( $old->{TEXT}, $this->{TEXT} ) * 4;
    }
    $sum += 3 if ( $this->{ACTION_NUMBER} == $old->{ACTION_NUMBER} );
    $sum += 2 if ( defined( $this->{NOTIFY} ) &&
		   $this->{NOTIFY} == $old->{NOTIFY} );
    $sum += 2 if ( defined( $this->{WHO} ) &&
		   $this->{WHO} eq $old->{WHO} );
    $sum += 1 if ( $this->{DUE} == $old->{DUE} );
    $sum += 1 if ( $this->{STATE} eq $old->{STATE} );

    return $sum;
  }

  # Crude algorithm for matching text. The words in the old text
  # are matched by equality or sound and the proportion of words
  # in the old text still seen in the new text is returned.
  sub _partialMatch {
    my ( $old, $new ) = @_;
    my @aold = split( /\s+/, $old );
    my @anew = split( /\s+/, $new );
    my $matches = 0;
    foreach my $s ( @aold ) {
      for (my $t = 0; $t <= $#anew; $t++) {
	if ( $anew[$t] =~ m/^$s$/i) {
	  $anew[$t] = "";
	  $matches++;
	  last;
	} else {
	  my $so = Text::Soundex::soundex( $s );
	  my $sn = Text::Soundex::soundex( $anew[$t] );
	  if ( $so eq $sn ) {
	    $anew[$t] = "";
	    $matches += 0.75;
	  }
	}
      }
    }
    return $matches / ( $#aold + 1 );
  }

  # PRIVATE STATIC simple compare two strings and return the closeness of
  # the match. Probably could be done much better using String::Approx.

  # PUBLIC find and format differences between this action and another
  # action, adding the changes to a hash keyed on the names of
  # people interested in notification.
  sub gatherNotifications {
    my ( $this, $old, $notifications ) = @_;

    return 0 if ( !$this->{NOTIFY} );

    my $changed = 0;
    my $text = "<table>" . $this->formatAsTableData( "href" ) . "</table>";
    my $curText = $this->{TEXT};

    if ( $this->{STATE} ne $old->{STATE} ) {
      $text .= "\n\t* State changed from *" .
	$old->{STATE} . "* to *" . $this->{STATE} . "*\n";
      $changed = 1;
    }

    if ( $this->{DUE} != $old->{DUE} ) {
      $text .= "\t*Due date changed from *" .
	$old->dueString() . "* to *" . $this->dueString() . "*\n";
      $changed = 1;
    }

    my $oldText = $old->{TEXT};
    $oldText =~ s/[\s\r]+/ /go;

    $curText =~ s/[\s\r]+/ /go;
    if ( $curText ne $oldText ) {
      my $diff = substr($curText, length($oldText));
      $diff =~ s/\s+/ /go;
      $text .= "Text appended ...$diff\n";
      $changed = 1;
    }

    return 0 unless( $changed );

    # Add text to people interested in notification
    # in the hash
    my @notables = split(/\s*,\s*/, $this->{NOTIFY} );
    foreach my $notable ( @notables ) {
      $notifications->{$notable} .= $text;
    }

    return 1;
  }

  # PUBLIC STATIC find the Nth action in the text
  sub findNthAction {
    my ( $web, $topic, $text, $index ) = @_;

    my @lines = split( /\n/, $text );
    my $line;
    my $actionNumber = -1;
    my $action;
    my $pretext = "";
    my $posttext = "";

    foreach $line ( @lines ) {
      if ( $line =~ /(.*)%ACTION{(.*)}%\s*([^\n\r]*)/so ) {
	$actionNumber++;
	if ( $actionNumber == $index ) {
	  $pretext .= $1;
	  $action = Action->new( $web, $topic, $actionNumber++, $2, $3 );
	} elsif ( $actionNumber < $index ) {
	  $pretext .= "$line\n";
	} else {
	  $posttext .= "$line\n";
	}
      } elsif ( $actionNumber < $index ) {
	$pretext .= "$line\n";
      } else {
	$posttext .= "$line\n";
      }
    }
    return ( $action, $pretext, $posttext );
  }
}

1;
