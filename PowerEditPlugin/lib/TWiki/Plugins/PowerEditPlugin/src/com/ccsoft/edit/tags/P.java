// Copyright (C) Crawford Currie 2004 - All rights reserved
// It is hereby granted that this software can be used, copied, 
// modified, and distributed without fee provided that this 
// copyright notice appears in all copies.
package com.ccsoft.edit.tags;

import com.ccsoft.edit.FontContext;

/**
 * HTML element &lt;P>
 * ALIGN=[ left | center | right | justify ]
 */
class P extends BR {
    public P(XMLTokeniser t) {
	super(t);
    }

    public int minimumHeight(FontContext fc) {
	return fc.fontHeight();
    }
}
