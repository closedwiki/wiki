package TWiki::Contrib::JSCalendarContrib;

use strict;

use vars qw( $VERSION $RELEASE );

$VERSION = '$Rev$';
$RELEASE = 'TWiki-4';

# See JSCalendarContrib.txt for pod
sub addHEAD {
    my $setup = shift;
    $setup ||= 'calendar-setup';
    my $style = $TWiki::cfg{JSCalendarContrib}{style} || 'blue';
    my $lang = $TWiki::cfg{JSCalendarContrib}{lang} || 'en';
    my $base = '%PUBURLPATH%/%TWIKIWEB%/JSCalendarContrib';
    my $head = <<HERE;
<style type='text/css' media='all'>
  \@import url('$base/calendar-$style.css');
  .calendar {z-index:2000;}
</style>
<script type='text/javascript' src='$base/calendar.js'></script>
<script type='text/javascript' src='$base/lang/calendar-$lang.js'></script>
HERE
    TWiki::Func::addToHEAD( 'JSCALENDAR_HEAD', $head );

    # Add the setup separately; there might be different setups required
    # in a single HTML page.
    $head = <<HERE;
<script type='text/javascript' src='$base/$setup.js'></script>
HERE
    TWiki::Func::addToHEAD( 'JSCALENDAR_HEAD'.$setup, $head );
}

# Max width of different mishoo format components
my %w = (
    a => 3,	# abbreviated weekday name
    A => 9,	# full weekday name
    b => 3,	# abbreviated month name
    B => 9,	# full month name
    C => 2,	# century number
    d => 2,	# the day of the month ( 00 .. 31 )
    e => 2,	# the day of the month ( 0 .. 31 )
    H => 2,	# hour ( 00 .. 23 )
    I => 2,	# hour ( 01 .. 12 )
    j => 3,	# day of the year ( 000 .. 366 )
    k => 2,	# hour ( 0 .. 23 )
    l => 2,	# hour ( 1 .. 12 )
    m => 2,	# month ( 01 .. 12 )
    M => 2,	# minute ( 00 .. 59 )
    n => 1,	# a newline character
    p => 2,	# ``PM'' or ``AM''
    P => 2,	# ``pm'' or ``am''
    S => 2,	# second ( 00 .. 59 )
    s => 12,# number of seconds since Epoch
    t => 1,	# a tab character
    U => 2,	# the week number
    u => 1,	# the day of the week ( 1 .. 7, 1 = MON )
    W => 2,	# the week number
    w => 1,	# the day of the week ( 0 .. 6, 0 = SUN )
    V => 2,	# the week number
    y => 2,	# year without the century ( 00 .. 99 )
    Y => 4,	# year including the century ( ex. 1979 )
);

# See JSCalendarContrib.txt for pod
sub renderDateForEdit {
    my ($name, $value, $format) = @_;

    $format ||= $TWiki::cfg{JSCalendarContrib}{format} || '%e %B %Y';

    addHEAD('twiki');

    # Work out how wide it has to be from the format
    # SMELL: add a space because pattern skin default fonts on FF make the
    # box half a character too narrow if the exact size is used
    my $wide = $format.' ';
    $wide =~ s/(%(.))/$w{$2} ? ('_' x $w{$2}) : $1/ge;

    return CGI::textfield(
        -name => $name, -id => 'id_'.$name,
        -size => length($wide),
        -default => $value || '')
      . CGI::image_button(
          -name => 'img_'.$name,
          -onclick =>
            "javascript: return showCalendar('id_$name','$format')",
            -src=> TWiki::Func::getPubUrlPath() . '/' .
              TWiki::Func::getTwikiWebname() .
                  '/JSCalendarContrib/img.gif',
          -alt => 'Calendar',
          -align => 'MIDDLE');
}

1;
