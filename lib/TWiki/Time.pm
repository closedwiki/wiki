# TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 1999-2005 Peter Thoeny, peter@thoeny.com
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
# Copyright (C) 2002 John Talintyre, john.talintyre@btinternet.com
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
# As per the GPL, removal of this notice is prohibited.

=pod

---+ package TWiki::Time

Time handling functions.

=cut

package TWiki::Time;

use Time::Local;
use TWiki;

# Constants
use vars qw( @ISOMONTH @WEEKDAY %MON2NUM );

@ISOMONTH =
  ( "Jan", "Feb", "Mar", "Apr", "May", "Jun",
    "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" );

@WEEKDAY =
  ( "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun" );

%MON2NUM =
  (
   Jan => 0,
   Feb => 1,
   Mar => 2,
   Apr => 3,
   May => 4,
   Jun => 5,
   Jul => 6,
   Aug => 7,
   Sep => 8,
   Oct => 9,
   Nov => 10,
   Dec => 11
  );

=pod

---++ StaticMethod parseTime( $szDate ) -> $iSecs

Convert string date/time to seconds since epoch.
   * =$sDate= - date/time string

Handles the following formats:
   * 31 Dec 2001 - 23:59
   * 2001/12/31 23:59:59
   * 2001.12.31.23.59.59
   * 2001/12/31 23:59
   * 2001.12.31.23.59
   * 2001-12-31T23:59:59Z
   * 2001-12-31T23:59:59+01:00
   * 2001-12-31T23:59Z
   * 2001-12-31T23:59+01:00

If the date format was not recognised, will return 0.

=cut

# previously known as revDate2EpSecs

sub parseTime {
    my( $date ) = @_;
    # NOTE: This routine *will break* if input is not one of below formats!
    
    # FIXME - why aren't ifs around pattern match rather than $5 etc
    # try "31 Dec 2001 - 23:59"  (TWiki date)
    if ($date =~ /([0-9]+)\s+([A-Za-z]+)\s+([0-9]+)[\s\-]+([0-9]+)\:([0-9]+)/) {
        my $year = $3;
        $year -= 1900 if( $year > 1900 );
        # The ($2) will look up the constant so named
        return timegm( 0, $5, $4, $1, $MON2NUM{$2}, $year );
    }

    # try "2001/12/31 23:59:59" or "2001.12.31.23.59.59" (RCS date)
    if ($date =~ /([0-9]+)[\.\/\-]([0-9]+)[\.\/\-]([0-9]+)[\.\s\-]+([0-9]+)[\.\:]([0-9]+)[\.\:]([0-9]+)/) {
        my $year = $1;
        $year -= 1900 if( $year > 1900 );
        return timegm( $6, $5, $4, $3, $2-1, $year );
    }

    # try "2001/12/31 23:59" or "2001.12.31.23.59" (RCS short date)
    if ($date =~ /([0-9]+)[\.\/\-]([0-9]+)[\.\/\-]([0-9]+)[\.\s\-]+([0-9]+)[\.\:]([0-9]+)/) {
        my $year = $1;
        $year -= 1900 if( $year > 1900 );
        return timegm( 0, $5, $4, $3, $2-1, $year );
    }

    # try "2001-12-31T23:59:59Z" or "2001-12-31T23:59:59+01:00" (ISO date)
    # FIXME: Calc local to zulu time "2001-12-31T23:59:59+01:00"
    if ($date =~ /([0-9]+)\-([0-9]+)\-([0-9]+)T([0-9]+)\:([0-9]+)\:([0-9]+)/ ) {
        my $year = $1;
        $year -= 1900 if( $year > 1900 );
        return timegm( $6, $5, $4, $3, $2-1, $year );
    }

    # try "2001-12-31T23:59Z" or "2001-12-31T23:59+01:00" (ISO short date)
    # FIXME: Calc local to zulu time "2001-12-31T23:59+01:00"
    if ($date =~ /([0-9]+)\-([0-9]+)\-([0-9]+)T([0-9]+)\:([0-9]+)/ ) {
        my $year = $1;
        $year -= 1900 if( $year > 1900 );
        return timegm( 0, $5, $4, $3, $2-1, $year );
    }

    # give up, return start of epoch (01 Jan 1970 GMT)
    return 0;
}

=pod

---++ StaticMethod formatTime ($epochSeconds, $formatString, $outputTimeZone) -> $value
   * =$epochSeconds= epochSecs GMT
   * =$formatString= twiki time date format
   * =$outputTimeZone= timezone to display ("gmtime" or "servertime", default "gmtime")
=$formatString= supports:
   | $seconds | secs |
   | $minutes | mins |
   | $hours | hours |
   | $day | date |
   | $wday | weekday name |
   | $dow | day number (0 = Sunday) |
   | $week | week number |
   | $month | month name |
   | $mo | month number |
   | $year | 4-digit year |
   | $ye | 2-digit year |

=cut

# previous known as TWiki::formatTime

sub formatTime  {
    my ($epochSeconds, $formatString, $outputTimeZone) = @_;
    my $value = $epochSeconds;

    # use default TWiki format "31 Dec 1999 - 23:59" unless specified
    $formatString = "\$day \$month \$year - \$hour:\$min"
      unless( $formatString );
    $outputTimeZone = $TWiki::cfg{DisplayTimeValues}
      unless( $outputTimeZone );

    my( $sec, $min, $hour, $day, $mon, $year, $wday);
    if( $outputTimeZone eq "servertime" ) {
        ( $sec, $min, $hour, $day, $mon, $year, $wday ) =
          localtime( $epochSeconds );
    } else {
        ( $sec, $min, $hour, $day, $mon, $year, $wday ) =
          gmtime( $epochSeconds );
    }

    #standard twiki date time formats
    if( $formatString =~ /rcs/i ) {
        # RCS format, example: "2001/12/31 23:59:59"
        $formatString = "\$year/\$mo/\$day \$hour:\$min:\$sec";
    } elsif ( $formatString =~ /http|email/i ) {
        # HTTP header format, e.g. "Thu, 23 Jul 1998 07:21:56 EST"
 	    # - based on RFC 2616/1123 and HTTP::Date; also used
        # by TWiki::Net for Date header in emails.
        $formatString = "\$wday, \$day \$month \$year \$hour:\$min:\$sec \$tz";
    } elsif ( $formatString =~ /iso/i ) {
        # ISO Format, see spec at http://www.w3.org/TR/NOTE-datetime
        # e.g. "2002-12-31T19:30Z"
        $formatString = "\$year-\$mo-\$dayT\$hour:\$min";
        if( $outputTimeZone eq "gmtime" ) {
            $formatString = $formatString."Z";
        } else {
            #TODO:            $formatString = $formatString.  # TZD  = time zone designator (Z or +hh:mm or -hh:mm) 
        }
    }

    $value = $formatString;
    $value =~ s/\$seco?n?d?s?/sprintf("%.2u",$sec)/gei;
    $value =~ s/\$minu?t?e?s?/sprintf("%.2u",$min)/gei;
    $value =~ s/\$hour?s?/sprintf("%.2u",$hour)/gei;
    $value =~ s/\$day/sprintf("%.2u",$day)/gei;
    $value =~ s/\$wday/$WEEKDAY[$wday]/gi;
    $value =~ s/\$dow/$wday/gi;
    $value =~ s/\$week/_weekNumber($day,$mon,$year,$wday)/egi;
    $value =~ s/\$mont?h?/$ISOMONTH[$mon]/gi;
    $value =~ s/\$mo/sprintf("%.2u",$mon+1)/gei;
    $value =~ s/\$year?/sprintf("%.4u",$year+1900)/gei;
    $value =~ s/\$ye/sprintf("%.2u",$year%100)/gei;

    # SMELL: how do we get the different timezone strings (and when
    # we add usertime, then what?)
    my $tz_str = ( $outputTimeZone eq "servertime" ) ? "Local" : "GMT";
    $value =~ s/\$tz/$tz_str/geoi;

    return $value;
}

sub _weekNumber {
    my( $day, $mon, $year, $wday ) = @_;

    # calculate the calendar week (ISO 8601)
    my $nextThursday = timegm(0, 0, 0, $day, $mon, $year) +
      (3 - ($wday + 6) % 7) * 24 * 60 * 60; # nearest thursday
    my $firstFourth = timegm(0, 0, 0, 4, 0, $year); # january, 4th
    return sprintf("%.0f", ($nextThursday - $firstFourth) / ( 7 * 86400 )) + 1;
}

1;
