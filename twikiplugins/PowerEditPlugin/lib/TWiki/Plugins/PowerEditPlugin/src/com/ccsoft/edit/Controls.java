// Copyright (C) Crawford Currie 2004 - All rights reserved
// It is hereby granted that this software can be used, copied, 
// modified, and distributed without fee provided that this 
// copyright notice appears in all copies.
package com.ccsoft.edit;

import java.io.StringReader;
import java.io.InputStreamReader;
import java.io.IOException;
import java.net.*;
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

	load(st);
    }

    private void load(XMLTokeniser st) throws IOException {
	int t;
	try {
	    // This is a rather cavalier reader, in that it ignores
	    // everything outside the few blocks it's actually interested
	    // in.
	    while ((t = st.nextToken()) != XMLTokeniser.EOF) {
		if (t == XMLTokeniser.TAG &&
		    st.string.equals("load")) {
		    String loadfile = st.attrs.getString("url");
		    System.out.println("Loading " + loadfile);
		    if (loadfile != null) {
			URL url = new URL(loadfile);
			// assume text/html returns text...
			XMLTokeniser sst = new XMLTokeniser(
			    new InputStreamReader(url.openStream()), 1000);
			load(sst);
		    }
		} else if (t == XMLTokeniser.TAG &&
			   (st.string.equals("keys") ||
			    st.string.equals("macros") ||
			    st.string.equals("top") ||
			    st.string.equals("bottom") ||
			    st.string.equals("left") ||
			    st.string.equals("right"))) {
		    ControlBlock b = (ControlBlock)get(st.string);
		    if (b == null)
			put(st.string, b = new ControlBlock());
		    b.parse(st, "/" + st.string);
		}
		// otherwise ignore it
	    }
	} catch (IOException ioe) {
	    ioe.printStackTrace();
	    throw new IOException(ioe.getMessage() + " in controls at line " +
				  st.getLineNumber());
	}
    }

    public ControlBlock getBlock(String block) {
	return (ControlBlock)get(block);
    }
}

