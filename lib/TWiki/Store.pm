# Module of TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 1999-2003 Peter Thoeny, peter@thoeny.com
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

package TWiki::Store;

use File::Copy;
use Time::Local;

use strict;

# 'Use locale' for internationalisation of Perl sorting in getTopicNames
# and other routines - main locale settings are done in TWiki::setupLocale
BEGIN {
    # Do a dynamic 'use locale' for this module
    if( $TWiki::useLocale ) {
        require locale;
	import locale ();
    }
}

# FIXME: Move elsewhere?
# template variable hash: (built from %TMPL:DEF{"key"}% ... %TMPL:END%)
use vars qw( %templateVars ); # init in TWiki.pm so okay for modPerl

# ===========================
sub initialize
{
    %templateVars = ();
    eval "use TWiki::Store::$TWiki::storeTopicImpl;";
}

# ===========================
# Normally writes no output, uncomment writeDebug line to get output of all RCS etc command to debug file
sub _traceExec
{
   #my( $cmd, $result ) = @_;
   #TWiki::writeDebug( "Store exec: $cmd -> $result" );
}

sub writeDebug
{
   #TWiki::writeDebug( "Store: $_[0]" );
}

sub _getTopicHandler
{
   my( $web, $topic, $attachment ) = @_;

   $attachment = "" if( ! $attachment );

   my $handlerName = "TWiki::Store::$TWiki::storeTopicImpl";

   my $handler = $handlerName->new( $web, $topic, $attachment, @TWiki::storeSettings );
   return $handler;
}


# =========================
# Normalize a Web.TopicName
# Input:                      Return:
#   ( "Web",  "Topic" )         ( "Web",  "Topic" )
#   ( "",     "Topic" )         ( "Main", "Topic" )
#   ( "",     "" )              ( "Main", "WebHome" )
#   ( "",     "Web/Topic" )     ( "Web",  "Topic" )
#   ( "",     "Web.Topic" )     ( "Web",  "Topic" )
#   ( "Web1", "Web2.Topic" )    ( "Web2", "Topic" )
# Note: Function renamed from getWebTopic
sub normalizeWebTopicName
{
   my( $theWeb, $theTopic ) = @_;

   if( $theTopic =~ m|^([^.]+)[\.\/](.*)$| ) {
       $theWeb = $1;
       $theTopic = $2;
   }
   $theWeb = $TWiki::webName unless( $theWeb );
   $theTopic = $TWiki::topicName unless( $theTopic );

   return( $theWeb, $theTopic );
}


# =========================
# Get rid a topic and its attachments completely
# Intended for TEST purposes.
# Use with GREAT CARE as file will be gone, including RCS history
sub erase
{
    my( $web, $topic ) = @_;

    my $topicHandler = _getTopicHandler( $web, $topic );
    $topicHandler->_delete();

    writeLog( "erase", "$web.$topic", "" );
}

# =========================
# Move an attachment from one topic to another.
# If there is a problem an error string is returned.
# The caller to this routine should check that all topics are valid and
# do lock on the topics.
sub moveAttachment
{
    my( $oldWeb, $oldTopic, $newWeb, $newTopic, $theAttachment ) = @_;
    
    my $topicHandler = _getTopicHandler( $oldWeb, $oldTopic, $theAttachment );
    my $error = $topicHandler->moveMe( $newWeb, $newTopic );
    return $error if( $error );

    # Remove file attachment from old topic
    my( $meta, $text ) = readTopic( $oldWeb, $oldTopic );
    my %fileAttachment = $meta->findOne( "FILEATTACHMENT", $theAttachment );
    $meta->remove( "FILEATTACHMENT", $theAttachment );
    $error .= saveNew( $oldWeb, $oldTopic, $text, $meta, "", "", "", "doUnlock", "dont notify", "" ); 
    
    # Remove lock file
    $topicHandler->setLock( "" );
    
    # Add file attachment to new topic
    ( $meta, $text ) = readTopic( $newWeb, $newTopic );

    $fileAttachment{"movefrom"} = "$oldWeb.$oldTopic";
    $fileAttachment{"moveby"}   = $TWiki::userName;
    $fileAttachment{"movedto"}  = "$newWeb.$newTopic";
    $fileAttachment{"movedwhen"} = time();
    $meta->put( "FILEATTACHMENT", %fileAttachment );    
    
    $error .= saveNew( $newWeb, $newTopic, $text, $meta, "", "", "", "doUnlock", "dont notify", "" ); 
    # Remove lock file.
    my $newTopicHandler = _getTopicHandler( $newWeb, $newTopic, $theAttachment );
    $newTopicHandler->setLock( "" );
    
    writeLog( "move", "$oldWeb.$oldTopic", "Attachment $theAttachment moved to $newWeb.$newTopic" );

    return $error;
}

# =========================
# Change refs out of a topic, I have a feeling this shouldn't be in Store.pm
sub changeRefTo
{
   my( $text, $oldWeb, $oldTopic ) = @_;
   my $preTopic = '^|[\*\s\[][-\(\s]*';
   # TODO: i18n fix on topic names
   my $postTopic = '$|[^A-Za-z0-9_.]|\.\s';
   my $metaPreTopic = '"|[\s[,\(-]';
   my $metaPostTopic = '[^A-Za-z0-9_.]|\.\s';
   
   my $out = "";
   
   # Get list of topics in $oldWeb, replace local refs topic, with full web.topic
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
                      s/($metaPreTopic)\Q$topic\E(?=$metaPostTopic)/$1$oldWeb.$topic/g;
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



# =========================
# Rename a Web, allow for transfer between Webs
# It is the responsibility of the caller to check: exstance webs & topics, lock taken for topic
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
      my $fullText = readTopicRaw( $newWeb, $newTopic );
      if( ( $oldWeb ne $newWeb ) && $doChangeRefTo ) {
         $fullText = changeRefTo( $fullText, $oldWeb, $oldTopic );
      }
      my ( $meta, $text ) = _extractMetaData( $newWeb, $newTopic, $fullText );
      $meta->put( "TOPICMOVED", @args );
      saveNew( $newWeb, $newTopic, $text, $meta, "", "", "", "unlock" );
   }
   
   # Log rename
   if( $TWiki::doLogRename ) {
      writeLog( "rename", "$oldWeb.$oldTopic", "moved to $newWeb.$newTopic $error" );
   }
   
   # Remove old lock file
   $topicHandler->setLock( "" );
   
   return $error;
}


# =========================
# Read a specific version of a topic
# view:     $text= &TWiki::Store::readTopicVersion( $topic, "1.$rev" );
sub readTopicVersion
{
    my( $theWeb, $theTopic, $theRev ) = @_;
    my $text = _readVersionNoMeta( $theWeb, $theTopic, $theRev );
    my $meta = "";
   
    ( $meta, $text ) = _extractMetaData( $theWeb, $theTopic, $text );
        
    return( $meta, $text );
}

# =========================
# Read a specific version of a topic
sub _readVersionNoMeta
{
    my( $theWeb, $theTopic, $theRev ) = @_;
    my $topicHandler = _getTopicHandler( $theWeb, $theTopic );
    
    $theRev =~ s/^1\.//o;
    return $topicHandler->getRevision( $theRev );
}

# =========================
sub readAttachmentVersion
{
   my ( $theWeb, $theTopic, $theAttachment, $theRev ) = @_;
   
   my $topicHandler = _getTopicHandler( $theWeb, $theTopic, $theAttachment );
   $theRev =~ s/^1\.//o;
   return $topicHandler->getRevision( $theRev );
}

# =========================
# Use meta information if available ...
sub getRevisionNumber
{
    my( $theWebName, $theTopic, $attachment ) = @_;
    my $ret = getRevisionNumberX( $theWebName, $theTopic, $attachment );
    ##TWiki::writeDebug( "Store: rev = $ret" );
    if( ! $ret ) {
       $ret = "1.1"; # Temporary
    }
    
    return $ret;
}


# =========================
# Latest revision number
# Returns "" if there is no revision
sub getRevisionNumberX
{
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


# =========================
# rdiff:            $text = &TWiki::Store::getRevisionDiff( $webName, $topic, "1.$r2", "1.$r1" );
sub getRevisionDiff
{
    my( $web, $topic, $rev1, $rev2 ) = @_;

    my $rcs = _getTopicHandler( $web, $topic );
    my $r1 = substr( $rev1, 2 );
    my $r2 = substr( $rev2, 2 );
    my( $error, $diff ) = $rcs->revisionDiff( $r1, $r2 );
    return $diff;
}


# =========================
# Call getRevisionInfoFromMeta for faster response for topics
# FIXME try and get rid of this it's a mess
# In direct calls changeToIsoDate always seems to be 1
sub getRevisionInfo
{
    my( $theWebName, $theTopic, $theRev, $changeToIsoDate, $attachment, $topicHandler ) = @_;
    if( ! $theWebName ) {
        $theWebName = $TWiki::webName;
    }
    
    $theRev =~ s/^1\.//o;

    $topicHandler = _getTopicHandler( $theWebName, $theTopic, $attachment ) if( ! $topicHandler );
    my( $rcsOut, $rev, $date, $user, $comment ) = $topicHandler->getRevisionInfo( $theRev );
    
    if( $changeToIsoDate ) {
        $date = TWiki::formatGmTime( $date );
    } else {
         # FIXME get rid of this - shouldn't be needing rcs date time format
        $date = TWiki::Store::RcsFile::_epochToRcsDateTime( $date );
    }
    
    return ( $date, $user, $rev, $comment );
}


# =========================
sub topicIsLockedBy
{
    my( $theWeb, $theTopic ) = @_;

    # pragmatic approach: Warn user if somebody else pressed the
    # edit link within a time limit e.g. 1 hour

    ( $theWeb, $theTopic ) = normalizeWebTopicName( $theWeb, $theTopic );

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
sub keyValue2list
{
    my( $args ) = @_;
    
    my @res = ();
    
    # Format of data is name="value" name1="value1" [...]
    while( $args =~ s/\s*([^=]+)=\"([^"]*)\"//o ) { #" avoid confusing syntax highlighters
        push @res, $1;
        push @res, $2;
    }
    
    return @res;
}


# ========================
sub metaAddTopicData
{
    my( $web, $topic, $rev, $meta, $forceDate, $forceUser ) = @_;

    my $time = $forceDate || time();
    my $user = $forceUser || $TWiki::userName;

    my @args = (
       "version" => "$rev",
       "date"    => "$time",
       "author"  => "$user",
       "format"  => $TWiki::formatVersion );
    $meta->put( "TOPICINFO", @args );
}


# =========================
sub saveTopicNew
{
    my( $web, $topic, $text, $metaData, $saveCmd, $doUnlock, $dontNotify, $dontLogSave ) = @_;
    my $attachment = "";
    my $meta = TWiki::Meta->new();
    $meta->readArray( @$metaData );
    saveNew( $web, $topic, $text, $meta, $saveCmd, $attachment, $dontLogSave, $doUnlock, $dontNotify );
}

# =========================
sub saveTopic
{
    my( $web, $topic, $text, $meta, $saveCmd, $doUnlock, $dontNotify, $dontLogSave, $forceDate ) = @_;
    my $attachment = "";
    my $comment = "";

    # FIXME: Inefficient code that hides meta data from Plugin callback
    $text = $meta->write( $text );  # add meta data for Plugin callback
    TWiki::Plugins::beforeSaveHandler( $text, $topic, $web );
    $meta = TWiki::Meta->remove();  # remove all meta data
    $text = $meta->read( $text );   # restore meta data

    my$error = saveNew( $web, $topic, $text, $meta, $saveCmd, $attachment, $dontLogSave, $doUnlock, $dontNotify, $comment, $forceDate );
    return $error;
}

# =========================
sub saveAttachment
{
    my( $web, $topic, $text, $saveCmd, $attachment, $dontLogSave, $doUnlock, $dontNotify, $theComment, $theTmpFilename,
        $forceDate) = @_;
        
    my $topicHandler = _getTopicHandler( $web, $topic, $attachment );
    my $error = $topicHandler->addRevision( $theTmpFilename, $theComment, $TWiki::userName );
    $topicHandler->setLock( ! $doUnlock );
    
    return $error;
}


# =========================
sub save
{
    my( $web, $topic, $text, $saveCmd, $attachment, $dontLogSave, $doUnlock, $dontNotify, $theComment, $forceDate ) = @_;
    
    # FIXME get rid of this routine
    
    my $meta = TWiki::Meta->new();
    
    return saveNew( $web, $topic, $text, $meta, $saveCmd, $attachment, $dontLogSave, $doUnlock, $dontNotify, $theComment, $forceDate );
}


# =========================
# Add meta data to the topic
sub _addMeta
{
    my( $web, $topic, $text, $attachment, $nextRev, $meta, $forceDate, $forceUser ) = @_;
    
    if( ! $attachment ) {
        $nextRev = "1.1" if( ! $nextRev );
        metaAddTopicData(  $web, $topic, $nextRev, $meta, $forceDate, $forceUser );
        $text = $meta->write( $text );        
    }
    
    return $text;
}


# =========================
# return non-null string if there is an (RCS) error.
# FIXME: does rev info from meta work if user saves a topic with no change?
sub saveNew
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
            my( $date, $user ) = getRevisionInfo( $web, $topic, $currentRev, "", $attachment, $topicHandler );
            # TWiki::writeDebug( "Store::save date = $date" );
            # same user?
            if( ( $TWiki::doKeepRevIfEditLock ) && ( $user eq $TWiki::userName ) && $currentRev ) {
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
                my( $fdate, $fuser, $frev ) = getRevisionInfo( $web, $topic, "", "", $attachment, $topicHandler );
                $fdate = ""; # suppress warning
                $fuser = ""; # suppress warning

                my @foo = split( /\n/, &readFile( "$TWiki::dataDir/$TWiki::webName/.changes" ) );
                if( $#foo > 100 ) {
                    shift( @foo);
                }
                push( @foo, "$topic\t$TWiki::userName\t$time\t$frev" );
                open( FILE, ">$TWiki::dataDir/$TWiki::webName/.changes" );
                print FILE join( "\n", @foo )."\n";
                close(FILE);
            }

            if( ( $TWiki::doLogTopicSave ) && ! ( $dontLogSave ) ) {
                # write log entry
                writeLog( "save", "$TWiki::webName.$topic", "" );
            }
        }
    }

    #### Replace Revision Save
    if( $saveCmd eq "repRev" ) {
        # fix topic by replacing last revision, but do not update .changes

        # save topic with same userName and date
        # FIXME why should date be the same if same user replacing with editLockTime?
        my( $date, $user, $rev ) = getRevisionInfo( $web, $topic, "", 1, $attachment, $topicHandler );
        $rev = "1.$rev";

        # Add two minutes (make small difference, but not too big for notification)
        my $epochSec = &TWiki::revDate2EpSecs( $date ) + 120;
        $date = &TWiki::formatGmTime( $epochSec, "rcs" );
        $text = _addMeta( $web, $topic, $text, $attachment, $rev,
                          $meta, $epochSec, $user );

        my $dataError = $topicHandler->replaceRevision( $text, $theComment, $user, $date );
        return $dataError if( $dataError );
        $topicHandler->setLock( ! $doUnlock );

        if( ( $TWiki::doLogTopicSave ) && ! ( $dontLogSave ) ) {
            # write log entry
            $tmp  = &TWiki::userToWikiName( $user );
            writeLog( "save", "$TWiki::webName.$topic", "repRev $rev $tmp $date" );
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
            writeLog( "cmd", "$TWiki::webName.$topic", "delRev $rev" );
        }
    }
    return ""; # all is well
}

# =========================
sub writeLog
{
    my( $action, $webTopic, $extra, $user ) = @_;

    # use local time for log, not UTC (gmtime)

    my ( $sec, $min, $hour, $mday, $mon, $year ) = localtime( time() );
    my( $tmon) = $TWiki::isoMonth[$mon];
    $year = sprintf( "%.4u", $year + 1900 );  # Y2K fix
    my $time = sprintf( "%.2u ${tmon} %.2u - %.2u:%.2u", $mday, $year, $hour, $min );
    my $yearmonth = sprintf( "%.4u%.2u", $year, $mon+1 );

    my $wuserName = $user || $TWiki::userName;
    $wuserName = &TWiki::userToWikiName( $wuserName );
    my $remoteAddr = $ENV{'REMOTE_ADDR'} || "";
    my $text = "| $time | $wuserName | $action | $webTopic | $extra | $remoteAddr |";

    my $filename = $TWiki::logFilename;
    $filename =~ s/%DATE%/$yearmonth/go;
    open( FILE, ">>$filename");
    print FILE "$text\n";
    close( FILE);
}

# =========================
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

# =========================
sub lockTopic
{
   my ( $name, $doUnlock ) = @_;

   lockTopicNew( $TWiki::webName, $name, $doUnlock );
}

# =========================
# Called from rename and TWiki::Func
sub lockTopicNew
{
    my( $theWeb, $theTopic, $doUnlock ) = @_;

    ( $theWeb, $theTopic ) = normalizeWebTopicName( $theWeb, $theTopic );
    
    my $topicHandler = _getTopicHandler( $theWeb, $theTopic );
    $topicHandler->setLock( ! $doUnlock );
}

# =========================
sub removeObsoleteTopicLocks
{
    my( $web ) = @_;

    # Clean all obsolete .lock files in a web.
    # This should be called regularly, best from a cron job (called from mailnotify)

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

# =========================
sub webExists
{
    my( $theWeb ) = @_;
    return -e "$TWiki::dataDir/$theWeb";
}

# =========================
sub topicExists
{
    my( $theWeb, $theTopic ) = @_;
    ( $theWeb, $theTopic ) = normalizeWebTopicName( $theWeb, $theTopic );
    return -e "$TWiki::dataDir/$theWeb/$theTopic.txt";
}

# =========================
# Try and get from meta information in topic, if this can't be done then use RCS
# Note there is no "1." prefix to this data
sub getRevisionInfoFromMeta
{
    my( $web, $topic, $meta, $changeToIsoDate ) = @_;
    
    my( $date, $author, $rev );
    my %topicinfo = ();
    
    if( $meta ) {
        %topicinfo = $meta->findOne( "TOPICINFO" );
    }
        
    if( %topicinfo ) {
       # Stored as meta data in topic for faster access
       $date = TWiki::formatGmTime( $topicinfo{"date"} ); # FIXME deal with changeToIsoDate
       $author = $topicinfo{"author"};
       my $tmp = $topicinfo{"version"};
       $tmp =~ /1\.(.*)/o;
       $rev = $1;
    } else {
       # Get data from RCS
       ( $date, $author, $rev ) = getRevisionInfo( $web, $topic, "", 1 );
    }
    
    # writeDebug( "rev = $rev" );
    
    return( $date, $author, $rev );
}


# =========================
sub convert2metaFormat
{
    my( $web, $topic, $text ) = @_;
    
    my $meta = TWiki::Meta->new();
    $text = $meta->read( $text );
     
    if ( $text =~ /<!--TWikiAttachment-->/ ) {
       $text = TWiki::Attach::migrateToFileAttachmentMacro( $meta, $text );
    }
    
    if ( $text =~ /<!--TWikiCat-->/ ) {
       $text = TWiki::Form::upgradeCategoryTable( $web, $topic, $meta, $text );    
    }
    
    return( $meta, $text );
}

# =========================
# Expect meta data at top of file, but willing to accept it anywhere
# If we have an old file format without meta data, then convert
sub _extractMetaData
{
    my( $web, $topic, $fulltext ) = @_;
    
    my $meta = TWiki::Meta->new();
    my $text = $meta->read( $fulltext );

    
    # If there is no meta data then convert
    if( ! $meta->count( "TOPICINFO" ) ) {
        ( $meta, $text ) = convert2metaFormat( $web, $topic, $text );
    } else {
        my %topicinfo = $meta->findOne( "TOPICINFO" );
        if( $topicinfo{"format"} eq "1.0beta" ) {
            # This format used live at DrKW for a few months
            if( $text =~ /<!--TWikiCat-->/ ) {
               $text = TWiki::Form::upgradeCategoryTable( $web, $topic, $meta, $text );
            }
            
            TWiki::Attach::upgradeFrom1v0beta( $meta );
            
            if( $meta->count( "TOPICMOVED" ) ) {
                 my %moved = $meta->findOne( "TOPICMOVED" );
                 $moved{"by"} = TWiki::wikiToUserName( $moved{"by"} );
                 $meta->put( "TOPICMOVED", %moved );
            }
        }
    }
    
    return( $meta, $text );
}

# FIXME - get rid of this because uses private part of handler
sub getFileName
{
    my( $theWeb, $theTopic, $theAttachment ) = @_;

    my $topicHandler = _getTopicHandler( $theWeb, $theTopic, $theAttachment );
    return $topicHandler->{file};
}

# ======================
# Just read the meta data at the top of the topic
# Generalise for Codev.DataFramework, but needs to be fast because of use by view script
sub readTopMeta
{
    my( $theWeb, $theTopic ) = @_;
    
    my $topicHandler = _getTopicHandler( $theWeb, $theTopic );
    my $filename = getFileName( $theWeb, $theTopic );
    
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
    
    my( $meta, $text ) = _extractMetaData( $theWeb, $theTopic, $data );
    
    close( IN_FILE );

    return $meta;
}

# =========================
# $internal true if topic being read for internal use
sub readTopic
{
    my( $theWeb, $theTopic, $internal ) = @_;
    
    my $fullText = readTopicRaw( $theWeb, $theTopic, "", $internal );
    
    my ( $meta, $text ) = _extractMetaData( $theWeb, $theTopic, $fullText );
    
    return( $meta, $text );
}

# =========================
sub readWebTopic
{
    my( $theWeb, $theName ) = @_;
    my $text = &readFile( "$TWiki::dataDir/$theWeb/$theName.txt" );
    
    return $text;
}

# =========================
# Optional version in format 1.x
sub readTopicRaw
{
    my( $theWeb, $theTopic, $theVersion, $internal ) = @_;

    #SVEN - test if theTopic contains a webName to override $theWeb
    ( $theWeb, $theTopic ) = normalizeWebTopicName( $theWeb, $theTopic );

    my $text = "";
    if( ! $theVersion ) {
        $text = &readFile( "$TWiki::dataDir/$theWeb/$theTopic.txt" );
    } else {
        $text = _readVersionNoMeta( $theWeb, $theTopic, $theVersion);
    }

    my $viewAccessOK = 1;
    unless( $internal ) {
        $viewAccessOK = &TWiki::Access::checkAccessPermission( "view", $TWiki::wikiUserName, $text, $theTopic, $theWeb );
        # TWiki::writeDebug( "readTopicRaw $viewAccessOK $TWiki::wikiUserName $theWeb $theTopic" );
    }
    
    unless( $viewAccessOK ) {
        # FIXME: TWiki::Func::readTopicText will break if the following text changes
        $text = "No permission to read topic $theWeb.$theTopic\n";
        # Could note inability to read so can divert to viewauth or similar
        $TWiki::readTopicPermissionFailed = "$TWiki::readTopicPermissionFailed $theWeb.$theTopic";
    }

    return $text;
}


# =========================
sub readTemplateTopic
{
    my( $theTopicName ) = @_;

    $theTopicName =~ s/$TWiki::securityFilter//go;    # zap anything suspicious

    # try to read in current web, if not read from TWiki web

    my $web = $TWiki::twikiWebname;
    if( topicExists( $TWiki::webName, $theTopicName ) ) {
        $web = $TWiki::webName;
    }
    return readTopic( $web, $theTopicName );
}

# =========================
sub _readTemplateFile
{
    my( $theName, $theSkin ) = @_;
    $theSkin = "" unless $theSkin; # prevent 'uninitialized value' warnings

    # CrisBailiff, PeterThoeny 13 Jun 2000: Add security
    $theName =~ s/$TWiki::securityFilter//go;    # zap anything suspicious
    $theName =~ s/\.+/\./g;                      # Filter out ".." from filename
    $theSkin =~ s/$TWiki::securityFilter//go;    # zap anything suspicious
    $theSkin =~ s/\.+/\./g;                      # Filter out ".." from filename

    my $tmplFile = "";

    # search first in twiki/templates/Web dir
    # for file script(.skin).tmpl
    my $tmplDir = "$TWiki::templateDir/$TWiki::webName";
    if( opendir( DIR, $tmplDir ) ) {
        # for performance use readdir, not a row of ( -e file )
        my @filelist = grep /^$theName\..*tmpl$/, readdir DIR;
        closedir DIR;
        $tmplFile = "$theName.$theSkin.tmpl";
        if( ! grep { /^$tmplFile$/ } @filelist ) {
            $tmplFile = "$theName.tmpl";
            if( ! grep { /^$tmplFile$/ } @filelist ) {
                $tmplFile = "";
            }
        }
        if( $tmplFile ) {
            $tmplFile = "$tmplDir/$tmplFile";
        }
    }

    # if not found, search in twiki/templates dir
    $tmplDir = $TWiki::templateDir;
    if( ( ! $tmplFile ) && ( opendir( DIR, $tmplDir ) ) ) {
        my @filelist = grep /^$theName\..*tmpl$/, readdir DIR;
        closedir DIR;
        $tmplFile = "$theName.$theSkin.tmpl";
        if( ! grep { /^$tmplFile$/ } @filelist ) {
            $tmplFile = "$theName.tmpl";
            if( ! grep { /^$tmplFile$/ } @filelist ) {
                $tmplFile = "";
            }
        }
        if( $tmplFile ) {
            $tmplFile = "$tmplDir/$tmplFile";
        }
    }

    # read the template file
    if( -e $tmplFile ) {
        return &readFile( $tmplFile );
    }
    return "";
}

# =========================
sub handleTmplP
{
    # Print template variable, called by %TMPL:P{"$theVar"}%
    my( $theVar ) = @_;

    my $val = "";
    if( ( %templateVars ) && ( exists $templateVars{ $theVar } ) ) {
        $val = $templateVars{ $theVar };
        $val =~ s/%TMPL\:P{[\s\"]*(.*?)[\"\s]*}%/&handleTmplP($1)/geo;  # recursion
    }
    if( ( $theVar eq "sep" ) && ( ! $val ) ) {
        # set separator explicitely if not set
        $val = " | ";
    }
    return $val;
}

# =========================
sub readTemplate
{
    my( $theName, $theSkin ) = @_;

    if( ! defined($theSkin) ) {
        $theSkin = &TWiki::getSkin();
    }

    # recursively read template file(s)
    my $text = _readTemplateFile( $theName, $theSkin );
    while( $text =~ /%TMPL\:INCLUDE{[\s\"]*(.*?)[\"\s]*}%/s ) {
        $text =~ s/%TMPL\:INCLUDE{[\s\"]*(.*?)[\"\s]*}%/&_readTemplateFile( $1, $theSkin )/geo;
    }

    if( ! ( $text =~ /%TMPL\:/s ) ) {
        # no template processing
        $text =~ s|^(( {3})+)|"\t" x (length($1)/3)|geom;  # leading spaces to tabs
        return $text;
    }

    my $result = "";
    my $key  = "";
    my $val  = "";
    my $delim = "";
    foreach( split( /(%TMPL\:)/, $text ) ) {
        if( /^(%TMPL\:)$/ ) {
            $delim = $1;
        } elsif( ( /^DEF{[\s\"]*(.*?)[\"\s]*}%[\n\r]*(.*)/s ) && ( $1 ) ) {
            # handle %TMPL:DEF{"key"}%
            if( $key ) {
                $templateVars{ $key } = $val;
            }
            $key = $1;
            $val = $2 || "";

        } elsif( /^END%[\n\r]*(.*)/s ) {
            # handle %TMPL:END%
            $templateVars{ $key } = $val;
            $key = "";
            $val = "";
            $result .= $1 || "";

        } elsif( $key ) {
            $val    .= "$delim$_";

        } else {
            $result .= "$delim$_";
        }
    }

    # handle %TMPL:P{"..."}% recursively
    $result =~ s/%TMPL\:P{[\s\"]*(.*?)[\"\s]*}%/&handleTmplP($1)/geo;
    $result =~ s|^(( {3})+)|"\t" x (length($1)/3)|geom;  # leading spaces to tabs
    return $result;
}


# =========================
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


# =========================
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


# =========================
#AS 5 Dec 2000 collect all Web's topic names
sub getTopicNames {
    my( $web ) = @_ ;

    if( !defined $web ) {
	$web="";
    }

    #FIXME untaint web name?

    # get list of all topics by scanning $dataDir
    opendir DIR, "$TWiki::dataDir/$web" ;
    my @tmpList = readdir( DIR );
    closedir( DIR );

    # this is not magic, it just looks like it.
    my @topicList = sort
        grep { s#^.+/([^/]+)\.txt$#$1# }
        grep { ! -d }
        map  { "$TWiki::dataDir/$web/$_" }
        grep { ! /^\.\.?$/ } @tmpList;

    return @topicList ;    
}
#/AS


# =========================
#AS 5 Dec 2000 collect immediate subWeb names
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
        grep { s#^.+/([^/]+)$#$1# }
        grep { -d }
        map  { "$TWiki::dataDir/$web/$_" }
        grep { ! /^\.\.?$/ } @tmpList;

    return @webList ;
}
#/AS


# =========================
#AS 26 Dec 2000 recursively collects all Web names
#FIXME: move var to TWiki.cfg ?
use vars qw ($subWebsAllowedP);
$subWebsAllowedP = 0; # 1 = subwebs allowed, 0 = flat webs

sub getAllWebs {
    # returns a list of subweb names
    my( $web ) = @_ ;
    
    if( !defined $web ) {
	$web="";
    }
    my @webList =   map { s/^\///o; $_ }
		    map { "$web/$_" }
		    &getSubWebs( $web );
    my $subWeb = "";
    if( $subWebsAllowedP ) {
        my @subWebs = @webList;
	foreach $subWeb ( @webList ) {
	    push @subWebs, &getAllWebs( $subWeb );
	}
	return @subWebs;
    }
    return @webList ;
}
#/AS


# =========================

1;

# EOF
