// Copyright (C) 2004 Crawford Currie - All rights reserved
// It is hereby granted that this software can be used, copied, 
// modified, and distributed without fee provided that this 
// copyright notice appears in all copies.
package com.ccsoft.edit.tags;

import com.ccsoft.edit.Word;

/**
 * A bulleted list (HTML element &lt;UL>)
 */
class UL extends ColumnarList {
    public UL(XMLTokeniser t) {
	super(t);
    }

    private class Bullet extends Word {
	Bullet(int pos) {
	    super(EntityExpandingReader.getEntity("bull") + " ", pos);
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
