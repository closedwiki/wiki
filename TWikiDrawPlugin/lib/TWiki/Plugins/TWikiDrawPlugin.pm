#
# Copyright (C) 2000-2001 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001 Peter Thoeny, Peter@Thoeny.com
# Copyright (C) 2002-2004 Crawford Currie, cc@c-dot.co.uk

package TWiki::Plugins::TWikiDrawPlugin;

use vars qw(
        $web $topic $user $installWeb $VERSION $editButton
    );

$VERSION = '1.201';
my $editmess;

sub initPlugin {
  ( $topic, $web, $user, $installWeb ) = @_;

  # check for Plugins.pm versions
  if( $TWiki::Plugins::VERSION < 1 ) {
	TWiki::Func::writeWarning( "Version mismatch between TWikiDrawPlugin and Plugins.pm" );
	return 0;
  }

  # Get plugin debug flag
  $editButton = TWiki::Func::getPreferencesValue( "TWIKIDRAWPLUGIN_EDIT_BUTTON" );
  $editmess = TWiki::Func::getPreferencesValue( "TWIKIDRAWPLUGIN_EDIT_TEXT" ) ||
    "Edit drawing using TWiki Draw applet (requires a Java 1.1 enabled browser)";
  $editmess =~ s/['"]/`/g;

  return 1;
}

sub handleDrawing {
  my( $attributes, $topic, $web ) = @_;
  my $nameVal = TWiki::Func::extractNameValuePair( $attributes );
  if( ! $nameVal ) {
	$nameVal = "untitled";
  }
  $nameVal =~ s/[^A-Za-z0-9_\.\-]//go; # delete special characters

  # should really use TWiki server-side include mechanism....
  my $mapFile = TWiki::Func::getPubDir() . "/$web/$topic/$nameVal.map";
  my $img = "src=\"%ATTACHURLPATH%/$nameVal.gif\"";
  my $editUrl =
	TWiki::Func::getOopsUrl($web, $topic, "twikidraw", $nameVal);
  my $imgText = "";
  my $edittext = $editmess;
  $edittext =~ s/%F%/$nameVal/g;
  my $hover =
    "onmouseover=\"window.status='$edittext';return true;\" ".
      "onmouseout=\"window.status='';return true;\"";

  if ( -e $mapFile ) {
	my $mapname = $nameVal;
	$mapname =~ s/^.*\/([^\/]+)$/$1/;
	$img .= " usemap=\"#$mapname\"";
	my $map = TWiki::Func::readFile($mapFile);
    # Unashamed hack to handle Web.TopicName links
    $map =~ s/href=\"((\w+)\.)?(\w+)(#\w+)?\"/&_processHref($2,$3,$4,$web)/ge;
	$map = TWiki::Func::expandCommonVariables( $map, $topic );
	$map =~ s/%MAPNAME%/$mapname/g;
	$map =~ s/%TWIKIDRAW%/$editUrl/g;
	$map =~ s/%EDITTEXT%/$edittext/g;
	$map =~ s/%HOVER%/$hover/g;
	$map =~ s/[\r\n]+//g;

	# Add an edit link just above the image if required
	$imgText = "<br /><a href=\"$editUrl\" $hover>".
          "Edit</a><br />" if ( $editButton == 1 );
#	$imgText = "<br /><button onclick=\"window.location='$editUrl'\" $hover>".
#          "Edit</button><br />" if ( $editButton == 1 );
	$imgText .= "<img $img>$map";
  } else {
	# insensitive drawing; the whole image gets a rather more
	# decorative version of the edit URL
	$imgText = "<a href=\"$editUrl\" $hover>".
          "<img $img $hover alt=\"$edittext\" title=\"$edittext\" /></a>";
#	$imgText = "<br /><button onclick=\"window.location='$editUrl'\" $hover>".
#          "$edittext</button><br />" if ( $editButton == 1 );
  }
  return $imgText;
}

sub _processHref {
    my ( $web, $topic, $anchor, $defweb ) = @_;

    $web = $defweb unless ( $web );
    $anchor = "" unless $anchor;

    return "href=\"%SCRIPTURLPATH%/view%SCRIPTSUFFIX%/$web/$topic$anchor\"";
}

sub commonTagsHandler
{
  ### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead
  $_[0] =~ s/%DRAWING{(.*?)}%/&handleDrawing($1, $_[1], $_[2])/geo;
  $_[0] =~ s/%DRAWING%/&handleDrawing("untitled", $_[1], $_[2])/geo;
}

1;
