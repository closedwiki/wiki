package com.ccsoft.edit;

import java.awt.*;
import junit.framework.*;

public class SearchableTextAreaTest extends TestCase implements Application {
    public SearchableTextAreaTest(String name) {
	super(name);
    }

    public static Test suite() {
	return new TestSuite(SearchableTextAreaTest.class);
    }

    private SearchableTextArea sa;
    private static final String line1 = "Line 1\n";
    private static final String line2 = "line 2\n";
    private static final String line3 = "Line 3";
    private static final String testText = line1 + line2 + line3;

    static Frame frame = new Frame();

    protected void setUp() {
        sa = new SearchableTextArea(null);
        frame.add(sa);
        frame.pack();
        frame.show();
    }

    public Frame getFrame() {
        return frame;
    }

    public void showStatus(String key) {
	throw new Error(key);
    }

    protected void tearDown() {
        frame.remove(sa);
    }

    private void checkSelection(int start, int end) {
	assert(sa.getSelectionStart() == start);
        assert(sa.getSelectionEnd() == end);
    }

    public void testReset() {
        sa.reset(this, testText, 20, 20);
        assertEquals("", sa.clipboard);
        assertEquals("", sa.searchString);
        assertEquals("", sa.replaceString);
        assert(sa.getRows() == 20);
        assert(sa.getColumns() == 20);
        assertEquals(testText, sa.getText());
    }

    public void testMoves() {
        sa.reset(this, testText, 5, 5);
        sa.setCaretPosition(0);

        sa.BUILTIN_left();
        assert(sa.getCaretPosition() == 0);

        sa.BUILTIN_right();
        assert(sa.getCaretPosition() == 1);

        sa.BUILTIN_left();
        assert(sa.getCaretPosition() == 0);

        sa.BUILTIN_end();
        assert(sa.getCaretPosition() == line1.length() - 1);

        sa.BUILTIN_home();
        assert(sa.getCaretPosition() == 0);

        sa.setCaretPosition(line1.length());
        sa.BUILTIN_end();
        assert(sa.getCaretPosition() == line1.length() + line2.length() - 1);

        sa.BUILTIN_home();
        assert(sa.getCaretPosition() == line1.length());

        sa.setCaretPosition(testText.length());
        sa.BUILTIN_right();
        assert(sa.getCaretPosition() == testText.length());
    }

    public void testCut() {
        sa.reset(this, testText, 5, 5);
        assertEquals("", sa.clipboard);
        sa.select(0, line1.length());
	checkSelection(0, line1.length());
        sa.BUILTIN_cut();
	checkSelection(0, 0);
        assertEquals(line1, sa.clipboard);
        assertEquals(line2 + line3, sa.getText());
        assert(sa.getCaretPosition() == 0);
    }

    public void testCopy() {
        sa.reset(this, testText, 5, 5);
        assertEquals("", sa.clipboard);
        sa.select(0, line1.length());
        sa.BUILTIN_copy();
        assertEquals(line1, sa.clipboard);
        assertEquals(testText, sa.getText());
	checkSelection(0, line1.length());
    }

    public void testPasteSimple() {
        sa.reset(this, testText, 5, 5);
        assertEquals("", sa.clipboard);
        sa.clipboard = line3;
        sa.BUILTIN_paste();
        assertEquals(line3 + testText, sa.getText());
        assert(sa.getCaretPosition() == line3.length());
	checkSelection(sa.getCaretPosition(), sa.getCaretPosition());
    }

    public void testPasteAtCaret() {
        sa.reset(this, testText, 5, 5);
        assertEquals("", sa.clipboard);
        sa.clipboard = line3;
        sa.setCaretPosition(line1.length());
        sa.BUILTIN_paste();
        assertEquals(line1 + line3 + line2 + line3, sa.getText());
        assert(sa.getCaretPosition() == line1.length() + line3.length());
	checkSelection(sa.getCaretPosition(), sa.getCaretPosition());
    }

    public void testPasteOverSelection() {
        sa.reset(this, testText, 5, 5);
        sa.select(line1.length(), line1.length() + line2.length());
        sa.clipboard = "boogle";
        sa.BUILTIN_paste();
        assertEquals(line1 + "boogle" + line3, sa.getText());
        assert(sa.getCaretPosition() == line1.length() + "boogle".length());
	checkSelection(sa.getCaretPosition(), sa.getCaretPosition());
    }

    private void checkFind(int start, int end) {
        sa.BUILTIN_refind();
	assertEquals(testText, sa.getText());
        assert(sa.getCaretPosition() == sa.getSelectionEnd());
	checkSelection(start, end);
    }

    public void testFindCS() {
        sa.reset(this, testText, 5, 5);
        sa.searchString = "Line";
	checkFind(0, 4);
	checkFind((line1 + line2).length(),
		  (line1 + line2).length() + 4);
    }

    public void testFindCI() {
        sa.reset(this, testText, 5, 5);
        sa.searchString = "lInE";
        sa.caseSensitive = false;
	checkFind(0, 4);
        checkFind(line1.length(), line1.length() + 4);
    }

    public void testFindRECS() {
        sa.reset(this, testText, 5, 5);
        sa.searchString = "Line [0-9]";
        sa.caseSensitive = true;
        sa.reSearch = true;

	checkFind(0, line1.length()-1);
	checkFind((line1+line2).length(),
		  (line1+line2+line3).length());
    }

    public void testFindRECI() {
        sa.reset(this, testText, 5, 5);
        sa.searchString = "line [0-9]";
        sa.caseSensitive = false;
        sa.reSearch = true;

	checkFind(0, line1.length()-1);
	checkFind(line1.length(), (line1+line2).length()-1);
	checkFind((line1+line2).length(), (line1+line2+line3).length());
    }

    private void checkReplace(String nt, int caret) {
        sa.BUILTIN_rereplace();
        assertEquals(nt, sa.getText());
        assert(sa.getCaretPosition() == caret);
	checkSelection(caret, caret);
    }

    public void testReplaceCS() {
        sa.reset(this, testText, 5, 5);
        sa.searchString = "Line";
        sa.replaceString = "Tomato";

        String newText = "Tomato" + line1.substring(4) + line2;
	checkReplace(newText + line3, 6);
	checkReplace(newText + "Tomato" + line3.substring(4),
		     newText.length() + 6);
    }

    public void testReplaceCI() {
        sa.reset(this, testText, 5, 5);
        sa.searchString = "Line";
        sa.replaceString = "Tomato";
        sa.caseSensitive = false;
        String newText = "Tomato" + line1.substring(4);
	checkReplace(newText + line2 + line3, 6);
	int end = newText.length();
        newText = "Tomato" + line1.substring(4) +
            "Tomato" + line2.substring(4);
	checkReplace(newText + line3, end + 6);
	end = newText.length();
        newText = "Tomato" + line1.substring(4) +
            "Tomato" + line2.substring(4) +
            "Tomato" + line3.substring(4);
	checkReplace(newText, end + 6);
    }

    public void testMacro1() {
        sa.reset(this, testText, 5, 5);
        sa.searchString = line2;
        sa.BUILTIN_refind();
        sa.replayMacro(".");
        assertEquals(line1 + "." + line3, sa.getText());
    }

    public void testMacro2() {
        sa.reset(this, testText, 5, 5);
        sa.searchString = line2;
        sa.BUILTIN_refind();
        sa.replayMacro("/cut/_/paste/_");
        assertEquals(line1 + "_" + line2 + "_" + line3, sa.getText());
    }

    public void testMacro3() {
        sa.reset(this, testText, 5, 5);
        sa.searchString = line2;
        sa.BUILTIN_refind();
        sa.replayMacro("//");
        assertEquals(line1 + "/" + line3, sa.getText());
    }

    public void testMacro5() {
        sa.reset(this, testText, 5, 5);
        sa.searchString = line2;
        sa.BUILTIN_refind();
        sa.replayMacro("");
        assertEquals(testText, sa.getText());
    }
}
