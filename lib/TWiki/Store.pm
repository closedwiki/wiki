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

---+ package TWiki::Store

This module hosts the generic storage backend. This module should be the
only module, anywhere, that knows that meta-data is stored interleaved
in the topic text. This is so it can be easily replaced by alternative
store implementations.

=cut

package TWiki::Store;

use File::Copy;
use TWiki::Meta;
use TWiki::Time;
use TWiki::AccessControlException;
use Assert;
use Error qw( :try );

use strict;

=pod

---++ ClassMethod new()

Construct a Store module, linking in the chosen sub-implementation.

=cut

sub new {
    my ( $class, $session ) = @_;
    ASSERT(ref($session) eq 'TWiki') if DEBUG;

    # Do a dynamic 'use locale' for this module
    if( $TWiki::cfg{UseLocale} ) {
        require locale;
    }

    my $this = bless( {}, $class );

    $this->{session} = $session;

    $this->{IMPL} = 'TWiki::Store::'.$TWiki::cfg{StoreImpl};
    eval "use $this->{IMPL}";
    if( $@ ) {
        die "$this->{IMPL} compile failed $@";
    }

    return $this;
}

# PRIVATE
# Get the handler for the current store implementation, either RcsFile
# or RcsLite
sub _getTopicHandler {
    my( $this, $web, $topic, $attachment ) = @_;

    $attachment = '' if( ! $attachment );

    ASSERT($TWiki::cfg{StoreImpl}) if DEBUG;
    my $handlerName = "TWiki::Store::$TWiki::cfg{StoreImpl}";

    return $this->{IMPL}->new( $this->{session}, $web, $topic,
                               $attachment );
}

=pod

---++ ObjectMethod readTopic($user, $web, $topic, $version) -> ($metaObject, $text)

Reads the given version of a topic and it's meta-data. If the version
is undef, then read the most recent version. The version number must be
an integer, or undef for the latest version.

If $user is defined, view permission will be required for the topic
read to be successful.  Access control violations are flagged by a
TWiki::AccessControlException. Permissions are checked for the user
name passed in.

If the topic contains a web specification (is of the form Web.Topic) the
web specification will override whatever is passed in $theWeb.

The metadata and topic text are returned separately, with the metadata in a
TWiki::Meta object.  (The topic text is, as usual, just a string.)

=cut

sub readTopic {
    my( $this, $user, $theWeb, $theTopic, $version ) = @_;
    ASSERT(ref($this) eq 'TWiki::Store') if DEBUG;

    my $text = $this->readTopicRaw( $user, $theWeb, $theTopic, $version );
    my $meta = $this->extractMetaData( $theWeb, $theTopic, \$text );
    return( $meta, $text );
}

=pod

---++ ObjectMethod readTopicRaw( $user, $web, $topic, $version ) ->  $topicText

Reads the given version of a topic, without separating out any embedded
meta-data. If the version is undef, then read the most recent version.
The version number must be an integer or undef.

If $user is defined, view permission will be required for the topic
read to be successful.  Access control violations are flagged by a
TWiki::AccessControlException. Permissions are checked for the user
name passed in.

If the topic contains a web specification (is of the form Web.Topic) the
web specification will override whatever is passed in $theWeb.

SMELL: DO NOT CALL THIS METHOD UNLESS YOU HAVE NO CHOICE. This method breaks
encapsulation of the store, as it assumes meta is stored embedded in the text.
Other implementors of store will be forced to insert meta-data to ensure
correct operation of View raw=debug and the 'repRev' mode of Edit.

=cut

sub readTopicRaw {
    my( $this, $user, $theWeb, $theTopic, $version ) = @_;
    ASSERT(ref($this) eq 'TWiki::Store') if DEBUG;

    # test if theTopic contains a webName to override $theWeb
    ( $theWeb, $theTopic ) =
      $this->{session}->normalizeWebTopicName( $theWeb, $theTopic );

    my $text;

    unless ( $version ) {
        $text = $this->readFile( "$TWiki::cfg{DataDir}/$theWeb/$theTopic.txt" );
    } else {
        my $topicHandler = $this->_getTopicHandler( $theWeb, $theTopic, undef );
        $text = $topicHandler->getRevision( $version );
    }

    if( $user &&
        !$this->{session}->{security}->checkAccessPermission
        ( 'view', $user, $text, $theTopic, $theWeb )) {
        throw TWiki::AccessControlException( 'VIEW', $user,
                                             $theWeb, $theTopic,
                                             $this->{session}->{security}->getReason());
    }

    return $text;
}

=pod

---++ ObjectMethod moveAttachment (  $oldWeb, $oldTopic, $newWeb, $newTopic, $theAttachment, $user  ) -> $error

Move an attachment from one topic to another.

If there is a problem an error string is returned, or may throw an exception.

The caller to this routine should check that all topics are valid.

SMELL: $user must be the user login name, not their wiki name

=cut

sub moveAttachment {
    my( $this, $oldWeb, $oldTopic, $newWeb, $newTopic,
        $theAttachment, $user ) = @_;
    ASSERT(ref($this) eq 'TWiki::Store') if DEBUG;
    ASSERT(ref($user) eq 'TWiki::User') if DEBUG;

    $this->lockTopic( $user, $oldWeb, $oldTopic );

    my( $ometa, $otext ) = $this->readTopic( undef, $oldWeb, $oldTopic );
    if( $user &&
        !$this->{session}->{security}->checkAccessPermission
        ( 'change', $user, $otext, $oldTopic, $oldWeb )) {
        throw TWiki::AccessControlException( 'CHANGE', $user,
                                             $oldWeb, $oldTopic,
                                             $this->{session}->{security}->getReason());
    }

    my ( $nmeta, $ntext ) = $this->readTopic( undef, $newWeb, $newTopic );
    if( $user &&
        !$this->{session}->{security}->checkAccessPermission
        ( 'change', $user, $ntext, $newTopic, $newWeb )) {
        throw TWiki::AccessControlException( 'CHANGE', $user,
                                             $newWeb, $newTopic,
                                             $this->{session}->{security}->getReason());
    }

    # Remove file attachment from old topic
    my $topicHandler =
      $this->_getTopicHandler( $oldWeb, $oldTopic, $theAttachment );
    my $error = $topicHandler->moveMe( $newWeb, $newTopic );

    if( $error ) {
        $this->unlockTopic( $user, $oldWeb, $oldTopic );
        $this->unlockTopic( $user, $newWeb, $newTopic );
        return $error;
    }

    my $fileAttachment =
      $ometa->get( 'FILEATTACHMENT', $theAttachment );
    $ometa->remove( 'FILEATTACHMENT', $theAttachment );
    $error = $this->_noHandlersSave( $user, $oldWeb, $oldTopic,
                                     $otext, $ometa,
                                     { notify => 0 } );

    $this->unlockTopic( $user, $oldWeb, $oldTopic );
    if( $error ) {
        $this->unlockTopic( $user, $newWeb, $newTopic );
        return $error;
    }

    # Add file attachment to new topic
    $fileAttachment->{movefrom} = $oldWeb.'.'.$oldTopic;
    $fileAttachment->{moveby}   = $user->webDotWikiName();
    $fileAttachment->{movedto}  = $newWeb.'.'.$newTopic;
    $fileAttachment->{movedwhen} = time();
    $nmeta->put( 'FILEATTACHMENT', $fileAttachment );

    $error = $this->_noHandlersSave( $user, $newWeb, $newTopic, $ntext,
                                      $nmeta, { notify => 0,
                                               comment => 'moved' } );

    $this->unlockTopic( $user, $newWeb, $newTopic );

    return $error if( $error );

    $this->{session}->writeLog( 'move', $oldWeb.'.'.$oldTopic,
                     "Attachment $theAttachment moved to $newWeb.$newTopic" );


    return $error;
}

=pod

---++ ObjectMethod getAttachmentStream( $user, $web, $topic, $attName ) -> \*STREAM
   * =$user= - the user doing the reading, or undef if no access checks
   * =$web= - The web
   * =$topic= - The topic
   * =$attName= - Name of the attachment

Open a standard input stream from an attachment. Will return undef
if the stream could not be opened (permissions, or nonexistant etc)

If $user is defined, view permission will be required for the topic
read to be successful.  Access control violations are flagged by a
TWiki::AccessControlException. Permissions are checked for the user
name passed in.

=cut

sub getAttachmentStream {
    my ( $this, $user, $web, $topic, $att ) = @_;
    ASSERT(ref($this) eq 'TWiki::Store') if DEBUG;

    if( $user &&
        !$this->{session}->{security}->checkAccessPermission
        ( 'view', $user, undef, $topic, $web )) {
        throw TWiki::AccessControlException( 'VIEW', $user, $web, $topic,
                                           $this->{session}->{security}->getReason());
    }

    my $topicHandler = $this->_getTopicHandler( $web, $topic, $att );
    my $strm = $topicHandler->getStream();
    unless( $strm ) {
        $this->{session}->writeWarning( $topicHandler->lastError() );
    }
    return $strm;
}

=pod

---++ ObjectMethod attachmentExists( $web, $topic, $att ) -> $boolean

Determine if the attachment already exists on the given topic

=cut

sub attachmentExists {
    my $this = shift;
    #my ( $web, $topic, $att ) = @_;

    ASSERT(ref($this) eq 'TWiki::Store') if DEBUG;
    my $topicHandler = $this->_getTopicHandler( @_ );
    return -e $topicHandler->{file};
}

# PRIVATE
# When moving a topic to another web, change within-web refs from
# this topic so that they'll work when the topic is in the new web.
# I have a feeling this shouldn't be in Store.pm.
#
# SMELL: It has to be - it knows about %META in topics. If you can
# eliminate that dependency, then it could move somewhere else.
sub _changeRefTo {
   my( $this, $text, $oldWeb, $oldTopic ) = @_;

   my $preTopic = '^|[\*\s\[][-\(\s]*';
   # I18N: match non-alpha before/after topic names
   my $alphaNum = $TWiki::regex{mixedAlphaNum};
   my $postTopic = '$|' . "[^${alphaNum}_.]" . '|\.\s';
   my $metaPreTopic = '"|[\s[,\(-]';
   my $metaPostTopic = "[^${alphaNum}_.]" . '|\.\s';
   
   my $out = '';
   
   # Get list of topics in $oldWeb, replace local refs to these topics with full web.topic
   # references
   my @topics = $this->getTopicNames( $oldWeb );
   
   my $insidePRE = 0;
   my $insideVERBATIM = 0;
   my $noAutoLink = 0;
   
   foreach( split( /\n/, $text ) ) {
       if( /^%META:TOPIC(INFO|MOVED)/ ) {
           $out .= "$_\n";
           next;
       }

       # change state:
       m|<pre>|i  && ( $insidePRE = 1 );
       m|</pre>|i && ( $insidePRE = 0 );
       if( m|<verbatim>|i ) {
           $insideVERBATIM = 1;
       }
       if( m|</verbatim>|i ) {
           $insideVERBATIM = 0;
       }
       m|<noautolink>|i   && ( $noAutoLink = 1 );
       m|</noautolink>|i  && ( $noAutoLink = 0 );
   
       if( ! ( $insidePRE || $insideVERBATIM || $noAutoLink ) ) {
           # Fairly inefficient, time will tell if this should be changed.
           foreach my $topic ( @topics ) {
              if( $topic ne $oldTopic ) {
                  if( /^%META:/ ) {
                      s/^(%META:FILEATTACHMENT.*? user\=\")(\w)/$1$TWiki::TranslationToken$2/;
                      s/^(%META:TOPICMOVED.*? by\=\")(\w)/$1$TWiki::TranslationToken$2/;
                      s/($metaPreTopic)\Q$topic\E(?=$metaPostTopic)/$1$oldWeb.$topic/g;
                      s/$TWiki::TranslationToken//;
                  } else {
                      s/($preTopic)\Q$topic\E(?=$postTopic)/$1$oldWeb.$topic/g;
                  }
              }
           }
       }
       $out .= "$_\n";
   }

   return $out;
}

=pod

---++ ObjectMethod renameTopic(  $oldWeb, $oldTopic, $newWeb, $newTopic, $doChangeRefTo  $user ) -> $error

Rename a topic, allowing for transfer between Webs. This method will change
all references _from_ this topic to other topics _within the old web_
so they still work after it has been moved to a new web.

It is the responsibility of the caller to check for existence of webs,
topics & lock taken for topic

SMELL: $user must be the user login name, not their wiki name

=cut

sub renameTopic {
    my( $this, $oldWeb, $oldTopic, $newWeb, $newTopic, $doChangeRefTo, $user ) = @_;
    ASSERT(ref($this) eq 'TWiki::Store') if DEBUG;
    ASSERT(ref($user) eq 'TWiki::User') if DEBUG;

    # will block
    $this->lockTopic( $user, $oldWeb, $oldTopic );

    my $otext = $this->readTopicRaw( undef, $oldWeb, $oldTopic );
    if( $user &&
        !$this->{session}->{security}->checkAccessPermission
        ( 'change', $user, $otext, $oldTopic, $oldWeb )) {
        throw TWiki::AccessControlException( 'CHANGE', $user,
                                             $oldWeb, $oldTopic,
                                             $this->{session}->{security}->getReason());
    }

    my ( $nmeta, $ntext ) = $this->readTopic( undef, $newWeb, $newTopic );
    if( $user &&
        !$this->{session}->{security}->checkAccessPermission
        ( 'change', $user, $ntext, $newTopic, $newWeb )) {
        throw TWiki::AccessControlException( 'CHANGE', $user,
                                             $newWeb, $newTopic,
                                           $this->{session}->{security}->getReason());
    }

    my $topicHandler = $this->_getTopicHandler( $oldWeb, $oldTopic, '' );
    my $error = $topicHandler->moveMe( $newWeb, $newTopic );

    if( ! $error ) {
        my $time = time();
        my $text = $this->readTopicRaw( undef, $newWeb, $newTopic, undef );
        if( ( $oldWeb ne $newWeb ) && $doChangeRefTo ) {
            $text = $this->_changeRefTo( $text, $oldWeb, $oldTopic );
        }
        my $meta = $this->extractMetaData( $newWeb, $newTopic, \$text );
        $meta->put( 'TOPICMOVED',
                    {
                     from => $oldWeb.'.'.$oldTopic,
                     to   => $newWeb.'.'.$newTopic,
                     date => $time,
                     # SMELL: surely this should be wikiUserName?
                     by   => $user->wikiName(),
                    } );

        $this->_noHandlersSave( $user, $newWeb, $newTopic, $text, $meta,
                                { comment => 'renamed' } );
    }

    $this->unlockTopic( $user, $oldWeb, $oldTopic );

    # Log rename
    if( $TWiki::cfg{Log}{rename} ) {
        my $old = $oldWeb.'.'.$oldTopic;
        my $new = $newWeb.'.'.$newTopic;
        $error ||= '';
        $this->{session}->writeLog( 'rename', $old,
                                    "moved to $new $error" );
    }

    return $error;
}

=pod

---++ ObjectMethod updateReferringPages( $oldWeb, $oldTopic, $user, $newWeb, $newTopic, @refs  ) -> ( $countoflockfailures, $resulttext)

Update pages that refer to a page that is being renamed/moved. Return the
number of updates that failed due to active locks and a message.

SMELL: This breaks the encapsulation of the Render function quite horribly.
It should really be done by asking the Renderer to render the topic with
a bunch of simplified handlers plugged in, and just one handler (the
handler for TWiki links) provided to change the link name.

=cut

sub updateReferringPages {
    my ( $this, $oldWeb, $oldTopic, $user, $newWeb, $newTopic, @refs ) = @_;
    ASSERT(ref($this) eq 'TWiki::Store') if DEBUG;
    ASSERT(ref($user) eq 'TWiki::User') if DEBUG;

    my $result = '';

    # SMELL: this is stinky; according to Render.pm this should be [\s\(] but that
    # assumes that each line is protected by spaces either side. Then, this
    # code does replacements in meta-data as well, so things like field names and
    # data values all get munged (!!!!) - good grief, what a hack!
    # SMELL: does not handle <nop> before the wikiword
    my $preTopic = qr/^|[^!\w]/;    # Start of line or non-alphanumeric and not !
    my $postTopic = qr/s?(?=$|\W)/;	# End of line or non-alphanumeric; s? for plurals
    my $spacedTopic = TWiki::spaceOutWikiWord( $oldTopic );
    $spacedTopic =~ s/ / */g;
    my $lockFailures = 0;

    while ( @refs ) {
        my $type = shift @refs;
        my $item = shift @refs;
        my( $itemWeb, $itemTopic ) = $this->{session}->normalizeWebTopicName( '', $item );
        my $insertWeb = ($itemWeb eq $newWeb) ? '' : "$newWeb.";

        my $newItemText = '';
        $result .= ":$item: , "; 
        #open each file, replace $topic with $newTopic
        if ( $this->topicExists($itemWeb, $itemTopic) ) {
            $this->lockTopic( $user, $itemWeb, $itemTopic );
            my $scantext =
              $this->readTopicRaw( undef, $itemWeb, $itemTopic, undef );
            if( $user &&
                !$this->{session}->{security}->checkAccessPermission( 'change',
                                                           $user,
                                                           $scantext,
                                                           $itemWeb,
                                                           $itemTopic ) ) {
                # This shouldn't happen, as search will not return, but
                # check to be on the safe side
                $this->{session}->writeWarning( "rename: attempt to change $itemWeb.$itemTopic without permission" );
                $this->unlockTopic( $user, $itemWeb, $itemTopic );
                next;
            }
            my $insidePRE = 0;
            my $insideVERBATIM = 0;
            my $noAutoLink = 0;
            foreach my $line ( split( /\r?\n/, $scantext ) ) {
                if( $line =~ /^%META:TOPIC(INFO|MOVED)/ ) {
                    $newItemText .= "$line\n";
                    next;
                }
                # SMELL: This code is in far too many places - also in Search.pm and Render.pm
                $insidePRE      = 1 if( $line =~ m|<pre>|i );
                $insidePRE      = 0 if( $line =~ m|</pre>|i );
                $insideVERBATIM = 1 if( $line =~ m|<verbatim>|i );
                $insideVERBATIM = 0 if( $line =~ m|</verbatim>|i );
                $noAutoLink     = 1 if( $line =~ m|<noautolink>|i );
                $noAutoLink     = 0 if( $line =~ m|</noautolink>|i );
                # SMELL: this replaces within META!!
                unless ( $insidePRE || $insideVERBATIM || $noAutoLink ) {
                    $line =~ s/($preTopic)\Q$oldWeb.$oldTopic\E(?=$postTopic)/$1$insertWeb$newTopic/g;
                    # Only replace bare topic (i.e. not preceded by web) if
                    # the web of the referring topic is the original web of
                    # the topic that's being moved.
                    if( $oldWeb eq $itemWeb ) {
                        # SMELL: these searches are not consistent with
                        # what is expanded in Render.pm
                        $line =~ s/($preTopic)\Q$oldTopic\E(?=$postTopic)/$1$insertWeb$newTopic/g;
                        $line =~ s/\[\[($spacedTopic)\]\]/[[$newTopic][$1]]/gi;
                    }
                }
                $newItemText .= "$line\n";
            }
            my $meta = $this->extractMetaData( $itemWeb, $itemTopic,
                                               \$newItemText );
            $this->saveTopic( $user, $itemWeb, $itemTopic,
                              $newItemText, $meta,
                              { minor => 1 } );
            $this->unlockTopic( $user, $itemWeb, $itemTopic );
        } else {
            $result .= ";$item does not exist;";
        }
    }
    return $result;
}


=pod

---++ ObjectMethod readAttachment( $user, $theWeb, $theTopic, $theAttachment, $theRev  ) -> $text

Read the given version of an attachment, returning the content.

View permission on the topic is required for the
read to be successful.  Access control violations are flagged by a
TWiki::AccessControlException. Permissions are checked for the user
name passed in.

=cut

sub readAttachment {
    my ( $this, $user, $theWeb, $theTopic, $theAttachment, $theRev ) = @_;

    ASSERT(ref($this) eq 'TWiki::Store') if DEBUG;

    if( $user &&
        !$this->{session}->{security}->checkAccessPermission
        ( 'change', $user, undef, $theTopic, $theWeb )) {
        throw TWiki::AccessControlException( 'CHANGE', $user,
                                             $theWeb, $theTopic,
                                             $this->{session}->{security}->getReason());
    }

    my $topicHandler = $this->_getTopicHandler( $theWeb, $theTopic, $theAttachment );
    return $topicHandler->getRevision( $theRev );
}

=pod

---++ ObjectMethod getRevisionNumber ( $theWebName, $theTopic, $attachment  ) -> $integer

Get the revision number of the most recent revision. Returns
the integer revision number or '' if the topic doesn't exist.

WORKS FOR ATTACHMENTS AS WELL AS TOPICS

=cut

sub getRevisionNumber {
    my( $this, $theWebName, $theTopic, $attachment ) = @_;
    ASSERT(ref($this) eq 'TWiki::Store') if DEBUG;

    $attachment = '' unless $attachment;

    my $topicHandler = $this->_getTopicHandler( $theWebName, $theTopic, $attachment );
    return $topicHandler->numRevisions();
}


=pod

---++ ObjectMethod getRevisionDiff (  $web, $topic, $rev1, $rev2, $contextLines  ) -> \@diffArray

Return reference to an array of [ diffType, $right, $left ]

   * =$webName= - the web
   * =$topic= - the topic
   * =$rev1= Integer revision number
   * =$rev2= Integer revision number
   * =$contextLines= - number of lines of context required

=cut

sub getRevisionDiff {
    my( $this, $web, $topic, $rev1, $rev2, $contextLines ) = @_;
    ASSERT(ref($this) eq 'TWiki::Store') if DEBUG;
    ASSERT(defined($contextLines)) if DEBUG;

    my $rcs = $this->_getTopicHandler( $web, $topic );
    my( $error, $diffArrayRef ) =
      $rcs->revisionDiff( $rev1, $rev2, $contextLines );
    return $diffArrayRef;
}


=pod

---++ ObjectMethod getRevisionInfo($theWebName, $theTopic, $theRev, $attachment, $topicHandler) -> ( $date, $user, $rev, $comment )
Get revision info of a topic
   * =$theWebName= Web name, optional, e.g. ='Main'=
   * =$theTopic= Topic name, required, e.g. ='TokyoOffice'=
   * =$theRev= revision number
   * =$attachment= ttachment filename
   * =$topicHandler= internal store use only
Return list with: ( last update date, login name of last user, integer revision number ), e.g. =( 1234561, 'phoeny', '5' )=
| $date | in epochSec |
| $user | user *object* |
| $rev | the revision number |
| $comment | WHAT COMMENT? |

=cut

sub getRevisionInfo {
    my( $this, $web, $topic, $theRev, $attachment, $topicHandler ) = @_;
    ASSERT(ref($this) eq 'TWiki::Store') if DEBUG;

    $theRev = 0 unless( $theRev );

    unless( $topicHandler ) {
        $topicHandler =
          $this->_getTopicHandler( $web, $topic, $attachment );
    }
    my( $rcsOut, $rev, $date, $user, $comment ) =
      $topicHandler->getRevisionInfo( $theRev );
    $user = $this->{session}->{users}->findUser( $user ) if $user;

    return ( $date, $user, $rev, $comment );
}

# STATIC Build a hash by parsing name=value comma separated pairs
# SMELL: duplication of TWiki::Attrs, using a different
# system of escapes :-(
sub _readKeyValues {
    my( $args ) = @_;
    my $res = {};

    # Format of data is name='value' name1='value1' [...]
    while( $args =~ s/\s*([^=]+)=\"([^"]*)\"//o ) {
        my $key = $1;
        my $value = $2;
        # reverse the encoding in _writeKeyValue
        $value =~ s/%_N_%/\n/g;
        $value =~ s/%_Q_%/\"/g;
        $value =~ s/%_P_%/%/g;
        $value =~ s/&/&amp\;/go;
        $value =~ s/</&lt\;/go;
        $value =~ s/>/&gt\;/go;
        $res->{$key} = $value;
    }

    return $res;
}

=pod

---++ ObjectMethod saveTopic (  $user, $web, $topic, $text, $meta, $options  ) -> $error
   * =$user= - login name of user doing the saving
   * =$web= - web for topic
   * =$topic= - topic to atach to
   * =$text= - topic text
   * =$meta= - topic meta-data
   * =$options= - Ref to hash of options
=$options= may include:
| =dontlog= | don't log this change in twiki log |
| =hide= | if the attachment is to be hidden in normal topic view |
| =comment= | comment for save |
| =file= | Temporary file name to upload |
| =minor= | True if this is a minor change (used in log) |
| =savecmd= | Save command |
| =forcedate= | grr |
| =unlock= | |

Save a new revision of the topic, calling plugins handlers as appropriate.

=cut

sub saveTopic {
    my( $this, $user, $web, $topic, $text, $meta, $options ) = @_;
    ASSERT(ref($this) eq 'TWiki::Store') if DEBUG;
    ASSERT(ref($user) eq 'TWiki::User') if DEBUG;

    $options = {} unless defined( $options );

    if( $user &&
        !$this->{session}->{security}->checkAccessPermission
        ( 'change', $user, undef, $topic, $web )) {

        throw TWiki::AccessControlException( 'CHANGE', $user, $web, $topic,
                                             $this->{session}->{security}->getReason());
    }

    my $plugins = $this->{session}->{plugins};

    if( $plugins->haveHandlerFor( 'beforeSaveHandler' )) {
        if( $meta ) {
            # SMELL: Staggeringly inefficient code that adds meta-data for
            # Plugin callback. Why not simply pass the meta in? It would be far
            # more sensible.
            $text = _writeMeta( $meta, $text );
        }

        $plugins->beforeSaveHandler( $text, $topic, $web );

        # remove meta data again, and throw any new meta data
        # away!!!! That's CRAP.
        $this->extractMetaData( $web, $topic, \$text );
    }

    my $error =
      $this->_noHandlersSave( $user, $web, $topic, $text, $meta,
                              $options );

    $plugins->afterSaveHandler( $text, $topic, $web, $error );

    return $error;
}

=pod

---++ ObjectMethod saveAttachment ($web, $topic, $attachment, $user, $opts ) -> $error
   * =$user= - user doing the saving
   * =$web= - web for topic
   * =$topic= - topic to atach to
   * =$attachment= - name of the attachment
   * =$opts= - Ref to hash of options
=$opts= may include:
| =dontlog= | don't log this change in twiki log |
| =minor= | don't log this change in .changes |
| =hide= | if the attachment is to be hidden in normal topic view |
| =comment= | comment for save |
| =file= | Temporary file name to upload |

Saves a new revision of the attachment, invoking plugin handlers as
appropriate.

If file is not set, this is a properties-only save.

=cut

sub saveAttachment {
    my( $this, $web, $topic, $attachment, $user, $opts ) = @_;
    ASSERT(ref($this) eq 'TWiki::Store') if DEBUG;
    ASSERT(ref($user) eq 'TWiki::User') if DEBUG;
    ASSERT(defined($opts)) if DEBUG;
    my $action;
    my $plugins = $this->{session}->{plugins};

    $this->lockTopic( $user, $web, $topic );

    # update topic
    my( $meta, $text ) = $this->readTopic( undef, $web, $topic, undef );

    if( $user &&
        !$this->{session}->{security}->checkAccessPermission
        ( 'change', $user, $text, $topic, $web )) {

        throw TWiki::AccessControlException( 'CHANGE', $user, $web, $topic,
                                           $this->{session}->{security}->getReason());
    }

    if ( $opts->{file} ) {
        my $fileVersion = $this->getRevisionNumber( $web, $topic,
                                                    $attachment );
        $action = 'upload';

        my $attrs =
          {
           attachment => $attachment,
           tmpFilename => $opts->{file},
           comment => $opts->{comment},
           user => $user->webDotWikiName()
          };

        my $topicHandler = $this->_getTopicHandler( $web, $topic, $attachment );
        $plugins->beforeAttachmentSaveHandler( $attrs, $topic, $web );
        my $error = $topicHandler->addRevision( $opts->{file},
                                                $opts->{comment},
                                                $user->wikiName() );

        $plugins->afterAttachmentSaveHandler( $attrs,
                                              $topic, $web, $error );

        return "attachment save failed: $error" if $error;

        $attrs->{name} = $attachment;
        $attrs->{version} = $fileVersion;
        $attrs->{path} = $opts->{filepath},;
        $attrs->{size} = $opts->{filesize};
        $attrs->{date} = $opts->{filedate};
        $attrs->{attr} = ( $opts->{hide} ) ? 'h' : '';

        $meta->put( 'FILEATTACHMENT', $attrs );
    } else {
        my $attrs = $meta->get( 'FILEATTACHMENT', $attachment );
        $attrs->{attr} = ( $opts->{hide} ) ? 'h' : '';
        $attrs->{comment} = $opts->{comment};
        $meta->put( 'FILEATTACHMENT', $attrs );
    }

    if( $opts->{createlink} ) {
        $text .= $this->{session}->{attach}->getAttachmentLink( $user, $web, $topic,
                                                   $attachment, $meta );
    }

    my $error = $this->saveTopic( $user, $web, $topic, $text, $meta, {} );

    $this->unlockTopic( $user, $web, $topic );

    unless( $error || $opts->{dontlog} ) {
        $this->{session}->writeLog( $action, $web.'.'.$topic, $attachment );
    }

    return $error;
}

# Save a topic or attachment _without_ invoking plugin handlers.
# Return non-null string if there is an error.
# FIXME: does rev info from meta work if user saves a topic with no change?
sub _noHandlersSave {
    my( $this, $user, $web, $topic, $text, $meta, $options ) = @_;

    ASSERT(ref($user) eq 'TWiki::User') if DEBUG;

    my $topicHandler = $this->_getTopicHandler( $web, $topic );
    my $currentRev = $topicHandler->numRevisions() || 0;

    my $nextRev = $currentRev + 1;

    if( $currentRev && !$options->{forcenewrevision} ) {
        # See if we want to replace the existing top revision
        my $mtime1 = $topicHandler->getTimestamp();
        my $mtime2 = time();

        if( abs( $mtime2 - $mtime1 ) <
            $TWiki::cfg{ReplaceIfEditedAgainWithin} ) {

            my( $date, $revuser ) =
              $this->getRevisionInfo( $web, $topic, $currentRev,
                               undef, $topicHandler );
            # same user?
            if(  $revuser->equals( $user )) {
                return repRev( @_ );
            }
        }
    }

    if( $meta ) {
        $meta->addTOPICINFO( $web, $topic, $nextRev );
        $text = _writeMeta( $meta, $text );
    }

    # RCS requires a newline for the last line,
    $text =~ s/([^\n\r])$/$1\n/os;

    # will block
    $this->lockTopic( $user, $web, $topic );
    my $error =
      $topicHandler->addRevision( $text, $options->{comment},
                                  $user->wikiName() );

    $this->unlockTopic( $user, $web, $topic );

    return $error if( $error );

    # update .changes
    my @foo = split( /\n/, $this->readMetaData( $web, 'changes' ));
    shift( @foo) if( $#foo > 500 );
    my $minor = '';
    $minor = "\tminor" if $options->{minor};
    push( @foo, "$topic\t".$user->login()."\t".time()."\t$nextRev$minor" );
    $this->saveMetaData( $web, 'changes', join( "\n", @foo ));
    close(FILE);

    if( ( $TWiki::cfg{Log}{save} ) && ! ( $options->{dontlog} ) ) {
        # write log entry
        my $extra = '';
        $extra   .= 'minor' if( $options->{minor} );
        $this->{session}->writeLog( 'save', $web.'.'.$topic, $extra );
    }

    return '';
}

=pod

---++ ObjectMethod repRev( $user, $web, $topic, $text, $meta, $options ) -> $error
Replace last (top) revision with different text.

Parameters and return value as saveTopic, except
   * =$options= - as for saveTopic, with the extra option:
      * =timetravel= - if we want to force the deposited revision to look as much like the revision specified in =$rev= as possible.

Used to try to avoid the deposition of 'unecessary' revisions, for example
where a user quickly goes back and fixes a spelling error.

Also provided as a means for administrators to rewrite history (timetravel).

It is up to the store implementation if this is different
to a normal save or not.

=cut

sub repRev {
    my( $this, $user, $web, $topic, $text, $meta, $options ) = @_;

    $this->lockTopic( $user, $web, $topic );

    my( $revdate, $revuser, $rev ) =
      $meta->getRevisionInfo( $web, $topic, '', undef );

    # RCS requires a newline for the last line,
    $text =~ s/([^\n\r])$/$1\n/os;

    if( $options->{timetravel} ) {
        # We are trying to force the rev to be saved with the same date
        # and user as the prior rev. However, exactly the same date may
        # cause some revision control systems to barf, so to avoid this we
        # add 1 minute to the rev time. Note that this mode of operation
        # will normally require sysadmin privilege, as it can result in
        # confused rev dates if abused.
        $revdate += 60;
    } else {
        # use defaults (current time, current user)
        $revdate = time();
        $revuser = $user;
    }
    $meta->addTOPICINFO( $web, $topic, $rev, $revdate, $revuser );
    $text = _writeMeta( $meta, $text );

    my $topicHandler = $this->_getTopicHandler( $web, $topic );
    my $error =
      $topicHandler->replaceRevision( $text, $options->{comment},
                                      $revuser->wikiName(), $revdate );
    return $error if( $error );

    $this->unlockTopic( $user, $web, $topic );

    if( ( $TWiki::cfg{Log}{save} ) && ! ( $options->{dontlog} ) ) {
        # write log entry
        my $extra = 'repRev by '.$user->login().": $rev " .
          $revuser->login().
            ' '. TWiki::Time::formatTime( $revdate, 'rcs', 'gmtime' );
        $extra   .= ' minor' if( $options->{minor} );
        $this->{session}->writeLog( 'save', $web.'.'.$topic, $extra );
    }
    return '';
}

=pod

---++ ObjectMethod delRev( $user, $web, $topic, $text, $meta, $options ) -> $error

Parameters and return value as saveTopic.

Provided as a means for administrators to rewrite history.

Delete last entry in repository, restoring the previous
revision.

It is up to the store implementation whether this actually
does delete a revision or not; some implementations will
simply promote the previous revision up to the head.

=cut

sub delRev {
    my( $this, $user, $web, $topic ) = @_;

    $this->lockTopic( $user, $web, $topic );

    my $rev = $this->getRevisionNumber( $web, $topic );
    if( $rev <= 1 ) {
        return "can't delete initial revision";
    }
    my $topicHandler = $this->_getTopicHandler( $web, $topic );
    my $error = $topicHandler->deleteRevision();
    return $error if( $error );

    # restore last topic from repository
    $error = $topicHandler->restoreLatestRevision();
    return $error if( $error );

    $this->unlockTopic( $user, $web, $topic );

    # TODO: delete entry in .changes

    # write log entry
    $this->{session}->writeLog( 'cmd', $web.'.'.$topic, 'delRev by '.
                                $user->login().": $rev" );

    return '';
}

=pod

---++ ObjectMethod saveFile (  $name, $text  )

Save an arbitrary file

SMELL: Breaks Store encapsulation, if it is used to save topic or
meta-data files.
Therefore this method should _never_ be used for saving topics or
web-specific meta data files, as they may not be stored as text files
in another store implementation. Use =saveTopic*= and =saveMetaData= instead.

=cut

sub saveFile {
    my( $this, $name, $text ) = @_;
    ASSERT(ref($this) eq 'TWiki::Store') if DEBUG;

    $name = TWiki::Sandbox::normalizeFileName( $name );

    umask( 002 );
    unless ( open( FILE, ">$name" ) )  {
        die "Can't create file $name - $!\n";
    }
    print FILE $text;
    close( FILE);
}

=pod

---++ ObjectMethod lockTopic( $web, $topic )

Grab a topic lock on the given topic. A topic lock will cause other
processes that also try to claim a lock to block. A lock has a
maximum lifetime of 2 minutes, so operations on a locked topic
must be completed within that time. You cannot rely on the
lock timeout clearing the lock, though; that should always
be done by calling unlockTopic.

=cut

sub lockTopic {
    my ( $this, $locker, $web, $topic ) = @_;
    ASSERT(ref($this) eq 'TWiki::Store') if DEBUG;
    ASSERT(ref($locker) eq 'TWiki::User') if DEBUG;
    ASSERT($web && $topic) if DEBUG;

    my $topicHandler = $this->_getTopicHandler( $web, $topic );

    while ( 1 ) {
        my ( $user, $time ) = $topicHandler->isLocked();
        last if ( !$user || $locker->wikiName() eq $user );
        $this->{session}->writeWarning( "Lock on $web.$topic for ".
                                        $locker->wikiName().
                                        " denied by $user" );
        # see how old the lock is. If it's older than 2 minutes,
        # break it anyway. Locks are atomic, and should never be
        # held that long, by _any_ process.
        if ( time() - $time > 2 * 60 ) {
            $this->{session}->writeWarning
              ( $locker->wikiName()." broke ${user}s lock on $web.$topic" );
            $topicHandler->setLock( 0 );
            last;
        }
        # wait a couple of seconds before trying again
        sleep(2);
    }

    $topicHandler->setLock( 1, $locker->wikiName() );
}

=pod

---++ ObjectMethod unlockTopic( $user, $web, $topic )
Release the topic lock on the given topic. A topic lock will cause other
processes that also try to claim a lock to block. It is important to
release a topic lock after a guard section is complete.

=cut

sub unlockTopic {
    my ( $this, $user, $web, $topic ) = @_;
    ASSERT(ref($this) eq 'TWiki::Store') if DEBUG;
    ASSERT(ref($user) eq 'TWiki::User') if DEBUG;

    my $topicHandler = $this->_getTopicHandler( $web, $topic );
    $topicHandler->setLock( 0, $user->wikiName() );
}

=pod

---++ ObjectMethod webExists( $web ) -> $boolean

Test if web exists
   * =$web= - Web name, required, e.g. ='Sandbox'=

Note: see isKnownWeb to test for whether the web is actually a usable
web or not (it has to have a home topic if it is)

=cut

sub webExists {
    my( $this, $theWeb ) = @_;
    ASSERT(defined($theWeb)) if DEBUG;

    ASSERT(ref($this) eq 'TWiki::Store') if DEBUG;
    return -e "$TWiki::cfg{DataDir}/$theWeb";
}

=pod

---++ ObjectMethod topicExists( $web, $topic ) -> $boolean

Test if topic exists
   * =$web= - Web name, optional, e.g. ='Main'=
   * =$topic= - Topic name, required, e.g. ='TokyoOffice'=, or ="Main.TokyoOffice"=

=cut

sub topicExists {
    my( $this, $theWeb, $theTopic ) = @_;
    ASSERT(ref($this) eq 'TWiki::Store') if DEBUG;
    ASSERT(defined($theTopic)) if DEBUG;

    return -e "$TWiki::cfg{DataDir}/$theWeb/$theTopic.txt";
}

# PRIVATE parse and add a meta-datum. Returns '' so it can be used in s///e
sub _addMetaDatum {
    #my ( $meta, $type, $args ) = @_;
    $_[0]->put( $_[1], _readKeyValues( $_[2] ));
    return ''; # so it can be used in s///e
}

# Expect meta data at top of file, but willing to accept it anywhere.
# If we have an old file format without meta data, then convert.
#
# SMELL: SIDE-EFFECTING FUNCTION meta-data is stripped from the $rtext
#
# SMELL: Calls to this method from outside of Store
# should be avoided at all costs, as it exports the assumption that
# meta-data is embedded in text.
#
sub extractMetaData {
    my( $this, $web, $topic, $rtext ) = @_;
    ASSERT(ref($this) eq 'TWiki::Store') if DEBUG;

    my $meta = new TWiki::Meta( $this->{session}, $web, $topic );
    $$rtext =~ s/^%META:([^{]+){(.*)}%\r?\n/&_addMetaDatum($meta,$1,$2)/gem;

    # If there is no meta data then convert from old format
    if( ! $meta->count( 'TOPICINFO' ) ) {
        if ( $$rtext =~ /<!--TWikiAttachment-->/ ) {
            $$rtext = $this->{session}->{attach}->migrateToFileAttachmentMacro( $meta,
                                                                   $$rtext );
        }

        if ( $$rtext =~ /<!--TWikiCat-->/ ) {
            $$rtext = $this->{session}->{form}->upgradeCategoryTable( $web, $topic,
                                                         $meta, $$rtext );
        }
    } else {
        my $topicinfo = $meta->get( 'TOPICINFO' );
        if( $topicinfo->{format} eq "1.0beta" ) {
            # This format used live at DrKW for a few months
            if( $$rtext =~ /<!--TWikiCat-->/ ) {
                $$rtext = $this->{session}->{form}->upgradeCategoryTable( $web, $topic,
                                                               $meta,
                                                               $$rtext );
            }
            $this->{session}->{attach}->upgradeFrom1v0beta( $meta );
            if( $meta->count( 'TOPICMOVED' ) ) {
                 my $moved = $meta->get( 'TOPICMOVED' );
                 my $u = $this->{session}->{users}->findUser( $moved->{by} );
                 $moved->{by} = $u->login() if $u;
                 $meta->put( 'TOPICMOVED', $moved );
            }
        }
    }

    return $meta;
}

=pod

---++ ObjectMethod getTopicParent (  $theWeb, $theTopic  ) -> $string

Get the name of the topic parent. Needs to be fast because
of use by Render.pm.

=cut

# SMELL: does not honour access controls

sub getTopicParent {
    my( $this, $theWeb, $theTopic ) = @_;
    ASSERT(ref($this) eq 'TWiki::Store') if DEBUG;
    ASSERT(defined($theWeb)) if DEBUG;
    ASSERT(defined($theTopic)) if DEBUG;

    return undef unless $this->topicExists( $theWeb, $theTopic );

    my $topicHandler = $this->_getTopicHandler( $theWeb, $theTopic );
    my $filename = $topicHandler->{file};

    my $data = '';
    my $line;
    $/ = "\n";     # read line by line
    open( IN_FILE, "<$filename" ) || return '';
    while( ( $line = <IN_FILE> ) ) {
        if( $line !~ /^%META:/ ) {
           last;
        } else {
           $data .= $line;
        }
    }
    close( IN_FILE );

    my $meta = $this->extractMetaData( $theWeb, $theTopic, \$data );
    my $parentMeta = $meta->get( 'TOPICPARENT' );
    return $parentMeta->{name} if $parentMeta;
    return undef;
}

=pod

---++ ObjectMethod getTopicLatestRevTime (  $theWeb, $theTopic  ) -> $epochSecs

Get an approximate rev time for the latest rev of the topic. This method
is used to optimise searching. Needs to be as fast as possible.

=cut

sub getTopicLatestRevTime {
    my ( $this, $web, $topic ) = @_;

    return (stat "$TWiki::cfg{DataDir}\/$web\/$topic.txt")[9];
}

=pod

---++ ObjectMethod readFile( $filename ) -> $text

Return value: $fileContents

Thorws Error::Simple if a file operation failed.

Returns the entire contents of the given file, which can be specified in any
format acceptable to the Perl open() function.

SMELL: Breaks Store encapsulation, if it is used to read topic or meta-data
files. Therefore this method should _never_ be used for reading topics or
web-specific meta data files, as they may not be stored as text files
in another store implementation. Use =readTopic*= and =readMetaData= instead.

=cut

sub readFile {
    my( $this, $name ) = @_;
    ASSERT(ref($this) eq 'TWiki::Store') if DEBUG;
    $name = TWiki::Sandbox::normalizeFileName( $name );
    my $data = '';
    open( IN_FILE, "<$name" ) || return '';
    my $s = $/;
    undef $/; # set to read to EOF
    $data = <IN_FILE>;
    $/ = $s;
    close( IN_FILE );
    $data = '' unless $data; # no undefined
    return $data;
}

=pod

---++ ObjectMethod readMetaData( $web, $name ) -> $text

Read a named meta-data string. If web is given the meta-data
is stored alongside a web. If the web is not
given, the meta-data is assumed to be globally unique.

=cut

sub readMetaData {
    my ( $this, $web, $name ) = @_;
    ASSERT(ref($this) eq 'TWiki::Store') if DEBUG;

    my $file = "$TWiki::cfg{DataDir}/";
    $file .= "$web/" if $web;
    $file .= ".$name";

    return $this->readFile( $file );
}

=pod

---++ ObjectMethod saveMetaData( $web, $name ) -> $text

Write a named meta-data string. If web is given the meta-data
is stored alongside a web. If the web is not
given, the meta-data is assumed to be globally unique.

=cut

sub saveMetaData {
    my ( $this, $web, $name, $text ) = @_;
    ASSERT(ref($this) eq 'TWiki::Store') if DEBUG;

    my $file = "$TWiki::cfg{DataDir}/";
    $file .= "$web/" if $web;
    $file .= ".$name";

    return $this->saveFile( $file, $text );
}

=pod

---++ ObjectMethod getTopicNames( $web ) -> @topics

Get list of all topics in a web
   * =$web= - Web name, required, e.g. ='Sandbox'=
Return a topic list, e.g. =( 'WebChanges',  'WebHome', 'WebIndex', 'WebNotify' )=

=cut

sub getTopicNames {
    my( $this, $web ) = @_ ;
    ASSERT(ref($this) eq 'TWiki::Store') if DEBUG;

    $web = '' unless( defined $web );

    opendir DIR, "$TWiki::cfg{DataDir}/$web" ;
    my @topicList = sort grep { s/\.txt$// } readdir( DIR );
    closedir( DIR );
    return @topicList;
}

=pod

---++ ObjectMethod getListOfWebs( $filter ) -> @webNames

Gets a list of webs, filtered according to the spec in the $filter,
which may include one of:
   1 'user' (for only user webs)
   2 'template' (for only template webs)
$filter may also contain the word 'public' which will further filter
webs on whether NOSEARCHALL is specified for them or not.

=cut

sub getListOfWebs {
    my( $this, $filter ) = @_;
    ASSERT(ref($this) eq 'TWiki::Store') if DEBUG;
    $filter ||= '';

    opendir DIR, "$TWiki::cfg{DataDir}" ;
    my @webList = grep { !/^\./ &&
                           -d "$TWiki::cfg{DataDir}/$_" } readdir( DIR );
    closedir( DIR );

    if ( $filter =~ /\buser\b/ ) {
        @webList = grep { !/^_/, } @webList;
    } elsif( $filter =~ /\btemplate\b/ ) {
        @webList = grep { /^_/, } @webList;
    }

    my $prefs = $this->{session}->{prefs};
    if( $filter =~ /\bpublic\b/ ) {
        @webList =
          grep {
              $_ eq $this->{session}->{webName} ||
              !$prefs->getPreferencesValue( 'NOSEARCHALL', $_ )
          } @webList;
    }

    return sort @webList;
}

=pod

---++ ObjectMethod isKnownWeb( $webName ) -> $boolean

Check if the given name refers to a web known to the store system
(including system webs). Differs from webExists because it checks
that the web actually has a home topic.

=cut

sub isKnownWeb {
    my( $this, $web ) = @_;
    ASSERT(ref($this) eq 'TWiki::Store') if DEBUG;
    ASSERT( $web ) if DEBUG;
    return -e "$TWiki::cfg{DataDir}/$web/$TWiki::cfg{HomeTopicName}.txt";
}

=pod

---++ ObjectMethod createWeb( $newWeb, $baseWeb, $opts ) -> $error

Create a new web. Returns an error string if it fails, undef if alles gut.

$newWeb is the name of the new web.

$baseWeb is the name of an existing web (a template web). If the
base web is a system web, all topics in it
will be copied into the new web. If it is a normal web, only topics starting
with 'Web' will be copied.

$opts is a ref to a hash that contains settings to be modified in
the web preferences topic in the new web.

=cut

sub createWeb {
    my ( $this, $newWeb, $baseWeb, $opts ) = @_;
    ASSERT(ref($this) eq 'TWiki::Store') if DEBUG;

    my $dir = TWiki::Sandbox::untaintUnchecked("$TWiki::cfg{DataDir}/$newWeb");
    umask( 0 );
    unless( mkdir( $dir, 0775 ) ) {
        return "Could not create $dir, error: $!";
    }

    if ( $TWiki::cfg{RCS}{useSubDir} ) {
        unless( mkdir( "$dir/RCS", 0775 ) ) {
            return "Could not create $dir/RCS, error: $!";
        }
    }

    # copy topics from base web
    my @topicList = $this->getTopicNames( $baseWeb );
    unless( $baseWeb =~ /^_/ ) {
        # not a system web, so filter for only Web* topics
        @topicList = grep { /^Web/ } @topicList;
    }
    my $err;
    foreach my $topic ( @topicList ) {
        $topic =~ s/$TWiki::cfg{NameFilter}//go;
        $err = $this->_copyTopicBetweenWebs( $baseWeb,
                                             $topic, $newWeb );
        return( $err ) if( $err );
    }

    # create meta-data files
    $this->saveMetaData( $newWeb, 'changes', '');
    $this->saveMetaData( $newWeb, 'mailnotify', '');

    # patch WebPreferences in new web
    my $wpt = $TWiki::cfg{WebPrefsTopicName};
    my( $meta, $text ) =
      $this->readTopic( undef, $newWeb, $wpt, undef );

    foreach my $key ( %$opts ) {
        $text =~ s/($TWiki::regex{setRegex}$key\s*=).*?$/$1 $opts->{$key}/gm;
    }
    return $this->saveTopic( $this->{session}->{user}, $newWeb, $wpt,
                             $text, $meta );
}

# STATIC Write a meta-data key=value pair
# The encoding is reversed in _readKeyValues
# SMELL: this uses a really bad escape encoding
# 1. it doesn't handle all characters that need escaping.
# 2. it's excessively noisy
# 3. it's not a reversible encoding; \r's are lost
sub _writeKeyValue {
    my( $key, $value ) = @_;

    if( defined( $value )) {
        $value =~ s/\%/%_P_%/g;
        $value =~ s/\"/%_Q_%/g;
        $value =~ s/\r*\n\r*/%_N_%/g;
    } else {
        $value = '';
    }

    return $key.'="'.$value.'"';
}

# Write all the key=value pairs for the types listed
sub _writeTypes {
    my( $meta, @types ) = @_;
    ASSERT(ref($meta) eq 'TWiki::Meta') if DEBUG;

    my $text = '';

    if( $types[0] eq 'not' ) {
        # write all types that are not in the list
        my %seen;
        @seen{ @types } = ();
        @types = ();  # empty "not in list"
        foreach my $key ( keys %$meta ) {
            push( @types, $key ) unless
              (exists $seen{ $key } || $key =~ /^_/);
        }
    }

    foreach my $type ( @types ) {
        my $data = $meta->{$type};
        foreach my $item ( @$data ) {
            my $sep = '';
            $text .= "%META:$type\{";
            my $name = $item->{name};
            if( $name ) {
                # If there's a name field, put first to make regexp based searching easier
                $text .= _writeKeyValue( 'name', $item->{name} );
                $sep = ' ';
            }
            foreach my $key ( sort keys %$item ) {
                if( $key ne 'name' ) {
                    $text .= $sep;
                    $text .= _writeKeyValue( $key, $item->{$key} );
                    $sep = ' ';
                }
            }
            $text .= "\}%\n";
        }
    }

    return $text;
}

# STATIC Meta data for start of topic
sub _writeStart {
    my( $meta ) = @_;

    return _writeTypes( $meta, qw/TOPICINFO TOPICPARENT/ );
}

# STATIC Meta data for end of topic
sub _writeEnd {
    my( $meta ) = @_;

    my $text = _writeTypes($meta, qw/FORM FIELD FILEATTACHMENT TOPICMOVED/ );
    # append remaining meta data
    $text .= _writeTypes( $meta, qw/not TOPICINFO TOPICPARENT FORM FIELD FILEATTACHMENT TOPICMOVED/ );
    return $text;
}

# STATIC Prepend/append meta data to topic
sub _writeMeta {
    my( $meta, $text ) = @_;
    ASSERT(ref($meta) eq 'TWiki::Meta') if DEBUG;

    my $start = _writeStart( $meta );
    my $end = _writeEnd( $meta );
    $text = $start . $text;
    $text =~ s/([^\n\r])$/$1\n/;     # new line is required at end
    $text .= $end;

    return $text;
}

=pod

---++ ObjectMethod getDebugText($meta, $text) -> $text

Generate a debug text form of the text/meta, for use in debug displays,
by annotating the text with meta informtion.

=cut

sub getDebugText {
    my ( $this, $meta, $text ) = @_;
    ASSERT(ref($this) eq 'TWiki::Store') if DEBUG;

    return _writeMeta( $meta, $text );
}

=pod

---++ ObjectMethod cleanUpRevID( $rev ) -> $integer

Cleans up (maps) a user-supplied revision ID and converts it to an integer
number that can be incremented to create a new revision number.

This method should be used to sanitise user-provided revision IDs.

=cut

sub cleanUpRevID {
    my ( $this, $rev ) = @_;
    ASSERT(ref($this) eq 'TWiki::Store') if DEBUG;

    return 0 unless $rev;

    $rev =~ s/^r//i;
    $rev =~ s/^\d+\.//; # clean up RCS rev number

    return $rev;
}

# Copy a topic and all it's attendant data from one web to another.
# Returns an error string if it fails.
sub _copyTopicBetweenWebs {
    my ( $this, $theFromWeb, $theTopic, $theToWeb ) = @_;
    ASSERT(ref($this) eq 'TWiki::Store') if DEBUG;

    # copy topic file
    my $from = TWiki::Sandbox::untaintUnchecked("$TWiki::cfg{DataDir}/$theFromWeb/$theTopic.txt");
    my $to = TWiki::Sandbox::untaintUnchecked("$TWiki::cfg{DataDir}/$theToWeb/$theTopic.txt");
    unless( copy( $from, $to ) ) {
        return( "Copy file ( $from, $to ) failed, error: $!" );
    }
    umask( 002 );
    chmod( 0644, $to );

    # copy repository file
    # FIXME: Hack, no support for RCS subdirectory
    $from .= ",v";
    $to .= ",v";
    if( -e $from ) {
        unless( copy( $from, $to ) ) {
            return( "Copy file ( $from, $to ) failed, error: $!" );
        }
        umask( 002 );
        chmod( 0644, $to );
    }

    # FIXME: Copy also attachments if present

    return '';
}

=pod

---++ ObjectMethod searchMetaData($params) -> $text

Search meta-data associated with topics. Parameters are passed in the $params hash,
which may contain:
| =type= | =topicmoved=, =parent= or =field= |
| =topic= | topic to search for, for =topicmoved= and =parent= |
| =name= | form field to search, for =field= type searches. May be a regex. |
| =value= | form field value. May be a regex. |
| =title= | Title prepended to the returned search results |
| =default= | defualt value if there are no results |
| =web= | web to search in, default is all webs |
The idea is that people can search for meta-data values without having to be
aware of how or where meta-data is stored.

SMELL: should be replaced with a proper SQL-like search, c.f. Plugins.DBCacheContrib.

=cut

sub searchMetaData {
    my ( $this, $params ) = @_;

    my $attrType = $params->{type} || 'FIELD';

    my $searchVal = 'XXX';

    my $attrWeb = $params->{web} || '';
    my $searchWeb = $attrWeb || 'all';

    if ( $attrType eq 'parent' ) {
        my $attrTopic = $params->{topic} || '';
        $searchVal = "%META:TOPICPARENT[{].*name=\\\"($attrWeb\\.)?$attrTopic\\\".*[}]%";
   } elsif ( $attrType eq 'topicmoved' ) {
        my $attrTopic = $params->{topic} || '';
        $searchVal = "%META:TOPICMOVED[{].*from=\\\"$attrWeb\.$attrTopic\\\".*[}]%";
    } else {
        $searchVal = "%META:".uc( $attrType )."[{].*";
        $searchVal .= "name=\\\"$params->{name}\\\".*"
          if (defined $params->{name});
        $searchVal .= "value=\\\"$params->{value}\\\".*"
          if (defined $params->{value});
        $searchVal .= "[}]%";
    }

    my $text = '';
    $this->{session}->{search}->searchWeb
      (
       _callback     => \&_collate,
       _cbdata       => \$text,,
       search        => $searchVal,
       web           => $searchWeb,
       type          => 'regex',
       nosummary     => 'on',
       nosearch      => 'on',
       noheader      => 'on',
       nototal       => 'on',
       noempty       => 'on',
       template      => 'searchmeta',
       inline        => 1,
      );

    my $attrTitle = $params->{title} || '';
    if( $text ) {
        $text = $attrTitle.$text;
    } else {
        my $attrDefault = $params->{default} || '';
        $text = $attrTitle.$attrDefault;
    }

    return $text;
}

# callback for search function to collate
# results
sub _collate {
    my $ref = shift;

    $$ref .= join( ' ', @_ );
}

=pod

---++ ObjectMethod searchInWebContent($searchString, $web, \@topics, \%options ) -> \%map

Search for a string in the content of a web. The search must be over all
content and all formatted meta-data, though the latter search type is
deprecated (use searchMetaData instead).

   * =$searchString= - the search string, in egrep format if regex
   * =$web= - The web to search in
   * =\@topics= - reference to a list of topics to search
   * =\%options= - reference to an options hash
The =\%options= hash may contain the following options:
   * =type= - if =regex= will perform a egrep-syntax RE search (default '')
   * =casesensitive= - false to ignore case (defaulkt true)
   * =files_without_match= - true to return files only (default false)

The return value is a reference to a hash which maps each matching topic
name to a list of the lines in that topic that matched the search,
as would be returned by 'grep'. If =files_without_match= is specified, it will
return on the first match in each topic (i.e. it will return only one
match per topic, and will not return matching lines).

=cut

sub searchInWebContent {
    my( $this, $searchString, $web, $topics, $options ) = @_;

    my $type = $options->{type} || '';
    my $caseSensitive = $options->{casesensitive} || 1;
    my $justTopics = $options->{files_without_match} || 0;

    # I18N: 'grep' must use locales if needed,
    # for case-insensitive searching.  See TWiki::setupLocale.
    my $program = '';
    # FIXME: For Cygwin grep, do something about -E and -F switches
    # - best to strip off any switches after first space in
    # EgrepCmd etc and apply those as argument 1.
    if( $type eq 'regex' ) {
        $program = $TWiki::cfg{RCS}{EgrepCmd};
    } else {
        $program = $TWiki::cfg{RCS}{FgrepCmd};
    }

    my $args = '';
    $args .= ' -i' unless $caseSensitive;
    $args .= ' -l' if $justTopics;
    $args .= ' -- %TOKEN|U% %FILES|F%';

    my $sDir = "$TWiki::cfg{DataDir}/$web/";
    my $seen = {};
    # process topics in sets, fix for Codev.ArgumentListIsTooLongForSearch
    my $maxTopicsInSet = 512; # max number of topics for a grep call
    my @take = @$topics;
    my @set = splice( @take, 0, $maxTopicsInSet );
    my $sandbox = $this->{session}->{sandbox};
    while( @set ) {
        @set = map { "$sDir/$_.txt" } @set;
        @set =
          $sandbox->readFromProcessArray ($program, $args,
                                          TOKEN => $searchString,
                                          FILES => \@set);

        foreach my $match ( @set ) {
            if( $match =~ m/([^\/]*)\.txt(:?: (.*))?$/ ) {
                push( @{$seen->{$1}}, $2 );
            }
        }
        @set = splice( @take, 0, $maxTopicsInSet );
    }
    return $seen;
}

=pod

getReferringTopics($oldWeb, $oldTopic);

SMELL: this does not hide NONSEARCHABLE webs or do any of the security things at the moment.

=cut
sub getReferringTopics {
    my ($this, $oldWeb, $oldTopic, $newWeb) = @_;
    my @results;
    my ($web, $topic);

    foreach $web ($this->getListOfWebs()) {
        my @topicList = $this->getTopicNames( $web );
        my $searchString = $oldTopic;
        $searchString = $web.'.'.$searchString unless $web eq $oldWeb;

        my $matches = $this->searchInWebContent
          ( $searchString, $web, \@topicList,
            { casesensitive => 0, files_without_match => 1 } );

        foreach $topic (keys %$matches) {
            if ( $web eq $newWeb ) {
                push (@results, 'global');
            } else {
                push (@results, 'stupid');
            }
            push (@results, $web.'.'.$topic);
        }
    }

    return \@results;
}

=pod

---++ ObjectMethod getRevisionAtTime( $web, $topic, $time ) -> $rev
   * =$web= - web for topic
   * =$topic= - topic
   * =$time= - time (in epoch secs) for the rev

Get the revision number of a topic at a specific time.
Returns a single-digit rev number or undef if it couldn't be determined
(either because the topic isn't that old, or there was a problem)

=cut

sub getRevisionAtTime {
    my ( $this, $theWeb, $theTopic, $time ) = @_;

    my $topicHandler = $this->_getTopicHandler( $theWeb, $theTopic );
    return $topicHandler->getRevisionAtTime( $time );
}

1;

