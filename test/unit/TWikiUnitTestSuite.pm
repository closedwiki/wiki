package TWikiUnitTestsSuite;

use base qw(Test::Unit::TestSuite);

sub name { 'TWikiUnitTests' };

# Assume we are run from the "test/unit" directory

sub include_tests {
    opendir(DIR, ".") || die "Failed to open .";
    return grep( /Tests\.pm$/, readdir(DIR));
};

1;
