package com.kizna.html.tags;

import java.util.*;
import java.io.IOException;
import com.kizna.html.scanners.HTMLTagScanner;
import com.kizna.html.HTMLNode;
import com.kizna.html.HTMLReader;
/**
 * HTMLTag represents a generic tag. This class allows users to register specific
 * tag scanners, which can identify links, or image references. This tag asks the
 * scanners to run over the text, and identify. It can be used to dynamically 
 * configure a parser.
 */
public class HTMLTag extends HTMLNode
{
    /**
    * Constant used as value for the value of the tag name
    * in parseParameters  (Kaarle Kaila 3.8.2001)
    */
    public final static String TAGNAME = "$<TAGNAME>$";    
	public final static int TAG_BEFORE_PARSING_STATE=0;
    public final static int TAG_BEGIN_PARSING_STATE=1;
    public final static int TAG_FINISHED_PARSING_STATE=2;
	public final static int TAG_ILLEGAL_STATE=3;
	public final static int TAG_IGNORE_DATA_STATE=4;	    
	private static Vector strictTags=null;
	/**
	 * Tag contents will have the contents of the comment tag.
   */
	StringBuffer tagContents;
	/** 
	 * The beginning position of the tag in the line
	 */		
	int tagBegin;
	/**
	 * The ending position of the tag in the line
	 */	
	int tagEnd;
	/**
	* tag parameters parsed into this hashtable
	* not implemented yet
	* added by Kaarle Kaila 23.10.2001
	*/
	private Hashtable parsed=null;
	
	/**
	 * Scanner associated with this tag (useful for extraction of filtering data from a
	 * HTML node)
	 */
	protected HTMLTagScanner thisScanner=null;
	private java.lang.String tagLine;
	private boolean endOfLineCharState;
	/**
	 * Set the HTMLTag with the beginning posn, ending posn and tag contents
	 * @param tagBegin Beginning position of the tag
	 * @param tagEnd Ending positiong of the tag
	 * @param tagContents The contents of the tag
	 * @param tagLine The current line being parsed, where the tag was found
	 */
	public HTMLTag(int tagBegin, int tagEnd, String tagContents, String tagLine)
	{
		this.tagBegin = tagBegin;
		this.tagEnd = tagEnd;
		this.tagContents = new StringBuffer();
		this.tagContents.append(tagContents);
		this.tagLine = tagLine;
		this.endOfLineCharState = false;
	}
	public void append(char ch) {
		tagContents.append(ch);
	}
	protected static int automataIllegalState(String input, int state, int i, char ch) {
		if (ch=='/' && i>0 && input.charAt(i-1)=='<')
		{
			state = TAG_ILLEGAL_STATE;
		}
		return state;
	}
	protected static int automataInput(int state, int i, char ch, HTMLTag tag) {
		state = checkIllegalState(state, i, ch, tag);
		state = checkFinishedState(state, i, ch, tag);
		state = toggleIgnoringState(state, ch);
		checkIfAppendable(state, ch, tag);
		state = checkBeginParsingState(state, i, ch, tag);
		return state;
	}
	private static int checkBeginParsingState(int state, int i, char ch, HTMLTag tag) {
		if (ch=='<' && (state==TAG_BEFORE_PARSING_STATE || state==TAG_ILLEGAL_STATE))
		{
			// Transition from State 0 to State 1 - Record data till > is encountered
			tag.setTagBegin(i);
			state = TAG_BEGIN_PARSING_STATE;
		}
		return state;
	}
	private static int checkFinishedState(int state, int i, char ch, HTMLTag tag) {
		if (ch=='>')
		{
			if (state==TAG_BEGIN_PARSING_STATE)
			{
				state = TAG_FINISHED_PARSING_STATE;
				tag.setTagEnd(i);
			}
			else
			if (state==TAG_IGNORE_DATA_STATE) {
				// Now, either this is a valid > input, and should be ignored,
				// or it is a mistake in the html, in which case we need to correct it *sigh*
				state = checkValidity(state, tag);
				// If the state has changed to TAG_FINISH_STATE
				// then we must perform a correction routine to the text that
				// has just been parsed
				if (state==TAG_FINISHED_PARSING_STATE) {
					tag.setTagEnd(i);
					// Do Correction
					// Correct the tag - assuming its grouped into name value pairs
					// Remove all inverted commas.
					correctTag(tag);
				}
			}
		}
		return state;
	}
	private static void checkIfAppendable(int state, char ch, HTMLTag tag) {
		if (state==TAG_IGNORE_DATA_STATE || state==TAG_BEGIN_PARSING_STATE) {
			tag.append(ch);
		}
	}
	private static int checkIllegalState(int state, int i, char ch, HTMLTag tag) {
		if (ch=='/' && i>0 && tag.getTagLine().charAt(i-1)=='<')
		{
			state = TAG_ILLEGAL_STATE;
		}
		return state;
	}
	public static int checkValidity(int state,HTMLTag tag) {
		// If the tag begins with any of the strictness tag values, then we may assume
		// that this is a valid > within the ignore state, and continue as normal
		// if however, this tag does not come under the strictness vector, then we
		// need to correct
		if (strictTags==null) return TAG_FINISHED_PARSING_STATE;
		// Get the first word within the tag
		String word = extractWord(tag.getText());
		// Now we have the word. Check if it exists in the vector

		if (strictTags.contains(word)) {
			// Yes it is contained
			// Hence, continue parsing as normal
			return state;
		}
		else {
			// Nope - it is not contained.
			// Assume this was a mistake.
			return TAG_FINISHED_PARSING_STATE;			
		}
	}
	public static void correctTag(HTMLTag tag) {
		String tempText = tag.getText();
		StringBuffer absorbedText = new StringBuffer();
		char c;
		for (int j=0;j<tempText.length();j++) {
			c = tempText.charAt(j);
			if (c!='"')
			absorbedText.append(c);
		}
		tag.setText(absorbedText.toString());
	}
  /**
	 * Returns the beginning position of the string.
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
	public static String extractWord(String s) {
		String word = "";
		boolean parse=true;
		for (int i=0;i<s.length() && parse==true;i++) {
			char ch = s.charAt(i);
			if (ch==' ') parse = false; else word +=ch;
		}
		word = word.toUpperCase();
		return word;
	}
	/**
	 * Locate the tag withing the input string, by parsing from the given position
	 * @param reader HTML reader to be provided so as to allow reading of next line
	 * @param input Input String
	 * @param position Position to start parsing from
	 */			
	public static HTMLTag find(HTMLReader reader,String input,int position)
	{
		int state = TAG_BEFORE_PARSING_STATE;
		StringBuffer tagContents = new StringBuffer();
		int i=position;
		char ch;
		HTMLTag tag = new HTMLTag(0,0,"",input);
		while (i<tag.getTagLine().length()&& state!=TAG_FINISHED_PARSING_STATE && state!=TAG_ILLEGAL_STATE)
		{
			ch = tag.getTagLine().charAt(i);
			state = automataInput(state, i, ch, tag);
			i = incrementCounter(reader, state, i, tag);
		}
		if (state==TAG_FINISHED_PARSING_STATE)
		return tag;
		else
		return null;	
	}
/*
* in case the tag is parsed at the scan method
* this will return value of a parameter
* not implemented yet
* @param name of parameter
* @author Kaarle Kaila 23.10.2001
*/
	
	public String getParameter(String name){
	    return (String)getParsed().get(name.toUpperCase());
	}
	/**
	 * Gets the parsed.
	 * @return Returns a Hashtable
	 */
	public Hashtable getParsed() {
		if (parsed == null) {
	    	parsed = parseParameters();
	    } 		
		return parsed;
	}
	/**
	 * Gets the strictTags.
	 * @return Returns a Vector
	 */
	public static Vector getStrictTags() {
		return strictTags;
	}
/*
* in case the tag is parsed at the scan method
* this will return the tag-name (TAG)
* not implemented yet
* @author Kaarle Kaila 23.10.2001
*/
	public String getTag(){
	    if (parsed == null) parsed=parseParameters();
	    return (String)parsed.get(TAGNAME);
	}
/**
 * Insert the method's description here.
 * Creation date: (6/6/2001 12:09:38 PM)
 * @return java.lang.String
 */
public java.lang.String getTagLine() {
	return tagLine;
}
	/**
	 * Return the text contained in this tag
	 */
	public String getText()
	{
		return tagContents.toString();
	}
	/**
	 * Return the scanner associated with this tag.
	 */
	public HTMLTagScanner getThisScanner()
	{
		return thisScanner;
	}
	public static int incrementCounter(HTMLReader reader, int state, int i, HTMLTag tag) {
		String nextLine = null;
		if ((state==TAG_BEGIN_PARSING_STATE || state == TAG_IGNORE_DATA_STATE) && i==tag.getTagLine().length()-1)
		{
			// The while loop below is a bug fix contributed by
			// Annette Doyle - see testcase HTMLImageScannerTest.testImageTagOnMultipleLines()
			while ((nextLine = reader.getNextLine()).length() == 0);
			// We need to continue parsing to the next line
			tag.setTagLine(nextLine);
			// convert the end of line to a space
			// The following line masked by Somik Raha, 15 Apr 2002, to fix space bug in links
			tag.append('\n');
			i=-1;
		}		
		return ++i;
	}
/**
 * Insert the method's description here.
 * Creation date: (6/16/2002 3:28:38 PM)
 * @return boolean
 */
public boolean isEndOfLineCharState() {
	return endOfLineCharState;
}
	/**
	* Method to break the tag into pieces.
	* @param returns a Hastable with elements containing the
	* pieces of the tag. The tag-name has the value field set to 
	* the constant HTMLTag.TAGNAME. In addition the tag-name is
	* stored into the Hashtable with the name HTMLTag.TAGNAME
	* where the value is the name of the tag.
	* Tag parameters without value
	* has the value "". Parameters with value are represented
	* in the Hastable by a name/value pair.
	* As html is case insensitive but Hastable is not are all
	* names converted into UPPERCASE to the Hastable
	* E.g extract the href values from A-tag's and print them
	* <pre>
	*    
    *    HTMLTag tag;
	*    Hashtable h;
	*    String tmp;
    *    try {
    *        HTMLReader in = new HTMLReader(new FileReader(path),2048);
    *        HTMLParser p = new HTMLParser(in);
    *        Enumeration en = p.elements();
    *        while (en.hasMoreElements()) {
    *            try {
    *                tag = (HTMLTag)en.nextElement();
    *                h = tag.parseParameters();
    *                tmp = (String)h.get(tag.TAGNAME);
    *                if (tmp != null && tmp.equalsIgnoreCase("A")) {;    
    *                    System.out.println("URL is :" + h.get("HREF"));
    *                }
    *            } catch (ClassCastException ce){}
    *        }
    *    }
    *    catch (IOException ie) {
    *        ie.printStackTrace();
    *    }
	* </pre>
	*
	* @author Kaarle Kaila
	* @version 7 AUG 2001
	*/
    public Hashtable parseParameters(){
        Hashtable h = new Hashtable();
        String name,value,t,st;
        final String delim = " \t\r\n\f=\"'>";
        boolean isAmp=false;
        boolean isApo=false;
        boolean isValue=false;
        boolean isName=true;
        boolean waitingForValue = false;
        name=null;
        value=null;
        t=null;
        waitingForValue=false;       
        StringTokenizer token = new StringTokenizer(getText() + " ",delim,true);
        while (token.hasMoreTokens()) {
            st = token.nextToken();
            //
            // First let's combine tokens that are inside "" or ''
            //
            if (isAmp || isApo) {
                if (isAmp && st.equals("\"")){                
                    isAmp= false;                                   
                } else if (isApo && st.equals("'")) {
                    isApo=false;
                }else {               
                    t += st;   
                    continue;
                }
            } else if (st.equals("\"")){                
                isAmp= true;
                t = "";
                continue;
            } else if (st.equals("'")){
                isApo=true;
                t="";
                continue;                
            } else t = st;
            
            // above leaves t with
            // - a delimter
            // - a name of a parameter or the tag itself
            // - a value of a parameter
            if (delim.indexOf(t)>=0) {
                // t was a delimiter
                if (waitingForValue) {
                    if (t.equals("=")) {
                        // here set to receive next value of parameter
                        waitingForValue=false;
                        isValue=true;
                        value="";
                    }
                } 
                if (name != null && isValue==false){
                    if (isName && value == null) value=TAGNAME;
                    else if (value==null) value = ""; // Hastable does not accept nulls
                    if (isName) {
                        // store tagname as tag.TAGNAME,tag                        
                        h.put(value,name.toUpperCase());  
                    } 
                    else {                   
                        // store tag parameters as NAME, value
                        h.put(name.toUpperCase(),value);  
                    }
                    isName=false;
                    name=null;
                    name = null;
                    value=null;
                }                
            }
            else {                
                if (isValue) {
                    value=t;
                    isValue=false;
                }
                else {
                    if (name==null) {
                        name=t;
                        waitingForValue=true;
                    }
                }
            }
        }
        return h;
    }
	/**
	 * Scan the tag to see using the registered scanners, and attempt identification.
	 * @param url URL at which HTML page is located
	 * @param reader The HTMLReader that is to be used for reading the url
	 */
	public HTMLNode scan(Enumeration scanners,String url,HTMLReader reader) throws IOException
	{
		boolean found=false;
		HTMLNode retVal=null;
		
		for (Enumeration e=scanners;(e.hasMoreElements() && !found);)
		{
			HTMLTagScanner scanner = (HTMLTagScanner)e.nextElement();
//			parsed = parseParameters();
	//		if (scanner.evaluate(this))
			if (scanner.evaluate(tagContents.toString(),reader.getPreviousOpenScanner()))
			{
				found=true;
				reader.setPreviousOpenScanner(scanner);
				retVal=scanner.scan(this,url,reader,tagLine);
				reader.setPreviousOpenScanner(null);
			}
		}
		if (!found) return this;
		else {   			
		    return retVal;
		}
	}
/**
 * Insert the method's description here.
 * Creation date: (6/16/2002 3:28:38 PM)
 * @param newEndOfLineCharState boolean
 */
public void setEndOfLineCharState(boolean newEndOfLineCharState) {
	endOfLineCharState = newEndOfLineCharState;
}
	/**
	 * Sets the parsed.
	 * @param parsed The parsed to set
	 */
	public void setParsed(Hashtable parsed) {
		this.parsed = parsed;
	}
	/**
	 * Sets the strictTags.
	 * @param strictTags The strictTags to set
	 */
	public static void setStrictTags(Vector strictTags) {
		HTMLTag.strictTags = strictTags;
	}
	/**
	 * Sets the tagBegin.
	 * @param tagBegin The tagBegin to set
	 */
	public void setTagBegin(int tagBegin) {
		this.tagBegin = tagBegin;
	}
	/**
	 * Sets the tagEnd.
	 * @param tagEnd The tagEnd to set
	 */
	public void setTagEnd(int tagEnd) {
		this.tagEnd = tagEnd;
	}
    /**
    * Insert the method's description here.
    * Creation date: (6/6/2001 12:09:38 PM)
    * @param newTagLine java.lang.String
    */
    public void setTagLine(java.lang.String newTagLine) {
	    tagLine = newTagLine;
    }
	public void setText(String text) {
		tagContents = new StringBuffer(text);
	}
	/**
	 * Set the scanner associated with this tag
	 */
	public void setThisScanner(HTMLTagScanner scanner)
	{
		thisScanner = scanner;
	}
	private static int toggleIgnoringState(int state, char ch) {
		if (ch=='"') {
			// State 4 is ignoring mode. In this mode, we cant exit upon recieving endtag character
			// This is to avoid problems with end tags within inverted commas (occuring with JSP tags).
			if (state==TAG_IGNORE_DATA_STATE) state = TAG_BEGIN_PARSING_STATE; else
			if (state==TAG_BEGIN_PARSING_STATE) state = TAG_IGNORE_DATA_STATE;
		}
		return state;
	}
	public String toPlainTextString() {
		return "";
	}
	public String toHTML() {
		if (endOfLineCharState) return "<"+tagContents+">\r\n"; else
		return "<"+tagContents+">";
	}
	/**
	 * Print the contents of the tag
	 */
	public String toString()
	{
		return "Begin Tag : "+tagContents+"; begins at : "+elementBegin()+"; ends at : "+elementEnd();
	}
}
