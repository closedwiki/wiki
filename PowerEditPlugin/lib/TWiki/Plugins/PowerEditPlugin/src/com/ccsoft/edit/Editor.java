// Copyright (C) 2004 Crawford Currie - All rights reserved
// It is hereby granted that this software can be used, copied, 
// modified, and distributed without fee provided that this 
// copyright notice appears in all copies.
package com.ccsoft.edit;

import java.awt.*;
import java.awt.event.*;
import java.io.*;

/**
 * Editor realises pattern Decorator. It is the framework of an editor that
 * can be imposed on a container, such as a Frame or an Applet, without
 * having to subclass the container.
 * <p>
 * The editor consists of a text area used for editing, a display area,
 * and four controls panels that contain buttons, arranged around the
 * periphery of the two main areas.
 */
class Editor {

    /** Editing area */
    SearchableTextArea textArea;
    /** Display area */
    DisplayArea displayArea;
    /** Edit controls */
    Controls controls;
    /** Listener for control actions */
    ActionListener actionListener;

    /** Singleton application instance reference */
    private static Application app;

    /** Get the singleton Application instance */
    public static Application getApplication() {
	return app;
    }

    public static void setApplication(Application a) {
	app = a;
    }

    public void addProcessListener(DisplayArea.ProcessListener prl) {
	displayArea.addProcessListener(prl);
    }

    /**
     * Once an editor has been created it must be reset to give
     * it text and application
     */
    public Editor(String controlsText, Container container, int daopts)
	throws IOException {

	if (app == null)
	    throw new Error("ASSERT");

	// create the HTML display area
	displayArea = new DisplayArea(daopts);

	// listener to get the text area reformatted when the container
	// is resized. Inner classes?
	container.addComponentListener(new ComponentAdapter() {
		public void componentResized(ComponentEvent ce) {
		    displayArea.areaChanged();
		}
	    });

	controls = new Controls(controlsText);

	// create the editing area
        textArea = new SearchableTextArea(controls);
	actionListener =
	    new ActionListener() {
		    public void actionPerformed(ActionEvent e) {
			textArea.replayMacro(e.getActionCommand());
		    }
		};

	// the display area has to listen for text changes in the
	// edited text
	textArea.addTextListener(displayArea);

	makeStandardLayout(container, actionListener);
    }

    public String getText() {
	return textArea.getText();
    }

    public void reset(String text, int r, int c) {
	textArea.reset(app, text, r, c);
    }

    /**
     * Create the standard layout of components in the container.
     * <pre><code>
     * +---------------------------------------------+
     * |                                             |
     * |               Display Area                  |
     * |                                             |
     * +---+-------------------------------------+---+
     * |   |               top                   |   |
     * +---+-------------------------------------+---+
     * | l |                                     | r |
     * | e |                                     | i |
     * | f |            Text Area                | g |
     * | t |                                     | h |
     * |   |                                     | t |
     * +---+-------------------------------------+---+
     * |   |              bottom                 |   |
     * +---+-------------------------------------+---+
     *
     */
    void makeStandardLayout(Container frame, ActionListener al) {

        frame.setLayout(new GridLayout(2, 1));

	ScrollPane DA = new ScrollPane(ScrollPane.SCROLLBARS_AS_NEEDED);
	DA.add(displayArea);
	frame.add(DA);

	Panel TA = new Panel();
	TA.setLayout(new BorderLayout());
	frame.add(TA);

	TA.add(textArea, "Center");

	ControlBlock b = controls.getBlock("top");
	if (b != null) {
	    Panel TOP = b.makePanel(new HorizontalControlLayout(), al);
	    TA.add(TOP, "North");
	}

	b = controls.getBlock("left");
	if (b != null) {
	    Panel LEFT = b.makePanel(new VerticalControlLayout(), al);
	    TA.add(LEFT, "West");
	}

	b = controls.getBlock("right");
	if (b != null) {
	    Panel RIGHT = b.makePanel(new VerticalControlLayout(), al);
	    TA.add(RIGHT, "East");
	}

	b = controls.getBlock("bottom");
	if (b != null) {
	    Panel BOTTOM = b.makePanel(new HorizontalControlLayout(), al);
	    TA.add(BOTTOM, "South");
	}
    }
}
