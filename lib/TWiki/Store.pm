#
# TWiki WikiClone (see TWiki.pm for $wikiversion and other info)
#
# Copyright (C) 1999-2001 Peter Thoeny, peter@thoeny.com
#
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

# FIXME: Move elsewhere?
# template variable hash: (built from %TMPL:DEF{"key"}% ... %TMPL:END%)
use vars qw( %templateVars ); # init in TWiki.pm so okay for modPerl

# ===========================
# Normally writes no output, uncomment writeDebug line to get output of all RCS etc command to debug file
sub _traceExec
{
   my( $cmd, $result ) = @_;
   
   #TWiki::writeDebug( "Store exec: $cmd -> $result" );
}

sub writeDebug
{
   #TWiki::writeDebug( "Store: $_[0]" );
}


# =========================
# Given a full topic name, split into Web and Topic
# e.g. Test.TestTopic1 -> ("Test", "TestTopic1")
sub getWebTopic
{
   my( $fullTopic ) = @_;
   $fullTopic =~ m|^([^.]+)[./](.*)$|;
   my $web = $1;
   my $topic = $2;
   return ($web, $topic );
}


# =========================
# Get full filename for attachment or topic, untaint
# Extension can be:
# If $attachment is blank
#    blank or .txt - topic data file
#    ,v            - topic history file
#    lock          - topic lock file
# If $attachment
#    blank         - attachment file
#    ,v            - attachment history file
sub getFileName
{
   my( $web, $topic, $attachment, $extension ) = @_;

   if( ! $attachment ) {
      $attachment = "";
   }
   
   if( ! $extension ) {
      $extension = "";
   }
 
   my $file = "";
   my $extra = "";
   if( ! $attachment ) {
      if( ! $extension ) {
         $extension = ".txt";
      } else {
         if( $extension eq ",v" ) {
            $extension = ".txt$extension";
            if( $TWiki::useRcsDir && -d "$TWiki::dataDir/$web/RCS" ) {
               $extra = "/RCS";
            }
         }
      }
      $file = "$TWiki::dataDir/$web$extra/$topic$extension";

   } else {
      if ( $extension eq ",v" && $TWiki::useRcsDir && -d "$TWiki::dataDir/$web/RCS" ) {
         $extra = "/RCS";
      }
      
      $file = "$TWiki::pubDir/$web/$topic$extra/$attachment$extension";
   }

   # Shouldn't really need to untaint here - done to be sure
   $file =~ /(.*)/;
   $file = $1; # untaint
   
   return $file;
}


# =========================
# Get directory that topic or attachment lives in
#    Leave topic blank if you want the web directory rather than the topic directory
sub getFileDir
{
   my( $web, $topic, $attachment, $extension) = @_;
   
   my $dir = "";
   if( ! $attachment ) {
      if( $extension eq ",v" && $TWiki::useRcsDir && -d "$TWiki::dataDir/$web/RCS" ) {
         $dir = "$TWiki::dataDir/$web/RCS";
      } else {
         $dir = "$TWiki::dataDir/$web";
      }
   } else {
      my $suffix = "";
      if ( $extension eq ",v" && $TWiki::useRcsDir && -d "$TWiki::dataDir/$web/RCS" ) {
         $suffix = "/RCS";
      }
      $dir = "$TWiki::pubDir/$web/$topic$suffix";
   }

   # Shouldn't really need to untaint here - done to be sure
   $dir =~ /(.*)/;
   $dir = $1; # untaint
   
   return $dir;
}


# =========================
# Get rid a topic and its attachments completely
# Intended for TEST purposes.
# Use with GREAT CARE as file will be gone, including RCS history
sub erase
{
   my( $web, $topic ) = @_;

   my $file = getFileName( $web, $topic );
   my $rcsDirFile = "$TWiki::dataDir/$web/RCS/$topic,v";

   # Because test switches between using/not-using RCS dir, do both
   my @files = ( $file, "$file,v", $rcsDirFile );
   unlink( @files );
   
   # Delete all attachments and the attachment directory
   my $attDir = getFileDir( $web, $topic, 1, "" );
   if( -e $attDir ) {
       opendir( DIR, $attDir );
       my @attachments = readdir( DIR );
       closedir( DIR );
       my $attachment;
       foreach $attachment ( @attachments ) {
          if( ! -d "$attDir/$attachment" ) {
             unlink( "$attDir/$attachment" ) || warn "Couldn't remove $attDir/$attachment";
             if( $attachment !~ /,v$/ ) {
                writeLog( "erase", "$web.$topic.$attachment" );
             }
          }
       }
       
       # Deal with RCS dir if it exists
       my $attRcsDir = "$attDir/RCS";
       if( -e $attRcsDir ) {
           opendir( DIR, $attRcsDir );
           my @attachments = readdir( DIR );
           closedir( DIR );
           my $attachment;
           foreach $attachment ( @attachments ) {
              if( ! -d "$attRcsDir/$attachment" ) {
                 unlink( "$attRcsDir/$attachment" ) || warn "Couldn't remove $attDir/$attachment";
              }
           }  
           rmdir( "$attRcsDir" ) || warn "Couldn't remove directory $attRcsDir";
       }
       
       rmdir( "$attDir" ) || warn "Couldn't remove directory $attDir";
   }

   writeLog( "erase", "$web.$topic", "" );
}

# =========================
# Move an attachment from one topic to another.
# If there is a problem an error string is returned.
# The caller to this routine check that all topics are valid and
# to lock the topics.
sub moveAttachment
{
    my( $oldWeb, $oldTopic, $newWeb, $newTopic, $theAttachment ) = @_;
    
    my $error = "";   
    my $what = "$oldWeb.$oldTopic.$theAttachment -> $newWeb.$newTopic";
    
    # Make sure directory exists to move to - FIMXE might want to delete old one if empty?
    my $newPubDir = getFileDir( $newWeb, $newTopic, $theAttachment, "" );
    if ( ! -e $newPubDir ) {
        umask( 0 );
        mkdir( $newPubDir, 0777 );        
    }
    
    # Move attachment
    my $oldAttachment = getFileName( $oldWeb, $oldTopic, $theAttachment );
    my $newAttachment = getFileName( $newWeb, $newTopic, $theAttachment );
    if( ! move( $oldAttachment, $newAttachment ) ) {
        $error = "Failed to move attachment; $what ($!)";
        return $error;
    }
    
    # Make sure rcs directory exists
    my $newRcsDir = getFileDir( $newWeb, $newTopic, $theAttachment, ",v" );
    if ( ! -e $newRcsDir ) {
        umask( 0 );
        mkdir( $newRcsDir, 0777 );
    }
    
    # Move attachment history
    my $oldAttachmentRcs = getFileName( $oldWeb, $oldTopic, $theAttachment, ",v" );
    my $newAttachmentRcs = getFileName( $newWeb, $newTopic, $theAttachment, ",v" );
    if( -e $oldAttachmentRcs ) {
        if( ! move( $oldAttachmentRcs, $newAttachmentRcs ) ) {
            $error .= "Failed to move attachment history; $what ($!)";
            # Don't return here as attachment file has already been moved
        }
    }

    # Remove file attachment from old topic
    my( $meta, $text ) = readTopic( $oldWeb, $oldTopic );
    my %fileAttachment = $meta->findOne( "FILEATTACHMENT", $theAttachment );
    $meta->remove( "FILEATTACHMENT", $theAttachment );
    $error .= saveNew( $oldWeb, $oldTopic, $text, $meta, "", "", "", "doUnlock", "dont notify", "" ); 
    
    # Remove lock file
    lockTopicNew( $oldWeb, $oldTopic, 1 );
    
    # Add file attachment to new topic
    ( $meta, $text ) = readTopic( $newWeb, $newTopic );

    $meta->put( "FILEATTACHMENT", %fileAttachment );    
    
    $error .= saveNew( $newWeb, $newTopic, $text, $meta, "", "", "", "doUnlock", "dont notify", "" ); 
    # Remove lock file
    lockTopicNew( $newWeb, $newTopic, 1 );
    
    writeLog( "move", "$oldWeb.$oldTopic", "Attachment $theAttachment moved to $newWeb.$newTopic" );

    return $error;
}

# =========================
# Change refs out of a topic, I have a feeling this shouldn't be in Store.pm
sub changeRefTo
{
   my( $text, $oldWeb, $oldTopic ) = @_;
   my $preTopic = '^|[\*\s\[][\(-\s]*';
   my $postTopic = '$|[^A-Za-z0-9_.]|\.\s';
   my $metaPreTopic = '"|[\s[,\(-]';
   my $metaPostTopic = '"|([^A-Za-z0-9_.]|\.\s';
   
   my $out = "";
   
   # Get list of topics in $oldWeb, replace local refs topic, with full web.topic
   my @topics = getTopicNames( $oldWeb );
   
   my $insidePRE = 0;
   my $insideVERBATIM = 0;
   my $noAutoLink = 0;
   
   foreach( split( /\n/, $text ) ) {

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
                  if( /^META:/ ) {
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
   
   my $error = "";

   # Change data file
   my $from = getFileName( $oldWeb, $oldTopic );
   my $to =  getFileName( $newWeb, $newTopic );
   if( ! move( $from, $to ) ) {
       $error .= "data file move failed.  ";
   }

   # Change data file history
   my $oldHistory = getFileName( $oldWeb, $oldTopic, "", ",v" );
   if( ! $error && -e $oldHistory ) {
       if( ! move(
         $oldHistory,
         getFileName( $newWeb, $newTopic, "", ",v" )
       ) ) {
          $error .= "history file move failed.  ";
       }
   }
   
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

   # Rename the attachment directory if there is one
   my $oldAttachDir = getFileDir( $oldWeb, $oldTopic, 1, "");
   my $newAttachDir = getFileDir( $newWeb, $newTopic, 1, "");
   if( ! $error && -e $oldAttachDir ) {
      if( ! move( $oldAttachDir, $newAttachDir ) ) {
          $error .= "attach move failed";
      }
   }
   
   # Log rename
   if( $TWiki::doLogRename ) {
      writeLog( "rename", "$oldWeb.$oldTopic", "moved to $newWeb.$newTopic $error" );
   }
   
   # Remove old lock file
   lockTopicNew( $oldWeb, $oldTopic, 1 );
   
   return $error;
}


# =========================
# Read a specific version of a topic
# view:	    $text= &TWiki::Store::readTopicVersion( $topic, "1.$rev" );
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
    my $tmp= $TWiki::revCoCmd;
    my $fileName = "$TWiki::dataDir/$theWeb/$theTopic.txt";
    $tmp =~ s/%FILENAME%/$fileName/;
    $tmp =~ s/%REVISION%/$theRev/;
    $tmp =~ /(.*)/;
    $tmp = $1;       # now safe, so untaint variable
    my $text = `$tmp`;
    _traceExec( $tmp, $text );

    return $text;
}

# =========================
sub readAttachmentVersion
{
   my ( $theWeb, $theTopic, $theAttachment, $theRev ) = @_;
   my $tmp = $TWiki::revCoCmd;
   my $fileName = getFileName( $theWeb, $theTopic, $theAttachment, ",v" ); 
   $tmp =~ s/%FILENAME%/$fileName/;
   $tmp =~ s/%REVISION%/$theRev/;
   $tmp =~ /(.*)/;
   $tmp = $1;       # now safe, so untaint variable
   my $text = `$tmp`;
   _traceExec( $tmp, $text );
   return $text;
}

# =========================
# Use meta information if available ...
sub getRevisionNumber
{
    my( $theWebName, $theTopic, $attachment ) = @_;
    my $ret = getRevisionNumberX( $theWebName, $theTopic, $attachment );
    TWiki::writeDebug( "Store: rev = $ret" );
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

    my $tmp= $TWiki::revHistCmd;
    my $fileName = getFileName( $theWebName, $theTopic, $attachment );
    
    my $rcsfilename = getFileName( $theWebName, $theTopic, $attachment, ",v" );
    if( ! -e $rcsfilename ) {
       return "";
    }

    $tmp =~ s/%FILENAME%/$rcsfilename/;
    $tmp =~ /(.*)/;
    my $cmd = $1;       # now safe, so untaint variable
    $tmp = `$cmd`;
    _traceExec( $cmd, $tmp );
    $tmp =~ /head: (.*?)\n/;
    if( ( $tmp ) && ( $1 ) ) {
        return $1;
    } else {
        return "";
    }
}


# =========================
# rdiff:            $text = &TWiki::Store::getRevisionDiff( $webName, $topic, "1.$r2", "1.$r1" );
sub getRevisionDiff
{
    my( $web, $topic, $rev1, $rev2 ) = @_;

    my $tmp= "";
    if ( $rev1 eq "1.1" && $rev2 eq "1.1" ) {
        my $text = _readVersionNoMeta( $web, $topic, 1.1);    # bug fix 19 Feb 1999
        $tmp = "1a1\n";
        foreach( split( /\n/, $text ) ) {
           $tmp = "$tmp> $_\n";
        }
    } else {
        $tmp= $TWiki::revDiffCmd;
        $tmp =~ s/%REVISION1%/$rev1/;
        $tmp =~ s/%REVISION2%/$rev2/;
        my $fileName = "$TWiki::dataDir/$TWiki::webName/$topic.txt";
        $fileName =~ s/$TWiki::securityFilter//go;
        $tmp =~ s/%FILENAME%/$fileName/;
        $tmp =~ /(.*)/;
        my $cmd = $1;       # now safe, so untaint variable
        $tmp = `$cmd`;
        _traceExec( $cmd, $tmp );
        # Avoid showing change in revision number!
        # I'm not too happy with this implementation, I think it may be better to filter before sending to diff command,
        # possibly using Algorithm::Diff from CPAN.
        $tmp =~ s/[0-9]+c[0-9]+\n[<>]\s*%META:TOPICINFO{[^}]*}%\s*\n---\n[<>]\s*%META:TOPICINFO{[^}]*}%\s*\n//go;
        $tmp =~ s/[<>]\s*%META:TOPICINFO{[^}]*}%\s*//go;
        
        TWiki::writeDebug( "and now $tmp" );
    }
    return "$tmp";
}


# =========================
# Call getRevisionInfoFromMeta for faster response for topics
sub getRevisionInfo
{
    my( $theWebName, $theTopic, $theRev, $changeToIsoDate, $attachment ) = @_;
    if( ! $theWebName ) {
        $theWebName = $TWiki::webName;
    }

    if( ! $theRev ) {
        # PTh 03 Nov 2000: comment out for performance
        ### $theRev = getRevisionNumber( $theTopic, $theWebName );
        $theRev = "";  # do a "rlog -r filename" to get top revision info
    }
    my $tmp= $TWiki::revInfoCmd;
    $theRev =~ s/$TWiki::securityFilter//go;
    $theRev =~ /(.*)/;
    $theRev = $1;       # now safe, so untaint variable
    $tmp =~ s/%REVISION%/$theRev/;
    my $fileName = getFileName( $theWebName, $theTopic, $attachment );
    $fileName =~ s/$TWiki::securityFilter//go;
    $fileName =~ /(.*)/;
    $fileName = $1;       # now safe, so untaint variable
    my $rcsFile = getFileName( $theWebName, $theTopic, $attachment, ",v" );
    $tmp =~ s/%FILENAME%/$rcsFile/;
    if ( -e $rcsFile ) {
       my $cmd = $tmp;
       $tmp = `$cmd`;
       _traceExec( $cmd, $tmp );
    } else {
       $tmp = "";
    }
    $tmp =~ /date: (.*?);  author: (.*?);.*\n(.*)\n/;
    my $date = $1;
    my $user = $2;
    my $comment = $3;
    $tmp =~ /revision 1.([0-9]*)/;
    my $rev = $1 || ""; #AS 25-5-01 added default value
    writeDebug( "rev = $rev" );
    
    return _tidyRevInfo( $theWebName, $theTopic, $date, $user, $rev, $comment, $changeToIsoDate );
}

sub _tidyRevInfo
{
    my( $web, $topic, $date, $user, $rev, $comment, $changeToIsoDate ) = @_;
    
    if( ! $user ) {
        writeDebug( "no user" );
        # repository file is missing or corrupt, use file timestamp
        $user = $TWiki::defaultUserName;
        my $fileName = getFileName( $web, $topic );
        $date = (stat "$fileName")[9] || 600000000;
        my @arr = gmtime( $date );
        # format to RCS date "2000.12.31.23.59.59"
        $date = sprintf( "%.4u.%.2u.%.2u.%.2u.%.2u.%.2u", $arr[5] + 1900,
                         $arr[4] + 1, $arr[3], $arr[2], $arr[1], $arr[0] );
        $rev = 1;
    }
    if( $changeToIsoDate ) {
        # change date to ISO format
        my $tmp = $date;
        # try "2000.12.31.23.59.59" format
        $tmp =~ /(.*?)\.(.*?)\.(.*?)\.(.*?)\.(.*?)\.[0-9]/;
        if( $5 ) {
            $date = "$3 $TWiki::isoMonth[$2-1] $1 - $4:$5";
        } else {
            # try "2000/12/31 23:59:59" format
            $tmp =~ /(.*?)\/(.*?)\/(.*?) (.*?):[0-9][0-9]$/;
            if( $4 ) {
                $date = "$3 $TWiki::isoMonth[$2-1] $1 - $4";
            }
        }
    }  
    
    return( $date, $user, $rev, $comment );
}


# =========================
sub topicIsLockedBy
{
    my( $theWeb, $theTopic ) = @_;

    # pragmatic approach: Warn user if somebody else pressed the
    # edit link within one hour

    my $lockFilename = "$TWiki::dataDir/$theWeb/$theTopic.lock";
    if( ( -e "$lockFilename" ) && ( $TWiki::editLockTime > 0 ) ) {
        my $tmp = readFile( $lockFilename );
        my( $lockUser, $lockTime ) = split( /\n/, $tmp );
        if( $lockUser ne $TWiki::userName ) {
            # time stamp of lock within one hour of current time?
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
    while( $args =~ s/\s*([^=]+)=\"([^"]*)\"//o ) {
        push @res, $1;
        push @res, $2;
    }
    
    return @res;
}


# ========================
sub metaAddTopicData
{
    my( $web, $topic, $rev, $meta, $forceDate ) = @_;
    
    my $time;
    if( $forceDate ) {
        $time = $forceDate;
    } else {
        $time = time();
    }
    
    my $user = $TWiki::userName;
        
    my @args = (
       "version" => "$rev",
       "date"    => "$time",
       "author"  => "$user",
       "format"  => $TWiki::formatVersion );
    $meta->put( "TOPICINFO", @args );
}


# =========================
sub savePreview
{
    my( $theWeb, $theTopic, $theText ) = @_;
    my $fileName = getFileName( $theWeb, $theTopic, "", ".tmp" );    
    saveFile( $fileName, $theText );   
}

# =========================
sub readRemovePreview
{
    my( $theWeb, $theTopic ) = @_;
    my $fileName = getFileName( $theWeb, $theTopic, "", ".tmp" );
    my $text = readFile( $fileName );
    unlink( $fileName );
    return $text;
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
    saveNew( $web, $topic, $text, $meta, $saveCmd, $attachment, $dontLogSave, $doUnlock, $dontNotify, $comment, $forceDate );
}

# =========================
sub saveAttachment
{
    my( $web, $topic, $text, $saveCmd, $attachment, $dontLogSave, $doUnlock, $dontNotify, $theComment, $theTmpFilename,
        $forceDate) = @_;

    # before save, create directories if they don't exist
    my $tempPath = getFileDir( $web, "", $attachment );
    if( ! -e "$tempPath" ) {
        umask( 0 );
        mkdir( $tempPath, 0777 );
    }
    $tempPath = getFileDir( $web, $topic, $attachment );
    if( ! -e "$tempPath" ) {
        umask( 0 );
        mkdir( $tempPath, 0777 );
    }

    # save uploaded file
    my $newFile = "$tempPath/$attachment";
    copy($theTmpFilename, $newFile) or warn "copy($theTmpFilename, $newFile) failed: $!";
    umask( 0027 );
    chmod( 0644, $newFile );
    
    # Update RCS
    my $error = save($web, $topic, $text, $saveCmd, $attachment, $dontLogSave, $doUnlock, 
		     $dontNotify, $theComment, $forceDate );
    return $error;
}


#==========================
sub isBinary
{
   my( $filename, $theWeb ) = @_;
   
   if( $filename =~ /$TWiki::attachAsciiPath/ ) {
      return "";
   } else {
      return "binary";
   }
}


sub save
{
    my( $web, $topic, $text, $saveCmd, $attachment, $dontLogSave, $doUnlock, $dontNotify, $theComment, $forceDate ) = @_;
    
    # FIXME get rid of this routine
    
    my $meta = TWiki::Meta->new();
    
    return saveNew( $web, $topic, $text, $meta, $saveCmd, $attachment, $dontLogSave, $doUnlock, $dontNotify, $theComment, $forceDate );
}


# ========================
sub _saveWithMeta
{
    my( $web, $topic, $text, $attachment, $doUnlock, $nextRev, $meta, $forceDate ) = @_;
    
    if( ! $attachment ) {
        my $name = getFileName( $web, $topic, $attachment );
        
        if( ! $nextRev ) {
            $nextRev = "1.1";
        }

        metaAddTopicData(  $web, $topic, $nextRev, $meta, $forceDate );
        $text = $meta->write( $text );
    
	# save file
	saveFile( $name, $text );

	# reset lock time, this is to prevent contention in case of a long edit session
       lockTopicNew( $web, $topic, $doUnlock );
    }

    return $text;
}



# =========================
# return non-null string if there is an (RCS) error.
sub saveNew
{
    my( $web, $topic, $text, $meta, $saveCmd, $attachment, $dontLogSave, $doUnlock, $dontNotify, $theComment, $forceDate ) = @_;
    my $name = getFileName( $web, $topic, $attachment );
    my $dir  = getFileDir( $web, $topic, $attachment, "" );
    my $time = time();
    my $tmp = "";
    my $rcsError = "";
    
    my $currentRev = getRevisionNumberX( $web, $topic );
    my $nextRev    = "";
    if( ! $currentRev ) {
        $nextRev = "1.1";
    }

    if( !$attachment ) {
        # RCS requires a newline for the last line,
        # so add newline if needed
        $text =~ s/([^\n\r])$/$1\n/os;
    }
    
    if( ! $theComment ) {
       $theComment = "none";
    }

    my $rcsFile = "";
    if( $attachment ) {
       $rcsFile = getFileName( $web, $topic, $attachment, ",v");
    }



    #### Normal Save
    if( ! $saveCmd ) {
        $saveCmd = "";

        # get time stamp of existing file
        my $mtime1 = 0;
        my $mtime2 = 0;
        if( -e $name ) {
            my( $tmp1,$tmp2,$tmp3,$tmp4,$tmp5,$tmp6,$tmp7,$tmp8,$tmp9,
                $tmp10,$tmp11,$tmp12,$tmp13 ) = stat $name;
            $mtime1 = $tmp10;
        }

        # how close time stamp of existing file to now?
        $mtime2 = time();
        if( abs( $mtime2 - $mtime1 ) < $TWiki::editLockTime ) {
            my $rev = getRevisionNumberX( $web, $topic, $attachment );
            my( $date, $user ) = getRevisionInfo( $web, $topic, $rev, "", $attachment );
            # same user?
            if( ( $TWiki::doKeepRevIfEditLock ) && ( $user eq $TWiki::userName ) && $rev ) {
                # replace last repository entry
                $saveCmd = "repRev";
                if( $attachment ) {
                   $saveCmd = ""; # cmd option not supported for attachments.
                }
            }
        }
        
        if( ! $nextRev ) {
            # If content hasn't changed we still get a new version, with revised META:TOPICINFO
            writeDebug( "currentRev = $currentRev" );
            $currentRev =~ /1\.([0-9]+)/;
            my $num = $1;
            $num++;
            $nextRev = "1.$num";
        }

        if( $saveCmd ne "repRev" ) {
            $text = _saveWithMeta( $web, $topic, $text, $attachment, $doUnlock, $nextRev, $meta, $forceDate );

            # If attachment and RCS file doesn't exist, initialise things
            if( $attachment ) {
               # Make sure directory for rcs history file exists
               my $rcsDir = getFileDir( $web, $topic, $attachment, ",v" );
               my $tempPath = "&TWiki::dataDir/$web";
               if( ! -e "$tempPath" ) {
                  umask( 0 );
                  mkdir( $tempPath, 0777 );
               }
               $tempPath = $rcsDir;
               if( ! -e "$tempPath" ) {
                  umask( 0 );
                  mkdir( $tempPath, 0777 );
               }
 
               if( ! -e $rcsFile && $TWiki::revInitBinaryCmd && isBinary( $attachment, $web ) ) {
                  $tmp = $TWiki::revInitBinaryCmd;
                  $tmp =~ s/%FILENAME%/$rcsFile/go;
                  $tmp =~ /(.*)/;
                  $tmp = "$1 2>&1 1>$TWiki::nullDev";       # safe, so untaint variable
                  $rcsError = `$tmp`;
                  _traceExec( $tmp, $rcsError );
                  if( $rcsError ) { # oops, stderr was not empty, return error
                     $rcsError = "$tmp\n$rcsError";
                     return $rcsError;
                  }
                  
                  # Sometimes (on Windows?) rcs file not formed, so check for it
                  if( ! -e $rcsFile ) {
                     return "Failed to create history file $rcsFile";
                  }
               }
            }

            $tmp = $TWiki::revCiCmd;
            if( $forceDate ) {
                $tmp = $TWiki::revCiDateCmd;
                my( $sec, $min, $hour, $mday, $mon, $year) = gmtime( $forceDate );
                $forceDate = sprintf( "%.4u/%.2u/%.2u %.2u:%.2u:%.2u", $year + 1900, $mon, $mday, $hour, $min, $sec );
                $tmp =~ s/%DATE%/$forceDate/o;
            }
            $tmp =~ s/%USERNAME%/$TWiki::userName/;
            $tmp =~ s/%FILENAME%/$name/;
            $tmp =~ s/%COMMENT%/$theComment/;
            $tmp =~ /(.*)/;
            $tmp = $1;       # safe, so untaint variable
            $tmp .= " 2>&1 1>$TWiki::nullDev";
            $rcsError = `$tmp`; # capture stderr  (S.Knutson)
            _traceExec( $tmp, $rcsError );
            $rcsError =~ s/^Warning\: missing newline.*//os; # forget warning
            if( $rcsError =~ /no lock set by/ ) {
                  # Try and break lock, setting new one and doing ci again
                  my $cmd = $TWiki::revBreakLockCmd;
                  $cmd =~ s/%FILENAME%/$name/go;
                  $cmd =~ /(.*)/;
                  $cmd = "$1 2>&1 1>$TWiki::nullDev";
                  my $out = `$cmd`;
                  _traceExec( $cmd, $out );
                  # Assume it worked, as not sure how to trap failure
                  $tmp= $TWiki::revCiCmd;
                  $rcsError = `$tmp`; # capture stderr  (S.Knutson)
                  _traceExec( $tmp, $rcsError );
                  $rcsError = "";
            }
            if( $rcsError ) { # oops, stderr was not empty, return error
                $rcsError = "$tmp\n$rcsError";
                return $rcsError;
            }

            if( ! $dontNotify ) {
                # update .changes
                my( $fdate, $fuser, $frev ) = getRevisionInfo( $web, $topic, "" );
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
        # fix topic by replacing last revision
        
        $nextRev = $currentRev;
        $text = _saveWithMeta( $web, $topic, $text, $attachment, $doUnlock, $nextRev, $meta );

        # update repository with same userName and date, but do not update .changes
        my $rev = getRevisionNumber( $web, $topic, $attachment );
        my( $date, $user ) = getRevisionInfo( $web, $topic, $rev, "", $attachment );
        if( $rev eq "1.1" ) {
            # initial revision, so delete repository file and start again
            unlink "$name,v";
        } else {
            # delete latest revision (unlock, delete revision, lock)
            $tmp= $TWiki::revUnlockCmd;
            $tmp =~ s/%FILENAME%/$name $rcsFile/go;
            $tmp =~ /(.*)/;
            $tmp = "$1 2>&1 1>$TWiki::nullDev";       # safe, so untaint variable
            $rcsError = `$tmp`; # capture stderr  (S.Knutson)
            _traceExec( $tmp, $rcsError );
            $rcsError =~ s/^Warning\: missing newline.*//os; # forget warning
            if( $rcsError ) {   # oops, stderr was not empty, return error
                $rcsError = "$tmp\n$rcsError";
                return $rcsError;
            }
            $tmp= $TWiki::revDelRevCmd;
            $tmp =~ s/%REVISION%/$rev/go;
            $tmp =~ s/%FILENAME%/$name $rcsFile/go;
            $tmp =~ /(.*)/;
            $tmp = "$1 2>&1 1>$TWiki::nullDev";       # safe, so untaint variable
            $rcsError = `$tmp`; # capture stderr  (S.Knutson)
            _traceExec( $tmp, $rcsError );
            $rcsError =~ s/^Warning\: missing newline.*//os; # forget warning
            if( $rcsError ) {   # oops, stderr was not empty, return error
                $rcsError = "$tmp\n$rcsError";
                return $rcsError;
            }
            $tmp= $TWiki::revLockCmd;
            $tmp =~ s/%REVISION%/$rev/go;
            $tmp =~ s/%FILENAME%/$name $rcsFile/go;
            $tmp =~ /(.*)/;
            $tmp = "$1 2>&1 1>$TWiki::nullDev";       # safe, so untaint variable
            $rcsError = `$tmp`; # capture stderr  (S.Knutson)
            _traceExec( $tmp, $rcsError );
            $rcsError =~ s/^Warning\: missing newline.*//os; # forget warning
            if( $rcsError ) {   # oops, stderr was not empty, return error
                $rcsError = "$tmp\n$rcsError";
                return $rcsError;
            }
        }
        $tmp = $TWiki::revCiDateCmd;
        $tmp =~ s/%DATE%/$date/;
        $tmp =~ s/%USERNAME%/$user/;
        $tmp =~ s/%FILENAME%/$name $rcsFile/;
        $tmp =~ /(.*)/;
        $tmp = "$1 2>&1 1>$TWiki::nullDev";       # safe, so untaint variable
        $rcsError = `$tmp`; # capture stderr  (S.Knutson)
        _traceExec( $tmp, $rcsError );
        $rcsError =~ s/^Warning\: missing newline.*//os; # forget warning
        if( $rcsError ) {   # oops, stderr was not empty, return error
            $rcsError = "$tmp\n$rcsError";
            return $rcsError;
        }

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
        $tmp= $TWiki::revUnlockCmd;
        $tmp =~ s/%FILENAME%/$name $rcsFile/go;
        $tmp =~ /(.*)/;
        $tmp = "$1 2>&1 1>$TWiki::nullDev";       # safe, so untaint variable
        $rcsError = `$tmp`; # capture stderr  (S.Knutson)
        _traceExec( $tmp, $rcsError );
        $rcsError =~ s/^Warning\: missing newline.*//os; # forget warning
        if( $rcsError ) {   # oops, stderr was not empty, return error
            $rcsError = "$tmp\n$rcsError";
            return $rcsError;
        }
        $tmp= $TWiki::revDelRevCmd;
        $tmp =~ s/%REVISION%/$rev/go;
        $tmp =~ s/%FILENAME%/$name $rcsFile/go;
        $tmp =~ /(.*)/;
        $tmp = "$1 2>&1 1>$TWiki::nullDev";     # safe, so untaint variable
        $rcsError = `$tmp`; # capture stderr  (S.Knutson)
        _traceExec( $tmp, $rcsError );
        $rcsError =~ s/^Warning\: missing newline.*//os; # forget warning
        if( $rcsError ) {   # oops, stderr was not empty, return error
            $rcsError = "$tmp\n$rcsError";
            return $rcsError;
        }
        $tmp= $TWiki::revLockCmd;
        $tmp =~ s/%REVISION%/$rev/go;
        $tmp =~ s/%FILENAME%/$name $rcsFile/go;
        $tmp =~ /(.*)/;
        $tmp = "$1 2>&1 1>$TWiki::nullDev";       # safe, so untaint variable
        $rcsError = `$tmp`; # capture stderr  (S.Knutson)
        _traceExec( $tmp, $rcsError );
        $rcsError =~ s/^Warning\: missing newline.*//os; # forget warning
        if( $rcsError ) {   # oops, stderr was not empty, return error
            $rcsError = "$tmp\n$rcsError";
            return $rcsError;
        }

        # restore last topic from repository
        $rev = getRevisionNumber( $web, $topic );
        $tmp = _readVersionNoMeta( $web, $topic, $rev );
        saveFile( $name, $tmp );
        lockTopic( $topic, $doUnlock );

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
    
    open( FILE, ">$name" ) or warn "Can't create file $name\n";
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
sub lockTopicNew
{
    my( $web, $name, $doUnlock ) = @_;

    my $lockFilename = getFileName( $web, $name, "", ".lock" );
    if( $doUnlock ) {
        unlink "$lockFilename";
    } else {
        my $lockTime = time();
        saveFile( $lockFilename, "$TWiki::userName\n$lockTime" );
    }
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
    my $lockTime = "";
    my $systemTime = time();
    foreach $file ( @fileList ) {
        $pathFile = "$webDir/$file";
        $pathFile =~ /(.*)/;
        $pathFile = $1;       # untaint file
        ( $lockUser, $lockTime ) = split( /\n/, readFile( "$pathFile" ) );
        if( ! $lockTime ) { $lockTime = ""; }

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
    my( $theWeb, $theName ) = @_;
    return -e "$TWiki::dataDir/$theWeb/$theName.txt";
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
       ( $date, $author, $rev ) = _tidyRevInfo( $web, $topic, $date, $author, $rev, "", $changeToIsoDate );
    }
    
    writeDebug( "rev = $rev" );
    
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

# ======================
# Just read the meta data at the top of the topic
sub readTopMeta
{
    my( $theWeb, $theTopic ) = @_;
    
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
sub readTopic
{
    my( $theWeb, $theTopic ) = @_;
    
    my $fullText = readTopicRaw( $theWeb, $theTopic );
    
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
    my( $theWeb, $theTopic, $theVersion ) = @_;
    my $text = "";
    if( ! $theVersion ) {
        $text = &readFile( "$TWiki::dataDir/$theWeb/$theTopic.txt" );
    } else {
        $text = _readVersionNoMeta( $theWeb, $theTopic, $theVersion);
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
