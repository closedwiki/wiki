use lib ('fakewiki');
use lib ('../../../..');
use TWiki::Plugins::ActionTrackerPlugin;
use Assert;
use TWiki::TestMaker;
use TWiki::Func;

{ package TWiki::Plugins;

  use vars qw ( $VERSION );

  $VERSION=2;
}
