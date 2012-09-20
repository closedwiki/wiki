use strict;
use FindBin;
BEGIN {require "$FindBin::RealBin/testenv.cfg"}

use Test::More tests => 60;

use TWiki::Plugins::IncludeXMLPlugin::XPathModifier;

my @cases = (
    {
        text     => 'abc, def, @ghi',
        prefix   => '//',
        xpaths   => ['abc', 'def', '@ghi'],
        mxpaths  => ['//abc', '//def', '//@ghi'],
        varnames => [['abc'], ['def'], ['ghi']],
        exnames  => [[], [], []],
    }, {
        text     => '*[name()="foo"]/bar , /foo/@bar|@baz ,*[@id=123] , ',
        prefix   => '//',
        xpaths   => ['*[name()="foo"]/bar', '/foo/@bar|@baz', '*[@id=123]'],
        mxpaths  => ['//*[name()="foo"]/bar', '(/foo/@bar|//@baz)', '//*[@id=123]'],
        varnames => [['bar'], ['bar', 'baz'], []],
        exnames  => [[], [], []],
    }, {
        text     => 'item[text()="/a/b[@c=1234], |x|y|z|"] | item2',
        prefix   => './/',
        xpaths   => ['item[text()="/a/b[@c=1234], |x|y|z|"] | item2'],
        mxpaths  => ['(.//item[text()="/a/b[@c=1234], |x|y|z|"] | .//item2)'],
        varnames => [['item', 'item2']],
        exnames  => [[], [], []],
    }, {
        text     => 'invalid[xpath("test",||)],|*@text',
        prefix   => './/',
        xpaths   => ['invalid[xpath("test",||)]', '|*@text'],
        mxpaths  => ['.//invalid[xpath("test",||)]', '(|.//*@text)'],
        varnames => [['invalid'], ['text']],
        exnames  => [[], [], []],
    }, {
        text     => '$var1 = item/@id, item/value, $var2 = *[name()=\'abc\'] | *[name()=\'def\']',
        prefix   => '//',
        xpaths   => ['item/@id', 'item/value', '*[name()=\'abc\'] | *[name()=\'def\']'],
        mxpaths  => ['//item/@id', '//item/value', '(//*[name()=\'abc\'] | //*[name()=\'def\'])'],
        varnames => [['id'], ['value'], []],
        exnames  => [['var1'], [], ['var2']],
    }, {
        text     => '$foo = foo, $baz = bar, $bar = baz',
        prefix   => './/',
        xpaths   => ['foo', 'bar', 'baz'],
        mxpaths  => ['.//foo', './/bar', './/baz'],
        varnames => [['foo'], ['bar'], ['baz']],
        exnames  => [['foo'], ['baz'], ['bar']],
    }
);

my $xpm = TWiki::Plugins::IncludeXMLPlugin::XPathModifier->new;

for (@cases) {
    my ($text, $prefix, $xpaths, $mxpaths, $varnames, $exnames) =
        ($_->{text}, $_->{prefix}, $_->{xpaths}, $_->{mxpaths}, $_->{varnames}, $_->{exnames});
    
    $xpm->parse($text)->addPrefixes($prefix);
    
    my @result;
    my @expected;
    
    @result = $xpm->getXPaths();
    @expected = @$xpaths;
    
    for my $i (0..$#result) {
        is($result[$i], $expected[$i],
            "result: '$result[$i]'; expected: '$expected[$i]'");
    }
    
    @result = $xpm->getModifiedXPaths();
    @expected = @$mxpaths;
    
    for my $i (0..$#result) {
        is($result[$i], $expected[$i],
            "result: '$result[$i]'; expected: '$expected[$i]'");
    }

    @result = $xpm->getVariableNames();
    @expected = @$varnames;

    for my $i (0..$#result) {
        is_deeply($result[$i], $expected[$i],
            "result: [".join(', ', map {"'$_'"} @{$result[$i]})."]; expected: [".join(', ', map {"'$_'"} @{$expected[$i]})."]");
    }

    @result = $xpm->getExplicitNames();
    @expected = @$exnames;

    for my $i (0..$#result) {
        is_deeply($result[$i], $expected[$i],
            "result: [".join(', ', map {"'$_'"} @{$result[$i]})."]; expected: [".join(', ', map {"'$_'"} @{$expected[$i]})."]");
    }
}
