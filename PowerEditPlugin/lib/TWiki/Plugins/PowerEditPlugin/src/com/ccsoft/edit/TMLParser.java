// Copyright (C) 2004 Crawford Currie - All rights reserved
// It is hereby granted that this software can be used, copied, 
// modified, and distributed without fee provided that this 
// copyright notice appears in all copies.
package com.ccsoft.edit;

import java.util.Stack;
import java.util.Vector;

import java.io.*;

import gnu.regexp.*;

/**
 * Simple parser to convert TWiki Markup Language (TML) to HTML
 */
class TMLParser {

    private static final String upperAlpha = "[:upper:]";
    private static final String lowerAlpha = "[:lower:]";
    private static final String numeric = "[:digit:]";
    private static final String mixedAlpha = "[:alpha:]";
    private static final String mixedAlphaNum = "[:alnum:]";
    private static final String lowerAlphaNum = lowerAlpha+numeric;
    private static final String wikiWordRE = "["+upperAlpha+"]+["+
    lowerAlpha+"]+["+ upperAlpha+"]+["+mixedAlphaNum+"]*";
    private static final String webNameRE = "["+upperAlpha+"]+["+
    lowerAlphaNum+"]*";
    private static final String anchorRE = "\\#["+mixedAlphaNum+"_]+";
    private static final String abbrevRE = "["+upperAlpha+"]{3,}";

    // Precompiled REs
    private static final RE re_comment = s("<!--.*?-->");
    private static final RE re_CITE = m("^>(.*?)$");
    private static final RE re_BCODE =
    m("([\\s\\(])==([^\\s].*?[^\\s])==([\\s\\,\\.\\;\\:\\!\\?\\)])");
    private static final RE re_B =
    m("([\\s\\(])\\*([^\\s].*?[^\\s])\\*([\\s\\,\\.\\;\\:\\!\\?\\)])");
    private static final RE re_BI =
    m("([\\s\\(])__([^\\s].*?[^\\s])__([\\s\\,\\.\\;\\:\\!\\?\\)])");
    private static final RE re_I =
    m("([\\s\\(])_([^\\s].*?[^\\s])_([\\s\\,\\.\\;\\:\\!\\?\\)])");
    private static final RE re_CODE =
    m("([\\s\\(])=([^\\s].*?[^\\s])=([\\s\\,\\.\\;\\:\\!\\?\\)])");
    private static final RE re_verbatim = m("^(\\s*)<verbatim>\\s*$");
    private static final RE re_slashverbatim = m("^\\s*</verbatim>\\s*$");
    private static final RE re_tabplus = s("^\t(\\++|\\#+)\\s*(.+)\\s*$");
    private static final RE re_H = si("^<h([1-6])>\\s*(.+?)\\s*</h[1-6]>");
    private static final RE re_minusplus = s("^---+(\\++|\\#+)\\s*(.+)\\s*$");
    private static final RE re_tablerow = s("^(\\s*)\\|(.*)");
    private static final RE re_blankline = s("^\\s*$");
    private static final RE re_SatBOL = s("^(\\S+?)");
    private static final RE re_DL = s("^(\\t+)(\\S+?):\\s");
    private static final RE re_UL = s("^(\\t+)\\* ");
    private static final RE re_OL = s("^(\\t+)[0-9] ");
    private static final RE re_spaces = s("\\s+");
    private static final RE re_tablehead = m("^([a-zA-Z0-9]+)---+");
    private static final RE re_HR = m("^---+");
    private static final RE re_ANCHOR = s("^(\\#)("+wikiWordRE+")");
    private static final RE re_MAIL1 = s("\\[\\[(mailto\\:[^\\s\\@]+)\\s+(.+?)\\]\\]");
    private static final RE re_MAIL2 = s("\\[\\[(mailto\\:[a-zA-Z0-9\\-\\_\\.\\+]+)\\@([a-zA-Z0-9\\-\\_\\.]+)\\.(.+?)(\\s+|\\]\\[)(.*?)\\]\\]");
    private static final RE re_MAIL3 = s("([\\s\\(])(mailto\\:)*([a-zA-Z0-9\\-\\_\\.\\+]+)\\@([a-zA-Z0-9\\-\\_\\.]+)\\.([a-zA-Z0-9\\-\\_]+)([\\s\\.\\,\\;\\:\\!\\?\\)])");
    private static final RE re_WW1 = s("\\[\\[([^\\]]+)\\]\\[([^\\]]+)\\]\\]");
    private static final RE re_WW2 = s("\\[\\[([a-z]+\\:\\S+)\\s+(.*?)\\]\\]");
    private static final RE re_WW3 = s("\\[\\[([^\\]]+)\\]\\]");
    private static final RE re_WW4 = s("([\\s\\(])("+webNameRE+
				       ")\\.("+wikiWordRE+")("+
				       anchorRE+")");
    private static final RE re_WW5 = s("([\\s\\(])("+webNameRE+
				       ")\\.("+wikiWordRE+")");
    private static final RE re_WW6 = s("([\\s\\(])("+wikiWordRE+
				       ")("+anchorRE+")");
    private static final RE re_WW7 = s("([\\s\\(])("+wikiWordRE+")");
    private static final RE re_WW8 = s("([\\s\\(])("+webNameRE+
				       ")\\.("+abbrevRE+")");
    private static final RE re_WW9 = s("([\\s\\(])("+abbrevRE+")");

    /**
     * RE for /m modifier
     */
    private static RE m(String rex) {
	try {
	    return new RE(rex, RE.REG_MULTILINE,
			  RESyntax.RE_SYNTAX_PERL5);
	} catch (REException re) {
	    throw new Error("ASSERT " + rex);
	}
    }

    /**
     * RE for /mi modifiers
     */
    private static RE mi(String rex) {
	try {
	    return new RE(rex, RE.REG_ICASE | RE.REG_MULTILINE,
			  RESyntax.RE_SYNTAX_PERL5);
	} catch (REException re) {
	    throw new Error("ASSERT " + rex);
	}
    }

    /**
     * RE for /s modifier
     */
    private static RE s(String rex) {
	try {
	    return new RE(rex, RE.REG_DOT_NEWLINE,
				   RESyntax.RE_SYNTAX_PERL5);
	} catch (REException re) {
	    re.printStackTrace();
	    throw new Error("ASSERT " + rex + re.getMessage());
	}
    }

    /**
     * RE for /si modifiers
     */
    private static RE si(String rex) {
	try {
	    return new RE(rex, RE.REG_ICASE | RE.REG_DOT_NEWLINE,
				   RESyntax.RE_SYNTAX_PERL5);
	} catch (REException re) {
	    throw new Error("ASSERT " + rex);
	}
    }

    /**
     * RE for no modifiers
     */
    private static RE nomod(String rex) {
	try {
	    return new RE(rex, 0, RESyntax.RE_SYNTAX_PERL5);
	} catch (REException re) {
	    throw new Error("ASSERT " + rex);
	}
    }

    /**
     * Returns the index within this string of the first occurrence of the
     * specified substring, starting at the specified index. The search
     * is case-insensitive.
     */
    private static int indexOfi(String text, String pattern, int start) {
	int len = pattern.length();
	int stop = text.length() - len + 1;
	for ( ; start < stop; start++) {
	    if (text.regionMatches(true, start, pattern, 0, len))
		return start;
	}
	return -1;
    }

    /** simple replacement of a pattern string. Faster than regexp.
     * Really wish we had StringBuffer.replace! */
    private static String stringReplace(String text,
					String pattern, String subs) {
	int start = indexOfi(text, pattern, 0);
	if (start == -1)
	    return text;
	int end = 0;
	int len = pattern.length();
	StringBuffer result = new StringBuffer(len);
	while (start != -1) {
	    result.append(text.substring(end, start));
	    result.append(subs);
	    end = start + len;
	    start = indexOfi(text, pattern, end);
	}
	result.append(text.substring(end));
	return result.toString();
    }

    /** Find next */
    private static REMatch m_(String text, RE rex) {
	return rex.getMatch(text);
    }

    /**
     * Replace the results of the given match in the text
     * @param text text that the match was performed on
     * @param match the match
     * @param subs substitution string, may contain $n
     */
    private static String replace(String text, REMatch match, String subs) {
	String repl = match.substituteInto(subs);
	StringBuffer result =
	    new StringBuffer(match.getStartIndex() +
			     repl.length() +
			     text.length() - match.getEndIndex());
	result.append(text.substring(0, match.getStartIndex()));
	result.append(repl);
	result.append(text.substring(match.getEndIndex()));
	return result.toString();
    }

    /**
     * Exclude text inside verbatim from further processing
     */
    private static String takeOutVerbatim(String intext, Vector verbatim)
	throws IOException {
	REMatch match = m_(intext, re_verbatim);
	if (match == null)
	    return intext;
    
	String tmp = "";
	StringBuffer outtext = new StringBuffer();
	int nesting = 0;
	int verbatimCount = verbatim.size();
	
	BufferedReader r = new BufferedReader(new StringReader(intext));
	String line;
	while ((line = r.readLine()) != null) {
	    if (Thread.currentThread().interrupted())
		throw new Interruption();
	    boolean process = true;
	    if ((match = m_(line, re_verbatim)) != null) {
		nesting++;
		if (nesting == 1) {
		    outtext.append(match.substituteInto("$1"));
		    outtext.append("%_VERBATIM");
		    outtext.append(verbatim.size());
		    outtext.append("%\n");
		    tmp = "";
		    process = false;
		}
	    } else if ((match = m_(line, re_slashverbatim)) != null) {
		nesting--;
		if (nesting == 0) {
		    verbatim.addElement(tmp);
		    process = false;
		}
	    }
	    
	    if (process) {
		if (nesting != 0)
		    tmp += line + "\n";
		else
		    outtext.append(line).append('\n');
	    }
	}
	
	// Deal with unclosed verbatim
	if (nesting != 0) {
	    verbatim.addElement(tmp);
	}
	
	return outtext.toString();
    }

    /**
     * @param type set tag=verbatim to get back original text, tag=pre
     * to convert to HTML readable verbatim text
     */
    private static String putBackVerbatim(String text, String type,
					  Vector verbatim) {
	for (int i = 0; i < verbatim.size(); i++) {
	    String val = (String)verbatim.elementAt(i);
	    if (type.equals("pre")) {
		val = stringReplace(val, "<", "&lt;");
		val = stringReplace(val, ">", "&gt;");
		// A shame to do this, but been in since day 1
		val = stringReplace(val, "\t", "   ");
	    }
	    text = stringReplace(text, "%_VERBATIM" + i + "%",
		       "<" + type + ">\n" + val + "</" + type + ">");
	}
	
	return text;
    }

    private static String makeHeading(String t, REMatch match,
					    String head, int lev) {
	return replace(t, match, "<h" + lev + ">" + head + "</h" + lev + ">");
    }

    private static String emitList(String theType, String theElement,
		    int theDepth, Stack listTypes, Stack listElements) {
	StringBuffer result = new StringBuffer();
	if( listTypes.size() < theDepth ) {
	    boolean firstTime = true;
	    while (listTypes.size() < theDepth ) {
		listTypes.push(theType);
		listElements.push(theElement);
		if (firstTime)
		    firstTime = false;
		else
		    result.append('<').append(theElement).append('>');
		result.append('<').append(theType).append('>');
	    }
	} else if (listTypes.size() > theDepth ) {
	    while (listTypes.size() > theDepth ) {
		result.append("</").append(listElements.pop()).
		    append("></").append(listTypes.pop()).append('>');
	    }
	    if (!listElements.isEmpty())
		result.append("</").append(listElements.peek()).append('>');
	} else if (!listElements.isEmpty())
	    result.append("</").append(listElements.peek()).append('>');
	
	if (!listTypes.isEmpty() && !listTypes.peek().equals(theType)) {
	    result.append("</").append(listTypes.peek()).append("><").
		append(theType).append('>');
	    listTypes.pop();
	    listTypes.push(theType);
	    listElements.pop();
	    listElements.push(theElement);
	}
	return result.toString();
    }

    private static String emitTR(String t, REMatch match,
			  String thePre, String theRow, boolean insideTABLE ) {
	StringBuffer text = new StringBuffer(match.substituteInto(thePre));
	theRow = match.substituteInto(theRow);
	if (!insideTABLE)
	    text.append("<table>");

	text.append("<tr>");

	for (int i = theRow.indexOf('|'); i >= 0; ) {
	    String start = theRow.substring(0, i);
	    theRow = theRow.substring(i + 1);
	    start.trim();
	    char tag = 'd';
	    if (start.length() > 0 && start.charAt(0) == '*' &&
		start.charAt(start.length() - 1) == '*')
		tag = 'h';

	    text.append("<t").append(tag).append("> ");
	    text.append(start).append(" </t").append(tag).append('>');
	    i = theRow.indexOf('|');
        }
	return text + "</tr>";
    }

    /**
     * Use gnu regexp to locate and mark up TML. This is analogous to
     * getRenderedVersion in TWiki.pm
     */
    public static String toHTML(String text)
	throws IOException {

	// take out carriage returns
	text = stringReplace(text, "\r", "");
	Vector verbatim = new Vector();
	text = takeOutVerbatim(text, verbatim);
	// take out line continuations
	text = stringReplace(text, "\\\n", "");
	// change triples of spaces to tabs
	text = stringReplace(text, "   ", "\t");
	// Strip comments
	text = re_comment.substituteAll(text, "");
	boolean insidePRE = false;
	boolean	insideTABLE = false;
	boolean insideNoAutoLink = false;
	boolean	isList = false;
	StringBuffer result = new StringBuffer(text.length());
	Stack listTypes = new Stack();
	Stack listElements = new Stack();

	BufferedReader r = new BufferedReader(new StringReader(text));
	String line;
	while ((line = r.readLine()) != null) {
	    if (Thread.currentThread().interrupted())
		throw new Interruption();

	    if (indexOfi(line, "<pre>", 0) >= 0)
		insidePRE = true;
	    if (indexOfi(line, "</pre>", 0) >= 0)
		insidePRE = false;
	    if (indexOfi(line, "<noautolink>", 0) >= 0)
		insideNoAutoLink = true;
	    if (indexOfi(line, "</noautolink>", 0) >= 0)
		insideNoAutoLink = false;

	    if (insidePRE) {
		if (listTypes.size() > 0) {
		    result.append(emitList("", "", 0, listTypes, listElements));
		    isList = true;
		}
		line = stringReplace(line, "\t", "   ");
	    } else {
		line = re_CITE.substituteAll(line, "> <cite> $1 </cite><br>");
	    }

	    // '<h6>...</h6>' HTML rule
	    REMatch match = m_(line, re_H);
	    if (match != null)
		line = makeHeading(
		    line, match, "$2", 
		    Integer.parseInt(match.substituteInto("$1")));
            // '\t+++++++' rule
            match = m_(line, re_tabplus);
	    if (match != null)
		line = makeHeading(
		    line, match, "$2",
		    match.substituteInto("$1").length());
	    // '----+++++++' rule
            match = m_(line, re_minusplus);
	    if (match != null)
		line = makeHeading(
		    line, match, "$2",
		    match.substituteInto("$1").length());

	    line = re_HR.substituteAll(line, "<hr />");

	    // this takes a hell of a time to match! Could it be loading??
	    //System.out.println("Mark 1");
	    //RE temp = mi("^([a-zA-Z0-9]+)----*");
	    //match = temp.getMatch(line);
	    //System.out.println("Mark 2");
	    //line = temp.substituteAll(
	    //	line,
	    //	"<table><tr><td><h2>$1</h2></td><td><hr></td></tr></table>");
	    line = re_tablehead.substituteAll(line,
		       "<table width=\"100%\"><tr><td valign=\"bottom\"><h2>$1</h2></td><td width=\"98%\" valign=\"middle\"><hr /></td></tr></table>");

	    // Table of format: | cell | cell |
	    match = m_(line, re_tablerow);
	    if (match != null) {
		line = emitTR(line, match, "$1", "$2", insideTABLE) + "\n";
                insideTABLE = true;
            } else if (insideTABLE) {
                result.append("</table>");
                insideTABLE = false;
            }

	    // Lists and paragraphs
            match = m_(line, re_blankline);
	    if (match != null) {
		result.append("<p />");
		isList = false;
		continue;
	    }

	    // Line not starting with spaces
            match = m_(line, re_SatBOL);
	    if (match != null)
		isList = false;

	    match = m_(line, re_DL);
	    if (match != null) {
		line = replace(line, match, "<dt> $2</dt><dd> ");
		int len = match.substituteInto("$1").length();
		result.append(emitList("dl", "dd", len, listTypes, listElements));
		isList = true;
	    }

	    match = m_(line, re_UL);
	    if (match != null) {
		line = replace(line, match, "<li> ");
		int len = match.substituteInto("$1").length();
		result.append(emitList("ul", "li", len, listTypes, listElements));
		isList = true;
	    }

	    match = m_(line, re_OL);
	    if (match != null) {
		line = replace(line, match, "<li> ");
		int len = match.substituteInto("$1").length();
		result.append(emitList("ol", "li", len, listTypes, listElements));
		isList = true;
	    }

            if (!isList)
                result.append(emitList("", "", 0, listTypes, listElements));

	    // '#WikiName' anchors
            line = re_ANCHOR.substituteAll(line, "");

	    //# enclose in white space for the regexes that follow
            line = "\n" + line + "\n";

	    // Emphasizing
	    line = re_BCODE.substituteAll(line, "$1<b><code>$2</code></b>$3");
	    line = re_BI.substituteAll(line, "$1<b><i>$2</i></b>$3");
	    line = re_B.substituteAll(line, "$1<b>$2</b>$3");
	    line = re_I.substituteAll(line, "$1<i>$2</i>$3");
	    line = re_CODE.substituteAll(line, "$1<code>$2</code>$3");

	    // Mailto
	    // Email addresses must always be 7-bit, even within I18N sites

	    // RD 27 Mar 02: Mailto improvements - FIXME: check security...
	    // Explicit [[mailto:... ]] link without an '@' - hence no 
	    // anti-spam padding needed.
	    // '[[mailto:string display text]]' link (no '@' in 'string'):
	    line = re_MAIL1.substituteAll(line, "<a href=\"$1\">$2</a>");

	    // Explicit [[mailto:... ]] link including '@', with anti-spam 
	    // padding, so match name@subdom.dom.
	    // '[[mailto:string display text]]' link
	    line = re_MAIL2.substituteAll(line,
					  "<a href=\"$1@$2.$3\">$5</a>");

	    // Normal mailto:foo@example.com ('mailto:' part optional)
	    // FIXME: Should be '?' after the 'mailto:'...
	    line = re_MAIL3.substituteAll(line, 
					  "$1<a href=\"$3@$4.$5\">$5</a>$6");

	    // Make internal links
	    // Spaced-out Wiki words with alternative link text
	    // '[[Web.odd wiki word	#anchor][display text]]' link:
            line = re_WW1.substituteAll(line, "<a href=\"$2\">$1</a>");
	    // RD 25 Mar 02: Codev.EasierExternalLinking
	    // '[[URL#anchor display text]]' link:
            line = re_WW2.substituteAll(line, "<a href=\"$1\">$2</a>");
	    // Spaced-out Wiki words
	    // '[[Web.odd wiki word#anchor]]' link:
            line = re_WW3.substituteAll(line, "<a href=\"$1\">$1</a>");

	    // do normal WikiWord link if not disabled by <noautolink>
	    if (!insideNoAutoLink) {
		// 'Web.TopicName#anchor' link:
                line = re_WW4.substituteAll(
		    line, "$1<a href=\"$2.$3#$4\">$2.$3#$4</a>");
		// 'Web.TopicName' link:
                line = re_WW5.substituteAll(line,
					    "$1<a href=\"$2.$3\">$2.$3</a>");

		// 'TopicName#anchor' link:
                line = re_WW6.substituteAll(line,
					    "$1<a href=\"$2#$3\">$2#$3</a>");

		// 'TopicName' link:
		line = re_WW7.substituteAll(line, "$1<a href=\"$2\">$2</a>");

		// Handle acronyms/abbreviations of three or more letters
		// 'Web.ABBREV' link:
                line = re_WW8.substituteAll(line,
					    "$1<a href=\"$2.$3\">$2.$3</a>");
		// 'ABBREV' link:
		line = re_WW9.substituteAll(line, "$1<a href=\"$2\">$2</a>");
            }
	    result.append(line);
	}
	if (insideTABLE)
	    result.append("</table>");
	result.append(emitList("", "", 0, listTypes, listElements));
	if (insidePRE)
	    result.append("</pre>");

	text = result.toString();
	text = stringReplace(text, "<nop>", "");
	text = putBackVerbatim(text, "pre", verbatim);

	return text;
    }
}
