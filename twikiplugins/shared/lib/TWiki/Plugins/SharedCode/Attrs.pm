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

---+ Package TWiki::Attrs
Class of attribute sets, designed for parsing and storing attribute values
from a TWiki tag e.g. %TAG{fred="bad" "sad" joe="mad"}%

An attribute set is a map containing an entry for each parameter. The
default parameter (unnamed quoted string) is named __<nop>default__ in the map.
Attributes declared later in the string will override those of the same
name defined earlier. Escaping quotes is _not_ supported.

The parser is forgiving; it will handle standard TWiki syntax (parameter
values double-quoted) but also single-quoted values, unquoted spaceless
values, and spaces around the =.

=cut
package TWiki::Attrs;
=pod

---+ new ($string) => Attrs object ref
| $string | String containing attribute specification |
Parse a standard attribute string containing name=value pairs and create a new
attributes object. The value may be a word or a quoted string. Will throw
an exception (by dieing) if there is a problem.

=cut
sub new {
  my ( $class, $string ) = @_;
  my $this = {};
  my $orig = $string;

  if ( defined( $string ) ) {
	while ( $string =~ m/\S/o ) {
	  # name="value" pairs
	  if ( $string =~ s/^[\s,]*([a-z]\w*)\s*=\s*\"(.*?)\"//io ) {
		$this->{$1} = $2;
	  }
	  # name='value' pairs
	  elsif ( $string =~ s/^[\s,]*([a-z]\w*)\s*=\s*'(.*?)'//io ) {
		$this->{$1} = $2;
	  }
	  # name=value pairs
	  elsif ( $string =~ s/^[\s,]*([a-z]\w*)\s*=\s*([^\s,\}\'\"]*)//io ) {
		$this->{$1} = $2;
	  }
	  # simple quoted value with no name, sets the key "__default__"
	  elsif ( $string =~ s/^[\s,]*\"(.*?)\"//o ) {
		$this->{"__default__"} = $1;
	  }
	  # simple quoted value with no name, sets the key "__default__"
	  elsif ( $string =~ s/^[\s,]*'(.*?)'//o ) {
		$this->{"__default__"} = $1;
	  }
	  # simple name with no value (boolean)
	  elsif ( $string =~ s/^[\s,]*([a-z]\w*)\b//o ) {
		$this->{$1} = "1";
	  } else {
		die "Bad attribute list at '$string' in '$orig'";
	  }
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

--++ isEmpty() => boolean
Return false if attribute set is not empty.

=cut
sub isEmpty {
  my $this = shift;
  return !scalar(%$this);
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
attribute syntax, with only the single-quote extension
syntax observed (no {} brackets, though).

=cut
sub toString {
  my $this = shift;
  my $key;
  my @ss;
  foreach $key ( keys %$this ) {
	my $es = ( $key eq "__default__" ) ? "" : "$key=";
	my $val = $this->{$key};
	if ( $val =~ m/\"/o ) {
	  push( @ss, "$es'$val'" );
	} else {
	  push( @ss, "$es\"$val\"" );
	}
  }
  return join( " ", @ss );
}

# end of class Attrs

1;
