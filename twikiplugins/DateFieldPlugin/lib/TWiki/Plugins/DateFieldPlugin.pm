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

use vars qw( $VERSION $calendarIncludes $topic $web $user $installWeb );

$VERSION = 1.000;

sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    return 1;
}

sub commonTagsHandler {
    return unless( $_[0] =~ /<!-- INCLUDEJSCALENDAR -->/ );

    unless( $calendarIncludes) {
        eval 'use TWiki::Contrib::JSCalendarContrib';
        if ( $@ ) {
            $calendarIncludes = "";
        } else {
            $calendarIncludes =
"<link type=\"text/css\" rel=\"stylesheet\" href=\"%PUBURL%/%TWIKIWEB%/JSCalendarContrib/calendar-%DATEFIELDPLUGIN_CAL_STYLE%.css\" />
 <base href=\"%SCRIPTURL%/view%SCRIPTSUFFIX%/%WEB%/%TOPIC%\" />
<script type=\"text/javascript\" src=\"%PUBURL%/%TWIKIWEB%/JSCalendarContrib/calendar.js\"></script>
<script type=\"text/javascript\" src=\"%PUBURL%/%TWIKIWEB%/JSCalendarContrib/lang/calendar-%DATEFIELDPLUGIN_CAL_LANG%.js\"></script>
<script type=\"text/javascript\" src=\"%PUBURL%/%TWIKIWEB%/JSCalendarContrib/twiki.js\"></script>";
            $calendarIncludes =
              TWiki::Func::expandCommonVariables( $calendarIncludes, $topic, $web );
        }
    }
    $_[0] =~ s/<!-- INCLUDEJSCALENDAR -->/$calendarIncludes/;
}

sub renderFormFieldForEditHandler {
    my ( $name, $type, $size, $value, $attributes, $possibleValues ) = @_;

    return unless $type eq "date";

    # make sure JSCalendar is there
    eval 'use TWiki::Contrib::JSCalendarContrib';
    if ( $@ ) {
        my $mess = "WARNING: JSCalendar not installed: $@";
        print STDERR "$mess\n";
        TWiki::Func::writeWarning( $mess );
        # try and force use of "text"
        $_[1] = "text";
        $_[2] = 16;
        return "";
    }
    return "<input type=\"text\" class=\"twikiEditFormTextField\" readonly=\"readonly\" "
      . "name=\"$name\" value=\"$value\" id=\"date_$name\"/>"
        . "<button type=\"reset\" onclick=\"return showCalendar('date_$name',"
          . "'\%e \%B \%Y')\"><img src=\""
            . TWiki::Func::getPubUrlPath() . "/"
              . TWiki::Func::getTwikiWebname()
                . "/JSCalendarContrib/img.gif\" alt=\"Calendar\"/></button>";
}

1;
