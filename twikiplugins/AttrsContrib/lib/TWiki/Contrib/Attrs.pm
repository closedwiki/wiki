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

=begin text

---+ Package TWiki::Contrib::Attrs
Class of attribute sets, designed for parsing and storing attribute values
from a TWiki tag e.g. =%TAG{fred="bad" "sad" joe="mad"}%=

An attribute set is a map containing an entry for each parameter. The
default parameter (unnamed quoted string) is named <code>__<nop>default__</code> in the map.
Attributes declared later in the string will override those of the same
name defined earlier. Escaping quotes is _not_ supported.

The parser is forgiving; it will handle standard TWiki syntax (parameter
values double-quoted) but also single-quoted values, unquoted spaceless
values, spaces around the =, and commas as well as spaces separating values.

=cut

package TWiki::Contrib::Attrs;

use vars qw( $VERSION );

$VERSION = '1.000';

my $ERRORKEY = "__error__";
my $DEFAULTKEY = "__default__";

=begin text

---++ new ($string) => Attrs object ref
| $string | String containing attribute specification |
Parse a standard attribute string containing name=value pairs and create a new
attributes object. The value may be a word or a quoted string. If there is an
error during parsing, the parse will complete but $this->{__error__} will be
set in the new object.

Example:
<verbatim>
use TWiki::Contrib::Attrs;
my $attrs = new TWiki::Contrib::Attrs('the="time has come", "the walrus" said to=speak of='many things');
</verbatim>
In this example:
   * =the= will be =time has come=
   * <code>_<nop>_<nop>default__</code> will be =the walrus=
   * =said= will be =on=
   * =to= will be =speak=
   * =of= will be =many things=

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
	  # simple double-quoted value with no name, sets the key __default__
	  elsif ( $string =~ s/^[\s,]*\"(.*?)\"//o ) {
		$this->{$DEFAULTKEY} = $1;
	  }
	  # simple single-quoted value with no name, sets the key __default__
	  elsif ( $string =~ s/^[\s,]*'(.*?)'//o ) {
		$this->{$DEFAULTKEY} = $1;
	  }
	  # simple name with no value (boolean)
	  elsif ( $string =~ s/^[\s,]*([a-z]\w*)\b//o ) {
		$this->{$1} = "1";
	  # try and clean up
	  } else {
		$this->{$ERRORKEY} = "Bad attribute list at '$string' in '$orig'"
		  unless ( $this->{$ERRORKEY} );
		$string =~ s/^.//o;
	  }
	}
  }
  return bless( $this, $class );
}

=begin text

---++ get( $key) => value
| $key | Attribute name |
Get an attr value; return undef if not set

=cut

sub get {
  my ( $this, $attr ) = @_;
  return $this->{$attr};
}

=begin text

---++ isEmpty() => boolean
Return false if attribute set is not empty.

=cut

sub isEmpty {
  my $this = shift;
  return !scalar(%$this);
}

=begin text

---++ remove($key) => value
| $key | Attribute to remove |
Remove an attr value from the map, return old value. After a call to
=remove= the attribute is no longer defined.

=cut

sub remove {
  my ( $this, $attr ) = @_;
  my $val = $this->{$attr};
  delete( $this->{$attr} ) if ( $val );
  return $val;
}

=begin text

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
	if ( $key ne $ERRORKEY ) {
	  my $es = ( $key eq $DEFAULTKEY ) ? "" : "$key=";
	  my $val = $this->{$key};
	  if ( $val =~ m/\"/o ) {
		push( @ss, "$es'$val'" );
	  } else {
		push( @ss, "$es\"$val\"" );
	  }
	}
  }
  return join( " ", @ss );
}

# end of class Attrs

1;
