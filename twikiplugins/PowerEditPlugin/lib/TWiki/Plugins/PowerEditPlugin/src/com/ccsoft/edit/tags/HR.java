// Copyright (C) Crawford Currie 2004 - All rights reserved
// It is hereby granted that this software can be used, copied, 
// modified, and distributed without fee provided that this 
// copyright notice appears in all copies.
package com.ccsoft.edit.tags;

import java.awt.Color;
import java.awt.Graphics;
import com.ccsoft.edit.FontContext;

/**
 * A horizontal rule (HTML element &lt;HR>)
 */
class HR extends P {
    public HR(XMLTokeniser t) {
	super(t);
    }

    public void paint(Graphics g, int ox, int oy, FontContext fc) {
	if (!paintable(g, ox, oy))
	    return;
	g.setColor(Color.black);
	int o = height / 2;
	g.drawLine(ox + x, oy + y + o, ox + x + width, oy + y + o);
    }
}
