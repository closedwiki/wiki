The test module has a number of modules and entry points. Each module is a test class in the spirit of JUnit, and contains a set of test functions that address a specific piece of functionality, usually one of the main perl modules. The modules can be run independently using perl -w <module>.pl for example

perl -w ActionTests.pl.

The submodule directory 'faketwiki' fakes the functions of a TWiki and is used to build test fixtures. It is a long way from implementing the full functionality of TWiki!

This all ought to be converted to use PerlUnit.
