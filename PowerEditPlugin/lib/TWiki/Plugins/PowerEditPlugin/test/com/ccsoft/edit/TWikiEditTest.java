package com.ccsoft.edit;

import java.applet.*;
import java.awt.*;
import java.net.*;
import java.util.Enumeration;
import junit.framework.*;
import netscape.javascript.JSObject;
import java.io.*;

public class TWikiEditTest extends TestCase {

    private class AContext implements AppletContext {
	public Applet getApplet(String name) {
	    return null;
	}
	public Enumeration getApplets() {
	    return null;
	}
	public AudioClip getAudioClip(URL url) {
	    return null;
	}
	public Image getImage(URL url) {
	    return null;
	}
        public void showDocument(URL url) {
	}
        public void showDocument(URL url, String target) {
	}
        public void showStatus(String status) {
	}
    }

    private class AStub implements AppletStub {
	public void appletResize(int width, int height) {
	}

	public AppletContext getAppletContext() {
	    return new AContext();
	}

	public URL getCodeBase() {
	    return null;
	}

	public URL getDocumentBase() {
	    return null;
	}

        public String getParameter(String name) {
	    if (name.equals("server"))
		return "debug";
	    else if (name.equals("editboxwidth"))
		return "60";
	    else if (name.equals("editboxheight"))
		return "15";
	    else if (name.equals("top_buttons"))
		return "Undo=%undo%|Find...=%find%|Replace...=%replace%|Again=%redo%";
	    else if (name.equals("bottom_buttons"))
		return "Preview Changes=%save%";
	    else if (name.equals("left_buttons"))
		return "B=bold|I=italic|TT=tt|LI=li|Red=red";
	    else if (name.equals("bold"))
		return "%cut%*%paste%*";
	    else if (name.equals("italic"))
		return "%cut%_%paste%_";
	    else if (name.equals("tt"))
		return "%cut%=%paste%=";
	    else if (name.equals("red"))
		return "%cut%<font color=red>%paste%</font>";
	    else if (name.equals("li"))
		return "%home%   * %cut%";
	    else if (name.equals("right_buttons"))
		return "H1=%cut%<H1>%paste%</H1>|H2=%cut%<H2>%paste%</H2>|H3=%cut%<H3>%paste%</H3>|H4=%cut%<H4>%paste%</H4>|H5=%cut%<H5>%paste%</H5>|H6=%cut%<H6>%paste%</H6>|";
	    return null;
	}

	public boolean isActive() {
	    return true;
	}
    }

    public TWikiEditTest(String name) {
	super(name);
    }

    public static Test suite() {
	return new TestSuite(TWikiEditTest.class);
    }

    public void setUp() throws Exception {
	File f = new File("PowerEditPlugin.txt");
	Reader fr = new FileReader(f.getAbsolutePath());
	int c;
	String str = "";
	while ((c = fr.read()) != -1) {
	    if (c == '\n')
		str += '\r';
	    str += (char)c;
	}
	fr.close();
	JSObject text = new JSObject();
	text.put("value", str);

	f = new File("PowerEditControls.txt");
	fr = new FileReader(f.getAbsolutePath());
	str = "";
	while ((c = fr.read()) != -1) {
	    if (c == '\n')
		str += '\r';
	    str += (char)c;
	}
	fr.close();
	JSObject controls = new JSObject();
	controls.put("value", str);

	JSObject main = new JSObject();
	main.put("text", text);
	main.put("controls", controls);

	JSObject document = new JSObject();
	document.put("main", main);

	JSObject window = new JSObject();
	window.put("document", document);
	JSObject.setWindow(window);
    }

    public void test1() {
	TWikiEdit a = new TWikiEdit();
	a.setStub(new AStub());
	a.init();
	a.start();
	a.destroy();
    }
}
