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

/**
 * A Meta Tag
 */
public class HTMLMetaTag extends HTMLTag {
	private String metaTagName;
	private String metaTagContents;
	private String httpEquiv;
	public HTMLMetaTag(int tagBegin, int tagEnd, String tagContents, String httpEquiv, String metaTagName, String metaTagContents,String tagLine) {
		super(tagBegin,tagEnd,tagContents,tagLine);
		this.httpEquiv = httpEquiv;
		this.metaTagName = metaTagName;
		this.metaTagContents = metaTagContents;
	}
	public String getHttpEquiv() {
		return httpEquiv;
	}
	public String getMetaTagContents() {
		return metaTagContents;
	}
	public String getMetaTagName() {
		return metaTagName;
	}
	public void setHttpEquiv(String httpEquiv) {
		this.httpEquiv = httpEquiv;
	}
	public void setMetaTagContents(String metaTagContents) {
		this.metaTagContents = metaTagContents;
	}
	public void setMetaTagName(String metaTagName) {
		this.metaTagName = metaTagName;
	}
	public String toString() {
		return "META TAG\n"+
				"--------\n"+
				"Http-Equiv : "+getHttpEquiv()+"\n"+
				"Name : "+metaTagName+"\n"+
				"Contents : "+metaTagContents+"\n";	
	}
}
