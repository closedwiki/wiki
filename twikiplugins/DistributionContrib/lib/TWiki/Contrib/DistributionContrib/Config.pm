#! perl -w
use strict;
package TWiki::Contrib::DistributionContrib::Config;
require Exporter;
our @ISA = qw(Exporter);

our @EXPORT=qw(%config);

%TWiki::Contrib::DistributionContrib::Config::config = (
 serverUrl => "http://twikitreleasetracker.mrjc.com",
 saveTopic => "TWiki.DistributionContrib",
 saveTopicAttachmentName => "remoteFileSavedLocally"
);

1;

