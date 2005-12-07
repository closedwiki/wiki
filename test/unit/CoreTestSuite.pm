require 5.006;

package CoreTestSuite;

use base qw(Test::Unit::TestSuite);

sub name { 'CoreTestSuite' };

# Assume we are run from the "test/unit" directory

sub include_tests {
    return (
        'AccessControlTests.pm',
        'AttrsTests.pm',
        'FuncTests.pm',
        'MetaTests.pm',
        'PasswordTests.pm',
        'PrefsTests.pm',
        'RcsTests.pm',
        'RegisterTests.pm',
        'RenameTests.pm',
        'RobustnessTests.pm',
        'SaveScriptTests.pm',
        'StoreSmokeTests.pm',
        'StoreTests.pm',
        'TemplatesTests.pm',
        'UsersTests.pm',
        'VariableTests.pm',
       );
};

1;
