use strict;
use FindBin;
BEGIN {require "$FindBin::RealBin/testenv.cfg"}

use Test::More tests => 5;

use TestPlugin;

subtest basic => sub {
    plan tests => 4;
    
    my $plugin = TestPlugin->new(records => 'row', fields => '@id, f1, f2');
    
    my ($fields, $table, $varnames, $exnames) = $plugin->buildTable(<<END);
<xml>
  <row id="1">
    <f1>value 1.1</f1>
    <f2>value 1.2</f2>
  </row>
  <row id="2">
    <f1>value 2.1</f1>
    <f2>value 2.2</f2>
  </row>
</xml>
END
    
    is_deeply($fields, ['@id', 'f1', 'f2']);
    is_deeply($table, [['1', 'value 1.1', 'value 1.2'], ['2', 'value 2.1', 'value 2.2']]);
    is_deeply($varnames, [['id'], ['f1'], ['f2']]);
    is_deeply($exnames, [[], [], []]);
};

subtest records_only => sub {
    plan tests => 4;
    
    my $plugin = TestPlugin->new(records => 'row');
    
    my ($fields, $table, $varnames, $exnames) = $plugin->buildTable(<<END);
<xml>
  <row id="1">
    <f1>value 1.1</f1>
    <f2>value 1.2</f2>
  </row>
  <row id="2">
    <f1>value 2.1</f1>
    <f2>value 2.2</f2>
  </row>
</xml>
END
    
    is_deeply($fields, ['@id', 'f1', 'f2']);
    is_deeply($table, [['1', 'value 1.1', 'value 1.2'], ['2', 'value 2.1', 'value 2.2']]);
    is_deeply($varnames, [['id'], ['f1'], ['f2']]);
    is_deeply($exnames, [[], [], []]);
};

subtest fields_only => sub {
    plan tests => 4;
    
    my $plugin = TestPlugin->new(fields => '@id, f1, f2');
    
    my ($fields, $table, $varnames, $exnames) = $plugin->buildTable(<<END);
<xml>
  <row id="1"/>
  <values>
    <f1>value 1.1</f1>
    <f2>value 1.2</f2>
  </values>
  <row id="2"/>
  <values>
    <f2>value 2.2</f2>
    <f1>value 2.1</f1>
  </values>
</xml>
END
    
    is_deeply($fields, ['@id', 'f1', 'f2']);
    is_deeply($table, [['1', 'value 1.1', 'value 1.2'], ['2', 'value 2.1', 'value 2.2']]);
    is_deeply($varnames, [['id'], ['f1'], ['f2']]);
    is_deeply($exnames, [[], [], []]);
};

subtest itemsep => sub {
    plan tests => 4;
    
    my $plugin = TestPlugin->new(records => 'row', fields => '@id, f1, f2', itemsep => '<br/>');
    
    my ($fields, $table, $varnames, $exnames) = $plugin->buildTable(<<END);
<xml>
  <row id="1">
    <f1>value 1.1.1</f1><f1>value 1.1.2</f1>
    <f2>value 1.2.1</f2>
  </row>
  <row id="2">
    <f1>value 2.1.1</f1>
    <f2>value 2.2.1</f2><f2>value 2.2.2</f2>
  </row>
</xml>
END
    
    is_deeply($fields, ['@id', 'f1', 'f2']);
    is_deeply($table, [
        ['1', 'value 1.1.1<br/>value 1.1.2', 'value 1.2.1'],
        ['2', 'value 2.1.1', 'value 2.2.1<br/>value 2.2.2'],
    ]);
    is_deeply($varnames, [['id'], ['f1'], ['f2']]);
    is_deeply($exnames, [[], [], []]);
};

subtest escape => sub {
    plan tests => 4;
    
    my $plugin = TestPlugin->new(records => 'row', fields => '@id, f1, f2', tml => 'off');
    
    my ($fields, $table, $varnames, $exnames) = $plugin->buildTable(<<END);
<xml>
  <row id="1">
    <f1>%value% | *1.1*</f1>
    <f2>%value% | *1.2*</f2>
  </row>
  <row id="2">
    <f1>%value% | *2.1*</f1>
    <f2>%value% | *2.2*</f2>
  </row>
</xml>
END
    
    is_deeply($fields, ['@id', 'f1', 'f2']);
    is_deeply($table, [
        ['1', '&#37;value&#37; &#124; &#42;1.1&#42;', '&#37;value&#37; &#124; &#42;1.2&#42;'],
        ['2', '&#37;value&#37; &#124; &#42;2.1&#42;', '&#37;value&#37; &#124; &#42;2.2&#42;'],
    ]);
    is_deeply($varnames, [['id'], ['f1'], ['f2']]);
    is_deeply($exnames, [[], [], []]);
};
