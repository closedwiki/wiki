# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2002-2004 Peter Thoeny, peter@thoeny.com
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
# This is the HeadlinesPlugin used to show RSS news feeds.
# Plugin home: http://TWiki.org/cgi-bin/view/Plugins/HeadlinesPlugin
#
# Each plugin is a package that contains the subs:
#
#   initPlugin           ( $topic, $web, $user, $installWeb )
#   commonTagsHandler    ( $text, $topic, $web )
#   startRenderingHandler( $text, $web )
#   outsidePREHandler    ( $text )
#   insidePREHandler     ( $text )
#   endRenderingHandler  ( $text )
#
# initPlugin is required, all other are optional.
# For increased performance, DISABLE handlers you don't need.
#
# NOTE: To interact with TWiki use the official TWiki functions
# in the &TWiki::Func module. Do not reference any functions or
# variables elsewhere in TWiki!!

# =========================
package TWiki::Plugins::HeadlinesPlugin;

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $debug
        $defaultRefresh $defaultLimit $defaultHeader $defaultFormat
        $perlDigestMD5Found
    );

$VERSION = '1.004';
$perlDigestMD5Found = 0;

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1 ) {
        &TWiki::Func::writeWarning( "Version mismatch between HeadlinesPlugin and Plugins.pm" );
        return 0;
    }

    # Get plugin preferences
    $defaultRefresh = &TWiki::Func::getPreferencesValue( "HEADLINESPLUGIN_REFRESH" ) || 15;
    $defaultLimit   = &TWiki::Func::getPreferencesValue( "HEADLINESPLUGIN_LIMIT" ) || 50;
    $defaultHeader  = &TWiki::Func::getPreferencesValue( "HEADLINESPLUGIN_HEADER" ) ||
                      "| *[[$imagelink][ $imageurl ]]* |";
    $defaultFormat  = &TWiki::Func::getPreferencesValue( "HEADLINESPLUGIN_FORMAT" ) ||
                      "| [[$link][$title]] |";

    # Get plugin debug flag
    $debug = &TWiki::Func::getPreferencesFlag( "HEADLINESPLUGIN_DEBUG" );

    # Plugin correctly initialized
    &TWiki::Func::writeDebug( "- TWiki::Plugins::HeadlinesPlugin::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}

# =========================
sub commonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    &TWiki::Func::writeDebug( "- HeadlinesPlugin::commonTagsHandler( $_[2].$_[1] )" ) if $debug;

    $_[0] =~ s/( *)%HEADLINES{(.*?)}%/_handleHeadlinesTag( $1, $2 )/geo;
}

# =========================
sub _errorMsg
{
    my( $thePre, $theMsg ) = @_;

    return "$thePre| *HEADLINES Plugin Error* |\n"
         . "$thePre| $installWeb.HeadlinesPlugin: $theMsg |\n";
}

# =========================
sub _readRssFeed
{
    my( $theUrl, $theRefresh ) = @_;

    my $cacheDir = "";
    my $cacheFile = "";
    if( $theRefresh ) {
        $cacheDir  = TWiki::Func::getPubDir() . '/' . $installWeb . '/HeadlinesPlugin';
        $cacheDir  =~ /(.*)/;  $cacheDir  = $1; # untaint (save because only internal variables)
        $cacheFile = $cacheDir . '/_rss-' . Digest::MD5::md5_hex( $theUrl );
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
    # figure out how to get to TWiki::Net which is wide open in Cairo and before,
    # but Dakar uses the session object.  
    my $text = $TWiki::Plugins::SESSION->{net}
	? $TWiki::Plugins::SESSION->{net}->getUrl( $host, $port, $path )
	: TWiki::Net::getUrl( $host, $port, $path );

    if( $text =~ /text\/plain\s*ERROR\: (.*)/s ) {
        my $msg = $1;
        $msg =~ s/[\n\r]/ /gos;
        return "ERROR: Can't read $theUrl ($msg)";
    }
    if( $text =~ /HTTP\/[0-9\.]+\s*([0-9]+)\s*([^\n]*)/s ) {
        unless( $1 == 200 ) {
           return "ERROR: Can't read $theUrl ($1 $2)";
        }
    }
    $text =~ s/\r\n/\n/gos;
    $text =~ s/\r/\n/gos;
    $text =~ s/^.*?\n\n(.*)/$1/os;  # strip header
    $text =~ s/\n/ /gos;            # new line to space
    $text =~ s/ +/ /gos;

    if( $theRefresh ) {
        unless( -e $cacheDir ) {
            # create the cache directory in the pub dir of the HeadlinesPlugin
            umask( 002 );
            mkdir( $cacheDir, 0775 );
        }
        # save text in cache file before returning it
        TWiki::Func::saveFile( $cacheFile, $text );
    }

    return $text;
}

# =========================
sub _handleHeadlinesTag
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

    my $href    = TWiki::Func::extractNameValuePair( $theArgs, "href" ) || TWiki::Func::extractNameValuePair( $theArgs );
    my $refresh = TWiki::Func::extractNameValuePair( $theArgs, "refresh" ) || $defaultRefresh;
    my $limit   = TWiki::Func::extractNameValuePair( $theArgs, "limit" )   || $defaultLimit;
    my $header  = TWiki::Func::extractNameValuePair( $theArgs, "header" )  || $defaultHeader;
    my $format  = TWiki::Func::extractNameValuePair( $theArgs, "format" )  || $defaultFormat;

    $header =~ s/\$n([^a-zA-Z])/\n$1/gos; # expand "$n" to new line
    $header =~ s/([^\n])$/$1\n/os;        # append new line if needed
    $format =~ s/\$n([^a-zA-Z])/\n$1/gos; # expand "$n" to new line
    $format =~ s/([^\n])$/$1\n/os;        # append new line if needed

    unless( $href ) {
        return _errorMsg( $thePre, "href parameter (news source) is missing" );
    }

    my $raw = _readRssFeed( $href, $refresh );
    if( $raw =~ /^ERROR\: (.*)/s ) {
        return _errorMsg( $thePre, $1 );
    }

    my $text = "$thePre<noautolink>\n";
    my $sub = "";
    my $val = "";
    if( $raw =~ /<channel.*?>(.*?)<\/channel>/ ) {
        $sub = $1;
        if( $sub =~ /<title>(.*?)<\/title>/ ) {
            $val = $1;
            $header =~ s/\$channeltitle/$val/gos;
        }
        if( $sub =~ /<link>(.*?)<\/link>/ ) {
            $val = $1;
            $header =~ s/\$channellink/$val/gos;
        }
        if( $sub =~ /<description>(.*?)<\/description>/ ) {
            $val = $1;
            $header =~ s/\$channeldescription/$val/gos;
        }
    }
    if( $raw =~ /<image.*?>(.*?)<\/image>/ ) {
        $sub = $1;
        if( $sub =~ /<title>(.*?)<\/title>/ ) {
            $val = $1;
            $header =~ s/\$imagetitle/$val/gos;
        }
        if( $sub =~ /<url>(.*?)<\/url>/ ) {
            $val = $1;
            $header =~ s/\$imageurl/$val/gos;
        }
        if( $sub =~ /<link>(.*?)<\/link>/ ) {
            $val = $1;
            $header =~ s/\$imagelink/$val/gos;
        }
        if( $sub =~ /<description>(.*?)<\/description>/ ) {
            $val = $1;
            $header =~ s/\$imagedescription/$val/gos;
        }
    }
    # Clean-up in case tags are not defined
    $header =~ s/\$imagetitle/ /gos;
    $header =~ s/\$imageurl/ /gos;
    $header =~ s/\$imagelink/ /gos;
    $header =~ s/\$imagedescription/ /gos;
    $text .= "$thePre$header";

    $raw =~ s/.*?(<item[^a-z])/$1/os;  # cut stuff above all <item>s
    my $line = "";
    my $ok = 0;
    my $count = 0;
    foreach ( split( /<item.*?>/, $raw ) ) {
        $line = $format;
        $ok = 0;
        if( /<title>(.*?)<\/title>/ ) {
            $val = $1;
            $line =~ s/\$title/$val/gos;
            $ok = 1;
        }
        if( /<link>(.*?)<\/link>/ ) {
            $val = $1;
            $line =~ s/\$link/$val/gos;
            $ok = 1;
        }
        if( /<description>(.*?)<\/description>/ ) {
            $val = $1;
            $line =~ s/\$description/$val/gos;
            $ok = 1;
        }
        $text .= "$thePre$line" if( $ok );
        $count++;
        last if( $count > $limit );
    }

    $text .= "$thePre</noautolink>\n";

    return $text;
}

# =========================

1;
