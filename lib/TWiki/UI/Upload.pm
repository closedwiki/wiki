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

  ( $meta, $text ) =
    TWiki::Store::readTopic( $webName, $topic, undef, 0 );
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
  $tmpl = $TWiki::renderer->getRenderedVersion( $tmpl );
  $tmpl = $TWiki::renderer->renderMetaTags( $webName, $topic, $tmpl, $meta, 0 );
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
    my $doPropsOnly = $query->param( 'changeproperties' );
    my $filePath = $query->param( 'filepath' ) || "";
    my $fileName = $query->param( 'filename' ) || "";
    if ( $filePath && ! $fileName ) {
        $filePath =~ m|([^/\\]*$)|;
        $fileName = $1;
    }

    my $stream;
    $stream = $query->upload( "filepath" ) unless ( $doPropsOnly );

    $fileComment =~ s/\s+/ /go;
    $fileComment =~ s/^\s*//o;
    $fileComment =~ s/\s*$//o;

    close $filePath if( $TWiki::OS eq "WINDOWS");

    my $wikiUserName = TWiki::User::userToWikiName( $userName );
    return ( 0 ) unless TWiki::UI::webExists( $webName, $topic );
    return ( 0 ) if TWiki::UI::isMirror( $webName, $topic );
    return ( 0 ) unless TWiki::UI::isAccessPermitted( $webName, $topic,
                                              "change", $wikiUserName );
    return ( 0 ) unless TWiki::UI::topicExists( $webName, $topic, "upload" );

    my ( $fileSize, $fileDate, $tmpFileName );

    unless( $doPropsOnly ) {
        # cut path from filepath name (Windows "\" and Unix "/" format)
        my @pathz = ( split( /\\/, $filePath ) );
        my $filetemp = $pathz[$#pathz];
        my @pathza = ( split( '/', $filetemp ) );
        $fileName = $pathza[$#pathza];

        # Delete unwanted characters from filename, with I18N
        my $nonAlphaNum = "[^$TWiki::regex{mixedAlphaNum}" . '\._-]+';
        $fileName =~ s/${nonAlphaNum}//go;
        # apply security filter
        $fileName =~ s/$TWiki::uploadFilter/$1\.txt/goi;
        $fileName =~ /(.*)/;  # untaint (why?)
        $fileName = $1;

        ##TWiki::writeDebug ("Upload filename after cleanup is '$fileName'");

        # check if upload has non zero size
        $tmpFileName = $query->tmpFileName( $filePath );
        my @stats = stat $tmpFileName;
        $fileSize = $stats[7];
        $fileDate = $stats[9];

        if( ! $fileSize ) {
            TWiki::UI::oops( $webName, $topic,
                             "upload",
                             "ERROR $webName.$topic File missing or zero size",
                             $fileName );
            return;
        }

        my $maxSize = $TWiki::prefsObject->getValue( "ATTACHFILESIZELIMIT" );
        $maxSize = 0 unless ( $maxSize =~ /([0-9]+)/o );

        if( $maxSize && $fileSize > $maxSize * 1024 ) {
            TWiki::UI::oops( $webName, $topic,
                             "uploadlimit", $fileName, $maxSize );
            return;
        }
    }

    my $error =
      TWiki::Store::saveAttachment( $webName, $topic, $fileName, $userName,
                                    { dontlog => !$TWiki::doLogTopicUpload,
                                      comment => $fileComment,
                                      hide => $hideFile,
                                      createlink => $createLink,
                                      # Undocumented CGI call
                                      file => $tmpFileName,
                                      filepath => $filePath,
                                      filesize => $fileSize,
                                      filedate => $fileDate,
                                    } );

    if( $error ) {
        TWiki::UI::oops( $webName, $topic, "saveerr", "Save error $error" );
        return;
    }

    TWiki::UI::redirect( &TWiki::getViewUrl( $webName, $topic ) );
    my $message = ( $doPropsOnly ) ?
      "properties changed" : "$fileName uploaded";

    print( "OK $message\n" );
}

1;
