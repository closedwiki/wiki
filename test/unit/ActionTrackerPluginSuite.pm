package ActionTrackerPluginSuite;

use base qw(Test::Unit::TestSuite);

sub name { 'ActionTrackerPlugin' };

sub include_tests {
  qw(ActionTests SimpleActionSetTests FileActionSetTests ExtendedActionSetTests ActionTrackerPluginTests ActionNotifyTests LiveActionSetTests );
};

1;


