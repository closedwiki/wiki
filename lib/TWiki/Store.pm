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
#
# 20000917 - NicholasLee : Split file/storage related functions from wiki.pm
# 200105   - JohnTalintyre : AttachmentsUnderRevisionControl & meta data in topics
# 200106   - JohnTalintyre : Added Form capability (replaces Category tables)
# 200401   - RafaelAlvarez : Added a new Plugin callback (afterSaveHandler)
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

use strict;

# 'Use locale' for internationalisation of Perl sorting in getTopicNames
# and other routines - main locale settings are done in TWiki::setupLocale
BEGIN {
    # Do a dynamic 'use locale' for this module
    if( $TWiki::useLocale ) {
        eval 'require locale; import locale ();';
    }
}

# ===========================
=pod

---++ sub initialize ()

Initialise the Store module, linking in the chosen implementation.

=cut

sub initialize
{
    eval "use TWiki::Store::$TWiki::storeTopicImpl;";
}

# PRIVATE sub _getTopicHandler (  $web, $topic, $attachment  )
# Get the handler for the current store implementation, either RcsFile
# or RcsLite
sub _getTopicHandler
{
   my( $web, $topic, $attachment ) = @_;

   $attachment = "" if( ! $attachment );

   my $handlerName = "TWiki::Store::$TWiki::storeTopicImpl";

   my $handler = $handlerName->new( $web, $topic, $attachment, @TWiki::storeSettings );
   return $handler;
}

=pod

---++ sub moveAttachment (  $oldWeb, $oldTopic, $newWeb, $newTopic, $theAttachment, $user  )

Move an attachment from one topic to another.

If there is a problem an error string is returned.

The caller to this routine should check that all topics are valid.

=cut

sub moveAttachment
{
    my( $oldWeb, $oldTopic, $newWeb, $newTopic, $theAttachment, $user ) = @_;

    # Remove file attachment from old topic
    my $topicHandler = _getTopicHandler( $oldWeb, $oldTopic, $theAttachment );
    my $error = $topicHandler->moveMe( $newWeb, $newTopic );

    return $error if( $error );

    my( $meta, $text ) = readTopic( $oldWeb, $oldTopic );
    my %fileAttachment =
      $meta->findOne( "FILEATTACHMENT", $theAttachment );
    $meta->remove( "FILEATTACHMENT", $theAttachment );
    $error .=
      TWiki::Store::noHandlersSave( $oldWeb, $oldTopic, $text, $meta,
                                    "", "", "", "doUnlock",
                                    "dont notify", "" );
    # Remove lock
    lockTopic( $oldWeb, $oldTopic, 1 );

    return $error if( $error );

    # Add file attachment to new topic
    ( $meta, $text ) = readTopic( $newWeb, $newTopic );
    $fileAttachment{"movefrom"} = "$oldWeb.$oldTopic";
    $fileAttachment{"moveby"}   = $user;
    $fileAttachment{"movedto"}  = "$newWeb.$newTopic";
    $fileAttachment{"movedwhen"} = time();
    $meta->put( "FILEATTACHMENT", %fileAttachment );

    $error .=
      TWiki::Store::noHandlersSave( $newWeb, $newTopic, $text, $meta,
                                          "", "", "", "doUnlock",
                                          "dont notify", "" );
    # Remove lock file.
    lockTopic( $newWeb, $newTopic, 1 );

    return $error if( $error );

    TWiki::writeLog( "move", "$oldWeb.$oldTopic",
                     "Attachment $theAttachment moved to $newWeb.$newTopic" );

    return $error;
}

=pod

---++ sub getAttachmentStream( $web, $topic, $attName )
| =$web= | The web |
| =$topic= | The topic |
| =$attName= | Name of the attachment |
Open a standard input stream from an attachment. Will return undef
if the stream could not be opened (permissions, or nonexistant etc)

=cut

sub getAttachmentStream {
    #my ( $web, $topic, $att ) = @_;
    my $topicHandler = _getTopicHandler( @_ );
    my $strm;
    my $fp = $topicHandler->{file};
    if ( $fp ) {
        unless ( open( $strm, "<$fp" )) {
            TWiki::writeWarning( "File $fp open failed: error $!" );
        }
    }
    return $strm;
}

=pod

---++ sub attachmentExists( $web, $topic, $att ) -> boolean

Determine if the attachment already exists on the given topic

=cut

sub attachmentExists {
    #my ( $web, $topic, $att ) = @_;
    my $topicHandler = _getTopicHandler( @_ );
    return -e $topicHandler->{file};
}

# PRIVATE sub _changeRefTo (  $text, $oldWeb, $oldTopic  )
# 
# When moving a topic to another web, change within-web refs from
# this topic so that they'll work when the topic is in the new web.
# I have a feeling this shouldn't be in Store.pm.
#
# SMELL: It has to be - it knows about %META in topics. If you can
# eliminate that dependency, then it could move somewhere else.
sub _changeRefTo
{
   my( $text, $oldWeb, $oldTopic ) = @_;

   my $preTopic = '^|[\*\s\[][-\(\s]*';
   # I18N: match non-alpha before/after topic names
   my $alphaNum = $TWiki::regex{mixedAlphaNum};
   my $postTopic = '$|' . "[^${alphaNum}_.]" . '|\.\s';
   my $metaPreTopic = '"|[\s[,\(-]';
   my $metaPostTopic = "[^${alphaNum}_.]" . '|\.\s';
   
   my $out = "";
   
   # Get list of topics in $oldWeb, replace local refs to these topics with full web.topic
   # references
   my @topics = getTopicNames( $oldWeb );
   
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

---++ sub renameTopic (  $oldWeb, $oldTopic, $newWeb, $newTopic, $doChangeRefTo  )

Rename a topic, allowing for transfer between Webs. This method will change
all references _from_ this topic to other topics _within the old web_
so they still work after it has been moved to a new web.

It is the responsibility of the caller to check for existence of webs,
topics & lock taken for topic

=cut

sub renameTopic
{
   my( $oldWeb, $oldTopic, $newWeb, $newTopic, $doChangeRefTo ) = @_;
   
   my $topicHandler = _getTopicHandler( $oldWeb, $oldTopic, "" );
   my $error = $topicHandler->moveMe( $newWeb, $newTopic );

   if( ! $error ) {
      my $time = time();
      my $user = $TWiki::userName;
      my @args = (
         "from" => "$oldWeb.$oldTopic",
         "to"   => "$newWeb.$newTopic",
         "date" => "$time",
         "by"   => "$user" );
      my $text = readTopicRaw( $newWeb, $newTopic );
      if( ( $oldWeb ne $newWeb ) && $doChangeRefTo ) {
         $text = _changeRefTo( $text, $oldWeb, $oldTopic );
      }
      my $meta = _extractMetaData( $newWeb, $newTopic, $text );
      $meta->put( "TOPICMOVED", @args );
      noHandlersSave( $newWeb, $newTopic, $text, $meta, "", "", "", "unlock" );
   }
   
   # Log rename
   if( $TWiki::doLogRename ) {
      TWiki::writeLog( "rename", "$oldWeb.$oldTopic", "moved to $newWeb.$newTopic $error" );
   }
   
   # Remove old lock file
   $topicHandler->setLock( "" );
   
   return $error;
}


=pod

---++ sub updateReferringPages (  $oldWeb, $oldTopic, $wikiUserName, $newWeb, $newTopic, @refs  )

Update pages that refer to a page that is being renamed/moved.

=cut

sub updateReferringPages
{
    my ( $oldWeb, $oldTopic, $wikiUserName, $newWeb, $newTopic, @refs ) = @_;

    my $lockFailure = 0;

    my $result = "";
    my $preTopic = '^|\W';		# Start of line or non-alphanumeric
    my $postTopic = '$|\W';	# End of line or non-alphanumeric
    my $spacedTopic = TWiki::searchableTopic( $oldTopic );

    while ( @refs ) {
       my $type = shift @refs;
       my $item = shift @refs;
       my( $itemWeb, $itemTopic ) = TWiki::normalizeWebTopicName( "", $item );
       if ( TWiki::Store::topicIsLockedBy( $itemWeb, $itemTopic ) ) {
          $lockFailure = 1;
       } else {
          my $resultText = "";
          $result .= ":$item: , "; 
          #open each file, replace $topic with $newTopic
          if ( TWiki::Store::topicExists($itemWeb, $itemTopic) ) { 
             my $scantext = TWiki::Store::readTopicRaw($itemWeb, $itemTopic);
             if( ! TWiki::Access::checkAccessPermission( "change", $wikiUserName, $scantext,
                    $itemWeb, $itemTopic ) ) {
                 # This shouldn't happen, as search will not return, but check to be on the safe side
                 TWiki::writeWarning( "rename: attempt to change $itemWeb.$itemTopic without permission" );
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
	     my $meta = _extractMetaData( $itemWeb, $itemTopic, $resultText );
         saveTopic( $itemWeb, $itemTopic, $resultText, $meta, "", "unlock", "dontNotify", "" );
          } else {
	    $result .= ";$item does not exist;";
          }
       }
    }
    return ( $lockFailure, $result );
}


=pod

---++ sub readTopicVersion (  $theWeb, $theTopic, $theRev  )

Read a specific version of a topic
<pre>view:     $text= TWiki::Store::readTopicVersion( $topic, "1.$rev" );</pre>

=cut

sub readTopicVersion
{
    my( $theWeb, $theTopic, $theRev ) = @_;
    my $text = _readVersionNoMeta( $theWeb, $theTopic, $theRev );
    my $meta = _extractMetaData( $theWeb, $theTopic, $text );
    return( $meta, $text );
}

# Read a specific version of a topic

sub _readVersionNoMeta
{
    my( $theWeb, $theTopic, $theRev ) = @_;
    my $topicHandler = _getTopicHandler( $theWeb, $theTopic );
    
    $theRev =~ s/^1\.//o;
    return $topicHandler->getRevision( $theRev );
}

=pod

---++ sub readAttachmentVersion (  $theWeb, $theTopic, $theAttachment, $theRev  )

Read the given version of an attachment, returning the content.

=cut

sub readAttachmentVersion
{
   my ( $theWeb, $theTopic, $theAttachment, $theRev ) = @_;
   
   my $topicHandler = _getTopicHandler( $theWeb, $theTopic, $theAttachment );
   $theRev =~ s/^1\.//o;
   return $topicHandler->getRevision( $theRev );
}

=pod

---++ sub getRevisionNumber (  $theWebName, $theTopic, $attachment  )

Get the revision number of the most recent revision.

WORKS FOR ATTACHMENTS AS WELL AS TOPICS

=cut

sub getRevisionNumber
{
    my( $theWebName, $theTopic, $attachment ) = @_;
    my $ret = _getMostRecentRevision( $theWebName, $theTopic, $attachment );
    ##TWiki::writeDebug( "Store: rev = $ret" );
    if( ! $ret ) {
       $ret = "1.1"; # Temporary
    }
    
    return $ret;
}

# PRIVATE sub _getMostRecentRevision (  $theWebName, $theTopic, $attachment  )
#
# Latest revision number. <br/>
# Returns "" if there is no revision.
#
# WORKS FOR ATTACHMENTS AS WELL AS TOPICS
sub _getMostRecentRevision {
    my( $theWebName, $theTopic, $attachment ) = @_;
    if( ! $theWebName ) {
        $theWebName = $TWiki::webName;
    }
    if( ! $attachment ) {
        $attachment = "";
    }

    my $topicHandler = _getTopicHandler( $theWebName, $theTopic, $attachment );
    my $revs = $topicHandler->numRevisions();
    $revs = "1.$revs" if( $revs );
    return $revs;
}


=pod

---++ sub getRevisionDiff (  $web, $topic, $rev1, $rev2, $contextLines  )

<pre>
rdiff:            $diffArray = TWiki::Store::getRevisionDiff( $webName, $topic, "1.$r2", "1.$r1", 3 );
</pre>
| Return: =\@diffArray= | reference to an array of [ diffType, $right, $left ] |

=cut

sub getRevisionDiff
{
    my( $web, $topic, $rev1, $rev2, $contextLines ) = @_;

    my $rcs = _getTopicHandler( $web, $topic );
    my $r1 = substr( $rev1, 2 );
    my $r2 = substr( $rev2, 2 );
    my( $error, $diffArrayRef ) = $rcs->revisionDiff( $r1, $r2, $contextLines );
    return $diffArrayRef;
}


# =========================
# FIXME try and get rid of this it's a mess
# In direct calls changeToIsoDate always seems to be 1

=pod

---+++ getRevisionInfo($theWebName, $theTopic, $theRev, $attachment, $topicHandler) ==> ( $date, $user, $rev, $comment ) 
| Description: | Get revision info of a topic |
| Parameter: =$theWebName= | Web name, optional, e.g. ="Main"= |
| Parameter: =$theTopic= | Topic name, required, e.g. ="TokyoOffice"= |
| Parameter: =$theRev= | revsion number, or tag name (can be in the format 1.2, or just the minor number) |
| Parameter: =$attachment= |attachment filename |
| Parameter: =$topicHandler= | internal store use only |
| Return: =( $date, $user, $rev, $comment )= | List with: ( last update date, login name of last user, minor part of top revision number ), e.g. =( 1234561, "phoeny", "5" )= |
| $date | in epochSec |
| $user | |
| $rev | TODO: this needs to be improves to contain the major number too (and what do we do is we have a different numbering system?) |
| $comment | WHAT COMMENT? |

=cut

sub getRevisionInfo
{
    my( $theWebName, $theTopic, $theRev, $attachment, $topicHandler ) = @_;
    if( ! $theWebName ) {
        $theWebName = $TWiki::webName;
    }

    $theRev = "" unless( $theRev );
    $theRev =~ s/^1\.//o;

    $topicHandler = _getTopicHandler( $theWebName, $theTopic, $attachment ) if( ! $topicHandler );
    my( $rcsOut, $rev, $date, $user, $comment ) = $topicHandler->getRevisionInfo( $theRev );
    
    return ( $date, $user, $rev, $comment );
}


=pod

---++ sub topicIsLockedBy (  $theWeb, $theTopic  )

| returns  ( $lockUser, $lockTime ) | ( "", 0 ) if not locked |

=cut

sub topicIsLockedBy
{
    my( $theWeb, $theTopic ) = @_;

    # pragmatic approach: Warn user if somebody else pressed the
    # edit link within a time limit e.g. 1 hour

    ( $theWeb, $theTopic ) = TWiki::normalizeWebTopicName( $theWeb, $theTopic );

    my $lockFilename = "$TWiki::dataDir/$theWeb/$theTopic.lock";
    if( ( -e "$lockFilename" ) && ( $TWiki::editLockTime > 0 ) ) {
        my $tmp = readFile( $lockFilename );
        my( $lockUser, $lockTime ) = split( /\n/, $tmp );
        if( $lockUser ne $TWiki::userName ) {
            # time stamp of lock within editLockTime of current time?
            my $systemTime = time();
            # calculate remaining lock time in seconds
            $lockTime = $lockTime + $TWiki::editLockTime - $systemTime;
            if( $lockTime > 0 ) {
                # must warn user that it is locked
                return( $lockUser, $lockTime );
            }
        }
    }
    return( "", 0 );
}

# ======================
# Build a hash by parsing name=value comma separated pairs

sub _keyValue2Hash
{
    my( $args ) = @_;
    
    my %res = ();
    
    # Format of data is name="value" name1="value1" [...]
    while( $args =~ s/\s*([^=]+)=\"([^"]*)\"//o ) {
        my $key = $1;
        my $value = $2;
        $value = TWiki::Meta::restoreValue( $value );
        $res{$key} = $value;
    }
    
    return %res;
}


# =pod
# 
# ---++ sub saveTopicNew (  $web, $topic, $text, $metaData, $saveCmd, $doUnlock, $dontNotify, $dontLogSave  )
# 
# Never called.
# 
# =cut
# 
# sub saveTopicNew
# {
#     my( $web, $topic, $text, $metaData, $saveCmd, $doUnlock, $dontNotify, $dontLogSave ) = @_;
#     my $attachment = "";
#     my $meta = TWiki::Meta->new();
#     $meta->readArray( @$metaData );
#     noHandlersSave( $web, $topic, $text, $meta, $saveCmd, $attachment, $dontLogSave, $doUnlock, $dontNotify );
# }

=pod

---++ sub saveTopic (  $web, $topic, $text, $meta, $saveCmd, $doUnlock, $dontNotify, $dontLogSave, $forceDate  )
| =$web= | |
| =$topic= | |
| =$text= | |
| =$meta= | |
| =$saveCmd= | |
| =$doUnlock= | |
| =$dontNotify= | |
| =$dontLogSave= | |
| =$forceDate= | |

Save a new revision of the topic, calling plugins handlers as appropriate.

=cut

sub saveTopic
{
    my( $web, $topic, $text, $meta, $saveCmd, $doUnlock, $dontNotify, $dontLogSave, $forceDate ) = @_;
    my $attachment = "";
    my $comment = "";

    # SMELL: Staggeringly inefficient code that adds meta-data for
    # Plugin callback. Why not simply pass the meta in? It would be far
    # more sensible.
    $text = _writeMeta( $meta, $text );  # add meta data for Plugin callback
    TWiki::Plugins::beforeSaveHandler( $text, $topic, $web );
    # remove meta data again!
    $meta = _extractMetaData( $web, $topic, $text );

    my $error = noHandlersSave( $web, $topic, $text, $meta, $saveCmd,
                                $attachment, $dontLogSave, $doUnlock,
                                $dontNotify, $comment, $forceDate );
    $text = _writeMeta( $meta, $text );  # add meta data for Plugin callback
    TWiki::Plugins::afterSaveHandler( $text, $topic, $web, $error );
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

sub saveAttachment
{
    my( $web, $topic, $attachment, $user, $opts ) = @_;
    my $action;

    lockTopic( $web, $topic, 0 );

    # update topic
    my( $meta, $text ) = TWiki::Store::readTopic( $web, $topic );

    if ( $opts->{file} ) {
        my $fileVersion = TWiki::Store::getRevisionNumber( $web, $topic,
                                                           $attachment );
        $action = "upload";

        my %attrs =
          (
           attachment => $attachment,
           tmpFilename => $opts->{file},
           comment => $opts->{comment},
           user => $user
          );

        my $topicHandler = _getTopicHandler( $web, $topic, $attachment );
        TWiki::Plugins::beforeAttachmentSaveHandler( \%attrs,
                                                     $topic, $web );

        my $error = $topicHandler->addRevision( $opts->{file},
                                                $opts->{comment},
                                                $user );

        TWiki::Plugins::afterAttachmentSaveHandler( \%attrs,
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
        $text .= TWiki::Attach::getAttachmentLink( $web, $topic,
                                                   $attachment, $meta );
    }

    my $error = TWiki::Store::saveTopic( $web, $topic, $text,
                                         $meta, "", 1 );

    lockTopic( $web, $topic, 1 );
    unless( $error || $opts->{dontlog} ) {
        TWiki::writeLog( $action, "$web.$topic", $attachment );
    }

    return $error;
}


# PRIVATE sub _addMeta (  $web, $topic, $text, $attachment, $nextRev, $meta, $forceDate, $forceUser  )
#
# Add meta data to the topic.
sub _addMeta
{
    my( $web, $topic, $text, $attachment, $nextRev, $meta, $forceDate, $forceUser ) = @_;

    if( ! $attachment ) {
        $nextRev = "1.1" if( ! $nextRev );
        $meta->addTopicInfo(  $web, $topic, $nextRev, $forceDate, $forceUser );
        $text = _writeMeta( $meta, $text );
    }

    return $text;
}

=pod

---++ sub noHandlersSave (  $web, $topic, $text, $meta, $saveCmd, $attachment, $dontLogSave, $doUnlock, $dontNotify, $theComment, $forceDate  )
| =$web= | |
| =$topic= | |
| =$text= | |
| =$meta= | |
| =$saveCmd= | |
| =$attachment= | |
| =$dontLogSave= | |
| =$doUnlock= | |
| =$dontNotify= | |
| =$theComment= | |
| =$forceDate= | |

Save a topic or attachment _without_ invoking plugin handlers.

Return non-null string if there is an (RCS) error.

FIXME: does rev info from meta work if user saves a topic with no change?

=cut

sub noHandlersSave
{
    my( $web, $topic, $text, $meta, $saveCmd, $attachment, $dontLogSave, $doUnlock, $dontNotify, $theComment, $forceDate ) = @_;
    my $time = time();
    my $tmp = "";
    my $rcsError = "";
    my $dataError = "";
    
    my $topicHandler = _getTopicHandler( $web, $topic, $attachment );

    my $currentRev = $topicHandler->numRevisions();
    
    my $nextRev    = "";
    if( ! $currentRev ) {
        $nextRev = "1.1";
    } else {
        $nextRev = "1." . ($currentRev + 1);
    }
    $currentRev = "1." . $currentRev if( $currentRev );

    if( ! $attachment ) {
        # RCS requires a newline for the last line,
        # so add newline if needed
        $text =~ s/([^\n\r])$/$1\n/os;
    }

    if( ! $theComment ) {
       $theComment = "none";
    }

    #### Normal Save
    if( ! $saveCmd ) {
        $saveCmd = "";

        # get time stamp of existing file
        my $mtime1 = $topicHandler->getTimestamp();
        my $mtime2 = time();

        # how close time stamp of existing file to now?
        if( abs( $mtime2 - $mtime1 ) < $TWiki::editLockTime ) {
            # FIXME no previous topic?
            my( $date, $user ) = getRevisionInfo( $web, $topic, $currentRev, $attachment, $topicHandler );
            # TWiki::writeDebug( "Store::save date = $date" );
            # same user?
            if( ( $TWiki::doKeepRevIfEditLock ) && ( $user eq $TWiki::userName ) && $currentRev ) { # TODO shouldn't this also check to see if its still locked?
                # replace last repository entry
                $saveCmd = "repRev";
                if( $attachment ) {
                   $saveCmd = ""; # cmd option not supported for attachments.
                }
            }
        }

        if( $saveCmd ne "repRev" ) {
            $text = _addMeta( $web, $topic, $text, $attachment, $nextRev, $meta, $forceDate );

            $dataError = $topicHandler->addRevision( $text, $theComment, $TWiki::userName );
            return $dataError if( $dataError );

            $topicHandler->setLock( ! $doUnlock );

            if( ! $dontNotify ) {
                # update .changes
                my( $fdate, $fuser, $frev ) = getRevisionInfo( $web, $topic, "", $attachment, $topicHandler );
                $fdate = ""; # suppress warning
                $fuser = ""; # suppress warning

                my @foo = split( /\n/, readFile( "$TWiki::dataDir/$TWiki::webName/.changes" ) );
                if( $#foo > 100 ) {
                    shift( @foo);
                }
                push( @foo, "$topic\t$TWiki::userName\t$time\t$frev" );
                open( FILE, ">$TWiki::dataDir/$web/.changes" );
                print FILE join( "\n", @foo )."\n";
                close(FILE);
            }

            if( ( $TWiki::doLogTopicSave ) && ! ( $dontLogSave ) ) {
                # write log entry
                my $extra = "";
                $extra   .= "dontNotify" if( $dontNotify );
                TWiki::writeLog( "save", "$web.$topic", $extra );
            }
        }
    }

    #### Replace Revision Save
    if( $saveCmd eq "repRev" ) {
        # fix topic by replacing last revision, but do not update .changes

        # save topic with same userName and date
        # FIXME why should date be the same if same user replacing with editLockTime?
        my( $date, $user, $rev ) = getRevisionInfo( $web, $topic, "", $attachment, $topicHandler );
        $rev = "1.$rev";

        # Add one minute (make small difference, but not too big for notification)
        my $epochSec = $date + 60; #TODO: this seems wrong. if editLockTime == 3600, and i edit, 30 mins later... why would the recorded date be 29 mins too early?
        $text = _addMeta( $web, $topic, $text, $attachment, $rev,
                          $meta, $epochSec, $user );

        my $dataError = $topicHandler->replaceRevision( $text, $theComment, $user, $epochSec );
        return $dataError if( $dataError );
        $topicHandler->setLock( ! $doUnlock );

        if( ( $TWiki::doLogTopicSave ) && ! ( $dontLogSave ) ) {
            # write log entry
            my $extra = "repRev $rev ";
            $extra   .= TWiki::User::userToWikiName( $user );
            $date = TWiki::formatTime( $epochSec, "rcs", "gmtime" );
            $extra   .= " $date";
            $extra   .= " dontNotify" if( $dontNotify );
            TWiki::writeLog( "save", "$web.$topic", $extra );
        }
    }

    #### Delete Revision
    if( $saveCmd eq "delRev" ) {
        # delete last revision

        # delete last entry in repository (unlock, delete revision, lock operation)
        my $rev = getRevisionNumber( $web, $topic );
        if( $rev eq "1.1" ) {
            # can't delete initial revision
            return;
        }
        my $dataError = $topicHandler->deleteRevision();
        return $dataError if( $dataError );

        # restore last topic from repository
        $topicHandler->restoreLatestRevision();
        $topicHandler->setLock( ! $doUnlock );

        # delete entry in .changes : FIXME

        if( $TWiki::doLogTopicSave ) {
            # write log entry
            TWiki::writeLog( "cmd", "$web.$topic", "delRev $rev" );
        }
    }
    return ""; # all is well
}

=pod

---++ sub saveFile (  $name, $text  )

Save an arbitrary file

SMELL: Breaks Store encapsulation.

=cut

sub saveFile
{
    my( $name, $text ) = @_;
    
    umask( 002 );
    unless ( open( FILE, ">$name" ) )  {
	warn "Can't create file $name - $!\n";
	return;
    }
    print FILE $text;
    close( FILE);
}

=pod

---++ sub lockTopic (  $theWeb, $theTopic, $doUnlock  )

Get a lock on the given topic.

=cut

sub lockTopic
{
    my( $theWeb, $theTopic, $doUnlock ) = @_;

    ( $theWeb, $theTopic ) = TWiki::normalizeWebTopicName( $theWeb, $theTopic );
    
    my $topicHandler = _getTopicHandler( $theWeb, $theTopic );
    $topicHandler->setLock( ! $doUnlock );
}

=pod

---++ sub removeObsoleteTopicLocks (  $web  )

Clean all obsolete .lock files in a web.
This should be called regularly, best from a cron job
(called from mailnotify). Only required for file database
implementations of Store.

=cut

sub removeObsoleteTopicLocks
{
    my( $web ) = @_;

    my $webDir = "$TWiki::dataDir/$web";
    opendir( DIR, "$webDir" );
    my @fileList = grep /\.lock$/, readdir DIR;
    closedir DIR;
    my $file = "";
    my $pathFile = "";
    my $lockUser = "";
    my $lockTime = 0;
    my $systemTime = time();
    foreach $file ( @fileList ) {
        $pathFile = "$webDir/$file";
        $pathFile =~ /(.*)/;
        $pathFile = $1;       # untaint file
        ( $lockUser, $lockTime ) = split( /\n/, readFile( "$pathFile" ) );
        $lockTime = 0 unless( $lockTime );

        # time stamp of lock over one hour of current time?
        if( abs( $systemTime - $lockTime ) > $TWiki::editLockTime ) {
            # obsolete, so delete file
            unlink "$pathFile";
        }
    }
}

=pod

---++ Functions: Content Handling

---+++ webExists( $web ) ==> $flag

| Description: | Test if web exists |
| Parameter: =$web= | Web name, required, e.g. ="Sandbox"= |
| Return: =$flag= | ="1"= if web exists, ="0"= if not |

=cut

sub webExists
{
    my( $theWeb ) = @_;
    return -e "$TWiki::dataDir/$theWeb";
}

=pod

---+++ topicExists( $web, $topic ) ==> $flag

| Description: | Test if topic exists |
| Parameter: =$web= | Web name, optional, e.g. ="Main"= |
| Parameter: =$topic= | Topic name, required, e.g. ="TokyoOffice"=, or ="Main.TokyoOffice"= |
| Return: =$flag= | ="1"= if topic exists, ="0"= if not |

=cut

sub topicExists
{
    my( $theWeb, $theTopic ) = @_;
    ( $theWeb, $theTopic ) = TWiki::normalizeWebTopicName( $theWeb, $theTopic );
    return -e "$TWiki::dataDir/$theWeb/$theTopic.txt";
}

# PRIVATE parse and add a meta-datum. Returns "" so it can be used in s///e
sub _addMetaDatum {
    #my ( $meta, $type, $args ) = @_;
    $_[0]->put( $_[1], _keyValue2Hash( $_[2] ));
    return ""; # so it can be used in s///e
}

# Expect meta data at top of file, but willing to accept it anywhere.
# If we have an old file format without meta data, then convert.
#
# *WARNING: SIDE-EFFECTING FUNCTION* meta-data is stripped from the $text
sub _extractMetaData
{
    #my( $web, $topic, $text ) = @_;

    my $meta = TWiki::Meta->new( $_[0], $_[1] );
    $_[2] =~ s/^%META:([^{]+){(.*)}%\r?\n/&_addMetaDatum($meta,$1,$2)/gem;

    # If there is no meta data then convert from old format
    if( ! $meta->count( "TOPICINFO" ) ) {
        if ( $_[2] =~ /<!--TWikiAttachment-->/ ) {
            $_[2] = TWiki::Attach::migrateToFileAttachmentMacro( $meta,
                                                                 $_[2] );
        }

        if ( $_[2] =~ /<!--TWikiCat-->/ ) {
            $_[2] = TWiki::Form::upgradeCategoryTable( $_[0], $_[1],
                                                       $meta, $_[2] );
        }
    } else {
        my %topicinfo = $meta->findOne( "TOPICINFO" );
        if( $topicinfo{"format"} eq "1.0beta" ) {
            # This format used live at DrKW for a few months
            if( $_[2] =~ /<!--TWikiCat-->/ ) {
               $_[2] = TWiki::Form::upgradeCategoryTable( $_[0],
                                                          $_[1],
                                                          $meta,
                                                          $_[2] );
            }
            TWiki::Attach::upgradeFrom1v0beta( $meta );
            if( $meta->count( "TOPICMOVED" ) ) {
                 my %moved = $meta->findOne( "TOPICMOVED" );
                 $moved{"by"} = TWiki::User::wikiToUserName( $moved{"by"} );
                 $meta->put( "TOPICMOVED", %moved );
            }
        }
    }

    return $meta;
}

=pod

---++ sub getMinimalMeta (  $theWeb, $theTopic  ) -> $meta

Get the minimum amount of meta-data necessary to find the
topic parent.
Generalised for Codev.DataFramework. Needs to be fast because
of use by Render.pm.

=cut

sub getMinimalMeta
{
    my( $theWeb, $theTopic ) = @_;

    my $topicHandler = _getTopicHandler( $theWeb, $theTopic );
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

    return _extractMetaData( $theWeb, $theTopic, $data );
}

=pod

---++ readTopic( $web, $topic, $internal )
Return value: ( $metaObject, $topicText )

Reads the most recent version of a topic.  If $internal is false, view
permission will be required for the topic read to be successful.  A failed
topic read is indicated by setting $TWiki::readTopicPermissionFailed.

The metadata and topic text are returned separately, with the metadata in a
TWiki::Meta object.  (The topic text is, as usual, just a string.)

=cut

sub readTopic
{
    my( $theWeb, $theTopic, $internal ) = @_;

    my $text = readTopicRaw( $theWeb, $theTopic, "", $internal );
    my $meta = _extractMetaData( $theWeb, $theTopic, $text );
    die "Internal error |$theWeb|$theTopic|" unless $meta;
    return( $meta, $text );
}

=pod

---++ sub readWebTopic (  $theWeb, $theName  )

Reads and returns the raw text of a topic.

SMELL: since the text returned contains META this method breaks the encapsulation of the Store. The only argument for this method is that it skips the extraction of meta-data from topics, which may be fractionally faster. I _believe_ it can be safely implemented to just return the topic text with no META.

=cut

sub readWebTopic
{
    my( $theWeb, $theName ) = @_;
    my $text = readFile( "$TWiki::dataDir/$theWeb/$theName.txt" );
    
    return $text;
}

=pod

---++ readTopicRaw( $web, $topic, $version, $internal )
Return value: $topicText

Reads a topic; the most recent version is used unless $version is specified.
If $internal is false, view access permission will be checked.  If permission
is not granted, then an error message will be returned in $text, and set in
$TWiki::readTopicPermissionFailed.

SMELL: breaks encapsulation of the store, as it assumes meta is stored embedded in the text, and clients use this. Other implementors of store will be forced to insert meta-data to ensure correct operation of View raw=debug and the "repRev" mode of Edit.

=cut

sub readTopicRaw
{
    my( $theWeb, $theTopic, $theVersion, $internal ) = @_;

    #SVEN - test if theTopic contains a webName to override $theWeb
    ( $theWeb, $theTopic ) = TWiki::normalizeWebTopicName( $theWeb, $theTopic );

    my $text = "";
    if( ! $theVersion ) {
        $text = readFile( "$TWiki::dataDir/$theWeb/$theTopic.txt" );
    } else {
        $text = _readVersionNoMeta( $theWeb, $theTopic, $theVersion);
    }

    my $viewAccessOK = 1;
    unless( $internal ) {
        $viewAccessOK = TWiki::Access::checkAccessPermission( "view", $TWiki::wikiUserName, $text, $theTopic, $theWeb );
        # TWiki::writeDebug( "readTopicRaw $viewAccessOK $TWiki::wikiUserName $theWeb $theTopic" );
    }
    
    unless( $viewAccessOK ) {
        # FIXME: TWiki::Func::readTopicText will break if the following text changes
        $text = "No permission to read topic $theWeb.$theTopic  - perhaps you need to log in?\n";
        # Could note inability to read so can divert to viewauth or similar
        $TWiki::readTopicPermissionFailed = "$TWiki::readTopicPermissionFailed $theWeb.$theTopic";
    }

    return $text;
}


=pod

---++ readFile( $filename )
Return value: $fileContents

Returns the entire contents of the given file, which can be specified in any
format acceptable to the Perl open() function.  SECURITY NOTE: make sure
any $filename coming from a user is stripped of special characters that might
change Perl's open() semantics.

Used for reading side-files of meta-data, such as fileTypes, changes, etc.

SMELL: Breaks Store encapsulation, if it is used to read files other than the standard meta-files (e.g. if it is used to read topic files)

=cut

sub readFile
{
    my( $name ) = @_;
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

---++ sub readFileHead (  $name, $maxLines  )

Returns $maxLines of content from the head of the given file-system file.

SMELL: breaks Store encapsulation, if it is used to access topics or attachments under the control of Store.

=cut

sub readFileHead
{
    my( $name, $maxLines ) = @_;
    my $data = "";
    my $line;
    my $l = 0;
    $/ = "\n";     # read line by line
    open( IN_FILE, "<$name" ) || return "";
    while( ( $l < $maxLines ) && ( $line = <IN_FILE> ) ) {
        $data .= $line;
        $l += 1;
    }
    close( IN_FILE );
    return $data;
}

=pod

---+++ getTopicNames( $web ) ==> @topics

| Description: | Get list of all topics in a web |
| Parameter: =$web= | Web name, required, e.g. ="Sandbox"= |
| Return: =@topics= | Topic list, e.g. =( "WebChanges",  "WebHome", "WebIndex", "WebNotify" )= |

=cut

sub getTopicNames {
    my( $web ) = @_ ;

    if( !defined $web ) {
	$web="";
    }

    #FIXME untaint web name?

    # get list of all topics by scanning $dataDir
    opendir DIR, "$TWiki::dataDir/$web" ;
    my @topicList = sort grep { s/\.txt$// } readdir( DIR );
    closedir( DIR );
    return @topicList ;    
}

=pod

---++ sub getSubWebs (  $web  )

gets a list of sub-webs contained in the given named web. If the
web is null, it gets a list of all top-level webs. $web may
be a pathname at any level of the hierarchy; for example, it may be
Dadweb/Kidweb/Petweb. Includes hidden webs (those starting with
non-alphanumeric characters).

=cut

sub getSubWebs {
    my( $web ) = @_ ;

    if( !defined $web ) {
        $web="";
    }

    #FIXME untaint web name?

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


# =========================
# CC: removed - useless.
#use vars qw ($subWebsAllowedP);

#$subWebsAllowedP = 0; # 1 = subwebs allowed, 0 = flat webs

=pod

---++ sub getAllWebs() -> list of web names

Gets a list of webnames, of webs contained within the given
web. Potentially able to expand recursively, but this is
commented out as support is lacking for subwebs almost everywhere
else.

=cut

sub getAllWebs {
    # returns a list of subweb names
    my( $web ) = @_ ;

    if( !defined $web ) {
        $web="";
    }

    my @webList =
      map { s/^\///o; $_ } # remove leading /
        map { "$web/$_" }
          &getSubWebs( $web );

#cc    my $subWeb = "";
#cc    if( $subWebsAllowedP ) {
#cc        my @subWebs = @webList;
#cc        foreach $subWeb ( @webList ) {
#cc            push @subWebs, &getAllWebs( $subWeb );
#cc        }
#cc        return @subWebs;
#cc    }
    return @webList ;
}

=pod

---+++ setTopicRevisionTag( $web, $topic, $rev, $tag ) ==> $success

| Description: | sets a names tag on the specified revision |
| Parameter: =$web= | webname |
| Parameter: =$topic= | topic name |
| Parameter: =$rev= | the revision we are taging |
| Parameter: =$tag= | the string to tag with |
| Return: =$success= |  |
| TODO: | we _need_ an error mechanism! |
| Since: | TWiki:: (20 April 2004) |

=cut

sub setTopicRevisionTag
{
	my ( $web, $topic, $rev, $tag ) = @_;
	
    my $topicHandler = _getTopicHandler( $web, $topic );
#	TWiki::writeDebug("Store - setTopicRevisionTag ( $web, $topic, $rev, $tag )");	
    return $topicHandler->setTopicRevisionTag( $web, $topic, $rev, $tag );
}

# Write a meta-data key=value pair
sub _writeKeyValue {
    my( $key, $value ) = @_;

    $value =~ s/\r\r\n/%_N_%/go;
    $value =~ s/\r\n/%_N_%/go;
    $value =~ s/\n\r/%_N_%/go;
    $value =~ s/\r\n/%_N_%/go; # Deal with doubles or \n\r
    $value =~ s/\r/\n/go;
    $value =~ s/\n/%_N_%/go;
    $value =~ s/"/%_Q_%/go;

    return "$key=\"$value\"";
}

# Write all the key=value pairs for the types listed
sub _writeTypes {
    my( $meta, @types ) = @_;
    
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

# Meta data for start of topic
sub _writeStart
{
    my( $meta ) = @_;
    
    return _writeTypes( $meta, qw/TOPICINFO TOPICPARENT/ );
}

# Meta data for end of topic
sub _writeEnd
{
    my( $meta ) = @_;

    my $text = _writeTypes($meta, qw/FORM FIELD FILEATTACHMENT TOPICMOVED/ );
    # append remaining meta data
    $text .= _writeTypes( $meta, qw/not TOPICINFO TOPICPARENT FORM FIELD FILEATTACHMENT TOPICMOVED/ );
    return $text;
}

# ===========================
# Prepend/append meta data to topic
sub _writeMeta
{
    my( $meta, $text ) = @_;
    
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
    my ( $meta, $text ) = @_;

    return _writeMeta( $meta, $text );
}

# =========================

1;

# EOF

