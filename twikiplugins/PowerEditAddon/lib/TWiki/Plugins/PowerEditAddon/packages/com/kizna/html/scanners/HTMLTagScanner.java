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
//////////////////
// Java Imports //
//////////////////
import java.io.IOException;

/////////////////////////
// HTML Parser Imports //
/////////////////////////
import com.kizna.html.tags.HTMLTag;
import com.kizna.html.HTMLNode;
import com.kizna.html.HTMLReader;
import com.kizna.html.HTMLStringNode;
/**
 * HTMLTagScanner is an abstract superclass which is subclassed to create specific 
 * scanners, that operate on a tag's strings, identify it, and can extract data from it.
 */
public abstract class HTMLTagScanner
{
	/**
	 * A filter which is used to associate this tag. The filter contains a string
	 * that is used to match which tags are to be allowed to pass through. This can
	 * be useful when one wishes to dynamically filter out all tags except one type
	 * which may be programmed later than the parser. Is also useful for command line
	 * implementations of the parser.
	 */
	protected String filter;
	/**
	 * Default Constructor, automatically registers the scanner into a static array of 
	 * scanners inside HTMLTag
	 */
	public HTMLTagScanner()
	{
		this.filter="";
	}
	/**
	 * This constructor automatically registers the scanner, and sets the filter for this
	 * tag. 
	 * @param filter The filter which will allow this tag to pass through.
	 */
	public HTMLTagScanner(String filter)
	{
		this.filter=filter;
	}
/**
 * Insert the method's description here.
 * Creation date: (6/4/2001 11:44:09 AM)
 * @return java.lang.String
 * @param c char
 */
public String absorb(String s,char c) {
	int index = s.indexOf(c);
	if (index!=-1)	s=s.substring(index+1,s.length());
	return s;
}
/**
 * Insert the method's description here.
 * Creation date: (6/18/2001 2:15:02 AM)
 * @return java.lang.String
 */
public static String absorbLeadingBlanks(String s) 
{
	String temp = new String(s);
	while (temp.charAt(0)==' ')
	{
		temp = temp.substring(1,temp.length());
	}
	return temp;
}
	/**
	 * Template Method, used to decide if this scanner can handle this tag type. If the
	 * evaluation returns true, the calling side makes a call to scan().
	 * @param s The complete text contents of the HTMLTag.
	 * @param previousOpenScanner Indicates any previous scanner which hasnt completed, before the current
	 * scan has begun, and hence allows us to write scanners that can work with dirty html
	 */
	public abstract boolean evaluate(String s,HTMLTagScanner previousOpenScanner);
public static String extractXMLData(HTMLNode node, String tagName, HTMLReader reader) {
	
	String xmlData = "";

	boolean xmlTagFound = isXMLTagFound(node, tagName);
	if (xmlTagFound) {
		try{
			do {
				node = reader.readElement();
				if (node!=null) {
					if (node instanceof HTMLStringNode) {
						HTMLStringNode stringNode = (HTMLStringNode)node;
						if (xmlData.length()>0) xmlData+=" ";
						xmlData += stringNode.getText();
					} else if (!(node instanceof com.kizna.html.tags.HTMLEndTag))
						xmlTagFound = false;
				}
			}
			while (node instanceof HTMLStringNode);
			
		}catch (IOException e) {}
	}
	if (xmlTagFound) {
			if (node!=null) {
				if (node instanceof com.kizna.html.tags.HTMLEndTag) {
					com.kizna.html.tags.HTMLEndTag endTag = (com.kizna.html.tags.HTMLEndTag)node;
					if (!endTag.getContents().equals(tagName)) xmlTagFound = false;		
				}
			
			}

	}
	if (xmlTagFound) return xmlData; else return null;
}
	/**
	 * Get the filter associated with this node.
	 */
	public String getFilter()
	{
		return filter;
	}
/**
 * Insert the method's description here.
 * Creation date: (10/24/2001 6:27:02 PM)
 */
public static boolean isXMLTagFound(HTMLNode node, String tagName) {
	boolean xmlTagFound=false;
	if (node instanceof HTMLTag) {
		HTMLTag tag = (HTMLTag)node;
		if (tag.getText().toUpperCase().indexOf(tagName)==0) {
			xmlTagFound=true;
		}
	}
	return xmlTagFound;
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
	 */
	public abstract HTMLNode scan(HTMLTag tag,String url,HTMLReader reader,String currLine) throws IOException;

	public String removeChars(String s,char occur)  {
		StringBuffer newString = new StringBuffer();
		char ch;
		for (int i=0;i<s.length();i++) {
			ch = s.charAt(i);
			if (ch!=occur) newString.append(ch);
		}
		return newString.toString();
	}

}
