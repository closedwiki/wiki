package TWikiReleaseNames;
use strict;
use diagnostics;

=pod 
'01 Feb 2003' => "TWiki20030201"

=cut
sub wikiVersionToDistributionName {
    my ($wikiVersion) =@_;
    my %months = (Jan => "01",
		    Feb => "02",
		    Mar => "03",
		    Apr => "04",
		    May => "05",
		    Jun => "06",
		    Jul => "07",
		    Aug => "08",
		    Sep => "09",
		    Oct => "10",
		    Nov => "11",
		    Dec => "12");

    if ($wikiVersion =~ m/([0-9][0-9]) (.*) ([0-9].*)/) { #CodeSmell lazy regex
	my ($day, $month, $year) = ($1, $2, $3);
	my $monthNumber = $months{$month};
	my $ans = "TWiki".$year.$monthNumber.$day;
#	print $ans;
	return $ans;
    }
    return "ERROR - couldn't parse $wikiVersion";

}


=pod 
TWikiBetaRelease2004x07x30 => TWiki20040730beta
TWikiRelease20030201 => TWiki20030201

=cut 

sub releaseTopicToDistributionName {
    my ($releaseTopic) = @_;
    my $date;
    my $type;
    if ($releaseTopic =~ m/TWikiBetaRelease(.*)/){
	$date = $1;
	$date =~ s/x//g;
	$type = "beta";
    } elsif ($releaseTopic =~ m/TWikiRelease(.*)/) {
	$date = $1;
	$type = "";
    }
    return "TWiki".$date.$type;
}

sub test {
    use Test::Unit::TestRunner;

    my $testrunner = Test::Unit::TestRunner->new();
    $testrunner->start('TWikiReleaseNamesTester');    
}

#test();

package TWikiReleaseNamesTester;
use base qw(Test::Unit::TestCase);

sub new {
    my $self = shift()->SUPER::new(@_);
    # your state for fixture here
    return $self;
}

sub set_up {
    # provide fixture
}
sub tear_down {
    # clean up after test
}

sub test_works {
    my $self = shift;
    $self->assert_equals("TWiki20040730beta", TWikiReleaseNames::releaseTopicToDistributionName("TWikiBetaRelease2004x07x30"));
}

sub test_works2 {
    my $self = shift;
    $self->assert_equals("TWiki20030201", TWikiReleaseNames::releaseTopicToDistributionName("TWikiRelease20030201"));
}

sub test_wikiVersionToDistributionName {
    my $self = shift;
    $self->assert_equals("TWiki20030201", TWikiReleaseNames::wikiVersionToDistributionName("01 Feb 2003"));
}

sub test_thisFaultsTestUnit {
    my $self = shift;
    $self->assert_equals("1", "2");
}

# Test::Unit segfaults on failure for me, but this at least keeps the interface working
sub assert_equals {
    my ($self, $compare, $with) = @_;
    if ($compare eq $with) {
	print "ok ($compare == $with)\n";
	return 1;
    } else {
	print "failed ($compare == $with) \n";
	return -1;
    }
}
1;
