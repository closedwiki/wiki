package com.ccsoft.edit;

import java.applet.*;
import java.awt.*;
import java.net.*;
import java.util.Enumeration;
import junit.framework.*;

public class ControlsTest extends TestCase {
    public ControlsTest(String name) {
	super(name);
    }

    public static Test suite() {
	return new TestSuite(ControlsTest.class);
    }

    public void test1() throws Exception {
	Controls controls = new Controls(
"//<verbatim>\n"+
"ctrlkeys\n"+
"	\"A\" = \"%redo%\"\n"+
"	\"C\" = \"%copy\"\n"+
"	\"F\" = \"%refind%\"\n"+
"	\"N\" = \"%redo%\"\n"+
"	\"R\" = \"%rereplace%\"\n"+
"	\"U\" = \"%undo%\"\n"+
"	\"V\" = \"%paste\"\n"+
"	\"X\" = \"%cut%\"\n"+
"end\n"+
"top\n"+
"	\"Undo\" = \"%undo%\"\n"+
"	\"Find...\" = \"%find%\"\n"+
"	\"Replace...\" = \"%replace%\"\n"+
"	\"Again\" = \"%redo%\"\n"+
"	\"HTML2Wiki\" = \"%convert%\"\n"+
"end\n"+
"\n"+
"bottom\n"+
"	\"Preview\" = \"%preview%\"\n"+
"	\"Save\" = \"%save%\"\n"+
"end\n"+
"\n"+
"macros\n"+
"	\"action\" = \"%home%%ACTION{who=\\\"\\\" due=\\\"\\\"}% \"\n"+
"end\n"+
"\n"+
"left\n"+
"	\"Bold\" = \"%cut% *%paste%* \"\n"+
"	\"Italic\" = \"%cut% _%paste%_ \"\n"+
"	\"TT\" = \"%cut% =%paste%= \"\n"+
"	\"*...\" = \"%home%   * %cut%\"\n"+
"	\"1...\" = \"%home%   1 %cut%\"\n"+
"	\"Red\" = \"%cut%<font color=red>%paste%</font>\"\n"+
"	\"Action\" = \"%action%\"\n"+
"end\n"+
"\n"+
"macros\n"+
"	\"H\" = \"\\n---\"\n"+
"end\n"+
"\n"+
"right\n"+
"	\"H1\" = \"%cut%%H%+ %paste%\\n\"\n"+
"	\"H2\" = \"%cut%%H%++ %paste%\\n\"\n"+
"	\"H3\" = \"%cut%%H%+++ %paste%\\n\"\n"+
"	\"H4\" = \"%cut%%H%++++ %paste%\\n\"\n"+
"	\"H5\" = \"%cut%%H%+++++ %paste%\\n\"\n"+
"	\"H6\" = \"%cut%%H%++++++ %paste%\\n\"\n"+
"end\n"+
"//</verbatim>\n");
	assertEquals("%home%%ACTION{who=\"\" due=\"\"}% ",
		     controls.getMacro("action"));
	assertEquals("\n---",
		     controls.getMacro("H"));
	assertEquals("%home%%ACTION{who=\"\" due=\"\"}% ",
		     controls.getMacro("action"));
	assertEquals("\n---",
		     controls.getMacro("H"));

	assertEquals("%redo%",
		     controls.getKey("A"));
	assertEquals("%copy",
		     controls.getKey("C"));
	assertEquals("%refind%",
		     controls.getKey("F"));
	assertEquals("%redo%",
		     controls.getKey("N"));
	assertEquals("%rereplace%",
		     controls.getKey("R"));
	assertEquals("%undo%",
		     controls.getKey("U"));
	assertEquals("%paste",
		     controls.getKey("V"));
	assertEquals("%cut%",
		     controls.getKey("X"));
	assertEquals("%undo%",
		     controls.getDefinition("top", "Undo"));

	assertEquals("%find%",
		     controls.getDefinition("top", "Find..."));
	assertEquals("%replace%",
		     controls.getDefinition("top", "Replace..."));
	assertEquals("%redo%",
	 	     controls.getDefinition("top", "Again"));
 	assertEquals("%convert%",
		     controls.getDefinition("top", "HTML2Wiki"));

	assertEquals("%preview%",
		     controls.getDefinition("bottom", "Preview"));
	assertEquals("%save%",
		     controls.getDefinition("bottom", "Save"));

	assertEquals("%cut% *%paste%* ",
		     controls.getDefinition("left", "Bold"));
	assertEquals("%cut% _%paste%_ ",
		     controls.getDefinition("left", "Italic"));
	assertEquals("%cut% =%paste%= ",
		     controls.getDefinition("left", "TT"));
	assertEquals("%home%   * %cut%",
		     controls.getDefinition("left", "*..."));
	assertEquals("%home%   1 %cut%",
		     controls.getDefinition("left", "1..."));
 	assertEquals("%cut%<font color=red>%paste%</font>",
		     controls.getDefinition("left", "Red"));
	assertEquals("%action%",
		     controls.getDefinition("left", "Action"));

	assertEquals("%cut%%H%+ %paste%\n",
		     controls.getDefinition("right", "H1"));
	assertEquals("%cut%%H%++ %paste%\n",
		     controls.getDefinition("right", "H2"));
	assertEquals("%cut%%H%+++ %paste%\n",
		     controls.getDefinition("right", "H3"));
	assertEquals("%cut%%H%++++ %paste%\n",
		     controls.getDefinition("right", "H4"));
	assertEquals("%cut%%H%+++++ %paste%\n",
		     controls.getDefinition("right", "H5"));
	assertEquals("%cut%%H%++++++ %paste%\n",
		     controls.getDefinition("right", "H6"));
    }
}
