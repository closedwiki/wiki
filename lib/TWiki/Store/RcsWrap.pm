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

=pod

---+ UNPUBLISHED package TWiki::Store::RcsWrap

Wrapper around the RCS commands required by TWiki.
There is one of these object for each file stored under RCS.
This object is PACKAGE PRIVATE to Store, and should never be
used from anywhere else.

=cut

package TWiki::Store::RcsWrap;

use TWiki;
use File::Copy;
use TWiki::Store::RcsFile;
@ISA = qw(TWiki::Store::RcsFile);

use strict;
use Assert;

sub new {
    my( $class, $session, $web, $topic, $attachment ) = @_;
    ASSERT(ref($session) eq "TWiki") if DEBUG;
    my $self =
      bless(new TWiki::Store::RcsFile( $session, $web, $topic, $attachment ),
            $class );
    $self->init();
    return $self;
}

# ======================
# Returns false if okay, otherwise an error string
sub _binaryChange {
    my( $self ) = @_;
    if( $self->{binary} ) {
        # Can only do something when changing to binary
        my $file = $self->{file};
        my ( $rcsOutput, $exit ) =
          $self->{session}->{sandbox}->readFromProcess ( $TWiki::cfg{RCS}{initBinaryCmd},
                                   FILENAME => $self->{file} );
        if( $exit && $rcsOutput ) {
           $rcsOutput = "$TWiki::cfg{RCS}{initBinaryCmd}\n$rcsOutput";
        } elsif( ! -e $self->{rcsFile} ) {
            # Sometimes (on Windows?) rcs file not formed, so check for it
            $rcsOutput =
              "$TWiki::cfg{RCS}{initBinaryCmd}\nFailed to create history file $self->{rcsFile}";
        }
        return $rcsOutput;
    }
    return "";
}

# ======================
=pod

---++ ObjectMethod addRevision (   $text, $comment, $user ) -> $error

Add new revision. Replace file (if exists) with text.
$user is a wikiname.

=cut

sub addRevision {
    my( $self, $text, $comment, $user ) = @_;
    $self->_save( $self->{file}, \$text );
    return $self->_ci( $self->{file}, $comment, $user );
}

# ======================
=pod

---++ ObjectMethod replaceRevision($text, $comment, $user, $date) -> $error

Replace the top revision.
Return non empty string with error message if there is a problem.
$date is in epoch seconds.
$user is a wikiname.

=cut

sub replaceRevision {
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
      ( $TWiki::cfg{RCS}{ciDateCmd},
        DATE => $date,
        USERNAME => $user,
        FILENAME => [$file, $rcsFile] );
    if( $exit ) {
        $rcsOut = "$TWiki::cfg{RCS}{ciDateCmd}\n$rcsOut";
        return $rcsOut;
    }
    return "";
}

# ======================
=pod

---++ ObjectMethod deleteRevision() -> $error

Return with empty string if only one revision.

=cut

sub deleteRevision {
    my( $self ) = @_;
    my $rev = $self->numRevisions();
    return "" if( $rev == 1 );
    return $self->_deleteRevision( $rev );
}

# ======================
sub _deleteRevision {
    my( $self, $rev ) = @_;

    # delete latest revision (unlock, delete revision, lock)
    my $file    = $self->{file};
    my $rcsFile = $self->{rcsFile};

    my ($rcsOut, $exit) = $self->{session}->{sandbox}->readFromProcess
      ( $TWiki::cfg{RCS}{unlockCmd}, FILENAME => [$file, $rcsFile] );
    if( $exit ) {
        $rcsOut = "$TWiki::cfg{RCS}{unlockCmd}\n$rcsOut";
        return $rcsOut;
    }

    ($rcsOut, $exit) = $self->{session}->{sandbox}->readFromProcess
      ( $TWiki::cfg{RCS}{delRevCmd},
        REVISION => "1.$rev",
        FILENAME => [$file, $rcsFile] );
    if( $exit ) {
        $rcsOut = "$TWiki::cfg{RCS}{delRevCmd}\n$rcsOut";
        return $rcsOut;
    }

    ($rcsOut, $exit) =
      $self->{session}->{sandbox}->readFromProcess( $TWiki::cfg{RCS}{lockCmd},
                              REVISION => "1.$rev",
                              FILENAME => [$file, $rcsFile] );
    if( $exit ) {
        $rcsOut = "$TWiki::cfg{RCS}{lockCmd}\n$rcsOut";
        return $rcsOut;
    }
}

# ======================
=pod

---++ ObjectMethod getRevision($version) -> $text

Get the text for a given revision. The version number must be an integer.

=cut

sub getRevision {
    my( $self, $version ) = @_;

    my $tmpfile = "";
    my $tmpRevFile = "";
    my $coCmd = $TWiki::cfg{RCS}{coCmd};
    my $file = $self->{file};
    if( $TWiki::cfg{OS} eq "WINDOWS" ) {
        # Need to take temporary copy of topic, check it out to file,
        # then read that
        # Need to put RCS into binary mode to avoid extra \r appearing and
        # read from binmode file rather than stdout to avoid early file
        # read termination
        $tmpfile = $self->_mkTmpFilename();
        $tmpRevFile = "$tmpfile,v";
        copy( $self->{rcsFile}, $tmpRevFile );
        my ($tmp) =
          $self->{session}->{sandbox}->readFromProcess( $TWiki::cfg{RCS}{tmpBinaryCmd},
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

---++ ObjectMethod numRevisions() -> $integer

Find out how many revisions there are. If there is a problem, such
as a nonexistent file, returns the null string.

=cut

sub numRevisions {
    my( $self ) = @_;
    my $rcsFile = $self->{rcsFile};
    if( ! -e $rcsFile ) {
       return "";
    }

    my ($rcsOutput) =
      $self->{session}->{sandbox}->readFromProcess( $TWiki::cfg{RCS}{histCmd},
                                        FILENAME => $rcsFile );
    if( $rcsOutput =~ /head:\s+\d+\.(\d+)\n/ ) {
        return $1;
    } else {
        return ""; # Note this hides possible errors
    }
}

# ======================
=pod

---++ ObjectMethod getRevisionInfo($version) -> ($rcsError, $rev, $date, $user, $comment)

A version number of 0 or undef will return info on the _latest_ revision.

If revision file is missing, information based on actual file is returned.

Date return in epoch seconds. Revision returned as a number.
User returned as a wikiname.

=cut

sub getRevisionInfo {
    my( $self, $version ) = @_;

    my $rcsFile = $self->{rcsFile};
    my $rcsError = "";
    my( $dummy, $rev, $date, $user, $comment );
    if ( -e $rcsFile ) {
        unless ( $version ) {
            $version = $self->numRevisions();
        }
        my $cmd = $TWiki::cfg{RCS}{infoCmd};
        my ( $rcsOut, $exit ) = $self->{session}->{sandbox}->readFromProcess
          ( $cmd,
            REVISION => "1.$version",
            FILENAME => $rcsFile );
       $rcsError = "Error with $cmd, output: $rcsOut" if( $exit );
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

---++ ObjectMethod revisionDiff (   $rev1, $rev2, $contextLines  ) -> \@diffArray
rev2 newer than rev1.
Return reference to an array of [ diffType, $right, $left ]

=cut

sub revisionDiff {
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
          $self->{session}->{sandbox}->readFromProcess( $TWiki::cfg{RCS}{diffCmd},
                                  REVISION1 => "1.$rev1",
                                  REVISION2 => "1.$rev2",
                                  FILENAME => $rcsFile,
                                  CONTEXT => $contextLines );
        $error = "Error $exit when running $TWiki::cfg{RCS}{diffCmd}";
    }
	
    return ($error, parseRevisionDiff( $tmp ) );
}

=pod

---++ StaticMethod parseRevisionDiff( $text ) -> \@diffArray

| Description: | parse the text into an array of diff cells |
| #Description: | unlike Algorithm::Diff I concatinate lines of the same diffType that are sqential (this might be something that should be left up to the renderer) |
| Parameter: =$text= | currently unified or rcsdiff format |
| Return: =\@diffArray= | reference to an array of [ diffType, $right, $left ] |
| TODO: | move into RcsFile and add indirection in Store |

=cut

sub parseRevisionDiff {
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
    my( $self, $file, $comment, $user ) = @_;

    # Check that we can write the file being checked in. This won't check
    # that $file,v is writable, but it _will_ trap 99% of all common
    # errors (permissions on directory tree)
    return "$file is not writable" unless ( -w $file );

    $comment = "none" unless( $comment );

    my ($rcsOutput, $exit) = $self->{session}->{sandbox}->readFromProcess
      ( $TWiki::cfg{RCS}{ciCmd},
        USERNAME => $user,
        FILENAME => $file,
        COMMENT => $comment );
    if( $exit && $rcsOutput =~ /no lock set by/ ) {
        # Try and break lock, setting new lock and doing ci again
        # Assume it worked, as not sure how to trap failure
        $self->{session}->{sandbox}->readFromProcess( $TWiki::cfg{RCS}{breakLockCmd},
                                FILENAME => $file);

        # re-do the ci command
        ( $rcsOutput, $exit ) =
          $self->{session}->{sandbox}->readFromProcess( $TWiki::cfg{RCS}{ciCmd},
                                  USERNAME => $user,
                                  FILENAME => $file,
                                  COMMENT => $comment );
    }
    if( $exit && $rcsOutput ) {
        $rcsOutput = "$TWiki::cfg{RCS}{ciCmd}\n$rcsOutput";
    }
    return $rcsOutput;
}

1;
