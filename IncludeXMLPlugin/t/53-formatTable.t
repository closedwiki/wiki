use strict;
use FindBin;
BEGIN {require "$FindBin::RealBin/testenv.cfg"}

use Test::More tests => 5;

use TestPlugin;

subtest default => sub {
    plan tests => 1;
    
    my $plugin = TestPlugin->new;
    
    my $result = $plugin->formatTable(['@id', 'f1', 'f2'], [
        ['1', 'value 1.1', 'value 1.2'],
        ['2', 'value 2.1', 'value 2.2'],
    ]);
    
    is($$result,
        qq(| *\@id* | *f1* | *f2* |\n).
        qq(| 1 | value 1.1 | value 1.2 |\n).
        qq(| 2 | value 2.1 | value 2.2 |)); # no line breaks at the end
};

subtest format => sub {
    plan tests => 1;
    
    my $plugin = TestPlugin->new(
        format => '| $2 [ID: $1] | $3 |',
    );
    
    my $result = $plugin->formatTable(['@id', 'f1', 'f2'], [
        ['1', 'value 1.1', 'value 1.2'],
        ['2', 'value 2.1', 'value 2.2'],
    ]);
    
    is($$result,
        qq(| value 1.1 [ID: 1] | value 1.2 |\n).
        qq(| value 2.1 [ID: 2] | value 2.2 |)); # no line breaks at the end
};

subtest header_footer => sub {
    plan tests => 1;
    
    my $plugin = TestPlugin->new(
        header => '| *Field 1* | *Field 2* |',
        format => '| $2 [ID: $1] | $3 |',
        footer => '| *Field 1* | *Field 2* |',
    );
    
    my $result = $plugin->formatTable(['@id', 'f1', 'f2'], [
        ['1', 'value 1.1', 'value 1.2'],
        ['2', 'value 2.1', 'value 2.2'],
    ]);
    
    is($$result,
        qq(| *Field 1* | *Field 2* |\n).
        qq(| value 1.1 [ID: 1] | value 1.2 |\n).
        qq(| value 2.1 [ID: 2] | value 2.2 |\n).
        qq(| *Field 1* | *Field 2* |)); # no line breaks at the end
};

subtest variables => sub {
    plan tests => 1;
    
    my $plugin = TestPlugin->new(
        header => '| *Field 1* | *Field 2* |',
        format => '| $v1 [ID: $id] | ${v2} |',
    );
    
    my $result = $plugin->formatTable(['@id', 'f1', 'f2'], [
        ['1', 'value 1.1', 'value 1.2'],
        ['2', 'value 2.1', 'value 2.2'],
    ], [['id'], ['v1'], ['v2']]);
    
    is($$result,
        qq(| *Field 1* | *Field 2* |\n).
        qq(| value 1.1 [ID: 1] | value 1.2 |\n).
        qq(| value 2.1 [ID: 2] | value 2.2 |)); # no line breaks at the end
};

subtest explicit_variables => sub {
    plan tests => 1;
    
    my $plugin = TestPlugin->new(
        header => '| *Field 1* | *Field 2* |',
        format => '| $x1 [ID: $id] | ${x2} |',
    );
    
    my $result = $plugin->formatTable(['@id', 'f1', 'f2'], [
        ['1', 'value 1.1', 'value 1.2'],
        ['2', 'value 2.1', 'value 2.2'],
    ], [['id'], ['v1'], ['v2']], [[], ['x1'], ['x2']]);
    
    is($$result,
        qq(| *Field 1* | *Field 2* |\n).
        qq(| value 1.1 [ID: 1] | value 1.2 |\n).
        qq(| value 2.1 [ID: 2] | value 2.2 |)); # no line breaks at the end
};
