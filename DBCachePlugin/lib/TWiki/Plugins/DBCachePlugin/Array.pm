#
# Copyright (C) Motorola 2003 - All rights reserved
#
use strict;

# Generic array object
{ package DBCachePlugin::Array;

  sub new {
    my $class = shift;
    my $this = {};

    # this leaves {values} undefined!???
    # PRIVATE the actual array
    $this->{values} = ();

    return bless( $this, $class );
  }

  # PUBLIC dispose of this array, breaking any circular references
  sub DESTROY {
    my $this = shift;
    #print STDERR "Destroy ",ref($this),"\n";
    $this->{values} = undef;
    # should be enough; nothing else should be pointing to the array
  }

  # PUBLIC add an element to the end of the array
  sub add {
    my $this = shift;
    return push( @{$this->{values}}, shift );
  }

  # PUBLIC find the given element in the array and
  # return it's index
  sub find {
    my ( $this, $obj ) = @_;
    my $i = 0;
    foreach my $meta ( @{$this->{values}} ) {
      return $i if ( $meta == $obj );
      $i++;
    }
    return -1;
  }

  # PUBLIC remove an entry at an index from the array.
  sub remove {
    my ( $this, $i ) = @_;
    splice( @{$this->{values}}, $i, 1 );
  }

  # PUBLIC get the element at an index or, if the parameter is a string,
  # the sum of a field
  sub get {
    my ( $this, $index ) = @_;
    # there's gotta be a better way than this.....
    if ( $index !~ /^\d+$/ ) {
      return $this->sum( $index );
    }
    return undef unless ( $this->size() > $index );
    return $this->{values}[$index];
  }

  # PUBLIC get the size of the array
  sub size {
    my $this = shift;
    return 0 unless ( defined( $this->{values} ));
    return scalar( @{$this->{values}} );
  }

  # PUBLIC
  # sum the values in a field in the objects at each position in the
  # array
  sub sum {
    my ( $this, $field ) = @_;
    return 0 if ( $this->size() == 0 );

    my $sum = 0;
    my $subfields;

    if ( $field =~ s/(\w+)\.(.*)/$1/o ) {
      $subfields = $2;
    }

    foreach my $meta ( @{$this->{values}} ) {
      if ( ref( $meta )) {
	my $fieldval = $meta->get( $field );
	if ( defined( $fieldval ) ) {
	  if ( defined( $subfields )) {
	    die "$field has no subfield $subfields" unless ( ref( $fieldval ));
	    $sum += $fieldval->sum( $subfields );
	  } elsif ( $fieldval =~ m/^\s*\d+/o ) {
	    $sum += $fieldval;
	  }
	}
      }
    }

    return $sum;
  }

  sub contains {
    my ( $this, $tv ) = @_;
    return ( $this->find( $tv ) >= 0 );
  }

  # PRIVATE search the array for matches with the given field
  # values. Return a list of matched topics..
  sub search {
    my ( $this, $search ) = @_;
    my $result = new DBCachePlugin::Array();

    return $result unless ( $this->size() > 0 );

    foreach my $meta ( @{$this->{values}} ) {
      if ( $search->matches( $meta )) {
	$result->add( $meta );
      }
    }

    return $result;
  }

  # For some reason when an empty array is restored from Storable,
  # getValues gives us a one-element array. Archive doesn't,
  # it gives us a nice empty array. With storable, the one
  # entry is undef.
  sub getValues {
    my $this = shift;

    return undef unless ( defined( @{$this->{values}} ));
    # does this return the array by reference? probably not...
    return @{$this->{values}};
  }

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
    my $ss = "$this<ol start=0>";
    if ( $this->size() > 0 ) {
      my $n = 0;
      foreach my $entry ( @{$this->{values}} ) {
	$ss .= "<li>";
	if ( ref( $entry )) {
	  $ss .= $entry->toString( $limit, $level + 1, $strung );
	} elsif ( defined( $entry )) {
	  $ss .= "\"$entry\"";
	} else {
	  $ss .= "UNDEF";
	}
	$ss .= "</li>";
	$n++;
      }
    }
    return "$ss</ol>";
  }

  sub write {
    my ( $this, $archive ) = @_;

    my $sz = $this->size();
    $archive->writeInt( $sz );
    foreach my $v ( @{$this->{values}} ) {
      $archive->writeObject( $v );
    }
  }

  sub read {
    my ( $this, $archive ) = @_;
    my $sz = $archive->readInt();
    while ( $sz-- > 0 ) {
      push( @{$this->{values}}, $archive->readObject() );
    }
  }
}

1;
