#
# TWiki WikiClone (see TWiki.pm for $wikiversion and other info)
#
# Copyright (C) 2001 Peter Thoeny, Peter@Thoeny.com
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
# Notes:
# - Latest version at http://twiki.org/
# - Installation instructions in $dataDir/TWiki/TWikiDocumentation.txt
# - Customize variables in TWiki.cfg when installing TWiki.
#
#
#
# This package contains routines for dealing with attachments to topics.
# 
# 

package TWiki::Attach;

use vars qw(
        $showAttr $viewableAttachmentCount $noviewableAttachmentCount $attachmentCount $noFooter
    );

# =========================
# Render the %FILEATTACHMENT...% tags to HTML
sub handleTags
{
    my $theWeb = $_[1];
    my $theTopic = $_[2];
    
    $viewableAttachmentCount = 0;
    $noviewableAttachmentCount = 0;
    $attachmentCount = 0;
    
    my ( $before, $atext, $after ) = split( /<!--TWikiAttachment-->/, $_[0] );
    
    if( ! $before ) { $before = ""; }
    if( ! $atext  ) { $atext  = ""; }
    if( ! $after  ) { $after  = ""; }
        
    $atext =~ s/(%FILEATTACHMENT\{)([^\}]*)(}%)/&formatAttachments( $1, $2, $3, $theWeb, $theTopic )/geo;

    # FIXME allow specification of text or image for this.
    my $footer = "";
    if( $attachmentCount && ! $noFooter ) {
        if( $showAttr ) {
            $footer = "<a href=\"%SCRIPTURLPATH%/view/$theWeb/$theTopic\">List ordinary attachments</a>";
        } else {
            if( $noviewableAttachmentCount > 0 ) {
                $footer = "<a href=\"%SCRIPTURLPATH%/view/$theWeb/$theTopic?showAttr=hd\">View all attachments</a>";
            }
        }
        $atext =~ s/(\s)*$/\n|  $footer  |||||||$1/;
    }
    $atext =~ s/\n+/\n/go;
        
    $_[0] = "$before$atext$after";
}


# =========================
sub filenameToIcon
{
    my( $fileName ) = @_;

    my @bits = ( split( /\./, $fileName ) );
    my $fileExt = lc $bits[$#bits];

    my $tmp = &TWiki::getPubDir();
    my $iconDir = "$tmp/icn";
    my $iconUrl = "%PUBURLPATH%/icn";
    my $iconList = &TWiki::Store::readFile( "$iconDir/_filetypes.txt" );
    foreach( split( /\n/, $iconList ) ) {
        @bits = ( split( / / ) );
	if( $bits[0] eq $fileExt ) {
            return "<IMG src=\"$iconUrl/$bits[1].gif\" width=\"16\" hight=\"16\" align=\"top\">";
        }
    }
    return "<IMG src=\"$iconUrl/else.gif\" width=\"16\" hight=\"16\" align=\"top\">";
}


# =========================
sub formatAttachments
{
    my ( $start, $attributes, $end, $theWeb, $theTopic ) = @_;

    my $row = "";

    my ( $file, $attrVersion, $attrPath, $attrSize, $attrDate, $attrUser, $attrComment, $attrAttr ) =
        TWiki::Attach::extractFileAttachmentArgs( $attributes );

    $attachmentCount++;
    if (  ! $attrAttr || ( $showAttr && $attrAttr =~ /^[$showAttr]*$/ ) ) {
        $viewableAttachmentCount++;     
        if( $viewableAttachmentCount == 1 ) {
            $row .= "|  *[[%TWIKIWEB%.FileAttachment]]:*  |  *Action:*  |  *Size:*  |  *Date:*  |  *Who:*  |  *Comment:*  |";
            if( $showAttr ) {
                $row .= "  *[[%TWIKIWEB%.FileAttribute]]:*  |";
            }
            $row .= "\n";
        }
        my $fileIcon = TWiki::Attach::filenameToIcon( $file );
        $attrComment = $attrComment || "&nbsp;";
        $row .= "| $fileIcon <a href=\"%SCRIPTURLPATH%/viewfile/$theWeb/$theTopic?rev=$attrVersion&filename=$file\">$file</a> \\\n";
        $row .= "   | <a href=\"%SCRIPTURL%/attach/$theWeb/$theTopic?filename=$file&revInfo=1\">action</a> \\\n";
        $row .= "   | $attrSize | $attrDate | $attrUser | $attrComment |";
        if ( $showAttr ) {
            $attrAttr = $attrAttr || " &nbsp; ";
            $row .= " $attrAttr |";
        }
    }  else {
        $noviewableAttachmentCount++;
    }

    return $row;
}


#=========================
sub migrateFormatForTopic
{
   my ( $theWeb, $theTopic, $doLogToStdOut ) = @_;
   
   my $text = TWiki::Store::readWebTopic( $theWeb, $theTopic );
   my ( $before, $atext, $after ) = split( /<!--TWikiAttachment-->/, $text );
   if( ! $before ) { $before = ""; }
   if( ! $atext  ) { $atext  = ""; }

   if ( $atext =~ /<TwkNextItem>/ ) {
      my $newtext = migrateToFileAttachmentMacro( $atext );
      
      $text = "$before<!--TWikiAttachment-->$newtext<!--TWikiAttachment-->";

      my ( $dontLogSave, $doUnlock, $dontNotify ) = ( "", "1", "1" );
      my $error = TWiki::Store::save( $theWeb, $theTopic, $text, "", $dontLogSave, $doUnlock, $dontNotify, "upgraded attachment format" );
      if ( $error ) {
         print "Attach: error from save: $error\n";
      }
      if ( $doLogToStdOut ) {
         print "Changed attachment format for $theWeb.$theTopic\n";
      }
   }
}

# Get file attachment attributes for old html
# format.
# =========================
sub getOldAttachAttr
{
    my( $atext ) = @_;
    my $fileName="", $filePath, $fileSize="", $fileDate="", $fileUser="", $fileComment="";
    my $before="", $item="", $after="";

    ( $before, $fileName, $after ) = split( /<(?:\/)*TwkFileName>/, $atext );
    if( ! $fileName ) { $fileName = ""; }
    if( $fileName ) {
        ( $before, $filePath,    $after ) = split( /<(?:\/)*TwkFilePath>/, $atext );
	if( ! $filePath ) { $filePath = ""; }
	$filePath =~ s/<TwkData value="(.*)">//go;
	if( $1 ) { $filePath = $1; } else { $filePath = ""; }
	$filePath =~ s/\%NOP\%//goi;   # delete placeholder that prevents WikiLinks
	( $before, $fileSize,    $after ) = split( /<(?:\/)*TwkFileSize>/, $atext );
	if( ! $fileSize ) { $fileSize = "0"; }
	( $before, $fileDate,    $after ) = split( /<(?:\/)*TwkFileDate>/, $atext );
	if( ! $fileDate ) { $fileDate = ""; }
	( $before, $fileUser,    $after ) = split( /<(?:\/)*TwkFileUser>/, $atext );
	if( ! $fileUser ) { $fileUser = ""; }
	$fileUser =~ s/ //go;
	( $before, $fileComment, $after ) = split( /<(?:\/)*TwkFileComment>/, $atext );
	if( ! $fileComment ) { $fileComment = ""; }
    }

    return ( $fileName, $filePath, $fileSize, $fileDate, $fileUser, $fileComment );
}

# Migrate old HTML format, to %FILEATTACHMENT ... format
# for one piece of text
# =========================
sub migrateToFileAttachmentMacro
{
   my ( $atext ) = @_;
   my $res = "\n";
   
   my $line = "";
   foreach $line ( split( /<TwkNextItem>/, $atext ) ) {
      my( $fileName, $filePath, $fileSize, $fileDate, $fileUser, $fileComment ) =
         getOldAttachAttr( $line );

      if( $fileName ) {
         $res .= formFileAttachmentMacro( $fileName, "", $filePath, $fileSize, 
                                          $fileDate, $fileUser, $fileComment, "" );
         $res .= "\n";
      }
   }
   
   return $res;
}


# =========================
sub formFileAttachmentMacro
{
    my( $theFile, $theVersion, $thePath, $theSize, $theDate, $theUser, 
             $theComment, $theAttr ) = @_;
    my $macro = "%FILEATTACHMENT{ \"$theFile\" ";
    $macro .= "version=\"$theVersion\" ";
    $macro .= "path=\"$thePath\" ";
    $macro .= "size=\"$theSize\" ";
    $macro .= "date=\"$theDate\" ";
    $macro .= "user=\"$theUser\" ";
    $macro .= "comment=\"$theComment\" ";
    $macro .= "attr=\"$theAttr\" ";

    $macro .= "}%";

    return $macro;
}



# =========================
sub extractFileAttachmentArgs
{
    my( $attributes ) = @_;

    my $file =        TWiki::extractNameValuePair( $attributes );
    my $attrVersion = TWiki::extractNameValuePair( $attributes, "version" );
    my $attrPath    = TWiki::extractNameValuePair( $attributes, "path" );
    my $attrSize    = TWiki::extractNameValuePair( $attributes, "size" );
    my $attrDate    = TWiki::extractNameValuePair( $attributes, "date" );
    my $attrUser    = TWiki::extractNameValuePair( $attributes, "user" );
    my $attrComment = TWiki::extractNameValuePair( $attributes, "comment" ); 
    my $attrAttr    = TWiki::extractNameValuePair( $attributes, "attr" );

    return ( $file, $attrVersion, $attrPath, $attrSize, $attrDate, $attrUser, 
             $attrComment, $attrAttr );
}

# FIXME - could be used more?
# ==========================
sub extractArgsForFile
{
   my ( $theText, $theFile ) = @_;
   
   if ( $theText =~ /%FILEATTACHMENT{[\s]*("$theFile" [^}]*)}%/o ) {
      return extractFileAttachmentArgs( $1 );
   } else {
      return "";
   }
}


# =========================
# Remove attachment macro for specified file from topic
# return "", or error string
sub removeFile
{
    my $theFile = $_[1];
    my $error = "";
    
    # %FILEATTACHMENT{[\s]*"$theFile"[^}]*}%
    if( ! ( $_[0] =~ s/%FILEATTACHMENT{[\s]*"$theFile"[^}]*}%//) ) {
       $error = "Failed to remove attachment $theFile";
    }
    return $error;
}


# =========================
# Add/update attachment for a topic
# $text is full set of attachments, new attachments will be added to the end.
sub updateAttachment
{
   my ( $atext, $fileVersion, $fileName, $filePath, $fileSize, $fileDate, $fileUser, $fileComment, $hideFile ) = @_;

   my $tmpAttr = "";
   if ( $hideFile ) {
      $tmpAttr .= "h";
   }

   my $attachMacro = formFileAttachmentMacro(
          $fileName, $fileVersion, $filePath, $fileSize, $fileDate, $fileUser, 
          $fileComment, $tmpAttr );
          
   TWiki::writeDebug( "Attach: attachMacro = $attachMacro" );
   TWiki::writeDebug( "Attach: text = \"$atext\"" );

   if( ! $atext ) {
      $atext = "\n";
      $atext .= "$attachMacro\n";
   } else {
      if( ! $fileSize ) {
         # Only trying to change attribute
         $atext =~ s/(%FILEATTACHMENT{[\s]*\"$fileName\"[^}]* attr=\")([^\"]*)(\"[^}]*}%)/$1$tmpAttr$3/o;
         # FIXME warning if no entry?
      } else {
         # Is there already an entry for this file replace, otherwise, add to end
         if ( ! ( $atext =~ s/%FILEATTACHMENT{[\s]*\"$fileName\"[^}]*}%/$attachMacro/o ) ) {
             $atext =~ s/\s*$/\n$attachMacro/;
         }
      }
   }
   return $atext;
}

1;
