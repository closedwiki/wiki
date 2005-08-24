# Run _all_ test suites in the current directory (core and plugins)
require 5.006;

package TWikiUnitTestsSuite;

use base qw(Test::Unit::TestSuite);

sub name { 'TWikiSuite' };

# Assume we are run from the "test/unit" directory

sub include_tests {
    opendir(DIR, ".") || die "Failed to open .";
    return grep( !/^TWikiSuite/ && /Suite\.pm$/, sort readdir(DIR));
};

1;
