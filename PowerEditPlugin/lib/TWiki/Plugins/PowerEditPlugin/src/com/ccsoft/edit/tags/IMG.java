// Copyright (C) Crawford Currie 2004 - All rights reserved
// It is hereby granted that this software can be used, copied, 
// modified, and distributed without fee provided that this 
// copyright notice appears in all copies.
package com.ccsoft.edit.tags;

import java.awt.Color;
import java.awt.Graphics;
import com.ccsoft.edit.*;

/**
 * HTML Element &lt;IMG>
 */
class IMG extends BoxTag {
    String text;

    public IMG(XMLTokeniser t) {
	super(t);
	text = (String)getAttributes().get("alt");
	if (text == null)
	    text = (String)getAttributes().get("src");
	if (text == null)
	    text = getTag();
    }
}
