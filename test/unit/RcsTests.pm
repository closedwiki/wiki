# Tests for TWiki::Store::RcsLite and TWiki::Store::RcsWrap
# JohnTalintyre
# Ported to Test::Unit by CrawfordCurrie
require 5.006;
use strict;

package RcsTests;

use base qw(Test::Unit::TestCase);

BEGIN {
    unshift @INC, '../../bin';
    require 'setlib.cfg';
};

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

use TWiki;
use TWiki::Store;
use TWiki::Store::RcsLite;
use TWiki::Store::RcsWrap;

my $web = "TestRcsWeb";
my $topic = "TestRcsTopic";
my $user = "TestUser1";
my $thePathInfo = "/$web/$topic";
my $theUrl = "/save/$web/$topic";

my $rTopic = "RcsLiteRTest";
my $wTopic = "RcsLiteWTest";
my $attachment = "it.doc";
my $twiki;
my $saveWF;

sub set_up {
    my $this = shift;
    die unless (defined $TWiki::cfg{PubUrlPath});
    die unless (defined $TWiki::cfg{ScriptSuffix});
    $twiki = new TWiki( $thePathInfo, $user, $topic, $theUrl );
    $saveWF = $TWiki::cfg{WarningFileName};
    $TWiki::cfg{WarningFileName} = "/tmp/junk";
    die unless $twiki;
    die unless $twiki->{prefs};
    mkdir("$TWiki::cfg{DataDir}/$web",0777);
    mkdir("$TWiki::cfg{PubDir}/$web",0777);
}

sub tear_down {
    $TWiki::cfg{WarningFileName} = $saveWF;
    `rm -rf $TWiki::cfg{DataDir}/$web`;
    `rm -rf $TWiki::cfg{PubDir}/$web`;
}

# Get rid a topic and its attachments completely
sub mug {
    my( $self ) = @_;

    my $web = $self->{web};
    my $topic = $self->{topic};

    my $rcsFile = "$TWiki::cfg{DataDir}/$web/RCS/$topic,v";
    my @files = ( $self->{file}, $self->{rcsFile}, $rcsFile );
    unlink( @files );
    $self->init();
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
            open( FILE, ">$name" ) or die "Can't create file $name\n";
            binmode( FILE );
            print FILE $text;
            close( FILE);
            $text = $name;
        }
    }
    $handler->addRevision( $text, $comment, $who );
}


sub verifyWrap {
    my( $this, $topic, $attachment, @vals ) = @_;
    my $numRevs = $#vals + 1;

    my $rcs = new TWiki::Store::RcsWrap( $twiki, $web, $topic, $attachment );
    for( my $i=0; $i<$numRevs; $i++ ) {
        addRevision( $rcs, $attachment, $vals[$i], "comment " . $i, "JohnTalintyre" );
    }
    $this->assert_equals($numRevs, $rcs->numRevisions());
    for( my $i=$numRevs; $i>0; $i-- ) {
        my $text = $rcs->getRevision( $i );
        $this->assert_equals( $vals[$i-1], $text );
    }

    return $rcs;
}

sub verifyLite {
    my( $this, $topic, $attachment, @vals ) = @_;
    my $numRevs = $#vals + 1;

    my $rcs = new TWiki::Store::RcsWrap( $twiki, $web, $topic, $attachment );
    for( my $i=0; $i<$numRevs; $i++ ) {
        addRevision( $rcs, $attachment, $vals[$i], "comment " . $i, "JohnTalintyre" );
    }
    $this->assert_equals($numRevs, $rcs->numRevisions());
    for( my $i=$numRevs; $i>0; $i-- ) {
        my $text = $rcs->getRevision( $i );
        $this->assert_equals( $vals[$i-1], $text );
    }
    return $rcs;
}

sub test_repRevRcs {
    my $this = shift;
    my $topic = "RcsRepRev";

    my $rcs = TWiki::Store::RcsWrap->new( $twiki, $web, $topic, "" );
    $rcs->addRevision( "there was a man\n\n", "in once", "JohnTalintyre" );
    $this->assert_equals( "there was a man\n\n", $rcs->getRevision(1) );
    $this->assert_equals( 1, $rcs->numRevisions() );

    $rcs->replaceRevision( "there was a cat\n", "1st replace",
                           "NotJohnTalintyre", time() );
    $this->assert_equals( 1, $rcs->numRevisions() );
    $this->assert_equals( "there was a cat\n", $rcs->getRevision(1) );
    $rcs->addRevision( "and now this\n\n\n", "2nd entry", "J1" );
    $this->assert_equals( 2, $rcs->numRevisions() );
    $this->assert_equals( "there was a cat\n", $rcs->getRevision(1) );
    $this->assert_equals( "and now this\n\n\n", $rcs->getRevision(2) );

    $rcs->replaceRevision( "then this", "2nd replace", "J2", time() );
    $this->assert_equals( 2, $rcs->numRevisions );
    $this->assert_equals( "there was a cat\n", $rcs->getRevision(1) );
    $this->assert_equals( "then this", $rcs->getRevision(2) );
}

sub test_repRevRcsLite {
    my $this = shift;
    my $topic = "RcsLiteRepRev";

    my $rcs = TWiki::Store::RcsLite->new( $twiki, $web, $topic, "" );
    $rcs->addRevision( "there was a man\n\n", "in once", "JohnTalintyre" );
    $this->assert_equals( "there was a man\n\n", $rcs->getRevision(1) );
    $this->assert_equals( 1, $rcs->numRevisions() );

    $rcs->replaceRevision( "there was a cat\n", "1st replace",
                           "NotJohnTalintyre", time() );
    $this->assert_equals( 1, $rcs->numRevisions() );
    $this->assert_equals( "there was a cat\n", $rcs->getRevision(1) );
    $rcs->addRevision( "and now this\n\n\n", "2nd entry", "J1" );
    $this->assert_equals( 2, $rcs->numRevisions() );
    $this->assert_equals( "there was a cat\n", $rcs->getRevision(1) );
    $this->assert_equals( "and now this\n\n\n", $rcs->getRevision(2) );

    $rcs->replaceRevision( "then this", "2nd replace", "J2", time() );
    $this->assert_equals( 2, $rcs->numRevisions );
    $this->assert_equals( "there was a cat\n", $rcs->getRevision(1) );
    $this->assert_equals( "then this", $rcs->getRevision(2) );
}

# Outputs delta for helping to work out how to do things
sub refDelta {
    my( $old, $new ) = @_;
    my $topic = "RefDelta";
    my $rcs = TWiki::Store::RcsWrap->new( $twiki, $web, $topic, "" );
    $rcs->addRevision( $old, "old comment", "JohnTalintyre" );   
    $rcs->addRevision( $new, "old comment", "JohnTalintyre" );   
    my $rcsLite = TWiki::Store::RcsLite->new( $twiki, $web, $topic, "" );
    my $delta = $rcsLite->delta(1);
    print "Old:\n\"$old\"\n";
    print "New:\n\"$new\"\n";
    print "Delta new->old:\n\"$delta\"\n\n"; 
}

sub test_wt1Lite {
    my $this = shift;
    $this->verifyLite( $wTopic, "", ( "a" ) );
}

sub test_wt1Wrap {
    my $this = shift;
    $this->verifyWrap( $wTopic, "", ( "a" ) );
}

sub test_wt2Lite {
    my $this = shift;
    $this->verifyLite( $wTopic, "", ( "a\n" ) );
}

sub test_wt2Wrap {
    my $this = shift;
    $this->verifyWrap( $wTopic, "", ( "a\n" ) );
}

sub test_wt3Lite {
    my $this = shift;
    $this->verifyLite( $wTopic, "", ( "a\n", "b\n" ) );
}

sub test_wt3Wrap {
    my $this = shift;
    $this->verifyWrap( $wTopic, "", ( "a\n", "b\n" ) );
}

sub test_wt4Lite {
    my $this = shift;
    $this->verifyLite( $wTopic, "", ( "a\n", "b" ) );
}

sub test_wt4Wrap {
    my $this = shift;
    $this->verifyWrap( $wTopic, "", ( "a\n", "b" ) );
}

sub test_wt5Lite {
    my $this = shift;
    $this->verifyLite( $wTopic, "", ( "a\n", "a\n\n" ) );
}

sub test_wt5Wrap {
    my $this = shift;
    $this->verifyWrap( $wTopic, "", ( "a\n", "a\n\n" ) );
}

sub test_wt6Lite {
    my $this = shift;
    $this->verifyLite( $wTopic, "", ( "a\nb\n", "a\nc\n" ) );
}

sub test_wt6Wrap {
    my $this = shift;
    $this->verifyWrap( $wTopic, "", ( "a\nb\n", "a\nc\n" ) );
}

sub test_wt7Lite {
    my $this = shift;
    $this->verifyLite( $wTopic, "", ( "one\n", "one\ntwo\n" ) );
}

sub test_wt7Wrap {
    my $this = shift;
    $this->verifyWrap( $wTopic, "", ( "one\n", "one\ntwo\n" ) );
}

sub test_wt8Lite {
    my $this = shift;
    $this->verifyLite( $wTopic, "", ( "one\n", "one\ntwo\n" ) ); # TODO: badly broken
}

sub test_wt8Wrap {
    my $this = shift;
    $this->verifyWrap( $wTopic, "", ( "one\n", "one\ntwo\n" ) ); # TODO: badly broken
}

sub test_wt9Lite {
    my $this = shift;
    $this->verifyLite( $wTopic, "", ( "one\nthree\nfour\n", "one\ntwo\nthree\n" ) );
}

sub test_wt9Wrap {
    my $this = shift;
    $this->verifyWrap( $wTopic, "", ( "one\nthree\nfour\n", "one\ntwo\nthree\n" ) );
}

sub test_wt10Lite {
    my $this = shift;
    $this->verifyLite( $wTopic, "", ( "three\nfour\n", "one\ntwo\nthree\n" ) );
}

sub test_wt10Wrap {
    my $this = shift;
    $this->verifyWrap( $wTopic, "", ( "three\nfour\n", "one\ntwo\nthree\n" ) );
}

sub test_wt11Lite {
    my $this = shift;
    $this->verifyLite( $wTopic, "", ( "john.talintyre\@drkw.com\n" ) );
}

sub test_wt11Wrap {
    my $this = shift;
    $this->verifyWrap( $wTopic, "", ( "john.talintyre\@drkw.com\n" ) );
}

# ensure RCS keywords are not expanded in the checked-out version
sub test_rcsKeywordsWrap {
    my $this = shift;
    my $check = '$Author$ $Date$ $Header$ $Id$ $Locker$ $Log$ $Name$ $RCSfile$ $Revision$ $Source$ $State$';
    my $rcs = $this->verifyWrap( $wTopic, "", ( $check ) );
    open(F,"<$rcs->{file}");
    undef $/;
    $this->assert_str_equals($check, <F>);
    close(F);
}

sub test_wt12Lite {
    my $this = shift;
    $this->verifyLite( $wTopic, "", ( "", "w\n\n" ) );  
}

sub test_wt12Wrap {
    my $this = shift;
    $this->verifyWrap( $wTopic, "", ( "", "w\n\n" ) );  
}

sub test_wt13Lite {
    my $this = shift;
    $this->verifyLite( $wTopic, "", ( "det\nnwaw\ndjrz", "wjmpa\nnwaw\ndjrz" ) );
}

sub test_wt13Wrap {
    my $this = shift;
    $this->verifyWrap( $wTopic, "", ( "det\nnwaw\ndjrz", "wjmpa\nnwaw\ndjrz" ) );
}

sub test_wt14Lite {
    my $this = shift;
    $this->verifyLite( $wTopic, "", ( "ntyp\nzz", "fl\n\n" ) );
}

sub test_wt14Wrap {
    my $this = shift;
    $this->verifyWrap( $wTopic, "", ( "ntyp\nzz", "fl\n\n" ) );
}

sub test_wt15Lite {
    my $this = shift;
    $this->verifyLite( $wTopic, "", ( "nrcpb\n", "" ) );
}

sub test_wt15Wrap {
    my $this = shift;
    $this->verifyWrap( $wTopic, "", ( "nrcpb\n", "" ) );
}

sub test_wt16Lite {
    my $this = shift;
    $this->verifyLite( $wTopic, "", ( "smifn", "\n" ) );
}

sub test_wt16Wrap {
    my $this = shift;
    $this->verifyWrap( $wTopic, "", ( "smifn", "\n" ) );
}

sub test_wt17Lite {
    my $this = shift;
    $this->verifyLite( $wTopic, "", ( "\n", "mus\n" ) );
}

sub test_wt17Wrap {
    my $this = shift;
    $this->verifyWrap( $wTopic, "", ( "\n", "mus\n" ) );
}

sub test_wt18Lite {
    my $this = shift;
    $this->verifyLite( $wTopic, "", ( "jw\na\niky", "yorem\na\niky\n" ) );
}

sub test_wt18Wrap {
    my $this = shift;
    $this->verifyWrap( $wTopic, "", ( "jw\na\niky", "yorem\na\niky\n" ) );
}

sub test_wt19Lite {
    my $this = shift;
    $this->verifyLite( $wTopic, "", ( "\nilw", "we\nilw" ) );
}

sub test_wt19Wrap {
    my $this = shift;
    $this->verifyWrap( $wTopic, "", ( "\nilw", "we\nilw" ) );
}

sub test_wt20Lite {
    my $this = shift;
    $this->verifyLite( $wTopic, "", ( "a\nb\n", "a\nb\nc\n", "a\nb\nc\n" . chr(0xFF) . "\n" ) );
}

sub test_wt20Wrap {
    my $this = shift;
    $this->verifyWrap( $wTopic, "", ( "a\nb\n", "a\nb\nc\n", "a\nb\nc\n" . chr(0xFF) . "\n" ) );
}

sub test_wa1Lite {
    my $this = shift;
    $this->verifyLite( $wTopic, "it.doc", ( "a" ) );
}

sub test_wa1Wrap {
    my $this = shift;
    $this->verifyWrap( $wTopic, "it.doc", ( "a" ) );
}

sub test_wa2Lite {
    my $this = shift;
    $this->verifyLite( $wTopic, "it.doc", ( "a\n" ) );
}

sub test_wa2Wrap {
    my $this = shift;
    $this->verifyWrap( $wTopic, "it.doc", ( "a\n" ) );
}

sub test_wa3Lite {
    my $this = shift;
    $this->verifyLite( $wTopic, "it.doc", ( "a\n", "b\n" ) );
}

sub test_wa3Wrap {
    my $this = shift;
    $this->verifyWrap( $wTopic, "it.doc", ( "a\n", "b\n" ) );
}

sub test_wa4Lite {
    my $this = shift;
    $this->verifyLite( $wTopic, "it.doc", ( "a\n", "b" ) );
}

sub test_wa4Wrap {
    my $this = shift;
    $this->verifyWrap( $wTopic, "it.doc", ( "a\n", "b" ) );
}

sub test_wa5Lite {
    my $this = shift;
    $this->verifyLite( $wTopic, "it.doc", ( "a\n", "a\n\n" ) );
}

sub test_wa5Wrap {
    my $this = shift;
    $this->verifyWrap( $wTopic, "it.doc", ( "a\n", "a\n\n" ) );
}

sub test_wa6Lite {
    my $this = shift;
    $this->verifyLite( $wTopic, "it.doc", ( "a\nb\n", "a\nc\n" ) );
}

sub test_wa6Wrap {
    my $this = shift;
    $this->verifyWrap( $wTopic, "it.doc", ( "a\nb\n", "a\nc\n" ) );
}

sub test_wa7Lite {
    my $this = shift;
    $this->verifyLite( $wTopic, "it.doc", ( "one\n", "one\ntwo\n" ) );
}

sub test_wa7Wrap {
    my $this = shift;
    $this->verifyWrap( $wTopic, "it.doc", ( "one\n", "one\ntwo\n" ) );
}

sub test_wa8Lite {
    my $this = shift;
    $this->verifyLite( $wTopic, "it.doc", ( "one\n", "one\ntwo\n" ) ); # TODO: badly broken
}

sub test_wa8Wrap {
    my $this = shift;
    $this->verifyWrap( $wTopic, "it.doc", ( "one\n", "one\ntwo\n" ) ); # TODO: badly broken
}

sub test_wa9Lite {
    my $this = shift;
    $this->verifyLite( $wTopic, "it.doc", ( "one\nthree\nfour\n", "one\ntwo\nthree\n" ) );
}

sub test_wa9Wrap {
    my $this = shift;
    $this->verifyWrap( $wTopic, "it.doc", ( "one\nthree\nfour\n", "one\ntwo\nthree\n" ) );
}

sub test_wa10Lite {
    my $this = shift;
    $this->verifyLite( $wTopic, "it.doc", ( "three\nfour\n", "one\ntwo\nthree\n" ) );
}

sub test_wa10Wrap {
    my $this = shift;
    $this->verifyWrap( $wTopic, "it.doc", ( "three\nfour\n", "one\ntwo\nthree\n" ) );
}

sub test_wa11Lite {
    my $this = shift;
    $this->verifyLite( $wTopic, "it.doc", ( "john.talintyre\@drkw.com\n" ) ); # TODO: broken!
}

sub test_wa11Wrap {
    my $this = shift;
    $this->verifyWrap( $wTopic, "it.doc", ( "john.talintyre\@drkw.com\n" ) ); # TODO: broken!
}

sub test_wa12Lite {
    my $this = shift;
    $this->verifyLite( $wTopic, "it.doc", ( "", "w\n\n" ) );  
}

sub test_wa12Wrap {
    my $this = shift;
    $this->verifyWrap( $wTopic, "it.doc", ( "", "w\n\n" ) );  
}

sub test_wa13Lite {
    my $this = shift;
    $this->verifyLite( $wTopic, "it.doc", ( "det\nnwaw\ndjrz", "wjmpa\nnwaw\ndjrz" ) );
}

sub test_wa13Wrap {
    my $this = shift;
    $this->verifyWrap( $wTopic, "it.doc", ( "det\nnwaw\ndjrz", "wjmpa\nnwaw\ndjrz" ) );
}

sub test_wa14Lite {
    my $this = shift;
    $this->verifyLite( $wTopic, "it.doc", ( "ntyp\nzz", "fl\n\n" ) );
}

sub test_wa14Wrap {
    my $this = shift;
    $this->verifyWrap( $wTopic, "it.doc", ( "ntyp\nzz", "fl\n\n" ) );
}

sub test_wa15Lite {
    my $this = shift;
    $this->verifyLite( $wTopic, "it.doc", ( "nrcpb\n", "" ) );
}

sub test_wa15Wrap {
    my $this = shift;
    $this->verifyWrap( $wTopic, "it.doc", ( "nrcpb\n", "" ) );
}

sub test_wa16Lite {
    my $this = shift;
    $this->verifyLite( $wTopic, "it.doc", ( "smifn", "\n" ) );
}

sub test_wa16Wrap {
    my $this = shift;
    $this->verifyWrap( $wTopic, "it.doc", ( "smifn", "\n" ) );
}

sub test_wa17Lite {
    my $this = shift;
    $this->verifyLite( $wTopic, "it.doc", ( "\n", "mus\n" ) );
}

sub test_wa17Wrap {
    my $this = shift;
    $this->verifyWrap( $wTopic, "it.doc", ( "\n", "mus\n" ) );
}

sub test_wa18Lite {
    my $this = shift;
    $this->verifyLite( $wTopic, "it.doc", ( "jw\na\niky", "yorem\na\niky\n" ) );
}

sub test_wa18Wrap {
    my $this = shift;
    $this->verifyWrap( $wTopic, "it.doc", ( "jw\na\niky", "yorem\na\niky\n" ) );
}

sub test_wa19Lite {
    my $this = shift;
    $this->verifyLite( $wTopic, "it.doc", ( "\nilw", "we\nilw" ) );
}

sub test_wa19Wrap {
    my $this = shift;
    $this->verifyWrap( $wTopic, "it.doc", ( "\nilw", "we\nilw" ) );
}

sub test_wa20Lite {
    my $this = shift;
    $this->verifyLite( $wTopic, "it.doc", ( "a\nb\n", "a\nb\nc\n", "a\nb\nc\n" . chr(0xFF) . "\n" ) );
}

# ensure RCS keywords are not expanded in the checked-out version
sub test_rcsKeywordsLite {
    my $this = shift;
    my $check = '$Author$ $Date$ $Header$ $Id$ $Locker$ $Log$ $Name$ $RCSfile$ $Revision$ $Source$ $State$';
    my $rcs = $this->verifyLite( $wTopic, "", ( $check ) );
    open(F,"<$rcs->{file}");
    undef $/;
    $this->assert_str_equals($check, <F>);
    close(F);
}

sub test_wa20Wrap {
    my $this = shift;
    $this->verifyWrap( $wTopic, "it.doc", ( "a\nb\n", "a\nb\nc\n", "a\nb\nc\n" . chr(0xFF) . "\n" ) );
}

sub test_rt1Wrap {
    my $this = shift;
    $this->verifyWrap( $rTopic, "it.doc", ( "a" ) );
}

sub test_rt1Lite {
    my $this = shift;
    $this->verifyLite( $rTopic, "it.doc", ( "a" ) );
}

sub test_rt2Wrap {
    my $this = shift;
    $this->verifyWrap( $rTopic, "it.doc", ( "a\n" ) );
}

sub test_rt2Lite {
    my $this = shift;
    $this->verifyLite( $rTopic, "it.doc", ( "a\n" ) );
}

sub test_rt3Wrap {
    my $this = shift;
    $this->verifyWrap( $rTopic, "it.doc", ( "a\n", "b\n" ) );
}

sub test_rt3Lite {
    my $this = shift;
    $this->verifyLite( $rTopic, "it.doc", ( "a\n", "b\n" ) );
}

sub test_rt4Wrap {
    my $this = shift;
    $this->verifyWrap( $rTopic, "it.doc", ( "a\n", "b" ) );
}

sub test_rt4Lite {
    my $this = shift;
    $this->verifyLite( $rTopic, "it.doc", ( "a\n", "b" ) );
}

sub test_rt5Wrap {
    my $this = shift;
    $this->verifyWrap( $rTopic, "it.doc", ( "a", "b\n" ) );
}

sub test_rt5Lite {
    my $this = shift;
    $this->verifyLite( $rTopic, "it.doc", ( "a", "b\n" ) );
}

sub test_rt6Wrap {
    my $this = shift;
    $this->verifyWrap( $rTopic, "it.doc", ( "a\n", "a\n\n" ) );
}

sub test_rt6Lite {
    my $this = shift;
    $this->verifyLite( $rTopic, "it.doc", ( "a\n", "a\n\n" ) );
}

sub test_rt7Wrap {
    my $this = shift;
    $this->verifyWrap( $rTopic, "it.doc", ( "a\nb\n", "a\nc\n" ) );
}

sub test_rt7Lite {
    my $this = shift;
    $this->verifyLite( $rTopic, "it.doc", ( "a\nb\n", "a\nc\n" ) );
}

sub test_rt8Wrap {
    my $this = shift;
    $this->verifyWrap( $rTopic, "it.doc", ( "one", "one\ntwo\n" ) );
}

sub test_rt8Lite {
    my $this = shift;
    $this->verifyLite( $rTopic, "it.doc", ( "one", "one\ntwo\n" ) );
}

sub test_rt9Wrap {
    my $this = shift;
    $this->verifyWrap( $rTopic, "it.doc", ( "one\n", "one\ntwo\n" ) );
}

sub test_rt9Lite {
    my $this = shift;
    $this->verifyLite( $rTopic, "it.doc", ( "one\n", "one\ntwo\n" ) );
}

sub test_rt10Wrap {
    my $this = shift;
    $this->verifyWrap( $rTopic, "it.doc", ( "one\nthree\nfour\n", "one\ntwo\nthree\n" ) );
}

sub test_rt10Lite {
    my $this = shift;
    $this->verifyLite($rTopic, "it.doc", ( "one\nthree\nfour\n", "one\ntwo\nthree\n" ) );
}

sub test_rt11Wrap {
    my $this = shift;
    $this->verifyWrap( $rTopic, "it.doc", ( "three\nfour\n", "one\ntwo\nthree\n" ) );
}

sub test_rt11Lite {
    my $this = shift;
    $this->verifyLite($rTopic, "it.doc", ( "three\nfour\n", "one\ntwo\nthree\n" ) );
}

sub test_rt12Wrap {
    my $this = shift;
    $this->verifyWrap( $rTopic, "it.doc", ( "john.talintyre\@drkw.com\n" ) );
}

sub test_rt12Lite {
    my $this = shift;
    $this->verifyLite($rTopic, "it.doc", ( "john.talintyre\@drkw.com\n" ) );
}

sub test_rt13Wrap {
    my $this = shift;
    $this->verifyWrap( $rTopic, "it.doc", ( "" ) );
}

sub test_rt13Lite {
    my $this = shift;
    $this->verifyLite($rTopic, "it.doc", ( "" ) );
}

sub test_rt14Wrap {
    my $this = shift;
    $this->verifyWrap( $rTopic, "it.doc", ( "nrcpb\n", "" ) );
}

sub test_rt14Lite {
    my $this = shift;
    $this->verifyLite($rTopic, "it.doc", ( "nrcpb\n", "" ) );
}

sub test_rt15Wrap {
	my $this = shift;
    $this->verifyWrap( $rTopic, "it.doc", ( "smifn", "\n" ) );
}

sub test_rt15Lite {
	my $this = shift;
    $this->verifyLite($rTopic, "it.doc", ( "smifn", "\n" ) );
}

sub test_rt16Wrap {
    my $this = shift;
    $this->verifyWrap( $rTopic, "it.doc", ( "\n", "mus\n" ) );
}

sub test_rt16Lite {
    my $this = shift;
    $this->verifyLite($rTopic, "it.doc", ( "\n", "mus\n" ) );
}

sub test_rt17Wrap {
    my $this = shift;
    $this->verifyWrap( $wTopic, "it.doc", ( "jw\na\niky", "yorem\na\niky\n" ) );
}

sub test_rt17Lite {
    my $this = shift;
    $this->verifyLite($wTopic, "it.doc", ( "jw\na\niky", "yorem\na\niky\n" ) );
}

sub test_rt18Wrap {
    my $this = shift;
    $this->verifyWrap( $rTopic, "it.doc", ( "\nilw", "we\nilw" ) );
}

sub test_rt18Lite {
    my $this = shift;
    $this->verifyLite($rTopic, "it.doc", ( "\nilw", "we\nilw" ) );
}

sub test_rt19Wrap {
    my $this = shift;
    $this->verifyWrap( $rTopic, "it.doc", ( "a\nb\n", "a\nb\nc\n", "a\nb\nc\n" . chr(0xFF) . "\n" ) );
}

sub test_rt19Lite {
    my $this = shift;
    $this->verifyLite($rTopic, "it.doc", ( "a\nb\n", "a\nb\nc\n", "a\nb\nc\n" . chr(0xFF) . "\n" ) );
}

sub test_ra1Wrap {
    my $this = shift;
    $this->verifyWrap( $rTopic, "", ( "a" ) );
}

sub test_ra1Lite {
    my $this = shift;
    $this->verifyLite( $rTopic, "", ( "a" ) );
}

sub test_ra2Wrap {
    my $this = shift;
    $this->verifyWrap( $rTopic, "", ( "a\n" ) );
}

sub test_ra2Lite {
    my $this = shift;
    $this->verifyLite( $rTopic, "", ( "a\n" ) );
}

sub test_ra3Wrap {
    my $this = shift;
    $this->verifyWrap( $rTopic, "", ( "a\n", "b\n" ) );
}

sub test_ra3Lite {
    my $this = shift;
    $this->verifyLite( $rTopic, "", ( "a\n", "b\n" ) );
}

sub test_raWrap4{
    my $this = shift;
    $this->verifyWrap( $rTopic, "", ( "a\n", "b" ) );
}

sub test_raLite4{
    my $this = shift;
    $this->verifyLite( $rTopic, "", ( "a\n", "b" ) );
}

sub test_ra5Wrap {
    my $this = shift;
    $this->verifyWrap( $rTopic, "", ( "a", "b\n" ) );
}

sub test_ra5Lite {
    my $this = shift;
    $this->verifyLite( $rTopic, "", ( "a", "b\n" ) );
}

sub test_ra6Wrap {
    my $this = shift;
    $this->verifyWrap( $rTopic, "", ( "a\n", "a\n\n" ) );
}

sub test_ra6Lite {
    my $this = shift;
    $this->verifyLite( $rTopic, "", ( "a\n", "a\n\n" ) );
}

sub test_ra7Wrap {
    my $this = shift;
    $this->verifyWrap( $rTopic, "", ( "a\nb\n", "a\nc\n" ) );
}

sub test_ra7Lite {
    my $this = shift;
    $this->verifyLite( $rTopic, "", ( "a\nb\n", "a\nc\n" ) );
}

sub test_ra8Wrap {
    my $this = shift;
    $this->verifyWrap( $rTopic, "", ( "one", "one\ntwo\n" ) );
}

sub test_ra8Lite {
    my $this = shift;
    $this->verifyLite( $rTopic, "", ( "one", "one\ntwo\n" ) );
}

sub test_ra9Wrap {
    my $this = shift;
    $this->verifyWrap( $rTopic, "", ( "one\n", "one\ntwo\n" ) );
}

sub test_ra9Lite {
    my $this = shift;
    $this->verifyLite( $rTopic, "", ( "one\n", "one\ntwo\n" ) );
}

sub test_ra10Wrap {
    my $this = shift;
    $this->verifyWrap( $rTopic, "", ( "one\nthree\nfour\n", "one\ntwo\nthree\n" ) );
}

sub test_ra10Lite {
    my $this = shift;
    $this->verifyLite($rTopic, "", ( "one\nthree\nfour\n", "one\ntwo\nthree\n" ) );
}

sub test_ra11Wrap {
    my $this = shift;
    $this->verifyWrap( $rTopic, "", ( "three\nfour\n", "one\ntwo\nthree\n" ) );
}

sub test_ra11Lite {
    my $this = shift;
    $this->verifyLite($rTopic, "", ( "three\nfour\n", "one\ntwo\nthree\n" ) );
}

sub test_ra12Wrap {
    my $this = shift;
    $this->verifyWrap( $rTopic, "", ( "john.talintyre\@drkw.com\n" ) );
}

sub test_ra12Lite {
    my $this = shift;
    $this->verifyLite($rTopic, "", ( "john.talintyre\@drkw.com\n" ) );
}

sub test_ra13Wrap {
    my $this = shift;
    $this->verifyWrap( $rTopic, "", ( "" ) );
}

sub test_ra13Lite {
    my $this = shift;
    $this->verifyLite($rTopic, "", ( "" ) );
}

sub test_ra14Wrap {
    my $this = shift;
    $this->verifyWrap( $rTopic, "", ( "nrcpb\n", "" ) );
}

sub test_ra14Lite {
    my $this = shift;
    $this->verifyLite($rTopic, "", ( "nrcpb\n", "" ) );
}

sub test_ra15Wrap {
    my $this = shift;
    $this->verifyWrap( $rTopic, "", ( "smifn", "\n" ) );
}

sub test_ra15Lite {
    my $this = shift;
    $this->verifyLite($rTopic, "", ( "smifn", "\n" ) );
}

sub test_ra16Wrap {
    my $this = shift;
    $this->verifyWrap( $rTopic, "", ( "\n", "mus\n" ) );
}

sub test_ra16Lite {
    my $this = shift;
    $this->verifyLite($rTopic, "", ( "\n", "mus\n" ) );
}

sub test_ra17Wrap {
    my $this = shift;
    $this->verifyWrap( $wTopic, "", ( "jw\na\niky", "yorem\na\niky\n" ) );
}

sub test_ra17Lite {
    my $this = shift;
    $this->verifyLite($wTopic, "", ( "jw\na\niky", "yorem\na\niky\n" ) );
}

sub test_ra18Wrap {
    my $this = shift;
    $this->verifyWrap( $rTopic, "", ( "\nilw", "we\nilw" ) );
}

sub test_ra18Lite {
    my $this = shift;
    $this->verifyLite($rTopic, "", ( "\nilw", "we\nilw" ) );
}

sub rcsDiffOne {
    my( $this, @vals ) = @_;
    my $topic = "RcsDiffTest";
    my $rcs = TWiki::Store::RcsWrap->new( $twiki, $web, $topic, "" );
    #print "Rcs Diff test $num\n";
    $rcs->addRevision( $vals[0], "num 0", "JohnTalintyre" );
    $rcs->addRevision( $vals[1], "num 1", "JohnTalintyre" );
    my $diff = $rcs->revisionDiff( 1, 2 );
    my $rcsLite = TWiki::Store::RcsLite->new( $twiki, $web, $topic, "" );
    my $diffLite = $rcsLite->revisionDiff( 1, 2 );

    for ( my $i = 0; $i <= $#$diffLite && $i <= $#$diff; $i++ ) {
        print "\nL: ".$i.": ".join("\t", @{$diffLite->[$i]});
        print "\nH: ".$i.": ".join("\t", @{$diff->[$i]});
    }

    my $i = 0;
    while ( $i <= $#$diffLite && $i <= $#$diff ) {
        my $a = $i.": ".join("\t", @{$diffLite->[$i]});
        my $b = $i.": ".join("\t", @{$diff->[$i]});

        $this->assert_str_equals( $b, $a );
        $i++;
    }
    $this->assert_equals( $#$diffLite, $#$diff );
}

# Note that diff tests as written don't work; the diffs are
# not equivalent in the two implementations, though both are valid.
sub dont_test_d1 { my $this = shift; $this->rcsDiffOne("1\n", "\n" ); }
sub dont_test_d2 { my $this = shift; $this->rcsDiffOne("\n", "1\n" ); }
sub dont_test_d3 { my $this = shift; $this->rcsDiffOne("1\n", "2\n" ); }
sub dont_test_d4 { my $this = shift; $this->rcsDiffOne("2\n", "1\n" ); }
sub dont_test_d5 { my $this = shift;
              $this->rcsDiffOne("1\n2\n3\n", "a\n1\n2\n3\nb\n" ); }
sub dont_test_d6 { my $this = shift;
              $this->rcsDiffOne("a\n1\n2\n3\nb\n", "1\n2\n3\n" ); }
sub dont_test_d7 { my $this = shift;
              $this->rcsDiffOne("1\n2\n3\n", "a\nb\n1\n2\n3\nb\nb\n" ); }
sub dont_test_d8 { my $this = shift;
              $this->rcsDiffOne("a\nb\n1\n2\n3\nb\nb\n", "1\n2\n3\n" ); }
sub dont_test_d9 { my $this = shift;
              $this->rcsDiffOne("1\n2\n3\n4\n5\n6\n7\n8\none\nabc\nABC\ntwo\n",
                                "A\n1\n2\n3\none\nIII\niii\ntwo\nthree\n"); }
sub dont_test_d10 {
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
    my $writer = $write->new( $twiki, $web, $topic, $attachment );
    my $numRevs = @vals;
    for( my $i=0; $i<$numRevs; $i++ ) {
        addRevision( $writer, $attachment, $vals[$i], "comment " . $i, "JohnTalintyre" );
    }
    my $reader = $read->new( $twiki, $web, $topic, $attachment );
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
    my $topic = "CiLocked";

    # create the fixture
    my $rcs = TWiki::Store::RcsWrap->new( $twiki, $web, $topic, "" );
    $rcs->addRevision( "Shooby Dooby", "original", "BungditDin" );
    # hack the lock so someone else has it
    my $user = `whoami`;
    chop($user);
    my $vfile = $rcs->{file}.",v";
    `co -f -q -l $vfile`;

    # file is now locked by blocker_socker, save some new text
    $rcs->_saveFile( $rcs->{file}, "Shimmy Dimmy" );
    # check it in
    $rcs->_ci( "Gotcha", "SheikAlot" );
    my $txt = $rcs->_readFile($vfile);
    $this->assert_matches(qr/Gotcha/s, $txt);
    $this->assert_matches(qr/BungditDin/s, $txt);
    $this->assert_matches(qr/Shimmy Dimmy/, $txt);
    $this->assert_matches(qr/Shooby Dooby/, $txt);
    $this->assert_matches(qr/SheikAlot/s, $txt);
}

1;
