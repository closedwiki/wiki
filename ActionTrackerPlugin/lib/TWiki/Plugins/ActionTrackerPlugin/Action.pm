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

# Object that represents a single action

# Fields:
# web           Web the action was found in
# topic         Topic the action was found in
# ACTION_NUMBER The number of the action in the topic (deprecated)
# text          The text of the action
# who           The person responsible for the action
# due           When the action is due
# notify        List of people to notify when the action changes
# uid           Unique identifier for the action
# creator       Who created the action
# created       When the action was created
# closer        Who closed the action
# closed        When the action was closed

{ package Action;

  use vars qw ( $latecol $badcol $hdrcol $border );

  # Colour for warning of late actions
  $latecol = "yellow";
  # Colour for an unparseable date
  $badcol = "red";
  # Colour for table header rows
  $hdrcol = "orange";
  # Border width for tables
  $border = "1";

  my $now = time();
  my $mainweb = TWiki::Func::getMainWebname();

  # Options for parsedate
  my %pdopt = ( NO_RELATIVE => 1, DATE_REQUIRED => 1, whoLE => 1 );

  # TODO: get this map from somewhere else
  my %attrTypes = (
		   'who'=>'names',
		   'due'=>'date',
		   'creator'=>'names',
		   'created'=>'date',
		   'closed'=>'date',
		   'closer'=>'names',
		   'notify'=>'names',
		   'topic'=>'ignore',
		   'web'=>'ignore',
		   'ACTION_NUMBER'=>'ignore',
		  );

  # PUBLIC Constructor
  sub new {
    my ( $class, $web, $topic, $number, $attrs, $descr ) = @_;
    my $this = {};

    my $attr = new ActionTrackerPlugin::Attrs( $attrs );

    $this->{state} = (( $attr->get( "closed" )) ? "closed" : "open" );

    foreach my $key ( keys %$attr ) {
      my $type = $attrTypes{$key};
      my $val = $attr->get( $key );
      if ( defined( $type ) && $type eq 'names' && defined( $val )) {
	my @names = split( /[,\s]+/, $val );
	foreach my $n ( @names ) {
	  $n = _canonicalName( $n );
	}
	$this->{$key} = join( ',', @names );
      } elsif ( defined( $type ) && $type eq 'date' && defined( $val )) {
	$this->{$key} =
	  Time::ParseDate::parsedate( $val, %pdopt );
      } elsif ( !(defined( $type ) && $type eq 'ignore' )) {
	# treat as plain string
	$this->{$key} = $attr->get( $key );
      }
    }

    $this->{web} = $web;
    $this->{topic} = $topic;
    $this->{ACTION_NUMBER} = $number;
    $descr =~ s/^\s+//o;
    $descr =~ s/\s+$//o;
    $this->{text} = $descr;

    return bless( $this, $class );
  }

  # PUBLIC when a topic containing an action is about to be saved,
  # populate these fields for the action.
  # Note: This will put a wrong date on closed actions if they were
  # closed a long while ago, but that's life.
  sub populateMissingFields {
    my $this = shift;
    my $me = _canonicalName( TWiki::Func::getWikiName() );

    if ( !defined($this->{uid} )) {
      $this->{uid} = $this->{web} . $this->{topic} .
	  formatTime( $now, "uid" ) . "n" . $this->{ACTION_NUMBER};
    }

    if ( !defined( $this->{who} )) {
      $this->{who} = $me;
    }

    if ( !defined( $this->{created} )) {
      $this->{created} = $now;
      $this->{creator} = $me;
    }

    if ( $this->{state} eq "closed" && !defined( $this->{closed} )) {
      $this->{closed} = $now;
      $this->{closer} = $me;
    }
  }

  # PUBLIC format as an action
  sub toString {
    my $this = shift;
    my $attrs = "";
    my $descr = "";
    foreach my $key ( keys %$this ) {
      my $type = $attrTypes{$key};
      if ( $key eq 'text') {
	$descr = $this->{text};
	$descr =~ s/^\s*(.*)\s*$/$1/o;
      } elsif ( defined( $type ) && $type eq 'date' ) {
	$attrs .= " $key=\"" .
	  formatTime( $this->{$key}, "attr" ) . "\"";
      } elsif ( !(  defined( $type ) && $type eq 'ignore' ) ) {
	# treat as plain text
	$attrs .= " $key=\"" . $this->{$key} . "\"";
      }
    }
    return "%ACTION{$attrs }% $descr";
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

  # PRIVATE get the anchor of this action
  sub getAnchor {
    my $this = shift;

    my $anchor = $this->{uid};
    if ( !$anchor ) {
      # required for old actions without uids
      $anchor = "AcTion" . $this->{ACTION_NUMBER};
    }

    return $anchor;
  }

  # PRIVATE STATIC format a time string
  sub formatTime {
    my ( $time, $format ) = @_;
    my $stime;
    if ( defined $time ) {
      if ( $format eq "attr" ) {
        $stime = localtime( $time );
	$stime =~ s/(\w+)\s+(\w+)\s+(\w+)\s+([^\s]+)\s+(\w+).*/$3-$2-$5/o;
      } elsif ( $format eq "uid" ) {
	my @els = localtime( $time );
	$stime = "$els[5]$els[6]$els[2]$els[1]$els[0]";
      } else {
        $stime = localtime( $time );
	$stime =~ s/(\w+)\s+(\w+)\s+(\w+)\s+([^\s]+)\s+(\w+).*/$1, $3 $2 $5/o;
      }
    } else {
      $stime = "BAD DATE FORMAT see Plugins.ActionTrackerPlugin#DateFormats";
    }
    return $stime;
  }

  # PUBLIC due time, as a date string
  sub dueString {
    my $this = shift;
    return formatTime( $this->{due}, "string" );
  }

  # PUBLIC return number of days to go before due date, negative if action
  # is late, 0 if it's due today
  sub daysToGo {
    my $this = shift;
    # 60 * 60 * 24 seconds in a days
    $now = time() unless ( defined( $now ) );
    if ( defined( $this->{due} )) {
	return ( $this->{due} - $now ) / (60 * 60 * 24);
    }
    return -1;
  }

  # PUBLIC true if due time is before now and not closed
  sub isLate {
    my $this = shift;
    return ( ($this->{due} - $now) <= 0 && $this->{state} ne "closed" );
  }

  # PRIVATE match the passed value against the corresponding field
  sub _match_who {
    my ( $this, $val ) = @_;
    my $who = _canonicalName( $val );
    return ( defined( $this->{who} ) && $this->{who} =~ /$who/ );
  }

  # PRIVATE match the passed value against the corresponding field
  sub _match_within {
    my ( $this, $val ) = @_;
    return ( $this->daysToGo() <= $val );
  }

  # PRIVATE match the passed value against the corresponding field
  sub _match_notify {
    my ( $this, $val ) = @_;
    my $notify = _canonicalName( $val );
    return ( defined($this->{notify}) &&  $this->{notify} =~ /$notify/ );
  }

  # PRIVATE match the passed value against the corresponding field
  sub _match_closed {
    my $this = shift;
    return ( $this->{state} eq "closed" );
  }

  # PRIVATE match the passed value against the corresponding field
  sub _match_open {
    my $this = shift;
    return ( $this->{state} eq "open" );
  }

  # PRIVATE match the passed value against the corresponding field
  sub _match_late {
    my $this = shift;
      TWiki::Func::writeDebug("Match LATE ".( $this->daysToGo() < 0 && $this->{state} ne "closed" )?"MATCH":"UNMATCH");
    return ( $this->daysToGo() < 0 && $this->{state} ne "closed" ) ? 1 : 0;
  }

  # PRIVATE this is required even though it doesn't actually do
  # anything. This is because the existance of the attribute in the
  # test expression would cause matches() to fail, because the action
  # doesn't have the field.
  sub _match_changedsince {
    return 1;
  }

  # PUBLIC true if the action matches the search attributes
  # The match is made either by calling a match function for the attribute
  # or by comparing the value of the field with the value of the
  # corresponding attribute, which is considered to be an RE.
  sub matches {
    my ( $this, $a ) = @_;
    TWiki::Func::writeDebug($this->toString());
    foreach my $key ( keys %$a ) {
      my $expr = $a->get( $key );

      TWiki::Func::writeDebug("Match $key");
      if ( defined( &{ref( $this ) . "::_match_$key"} ) ) {
	# function match
	my $fn = "_match_$key";
	return 0 unless ( $this->$fn( $expr ));
      } elsif ( defined( $expr ) && defined( $this->{$key} ) ) {
	# re match
	return 0 unless ( $this->{$key} =~ m/$expr/ );
      } else {
	return 0;
      }
    }
    return 1;
  }

  # PUBLIC action formatted as HTML table row
  # Pass $type="name" to to get a jump to a position
  # within the topic, "href" to get a jump. Defaults to "name".
  # Pass $newWindow=1 to get separate browser window,
  # $newWindow=0 to get jump in same window.
  sub formatAsHTML {
    my ( $this, $type, $format, $newWindow ) = @_;

    my $row = $format->fillInHTML( $this, $type, $newWindow );

    if ( $type eq "name" ) {
      $row = "<a name=\"" . $this->getAnchor() . "\"></a>$row";
    }

    return $row;
  }

  # PUBLIC action formatted as a simple string
  sub formatAsString {
    my ( $this, $format ) = @_;

    return $format->fillInString( $this );
  }

  # PRIVATE format the given field
  sub _format_closed {
    my $this = shift;
    return ( formatTime( $this->{closed}, "string" ), 0 );
  }

  # PRIVATE format the given field
  sub _format_created {
    my $this = shift;

    return ( formatTime( $this->{created}, "string" ), 0 );
  }

  # PRIVATE format the given field
  sub _format_due {
    my $this = shift;
    my $bgcol = 0;
    my $text = formatTime( $this->{due}, "string" );

    if ( !defined($this->{due}) ) {
      $bgcol = $badcol;
    } elsif ( $this->isLate() ) {
      $bgcol = $latecol;
      $text .= " (LATE)";
    }

    return ( $text, $bgcol );
  }

  # PRIVATE format text field
  sub _format_text {
    my ( $this, $asHTML, $type ) = @_;
    my $text = $this->{text};

    if ( $asHTML && defined( $type ) && $type eq "href" ) {
      # Generate a jump-to in wiki syntax
      my $rest = $text;
      $rest =~ s/<br ?\/?>/\n/sgo;
      $rest =~ s/^([^\n]*)(.*)/$2/so;
      my $fline = $1;
      # escape wikiwords
      $fline =~ s/\b([A-Z]+[a-z]+[A-Z]+\w*)\b/<nop>$1/go;

      $text = "[[" . $this->{web} . "." . $this->{topic} .
	"#" . $this->getAnchor() . "][$fline]]$rest";
    }
    return ( $text, 0 );
  }

  # PRIVATE format state field
  sub _format_state {
    my ( $this ) = @_;
    my $text = $this->{state};

#    if ( $this->{state} eq "closed" && $this->{closed} ) {
#      $text .= " on " . formatTime( $this->{closed}, "string" );
#      if ( $this->{closer} ) {
#	$text .= " by " . $this->{closer};
#      }
#    }
    return ( $text, 0 );
  }

  # PRIVATE format edit field
  sub _format_edit {
    my ( $this, $asHTML, $type, $newWindow ) = @_;

    return "" unless ( $asHTML );

    my $url = "%SCRIPTURLPATH%/edit%SCRIPTSUFFIX%/" .
      $this->{web} . "/" . $this->{topic} .
	"?skin=action&action=" . $this->getAnchor();
    my $text = "<a href=\"$url\"";
    if ( $newWindow ) {
      # Javascript window call
      $text .= " onClick=\"return editWindow('$url')\"";
    }
    return ( "${text}>edit</a>", 0 );
  }

  # PRIVATE format the given field
  sub _format_uid {
    my ( $this, $asHTML ) = @_;
    my $uid = $this->{uid};
    return "<nop>$uid" if ( $asHTML );
    return ( $uid, 0 );
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

    return 100 if ( defined( $this->{uid} ) &&
		    "$this->{uid}" eq "$old->{uid}" );
    return 0 if ( defined( $this->{uid} ) &&
		  "$this->{uid}" ne "$old->{uid}" );

    # identical text
    if ( $this->{text} =~ m/^\Q$old->{text}\E/ ) {
      $sum += length( $this->{text} );
    } else {
      $sum += _partialMatch( $old->{text}, $this->{text} ) * 4;
    }
    $sum += 3 if ( $this->{ACTION_NUMBER} == $old->{ACTION_NUMBER} );
    $sum += 2 if ( defined( $this->{notify} ) && defined( $old->{notify} ) &&
		   $this->{notify} == $old->{notify} );
    $sum += 2 if ( defined( $this->{who} ) &&
		   $this->{who} eq $old->{who} );
    $sum += 1 if ( $this->{due} == $old->{due} );
    $sum += 1 if ( $this->{state} eq $old->{state} );

    return $sum;
  }

  # PRIVATE Crude algorithm for matching text. The words in the old text
  # are matched by equality or sound and the proportion of words
  # in the old text still seen in the new text is returned.
  sub _partialMatch {
    my ( $old, $new ) = @_;
    my @aold = split( /\s+/, $old );
    my @anew = split( /\s+/, $new );
    my $matches = 0;
    foreach my $s ( @aold ) {
      for (my $t = 0; $t <= $#anew; $t++) {
	if ( $anew[$t] =~ m/^\Q$s\E$/i) {
	  $anew[$t] = "";
	  $matches++;
	  last;
	} else {
	  my $so = Text::Soundex::soundex( $s ) || "";
	  my $sn = Text::Soundex::soundex( $anew[$t] ) || "";
	  if ( $so eq $sn ) {
	    $anew[$t] = "";
	    $matches += 0.75;
	  }
	}
      }
    }
    return $matches / ( $#aold + 1 );
  }

  # PUBLIC find and format differences between this action and another
  # action, adding the changes to a hash keyed on the names of
  # people interested in notification.
  sub findChanges {
    my ( $this, $old, $format, $notifications ) = @_;

    return 0 if ( !$this->{notify} );

    my $changes = $format->getStringChanges( $old, $this );
    return 0 if ( $changes eq "" );

    my $plain_text = $this->formatAsString( $format ) . "\n$changes\n";
    my $html_text = "<table>" . $this->formatAsHTML( "href", $format, 0 ) .
      "</table>\n" . $format->getHTMLChanges( $old, $this );

    # Add text to people interested in notification
    # in the hash
    my @notables = split(/[,\s]+/, $this->{notify} );
    foreach my $notable ( @notables ) {
      $notable = _canonicalName( $notable );
      $notifications->{$notable}{html} .= $html_text;
      $notifications->{$notable}{text} .= $plain_text;
    }

    return 1;
  }

  # PUBLIC STATIC find the action in the text with the given uid
  sub findActionByUID {
    my ( $web, $topic, $text, $uid ) = @_;

    my $action;
    my $pretext = "";
    my $posttext = "";
    my $found = 0;
    my $an = 0;
    my $sn = -1;
    if ( $uid =~ m/^AcTion(\d+)$/o ) {
      $sn = $1;
    }

    foreach my $line ( split( /[\r\n]+/, $text ) ) {
      if ( $line =~ /(.*)%ACTION{(.*?)}%\s*([^\n\r]*)/so ) {
	my $anAction = Action->new( $web, $topic, $an, $2, $3 );
	if ( $anAction->{uid} eq $uid || $an == $sn ) {
	  $pretext .= $1;
	  $found = 1;
	  $action = $anAction;
	} elsif ( $found ) {
	  $posttext .= "$line\n";
	} else {
	  $pretext .= "$line\n";
	}
	$an++;
      } elsif ( $found ) {
	$posttext .= "$line\n";
      } else {
	$pretext .= "$line\n";
      }
    }
    if ( !$action ) {
      TWiki::Func::writeDebug("Action not found $uid");
    }
    return ( $action, $pretext, $posttext );
  }
}

1;
