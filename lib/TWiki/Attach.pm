package TWiki::Attach;

# FIXME: will use of globals here be a problem for mod_perl?

use vars qw(
        $showAttr $viewableAttachmentCount $noviewableAttachmentCount
    );


# Render the %FILEATTACHMENT...% tags to HTML
# =========================
sub handleTags
{;
    my $theWeb = $_[1];
    my $theTopic = $_[2];
    
    $viewableAttachmentCount = 0;
    $noviewableAttachmentCount = 0;

    # First do rows of attachment table
    $_[0] =~ s/(%FILEATTACHMENT\{)([^\}]*)(}%)/&formatAttachments( $1, $2, $3, "", $theWeb, $theTopic )/geo;

    # Rest depends on whether any rows exists to display
    $_[0] =~ s/(%FILEATTACHMENT\{)([^\}]*)(}%)/&formatAttachments( $1, $2, $3, "cmd", $theWeb, $theTopic )/geo;
    
    return $theText;
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
    my ( $start, $attributes, $end, $justCmd, $theWeb, $theTopic ) = @_;

    my $row = "";

    my $attrCmd     = TWiki::extractNameValuePair( $attributes, "cmd" );
    if ( $attrCmd ) {
        # FIXME this is far too complicated
        
        if ( $attrCmd eq "Start" ) {
           $showAttr = TWiki::extractNameValuePair( $attributes, "view" );
        }

        if ( ! $justCmd ) {
           return "$start$attributes$end";
        }
        
        if ( $attrCmd eq "Start" && $viewableAttachmentCount > 0 ) {
           $showAttr = TWiki::extractNameValuePair( $attributes, "view" );
           $row .= "|  *FileAttachment:*  |  *Action:*  |  *Size:*  |  *Date:*  |  *Who:*  |  *Comment:*  |";
           if ( $showAttr ) {
               #$row .= "    <th title=\"h : hidden, d : deleted, - none\">Attrib:</th>";
               $row .= "  *Attrib:*  |";
           }
        } elsif ( $attrCmd eq "End" ) {
           if ( $viewableAttachmentCount > 0 ) {
           }
           if ( $showAttr ) {
              # FIXME move to a template
              $row .= "<a href=\"%SCRIPTURL%/view/$theWeb/$theTopic\">List ordinary attachments</a>";
           } else {
              if( $noviewableAttachmentCount > 0 ) {
                 # FIXME move to a template
                 $row .= "<a href=\"%SCRIPTURL%/view/$theWeb/$theTopic?showAttr=hd\">View all attachments</a>";
              }
           }
        }
    } else {

        my ( $file, $attrVersion, $attrPath, $attrSize, $attrDate, $attrUser, $attrComment, $attrAttr ) =
            TWiki::Attach::extractFileAttachmentArgs( $attributes );

        if (  ! $attrAttr || ( $showAttr && $attrAttr =~ /^[$showAttr]*$/ ) ) {
            $viewableAttachmentCount++;
            my $fileIcon = TWiki::Attach::filenameToIcon( $file );
            $attrComment = $attrComment || "&nbsp;";
            $row .= "| $fileIcon <a href=\"%SCRIPTURL%/viewfile/$theWeb/$theTopic?rev=$attrVersion&filename=$file\">$file</a> \\\n";
            $row .= "   | <a href=\"%SCRIPTURL%/attach/$theWeb/$theTopic?filename=$file&revInfo=1\">action</a> \\\n";
            $row .= "   | $attrSize | $attrDate | $attrUser | $attrComment |";
            if ( $showAttr ) {
                $attrAttr = $attrAttr || "-";
                $row .= " $attrAttr |";
            }
        }  else {
            $noviewableAttachmentCount++;
        }
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
      # FIXME seems to be failing to update RCS at present
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
   TWiki::writeDebug( "Attach: migrateToFileAttachmentMacro" );

   my $res = "\n" . startMacro();
   
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
   
   $res .= endMacro();

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
sub startMacro
{
    return "%FILEATTACHMENT{ cmd=\"Start\" }%\n";
}


# =========================
sub endMacro
{
    return "%FILEATTACHMENT{ cmd=\"End\" }%\n";
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

# FIXME not yet used
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
sub updateAttachment
{
   my ( $atext, $fileVersion, $fileName, $filePath, $fileSize, $fileDate, $fileUser, $fileComment, $hideFile ) = @_;

   my $tmpVersion = "-";
   my $tmpAttr = "";
   if ( $hideFile ) {
      $tmpAttr .= "h";
   }

   my $attachMacro = formFileAttachmentMacro(
          $fileName, $fileVersion, $filePath, $fileSize, $fileDate, $fileUser, 
          $fileComment, $tmpAttr );
          
   TWiki::writeDebug( "upload: attachMacro = $attachMacro" );
          
   my $endMacro = TWiki::Attach::endMacro();

   if ( ! $atext ) {
      $atext = "\n" . &TWiki::Attach::startMacro();
      $atext .= "$attachMacro\n";
      $atext .= $endMacro;
   } else {
      if ( ! $fileSize ) {
         # Only trying to change attribute
         $atext =~ s/(%FILEATTACHMENT{[\s]*\"$fileName\"[^}]* attr=\")([^\"]*)(\"[^}]*}%)/$1$tmpAttr$3/o;
         # FIXME error if no entry?
      } else {
         # Is there already an entry for this file replace, otherwise, add to end
         if ( ! ( $atext =~ s/%FILEATTACHMENT{[\s]*\"$fileName\"[^}]*}%/$attachMacro/o ) ) {
             $atext =~ s/(\Q$endMacro\E)/$attachMacro\n$1/o;
         }
      }
   }
   return $atext;
}

1;
