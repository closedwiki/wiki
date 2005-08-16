# Run _all_ test suites in the current directory (core and plugins)
require 5.006;

package TWikiUnitTestsSuite;

use base qw(Test::Unit::TestSuite);

sub name { 'TWikiUnitTests' };

# Assume we are run from the "test/unit" directory

sub include_tests {
    opendir(DIR, ".") || die "Failed to open .";
    return grep( !/^TWikiUnitTestSuite/ && /Suite\.pm$/, sort readdir(DIR));
};

1;
