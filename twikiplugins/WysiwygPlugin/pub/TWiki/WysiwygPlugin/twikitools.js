/*****************************************************************************
 * 
 * Copyright (C) 2005 ILOG
 * Portions Copyright (C) 2004 Damien Mandrioli and Romain Raugi
 * Portions Copyright (c) 2003-2004 Kupu Contributors. All rights reserved.
 *  
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *  
 *****************************************************************************/

/* Shared drawer spec used for all picklist drawers */
function TWikiPickListDrawer(elementid, selector_id, tool) {
  this.varSelect = document.getElementById(selector_id);
  this.element = document.getElementById(elementid);
  this.tool = tool;

  this.save = function() {
    this.tool.pick(this.varSelect.options[this.varSelect.selectedIndex].value);
  };
};

TWikiPickListDrawer.prototype = new Drawer;

/* Tool for inserting the url of an attachment into the document. */
function TWikiInsertAttachmentTool() {
  this.initialize = function(editor) {
    this.editor = editor;
    this.editor.logMessage('InsertAttachmentmentTool initialized');
  };
  
  this.pick = function(filename) {
    var url = this.editor.config.attachment_url_path + '/' + filename;
    var tmp = filename.lastIndexOf(".");
    if (tmp >= 0)
      tmp = filename.substring(tmp + 1, filename.length);

    var doc = this.editor.getInnerDocument();
    var elem;
    if (tmp == "jpg" || tmp == "gif" || tmp == "jpeg" ||
        tmp == "png" || tmp == "bmp") {
      elem = doc.createElement("img");
      elem.setAttribute('src', url);
      elem.setAttribute('alt', filename);
    } else {
      elem = doc.createElement("a");
      elem.setAttribute('href', url);
      var text = this.editor.getInnerDocument().createTextNode(filename);
      elem.appendChild(text);
    }
    try {
      if (this.editor.getSelection()) {
        this.editor.getSelection().replaceWithNode(elem);
      } else {
        this.editor.getSelection().insertNodeAtSelection(elem);
      }
    } catch(exception) {
      alert("Something unexpected happened");
    }
    this.editor.updateState();
  };
}

TWikiInsertAttachmentTool.prototype = new KupuTool;

/* Tool for invoking the attachment screen for adding an attachment */
function TWikiNewAttachmentTool() {
  this.initialize = function(editor) {
    this.editor = editor;
    this.editor.logMessage('NewAttachmentmentTool initialized');
  };
  
  this.invoke = function(element) {
    alert("Picked save");
    //window.open(this.editor.config.upload_url, 'twikiattach' );
  };
}

TWikiNewAttachmentTool.prototype = new KupuTool;

function TWikiNewAttachmentDrawer(elementid, tool) {
  this.element = document.getElementById(elementid);
  this.tool = tool;

  this.save = function() {
    this.tool.invoke(this.element);
  };
};

TWikiNewAttachmentDrawer.prototype = new Drawer;

/* Tool for inserting TWiki variables. The variables are
 * in a <select> */
function TWikiVarTool(){
  this.initialize = function(editor) {
    /* tool initialization : nothing */
    this.editor = editor;
  };
 
  this.pick = function(name) {
    var doc = this.editor.getInnerDocument();
    var elem = doc.createElement('span');
    elem.className = 'TMLvariable';
    elem.appendChild(doc.createTextNode(name));
    // stomp anything already selected
    this.editor.insertNodeAtSelection(elem);
    this.editor.updateState();
  };
}

TWikiVarTool.prototype = new KupuTool;

/* Tool for inserting smilies. The smilies are collected in a div, which
 * is shown and hidden as required to give the effect of a popup panel.
 * The reson this is not a drawer is that it was implemented before
 * drawers existed (I think)  */
function TWikiIconsTool(buttonid, popupid){
  this.imgbutton = document.getElementById(buttonid);
  this.imwindow = document.getElementById(popupid);
  
  this.initialize = function(editor) {
    /* attach events handlers and hide images' panel */
    this.editor = editor;
    addEventHandler(this.imgbutton, "click", this.openImageChooser, this);
    addEventHandler(this.imwindow, "click", this.chooseImage, this);
    this.hide();
    this.editor.logMessage('Icons tool initialized');
  };

  this.updateState = function(selNode) {
    /* update state of the chooser */
    this.hide();
  };

  this.openImageChooser = function() {
    /* open the chooser pane */
    this.show();
  };
  
  this.chooseImage = function(evt) {
    /* insert chosen image (delegate to createImage) */
    // event handler for choosing the color
    var target = _SARISSA_IS_MOZ ? evt.target : evt.srcElement;
    this.createImage(target);
    this.hide();
    this.editor.logMessage('TWiki Image chosen');
  };

  this.show = function() {
    /* show the chooser */
    this.imwindow.style.display = "block";
  };

  this.hide = function() {
    /* hide the chooser */
    this.imwindow.style.display = "none";
  };

  this.createImage = function(template) {
    var doc = this.editor.getInnerDocument();
    var img = doc.createElement('img');
    img.setAttribute('src', template.getAttribute('src'));
    img.setAttribute('alt', template.getAttribute('alt'));
    img.classname = template.classname;
    try {
      img = this.editor.insertNodeAtSelection(img);
    } catch( exception ) {
      this.imwindow.style.display = "none";
    };
  };
}

TWikiIconsTool.prototype = new KupuTool;

/* Tool for inserting wikiwords */
function TWikiWikiWordTool() {
  this.pick = function(wikiword) {
    var editor = this.editor;
    var url = editor.config.view_url+editor.config.current_web+'/'+wikiword;
    var doc = editor.getInnerDocument();
    var elem = doc.createElement('a');
    elem.setAttribute('href', url);
    selection = editor.getSelection();
    var startoffset = selection.startOffset();
    var endoffset = selection.endOffset(); 
    if (endoffset == startoffset) {
      // nothing selected, just an insertion point
      elem.appendChild(doc.createTextNode(wikiword));
    }
    TWikiInsertNode(editor, elem);
    editor.updateState();
  };
};

TWikiWikiWordTool.prototype = new KupuTool;

/*
 * A submit can come from several places; from links inside the form
 * (replace form and add form) and from the Kupu save button, which is
 * redirected to the form. We need to create the 'text'
 * field for all these operations. The Kupu save button is handled by
 * the 'submitForm' function declared in kupuinit.js, but the links
 * have to be handled through the following onSubmit handler.
 */
function TWikiHandleSubmit() {
  alert("Called TWikiHandleSubmit");
  var form = document.getElementById('twiki-main-form');
  
  // don't know how else to get the kupu singleton
  var kupu = window.drawertool.editor;

  // use prepareForm to create the 'text' field
  kupu.prepareForm(form, 'text');
};

/*
 * Replace the standard saveOnPart to suppress the confirmation
 * prompt.
 */
function saveOnPart() {
  if (kupu.content_changed) {
    kupu.config.reload_src = 0;
  };
};

function TWikiToggleTag(button, editor, tag) {
  if (button.pressed) {
    var currnode = editor.getSelectedNode();
    var dead = editor.getNearestParentOfType(currnode, tag);
    if (!dead) {
      alert('Not inside a tag of type '+tag);
      return;
    };
    while (dead.childNodes.length) {
      dead.parentNode.insertBefore(dead.childNodes[0], dead);
    };
    dead.parentNode.removeChild(dead);
  } else {
    var doc = editor.getInnerDocument();
    var elem = doc.createElement(tag);
    TWikiInsertNode(editor,elem);
  }
  editor.updateState();
};

function stringify(node) {
  var str = node.nodeName + "{";
  if (node.nodeName == '#text') {
    str = str + '"' + node.nodeValue + '"';
  } else {
    var currnode = node.firstChild;
    var n = 0;
    while (currnode) {
      if (n) str = str + ",";
      str = str + stringify(currnode);
      n++;
      currnode = currnode.nextSibling;
    }
  }
  return str + "}";
}

/* Move the contents of the selection into the node, and insert the
 * node in place of the selection.
 * I can't understand why this isn't a standard Kupu method! */
function TWikiInsertNode(editor,elem) {
  var selection = editor.getSelection();
  var cloned = selection.cloneContents();
  editor.insertNodeAtSelection(elem);
  while (cloned.hasChildNodes()) {
    elem.appendChild(cloned.firstChild);
  };
  selection.selectNodeContents(elem);
};
