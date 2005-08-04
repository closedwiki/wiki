use strict;

# Pathologically most simple test case.
package ExampleTests;

use base qw(TWikiTestCase);

use TWiki;

sub testHelloWorld {
   print "Hello, world\n";
   1;
} 

1;