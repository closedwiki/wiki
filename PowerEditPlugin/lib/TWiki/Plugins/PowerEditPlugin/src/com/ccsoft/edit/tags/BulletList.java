// Copyright (C) 2004 Crawford Currie - All rights reserved
// It is hereby granted that this software can be used, copied, 
// modified, and distributed without fee provided that this 
// copyright notice appears in all copies.
package com.ccsoft.edit.tags;

import com.ccsoft.edit.Block;

/**
 * A row in a DL, UL or OL list. These elements are created for layout
 * only and have no HTML representation.
 */
class BulletList extends AlignedList {
    public BulletList() {
    }

    public String toHTML(String indent) {
	TaggedBlock b = (TaggedBlock)contents.elementAt(1);
	return "<!--bullet-->" + layoutInfo() + indent + " " +
	    b.toHTML(indent + " ") + indent + "<!--/bullet-->";
    }
}
