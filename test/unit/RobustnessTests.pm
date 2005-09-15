# Copyright (C) 2004 Florian Weimer
package RobustnessTests;

use base qw(TWikiTestCase);
require 5.008;

use TWiki;
use TWiki::Sandbox;
use TWiki::Time;
use Error qw(:try);
sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

my @safe;
my $twiki;

sub set_up {
    my $this = shift;

    $this->SUPER::set_up();

    $twiki = new TWiki();
    @safe = (
        $twiki->{sandbox}->{REAL_SAFE_PIPE_OPEN},
        $twiki->{sandbox}->{EMULATED_SAFE_PIPE_OPEN}
       );
}

sub tear_down {
    my $this = shift;
    $this->SUPER::tear_down();
    $twiki->{sandbox}->{REAL_SAFE_PIPE_OPEN} = $safe[0];
    $twiki->{sandbox}->{EMULATED_SAFE_PIPE_OPEN} = $safe[1];
}

sub test_untaint {
    my $this = shift;

    $this->assert_str_equals('', TWiki::Sandbox::untaintUnchecked (''));
    $this->assert_not_null('abc', TWiki::Sandbox::untaintUnchecked ('abc'));
    $this->assert_null(TWiki::Sandbox::untaintUnchecked (undef));
}

sub test_normalize {
    my $this = shift;

    $this->assert_str_equals( 'abc', TWiki::Sandbox::normalizeFileName ('abc'));
    $this->assert_str_equals('abc', TWiki::Sandbox::normalizeFileName ('./abc'));
    $this->assert_str_equals('abc', TWiki::Sandbox::normalizeFileName ('abc/.'));
    $this->assert_str_equals('./-abc', TWiki::Sandbox::normalizeFileName ('-abc'));
    $this->assert_str_equals('./-', TWiki::Sandbox::normalizeFileName ('-'));
    $this->assert_str_equals('./--abc', TWiki::Sandbox::normalizeFileName ('--abc'));
    $this->assert_str_equals('./--', TWiki::Sandbox::normalizeFileName ('--'));
    $this->assert_str_equals('/abc', TWiki::Sandbox::normalizeFileName ('/abc'));
    $this->assert_str_equals('/abc', TWiki::Sandbox::normalizeFileName ('//abc'));
    $this->assert_str_equals('/a/bc', TWiki::Sandbox::normalizeFileName ('/a/bc'));
    $this->assert_str_equals('/a/bc', TWiki::Sandbox::normalizeFileName ('//a/bc'));
    $this->assert_str_equals('/a/b/c', TWiki::Sandbox::normalizeFileName ('/a/b/c'));
    $this->assert_str_equals('/a/b/c', TWiki::Sandbox::normalizeFileName ('//a/b/c'));
    $this->assert_str_equals('/a/b/c', TWiki::Sandbox::normalizeFileName ('/a/b/c/'));
    $this->assert_str_equals('/a/b/c', TWiki::Sandbox::normalizeFileName ('//a/b/c/'));

    try {
        TWiki::Sandbox::normalizeFileName('c/..');
        $this->assert(0);
    } catch Error::Simple with {
        $this->assert_matches(qr/^relative path/, shift->stringify());
    };
    try {
        TWiki::Sandbox::normalizeFileName ('../a');
        $this->assert(0);
    } catch Error::Simple with {
        $this->assert_matches(qr/^relative path/, shift->stringify());
    };
    try {
        $this->assert_str_equals('a/../b', TWiki::Sandbox::normalizeFileName ('//a/b/c/../..'));
        $this->assert(0);
    } catch Error::Simple with {
        $this->assert_matches(qr/^relative path/, shift->stringify());
    };
    $this->assert_str_equals('..a', TWiki::Sandbox::normalizeFileName ('..a/'));
    $this->assert_str_equals('a/..b', TWiki::Sandbox::normalizeFileName ('a/..b'));
}

sub test_buildCommandLine {
    my $this = shift;
    $this->assert_deep_equals(['a', 'b', 'c'],
                              [$twiki->{sandbox}->_buildCommandLine('a b c', ())]);
    $this->assert_deep_equals(['a', 'b', 'c'],
                              [$twiki->{sandbox}->_buildCommandLine(' a  b  c ', ())]);
    $this->assert_deep_equals([1, 2, 3],
                              [$twiki->{sandbox}->_buildCommandLine(' %A%  %B%  %C% ', (A => 1, B => 2, C => 3))]);
    $this->assert_deep_equals([1, "./-..", 'a/b'],
                              [$twiki->{sandbox}->_buildCommandLine(' %A|U%  %B|F%  %C|F% ', (A => 1, B => "-..", C => "a/b"))]);
    $this->assert_deep_equals([1, "2:3"],
                              [$twiki->{sandbox}->_buildCommandLine(' %A%  %B%:%C% ', (A => 1, B => 2, C => 3))]);
    $this->assert_deep_equals([1, "-n2:3"],
                              [$twiki->{sandbox}->_buildCommandLine(' %A%  -n%B%:%C% ', (A => 1, B => 2, C => 3))]);
    $this->assert_deep_equals([1, "-r2:HEAD", 3],
                              [$twiki->{sandbox}->_buildCommandLine(' %A%  -r%B%:HEAD %C% ', (A => 1, B => 2, C => 3))]);
    $this->assert_deep_equals(['a', 'b', '/c'],
                              [$twiki->{sandbox}->_buildCommandLine(' %A|F%  ', (A => ["a", "b", "/c"]))]);
    $this->assert_deep_equals(['1', '2.3', '4', 'string', ''],
                              [$twiki->{sandbox}->_buildCommandLine(' %A|N% %B|S% %C|S%', (A => [1, 2.3, 4], B => 'string', C => ''))]);
    $this->assert_deep_equals(['2004/11/20 09:57:41'],
                              [$twiki->{sandbox}->_buildCommandLine('%A|D%', A => TWiki::Time::formatTime (1100944661, '$rcs', 'gmtime'))]);
    eval { $twiki->{sandbox}->_buildCommandLine('%A|%') };
    $this->assert_not_null($@, '');
    eval { $twiki->{sandbox}->_buildCommandLine('%A|X%') };
    $this->assert_not_null($@, '');
    eval { $twiki->{sandbox}->_buildCommandLine(' %A|N%  ', A => '2/3') };
    $this->assert_not_null($@, '');
    eval { $twiki->{sandbox}->_buildCommandLine(' %A|S%  ', A => '2/3') };
    $this->assert_not_null($@, '');
}

sub verify {
    my $this = shift;
    my($out, $exit) = $twiki->{sandbox}->sysCommand(
        'sh -c %A%', A => 'echo OK; echo BOSS');
    $this->assert_str_equals("OK\nBOSS\n", $out);
    $this->assert_equals(0, $exit);
    ($out, $exit) = $twiki->{sandbox}->sysCommand(
        'sh -c %A%', A => 'echo JUNK ON STDERR 1>&2');
    $this->assert_equals(0, $exit);
    $this->assert_str_equals("", $out);
    ($out, $exit) = $twiki->{sandbox}->sysCommand(
        'test %A% %B% %C%', A => '1', B=>'-eq', C=>'2');
    $this->assert_equals(1, $exit, $exit.' '.$out);
    $this->assert_str_equals("", $out);
    ( $out, $exit) = $twiki->{sandbox}->sysCommand(
        'sh -c %A%', A => 'echo urmf; exit 7');
    $this->assert($exit != 0);
    $this->assert_str_equals("urmf\n", $out);
}

sub test_executeRSP {
    my $this = shift;
    $twiki->{sandbox}->{REAL_SAFE_PIPE_OPEN} = 1;
    $twiki->{sandbox}->{EMULATED_SAFE_PIPE_OPEN} = 0;
    $this->verify();
}

sub test_executeESP {
    my $this = shift;
    $twiki->{sandbox}->{REAL_SAFE_PIPE_OPEN} = 0;
    $twiki->{sandbox}->{EMULATED_SAFE_PIPE_OPEN} = 1;
    $this->verify();
}

sub test_executeNSP {
    my $this = shift;
    $twiki->{sandbox}->{REAL_SAFE_PIPE_OPEN} = 0;
    $twiki->{sandbox}->{EMULATED_SAFE_PIPE_OPEN} = 0;
    $this->verify();
}

1;
