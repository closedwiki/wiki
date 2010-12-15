# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2005 Toni Prug, toni@irational.org
# Copyright (C)2005-2010 TWiki:TWiki.TWikiContributor
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
# This is the NetgrepPlugin used to embed external information.
# Plugin home: http://TWiki.org/cgi-bin/view/Plugins/NetgrepPlugin

# =========================
package TWiki::Plugins::NetgrepPlugin;

# =========================
use vars qw(
	    $web $topic $user $installWeb $VERSION $RELEASE $debug
	    $defaultRefresh $defaultFormat $defaultSize
	    $perlDigestMD5Found $defaultFilter $defaultColor $useLWPUserAgent
    );

$VERSION = '$Rev$';
$RELEASE = '2010-12-14';

$perlDigestMD5Found = 0;

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1 ) {
        &TWiki::Func::writeWarning( "Version mismatch between NetgrepPlugin and Plugins.pm" );
        return 0;
    }

    # Get plugin preferences
    $defaultRefresh  = TWiki::Func::getPreferencesValue( "NETGREPPLUGIN_REFRESH" ) || 15;
    $defaultFilter   = TWiki::Func::getPreferencesValue( "NETGREPPLUGIN_FILTER" );
    $defaultFormat   = TWiki::Func::getPreferencesValue( "NETGREPPLUGIN_FORMAT" ) || "(+1+)";
    $defaultSize     = TWiki::Func::getPreferencesValue( "NETGREPPLUGIN_SIZE" ) || "100%";
    $defaultColor    = TWiki::Func::getPreferencesValue( "NETGREPPLUGIN_COLOR" ) || "black";
    $useLWPUserAgent = TWiki::Func::getPreferencesValue( "NETGREPPLUGIN_USELWPUSERAGENT" ) || 'on';
    $useLWPUserAgent =~ s/^\s*(.*?)\s*$/$1/go;
    $useLWPUserAgent = ($useLWPUserAgent =~ /on|yes|1/)?1:0;

    # Get plugin debug flag
    $debug = &TWiki::Func::getPreferencesFlag( "NETGREPPLUGIN_DEBUG" );

    # Plugin correctly initialized
    &TWiki::Func::writeDebug( "- TWiki::Plugins::NetgrepPlugin::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}

# =========================
sub commonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead
    
    &TWiki::Func::writeDebug( "- NetgrepPlugin::commonTagsHandler( $_[2].$_[1] )" ); 
    $_[0] =~ s/( *)%NETGREP{(.*?)}%/_handleNetgrepTag( $1, $2 )/geo;
}

# =========================
sub _errorMsg
{
    my( $thePre, $theMsg ) = @_;

    return "$thePre| *NETGREP Plugin Error* |\n"
         . "$thePre| $installWeb.NetgrepPlugin: $theMsg |\n";
}

# =========================
sub _getUrl
{
    my( $theUrl, $theRefresh ) = @_;

    my $cacheDir = "";
    my $cacheFile = "";
    if( $theRefresh ) {
        $cacheDir  = TWiki::Func::getPubDir() . '/' . $installWeb . '/NetgrepPlugin';
        $cacheDir  =~ /(.*)/;  $cacheDir  = $1; # untaint (save because only internal variables)
        $cacheFile = $cacheDir . '/_url-' . Digest::MD5::md5_hex( $theUrl );
        $cacheFile =~ /(.*)/;  $cacheFile = $1; # untaint
        if( ( -e $cacheFile ) && ( ( time() - (stat(_))[9] ) <= ( $theRefresh * 60 ) ) ) {
            # return cached version if it exists and isn't too old. 1440 = 24h * 60min
            return TWiki::Func::readFile( $cacheFile );
        }
    }

    my $host = "";
    my $port = 0;
    my $path = "";
    if( $theUrl =~ /http\:\/\/(.*?)\:([0-9]+)(\/.*)/ ) {
        $host = $1;
        $port = $2;
        $path = $3;
    } elsif( $theUrl =~ /http\:\/\/(.*?)(\/.*)/ ) {
        $host = $1;
        $path = $2;
    }
    unless( $path ) {
        return "ERROR: invalid format of the href parameter";
    }

    my ($text, $errorMsg) = $useLWPUserAgent ?
                              _getUrlUsingLWP( $theUrl ) :
                              _getUrlUsingTWikiNet( $theUrl );
    return ( "ERROR: $errorMsg" ) if $errorMsg;

    if( $theRefresh ) {
        unless( -e $cacheDir ) {
            # create the cache directory in the pub dir of the NetgrepPlugin
            umask( 002 );
            mkdir( $cacheDir, 0775 );
        }
        # save text in cache file before returning it
        TWiki::Func::saveFile( $cacheFile, $text );
    }

    return $text;
}

# =========================
# borrowed from HeadlinesPlugin
sub _getUrlUsingLWP {
  my $theUrl = shift;

  #writeDebug("called getUrlLWP($theUrl)");

  unless ($userAgent) {
    eval "use LWP::UserAgent";
    die $@ if $@;

    my $proxyHost = TWiki::Func::getPreferencesValue('PROXYHOST') || '';
    my $proxyPort = TWiki::Func::getPreferencesValue('PROXYPORT') || '';
    $proxyHost ||= $TWiki::cfg{PROXY}{HOST};
    $proxyPort ||= $TWiki::cfg{PROXY}{PORT};
    my $proxySkip = $TWiki::cfg{PROXY}{SkipProxyForDomains} || '';

    $userAgent = LWP::UserAgent->new();
    $userAgent->agent( $userAgentName );
      # don't leave the LWP default string there as
      # this is blocked by some sites, e.g. google news
    $userAgent->timeout( $userAgentTimeout );
    if( $proxyHost && $proxyPort ) {
      my $proxyURL = "$proxyHost:$proxyPort/";
      $proxyURL = 'http://' . $proxyURL unless( $proxyURL =~ /^https?:\/\// );
      $userAgent->proxy( "http", $proxyURL );
      my @skipDomains = split( /[\,\s]+/, $proxySkip );
      $userAgent->no_proxy( @skipDomains );
    }
  }

  my $request = HTTP::Request->new('GET', $theUrl);
  $request->referer(TWiki::Func::getViewUrl($web, $topic));
  my $response = $userAgent->request($request);
  if ($response->is_error) {
    return (undef, $response->status_line);
  } else {
    my $text = $response->content;
    $text =~ s/\r\n?/ /gos;
    $text =~ s/\n/ /gos;
    #$text =~ s/ +/ /gos;
    return ($text, undef);
  }
}

# =========================
# borrowed from HeadlinesPlugin
sub _getUrlUsingTWikiNet {
  my $theUrl = shift;

  my $host = '';
  my $port = 0;
  my $path = '';
  if ($theUrl =~ /https?\:\/\/(.*?)\:([0-9]+)(\/.*)/) {
    $host = $1;
    $port = $2;
    $path = $3;
  } elsif($theUrl =~ /https?\:\/\/(.*?)(\/.*)/) {
    $host = $1;
    $path = $2;
  }
  return (undef, "Invalid URL") unless $path;

  # figure out how to get to TWiki::Net which is wide open in Cairo and before,
  # but Dakar uses the session object.  
  my $text = $TWiki::Plugins::SESSION->{net}
      ? $TWiki::Plugins::SESSION->{net}->getUrl( $host, $port, $path )
      : TWiki::Net::getUrl( $host, $port, $path );

  if ($text =~ /text\/plain\s*ERROR\: (.*)/s) {
    my $msg = $1;
    $msg =~ s/[\n\r]/ /gos;
    return (undef, "Can't read $theUrl ($msg)");
  }
  if ($text =~ /HTTP\/[0-9\.]+\s*([0-9]+)\s*([^\n]*)/s) {
    return (undef, "Can't read $theUrl ($1 $2)")
      unless $1 == 200;
  }
  $text =~ s/^.*?\n\n(.*)/$1/os;  # strip header
  $text =~ s/\r\n?/ /gos;
  $text =~ s/\n/ /gos;
  #$text =~ s/ +/ /gos;

  return ($text, undef);
}

# =========================
sub _handleNetgrepTag
{
    my( $thePre, $theArgs ) = @_;

    unless( $perlDigestMD5Found ) {
	# lazy loading of Perl module
	eval {
	    $perlDigestMD5Found = require Digest::MD5;
	}
    }
    unless( $perlDigestMD5Found ) {
	return _errorMsg( $thePre, "ERROR: Cannot locate Perl module Digest::MD5" );
    }

    my $href    = TWiki::Func::extractNameValuePair( $theArgs, "href" ) 
	|| TWiki::Func::extractNameValuePair( $theArgs );
    my $filter  = TWiki::Func::extractNameValuePair( $theArgs, "filter" ) 
	|| TWiki::Func::extractNameValuePair( $theArgs );
    my $refresh = TWiki::Func::extractNameValuePair( $theArgs, "refresh" ) 
	|| $defaultRefresh;
    my $format  = TWiki::Func::extractNameValuePair( $theArgs, "format" ) 
	|| $defaultFormat;
    my $size    = TWiki::Func::extractNameValuePair( $theArgs, "size" ) 
	|| $defaultSize;
    my $color   = TWiki::Func::extractNameValuePair( $theArgs, "color" ) 
	|| $defaultColor;

    unless( $href ) {
	return _errorMsg( $thePre, "href parameter (source) is missing" );
    }

    unless( $filter ) {
	return _errorMsg( $thePre, "filter parameter is missing" );
    }
    
    my $raw = _getUrl( $href, $refresh );
    if( $raw =~ /^ERROR\: (.*)/s ) {
         return _errorMsg( $thePre, $1 );
     }

    ( my @filtered ) = $raw =~ /$filter/;

    my $result = $format;
    for (my $i=0; $i < scalar(@filtered); $i++) {
    	$result =~ s/\+$i\+/$filtered[$i]/g;
    }
    
    return "$thePre <noautolink><span style='color: $color; font-size: $size;'>$result</span></noautolink>";
}

# =========================

1;
