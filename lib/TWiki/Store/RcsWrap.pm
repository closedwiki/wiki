# Module of TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 1999-2003 Peter Thoeny, peter@thoeny.com
# Copyright (C) 2002 John Talintyre, john.talintyre@btinternet.com
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
# Wrapper around the RCS commands required by TWiki

=begin twiki

---+ TWiki::Store::RcsWrap Module

This module calls rcs

=cut

package TWiki::Store::RcsWrap;

use TWiki;
use File::Copy;
use TWiki::Store::RcsFile;
@ISA = qw(TWiki::Store::RcsFile);

use strict;

## Details of settings
#
# attachAsciiPath         Defines which attachments will be treated as ASCII in RCS
# initBinaryCmd           RCS init command, needed when initialising a file as binary
# ciCmd                   RCS check in command
# coCmd                   RCS check out command
# histCmd                 RCS history command
# infoCmd                 RCS history on revision command
# diffCmd                 RCS revision diff command
# breakLockCmd            RCS for breaking a lock
# ciDateCmd               RCS check in command with date
# delRevCmd               RCS delete revision command
# unlockCmd               RCS unlock command
# lockCmd                 RCS lock command
#
# (from RcsFile)
# dataDir
# pubDir
# attachAsciiPath         Defines which attachments will be automatically treated as ASCII in RCS
# dirPermission           File security for new directories

sub new {
    my( $class, $session, $web, $topic, $attachment, $settings ) = @_;
    my $self =
      bless(new TWiki::Store::RcsFile( $session, $web, $topic, $attachment, $settings ),
            $class );
    foreach my $key ( "initBinaryCmd", "tmpBinaryCmd", "ciCmd", "coCmd",
                      "histCmd", "infoCmd", "diffCmd", "breakLockCmd",
                      "ciDateCmd", "delRevCmd", "unlockCmd", "lockCmd" ) {
        $self->{$key} = $settings->{$key};
    }
    $self->init();
    return $self;
}

#TODO set from TWiki.cfg
my $cmdQuote = "'";

# ======================
# Returns false if okay, otherwise an error string
sub _binaryChange
{
    my( $self ) = @_;
    if( $self->getBinary() ) {
        # Can only do something when changing to binary
        my $file = $self->{file};
        my ( $rcsOutput, $exit ) =
          $self->{session}->{sandbox}->readFromProcess ( $self->{initBinaryCmd},
                                   FILENAME => $self->{file} );
        if( $exit && $rcsOutput ) {
           $rcsOutput = "$self->{initBinaryCmd}\n$rcsOutput";
        } elsif( ! -e $self->{rcsFile} ) {
            # Sometimes (on Windows?) rcs file not formed, so check for it
            $rcsOutput =
              "$self->{initBinaryCmd}\nFailed to create history file $self->{rcsFile}";
        }
        return $rcsOutput;
    }
    return "";
}

# ======================
=pod

---++ sub addRevision (  $self, $text, $comment, $userName  )

Add new revision. Replace file (if exists) with text

=cut

sub addRevision
{
    my( $self, $text, $comment, $userName ) = @_;
    
    $self->_save( $self->{file}, \$text );
    return $self->_ci( $self->{file}, $comment, $userName );
}

# ======================
=pod

---++ sub replaceRevision (  $self, $text, $comment, $user, $date  )

Replace the top revision
Return non empty string with error message if there is a problem
| $date | is on epoch seconds |

=cut

sub replaceRevision
{
    my( $self, $text, $comment, $user, $date ) = @_;

    my $rev = $self->numRevisions();
    my $file    = $self->{file};
    my $rcsFile = $self->{rcsFile};

    # update repository with same userName and date
    if( $rev == 1 ) {
        # initial revision, so delete repository file and start again
        unlink $rcsFile;
    } else {
        $self->_deleteRevision( $rev );
    }
    $self->_saveFile( $self->{file}, $text );
	$date = TWiki::formatTime( $date , "\$rcs", "gmtime");

    my ($rcsOut, $exit) = $self->{session}->{sandbox}->readFromProcess
      ( $self->{ciDateCmd},
        DATE => $date,
        USERNAME => $user,
        FILENAME => [$file, $rcsFile] );
    if( $exit ) {
        $rcsOut = "$self->{ciDateCmd}\n$rcsOut";
        return $rcsOut;
    }
    return "";
}

# ======================
=pod

---++ sub deleteRevision (  $self  )

Return with empty string if only one revision.

=cut

sub deleteRevision
{
    my( $self ) = @_;
    my $rev = $self->numRevisions();
    return "" if( $rev == 1 );
    return $self->_deleteRevision( $rev );
}

# ======================
sub _deleteRevision
{
    my( $self, $rev ) = @_;

    # delete latest revision (unlock, delete revision, lock)
    my $file    = $self->{file};
    my $rcsFile = $self->{rcsFile};

    my ($rcsOut, $exit) = $self->{session}->{sandbox}->readFromProcess
      ( $self->{unlockCmd}, FILENAME => [$file, $rcsFile] );
    if( $exit ) {
        $rcsOut = "$self->{unlockCmd}\n$rcsOut";
        return $rcsOut;
    }

    ($rcsOut, $exit) = $self->{session}->{sandbox}->readFromProcess
      ( $self->{delRevCmd},
        REVISION => "1.$rev",
        FILENAME => [$file, $rcsFile] );
    if( $exit ) {
        $rcsOut = "$self->{delRevCmd}\n$rcsOut";
        return $rcsOut;
    }

    ($rcsOut, $exit) =
      $self->{session}->{sandbox}->readFromProcess( $self->{lockCmd},
                              REVISION => "1.$rev",
                              FILENAME => [$file, $rcsFile] );
    if( $exit ) {
        $rcsOut = "$self->{lockCmd}\n$rcsOut";
        return $rcsOut;
    }
}

# ======================
=pod

---++ sub getRevision (  $self, $version  )

Get the text for a given revision. The version number must be an integer.

=cut

sub getRevision
{
    my( $self, $version ) = @_;

    my $tmpfile = "";
    my $tmpRevFile = "";
    my $coCmd = $self->{coCmd};
    my $file = $self->{file};
    if( $TWiki::OS eq "WINDOWS" ) {
        # Need to take temporary copy of topic, check it out to file,
        # then read that
        # Need to put RCS into binary mode to avoid extra \r appearing and
        # read from binmode file rather than stdout to avoid early file
        # read termination
        $tmpfile = $self->_mkTmpFilename();
        $tmpRevFile = "$tmpfile,v";
        copy( $self->{rcsFile}, $tmpRevFile );
        my ($tmp) =
          $self->{session}->{sandbox}->readFromProcess( $self->{tmpBinaryCmd},
                                  FILENAME => $tmpRevFile );
        $file = $tmpfile;
        $coCmd =~ s/-p%REVISION%/-r%REVISION%/;
    }
    my ($text) =
      $self->{session}->{sandbox}->readFromProcess( $coCmd,
                              REVISION => "1.$version",
                              FILENAME => $file );

    if( $tmpfile ) {
        $text = $self->_readFile( $tmpfile );
        # SMELL: Is untainting really necessary here?
        unlink TWiki::Sandbox::untaintUnchecked( $tmpfile );
        unlink TWiki::Sandbox::untaintUnchecked( $tmpRevFile );
    }
    return $text;
}

# ======================
=pod

---++ sub numRevisions (  $self  )

Find out how many revisions there are. If there is a problem, such
as a nonexistant file, returns the null string.

=cut

sub numRevisions
{
    my( $self ) = @_;
    my $rcsFile = $self->{rcsFile};
    if( ! -e $rcsFile ) {
       return "";
    }

    my ($rcsOutput) =
      $self->{session}->{sandbox}->readFromProcess( $self->{histCmd},
                                        FILENAME => $rcsFile );
    if( $rcsOutput =~ /head:\s+\d+\.(\d+)\n/ ) {
        return $1;
    } else {
        return ""; # Note this hides possible errors
    }
}

# ======================
=pod

---++ sub getRevisionInfo (  $self, $version  )

A version number of 0 or undef will return info on the _latest_ revision.

If revision file is missing, information based on actual file is returned.

Date return in epoch seconds. Revision returned as a number.

=cut

sub getRevisionInfo
{
    my( $self, $version ) = @_;

    my $rcsFile = $self->{rcsFile};
    my $rcsError = "";
    my( $dummy, $rev, $date, $user, $comment );
    if ( -e $rcsFile ) {
        unless ( $version ) {
            $version = $self->numRevisions();
        }
        my $cmd = $self->{infoCmd};
        my ( $rcsOut, $exit ) = $self->{session}->{sandbox}->readFromProcess
          ( $cmd,
            REVISION => "1.$version",
            FILENAME => $rcsFile );
       $rcsError = "Error with $self->{infoCmd}, output: $rcsOut" if( $exit );
       if( ! $rcsError ) {
            $rcsOut =~ /date: (.*?);  author: (.*?);.*\n(.*)\n/;
            $date = $1 || "";
            $user = $2 || "";
            $comment = $3 || "";
            $date = TWiki::Store::RcsFile::_rcsDateTimeToEpoch( $date );
            $rcsOut =~ /revision 1.([0-9]*)/;
            $rev = $1;
            $rcsError = "Rev missing from revision file $rcsFile" unless( $rev );
       }
    } else {
       $rcsError = "Revision file $rcsFile is missing";
    }

    ( $dummy, $rev, $date, $user, $comment ) =
      $self->_getRevisionInfoDefault() if( $rcsError );

    return( $rcsError, $rev, $date, $user, $comment );
}

# ======================
=pod

---++ sub revisionDiff (  $self, $rev1, $rev2, $contextLines  )
# rev2 newer than rev1

| Return: =\@diffArray= | reference to an array of [ diffType, $right, $left ] |

=cut

sub revisionDiff
{
    my( $self, $rev1, $rev2, $contextLines ) = @_;
    
    my $error = "";

    my $tmp = "";
    my $exit;
    if ( $rev1 eq "1" && $rev2 eq "1" ) {
        my $text = $self->getRevision(1);
        $tmp = "1a1\n";
        foreach( split( /\n/, $text ) ) {
           $tmp = "$tmp> $_\n";
        }
    } else {
        my $rcsFile = $self->{rcsFile};
        $contextLines = "" unless defined($contextLines);
        ( $tmp, $exit ) =
          $self->{session}->{sandbox}->readFromProcess( $self->{diffCmd},
                                  REVISION1 => "1.$rev1",
                                  REVISION2 => "1.$rev2",
                                  FILENAME => $rcsFile,
                                  CONTEXT => $contextLines );
        $error = "Error $exit when running $self->{diffCmd}";
    }
	
    return ($error, parseRevisionDiff( $tmp ) );
}

# =========================
=pod

---+++ parseRevisionDiff( $text ) ==> \@diffArray

| Description: | parse the text into an array of diff cells |
| #Description: | unlike Algorithm::Diff I concatinate lines of the same diffType that are sqential (this might be something that should be left up to the renderer) |
| Parameter: =$text= | currently unified or rcsdiff format |
| Return: =\@diffArray= | reference to an array of [ diffType, $right, $left ] |
| TODO: | move into RcsFile and add indirection in Store |

=cut
# -------------------------
sub parseRevisionDiff
{
    my( $text ) = @_;

    my ( $diffFormat ) = "normal"; #or rcs, unified...
    my ( @diffArray ) = ();

    $diffFormat = "unified" if ( $text =~ /^---/ );

    $text =~ s/\r//go;  # cut CR

    my $lineNumber=1;
    if ( $diffFormat eq "unified" ) {
        foreach( split( /\n/, $text ) ) {
	    if ( $lineNumber > 3 ) {   #skip the first 2 lines (filenames)
 	   	    if ( /@@ [-+]([0-9]+)([,0-9]+)? [-+]([0-9]+)(,[0-9]+)? @@/ ) {
	    	        #line number
		        push @diffArray, ["l", $1, $3];
		    } elsif ( /^\-/ ) {
		        s/^\-//go;
		        push @diffArray, ["-", $_, ""];
		    } elsif ( /^\+/ ) {
		        s/^\+//go;
		        push @diffArray, ["+", "", $_];
		    } else {
	  		s/^ (.*)$/$1/go;
			push @diffArray, ["u", $_, $_];
		    }
	    }
	    $lineNumber = $lineNumber + 1;
       	 }
    } else {
        #"normal" rcsdiff output 
        foreach( split( /\n/, $text ) ) {
    	    if ( /^([0-9]+)[0-9\,]*([acd])([0-9]+)/ ) {
    	        #line number
	        push @diffArray, ["l", $1, $3];
	    } elsif ( /^</ ) {
	        s/^< //go;
	            push @diffArray, ["-", $_, ""];
	    } elsif ( /^>/ ) {
	        s/^> //go;
	            push @diffArray, ["+", "", $_];
	    } else {
	        #empty lines and the --- selerator in the diff
	        #push @diffArray, ["u", "$_", $_];
	    }
        }
    }
    return \@diffArray;
}

# ======================
sub _ci {
    my( $self, $file, $comment, $userName ) = @_;

    # Check that we can write the file being checked in. This won't check
    # that $file,v is writable, but it _will_ trap 99% of all common
    # errors (permissions on directory tree)
    return "$file is not writable" unless ( -w $file );

    $comment = "none" unless( $comment );

    my ($rcsOutput, $exit) = $self->{session}->{sandbox}->readFromProcess
      ( $self->{ciCmd},
        USERNAME => $userName,
        FILENAME => $file,
        COMMENT => $comment );
    if( $exit && $rcsOutput =~ /no lock set by/ ) {
        # Try and break lock, setting new lock and doing ci again
        # Assume it worked, as not sure how to trap failure
        $self->{session}->{sandbox}->readFromProcess( $self->{breakLockCmd},
                                FILENAME => $file);

        # re-do the ci command
        ( $rcsOutput, $exit ) =
          $self->{session}->{sandbox}->readFromProcess( $self->{ciCmd},
                                  USERNAME => $userName,
                                  FILENAME => $file,
                                  COMMENT => $comment );
    }
    if( $exit && $rcsOutput ) {
        $rcsOutput = "$self->{ciCmd}\n$rcsOutput";
    }
    return $rcsOutput;
}

1;
