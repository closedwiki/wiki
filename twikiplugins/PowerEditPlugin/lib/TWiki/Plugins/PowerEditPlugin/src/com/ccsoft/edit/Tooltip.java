package com.ccsoft.edit;

import java.applet.Applet;
import java.awt.*;
import java.awt.event.*;

public class Tooltip extends Canvas {
    protected String tip;
    protected Component owner;
    
    private Container mainContainer;
    private LayoutManager mainLayout;
    
    private boolean shown;
    
    private final int VERTICAL_OFFSET = 30;
    private final int HORIZONTAL_ENLARGE = 10;
    
    class MAdapter extends MouseAdapter {
	public void mouseEntered(MouseEvent me) {
	    findMainContainer();
	    addTooltip();
	}
	public void mouseExited(MouseEvent me) {
	    removeTooltip();
	}
	public void mousePressed(MouseEvent me) {
	    removeTooltip();
	}
    }

    public Tooltip(String tip, Component owner) {
	this.tip = tip;
	this.owner = owner;
	owner.addMouseListener(new MAdapter());
	setBackground(new Color(255,255,220));
    }
    
    
    public void paint(Graphics g) {
	g.drawRect(0,0,getSize().width -1, getSize().height -1);
	g.drawString(tip, 3, getSize().height - 3);
    }
    
    private void addTooltip() {
	mainContainer.setLayout(null);
	
	FontMetrics fm = getFontMetrics(owner.getFont());               
	setSize(fm.stringWidth(tip) + HORIZONTAL_ENLARGE, fm.getHeight());
	
	setLocation((owner.getLocationOnScreen().x - mainContainer.getLocationOnScreen().x) , 
		    (owner.getLocationOnScreen().y - mainContainer.getLocationOnScreen().y + VERTICAL_OFFSET));
	
	// correction, whole tool tip must be visible 
	if (mainContainer.getSize().width < ( getLocation().x + getSize().width )) {
	    setLocation(mainContainer.getSize().width - getSize().width, getLocation().y);
	}
	mainContainer.add(this, 0);
	mainContainer.validate();
	repaint();
	shown = true;
    }
    
    private void removeTooltip() {
	if (shown) {
	    mainContainer.remove(0);
	    mainContainer.setLayout(mainLayout);
	    mainContainer.validate();
	}
	shown = false;
    }
    
    private void findMainContainer() {
	Container parent = owner.getParent();
	while (true) {
	    if ((parent instanceof Applet) || (parent instanceof Frame)) {
		mainContainer = parent;
		break;                          
	    } else {
		parent = parent.getParent();
	    }
	}               
	mainLayout = mainContainer.getLayout();
    }
}

