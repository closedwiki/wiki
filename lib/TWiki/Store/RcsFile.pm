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
    ASSERT($session->isa( 'TWiki')) if DEBUG;
    my $this = bless( {}, $class );
    $this->{session} = $session;
    $this->{web} = $web;
    $this->{topic} = $topic;
    $this->{attachment} = $attachment;
    $this->{file} = $this->_makeFileName();
    $this->{rcsFile} = $this->_makeFileName( ",v" );

    return $this;
}

# Used in subclasses for late initialisation during object creation
# (after the object is blessed into the subclass)
sub init {
    my $this = shift;

    # If attachment - make sure file and history directories exist
    if( $this->{attachment} ) {
        # Make sure directory for rcs history file exists
        # SMELL: surely this should be PubDir??
        my $tempPath = $TWiki::cfg{DataDir} . "/" . $this->{web};
        unless( -e $tempPath ) {
            umask( 0 );
            mkdir( $tempPath,
                   $TWiki::cfg{RCS}{dirPermission} );
        }
        $tempPath = $this->_makeFileDir( 1, ",v" );
        unless( -e $tempPath ) {
            umask( 0 );
            mkdir( $tempPath,
                   $TWiki::cfg{RCS}{dirPermission} );
        }
    }

    unless( -e $this->{rcsFile} ) {
        if( $this->{attachment} &&
            !$this->isAsciiDefault() ) {
            $this->initBinary();
        } else {
            $this->initText();
        }
    }
}

=pod

---++ ObjectMethod getRevisionInfo($version) -> ($rev, $date, $user, $comment)
   * =$version= if 0 or undef, or out of range (version number > number of revs) will return info about the latest revision.

Returns (rev, date, user, comment) where rev is the number of the rev for which the info was recovered, date is the date of that rev (epoch s), user is the login name of the user who saved that rev, and comment is the comment asscoaietd with the rev.

Designed to be overridden by subclasses, which can call up to this method
if file-based rev info is required.

=cut

sub getRevisionInfo {
    my( $this ) = @_;
    my $fileDate = $this->getTimestamp();
    return ( 1, $fileDate, $TWiki::cfg{DefaultUserLogin},
             "Default revision information" );
}

=pod

---++ ObjectMethod getRevision($version) -> $text
   * =$version= if 0 or undef, or out of range (version number > number of revs) will return the latest revision.

Get the text of the given revision.

Designed to be overridden by subclasses, which can call up to this method
if the main file revision is required.

=cut

sub getRevision {
    my( $this ) = @_;
    return $this->_readFile( $this->{file} );
}

=pod

---++ ObjectMethod getTimestamp() -> $integer

Get the timestamp of the topic file
Returns 0 if no file, otherwise epoch seconds

=cut

sub getTimestamp {
    my( $this ) = @_;
    my $date = 0;
    if( -e $this->{file} ) {
        # Why big number if fail?
        $date = (stat $this->{file})[9] || 600000000;
    }
    return $date;
}

=pod

---++ ObjectMethod restoreLatestRevision()

Restore the plaintext file from the revision at the head.

Return an error message or undef.

=cut

sub restoreLatestRevision {
    my( $this ) = @_;

    my $rev = $this->numRevisions();
    my $text = $this->getRevision( $rev );

    return $this->_saveFile( $this->{file}, $text );
}

=pod

---++ ObjectMethod moveMe($newWeb, $newTopic, $attachment)

Move a topic or attachment somewhere else.

Return error message or undef.

=cut

sub moveMe {
    my( $this, $newWeb, $newTopic, $attachment ) = @_;

    if( $this->{attachment} ) {
        return $this->_moveAttachment( $newWeb, $newTopic,
                                       $this->{attachment} );
    } else {
        return $this->_moveTopic( $newWeb, $newTopic );
    }
}

# Move/rename a topic, allow for transfer between Webs
#
# Return error message or undef
sub _moveTopic {
    my( $this, $newWeb, $newTopic ) = @_;

    my $oldWeb = $this->{web};
    my $oldTopic = $this->{topic};

    # Change data file
    my $new = new TWiki::Store::RcsFile( $this->{session},
                                         $newWeb, $newTopic, '' );
    unless( move( $this->{file}, $new->{file} ) ) {
        return "data file move failed.";
    }

    # Change data file history
    if( -e $this->{rcsFile} ) {
        unless( move( $this->{rcsFile}, $new->{rcsFile} )) {
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
    my $oldAttachDir = $this->_makeFileDir( 1, '' );
    my $newAttachDir = $new->_makeFileDir( 1, '');
    if( -e $oldAttachDir ) {
        unless( move(
                     $oldAttachDir,
                     $newAttachDir
                    ) ) {
            return 'attach move failed';
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
    my( $this, $newWeb, $newTopic ) = @_;

    my $oldWeb = $this->{web};
    my $oldTopic = $this->{topic};
    my $attachment = $this->{attachment};

    my $what = "$oldWeb.$oldTopic.$attachment -> $newWeb.$newTopic";

    # FIXME might want to delete old directories if empty
    my $new = TWiki::Store::RcsFile->new( $this->{session}, $newWeb,
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
    my $oldAttachment = $this->{file};
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
    my $oldAttachmentRcs = $this->{rcsFile};
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
    my( $this ) = @_;

    if( $this->{attachment} =~ /$TWiki::cfg{RCS}{asciiFileSuffixes}/ ) {
        return 'ascii';
    } else {
        return '';
    }
}

=pod

---++ ObjectMethod setLock($lock, $user)

Set a lock on the topic, if $lock, otherwise clear it.
$user is a wikiname.

Return an error message on failure.

SMELL: there is a tremendous amount of potential for race
conditions using this locking approach.

=cut

sub setLock {
    my( $this, $lock, $user ) = @_;

    $user = $this->{session}->{user} unless $user;

    my $filename = $this->_makeFileName( '.lock' );
    if( $lock ) {
        my $lockTime = time();
        return $this->_saveFile( $filename, "$user\n$lockTime" );
    } else {
        unlink $filename
          or return "Failed to delete $filename: $!";
    }
    return undef;
}

=pod

---++ ObjectMethod isLocked( ) -> $boolean

See if a twiki lock exists. Return the lock user and lock time if it does.

=cut

sub isLocked {
    my( $this ) = @_;

    my $filename = $this->_makeFileName('.lock');
    if ( -e $filename ) {
        my $t = $this->{session}->{store}->readFile( $filename );
        return split( /\s+/, $t, 2 );
    }
    return ( undef, undef );
}

=pod

---++ ObjectMethod setLease( $lease )

   * =$lease= reference to lease hash, or undef if the existing lease is to be cleared.

Set an lease on the topic.

=cut

sub setLease {
    my( $this, $lease ) = @_;

    my $filename = $this->_makeFileName( '.lease' );
    if( $lease ) {
        return $this->_saveFile( $filename, join( "\n", %$lease ) );
    } elsif( -e $filename ) {
        unlink $filename
          or throw Error::Simple "Failed to delete $filename: $!";
    }
}

=pod

---++ ObjectMethod getLease() -> $lease

Get the current lease on the topic.

=cut

sub getLease {
    my( $this ) = @_;

    my $filename = $this->_makeFileName( '.lease' );
    if ( -e $filename ) {
        my $t = $this->{session}->{store}->readFile( $filename );
        my $lease = { split( /\n/, $t ) };
        return $lease;
    }
    return undef;
}

sub _saveAttachment {
    my( $this, $theTmpFilename ) = @_;

    # before save, create directories if they don't exist
    my $tempPath = $this->_makePubWebDir();
    if( ! -e $tempPath ) {
        umask( 0 );
        mkdir( $tempPath,
               $TWiki::cfg{RCS}{dirPermission} )
          or return "mkdir failed: $!";
    }
    $tempPath = $this->_makeFileDir( 1 );
    if( ! -e $tempPath ) {
        umask( 0 );
        mkdir( $tempPath, 0775 )
          or return "mkdir failed: $!";
    }

    # FIXME share with move - part of init?

    # save uploaded file
    my $newFile = $this->{file};
    copy($theTmpFilename, $newFile)
      or return "copy($theTmpFilename, $newFile) failed: $!";

    # FIXME more consistant way of dealing with errors
    umask( 002 );
    chmod( 0644, $newFile ); # FIXME config permission for new attachment

    return '';
}

sub _saveFile {
    my( $this, $name, $text ) = @_;

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
    my( $this, $filename, $text ) = @_;

    if( $this->{attachment} ) {
        my $tmpFilename = $$text;
        return $this->_saveAttachment( $tmpFilename );
    } else {
        return $this->_saveFile( $filename, $$text );
    }
}

sub _readFile {
    my( $this, $name ) = @_;
    my $data = '';
    undef $/; # set to read to EOF
    open( IN_FILE, "<$name" )
      or return '';
    binmode IN_FILE;
    $data = <IN_FILE>;
    $/ = "\n";
    close( IN_FILE );
    $data = '' unless $data; # no undefined
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
    my( $this, $extension ) = @_;

    $extension ||= '';

    my $file = '';
    my $extra = '';
    my $web = $this->{web};
    my $topic = $this->{topic};
    my $attachment = $this->{attachment};

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
    my( $this, $attachment, $extension) = @_;

    $extension = '' if( ! $extension );

    my $web = $this->{web};
    my $topic = $this->{topic};

    my $dir = '';
    if( ! $attachment ) {
        if( $extension eq ",v" && $TWiki::cfg{RCS}{useSubDir} &&
            -d "$TWiki::cfg{DataDir}/$web/RCS" ) {
            $dir = "$TWiki::cfg{DataDir}/$web/RCS";
        } else {
            $dir = "$TWiki::cfg{DataDir}/$web";
        }
    } else {
        my $suffix = '';
        if ( $extension eq ",v" && $TWiki::cfg{RCS}{useSubDir} &&
             -d "$TWiki::cfg{DataDir}/$web/RCS" ) {
            $suffix = "/RCS";
        }
        $dir = "$TWiki::cfg{PubDir}/$web/$topic$suffix";
    }

    return TWiki::Sandbox::untaintUnchecked( $dir );
}

sub _makePubWebDir {
    my( $this ) = @_;

    my $dir = $TWiki::cfg{PubDir} . "/" . $this->{web};

    return TWiki::Sandbox::untaintUnchecked( $dir );
}

sub _mkTmpFilename {
    my $tmpdir = File::Spec->tmpdir();
    my $file = _mktemp( 'twikiAttachmentXXXXXX', $tmpdir );
    return File::Spec->catfile($tmpdir, $file);
}

# Adapted from CPAN - File::MkTemp
sub _mktemp {
    my ($template,$dir,$ext,$keepgen,$lookup);
    my (@template,@letters);

    ASSERT(@_ == 1 || @_ == 2 || @_ == 3) if DEBUG;

    ($template,$dir,$ext) = @_;
    @template = split //, $template;

    ASSERT($template =~ /XXXXXX$/) if DEBUG;

    if ($dir){
        ASSERT(-e $dir) if DEBUG;
    }

    @letters =
      split(//,'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ');

    $keepgen = 1;

    while ($keepgen){
        for (my $i = $#template; $i >= 0 && ($template[$i] eq 'X'); $i--){
            $template[$i] = $letters[int(rand 52)];
        }

        undef $template;

        $template = pack 'a' x @template, @template;

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

Returns '' if okay, otherwise an error string.

*Virtual method* - must be implemented by subclasses

=cut

=pod

---++ ObjectMethod initText()

Initialise a text file.

Must be provided by subclasses.

Returns '' if okay, otherwise an error string.

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

---++ ObjectMethod getRevisionAtTime($time) -> $rev

Get a single-digit version number for the rev that was alive at the
given epoch-secs time, or undef it none could be found.

*Virtual method* - must be implemented by subclasses

=cut

1;
