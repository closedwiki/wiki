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

import com.ccsoft.edit.Area;
import com.ccsoft.edit.Block;
import com.ccsoft.edit.FontContext;

/**
 * An aligned list where the second column is cascaded below the first
 * (as used in Dl type lists)
 */
class CascadedList extends AlignedList {

    public CascadedList(XMLTokeniser t) {
	super(t);
    }

    public int minimumHeight(FontContext fc) {
	int h = 0;
	Enumeration e = contents.elements();
	while (e.hasMoreElements()) {
	    Block b = (Block)e.nextElement();
	    h += b.minimumHeight(fc);
	}
	return h;
    }

    public int preferredHeight(FontContext fc) {
	int h = 0;
	Enumeration e = contents.elements();
	while (e.hasMoreElements()) {
	    Block b = (Block)e.nextElement();
	    h += b.preferredHeight(fc);
	}
	return h;
    }

    public void layout(Area area, FontContext fc) {
	TableInfo cwidths =
	    ((VerticalList)getParent()).getTableInfo(area.maxWidth, fc);

	x = area.x;
	y = area.y;
	width = area.maxWidth;
	Area l = new Area(0, 0, 0, area.ascent);
	int i = 0;
	Enumeration e = contents.elements();
	while (e.hasMoreElements()) {
	    Block b = (Block)e.nextElement();
	    l.maxWidth = cwidths.minWidth[i++];
	    b.layout(l, fc);
	    b.width = l.maxWidth;
	    l.x += b.width;
	    l.y += b.height;
	}
	height = l.y;
    }
}
