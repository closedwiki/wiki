// Copyright (C) Crawford Currie 2004 - All rights reserved
// It is hereby granted that this software can be used, copied, 
// modified, and distributed without fee provided that this 
// copyright notice appears in all copies.
package com.ccsoft.edit.tags;

import java.awt.Graphics;
import com.ccsoft.edit.*;

/**
 * An ignored tag
 */
public class IgnoreTag extends ContainerTag {
    public IgnoreTag(XMLTokeniser t) {
	super(t);
    }

    public int minimumHeight(FontContext fc) {
	return 0;
    }

    public int ascent(FontContext fc) {
	return 0;
    }

    public int minimumWidth(FontContext fc) {
	return 0;
    }

    public void layout(Area area, FontContext fc) {
	width = 0;
	height = 0;
	x = area.x;
	y = area.y;
    }

    public void paint(Graphics g, int ox, int oy, FontContext fc) {
    }
}
