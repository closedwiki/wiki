// Copyright (C) 2003 Motorola - All rights reserved
// It is hereby granted that this software can be used, copied, 
// modified, and distributed without fee provided that this 
// copyright notice appears in all copies.
package com.ccsoft.edit;

import java.awt.Button;
import java.awt.GridBagConstraints;
import java.awt.GridBagLayout;
import java.awt.Panel;

import java.awt.event.ActionListener;

import java.io.IOException;
import java.util.Hashtable;
import java.util.Enumeration;
import java.util.Vector;

/**
 * A block of ordered button, key or macro definitions
 */
class ControlBlock extends Vector {
    Hashtable quickLook = new Hashtable();

    void parse(ControlTokeniser st) throws IOException {
	while (st.nextToken() == '"') {
	    ControlDefinition cd = new ControlDefinition(st);
	    addElement(cd);
	    quickLook.put(cd.getKey(), cd);
	}
	st.expect("end");
    }

    ControlDefinition getDefinition(String command) {
	return (ControlDefinition)quickLook.get(command);
    }

    Panel makePanel(boolean horizontal, ActionListener al) {
	Panel buttonPanel = new Panel();
	GridBagLayout buttonBag = new GridBagLayout();
	GridBagConstraints buttonBagConstraints = new GridBagConstraints();
	buttonPanel.setLayout(buttonBag);

	Enumeration i = elements();
	while (i.hasMoreElements()) {
	    ControlDefinition cd = (ControlDefinition)i.nextElement();
	    Button but = new Button(cd.getKey());
	    but.setActionCommand(cd.getValue());
	    but.addActionListener(al);
	    if (horizontal)
		buttonBagConstraints.gridx++;
	    else
		buttonBagConstraints.gridy++;
	    buttonBag.setConstraints(but, buttonBagConstraints);
	    buttonPanel.add(but);
	}
	
	return buttonPanel;
    }
}

