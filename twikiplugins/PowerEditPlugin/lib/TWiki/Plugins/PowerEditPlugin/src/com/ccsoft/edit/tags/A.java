// Copyright (C) Crawford Currie 2004 - All rights reserved
// It is hereby granted that this software can be used, copied, 
// modified, and distributed without fee provided that this 
// copyright notice appears in all copies.
package com.ccsoft.edit.tags;

import java.awt.Color;
import java.awt.Font;
import com.ccsoft.edit.FontContext;

/**
 * HTML element &lt;A>
 */
public class A extends U {
    public A(XMLTokeniser t) {
	super(t);
    }

    protected Color getColorChange(FontContext fc) {
	return Color.blue;
    }
}

