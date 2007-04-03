#
# Base class of all TWiki tests. Establishes base paths and adds
# some useful functionality such as comparing HTML
#
# The basic strategy in all unit tests is to never write to normal
# TWiki data areas; only ever write to temporary test areas. If you
# have to create a test fixture that duplicates an existing area,
# you can always create a new web based on that web.
#
package TWikiTestCase;

use base qw(Test::Unit::TestCase);
use Data::Dumper;
use HTMLDiffer;

use TWiki;
use strict;
use Error qw( :try );

BEGIN {
    push( @INC, "$ENV{TWIKI_HOME}/lib" ) if defined($ENV{TWIKI_HOME});
    unshift @INC, '../../bin';
    require 'setlib.cfg';
    $SIG{__DIE__} = sub { Carp::confess $_[0] };
};

# Temporary directory to store log files in.
# Will be cleaned up after running the tests unless the environment
# variable TWIKI_DEBUG_KEEP is true
use File::Temp;
my $cleanup  =  $ENV{TWIKI_DEBUG_KEEP} ? 0 : 1;
my $tempdir  =  File::Temp::tempdir( CLEANUP => $cleanup );

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

# Use this to save the TWiki cfg to a backing store during start_up
# so it can be temporarily changed during tests.
sub set_up {
    my $this = shift;

    $this->SUPER::set_up();

    # force a read of $TWiki::cfg
    my $tmp = new TWiki();
    # This needs to be a deep copy
    $this->{__TWikiSafe} = Data::Dumper->Dump([\%TWiki::cfg], ['*TWiki::cfg']);
    $tmp->finish();

    # Move logging into a temporary directory
    $TWiki::cfg{LogFileName} = "$tempdir/TWikiTestCase.log";
    $TWiki::cfg{WarningFileName} = "$tempdir/TWikiTestCase.warn";
}

# Restores TWiki::cfg from backup
sub tear_down {
    my $this = shift;
    eval {$this->{twiki}->finish()};
    %TWiki::cfg = eval $this->{__TWikiSafe};
}

sub _copy {
    my $n = shift;

    return undef unless defined( $n );

    if (UNIVERSAL::isa($n, 'ARRAY')) {
        my @new;
        for ( 0..$#$n ) {
            push(@new, _copy( $n->[$_] ));
        }
        return \@new;
    }
    elsif (UNIVERSAL::isa($n, 'HASH')) {
        my %new;
        for ( keys %$n ) {
            $new{$_} = _copy( $n->{$_} );
        }
        return \%new;
    }
    elsif (UNIVERSAL::isa($n, 'REF') || UNIVERSAL::isa($n, 'SCALAR')) {
        $n = _copy($$n);
        return \$n;
    }
    elsif (ref($n) eq 'Regexp') {
        return qr/$n/;
    }
    else {
        return $n;
    }
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

sub removeWebFixture {
    my( $this, $twiki, $web ) = @_;

    try {
        $twiki->{store}->removeWeb($twiki->{user}, $web);
    } otherwise {
        my $e = shift;
        print STDERR "Unexpected exception while removing web $web\n";
        print STDERR $e->stringify(),"\n" if $e;
    };
}

1;
