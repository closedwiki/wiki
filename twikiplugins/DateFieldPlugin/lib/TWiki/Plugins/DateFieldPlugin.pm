#
# Date field entry plugin
#
# Copyright (C) Deutsche Bank AG http://www.db.com
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

package TWiki::Plugins::DateFieldPlugin;

use strict;

use TWiki::Func;

use vars qw( $VERSION $RELEASE );

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';


sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;

    # make sure JSCalendar is there
    eval 'use TWiki::Contrib::JSCalendarContrib';
    if ( $@ ) {
        my $mess = "WARNING: JSCalendar not installed: $@";
        print STDERR "$mess\n";
        TWiki::Func::writeWarning( $mess );
        return 0;
    }

    return 1;
}

sub beforeEditHandler {
    # Load the 'twiki' calendar setup
    TWiki::Contrib::JSCalendarContrib::addHEAD( 'twiki' );
}

sub renderFormFieldForEditHandler {
    my ( $name, $type, $size, $value, $attributes, $possibleValues ) = @_;
    my $calendarOutputFormat = TWiki::Func::getPreferencesValue('DATEFIELDPLUGIN_DATEFORMAT') || '%d %b %Y';
    return unless $type eq "date";

    my $content =
      CGI::image_button(
          -name => 'calendar',
          -onclick =>
            "return showCalendar('date_$name','$calendarOutputFormat')",
          -src=> TWiki::Func::getPubUrlPath() . '/' .
            TWiki::Func::getTwikiWebname() .
                '/JSCalendarContrib/img.gif',
          -alt => 'Calendar',
          -align => 'MIDDLE' );
    return CGI::textfield( { name => $name,
                             value => $value,
                             size => 30,
                             id => 'date_'.$name } ).
                               $content;
}

1;
