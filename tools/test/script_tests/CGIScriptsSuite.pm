package CGIScriptsSuite;
#
# Test suite for CGI scripts
# Run using 'testrunner.pl CGIScripts'
#
use base qw(Test::Unit::TestSuite);

sub name { 'CGIScripts' };

sub include_tests { qw(oopsScriptTest viewScriptTest editScriptTest previewScriptTest saveScriptTest renameScriptTest attachScriptTest rdiffScriptTest changesScriptTest statisticsScriptTest viewfileScriptTest uploadScriptTest manageScriptTest ) };

1;
