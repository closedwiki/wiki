package ArrayTest;

use TWiki::Plugins::FormQueryPlugin::Array;
use TWiki::Plugins::FormQueryPlugin::Map;
use TWiki::Plugins::FormQueryPlugin::Search;

use base qw(Test::Unit::TestCase);

sub new {
  my $self = shift()->SUPER::new(@_);
  # your state for fixture here
  return $self;
}

sub test_array {
  my $this = shift;

  my $array = new FormQueryPlugin::Array();
  my $i;
  for ($i = 0; $i < 100; $i++) {
    $array->add(new FormQueryPlugin::Map("f1=$i"));
  }
  my $sum = 0;
  for ($i = 0; $i < 100; $i++) {
    $this->assert_equals($i, $array->get($i)->get("f1"));
    $sum += $i;
  }

  $i = 0;
  foreach my $v ($array->getValues()) {
    $this->assert_equals($i, $v->get("f1"));
    $i++;
  }

  $this->assert_equals(100, $array->size());
  $this->assert_equals($sum, $array->get("f1"));
  $this->assert_equals($sum, $array->sum("f1"));

  my $search = new FormQueryPlugin::Search("f1=50");
  my $res = $array->search($search);
  $this->assert_equals(1, $res->size());
  $this->assert_equals(50, $res->get(0)->get("f1"));

  $search = new FormQueryPlugin::Search("f1>=90");
  $res = $array->search($search);
  $this->assert_equals(10, $res->size());
  for ($i = 90; $i < 100; $i++) {
    $this->assert_equals($i, $res->get($i-90)->get("f1"));
  }
}

sub test_sum {
  my $this = shift;

  my $array = new FormQueryPlugin::Array();

  $array->add(new FormQueryPlugin::Map("f1=1"));
  $array->add(new FormQueryPlugin::Map("f1=2"));
  $array->add(new FormQueryPlugin::Map());
  $array->add(new FormQueryPlugin::Array());
  $this->assert_equals(3,$array->sum("f1"));
}

1;
