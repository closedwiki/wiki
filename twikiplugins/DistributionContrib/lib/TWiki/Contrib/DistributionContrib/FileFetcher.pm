#! perl -w
use strict;
use diagnostics;

package TWiki::Contrib::FileFetcher;
use Config;
use LWP;

sub getDistributionFile {
	my ( $file, $distribution ) = @_;
	$file =~ s!^twiki/!!;
	my $file2 = $serverUrl=. "/" . $distribution . "/" . $file;
	return $file2;
}