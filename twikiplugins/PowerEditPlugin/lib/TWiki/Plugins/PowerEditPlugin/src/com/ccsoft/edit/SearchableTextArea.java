// Copyright (C) Crawford Currie 2001 - All rights reserved
// It is hereby granted that this software can be used, copied, 
// modified, and distributed without fee provided that this 
// copyright notice appears in all copies.
package com.ccsoft.edit;

import com.kizna.html.*;

import gnu.regexp.*;

import java.awt.*;
import java.awt.event.*;
import java.awt.datatransfer.*;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.util.Hashtable;
import java.util.Vector;

/**
 * Extends textArea to add common editing operations such as cut, copy,
 * paste, find, replace and undo. Uses the GNU regexp package to provide
 * regular expression support a la emacs.<p>
 * This is MUCH lighter weight than using the equivalent 'lightweight'
 * JComponent! What's more, it's entirely JDK1.1 so it can be used with
 * Netscape Java 1.1.5.
 * It also has hoopy HTML->TML conversion.
 */
public class SearchableTextArea extends TextArea
implements Difference.ModifiableText {

    private static final int UNDO_DEPTH = 100;
    private static final RESyntax syntax = RESyntax.RE_SYNTAX_EMACS;
    /** macro command delimiter */
    private static final char DELIMITER = '/';

    String searchString, replaceString, clipboard;
    boolean caseSensitive, reSearch;

    private transient String prevText;
    private transient UndoBuffer undoBuffer;
    private transient Application application;
    private transient boolean recordUndo;
    private transient String repeatCommand;
    private Controls controls;
    private HTML2TWiki html2wiki = null;
    private Hashtable commandSet;

    /**
     * Create a new searchable text area. The area must be reset
     * before it is usable.
     */
    SearchableTextArea(Controls controls) {
	super("", 10, 10, TextArea.SCROLLBARS_VERTICAL_ONLY);

	// Make a hashtable of known macro methods. Do this rather
	// than catching a NoSuchMethod exception to dodge the
	// overhead of the exception.
	commandSet = new Hashtable();
	Class clzz = getClass();
	Method[] ms = clzz.getMethods();
	for (int i = 0; i < ms.length; i++) {
	    Method m = ms[i];
	    if (m.getName().startsWith("BUILTIN_"))
		commandSet.put(m.getName(), m);
	}

	this.controls = controls;
	/// Init per-invocation features
        recordUndo = false;
	undoBuffer = new UndoBuffer(UNDO_DEPTH);
	prevText = "";
	repeatCommand = null;
	/// Init persistant features
        caseSensitive = true;
        reSearch = false;
        try {
            Clipboard cb = Toolkit.getDefaultToolkit().getSystemClipboard();
        } catch (Exception se) {
            System.err.println("System clipboard inaccessible");
        }
        clipboard = "";
        searchString = "";
        replaceString = "";

	// Text listener to detect changes and record for undo
	addTextListener(new TextListener() {
		public void textValueChanged(TextEvent t) {
		    String text = getText();
		    if (recordUndo && !text.equals(prevText)) {
			Difference diff = new Difference(prevText, text);
			undoBuffer.push(diff);
		    } else
			recordUndo = true;
		    prevText = text;
		}
	    });

	// NOTE: cannot use key listeners because the event gets
	// delivered to the text area whether we want it to or
	// not. Instead, enable event processing by processKeyEvent
	enableEvents(AWTEvent.KEY_EVENT_MASK);
    }

    protected void processKeyEvent(KeyEvent k) {
	if (k.getID() == KeyEvent.KEY_PRESSED) {
	    String command = getKeyCommand(k);
	    if (command != null) {
		// consume all events associated with command keys. Otherwise
		// default event handling will insert characters for them.
		k.consume();
		replayMacro(command);
		return;
	    }
	}

	super.processKeyEvent(k);
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
     * Has the textarea been modified? If it has, the undo buffer will
     * contain something.
     */
    public boolean isModified() {
	return undoBuffer.hasUndo();
    }

    /** Implements Application to look up keystrokes */
    private String getKeyCommand(KeyEvent ke) {
	ControlBlock kb = controls.getBlock("keys");
	if (kb == null)
	    return null;
	char kc = ke.getKeyChar();
	if (kc == 0)
	    return null;
	String ks = "";
	if ((ke.getModifiers() & KeyEvent.CTRL_MASK) != 0) {
	    if (kc < ' ')
		ks = "^" + (char)(kc + 'A' - 1);
	    else
		ks = "^" + kc;
	} else if (kc <= '~') {
	    ks = "" + kc;
	} else if ((ke.getModifiers() & KeyEvent.ALT_MASK) != 0) {
	    ks = "$" + kc;
	} else
	    return null;
	ControlDefinition cd = kb.getDefinition(ks);
	if (cd == null)
	    return null;

	return cd.getValue();
    }

    /**
     * Replay a macro command. Editor commands are delineated by / signs.
     */
    public void replayMacro(String macro) {
        int idx = 0;
	int ml = macro.length();
        while (idx < ml) {
            int cmdstart = macro.indexOf(DELIMITER, idx);
            if (cmdstart < 0) {
                overwriteSelection(macro.substring(idx));
                break;
            } else if (macro.charAt(cmdstart + 1) == DELIMITER) {
                overwriteSelection("" + DELIMITER);
                idx = cmdstart + 2;
            } else {
                int cmdend = macro.indexOf(DELIMITER, cmdstart + 1);
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
	if (controls != null) {
	    ControlBlock mb = controls.getBlock("macros");
	    if (mb != null) {
		ControlDefinition cd = mb.getDefinition(command);
		if (cd != null) {
		    String macro = cd.getValue();
		    replayMacro(macro);
		    return;
		}
	    }
	}
	Method m = (Method)commandSet.get("BUILTIN_" + command);
	if (m != null) {
	    try {
		m.invoke(this, null);
	    } catch (InvocationTargetException ee) {
		System.err.println(ee.getMessage());
		Throwable se = ee.getTargetException();
		se.printStackTrace();
		throw new Error(se.getMessage());
	    } catch (Exception e) {
		e.printStackTrace();
		throw new Error(e.getMessage());
	    }
	} else {
	    application.showStatus("No such macro: /" + command + "/");
	    Toolkit.getDefaultToolkit().beep();
	}
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
     * Beep on error or warning.
     */
    public void beep() {
        Toolkit.getDefaultToolkit().beep();
    }

    /**
     * COMMAND
     * Repeat the last command. If the last command is not
     * repeatable, beep.
     */
    public void BUILTIN_redo() {
	if (repeatCommand != null) {
	    doCommand(repeatCommand);
	} else
            beep();
    }

    /**
     * COMMAND
     * Undo the last command. If the last command is not undoable, beep.
     */
    public void BUILTIN_undo() {
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
    public void BUILTIN_cut() {
	BUILTIN_copy();
	overwriteSelection("");
	repeatCommand = null;
    }

    /**
     * COMMAND
     * Copy the selected text
     */
    public void BUILTIN_copy() {
	clipboard = getSelectedText();
	repeatCommand = null;
    }

    /**
     * COMMAND
     * Paste the cut buffer, replacing the selected text
     */
    public void BUILTIN_paste() {
        overwriteSelection(clipboard);
	repeatCommand = "paste";
    }

    /**
     * COMMAND
     * Move to the start of the current line
     */
    public void BUILTIN_home() {
        if (getCaretPosition() == 0)
            return;
        int s = getLineStart(getCaretPosition());
        setSelection(s);
    }

    /**
     * COMMAND
     * Move to the end of the current line
     */
    public void BUILTIN_end() {
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
    public void BUILTIN_left() {
        int cp = getCaretPosition();
        if (cp > 0)
            setSelection(cp - 1);
    }

    /**
     * COMMAND
     * Move right one character
     */
    public void BUILTIN_right() {
        int cp = getCaretPosition();
        setSelection(cp + 1);
    }

    /**
     * COMMAND
     * Invoke the find dialog
     */
    public void BUILTIN_find() {
	if (!reSearch && haveSelection())
	    searchString = getSelectedText();
	FindDialog dlg = new FindDialog(
	    application.getFrame(), searchString, caseSensitive, reSearch);
	dlg.show();
	if (dlg.oked) {
	    caseSensitive = dlg.getCaseSensitivity();
            reSearch = dlg.getRESearch();
	    searchString = dlg.getFindString();
	    BUILTIN_refind();
	}
	repeatCommand = "refind";
    }

    /**
     * COMMAND
     * Repeat the last find from the caret position
     */
    public boolean BUILTIN_refind() {
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
                REMatch match = re.getMatch(getText(), curPos);
                if (match == null)
                    newPos = -1;
                else {
                    newPos = match.getStartIndex();
                    matchedLen = match.getEndIndex() - newPos;
                }
            } catch (REException ree) {
		throw new Error(ree.getMessage());
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
    public void BUILTIN_replace() {
	if (!reSearch && haveSelection())
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
		if (!BUILTIN_refind()) {
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
    public boolean BUILTIN_rereplace() {
	if (BUILTIN_refind()) {
	    overwriteSelection(replaceString);
	    return true;
	}
	return false;
    }

    /**
     * COMMAND
     * Converts the selection from HTML to
     * TWikiML. If there is no selection, converts the whole textarea.
     */
    public void BUILTIN_convert() {
	if (haveSelection()) {
	    String convertString = getSelectedText();
	    if (html2wiki == null)
		html2wiki = new HTML2TWiki();
	    String result = html2wiki.process(convertString, "nourl");
	    overwriteSelection(result);
	} else
	    beep();
    }

}

