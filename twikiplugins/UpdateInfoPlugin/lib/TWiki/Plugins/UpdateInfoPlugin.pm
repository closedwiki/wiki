#
#      TWiki UpdateInfo Plugin
#
#      Written by Chris Huebsch chu@informatik.tu-chemnitz.de
#

package TWiki::Plugins::UpdateInfoPlugin; 	

use vars qw(
        $web $topic $user $installWeb $VERSION $debug
    );

$VERSION = '1.000';

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1 ) {
        &TWiki::Func::writeWarning( "Version mismatch between EmptyPlugin and Plugins.pm" );
        return 0;
    }

    return 1;
}

sub update_info
{
  my ( $defweb, $wikiword, $opts ) = @_;

  ( $web, $topic ) = split ( /\./, $wikiword );
  if ( !$topic ) {
    $topic = $web;
    $web = $defweb;
  }

  #return " web $web topic $topic opts $opts";

  ( $meta, $dummy ) = TWiki::Func::readTopic($web, $topic);
  if ( $meta ) {

    $opts =~ s/{(.*?)}/$1/geo;

    $params{"days"}  = "5";
    $params{"version"}  = "1.1";

    foreach $param (split (/ /, $opts)) {
	($key, $val) = split (/=/, $param);
        $val =~ tr ["] [ ];
	$params{$key} = $val;
    }

    if( defined(&TWiki::Meta::findOne)) {
        %info = $meta->findOne( "TOPICINFO" );
    } else {
        my $r = $meta->get( "TOPICINFO" );
        return '' unless $r;
        %info = %$r;
    }
    $updated = ((time-$info{"date"})/86400) < $params{"days"}; #24*60*60
    $new = $updated & (($info{"version"}+0) <= ($params{"version"}+0)); 

    $r = "";
    if ( $updated )
      { $r = " <img src=\"%PUBURLPATH%/$installWeb/UpdateInfoPlugin/updated.gif\">"; }
    if ( $new )
      { $r = " <img src=\"%PUBURLPATH%/$installWeb/UpdateInfoPlugin/new.gif\">"; }

    return $r;

  } else {
    return "";
  }
}

# =========================
sub commonTagsHandler
{
    my ( $text, $topic, $web ) = @_; 

    # This is the place to define customized tags and variables
    # Called by sub handleCommonTags, after %INCLUDE:"..."%
    $_[0] =~ s/([\w\.]+) %ISNEW(({.*?})?)%/"$1".update_info($web, $1, $2)/geo;
}

1;
