// Copyright (C) 2004 Crawford Currie - All rights reserved
// It is hereby granted that this software can be used, copied, 
// modified, and distributed without fee provided that this 
// copyright notice appears in all copies.
package com.ccsoft.edit.tags;

import com.ccsoft.edit.Word;

/**
 * HTML element &lt;DIR>
 */
class DIR extends ColumnarList {
    public DIR(XMLTokeniser t) {
	super(t);
    }

    private class Bullet extends Word {
	Bullet(int pos) {
	    super("   ", pos);
	}

	public String toHTML(String indent) {
	    return "";
	}
    }

    public void tag(XMLTokeniser t) {
	if (t.string.equals("li")) {
	    BulletList row = new BulletList(t);
	    add(row);
	    row.add(new Bullet(t.markerTag));
	    row.add(new LI(t), t);
	} else
	    super.tag(t);
    }
}
