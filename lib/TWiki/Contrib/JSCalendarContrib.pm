package TWiki::Contrib::JSCalendarContrib;

use vars qw( $VERSION );

use TWiki;

$VERSION = 0.961;

# Helper for plugins, to add the requisite bits of the calendar
# to the header
sub addHEAD {
    my $setup = shift;
    $setup ||= 'calendar-setup';
    my $style = $TWiki::cfg{JSCalendarContrib}{style} || 'system';
    my $lang = $TWiki::cfg{JSCalendarContrib}{lang} || 'en';
    my $base = '%PUBURL%/%TWIKIWEB%/JSCalendarContrib';
    my $head = <<HERE;
<style type='text/css' media='all'>
  \@import url('$base/calendar-$style.css');
</style>
<script type='text/javascript' src='$base/calendar.js'></script>
<script type='text/javascript' src='$base/lang/calendar-$lang.js'></script>
<script type='text/javascript' src='$base/$setup.js'></script>
HERE
    TWiki::Func::addToHEAD( 'JSCALENDAR_HEAD', $head );
}

1;
