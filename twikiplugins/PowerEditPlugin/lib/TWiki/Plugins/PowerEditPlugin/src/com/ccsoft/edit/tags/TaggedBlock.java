package com.ccsoft.edit.tags;

import com.ccsoft.edit.Block;

import com.ccsoft.edit.Interruption;

/**
 * Base class of all tags
 */
abstract class TaggedBlock extends Block {
    String tag;
    TagAttributes attrs = null;
    boolean preformatted;

    protected TaggedBlock() {
	tag = "";
	attrs = null;
	preformatted = false;
    }

    protected TaggedBlock(XMLTokeniser t) {
	tag = t.string;
	attrs = t.attrs;
	preformatted = t.isPreformatted;
    }

    public String getTag() {
	return tag;
    }

    public void setAttributes(TagAttributes a) {
	attrs = a;
    }

    public TagAttributes getAttributes() {
	return attrs;
    }

    /**
     * Parse this tag off the input stream.
     */
    public void parse(XMLTokeniser t) {
	for (;;) {
	    if (Thread.currentThread().interrupted())
		throw new Interruption();
	    int id = t.nextToken();
	    switch (id) {
	    case XMLTokeniser.EOF:
		return;
	    case XMLTokeniser.WORD:
		word(t.string);
		break;
	    case XMLTokeniser.TAG:
		if (t.string.equals("/" + getTag())) {
		    // block terminated
		    return;
		}
		tag(t);
		break;
	    default:
	    }
	}
    }

    public abstract void word(String w);
    public abstract void tag(XMLTokeniser t);

    public String toString() {
	return toHTML();
    }

    public String toHTML() {
	return toHTML("\n");
    }

    public String toHTML(String indent) {
	return '<' + tag + (attrs == null ? "" : attrs.toString()) + '>' +
	    (preformatted ? "<!--PRE-->" : "") + layoutInfo();
    }
}
