#! /usr/bin/perl -w

use strict;
use diagnostics;
use Digest::MD5;
use FileHandle;
use FileDigest;
use IndexDistributions;
use Common;

package main;
#
# Plugins and releases are expected to be in the same $Common::downloadDir directory - this script will
# put into an index according to its download name.

my $excludeFilePattern = 'DEADJOE|.svn|\~$|\,v|.changes|.mailnotify|.session';

sub indexLocalInstallation {
    FileDigest::emptyIndexes();
      print "Indexing localInstallation\n"; 
      IndexDistributions::indexDistribution("localInstallation",
					    $Common::installationDir,
					    $excludeFilePattern);

      FileDigest::saveIndex($Common::md5IndexDir."/localInstallation.md5");

}


# These routines depend on a modified version of Crawfords' SharedCode 
sub indexReleases {
    FileDigest::emptyIndexes();

    my @releases = getDirsListed($Common::downloadDir);
#      e.g. qw(TWiki19990901 TWiki20030201); 

    foreach my $release (@releases) {
	next unless ($module ~= m/^TWiki/);
	next if ($release =~ m/beta/);
	print "Indexing $release\n"; 
	IndexDistributions::indexDistribution($release,
					$dir."/".$release,
					$excludeFilePattern,
					"twiki");
    }
      FileDigest::saveIndex($Common::md5IndexDir."/releases.md5");

  }

sub indexPlugins {
    FileDigest::emptyIndexes();

    my @modules = getDirsListed($Common::downloadDir);

    foreach my $module (@modules) {
	next if ($module ~= m/^TWiki/);
	print "$module\n"; 
	IndexDistributions::indexDistribution("TWiki:Plugins.".$module,
					$dir."/".$module,
					$excludeFilePattern,
					"twiki");
    }
    FileDigest::saveIndex($Common::md5IndexDir."/plugins.md5");
}

indexLocalInstallation();
#indexPlugins();
#indexReleases();

#FileDigest::printIndexes();
#FileDigest::dumpIndex();


sub getDirsListed {
    my ($dir) = @_;

    use DirHandle;
    my $dh = DirHandle->new($dir) || die "$! - $dir";
    return sort
#	   grep { -d }
           grep { !/\./ }
           $dh -> read();
}


sub installsOfMine {
    IndexDistributions::indexDistribution("athens", 
			$ENV{HOME}."/athenstwiki.mrjc.com/", 
			$excludeFilePattern);
      IndexDistributions::indexDistribution("beijing", 
			  $ENV{HOME}."/beijingtwiki.mrjc.com/", 
			  $excludeFilePattern);
      IndexDistributions::indexDistribution("cairo", 
			  $ENV{HOME}."/cairotwiki.mrjc.com/",
			  $excludeFilePattern);
}
