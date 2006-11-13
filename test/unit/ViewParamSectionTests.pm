use strict;

package ViewParamSectionTests;

use base qw(TWikiTestCase);

use strict;

use TWiki::Contrib::CliRunnerContrib;

my $runner; # will be passed from set_up to the tests

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

# Set up the test fixture
sub set_up {
    my $this = shift;

    $this->SUPER::set_up();
    $runner  =  TWiki::Contrib::CliRunnerContrib->new;
    $runner->addScriptOptions(skin => 'text', user => 'TWikiGuest');
    $runner->twikiCfg(LogFileName => '/dev/null');
    $runner->topic('TestCases.IncludeFixtures');
}

sub tear_down {
    my $this = shift;
    $this->SUPER::tear_down();
}

# ----------------------------------------------------------------------
# General:  All tests assume that formatting parameters (especially
#           skin) are applied correctly after the section has been 
#           extracted from the topic
# General:  Log file entries are discarded.


# ----------------------------------------------------------------------
# Purpose:  Test a simple section
# Verifies: with parameter section=first returns text of first section
sub test_sectionFirst {
    my $this = shift;
    $runner->addScriptOptions(section => 'first');
    my $result  =  $runner->run;
    $this->assert_matches(qr(^\s?This is the first section\s?$)s,$result);
}

# ----------------------------------------------------------------------
# Purpose:  Test a nesting section
# Verifies: with parameter section=outer returns all text parts from
#           outer and inner
sub test_sectionOuter {
    my $this = shift;
    $runner->addScriptOptions(section => 'outer');
    my $result  =  $runner->run;
    $this->assert_matches(qr(^\s?This is the start of the outer section)s,$result);
    $this->assert_matches(qr(This is the whole content of the inner section)s,$result);
    $this->assert_matches(qr(This is the end of the outer section\s?$)s,$result);
}

# ----------------------------------------------------------------------
# Purpose:  Test a nested section
# Verifies: with parameter section=inner returns only the inner part
sub test_sectionInner {
    my $this = shift;
    $runner->addScriptOptions(section => 'inner');
    my $result  =  $runner->run;
    $this->assert_matches(qr(^\s?This is the whole content of the inner section\s?$)s,$result);
}

# ----------------------------------------------------------------------
# Purpose:  Test a non-existing section
# Verifies: with parameter section=notExisting returns the whole topic
sub test_sectionNotExisting {
    my $this = shift;
    $runner->addScriptOptions(section => 'notExisting');
    my $result  =  $runner->run;
    $this->assert_matches(qr(^\s?This is outside any section)s,$result);
    $this->assert_matches(qr(This is the start of the outer section)s,$result);
    $this->assert_matches(qr(This is the whole content of the inner section)s,$result);
    $this->assert_matches(qr(This is the end of the outer section)s,$result);
    $this->assert_matches(qr(This is after firstoverlap\s?$)s,$result);
}

1;
