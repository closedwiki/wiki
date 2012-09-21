use strict;
use FindBin;
BEGIN {require "$FindBin::RealBin/testenv.cfg"}

use Test::More tests => 4;

use_ok 'TWiki::Plugins::JiraPlugin';
use_ok 'TWiki::Plugins::JiraPlugin::Handler';
use_ok 'TWiki::Plugins::JiraPlugin::Client';
use_ok 'TWiki::Plugins::JiraPlugin::Field';
