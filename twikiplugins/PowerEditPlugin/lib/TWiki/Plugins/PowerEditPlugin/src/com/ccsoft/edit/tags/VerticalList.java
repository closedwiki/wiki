// Copyright (C) 2004 Crawford Currie - All rights reserved
// It is hereby granted that this software can be used, copied, 
// modified, and distributed without fee provided that this 
// copyright notice appears in all copies.
package com.ccsoft.edit.tags;

import java.util.Enumeration;
import java.util.Stack;
import java.util.Vector;

import com.ccsoft.edit.Area;
import com.ccsoft.edit.Block;
import com.ccsoft.edit.FontContext;

/**
 * A vertically oriented list, such as a table or bulleted list
 */
abstract class VerticalList extends ContainerTag {
    protected VerticalList(XMLTokeniser t) {
	super(t);
    }

    /** Min width is min width of widest child */
    public int minimumWidth(FontContext fc) {
	int w = 0;
	Enumeration e = contents.elements();
	while (e.hasMoreElements()) {
	    Block b = (Block)e.nextElement();
	    w = Math.max(w, b.minimumWidth(fc));
	}
	return w;
    }

    /** Pref width is pref width of widest child */
    public int preferredWidth(FontContext fc) {
	int w = 0;
	Enumeration e = contents.elements();
	while (e.hasMoreElements()) {
	    Block b = (Block)e.nextElement();
	    w = Math.max(w, b.preferredWidth(fc));
	}
	return w;
    }

    /** Min height is sum of children */
    public int minimumHeight(FontContext fc) {
	int h = 0;
	Enumeration e = contents.elements();
	while (e.hasMoreElements()) {
	    Block b = (Block)e.nextElement();
	    h += b.minimumHeight(fc);
	}
	return h;
    }

    /** Pref height is sum of children */
    public int preferredHeight(FontContext fc) {
	int h = 0;
	Enumeration e = contents.elements();
	while (e.hasMoreElements()) {
	    Block b = (Block)e.nextElement();
	    h += b.preferredHeight(fc);
	}
	return h;
    }

    public int ascent(FontContext fc) {
	if (contents.size() == 0)
	    return 0;
	return ((Block)contents.elementAt(0)).ascent(fc);
    }

    /**
     * Get minimum and preferred width info from children of this
     * list. Used in computation of column widths for laying out
     * tables and bulleted lists etc.
     * @param mw the maximum width of this container, useful in allocating
     * extra space to columns
     * @param fc the font context
     * @throws ClassCastException if any children are not AlignedLists
     */
    public TableInfo getTableInfo(int mw, FontContext fc) {
	TableInfo cw = new TableInfo();
	Enumeration e = contents.elements();
	while (e.hasMoreElements()) {
	    Block b = (Block)e.nextElement();
	    if (b instanceof AlignedList) {
		RowInfo ri = ((AlignedList)b).getRowInfo(fc);
		if (ri != null) {
		    cw.addRow(ri);
		}
	    }
	}
	cw.layout(mw);

	return cw;
    }

    public void layout(Area area, FontContext fc) {
	width = 0;
	Enumeration e = contents.elements();
	Area l = new Area(0, 0, area.maxWidth, area.ascent);
	while (e.hasMoreElements()) {
	    Block b = (Block)e.nextElement();
	    b.layout(l, fc);
	    l.y += b.height;
	    width = Math.max(width, b.width);
	}
	x = area.x;
	y = area.y;
	height = l.y;
    }
}
