// Copyright (C) 2003 Motorola - All rights reserved
// It is hereby granted that this software can be used, copied, 
// modified, and distributed without fee provided that this 
// copyright notice appears in all copies.
package com.ccsoft.edit;

import java.io.IOException;

/**
 * A mapping from a string to a string
 */
class ControlDefinition {
    private String key, value;

    ControlDefinition(String f, String t) {
	key = f;
	value = t;
    }
    
    ControlDefinition(ControlTokeniser st) throws IOException {
	key = st.sval;
	st.expect('=');
	st.expect('"');
	value = st.sval;
    }
    
    String getKey() {
	return key;
    }

    String getValue() {
	return value;
    }
}

