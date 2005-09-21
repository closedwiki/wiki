# See Plugin topic for history and plugin information
package TWiki::Plugins::CommentPlugin;

use strict;

use TWiki::Func;

use vars qw( $VERSION );

$VERSION = '3.100';

sub initPlugin {
    #my ( $topic, $web, $user, $installWeb ) = @_;

    if( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning( "Version mismatch between CommentPlugin $VERSION and Plugins.pm $TWiki::Plugins::VERSION. Plugins.pm >= 1.026 required." );
    }

    TWiki::Func::registerTagHandler( "TIME", \&_TIME );

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

    return unless $_[0] =~ m/%COMMENT({.*?})?%/o;

    # SMELL: Nasty, tacky way to find out where we were invoked from
    my $scriptname = $ENV{'SCRIPT_NAME'} || '';
    # SMELL: unreliable
    my $previewing = ($scriptname =~ /\/(preview|gnusave|rdiff)/);
    TWiki::Plugins::CommentPlugin::Comment::prompt( $previewing,
                                                    $_[0], $web, $topic );
}

=pod

---++ beforeSaveHandler($text, $topic, $web )
   * =$text= - text _with embedded meta-data tags_
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
This handler is called just before the save action. The text is populated
with 'meta-data tags' before this method is called. If you modify any of
these tags, or their contents, you may break meta-data. You have been warned!

=cut

sub beforeSaveHandler {
    #my ( $text, $topic, $web ) = @_;

    require TWiki::Plugins::CommentPlugin::Comment;
    if ($@) {
        TWiki::Func::writeWarning( $@ );
        return 0;
    }
    my $query = TWiki::Func::getCgiQuery();
    return unless $query;

    my $action = $query->param('comment_action');

    return unless( defined( $action ) && $action eq 'save' );
    TWiki::Plugins::CommentPlugin::Comment::save( @_ );
}

sub _TIME {
    return TWiki::Time::formatTime( time(), '$hour:$min' );
}

1;
