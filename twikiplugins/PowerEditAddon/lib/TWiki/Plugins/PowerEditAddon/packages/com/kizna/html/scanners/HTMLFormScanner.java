// HTMLParser Library v1.03 - A java-based parser for HTML
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
// 2-1-17-6F, Sakamoto Bldg., Moto Azabu, Minato ku, Tokyo, 106 0046, JAPAN
package com.kizna.html.scanners;

//////////////////
// Java Imports //
//////////////////
import java.util.Enumeration;
import java.util.Vector;
import java.util.StringTokenizer;
import java.io.IOException;
import java.util.Hashtable;
import java.util.HashMap;

/////////////////////////
// HTML Parser Imports //
/////////////////////////
import com.kizna.html.tags.HTMLTag;
import com.kizna.html.HTMLNode;
import com.kizna.html.HTMLStringNode;
import com.kizna.html.HTMLRemarkNode;
import com.kizna.html.HTMLReader;
import com.kizna.html.HTMLParser;
import com.kizna.html.tags.HTMLEndTag;
import com.kizna.html.tags.HTMLImageTag;
import com.kizna.html.util.HTMLLinkProcessor;
import com.kizna.html.tags.HTMLFormTag;

/**
 * Scans for the Image Tag. This is a subclass of HTMLTagScanner, and is called using a
 * variant of the template method. If the evaluate() method returns true, that means the
 * given string contains an image tag. Extraction is done by the scan method thereafter
 * by the user of this class.
 */
public class HTMLFormScanner extends HTMLTagScanner
{
 
	/**
	 * Overriding the constructor to accept the filter
	 */
	public HTMLFormScanner(String filter)
	{
		super(filter);
	}
	/**
	 * Template Method, used to decide if this scanner can handle the Image tag type. If
	 * the evaluation returns true, the calling side makes a call to scan().
	 * @param s The complete text contents of the HTMLTag.
	 */
	public boolean evaluate(String s, HTMLTagScanner previousOpenScanner)
	{
		// Eat up leading blanks
		s = absorbLeadingBlanks(s);
		if (s.toUpperCase().indexOf("FORM")==0)
		return true; else return false;		
	}
  /**
   * Extract the location of the image, given the string to be parsed, and the url
   * of the html page in which this tag exists.
   * @param s String to be parsed
   * @param url URL of web page being parsed
   */
	public String extractFormLocn(HTMLTag tag,String url)
	{
		String formURL= tag.getParameter("ACTION");
		if (formURL==null) return ""; else
		return (new HTMLLinkProcessor()).extract(formURL, url);
	}

	public String extractFormName(HTMLTag tag)
	{
		return tag.getParameter("NAME");
	}

	public String extractFormMethod(HTMLTag tag)
	{
		String method = tag.getParameter("METHOD");
		if (method==null) method = "GET";
		return method;

	}

	/**
	 * Scan the tag and extract the information related to the <IMG> tag. The url of the
	 * initiating scan has to be provided in case relative links are found. The initial
	 * url is then prepended to it to give an absolute link.
	 * The HTMLReader is provided in order to do a lookahead operation. We assume that
	 * the identification has already been performed using the evaluate() method.
	 * @param tag HTML Tag to be scanned for identification
	 * @param url The initiating url of the scan (Where the html page lies)
	 * @param reader The reader object responsible for reading the html page
	 * @param currentLine The current line (automatically provided by HTMLTag)
	 */
	public HTMLNode scan(HTMLTag tag,String url,HTMLReader reader,String currentLine) throws IOException
	{
		HTMLNode node;
      	Vector inputVector = new Vector(), nodeVector = new Vector();
		String link,name="",method="GET";
		int linkBegin=-1, linkEnd=-1;

		link = extractFormLocn(tag,url);
    	name = extractFormName(tag);
	    method = extractFormMethod(tag);
		linkBegin = tag.elementBegin();
	    boolean endFlag = false;
		nodeVector.addElement(tag);
	    do
		{
			node = reader.readElement();
			if (node instanceof HTMLEndTag)
			{
				HTMLEndTag endTag = (HTMLEndTag)node;
				if (endTag.getContents().toUpperCase().equals("FORM")) {
					endFlag=true;
					linkEnd = endTag.elementEnd();
				}
			}
			else 
			if (node instanceof HTMLTag) {
				HTMLTag thisTag=(HTMLTag)node;
				if (thisTag.getText().toUpperCase().indexOf("INPUT")==0)
				inputVector.addElement(thisTag);
			}
			nodeVector.addElement(node);
		}
		while (endFlag==false);
		HTMLFormTag formTag = new HTMLFormTag(link,name,method,linkBegin,linkEnd,currentLine,inputVector,nodeVector);
        formTag.setThisScanner(this);
		return formTag;
	}

}
