# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2010 Peter Thoeny, peter@thoeny.org
# Copyright (C) 2003 TWiki:Main.WillNorris
# Copyright (C) 2008-2011 TWiki Contributors. All Rights Reserved.
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

package TWiki::Plugins::PageStatsPlugin;

use strict;

require TWiki::Func;    # The plugins API
require TWiki::Plugins; # For the API version

use vars qw( $VERSION $RELEASE $debug );

$VERSION = '$Rev$';
$RELEASE = '2011-02-01';

#=========================================================
sub initPlugin {
    my( $topic, $web ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.1 ) {
        TWiki::Func::writeWarning( "Version mismatch between PageStatsPlugin and Plugins.pm" );
        return 0;
    }

    $debug = $TWiki::cfg{Plugins}{EmptyPlugin}{Debug} || 0;

    TWiki::Func::registerTagHandler( 'PAGESTATS', \&_PAGESTATS );

    return 1;
}

#=========================================================
sub _PAGESTATS
{ 
    my( $session, $params, $theTopic, $theWeb ) = @_;
    my ( $attributes ) = @_;

    my $topic = $params->{_DEFAULT} || $params->{topic} || $theTopic;
    my $web   = $params->{web} || $theWeb;

    my( $sec, $min, $hour, $day, $mon, $year, $wday, $yday ) = localtime( time() );
    $year = sprintf( "%.4u", $year + 1900 );
    $mon  = sprintf( "%.2u", $mon + 1 );

    my $logFile = $TWiki::cfg{LogFileName};
    if( $logFile ) {
        $logFile =~ s/\%DATE\%/$year$mon/;
    } else {
        $logFile = TWiki::Func::getDataDir() . "/log$year$mon.txt";
    }
    my @pagestats =
        reverse
        map{ s/ (save) / <b>$1<\/b> /; $_ }
        grep{ / (view|save) / }
        grep{ / $web\.$topic / }
        split( /[\n\r]+/, TWiki::Func::readFile( $logFile ) );

    my $i = int( $params->{max} || 0 );
    if( ( $i > 0 ) && ( $i < scalar @pagestats ) ) {
        $#pagestats = $i - 1;
    }

    return qq{<div class="PageStats">\n}
	. "| *Timestamp* | *User* | *Action* | *Page* | *Extra* | *IP Address* |\n"
	. join( "\n", @pagestats )
	. "\n</div>";
}

#=========================================================
1;
