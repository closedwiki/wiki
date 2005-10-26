# TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 1999-2005 Peter Thoeny, peter@thoeny.com
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# As per the GPL, removal of this notice is prohibited.

=begin twiki

---+ package TWiki::UI::Upload

UI delegate for attachment management functions

=cut
package TWiki::UI::Upload;

use strict;
use TWiki;
use TWiki::UI;
use Error qw( :try );
use TWiki::OopsException;

=pod

---++ StaticMethod attach( $session )
=upload= command handler.
This method is designed to be
invoked via the =TWiki::UI::run= method.

Attach a file to a topic. CGI parameters are:

| =filename= | Name of attachment |
| =skin= | Skin(s) to use in presenting pages |

=cut
sub attach {
    my $session = shift;

    my $query = $session->{cgiQuery};
    my $webName = $session->{webName};
    my $topic = $session->{topicName};

    my $fileName = $query->param( 'filename' ) || '';
    my $skin = $session->getSkin();

    TWiki::UI::checkWebExists( $session, $webName, $topic, 'attach' );

    my $tmpl = '';
    my $text = '';
    my $meta = '';
    my $atext = '';
    my $fileUser = '';
    my $isHideChecked = '';

    TWiki::UI::checkMirror( $session, $webName, $topic );

    TWiki::UI::checkAccess( $session, $webName, $topic,
                            'change', $session->{user} );
    TWiki::UI::checkTopicExists( $session, $webName, $topic,
                                 'upload files to' );

    ( $meta, $text ) =
      $session->{store}->readTopic( $session->{user}, $webName, $topic, undef );
    my $args = $meta->get( 'FILEATTACHMENT', $fileName );
    $args = {
             name => $fileName,
             attr => '',
             path => '',
             comment => ''
            } unless( $args );

    if ( $args->{attr} =~ /h/o ) {
        $isHideChecked = 'checked';
    }

    # SMELL: why log attach before post is called?
    # FIXME: Move down, log only if successful (or with error msg?)
    # Attach is a read function, only has potential for a change
    if( $TWiki::cfg{Log}{attach} ) {
        # write log entry
        $session->writeLog( 'attach', $webName.'.'.$topic, $fileName );
    }

    my $fileWikiUser = '';
    if( $fileName ) {
        $tmpl = $session->{templates}->readTemplate( 'attachagain', $skin );
        my $u = $session->{users}->findUser( $args->{user} );
        $fileWikiUser = $u->webDotWikiName() if $u;
    } else {
        $tmpl = $session->{templates}->readTemplate( 'attachnew', $skin );
    }
    if ( $fileName ) {
        # must come after templates have been read
        $atext .= $session->{attach}->formatVersions( $webName, $topic, %$args );
    }
    $tmpl =~ s/%ATTACHTABLE%/$atext/go;
    $tmpl =~ s/%FILEUSER%/$fileWikiUser/go;
    $session->enterContext( 'can_render_meta', $meta );
    $tmpl = $session->handleCommonTags( $tmpl, $webName, $topic );
    $tmpl = $session->{renderer}->getRenderedVersion( $tmpl, $webName, $topic );
    $tmpl =~ s/%HIDEFILE%/$isHideChecked/go;
    $tmpl =~ s/%FILENAME%/$fileName/go;
    $tmpl =~ s/%FILEPATH%/$args->{path}/go;
    $tmpl =~ s/%FILECOMMENT%/$args->{comment}/go;

    $session->writeCompletePage( $tmpl );
}

=pod

---++ StaticMethod upload( $session )

=upload= command handler.
This method is designed to be
invoked via the =TWiki::UI::run= method.
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

    my $hideFile = $query->param( 'hidefile' ) || '';
    my $fileComment = $query->param( 'filecomment' ) || '';
    my $createLink = $query->param( 'createlink' ) || '';
    my $doPropsOnly = $query->param( 'changeproperties' );
    my $filePath = $query->param( 'filepath' ) || '';
    my $fileName = $query->param( 'filename' ) || '';
    if ( $filePath && ! $fileName ) {
        $filePath =~ m|([^/\\]*$)|;
        $fileName = $1;
    }

    $fileComment =~ s/\s+/ /go;
    $fileComment =~ s/^\s*//o;
    $fileComment =~ s/\s*$//o;

    TWiki::UI::checkWebExists( $session, $webName, $topic, 'attach files to' );
    TWiki::UI::checkTopicExists( $session, $webName, $topic, 'attach files to' );
    TWiki::UI::checkMirror( $session, $webName, $topic );
    TWiki::UI::checkAccess( $session, $webName, $topic,
                            'change', $user );

    my ( $fileSize, $fileDate, $tmpFileName );

    my $stream;
    $stream = $query->upload( 'filepath' ) unless ( $doPropsOnly );

    unless( $doPropsOnly ) {
        # cut path from filepath name (Windows '\' and Unix "/" format)
        my @pathz = ( split( /\\/, $filePath ) );
        my $filetemp = $pathz[$#pathz];
        my @pathza = ( split( '/', $filetemp ) );
        $fileName = $pathza[$#pathza];

        # Check that name isn't filtered for upload
        # Check that name doesn't contain illegal chars
        if( $fileName =~ /$TWiki::cfg{UploadFilter}/ ||
              $fileName =~ /$TWiki::cfg{NameFilter}/ ) {
            my $e1 = $TWiki::cfg{UploadFilter};
            $e1 =~ s#\(\?-xism:(.*)\)$#/$1/#;
            my $e2 = $TWiki::cfg{NameFilter};
            $e2 =~ s#\(\?-xism:(.*)\)$#/$1/#;
            throw TWiki::OopsException( 'attention',
                                        def => 'illegally_named_upload',
                                        web => $webName,
                                        topic => $topic,
                                        params =>
                                          [ $fileName,
                                            $e1,
                                            $e2 ] );
        }

        $fileName = TWiki::Sandbox::untaintUnchecked( $fileName );

        ##$session->writeDebug ("Upload filename after cleanup is '$fileName'");

        # check if upload has non zero size
        my @stats = stat $stream;
        $fileSize = $stats[7];
        $fileDate = $stats[9];

        if( ! $fileSize ) {
            throw TWiki::OopsException( 'attention',
                                        def => 'zero_size_upload',
                                        web => $webName,
                                        topic => $topic,
                                        params => ($fileName || '""') );
        }

        my $maxSize = $session->{prefs}->getPreferencesValue( 'ATTACHFILESIZELIMIT' );
        $maxSize = 0 unless ( $maxSize =~ /([0-9]+)/o );

        if( $maxSize && $fileSize > $maxSize * 1024 ) {
            throw TWiki::OopsException( 'attention',
                                        def => 'oversized_upload',
                                        web => $webName,
                                        topic => $topic,
                                        params => [ $fileName, $maxSize ] );
        }
    }

    try {
        $session->{store}->saveAttachment(
            $webName, $topic, $fileName, $user,
            { dontlog => !$TWiki::cfg{Log}{upload},
              comment => $fileComment,
              hide => $hideFile,
              createlink => $createLink,
              stream => $stream,
              filepath => $filePath,
              filesize => $fileSize,
              filedate => $fileDate,
          } );
    } catch Error::Simple with {
        throw TWiki::OopsException( 'attention',
                                    def => 'save_error',
                                    web => $webName,
                                    topic => $topic,
                                    params => shift->{-text} );
    };

    close( $stream ) if $stream;

    $session->redirect( $session->getScriptUrl( $webName, $topic, 'view' ) );

    # generate a message useful for those calling this script from the command line
    my $message = ( $doPropsOnly ) ?
      'properties changed' : "$fileName uploaded";

    print 'OK ',$message,"\n";
}

1;
