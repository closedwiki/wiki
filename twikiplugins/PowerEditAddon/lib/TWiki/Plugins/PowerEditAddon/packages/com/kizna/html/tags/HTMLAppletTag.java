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

package com.kizna.html.tags;

import java.util.Enumeration;
import java.util.Hashtable;
import java.util.Vector;
/**
 * HTMLAppletTag represents an &lt;Applet&gt; tag
 */
public class HTMLAppletTag extends HTMLTag 
{
	private java.lang.String codeBase;
	private java.lang.String archive;
	private java.lang.String appletClass;
	private Hashtable appletParams;
	private java.util.Vector misc;
/**
 * HTMLAppletTag constructor comment.
 * @param tagBegin int
 * @param tagEnd int
 * @param tagContents java.lang.String
 * @param tagLine java.lang.String
 */
public HTMLAppletTag(int tagBegin, int tagEnd, String tagContents, String tagLine, String appletClass,String archive,String codeBase,Hashtable appletParams,Vector misc) 
{
	super(tagBegin, tagEnd, tagContents, tagLine);
	this.appletClass = appletClass;
	this.codeBase = codeBase;
	this.archive = archive;
	this.appletParams = appletParams;
	this.misc = misc;
}
/**
 * Insert the method's description here.
 * Creation date: (6/18/2001 2:01:56 AM)
 * @return java.lang.String
 */
public java.lang.String getAppletClass() {
	return appletClass;
}
/**
 * Insert the method's description here.
 * Creation date: (6/18/2001 2:03:26 AM)
 * @return java.util.Vector
 */
public Hashtable getAppletParams() {
	return appletParams;
}
/**
 * Insert the method's description here.
 * Creation date: (6/18/2001 2:01:42 AM)
 * @return java.lang.String
 */
public java.lang.String getArchive() {
	return archive;
}
/**
 * Insert the method's description here.
 * Creation date: (6/18/2001 2:01:28 AM)
 * @return java.lang.String
 */
public java.lang.String getCodeBase() {
	return codeBase;
}
/**
 * Insert the method's description here.
 * Creation date: (6/18/2001 2:15:57 PM)
 * @return java.util.Vector
 */
public java.util.Vector getMisc() {
	return misc;
}
/**
 * Insert the method's description here.
 * Creation date: (6/18/2001 2:06:20 AM)
 * @return java.lang.String
 * @param key java.lang.String
 */
public String getParameter(String key)
{
	return (String)appletParams.get(key);
}
/**
 * Insert the method's description here.
 * Creation date: (6/18/2001 2:05:34 AM)
 */
public Enumeration getParameterNames() 
{
	return appletParams.keys();	
}
/**
 * Insert the method's description here.
 * Creation date: (6/18/2001 2:01:56 AM)
 * @param newAppletClass java.lang.String
 */
public void setAppletClass(java.lang.String newAppletClass) {
	appletClass = newAppletClass;
}
/**
 * Insert the method's description here.
 * Creation date: (6/18/2001 2:03:26 AM)
 * @param newAppletParams java.util.Vector
 */
public void setAppletParams(Hashtable newAppletParams) {
	appletParams = newAppletParams;
}
/**
 * Insert the method's description here.
 * Creation date: (6/18/2001 2:01:42 AM)
 * @param newArchive java.lang.String
 */
public void setArchive(java.lang.String newArchive) {
	archive = newArchive;
}
/**
 * Insert the method's description here.
 * Creation date: (6/18/2001 2:01:28 AM)
 * @param newCodeBase java.lang.String
 */
public void setCodeBase(java.lang.String newCodeBase) {
	codeBase = newCodeBase;
}
/**
 * Insert the method's description here.
 * Creation date: (6/18/2001 2:15:57 PM)
 * @param newMisc java.util.Vector
 */
public void setMisc(java.util.Vector newMisc) {
	misc = newMisc;
}
	public String toString()
	{
		StringBuffer sb = new StringBuffer();
		sb.append("Applet Tag\n");
		sb.append("**********\n");
		sb.append("Class Name = "+appletClass+"\n");
		sb.append("Archive = "+archive+"\n");
		sb.append("Codebase = "+codeBase+"\n");
		Enumeration params = appletParams.keys();
		if (params==null)
		sb.append("No Params found.\n");
		else
		{
			int cnt = 0;
			for (;params.hasMoreElements();)
			{
				String paramName = (String)params.nextElement();
				String paramValue = (String)appletParams.get(paramName);
				sb.append((cnt++)+": Parameter name = "+paramName+", Parameter value = "+paramValue+"\n");
			}
		}
		if (misc.elements()==null)
		sb.append("No Miscellaneous items\n"); else
		{
			sb.append("Miscellaneous items :\n");
			for (Enumeration e = misc.elements();e.hasMoreElements();)
			{
				((HTMLTag)e.nextElement()).print();
			}
		}
		sb.append("End of Applet Tag\n");
		sb.append("*****************\n");
		return sb.toString();
	}

	/**
	 * @see HTMLNode#toRawString()
	 */
	public String toHTML() {
		StringBuffer sb = new StringBuffer();
		sb.append(super.toHTML()+"\n");
		for (Enumeration e = getParameterNames();e.hasMoreElements();) {
			String paramName = (String)e.nextElement();
			String paramValue = getParameter(paramName);
			sb.append("<PARAM NAME=\""+paramName+"\" VALUE=\""+paramValue+"\">\n");
		}
		sb.append("</APPLET>");
		return sb.toString();
	}

}
