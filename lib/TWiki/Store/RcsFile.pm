# Module of TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2002 John Talintyre, john.talintyre@btinternet.com
# Copyright (C) 2002-2003 Peter Thoeny, peter@thoeny.com
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
#

=begin twiki

---+ UNPUBLISHED package TWiki::Store::RcsFile

Superclass of RcsWrap and RcsLite.

This class is PACKAGE PRIVATE to Store, and should never be
used from anywhere else.

The documentation is extremely sparse. Refer to Store.pm for models
of usage.

=cut

package TWiki::Store::RcsFile;

use strict;

use File::Copy;
use File::Spec;
use TWiki::Sandbox;
use Assert;
use TWiki::Time;

=pod

---++ ClassMethod new($web, $topic, $attachment)

=cut to implementation

sub new {
    my( $class, $session, $web, $topic, $attachment ) = @_;
    ASSERT(ref($session) eq "TWiki") if DEBUG;
    my $self = bless( {}, $class );
    $self->{session} = $session;
    $self->{web} = $web;
    $self->{topic} = $topic;
    $self->{attachment} = $attachment || "";
    $self->{file} = $self->_makeFileName();
    $self->{rcsFile} = $self->_makeFileName( ",v" );

    return $self;
}

=pod

---++ ClassMethod init()
Used in subclasses for late initialisation during object creation.

=cut

sub init {
    my $self = shift;

    # If attachment - make sure file and history directories exist
    if( $self->{attachment} ) {
        # Make sure directory for rcs history file exists
        # SMELL: surely this should be PubDir??
        my $tempPath = $TWiki::cfg{DataDir} . "/" . $self->{web};
        if( ! -e $tempPath ) {
            umask( 0 );
            mkdir( $tempPath, $TWiki::cfg{RCS}{dirPermission} );
        }
        $tempPath = $self->_makeFileDir( 1, ",v" );
        if( ! -e $tempPath ) {
            umask( 0 );
            mkdir( $tempPath, $TWiki::cfg{RCS}{dirPermission} );
        }
    }

    if( $self->{attachment} &&
        ! -e $self->{rcsFile} && 
        ! $self->isAsciiDefault() ) {
        $self->setBinary( 1 );
    }
}

=pod

---++ ObjectMethod revisionFileExists (   ) -> $boolean

Not yet documented.

=cut to implementation

sub revisionFileExists {
    my( $self ) = @_;
    return ( -e $self->{rcsFile} );
}

# Psuedo revision information - useful when there is no revision file
sub _getRevisionInfoDefault {
    my( $self ) = @_;
    my $fileDate = $self->getTimestamp();
    return ( "", 1, $fileDate, $TWiki::defaultUser, "Default revision information - no revision file" );
}

=pod

---++ ObjectMethod getTimestamp (   ) -> $integer

Get the timestamp of the topic file
Returns 0 if no file, otherwise epoch seconds

=cut to implementation

sub getTimestamp {
    my( $self ) = @_;
    my $date = 0;
    if( -e $self->{file} ) {
        # Why big number if fail?
        $date = (stat $self->{file})[9] || 600000000;
    }
    return $date;
}

=pod

---++ ObjectMethod restoreLatestRevision (   )

Not yet documented.

=cut to implementation

sub restoreLatestRevision {
    my( $self ) = @_;

    my $rev = $self->numRevisions();
    my $text = $self->getRevision( $rev );
    $self->_saveFile( $self->{file}, $text );
}

=pod

---++ ObjectMethod moveMe (   $newWeb, $newTopic, $attachment  )

Not yet documented.

=cut to implementation

sub moveMe {
    my( $self, $newWeb, $newTopic, $attachment ) = @_;

    if( $self->{attachment} ) {
        $self->_moveAttachment( $newWeb, $newTopic, $self->{attachment} );
    } else {
        $self->_moveTopic( $newWeb, $newTopic );
    }
}

# Move/rename a topic, allow for transfer between Webs
# It is the responsibility of the caller to check: exstance webs & topics, lock taken for topic
sub _moveTopic {
   my( $self, $newWeb, $newTopic ) = @_;

   my $oldWeb = $self->{web};
   my $oldTopic = $self->{topic};
   my $error = "";

   # Change data file
   my $new = TWiki::Store::RcsFile->new( $self->{session}, $newWeb, $newTopic, "" );
   my $from = $self->{file};
   my $to =  $new->{file};
   if( ! move( $from, $to ) ) {
       $error .= "data file move failed.  ";
   }

   # Change data file history
   my $oldHistory = $self->{rcsFile};
   if( ! $error && -e $oldHistory ) {
       if( ! move(
         $oldHistory,
         $new->{rcsFile}
       ) ) {
          $error .= "history file move failed.  ";
       }
   }

   if( ! $error ) {
       # Make sure pub directory exists for newWeb
       my $newPubWebDir = $new->_makePubWebDir( $newWeb );
       if ( ! -e $newPubWebDir ) {
           umask( 0 );
           mkdir( $newPubWebDir, $TWiki::cfg{RCS}{dirPermission} );
       }

       # Rename the attachment directory if there is one
       my $oldAttachDir = $self->_makeFileDir( 1, "" );
       my $newAttachDir = $new->_makeFileDir( 1, "");
       if( -e $oldAttachDir ) {
          if( ! move( $oldAttachDir, $newAttachDir ) ) {
              $error .= "attach move failed";
          }
       }
   }

   return $error;
}

# Move an attachment from one topic to another.
# If there is a problem an error string is returned.
# The caller to this routine should check that all topics are valid and
# do lock on the topics.
sub _moveAttachment {
    my( $self, $newWeb, $newTopic ) = @_;

    my $oldWeb = $self->{web};
    my $oldTopic = $self->{topic};
    my $attachment = $self->{attachment};

    my $error = "";
    my $what = "$oldWeb.$oldTopic.$attachment -> $newWeb.$newTopic";

    # FIXME might want to delete old directories if empty

    my $new = TWiki::Store::RcsFile->new( $self->{session}, $newWeb, $newTopic, $attachment );

    # before save, create directories if they don't exist
    my $tempPath = $new->_makePubWebDir();
    unless( -e $tempPath ) {
        umask( 0 );
        mkdir( $tempPath, 0775 );
    }
    $tempPath = $new->_makeFileDir( 1 );
    unless( -e $tempPath ) {
        umask( 0 );
        mkdir( $tempPath, 0775 ); # FIXME get from elsewhere
    }

    # Move attachment
    my $oldAttachment = $self->{file};
    my $newAttachment = $new->{file};
    if( ! move( $oldAttachment, $newAttachment ) ) {
        $error = "Failed to move attachment; $what ($!)";
        return $error;
    }

    # Make sure rcs directory exists
    my $newRcsDir = $new->_makeFileDir( 1, ",v" );
    if ( ! -e $newRcsDir ) {
        umask( 0 );
        mkdir( $newRcsDir, $TWiki::cfg{RCS}{dirPermission} );
    }

    # Move attachment history
    my $oldAttachmentRcs = $self->{rcsFile};
    my $newAttachmentRcs = $new->{rcsFile};
    if( -e $oldAttachmentRcs ) {
        if( ! move( $oldAttachmentRcs, $newAttachmentRcs ) ) {
            $error .= "Failed to move attachment history; $what ($!)";
            # Don't return here as attachment file has already been moved
        }
    }

    return $error;
}

sub _epochToRcsDateTime {
   my( $dateTime ) = @_;
   # TODO: should this be gmtime or local time?
   my( $sec,$min,$hour,$mday,$mon,$year,$wday,$yday ) = gmtime( $dateTime );
   $year += 1900 if( $year > 99 );
   my $rcsDateTime = sprintf "%d.%02d.%02d.%02d.%02d.%02d", ( $year, $mon + 1, $mday, $hour, $min, $sec );
   return $rcsDateTime;
}

=pod

---++ ObjectMethod isAsciiDefault (   ) -> $string

Not yet documented.

=cut to implementation

sub isAsciiDefault {
   my( $self ) = @_;

   if( $self->{attachment} =~ /$TWiki::cfg{RCS}{asciiFileSuffixes}/ ) {
      return "ascii";
   } else {
      return "";
   }
}

# Must be provided by subclasses
# Returns "" if okay, otherwise an error string
sub binaryChange {
   ASSERT(0) if DEBUG;
}

=pod

---++ ObjectMethod setBinary (   $binary  )

=cut to implementation

sub setBinary {
    my( $self, $binary ) = @_;
    my $oldSetting = $self->{binary};
    $binary = "" if( ! $binary );
    $self->{binary} = $binary;
    $self->binaryChange() if( (! $oldSetting && $binary) || ($oldSetting && ! $binary) );
}

=pod

---++ ObjectMethod setLock (   $lock, $user  )

Set a twiki lock on the topic, if $lock, otherwise clear it.
$user is a wikiname.

=cut to implementation

sub setLock {
    my( $self, $lock, $user ) = @_;

    $user = $self->{session}->{user} unless $user;

    my $lockFilename = $self->_makeFileName( ".lock" );
    if( $lock ) {
        my $lockTime = time();
        $self->_saveFile( $lockFilename, "$user\n$lockTime" );
    } else {
        unlink "$lockFilename";
    }
}

=pod

---++ ObjectMethod isLocked( ) -> $boolean

See if a twiki lock exists. Return the lock user and lock time if it does.

=cut to implementation

sub isLocked {
    my( $self ) = @_;

    my $lockFilename = $self->_makeFileName( ".lock" );
    if ( -e $lockFilename ) {
        my $t = $self->{session}->{store}->readFile( $lockFilename );
        return split( /\s+/, $t, 2 );
    }
    return ( undef, undef );
}

sub _saveAttachment {
    my( $self, $theTmpFilename ) = @_;

    # before save, create directories if they don't exist
    my $tempPath = $self->_makePubWebDir();
    if( ! -e $tempPath ) {
        umask( 0 );
        mkdir( $tempPath, $TWiki::cfg{RCS}{dirPermission} );
    }
    $tempPath = $self->_makeFileDir( 1 );
    if( ! -e $tempPath ) {
        umask( 0 );
        mkdir( $tempPath, 0775 );
    }
    
    # FIXME share with move - part of init?

    # save uploaded file
    my $newFile = $self->{file};
    copy($theTmpFilename, $newFile) or warn "copy($theTmpFilename, $newFile) failed: $!";
    # FIXME more consistant way of dealing with errors
    umask( 002 );
    chmod( 0644, $newFile ); # FIXME config permission for new attachment
}

# This is really saveTopic
sub _saveFile {
    my( $self, $name, $text ) = @_;

    umask( 002 );
    unless ( open( FILE, ">$name" ) )  {
        warn "Can't create file $name - $!\n";
        return;
    }
    binmode( FILE );
    print FILE $text;
    close( FILE);
}

# Deal differently with topics and attachments
# text is a reference for efficiency
sub _save {
    my( $self, $filename, $text ) = @_;

    if( $self->{attachment} ) {
        my $tmpFilename = $$text;
        $self->_saveAttachment( $tmpFilename );
    } else {
        $self->_saveFile( $filename, $$text );
    }
}

sub _readFile {
    my( $self, $name ) = @_;
    my $data = "";
    undef $/; # set to read to EOF
    open( IN_FILE, "<$name" ) || return "";
    binmode IN_FILE;
    $data = <IN_FILE>;
    $/ = "\n";
    close( IN_FILE );
    $data = "" unless $data; # no undefined
    return $data;
}


# Get full filename for attachment or topic, untaint
# Extension can be:
# If $attachment is blank
#    blank or .txt - topic data file
#    ,v            - topic history file
#    lock          - topic lock file
# If $attachment
#    blank         - attachment file
#    ,v            - attachment history file
sub _makeFileName {
   my( $self, $extension ) = @_;

   if( ! $extension ) {
      $extension = "";
   }

   my $file = "";
   my $extra = "";
   my $web = $self->{web};
   my $topic = $self->{topic};
   my $attachment = $self->{attachment};

   if( $extension eq ".lock" ) {
      $file = "$TWiki::cfg{DataDir}/$web/$topic$extension";

   } elsif( $attachment ) {
      if ( $extension eq ",v" && $TWiki::cfg{RCS}{useSubDir} && -d "$TWiki::cfg{DataDir}/$web/RCS" ) {
         $extra = "/RCS";
      }

      $file = "$TWiki::cfg{PubDir}/$web/$topic$extra/$attachment$extension";
   } else {
      if( ! $extension ) {
         $extension = ".txt";
      } else {
         if( $extension eq ",v" ) {
            $extension = ".txt$extension";
            if( $TWiki::cfg{RCS}{useSubDir} && -d "$TWiki::cfg{DataDir}/$web/RCS" ) {
               $extra = "/RCS";
            }
         }
      }
      $file = "$TWiki::cfg{DataDir}/$web$extra/$topic$extension";
   }

   # Shouldn't really need to untaint here - done to be sure
   return TWiki::Sandbox::untaintUnchecked( $file );
}

# Get directory that topic or attachment lives in
#    Leave topic blank if you want the web directory rather than the topic directory
#    should simply this with _makeFileName
sub _makeFileDir {
   my( $self, $attachment, $extension) = @_;

   $extension = "" if( ! $extension );

   my $web = $self->{web};
   my $topic = $self->{topic};

   my $dir = "";
   if( ! $attachment ) {
      if( $extension eq ",v" && $TWiki::cfg{RCS}{useSubDir} && -d "$TWiki::cfg{DataDir}/$web/RCS" ) {
         $dir = "$TWiki::cfg{DataDir}/$web/RCS";
      } else {
         $dir = "$TWiki::cfg{DataDir}/$web";
      }
   } else {
      my $suffix = "";
      if ( $extension eq ",v" && $TWiki::cfg{RCS}{useSubDir} && -d "$TWiki::cfg{DataDir}/$web/RCS" ) {
         $suffix = "/RCS";
      }
      $dir = "$TWiki::cfg{PubDir}/$web/$topic$suffix";
   }

   # Shouldn't really need to untaint here - done to be sure
   return TWiki::Sandbox::untaintUnchecked( $dir );
}

sub _makePubWebDir {
    my( $self ) = @_;

    my $dir = $TWiki::cfg{PubDir} . "/" . $self->{web};

    # FIXME: Dangerous, need to make sure that parameters are not tainted
    return TWiki::Sandbox::untaintUnchecked( $dir );
}

sub _mkTmpFilename {
    my $tmpdir = File::Spec->tmpdir();
    my $file = _mktemp( "twikiAttachmentXXXXXX", $tmpdir );
    return File::Spec->catfile($tmpdir, $file);
}

# Adapted from CPAN - File::MkTemp
sub _mktemp {
   my ($template,$dir,$ext,$keepgen,$lookup);
   my (@template,@letters);

   croak("Usage: mktemp('templateXXXXXX',['/dir'],['ext']) ") 
     unless(@_ == 1 || @_ == 2 || @_ == 3);

   ($template,$dir,$ext) = @_;
   @template = split //, $template;

   croak("The template must end with at least 6 uppercase letter X")
      if (substr($template, -6, 6) ne 'XXXXXX');

   if ($dir){
      croak("The directory in which you wish to test for duplicates, $dir, does not exist") unless (-e $dir);
   }

   @letters = split(//,"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ");

   $keepgen = 1;

   while ($keepgen){
      for (my $i = $#template; $i >= 0 && ($template[$i] eq 'X'); $i--){
         $template[$i] = $letters[int(rand 52)];
      }

      undef $template;

      $template = pack "a" x @template, @template;

      $template = $template . $ext if ($ext);

         if ($dir){
            $lookup = File::Spec->catfile($dir, $template);
            $keepgen = 0 unless (-e $lookup);
         }else{
            $keepgen = 0;
         }

   next if $keepgen == 0;
   }

   return($template);
}

1;
