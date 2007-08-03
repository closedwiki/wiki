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
use base qw(TWikiTestCase);

use TWiki::Plugins::WysiwygPlugin;
use TWiki::Plugins::WysiwygPlugin::TML2HTML;
use TWiki::Plugins::WysiwygPlugin::HTML2TML;

use vars qw( $mask $unsafe $protecton $protectoff
             $preon $preoff
             $linkon $linkoff $nop );

for( my $i = 0; $i < 32; $i++) {
    $unsafe .= chr($i) unless $i == 10;
}

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

my $mask;
#$mask = 1; # TML 2 HTML only
#$mask = 2; # HTML 2 TML only
$mask = 3; # Both ways
my $pick_test; # set this to the name of a single test to execute

gen_compare_tests();
#gen_file_tests();

my $data;

BEGIN {
    #$notml2html = 1; # uncomment to disable tml2html tests
    #$nohtml2tml = 1; # uncomment to disable html2tml tests
    $protecton = '<span class="WYSIWYG_PROTECTED">';
    $preon = '<pre class="WYSIWYG_PROTECTED">';
    $linkon = '<span class="WYSIWYG_LINK">';

    $linkoff = $protectoff = '</span>';
    $preoff = '</pre>';

    $nop = '<nop>';

    $data =
  [
      {
          exec => 3,
          name => 'Pling',
          tml => 'Move !ItTest/site/ToWeb5 leaving web5 as !MySQL host',
          html => <<HERE,
Move ${nop}ItTest/site/ToWeb5 leaving web5 as ${nop}MySQL host
HERE
          finaltml => <<'HERE',
Move <nop>ItTest/site/ToWeb5 leaving web5 as <nop>MySQL host
HERE
      },
      {
          exec => 3,
          name => 'linkAtStart',
          tml => 'LinkAtStart',
          html => $linkon.'LinkAtStart'.$linkoff,
      },
      {
          exec => 3,
          name => 'otherWebLinkAtStart',
          tml => 'OtherWeb.LinkAtStart',
          html => $linkon.'OtherWeb.LinkAtStart'.$linkoff,
      },
      {
          exec => 3,
          name => 'currentWebLinkAtStart',
          tml => 'Current.LinkAtStart',
          html => $linkon.'Current.LinkAtStart'.$linkoff,
          finaltml => 'Current.LinkAtStart',
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
          html => <<HERE,
<b>reminded about${linkon}http://www.koders.com${linkoff}</b>
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
<pre class="WYSIWYG_VERBATIM"><br />&#60;verbatim&#62;<br />Description<br />&#60;/verbatim&#62;<br />class&nbsp;CatAnimal&nbsp;{<br />&nbsp;&nbsp;void&nbsp;purr()&nbsp;{<br />&nbsp;&nbsp;&nbsp;&nbsp;code&nbsp;&#60;here&#62;<br />&nbsp;&nbsp;}<br />}<br /></pre>
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
          html => '<hr class="TMLhr"/><hr class="TMLhr"/>--',
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
          html => <<"HERE",
<ol><li>Things</li><li>Stuff
<ul><li>Banana Stuff</li><li>Other</li><li></li></ul></li><li>Something</li><li>kello$protecton&lt;br&nbsp;/&gt;${protectoff}kitty</li></ol>
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
<dl> <dt> Sushi
</dt><dd>Japan</dd><dt>Dim Sum</dt><dd>S. F.</dd><dt>Sauerkraut</dt><dd>Germany</dd></dl>
HERE
          tml => <<'HERE',
   $ Sushi: Japan
   $ Dim Sum: S. F.
   Sauerkraut: Germany

HERE
          finaltml => <<'HERE',
   $ Sushi: Japan
   $ Dim Sum: S. F.
   $ Sauerkraut: Germany

HERE
      },
      {
          exec => 3,
          name => 'simpleTable',
          html => <<'HERE',
<table border="1" cellpadding="0" cellspacing="1"><tr><td><b>L</b></td><td><b>C</b></td><td><b>R</b></td></tr><tr><td> A2</td><td style="text-align: center" class="align-center"> 2</td><td style="text-align: right" class="align-right"> 2</td></tr><tr><td> A3</td><td style="text-align: center" class="align-center"> 3</td><td style="text-align: left" class="align-left"> 3</td></tr><tr><td> A4-6</td><td> four</td><td> four</td></tr><tr><td>^</td><td> five</td><td> five</td></tr></table><p /><table border="1" cellpadding="0" cellspacing="1"><tr><td>^</td><td> six</td><td> six</td></tr></table>
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
| A2 |  2  |  2 |
| A3 |  3  | 3  |
| A4-6 | four | four |
| ^ | five | five |

| ^ | six | six |
HERE
      },
      {
          exec => 0,# disabled because of Kupu problems handling colspans
          name => 'tableWithSpans',
          html => <<'HERE',
<table border="1" cellpadding="0" cellspacing="1"><tr><td><b> L </b></td><td><b> C </b></td><td><b> R </b></td></tr><tr><td> A2 </td><td class="align-center" style="text-align: center">  2  </td><td class="align-right" style="text-align: right">  2 </td></tr><tr><td> A3 </td><td class="align-center" style="text-align: center">  3  </td><td class="align-left" style="text-align: left">  3  </td></tr><tr><td colspan="3"> multi span </td></tr><tr><td> A4-6 </td><td> four </td><td> four </td></tr><tr><td>^</td><td> five</td><td>five </td></tr></table><p /><table border="1" cellpadding="0" cellspacing="1"><tr><td>^</td><td>six</td><td>six</td></tr></table>
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
          html => "${nop}SunOS",
          tml => '!SunOS',
          finaltml => '<nop>SunOS',
      },
      {
          exec => 2,
          name => 'noppedPara',
          html => "${nop}BeFore SunOS AfTer",
          tml => '<nop>BeFore <nop>SunOS <nop>AfTer',
      },
      {
          exec => 2,
          name => 'noppedVariable',
          html => <<'HERE',
%${nop}MAINWEB%</nop>
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
          html => <<HERE,
$linkon\[[mailto:a\@z.com][Mail]]${linkoff} $linkon\[[mailto:?subject=Hi][Hi]]${linkoff}
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
          html => "${linkon}WebPreferences${linkoff}<p />$protecton%MAINWEB%$protectoff.TWikiUsers<p />${linkon}CompleteAndUtterNothing${linkoff}<p />${linkon}LinkBox$linkoff${linkon}LinkBoxs${linkoff}${linkon}LinkBoxies${linkoff}${linkon}LinkBoxess${linkoff}${linkon}LinkBoxesses${linkoff}${linkon}LinkBoxes${linkoff}",
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
      },
      {
          exec => 2,
          name => 'variousWikiWordsNopped',
          html => "${nop}${linkon}WebPreferences${linkoff} %${nop}MAINWEB%.TWikiUsers ${nop}CompleteAndUtterNothing",
          tml => '<nop>WebPreferences %<nop>MAINWEB%.TWikiUsers <nop>CompleteAndUtterNothing',
      },
      {
          exec => 3,
          name => 'squabsWithVars',
          html => "${linkon}[[wiki syntax]]$linkoff$linkon\[[%MAINWEB%.TWiki users]]${linkoff}
escaped:
[<nop>[wiki syntax]]",
          tml => '[[wiki syntax]][[%MAINWEB%.TWiki users]]
escaped:
![[wiki syntax]]',
          finaltml => '[[wiki syntax]][[%MAINWEB%.TWiki users]]
escaped:
[<nop>[wiki syntax]]',
      },
      {
          exec => 3,
          name => 'squabsWithWikiWordsAndLink',
          html => "${linkon}[[WikiSyntax][syntax]]${linkoff} ${linkon}[[http://gnu.org][GNU]]${linkoff} ${linkon}[[http://xml.org][XML]]${linkoff}",
          tml => '[[WikiSyntax][syntax]] [[http://gnu.org][GNU]] [[http://xml.org][XML]]',
      },
      {
          exec => 3,
          name => 'squabWithAnchor',
          html => "${linkon}FleegleHorn#TrumpetHack${linkoff}",
          tml => 'FleegleHorn#TrumpetHack'
         },
      {
          exec => 3,
          name => 'plingedVarOne',
          html => "%<nop>MAINWEB%nowt",
          tml => '!%MAINWEB%nowt',
          finaltml => '%<nop>MAINWEB%nowt'
         },
      {
          exec => 3,
          name => 'plingedVarTwo',
          html => "nowt%${nop}MAINWEB%",
          tml => 'nowt!%MAINWEB%',
          finaltml => 'nowt%<nop>MAINWEB%',
      },
      {
          exec => 3,
          name => 'WEBvar',
          html => "${protecton}%WEB%${protectoff}",
          tml => '%WEB%'
         },
      {
          exec => 3,
          name => 'ICONvar1',
          html => "${protecton}%ICON{}%${protectoff}",
          tml => '%ICON{}%'
         },
      {
          exec => 3,
          name => 'ICONvar2',
          html => "${protecton}%ICON{&#34;&#34;}%${protectoff}",
          tml => '%ICON{""}%',
         },
      {
          exec => 3,
          name => 'ICONvar3',
          html => "${protecton}%ICON{&#34;Fleegle&#34;}%${protectoff}",
          tml => '%ICON{"Fleegle"}%'
         },
      {
          exec => 3,
          name => 'URLENCODEvar',
          html => "${protecton}%URLENCODE{&#34;&#34;}%${protectoff}",
          tml => '%URLENCODE{""}%'
         },
      {
          exec => 3,
          name => 'ENCODEvar',
          html => "${protecton}%ENCODE{&#34;&#34;}%${protectoff}",
          tml => '%ENCODE{""}%'
         },
      {
          exec => 3,
          name => 'INTURLENCODEvar',
          html => "${protecton}%INTURLENCODE{&#34;&#34;}%${protectoff}",
          tml => '%INTURLENCODE{""}%'
         },
      {
          exec => 3,
          name => 'MAINWEBvar',
          html => "${protecton}%MAINWEB%${protectoff}",
          tml => '%MAINWEB%'
         },
      {
          exec => 3,
          name => 'TWIKIWEBvar',
          html => "${protecton}%TWIKIWEB%${protectoff}",
          tml => '%TWIKIWEB%'
         },
      {
          exec => 3,
          name => 'HOMETOPICvar',
          html => "${protecton}%HOMETOPIC%${protectoff}",
          tml => '%HOMETOPIC%'
         },
      {
          exec => 3,
          name => 'WIKIUSERSTOPICvar',
          html => $protecton.'%WIKIUSERSTOPIC%'.$protectoff,
          tml => '%WIKIUSERSTOPIC%'
         },
      {
          exec => 3,
          name => 'WIKIPREFSTOPICvar',
          html => $protecton.'%WIKIPREFSTOPIC%'.$protectoff,
          tml => '%WIKIPREFSTOPIC%'
         },
      {
          exec => 3,
          name => 'WEBPREFSTOPICvar',
          html => $protecton.'%WEBPREFSTOPIC%'.$protectoff,
          tml => '%WEBPREFSTOPIC%'
         },
      {
          exec => 3,
          name => 'NOTIFYTOPICvar',
          html => $protecton.'%NOTIFYTOPIC%'.$protectoff,
          tml => '%NOTIFYTOPIC%'
         },
      {
          exec => 3,
          name => 'STATISTICSTOPICvar',
          html => $protecton.'%STATISTICSTOPIC%'.$protectoff,
          tml => '%STATISTICSTOPIC%'
         },
      {
          exec => 3,
          name => 'STARTINCLUDEvar',
          html => $protecton.'%STARTINCLUDE%'.$protectoff,
          tml => '%STARTINCLUDE%'
         },
      {
          exec => 3,
          name => 'STOPINCLUDEvar',
          html => $protecton.'%STOPINCLUDE%'.$protectoff,
          tml => '%STOPINCLUDE%'
         },
      {
          exec => 3,
          name => 'SECTIONvar',
          html => $protecton.'%SECTION{&#34;&#34;}%'.$protectoff,
          tml => '%SECTION{""}%'
         },
      {
          exec => 3,
          name => 'ENDSECTIONvar',
          html => $protecton.'%ENDSECTION%'.$protectoff,
          tml => '%ENDSECTION%'
         },
      {
          exec => 3,
          name => 'FORMFIELDvar1',
          html => $protecton.'%FORMFIELD{&#34;&#34;&nbsp;topic=&#34;&#34;&nbsp;alttext=&#34;&#34;&nbsp;default=&#34;&#34;&nbsp;format=&#34;$value&#34;}%'.$protectoff,
          tml => '%FORMFIELD{"" topic="" alttext="" default="" format="$value"}%',
      },
      {
          exec => 3,
          name => 'FORMFIELDvar2',
          html => $protecton.'%FORMFIELD{&#34;TopicClassification&#34;&nbsp;topic=&#34;&#34;&nbsp;alttext=&#34;&#34;&nbsp;default=&#34;&#34;&nbsp;format=&#34;$value&#34;}%'.$protectoff,
          tml => '%FORMFIELD{"TopicClassification" topic="" alttext="" default="" format="$value"}%',
      },
      {
          exec => 3,
          name => 'SPACEDTOPICvar',
          html => $protecton.'%SPACEDTOPIC%'.$protectoff,
          tml => '%SPACEDTOPIC%'
         },
      {
          exec => 3,
          name => 'RELATIVETOPICPATHvar1',
          html => $protecton.'%RELATIVETOPICPATH{}%'.$protectoff,
          tml => '%RELATIVETOPICPATH{}%'
         },
      {
          exec => 3,
          name => 'RELATIVETOPICPATHvar2',
          html => $protecton.'%RELATIVETOPICPATH{Sausage}%'.$protectoff,
          tml => '%RELATIVETOPICPATH{Sausage}%'
         },
      {
          exec => 3,
          name => 'RELATIVETOPICPATHvar3',
          html => $protecton.'%RELATIVETOPICPATH{&#34;Chips&#34;}%'.$protectoff,
          tml => '%RELATIVETOPICPATH{"Chips"}%'
         },
      {
          exec => 3,
          name => 'SCRIPTNAMEvar',
          html => $protecton.'%SCRIPTNAME%'.$protectoff,
          tml => '%SCRIPTNAME%'
         },
      {
          exec => 3,
          name => 'nestedVerbatim',
          html => 'Outside
<pre class="WYSIWYG_VERBATIM"><br />Inside<br /></pre>Outside',
          tml => 'Outside
<verbatim>
Inside
</verbatim>
Outside',
      },
      {
          exec => 3,
          name => 'nestedPre',
          html => 'Outside
<pre class="twikiAlert WYSIWYG_VERBATIM"><br />Inside<br /></pre>
Outside',
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
          html => 'Outside<pre class="WYSIWYG_VERBATIM"><br />Inside<br />&nbsp;&nbsp;&nbsp;</pre>Outside',
          tml => 'Outside
   <verbatim>
Inside
   </verbatim>
Outside
',
      },
      {
          exec => 3,
          name => 'nestedIndentedPre',
          html => 'Outside
<pre>
Inside
</pre>
Outside',
          tml => 'Outside
<pre>
Inside
</pre>
Outside',
      },
      {
          exec => 3,
          name => 'classifiedPre',
          html => 'Outside
<pre class="twikiAlert">
Inside
</pre>
Outside',
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
          html => 'Outside
<div class="TMLnoautolink">
Inside
</div>
Outside',
          tml => 'Outside
<noautolink>
Inside
</noautolink>
Outside',
      },
      {
          exec => 3,
          name => 'classifiedNAL',
          html => 'Outside
<div class="twikiAlert TMLnoautolink">
Inside
</div>
Outside
',
          tml => 'Outside
<noautolink class="twikiAlert">
Inside
</noautolink>
Outside',
      },
      {
          exec => 3,
          name => 'indentedNAL',
          html => 'Outside
<div class="TMLnoautolink">
Inside
</div>
Outside
',
          tml => 'Outside
   <noautolink>
Inside
   </noautolink>
Outside
',
      },
      {
          exec => 3,
          name => 'linkInHeader',
          html => "<h3 class=\"TML\"> Test with${linkon}LinkInHeader${linkoff}</h3>",
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
          html=>"${linkon}[[%!page!%/Burble/Barf][Burble]]${linkoff}",
          tml => '[[%!page!%/Burble/Barf][Burble]]',
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
1 
2 
3 
4 francais
5 francais
HERE
      },
      {
          exec => 3,
          name => 'linkToOtherWeb',
          html => "${linkon}[[Sandbox.WebHome][this]]${linkoff}",
          tml => '[[Sandbox.WebHome][this]]',
      },
      {
          exec => 3,
          name => 'anchoredLink',
          tml => '[[FAQ.NetworkInternet#Pomona_Network][Test Link]]',
          html => "${linkon}[[FAQ.NetworkInternet#Pomona_Network][Test Link]]${linkoff}",
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
          html => '<img src="/MAIN/pub/Current/TestTopic/T-logo-16x16.gif" />',
          tml  => '<img src="%ATTACHURLPATH%/T-logo-16x16.gif" />',
          finaltml => '<img src="%ATTACHURLPATH%/T-logo-16x16.gif" />',
      },
      {
          exec => 3,
          name => 'setCommand',
          tml => <<HERE,
   * Set FLIBBLE = <break> <cake/>
     </break>
   * %FLIBBLE%
      * Set FLEEGLE = easy gum
HERE
          html => '<ul>
<li> Set FLIBBLE =<span class="WYSIWYG_PROTECTED">&nbsp;&#60;break&#62;&nbsp;&#60;cake/&#62;<br />&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&#60;/break&#62;</span></li><li><span class="WYSIWYG_PROTECTED">%FLIBBLE%</span><ul><li>Set FLEEGLE =<span class="WYSIWYG_PROTECTED">&nbsp;easy&nbsp;gum</span></li></ul></li></ul>',
      },
      {
          exec => 3,
          name => 'twikiWebSnarf',
          html => $linkon.'[[%TWIKIWEB%.TopicName][bah]]'.$linkoff,
          tml  => '[[%TWIKIWEB%.TopicName][bah]]',
      },
      {
          exec => 3,
          name => 'mainWebSnarf',
          html => "${linkon}\[[%MAINWEB%.TopicName][bah]]$linkoff",
          tml  => '[[%MAINWEB%.TopicName][bah]]',
      },
      {
          exec => 3,
          name => 'mainFormWithVars',
          html => $protecton.'<form&nbsp;action=&#34;%SCRIPTURLPATH%/search%SCRIPTSUFFIX%/%INTURLENCODE{&#34;%WEB%&#34;}%/&#34;>'.$protectoff,
          tml  => '<form action="%SCRIPTURLPATH%/search%SCRIPTSUFFIX%/%INTURLENCODE{"%WEB%"}%/">',
      },
      {
          exec => 3,
          name => "Item871",
          tml => "[[Test]] Entry [[TestPage][Test Page]]\n",
          html => "${linkon}[[Test]]${linkoff} Entry ${linkon}[[TestPage][Test Page]]${linkoff}",
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
          html => $protecton.'%SEARCH{&#34;ReqNo&#34;&nbsp;scope=&#34;topic&#34;&nbsp;regex=&#34;on&#34;&nbsp;nosearch=&#34;on&#34;&nbsp;nototal=&#34;on&#34;&nbsp;casesensitive=&#34;on&#34;&nbsp;format=&#34;$percntCALC{$IF($NOT($FIND(%TOPIC%,$formfield(ReqParents))),&nbsp;&#60;nop&#62;,&nbsp;[[$topic]]&nbsp;-&nbsp;$formfield(ReqShortDescript)&nbsp;%BR%&nbsp;)}$percnt&#34;}%'.$protectoff,
          tml  => '%SEARCH{"ReqNo" scope="topic" regex="on" nosearch="on" nototal="on" casesensitive="on" format="$percntCALC{$IF($NOT($FIND(%TOPIC%,$formfield(ReqParents))), <nop>, [[$topic]] - $formfield(ReqShortDescript) %BR% )}$percnt"}%',
      },
      {
          exec => 3,
          name => "WebAndTopic",
          tml => "Current.TestTopic Sandbox.TestTopic [[Current.TestTopic]] [[Sandbox.TestTopic]]",
          html => <<HERE,
${linkon}Current.TestTopic${linkoff}
${linkon}Sandbox.TestTopic${linkoff}
${linkon}\[[Current.TestTopic]]${linkoff}
${linkon}\[[Sandbox.TestTopic]]${linkoff}
HERE
          finaltml => <<HERE,
Current.TestTopic Sandbox.TestTopic [[Current.TestTopic]] [[Sandbox.TestTopic]]
HERE
      },
      {
          exec => 3,
          name => 'Item1140',
          html => '<img src="%!page!%/T-logo-16x16.gif" />',
          tml  => '<img src="%!page!%/T-logo-16x16.gif" />',
          finaltml => '<img src=\'%SCRIPTURL{"view"}%/T-logo-16x16.gif\' />'
         },
      {
          exec => 3,
          name => 'Item1175',
          tml => '[[WebCTPasswords][Resetting a WebCT Password]]',
          html => "${linkon}[[WebCTPasswords][Resetting a WebCT Password]]${linkoff}",
          finaltml => '[[WebCTPasswords][Resetting a WebCT Password]]',
      },
      {
          exec => 3,
          name => 'Item1259',
          html => "Spleem$protecton&#60;!--<br />&nbsp;&nbsp;&nbsp;*&nbsp;Set&nbsp;SPOG&nbsp;=&nbsp;dreep<br />--&#62;${protectoff}Splom",
          tml => "Spleem<!--\n   * Set SPOG = dreep\n-->Splom",
      },
      {
          exec => 3,
          name => 'Item1317',
          tml => '%<nop>DISPLAYTIME{"$hou:$min"}%',
          html => "%${nop}DISPLAYTIME\{\"\$hou:\$min\"}%",
      },
      {
          exec => 3,
          name => 'Item4410',
          tml => <<'HERE',
   * x
| Y |
HERE
          html => '<ul><li>x</li></ul><table cellspacing="1" cellpadding="0" border="1"><tr><td>Y</td></tr></table>',
      },
      {
          exec => 3,
          name => 'Item4426',
          tml => <<'HERE',
   * x
   *
   * y
HERE
          html => '<ul>
<li>x
</li><li></li><li>y
</li></ul>',
          finaltml => <<'HERE',
   * x
   * 
   * y
HERE
      },
      {
          exec => 3,
          name => 'Item3735',
          tml => "fred *%WIKINAME%* fred",
          html => "fred <b>$protecton%WIKINAME%$protectoff</b> fred",
      },
      {
          exec => 3,
          name => 'brInProtectedRegion',
          html => $protecton."&#60;!--Fred<br />Jo&nbsp;e<br />Sam--&#62;".$protectoff,
          tml => "<!--Fred\nJo e\nSam-->",
      },
     ];
};

sub gen_compare_tests {
    for (my $i = 0; $i < scalar(@$data); $i++) {
        my $datum = $data->[$i];
        if (defined($pick_test)) {
            next unless( $datum->{name} eq $pick_test );
        }
        if ( (($mask & $datum->{exec}) & 1)) {
            my $fn = 'TranslatorTests::test_TML2HTML_'.$datum->{name};
            no strict 'refs';
            *$fn = sub { my $this = shift; $this->compareTML_HTML( $datum ) };
            use strict 'refs';
        }
        if (($mask & $datum->{exec}) & 2) {
            my $fn = 'TranslatorTests::test_HTML2TML_'.$datum->{name};
            no strict 'refs';
            *$fn = sub { my $this = shift; $this->compareRoundTrip( $datum ) };
            use strict 'refs';
        }
    }
}

sub gen_file_tests {
    foreach my $d (@INC) {
        if (-d "$d/test_html" && $d =~ /WysiwygPlugin/) {
            opendir( D, "$d/test_html" ) or die;
            foreach my $file (grep { /^.*\.html$/i } readdir D ) {
                $file =~ s/\.html$//;
                my $test = { name => $file };
                open(F, "<$d/test_html/$file.html");
                undef $/;
                $test->{html} = <F>;
                close(F);
                next unless -e "$d/result_tml/$file.txt";
                open(F, "<$d/result_tml/$file.txt");
                undef $/;
                $test->{finaltml} = <F>;
                close(F);
                my $fn = 'TranslatorTests::test_HTML2TML_FILE_'.$test->{name};
                no strict 'refs';
                *$fn = sub { shift->compareHTML_TML( $test ) };
                use strict 'refs';
            }
            last;
        }
    }
}

sub set_up {
    my $this = shift;
    $this->SUPER::set_up(@_);
    $TWiki::cfg{Plugins}{WysiwygPlugin}{Enabled} = 1;

    my $query = new CGI("");
    $query->path_info("/Current/TestTopic");
    $this->{twiki} = new TWiki(undef, $query);
    $TWiki::Plugins::SESSION = $this->{twiki};
}

use HTML::Diff;

sub normaliseEntities {
    my $text = shift;
    # Convert text entities to &# representation
    $text =~ s/(&\w+;)/'&#'.ord(HTML::Entities::decode_entities($1)).';'/ge;
    return $text;
}

=pod

sub _compareHTML {
    my ( $this, $expected, $actual ) = @_;

    my $result = '';
    $expected =~ s/(&[^;]+;)/normaliseEntities($1)/ge;
#    $expected =~ s/ +/ /gs;
#    $expected =~ s/^\s+//s;
#    $expected =~ s/\s+$//s;
#    $expected =~ s/\s+</</g;
#    $expected =~ s/>\s+/>/g;

    $actual =~ s/(&[^;]+;)/normaliseEntities($1)/ge;
#    $actual =~ s/ +/ /gs;
#    $actual =~ s/^\s+//s;
#    $actual =~ s/\s+$//s;
#    $actual =~ s/\s+</</g;
#    $actual =~ s/>\s+/>/g;

    return if $actual eq $expected;

    my $diffs = HTML::Diff::html_word_diff( $expected, $actual );
    my $failed = 0;
    my $okset = "";

    foreach my $diff ( @$diffs ) {
        my $a = $diff->[1];
        #$a =~ s/^\s+//;
        #$a =~ s/\s+$//s;
        my $b = $diff->[2];
        #$b =~ s/^\s+//;
        #$b =~ s/\s+$//s;
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

=cut

sub compareTML_HTML {
    my ( $this, $args ) = @_;

    my $page = $this->{twiki}->getScriptUrl(1, 'view', 'Current', 'TestTopic');
    $page =~ s/\/Current\/TestTopic.*$//;
    my $html = $args->{html}||''; $html =~ s/%!page!%/$page/g;
    my $finaltml = $args->{finaltml}||''; $finaltml =~ s/%!page!%/$page/g;
    my $tml = $args->{tml}||''; $tml =~ s/%!page!%/$page/g;

    my $txer = new TWiki::Plugins::WysiwygPlugin::TML2HTML();
    my $tx = $txer->convert(
        $tml,
        {
            web => 'Current', topic => 'TestTopic',
            getViewUrl => \&TWiki::Plugins::WysiwygPlugin::getViewUrl,
            expandVarsInURL => \&TWiki::Plugins::WysiwygPlugin::expandVarsInURL,
        });

    $this->assert_html_equals($html, $tx);
}

sub compareRoundTrip {
    my ( $this, $args ) = @_;
    my $page = $this->{twiki}->getScriptUrl(1, 'view', 'Current', 'TestTopic');
    $page =~ s/\/Current\/TestTopic.*$//;

    my $tml = $args->{tml}||'';
    $tml =~ s/%!page!%/$page/g;

    my $txer = new TWiki::Plugins::WysiwygPlugin::TML2HTML();
    my $html = $txer->convert(
        $tml,
        {
            web => 'Current', topic => 'TestTopic',
            getViewUrl => \&TWiki::Plugins::WysiwygPlugin::getViewUrl,
            expandVarsInURL => \&TWiki::Plugins::WysiwygPlugin::expandVarsInURL,
        });

    $txer = new TWiki::Plugins::WysiwygPlugin::HTML2TML();
    my $tx = $txer->convert(
        $html,
        {
            web => 'Current', topic => 'TestTopic',
            convertImage => \&convertImage,
            rewriteURL => \&TWiki::Plugins::WysiwygPlugin::postConvertURL,
        });
    my $finaltml = $args->{finaltml} || $tml;
    $finaltml =~ s/%!page!%/$page/g;
    $this->_compareTML($finaltml, $tx, $args->{name});
}

sub compareHTML_TML {
    my ( $this, $args ) = @_;

    my $page = $this->{twiki}->getScriptUrl(1, 'view', 'Current', 'TestTopic');
    $page =~ s/\/Current\/TestTopic.*$//;
    my $html = $args->{html}||'';
    $html =~ s/%!page!%/$page/g;
    my $tml = $args->{tml}||'';
    $tml =~ s/%!page!%/$page/g;
    my $finaltml = $args->{finaltml}||'$tml';
    $finaltml =~ s/%!page!%/$page/g;

    my $txer = new TWiki::Plugins::WysiwygPlugin::HTML2TML();
    my $tx = $txer->convert(
        $html,
        {
            web => 'Current', topic => 'TestTopic',
            convertImage => \&convertImage,
            rewriteURL => \&TWiki::Plugins::WysiwygPlugin::postConvertURL,
        });
    $this->_compareTML($finaltml, $tx, $args->{name});
}

sub encode {
    my $s = shift;
    # used for debugging odd chars
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
