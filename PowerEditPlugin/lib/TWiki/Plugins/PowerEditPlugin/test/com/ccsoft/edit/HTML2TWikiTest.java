package com.ccsoft.edit;

import java.net.*;
import java.util.Enumeration;
import junit.framework.*;
import java.io.*;
import com.kizna.html.*;
import java.util.Vector;

public class HTML2TWikiTest extends TestCase {

    public HTML2TWikiTest(String name) {
	super(name);
    }

    public static Test suite() {
	return new TestSuite(HTML2TWikiTest.class);
    }

    Vector thingsToProcess;
    Vector thingsProcessed;

    private void addLink(String link) {
	if (link.startsWith("http://localhost") &&
	    !link.endsWith("/./") &&
	    !thingsToProcess.contains(link) &&
	    !thingsProcessed.contains(link)) {
	    
	    thingsToProcess.add(link);
	}
    }

    public void testHTMLConversion() {
	thingsToProcess = new Vector();
	thingsProcessed = new Vector();
	//thingsToProcess.add("http://localhost");
	thingsToProcess.add("http://Anthea/twiki/bin/view");
	PrintWriter pw = new PrintWriter(new Writer() {
		public void close() {
		}
		public void flush() {
		}
		public void write(char[] cbuf, int off, int len) {
		}
	    });
	
	HTML2TWiki.LinkCallback cb = new HTML2TWiki.LinkCallback() {
		public void processLink(String link) {
		    addLink(link);
		}
	    };
	HTML2TWiki conv = new HTML2TWiki(cb);

	while (thingsToProcess.size() > 0) {
	    String thing = (String)thingsToProcess.lastElement();
	    System.out.println("Processing " + thing);
	    thingsToProcess.remove(thingsToProcess.size() - 1);

	    HTMLParser parser = new HTMLParser(thing);

	    try {
		conv.process(parser, pw);
	    } catch (Error e) {
		System.err.println("WHILE PROCESSING " + thing);
		throw e;
	    }

	    thingsProcessed.add(thing);
	}
	thingsToProcess = null;
	thingsProcessed = null;
    }
}

