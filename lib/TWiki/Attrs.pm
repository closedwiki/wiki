#
# Copyright (C) 2005 Crawford Currie - http://c-dot.co.uk
#
# Derived from Contrib::Attrs, which is
# Copyright (C) 2001 Motorola - All rights reserved
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

=pod

---+ package TWiki::Attrs
Class of attribute sets, designed for parsing and storing attribute values
from a TWiki tag e.g. =%TAG{fred="bad" "sad" joe="mad"}%=

An attribute set is a map containing an entry for each parameter. The
default parameter (unnamed quoted string) is named <code>_<nop>DEFAULT</code> in the map.

Attributes declared later in the string will override those of the same
name defined earlier. The one exception to this is the _DEFAULT key, where
the _first_ instance of a setting is always taken.

As well as standard TWiki syntax (parameter values double-quoted)
it also parses single-quoted values, unquoted spaceless
values, spaces around the =, and commas as well as spaces separating values,
though none of these alternatives is advertised in documentation and
the extended syntax can be turned off by passing the "strict" parameter
to =new=.

This class replaces the old TWiki::extractNameValuePair and
TWiki::extractParameters.

=cut

package TWiki::Attrs;

use strict;
use Assert;

my $ERRORKEY = "_ERROR";
my $DEFAULTKEY = "_DEFAULT";

=pod

---++ ClassMethod new ($string, $strict) => \%attrsObjectRef
   * =$string= - String containing attribute specification
   * =$strict= - if true, the parse will be strict as per traditional TWiki syntax.

Parse a standard attribute string containing name=value pairs and create a new
attributes object. The value may be a word or a quoted string. If there is an
error during parsing, the parse will complete but $attrs->{_ERROR} will be
set in the new object.

Example:
<verbatim>

my $attrs = new TWiki::Attrs('the="time has come", "the walrus" said to=speak of='many things', 1);
</verbatim>
In this example:
   * =the= will be =time has come=
   * <code>_<nop>_<nop>default__</code> will be =the walrus=
   * =said= will be =on=
   * =to= will be =speak=
   * =of= will be =many things=

=cut

sub new {
    my ( $class, $string, $strict ) = @_;
    my $this = bless( {}, $class );

    return $this unless defined( $string );

    $string =~ s/\\(["'])/"\0".sprintf("%.2u", ord($1))/ge;  # escapes

    my $sep = ( $strict ? "\\s" : "[\\s,]" );

    while ( $string =~ m/\S/ ) {
        # name="value" pairs
        if ( $string =~ s/^$sep*(\w+)\s*=\s*\"(.*?)\"//i ) {
            $this->{$1} = $2;
        }
        # name='value' pairs
        elsif ( !$strict &&
                $string =~ s/^$sep*(\w+)\s*=\s*'(.*?)'//i ) {
            $this->{$1} = $2;
        }
        # name=value pairs
        elsif ( !$strict &&
                $string =~ s/^$sep*(\w+)\s*=\s*([^\s,\}\'\"]*)//i ) {
            $this->{$1} = $2;
        }
        # simple double-quoted value with no name, sets the default
        elsif ( $string =~ s/^$sep*\"(.*?)\"//o ) {
            $this->{$DEFAULTKEY} = $1
              unless defined( $this->{$DEFAULTKEY} );
        }
        # simple single-quoted value with no name, sets the default
        elsif ( !$strict &&
                $string =~ s/^$sep*'(.*?)'//o ) {
            $this->{$DEFAULTKEY} = $1
              unless defined( $this->{$DEFAULTKEY} );
        }
        # simple name with no value (boolean, or _DEFAULT)
        elsif ( !$strict &&
                $string =~ s/^$sep*([a-z]\w*)\b// ) {
            $this->{$1} = "1";
            $this->{$DEFAULTKEY} = $1
              unless defined( $this->{$DEFAULTKEY} );
        }
        # otherwise the whole string - sans padding - is the default
        else {
            $string =~ s/^\s*(.*)\s*$/$1/;
            $this->{$DEFAULTKEY} = $string
              unless defined( $this->{$DEFAULTKEY} );
            last;
        }
    }
    foreach my $k ( keys %$this ) {
        $this->{$k} =~ s/\0(\d\d)/chr($1)/ge;  # escapes
    }
    return $this;
}

=pod

---++ ObjectMethod isEmpty() -> boolean
Return false if attribute set is not empty.

=cut

sub isEmpty {
  my $this = shift;

  ASSERT( ref( $this ) eq "TWiki::Attrs" ) if DEBUG;

  return !scalar(%$this);
}

=pod

---++ ObjectMethod remove($key) -> $value
| $key | Attribute to remove |
Remove an attr value from the map, return old value. After a call to
=remove= the attribute is no longer defined.

=cut

sub remove {
  my ( $this, $attr ) = @_;
  ASSERT( ref( $this ) eq "TWiki::Attrs" ) if DEBUG;
  my $val = $this->{$attr};
  delete( $this->{$attr} ) if ( exists $this->{$attr} );
  return $val;
}

=pod

---++ ObjectMethod stringify() -> $string
Generate a printed form for the map, using standard
attribute syntax, with only the single-quote extension
syntax observed (no {} brackets, though).

=cut

sub stringify {
  my $this = shift;
  ASSERT( ref( $this ) eq "TWiki::Attrs" ) if DEBUG;
  my $key;
  my @ss;
  foreach $key ( keys %$this ) {
	if ( $key ne $ERRORKEY ) {
	  my $es = ( $key eq $DEFAULTKEY ) ? "" : "$key=";
	  my $val = $this->{$key};
      $val =~ s/"/\\"/g;
      push( @ss, "$es\"$val\"" );
	}
  }
  return join( " ", @ss );
}

1;
