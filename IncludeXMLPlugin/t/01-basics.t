use strict;
use FindBin;
BEGIN {require "$FindBin::RealBin/testenv.cfg"}

use Test::More tests => 4;

use TWiki;

my $pkg = 'TWiki::Plugins::IncludeXMLPlugin';

use_ok($pkg);

use_ok($pkg.'::'.$_) foreach qw(
    Handler
    SubsequenceGenerator
    XPathModifier
);
