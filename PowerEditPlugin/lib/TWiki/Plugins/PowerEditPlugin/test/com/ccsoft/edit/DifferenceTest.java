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

    public void test16replace() {
	text.t = "after";
	Difference d = new Difference("before", text.t);
	d.undo(text);
	assertEquals("before", text.t);
    }

    public void test15replace() {
	text.t = "axyd";
	Difference d = new Difference("abcd", text.t);
	d.undo(text);
	assertEquals("abcd", text.t);
    }

    public void test14replace() {
	text.t = "abxy";
	Difference d = new Difference("abcd", text.t);
	d.undo(text);
	assertEquals("abcd", text.t);
    }

    public void test13replace() {
	text.t = "xycd";
	Difference d = new Difference("abcd", text.t);
	d.undo(text);
	assertEquals("abcd", text.t);
    }

    public void test12delete() {
	text.t = "ad";
	Difference d = new Difference("abcd", text.t);
	d.undo(text);
	assertEquals("abcd", text.t);
    }

    public void test11delete() {
	text.t = "d";
	Difference d = new Difference("abcd", text.t);
	d.undo(text);
	assertEquals("abcd", text.t);
    }

    public void test10delete() {
	text.t = "abc";
	Difference d = new Difference("abcd", text.t);
	d.undo(text);
	assertEquals("abcd", text.t);
    }

    public void test9insert() {
	text.t = "abc";
	Difference d = new Difference("ab", text.t);
	d.undo(text);
	assertEquals("ab", text.t);
    }

    public void test8insert() {
	text.t = "abc\nd";
	Difference d = new Difference("a", text.t);
	d.undo(text);
	assertEquals("a", text.t);
    }

    public void test7insert() {
	text.t = "abc\nd";
	Difference d = new Difference("d", text.t);
	d.undo(text);
	assertEquals("d", text.t);
    }

    public void test6insert() {
	text.t = "abcd";
	Difference d = new Difference("ad", text.t);
	d.undo(text);
	assertEquals("ad", text.t);
    }

    public void test5insert() {
	text.t = "abc";
	Difference d = new Difference("ab", text.t);
	d.undo(text);
	assertEquals("ab", text.t);
    }

    public void test4insert() {
	text.t = "abc";
	Difference d = new Difference("ac", text.t);
	d.undo(text);
	assertEquals("ac", text.t);
    }

    public void test3insert() {
	text.t = "abc";
	Difference d = new Difference("bc", text.t);
	d.undo(text);
	assertEquals("bc", text.t);
    }

    public void test2delete() {
	text.t = "";
	Difference d = new Difference("a", text.t);
	d.undo(text);
	assertEquals("a", text.t);
    }

    public void test1insert() {
	text.t = "a";
	Difference d = new Difference("", text.t);
	d.undo(text);
	assertEquals("", text.t);
    }
}
