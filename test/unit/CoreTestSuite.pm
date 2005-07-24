require 5.006;

package TWikiUnitTestsSuite;

use base qw(Test::Unit::TestSuite);

sub name { 'CoreTestSuite' };

# Assume we are run from the "test/unit" directory

sub include_tests {
    return (
        'AccessControlTests.pm',
        'AttrsTests.pm',
        'FuncTests.pm',
        'PrefsTests.pm',
        'SaveScriptTests.pm',
        'RcsTests.pm',
        'RegisterTests.pm',
        'StoreSmokeTests.pm',
        'MetaTests.pm',
        'RenameTests.pm',
        'StoreTests.pm',
        'UsersTests.pm',
        'PasswordTests.pm',
        'RobustnessTests.pm',
        'TemplatesTests.pm',
       );
};

1;
