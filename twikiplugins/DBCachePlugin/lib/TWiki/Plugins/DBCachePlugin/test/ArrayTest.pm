package ArrayTest;

use TWiki::Plugins::DBCachePlugin::Array;
use TWiki::Plugins::DBCachePlugin::Map;
use TWiki::Plugins::DBCachePlugin::Search;

use base qw(Test::Unit::TestCase);

sub new {
  my $self = shift()->SUPER::new(@_);
  # your state for fixture here
  return $self;
}

sub test_array {
  my $this = shift;

  my $array = new DBCachePlugin::Array();
  my $i;
  for ($i = 0; $i < 100; $i++) {
    my $fred = new DBCachePlugin::Map("f1=$i");
    $array->add($fred);
  }
  my $sum = 0;
  for ($i = 0; $i < 100; $i++) {
    $this->assert_equals($i, $array->get($i)->get("f1"));
    $sum += $i;
  }

  $i = 0;
  foreach my $v ($array->getValues()) {
    $this->assert_equals($i, $v->get("f1"));
    $this->assert_equals($i, $array->find( $v ));
    $i++;
  }
  my $nonex = new DBCachePlugin::Map("f1=1");
  $this->assert_equals(-1, $array->find($nonex));

  $this->assert_equals(100, $array->size());
  $this->assert_equals($sum, $array->get("f1"));
  $this->assert_equals($sum, $array->sum("f1"));

  my $search = new DBCachePlugin::Search("f1=50");
  my $res = $array->search($search);
  $this->assert_equals(1, $res->size());
  $this->assert_equals(50, $res->get(0)->get("f1"));

  $search = new DBCachePlugin::Search("f1>=90");
  $res = $array->search($search);
  $this->assert_equals(10, $res->size());
  for ($i = 90; $i < 100; $i++) {
    $this->assert_equals($i, $res->get($i-90)->get("f1"));
  }
}

sub test_gets {
  my $this = shift;
  my $array = new DBCachePlugin::Array();
  my $i;
  for ($i = 0; $i < 10; $i++) {
    my $fred = new DBCachePlugin::Map("f1=$i");
    $array->add($fred);
  }
  my $k = 0;
  foreach $i ( $array->getValues()) {
    $i->set("f2", $k++);
  }
  for ($i = 0; $i < 10; $i++) {
    my $fred = $array->get($i);
    $this->assert_equals($i, $fred->get("f1"));
    $this->assert_equals($i, $fred->get("f2"));
  }
}

sub test_contains {
  my $this = shift;
  my $array = new DBCachePlugin::Array();
  my $i;
  for ($i = 0; $i < 10; $i++) {
    my $fred = new DBCachePlugin::Map("f1=$i");
    $this->assert(!$array->contains($fred));
    $array->add($fred);
    $this->assert($array->contains($fred));
  }
}

sub test_find {
  my $this = shift;
  my $array = new DBCachePlugin::Array();
  my $i;
  for ($i = 0; $i < 10; $i++) {
    my $fred = new DBCachePlugin::Map("f1=$i");
    $this->assert_equals(-1,$array->find($fred));
    $array->add($fred);
    $this->assert_equals($i,$array->find($fred));
  }
}

sub test_remove {
  my $this = shift;
  my $array = new DBCachePlugin::Array();
  my $i;
  my @nums;
  for ($i = 0; $i < 3; $i++) {
    my $fred = new DBCachePlugin::Map("f1=$i");
    push(@nums, $fred);
    $array->add($fred);
  }
  # from the middle
  my $n = $array->find($nums[1]);
  $array->remove($n);
  $this->assert_equals(2, $array->size());

  # off the front
  $n = $array->find($nums[0]);
  $array->remove($n);
  $this->assert_equals(1, $array->size());

  # off the back
  $n = $array->find($nums[2]);
  $array->remove($n);
  $this->assert_equals(0, $array->size());
}

sub test_sum {
  my $this = shift;

  my $array = new DBCachePlugin::Array();

  $array->add(new DBCachePlugin::Map("f1=1"));
  $array->add(new DBCachePlugin::Map("f1=2"));
  $array->add(new DBCachePlugin::Map());
  $array->add(new DBCachePlugin::Array());
  $this->assert_equals(3,$array->sum("f1"));
}

1;
