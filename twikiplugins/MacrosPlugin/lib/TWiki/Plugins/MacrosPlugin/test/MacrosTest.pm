use strict;

package MacrosTest;

use base qw(BaseFixture);

use TWiki::Store;
use TWiki::Func;

use TWiki::Plugins::MacrosPlugin;

use CGI;

sub new {
  my $self = shift()->SUPER::new(@_);
  return $self;
}

# Set up the test fixture
sub set_up {
  my $this = shift;

  $this->SUPER::set_up();
  # to force it to use Cairo compatibility mode, change the following
  # to "1"
  $TWiki::Plugins::VERSION = 1.020;
  TWiki::Plugins::MacrosPlugin::initPlugin();

  BaseFixture::writeTopic("One", "MacroA",
"A\%CALLMACRO{topic=\%t\%,x=\"0\",y=1}\%A");
   BaseFixture::writeTopic("One", "MacroB",
"B\%CALLMACRO{topic=\%t\%,x=\"\%x%\%y\%\",y=2}\%");
   BaseFixture::writeTopic("One", "MacroC",
"C%x%C%y%C");
   BaseFixture::writeTopic("Two", "MacroD",
"D%x%\nD\n%y%D\n%STRIP%");
}

sub testSimple {
  my $this = shift;
  my $tst;

  $tst = "%CALLMACRO{topic=Two.MacroD,x=1,y=2}%";
  TWiki::Plugins::MacrosPlugin::commonTagsHandler($tst, "T", "One");
  $this->assert_str_equals("D1D2D", $tst);

  $tst = "%CALLMACRO{topic=Two/MacroD,x=1,y=2}%";
  TWiki::Plugins::MacrosPlugin::commonTagsHandler($tst, "T", "One");
  $this->assert_str_equals("D1D2D", $tst);
}

sub testPassthrough {
  my $this = shift;
  my $tst;

  $tst = "%CALLMACRO{topic=MacroA,t=MacroC}%";
  TWiki::Plugins::MacrosPlugin::commonTagsHandler($tst, "T", "One");
  $this->assert_str_equals("AC0C1CA", $tst);

  $tst = "%CALLMACRO{topic=MacroA,t=Two.MacroD}%";
  TWiki::Plugins::MacrosPlugin::commonTagsHandler($tst, "T", "One");
  $this->assert_str_equals("AD0D1DA", $tst);
}

sub testNoSuchMacro {
  my $this = shift;
  my $tst = "%CALLMACRO{topic=MacroA}%";
  TWiki::Plugins::MacrosPlugin::commonTagsHandler($tst, "T", "One");
  $this->assert_str_equals("A <font color=red> No such macro %t% in CALLMACRO{topic=%t%,x=\"0\",y=1} </font> A", $tst);
}

sub testSimpleSet {
  my $this = shift;

  my $tst = "X\n%SET Y = 10\nY\n%Y%\n";
  TWiki::Plugins::MacrosPlugin::commonTagsHandler($tst, "T", "One");
  $this->assert_str_equals("XY\n10\n", $tst);

  $tst = "%SET Y = 10\nY\n%Y%\n";
  TWiki::Plugins::MacrosPlugin::commonTagsHandler($tst, "T", "One");
  $this->assert_str_equals("Y\n10\n", $tst);

  $tst = "X\n%SET Y = 10\n";
  TWiki::Plugins::MacrosPlugin::commonTagsHandler($tst, "T", "One");
  $this->assert_str_equals("X", $tst);
}

1;
