// HTMLParser Library v1_2_20020623 - A java-based parser for HTML
// Copyright (C) Dec 31, 2000 Somik Raha
//
// This library is free software; you can redistribute it and/or
// modify it under the terms of the GNU Lesser General Public
// License as published by the Free Software Foundation; either
// version 2.1 of the License, or (at your option) any later version.
//
// This library is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public
// License along with this library; if not, write to the Free Software
// Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
//
// For any questions or suggestions, you can write to me at :
// Email :somik@kizna.com
// 
// Postal Address : 
// Somik Raha
// R&D Team
// Kizna Corporation
// Hiroo ON Bldg. 2F, 5-19-9 Hiroo,
// Shibuya-ku, Tokyo, 
// 150-0012, 
// JAPAN
// Tel  :  +81-3-54752646
// Fax : +81-3-5449-4870
// Website : www.kizna.com

package com.kizna.html.scanners;
/////////////////////////
// HTML Parser Imports //
/////////////////////////
import com.kizna.html.tags.HTMLTag;
import com.kizna.html.HTMLNode;
import com.kizna.html.HTMLReader;
import com.kizna.html.HTMLStringNode;
import com.kizna.html.tags.HTMLEndTag;
import com.kizna.html.tags.HTMLStyleTag;
/**
 * The HTMLStyleScanner scans identifies &lt;style&gt; code
 */

public class HTMLStyleScanner extends HTMLTagScanner {
/**
 * HTMLScriptScanner constructor comment.
 */
public HTMLStyleScanner() {
	super();
}
/**
 * HTMLScriptScanner constructor comment.
 * @param filter java.lang.String
 */
public HTMLStyleScanner(String filter) {
	super(filter);
}
	/**
	 * Template Method, used to decide if this scanner can handle this tag type. If the
	 * evaluation returns true, the calling side makes a call to scan().
	 * @param s The complete text contents of the HTMLTag.
	 * @param previousOpenScanner Indicates any previous scanner which hasnt completed, before the current
	 * scan has begun, and hence allows us to write scanners that can work with dirty html
	 */
public boolean evaluate(String s,HTMLTagScanner previousOpenScanner)
{
	boolean retVal=false;
	// Eat up leading blanks
	s = absorbLeadingBlanks(s);
	// Now, test for the occurence of SCRIPT
	if (s.toUpperCase().indexOf("STYLE")==0) retVal=true;
	return retVal;
}
	/** 
	 * Scan the tag and extract the information related to this type. The url of the 
	 * initiating scan has to be provided in case relative links are found. The initial 
	 * url is then prepended to it to give an absolute link.
	 * The HTMLReader is provided in order to do a lookahead operation. We assume that
	 * the identification has already been performed using the evaluate() method.
	 * @param tag HTML Tag to be scanned for identification
	 * @param url The initiating url of the scan (Where the html page lies)
	 * @param reader The reader object responsible for reading the html page
	 * @param currentLine The current line (automatically provided by HTMLTag)
	 */
public HTMLNode scan(HTMLTag tag, String url, HTMLReader reader,String currentLine) throws java.io.IOException 
{
	// We know we have style stuff. 
	// Parse on till the end tag </style> is found
	String line;
	HTMLEndTag endTag=null;
	HTMLNode node = null;
	boolean endStyleFound=false;
	StringBuffer buff=new StringBuffer();
	
	do {
		node = reader.readElement();
		if (node instanceof HTMLEndTag) {
			endTag = (HTMLEndTag)node;
			if (endTag.getContents().toUpperCase().equals("STYLE")) {
				endStyleFound = true;
			}
		} else buff.append(node.toHTML());
	}
	while (!endStyleFound);
	HTMLStyleTag styleTag = new HTMLStyleTag(tag.elementBegin(),endTag.elementEnd(),buff.toString(),currentLine);
	styleTag.setThisScanner(this);
	return styleTag;
}
}
