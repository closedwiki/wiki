# See Plugin topic for history and plugin information
package TWiki::Plugins::CommentPlugin;

use strict;
use integer;

require  TWiki::Plugins::CommentPlugin::Comment;

use vars qw( $VERSION $firstCall );

BEGIN {
    $VERSION = '3.003';
    $firstCall = 0;
}

sub initPlugin {
  #my ( $topic, $web, $user, $installWeb ) = @_;

  if( $TWiki::Plugins::VERSION < 1 ) {
    TWiki::Func::writeWarning( "Version mismatch between CommentPlugin and Plugins.pm $TWiki::Plugins::VERSION" );
    return 0;
  }
  $firstCall = 1;

  return 1;
}

sub commonTagsHandler {
  ### my ( $text, $topic, $web ) = @_;

  my $query = TWiki::Func::getCgiQuery();
  return unless( defined( $query ));
  my $action = $query->param( 'comment_action' ) || "";

  if ( defined( $action ) && $action eq "save" ) {
    # $firstCall ensures we only save once, ever.
    if ( $firstCall ) {
      $firstCall = 0;
      CommentPlugin::Comment::save( $_[2], $_[1], $query );
    }
  } elsif ( $_[0] =~ m/%COMMENT{.*?}%/o ) {
    # Nasty, tacky way to find out where we were invoked from
    my $scriptname = $ENV{'SCRIPT_NAME'} || "";
    my $previewing = ($scriptname =~ /\/preview/ ||
		      $scriptname =~ /\/gnusave/);
    CommentPlugin::Comment::prompt( $previewing, @_ );
  }
}

1;
