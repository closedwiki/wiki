package com.ccsoft.edit.tags;

import junit.framework.*;
import java.io.*;

public class EntityExpandingReaderTest extends TestCase {

    public EntityExpandingReaderTest(String name) {
	super(name);
    }

    public static Test suite() {
	return new TestSuite(EntityExpandingReaderTest.class);
    }

    private void check(String in, String out) throws Exception {
	Reader r = new EntityExpandingReader(new StringReader(in));
	char[] cbuf = new char[100];
	int n = r.read(cbuf, 0, cbuf.length);
	assert("" + n, n > 0);
	String s = new String(cbuf, 0, n);
	assert(s + " != " + out, out.equals(s));
    }

    public void test1Simple() throws Exception {
	check("&nbsp;", "" + (char)0xA0);
	check("&iexcl;", "" + (char)0xA1);
	check("&cent;", "" + (char)0xA2);
	check("&pound;", "" + (char)0xA3);
	check("&curren;", "" + (char)0xA4);
	check("&yen;", "" + (char)0xA5);
	check("&brvbar;", "" + (char)0xA6);
	check("&sect;", "" + (char)0xA7);
	check("&uml;", "" + (char)0xA8);
	check("&copy;", "" + (char)0xA9);
	check("&ordf;", "" + (char)0xAA);
	check("&laquo;", "" + (char)0xAB);
	check("&not;", "" + (char)0xAC);
	check("&shy;", "" + (char)0xAD);
	check("&reg;", "" + (char)0xAE);
	check("&macr;", "" + (char)0xAF);
	check("&deg;", "" + (char)0xB0);
	check("&plusmn;", "" + (char)0xB1);
	check("&sup2;", "" + (char)0xB2);
	check("&sup3;", "" + (char)0xB3);
	check("&acute;", "" + (char)0xB4);
	check("&micro;", "" + (char)0xB5);
	check("&para;", "" + (char)0xB6);
	check("&middot;", "" + (char)0xB7);
	check("&cedil;", "" + (char)0xB8);
	check("&sup1;", "" + (char)0xB9);
	check("&ordm;", "" + (char)0xBA);
	check("&raquo;", "" + (char)0xBB);
	check("&frac14;", "" + (char)0xBC);
	check("&frac12;", "" + (char)0xBD);
	check("&frac34;", "" + (char)0xBE);
	check("&iquest;", "" + (char)0xBF);
	check("&Agrave;", "" + (char)0xC0);
	check("&Aacute;", "" + (char)0xC1);
	check("&Acirc;", "" + (char)0xC2);
	check("&Atilde;", "" + (char)0xC3);
	check("&Auml;", "" + (char)0xC4);
	check("&Aring;", "" + (char)0xC5);
	check("&AElig;", "" + (char)0xC6);
	check("&Ccedil;", "" + (char)0xC7);
	check("&Egrave;", "" + (char)0xC8);
	check("&Eacute;", "" + (char)0xC9);
	check("&Ecirc;", "" + (char)0xCA);
	check("&Euml;", "" + (char)0xCB);
	check("&Igrave;", "" + (char)0xCC);
	check("&Iacute;", "" + (char)0xCD);
	check("&Icirc;", "" + (char)0xCE);
	check("&Iuml;", "" + (char)0xCF);
	check("&ETH;", "" + (char)0xD0);
	check("&Ntilde;", "" + (char)0xD1);
	check("&Ograve;", "" + (char)0xD2);
	check("&Oacute;", "" + (char)0xD3);
	check("&Ocirc;", "" + (char)0xD4);
	check("&Otilde;", "" + (char)0xD5);
	check("&Ouml;", "" + (char)0xD6);
	check("&times;", "" + (char)0xD7);
	check("&Oslash;", "" + (char)0xD8);
	check("&Ugrave;", "" + (char)0xD9);
	check("&Uacute;", "" + (char)0xDA);
	check("&Ucirc;", "" + (char)0xDB);
	check("&Uuml;", "" + (char)0xDC);
	check("&Yacute;", "" + (char)0xDD);
	check("&THORN;", "" + (char)0xDE);
	check("&szlig;", "" + (char)0xDF);
	check("&agrave;", "" + (char)0xE0);
	check("&aacute;", "" + (char)0xE1);
	check("&acirc;", "" + (char)0xE2);
	check("&atilde;", "" + (char)0xE3);
	check("&auml;", "" + (char)0xE4);
	check("&aring;", "" + (char)0xE5);
	check("&aelig;", "" + (char)0xE6);
	check("&ccedil;", "" + (char)0xE7);
	check("&egrave;", "" + (char)0xE8);
	check("&eacute;", "" + (char)0xE9);
	check("&ecirc;", "" + (char)0xEA);
	check("&euml;", "" + (char)0xEB);
	check("&igrave;", "" + (char)0xEC);
	check("&iacute;", "" + (char)0xED);
	check("&icirc;", "" + (char)0xEE);
	check("&iuml;", "" + (char)0xEF);
	check("&eth;", "" + (char)0xF0);
	check("&ntilde;", "" + (char)0xF1);
	check("&ograve;", "" + (char)0xF2);
	check("&oacute;", "" + (char)0xF3);
	check("&ocirc;", "" + (char)0xF4);
	check("&otilde;", "" + (char)0xF5);
	check("&ouml;", "" + (char)0xF6);
	check("&divide;", "" + (char)0xF7);
	check("&oslash;", "" + (char)0xF8);
	check("&ugrave;", "" + (char)0xF9);
	check("&uacute;", "" + (char)0xFA);
	check("&ucirc;", "" + (char)0xFB);
	check("&uuml;", "" + (char)0xFC);
	check("&yacute;", "" + (char)0xFD);
	check("&thorn;", "" + (char)0xFE);
	check("&yuml;", "" + (char)0xFF);
	check("&fnof;", "" + (char)0x192);
	check("&Alpha;", "" + (char)0x391);
	check("&Beta;", "" + (char)0x392);
	check("&Gamma;", "" + (char)0x393);
	check("&Delta;", "" + (char)0x394);
	check("&Epsilon;", "" + (char)0x395);
	check("&Zeta;", "" + (char)0x396);
	check("&Eta;", "" + (char)0x397);
	check("&Theta;", "" + (char)0x398);
	check("&Iota;", "" + (char)0x399);
	check("&Kappa;", "" + (char)0x39A);
	check("&Lambda;", "" + (char)0x39B);
	check("&Mu;", "" + (char)0x39C);
	check("&Nu;", "" + (char)0x39D);
	check("&Xi;", "" + (char)0x39E);
	check("&Omicron;", "" + (char)0x39F);
	check("&Pi;", "" + (char)0x3A0);
	check("&Rho;", "" + (char)0x3A1);
	check("&Sigma;", "" + (char)0x3A3);
	check("&Tau;", "" + (char)0x3A4);
	check("&Upsilon;", "" + (char)0x3A5);
	check("&Phi;", "" + (char)0x3A6);
	check("&Chi;", "" + (char)0x3A7);
	check("&Psi;", "" + (char)0x3A8);
	check("&Omega;", "" + (char)0x3A9);
	check("&alpha;", "" + (char)0x3B1);
	check("&beta;", "" + (char)0x3B2);
	check("&gamma;", "" + (char)0x3B3);
	check("&delta;", "" + (char)0x3B4);
	check("&epsilon;", "" + (char)0x3B5);
	check("&zeta;", "" + (char)0x3B6);
	check("&eta;", "" + (char)0x3B7);
	check("&theta;", "" + (char)0x3B8);
	check("&iota;", "" + (char)0x3B9);
	check("&kappa;", "" + (char)0x3BA);
	check("&lambda;", "" + (char)0x3BB);
	check("&mu;", "" + (char)0x3BC);
	check("&nu;", "" + (char)0x3BD);
	check("&xi;", "" + (char)0x3BE);
	check("&omicron;", "" + (char)0x3BF);
	check("&pi;", "" + (char)0x3C0);
	check("&rho;", "" + (char)0x3C1);
	check("&sigmaf;", "" + (char)0x3C2);
	check("&sigma;", "" + (char)0x3C3);
	check("&tau;", "" + (char)0x3C4);
	check("&upsilon;", "" + (char)0x3C5);
	check("&phi;", "" + (char)0x3C6);
	check("&chi;", "" + (char)0x3C7);
	check("&psi;", "" + (char)0x3C8);
	check("&omega;", "" + (char)0x3C9);
	check("&thetasym;", "" + (char)0x3D1);
	check("&upsih;", "" + (char)0x3D2);
	check("&piv;", "" + (char)0x3D6);
	check("&bull;", "" + (char)0x2022);
	check("&hellip;", "" + (char)0x2026);
	check("&prime;", "" + (char)0x2032);
	check("&Prime;", "" + (char)0x2033);
	check("&oline;", "" + (char)0x203E);
	check("&frasl;", "" + (char)0x2044);
	check("&weierp;", "" + (char)0x2118);
	check("&image;", "" + (char)0x2111);
	check("&real;", "" + (char)0x211C);
	check("&trade;", "" + (char)0x2122);
	check("&alefsym;", "" + (char)0x2135);
	check("&larr;", "" + (char)0x2190);
	check("&uarr;", "" + (char)0x2191);
	check("&rarr;", "" + (char)0x2192);
	check("&darr;", "" + (char)0x2193);
	check("&harr;", "" + (char)0x2194);
	check("&crarr;", "" + (char)0x21B5);
	check("&lArr;", "" + (char)0x21D0);
	check("&uArr;", "" + (char)0x21D1);
	check("&rArr;", "" + (char)0x21D2);
	check("&dArr;", "" + (char)0x21D3);
	check("&hArr;", "" + (char)0x21D4);
	check("&forall;", "" + (char)0x2200);
	check("&part;", "" + (char)0x2202);
	check("&exist;", "" + (char)0x2203);
	check("&empty;", "" + (char)0x2205);
	check("&nabla;", "" + (char)0x2207);
	check("&isin;", "" + (char)0x2208);
	check("&notin;", "" + (char)0x2209);
	check("&ni;", "" + (char)0x220B);
	check("&prod;", "" + (char)0x220F);
	check("&sum;", "" + (char)0x2211);
	check("&minus;", "" + (char)0x2212);
	check("&lowast;", "" + (char)0x2217);
	check("&radic;", "" + (char)0x221A);
	check("&prop;", "" + (char)0x221D);
	check("&infin;", "" + (char)0x221E);
	check("&ang;", "" + (char)0x2220);
	check("&and;", "" + (char)0x2227);
	check("&or;", "" + (char)0x2228);
	check("&cap;", "" + (char)0x2229);
	check("&cup;", "" + (char)0x222A);
	check("&int;", "" + (char)0x222B);
	check("&there4;", "" + (char)0x2234);
	check("&sim;", "" + (char)0x223C);
	check("&cong;", "" + (char)0x2245);
	check("&asymp;", "" + (char)0x2248);
	check("&ne;", "" + (char)0x2260);
	check("&equiv;", "" + (char)0x2261);
	check("&le;", "" + (char)0x2264);
	check("&ge;", "" + (char)0x2265);
	check("&sub;", "" + (char)0x2282);
	check("&sup;", "" + (char)0x2283);
	check("&nsub;", "" + (char)0x2284);
	check("&sube;", "" + (char)0x2286);
	check("&supe;", "" + (char)0x2287);
	check("&oplus;", "" + (char)0x2295);
	check("&otimes;", "" + (char)0x2297);
	check("&perp;", "" + (char)0x22A5);
	check("&sdot;", "" + (char)0x22C5);
	check("&lceil;", "" + (char)0x2308);
	check("&rceil;", "" + (char)0x2309);
	check("&lfloor;", "" + (char)0x230A);
	check("&rfloor;", "" + (char)0x230B);
	check("&lang;", "" + (char)0x2329);
	check("&rang;", "" + (char)0x232A);
	check("&loz;", "" + (char)0x25CA);
	check("&spades;", "" + (char)0x2660);
	check("&clubs;", "" + (char)0x2663);
	check("&hearts;", "" + (char)0x2665);
	check("&diams;", "" + (char)0x2666);
	check("&quot;", "" + (char)0x22);
	check("&amp;", "" + (char)0x26);
	check("&lt;", "" + (char)0x3C);
	check("&gt;", "" + (char)0x3E);
	check("&OElig;", "" + (char)0x152);
	check("&oelig;", "" + (char)0x153);
	check("&Scaron;", "" + (char)0x160);
	check("&scaron;", "" + (char)0x161);
	check("&Yuml;", "" + (char)0x178);
	check("&circ;", "" + (char)0x2C6);
	check("&tilde;", "" + (char)0x2DC);
	check("&ensp;", "" + (char)0x2002);
	check("&emsp;", "" + (char)0x2003);
	check("&thinsp;", "" + (char)0x2009);
	check("&zwnj;", "" + (char)0x200C);
	check("&zwj;", "" + (char)0x200D);
	check("&lrm;", "" + (char)0x200E);
	check("&rlm;", "" + (char)0x200F);
	check("&ndash;", "" + (char)0x2013);
	check("&mdash;", "" + (char)0x2014);
	check("&lsquo;", "" + (char)0x2018);
	check("&rsquo;", "" + (char)0x2019);
	check("&sbquo;", "" + (char)0x201A);
	check("&ldquo;", "" + (char)0x201C);
	check("&rdquo;", "" + (char)0x201D);
	check("&bdquo;", "" + (char)0x201E);
	check("&dagger;", "" + (char)0x2020);
	check("&Dagger;", "" + (char)0x2021);
	check("&permil;", "" + (char)0x2030);
	check("&lsaquo;", "" + (char)0x2039);
	check("&rsaquo;", "" + (char)0x203A);
    }
    
    public void test2Open() throws Exception {
	check("&rsaquo bollocks", "&rsaquo bollocks");
	check("&rsaquo", "&rsaquo");
    }

    public void test3Expand() throws Exception {
	check("&amp;amp;", "&amp;");
	check("&amp;#95;", "&#95;");
	check("&amp;#a4;", "&#a4;");
    }

    public void test4Number() throws Exception {
	check("&#91;&#93;", "[]");
	check("&#x5b;&#X5D;", "[]");
    }

    public void test5BadNumber() throws Exception {
	check("&#9a3;", "&#9a3;");
	check("&#x5yb;&#x5yD;", "&#x5yb;&#x5yD;");
    }

    public void test6BadName() throws Exception {
	check("&bollocks;", "&bollocks;");
    }
}
