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
    
  CommentPlugin::Comment::prompt( @_ );
}

sub beforeSaveHandler {
  TWiki::Func::writeDebug( "- CommentPlugin::beforeSaveHandler( $_[2].$_[1] )" ) if $debug;
  my $query = TWiki::Func::getCgiQuery();
  if ( $query ) {
    CommentPlugin::Comment::save( $query, @_ );
  } else {
    TWiki::Func::writeWarning("Comment plugin was unable to getCgiQuery");
  };
}

1;
