package DBCacheContribSuite;

use base qw(Test::Unit::TestSuite);

sub name { 'DBCacheContrib' };

sub include_tests {
    qw(ArrayTest MapTest FileTimeTest SearchTest DBCacheTest)
};

1;
