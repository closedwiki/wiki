// Copyright (C) Crawford Currie 2004 - All rights reserved
// It is hereby granted that this software can be used, copied, 
// modified, and distributed without fee provided that this 
// copyright notice appears in all copies.
package com.ccsoft.edit.tags;

import java.awt.Dimension;
import java.awt.Graphics;
import java.util.Enumeration;
import java.util.Stack;
import java.util.Vector;
import com.ccsoft.edit.Block;

/**
 * HTML element &lt;DL>
 */
class DL extends ColumnarList {

    public DL(XMLTokeniser t) {
	super(t);
    }

    public void parse(XMLTokeniser t) {
	super.parse(t);
	Block lastb = null;
	// pair up adjacent Dt/Dl pairs
	for (int i = 0; i < contents.size(); i++) {
	    Block b = (Block)contents.elementAt(i);
	    if (lastb != null && (b instanceof DD) && (lastb instanceof DT)) {
		CascadedList newB = new CascadedList(t);
		newB.add(lastb);
		newB.add(b);
		i--;
		contents.removeElementAt(i);
		contents.removeElementAt(i);
		contents.insertElementAt(newB, i);
		newB.parent = this;
	    }
	    lastb = b;
	}
    }
}
