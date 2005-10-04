#
# TWiki WikiClone ($wikiversion has version info)
#
# Copyright (C) 2002-2004 Peter Thoeny, Peter@Thoeny.com
#
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

# Still do to:
# "format", "header": Would allow the table to be defined without
# template. What if there is text or template that conflicts?
# Note that vanilla twiki shows the "Change form..." button in update
# mode, albeit it has no effect.
# Support the $quot, etc., non-expanded values in table initialization.


# =========================
package TWiki::Plugins::EditTablerowPlugin;

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $debug
        $query $renderingWeb
        $preSp %params @format @formatExpanded
        $prefsInitialized $prefCHANGEROWS $prefEDITBUTTON $prefEDITLINK
    );

$VERSION = '$Rev$';
$prefsInitialized  = 0;

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1 ) {
        &TWiki::Func::writeWarning( "Version mismatch between EditTablerowPlugin and Plugins.pm" );
        return 0;
    }

    $query = &TWiki::Func::getCgiQuery();
    if( ! $query ) {
        return 0;
    }

    # Get plugin debug flag
    $debug = &TWiki::Func::getPreferencesFlag( "EDITTABLEROWPLUGIN_DEBUG" );

    $prefsInitialized = 0;
    $renderingWeb = $web;

    # Plugin correctly initialized
    &TWiki::Func::writeDebug( "- TWiki::Plugins::EditTablerowPlugin::initPlugin( $web.$topic ) is OK" ) if $debug;

    return 1;
}

# =========================
sub extractParams
{
    my( $theArgs, $theHashRef ) = @_;

    my $tmp = &TWiki::Func::extractNameValuePair( $theArgs, "header" );
    $$theHashRef{"header"} = $tmp if( $tmp );

    $tmp = &TWiki::Func::extractNameValuePair( $theArgs, "footer" );
    $$theHashRef{"footer"} = $tmp if( $tmp );

    $tmp = &TWiki::Func::extractNameValuePair( $theArgs, "headerislabel" );
    $$theHashRef{"headerislabel"} = $tmp if( $tmp );

    $tmp = &TWiki::Func::extractNameValuePair( $theArgs, "format" );
    $tmp =~ s/^\s*\|*\s*//o;
    $tmp =~ s/\s*\|*\s*$//o;
    $$theHashRef{"format"} = $tmp if( $tmp );

    $tmp = &TWiki::Func::extractNameValuePair( $theArgs, "template" );
    $$theHashRef{"template"} = $tmp if( $tmp );

    $tmp = &TWiki::Func::extractNameValuePair( $theArgs, "changerows" );
    $$theHashRef{"changerows"} = $tmp if( $tmp );

    $tmp = &TWiki::Func::extractNameValuePair( $theArgs, "show" );
    $$theHashRef{"showtable"} = $tmp if( $tmp );

    $tmp = &TWiki::Func::extractNameValuePair( $theArgs, "helptopic" );
    $$theHashRef{"helptopic"} = $tmp if( $tmp );

    $tmp = &TWiki::Func::extractNameValuePair( $theArgs, "editbutton" );
    $$theHashRef{"editbutton"} = $tmp if( $tmp );

    $tmp = &TWiki::Func::extractNameValuePair( $theArgs, "headeronempty" );
    $$theHashRef{"showHeaderOnEmpty"} = $tmp if( $tmp );

    return;
}

# =========================
sub commonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    &TWiki::Func::writeDebug( "- EditTablerowPlugin::commonTagsHandler( $_[2].$_[1] )" ) if $debug;

    return unless $_[0] =~ /%EDITTABLEROW{(.*)}%/os;

    unless( $prefsInitialized ) {
        $prefCHANGEROWS           = &TWiki::Func::getPreferencesValue("CHANGEROWS") ||
                    &TWiki::Func::getPreferencesValue("EDITTABLEROWPLUGIN_CHANGEROWS") || "on";
        $prefEDITBUTTON           = &TWiki::Func::getPreferencesValue("EDITBUTTON") ||
                    &TWiki::Func::getPreferencesValue("EDITTABLEROWPLUGIN_EDITBUTTON") || "Edit table";
        $prefEDITLINK             = &TWiki::Func::getPreferencesValue("EDITLINK") ||
                    &TWiki::Func::getPreferencesValue("EDITTABLEROWPLUGIN_EDITLINK");
        $prefsInitialized = 1;
    }

    my $theWeb = $_[2];
    my $theTopic = $_[1];
    my $result = "";
    my $tableNr = 0;
    my $rowNr = 0;
    my $enableForm = 0;
    my $insideTable = 0;
    my $cgiRows = -1;

    # appended stuff is a hack to handle EDITTABLE correctly if at end
    foreach( split( /\r?\n/, "$_[0]\n<nop>\n" ) ) {
        if( s/(\s*)%EDITTABLEROW{(.*)}%/&handleEditTableTag( $theWeb, $theTopic, $1, $2 )/geo ) {
            $enableForm = 1;
            $tableNr += 1;
        }
        if( $enableForm ) {
            if( /^(\s*)\|.*\|\s*$/ ) {
                # found table row
	        # Here we could handle the first row if something needs to be done
                $insideTable = 1;
                $rowNr++;
                s/^(\s*)\|(\s*)(.*?)(\s*)\|(.*)/&handleTableRow( $1, $2, $3, $4, $5, $tableNr, $rowNr )/eo;

            } elsif( $insideTable ) {
                # end of table
                $insideTable = 0;
		$rowNr++;
                $result .= handleTableEnd( $theWeb, $tableNr, $rowNr );
                $enableForm = 0;
                $rowNr = 0;
            }
            if( /^\s*$/ ) {      # empty line
                if( $enableForm ) {
		  # empty %EDITTABLEROW%, so create a default table
		  if ( $params{"showHeaderOnEmpty"} ) {
		    $result .= handleTableStart( $theWeb, $theTopic, $tableNr );
		  }
		  $result .= handleTableEnd( $theWeb, $tableNr, 0 );
		  $enableForm = 0;
		  $rowNr = 0;
                }
                $rowNr = 0;
            }
        }
        $result .= "$_\n";
    }
    $result =~ s|\n?<nop>\n$||o; # clean up hack that handles EDITTABLE correctly if at end
    
    $_[0] = $result;
}

# =========================
sub handleEditTableTag
{
    my( $theWeb, $theTopic, $thePreSpace, $theArgs ) = @_;

    $preSp = $thePreSpace || "";
    %params = (
        "header"        => "",
        "footer"        => "",
        "headerislabel" => "1",
        "format"        => "",
        "changerows"    => $prefCHANGEROWS,
        "helptopic"     => "",
        "editbutton"    => "",
        "editlink"      => "",
	"showHeaderOnEmpty" => "",
    );

    extractParams( $theArgs, \%params );
    # Name is name based upon a unique time-stamp. This is based to the 
    # editTable.tmpl and is transparent to the user. This removes the 
    # constraint of unique first columns.
    my $sortName = $rowNr;

    if ( $copyElement ) { #Give unique table element keys for copied elements
      $sortName = time;
    }


    $params{"header"} = "" if( $params{"header"} =~ /^(off|no)$/oi );
    $params{"header"} =~ s/^\s*\|//o;
    $params{"header"} =~ s/\|\s*$//o;
    $params{"headerislabel"} = "" if( $params{"headerislabel"} =~ /^(off|no)$/oi );
    $params{"footer"} = "" if( $params{"footer"} =~ /^(off|no)$/oi );
    $params{"footer"} =~ s/^\s*\|//o;
    $params{"footer"} =~ s/\|\s*$//o;
    $params{"changerows"} = "" if( $params{"changerows"} =~ /^(off|no)$/oi );
    $params{"showtable"}  = "" if( $params{"showtable"}  =~ /^(off|no)$/oi );
    $params{"showHeaderOnEmpty"}  = "" if( $params{"showHeaderOnEmpty"}  =~ /^(off|no)$/oi );

    # FIXME: No handling yet of footer

    return "$preSp<nop>";
}

# =========================
sub handleTableStart
{
    my( $theWeb, $theTopic, $theTableNr ) = @_;

    my @fieldDefs = &TWiki::Form::getFormDef( $theWeb, $params{"template"} );
    if( ! @fieldDefs ) {
      return "<font color=red>No Table template found: $theWeb . $params{'template'}</font>";
    } else {
      my $tableHeader .= renderForDisplay( @fieldDefs );
      #$tableHeader =~ s/^(\s*)\|(.*)/&processTR($1,$2)/eo;
      $tableHeader .= "\n";
      return $tableHeader;
    }

}

# =========================
sub renderForDisplay
{

	my ( @fieldDefs ) = @_;
	my $tableHeader = "| ";

    # Get each field definition
    # | *Name:* | *Type:* | *Size:* | *Value:*  | *Tooltip message:* |
	foreach my $fieldDefP ( @fieldDefs ) {
        my @fieldDef = @$fieldDefP;
        my( $name, $title, $type, $size, $posValuesS, $tooltip ) = @fieldDef;
		$tableHeader .= "*$title* | ";
	}

	return $tableHeader;

}

# =========================
sub handleTableEnd
{
    my( $theWeb, $theTableNr, $theRowNr ) = @_;

    $header = "";
    $button = "";

    my $value = $prefEDITBUTTON;
    my $img = "";
    if( $value =~ s/(.+),\s*(.+)/$1/o ) {
      $img = $2;
      $img =~ s|%ATTACHURL%|%PUBURL%/$installWeb/EditTablerowPlugin|o;
      $img =~ s|%WEB%|$installWeb|o;
    }

    if( $img ) {
      $button = "<input type=\"image\" src=\"$img\" alt=\"$value\" />";
    } else {
      $button = "<input type=\"submit\" value=\"$value\" />";
    }


    if ( $params{"changerows"} ) {
      $header .= "<form action=\"%SCRIPTURLPATH%/editTableRow%SCRIPTSUFFIX%/%WEB%/$topic\">
<input type=\"hidden\" name=\"template\" value=\"$params{'template'}\">
<input type=\"hidden\" name=\"helptopic\" value=\"$params{'helptopic'}\">
<input type=\"hidden\" name=\"sec\" value=\"0\">
<input type=\"hidden\" name=\"tablename\" value=\"$theTableNr\">\n" .
  (($params{'showtable'} && $theRowNr)?"<input type=\"hidden\" name=\"showtable\" value=\"on\">\n"
          :"<input type=\"hidden\" name=\"showtable\" value=\"off\">\n") .
    "$button</form>";
    }

    return "$header<br>\n";

}

# =========================
sub handleTableRow
{
    my ( $thePre, $r1, $title, $r2, $tail, $theTableNr, $theRowNr ) = @_;

    $thePre = "" unless( defined( $thePre ) );
    my $text = "$thePre\|$r1";

    # Find out whether this is title row
    my $boldTitle = 0;
    if ( $params{"headerislabel"} && $title =~ m/\*(.*)\*/ ) {
      my $isTitle = 1;
      $boldTitle = $1;
      my @fields = split (/\|/, $tail);
      foreach my $fld (@fields) {
	if ( $fld !~ m/\s*\*.*\*\s*/o ) { $isTitle = 0; last; }
      }
      return "$text$title$r2\|$tail" if $isTitle;
    }

    $title = $boldTitle if $boldTitle;
    $text .= "*" if $boldTitle;
    # Add edit links, maybe this should just be a link of the first table item
    my $eurl = TWiki::Func::getScriptUrlPath() . "/editTableRow$scriptSuffix/$web/$topic";
    if ( $prefEDITLINK ) {
      my $value = $prefEDITLINK;
      my $img = "";
      if( $value =~ s/(.+),\s*(.+)/$1/o ) {
	$img = $2;
	$img =~ s|%ATTACHURL%|%PUBURL%/$installWeb/EditTablerowPlugin|o;
	$img =~ s|%WEB%|$installWeb|o;
      }
      if( $img ) {
	$button = "<img src=\"$img\" alt=\"$value\" border=\"0\" />";
      } else {
	$button = "$value";
      }
      $text .= "<a href=\"$eurl\?t=" . time() . "&template=$params{'template'}&helptopic=$params{'helptopic'}&tablename=$theTableNr&sec=$theRowNr&changerows=$params{'changerows'}&showtable=$params{'showtable'}#SECEDITBOX\">$button</a> $title";
    } else {
      $text .= "<a href=\"$eurl\?t=" . time() . "&template=$params{'template'}&helptopic=$params{'helptopic'}&tablename=$theTableNr&sec=$theRowNr&changerows=$params{'changerows'}&showtable=$params{'showtable'}#SECEDITBOX\">$title</a>";
    }
      
    $text .= "*" if $boldTitle;

    $text .= "$r2\|$tail";

    return $text;
}

# =========================
sub carriageReturnConvert
{
	my ( $string ) = @_;
	
	if ( $string =~ /\<br\>/ ) {
		$string =~ s/\<br\>/\n/g;
	} else {
		$string =~ s/\n/\<br\>/g;
		$string =~ s/\r//g;
	}	

	return ( $string );
}

# =========================
sub stringConvert
{
	my ( $string ) = @_;
	
#	$string =~ s/\+/\._./g; #Converts all '+' characters to '._.' characters
	$string =~ s/\ /+/g;    #Uses '+' character to denote spaces

	return ( $string );
}

# =========================
sub updateTableRow {

    my ( $line, $deleteElement, $copyElement, $fieldsInfo ) = @_;

    my @fieldElements = ();

    # found row
    $result = "";
    if ($deleteElement) {
      return ""; 
    }
    if ($copyElement) {
      # Copy the entry
      $result .= $line;
    }
    # Update the entry
    $result .= "\|";
    my $firstEntry = 1;
    foreach my $c ( @{$fieldsInfo} ) {
      my @fieldInfo = @$c;
      my $entryName = shift @fieldInfo;
      my $title     = shift @fieldInfo;
      my $type      = shift @fieldInfo;
      my $size      = shift @fieldInfo;
      my $tableEntry= $query->param( $entryName );
      my $cvalue    = "";

      ## Puts default text "---" for first entry
      if ($firstEntry == 1) {
	$tableEntry = "---" if ($tableEntry eq "");
	$firstEntry = 0;
      }

      # Takes care of special checkbox entry (Form.pm -- line : 376) 
      if( ! $tableEntry && $type =~ "^checkbox" ) {
	foreach my $name ( @fieldInfo ) {
	  $cvalue = $query->param( "$entryName" . "$name" );
	  if( defined( $cvalue ) ) {
	    if( ! $tableEntry ) {
	      $tableEntry = "";
	    } else {
	      $tableEntry .= ", " if( $cvalue );
	    }
	    $tableEntry .= "$name" if( $cvalue );
	  }
	}
      }
      #$tableEntry = "&nbsp;" unless $tableEntry;
      $tableEntry = " " unless $tableEntry;
      $result .= TWiki::Plugins::EditTablerowPlugin::carriageReturnConvert( $tableEntry ) . "\|";

    }
    #push @fieldElements, ( "name" => TWiki::Plugins::TablePlugin::stringConvert( $sortName ) );
    return "$result\n";
}

# =========================
sub appendToTable {
    my ( $line, $rowNr, $deleteElement, $copyElement, $fieldsInfo ) = @_;

    my @fieldElements = ();

    # found row
    $result = "";
    if ($deleteElement) {
      return ""; 
    }
    if ($copyElement) {
      # Copy the entry
      $result .= $line;
    }
    # Update the entry
    $result .= "\|";
    my $firstEntry = 1;
    foreach my $c ( @{$fieldsInfo} ) {
      my @fieldInfo = @$c;
      my $entryName = shift @fieldInfo;
      my $title     = shift @fieldInfo;
      my $type      = shift @fieldInfo;
      my $size      = shift @fieldInfo;
      my $tableEntry= $query->param( $entryName );
      my $cvalue    = "";

      ## Puts default text "---" for first entry
      if ($firstEntry == 1) {
	$tableEntry = "---" if ($tableEntry eq "");
	$firstEntry = 0;
      }

      # Takes care of special checkbox entry (Form.pm -- line : 376) 
      if( ! $tableEntry && $type =~ "^checkbox" ) {
	foreach my $name ( @fieldInfo ) {
	  $cvalue = $query->param( "$entryName" . "$name" );
	  if( defined( $cvalue ) ) {
	    if( ! $tableEntry ) {
	      $tableEntry = "";
	    } else {
	      $tableEntry .= ", " if( $cvalue );
	    }
	    $tableEntry .= "$name" if( $cvalue );
	  }
	}
      }
      #$tableEntry = "&nbsp;" unless $tableEntry;
      $tableEntry = " " unless $tableEntry;
      $result .= TWiki::Plugins::EditTablerowPlugin::carriageReturnConvert( $tableEntry ) . "\|";

    }
    #push @fieldElements, ( "name" => TWiki::Plugins::TablePlugin::stringConvert( $sortName ) );
    return "$result\n$line";

}

1;
