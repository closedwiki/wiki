#!/usr/bin/perl -w

package TestHarness;

use Exporter 'import';
BEGIN{ @EXPORT_OK = qw(harness unharness); }

use strict;

my %harnessed;

use vars qw(
    $ERR_REHARNESS $ERR_NOTHARNESSED $ERR_HARNESSFAIL $ERR_UNHARNESSFAIL
);

*ERR_REHARNESS     = \1;
*ERR_NOTHARNESSED  = \2;
*ERR_HARNESSFAIL   = \3;
*ERR_UNHARNESSFAIL = \4;

sub normalizeSubName {
    my ($subName, $callingPackage) = @_;
    if ($subName =~ /^(.*)::/) {
	return ($subName, $1);
    } else {
	return ("${callingPackage}::${subName}", $callingPackage);
    }
}

sub harness
{
    my ($subName, $newFunc, $needOld) = @_;

    my $package;
    ($subName, $package) = normalizeSubName($subName, caller);

    if (exists $harnessed{$subName}) {
	warn "Attempt to reharness $subName";
	return $ERR_REHARNESS;
    }
    
    {   no strict 'refs';
        $harnessed{$subName} = \&{$subName};
    }
    my $oldFunc = $harnessed{$subName};
    
    my $harnessFunc;
    if ($needOld) {
	# create a closure to provide access to the real function
	$harnessFunc = sub {unshift @_, $oldFunc; goto &$newFunc; };
    } else {
	$harnessFunc = $newFunc;
    }

    eval "no warnings; *$subName = \$harnessFunc;"; # harnessFunc _not_ interpolated!
    if ($@) {
	warn "Could not harness function $subName: $@\n";
	delete $harnessed{$subName};
	return $ERR_HARNESSFAIL;
    }

    return $oldFunc;
}

sub unharness
{
    my ($subName) = @_;
    
    my $package;
    ($subName, $package) = normalizeSubName($subName, caller);
    
    if (exists $harnessed{$subName}) {
	eval "no warnings; *$subName = \$harnessed{\$subName};";
	if ($@) {
	    warn "Could not unharness function $subName: $@\n";
	    return $ERR_UNHARNESSFAIL;
	}
	delete $harnessed{$subName};
    } else {
	warn "Attempt to unharness unknown function $subName";
	return $ERR_NOTHARNESSED;
    }
    return 0;
}

package TestHarness::Test;

use TestUtil;
BEGIN {TestHarness->import('harness', 'unharness');}

sub a {return [ "a", @_ ];}
sub b {return [ "b", @_ ];}

sub test_harness_ok {
    my $realA = \&a; my $testRealA = harness('a', \&b);
    my $realB = \&b; my $testRealB = harness('b', $realA);

    TestUtil::check_equal( $realA, $testRealA );
    TestUtil::check_equal( $realB, $testRealB );
    
    TestUtil::check_equal( $realB, \&a );
    TestUtil::check_equal( $realA, \&b );

    unharness('a');
    TestUtil::check_equal( $realA, \&a );

    unharness('b');
    TestUtil::check_equal( $realB, \&b );
}

sub to1 { return $_[0]; }
sub to2 { return $_[0]; }

sub test_harness_withorig {
    my $real1 = \&to1;
    my $old1 = harness('to1', \&to2, 1);
    
    TestUtil::check_equal( $old1, $real1 );
    TestUtil::check_equal( to1(), $real1 );
    TestUtil::check_equal( to2(42), 42);

    unharness('to1');

    TestUtil::check_equal($real1, \&to1);
    TestUtil::check_equal(to1(42), 42);
}

sub test_harness_failure {
    local $SIG{__WARN__} = sub {return;};
    
    my $realA = \&a;
    my $fortytwo = sub {return 42;};
    my $oldA = harness('a', $fortytwo);

    TestUtil::check_equal($realA, $oldA);
    TestUtil::check_equal($fortytwo, \&a);
    TestUtil::check_equal(a(), 42);

    my $five = sub {return 5;};
    my $err = harness('a', $five);
    
    TestUtil::check_equal($err, $TestHarness::ERR_REHARNESS);
    TestUtil::check_equal(\&a, $fortytwo);
    TestUtil::check_equal(a(), 42);

    unharness('a');
    TestUtil::check_equal($realA, \&a);
    
    $err = unharness('a');
    TestUtil::check_equal($err, $TestHarness::ERR_NOTHARNESSED);

    $err = unharness('frob');
    TestUtil::check_equal($err, $TestHarness::ERR_NOTHARNESSED);
    
    #foo*bar can be a sub in a symbol table, but we won't allow it
    $err = harness('foo*bar', $fortytwo);
    TestUtil::check_equal($err, $TestHarness::ERR_HARNESSFAIL);

    # HACK: takes advantage of file-wide lexical scoping
    $harnessed{'TestHarness::Test::foo*bar'} = $five;
    $err = unharness('foo*bar');
    TestUtil::check_equal($err, $TestHarness::ERR_UNHARNESSFAIL);
    TestUtil::check_equal($harnessed{'TestHarness::Test::foo*bar'}, $five);
    no strict 'refs';
    TestUtil::check(!defined(&{'foo*bar'}), "Sub foo*bar should be undefined");
}

sub main {
    foreach my $symName (keys %TestHarness::Test::) {
	next unless $symName =~ /^test\_/;
	my $sub = *{ $TestHarness::Test::{$symName} }{CODE};
	if (defined $sub) {
	    TestUtil::enter("TestHarness::Test::$symName");
	    &$sub();
	    TestUtil::leave();
	}
    }
    print TestUtil::testSummary();
}

main() unless defined caller;

