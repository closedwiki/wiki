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

package com.kizna.html;

/**
 * The remark tag is identified and represented by this class.
 */
public class HTMLRemarkNode extends HTMLNode
{
	/**
	 * Tag contents will have the contents of the comment tag.
   */
	String tagContents;
	/** 
	 * The beginning position of the tag in the line
	 */
	int tagBegin;
	/**
	 * The ending position of the tag in the line
	 */
	int tagEnd;
	/**
	 * The HTMLRemarkTag is constructed by providing the beginning posn, ending posn
	 * and the tag contents.
	 * @param tagBegin beginning position of the tag
	 * @param tagEnd ending position of the tag
	 * @param tagContents contents of the remark tag
	 * @param tagLine The current line being parsed, where the tag was found	 
	 */
	public HTMLRemarkNode(int tagBegin, int tagEnd, String tagContents)
	{
		this.tagBegin = tagBegin;
		this.tagEnd = tagEnd;
		this.tagContents = tagContents;
	}
	/**
	 * Returns the beginning position of the tag.
	 */
	public int elementBegin()
	{
		return tagBegin;
	}
	/**
	 * Returns the ending position fo the tag
	 */
	public int elementEnd()
	{
		return tagEnd;
	}
	/**
	 * Locate the remark tag withing the input string, by parsing from the given position
	 * @param reader HTML reader to be provided so as to allow reading of next line
	 * @param input Input String
	 * @param position Position to start parsing from
	 */	
	public static HTMLRemarkNode find(HTMLReader reader,String input,int position)
	{
		int state = 0;
		//String tagContents = "";
		StringBuffer tagContents = new StringBuffer();
		int tagBegin=0;
		int tagEnd=0;
		int i=position;
		int inputLen = input.length();
		char ch,prevChar=' ';
		while (i < inputLen && state < 7)
		{
			ch = input.charAt(i);
			if (state == 6 && ch == '>')
			{
				state=7;
				tagEnd=i;
			}
			if (state==5)
			{
				if (ch == '-')
				{
					state=6;
				} else
				{
					// Rollback
					state = 4;
					tagContents.append(prevChar);
				}
			}
			if (state==4 && ch == '-')
			{
				state=5;
			}		
			if (state==4)
			{
				//tagContents+=input.charAt(i);		
				tagContents.append(ch);
			}
			if (state==8)
			{
				return null;
			}
			
			if (state==3)
			{
				if (ch == '-')
				state=4;
				else state=8;
			}
			if (state==2)
			{
				if (ch == '-')
				state=3;
				else state=8;
			}
			if (state==1)
			{
				if (ch == '!')
				state=2;
				else state = 8; // This is not a remark tag
			}
			if (ch == '<' && state == 0)
			{
				// Transition from State 0 to State 1 - Record data till > is encountered
				tagBegin = i;
				state = 1;
			}
			if (state > 1 && state < 7 && i == input.length() - 1)
			{
				// We need to continue parsing to the next line
				input = reader.getNextLine();
				tagContents.append("\n");
				inputLen = input.length();
				i=-1;
			}		
			i++;
			prevChar = ch;
		}
		if (state==7)
		return new HTMLRemarkNode(tagBegin,tagEnd,tagContents.toString());
		else
		return null;	
	}
	/** 
	 * Returns the text contents of the comment tag.
	 */
	public String getText()
	{
		return tagContents;
	}
	public String toPlainTextString() {
		return tagContents;
	}
	public String toHTML() {
		return "<!--\n"+tagContents+"\n-->";
	}
	/**
	 * Print the contents of the remark tag.
	 */
	public String toString()
	{
		return "Comment Tag : "+tagContents+"; begins at : "+elementBegin()+"; ends at : "+elementEnd()+"\n";
	}
}
