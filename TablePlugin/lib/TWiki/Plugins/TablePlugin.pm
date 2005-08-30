# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2001-2003 John Talintyre, jet@cheerful.com
# Copyright (C) 2001-2004 Peter Thoeny, peter@thoeny.com
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
# Allow sorting of tables, plus setting of background colour for
# headings and data cells
# see TWiki.TablePlugin for details of use
use strict;

package TWiki::Plugins::TablePlugin;

use vars qw( $topic $installWeb $VERSION $initialised );

$VERSION = '1.014';

sub initPlugin {
    my( $web, $user );
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning( 'Version mismatch between TablePlugin and Plugins.pm' );
        return 0;
    }

    my $cgi = TWiki::Func::getCgiQuery();
    return 0 unless $cgi;

    $initialised = 0;

    return 1;
}

sub preRenderingHandler {
    ### my ( $text, $removed ) = @_;

    my $sort = TWiki::Func::getPreferencesValue( 'TABLEPLUGIN_SORT' );
    return unless $sort =~ /^(all|attachments)$/ || $_[0] =~ /%TABLE{.*?}%/;

    # on-demand inclusion
    eval 'use TWiki::Plugins::TablePlugin::Core';
    die $@ if $@;
    TWiki::Plugins::TablePlugin::Core::handler( @_ );
}

1;
