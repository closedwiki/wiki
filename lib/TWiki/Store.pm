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

This module hosts the generic storage backend. This module provides
the interface layer between the "real" store provider - which is hidden
behind a handler - and the rest of the system. it is responsible for
checking for topic existance, access permissions, and all the other
general admin tasks that are common to all store implementations.

This module knows nothing about how the data is actually _stored_ -
that knowledge is entirely encapsulated in the handlers.

The general contract for methods in the class requires that errors
are signalled using exceptions. TWiki::AccessControlException is
used for access control exceptions, and Error::Simple for all other
types of error.

=cut

package TWiki::Store;

use strict;

use Assert;
use Error qw( :try );

use TWiki::Meta ();
use TWiki::Time ();
use TWiki::AccessControlException ();

use vars qw( $STORE_FORMAT_VERSION );

$STORE_FORMAT_VERSION = '1.1';

=pod

---++ ClassMethod new()

Construct a Store module, linking in the chosen sub-implementation.

=cut

sub new {
    my ( $class, $session ) = @_;
    ASSERT($session->isa('TWiki')) if DEBUG;

    # Do a dynamic 'use locale' for this module
    if( $TWiki::cfg{UseLocale} ) {
        require locale;
    }

    my $this = bless( {}, $class );

    $this->{session} = $session;

    $this->{IMPL} = 'TWiki::Store::'.$TWiki::cfg{StoreImpl};
    eval 'use '.$this->{IMPL};
    if( $@ ) {
        die "$this->{IMPL} compile failed $@";
    }

    return $this;
}

# PRIVATE
# Get the handler for the current store implementation.
# $web, $topic and $attachment _must_ be untainted.
sub _getHandler {
    my( $this, $web, $topic, $attachment ) = @_;

    return $this->{IMPL}->new( $this->{session}, $web, $topic, $attachment );
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
web specification will override whatever is passed in $web.

The metadata and topic text are returned separately, with the metadata in a
TWiki::Meta object.  (The topic text is, as usual, just a string.)

=cut

sub readTopic {
    my( $this, $user, $web, $topic, $version ) = @_;
    ASSERT($this->isa('TWiki::Store')) if DEBUG;
    $web =~ s#\.#/#go;

    my $text = $this->readTopicRaw( $user, $web, $topic, $version );
    my $meta = new TWiki::Meta( $this->{session}, $web, $topic);
    $this->extractMetaData( $meta, \$text );
    my @knownAttachments = $meta->find('FILEATTACHMENT');
    my $ka = undef; #ugly I know
    if ($#knownAttachments) {
        $ka = \@knownAttachments;
	}
    
	my $autoAttachments = $this->extractMetaDataAutoAttachments($user, $web, $topic, $version, $ka );
	if (defined $autoAttachments) {
		$meta->putAll('FILEATTACHMENT', @$autoAttachments);
	};

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
web specification will override whatever is passed in $web.

SMELL: DO NOT CALL THIS METHOD UNLESS YOU HAVE NO CHOICE. This method breaks
encapsulation of the store, as it assumes meta is stored embedded in the text.
Other implementors of store will be forced to insert meta-data to ensure
correct operation of View raw=debug and the 'repRev' mode of Edit.

$web and $topic _must_ be untainted.

=cut

sub readTopicRaw {
    my( $this, $user, $web, $topic, $version ) = @_;
    ASSERT($this->isa('TWiki::Store')) if DEBUG;
    $web =~ s#\.#/#go;

    # test if topic contains a webName to override $web
    ( $web, $topic ) =
      $this->{session}->normalizeWebTopicName( $web, $topic );

    my $text;

    my $handler = $this->_getHandler( $web, $topic );
    unless ( $version ) {
        $text = $handler->getLatestRevision();
    } else {
        $text = $handler->getRevision( $version );
    }

    if( $user &&
          !$this->{session}->{security}->checkAccessPermission
            ( 'view', $user, $text, $topic, $web )) {
        throw TWiki::AccessControlException(
            'VIEW', $user, $web, $topic,
            $this->{session}->{security}->getReason());
    }

    return $text;
}

=pod

---++ ObjectMethod moveAttachment( $oldWeb, $oldTopic, $oldAttachment, $newWeb, $newTopic, $newAttachment, $user  )

Move an attachment from one topic to another.

The caller to this routine should check that all topics are valid.

All parameters must be defined, and must be untainted.

=cut

sub moveAttachment {
    my( $this, $oldWeb, $oldTopic, $oldAttachment,
        $newWeb, $newTopic, $newAttachment, $user ) = @_;
    ASSERT($this->isa('TWiki::Store')) if DEBUG;
    ASSERT($user->isa('TWiki::User')) if DEBUG;

    $this->lockTopic( $user, $oldWeb, $oldTopic );
    try {
        my( $ometa, $otext ) = $this->readTopic( undef, $oldWeb, $oldTopic );
        if( $user &&
              !$this->{session}->{security}->checkAccessPermission
                ( 'change', $user, $otext, $oldTopic, $oldWeb )) {
            throw TWiki::AccessControlException(
                'CHANGE', $user, $oldWeb, $oldTopic,
                $this->{session}->{security}->getReason());
        }

        my ( $nmeta, $ntext ) = $this->readTopic( undef, $newWeb, $newTopic );
        if( $user &&
              !$this->{session}->{security}->checkAccessPermission
                ( 'change', $user, $ntext, $newTopic, $newWeb )) {
            throw TWiki::AccessControlException(
                'CHANGE', $user, $newWeb, $newTopic,
                $this->{session}->{security}->getReason());
        }

        # Remove file attachment from old topic
        my $handler =
          $this->_getHandler( $oldWeb, $oldTopic, $oldAttachment );

        $handler->moveAttachment( $newWeb, $newTopic, $newAttachment );

        my $fileAttachment =
          $ometa->get( 'FILEATTACHMENT', $oldAttachment );
        $ometa->remove( 'FILEATTACHMENT', $oldAttachment );
        $this->_noHandlersSave( $user, $oldWeb, $oldTopic, $otext, $ometa,
                                { notify => 0 } );

        # Add file attachment to new topic
        $fileAttachment->{name} = $newAttachment;
        $fileAttachment->{movefrom} = $oldWeb.'.'.$oldTopic.'.'.$oldAttachment;
        $fileAttachment->{moveby}   = $user->webDotWikiName();
        $fileAttachment->{movedto}  = $newWeb.'.'.$newTopic.'.'.$newAttachment;
        $fileAttachment->{movedwhen} = time();
        $nmeta->putKeyed( 'FILEATTACHMENT', $fileAttachment );

        $this->_noHandlersSave( $user, $newWeb, $newTopic, $ntext,
                                $nmeta, { dontlog => 1,
                                          notify => 0,
                                          comment => 'moved' } );
        $this->{session}->writeLog(
            'move',
            $fileAttachment->{movefrom}.' moved to '.
              $fileAttachment->{movedto}, $user );
    } finally {
        $this->unlockTopic( $user, $oldWeb, $oldTopic );
        $this->unlockTopic( $user, $newWeb, $newTopic );
    };
}

=pod

---++ ObjectMethod getAttachmentStream( $user, $web, $topic, $attName ) -> \*STREAM
   * =$user= - the user doing the reading, or undef if no access checks
   * =$web= - The web
   * =$topic= - The topic
   * =$attName= - Name of the attachment

Open a standard input stream from an attachment.

If $user is defined, view permission will be required for the topic
read to be successful.  Access control violations and errors will
cause exceptions to be thrown.

Permissions are checked for the user name passed in.

=cut

sub getAttachmentStream {
    my ( $this, $user, $web, $topic, $att ) = @_;
    ASSERT($this->isa('TWiki::Store')) if DEBUG;

    if( $user &&
          !$this->{session}->{security}->checkAccessPermission
            ( 'view', $user, undef, $topic, $web )) {
        throw TWiki::AccessControlException( 'VIEW', $user, $web, $topic,
                                             $this->{session}->{security}->getReason());
    }

    my $handler = $this->_getHandler( $web, $topic, $att );
    return $handler->getStream();
}

=pod

returns @($attachmentName => [stat]) for any given web, topic
=cut
sub getAttachmentList {
    my( $this, $web, $topic ) = @_;

    ASSERT($this->isa('TWiki::Store')) if DEBUG;
    my $handler = $this->_getHandler( $web, $topic ); 
    return $handler->getAttachmentList($web, $topic);
}

=pod
---++ ObjectMethod attachmentExists( $web, $topic, $att ) -> $boolean

Determine if the attachment already exists on the given topic

=cut

sub attachmentExists {
    my( $this, $web, $topic, $att ) = @_;

    ASSERT($this->isa('TWiki::Store')) if DEBUG;
    my $handler = $this->_getHandler( $web, $topic, $att );
    return $handler->storedDataExists();
}

=pod
---++ findAttachments($session, $web, $topic, $knownAttachments)
Synchronise the attachment list with what's actually on disk
Returns an ARRAY of FILEATTACHMENTs- these can be put in the new meta using meta->put('FILEATTACHMENTS', $tree)

IDEA On Windows machines where the underlying filesystem can store arbitary meta data against files, this might replace/fulfil the COMMENT purpose
TODO consider logging when things are added to metadata
=cut

sub findAttachments {
    my ($this, $web, $topic, $attachmentsKnownInMeta) = @_;
    my $session = $this->{session};
    ASSERT($session->isa( 'TWiki' )) if DEBUG;
  
    my $store = $this;   
    
    my %filesListedInPub = $store->getAttachmentList($web, $topic);
	my %filesListedInMeta = ();

# You need the following lines if you want metadata to supplement the filesystem	
	if (defined $attachmentsKnownInMeta) {
		%filesListedInMeta = TWiki::Meta::indexByKey('name', @$attachmentsKnownInMeta);
	}
# Please retain following print until this feature is out of beta
#	print "In Meta:".Dumper(\%filesListedInMeta). "\n\nIn Pub:\n".Dumper(\%filesListedInPub);

    foreach my $file (keys %filesListedInPub) {
       if ($filesListedInMeta{$file}) {
       	  # Bring forward any missing yet wanted attributes
          $filesListedInPub{$file}{comment} = $filesListedInMeta{$file}{comment};
       }
    }

# Please retain following print until this feature is out of beta
#    print "Result:".Dumper(\%filesListedInPub)."\n";

	# A comparison of the keys of the $filesListedInMeta and %filesListedInPub 
	# would show files that were in Meta but have disappeared from Pub.
		
	# SMELL Meta really ought index its attachments in a hash by attachment name but this is not the case
	# SMELL so fit the interface and return an ugly array instead
	my @deindexedBecauseMetaDoesnotIndexAttachments = TWiki::Meta::deindexKeyed(%filesListedInPub);
	    
	return @deindexedBecauseMetaDoesnotIndexAttachments;
}


=pod

---++ ObjectMethod moveTopic(  $oldWeb, $oldTopic, $newWeb, $newTopic, $user )

All parameters must be defined and must be untainted.

=cut

sub moveTopic {
    my( $this, $oldWeb, $oldTopic, $newWeb, $newTopic, $user ) = @_;
    ASSERT($this->isa('TWiki::Store')) if DEBUG;
    ASSERT($user->isa('TWiki::User')) if DEBUG;

    # will block
    $this->lockTopic( $user, $oldWeb, $oldTopic );
    try {
        my $otext = $this->readTopicRaw( undef, $oldWeb, $oldTopic );
        if( $user &&
              !$this->{session}->{security}->checkAccessPermission
                ( 'change', $user, $otext, $oldTopic, $oldWeb )) {
            throw TWiki::AccessControlException(
                'CHANGE', $user,
                $oldWeb, $oldTopic,
                $this->{session}->{security}->getReason());
        }

        my ( $nmeta, $ntext );
        if( $this->topicExists( $newWeb, $newTopic )) {
            ( $nmeta, $ntext ) = $this->readTopic( undef, $newWeb, $newTopic );
        }
        if( $user &&
              !$this->{session}->{security}->checkAccessPermission
                ( 'change', $user, $ntext, $newTopic, $newWeb )) {
            throw TWiki::AccessControlException(
                'CHANGE', $user, $newWeb, $newTopic,
                $this->{session}->{security}->getReason());
        }

        my $handler = $this->_getHandler( $oldWeb, $oldTopic, '' );
        $handler->moveTopic( $newWeb, $newTopic );
    } finally {
        $this->unlockTopic( $user, $oldWeb, $oldTopic );
    };

    # Log rename
    if( $TWiki::cfg{Log}{rename} ) {
        my $old = $oldWeb.'.'.$oldTopic;
        my $new = $newWeb.'.'.$newTopic;
        $this->{session}->writeLog( 'rename', $old, "moved to $new", $user );
    }
}

=pod

---++ ObjectMethod moveWeb( $oldWeb, $newWeb, $user )

Move a web.

All parrameters must be defined and must be untainted.

=cut

sub moveWeb {
    my( $this, $oldWeb, $newWeb, $user ) = @_;
    ASSERT($this->isa('TWiki::Store')) if DEBUG;
    ASSERT($user->isa('TWiki::User')) if DEBUG;

    $oldWeb =~ s/\./\//go;
    $newWeb =~ s/\./\//go;

    my (@webList) = $this->getListOfWebs('public', $oldWeb);
    unshift(@webList,$oldWeb);
    foreach my $webIter (@webList) {
        if( $webIter ) {
            $webIter =~ /(.*)/;
            $webIter = $1;
            my @webTopicList = $this->getTopicNames( $webIter );
            foreach my $webTopic (@webTopicList) {
                $webTopic =~ /(.*)/;
                $webTopic = $1;
                $this->lockTopic( $user, $webIter, $webTopic );
            }
        }
    }

    my @newParentPath = split(/\//,$newWeb);
    pop( @newParentPath );
    my $newParent = join( '/', @newParentPath );

    my $handler = $this->_getHandler( $oldWeb );
    $handler->moveWeb( $newWeb );

    (@webList) = $this->getListOfWebs('public', $newWeb);
    unshift(@webList, $newWeb);
    foreach my $webIter (@webList) {
        if( $webIter ) {
            $webIter =~ /(.*)/;
            $webIter = $1;
            my @webTopicList = $this->getTopicNames( $webIter );
            foreach my $webTopic (@webTopicList) {
                $webTopic =~ /(.*)/;
                $webTopic = $1;
                $this->unlockTopic( $user, $webIter, $webTopic );
            }
        }
    }

    # Log rename
    if( $TWiki::cfg{Log}{rename} ) {
        $this->{session}->writeLog( 'renameweb', $oldWeb, 'moved to '.$newWeb, $user );
    }
}

=pod

---++ ObjectMethod readAttachment( $user, $web, $topic, $attachment, $theRev  ) -> $text

Read the given version of an attachment, returning the content.

View permission on the topic is required for the
read to be successful.  Access control violations are flagged by a
TWiki::AccessControlException. Permissions are checked for the user
passed in.

If $theRev is not given, the most recent rev is assumed.

=cut

sub readAttachment {
    my ( $this, $user, $web, $topic, $attachment, $theRev ) = @_;

    ASSERT($this->isa('TWiki::Store')) if DEBUG;

    if( $user &&
          !$this->{session}->{security}->checkAccessPermission
            ( 'change', $user, undef, $topic, $web )) {
        throw TWiki::AccessControlException( 'CHANGE', $user,
                                             $web, $topic,
                                             $this->{session}->{security}->getReason());
    }

    my $handler = $this->_getHandler( $web, $topic, $attachment );
    return $handler->getRevision( $theRev );
}

=pod

---++ ObjectMethod getRevisionNumber ( $web, $topic, $attachment  ) -> $integer

Get the revision number of the most recent revision. Returns
the integer revision number or '' if the topic doesn't exist.

WORKS FOR ATTACHMENTS AS WELL AS TOPICS

=cut

sub getRevisionNumber {
    my( $this, $web, $topic, $attachment ) = @_;
    ASSERT($this->isa('TWiki::Store')) if DEBUG;

    $attachment = '' unless $attachment;

    my $handler = $this->_getHandler( $web, $topic, $attachment );
    return $handler->numRevisions();
}


=pod

---++ ObjectMethod getRevisionDiff (  $web, $topic, $rev1, $rev2, $contextLines  ) -> \@diffArray

Return reference to an array of [ diffType, $right, $left ]

   * =$web= - the web
   * =$topic= - the topic
   * =$rev1= Integer revision number
   * =$rev2= Integer revision number
   * =$contextLines= - number of lines of context required

=cut

sub getRevisionDiff {
    my( $this, $web, $topic, $rev1, $rev2, $contextLines ) = @_;
    ASSERT($this->isa('TWiki::Store')) if DEBUG;
    ASSERT(defined($contextLines)) if DEBUG;

    my $rcs = $this->_getHandler( $web, $topic );
    return $rcs->revisionDiff( $rev1, $rev2, $contextLines );
}

=pod

---++ ObjectMethod getRevisionInfo($web, $topic, $rev, $attachment) -> ( $date, $user, $rev, $comment )
Get revision info of a topic.
   * =$web= Web name, optional, e.g. ='Main'=
   * =$topic= Topic name, required, e.g. ='TokyoOffice'=
   * =$rev= revision number. If 0, undef, or out-of-range, will get info about the most recent revision.
   * =$attachment= attachment filename; undef for a topic
Return list with: ( last update date, last user object, =
| $date | in epochSec |
| $user | user *object* |
| $rev | the revision number |
| $comment | WHAT COMMENT? |
e.g. =( 1234561, 'phoeny', 5, 'no comment' )

NOTE NOTE NOTE if you are working within the TWiki code DO NOT USE THIS
FUNCTION FOR GETTING REVISION INFO OF TOPICS - use
TWiki::Meta::getRevisionInfo instead. This is essential to allow clean
transition to a topic object model later, and avoids the risk of confusion
coming from meta and Store revision information being out of step.
(it's OK to use it for attachments)

=cut

sub getRevisionInfo {
    my( $this, $web, $topic, $rev, $attachment ) = @_;
    ASSERT($this->isa('TWiki::Store')) if DEBUG;

    $rev ||= 0;

    my $handler =
      $this->_getHandler( $web, $topic, $attachment );

    my( $rrev, $date, $user, $comment ) =
      $handler->getRevisionInfo( $rev );
    $rev = $rrev;

    $user = $this->{session}->{users}->findUser( $user ) if $user;

    return ( $date, $user, $rev, $comment );
}

=pod

---++ StaticMethod dataEncode( $uncoded ) -> $coded
Encode meta-data fields, escaping out selected characters. The encoding
is chosen to avoid problems with parsing the attribute values, while
minimising the number of characters encoded so searches can still work
(fairly) sensibly.

The encoding has to be exported because TWiki (and plugins) use
encoded field data in other places e.g. RDiff, mainly as a shorthand
for the properly parsed meta object. Some day we may be able to
eliminate that....

=cut

sub dataEncode {
    my $datum = shift;

    $datum =~ s/([%"\r\n{}])/'%'.sprintf('%02x',ord($1))/ge;
    return $datum;
}

=pod

---++ StaticMethod dataDecode( $encoded ) -> $decoded
Decode escapes in a string that was encoded using dataEncode

The encoding has to be exported because TWiki (and plugins) use
encoded field data in other places e.g. RDiff, mainly as a shorthand
for the properly parsed meta object. Some day we may be able to
eliminate that....

=cut

sub dataDecode {
    my $datum = shift;

    $datum =~ s/%([\da-f]{2})/chr(hex($1))/gei;
    return $datum;
}

# STATIC Build a hash by parsing name=value comma separated pairs
# SMELL: duplication of TWiki::Attrs, using a different
# system of escapes :-(
sub _readKeyValues {
    my( $args, $format ) = @_;
    my $res = {};

    # Format of data is name='value' name1='value1' [...]
    while( $args =~ s/\s*([^=]+)=\"([^"]*)\"//o ) {
        my $key = $1;
        my $value = $2;
        $format =~ s/[^\d\.]+//g if $format;
        if( !$format || $format < 1.1 ) {
            # Old decoding retained for backward compatibility
            # (this encoding is badly broken)
            $value =~ s/%_N_%/\n/g;
            $value =~ s/%_Q_%/\"/g;
            $value =~ s/%_P_%/%/g;
        } else {
            $value = dataDecode( $value );
        }

        $res->{$key} = $value;
    }

    return $res;
}

=pod

---++ ObjectMethod saveTopic( $user, $web, $topic, $text, $meta, $options  )
   * =$user= - user doing the saving (object)
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
    ASSERT($this->isa('TWiki::Store')) if DEBUG;
    ASSERT($user->isa('TWiki::User')) if DEBUG;
    $web =~ s#\.#/#go;

    $options = {} unless defined( $options );

    if( $user &&
          !$this->{session}->{security}->checkAccessPermission
            ( 'change', $user, undef, $topic, $web )) {

        throw TWiki::AccessControlException(
            'CHANGE', $user, $web, $topic,
            $this->{session}->{security}->getReason());
    }
    my $plugins = $this->{session}->{plugins};
    # Semantics inherited from Cairo. See
    # TWiki:Codev.BugBeforeSaveHandlerBroken
    if( $plugins->haveHandlerFor( 'beforeSaveHandler' )) {
        if( $meta ) {
            $text = _writeMeta( $meta, $text );
        }
        $plugins->beforeSaveHandler( $text, $topic, $web, $meta );
        # remove meta again and throw it away (!)
        my $trash = new TWiki::Meta( $this->{session}, $web, $topic);
        $this->extractMetaData( $trash, \$text );
    }
    my $error;
    try {
        $this->_noHandlersSave( $user, $web, $topic, $text, $meta, $options );
    } catch Error::Simple with {
        $error = shift;
    };

    # Semantics inherited from Cairo. See
    # TWiki:Codev.BugBeforeSaveHandlerBroken
    if( $plugins->haveHandlerFor( 'afterSaveHandler' )) {
        if( $meta ) {
            $text = _writeMeta( $meta, $text );
        }
        $plugins->afterSaveHandler( $text, $topic, $web,
                                    $error?$error->{-text}:'', $meta );
    }

    throw $error if $error;
}

=pod

---++ ObjectMethod saveAttachment ($web, $topic, $attachment, $user, $opts )
   * =$user= - user doing the saving
   * =$web= - web for topic
   * =$topic= - topic to atach to
   * =$attachment= - name of the attachment
   * =$opts= - Ref to hash of options
=$opts= may include:
| =dontlog= | don't log this change in twiki log |
| =comment= | comment for save |
| =hide= | if the attachment is to be hidden in normal topic view |
| =stream= | Stream of file to upload |
| =file= | Name of a file to use for the attachment data. ignored is stream is set. |
| =filepath= | Client path to file |
| =filesize= | Size of uploaded data |
| =filedate= | Date |

Saves a new revision of the attachment, invoking plugin handlers as
appropriate.

If file is not set, this is a properties-only save.

=cut

sub saveAttachment {
    my( $this, $web, $topic, $attachment, $user, $opts ) = @_;
    ASSERT($this->isa('TWiki::Store')) if DEBUG;
    ASSERT($user->isa('TWiki::User')) if DEBUG;
    ASSERT(defined($opts)) if DEBUG;
    my $action;
    my $plugins = $this->{session}->{plugins};
    my $attrs;

    $this->lockTopic( $user, $web, $topic );

    try {
        # update topic
        my( $meta, $text ) = $this->readTopic( undef, $web, $topic, undef );

        if( $user &&
              !$this->{session}->{security}->checkAccessPermission
                ( 'change', $user, $text, $topic, $web )) {

            throw TWiki::AccessControlException(
                'CHANGE', $user, $web, $topic,
                $this->{session}->{security}->getReason());
        }

        if( $opts->{file} && !$opts->{stream} ) {
            open($opts->{stream}, $opts->{file}) ||
              throw Error::Simple('Could not open '.$opts->{file} );
            binmode($opts->{stream}) ||
              throw Error::Simple( $opts->{file}.' binmode failed: '.$! );
        }

        if ( $opts->{stream} ) {
            my $fileVersion = $this->getRevisionNumber( $web, $topic,
                                                        $attachment );
            $action = 'upload';

            $attrs = {
                attachment => $attachment,
                stream => $opts->{stream},
                comment => $opts->{comment},
                user => $user->webDotWikiName()
               };

            my $handler = $this->_getHandler( $web, $topic, $attachment );

            my $tmpFile = $handler->{file};

            if( $plugins->haveHandlerFor( 'beforeAttachmentSaveHandler' )) {
                # SMELL: legacy spec of beforeAttachmentSaveHandler requires
                # a local copy of the stream. This could be a problem for
                # very big data files.
                open( F, $tmpFile );
                binmode( F );
                # transfer 512KB blocks
                while( my $r = sysread( $opts->{stream}, $text, 0x80000 )) {
                    syswrite( F, $text, $r );
                }
                close( F );
                $attrs->{file} = $tmpFile;
                $plugins->beforeAttachmentSaveHandler( $attrs, $topic, $web );
                open( $opts->{stream}, $tmpFile );
                binmode( $opts->{stream} );
            }

            my $error;
            try {
                $handler->addRevisionFromStream( $opts->{stream},
                                                 $opts->{comment},
                                                 $user->wikiName() );
            } catch Error::Simple with {
                $error = shift;
            };

            if( $plugins->haveHandlerFor( 'afterAttachmentSaveHandler' )) {
                # SMELL: legacy spec of afterAttachmentSaveHandler requires
                # a local copy of the stream. This could be a problem for
                # very big data files. It really should use the stream.
                open( F, $tmpFile );
                binmode(F);
                while( read($opts->{stream}, $text, 1024 )) {
                    print F $text;
                }
                close(F);
                $attrs->{file} = $tmpFile;
                $plugins->afterAttachmentSaveHandler( $attrs, $topic, $web,
                                                      $error ? 
                                                        $error->{-text} : '' );
            }
            throw $error if $error;

            $attrs->{name} ||= $attachment;
            $attrs->{version} = $fileVersion;
            $attrs->{path} = $opts->{filepath},;
            $attrs->{size} = $opts->{filesize};
            $attrs->{date} = $opts->{filedate};
            $attrs->{attr} = ( $opts->{hide} ) ? 'h' : '';

            $meta->putKeyed( 'FILEATTACHMENT', $attrs );
        } else {
            $attrs = $meta->get( 'FILEATTACHMENT', $attachment );
            $attrs->{name} = $attachment;
            $attrs->{attr} = ( $opts->{hide} ) ? 'h' : '';
            $attrs->{comment} = $opts->{comment};
            $meta->putKeyed( 'FILEATTACHMENT', $attrs );
        }

        if( $opts->{createlink} ) {
            $text .= $this->{session}->{attach}->getAttachmentLink(
                $user, $web, $topic, $attachment, $meta );
        }

        $this->saveTopic( $user, $web, $topic, $text, $meta, {} );

    } finally {
        $this->unlockTopic( $user, $web, $topic );
    };

    unless( $opts->{dontlog} ) {
        $this->{session}->writeLog( $action, $web.'.'.$topic, $attachment, $user );
    }
}

# Save a topic or attachment _without_ invoking plugin handlers.
# FIXME: does rev info from meta work if user saves a topic with no change?
sub _noHandlersSave {
    my( $this, $user, $web, $topic, $text, $meta, $options ) = @_;

    ASSERT($user->isa('TWiki::User')) if DEBUG;

    $meta ||= new TWiki::Meta( $this->{session}, $web, $topic );

    my $handler = $this->_getHandler( $web, $topic );
    my $currentRev = $handler->numRevisions() || 0;
    my $nextRev = $currentRev + 1;

    if( $currentRev && !$options->{forcenewrevision} ) {
        # See if we want to replace the existing top revision
        my $mtime1 = $handler->getTimestamp();
        my $mtime2 = time();

        if( abs( $mtime2 - $mtime1 ) <
              $TWiki::cfg{ReplaceIfEditedAgainWithin} ) {

            my( $rev, $date, $revuser, $comment ) =
              $handler->getRevisionInfo( $currentRev );

            # same user?
            if(  $revuser eq $user->wikiName() ) {
                $this->repRev( $user, $web, $topic, $text,
                               $meta, $options );
                return;
            }
        }
    }

    if( $meta ) {
        $meta->addTOPICINFO( $nextRev, time(), $user );
        $text = _writeMeta( $meta, $text );
    }

    # will block
    $this->lockTopic( $user, $web, $topic );

    try {
        $handler->addRevisionFromText( $text, $options->{comment},
                                       $user->wikiName() );
    } finally {
        $this->unlockTopic( $user, $web, $topic );
    };

    # update .changes
    my @foo = split( /\r?\n/, $this->readMetaData( $web, 'changes' ));
    shift( @foo) if( $#foo > 500 );
    my $minor = '';
    $minor = "\tminor" if $options->{minor};
    push( @foo, "$topic\t".$user->login()."\t".time()."\t$nextRev$minor" );
    $this->saveMetaData( $web, 'changes', join( "\n", @foo ));

    if( ( $TWiki::cfg{Log}{save} ) && ! ( $options->{dontlog} ) ) {
        # write log entry
        my $extra = '';
        $extra   .= 'minor' if( $options->{minor} );
        $this->{session}->writeLog( 'save', $web.'.'.$topic, $extra, $user );
    }
}

=pod

---++ ObjectMethod repRev( $user, $web, $topic, $text, $meta, $options )
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

    ASSERT($meta && $meta->isa('TWiki::Meta')) if DEBUG;

    my( $revdate, $revuser, $rev ) = $meta->getRevisionInfo();

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
    $meta->addTOPICINFO( $rev, $revdate, $revuser );
    $text = _writeMeta( $meta, $text );

    $this->lockTopic( $user, $web, $topic );
    try {
        my $handler = $this->_getHandler( $web, $topic );
        $handler->replaceRevision( $text, $options->{comment},
                                        $revuser->wikiName(), $revdate );
    } finally {
        $this->unlockTopic( $user, $web, $topic );
    };

    if( ( $TWiki::cfg{Log}{save} ) && ! ( $options->{dontlog} ) ) {
        # write log entry
        my $extra = 'repRev by '.$user->login().": $rev " .
          $revuser->login().
            ' '. TWiki::Time::formatTime( $revdate, '$rcs', 'gmtime' );
        $extra   .= ' minor' if( $options->{minor} );
        $this->{session}->writeLog( 'cmd', $web.'.'.$topic, $extra, $user );
    }
}

=pod

---++ ObjectMethod delRev( $user, $web, $topic, $text, $meta, $options )

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

    my $rev = $this->getRevisionNumber( $web, $topic );
    if( $rev <= 1 ) {
        throw Error::Simple( 'Cannot delete initial revision of '.
                               $web.'.'.$topic );
    }

    $this->lockTopic( $user, $web, $topic );
    try {
        my $handler = $this->_getHandler( $web, $topic );
        $handler->deleteRevision();

        # restore last topic from repository
        $handler->restoreLatestRevision();
    } finally {
        $this->unlockTopic( $user, $web, $topic );
    };

    # TODO: delete entry in .changes

    # write log entry
    $this->{session}->writeLog( 'cmd', $web.'.'.$topic, 'delRev by '.
                                  $user->login().": $rev", $user );
}

=pod

---++ ObjectMethod lockTopic( $web, $topic )

Grab a topic lock on the given topic. A topic lock will cause other
processes that also try to claim a lock to block. A lock has a
maximum lifetime of 2 minutes, so operations on a locked topic
must be completed within that time. You cannot rely on the
lock timeout clearing the lock, though; that should always
be done by calling unlockTopic. The best thing to do is to guard
the locked section with a try..finally clause. See man Error for more info.

Topic locks are used to make store operations atomic. They are
_note_ the locks used when a topic is edited; those are Leases
(see =getLease=)

=cut

sub lockTopic {
    my ( $this, $locker, $web, $topic ) = @_;
    ASSERT($this->isa('TWiki::Store')) if DEBUG;
    ASSERT($locker->isa('TWiki::User')) if DEBUG;
    ASSERT($web && $topic) if DEBUG;

    my $handler = $this->_getHandler( $web, $topic );

    while ( 1 ) {
        my ( $user, $time ) = $handler->isLocked();
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
            $handler->setLock( 0 );
            last;
        }
        # wait a couple of seconds before trying again
        sleep(2);
    }

    $handler->setLock( 1, $locker->wikiName() );
}

=pod

---++ ObjectMethod unlockTopic( $user, $web, $topic )
Release the topic lock on the given topic. A topic lock will cause other
processes that also try to claim a lock to block. It is important to
release a topic lock after a guard section is complete. This should
normally be done in a 'finally' block. See man Error for more info.

Topic locks are used to make store operations atomic. They are
_note_ the locks used when a topic is edited; those are Leases
(see =getLease=)

=cut

sub unlockTopic {
    my ( $this, $user, $web, $topic ) = @_;
    ASSERT($this->isa('TWiki::Store')) if DEBUG;
    ASSERT($user->isa('TWiki::User')) if DEBUG;

    my $handler = $this->_getHandler( $web, $topic );
    $handler->setLock( 0, $user->wikiName() );
}

=pod

---++ ObjectMethod webExists( $web ) -> $boolean

Test if web exists
   * =$web= - Web name, required, e.g. ='Sandbox'=

A web _has_ to have a home topic to be a web.

=cut

sub webExists {
    my( $this, $web ) = @_;
    ASSERT($this->isa('TWiki::Store')) if DEBUG;
    $web =~ s#\.#/#go;

    return 0 unless defined $web;
    my $handler = $this->_getHandler( $web, $TWiki::cfg{HomeTopicName} );
    return $handler->storedDataExists();
}

=pod

---++ ObjectMethod topicExists( $web, $topic ) -> $boolean

Test if topic exists
   * =$web= - Web name, optional, e.g. ='Main'=
   * =$topic= - Topic name, required, e.g. ='TokyoOffice'=, or ="Main.TokyoOffice"=

=cut

sub topicExists {
    my( $this, $web, $topic ) = @_;
    $web =~ s#\.#/#go;
    ASSERT($this->isa('TWiki::Store')) if DEBUG;
    ASSERT(defined($topic)) if DEBUG;

    return 0 unless $topic;

    my $handler = $this->_getHandler( $web, $topic );
    return $handler->storedDataExists();
}

# Expect meta data at top of file, but willing to accept it anywhere.
# If we have an old file format without meta data, then convert.
#
# If autoattachments is on then get this from the filestore rather than meta data
#
# SMELL: SIDE-EFFECTING FUNCTION meta-data is stripped from the $rtext
#
# SMELL: Calls to this method from outside of Store
# should be avoided at all costs, as it exports the assumption that
# meta-data is embedded in text.
#
sub extractMetaData {
    my( $this, $meta, $rtext ) = @_;
    ASSERT($this->isa('TWiki::Store')) if DEBUG;
    ASSERT(defined($$rtext)) if DEBUG;

    my $format = $STORE_FORMAT_VERSION;
    # head meta-data
    $$rtext =~ s(^%META:TOPICINFO{(.*)}%\r?\n)
      ($meta->put( 'TOPICINFO', _readKeyValues( $1 ));'')gem;

    my $ti = $meta->get( 'TOPICINFO' );
    if( $ti ) {
        $format = $ti->{format} || $STORE_FORMAT_VERSION;
        # Make sure we update the topic format
        $ti->{format} = $STORE_FORMAT_VERSION;
    }

    my $endMeta = 0;

    $$rtext =~ s(^%META:([^{]+){(.*)}%\r?\n)
      ($endMeta=1;$meta->putKeyed( $1, _readKeyValues( $2, $format )),'')gem;

    # eat the extra newline put in to separate text from tail meta-data
    $$rtext =~ s/\n$//s if $endMeta;

    # If there is no meta data then convert from old format
    if( ! $meta->count( 'TOPICINFO' ) ) {
        if ( $$rtext =~ /<!--TWikiAttachment-->/ ) {
            $$rtext = $this->{session}->{attach}->migrateToFileAttachmentMacro( $meta,
                                                                                $$rtext );
        }

        if ( $$rtext =~ /<!--TWikiCat-->/ ) {
            require TWiki::Compatibility;
            $$rtext = TWiki::Compatibility::upgradeCategoryTable( $this->{session}, $meta->web(), $meta->topic(),
                                                                  $meta, $$rtext );
        }
    } elsif( $format eq '1.0beta' ) {
        # This format used live at DrKW for a few months
        if( $$rtext =~ /<!--TWikiCat-->/ ) {
            require TWiki::Compatibility;
            $$rtext = TWiki::Compatibility::upgradeCategoryTable( $this->{session}, $meta->web(), $meta->topic(),
                                                                  $meta,
                                                                  $$rtext );
        }
        $this->{session}->{attach}->upgradeFrom1v0beta( $meta );
        if( $meta->count( 'TOPICMOVED' ) ) {
            my $moved = $meta->get( 'TOPICMOVED' );
            my $u = $this->{session}->{users}->findUser( $moved->{by} );
            $moved->{by} = $u->wikiName() if $u;
            $meta->put( 'TOPICMOVED', $moved );
        }
    }

    return $meta;
}

sub extractMetaDataAutoAttachments {
    
    my( $this, $user, $web, $topic, $version, $attachmentsKnownInMeta ) = @_;    
 
	if ($TWiki::cfg{AutoAttachPubFiles}) {
#  	   print "AUTOATTACHING on $web.$topic\nFOUND BEFORE ".Dumper($attachmentsKnownInMeta)."\n";
       my @attachmentsFoundInPub = findAttachments($this, $web, $topic, $attachmentsKnownInMeta);
#       print "FOUND AFTER ".Dumper(\@attachmentsFoundInPub);
       return \@attachmentsFoundInPub;
    } else {
#       print "NOT AUTOATTACHING on $web.$topic\n ".Dumper($attachmentsKnownInMeta)."\n";
       return $attachmentsKnownInMeta;
    }
    
}

=pod

---++ ObjectMethod getTopicParent (  $web, $topic  ) -> $string

Get the name of the topic parent. Needs to be fast because
of use by Render.pm.

=cut

# SMELL: does not honour access controls

sub getTopicParent {
    my( $this, $web, $topic ) = @_;
    ASSERT($this->isa('TWiki::Store')) if DEBUG;
    ASSERT(defined($web)) if DEBUG;
    ASSERT(defined($topic)) if DEBUG;

    return undef unless $this->topicExists( $web, $topic );

    my $handler = $this->_getHandler( $web, $topic );

    my $strm = $handler->getStream();
    my $data = '';
    while( ( my $line = <$strm> ) ) {
        if( $line !~ /^%META:/ ) {
            last;
        } else {
            $data .= $line;
        }
    }
    close( $strm );

    my $meta = new TWiki::Meta( $this->{session}, $web, $topic );
    $this->extractMetaData( $meta, \$data );
    my $parentMeta = $meta->get( 'TOPICPARENT' );
    return $parentMeta->{name} if $parentMeta;
    return undef;
}

=pod

---++ ObjectMethod getTopicLatestRevTime (  $web, $topic  ) -> $epochSecs

Get an approximate rev time for the latest rev of the topic. This method
is used to optimise searching. Needs to be as fast as possible.

=cut

sub getTopicLatestRevTime {
    my ( $this, $web, $topic ) = @_;
    $web =~ s#\.#/#go;

    my $handler = $this->_getHandler( $web, $topic );
    return $handler->getLatestRevisionTime();
}

=pod

---++ ObjectMethod readMetaData( $web, $name ) -> $text

Read a named meta-data string. If web is given the meta-data
is stored alongside a web.

=cut

sub readMetaData {
    my ( $this, $web, $name ) = @_;
    ASSERT($this->isa('TWiki::Store')) if DEBUG;
    $web =~ s#\.#/#go;

    my $handler = $this->_getHandler( $web );
    return $handler->readMetaData( $name );
}

=pod

---++ ObjectMethod saveMetaData( $web, $name ) -> $text

Write a named meta-data string. If web is given the meta-data
is stored alongside a web.

=cut

sub saveMetaData {
    my ( $this, $web, $name, $text ) = @_;
    ASSERT($this->isa('TWiki::Store')) if DEBUG;
    $web =~ s#\.#/#go;

    my $handler = $this->_getHandler( $web );
    return $handler->saveMetaData( $name, $text );
}

=pod

---++ ObjectMethod getTopicNames( $web ) -> @topics

Get list of all topics in a web
   * =$web= - Web name, required, e.g. ='Sandbox'=
Return a topic list, e.g. =( 'WebChanges',  'WebHome', 'WebIndex', 'WebNotify' )=

=cut

sub getTopicNames {
    my( $this, $web ) = @_ ;
    ASSERT($this->isa('TWiki::Store')) if DEBUG;

    $web =~ s#\.#/#go;

    my $handler = $this->_getHandler( $web );
    return $handler->getTopicNames();
}

=pod

---++ ObjectMethod getListOfWebs( $filter ) -> @webNames

Gets a list of webs, filtered according to the spec in the $filter,
which may include one of:
   1 'user' (for only user webs)
   2 'template' (for only template webs)
$filter may also contain the word 'public' which will further filter
webs on whether NOSEARCHALL is specified for them or not.

If $TWiki::cfg{EnableHierarchicalWebs} is set, will also list
sub-webs recursively.

=cut

sub getListOfWebs {
    my( $this, $filter, $web ) = @_;
    ASSERT($this->isa('TWiki::Store')) if DEBUG;
    $filter ||= '';
    $web ||= '';
    $web =~ s#\.#/#g;

    my @webList = $this->_getSubWebs( $web );

    if ( $filter =~ /\buser\b/ ) {
        @webList = grep { !/(?:^_|\/_)/, } @webList;
    } elsif( $filter =~ /\btemplate\b/ ) {
        @webList = grep { /(?:^_|\/_)/, } @webList;
    }

    my $prefs = $this->{session}->{prefs};
    if( $filter =~ /\bpublic\b/ ) {
        @webList =
          grep {
              $_ eq $this->{session}->{webName} ||
                !$prefs->getWebPreferencesValue( 'NOSEARCHALL', $_ )
            } @webList;
    }

    return sort @webList;
}

# get a list of directories within the named web directory. If hierarchical
# webs are enabled, returns a deep list e.g. web, web/subweb,
# web/subweb/subsubweb
sub _getSubWebs {
    my( $this, $web ) = @_ ;

    my $handler = $this->_getHandler( $web );
    my @tmpList = $handler->getWebNames();
    # filter only those webs that meet the webExists criteria
    my @webList;
    if( $web ) {
        # sub-web
        @webList = sort
          grep { $this->webExists( $_ ) } # filter dirs with no WebHome
            map { $web.'/'.$_ }           # add hierarchical path
              @tmpList;
    } else {
        # root level (no parent web)
        @webList = sort
          grep { $this->webExists( $_ ) } # filter dirs with no WebHome
            @tmpList;
    }

    if( $TWiki::cfg{EnableHierarchicalWebs} ) {
        my @subWebList = ();
        foreach my $subWeb ( @webList ) {
            push( @subWebList, $this->_getSubWebs( $subWeb ));
        }
        push( @webList, @subWebList );
    }

    return @webList;
}

=pod

---++ ObjectMethod createWeb( $user, $newWeb, $baseWeb, $opts )

$newWeb is the name of the new web.

$baseWeb is the name of an existing web (a template web). If the
base web is a system web, all topics in it
will be copied into the new web. If it is a normal web, only topics starting
with 'Web' will be copied. If no base web is specified, an empty web
(with no topics) will be created. If it is specified but does not exist,
an error will be thrown.

$opts is a ref to a hash that contains settings to be modified in
the web preferences topic in the new web.

=cut

sub createWeb {
    my ( $this, $user, $newWeb, $baseWeb, $opts ) = @_;
    ASSERT($this->isa('TWiki::Store')) if DEBUG;
    ASSERT($user->isa('TWiki::User')) if DEBUG;

    unless( $baseWeb ) {
        # For a web to be a web, it has to have at least one topic
        my $meta = new TWiki::Meta( $this->{session}, $newWeb,
                                    $TWiki::cfg{HomeTopicName} );
        $this->saveTopic( $user, $newWeb, $TWiki::cfg{HomeTopicName},
                          "Home", $meta );
        return;
    }

    unless( $this->webExists( $baseWeb )) {
        throw Error::Simple( 'Base web '.$baseWeb.' does not exist' );
    }

    $newWeb =~ s#\.#/#go;
    $baseWeb =~ s#\.#/#go if $baseWeb;
    # copy topics from base web
    my @topicList = $this->getTopicNames( $baseWeb );

    unless( $baseWeb =~ /^_/ ) {
        # not a system web, so filter for only Web* topics
        @topicList = grep { /^Web/ } @topicList;
    }

    foreach my $topic ( @topicList ) {
        $this->copyTopic( $user, $baseWeb, $topic, $newWeb, $topic );
    }

    # create meta-data files
    $this->saveMetaData( $newWeb, 'changes', '');
    $this->saveMetaData( $newWeb, 'mailnotify', '');

    # patch WebPreferences in new web
    my $wpt = $TWiki::cfg{WebPrefsTopicName};

    return unless $this->topicExists( $newWeb, $wpt );

    my( $meta, $text ) =
      $this->readTopic( undef, $newWeb, $wpt, undef );

    if( $opts ) {
        foreach my $key ( %$opts ) {
            $text =~ s/($TWiki::regex{setRegex}$key\s*=).*?$/$1 $opts->{$key}/gm;
        }
    }
    $this->saveTopic( $user, $newWeb, $wpt, $text, $meta );
}

=pod

---++ ObjectMethod removeWeb( $user, $web )
   * =$user= - user doing the removing (for the history)
   * =$web= - web being removed

Destroy a web, utterly. Removed the data and attachments in the web.

Use with great care!

The web must be a known web to be removed this way.

=cut

sub removeWeb {
    my( $this, $user, $web ) = @_;
    ASSERT( $web ) if DEBUG;
    $web =~ s#\.#/#go;

    unless( $this->webExists( $web )) {
        throw Error::Simple( 'No such web '.$web );
    }

    my $handler = $this->_getHandler( $web );
    $handler->removeWeb();
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
        $value = dataEncode( $value );
    } else {
        $value = '';
    }

    return $key.'="'.$value.'"';
}

# Write all the key=value pairs for the types listed
sub _writeTypes {
    my( $meta, @types ) = @_;
    ASSERT($meta->isa('TWiki::Meta')) if DEBUG;

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
            $text .= '%META:'.$type.'{';
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
            $text .= '}%'."\n";
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
    ASSERT($meta->isa('TWiki::Meta')) if DEBUG;
    $text ||= '';

    my $start = _writeStart( $meta );
    my $end = _writeEnd( $meta );
    $text = $start . $text;
    $end = "\n".$end if $end;
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
    ASSERT($this->isa('TWiki::Store')) if DEBUG;

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
    ASSERT($this->isa('TWiki::Store')) if DEBUG;

    return 0 unless $rev;

    $rev =~ s/^r//i;
    $rev =~ s/^\d+\.//; # clean up RCS rev number

    return $rev;
}

=pod

---++ ObjectMethod copyTopic($user, $fromweb, $fromtopic, $toweb, $totopic)
Copy a topic and all it's attendant data from one web to another.

SMELL: Does not fix up meta-data!

=cut

sub copyTopic {
    my ( $this, $user, $fromWeb, $fromTopic, $toWeb, $toTopic ) = @_;
    ASSERT($this->isa('TWiki::Store')) if DEBUG;
    $fromWeb =~ s#\.#/#go;
    $toWeb =~ s#\.#/#go;

    my $handler = $this->_getHandler( $fromWeb, $fromTopic );
    $handler->copyTopic( $toWeb, $toTopic );
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
    $web =~ s#\.#/#go;

    my $handler = $this->_getHandler( $web );
    return $handler->searchInWebContent( $searchString, $topics, $options );
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
    my ( $this, $web, $topic, $time ) = @_;

    my $handler = $this->_getHandler( $web, $topic );
    return $handler->getRevisionAtTime( $time );
}

=pod

---++ ObjectMethod getLease( $web, $topic ) -> $lease
   * =$web= - web for topic
   * =$topic= - topic

If there is an lease on the topic, return the lease, otherwise undef.
A lease is a block of meta-information about a topic that can be
recovered (this is a hash containing =user=, =taken= and =expires=).
Leases are taken out when a topic is edited. Only one lease
can be active on a topic at a time. Leases are used to warn if
another user is already editing a topic.

=cut

sub getLease {
    my( $this, $web, $topic ) = @_;

    my $handler = $this->_getHandler( $web, $topic );
    my $lease = $handler->getLease();
    if( $lease ) {
        my $user = $this->{session}->{users}->findUser( $lease->{user} );
        ASSERT( $user->isa('TWiki::User')) if DEBUG;
        $lease->{user} = $user;
    }
    return $lease;
}

=pod

---++ ObjectMethod setLease( $web, $topic, $user, $length )

Take out an lease on the given topic for this user for $length seconds.

See =getLease= for more details about Leases.

=cut

sub setLease {
    my( $this, $web, $topic, $user, $length ) = @_;
    ASSERT( $user->isa( 'TWiki::User') ) if DEBUG;

    my $handler = $this->_getHandler( $web, $topic );
    my $lease;
    if( $user ) {
        my $t = time();
        $lease = { user => $user->wikiName(),
                   expires => $t + $length,
                   taken => $t };
    }

    $handler->setLease( $lease );
}

=pod

---++ ObjectMethod clearLease( $web, $topic )

Cancel the current lease.

See =getLease= for more details about Leases.

=cut

sub clearLease {
    my( $this, $web, $topic ) = @_;

    my $handler = $this->_getHandler( $web, $topic );
    $handler->setLease( undef );
}

1;

