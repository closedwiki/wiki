#
# Test fixture providing functions of the TWiki module
#

$TWiki::wikiPrefsTopicname = "TWikiPreferences";
$TWiki::webPrefsTopicname = "WebPreferences";

#$TWiki::webNameRegex = "[A-Z]+[A-Za-z0-9]*";
#$TWiki::anchorRegex = "\#[A-Za-z0-9_]+";
use strict;

package TWiki;

sub initialize {
  my ( $path, $remuser, $topic, $url, $query ) = @_;
  # initialize $webName and $topicName
  my $webName   = "Main";
  if( $topic && $topic =~ /(.*)\.(.*)/ ) {
	# is "bin/script?topic=Webname.SomeTopic"
	$webName = $1 || "";
	$topic = $2 || "";
  } else {
	$topic = "WebHome";
  }

  return ($topic, $webName, "scripturlpath", "testrunner", $BaseFixture::testData);
}

1;
