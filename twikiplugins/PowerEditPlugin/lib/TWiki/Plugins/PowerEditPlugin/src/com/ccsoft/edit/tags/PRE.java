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
 * Preformatted area
 */
class PRE extends FontChange {

    public PRE(XMLTokeniser t) {
	super(t);
	preformatted = true;
    }

    protected String getFaceChange() {
	return "CourierNew";
    }

    public int preferredWidth(FontContext fc) {
	return FULL_PAGE;
    }

    public void parse(XMLTokeniser t) {
	boolean wm = t.isPreformatted;
	t.isPreformatted = preformatted;
	super.parse(t);
	t.isPreformatted = wm;
    }
}
