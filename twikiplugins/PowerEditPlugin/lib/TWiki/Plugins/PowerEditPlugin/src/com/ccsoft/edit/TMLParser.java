// Copyright (C) 2004 Crawford Currie - All rights reserved
// It is hereby granted that this software can be used, copied, 
// modified, and distributed without fee provided that this 
// copyright notice appears in all copies.
package com.ccsoft.edit;

import java.util.Stack;
import java.util.Vector;
import java.util.Enumeration;

import java.io.*;

import gnu.regexp.*;
import uk.co.cdot.SuperString;

/**
 * Simple parser to convert TWiki Markup Language (TML) to HTML
 */
class TMLParser {

    private static final String verbatimIntro = "%_VERBATIM";

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
    private static final RE re_verbatim = m("^\\s*<verbatim>\\s*$");
    private static final RE re_slashverbatim = m("^\\s*</verbatim>\\s*$");
    private static final RE re_verbatimPH = m(verbatimIntro +
					       "([0-9]+)_([0-9]+)%");
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
    private static final RE m(String rex) {
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
    private static final RE mi(String rex) {
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
    private static final RE s(String rex) {
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
    private static final RE si(String rex) {
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
    private static final RE nomod(String rex) {
	try {
	    return new RE(rex, 0, RESyntax.RE_SYNTAX_PERL5);
	} catch (REException re) {
	    throw new Error("ASSERT " + rex);
	}
    }

    /**
     * Exclude text inside verbatim from further processing
     */
    /**
     * Exclude text inside verbatim from further processing
     */
    private static Vector takeOutVerbatim(SuperString intext)
        throws IOException {

	Vector verbatim = new Vector();

        REMatch match = re_verbatim.getMatch(intext);
        if (match == null)
            return verbatim;
    
        SuperString tmp = new SuperString();
        StringBuffer outtext = new StringBuffer();
        int nesting = 0;
        int verbatimCount = verbatim.size();
        
        Enumeration e = intext.lineEnumeration();
	int tmpLines = 0;
        while (e.hasMoreElements()) {
	    SuperString line = (SuperString)e.nextElement();;
            if (Thread.currentThread().interrupted())
                throw new Interruption();
            boolean process = true;
            if ((match = re_verbatim.getMatch(line)) != null) {
                nesting++;
                if (nesting == 1) {
		    outtext.append(verbatimIntro);
                    outtext.append(verbatim.size());
                    outtext.append('_');
                    tmp = new SuperString();
		    tmpLines = 0;
                    process = false;
                }
            } else if ((match = re_slashverbatim.getMatch(line)) != null) {
                nesting--;
                if (nesting == 0) {
                    outtext.append(tmpLines + 1);
                    outtext.append("%\n");
                    verbatim.addElement(tmp);
                    process = false;
                }
            }
            
            if (process) {
                if (nesting != 0) {
                    tmp.append(line + "\n");
		    tmpLines++;
                } else {
                    outtext.append(line).append('\n');
		}
            }
        }
        
        // Deal with unclosed verbatim
        if (nesting != 0) {
	    outtext.append(tmpLines + 1);
	    outtext.append("%\n");
            verbatim.addElement(tmp);
        }
        
	intext.setLength(0);
	intext.append(outtext);
	return verbatim;
    }

    /**
     * @param type set tag=verbatim to get back original text, tag=pre
     * to convert to HTML readable verbatim text
     */
    private static void putBackVerbatim(SuperString text, String type,
					  Vector verbatim) {
	for (int i = 0; i < verbatim.size(); i++) {
	    SuperString val = (SuperString)verbatim.elementAt(i);
	    if (type.equals("pre")) {
		val.findAndReplace("<", "&lt;");
		val.findAndReplace(">", "&gt;");
		// A shame to do this, but been in since day 1
		val.findAndReplace("\t", "   ");
	    }
	}

	REMatch match;
	while ((match = re_verbatimPH.getMatch(text)) != null) {
	    int i = Integer.parseInt(match.substituteInto("$1"));
	    text.replace(match,
		    "<" + type + ">\n" +
		    verbatim.elementAt(i) +
		    "</" + type + ">");
	}
    }

    private static void makeHeading(SuperString t, REMatch match,
					    String head, int lev) {
	t.replace(match, "<h" + lev + ">" + head + "</h" + lev + ">");
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

    private static String emitTR(SuperString t, REMatch match,
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
     * getRenderedVersion in TWiki.pm. 'text' will be destroyed.
     */
    public static SuperString toHTML(SuperString text)
	throws IOException {

	REMatch match;
	// take out carriage returns
	text.findAndReplace("\r", "");
	Vector verbatim = takeOutVerbatim(text);
	// take out line continuations
	text.findAndReplace("\\\n", "");
	// change triples of spaces to tabs
	text.findAndReplace("   ", "\t");
	// Strip comments
	text.findAndReplace(re_comment, "");

	boolean insidePRE = false;
	boolean	insideTABLE = false;
	boolean insideNoAutoLink = false;
	boolean	isList = false;
	SuperString result = new SuperString(text.length());
	Stack listTypes = new Stack();
	Stack listElements = new Stack();
	Enumeration e = text.lineEnumeration();
	SuperString line = null;
	int lineno = 0;
	while (e.hasMoreElements()) {
	    if (Thread.currentThread().interrupted())
		throw new Interruption();

	    if (line != null && (match = re_verbatimPH.getMatch(line)) != null)
		lineno += Integer.parseInt(match.substituteInto("$2"));
	    result.append("<!#" + (lineno++) + ">");

	    line = (SuperString)e.nextElement();
	    if (line.indexOfi("<pre>", 0) >= 0)
		insidePRE = true;
	    if (line.indexOfi("</pre>", 0) >= 0)
		insidePRE = false;
	    if (line.indexOfi("<noautolink>", 0) >= 0)
		insideNoAutoLink = true;
	    if (line.indexOfi("</noautolink>", 0) >= 0)
		insideNoAutoLink = false;

	    if (insidePRE) {
		if (listTypes.size() > 0) {
		    result.append(emitList("", "", 0, listTypes, listElements));
		    isList = true;
		}
		line.findAndReplace("\t", "   ");
	    } else {
		line.findAndReplace(re_CITE, "> <cite> $1 </cite><br>");
	    }

	    // '<h6>...</h6>' HTML rule
	    match = re_H.getMatch(line);
	    if (match != null)
		makeHeading(
		    line, match, "$2", 
		    Integer.parseInt(match.substituteInto("$1")));
            // '\t+++++++' rule
            match = re_tabplus.getMatch(line);
	    if (match != null)
		makeHeading(
		    line, match, "$2",
		    match.substituteInto("$1").length());
	    // '----+++++++' rule
            match = re_minusplus.getMatch(line);
	    if (match != null)
		makeHeading(
		    line, match, "$2",
		    match.substituteInto("$1").length());

	    line.findAndReplace(re_HR, "<hr />");
	    line.findAndReplace(re_tablehead,
			 "<table width=\"100%\"><tr><td valign=\"bottom\"><h2>$1</h2></td><td width=\"98%\" valign=\"middle\"><hr /></td></tr></table>");

	    // Table of format: | cell | cell |
	    match = re_tablerow.getMatch(line);
	    if (match != null) {
		line = new SuperString(emitTR(line, match, "$1", "$2", insideTABLE) + "\n");
                insideTABLE = true;
            } else if (insideTABLE) {
                result.append("</table>");
                insideTABLE = false;
            }

	    // Lists and paragraphs
            match = re_blankline.getMatch(line);
	    if (match != null) {
		result.append("<p />");
		isList = false;
		continue;
	    }

	    // Line not starting with spaces
            match = re_SatBOL.getMatch(line);
	    if (match != null)
		isList = false;

	    match = re_DL.getMatch(line);
	    if (match != null) {
		line.replace(match, "<dt> $2</dt><dd> ");
		int len = match.substituteInto("$1").length();
		result.append(emitList("dl", "dd", len, listTypes, listElements));
		isList = true;
	    }

	    match = re_UL.getMatch(line);
	    if (match != null) {
		line.replace(match, "<li> ");
		int len = match.substituteInto("$1").length();
		result.append(emitList("ul", "li", len, listTypes, listElements));
		isList = true;
	    }

	    match = re_OL.getMatch(line);
	    if (match != null) {
		line.replace(match, "<li> ");
		int len = match.substituteInto("$1").length();
		result.append(emitList("ol", "li", len, listTypes, listElements));
		isList = true;
	    }

            if (!isList)
                result.append(emitList("", "", 0, listTypes, listElements));

	    // '#WikiName' anchors
            line.findAndReplace(re_ANCHOR, "");

	    //# enclose in white space for the regexes that follow
	    line.insert(0, '\n');
            line.append('\n');

	    // Emphasizing
	    line.findAndReplace(re_BCODE, "$1<b><code>$2</code></b>$3");
	    line.findAndReplace(re_BI, "$1<b><i>$2</i></b>$3");
	    line.findAndReplace(re_B, "$1<b>$2</b>$3");
	    line.findAndReplace(re_I, "$1<i>$2</i>$3");
	    line.findAndReplace(re_CODE, "$1<code>$2</code>$3");

	    // Mailto
	    // Email addresses must always be 7-bit, even within I18N sites

	    // RD 27 Mar 02: Mailto improvements - FIXME: check security...
	    // Explicit [[mailto:... ]] link without an '@' - hence no 
	    // anti-spam padding needed.
	    // '[[mailto:string display text]]' link (no '@' in 'string'):
	    line.findAndReplace(re_MAIL1, "<a href=\"$1\">$2</a>");

	    // Explicit [[mailto:... ]] link including '@', with anti-spam 
	    // padding, so match name@subdom.dom.
	    // '[[mailto:string display text]]' link
	    line.findAndReplace(re_MAIL2, "<a href=\"$1@$2.$3\">$5</a>");

	    // Normal mailto:foo@example.com ('mailto:' part optional)
	    // FIXME: Should be '?' after the 'mailto:'...
	    line.findAndReplace(re_MAIL3, "$1<a href=\"$3@$4.$5\">$5</a>$6");

	    // Make internal links
	    // Spaced-out Wiki words with alternative link text
	    // '[[Web.odd wiki word	#anchor][display text]]' link:
            line.findAndReplace(re_WW1, "<a href=\"$2\">$1</a>");
	    // RD 25 Mar 02: Codev.EasierExternalLinking
	    // '[[URL#anchor display text]]' link:
            line.findAndReplace(re_WW2, "<a href=\"$1\">$2</a>");
	    // Spaced-out Wiki words
	    // '[[Web.odd wiki word#anchor]]' link:
            line.findAndReplace(re_WW3, "<a href=\"$1\">$1</a>");

	    // do normal WikiWord link if not disabled by <noautolink>
	    if (!insideNoAutoLink) {
		// 'Web.TopicName#anchor' link:
                line.findAndReplace(re_WW4,
			     "$1<a href=\"$2.$3#$4\">$2.$3#$4</a>");
		// 'Web.TopicName' link:
                line.findAndReplace(re_WW5, "$1<a href=\"$2.$3\">$2.$3</a>");

		// 'TopicName#anchor' link:
                line.findAndReplace(re_WW6, "$1<a href=\"$2#$3\">$2#$3</a>");

		// 'TopicName' link:
		line.findAndReplace(re_WW7, "$1<a href=\"$2\">$2</a>");

		// Handle acronyms/abbreviations of three or more letters
		// 'Web.ABBREV' link:
                line.findAndReplace(re_WW8, "$1<a href=\"$2.$3\">$2.$3</a>");
		// 'ABBREV' link:
		line.findAndReplace(re_WW9, "$1<a href=\"$2\">$2</a>");
            }

	    result.append(line);
	}
	if (insideTABLE)
	    result.append("</table>");
	result.append(emitList("", "", 0, listTypes, listElements));
	if (insidePRE)
	    result.append("</pre>");

	result.findAndReplace("<nop>", "");
	result.findAndReplace("<noautolink>", "");
	result.findAndReplace("</noautolink>", "");
	putBackVerbatim(result, "pre", verbatim);

	return result;
    }
}
