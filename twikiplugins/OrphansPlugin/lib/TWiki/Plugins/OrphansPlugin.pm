# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2004 Peter Thoeny, peter@thoeny.com
# Plugin written by http://TWiki.org/cgi-bin/view/Main/CrawfordCurrie
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
# Plugin that supports content management operations
#
package TWiki::Plugins::OrphansPlugin;

use vars qw( $VERSION $RELEASE $SHORTDESCRIPTION $ready );

$VERSION = '$Rev$';
$RELEASE = '4.0.4';
$SHORTDESCRIPTION = 'Locate and manage orphaned topics';
$ready = 0;

sub initPlugin {

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.1 ) {
        die "Require Plugins.pm >= 1.1";
    }

    TWiki::Func::registerTagHandler('FINDORPHANS', \&_findOrphans);

    return 1;
}

# Handle the "FINDORPHANS" tag
sub _findOrphans {
    my ( $session, $params, $topic, $web ) = @_;
    unless( $ready ) {
        # Lazy-use
        eval 'use TWiki::Plugins::OrphansPlugin::Orphans';
        die $@ if $@;
        $ready = 1;
    }
    my $orphans = new TWiki::Plugins::OrphansPlugin::Orphans( $web, $params );
    return $orphans->tabulate( $params );
}

1;
