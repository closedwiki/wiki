// Copyright (C) Crawford Currie 2004 - All rights reserved
// It is hereby granted that this software can be used, copied, 
// modified, and distributed without fee provided that this 
// copyright notice appears in all copies.
package com.ccsoft.edit;

import java.awt.Component;
import java.awt.LayoutManager;
import java.awt.Button;
import java.awt.Panel;

import java.awt.event.ActionListener;

import java.io.IOException;
import java.util.Hashtable;
import java.util.Enumeration;
import java.util.Vector;
import com.ccsoft.edit.tags.XMLTokeniser;

/**
 * A block of ordered button, key or macro definitions (ordered because
 * we generate a panel from them)
 */
class ControlBlock extends Vector {
    Hashtable quickLook = new Hashtable();

    void parse(XMLTokeniser st, String terminator) throws IOException {
	while (st.nextToken() == XMLTokeniser.TAG) {
	    if (st.string.equals(terminator))
		return;
	    
	    if (st.string.equals("map")) {
		String name = st.attrs.getString("name");
		String def = st.attrs.getString("action");
		String tip = st.attrs.getString("tip");
		if (name == null)
		    throw new IOException("No name= in <map>");
		if (def == null)
		    throw new IOException("No action= in <map>");
		ControlDefinition cd = new ControlDefinition(name, def, tip);
		addElement(cd);
		quickLook.put(cd.getKey(), cd);
	    }
	}
	throw new IOException("Bad " + terminator + " block " + st);
    }

    ControlDefinition getDefinition(String command) {
	return (ControlDefinition)quickLook.get(command);
    }

    /**
     */
    Panel makePanel(LayoutManager layout, ActionListener al) {
	Panel buttonPanel = new Panel();
	buttonPanel.setLayout(layout);
	Enumeration i = elements();
	while (i.hasMoreElements()) {
	    ControlDefinition cd = (ControlDefinition)i.nextElement();
	    buttonPanel.add(cd.createButton(al));
	}
	
	return buttonPanel;
    }
}

