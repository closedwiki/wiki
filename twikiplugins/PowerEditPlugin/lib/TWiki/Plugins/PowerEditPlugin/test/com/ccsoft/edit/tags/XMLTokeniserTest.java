package com.ccsoft.edit.tags;

import junit.framework.*;
import java.io.*;

public class XMLTokeniserTest extends TestCase {

    public XMLTokeniserTest(String name) {
	super(name);
    }

    public static Test suite() {
	return new TestSuite(XMLTokeniserTest.class);
    }

    public void test1simpletokens() {
	String controlText = "bleah <macros> blah </snot>";
	XMLTokeniser st = new XMLTokeniser(new StringReader(controlText),
					     controlText.length());
	if (st.nextToken() != XMLTokeniser.WORD) assert(""+st, false);
	if (!st.string.equals("bleah")) assert(st.string, false);
	if (st.nextToken() != XMLTokeniser.TAG) assert(""+st, false);
	if (!st.string.equals("macros")) assert(st.string, false);
	if (st.nextToken() != XMLTokeniser.WORD) assert(""+st, false);
	if (!st.string.equals("blah")) assert(st.string, false);
	if (st.nextToken() != XMLTokeniser.TAG) assert(""+st, false);
	if (!st.string.equals("/snot")) assert(st.string, false);
	if (st.nextToken() != XMLTokeniser.EOF) assert(""+st, false);
    }

    public void test2comments() {
	String controlText = "<! macros>A<!-- snick snick -->B<!C>";
	XMLTokeniser st = new XMLTokeniser(new StringReader(controlText),
					     controlText.length());
	if (st.nextToken() != XMLTokeniser.WORD) assert(""+st, false);
	if (!st.string.equals("A")) assert(st.string, false);
	if (st.nextToken() != XMLTokeniser.WORD) assert(""+st, false);
	if (!st.string.equals("B")) assert(st.string, false);
    }

    public void test3tagafter() {
	String controlText = "<!-- snick snick --><verbatim>";
	XMLTokeniser st = new XMLTokeniser(new StringReader(controlText),
					     controlText.length());
	if (st.nextToken() != XMLTokeniser.TAG) assert(""+st, false);
	if (!st.string.equals("verbatim")) assert(st.string, false);
    }

    public void test4attrvals() {
	String controlText = "<map name=\"action\" action=\"/home/%&lt;nop>ACTION{who=&quot;&quot; due=&quot;&quot;}% \"/>";
	XMLTokeniser st = new XMLTokeniser(new StringReader(controlText),
					     controlText.length());
	if (st.nextToken() != XMLTokeniser.TAG) assert(""+st, false);
	assert(""+st, st.string.equals("map"));
	assert(""+st, st.attrs.getString("name").equals("action"));
	assert(""+st, st.attrs.getString("action").equals("/home/%<nop>ACTION{who=\"\" due=\"\"}% "));
    }

    private String replace(String t, char c, String ent) {
	String value = "";
	for (;;) {
	    int j = t.indexOf(c);
	    if (j == -1) {
		value += t;
		break;
	    }
	    value += t.substring(0, j) + ent;
	    t = t.substring(j + 1);
	}
	return value;
    }

    private String map(String nm, String vl) {
	vl = replace(vl, '&', "&amp;");
	vl = replace(vl, '\"', "&quot;");
	vl = replace(vl, '<', "&lt;");
	vl = replace(vl, '>', "&gt;");
	return "<map name=\"" + nm + "\" action=\"" + vl + "\"/>";
    }

    String mkblock(String name, String[][] vals) {
	String res = "<" + name + ">\n";
	for (int i = 0; i < vals.length; i++) {
	    res += map(vals[i][0], vals[i][1]);
	}
	return res + "\n<" + name + ">";
    }

    public void test5controls() {
	String[][] macros = new String[][] {
	    { "action", "/home/%<nop>ACTION{who=\"\"; due=\"\"}% "},
	    { "H", "\\n---"},
	};
	String[][] keys = new String[][] {
	    { "^A", "/redo/"},
	    { "^C", "/copy/"},
	    { "^F", "/refind/"},
	    { "^N", "/redo/"},
	    { "^R", "/rereplace/"},
	    { "^U", "/undo/"},
	    { "^V", "/paste/"},
	    { "^X", "/cut/"},
	};
	String[][] top = new String[][] {
	    { "CUT", "/cut/"},
	    { "COPY", "/copy/"},
	    { "PASTE", "/paste/"},
	    { "FIND", "/find/"},
	    { "REFIND", "/refind/"},
	    { "REPLACE", "/replace/"},
	    { "REREPLACE", "/rereplace/"},
	    { "UNDO", "/undo/"},
	    { "REDO", "/redo/"},
	};
	String[][] left = new String[][] {
	    { "BOLD", "/cut/ */paste/* "},
	    { "ITALIC", "/cut/ _/paste/_ "},
	    { "TT", "/cut/ =/paste/= "},
	    { "UL", "/home/   * /cut/"},
	    { "OL", "/home/   1 /cut/"},
	    { "LINK", "[[http://www.xyz.com][xyz]]"},
	};
	    
	String[][] right = new String[][] {
	    { "H1", "/home//H/+ "},
	    { "H2", "/home//H/++ "},
	    { "H3", "/home//H/+++ "},
	    { "H4", "/home//H/++++ "},
	    { "H5", "/home//H/+++++ "},
	    { "H6", "/home//H/++++++ "},
	};
	String[][] bottom = new String[][] {
	    { "Red", "/cut/ %RED% /paste/ %ENDCOLOR%"},
	    { "Green", "/cut/ %GREEN% /paste/ %ENDCOLOR%"},
	    { "http://localhost/twiki/pub/TWiki/SmiliesPlugin/smile.gif", "/action/"},
	};

	String controlText =
	    mkblock("macros", macros) +
	    mkblock("keys", keys) +
	    mkblock("top", top) +
	    mkblock("left", left) +
	    mkblock("right", right) +
	    mkblock("bottom", bottom);
	    
	XMLTokeniser st = new XMLTokeniser(new StringReader(controlText),
					     controlText.length());
	String[][] block = null;
	String openblock = null;
	int index = -1;
	boolean done = false;
	while (!done) {
	    switch (st.nextToken()) {
	    case XMLTokeniser.EOF: done=true; break;
	    case XMLTokeniser.WORD: assert("" + st, false);
	    case XMLTokeniser.TAG:
		if (st.string.equals("macros")) {
		    openblock = st.string;
		    block = macros; macros = null;
		    index = 0;
		} else if (st.string.equals("keys")) {
		    openblock = st.string;
		    block = keys; keys = null;
		    index = 0;
		} else if (st.string.equals("top")) {
		    openblock = st.string;
		    block = top; top = null;
		    index = 0;
		} else if (st.string.equals("left")) {
		    openblock = st.string;
		    block = left; left = null;
		    index = 0;
		} else if (st.string.equals("right")) {
		    openblock = st.string;
		    block = right; right = null;
		    index = 0;
		} else if (st.string.equals("bottom")) {
		    openblock = st.string;
		    block = bottom; bottom = null;
		    index = 0;
		} else if (st.string.startsWith("/")) {
		    assert(st.string.substring(1).equals(openblock));
		    assert(index == block.length);
		    openblock = null;
		    block = null;
		} else {
		    assert(st.string.equals("map"));
		    assert(st.attrs.getString("name") + "="+block[index][0],
			   st.attrs.getString("name").equals(block[index][0]));
		    assert(st.attrs.getString("action").equals(block[index][1]));
		    index++;
		}
		break;
	    }
	}
	assert("macros", macros == null);
	assert("keys", keys == null);
	assert("left", left == null);
	assert("top", top == null);
	assert("right", right == null);
	assert("bottom", bottom == null);
    }
}
