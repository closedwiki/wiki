# Smoke tests for TWiki::Meta

use strict;

package MetaTests;

use base qw(Test::Unit::TestCase);

BEGIN {
    unshift @INC, '../../lib';
    unshift @INC, '.';
}

use TWiki;
use TWiki::Meta;

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

use vars qw( $m1 %args %args1 %args2 $web $topic $session );

%args = ( "name" => "a",
          "value"  => "1",
          "aa"     => "AA",
          "yy"     => "YY",
          "xx"     => "XX" );
          
%args1 = ( "name" => "a",
           "value" => "2" );
           
%args2 = ( "name" => "b",
           "value" => "3" );
$web= "ZoopyDoopy";
$topic = "NoTopic";
%{$session} = ();

sub set_up
{
    $m1 = TWiki::Meta->new($session, $web, $topic);
    $m1->put( "TOPICINFO", %args );
    $m1->put( "FIELD", %args );
    $m1->put( "FIELD", %args2 );
}

# Field that can only have one copy
sub test_single
{
    my $this = shift;
    my $meta = TWiki::Meta->new($session, $web, $topic);
    
    $meta->put( "TOPICINFO", %args );
    my %vals = $meta->findOne( "TOPICINFO" );
    $this->assert_str_equals( $vals{"name"}, "a" );
    $this->assert_str_equals( $vals{"value"}, "1" );
    $this->assert( $meta->count( "TOPICINFO" ) == 1, "Should be one item" );
    
    $meta->put( "TOPICINFO", %args1 );
    my %vals1 = $meta->findOne( "TOPICINFO" );
    $this->assert_str_equals( $vals1{"name"}, "a" );
    $this->assert_str_equals( $vals1{"value"}, "2" );
    $this->assert( $meta->count( "TOPICINFO" ) == 1, "Should be one item" );
}

sub test_multiple
{
    my $this = shift;
    my $meta = TWiki::Meta->new($session, $web, $topic);
    
    $meta->put( "FIELD", %args );
    my %vals = $meta->findOne( "FIELD", "a" );
    $this->assert_str_equals( $vals{"name"}, "a" );
    $this->assert_str_equals( $vals{"value"}, "1" );
    $this->assert( $meta->count( "FIELD" ) == 1, "Should be one item" );

    $meta->put( "FIELD", %args1 );
    my %vals1 = $meta->findOne( "FIELD", "a" );
    $this->assert_str_equals( $vals1{"name"}, "a" );
    $this->assert_str_equals( $vals1{"value"}, "2" );
    $this->assert( $meta->count( "FIELD" ) == 1, "Should be one item" );
    
    $meta->put( "FIELD", %args2 );
    $this->assert( $meta->count( "FIELD" ) == 2, "Should be two items" );
    my %vals2 = $meta->findOne( "FIELD", "b" );
    $this->assert_str_equals( $vals2{"name"}, "b" );
    $this->assert_str_equals( $vals2{"value"}, "3" );
}

sub test_removeSingle
{
    my $this = shift;
    my $meta = TWiki::Meta->new($session, $web, $topic);
    
    $meta->put( "TOPICINFO", %args );
    $this->assert( $meta->count( "TOPICINFO" ) == 1, "Should be one item" );
    $meta->remove( "TOPICINFO" );
    $this->assert( $meta->count( "TOPICINFO" ) == 0, "Should be no items after remove" );
}

sub test_removeMultiple
{
    my $this = shift;
    my $meta = TWiki::Meta->new($session, $web, $topic);
    
    $meta->put( "FIELD", %args );
    $meta->put( "FIELD", %args2 );
    $meta->put( "TOPICINFO", %args );
    $this->assert( $meta->count( "FIELD" ) == 2, "Should be two items" );
    
    $meta->remove( "FIELD" );
    
    $this->assert( $meta->count( "FIELD" ) == 0, "Should be no FIELD items after remove" );
    $this->assert( $meta->count( "TOPICINFO" ) == 1, "Should be one item" );
    
    $meta->put( "FIELD", %args );
    $meta->put( "FIELD", %args2 );
    $meta->remove( "FIELD", "b" );
    $this->assert( $meta->count( "FIELD" ) == 1, "Should be one FIELD items after partial remove" );
}

1;
