# See bottom of file for license and copyright details
package TWiki::Form::Select;
use base 'TWiki::Form::ListFieldDefinition';

use strict;

sub new {
    my $class = shift;
    my $this = $class->SUPER::new( @_ );

    # Parse the size to get min and max
    $this->{size} ||= 1;
    if( $this->{size} =~ /^\s*(\d+)\.\.(\d+)\s*$/ ) {
        $this->{minSize} = $1;
        $this->{maxSize} = $2;
    } else {
        $this->{minSize} = $this->{size};
        $this->{minSize} =~ s/[^\d]//g;
        $this->{minSize} ||= 1;
        $this->{maxSize} = $this->{minSize};
    }

    return $this;
}

=begin twiki

---++ ObjectMethod finish()
Break circular references.

=cut

# Note to developers; please undef *all* fields in the object explicitly,
# whether they are references or not. That way this method is "golden
# documentation" of the live fields in the object.
sub finish {
    my $this = shift;
    $this->SUPER::finish();
    undef $this->{minSize};
    undef $this->{maxSize};
}

sub isMultiValued { return shift->{type} =~ /\+multi/; }

sub renderForEdit {
    my( $this, $web, $topic, $value ) = @_;

    my $choices = '';
    foreach my $option ( @{$this->getOptions()} ) {
        $option = TWiki::urlDecode($option);
        my %params = (
            class => 'twikiEditFormOption'
           );
        my $optionValue = $option;
        if( $this->{type} =~ /\+values/ ) {
            if( $option =~ /^(.*?[^\\])=(.*)$/ ) {
                $option = $1;
                $optionValue = $2;
                $params{value} = $optionValue;
            }
            $option =~ s/\\=/=/g;
        }
        if( defined $optionValue && defined $value ) {
            my $selected;
            if( $this->isMultiValued() ) {
                $selected = ( $value =~ /(^|,)?\s*$optionValue\s*(,|$)/ );
            } else {
                $selected = ( $optionValue eq $value );
            }
            $params{selected} = 'selected' if $selected;
        }
        $option =~ s/<nop/&lt\;nop/go;
        $choices .= CGI::option( \%params, $option );
    }
    my $size = scalar( @{$this->getOptions()} );
    if( $size > $this->{maxSize} ) {
        $size = $this->{maxSize};
    } elsif( $size < $this->{minSize} ) {
        $size = $this->{minSize};
    }
    my $params = {
        class => $this->cssClasses('twikiSelect', 'twikiEditFormSelect'),
        name => $this->{name},
        size => $this->{size},
    };
    if( $this->isMultiValued() ) {
        $params->{'multiple'}='on';
        $value  = CGI::Select( $params, $choices );
        # Item2410: We need a dummy control to detect the case where
        #           all checkboxes have been deliberately unchecked
        # Item3061:
        # Don't use CGI, it will insert the value from the query
        # once again and we need an empt field here.
        $value .= '<input type="hidden" name="'.$this->{name}.'" value="" />';
    }
    else {
        $value  = CGI::Select( $params, $choices );
    }
    return ( '', $value );
}

1;
__DATA__

Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/

Copyright (C) 2001-2007 TWiki Contributors. All Rights Reserved.
TWiki Contributors are listed in the AUTHORS file in the root of
this distribution. NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.

