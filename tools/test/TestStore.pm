#!perl

package TestStore;

##use strict;  So can do function calls by reference

use lib ( '../../lib' );
use TWiki;
use TestUtil;
use Carp;

my $trace = 1;

sub test_notopic
{
   my $web = "Test";
   my $topic = "UnitTest1";
   my $rev = TWiki::Store::getRevisionNumberX( "Test", "UnitTest1" ); 
   #FIXME remove LINE and FILE??
   TestUtil::checkNot(TWiki::Store::topicExists($web, $topic), "$topic should not exist", __LINE__, __FILE__);

   # Would be better if there was a different result !!!
   TestUtil::checkNot($rev, "Shouldn't have a revision"); 
}



sub cleanup
{
   setup();
}


sub saveTopic1
{
   my ($web, $topic, $text, $user, $meta ) = @_;

   my $saveCmd = "";
   my $doNotLogChanges = 0;
   my $doUnlock = 1;

   my $thePathInfo = "/$web/$topic";
   my $theTopic = "$topic";
   my $theUrl = "/save.pl/$web/$topic";
   &TWiki::initialize( $thePathInfo, $user, $theTopic, $theUrl );
   my $error = TWiki::Store::saveTopicNew( $web, $topic, $text, $meta, $saveCmd, $doNotLogChanges, $doUnlock );

   TestUtil::checkNot( $error );
}


sub setup
{
   my @meta = ();
   
   # Make sure we have a TestUser1 and TestUser1 topic
   if (! TWiki::Store::topicExists("Main", "TestUser1")) {
      saveTopic1("Main", "TestUser1", "silly user page!!!", "", \@meta );
   }
   if (! TWiki::Store::topicExists("Main", "TestUser2")) {
      saveTopic1("Main", "TestUser2", "silly user page!!!", "", \@meta);
   }
   
      
   # Make sure we don't have a Test.UnitTest1 topic
   my $web = "Test";
   my $topic = "UnitTest1";
   TWiki::Store::erase($web, $topic);
   
   # Make sure we don't have any Test.UnitTest2.afile.txt attachment
   $topic = "UnitTest2";
   TWiki::Store::erase($web, $topic);
   
   $topic = "UnitTest2Moved";
   TWiki::Store::erase($web, $topic);
}


sub test_checkin
{
   my $topic = "UnitTest1";
   my $text = "hi";
   my $web = "Test";
   my $user = "TestUser1";
   my @meta = ();

   saveTopic1( $web, $topic, $text, $user, \@meta );

   my $rev = TWiki::Store::getRevisionNumber( $web, $topic );
   TestUtil::check_equal($rev, "1.1");

   my $text1;
   ( $text1, @meta ) = &TWiki::Store::readWebTopicNew( $web, $topic );
   
   # FIXME ?
   # Temporarily remove \n
   $text1 =~ s/[\s]*$//go;

   TestUtil::check_equal( $text1, $text );
   
   # Check revision number from meta data
   my( $dateMeta, $authorMeta, $revMeta ) = TWiki::Store::getRevisionInfoFromMeta( $web, $topic, \@meta );
   TestUtil::check_equal( $revMeta, "1", "Rev from meta data should be 1 when first creatd" );
   
   # Use same call but don't supply meta data, should go via RCS
   my( $dateMeta0, $authorMeta0, $revMeta0 ) = TWiki::Store::getRevisionInfoFromMeta( $web, $topic, "" );
   TestUtil::check_equal( $revMeta, $revMeta0 );
    

   # Check-in with different text, under different user (to force change)
   $user = "TestUser2";
   $text = "bye";
   saveTopic1($web, $topic, $text, $user, \@meta );
   $rev = TWiki::Store::getRevisionNumber( $web, $topic );
   
   TestUtil::check_equal($rev, "1.2", "After one change topic revision should be 1.2" );
   ($text1, @meta ) = TWiki::Store::readWebTopicNew( $web, $topic );
   ( $dateMeta, $authorMeta, $revMeta ) = TWiki::Store::getRevisionInfoFromMeta( $web, $topic, \@meta );
   TestUtil::check_equal( $revMeta, "2", "Rev from meta should be 2 after one change" );
}

sub test_checkin_attachment
{
   # Create topic
   my $topic = "UnitTest2";
   my $text = "hi";
   my $web = "Test";
   my $user = "TestUser1";
   my @meta = ();

   saveTopic1($web, $topic, $text, $user, \@meta );  
   
   # directly put file in pub directory (where attachments go)
   my $dir = &TWiki::getPubDir();
   $dir = "$dir/$web/$topic";
   if( ! -e "$dir" ) {
      umask( 0 );
      mkdir( $dir, 0777 );
   }

   my $attachment = "afile.txt";
   my $filename = "$dir/$attachment";
   open( FILE, ">$filename" );
   print FILE "Test attachment";
   close(FILE);

   my $text = "";
   my $saveCmd = "";
   my $doNotLogChanges = 0;
   my $doUnlock = 1;
   
   TWiki::Store::save($web, $topic, $text, $saveCmd, $attachment, $doNotLogChanges, $doUnlock);
   
   # Check revision number
   my $rev = TWiki::Store::getRevisionNumber($web, $topic, $attachment);
   TestUtil::check_equal($rev, "1.1");
   
   # Save again and check version number goes up by 1
   open( FILE, ">$filename" );
   print FILE "Test attachment\nAnd a second line";
   close(FILE);
   
   TWiki::Store::save( $web, $topic, $text, $saveCmd, $attachment, $doNotLogChanges, $doUnlock );
   # Check revision number
   $rev = TWiki::Store::getRevisionNumber( $web, $topic, $attachment );
   TestUtil::check_equal($rev, "1.2");
}

# Assumes topic with attachment already exists
sub test_rename()
{
   my $oldWeb = "Test";
   my $oldTopic = "UnitTest2";
   my $newWeb = $oldWeb;
   my $newTopic = "UnitTest2Moved";
   my $attachment = "afile.txt";
   
   my $doNotLogChanges = 0;
   my $doUnlock = 1;
   my $oldRevAtt = TWiki::Store::getRevisionNumber( $oldWeb, $oldTopic, $attachment, $doNotLogChanges, $doUnlock );
   my $oldRevTop = TWiki::Store::getRevisionNumber( $oldWeb, $oldTopic );
   
   TWiki::Store::renameTopic($oldWeb, $oldTopic, $newWeb, $newTopic);
   
   my $newRevAtt = TWiki::Store::getRevisionNumber($newWeb, $newTopic, $attachment );
   my $newRevTop = TWiki::Store::getRevisionNumber( $newWeb, $newTopic );
   
   $oldRevTop =~ /1\.(.*)/;
   my $revTopShouldBe = $1 + 1;
   $revTopShouldBe = "1.$revTopShouldBe";
   
   TestUtil::check_equal($newRevAtt, $oldRevAtt);
   # Topic is modified in move, because meta information is updated to indicate move
   TestUtil::check_equal($newRevTop, $revTopShouldBe, "Topic revision should got up 1 in move" );
}



sub test
{
   my @tests = qw/notopic checkin checkin_attachment rename/;
   foreach $test ( @tests ) {
      my $fullTest = "TestStore::test_$test";
      TestUtil::enter( $fullTest );
      &$fullTest;
      TestUtil::leave();
   }
}

1;


