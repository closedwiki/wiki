// It is hereby granted that this software can be used, copied, 
// modified, and distributed without fee provided that this 
// copyright notice appears in all copies.
package com.ccsoft.edit;

import java.awt.*;
import java.util.Stack;

/**
 * Interface to font metrics information from components or graphics.
 */
public class FontContext {

    /** decorator style bits, must avoid Font.BOLD and Font.ITALIC */
    public static final int UNDERLINE = 0x10;
    public static final int STRIKETHROUGH = 0x20;
    
    private class FontData {
	private Font font;
	public String name;
	public int size;
	public Color color;
	public int style;
	

	FontData(String n, int sz, Color c, int fs) {
	    font = null;
	    color = c;
	    style = fs;
	    size = sz;
	    name = n;
	}

	public String toString() {
	    return name + ":" +
		size + ":" +
		Integer.toHexString(style) + ":" + color;
	}

	public Font getFont() {
	    if (font == null) {
		// A size 0 font is 2 pt
		// 1 8
		// 2 10
		// 3 12
		// 4 14
		// 5 16
		font = new Font(name, 
				style & (Font.BOLD | Font.ITALIC),
				6 + 2 * size);
	    }
	    return font;
	}

	public boolean equals(Object o) {
	    if (this == o)
		return true;
	    if (!(o instanceof FontData))
		return false;
	    FontData f = (FontData)o;
	    return size == f.size &&
		style == f.style &&
		color.equals(f.color) &&
		name.equals(f.name);
	}
    }

    /** stack of FontData */
    private Stack stack;
    /** component for getting font metrics */
    private Component comp;

    FontContext(Component c) {
	comp = c;
	stack = new Stack();
	stack.push(new FontData("Dialog",
				3,
				Color.black,
				Font.PLAIN));
    }

    private FontMetrics getFontMetrics() {
	return comp.getFontMetrics(font());
    }

    /**
     * @param size -1 means no change, otherwise size in virtual units
     * @param style -1 means no change
     */
    public void pushFont(String name, int style, int size, Color color) {
	FontData curr = (FontData)stack.peek();

	if (name == null)
	    name = curr.name;

	if (style == -1)
	    style = curr.style;
	else
	    style |= curr.style;

	if (size == -1)
	    size = curr.size;

	if (color == null)
	    color = curr.color;

	stack.push(new FontData(name, size, color, style));
    }

    public void popFont() {
	if (!stack.isEmpty())
	    stack.pop();
    }

    public int stringWidth(String s) {
	return getFontMetrics().stringWidth(s);
    }

    public int spaceWidth() {
	return getFontMetrics().charWidth(' ');
    }

    public Font font() {
	return ((FontData)stack.peek()).getFont();
    }

    public int fontAscent() {
	return getFontMetrics().getAscent();
    }

    public int fontHeight() {
	return getFontMetrics().getHeight();
    }

    /** Font size in virtual units */
    public int fontSize() {
	return ((FontData)stack.peek()).size;
    }

    public Color fontColor() {
	return ((FontData)stack.peek()).color;
    }

    public int fontStyle() {
	return ((FontData)stack.peek()).style;
    }
}
