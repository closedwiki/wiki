#!/usr/bin/perl -w
#
# Build for TWiki
# Crawford Currie
# Copyright (C) TWikiContributors, 2005

# Standard preamble
BEGIN {
  foreach my $pc (split(/:/, $ENV{TWIKI_LIBS})) {
    unshift @INC, $pc;
  }
}

use TWiki::Contrib::Build;

# Declare our build package
{ package TWikiBuild;

  @TWikiBuild::ISA = ( "TWiki::Contrib::Build" );

  sub new {
    my $class = shift;
    return bless( $class->SUPER::new( "TWiki" ), $class );
  }

  # Example: Override the build target
  sub target_build {
    my $this = shift;

    $this->SUPER::target_build();

    # generate the POD documentation
    print "Building documentation....\n";
    print `perl gendocs.pl -root $this->{basedir}`;
  }
}

# Create the build object
$build = new TWikiBuild();

# Build the target on the command line, or the default target
$build->build($build->{target});

