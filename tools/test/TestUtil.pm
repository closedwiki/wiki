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
   
   my $okay = 1;
   
   if( $extra ) {
      $message .= "; $extra";
   }

   if( ! $condition ) {
      $okay = 0;
      carp "*** $message";
   } else {
      trace( "$message" );
   }
   
   $TestUtil::okay = 0 unless $okay;
   return $okay;
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
   return check( $match, "$text match $pattern", $extra );
}

sub check_matchs
{
   my( $text, $pattern, $extra ) = @_;

   my $match = $text =~ /$pattern/s;
   return check( $match, "$text should match $pattern (s option)", $extra );
}


sub check_equal
{
   my( $result, $expected, $extra ) = @_;

   return check( $result eq $expected, "\"$result\" should be \"$expected\"", $extra );
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
      print "=== $routine failed\n";
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

