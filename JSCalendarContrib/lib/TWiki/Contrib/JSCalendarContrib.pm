package TWiki::Contrib::JSCalendarContrib;

use vars qw( $VERSION $RELEASE );

use TWiki;

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';


# Helper for plugins, to add the requisite bits of the calendar
# to the header
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

sub renderFormFieldForEditHandler {
  my ( $name, $type, $size, $value, $attributes, $possibleValues ) = @_;
  return unless ( $type eq 'date' );
  my $ifFormat = ''; # Need to get the format from somewhere...
  $ifFormat ||= '%e %b %Y';
  $size = 10 if( !$size || $size < 1 );
  $value = TWiki::Plugins::EditTablePlugin::encodeValue( $value ) unless( $theValue eq '' );
  my $text .= CGI::textfield(
            { name => $name,
              id => 'id'.$name,
              size=> $size,
              value => $value });
  require TWiki::Contrib::JSCalendarContrib;
  unless ( $@ ) {
    addHEAD( 'twiki' );
    $text .= CGI::image_button(
                -name => 'calendar',
                -onclick =>
                  "return showCalendar('id$name','$ifFormat')",
                -src=> TWiki::Func::getPubUrlPath() . '/' .
                  TWiki::Func::getTwikiWebname() .
                      '/JSCalendarContrib/img.gif',
                -alt => 'Calendar',
                -align => 'MIDDLE' );
  }
  return $text;
  
}

1;
