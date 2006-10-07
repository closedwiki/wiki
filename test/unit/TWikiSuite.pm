# Run _all_ test suites in the current directory (core and plugins)
require 5.006;

package TWikiUnitTestsSuite;

use base qw(Test::Unit::TestSuite);

sub name { 'TWikiSuite' };

# Assume we are run from the "test/unit" directory

sub include_tests {
    push(@INC, '.');
    my @list;
    opendir(DIR, ".") || die "Failed to open .";
    foreach my $i (sort readdir(DIR)) {
        next if $i =~ /^EmptyTests/;
        if ($i =~ /^Fn_[A-Z]+\.pm$/ ||
              $i =~ /^.*Tests\.pm$/) {
            push(@list, $i);
        }
    }
    closedir(DIR);
    return @list;
};

1;
