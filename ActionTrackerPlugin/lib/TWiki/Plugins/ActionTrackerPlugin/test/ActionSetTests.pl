# Tests for module ActionSet.pm
use lib ('.');
use Assert;
use SimpleActionSetTests;
use FileActionSetTests;
use LiveActionSetTests;
use ExtendedActionSetTests;

Assert::runTests("SimpleActionSetTests");
Assert::runTests("FileActionSetTests");
Assert::runTests("LiveActionSetTests");
Assert::runTests("ExtendedActionSetTests");

1;
