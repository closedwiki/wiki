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
    private int inputLength;
    private int charsRead;
    private LineNumberReader source;
    private int markedAtCh;
    private int markedAtCharsRead;

    /** true if we want whitespace */
    public boolean isPreformatted;

    /** The current tag or word */
    public String string;
    /** The attribute set read for the current token, if it is a TAG */
    public TagAttributes attrs;
    /** The value of the last <!# marker tag seen */
    public int markerTag;

    public boolean whitespaceMode(boolean mode) {
	boolean oldmode = isPreformatted;
	isPreformatted = mode;
	return oldmode;
    }

    /**
     * Create a tokeniser to read from the given reader,
     * with an estimate for the total length of the input text.
     */
    public XMLTokeniser(Reader source, int inputLength) {
	this.source = new LineNumberReader(source);
	this.inputLength = inputLength;
	charsRead = 0;
	try {
	    readch();
	} catch (IOException io) {
	}
	string = "body";
	attrs = null;
	markerTag = -1;
    }

    /**
     * Get the next character, expanding entities
     */
    private void readch() throws IOException {
	nextch = source.read();
	charsRead++;
    }

    public int getLineNumber() {
	return source.getLineNumber();
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

    private void skipWhite() throws IOException {
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

    private void setMark() throws IOException {
	markedAtCharsRead = charsRead;
	markedAtCh = nextch;
	source.mark(Math.max(100, inputLength - charsRead));
    }

    private void resetToMark() throws IOException {
	source.reset();
	charsRead = markedAtCharsRead;
	nextch = markedAtCh;
    }

    private String readCDATA(int closer) throws IOException {
	String val = "";
	while (nextch != -1 &&
	       ((closer != 0 && nextch != closer) ||
		(closer == 0 && onAttrVal()))) {
	    val += (char)nextch;
	    readch();
	}
	if (val.length() == 0)
	    return "";
	Reader r = new EntityExpandingReader(new StringReader(val));
	char[] cbuf = new char[val.length()];
	int n = r.read(cbuf, 0, cbuf.length);
	return new String(cbuf, 0, n);
    }

    /**
     * Get the next token from the reader
     */
    public int nextToken() {
	try {
	    return getNextToken();
	} catch (IOException ioe) {
	    ioe.printStackTrace();
	    throw new Error("ASSERT " + ioe.getMessage() + this);
	}
    }

    private int getNextToken() throws IOException {
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

	    // Comment block,DOCTYPE tag, or <!#n> line number tag
	    readch();
	    if (nextch == '#') {
		int ln = 0;
		readch();
		while ('0' <= nextch && nextch <= '9') {
		    ln = ln * 10 + (nextch - '0');
		    readch();
		}
		markerTag = ln;
	    } else {
		// SGML says: A comment declaration starts with <!, followed by
		// zero or more comments, followed by >. A comment starts and
		//  ends with "--", and does not contain any occurrence of
		// "--". 
		// This means that the following are all legal SGML comments: 
		// 1.<!-- Hello --> 
		// 2.<!-- Hello -- -- Hello--> 
		// 3.<!----> 
		// 4.<!------ Hello --> 
		// 5.<!>
		// 6.<!------> hello-->
		// In the interests of brevity, we're going to get this wrong,
		// deliberately..
		while (nextch != '>' && nextch != -1)
		    readch();
	    }
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
	    string += (char)nextch;
	    readch();
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
	return " string=" + string +
	    " attrs={" + attrs +
	    "}\nnext char " + nextch + "(" + (char)nextch + ")" +
	    "on line=" + getLineNumber() +
	    "\nread " + charsRead + " of " + inputLength +
	    "\nmarkedAtCh=" + markedAtCh + "(" + (char)markedAtCh + ")";
    }
}
