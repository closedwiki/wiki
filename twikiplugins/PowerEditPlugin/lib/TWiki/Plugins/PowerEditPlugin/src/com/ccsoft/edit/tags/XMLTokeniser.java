// Copyright (C) Crawford Currie 2004 - All rights reserved
// It is hereby granted that this software can be used, copied, 
// modified, and distributed without fee provided that this 
// copyright notice appears in all copies.
package com.ccsoft.edit.tags;

import java.io.*;
import java.util.Locale;
import java.util.Hashtable;

/**
 * Simple tokeniser that recognises XML, at least as far
 * as the XHTML1.0 spec requires.
 */
public class XMLTokeniser {
    public static final int WORD = 1;
    public static final int TAG = 2;
    public static final int EOF = 3;

    private int nextch;
    private int inputLeft;
    private Reader source;
    private int markedAt;
    private int markch;
    private int markline;
    private int lineno;

    /** The most recent tag or word read by the tokeniser */
    public String string;
    /** true if we want whitespace */
    public boolean isPreformatted;
    /** The most recent attribute set read by the tokeniser */
    public TagAttributes attrs;

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

    public boolean whitespaceMode(boolean mode) {
	boolean oldmode = isPreformatted;
	isPreformatted = mode;
	return oldmode;
    }

    public static final char getEntity(String name) {
	return ((Character)entities.get(name)).charValue();
    }

    /** Helper function to expand entities into their literal
     * conterparts. Useful when processing parameters to an applet. */
    public static String decode(String s) {
	XMLTokeniser t = new XMLTokeniser(new StringReader(s), s.length());
	return t.readCDATA(-1);
    }

    /**
     * Create a tokeniser to read from the given reader, with an estimate for
     * the total length of the input text..
     */
    public XMLTokeniser(Reader source, int inputLength) {
	this.source = source;
	inputLeft = inputLength;
	readch();
	string = "body";
	attrs = null;
	lineno = 1;
    }

    /**
     * Get the next character
     */
    private void readch() {
	try {
	    nextch = source.read();
	    inputLeft--;
	    if (nextch == '\n')
		lineno++;
	} catch (IOException ioe) {
	    throw new Error("ASSERT");
	}
    }

    public int getLineNumber() {
	return lineno;
    }

    private final boolean onWhite() {
	return nextch == ' ' || nextch == '\t' ||
	    nextch == '\r' || nextch == '\n';
    }

    private final boolean onAlpha() {
	return 'a' <= nextch && nextch <= 'z' ||
	    'A' <= nextch && nextch <= 'Z';
    }

    private final boolean onDigit() {
	return '0' <= nextch && nextch <= '9';
    }

    private void skipWhite() {
	// skip whitespace
	while (onWhite())
	    readch();
    }

    /** From the HTML manual:
     * The attribute value is delimited by single or double
     * quotes. The quotes are optional if the attribute value
     * consists solely of letters in the range A-Z and a-z,
     * digits (0-9), hyphens ("-"), and periods (".").
     * <p>
     * We add other common characters.
     */
    private final boolean onAttrVal() {
	return onAlpha() || onDigit() || nextch == '-' || nextch == '.' ||

	    nextch == '%' ||
	    nextch == ':' ||
	    nextch == '.' ||
	    nextch == '_' ||
	    nextch == '+';
    }

    private void setMark() {
	markedAt = inputLeft;
	markch = nextch;
	markline = lineno;
	try {
	    source.mark(inputLeft);
	} catch (IOException ioe) {
	    throw new Error("ASSERT");
	}
    }

    private void resetToMark() {
	try {
	    source.reset();
	} catch (IOException io) {
	    throw new Error("ASSERT");
	}
	inputLeft = markedAt;
	nextch = markch;
	lineno = markline;
    }

    /** parked on a "&" */
    private String readEntity() {
	readch();	// skip the &
	String name = "";
	char ent = 0;
	boolean valid = false;
	boolean isNumber = false;
	if (nextch == '#') {
	    readch();
	    isNumber = true;
	}
	while (onAlpha() || onDigit()) {
	    name += (char)nextch;
	    readch();
	}
	if (nextch == ';') {
	    try {
		if (isNumber) {
		    if ('0' <= name.charAt(0) && name.charAt(0) <= '9') {
			// decimal
			ent = (char)Integer.parseInt(name);
			valid = true;
		    } else if (name.charAt(0) == 'X' ||
			       name.charAt(0) == 'x') {
			// hex
			ent = (char)Integer.parseInt(name.substring(1), 16);
			valid = true;
		    }
		} else {
		    Character entval = (Character)entities.get(name);
		    if (entval != null) {
			ent = entval.charValue();
			valid = true;
		    }
		}
	    } catch (NumberFormatException nfe) {
	    }
	}
	if (valid) {
	    readch();	// skip the ;
	    return "" + ent;
	} else
	    return '&' + name;
    }

    /** static so it can be used in decode() */
    private String readCDATA(int closer) {
	String val = "";
	while (nextch != -1 &&
	       ((closer != 0 && nextch != closer) ||
		(closer == 0 && onAttrVal()))) {
	    if (nextch == '&')
		val += readEntity();
	    else {
		val += (char)nextch;
		readch();
	    }
	}
	return val;
    }

    /**
     * Get the next token from the reader
     */
    public int nextToken() {
	string = "";
	attrs = null;
	String whitespace = "";

	for (;;) {
	    while (onWhite()) {
		if (nextch == '\t')
		    whitespace += "   ";
		else if (nextch == ' ')
		    whitespace += (char)nextch;
		else if (nextch == '\n') {
		    if (isPreformatted) {
			readch();
			string = "br";
			//System.out.println("<BR>");
			return TAG;
		    }
		}
		readch();
	    }
	    
	    if (nextch != '<')
		break;

	    setMark();
	    readch();
	    if (nextch != '!') {
		resetToMark();
		break;
	    }

	    // Comment block or DOCUMENTTYPE tag
	    // SGML says: A comment declaration starts with <!, followed by
	    // zero or more comments, followed by >. A comment starts and
	    //  ends with "--", and does not contain any occurrence of "--". 
	    // This means that the following are all legal SGML comments: 
	    // 1.<!-- Hello --> 
	    // 2.<!-- Hello -- -- Hello--> 
	    // 3.<!----> 
	    // 4.<!------ Hello --> 
	    // 5.<!>
	    // 6.<!------> hello-->
	    // In the interests of brevity, we're going to get this wrong,
	    // deliberately..
	    do {
		readch();
	    } while (nextch != '>' && nextch != -1);
	    readch();
	}

	if (nextch == -1)
	    return EOF;

	if (nextch == '<') {
	    String tag = "";
	    boolean isEndTag = false;
	    setMark();
	    readch();
	    if (nextch == '/') {
		tag += (char)nextch;
		readch();
		isEndTag = true;
	    }
	    while (onAlpha() || onDigit()) {
		tag += (char)nextch;
		readch();
	    }
	    skipWhite();

	    attrs = new TagAttributes();
	    while (!isEndTag && onAlpha()) {
		String attr = "";
		while (onAlpha()) {
		    attr += (char)nextch;
		    readch();
		}
		skipWhite();
		if (nextch != '=')
		    break;
		readch();
		skipWhite();
		int closer = 0;
		if (nextch == '\'' || nextch == '"') {
		    closer = nextch;
		    readch();
		}
		attrs.put(attr.toLowerCase(), readCDATA(closer));
		if (nextch == closer)
		    readch();
		skipWhite();
	    }
	    if (!isEndTag && nextch == '/') {
		readch();
	    }
	    
	    if (nextch == '>') {
		readch();
		string = tag.toLowerCase();
		//System.out.println("TAG <" + tag + " " + attrs + ">" + nextch);
		return TAG;
	    }
	    // reset to mark, and drop through to word reader
	    resetToMark();
	    attrs = null;
	}
	
	// read a word
	do {
	    if (nextch == '&') {
		string += readEntity();
	    } else {
		string += (char)nextch;
		readch();
	    }
	} while (!onWhite() &&
		 nextch != -1 &&
		 nextch != '<');

	if (isPreformatted) {
	    string = whitespace + string;
	    while (onWhite()) {
		if (nextch == '\t')
		    string += "   ";
		else if (nextch == ' ')
		    string += (char)nextch;
		else if (nextch == '\n')
		    break;
		readch();
	    }		
	    //System.out.println("WORD \"" + string + "\"");
	}

	return WORD;
    }

    public String toString() {
	return "string=" + string +
	    "\nattrs=" + attrs +
	    "\nnextch= " + nextch + "(" + (char)nextch + ")" +
	    "\ninputLeft=" + inputLeft +
	    "\nmarkedAt=" + markedAt +
	    "\nmarkch=" + markch + "(" + (char)markch + ")" +
	    "\nmarkline=" + markline +
	    "\nlineno=" + lineno;
    }
}
