#!/usr/bin/perl -w
#
# Example build class. Copy this file to the equivalent place in your
# plugin and edit.
#
# Requires the environment variable TWIKI_SHARED to be
# set to point at the shared code repository
# Usage: ./build.pl [-n] [-v] [target]
# where [target] is the optional build target (build, test,
# install, release, uninstall), test is the default.`
# Two command-line options are supported:
# -n Don't actually do anything, just print commands
# -v Be verbose
#
# Read the comments at the top of lib/TWiki/Plugins/Build.pm for
# details of how the build process works, and what files you
# have to provide and where.
#
# Standard preamble
BEGIN {
	warn '$TWIKI_LIBS is not set' unless $ENV{TWIKI_LIBS};
	foreach my $pc ( split( /:/, $ENV{TWIKI_LIBS} ) ) {
		unshift @INC, $pc;
	}
}
use TWiki::Contrib::Build;

use strict;
use diagnostics;
use Digest::MD5;
use FileHandle;
use FileDigest;
use IndexDistributions;
use Common;

use Cwd;
my $runDir = cwd();
IndexDistributions::setRunDir($runDir);

# Declare our build package
package TWikiReleaseTrackerPluginBuild;

@TWikiReleaseTrackerPluginBuild::ISA = ("TWiki::Contrib::Build");

sub new {
	my $class = shift;
	my $this = bless( $class->SUPER::new("TWikiReleaseTrackerPlugin"), $class );
	return $this;
}

# Example: Override the build target
sub target_build {
	my $this = shift;

	$this->SUPER::target_build();

	# Do other build stuff here
}

sub target_install {
	my $this = shift;
	print IndexDistributions::indexLocalEmptyDistribution();
	$this->SUPER::target_install();
}

sub target_indexLocalInstallation {
#FIXME: there needs to be a check in here to ensure that this is only done 
#from an installation
	print IndexDistributions::indexLocalInstallation();
}

sub target_indexReleases {
	print IndexDistributions::indexReleases();
}

sub target_indexBetaReleases {
	print IndexDistributions::indexBetaReleases();
}

sub target_indexPlugins {
	print IndexDistributions::indexPlugins();
}

sub target_test {
	my $this = shift;

	print "Building TRTTestSuite\n";
	chdir( $runDir . "/test" ) || die "$! - can't cd into test dir";
	print `perl testPluginTestSuite.pl`;
	1;
}

sub target_release {
	my $this = shift;
	if ( $Common::installationDir ne "" ) {
		warn "YOU FORGOT TO REMOVE THE DEFAULT INSTALL DIR!\n";
	}
	$this->SUPER::target_release();
}

# Create the build object
my $builder = new TWikiReleaseTrackerPluginBuild();

# Build the target on the command line, or the default target

if (@ARGV) {
	$builder->build( $builder->{target} );    #NB. Buildpm picks up from ARGV
}
else {
	$builder->build("test");
	$builder->build("build");
}


