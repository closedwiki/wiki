// Copyright (C) Crawford Currie 2004 - All rights reserved
// It is hereby granted that this software can be used, copied, 
// modified, and distributed without fee provided that this 
// copyright notice appears in all copies.
package com.ccsoft.edit.tags;

import java.awt.Color;
import java.awt.Graphics;
import com.ccsoft.edit.*;

/**
 * A tage rendered as a box
 */
class BoxTag extends ContainerTag {
    protected String text;

    public BoxTag(XMLTokeniser t) {
	super(t);
	text = getTag();
    }

    private void pushFont(FontContext fc) {
	fc.pushFont("CourierNew", FontContext.UNDERLINE, 1, Color.red);
    }

    public int minimumHeight(FontContext fc) {
	pushFont(fc);
	int d = fc.fontHeight();
	fc.popFont();
	return d;
    }

    public int ascent(FontContext fc) {
	pushFont(fc);
	int d = fc.fontAscent();
	fc.popFont();
	return d;
    }

    public int minimumWidth(FontContext fc) {
	pushFont(fc);
	int d = fc.stringWidth(text);
	fc.popFont();
	return d;
    }

    public void layout(Area area, FontContext fc) {
	pushFont(fc);
	width = fc.stringWidth(text);
	height = fc.fontHeight();
	x = area.x;
	y = area.y;
	fc.popFont();
    }

    public void paint(Graphics g, int ox, int oy, FontContext fc) {
	pushFont(fc);
	g.setColor(Color.red);
	g.drawRect(ox + x, oy + y, width, height);
	ox += x;
	oy += y + fc.fontAscent();
	g.setFont(fc.font());
	g.drawString(text, ox, oy);
	fc.popFont();
    }
}
