#! /usr/bin/perl -w
# Copyright 2004 Sven Dowideit.  All Rights Reserved.
# License: GPL

use strict;
use File::Path qw( rmtree mkpath );

my $outputDir;

#please do all your work in /tmp, and then move the resultant files (and error logs) into the directory specified on the command line
if  ( $#ARGV == 0 ) {
	$outputDir = $ARGV[0]; 
} else {
	print "please provide an outputDir\n";
	exit(1);
}

print "building distros\n";
print "results will be in $outputDir\n";

#removing old build contents to save disk space
( rmtree( $outputDir ) or die "Unable to empty the twiki build directory: $!" ) if -e $outputDir;
mkpath( $outputDir, 1 );

################################################################################
# build the twiki-kernel
execute ( "cd distro ; ./build-twiki-kernel.pl /tmp $outputDir" ) or die $!;

exit 0;

################################################################################
################################################################################

sub execute 
{
    my ($cmd) = @_;
    chomp( my @output = `$cmd` );
    print "$?: $cmd\n", join( "\n", @output );
}
