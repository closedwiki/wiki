// Copyright (C) 2004 Crawford Currie - All rights reserved
// It is hereby granted that this software can be used, copied, 
// modified, and distributed without fee provided that this 
// copyright notice appears in all copies.
package com.ccsoft.edit;

import java.awt.*;
import java.awt.event.*;
import java.net.*;
import java.io.*;

/**
 * Stand-alone editor
 */
public class StandAlone extends Frame implements Application {
    Editor editor;
    String codeBase;
    Label statusBar;

    StandAlone(String[] args) throws IOException {
	super("Power Edit");
	if (args.length < 1)
	    throw new Error("Need an input file");
	String file = "";
	for (int i = 0; i < args.length; i++) {
	    if (args[i].equals("-exit"))
		DisplayArea.forcedExit = true;
	    else if (args[i].equals("-notml"))
		DisplayArea.tml_default = false;
	    else
		file = args[i];
	}
	setTitle(file);
	String ctext = "";
	BufferedReader r = new BufferedReader(new FileReader("PowerEditControls.txt"));
	for (;;) {
	    String l = r.readLine();
	    if (l == null)
		break;
	    ctext += l + "\n";
	}
	String etext = "";
	r = new BufferedReader(new FileReader(file));
	for (;;) {
	    String l = r.readLine();
	    if (l == null)
		break;
	    etext += l + "\n";
	}
	setLayout(new BorderLayout());
	statusBar = new Label("Editing " + file);
	statusBar.setBackground(Color.white);
	add(statusBar, "South");
	Panel epane = new Panel();
	add(epane, "Center");
	editor = new Editor(ctext, epane, this);
	editor.reset(this, etext, 20, 70);
    }

    /** Implements Application to provide the containing Frame */
    public Frame getFrame() {
	return this;
    }

    public void showStatus(String status) {
	statusBar.setText(status);
    }

    public static void main(String args[]) throws IOException {
	Frame mainFrame = new StandAlone(args);

	mainFrame.setSize(600, 800);

	mainFrame.pack();
        mainFrame.addWindowListener(new WindowAdapter() {
		// required for the X button on the window
		public void windowClosing(WindowEvent e) {
		    System.exit(0);
		}
		// required for dispose()
		public void windowClosed(WindowEvent e) {
		    System.exit(0);
		}
	    });
	mainFrame.show();
    }
}
