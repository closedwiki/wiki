# Module of TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2001-2004 Peter Thoeny, peter@thoeny.com
#
# For licensing info read license.txt file in the TWiki root.
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at 
# http://www.gnu.org/copyleft/gpl.html
#
# Written by John Talintyre, jet@cheerful.com, Jul 2001.

=begin twiki

---+ package TWiki::Form

This module handles the encoding and decoding of %TWIKIWEB%.TWikiForms,
including upgrade of older format topics using the 'Category Table'
approach, an earlier type of form.

=cut

package TWiki::Form;

use strict;
use Assert;

=pod

---++ ClassMethod new ( $session )
Constructor

=cut

sub new {
    my ( $class, $session ) = @_;
    my $this = bless( {}, $class );
    ASSERT(ref($session) eq "TWiki") if DEBUG;
    $this->{session} = $session;
    return $this;
}

sub users { my $this = shift; return $this->{session}->{users}; }
sub prefs { my $this = shift; return $this->{session}->{prefs}; }
sub store { my $this = shift; return $this->{session}->{store}; }
sub sandbox { my $this = shift; return $this->{session}->{sandbox}; }
sub security { my $this = shift; return $this->{session}->{security}; }
sub templates { my $this = shift; return $this->{session}->{templates}; }
sub renderer { my $this = shift; return $this->{session}->{renderer}; }

# Get definition from supplied topic text
# Returns array of arrays
#   1st - list fields
#   2nd - name, title, type, size, vals, tooltip, setting
sub _parseFormDefinition
{
    my( $this, $text ) = @_;

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
                    $title =~ s/^\s*//go;
                    $title =~ s/\s*$//go;
                    my $name = _cleanField( $title );
                    $type = lc $type;
                    $attributes =~ s/\s*//go;
                    $attributes = "" if( ! $attributes );
                    $type =~ s/^\s*//go;
                    $type =~ s/\s*$//go;
                    $type = "text" if( ! $type );
                    $size = _cleanField( $size );
                    if( ! $size ) {
                        if( $type eq "text" ) {
                            $size = 20;
                        } elsif( $type eq "textarea" ) {
                            $size = "40x5";
                        } else {
                            $size = 1;
                        }
                    }
                    $size = 1 if( ! $size );
                    $vals =~ s/^\s*//go;
                    $vals =~ s/\s*$//go;
                    $vals =~ s/"//go; # " would break parsing of META variables
                    if( $vals eq '$users' ) {
                       $vals = $TWiki::cfg{UsersWebName} . "." . join( ", ${TWiki::cfg{UsersWebName}}.", ( $this->store()->getTopicNames( $TWiki::cfg{UsersWebName} ) ) );
                    }
                    $tooltip =~ s/^\s*//go;
                    $tooltip =~ s/\s*$//go;
                    # FIXME object if too short
                    push @fields, [ $name, $title, $type, $size, $vals, $tooltip, $attributes ];
            } else {
                $inBlock = 0;
            }
        }
    }

    return @fields;
}


sub _cleanField {
   my( $text ) = @_;
   $text = "" if( ! $text );
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

=cut

sub getFormDef {
    my( $this, $webName, $form ) = @_;
    ASSERT(ref($this) eq "TWiki::Form") if DEBUG;

    ( $webName, $form ) =
      $this->{session}->normalizeWebTopicName( $webName, $form );

    my @fieldDefs = ();

    # Read topic that defines the form
    if( $this->store()->topicExists( $webName, $form ) ) {
        my( $meta, $text ) =
          $this->store()->readTopic( $this->{session}->{user}, $webName, $form, undef );
        @fieldDefs = $this->_parseFormDefinition( $text );
    } else {
        # FIXME - do what if there is an error?
    }

    my @fieldsInfo = ();

    # Get each field definition
    foreach my $fieldDefP ( @fieldDefs ) {
        my @fieldDef = @$fieldDefP;
        my( $name, $title, $type, $size, $posValuesS, $tooltip, $attributes ) = @fieldDef;
        my @posValues = ();
        if( $posValuesS ) {
           @posValues = split( /,\s*/, $posValuesS );
        }

        if( ( ! @posValues ) && $this->store()->topicExists( $webName, $name ) ) {
            my( $meta, $text ) =
              $this->store()->readTopic( $this->{session}->{user}, $webName, $name, undef );
            @posValues = getPossibleFieldValues( $text );
            if( ! $type ) {
                $type = "select";  #FIXME keep?
            }
        } else {
            # FIXME no list matters for some types
        }
        push @fieldsInfo, [ ( $name, $title, $type, $size, $tooltip, $attributes, @posValues ) ];
    }

    return @fieldsInfo;
}

sub _link {
    my( $this, $web, $name, $tooltip, $heading, $align, $span, $extra ) = @_;
    
    $name =~ s/[\[\]]//go;
    
    my $cell = "td";
    my $attr = "";
    if( $heading ) {
       $cell = "th";
       $attr = ' bgcolor="#99CCCC"';
    }
    
    if( !$align ) {
       $align = "";
    } else {
       $align = " align=\"$align\"";
    }
    
    if( $span ) {
       $span = " colspan=\"$span\"";
    } else {
       $span = "";
    }
    
    my $link = "$name";
    
    if( $this->store()->topicExists( $web, $name ) ) {
        ( $web, $name ) = $this->{session}->normalizeWebTopicName( $web, $name );
        if( ! $tooltip ) {
            $tooltip = "Click to see details in separate window";
        }
        $link =  "<a target=\"$name\" " .
                 "onclick=\"return launchWindow('$web','$name')\" " .
                 "title=\"$tooltip\" " .
                 "href=\"".$this->{session}->{scriptUrlPath}."/view$TWiki::cfg{ScriptSuffix}/$web/$name\" $TWiki::cfg{NoFollow}>$name</a>";
    } elsif ( $tooltip ) {
        $link = "<span title=\"$tooltip\">$name</span>";
    }

    my $html = "<$cell$attr$span$align>$link $extra</$cell>";
    return $html;
}

=pod

---++ StaticMethod chooseFormButton (  $text  )

Not yet documented.

=cut

sub chooseFormButton {
    my( $text ) = @_;
    
    return "<input type=\"submit\" name=\"submitChangeForm\" value=\"$text\" class=\"twikiChangeFormButton twikiSubmit \" />";
}


=pod

---++ ObjectMethod renderForEdit (  $web, $topic, $form, $meta, $getValuesFromFormTopic,  @fieldsInfo  ) -> $html

Render form fields for entry during an edit session

=cut

sub renderForEdit {
    my( $this, $web, $topic, $form, $meta, $getValuesFromFormTopic, @fieldsInfo ) = @_;
    ASSERT(ref($this) eq "TWiki::Form") if DEBUG;

    my $chooseForm = "";
    if( $this->prefs()->getPreferencesValue( "WEBFORMS", "$web" ) ) {
        $chooseForm = chooseFormButton( "Replace form..." );
    }

    # FIXME could do with some of this being in template
    my $text = "<div class=\"twikiForm twikiEditForm\"><table border=\"1\" cellspacing=\"0\" cellpadding=\"0\">\n   <tr>" . 
               $this->_link( $web, $form, "", "h", "", 2, $chooseForm ) . "</tr>\n";

    my $query = $this->{session}->{cgiQuery};
    $this->fieldVars2Meta( $web, $query, $meta, "override" );

    foreach my $c ( @fieldsInfo ) {
        my @fieldInfo = @$c;
        my $fieldName = shift @fieldInfo;
        my $name = $fieldName;
        my $title = shift @fieldInfo;
        my $type = shift @fieldInfo;
        my $size = shift @fieldInfo;
        my $tooltip = shift @fieldInfo;
        my $attributes = shift @fieldInfo;

        my $field = $meta->get( "FIELD", $fieldName );
        my $value = $field->{"value"};
        if( ! defined( $value ) && $attributes =~ /S/ ) {
            # Allow initialisation based on a preference
            $value = $this->prefs()->getPreferencesValue($fieldName);
        }
        if( !defined( $value ) && $type !~ /^checkbox/ && $getValuesFromFormTopic ) {
            my $tmp = $fieldInfo[0];
            if( defined( $tmp )) {
                $value = $this->{session}->handleCommonTags( $tmp,
                                                             $web, $topic );
            }
        }
        $value = "" unless defined $value;  # allow "0" values
        my $extra = "";

        $tooltip =~ s/&/&amp\;/g;
        $tooltip =~ s/"/&quot\;/g;
        $tooltip =~ s/</&lt\;/g;
        $tooltip =~ s/>/&gt\;/g;

        my $output = $this->{session}->{plugins}->renderFormFieldForEditHandler( $name, $type, $size, $value, $attributes, \@fieldInfo );
        if( $output ) {
            $value = $output;
        } elsif( $type eq "text" ) {
            $value =~ s/&/&amp\;/go;
            $value =~ s/"/&quot\;/go; # Make sure double quote don't kill us
            $value =~ s/</&lt\;/go;
            $value =~ s/>/&gt\;/go;
            $value = "<input class=\"twikiEditFormTextField\" type=\"text\" name=\"$name\" size=\"$size\" value=\"$value\" />";
        } elsif( $type eq "label" ) {
            my $escaped = $value;
            $escaped =~ s/&/&amp\;/go;
            $escaped =~ s/"/&quot\;/go; # Make sure double quote don't kill us
            $escaped =~ s/</&lt\;/go;
            $escaped =~ s/>/&gt\;/go;
            $value = "<input class=\"twikiEditFormLabelField\" type=\"hidden\" name=\"$name\" value=\"$escaped\" />$value";
        } elsif( $type eq "textarea" ) {
            my $cols = 40;
            my $rows = 5;
            if( $size =~ /([0-9]+)x([0-9]+)/ ) {
               $cols = $1;
               $rows = $2;
            }
            $value =~ s/&/&amp\;/go;
            $value =~ s/"/&quot\;/go; # Make sure double quote don't kill us
            $value =~ s/</&lt\;/go;
            $value =~ s/>/&gt\;/go;
            $value = "<textarea class=\"twikiEditFormTextAreaField\" cols=\"$cols\" rows=\"$rows\" name=\"$name\">$value</textarea>";
        } elsif( $type eq "select" ) {
            my $val = "";
            my $matched = "";
            my $defaultMarker = "%DEFAULTOPTION%";
            foreach my $item ( @fieldInfo ) {
                my $selected = $defaultMarker;
                if( $item eq $value ) {
                   $selected = ' selected="selected"';
                   $matched = $item;
                }
                $defaultMarker = "";
                $item =~ s/<nop/&lt\;nop/go;
                $val .= "   <option$selected>$item</option>";
            }
            if( ! $matched ) {
               $val =~ s/%DEFAULTOPTION%/ selected="selected"/go;
            } else {
               $val =~ s/%DEFAULTOPTION%//go;
            }
            $value = "<select name=\"$name\" size=\"$size\">$val</select>";
        } elsif( $type =~ "^checkbox" ) {
            if( $type eq "checkbox+buttons" ) {
                my $boxes = $#fieldInfo + 1;
                $extra = "<br />\n<input class=\"twikiEditFormCheckboxButton twikiCheckbox\" type=\"button\" value=\" Set \" onclick=\"checkAll(this, 2, $boxes, true)\" />&nbsp;\n" .
                         "<input class=\"twikiEditFormCheckboxButton twikiCheckbox\" type=\"button\" value=\"Clear\" onclick=\"checkAll(this, 1, $boxes, false)\" />\n";
            }

            my $val ="<table  cellspacing=\"0\" cellpadding=\"0\"><tr>";
            my $lines = 0;
            foreach my $item ( @fieldInfo ) {
                my $flag = "";
                my $expandedItem = $this->{session}->handleCommonTags
                  ( $item, $web, $topic );
                if( $value =~ /(^|,\s*)\Q$item\E(,|$)/ ) {
                    $flag = ' checked="checked"';
                }
                $val .= "\n<td><input class=\"twikiEditFormCheckboxField\" type=\"checkbox\" name=\"$name$item\"$flag />$expandedItem &nbsp;&nbsp;</td>";
                if( $size > 0 && ($lines % $size == $size - 1 ) ) {
                   $val .= "\n</tr><tr>";
                }
                $lines++;
            }
            $val =~ s/\n<\/tr><tr>$//;
            $value = "$val\n</tr></table>\n";
        } elsif( $type eq "radio" ) {
            my $val = "<table  cellspacing=\"0\" cellpadding=\"0\"><tr>";
            my $matched = "";
            my $defaultMarker = "%DEFAULTOPTION%";
            my $lines = 0;
            foreach my $item ( @fieldInfo ) {
                my $selected = $defaultMarker;
                my $expandedItem = $this->{session}->handleCommonTags
                  ( $item, $web, $topic );
                if( $item eq $value ) {
                   $selected = ' checked="checked"';
                   $matched = $item;
                }
                $defaultMarker = "";
                $val .= "\n<td><input class=\"twikiEditFormRadioField twikiRadioButton\" type=\"radio\" name=\"$name\" value=\"$item\" $selected />$expandedItem &nbsp;&nbsp;</td>";
                if( $size > 0 && ($lines % $size == $size - 1 ) ) {
                   $val .= "\n</tr><tr>";
                }
                $lines++;
            }
            if( ! $matched ) {
               $val =~ s/%DEFAULTOPTION%/ checked="checked"/go;
            } else {
               $val =~ s/%DEFAULTOPTION%//go;
            }
            $val =~ s/\n<\/tr><tr>$//;
            $value = "$val\n</tr></table>\n";
        } else {
            # Treat like test, make it reasonably long
#TODO: Sven thinks this should be an error condition - so users know about typo's, and don't loose data when the typo is fixed
            $value =~ s/&/&amp\;/go;
            $value =~ s/"/&quot\;/go; # Make sure double quote don't kill us
            $value =~ s/</&lt\;/go;
            $value =~ s/>/&gt\;/go;
            $value = "<input class=\"twikiEditFormError\" type=\"text\" name=\"$name\" size=\"80\" value=\"$value\" />";
        }
        $text .= "   <tr> " . $this->_link( $web, $title, $tooltip, "h", "right", "", $extra ) . "<td align=\"left\"> $value </td> </tr>\n";
    }
    $text .= "</table></div>\n";
    
    return $text;
}


=pod

---++ ObjectMethod fieldVars2Meta($webName, $query, $metaObject, $justOverride) -> $metaObject

Extract new values of form fields from a query.

Note that existing meta information for fields is removed unless $justOverride is true

=cut

sub fieldVars2Meta {
    my( $this, $webName, $query, $meta, $justOverride ) = @_;
    ASSERT(ref($this) eq "TWiki::Form") if DEBUG;
    ASSERT(ref($meta) eq "TWiki::Meta") if DEBUG;

    $meta->remove( "FIELD" ) if( ! $justOverride );

    #$this->{session}->writeDebug( "Form::fieldVars2Meta " . $query->query_string );

    my @fieldsInfo = ();
    my $form = $meta->get( "FORM" );
    if( $form ) {
        @fieldsInfo = $this->getFormDef( $webName, $form->{"name"} );
    }

   foreach my $fieldInfop ( @fieldsInfo ) {
       my @fieldInfo = @$fieldInfop;
       my $fieldName = shift @fieldInfo;
       my $title     = shift @fieldInfo;
       my $type      = shift @fieldInfo;
       my $size      = shift @fieldInfo;
       my $tooltip   = shift @fieldInfo;
       my $attributes = shift @fieldInfo;
       my $value     = $query->param( $fieldName );
       my $cvalue    = "";

       if( ! $value && $type =~ "^checkbox" ) {
          foreach my $name ( @fieldInfo ) {
             my $cleanName = $name;
             $cleanName =~ s/<nop>//g;
             $cvalue = $query->param( "$fieldName" . "$cleanName" );
             if( defined( $cvalue ) ) {
                 if( ! $value ) {
                     $value = "";
                 } else {
                     $value .= ", " if( $cvalue );
                 }
                 $value .= "$name" if( $cvalue );
             }
          }
       }

       if( defined( $value ) ) {
           $value = TWiki::decodeSpecialChars( $value );
       }

       # Have title and name stored so that topic can be viewed without reading in form definition
       $value = "" if( ! defined( $value ) && ! $justOverride );
       if( defined( $value ) ) {
           my $args =
             {
              name =>  $fieldName,
              title => $title,
              value => $value,
              attributes => $attributes,
             };
           $meta->put( "FIELD", $args );
       }
   }

   return $meta;
}


# =============================
=pod

---++ StaticMethod getFieldParams (  $meta  )

Not yet documented.

=cut

sub getFieldParams {
    my( $meta ) = @_;
    ASSERT(ref($meta) eq "TWiki::Meta") if DEBUG;

    my $params = "";

    my @fields = $meta->find( "FIELD" );
    foreach my $field ( @fields ) {
       my $args = $2;
       my $name  = $field->{"name"};
       my $value = $field->{"value"};
       #$this->{session}->writeDebug( "Form::getFieldParams " . $name . ", " . $value );
       $value = TWiki::decodeSpecialChars( $value );
       $value =~ s/&/&amp\;/go;
       $value =~ s/</&lt\;/go;
       $value =~ s/>/&gt\;/go;
       $params .= "<input type=\"hidden\" name=\"$name\" value=\"$value\" />\n";
    }
    return $params;

}

=pod

---++ ObjectMethod changeForm (  $theWeb, $theTopic )

Called by script to change the form for a topic

=cut

# SMELL: surely this should be in UI somewhere??

sub changeForm {
    my( $this, $theWeb, $theTopic ) = @_;
    ASSERT(ref($this) eq "TWiki::Form") if DEBUG;

    my $tmpl = $this->templates()->readTemplate( "changeform" );
    $tmpl = $this->{session}->handleCommonTags( $tmpl, $theWeb, $theTopic );
    $tmpl = $this->renderer()->getRenderedVersion( $tmpl, $theWeb, $theTopic );
    my $q = $this->{session}->{cgiQuery};
    my $text = $q->param( 'text' );
    $text = TWiki::encodeSpecialChars( $text );
    $tmpl =~ s/%TEXT%/$text/go;

    my $listForms = $this->prefs()->getPreferencesValue( "WEBFORMS", "$theWeb" );
    $listForms =~ s/^\s*//go;
    $listForms =~ s/\s*$//go;
    my @forms = split( /\s*,\s*/, $listForms );
    unshift @forms, "";
    my( $metat, $tmp ) =
      $this->store()->readTopic( $this->{session}->{user}, $theWeb, $theTopic, undef );
    my $formName = $q->param( 'formtemplate' ) || "";
    if( ! $formName ) {
        my $form = $metat->get( "FORM" );
        $formName = $form->{"name"} if $form;
    }
    $formName = "" if( !$formName || $formName eq "none" );

    my $formList = "";
    foreach my $form ( @forms ) {
       my $selected = ( $form eq $formName ) ? 'checked="checked"' : "";
       $formList .= "\n<br />" if( $formList );
       my $show = $form ? $form : "&lt;none&gt;";
       my $value = $form ? $form : "none";
       $formList .= "<input type=\"radio\" name=\"formtemplate\" value=\"$value\" $selected />&nbsp;$show";
    }
    $tmpl =~ s/%FORMLIST%/$formList/go;

    my $parent = $q->param( 'topicparent' ) || "";
    $tmpl =~ s/%TOPICPARENT%/$parent/go;

    $tmpl =~ s|</*nop/*>||goi;

    $this->{session}->writeCompletePage( $tmpl );
}

#Upgrade old style category table item
sub _upgradeCategoryItem {
    my ( $catitems, $ctext ) = @_;
    my $catname = "";
    my $scatname = "";
    my $catmodifier = "";
    my $catvalue = "";
    my @cmd = split( /\|/, $catitems );
    my $src = "";
    my $len = @cmd;
    if( $len < "2" ) {
        # FIXME
        return ( $catname, $catmodifier, $catvalue )
    }
    my $svalue = "";

    my $i;
    my $itemsPerLine;

    # check for CategoryName=CategoryValue parameter
    my $paramCmd = "";
    my $cvalue = ""; # was$query->param( $cmd[1] );
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

    if( $cmd[0] eq "select" || $cmd[0] eq "radio") {
        $catname = $cmd[1];
        $scatname = $catname;
        #$scatname =~ s/[^a-zA-Z0-9]//g;
        my $size = $cmd[2];
        for( $i = 3; $i < $len; $i++ ) {
            my $value = $cmd[$i];
            my $svalue = $value;
            if( $src =~ /$value/ ) {
               $catvalue = "$svalue";
            }
        }

    } elsif( $cmd[0] eq "checkbox" ) {
        $catname = $cmd[1];
        $scatname = $catname;
        #$scatname =~ s/[^a-zA-Z0-9]//g;
        if( $cmd[2] eq "true" || $cmd[2] eq "1" ) {
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

    } elsif( $cmd[0] eq "text" ) {
        $catname = $cmd[1];
        $scatname = $catname;
        #$scatname =~ s/[^a-zA-Z0-9]//g;
        $src =~ /<!---->(.*)<!---->/;
        if( $1 ) {
            $src = $1;
        } else {
            $src = "";
        }
        $catvalue = $src;
    }

    return ( $catname, $catmodifier, $catvalue )
}

=pod

---++ ObjectMethod upgradeCategoryTable (  $web, $topic, $meta, $text  ) -> $text

Upgrade old style category table

=cut

sub upgradeCategoryTable {
    my( $this, $web, $topic, $meta, $text ) = @_;
    ASSERT(ref($this) eq "TWiki::Form") if DEBUG;

    my $icat = $this->templates()->readTemplate( "twikicatitems" );

    if( $icat ) {
        my @items = ();
        # extract category section and build category form elements
        my( $before, $ctext, $after) = split( /<!--TWikiCat-->/, $text );
        # cut TWikiCat part
        $text = $before || "";
        $text .= $after if( $after );
        $ctext = "" if( ! $ctext );

        my $ttext = "";
        foreach( split( /\n/, $icat ) ) {
            my( $catname, $catmod, $catvalue ) = _upgradeCategoryItem( $_, $ctext );
            #$this->{session}->writeDebug( "Form: name, mod, value: $catname, $catmod, $catvalue" );
            if( $catname ) {
                push @items, ( [$catname, $catmod, $catvalue] );
            }
        }
        my $listForms = $this->prefs()->getPreferencesValue( "WEBFORMS", "$web" );
        $listForms =~ s/^\s*//go;
        $listForms =~ s/\s*$//go;
        my @formTemplates = split( /\s*,\s*/, $listForms );
        my $defaultFormTemplate = "";
        $defaultFormTemplate = $formTemplates[0] if ( @formTemplates );

        if( ! $defaultFormTemplate ) {
            $this->{session}->writeWarning( "Form: can't get form definition to convert category table " .
                                  " for topic $web.$topic" );
            foreach my $oldCat ( @items ) {
                my $name = $oldCat->[0];
                my $value = $oldCat->[2];
                $meta->put( "FORM", { name => "" } );
                $meta->put( "FIELD",
                            { name => $name,
                              title => $name,
                              value => $value
                            } );
            }
            return;
        }

        my @fieldsInfo = $this->getFormDef( $web, $defaultFormTemplate );
        $meta->put( "FORM", { name => $defaultFormTemplate } );

        foreach my $catInfop ( @fieldsInfo ) {
           my @catInfo = @$catInfop;
           my $fieldName = shift @catInfo;
           my $title = shift @catInfo;
           my $value = "";
           foreach my $oldCatP ( @items ) {
               my @oldCat = @$oldCatP;
               if( _cleanField( $oldCat[0] ) eq $fieldName ) {
                  $value = $oldCat[2];
                  last;
               }
           }
           $meta->put( "FIELD",
                     {
                      name => $fieldName,
                      title => $title,
                      value => $value,
                     } );
        }

    } else {
        $this->{session}->writeWarning( "Form: get find category template twikicatitems for Web $web" );
    }
    return $text;
}

1;
