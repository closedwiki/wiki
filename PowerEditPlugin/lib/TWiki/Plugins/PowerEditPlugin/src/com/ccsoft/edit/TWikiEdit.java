// Copyright (C) Crawford Currie 2001,2002,2003,2004 - All rights reserved
// It is hereby granted that this software can be used, copied, 
// modified, and distributed without fee provided that this 
// copyright notice appears in all copies.
package com.ccsoft.edit;

import java.applet.Applet;

import java.awt.*;
import java.awt.event.*;
import java.net.*;
import java.io.*;
import java.lang.reflect.*;
import java.util.Enumeration;
import netscape.javascript.JSException;
import netscape.javascript.JSObject;
import java.util.Hashtable;
import com.ccsoft.edit.tags.XMLTokeniser;

/**
 * Editor applet using a Frame and a SearchableTextArea, specifically
 * configured for use with TWiki.
 * The applet may be used either in the browser window or in a separate
 * frame, as defined by the applect parameters:
 * <table>
 *
 * <tr><td>Parameter</td><td>Values</td>
 * <td>Description</td></tr>
 *
 * <tr><td>text</td><td>URL-escaped text</td>
 * <td>Text to edit. The text must be escaped for use in a URL</td></tr>
 *
 * <tr><td>useframe</td><td>"yes" or "no"</td>
 * <td>Whether to use a separate window or not</td></tr>
 *
 * <tr><td>editboxwidth</td><td>Number of columns</td>
 * <td>If useframe=yes, then defines the number of columns width of
 * the edit area</td></tr>
 *
 * <tr><td>editboxheight</td><td>Number of rows</td>
 * <td>If useframe=yes, then defines the number of rows height of
 * the edit area</td></tr>
 *
 * <tr><td>server</td><td>URL</td>
 * <td>The URL that the editor will use to pass information back to the
 * server. The edited text is passed back in the form of MIME-form data.
 * </td></tr>
 *
 * </table>
 */
public class TWikiEdit extends Applet implements Application {

    /** Containing frame */
    static Frame frame = null;
    private Editor editor = null;
    String text, controlsText;

    /** Implements Application to provide the containing Frame */
    public Frame getFrame() {
	if (frame == null)
            return new Frame();
        else
            return frame;
    }

    private static final String truncated(String s) {
	if (s == null)
	    return "null";
	if (s.length() > 40)
	    return s.substring(0, 37) + "...";
	return s;
    }

    /**
     * implementation of three-tier strategy for recovering parameters;
     * First tries to interpret parameter as a Javascript expression,
     * then as a URL, finally assumes it is the actual value.
     */
    private String getLargeParameter(String param) {
	String pval = getParameter(param);
	System.out.println("PARAM " + param + " = " + pval);
	// First try and interpret it as a javascript expression
	Object obj;
	try {
	    JSObject jsWin = JSObject.getWindow(this);
	    try {
		obj = jsWin.eval(pval);
		String val = (String)obj;
		if (val != null)
		    return val;
		else
		    // Have to do this because otherwise compiler doesn't
		    // see JSException thrown by eval and doesn't compile!10h
		    throw new JSException();
	    } catch (ClassCastException cce) {
		System.out.println(param + ": Error interpreting '" +
				   truncated(pval) +
				   "' as a String");
	    } catch (SecurityException se) {
		System.out.println(
		    param +
		    ": Security exception when trying to talk to JavaScript");
	    } catch (JSException jse) {
		System.out.println(param + ": Error interpreting '" + 
				   truncated(pval) +
				   "' as Javascript: " +
				   jse.getMessage());
	    }
	} catch (NoClassDefFoundError ncfe) {
	    System.out.println(param + ": JavaScript not available");
	}
	// Try and interpret it as a URL instead
	try {
	    URL url = new URL(pval);
	    Reader r = new InputStreamReader(url.openStream());
	    int ch;
	    StringBuffer txt = new StringBuffer(1000);
	    while ((ch = r.read()) != -1) {
		txt.append((char)ch);
	    }
	    return txt.toString();
	} catch (MalformedURLException mue) {
	    System.out.println(param + ": '" + truncated(pval) +
			       "' is not a valid URL");
	} catch (IOException ioe) {
	    System.out.println(param + ": IO exception reading from URL - " +
			       ioe.getMessage());
	}
	// Give up; the text is just the value of the parameter
	return pval;
    }

    /** Implements Applet initialisation */
    public synchronized void init() {
	text = getLargeParameter("text");
	controlsText = getLargeParameter("controls");
	
	String uf = getParameter("useframe");
	if (uf == null) {
	    System.out.println("Warning; no useframe parameter");
	}
        boolean framed = (uf != null && uf.equals("yes"));
	Container container;

        if (framed) {
            if (frame == null) {
                frame = new Frame();
            }
	    container = frame;
        } else {
            // if we are switching from framed to unframed, kill the
            // cached frame.
            if (frame != null) {
                frame.hide();
                frame = null;
            }
	    container = this;
	}

	Editor.setApplication(this);

	if (editor == null) {
	    try {
		editor = new Editor(controlsText, container, 0);
	    } catch (IOException ioe) {
		ioe.printStackTrace();
		throw new Error("Failed during startup; stack trace should have been printed");
	    }
	}

	int r = Integer.parseInt(getParameter("editboxheight"));
	int c = Integer.parseInt(getParameter("editboxwidth"));

	// reset the text
	editor.reset(text, r, c);

	if (framed) {
	    frame.pack();
	    frame.setSize(10 * r, 10 * c);
	    frame.show();
        }
    }

    /**
     * Provided for JavaScript to get the value of the text
     */
    public String getText() {
	return editor.getText();
    }

    public void stop() {
	if (frame != null) {
            frame.hide();
        }
    }

    public void start() {
	if (frame != null) {
            frame.show();
        }
    }

    public void destroy() {
	if (frame != null) {
            frame.hide();
            frame.dispose();
        }
        super.destroy();
    }

}
