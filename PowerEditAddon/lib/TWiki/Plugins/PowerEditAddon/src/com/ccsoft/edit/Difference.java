// Copyright (C) Crawford Currie 2001 - All rights reserved
// It is hereby granted that this software can be used, copied, 
// modified, and distributed without fee provided that this 
// copyright notice appears in all copies.
package com.ccsoft.edit;

/**
 * Object that represents the difference between two strings, and
 * can undo that difference in a ModifiableText object. Note that
 * the undo function only makes sense when the ModifiableText object
 * contains exactly the text as it should be after the modification
 * was applied.
 */
class Difference {

    /**
     * Interface to a text object which can be modified.
     */
    public interface ModifiableText {
	void replace(String s, int start, int end);
    }

    /** Start position of the change in the MODIFIED string */
    private int index;
    /** Length of the change in the MODIFIED string */
    private int len;
    /** Text that was lost from the UNMODIFIED string by the modification */
    private String diff;

    /**
     * @param oldt the text BEFORE modification
     * @param newt the text AFTER modification
     */
    Difference(String oldt, String newt) {
	// On the assumption that the difference is contiguous, find
	// the differences between the old text and the new.
	// First probe forward...
	index = 0;
	while (index < oldt.length() && index < newt.length() &&
	       oldt.charAt(index) == newt.charAt(index))
	    index++;
	// Now probe backwards
	int bold = oldt.length();
	int bnew = newt.length();
	while (bold > index && bnew > index &&
	       oldt.charAt(bold - 1) == newt.charAt(bnew - 1)) {
	    bold--;
	    bnew--;
	}
	len = bnew - index;
	if (bold > index) {
	    diff = oldt.substring(index, bold);
	} else
	    diff = "";
    }

    /**
     * Undoes the modification.
     * @param ta text in which the change is to be undone
     * @return the caret position after the undo
     */
    public int undo(ModifiableText ta) {
	ta.replace(diff, index, index + len);
	return index;
    }
    
    /** Return debug representation */
    public String toString() {
	return "diff " + index + ":" + len + "<" + diff + ">";
    }
}
