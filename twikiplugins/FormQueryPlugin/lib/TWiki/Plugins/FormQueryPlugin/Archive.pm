#
# Copyright (C) Motorola 2003 - All rights reserved
#
use strict;
use FileHandle;
use Carp;

#
# Simple file archive storer and restorer. Handles serialising objects
# using their "write" and "read" methods. Serialisable objects must
# have a no-parameters constructor.
#
# This module is only used if Storable isn't available. Storable is
# much faster, because it is implemented in C.
#
{ package FormQueryPlugin::Archive;

  # PUBLIC create a new archive, using filename $file and
  # mode $rw which must be "r" or "w". The archive will remain
  # in existence (and the file remain open) until "close" is
  # called. An exclusive lock is taken for write as long as the file
  # is open.
  sub new {
    my ( $class, $file, $rw ) = @_;
    
    my $this = {};
    $this->{FH} = new FileHandle( $file, $rw );
    if ( !defined( $this->{FH} )) {
      Carp::croak "Open $file failed";
    }
    $this->{OBJECTINDEX} = 0;
    $this->{lock} = $rw;
    if ( $rw eq "w" ) {
      # get an exclusive lock on the file
      flock( *{$this->{FH}}, 2 );
    }

    return bless( $this, $class );
  }

  # If we enable this, it seems to close the file immediately!
  sub DESTROY {
    my $this = shift;
    $this->close();
  }

  # PUBLIC close this archive. MUST be called to
  # close the file.
  sub close {
    my $this = shift;
    if ( defined( $this->{FH} )) {
      if ( $this->{lock} eq "w" ) {
	flock( *{$this->{FH}}, 8 );
      }
      $this->{FH}->close();
      $this->{FH} = undef;
    }
  }

  # PUBLIC write a byte to the archive
  sub writeByte {
    my ( $this, $b ) = @_;
    syswrite( $this->{FH}, $b, 1 );
  }

  # PUBLIC write a string to the archive
  sub writeString {
    my ( $this, $s ) = @_;
    my $l = length( $s );
    syswrite( $this->{FH}, pack( "S", $l ).$s, 2 + $l );
  }
  
  # PUBLIC write a 32-bit integer to the archive
  sub writeInt {
    my ( $this, $i ) = @_;
    syswrite( $this->{FH}, pack( "i", $i ), 4 );
  }
  
  # PUBLIC write an object to the archive. An object must implement
  # read() and write(), or may be undef or a string. No other types
  # are supported.
  sub writeObject {
    my ( $this, $o ) = @_;
    
    if ( !defined( $o )) {
      syswrite( $this->{FH}, 'U', 1 );
    } elsif ( defined( $this->{refs}{$o} )) {
      syswrite( $this->{FH}, "R".pack( "i", $this->{refs}{$o} ), 5 );
    } else {
      $this->{refs}{$o} = $this->{OBJECTINDEX}++;
      if ( ref( $o )) {
	my $s = ref( $o );
	my $l = length( $s );
	syswrite( $this->{FH},
		  "O" . pack( "i", $this->{refs}{$o} ) . pack( "S", $l ) . $s,
		  5 + 2 + $l );
	$o->write( $this );
      } else {
	my $l = length( $o );
	syswrite( $this->{FH},
		  "S" . pack( "i", $this->{refs}{$o} ) . pack( "S", $l ) . $o,
		  5 + 2 + $l );
      }
    }
  }

  # PUBLIC read a byte from the archive
  sub readByte {
    my $this = shift;

    my $b; sysread( $this->{FH}, $b, 1 );
    return $b;
  }

  # PUBLIC read a UTF8 string from the archive
  sub readString {
    my $this = shift;
    
    my $l; sysread( $this->{FH}, $l, 2 );
    my $o; sysread( $this->{FH}, $o, unpack( "s", $l ));

    return $o;
  }
  
  # PUBLIC read a 32-bit integer from the archive
  sub readInt {
    my $this = shift;
    
    my $o; sysread( $this->{FH}, $o, 4 );
    return unpack( "i", $o );
  }
  
  # PUBLIC read an object from the archive
  sub readObject {
    my $this = shift;
    
    my $key; sysread( $this->{FH}, $key, 1 );

    if ( $key eq 'R' ) {
      my $o; sysread( $this->{FH}, $o, 4 );
      my $id = unpack( "i", $o );
      return $this->{ids}[$id];
    } elsif ( $key eq 'S' ) {
      my $o; sysread( $this->{FH}, $o, 4 );
      my $id = unpack( "i", $o );
      my $l; sysread( $this->{FH}, $l, 2 );
      sysread( $this->{FH}, $o, unpack( "s", $l ));
      $this->{ids}[$id] = $o;
      return $o;
    } elsif ( $key eq 'O' ) {
      my $o; sysread( $this->{FH}, $o, 4 );
      my $id = unpack( "i", $o );
      my $l; sysread( $this->{FH}, $l, 2 );
      my $class; sysread( $this->{FH}, $class, unpack( "s", $l ));
      $o = $class->new();
      $this->{ids}[$id] = $o;
      $o->read( $this );
      return $o;
    } elsif ( $key eq 'U' ) {
      return undef;
    } else {
      Carp::confess( "Unrecognised key '$key'" );
    }
  }
}

1;
