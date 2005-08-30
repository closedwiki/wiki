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
        next if $i =~ /^TWikiSuite/;
        if( -e "$i/${i}Suite.pm" ) {
           #push( @list, $i.'::'.$i );
        } elsif ( $i =~ s/(Suite).pm$/$1/ ) {
            push( @list, $i );
        }
    }
    closedir(DIR);
    return @list;
};

1;
