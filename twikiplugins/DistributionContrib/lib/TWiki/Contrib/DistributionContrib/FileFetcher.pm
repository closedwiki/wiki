#! perl -w
use strict;
use diagnostics;

package TWiki::Contrib::DistributionContrib::FileFetcher;
use TWiki::Contrib::DistributionContrib::Config qw(%config);
my %config = %TWiki::Contrib::DistributionContrib::Config::config;

use LWP::Simple;

=pod
Fetches a copy of a given file and distribution. 
Saves according to TWiki::Contrib::DistributionContrib::Config;


In:
| $file | name of filename, e.g. bin/view |
| $distribution | name of distribution, e.g. TWiki20020201 |

Out:
| $location | where the local copy of the file has been placed |


=cut

sub fetchDistributionFile {
	my ( $file, $distribution ) = @_;
	$file =~ s!^twiki/!!;
	my $fileUrl = $config{'serverUrl'}. "/" . $distribution . "/" . $file;
	my $webTopicBodge = $config{'saveTopic'};
	$webTopicBodge =~ s!\.!/!;
	my $attachmentPath = TWiki::Func::getPubDir()."/".$webTopicBodge."/".$config{'saveTopicAttachmentName'};
	my $ans = $attachmentPath;
	my $status = mirror($fileUrl, $attachmentPath);
	if (is_error($status)) {
		TWiki::Func::writeWarning("Couldn't get $distribution:$file as $fileUrl to $attachmentPath ($status)\n");
		$ans = "Couldn't download - $status";
	}
	return $ans;
}

1;
