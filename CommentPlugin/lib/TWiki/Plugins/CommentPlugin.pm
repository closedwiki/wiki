# See Plugin topic for history and plugin information
package TWiki::Plugins::CommentPlugin;

use strict;
use integer;

use TWiki::Plugins::CommentPlugin::Comment;

# =========================
use vars qw(
	    $web $topic $user $installWeb $VERSION $debug
	   );

$VERSION = '3.000';

sub initPlugin {
  ( $topic, $web, $user, $installWeb ) = @_;

  if( $TWiki::Plugins::VERSION < 1 ) {
    TWiki::Func::writeWarning( "Version mismatch between CommentPlugin and Plugins.pm $TWiki::Plugins::VERSION" );
    return 0;
  }

  # Plugin correctly initialized
  TWiki::Func::writeDebug( "- TWiki::Plugins::CommentPlugin::initPlugin( $web.$topic ) is OK" ) if $debug;
  return 1;
}

sub commonTagsHandler {
  ### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

  TWiki::Func::writeDebug( "- CommentPlugin::commonTagsHandler( $_[2].$_[1] )" ) if $debug;

  my $query = TWiki::Func::getCgiQuery();

  my $type = $query->param( 'comment_type' );
  my $index = $query->param( 'comment_index' );
  my $anchor = $query->param( 'comment_anchor' );
  my $location = $query->param( 'comment_location' );

  # the presence of these three urlparams indicates this is a comment save
  # from a viewauth invocation.
  if ( defined( $type ) && $type ne "" &&
       ( defined( $index ) || defined( $anchor ) ||
	 defined( $location ))) {
    CommentPlugin::Comment::save( $_[2], $_[1], $type, $index, $anchor, $location );
  } else {
    CommentPlugin::Comment::prompt( @_ );
  }
}

1;
