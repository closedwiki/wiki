// Copyright (C) Crawford Currie 2001 - All rights reserved
// It is hereby granted that this software can be used, copied, 
// modified, and distributed without fee provided that this 
// copyright notice appears in all copies.
package com.ccsoft.edit;

import gnu.regexp.*;

import java.awt.*;
import java.awt.event.*;
import java.awt.datatransfer.*;
import java.lang.reflect.*;

/**
 * Extends textArea to add common editing operations such as cut, copy,
 * paste, find, replace and undo. Uses the GNU regexp package to provide
 * regular expression support a la emacs.<p>
 * This is MUCH lighter weight than using the equivalent 'lightweight'
 * JComponent! What's more, it's entirely JDK1.1 so it can be used with
 * Netscape Java 1.1.5
 */
public class SearchableTextArea
extends TextArea
implements Difference.ModifiableText {

    private static final int UNDO_DEPTH = 100;
    private static final RESyntax syntax = RESyntax.RE_SYNTAX_EMACS;

    String searchString, replaceString, clipboard;
    boolean caseSensitive, reSearch;

    private transient String prevText;
    private transient UndoBuffer undoBuffer;
    private transient Application application;
    private transient boolean recordUndo;
    private transient String repeatCommand;

    /**
     * Create a new searchable text area. The area must be reset
     * before it is usable.
     */
    SearchableTextArea() {
	super("", 10, 10, TextArea.SCROLLBARS_VERTICAL_ONLY);

	/* Init per-invocation features */
        recordUndo = false;
	undoBuffer = new UndoBuffer(UNDO_DEPTH);
	prevText = "";
	repeatCommand = null;
	/** Init persistant features */
        caseSensitive = true;
        reSearch = false;
        try {
            Clipboard cb = Toolkit.getDefaultToolkit().getSystemClipboard();
        } catch (Exception se) {
            System.out.println("System clipboard inaccessible");
        }
        clipboard = "";
        searchString = "";
        replaceString = "";
	addTextListener(new TextListener() {
		public void textValueChanged(TextEvent t) {
		    String text = getText();
		    if (recordUndo && !text.equals(prevText)) {
			Difference diff = new Difference(prevText, text);
			//System.out.println(diff);
			undoBuffer.push(diff);
		    } else
			recordUndo = true;
		    prevText = text;
		}
	    });
	// enable event processing by processKeyEvent
	enableEvents(AWTEvent.KEY_EVENT_MASK);
    }

    /**
     * Constructor
     */
    SearchableTextArea(Application app, String text, int r, int c) {
        reset(app, text, r, c);
    }

    /**
     * Override so this behaves more like a properly resizable
     * component when used in a layout manager.
     */
    public Dimension getMinimumSize() {
        return new Dimension(100,100);
    }

    /**
     * Resets the text area. The following features are persistant
     * and are not rest between invocations:
     * <ul><li>the search string
     * <li>case insensitivity
     * <li>regular expression matching
     * <li>the clipboard
     * </ul>
     */
    public void reset(Application app, String text, int r, int c) {
	application = app;
	setRows(r);
	setColumns(c);
	prevText = text;
	setText(text);
	undoBuffer.reset();
        //setCaretPosition(0);
	recordUndo = true;
    }

    /**
     * Beep on error or warning.
     */
    public void beep() {
        Toolkit.getDefaultToolkit().beep();
    }

    /**
     * Replay a macro command. Editor commands are delineated by % signs.
     */
    public void replayMacro(String macro) {
        //System.out.println("Replay <" + macro + "> over " + getSelectedText());
        int idx = 0;
	int ml = macro.length();
        while (idx < ml) {
            int cmdstart = macro.indexOf('%', idx);
            if (cmdstart < 0) {
                overwriteSelection(macro.substring(idx));
                break;
            } else if (macro.charAt(cmdstart + 1) == '%') {
                overwriteSelection("%");
                idx = cmdstart + 2;
            } else {
                int cmdend = macro.indexOf('%', cmdstart + 1);
                if (cmdend < 0) {
                    overwriteSelection(macro.substring(idx));
                    break;
                }
                String cmd = macro.substring(cmdstart + 1, cmdend);
                if (cmdstart > idx)
                    overwriteSelection(macro.substring(idx, cmdstart));
                doCommand(cmd);
                idx = cmdend + 1;
            }
        }
    }

    /**
     * Execute a command that applies to the text area.
     */
    private void doCommand(String command) {
	try {
	    Method m = getClass().getMethod(command, null);
	    m.invoke(this, null);
	} catch (NoSuchMethodException nsme) {
	    application.doCommand(command);
	} catch (Exception e) {
	    throw new RuntimeException(e.getMessage());
	}
    }
    
    /**
     * Process a key event. Certain key events are intercepted and
     * interpreted as command invocations:
     * <table cols=2>
     * <tr><td>Ctrl+C</td><td>Copy</td></tr>
     * <tr><td>Ctrl+F</td><td>Find</td></tr>
     * <tr><td>Ctrl+N</td><td>Repeat last command</td></tr>
     * <tr><td>Ctrl+R</td><td>Replace</td></tr>
     * <tr><td>Ctrl+V</td><td>Paste</td></tr>
     * <tr><td>Ctrl+X</td><td>Cut</td></tr>
     * <tr><td>Ctrl+Y</td><td>Undo</td></tr>
     * </table>
     * All other key strokes are passed on to the TextArea for
     * conventional processing.
     */
    protected void processKeyEvent(KeyEvent k) {
	int kc = k.getKeyChar();
        if (kc < ' ') {
            //System.out.println("prcoessKeyEvent Keycode " + k.getKeyCode() + " " + kc);
            String command = null;
            switch (kc) {
            case 3:		// Ctrl+C
                command = "copy"; break;
            case 6:             // Ctrl+F
                command = "find"; break;
            case 14:            // Ctrl+N
                command = "redo"; break;
            case 18:	        // Ctrl+R
                command = "replace"; break;
            case 22:	        // Ctrl+V
                command = "paste"; break;
            case 24:	        // Ctrl+X
                command = "cut"; break;
            case 25:	        // Ctrl+Y
                command = "undo"; break;
            }
            if (command != null) {
                // consume all events associated with command keys. Otherwise
                // over-enthusiastic Netscape will insert characters for them.
                k.consume();
                if (k.getID() == KeyEvent.KEY_PRESSED)
                    doCommand(command);
                return;
            }
        }
	super.processKeyEvent(k);
    }

    /**
     * Implement Difference.ModifiableText to replace the text between
     * start and end.
     * @param rep the new text
     * @param start start of the span to replace
     * @param end end of the span to replace
     */
    public void replace(String rep, int start, int end) {
	recordUndo = false;
	replaceRange(rep, start, end);
    }

    private void setSelection(int s, int e) {
        select(s, e);
        setCaretPosition(e);
    }

    private void setSelection(int s) {
        setSelection(s, s);
    }

    private boolean haveSelection() {
        return getSelectionEnd() > getSelectionStart();
    }

    /**
     * Insert the text, overwriting any current selection
     */
    public void overwriteSelection(String ins) {
        int s;
	if (haveSelection()) {
            s = getSelectionStart();
	    replaceRange(ins, s, getSelectionEnd());
	} else {
            s = getCaretPosition();
	    insert(ins, s);
        }
        int e = s + ins.length();
        setSelection(e, e);
    }

    /**
     * COMMAND
     * Repeat the last command. If the last command is not
     * repeatable, beep.
     */
    public void redo() {
	if (repeatCommand != null) {
	    //System.out.println("Repeating " + repeatCommand);
	    doCommand(repeatCommand);
	} else
            beep();
    }

    /**
     * COMMAND
     * Undo the last command. If the last command is not undoable, beep.
     */
    public void undo() {
        //System.out.println("Undo");
	if (undoBuffer.hasUndo()) {
	    setCaretPosition(undoBuffer.undo(this));
	} else
	    beep();
	repeatCommand = "undo";
    }

    /**
     * COMMAND
     * Cut the selected text.
     */
    public void cut() {
	copy();
        //System.out.println("Delete " + getSelectedText());
	overwriteSelection("");
	repeatCommand = null;
    }

    /**
     * COMMAND
     * Copy the selected text
     */
    public void copy() {
        //System.out.println("Copy " + getSelectedText());
	clipboard = getSelectedText();
	repeatCommand = null;
    }

    /**
     * COMMAND
     * Paste the cut buffer, replacing the selected text
     */
    public void paste() {
        //System.out.println("Paste " + clipboard);
        overwriteSelection(clipboard);
	repeatCommand = "paste";
    }

    /**
     * COMMAND
     * Move to the start of the current line
     */
    public void home() {
        //System.out.println("Home");
        if (getCaretPosition() == 0)
            return;
        int s = getLineStart(getCaretPosition());
        setSelection(s);
    }

    /**
     * COMMAND
     * Move to the end of the current line
     */
    public void end() {
        //System.out.println("End");
        int e = getText().indexOf('\n', getCaretPosition());
        if (e < 0)
            e = getText().length();
        setSelection(e);
    }

    private int getLineStart(int pos) {
        String searchSpace = getText().substring(0, pos);
        return searchSpace.lastIndexOf('\n') + 1;
    }

    /**
     * COMMAND
     * Move left one character
     */
    public void left() {
        //System.out.println("Left");
        int cp = getCaretPosition();
        if (cp > 0)
            setSelection(cp - 1);
    }

    /**
     * COMMAND
     * Move right one character
     */
    public void right() {
        //System.out.println("Right");
        int cp = getCaretPosition();
        setSelection(cp + 1);
    }

    /**
     * COMMAND
     * Do nothing (used to delimit macros)
     */
    public void delimit() {
    }

    /**
     * COMMAND
     * Invoke the find dialog
     */
    public void find() {
        //System.out.println("Find");
	if (!reSearch && getSelectionStart() < getSelectionEnd())
	    searchString = getSelectedText();
	FindDialog dlg = new FindDialog(
	    application.getFrame(), searchString, caseSensitive, reSearch);
	dlg.show();
	if (dlg.oked) {
	    caseSensitive = dlg.getCaseSensitivity();
            reSearch = dlg.getRESearch();
	    searchString = dlg.getFindString();
	    refind();
	}
	repeatCommand = "refind";
    }

    /**
     * COMMAND
     * Repeat the last find from the caret position
     */
    public boolean refind() {
        //System.out.println("FindAgain");
	int curPos = getCaretPosition();
	int newPos = -1, matchedLen = 0;
        if (!reSearch) {
            if (caseSensitive)
                newPos = getText().indexOf(searchString, curPos);
            else
                newPos = getText().toLowerCase().indexOf(
                    searchString.toLowerCase(), curPos);
            matchedLen = searchString.length();
        } else {
            try {
                RE re = new RE(searchString,
                               RE.REG_MULTILINE |
                               (caseSensitive ? 0 : RE.REG_ICASE),
                               syntax);
                //REMatchEnumeration matches =
                //    re.getMatchEnumeration(getText(), curPos);
                //while (matches.hasMoreMatches()) {
                //    REMatch m = matches.nextMatch();
                //    System.out.println("Match " + m);
                //}
                //System.out.println("No more matches");
                REMatch match = re.getMatch(getText(), curPos);
                if (match == null)
                    newPos = -1;
                else {
                    newPos = match.getStartIndex();
                    matchedLen = match.getEndIndex() - newPos;
                }
            } catch (REException ree) {
                ree.printStackTrace();
                System.out.println(ree.getMessage());
            }
        }
	if (newPos != -1 && matchedLen > 0) {
	    setSelection(newPos, newPos + matchedLen);
	    return true;
	} else {
	    beep();
	    return false;
	}
    }

    /**
     * COMMAND
     * Invoke the replace dialog
     */
    public void replace() {
        //System.out.println("Replace");
	if (!reSearch && getSelectionStart() < getSelectionEnd())
	    searchString = getSelectedText();
	ReplaceDialog dlg = new ReplaceDialog(
	    application.getFrame(),
	    searchString, replaceString, caseSensitive, reSearch);
	dlg.show();
	if (dlg.oked) {
	    caseSensitive = dlg.getCaseSensitivity();
	    searchString = dlg.getFindString();
	    replaceString = dlg.getReplaceString();
	    if (!getSelectedText().equals(searchString))
		if (!refind()) {
		    beep();
		    return;
		}
	    overwriteSelection(replaceString);
	}
	repeatCommand = "rereplace";
    }

    /**
     * COMMAND
     * Repeat the last replacement. Note that replacement does not
     * currently support field extraction.
     */
    public boolean rereplace() {
        //System.out.println("ReplaceAgain");
	if (refind()) {
	    overwriteSelection(replaceString);
	    return true;
	}
	return false;
    }
}

