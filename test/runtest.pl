#! /usr/bin/perl -w
## Copyright 2004 Sven Dowideit.  All Rights Reserved.
## License: GPL
#please output results and errors to the dir specified on the command line

use strict;

my $outputDir;

if  ( $#ARGV == 0 ) {
	$outputDir = $ARGV[0];
} else {
	print "please provide an outputDir\n";
    exit(1);
 }

print "<HTML><TITLE>Running tests</TITLE><BODY>\n";
print "<H2>running Tests</H2>\n";
print "results will be in $outputDir\n";

print "<HR />\n";
print "<pre>\n";
print `svn update`;
</pre>
print "<HR />\n";
<pre>
chomp( my $now = `date +'%Y%m%d.%H%M%S'` );

execute ( "cd unit ; perl ../bin/TestRunner.pl TWikiUnitTestSuite > $outputDir/unit$now ; cd ..") or die $!;

print "</pre>\n";
print "<HR />\n";
print "</BODY></HTML>";
exit 0;

################################################################################
#################################################################################

sub execute
{
    my ($cmd) = @_;
    chomp( my @output = `$cmd` );
    print "$?: $cmd\n", join( "\n", @output );
    return not $?;
}
