// Copyright (C) Crawford Currie 2004 - All rights reserved
// It is hereby granted that this software can be used, copied, 
// modified, and distributed without fee provided that this 
// copyright notice appears in all copies.
package com.ccsoft.edit.tags;

import java.awt.Color;
import java.awt.Dimension;
import java.awt.Graphics;
import java.util.Enumeration;
import java.util.Stack;
import java.util.Vector;
import com.ccsoft.edit.*;

/**
 * An horizontal list that has controlled alignment and occupies the full
 * width of the available space
 */
class AlignedList extends HorizontalList {
    protected int defaultAlignment = TagAttributes.CENTER;

    protected AlignedList(XMLTokeniser t) {
	super(t);
    }

    public int preferredWidth(FontContext fc) {
	return FULL_PAGE;
    }

    public int minimumWidth(FontContext fc) {
	return FULL_PAGE;
    }

    /**
     * Get column and height information about this row.
     */
    RowInfo getRowInfo(FontContext fc) {
	RowInfo ri = new RowInfo();
	Enumeration e = contents.elements();
	while (e.hasMoreElements()) {
	    Block b = (Block)e.nextElement();
	    int cs = 1;
	    if (b instanceof TaggedBlock) {
		cs = ((TaggedBlock)b).getAttributes().getNumber("colspan", 1);
	    }
	    ri.addCol(b.minimumWidth(fc), b.preferredWidth(fc), cs);
	}
	return ri;
    }

    public void layout(Area area, FontContext fc) {
	if (!(getParent() instanceof VerticalList)) {
	    super.layout(area, fc);
	    return;
	}

	TableInfo cwidths =
	    ((VerticalList)getParent()).getTableInfo(area.maxWidth, fc);
	x = area.x;
	y = area.y;
	height = 0;
	Area l = new Area(0, 0, 0, area.ascent);
	int i = 0;
	Enumeration e = contents.elements();
	while (e.hasMoreElements()) {
	    Block b = (Block)e.nextElement();
	    int cs; // colspan
	    if (b instanceof TaggedBlock) {
		TagAttributes attrs = ((TaggedBlock)b).getAttributes();
		cs = i + attrs.getNumber("colspan", 1);
	    } else {
		cs = i + 1;
	    }

	    l.maxWidth = 0;
	    while (i < cs)
		l.maxWidth += cwidths.minWidth[i++];

	    b.layout(l, fc);

	    b.width = l.maxWidth;
	    l.x += b.width;
	    height = Math.max(height, b.height);
	}
	width = l.x;
    }
}
