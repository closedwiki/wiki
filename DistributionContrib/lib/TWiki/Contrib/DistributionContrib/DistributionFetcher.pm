#! perl -w
use strict;
use diagnostics;

package TWiki::Contrib::DistributionContrib::DistributionFetcher;
use TWiki::Contrib::DistributionContrib::Config qw(%config);
my %config = %TWiki::Contrib::DistributionContrib::Config::config;

use TWiki;
use TWiki::Func;
use LWP::Simple;

=pod
---++ sub fetchLatestDistributionVersion 

 * Get the latest version of a given distribution name. Saves according to TWiki::Contrib::DistributionContrib::Config;
 
 * e.g. fetchLatestDistributionVersion("KoalaSkin")
 * e.g. fetchLatestDistributionVersion("TWiki20030201")

In:
| $distribution | name of distribution, e.g. TWiki20020201 |

Out:
| $location | where the local copy of the file has been placed |

It will have the same name as it did on the remote server.
 
 Note that plugins are not uniquely defined by name whereas TWiki distributions are.

=cut


sub fetchLatestDistributionVersion {
   my ($distribution) = @_;

	my $fileUrlBase = $config{'serverUrl'}. "/" . $distribution;

	my $pubDir = TWiki::Func::getPubDir();
	my $webTopicBodge = $config{'saveTopic'};
	$webTopicBodge =~ s!\.!/!;
	my $attachmentDir = $pubDir."/".$webTopicBodge;
	
	my $distributionFile = $distribution.'.zip';
	
	my $attachmentPath = $attachmentDir.'/'.$distributionFile;
	my $fileUrl = $fileUrlBase.'/'.$distributionFile;
	my $ans = $attachmentPath;
	my $status = getstore($fileUrl, $attachmentPath);
	if (is_error($status)) {
		my $error = "Couldn't get $distribution as $fileUrl to $attachmentPath ($status)";
#		TWiki::Func::writeWarning($error."\n");
		$ans = "Couldn't download - $error";
	}
	return $ans;

}

1;