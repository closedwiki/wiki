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
 * HTML element &lt;FONT>
 */
class FONT extends FontChange {
    public FONT(XMLTokeniser t) {
	super(t);
    }

    protected String getFaceChange() {
	return (String)attrs.get("face");
    }

    protected int getSizeChange(FontContext fc) {
	String sizes = (String)attrs.get("size");
	int size = 0;
	if (sizes != null) {
	    if (sizes.startsWith("+") || sizes.startsWith("-")) {
		int inc = Integer.parseInt(sizes.substring(1));
		size = fc.fontSize() + inc;
	    } else 
		size = Integer.parseInt(sizes);
	}
	return size;
    }

    protected Color getColorChange(FontContext fc) {
	return getAttributes().getColor("color");
    }
}
