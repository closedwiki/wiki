#!/usr/bin/perl -w
#
package CommentPluginBuild;

require '../../../../bin/setlib.cfg';
use TWiki::Contrib::Build;

@CommentPluginBuild::ISA = ( "TWiki::Contrib::Build" );

sub new {
    my $class = shift;
    return bless( $class->SUPER::new( "CommentPlugin" ), $class );
}

$build = new CommentPluginBuild();
$build->build($build->{target});
