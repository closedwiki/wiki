package TWiki::Classification;

use strict;

# ============================
# Get definition from topic (includes categories)
sub getClassificationDefinition
{
    my( $text ) = @_;
    
    my @categories = ();
    
    my $inBlock = 0;
    
    foreach( split( /\n/, $text ) ) {
        if( /^\s*\|.*ClassificationDefinition[^|]*\|/ ) {
            $inBlock = 1;
        } else {
	    if( /^\s*\|\s*([^\s]*)\s*\|/ ) {
		my $category = $1;
		if( $inBlock ) {
		    push @categories, $category;
		}
	    } else {
		$inBlock = 0;
	    }
	}
    }
    
    return @categories;
}


# ============================
# Get definition from topic
sub getCategoryDefinition
{
    my( $text ) = @_;
    
    my @defn = ();
    
    my $inBlock = 0;
    
    foreach( split( /\n/, $text ) ) {
        if( /^\s*\|.*CategoryDefinition[^|]*\|/ ) {
            $inBlock = 1;
        } else {
            if( /^\s*\|\s*([^|]*)\s*\|/ ) {
                my $item = $1;
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
# Get array of category information, given classification
sub getCategoriesInfo
{
    my( $webName, $classification ) = @_;
    
    my @categories = ();    
   
    # Read topic that defines the classifcation
    if( &TWiki::Store::topicExists( $webName, $classification ) ) {
        my( $text, @meta ) = &TWiki::Store::readWebTopicNew( $webName, $classification );
        @categories = getClassificationDefinition( $text );
    } else {
        # FIXME - do what if there is an error?
    }
    
    my @categoriesInfo = ();
        
        
    # Get each category definition
    foreach my $category ( @categories ) {
        if( &TWiki::Store::topicExists( $webName, $category ) ) {
            my( $text, @meta ) = &TWiki::Store::readWebTopicNew( $webName, $category );
            my @categoryDefn = getCategoryDefinition( $text );
            push @categoriesInfo, [ ( $category, "select", @categoryDefn ) ];
        } else {
            push @categoriesInfo, [ ( $category, "text" ) ];      
        }
    }

    return @categoriesInfo;
}

sub link
{
    my( $name, $heading, $align, $span ) = @_;
    
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
    
    my $html = "<$cell$span$align><a target=\"$name\" " .
               "onClick=\"return launchWindow('%WEB%','$name')\" " .
               "title=\"Click to see details in separate window\" " .
               "href=\"%SCRIPTURLPATH%/view%SCRIPTSUFFIX%/%WEB%/$name\">$name</a></$cell>";
    return $html;
}


# ============================
# Render category information - only support edit ($for="edit") at present
sub renderCategoryInfo
{
    my( $for, $classification, $metap, @categoriesInfo ) = @_;
    
    my $text = "<table border=\"1\" cellspacing=\"0\" cellpadding=\"0\">\n   <tr>" . 
               &link( $classification, "h", "", 2 ) . "</tr>\n";
    my @meta = @$metap;
    
    foreach my $c ( @categoriesInfo ) {
        my @categoryInfo = @$c;
        my $category = shift @categoryInfo;
        my $name = "$category" . "Cat";
        my $type = shift @categoryInfo;
            
        my @ident = ( "name" => $category );
        my( $oldargsr, @meta ) = &TWiki::Store::metaExtract( "CATEGORY", \@ident, "", @meta );
        my @oldargs = @$oldargsr;
        my %args = @oldargs;
        my $value = $args{"value"} || "";
        
        if( $for eq "edit" ) {
            if( $type eq "text" ) {
                $value = "<input name=\"$name\" type=\"input\" value=\"$value\">";
            } elsif( $type eq "select" ) {
                my $val = "";
                my $matched = "";
                my $defaultMarker = "%DEFAULTOPTION%";
                foreach my $item ( @categoryInfo ) {
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
                $value = "<select name=\"$name\">$val</select>";
            }
        }
        $text .= "   <tr> " . &link( $category, "h", "right" ) . "<td align=\"left\"> $value </td> </tr>\n";
    }
    $text .= "</table>\n";
    
    return $text;
}


# =============================
sub getCategoryInfoFromMeta
{
    my( $webName, @meta ) = @_;
    
    my @categoriesInfo = ();
    
    my $oldargsr;
    ( $oldargsr, @meta ) = &TWiki::Store::metaExtract( "CLASSIFICATION", "", "", @meta );
    my @oldargs = @$oldargsr;
    if( @oldargs ) {
       my %args = @oldargs;
       my $classification = $args{"name"};
       @categoriesInfo = getCategoriesInfo( $webName, $classification );
    }
    
    return @categoriesInfo;
}


# =============================
# Meta to hidden form params
sub catVars2Meta
{
   my( $webName, $query, @meta ) = @_;
   
   my @categoriesInfo = getCategoryInfoFromMeta( $webName, @meta );
   my $order = 0; # Used to ensure order of categories
   foreach my $catInfop ( @categoriesInfo ) {
       my @catInfo = @$catInfop;
       my $category = shift @catInfo;
       my $value = $query->param( $category . "Cat" );
       my @args = ( "order" => sprintf( "%02d", $order ),
                    "name" => $category,
                    "value" => $value );
       @meta = &TWiki::Store::metaUpdate( "CATEGORY", \@args, "name", @meta);
       $order++;
   }
   
   return @meta;
}


# =============================
sub categoryParams
{
    my( @meta ) = @_;
    
    my $params = "";
    
    foreach my $metaItem( @meta ) {
       if( $metaItem =~ /(%META:CATEGORY\{)([^\}]*)(}%)/ ) {
           my $args = $2;
           my $name  = &TWiki::extractNameValuePair( $args, "name" );
           my $value = &TWiki::extractNameValuePair( $args, "value" );
           $name .= "Cat";
           $params .= "<input type=\"hidden\" name=\"$name\" value=\"$value\">\n";
       }
    }
    
    return $params;

}

1;
