#
# Copyright (C) Motorola 2003 - All rights reserved
#
use strict;

# Object that handles a file/time tuple for use in Storable and
# FormQueryPlugin::Archive. As each object is created during read,
# the file time is checked against disc and an exception thrown
# if they are inconsistent. Only works on .txt files.
{ package FormQueryPlugin::FileTime;

  use vars qw( $checkDir );

  # PUBLIC STATIC set the directory to check files against
  # Must be called before any 'new's are done
  sub setRoot {
    $checkDir = shift;
  }

  # PUBLIC construct from a file name
  sub new {
    my ( $class, $file ) = @_;
    my $this = bless( {}, $class );
    return $this unless ( $file );
    $this->{file} = $file;
    my @sinfo = stat( "$checkDir/$file.txt" );
    $this->{time} = $sinfo[9];
    return $this;
  }

  # PRIVATE check the file time against what is seen on disc
  sub _check {
    my $this = shift;
    #print STDERR "Check $this->{file}:$this->{time}\n";
    die unless defined( $this->{file} );
    my $file = "$checkDir/$this->{file}.txt";
    if ( -r $file && defined( $this->{time} )) {
      my @sinfo = stat( $file );
      my $fileTime = $sinfo[9];
      if ( ( !defined( $fileTime) || $fileTime != $this->{time} )) {
	die "$file:$this->{time}";
      }
    } else {
      die "$file";
    }
    #print STDERR "Check passed\n";
  }

  sub toString {
    my $this = shift;
    return $this->{file} . ":" . $this->{time};
  }

  # PUBLIC Storable hook.
  sub STORABLE_freeze {
    my ( $this, $cloning ) = @_;
    return if ( $cloning );
    return ( $this->{file} . ":" . $this->{time} );
  }

  # PUBLIC Storable hook.
  # Unserialise a file time object and check it is consistent
  # with the same file currently in the directory.
  sub STORABLE_thaw {
    my ( $this, $cloning, $serialised ) = @_;
    $serialised =~ m/^(.*):(.*)/o;
    $this->{file} = $1;
    $this->{time} = $2;
    $this->_check();
  }

  # PUBLIC FormQueryPlugin::Archive hook
  sub write {
    my ( $this, $archive ) = @_;

    $archive->writeString( $this->{file} );
    $archive->writeInt( $this->{time} );
  }

  # PUBLIC FormQueryPlugin::Archive hook
  sub read {
    my ( $this, $archive ) = @_;

    $this->{file} = $archive->readString();
    $this->{time} = $archive->readInt();
    $this->_check();
  }
}

1;
