// Copyright (C) 2004 Crawford Currie - All rights reserved
// It is hereby granted that this software can be used, copied, 
// modified, and distributed without fee provided that this 
// copyright notice appears in all copies.
package com.ccsoft.edit;

import java.awt.*;
import java.util.Enumeration;
import java.util.Stack;
import java.util.Vector;

/**
 * The display entity for a single word (the atomic unit in output)
 */
public class Word extends Block {
    /** the actual word */
    private String text;
    /** the ascent required to get to the baseline of the word from the top */
    private int offset;

    public Word(String w) {
	text = w;
    }

    public void layout(Area area, FontContext fc) {
	x = area.x;
	y = area.y;
	offset = Math.max(area.ascent, fc.fontAscent());
	width = fc.stringWidth(text);
	height = fc.fontHeight();
    }

    public void paint(Graphics g, int ox, int oy, FontContext fonts) {
	if (!paintable(g, ox, oy))
	    return;

	ox += x;
	oy += y + offset;
	g.setColor(fonts.fontColor());
	g.setFont(fonts.font());
	g.drawString(text, ox, oy);
	if ((fonts.fontStyle() & FontContext.UNDERLINE) != 0) {
	    g.drawLine(ox, oy, ox + width, oy);
	}
	if ((fonts.fontStyle() & FontContext.STRIKETHROUGH) != 0) {
	    g.drawLine(ox, oy - offset / 2, ox + width, oy - offset / 2);
	}
    }

    public int minimumWidth(FontContext fc) {
	return fc.stringWidth(text);
    }

    public int minimumHeight(FontContext fc) {
	return fc.fontHeight();
    }

    public int ascent(FontContext fc) {
	return fc.fontAscent();
    }

    public String toString() {
	return text;
    }
}
