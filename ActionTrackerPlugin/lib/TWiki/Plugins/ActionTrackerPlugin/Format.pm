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

# Object that represents a header and fields format

{ package Format;

  # PUBLIC Constructor
  # $header is the format of the HTML table header representation
  # $fields is the format of the HTML table body respresentation
  # $textform is the format of the text representation
  # $changeFields is the comma-separated list of fields to detect changes
  # in.
  sub new {
    my ( $class, $header, $fields, $textform, $changeFields ) = @_;

    my $this = {};

    $header =~ s/^\s*\|//so;
    $header =~ s/\|\s*$//so;
    my @heads = split( /\|/, $header );

    $fields =~ s/^\s*\|//so;
    $fields =~ s/\|\s*$//so;
    my @bodies = split( /\|/, $fields );

    while ( $#bodies < $#heads ) {
      push( @bodies, "" );
    }

    while ( $#heads < $#bodies ) {
      push( @heads, "" );
    }

    @{$this->{HEADINGS}} = @heads;
    @{$this->{FIELDS}} = @bodies;

    $this->{TEXTFORM} = $textform;

    $changeFields =~ s/\s//go;
    $changeFields =~ s/\$//go;
    @{$this->{CHANGEFIELDS}} = split( /,/, $changeFields );

    return bless( $this, $class );
  }

  # PUBLIC return the format as attributes
  sub toString() {
    my $this = shift;

    return "header=\"|" . join( "|", @{$this->{HEADINGS}} ) . "|\" " .
      "format=\"|" . join( "|", @{$this->{FIELDS}} ) . "|\" " .
	"textform=\"" . $this->{TEXTFORM} . "\" ".
	  "changefields=\"" . join( ",", @{$this->{CHANGEFIELDS}} ) . "\"";
  }

  # PRIVATE expand a var using one of:
  # a function called $object->_format_$var()
  # the field $object->{$var}
  # or return the name of the var
  # The function returns a tuple of ( text, colour ). The value 0 is
  # treated as the default colour.
  sub _expandVar {
    my $object = shift;
    my $vbl = shift;
    if ( defined( &{ref( $object ) . "::_format_$vbl"} ) ) {
      my $fn = "_format_$vbl";
      return $object->$fn( @_ );
    } elsif ( defined( $object->{$vbl} ) ) {
      return ( $object->{$vbl}, 0 );
    } else {
      return ( "\$$vbl", 0 );
    }
  }

  # PRIVATE STATIC fill in variable expansions in simple text form
  sub _expandString {
    my ( $t, $c ) = _expandVar( @_ );
    return $t;
  }

  # PUBLIC fill in the text template using values
  # extracted from the given object
  sub fillInString {
    my $this = shift;
    my $object = shift;
    my $fmt = "";

    my $fmt = $this->{TEXTFORM};
    $fmt =~ s/\$dollar(\(\))?\b/\$/gos;
    $fmt =~ s/\$nop(\(\))?\b//gos;
    $fmt =~ s/\$n(\(\))?\b/\n/gos;
    $fmt =~ s/\$percnt(\(\))?\b/\%/gos;
    $fmt =~ s/\$quot(\(\))?\b/\"/gos;
    $fmt =~ s/\$(\w+)(\(\))?/&_expandString( $object, $1, 0, @_ )/geos;

    return $fmt;
  }

  # PRIVATE STATIC fill in variable expansions. If any of the expansions
  # returns a non-zero color, then fill in the passed-by-reference color
  # variable $col with the value returned.
  sub _expandHTML {
    my $col = shift;
    my ( $t, $c ) = _expandVar( @_ );
    $$col = $c if ( $c );
 
    return "$t";
  }

  # PUBLIC fill in the HTML template using values
  # extracted from the given object
  sub fillInHTML {
    my $this = shift;
    my $object = shift;

    my $fmt = "";
    foreach my $i ( @{$this->{FIELDS}} ) {
      my $col = $i;
      my $c;
      $col =~ s/\$(\w+)(\(\))?/&_expandHTML( \$c, $object, $1, 1, @_ )/geos;
      $col =~ s/\$dollar(\(\))?\b/\$/gos;
      $col =~ s/\$nop(\(\))?\b//gos;
      $col =~ s/\$n(\(\))?\b/<br \/>/gos;
      $col =~ s/\$percnt(\(\))?\b/%/gos;
      $col =~ s/\$quot(\(\))?\b/\"/gos;

      if ( $c ) {
	$col = "<td bgcolor=\"$c\">$col</td>";
      } else {
	$col = "<td>$col</td>";
      }
      $fmt .= $col;
    }

    return $fmt;
  }

  # PUBLIC get the HTML formatted header row
  sub getHTMLHeads {
    my ( $this ) = @_;
    my $fmt = "";
    foreach my $i ( @{$this->{HEADINGS}} ) {
      if ( $i ne "" ) {
	$fmt .= "<th>$i</th>";
      } else {
	$fmt .= "<th>&nbsp;</th>";
      }
    }
    return $fmt;
  }

  # PUBLIC Get the changes in the change fields between the old object and
  # the new object.
  sub getHTMLChanges {
    my ( $this, $old, $new ) = @_;
    my $tbl = "";
    foreach my $field ( @{$this->{CHANGEFIELDS}} ) {
      if ( defined( $old->{$field} ) && defined( $new->{$field} )) {
	my ( $oldval, $c ) = _expandVar( $old, $field );
	my ( $newval, $d ) = _expandVar( $new, $field );
	if ( $oldval ne $newval ) {
	  $tbl .= "<tr><td>$field</td><td>$oldval</td><td>$newval</td></tr>\n";
	}
      } elsif ( defined( $old->{$field} ) ) {
	my ( $oldval, $c ) = _expandVar( $old, $field );
	$tbl .= "<tr><td>$field</td><td>$oldval</td><td> *removed* </td></tr>\n";
      } elsif ( defined( $new->{$field} )) {
	my ( $newval, $c ) = _expandVar( $new, $field );
	$tbl .= "<tr><td>$field</td><td> *missing* </td><td>$newval</td></tr>\n";
      }
    }
    if ( $tbl ne "" ) {
      return "<table><tr><th>Attribute</th>".
	"<th>Old</th><th>New</th></tr>\n$tbl</table>";
    }
    return $tbl;
  }

  # PUBLIC Get the changes in the change fields between the old object and
  # the new object.
  sub getStringChanges {
    my ( $this, $old, $new ) = @_;
    my $tbl = "";
    foreach my $field ( @{$this->{CHANGEFIELDS}} ) {
      if ( defined( $old->{$field} ) && defined( $new->{$field} ) ) {
	my ( $oldval, $c ) = _expandVar( $old, $field );
	my ( $newval, $d ) = _expandVar( $new, $field );
	if ( $oldval ne $newval ) {
	  $tbl .= "\t- Attribute \"$field\" changed, was \"$oldval\", now \"$newval\"\n";
	}
      } elsif ( defined( $old->{$field} ) ) {
	my ( $oldval, $c ) = _expandVar( $old, $field );
	$tbl .= "\t- Attribute \"$field\" was \"$oldval\" now removed\n";
      } elsif ( defined( $new->{$field} ) ) {
	my ( $newval, $c ) = _expandVar( $new, $field );
	$tbl .= "\t- Attribute \"$field\" added with value \"$newval\"\n";
      }
    }
    return $tbl;
  }
}

1;
