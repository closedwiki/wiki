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
 * </table>
 */
public class TWikiEdit extends Applet implements Application {

    /** Containing frame */
    static Frame frame = null;
    /** Editing area */
    static SearchableTextArea textarea;
    /** Command (url, actually) used to save the results */
    String server;
    /** Edit controls */
    Controls controls;

    /** MIME form separator */
    static private final String MIME_SEP =
    "---------------------------89692781418184";
    static private String NL = "\r\n";
    static private final String END_MESSAGE =
    "--" + MIME_SEP + "--" + NL;

    /** Implements Application to provide the containing Frame */
    public Frame getFrame() {
	if (frame == null)
            return new Frame();
        else
            return frame;
    }

    /** Implements Application to look up keystrokes */
    public String getKeyCommand(String kc) {
	return controls.getKey(kc);
    }

    /** Implements Applet initialisation */
    public synchronized void init() {
	server = getParameter("server");

        boolean framed = getParameter("useframe") != null &&
            getParameter("useframe").equals("yes");

        textarea = new SearchableTextArea();
	String text = download("get");
	controls = new Controls(download("controls"));
	ActionListener actionListener =
	    new ActionListener() {
		    public void actionPerformed(ActionEvent e) {
			textarea.replayMacro(e.getActionCommand());
		    }
		};

        if (framed) {
            int r = Integer.parseInt(getParameter("editboxheight"));
            int c = Integer.parseInt(getParameter("editboxwidth"));
            textarea.reset(this, text, r, c);
            if (frame == null) {
                frame = new Frame();
		controls.makeStandardLayout(frame, textarea, actionListener);
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
	    controls.makeStandardLayout(this, textarea, actionListener);
        }

        boolean dontNotify = getParameter("dontNotify") != null &&
            getParameter("dontNotify").equals("checked");
        boolean releaseEditLock = getParameter("releaseEditLock") != null &&
            getParameter("releaseEditLock").equals("checked");
	controls.setDefaultControls(dontNotify, releaseEditLock);
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
	String macro = controls.getMacro(command);
	if (macro != null) {
	    textarea.replayMacro(macro);
	    return;
	}
	try {
	    Method m = getClass().getMethod(command, null);
	    m.invoke(this, null);
	} catch (Exception e) {
	    e.printStackTrace();
	    showStatus("Can't " + command + ": " + e.getMessage());
	    Toolkit.getDefaultToolkit().beep();
	}
    }

    /** Download text from the server, using the given command. */
    private String download(String command) {
	String reply = "";
	// a url of "debug" means run in appletviewer mode and
	// don't try to talk to the server
	if (!server.startsWith("debug")) {
	    reply = post(server, formParameter("action", command));
	    if (reply.startsWith("OK")) {
		return reply.substring(2);
	    } else {
		showStatus(reply);
		return "ERROR during get?action=" + command + " -> " + reply;
	    }
	} else {
	    reply = server.substring(5);
	}

	return reply;
    }

    /**
     * Command action on save. This command is reflected
     * from the textarea.
     * Save the modified text.
     */
    public void save() {
	if (textarea.isModified()) {
	    String sp = "&unlock=" + (controls.getReleaseLock() ? 1 : 0) +
		"&dontnotify=" + (controls.getDontNotify() ? 1 : 0);
	    String text = textarea.getText();
	    String reply = post(server,	    
				formParameter("action", "put") +
				formParameter("text", text));
	    if (reply.startsWith("OK")) {
		reply = reply.substring(2) + "?action=commit" + sp;
		try {
		    URL url = new URL(getCodeBase(), reply);
		    getAppletContext().showDocument(url);
		    // never returns because we've navigated away from
		    // this page
		} catch (MalformedURLException mue) {
		    showStatus("ERROR Bad url: " + mue.getMessage());
		}
	    } else {
		showStatus(reply);
	    }
	} else {
	    showStatus("No changes to save");
	}
    }

    /**
     * Command action on preview. This command is reflected
     * from the textarea.
     * Preview the edited text in a new window.
     */
    public void preview() {
	String text = textarea.getText();
	String reply = post(server,	    
			    formParameter("action", "put") +
			    formParameter("text", text));
	if (reply.startsWith("OK")) {
	    reply = reply.substring(2) + "?action=preview";
	    try {
		URL url = new URL(getCodeBase(), reply);
		getAppletContext().showDocument(url, "_blank");
	    } catch (MalformedURLException mue) {
		showStatus("ERROR Bad url: " + mue.getMessage());
	    }
	} else {
	    showStatus("ERROR: " + reply);
	}
    }

    private String formParameter(String name, String value) {
	return "--" + MIME_SEP + NL +
            "Content-Disposition: form-data; name=\"" +
	    name +
	    "\"" + NL + "Content-Type: text/plain" + NL + NL +
	    value +
	    NL;
    }

    /**
     * Submits POST command to the server, and reads the reply.
     * If everything works it will return OK+the reply, otherwise
     * it will return ERROR+the error message.
     */
    public String post(String url, String message) {

	message += END_MESSAGE;

	if (server.equals("debug")) {
	    System.out.println(message);
	    return "OKno_response";
	}

	try {
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

	    StringBuffer replyBuffer = new StringBuffer();
	    BufferedReader in =
		new BufferedReader(new InputStreamReader(
		    connection.getInputStream()));
	    String reply = null;
	    do {
		reply = in.readLine();
		if (reply != null) {
		    replyBuffer.append(reply);
		    replyBuffer.append('\n');
		}
	    } while (reply != null);
	    in.close();
	    return replyBuffer.toString().trim();
	} catch (MalformedURLException mue) {
	    return "ERROR Bad url: " + mue.getMessage();
	} catch (IOException ioe) {
	    return "ERROR " + ioe.getMessage();
	}
    }
}
