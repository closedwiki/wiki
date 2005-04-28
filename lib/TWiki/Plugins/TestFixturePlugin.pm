# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2004 Crawford Currie, http://c-dot.co.uk
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at 
# http://www.gnu.org/copyleft/gpl.html
#
package TWiki::Plugins::TestFixturePlugin;

use strict;
use HTML::Diff;
use TWiki::Func;

# This is a test plugin designed to interact with TWiki testcases.
# It should NOT be shipped with a release.
# It implements all possible plugin handlers, and generates selected
# results that interact with test cases in the TestCases web.
#
# To use this plugin, you will have to:
# 1 Have HTML::Diff installed
# 2 Create an empty topic in the 'TWiki' web of your test installation,
#   called TestFixturePlugin.txt
#
# DO NOT USE THIS PLUGIN IN A USER INSTALLATION. IT IS DESIGNED FOR
# TWIKI CORE TESTING ONLY!!!
#
# The idea is that topics contain blocks marked by <!-- expected -->
# and <!-- actual --> tags. These blocks are compared in the
# endRenderingHandler. The comparison is only done when you provide
# the "test=compare" parameter on the URL.
#
# Stubs are provided for all the published handlers so you can hack
# the plugin to do other tests as well.
#
use vars qw(
            $installWeb $VERSION $pluginName
            $topic $web $user $installWeb
           );

use CGI qw( :any );

$VERSION = '1.000';
$pluginName = 'TestFixturePlugin';

my %entMap =
  (
   nbsp => 160,
   iexcl => 161,
   cent => 162,
   pound => 163,
   curren => 164,
   yen => 165,
   brvbar => 166,
   sect => 167,
   uml => 168,
   copy => 169,
   ordf => 170,
   laquo => 171,
   not => 172,
   shy => 173,
   reg => 174,
   macr => 175,
   deg => 176,
   plusmn => 177,
   sup2 => 178,
   sup3 => 179,
   acute => 180,
   micro => 181,
   para => 182,
   middot => 183,
   cedil => 184,
   sup1 => 185,
   ordm => 186,
   raquo => 187,
   frac14 => 188,
   frac12 => 189,
   frac34 => 190,
   iquest => 191,
   Agrave => 192,
   Aacute => 193,
   Acirc => 194,
   Atilde => 195,
   Auml => 196,
   Aring => 197,
   AElig => 198,
   Ccedil => 199,
   Egrave => 200,
   Eacute => 201,
   Ecirc => 202,
   Euml => 203,
   Igrave => 204,
   Iacute => 205,
   Icirc => 206,
   Iuml => 207,
   ETH => 208,
   Ntilde => 209,
   Ograve => 210,
   Oacute => 211,
   Ocirc => 212,
   Otilde => 213,
   Ouml => 214,
   times => 215,
   Oslash => 216,
   Ugrave => 217,
   Uacute => 218,
   Ucirc => 219,
   Uuml => 220,
   Yacute => 221,
   THORN => 222,
   szlig => 223,
   agrave => 224,
   aacute => 225,
   acirc => 226,
   atilde => 227,
   auml => 228,
   aring => 229,
   aelig => 230,
   ccedil => 231,
   egrave => 232,
   eacute => 233,
   ecirc => 234,
   euml => 235,
   igrave => 236,
   iacute => 237,
   icirc => 238,
   iuml => 239,
   eth => 240,
   ntilde => 241,
   ograve => 242,
   oacute => 243,
   ocirc => 244,
   otilde => 245,
   ouml => 246,
   divide => 247,
   oslash => 248,
   ugrave => 249,
   uacute => 250,
   ucirc => 251,
   uuml => 252,
   yacute => 253,
   thorn => 254,
   yuml => 255,
   fnof => 402,
   Alpha => 913,
   Beta => 914,
   Gamma => 915,
   Delta => 916,
   Epsilon => 917,
   Zeta => 918,
   Eta => 919,
   Theta => 920,
   Iota => 921,
   Kappa => 922,
   Lambda => 923,
   Mu => 924,
   Nu => 925,
   Xi => 926,
   Omicron => 927,
   Pi => 928,
   Rho => 929,
   Sigma => 931,
   Tau => 932,
   Upsilon => 933,
   Phi => 934,
   Chi => 935,
   Psi => 936,
   Omega => 937,
   alpha => 945,
   beta => 946,
   gamma => 947,
   delta => 948,
   epsilon => 949,
   zeta => 950,
   eta => 951,
   theta => 952,
   iota => 953,
   kappa => 954,
   lambda => 955,
   mu => 956,
   nu => 957,
   xi => 958,
   omicron => 959,
   pi => 960,
   rho => 961,
   sigmaf => 962,
   sigma => 963,
   tau => 964,
   upsilon => 965,
   phi => 966,
   chi => 967,
   psi => 968,
   omega => 969,
   thetasym => 977,
   upsih => 978,
   piv => 982,
   bull => 8226,
   hellip => 8230,
   prime => 8242,
   Prime => 8243,
   oline => 8254,
   frasl => 8260,
   weierp => 8472,
   image => 8465,
   real => 8476,
   trade => 8482,
   alefsym => 8501,
   larr => 8592,
   uarr => 8593,
   rarr => 8594,
   darr => 8595,
   harr => 8596,
   crarr => 8629,
   lArr => 8656,
   uArr => 8657,
   rArr => 8658,
   dArr => 8659,
   hArr => 8660,
   forall => 8704,
   part => 8706,
   exist => 8707,
   empty => 8709,
   nabla => 8711,
   isin => 8712,
   notin => 8713,
   ni => 8715,
   prod => 8719,
   sum => 8721,
   minus => 8722,
   lowast => 8727,
   radic => 8730,
   prop => 8733,
   infin => 8734,
   ang => 8736,
   and => 8743,
   or => 8744,
   cap => 8745,
   cup => 8746,
   int => 8747,
   there4 => 8756,
   sim => 8764,
   cong => 8773,
   asymp => 8776,
   ne => 8800,
   equiv => 8801,
   le => 8804,
   ge => 8805,
   sub => 8834,
   sup => 8835,
   nsub => 8836,
   sube => 8838,
   supe => 8839,
   oplus => 8853,
   otimes => 8855,
   perp => 8869,
   sdot => 8901,
   lceil => 8968,
   rceil => 8969,
   lfloor => 8970,
   rfloor => 8971,
   lang => 9001,
   rang => 9002,
   loz => 9674,
   spades => 9824,
   clubs => 9827,
   hearts => 9829,
   diams => 9830,
   quot => 34,
   amp => 38,
   lt => 60,
   gt => 62,
   OElig => 338,
   oelig => 339,
   Scaron => 352,
   scaron => 353,
   Yuml => 376,
   circ => 710,
   tilde => 732,
   ensp => 8194,
   emsp => 8195,
   thinsp => 8201,
   zwnj => 8204,
   zwj => 8205,
   lrm => 8206,
   rlm => 8207,
   ndash => 8211,
   mdash => 8212,
   lsquo => 8216,
   rsquo => 8217,
   sbquo => 8218,
   ldquo => 8220,
   rdquo => 8221,
   bdquo => 8222,
   dagger => 8224,
   Dagger => 8225,
   permil => 8240,
   lsaquo => 8249,
   rsaquo => 8250,
   euro => 8364,
  );

# Parse a topic extracting bracketed subexpressions
sub _parse {
    my ( $text, $tag ) = @_;

    $text =~ s/\r//g;
    $text =~ s/\t/   /g;
    $text =~ s/[^ -~\n]/./g;
    $text =~ s/<nop>//g;

    my @list = ();
    my $opt;
    my $lastTok;
    my $gathering = 1;

    foreach my $tok ( split( /(<!--\s*\/?$tag.*?-->)/, $text ) ) {
        if ( $tok =~ /<!--\s*$tag(.*?)-->/ ) {
            $opt = $1;
            $gathering = 1;
        } elsif ( $tok =~ /<!--\s*\/$tag\s*-->/ ) {
            throw Error::Simple("<!-- /$tag --> found without matching <!-- $tag --> $lastTok")
              unless ( $gathering );
            push( @list, { text => $lastTok, options=> $opt } );
            $gathering = 0;
        } elsif ( $gathering &&
                  $tok =~ /^<!--\/?\s*(expected|actual).*?-->$/ ) {
            throw Error::Simple("$tok encountered when in open <!-- $tag --> bracket");
        }
        $lastTok = $tok;
    }
    if ( $gathering ) {
        push( @list, { text => $lastTok, options=> $opt } );
    }

    return \@list;
}

# use HTML::Diff to compare the expected and actual contents
sub _compareExpectedWithActual {
    my ( $expected, $actual, $topic, $web ) = @_;
    my $errors = '';

    unless( $#$actual == $#$expected ) {
        my $mess = "Numbers of actual ($#$actual) and expected ($#$expected) blocks don't match<table width=\"100%\"><th>Expected</th><th>Actual</th></tr>";
        for my $i ( 0..$#$actual ) {
            my $e = $expected->[$i];
            my $et = $e->{text};
            my $at = $actual->[$i]->{text};
            $et =~ s/&/&amp;/g;
            $et =~ s/</&lt;/g;
            $at =~ s/&/&amp;/g;
            $at =~ s/</&lt;/g;
            $mess .= "<tr><td>$et</td><td>$at</td></tr>";
        }
        return "$mess</table>";;
    }

    for my $i ( 0..$#$actual ) {
        my $e = $expected->[$i];
        my $et = $e->{text};
        if ( $e->{options} =~ /\bagain\b/ ) {
            my $prev = $expected->[$i-1];
            $et = $prev->{text};
            # inherit the text so that the next 'again' will see the
            # previous text
            $e->{text} = $et;
        }
        if ( $e->{options} =~ /\bexpand\b/ ) {
            $et = TWiki::Func::expandCommonVariables( $et, $topic, $web );
        }
        my $at = $actual->[$i]->{text};
        $errors .= _compareResults( $et, $at, $i + 1, $e->{options} );
    }

    return $errors;
}

sub _tidy {
    my $a = shift;
    $a =~ s/&/&amp;/g;
    $a =~ s/</&lt;/g;
    $a =~ s/>/&gt;/g;
    return $a;
}

sub _compareResults {
    my ( $expected, $actual, $group, $opts ) = @_;

    my $result = '';
    # normalise HTML entities
    $expected =~ s/&(\w+);/&#$entMap{$1};/g;
    $actual =~ s/&(\w+);/&#$entMap{$1};/g;
    my $diffs = HTML::Diff::html_word_diff( $expected, $actual );
    my $failed = 0;
    my $rex = ( $opts =~ /\brex\b/ );
    my $okset = "";

    foreach my $diff ( @$diffs ) {
        my $a = $diff->[1];
        $a =~ s/^\s+//;
        $a =~ s/\s+$//s;
        my $b = $diff->[2];
        $b =~ s/^\s+//;
        $b =~ s/\s+$//s;
        my $ok = 0;

        if ( $diff->[0] eq 'u' || $a eq $b || $rex && _rexeq( $a, $b ) ||
             tagSame($a, $b)) {
            $ok = 1;
        }
        $a = _tidy( $a );
        $b = _tidy( $b );
        if ( $ok ) {
            $okset .= "$a ";
        } else {
            if( $okset ) {
                $result .=
                  CGI::Tr({}, CGI::td({valign=>'top', colspan=>2},
                                      CGI::code($okset)));
                $okset = "";
            }
            $result .= CGI::Tr({valign=>'top'},
                               CGI::td({bgcolor=>'#99ffcc'},CGI::pre($a))).
                       CGI::Tr({valign=>'top'},
                               CGI::td({bgcolor=>'#ffccff'},CGI::pre($b)));
            $failed = 1;
        }
    }
    return '' unless $failed;
    if( $okset ) {
        $result .= CGI::Tr({}, CGI::td({valign=>'top', colspan=>2},
                                       CGI::code($okset)));
    }
    return CGI::table({border=>1},
      CGI::Tr(CGI::th({}, 'Expected '.$opts).$result));
}

sub _rexeq {
    my ( $a, $b ) = @_;

    my @res;
    while ( $a =~ s/\@REX\((.*?)\)/!REX@res!/ ) {
        push( @res, $1 );
    }
    # escape regular expression chars
    $a =~ s/([\[\]\(\)\\\?\*\+\.\/\^\$])/\\$1/g;
    $a =~ s/\@DATE/[0-3]\\d [JFMASOND][aepuco][nbrylgptvc] [12][09]\\d\\d/g;
    $a =~ s/\@TIME/[012]\\d:[0-5]\\d/g;
    my $wikiword = "[A-Z]+[a-z]+[A-Z]+[a-z]+";
    $a =~ s/\@WIKIWORD/$wikiword/og;
    my $satWord = '<a [^>]*class="twikiLink"[^>]*>'.$wikiword.'</a>';
    my $unsatWord = '<span [^>]*class="twikiNewLink"[^>]*>'.$wikiword.'<a [^>]*><sup>\?</sup></a></span>';
    $a =~ s/\@WIKINAME/($satWord|$unsatWord)/og;
    $a =~ s/!REX(\d+)!/$res[$1]/g;
    $a =~ s!/!\/!g;

    return $b =~ /^$a$/;
}

sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    TWiki::Func::registerTagHandler('STRICTTAG', \&_STRICTTAG);

    return 1;
}

sub commonTagsHandler {
    $_[0] =~ s/%FRIENDLYTAG{(.*?)}%/&_extractParams($1)/ge;
}

sub tagSame {
    my( $a, $b ) = @_;

    return 0 unless ($a =~ /^\s*<\/?(\w+)\s+(.*?)>\s*$/i);
    my $tag = $1;
    my $pa = $2;
    return 0 unless $b =~  /^\s*<\/?$tag\s+(.*?)>\s*$/i;
    my $pb = $1;
    return paramsSame($pa, $pb);
}

sub paramsSame {
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

sub _extractParams {
    my $params = new TWiki::Attrs(shift, 1);
    return $params->stringify();
}

sub _STRICTTAG {
    my( $session, $params ) = @_;

    return $params->stringify();
}

my $iph = 0;
my $oph = 0;
sub preRenderingHandler {
    $iph = 0;
    $oph = 0;
}

sub outsidePREHandler {
    # Replace the text "%outsidePREHandler%" with some
    # recognisable text.
    $oph++;
    $_[0] =~ s/%outsidePreHandler(\d+)%/$1OPH${oph}_line1\n$1OPH${oph}_line2\n$1OPH${oph}_line3\n/g;
}

sub insidePREHandler {
    # Replace the text "%insidePREHandler%" with some
    # recognisable text.
    $iph++;
    $_[0] =~ s/%insidePreHandler(\d+)%/$1IPH${iph}_line1\n$1IPH${iph}_line2\n$1IPH${iph}_line3\n/g;
}

sub postRenderingHandler {
    my $q = TWiki::Func::getCgiQuery();
    my $t;
    $t = $q->param( 'test' ) if ( $q );
    $t = '' unless $t;

    if ( $t eq 'compare' && $_[0] =~ /<!--\s*actual\s*-->/ ) {
        my ( $meta, $expected ) = TWiki::Func::readTopic( $web, $topic );
        my $res = _compareExpectedWithActual( _parse( $expected, 'expected' ),
                                              _parse( $_[0], 'actual' ),
                                              $topic, $web);
        if ( $res ) {
            $res = "<font color=\"red\">TESTS FAILED</font><p />$res";
        } else {
            $res = "<font color=\"green\">ALL TESTS PASSED</font>";
        }
        $_[0] = $res;
    }
}

1;
