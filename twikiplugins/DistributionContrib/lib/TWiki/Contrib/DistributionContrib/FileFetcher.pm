#! perl -w
use strict;
use diagnostics;

package TWiki::Contrib::FileFetcher;

use LWP;

sub getDistributionFile {
	my ( $file, $distribution ) = @_;
	$file =~ s!^twiki/!!;
	my $file2 = $Common::downloadDir . "/" . $distribution . "/" . $file;
	return $file2;
}