// Copyright (C) Crawford Currie 2001 - All rights reserved
// It is hereby granted that this software can be used, copied, 
// modified, and distributed without fee provided that this 
// copyright notice appears in all copies.
package com.ccsoft.edit;

import java.awt.*;

/**
 * Dialog for capturing replace strings
 */
public class ReplaceDialog extends SearchDialog {
    
    /** Field for replacement text */
    private TextField textSubField;

    /**
     * @param parent containing frame
     * @param defStr default string
     * @param defSubStr default replacement
     * @param cs true if case-sensitive
     * @param re true if regular expression matching to be done
     */
    public ReplaceDialog(Frame parent,
			 String defStr, String defSubStr,
			 boolean cs, boolean re) {
	super(parent, "Replace", cs, re);
	GridBagLayout grid = new GridBagLayout();
	setLayout(grid);
	GridBagConstraints gbc = new GridBagConstraints();

        // First column
	gbc.gridx = 0;
	gbc.gridy = 0;
	grid.setConstraints(textLbl, gbc);
	add(textLbl);

	Label textSubLbl = new Label("With:");
	gbc.gridy = 1;
	grid.setConstraints(textSubLbl, gbc);
	add(textSubLbl);

	gbc.gridy = 2;
	grid.setConstraints(caseSensitive, gbc);
	add(caseSensitive);

	gbc.gridy = 3;
	grid.setConstraints(okBtn, gbc);
	add(okBtn);

        // Second column
	gbc.gridwidth = GridBagConstraints.REMAINDER;
	gbc.gridx = 1;
	gbc.gridy = 0;
	grid.setConstraints(textField, gbc);
	add(textField);

	textSubField = new TextField("01234567890123456789");
	gbc.gridy = 1;
	grid.setConstraints(textSubField, gbc);
	add(textSubField);

        gbc.gridx = 2;
	grid.setConstraints(reSearch, gbc);
	add(reSearch);

	gbc.gridy = 3;
	grid.setConstraints(cancelBtn, gbc);
	add(cancelBtn);

	pack();
        textField.addKeyListener(returnListener);
	textField.setText(defStr);
	textField.selectAll();
	textSubField.setText(defSubStr);
	textSubField.selectAll();
	textSubField.requestFocus();
    }

    /**
     * @return the string to replace with
     */
    public String getReplaceString() {
	return textSubField.getText();
    }
}
