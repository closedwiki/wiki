// Copyright (C) Crawford Currie 2001 - All rights reserved
// It is hereby granted that this software can be used, copied, 
// modified, and distributed without fee provided that this 
// copyright notice appears in all copies.
package com.ccsoft.edit;

import java.awt.*;
import java.net.URL;

/**
 * Interface to controlling application, either an applet or a java
 * application. Makes a SearchableTextArea independent of it's context.
 */
interface Application {
    /** Get the parent frame for the controlling application. Needed
     * for dialogs. */
    Frame getFrame();
    /** Execute a command reflected from a child */
    void doCommand(String command);
    /** Get the mapping for the key */
    String getKeyCommand(String key);
}
