// Copyright (C) Crawford Currie 2001 - All rights reserved
// It is hereby granted that this software can be used, copied, 
// modified, and distributed without fee provided that this 
// copyright notice appears in all copies.
package com.ccsoft.edit;

/**
 * An undo buffer for changes made to a modifiable text object
 */
class UndoBuffer {

    /** Size of the buffer (max number of undos) */
    private int size;
    /** The undo buffer */
    private Difference[] buffer;
    /** Index of the most recent undo added to the buffer */
    private int top;

    /** Construct an undo buffer of given size */
    UndoBuffer(int maxsz) {
	size = maxsz;
	buffer = new Difference[size];
	reset();
    }

    /** Clear out the buffer */
    void reset() {
	top = 0;
	for (int i = 0; i < size; i++)
	    buffer[i] = null;
    }
    
    /** True if there's an undo waiting in the buffer */
    boolean hasUndo() {
	return buffer[top] != null;
    }

    /** Add a new undo to the buffer */
    void push(Difference d) {
	top = (top + 1) % size;
	buffer[top] = d;
    }

    /** Remove the most recent undo from the buffer */
    Difference pop() {
	Difference d = buffer[top];
	buffer[top] = null;
	if (top == 0)
	    top = size - 1;
	else
	    top--;
	return d;
    }

    /** Apply the most recent undo to the modifiable text object.
     * @return the index of the end of the modification, or -1
     * if there are no pending undos
     */
    int undo(Difference.ModifiableText dt) {
	Difference d = pop();
	if (d == null)
	    return -1;
	return d.undo(dt);
    }
}
