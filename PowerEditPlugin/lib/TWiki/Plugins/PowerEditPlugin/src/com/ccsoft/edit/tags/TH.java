// Copyright (C) 2004 Crawford Currie - All rights reserved
// It is hereby granted that this software can be used, copied, 
// modified, and distributed without fee provided that this 
// copyright notice appears in all copies.
package com.ccsoft.edit.tags;

import java.awt.Graphics;
import java.awt.Color;
import com.ccsoft.edit.FontContext;

/**
 * A table column heading (HTML element &lt;TH>)
 * Needs to paint with a coloured background
 */
public class TH extends TD {
    public TH(XMLTokeniser t) {
	super(t);
    }
}
