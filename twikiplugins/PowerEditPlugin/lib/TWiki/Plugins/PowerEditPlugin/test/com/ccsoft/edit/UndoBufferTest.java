package com.ccsoft.edit;

import junit.framework.*;

public class UndoBufferTest extends TestCase {

    public UndoBufferTest(String name) {
	super(name);
    }

    public static Test suite() {
	return new TestSuite(UndoBufferTest.class);
    }

    class Undoable implements Difference.ModifiableText {
	String t;

	public void replace(String newt, int start, int end) {
	    t = t.substring(0, start) +
		newt + t.substring(end);
	}
    }

    UndoBuffer ub;
    Undoable text;

    protected void setUp() {
	ub = new UndoBuffer(3);
	text = new Undoable();
    }

    public void test4() {
	assert(!ub.hasUndo());
	ub.push(new Difference("before", "after"));
	assert(ub.hasUndo());
	ub.reset();
	assert(!ub.hasUndo());
    }

    public void test3() {
	assert(!ub.hasUndo());
	text.t = "before";
	for (int i = 0; i < 5; i++) {
	    String newt = text.t + (char)('a' + i);
	    ub.push(new Difference(text.t, newt));
	    text.t = newt;
	}
	String oldt = text.t;
	for (int i = 0; i < 5; i++) {
	    if (i < 3)
		assert(ub.hasUndo());
	    ub.undo(text);
	    if (i < 3) {
		oldt = oldt.substring(0, oldt.length() - 1);
	    } else {
		assert(!ub.hasUndo());
	    }
	    assertEquals(oldt, text.t);
	}
	assert(!ub.hasUndo());
    }

    public void test2() {
	assert(!ub.hasUndo());
	text.t = "before";
	for (int i = 0; i < 3; i++) {
	    String newt = text.t + (char)('a' + i);
	    ub.push(new Difference(text.t, newt));
	    assert(ub.hasUndo());
	    text.t = newt;
	}
	String oldt = text.t;
	for (int i = 0; i < 3; i++) {
	    assert(ub.hasUndo());
	    ub.undo(text);
	    oldt = oldt.substring(0, oldt.length() - 1);
	    assertEquals(oldt, text.t);
	}
	assert(!ub.hasUndo());
    }

    public void test1() {
	assert(!ub.hasUndo());
	text.t = "after";
	ub.push(new Difference("before", text.t));
	assert(ub.hasUndo());
	ub.undo(text);
	assertEquals("before", text.t);
	assert(!ub.hasUndo());
    }
}
