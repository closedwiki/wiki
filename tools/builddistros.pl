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

print "<HTML><TITLE>Building Distros</TITLE><BODY>\n";
print "<H2>building distros</H2>\n";
print "results will be in $outputDir\n";

print "<verbatim>\n";
mkpath( $outputDir, 1 );

################################################################################
# build the twiki-kernel
execute ( "cd distro/ ; ./build-twiki-kernel.pl --tempdir=/tmp --outputdir=$outputDir" ) or die $!;

print "</verbatim>\n";
print "<HR />\n";
print "</BODY></HTML>";
exit 0;

################################################################################
################################################################################

sub execute 
{
    my ($cmd) = @_;
    chomp( my @output = `$cmd` );
    print "$?: $cmd\n", join( "\n", @output );
    return not $?;
}
