// Copyright (C) Crawford Currie 2001 - All rights reserved
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
    /** Editing area */
    static Editor editor;

    String text, controlsText;

    /** Implements Application to provide the containing Frame */
    public Frame getFrame() {
	if (frame == null)
            return new Frame();
        else
            return frame;
    }

    /** Get a field in the form */
    private String getFieldValue(JSObject form, String field) {
	JSObject member = (JSObject)form.getMember(field);
	String val = (String)member.getMember("value");
	if (val != null) {
	    StringBuffer s = new StringBuffer();
	    for (int i = 0; i < val.length(); i++) {
		if (val.charAt(i) != '\r')
		    s.append(val.charAt(i));
	    }
	    val = s.toString();
	}
	return val;
    }

    private void getLargeParameters() {
	text = controlsText = null;
	try {
	    JSObject jsWin = JSObject.getWindow(this);
	    JSObject doc = (JSObject)jsWin.getMember("document");
	    JSObject form = (JSObject)doc.getMember("main");
	    text = getFieldValue(form, "text");
	    controlsText = getFieldValue(form, "controls");
	} catch (NoClassDefFoundError ncfe) {
	    System.out.println("JavaScript not available; trying applet parameters");
	    text = getParameter("text");
	    // XMLTokeniser.decode()
	    controlsText = getParameter("controls");
	}
    }

    /** Implements Applet initialisation */
    public synchronized void init() {

	getLargeParameters();
	
	String uf = getParameter("useframe");
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

	if (editor == null) {
	    try {
		editor = new Editor(controlsText, container, this);
	    } catch (IOException ioe) {
		ioe.printStackTrace();
		throw new Error("Failed during startup; stack trace should have been printed");
	    }
	}

	int r = Integer.parseInt(getParameter("editboxheight"));
	int c = Integer.parseInt(getParameter("editboxwidth"));

	// Attach the editor to this application and reset the text
	editor.reset(this, text, r, c);
	
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
