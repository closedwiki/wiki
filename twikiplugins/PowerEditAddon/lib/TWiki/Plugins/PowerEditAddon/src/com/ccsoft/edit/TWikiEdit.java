// Copyright (C) Crawford Currie 2001 - All rights reserved
// It is hereby granted that this software can be used, copied, 
// modified, and distributed without fee provided that this 
// copyright notice appears in all copies.
package com.ccsoft.edit;

import java.applet.Applet;

import java.awt.*;
import java.awt.event.*;
import java.net.*;
import java.io.*;
import java.lang.reflect.*;

/**
 * Editor applet using a Frame and a SearchableTextArea, specifically
 * configured for use with TWiki.
 * The applet may be used either in the browser window or in a separate
 * frame, as defined by the applect parameters:
 * <table>
 *
 * <tr><td>Parameter</td><td>Values</td>
 * <td>Description</td></tr>
 *
 * <tr><td>text</td><td>URL-escaped text</td>
 * <td>Text to edit. The text must be escaped for use in a URL</td></tr>
 *
 * <tr><td>useframe</td><td>"yes" or "no"</td>
 * <td>Whether to use a separate window or not</td></tr>
 *
 * <tr><td>editboxwidth</td><td>Number of columns</td>
 * <td>If useframe=yes, then defines the number of columns width of
 * the edit area</td></tr>
 *
 * <tr><td>editboxheight</td><td>Number of rows</td>
 * <td>If useframe=yes, then defines the number of rows height of
 * the edit area</td></tr>
 *
 * <tr><td>server</td><td>URL</td>
 * <td>The URL that the editor will use to pass information back to the
 * server. The edited text is passed back in the form of MIME-form data.
 * </td></tr>
 *
 * <tr><td>top, bottom, left, right</td><td>Each defines the list of
 * buttons for the panel at that location on the applet. Each button
 * panel is defined by a list of | separated strings, each of which is
 * a name=value pair where the name is used as the label on the button,
 * and the value is interpreted as a macro sequence. Macro sequences are
 * either sequences of %% commands (the basic commands of the editor)
 * interleaved with text, or may be simple names of macros provided
 * in other parameters. For example:
 * "Tele type=%cut%=%paste%=|A Space=space"
 * The first button will be labelled "Tele type" and will cut the
 * selected text, then insert an =, paste back the text and then insert
 * another =. The second button will be labelled "A Space" and will
 * execute the macro defined by the applet parameter named "space". A
 * | may be inserted in a definition using ||. It is not possible to
 * insert an = sign in a button name.
 *
 * <td>A list of additional parameter names to be interpreted as macro
 * definitions.</td></tr>
 * <tr><td><i>macro-name</i></td><td>Macro definition</td>
 * <td>Each name in the <tt>macros</tt> list defines the name of
 * a parameter which contains the macro definition. The macro definition
 * consists of text and commands delineated by % signs. A single % sign
 * may be inserted in text as %%. Each macro will be given a button in the
 * second row of buttons.</td></tr>
 *
 * </table>
 */
public class TWikiEdit extends Applet implements Application {

    /** Containing frame */
    static Frame frame = null;
    /** Editing area */
    static SearchableTextArea textarea;
    /** Command (url, actually) used to save the results */
    String server;

    /** MIME form separator */
    static private final String MIME_SEP =
    "---------------------------89692781418184";

    /** Implements Application to provide the containing Frame */
    public Frame getFrame() {
	if (frame == null)
            return new Frame();
        else
            return frame;
    }

    /** Implements Applet initialisation */
    public synchronized void init() {
	server = getParameter("server");

	String text = downloadText();
        boolean framed = getParameter("useframe") != null &&
            getParameter("useframe").equals("yes");

        textarea = new SearchableTextArea();
        if (framed) {
            int r = Integer.parseInt(getParameter("editboxheight"));
            int c = Integer.parseInt(getParameter("editboxwidth"));
            textarea.reset(this, text, r, c);
            if (frame == null) {
                frame = new Frame();
                initControls(frame);
            }
            frame.pack();
            frame.show();
        } else {
            // if we are switching from framed to unframed, kill the
            // cached frame.
            if (frame != null) {
                frame.hide();
                frame = null;
            }
            // reset the textarea to a small size; it will be resized
            // by the layout manager.
            textarea.reset(this, text, 10, 100);
            initControls(this);
        }
    }

    public void stop() {
	if (frame != null) {
            frame.hide();
        }
    }

    public void start() {
	if (frame != null) {
            frame.show();
        }
    }

    public void destroy() {
	if (frame != null) {
            frame.hide();
            frame.dispose();
        }
        super.destroy();
    }

    /**
     * Handle a command reflected from a child
     */
    public void doCommand(String command) {
	try {
	    Method m = getClass().getMethod(command, null);
	    m.invoke(this, null);
	} catch (Exception e) {
	    e.printStackTrace();
	    showStatus("Can't " + command + ": " + e.getMessage());
	    Toolkit.getDefaultToolkit().beep();
	}
    }

    /**
     * Make a button
     */
    private Button makeButton(String name, String cmd) {
        Button but = new Button(name);
        if (cmd != null) {
            but.setActionCommand(cmd);
            but.addActionListener(new ActionListener() {
                    public void actionPerformed(ActionEvent e) {
                        textarea.replayMacro(e.getActionCommand());
                    }
                });
        }
        return but;
    }

    /**
     * Make a command button panel given a descriptor string.
     * Descriptor strings are | separated lists of name=value
     * pairs.
     */
    private Panel makePanel(String desc, int dx, int dy) {
	Panel buttonPanel = new Panel();
	GridBagLayout buttonBag = new GridBagLayout();
	GridBagConstraints buttonBagConstraints = new GridBagConstraints();
	buttonPanel.setLayout(buttonBag);
	String[] buttons = PanelParser.parsePanel(desc);

	for (int i = 0; i < buttons.length; ) {
	    String name = buttons[i++];
	    String def = buttons[i++];

	    // Look up to see if there's a param defining
	    // the def
	    String macro = getParameter(def);
	    if (macro == null)
		macro = def;

	    Button button = makeButton(name, macro);
	    buttonBagConstraints.gridx += dx;
	    buttonBagConstraints.gridy += dy;
	    buttonBag.setConstraints(button, buttonBagConstraints);
	    buttonPanel.add(button);
	}
	return buttonPanel;
    }

    private void addPanel(Container container, GridBagLayout layout,
			     String name,
			     int dx, int dy,
			     int gx, int gy) {
        String def = getParameter(name);
        if (def == null)
	    return;

	Panel buttonPanel = makePanel(def, dx, dy);
	GridBagConstraints gbc = new GridBagConstraints();
	gbc.gridx = gx;
	gbc.gridy = gy;
	gbc.anchor = dx > 0 ?
	    GridBagConstraints.WEST :
	    GridBagConstraints.NORTH;
	layout.setConstraints(buttonPanel, gbc);
	container.add(buttonPanel);
    }

    /** Initialise controls for an in-browser applet */
    private void initControls(Container container) {
        GridBagLayout layout = new GridBagLayout();
        container.setLayout(layout);

	addPanel(container, layout, "top_buttons", 1, 0, 1, 0);
	addPanel(container, layout, "bottom_buttons", 1, 0, 1, 2);
	addPanel(container, layout, "left_buttons", 0, 1, 0, 1);
	addPanel(container, layout, "right_buttons", 0, 1, 2, 1);

        GridBagConstraints gbc = new GridBagConstraints();
	gbc.gridx = 1;
        gbc.gridy = 1;
        gbc.fill = GridBagConstraints.BOTH;
        gbc.weightx = 1.0;
        gbc.weighty = 1.0;
        layout.setConstraints(textarea, gbc);
        container.add(textarea);
    }

    /** Download the text from the given server url */
    private String downloadText() {
	String replyString = "";
	// a url of "debug" means run in appletviewer mode and
	// don't try to talk to the server
	if (!server.startsWith("debug")) {
	    URL url;
	    try {
		url = new URL(getCodeBase(),
				  server + "?action=get");
	    } catch (MalformedURLException mue) {
		return mue.toString();
	    }

	    System.out.println("get: " + url);

	    try {
		InputStream ins = url.openStream();

		BufferedReader in =
		    new BufferedReader(new InputStreamReader(ins));
		String reply = null;
		do {
		    reply = in.readLine();
		    if (reply != null) {
			replyString += reply + "\n";
		    }
		} while (reply != null);
	    } catch (IOException ioe) {
		return ioe.toString();
	    }

	    if ( replyString.startsWith("OK"))
		replyString = replyString.substring(2);

	} else {
	    replyString = server.substring(5);
	}

	return replyString;
    }

    /** Command action on save. This command is reflected
     * from the textarea. */
    public void save() {
	try {
	    String text = textarea.getText();
	    String serverCmd = server + "?action=put";
	    System.out.println("put: " + serverCmd);
	    String reply = post(serverCmd, text);
	    // read the reply, which should be a URL
	    try {
		System.out.println("redirect:" + reply);
                URL url = new URL(getCodeBase(), reply);
                getAppletContext().showDocument(url);
            } catch (MalformedURLException murle) {
            }
	} catch (MalformedURLException mue) {
            mue.printStackTrace();
	    showStatus("Bad url: " + mue.getMessage());
	} catch (IOException ioe) {
            ioe.printStackTrace();
	    showStatus("Save failed: " + ioe.getMessage());
	}
    }

    /**
     * Submits POST command to the server, and reads the reply.
     */
    public String post(String url, String content)
	throws MalformedURLException, IOException {

	String message =
	    "--" + MIME_SEP + "\r\n" 
	    // shouldn't need this, as the url has ?action=put
            + "Content-Disposition: form-data; "
            + "name=\"action\"\r\n\r\nput\r\n"
	    + "--" + MIME_SEP + "\r\n"
            + "Content-Disposition: form-data; "
            + "name=\"text\"\r\n"
            + "Content-Type: text/plain\r\n\r\n"
            + content + "\r\n"
	    + "--" + MIME_SEP + "--\r\n";

	if (server.equals("debug")) {
	    System.out.println(message);
	    return "no_response";
	}

        URL server = new URL(
	    getCodeBase().getProtocol(),
	    getCodeBase().getHost(),
	    getCodeBase().getPort(),
	    url);
        URLConnection connection = server.openConnection();

        connection.setAllowUserInteraction(true);
        connection.setDoOutput(true);
        connection.setDoInput(true);
        connection.setUseCaches(false);

        connection.setRequestProperty(
	    "Content-type",
	    "multipart/form-data; boundary=" + MIME_SEP);
        connection.setRequestProperty(
	    "Content-length",
	    Integer.toString(message.length()));

        DataOutputStream out =
	    new DataOutputStream(connection.getOutputStream());
        out.writeBytes(message);
        out.close();

	String replyString = "";
	try {
	    BufferedReader in =
		new BufferedReader(new InputStreamReader(
		    connection.getInputStream()));
	    String reply = null;
	    do {
		reply = in.readLine();
		if (reply != null) {
		    replyString += reply;
		}
	    } while (reply != null);
	    in.close();
	} catch (IOException ioe) {
	    replyString = ioe.toString();
	}
	return replyString;
    }
}
