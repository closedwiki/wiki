use strict;

# tests for the two translators, TML to HTML and HTML to TML, that
# support editing using WYSIWYG HTML editors. The tests are designed
# so that the round trip can be verified in as many cases as possible.
# Readers are invited to add more testcases.

package TranslatorTests;

use base qw(Test::Unit::TestCase);

BEGIN {
    unshift(@INC,'../../../..');
    unshift(@INC,'/home/twiki/cairo/lib');
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
        name => 0,
        tml => 'LinkAtStart',
        html => '<a href="page:/Current/LinkAtStart">LinkAtStart</a>'
       },
       {
        exec => 3,
        name => 191,
        tml => 'OtherWeb.LinkAtStart',
        html => '<a href="page:/OtherWeb/LinkAtStart">LinkAtStart</a>',
       },
       {
        exec => 3,
        name => 192,
        tml => 'Current.LinkAtStart',
        html => '<a href="page:/Current/LinkAtStart">LinkAtStart</a>',
        finaltml => 'LinkAtStart'
       },
       {
        exec => 3,
        name => 1,
        html => '1st paragraph<p />2nd paragraph',
        tml => '1st paragraph

2nd paragraph'
       },
       {
        exec => 3,
        name => 1,
        html => '<h2 class="TML"> Sushi</h2><h3 class="TML"> Maguro</h3>',
        tml => '---++ Sushi
---+++ Maguro'
       },
       {
        exec => 3,
        name => 3,
        html => '<strong>Bold</strong>',
        tml => '*Bold*
'
       },
       {
        exec => 3,
        name => 4,
        html => '<strong>reminded about<a href="http://www.koders.com">http://www.koders.com</a></strong>',
        tml => '*reminded about http://www.koders.com*',
        finaltml => '*reminded about http://www.koders.com*',
       },
       {
        exec => 3,
        name => 5,
        html => '<em>Italic</em>',
        tml => '_Italic_',
       },
       {
        exec => 3,
        name => 6,
        html => '<strong><em>Bold italic</em></strong>',
        tml => '__Bold italic__',
       },
       {
        exec => 3,
        name => 7,
        html => '<code>Code</code>',
        tml => '=Code='
       },
       {
        exec => 3,
        name => 8,
        html => '<strong><code>Bold Code</code></strong>',
        tml => '==Bold Code=='
       },
       {
        exec => 3,
        name => 9,
        html => '<em>this</em><em>should</em><em>italicise</em><em>each</em><em>word</em><p /><strong>and</strong><strong>this</strong><strong>should</strong><strong>embolden</strong><strong>each</strong><strong>word</strong><p /><em>mixing</em><strong>them</strong><em>should</em><strong>work</strong>',
        tml => '_this_ _should_ _italicise_ _each_ _word_

*and* *this* *should* *embolden* *each* *word*

_mixing_ *them* _should_ *work*
',
       },
       {
        exec => 3,
        name => 10,
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
        name => 11,
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
        name => 12,
        html => '<ul><li>bullet item</li></ul>',
        tml => '	* bullet item
',
       },
       {
        exec => 3,
        name => 13,
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
        name => 14,
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
        name => 15,
        html => '<ol><li>Things</li><li>Stuff
<ul><li>Banana Stuff</li><li>Other</li><li></li></ul></li><li>Something</li><li>kello<br />kitty</li></ol>',
        tml => '   1 Things
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
        name => 16,
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
        name => 17,
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
        name => 18,
        html => '!SunOS',
        tml => '!SunOS',
       },
       {
        exec => 3,
        name => 19,
        html => '<div class="TMLnoautolink">RedHat & SuSE</div>
',
        tml => '<noautolink>
RedHat & SuSE
</noautolink>'
       },
       {
        exec => 3,
        name => 20,
        html => '<a href="mailto:a@z.com">Mail</a><a href="mailto:?subject=Hi">Hi</a>',
        tml => '[[mailto:a@z.com Mail]] [[mailto:?subject=Hi Hi]]',
        finaltml => '[[mailto:a@z.com][Mail]] [[mailto:?subject=Hi][Hi]]',
       },
       {
        exec => 3,
        name => 21,
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
        name => 22,
        html => '<a href="page:/Current/WikiSyntax">wiki syntax</a><a href="%MAINWEB%.TWikiUsers"><span class="TMLvariable">MAINWEB</span>.TWiki users</a>escaped: ![[wiki syntax]]',
        tml => '[[wiki syntax]] [[%MAINWEB%.TWiki users]]
escaped:
![[wiki syntax]]',
        finaltml => '[[WikiSyntax][wiki syntax]] [[%MAINWEB%.TWikiUsers][%MAINWEB%.TWiki users]] escaped: ![[wiki syntax]]'
       },
       {
        exec => 3,
        name => 23,
        html => '<a href="page:/Current/WikiSyntax">syntax</a><a href="http://gnu.org">GNU</a><a href="http://xml.org">XML</a>',
        tml => '[[WikiSyntax][syntax]] [[http://gnu.org][GNU]] [[http://xml.org][XML]]',
       },
       {
        exec => 3,
        name => 24,
        html => '<a href="page:/Current/FleegleHorn#TrumpetHack">FleegleHorn#TrumpetHack</a>',
        tml => 'FleegleHorn#TrumpetHack'
       },
       {
        exec => 3,
        name => 25,
        html => '!<span class="TMLvariable">MAINWEB</span>nowt',
        tml => '!%MAINWEB%nowt',
       },
       {
        exec => 3,
        name => 26,
        html => 'nowt!<span class="TMLvariable">MAINWEB</span>',
        tml => 'nowt!%MAINWEB%',
       },
       {
        exec => 3,
        name => 28,
        html => '<span class="TMLvariable">WEB</span>',
        tml => '%WEB%'
       },
       {
        exec => 3,
        name => 29,
        html => '<span class="TMLvariable">ICON{}</span>',
        tml => '%ICON{}%'
       },
       {
        exec => 3,
        name => 30,
        html => '<span class="TMLvariable">ICON{""}</span>',
        tml => '%ICON{""}%'
       },
       {
        exec => 3,
        name => 31,
        html => '<span class="TMLvariable">ICON{"Fleegle"}</span>',
        tml => '%ICON{"Fleegle"}%'
       },
       {
        exec => 3,
        name => 32,
        html => '<span class="TMLvariable">URLENCODE{""}</span>',
        tml => '%URLENCODE{""}%'
       },
       {
        exec => 3,
        name => 33,
        html => '<span class="TMLvariable">ENCODE{""}</span>',
        tml => '%ENCODE{""}%'
       },
       {
        exec => 3,
        name => 34,
        html => '<span class="TMLvariable">INTURLENCODE{""}</span>',
        tml => '%INTURLENCODE{""}%'
       },
       {
        exec => 3,
        name => 35,
        html => '<span class="TMLvariable">MAINWEB</span>',
        tml => '%MAINWEB%'
       },
       {
        exec => 3,
        name => 36,
        html => '<span class="TMLvariable">TWIKIWEB</span>',
        tml => '%TWIKIWEB%'
       },
       {
        exec => 3,
        name => 37,
        html => '<span class="TMLvariable">HOMETOPIC</span>',
        tml => '%HOMETOPIC%'
       },
       {
        exec => 3,
        name => 38,
        html => '<span class="TMLvariable">WIKIUSERSTOPIC</span>',
        tml => '%WIKIUSERSTOPIC%'
       },
       {
        exec => 3,
        name => 39,
        html => '<span class="TMLvariable">WIKIPREFSTOPIC</span>',
        tml => '%WIKIPREFSTOPIC%'
       },
       {
        exec => 3,
        name => 40,
        html => '<span class="TMLvariable">WEBPREFSTOPIC</span>',
        tml => '%WEBPREFSTOPIC%'
       },
       {
        exec => 3,
        name => 41,
        html => '<span class="TMLvariable">NOTIFYTOPIC</span>',
        tml => '%NOTIFYTOPIC%'
       },
       {
        exec => 3,
        name => 42,
        html => '<span class="TMLvariable">STATISTICSTOPIC</span>',
        tml => '%STATISTICSTOPIC%'
       },
       {
        exec => 3,
        name => 43,
        html => '<span class="TMLvariable">STARTINCLUDE</span>',
        tml => '%STARTINCLUDE%'
       },
       {
        exec => 3,
        name => 44,
        html => '<span class="TMLvariable">STOPINCLUDE</span>',
        tml => '%STOPINCLUDE%'
       },
       {
        exec => 3,
        name => 45,
        html => '<span class="TMLvariable">SECTION{""}</span>',
        tml => '%SECTION{""}%'
       },
       {
        exec => 3,
        name => 46,
        html => '<span class="TMLvariable">ENDSECTION</span>',
        tml => '%ENDSECTION%'
       },
       {
        exec => 3,
        name => 47,
        html => '<span class="TMLvariable">FORMFIELD{"" topic="" alttext="" default="" format="$value"}</span>',
        tml => '%FORMFIELD{"" topic="" alttext="" default="" format="$value"}%'
       },
       {
        exec => 3,
        name => 48,
        html => '<span class="TMLvariable">FORMFIELD{"TopicClassification" topic="" alttext="" default="" format="$value"}</span>',
        tml => '%FORMFIELD{"TopicClassification" topic="" alttext="" default="" format="$value"}%'
       },
       {
        exec => 3,
        name => 49,
        html => '<span class="TMLvariable">SPACEDTOPIC</span>',
        tml => '%SPACEDTOPIC%'
       },
       {
        exec => 3,
        name => 50,
        html => '<span class="TMLvariable">RELATIVETOPICPATH{}</span>',
        tml => '%RELATIVETOPICPATH{}%'
       },
       {
        exec => 3,
        name => 51,
        html => '<span class="TMLvariable">RELATIVETOPICPATH{Sausage}</span>',
        tml => '%RELATIVETOPICPATH{Sausage}%'
       },
       {
        exec => 3,
        name => 52,
        html => '<span class="TMLvariable">RELATIVETOPICPATH{"Chips"}</span>',
        tml => '%RELATIVETOPICPATH{"Chips"}%'
       },
       {
        exec => 3,
        name => 53,
        html => '<span class="TMLvariable">SCRIPTNAME</span>',
        tml => '%SCRIPTNAME%'
       },
       {
        exec => 3,
        name => 54,
        html => 'Outside<pre class="TMLverbatim">Inside</pre>Outside',
        tml => 'Outside
<verbatim>
Inside
</verbatim>
Outside',
       },
       {
        exec => 3,
        name => 55,
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
        name => 56,
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
        name => 57,
        html => 'Outside<pre>Inside</pre>Outside',
        tml => 'Outside
<pre>
Inside
</pre>
Outside',
       },
       {
        exec => 3,
        name => 58,
        html => 'Outside<pre class="twikiAlert">Inside</pre>Outside',
        tml => 'Outside
<pre class="twikiAlert">
Inside
</pre>
Outside',
       },
       {
        exec => 3,
        name => 59,
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
        name => 60,
        html => 'Outside<div class="TMLnoautolink">Inside</div>Outside',
        tml => 'Outside
<noautolink>
Inside
</noautolink>
Outside',
       },
       {
        exec => 3,
        name => 61,
        html => 'Outside<div class="twikiAlert TMLnoautolink">Inside</div>Outside',
        tml => 'Outside
<noautolink class="twikiAlert">
Inside
</noautolink>
Outside',
       },
       {
        exec => 3,
        name => 62,
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
        name => 63,
        html => '<h3 class="TML"> Test with<a href="page:/Current/LinkInHeader">LinkInHeader</a></h3>',
        tml => '---+++ Test with LinkInHeader
',
       },
       {
        exec => 2,
        name => 64,
        html => '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">',
        tml => '',
       },
       {
        exec => 2,
        name => 65,
        html => '<head> ignore me </head>',
        tml => '',
       },
       {
        exec => 2,
        name => 66,
        html => '<html> good <body>good </body></html>',
        tml => 'good good',
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

=pod

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

=cut

}

use HTML::Diff;

my %entMap =
  (
   nbsp => 160,   iexcl => 161,   cent => 162,   pound => 163,   curren => 164,
   yen => 165,   brvbar => 166,   sect => 167,   uml => 168,   copy => 169,
   ordf => 170,   laquo => 171,   not => 172,   shy => 173,   reg => 174,
   macr => 175,   deg => 176,   plusmn => 177,   sup2 => 178,   sup3 => 179,
   acute => 180,   micro => 181,   para => 182,   middot => 183,
   cedil => 184,   sup1 => 185,   ordm => 186,   raquo => 187,
   frac14 => 188,   frac12 => 189,   frac34 => 190,   iquest => 191,
   Agrave => 192,   Aacute => 193,   Acirc => 194,   Atilde => 195,
   Auml => 196,   Aring => 197,   AElig => 198,   Ccedil => 199,
   Egrave => 200,   Eacute => 201,   Ecirc => 202,   Euml => 203,
   Igrave => 204,   Iacute => 205,   Icirc => 206,   Iuml => 207,
   ETH => 208,   Ntilde => 209,   Ograve => 210,   Oacute => 211,
   Ocirc => 212,   Otilde => 213,   Ouml => 214,   times => 215,
   Oslash => 216,   Ugrave => 217,   Uacute => 218,   Ucirc => 219,
   Uuml => 220,   Yacute => 221,   THORN => 222,   szlig => 223,
   agrave => 224,   aacute => 225,   acirc => 226,   atilde => 227,
   auml => 228,   aring => 229,   aelig => 230,   ccedil => 231,
   egrave => 232,   eacute => 233,   ecirc => 234,   euml => 235,
   igrave => 236,   iacute => 237,   icirc => 238,   iuml => 239,
   eth => 240,   ntilde => 241,   ograve => 242,   oacute => 243,
   ocirc => 244,   otilde => 245,   ouml => 246,   divide => 247,
   oslash => 248,   ugrave => 249,   uacute => 250,   ucirc => 251,
   uuml => 252,   yacute => 253,   thorn => 254,   yuml => 255,
   fnof => 402,   Alpha => 913,   Beta => 914,   Gamma => 915,
   Delta => 916,   Epsilon => 917,   Zeta => 918,   Eta => 919,
   Theta => 920,   Iota => 921,   Kappa => 922,   Lambda => 923,
   Mu => 924,   Nu => 925,   Xi => 926,   Omicron => 927,
   Pi => 928,   Rho => 929,   Sigma => 931,   Tau => 932,
   Upsilon => 933,   Phi => 934,   Chi => 935,   Psi => 936,   Omega => 937,
   alpha => 945,   beta => 946,   gamma => 947,   delta => 948,
   epsilon => 949,   zeta => 950,   eta => 951,   theta => 952,
   iota => 953,   kappa => 954,   lambda => 955,   mu => 956,
   nu => 957,   xi => 958,   omicron => 959,   pi => 960,
   rho => 961,   sigmaf => 962,   sigma => 963,   tau => 964,
   upsilon => 965,   phi => 966,   chi => 967,   psi => 968,
   omega => 969,   thetasym => 977,   upsih => 978,   piv => 982,
   bull => 8226,   hellip => 8230,   prime => 8242,   Prime => 8243,
   oline => 8254,   frasl => 8260,   weierp => 8472,   image => 8465,
   real => 8476,   trade => 8482,   alefsym => 8501,   larr => 8592,
   uarr => 8593,   rarr => 8594,   darr => 8595,   harr => 8596,
   crarr => 8629,   lArr => 8656,   uArr => 8657,   rArr => 8658,
   dArr => 8659,   hArr => 8660,   forall => 8704,   part => 8706,
   exist => 8707,   empty => 8709,   nabla => 8711,   isin => 8712,
   notin => 8713,   ni => 8715,   prod => 8719,   sum => 8721,
   minus => 8722,   lowast => 8727,   radic => 8730,   prop => 8733,
   infin => 8734,   ang => 8736,   and => 8743,   or => 8744,
   cap => 8745,   cup => 8746,   int => 8747,   there4 => 8756,
   sim => 8764,   cong => 8773,   asymp => 8776,   ne => 8800,
   equiv => 8801,   le => 8804,   ge => 8805,   sub => 8834,
   sup => 8835,   nsub => 8836,   sube => 8838,   supe => 8839,
   oplus => 8853,   otimes => 8855,   perp => 8869,   sdot => 8901,
   lceil => 8968,   rceil => 8969,   lfloor => 8970,   rfloor => 8971,
   lang => 9001,   rang => 9002,   loz => 9674,   spades => 9824,
   clubs => 9827,   hearts => 9829,   diams => 9830,   quot => 34,
   amp => 38,   lt => 60,   gt => 62,   OElig => 338,   oelig => 339,
   Scaron => 352,   scaron => 353,   Yuml => 376,   circ => 710,
   tilde => 732,   ensp => 8194,   emsp => 8195,   thinsp => 8201,
   zwnj => 8204,   zwj => 8205,   lrm => 8206,   rlm => 8207,
   ndash => 8211,   mdash => 8212,   lsquo => 8216,   rsquo => 8217,
   sbquo => 8218,   ldquo => 8220,   rdquo => 8221,   bdquo => 8222,
   dagger => 8224,   Dagger => 8225,   permil => 8240,   lsaquo => 8249,
   rsaquo => 8250,   euro => 8364,
  );

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

sub _compareHTML {
    my ( $this, $expected, $actual ) = @_;

    my $result = '';
    $expected =~ s/&(\w+);/&#$entMap{$1};/g;
    $expected =~ s/ +/ /gs;
    $expected =~ s/^\s+//s;
    $expected =~ s/\s+$//s;
    $expected =~ s/\s+</</g;
    $expected =~ s/>\s+/>/g;

    $actual =~ s/&(\w+);/&#$entMap{$1};/g;
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
    my $txer = new TWiki::Plugins::WysiwygPlugin::HTML2TML({}, \&parseWikiUrl);
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

1;
