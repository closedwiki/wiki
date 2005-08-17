# TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 1999-2005 Peter Thoeny, peter@thoeny.com
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
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

---+ package TWiki::Form

Object representing a single form definition.

=cut

package TWiki::Form;

use strict;
use Assert;
use Error qw( :try );
use TWiki::OopsException;
use CGI qw( -any );

use vars qw( $reservedFieldNames );

BEGIN {
    # The following are reserved as URL parameters to scripts and may not be
    # used as field names in forms.
    $reservedFieldNames =
      {
          action => 1,
          breaklock => 1,
          contenttype => 1,
          cover => 1,
          dontnotify => 1,
          editaction => 1,
          forcenewrevision => 1,
          formtemplate => 1,
          onlynewtopic => 1,
          onlywikiname => 1,
          originalrev => 1,
          skin => 1,
          templatetopic => 1,
          text => 1,
          topic => 1,
          topicparent => 1,
          user => 1,
      };
};

=pod

---++ ClassMethod new ( $session, $web, $form )

   * $web - default web to recover form from, if $form doesn't specify a web
   * =$form= - topic name to read form definition from

May throw TWiki::OopsException

=cut

sub new {
    my( $class, $session, $web, $form, $noNameCheck ) = @_;
    my $this = bless( {}, $class );

    ( $web, $form ) =
      $session->normalizeWebTopicName( $web, $form );

    my $store = $session->{store};

    # Read topic that defines the form
    unless( $store->topicExists( $web, $form ) ) {
        return undef;
    }
    my( $meta, $text ) =
      $store->readTopic( $session->{user}, $web, $form, undef );

    $this->{session} = $session;
    $this->{web} = $web;
    $this->{topic} = $form;
    $this->{fields} = $this->_parseFormDefinition( $text );

    # Expand out values arrays in the definition
    # SMELL: this should be done lazily
    foreach my $fieldDef ( @{$this->{fields}} ) {
        my @posValues = ();

        if( $fieldDef->{type} =~ /^(checkbox|radio|select)/ ) {
            @posValues = split( /,/, $fieldDef->{value} );
            my $topic = $fieldDef->{definingTopic} || $fieldDef->{name};
            if( !scalar( @posValues ) &&
                  $store->topicExists( $web, $topic ) ) {
                # If no values are defined, see if we can get them from
                # the topic of the same name as the field
                my( $meta, $text ) =
                  $store->readTopic( $session->{user}, $web, $topic, undef );
                # Add processing of SEARCHES for Lists
                # SMELL: why isn't this just handleCommonTags?
                $text =~ s/%SEARCH{(.*?)}%/_searchVals($session, $1)/geo;
                @posValues = _getPossibleFieldValues( $text );
                $fieldDef->{type} ||= 'select';  #FIXME keep?
            }
            #FIXME duplicates code in _getPossibleFieldValues?
            @posValues = map { $_ =~ s/^\s*(.*)\s*$/$1/; $_; } @posValues;
            $fieldDef->{value} = \@posValues;
        }

        if( $fieldDef->{attributes} =~ /M/ ) {
            $this->{mandatoryFieldsPresent} = 1;
        }
    }

    return $this;
}

# Get definition from supplied topic text
# Returns array of arrays
#   1st - list fields
#   2nd - name, title, type, size, vals, tooltip, attributes
#   Possible attributes are "M" (mandatory field)
sub _parseFormDefinition {
    my( $this, $text ) = @_;

    my $store = $this->{session}->{store};
    my @fields = ();
    my $inBlock = 0;
    $text =~ s/\\\r?\n//go; # remove trailing '\' and join continuation lines

    # | *Name:* | *Type:* | *Size:* | *Value:*  | *Tooltip message:* | *Attributes:* |
    # Tooltip and attributes are optional
    foreach( split( /\n/, $text ) ) {
        if( /^\s*\|.*Name[^|]*\|.*Type[^|]*\|.*Size[^|]*\|/ ) {
            $inBlock = 1;
            next;
        }
        # Only insist on first field being present FIXME - use oops page instead?
        if( $inBlock && s/^\s*\|//o ) {
            my( $title, $type, $size, $vals, $tooltip, $attributes ) = split( /\|/ );
            $title ||= '';
            $title =~ s/^\s*//go;
            $title =~ s/\s*$//go;

            $attributes ||= '';
            $attributes =~ s/\s*//go;
            $attributes = '' if( ! $attributes );

            $type ||= '';
            $type = lc $type;
            $type =~ s/^\s*//go;
            $type =~ s/\s*$//go;
            $type = 'text' if( ! $type );

            $size ||= '';
            $size = _cleanField( $size );
            unless( $size ) {
                if( $type eq 'text' ) {
                    $size = 20;
                } elsif( $type eq 'textarea' ) {
                    $size = '40x5';
                } else {
                    $size = 1;
                }
            }

            $vals ||= '';
            # SMELL: why isn't this just handleCommonTags?
            $vals =~ s/%SEARCH{(.*?)}%/_searchVals($this->{session}, $1)/geo;
            $vals =~ s/^\s*//go;
            $vals =~ s/\s*$//go;

            # SMELL: WTF is this??? This looks like a really bad hack!
            if( $vals eq '$users' ) {
                $vals = $TWiki::cfg{UsersWebName} . '.' .
                  join( ", ${TWiki::cfg{UsersWebName}}.",
                        ( $store->getTopicNames( $TWiki::cfg{UsersWebName} ) ) );
            }

            $tooltip ||= '';
            $tooltip =~ s/^\s*//go;
            $tooltip =~ s/\s*$//go;

            my $definingTopic = "";
            if( $title =~ /\[\[(.+)\]\[(.+)\]\]/ )  { # use common defining
                $definingTopic = _cleanField( $1 );      # topics with different
                $title = $2;                          # field titles
            }

            my $name = _cleanField( $title );

            # Rename fields with reserved names
            if( $reservedFieldNames->{$name} ) {
                $name .= '_';
                $title .= '_';
            }

            push( @fields,
                  { name => $name,
                    title => $title,
                    type => $type,
                    size => $size,
                    value => $vals,
                    tooltip => $tooltip,
                    attributes => $attributes,
                    definingTopic => $definingTopic
                   } );
        } else {
            $inBlock = 0;
        }
    }

    return \@fields;
}

sub _searchVals {
    my ( $session, $arg ) = @_;
    $arg =~ s/%WEB%/$session->{webName}/go;
    return $session->_SEARCH(new TWiki::Attrs($arg), $session->{topicName}, $session->{webName});
}

# Chop out all except A-Za-z0-9_.
# I'm sure there must have been a good reason for this once.
sub _cleanField {
    my( $text ) = @_;
    $text = '' if( ! $text );
    # TODO: make this dependent on a 'character set includes non-alpha'
    # setting in TWiki.cfg - and do same in Render.pm re 8859 test.
    # I18N: don't get rid of non-ASCII characters
    # TW: this is applied to the key in the field; it is not obvious
    # why we need I18N in the key (albeit there could be collisions due
    # to the filtering... but all the current topics are keyed on _cleanField
    $text =~ s/<nop>//go;    # support <nop> character in title
    $text =~ s/[^A-Za-z0-9_\.]//go;
    return $text;
}


# Possible field values for select, checkbox, radio from supplied topic text
sub _getPossibleFieldValues {
    my( $text ) = @_;
    my @defn = ();
    my $inBlock = 0;
    foreach( split( /\n/, $text ) ) {
        if( /^\s*\|.*Name[^|]*\|/ ) {
            $inBlock = 1;
        } else {
            if( /^\s*\|\s*([^|]*)\s*\|/ ) {
                my $item = $1;
                $item =~ s/\s+$//go;
                $item =~ s/^\s+//go;
                if( $inBlock ) {
                    push @defn, $item;
                }
            } else {
                $inBlock = 0;
            }
        }
    }
    return @defn;
}

# Generate a link to the given topic, so we can bring up details in a
# separate window.
sub _link {
    my( $this, $string, $tooltip, $topic ) = @_;

    $string =~ s/[\[\]]//go;

    $topic ||= $string;
    $tooltip ||= 'Click to see details in separate window';

    my $web;
    ( $web, $topic ) =
      $this->{session}->normalizeWebTopicName( $this->{web}, $topic );

    my $link;

    my $store = $this->{session}->{store};
    if( $store->topicExists( $web, $topic ) ) {
        $link =
          CGI::a(
              { target => $topic,
                onclick => 'return launchWindow("'.$web.'","'.$topic.'")',
                title => $tooltip,
                href =>$this->{session}->getScriptUrl($web, $topic, 'view'),
                rel => 'nofollow'
               }, $string );
    } elsif ( $tooltip ) {
        $link = CGI::span( { title=>$tooltip }, $string );
    } else {
        $link = $string;
    }

    return $link;
}

=pod

---++ ObjectMethod renderForEdit( $web, $topic, $meta, $useDefaults ) -> $html
   * =$web= the web of the topic being rendered
   * =$topic= the topic being rendered
   * =$meta= the meta data for the form
   * =$useDefaults= if true, will use default values from the form definition if no other value is given

Render the form fields for entry during an edit session, using data values
from $meta

=cut

sub renderForEdit {
    my( $this, $web, $topic, $meta, $useDefaults ) = @_;
    ASSERT($this->isa( 'TWiki::Form')) if DEBUG;
    ASSERT($meta->isa( 'TWiki::Meta')) if DEBUG;
    my $session = $this->{session};

    if( $this->{mandatoryFieldsPresent} ) {
        $session->enterContext( 'mandatoryfields' );
    }
    my $tmpl = $session->{templates}->readTemplate( "form", $session->getSkin() );

    # Note: if WEBFORMS preference is not set, can only delete form.
    $tmpl =~ s/%FORMTITLE%/$this->_link($this->{web}.'.'.$this->{topic})/geo;
    my( $text, $repeatTitledText, $repeatUntitledText, $afterText ) =
      split( /%REPEAT%/, $tmpl );

    foreach my $fieldDef ( @{$this->{fields}} ) {

        my $tooltip = $fieldDef->{tooltip};
        my $definingTopic = $fieldDef->{definingTopic};
        my $title = $fieldDef->{title};

        if (! $title && $fieldDef->{type} eq 'label') {
            # Special handling for untitled labels
            my $tmp = $repeatUntitledText;
            my $value =
              $session->{renderer}->getRenderedVersion(
                  $session->handleCommonTags($fieldDef->{value}, $web, $topic));
            $tmp =~ s/%ROWVALUE%/$value/go;
            $text .= $tmp;
        } else {
            my( $extra, $value );
            my $name = $fieldDef->{name};
            if( $name ) {
                my $field = $meta->get( 'FIELD', $name );
                $value = $field->{value};
            }
            if( $useDefaults && !defined( $value ) &&
                  $fieldDef->{type} !~ /^checkbox/ ) {

                # Try and get a sensible default value from the form
                # definition. Doesn't make sense for checkboxes.
                $value = $fieldDef->{value};
                if( defined( $value )) {
                    $value = $session->handleCommonTags( $value, $web,
                                                         $topic );
                }
            }
            $value = '' unless defined $value;  # allow 0 values

            ( $extra, $value ) =
              $this->renderFieldForEdit( $fieldDef, $web, $topic, $value );

            my $tmp = $repeatTitledText;
            $tmp =~ s/%ROWTITLE%/$this->_link($title,$tooltip,$definingTopic)/geo;
            $tmp =~ s/%ROWEXTRA%/$extra/go;
            $tmp =~ s/%ROWVALUE%/$value/go;
            $text .= $tmp;
        }
    }

    $text .= $afterText;
    return $text;
}

=pod

---++ ObjectMethod renderFieldForEdit( $fieldDef, $web, $topic, $value) -> $html
   * =$fieldDef= the field being rendered
   * =$web= the web of the topic being rendered
   * =$topic= the topic being rendered
   * =$value= the current value of the field

Render a single form field for entry during an edit session, using data values
from $meta. Plugins can provide a handler that extends the set of supported
types

SMELL: this should be a method on a field class
SMELL: JSCalendarContrib ought to provide a 'date' handler.

=cut

sub renderFieldForEdit {
    my( $this, $fieldDef, $web, $topic, $value ) = @_;

    my $name = $fieldDef->{name};
    my $type = $fieldDef->{type} || '';
    my $size = $fieldDef->{size};
    my $attributes = $fieldDef->{attributes} || '';
    my $extra = '';
    my $session = $this->{session};

    if( $attributes =~ /M/ ) {
        $extra = CGI::span( { class => 'twikiAlert' }, ' *' );
    }

    my $options;
    my $item;
    my %attrs;
    my @defaults;
    my $selected;

    $name = $this->cgiName( $name );

    my $output = $session->{plugins}->renderFormFieldForEditHandler
      ( $name, $type, $size, $value, $attributes, $fieldDef->{value} );

    if( $output ) {
        $value = $output;

    } elsif( $type eq 'text' ) {
        $value = CGI::textfield( -class => 'twikiEditFormTextField',
                                 -name => $name,
                                 -size => $size,
                                 -value => $value );

    } elsif( $type eq 'label' ) {
        # Interesting question: if something is defined as "label",
        # could it be changed by applications or is the value
        # necessarily identical to what is in the form? If we can
        # take it from the text, we must be sure it cannot be
        # changed through the URL?
        my $renderedValue = $session->{renderer}->getRenderedVersion
          ( $session->handleCommonTags( $value, $web, $topic ));
        $value = CGI::hidden( -name => $name,
                              -class => 'twikiEditFormLabelField',
                              -value => $renderedValue );
        $value .= CGI::div( { class => 'twikiEditFormLabelField' },
                            $renderedValue );

    } elsif( $type eq 'textarea' ) {
        my $cols = 40;
        my $rows = 5;
        if( $size =~ /([0-9]+)x([0-9]+)/ ) {
            $cols = $1;
            $rows = $2;
        }
        $value = CGI::textarea( -class => 'twikiEditFormTextAreaField',
                                -cols => $cols,
                                -rows => $rows,
                                -name => $name,
                                -default => "\n".$value );

    } elsif( $type eq 'select' ) {
        $options = $fieldDef->{value};
        ASSERT( ref( $options )) if DEBUG;
        my $choices = '';
        foreach $item ( @$options ) {
            $selected = ( $item eq $value );
            $item =~ s/<nop/&lt\;nop/go;
            if( $selected ) {
                $choices .= CGI::option({ selected=>'selected' }, $item );
            } else {
                $choices .= CGI::option( $item );
            }
        }
        $value = CGI::Select( { name=>$name, size=>$size }, $choices );

    } elsif( $type =~ /^checkbox/ ) {
        $options = $fieldDef->{value};
        ASSERT( ref( $options )) if DEBUG;
        if( $type eq 'checkbox+buttons' ) {
            my $boxes = scalar( @$options );
            $extra = CGI::br();
            # SMELL: localisation - this should be from a template
            $extra .= CGI::button
              ( -class => 'twikiEditFormCheckboxButton',
                -value => 'Set',
                -onClick => 'checkAll(this,2,'.$boxes.',true)' );
            $extra .= '&nbsp;';
            # SMELL: localisation - this should be from a template
            $extra .= CGI::button
              ( -class => 'twikiEditFormCheckboxButton',
                -value => 'Clear',
                -onClick => 'checkAll(this,1,'.$boxes.',false)');
        }
        foreach $item ( @$options ) {
            #NOTE: Does not expand $item in label
            $attrs{$item} =
              { class=>'twikiEditFormCheckboxField',
                label=>$session->handleCommonTags( $item,
                                                   $web,
                                                   $topic ) };
            if( $value =~ /(^|,\s*)$item(\s*,|$)/ ) {
                $attrs{$item}{checked} = 'checked';
                push( @defaults, $item );
            }
        }
        $value = CGI::checkbox_group( -name => $name,
                                      -values => $options,
                                      -defaults => \@defaults,
                                      -columns => $size,
                                      -attributes => \%attrs );

    } elsif( $type eq 'radio' ) {
        $options = $fieldDef->{value};
        ASSERT( ref( $options )) if DEBUG;
        $selected = '';
        foreach $item ( @$options ) {
            $attrs{$item} =
              { class=>'twikiEditFormRadioField twikiRadioButton',
                label=>$session->handleCommonTags( $item, $web, $topic ) };

            $selected = $item if( $item eq $value );
        }

        $value = CGI::radio_group( -name => $name,
                                   -values => $options,
                                   -default => $selected,
                                   -columns => $size,
                                   -attributes => \%attrs );

    } else {
        # Treat like text, make it reasonably long
        # SMELL: Sven thinks this should be an error condition - so users
        # know about typo's, and don't lose data when the typo is fixed
        $value = CGI::textfield( -class=>'twikiEditFormError',
                                 -name=>$name,
                                 -size=>80,
                                 -value=>$value );

    }
    return ( $extra, $value );
}

=pod

---++ ObjectMethod renderHidden( $meta, $useDefaults ) -> $html
   * =$useDefaults= if true, will use default values from the form definition if no other value is given

Render form fields found in the meta as hidden inputs, so they pass
through edits untouched.

=cut

sub renderHidden {
    my( $this, $meta, $useDefaults ) = @_;
    ASSERT($this->isa( 'TWiki::Form')) if DEBUG;
    ASSERT($meta->isa( 'TWiki::Meta')) if DEBUG;
    my $session = $this->{session};

    my $text = "";

    foreach my $fieldDef ( @{$this->{fields}} ) {
        my $name = $fieldDef->{name};

        my $value;
        if( $name ) {
            my $field = $meta->get( 'FIELD', $name );
            $value = $field->{value};
        }

        if( $useDefaults && !defined( $value ) &&
              $fieldDef->{type} !~ /^checkbox/ ) {

            $value = $fieldDef->{value};
        }

        $value = '' unless defined $value;  # allow 0 values
        $text .= CGI::hidden( -name => $this->cgiName( $name ),
                              -value => $value );
    }

    return $text;
}

=pod

---++ ObjectMethod cgiName( $field ) -> $string
Generate the 'name' of the CGI parameter used to represent a field.

=cut

sub cgiName {
    my( $this, $fieldName ) = @_;

    # See Codev.FormFieldsNamedSameAsParameters
    return $fieldName;
}

=pod

---++ ObjectMethod getFieldValuesFromQuery($query, $metaObject, $handleMandatory) -> $metaObject
Extract new values for form fields from a query.
   * =$query= - the query
   * =$metaObject= - the meta object that is storing the form values
   * =$handleMandatory= - if set, will throw an OopsException if any mandatory fields are absent from the query.

For each field, if there is a value in the query, use it.
Otherwise if there is already entry for the field in the meta, keep it.
Otherwise, if $handleMandatory, initialise the field to '' and set it in the meta.

=cut

sub getFieldValuesFromQuery {
    my( $this, $query, $meta, $handleMandatory ) = @_;
    ASSERT($this->isa( 'TWiki::Form')) if DEBUG;
    ASSERT($meta->isa( 'TWiki::Meta')) if DEBUG;

    foreach my $fieldDef ( @{$this->{fields}} ) {
        next unless $fieldDef->{name};

        my $param = $this->cgiName( $fieldDef->{name} );

        my $value = $query->param( $param );
        if( $fieldDef->{type} =~ /^checkbox/ ) {
            my @checked = $query->param ( $param );
            $value = shift @checked;
            foreach my $val (@checked) {
                $value .= ", $val";
            }
        }

        # SMELL: This is really independent of $handleMandatory, but happens
        # to coincide with usage (to be proper, should introduce additional flag)
        if ( $handleMandatory ) {
            unless( defined( $value )) {
                # Note: In Cairo, meta data is overwritten by empty query parameter
                unless( defined( $meta->get( 'FIELD', $fieldDef->{name} ))) {
                    $value = '';
                }
            }
        }

        # NOTE: title and name are stored in the topic so that it can be
        # viewed without reading in the form definition

        my $mandatory = ($fieldDef->{attributes} =~ /M/)?1:0;
        if ( $handleMandatory && $mandatory && !$value ) {
            throw TWiki::OopsException( 'attention',
                                        def=>'mandatory_field',
                                        web => $this->{session}->{webName},
                                        topic => $this->{session}->{topicName},
                                        params => [ $fieldDef->{title} ] );
        }

        if( defined( $value ) ) {
            my $args =
              {
                  name =>  $fieldDef->{name},
                  title => $fieldDef->{title},
                  value => $value,
                  attributes => $fieldDef->{attributes},
              };
            $meta->putKeyed( 'FIELD', $args );
        }
    }

    return $meta;
}

=pod

---++ ObjectMethod isTextMergeable( $name ) -> $boolean
   * =$name= - name of a form field (value of the =name= attribute)
Returns true if the type of the named field allows it to be text-merged.

If the form does not define the field, it is assumed to be mergeable.

=cut

sub isTextMergeable {
    my( $this, $name ) = @_;

    foreach my $fieldDef ( @{$this->{fields}} ) {
        next unless( $fieldDef->{name} && $fieldDef->{name} eq $name);
        return( $fieldDef->{type} !~ /^(checkbox|radio|select)/ );
    }
    # Field not found - assume it is mergeable
    return 1;
}

1;
