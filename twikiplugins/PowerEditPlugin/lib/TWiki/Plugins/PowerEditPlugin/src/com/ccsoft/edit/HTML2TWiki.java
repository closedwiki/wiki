package com.ccsoft.edit;

import java.io.BufferedReader;
import java.io.PrintWriter;
import java.io.StringReader;
import java.io.StringWriter;

import java.util.Enumeration;
import java.util.Hashtable;

import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;

import com.kizna.html.HTMLNode;
import com.kizna.html.HTMLParser;
import com.kizna.html.HTMLReader;
import com.kizna.html.HTMLRemarkNode;
import com.kizna.html.HTMLStringNode;

import com.kizna.html.scanners.HTMLDoctypeScanner;
import com.kizna.html.scanners.HTMLImageScanner;
import com.kizna.html.scanners.HTMLJspScanner;
import com.kizna.html.scanners.HTMLLinkScanner;

import com.kizna.html.tags.HTMLDoctypeTag;
import com.kizna.html.tags.HTMLEndTag;
import com.kizna.html.tags.HTMLImageTag;
import com.kizna.html.tags.HTMLJspTag;
import com.kizna.html.tags.HTMLLinkTag;
import com.kizna.html.tags.HTMLTag;

/**
 * Conversion from HTML to TWiki ML
 * Does as well as it can in the circumstances!
 * Methods are provided to handle most of the basic node types and
 * ignore others. When a method is not found to handle a node type,
 * the HTML is simply reflected.
 */
public class HTML2TWiki {
    private PrintWriter out;
    private String bulletType;
    private boolean filterNLs;

    static Hashtable passThrough, ignore, translate, ignoreToClose;

    /**
     * Tags declared passthrough are output unchanged
     */
    static void passThrough(String tag) {
	passThrough.put(tag, tag);
    }

    /**
     * Tags declared translate are changed to the given tag
     */
    static void translate(String tag, String to) {
	translate.put(tag, to);
    }

    /**
     * Tags declared ignore are simply filtered
     */
    static void ignore(String tag) {
	ignore.put(tag, tag);
    }

    /**
     * Tags declared ignoreToClose filter all content until the close tag
     * is seen
     */
    static void ignoreToClose(String tag) {
	ignoreToClose.put(tag, tag);
    }

    static {
	passThrough = new Hashtable();
	translate = new Hashtable();
	ignore = new Hashtable();
	ignoreToClose = new Hashtable();

	passThrough("ABBR");
	passThrough("ACRONYM");
	passThrough("ADDRESS");
	passThrough("AREA");
	passThrough("BDO");
	passThrough("BIG");
	passThrough("BLOCKQUOTE");
	passThrough("BR");
	passThrough("CAPTION");
	passThrough("CENTER");
	// ^> at the start of each line in the cite block?
	passThrough("CITE");
	passThrough("COL");
	passThrough("COLGROUP");
	// Can translate DL & DD iff <dt>\s*\S+</dt>
	passThrough("DD");
	passThrough("DEL");
	passThrough("DIR");
	passThrough("DL");
	passThrough("DT");
	passThrough("FONT");
	passThrough("IFRAME");
	passThrough("INS");
	passThrough("KBD");
	passThrough("MAP");
	passThrough("MULTICOL");
	passThrough("NOBR");
	passThrough("NOFRAMES");
	passThrough("NOSCRIPT");
	passThrough("Q");
	passThrough("S");
	passThrough("SAMP");
	passThrough("SMALL");
	passThrough("SUB");
	passThrough("SUP");
	passThrough("TABLE");
	passThrough("TBODY");
	passThrough("TD");
	passThrough("TFOOT");
	passThrough("TH");
	passThrough("THEAD");
	passThrough("TR");
	passThrough("U");
	passThrough("VAR");

	translate("DFN", "I");
	translate("S", "STRIKE");

	// TODO: Capture and add to URIs
	ignore("BASE");
	ignore("BASEFONT");
	ignore("BODY");
	ignore("DIV");
	ignore("FORM");
	ignore("HTML");
	ignore("INPUT");
	ignore("ISINDEX");
	ignore("LINK");
	ignore("META");
	ignore("PARAM");
	ignore("SPAN");

	ignoreToClose("APPLET");
	ignoreToClose("BUTTON");
	ignoreToClose("HEAD");
	ignoreToClose("LABEL");
	ignoreToClose("LEGEND");
	ignoreToClose("OBJECT");
	ignoreToClose("SCRIPT");
	ignoreToClose("SELECT");
	ignoreToClose("STYLE");
	ignoreToClose("TEXTAREA");
	ignoreToClose("TITLE");
    }

    // Call back when we see a link; strictly test only
    LinkCallback linkCallback;

    interface LinkCallback {
	public void processLink(String link);
    }

    HTML2TWiki() {
	linkCallback = null;
    }

    HTML2TWiki(LinkCallback cb) {
	linkCallback = cb;
    }

    // See if NAME is a valid wikiword
    // [:upper:]+[:lower:]+[:upper:]+[:alpha:]
    private boolean isWikiWord(String name) {
	int i = 0, n = name.length();
	while (i < n && Character.isUpperCase(name.charAt(i)))
	    i++;
	while (i < n && Character.isLowerCase(name.charAt(i)))
	    i++;
	while (i < n && Character.isUpperCase(name.charAt(i)))
	    i++;
	while (i < n && Character.isLetterOrDigit(name.charAt(i)))
	    i++;
	return i == n;
    }

    public void openA(HTMLTag node) {
	// This only occurs when its <A NAME=
	// <A HREF= gets caught as a HTMLLinkNode
	String name = node.getParameter("NAME");
	if (isWikiWord(name))
	    out.println("\n#" + name);
	else
	    out.print("\n" + toHTML(node));
    }

    public void closeA(HTMLEndTag node) {
	// ignore
    }

    // ([\s\(])\*([^\s]+?|[^\s].*?[^\s])\*([\s\,\.\;\:\!\?\)])
    public void openB(HTMLTag node) {
	out.print(" *");
    }

    public void closeB(HTMLEndTag node) {
	out.print("* ");
    }

    // ([\s\(])=([^\s]+?|[^\s].*?[^\s])=([\s\,\.\;\:\!\?\)])
    public void openCODE(HTMLTag node) {
	out.print(" =");
    }

    public void closeCODE(HTMLEndTag node) {
	out.print("= ");
    }

    public void openTT(HTMLTag node) {
	openCODE(node);
    }

    public void closeTT(HTMLEndTag node) {
	closeCODE(node);
    }

    // ([\s\(])_([^\s]+?|[^\s].*?[^\s])_([\s\,\.\;\:\!\?\)])
    public void openEM(HTMLTag node) {
	out.print(" _");
    }

    public void closeEM(HTMLEndTag node) {
	out.print("_ ");
    }

    public void openHR(HTMLTag node) {
	out.println("\n---");
    }

    private void handleH(int pluses) {
	out.print("\n---");
	while (pluses-- > 0)
	    out.print("+");
	out.print(" ");
    }

    public void openH1(HTMLTag node) {
	handleH(1);
    }

    public void closeH1(HTMLEndTag node) {
	out.println();
    }

    public void openH2(HTMLTag node) {
	handleH(2);
    }

    public void closeH2(HTMLEndTag node) {
	out.println();
    }

    public void openH3(HTMLTag node) {
	handleH(3);
    }

    public void closeH3(HTMLEndTag node) {
	out.println();
    }

    public void openH4(HTMLTag node) {
	handleH(4);
    }

    public void closeH4(HTMLEndTag node) {
	out.println();
    }

    public void openH5(HTMLTag node) {
	handleH(5);
    }

    public void closeH5(HTMLEndTag node) {
	out.println();
    }

    public void openH6(HTMLTag node) {
	handleH(6);
    }

    public void closeH6(HTMLEndTag node) {
	out.println();
    }

    public void openI(HTMLTag node) {
	out.print(" _");
    }

    public void closeI(HTMLEndTag node) {
	out.print("_ ");
    }

    public void openLI(HTMLTag node) {
	out.println();
	for (int i = 0; i < bulletType.length(); i++)
	    out.print("   ");
	out.print(bulletType.charAt(bulletType.length() - 1) + " ");
    }

    public void closeLI(HTMLEndTag node) {
	out.println();
    }

    public void openMENU(HTMLTag node) {
	openUL(node);
    }

    public void closeMENU(HTMLEndTag node) {
	closeUL(node);
    }

    public void openOL(HTMLTag node) {
	bulletType += "1";
    }

    public void closeOL(HTMLEndTag node) {
	bulletType = bulletType.substring(0, bulletType.length() - 1);
    }

    public void openP(HTMLTag node) {
	out.println("\n\n");
    }

    public void closeP(HTMLEndTag node) {
    }

    public void openPRE(HTMLTag node) {
	out.print("<pre>\n");
	filterNLs = false;
    }

    public void closePRE(HTMLEndTag node) {
	out.println("\n<pre>");
	filterNLs = true;
    }

    public void openSTRONG(HTMLTag node) {
	out.print(" __");
    }

    public void closeSTRONG(HTMLEndTag node) {
	out.print("__ ");
    }

    public void openUL(HTMLTag node) {
	bulletType += "*";
    }

    public void closeUL(HTMLEndTag node) {
	closeOL(node);
    }

    private String stripNLs(String text) {
	if (!filterNLs)
	    return text;

	StringBuffer res = new StringBuffer();
	for (int i = 0; i < text.length(); i++) {
	    char c = text.charAt(i);
	    if (c == '\n' || c == '\r')
		res.append(" ");
	    else
		res.append(c);
	}
	return res.toString();
    }

    /**
     * Format while stripping Core Attributes ID, STYLE, CLASS, TITLE
     */
    private String toHTML(HTMLNode tag) {
	return toHTML(tag, null);
    }

    /**
     * Format while stripping Core Attributes ID, STYLE, CLASS, TITLE
     * and renaming the tag if required.
     */
    private String toHTML(HTMLNode tag, String rename) {
	if (!(tag instanceof HTMLTag))
	    // HTMLEndTag
	    return tag.toHTML();
	Hashtable h = ((HTMLTag)tag).parseParameters();
	String res = "<";
	if (rename != null)
	    res += rename;
	else
	    res += h.get(HTMLTag.TAGNAME);
	h.remove(HTMLTag.TAGNAME);
	h.remove("ID");
	h.remove("STYLE");
	h.remove("CLASS");
	h.remove("TITLE");
	Enumeration i = h.keys();
	while (i.hasMoreElements()) {
	    Object key = i.nextElement();
	    String val = (String)h.get(key);
	    res += " " + key;
	    if (val.length() > 0)
		res += "=" + val;
	}
	return res + ">";
    }

    /**
     * Look for a method named (open|close)<tag> in this class and
     * call it for the tag
     */
    private void processElement(boolean open, String tag, HTMLNode node) {
	String type = (open ? "open" : "close");
	try {
	    Class[] clzz = new Class[1];
	    clzz[0] = node.getClass();
	    Method m = getClass().getMethod(type + tag, clzz);
	    Object[] args = new Object[1];
	    args[0] = node;
	    m.invoke(this, args);
	} catch (NoSuchMethodException nsme) {
	    throw new Error(type + " not found '" + tag + "'");
	} catch (InvocationTargetException ite) {
	    throw new Error(ite.getMessage() + " in " + type + tag);
	} catch (IllegalAccessException iae) {
	    throw new Error(iae.getMessage() + " in " + type + tag);
	}
    }

    // process a file passed on the command line
    public static void main(String [] args) {
	PrintWriter pw = new PrintWriter(System.out);
	new HTML2TWiki().process(new HTMLParser(args[0]), pw);
	pw.flush();
    }

    public String process(String theHtml, String url) {
	BufferedReader br = new BufferedReader(new StringReader(theHtml));
	HTMLReader htmlr = new HTMLReader(br, url);
	HTMLParser parser = new HTMLParser(htmlr);
	StringWriter sw = new StringWriter();
	PrintWriter pw = new PrintWriter(sw);
	process(parser, pw);
	pw.close();
	return sw.getBuffer().toString();
    }

    void process(HTMLParser parser, PrintWriter o) {
	parser.addScanner(new HTMLLinkScanner());
	parser.addScanner(new HTMLImageScanner());
	parser.addScanner(new HTMLJspScanner());
	parser.addScanner(new HTMLDoctypeScanner());

	out = o;
	bulletType = "";
	filterNLs = true;

	// pass 1: strip unwanted tags, compile new buffer containing
	// the modified input.
	StringBuffer buffer = new StringBuffer();
	Enumeration e = parser.elements();
	while (e.hasMoreElements()) {
	    HTMLNode node = (HTMLNode)e.nextElement();
	    if (node instanceof HTMLDoctypeTag ||
		node instanceof HTMLJspTag ||
		node instanceof HTMLRemarkNode) {
		// ignore
	    } else if (node instanceof HTMLStringNode) {
		out.print(stripNLs(((HTMLStringNode)node).getText()));
	    } else if (node instanceof HTMLImageTag) {
		out.print(node.toHTML());
	    } else if (node instanceof HTMLLinkTag) {
		HTMLLinkTag link = (HTMLLinkTag)node;
		if (link.getLinkText().equals(""))
		    out.print(link.getLink());
		else
		    out.print(" [[" + link.getLink() + "][" +
			link.getLinkText() + "]] ");
		if (linkCallback != null)
		    linkCallback.processLink(link.getLink());
	    } else {
		boolean open = !(node instanceof HTMLEndTag);
		String tag;

		if (open) 
		    tag = ((HTMLTag)node).getTag();
		else
		    tag = ((HTMLEndTag)node).getContents();

		tag = tag.toUpperCase();

		if (ignore.get(tag) != null) {
		    // ignore
		} else if (passThrough.get(tag) != null) {
		    out.print("\n" + toHTML(node));
		} else if (translate.get(tag) != null) {
		    out.print(toHTML(node, (String)translate.get(tag)));
		} else if (ignoreToClose.get(tag) != null) {
		    int level = 0;
		    String t;
		    while (e.hasMoreElements()) {
			node = (HTMLNode)e.nextElement();
			if (node instanceof HTMLEndTag) {
			    t = ((HTMLEndTag)node).getContents().toUpperCase();
			    if (t.equals(tag)) {
				if (level == 0)
				    break;
				level--;
			    }
			} else if (node instanceof HTMLTag) {
			    t = ((HTMLTag)node).getTag().toUpperCase();
			    if (t.equals(tag))
				level++;
			}
		    }
		} else
		    processElement(open, tag, node);
	    }
	}
    }
}
