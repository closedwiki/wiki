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

---+ package TWiki::Store::RcsWrap

This package does not publish any methods. It implements the
virtual methods of the [[TWikiStoreRcsFileDotPm][TWiki::Store::RcsFile]] superclass.

Wrapper around the RCS commands required by TWiki.
There is one of these object for each file stored under RCS.

=cut

package TWiki::Store::RcsWrap;

use TWiki;
use File::Copy;
use TWiki::Store::RcsFile;
use TWiki::Time;

@ISA = qw(TWiki::Store::RcsFile);

use strict;
use Assert;

# implements RcsFile
sub new {
    my( $class, $session, $web, $topic, $attachment ) = @_;
    ASSERT(ref($session) eq "TWiki") if DEBUG;
    my $self =
      bless(new TWiki::Store::RcsFile( $session, $web, $topic, $attachment ),
            $class );
    $self->init();
    return $self;
}

# implements RcsFile
sub initBinary {
    my( $self ) = @_;

    $self->{binary} = 1;

    my ( $rcsOutput, $exit ) =
      $self->{session}->{sandbox}->readFromProcess
        ( $TWiki::cfg{RCS}{initBinaryCmd},
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

# implements RcsFile
sub initText {
    my( $self ) = @_;

    $self->{binary} = 0;

    my ( $rcsOutput, $exit ) =
      $self->{session}->{sandbox}->readFromProcess
        ( $TWiki::cfg{RCS}{initTextCmd},
          FILENAME => $self->{file} );
    if( $exit && $rcsOutput ) {
        $rcsOutput = "$TWiki::cfg{RCS}{initTextCmd}\n$rcsOutput";
    } elsif( ! -e $self->{rcsFile} ) {
        # Sometimes (on Windows?) rcs file not formed, so check for it
        $rcsOutput =
          "$TWiki::cfg{RCS}{initTextCmd}\nFailed to create history file $self->{rcsFile}";
    }
    return $rcsOutput;
}

# implements RcsFile
# $date is ignored
sub addRevision {
    my( $self, $text, $comment, $user, $date ) = @_;
    my $error = $self->_lock();
    return $error if $error;
    $error = $self->_save( $self->{file}, \$text );
    return $error if $error;
    return $self->_ci( $comment, $user );
}

# implements RcsFile
sub replaceRevision {
    my( $self, $text, $comment, $user, $date ) = @_;

    my $rev = $self->numRevisions();

    # update repository with same userName and date
    if( $rev == 1 ) {
        # initial revision, so delete repository file and start again
        unlink $self->{rcsFile};
    } else {
        $self->_deleteRevision( $rev );
    }
    $self->_saveFile( $self->{file}, $text );
	$date = TWiki::Time::formatTime( $date , "\$rcs", "gmtime");

    my $error = $self->_lock();
    return $error if $error;

    my ($rcsOut, $exit) = $self->{session}->{sandbox}->readFromProcess
      ( $TWiki::cfg{RCS}{ciDateCmd},
        DATE => $date,
        USERNAME => $user,
        FILENAME => $self->{file} );
    if( $exit ) {
        $rcsOut = "$TWiki::cfg{RCS}{ciDateCmd}\n$rcsOut";
        return $rcsOut;
    }
    chmod( 0644, $self->{file} );

    return undef;
}

# implements RcsFile
sub deleteRevision {
    my( $self ) = @_;
    my $rev = $self->numRevisions();
    return undef if( $rev == 1 );
    return $self->_deleteRevision( $rev );
}

sub _deleteRevision {
    my( $self, $rev ) = @_;

    # delete latest revision (unlock (may not be needed), delete revision)
    $self->{session}->{sandbox}->readFromProcess
      ( $TWiki::cfg{RCS}{unlockCmd},
        FILENAME => $self->{file} );

    chmod( 0644, $self->{file} );

    my ($rcsOut, $exit) = $self->{session}->{sandbox}->readFromProcess
      ( $TWiki::cfg{RCS}{delRevCmd},
        REVISION => "1.$rev",
        FILENAME => $self->{file} );
    if( $exit ) {
        $rcsOut = "$TWiki::cfg{RCS}{delRevCmd}\n$rcsOut";
        return $rcsOut;
    }
}

# implements RcsFile
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
          $self->{session}->{sandbox}->readFromProcess
            ( $TWiki::cfg{RCS}{tmpBinaryCmd},
              FILENAME => $tmpRevFile );
        $file = $tmpfile;
        $coCmd =~ s/-p%REVISION%/-r%REVISION%/;
    }
    my ($text) = $self->{session}->{sandbox}->readFromProcess
      ( $coCmd,
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

sub numRevisions {
    my( $self ) = @_;

    if( ! -e $self->{rcsFile} ) {
       return 0;
    }

    my ($rcsOutput) =
      $self->{session}->{sandbox}->readFromProcess
        ( $TWiki::cfg{RCS}{histCmd},
          FILENAME => $self->{rcsFile} );
    if( $rcsOutput =~ /head:\s+\d+\.(\d+)\n/ ) {
        return $1;
    } else {
        $ TWiki::Store::RcsFile::lastError = $rcsOutput;
        return 0; # Note this hides possible errors
    }
}

# implements RcsFile
sub getRevisionInfo {
    my( $self, $version ) = @_;

    my $rcsError = "";
    my( $dummy, $rev, $date, $user, $comment );
    if ( -e $self->{rcsFile} ) {
        $version = $self->numRevisions() unless $version;
        my $cmd = $TWiki::cfg{RCS}{infoCmd};
        my ( $rcsOut, $exit ) = $self->{session}->{sandbox}->readFromProcess
          ( $cmd,
            REVISION => "1.$version",
            FILENAME => $self->{rcsFile} );
       $rcsError = "Error with $cmd, output: $rcsOut" if( $exit );
       if( ! $rcsError ) {
            $rcsOut =~ /date: (.*?);  author: (.*?);.*\n(.*)\n/;
            $date = $1 || "";
            $user = $2 || "";
            $comment = $3 || "";
            $date = TWiki::Time::parseTime( $date );
            $rcsOut =~ /revision 1.([0-9]*)/;
            $rev = $1;
            $rcsError = "Rev missing from revision file $self->{rcsFile}" unless( $rev );
       }
    } else {
       $rcsError = "Revision file $self->{rcsFile} is missing";
    }

    ( $dummy, $rev, $date, $user, $comment ) =
      $self->_getRevisionInfoDefault() if( $rcsError );

    return( $rcsError, $rev, $date, $user, $comment );
}

# implements RcsFile
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
        $contextLines = "" unless defined($contextLines);
        ( $tmp, $exit ) =
          $self->{session}->{sandbox}->readFromProcess
            ( $TWiki::cfg{RCS}{diffCmd},
              REVISION1 => "1.$rev1",
              REVISION2 => "1.$rev2",
              FILENAME => $self->{rcsFile},
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

sub _ci {
    my( $self, $comment, $user ) = @_;

    $comment = "none" unless( $comment );
    my ($rcsOutput, $exit) = $self->{session}->{sandbox}->readFromProcess
      ( $TWiki::cfg{RCS}{ciCmd},
        USERNAME => $user,
        FILENAME => $self->{file},
        COMMENT => $comment );

    if( $exit && $rcsOutput ) {
        $rcsOutput = "$TWiki::cfg{RCS}{ciCmd}\n$rcsOutput";
    }

    # A ci -u leaves the file unwriteable, so fix that. We are still
    # rather mean with the permissions, but at least the webserver user
    # can write!
    chmod( 0644, $self->{file} );

    return $rcsOutput;
}

sub _lock {
    my $self = shift;

    return undef unless -e $self->{rcsFile};

    # Try and get a lock on the file
    my ($rcsOutput, $exit) = $self->{session}->{sandbox}->readFromProcess
      ( $TWiki::cfg{RCS}{lockCmd}, FILENAME => $self->{file} );

    if( $exit && $rcsOutput ) {
        $rcsOutput = "$TWiki::cfg{RCS}{lockCmd}\n$rcsOutput";
        return $rcsOutput;
    }
    chmod( 0644, $self->{file} );

    return undef;
}

1;
