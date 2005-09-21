#
# Plugin makes links to specified revisions
# Richard Baar, 2003
# richard.baar@centrum.cz

# =========================
package TWiki::Plugins::RevisionLinkPlugin;

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $debug
    );

$VERSION = '1.21';

# =========================
sub initPlugin
{
  ( $topic, $web, $user, $installWeb ) = @_;

  # check for Plugins.pm versions
  if( $TWiki::Plugins::VERSION < 1 ) {
    &TWiki::Func::writeWarning( "Version mismatch between RevisionLinkPlugin and Plugins.pm" );
    return 0;
  }

  # Get plugin debug flag
  $debug = &TWiki::Func::getPreferencesFlag( "REVISIONLINKPLUGIN_DEBUG" );

  # Plugin correctly initialized
  &TWiki::Func::writeDebug( "- TWiki::Plugins::RevisionLinkPlugin::initPlugin( $web.$topic ) is OK" ) if $debug;
  return 1;
}

# =========================
sub commonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

  &TWiki::Func::writeDebug( "- RevisionLinkPlugin::commonTagsHandler( $_[2].$_[1] )" ) if $debug;

  # This is the place to define customized tags and variables
  # Called by sub handleCommonTags, after %INCLUDE:"..."%

  $_[0] =~ s/%REV[{\[](.*)[}\]]%/&handleRevision($1)/geo;
}

sub handleRevision {
  my ( $text ) = @_;
  my ( $tmpTopic ) = ( $text =~ /topic=[\'\"](.*?)[\'\"]/ );
  my ( $tmpWeb ) = ( $text =~ /web=[\'\"](.*?)[\'\"]/ );
  my ( $rev ) = ( $text =~ /rev=[\'\"](.*?)[\'\"]/ );
  my ( $format ) = ( $text =~ /format=[\'\"](.*?)[\'\"]/ );
  my ( $emptyAttr ) = ( $text =~ /^[\'\"](.*?)[\'\"]/ );
  if ( $emptyAttr ne "" ) {
    if ( $rev eq "" ) {
      $rev = $emptyAttr;
    }
    else {
      $topic = $emptyAttr;
    }
  }
  if ( $tmpWeb eq "" ) {$tmpWeb = $web;}
  if ( $tmpTopic eq "" ) {$tmpTopic = $topic;}
  if ( $rev < 0 ) {
    my $maxRev = &TWiki::Store::getRevisionNumberX( $tmpWeb, $tmpTopic );
    $maxRev =~ s/1.(.*)/$1/;
    $rev = $maxRev + $rev;
    if ( $rev < 1 ) { $rev = 1; }
  }
  my ( $revDate, $revUser, $tmpRev, $revComment ) = &TWiki::Store::getRevisionInfo( $tmpWeb, $tmpTopic, $rev, 1 );
  if ( index( $rev, "." ) < 0 ) {
    $rev = "1.$rev";
  }
  if ( $format eq "" ) {
    $format = "!$topic($rev)!"
  }
  else {
    if ( $format =~ /!(.*?)!/ eq "" ) {
      $format = "!$format!";
    }
    $format =~ s/\$topic/$tmpTopic/geo;
    $format =~ s/\$web/$tmpWeb/geo;
    $format =~ s/\$rev/$rev/geo;
    $format =~ s/\$date/$revDate/geo;
    $format =~ s/\$user/$revUser/geo;
    $format =~ s/\$comment/$revComment/geo;
  }
  $format =~ s/!(.*?)!/[[%SCRIPTURL%\/view\/$tmpWeb\/$tmpTopic\?rev=$rev][$1]]/g;
  return $format;
}

1;
