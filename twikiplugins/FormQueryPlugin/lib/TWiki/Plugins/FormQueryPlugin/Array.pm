#
# Copyright (C) Motorola 2003 - All rights reserved
#
use strict;
use Carp;

# Generic array object
{ package FormQueryPlugin::Array;

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
    my $more;

    if ( $field =~ s/(\w+)\.(.*)/$1/o ) {
      $more = $2;
    }

    foreach my $meta ( @{$this->{values}} ) {
      if ( ref( $meta )) {
	my $fieldval = $meta->get( $field );
	if ( defined( $fieldval )) {
	  if ( defined( $more )) {
	    $sum += $fieldval->sum( $more );
	  } else {
	    $sum += $fieldval;
	  }
	}
      }
    }

    return $sum;
  }

  # PRIVATE search the array for matches with the given field
  # values. Return a list of matched topics..
  sub search {
    my ( $this, $search ) = @_;
    my $result = new FormQueryPlugin::Array();

    return $result unless ( $this->size() > 0 );

    foreach my $meta ( @{$this->{values}} ) {
      if ( $search->matches( $meta )) {
	$result->add( $meta );
      }
    }

    return $result;
  }

  sub getValues {
    my $this = shift;

    return undef unless (defined( $this->{values} ));
    return @{$this->{values}};
  }

  sub toString {
    my $this = shift;
    my $ss = "[";
    if ( $this->size() > 0 ) {
      foreach my $entry ( @{$this->{values}} ) {
	$ss .= "," if $ss ne "[";
	if ( ref( $entry )) {
	  $ss .= $entry->toString();
	} else {
	  $ss .= "\"" . $entry . "\"";
	}
      }
    }
    return "$ss]";
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
