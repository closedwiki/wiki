#! /usr/bin/perl -w

use strict;
use FileHandle;
use FileDigest;
use Common;

# TODO: split out the generic from the TWiki-specific parts of this.
package IndexDistributions;

sub indexDistribution {
    use Cwd;
    my $runDir = cwd();

	my ( $distribution, $distributionLocation, $excludeFilePattern,
		$pathPrefix ) = @_;
	use File::Find;
	unless ( defined $pathPrefix ) { $pathPrefix = "" }

	my $preprocessCallback = sub {
		my @ans = grep { !/$excludeFilePattern/ } @_;
		return @ans;
	};

	my $findCallback = sub {
		my $pathname = $File::Find::name;    #  complete pathname to the file.
		Common::debug "$pathname\n";
		my $relativePath =
		  Common::relativeFromPathname( $pathname, $distributionLocation );
		return unless includeInResults($relativePath);
		return unless -f $pathname;
		return if -z $pathname;
		Common::debug "$pathname\n";
		indexFile( $distribution, $distributionLocation, $pathname, $pathPrefix,
			$relativePath );
	};
	find(
		{
			wanted     => $findCallback,
			preprocess => $preprocessCallback,
			follow     => 0
		},
		$distributionLocation
	);
    chdir($runDir);
}

sub indexFile {
	my ( $distribution, $distributionLocation, $file, $pathPrefix,
		$relativePath )
	  = @_;
	my $digest = digestForFile($file);
	Common::debug $relativePath. " = " . $digest . "\n";
	FileDigest::addOccurance( $distribution, $pathPrefix . $relativePath,
		$digest );
}

sub digestForFile {
	my ($file) = @_;
	my $fh = new FileHandle $file, "r";
	unless ( defined $fh ) {
		return "$!";
	}
	unless ( -s $fh ) {
		return "EMPTY";
	}
	use Digest::MD5;
	my $ctx = Digest::MD5->new;
	$ctx->addfile($fh);
	return $ctx->hexdigest();
}

#---------------------------------------------------
# TWiki-specifics
#---------------------------------------------------
my $runDir;

sub includeInResults {
	my ($relativePath) = @_;

	#CodeSmell: should be able to do this in preprocessCallback
	if (   ( $relativePath =~ m!data/(.*)/! )
		or ( $relativePath =~ m!pub/(.*)/! ) )
	{
		my $web = $1;

		#	    print "Index web '$web'?" ;
		if ( $web =~ m/$Common::websToIndex/ ) {
			return 1;
			#		print "yes\n";
		}
		else {
			return 0;
			#		print "no\n";
		}
	}
	return 1;
}

sub indexLocalInstallation {
	ensureInstallationDir();
	FileDigest::emptyIndexes();
	print "Indexing localInstallation\n";
	IndexDistributions::indexDistribution( "localInstallation",
		$Common::installationDir, $Common::excludeFilePattern );
	my $saveFile = $Common::md5IndexDir . "/localInstallation.md5" ;
	print "saving to ".File::Spec->rel2abs($saveFile)."\n";
	FileDigest::saveIndex($saveFile);

#	print FileDigest::dataOutline();
}

sub indexReleases {
#	die "feature broken";
	indexDistributions("(?!beta)");
	FileDigest::saveIndex( $Common::md5IndexDir . "/releases.md5" );
}

sub indexBetaReleases {
	indexDistributions("beta");
	FileDigest::saveIndex( $Common::md5IndexDir . "/betas.md5" );
}

sub indexPlugins {
	FileDigest::emptyIndexes();
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
	print "$Common::installationDir\n";
}

sub setRunDir {
	($runDir) = @_;
}

sub indexDistributions {
    # This depends on a modified version of Crawfords' SharedCode
	my ($filterIn) = @_;

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

1;
