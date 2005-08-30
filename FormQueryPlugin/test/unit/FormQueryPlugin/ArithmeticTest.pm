package ArithmeticTest;

use TWiki::Plugins::FormQueryPlugin::Arithmetic;

use base qw(Test::Unit::TestCase);

sub new {
  my $self = shift()->SUPER::new(@_);
  return $self;
}

sub check {
  my ( $this, $r, $expr ) = @_;
  $this->assert_equals($r,  TWiki::Plugins::FormQueryPlugin::Arithmetic::evaluate($expr));
}

sub check_bad {
  my ( $this, $r, $expr ) = @_;
  $res =  TWiki::Plugins::FormQueryPlugin::Arithmetic::evaluate($expr);
  #$this->assert_not_null( $@ );
  $this->assert_equals( $r, $@ ) unless ( $res =~ /$r/ );
}

sub test_simple {
  my $this = shift;
  $this->assert_equals(1 + 2,
		        TWiki::Plugins::FormQueryPlugin::Arithmetic::evaluate("1 + 2"));
  $this->assert_equals(1 + 2 - 3,
		        TWiki::Plugins::FormQueryPlugin::Arithmetic::evaluate("1 + 2 - 3"));
  $this->assert_equals(1 + -2,
		        TWiki::Plugins::FormQueryPlugin::Arithmetic::evaluate("1 + -2"));
  $this->assert_equals(-1 + 2,
		        TWiki::Plugins::FormQueryPlugin::Arithmetic::evaluate("-1 + 2"));
  $this->assert_equals(-1 - -2,
		        TWiki::Plugins::FormQueryPlugin::Arithmetic::evaluate("-1 - -2"));
}

sub test_prec {
  my $this = shift;
  $this->assert_equals(2 * 4 - 3,
		        TWiki::Plugins::FormQueryPlugin::Arithmetic::evaluate("2 * 4 - 3"));
  $this->assert_equals(2 - 4 * 3,
		        TWiki::Plugins::FormQueryPlugin::Arithmetic::evaluate("2 - 4 * 3"));
  $this->assert_equals(-4 * 3,
		        TWiki::Plugins::FormQueryPlugin::Arithmetic::evaluate("-4 * 3"));
}

sub test_brackets {
  my $this = shift;
  $this->assert_equals(2 * (4 - 3),
		        TWiki::Plugins::FormQueryPlugin::Arithmetic::evaluate("2 * (4 - 3)"));
  $this->assert_equals((2 + 2) - (4 - 3),
		        TWiki::Plugins::FormQueryPlugin::Arithmetic::evaluate("(2+2)-(4-3)"));
  $this->assert_equals((2 + 2) - -(4 - 3),
		        TWiki::Plugins::FormQueryPlugin::Arithmetic::evaluate("(2+2)--(4-3)"));
  $this->assert_equals((2 + 2) - +(+4 - 3),
		        TWiki::Plugins::FormQueryPlugin::Arithmetic::evaluate("(2+2)-+(+4-3)"));
}

sub test_round {
  my $this = shift;
  $this->assert_equals(1,
		        TWiki::Plugins::FormQueryPlugin::Arithmetic::evaluate("round 1.1"));
  $this->assert_equals(1,
		        TWiki::Plugins::FormQueryPlugin::Arithmetic::evaluate("round 0.9"));
  $this->assert_equals(1,
		        TWiki::Plugins::FormQueryPlugin::Arithmetic::evaluate("round 0.5"));
  $this->assert_equals(0,
		        TWiki::Plugins::FormQueryPlugin::Arithmetic::evaluate("round 0.1"));
  $this->assert_equals(0,
		        TWiki::Plugins::FormQueryPlugin::Arithmetic::evaluate("round -0.1"));
  $this->assert_equals(-1,
		        TWiki::Plugins::FormQueryPlugin::Arithmetic::evaluate("round -0.5"));
  $this->assert_equals(-1,
		        TWiki::Plugins::FormQueryPlugin::Arithmetic::evaluate("round -0.9"));
  $this->assert_equals(-1,
		        TWiki::Plugins::FormQueryPlugin::Arithmetic::evaluate("round -1.1"));
  $this->assert_equals(1,
		        TWiki::Plugins::FormQueryPlugin::Arithmetic::evaluate("round(1.1)"));
}

sub test_point {
  my $this = shift;
  $this->assert_equals(1234.5678 / 9765.4321,
		       TWiki::Plugins::FormQueryPlugin::Arithmetic::evaluate("1234.5678 / 9765.4321"));
  $this->assert_equals(.5678 + .9765,
		       TWiki::Plugins::FormQueryPlugin::Arithmetic::evaluate(".5678 + .9765"));
}

sub test_bad {
  my $this = shift;
  $this->check_bad("No left operand", "1234.5678 * * 9765.4321");
  $this->check_bad("Bad token", "2 * a");
}

1;
