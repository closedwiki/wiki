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
 * HTML Element &lt;SUP>
 */
class SUP extends SMALL {
    public SUP(XMLTokeniser t) {
	super(t);
    }

    public int minimumHeight(FontContext fc) {
	int rise = fc.fontAscent() / 2;
	return super.minimumHeight(fc) + rise;
    }

    public int preferredHeight(FontContext fc) {
	int rise = fc.fontAscent() / 2;
	return rise + super.preferredHeight(fc);
    }

    public int ascent(FontContext fc) {
	int a = super.ascent(fc);
	return fc.fontAscent() / 2 + a;;
    }

    public void layout(Area area, FontContext fc) {
	int rise = fc.fontAscent() / 2;
	pushFont(fc);
	Area l = new Area(area.x, area.y, area.maxWidth,
			  Math.max(0, area.ascent - rise));
	super.layout(l, fc);
	fc.popFont();
    }
}
