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

print "<HTML><TITLE>Building Kernels</TITLE><BODY>\n";
print "<H2>building kernels</H2>\n";
print "results will be in $outputDir\n";

print "<verbatim>\n";
mkpath( $outputDir, 1 );

################################################################################
# build the twiki-kernel
my ( $svnRev ) = ( ( grep { /^Revision:\s+(\d+)$/ } `svn info .` )[0] ) =~ /(\d+)$/;
execute ( "cd distro/ ; ./build-twiki-kernel.pl --nozip --tempdir=/tmp --outputdir=$outputDir --outfile=TWikiKernel-`head -n 1 branch`-$svnRev" ) or die $!;

print "</verbatim>\n";
print "<HR />\n";

################################################################################
# kernels filenames download/discussion list
my @dirReleases = ();
if ( opendir( RELEASES, $outputDir ) )
{
    @dirReleases = grep { /^TWiki.+\.tar\.gz/ } readdir( RELEASES );  #or warn $!;
    closedir( RELEASES ) or warn $!;
}
foreach my $kernel ( reverse sort @dirReleases )
{
    ( my $rel = $kernel ) =~ s/\.tar\.gz$//;
    my ( $label, undef, $branch, $revInfo ) = $rel =~ m/TWiki(Kernel)?(-([^-]+)-)?(.+)?/;
    $branch ||= '';
    warn "Skipping $kernel\n" unless $revInfo;
    # CODE_SMELL: hardcoded to twiki.org (would need some sort of super project configuration file)
    my $homepage = "http://twiki.org/cgi-bin/view/Codev/TWikiKernel$branch$revInfo";
    # CODE_SMELL: hardcoded to ntwiki (can be fixed using hostname and ...?)
    my $download = "http://ntwiki.ethermage.net/users/develop/pub/BuildDistros/$kernel";
    print qq{<b>$rel</b> };
    print qq{<a href="$download" >download</a>\n};
    print qq{<a href="$homepage" >discussion</a>\n};
    print qq{<br />\n\n};  
} 

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
