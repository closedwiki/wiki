package TestUtil;

use strict;

use Carp;

use vars qw(
   $routine $doTrace $totalCount $okayCount $okay
);


sub trace
{
   my( $message ) = @_;

   if( $doTrace ) {
      print "--- Trace: $message\n";
   }
}

sub check
{
   my( $condition, $message, $extra ) = @_;
   
   if( $extra ) {
      $message .= "; $extra";
   }

   if( ! $condition ) {
      $okay = 0;
      carp "*** $message";
   } else {
      trace( "$message" );
   }
}

sub checkNot
{
   my ($condition, $message ) = @_;

   if( $condition ) {
      $okay = 0;
      carp "*** $condition, $message";
   } else {
      trace("$message");
   }
}

sub check_match
{
   my( $text, $pattern, $extra ) = @_;

   my $match = $text =~ /$pattern/;
   check( $match, "$text match $pattern", $extra );
}

sub check_matchs
{
   my( $text, $pattern, $extra ) = @_;

   my $match = $text =~ /$pattern/s;
   check( $match, "$text should match $pattern (s option)", $extra );
}


sub check_equal
{
   my( $result, $expected, $extra ) = @_;

   check( $result eq $expected, "\"$result\" should be \"$expected\"", $extra );
}


sub enter
{
   my( $theroutine ) = @_;
   
   $routine = $theroutine;
   
   $totalCount++;
   $okay = 1;

   trace( "Entering $routine" );
} 

sub leave
{
   if( $okay ) {
      $okayCount++;
   } else {
      print "=== $routine failed";
   }
   trace( "Leaving $routine" );
}   

sub testSummary
{
   my $failedCount = $totalCount - $okayCount;
   my $summary = "Total tests  = $totalCount\n" .
                 "Okay  tests  = $okayCount\n"  .
                 "Failed tests = $failedCount\n";
   return $summary;
}

1;

