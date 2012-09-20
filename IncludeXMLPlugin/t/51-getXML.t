use strict;
use FindBin;
BEGIN {require "$FindBin::RealBin/testenv.cfg"}

use Test::More tests => 2;

use TestPlugin;

my $plugin;

$plugin = TestPlugin->new('<xml/>');
is(${$plugin->getXML($plugin->{params}{_DEFAULT})}, '<xml/>');

$plugin = TestPlugin->new('/pub/Main/WebHome/simple.xml');
is(${$plugin->getXML($plugin->{params}{_DEFAULT})}, $plugin->readTestFile("/pub/Main/WebHome/simple.xml"));
