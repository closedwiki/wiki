#
# Copyright (C) Motorola 2001 - All rights reserved
#
# TWiki extension that adds tags for the generation of tables of contents.
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

=begin twiki

---+ Package TWiki::Plugins::Attrs
Class of attribute sets.
An attribute set is a map containing an entry for each parameter. The
default parameter (quoted string) is named "__default__" in the map.
Attributes declared later in the string will override those of the same
name defined earlier.

=cut

=pod

---+ new ($string) => Attrs object ref
| $string | String containing attribute specification |
Parse a standard attribute string containing name=value pairs and create a new
attributes object. The value may be a word or a quoted string (no escapes!)

=cut
sub new {
  my ( $class, $string ) = @_;
  my $this = {};

  if ( defined( $string ) ) {
    # name="value" pairs
    while ( $string =~ s/([a-z]\w+)\s*=\s*\"([^\"]*)\"//io ) {
      $this->{$1} = $2;
    }
    # name=value pairs
    while ( $string =~ s/([a-z]\w+)\s*=\s*([^\s,\}]*)//io ) {
      $this->{$1} = $2;
    }
    # simple quoted value with no name; only one allowed;
    # sets the key "__default__"
    if ( $string =~ s/\"(.*?)\"//o ) {
      $this->{"__default__"} = $1;
    }
    # simple name with no value (boolean)
    while ( $string =~ s/([a-z]\w+)\b//o ) {
      $this->{$1} = "on";
    }
  }
  return bless( $this, $class );
}

=pod

--++ get( $key) => value
| $key | Attribute name |
Get an attr value; return undef if not set

=cut
sub get {
  my ( $this, $attr ) = @_;
  return $this->{$attr};
}

=pod

---++ remove($key) => value
Remove an attr value from the map, return old value

=cut
sub remove {
  my ( $this, $attr ) = @_;
  my $val = $this->{$attr};
  delete( $this->{$attr} ) if ( $val );
  return $val;
}

=pod

---++ toString() => string
Generate a printed form for the map, using standard
attribute syntax (no {} brackets, though).

=cut
sub toString {
  my $this = shift;
  my $key;
  my $ss = "";
  foreach $key ( keys %$this ) {
    if ( $key eq "__default__" ) {
      $ss = " \"" . $this->{$key} . "\"$ss";
    } else {
      $ss .= " $key=\"" . $this->{$key} . "\"";
    }
  }
  return "{$ss }";
}

# end of class Attrs

1;
