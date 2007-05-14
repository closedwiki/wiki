# See bottom of file for license and copyright details
# base class for all form field types

=pod

---+ package TWiki::Form::FieldDefinition

Base class of all field definition classes.

Type-specific classes are derived from this class to define specific
per-type behaviours. This class also provides default behaviours for when
a specific type cannot be loaded.

=cut

package TWiki::Form::FieldDefinition;

use strict;
use Assert;

=pod

---++ ClassMethod new(%...)

Construct a new FieldDefinition. Parameters are passed in a hash. See
Form.pm for how it is called. Subclasses should pass @_ on to this class.

=cut

sub new {
    my $class = shift;
    my %attrs = @_;

    $attrs{name} ||= '';
    $attrs{attributes} ||= '';
    $attrs{type} ||= ''; # default
    $attrs{size} =~ s/^\s*//;
    $attrs{size} =~ s/\s*$//;
    return bless(\%attrs, $class);
}

=pod

---++ isEditable() -> $boolean

Is the field type editable? Labels aren't, for example. Subclasses may need
to redefine this.

=cut

sub isEditable { 1 }

=pod

---++ isMultiValued() -> $boolean

Is the field type multi-valued (i.e. does it store multiple values)?
Subclasses may need to redefine this.

=cut

sub isMultiValued { 0 }

=pod

---++ isTextMergeable() -> $boolean

Is this field type mergeable using a conventional text merge?

=cut

# can't merge multi-valued fields (select+multi, checkbox)
sub isTextMergeable { return !shift->isMultiValued() }

=pod

---++ isMandatory() -> $boolean

Is this field mandatory (required)?

=cut

sub isMandatory { return shift->{attributes} =~ /M/ }

=pod

---++ renderForEdit( $web, $topic, $value ) -> ($col0html, $col1html)
   =$web= - the web containing the topic being edited
   =$topic= - the topic being edited
Render the field for editing. Returns two chunks of HTML; the
=$col0html= is appended to the HTML for the first column in the
form table, and the =$col1html= is used as the content of the second column.

=cut

sub renderForEdit {
    my( $this, $web, $topic, $value ) = @_;

    # Treat like text, make it reasonably long, add a warning
    return ( '<br /><span class="twikiAlert">MISSING TYPE '.
               $this->{type}.'</span>',
            CGI::textfield( -class => 'twikiEditFormError',
                            -name => $this->{name},
                            -size => 80,
                            -value => $value ));
}

=pod

---++ getDefaultValue() -> $value
Try and get a sensible default value for the field from the
values stored in the form definition. The result should be
a value string.

Some subclasses may not support the definition of defaults in
the form definition. In that case this method should return =undef=.

=cut

sub getDefaultValue {
    my $this = shift;

    my $value = $this->{value};
    $value = '' unless defined $value;  # allow 0 values

    return $value;
}

=pod

---++ renderHidden($meta) -> $html
Render the form in =$meta= as a set of hidden fields.

=cut

sub renderHidden {
    my( $this, $meta ) = @_;

    my $value;
    if( $this->{name} ) {
        my $field = $meta->get( 'FIELD', $this->{name} );
        $value = $field->{value};
    }

    my @values;

    if( defined( $value )) {
        if( $this->isMultiValued() ) {
            push( @values, split(/\s*,\s*/, $value ));
        } else {
            push( @values, $value );
        }
    } else {
        $value = $this->getDefaultValue();
        push( @values, $this->getDefaultValue() ) if $value;
    }

    return '' unless scalar( @values );

    return CGI::hidden( -name => $this->{name}, -default => \@values );
}

=pod

---++ populateMetaDataFromQuery( $query, $meta, $old ) -> $boolean

Given a CGI =$query=, a =$meta= object, and an array of =$old= field entries,
then populate the $meta with a row for this field definition, taking the
content from the query if it's there, otherwise from $old or failing that,
from the default defined for the type. Refuses to update mandatory fields
that have an empty value.

Return true if the value in $meta was updated.

=cut

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

            foreach my $option ( @{$this->getOptions()} ) {
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
        my $title = $this->{title};
        if( $this->{definingTopic} ) {
            $title = '[['.$this->{definingTopic}.']['.$title.']]';
        }
        $def =
          {
              name =>  $this->{name},
              title => $title,
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

