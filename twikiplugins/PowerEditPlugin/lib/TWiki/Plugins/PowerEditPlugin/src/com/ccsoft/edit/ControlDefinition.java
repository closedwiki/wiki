// Copyright (C) Crawford Currie 2004 - All rights reserved
// It is hereby granted that this software can be used, copied, 
// modified, and distributed without fee provided that this 
// copyright notice appears in all copies.
package com.ccsoft.edit;

import java.awt.Toolkit;
import java.awt.image.ImageProducer;
import com.ccsoft.edit.images.StaticImages;
import java.awt.Component;
import java.awt.Image;
import java.awt.Button;
import java.awt.event.ActionListener;
import java.io.IOException;
import java.net.*;

/**
 * A mapping from a string to a string
 */
class ControlDefinition {
    private String key, value, tipster;
    private Image image;
    private Tooltip tip;

    ControlDefinition(String name, String act, String tip) {
	key = name;
	value = act;
	tipster = tip;

	// if we have an image, get it
	image = StaticImages.getImage(key + "_BUTTON");
	if (image == null) {
	    // not a preloaded image
	    try {
		URL url = new URL(key);
		//System.out.println("Downloading " + url);
		ImageProducer nm = (ImageProducer)url.getContent();
		image = Toolkit.getDefaultToolkit().createImage(nm);
	    } catch (MalformedURLException mfe) {
	    } catch (IOException ioe) {
	    }
	}
    }

    String getKey() {
	return key;
    }

    String getValue() {
	return value;
    }

    Component createButton(ActionListener al) {
	Component comp;
	if (image != null) {
	    ImageButton but = new ImageButton(image);
	    but.setActionCommand(value);
	    but.addActionListener(al);
	    comp = but;
	} else {
	    Button but = new Button(key);
	    but.setActionCommand(value);
	    but.addActionListener(al);
	    comp = but;
	}
	if (tipster != null)
	    tip = new Tooltip(tipster, comp);
	return comp;
    }

    public String toString() {
	return " " + key + "=" + value;
    }
}

