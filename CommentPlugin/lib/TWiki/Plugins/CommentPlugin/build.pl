#!/usr/bin/perl -w
#
package CommentPluginBuild;

BEGIN {
    unshift(@INC, '../../../../bin');
    do 'setlib.cfg';
}
use TWiki::Contrib::Build;

@CommentPluginBuild::ISA = ( "TWiki::Contrib::Build" );

sub new {
    my $class = shift;
    return bless( $class->SUPER::new( "CommentPlugin" ), $class );
}

$build = new CommentPluginBuild();
$build->build($build->{target});
