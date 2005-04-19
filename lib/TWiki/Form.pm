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

This module handles the encoding and decoding of %TWIKIWEB%.TWikiForms,
including upgrade of older format topics using the 'Category Table'
approach, an earlier type of form.

=cut

package TWiki::Form;

use strict;
use Assert;
use Error qw( :try );
use TWiki::OopsException;
use CGI qw( -any );

=pod

---++ ClassMethod new ( $session )
Constructor

=cut

sub new {
    my ( $class, $session ) = @_;
    my $this = bless( {}, $class );
    ASSERT(ref($session) eq 'TWiki') if DEBUG;
    $this->{session} = $session;
    return $this;
}

# Get definition from supplied topic text
# Returns array of arrays
#   1st - list fields
#   2nd - name, title, type, size, vals, tooltip, setting
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
        } else {
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

                push( @fields,
                      { name => _cleanField( $title ),
                        title => $title,
                        type => $type,
                        size => $size,
                        value => $vals,
                        tooltip => $tooltip,
                        attributes => $attributes,
                      } );
            } else {
                $inBlock = 0;
            }
        }
    }

    return \@fields;
}


sub _cleanField {
   my( $text ) = @_;
   $text = '' if( ! $text );
   # TODO: make this dependent on a 'character set includes non-alpha'
   # setting in TWiki.cfg - and do same in Render.pm re 8859 test.
   # I18N: don't get rid of non-ASCII characters
   # $text =~ s/[^A-Za-z0-9_\.]//go; # Need do for web.topic
   return $text;
}


=pod

---++ StaticMethod getPossibleFieldValues (  $text  )

Possible field values for select, checkbox, radio from supplied topic text

=cut

sub getPossibleFieldValues {
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

=pod

---++ ObjectMethod getFormDef (  $webName, $form  ) -> @fields

Get array of field definition, given form name
If form contains Web this overrides webName

May throw TWiki::OopsException

=cut

sub getFormDef {
    my( $this, $webName, $form ) = @_;
    ASSERT(ref($this) eq 'TWiki::Form') if DEBUG;

    ( $webName, $form ) =
      $this->{session}->normalizeWebTopicName( $webName, $form );

    my $store = $this->{session}->{store};

    # Read topic that defines the form
    unless( $store->topicExists( $webName, $form ) ) {
        throw TWiki::OopsException( 'noformdef',
                                    web => $this->{session}->{webName},
                                    topic => $this->{session}->{topicName},
                                    params => [ $webName, $form ] );
    }
    my( $meta, $text ) =
      $store->readTopic( $this->{session}->{user}, $webName, $form, undef );

    my $fieldsInfo = $this->_parseFormDefinition( $text );

    # Expand out values arrays in the definition
    foreach my $fieldDef ( @$fieldsInfo ) {
        my @posValues = ();

        if( $fieldDef->{type} =~ /^(checkbox|radio|select)/ ) {
            @posValues = split( /[,\s]+/, $fieldDef->{value} );

            if( !scalar( @posValues ) && $store->topicExists( $webName, $fieldDef->{name} ) ) {
                # If no values are defined, see if we can get them from
                # the topic of the same name as the field
                my( $meta, $text ) =
                  $store->readTopic( $this->{session}->{user}, $webName, $fieldDef->{name},
                                     undef );
                # http://twiki.org/cgi-bin/view/Codev/DynamicFormOptionDefinitions
                $text = $this->{session}->handleCommonTags( $text, $form, $webName );
                @posValues = getPossibleFieldValues( $text );
                $fieldDef->{type} ||= 'select';  #FIXME keep?
            }
            $fieldDef->{value} = \@posValues;
        }
    }

    return $fieldsInfo;
}

sub _link {
    my( $this, $web, $name, $tooltip, $heading, $align, $span, $extra ) = @_;

    $name =~ s/[\[\]]//go;

    my %attrs;

    $attrs{-align} = $align if $align;
    $attrs{-colspan} = $span if $span;

    my $link = $name;

    my $store = $this->{session}->{store};
    if( $store->topicExists( $web, $name ) ) {
        ( $web, $name ) = $this->{session}->normalizeWebTopicName( $web, $name );
        if( ! $tooltip ) {
            $tooltip = 'Click to see details in separate window';
        }
        $link =
          CGI::a( { target => $name,
                    onclick => 'return launchWindow("'.$web.'","'.$name.'")',
                    title => $tooltip,
                    href =>$this->{session}->getScriptUrl($web, $name, 'view'),
                    rel => 'nofollow'
                  }, $name );
    } elsif ( $tooltip ) {
        $link = CGI::span({ -title=>$tooltip }, $name );
    }

    if( $heading ) {
        $attrs{-bgcolor} = '#99CCCC';
        return CGI::th( \%attrs, $link, );
    } else {
        return CGI::td( \%attrs, $link );
    }
}

=pod

---++ ObjectMethod renderForEdit (  $web, $topic, $formWeb, $form, $meta, $getValuesFromFormTopic ) -> $html

Render form fields for entry during an edit session

SMELL: this method is a horrible hack. It badly wants cleaning up.
e.g. FIXME could do with some of this being in template

=cut

sub renderForEdit {
    my( $this, $web, $topic, $formWeb, $form, $meta, $getValuesFromFormTopic ) = @_;
    ASSERT(ref($this) eq 'TWiki::Form') if DEBUG;
    my $session = $this->{session};

    my $chooseForm = '';
    my $prefs = $session->{prefs};
    if( $prefs->getPreferencesValue( 'WEBFORMS', $web ) ) {
        $chooseForm =
          CGI::submit(-name => 'submitChangeForm',
                      -value => 'Replace form...',
                      -class => "twikiChangeFormButton twikiSubmit");
    }

    my $text = CGI::start_table(-border=>1, -cellspacing=>0, -cellpadding=>0 );
    $text .= CGI::Tr($this->_link( $web, $form, '', 1, '', 2, $chooseForm ));

    my $fieldsInfo = $this->getFormDef( $formWeb, $form );
    foreach my $c ( @$fieldsInfo ) {
        my $name = $c->{name};
        my $title = $c->{title};
        my $type = $c->{type};
        my $size = $c->{size};
        my $tooltip = $c->{tooltip};
        my $attributes = $c->{attributes};

        my $field;
        my $value;
        if( $name ) {
            $field = $meta->get( 'FIELD', $name );
            $value = $field->{value};
        }
        if( ! defined( $value ) && $attributes =~ /S/ ) {
            # Allow initialisation based on a preference
            $value = $prefs->getPreferencesValue($name);
        }
        if( $getValuesFromFormTopic && !defined( $value ) &&
            $type !~ /^(checkbox|radio|select)/ ) {

            # Try and get a sensible default value from the form
            # definition. Doesn't make sense for checkboxes,
            # radio buttons or select.
            $value = $c->{value};
            if( defined( $value )) {
                $value = $session->handleCommonTags( $value, $web, $topic );
            }
        }
        $value = '' unless defined $value;  # allow 0 values
        my $extra = '';

        my $output = $session->{plugins}->renderFormFieldForEditHandler
          ( $name, $type, $size, $value, $attributes, $c->{value} );
        if( $output ) {
            $value = $output;

        } elsif( $type eq 'text' ) {
            $value = CGI::textfield( -class => 'twikiEditFormTextField',
                                     -name => $name,
                                     -size => $size,
                                     -value => $value );

        } elsif( $type eq 'label' ) {
            $value = CGI::div( { class => 'twikiEditFormLabelField' },
                               $session->{renderer}->getRenderedVersion
                               ( $session->handleCommonTags( $c->{value}, $web, $topic )));

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
            my $options = $c->{value};
            ASSERT( ref( $options )) if DEBUG;
            my $choices = '';
            foreach my $item ( @$options ) {
                my $selected = ( $item eq $value );
                $item =~ s/<nop/&lt\;nop/go;
                if( $selected ) {
                    $choices .= CGI::option({ selected=>'selected' }, $item );
                } else {
                    $choices .= CGI::option( $item );
                }
            }
            $value = CGI::Select( { name=>$name, size=>$size }, $choices );

        } elsif( $type =~ /^checkbox/ ) {
            my $options = $c->{value};
            ASSERT( ref( $options )) if DEBUG;
            $value = '';
            if( $type eq 'checkbox+buttons' ) {
                my $boxes = scalar( @$options );
                $extra .= CGI::br();
                $extra = CGI::button
                  ( -class => 'twikiEditFormCheckboxButton',
                    -value => 'Set',
                    -onClick => 'checkAll(this,2,'.$boxes.',true)' );
                $extra .= '&nbsp;';
                $extra .= CGI::button
                  ( -class => 'twikiEditFormCheckboxButton',
                    -value => 'Clear',
                    -onClick => 'checkAll(this,1,'.$boxes.',false)');
            }
            my %attrs;
            my @defaults;
            foreach my $item ( @$options ) {
                $attrs{$item} =
                  { class=>'twikiEditFormCheckboxField',
                    label=>$session->handleCommonTags( $item,
                                                       $web,
                                                       $topic ) };
                if( $value =~ /(^|,\s*)$item(,|$)/ ) {
                    $attrs{$item}{checked} = 'checked';
                    push( @defaults, $item );
                }
            }
            $value .= CGI::checkbox_group( -name => $name,
                                          -values => $options,
                                          -defaults => \@defaults,
                                          -columns => $size,
                                          -attributes => \%attrs );

        } elsif( $type eq 'radio' ) {
            my $options = $c->{value};
            ASSERT( ref( $options )) if DEBUG;
            my %attrs;
            my @defaults;
            my $selected = '';
            foreach my $item ( @$options ) {
                $attrs{$item} =
                  { class=>'twikiEditFormRadioField twikiRadioButton',
                    label=>$session->handleCommonTags( $item,
                                                               $web,
                                                               $topic ) };

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
        $text .= CGI::Tr($this->_link( $web, $title, $tooltip, 1,
                                       'right', '', $extra ) .
                         CGI::td( { -align=>'left' } , $value ));
    }
    $text .= CGI::end_table();

    return CGI::div({-class=>'twikiForm twikiEditForm'}, $text );
}


=pod

---++ ObjectMethod fieldVars2Meta($webName, $query, $metaObject, $justOverride) -> $metaObject

Extract new values of form fields from a query.

Note that existing meta information for fields is removed unless $justOverride is true

May throw TWiki::OopsException

=cut

sub fieldVars2Meta {
    my( $this, $webName, $query, $meta, $justOverride ) = @_;
    ASSERT(ref($this) eq 'TWiki::Form') if DEBUG;
    ASSERT(ref($meta) eq 'TWiki::Meta') if DEBUG;

    $meta->remove( 'FIELD' ) if( ! $justOverride );

    #$this->{session}->writeDebug( "Form::fieldVars2Meta " . $query->query_string );

    my $form = $meta->get( 'FORM' );
    return $meta unless $form;

    my $fieldsInfo = $this->getFormDef( $webName, $form->{name} );

    foreach my $fieldDef ( @$fieldsInfo ) {
       next unless $fieldDef->{name};

       my $value = $query->param( $fieldDef->{name} );
       if( defined $value ) {
           if( $fieldDef->{type} =~ /^checkbox/ ) {
               $value = join( ', ', $query->param( $fieldDef->{name} ) );
           } else {
               $value = $query->param( $fieldDef->{name} );
           }
       }

       # title and name are stored so that topic can be viewed without
       # reading in form definition
       $value = '' unless( defined( $value ) || $justOverride );
       if( defined( $value ) ) {
           my $args =
             {
              name =>  $fieldDef->{name},
              title => $fieldDef->{title},
              value => $value,
              attributes => $fieldDef->{attributes},
             };
           $meta->put( 'FIELD', $args );
       }
   }

   return $meta;
}

=pod

---++ StaticMethod getFieldParams (  $meta  )

Not yet documented.

=cut

sub getFieldParams {
    my( $meta ) = @_;
    ASSERT(ref($meta) eq 'TWiki::Meta') if DEBUG;

    my $params = '';

    my @fields = $meta->find( 'FIELD' );
    foreach my $field ( @fields ) {
       my $args = $2;
       my $name  = $field->{name};
       my $value = $field->{value};
       #$this->{session}->writeDebug( "Form::getFieldParams " . $name . ", " . $value );
       $params .= CGI::hidden( -name => $name,
                               -default => $value );
    }
    return $params;

}

#Upgrade old style category table item
sub _upgradeCategoryItem {
    my ( $catitems, $ctext ) = @_;
    my $catname = '';
    my $scatname = '';
    my $catmodifier = '';
    my $catvalue = '';
    my @cmd = split( /\|/, $catitems );
    my $src = '';
    my $len = @cmd;
    if( $len < '2' ) {
        # FIXME
        return ( $catname, $catmodifier, $catvalue )
    }
    my $svalue = '';

    my $i;
    my $itemsPerLine;

    # check for CategoryName=CategoryValue parameter
    my $paramCmd = '';
    my $cvalue = ''; # was$query->param( $cmd[1] );
    if( $cvalue ) {
        $src = "<!---->$cvalue<!---->";
    } elsif( $ctext ) {
        foreach( split( /\n/, $ctext ) ) {
            if( /$cmd[1]/ ) {
                $src = $_;
                last;
            }
        }
    }

    if( $cmd[0] eq 'select' || $cmd[0] eq 'radio') {
        $catname = $cmd[1];
        $scatname = $catname;
        #$scatname =~ s/[^a-zA-Z0-9]//g;
        my $size = $cmd[2];
        for( $i = 3; $i < $len; $i++ ) {
            my $value = $cmd[$i];
            my $svalue = $value;
            if( $src =~ /$value/ ) {
               $catvalue = $svalue;
            }
        }

    } elsif( $cmd[0] eq 'checkbox' ) {
        $catname = $cmd[1];
        $scatname = $catname;
        #$scatname =~ s/[^a-zA-Z0-9]//g;
        if( $cmd[2] eq 'true' || $cmd[2] eq '1' ) {
            $i = $len - 4;
            $catmodifier = 1;
        }
        $itemsPerLine = $cmd[3];
        for( $i = 4; $i < $len; $i++ ) {
            my $value = $cmd[$i];
            my $svalue = $value;
            # I18N: FIXME - need to look at this, but since it's upgrading
            # old forms that probably didn't use I18N, it's not a high
            # priority.
            if( $src =~ /$value[^a-zA-Z0-9\.]/ ) {
                $catvalue .= ", " if( $catvalue );
                $catvalue .= $svalue;
            }
        }

    } elsif( $cmd[0] eq 'text' ) {
        $catname = $cmd[1];
        $scatname = $catname;
        #$scatname =~ s/[^a-zA-Z0-9]//g;
        $src =~ /<!---->(.*)<!---->/;
        if( $1 ) {
            $src = $1;
        } else {
            $src = '';
        }
        $catvalue = $src;
    }

    return ( $catname, $catmodifier, $catvalue )
}

=pod

---++ ObjectMethod upgradeCategoryTable (  $web, $topic, $meta, $text  ) -> $text

Upgrade old style category table

May throw TWiki::OopsException

=cut

sub upgradeCategoryTable {
    my( $this, $web, $topic, $meta, $text ) = @_;
    ASSERT(ref($this) eq 'TWiki::Form') if DEBUG;

    my $icat = $this->{session}->{templates}->readTemplate( 'twikicatitems' );

    if( $icat ) {
        my @items = ();
        # extract category section and build category form elements
        my( $before, $ctext, $after) = split( /<!--TWikiCat-->/, $text );
        # cut TWikiCat part
        $text = $before || '';
        $text .= $after if( $after );
        $ctext = '' if( ! $ctext );

        my $ttext = '';
        foreach( split( /\n/, $icat ) ) {
            my( $catname, $catmod, $catvalue ) = _upgradeCategoryItem( $_, $ctext );
            #$this->{session}->writeDebug( "Form: name, mod, value: $catname, $catmod, $catvalue" );
            if( $catname ) {
                push @items, ( [$catname, $catmod, $catvalue] );
            }
        }
        my $prefs = $this->{session}->{prefs};
        my $listForms = $prefs->getPreferencesValue( 'WEBFORMS', $web );
        $listForms =~ s/^\s*//go;
        $listForms =~ s/\s*$//go;
        my @formTemplates = split( /\s*,\s*/, $listForms );
        my $defaultFormTemplate = '';
        $defaultFormTemplate = $formTemplates[0] if ( @formTemplates );

        if( ! $defaultFormTemplate ) {
            $this->{session}->writeWarning( "Form: can't get form definition to convert category table " .
                                  " for topic $web.$topic" );
            foreach my $oldCat ( @items ) {
                my $name = $oldCat->[0];
                my $value = $oldCat->[2];
                $meta->put( 'FORM', { name => '' } );
                $meta->put( 'FIELD',
                            { name => $name,
                              title => $name,
                              value => $value
                            } );
            }
            return;
        }

        my $fieldsInfo = $this->getFormDef( $web, $defaultFormTemplate );
        $meta->put( 'FORM', { name => $defaultFormTemplate } );

        foreach my $fieldDef ( @$fieldsInfo ) {
           my $value = '';
           foreach my $oldCatP ( @items ) {
               my @oldCat = @$oldCatP;
               if( _cleanField( $oldCat[0] ) eq $fieldDef->{name} ) {
                  $value = $oldCat[2];
                  last;
               }
           }
           $meta->put( 'FIELD',
                     {
                      name => $fieldDef->{name},
                      title => $fieldDef->{title},
                      value => $value,
                     } );
        }

    } else {
        $this->{session}->writeWarning( "Form: get find category template twikicatitems for Web $web" );
    }
    return $text;
}

1;
