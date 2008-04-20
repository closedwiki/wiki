# Test for StringifyBase.pm
package StringifyBaseTest;
use base qw( TWikiFnTestCase );

use strict;
use File::Temp qw/tmpnam/;

use TWiki::Contrib::SearchEngineKinoSearchAddOn::StringifyBase;

sub set_up {
    my $this = shift;

    $this->SUPER::set_up();
}

sub tear_down {
    my $this = shift;
    $this->SUPER::tear_down();
}

sub test_rmtree {
    my $this = shift;
    my $stringifier = TWiki::Contrib::SearchEngineKinoSearchAddOn::StringifyBase->new();

    # Lets create a test directory that I will delete afterwards.
    # Note: Here I use unix commands and don't care on windows compatibility.
    my $tmp_dir = tmpnam();

    my $cmd = "cp -R tree_example $tmp_dir";
    `$cmd`;

    # Now lets try to remove that dir
    $stringifier->rmtree($tmp_dir);

    $this->assert(! (-f $tmp_dir), "Directory $tmp_dir not deleteted.");

    # Now try to delete just a file
    $cmd = "cp -R tree_example\test_file.txt $tmp_dir";
    $stringifier->rmtree($tmp_dir);

    $this->assert(! (-f $tmp_dir), "File $tmp_dir not deleteted.");
}

1;
