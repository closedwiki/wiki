/*
 * Copyright (C) 2005 ILOG http://www.ilog.fr
 * Portions Copyright (C) 2004 Damien Mandrioli and Romain Raugi
 * Portions Copyright (C) 2003-2004 Kupu Contributors. All rights reserved.
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
 */

function TWiki3StateButton(buttonid, check, command,
                           clazz) {
    /* A button that can have two states (e.g. pressed and
       not-pressed) based on CSS classes */
    this.button = window.document.getElementById(buttonid);
    this.command = command;
    this.parentcheck = parentFinder(check);
    this.childcheck = childFinder(check);
    this.clazz = clazz;
    this.state = 0;

    this.execCommand = function() {
      this.command(this, this.editor);
      this.editor.updateState();
      this.editor.focusDocument();
    };

    this.updateState = function(selNode, event) {
      var state = this.state;
      if (this.parentcheck(selNode, this, this.editor, event)) {
        state = 2;
      } else if (this.childcheck(selNode, this, this.editor, event)) {
        state = 1;
      } else {
        state = 0;
      }
      if (state != this.state) {
        this.button.className = this.clazz + state;
        this.state = state;
      }
    };
};

TWiki3StateButton.prototype = new KupuButton;

/* Exec function for formatting using a TWiki3StateButton.
 * checker - checks if a node matches criteria
 * creator - manipulates the selection so it meets the criteria
 * cleaner - manipulates a node so it doesn't meet the criteria,
 * removing the node if appropriate.
 */
function TWiki3StateToggler(checker, creator, cleaner) {
  var parentfn = parentFinder(checker);
  var childfn = childFinder(checker);

  return function (button, editor) {
    var node = editor.getSelectedNode();
    node = parentfn(node, button, editor, null);

    if (node) {
      cleaner(node);
    } else {
      node = editor.getSelectedNode();
      var c = childfn(node, button, editor, null);
      if (c) {
        for (var i = 0; i < c.length; i++) {
          cleaner(c[i]);
        }
      } else {
        creator(this.editor);
      }
    }
    editor.updateState();
  }
};

/* get a function that returns the boolean inverse of the result from the
   function passed. Used to allow parentFinder and childFinder to be used with
   KupuStateButton */
function notted(fn) {
  return function(selNode, button, editor, event) {
    return !fn(selNode, button, editor, event);
  };
}

/* Used to combine "has" functions together */
function hasOne(fn1,fn2) {
  return function(node) {
    return fn1(node) || fn2(node);
  };
}

/* get a function to find the first parent that triggers the check function */
function parentFinder(check) {
    return function(selNode, button, editor, event) {
      var node = selNode;
      if (!node) return null;
      while (node) {
        if (check(node))
          return node;
        node = node.parentNode;
      }
      return null;
    };
}

/* Get a method to check if a node has one of the specified tag names */
function hasTag(tagnames) {
  return function (node) {
    if (node.tagName) {
      var name = node.tagName.toLowerCase();
      for (var i = 0; i < tagnames.length; i++) {
        if (name == tagnames[i])
          return true;
      }
    }
    return false;
  };
}

/* Get a method that returns true if a node has a certain class */
function hasClass(clazz) {
  return function (node) {
    if (node.nodeType != 3 && node.className) {
      var c = node.className.split(' ');
      for (var i = 0; i < c.length; i++ ) {
        if (clazz == c[i]) {
          return true;
        }
      }
    }
    return false;
  };
}

/* get a function to check if a node has the given style. */
function hasStyle(style, stylevalue) {
  return function(node) {
    return (style && node.style && node.style[style] == stylevalue);
  };
};

/* get a function to create a new node over the selection,
   simply to add class */
function coverSelection(tag, clazz) {
  return function (editor) {
    var doc = editor.getInnerDocument();
    var elem = doc.createElement(tag);
    if (clazz)
      elem.className = clazz;
    _insertNode(editor, elem);
  };
}

function classCleaner(clazz) {
  return function (n) {
    _removeClass(n, clazz);
  };
}

function tagCleaner() {
  return function (n) {
    _removeNode(n);
  };
}

/* Get a function to iterate depth-first over non-text nodes below the
 * selection, and return an array of those that the "check" function
 * returned true for. */
function childFinder(check) {
  return function(selNode, button, editor, event) {
    var c = null;
    var sel = editor.getSelection();
    if (!selNode) return null;
    var nodeQueue = new Array(selNode);
    while (nodeQueue.length > 0) {
      var node = nodeQueue.pop();
      if (check(node)) {
        if (!c) c = new Array();
        c.push(node);
      }
      for (var i = 0; i < node.childNodes.length; i++) {
        var kid = node.childNodes[i];
        if (kid.nodeType != 3 && sel.containsNode(kid)) {
          nodeQueue.push(node.childNodes[i]);
        }
      }
    }
    return c;
  }
}

// remove a class, and if the tag the class is removed from matches
// and has no other class, remove the tag as well.
function TWikiRemoveClassButton(buttonid, checker, tag, clazz, cssclass) {
    this.button = window.document.getElementById(buttonid);
    this.onclass = cssclass;
    this.offclass = 'invisible';
    this.pressed = false;
    this.checkfunc = checker;

    this.commandfunc = function(button, editor) {
      var node = this.checkfunc(editor.getSelectedNode(), this.button,
                              editor, null);
      if (node) _removeClass(node, clazz);
    };
};

TWikiRemoveClassButton.prototype = new KupuStateButton;

// exec function that adds a tag/class over the current selection
function TWikiTagToggler(tag, clazz, checker) {
  return function (button, editor) {
    var sel = editor.getSelectedNode();
    var node = checker(sel, button, editor, null);
    if (node) {
      _removeClass(node, clazz);
    } else if (!button.pressed) {
      var doc = editor.getInnerDocument();
      var elem = doc.createElement(tag);
      elem.className = clazz;
      _insertNode(editor, elem);
    }
    editor.updateState();
  }
}

/* Move the contents of the selection into the node, and insert the
 * node in place of the selection.
 * I can't understand why this isn't a standard Kupu method!
 */
function _insertNode(editor,elem) {
  var selection = editor.getSelection();
  var cloned = selection.cloneContents();
  while (cloned.hasChildNodes()) {
    elem.appendChild(cloned.firstChild);
  };
  selection.replaceWithNode(elem, true);
};

/* Remove a node completely */
function _removeNode(node) {
    var parent = node.parentNode;
    while (node.childNodes.length) {
      var child = node.firstChild;
      child = node.removeChild(child);
      parent.insertBefore(child, node);
    };
    parent.removeChild(node);
}

/* remove the class from the node, and if the node is the given type and
 is left with no class, remove the node as well */
function _removeClass(node, clazz) {
  var c = node.className.split(' ');
  for (var i = 0; i < c.length; i++) {
    if (c[i] == clazz) {
      c.splice(i, 1);
      break;
    }
  }
  // if the node has no class, kill it completely
  if (c.length == 0) {
    _removeNode(node);
  } else {
    node.className = join(' ', c);
  }
}

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
      var sel = this.editor.getSelection();
      if (sel) {
        sel.replaceWithNode(elem);
      } else {
        sel.insertNodeAtSelection(elem);
      }
    } catch(exception) {
      alert("Something unexpected happened");
    }
    this.editor.updateState();
  };
}

TWikiInsertAttachmentTool.prototype = new KupuTool;

/* UI for adding an attachment */
function TWikiNewAttachmentDrawer(drawerid, formid, tool) {
  this.element = document.getElementById(drawerid);
  this.form = document.getElementById(formid);
  this.tool = tool;

  this.save = function() {
    if (this.tool) {
      var path = this.form.filepath.value;
      var last = path.lastIndexOf('/');
      if (last < 0)
        last = path.lastIndexOf('\\');
      last++;
      var filename = path.substring(last);

      this.tool.pick(filename);
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
    var elem;

    // if using spans for variables
    //    elem = doc.createElement('span');
    //    elem.setAttribute('class', 'TMLvariable');
    //    elem.appendChild(doc.createTextNode(name));
    // else
          elem = doc.createTextNode('%'+name+'%');
    // endif

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
 
/* Tool for inserting a new NOP region, around whatever is selected */
/* if already in a region of that type, remove the region */
function TWikiNOPTool(buttonid){
  this.button = document.getElementById(buttonid);

  this.initialize = function(editor) {
    /* tool initialization : nothing */
    this.editor = editor;
    addEventHandler(this.button, "click", this.insert, this);
    this.editor.logMessage('NOP tool initialized');
  };
 
  this.insert = function() {
    var doc = this.editor.getInnerDocument();
    var elem = doc.createElement('span');
    elem.setAttribute('class', 'TMLnop');
    _insertNode(this.editor, elem);
    this.editor.updateState();
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
    _insertNode(editor, elem);
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
  var form = document.getElementById('twiki-main-form');
  
  // don't know how else to get the kupu singleton
  var kupu = window.drawertool.editor;

  // use prepareForm to create the 'text' field
  kupu.prepareForm(form, 'text');
};

function stringify(node) {
  if (!node)
    return "NULL";
  var str = node.nodeName + "{";
  if (node.nodeName == '#text') {
    str = str + '"' + node.nodeValue + '"';
  } else {
    var node = node.firstChild;
    var n = 0;
    while (node) {
      if (n) str = str + ",";
      str = str + stringify(node);
      n++;
      node = node.nextSibling;
    }
  }
  return str + "}";
}

/* Hack bad buttons off the form on startup */
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

function TWikiColorChooserTool(fgcolorbuttonid, colorchooserid) {
    /* the colorchooser */
    
    this.fgcolorbutton = document.getElementById(fgcolorbuttonid);
    this.ccwindow = document.getElementById(colorchooserid);
    this.command = null;

    this.initialize = function(editor) {
        /* attach the event handlers */
        this.editor = editor;
        
        this.createColorchooser(this.ccwindow);

        addEventHandler(this.fgcolorbutton, "click", this.openFgColorChooser, this);
        addEventHandler(this.ccwindow, "click", this.chooseColor, this);

        this.hide();

        this.editor.logMessage('Colorchooser tool initialized');
    };

    this.updateState = function(selNode) {
        /* update state of the colorchooser */
        this.hide();
    };

    this.openFgColorChooser = function() {
        /* event handler for opening the colorchooser */
        this.command = "forecolor";
        this.show();
    };

    this.chooseColor = function(event) {
        /* event handler for choosing the color */
        var target = _SARISSA_IS_MOZ ? event.target : event.srcElement;
        var cell = this.editor.getNearestParentOfType(target, 'td');
        this.editor.execCommand(this.command, cell.getAttribute('bgColor'));
        this.hide();
    
        this.editor.logMessage('Color chosen');
    };

    this.show = function(command) {
        /* show the colorchooser */
        this.ccwindow.style.display = "block";
    };

    this.hide = function() {
        /* hide the colorchooser */
        this.command = null;
        this.ccwindow.style.display = "none";
    };

    this.createColorchooser = function(table) {
        /* create the colorchooser table */
      var cols = new Array( "black", "gray", "silver", "white",
                            "maroon", "purple", "red", "fuschia",
                            "green", "olive", "lime", "yellow",
                            "navy", "teal", "blue", "aqua" );
        table.setAttribute('id', 'kupu-colorchooser-table');
        table.style.borderWidth = '2px';
        table.style.borderStyle = 'solid';
        table.style.position = 'absolute';
        table.style.cursor = 'default';
        table.style.display = 'none';

        var tbody = document.createElement('tbody');

        for (var i=0; i < 4; i++) {
            var tr = document.createElement('tr');
            for (var j = 0; j < 4; j++) {
              var color = cols[i * 4 + j];;
              var td = document.createElement('td');
              td.setAttribute('bgColor', color);
              td.style.borderWidth = '1px';
              td.style.borderStyle = 'solid';
              td.style.fontSize = '1px';
              td.style.width = '10px';
              td.style.height = '10px';
              var text = document.createTextNode('\u00a0');
              td.appendChild(text);
              tr.appendChild(td);
            }
            tbody.appendChild(tr);
        }
        table.appendChild(tbody);

        return table;
    };
}

TWikiColorChooserTool.prototype = new KupuTool;

// only check max if max > min
function twikiVerifyNumber(name,id,min,max) {
  var field = window.document.getElementById(id);
  var error = "";

  var charpos = field.value.search("[^0-9]");
  if (field.value.length > 0 && charpos >= 0) {
    error = name + ": Only digits allowed\n[Error at character position " +
      eval(charpos + 1) + "]";
  }
  if (error.length == 0 && isNaN(field.value)) {
    error = name + " is not a number";
  }
  if (error.length == 0 && field.value < min) {
    error = name + " must be >= " + min;
  }
  if (error.length == 0 && max > min && field.value > max) {
    error = name + " must be <= " + max;
  }

  if (error.length > 0) {
    alert(error);
    field.focus();
    return false;
  };

  return true;
}

function TWikiSelect(id, tool) {
    this.selector = window.document.getElementById(id);
    this.tool = tool;

    this.initialize = function(editor) {
        this.editor = editor;
        this._fixTabIndex(this.selector);
        addEventHandler(this.selector, 'change', this.execCommand, this);
    };

    this.execCommand = function() {
        this.tool.pick(this.selector.options[this.selector.selectedIndex].value);
        this.editor.focusDocument();
    };
}

TWikiSelect.prototype = new KupuTool;
