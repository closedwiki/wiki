package com.ccsoft.edit.tags;

import java.util.Enumeration;
import java.util.Vector;

import com.ccsoft.edit.Block;

/**
 * Table size information. This consists of an array of rows,
 * each of which is an array of columns, and combined info about
 * the rows and columns of the whole table.
 */
public class TableInfo extends Vector {
    /** Number of columns */
    public int cols;
    
    public int[] minWidth;
    public int[] prefWidth;

    /**
     * Lay out the table in the given width
     */
    public void layout(int mw) {
	// Count columns
	cols = 0;
	int row = 0;
	Enumeration e = elements();
	while (e.hasMoreElements()) {
	    RowInfo ri = (RowInfo)e.nextElement();
	    Enumeration ce = ri.elements();
	    int col = 0;
	    while (ce.hasMoreElements()) {
		int[] ced = (int[])ce.nextElement();
		if (ced[RowInfo.SPAN] > 1) {
		    col += ced[RowInfo.SPAN];
		} else {
		    col++;
		}
	    }
	    cols = Math.max(cols, col);
	}

	prefWidth = new int[cols];
	minWidth = new int[cols];
	e = elements();
	while (e.hasMoreElements()) {
	    RowInfo ri = (RowInfo)e.nextElement();
	    Enumeration ce = ri.elements();
	    int col = 0;
	    while (ce.hasMoreElements()) {
		int[] ced = (int[])ce.nextElement();
		if (ced[RowInfo.SPAN] > 1) {
		    // Ignore columns with colspan > 1
		    col += ced[RowInfo.SPAN];
		} else {
		    prefWidth[col] = Math.max(prefWidth[col],
					      ced[RowInfo.PREF]);
		    minWidth[col] = Math.max(minWidth[col], ced[RowInfo.MIN]);
		    col++;
		}
	    }
	}

	// correct full page widths
	int colcount = cols;
	while (--colcount >= 0) {
	    if (prefWidth[colcount] >= Block.FULL_PAGE) {
		prefWidth[colcount] = mw;
	    }
	    if (minWidth[colcount] >= Block.FULL_PAGE) {
		minWidth[colcount] = mw;
	    }
	}
    }

    /** Add row information */
    public void addRow(RowInfo ri) {
	addElement(ri);
    }

    public String dump() {
	String mw = "", pw = "";
	for (int i = 0; i < cols; i++) {
	    if (i > 0) {
		mw += " "; pw += " ";
	    }
	    mw += "" + minWidth[i];
	    pw += "" + prefWidth[i];
	}
	String rows = super.toString();
	return "Min " + mw + "\nPref " + pw + "\nRows " + rows;
    }
}
