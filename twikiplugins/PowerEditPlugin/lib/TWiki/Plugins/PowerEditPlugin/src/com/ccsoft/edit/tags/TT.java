// Copyright (C) Crawford Currie 2004 - All rights reserved
// It is hereby granted that this software can be used, copied, 
// modified, and distributed without fee provided that this 
// copyright notice appears in all copies.
package com.ccsoft.edit.tags;

import java.awt.*;
import com.ccsoft.edit.FontContext;

/**
 * Code (HTML element &lt;TT>)
 */
class TT extends FontChange {
    public TT(XMLTokeniser t) {
	super(t);
    }

    protected String getFaceChange() {
	return "CourierNew";
    }
}

