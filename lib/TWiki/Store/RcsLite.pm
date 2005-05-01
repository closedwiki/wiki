# TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 1999-2005 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root of
# this distribution.
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

---+ package TWiki::Store::RcsLite

This package does not publish any methods. It implements the virtual
methods of the [[TWikiStoreRcsFileDotPm][TWiki::Store::RcsFile]] superclass.

Simple replacement for RCS.  Doesn't support:
   * branches
   * locking

This module doesn't know anything about the content of the topic

There is one of these object for each file stored under RCSLite.

This object is PACKAGE PRIVATE to Store, and should never be
used from anywhere else.

FIXME:
   * need to tidy up dealing with \n for differences
   * still have difficulty on line ending at end of sequences, consequence of doing a line based diff
   * most serious is when having multiple line ends on one seq but not other - this needs fixing
   * cleaner dealing with errors/warnings

---++ File format information:
<verbatim>
rcstext    ::=  admin {delta}* desc {deltatext}*
admin      ::=  head {num};
                { branch   {num}; }
                access {id}*;
                symbols {sym : num}*;
                locks {id : num}*;  {strict  ;}
                { comment  {string}; }
                { expand   {string}; }
                { newphrase }*
delta      ::=  num
                date num;
                author id;
                state {id};
                branches {num}*;
                next {num};
                { newphrase }*
desc       ::=  desc string
deltatext  ::=  num
                log string
                { newphrase }*
                text string
num        ::=  {digit | .}+
digit      ::=  0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9
id         ::=  {num} idchar {idchar | num }*
sym        ::=  {digit}* idchar {idchar | digit }*
idchar     ::=  any visible graphic character except special
special    ::=  $ | , | . | : | ; | @
string     ::=  @{any character, with @ doubled}*@
newphrase  ::=  id word* ;
word       ::=  id | num | string | :
</verbatim>
Identifiers are case sensitive. Keywords are in lower case only. The
sets of keywords and identifiers can overlap. In most environments RCS
uses the ISO 8859/1 encoding: visible graphic characters are codes
041-176 and 240-377, and white space characters are codes 010-015 and 040.

Dates, which appear after the date keyword, are of the form Y.mm.dd.hh.mm.ss,
where Y is the year, mm the month (01-12), dd the day (01-31), hh the hour
(00-23), mm the minute (00-59), and ss the second (00-60). Y contains just
the last two digits of the year for years from 1900 through 1999, and all
the digits of years thereafter. Dates use the Gregorian calendar; times
use UTC.

The newphrase productions in the grammar are reserved for future extensions
to the format of RCS files. No newphrase will begin with any keyword already
in use.

=cut
package TWiki::Store::RcsLite;

use TWiki::Store::RcsFile;
@ISA = qw(TWiki::Store::RcsFile);

use strict;
#use Algorithm::Diff;# qw(diff sdiff);
use Algorithm::Diff;
use FileHandle;
use Assert;
use TWiki::Time;

#$this->{session}->writeDebug("Diff version $Algorithm::Diff::VERSION\n");

my $DIFF_DEBUG = 0;
my $DIFFEND_DEBUG = 0;

# implements RcsFile
sub new {
    my( $class, $session, $web, $topic, $attachment, $settings ) = @_;
    ASSERT(ref($session) eq 'TWiki') if DEBUG;
    my $this =
      bless( new TWiki::Store::RcsFile( $session, $web, $topic, $attachment, $settings ),
             $class );
    $this->{head} = 0;
    $this->{access} = '';
    $this->{symbols} = '';
    $this->{comment} = '';
    $this->{description} = '';
    $this->init();
    return $this;
}

sub _readTo {
    my( $file, $char ) = @_;
    my $buf = '';
    my $ch;
    my $space = 0;
    my $string = '';
    my $state = '';
    while( read( $file, $ch, 1 ) ) {
       if( $ch eq "@" ) {
          if( $state eq "@" ) {
             $state = 'e';
             next;
          } elsif( $state eq 'e' ) {
             $state = "@";
             $string .= "@";
             next;
          } else {
             $state = "@";
             next;
          }
       } else {
          if( $state eq 'e' ) {
             $state = '';
             if( $char eq "@" ) {
                last;
             }
             # End of string
          } elsif ( $state eq "@" ) {
             $string .= $ch;
             next;
          }
       }
       if( $ch =~ /\s/ ) {
          if( length( $buf ) == 0 ) {
              next;
          } elsif( $space ) {
              next;
          } else {
              $space = 1;
              $ch = ' ';
          }
       } else {
          $space = 0;
       }
       $buf .= $ch;
       if( $ch eq $char ) {
           last;
       }
    }
    return( $buf, $string );
}

# ======================
# Called by routines that must make sure RCS file has been read in
sub _ensureProcessed {
    my( $this ) = @_;
    if( ! $this->{where} ) {
        $this->_process();
    }
}

# ======================
# Read in the whole RCS file
sub _process {
    my( $this ) = @_;
    my $rcsFile = TWiki::Sandbox::normalizeFileName( $this->{rcsFile} );
    if( ! -e $rcsFile ) {
        $this->{where} = 'nofile';
        return;
    }
    my $fh = new FileHandle;
    if( ! $fh->open( $rcsFile ) ) {
        $this->{session}->writeWarning( "Couldn't open file $rcsFile" );
        $this->{where} = 'nofile';
        return;
    }
    my $where = "admin.head";
    binmode( $fh );
    my $lastWhere = '';
    my $going = 1;
    my $term = ";";
    my $string = '';
    my $num = '';
    my $headNum = '';
    my @date = ();
    my @author = ();
    my @log = ();
    my @text = ();
    my $dnum = '';
    while( $going ) {
       ($_, $string) = _readTo( $fh, $term );
       last if( ! $_ );
      
       my $lastWhere = $where;
       #print "\"$where -- $_\"\n";
       if( $where eq "admin.head" ) {
          if( /^head\s+([0-9]+)\.([0-9]+);$/o ) {
             die( 'Only support start of version being 1' ) if( $1 ne '1' );
             $headNum = $2;
             $where = 'admin.access'; # Don't support branch
          } else {
             last;
          }
       } elsif( $where eq "admin.access" ) {
          if( /^access\s*(.*);$/o ) {
             $where = 'admin.symbols';
             $this->{access} = $1;
          } else {
             last;
          }
       } elsif( $where eq "admin.symbols" ) {
          if( /^symbols(.*);$/o ) {
             $where = "admin.locks";
             $this->{symbols} = $1;
          } else {
             last;
          }
       } elsif( $where eq "admin.locks" ) {
          if( /^locks.*;$/o ) {
             $where = "admin.postLocks";
          } else {
             last;
          }
       } elsif( $where eq "admin.postLocks" ) {
          if( /^strict\s*;/o ) {
             $where = "admin.postStrict";
          }
       } elsif( $where eq "admin.postStrict" &&
                /^comment\s.*$/o ) {
             $where = "admin.postComment";
             $this->{comment} = $string;
       } elsif( ( $where eq "admin.postStrict" || $where eq "admin.postComment" )  &&
                /^expand\s/o ) {
             $where = "admin.postExpand";
             $this->{expand} = $string;
       } elsif( $where eq "admin.postStrict" || $where eq "admin.postComment" || 
                $where eq "admin.postExpand" || $where eq "delta.date") {
          if( /^([0-9]+)\.([0-9]+)\s+date\s+(\d\d(\d\d)?(\.\d\d){5}?);$/o ) {
             $where = "delta.author";
             $num = $2;
             $date[$num] = TWiki::Time::parseTime($3);
          }
       } elsif( $where eq "delta.author" ) {
          if( /^author\s+(.*);$/o ) {
             $author[$num] = $1;
             if( $num == 1 ) {
                $where = 'desc';
                $term = "@";
             } else {
                $where = "delta.date";
             }
          }
       } elsif( $where eq 'desc' ) {
          if( /desc\s*$/o ) {
             $this->{description} = $string;
             $where = "deltatext.log";
          }
       } elsif( $where eq "deltatext.log" ) {
          if( /\d+\.(\d+)\s+log\s+$/o ) {
             $dnum = $1;
             $log[$dnum] = $string;
             $where = "deltatext.text";
          }
       } elsif( $where eq "deltatext.text" ) {
          if( /text\s*$/o ) {
             $where = "deltatext.log";
             $text[$dnum] = $string;
             if( $dnum == 1 ) {
                $where = 'done';
                last;
             }
          }
       }
    }
    
    $this->{head} = $headNum;
    $this->{author} = \@author;
    $this->{date} = \@date;   #TODO: i hitnk i need to make this into epochSecs
    $this->{log} = \@log;
    $this->{delta} = \@text;
    $this->{status} = $dnum;
    $this->{where} = $where;
    
    close( $fh );
}

# ======================
sub _formatString {
    my( $str ) = @_;
    $str =~ s/@/@@/go;
    return "\@$str\@";
}

# ======================
# Write content of the RCS file
sub _write {
    my( $this, $file ) = @_;
    
    # admin
    print $file "head\t1." . $this->numRevisions() . ";\n";
    print $file 'access' . $this->{access} . ";\n";
    print $file 'symbols' . $this->{symbols} . ";\n";
    print $file "locks; strict;\n";
    printf $file "comment\t%s;\n", ( _formatString( $this->_comment() ) );
    printf $file "expand\t@%s@;\n", ( $this->{expand} ) if ( $this->{expand} );
    
    print $file "\n";
    
    # delta
    for( my $i=$this->numRevisions(); $i>0; $i--) {
       printf $file "\n1.%d\ndate\t%s;\tauthor %s;\tstate Exp;\nbranches;\n", 
              ($i, TWiki::Store::RcsFile::_epochToRcsDateTime( ${$this->{date}}[$i] ), $this->_author($i) );
       if( $i == 1 ) {
           print $file "next\t;\n";
       } else {
           printf $file "next\t1.%d;\n", ($i - 1);
       }
    }
    
    printf $file "\n\ndesc\n%s\n\n", ( _formatString( $this->_description() ) );
    
    for( my $i=$this->numRevisions(); $i>0; $i--) {
       printf $file "\n1.$i\nlog\n%s\ntext\n%s\n",
              ( _formatString( $this->_log($i) ), _formatString( $this->_delta($i) ) );
    }
}

# implements RcsFile
sub initBinary {
   my( $this ) = @_;
   # Nothing to be done but note for re-writing
   $this->{expand} = 'b';
   # FIXME: unless we have to not do diffs for binary files
   return undef;
}

# implements RcsFile
sub initText {
   my( $this ) = @_;
   # Nothing to be done but note for re-writing
   $this->{expand} = '';
   return undef;
}

# implements RcsFile
sub numRevisions {
    my( $this ) = @_;
    $this->_ensureProcessed();
    return $this->{head};
}

# Get the revision date in epoch seconds (secs since 1970)
sub _date {
    my( $this, $version ) = @_;
    $this->_ensureProcessed();
    my $date = ${$this->{date}}[$version];
    if( $date ) {
#        $date = TWiki::Time::parseTime($date);
    } else {
        $date = 0;#MMMM, should this be 0, or now()?
    }
    return $date;
}

# Get description
sub _description {
    my( $this ) = @_;
    $this->_ensureProcessed();
    return $this->{description};
}

# Get comment
sub _comment {
    my( $this ) = @_;
    $this->_ensureProcessed();
    return $this->{comment};
}

# Get author
sub _author {
    my( $this, $version ) = @_;
    $this->_ensureProcessed();
    return ${$this->{author}}[$version];
}

# Get log
sub _log {
    my( $this, $version ) = @_;
    $this->_ensureProcessed();
    return ${$this->{log}}[$version];
}

# get delta to rev
sub _delta {
    my( $this, $version ) = @_;
    $this->_ensureProcessed();
    return ${$this->{delta}}[$version];
}

# implements RcsFile
sub addRevision {
    my( $this, $text, $log, $author, $date ) = @_;
    $this->_ensureProcessed();

    $this->_save( $this->{file}, \$text );
    $text = $this->_readFile( $this->{file} ) if( $this->{attachment} );
    my $head = $this->numRevisions();
    if( $head ) {
        my $delta = _diffText( \$text, \$this->_delta($head), '', 0 );
        ${$this->{delta}}[$head] = $delta;
    }
    $head++;
    ${$this->{delta}}[$head] = $text;
    $this->{head} = $head;
    ${$this->{log}}[$head] = $log;
    ${$this->{author}}[$head] = $author;
    $date = time() unless( $date );

    ${$this->{date}}[$head] = $date;

    return $this->_writeMe();
}

sub _writeMe {
    my( $this ) = @_;
    my $dataError = '';
    my $out = new FileHandle;

    # FIXME move permission to config or similar
    chmod( 0644, $this->{rcsFile} );
    if( ! $out->open( "> " . TWiki::Sandbox::normalizeFileName( $this->{rcsFile} ))) {
       $dataError = 'Problem opening ' . $this->{rcsFile} . " for writing";
    } else {
       binmode( $out );
       $this->_write( $out );
       close( $out );
    }
    chmod( 0444, $this->{rcsFile} ); # FIXME as above
    return $dataError;    
}

# implements RcsFile
sub replaceRevision {
    my( $this, $text, $comment, $user, $date ) = @_;
    $this->_ensureProcessed();
    $this->_delLastRevision();
    return $this->addRevision( $text, $comment, $user, $date );
}

# implements RcsFile
sub deleteRevision {
    my( $this ) = @_;
    $this->_ensureProcessed();
    return undef if( $this->numRevisions() <= 1 );
    $this->_delLastRevision();
    return $this->_writeMe();
}

sub _delLastRevision {
    my( $this ) = @_;
    my $numRevisions = $this->numRevisions();
    if( $numRevisions > 1 ) {
        # Need to recover text for last revision
        my $lastText = $this->getRevision( $numRevisions - 1 );
        $numRevisions--;
        $this->{delta}->[$numRevisions] = $lastText;
    } else {
        $numRevisions--;
    }
    $this->{head} = $numRevisions;
}


# implements RcsFile
# SMELL: so why does this read the rcs file, re-create each of the 2 revisions and then diff them? isn't the delta in the rcs file good enough? (until you want context?)
sub revisionDiff {
    my( $this, $rev1, $rev2, $contextLines ) = @_;
    $this->_ensureProcessed();
    my $text1 = $this->getRevision( $rev1 );
    my $text2 = $this->getRevision( $rev2 );
	
    my @lNew = _mySplit( \$text1 );
    my @lOld = _mySplit( \$text2 );
	my $diff = Algorithm::Diff::sdiff( \@lNew, \@lOld );

	#the Diff::sdiff algol seems to work better with \n, and the rendering currently needs no \n's
	my @list;
	foreach my $ele ( @$diff ) {
		@$ele[1] =~ s/\n//go;
		@$ele[2] =~ s/\n//go;
		push @list, $ele;
	}
	return ('', \@list);	
}

# implements RcsFile
sub getRevision {
    my( $this, $version ) = @_;
    $this->_ensureProcessed();
    my $head = $this->numRevisions();
    if( $version == $head ) {
        return $this->_delta( $version );
    } else {
        my $headText = $this->_delta( $head );
        my @text = _mySplit( \$headText, 1 );
        return $this->_patchN( \@text, $head-1, $version );
    }
}

# implements RcsFile
sub getRevisionInfo {
    my( $this, $version ) = @_;
    $this->_ensureProcessed();
    $version = $this->numRevisions() if( ! $version );

	#TODO: need to add a where $revision is not number, find out what rev number the tag refers to

    my @result;

    if( $this->{where} && $this->{where} ne 'nofile' ) {
        @result = ( '', $version, $this->_date( $version ), $this->_author( $version ), $this->_comment() );
    } else {
        @result = $this->_getRevisionInfoDefault();
    }

    return @result;
}


# ======================
# Apply delta (patch) to text.  Note that RCS stores reverse deltas, the is text for revision x
# is patched to produce text for revision x-1.
# It is fiddly dealing with differences in number of line breaks after the end of the
# text.
sub _patch {
   # Both params are references to arrays
   my( $text, $delta ) = @_;
   my $adj = 0;
   my $pos = 0;
   my $last = '';
   my $d;
   my $extra = '';
   my $max = $#$delta;
   while( $pos <= $max ) {
       $d = $delta->[$pos];
       if( $d =~ /^([ad])(\d+)\s(\d+)\n(\n*)/ ) {
          $last = $1;
          $extra = $4;
          my $offset = $2;
          my $length = $3;
          if( $last eq 'd' ) {
             my $start = $offset + $adj - 1;
             my @removed = splice( @$text, $start, $length );
             $adj -= $length;
             $pos++;
          } elsif( $last eq 'a' ) {
             my @toAdd = @$delta[$pos+1..$pos+$length];
             if( $extra ) {
                 if( @toAdd ) {
                     $toAdd[$#toAdd] .= $extra;
                 } else {
                     @toAdd = ( $extra );
                 }
             }
             splice( @$text, $offset + $adj, 0, @toAdd );
             $adj += $length;
             $pos += $length + 1;
          }
       } else {
          #warn( 'wrong! - should be \'[ad]<num> <num>\" and was: \"" . $d . "\"\n\n" ); #FIXME remove die
          return;
       }
   }
}

sub _patchN {
    my( $this, $text, $version, $target ) = @_;

    my $deltaText= $this->_delta( $version );
    my @delta = _mySplit( \$deltaText );
    _patch( $text, \@delta );
    if( $version <= $target ) {
        return join( '', @$text );
    } else {
        return $this->_patchN( $text, $version-1, $target );
    }
}

# Split and make sure we have trailing carriage returns
sub _mySplit {
    my( $text, $addEntries ) = @_;

    my $ending = '';
    if( $$text =~ /(\n+)$/o ) {
        $ending = $1;
    }

    my @list = split( /\n/o, $$text );
    for( my $i = 0; $i<$#list; $i++ ) {
    	    $list[$i] .= "\n";
    }
	
    if( $ending ) {
        if( $addEntries ) {
            my $len = length($ending);
            if( @list ) {
               $len--;
               $list[$#list] .= "\n";
            }
            for( my $i=0; $i<$len; $i++ ) {
                push @list, ("\n");
           }
        } else {
            if( @list ) {
                $list[$#list] .= $ending;
            } else {
                @list = ( $ending );
            }
        }
    }
    # TODO: deal with Mac style line ending??

    return @list; # FIXME would it be more efficient to return a reference?
}

# SMELL: Way of dealing with trailing \ns feels clumsy
sub _diffText {
    my( $new, $old, $type, $contextLines ) = @_;
    my @lNew = _mySplit( $new );
    my @lOld = _mySplit( $old );
    return _diff( \@lNew, \@lOld, $type, $contextLines );
}

sub _lastNoEmptyItem {
   my( $items ) = @_;
   my $pos = $#$items;
   my $count = 0;
   my $item;
   while( $pos >= 0 ) {
      $item = $items->[$pos];
      last if( $item );
      $count++;
      $pos--;
   }
   return( $pos, $count );
}

# Deal with trailing carriage returns - Algorithm doesn't give output that RCS format is too happy with
sub _diffEnd {
   my( $new, $old, $type ) = @_;
   return if( $type ); # FIXME

   my( $posNew, $countNew ) = _lastNoEmptyItem( $new );
   my( $posOld, $countOld ) = _lastNoEmptyItem( $old );

   return '' if( $countNew == $countOld );

   if( $DIFFEND_DEBUG ) {
     print( "countOld, countNew, posOld, posNew, lastOld, lastNew, lenOld: " .
            "$countOld, $countNew, $posOld, $posNew, " . $#$old . ", " . $#$new .
            "," . @$old . "\n" );
   }

   $posNew++;
   my $toDel = ( $countNew < 2 ) ? 1 : $countNew;
   my $startA = @$new - ( ( $countNew > 0 ) ? 1 : 0 );
   my $toAdd = ( $countOld < 2 ) ? 1 : $countOld;
   my $theEnd = "d$posNew $toDel\na$startA $toAdd\n";
   for( my $i=$posOld; $i<@${old}; $i++ ) {
       $theEnd .= $old->[$i] ? $old->[$i] : "\n";
   }

   for( my $i=0; $i<$countNew; $i++ ) {pop @$new;}
   pop @$new;
   for( my $i=0; $i<$countOld; $i++ ) {pop @$old;}
   pop @$old;

   print "--$theEnd--\n"  if( $DIFFEND_DEBUG );

   return $theEnd;
}

# no type means diff for putting in rcs file, diff means normal diff output
sub _diff {
    my( $new, $old, $type, $contextLines ) = @_;
    # Work out diffs to change new to old, params are refs to lists
    my $diffs = Algorithm::Diff::diff( $new, $old );
	
    my $adj = 0;
    my @patch = ();
    my @del = ();
    my @ins = ();
    my $out = '';
    my $start = 0;
    my $start1;
    my $chunkSign = '';
    my $count = 0;
    my $numChunks = @$diffs;
    my $last = 0;
    my $lengthNew = @$new - 1;
    foreach my $chunk ( @$diffs ) {
       $count++;
       print "[\n" if( $DIFF_DEBUG );
       $chunkSign = '';
       my @lines = ();
       foreach my $line ( @$chunk ) {
           my( $sign, $pos, $what ) = @$line;
           print "$sign $pos \"$what\"\n" if( $DIFF_DEBUG );
           if( $chunkSign ne $sign && $chunkSign ne '') {
               if( $chunkSign eq '-' && $type eq 'diff' ) {
                  # Might be change of lines
                  my $chunkLength = @$chunk;
                  my $linesSoFar = @lines;
                  if( $chunkLength == 2 * $linesSoFar ) {
                     $chunkSign = 'c';
                     $start1 = $pos;
                  }
               }
               $adj += _addChunk( $chunkSign, \$out, \@lines, $start, $adj, $type, $start1, $last ) if( $chunkSign ne 'c' );
           }
           if( ! @lines ) {
               $start = $pos;
           }
           $chunkSign = $sign if( $chunkSign ne 'c' );
           push @lines, ( $what );
       }

       $last = 1 if( $count == $numChunks );
       if( $last && $chunkSign eq "+" ) {
           my $endings = 0;
           for( my $i=$#$old; $i>=0; $i-- ) {
               if( $old->[$i] ) {
                   last;
               } else {
                   $endings++;
               }
           }
           my $has = 0;
           for( my $i=$#lines; $i>=0; $i-- ) {
               if( $lines[$i] ) {
                   last;
               } else {
                   $has++;
               }
           }
           for( my $i=0; $i<$endings-$has; $i++ ) {
               push @lines, ('');
           }
       }
       $adj += _addChunk( $chunkSign, \$out, \@lines, $start, $adj, $type, $start1, $last, $lengthNew );
       print "]\n" if( $DIFF_DEBUG );
    }
    # Make sure we have the correct number of carriage returns at the end

    print "pre end: \"$out\"\n" if( $DIFFEND_DEBUG );
    return $out; # . $theEnd;
}

sub _range {
   my( $start, $end ) = @_;
   if( $start == $end ) {
      return $start;
   } else {
      return "$start,$end";
   }
}

sub _addChunk {
   my( $chunkSign, $out, $lines, $start, $adj, $type, $start1, $last, $newLines ) = @_;
   my $nLines = @$lines;
   if( $lines->[$#$lines] =~ /(\n+)$/o ) {
      $nLines += ( ( length( $1 ) == 0 ) ? 0 : length( $1 ) -1 );
   }
   if( $nLines > 0 ) {
       print "addChunk chunkSign=$chunkSign start=$start adj=$adj type=$type start1=$start1 " .
             "last=$last newLines=$newLines nLines=$nLines\n" if( $DIFF_DEBUG );
       $$out .= "\n" if( $$out && $$out !~ /\n$/o );
       if( $chunkSign eq 'c' ) {
          $$out .= _range( $start+1, $start+$nLines/2 );
          $$out .= 'c';
          $$out .= _range( $start1+1, $start1+$nLines/2 );
          $$out .= "\n";
          $$out .= '< ' . join( '< ', @$lines[0..$nLines/2-1] );
          $$out .= "\n" if( $lines->[$nLines/2-1] !~ /\n$/o );
          $$out .= "---\n";
          $$out .= '> ' . join( '> ', @$lines[$nLines/2..$nLines-1] );
          $nLines = 0;
       } elsif( $chunkSign eq '+' ) {
          if( $type eq 'diff' ) {
              $$out .= $start-$adj . 'a';
              $$out .= _range( $start+1, $start+$nLines ) . "\n";
              $$out .= '> ' . join( '> ', @$lines );
          } else {
              $$out .= 'a';
              $$out .= $start-$adj;
              $$out .= " $nLines\n";
              $$out .= join( '', @$lines );
          }
       } else {
          print "Start nLines newLines: $start $nLines $newLines\n" if( $DIFF_DEBUG );
          if( $type eq 'diff' ) {
              $$out .= _range( $start+1, $start+$nLines );
              $$out .= 'd';
              $$out .= $start + $adj . "\n";
              $$out .= '< ' . join( '< ', @$lines );
          } else {
              $$out .= 'd';
              $$out .= $start+1;
              $$out .= " $nLines";
              $$out .= "\n" if( $last );
          }
          $nLines *= -1;
       }
       @$lines = ();
   }
   return $nLines;
}

sub getRevisionAtTime {
    my( $this, $date ) = @_;

    return undef;
}

1;
