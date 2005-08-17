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

  sub target_build {
    my $this = shift;

    $this->SUPER::target_build();

    # generate the POD documentation
    print "Building documentation....\n";
    $this->sys_action('perl gendocs.pl -root '.$this->{basedir});
    $this->cp( $this->{basedir}.'/AUTHORS',
               $this->{basedir}.'/pub/TWiki/TWikiContributor/AUTHORS' );
    print "Generating CHANGELOG...\n";
    $this->sys_action( 'svn log --xml --verbose | xsltproc '.
                         $this->{basedir}.'/tools/distro/svn2cl.xsl - > '.
                           $this->{basedir}.'/CHANGELOG' );
    print "Documentation built\n";
}

  sub target_stage {
    my $this = shift;

    $this->SUPER::target_stage();

    #use a Cairo install to create new ,v files for the data
    #WARNING: I don't know how to get the 'last' release, so i'm hardcoding Cairo
  }
}

# Create the build object
$build = new TWikiBuild();

# Build the target on the command line, or the default target
$build->build($build->{target});

