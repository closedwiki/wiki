#! perl -w
use strict;
use diagnostics;

package TWiki::Contrib::DistributionContrib::FileFetcher;
use TWiki::Contrib::DistributionContrib::Config;
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
	my $fileUrl = $serverUrl=. "/" . $distribution . "/" . $file;
	$ans = $saveFilename;
	unless (mirror($fileUrl, $saveFilename)) {
		TWiki::Func::writeWarning("Couldn't get $distribution:$file\n");
		$ans = "Couldn't download";
	}
	return $ans;
}