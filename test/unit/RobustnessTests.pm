# Copyright (C) 2004 Florian Weimer
require 5.006;
use strict;

package RobustnessTests;

use base qw(Test::Unit::TestCase);

BEGIN {
    unshift @INC, '../../bin';
    require 'setlib.cfg';
};

require '../../bin/setlib.cfg';
use TWiki;
use TWiki::Sandbox;
use TWiki::Time;
use strict;

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

my $web = "TestRcsWeb";
my $topic = "TestRcsTopic";
my $user = "TestUser1";
my $thePathInfo = "/$web/$topic";
my $theUrl = "/save/$web/$topic";

my $twiki;

sub set_up {
    $twiki = new TWiki( $thePathInfo, $user, $topic, $theUrl );
}

sub test_env {
    my $this = shift;
    if ( $TWiki::cfg{OS} eq "UNIX" ) {
        $this->assert( $twiki->{sandbox}->{REAL_SAFE_PIPE_OPEN} );
    } else {
        $this->assert( $twiki->{sandbox}->{EMULATED_SAFE_PIPE_OPEN} );
    }
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
    $this->assert_str_equals('/a/b', TWiki::Sandbox::normalizeFileName ('/a/b/c/..', 1));
    $this->assert_str_equals('/a/b', TWiki::Sandbox::normalizeFileName ('//a/b/c/..', 1));
    $this->assert_str_equals('/a', TWiki::Sandbox::normalizeFileName ('/a/b/c/../..', 1));
    $this->assert_str_equals('/a', TWiki::Sandbox::normalizeFileName ('//a/b/c/../..', 1));
    $this->assert_str_equals('/', TWiki::Sandbox::normalizeFileName ('/a/b/c/../../..', 1));
    $this->assert_str_equals('/', TWiki::Sandbox::normalizeFileName ('//a/b/c/../../..', 1));
    $this->assert_str_equals('a/b', TWiki::Sandbox::normalizeFileName ('a/b/c/..', 1));
    $this->assert_str_equals('a', TWiki::Sandbox::normalizeFileName ('a/b/c/../..', 1));

    eval { TWiki::Sandbox::normalizeFileName ('a/b/c/../../..', 1) };
    $this->assert_not_null ($@, '');
    eval { TWiki::Sandbox::normalizeFileName ('a/..', 1) };
    $this->assert_not_null ($@, '');
    eval { TWiki::Sandbox::normalizeFileName ('-/..', 1) };
    $this->assert_not_null ($@, '');
    eval { TWiki::Sandbox::normalizeFileName ('') };
    $this->assert_not_null ($@, '');
    eval { TWiki::Sandbox::normalizeFileName ('', 1) };
    $this->assert_not_null ($@, '');
    eval { TWiki::Sandbox::normalizeFileName (undef) };
    $this->assert_not_null ($@, '');
    eval { TWiki::Sandbox::normalizeFileName (undef, 1) };
    $this->assert_not_null ($@, '');
    eval { TWiki::Sandbox::normalizeFileName ('a/b/../c') };
    $this->assert_not_null ($@, '');
}

sub test_buildCommandLine {
    my $this = shift;
    $this->assert_deep_equals(['a', 'b', 'c'],
                              [$twiki->{sandbox}->buildCommandLine('a b c', ())]);
    $this->assert_deep_equals(['a', 'b', 'c'],
                              [$twiki->{sandbox}->buildCommandLine(' a  b  c ', ())]);
    $this->assert_deep_equals([1, 2, 3],
                              [$twiki->{sandbox}->buildCommandLine(' %A%  %B%  %C% ', (A => 1, B => 2, C => 3))]);
    $this->assert_deep_equals([1, "./-..", 'a/b'],
                              [$twiki->{sandbox}->buildCommandLine(' %A|U%  %B|F%  %C|F% ', (A => 1, B => "-..", C => "a/b"))]);
    $this->assert_deep_equals([1, "2:3"],
                              [$twiki->{sandbox}->buildCommandLine(' %A%  %B%:%C% ', (A => 1, B => 2, C => 3))]);
    $this->assert_deep_equals([1, "-n2:3"],
                              [$twiki->{sandbox}->buildCommandLine(' %A%  -n%B%:%C% ', (A => 1, B => 2, C => 3))]);
    $this->assert_deep_equals([1, "-r2:HEAD", 3],
                              [$twiki->{sandbox}->buildCommandLine(' %A%  -r%B%:HEAD %C% ', (A => 1, B => 2, C => 3))]);
    $this->assert_deep_equals(['a', 'b', '/c'],
                              [$twiki->{sandbox}->buildCommandLine(' %A|F%  ', (A => ["a", "b", "/c"]))]);
    $this->assert_deep_equals(['1', '2.3', '4', 'string', ''],
                              [$twiki->{sandbox}->buildCommandLine(' %A|N% %B|S% %C|S%', (A => [1, 2.3, 4], B => 'string', C => ''))]);
    $this->assert_deep_equals(['2004/11/20 09:57:41'],
                              [$twiki->{sandbox}->buildCommandLine('%A|D%', A => TWiki::Time::formatTime (1100944661, '$rcs', 'gmtime'))]);
    eval { $twiki->{sandbox}->buildCommandLine('%A|%') };
    $this->assert_not_null($@, '');
    eval { $twiki->{sandbox}->buildCommandLine('%A|X%') };
    $this->assert_not_null($@, '');
    eval { $twiki->{sandbox}->buildCommandLine(' %A|N%  ', A => '2/3') };
    $this->assert_not_null($@, '');
    eval { $twiki->{sandbox}->buildCommandLine(' %A|S%  ', A => '2/3') };
    $this->assert_not_null($@, '');
}

sub test_execute {
    my $this = shift;
    $this->assert_deep_equals([" 1 2 "],
                              [$twiki->{sandbox}->readFromProcessArray('echo',
                                                           ' %A%  %B% ',
                                                           (A => " 1", B => "2 "))]);

    $this->assert_deep_equals(['', 7],
                              [$twiki->{sandbox}->readFromProcess('sh -c %A%', A => 'exit 7')]);
    $this->assert_deep_equals(["1\n2\n", 0],
                              [$twiki->{sandbox}->readFromProcess ('sh -c %A%', A => 'echo 1; echo 2')]);
    $this->assert_deep_equals(["1\n2\n", 0],
                              [$twiki->{sandbox}->readFromProcess ('sh -c %A%', A => 'echo 1; echo 2 1>&2')]);
}

1;
