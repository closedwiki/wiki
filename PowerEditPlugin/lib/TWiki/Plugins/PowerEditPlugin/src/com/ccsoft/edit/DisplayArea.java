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
import com.ccsoft.edit.tags.EntityExpandingReader;
import com.ccsoft.edit.tags.XMLTokeniser;
import uk.co.cdot.SuperString;

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
class DisplayArea extends Canvas implements TextListener, MouseListener {
    /** Partner textarea */
    private TextComponent textArea;
    /** Block structure of the page */
    private BODY page;
    /** Thread used to ensure parsing doesn't prevent editing */
    private Thread parseThread = null;

    public static final int FORCE_EXIT = 1;
    public static final int HTML_ONLY  = 2;
    private int options;

    DisplayArea(int opts) {
	setBackground(Color.lightGray);
	page = null;
	addMouseListener(this);
	options = opts;
    }

    interface ProcessListener {
	void setText(String text);
    }
    private ProcessListener processListener = null;
    public void addProcessListener(ProcessListener ear) {
	processListener = ear;
    }

    private Thread tmlParseThread = null;

    private class ParseThread extends Thread {
	private SuperString text;
	private boolean isTML;
	private TextArea intermediate;

	ParseThread(String t, boolean htmlOnly) {
	    setDaemon(true);
	    text = new SuperString(t);
	    isTML = !htmlOnly;
	}

	public void run() {
	    try {
		if (isTML) {
		    //System.out.println("TML->HTML....");
		    text = TMLParser.toHTML(text);
		    if (processListener != null)
			processListener.setText(text.toString());
		}
		if (Thread.currentThread().interrupted())
		    return;
		//System.out.println("Parse HTML....");
		XMLTokeniser htmlt = new XMLTokeniser(
		    new EntityExpandingReader(text.reader()),
		    text.length());
		BODY page = new BODY(htmlt);
		if (Thread.currentThread().interrupted())
		    return;
		//System.out.println("Layout....");
		setPage(page);
		if (processListener != null)
		    processListener.setText(page.toString());
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
     * @param html if true, will not preprocess text through
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
	parseThread = new ParseThread(text, (options & HTML_ONLY) != 0);
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
	    int pos = p.getVAdjustable().getValue();
	    setSize(ps.width, page.height + 100);
	    p.getVAdjustable().setValue(pos);
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
	if ((options & FORCE_EXIT) != 0) {
	    Component p = this;
	    while (!(p instanceof Frame))
		p = p.getParent();
	    ((Frame)p).dispose();
	}
    }

    public void mouseClicked(MouseEvent me) {
	if (page != null) {
	    int ht = page.hitTest(me.getX(), me.getY(), 0, 0, new FontContext(this));
	    System.out.println("Line " + ht);
	}
    }
    public void mousePressed(MouseEvent me) {
    }
    public void mouseReleased(MouseEvent me) {
    }
    public void mouseEntered(MouseEvent me) {
    }
    public void mouseExited(MouseEvent me) {
    }
}
