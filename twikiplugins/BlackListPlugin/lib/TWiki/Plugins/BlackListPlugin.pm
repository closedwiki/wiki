# Q&D implementation of backlist handler. Black sheep get a 
# timeout and a message
#
# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2004-2005 Peter Thoeny, peter@thoeny.com
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
package TWiki::Plugins::BlackListPlugin;

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $pluginName
        $debug %cfg
        $userScore $isBlackSheep
    );

BEGIN {
    $VERSION = 1.104;
    $pluginName = 'BlackListPlugin';  # Name of this Plugin
    %cfg =
        (
            "ptReg"   => 10,
            "ptChg"   => 5,
            "ptView"  => 1,
            "ptRaw"   => 30,
            "ptLimit" => 100,
            "period"  => 300,
        );
    $userScore = "N/A";
    $isBlackSheep = 0;
    $noFollowAge = 0;
    $topicAge = 0;
    $urlHost = "initialized_later";
}

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    # get debug flag
    $debug = TWiki::Func::getPreferencesFlag( "\U$pluginName\E_DEBUG" );

    # initialize for rel="nofollow" links
    $urlHost = TWiki::Func::getUrlHost();
    $noFollowAge = TWiki::Func::getPreferencesValue( "\U$pluginName\E_NOFOLLOWAGE" ) || 0;
    $noFollowAge =~ s/.*?(\-?[0-9]*.*)/$1/ || 0;
    $noFollowAge = 0 unless( $noFollowAge );
    if( $noFollowAge > 0 ) {
        $noFollowAge *= 3600;
        my( $date ) = TWiki::Func::getRevisionInfo( $web, $topic );
        $topicAge = time() - $date if( $date );
    }

    # white list
    my $whiteList = TWiki::Func::getPreferencesValue( "\U$pluginName\E_WHITELIST" ) || "127.0.0.1";
    $whiteList = join( "|", map { quotemeta } split( /,\s*/, $whiteList ) );
    $whiteList = "($whiteList)";

    # black list
    my $blackList = TWiki::Func::getPreferencesValue( "\U$pluginName\E_BLACKLIST" ) || "";
    $blackList = join( "|", map { quotemeta } split( /,\s*/, $blackList ) );

    # ban list
    my $remoteAddr = $ENV{'REMOTE_ADDR'}   || "";
    my $scriptName = $ENV{'SCRIPT_NAME'}   || "";
    my $queryString = $ENV{'QUERY_STRING'} || "";
    my $banList = _handleBanList( "read", $remoteAddr );
    $banList = join( "|", map { quotemeta } split( /\n/, $banList ) );

    # black list + ban list regular expression
    my $blackRE = "($blackList";
    $blackRE .= "|" if( $blackList && $banList );
    $blackRE .= "$banList)";

    # black sheep if in black list unless in white list
    $isBlackSheep = 0;
    $userScore = "N/A";
    if( ( $remoteAddr ) && ( $remoteAddr !~ /^$whiteList/ ) ) {
        if( $remoteAddr =~ /^$blackRE/ ) {
            # already a black sheep
            $isBlackSheep = 1;
        } else {
            # check for new candidate of black sheep

            my( $c1, $c2, $c3, $c4, $c5, $c6 ) = split( /, */, TWiki::Func::getPreferencesValue( "\U$pluginName\E_BANLISTCONFIG" ) );
            $cfg{ "ptReg" }   = $c1 || 10;
            $cfg{ "ptChg" }   = $c2 || 5;
            $cfg{ "ptView" }  = $c3 || 1;
            $cfg{ "ptRaw" }   = $c4 || 30;
            $cfg{ "ptLimit" } = $c5 || 100;
            $cfg{ "period" }  = $c6 || 300;

            $userScore = _handleEventLog( $remoteAddr, $scriptName, $queryString );
            TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName}::initPlugin() score: $userScore" ) if $debug;
            if( $userScore > $cfg{ "ptLimit" } ) {
                $isBlackSheep = 1;
                _handleBanList( "add", $remoteAddr );
                _writeLog( "BANLIST add: $remoteAddr, $userScore over limit $cfg{ \"ptLimit\" }" );
            }
        }
    }

    if( $isBlackSheep ) {
        # black sheep identified
        _writeLog( $scriptName );
        # sleep for one minute
        sleep 60 unless( $debug );
        if( $scriptName =~ /view/ ) {
            # view script: show message later in commonTagsHandler
        } else {
            # other scripts: force a "500 Internal Server Error" error
            exit 1;
        }
    }

    # Plugin correctly initialized
    TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK, "
                           . "whiteList $whiteList, blackRE $blackRE" ) if $debug;
    return 1;
}

# =========================
sub commonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::commonTagsHandler( $_[2].$_[1] )" ) if $debug;

    if( $isBlackSheep ) {
        my $message = TWiki::Func::getPreferencesValue( "\U$pluginName\E_BLACKLISTMESSAGE" ) ||
                      "You are black listed at %WIKITOOLNAME%. "
                    . "In addition, your IP address will be submitted to major blacklist databases.";
        $_[0] = $message;
    }
    $_[0] =~ s/%BLACKLIST{(.*?)}%/_handleBlackList( $1, $_[2], $_[1] )/geo;
}

# =========================
sub endRenderingHandler
{
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

    TWiki::Func::writeDebug( "- ${pluginName}::endRenderingHandler( $web.$topic )" ) if $debug;

    # This handler is called by getRenderedVersion just after the line loop, that is,
    # after almost all XHTML rendering of a topic. <nop> tags are removed after this.

    return unless( $noFollowAge );
    $_[0] =~ s/(<a .*?href=[\"\']?)([^\"\'\s]+[\"\']?)(\s*[a-z]*)/_handleNofollowLink( $1, $2, $3 )/geoi;
}

# =========================
sub _handleBlackList
{
    my( $theAttributes, $theWeb, $theTopic ) = @_;
    my $action = &TWiki::Func::extractNameValuePair( $theAttributes, "action" );
    my $value  = &TWiki::Func::extractNameValuePair( $theAttributes, "value" );
    my $text = "";
    if( $action eq "ban_show" ) {
        $text = _handleBanList( "read", "" );
        $text =~ s/[\n\r]+$//os;
        $text =~ s/[\n\r]+/, /gos;

    } elsif( $action eq "user_score" ) {
        $text = $userScore;

    } elsif( $action =~ /^(ban_add|ban_remove)$/ ) {
        if( "$theWeb.$theTopic" eq "$installWeb.$pluginName" ) {
            my $wikiName = &TWiki::Func::userToWikiName( $user );
            if(  &TWiki::Func::checkAccessPermission( "CHANGE", $wikiName, "", $pluginName, $installWeb ) ) {
                if( $action eq "ban_add" ) {
                    $text = _handleBanList( "add", $value );
                    _writeLog( "BANLIST add: $value, by user" );
                } else {
                    $text = _handleBanList( "remove", $value );
                    _writeLog( "BANLIST delete: $value by user" );
                }
            } else {
                $text = "Error: You do not have permission to add IP addresses";
            }
        } else {
             $text = "Error: For use on $installWeb.$pluginName topic only";
        }
        $text .= " [ [[$theWeb.$theTopic][OK]] ]";
    }
    return $text;
}

# =========================
sub _handleBanList
{
    my ( $theAction, $theIP ) = @_;
    my $fileName = _makeFileName( "ban_list", 0 );
    TWiki::Func::writeDebug( "- ${pluginName}::_handleBanList( Action: $theAction, IP: $theIP, file: $fileName )" ) if $debug;
    my $text = TWiki::Func::readFile( $fileName ) || "# The ban-list is a generated file, do not edit\n";
    if( $theAction eq "read" ) {
        $text =~ s/^\#[^\n]*\n//s;
        return $text;

    } elsif( $theAction eq "add" ) {
        unless( ( $theIP ) && ( $theIP =~ /^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$/ ) ) {
            return "Error: Invalid IP address $theIP";
        }
        if( $text =~ s/(\n)\Q$theIP\E\n/$1/s ) {
            return "Error: IP address $theIP is already on the list";
        }
        $text .= "$theIP\n";
        TWiki::Func::saveFile( $fileName, $text );
        unless( -e "$fileName" ) {
            # assuming save failed because of missing dir
            _makeFileDir();
            TWiki::Func::saveFile( $fileName, $text );
        }
        return "Note: Added IP address $theIP";

    } elsif( $theAction eq "remove" ) {
        unless( ( $theIP ) && ( $text =~ s/(\n)\Q$theIP\E\n/$1/s ) ) {
            return "Error: IP address $theIP not found";
        }
        TWiki::Func::saveFile( $fileName, $text );
        return "Note: Removed IP address $theIP";
    }
}

# =========================
sub _handleEventLog
{
    my ( $theIP, $theType, $theQueryString ) = @_;

    # read/update/save event logs
    my $fileName = _makeFileName( "event_log" );
    TWiki::Func::writeDebug( "- ${pluginName}::_handleEventLog( IP: $theIP, type: $theType, query: $theQueryString )" ) if $debug;
    my $text = TWiki::Func::readFile( $fileName ) || "# The event-list is a generated file, do not edit\n";
    my $time = time();
    $text .= "$time, $theIP, $theType";
    $text .= "__R_A_W__" if( $theQueryString =~ /raw\=/ );
    $text .= "\n";
    my $limit = $time - $cfg{"period"};
    if( ( $text =~ /([0-9]+)/ ) && ( $1  < $time - 8 * $cfg{"period"} ) ) {
        # for efficiency, clean up expired events only once in a while
        my @arr = split( /\n/, $text );
        my $index = 0;
        my $limit = $time - $cfg{"period"};
        foreach( @arr ) {
            if( ( /^([0-9]+)/ ) && ( $1 >= $limit ) ) {
                last;
            }
            $index++;
        }
        $text = "$arr[0]\n";  # keep comment
        $text .= join( "\n", @arr[$index..$#arr] ) if( $index <= $#arr );
        $text .= "\n";
    }
    TWiki::Func::saveFile( $fileName, $text );

    # extract IP addresses of interest and calculate score
    my $score = 0;
    $type = "";
    foreach( grep { / \Q$theIP\E\,/ } split( /\n/, $text ) ) {
        if( ( /^([0-9]+)\,[^\,]+\, ?(.*)/ ) && ( $1 >= $limit ) ) {
            $type = $2;
            if( $type =~ /register/ ) {
                $score += $cfg{"ptReg"};
            }elsif( $type =~ /(save|upload)/ ) {
                $score += $cfg{"ptChg"};
            }elsif( $type =~ /__R_A_W__/ ) {
                $score += $cfg{"ptRaw"};
            } else {
                $score += $cfg{"ptView"};
            }
        }
    }
    return $score;
}

# =========================
sub _makeFileName
{
    my ( $name ) = @_;
    my $dir = TWiki::Func::getPubDir() . "/$installWeb/$pluginName";
    return "$dir/_$name.txt";
}

# =========================
sub _makeFileDir
{
    # Create web directory "pub/$installWeb" if needed
    my $dir = TWiki::Func::getPubDir() . "/$installWeb";
    unless( -e "$dir" ) {
        umask( 002 );
        mkdir( $dir, 0775 );
    }
    # Create topic directory "pub/$installWeb/$pluginName" if needed
    $dir .= "/$pluginName";
    unless( -e "$dir" ) {
        umask( 002 );
        mkdir( $dir, 0775 );
    }
}

# =========================
sub _writeLog
{
    my ( $theText ) = @_;
    if( TWiki::Func::getPreferencesFlag( "\U$pluginName\E_LOGACCESS" ) ) {
        # FIXME: Call to unofficial function
        TWiki::Store::writeLog( "blacklist", "$web.$topic", $theText );
        ##TWiki::Func::writeDebug( "BLACKLIST access by $remoteAddr, $web/$topic, $theText" );
    }
}

# =========================
sub _handleNofollowLink
{
    my( $thePrefix, $theUrl, $thePostfix ) = @_;

    # Codev.SpamDefeatingViaNofollowAttribute: Add a rel="nofollow" to URL
    my $addRel = 0;
    my $text = "$thePrefix$theUrl$thePostfix";
    $theUrl =~ m/^http/i      && ( $addRel = 1 ); # only for http and hhtps
    $theUrl =~ m/^$urlHost/i  && ( $addRel = 0 ); # not for own host
    $theUrl =~ m/twiki\.org/i && ( $addRel = 0 ); # not for twiki.org
    $thePostfix =~ m/^\s?rel/ && ( $addRel = 0 ); # prevent adding it twice

    $addRel = 0 if( $noFollowAge > 0 && $topicAge > $noFollowAge ); # old topic

    return $text unless( $addRel );
    return "$thePrefix$theUrl rel=\"nofollow\"$thePostfix";
}

# =========================

1;
