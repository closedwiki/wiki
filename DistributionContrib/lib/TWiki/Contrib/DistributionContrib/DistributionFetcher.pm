#! perl -w
use strict;
use diagnostics;
use LWP::Simple;

package TWiki::Contrib::DistributionContrib::DistributionFetcher;
my %config = %TWiki::Contrib::DistributionContrib::Config::config;

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

	my $fileUrl = $config{'serverUrl'}. "/" . $distribution;
	my $webTopicBodge = $config{'saveTopic'};
	$webTopicBodge =~ s!\.!/!;
	my $attachmentPath = TWiki::Func::getPubDir()."/".$webTopicBodge."/".$distribution;
	my $ans = $attachmentPath;
	my $status = getstore($fileUrl, $attachmentPath);
	if (is_error($status)) {
		my $error = "Couldn't get $distribution:as $fileUrl to $attachmentPath ($status)";
		TWiki::Func::writeWarning($error."\n");
		$ans = "Couldn't download - $error";
	}
	return $ans;

}
	