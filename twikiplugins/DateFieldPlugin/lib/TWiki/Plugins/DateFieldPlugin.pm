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

use vars qw( $VERSION );

$VERSION = 1.000;

sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;

    # make sure JSCalendar is there
    eval 'use TWiki::Contrib::JSCalendarContrib';
    if ( $@ ) {
        my $mess = "WARNING: JSCalendar not installed: $@";
        print STDERR "$mess\n";
        TWiki::Func::writeWarning( $mess );
        return 0;
    } elsif( $TWiki::Contrib::JSCalendarContrib::VERSION < 0.961 ) {
        TWiki::Func::writeWarning(
            'JSCalendarContrib >=0.961 required, '.
              $TWiki::Contrib::JSCalendarContrib::VERSION.' found');
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

    return unless $type eq "date";

    my $content =
      CGI::image_button(
          -name => 'calendar',
          -onclick =>
            "return showCalendar('date_$name','%e %B %Y')",
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
