// Copyright (C) Crawford Currie 2004 - All rights reserved
// It is hereby granted that this software can be used, copied, 
// modified, and distributed without fee provided that this 
// copyright notice appears in all copies.
package com.ccsoft.edit;

import java.awt.*;
import java.util.Enumeration;
import java.util.Stack;
import java.util.Vector;

/**
 * Base class of all on-screen entities
 */
public abstract class Block extends Rectangle {
    /** Constant representing full page width */
    public static final int FULL_PAGE = 100000;
    public int x, y, width, height;

    protected Block() {
        x = y = width = height = -1;
    }

    public abstract int minimumWidth(FontContext fc);

    public int preferredWidth(FontContext fc) {
        return minimumWidth(fc);
    }

    public abstract int minimumHeight(FontContext fc);

    public int preferredHeight(FontContext fc) {
        return minimumHeight(fc);
    }

    /** The ascent of the top line of the block */
    public abstract int ascent(FontContext fc);

    public abstract void layout(Area area, FontContext fonts);
    public abstract void paint(Graphics g, int ox, int oy, FontContext fonts);

    protected boolean paintable(Graphics g, int ox, int oy) {
        Rectangle me = new Rectangle(ox + x, oy + y, width, height);
        return me.intersects(g.getClipBounds());
    }

    protected String layoutInfo() {
        return "<!-- x=" + x + " y=" + y + " width=" + width +
            " height=" + height + " -->";
    }
}

