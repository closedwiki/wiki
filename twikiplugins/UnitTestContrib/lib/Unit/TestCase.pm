package Unit::TestCase;

use strict;
use Error qw( :try );
use Carp;

sub new {
    my $class = shift;
    my $this = bless({}, $class);
    @{$this->{annotations}} = ();
    return $this;
}

sub set_up {
    my $this = shift;
    @{$this->{annotations}} = ();
}

sub tear_down {
}

sub list_tests {
    my ($this, $suite) = @_;
    die "No suite" unless $suite;
    my @tests;
    my $clz = new Devel::Symdump($suite);
    for my $i ($clz->functions()) {
        if ($i =~ /^$suite\:\:test/) {
            push(@tests, $i);
        }
    }
    return @tests;
}

sub assert {
    my ($this, $bool, $mess) = @_;
    return 1 if $bool;
    $mess ||= "Assertion failed";
    $mess = join("\n", @{$this->{annotations}})."\n".$mess;
    die $mess;
}

sub assert_equals {
    my ($this, $expected, $got, $mess) = @_;
    if (defined($got) && defined($expected)) {
        $this->assert($expected eq $got,
                      $mess || "Expected:'$expected'\n But got:'$got'\n");
    } elsif (!defined($got)) {
        $this->assert_null($expected);
    } else {
        $this->assert_null($got);
    }
}

sub assert_not_null {
    my ($this, $wot, $mess) = @_;
    $this->assert(defined($wot), $mess);
}

sub assert_null {
    my ($this, $wot, $mess) = @_;
    $this->assert(!defined($wot), $mess);
}

sub assert_str_equals {
    my ($this, $expected, $got, $mess) = @_;
    $this->assert_not_null($expected);
    $this->assert_not_null($got);
    $this->assert($expected eq $got, $mess || "Expected:'$expected'\n But got:'$got'\n");
}

sub assert_str_not_equals {
    my ($this, $expected, $got, $mess) = @_;
    $this->assert_not_null($expected);
    $this->assert_not_null($got);
    $this->assert($expected ne $got, $mess || "Expected:'$expected'\n And got:'$got'\n");
}

sub assert_num_equals {
    my ($this, $expected, $got, $mess) = @_;
    $this->assert_not_null($expected);
    $this->assert_not_null($got);
    $this->assert($expected == $got, $mess || "Expected:'$expected'\n But got:'$got'\n");
}

sub assert_matches {
    my ($this, $expected, $got, $mess) = @_;
    $this->assert_not_null($expected);
    $this->assert_not_null($got);
    $this->assert($expected =~ /$got/, $mess || "Expected:'$expected'\n But got:'$got'\n");
}

sub assert_does_not_match {
    my ($this, $expected, $got, $mess) = @_;
    $this->assert_not_null($expected);
    $this->assert_not_null($got);
    $this->assert($got !~ /$expected/, $mess || "Expected:'$expected'\n And got:'$got'\n");
}

sub assert_deep_equals {
    my ($this, $expected, $got, $mess) = @_;

    if (UNIVERSAL::isa($expected, 'ARRAY')) {
        $this->assert(UNIVERSAL::isa($got, 'ARRAY'));
        for ( 0..$#$expected ) {
            $this->assert_deep_equals($expected->[$_], $got->[$_], $mess);
        }
    }
    elsif (UNIVERSAL::isa($expected, 'HASH')) {
        $this->assert(UNIVERSAL::isa($got, 'HASH'));
        my %matched;
        for ( keys %$expected ) {
            $this->assert_deep_equals($expected->{$_}, $got->{$_}, $mess);
            $matched{$_} = 1;
        }
        for (keys %$got) {
            $this->assert($matched{$_});
        }
    }
    elsif (UNIVERSAL::isa($expected, 'REF') ||
        UNIVERSAL::isa($expected, 'SCALAR')) {
        $this->assert_equals(ref($expected), ref($got));
        $this->assert_deep_equals($$expected, $$got, $mess);
    }
    else {
        $this->assert_equals($expected, $got, $mess);
    }
}

sub annotate {
    my ($this, $mess) = @_;
    push(@{$this->{annotations}}, $mess) if defined($mess);
}

# 1:1 HTML comparison. Correctly compares attributes in tags. Uses HTML::Parser
# which is tolerant of unbalanced tags, so the actual may have unbalanced
# tags which will _not_ be detected.
sub assert_html_equals {
    my( $this, $e, $a, $mess ) = @_;

    my ($package, $filename, $line) = caller(0);
    my $opts =
      {
       options => 'rex',
       reporter =>
       \&HTMLDiffer::defaultReporter,
       result => ''
      };

    $mess ||= "$a\ndoes not equal\n$e";
    $this->assert($e, "$filename:$line\n$mess");
    $this->assert($a, "$filename:$line\n$mess");
    if( HTMLDiffer::diff($e, $a, $opts)) {
        $this->assert(0, "$filename:$line\n$mess\n$opts->{result}");
    }
}

# Uses a regular-expression match to try to match a block of HTML in a larger
# block of HTML. Not too clever about tag attributes.
sub assert_html_matches {
    my ($this, $e, $a, $mess ) = @_;

    $mess ||= "$a\ndoes not match\n$e";
    my ($package, $filename, $line) = caller(0);
    unless( HTMLDiffer::html_matches($e, $a)) {
        $this->assert(0, "$filename:$line\n$mess");
    }
}

# invoke a subroutine while grabbing stdout, so the "http
# response" doesn't flood the console that you're running the
# unit test from.
# $this->capture(\&proc, ...) -> $stdout
# ... params get passed on to &proc
sub capture {
    my $this = shift;
    my $proc = shift;

    # take copy of the file descriptor
    open(OLDOUT, ">&STDOUT");
    open(STDOUT, ">/tmp/cgi");

    my $text = undef;
    my @params = @_;
    my $result;

    try {
        $result = &$proc( @params );
    } finally {
        close(STDOUT)            or die "Can't close STDOUT: $!";
        open(STDOUT, ">&OLDOUT") or die "Can't restore stderr: $!";
        close(OLDOUT)            or die "Can't close OLDOUT: $!";
    };

    $text = '';
    open(FH, '/tmp/cgi');
    local $/ = undef;
    $text = <FH>;
    close(FH);
    unlink('/tmp/cgi');

    return ( $text, $result );
}

1;
