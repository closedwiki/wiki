#
# Copyright (C) 2000-2001 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001 Peter Thoeny, Peter@Thoeny.com
# Copyright (C) 2002-2004 Crawford Currie, cc@c-dot.co.uk

package TWiki::Plugins::TWikiDrawPlugin;

use vars qw(
        $web $topic $user $installWeb $VERSION $editButton
    );

$VERSION = 1.100;

sub initPlugin {
  ( $topic, $web, $user, $installWeb ) = @_;

  # check for Plugins.pm versions
  if( $TWiki::Plugins::VERSION < 1 ) {
	TWiki::Func::writeWarning( "Version mismatch between TWikiDrawPlugin and Plugins.pm" );
	return 0;
  }

  # Get plugin debug flag
  $editButton = TWiki::Func::getPreferencesValue( "TWIKIDRAWPLUGIN_EDIT_BUTTON" );

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

  if ( -e $mapFile ) {
	my $name = $nameVal;
	$name =~ s/^.*\/([^\/]+)$/$1/o;
	$img .= " usemap=\"#$name\"";
	my $map = TWiki::Func::readFile($mapFile);
	$map = TWiki::Func::expandCommonVariables( $map, $topic );
	$map =~ s/%MAPNAME%/$name/go;
	$map =~ s/%TWIKIDRAW%/$editUrl/go;
	
	# Add an edit link just above the image if required
	$imgText = "<br><a href=\"$editUrl\">Edit image</a><br>" if ( $editButton == 1 );
	
	$imgText .= "<img $img>\n$map";
  } else {
	# insensitive drawing; the whole image gets a rather more
	# decorative version of the edit URL
	$imgText = "<a href=\"$editUrl\" ".
	  "onMouseOver=\"".
	    "window.status='Edit drawing [$nameVal] using ".
	      "TWiki Draw applet (requires a Java 1.1 enabled browser)';" .
			"return true;\"".
			  "onMouseOut=\"".
				"window.status='';".
				  "return true;\">".
					"<img $img ".
					  "alt=\"Edit drawing '$nameVal' ".
						"(requires a Java enabled browser)\"></a>\n";
  }
  return $imgText;
}

sub commonTagsHandler
{
  ### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead
  $_[0] =~ s/%DRAWING{(.*?)}%/&handleDrawing($1, $_[1], $_[2])/geo;
  $_[0] =~ s/%DRAWING%/&handleDrawing("untitled", $_[1], $_[2])/geo;
}

1;
