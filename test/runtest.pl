#! /usr/bin/perl -w
## Copyright 2004 Sven Dowideit.  All Rights Reserved.
## License: GPL
#please output results and errors to the dir specified on the command line

use strict;
use LWP;

my $URL = "http://ntwiki.ethermage.net/~develop/cgi-bin";
#my $URL = "http://localhost/DEVELOP/bin";

my $outputDir;

if  ( $#ARGV == 0 ) {
	$outputDir = $ARGV[0];
} else {
	print "please provide an outputDir\n";
    exit(1);
 }

my $now = `date +'%Y%m%d.%H%M%S'`;
chomp( $now );

print "<HTML><TITLE>Running tests</TITLE><BODY>\n";

print "<h1><code>svn update</code>\n";
print "<pre>\n";
print `svn update`;
print "</pre>\n";

print "<h1>Unit Tests</h1>";
print "Errors will be in $outputDir/unit$now\n<pre>\n";
execute ( "cd unit ; perl ../bin/TestRunner.pl TWikiUnitTestSuite.pm > $outputDir/unit$now ; cd ..") or die $!;
print "</pre>\n";

print "<h1>Automated Test Cases</h1>\n";
my $userAgent = LWP::UserAgent->new();
$userAgent->agent( "ntwiki Test Script " );

opendir( TESTS, "../data/TestCases" ) || die "Can't get testcases: $!";
foreach my $test ( grep { /^TestCaseAuto.*\.txt$/ } readdir TESTS ) {
    $test =~ s/\.txt//;
    my $result = $userAgent->get( "$URL/view/TestCases/$test?test=compare&debugenableplugins=TestFixturePlugin" );

    print "$test ";
    if ( $result->content() =~ /ALL TESTS PASSED/ ) {
        print "<font color='green'>PASSED</font>";
    } else {
        print "<font color='red'><b>FAILED</b></font>";
    }
    print "<br>\n";
}
closedir(TESTS);

print "</BODY></HTML>";

sub execute
{
    my ($cmd) = @_;
    chomp( my @output = `$cmd` );
    print "$?: $cmd\n", join( "\n", @output );
    return not $?;
}


exit 0;
