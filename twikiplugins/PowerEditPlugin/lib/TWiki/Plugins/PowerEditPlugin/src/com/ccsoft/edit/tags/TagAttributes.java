// Copyright (C) Crawford Currie 2004 - All rights reserved
// It is hereby granted that this software can be used, copied, 
// modified, and distributed without fee provided that this 
// copyright notice appears in all copies.
package com.ccsoft.edit.tags;

import java.awt.Color;

import java.util.Hashtable;
import java.util.Enumeration;

/**
 * Attributes associated with an HTML tag
 */
public class TagAttributes extends Hashtable {
    public static final int LEFT =	0x01;
    public static final int CENTER =	0x02;
    public static final int RIGHT =	0x04;
    public static final int JUSTIFY =	0x08;
    public static final int TOP =	0x10;
    public static final int MIDDLE =	0x20;
    public static final int BOTTOM =	0x30;
    public static final int BASELINE =	0x40;

    private static final Hashtable colormap = new Hashtable();
    private static final Hashtable alignmap = new Hashtable();

    static {
	colormap.put("black", Color.black);
	colormap.put("silver", Color.lightGray);
	colormap.put("gray", Color.gray);
	colormap.put("white", Color.white);
	colormap.put("maroon", new Color(0x800000));
	colormap.put("red", Color.red);
	colormap.put("purple", new Color(0x800080));
	colormap.put("fuchsia", Color.magenta);
	colormap.put("green", new Color(0x008000));
	colormap.put("lime", Color.green);
	colormap.put("olive", new Color(0x808000));
	colormap.put("yellow", Color.yellow);
	colormap.put("navy", new Color(0x000080));
	colormap.put("blue", Color.blue);
	colormap.put("teal", new Color(0x008080));
	colormap.put("aqua", Color.cyan);

	alignmap.put("left", new Integer(LEFT));
	alignmap.put("center", new Integer(CENTER));
	alignmap.put("right", new Integer(RIGHT));
	alignmap.put("justify", new Integer(JUSTIFY));
	alignmap.put("top", new Integer(TOP));
	alignmap.put("middle", new Integer(MIDDLE));
	alignmap.put("bottom", new Integer(BOTTOM));
	alignmap.put("baseline", new Integer(BASELINE));
    }

    public String toString() {
	String s = "";
	Enumeration e = keys();
	while (e.hasMoreElements()) {
	    String name = (String)e.nextElement();
	    String value = (String)get(name);
	    if (name.indexOf("\"") > 0)
		value = "'" + value + "'";
	    else
		value = "\"" + value + "\"";
	    s += " " + name + "=" + value;
	}
	return s;
    }

    public String getString(String key) {
	return (String)get(key);
    }

    /**
     * Get a Number
     */
    public int getNumber(String key, int base) {
	String w = (String)get(key);
	if (w == null)
	    return base;
	try {
	    base = Integer.parseInt(w);
	} catch (NumberFormatException ffe) {
	    // ignore it
	}
	return base;
    }

    /**
     * Get a Length either as a percentage or pixel value
     */
    public int getLength(String key, int base) {
	String w = (String)get(key);
	if (w == null)
	    return base;

	try {
	    if (w.endsWith("%")) {
		int p = Integer.parseInt(w.substring(0, w.length() - 1));
		base = (int)(base * (float)p / 100);
	    } else
		base = Integer.parseInt(w);
	} catch (NumberFormatException ffe) {
	    // ignore it
	}
	return base;
    }

    public int getAlignment(String key, int base) {
	String w = (String)get(key);
	if (w == null)
	    return base;
	Integer i = (Integer)alignmap.get(w);
	if (i == null)
	    return base;
	return i.intValue();
    }

    public Color getColor(String key) {
	Color mapped = null;
	String colors = (String)get(key);
	if (colors != null) {
	    if (colors.charAt(0) == '#') {
		try {
		    int val = Integer.parseInt(colors.substring(1), 16);
		    mapped = new Color(val);
		} catch (NumberFormatException nfe) {
		}
	    } else {
		mapped = (Color)colormap.get(colors.toLowerCase());
	    }
	}
	return mapped;
    }
}
