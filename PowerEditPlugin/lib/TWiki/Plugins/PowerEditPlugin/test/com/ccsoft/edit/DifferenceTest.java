package com.ccsoft.edit;

import junit.framework.*;

public class DifferenceTest extends TestCase {

    class Undoable implements Difference.ModifiableText {
	String t;

	public void replace(String newt, int start, int end) {
	    t = t.substring(0, start) +
		newt + t.substring(end);
	}
    }

    public DifferenceTest(String name) {
	super(name);
    }

    public static Test suite() {
	return new TestSuite(DifferenceTest.class);
    }

    private Undoable text;

    protected void setUp() {
	text = new Undoable();
    }

    public void testReplace16() {
	text.t = "after";
	Difference d = new Difference("before", text.t);
	d.undo(text);
	assertEquals("before", text.t);
    }

    public void testReplace15() {
	text.t = "axyd";
	Difference d = new Difference("abcd", text.t);
	d.undo(text);
	assertEquals("abcd", text.t);
    }

    public void testReplace14() {
	text.t = "abxy";
	Difference d = new Difference("abcd", text.t);
	d.undo(text);
	assertEquals("abcd", text.t);
    }

    public void testReplace13() {
	text.t = "xycd";
	Difference d = new Difference("abcd", text.t);
	d.undo(text);
	assertEquals("abcd", text.t);
    }

    public void testDelete12() {
	text.t = "ad";
	Difference d = new Difference("abcd", text.t);
	d.undo(text);
	assertEquals("abcd", text.t);
    }

    public void testDelete11() {
	text.t = "d";
	Difference d = new Difference("abcd", text.t);
	d.undo(text);
	assertEquals("abcd", text.t);
    }

    public void testDelete10() {
	text.t = "abc";
	Difference d = new Difference("abcd", text.t);
	d.undo(text);
	assertEquals("abcd", text.t);
    }

    public void testInsert9() {
	text.t = "abc";
	Difference d = new Difference("ab", text.t);
	d.undo(text);
	assertEquals("ab", text.t);
    }

    public void testInsert8() {
	text.t = "abc\nd";
	Difference d = new Difference("a", text.t);
	d.undo(text);
	assertEquals("a", text.t);
    }

    public void testInsert7() {
	text.t = "abc\nd";
	Difference d = new Difference("d", text.t);
	d.undo(text);
	assertEquals("d", text.t);
    }

    public void testInsert6() {
	text.t = "abcd";
	Difference d = new Difference("ad", text.t);
	d.undo(text);
	assertEquals("ad", text.t);
    }

    public void testInsert5() {
	text.t = "abc";
	Difference d = new Difference("ab", text.t);
	d.undo(text);
	assertEquals("ab", text.t);
    }

    public void testInsert4() {
	text.t = "abc";
	Difference d = new Difference("ac", text.t);
	d.undo(text);
	assertEquals("ac", text.t);
    }

    public void testInsert3() {
	text.t = "abc";
	Difference d = new Difference("bc", text.t);
	d.undo(text);
	assertEquals("bc", text.t);
    }

    public void testDelete2() {
	text.t = "";
	Difference d = new Difference("a", text.t);
	d.undo(text);
	assertEquals("a", text.t);
    }

    public void testInsert1() {
	text.t = "a";
	Difference d = new Difference("", text.t);
	d.undo(text);
	assertEquals("", text.t);
    }
}
