package com.ccsoft.edit;

import java.awt.*;
import java.awt.event.*;
import java.io.*;

/**
 * Not part of the automated test suite, this class implements visual
 * tests for HTML4 rendering
 */
public class HTML4Tests extends Frame implements ActionListener {

    DisplayArea displayArea;
    int currFile;
    String[] files;
    String subdir;

    HTML4Tests(String s) {
	subdir = s;

	setLayout(new BorderLayout());
	displayArea = new DisplayArea();
	addComponentListener(new ComponentAdapter() {
		public void componentResized(ComponentEvent ce) {
		    displayArea.areaChanged();
		}
	    });
	
	ScrollPane dsp = new ScrollPane(ScrollPane.SCROLLBARS_AS_NEEDED);
	dsp.add(displayArea);
	add(dsp, "Center");
	Button nextb = new Button("Next");
	nextb.addActionListener(this);
	add(nextb, "South");
	Button prevb = new Button("Prev");
	prevb.addActionListener(this);
	add(prevb, "North");

	files = new File(subdir).list(new FilenameFilter() {
		public boolean accept(File f, String n) {
		    return(n.endsWith("xml") || n.endsWith("html"));
		}});

	testFile(currFile = 0);
    }

    public void actionPerformed(ActionEvent e) {
	if (e.getActionCommand().equals("Next")) {
	    currFile = (currFile + 1) % files.length;
	    testFile(currFile);
	} else if (e.getActionCommand().equals("Prev")) {
	    if (currFile == 0)
		currFile = files.length;
	    --currFile;
	    testFile(currFile);
	}
    }

    void testFile(int file) {
	try {
	    File f = new File(subdir + "/" + files[file]);
	    Reader fr = new FileReader(f);
	    System.out.println("Reading " + f);
	    setTitle("Test " + f);
	    String text = "";
	    int c;
	    while ((c = fr.read()) != -1) {
		text += (char)c;
	    }
	    fr.close();
	    int start = text.indexOf("<body");
	    if (start < 0)
		start = text.indexOf("<BODY");
	    if (start >= 0) {
		start = text.indexOf(">", start) + 1;
		text = text.substring(start);
	    }
	    System.out.println("Processing " + text);
	    displayArea.setText(text);
	} catch (IOException ioe) {
	    ioe.printStackTrace();
	}
    }

    public static void main(String[] args) {
	DisplayArea.tml_default = false;
	Frame frame = new HTML4Tests(args[0]);
	frame.pack();
	frame.setSize(600, 400);
	frame.show();
    }
}
