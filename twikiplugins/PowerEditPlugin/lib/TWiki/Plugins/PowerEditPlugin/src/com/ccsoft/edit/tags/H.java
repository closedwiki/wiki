// Copyright (C) Crawford Currie 2004 - All rights reserved
// It is hereby granted that this software can be used, copied, 
// modified, and distributed without fee provided that this 
// copyright notice appears in all copies.
package com.ccsoft.edit.tags;

import java.awt.Color;
import java.awt.Font;
import com.ccsoft.edit.FontContext;

/**
 * HTML element &lt;Hn>
 * ALIGN=[ left | center | right | justify ] 
 */
class H extends FontChange {
    int level;

    public H(XMLTokeniser t) {
	super(t);
	try {
	    level = Integer.parseInt(t.string.substring(1));
	} catch (NumberFormatException nfe) {
	    level = 6;
	}
    }

    protected int getStyleChange() {
	return Font.BOLD;
    }

    protected int getSizeChange(FontContext fc) {
	// Want an H1 to be size 7, H6 size 2
	return 8 - level;
    }

    public int preferredWidth(FontContext fc) {
	return FULL_PAGE;
    }

    public int minimumWidth(FontContext fc) {
	return FULL_PAGE;
    }
}

