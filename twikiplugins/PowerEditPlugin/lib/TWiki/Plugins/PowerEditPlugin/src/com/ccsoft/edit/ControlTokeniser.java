// Copyright (C) Crawford Currie 2001 - All rights reserved
// It is hereby granted that this software can be used, copied, 
// modified, and distributed without fee provided that this 
// copyright notice appears in all copies.
package com.ccsoft.edit;

import java.io.IOException;
import java.io.StreamTokenizer;
import java.io.StringReader;

class ControlTokeniser extends StreamTokenizer {
    class ParseException extends IOException {
	public ParseException(String mess) {
	    super(mess);
	}
    }

    ControlTokeniser(String text) {
	super(new StringReader(text));
	commentChar('<');
	slashStarComments(false);
	slashSlashComments(false);
    }

    void expect(char c) throws IOException {
	if (nextToken() != c)
	    throw new ParseException(
		"Expected '" + c + "' but saw '" + this + "'");
    }

    void expect(String s) throws IOException {
	if (ttype != StreamTokenizer.TT_WORD || !sval.equals(s))
	    throw new ParseException(
		"Expected '" + s + "' but saw '" + this + "'");
    }
}

