# See Plugin topic for history and plugin information
package TWiki::Plugins::CommentPlugin;

use strict;

use TWiki::Func;

use vars qw( $VERSION $firstCall $pluginName $context );

BEGIN {
    $VERSION = 3.100;
    $pluginName = "CommentPlugin";
    $firstCall = 0;
}

sub initPlugin {
    #my ( $topic, $web, $user, $installWeb ) = @_;

    if( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName $VERSION and Plugins.pm $TWiki::Plugins::VERSION. Plugins.pm >= 1.026 required." );
    }

    $firstCall = 1;
    my $topic = $_[0] || "";
    my $web = $_[1] || "";
    $context = "$web.$topic";

    return 1;
}

sub commonTagsHandler {
    my ( $text, $topic, $web ) = @_;

    require TWiki::Plugins::CommentPlugin::Comment;
    if ($@) {
        TWiki::Func::writeWarning( $@ );
        return 0;
    }

    my $query = TWiki::Func::getCgiQuery();
    return unless( defined( $query ));
    my $action = $query->param( 'comment_action' ) || "";

    if ( defined( $action ) && $action eq "save" &&
         # Test that the current context is the context of the
         # original query. This is needed as the common tags
         # handler is called on other topics, such as included
         # topics; but the save action should only happen on
         # the queried topic.
         "$web.$topic" eq $context ) {
        # $firstCall ensures we only save once, ever.
        if ( $firstCall ) {
            $firstCall = 0;
            TWiki::Plugins::CommentPlugin::Comment::save( $web, $topic, $query );
        }
    } elsif ( $_[0] =~ m/%COMMENT({.*?})?%/o ) {
        # SMELL: Nasty, tacky way to find out where we were invoked from
        my $scriptname = $ENV{'SCRIPT_NAME'} || "";
        # SMELL: unreliable
        my $previewing = ($scriptname =~ /\/(preview|gnusave|rdiff)/);
        TWiki::Plugins::CommentPlugin::Comment::prompt( $previewing,
                                                        $_[0], $web, $topic );
    }
}

1;
