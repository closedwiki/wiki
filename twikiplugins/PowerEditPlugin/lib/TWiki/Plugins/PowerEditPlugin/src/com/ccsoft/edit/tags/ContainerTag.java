// Copyright (C) Crawford Currie 2004 - All rights reserved
// It is hereby granted that this software can be used, copied, 
// modified, and distributed without fee provided that this 
// copyright notice appears in all copies.
package com.ccsoft.edit.tags;

import java.awt.Color;
import java.awt.Font;
import java.awt.Graphics;
import java.awt.Rectangle;

import java.util.Enumeration;
import java.util.Stack;
import java.util.Vector;

import com.ccsoft.edit.Area;
import com.ccsoft.edit.Block;
import com.ccsoft.edit.FontContext;
import com.ccsoft.edit.Word;

/**
 * Abstract base-class of all elements that include sub-elements
 */
abstract class ContainerTag extends TaggedBlock {
    /** containing page */
    public ContainerTag parent;
    protected Vector contents;
    private int[] pref;
    private int[]min;

    /** Indices into column width array */
    protected static final int MIN = 0;
    protected static final int PREF = 1;

    protected ContainerTag(XMLTokeniser t) {
	super(t);
	contents = new Vector();
	parent = null;
    }

    protected ContainerTag getParent() {
	return parent;
    }

    public void add(Block b) {
	if (b instanceof ContainerTag)
	    ((ContainerTag)b).parent = this;
	contents.addElement(b);
    }

    public void add(ContainerTag b) {
	b.parent = this;
	contents.addElement(b);
    }

    public void add(TaggedBlock b, XMLTokeniser t) {
	add(b);
	b.parse(t);
    }

    /** Indented list with no tag */
    public String toHTML(String indent) {
	if (this instanceof TaggedBlock) {
	    return super.toHTML(indent) +
		composeHTML(indent, true) +
		"</" + getTag() + '>';
	} else {
	    return composeHTML(indent, false);
	}
    }

    private String composeHTML(String indent, boolean hasTag) {
	String s = "";
	boolean brokenChild = false;

	Enumeration e = contents.elements();	
	while (e.hasMoreElements()) {
	    Block b = (Block)e.nextElement();
	    if (b instanceof TaggedBlock) {
		String sub = ((TaggedBlock)b).toHTML(indent + " ");
		if (sub.length() > 0) {
		    if (!sub.startsWith("\n"))
			s += indent + " ";
		    brokenChild = true;
		}
		s += sub;
	    } else {
		String sub = b.toString();
		if (sub.length() > 0)
		    s += " " + sub;
	    }
	}
	if (brokenChild && hasTag) {
	    if (!s.startsWith("\n"))
		s = indent + s;
	    s += indent;
	}

	return s;
    }

    public void tag(XMLTokeniser t) {
	if (t.string.equals("a"))		add(new A(t), t);
	else if (t.string.equals("abbr"))	add(new Flow(t), t);
	else if (t.string.equals("acronym"))    add(new Flow(t), t);
	else if (t.string.equals("address"))    add(new Flow(t), t);
	else if (t.string.equals("applet"))	add(new BoxTag(t), t);
	else if (t.string.equals("area"))	add(new IgnoreTag(t), t);
	else if (t.string.equals("b"))		add(new B(t), t);
	else if (t.string.equals("br"))		add(new BR(t), t);
	else if (t.string.equals("base"))	add(new IgnoreTag(t));
	else if (t.string.equals("basefont"))	add(new IgnoreTag(t));
	else if (t.string.equals("bdo"))	add(new Flow(t), t);
	else if (t.string.equals("big"))	add(new BIG(t), t);
	else if (t.string.equals("blockquote"))	add(new I(t), t);
	else if (t.string.equals("br"))		add(new BR(t));
	else if (t.string.equals("button"))	add(new BoxTag(t), t);
	else if (t.string.equals("caption"))	add(new IgnoreTag(t), t);
	else if (t.string.equals("center"))	add(new CENTER(t), t);
	else if (t.string.equals("cite"))	add(new TT(t), t);
	else if (t.string.equals("code"))	add(new TT(t), t);
	else if (t.string.equals("col"))	add(new IgnoreTag(t));
	else if (t.string.equals("colgroup"))	add(new IgnoreTag(t), t);
	else if (t.string.equals("dd"))		add(new DD(t), t);
	else if (t.string.equals("del"))	add(new STRIKE(t), t);
	else if (t.string.equals("dfn"))	add(new Flow(t), t);
	else if (t.string.equals("dir"))	add(new DIR(t), t);
	else if (t.string.equals("div"))	add(new Flow(t), t);
	else if (t.string.equals("dl"))		add(new DL(t), t);
	else if (t.string.equals("dt"))		add(new DT(t), t);
	else if (t.string.equals("em"))		add(new I(t), t);
	else if (t.string.equals("fieldset"))	add(new IgnoreTag(t), t);
	else if (t.string.equals("font"))	add(new FONT(t), t);
	else if (t.string.equals("form"))	add(new BoxTag(t), t);
	else if (t.string.equals("frame"))	add(new IgnoreTag(t));
	else if (t.string.equals("frameset"))	add(new IgnoreTag(t), t);
	else if (t.string.equals("h1") ||
		 t.string.equals("h2") ||
		 t.string.equals("h3") ||
		 t.string.equals("h4") ||
		 t.string.equals("h5") ||
		 t.string.equals("h6"))		add(new H(t), t);
	else if (t.string.equals("head"))	add(new IgnoreTag(t), t);
	else if (t.string.equals("hr"))		add(new HR(t));
	else if (t.string.equals("html"))	add(new IgnoreTag(t), t);
	else if (t.string.equals("i"))		add(new I(t), t);
	else if (t.string.equals("iframe"))	add(new IgnoreTag(t), t);
	else if (t.string.equals("img"))	add(new IMG(t));
	else if (t.string.equals("input"))	add(new BoxTag(t), t);
	else if (t.string.equals("ins"))	add(new I(t), t);
	else if (t.string.equals("isindex"))	add(new IgnoreTag(t));
	else if (t.string.equals("kbd"))	add(new TT(t), t);
	else if (t.string.equals("label"))	add(new IgnoreTag(t), t);
	else if (t.string.equals("legend"))	add(new IgnoreTag(t), t);
	else if (t.string.equals("li"))		add(new IgnoreTag(t), t);
	else if (t.string.equals("link"))	add(new IgnoreTag(t));
	else if (t.string.equals("map"))	add(new IgnoreTag(t), t);
	else if (t.string.equals("menu"))	add(new DIR(t), t);
	else if (t.string.equals("meta"))	add(new IgnoreTag(t));
	else if (t.string.equals("noframes"))	add(new Flow(t), t);
	else if (t.string.equals("noscript"))	add(new Flow(t), t);
	else if (t.string.equals("object"))	add(new BoxTag(t), t);
	else if (t.string.equals("ol"))		add(new OL(t), t);
	else if (t.string.equals("optgroup"))	add(new IgnoreTag(t), t);
	else if (t.string.equals("option"))	add(new IgnoreTag(t), t);
	else if (t.string.equals("p"))		add(new P(t));
	else if (t.string.equals("param"))	add(new IgnoreTag(t));
	else if (t.string.equals("pre"))	add(new PRE(t), t);
	else if (t.string.equals("q"))		add(new I(t), t);
	else if (t.string.equals("s"))		add(new STRIKE(t), t);
	else if (t.string.equals("samp"))	add(new TT(t), t);
	else if (t.string.equals("script"))	add(new IgnoreTag(t), t);
	else if (t.string.equals("select"))	add(new IgnoreTag(t), t);
	else if (t.string.equals("small"))	add(new SMALL(t), t);
	else if (t.string.equals("span"))	add(new Flow(t), t);
	else if (t.string.equals("strike"))	add(new STRIKE(t), t);
	else if (t.string.equals("script"))	add(new IgnoreTag(t), t);
	else if (t.string.equals("strong"))	add(new B(t), t);
	else if (t.string.equals("style"))	add(new IgnoreTag(t), t);
	else if (t.string.equals("sub"))	add(new SUB(t), t);
	else if (t.string.equals("sup"))	add(new SUP(t), t);
	else if (t.string.equals("table"))	add(new TABLE(t), t);
	else if (t.string.equals("tbody"))	add(new IgnoreTag(t), t);
	else if (t.string.equals("td"))		add(new TD(t), t);
	else if (t.string.equals("textarea"))	add(new BoxTag(t), t);
	else if (t.string.equals("tfoot"))	add(new IgnoreTag(t), t);
	else if (t.string.equals("th"))		add(new TH(t), t);
	else if (t.string.equals("thead"))	add(new IgnoreTag(t), t);
	else if (t.string.equals("tr"))		add(new TR(t), t);
	else if (t.string.equals("tt"))		add(new TT(t), t);
	else if (t.string.equals("u"))		add(new U(t), t);
	else if (t.string.equals("ul"))		add(new UL(t), t);
	else if (t.string.equals("var"))	add(new I(t), t);
	else if (!t.string.equals("/p"))
	    contents.addElement(new Word("<" + t.string + t.attrs + ">",
					 t.markerTag));
    }

    public void word(XMLTokeniser t) {
	contents.addElement(new Word(t));
    }

    public void paint(Graphics g, int ox, int oy, FontContext fc) {
	if (!paintable(g, ox, oy))
	    return;
	ox += x;
	oy += y;
	//g.setColor(Color.red);
	//g.drawRect(ox, oy, width, height);
	Enumeration e = contents.elements();
	while (e.hasMoreElements()) {
	    Block l = (Block)e.nextElement();
	    l.paint(g, ox, oy, fc);
	}
    }

    public int hitTest(int hx, int hy, int ox, int oy, FontContext fc) {
	ox += x;
	oy += y;
	if (hx < ox || hx > ox + width ||
	    hy < oy || hy > oy + height)
	    return -1;
	Enumeration e = contents.elements();
	while (e.hasMoreElements()) {
	    Block l = (Block)e.nextElement();
	    int ht = l.hitTest(hx, hy, ox, oy, fc);
	    if (ht >= 0)
		return ht;
	}
	return -1;
    }
}
