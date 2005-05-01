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
    ASSERT(ref($session) eq 'TWiki') if DEBUG;
    my $this =
      bless(new TWiki::Store::RcsFile( $session, $web, $topic, $attachment ),
            $class );
    $this->init();
    return $this;
}

# implements RcsFile
sub initBinary {
    my( $this ) = @_;

    $this->{binary} = 1;

    my ( $rcsOutput, $exit ) =
      $this->{session}->{sandbox}->readFromProcess
        ( $TWiki::cfg{RCS}{initBinaryCmd},
          FILENAME => $this->{file} );
    if( $exit && $rcsOutput ) {
        $rcsOutput = "$TWiki::cfg{RCS}{initBinaryCmd}\n$rcsOutput";
    } elsif( ! -e $this->{rcsFile} ) {
        # Sometimes (on Windows?) rcs file not formed, so check for it
        $rcsOutput =
          "$TWiki::cfg{RCS}{initBinaryCmd}\nFailed to create history file $this->{rcsFile}";
    }
    return $rcsOutput;
}

# implements RcsFile
sub initText {
    my( $this ) = @_;

    $this->{binary} = 0;

    my ( $rcsOutput, $exit ) =
      $this->{session}->{sandbox}->readFromProcess
        ( $TWiki::cfg{RCS}{initTextCmd},
          FILENAME => $this->{file} );
    if( $exit && $rcsOutput ) {
        $rcsOutput = "$TWiki::cfg{RCS}{initTextCmd}\n$rcsOutput";
    } elsif( ! -e $this->{rcsFile} ) {
        # Sometimes (on Windows?) rcs file not formed, so check for it
        $rcsOutput =
          "$TWiki::cfg{RCS}{initTextCmd}\nFailed to create history file $this->{rcsFile}";
    }
    return $rcsOutput;
}

# implements RcsFile
# $date is ignored
sub addRevision {
    my( $this, $text, $comment, $user, $date ) = @_;
    my $error = $this->_lock();
    return $error if $error;
    $error = $this->_save( $this->{file}, \$text );
    return $error if $error;
    return $this->_ci( $comment, $user );
}

# implements RcsFile
sub replaceRevision {
    my( $this, $text, $comment, $user, $date ) = @_;

    my $rev = $this->numRevisions();

    # update repository with same userName and date
    if( $rev == 1 ) {
        # initial revision, so delete repository file and start again
        unlink $this->{rcsFile};
    } else {
        $this->_deleteRevision( $rev );
    }
    $this->_saveFile( $this->{file}, $text );
	$date = TWiki::Time::formatTime( $date , '$rcs', 'gmtime');

    my $error = $this->_lock();
    return $error if $error;

    my ($rcsOut, $exit) = $this->{session}->{sandbox}->readFromProcess
      ( $TWiki::cfg{RCS}{ciDateCmd},
        DATE => $date,
        USERNAME => $user,
        FILENAME => $this->{file} );
    if( $exit ) {
        $rcsOut = "$TWiki::cfg{RCS}{ciDateCmd}\n$rcsOut";
        return $rcsOut;
    }
    chmod( 0644, $this->{file} );

    return undef;
}

# implements RcsFile
sub deleteRevision {
    my( $this ) = @_;
    my $rev = $this->numRevisions();
    return undef if( $rev == 1 );
    return $this->_deleteRevision( $rev );
}

sub _deleteRevision {
    my( $this, $rev ) = @_;

    # delete latest revision (unlock (may not be needed), delete revision)
    $this->{session}->{sandbox}->readFromProcess
      ( $TWiki::cfg{RCS}{unlockCmd},
        FILENAME => $this->{file} );

    chmod( 0644, $this->{file} );

    my ($rcsOut, $exit) = $this->{session}->{sandbox}->readFromProcess
      ( $TWiki::cfg{RCS}{delRevCmd},
        REVISION => "1.$rev",
        FILENAME => $this->{file} );
    if( $exit ) {
        $rcsOut = "$TWiki::cfg{RCS}{delRevCmd}\n$rcsOut";
        return $rcsOut;
    }
}

# implements RcsFile
sub getRevision {
    my( $this, $version ) = @_;

    my $tmpfile = '';
    my $tmpRevFile = '';
    my $coCmd = $TWiki::cfg{RCS}{coCmd};
    my $file = $this->{file};
    #SMELL: Why is this code here? The checkout works fine without this.
    if( 0 && $TWiki::cfg{OS} eq 'WINDOWS' ) {
        # Need to take temporary copy of topic, check it out to file,
        # then read that
        # Need to put RCS into binary mode to avoid extra \r appearing and
        # read from binmode file rather than stdout to avoid early file
        # read termination
        $tmpfile = $this->_mkTmpFilename();
        $tmpRevFile = "$tmpfile,v";
        copy( $this->{rcsFile}, $tmpRevFile );
        my ($tmp) =
          $this->{session}->{sandbox}->readFromProcess
            ( $TWiki::cfg{RCS}{tmpBinaryCmd},
              FILENAME => $tmpRevFile );
        $file = $tmpfile;
        $coCmd =~ s/-p%REVISION/-r%REVISION/;
    }
    my ($text) = $this->{session}->{sandbox}->readFromProcess
      ( $coCmd,
        REVISION => "1.$version",
        FILENAME => $file );

    if( $tmpfile ) {
        $text = $this->_readFile( $tmpfile );
        # SMELL: Is untainting really necessary here?
        unlink TWiki::Sandbox::untaintUnchecked( $tmpfile );
        unlink TWiki::Sandbox::untaintUnchecked( $tmpRevFile );
    }

    return $text;
}

sub numRevisions {
    my( $this ) = @_;

    if( ! -e $this->{rcsFile} ) {
       return 0;
    }

    my ($rcsOutput) =
      $this->{session}->{sandbox}->readFromProcess
        ( $TWiki::cfg{RCS}{histCmd},
          FILENAME => $this->{rcsFile} );
    if( $rcsOutput =~ /head:\s+\d+\.(\d+)\n/ ) {
        return $1;
    } else {
        $ TWiki::Store::RcsFile::lastError = $rcsOutput;
        return 0; # Note this hides possible errors
    }
}

# implements RcsFile
sub getRevisionInfo {
    my( $this, $version ) = @_;

    my $rcsError = '';
    my( $dummy, $rev, $date, $user, $comment );
    if ( -e $this->{rcsFile} ) {
        $version = $this->numRevisions() unless $version;
        my $cmd = $TWiki::cfg{RCS}{infoCmd};
        my ( $rcsOut, $exit ) = $this->{session}->{sandbox}->readFromProcess
          ( $cmd,
            REVISION => "1.$version",
            FILENAME => $this->{rcsFile} );
       $rcsError = "Error with $cmd, output: $rcsOut" if( $exit );
       if( ! $rcsError ) {
            if( $rcsOut =~ /date: (.*?);  author: (.*?);.*\n(.*)\n/ ) {
                $date = $1;
                $user = $2;
                $comment = $3;
                $date = TWiki::Time::parseTime( $date );
                if( $rcsOut =~ /revision 1.([0-9]*)/ ) {
                    $rev = $1;
                }
            }
            $rcsError = "Rev info missing from revision file $this->{rcsFile}" unless( $rev );
       }
    } else {
       $rcsError = "Revision file $this->{rcsFile} is missing";
    }

    ( $dummy, $rev, $date, $user, $comment ) =
      $this->_getRevisionInfoDefault() if( $rcsError );

    return( $rcsError, $rev, $date, $user, $comment );
}

# implements RcsFile
sub revisionDiff {
    my( $this, $rev1, $rev2, $contextLines ) = @_;
    
    my $error = '';

    my $tmp = '';
    my $exit;
    if ( $rev1 eq '1' && $rev2 eq '1' ) {
        my $text = $this->getRevision(1);
        $tmp = "1a1\n";
        foreach( split( /\n/, $text ) ) {
           $tmp = "$tmp> $_\n";
        }
    } else {
        $contextLines = '' unless defined($contextLines);
        ( $tmp, $exit ) =
          $this->{session}->{sandbox}->readFromProcess
            ( $TWiki::cfg{RCS}{diffCmd},
              REVISION1 => "1.$rev1",
              REVISION2 => "1.$rev2",
              FILENAME => $this->{rcsFile},
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

    my ( $diffFormat ) = 'normal'; #or rcs, unified...
    my ( @diffArray ) = ();

    $diffFormat = 'unified' if ( $text =~ /^---/ );

    $text =~ s/\r//go;  # cut CR

    my $lineNumber=1;
    if ( $diffFormat eq 'unified' ) {
        foreach( split( /\n/, $text ) ) {
	    if ( $lineNumber > 3 ) {   #skip the first 2 lines (filenames)
 	   	    if ( /@@ [-+]([0-9]+)([,0-9]+)? [-+]([0-9]+)(,[0-9]+)? @@/ ) {
	    	        #line number
		        push @diffArray, ['l', $1, $3];
		    } elsif ( /^\-/ ) {
		        s/^\-//go;
		        push @diffArray, ['-', $_, ''];
		    } elsif ( /^\+/ ) {
		        s/^\+//go;
		        push @diffArray, ['+', '', $_];
		    } else {
	  		s/^ (.*)$/$1/go;
			push @diffArray, ['u', $_, $_];
		    }
	    }
	    $lineNumber = $lineNumber + 1;
       	 }
    } else {
        #'normal' rcsdiff output 
        foreach( split( /\n/, $text ) ) {
    	    if ( /^([0-9]+)[0-9\,]*([acd])([0-9]+)/ ) {
    	        #line number
	        push @diffArray, ['l', $1, $3];
	    } elsif ( /^</ ) {
	        s/^< //go;
	            push @diffArray, ['-', $_, ''];
	    } elsif ( /^>/ ) {
	        s/^> //go;
	            push @diffArray, ['+', '', $_];
	    } else {
	        #empty lines and the --- selerator in the diff
	        #push @diffArray, ['u', $_, $_];
	    }
        }
    }
    return \@diffArray;
}

sub _ci {
    my( $this, $comment, $user ) = @_;

    $comment = 'none' unless( $comment );
    my ($rcsOutput, $exit) = $this->{session}->{sandbox}->readFromProcess
      ( $TWiki::cfg{RCS}{ciCmd},
        USERNAME => $user,
        FILENAME => $this->{file},
        COMMENT => $comment );

    if( $exit && $rcsOutput ) {
        $rcsOutput = "$TWiki::cfg{RCS}{ciCmd}\n$rcsOutput";
    }

    # A ci -u leaves the file unwriteable, so fix that. We are still
    # rather mean with the permissions, but at least the webserver user
    # can write!
    chmod( 0644, $this->{file} );

    return $rcsOutput;
}

sub _lock {
    my $this = shift;

    return undef unless -e $this->{rcsFile};

    # Try and get a lock on the file
    my ($rcsOutput, $exit) = $this->{session}->{sandbox}->readFromProcess
      ( $TWiki::cfg{RCS}{lockCmd}, FILENAME => $this->{file} );

    if( $exit && $rcsOutput ) {
        $rcsOutput = "$TWiki::cfg{RCS}{lockCmd}\n$rcsOutput";
        return $rcsOutput;
    }
    chmod( 0644, $this->{file} );

    return undef;
}

sub getRevisionAtTime {
    my( $this, $date ) = @_;

    if ( !-e $this->{rcsFile} ) {
        return undef;
    }
	$date = TWiki::Time::formatTime( $date , '$rcs', 'gmtime');
    my ($rcsOutput, $exit) = $this->{session}->{sandbox}->readFromProcess
      ( $TWiki::cfg{RCS}{rlogDateCmd}, DATE => $date, FILENAME => $this->{file} );

    if ( $rcsOutput =~ m/revision \d+\.(\d+)/ ) {
        return $1;
    } else {
        return undef;
    }
}

1;
