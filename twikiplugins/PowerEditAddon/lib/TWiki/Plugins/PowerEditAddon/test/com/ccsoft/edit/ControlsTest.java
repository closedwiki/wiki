package com.ccsoft.edit;

//import java.applet.*;
//import java.awt.*;
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

    public void test1() throws Exception {
	Controls controls = new Controls();
	File f = new File("PowerEditControls.txt");
	Reader fr = new FileReader(f.getAbsolutePath());
	int c;
	String str = "";
	while ((c = fr.read()) != -1)
	    str += (char)c;
	fr.close();
	controls.parse(str);
	assertEquals("/home/%<nop>ACTION{who=\"\" due=\"\"}% ",
		     controls.getMacro("action"));
	assertEquals("\n---", controls.getMacro("H"));
	assertEquals("/redo/", controls.getKey("A"));
	assertEquals("/copy/", controls.getKey("C"));
	assertEquals("/refind/", controls.getKey("F"));
	assertEquals("/redo/", controls.getKey("N"));
	assertEquals("/rereplace/", controls.getKey("R"));
	assertEquals("/undo/", controls.getKey("U"));
	assertEquals("/paste/", controls.getKey("V"));
	assertEquals("/cut/", controls.getKey("X"));
	assertEquals("/undo/", controls.getDefinition("top", "Undo"));

	assertEquals("/find/", controls.getDefinition("top", "Find..."));
	assertEquals("/replace/", controls.getDefinition("top", "Replace..."));
	assertEquals("/redo/",  controls.getDefinition("top", "Again"));
 	assertEquals("/convert/", controls.getDefinition("top", "HTML2Wiki"));

	assertEquals("/cut/ %RED% /paste/ %ENDCOLOR%",
		     controls.getDefinition("bottom", "Red"));
	assertEquals("/cut/ %GREEN% /paste/ %ENDCOLOR%",
		     controls.getDefinition("bottom", "Green"));

	assertEquals("/cut/ */paste/* ",
		     controls.getDefinition("left", "Bold"));
	assertEquals("/cut/ _/paste/_ ",
		     controls.getDefinition("left", "Italic"));
	assertEquals("/cut/ =/paste/= ",
		     controls.getDefinition("left", "TT"));
	assertEquals("/home/   * /cut/",
		     controls.getDefinition("left", "*..."));
	assertEquals("/home/   1 /cut/",
		     controls.getDefinition("left", "1..."));
	assertEquals("/action/",
		     controls.getDefinition("left", "Action"));

	assertEquals("/home//H/+ ", controls.getDefinition("right", "H1"));
	assertEquals("/home//H/++ ", controls.getDefinition("right", "H2"));
	assertEquals("/home//H/+++ ", controls.getDefinition("right", "H3"));
	assertEquals("/home//H/++++ ", controls.getDefinition("right", "H4"));
	assertEquals("/home//H/+++++ ", controls.getDefinition("right", "H5"));
	assertEquals("/home//H/++++++ ",
		     controls.getDefinition("right", "H6"));
    }
}
