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
	print $ENV{TWIKI_LIBS};
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
	$this->SUPER::target_build();
	target_indexLocalInstallation();

}

sub target_indexLocalInstallation {
	ensureInstallationDir();
	indexLocalInstallation();
	chdir($runDir) || die "Can't cd into $runDir - $!";
	my $saveFile = $Common::md5IndexDir . "/localInstallation.md5" ;
	print "saving to $saveFile";
	FileDigest::saveIndex($saveFile);

	#    print FileDigest::dataOutline();
}

sub target_indexReleases {
	die "feature broken";
	indexReleases("(?!beta)");
	chdir($runDir) || die "Can't cd into $runDir - $!";
	FileDigest::saveIndex( $Common::md5IndexDir . "/releases.md5" );
}

sub target_indexBetaReleases {
	indexReleases("beta");
	chdir($runDir) || die "Can't cd into $runDir - $!";
	FileDigest::saveIndex( $Common::md5IndexDir . "/betas.md5" );
}

sub target_test {
	my $this = shift;
	ensureInstallationDir();

	print "Building TRTTestSuite\n";
	chdir( $runDir . "/test" ) || die "$! - can't cd into test dir";
	print `perl testPluginTestSuite.pl`;
	1;
}

sub target_release {
	my $this = shift;
	if ( $Common::installationDir ne "" ) {
		die "YOU FORGOT TO REMOVE THE DEFAULT INSTALL DIR!\n";
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

sub indexLocalInstallation {
	FileDigest::emptyIndexes();
	print "Indexing localInstallation\n";
	IndexDistributions::indexDistribution( "localInstallation",
		$Common::installationDir, $Common::excludeFilePattern );

}

# These routines depend on a modified version of Crawfords' SharedCode
sub target_indexReleasesOld {
	my ($filterIn) = @_;

	chdir($runDir) || die "Can't cd into $runDir - $!";
	FileDigest::emptyIndexes();
	my $dir = $Common::downloadDir;

	my @releases = getDirsListed($Common::downloadDir);

	foreach my $release (@releases) {
		next unless ( $release =~ m/^TWiki/ );
		next unless ( $release =~ m/$filterIn/ );
		print "Indexing $release\n";
		IndexDistributions::indexDistribution( $release, $dir . $release,
			$Common::excludeFilePattern, "twiki" );
	}

}

sub target_indexPlugins {
	FileDigest::emptyIndexes();
	chdir($runDir) || die "Can't cd into $runDir - $!";
	my $dir = $Common::downloadDir;

	my @modules = getDirsListed($dir);

	foreach my $module (@modules) {
		next if ( $module =~ m/^TWiki/ );
		print "$module\n";
		IndexDistributions::indexDistribution( $module, $dir . "/" . $module,
			$Common::excludeFilePattern, "twiki" );
	}
	FileDigest::saveIndex( $Common::md5IndexDir . "/plugins.md5" );
}

sub getDirsListed {
	my ($dir) = @_;

	use DirHandle;
	my $dh = DirHandle->new($dir) || die "$! - $dir";
	return sort

	  #	   grep { -d }
	  grep { !/\./ } $dh->read();
}

sub installsOfMine {
	IndexDistributions::indexDistribution( "athens",
		$ENV{HOME} . "/athenstwiki.mrjc.com/",
		$Common::excludeFilePattern );
	IndexDistributions::indexDistribution( "beijing",
		$ENV{HOME} . "/beijingtwiki.mrjc.com/",
		$Common::excludeFilePattern );
	IndexDistributions::indexDistribution( "cairo",
		$ENV{HOME} . "/cairotwiki.mrjc.com/",
		$Common::excludeFilePattern );
}

sub ensureInstallationDir {
	use TRTConfig;
	if ( $Common::installationDir eq "" ) {
		die "You must edit TRTConfig to tell it where you've installed TWiki";
	}
}
