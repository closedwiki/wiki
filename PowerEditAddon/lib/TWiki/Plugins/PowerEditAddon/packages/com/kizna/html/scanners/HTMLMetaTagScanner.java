/*
 * (c) Copyright 2001 MyCorporation.
 * All Rights Reserved.
 */
package com.kizna.html.scanners;

import java.io.IOException;
import java.util.Hashtable;

import com.kizna.html.HTMLNode;
import com.kizna.html.HTMLReader;
import com.kizna.html.tags.HTMLMetaTag;
import com.kizna.html.tags.HTMLTag;

/**
 * Scans meta tags.
 */
public class HTMLMetaTagScanner extends HTMLTagScanner {
	public HTMLMetaTagScanner(String filter) {
		super(filter);
	}
	/*
	 * @see HTMLTagScanner#evaluate(String)
	 * @param s The complete text contents of the HTMLTag.
	 * @param previousOpenScanner Indicates any previous scanner which hasnt completed, before the current
	 * scan has begun, and hence allows us to write scanners that can work with dirty html
	 */
	public boolean evaluate(String s,HTMLTagScanner previousOpenScanner){
		s = absorbLeadingBlanks(s);
		if (s.toUpperCase().indexOf("META")==0)
		return true; else return false;
	}

	/*
	 * @see HTMLTagScanner#scan(HTMLTag, String, HTMLReader, String)
	 */
	public HTMLNode scan(HTMLTag tag,String url,HTMLReader reader, String currLine)
		throws IOException {
		// Since its a simple tag, all META TAG info will 
		// be in the tag itself
		Hashtable table = tag.parseParameters();
		String metaTagName = (String)table.get("NAME");					
		String metaTagContents = (String)table.get("CONTENT");
		String httpEquiv = (String)table.get("HTTP-EQUIV");
		return new HTMLMetaTag(tag.elementBegin(),tag.elementEnd(),tag.getText(),httpEquiv, metaTagName,metaTagContents,currLine);
	}

}
