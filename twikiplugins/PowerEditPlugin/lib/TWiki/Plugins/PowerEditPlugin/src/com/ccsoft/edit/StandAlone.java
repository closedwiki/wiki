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
 * Stand-alone editor. Operates from command line, and provides menu items
 * for file loading and saving.
 */
public class StandAlone extends Frame implements Application, ActionListener {
    String codeBase;
    Label statusBar;
    Editor editor;

    StandAlone(String[] args) throws IOException {
	super("Power Edit");
	int opts = 0;
	boolean showSteps = false;
	String controls = "PowerEditControls.txt";

	String file = null;
	for (int i = 0; i < args.length; i++) {
	    if (args[i].equals("-exit"))
		opts |= DisplayArea.FORCE_EXIT;
	    else if (args[i].startsWith("-h"))
		opts |= DisplayArea.HTML_ONLY;
	    else if (args[i].startsWith("-d"))
		showSteps = true;
	    else if (args[i].startsWith("-c"))
		controls = args[++i];
	    else
		file = args[i];
	}
	if (file == null)
	    throw new Error("Need an input file!" + usage());

	Editor.setApplication(this);

	setMenuBar(createMenubar());

	setLayout(new BorderLayout());

	statusBar = new Label("Editing " + file);
	statusBar.setBackground(Color.white);
	add(statusBar, "South");
	Panel epane = new Panel();
	add(epane, "Center");
	String ctext = "";
	BufferedReader r = new BufferedReader(new FileReader(controls));
	for (;;) {
	    String l = r.readLine();
	    if (l == null)
		break;
	    ctext += l + "\n";
	}
	editor = new Editor(ctext, epane, opts);

	if (showSteps) {
	    editor.addProcessListener(new DebugFrame());
	}

	openFile(file);
    }

    private void openFile(String file) throws IOException {
	setTitle(file);
	String etext = "";
	BufferedReader r = new BufferedReader(new FileReader(file));
	for (;;) {
	    String l = r.readLine();
	    if (l == null)
		break;
	    etext += l + "\n";
	}
	editor.reset(etext, 20, 70);
    }

    private void saveFile(String file) throws IOException {
	setTitle(file);
	String conts = editor.getText();
	FileWriter fw = new FileWriter(file);
	fw.write(conts);
	fw.close();
	showStatus(file + " saved");
    }

    /** Implements Application to provide the containing Frame */
    public Frame getFrame() {
	return this;
    }

    /** Implements Application to show status */
    public void showStatus(String status) {
	statusBar.setText(status);
    }

    /** Implements Application to get an image */
    public Image getImage(URL url) {
	return Toolkit.getDefaultToolkit().getImage(url);
    }

    private MenuBar createMenubar() {
	MenuItem open = new MenuItem("Open...");
	open.addActionListener(this);

	MenuItem save = new MenuItem("Save");
	save.addActionListener(this);

	MenuItem saveAs = new MenuItem("Save As...");
	saveAs.addActionListener(this);

	Menu fileMenu = new Menu("File");
	fileMenu.add(open);
	fileMenu.add(save);
	fileMenu.add(saveAs);

	MenuBar mb = new MenuBar();
	mb.add(fileMenu);

	return mb;
    }

    public void actionPerformed(ActionEvent ac) {
	if (ac.getActionCommand().equals("Open..."))
	    doOpen();
	else if (ac.getActionCommand().equals("Save"))
	    doSave();
	else if (ac.getActionCommand().equals("Save As..."))
	    doSaveAs();
    }

    private void doOpen() {
	FileDialog fd = new FileDialog(this, "Open...", FileDialog.LOAD);
	fd.setFile(getTitle());
	fd.show();
	String file = fd.getFile();
	if (file != null) {
	    String dir = fd.getDirectory();
	    if (dir != null)
		file = dir + file;
	    try {
		openFile(file);
	    } catch (IOException ioe) {
		showStatus(ioe.getMessage());
	    }
	}
    }

    private void doSave() {
	try {
	    saveFile(getTitle());
	} catch (IOException ioe) {
	    showStatus(ioe.getMessage());
	}
    }

    private void doSaveAs() {
	FileDialog fd = new FileDialog(this, "Save As...", FileDialog.SAVE);
	fd.setFile(getTitle());
	fd.show();
	String file = fd.getFile();
	if (file != null) {
	    String dir = fd.getDirectory();
	    if (dir != null)
		file = dir + file;
	    try {
		saveFile(file);
	    } catch (IOException ioe) {
		showStatus(ioe.getMessage());
	    }
	}
    }

    private String usage() {
	return "\nParameters: -hdc <file>" +
	    "\n\t-c <file> read controls from <file>"+
	    "\n\t-h interpret files as HTML only (no TML)"+
	    "\n\t-d debug; adds a third window showing XHTML1.0"+
	    "\n\t<file> file to edit";
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
