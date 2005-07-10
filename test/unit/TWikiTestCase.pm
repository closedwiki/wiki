package TWikiTestCase;
#
# Base class of all TWiki tests. Establishes base paths and adds
# some useful functionality such as comparing HTML
#
BEGIN {
    push( @INC, "$ENV{TWIKI_HOME}/lib" );
};

use base qw(Test::Unit::TestCase);

use TWiki;
use TWiki::Plugins::TestFixturePlugin::HTMLDiffer;
use strict;

sub protectCFG() {
    my $this = shift;
    foreach my $i (keys %TWiki::cfg ) {
        $this->{__TWikiSafe}{$i} = $TWiki::cfg{$i};
    }
}

sub restoreCFG {
    my $this = shift;
    for my $i (keys %{$this->{__TWikiSafe}} ) {
        $TWiki::cfg{$i} = $this->{__TWikiSafe}{$i};
    }
}

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

sub assert_html_equals {
    my( $this, $e, $a, $mess ) = @_;
    my ($package, $filename, $line) = caller(0);
    my $opts =
      {
       options => 'rex',
       reporter =>
       \&TWiki::Plugins::TestFixturePlugin::HTMLDiffer::defaultReporter,
       result => ''
      };

    $mess ||= "$a\ndoes not equal\n$e";
    $this->assert($e, "$filename:$line\n$mess");
    $this->assert($a, "$filename:$line\n$mess");
    unless( TWiki::Plugins::TestFixturePlugin::HTMLDiffer::diff($e, $a, $opts)) {
        $this->assert(0, "$filename:$line\n$mess");
    }
}

sub assert_html_matches {
    my ($this, $e, $a, $mess ) = @_;
    $mess ||= "$a\ndoes not match\n$e";
    my ($package, $filename, $line) = caller(0);
    unless( TWiki::Plugins::TestFixturePlugin::HTMLDiffer::html_matches($e, $a)) {
        $this->assert(0, "$filename:$line\n$mess");
    }
}

1;
