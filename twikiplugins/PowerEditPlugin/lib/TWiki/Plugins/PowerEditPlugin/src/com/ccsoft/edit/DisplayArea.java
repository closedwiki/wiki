// Copyright (C) Crawford Currie 2004 - All rights reserved
// It is hereby granted that this software can be used, copied, 
// modified, and distributed without fee provided that this 
// copyright notice appears in all copies.
package com.ccsoft.edit;

import java.awt.*;
import java.awt.event.*;
import java.io.*;
import java.util.Stack;
import java.util.Vector;
import com.ccsoft.edit.tags.BODY;
import com.ccsoft.edit.tags.XMLTokeniser;

/**
 * Display area that partners a TextComponent to display the contained
 * text as it would appear in a browser after interpretation of embedded
 * TWiki Markup Language (TML).
 * <p>
 * There are three stages of processing; first, when the text is changed,
 * it is converted to HTML markup. Second, when the canvas area changes
 * (or the text changes) the virtual markup is parsed to generate a block
 * structure. Third, the block structure is painted on demand.
 */
class DisplayArea extends Canvas implements TextListener {
    /** Partner textarea */
    TextComponent textArea;
    /** Block structure of the page */
    BODY page;
    /** Thread used to ensure parsing doesn't prevent editing */
    Thread parseThread = null;

    public static boolean forcedExit = false;
    public static boolean tml_default = true;;


    DisplayArea() {
	setBackground(Color.lightGray);
	page = null;
    }

    private Thread tmlParseThread = null;

    private class ParseThread extends Thread {
	private String text;
	private boolean isTML;

	ParseThread(String t, boolean tml) {
	    setDaemon(true);
	    text = t;
	    isTML = tml;
	}

	public void run() {
	    try {
		if (isTML) {
		    //System.out.println("TML->HTML....");
		    text = TMLParser.toHTML(text);
		}
		if (Thread.currentThread().interrupted())
		    return;
		//System.out.println("Parse HTML....");
		Reader reader = new StringReader(text);
		XMLTokeniser htmlt = new XMLTokeniser(reader, text.length());
		BODY page = new BODY(htmlt);
		if (Thread.currentThread().interrupted())
		    return;
		//System.out.println("Layout....");
		setPage(page);
	    } catch (Interruption ie) {
	    } catch (IOException ioe) {
		throw new Error("ASSERT");
	    }
	}
    }

    private synchronized void setPage(BODY p) {
	parseThread = null;
	page = p;
	invalidate();
	repaint();
	//System.out.println(page);
    }

    public Block getPage() {
	return page;
    }

    /**
     * Set the text in the text area to be the given TML text
     * @param tml if false, will not preprocess text through
     * the TML parser but assume it is HTML. Used for testing.
     */
    public void setText(String text) {
	if (parseThread != null) {
	    parseThread.interrupt();
	    try {
		parseThread.join();
	    } catch (InterruptedException ie) {
		// this thread was interrupted
		return;
	    }
	}
	// will invoke setPage when it's finished
	parseThread = new ParseThread(text, tml_default);
	parseThread.start();
    }

    /** Implementation of TextListener, called when text in text area
     * has changed. */
    public void textValueChanged(TextEvent te) {
	TextComponent textArea = (TextComponent)te.getSource();
	setText(textArea.getText());
    }

    /**
     * Called when the container is resized and we have to recalculate
     * the display area.
     */
    public void areaChanged() {
	ScrollPane p = (ScrollPane)getParent();
	Dimension ps = p.getSize();
	int width = ps.width - p.getVScrollbarWidth() - 4;
	if (page != null) {
	    setSize(ps.width, page.height + 100);
	    invalidate();
	}
    }

    /**
     * Called when the block structure has been invalidated by a
     * canvas area change or a text change.
     */
    public void doLayout() {
	if (page == null)
	    return;

	ScrollPane p = (ScrollPane)getParent();
	p.getVAdjustable().setUnitIncrement(getFontMetrics(getFont()).getHeight());
	Dimension ps = p.getSize();
	Area a = new Area(0, 0, ps.width - p.getVScrollbarWidth() - 4, 0);
	page.layout(a, new FontContext(this));
	ps = getSize();
	if (page.height != ps.height)
	    areaChanged();
    }

    public void validate() {
	if (!isValid()) {
	    super.validate();
	    doLayout();
	}
    }

    public void paint(Graphics g) {
	if (page == null)
	    return;
	validate();
	page.paint(g, 0, 0, new FontContext(this));
	if (forcedExit) {
	    Component p = this;
	    while (!(p instanceof Frame))
		p = p.getParent();
	    ((Frame)p).dispose();
	}
    }
}
