package com.ccsoft.edit;

//import java.applet.*;
import java.awt.*;
//import java.net.*;
//import java.util.Enumeration;
import junit.framework.*;
import java.io.*;

public class ControlsTest extends TestCase {
    public ControlsTest(String name) {
	super(name);
    }

    public static Test suite() {
	return new TestSuite(ControlsTest.class);
    }

    public void testControlBlockReading() throws Exception {
	File f = new File("PowerEditControls.txt");
	Reader fr = new FileReader(f.getAbsolutePath());
	int c;
	String str = "";
	while ((c = fr.read()) != -1)
	    str += (char)c;
	fr.close();
	Controls controls = new Controls(str);
	assert(str,controls != null);
	ControlBlock cb = controls.getBlock("macros");
	assert(""+controls,cb != null);
	assertEquals("/home/%<nop>ACTION{who=\"\" due=\"\"}% ",
		     cb.getDefinition("action").getValue());
	assertEquals("\n---", cb.getDefinition("H").getValue());

	cb = controls.getBlock("keys");
	assert(""+controls,cb != null);
	assertEquals("/redo/", cb.getDefinition("^A").getValue());
	assertEquals("/copy/", cb.getDefinition("^C").getValue());
	assertEquals("/refind/", cb.getDefinition("^F").getValue());
	assertEquals("/redo/", cb.getDefinition("^N").getValue());
	assertEquals("/rereplace/", cb.getDefinition("^R").getValue());
	assertEquals("/undo/", cb.getDefinition("^U").getValue());
	assertEquals("/paste/", cb.getDefinition("^V").getValue());
	assertEquals("/cut/", cb.getDefinition("^X").getValue());

	cb = controls.getBlock("top");
	assert(""+controls,cb != null);
	assertEquals("/undo/", cb.getDefinition("UNDO").getValue());

	assertEquals("/find/", cb.getDefinition("FIND").getValue());
	assertEquals("/replace/", cb.getDefinition("REPLACE").getValue());
	assertEquals("/redo/",  cb.getDefinition("REDO").getValue());

	cb = controls.getBlock("bottom");
	assert(""+controls,cb != null);
	assertEquals("/cut/ %RED% /paste/ %ENDCOLOR%",
		     cb.getDefinition("Red").getValue());
	assertEquals("/cut/ %GREEN% /paste/ %ENDCOLOR%",
		     cb.getDefinition("Green").getValue());

	cb = controls.getBlock("left");
	assert(""+controls,cb != null);
	assertEquals("/cut/ */paste/* ",
		     cb.getDefinition("BOLD").getValue());
	assertEquals("/cut/ _/paste/_ ",
		     cb.getDefinition("ITALIC").getValue());
	assertEquals("/cut/ =/paste/= ",
		     cb.getDefinition("TT").getValue());
	assertEquals("/home/   * /cut/",
		     cb.getDefinition("UL").getValue());
	assertEquals("/home/   1 /cut/",
		     cb.getDefinition("OL").getValue());

	cb = controls.getBlock("right");
	assert(""+controls,cb != null);
	assertEquals("/home//H/+ ", cb.getDefinition("H1").getValue());
	assertEquals("/home//H/++ ", cb.getDefinition("H2").getValue());
	assertEquals("/home//H/+++ ", cb.getDefinition("H3").getValue());
	assertEquals("/home//H/++++ ", cb.getDefinition("H4").getValue());
	assertEquals("/home//H/+++++ ", cb.getDefinition("H5").getValue());
	assertEquals("/home//H/++++++ ", cb.getDefinition("H6").getValue());
    }

    public void testPanelMaking() throws Exception {
	File f = new File("PowerEditControls.txt");
	Reader fr = new FileReader(f.getAbsolutePath());
	int c;
	String str = "";
	while ((c = fr.read()) != -1)
	    str += (char)c;
	fr.close();
	Controls controls = new Controls(str);
	ControlBlock b = controls.getBlock("top");
	assert(""+b, b != null);
	java.awt.Panel p = b.makePanel(new FlowLayout(), null);

	b = controls.getBlock("bottom");
	assert(b != null);
	p = b.makePanel(new FlowLayout(), null);

	b = controls.getBlock("left");
	assert(b != null);
	p = b.makePanel(new FlowLayout(), null);

	b = controls.getBlock("right");
	assert(b != null);
	p = b.makePanel(new FlowLayout(), null);
    }
}
