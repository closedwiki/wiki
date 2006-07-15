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
        if ($i =~ /^(Fn_[A-Z]+).pm$/) {
            push(@list, $1);
        }
        next if $i =~ /^TWikiSuite/;
        if( -e "$i/${i}Suite.pm" ) {
           #push( @list, $i.'::'.$i );
        } elsif ( $i =~ /^(.*Suite).pm$/ ) {
            push( @list, $1 );
        }
    }
    closedir(DIR);
    return @list;
};

1;
