package com.ccsoft.edit;

import java.awt.*;
import java.awt.event.*;
import java.awt.image.*;

/**
 * A two-state button using images
 */
public class ImageButton extends Canvas implements MouseListener {

    private static final int INSET = 2;
    private static final int BORDER = 1;

    Image image;
    boolean depressed;
    ActionListener al;
    String ac;
    Dimension size;

    public ImageButton(Image im) {
	image = im;
	depressed = false;
	al = null;
	addMouseListener(this);
	if ((checkImage(image, this) & ImageObserver.PROPERTIES) == 0) {
	    while (!prepareImage(image, 16, 16, this))
		;
	}
	size = new Dimension(image.getWidth(this) + 2 * INSET + 2 * BORDER,
			     image.getHeight(this) + 2 * INSET + 2 * BORDER);
    }

    public void setActionCommand(String cmd) {
	ac = cmd;
    }

    public void addActionListener(ActionListener al) {
	this.al = al;
    }

    public Dimension getMinimumSize() {
        return size;
    }

    public Dimension getPreferredSize() {
        return size;
    }

    public void paint(Graphics g) {
	g.setColor(getBackground());
	g.fill3DRect(INSET, INSET,
		     size.width - 2 * INSET, size.height - 2 * INSET,
		     !depressed);
	g.drawImage(image,
		    INSET + BORDER,
		    INSET + BORDER, this);
    }

    public void mousePressed(MouseEvent e) {
	depressed = true;
        repaint();
    }

    public void mouseReleased(MouseEvent e) {
	depressed = false;
        repaint();
    }

    public void mouseClicked(MouseEvent e) {
	if (al != null) {
	    al.actionPerformed(new ActionEvent(this, 0, ac, e.getModifiers()));
	}
    }

    public void mouseEntered(MouseEvent e) {
    }

    public void mouseExited(MouseEvent e) {
    }
}
