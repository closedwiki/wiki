package com.ccsoft.edit.tags;

import java.util.Vector;

/**
 * Information about a table row
 */
class RowInfo extends Vector {
    /** Indices into entries in vector */
    public static final int MIN = 0;
    public static final int PREF = 1;
    public static final int SPAN = 2;

    /**
     * Add column information to the row
     */
    void addCol(int minw, int prefw, int colspan) {
	addElement(new int[]{minw, prefw, colspan});
    }
}
