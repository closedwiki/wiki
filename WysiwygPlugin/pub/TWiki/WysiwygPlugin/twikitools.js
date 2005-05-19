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

/*
 * generic toggler tags. Will add a new tag of the given type,
 * or delete an enclosing tag if the burron is pressed (as
 * established by the associated checker)
 */
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

/* Move the contents of the selection into the node, and insert the
 * node in place of the selection.
 * I can't understand why this isn't a standard Kupu method!
 */
function TWikiInsertNode(editor,elem) {
  var selection = editor.getSelection();
  var cloned = selection.cloneContents();
  editor.insertNodeAtSelection(elem);
  while (cloned.hasChildNodes()) {
    elem.appendChild(cloned.firstChild);
  };
  selection.selectNodeContents(elem);
};

/* Generic derivative of KupuRemoveELementButton, checks the class as well
 */
function TWikiRemoveElementButton(buttonid, element_name, deadclass, offclass) {
    this.button = window.document.getElementById(buttonid);
    this.onclass = 'invisible';
    this.offclass = offclass;
    this.pressed = false;

    this.commandfunc = function(button, editor) {
      var elem = this.editor.getNearestParentOfType(currnode, deadclass);
      while (elem && elem.className.indexOf(this.deadclass) >= 0) {
        elem = this.editor.getNearestParentOfType(elem, element_name);
      }
      if (elem ) {
        elem.removeNode(true);
      } else {
        alert("Not inside a variable span");
      }
    };

    this.checkfunc = function(currnode, button, editor, event) {
      var elem = this.editor.getNearestParentOfType(currnode, deadclass);
      while (elem && elem.className.indexOf(this.deadclass) >= 0) {
        elem = this.editor.getNearestParentOfType(elem, element_name);
      }
      return (elem ? false : true );
    };
};

TWikiRemoveElementButton.prototype = new KupuStateButton;

/* Shared drawer spec used for all picklist drawers (drawers that just
 * contain a single pre-populated select
 */
function TWikiPickListDrawer(elementid, selector_id, tool) {
  this.varSelect = document.getElementById(selector_id);
  this.element = document.getElementById(elementid);
  this.tool = tool;

  this.save = function() {
    this.tool.pick(this.varSelect.options[this.varSelect.selectedIndex].value);
  };
};

TWikiPickListDrawer.prototype = new Drawer;

/* Tool for inserting the url of an attachment into the document.
 */
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

/* UI for adding an attachment to the select in the attachment insert drawer */
function TWikiNewAttachmentDrawer(drawerid, formid, selectid) {
  this.element = document.getElementById(drawerid);
  this.select = document.getElementById(selectid);
  this.form = document.getElementById(formid);

  this.save = function() {
    var path = this.form.filepath.value;
    var last = path.lastIndexOf('/');
    if (last < 0)
      last = path.lastIndexOf('\\');
    last++;
    var filename = path.substring(last);

    // Add the new filename to the select list for attachments
    var currnode = this.select.firstChild;
    var alreadyThere = false;
    while (currnode) {
      var name = currnode.name;
      if (name == filename) {
        alreadyThere = true;
        break;
      }
      currnode = currnode.nextSibling;
    }

    if (!alreadyThere) {
      var elem = document.createElement("option");
      elem.name = filename;
      elem.appendChild(document.createTextNode(filename));
      this.select.appendChild(elem);
    }

    this.editor.updateState();
  };
};

TWikiNewAttachmentDrawer.prototype = new Drawer;

/* Tool for inserting TWiki variables. The variables are in a select */
function TWikiVarTool(){
  this.initialize = function(editor) {
    /* tool initialization : nothing */
    this.editor = editor;
  };
 
  this.pick = function(name) {
    var doc = this.editor.getInnerDocument();
    var elem = doc.createElement('span');
    elem.setAttribute('class', 'TMLvariable');
    elem.appendChild(doc.createTextNode(name));
    // stomp anything already selected
    this.editor.insertNodeAtSelection(elem);
    this.editor.updateState();
  };
}

TWikiVarTool.prototype = new KupuTool;

/* Tool for inserting a new verbatim region, around whatever is selected */
function TWikiVerbatimTool(buttonid){
  this.button = document.getElementById(buttonid);

  this.initialize = function(editor) {
    /* tool initialization : nothing */
    this.editor = editor;
    addEventHandler(this.button, "click", this.insert, this);
    this.editor.logMessage('Verbatim tool initialized');
  };
 
  this.insert = function() {
    var doc = this.editor.getInnerDocument();
    var elem = doc.createElement('pre');
    elem.setAttribute('class', 'TMLverbatim');
    TWikiInsertNode(this.editor, elem);
    this.editor.updateState();
  };
}

TWikiVerbatimTool.prototype = new KupuTool;

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
  
  this.show = function() {
    /* show the chooser */
    this.imwindow.style.display = "block";
  };

  this.hide = function() {
    /* hide the chooser */
    this.imwindow.style.display = "none";
  };

  this.chooseImage = function(evt) {
    /* insert chosen image (delegate to createImage) */
    // event handler for choosing the color
    var target = _SARISSA_IS_MOZ ? evt.target : evt.srcElement;
    this.createImage(target);
    this.hide();
    this.editor.logMessage('TWiki Image chosen');
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
 
/* Tool for inserting NOP */
function TWikiNOPTool(buttonid){
  this.imgbutton = document.getElementById(buttonid);
  
  this.initialize = function(editor) {
    /* attach events handlers and hide images' panel */
    this.editor = editor;
    addEventHandler(this.imgbutton, "click", this.insertNOP, this);
    this.editor.logMessage('NOP tool initialized');
  };

  this.insertNOP = function(evt) {
    var doc = this.editor.getInnerDocument();
    var nop = doc.createElement('span');
    nop.setAttribute('class', 'TMLnop');
    nop.appendChild(doc.createTextNode('X'));
    this.editor.insertNodeAtSelection(nop);
  };
}

TWikiNOPTool.prototype = new KupuTool;

/* Tool for inserting wikiwords */
function TWikiWikiWordTool() {
  this.pick = function(wikiword) {
    var editor = this.editor;
    var url = editor.config.view_url+editor.config.current_web+'/'+wikiword;
    var doc = editor.getInnerDocument();
    var elem = doc.createElement('a');
    elem.setAttribute('href', url);
    var selection = editor.getSelection();
    if (selection) {
      if ( selection.startNode() == selection.endNode()) {
        var startoffset = selection.startOffset();
        var endoffset = selection.endOffset();
        if (endoffset == startoffset) {
          // nothing selected, just an insertion point
          elem.appendChild(doc.createTextNode(wikiword));
        }
      }
    } else {
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

/* Hack bad buttons off the form */
function TWikiCleanForm() {
  var elems = document.getElementsByName('submitChangeForm');
  for (var i = 0; i < elems.length; i++) {
    if (elems[i].nodeName.toLowerCase() == 'input' &&
        elems[i].type.toLowerCase() == 'submit' ) {
      elems[i].parentNode.removeChild(elems[i]);
      // should replace with _nice_ button?
    }
  }
}
