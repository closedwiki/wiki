// Copyright (C) Crawford Currie 2004 - All rights reserved
// It is hereby granted that this software can be used, copied, 
// modified, and distributed without fee provided that this 
// copyright notice appears in all copies.
package com.ccsoft.edit;

import java.awt.Component;
import java.awt.Container;
import java.awt.Dimension;
import java.awt.FlowLayout;
import java.awt.Insets;

/**
 * Class to layout buttons packed close together
 */
class VerticalControlLayout extends FlowLayout {
    public VerticalControlLayout() {
	setHgap(0);
	setVgap(0);
    }

    public Dimension preferredLayoutSize(Container target) {
	Dimension dim = new Dimension(0, 0);
	int nmembers = target.getComponentCount();
	
	for (int i = 0 ; i < nmembers ; i++) {
	    Component m = target.getComponent(i);
	    if (m.isVisible()) {
		Dimension d = m.getPreferredSize();
		dim.width = Math.max(dim.width, d.width);
		if (i > 0)
		    dim.height += getVgap();
		dim.height += d.height;
	    }
	}
	Insets insets = target.getInsets();
	dim.width += insets.left + insets.right + getHgap()*2;
	dim.height += insets.top + insets.bottom + getVgap()*2;
	return dim;
    }
    
    public Dimension minimumLayoutSize(Container target) {
	Dimension dim = new Dimension(0, 0);
	int nmembers = target.getComponentCount();
	
	for (int i = 0 ; i < nmembers ; i++) {
	    Component m = target.getComponent(i);
	    if (m.isVisible()) {
		Dimension d = m.getMinimumSize();
		dim.width = Math.max(dim.width, d.width);
		if (i > 0)
		    dim.height += getVgap();
		dim.height += d.height;
	    }
	}
	Insets insets = target.getInsets();
	dim.width += insets.left + insets.right + getHgap()*2;
	dim.height += insets.top + insets.bottom + getVgap()*2;
	return dim;
    }
}

