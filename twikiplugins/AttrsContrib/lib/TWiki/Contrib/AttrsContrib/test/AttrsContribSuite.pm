use strict;

use TWiki::Contrib::Attrs;

{ package AttrsContribSuite;

  use base qw(Test::Unit::TestSuite);

  sub name { 'AttrsContrib' };

  sub include_tests { qw(AttrsTests) };
}

{ package AttrsTests;

  use base qw(Test::Unit::TestCase);

  sub new {
	my $self = shift()->SUPER::new(@_);
	return $self;
  }

  sub test_isEmpty {
	my $this = shift;

	my $attrs = TWiki::Contrib::Attrs->new(undef);
	$this->assert($attrs->isEmpty());
	$attrs = TWiki::Contrib::Attrs->new("");
	$this->assert($attrs->isEmpty());
	$attrs = TWiki::Contrib::Attrs->new(" \t  \n\t");
	$this->assert($attrs->isEmpty());
  }

  sub test_boolean {
	my $this = shift;

	my $attrs = TWiki::Contrib::Attrs->new("a");
	$this->assert(!$attrs->isEmpty());
	$this->assert_not_null($attrs->get("a"));
	$this->assert_str_equals("1", $attrs->get("a"));

	$attrs = TWiki::Contrib::Attrs->new("a12g b987");
	$this->assert_not_null($attrs->remove("a12g"));
	$this->assert_null($attrs->get("a12g"));
	$this->assert_not_null($attrs->remove("b987"));
	$this->assert_null($attrs->get("b987"));
	$this->assert($attrs->isEmpty());
  }

  sub test_default {
	my $this = shift;

	my $attrs = TWiki::Contrib::Attrs->new("\"wibble\"");
	$this->assert(!$attrs->isEmpty());
	$this->assert_str_equals("wibble", $attrs->remove("__default__"));
	$this->assert_null($attrs->get("__default__"));
	$this->assert($attrs->isEmpty());

	$attrs = TWiki::Contrib::Attrs->new("\"wibble\" \"fleegle\"");
	$this->assert_str_equals("fleegle", $attrs->remove("__default__"));
	$this->assert($attrs->isEmpty());
  }

  sub test_unquoted {
	my $this = shift;

	my $attrs = TWiki::Contrib::Attrs->new("var1=val1 var2= val2, var3 = 3 var4 =val4");
	$this->assert_str_equals("val1", $attrs->remove("var1"));
	$this->assert_str_equals("val2", $attrs->remove("var2"));
	$this->assert_str_equals("3", $attrs->remove("var3"));
	$this->assert_str_equals("val4", $attrs->remove("var4"));
	$this->assert($attrs->isEmpty());
  }

  sub test_doubleQuoted {
	my $this = shift;

	my $attrs = TWiki::Contrib::Attrs->new("var1 =\"val 1\", var2= \"val 2\" \" default \" var3 = \" val 3 \"");
	$this->assert_str_equals("val 1", $attrs->remove("var1"));
	$this->assert_str_equals("val 2", $attrs->remove("var2"));
	$this->assert_str_equals(" val 3 ", $attrs->remove("var3"));
	$this->assert_str_equals(" default ", $attrs->remove("__default__"));
	$this->assert($attrs->isEmpty());
  }

  sub test_singleQuoted {
	my $this = shift;

	my $attrs = TWiki::Contrib::Attrs->new("var1 ='val 1', var2= 'val 2' ' default ' var3 = ' val 3 '");
	$this->assert_str_equals("val 1", $attrs->remove("var1"));
	$this->assert_str_equals("val 2", $attrs->remove("var2"));
	$this->assert_str_equals(" val 3 ", $attrs->remove("var3"));
	$this->assert_str_equals(" default ", $attrs->remove("__default__"));
	$this->assert($attrs->isEmpty());
  }

  sub test_mixedQuotes {
	my $this = shift;

	my $attrs = TWiki::Contrib::Attrs->new("a ='\"', b=\"'\" \"'\"");
	$this->assert_str_equals("\"", $attrs->remove("a"));
	$this->assert_str_equals("'", $attrs->remove("b"));
	$this->assert_str_equals("'", $attrs->remove("__default__"));
	$this->assert($attrs->isEmpty());
	$attrs = TWiki::Contrib::Attrs->new("'\"'");
	$this->assert_str_equals("\"", $attrs->remove("__default__"));
	$this->assert($attrs->isEmpty());
  }

  sub test_toString {
	my $this = shift;

	my $attrs = TWiki::Contrib::Attrs->new("a ='\"', b=\"'\" \"'\"");
	my $s = $attrs->toString();
	$attrs = TWiki::Contrib::Attrs->new($attrs->toString());
	$this->assert_str_equals("\"", $attrs->remove("a"));
	$this->assert_str_equals("'", $attrs->remove("b"));
	$this->assert_str_equals("'", $attrs->remove("__default__"));
	$this->assert($attrs->isEmpty());
  }
}
1;
