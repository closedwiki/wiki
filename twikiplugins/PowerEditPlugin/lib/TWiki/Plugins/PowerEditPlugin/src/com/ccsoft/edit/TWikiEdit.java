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
    static SearchableTextArea textarea;
    /** Edit controls */
    Controls controls;
    /** Listener for control actions */
    ActionListener actionListener;
    /** JavaScript reference to form object */
    JSObject form;

    /** Implements Application to provide the containing Frame */
    public Frame getFrame() {
	if (frame == null)
            return new Frame();
        else
            return frame;
    }

    /** Get a field in the form */
    private String getFieldValue(String field) {
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

    /** Set a field in the form */
    private void setFieldValue(String field, String value) {
	JSObject member = (JSObject)form.getMember(field);
        member.setMember(field, value);
    }

    /** Implements Applet initialisation */
    public synchronized void init() {
	JSObject jsWin = JSObject.getWindow(this);
	JSObject doc = (JSObject)jsWin.getMember("document");
	form = (JSObject)doc.getMember("main");

        boolean framed = getParameter("useframe") != null &&
            getParameter("useframe").equals("yes");

	controls = null;

	String text = getFieldValue("text");
	String ct = getFieldValue("controls");
	try {
	    controls = new Controls(ct);
	} catch (IOException cioe) {
	    text = cioe.getMessage() + "\n" + ct;
	}

        textarea = new SearchableTextArea(controls);
	actionListener =
	    new ActionListener() {
		    public void actionPerformed(ActionEvent e) {
			textarea.replayMacro(e.getActionCommand());
		    }
		};

        if (framed) {
            int r = Integer.parseInt(getParameter("editboxheight"));
            int c = Integer.parseInt(getParameter("editboxwidth"));
            textarea.reset(this, text, r, c);
            if (frame == null) {
                frame = new Frame();
		makeStandardLayout(frame);
            }
            frame.pack();
            frame.show();
        } else {
            // if we are switching from framed to unframed, kill the
            // cached frame.
            if (frame != null) {
                frame.hide();
                frame = null;
            }
            // reset the textarea to a small size; it will be resized
            // by the layout manager.
            textarea.reset(this, text, 10, 100);
	    makeStandardLayout(this);
        }
    }

    /**
     * Provided for JavaScript to get the value of the text
     */
    public String getText() {
	System.out.println("Got text " + textarea.getText());
	return textarea.getText();
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

    Panel makePanel(ControlBlock b, boolean horizontal) {
	Panel buttonPanel = new Panel();
	GridBagLayout buttonBag = new GridBagLayout();
	GridBagConstraints buttonBagConstraints = new GridBagConstraints();
	buttonPanel.setLayout(buttonBag);

	Enumeration i = b.elements();
	while (i.hasMoreElements()) {
	    ControlDefinition cd = (ControlDefinition)i.nextElement();
	    Button but = new Button(cd.getKey());
	    but.setActionCommand(cd.getValue());
	    but.addActionListener(actionListener);
	    if (horizontal)
		buttonBagConstraints.gridx++;
	    else
		buttonBagConstraints.gridy++;
	    buttonBag.setConstraints(but, buttonBagConstraints);
	    buttonPanel.add(but);
	}
	
	return buttonPanel;
    }

    /**
     * Create the standard layout of panels in the container. Buttons
     * are given the action listener passed.
     */
    void makeStandardLayout(Container container) {

        GridBagLayout layout = new GridBagLayout();
        container.setLayout(layout);
        GridBagConstraints gbc = new GridBagConstraints();

	Panel p;
	ControlBlock b = controls.getBlock("top");
	if (b != null) {
	    p = makePanel(b, true);
	    gbc.gridx = 1; gbc.gridy = 0;
	    gbc.anchor = GridBagConstraints.WEST;
	    layout.setConstraints(p, gbc);
	    container.add(p);
	}

	b = controls.getBlock("bottom");
	if (b != null) {
	    p = makePanel(b, true);
	    gbc.gridx = 1; gbc.gridy = 2;
	    gbc.anchor = GridBagConstraints.WEST;
	    layout.setConstraints(p, gbc);
	    container.add(p);
	}

	b = controls.getBlock("left");
	if (b != null) {
	    p = makePanel(b, false);
	    gbc.gridx = 0; gbc.gridy = 1;
	    gbc.anchor = GridBagConstraints.NORTH;
	    layout.setConstraints(p, gbc);
	    container.add(p);
	}

	b = controls.getBlock("right");
	if (b != null) {
	    p = makePanel(b, false);
	    gbc.gridx = 2; gbc.gridy = 1;
	    gbc.anchor = GridBagConstraints.NORTH;
	    layout.setConstraints(p, gbc);
	    container.add(p);
	}

	gbc.gridx = 1; gbc.gridy = 1;
        gbc.fill = GridBagConstraints.BOTH;
        gbc.weightx = 1.0;
        gbc.weighty = 1.0;
        layout.setConstraints(textarea, gbc);
        container.add(textarea);
    }
}
