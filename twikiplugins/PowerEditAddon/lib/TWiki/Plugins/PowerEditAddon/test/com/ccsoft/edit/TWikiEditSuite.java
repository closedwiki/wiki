package com.ccsoft.edit;

import junit.framework.*;

/**
 * Tests for display package and sub-packages
 */
public class TWikiEditSuite extends TestCase {
    public TWikiEditSuite(String name) {
        super(name);
    }

    public static Test suite() {
        TestSuite suite = new TestSuite();
        suite.addTest(DifferenceTest.suite());
        suite.addTest(UndoBufferTest.suite());
        suite.addTest(PanelParserTest.suite());
        suite.addTest(SearchableTextAreaTest.suite());
        suite.addTest(TWikiEditTest.suite());
        return suite;
    }
}

