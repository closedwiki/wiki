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

package com.kizna.html.parserapplications;
import com.kizna.html.scanners.*;
import com.kizna.html.tags.*;
import java.util.Vector;
import java.util.Enumeration;
import com.kizna.html.*;


/**
 * MailRipper will rip out all the mail addresses from a given web page
 * Pass a web site (or html file on your local disk) as an argument.
 */
public class MailRipper {
	private com.kizna.html.HTMLParser parser;
/**
 * MailRipper c'tor takes the url to be ripped
 * @param resourceLocation url to be ripped
 */
public MailRipper(String resourceLocation) {
	parser = new HTMLParser(resourceLocation);
	parser.registerScanners();
}
public static void main(String[] args) {
	System.out.println("Mail Ripper v"+HTMLParser.VERSION_STRING);
	if (args.length<1 || args[0].equals("-help"))
	{
		System.out.println();
		System.out.println("Syntax : java -classpath htmlparser.jar com.kizna.parserapplications.MailRipper <resourceLocn/website>");
		System.out.println();
		System.out.println("   <resourceLocn> the name of the file to be parsed (with complete path ");
		System.out.println("                  if not in current directory)");
		System.out.println("   -help This screen");
		System.out.println();
		System.out.println("HTML Parser home page : http://htmlparser.sourceforge.net");
		System.out.println();
		System.out.println("Example : java -classpath htmlparser.jar com.kizna.parserapplications.MailRipper http://htmlparser.sourceforge.net");
		System.out.println();
		System.out.println("If you have any doubts, please join the HTMLParser mailing list (user/developer) from the HTML Parser home page instead of mailing any of the contributors directly. You will be surprised with the quality of open source support. ");
		System.exit(-1);
	}		
	String resourceLocation = "http://htmlparser.sourceforge.net";
	if (args.length!=0) resourceLocation = args[0];

	MailRipper ripper = new MailRipper(resourceLocation);	
	System.out.println("Ripping Site "+resourceLocation);
	for (Enumeration e=ripper.rip();e.hasMoreElements();) {
		HTMLLinkTag tag = (HTMLLinkTag)e.nextElement();
		System.out.println("Ripped mail address : "+tag.getLink());
	}
}
/**
 * Rip all mail addresses from the given url, and return an enumeration of such mail addresses.
 * @return Enumeration of mail addresses (a vector of HTMLLinkTag)
 */
public Enumeration rip() {
	HTMLNode node;
	Vector mailAddresses = new Vector();
	for (Enumeration e = parser.elements();e.hasMoreElements();)
	{
		node = (HTMLNode)e.nextElement();
		if (node instanceof HTMLLinkTag)
		{
			HTMLLinkTag linkTag = (HTMLLinkTag)node;
			if (linkTag.isMailLink()) mailAddresses.addElement(linkTag);
		}
	}
	return mailAddresses.elements();	
}
}
