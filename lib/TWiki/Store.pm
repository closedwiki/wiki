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
# - Customize variables in wikicfg.pm when installing TWiki.
# - Optionally change wikicfg.pm for custom extensions of rendering rules.
# - Files wiki[a-z]+.pm are included by wiki.pm
# - Upgrading TWiki is easy as long as you do not customize wiki.pm.
# - Check web server error logs for errors, i.e. % tail /var/log/httpd/error_log
#
# 20000917 - NicholasLee : Split file/storage related functions from wiki.pm
#

package TWiki::Store;

use File::Copy;

use strict;

##use vars qw(
##        $revCoCmd $revCiCmd $revCiDateCmd $revHistCmd $revInfoCmd 
##        $revDiffCmd $revDelRevCmd $revUnlockCmd $revLockCmd
##);


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
sub getFileName
{
   my( $web, $topic, $attachment, $extension ) = @_;

   if( ! $attachment ) {
      $attachment = "";
   }
   
 
   # FIXME this is too messy and $extension should be replaced with type e.g. DATA,
   # HISTORY, LOCK etc
   my $file = "";
   if( ! $attachment ) {
      if( ! $extension ) {
         $extension = ".txt";
      } else {
         if( $extension eq ",v" ) {
            $extension = ".txt$extension";
         }
      }
      $file = "$TWiki::dataDir/$web/$topic$extension";

   } else {
      if ( $extension eq ",v" ) {
         $file = "$TWiki::pubDir/$web/$topic/$attachment$extension";
      } else {
         $file = "$TWiki::pubDir/$web/$topic/$attachment$extension";
      }
   }

   ## !!! clean up an ..s etc in $web and $topic
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
      $dir = "$TWiki::dataDir/$web";
   } else {
      my $suffix = $topic;
      if ( $topic ) {
         $suffix = "/$suffix";
      }
      if ( $extension ) {
         $dir = "$TWiki::pubDir/$web$suffix";
      } else { 
         $dir = "$TWiki::pubDir/$web$suffix";
      }
   }

   ## FIXME clean up an ..s etc in $web and $topic
   $dir =~ /(.*)/;
   $dir = $1; # untaint
   
   return $dir;
}


# =========================
# List Webs - JohnTalintyre 26 Feb 2001
# Sub webs returned in format Top.Sub
sub listWebs
{
   my $baseDir = &TWiki::getDataDir();
   # Directories within this
   opendir( DIR, $baseDir ) || warn "can't opendir $baseDir: $!";
   my @dirs = grep { /^[^.]/ && -d "$baseDir/$_" } readdir( DIR );
   closedir DIR;
   return @dirs;
}


# =========================
# Get rid a topic and its attachments completely
# Intended for TEST purposes.
# Use with GREAT CARE as file will be gone, including RCS history
sub erase
{
   my( $web, $topic ) = @_;

   my $file = getFileName( $web, $topic );
   my $rcsFile = "$file,v";

   my @files = ( $file, $rcsFile );
   unlink( @files );
   
   # Delete all attachments and the attachment directory
   my $attDir = "$TWiki::pubDir/$web/$topic";
   if( -e $attDir ) {
       opendir( DIR, $attDir );
       my @attachments = readdir( DIR );
       closedir( DIR );
       my $attachment;
       foreach $attachment ( @attachments ) {
          if( $attachment !~ /^\./ ) {
             unlink( "$attDir/$attachment" ) || warn "Couldn't remove $attDir/$attachment";
             if( $attachment !~ /,v$/ ) {
                writeLog( "erase", "$web.$topic.$attachment" );
             }
          }
       }
       
       rmdir( "$attDir" ) || warn "Couldn't remove directory $attDir";
   }
   
   # Delete any attachment history
   my $attDir = getFileDir( $web, $topic, 1, ",v" );
   if ( -e $attDir ) {
       opendir( DIR, $attDir );
       my @attachments = readdir( DIR );
       closedir( DIR );
       my $attachment;
       foreach $attachment ( @attachments ) {
          if( $attachment !~ /^\./ ) {
             unlink( "$attDir/$attachment" ) || warn "Couldn't remove $attDir/$attachment";
             if( $attachment !~ /,v$/ ) {
                writeLog( "erase", "$web.$topic.$attachment" );
             }
          }
       }
    
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
    if( ! move( $oldAttachmentRcs, $newAttachmentRcs ) ) {
        $error .= "Failed to move attachment history; $what ($!)";
        # Don't return here as attachment file has already been moved
    }

    # Remove file attachment from old topic
    my $text = readWebTopic( $oldWeb, $oldTopic );
    my ( $file, $fileVersion, $filePath, $fileSize, $fileDate, $fileUser, 
             $fileComment, $fileAttr ) = TWiki::Attach::extractArgsForFile( $text, $theAttachment );
    TWiki::Attach::removeFile( $text, $theAttachment );
    $error .= save( $oldWeb, $oldTopic, $text, "", "", "", "doUnlock", "dont notify", "" ); 
    
    # Remove lock file
    lockTopicNew( $oldWeb, $oldTopic, 1 );
    
    # Add file attachment to new topic
    $text = readWebTopic( $newWeb, $newTopic );
    my $hideFile = "";
    # FIXME doesn't deal with delete flag
    my $hideFile = $fileAttr;
    # FIXME concentrate TWikiAttachment code in one place
    my( $before, $atext, $after ) = split( /<!--TWikiAttachment-->/, $text );
    if( ! $before ) { $before = ""; }
    if( ! $atext  ) { $atext  = ""; }
    $atext = TWiki::Attach::updateAttachment( 
                    $atext, $fileVersion, $theAttachment, $filePath, $fileSize,
                    $fileDate, $fileUser, $fileComment, $hideFile );
    $text = "$before<!--TWikiAttachment-->$atext<!--TWikiAttachment-->";
    
    $error .= save( $newWeb, $newTopic, $text, "", "", "", "doUnlock", "dont notify", "" ); 
    # Remove lock file
    lockTopicNew( $newWeb, $newTopic, 1 );
    
    writeLog( "move", "$oldWeb.$oldTopic", "Attachment $theAttachment moved to $newWeb.$newTopic" );

    return $error;
}


# =========================
# Rename a Web, allow for transfer between Webs
sub renameTopic
{
   my( $oldWeb, $oldTopic, $newWeb, $newTopic ) = @_;
   
   my $error = "";

   #!!!check lock
   
   # Change data file
   my $from = getFileName( $oldWeb, $oldTopic );
   my $to =  getFileName( $newWeb, $newTopic );
   if( ! move( $from, $to ) ) {
       $error .= "data file move failed.  ";
   }

   # Remove lock file
   lockTopicNew( $oldWeb, $oldTopic, 1 );
   
   # Change data file history
   if( ! move(
     getFileName( $oldWeb, $oldTopic, "", ",v" ),
     getFileName( $newWeb, $newTopic, "", ",v" )
   ) ) {
      $error .= "history file move failed.  ";
   }
   
   # Rename the attachment directory if there is one
   my $oldAttachDir = getFileDir( $oldWeb, $oldTopic, 1, "");
   my $newAttachDir = getFileDir( $newWeb, $newTopic, 1, "");
   if( -e $oldAttachDir ) {
      if( ! move( $oldAttachDir, $newAttachDir ) ) {
          $error .= "attach move failed";
      }
      # FIXME can't deal with attach history being in different place to attachments
   }
   
   # Log rename
   if( $TWiki::doLogRename ) {
      writeLog( "rename", "$oldWeb.$oldTopic", "moved to $newWeb.$newTopic" );
   }
   
   return $error;
}


# =========================
# Read a specific version of a topic
# view:	    $text= &TWiki::Store::readVersion( $topic, "1.$rev" );
sub readVersion
{
    my( $theTopic, $theRev ) = @_;
    my $tmp= $TWiki::revCoCmd;
    my $fileName = "$TWiki::dataDir/$TWiki::webName/$theTopic.txt";
    $tmp =~ s/%FILENAME%/$fileName/;
    $tmp =~ s/%REVISION%/$theRev/;
    $tmp =~ /(.*)/;
    $tmp = $1;       # now safe, so untaint variable
    return `$tmp`;
}

# =========================
# FIXME probably doesn't work yet
sub readAttachmentVersion
{
   my ( $theWeb, $theTopic, $theAttachment, $theRev ) = @_;
   my $tmp = $TWiki::revCoCmd;
   my $fileName = getFileName( $theWeb, $theTopic, $theAttachment, ",v" ); 
   $tmp =~ s/%FILENAME%/$fileName/;
   $tmp =~ s/%REVISION%/$theRev/;
   $tmp =~ /(.*)/;
   $tmp = $1;       # now safe, so untaint variable
   ##TWiki::writeDebug( $tmp );
   return `$tmp`;
}


# =========================
# rdiff:	$maxrev = &TWiki::Store::getRevisionNumber( $topic );
# view:	$maxrev = &TWiki::Store::getRevisionNumber( $topic );
# FIXME get rid of this
sub getRevisionNumber
{
    my( $theTopic, $theWebName ) = @_;
    if( ! $theWebName ) {
        $theWebName = $TWiki::webName;
    }
    return getRevisionNumberNew( $theWebName, $theTopic, "" );
}

# =========================
# FIXME get rid of this
sub getRevisionNumberNew
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
# Latest reviewion number
# FIXME rename to getRevisionNumber
# FIXME pick up errors, but what to do with them as return value already used?
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
    
    ##&TWiki::writeDebug( "getRevisionNumberNew: fileName: $fileName" );
    my $rcsfilename = getFileName( $theWebName, $theTopic, $attachment, ",v" );
    ##&TWiki::writeDebug( "getRevisionNumberNew: rcsfilename: $rcsfilename" );
    if( ! -e $rcsfilename ) {
       return "";
    }

    $tmp =~ s/%FILENAME%/$rcsfilename/;
    $tmp =~ /(.*)/;
    $tmp = $1;       # now safe, so untaint variable
    $tmp = `$tmp`;
    $tmp =~ /head: (.*?)\n/;
    if( ( $tmp ) && ( $1 ) ) {
        return $1;
    } else {
        return "";
    }
}


# =========================
# rdiff:            $text = &TWiki::Store::getRevisionDiff( $topic, "1.$r2", "1.$r1" );
sub getRevisionDiff
{
    my( $topic, $rev1, $rev2 ) = @_;

    my $tmp= "";
    if ( $rev1 eq "1.1" && $rev2 eq "1.1" ) {
        my $text = readVersion($topic, 1.1);    # bug fix 19 Feb 1999
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
        $tmp = $1;       # now safe, so untaint variable
        $tmp = `$tmp`;
    }
    return "$tmp";
}


# =========================
# rdiff:         my( $date, $user ) = &TWiki::Store::getRevisionInfo( $topic, "1.$rev", 1 );
# view:          my( $date, $user ) = &TWiki::Store::getRevisionInfo( $topic, "1.$rev", 1 );
# wikisearch.pm: my ( $revdate, $revuser, $revnum ) = &TWiki::Store::getRevisionInfo( $filename, "", 1, $thisWebName );
# FIXME get rid of this
sub getRevisionInfo
{
    my( $theTopic, $theRev, $changeToIsoDate, $theWebName) = @_;
    return getRevisionInfoNew($theTopic, $theRev, $changeToIsoDate, $theWebName, "");
}


# =========================
# FIXME rename to getRevisionInfo
sub getRevisionInfoNew
{
    my( $theTopic, $theRev, $changeToIsoDate, $theWebName, $attachment ) = @_;
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
    # FIXME - do elsewhere for rlog call.
    TWiki::writeDebug( "Store: revInfo; rcsfile = $rcsFile" );
    TWiki::writeDebug( "Store: revcmd = $tmp" );
    if ( -e $rcsFile ) {
       $tmp = `$tmp`;
    } else {
       $tmp = "";
    }
    $tmp =~ /date: (.*?);  author: (.*?);.*\n(.*)\n/;
    my $date = $1;
    my $user = $2;
    my $comment = $3;
    ## TWiki::writeDebug( "Store: rlog output = \n$tmp\n  ########################### comment=$comment" );
    $tmp =~ /revision 1.([0-9]*)/;
    my $rev = $1;
    if( ! $user ) {
        # repository file is missing or corrupt, use file timestamp
        $user = $TWiki::defaultUserName;
        $date = (stat "$fileName")[9] || 600000000;
        my @arr = gmtime( $date );
        # format to RCS date "2000.12.31.23.59.59"
        $date = sprintf( "%.4u.%.2u.%.2u.%.2u.%.2u.%.2u", $arr[5] + 1900,
                         $arr[4] + 1, $arr[3], $arr[2], $arr[1], $arr[0] );
        $rev = 1;
    }
    if( $changeToIsoDate ) {
        # change date to ISO format
        $tmp = $date;
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
    return ( $date, $user, $rev, $comment );
}


# =========================
sub topicIsLockedBy
{
    my( $theWeb, $theTopic ) = @_;

    # pragmatic approach: Warn user if somebody else pressed the
    # edit link within one hour

    my $lockFilename = "$TWiki::dataDir/$theWeb/$theTopic.lock"; # FIXME use file generation method
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


# =========================
sub saveTopic
{
    my( $topic, $text, $saveCmd, $doUnlock, $dontNotify, $dontLogSave ) = @_;
#   my( $topic, $text, $saveCmd, $doNotLogChanges, $doUnlock ) = @_;
    my $attachment = "";
    save( $TWiki::webName, $topic, $text, $saveCmd, $attachment, $dontLogSave, $doUnlock, $dontNotify );
}

# =========================
sub saveAttachment
{
    my( $web, $topic, $text, $saveCmd, $attachment, $dontLogSave, $doUnlock, $dontNotify, $theComment, $theTmpFilename ) = @_;

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
    
    # Update RCS if required
    # FIXME make optional
    my $error = save($web, $topic, $text, $saveCmd, $attachment, $dontLogSave, $doUnlock, 
		     $dontNotify, $theComment );
    return $error;
}


#==========================
# FIXME use properties
sub isBinary
{
   my( $filename, $theWeb ) = @_;
   
   if( $filename =~ /$TWiki::attachAsciiPath/ ) {
      return "";
   } else {
      return "binary";
   }
}


# =========================
# return non-null string if there is an (RCS) error.
sub save
{
    my( $web, $topic, $text, $saveCmd, $attachment, $dontLogSave, $doUnlock, $dontNotify, $theComment ) = @_;
    my $name = getFileName( $web, $topic, $attachment );
    my $dir  = getFileDir( $web, $topic, $attachment, "" );
    my $time = time();
    my $tmp = "";
    my $rcsError = "";

    if( $attachment ) {
       $dontLogSave = 1; # FIXME
    } else {
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

        if( ! $attachment ) {
            # save file
            ##&TWiki::writeDebug( "save: web: $web, name: $name, topic: $topic" );
            saveFile( $name, $text );

            # reset lock time, this is to prevent contention in case of a long edit session
           lockTopicNew( $web, $topic, $doUnlock );
        }

        # time stamp of existing file within one hour of old one?
        my( $tmp1,$tmp2,$tmp3,$tmp4,$tmp5,$tmp6,$tmp7,$tmp8,$tmp9,
            $tmp10,$tmp11,$tmp12,$tmp13 ) = stat $name;
        $mtime2 = $tmp10;
        if( abs( $mtime2 - $mtime1 ) < $TWiki::editLockTime ) {
            my $rev = getRevisionNumberNew( $web, $topic, $attachment );
            my( $date, $user ) = getRevisionInfoNew( $topic, $rev, "", $web, $attachment );
            # same user?
            if( ( $TWiki::doKeepRevIfEditLock ) && ( $user eq $TWiki::userName ) ) {
                # replace last repository entry
                $saveCmd = "repRev";
                #!!!
                if( $attachment ) {
                   $saveCmd = "";
                }
            }
        }

        if( $saveCmd ne "repRev" ) {
            # If attachment and RCS file doesn't exist, initialise
            if( $attachment ) {
               # Make sure directory for rcs history file exists
               my $rcsDir = getFileDir( $web, $topic, $attachment, ",v" );
               my $tempPath = "&TWiki::dataDir/$web"; # FIXME move up to getDirName
               if( ! -e "$tempPath" ) {
                  umask( 0 );
                  mkdir( $tempPath, 0777 );
               }
               $tempPath = $rcsDir;
               if( ! -e "$tempPath" ) {
                  umask( 0 );
                  mkdir( $tempPath, 0777 );
               }
 
               if( ! -e $rcsFile && $TWiki::revInitBinaryCmd ) {
                  $tmp = $TWiki::revInitBinaryCmd;
                  $tmp =~ s/%FILENAME%/$rcsFile/go;
                  if( ! isBinary( $attachment, $web ) ) {
                      # FIXME naff
                      $tmp =~ s/-kb //go;
                  }
                  $tmp =~ /(.*)/;
                  $tmp = "$1 2>&1 1>$TWiki::nullDev";       # safe, so untaint variable
                  ##&TWiki::writeDebug( "save: Init RCS file, $tmp" );
                  $rcsError = `$tmp`;
                  TWiki::writeDebug( "Store::save initci $tmp\n   res = $rcsError");
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

            # update repository
            $tmp= $TWiki::revCiCmd;
            $tmp =~ s/%USERNAME%/$TWiki::userName/;
            # FIXME put back $rcsFile if history for attachments moves to data area
            $tmp =~ s/%FILENAME%/$name/;
            $tmp =~ s/%COMMENT%/$theComment/;
            $tmp =~ /(.*)/;
            $tmp = $1;       # safe, so untaint variable
            $tmp .= " 2>&1 1>$TWiki::nullDev";
            TWiki::writeDebug( "Store: ci to rcs; $tmp" );
            if( -e $name ) {
               TWiki::writeDebug( "Store: source file $name exists" );
            }
            $rcsError = `$tmp`; # capture stderr  (S.Knutson)
            TWiki::writeDebug( "Store: rcsError post ci = $rcsError" );
            $rcsError =~ s/^Warning\: missing newline.*//os; # forget warning
            if( $rcsError ) { # oops, stderr was not empty, return error
                $rcsError = "$tmp\n$rcsError";
                return $rcsError;
            }

            if( ! $dontNotify ) {
                # update .changes
                my( $fdate, $fuser, $frev ) = getRevisionInfo( $topic, "" );
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

        # save file
        saveFile( $name, $text );
        lockTopic( $topic, $doUnlock );

        # update repository with same userName and date, but do not update .changes
        my $rev = getRevisionNumberNew( $web, $topic, $attachment );
        my( $date, $user ) = getRevisionInfoNew( $topic, $rev, "", $web, $attachment );
        if( $rev eq "1.1" ) {
            # initial revision, so delete repository file and start again
            unlink "$name,v";
        } else {
            # delete latest revision (unlock, delete revision, lock)
            $tmp= $TWiki::revUnlockCmd;
            $tmp =~ s/%FILENAME%/$name $rcsFile/go;
            $tmp =~ /(.*)/;
            $tmp = $1;       # safe, so untaint variable
            $rcsError = `$tmp 2>&1 1>$TWiki::nullDev`; # capture stderr  (S.Knutson)
            $rcsError =~ s/^Warning\: missing newline.*//os; # forget warning
            if( $rcsError ) {   # oops, stderr was not empty, return error
                $rcsError = "$tmp\n$rcsError";
                return $rcsError;
            }
            $tmp= $TWiki::revDelRevCmd;
            $tmp =~ s/%REVISION%/$rev/go;
            $tmp =~ s/%FILENAME%/$name $rcsFile/go;
            $tmp =~ /(.*)/;
            $tmp = $1;       # safe, so untaint variable
            $rcsError = `$tmp 2>&1 1>$TWiki::nullDev`; # capture stderr  (S.Knutson)
            $rcsError =~ s/^Warning\: missing newline.*//os; # forget warning
            if( $rcsError ) {   # oops, stderr was not empty, return error
                $rcsError = "$tmp\n$rcsError";
                return $rcsError;
            }
            $tmp= $TWiki::revLockCmd;
            $tmp =~ s/%REVISION%/$rev/go;
            $tmp =~ s/%FILENAME%/$name $rcsFile/go;
            $tmp =~ /(.*)/;
            $tmp = $1;       # safe, so untaint variable
            $rcsError = `$tmp 2>&1 1>$TWiki::nullDev`; # capture stderr  (S.Knutson)
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
        $tmp = $1;       # safe, so untaint variable
        $rcsError = `$tmp 2>&1 1>$TWiki::nullDev`; # capture stderr  (S.Knutson)
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
        my $rev = getRevisionNumber( $topic );
        if( $rev eq "1.1" ) {
            # can't delete initial revision
            return;
        }
        $tmp= $TWiki::revUnlockCmd;
        $tmp =~ s/%FILENAME%/$name $rcsFile/go;
        $tmp =~ /(.*)/;
        $tmp = $1;       # safe, so untaint variable
        $rcsError = `$tmp 2>&1 1>$TWiki::nullDev`; # capture stderr  (S.Knutson)
        $rcsError =~ s/^Warning\: missing newline.*//os; # forget warning
        if( $rcsError ) {   # oops, stderr was not empty, return error
            $rcsError = "$tmp\n$rcsError";
            return $rcsError;
        }
        $tmp= $TWiki::revDelRevCmd;
        $tmp =~ s/%REVISION%/$rev/go;
        $tmp =~ s/%FILENAME%/$name $rcsFile/go;
        $tmp =~ /(.*)/;
        $tmp = $1;       # safe, so untaint variable
        $rcsError = `$tmp 2>&1 1>$TWiki::nullDev`; # capture stderr  (S.Knutson)
        $rcsError =~ s/^Warning\: missing newline.*//os; # forget warning
        if( $rcsError ) {   # oops, stderr was not empty, return error
            $rcsError = "$tmp\n$rcsError";
            return $rcsError;
        }
        $tmp= $TWiki::revLockCmd;
        $tmp =~ s/%REVISION%/$rev/go;
        $tmp =~ s/%FILENAME%/$name $rcsFile/go;
        $tmp =~ /(.*)/;
        $tmp = $1;       # safe, so untaint variable
        $rcsError = `$tmp 2>&1 1>$TWiki::nullDev`; # capture stderr  (S.Knutson)
        $rcsError =~ s/^Warning\: missing newline.*//os; # forget warning
        if( $rcsError ) {   # oops, stderr was not empty, return error
            $rcsError = "$tmp\n$rcsError";
            return $rcsError;
        }

        # restore last topic from repository
        $rev = getRevisionNumber( $topic );
        $tmp = readVersion( $topic, $rev );
        saveFile( $name, $tmp );
        lockTopic( $topic, $doUnlock );

        # delete entry in .changes : To Do !

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
sub readTopic
{
    my( $theName ) = @_;
    return &readFile( "$TWiki::dataDir/$TWiki::webName/$theName.txt" );
}

# =========================
sub readWebTopic
{
    my( $theWeb, $theName ) = @_;
    return &readFile( "$TWiki::dataDir/$theWeb/$theName.txt" );
}

# =========================
sub readTemplate
{
    my( $theName, $theTopic, $theSkin ) = @_;
    $theTopic = "" unless $theTopic; # prevent 'uninitialized value' ...
    $theSkin  = "" unless $theSkin;  #   ... warnings

    # CrisBailiff, PeterThoeny 13 Jun 2000: Add security
    $theName =~ s/$TWiki::securityFilter//go;    # zap anything suspicious
    $theName =~ s/\.+/\./g;                      # Filter out ".." from filename
    $theTopic =~ s/$TWiki::securityFilter//go;   # zap anything suspicious
    $theTopic =~ s/\.+/\./g;                     # Filter out ".." from filename
    $theSkin =~ s/$TWiki::securityFilter//go;    # zap anything suspicious
    $theSkin =~ s/\.+/\./g;                      # Filter out ".." from filename

    my $tmplFile = "";

    # search first in twiki/templates/Web dir
    # for file script(.topic)(.skin).tmpl
    my $tmplDir = "$TWiki::templateDir/$TWiki::webName";
    if( opendir( DIR, $tmplDir ) ) {
        # for performance use readdir, not a row of ( -e file )
        my @filelist = grep /^$theName\..*tmpl$/, readdir DIR;
        closedir DIR;
        $tmplFile = "$theName.$theTopic.tmpl";
        if( ! grep { /^$tmplFile$/ } @filelist ) {
            $tmplFile = "$theName.$theSkin.tmpl";
            if( ! grep { /^$tmplFile$/ } @filelist ) {
                $tmplFile = "$theName.$theTopic.$theSkin.tmpl";
                if( ! grep { /^$tmplFile$/ } @filelist ) {
                    $tmplFile = "$theName.tmpl";
                    if( ! grep { /^$tmplFile$/ } @filelist ) {
                        $tmplFile = "";
                    }
                }
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
        $tmplFile = "$theName.$theTopic.tmpl";
        if( ! grep { /^$tmplFile$/ } @filelist ) {
            $tmplFile = "$theName.$theSkin.tmpl";
            if( ! grep { /^$tmplFile$/ } @filelist ) {
                $tmplFile = "$theName.$theTopic.$theSkin.tmpl";
                if( ! grep { /^$tmplFile$/ } @filelist ) {
                    $tmplFile = "$theName.tmpl";
                    if( ! grep { /^$tmplFile$/ } @filelist ) {
                        $tmplFile = "";
                    }
                }
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
