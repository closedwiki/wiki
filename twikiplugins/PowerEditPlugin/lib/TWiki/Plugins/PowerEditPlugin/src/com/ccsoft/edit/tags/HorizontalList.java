// Copyright (C) Crawford Currie 2004 - All rights reserved
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
 * Base class of horizontally-oriented lists, such as flow lists
 * and table rows
 */
abstract class HorizontalList extends ContainerTag {
    protected HorizontalList() {
    }

    protected HorizontalList(XMLTokeniser t) {
	super(t);
    }

    public int minimumWidth(FontContext fc) {
	int w = 0;
	Enumeration e = contents.elements();
	while (e.hasMoreElements()) {
	    Block b = (Block)e.nextElement();
	    w += b.minimumWidth(fc);
	}
	return w;
    }

    public int preferredWidth(FontContext fc) {
	int w = 0;
	Enumeration e = contents.elements();
	while (e.hasMoreElements()) {
	    Block b = (Block)e.nextElement();
	    w += b.preferredWidth(fc);
	}
	return w;
    }

    public int minimumHeight(FontContext fc) {
	int h = 0;
	Enumeration e = contents.elements();
	while (e.hasMoreElements()) {
	    Block b = (Block)e.nextElement();
	    h = Math.max(h, b.minimumHeight(fc));
	}
	return h;
    }

    public int ascent(FontContext fc) {
	int h = 0;
	Enumeration e = contents.elements();
	while (e.hasMoreElements()) {
	    Block b = (Block)e.nextElement();
	    h = Math.max(h, b.ascent(fc));
	}
	return h;
    }

    public int preferredHeight(FontContext fc) {
	int h = 0;
	Enumeration e = contents.elements();
	while (e.hasMoreElements()) {
	    Block b = (Block)e.nextElement();
	    h = Math.max(h, b.preferredHeight(fc));
	}
	return h;
    }
}
