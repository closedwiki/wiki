# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2011 Peter Thoeny, peter[at]thoeny.org
# Copyright (C) 2007-2008 Thadeu Lima de Souza Cascardo, cascardo@holoscopio.com
# Copyright (C) 2008-2011 TWiki Contributors
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at 
# http://www.gnu.org/copyleft/gpl.html
#
# =========================
#
# This plugin is base on EmbedPlugin, which, in turn, is based on EmptyPlugin
#
# Many unused functions/hooks and simple explanation comments were removed.
# The Handler was changed to deal with Cortado Java Applet instead of
# MediaPlayer.

# =========================
package TWiki::Plugins::CortadoPlugin;

use Error qw( :try );
use vars qw(
        $web $topic $user $installWeb $VERSION $REVISON $pluginName
        $SHORTDESCRIPTION
        $debug $cortadoPath
    );

$SHORTDESCRIPTION = 'Embed videos in a topic using the Cortado Java Applet';
$VERSION = '1.001';
$REVISION = '2011-05-14';
$pluginName = 'CortadoPlugin';  # Name of this Plugin

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    # Get debug option from $TWiki::cfg
    $debug = $TWiki::cfg{Plugins}{CortadoPlugin}{DEBUG};

    # Get Cortado applet path
    $cortadoPath = $TWiki::cfg{Plugins}{CortadoPlugin}{CortadoPath};
    return 0 unless $cortadoPath ne "";

    # Plugin correctly initialized
    TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}

# =========================
sub commonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::commonTagsHandler( $_[2].$_[1] )" ) if $debug;

    while ($_[0] =~ m/%CORTADO{(.*?)}%/) {
      my $web = &TWiki::Func::extractNameValuePair($1, "web");
      my $topic = &TWiki::Func::extractNameValuePair($1, "topic");
      my $filename = &TWiki::Func::extractNameValuePair($1);
      $topic = $_[1] if $topic eq "";
      $web = $_[2] if $web eq "";
      my $puburl = &TWiki::Func::getPubUrlPath;
      my $url = "$puburl/$web/$topic/$filename";
      my $value = &handleCortado($url, $1);
      $_[0] =~ s/%CORTADO{(.*?)}%/$value/;
    }
}

sub handleTotem
{
  my ( $url ) = @_;
  my $string =<<EOM;
  <object>
    <embed src="$url" />
  </object>
EOM
  $string =~ s/\n//;
  return $string;
}

# =========================
sub handleCortado
{
    my ( $url, $theAttributes ) = @_;
    my %default_params = ( "seekable" => "true");
    my @params = ( 
    			"seekable",
			"duration",
			"keepAspect",
			"video",
			"audio",
			"statusHeight",
			"autoPlay",
			"showStatus",
			"hideTimeout",
			"bufferSize",
			"bufferLow",
			"bufferHigh",
			"userId",
			"password",
			"debug"
			);
    my %default_attrs = ( "width" => 320, "height" => 240 );
    my @attrs = ( "width", "height" );
    my $param = "";
    my $attr = "";
    foreach (@params) {
      my $val = &TWiki::Func::extractNameValuePair($theAttributes, $_);
      $val = $default_params{$_} if $val eq "";
      $param .= "<param name=\"$_\" value=\"$val\" />" if $val ne "";
    }
    foreach (@attrs) {
      my $val = &TWiki::Func::extractNameValuePair($theAttributes, $_);
      $val = $default_attrs{$_} if $val eq "";
      $attr .= " $_=\"$val\" " if $val ne "";
    }

    $server = &TWiki::Func::getUrlHost;
    my $string =<<EOM;
    <applet code="com.fluendo.player.Cortado.class" archive="$server$cortadoPath" $attr >
      <param name="url" value="$url" />
      $param
    </applet>
EOM
     $string =~ s/\n/   /g; # not allowed to have newlines else you get rendering
    return $string;

}


# =========================
sub afterEditHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::afterEditHandler( $_[2].$_[1] )" ) if $debug;

    @matches = $_[0] =~ m/%CORTADO{(.*?)}%/g;
    foreach (@matches) {
      my $filename = &TWiki::Func::extractNameValuePair($_);
      my $topic = &TWiki::Func::extractNameValuePair($_, "topic");
      my $web = &TWiki::Func::extractNameValuePair($_, "web");
      $topic = $_[1] if $topic eq "";
      $web = $_[2] if $web eq "";
      if ($filename eq "") {
        throw TWiki::OopsException ('saveerr',
	                            web => $_[2],
				    topic => $_[1],
	                            params => ([ 'Provide filename' ]));
      }
      elsif (! &TWiki::Func::attachmentExists ($web, $topic, $filename)) {
        throw TWiki::OopsException ('saveerr',
				    web => $_[2],
				    topic => $_[1],
	                            params => ([ 'File does not exist' ]));
      }
      elsif ($filename !~ m/ogg$/) {
        throw TWiki::OopsException ('saveerr',
				    web => $_[2],
				    topic => $_[1],
	                            params => ([ 'File is not a supported media' ]));
      }
    }

}

1;
