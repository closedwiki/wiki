// Copyright (C) Crawford Currie 2004 - All rights reserved
// It is hereby granted that this software can be used, copied, 
// modified, and distributed without fee provided that this 
// copyright notice appears in all copies.
package com.ccsoft.edit.tags;

/**
 * HTML element &lt;OL>
 */
class CENTER extends Flow {
    public CENTER(XMLTokeniser t) {
	super(t);
	setAlignment("center");
    }
}
