package MapTest;

use TWiki::Plugins::DBCachePlugin::Map;
use TWiki::Plugins::DBCachePlugin::Search;
use base qw(Test::Unit::TestCase);

sub new {
  my $self = shift()->SUPER::new(@_);
  # your state for fixture here
  return $self;
}

sub test_parse1 {
  my $this = shift;
  my $attrs = new DBCachePlugin::Map( "a = one bit=\"two\" c" );
  $this->assert_not_null($attrs);
  $this->assert_str_equals("one", $attrs->get("a"));
  $this->assert_str_equals("two", $attrs->get("bit"));
  $this->assert_str_equals("on", $attrs->get("c"));
}

sub test_parse2 {
  my $this = shift;
  my $attrs = new DBCachePlugin::Map( "aname = one,b = \"two\",c" );
  $this->assert_not_null($attrs);
  $this->assert_str_equals("one", $attrs->get("aname"));
  $this->assert_str_equals("two", $attrs->get("b"));
  $this->assert_str_equals("on", $attrs->get("c"));
}

sub test_parse3 {
  my $this = shift;
  my $attrs = new DBCachePlugin::Map( "x.y=one" );
  $this->assert_not_null($attrs);
  $this->assert_str_equals("one", $attrs->get("x.y"));
}

sub test_parse4 {
  my $this = shift;
  my $attrs;
  eval { new DBCachePlugin::Map( "topic=MacroReqDetails area = \"Signal Integrity\" status=\"Assigned\" release=\"2003.06|All product=\"Fsim\"" ); };

  $this->assert_not_null($@);
}

sub test_remove {
  my $this = shift;
  my $attrs = new DBCachePlugin::Map( "a = one bit=\"two\" c" );
  $this->assert_not_null($attrs);
  $this->assert_str_equals("one", $attrs->remove("a"));
  $this->assert_str_equals("two", $attrs->remove("bit"));
  $this->assert_str_equals("on", $attrs->remove("c"));
  $this->assert_null($attrs->get("a"));
  $this->assert_null($attrs->get("bit"));
  $this->assert_null($attrs->get("c"));
}

sub test_multipleDefs1 {
  my $this = shift;
  my $attrs = new DBCachePlugin::Map( "a = one a=\"two\"" );
  $this->assert_not_null($attrs);
  $this->assert_str_equals("two", $attrs->get("a"));
}

sub testMultipleDefs2 {
  my $this = shift;
  my $attrs = new DBCachePlugin::Map( "a=\"two\" a" );
  $this->assert_not_null($attrs);
  $this->assert_str_equals("on", $attrs->remove("a"));
}

sub testMultipleDefs3 {
  my $this = shift;
  my $attrs = new DBCachePlugin::Map( "a=two a" );
  $this->assert_not_null($attrs);
  $this->assert_str_equals("on", $attrs->remove("a"));
}

sub testMultipleDefs4 {
  my $this = shift;
  my $attrs = new DBCachePlugin::Map( "a a = one" );
  $this->assert_not_null($attrs);
  $this->assert_str_equals("one", $attrs->remove("a"));
}

sub testStringOnOwn {
  my $this = shift;
  my $attrs = new DBCachePlugin::Map( "\"able cain\" a=\"no\"" );
  $this->assert_not_null($attrs);
  $this->assert_str_equals("able cain", $attrs->get("\$1"));
  $this->assert_str_equals("no", $attrs->remove("a"));
}

sub test_big {
  my $this = shift;
  my $n = 0;
  my $str = "";
  while ( $n < 1000 ) {
    $str .= ",a$n=b$n";
    $n++;
  }
  my $attrs = new DBCachePlugin::Map( $str );
}

sub test_set {
  my $this = shift;
  my $attrs = new DBCachePlugin::Map( "\"able cain\" a=\"no\"" );
  $attrs->set( "2", "two" );
  $this->assert_equals(3, $attrs->size());
  $this->assert_str_equals("able cain", $attrs->remove("\$1"));
  $this->assert_str_equals("no", $attrs->remove("a"));
  $this->assert_str_equals("two", $attrs->remove("2"));
  $this->assert_equals(0, $attrs->size());
}

sub test_kandv {
  my $this = shift;
  my $attrs = new DBCachePlugin::Map( "a=A b=B c=C d=D" );
  $this->assert_equals(4, $attrs->size());
  my $tst = "abcd";
  foreach my $val ($attrs->getKeys()) {
    $tst =~ s/$val//;
  }
  $this->assert_equals("", $tst);
  $tst = "ABCD";
  foreach my $val ($attrs->getValues()) {
    $tst =~ s/$val//;
  }
  $this->assert_equals("", $tst);
}

sub test_search {
  my $this = shift;
  my $attrs = new DBCachePlugin::Map();
  $attrs->set("a", new DBCachePlugin::Map("f=A"));
  $attrs->set("b", new DBCachePlugin::Map("f=B"));
  $attrs->set("c", new DBCachePlugin::Map("f=C"));
  $attrs->set("d", new DBCachePlugin::Map("f=D"));
  $this->assert_equals(4, $attrs->size());
  my $search = new DBCachePlugin::Search("f=~'(B|C)'");
  my $res = $attrs->search($search);
  my $tst = "BC";
  foreach my $e ($res->getValues()) {
    my $v = $e->get("f");
    $tst =~ s/$v//;
  }
  $this->assert_str_equals("", $tst);
}

1;
