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
import java.util.Vector;

import com.kizna.html.HTMLNode;

/**
 * Identifies an frame tag
 */
public class HTMLFrameSetTag extends HTMLTag
{
	/**
	 * The URL where the image is stored.
	 */
	protected String frameURL;
   	protected String frameName;
   	protected Vector frames;
	public HTMLFrameSetTag(int frameSetBegin, int frameSetEnd,String frameSetContents,String tagLine,Vector frames)
	{
		super(frameSetBegin,frameSetEnd,frameSetContents,tagLine);
		this.frameURL = frameURL;
      	this.frameName = frameName;
      	this.frames = frames;
	}
	/**
	 * Returns the location of the image
	 */
	public String getFrameLocation()
	{
		return frameURL;
	}
	public String getFrameName()
	{
		return frameName;
	}
	/**
	 * Print the contents of the HTMLImageNode
	 */
	public String toString()
	{
		return "FRAME TAG : Image at "+frameURL+"; begins at : "+elementBegin()+"; ends at : "+elementEnd();
	}
	/**
	 * Returns the frames.
	 * @return Vector
	 */
	public Vector getFrames() {
		return frames;
	}

	public HTMLFrameTag getFrame(String frameName) {
		boolean found = false;
		HTMLFrameTag frameTag=null;
		for (Enumeration e=frames.elements();e.hasMoreElements() && !found;) {
			frameTag = (HTMLFrameTag)e.nextElement();
			if (frameTag.getFrameName().toUpperCase().equals(frameName.toUpperCase())) found = true;
		}
		if (found)
		return frameTag; else return null;
	}
	/**
	 * Sets the frames.
	 * @param frames The frames to set
	 */
	public void setFrames(Vector frames) {
		this.frames = frames;
	}


	/**
	 * @see com.kizna.html.HTMLNode#toHTML()
	 */
	public String toHTML() {
		StringBuffer sb = new StringBuffer();
		sb.append(super.toHTML());
		HTMLNode node=null,prevNode=this;
		for (Enumeration e = frames.elements();e.hasMoreElements();) {
			node = (HTMLNode)e.nextElement();
			if (prevNode.elementEnd()>node.elementBegin()) sb.append("\r\n");
			sb.append(node.toHTML());
		} 
		if (node.elementEnd()>elementEnd()) sb.append("\r\n");
		sb.append("</FRAMESET>");
		return sb.toString();
	}


}
