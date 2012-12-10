# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2004-2012 Peter Thoeny, peter[at]thoeny.org
# Copyright (C) 2004-2012 TWiki Contributors. All Rights Reserved.
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
# As per the GPL, removal of this notice is prohibited.
#
# This plugin is based on the work of TWiki:Plugins.JSCalendarContrib.

=begin twiki

Read [[%ATTACHURL%/doc/html/reference.html][the Mishoo documentation]] or
[[%ATTACHURL%/index.html][visit the demo page]] for detailed information 
on using the calendar widget.

This plugin includes the following function to make using the calendar
easier from other TWiki plugins:

=cut

package TWiki::Plugins::DatePickerPlugin;

use strict;

require TWiki::Func;    # The plugins API

# ========================================================
our $VERSION = '$Rev$';
our $RELEASE = '2012-12-10';
our $SHORTDESCRIPTION = "Pop-up calendar with date picker, for use in TWiki forms, HTML forms and TWiki plugins";
our $NO_PREFS_IN_TOPIC = 1;

# Max width of different mishoo format components
my %w = (
    a => 3,     # abbreviated weekday name
    A => 9,     # full weekday name
    b => 3,     # abbreviated month name
    B => 9,     # full month name
    C => 2,     # century number
    d => 2,     # the day of the month ( 00 .. 31 )
    e => 2,     # the day of the month ( 0 .. 31 )
    H => 2,     # hour ( 00 .. 23 )
    I => 2,     # hour ( 01 .. 12 )
    j => 3,     # day of the year ( 000 .. 366 )
    k => 2,     # hour ( 0 .. 23 )
    l => 2,     # hour ( 1 .. 12 )
    m => 2,     # month ( 01 .. 12 )
    M => 2,     # minute ( 00 .. 59 )
    n => 1,     # a newline character
    p => 2,     # ``PM'' or ``AM''
    P => 2,     # ``pm'' or ``am''
    S => 2,     # second ( 00 .. 59 )
    s => 12,    # number of seconds since Epoch
    t => 1,     # a tab character
    U => 2,     # the week number
    u => 1,     # the day of the week ( 1 .. 7, 1 = MON )
    W => 2,     # the week number
    w => 1,     # the day of the week ( 0 .. 6, 0 = SUN )
    V => 2,     # the week number
    y => 2,     # year without the century ( 00 .. 99 )
    Y => 4,     # year including the century ( ex. 1979 )
);

my $headerDone;

# ========================================================
sub initPlugin {
  my( $topic, $web, $user, $installWeb ) = @_;

  TWiki::Func::registerTagHandler('DATEPICKER', \&handleDATEPICKER );
  $headerDone = 0;

  return 1;
}

# ========================================================
sub handleDATEPICKER  {
  my ( $session, $params ) = @_;

  my $name   = $params->{name};
  my $value  = $params->{value};
  my $format = $params->{format};
  # FIXME: size, class, and more
  return renderForEdit( $name, $value, $format );
}

=begin twiki

---+++ renderForEdit

TWiki::Plugins::DatePickerPlugin::renderForEdit($name, $value, $format [, \%options]) -> $html

This is the simplest way to use calendars from a plugin.
   * =$name= is the name of the CGI parameter for the calendar
     (it should be unique),
   * =$value= is the current value of the parameter (may be undef)
   * =$format= is the format to use (optional; the default is set
     in =configure=). The HTML returned will display a date field
     and a drop-down calendar.
   * =\%options= is an optional hash containing base options for
     the textfield.

__Note:__ No output is shown if =$name= is empty or undef, but the 
CSS and Javascript are loaded.

Example:
<verbatim>
use TWiki::Plugins::DatePickerPlugin;
...
my $fromDate = TWiki::Plugins::DatePickerPlugin::renderForEdit(
   'from', '2012-12-31');
my $toDate = TWiki::Plugins::DatePickerPlugin::renderForEdit(
   'to', undef, '%Y');
</verbatim>

=cut

# ========================================================
sub renderForEdit {
    my ( $name, $value, $format, $options ) = @_;

    $format ||= $TWiki::cfg{Plugins}{DatePickerPlugin}{Format} || '%Y-%m-%d';

    addToHEAD( 'twiki' );

    # return after adding the css & js if no name
    return '' unless( $name );

    # Work out how wide it has to be from the format
    # SMELL: add a space because pattern skin default fonts on FF make the
    # box half a character too narrow if the exact size is used
    my $wide = $format.' ';
    $wide =~ s/(%(.))/$w{$2} ? ('_' x $w{$2}) : $1/ge;
    $options ||= {};
    $options->{name} = $name;
    $options->{id} = 'id_'.$name;
    $options->{value} = $value || '';
    $options->{size} ||= length($wide);
    $options->{class} ||= 'twikiInputField';

    my $text = CGI::textfield($options)
      . CGI::image_button(
          -name => 'img_'.$name,
          -onclick =>
            "javascript: return showCalendar('id_$name','$format')",
            -src=> TWiki::Func::getPubUrlPath() . '/' .
              TWiki::Func::getTwikiWebname() .
                  '/DatePickerPlugin/img.gif',
          -alt => 'Calendar',
          -align => 'middle');

    return $text;
}

# ========================================================
sub addToHEAD {
    my $setup = shift;
    $setup ||= 'calendar-setup';

    return if( $headerDone );
    $headerDone = 1;

    my $style = $TWiki::cfg{Plugins}{DatePickerPlugin}{Style} || 'blue';
    my $lang = $TWiki::cfg{Plugins}{DatePickerPlugin}{Lang} || 'en';
    my $base = '%PUBURLPATH%/%SYSTEMWEB%/DatePickerPlugin';
    my $head = <<HERE;
<style type='text/css' media='all'>
  \@import url('$base/calendar-$style.css');
  .calendar {z-index:2000;}
</style>
<script type='text/javascript' src='$base/calendar.js'></script>
<script type='text/javascript' src='$base/lang/calendar-$lang.js'></script>
HERE
    TWiki::Func::addToHEAD( 'DATEPICKERPLUGIN', $head );

    # Add the setup separately; there might be different setups required
    # in a single HTML page.
    $head = <<HERE;
<script type='text/javascript' src='$base/$setup.js'></script>
HERE
    TWiki::Func::addToHEAD( 'DATEPICKERPLUGIN_'.$setup, $head );
}

# ========================================================
1;
