package com.ccsoft.edit;

import java.applet.*;
import java.awt.*;
import java.net.*;
import java.util.Enumeration;
import junit.framework.*;
import netscape.javascript.JSObject;
import java.io.*;
import java.util.Hashtable;

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

    private class AStub extends Hashtable implements AppletStub {
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
	    return (String)get(name);
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

    private static AStub appletStub = null;

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

	appletStub = new AStub();
	appletStub.put("editboxwidth", "60");
	appletStub.put("editboxheight", "15");
	appletStub.put("useframe", "no");
    }

    public void test1_JS_JS() {
	TWikiEdit a = new TWikiEdit();
	appletStub.put("controls", "document.main.controls.value");
	appletStub.put("text", "document.main.text.value");
	a.setStub(appletStub);
	a.init();
	a.start();
	a.destroy();
    }

    public void test2_JS_URL() {
	TWikiEdit a = new TWikiEdit();
	appletStub.put("controls", "document.main.controls.value");
	appletStub.put("text", "http://localhost");
	a.setStub(appletStub);
	a.init();
	a.start();
	a.destroy();
    }

    public void test2_JS_INLINE() {
	TWikiEdit a = new TWikiEdit();
	appletStub.put("controls", "document.main.controls.value");
	appletStub.put("text", "Chirpy Chirpy Cheep Cheep");
	a.setStub(appletStub);
	a.init();
	a.start();
	a.destroy();
    }
}
