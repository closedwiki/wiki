#
# Copyright (C) Motorola 2003 - All rights reserved
#
use strict;

# Object that handles a file/time tuple for use in Storable and
# FormQueryPlugin::Archive. Only works on .txt files.
{ package FormQueryPlugin::FileTime;

  # PUBLIC construct from a file name
  sub new {
    my ( $class, $file ) = @_;
    my $this = bless( {}, $class );
    return $this unless ( $file ); # needed for read()
    $this->{file} = $file;
    my @sinfo = stat( $file );
    $this->{time} = $sinfo[9];
    return $this;
  }

  # PUBLIC check the file time against what is seen on disc.
  # Return 1 if consistent, 0 if inconsistent.
  sub uptodate {
    my $this = shift;
    my $file = $this->{file};
    if ( -r $file && defined( $this->{time} )) {
      my @sinfo = stat( $file );
      my $fileTime = $sinfo[9];
      if ( defined( $fileTime) && $fileTime == $this->{time} ) {
	return 1;
      }
    }
    return 0;
  }

  sub toString {
    my $this = shift;
    return $this->{file} . ":" . $this->{time};
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
  }
}

1;
