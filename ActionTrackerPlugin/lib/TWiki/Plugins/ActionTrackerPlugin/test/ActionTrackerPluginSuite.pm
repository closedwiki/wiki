package ActionTrackerPluginSuite;

use base qw(Test::Unit::TestSuite);

sub name { 'ActionTrackerPlugin' };

sub include_tests {
  qw(ActionTests SimpleActionSetTests FileActionSetTests LiveActionSetTests ExtendedActionSetTests ActionTrackerPluginTests ActionNotifyTests)
};

1;


