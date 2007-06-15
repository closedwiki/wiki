package Unit::TestRunner;

use strict;
use Devel::Symdump;
use Error qw(:try);

sub new {
    my $class = shift;
    return bless({}, $class);
}

sub start {
    my $this = shift;
    my @files = @_;
    @{$this->{failures}} = ();

    # First use all the tests to get them compiled
    while (scalar(@files)) {
        my $suite = shift @files;
        $suite =~ s/\.pm$//;
        eval "use $suite";
        if ($@) {
            my $m = "*** Failed to use $suite: $@";
            print $m;
            push(@{$this->{failures}}, $m);
            next;
        }
        print "Running $suite\n";
        my $tester = $suite->new($suite);
        if ($tester->isa('TWikiTestCase')) {
            # Get a list of the test methods in the class
            my @tests = $tester->list_tests($suite);
            unless (scalar(@tests)) {
                print "*** No tests in $suite\n";
                next;
            }
            foreach my $test (@tests) {
                print STDERR "\t$test\n";
                $tester->set_up();
                try {
                    $tester->$test();
                } catch Error::Simple with {
                    my $e = shift;
                    print "*** ",$e->stringify(),"\n";
                    push(@{$this->{failures}}, $test."\n".$e->stringify());
                };
                $tester->tear_down();
            }
        } else {
            # Assume it's a suite
            push(@files, $tester->include_tests());
        }
    }

    if (scalar(@{$this->{failures}})) {
        print scalar(@{$this->{failures}})." failures\n";
        print  join("\n---------------------------\n",
                    @{$this->{failures}}),"\n";
    } else {
        print "All tests passed\n";
    }
}

1;
