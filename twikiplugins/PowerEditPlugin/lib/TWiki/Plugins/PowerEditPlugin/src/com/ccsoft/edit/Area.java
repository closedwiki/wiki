// Copyright (C) Crawford Currie 2004 - All rights reserved
// It is hereby granted that this software can be used, copied, 
// modified, and distributed without fee provided that this 
// copyright notice appears in all copies.
package com.ccsoft.edit;

/**
 * Object used during layout to pass layout information down through
 * the element hierarchy.
 */
public class Area {
    /** Top left of this area, relative to the parent */
    public int x, y;
    /** Maximum permitted width allowed by this area */
    public int maxWidth;
    /** Ascent required for lines of text */
    public int ascent;

    public Area(int x, int y, int mw, int a) {
        this.x = x;
        this.y = y;
        this.maxWidth = mw;
        this.ascent = a;
    }

    public String toString() {
        return "[" + x + "," + y + "," + maxWidth + "," + ascent + "]";
    }
}
