// Copyright (C) Crawford Currie 2004 - All rights reserved
// It is hereby granted that this software can be used, copied, 
// modified, and distributed without fee provided that this 
// copyright notice appears in all copies.
package com.ccsoft.edit.tags;

import java.awt.Color;
import java.awt.Font;
import com.ccsoft.edit.FontContext;

/**
 * HTML Element &lt;BIG>
 */
class BIG extends FontChange {
    public BIG(XMLTokeniser t) {
	super(t);
    }

    protected int getSizeChange(FontContext fc) {
	return fc.fontSize() + 1;
    }
}

