// Copyright (C) Crawford Currie 2004 - All rights reserved
// It is hereby granted that this software can be used, copied, 
// modified, and distributed without fee provided that this 
// copyright notice appears in all copies.
package com.ccsoft.edit.tags;

import com.ccsoft.edit.FontContext;

import java.awt.*;
import java.util.Enumeration;

/**
 * Base class of DL, UL and OL type lists. It is a vertical list that
 * seeks to align the second column of it's children.
 */
class ColumnarList extends VerticalList {
    protected ColumnarList(XMLTokeniser t) {
	super(t);
    }

    /**
     * Try and make all columns their preferred width, and donate any
     * excess to the last column.
     */
    public TableInfo getTableInfo(int maxWidth, FontContext fc) {
	TableInfo cw = super.getTableInfo(maxWidth, fc);
	int cc = cw.cols, i;
	for (int highest = cc - 1; highest >= 0; highest--) {
	    // See if they all fit at preferred width
	    int prefw = 0;
	    for (i = 0; i < cc; i++)
		prefw += cw.prefWidth[i];
	    
	    if (prefw <= maxWidth) {
		for (i = 0; i < cc; i++) {
		    cw.minWidth[i] = cw.prefWidth[i];
		}
		cw.minWidth[i - 1] += maxWidth - prefw;
		break;
	    }
	    
	    // Preferred widths are too wide. Starting with the last column,
	    // switch to min width and try again.
	    cw.prefWidth[highest] = cw.minWidth[highest];
	}
	return cw;
    }
}
