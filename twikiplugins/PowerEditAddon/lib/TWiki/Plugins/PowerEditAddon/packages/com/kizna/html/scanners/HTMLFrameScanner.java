package com.kizna.html.scanners;


//////////////////
// Java Imports //
//////////////////
import java.util.Enumeration;
import java.util.Vector;
import java.io.IOException;
import java.util.Hashtable;

/////////////////////////
// HTML Parser Imports //
/////////////////////////
import com.kizna.html.tags.HTMLTag;
import com.kizna.html.HTMLNode;
import com.kizna.html.HTMLReader;
import com.kizna.html.HTMLParser;
import com.kizna.html.tags.HTMLEndTag;
import com.kizna.html.tags.HTMLFrameTag;
import com.kizna.html.util.HTMLLinkProcessor;
/**
 * Scans for the Frame Tag. This is a subclass of HTMLTagScanner, and is called using a
 * variant of the template method. If the evaluate() method returns true, that means the
 * given string contains an image tag. Extraction is done by the scan method thereafter
 * by the user of this class.
 */
public class HTMLFrameScanner extends HTMLTagScanner
{
	/**
	 * Overriding the default constructor
	 */
	public HTMLFrameScanner()
	{
		super();
	}
	/**
	 * Overriding the constructor to accept the filter
	 */
	public HTMLFrameScanner(String filter)
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
		if (s.toUpperCase().indexOf("FRAME ")==0)
		return true; else return false;			
	}
  /**
   * Extract the location of the image, given the string to be parsed, and the url
   * of the html page in which this tag exists.
   * @param s String to be parsed
   * @param url URL of web page being parsed
   */
	public String extractFrameLocn(HTMLTag tag,String url)
	{
		Hashtable table = tag.parseParameters();
		String relativeFrame =  (String)table.get("SRC");
		if (relativeFrame==null) return ""; else
		return (new HTMLLinkProcessor()).extract(relativeFrame,url);
	}


	public String extractFrameName(HTMLTag tag,String url)
	{
		return tag.getParameter("NAME");
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
		String frame, frameName, linkText="";
		int frameBegin, frameEnd;

		// Yes, the tag is a link
		// Extract the link
		//link = extractImageLocn(tag.getText(),url);
		frame = extractFrameLocn(tag,url);
	    frameName = extractFrameName(tag,url);
		frameBegin = tag.elementBegin();
		frameEnd = tag.elementEnd();
		HTMLFrameTag frameTag = new HTMLFrameTag(frame, frameName, tag.getText(), frameBegin,frameEnd,currentLine);
		frameTag.setThisScanner(this);
		frameTag.setParsed(tag.getParsed());
		return frameTag;
	}
}
