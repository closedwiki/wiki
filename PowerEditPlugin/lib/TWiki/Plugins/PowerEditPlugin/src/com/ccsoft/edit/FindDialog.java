// Copyright (C) Crawford Currie 2001 - All rights reserved
// It is hereby granted that this software can be used, copied, 
// modified, and distributed without fee provided that this 
// copyright notice appears in all copies.
package com.ccsoft.edit;
           
import java.awt.*;

/**
 * Dialog to capture a 'Find' string
 */
class FindDialog extends SearchDialog {

    /**
     * @param parent containing frame
     * @param defStr default string
     * @param cs true if case-sensitive
     * @param re true if regular expression matching to be done
     */
    public FindDialog(Frame parent, String defStr,
		      boolean cs, boolean re) {
	super(parent, "Find", cs, re);
	GridBagLayout grid = new GridBagLayout();
	setLayout(grid);
	GridBagConstraints gbc = new GridBagConstraints();

	gbc.gridx = 0;
	gbc.gridy = 0;
	grid.setConstraints(textLbl, gbc);
	add(textLbl);

	gbc.gridy = 2;
	grid.setConstraints(okBtn, gbc);
	add(okBtn);

	gbc.gridy = 1;
	gbc.gridwidth = 1;
	grid.setConstraints(caseSensitive, gbc);
	add(caseSensitive);

        gbc.gridx = 1;
	gbc.gridwidth = GridBagConstraints.REMAINDER;
	grid.setConstraints(reSearch, gbc);
	add(reSearch);

	gbc.gridy = 0;
	grid.setConstraints(textField, gbc);
	add(textField);

	gbc.gridy = 2;
	grid.setConstraints(cancelBtn, gbc);
	add(cancelBtn);

	pack();
	textField.setText(defStr);
	textField.selectAll();
	textField.requestFocus();
    }
}
