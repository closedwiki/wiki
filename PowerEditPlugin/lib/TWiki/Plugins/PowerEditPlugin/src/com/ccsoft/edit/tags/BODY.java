// Copyright (C) Crawford Currie 2004 - All rights reserved
// It is hereby granted that this software can be used, copied, 
// modified, and distributed without fee provided that this 
// copyright notice appears in all copies.
package com.ccsoft.edit.tags;

/**
 * The top level page (equivalent to HTML element &lt;BODY>)
 */
public class BODY extends Flow {
    public BODY(XMLTokeniser t) {
	super(t);
	parse(t);
    }
}
