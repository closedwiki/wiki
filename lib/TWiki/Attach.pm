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

# ======================
sub renderMetaData
{
    my( $web, $topic, $metaP ) = @_;
    
    my @meta = @$metaP;
    
    my $metaText = "";
    
    $viewableAttachmentCount = 0;
    $noviewableAttachmentCount = 0;
    $attachmentCount = 0;
    
    $header .= "|  *[[%TWIKIWEB%.FileAttachment]]:*  |  *Action:*  |  *Size:*  |  *Date:*  |  *Who:*  |  *Comment:*  |";
    if( $showAttr ) {
        $header .= "  *[[%TWIKIWEB%.FileAttribute]]:*  |";
    }
    $header .= "\n";
    
    foreach my $metaItem ( @meta ) {
       if( $metaItem =~ /(%META:FILEATTACHMENT\{)([^\}]*)(}%)/ ) {
           $metaText .= formatAttachments( $1, $2, $3, $web, $topic );
       }
    }
    
    my $footer = "";
    if( $attachmentCount && ! $noFooter ) {
        if( $showAttr ) {
            $footer = "<a href=\"%SCRIPTURLPATH%/view/$web/$topic\">List ordinary attachments</a>";
        } else {
            if( $noviewableAttachmentCount > 0 ) {
                $footer = "<a href=\"%SCRIPTURLPATH%/view/$web/$topic?showAttr=hd\">View all attachments</a>";
            }
        }
        $footer = "|  $footer  |||||||";
    }
    
    TWiki::writeDebug( "Attach: $header$metaText$footer" );
    
    my $text = "";
    if( $attachmentCount ) {
       $text = "<p>\n$header$metaText$footer\n</p>";
    }
    
    return $text;
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
        my $fileIcon = TWiki::Attach::filenameToIcon( $file );
        $attrComment = $attrComment || "&nbsp;";
        $row .= "| $fileIcon <a href=\"%SCRIPTURLPATH%/viewfile/$theWeb/$theTopic?rev=$attrVersion&filename=$file\">$file</a> \\\n";
        $row .= "   | <a href=\"%SCRIPTURL%/attach/$theWeb/$theTopic?filename=$file&revInfo=1\">action</a> \\\n";
        $row .= "   | $attrSize | $attrDate | $attrUser | $attrComment |";
        if ( $showAttr ) {
            $attrAttr = $attrAttr || " &nbsp; ";
            $row .= " $attrAttr |";
        }
        $row .= "\n";
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
    my $fileName="", $filePath="", $fileSize="", $fileDate="", $fileUser="", $fileComment="";
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
   my ( $text, @meta ) = @_;
   
   
   my ( $before, $atext, $after ) = split( /<!--TWikiAttachment-->/, $text );
   if( ! $before ) { $before = ""; }
   if( ! $atext  ) { $atext  = ""; }
   
   if( $atext =~ /<TwkNextItem>/ ) {
      my $line = "";
      foreach $line ( split( /<TwkNextItem>/, $atext ) ) {
          my( $fileName, $filePath, $fileSize, $fileDate, $fileUser, $fileComment ) =
             getOldAttachAttr( $line );

          if( $fileName ) {
             my @args = formFileAttachmentArgs( $fileName, "", $filePath, $fileSize, 
                                              $fileDate, $fileUser, $fileComment, "" );
             @meta = TWiki::Store::metaUpdate( "FILEATTACHMENT", \@args, "name", @meta );                                 
          }
       }
   } else {
       # Format of macro that came before META:ATTACHMENT
       my $line = "";
       foreach $line ( split( /\n/, $atext ) ) {
           if( $line =~ /%FILEATTACHMENT{\s"([^"]*)"([^}]*)}%/ ) {
               my $name = $1;
               my $rest = $2;
               $rest =~ s/^\s*//;
               my @values = TWiki::Store::keyValue2list( $rest );
               unshift @values, $name;
               unshift @values, "name";
               @meta = TWiki::Store::metaUpdate( "FILEATTACHMENT", \@values, "name", @meta );
           }
       }
   }
       
   $text = "$before$after";
   
   return( $text, @meta );
}



# =========================
sub formFileAttachmentArgs
{
    my( $theFile, $theVersion, $thePath, $theSize, $theDate, $theUser, 
             $theComment, $theAttr ) = @_;

    my @args = (
       "name"    => $theFile,
       "version" => $theVersion,
       "path"    => $thePath,
       "size"    => $theSize,
       "date"    => $theDate,
       "user"    => $theUser,
       "comment" => $theComment,
       "attr"    => $theAttr );
    
    return @args;
}



# =========================
sub extractFileAttachmentArgs
{
    my( $attributes ) = @_;

    my $file =        TWiki::extractNameValuePair( $attributes, "name" );
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
    my ( $fileVersion, $fileName, $filePath, $fileSize, $fileDate, $fileUser, $fileComment, $hideFile, @meta ) = @_;

    my $tmpAttr = "";
    if ( $hideFile ) {
       $tmpAttr .= "h";
    }
          
    #TWiki::writeDebug( "Attach: attachArgs = @args" );

    if( ! $fileDate ) {
        # Only trying to change attribute
        
        my @args = ( "attr" => $tmpAttr );
        @meta = TWiki::Store::metaUpdatePartial( "FILEATTACHMENT", \@args, "name", @meta );
        # FIXME warning if no entry?
    } else {
        my @args = formFileAttachmentArgs(
          $fileName, $fileVersion, $filePath, $fileSize, $fileDate, $fileUser, 
          $fileComment, $tmpAttr );
        @meta = TWiki::Store::metaUpdate( "FILEATTACHMENT", \@args, "name", @meta );
    }
    
    return @meta;
}

1;
