use strict;

# tests for the two translators, TML to HTML and HTML to TML, that
# support editing using WYSIWYG HTML editors. The tests are designed
# so that the round trip can be verified in as many cases as possible.
# Readers are invited to add more testcases.

package TranslatorTests;

use base qw(Test::Unit::TestCase);

BEGIN {
    unshift(@INC,'/home/twiki/cairo/lib');
    unshift(@INC,'../../../..');
}

use TWiki;
use TWiki::Plugins::WysiwygPlugin::TML2HTML;
use TWiki::Plugins::WysiwygPlugin::HTML2TML;
use Carp;
$SIG{__DIE__} = sub { Carp::confess $_[0] };

my $unsafe;
BEGIN {
    for( my $i = 0; $i < 32; $i++) {
        $unsafe .= chr($i) unless $i == 10;
    }

    if( defined &TWiki::setupRegexes ) {
        TWiki::setupRegexes();
    } else {
        print STDERR "Warning: running on DEVELOP?\n";
    }
}

BEGIN {
    # The following big table contains all the testcases. These are
    # used to add a bunch of functions to the symbol table of this
    # testcase, so they get picked up and run by TestRunner.

    # Each testcase is a subhash with fields as follows:
    # exec => 1 to test TML -> HTML, 2 to test HTML -> TML, 3 to
    # test both, anything else to skin the test.
    # name => identifier (used to compose the testcase function name)
    # tml => source TWiki meta-language
    # html => expected html from expanding tml
    # finaltml => optional expected tml from translating html. If not there,
    # will use tml. Only use where round-trip can't be closed because
    # we are testing deprecated syntax.

    my $data =
      [
       {
        exec => 3,
        name => 'linkAtStart',
        tml => 'LinkAtStart',
        html => '<a href="page:/Current/LinkAtStart">LinkAtStart</a>'
       },
       {
        exec => 3,
        name => 'otherWebLinkAtStart',
        tml => 'OtherWeb.LinkAtStart',
        html => '<a href="page:/OtherWeb/LinkAtStart">LinkAtStart</a>',
       },
       {
        exec => 3,
        name => 'currentWebLinkAtStart',
        tml => 'Current.LinkAtStart',
        html => '<a href="page:/Current/LinkAtStart">LinkAtStart</a>',
        finaltml => 'LinkAtStart'
       },
       {
        exec => 3,
        name => 'simpleParas',
        html => '1st paragraph<p />2nd paragraph',
        tml => '1st paragraph

2nd paragraph'
       },
       {
        exec => 3,
        name => 'headings',
        html => '<h2 class="TML"> Sushi</h2><h3 class="TML"> Maguro</h3>',
        tml => '---++ Sushi
---+++ Maguro'
       },
       {
        exec => 3,
        name => 'simpleStrong',
        html => '<strong>Bold</strong>',
        tml => '*Bold*
'
       },
       {
        exec => 3,
        name => 'strongLink',
        html => '<strong>reminded about<a href="http://www.koders.com">http://www.koders.com</a></strong>',
        tml => '*reminded about http://www.koders.com*',
        finaltml => '*reminded about http://www.koders.com*',
       },
       {
        exec => 3,
        name => 'simpleItalic',
        html => '<em>Italic</em>',
        tml => '_Italic_',
       },
       {
        exec => 3,
        name => 'boldItalic',
        html => '<strong><em>Bold italic</em></strong>',
        tml => '__Bold italic__',
       },
       {
        exec => 3,
        name => 'simpleCode',
        html => '<code>Code</code>',
        tml => '=Code='
       },
       {
        exec => 3,
        name => 'strongCode',
        html => '<strong><code>Bold Code</code></strong>',
        tml => '==Bold Code=='
       },
       {
        exec => 3,
        name => 'mixtureOfFormats',
        html => '<em>this</em><em>should</em><em>italicise</em><em>each</em><em>word</em><p /><strong>and</strong><strong>this</strong><strong>should</strong><strong>embolden</strong><strong>each</strong><strong>word</strong><p /><em>mixing</em><strong>them</strong><em>should</em><strong>work</strong>',
        tml => '_this_ _should_ _italicise_ _each_ _word_

*and* *this* *should* *embolden* *each* *word*

_mixing_ *them* _should_ *work*
',
       },
       {
        exec => 3,
        name => 'simpleVerbatim',
        html => '<pre class="TMLverbatim">
&#60;verbatim&#62;
Description
&#60;/verbatim&#62;
class CatAnimal {
  void purr() {
    code &#60;here&#62;
  }
}
</pre>',
        tml => '<verbatim>
<verbatim>
Description
</verbatim>
class CatAnimal {
  void purr() {
    code <here>
  }
}
</verbatim>
'
       },
       {
        exec => 3,
        name => 'simpleHR',
        html => '<hr /><hr />--',
        tml => '---
-------
--
',
        finaltml => '---
---
--
'
       },
       {
        exec => 3,
        name => 'simpleBullList',
        html => '<ul><li>bullet item</li></ul>',
        tml => '	* bullet item
',
       },
       {
        exec => 3,
        name => 'multiLevelBullList',
        html => 'X
<ul><li>level 1
<ul><li>level 2</li></ul></li></ul>',
        tml => 'X
   * level 1
      * level 2
',
        finaltml => 'X
	* level 1 
		* level 2 ',
       },
       {
        exec => 3,
        name => 'orderedList',
        html => '<ol><li>Sushi</li></ol><p /><ol>
<li type="A">Sushi</li></ol><p />
<ol><li type="i">Sushi</li></ol><p />
<ol><li>Sushi</li><li type="A">Sushi</li><li type="i">Sushi</li></ol>',
        tml => '	1 Sushi

	A. Sushi

	i. Sushi

	1 Sushi
	A. Sushi
	i. Sushi
',
       },
       {
        exec => 3,
        name => 'mixedList',
        html => '<ol><li>Things</li><li>Stuff
<ul><li>Banana Stuff</li><li>Other</li><li></li></ul></li><li>Something</li><li>kello<br />kitty</li></ol>',
        tml => '	1 Things
	1 Stuff 
		* Banana Stuff
		* Other
		* 
	1 Something
	1 kello<br />kitty
',
       },
       {
        exec => 3,
        name => 'definitionList',
        html => '<dl><dt>Sushi</dt><dd>Japan</dd><dt>Dim Sum</dt><dd>S. F.</dd><dt>Sauerkraut</dt><dd>Germany</dd></dl>',
        tml => '   $ Sushi: Japan
	$ Dim Sum: S. F.
	Sauerkraut: Germany
',
        finaltml => '   Sushi: Japan
	$ Dim Sum: S. F.
	Sauerkraut: Germany
',
       },
       {
        exec => 3,
        name => 'simpleTable',
        html => '<p /><table><tr><th>L</th><th>C</th><th>R</th></tr><tr><td>A2</td><td align="center">2</td><td align="right">2</td></tr><tr><td>A3</td><td align="center">3</td><td align="left">3</td></tr><tr><td colspan="3">multi span</td></tr><tr><td>A4-6</td><td>four</td><td>four</td></tr><tr><td>^</td><td>five</td><td>five</td></tr></table><p /><table><tr><td>^</td><td>six</td><td>six</td></tr></table>',
        tml => '
| *L* | *C* | *R* |
| A2 |  2  |  2 |
| A3 |  3  | 3  |
| multi span |||
| A4-6 | four | four |
|^| five | five |

|^| six | six |
',
        finaltml => '
|*L*|*C*|*R*|
|A2|  2  |  2|
|A3|  3  |3  |
|multi span|||
|A4-6|four|four|
|^|five|five|

|^|six|six|'
       },
       {
        exec => 3,
        name => 'noppedWikiword',
        html => '<span class="TMLnop">X</span>SunOS',
        tml => '!SunOS',
        finaltml => '<nop>SunOS',
       },
       {
        exec => 3,
        name => 'noAutoLunk',
        html => '<div class="TMLnoautolink">RedHat & SuSE</div>
',
        tml => '<noautolink>
RedHat & SuSE
</noautolink>'
       },
       {
        exec => 3,
        name => 'mailtoLink',
        html => '<a href="mailto:a@z.com">Mail</a><a href="mailto:?subject=Hi">Hi</a>',
        tml => '[[mailto:a@z.com Mail]] [[mailto:?subject=Hi Hi]]',
        finaltml => '[[mailto:a@z.com][Mail]] [[mailto:?subject=Hi][Hi]]',
       },
       {
        exec => 3,
        name => 'variousWikiWords',
        html => '<a href="page:/Current/WebPreferences">WebPreferences</a><p /><span class="TMLvariable">MAINWEB</span>.TWikiUsers<p /><a href="page:/Current/CompleteAndUtterNothing">CompleteAndUtterNothing</a><p /><a href="page:/Current/LinkBox">LinkBox</a><a href="page:/Current/LinkBoxs">LinkBoxs</a><a href="page:/Current/LinkBoxies">LinkBoxies</a><a href="page:/Current/LinkBoxess">LinkBoxess</a><a href="page:/Current/LinkBoxesses">LinkBoxesses</a><a href="page:/Current/LinkBoxes">LinkBoxes</a>',
        tml => 'WebPreferences

%MAINWEB%.TWikiUsers

CompleteAndUtterNothing

LinkBox
LinkBoxs
LinkBoxies
LinkBoxess
LinkBoxesses
LinkBoxes
',
        finaltml => 'WebPreferences

%MAINWEB%.TWikiUsers

CompleteAndUtterNothing

LinkBox LinkBoxs LinkBoxies LinkBoxess LinkBoxesses LinkBoxes',
       },
       {
        exec => 3,
        name => 'squabsWithVars',
        html => '<a href="page:/Current/WikiSyntax">wiki syntax</a><a href="&#37;MAINWEB&#37;.TWiki users"><span class="TMLvariable">MAINWEB</span>.TWiki users</a>escaped: [<span class="TMLnop">X</span>[wiki syntax]]',
        tml => '[[wiki syntax]] [[%MAINWEB%.TWiki users]]
escaped:
![[wiki syntax]]',
        finaltml => '[[WikiSyntax][wiki syntax]] <a href="%MAINWEB%.TWiki users">%MAINWEB%.TWiki users</a>escaped: [<nop>[wiki syntax]]'
       },
       {
        exec => 3,
        name => 'squabsWithWikiWordsAndLink',
        html => '<a href="page:/Current/WikiSyntax">syntax</a><a href="http://gnu.org">GNU</a><a href="http://xml.org">XML</a>',
        tml => '[[WikiSyntax][syntax]] [[http://gnu.org][GNU]] [[http://xml.org][XML]]',
       },
       {
        exec => 3,
        name => 'squabWithAnchor',
        html => '<a href="page:/Current/FleegleHorn#TrumpetHack">FleegleHorn#TrumpetHack</a>',
        tml => 'FleegleHorn#TrumpetHack'
       },
       {
        exec => 3,
        name => 'plingedVarOne',
        html => '&#37;<span class="TMLnop">X</span>MAINWEB&#37;nowt',
        tml => '!%MAINWEB%nowt',
        finaltml => '%<nop>MAINWEB%nowt'
       },
       {
        exec => 3,
        name => 'plingedVarTwo',
        html => 'nowt!<span class="TMLvariable">MAINWEB</span>',
        tml => 'nowt!%MAINWEB%',
       },
       {
        exec => 3,
        name => 'WEBvar',
        html => '<span class="TMLvariable">WEB</span>',
        tml => '%WEB%'
       },
       {
        exec => 3,
        name => 'ICONvar1',
        html => '<span class="TMLvariable">ICON{}</span>',
        tml => '%ICON{}%'
       },
       {
        exec => 3,
        name => 'ICONvar2',
        html => '<span class="TMLvariable">ICON{""}</span>',
        tml => '%ICON{""}%'
       },
       {
        exec => 3,
        name => 'ICONvar3',
        html => '<span class="TMLvariable">ICON{"Fleegle"}</span>',
        tml => '%ICON{"Fleegle"}%'
       },
       {
        exec => 3,
        name => 'URLENCODEvar',
        html => '<span class="TMLvariable">URLENCODE{""}</span>',
        tml => '%URLENCODE{""}%'
       },
       {
        exec => 3,
        name => 'ENCODEvar',
        html => '<span class="TMLvariable">ENCODE{""}</span>',
        tml => '%ENCODE{""}%'
       },
       {
        exec => 3,
        name => 'INTURLENCODEvar',
        html => '<span class="TMLvariable">INTURLENCODE{""}</span>',
        tml => '%INTURLENCODE{""}%'
       },
       {
        exec => 3,
        name => 'MAINWEBvar',
        html => '<span class="TMLvariable">MAINWEB</span>',
        tml => '%MAINWEB%'
       },
       {
        exec => 3,
        name => 'TWIKIWEBvar',
        html => '<span class="TMLvariable">TWIKIWEB</span>',
        tml => '%TWIKIWEB%'
       },
       {
        exec => 3,
        name => 'HOMETOPICvar',
        html => '<span class="TMLvariable">HOMETOPIC</span>',
        tml => '%HOMETOPIC%'
       },
       {
        exec => 3,
        name => 'WIKIUSERSTOPICvar',
        html => '<span class="TMLvariable">WIKIUSERSTOPIC</span>',
        tml => '%WIKIUSERSTOPIC%'
       },
       {
        exec => 3,
        name => 'WIKIPREFSTOPICvar',
        html => '<span class="TMLvariable">WIKIPREFSTOPIC</span>',
        tml => '%WIKIPREFSTOPIC%'
       },
       {
        exec => 3,
        name => 'WEBPREFSTOPICvar',
        html => '<span class="TMLvariable">WEBPREFSTOPIC</span>',
        tml => '%WEBPREFSTOPIC%'
       },
       {
        exec => 3,
        name => 'NOTIFYTOPICvar',
        html => '<span class="TMLvariable">NOTIFYTOPIC</span>',
        tml => '%NOTIFYTOPIC%'
       },
       {
        exec => 3,
        name => 'STATISTICSTOPICvar',
        html => '<span class="TMLvariable">STATISTICSTOPIC</span>',
        tml => '%STATISTICSTOPIC%'
       },
       {
        exec => 3,
        name => 'STARTINCLUDEvar',
        html => '<span class="TMLvariable">STARTINCLUDE</span>',
        tml => '%STARTINCLUDE%'
       },
       {
        exec => 3,
        name => 'STOPINCLUDEvar',
        html => '<span class="TMLvariable">STOPINCLUDE</span>',
        tml => '%STOPINCLUDE%'
       },
       {
        exec => 3,
        name => 'SECTIONvar',
        html => '<span class="TMLvariable">SECTION{""}</span>',
        tml => '%SECTION{""}%'
       },
       {
        exec => 3,
        name => 'ENDSECTIONvar',
        html => '<span class="TMLvariable">ENDSECTION</span>',
        tml => '%ENDSECTION%'
       },
       {
        exec => 3,
        name => 'FORMFIELDvar1',
        html => '<span class="TMLvariable">FORMFIELD{"" topic="" alttext="" default="" format="$value"}</span>',
        tml => '%FORMFIELD{"" topic="" alttext="" default="" format="$value"}%'
       },
       {
        exec => 3,
        name => 'FORMFIELDvar2',
        html => '<span class="TMLvariable">FORMFIELD{"TopicClassification" topic="" alttext="" default="" format="$value"}</span>',
        tml => '%FORMFIELD{"TopicClassification" topic="" alttext="" default="" format="$value"}%'
       },
       {
        exec => 3,
        name => 'SPACEDTOPICvar',
        html => '<span class="TMLvariable">SPACEDTOPIC</span>',
        tml => '%SPACEDTOPIC%'
       },
       {
        exec => 3,
        name => 'RELATIVETOPICPATHvar1',
        html => '<span class="TMLvariable">RELATIVETOPICPATH{}</span>',
        tml => '%RELATIVETOPICPATH{}%'
       },
       {
        exec => 3,
        name => 'RELATIVETOPICPATHvar2',
        html => '<span class="TMLvariable">RELATIVETOPICPATH{Sausage}</span>',
        tml => '%RELATIVETOPICPATH{Sausage}%'
       },
       {
        exec => 3,
        name => 'RELATIVETOPICPATHvar3',
        html => '<span class="TMLvariable">RELATIVETOPICPATH{"Chips"}</span>',
        tml => '%RELATIVETOPICPATH{"Chips"}%'
       },
       {
        exec => 3,
        name => 'SCRIPTNAMEvar',
        html => '<span class="TMLvariable">SCRIPTNAME</span>',
        tml => '%SCRIPTNAME%'
       },
       {
        exec => 3,
        name => 'nestedVerbatim',
        html => 'Outside<pre class="TMLverbatim">Inside</pre>Outside',
        tml => 'Outside
<verbatim>
Inside
</verbatim>
Outside',
       },
       {
        exec => 3,
        name => 'nestedPre',
        html => 'Outside<pre class="twikiAlert TMLverbatim">Inside</pre>Outside',
        tml => 'Outside
<verbatim class="twikiAlert">
Inside
</verbatim>
Outside
',
       },
       {
        exec => 3,
        name => 'nestedIndentedVerbatim',
        html => 'Outside<pre class="TMLverbatim">Inside</pre>Outside',
        tml => 'Outside
   <verbatim>
Inside
   </verbatim>
Outside
',
        finaltml => 'Outside
<verbatim>
Inside
</verbatim>
Outside
',
       },
       {
        exec => 3,
        name => 'nestedIndentedPre',
        html => 'Outside<pre>Inside</pre>Outside',
        tml => 'Outside
<pre>
Inside
</pre>
Outside',
       },
       {
        exec => 3,
        name => 'classifiedPre',
        html => 'Outside<pre class="twikiAlert">Inside</pre>Outside',
        tml => 'Outside
<pre class="twikiAlert">
Inside
</pre>
Outside',
       },
       {
        exec => 3,
        name => 'indentedPre',
        html => 'Outside<pre>Inside</pre>Outside',
        tml => 'Outside
   <pre>
Inside
   </pre>
Outside',
        finaltml => 'Outside
<pre>
Inside
</pre>
Outside',
       },
       {
        exec => 3,
        name => 'NAL',
        html => 'Outside<div class="TMLnoautolink">Inside</div>Outside',
        tml => 'Outside
<noautolink>
Inside
</noautolink>
Outside',
       },
       {
        exec => 3,
        name => 'classifiedNAL',
        html => 'Outside<div class="twikiAlert TMLnoautolink">Inside</div>Outside',
        tml => 'Outside
<noautolink class="twikiAlert">
Inside
</noautolink>
Outside',
       },
       {
        exec => 3,
        name => 'indentedNAL',
        html => 'Outside<div class="TMLnoautolink">Inside</div>Outside',
        tml => 'Outside
   <noautolink>
Inside
   </noautolink>
Outside
',
        finaltml => 'Outside
<noautolink>
Inside
</noautolink>
Outside
',
       },
       {
        exec => 3,
        name => 'linkInHeader',
        html => '<h3 class="TML"> Test with<a href="page:/Current/LinkInHeader">LinkInHeader</a></h3>',
        tml => '---+++ Test with LinkInHeader
',
       },
       {
        exec => 2,
        name => 'doctype',
        html => '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">',
        tml => '',
       },
       {
        exec => 2,
        name => 'head',
        html => '<head> ignore me </head>',
        tml => '',
       },
       {
        exec => 2,
        name => 'htmlAndBody',
        html => '<html> good <body>good </body></html>',
        tml => 'good good',
       },
       {
        exec => 2,
        name => 'kupuTable',
        html => '<table cellspacing="0" cellpadding="8" border="1" class="plain" _moz_resizing="true">
<tbody>
<tr>a0<td>a1</td><td>a2</td><td>a3</td></tr>
<tr>b0<td>b1</td><td>b2</td><td>b3</td></tr>
<tr>c0<td>c1</td><td>c2</td><td>c3</td></tr>
</tbody>
</table>',
        tml => '|a1|a2|a3|
|b1|b2|b3|
|c1|c2|c3|
',
       },
       {
        exec => 3,
        name => 'NOP',
        html => '<span class="TMLnop">X</span>WysiwygEditor',
        tml => '<nop>WysiwygEditor',
       },

       {
        exec => 2,
        name=>"images",
        html=>'<img src="test_image" />',
        tml => 'egami_tset'
       },

       {
        exec => 3,
        name=>"TWikiTagsInHTMLParam",
        html=>'<a href="&#37;SCRIPTURL&#37;/view&#37;SCRIPTSUFFIX&#37;"></a>'.
        "<a href='&#37;SCRIPTURL&#37;/view&#37;SCRIPTSUFFIX&#37;'></a>",
        tml => '<a href="%SCRIPTURL%/view%SCRIPTSUFFIX%"></a>'.
        "<a href='%SCRIPTURL%/view%SCRIPTSUFFIX%'></a>",
        finaltml => '<a href="%SCRIPTURL%/view%SCRIPTSUFFIX%"></a>'.
        '<a href="%SCRIPTURL%/view%SCRIPTSUFFIX%"></a>',
       },

      ];


    foreach my $datum ( @$data ) {
        next unless( $datum->{exec} & 1 );
        my $fn = 'TranslatorTests::test_TML2HTML_'.$datum->{name};
        no strict 'refs';
        *$fn = sub { shift->compareTML_HTML( $datum ) };
        use strict 'refs';
    }

    foreach my $datum ( @$data ) {
        next unless( $datum->{exec} & 2 );
        my $fn = 'TranslatorTests::test_HTML2TML_'.$datum->{name};
        no strict 'refs';
        *$fn = sub { shift->compareHTML_TML( $datum ) };
        use strict 'refs';
    }

    opendir( D, "test_html" ) or die;
    foreach my $file (grep { /^.*\.html$/i } readdir D ) {
        $file =~ s/\.html$//;
        next unless -e "result_tml/$file.txt";
        my $test = { name => $file };
        open(F, "<test_html/$file.html");
        undef $/;
        $test->{html} = <F>;
        close(F);
        open(F, "<result_tml/$file.txt");
        undef $/;
        $test->{finaltml} = <F>;
        close(F);
        my $fn = 'TranslatorTests::test_HTML2TML_FILE_'.$test->{name};
        no strict 'refs';
        *$fn = sub { shift->compareHTML_TML( $test ) };
        use strict 'refs';
    }

}

use HTML::Diff;

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

sub normaliseEntities {
    my $text = shift;
    $text = HTML::Entities::decode_entities($text);
    $text = HTML::Entities::encode_entities
      ($text, "\000\001\002\003\004\005\006\007\010\013\014\015");
    $text = HTML::Entities::encode_entities($text,"\016-\037");
    $text = HTML::Entities::encode_entities($text,"\200-\377");
    return $text;
}

sub _compareHTML {
    my ( $this, $expected, $actual ) = @_;

    my $result = '';
    $expected = normaliseEntities($expected);
    $expected =~ s/ +/ /gs;
    $expected =~ s/^\s+//s;
    $expected =~ s/\s+$//s;
    $expected =~ s/\s+</</g;
    $expected =~ s/>\s+/>/g;

    $actual = normaliseEntities($expected);
    $actual =~ s/ +/ /gs;
    $actual =~ s/^\s+//s;
    $actual =~ s/\s+$//s;
    $actual =~ s/\s+</</g;
    $actual =~ s/>\s+/>/g;

    my $diffs = HTML::Diff::html_word_diff( $expected, $actual );
    my $failed = 0;
    my $okset = "";

    foreach my $diff ( @$diffs ) {
        my $a = $diff->[1];
        $a =~ s/^\s+//;
        $a =~ s/\s+$//s;
        my $b = $diff->[2];
        $b =~ s/^\s+//;
        $b =~ s/\s+$//s;
        my $ok = 0;

        if ( $diff->[0] eq 'u' || $a eq $b || _tagSame($a, $b)) {
            $ok = 1;
        }
        if ( $ok ) {
            $okset .= "$a ";
        } else {
            if( $okset ) {
                $result .= "OK: $okset\n";
                $okset = "";
            }
            $result .= "***** Expected HTML: ".encode($a).
              "\n***** Actual HTML: ".encode($b)."\n";
            $failed = 1;
        }
    }
    return '' unless $failed;
    if( $okset ) {
        $result .= "OK: $okset\n";
    }
    $this->assert(0, "Match failed\n$result");
}

sub _tagSame {
    my( $a, $b ) = @_;

    return 0 unless ($a =~ /^\s*<\/?(\w+)\s+(.*?)>\s*$/i);
    my $tag = $1;
    my $pa = $2;
    return 0 unless $b =~  /^\s*<\/?$tag\s+(.*?)>\s*$/i;
    my $pb = $1;
    return _paramsSame($pa, $pb);
}

sub _paramsSame {
    my( $a, $b) = @_;
    return 1 if ($a eq $b);
    while( $a =~ s/^\s*([a-zA-Z]+)=["'](.*?)["']// ) {
        my( $x, $y) = ($1, $2);
        $y =~ s/(\W)/\\$1/g;
        return 0 unless $b =~ s/\b${x}=["']${y}["']//;
    }
    $a =~ s/^\s*//;
    $b =~ s/^\s*//;
    return $b eq $a;
}

sub compareTML_HTML {
    my ( $this, $args ) = @_;
    my $txer = new TWiki::Plugins::WysiwygPlugin::TML2HTML(\&getViewUrl);
    my $tx = $txer->convert( $args->{tml} );
    $this->_compareHTML($args->{html}, $tx, 1);
}

sub compareHTML_TML {
    my ( $this, $args ) = @_;
    my $txer = new TWiki::Plugins::WysiwygPlugin::HTML2TML
      ( { parseWikiUrl => \&parseWikiUrl,
          convertImage => \&convertImage } );
    my $tx = $txer->convert( $args->{html} );
    if( $args->{finaltml} ) {
        $this->_compareTML($args->{finaltml}, $tx, $args->{name});
    } else {
        $this->_compareTML($args->{tml}, $tx, $args->{name});
    }
}

sub encode {
    my $s = shift;

#    $s =~ s/([\000-\037])/'#'.ord($1)/ge;
    return $s;
}

sub _compareTML {
    my( $this, $expected, $actual, $name ) = @_;

    $expected = TWiki::Plugins::WysiwygPlugin::HTML2TML::Node::_trim($expected);
    $actual = TWiki::Plugins::WysiwygPlugin::HTML2TML::Node::_trim($actual);
    unless( $expected eq $actual ) {
        my $expl =
            "==$name== Expected TML:\n".encode($expected).
                "\n==$name== Actual TML:\n".encode($actual).
                      "\n==$name==\n";
        my $i = 0;
        while( $i < length($expected) && $i < length($actual)) {
            my $e = substr($expected,$i,1);
            my $a = substr($actual,$i,1);
            if( $a ne $e) {
                $expl .= "<<==== HERE ";
                $expl .= ord($a)."!=".ord($e)."\n";
                last;
            }
            $expl .= $a;
            $i++;
        }
        $this->assert(0, $expl."\n");
    }
}

sub getViewUrl {
    my( $web, $topic ) = @_;
    $web ||= "Current";
    return "page:/$web/$topic";
}

sub parseWikiUrl {
    my $url = shift;
    if( $url =~ m!^page:/(\w+)/(\w+(#\w+)?)$! ) {
        my($web,$topic)=($1,$2);
        if( $web eq 'Current' ) {
          return $topic;
      } else {
          return "$web.$topic";
      }
    }
    return undef;
}

sub convertImage {
    my $url = shift;

    if ($url eq "test_image") {
        return "egami_tset";
    }
}

1;
