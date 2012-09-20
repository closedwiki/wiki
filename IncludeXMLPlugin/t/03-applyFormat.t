use strict;
use FindBin;
BEGIN {require "$FindBin::RealBin/testenv.cfg"}

use Test::More tests => 2;

use TestPlugin;

subtest format => sub {
    plan tests => 7;
    
    my $plugin = TestPlugin->new;
    
    my $values = [qw(foo bar baz)];
    my $varmap = {'x' => 0, 'y' => 1, 'z' => 2};
    
    is($plugin->applyFormat(undef, $values), '| foo | bar | baz |');
    is($plugin->applyFormat('$2::$3::$1', $values), 'bar::baz::foo');
    is($plugin->applyFormat('| [[$y][$x]] | $z |', $values, $varmap), '| [[bar][foo]] | baz |');
    is($plugin->applyFormat('| [[$y][$1]] | $3 |', $values, $varmap), '| [[bar][foo]] | baz |');
    is($plugin->applyFormat('$unknown $9876', $values, $varmap), '$unknown $9876');
    is($plugin->applyFormat('X${x}X${y}X${z}X', $values, $varmap), 'XfooXbarXbazX');
    is($plugin->applyFormat('X${1}X${2}X${3}X', $values, $varmap), 'XfooXbarXbazX');
};

subtest escape_standard => sub {
    plan tests => 4;
    
    my $plugin = TestPlugin->new;
    
    my $values = [qw(foo bar baz)];
    my $varmap = {'x' => 0, 'y' => 1, 'z' => 2};
    
    is($plugin->applyFormat('$x $n $percntRED$percnt$y$percntENDCOLOR$percnt', $values, $varmap),
        'foo '."\n".' %RED%bar%ENDCOLOR%');
    
    is($plugin->applyFormat('$percntTEST{$quottest$quot format=$quot$dollarxyz$quot}$percnt', $values, $varmap),
        '%TEST{"test" format="$xyz"}%');
    
    is($plugin->applyFormat('[[$n]] ($dollar)', ['test'], {n => 0}), '[[test]] ($)');
    is($plugin->applyFormat('[[$n]] ($dollar)', ['test', 'xyz'], {n => 0, dollar => 1}), '[[test]] (xyz)');
};
