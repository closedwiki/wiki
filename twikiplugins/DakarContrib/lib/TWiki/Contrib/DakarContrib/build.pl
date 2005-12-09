#!/usr/bin/perl -w

BEGIN {
  foreach my $pc (split(/:/, $ENV{TWIKI_LIBS})) {
    unshift @INC, $pc;
  }
}

use TWiki::Contrib::Build;

package DakarBuild;

@DakarBuild::ISA = ( "TWiki::Contrib::Build" );

sub new {
  my $class = shift;
  return bless( $class->SUPER::new( "DakarContrib" ), $class );
}

$build = new DakarBuild();

$build->build($build->{target});
