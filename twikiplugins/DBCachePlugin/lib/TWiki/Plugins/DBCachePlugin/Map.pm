#
# Copyright (C) Motorola 2003 - All rights reserved
# Copyright (C) Crawford Currie 2004
#
use strict;

use TWiki::Plugins::DBCachePlugin::Array;

=begin text

---++ class Map
# Generic map object for mapping names to things. A name is defined as
name = \w+ | \w+ "." name
The . indicates a field reference in a sub-map.
Objects in the map are either strings, or other objects that must
support toString.

=cut

{ package DBCachePlugin::Map;

=begin text

---+++ =new($string)=
   * $string - optional attribute string in standard TWiki syntax
Create a new, empty array object. Optionally parse a standard attribute
string containing name=value pairs. The
value may be a word or a quoted string (no escapes!)

=cut

  sub new {
    my ( $class, $string ) = @_;
    my $this = bless( {}, $class );
    $this->{keys} = ();

    if ( defined( $string ) ) {
      my $orig = $string;
      my $n = 1;
      while ( $string !~ m/^[\s,]*$/o ) {
	if ( $string =~ s/^\s*(\w[\w\.]*)\s*=\s*\"(.*?)\"//o ) {
	  $this->set( $1, $2 );
	} elsif ( $string =~ s/^\s*(\w[\w\.]*)\s*=\s*([^\s,\}]*)//o ) {
	  $this->set( $1, $2 );
	} elsif ( $string =~ s/^\s*\"(.*?)\"//o ) {
	  $this->set( "\$$n", $1 );
	  $n++;
	} elsif ( $string =~ s/^\s*(\w[\w+\.]*)\b//o ) {
	  $this->set( $1, "on" );
	} elsif ( $string =~ s/^[^\w\.\"]//o ) {
	  # skip bad char or comma
	} else {
	  # some other problem
	  die "DBCachePlugin: Badly formatted attribute string at '$string' in '$orig'";
	}
      }
    }
    return $this;
  }

  # PUBLIC dispose of this map, breaking any circular references
  sub DESTROY {
    my $this = shift;
    #print STDERR "Destroy ",ref($this),"\n";
    $this->{keys} = undef;
    # should be enough; nothing else should be pointing to the keys
  }

=begin text

---+++ =fastget($k)= -> datum
   * =$k= - key
Get the value for a key, but without any subfield field expansion

=cut

  sub fastget {
    my ( $this, $attr ) = @_;
    return $this->{keys}{$attr};
  }

=begin text

---+++ =get($k)= -> datum
   * =$k= - key
Get the value corresponding to this key; return undef if not set.
If =$k= is a string of the form =X.Y= then the result will be the
result of calling =get("Y")= on the object in this map that matches =X=.

Note that if X is a DBCachePlugin::Array, Y may be an integer index, or the name of a field
in the class of the objects stored by X. In the latter case, =get= will return the result
of calling =X->sum("Y")=.

=cut

  sub get {
    my ( $this, $attr ) = @_;
    if ( index( $attr, "." ) > 0 && $attr =~ m/^(\w+)\.(\w+.*)$/o ) {
      my $field = $2;
      $attr = $this->{keys}{$1};
      if ( defined( $attr ) && ref( $attr )) {
		return $attr->get( $field );
      } else {
		return undef;
      }
    } else {
      return $this->{keys}{$attr};
    }
  }

=begin text

---+++ =set($k, $v)=
   * =$k= - key
   * =$v= - value
Set the given key, value pair in the map.

=cut

 sub set {
    my ( $this, $attr, $val ) = @_;
    if ( $attr =~ m/^(\w+)\.(.*)$/o ) {
      $attr = $1;
      my $field = $2;
      if ( !defined( $this->{keys}{$attr} )) {
	$this->{keys}{$attr} = new DBCachePlugin::Map();
      }
      $this->{keys}{$attr}->set( $field, $val );
    } else {
      $this->{keys}{$attr} = $val;
    }
  }

=begin text

---+++ =size()= -> integer
Get the size of the map

=cut

  sub size {
    my $this = shift;

    return scalar( keys( %{$this->{keys}} ));
  }

=begin text

---+++ =remove($index)= -> old value
   * =$index= - integer index
Remove an entry at an index from the array. Return the old value.

=cut

  sub remove {
    my ( $this, $attr ) = @_;

    if ( $attr =~ m/^(\w+)\.(.*)$/o && ref( $this->{keys}{$attr} )) {
      $attr = $1;
      my $field = $2;
      return $this->{keys}{$attr}->remove( $field );
    } else {
      my $val = $this->{keys}{$attr};
      delete( $this->{keys}{$attr} );
      return $val;
    }
  }

=begin text

---+++ =getKeys()= -> perl array

Get a "perl" array of the keys in the map, suitable for use with =foreach=

=cut

  sub getKeys {
    my $this = shift;

    return keys( %{$this->{keys}} );
  }

=begin text

---+++ =getValues()= -> perl array

Get a "perl" array of the values in the Map, suitable for use with =foreach=

=cut

  sub getValues {
    my $this = shift;

    return values( %{$this->{keys}} );
  }

=begin text

---+++ =search($search)= -> search result
   * =$search* =DBCachePlugin::Search object to use in the search
Search the map for keys that match with the given object.
values. Return a =DBCachePlugin::Array= of matching keys.

=cut

  sub search {
    my ( $this, $search ) = @_;
    my $result = new DBCachePlugin::Array();

    foreach my $meta ( values( %{$this->{keys}} )) {
      if ( $search->matches( $meta )) {
		$result->add( $meta );
      }
    }

    return $result;
  }

=begin text

---+++ =toString($limit, $level, $strung)= -> string
   * =$limit= - recursion limit for expansion of elements
   * =$level= - currentl recursion level
Generates an HTML string representation of the object.

=cut

  sub toString {
    my ( $this, $limit, $level, $strung ) = @_;
    if ( !defined( $strung )) {
      $strung = {};
    } elsif ( $strung->{$this} ) {
      return "$this";
    }
    $level = 0 unless (defined($level));
    $limit = 2 unless (defined($limit));
    if ( $level == $limit ) {
      return "$this.....";
    }
    $strung->{$this} = 1;
    my $key;
    my $ss = "$this<ul>";
    foreach $key ( keys %{$this->{keys}} ) {
      $ss .= "<li>$key = ";
      my $entry = $this->{keys}{$key};
      if ( ref( $entry )) {
	$ss .= $entry->toString( $limit, $level + 1, $strung );
      } elsif ( defined( $entry )) {
	$ss .= "\"$entry\"";
      } else {
	$ss .= "UNDEF";
      }
      $ss .= "</li>";
    }
    return "$ss</ul>";
  }

=begin text

---+++ write($archive)
   * =$archive= - the DBCachePlugin::Archive being written to
Writes this object to the archive. Archives are used only if Storable is not available. This
method must be overridden by subclasses is serialisation of their data fields is required.

=cut

  sub write {
    my ( $this, $archive ) = @_;

    $archive->writeInt( $this->size());
    foreach my $key ( keys %{$this->{keys}} ) {
      $archive->writeObject( $key );
      $archive->writeObject( $this->{keys}{$key} );
    }
  }

=begin text

---+++ read($archive)
   * =$archive= - the DBCachePlugin::Archive being read from
Reads this object from the archive. Archives are used only if Storable is not available. This
method must be overridden by subclasses is serialisation of their data fields is required.

=cut

  sub read {
    my ( $this, $archive ) = @_;

    my $sz = $archive->readInt();
    while ( $sz-- > 0 ) {
      my $key = $archive->readObject();
      $this->{keys}{$key} = $archive->readObject();
    }
  }
}

1;
