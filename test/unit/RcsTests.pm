require 5.006;

package RcsTests;

use base qw(TWikiTestCase);
use strict 'vars';
sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

use TWiki;
use TWiki::Store;
use TWiki::Store::RcsLite;
use TWiki::Store::RcsWrap;
use File::Path;

my $testWeb = "TestRcsWebTests";
my $user = "TestUser1";

my $rTopic = "TestTopic";
my $twiki;
my $saveWF;

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();
    die unless (defined $TWiki::cfg{PubUrlPath});
    die unless (defined $TWiki::cfg{ScriptSuffix});
    $twiki = new TWiki();
    $saveWF = $TWiki::cfg{WarningFileName};
    $TWiki::cfg{WarningFileName} = "/tmp/junk";
    die unless $twiki;
    die unless $twiki->{prefs};
    File::Path::mkpath("$TWiki::cfg{DataDir}/$testWeb");
    File::Path::mkpath("$TWiki::cfg{PubDir}/$testWeb");
}

sub tear_down {
    my $this = shift;
    $this->SUPER::tear_down();
    File::Path::rmtree("$TWiki::cfg{DataDir}/$testWeb");
    File::Path::rmtree("$TWiki::cfg{PubDir}/$testWeb");
}

# Tests temp file creation in RcsFile
sub test_mktmp {
    # this is only used on WINDOWS so needs a special test
    my $this = shift;
    my $tmpfile = TWiki::Store::RcsFile::_mkTmpFilename();
    $this->assert(!-e $tmpfile);
}

# Tests reprev, for both Wrap and Lite
sub verifyRepRev {
    my ($this, $class) = @_;
    my $topic = "RcsRepRev";

    my $rcs = $class->new( $twiki, $testWeb, $topic, "" );
    $rcs->addRevisionFromText( "there was a man\n\n", "in once", "JohnTalintyre" );
    $this->assert_equals( "there was a man\n\n", $rcs->getRevision(1) );
    $this->assert_equals( 1, $rcs->numRevisions() );

    $rcs->replaceRevision( "there was a cat\n", "1st replace",
                           "NotJohnTalintyre", time() );
    $this->assert_equals( 1, $rcs->numRevisions() );
    $this->assert_equals( "there was a cat\n", $rcs->getRevision(1) );
    $rcs->addRevisionFromText( "and now this\n\n\n", "2nd entry", "J1" );
    $this->assert_equals( 2, $rcs->numRevisions() );
    $this->assert_equals( "there was a cat\n", $rcs->getRevision(1) );
    $this->assert_equals( "and now this\n\n\n", $rcs->getRevision(2) );

    $rcs->replaceRevision( "then this", "2nd replace", "J2", time() );
    $this->assert_equals( 2, $rcs->numRevisions );
    $this->assert_equals( "there was a cat\n", $rcs->getRevision(1) );
    $this->assert_equals( "then this", $rcs->getRevision(2) );
}

# Tests locking - Wrap only
sub test_RcsWrapOnly_ciLocked {
    my $this = shift;
    my $topic = "CiTestLockedTempDeleteMeItsOk";
    # create the fixture
    my $rcs = TWiki::Store::RcsWrap->new( $twiki, $testWeb, $topic, "" );
    $rcs->addRevisionFromText( "Shooby Dooby", "original", "BungditDin" );
    # hack the lock so someone else has it
    my $user = `whoami`;
    chop($user);
    my $vfile = $rcs->{file}.",v";
    `co -f -q -l $vfile`;
    unlink("$topic.txt");

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

BEGIN {
    my @simpleTests =
      (
       [ "a", "b\n", "c\n" ],
       [ "a", "b", "a\n", "b", "a", "b\n","a\nb\n" ],
       [ "a\n", "b" ],
       [ "" ],
       [ "", "a" ],
       [ "", "a", "a\n", "a\n\n", "a\n\n\n" ],
       [ "", "a", "a\n", "a\nb" ],
       [ "", "a", "a\n", "a\nb", "a\nb\n" ],
       [ "", "\n", "\n\n", "a", "a\n", "a\n\n", "\na","\n\na", "" ],
       [ "a", "b", "a\n", "b", "a", "b\n","a\nb\n", "a\nc\n" ],
       [ "one\n", "1\n2\n", "one\nthree\n4\n", "one\ntwo\nthree\n" ],
       [ "three\nfour\n", "one\ntwo\nthree\n" ],
       [ '@expand@\n', "strict;\n", "head 1.99;\n" ],
       [ '@expand@', "strict;\n", "head 1.99;\n" ],
       [ "a".chr(0xFF), "b".chr(0xFF) ]
      );

    my @diffTests =
      (
       [ "1\n", "2\n" ],
       [ "\n", "1\n" ],
       [ "1\n", "2\n" ],
       [ "2\n", "1\n" ],
       [ "1\n2\n3\n", "a\n1\n2\n3\nb\n" ],
       [ "a\n1\n2\n3\nb\n", "1\n2\n3\n" ],
       [ "1\n2\n3\n", "a\nb\n1\n2\n3\nb\nb\n" ],
       [ "a\nb\n1\n2\n3\nb\nb\n", "1\n2\n3\n" ],
       [ "1\n2\n3\n4\n5\n6\n7\n8\none\nabc\nABC\ntwo\n",
         "A\n1\n2\n3\none\nIII\niii\ntwo\nthree\n"],
       [ "A\n1\n2\n3\none\nIII\niii\ntwo\nthree\n",
         "1\n2\n3\n4\n5\n6\n7\n8\none\nabc\nABC\ntwo\n" ],
       [ "one\ntwo\nthree\nfour\nfive\nsix\n",
         "one\nA\ntwo\nB\nC\nfive\n" ]
      );

    foreach my $impl qw( RcsLite RcsWrap ) {
        my $class = 'TWiki::Store::'.$impl;
        my $fn = 'RcsTests::test_'.$impl;
        my $sfn;
        my $i;

        for $i ( 0..$#simpleTests ) {
            $sfn = $fn.'_getRevision'.$i;
            *$sfn = sub { shift->verifyGetRevision( $class,
                                                    $simpleTests[$i] ) };
        }

        $sfn = $fn.'_getBinaryRevision';
        *$sfn = sub { shift->verifyGetBinaryRevision( $class ) };

        for $i ( 0..$#diffTests ) {
            $sfn = $fn.'_diffs'.$i;
            *$sfn = sub { shift->verifyDifferences( $class,
                                                    $diffTests[$i] ) };
        }

        $sfn = $fn.'_keywords';
        *$sfn = sub { shift->verifyKeywords( $class ) };

        $sfn = $fn.'_repRev';
        *$sfn = sub { shift->verifyRepRev( $class ) };

        $sfn = $fn.'_revAtTime';
        *$sfn = sub { shift->verifyRevAtTime( $class ) };

        $sfn = $fn.'_revInfo';
        *$sfn = sub { shift->verifyRevInfo( $class ) };
    }
}

sub verifyGetRevision {
    my( $this, $class, $revs ) = @_;
    my $topic = "TestRcsTopic";

    my $rcs = $class->new( $twiki, $testWeb, $topic );

    for( my $i = 0; $i < scalar(@$revs); $i++ ) {
        my $text = $revs->[$i];
        $rcs->addRevisionFromText( $text, "rev".($i+1), "UserForRev".($i+1) );
    }

    $rcs = $class->new( $twiki, $testWeb, $topic );

    $this->assert_equals(scalar(@$revs), $rcs->numRevisions());
    for( my $i = 1; $i <= scalar(@$revs); $i++ ) {
        my $text = $rcs->getRevision( $i );
        $this->assert_str_equals( $revs->[$i-1], $text,
                                  "rev ".$i.
                                  ": expected '$revs->[$i-1]', got '$text'");
    }
}

sub verifyGetBinaryRevision {
    my( $this, $class, $revs ) = @_;
    my $topic = "TestRcsTopic";

    my $atttext1 = "\000123\003\n";
    my $atttext2 = "\003test test test\000\n";
    my $attachment = "file.binary";
    my $rcs = $class->new( $twiki, $testWeb, $topic, $attachment );
    $rcs->_saveFile("tmp.tmp", $atttext1) && die;
    my $fh;
    open($fh, "<tmp.tmp");
    $rcs->addRevisionFromStream( $fh, "comment attachment",
                       "UserForRev" );
    close($fh);
    unlink("tmp.tmp");
    $rcs->_saveFile("tmp.tmp", $atttext2) && die;
    open($fh, "<tmp.tmp");
    $rcs->addRevisionFromStream( $fh, "comment attachment",
                                 "UserForRev" );
    close($fh);
    unlink("tmp.tmp");

    $rcs = $class->new( $twiki, $testWeb, $topic, $attachment );

    my $text = $rcs->getRevision( 1 );
    $this->assert_str_equals( $atttext1, $text );
    $text = $rcs->getRevision( 2 );
    $this->assert_str_equals( $atttext2, $text );
}

# ensure RCS keywords are not expanded in the checked-out version
sub verifyKeywords {
    my( $this, $class ) = @_;
    my $topic = "TestRcsTopic";
    my $check = '$Author$ $Date$ $Header$ $Id$ $Locker$ $Log$ $Name$ $RCSfile$ $Revision$ $Source$ $State$';
    my $rcs = $class->new( $twiki, $testWeb, $topic, undef );
    $rcs->addRevisionFromText( $check, "comment", "UserForRev0" );
    open(F,"<$rcs->{file}") || die "Failed to open $rcs->{file}";
    undef $/;
    $this->assert_str_equals($check, <F>);
    close(F);
}

sub verifyDifferences {
    my( $this, $class, $set ) = @_;
    my($from, $to) = @$set;
    my $topic = "RcsDiffTest";
    my $rcs = $class->new( $twiki, $testWeb, $topic, "" );

    $rcs->addRevisionFromText( $from, "num 0", "RcsWrapper" );
    $rcs->addRevisionFromText( $to, "num 1", "RcsWrapper" );

    $rcs = $class->new( $twiki, $testWeb, $topic, "" );

    my $diff = $rcs->revisionDiff( 1, 2 );

    # apply the differences to the text of topic 1
    my $data = TWiki::Store::RcsLite::_split( $from );
    my $l = 0;
    #print "\nStart: ",join('\n',@$data),"\n";
    foreach my $e ( @$diff ) {
        #print STDERR "    $e->[0] $l: ";
        if( $e->[0] eq 'u' ) {
            $l++;
        } elsif( $e->[0] eq 'c' ) {
            $this->assert_str_equals($data->[$l], $e->[1]);
            $data->[$l] = $e->[2];
            $l++;
        } elsif($e->[0] eq '-') {
            $this->assert_str_equals($data->[$l], $e->[1]);
            splice(@$data, $l, 1);
        } elsif($e->[0] eq '+') {
            splice(@$data, $l, 0, $e->[2]);
            $l++;
        } elsif($e->[0] eq 'l') {
            $l = $e->[2] - 1;
        } else {
            $this->assert(0, $e->[0]);
        }
        #for my $i (0..$#$data) {
        #    print STDERR '^' if $i == $l;
        #    print STDERR $data->[$i];
        #    print STDERR '\n' unless($i == $#$data);
        #}
        #print STDERR " -> $l\n";
    }
    $this->assert_str_equals($to, join("\n",@$data));
}

sub verifyRevAtTime {
    my( $this, $class ) = @_;

    my $rcs = $class->new( $twiki, $testWeb, 'AtTime', "" );
    $rcs->addRevisionFromText( "Rev0\n", '', "RcsWrapper", 0 );
    $rcs->addRevisionFromText( "Rev1\n", '', "RcsWrapper", 1000 );
    $rcs->addRevisionFromText( "Rev2\n", '', "RcsWrapper", 2000 );
    $rcs = $class->new( $twiki, $testWeb, 'AtTime', "" );

    my $r = $rcs->getRevisionAtTime(500);
    $this->assert_equals(1, $r);
    $r = $rcs->getRevisionAtTime(1500);
    $this->assert_equals(2, $r);
    $r = $rcs->getRevisionAtTime(2500);
    $this->assert_equals(3, $r);
}

sub verifyRevInfo {
    my( $this, $class ) = @_;

    my $rcs = $class->new( $twiki, $testWeb, 'RevInfo', "" );
    $rcs->addRevisionFromText( "Rev1\n", 'FirstComment', "FirstUser", 0 );
    $rcs->addRevisionFromText( "Rev2\n", 'SecondComment', "SecondUser", 1000 );
    $rcs->addRevisionFromText( "Rev3\n", 'ThirdComment', "ThirdUser", 2000 );

    $rcs = $class->new( $twiki, $testWeb, 'RevInfo', "" );

    my ($rev, $date, $user, $comment) = $rcs->getRevisionInfo(1);
    $this->assert_equals(1, $rev);
    $this->assert_equals(0, $date);
    $this->assert_str_equals('FirstUser', $user);
    $this->assert_str_equals('FirstComment', $comment);

    ($rev, $date, $user, $comment) = $rcs->getRevisionInfo(2);
    $this->assert_equals(2, $rev);
    $this->assert_equals(1000, $date);
    $this->assert_str_equals('SecondUser', $user);
    $this->assert_str_equals('SecondComment', $comment);

    ($rev, $date, $user, $comment) = $rcs->getRevisionInfo(3);
    $this->assert_equals(3, $rev);
    $this->assert_equals(2000, $date);
    $this->assert_str_equals('ThirdUser', $user);
    $this->assert_str_equals('ThirdComment', $comment);

    ($rev, $date, $user, $comment) = $rcs->getRevisionInfo(0);
    $this->assert_equals(3, $rev);
    $this->assert_equals(2000, $date);
    $this->assert_str_equals('ThirdUser', $user);
    $this->assert_str_equals('ThirdComment', $comment);

    ($rev, $date, $user, $comment) = $rcs->getRevisionInfo(4);
    $this->assert_equals(3, $rev);
    $this->assert_equals(2000, $date);
    $this->assert_str_equals('ThirdUser', $user);
    $this->assert_str_equals('ThirdComment', $comment);

    unlink($rcs->{rcsFile});

    $rcs = $class->new( $twiki, $testWeb, 'RevInfo', "" );

    ($rev, $date, $user, $comment) = $rcs->getRevisionInfo(3);
    $this->assert_equals(1, $rev);
    $this->assert_str_equals('guest', $user);
    $this->assert_str_equals('Default revision information', $comment);
}

# not tested:
# deleteRevision
# getRevisionInfo
# any of the RcsFile methods

1;
