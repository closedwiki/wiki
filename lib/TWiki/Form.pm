package TWiki::Form;

use strict;


# ============================
# Get definition from supplied topic text
sub getFormDefinition
{
    my( $text ) = @_;
    
    my @fields = ();
    
    my $inBlock = 0;
    # | *Name:* | *Type:* | *Size:* | *Value:*  | *Tooltip message:* |
    foreach( split( /\n/, $text ) ) {
        if( /^\s*\|.*Name[^|]*\|.*Type[^|]*\|.*Size[^|]*\|/ ) {
            $inBlock = 1;
        } else {
            # Only insist on first field being present FIXME - use oops page instead?
	    if( $inBlock && s/^\s*\|//o ) {
                my( $title, $type, $size, $vals, $tooltip ) = split( /\|/ );
                $title =~ s/^\s*//go;
                $title =~ s/\s*$//go;
                my $name = _cleanField( $title );
                $type = lc $type;
                $type =~ s/[^a-z+]//go;
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
                $vals =~ s/"//go; # " would break parsing off META variables
                $tooltip =~ s/^\s*//go;
                $tooltip =~ s/^\s*//go;
                # FIXME object if too short
                push @fields, [ $name, $title, $type, $size, $vals, $tooltip ];
	    } else {
		$inBlock = 0;
	    }
	}
    }
    
    return @fields;
}


# ============================
sub _cleanField
{
   my( $text ) = @_;
   $text = "" if( ! $text );
   $text =~ s/[^A-Za-z0-9_\.]//go; # Need do for web.topic
   return $text;
}


# ============================
# Possible field values for select, checkbox, radio from supplied topic text
sub getPossibleFieldValues
{
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


# ============================
# Get array of field definition, given form name
sub getFormDef
{
    my( $webName, $form ) = @_;
    
    my @fieldDefs = ();    
   
    # Read topic that defines the form
    if( &TWiki::Store::topicExists( $webName, $form ) ) {
        my( $meta, $text ) = &TWiki::Store::readTopic( $webName, $form );
        @fieldDefs = getFormDefinition( $text );
    } else {
        # FIXME - do what if there is an error?
    }
    
    my @fieldsInfo = ();
        
    # Get each field definition
    foreach my $fieldDefP ( @fieldDefs ) {
        my @fieldDef = @$fieldDefP;
        my( $name, $title, $type, $size, $posValuesS, $tooltip ) = @fieldDef;
        my @posValues = ();
        if( $posValuesS ) {
           @posValues = split( /,\s*/, $posValuesS );
        }

        if( ( ! @posValues ) && &TWiki::Store::topicExists( $webName, $name ) ) {
            my( $meta, $text ) = &TWiki::Store::readTopic( $webName, $name );
            @posValues = getPossibleFieldValues( $text );
            if( ! $type ) {
                $type = "select";  #FIXME keep?
            }
        } else {
            # FIXME no list matters for some types
        }
        push @fieldsInfo, [ ( $name, $title, $type, $size, $tooltip, @posValues ) ];
    }

    return @fieldsInfo;
}


# ============================
sub link
{
    my( $web, $name, $tooltip, $heading, $align, $span, $extra ) = @_;
    
    $name =~ s/[\[\]]//go;
    
    my $cell = "td";
    if( $heading ) {
       $cell = "th bgcolor=\"#99CCCC\"";
    }
    
    if( !$align ) {
       $align = "";
    } else {
       $align = " align=\"$align\"";
    }
    
    if( $span ) {
       $span = " colspan=$span";
    } else {
       $span = "";
    }
    
    my $link = "$name";
    
    if( &TWiki::Store::topicExists( $web, $name ) ) {
        if( ! $tooltip ) {
            $tooltip = "Click to see details in separate window";
        }
        $link =  "<a target=\"$name\" " .
                 "onClick=\"return launchWindow('$web','$name')\" " .
                 "title=\"$tooltip\" " .
                 "href=\"$TWiki::scriptUrlPath/view$TWiki::scriptSuffix/$web/$name\">$name</a>";
    } elsif ( $tooltip ) {
        $link = "<span title=\"$tooltip\">$name</span>";
    }

    my $html = "<$cell$span$align>$link $extra</$cell>";
    return $html;
}

sub chooseFormButton
{
    my( $text ) = @_;
    
    return "<INPUT type=\"submit\" STYLE=\"font-size:8pt; border-width:1px; " .
           "margin:2px\" name=\"submitChangeForm\" value=\" &nbsp; $text &nbsp; \">";
}


# ============================
# Render form information 
sub renderForEdit
{
    my( $web, $form, $meta, @fieldsInfo ) = @_;
    
    my $chooseForm = "";   
    if( TWiki::Prefs::getPreferencesValue( "WEBFORMS", "$web" ) ) {
        $chooseForm = chooseFormButton( "Change" );
    }
    
    # FIXME could do with some of this being in template
    my $text = "<table border=\"1\" cellspacing=\"0\" cellpadding=\"0\">\n   <tr>" . 
               &link( $web, $form, "", "h", "", 2, $chooseForm ) . "</tr>\n";
    
    foreach my $c ( @fieldsInfo ) {
        my @fieldInfo = @$c;
        my $fieldName = shift @fieldInfo;
        my $name = $fieldName . "FLD";
        my $title = shift @fieldInfo;
        my $type = shift @fieldInfo;
        my $size = shift @fieldInfo;
        my $tooltip = shift @fieldInfo;

        my %field = $meta->findOne( "FIELD", $fieldName );
        my $value = $field{"value"} || "";
        my $extra = "";
        
        # Special processing for UseForm
        if( ! $value && $fieldName eq "UseForm" ) {
           $value = $fieldInfo[1];
        }
                
        if( $type eq "text" ) {
            $value = "<input name=\"$name\" size=\"$size\" type=\"input\" value=\"$value\">";
        } elsif( $type eq "textarea" ) {
            my $cols = 40;
            my $rows = 5;
            if( $size =~ /(.*)x(.*)/ ) {
               $cols = $1;
               $rows = $2;
            }
            $value = "<textarea cols=\"$cols\" rows=\"$rows\" name=\"$name\">$value</textarea>";
        } elsif( $type eq "select" ) {
            my $val = "";
            my $matched = "";
            my $defaultMarker = "%DEFAULTOPTION%";
            foreach my $item ( @fieldInfo ) {
                my $selected = $defaultMarker;
                if( $item eq $value ) {
                   $selected = " selected";
                   $matched = $item;
                }
                $defaultMarker = "";
                $val .= "   <option name=\"$item\"$selected>$item</option>";
            }
            if( ! $matched ) {
               $val =~ s/%DEFAULTOPTION%/ selected/go;
            } else {
               $val =~ s/%DEFAULTOPTION%//go;
            }
            $value = "<select name=\"$name\" size=\"$size\">$val</select>";
        } elsif( $type =~ "^checkbox" ) {
            if( $type eq "checkbox+buttons" ) {
                my $boxes = $#fieldInfo + 1;
                $extra = "<br>\n<input type=\"button\" value=\" Set \" onClick=\"checkAll(this, 2, $boxes, true)\">&nbsp;\n" .
                         "<input type=\"button\" value=\"Clear\" onClick=\"checkAll(this, 1, $boxes, false)\">\n";
            }

            my $val ="<table  cellspacing=\"0\" cellpadding=\"0\"><tr>";
            my $lines = 0;
            foreach my $item ( @fieldInfo ) {
                my $flag = "";
                if( $value =~ /(^|,\s*)$item(,|$)/ ) {
                    $flag = "checked";
                }
                $val .= "\n<td><input type=\"checkbox\" name=\"$name$item\" $flag>$item &nbsp;&nbsp;</td>";
                if( $size > 0 && ($lines % $size == $size - 1 ) ) {
                   $val .= "\n</tr><tr>";
                }
                $lines++;
            }
            $value = "$val\n</tr></table>\n";
        } elsif( $type eq "radio" ) {
            my $val = "<table  cellspacing=\"0\" cellpadding=\"0\"><tr>";
            my $matched = "";
            my $defaultMarker = "%DEFAULTOPTION%";
            my $lines = 0;
            foreach my $item ( @fieldInfo ) {
                my $selected = $defaultMarker;
                if( $item eq $value ) {
                   $selected = " checked";
                   $matched = $item;
                }
                $defaultMarker = "";
                $val .= "\n<td><input type=\"radio\" name=\"$name\" value=\"$item\" $selected>$item &nbsp;&nbsp;</td>";
                if( $size > 0 && ($lines % $size == $size - 1 ) ) {
                   $val .= "\n</tr><tr>";
                }
                $lines++;
            }
            if( ! $matched ) {
               $val =~ s/%DEFAULTOPTION%/ checked/go;
            } else {
               $val =~ s/%DEFAULTOPTION%//go;
            }
            $value = "$val\n</tr></table>\n";
        }
        $text .= "   <tr> " . &link( $web, $title, $tooltip, "h", "right", "", $extra ) . "<td align=\"left\"> $value </td> </tr>\n";
    }
    $text .= "</table>\n";
    
    return $text;
}


# =============================
sub getFormInfoFromMeta
{
    my( $webName, $meta ) = @_;
    
    my @fieldsInfo = ();
    
    my %form = $meta->findOne( "FORM" );
    if( %form ) {
       @fieldsInfo = getFormDef( $webName, $form{"name"} );
    }
    
    return @fieldsInfo;
}


# =============================
# Meta to hidden form params
# Note that existing meta information for fields is removed
sub fieldVars2Meta
{
   my( $webName, $query, $meta ) = @_;
   
   $meta->remove( "FIELD" );
   my @fieldsInfo = getFormInfoFromMeta( $webName, $meta );
   foreach my $fieldInfop ( @fieldsInfo ) {
       my @fieldInfo = @$fieldInfop;
       my $fieldName = shift @fieldInfo;
       my $title     = shift @fieldInfo;
       my $type      = shift @fieldInfo;
       my $size      = shift @fieldInfo;
       my $value     = "";
       $value = $query->param( $fieldName . "FLD" );
       
       if( $fieldName eq "UseForm" ) {
          if( lc $value ne "yes" ) {
              $meta->remove( "FORM" );
              $meta->remove( "FIELD" );
              return $meta;
          }
       }
       
       if( ! $value && $type =~ "^checkbox" ) {
          foreach my $name ( @fieldInfo ) {
             if( $query->param( "$fieldName" . "FLD$name" ) ) {
                 $value .= ", " if( $value );
                 $value .= "$name";
             }
          }
       }
       
       $value = TWiki::Meta::restoreValue( $value );
              
       # Have title and name stored so that topic can be view without reading in form definition
       my @args = ( "name" =>  $fieldName,
                    "title" => $title,
                    "value" => $value );
                    
       $meta->put( "FIELD", @args );
   }
   
   return $meta;
}


# =============================
sub getFieldParams
{
    my( $meta ) = @_;
    
    my $params = "";
    
    my @fields = $meta->find( "FIELD" );
    foreach my $field ( @fields ) {
       my $args = $2;
       my $name  = $field->{"name"};
       my $value = $field->{"value"};
       $value = TWiki::Meta::cleanValue( $value );
       $name .= "FLD";
       $params .= "<input type=\"hidden\" name=\"$name\" value=\"$value\">\n";
    }
    
    return $params;

}

# ============================
# load old style category table item
sub upgradeCategoryItem
{
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
            $svalue =~ s/[^a-zA-Z0-9]//g;
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
            $svalue =~ s/[^a-zA-Z0-9]//g;
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


# ============================
# load old style category table
sub upgradeCategoryTable
{
    my( $web, $topic, $meta, $text ) = @_;
    
    my $icat = &TWiki::Store::readTemplate( "twikicatitems" );
    
    if( $icat ) {
        my @items = ();
        
        # extract category section and build category form elements
        my( $before, $ctext, $after) = split( /<!--TWikiCat-->/, $text);
        # cut TWikiCat part
        $text = $before;
        if( ! $ctext ) { $ctext = ""; }
        if( $after ) {
            $text .= $after;
        }

        my $ttext = "";
        foreach( split( /\n/, $icat ) ) {
            my( $catname, $catmod, $catvalue ) = upgradeCategoryItem( $_, $ctext );
            #TWiki::writeDebug( "Form: name, mod, value: $catname, $catmod, $catvalue" );
            if( $catname && $catname ne "UseCategory" ) {
                push @items, ( [$catname, $catmod, $catvalue] );
            }
        }
        
        my @formTemplates = split( /,\s*/, TWiki::Prefs::getPreferencesValue( "WEBFORMS", "$web" ) );
        # FIXME - deal with none
        
        if( ! @formTemplates ) {
            &TWiki::writeWarning( "Form: can't get form definition to convert category table " .
                                  " for topic $web.$topic" );
                                  
            foreach my $oldCat ( @items ) {
                my $name = $oldCat->[0];
                my $value = $oldCat->[2];
                $meta->put( "FORM", ( "name" => "" ) );
                $meta->put( "FIELD", ( "name" => $name, "title" => $name, "value" => $value ) );
            }
            
            return;
        }
        
        my $defaultFormTemplate = $formTemplates[0];
        my @fieldsInfo = getFormDef( $web, $defaultFormTemplate );
        $meta->put( "FORM", ( name => $defaultFormTemplate ) );
        
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
           my @args = ( "name" => $fieldName,
                        "title" => $title,
                        "value" => $value );
           $meta->put( "FIELD", @args );
        }

    }
    
    
    return $text;
}
  
1;
