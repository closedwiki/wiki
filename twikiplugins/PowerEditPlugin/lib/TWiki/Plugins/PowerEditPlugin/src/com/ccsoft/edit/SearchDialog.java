// Copyright (C) Crawford Currie 2001 - All rights reserved
// It is hereby granted that this software can be used, copied, 
// modified, and distributed without fee provided that this 
// copyright notice appears in all copies.
package com.ccsoft.edit;

import java.awt.*;
import java.awt.event.*;

/**
 * Abstract base class containing common elements of Find and
 * Replace dialogs.
 */
abstract class SearchDialog
extends Dialog {

    /** Label on search string */
    protected Label textLbl;
    /** Search string */
    protected TextField textField;
    protected Button okBtn;
    protected Button cancelBtn;
    protected Checkbox caseSensitive;
    protected Checkbox reSearch;
    /** Listener for 'Enter' pressed in text fields */
    protected KeyAdapter returnListener;
    /** True if OK hit or Enter pressed in a text field */
    public boolean oked;
    
    /** Action on dialog frame closed */
    private WindowAdapter waClosing =  new WindowAdapter() {
	    public void windowClosing(WindowEvent e) {
		oked = false;
		hide();
	    }
	};

    /**
     * @param parent the Frame parent.
     * @param title the Dialog title.
     * @param cs case sensitivity
     */
    protected SearchDialog(Frame parent, String title,
                           boolean cs, boolean re) {

	super(parent, title, true);
	addWindowListener(waClosing);
	textLbl = new Label(title + ":");
	textField = new TextField("01234567890123456789");
	okBtn = new Button("Ok");
	okBtn.addActionListener(new ActionListener() {
		public void actionPerformed(ActionEvent e) {
		    oked = true;
		    hide();
		}
	    });
	cancelBtn = new Button("Cancel");
	cancelBtn.addActionListener(new ActionListener() {
		public void actionPerformed(ActionEvent e) {
		    oked = false;
		    hide();
		}
	    });
	caseSensitive = new Checkbox("Case sensitive", cs);
	reSearch = new Checkbox("Regular expressions", re);
        returnListener = new KeyAdapter() {
                public void keyPressed(KeyEvent k) {
                    if (k.getKeyChar() == '\n') {
                        oked = true;
                        hide();
                    }
                }
            };
        textField.addKeyListener(returnListener);
    }

    /**
     * @return the string to find
     */
    public String getFindString() {
	return textField.getText();
    }

    /**
     * @return the state of the 'Case Sensitive' check
     */
    public boolean getCaseSensitivity() {
	return caseSensitive.getState();
    }

    /**
     * @return the state of the 'Regular expressions' check
     */
    public boolean getRESearch() {
	return reSearch.getState();
    }
}
