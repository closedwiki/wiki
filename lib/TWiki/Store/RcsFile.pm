# TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 1999-2005 Peter Thoeny, peter@thoeny.com
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
# Copyright (C) 2002 John Talintyre, john.talintyre@btinternet.com
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

---+ package TWiki::Store::RcsFile

This class is PACKAGE PRIVATE to Store, and should never be
used from anywhere else. It provides methods for the default
Store implementation to manipulate RCS files.

Superclass of all implementers of RCS storage models.

Refer to Store.pm for models of usage.

=cut

package TWiki::Store::RcsFile;

use strict;

use File::Copy;
use File::Spec;
use TWiki::Sandbox;
use Assert;
use TWiki::Time;

my $lastError;

=pod

---++ ClassMethod new($session, $web, $topic, $attachment)
Constructor. There is one object per stored file.

=cut

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

# Used in subclasses for late initialisation during object creation
# (after the object is blessed into the subclass)
sub init {
    my $self = shift;

    # If attachment - make sure file and history directories exist
    if( $self->{attachment} ) {
        # Make sure directory for rcs history file exists
        # SMELL: surely this should be PubDir??
        my $tempPath = $TWiki::cfg{DataDir} . "/" . $self->{web};
        unless( -e $tempPath ) {
            umask( 0 );
            mkdir( $tempPath,
                   $TWiki::cfg{RCS}{dirPermission} );
        }
        $tempPath = $self->_makeFileDir( 1, ",v" );
        unless( -e $tempPath ) {
            umask( 0 );
            mkdir( $tempPath,
                   $TWiki::cfg{RCS}{dirPermission} );
        }
    }

    unless( -e $self->{rcsFile} ) {
        if( $self->{attachment} &&
            !$self->isAsciiDefault() ) {
            $self->initBinary();
        } else {
            $self->initText();
        }
    }
}

# Pseudo revision information - used when there is no revision file
sub _getRevisionInfoDefault {
    my( $self ) = @_;
    my $fileDate = $self->getTimestamp();
    return ( "", 1, $fileDate, $TWiki::cfg{DefaultUserLogin},
             "Default revision information - no revision file" );
}

=pod

---++ ObjectMethod getTimestamp() -> $integer

Get the timestamp of the topic file
Returns 0 if no file, otherwise epoch seconds

=cut

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

---++ ObjectMethod restoreLatestRevision()

Restore the plaintext file from the revision at the head.

Return an error message or undef.

=cut

sub restoreLatestRevision {
    my( $self ) = @_;

    my $rev = $self->numRevisions();
    my $text = $self->getRevision( $rev );

    return $self->_saveFile( $self->{file}, $text );
}

=pod

---++ ObjectMethod moveMe($newWeb, $newTopic, $attachment)

Move a topic or attachment somewhere else.

Return error message or undef.

=cut

sub moveMe {
    my( $self, $newWeb, $newTopic, $attachment ) = @_;

    if( $self->{attachment} ) {
        return $self->_moveAttachment( $newWeb, $newTopic,
                                       $self->{attachment} );
    } else {
        return $self->_moveTopic( $newWeb, $newTopic );
    }
}

# Move/rename a topic, allow for transfer between Webs
#
# Return error message or undef
sub _moveTopic {
   my( $self, $newWeb, $newTopic ) = @_;

   my $oldWeb = $self->{web};
   my $oldTopic = $self->{topic};

   # Change data file
   my $new = new TWiki::Store::RcsFile( $self->{session},
                                        $newWeb, $newTopic, "" );
   unless( move( $self->{file}, $new->{file} ) ) {
       return "data file move failed.";
   }

   # Change data file history
   if( -e $self->{rcsFile} ) {
       unless( move( $self->{rcsFile}, $new->{rcsFile} )) {
           return "history file move failed.";
       }
   }

   # Make sure pub directory exists for newWeb
   my $newPubWebDir = $new->_makePubWebDir( $newWeb );
   unless( -e $newPubWebDir ) {
       umask( 0 );
       mkdir( $newPubWebDir,
              $TWiki::cfg{RCS}{dirPermission} )
         or return "mkdir $newPubWebDir failed";;
   }

   # Rename the attachment directory if there is one
   my $oldAttachDir = $self->_makeFileDir( 1, "" );
   my $newAttachDir = $new->_makeFileDir( 1, "");
   if( -e $oldAttachDir ) {
       unless( move(
                    $oldAttachDir,
                    $newAttachDir
                   ) ) {
           return "attach move failed";
       }
   }

   return undef;
}

# Move an attachment from one topic to another.
# If there is a problem an error string is returned.
# The caller to this routine should check that all topics are valid and
# do lock on the topics.
# Return error message or undef.
sub _moveAttachment {
    my( $self, $newWeb, $newTopic ) = @_;

    my $oldWeb = $self->{web};
    my $oldTopic = $self->{topic};
    my $attachment = $self->{attachment};

    my $what = "$oldWeb.$oldTopic.$attachment -> $newWeb.$newTopic";

    # FIXME might want to delete old directories if empty
    my $new = TWiki::Store::RcsFile->new( $self->{session}, $newWeb,
                                          $newTopic, $attachment );

    # before save, create directories if they don't exist
    my $tempPath = $new->_makePubWebDir();
    unless( -e $tempPath ) {
        umask( 0 );
        mkdir( $tempPath, 0775 )
          or return "mkdir $tempPath failed";
    }
    $tempPath = $new->_makeFileDir( 1 );
    unless( -e $tempPath ) {
        umask( 0 );
        mkdir( $tempPath, 0775 )
          or return "mkdir $tempPath failed: $!";
    }

    # Move attachment
    my $oldAttachment = $self->{file};
    my $newAttachment = $new->{file};
    unless( move(
                 $oldAttachment,
                 $newAttachment
                ) ) {
        return "Failed to move attachment; $what ($!)";
    }

    # Make sure rcs directory exists
    my $newRcsDir = $new->_makeFileDir( 1, ",v" );
    if ( ! -e $newRcsDir ) {
        umask( 0 );
        mkdir( $newRcsDir,
               $TWiki::cfg{RCS}{dirPermission} )
          or return "mkdir $newRcsDir failed: $!";
    }

    # Move attachment history
    my $oldAttachmentRcs = $self->{rcsFile};
    my $newAttachmentRcs = $new->{rcsFile};
    if( -e $oldAttachmentRcs ) {
        unless( move(
                     $oldAttachmentRcs,
                     $newAttachmentRcs
                    ) ) {
            return "Failed to move attachment history; $what ($!)";
        }
    }

    return undef;
}

# SMELL: this should use TWiki::Time
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

Check if this file type is known to be an ascii type file.

=cut

sub isAsciiDefault {
   my( $self ) = @_;

   if( $self->{attachment} =~ /$TWiki::cfg{RCS}{asciiFileSuffixes}/ ) {
      return "ascii";
   } else {
      return "";
   }
}

=pod

---++ ObjectMethod setLock (   $lock, $user  )

Set a twiki lock on the topic, if $lock, otherwise clear it.
$user is a wikiname.

Return an error message on failure.

=cut

sub setLock {
    my( $self, $lock, $user ) = @_;

    $user = $self->{session}->{user} unless $user;

    my $lockFilename = $self->_makeFileName( ".lock" );
    if( $lock ) {
        my $lockTime = time();
        return $self->_saveFile( $lockFilename, "$user\n$lockTime" );
    } else {
        unlink "$lockFilename"
          or return "Failed to delete $lockFilename: $!";
    }
    return undef;
}

=pod

---++ ObjectMethod isLocked( ) -> $boolean

See if a twiki lock exists. Return the lock user and lock time if it does.

=cut

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
        mkdir( $tempPath,
               $TWiki::cfg{RCS}{dirPermission} )
          or return "mkdir failed: $!";
    }
    $tempPath = $self->_makeFileDir( 1 );
    if( ! -e $tempPath ) {
        umask( 0 );
        mkdir( $tempPath, 0775 )
          or return "mkdir failed: $!";
    }

    # FIXME share with move - part of init?

    # save uploaded file
    my $newFile = $self->{file};
    copy($theTmpFilename, $newFile)
      or return "copy($theTmpFilename, $newFile) failed: $!";

    # FIXME more consistant way of dealing with errors
    umask( 002 );
    chmod( 0644, $newFile ); # FIXME config permission for new attachment

    return "";
}

sub _saveFile {
    my( $self, $name, $text ) = @_;

    umask( 002 );
    open( FILE, ">$name" )
      or return "Can't create file $name: $!";
    binmode( FILE )
      or return "Can't binmode $name: $!";
    print FILE $text;
    close( FILE)
      or return "Can't create file $name: $!";

    return undef;
}

# Deal differently with topics and attachments
# text is a reference for efficiency
sub _save {
    my( $self, $filename, $text ) = @_;

    if( $self->{attachment} ) {
        my $tmpFilename = $$text;
        return $self->_saveAttachment( $tmpFilename );
    } else {
        return $self->_saveFile( $filename, $$text );
    }
}

sub _readFile {
    my( $self, $name ) = @_;
    my $data = "";
    undef $/; # set to read to EOF
    open( IN_FILE, "<$name" )
      or return "";
    binmode IN_FILE;
    $data = <IN_FILE>;
    $/ = "\n";
    close( IN_FILE );
    $data = "" unless $data; # no undefined
    return $data;
}

# Get full filename for attachment or topic
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

    $extension ||= "";

    my $file = "";
    my $extra = "";
    my $web = $self->{web};
    my $topic = $self->{topic};
    my $attachment = $self->{attachment};

    if( $extension eq ".lock" ) {
        $file = "$TWiki::cfg{DataDir}/$web/$topic$extension";
    } elsif( $attachment ) {
        if ( $extension eq ",v" && $TWiki::cfg{RCS}{useSubDir} &&
             -d "$TWiki::cfg{DataDir}/$web/RCS" ) {
            $extra = "/RCS";
        }

        $file = "$TWiki::cfg{PubDir}/$web/$topic$extra/$attachment$extension";
    } else {
        if( ! $extension ) {
            $extension = ".txt";
        } else {
            if( $extension eq ",v" ) {
                $extension = ".txt$extension";
                if( $TWiki::cfg{RCS}{useSubDir} &&
                    -d "$TWiki::cfg{DataDir}/$web/RCS" ) {
                    $extra = "/RCS";
                }
            }
        }
        $file = "$TWiki::cfg{DataDir}/$web$extra/$topic$extension";
    }

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
        if( $extension eq ",v" && $TWiki::cfg{RCS}{useSubDir} &&
            -d "$TWiki::cfg{DataDir}/$web/RCS" ) {
            $dir = "$TWiki::cfg{DataDir}/$web/RCS";
        } else {
            $dir = "$TWiki::cfg{DataDir}/$web";
        }
    } else {
        my $suffix = "";
        if ( $extension eq ",v" && $TWiki::cfg{RCS}{useSubDir} &&
             -d "$TWiki::cfg{DataDir}/$web/RCS" ) {
            $suffix = "/RCS";
        }
        $dir = "$TWiki::cfg{PubDir}/$web/$topic$suffix";
    }

    return TWiki::Sandbox::untaintUnchecked( $dir );
}

sub _makePubWebDir {
    my( $self ) = @_;

    my $dir = $TWiki::cfg{PubDir} . "/" . $self->{web};

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

    ASSERT(@_ == 1 || @_ == 2 || @_ == 3) if DEBUG;

    ($template,$dir,$ext) = @_;
    @template = split //, $template;

    ASSERT(substr($template, -6, 6) ne 'XXXXXX') if DEBUG;

    if ($dir){
        ASSERT(-e $dir) if DEBUG;
    }

    @letters =
      split(//,"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ");

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
        } else {
            $keepgen = 0;
        }

        next if $keepgen == 0;
    }

    return($template);
}

=pod

---++ ObjectMethod getStream() -> \*STREAM

Return stream or undef if there is an error. The error
can be recovered using lastError.

=cut

sub getStream {
    my( $this ) = shift;
    my $strm;
    unless( open( $strm, "<$this->{file}" )) {
        $lastError = "Open failed: $!";
        return undef;
    }
    return $strm;
}

=pod

---++ StaticMethod lastError() -> $string

Get the last recorded error.

=cut

sub lastError {
    return $lastError;
}

=pod

---++ ObjectMethod numRevisions() -> $integer

Must be provided by subclasses.

Find out how many revisions there are. If there is a problem, such
as a nonexistent file, returns 0. Any errors can be recovered using
lastError().

*Virtual method* - must be implemented by subclasses

=cut

=pod

---++ ObjectMethod initBinary()

Initialise a binary file.

Must be provided by subclasses.

Returns "" if okay, otherwise an error string.

*Virtual method* - must be implemented by subclasses

=cut

=pod

---++ ObjectMethod initText()

Initialise a text file.

Must be provided by subclasses.

Returns "" if okay, otherwise an error string.

*Virtual method* - must be implemented by subclasses

=cut

=pod

---++ ObjectMethod addRevision (   $text, $comment, $user, $date ) -> $error

Add new revision. Replace file (if exists) with text.
   * =$text= of new revision
   * =$comment= checkin comment
   * =$user= is a wikiname.
   * =$date= in epoch seconds; may be ignored

*Virtual method* - must be implemented by subclasses

=cut

=pod

---++ ObjectMethod replaceRevision($text, $comment, $user, $date) -> $error
Replace the top revision.
   * =$text= is the new revision
   * =$date= is in epoch seconds.
   * =$user= is a wikiname.
   * =$comment= is a string

Return error message or undef.

*Virtual method* - must be implemented by subclasses

=cut

=pod

---++ ObjectMethod deleteRevision() -> $error

Delete the last revision - do nothing if there is only one revision

Return error message or undef.

*Virtual method* - must be implemented by subclasses

=cut to implementation

=pod

---++ ObjectMethod revisionDiff (   $rev1, $rev2, $contextLines  ) -> \@diffArray
rev2 newer than rev1.
Return reference to an array of [ diffType, $right, $left ]

*Virtual method* - must be implemented by subclasses

=cut

=pod

---++ ObjectMethod getRevision($version) -> $text

Get the text for a given revision. The version number must be an integer.

*Virtual method* - must be implemented by subclasses

=cut

=pod

---++ ObjectMethod getRevisionInfo($version) -> ($rcsError, $rev, $date, $user, $comment)

A version number of 0 or undef will return info on the _latest_ revision.

If revision file is missing, information based on actual file is returned.

Date return in epoch seconds. Revision returned as a number.
User returned as a wikiname.

*Virtual method* - must be implemented by subclasses

=cut

1;
