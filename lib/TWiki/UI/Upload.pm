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
use Error qw( :try );
use TWiki::UI::OopsException;

=pod

---++ attach( $session )
Perform the functions of an 'attach' URL. CGI parameters are:
| =filename= | Name of attachment |
| =skin= | Skin to use in presenting pages |

=cut
sub attach {
    my $session = shift;

    my $query = $session->{cgiQuery};
    my $webName = $session->{webName};
    my $topic = $session->{topicName};

    my $fileName = $query->param( 'filename' ) || "";
    my $skin = $session->getSkin();

    TWiki::UI::checkWebExists( $session, $webName, $topic );

    my $tmpl = "";
    my $text = "";
    my $meta = "";
    my $atext = "";
    my $fileUser = "";
    my $isHideChecked = "";

    TWiki::UI::checkMirror( $session, $webName, $topic );

    TWiki::UI::checkAccess( $session, $webName, $topic,
                            "change", $session->{user} );
    TWiki::UI::checkTopicExists( $session, $webName, $topic,
                                 "upload files to" );

    ( $meta, $text ) =
      $session->{store}->readTopic( $session->{user}, $webName, $topic, undef );
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
        $session->writeLog( "attach", "$webName.$topic", $fileName );
    }

    my $fileWikiUser = "";
    if( $fileName && %args ) {
        $tmpl = $session->{templates}->readTemplate( "attachagain", $skin );
        my $u = $session->{users}->findUser( $args{"user"} );
        $fileWikiUser = $u->webDotWikiName() if $u;
    } else {
        $tmpl = $session->{templates}->readTemplate( "attachnew", $skin );
    }
    if ( $fileName ) {
        # must come after templates have been read
        $atext .= $session->{attach}->formatVersions( $webName, $topic, %args );
    }
    $tmpl =~ s/%ATTACHTABLE%/$atext/go;
    $tmpl =~ s/%FILEUSER%/$fileWikiUser/go;
    $tmpl = $session->handleCommonTags( $tmpl, $topic );
    # SMELL: The following two calls are done in the reverse order in all
    # the other handlers. Why are they done in this order here?
    $tmpl = $session->{renderer}->getRenderedVersion( $tmpl );
    $tmpl = $session->{renderer}->renderMetaTags( $webName, $topic, $tmpl, $meta, 0 );
    $tmpl =~ s/%HIDEFILE%/$isHideChecked/go;
    $tmpl =~ s/%FILENAME%/$fileName/go;
    $tmpl =~ s/%FILEPATH%/$args{"path"}/go;
    $tmpl =~ s/%FILECOMMENT%/$args{"comment"}/go;
    $tmpl =~ s/( ?) *<\/?(nop|noautolink)\/?>\n?/$1/gois;   # remove <nop> and <noautolink> tags

    $session->writeCompletePage( $tmpl );
}

=pod

---++ upload( $session )
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
    my $session = shift;

    my $query = $session->{cgiQuery};
    my $webName = $session->{webName};
    my $topic = $session->{topicName};
    my $user = $session->{user};

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

    TWiki::UI::checkWebExists( $session, $webName, $topic );
    TWiki::UI::checkMirror( $session, $webName, $topic );
    TWiki::UI::checkAccess( $session, $webName, $topic,
                            "change", $user );
    TWiki::UI::checkTopicExists( $session, $webName, $topic,
                                 "attach files to" );

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
        $fileName = TWiki::Sandbox::untaintUnchecked( $fileName );

        ##$session->writeDebug ("Upload filename after cleanup is '$fileName'");

        # check if upload has non zero size
        $tmpFileName = $query->tmpFileName( $filePath );
        my @stats = stat $tmpFileName;
        $fileSize = $stats[7];
        $fileDate = $stats[9];

        if( ! $fileSize ) {
            throw TWiki::UI::OopsException( $webName, $topic,
                             "upload",
                             "ERROR $webName.$topic File missing or zero size",
                             $fileName );
        }

        my $maxSize = $session->{prefs}->getPreferencesValue( "ATTACHFILESIZELIMIT" );
        $maxSize = 0 unless ( $maxSize =~ /([0-9]+)/o );

        if( $maxSize && $fileSize > $maxSize * 1024 ) {
            throw TWiki::UI::OopsException( $webName, $topic,
                             "uploadlimit", $fileName, $maxSize );
        }
    }

    my $error =
      $session->{store}->saveAttachment( $webName, $topic, $fileName, $user,
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
        throw TWiki::UI::OopsException( $webName, $topic, "saveerr",
                                        "Save error $error" );
    }

    $session->redirect( $session->getScriptUrl( $webName, $topic, "view" ) );
    my $message = ( $doPropsOnly ) ?
      "properties changed" : "$fileName uploaded";

    print( "OK $message\n" );
}

1;
