use strict;
use FindBin;
BEGIN {require "$FindBin::RealBin/testenv.cfg"}

use TestPlugin;

sub plugin {
    my @params = eval shift;
    die $@ if $@;
    my $plugin = TestPlugin->new(@params);
    return ${$plugin->generate()};
}

use Test::Base;
__DATA__

=== default

--- input plugin
'<xml>
  <row id="1">
    <f1>value 1.1</f1>
    <f2>value 1.2</f2>
  </row>
  <row id="2">
    <f1>value 2.1</f1>
    <f2>value 2.2</f2>
  </row>
</xml>',
records => 'row',
fields => '@id, f1, f2',

--- expected chomp
| *@id* | *f1* | *f2* |
| 1 | value 1.1 | value 1.2 |
| 2 | value 2.1 | value 2.2 |

=== format

--- input plugin
'<xml>
  <row id="1">
    <f1>value 1.1</f1>
    <f2>value 1.2</f2>
  </row>
  <row id="2">
    <f1>value 2.1</f1>
    <f2>value 2.2</f2>
  </row>
</xml>',
records => 'row',
fields => '@id, f1, f2',
format => '| $f1 [ID: $id] | $f2 |',

--- expected chomp
| value 1.1 [ID: 1] | value 1.2 |
| value 2.1 [ID: 2] | value 2.2 |

=== header and footer

--- input plugin
'<xml>
  <row id="1">
    <f1>value 1.1</f1>
    <f2>value 1.2</f2>
  </row>
  <row id="2">
    <f1>value 2.1</f1>
    <f2>value 2.2</f2>
  </row>
</xml>',
records => 'row',
fields => '@id, f1, f2',
header => '| *ID* | *Field 1* | *Field 2* |',
footer => '$percntRED$percntFooter$percntENDCOLOR$percnt',

--- expected chomp
| *ID* | *Field 1* | *Field 2* |
| 1 | value 1.1 | value 1.2 |
| 2 | value 2.1 | value 2.2 |
%RED%Footer%ENDCOLOR%

=== format with $n at the end

--- input plugin
'<xml>
  <row id="1">
    <f1>value 1.1</f1>
    <f2>value 1.2</f2>
  </row>
  <row id="2">
    <f1>value 2.1</f1>
    <f2>value 2.2</f2>
  </row>
</xml>',
records => 'row',
fields => '@id, f1, f2',
format => '| $f1 [ID: $id] | $f2 |$n',
header => '| *ID* | *Field 1* | *Field 2* |$n',
footer => '| *ID* | *Field 1* | *Field 2* |$n',

--- expected
| *ID* | *Field 1* | *Field 2* |
| value 1.1 [ID: 1] | value 1.2 |
| value 2.1 [ID: 2] | value 2.2 |
| *ID* | *Field 1* | *Field 2* |

=== xmlns

--- input plugin
'<ex1:xml xmlns:ex1="http://example1.com" xmlns:ex2="http://example2.com">
  <ex1:row id="1">
    <ex2:f1>value 1.1</ex2:f1>
    <ex2:f2>value 1.2</ex2:f2>
  </ex1:row>
  <ex1:row id="2">
    <ex2:f1>value 2.1</ex2:f1>
    <ex2:f2>value 2.2</ex2:f2>
  </ex1:row>
</ex1:xml>',
records => '/ex1:xml/ex1:row',
fields => '@id, ex2:f1, ex2:f2',
xmlns_ex1 => 'http://example1.com',
xmlns_ex2 => 'http://example2.com',
format => '| $f1 [ID: $id] | $f2 |',
header => '| *ID* | *Field 1* | *Field 2* |',

--- expected chomp
| *ID* | *Field 1* | *Field 2* |
| value 1.1 [ID: 1] | value 1.2 |
| value 2.1 [ID: 2] | value 2.2 |

=== xpath with implicit variables

--- input plugin
'<xml>
  <row id="1" enabled="true">
    <attrs>
      <f1>value 1.1</f1>
      <f2>value 1.2</f2>
    </attrs>
  </row>
  <row id="2" enabled="false">
    <attrs>
      <f1>value 2.1</f1>
      <f2>value 2.2</f2>
    </attrs>
  </row>
  <row id="3" enabled="true">
    <attrs>
      <f1>value 3.1</f1>
      <f2>value 3.2</f2>
    </attrs>
  </row>
</xml>',
records => '/xml/row[@enabled="true"]',
fields => '@id, ./attrs/f1, ./attrs/f2',
format => '---++ ID: $id $n   * Field 1: $f1 $n   * Field 2: $f2 $n',

--- expected
---++ ID: 1 
   * Field 1: value 1.1 
   * Field 2: value 1.2 
---++ ID: 3 
   * Field 1: value 3.1 
   * Field 2: value 3.2 

=== xpath with explicit variables

--- input plugin
'<xml>
  <row id="1" enabled="true">
    <attrs>
      <attr name="f1">value 1.1</attr>
      <attr name="f2">value 1.2</attr>
    </attrs>
  </row>
  <row id="2" enabled="false">
    <attrs>
      <attr name="f1">value 2.1</attr>
      <attr name="f2">value 2.2</attr>
    </attrs>
  </row>
  <row id="3" enabled="true">
    <attrs>
      <attr name="f1">value 3.1</attr>
      <attr name="f2">value 3.2</attr>
    </attrs>
  </row>
</xml>',
records => '/xml/row[@enabled="true"]',
fields => '@id, $v1 = attrs/attr[@name="f1"], $v2 := attrs/attr[@name="f2"]',
format => '---++ ID: $id $n   * Field 1: $v1 $n   * Field 2: $v2 $n',

--- expected
---++ ID: 1 
   * Field 1: value 1.1 
   * Field 2: value 1.2 
---++ ID: 3 
   * Field 1: value 3.1 
   * Field 2: value 3.2 

=== separator

--- input plugin
'<xml>
  <row id="1">
    <f1>value 1.1</f1>
    <f2>value 1.2</f2>
  </row>
  <row id="2">
    <f1>value 2.1</f1>
    <f2>value 2.2</f2>
  </row>
</xml>',
records => 'row',
fields => '@id, f1, f2',
format => '{id: "$id", f1: "$f1", f2: "$f2"}',
separator => ',$n',

--- expected chomp
{id: "1", f1: "value 1.1", f2: "value 1.2"},
{id: "2", f1: "value 2.1", f2: "value 2.2"}

=== itemsep

--- input plugin
'<xml>
  <row id="1">
    <f1>value 1.1.1</f1>
    <f1>value 1.1.2</f1>
    <f2>value 1.2.1</f2>
  </row>
  <row id="2">
    <f1>value 2.1.1</f1>
    <f2>value 2.2.1</f2>
    <f2>value 2.2.2</f2>
  </row>
</xml>',
records => 'row',
fields => '@id, f1, f2',
itemsep => ';<br/>',

--- expected chomp
| *@id* | *f1* | *f2* |
| 1 | value 1.1.1;<br/>value 1.1.2 | value 1.2.1 |
| 2 | value 2.1.1 | value 2.2.1;<br/>value 2.2.2 |

=== offset, limit, reverse

--- input plugin
'<xml>
  <row id="1">
    <f1>value 1.1</f1>
  </row>
  <row id="2">
    <f1>value 2.1</f1>
  </row>
  <row id="3">
    <f1>value 3.1</f1>
  </row>
  <row id="4">
    <f1>value 4.1</f1>
  </row>
</xml>',
records => 'row',
fields => '@id, f1',
offset => '1',
limit => '-1',
reverse => 'on',

--- expected chomp
| *@id* | *f1* |
| 3 | value 3.1 |
| 2 | value 2.1 |

=== escape html

--- input plugin
'<xml>
  <row id="1">
    <f1>0 &lt; x &lt; N |
-N &lt; y &lt; 0</f1>
  </row>
</xml>',
records => 'row',
fields => 'f1',
html => 'off',

--- expected chomp
| *f1* |
| 0 &lt; x &lt; N &#124;<br/>-N &lt; y &lt; 0 |

=== do not escape html

--- input plugin
'<xml>
  <row id="1">
    <f1>&lt;p&gt;para 1&lt;/p&gt;
&lt;p&gt;para 2&lt;/p&gt;</f1>
  </row>
</xml>',
records => 'row',
fields => 'f1',
html => 'on',

--- expected chomp
| *f1* |
| <p>para 1</p> <p>para 2</p> |

=== escape tml

--- input plugin
'<xml>
  <row id="1">
    <f1>x * 10 % y != z</f1>
  </row>
</xml>',
records => 'row',
fields => 'f1',
tml => 'off',

--- expected chomp
| *f1* |
| x * 10 &#37; y &#33;= z |

=== do not escape tml

--- input plugin
'<xml>
  <row id="1">
    <f1>*bold* | %RED%red%ENDCOLOR%</f1>
  </row>
</xml>',
records => 'row',
fields => 'f1',
tml => 'on',

--- expected chomp
| *f1* |
| *bold* &#124; %RED%red%ENDCOLOR% |

=== raw

--- input plugin
'<xml>
  <row id="1">
    <f1>---++ Table
| *A* | *B* |
| a | b |</f1>
  </row>
</xml>',
records => 'row',
fields => 'f1',
raw => 'on',
format => '$f1',

--- expected chomp
---++ Table
| *A* | *B* |
| a | b |

=== raw xml

--- input plugin
'<xml>
  <row id="1">
    <f1>
      test &lt;1&gt;
      <nested>test &lt;2&gt;</nested>
      test &lt;3&gt;
    </f1>
  </row>
</xml>',
records => 'row',
fields => 'f1',
raw => 'xml',
format => '    <tag>$f1</tag>',

--- expected chomp
    <tag>
      test &lt;1&gt;
      <nested>test &lt;2&gt;</nested>
      test &lt;3&gt;
    </tag>
