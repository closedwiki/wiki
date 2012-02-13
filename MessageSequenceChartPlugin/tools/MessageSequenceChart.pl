#!/usr/bin/perl 
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html

# Helper script for the MessageSequenceChartPlugin. This script is needed for
# catching possible STDERR from mscgen executable. Without this trick STDERR
# is lost (thrown away by TWiki::Sandbox::sysCommand) and plugin cannot display
# meaningful error messages to the user.

use strict;
use warnings;

my $mscGenCmd  = $ARGV[0];    # Command to be executed
my $type       = $ARGV[1];    # Output file type (png, eps, svg or ismap)
my $inFile     = $ARGV[2];    # Input file
my $outFile    = $ARGV[3];    # Output file
my $errFile    = $ARGV[4];    # Error file

if ( $#ARGV != 4 ) {
    die "Usage: MessageSequenceChartPlugin.pl mscgen_executable type infile outfile errfile";
}

my $execCmd = "$mscGenCmd -T $type -i $inFile -o $outFile 2> $errFile ";

my $execError = "";
system("$execCmd");    # Execute the command

if ( $? != 0 ) {
    if ( $? == -1 ) {
        $execError = "$mscGenCmd failed to execute: $!";
    }
    elsif ( $? & 127 ) {
        $execError = sprintf(
            "$mscGenCmd died with signal %d, %s coredump\n",
            ( $? & 127 ),
            ( $? & 128 ) ? 'with' : 'without'
        );
    }
    else {
        $execError = sprintf(
            "$mscGenCmd exited with value %d\n",
            $? >> 8);
    }

    open (my $err, '>>', $errFile)
        or die "Problem executing $mscGenCmd: $execError";
    print $err "Problem executing $mscGenCmd: '$execCmd', got:\n";
    print $err "$execError\n ";
    close $err;

    die "Problem executing $mscGenCmd: $execError";
}
