// Copyright (C) Crawford Currie 2004 - All rights reserved
// It is hereby granted that this software can be used, copied, 
// modified, and distributed without fee provided that this 
// copyright notice appears in all copies.
package com.ccsoft.edit.tags;

import java.awt.Graphics;

import java.util.Enumeration;
import java.util.Stack;
import java.util.Vector;

import com.ccsoft.edit.Area;
import com.ccsoft.edit.Block;
import com.ccsoft.edit.FontContext;

/**
 * A horizontal list that tries to fit as much as possible onto a line,
 * but will happily break the line if it doesn't fit.
 */
class Flow extends HorizontalList {
    protected Flow(XMLTokeniser t) {
	super(t);
    }

    /** Set alignment attributes for h and v align */
    public void setAlignment(String alignment) {
    }

    public int minimumWidth(FontContext fc) {
	int w = 0;
	Enumeration e = contents.elements();
	if (preformatted) {
	    int lw = 0;
	    while (e.hasMoreElements()) {
		Block b = (Block)e.nextElement();
		if (b instanceof BR) {
		    w = Math.max(w, lw);
		    lw = 0;
		} else
		    lw += b.minimumWidth(fc);
	    }
	    w = Math.max(w, lw);
	} else {
	    while (e.hasMoreElements()) {
		Block b = (Block)e.nextElement();
		w = Math.max(w, b.minimumWidth(fc));
	    }
	}
	return w;
    }

    public int ascent(FontContext fc) {
	int a = 0;
	Enumeration e = contents.elements();
	if (preformatted) {
	    int la = 0;
	    while (e.hasMoreElements()) {
		Block b = (Block)e.nextElement();
		if (b instanceof BR) {
		    break;
		} else
		    a = Math.max(a, b.ascent(fc));
	    }
	} else {
	    while (e.hasMoreElements()) {
		Block b = (Block)e.nextElement();
		a = Math.max(a, b.ascent(fc));
	    }
	}
	return a;
    }

    public int preferredWidth(FontContext fc) {
	if (preformatted)
	    return minimumWidth(fc);

	int w = 0;
	Enumeration e = contents.elements();
	while (e.hasMoreElements()) {
	    Block b = (Block)e.nextElement();
	    w += b.preferredWidth(fc) + fc.spaceWidth();
	}
	return w;
    }

    public int minimumHeight(FontContext fc) {
	if (!preformatted)
	    return super.minimumHeight(fc);

	int h = 0;
	int lh = 0;
	Enumeration e = contents.elements();
	while (e.hasMoreElements()) {
	    Block b = (Block)e.nextElement();
	    if (b instanceof BR) {
		h += lh;
		lh = 0;
	    } else
		lh = Math.max(lh, b.minimumHeight(fc));
	}
	return h + lh;
    }

    /**
     * Layout the range of items on the current line, resetting
     * the area so it's ready for the next line
     */
    private int flush(int lasti, int i, Area l, FontContext fc) {
	int right = l.x;
	int actualHeight = 0;
	int sw = (preformatted ? 0 : fc.spaceWidth());
	for (int j = lasti; j < i; j++) {
	    Block e = (Block)contents.elementAt(j);
	    e.layout(l, fc);
	    actualHeight = Math.max(actualHeight, e.height);
	    right = l.x + e.width;
	    l.x = right + sw;
	}
	l.y += actualHeight;
	l.x = 0;
	l.ascent = 0;
	return right;
    }

    public void layout(Area area, FontContext fc) {
	x = area.x;
	y = area.y;
	width = 0;
	int sw = (preformatted ? 0 : fc.spaceWidth());
	int right = 0;
	Area l = new Area(0, 0, area.maxWidth, area.ascent);
	int i, lasti = 0;
	int cs = contents.size();
	for (i = 0; i < cs; i++) {
	    Block b = (Block)contents.elementAt(i);
	    int ph = b.preferredWidth(fc);
	    if (preformatted && b instanceof BR ||
		!preformatted && right + ph > area.maxWidth) {
		width = Math.max(width, flush(lasti, i, l, fc));
		right = 0;
		lasti = i;
		if (preformatted) {
		    lasti++;
		    ph = 0;
		}
	    }
	    right += ph + sw;
	    l.ascent = Math.max(l.ascent, b.ascent(fc));
	}
	if (lasti < cs) {
	    width = Math.max(width, flush(lasti, cs, l, fc));
	}
	height = l.y;
    }
}
