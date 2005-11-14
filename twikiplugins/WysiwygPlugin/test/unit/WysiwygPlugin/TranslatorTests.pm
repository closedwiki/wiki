# Copyright (C) 2005 ILOG http://www.ilog.fr
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of the TWiki distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# As per the GPL, removal of this notice is prohibited.

use strict;

# tests for the two translators, TML to HTML and HTML to TML, that
# support editing using WYSIWYG HTML editors. The tests are designed
# so that the round trip can be verified in as many cases as possible.
# Readers are invited to add more testcases.
#
# The tests require TWIKI_LIBS to include a pointer to the lib
# directory of a TWiki installation, so it can pick up the bits
# of TWiki it needs to include.
#
package TranslatorTests;

use base qw(Test::Unit::TestCase);

use TWiki::Plugins::WysiwygPlugin::TML2HTML;
use TWiki::Plugins::WysiwygPlugin::HTML2TML;
use Carp;
$SIG{__DIE__} = sub { Carp::confess $_[0] };
$SIG{__WARN__} = sub { die @_ };

use vars qw( $notml2html $nohtml2tml $unsafe);

BEGIN {

    for( my $i = 0; $i < 32; $i++) {
        $unsafe .= chr($i) unless $i == 10;
    }

    my $page;
    if( defined &TWiki::basicInitialize ) {
        TWiki::basicInitialize();
        die "ARGH" unless defined $TWiki::regex{headerPatternNoTOC};
        $page = TWiki::getScriptUrl('Current', 'TestTopic', 'view');
    } else {
        my $query = new CGI("");
        $query->path_info("/Current/TestTopic");
        my $twiki = new TWiki(undef, $query);
        $TWiki::cfg{Plugins}{WysiwygPlugin}{Enabled} = 1;
        $twiki = new TWiki(undef, $query);
        $TWiki::Plugins::SESSION = $twiki;
        $page = $twiki->getScriptUrl('Current', 'TestTopic', 'view');
    }
    $page =~ s/\/Current\/TestTopic.*$//;

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
              name => 'Pling',
              tml => 'Move !ItTest/site/ToWeb5 leaving web5 as !MySQL host',
              html => <<'HERE',
Move <span class="TMLnop">ItTest</span>/site/ToWeb5 leaving web5 as <span class="TMLnop">MySQL</span> host
HERE
              finaltml => <<'HERE',
Move <nop>ItTest/site/ToWeb5 leaving web5 as <nop>MySQL host
HERE
          },
          {
              exec => 3,
              name => 'linkAtStart',
              tml => 'LinkAtStart',
              html => '<a href="'.$page.'/Current/LinkAtStart">LinkAtStart</a>'
             },
          {
              exec => 3,
              name => 'otherWebLinkAtStart',
              tml => 'OtherWeb.LinkAtStart',
              html => '<a href="'.$page.'/OtherWeb/LinkAtStart">LinkAtStart</a>',
          },
          {
              exec => 3,
              name => 'currentWebLinkAtStart',
              tml => 'Current.LinkAtStart',
              html => '<a href="'.$page.'/Current/LinkAtStart">LinkAtStart</a>',
              finaltml => 'LinkAtStart'
             },
          {
              exec => 3,
              name => 'simpleParas',
              html => '1st paragraph<p />2nd paragraph',
              tml => <<'HERE',
1st paragraph

2nd paragraph
HERE
          },
          {
              exec => 3,
              name => 'headings',
              html => <<'HERE',
<h2 class="TML"> Sushi</h2><h3 class="TML"> Maguro</h3>
HERE
              tml => <<'HERE',
---++ Sushi
---+++ Maguro
HERE
          },
          {
              exec => 3,
              name => 'simpleStrong',
              html => '<b>Bold</b>',
              tml => '*Bold*
'
             },
          {
              exec => 3,
              name => 'strongLink',
              html => <<'HERE',
<b>reminded about<a href="http://www.koders.com">http://www.koders.com</a></b>
HERE
              tml => '*reminded about http://www.koders.com*',
              finaltml => '*reminded about http://www.koders.com*',
          },
          {
              exec => 3,
              name => 'simpleItalic',
              html => '<i>Italic</i>',
              tml => '_Italic_',
          },
          {
              exec => 3,
              name => 'boldItalic',
              html => '<b><i>Bold italic</i></b>',
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
              html => '<b><code>Bold Code</code></b>',
              tml => '==Bold Code=='
             },
          {
              exec => 3,
              name => 'mixtureOfFormats',
              html => <<'HERE',
<i>this</i><i>should</i><i>italicise</i><i>each</i><i>word</i><p /><b>and</b><b>this</b><b>should</b><b>embolden</b><b>each</b><b>word</b><p /><i>mixing</i><b>them</b><i>should</i><b>work</b>
HERE
              tml => <<'HERE',
_this_ _should_ _italicise_ _each_ _word_

*and* *this* *should* *embolden* *each* *word*

_mixing_ *them* _should_ *work*

HERE
          },
          {
              exec => 3,
              name => 'simpleVerbatim',
              html => <<'HERE',
<pre class="TMLverbatim">
&#60;verbatim&#62;
Description
&#60;/verbatim&#62;
class CatAnimal {
  void purr() {
    code &#60;here&#62;
  }
}
</pre>
HERE
              tml => <<'HERE',
<verbatim>
<verbatim>
Description
</verbatim>
class CatAnimal {
  void purr() {
    code <here>
  }
}
</verbatim>

HERE
          },
          {
              exec => 3,
              name => 'simpleHR',
              html => '<hr /><hr />--',
              tml => <<'HERE',
---
-------
--

HERE
              finaltml => <<'HERE',
---
---
--

HERE
          },
          {
              exec => 3,
              name => 'simpleBullList',
              html => '<ul><li>bullet item</li></ul>',
              tml => <<'HERE',
   * bullet item

HERE
          },
          {
              exec => 3,
              name => 'multiLevelBullList',
              html => <<'HERE',
X
<ul><li>level 1
<ul><li>level 2</li></ul></li></ul>
HERE
              tml => <<'HERE',
X
   * level 1
      * level 2

HERE
              finaltml => <<'HERE',
X
   * level 1
      * level 2 
HERE
          },
          {
              exec => 3,
              name => 'orderedList',
              html => <<'HERE',
<ol><li>Sushi</li></ol><p /><ol>
<li type="A">Sushi</li></ol><p />
<ol><li type="i">Sushi</li></ol><p />
<ol><li>Sushi</li><li type="A">Sushi</li><li type="i">Sushi</li></ol>
HERE
              tml => <<'HERE',
   1 Sushi

   A. Sushi

   i. Sushi

   1 Sushi
   A. Sushi
   i. Sushi

HERE
          },
          {
              exec => 3,
              name => 'mixedList',
              html => <<'HERE',
<ol><li>Things</li><li>Stuff
<ul><li>Banana Stuff</li><li>Other</li><li></li></ul></li><li>Something</li><li>kello<br />kitty</li></ol>
HERE
              tml => <<'HERE',
   1 Things
   1 Stuff
      * Banana Stuff
      * Other
      * 
   1 Something
   1 kello<br />kitty

HERE
          },
          {
              exec => 3,
              name => 'definitionList',
              html => <<'HERE',
<dl><dt>Sushi</dt><dd>Japan</dd><dt>Dim Sum</dt><dd>S. F.</dd><dt>Sauerkraut</dt><dd>Germany</dd></dl>
HERE
              tml => <<'HERE',
   $ Sushi: Japan
   $ Dim Sum: S. F.
   Sauerkraut: Germany

HERE
              finaltml => <<'HERE',
   Sushi: Japan
   $ Dim Sum: S. F.
   Sauerkraut: Germany

HERE
          },
          {
              exec => 3,
              name => 'simpleTable',
              html => <<'HERE',
<table border="1" cellpadding="0" cellspacing="1"><tr><th>L</th><th>C</th><th>R</th></tr><tr><td>A2</td><td class="align-center" style="text-align: center">2</td><td class="align-right" style="text-align: right">2</td></tr><tr><td>A3</td><td class="align-center" style="text-align: center">3</td><td class="align-left" style="text-align: left">3</td></tr><tr><td>A4-6</td><td>four</td><td>four</td></tr><tr><td>^</td><td>five</td><td>five</td></tr></table><p /><table border="1" cellpadding="0" cellspacing="1"><tr><td>^</td><td>six</td><td>six</td></tr></table>
HERE
              tml => <<'HERE',

| *L* | *C* | *R* |
| A2 |  2  |  2 |
| A3 |  3  | 3  |
| A4-6 | four | four |
|^| five | five |

|^| six | six |

HERE
              finaltml => <<'HERE',

| *L* | *C* | *R* |
| A2 | 2 |  2 |
| A3 | 3 | 3  |
| A4-6 | four | four |
| ^ | five | five |

| ^ | six | six |
HERE
          },
          {
              exec => 0,# disabled because of Kupu problems handling colspans
              name => 'tableWithSpans',
              html => <<'HERE',
<table border="1" cellpadding="0" cellspacing="1"><tr><th> L </th><th> C </th><th> R </th></tr><tr><td> A2 </td><td class="align-center" style="text-align: center">  2  </td><td class="align-right" style="text-align: right">  2 </td></tr><tr><td> A3 </td><td class="align-center" style="text-align: center">  3  </td><td class="align-left" style="text-align: left">  3  </td></tr><tr><td colspan="3"> multi span </td></tr><tr><td> A4-6 </td><td> four </td><td> four </td></tr><tr><td>^</td><td> five</td><td>five </td></tr></table><p /><table border="1" cellpadding="0" cellspacing="1"><tr><td>^</td><td>six</td><td>six</td></tr></table>
HERE
              tml => <<'HERE',

| *L* | *C* | *R* |
| A2 |  2  |  2 |
| A3 |  3  | 3  |
| multi span |||
| A4-6 | four | four |
|^| five|five |

|^| six | six |

HERE
              finaltml => <<'HERE',

| *L* |*C* |*R* |
| A2 |  2  |  2 |
| A3 |  3  | 3  |
| multi span |||
| A4-6 | four | four |
|^| five|five |

|^|six|six|
HERE
          },
          {
              exec => 3,
              name => 'noppedWikiword',
              html => '<span class="TMLnop">SunOS</span>',
              tml => '!SunOS',
              finaltml => '<nop>SunOS',
          },
          {
              exec => 2,
              name => 'noppedPara',
              html => '<span class="TMLnop">BeFore SunOS AfTer</span>',
              tml => '<nop>BeFore <nop>SunOS <nop>AfTer',
          },
          {
              exec => 2,
              name => 'noppedVariable',
              html => <<'HERE',
<span class="TMLnop"><span class="TMLvariable">MAINWEB</span></nop>
HERE
              tml => '%<nop>MAINWEB%'
             },
          {
              exec => 3,
              name => 'noAutoLunk',
              html => <<'HERE',
<div class="TMLnoautolink">RedHat & SuSE</div>

HERE
              tml => <<'HERE',
<noautolink>
RedHat & SuSE
</noautolink>
HERE
          },
          {
              exec => 3,
              name => 'mailtoLink',
              html => <<'HERE',
<a href="mailto:a@z.com">Mail</a><a href="mailto:?subject=Hi">Hi</a>
HERE
              tml => '[[mailto:a@z.com][Mail]] [[mailto:?subject=Hi][Hi]]',
              finaltml => <<'HERE',
[[mailto:a@z.com][Mail]] [[mailto:?subject=Hi][Hi]]
HERE
          },
          {
              exec => 3,
              name => 'mailtoLink2',
              html => ' a@z.com ',
              tml => ' a@z.com ',
          },
          {
              exec => 3,
              name => 'variousWikiWords',
              html => '<a href="'.$page.'/Current/WebPreferences">WebPreferences</a><p /><span class="TMLvariable">MAINWEB</span>.TWikiUsers<p /><a href="'.$page.'/Current/CompleteAndUtterNothing">CompleteAndUtterNothing</a><p /><a href="'.$page.'/Current/LinkBox">LinkBox</a><a href="'.$page.'/Current/LinkBoxs">LinkBoxs</a><a href="'.$page.'/Current/LinkBoxies">LinkBoxies</a><a href="'.$page.'/Current/LinkBoxess">LinkBoxess</a><a href="'.$page.'/Current/LinkBoxesses">LinkBoxesses</a><a href="'.$page.'/Current/LinkBoxes">LinkBoxes</a>',
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
              exec => 2,
              name => 'variousWikiWordsNopped',
              html => '<span class="TMLnop"><a href="'.$page.'/Current/WebPreferences">WebPreferences</a> <span class="TMLvariable">MAINWEB</span>.TWikiUsers <a href="'.$page.'/Current/CompleteAndUtterNothing">CompleteAndUtterNothing</a>',
              tml => '<nop>WebPreferences %<nop>MAINWEB%.TWikiUsers <nop>CompleteAndUtterNothing',
          },
          {
              exec => 3,
              name => 'squabsWithVars',
              html => '<a href="'.$page.'/Current/WikiSyntax">wiki syntax</a>[[<span class="TMLvariable">MAINWEB</span>.TWiki users]] escaped: [<span class="TMLnop">[wiki syntax]</span>]',
              tml => '[[wiki syntax]] [[%MAINWEB%.TWiki users]]
escaped:
![[wiki syntax]]',
              finaltml => '[[WikiSyntax][wiki syntax]] [[%MAINWEB%.TWiki users]] escaped: [<nop>[wiki syntax]]',
          },
          {
              exec => 3,
              name => 'squabsWithWikiWordsAndLink',
              html => '<a href="'.$page.'/Current/WikiSyntax">syntax</a><a href="http://gnu.org">GNU</a><a href="http://xml.org">XML</a>',
              tml => '[[WikiSyntax][syntax]] [[http://gnu.org][GNU]] [[http://xml.org][XML]]',
          },
          {
              exec => 3,
              name => 'squabWithAnchor',
              html => '<a href="'.$page.'/Current/FleegleHorn#TrumpetHack">FleegleHorn#TrumpetHack</a>',
              tml => 'FleegleHorn#TrumpetHack'
             },
          {
              exec => 3,
              name => 'plingedVarOne',
              html => '<span class="TMLnop"><span class="TMLvariable">MAINWEB</span></span>nowt',
              tml => '!%MAINWEB%nowt',
              finaltml => '%<nop>MAINWEB%nowt'
             },
          {
              exec => 3,
              name => 'plingedVarTwo',
              html => 'nowt<span class="TMLnop"><span class="TMLvariable">MAINWEB</span></span>',
              tml => 'nowt!%MAINWEB%',
              finaltml => 'nowt%<nop>MAINWEB%',
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
              tml => '%FORMFIELD{"" topic="" alttext="" default="" format="$value"}%',
          },
          {
              exec => 3,
              name => 'FORMFIELDvar2',
              html => '<span class="TMLvariable">FORMFIELD{"TopicClassification" topic="" alttext="" default="" format="$value"}</span>',
              tml => '%FORMFIELD{"TopicClassification" topic="" alttext="" default="" format="$value"}%',
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
              html => '<h3 class="TML"> Test with<a href="'.$page.'/Current/LinkInHeader">LinkInHeader</a></h3>',
              tml => '---+++ Test with LinkInHeader
',
          },
          {
              exec => 2,
              name => 'inlineNewlines',
              html => 'Zadoc<br />The<br />Priest',
              tml => 'Zadoc<br />The<br />Priest',
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
<tr>b0<td colspan="2">b1</td><td></td><td>b3</td></tr>
<tr>c0<td>c1</td><td>c2</td><td>c3</td></tr>
</tbody>
</table>',
              tml => '| a1 | a2 | a3 |
| b1 || b3 |
| c1 | c2 | c3 |
',
          },
          {
              exec => 2,
              name=>"images",
              html=>'<img src="test_image" />',
              tml => 'egami_tset',
          },
          {
              exec => 3,
              name=>"TWikiTagsInHTMLParam",
              html=>'<a href="%SCRIPTURL%/view%SCRIPTSUFFIX%">Burble</a>'.
                "<a href='%SCRIPTURL%/view%SCRIPTSUFFIX%'>Burble</a>",
              tml => '<a href="%SCRIPTURL%/view%SCRIPTSUFFIX%">Burble</a>'.
                "<a href='%SCRIPTURL%/view%SCRIPTSUFFIX%'>Burble</a>",
              finaltml => '<a href="%SCRIPTURL%/view%SCRIPTSUFFIX%">Burble</a>'.
                '<a href="%SCRIPTURL%/view%SCRIPTSUFFIX%">Burble</a>',
          },
          {
              exec => 2,
              name=>"emptySpans",
              html=> <<HERE,
1 <span class="arfle"></span>
2 <span lang="jp"></span>
3 <span></span>
4 <span lang="fr">francais</span>
5 <span class="arfle" lang="fr">francais</span>
HERE
              tml => <<HERE,
1 <span class="arfle"></span>
2 
3 
4 francais
5 <span class="arfle">francais</span>
HERE
          },
          {
              exec => 3,
              name => 'linkToOtherWeb',
              html => '<a href="Sandbox.WebHome">this</a>',
              tml => '[[Sandbox.WebHome][this]]',
          },
          {
              exec => 3,
              name => 'anchoredLink',
              tml => '[[FAQ.NetworkInternet#Pomona_Network][Test Link]]',
              html => '<a href="FAQ.NetworkInternet#Pomona_Network">Test Link</a>',
          },
          {
              exec => 2,
              name => 'tableInBold',
              html => '<b>abcd<table><tr><td>efg</td><td> </td></tr><tr><td> </td><td> </td></tr></table></b>',
              tml  => '<b>abcd
| efg ||
|||
</b>',
          },
          {
              exec => 3,
              name => 'variableInIMGtag',
              html => '<img src="%ATTACHURLPATH%/T-logo-16x16.gif" />',
              tml  => '<img src="%ATTACHURLPATH%/T-logo-16x16.gif" />',
              finaltml => '<img src="%ATTACHURLPATH%/T-logo-16x16.gif"></img>'
          },
          {
              exec => 3,
              name => 'twikiWebSnarf',
              html => '[[<span class="TMLvariable">TWIKIWEB</span>.TopicName][bah]]',
              tml  => '[[%TWIKIWEB%.TopicName][bah]]',
          },
          {
              exec => 3,
              name => 'mainWebSnarf',
              html => '[[<span class="TMLvariable">MAINWEB</span>.TopicName][bah]]',
              tml  => '[[%MAINWEB%.TopicName][bah]]',
          },
          {
              exec => 3,
              name => 'mainFormWithVars',
              html => '<form action="%SCRIPTURLPATH%/search%SCRIPTSUFFIX%/%INTURLENCODE{"%WEB%"}%/">',
              tml  => '<form action="%SCRIPTURLPATH%/search%SCRIPTSUFFIX%/%INTURLENCODE{"%WEB%"}%/">',
          },
          {
              exec => 3,
              name => "Item871",
              tml => "[[Test]] Entry [[Test Page]]\n",
              tml => "[[Test]] Entry [[TestPage][Test Page]]\n",
              html => '<a href="'.$page.'/Current/Test">Test</a>Entry<a href="'.$page.'/Current/TestPage">Test Page</a>',
          },
          {
              exec => 0,
              name => "Item863",
              tml => <<EOE,
||1| 2 |  3 | 4  ||
EOE
              html => '<table cellpadding="0" border="1" cellspacing="1">',
              finaltml => <<EOE,
EOE
          },
          {
              exec => 3,
              name => 'Item945',
              html => '<span class="TMLvariable">SEARCH{"ReqNo" scope="topic" regex="on" nosearch="on" nototal="on" casesensitive="on" format="$percntCALC{$IF($NOT($FIND(%TOPIC%,$formfield(ReqParents))), <nop>, [[$topic]] - $formfield(ReqShortDescript) %BR% )}$percnt"}</span>',
              tml  => '%SEARCH{"ReqNo" scope="topic" regex="on" nosearch="on" nototal="on" casesensitive="on" format="$percntCALC{$IF($NOT($FIND(%TOPIC%,$formfield(ReqParents))), <nop>, [[$topic]] - $formfield(ReqShortDescript) %BR% )}$percnt"}%',
          },
         ];



    foreach my $datum ( @$data ) {
        #next unless( $datum->{name} eq 'tableInBold' );
        next unless( $datum->{exec} & 1 );
        my $fn = 'TranslatorTests::test_TML2HTML_'.$datum->{name};
        no strict 'refs';
        *$fn = sub { shift->compareTML_HTML( $datum ) };
        use strict 'refs';
    }

    foreach my $datum ( @$data ) {
        #next unless( $datum->{name} eq 'tableInBold' );
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

    $actual = normaliseEntities($actual);
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
        #print "$diff->[0] | $diff->[1] | $diff->[2]\n";
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
                     "\n*****   Actual HTML: ".encode($b)."\n";
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

    my $txer = new TWiki::Plugins::WysiwygPlugin::TML2HTML(\&TWiki::Plugins::WysiwygPlugin::getViewUrl);
    $txer->{markvars} = 1;
    my $tx = $txer->convert( $args->{tml} );
    $txer->cleanup($tx);
    $this->_compareHTML($args->{html}, $tx, 1);
}

sub compareHTML_TML {
    my ( $this, $args ) = @_;
    my $txer = new TWiki::Plugins::WysiwygPlugin::HTML2TML
      ( { parseWikiUrl => \&TWiki::Plugins::WysiwygPlugin::parseWikiUrl,
          convertImage => \&convertImage } );
    my $tx = $txer->convert( $args->{html} );
    if( defined($args->{finaltml}) ) {
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
    $expected ||= '';
    $actual ||= '';
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
                $expl .= "<<==== HERE actual ";
                $expl .= ord($a)." != expected ".ord($e)."\n";
                last;
            }
            $expl .= $a;
            $i++;
        }
        $this->assert(0, $expl."\n");
    }
}

sub convertImage {
    my $url = shift;

    if ($url eq "test_image") {
        return "egami_tset";
    }
}

1;
