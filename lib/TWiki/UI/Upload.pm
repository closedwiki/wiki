# TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 1999-2004 Peter Thoeny, peter@thoeny.com
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
=begin twiki

---+ TWiki::UI::Upload

UI delegate for attachment management functions

=cut
package TWiki::UI::Upload;

use strict;
use TWiki;
use TWiki::UI;

=pod

---++ attach( $web, $topic, $query )
Perform the functions of an 'attach' URL. CGI parameters are:
| =filename= | Name of attachment |
| =skin= | Skin to use in presenting pages |

=cut
sub attach {
  my ( $webName, $topic, $userName, $query ) = @_;

  my $fileName = $query->param( 'filename' ) || "";
  my $skin = TWiki::getSkin();

  return unless TWiki::UI::webExists( $webName, $topic );

  my $tmpl = "";
  my $text = "";
  my $meta = "";
  my $atext = "";
  my $fileUser = "";

  my $isHideChecked = "";

  return if TWiki::UI::isMirror( $webName, $topic );

  my $wikiUserName = &TWiki::User::userToWikiName( $userName );
  return unless TWiki::UI::isAccessPermitted( $webName, $topic,
                                            "change", $wikiUserName );

  return unless TWiki::UI::topicExists( $webName, $topic, "attach" );

  ( $meta, $text ) = &TWiki::Store::readTopic( $webName, $topic );
  my %args = $meta->findOne( "FILEATTACHMENT", $fileName );
  %args = (
           name => $fileName,
           attr => "",
           path => "",
           comment => ""
          ) if( ! % args );

  if ( $args{attr} =~ /h/o ) {
      $isHideChecked = "checked";
  }

  # SMELL: why log attach before post is called?
  # FIXME: Move down, log only if successful (or with error msg?)
  # Attach is a read function, only has potential for a change
  if( $TWiki::doLogTopicAttach ) {
      # write log entry
      TWiki::writeLog( "attach", "$webName.$topic", $fileName );
  }

  my $fileWikiUser = "";
  if( $fileName && %args ) {
    $tmpl = TWiki::Templates::readTemplate( "attachagain", $skin );
    $fileWikiUser = &TWiki::User::userToWikiName( $args{"user"} );
  } else {
      $tmpl = TWiki::Templates::readTemplate( "attachnew", $skin );
  }
  if ( $fileName ) {
	# must come after templates have been read
    $atext .= TWiki::Attach::formatVersions( $webName, $topic, %args );
  }
  $tmpl =~ s/%ATTACHTABLE%/$atext/go;
  $tmpl =~ s/%FILEUSER%/$fileWikiUser/go;
  $tmpl = &TWiki::handleCommonTags( $tmpl, $topic );
  # SMELL: The following two calls are done in the reverse order in all
  # the other handlers. Why are they done in this order here?
  $tmpl = &TWiki::Render::getRenderedVersion( $tmpl );
  $tmpl = TWiki::Render::renderMetaTags( $webName, $topic, $tmpl, $meta, 0 );
  $tmpl =~ s/%HIDEFILE%/$isHideChecked/go;
  $tmpl =~ s/%FILENAME%/$fileName/go;
  $tmpl =~ s/%FILEPATH%/$args{"path"}/go;
  $tmpl =~ s/%FILECOMMENT%/$args{"comment"}/go;
  $tmpl =~ s/( ?) *<\/?(nop|noautolink)\/?>\n?/$1/gois;   # remove <nop> and <noautolink> tags
  TWiki::writeHeader( TWiki::getCgiQuery(), length( $tmpl ));
  print $tmpl;
}

=pod

---++ upload( $web, $topic, $userName, $query)
Perform the functions of an 'upload' url.
CGI parameters, passed in $query:
| =hidefile= | if defined, will not show file in attachment table |
| =filepath= | |
| =filename= | |
| =filecomment= | Comment to associate with file in attachment table |
| =createlink= | if defined, will create a link to file at end of topic |
| =changeproperties= | |

=cut
sub upload {
  my ( $webName, $topic, $userName, $query ) = @_;

  my $hideFile = $query->param( 'hidefile' ) || "";
  my $fileComment = $query->param( 'filecomment' ) || "";
  my $createLink = $query->param( 'createlink' ) || "";
  my $doChangeProperties = $query->param( 'changeproperties' );
  my $filePath = $query->param( 'filepath' ) || "";
  my $fileName = $query->param( 'filename' ) || "";
  if ( $filePath && ! $fileName ) {
    $filePath =~ m|([^/\\]*$)|;
    $fileName = $1;
  }
  my $tmpFilename = $query->tmpFileName( $filePath ) || "";
  # CODE_SMELL: should really be using the file handle, not
  # an undocumented CGI function. The previous line of code causes
  # an Apache warning.
  #my $tmpFile = $query->upload( "filepath" ) || "";

  $fileComment =~ s/\s+/ /go;
  $fileComment =~ s/^\s*//o;
  $fileComment =~ s/\s*$//o;

  close $filePath if( $TWiki::OS eq "WINDOWS");

  # Change Windows path to Unix path
  $tmpFilename =~ s!\\!/!go;
  $tmpFilename =~ /(.*)/;
    $tmpFilename = $1;
    ##TWiki::writeDebug( "upload: tmpFilename $tmpFilename" );
  
  my @error =
    updateAttachment( $webName, $topic, $userName,
                      $createLink,
                      $doChangeProperties,
                      $filePath, $tmpFilename,
                      $fileName, $hideFile, $fileComment );

  if ( ( @error ) && scalar( @error ) && defined( $error[0] )) {
    # error[0] will be "" if redirect already printed
    TWiki::UI::oops( $webName, $topic, @error ) if ( $error[0] )
  } else {
    # and finally display topic
    TWiki::UI::redirect( &TWiki::getViewUrl( $webName, $topic ) );
    my $message = ( $doChangeProperties ) ? "properties changed" : "$fileName uploaded";
    print( "OK $message\n" );
  }
}
  
=pod
  
---++ updateAttachment( $webName, $topic, $userName, $createLink, $propsOnly, $filePath, $localFile, $attName, $hideFile, $comment ) => undef or error
  
CODE_SMELL: this should really be in Store
  
Update an attachment, file or properties or both. This may also be used to
create an attachment.
| =$webName= | Web containing topic |
| =$topic= | Topic |
| =$userName= | Username of user doing upload/change - username, *not* wikiName |
| =$createLink= | 1 if a link is to be created in the topic text |
| =$propsOnly= | 1 if only change properties, not atachment |
| =$filePath= | if !propsOnly, gives the remote path name of the file to upload. This is used to derive the attName. |
| =$localFile= | Name of local file to replace attachment |
| =$attName= | If propsOnly, the name of the attachment. Ignored if !propsOnly. |
| =$hideFile= | (property) on if files is to be hidden in normal view |
| =$comment= | (property) comment associated with file |
| return | on error, a list of parameters to the TWiki::UI::oops function, not including the webName and topic. |
|               |  If the first element in the list is the empty string, an error has already been printed to the browser, and no oops call is necessary. |

=cut
sub updateAttachment {
  my ( $webName, $topic, $userName,
       $createLink,
       $propsOnly,
       $filePath, $localFile,
       $attName, $hideFile, $comment ) = @_;

  my $wikiUserName = TWiki::User::userToWikiName( $userName );
  return ( 0 ) unless TWiki::UI::webExists( $webName, $topic );
  return ( 0 ) if TWiki::UI::isMirror( $webName, $topic );
  return ( 0 ) unless TWiki::UI::isAccessPermitted( $webName, $topic,
                                              "change", $wikiUserName );
  return ( 0 ) unless TWiki::UI::topicExists( $webName, $topic, "upload" );

  my( $fileSize, $fileUser, $fileDate, $fileVersion ) = "";

  unless( $propsOnly ) {
      # cut path from filepath name (Windows "\" and Unix "/" format)
      my @pathz = ( split( /\\/, $filePath ) );
      my $filetemp = $pathz[$#pathz];
      my @pathza = ( split( '/', $filetemp ) );
    $attName = $pathza[$#pathza];
  
      # Delete unwanted characters from filename, with I18N
      my $nonAlphaNum = "[^$TWiki::regex{mixedAlphaNum}" . '\._-]+';
    $attName =~ s/${nonAlphaNum}//go;
    $attName =~ s/$TWiki::uploadFilter/$1\.txt/goi;  # apply security filter
    $attName =~ /(.*)/;  # untaint
    $attName = $1;

    ##TWiki::writeDebug ("Upload filename after cleanup is '$attName'");

    # check if file exists and has non zero size
    my $size = -s $localFile;
  
    if( ! -e $localFile || ! $size ) {
      return ( "upload",
               "ERROR $webName.$topic File missing or zero size", $attName );
    }

    my $maxSize = TWiki::Prefs::getPreferencesValue( "ATTACHFILESIZELIMIT" );
    $maxSize = 0 unless ( $maxSize =~ /([0-9]+)/o );

    if( $maxSize && $size > $maxSize * 1024 ) {
      return ( "uploadlimit", $attName, $maxSize );
    }
  
      # Update
      my $text1 = "";
    my $saveCmd = "";
    my $doNotLogChanges = 1;
    my $doUnlock = 0;
    my $dontNotify = "";
    my $error =
      TWiki::Store::saveAttachment( $webName, $topic, $text1, $saveCmd,
                                    $attName, $doNotLogChanges, $doUnlock,
                                    $dontNotify, $comment, $localFile );

    if ( $error ) {
      return ( "saveerr", "Save attachment error $error" );
    }

    # get user name
    $fileUser = $userName;

    # get time stamp and file size of uploaded file:
    my @stats = stat $localFile;
    $fileSize = $stats[7];
    $fileDate = $stats[9];

    $fileVersion = TWiki::Store::getRevisionNumber( $webName, $topic,
                                                    $attName );

    if( $TWiki::doLogTopicUpload ) {
      # write log entry
      TWiki::writeLog( "upload", "$webName.$topic", $attName );
      #FIXE also do log for change property?
    }
  }

  # update topic
  my( $meta, $text ) = TWiki::Store::readTopic( $webName, $topic );

  # update meta-data
  if( $propsOnly ) {
    TWiki::Attach::updateProperties( $attName, $hideFile, $comment, $meta );
  } else {
    TWiki::Attach::updateAttachment( $fileVersion, $attName, $filePath,
                                     $fileSize,
                                     $fileDate, $fileUser, $comment,
                                     $hideFile, $meta );
  }

  if( $createLink ) {
    $text .= TWiki::Attach::getAttachmentLink( $webName, $topic,
                                               $attName, $meta );
  }

  # update topic
  my $error = TWiki::Store::saveTopic( $webName, $topic, $text, $meta, "", 1 );
  if( $error ) {
    return ( "saveerr", "Save topic error $error" );
  }

  return undef;
}

1;
