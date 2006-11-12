use strict;

package WebTestCasesAutoTests;

use base qw(TWikiTestCase);

use strict;

use TWiki::Contrib::CliRunnerContrib;

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

# Set up the test fixture
sub set_up {
    my $this = shift;

    $this->SUPER::set_up();
}

sub tear_down {
    my $this = shift;
    $this->SUPER::tear_down();
}


# ----------------------------------------------------------------------
# This is a bit hackish: For better reading of the results, create a
# separate test_TestCaseAutoFoo sub for each of the Auto topics.  We
# could do that in one single test case, but it would be messy to find
# out *which* of the testcases have problems.  And we could only find
# errors one at a time, because unit test cases are aborted after the
# first failure.
BEGIN {
    # The configuration is available from our TWikiTestCase heritage
    my $dataDir  =  $TWiki::cfg{DataDir};
    opendir TCWEB,"$dataDir/TestCases"
        or  die "Can not run this test case without a TestCases web";
    my @autoTestCases  =  map {s/\.txt$//; $_}
                          grep {/^TestCaseAuto.*\.txt$/}
                          readdir TCWEB;
    closedir TCWEB;

    for my $autoTestCase (@autoTestCases) {
        my $subText = <<EOT;
sub test_${autoTestCase} {
    my \$this = shift;
    _testAutoTestCase(\$this,'$autoTestCase');
}
EOT

        eval $subText;
    }
}


sub _testAutoTestCase {
    my $this = shift;
    my ($topic)  =  @_;
    my $runner  =  TWiki::Contrib::CliRunnerContrib->new();
    $runner->twikiCfg([qw(Plugins TestFixturePlugin Enabled)],1);
    $runner->addScriptOptions(test => 'compare', user=>'TWikiGuest');
    $runner->topic("TestCases.$topic");
    my $result  =  $runner->run();
    $this->assert_matches(qr/ALL TESTS PASSED/,$result);

    # As a next step one could avoid to assert the binary ALL TESTS
    # PASSED result, and assert the individual expected/actual
    # sections instead.  In that case one would omit activating the
    # TestFixturePlugin and the script option 'test=compare'.
}

1;
