// Copyright (C) 2003 Motorola - All rights reserved
// It is hereby granted that this software can be used, copied, 
// modified, and distributed without fee provided that this 
// copyright notice appears in all copies.
package com.ccsoft.edit;

import java.io.IOException;
import java.util.Hashtable;

/**
 * Class that manages controls.
 * A Controls object is a hashtable keyed on the name of the control
 * block.
 */
class Controls extends Hashtable {

    Controls(String controlText) throws IOException {
	ControlTokeniser st = new ControlTokeniser(controlText);
	try {
	    while (st.nextToken() == ControlTokeniser.TT_WORD) {
		ControlBlock b = (ControlBlock)get(st.sval);
		if (b == null)
		    put(st.sval, b = new ControlBlock());
		b.parse(st);
	    }
	} catch (IOException ioe) {
	    throw new IOException(
		ioe.getMessage() +
		" while parsing controls; line " + st.lineno());
	}
    }

    public ControlBlock getBlock(String block) {
	return (ControlBlock)get(block);
    }
}

