package com.ccsoft.edit;

import java.io.*;
import java.net.*;
import java.util.*;
import java.lang.reflect.*;

import com.kizna.html.*;
import com.kizna.html.tags.*;

/**
 * Conversion from HTML to TWiki ML
 * Does as well as it can in the circumstances!
 * Methods are provided to handle most of the basic node types and
 * ignore others. When a method is not found to handle a node type,
 * the HTML is simply reflected.
 */
public class HTML2TWiki {
    PrintWriter out;
    String bulletType;
    boolean filterNLs;
    int withinTABLE;

    public void openA(HTMLTag node) {
	// This only occurs when its <A NAME=
	// <A HREF= gets caught as a HTMLLinkNode
	out.println("\n#" + node.getParameter("NAME"));
    }

    public void closeA(HTMLEndTag node) {
	// ignore
    }

    public void openB(HTMLTag node) {
	// look ahead to see if we are around 
	out.print(" *");
    }

    public void closeB(HTMLEndTag node) {
	out.print("* ");
    }

    public void openBODY(HTMLTag node) {
    }

    public void closeBODY(HTMLEndTag node) {
    }

    public void openDIV(HTMLTag node) {
	// Ignore DIV
    }

    public void closeDIV(HTMLEndTag node) {
	// Ignore DIV
    }

    public void closeFONT(HTMLEndTag node) {
    }

    public void openHEAD(HTMLTag node) {
    }

    public void closeHEAD(HTMLEndTag node) {
    }

    public void openHR(HTMLTag node) {
	out.println("\n---");
    }

    public void openHTML(HTMLTag node) {
    }

    public void closeHTML(HTMLEndTag node) {
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

    public void openNOBR(HTMLTag node) {
    }

    public void closeNOBR(HTMLEndTag node) {
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

    public void openPRE(HTMLTag node) {
	out.print(node.toHTML());
	filterNLs = false;
    }

    public void closePRE(HTMLEndTag node) {
	out.print(node.toHTML());
	filterNLs = true;
    }

    public void openSPAN(HTMLTag node) {
    }

    public void closeSPAN(HTMLEndTag node) {
    }

    public void openSTRONG(HTMLTag node) {
	out.print(" __");
    }

    public void closeSTRONG(HTMLEndTag node) {
	out.print("__ ");
    }

    public void openSUP(HTMLTag node) {
	out.print(node.toHTML());
    }

    public void closeSUP(HTMLEndTag node) {
	out.print("</sup>");
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

    private void invoke(String type, HTMLNode node) {
	String tag;
	if (node instanceof HTMLEndTag)
	    tag = ((HTMLEndTag)node).getContents().toUpperCase();
	else
	    tag = ((HTMLTag)node).getTag().toUpperCase();
	try {
	    Class[] clzz = new Class[1];
	    clzz[0] = node.getClass();
	    Method m = getClass().getMethod(type + tag, clzz);
	    Object[] args = new Object[1];
	    args[0] = node;
	    m.invoke(this, args);
	} catch (NoSuchMethodException nsme) {
	    // ignore silently; not interested
	    System.err.println(type + " not found '" + tag + "'");
	    out.print(node.toHTML());
	} catch (InvocationTargetException ite) {
	    throw new Error(ite.getMessage() + " in " + tag);
	} catch (IllegalAccessException iae) {
	    throw new Error(iae.getMessage() + " in " + tag);
	}
    }

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

    private void process(HTMLParser parser, PrintWriter o) {
	parser.registerScanners();
	Enumeration e = parser.elements();
	out = o;
	bulletType = "";
	filterNLs = true;
	withinTABLE = 0;

	while (e.hasMoreElements()) {
	    HTMLNode node = (HTMLNode)e.nextElement();
	    if (node instanceof HTMLAppletTag ||
		node instanceof HTMLDoctypeTag ||
		node instanceof HTMLFormTag ||
		node instanceof HTMLFrameSetTag ||
		node instanceof HTMLFrameTag ||
		node instanceof HTMLJspTag ||
		node instanceof HTMLRemarkNode ||
		node instanceof HTMLMetaTag ||
		node instanceof HTMLScriptTag ||
		node instanceof HTMLStyleTag ||
		node instanceof HTMLTitleTag) {
	    } else if (node instanceof HTMLStringNode) {
		String text = ((HTMLStringNode)node).getText();
		out.print(stripNLs(text));
	    } else if (node instanceof HTMLImageTag) {
		out.print(node.toHTML());
	    } else if (node instanceof HTMLLinkTag) {
		HTMLLinkTag link = (HTMLLinkTag)node;
		if (link.getLinkText().equals(""))
		    out.print(link.getLink());
		else
		    out.print(" [[" + link.getLink() + "][" +
			link.getLinkText() + "]] ");
	    } else if (node instanceof HTMLEndTag) {
		String tag = ((HTMLEndTag)node).getContents().toUpperCase();
		invoke("close", node);
	    } else if (node instanceof HTMLTag) {
		invoke("open", node);
	    } else {
		System.err.println("Unhandled " + node.getClass());
	    }
	}
    }
}
