# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2010-2011 Peter Thoeny, peter[at]thoeny.org
# Copyright (C) 2010-2011 TWiki Contributors. All Rights Reserved.
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

This package includes a small Perl module to make it easier to use the 
color picker from other TWiki plugins. This module includes the functions:

=cut

package TWiki::Plugins::ColorPickerPlugin;

use strict;

require TWiki::Func;    # The plugins API

# ==========================================================================
our $VERSION = '$Rev$';
our $RELEASE = '2012-08-11';
our $SHORTDESCRIPTION = "Color picker, packaged for use in TWiki forms and TWiki applications";
our $NO_PREFS_IN_TOPIC = 1;
our $doneHeader;
our $header = <<'HERE';
<script type="text/javascript" src="%PUBURLPATH%/%SYSTEMWEB%/ColorPickerPlugin/farbtastic.js"></script>
<link rel="stylesheet" href="%PUBURLPATH%/%SYSTEMWEB%/ColorPickerPlugin/farbtastic.css" type="text/css" media="all" />
HERE

# ==========================================================================
sub initPlugin {
  my( $topic, $web, $user, $installWeb ) = @_;

  $doneHeader = 0;

  TWiki::Func::registerTagHandler('COLORPICKER', \&handleColorPicker );

  return 1;
}

# ==========================================================================

=begin twiki

---+++ addHEAD

TWiki::Plugins::ColorPickerPlugin::addHEAD( )

=addHEAD= needs to be called before TWiki::Plugins::ColorPickerPlugin::renderForEdit
is called.

=cut

sub addHEAD {

  return if( $doneHeader );
  TWiki::Func::addToHEAD( 'COLORPICKERPLUGIN', $header );
}

# ==========================================================================
sub handleColorPicker  {
  my ( $session, $params ) = @_;

  my %options = %$params;
  my $name  = $params->{name};
  my $value = $params->{value};
  delete $options{name};
  delete $options{value};
  delete $options{_DEFAULT};
  delete $options{_RAW};

  return renderForEdit( $name, $value, \%options );
}


# ==========================================================================

=begin twiki

---+++ renderForEdit

TWiki::Plugins::ColorPickerPlugin::renderForEdit($name, $value, [, \%options]) -> $html

=cut

sub renderForEdit {
    my ( $name, $value, $options ) = @_;

    addHEAD();

    my $head = <<HERE;
 <script type="text/javascript" charset="utf-8">
  \$(document).ready(function() {
    \$('#picker$name').farbtastic('#id$name');
  });   
 </script>
HERE
    TWiki::Func::addToHEAD( 'COLORPICKERPLUGIN_' . $name, $head, 'COLORPICKERPLUGIN' );

    $options ||= {};
    $options->{name} = $name;
    $options->{id} = 'id'.$name;
    $options->{value} = $value || '#000000';
    $options->{size} ||= '8';

    my $text = CGI::textfield( $options ) . ' ';

# To-do: To conserve space, add popup when color button pressed 
#    $text .= CGI::image_button(
#               -name => 'img_'.$name,
#               -onclick =>
#                 "javascript: return showColorPicker( 'id$name' )",
#               -src=> TWiki::Func::getPubUrlPath() . '/' .
#                TWiki::Func::getTwikiWebname() .
#                  '/ColorPickerPlugin/colorpickericon.gif',
#               -alt => 'ColorPicker',
#               -align => 'middle');

    $text .= CGI::div( { -id => "picker$name" }, ' ' );

    return $text;
}

1;
