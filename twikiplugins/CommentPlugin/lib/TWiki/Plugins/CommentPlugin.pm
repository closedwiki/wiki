#CommentPlugin written by David Weller (dgweller@yahoo.com)
#Rev 1.0 -- Initial release
#Rev 1.1 -- Incorporate changes suggested by Andrea Sterbini and John Rouillard
#Rev 1.2 -- Additional user feedback incorporated
#Rev 1.3 -- Added checks for $debug flag - JonLambert
#Rev 1.3 -- Added checks for locked pages - JonLambert
#Rev 1.4 -- refactored form, disabled comment in preview mode, passing comments to oops template -- Peter Masiar
#Rev 2.0 -- 80% rewrite: use templates for input/output, move COMMENT-specific code from savecomment script to plugin
#
# Contributors: DavidWeller, LaurentAmon, JonLambert, PeterMasiar, CrawfordCurrie
package TWiki::Plugins::CommentPlugin;

use strict;
use integer;

use TWiki::Plugins::CommentPlugin::Comment;

# =========================
use vars qw(
	    $web $topic $user $installWeb $VERSION $debug
	   );

$VERSION = '3.000';

# =========================
sub initPlugin {
  ( $topic, $web, $user, $installWeb ) = @_;
  
  if( $TWiki::Plugins::VERSION < 1 ) {
    &TWiki::Func::writeWarning( "Version mismatch between CommentPlugin and Plugins.pm $TWiki::Plugins::VERSION" );
    return 0;
  }

  # Plugin correctly initialized
  &TWiki::Func::writeDebug( "- TWiki::Plugins::CommentPlugin::initPlugin( $web.$topic ) is OK" ) if $debug;
  return 1;
}

# =========================
sub commonTagsHandler {
  ### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead
  
  &TWiki::Func::writeDebug( "- CommentPlugin::commonTagsHandler( $_[2].$_[1] )" ) if $debug;
    
  CommentPlugin::Comment::prompt( @_ );
}

sub beforeSaveHandler {
  CommentPlugin::Comment::save( @_ );
}

1;
