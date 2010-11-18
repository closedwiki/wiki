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
#
# This packages subclasses TWiki::Form::FieldDefinition to implement
# the =color= type

package TWiki::Form::Color;
use base 'TWiki::Form::FieldDefinition';

use strict;

use TWiki::Contrib::ColorPickerContrib;

# ========================================================
sub new {
    my $class = shift;
    my $this = $class->SUPER::new( @_ );
    my $size = $this->{size} || '0';
    $size =~ s/[^\d]//g;
    $size = 8 if( !$size || $size < 1 );
    $this->{size} = $size;
    return $this;
}

sub renderForEdit {
    my( $this, $web, $topic, $value ) = @_;

    my $head = <<HERE;
 <script type="text/javascript" charset="utf-8">
  \$(document).ready(function() {
    \$('#picker$this->{name}').farbtastic('#id$this->{name}');
  });   
 </script>
HERE
    TWiki::Func::addToHEAD( 'COLORPICKERCONTRIB_'.$this->{name}, $head );

    $value = CGI::textfield(
        { name => $this->{name},
          id => 'id'.$this->{name},
          size=> $this->{size},
          value => $value,
          class => $this->can('cssClasses') ?
            $this->cssClasses('twikiInputField', 'twikiEditFormColorField') :
              'twikiInputField twikiEditFormColorField'});
    TWiki::Contrib::ColorPickerContrib::addHEAD( 'twiki' );

# To-do: To conserve space, add popup when color button pressed 
    my $button = '';
#    my $button .= CGI::image_button(
#        -name  => "img$this->{name}",
#        -src   => $TWiki::cfg{PubUrlPath} . '/'
#                . $TWiki::cfg{SystemWebName}
#                . '/ColorPickerContrib/color_bg.gif',
#        -alt   => 'ColorPicker',
#        -align => 'middle',
#        -class => 'twikiButton twikiEditFormColorButton' );
my $button = '';
    $value .= CGI::span(
        { -class => 'twikiMakeVisible' },
        '&nbsp;' . $button
    );
    $value .= CGI::div( { -id => "picker$this->{name}" } );

    my $session = $this->{session};
    $value = $session->renderer->getRenderedVersion(
        $session->handleCommonTags( $value, $web, $topic ));

    return ( '', $value );
}

sub renderForDisplay {
    my ( $this, $format, $value, $attrs ) = @_;

    my $text = "<span style=\"background-color:$value\">"
             . '<img src="%ICONURLPATH{blank-bg}%" alt="" width="16" height="16" /></span>'
             . " $value";
    $format =~ s/\$value/$text/g;

    return $this->SUPER::renderForDisplay( $format, $value, $attrs );
}

1;
