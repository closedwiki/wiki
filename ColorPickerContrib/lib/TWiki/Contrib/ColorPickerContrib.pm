# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2010 Peter Thoeny, peter[at]thoeny.org
# Copyright (C) 2010 TWiki Contributors. All Rights Reserved.
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

TBD

=cut

package TWiki::Contrib::ColorPickerContrib;

use strict;

require TWiki::Func;    # The plugins API

use vars qw( $VERSION $RELEASE $SHORTDESCRIPTION );

$VERSION = '$Rev$';
$RELEASE = '2010-11-26';
$SHORTDESCRIPTION = "Color picker, packaged for use in TWiki forms and TWiki applications";

=begin twiki

---+++ renderForEdit

TWiki::Contrib::ColorPickerContrib::renderForEdit($name, $value, [, \%options]) -> $html

This is the simplest way to use the color picker from a plugin.

   * =$name= is the name of the CGI parameter for the calendar
     (it should be unique),
   * =$value= is the color such as '#8899aa' (may be empty)
   * =\%options= is an optional hash containing base options for
     the textfield.
Example:
<verbatim>
use TWiki::Contrib::ColorPickerContrib;
my $html = "<form>\n";
$html .= TWiki::Contrib::ColorPickerContrib::renderForEdit( 'webcolor'i, $value );
...
</verbatim>

=cut

sub renderForEdit {
    my ( $name, $value, $options ) = @_;

    addHEAD('twiki');

    my $head = <<HERE;
 <script type="text/javascript" charset="utf-8">
  \$(document).ready(function() {
    \$('#picker$name').farbtastic('#id$name');
  });   
 </script>
HERE
    TWiki::Func::addToHEAD( 'COLORPICKERCONTRIB_'.$name, $head );

    $options ||= {};
    $options->{name} = $name;
    $options->{id} = 'id'.$name;
    $options->{value} = $value || '#000000';
    $options->{size} ||= '8';

    my $text = CGI::textfield( $options );

# To-do: To conserve space, add popup when color button pressed 
#    $text .= CGI::image_button(
#               -name => 'img_'.$name,
#               -onclick =>
#                 "javascript: return showColorPicker( 'id$name' )",
#               -src=> TWiki::Func::getPubUrlPath() . '/' .
#                TWiki::Func::getTwikiWebname() .
#                  '/ColorPickerContrib/colorpickericon.gif',
#               -alt => 'ColorPicker',
#               -align => 'middle');

    $text .= CGI::div( { -id => "picker$name" } );

    return $text;
}

=begin twiki

---+++ addHEAD

TWiki::Contrib::ColorPickerContrib::addHEAD( )

=addHEAD= can be called from =commonTagsHandler= for adding the header to 
all pages, or from =beforeEditHandler= just for edit pages.

=cut

sub addHEAD {
    my $style = $TWiki::cfg{JSCalendarContrib}{style} || 'blue';
    my $lang = $TWiki::cfg{JSCalendarContrib}{lang} || 'en';
    my $base = '%PUBURLPATH%/%SYSTEMWEB%/ColorPickerContrib';
    my $head = <<HERE;
<script type="text/javascript" src="$base/farbtastic.js"></script>
<link rel="stylesheet" href="$base/farbtastic.css" type="text/css" />
HERE
    TWiki::Func::addToHEAD( 'COLORPICKERCONTRIB', $head );
}

1;
