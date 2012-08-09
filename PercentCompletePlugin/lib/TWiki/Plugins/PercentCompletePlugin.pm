# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2012 Peter Thoeny, peter[at]thoeny.org
# Copyright (C) 2012 TWiki Contributors. All Rights Reserved.
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

=begin twiki

This package adds a percent complete selector to TWiki forms. 
It includes the functions:

=cut

package TWiki::Plugins::PercentCompletePlugin;

use strict;

require TWiki::Func;    # The plugins API

# ========================================================
our $VERSION = '$Rev$';
our $RELEASE = '2011-08-09';
our $SHORTDESCRIPTION = "Percent complete selector, for use in TWiki forms and TWiki applications";
our $NO_PREFS_IN_TOPIC = 1;

# ========================================================
sub initPlugin {
  my( $topic, $web, $user, $installWeb ) = @_;

  TWiki::Func::registerTagHandler('PERCENTCOMPLETE', \&handlePercentComplete );

  return 1;
}

# ========================================================
sub handlePercentComplete  {
  my ( $session, $params ) = @_;

  my $name  = $params->{name};
  my $value = $params->{value};

  return renderForEdit( $name, $value );
}

# ========================================================
sub renderForDisplay {
    my ( $value ) = @_;

    my $text = '<span style="white-space: nowrap">'
      . '<img src="%PUBURL%/%SYSTEMWEB%/PercentCompletePlugin/complete'
      . "$value.png\" width=\"100\" height=\"16\" alt=\"\" title=\"$value%\" />"
      . " $value% </span>";

    return $text;
}

# ========================================================
sub renderForEdit {
    my ( $name, $value ) = @_;

    # TODO: Make it possible to use more than one percent complete selector per page.

    my $text = '<span style="white-space: nowrap">'
      . '<img src="%PUBURL%/%SYSTEMWEB%/PercentCompletePlugin/complete'
      . $value
      . '.png" width="100" height="16" alt="" id="percentCompleteImg" '
      . 'title="Click to change the percentage" /> '
      . '<select name="' . $name . '" id="percentCompleteSelect" class="twikiSelect"> '
      . '%CALCULATE{$LISTJOIN($sp, $LISTMAP(<option $IF($EXACT('
      . $value
      . ',$item), selected="selected") value="$item">$item%</option> , '
      . '0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100))}% </select> '
      . '</span> '
      . '<script type="text/javascript"> function setPercentComplete(percent) { '
      . '$("#percentCompleteSelect").val(percent); $("#percentCompleteImg").'
      . 'attr("src", "%PUBURL%/%SYSTEMWEB%/PercentCompletePlugin/complete"+percent+".png"); }'
      . '$("#percentCompleteImg").click(function(e){ var xPos = e.pageX - '
      . '$("#percentCompleteImg").offset().left; if(xPos<5) { xPos=0 } else { '
      . 'xPos=10*Math.round((xPos+5)/10) }; setPercentComplete(xPos); }); '
      . '$("#percentCompleteSelect").change(function() { '
      . 'setPercentComplete($("#percentCompleteSelect").val()) }); </script>';

    return $text;
}

# ========================================================
1;
