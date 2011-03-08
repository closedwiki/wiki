#!/usr/bin/perl -w

BEGIN {
    unshift @INC, split( /:/, $ENV{TWIKI_LIBS} );
}

use TWiki::Contrib::Build;

package BuildBuild;
use base qw( TWiki::Contrib::Build );

sub new {
    my $class = shift;
    return bless( $class->SUPER::new( "ShowAccessPlugin" ), $class );
}

package main;

$build = new BuildBuild();

$build->build($build->{target});

