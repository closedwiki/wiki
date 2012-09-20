use strict;
use FindBin;
BEGIN {require "$FindBin::RealBin/testenv.cfg"}

use Test::More tests => 5;

use TestPlugin;

subtest plain_html => sub {
    plan tests => 23;

    my $plugin = TestPlugin->new(html => "on", tml => "on");
    
    is($plugin->escapeValue(''), '');
    is($plugin->escapeValue('test'), 'test');
    is($plugin->escapeValue('&lt;font color=&quot;#F00&quot;&gt;Red text&lt;/font&gt;'), '<font color="#F00">Red text</font>');
    is($plugin->escapeValue('<font color="#F00">Red text</font>'), '<font color="#F00">Red text</font>');
    is($plugin->escapeValue("  leading  and  trailing  spaces  "), "leading  and  trailing  spaces");

    is($plugin->escapeValue("<div>\n  <span>span</span>\n</div>\n"), "<div>   <span>span</span> </div>");
    is($plugin->escapeValue("<div>\r\n  <span>span</span>\r\n</div>\r\n"), "<div>   <span>span</span> </div>");
    is($plugin->escapeValue("para 1\nblah blah\n\npara 2\nblah blah\n"), "para 1 blah blah<p/>para 2 blah blah");
    is($plugin->escapeValue("para 1\nblah blah\n\npara 2\nblah blah\n\npara 3"), "para 1 blah blah<p/>para 2 blah blah<p/>para 3");
    is($plugin->escapeValue("para 1\r\nblah blah\r\n\r\npara 2\r\nblah blah\r\n\r\npara 3"), "para 1 blah blah<p/>para 2 blah blah<p/>para 3");

    is($plugin->escapeValue(<<END),
<div>
  outer 1
  outer 2
  <pre>
    pre 1
    pre 2
    <PRE>
      nested 1
      nested 2
    </PRE>
    pre 3
    pre 4
  </pre>
  outer 3
  outer 4
</div>
END
    '<div> '.
    '  outer 1 '.
    '  outer 2'.
      '<pre>'.
    '    pre 1<br/>'.
    '    pre 2'.
        '<pre>'.
    '      nested 1<br/>'.
    '      nested 2'.
        '</pre>'.
    '    pre 3<br/>'.
    '    pre 4'.
      '</pre>'.
    '  outer 3 '.
    '  outer 4 '.
    '</div>');
    
    # Vertical bars
    is($plugin->escapeValue('foo || bar'), 'foo &#124;&#124; bar');
    
    # Inline TML
    is($plugin->escapeValue('%var%'), '%var%');
    is($plugin->escapeValue('%plugin{"param"}%'), '%plugin{"param"}%');
    is($plugin->escapeValue('[[HyperLink]]'), '[[HyperLink]]');
    is($plugin->escapeValue('=Fixed font='), '=Fixed font=');
    is($plugin->escapeValue('_Italic_'), '_Italic_');
    is($plugin->escapeValue('*Bold*'), '*Bold*');
    is($plugin->escapeValue('__Bold italic__'), '__Bold italic__');
    is($plugin->escapeValue('==Bold fixed=='), '==Bold fixed==');
    is($plugin->escapeValue('!Escape'), '!Escape');
    is($plugin->escapeValue('$Variable'), '$Variable');
    
    # Line-oriented TML
    is($plugin->escapeValue(<<END),
---
---++
#Anchor
   * list
   1. list
   A. list
   a. list
   I. list
   i. list
   123. list
   \$ Sushi: Japan
   \$ Dim Sum: S.F.
END
    '--- '.
    '---++ '.
    '#Anchor '.
    '   * list '.
    '   1. list '.
    '   A. list '.
    '   a. list '.
    '   I. list '.
    '   i. list '.
    '   123. list '.
    '   $ Sushi: Japan '.
    '   $ Dim Sum: S.F.');
};

subtest plain_text => sub {
    plan tests => 17;
    
    my $plugin = TestPlugin->new(html => "off", tml => "on");
    
    is($plugin->escapeValue('0 &lt; x &lt; 100'), '0 &lt; x &lt; 100');
    is($plugin->escapeValue(' A B C '), '&nbsp;A B C&nbsp;');
    is($plugin->escapeValue('  A  B  C  '), '&nbsp;&nbsp;A&nbsp;&nbsp;B&nbsp;&nbsp;C&nbsp;&nbsp;');
    is($plugin->escapeValue("A\nB\nC\n"), 'A<br/>B<br/>C<br/>');
    is($plugin->escapeValue("\t123\t\n\t\t1234567\t123\n"), ('&nbsp;' x 8).'123'.('&nbsp;' x 5).'<br/>'.('&nbsp;' x 16).'1234567'.' '.'123'.'<br/>');
    
    # Vertical bars
    is($plugin->escapeValue('foo || bar'), 'foo &#124;&#124; bar');
    
    # Inline TML
    is($plugin->escapeValue('%var%'), '%var%');
    is($plugin->escapeValue('%plugin{"param"}%'), '%plugin{"param"}%');
    is($plugin->escapeValue('[[HyperLink]]'), '[[HyperLink]]');
    is($plugin->escapeValue('=Fixed font='), '=Fixed font=');
    is($plugin->escapeValue('_Italic_'), '_Italic_');
    is($plugin->escapeValue('*Bold*'), '*Bold*');
    is($plugin->escapeValue('__Bold italic__'), '__Bold italic__');
    is($plugin->escapeValue('==Bold fixed=='), '==Bold fixed==');
    is($plugin->escapeValue('!Escape'), '!Escape');
    is($plugin->escapeValue('$Variable'), '$Variable');

    # Line-oriented TML
    is($plugin->escapeValue(<<END),
---
---++
#Anchor
   * list
   1. list
   A. list
   a. list
   I. list
   i. list
   123. list
   \$ Sushi: Japan
   \$ Dim Sum: S.F.
END
    '---<br/>'.
    '---++<br/>'.
    '#Anchor<br/>'.
    '&nbsp;&nbsp;&nbsp;* list<br/>'.
    '&nbsp;&nbsp;&nbsp;1. list<br/>'.
    '&nbsp;&nbsp;&nbsp;A. list<br/>'.
    '&nbsp;&nbsp;&nbsp;a. list<br/>'.
    '&nbsp;&nbsp;&nbsp;I. list<br/>'.
    '&nbsp;&nbsp;&nbsp;i. list<br/>'.
    '&nbsp;&nbsp;&nbsp;123. list<br/>'.
    '&nbsp;&nbsp;&nbsp;$ Sushi: Japan<br/>'.
    '&nbsp;&nbsp;&nbsp;$ Dim Sum: S.F.<br/>');
};

subtest escape_tml => sub {
    plan tests => 12;
    
    my $plugin = TestPlugin->new(html => "on", tml => "off");
    
    # Vertical bars
    is($plugin->escapeValue('foo || bar'), 'foo &#124;&#124; bar');
    
    # Inline TML
    is($plugin->escapeValue('%var%'), '&#37;var&#37;');
    is($plugin->escapeValue('%plugin{"param"}%'), '&#37;plugin{"param"}&#37;');
    is($plugin->escapeValue('[[HyperLink]]'), '&#91;&#91;HyperLink&#93;&#93;');
    is($plugin->escapeValue('=Fixed font='), '&#61;Fixed font&#61;');
    is($plugin->escapeValue('_Italic_'), '&#95;Italic&#95;');
    is($plugin->escapeValue('*Bold*'), '&#42;Bold&#42;');
    is($plugin->escapeValue('__Bold italic__'), '&#95;&#95;Bold italic&#95;&#95;');
    is($plugin->escapeValue('==Bold fixed=='), '&#61;&#61;Bold fixed&#61;&#61;');
    is($plugin->escapeValue('!Escape'), '&#33;Escape');
    is($plugin->escapeValue('$Variable'), '&#36;Variable');
    
    # Line-oriented TML
    is($plugin->escapeValue(<<END),
---
---++
#Anchor
   * list
   1. list
   A. list
   a. list
   I. list
   i. list
   123. list
   \$ Sushi: Japan
   \$ Dim Sum: S.F.
END
    '--- '.
    '---++ '.
    '#Anchor '.
    '   * list '.
    '   1. list '.
    '   A. list '.
    '   a. list '.
    '   I. list '.
    '   i. list '.
    '   123. list '.
    '   &#36; Sushi: Japan '.
    '   &#36; Dim Sum: S.F.');
};

subtest raw => sub {
    plan tests => 12;
    
    my $plugin = TestPlugin->new(raw => "on");
    
    # Vertical bars
    is($plugin->escapeValue('foo || bar'), 'foo || bar');
    
    # Inline TML
    is($plugin->escapeValue('%var%'), '%var%');
    is($plugin->escapeValue('%plugin{"param"}%'), '%plugin{"param"}%');
    is($plugin->escapeValue('[[HyperLink]]'), '[[HyperLink]]');
    is($plugin->escapeValue('=Fixed font='), '=Fixed font=');
    is($plugin->escapeValue('_Italic_'), '_Italic_');
    is($plugin->escapeValue('*Bold*'), '*Bold*');
    is($plugin->escapeValue('__Bold italic__'), '__Bold italic__');
    is($plugin->escapeValue('==Bold fixed=='), '==Bold fixed==');
    is($plugin->escapeValue('!Escape'), '!Escape');
    is($plugin->escapeValue('$Variable'), '$Variable');
    
    # Line-oriented TML
    is($plugin->escapeValue(<<END),
---
---++
#Anchor
   * list
   1. list
   A. list
   a. list
   I. list
   i. list
   123. list
   \$ Sushi: Japan
   \$ Dim Sum: S.F.
END
    <<END);
---
---++
#Anchor
   * list
   1. list
   A. list
   a. list
   I. list
   i. list
   123. list
   \$ Sushi: Japan
   \$ Dim Sum: S.F.
END
};

subtest raw_xml => sub {
    plan tests => 1;
    
    my $plugin = TestPlugin->new(raw => "xml");
    
    is($plugin->escapeValue(<<END),
<xml>
  <a>a || b</a>
  <b>%b%</b>
  <c id="0">*c*</c>
  &lt;d&gt;d&lt;/d&gt;
</xml>
END
    <<END);
<xml>
  <a>a || b</a>
  <b>%b%</b>
  <c id="0">*c*</c>
  &lt;d&gt;d&lt;/d&gt;
</xml>
END
};
