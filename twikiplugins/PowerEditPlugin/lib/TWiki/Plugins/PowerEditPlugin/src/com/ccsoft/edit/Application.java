// Copyright (C) Crawford Currie 2001 - All rights reserved
// It is hereby granted that this software can be used, copied, 
// modified, and distributed without fee provided that this 
// copyright notice appears in all copies.
package com.ccsoft.edit;

import java.awt.Frame;
import java.awt.Image;
import java.awt.event.KeyEvent;
import java.net.URL;

/**
 * Interface to controlling application, either an applet or a java
 * application. Makes a SearchableTextArea independent of it's context.
 */
interface Application {
    /** Get the parent frame for the controlling application. Needed
     * for dialogs. */
    Frame getFrame();
    /** Do whatever you do to show the status */
    void showStatus(String s);
    Image getImage(URL url);
}
