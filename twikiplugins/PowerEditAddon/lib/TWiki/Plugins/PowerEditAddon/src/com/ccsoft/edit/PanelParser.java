package com.ccsoft.edit;

class PanelParser {
    static String[] parsePanel(String desc) {
	String[] result = null;
	int end, start = 0, rl = 0;
	while ((end = desc.indexOf('=', start)) != -1) {
	    String[] nr = new String[rl + 2];
	    if (result != null)
		System.arraycopy(result, 0, nr, 0, rl);
	    result = nr;
	    result[rl++] = desc.substring(start, end);
	    start = end + 1;
	    end = start;
	    for (;;) {
		end = desc.indexOf('|', end);
		if (end == -1)
		    break;
		if (desc.indexOf('|', end + 1) != end + 1)
		    break;
		desc = desc.substring(0, end) + desc.substring(end + 1);
		end += 2;
	    }
	    if (end == -1)
		end = desc.length();
	    result[rl++] = desc.substring(start, end);
	    start = end + 1;

	}
	return result;
    }
}
