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
import com.kizna.html.tags.HTMLFrameSetTag;
import com.kizna.html.tags.HTMLFrameTag;
import com.kizna.html.util.HTMLLinkProcessor;
/**
 * Scans for the Frame Tag. This is a subclass of HTMLTagScanner, and is called using a
 * variant of the template method. If the evaluate() method returns true, that means the
 * given string contains an image tag. Extraction is done by the scan method thereafter
 * by the user of this class.
 */
public class HTMLFrameSetScanner extends HTMLTagScanner
{
	/**
	 * Overriding the default constructor
	 */
	public HTMLFrameSetScanner()
	{
		super();
	}
	/**
	 * Overriding the constructor to accept the filter
	 */
	public HTMLFrameSetScanner(String filter)
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
		if (s.toUpperCase().indexOf("FRAMESET")==0)
		return true; else return false;			
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
		/* Remove all the existing scanners and register only the frame scanner. Proceed scanning till end
		 * tag is found. Then register all the scanners back.
		 */
		// Store all the current scanners in tempScannerVector
		Vector tempScannerVector = adjustScanners(reader);
		Vector frameVector = new Vector();
		// Scanners have been adjusted, begin processing till we recieve the end tag for the frame
		boolean endFrameSetFound=false;
		HTMLNode node;
		int frameSetEnd=-1;
		do {
			node = reader.readElement();
			if (node instanceof HTMLEndTag) {
				HTMLEndTag endTag = (HTMLEndTag)node;
				if (endTag.getContents().toUpperCase().equals("FRAMESET")) {
					endFrameSetFound = true;
					frameSetEnd = endTag.elementEnd();
				}
			} else
			if (node instanceof HTMLFrameTag) {
				frameVector.addElement(node);
			}
		}
		while(!endFrameSetFound);
		HTMLFrameSetTag frameSetTag = new HTMLFrameSetTag(tag.elementBegin(),frameSetEnd,tag.getText(),currentLine,frameVector);
		frameSetTag.setThisScanner(this);
		frameSetTag.setParsed(tag.getParsed());
		restoreScanners(reader, tempScannerVector);
		return frameSetTag;		
	}
	public void restoreScanners(HTMLReader reader, Vector tempScannerVector) {
		// Flush the scanners
		reader.getParser().flushScanners();
		// Add all the original scanners back
		for (Enumeration e = tempScannerVector.elements();e.hasMoreElements();) {
			reader.getParser().addScanner((HTMLTagScanner)e.nextElement());
		}
	}
	public Vector adjustScanners(HTMLReader reader) {
		Vector tempScannerVector = new Vector();
		for (Enumeration e=reader.getParser().getScanners();e.hasMoreElements();) {
			tempScannerVector.addElement(e.nextElement());
		}
		// Remove all existing scanners
		reader.getParser().flushScanners();
		// Add only the frame scanner
		reader.getParser().addScanner(new HTMLFrameScanner(""));
		return tempScannerVector;
	}
}
