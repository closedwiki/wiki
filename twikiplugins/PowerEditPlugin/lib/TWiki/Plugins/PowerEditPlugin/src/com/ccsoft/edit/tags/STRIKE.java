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
 * HTML Element &lt;STRIKE>
 */
class STRIKE extends FontChange {
    public STRIKE(XMLTokeniser t) {
	super(t);
    }

    protected int getStyleChange() {
	return FontContext.STRIKETHROUGH;
    }
}
