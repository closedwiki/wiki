# Module of TWiki Collaboration Platform, http://TWiki.org/
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
#
# Notes:
# - Latest version at http://twiki.org/
# - Installation instructions in $dataDir/Main/TWikiDocumentation.txt
# - Customize variables in TWiki.cfg when installing TWiki.
# - Optionally change TWiki.pm for custom extensions of rendering rules.
# - Upgrading TWiki is easy as long as you do not customize TWiki.pm.
# - Check web server error logs for errors, i.e. % tail /var/log/httpd/error_log
=begin twiki

---+ TWiki::Store Module

This module hosts the generic storage backend. This module should be the
only module, anywhere, that knows that meta-data is stored interleaved
in the topic text. This is so it can be easily replaced by alternative
store implementations.

=cut

package TWiki::Store;

use File::Copy;
use Time::Local;
use TWiki::Meta;
use Assert;

use strict;

# 'Use locale' for internationalisation of Perl sorting in getTopicNames
# and other routines - main locale settings are done in TWiki::setupLocale
BEGIN {
    # Do a dynamic 'use locale' for this module
    if( $TWiki::useLocale ) {
        eval 'require locale; import locale ();';
    }
}

=pod

---++ sub new()

Construct a Store module, linking in the chosen implementation.

=cut

sub new {
    my ( $class, $session, $impl, $storeSettings ) = @_;
    ASSERT(ref($session) eq "TWiki") if DEBUG;
    my $this = bless( {}, $class );

    $this->{session} = $session;

    $this->{IMPL} = "TWiki::Store::$impl";
    eval "use $this->{IMPL}";
    if( $@ ) {
        die "$this->{IMPL} compile failed $@";
    }
    $this->{ACCESSFAILED} = "";
    $this->{STORESETTINGS} = $storeSettings;

    return $this;
}

sub security { my $this = shift; return $this->{session}->{security}; }
sub sandbox { my $this = shift; return $this->{session}->{sandbox}; }
sub users { my $this = shift; return $this->{session}->{users}; }
sub form { my $this = shift; return $this->{session}->{form}; }
sub attach { my $this = shift; return $this->{session}->{attach}; }
sub search { my $this = shift; return $this->{session}->{search}; }

# PRIVATE
# Get the handler for the current store implementation, either RcsFile
# or RcsLite
sub _getTopicHandler {
    my( $this, $web, $topic, $attachment ) = @_;

    $attachment = "" if( ! $attachment );

    my $handlerName = "TWiki::Store::$TWiki::storeTopicImpl";

    return $this->{IMPL}->new( $this->{session}, $web, $topic,
                               $attachment, $this->{STORESETTINGS} );
}

=pod

---++ readTopic($user, $web, $topic, $version, $internal) -> ($meta, $text)

Reads the given version of a topic and it's meta-data. If the version
is undef, then read the most recent version. The version number must be
an integer, or undef for the latest version.

If $internal is false, view permission will be required for the topic
read to be successful.  A failed topic read is indicated by setting
the status returned by accessFailed(). Permissions are checked for
TWiki::wikiUserName, there is no way to override this.

If the topic contains a web specification (is of the form Web.Topic) the
web specification will override whatever is passed in $theWeb.

The metadata and topic text are returned separately, with the metadata in a
TWiki::Meta object.  (The topic text is, as usual, just a string.)

=cut

sub readTopic {
    my( $this, $user, $theWeb, $theTopic, $version, $internal ) = @_;
    ASSERT(ref($this) eq "TWiki::Store") if DEBUG;
    ASSERT(defined($internal)) if DEBUG;

    my $text = $this->readTopicRaw( $user, $theWeb, $theTopic, $version, $internal );
    my $meta = $this->extractMetaData( $theWeb, $theTopic, \$text );
    return( $meta, $text );
}

=pod

---++ readTopicRaw( $user, $web, $topic, $version, $internal )
Return value: $topicText

Reads the given version of a topic, without separating out any embedded
meta-data. If the version is undef, then read the most recent version.
The version number must be an integer or undef.

If $internal is false, view access permission will be checked.  If permission
is not granted, then an error message will be returned in $text, and set
as the return value of accessFailed. Permissions are checked for
TWiki::wikiUserName, there is no way to overrides this.

If the topic contains a web specification (is of the form Web.Topic) the
web specification will override whatever is passed in $theWeb.

SMELL: DO NOT CALL THIS METHOD UNLESS YOU HAVE NO CHOICE. This method breaks
encapsulation of the store, as it assumes meta is stored embedded in the text.
Other implementors of store will be forced to insert meta-data to ensure
correct operation of View raw=debug and the "repRev" mode of Edit.

=cut

sub readTopicRaw {
    my( $this, $user, $theWeb, $theTopic, $version, $internal ) = @_;
    ASSERT(ref($this) eq "TWiki::Store") if DEBUG;
    ASSERT(defined($internal)) if DEBUG;

    # test if theTopic contains a webName to override $theWeb
    ( $theWeb, $theTopic ) =
      $this->{session}->normalizeWebTopicName( $theWeb, $theTopic );

    my $text;

    unless ( defined( $version )) {
        $text = $this->readFile( "$TWiki::dataDir/$theWeb/$theTopic.txt" );
    } else {
        my $topicHandler = $this->_getTopicHandler( $theWeb, $theTopic, undef );
        $text = $topicHandler->getRevision( $version );
    }

    my $viewAccessOK = 1;
    unless( $internal ) {
        $viewAccessOK =
          $this->security()->checkAccessPermission( "view", $user,
                                                    $text, $theTopic, $theWeb );
    }

    unless( $viewAccessOK ) {
        # SMELL: TWiki::Func::readTopicText will break if the following
        # text changes
        $text = "No permission to read topic $theWeb.$theTopic  - perhaps you need to log in?\n";
        $this->{ACCESSFAILED} .= " $theWeb.$theTopic";
    }

    return $text;
}

=pod

---++ sub accessFailed ()
Returns a string containing the names of all topics that have have had access
failures since this Store was created.

=cut
sub accessFailed {
    my $this = shift;
    ASSERT(ref($this) eq "TWiki::Store") if DEBUG;

    return $this->{ACCESSFAILED};
}

=pod

---++ sub moveAttachment (  $oldWeb, $oldTopic, $newWeb, $newTopic, $theAttachment, $user  )

Move an attachment from one topic to another.

If there is a problem an error string is returned.

The caller to this routine should check that all topics are valid.

SMELL: $user must be the user login name, not their wiki name

=cut

sub moveAttachment {
    my( $this, $oldWeb, $oldTopic, $newWeb, $newTopic,
        $theAttachment, $user ) = @_;
    ASSERT(ref($this) eq "TWiki::Store") if DEBUG;
    ASSERT(defined($user)) if DEBUG;

    $this->lockTopic( $user, $oldWeb, $oldTopic );

    my $wName = $this->users()->userToWikiName( $user );
    # Remove file attachment from old topic
    my $topicHandler = $this->_getTopicHandler( $oldWeb, $oldTopic, $theAttachment );
    my $error = $topicHandler->moveMe( $newWeb, $newTopic );

    if( $error ) {
        $this->unlockTopic( $user, $oldWeb, $oldTopic );
        $this->unlockTopic( $user, $newWeb, $newTopic );
        return $error;
    }

    my( $meta, $text ) = $this->readTopic( $wName, $oldWeb, $oldTopic, 1 );
    my %fileAttachment =
      $meta->findOne( "FILEATTACHMENT", $theAttachment );
    $meta->remove( "FILEATTACHMENT", $theAttachment );
    $error = $this->_noHandlersSave( $user, $oldWeb, $oldTopic,
                                     $text, $meta,
                                     { notify => 0 } );

    $this->unlockTopic( $user, $oldWeb, $oldTopic );
    if( $error ) {
        $this->unlockTopic( $user, $newWeb, $newTopic );
        return $error;
    }

    # Add file attachment to new topic
    ( $meta, $text ) = $this->readTopic( $wName, $newWeb, $newTopic, 1 );
    $fileAttachment{"movefrom"} = "$oldWeb.$oldTopic";
    $fileAttachment{"moveby"}   = $user;
    $fileAttachment{"movedto"}  = "$newWeb.$newTopic";
    $fileAttachment{"movedwhen"} = time();
    $meta->put( "FILEATTACHMENT", %fileAttachment );

    $error = $this->_noHandlersSave( $user, $newWeb, $newTopic, $text,
                                      $meta, { notify => 0,
                                               comment => "moved" } );

    $this->unlockTopic( $user, $newWeb, $newTopic );

    return $error if( $error );

    $this->{session}->writeLog( "move", "$oldWeb.$oldTopic",
                     "Attachment $theAttachment moved to $newWeb.$newTopic" );


    return $error;
}

=pod

---++ sub getAttachmentStream( $web, $topic, $attName ) -> stream
| =$web= | The web |
| =$topic= | The topic |
| =$attName= | Name of the attachment |
Open a standard input stream from an attachment. Will return undef
if the stream could not be opened (permissions, or nonexistant etc)

=cut

sub getAttachmentStream {
    my $this = shift;
    #my ( $web, $topic, $att ) = @_;
    ASSERT(ref($this) eq "TWiki::Store") if DEBUG;

    my $topicHandler = $this->_getTopicHandler( @_ );
    my $strm;
    my $fp = $topicHandler->{file};
    if ( $fp ) {
        unless ( open( $strm, "<$fp" )) {
            $this->{session}->writeWarning( "File $fp open failed: error $!" );
        }
    }
    return $strm;
}

=pod

---++ sub attachmentExists( $web, $topic, $att ) -> boolean

Determine if the attachment already exists on the given topic

=cut

sub attachmentExists {
    my $this = shift;
    #my ( $web, $topic, $att ) = @_;

    ASSERT(ref($this) eq "TWiki::Store") if DEBUG;
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
   
   my $out = "";
   
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

---++ sub renameTopic(  $oldWeb, $oldTopic, $newWeb, $newTopic, $doChangeRefTo  $user ) -> error string or undef

Rename a topic, allowing for transfer between Webs. This method will change
all references _from_ this topic to other topics _within the old web_
so they still work after it has been moved to a new web.

It is the responsibility of the caller to check for existence of webs,
topics & lock taken for topic

SMELL: $user must be the user login name, not their wiki name

=cut

sub renameTopic {
    my( $this, $oldWeb, $oldTopic, $newWeb, $newTopic, $doChangeRefTo, $user ) = @_;
    ASSERT(ref($this) eq "TWiki::Store") if DEBUG;
    ASSERT(defined($user)) if DEBUG;

    # will block
    $this->lockTopic( $user, $oldWeb, $oldTopic );

    my $topicHandler = $this->_getTopicHandler( $oldWeb, $oldTopic, "" );
    my $error = $topicHandler->moveMe( $newWeb, $newTopic );
    my $wName = $this->users()->userToWikiName( $user );

    if( ! $error ) {
        my $time = time();
        my @args = (
                    "from" => "$oldWeb.$oldTopic",
                    "to"   => "$newWeb.$newTopic",
                    "date" => "$time",
                    "by"   => "$user" );
        my $text = $this->readTopicRaw( $wName, $newWeb, $newTopic, undef, 1 );
        if( ( $oldWeb ne $newWeb ) && $doChangeRefTo ) {
            $text = $this->_changeRefTo( $text, $oldWeb, $oldTopic );
        }
        my $meta = $this->extractMetaData( $newWeb, $newTopic, \$text );
        $meta->put( "TOPICMOVED", @args );

        $this->_noHandlersSave( $user, $newWeb, $newTopic, $text, $meta,
                                { comment => "renamed" } );
    }

    $this->unlockTopic( $user, $oldWeb, $oldTopic );

    # Log rename
    if( $TWiki::doLogRename ) {
        $this->{session}->writeLog( "rename", "$oldWeb.$oldTopic", "moved to $newWeb.$newTopic $error" );
    }

    return $error;
}

=pod

---++ sub updateReferringPages (  $oldWeb, $oldTopic, $wikiUserName, $newWeb, $newTopic, @refs  ) -> ( count of lock failures, result text)

Update pages that refer to a page that is being renamed/moved. Return the
number of updates that failed due to active locks and a message.

SMELL: This breaks the encapsulation of the Render function quite horribly.
It should really be done by asking the Renderer to render the topic with
a bunch of simplified handlers plugged in, and just one handler (the
handler for TWiki links) provided to change the link name.

=cut

sub updateReferringPages {
    my ( $this, $oldWeb, $oldTopic, $user, $newWeb, $newTopic, @refs ) = @_;
    ASSERT(ref($this) eq "TWiki::Store") if DEBUG;

    my $result = "";
    my $preTopic = '^|\W';		# Start of line or non-alphanumeric
    my $postTopic = '$|\W';	# End of line or non-alphanumeric
    my $spacedTopic = TWiki::searchableTopic( $oldTopic );
    my $wikiUserName = $this->users()->userToWikiName( $user );
    my $lockFailures = 0;

    while ( @refs ) {
        my $type = shift @refs;
        my $item = shift @refs;
        my( $itemWeb, $itemTopic ) = $this->{session}->normalizeWebTopicName( "", $item );
        my $resultText = "";
        $result .= ":$item: , "; 
        #open each file, replace $topic with $newTopic
        if ( $this->topicExists($itemWeb, $itemTopic) ) {
            $this->lockTopic( $user, $itemWeb, $itemTopic );
            my $scantext =
              $this->readTopicRaw( $wikiUserName, $itemWeb, $itemTopic,
                                   undef, 0 );
            if( ! $this->security()->checkAccessPermission( "change",
                                                            $wikiUserName,
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
            foreach( split( /\n/, $scantext ) ) {
                if( /^%META:TOPIC(INFO|MOVED)/ ) {
                    $resultText .= "$_\n";
                    next;
                }
                # FIXME This code is in far too many places - also in Search.pm and Store.pm
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
                    if( $type eq "global" ) {
                        my $insertWeb = ($itemWeb eq $newWeb) ? "" : "$newWeb.";
                        s/($preTopic)\Q$oldWeb.$oldTopic\E(?=$postTopic)/$1$insertWeb$newTopic/g;
                    } else {
                        # Only replace bare topic (i.e. not preceeded by web) if web of referring
                        # topic is in original Web of topic that's being moved
                        if( $oldWeb eq $itemWeb ) {
                            my $insertWeb = ($oldWeb eq $newWeb) ? "" : "$newWeb.";
                            s/($preTopic)\Q$oldTopic\E(?=$postTopic)/$1$insertWeb$newTopic/g;
                            s/\[\[($spacedTopic)\]\]/[[$newTopic][$1]]/gi;
                        }
                    }
                }
                $resultText .= "$_\n";
            }
            my $meta = $this->extractMetaData( $itemWeb, $itemTopic,
                                               \$resultText );
            $this->saveTopic( $user, $itemWeb, $itemTopic,
                              $resultText, $meta,
                              { unlock => 1, dontnotify => 1 } );
            $this->unlockTopic( $user, $itemWeb, $itemTopic );
        } else {
            $result .= ";$item does not exist;";
        }
    }
    return $result;
}


=pod

---++ sub readAttachmentVersion (  $theWeb, $theTopic, $theAttachment, $theRev  )

Read the given version of an attachment, returning the content.

=cut

sub readAttachmentVersion {
   my ( $this, $theWeb, $theTopic, $theAttachment, $theRev ) = @_;
    ASSERT(ref($this) eq "TWiki::Store") if DEBUG;

   my $topicHandler = $this->_getTopicHandler( $theWeb, $theTopic, $theAttachment );
   return $topicHandler->getRevision( $theRev );
}

=pod

---++ sub getRevisionNumber ( $theWebName, $theTopic, $attachment  )

Get the revision number of the most recent revision. Returns
the integer revision number or "" if the topic doesn't exist.

WORKS FOR ATTACHMENTS AS WELL AS TOPICS

=cut

sub getRevisionNumber {
    my( $this, $theWebName, $theTopic, $attachment ) = @_;
    ASSERT(ref($this) eq "TWiki::Store") if DEBUG;

    $attachment = "" unless $attachment;

    my $topicHandler = $this->_getTopicHandler( $theWebName, $theTopic, $attachment );
    return $topicHandler->numRevisions();
}


=pod

---++ sub getRevisionDiff (  $web, $topic, $rev1, $rev2, $contextLines  )

| $webName|
| $topic |
| $rev1 | Integer revision number |
| $rev2 | Integer revision number |
</pre>
| Return: =\@diffArray= | reference to an array of [ diffType, $right, $left ] |

=cut

sub getRevisionDiff {
    my( $this, $web, $topic, $rev1, $rev2, $contextLines ) = @_;
    ASSERT(ref($this) eq "TWiki::Store") if DEBUG;
    ASSERT(defined($contextLines)) if DEBUG;

    my $rcs = $this->_getTopicHandler( $web, $topic );
    my( $error, $diffArrayRef ) =
      $rcs->revisionDiff( $rev1, $rev2, $contextLines );
    return $diffArrayRef;
}


=pod

---+++ getRevisionInfo($theWebName, $theTopic, $theRev, $attachment, $topicHandler) ==> ( $date, $user, $rev, $comment ) 
| Description: | Get revision info of a topic |
| Parameter: =$theWebName= | Web name, optional, e.g. ="Main"= |
| Parameter: =$theTopic= | Topic name, required, e.g. ="TokyoOffice"= |
| Parameter: =$theRev= | revision number |
| Parameter: =$attachment= |attachment filename |
| Parameter: =$topicHandler= | internal store use only |
| Return: =( $date, $user, $rev, $comment )= | List with: ( last update date, login name of last user, integer revision number ), e.g. =( 1234561, "phoeny", "5" )= |
| $date | in epochSec |
| $user | |
| $rev | the revision number |
| $comment | WHAT COMMENT? |

=cut

sub getRevisionInfo {
    my( $this, $theWebName, $theTopic, $theRev, $attachment, $topicHandler ) = @_;
    ASSERT(ref($this) eq "TWiki::Store") if DEBUG;

    $theRev = 0 unless( $theRev );

    unless( $topicHandler ) {
        $topicHandler =
          $this->_getTopicHandler( $theWebName, $theTopic, $attachment );
    }
    my( $rcsOut, $rev, $date, $user, $comment ) =
      $topicHandler->getRevisionInfo( $theRev );

    return ( $date, $user, $rev, $comment );
}

# STATIC Build a hash by parsing name=value comma separated pairs
# SMELL: duplication of TWiki::extractParameters, using a different
# system of escapes :-(
sub _readKeyValue
{
    my( $args ) = @_;
    my %res = ();

    # Format of data is name="value" name1="value1" [...]
    while( $args =~ s/\s*([^=]+)=\"([^"]*)\"//o ) {
        my $key = $1;
        my $value = $2;
        # reverse the encoding in _writeKeyValue
        $value =~ s/%_N_%/\n/g;
        $value =~ s/%_Q_%/\"/g;
        $value =~ s/%_P_%/%/g;
        $res{$key} = $value;
    }
    return %res;
}

=pod

---++ sub saveTopic (  $user, $web, $topic, $text, $meta, $options  )
| =$user= | login name of user doing the saving |
| =$web= | web for topic |
| =$topic= | topic to atach to |
| =$text= | topic text |
| =$meta= | topic meta-data |
| =$options= | Ref to hash of options |
=$options= may include:
| =dontlog= | don't log this change in twiki log |
| =dontnotify= | don't log this change in .changes |
| =hide= | if the attachment is to be hidden in normal topic view |
| =comment= | comment for save |
| =file= | Temporary file name to upload |
| =savecmd= | Save command |
| =forcedate= | grr |
| =unlock= | |

Save a new revision of the topic, calling plugins handlers as appropriate.

=cut

sub saveTopic {
    my( $this, $user, $web, $topic, $text, $meta, $options ) = @_;
    ASSERT(ref($this) eq "TWiki::Store") if DEBUG;
    ASSERT(ref($meta) eq "TWiki::Meta") if DEBUG;

    $options = {} unless defined( $options );

    # SMELL: Staggeringly inefficient code that adds meta-data for
    # Plugin callback. Why not simply pass the meta in? It would be far
    # more sensible.
    $text = _writeMeta( $meta, $text );  # add meta data for Plugin callback
    $this->{session}->{plugins}->beforeSaveHandler( $text, $topic, $web );
    # remove meta data again!
    $meta = $this->extractMetaData( $web, $topic, \$text );
    my $error =
      $this->_noHandlersSave( $user, $web, $topic, $text, $meta,
                              $options );
    $text = _writeMeta( $meta, $text );  # add meta data for Plugin callback
    $this->{session}->{plugins}->afterSaveHandler( $text, $topic, $web, $error );
    return $error;
}

=pod

---++ sub saveAttachment ($web, $topic, $attachment, $opts )
| =$web= | web for topic |
| =$topic= | topic to atach to |
| =$user= | user doing the saving |
| =$attachment= | name of the attachment |
| =$opts= | Ref to hash of options |
=$opts= may include:
| =dontlog= | don't log this change in twiki log |
| =dontnotify= | don't log this change in .changes |
| =hide= | if the attachment is to be hidden in normal topic view |
| =comment= | comment for save |
| =file= | Temporary file name to upload |

Saves a new revision of the attachment, invoking plugin handlers as
appropriate.

If file is not set, this is a properties-only save.

=cut

sub saveAttachment {
    my( $this, $web, $topic, $attachment, $user, $opts ) = @_;
    ASSERT(ref($this) eq "TWiki::Store") if DEBUG;
    ASSERT(defined($opts)) if DEBUG;
    my $action;

    $this->lockTopic( $user, $web, $topic );

    # update topic
    my( $meta, $text ) = $this->readTopic( $user, $web, $topic, undef, 1 );

    if ( $opts->{file} ) {
        my $fileVersion = $this->getRevisionNumber( $web, $topic,
                                                    $attachment );
        $action = "upload";

        my %attrs =
          (
           attachment => $attachment,
           tmpFilename => $opts->{file},
           comment => $opts->{comment},
           user => $user
          );

        my $topicHandler = $this->_getTopicHandler( $web, $topic, $attachment );
        $this->{session}->{plugins}->beforeAttachmentSaveHandler( \%attrs,
                                                     $topic, $web );
        my $error = $topicHandler->addRevision( $opts->{file},
                                                $opts->{comment},
                                                $user );

        $this->{session}->{plugins}->afterAttachmentSaveHandler( \%attrs,
                                                    $topic, $web, $error );

        return "attachment save failed: $error" if $error;

        $attrs{name} = $attachment;
        $attrs{version} = $fileVersion;
        $attrs{path} = $opts->{filepath},;
        $attrs{size} = $opts->{filesize};
        $attrs{date} = $opts->{filedate};
        $attrs{attr} = ( $opts->{hide} ) ? "h" : "";

        $meta->put( "FILEATTACHMENT", %attrs );
    } else {
        my %attrs = $meta->findOne( "FILEATTACHMENT", $attachment );
        $attrs{attr} = ( $opts->{hide} ) ? "h" : "";
        $attrs{comment} = $opts->{comment};
        $meta->put( "FILEATTACHMENT", %attrs );
    }

    if( $opts->{createlink} ) {
        $text .= $this->attach()->getAttachmentLink( $web, $topic,
                                                   $attachment, $meta );
    }

    my $error = $this->saveTopic( $user, $web, $topic, $text,
                                  $meta, { unlock => 1 } );

    $this->unlockTopic( $user, $web, $topic );

    unless( $error || $opts->{dontlog} ) {
        $this->{session}->writeLog( $action, "$web.$topic", $attachment );
    }

    return $error;
}

# Save a topic or attachment _without_ invoking plugin handlers.
# Return non-null string if there is an error.
# FIXME: does rev info from meta work if user saves a topic with no change?
sub _noHandlersSave {
    my( $this, $userName, $web, $topic, $text, $meta, $options ) = @_;

    my $topicHandler = $this->_getTopicHandler( $web, $topic );
    my $currentRev = $topicHandler->numRevisions() || 0;

    my $nextRev = $currentRev + 1;

    if( $currentRev && !$options->{forcenewrevision} ) {
        # See if we want to replace the existing top revision
        my $mtime1 = $topicHandler->getTimestamp();
        my $mtime2 = time();

        if( abs( $mtime2 - $mtime1 ) < $TWiki::editLockTime ) {
            my( $date, $user ) =
              $this->getRevisionInfo( $web, $topic, $currentRev,
                               undef, $topicHandler );
            # same user?
            if(  $user eq $userName ) {
                return repRev( @_ );
            }
        }
    }

    $meta->addTOPICINFO( $web, $topic, $nextRev, {} );
    $text = _writeMeta( $meta, $text );

    # RCS requires a newline for the last line,
    $text =~ s/([^\n\r])$/$1\n/os;

    # will block
    $this->lockTopic( $userName, $web, $topic );

    my $error =
      $topicHandler->addRevision( $text, $options->{comment}, $userName );

    $this->unlockTopic( $userName, $web, $topic );

    return $error if( $error );

    if( ! $options->{dontnotify} ) {
        # update .changes
        my( $fdate, $fuser, $frev ) =
          $this->getRevisionInfo( $web, $topic, "", undef, $topicHandler );
        $fdate = ""; # suppress warning
        $fuser = ""; # suppress warning

        my @foo = split( /\n/, $this->readMetaData( $web, "changes" ));
        if( $#foo > 100 ) {
            shift( @foo);
        }
        push( @foo, "$topic\t$userName\t".time()."\t$frev" );
        $this->saveMetaData( $web, "changes", join( "\n", @foo ));
        close(FILE);
    }

    if( ( $TWiki::doLogTopicSave ) && ! ( $options->{dontlog} ) ) {
        # write log entry
        my $extra = "";
        $extra   .= "dontNotify" if( $options->{dontnotify} );
        $this->{session}->writeLog( "save", "$web.$topic", $extra );
    }

    return "";
}

=pod

---++ repRev( $user, $web, $topic, $text, $meta, $options )

Parameters and return value as saveTopic.

Provided as a means for administrators to rewrite history.

Replace last revision, but do not update .changes.
Save topic with same userName and date.

It is up to the store implementation if this is different
to a normal save or not.

=cut

sub repRev {
    my( $this, $userName, $web, $topic, $text, $meta, $options ) = @_;

    $this->lockTopic( $userName, $web, $topic );

    # FIXME why should date be the same if same user replacing with
    # editLockTime?
    my $topicHandler = $this->_getTopicHandler( $web, $topic );
    my( $date, $user, $rev ) =
      $this->getRevisionInfo( $web, $topic, "", undef, $topicHandler );

    # RCS requires a newline for the last line,
    $text =~ s/([^\n\r])$/$1\n/os;

    # Add one minute (make small difference, but not too big for notification)
    # TODO: this seems wrong. if editLockTime == 3600, and i edit, 30 mins
    # later... why would the recorded date be 29 mins too early?
    my $epochSec = $date + 60;
    $meta->addTOPICINFO( $web, $topic, $rev,
                         { forcedate => $epochSec, forceuser => $user } );
    $text = _writeMeta( $meta, $text );

    my $error =
      $topicHandler->replaceRevision( $text, $options->{comment},
                                      $user, $epochSec );
    return $error if( $error );

    $this->unlockTopic( $userName, $web, $topic );

    if( ( $TWiki::doLogTopicSave ) && ! ( $options->{dontlog} ) ) {
        # write log entry
        my $extra = "repRev by $userName: $rev " .
          $this->users()->userToWikiName( $user ) .
              " ". TWiki::formatTime( $epochSec, "rcs", "gmtime" );
        $extra   .= " dontNotify" if( $options->{dontnotify} );
        $this->{session}->writeLog( "save", "$web.$topic", $extra );
    }
    return "";
}

=pod

---++ delRev( $user, $web, $topic, $text, $meta, $options )

Parameters and return value as saveTopic.

Provided as a means for administrators to rewrite history.

Delete last entry in repository, restoring the previous
revision.

It is up to the store implementation whether this actually
does delete a revision or not; some implementations will
simply promote the previous revision up to the head.

=cut

sub delRev {
    my( $this, $userName, $web, $topic ) = @_;

    $this->lockTopic( $userName, $web, $topic );

    my $rev = $this->getRevisionNumber( $web, $topic );
    if( $rev <= 1 ) {
        return "can't delete initial revision";
    }
    my $topicHandler = $this->_getTopicHandler( $web, $topic );
    my $error = $topicHandler->deleteRevision();
    return $error if( $error );

    # restore last topic from repository
    $topicHandler->restoreLatestRevision();

    $this->unlockTopic( $userName, $web, $topic );

    # TODO: delete entry in .changes

    # write log entry
    $this->{session}->writeLog( "cmd", "$web.$topic", "delRev by $userName: $rev" );

    return "";
}

=pod

---++ sub saveFile (  $name, $text  )

Save an arbitrary file

SMELL: Breaks Store encapsulation, if it is used to save topic or
meta-data files.
Therefore this method should _never_ be used for saving topics or
web-specific meta data files, as they may not be stored as text files
in another store implementation. Use =saveTopic*= and =saveMetaData= instead.

=cut

sub saveFile {
    my( $this, $name, $text ) = @_;
    ASSERT(ref($this) eq "TWiki::Store") if DEBUG;

    $name = TWiki::Sandbox::normalizeFileName( $name );

    umask( 002 );
    unless ( open( FILE, ">$name" ) )  {
        warn "Can't create file $name - $!\n";
        return;
    }
    print FILE $text;
    close( FILE);
}

=pod

---++ sub lockTopic( $web, $topic )

Grab a topic lock on the given topic. A topic lock will cause other
processes that also try to claim a lock to block. A lock has a
maximum lifetime of 2 minutes, so operations on a locked topic
must be completed within that time. You cannot rely on the
lock timeout clearing the lock, though; that should always
be done by calling unlockTopic.

=cut

sub lockTopic {
    my ( $this, $locker, $web, $topic ) = @_;
    ASSERT(ref($this) eq "TWiki::Store") if DEBUG;
    ASSERT($locker && $web && $topic) if DEBUG;

    my $topicHandler = $this->_getTopicHandler( $web, $topic );

    while ( 1 ) {
        my ( $user, $time ) = $topicHandler->isLocked();
        last if ( !$user || $user eq $locker );
        TWiki::writeWarning( "Lock on $web.$topic for $locker denied" );
        # see how old the lock is. If it's older than 2 minutes,
        # break it anyway. Locks are atomic, and should never be
        # held that long, by _any_ process.
        if ( time() - $time > 2 * 60 ) {
            $this->{session}->writeWarning
              ( "$locker broke $user's lock on $web.$topic" );
            $topicHandler->setLock( 0 );
            last;
        }
        # wait a couple of seconds before trying again
        sleep(2);
    }

    $topicHandler->setLock( 1, $locker );
}

=pod

---++ sub unlockTopic( $user, $web, $topic )
Release the topic lock on the given topic. A topic lock will cause other
processes that also try to claim a lock to block. It is important to
release a topic lock after a guard section is complete.

=cut

sub unlockTopic {
    my ( $this, $user, $web, $topic ) = @_;

    my $topicHandler = $this->_getTopicHandler( $web, $topic );
    $topicHandler->setLock( 0, $user );
}

=pod

---+++ webExists( $web ) ==> $flag

| Description: | Test if web exists |
| Parameter: =$web= | Web name, required, e.g. ="Sandbox"= |
| Return: =$flag= | ="1"= if web exists, ="0"= if not |

=cut

sub webExists {
    my( $this, $theWeb ) = @_;
    ASSERT(defined($theWeb)) if DEBUG;

    ASSERT(ref($this) eq "TWiki::Store") if DEBUG;
    return -e "$TWiki::dataDir/$theWeb";
}

=pod

---+++ topicExists( $web, $topic ) ==> $flag

| Description: | Test if topic exists |
| Parameter: =$web= | Web name, optional, e.g. ="Main"= |
| Parameter: =$topic= | Topic name, required, e.g. ="TokyoOffice"=, or ="Main.TokyoOffice"= |
| Return: =$flag= | ="1"= if topic exists, ="0"= if not |

=cut

sub topicExists {
    my( $this, $theWeb, $theTopic ) = @_;
    ASSERT(ref($this) eq "TWiki::Store") if DEBUG;
    ASSERT(defined($theTopic)) if DEBUG;

    return -e "$TWiki::dataDir/$theWeb/$theTopic.txt";
}

# PRIVATE parse and add a meta-datum. Returns "" so it can be used in s///e
sub _addMetaDatum {
    #my ( $meta, $type, $args ) = @_;
    $_[0]->put( $_[1], _readKeyValue( $_[2] ));
    return ""; # so it can be used in s///e
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
    ASSERT(ref($this) eq "TWiki::Store") if DEBUG;

    my $meta = new TWiki::Meta( $this->{session}, $web, $topic );
    $$rtext =~ s/^%META:([^{]+){(.*)}%\r?\n/&_addMetaDatum($meta,$1,$2)/gem;

    # If there is no meta data then convert from old format
    if( ! $meta->count( "TOPICINFO" ) ) {
        if ( $$rtext =~ /<!--TWikiAttachment-->/ ) {
            $$rtext = $this->attach()->migrateToFileAttachmentMacro( $meta,
                                                                   $$rtext );
        }

        if ( $$rtext =~ /<!--TWikiCat-->/ ) {
            $$rtext = $this->form()->upgradeCategoryTable( $web, $topic,
                                                         $meta, $$rtext );
        }
    } else {
        my %topicinfo = $meta->findOne( "TOPICINFO" );
        if( $topicinfo{"format"} eq "1.0beta" ) {
            # This format used live at DrKW for a few months
            if( $$rtext =~ /<!--TWikiCat-->/ ) {
                $$rtext = $this->form()->upgradeCategoryTable( $web, $topic,
                                                               $meta,
                                                               $$rtext );
            }
            $this->attach()->upgradeFrom1v0beta( $meta );
            if( $meta->count( "TOPICMOVED" ) ) {
                 my %moved = $meta->findOne( "TOPICMOVED" );
                 $moved{"by"} = $this->users()->wikiToUserName( $moved{"by"} );
                 $meta->put( "TOPICMOVED", %moved );
            }
        }
    }

    return $meta;
}

=pod

---++ sub getTopicParent (  $theWeb, $theTopic  ) -> $meta

Get the name of the topic parent. Needs to be fast because
of use by Render.pm.

=cut

sub getTopicParent {
    my( $this, $theWeb, $theTopic ) = @_;
    ASSERT(ref($this) eq "TWiki::Store") if DEBUG;
    ASSERT(defined($theWeb)) if DEBUG;
    ASSERT(defined($theTopic)) if DEBUG;

    return undef unless $this->topicExists( $theWeb, $theTopic );

    my $topicHandler = $this->_getTopicHandler( $theWeb, $theTopic );
    my $filename = $topicHandler->{file};

    my $data = "";
    my $line;
    $/ = "\n";     # read line by line
    open( IN_FILE, "<$filename" ) || return "";
    while( ( $line = <IN_FILE> ) ) {
        if( $line !~ /^%META:/ ) {
           last;
        } else {
           $data .= $line;
        }
    }
    close( IN_FILE );

    my $meta = $this->extractMetaData( $theWeb, $theTopic, \$data );
    my %parentMeta = $meta->findOne( "TOPICPARENT" );
    return $parentMeta{name} if %parentMeta;
    return undef;
}

=pod

---++ sub getTopicLatestRevTime (  $theWeb, $theTopic  ) -> $epochsecs

Get an approximate rev time for the latest rev of the topic. This method
is used to optimise searching. Needs to be as fast as possible.

=cut

sub getTopicLatestRevTime {
    my ( $this, $web, $topic ) = @_;

    return (stat "$TWiki::dataDir\/$web\/$topic.txt")[9];
}

=pod

---++ readFile( $filename )
Return value: $fileContents

Returns the entire contents of the given file, which can be specified in any
format acceptable to the Perl open() function.

SMELL: Breaks Store encapsulation, if it is used to read topic or meta-data
files. Therefore this method should _never_ be used for reading topics or
web-specific meta data files, as they may not be stored as text files
in another store implementation. Use =readTopic*= and =readMetaData= instead.

=cut

sub readFile {
    my( $this, $name ) = @_;
    ASSERT(ref($this) eq "TWiki::Store") if DEBUG;
    $name = TWiki::Sandbox::normalizeFileName( $name );
    my $data = "";
    undef $/; # set to read to EOF
    open( IN_FILE, "<$name" ) || return "";
    $data = <IN_FILE>;
    $/ = "\n";
    close( IN_FILE );
    $data = "" unless $data; # no undefined
    return $data;
}

=pod

---++ sub readMetaData( $web, $name ) -> $text
Read a named meta-data string. If web is given the meta-data
is stored alongside a web. If the web is not
given, the meta-data is assumed to be globally unique.

=cut

sub readMetaData {
    my ( $this, $web, $name ) = @_;
    ASSERT(ref($this) eq "TWiki::Store") if DEBUG;

    my $file = "$TWiki::dataDir/";
    $file .= "$web/" if $web;
    $file .= ".$name";

    return $this->readFile( $file );
}

=pod

---++ sub saveMetaData( $web, $name ) -> $text
Write a named meta-data string. If web is given the meta-data
is stored alongside a web. If the web is not
given, the meta-data is assumed to be globally unique.

=cut

sub saveMetaData {
    my ( $this, $web, $name, $text ) = @_;
    ASSERT(ref($this) eq "TWiki::Store") if DEBUG;

    my $file = "$TWiki::dataDir/";
    $file .= "$web/" if $web;
    $file .= ".$name";

    return $this->saveFile( $file, $text );
}

=pod

---+++ getTopicNames( $web ) ==> @topics

| Description: | Get list of all topics in a web |
| Parameter: =$web= | Web name, required, e.g. ="Sandbox"= |
| Return: =@topics= | Topic list, e.g. =( "WebChanges",  "WebHome", "WebIndex", "WebNotify" )= |

=cut

sub getTopicNames {
    my( $this, $web ) = @_ ;
    ASSERT(ref($this) eq "TWiki::Store") if DEBUG;

    $web = "" unless( defined $web );

    # get list of all topics by scanning $dataDir
    opendir DIR, "$TWiki::dataDir/$web" ;
    my @topicList = sort grep { s/\.txt$// } readdir( DIR );
    closedir( DIR );
    return @topicList;
}

# Gets a list of sub-webs contained in the given named web. If the
# web is null, it gets a list of all top-level webs. $web may
# be a pathname at any level of the hierarchy; for example, it may be
# Dadweb/Kidweb/Petweb. Includes hidden webs (those starting with
# non-alphanumeric characters).
sub _getSubWebs {
    my( $this, $web ) = @_ ;

    # get list of all subwebs by scanning $dataDir
    opendir DIR, "$TWiki::dataDir/$web" ;
    my @tmpList = readdir( DIR );
    closedir( DIR );

    # this is not magic, it just looks like it.
    my @webList = sort
      grep { !/^\.\.?$/ && -d "$TWiki::dataDir/$web/$_" }
        @tmpList;

    return @webList ;
}

=pod

---++ sub getAllWebs() -> list of web names

Gets a list of webnames, of webs contained within the given
web. Potentially able to expand recursively, but this is
commented out as support is lacking for subwebs almost everywhere
else. If the web parameter is not given or is "", returns the
list of all top-level webs (including hidden webs).

=cut

sub getAllWebs {
    my( $this, $web ) = @_ ;
    ASSERT(ref($this) eq "TWiki::Store") if DEBUG;

    $web = "" unless( defined $web );

    my @webList = $this->_getSubWebs( $web );
    if ( $web ) {
        @webList = map { "$web/$_" } @webList ;
    }

#cc    my $subWeb = "";
#cc    if( $subWebsAllowedP ) {
#cc        my @subWebs = @webList;
#cc        foreach $subWeb ( @webList ) {
#cc            push @subWebs, $this->getAllWebs( $subWeb );
#cc        }
#cc        return @subWebs;
#cc    }
    return @webList;
}

=pod

---++ sub createWeb( $name ) -> $err
Create a new empty web (empty means "with no topic". Returns an error
string if it fails.

=cut

sub createWeb {
    my ( $this, $theWeb ) = @_;

    my $dir = "$TWiki::dataDir/$theWeb";
    umask( 0 );
    unless( mkdir( $dir, 0775 ) ) {
        return "Could not create $dir, error: $!";
    }

    if ( $TWiki::useRcsDir ) {
        unless( mkdir( "$dir/RCS", 0775 ) ) {
            return "Could not create $dir/RCS, error: $!";
        }
    }

    unless( open( FILE, ">$dir/.changes" ) ) {
        return "Could not create changes file $dir/.changes, error: $!";
    }
    print FILE "";  # empty file
    close( FILE );

    unless( open( FILE, ">$dir/.mailnotify" ) ) {
        return "Could not create mailnotify timestamp file $dir/.mailnotify, error: $!";
    }
    print FILE "";
    close( FILE );
    return undef;
}

# STATIC Write a meta-data key=value pair
# The encoding is reversed in _readKeyValue
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
        $value = "";
    }

    return "$key=\"$value\"";
}

# Write all the key=value pairs for the types listed
sub _writeTypes {
    my( $meta, @types ) = @_;
    ASSERT(ref($meta) eq "TWiki::Meta") if DEBUG;

    my $text = "";

    if( $types[0] eq "not" ) {
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
            my $sep = "";
            $text .= "%META:$type\{";
            my $name = $item->{"name"};
            if( $name ) {
                # If there's a name field, put first to make regexp based searching easier
                $text .= _writeKeyValue( "name", $item->{"name"} );
                $sep = " ";
            }
            foreach my $key ( sort keys %$item ) {
                if( $key ne "name" ) {
                    $text .= $sep;
                    $text .= _writeKeyValue( $key, $item->{$key} );
                    $sep = " ";
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
    ASSERT(ref($meta) eq "TWiki::Meta") if DEBUG;

    my $start = _writeStart( $meta );
    my $end = _writeEnd( $meta );
    $text = $start . "$text";
    $text =~ s/([^\n\r])$/$1\n/;     # new line is required at end
    $text .= $end;

    return $text;
}

=pod

---++ sub getDebugText($meta, $text) -> $text
Generate a debug text form of the text/meta, for use in debug displays,
by annotating the text with meta informtion.

=cut

sub getDebugText {
    my ( $this, $meta, $text ) = @_;
    ASSERT(ref($this) eq "TWiki::Store") if DEBUG;

    return _writeMeta( $meta, $text );
}

=pod

---++ sub cleanUpRevID( $rev )
Cleans up (maps) a user-supplied revision ID and converts it to an integer
number that can be incremented to create a new revision number.

This method should be used to sanitise user-provided revision IDs.

=cut

sub cleanUpRevID {
    my ( $this, $rev ) = @_;
    ASSERT(ref($this) eq "TWiki::Store") if DEBUG;

    return 0 unless $rev;

    $rev =~ s/^r//i;
    $rev =~ s/^\d+\.//; # clean up RCS rev number

    return $rev;
}

=pod

---++ sub copyTopicBetweenWebs($fromWeb, $topic, $toWeb)
Copy a topic and all it's attendant data from one web to another.
Returns an error string if it fails.

=cut

sub copyTopicBetweenWebs {
    my ( $this, $theFromWeb, $theTopic, $theToWeb ) = @_;
    ASSERT(ref($this) eq "TWiki::Store") if DEBUG;

    # copy topic file
    my $from = "$TWiki::dataDir/$theFromWeb/$theTopic.txt";
    my $to = "$TWiki::dataDir/$theToWeb/$theTopic.txt";
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

    return "";
}

=pod

---++ sub searchMetaData($params)
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

    my $attrType = $params->{type} || "FIELD";

    my $searchVal = "XXX";

    my $attrWeb = $params->{web} || "";
    my $searchWeb = $attrWeb || "all";

    if ( $attrType eq "parent" ) {
        my $attrTopic = $params->{topic} || "";
        $searchVal = "%META:TOPICPARENT[{].*name=\\\"($attrWeb\\.)?$attrTopic\\\".*[}]%";
   } elsif ( $attrType eq "topicmoved" ) {
        my $attrTopic = $params->{topic} || "";
        $searchVal = "%META:TOPICMOVED[{].*from=\\\"$attrWeb\.$attrTopic\\\".*[}]%";
    } else {
        $searchVal = "%META:".uc( $attrType )."[{].*";
        $searchVal .= "name=\\\"$params->{name}\\\".*"
          if (defined $params->{name});
        $searchVal .= "value=\\\"$params->{value}\\\".*"
          if (defined $params->{value});
        $searchVal .= "[}]%";
    }

    my $text = "";
    $this->search()->searchWeb
      (
       _callback     => \&_collate,
       _cbdata       => \$text,,
       search        => $searchVal,
       web           => $searchWeb,
       type          => "regex",
       nosummary     => "on",
       nosearch      => "on",
       noheader      => "on",
       nototal       => "on",
       noempty       => "on",
       template      => "searchmeta",
       inline        => 1,
      );

    my $attrTitle = $params->{title} || "";
    if( $text ) {
        $text = "$attrTitle$text";
    } else {
        my $attrDefault = $params->{default} || "";
        $text = "$attrTitle$attrDefault";
    }

    return $text;
}

# callback for search function to collate
# results
sub _collate {
    my $ref = shift;

    $$ref .= join( " ", @_ );
}

=pod

---+ sub searchInWebContent

Search for a token in the content of a web. The search must be over all
content and all formatted meta-data, though the latter search type is
deprecated (use searchMetaData instead).
| $web | The web to search in |
| $type | "regex" or something else |
| $searchString | the search string, in egrep format |
| $topics | reference to a list of topics to search |

The return value is a reference to a hash which maps each matching topic
name to a list of the lines in that topic that matched the search,
as would be returned by 'grep'. If $justTopics is specified, it will
return on the first match in each topic (i.e. it will return only one
match per topic, and will not return matching lines).

=cut

sub searchInWebContent {
    my( $this, $web, $type, $caseSensitive, $justTopics, $searchString, $topics ) = @_;

    # I18N: 'grep' must use locales if needed,
    # for case-insensitive searching.  See TWiki::setupLocale.
    my $program = "";
    # FIXME: For Cygwin grep, do something about -E and -F switches
    # - best to strip off any switches after first space in
    # $egrepCmd etc and apply those as argument 1.
    if( $type eq "regex" ) {
        # SMELL: this should be specific to the store implementation
        $program = $TWiki::egrepCmd;
    } else {
        # SMELL: this should be specific to the store implementation
        $program = $TWiki::fgrepCmd;
    }

    my $args = '';
    $args .= ' -i' unless $caseSensitive;
    $args .= ' -l' if $justTopics;
    $args .= ' -- %TOKEN|U% %FILES|F%';

    my $sDir = "$TWiki::dataDir/$web/";
    my $seen = {};
    # process topics in sets, fix for Codev.ArgumentListIsTooLongForSearch
    my $maxTopicsInSet = 512; # max number of topics for a grep call
    my @take = @$topics;
    my @set = splice( @take, 0, $maxTopicsInSet );
    while( @set ) {
        @set = map { "$sDir/$_.txt" } @set;
        @set =
          $this->sandbox()->readFromProcessArray ($program, $args,
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

1;

