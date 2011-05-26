# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2004-2011 Peter Thoeny, peter[at]thoeny.org, Twiki Inc.
# Copyright (C) 2008-2011 TWiki Contributors
#
# For licensing info read LICENSE file in the TWiki root.
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
# As per the GPL, removal of this notice is prohibited.

# =========================
package TWiki::Plugins::VarCachePlugin;

# =========================
our $VERSION = '$Rev$';
our $RELEASE = '2011-05-24';

# =========================
our $SHORTDESCRIPTION = 'Cache TWiki variables in selected topics for faster page rendering';
our $NO_PREFS_IN_TOPIC = 1;
our $pluginName = 'VarCachePlugin';  # Name of this Plugin
our $web, $topic, $user, $installWeb, $debug;

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.024 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    # Get plugin debug flag
    $debug = TWiki::Func::getPreferencesFlag( "\U$pluginName\E_DEBUG" );

    # Plugin correctly initialized
    TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}

# =========================
sub beforeCommonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::beforeCommonTagsHandler( $_[2].$_[1] )" ) if $debug;

    return unless( $_[0] =~ /%VARCACHE/ );

    $_[0] =~ s/%VARCACHE(?:{(.*?)})?%/_handleVarCache( $_[2], $_[1], $1 )/ge;

    # if "read cache", replace all text with marker, to be filled in afterCommonTagsHandler
    $_[0] =~ s/^.*(%--VARCACHE\:read\:.*?--%).*$/$1/os;
}

# =========================
sub afterCommonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::afterCommonTagsHandler( $_[2].$_[1] )" ) if $debug;

    return unless( $_[0] =~ /%--VARCACHE\:/ );

    if( $_[0] =~ /%--VARCACHE\:([a-z]+)\:?(.*?)(?:\001(.*?)\001)?--%/ ) {
        my $save = ( $1 eq "save" );
        my $age = $2 || 0;
        my $tag = $3;
        my $cacheFilename = _cacheFileName( $_[2], $_[1], $save );

        if( $save ) {
            # update cache
            TWiki::Func::saveFile( $cacheFilename, $_[0] );
            $msg = _formatMsg( $_[2], $_[1], $tag );
            $_[0] =~ s/%--VARCACHE\:.*?--%/$msg/go;

            # cache addToHEAD info
            # FIXME: Enhance the TWiki::Func API to get the head info cleanly
            $cacheFilename = _cacheFileName( $_[2], $_[1], 0, 1 );
            my $htmlHeader = '';
            TWiki::Func::saveFile( $cacheFilename, '' ); # clear
            my $session = $TWiki::Plugins::SESSION;
            if( $session && $session->{_HTMLHEADERS} ) {
                $htmlHeader = join( "\n",
                  map { '<!--VARCACHE_HEAD_'.$_.'-->'.$session->{_HTMLHEADERS}{$_} }
                  keys %{$session->{_HTMLHEADERS}} );
            }
            TWiki::Func::saveFile( $cacheFilename, $htmlHeader );

        } else {
            # read cache
            my $text = TWiki::Func::readFile( $cacheFilename );
            $msg = _formatMsg( $_[2], $_[1], $tag );
            $msg =~ s/\$age/_formatAge($age)/geo;
            $text =~ s/%--VARCACHE.*?--%/$msg/go;
            $_[0] = $text;

            # restore addToHEAD info from cache
            $cacheFilename = _cacheFileName( $_[2], $_[1], 0, 1 );
            my $htmlHeader = TWiki::Func::readFile( $cacheFilename );
            foreach ( split /<!--VARCACHE_HEAD_/, $htmlHeader ) {
                if( /^(.*?)-->(.+)$/s ) {
                    TWiki::Func::addToHEAD( $1, $2 );
                }
            }
        }
    }
}

# =========================
sub _formatMsg
{
    my ( $theWeb, $theTopic, $msg ) = @_;

    $msg =~ s|<nop>||go;
    $msg =~ s|\$link|%SCRIPTURL{view}%/%WEB%/%TOPIC%?varcache=refresh|go;
    $msg =~ s|%ATTACHURL%|%PUBURL%/$installWeb/$pluginName|go;
    $msg =~ s|%ATTACHURLPATH%|%PUBURLPATH%/$installWeb/$pluginName|go;
    $msg = TWiki::Func::expandCommonVariables( $msg, $theTopic, $theWeb );
    return $msg;
}

# =========================
sub _formatAge
{
    my ( $age ) = @_;

    my $unit = "hours";
    if( $age > 24 ) {
        $age /= 24;
        $unit = "days";
    } elsif( $age < 1 ) {
        $age *= 60;
        $unit = "min";
        if( $age < 1 ) {
            $age *= 60;
            $unit = "sec";
        }
    }
    if( $age >= 3 || $unit eq "sec" ) {
        $age = int( $age );
        return "$age $unit";
    }
    return sprintf( "%1.1f $unit", $age );
}

# =========================
sub _handleVarCache
{
    my ( $theWeb, $theTopic, $theArgs ) = @_;

    my $query = TWiki::Func::getCgiQuery();
    my $action = "check";
    if( $query ) {
        my $tmp = $query->param( 'varcache' ) || "";
        if( $tmp eq "refresh" ) {
            $action = "refresh";
        } else {
            $action = "" if( grep{ !/^varcache$/ } $query->param );
        }
    }

    if( $action eq "check" ) {
        my $filename = _cacheFileName( $theWeb, $theTopic, 0 );
        if( -e $filename ) {
            my $now = time();
            my $cacheTime = (stat $filename)[9] || 10000000000;
            # CODE_SMELL: Assume file system for topics
            $filename = TWiki::Func::getDataDir() . "/$theWeb/$theTopic.txt";
            my $topicTime = (stat $filename)[9] || 10000000000;
            my $refresh = TWiki::Func::extractNameValuePair( $theArgs )
                       || TWiki::Func::extractNameValuePair( $theArgs, "refresh" );
            $refresh = TWiki::Func::getPreferencesValue( "\U$pluginName\E_REFRESH" ) unless( $refresh || $refresh eq '0' );
            $refresh = 24 unless( $refresh || defined $refresh && $refresh eq '0' );
            $refresh *= 3600;
            if( ( ( $refresh == 0 ) || ( $cacheTime >= $now - $refresh ) )
             && ( $cacheTime >= $topicTime ) ) {
                # add marker for afterCommonTagsHandler to read cached file
                my $paramMsg = TWiki::Func::extractNameValuePair( $theArgs, "cachemsg" )
                            || TWiki::Func::getPreferencesValue( "\U$pluginName\E_CACHEMSG" )
                            || 'This topic was cached $age ago ([[$link][refresh]])';
                $cacheTime = sprintf( "%1.6f", ( $now - $cacheTime ) / 3600 );
                return "%--VARCACHE\:read:$cacheTime\001$paramMsg\001--%";
            }
        }
        $action = "refresh";
    }

    if( $action eq "refresh" ) {
        # add marker for afterCommonTagsHandler to refresh cache file
        my $paramMsg = TWiki::Func::extractNameValuePair( $theArgs, "updatemsg" )
                    || TWiki::Func::getPreferencesValue( "\U$pluginName\E_UPDATEMSG" )
                    || 'This topic is now cached ([[$link][refresh]])';
        
        return "%--VARCACHE\:save\001$paramMsg\001--%";
    }

    # else normal uncached processing
    return "";
}

# =========================
sub _cacheFileName
{
    my ( $web, $topic, $mkDir, $isHead ) = @_;

    my $dir = TWiki::Func::getWorkArea($pluginName) . "/$web";
    if( ( $mkDir ) && ( ! -e "$dir" ) ) {
        my $sumsk = umask( 002 );
        mkdir( $dir, $TWiki::cfg{RCS}{dirPermission} );
        umask( $sumsk );
    }

    return "$dir/${topic}_cache." . ($isHead? 'head' : 'txt');
}

# =========================
1;
