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
#

package TWiki::Store;

use File::Copy;

use strict;

##use vars qw(
##        $revCoCmd $revCiCmd $revCiDateCmd $revHistCmd $revInfoCmd 
##        $revDiffCmd $revDelRevCmd $revUnlockCmd $revLockCmd
##);

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

   # Shouldn't really need to untaint here - done to be sure
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
   $attDir = getFileDir( $web, $topic, 1, ",v" );
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
    if( -e $oldAttachmentRcs ) {
        if( ! move( $oldAttachmentRcs, $newAttachmentRcs ) ) {
            $error .= "Failed to move attachment history; $what ($!)";
            # Don't return here as attachment file has already been moved
        }
    }

    # Remove file attachment from old topic
    my( $text, @meta ) = readWebTopicNew( $oldWeb, $oldTopic );
    my @ident = ( "name" => $theAttachment );
    my $oldargsr;
    ( $oldargsr, @meta ) = metaExtract( "FILEATTACHMENT", \@ident, "remove", @meta );
    my @oldargs = @$oldargsr;
    $error .= saveNew( $oldWeb, $oldTopic, $text, \@meta, "", "", "", "doUnlock", "dont notify", "" ); 
    
    # Remove lock file
    lockTopicNew( $oldWeb, $oldTopic, 1 );
    
    # Add file attachment to new topic
    ( $text, @meta ) = readWebTopicNew( $newWeb, $newTopic );

    @meta = metaUpdate( "FILEATTACHMENT", \@oldargs, "name", @meta );    
    
    $error .= saveNew( $newWeb, $newTopic, $text, \@meta, "", "", "", "doUnlock", "dont notify", "" ); 
    # Remove lock file
    lockTopicNew( $newWeb, $newTopic, 1 );
    
    writeLog( "move", "$oldWeb.$oldTopic", "Attachment $theAttachment moved to $newWeb.$newTopic" );

    return $error;
}

# =========================
sub changeRefTo
{
   my( $text, $oldWeb, $oldTopic ) = @_;
   my $preTopic = "^\|[\\*\\s][\\(\\-\\*\\s]*";
   my $postTopic = "$\|[_\\*<\\s]";

   # Get list of topics in $oldWeb, replace local refs topic, with full web.topic
   my @topics = getTopicNames( $oldWeb );
   foreach my $topic ( @topics ) {
       if( $topic ne $oldTopic ) {
           $text =~ s/($preTopic)\Q$topic\E($postTopic)/$1$oldWeb.$topic$2/gm;
       }
   }
   
   return $text;
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
      my $user = &TWiki::getWikiUserTopic();
      my @args = (
         "from" => "$oldWeb.$oldTopic",
         "to"   => "$newWeb.$newTopic",
         "date" => "$time",
         "by"   => "$user" );
      my( $text, @meta ) = readWebTopicNew( $newWeb, $newTopic );
      @meta = metaUpdate( "TOPICMOVED", \@args, "", @meta );
      if( ( $oldWeb ne $newWeb ) && $doChangeRefTo ) {
         $text = changeRefTo( $text, $oldWeb, $oldTopic );
      }
      saveNew( $newWeb, $newTopic, $text, \@meta, "", "", "", "unlock" );
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
# view:	    $text= &TWiki::Store::readVersion( $topic, "1.$rev" );
sub readVersion
{
    my( $theWeb, $theTopic, $theRev ) = @_;
    my $text = _readVersionNoMeta( $theWeb, $theTopic, $theRev );
    my @meta = ();
   
    ($text, @meta) = _extractMetaData( $text );
        
    return( $text, @meta );
}

# =========================
# Read a specific version of a topic
# view:     $text= &TWiki::Store::readVersion( $topic, "1.$rev" );
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
# rdiff:            $text = &TWiki::Store::getRevisionDiff( $topic, "1.$r2", "1.$r1" );
sub getRevisionDiff
{
    my( $topic, $rev1, $rev2 ) = @_;

    my $tmp= "";
    if ( $rev1 eq "1.1" && $rev2 eq "1.1" ) {
        my( $text, @meta ) = readVersion($topic, 1.1);    # bug fix 19 Feb 1999
        $text = TWiki::renderMetaData( $TWiki::webName, $topic, \@meta );
        $tmp = "1a1\n";
        foreach( split( /\n/, $text ) ) {
           $tmp = "$tmp> $_\n";
        }
    } else {
        # FIXME - this will not look very good as meta data not rendered, mind you it's relatively informative
        # Best course is probably to filter output and pass to diff command - at least to cut out some/all of TOPICINFO stuff
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
    my $rev = $1;
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


# ============================
# Replace all of a meta data item
# e.g. 
# @args = ( "author" => "JohnTalintyre" );
# metaUpdate( "FILEATTACHMENT", \@args, "name", @meta);
# If ! $identifierKey then existing entry for this tag replaced i.e. for single entry macro such as META:TOPIC
sub metaUpdate
{
    my( $metaDataType, $args, $identifierKey, @meta ) = @_;
    
    my @argsList = @$args;
    my $identifier = "";
    
    my $metaDataArgs = "";
    my $sep = "";
    while( @argsList ) {
       my $key = shift @argsList;
       my $value = shift @argsList;
       if ( $identifierKey && $identifierKey eq $key ) {
           $identifier = "$key=\"$value\"";
       }
       $metaDataArgs .= "$sep$key=\"$value\"";
       $sep = " ";
    }
    
    @meta = grep( !/^%META:$metaDataType\{$identifier/, @meta );

    push @meta, "%META:$metaDataType\{$metaDataArgs}%";
    return sort @meta;
}

# ==========================
sub metaExtract
{
    my( $metaDataType, $identifierr, $doRemove, @meta ) = @_;
    
    my $identifier = "";
    
    if( $identifierr ) {
        my @identifierL = @$identifierr;
    
        my $key = shift @identifierL;
        my $value = shift @identifierL;
        
        $identifier = "$key=\"$value\"";
    }

    my @extract = grep( /^%META:$metaDataType\{.*$identifier/, @meta );
    my $variable = "";
    my @args = ();
    
    if( @extract ) {
        $variable = shift @extract;
        $variable =~ /%META:$metaDataType\{([^}]*)}%/;
        @args = keyValue2list( $1 );
        if( $doRemove ) {
            @meta = grep( !/^%META:$metaDataType\{.*$identifier/, @meta );
        }
    }
    
    return( \@args, @meta );
}

# ============================
# Replace only those attributes supplied
# This has all the capabilities of metaUpdate and could replace it, but is more complex.
sub metaUpdatePartial
{
    my( $metaDataType, $args, $identifierKey, @meta ) = @_;
    
    my $identifier = "";
    
    my @match = grep( /^%META:$metaDataType\{$identifier/, @meta );
    my $oldItem = "";
    if( @match ) {
       $oldItem = shift @match;
       $oldItem =~ /%META:$metaDataType\{([^}]*)}/;
       $oldItem = $1;
    }
    
    my @oldArgs = keyValue2list( $oldItem );
    my %newArgs = @$args;
    
    my $metaDataArgs = "";
    my $sep = "";
    while( @oldArgs ) {
       my $key = shift @oldArgs;
       my $value = shift @oldArgs;
       if( exists $newArgs{$key} ) {
          $value = $newArgs{$key};
       }
       if ( $identifierKey && $identifierKey eq $key ) {
           $identifier = "$key=\"$value\"";
       }
       $metaDataArgs .= "$sep$key=\"$value\"";
       $sep = " ";
    }
    
    @meta = grep( !/^%META:$metaDataType\{$identifier/, @meta );

    push @meta, "%META:$metaDataType\{$metaDataArgs}%";
    return sort @meta;
}

# ======================
sub keyValue2list
{
    my( $args ) = @_;
    
    my @items = split /\s/, $args;
    
    my @res = ();
    
    foreach my $item ( @items ) {
        $item =~ /(.*)="([^"]*)"/;
        push @res, $1;
        push @res, $2;
    }
    
    return @res;
}


# ========================
sub metaAddTopicData
{
    my( $web, $topic, $rev, @meta ) = @_;
    
    my $time = time();
    my $user = $TWiki::userName;
        
    my @args = (
       "version" => "$rev",
       "date"    => "$time",
       "author"  => "$user",
       "format"  => "1.0beta" ); # FIXME put correct format version here
    @meta = metaUpdate( "TOPICINFO", \@args, "", @meta );
    
    return @meta;
}


# =========================
sub saveTopicNew
{
    my( $web, $topic, $text, $metaData, $saveCmd, $doUnlock, $dontNotify, $dontLogSave ) = @_;
    my $attachment = "";
    saveNew( $web, $topic, $text, $metaData, $saveCmd, $attachment, $dontLogSave, $doUnlock, $dontNotify );
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
    
    # Update RCS
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


sub save
{
    my( $web, $topic, $text, $saveCmd, $attachment, $dontLogSave, $doUnlock, $dontNotify, $theComment ) = @_;
    
    # FIXME get rid of this routine
    
    my @meta = ();
    
    return saveNew( $web, $topic, $text, \@meta, $saveCmd, $attachment, $dontLogSave, $doUnlock, $dontNotify, $theComment );
}


# ========================
sub _saveWithMeta
{
    my( $web, $topic, $text, $attachment, $doUnlock, $nextRev, @meta ) = @_;
    
    if( ! $attachment ) {
        my $name = getFileName( $web, $topic, $attachment );
        
        if( ! $nextRev ) {
            $nextRev = "1.1";
        }

        @meta = metaAddTopicData(  $web, $topic, $nextRev, @meta );
        my $metaText = join "\n", @meta;
        $text = "$metaText\n$text";
    
	# save file
	saveFile( $name, $text );

	# reset lock time, this is to prevent contention in case of a long edit session
       lockTopicNew( $web, $topic, $doUnlock );
    }

    return( $text, @meta );
}



# =========================
# return non-null string if there is an (RCS) error.
sub saveNew
{
    my( $web, $topic, $text, $metaData, $saveCmd, $attachment, $dontLogSave, $doUnlock, $dontNotify, $theComment ) = @_;
    my $name = getFileName( $web, $topic, $attachment );
    my $dir  = getFileDir( $web, $topic, $attachment, "" );
    my $time = time();
    my $tmp = "";
    my $rcsError = "";
    my @meta = @$metaData;
    
    my $currentRev = getRevisionNumberX( $web, $topic );
    my $nextRev    = "";
    if( ! $currentRev ) {
        $nextRev = "1.1";
    }

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
                   $saveCmd = ""; # FIXME - correct?
                }
            }
        }
        
        if( ! $nextRev ) {
            # FIXME what if content hasn't changed?
            writeDebug( "currentRev = $currentRev" );
            $currentRev =~ /1\.([0-9]+)/;
            my $num = $1;
            $num++;
            $nextRev = "1.$num";
        }

        if( $saveCmd ne "repRev" ) {
            ( $text, @meta ) = _saveWithMeta( $web, $topic, $text, $attachment, $doUnlock, $nextRev, @meta );

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

            $tmp= $TWiki::revCiCmd;
            $tmp =~ s/%USERNAME%/$TWiki::userName/;
            # FIXME put back $rcsFile if history for attachments moves to data area
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
                  $tmp =~ s/%USERNAME%/$TWiki::userName/;
                  # FIXME put back $rcsFile if history for attachments moves to data area
                  $tmp =~ s/%FILENAME%/$name/;
                  $tmp =~ s/%COMMENT%/$theComment/;
                  $tmp =~ /(.*)/;
                  $tmp = $1;       # safe, so untaint variable
                  $tmp .= " 2>&1 1>$TWiki::nullDev";
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
        ( $text, @meta ) = _saveWithMeta( $web, $topic, $text, $attachment, $doUnlock, $nextRev, @meta );

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
        $tmp = _readVersionNoMeta( $topic, $rev );
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
sub getRevisionInfoFromMeta
{
    my( $web, $topic, $metar, $changeToIsoDate ) = @_;
    
    my( $date, $author, $rev );
    
    my @meta = @$metar;
    
    my @metainfo = grep( /^%META:TOPICINFO/, @meta );
    if( @metainfo ) {
       # Stored as meta data in topic for faster access
       my $topicinfo = shift @metainfo;
       $topicinfo =~ /%META:TOPICINFO{([^}]*)}/;
       my $args   = $1;
       my $tmp = TWiki::extractNameValuePair( $args, "date" );
       $date = TWiki::formatGmTime( $tmp ); # FIXME should format be here or with user?
       $author = TWiki::extractNameValuePair( $args, "author" );
       $tmp = TWiki::extractNameValuePair( $args, "version" );
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
    my( $text ) = @_;
    
    my @meta = ();
     
    if ( $text =~ /<!--TWikiAttachment-->/ ) {
       ( $text, @meta ) = TWiki::Attach::migrateToFileAttachmentMacro( $text );
    }

    
    return( $text, @meta );
}


# =========================
# Expect meta data at top of file, but willing to accept it anywhere
# If we have an old file format without meta data, then convert
sub _extractMetaData
{
    my( $fulltext ) = @_;
    
    my $text = "";
    my @meta = ();
    
    foreach( split( /\n/, $fulltext ) ) {
        if( /^%META:/ ) {
            push @meta, $_;    
        } else {
            $text .= "$_\n";
        }
    }
    
    # If there is no meta data then convert
    if( $#meta == -1 ) {
        ($text, @meta ) = convert2metaFormat( $text );
    }
    
    return( $text, @meta );
}

# =========================
sub readTopic
{
    my( $theName ) = @_;
    return &readWebTopic( $TWiki::webName, $theName );
}

# =========================
sub readWebTopic
{
    my( $theWeb, $theName ) = @_;
    my $text = &readFile( "$TWiki::dataDir/$theWeb/$theName.txt" );
    
    return $text;
}

# FIXME replace readWebTopic
sub readWebTopicNew
{
    my( $theWeb, $theName ) = @_;
    my $text = &readFile( "$TWiki::dataDir/$theWeb/$theName.txt" );
    
    my @meta = ();
    
    ($text, @meta) = _extractMetaData( $text );
    
    return( $text, @meta );
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
        my $txt = &readFile( $tmplFile );
        
        $txt =~ s/%HEADER{([^}]*)}%/&TWiki::handleHeader( $1, $theTopic, $theSkin )/geo;
        $txt =~ s/%FOOTER(:[A-Z]*)?%/&TWiki::handleFooter( $1, $theTopic, $theSkin )/geo;
        $txt =~ s/%SEP%/&TWiki::handleSep( $theTopic, $theSkin )/geo;
        

        
        # Modify views for DrKW style
        if ( -e "$tmplDir/drkwtop.tmpl" && $tmplFile !~ m|/view.| ) {
            my $top = &readFile( "$tmplDir/drkwtop.tmpl" );
            my $bottom = &readFile( "$tmplDir/drkwbottom.tmpl" );
            $txt =~ s|<TD[^>]*>.*?wikiHome.gif.*?</TD>||smio;
            $txt =~ s|%WEBBGCOLOR%|#e3f0e3|go;
            $txt =~ s|<BASE.*>(.*)|$1|;
            $txt =~ s+<TITLE>+<LINK href="/twiki/pub/skins/drkwleftnav/twiki.css" rel=stylesheet type=TEXT/CSS>\n<TITLE>+smio;
            $txt =~ s+\s*(<TABLE[^>]*>.*?</TABLE>)(.*)(<TABLE[^>]*>.*?</TABLE>\s*(%WEBCOPYRIGHT%)?\s*(</FORM>)?)\s*</BODY>+$top$1$2$3$bottom</BODY>+smio;

        }
        return $txt;
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
