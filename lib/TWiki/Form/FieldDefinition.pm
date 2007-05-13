# See bottom of file for license and copyright details
# base class for all form field types
package TWiki::Form::FieldDefinition;

use strict;
use Assert;

sub new {
    my $class = shift;
    my %attrs = @_;

    $attrs{name} ||= '';
    $attrs{attributes} ||= '';
    $attrs{type} ||= ''; # default

    return bless(\%attrs, $class);
}

# is the field type editable?
sub isEditable { 1 }
# is it multi-valued (i.e. does it store multiple values)?
sub isMultiValued { 0 }

sub isMandatory { return shift->{attributes} =~ /M/ }

sub renderForEdit {
    my( $this, $web, $topic, $value ) = @_;
ASSERT(0);

    # Treat like text, make it reasonably long, add a warning
    return ( '<br /><span class="twikiAlert">MISSING TYPE '.$this->{type}.'</span>',
            CGI::textfield( -class => 'twikiEditFormError',
                            -name => $this->{name},
                            -size => 80,
                            -value => $value ));
}

# Try and get a sensible default value from the values stored in the form
# definition.
sub getDefaultValue {
    my $this = shift;

    my $value = $this->{value};
    $value = '' unless defined $value;  # allow 0 values

    return $value;
}

sub renderHidden {
    my( $this, $meta ) = @_;

    my $value;
    if( $this->{name} ) {
        my $field = $meta->get( 'FIELD', $this->{name} );
        $value = $field->{value};
    }

    unless( defined( $value ) || $this->isMultiValued() ) {
        $value = $this->{value};
    }

    $value = '' unless defined( $value );  # allow 0 values

    return CGI::hidden( -name => $this->{name}, -value => $value );
}

# -> $boolean
# return true if the value was updated from the query

sub populateMetaFromQueryData {
    my( $this, $query, $meta, $old ) = @_;
    my $value;

    if( defined( $query->param( $this->{name} ))) {

        if( $this->isMultiValued() ) {
            my @values = $query->param( $this->{name} );

            if( scalar( @values ) == 1 ) {
                @values = split( /,|%2C/, $values[0] );
            }
            my %vset = ();
            foreach my $val ( @values ) {
                $val =~ s/^\s*//o;
                $val =~ s/\s*$//o;
                # skip empty values
                $vset{$val} = (defined $val && $val =~ /\S/);
            }
            $value = '';
            my $isValues = ( $this->{type} =~ /\+values/ );
            $this->expandOptions();
            foreach my $option ( @{$this->{options}} ) {
                $option =~ s/^.*?[^\\]=(.*)$/$1/ if $isValues;
                # Maintain order of definition
                if( $vset{$option} ) {
                    $value .= ', ' if length( $value );
                    $value .= $option;
                }
            }
        } else {
            $value = $query->param( $this->{name} );

            if( defined( $value ) && $this->{session}->inContext('edit')) {
                $value = TWiki::expandStandardEscapes( $value );
            }
        }

    }

    # Find the old value of this field
    my $preDef;
    foreach my $item ( @$old ) {
        if( $item->{name} eq $this->{name} ) {
            $preDef = $item;
            last;
        }
    }

    my $def;

    if( defined( $value ) ) {
        # mandatory fields must have length > 0
        if( $this->isMandatory() && length( $value ) == 0) {
            return 0;
        }
        # NOTE: title and name are stored in the topic so that it can be
        # viewed without reading in the form definition
        $def =
          {
              name =>  $this->{name},
              title => $this->{title},
              value => $value,
              attributes => $this->{attributes},
          };
    } elsif( $preDef ) {
        $def = $preDef;
    } else {
        return 0;
    }

    $meta->putKeyed( 'FIELD', $def ) if $def;

    return 1;
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

