# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2001-2011 Peter Thoeny, peter@thoeny.org
# Copyright (C) 2011 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root of
# this distribution. NOTE: Please extend that file, not this notice.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# For licensing info read LICENSE file in the TWiki root.

package TWiki::Plugins::RecentVisitorPlugin;

use strict;

require TWiki::Func;    # The plugins API
require TWiki::Plugins; # For the API version

use vars qw(
      $VERSION $RELEASE $SHORTDESCRIPTION $NO_PREFS_IN_TOPIC
      $pluginName $debug $showIP $baseTopic $baseWeb $loginUser $loginIsAdmin
    );

$VERSION = '$Rev$';
$RELEASE = '2011-02-05';

# One line description, is shown in the %TWIKIWEB%.TextFormattingRules topic:
$SHORTDESCRIPTION = 'Show recent visitors to a TWiki site';

$NO_PREFS_IN_TOPIC = 1;

$pluginName = 'RecentVisitorPlugin';

# =========================
sub initPlugin {
    ( $baseTopic, $baseWeb, $loginUser ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.1 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    # configuration to the =configure= interface.
    $debug = $TWiki::cfg{Plugins}{RecentVisitorPlugin}{Debug} || 0;
    $showIP = $TWiki::cfg{Plugins}{RecentVisitorPlugin}{ShowIP} || 0;
    $loginIsAdmin = 0;

    TWiki::Func::registerTagHandler( 'RECENTVISITOR', \&_RECENTVISITOR );

    _recordVisitor( $loginUser ) unless( $loginUser =~ /(TWikiGuest|guest)/ );

    # Plugin correctly initialized
    return 1;
}

# =========================
sub _RECENTVISITOR {
    my( $session, $params ) = @_;

    my $text = '';
    my $action   = $params->{action} || $params->{_DEFAULT};
    my $now = time();
    $loginIsAdmin = TWiki::Func::isAnAdmin( $loginUser )
       if( defined &TWiki::Func::isAnAdmin );

    if( $action =~ /user/i ) {
        my $wikiName = $params->{name} || $loginUser;
        $text = $params->{format} || 'Last seen $ago ago';
        $text = _expandStandardEscapes( $text );
        my ( $time, $addr ) = _readVisitor( $wikiName );

        if( $time ) {
            $text =~ s/\$date/_formatDate( $time, 0 )/geo;
            $text =~ s/\$time/_formatDate( $time, 1 )/geo;
            $text =~ s/\$ago/_formatAgo( $time, $now )/geo;
            $text =~ s/\$ip/_formatIP( $addr )/geo;
        } else {
            $text = $params->{notfound} || 'Never seen';
        }

    } elsif( $action =~ /recent/i ) {
        my $format = $params->{format} || '   * $wikiusername last seen $ago ago';
        $format = _expandStandardEscapes( $format );
        my $sep    = $params->{separator} || "\n";
        $sep = _expandStandardEscapes( $sep );
        my $limit  = int( $params->{limit} || 0 );
        $limit = 20 if( $limit < 1 );
        my $ref = _readAllVisitors();
        foreach my $key ( sort { $ref->{$b}[0] <=> $ref->{$a}[0] } ( keys( %$ref ) ) ) {
            last unless( $limit-- );
            my $line = $format;
            $line =~ s/\$wikiname/$key/go;
            $line =~ s/\$wikiusername/$TWiki::cfg{UsersWebName}.$key/go;
            $line =~ s/\$username/TWiki::Func::wikiToUserName( $key )/geo;
            $line =~ s/\$date/_formatDate( $ref->{$key}[0], 0 )/geo;
            $line =~ s/\$time/_formatDate( $ref->{$key}[0], 1 )/geo;
            $line =~ s/\$ago/_formatAgo( $ref->{$key}[0], $now )/geo;
            $line =~ s/\$ip/_formatIP( $ref->{$key}[1] )/geo;
            $text .= $line;
            $text .= $sep;
        }
        $text =~ s/$sep^//;

    } else {
        $text = "RECENTVISITOR error: No action specified."
    }
    return $text;
}

# =========================
sub _formatDate {
    my( $time, $isTime ) = @_;

    return '' unless( $time );

    my( $sec, $min, $hour, $day, $mon, $year, $wday, $yday ) = gmtime( $time );
    my $text = '';

    if( $isTime ) {
        $text = sprintf( "%.2u", $hour ) . ':'
              . sprintf( "%.2u", $min );
    } else {
        $text = sprintf( "%.4u", $year+1900 ) . '-'
              . sprintf( "%.2u", $mon+1 ) . '-'
              . sprintf( "%.2u", $day );
    }

    return $text;
}

# =========================
sub _formatAgo {
    my( $time, $now ) = @_;

    return '' unless( $time );

    my $text = '';
    my $diff = $now - $time;

    if( $diff < 10 ) {
        $text = 'moments';
    } elsif( $diff < 60 ) {
        $text = $diff . ' seconds';
    } elsif( $diff < 60*60 ) {
        $text = int( $diff/60 ) . ' minutes';
    } elsif( $diff < 60*60*24 ) {
        $text = int( $diff/(60*60) ) . ' hours';
    } elsif( $diff < 60*60*24*30 ) {
        $text = int( $diff/(60*60*24) ) . ' days';
    } else {
        $text = int( $diff/(60*60*24*30) ) . ' months';
    }
    $text =~ s/^(1 .*)s$/$1/; # plural to singular

    return $text;
}

# =========================
sub _formatIP {
    my( $addr ) = @_;
    return '' unless( $showIP || $loginIsAdmin );
    return $addr;
}

# =========================
sub _expandStandardEscapes {
    my $text = shift;

    if( defined &TWiki::Func::decodeFormatTokens ) {
        return TWiki::Func::decodeFormatTokens( $text );
    }

    $text =~ s/\$n\(\)/\n/gos;         # expand '$n()' to new line
    $text =~ s/\$n\b/\n/gos;           # expand '$n' to new line
    $text =~ s/\$nop(\(\))?//gos;      # remove filler, useful for nesting
    $text =~ s/\$quot(\(\))?/\"/gos;   # expand double quote
    $text =~ s/\$percnt(\(\))?/\%/gos; # expand percent
    $text =~ s/\$dollar(\(\))?/\$/gos; # expand dollar
    return $text;
}

# =========================
sub _recordVisitor {
    my( $loginUser ) = @_;

    my $wikiUser = TWiki::Func::getWikiName( $loginUser );
    my $file = TWiki::Func::getWorkArea( $pluginName ) . "/user-$wikiUser.txt";
    my $remoteAddr = $ENV{REMOTE_ADDR} || '';
    if( ! $remoteAddr && $TWiki::Plugins::SESSION->{request} ) { 
        $remoteAddr    = $TWiki::Plugins::SESSION->{request}->remoteAddress() || '';
    }
    my $text = "Epoch: " . time() . "\n"
             . "IP: $remoteAddr\n";
    TWiki::Func::saveFile( $file, $text );
}

# =========================
sub _readVisitor {
    my( $loginUser ) = @_;

    my $wikiUser = TWiki::Func::getWikiName( $loginUser );
    my $file = TWiki::Func::getWorkArea( $pluginName ) . "/user-$wikiUser.txt";
    return ( 0, '' ) unless( -e $file );

    my $text = TWiki::Func::readFile( $file );
    if( $text =~ /.*?Epoch: *([^\n]*).*IP: *([^\n]*)/s ) {
        return( $1, $2 );
    }
    return( 0, '' );
}

# =========================
sub _readAllVisitors {

    my $ref;
    my $workDir = TWiki::Func::getWorkArea( $pluginName );
    opendir( WKDIR, $workDir ) || return $ref;
    my @files = grep{ /user-.*txt/ } readdir( WKDIR );
    closedir( WKDIR );

    foreach my $file ( @files ) {
        my $text = TWiki::Func::readFile( "$workDir/$file" );
        $file =~ s/^user-(.*?).txt$/$1/;
        if( $text =~ /.*?Epoch: *([^\n]*).*IP: *([^\n]*)/s ) {
            $ref->{$file} = [ $1, $2 ];
        }
    }
    return $ref;
}

# =========================
1;
