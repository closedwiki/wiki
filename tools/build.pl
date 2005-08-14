#!/usr/bin/perl -w
#
# Build for TWiki
# Crawford Currie
# Copyright (C) TWikiContributors, 2005

BEGIN {
    use File::Spec;

    foreach my $pc (split(/:/, $ENV{TWIKI_LIBS})) {
        unshift @INC, $pc;
    }

    # designed to be run within a SVN checkout area
    my @path = split( /\/+/, File::Spec->rel2abs($0) );
    pop(@path); # the script name

    while (scalar(@path) > 0) {
        last if -d join( '/', @path).'/twikiplugins/BuildContrib';
        pop( @path );
    }

    if(scalar(@path)) {
        unshift @INC, join( '/', @path ).'/twikiplugins/BuildContrib/lib';
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
    #print `perl gendocs.pl -root $this->{basedir}`;
    print "Documentation built\n";
  }
}

# Create the build object
$build = new TWikiBuild();

# Build the target on the command line, or the default target
$build->build($build->{target});

