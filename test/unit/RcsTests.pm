# Tests for TWiki::Store::RcsLite and TWiki::Store::RcsWrap
# JohnTalintyre
# Ported to Test::Unit by CrawfordCurrie
use strict;

package RcsTests;

use base qw(Test::Unit::TestCase);

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

# Set up the test fixture
sub set_up {
}

BEGIN {
    unshift @INC, '../../lib';
    unshift @INC, '.';
}

use TWiki;
use TWiki::Store;
use TWiki::Store::RcsLite;
use TWiki::Store::RcsWrap;

my $rTopic = "RcsLiteRTest";
my $wTopic = "RcsLiteWTest";
my $attachment = "it.doc";

my @storeSettings = @TWiki::storeSettings;

# Get rid a topic and its attachments completely
sub mug {
    my( $self ) = @_;

    my $web = $self->{web};
    my $topic = $self->{topic};

    my $rcsDirFile = $self->{dataDir} . "/$web/RCS/$topic,v";
    my @files = ( $self->file(), $self->rcsFile(), $rcsDirFile );
    unlink( @files );
    $self->_init();
    $self->{"head"} = 0;

    return if ( $self->{attachment} );

    # Delete all attachments and the attachment directory
    my $attDir = $self->_makeFileDir( 1, "" );
    if( -e $attDir ) {
        opendir( DIR, $attDir );
        my @attachments = readdir( DIR );
        closedir( DIR );
        my $attachment;
        foreach $attachment ( @attachments ) {
            if( ! -d "$attDir/$attachment" ) {
                unlink( "$attDir/$attachment" );
                if( $attachment !~ /,v$/ ) {
                    #writeLog( "erase", "$web.$topic.$attachment" );
                }
            }
        }

        # Deal with RCS dir if it exists
        my $attRcsDir = "$attDir/RCS";
        if( -e $attRcsDir ) {
            opendir( DIR, $attRcsDir );
            my @attachments = readdir( DIR );
            closedir( DIR );
            my $attachment;
            foreach $attachment ( @attachments ) {
                if( ! -d "$attRcsDir/$attachment" ) {
                    unlink( "$attRcsDir/$attachment" );
                }
            }
            rmdir( $attRcsDir ) || die $attRcsDir;
        }
        rmdir( $attDir ) || die $attDir;
    }
}

# save attachment and topic differently
sub addRevision {
    my( $handler, $attachment, $text, $comment, $who ) = @_;

    if( $attachment ) {
        if(  $attachment eq "usefile.tmp" ) {
        } else {
            my $name = "tmp-attachment.tmp";
            umask( 002 );
            open( FILE, ">$name" ) or warn "Can't create file $name\n";
            binmode( FILE );
            print FILE $text;
            close( FILE);
            $text = $name;
        }
    }
    $handler->addRevision( $text, $comment, $who );
}


sub checkRead {
    my( $this, $topic, $attachment, @vals ) = @_;
    my $web = "Test";
    my $rcs = TWiki::Store::RcsWrap->new( $web, $topic, $attachment, @storeSettings );
    mug($rcs);
    my $numRevs = $#vals + 1;
    for( my $i=0; $i<$numRevs; $i++ ) {
        addRevision( $rcs, $attachment, $vals[$i], "comment " . $i, "JohnTalintyre" );
    }
    my $rcsLite = TWiki::Store::RcsLite->new( $web, $topic, $attachment, @storeSettings );
    $this->assert_equals( $numRevs, $rcsLite->numRevisions(), "Number of revisions should be the same" );
    for( my $i=$numRevs; $i>0; $i-- ) {
        my $text = $rcsLite->getRevision( $i );
        $this->assert_equals( $vals[$i-1], $text );
    }
    return $rcsLite;
}


sub test_repRev {
    my $this = shift;
    my $web = "Test";
    my $topic = "RcsLiteRepRev";
    #print "Test Rep Rev\n";
    my $rcsLite = TWiki::Store::RcsLite->new( $web, $topic, "", @storeSettings );
    mug($rcsLite);
    $rcsLite->addRevision( "there was a man\n\n", "in once", "JohnTalintyre" );
    $rcsLite->replaceRevision( "there was a cat\n", "1st replace", "NotJohnTalintyre", time() );
    my $rcs = TWiki::Store::RcsWrap->new( $web, $topic, "", @storeSettings );
    my $numRevs = $rcs->numRevisions();
    $this->assert_equals( 1, $numRevs, "Should be one revision" );
    my $text = $rcs->getRevision(1);
    $this->assert_equals( "there was a cat\n", $text, "Text for 1st replaced revision should match" );
    $rcsLite->addRevision( "and now this\n\n\n", "2nd entry", "J1" );
    $rcsLite->replaceRevision( "then this", "2nd replace", "J2", time() );
    $this->assert_equals( 2, $rcs->numRevisions );
    $this->assert_equals( "there was a cat\n", $rcs->getRevision(1) );
    $this->assert_equals( "then this", $rcs->getRevision(2) );
    mug($rcs);
    $rcs->addRevision( "there was a man\n\n", "in once", "JohnTalintyre" );
    $rcs->replaceRevision( "there was a cat\n", "1st replace", "NotJohnTalintyre", time() );
    $rcsLite = TWiki::Store::RcsLite->new( $web, $topic, "", @storeSettings );
    $numRevs = $rcsLite->numRevisions();
    $this->assert_equals( $numRevs, 1 );
    $text = $rcsLite->getRevision(1);
    $this->assert_equals( "there was a cat\n", $text);
    $rcs->addRevision( "and now this\n\n\n", "2nd entry", "J1" );
    $rcs->replaceRevision( "then this\n", "2nd replace", "J2", time() );
    $rcsLite = TWiki::Store::RcsLite->new( $web, $topic, "", @storeSettings );
    $this->assert_equals( 2, $rcsLite->numRevisions);
    $this->assert_equals( "there was a cat\n", $rcsLite->getRevision(1));
    $this->assert_equals( "then this\n", $rcsLite->getRevision(2));
}

sub writeTest {
    my( $this, $topic, $attachment, @vals ) = @_;
    my $web = "Test";
    my $rcsLite = TWiki::Store::RcsLite->new( $web, $topic, $attachment,
                                              @storeSettings );
    mug($rcsLite);
    my $numRevs = $#vals + 1;
    for( my $i=0; $i<$numRevs; $i++ ) {
        addRevision( $rcsLite, $attachment, $vals[$i], "comment " . $i,
                     "JohnTalintyre" );
    }
    my $rcs = TWiki::Store::RcsWrap->new( $web, $topic, $attachment,
                                          @storeSettings );
    $this->assert_equals( $numRevs, $rcs->numRevisions());
    for( my $i = $numRevs; $i > 0; $i-- ) {
        my $text = $rcs->getRevision( $i );
        $this->assert_str_equals( $vals[$i-1], $text );
    }
}

# Outputs delta for helping to work out how to do things
sub refDelta {
    my( $old, $new ) = @_;
    my $web = "Test";
    my $topic = "RefDelta";
    my $rcs = TWiki::Store::RcsWrap->new( $web, $topic, "", @storeSettings );
    mug($rcs);
    $rcs->addRevision( $old, "old comment", "JohnTalintyre" );   
    $rcs->addRevision( $new, "old comment", "JohnTalintyre" );   
    my $rcsLite = TWiki::Store::RcsLite->new( $web, $topic, "", @storeSettings );
    my $delta = $rcsLite->delta(1);
    print "Old:\n\"$old\"\n";
    print "New:\n\"$new\"\n";
    print "Delta new->old:\n\"$delta\"\n\n"; 
}

sub rcsDiffOne {
    my( $this, @vals ) = @_;
    my $topic = "RcsDiffTest";
    my $web = "Test";
    my $rcs = TWiki::Store::RcsWrap->new( $web, $topic, "", @storeSettings );
    mug($rcs);
    #print "Rcs Diff test $num\n";
    $rcs->addRevision( $vals[0], "num 0", "JohnTalintyre" );
    $rcs->addRevision( $vals[1], "num 1", "JohnTalintyre" );
    my $diff = $rcs->revisionDiff( 1, 2 );
    my $rcsLite = TWiki::Store::RcsLite->new( $web, $topic, "", @storeSettings );
    my $diffLite = $rcsLite->revisionDiff( 1, 2 );

    my $i = 0;
    while ( $i <= $#$diffLite && $i <= $#$diff ) {
        my $a = $i.": ".join("\t", @{$diffLite->[$i]});
        my $b = $i.": ".join("\t", @{$diff->[$i]});

        $this->assert_str_equals( $b, $a );
        $i++;
    }
    $this->assert_equals( $#$diffLite, $#$diff );
}

sub test_wt1 {
    my $this = shift;
    $this->writeTest( $wTopic, "", ( "a" ) );
}

sub test_wt2 {
    my $this = shift;
    $this->writeTest( $wTopic, "", ( "a\n" ) );
}

sub test_wt3 {
    my $this = shift;
    $this->writeTest( $wTopic, "", ( "a\n", "b\n" ) );
}

sub test_wt4 {
    my $this = shift;
    $this->writeTest( $wTopic, "", ( "a\n", "b" ) );
}

sub test_wt5 {
    my $this = shift;
    $this->writeTest( $wTopic, "", ( "a\n", "a\n\n" ) );
}

sub test_wt6 {
    my $this = shift;
    $this->writeTest( $wTopic, "", ( "a\nb\n", "a\nc\n" ) );
}

sub test_wt7 {
    my $this = shift;
    $this->writeTest( $wTopic, "", ( "one\n", "one\ntwo\n" ) );
}

sub test_wt8 {
    my $this = shift;
    $this->writeTest( $wTopic, "", ( "one\n", "one\ntwo\n" ) ); # TODO: badly broken
}

sub test_wt9 {
    my $this = shift;
    $this->writeTest( $wTopic, "", ( "one\nthree\nfour\n", "one\ntwo\nthree\n" ) );
}

sub test_wt10 {
    my $this = shift;
    $this->writeTest( $wTopic, "", ( "three\nfour\n", "one\ntwo\nthree\n" ) );
}

sub test_wt11 {
    my $this = shift;
    $this->writeTest( $wTopic, "", ( 'john.talintyre@drkw.com\n' ) ); # TODO: broken!
}

sub test_wt12 {
    my $this = shift;
    $this->writeTest( $wTopic, "", ( "", "w\n\n" ) );  
}

sub test_wt13 {
    my $this = shift;
    $this->writeTest( $wTopic, "", ( "det\nnwaw\ndjrz", "wjmpa\nnwaw\ndjrz" ) );
}

sub test_wt14 {
    my $this = shift;
    $this->writeTest( $wTopic, "", ( "ntyp\nzz", "fl\n\n" ) );
}

sub test_wt15 {
    my $this = shift;
    $this->writeTest( $wTopic, "", ( "nrcpb\n", "" ) );
}

sub test_wt16 {
    my $this = shift;
    $this->writeTest( $wTopic, "", ( "smifn", "\n" ) );
}

sub test_wt17 {
    my $this = shift;
    $this->writeTest( $wTopic, "", ( "\n", "mus\n" ) );
}

sub test_wt18 {
    my $this = shift;
    $this->writeTest( $wTopic, "", ( "jw\na\niky", "yorem\na\niky\n" ) );
}

sub test_wt19 {
    my $this = shift;
    $this->writeTest( $wTopic, "", ( "\nilw", "we\nilw" ) );
}

sub test_wt20 {
    my $this = shift;
    $this->writeTest( $wTopic, "", ( "a\nb\n", "a\nb\nc\n", "a\nb\nc\n" . chr(0xFF) . "\n" ) );
}

sub test_wa1 {
    my $this = shift;
    $this->writeTest( $wTopic, "it.doc", ( "a" ) );
}

sub test_wa2 {
    my $this = shift;
    $this->writeTest( $wTopic, "it.doc", ( "a\n" ) );
}

sub test_wa3 {
    my $this = shift;
    $this->writeTest( $wTopic, "it.doc", ( "a\n", "b\n" ) );
}

sub test_wa4 {
    my $this = shift;
    $this->writeTest( $wTopic, "it.doc", ( "a\n", "b" ) );
}

sub test_wa5 {
    my $this = shift;
    $this->writeTest( $wTopic, "it.doc", ( "a\n", "a\n\n" ) );
}

sub test_wa6 {
    my $this = shift;
    $this->writeTest( $wTopic, "it.doc", ( "a\nb\n", "a\nc\n" ) );
}

sub test_wa7 {
    my $this = shift;
    $this->writeTest( $wTopic, "it.doc", ( "one\n", "one\ntwo\n" ) );
}

sub test_wa8 {
    my $this = shift;
    $this->writeTest( $wTopic, "it.doc", ( "one\n", "one\ntwo\n" ) ); # TODO: badly broken
}

sub test_wa9 {
    my $this = shift;
    $this->writeTest( $wTopic, "it.doc", ( "one\nthree\nfour\n", "one\ntwo\nthree\n" ) );
}

sub test_wa10 {
    my $this = shift;
    $this->writeTest( $wTopic, "it.doc", ( "three\nfour\n", "one\ntwo\nthree\n" ) );
}

sub test_wa11 {
    my $this = shift;
    $this->writeTest( $wTopic, "it.doc", ( 'john.talintyre@drkw.com\n' ) ); # TODO: broken!
}

sub test_wa12 {
    my $this = shift;
    $this->writeTest( $wTopic, "it.doc", ( "", "w\n\n" ) );  
}

sub test_wa13 {
    my $this = shift;
    $this->writeTest( $wTopic, "it.doc", ( "det\nnwaw\ndjrz", "wjmpa\nnwaw\ndjrz" ) );
}

sub test_wa14 {
    my $this = shift;
    $this->writeTest( $wTopic, "it.doc", ( "ntyp\nzz", "fl\n\n" ) );
}

sub test_wa15 {
    my $this = shift;
    $this->writeTest( $wTopic, "it.doc", ( "nrcpb\n", "" ) );
}

sub test_wa16 {
    my $this = shift;
    $this->writeTest( $wTopic, "it.doc", ( "smifn", "\n" ) );
}

sub test_wa17 {
    my $this = shift;
    $this->writeTest( $wTopic, "it.doc", ( "\n", "mus\n" ) );
}

sub test_wa18 {
    my $this = shift;
    $this->writeTest( $wTopic, "it.doc", ( "jw\na\niky", "yorem\na\niky\n" ) );
}

sub test_wa19 {
    my $this = shift;
    $this->writeTest( $wTopic, "it.doc", ( "\nilw", "we\nilw" ) );
}

sub test_wa20 {
    my $this = shift;
    $this->writeTest( $wTopic, "it.doc", ( "a\nb\n", "a\nb\nc\n", "a\nb\nc\n" . chr(0xFF) . "\n" ) );
}

sub test_rt1 {
    my $this = shift;
    $this->checkRead( $rTopic, "it.doc", ( "a" ) );
}

sub test_rt2 {
    my $this = shift;
    $this->checkRead( $rTopic, "it.doc", ( "a\n" ) );
}

sub test_rt3 {
    my $this = shift;
    $this->checkRead( $rTopic, "it.doc", ( "a\n", "b\n" ) );
}

sub test_rt4 {
    my $this = shift;
    $this->checkRead( $rTopic, "it.doc", ( "a\n", "b" ) );
}

sub test_rt5 {
    my $this = shift;
    $this->checkRead( $rTopic, "it.doc", ( "a", "b\n" ) );
}

sub test_rt6 {
    my $this = shift;
    $this->checkRead( $rTopic, "it.doc", ( "a\n", "a\n\n" ) );
}

sub test_rt7 {
    my $this = shift;
    $this->checkRead( $rTopic, "it.doc", ( "a\nb\n", "a\nc\n" ) );
}

sub test_rt8 {
    my $this = shift;
    $this->checkRead( $rTopic, "it.doc", ( "one", "one\ntwo\n" ) );
}

sub test_rt9 {
    my $this = shift;
    $this->checkRead( $rTopic, "it.doc", ( "one\n", "one\ntwo\n" ) );
}

sub test_rt10 {
    my $this = shift;
    $this->checkRead( $rTopic, "it.doc", ( "one\nthree\nfour\n", "one\ntwo\nthree\n" ) );
}

sub test_rt11 {
    my $this = shift;
    $this->checkRead( $rTopic, "it.doc", ( "three\nfour\n", "one\ntwo\nthree\n" ) );
}

sub test_rt12 {
    my $this = shift;
    $this->checkRead( $rTopic, "it.doc", ( 'john.talintyre@drkw.com\n' ) );
}

sub test_rt13 {
    my $this = shift;
    $this->checkRead( $rTopic, "it.doc", ( "" ) );
}

sub test_rt14 {
    my $this = shift;
    $this->checkRead( $rTopic, "it.doc", ( "nrcpb\n", "" ) );
}

sub test_rt15 {
	my $this = shift;
    $this->checkRead( $rTopic, "it.doc", ( "smifn", "\n" ) );
}

sub test_rt16 {
    my $this = shift;
    $this->checkRead( $rTopic, "it.doc", ( "\n", "mus\n" ) );
}

sub test_rt17 {
    my $this = shift;
    $this->checkRead( $wTopic, "it.doc", ( "jw\na\niky", "yorem\na\niky\n" ) );
}

sub test_rt18 {
    my $this = shift;
    $this->checkRead( $rTopic, "it.doc", ( "\nilw", "we\nilw" ) );
}

sub test_rt19 {
    my $this = shift;
    $this->checkRead( $rTopic, "it.doc", ( "a\nb\n", "a\nb\nc\n", "a\nb\nc\n" . chr(0xFF) . "\n" ) );
}


sub test_ra1 {
    my $this = shift;
    $this->checkRead( $rTopic, "", ( "a" ) );
}

sub test_ra2 {
    my $this = shift;
    $this->checkRead( $rTopic, "", ( "a\n" ) );
}

sub test_ra3 {
    my $this = shift;
    $this->checkRead( $rTopic, "", ( "a\n", "b\n" ) );
}

sub test_ra4{
    my $this = shift;
    $this->checkRead( $rTopic, "", ( "a\n", "b" ) );
}

sub test_ra5 {
    my $this = shift;
    $this->checkRead( $rTopic, "", ( "a", "b\n" ) );
}

sub test_ra6 {
    my $this = shift;
    $this->checkRead( $rTopic, "", ( "a\n", "a\n\n" ) );
}

sub test_ra7 {
    my $this = shift;
    $this->checkRead( $rTopic, "", ( "a\nb\n", "a\nc\n" ) );
}

sub test_ra8 {
    my $this = shift;
    $this->checkRead( $rTopic, "", ( "one", "one\ntwo\n" ) );
}

sub test_ra9 {
    my $this = shift;
    $this->checkRead( $rTopic, "", ( "one\n", "one\ntwo\n" ) );
}

sub test_ra10 {
    my $this = shift;
    $this->checkRead( $rTopic, "", ( "one\nthree\nfour\n", "one\ntwo\nthree\n" ) );
}

sub test_ra11 {
    my $this = shift;
    $this->checkRead( $rTopic, "", ( "three\nfour\n", "one\ntwo\nthree\n" ) );
}

sub test_ra12 {
    my $this = shift;
    $this->checkRead( $rTopic, "", ( 'john.talintyre@drkw.com\n' ) );
}

sub test_ra13 { my $this = shift; $this->checkRead( $rTopic, "", ( "" ) ); }
sub test_ra14 { my $this = shift;
                $this->checkRead( $rTopic, "", ( "nrcpb\n", "" ) ); }
sub test_ra15 { my $this = shift;
                $this->checkRead( $rTopic, "", ( "smifn", "\n" ) ); }
sub test_ra16 { my $this = shift;
                $this->checkRead( $rTopic, "", ( "\n", "mus\n" ) ); }
sub test_ra17 { my $this = shift;
                $this->checkRead( $wTopic, "", ( "jw\na\niky", "yorem\na\niky\n" ) ); }
sub test_ra18 { my $this = shift;
                $this->checkRead( $rTopic, "", ( "\nilw", "we\nilw" ) ); }

sub test_d1 { my $this = shift; $this->rcsDiffOne("1\n", "\n" ); }
sub test_d2 { my $this = shift; $this->rcsDiffOne("\n", "1\n" ); }
sub test_d3 { my $this = shift; $this->rcsDiffOne("1\n", "2\n" ); }
sub test_d4 { my $this = shift; $this->rcsDiffOne("2\n", "1\n" ); }
sub test_d5 { my $this = shift;
              $this->rcsDiffOne("1\n2\n3\n", "a\n1\n2\n3\nb\n" ); }
sub test_d6 { my $this = shift;
              $this->rcsDiffOne("a\n1\n2\n3\nb\n", "1\n2\n3\n" ); }
sub test_d7 { my $this = shift;
              $this->rcsDiffOne("1\n2\n3\n", "a\nb\n1\n2\n3\nb\nb\n" ); }
sub test_d8 { my $this = shift;
              $this->rcsDiffOne("a\nb\n1\n2\n3\nb\nb\n", "1\n2\n3\n" ); }
sub test_d9 { my $this = shift;
              $this->rcsDiffOne("1\n2\n3\n4\n5\n6\n7\n8\none\nabc\nABC\ntwo\n",
                                "A\n1\n2\n3\none\nIII\niii\ntwo\nthree\n"); }
sub test_d10 {
    my $this = shift;
    $this->rcsDiffOne("A\n1\n2\n3\none\nIII\niii\ntwo\nthree\n",
                      "1\n2\n3\n4\n5\n6\n7\n8\none\nabc\nABC\ntwo\n");
}

# int(0.5) = 0
# int(1.0) = 1;
sub randRange {
    my( $min, $max ) = @_;
    my $val = $min + int( rand($max-$min+1) );
    $val = $max if( $val > $max );
    $val = $min if( $val < $min );
    return $val;
}

sub randLines {
    my( $maxChars ) = @_;
    my $chars = randRange( 0, $maxChars );
    my $text = "";
    for( my $i=0; $i<$chars; $i++ ) {
        my $asc = randRange(ord('a'),ord('z'));
        $text .= chr( $asc );
    }
    return $text;
}

# Random tests
# iterations - do a certain number of insertions and deletions
# count - changes for each time around
# pinsert - prob for an insert, 0 - 100
sub randTest {
    my( $this, $ident, $iterations, $count, $pinsert, $ndel ) = @_;
    my $web = "Test";
    my $topic = "RcsLiteRandom";
    my @vals = ();
    my @val  = ();
    for( my $i = 0; $i < $iterations; $i++ ) {
        my $changes = randRange(1,$count);
        for( my $j = 0; $j < $changes; $j++ ) {
            my $prob = randRange(0,100);
            my $insert = 1;
            $insert = 0 if( $prob > $pinsert );
            $insert = 1 if( ! @val );
            if( $insert ) {
                my $where = randRange(0, @val);
                my $what = randLines( 5 );
                splice @val, $where, 0, $what;
            } else {
                my $toDel = randRange( 0, $ndel );
                splice @val, randRange(0, @val), $toDel;
            }
        }
        push @val, ("") if( randRange( 0, 100 ) > 80 );
        my $text = join( "\n", @val );
        push @vals, $text;
    }
    #printVals( @vals );
    my $okay = $this->genTest( "", $topic, "TWiki::Store::RcsLite", "TWiki::Store::RcsLite", "", @vals );
    printVals( $ident, @vals ) if( ! $okay );
    return $okay;
}

sub printVals {
    my( $ident, @vals ) = @_;
    my $str = "( ";
    my $sep = "";
    foreach my $text (@vals) {
        $text =~ s/\n/\\n/go;
        $str .= $sep;
        $str .= "\"$text\"";
        $sep = ", ";
    }
    $str .= " )";
    print "$ident - $str\n";
}

sub genTest {
    my( $this,$ident, $topic, $write, $read, $attachment, @vals ) = @_;
    print "Test Generic ($attachment) $ident\n" if( $ident );
    my $web = "Test";
    my $writer = $write->new( $web, $topic, $attachment, @storeSettings );
    mug($writer);
    my $numRevs = @vals;
    for( my $i=0; $i<$numRevs; $i++ ) {
        addRevision( $writer, $attachment, $vals[$i], "comment " . $i, "JohnTalintyre" );
    }
    my $reader = $read->new( $web, $topic, $attachment, @storeSettings );
    my $okay = $this->assert_equals( $reader->numRevisions(), $numRevs, "Number of revisions should be the same" );
    if( $okay ) {
        for( my $i=$numRevs; $i>0; $i-- ) {
            my $text = $reader->getRevision( $i );
            $okay = $this->assert_equals( $vals[$i-1], $text, "Text should be same for revision $i" );
        }
    }
    return $okay;
}

sub test_ciLocked {
    my $this = shift;
    my $web = "Test";
    my $topic = "CiLocked";

    # create the fixture
    my $rcs = TWiki::Store::RcsWrap->new( $web, $topic, "", @storeSettings );
    $rcs->addRevision( "Shooby Dooby", "original", "BungditDin" );
    # hack the lock so someone else has it
    my $user = `whoami`;
    chop($user);
    my $vfile = $rcs->file().",v";
    my $txt = $rcs->_readFile($vfile);
    $txt =~ s/$user/blocker_socker/g;
    `chmod 777 $vfile`;
    $rcs->_saveFile( $vfile, $txt);
    # file is now locked by blocker_socker, save some new text
    $rcs->_saveFile( $rcs->file(), "Shimmy Dimmy" );
    # check it in
    $rcs->_ci( $rcs->file(), "Gotcha", "SheikAlot" );
    $txt = $rcs->_readFile($vfile);
    # make sure the lock is right
    $this->assert_matches(qr/locks\n\s+$user:1\./s, $txt);
}

1;
