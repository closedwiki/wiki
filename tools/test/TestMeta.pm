use lib ( '../../lib' );
use lib ( '.' );
use TWiki;
use TestUtil;

package TestMeta;

use vars qw( $m1 %args %args1 %args2 );

%args = ( "name" => "a",
          "value"  => "1",
          "aa"     => "AA",
          "yy"     => "YY",
          "xx"     => "XX" );
          
%args1 = ( "name" => "a",
           "value" => "2" );
           
%args2 = ( "name" => "b",
           "value" => "3" );
           


# Field that can only have one copy
sub test_single
{
    my $meta = TWiki::Meta->new();
    
    $meta->put( "TOPICINFO", %args );
    my %vals = $meta->findOne( "TOPICINFO" );
    TestUtil::check_equal( $vals{"name"}, "a" );
    TestUtil::check_equal( $vals{"value"}, "1" );
    TestUtil::check( $meta->count( "TOPICINFO" ) == 1, "Should be one item" );
    
    $meta->put( "TOPICINFO", %args1 );
    my %vals1 = $meta->findOne( "TOPICINFO" );
    TestUtil::check_equal( $vals1{"name"}, "a" );
    TestUtil::check_equal( $vals1{"value"}, "2" );
    TestUtil::check( $meta->count( "TOPICINFO" ) == 1, "Should be one item" );
}

sub test_multiple
{
    my $meta = TWiki::Meta->new();
    
    $meta->put( "FIELD", %args );
    my %vals = $meta->findOne( "FIELD", "a" );
    TestUtil::check_equal( $vals{"name"}, "a" );
    TestUtil::check_equal( $vals{"value"}, "1" );
    TestUtil::check( $meta->count( "FIELD" ) == 1, "Should be one item" );

    $meta->put( "FIELD", %args1 );
    my %vals1 = $meta->findOne( "FIELD", "a" );
    TestUtil::check_equal( $vals1{"name"}, "a" );
    TestUtil::check_equal( $vals1{"value"}, "2" );
    TestUtil::check( $meta->count( "FIELD" ) == 1, "Should be one item" );
    
    $meta->put( "FIELD", %args2 );
    TestUtil::check( $meta->count( "FIELD" ) == 2, "Should be two items" );
    my %vals2 = $meta->findOne( "FIELD", "b" );
    TestUtil::check_equal( $vals2{"name"}, "b" );
    TestUtil::check_equal( $vals2{"value"}, "3" );
}

sub test_write
{
    my $text = $m1->writeTypes( "TOPICINFO" );
    TestUtil::check_equal( $text, "%META:TOPICINFO\{name=\"a\" aa=\"AA\" value=\"1\" xx=\"XX\" yy=\"YY\"\}%\n" );
    
    $text = $m1->writeTypes( "FIELD" );
    TestUtil::check_match( $text, '^%META.*name="a".*\n.*META.*name="b" value="3"}', "Two items should match" );
}

sub test_writeStart
{
    my $text = $m1->writeStart();
    TestUtil::check_equal( $text, "%META:TOPICINFO\{name=\"a\" aa=\"AA\" value=\"1\" xx=\"XX\" yy=\"YY\"\}%\n" );
}

sub test_writeEnd
{
    my $text = $m1->writeEnd();
    
    TestUtil::check_match( $text, '^%META.*name="a".*\n.*META.*name="b" value="3"}', "Two items should match" );
}

sub test_readWrite
{
    my $text = "this is some\ntopic text\n";
    
    $text = $m1->write( $text );
    
    TestUtil::check_matchs( $text, 'TOPICINFO.*FIELD.*FIELD' );
    
    my $meta = TWiki::Meta->new();
    
    $meta->read( $text );
        
    TestUtil::check( $meta->count( "FIELD" ) == 2, "Should be two FIELD items" );
    my %vals = $meta->findOne( "FIELD", "b" );
    TestUtil::check_equal( $vals{"name"}, "b" );
    TestUtil::check_equal( $vals{"value"}, "3" );
    
    %vals = $meta->findOne( "TOPICINFO" );
    TestUtil::check_equal( $vals{"name"}, "a" );
    TestUtil::check_equal( $vals{"value"}, "1" );
    TestUtil::check( $meta->count( "TOPICINFO" ) == 1, "Should be one TOPICINFO item" );   
}

sub test_removeSingle
{
    my $meta = TWiki::Meta->new();
    
    $meta->put( "TOPICINFO", %args );
    TestUtil::check( $meta->count( "TOPICINFO" ) == 1, "Should be one item" );
    $meta->remove( "TOPICINFO" );
    TestUtil::check( $meta->count( "TOPICINFO" ) == 0, "Should be no items after remove" );
}

sub test_removeMultiple
{
    my $meta = TWiki::Meta->new();
    
    $meta->put( "FIELD", %args );
    $meta->put( "FIELD", %args2 );
    $meta->put( "TOPICINFO", %args );
    TestUtil::check( $meta->count( "FIELD" ) == 2, "Should be two items" );
    
    $meta->remove( "FIELD" );
    
    TestUtil::check( $meta->count( "FIELD" ) == 0, "Should be no FIELD items after remove" );
    TestUtil::check( $meta->count( "TOPICINFO" ) == 1, "Should be one item" );
    
    $meta->put( "FIELD", %args );
    $meta->put( "FIELD", %args2 );
    $meta->remove( "FIELD", "b" );
    TestUtil::check( $meta->count( "FIELD" ) == 1, "Should be one FIELD items after partial remove" );
}

sub cleanup
{
}

sub setup
{
    $m1 = TWiki::Meta->new();
    $m1->put( "TOPICINFO", %args );
    $m1->put( "FIELD", %args );
    $m1->put( "FIELD", %args2 );
}

sub test
{
   my @tests = qw/single multiple write writeStart writeEnd readWrite removeSingle removeMultiple/;
   foreach my $test ( @tests ) {
      my $fullTest = "TestMeta::test_$test";
      TestUtil::enter( $fullTest );
      &$fullTest;
      TestUtil::leave();
   }
}

#&main();

sub main
{
    my $cleanup = 1;
    $TestUtil::doTrace = 1;
    
    $TestUtil::totalCount = 0;
    $TestUtil::okayCount  = 0;
    
    setup();
    test();
    if( $cleanup ) {
      cleanup();
    }
    
    print TestUtil::testSummary();
}
