// Copyright (C) 2004 Crawford Currie - All rights reserved
// It is hereby granted that this software can be used, copied, 
// modified, and distributed without fee provided that this 
// copyright notice appears in all copies.
package com.ccsoft.edit.tags;

import java.awt.Color;
import java.awt.Graphics;
import com.ccsoft.edit.FontContext;

/**
 * A table cell (HTML element &lt;TD>)
 * ALIGN=[ left | center | right | justify ]
 * VALIGN=[ top | middle | bottom | baseline ]
 * BGCOLOR=Color
 */
class TD extends Flow {
    public TD(XMLTokeniser t) {
	super(t);
    }

    public void paint(Graphics g, int ox, int oy, FontContext fc) {
	Color col = getAttributes().getColor("bgcolor");
	if (col != null) {
	    g.setColor(col);
	    g.fillRect(ox + x, oy + y, width, height);
	}
	super.paint(g, ox, oy, fc);
    }
}
