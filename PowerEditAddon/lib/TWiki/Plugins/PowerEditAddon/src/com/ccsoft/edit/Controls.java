// Copyright (C) Crawford Currie 2001 - All rights reserved
// It is hereby granted that this software can be used, copied, 
// modified, and distributed without fee provided that this 
// copyright notice appears in all copies.
package com.ccsoft.edit;

import java.awt.*;
import java.awt.event.*;
import java.io.*;
import java.util.Enumeration;
import java.util.Hashtable;
import java.util.Vector;

/**
 * Class that manages controls.
 * A Controls object is a hashtable keyed on the name of the control block. Each object in the hashtable is
 * a vector of string mappings.
 */
class Controls extends Hashtable {
    private Checkbox editLock, noNotify;

    private class ParseException extends IOException {
    }

    private class Definition {
	public String key, cmd;

	Definition(String f, String t) {
	    key = f;
	    cmd = t;
	}

	Definition(StreamTokenizer st) throws IOException {
	    key = st.sval;
	    expect(st, '=');
	    expect(st, '"');
	    cmd = st.sval;
	}

	Button makeButton(ActionListener l) {
	    Button but = new Button(key);
	    but.setActionCommand(cmd);
	    but.addActionListener(l);
	    return but;
	}
    }

    /**
     * A block of button, key or macro definitions
     */
    private class Block extends Vector {

	void parse(StreamTokenizer st) throws IOException {
	    while (st.nextToken() == '"') {
		addElement(new Definition(st));
	    }
	    expect(st, "end");
	}

	Panel makePanel(ActionListener l, boolean horizontal) {
	    Panel buttonPanel = new Panel();
	    GridBagLayout buttonBag = new GridBagLayout();
	    GridBagConstraints buttonBagConstraints = new GridBagConstraints();
	    buttonPanel.setLayout(buttonBag);

	    Enumeration i = elements();
	    while (i.hasMoreElements()) {
		Definition d = (Definition)i.nextElement();
		Button b = d.makeButton(l);
		if (horizontal)
		    buttonBagConstraints.gridx++;
		else
		    buttonBagConstraints.gridy++;
		buttonBag.setConstraints(b, buttonBagConstraints);
		buttonPanel.add(b);
	    }

	    return buttonPanel;
	}

	Definition lookup(String name) {
	    Enumeration i = elements();
	    while (i.hasMoreElements()) {
		Definition d = (Definition)i.nextElement();
		if (d.key.equals(name))
		    return d;
	    }
	    return null;
	}
    }

    Controls() {
    }

    /** Create from a control file */
    public void parse(String controlText) throws IOException {
	StreamTokenizer st = new StreamTokenizer(new StringReader(controlText));
	st.commentChar('<');
	st.slashStarComments(false);
	st.slashSlashComments(false);

	try {
	    while (st.nextToken() == StreamTokenizer.TT_WORD) {
		Block b = (Block)get(st.sval);
		if (b == null)
		    put(st.sval, b = new Block());
		b.parse(st);
	    }
	} catch (IOException ioe) {
	    throw new IOException(ioe.getMessage() +
			    " while parsing controls; line " + st.lineno());
	}
    }

    private void expect(StreamTokenizer st, char c) throws IOException {
	if (st.nextToken() != c)
	    throw new IOException("Expected '" + c + "' in controls at line " +
		st.lineno() + " but saw '" + st + "'");
    }

    private void expect(StreamTokenizer st, String s) throws IOException {
	if (st.ttype != StreamTokenizer.TT_WORD ||
	    !st.sval.equals(s))

	    throw new IOException("Expected '" + s + "' in controls at line " +
		st.lineno() + " but saw '" + st + "'");
    }

    Panel makePanel(String name, ActionListener l, boolean horizontal) {
	Block b = (Block)get(name);
	if (b == null)
	    return null;
	return b.makePanel(l, horizontal);
    }

    /**
     * Create the standard layout of panels in the container. Buttons
     * are given the action listener passed.
     */
    void makeStandardLayout(Container container, SearchableTextArea textarea,
			    ActionListener l) {

        GridBagLayout layout = new GridBagLayout();
        container.setLayout(layout);
        GridBagConstraints gbc = new GridBagConstraints();

	Panel p = makePanel("top", l, true);
	if (p != null) {
	    gbc.gridx = 1; gbc.gridy = 0;
	    gbc.anchor = GridBagConstraints.WEST;
	    layout.setConstraints(p, gbc);
	    container.add(p);
	}

	p = makePanel("bottom", l, true);
	if (p != null) {
	    gbc.gridx = 1; gbc.gridy = 2;
	    gbc.anchor = GridBagConstraints.WEST;
	    layout.setConstraints(p, gbc);
	    container.add(p);
	}

	p = makePanel("left", l, false);
	if (p != null) {
	    gbc.gridx = 0; gbc.gridy = 1;
	    gbc.anchor = GridBagConstraints.NORTH;
	    layout.setConstraints(p, gbc);
	    container.add(p);
	}

	p = makePanel("right", l, false);
	if (p != null) {
	    gbc.gridx = 2; gbc.gridy = 1;
	    gbc.anchor = GridBagConstraints.NORTH;
	    layout.setConstraints(p, gbc);
	    container.add(p);
	}

	p = new Panel();
	p.setLayout(new FlowLayout());
	Button preview = new Definition("Preview", "/preview/").makeButton(l);
	p.add(preview);
	Button save = new Definition("Save", "/save/").makeButton(l);
	p.add(save);
	editLock = new Checkbox("Release edit lock", true);
	p.add(editLock);
	noNotify = new Checkbox("Minor changes, don't notify", false);
	p.add(noNotify);

	gbc.gridx = 1;
	gbc.gridy = 3;
	gbc.anchor = GridBagConstraints.WEST;
	layout.setConstraints(p, gbc);
	container.add(p);

	gbc.gridx = 1; gbc.gridy = 1;
        gbc.fill = GridBagConstraints.BOTH;
        gbc.weightx = 1.0;
        gbc.weighty = 1.0;
        layout.setConstraints(textarea, gbc);
        container.add(textarea);

    }

    public String getDefinition(String block, String command) {
	Block b = (Block)get(block);
	if (b != null) {
	    Definition d = b.lookup(command);
	    if (d != null)
		return d.cmd;
	}
	return null; 
    }

    public String getMacro(String command) {
	return getDefinition("macros", command);
    }

    public String getKey(String key) {
	return getDefinition("ctrlkeys", key);
    }

    public void setDefaultControls(boolean not, boolean rel) {
	editLock.setState(rel);
	noNotify.setState(rel);
    }

    public boolean getReleaseLock() {
	return editLock.getState();
    }

    public boolean getDontNotify() {
	return noNotify.getState();
    }
}

