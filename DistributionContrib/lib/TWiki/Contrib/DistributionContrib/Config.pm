#! perl -w
use strict;
package TWiki::Contrib::DistributionContrib::Config;

use vars qw($serverUrl $saveTopic $saveFilename);

my $serverUrl = "http://twikitreleasetracker.mrjc.com";
my $saveTopic = "TWiki.DistributionContrib";
my $saveFilename = "remoteFileSavedLocally";

1;

