# Tests for module ActionSet.pm
use lib ('.');
use Assert;
use ActionTests;
use SimpleActionSetTests;
use FileActionSetTests;
use LiveActionSetTests;
use ActionNotifyTests;
use ActionTrackerPluginTests;

Assert::runTests("ActionTests");  
Assert::runTests("SimpleActionSetTests");
Assert::runTests("FileActionSetTests");
Assert::runTests("LiveActionSetTests");
Assert::runTests("ActionNotifyTests");
Assert::runTests("ActionTrackerPluginTests");

1;
