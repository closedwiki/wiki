#!/usr/bin/perl -w
#
# Build a TWiki Release from the MAIN svn repository - see http://twiki.org/cgi-bin/view/Codev/BuildingARelease
# checkout TWiki MAIN
# run the unit tests
# run other tests
# build a release tarball & upload...
# Sven Dowideit
# Copyright (C) TWikiContributors, 2005

unless ( -e 'MAIN' ) {
   print STDERR "doing a fresh checkout\n";
   `svn co http://svn.twiki.org/svn/twiki/branches/MAIN > TWiki-svn.log`;
   chdir('MAIN');
} else {
#TODO: should really do an svn revert..
   print STDERR "using existing checkout, removing ? files";
   chdir('MAIN');
   `svn status | grep ? | sed 's/?/rm -r/' | sh`;
   `svn up > TWiki-svn.log`;
}

my $twikihome = `pwd`;
chomp($twikihome);

`mkdir working/tmp`;
`chmod 777 working/tmp`;
`chmod 777 lib`;
#TODO: add a trivial and correct LocalSite.cfg
`chmod -R 777 data pub`;

#TODO: replace this code with 'configure' from comandline
my $localsite = getLocalSite($twikihome);
open(LS, ">$twikihome/lib/LocalSite.cfg");
print LS $localsite;
close(LS);


`perl pseudo-install.pl default`;
`perl pseudo-install.pl UnitTestContrib`; # required for all testcases
`perl pseudo-install.pl TestFixturePlugin`; # required for semi-auto testcases to run

#run unit tests
#TODO: testrunner should exit == 0 if no errors?
chdir('test/unit');
my $unitTests = "export TWIKI_LIBS=; export TWIKI_HOME=$twikihome;perl ../bin/TestRunner.pl -clean TWikiSuite.pm 2>&1 > $twikihome/TWiki-UnitTests.log";
my $return = `$unitTests`;
my $errorcode = $? >> 8;
unless ($errorcode == 0) {
    open(UNIT, "$twikihome/TWiki-UnitTests.log");
    local $/ = undef;
    my $unittestErrors = <UNIT>;
    close(UNIT);
    
    chdir($twikihome);
    `scp TWiki* distributedinformation\@distributedinformation.com:/home/distributedinformation/www/TWikiBuilds`;
    sendEmail("Subject: TWiki MAIN branch has Unit test FAILURES\n\n".$unittestErrors);
    die "\n\n$errorcode: unit test failures - need to fix them first\n" 
}

chdir($twikihome);
#TODO: add a performance BM & compare to something golden.
`perl tools/MemoryCycleTests.pl > $twikihome/TWiki-MemoryCycleTests.log`;
`perlcritic lib/ > $twikihome/TWiki-PerlCritic.log`;
`perlcritic bin/ >> $twikihome/TWiki-PerlCritic.log`;
#`cd tools; perl check_manifest.pl`;
#`cd data; grep '%META:TOPICINFO{' */*.txt | grep -v TestCases | grep -v 'author="TWikiContributor".*version="\$Rev'`;

#TODO: #  fix up release notes with new changelogs - see
#
#    * http://develop.twiki.org/~twiki4/cgi-bin/view/Bugs/ReleaseNotesTml?type=patch
#        * Note that the release note is edited by editing the topic data/TWiki/TWikiReleaseNotes04x00. The build script creates a file in the root of the zip called TWikiReleaseNotes04x00? .html, and the build script needs your Twiki to be running to look up the release note topic and show it with the simple text skin.
#            * Note - from 4.1 we need to call this data/TWiki/TWikiReleaseNotes04x01 
#
#

print "\n\n ready to build release\n";

#TODO: clean the setup again
#   1.  Install default plugins (hard copy)
#      * perl pseudo-install.pl default to install the plugins specified in MANIFEST 
#   2. use the configure script to make your system basically functional
#      * ensure that your apache has sufficient file and directory permissions for data and pub 
#   3. cd tools
#   4. perl build.pl release
#      * Note: if you specify a release name the script will attempt to commit to svn 
`perl pseudo-install.pl BuildContrib`;
chdir('lib');
`perl ../tools/build.pl release -auto`;

chdir($twikihome);
#push the files to my server - http://distributedinformation.com/TWikiBuilds/
`scp TWiki* distributedinformation\@distributedinformation.com:/home/distributedinformation/www/TWikiBuilds`;

my $buildOutput = `ls -alh *auto*`;
$buildOutput .= "\n";
$buildOutput .= `grep 'All tests passed' $twikihome/TWiki-UnitTests.log`;
sendEmail("Subject: TWiki MAIN built OK\n\n".$buildOutput);


sub getLocalSite {
   my $twikidir = shift;

#   open(TS, "$twikidir/lib/TWiki.spec");
#   local $/ = undef;
#   my $localsite = <TS>;
#   close(TS);
   my $localsite = `grep 'TWiki::cfg' $twikidir/lib/TWiki.spec`;

   $localsite =~ s|/home/httpd/twiki|$twikidir|g;
   $localsite =~ s|# \$TWiki|\$TWiki|g;

   return $localsite;
}

#Yes, this email setup only works for Sven - will look at re-using the .settings file CC made for BuildContrib
sub sendEmail {
    my $text = shift;
    use Net::SMTP;
    my $twikiDev = 'twiki-dev@lists.sourceforge.net';

    my $smtp = Net::SMTP->new('mail.iinet.net.au', Hello=>'sven.home.org.au', Debug=>0);

    $smtp->mail('SvenDowideit@WikiRing.com');
    $smtp->to($twikiDev);

    $smtp->data();
    $smtp->datasend("To: $twikiDev\n");
    $smtp->datasend($text);
    $smtp->dataend();

    $smtp->quit;
}
1;
