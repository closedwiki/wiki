#
# Copyright (C) Motorola 2003 - All rights reserved
#
use strict;

use TWiki::Plugins::FormQueryPlugin::Array;

# Generic map object for mapping names to things. A name is defined as
# name = \w+ | \w+ "." name
# The . indicates a field reference in a sub-map.
# Objects in the map are either strings, or other objects that must also
# support tostring.
{ package FormQueryPlugin::Map;

  # Constructor. Optionally parse a standard attribute
  # string containing name=value pairs. The
  # value may be a word or a quoted string (no escapes!)
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
	  die "FORMQUERYPLUGIN: Badly formatted attribute string at '$string' in '$orig'";
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

  # PUBLIC Get an attr value; return undef if not set.
  # Supports subfields.
  sub get {
    my ( $this, $attr ) = @_;
    if ( index( $attr, "." ) > 0 && $attr =~ m/^(\w+)\.(.*)$/o ) {
      my $field = $2;
      $attr = $this->{keys}{$1};
      if ( defined( $attr )) {
	return $attr->get( $field );
      } else {
	return undef;
      }
    } else {
      return $this->{keys}{$attr};
    }
  }

  # PUBLIC Get an attr value; return undef if not set
  sub set {
    my ( $this, $attr, $val ) = @_;
    if ( $attr =~ m/^(\w+)\.(.*)$/o ) {
      $attr = $1;
      my $field = $2;
      if ( !defined( $this->{keys}{$attr} )) {
	$this->{keys}{$attr} = new FormQueryPlugin::Map();
      }
      $this->{keys}{$attr}->set( $field, $val );
    } else {
      $this->{keys}{$attr} = $val;
    }
  }

  # PUBLIC return the size of this map, which is the number of keys
  sub size {
    my $this = shift;

    return scalar( keys( %{$this->{keys}} ));
  }

  # PUBLIC remove an attr value, return old value
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

  # PUBLIC get a list of keys in the map
  sub getKeys {
    my $this = shift;

    return keys( %{$this->{keys}} );
  }

  # PUBLIC get a list of values in the map
  sub getValues {
    my $this = shift;

    return values( %{$this->{keys}} );
  }

  # PUBLIC search the map for matches with the given field
  # values. Return a list of matched topics. The search object
  # must implement "matches".
  sub search {
    my ( $this, $search ) = @_;
    my $result = new FormQueryPlugin::Array();

    foreach my $topic ( $this->getKeys() ) {
      my $meta = $this->get( $topic );
      if ( $search->matches( $meta )) {
	$result->add( $meta );
      }
    }
 
    return $result;
  }

  # PUBLIC debug print
  sub toString {
    my ( $this, $strung ) = @_;
    if ( !defined( $strung )) {
      $strung = {};
    } elsif ( $strung->{$this} ) {
      return "$this\{...\}";
    }
    $strung->{$this} = 1;
    my $key;
    my $ss = "$this\{ ";
    foreach $key ( keys %{$this->{keys}} ) {
      $ss .= " $key=";
      my $entry = $this->{keys}{$key};
      if ( ref( $entry )) {
	$ss .= $entry->toString( $strung );
      } elsif ( defined( $entry )) {
	$ss .= "\"$entry\"";
      } else {
	$ss .= "UNDEF";
      }
    }
    return $ss." }";
  }

  sub write {
    my ( $this, $archive ) = @_;

    $archive->writeInt( $this->size());
    foreach my $key ( keys %{$this->{keys}} ) {
      $archive->writeObject( $key );
      $archive->writeObject( $this->{keys}{$key} );
    }
  }

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
