#!/usr/bin/perl

# Support script for sandbox security mechanism for DirectedGraphPlugin
# Sets the proper working dir and calls dot

use strict;

my $debug = 0;

if ($debug) {
    open( DEBUGFILE, ">>/tmp/DirectedGraphPlugin.pl.log" );
    print DEBUGFILE "\n----\nCalling dot; got parameters:\n";
    print DEBUGFILE join( "\n", @ARGV ) . "\n";
    close DEBUGFILE;
}

if ( $#ARGV != 4 ) {
    open( DEBUGFILE, ">>/tmp/DirectedGraphPlugin.pl.log" );
    print DEBUGFILE "Received $#ARGV parameters \n";
    print DEBUGFILE "Usage: DirectedGraphPlugin.pl dot_executable working_dir infile iostring errfile\n";
    close DEBUGFILE;
    die "Usage: DirectedGraphPlugin.pl dot_executable working_dir infile iostring errfile\n";
}

open( ERRFILE, "$ARGV[4]" );
print ERRFILE "";
close ERRFILE;

unless ( chdir "$ARGV[1]" ) {
    open( ERRFILE, ">>$ARGV[4]" );
    print ERRFILE "Couldn't change working dir to $ARGV[1]: $!\n";
    close ERRFILE;
    die "Couldn't change working dir to $ARGV[1]: $!\n";
}

# GV_FILE_PATH need to be set for dot to load custom icons (shapefiles)
my $execCmd = "GV_FILE_PATH=\"$ARGV[1]/\" $ARGV[0] $ARGV[2] $ARGV[3] 2> $ARGV[4] ";

if ($debug) {
    open( DEBUGFILE, ">>/tmp/DirectedGraphPlugin.pl.log" );
    print DEBUGFILE "Built command line: " . $execCmd . "\n";
    close DEBUGFILE;
}

print `$execCmd`;
if ($?) {
    print "Problem executing dot command";
    if ($debug) {
       open( DEBUGFILE, ">>/tmp/DirectedGraphPlugin.pl.log" );
       print DEBUGFILE "Problem executing dot command: '$execCmd', got:\n$!";
       close DEBUGFILE;
    }
    die "Problem executing dot command: '$execCmd', got:\n$!";
}
