#
# Copyright (C) Motorola 2003 - All rights reserved
# Copyright (C) Crawford Currie 2004
#
use strict;

=begin text

---++ class Array

Generic array object. This is required because perl arrays are not objects, and
cannot be subclassed e.g. for serialisation. To avoid lots of horrid code to handle
special cases of the different perl data structures, we use this array object instead.

=cut

{ package DBCachePlugin::Array;

=begin text

---+++ =new()=
Create a new, empty array object

=cut

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

=begin text

---+++ =add($object)=
   * =$object= any perl data type
Add an element to the end of the array

=cut

  sub add {
    my $this = shift;
    return push( @{$this->{values}}, shift );
  }

=begin text

---+++ =find($object)= -> integer
   * $object datum of the same type as the content of the array
Uses "==" to find the given element in the array and return it's index

=cut

  sub find {
    my ( $this, $obj ) = @_;
    my $i = 0;
    foreach my $meta ( @{$this->{values}} ) {
      return $i if ( $meta == $obj );
      $i++;
    }
    return -1;
  }

=begin text

---+++ =remove($index)=
   * =$index= - integer index
Remove an entry at an index from the array.

=cut

  sub remove {
    my ( $this, $i ) = @_;
    splice( @{$this->{values}}, $i, 1 );
  }

=begin text

---+++ =get($index)= -> object
   * =$index= - integer index
Get the element at an index. if =$index= is not an integer, will return the result
of $this->sum($index)

=cut

  sub get {
    my ( $this, $index ) = @_;
	if ( $index !~ /^\d+$/ ) {
     return $this->sum( $index );
	}

    return undef unless ( $this->size() > $index );
    return $this->{values}[$index];
  }

=begin text

---+++ =size()= -> integer
Get the size of the array

=cut

  sub size {
    my $this = shift;
    return 0 unless ( defined( $this->{values} ));
    return scalar( @{$this->{values}} );
  }

=begin text

---+++ =sum($field)= -> number
   * =$field= - name of a field in the class of objects stored by this array
Returns the sum of values of the given field in the objects stored in this array.

=cut

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

=begin text

---+++ =search($search)= -> search result
   * =$search* =DBCachePlugin::Search object to use in the search
Search the array for matches with the given object.
values. Return a =DBCachePlugin::Array= of matching entries.

=cut

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

=begin text

---+++ =getValues()= -> perl array

Get a "perl" array of the values in the array, suitable for use with =foreach=

=cut

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

=begin text

---+++ write($archive)
   * =$archive= - the DBCachePlugin::Archive being written to
Writes this object to the archive. Archives are used only if Storable is not available. This
method must be overridden by subclasses is serialisation of their data fields is required.

=cut

  sub write {
    my ( $this, $archive ) = @_;

    my $sz = $this->size();
    $archive->writeInt( $sz );
    foreach my $v ( @{$this->{values}} ) {
      $archive->writeObject( $v );
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
      push( @{$this->{values}}, $archive->readObject() );
    }
  }
}

1;
