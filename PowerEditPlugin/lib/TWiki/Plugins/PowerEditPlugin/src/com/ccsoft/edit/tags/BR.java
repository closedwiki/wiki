// Copyright (C) Crawford Currie 2004 - All rights reserved
// It is hereby granted that this software can be used, copied, 
// modified, and distributed without fee provided that this 
// copyright notice appears in all copies.
package com.ccsoft.edit.tags;

import java.awt.*;
import com.ccsoft.edit.FontContext;
import com.ccsoft.edit.Area;

/**
 * HTML element &lt;BR>
 */
class BR extends TaggedBlock {

    public BR(XMLTokeniser t) {
	super(t);
    }

    public void parse(XMLTokeniser t) {
	// no terminator, so don't parse to end tag
    }

    public int minimumHeight(FontContext fc) {
	return 0;
    }

    public int ascent(FontContext fc) {
	return 0;
    }

    public int minimumWidth(FontContext fc) {
	return FULL_PAGE;
    }

    public void layout(Area area, FontContext fc) {
	int sp = fc.fontHeight();
	width = area.maxWidth;
	height = minimumHeight(fc);
	x = area.x;
	y = area.y;
    }

    public void paint(Graphics g, int ox, int oy, FontContext fc) {
    }

    public void word(String w) {
	throw new Error("ASSERT");
    }

    public void tag(XMLTokeniser t) {
	throw new Error("ASSERT");
    }
}
