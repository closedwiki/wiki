# Run _all_ test suites in the current directory (core and plugins)
require 5.006;

package TWikiUnitTestsSuite;

use base qw(Test::Unit::TestSuite);

sub name { 'TWikiSuite' };

# Assumes we are run from the "test/unit" directory

sub include_tests {
    my $this = shift;
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
    # Add standard extensions tests
    if (-e "$ENV{TWIKI_HOME}/tools/MANIFEST") {
        open(F, "$ENV{TWIKI_HOME}/tools/MANIFEST") || die $!;
    } else {
        open(F, "../../tools/MANIFEST") || die $!;
    }
    local $/ = "\n";
    while (<F>) {
        if (m#^!include (twikiplugins/\w+)/.*?/(\w+)$#) {
            my $d = "../../$1/test/unit/$2";
            next unless (-e "$d/${2}Suite.pm");
            push(@INC, $d);
            print STDERR "Added ${2}Suite\n";
            $this->add_test("${2}Suite");
        }
    }
    close(F);
    return @list;
};

1;
