// Copyright (C) Crawford Currie 2004 - All rights reserved
// It is hereby granted that this software can be used, copied, 
// modified, and distributed without fee provided that this 
// copyright notice appears in all copies.
package com.ccsoft.edit;

import java.io.StringReader;
import java.io.IOException;
import java.util.Hashtable;
import com.ccsoft.edit.tags.XMLTokeniser;

/**
 * Class that manages controls.
 * A Controls object is a hashtable keyed on the name of the control
 * block.
 */
class Controls extends Hashtable {

    Controls() {
    }

    Controls(String controlText) throws IOException {
	if (controlText == null)
	    throw new IOException("No controls text");

	XMLTokeniser st = new XMLTokeniser(new StringReader(controlText),
					     controlText.length());
	int t;
	try {
	    while ((t = st.nextToken()) == XMLTokeniser.TAG) {
		// ignore <verbatim> and </verbatim>
		if (st.string.equals("verbatim") ||
		    st.string.equals("/verbatim"))
		    continue;
		ControlBlock b = (ControlBlock)get(st.string);
		if (b == null)
		    put(st.string, b = new ControlBlock());
		b.parse(st, "/" + st.string);
	    }
	    if (t == XMLTokeniser.WORD)
		throw new IOException("Unexpected word " + st.string);
	} catch (IOException ioe) {
	    throw new IOException(ioe.getMessage() + " in controls at line " +
				  st.getLineNumber());
	}
    }

    public ControlBlock getBlock(String block) {
	return (ControlBlock)get(block);
    }
}

