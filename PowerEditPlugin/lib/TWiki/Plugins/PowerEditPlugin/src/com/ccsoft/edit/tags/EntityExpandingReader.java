package com.ccsoft.edit.tags;

import java.io.*;
import java.util.Hashtable;

public class EntityExpandingReader extends PushbackReader {
    private static final Hashtable entities = new Hashtable();

    private static final void addEntity(String e, int c) {
	entities.put(e, new Character((char)c));
    }

    static {
	addEntity("nbsp", 0xA0);	addEntity("iexcl", 0xA1);
	addEntity("cent", 0xA2);	addEntity("pound", 0xA3);
	addEntity("curren", 0xA4);	addEntity("yen", 0xA5);
	addEntity("brvbar", 0xA6);	addEntity("sect", 0xA7);
	addEntity("uml", 0xA8);		addEntity("copy", 0xA9);
	addEntity("ordf", 0xAA);	addEntity("laquo", 0xAB);
	addEntity("not", 0xAC);		addEntity("shy", 0xAD);
	addEntity("reg", 0xAE);		addEntity("macr", 0xAF);
	addEntity("deg", 0xB0);		addEntity("plusmn", 0xB1);
	addEntity("sup2", 0xB2);	addEntity("sup3", 0xB3);
	addEntity("acute", 0xB4);	addEntity("micro", 0xB5);
	addEntity("para", 0xB6);	addEntity("middot", 0xB7);
	addEntity("cedil", 0xB8);	addEntity("sup1", 0xB9);
	addEntity("ordm", 0xBA);	addEntity("raquo", 0xBB);
	addEntity("frac14", 0xBC);	addEntity("frac12", 0xBD);
	addEntity("frac34", 0xBE);	addEntity("iquest", 0xBF);
	addEntity("Agrave", 0xC0);	addEntity("Aacute", 0xC1);
	addEntity("Acirc", 0xC2);	addEntity("Atilde", 0xC3);
	addEntity("Auml", 0xC4);	addEntity("Aring", 0xC5);
	addEntity("AElig", 0xC6);	addEntity("Ccedil", 0xC7);
	addEntity("Egrave", 0xC8);	addEntity("Eacute", 0xC9);
	addEntity("Ecirc", 0xCA);	addEntity("Euml", 0xCB);
	addEntity("Igrave", 0xCC);	addEntity("Iacute", 0xCD);
	addEntity("Icirc", 0xCE);	addEntity("Iuml", 0xCF);
	addEntity("ETH", 0xD0);		addEntity("Ntilde", 0xD1);
	addEntity("Ograve", 0xD2);	addEntity("Oacute", 0xD3);
	addEntity("Ocirc", 0xD4);	addEntity("Otilde", 0xD5);
	addEntity("Ouml", 0xD6);	addEntity("times", 0xD7);
	addEntity("Oslash", 0xD8);	addEntity("Ugrave", 0xD9);
	addEntity("Uacute", 0xDA);	addEntity("Ucirc", 0xDB);
	addEntity("Uuml", 0xDC);	addEntity("Yacute", 0xDD);
	addEntity("THORN", 0xDE);	addEntity("szlig", 0xDF);
	addEntity("agrave", 0xE0);	addEntity("aacute", 0xE1);
	addEntity("acirc", 0xE2);	addEntity("atilde", 0xE3);
	addEntity("auml", 0xE4);	addEntity("aring", 0xE5);
	addEntity("aelig", 0xE6);	addEntity("ccedil", 0xE7);
	addEntity("egrave", 0xE8);	addEntity("eacute", 0xE9);
	addEntity("ecirc", 0xEA);	addEntity("euml", 0xEB);
	addEntity("igrave", 0xEC);	addEntity("iacute", 0xED);
	addEntity("icirc", 0xEE);	addEntity("iuml", 0xEF);
	addEntity("eth", 0xF0);		addEntity("ntilde", 0xF1);
	addEntity("ograve", 0xF2);	addEntity("oacute", 0xF3);
	addEntity("ocirc", 0xF4);	addEntity("otilde", 0xF5);
	addEntity("ouml", 0xF6);	addEntity("divide", 0xF7);
	addEntity("oslash", 0xF8);	addEntity("ugrave", 0xF9);
	addEntity("uacute", 0xFA);	addEntity("ucirc", 0xFB);
	addEntity("uuml", 0xFC);	addEntity("yacute", 0xFD);
	addEntity("thorn", 0xFE);	addEntity("yuml", 0xFF);
	addEntity("fnof", 0x192);	addEntity("Alpha", 0x391);
	addEntity("Beta", 0x392);	addEntity("Gamma", 0x393);
	addEntity("Delta", 0x394);	addEntity("Epsilon", 0x395);
	addEntity("Zeta", 0x396);	addEntity("Eta", 0x397);
	addEntity("Theta", 0x398);	addEntity("Iota", 0x399);
	addEntity("Kappa", 0x39A);	addEntity("Lambda", 0x39B);
	addEntity("Mu", 0x39C);		addEntity("Nu", 0x39D);
	addEntity("Xi", 0x39E);		addEntity("Omicron", 0x39F);
	addEntity("Pi", 0x3A0);		addEntity("Rho", 0x3A1);
	addEntity("Sigma", 0x3A3);	addEntity("Tau", 0x3A4);
	addEntity("Upsilon", 0x3A5);	addEntity("Phi", 0x3A6);
	addEntity("Chi", 0x3A7);	addEntity("Psi", 0x3A8);
	addEntity("Omega", 0x3A9);	addEntity("alpha", 0x3B1);
	addEntity("beta", 0x3B2);	addEntity("gamma", 0x3B3);
	addEntity("delta", 0x3B4);	addEntity("epsilon", 0x3B5);
	addEntity("zeta", 0x3B6);	addEntity("eta", 0x3B7);
	addEntity("theta", 0x3B8);	addEntity("iota", 0x3B9);
	addEntity("kappa", 0x3BA);	addEntity("lambda", 0x3BB);
	addEntity("mu", 0x3BC);		addEntity("nu", 0x3BD);
	addEntity("xi", 0x3BE);		addEntity("omicron", 0x3BF);
	addEntity("pi", 0x3C0);		addEntity("rho", 0x3C1);
	addEntity("sigmaf", 0x3C2);	addEntity("sigma", 0x3C3);
	addEntity("tau", 0x3C4);	addEntity("upsilon", 0x3C5);
	addEntity("phi", 0x3C6);	addEntity("chi", 0x3C7);
	addEntity("psi", 0x3C8);	addEntity("omega", 0x3C9);
	addEntity("thetasym", 0x3D1);	addEntity("upsih", 0x3D2);
	addEntity("piv", 0x3D6);	addEntity("bull", 0x2022);
	addEntity("hellip", 0x2026);	addEntity("prime", 0x2032);
	addEntity("Prime", 0x2033);	addEntity("oline", 0x203E);
	addEntity("frasl", 0x2044);	addEntity("weierp", 0x2118);
	addEntity("image", 0x2111);	addEntity("real", 0x211C);
	addEntity("trade", 0x2122);	addEntity("alefsym", 0x2135);
	addEntity("larr", 0x2190);	addEntity("uarr", 0x2191);
	addEntity("rarr", 0x2192);	addEntity("darr", 0x2193);
	addEntity("harr", 0x2194);	addEntity("crarr", 0x21B5);
	addEntity("lArr", 0x21D0);	addEntity("uArr", 0x21D1);
	addEntity("rArr", 0x21D2);	addEntity("dArr", 0x21D3);
	addEntity("hArr", 0x21D4);	addEntity("forall", 0x2200);
	addEntity("part", 0x2202);	addEntity("exist", 0x2203);
	addEntity("empty", 0x2205);	addEntity("nabla", 0x2207);
	addEntity("isin", 0x2208);	addEntity("notin", 0x2209);
	addEntity("ni", 0x220B);	addEntity("prod", 0x220F);
	addEntity("sum", 0x2211);	addEntity("minus", 0x2212);
	addEntity("lowast", 0x2217);	addEntity("radic", 0x221A);
	addEntity("prop", 0x221D);	addEntity("infin", 0x221E);
	addEntity("ang", 0x2220);	addEntity("and", 0x2227);
	addEntity("or", 0x2228);	addEntity("cap", 0x2229);
	addEntity("cup", 0x222A);	addEntity("int", 0x222B);
	addEntity("there4", 0x2234);	addEntity("sim", 0x223C);
	addEntity("cong", 0x2245);	addEntity("asymp", 0x2248);
	addEntity("ne", 0x2260);	addEntity("equiv", 0x2261);
	addEntity("le", 0x2264);	addEntity("ge", 0x2265);
	addEntity("sub", 0x2282);	addEntity("sup", 0x2283);
	addEntity("nsub", 0x2284);	addEntity("sube", 0x2286);
	addEntity("supe", 0x2287);	addEntity("oplus", 0x2295);
	addEntity("otimes", 0x2297);	addEntity("perp", 0x22A5);
	addEntity("sdot", 0x22C5);	addEntity("lceil", 0x2308);
	addEntity("rceil", 0x2309);	addEntity("lfloor", 0x230A);
	addEntity("rfloor", 0x230B);	addEntity("lang", 0x2329);
	addEntity("rang", 0x232A);	addEntity("loz", 0x25CA);
	addEntity("spades", 0x2660);	addEntity("clubs", 0x2663);
	addEntity("hearts", 0x2665);	addEntity("diams", 0x2666);
	addEntity("quot", 0x22);	addEntity("amp", 0x26);
	addEntity("lt", 0x3C);		addEntity("gt", 0x3E);
	addEntity("OElig", 0x152);	addEntity("oelig", 0x153);
	addEntity("Scaron", 0x160);	addEntity("scaron", 0x161);
	addEntity("Yuml", 0x178);	addEntity("circ", 0x2C6);
	addEntity("tilde", 0x2DC);	addEntity("ensp", 0x2002);
	addEntity("emsp", 0x2003);	addEntity("thinsp", 0x2009);
	addEntity("zwnj", 0x200C);	addEntity("zwj", 0x200D);
	addEntity("lrm", 0x200E);	addEntity("rlm", 0x200F);
	addEntity("ndash", 0x2013);	addEntity("mdash", 0x2014);
	addEntity("lsquo", 0x2018);	addEntity("rsquo", 0x2019);
	addEntity("sbquo", 0x201A);	addEntity("ldquo", 0x201C);
	addEntity("rdquo", 0x201D);	addEntity("bdquo", 0x201E);
	addEntity("dagger", 0x2020);	addEntity("Dagger", 0x2021);
	addEntity("permil", 0x2030);	addEntity("lsaquo", 0x2039);
	addEntity("rsaquo", 0x203A);
    };

    public EntityExpandingReader(Reader r) {
	super(r, 100);
    }

    /**
     * Override to expand entitities
     */
    public int read() throws IOException {
	// Read a single character.
	int ch = super.read();
	if (ch == '&') {
	    return readEntity();
	}
	return ch;
    }

    private int readEntity() throws IOException {
	int ch = super.read();
	String name = "";
	boolean isNumber = false;
	int isHex = -1;
	if (ch == '#') {
	    isNumber = true;
	    ch = super.read();
	    try {
		if (ch == 'x' || ch == 'X') {
		    isHex = ch;
		    ch = super.read();
		    while ('a' <= ch && ch <= 'f' ||
			   'A' <= ch && ch <= 'F' ||
			   '0' <= ch && ch <= '9') {
			name += (char)ch;
			ch = super.read();
		    }
		    if (ch == ';')
			return Integer.parseInt(name, 16);
		} else {
		    while ('0' <= ch && ch <= '9') {
			name += (char)ch;
			ch = super.read();
		    }
		    if (ch == ';')
			return Integer.parseInt(name);
		}
	    } catch (NumberFormatException nfe) {
	    }
	} else {
	    while ('a' <= ch && ch <= 'z' || 'A' <= ch && ch <= 'Z' ||
		   '0' <= ch && ch <= '9') {
		name += (char)ch;
		ch = super.read();
	    }
	    if (ch == ';') {
		Character entval = (Character)entities.get(name);
		if (entval != null)
		    return entval.charValue();
	    }
	}

	// failed, unread back to start
	if (ch != -1)
	    unread(ch);
	if (name.length() > 0)
	    unread(name.toCharArray());
	if (isHex != -1)
	    unread(isHex);
	if (isNumber)
	    unread('#');
	return '&';
    }

    public int read(char[] cbuf, int off, int len) throws IOException {
	int i = 0;
	int ch = read();
	if (ch == -1)
	    return -1;
	while (i < len && ch != -1) {
	    cbuf[off + i] = (char)ch;
	    i++;
	    ch = read();
	    if (ch == -1)
		break;
	}
	return i;
    }

    public static final char getEntity(String name) {
	return ((Character)entities.get(name)).charValue();
    }
}
