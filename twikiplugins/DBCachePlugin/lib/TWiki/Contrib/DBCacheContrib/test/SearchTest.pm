package SearchTest;

use TWiki::Contrib::Map;
use TWiki::Contrib::Search;
use Time::ParseDate;
use base qw(Test::Unit::TestCase);

sub new {
  my $self = shift()->SUPER::new(@_);
  $self->{map} = undef;
  return $self;
}

sub set_up {
  my $this = shift;
  $this->{map} = new DBCachePlugin::Map("
     string = \"String\",
     number = 99,
     date = \"3-Jul-1960\"");
  # date's a sunday!
  my $mother = new DBCachePlugin::Map("who=Mother");
  $this->{map}->set("mother", $mother);
  my $gran = new DBCachePlugin::Map("who=GrandMother");
  $mother->set("mother", $gran);
}

sub tear_down {
  my $this = shift;
  $this->{map} = undef;
}

sub test_empty {
  my $this = shift;
  my $search = new DBCachePlugin::Search("");
  $this->assert_not_null( $search );
  $this->assert_equals(1,$search->matches($this->{map}));
}

sub test_badparse {
  my $this = shift;
  eval {  new DBCachePlugin::Search("WITHIN_DAYS"); };
  $this->assert_not_null($@,$@);
  eval {  new DBCachePlugin::Search("x WITHIN_DAYS 30"); };
  $this->assert_not_null($@,$@);
  eval {  new DBCachePlugin::Search("z WITHIN_DAYS < 3"); };
  $this->assert_not_null($@,$@);
}

sub check {
  my ( $this, $s, $r ) = @_;
  my $search = new DBCachePlugin::Search($s);
  $this->assert_equals($r,
		       $search->matches($this->{map}),
		       $search->toString().
		       " expected $r in ".
		       $this->{map}->toString());
}

sub test_stringops {
  my $this = shift;
  $this->check("string='String'",1);
  $this->check("string='String '",0);
  $this->check("string=~'String '", 0);
  $this->check("string='Str'", 0);
  $this->check("string=~'trin'", 1);
  $this->check("string=~' String'", 0);
  $this->check("string!='Str'", 1);
  $this->check("string!='String '", 1);
  $this->check("string!='String'", 0);
}

sub test_numops {
  my $this = shift;
  $this->check("number='99'",1);
  $this->check("number='98'", 0);
  $this->check("number!='99'", 0);
  $this->check("number!='0'", 1);
  $this->check("number<'100'", 1);
  $this->check("number<'99'", 0);
  $this->check("number>'98'", 1);
  $this->check("number>'99'", 0);
  $this->check("number<='99'", 1);
  $this->check("number<='100'", 1);
  $this->check("number<='98'", 0);
  $this->check("number>='98'", 1);
  $this->check("number>='99'", 1);
  $this->check("number>='100'", 0);
}

sub test_dateops {
  my $this = shift;
  $this->check("date IS_DATE '3 jul 1960'", 1);
  $this->check("date IS_DATE '3-JUL-1960'", 1);
  $this->check("date IS_DATE '4-JUL-1960'", 0);
  $this->check("date EARLIER_THAN '4-JUL-1960'",1);
  $this->check("date EARLIER_THAN '3-JUL-1960'", 0);
  $this->check("date EARLIER_THAN '2-JUL-1960'", 0);
  $this->check("date LATER_THAN '2-Jul-1960'", 1);
  $this->check("date LATER_THAN '3 jul 1960'", 0);
  $this->check("date LATER_THAN '4 jul 1960'", 0);
}

sub test_dateops2 {
  my $this = shift;
  DBCachePlugin::Search::forceTime("30 jun 1960");#thursday
  $this->check("date WITHIN_DAYS '4'", 1);
  $this->check("date WITHIN_DAYS '3'", 1);
  $this->check("date WITHIN_DAYS '2'", 1); # th & fri
  $this->check("date WITHIN_DAYS '1'", 0);
  $this->check("date WITHIN_DAYS '0'", 0);
}

sub test_dateops3 {
  my $this = shift;
  DBCachePlugin::Search::forceTime("3 jul 1960");
  $this->check("date WITHIN_DAYS '2'", 1);
  $this->check("date WITHIN_DAYS '1'", 1);
  $this->check("date WITHIN_DAYS '0'", 1);
}

sub test_dateops4 {
  my $this = shift;
  DBCachePlugin::Search::forceTime("4 jul 1960");
  $this->check("date WITHIN_DAYS '2'", 0);
  $this->check("date WITHIN_DAYS '1'", 0);
  $this->check("date WITHIN_DAYS '0'", 0);
}

sub test_not {
  my $this = shift;
  $this->check("!number='99'",0);
  $this->check("!number='98'", 1);
}

sub test_and {
  my $this = shift;
  $this->check("number='99' AND string='String'",1);
  $this->check("number='98' AND string='String'", 0);
  $this->check("number='99' AND string='Sring'", 0);
  $this->check("number='99' AND string='String' AND date IS_DATE '3 jul 1960'", 1);
}

sub test_or {
  my $this = shift;
  $this->check("number='99' OR string='Spring'",1);
  $this->check("number='98' OR string='String'", 1);
  $this->check("number='98' OR string='Spring'", 0);
}

sub conjoin {
  my ( $this, $last, $A, $B, $a, $b, $c, $r ) = @_;

  my $ae = "number='" . ( $a ? "99" : "98" ) . "'";
  my $be = "string='" . ( $b ? "String" : "Spring" ) . "'";
  my $ce = "date EARLIER_THAN '" . ( $c ? "4-jul-1960" : "3-jul-1960" ) . "'";
  my $expr;
  if ( $last ) {
    $expr = "$ae $A ( $be $B $ce )";
  } else {
    $expr = "( $ae $A $be ) $B $ce";
  }
  $this->check($expr,$r);
}

sub test_brackets {
  my $this = shift;
  for (my $a = 0; $a < 2; $a++) {
    for (my $b = 0; $b < 2; $b++) {
      for (my $c = 0; $c < 2; $c++) {
	$this->conjoin(1,"AND","OR", $a, $b, $c, $a && ($b || $c));
	$this->conjoin(1,"OR","AND", $a, $b, $c, $a || ($b && $c));
	$this->conjoin(0,"AND","OR",$a, $b, $c, ($a && $b) || $c);
	$this->conjoin(0,"OR","AND",$a, $b, $c, ($a || $b) && $c);
      }
    }
  }
}

sub test_other {
  my $this = shift;
  $this->check("mother.who='Mother'",1);
  $this->check("mother.who!='Mother'",0);
  $this->check("mother.mother.who='GrandMother'",1);
}

1;
