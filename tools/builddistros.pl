#! /usr/bin/perl -w
# Copyright 2004 Sven Dowideit.  All Rights Reserved.
# License: GPL

use strict;

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
