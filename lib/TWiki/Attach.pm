package TWiki::Attach;


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
      my $filename = "";

      TWiki::writeDebug( "Attach: line=$line" );
      if ( $line =~ /<TwkFileName>([^<]*)</ ) {
         $filename = $1;
      }
      # FIXME might there be some trailing spaces to remove?
      $line =~ /<TwkFilePath>[\s]*([^<]*)</;
      my $filepath = $1;
      $line =~ /<TwkFileSize>[\s]*([^<]*)</;
      my $filesize = $1;
      $line =~ /<TwkFileDate>[\s]*([^<]*)</;
      my $filedate = $1;
      $line =~ /<TwkFileUser>[\s]*([^<]*)</;
      my $fileuser = $1;
      $line =~ /<TwkFileComment>[\s]*([^<]*)</;
      my $filecomment = $1;
      
      if ( $filename ) {
         $res .= formFileAttachmentMacro( $filename, "", $filepath, $filesize, $filedate, $fileuser, $filecomment, "" );
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
   
   if ( $theText =~ /%FILEATTACHMENT{[\s]*(\"$theFile\" [^}])}%/ ) {
      return extractFileAttachmentArgs( $1 );
   } else {
      return "";
   }
}

1;
