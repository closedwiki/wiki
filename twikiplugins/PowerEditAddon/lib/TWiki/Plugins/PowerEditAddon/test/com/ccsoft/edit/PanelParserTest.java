package com.ccsoft.edit;

import junit.framework.*;

public class PanelParserTest extends TestCase {

    public PanelParserTest(String name) {
	super(name);
    }

    public static Test suite() {
	return new TestSuite(PanelParserTest.class);
    }

    public void testSimple() {
	String[] v = PanelParser.parsePanel("A=1|B=2|C=3");
	int i = 0;
	assertEquals("A", v[i++]);
	assertEquals("1", v[i++]);
	assertEquals("B", v[i++]);
	assertEquals("2", v[i++]);
	assertEquals("C", v[i++]);
	assertEquals("3", v[i++]);
	assert(i == v.length);
    }

    public void testTwoButtons() {
	String[] v = PanelParser.parsePanel("A sad fact=1|Of life=2");
	int i = 0;
	assertEquals("A sad fact", v[i++]);
	assertEquals("1", v[i++]);
	assertEquals("Of life", v[i++]);
	assertEquals("2", v[i++]);
	assert(i == v.length);
    }

    public void testBarsAndEquals() {
	String[] v = PanelParser.parsePanel("A=1||2|B=2=3");
	int i = 0;
	assertEquals("A", v[i++]);
	assertEquals("1|2", v[i++]);
	assertEquals("B", v[i++]);
	assertEquals("2=3", v[i++]);
	assert(i == v.length);
    }

    public void testSpacesAndEquals() {
	String[] v = PanelParser.parsePanel("A B =1=2=3| B =||");
	int i = 0;
	assertEquals("A B ", v[i++]);
	assertEquals("1=2=3", v[i++]);
	assertEquals(" B ", v[i++]);
	assertEquals("|", v[i++]);
	assert(i == v.length);
    }

    public void testBadEnd() {
	String[] v = PanelParser.parsePanel("A=B|");
	int i = 0;
	assertEquals("A", v[i++]);
	assertEquals("B", v[i++]);
	assert(i == v.length);
    }

}

