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
import java.io.IOException;
import java.net.URL;
import java.util.Hashtable;
import java.util.Enumeration;
import java.util.Vector;
/////////////////////////
// HTML Parser Imports //
/////////////////////////
import com.kizna.html.*;
import com.kizna.html.tags.HTMLTag;
import com.kizna.html.tags.HTMLEndTag;
import com.kizna.html.tags.HTMLAppletTag;
/**
 * Used to scan for applet tags.
 */
public class HTMLAppletScanner extends HTMLTagScanner {
	private java.lang.String className;
	private java.lang.String archive;
	private java.lang.String codebase;
/**
 * HTMLAppletScanner constructor comment.
 */
public HTMLAppletScanner() {
	super();
}
/**
 * HTMLAppletScanner constructor comment.
 * @param filter java.lang.String
 */
public HTMLAppletScanner(String filter) {
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
	// Eat up leading blanks
	s = absorbLeadingBlanks(s);
		
	if (s.toUpperCase().indexOf("APPLET")==0)
	return true;
	else return false;
}
/**
 * Insert the method's description here.
 * Creation date: (6/18/2001 2:31:42 AM)
 * @param text java.lang.String
 */
public void extractFields(HTMLTag tag) 
{
    className = tag.getParameter("CODE");
    archive = tag.getParameter("ARCHIVE");
    codebase = tag.getParameter("CODEBASE");
}
/**
 * Insert the method's description here.
 * Creation date: (6/18/2001 2:34:38 AM)
 * @return java.lang.String
 */
public java.lang.String getArchive() {
	return archive;
}
/**
 * Insert the method's description here.
 * Creation date: (6/18/2001 2:33:08 AM)
 * @return java.lang.String
 */
public java.lang.String getClassName() {
	return className;
}
/**
 * Insert the method's description here.
 * Creation date: (6/18/2001 2:34:53 AM)
 * @return java.lang.String
 */
public java.lang.String getCodebase() {
	return codebase;
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
public com.kizna.html.HTMLNode scan(HTMLTag tag, String url, com.kizna.html.HTMLReader reader, String currLine) throws java.io.IOException 
{
	String tagContents = tag.getText();
	// From the tagContents, get the class name, archive, codebase
	extractFields(tag);

	String line;
	HTMLEndTag endTag=null;
	HTMLNode node = null;
	boolean endScriptFound=false;
	Vector buff=new Vector();
	Vector misc=new Vector();
	Hashtable table = new Hashtable();

	do {
		node = reader.readElement();
		if (node instanceof HTMLEndTag) {
			endTag = (HTMLEndTag)node;
			if (endTag.getContents().toUpperCase().equals("APPLET")) 
			{
				endScriptFound = true; 
			}
		}
		else if (node instanceof HTMLTag) {
			HTMLTag htag = (HTMLTag)node;
			String paramName = htag.getParameter("NAME");
			if (paramName!=null && paramName.length()!=0)
			{
				String paramValue = htag.getParameter("VALUE");
				table.put(paramName,paramValue);
			}
			else
			{
				misc.addElement(htag);
			}
		}
	}
	while (!endScriptFound);
	
	HTMLAppletTag appTag = new HTMLAppletTag(node.elementBegin(),node.elementEnd(),tag.getText(),currLine,className,archive,codebase,table,misc);
	appTag.setThisScanner(this);
	return appTag;
}
/**
 * Insert the method's description here.
 * Creation date: (6/18/2001 2:34:38 AM)
 * @param newArchive java.lang.String
 */
public void setArchive(java.lang.String newArchive) {
	archive = newArchive;
}
/**
 * Insert the method's description here.
 * Creation date: (6/18/2001 2:33:08 AM)
 * @param newClassName java.lang.String
 */
public void setClassName(java.lang.String newClassName) {
	className = newClassName;
}
/**
 * Insert the method's description here.
 * Creation date: (6/18/2001 2:34:53 AM)
 * @param newCodebase java.lang.String
 */
public void setCodebase(java.lang.String newCodebase) {
	codebase = newCodebase;
}
}
