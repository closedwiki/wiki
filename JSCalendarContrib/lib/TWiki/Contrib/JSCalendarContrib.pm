=begin twiki

Read [[%ATTACHURL%/doc/html/reference.html][the Mishoo documentation]] or
[[%ATTACHURL%][visit the demo page]] for detailed information on using the
calendar widget.

This package also includes a small Perl module to make using the calendar
easier from TWiki plugins. This module includes the functions:

=cut

package TWiki::Contrib::JSCalendarContrib;

use strict;

require TWiki::Func;    # The plugins API

use vars qw( $VERSION $RELEASE $SHORTDESCRIPTION );

$VERSION = '$Rev$';
$RELEASE = 'TWiki-4';
$SHORTDESCRIPTION = "[[http://dynarch.com/mishoo/calendar.epl][Mishoo JSCalendar]], packaged for use by plugins, skins and add-ons";

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

=begin twiki

---+++ TWiki::Contrib::JSCalendarContrib::renderDateForEdit($name, $value, $format) -> $html

This is the simplest way to use calendars from a plugin.
   * =$name= is the name of the CGI parameter for the calendar
     (it should be unique),
   * =$value= is the current value of the parameter (may be undef)
   * =$format= is the format to use (optional; the default is set
     in =configure=). The
HTML returned will display a date field and a drop-down calendar.
Example:
<verbatim>
use TWiki::Contrib::JSCalendarContrib;
...
my $fromDate = TWiki::Contrib::JSCalendarContrib::renderDateForEdit(
   'from', '1 April 1999');
my $toDate = TWiki::Contrib::JSCalendarContrib::renderDateForEdit(
   'to', undef, '%Y');
</verbatim>

=cut

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
        -name => $name,
        -id => 'id_'.$name,
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

=begin twiki

---+++ TWiki::Contrib::JSCalendarContrib::addHEAD($setup)

This function will automatically add the headers for the calendar to the page
being rendered. It's intended for use when you want more control over the
formatting of your calendars than =renderDateForEdit= affords. =$setup= is
the name of
the calendar setup module; it can either be omitted, in which case the method
described in the Mishoo documentation can be used to create calendars, or it
can be ='twiki'=, in which case a Javascript helper function called
'showCalendar' is added that simplifies using calendars to set a value in a
text field. For example, say we wanted to display the date with the calendar
icon _before_ the text field, using the format =%Y %b %e=
<verbatim>
# Add styles and javascript for the calendar
use TWiki::Contrib::JSCalendarContrib;
...

sub commonTagsHandler {
  ....
  # Enable 'showCalendar'
  TWiki::Contrib::JSCalendarContrib::addHEAD( 'twiki' );

  my $cal = CGI::image_button(
      -name => 'img_datefield',
      -onclick =>
       "return showCalendar('id_datefield','%Y %b %e')",
      -src=> TWiki::Func::getPubUrlPath() . '/' .
             TWiki::Func::getTwikiWebname() .
             '/JSCalendarContrib/img.gif',
      -alt => 'Calendar',
      -align => 'MIDDLE' )
    . CGI::textfield(
      { name => 'date', id => "id_datefield" });
  ....
}
</verbatim>
The first parameter to =showCalendar= is the id of the textfield, and the second parameter is the . See the Mishoo documentation for details of the '$e %B %Y' parameter.

=addHEAD= can be called from =commonTagsHandler= for adding the header to all pages, or from =beforeEditHandler= just for edit pages etc.

=cut

sub addHEAD {
    my $setup = shift;
    $setup ||= 'calendar-setup';
    my $style = $TWiki::cfg{JSCalendarContrib}{style} || 'blue';
    my $lang = $TWiki::cfg{JSCalendarContrib}{lang} || 'en';
    my $base = '%PUBURLPATH%/%SYSTEMWEB%/JSCalendarContrib';
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
    TWiki::Func::addToHEAD( 'JSCALENDAR_HEAD_'.$setup, $head );
}

1;
