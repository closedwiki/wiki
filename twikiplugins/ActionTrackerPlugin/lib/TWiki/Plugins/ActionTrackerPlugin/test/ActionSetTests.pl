# Tests for module ActionSet.pm
use lib ('.');
use Assert;
use SimpleActionSetTests;
use FileActionSetTests;
use LiveActionSetTests;

Assert::runTests("SimpleActionSetTests");
Assert::runTests("FileActionSetTests");
Assert::runTests("LiveActionSetTests");

1;
