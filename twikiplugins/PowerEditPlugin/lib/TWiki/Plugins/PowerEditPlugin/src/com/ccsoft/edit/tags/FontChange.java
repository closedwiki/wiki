// Copyright (C) Crawford Currie 2004 - All rights reserved
// It is hereby granted that this software can be used, copied, 
// modified, and distributed without fee provided that this 
// copyright notice appears in all copies.
package com.ccsoft.edit.tags;

import java.awt.Font;
import java.awt.Graphics;
import java.awt.Color;
import com.ccsoft.edit.FontContext;
import com.ccsoft.edit.Area;
import java.util.Hashtable;

/**
 * Base class for all elements that change fonts (such as headings).
 */
class FontChange extends Flow {
    public FontChange(XMLTokeniser t) {
	super(t);
    }

    protected void pushFont(FontContext fc) {
	fc.pushFont(getFaceChange(), getStyleChange(),
		    getSizeChange(fc), getColorChange(fc));
    }

    public int ascent(FontContext fc) {
	pushFont(fc);
	int d = super.ascent(fc);
	fc.popFont();
	return d;
    }

    public int minimumWidth(FontContext fc) {
	pushFont(fc);
	int d = super.minimumWidth(fc);
	fc.popFont();
	return d;
    }

    public int minimumHeight(FontContext fc) {
	pushFont(fc);
	int d = super.minimumHeight(fc);
	fc.popFont();
	return d;
    }

    public int preferredWidth(FontContext fc) {
	pushFont(fc);
	int d = super.preferredWidth(fc);
	fc.popFont();
	return d;
    }

    public int preferredHeight(FontContext fc) {
	pushFont(fc);
	int d = super.preferredHeight(fc);
	fc.popFont();
	return d;
    }

    protected String getFaceChange() {
	return null;
    }

    protected int getStyleChange() {
	return -1;
    }

    protected int getSizeChange(FontContext fc) {
	return -1;
    }

    protected Color getColorChange(FontContext fc) {
	return null;
    }

    public void layout(Area area, FontContext fc) {
	pushFont(fc);
	super.layout(area, fc);
	fc.popFont();
    }

    public void paint(Graphics g, int ox, int oy, FontContext fc) {
	pushFont(fc);
	super.paint(g, ox, oy, fc);
	fc.popFont();
    }
}
