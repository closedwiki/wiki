// Copyright (C) 2004 Crawford Currie - All rights reserved
// It is hereby granted that this software can be used, copied, 
// modified, and distributed without fee provided that this 
// copyright notice appears in all copies.
package com.ccsoft.edit.tags;

import java.awt.Color;
import java.awt.Graphics;

import java.util.Enumeration;
import java.util.Stack;
import java.util.Vector;

import com.ccsoft.edit.FontContext;
import com.ccsoft.edit.Block;
import com.ccsoft.edit.Area;

/**
 * A table (HTML element &lt;TABLE>)
 * ALIGN=[ left | center | right | justify ]
 * BGCOLOR=Color
 */
class TABLE extends VerticalList {
    public TABLE(XMLTokeniser t) {
	super(t);
    }

    public int minimumWidth(FontContext fc) {
	int w = 0;
	Enumeration e = contents.elements();
	while (e.hasMoreElements()) {
	    Block b = (Block)e.nextElement();
	    if (b instanceof AlignedList)
		w = Math.max(w, b.minimumWidth(fc));
	}
	return w;
    }

    public int preferredWidth(FontContext fc) {
	return FULL_PAGE;
    }

    public int minimumHeight(FontContext fc) {
	int h = 0;
	Enumeration e = contents.elements();
	while (e.hasMoreElements()) {
	    Block b = (Block)e.nextElement();
	    if (b instanceof AlignedList)
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
	    if (b instanceof AlignedList)
		h += b.preferredHeight(fc);
	}
	return h;
    }

    public void tag(XMLTokeniser t) {
	if (t.string.equals("tr")) {
	    add(new TR(t), t);
	}
    }

    /**
     * Distribute excess space around the columns
     */
    public TableInfo getTableInfo(int maxWidth, FontContext fc) {
	TableInfo cw = super.getTableInfo(maxWidth, fc);
	//System.out.println("Before " + maxWidth + "\n" + cw.dump());
	int colcount = cw.cols;
	int space = maxWidth;
	int i;
	for (i = 0; i < cw.cols; i++)
	    space -= cw.minWidth[i];

	if (space > 0) {
	    // Distribute space, but don't allow any column to exceed
	    // its preferred width just yet
	    boolean grown;
	    do {
		grown = false;
		for (i = 0; i < cw.cols && space > 0; i++) {
		    if (cw.minWidth[i] < cw.prefWidth[i]) {
			cw.minWidth[i]++;
			space--;
			grown = true;
		    }
		}
	    } while (space > 0 && grown);
	}

	// distribute any excess
	if (space > 0) {
	    int percol = space / cw.cols;
	    if (percol > 0) {
		for (i = 0; i < cw.cols; i++)
		    cw.minWidth[i] += percol;
	    }
	    // dribble any extra into the last column
	    cw.minWidth[cw.cols - 1] += space - percol * cw.cols;
	}

	return cw;
    }

    /**
     * Override to adjust the area according to the WIDTH attribute
     */
    public void layout(Area area, FontContext fc) {
	area.maxWidth = getAttributes().getLength("width", area.maxWidth);
	width = 0;
	Enumeration e = contents.elements();
	Area l = new Area(0, 0, area.maxWidth, area.ascent);
	while (e.hasMoreElements()) {
	    Block b = (Block)e.nextElement();
	    if (b instanceof AlignedList) {
		b.layout(l, fc);
		l.y += b.height;
		width = Math.max(width, b.width);
	    }
	}
	x = area.x;
	y = area.y;
	height = l.y;
    }

    /**
     * Decorate the table with borders
     */
    public void paint(Graphics g, int ox, int oy, FontContext fc) {
	if (!paintable(g, ox, oy))
	    return;

	if (!paintable(g, ox, oy))
	    return;

	ox += x;
	oy += y;

	Color col = getAttributes().getColor("bgcolor");
	if (col != null) {
	    g.setColor(col);
	    g.fillRect(ox + x, oy + y, width, height);
	}

	Enumeration e = contents.elements();
	while (e.hasMoreElements()) {
	    Block l = (Block)e.nextElement();
	    if (l instanceof TR)
		l.paint(g, ox, oy, fc);
	}

	TableInfo cw = getTableInfo(width, fc);
	g.setColor(Color.black);
	int i;
	int xbar = ox;
	int ybar = oy;
	g.drawLine(xbar, ybar, xbar, ybar + height);
	for (i = 0; i < cw.cols; i++) {
	    xbar += cw.minWidth[i];
	    g.drawLine(xbar, ybar, xbar, ybar + height);
	}

	xbar = ox;
	ybar = oy;
	g.drawLine(xbar, ybar, xbar + width, ybar);
	for (i = 0; i < contents.size(); i++) {
	    ybar += ((Block)contents.elementAt(i)).height;
	    g.drawLine(xbar, ybar, xbar + width, ybar);
	}
    }
}
