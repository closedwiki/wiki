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
   `svn co http://svn.twiki.org/svn/twiki/branches/MAIN > checkouMAIN.log`;
} else {
   `svn up`;
}

chdir('MAIN');
my $twikihome = `pwd`;
chomp($twikihome);

`mkdir working/tmp`;
`chmod 777 working/tmp`;
`chmod 777 lib`;
#TODO: add a trivial and correct LocalSite.cfg
`chmod -R 777 data pub`;


`perl pseudo-install.pl default`;
`perl pseudo-install.pl UnitTestContrib`;

#run unit tests
#TODO: testrunner should exit == 0 if no errors?
chdir('test/unit');
my $unitTests = "export TWIKI_LIBS=; export TWIKI_HOME=$twikihome;perl ../bin/TestRunner.pl -clean TWikiSuite.pm > ../../unittestMAIN.log";
my $return = `$unitTests`;
my $errorcode = $? >> 8;
die "\n\n$errorcode: unit test failures - need to fix them first\n" unless ($errorcode == 0);

#these tests now are run from the unit test suite
#`cd ../..`;
#`perl pseudo-install.pl -link TestFixturePlugin`;


#`perl tools/MemoryCycleTests.pl`;
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

#TODO:    1.  Install default plugins (hard copy)
#          * perl pseudo-install.pl default to install the plugins specified in MANIFEST 
#             2. use the configure script to make your system basically functional
#                       * ensure that your apache has sufficient file and directory permissions for data and pub 
#                          3. cd tools
#                             4. perl build.pl release
#                                       * Note: if you specify a release name the script will attempt to commit to svn 
#





