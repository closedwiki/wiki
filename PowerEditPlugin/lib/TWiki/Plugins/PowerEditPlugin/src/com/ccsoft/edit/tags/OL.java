// Copyright (C) Crawford Currie 2004 - All rights reserved
// It is hereby granted that this software can be used, copied, 
// modified, and distributed without fee provided that this 
// copyright notice appears in all copies.
package com.ccsoft.edit.tags;

import com.ccsoft.edit.*;

/**
 * A numbered list (HTML element &lt;OL>)
 */
public class OL extends ColumnarList {
    public OL(XMLTokeniser t) {
	super(t);
    }

    private class Ordinal extends Word {
	Ordinal(int i, int pos) {
	    super(i + " ", pos);
	}

	public String toHTML(String indent) {
	    return "";
	}
    }

    public void tag(XMLTokeniser t) {
	if (t.string.equals("li")) {
	    BulletList row = new BulletList(t);
	    add(row);
	    row.add(new Ordinal(contents.size(), t.markerTag));
	    row.add(new LI(t), t);
	} else
	    super.tag(t);
    }
}

