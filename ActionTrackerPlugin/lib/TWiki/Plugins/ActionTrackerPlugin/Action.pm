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

use CGI;

use TWiki::Func;

use Text::Soundex;
use Time::ParseDate;

use TWiki::Plugins::ActionTrackerPlugin::Attrs;
use TWiki::Plugins::ActionTrackerPlugin::AttrDef;
use TWiki::Plugins::ActionTrackerPlugin::Format;

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
{ package ActionTrackerPlugin::Action;

  my $now = time();
  my $mainweb = TWiki::Func::getMainWebname();

  # Options for parsedate
  my %pdopt = ( NO_RELATIVE => 1, DATE_REQUIRED => 1, WHOLE => 1 );

  # Types of standard attributes. The 'noload' type tells us
  # not to load the hash from %ACTION attributes, and the 'nomatch' type
  # tells us not to consider it during match operations.
  # Types are defined as a base type and a comma-separated list of
  # format attributes. Two meta-type components 'noload' and 'nomatch'
  # are defined. If an attribute is defined 'noload' no attempt will
  # be made to load a value for it when the action is created. If it
  # is defined 'nomatch' then the attribute will be ignored in match
  # expressions.
  my %types =
    (
     changedsince =>
     new ActionTrackerPlugin::AttrDef( 'ignore', 0, 0, 0, undef ),
     closed       =>
     new ActionTrackerPlugin::AttrDef( 'date',  13, 1, 0, undef ),
     closer       =>
     new ActionTrackerPlugin::AttrDef( 'names', 25, 1, 0, undef ),
     created      =>
     new ActionTrackerPlugin::AttrDef( 'date',  13, 1, 0, undef ),
     creator      =>
     new ActionTrackerPlugin::AttrDef( 'names', 25, 1, 0, undef ),
     dollar       =>
     new ActionTrackerPlugin::AttrDef( 'ignore', 0, 0, 0, undef ),
     due          =>
     new ActionTrackerPlugin::AttrDef( 'date',  13, 1, 0, undef ),
     edit         =>
     new ActionTrackerPlugin::AttrDef( 'ignore', 0, 0, 0, undef ),
     format       =>
     new ActionTrackerPlugin::AttrDef( 'ignore', 0, 0, 0, undef ),
     header       =>
     new ActionTrackerPlugin::AttrDef( 'ignore', 0, 0, 0, undef ),
     late         =>
     new ActionTrackerPlugin::AttrDef( 'ignore', 0, 0, 0, undef ),
     n            =>
     new ActionTrackerPlugin::AttrDef( 'ignore', 0, 0, 0, undef ),
     nop          =>
     new ActionTrackerPlugin::AttrDef( 'ignore', 0, 0, 0, undef ),
     notify       =>
     new ActionTrackerPlugin::AttrDef( 'names', 25, 1, 0, undef ),
     percnt       =>
     new ActionTrackerPlugin::AttrDef( 'ignore', 0, 0, 0, undef ),
     quot         =>
     new ActionTrackerPlugin::AttrDef( 'ignore', 0, 0, 0, undef ),
     sort         =>
     new ActionTrackerPlugin::AttrDef( 'ignore', 0, 0, 0, undef ),
     state        =>
     new ActionTrackerPlugin::AttrDef( 'select', 1, 1, 1,
				       [ "open","closed" ] ),
     text         =>
     new ActionTrackerPlugin::AttrDef( 'ignore', 0, 1, 0, undef ),
     topic        =>
     new ActionTrackerPlugin::AttrDef( 'ignore', 0, 1, 0, undef ),
     uid          =>
     new ActionTrackerPlugin::AttrDef( 'text',  10, 1, 0, undef ),
     web          =>
     new ActionTrackerPlugin::AttrDef( 'ignore', 0, 1, 0, undef ),
     who          =>
     new ActionTrackerPlugin::AttrDef( 'names', 25, 1, 0, undef ),
     within       =>
     new ActionTrackerPlugin::AttrDef( 'ignore', 0, 1, 0, undef ),
     ACTION_NUMBER=>
     new ActionTrackerPlugin::AttrDef( 'ignore', 0, 0, 0, undef ),
    );
  
  # PUBLIC Constructor
  sub new {
    my ( $class, $web, $topic, $number, $attrs, $descr ) = @_;
    my $this = {};
    
    my $attr = new ActionTrackerPlugin::Attrs( $attrs );

    # We always have a state, and if it's not defined in the
    # attribute set, and the closed attribute isn't defined,
    # then it takes the value of the first option in the
    # enum for the state attribute. If the closed attribute is
    # defined it takes the last enum.
    $this->{state} = $attr->get( "state" );
    if ( !defined( $this->{state} )) {
      if ( $attr->get( "closed" )) {
	$this->{state} = "closed";
      } else {
	$this->{state} = $types{state}->firstSelect();
      }
    }

    # conditionally load field values, interpreting them
    # according to their type.
    foreach my $key ( keys %$attr ) {
      my $type = getBaseType( $key ) || "ignore";
      my $val = $attr->get( $key );
      if ( $type eq "names" && defined( $val )) {
	my @names = split( /[,\s]+/, $val );
	foreach my $n ( @names ) {
	  $n = _canonicalName( $n );
	}
	$this->{$key} = join( ',', @names );
      } elsif ( $type eq "date" ) {
	if ( defined( $val )) {
	  $this->{$key} = Time::ParseDate::parsedate( $val, %pdopt );
	}
      } elsif ( $type ne "ignore" ) {
	# treat as plain string; text, select
	$this->{$key} = $attr->get( $key );
      }
    }

    # do these last so they override and attribute values
    $this->{web} = $web;
    $this->{topic} = $topic;
    $this->{ACTION_NUMBER} = $number;
    $descr =~ s/^\s+//o;
    $descr =~ s/\s+$//o;
    $descr =~ s/\n\n/<p \/>/gos;
    $descr =~ s/\n/<br \/>/gos;
    $this->{text} = $descr;

    return bless( $this, $class );
  }

  # PUBLIC STATIC extend the range of types accepted by actions.
  # Return undef if everything went OK, or error message if not.
  # The range of types is extended statically; once extended, there's
  # no way to unextend them.
  # Format of a type def is described in ActionTrackerPlugin.txt
  sub extendTypes {
    my $defs = shift;
    $defs =~ s/^\s*\|//o;
    $defs =~ s/\|\s*$//o;
    foreach my $def ( split( /\|/, $defs )) {
      if ( $def =~ m/^\s*(\w+)\s*,\s*(\w+)\s*(,\s*(\d+)\s*)?(,\s*(.*))?$/o ) {
	my $name = $1;
	my $type = $2;
	my $size = $4;
	my $params = $6;
	my @values;
	my $exists = $types{$name};

	if ( defined( $exists ) && !$exists->isRedefinable() ) {
	  return "Attempt to redefine attribute '$name' in EXTRAS";
	} elsif ( $type eq "select" ) {
	  @values = split( /\s*,\s*/, $params );
	  foreach my $option ( @values ) {
	    $option =~ s/^\s*\"(.*)\"\s*$/$1/o;
	  }
	}
	$types{$name} =
	  new ActionTrackerPlugin::AttrDef( $type, $size, 1, 1, @values );
      } else {
	return "Bad EXTRAS definition '$def' in EXTRAS";
      }
    }
    return undef;
  }

  # PUBLIC get the base type of an attribute name i.e.
  # with the formatting attributes stripped off.
  sub getBaseType {
    my $vbl = shift;
    my $type = $types{$vbl};
    return $type->{type} if ( defined( $type ) );
    return undef;
  }

  # PUBLIC provided as part of the contract with Format.
  sub getType {
    my ( $this, $name ) = @_;

    return $types{$name};
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
      my $type = $types{$key};
      if ( $key eq 'text') {
	$descr = $this->{text};
	$descr =~ s/^\s*(.*)\s*$/$1/os;
      } elsif ( defined( $type )) {
	if ( $type->{type} eq 'date' ) {
	  $attrs .= " $key=\"" .
	    formatTime( $this->{$key}, "attr" ) . "\"";
	} elsif ( $type->{type} ne 'ignore' ) {
	  # select or text; treat as plain text
	  $attrs .= " $key=\"" . $this->{$key} . "\"";
	}
      }
    }
    return "%ACTION{$attrs }% $descr";
  }

  # PRIVATE STATIC make a canonical name (including the web) for a user
  # unless it's an email address.
  sub _canonicalName {
    my $who = shift;

    return undef if !defined( $who );
    if ( $who !~ /([A-Za-z0-9\.\+\-\_]+\@[A-Za-z0-9\.\-]+)/ ) {
      $who = TWiki::Func::getWikiName() if ( $who eq "me" );
      $who = "$mainweb.$who" unless $who =~ /\./o;
    }
    return $who;
  }

  # PUBLIC For testing only, force current time to a known value
  sub forceTime {
    my $tim = shift;
    $now = Time::ParseDate::parsedate( $tim );
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
	# year yearday hour min sec
	$stime = "$els[5]$els[7]$els[2]$els[1]$els[0]";
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

  # PUBLIC return number of seconds to go before due date, negative if action
  # is late
  sub secsToGo {
    my $this = shift;
    $now = time() unless ( defined( $now ) );
    if ( defined( $this->{due} )) {
      return $this->{due} - $now;
    }
    return -1;
  }

  # PUBLIC return number of days to go before due date, negative if action
  # is late, 0 if it's due today
  sub daysToGo {
    my $this = shift;
    my $delta = $this->secsToGo();
    # if less that 24h late, make it a day late
    if ( $delta < 0 && $delta > -(60 * 60 * 24 )) {
      return -1;
    } else {
      return $delta / (60 * 60 * 24);
    }
  }

  # PUBLIC true if due time is before now and not closed
  sub isLate {
    my $this = shift;
    return 0 if ( $this->{state} eq "closed" );
    return ( ($this->{due} - $now) <= 0 );
  }

  # PRIVATE match the passed names against the given names type field.
  # The match passes if any of the names passed matches any of the
  # names in the field.
  sub _matchType_names {
    my ( $this, $vbl, $val ) = @_;
    return 0 unless defined( $this->{$vbl} );
    foreach my $name ( split( /\s*,\s*/, $val )) {
      my $who = _canonicalName( $name );
      $who =~ s/\./\\./go;
      return 1 if ( $this->{$vbl} =~ /$who/ );
    }
    return 0;
  }

  sub _matchType_date {
    my ( $this, $vbl, $val ) = @_;
    my $tim = Time::ParseDate::parsedate( $val, %pdopt );
    return ( defined( $this->{$vbl} ) && $this->{$vbl} == $tim );
  }

  # PRIVATE match if there are at least $val days to go before
  # action falls due
  sub _matchField_within {
    my ( $this, $val ) = @_;
    return ( $this->secsToGo() <= $val * 60 * 60 * 24 );
  }

  # PRIVATE match the passed value against the corresponding field
  sub _matchField_closed {
    my $this = shift;
    return ( $this->{state} eq "closed" );
  }

  # PRIVATE match the passed value against the corresponding field
  sub _matchField_open {
    my $this = shift;
    return ( $this->{state} ne "closed" );
  }

  # PRIVATE match the passed value against the corresponding field
  sub _matchField_late {
    my $this = shift;
    return ( $this->secsToGo() < 0 && $this->{state} ne "closed" ) ? 1 : 0;
  }

  # PUBLIC true if the action matches the search attributes
  # The match is made either by calling a match function for the attribute
  # or by comparing the value of the field with the value of the
  # corresponding attribute, which is considered to be an RE.
  # To match, an action must match all conditions.
  sub matches {
    my ( $this, $a ) = @_;
    foreach my $attrName ( keys %$a ) {
      my $attrVal = $a->get( $attrName );
      my $attrType = getBaseType( $attrName );
      my $class = ref( $this );
      if ( defined( &{$class."::_matchField_$attrName"} ) ) {
	# function match
	my $fn = "_matchField_$attrName";
	return 0 unless ( $this->$fn( $attrVal ));
      } elsif ( defined( $attrType ) &&
		defined( &{$class."::_matchType_$attrType"} ) ) {
	my $fn = "_matchType_$attrType";
	return 0 unless ( $this->$fn( $attrName, $attrVal ));
      } elsif ( defined( $attrType ) &&
		$attrType =~ m/nomatch/o ) {
	# do nothing
      } elsif ( defined( $attrVal ) &&
		defined( $this->{$attrName} ) ) {
	# re match
	return 0 unless ( $this->{$attrName} =~ m/$attrVal/ );
      } else {
	return 0;
      }
    }
    return 1;
  }

  # PRIVATE format the given time type
  sub _formatType_date {
    my $this = shift;
    my $fld = shift;
    return ( formatTime( $this->{$fld}, "string" ), 0 );
  }

  # PRIVATE format the given field (takes precedence of standard
  # date formatting)
  sub _formatField_due {
    my $this = shift;
    my $bgcol = 0;
    my $text = formatTime( $this->{due}, "string" );

    if ( !defined($this->{due}) ) {
      $bgcol = $ActionTrackerPlugin::Format::badcol;
    } elsif ( $this->isLate() ) {
      $bgcol = $ActionTrackerPlugin::Format::latecol;
      $text .= " (LATE)";
    }

    return ( $text, $bgcol );
  }

  # PRIVATE format text field
  sub _formatField_text {
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
	"#" . $this->getAnchor() . "][ $fline ]]$rest";
    }
    return ( $text, 0 );
  }

  # PRIVATE format edit field
  sub _formatField_edit {
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

  # PRIVATE format the UID field
  sub _formatField_uid {
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
		   $this->{notify} eq $old->{notify} );
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

    my $changes = $format->formatChangesAsString( $old, $this );
    return 0 if ( $changes eq "" );

    my $plain_text = $format->formatStringTable( [ $this ] );
    $plain_text .= "\n$changes\n";
    my $html_text = $format->formatHTMLTable( [ $this ], "href", 0 );
    $html_text .= $format->formatChangesAsHTML( $old, $this );

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
	my $anAction = new ActionTrackerPlugin::Action( $web, $topic, $an, $2, $3 );
	my $auid = $anAction->{uid};
	if ( ( defined( $auid ) && $auid eq $uid ) || $an == $sn ) {
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

  # PUBLIC STATIC create a new action filling in attributes
  # from a CGI query as used in the action edit.
  sub createFromQuery {
    my ( $web, $topic, $an, $query ) = @_;
    my $desc = $query->param( "text" ) || "No description";
    $desc =~ s/\r?\n\r?\n/ <p \/>/sgo;
    $desc =~ s/\r?\n/ <br \/>/sgo;

    # for each of the legal attribute types, see if the query
    # contains a value for that attribute. If it does, fill it
    # in. Must ignore text.
    my $attrs = "";
    foreach my $attrname ( keys %types ) {
      my $type = $types{$attrname};
      if ( $attrname ne 'text' && $type->{type} ne 'ignore' ) {
	my $val = $query->param( $attrname );
	$attrs .= " $attrname=\"$val\"" if ( defined( $val ));
      }
    }
    return new ActionTrackerPlugin::Action( $web, $topic, $an, $attrs, $desc );
  }
}

1;
