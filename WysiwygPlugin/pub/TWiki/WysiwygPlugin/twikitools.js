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

/* Tool for attaching files. Attaching a file is a complex process; it
 * involves dispatching the TWiki upload script, and optionally inserting
 * a reference in the document itself. */

function TWikiAttachTool(){
  this.initialize = function(editor) {
    this.editor = editor;
    this.editor.logMessage('Attachments tool initialized');
  };

  this.attach = function(file) {
    /* We want to fire a post off to the server, but we're not that
     * interested in what comes back. */
    /* The path is going to be .../WEB/TOPIC/file. We can work it out... */
    alert("Path was " + file);
  }
};

function insertRefToAttachment(path, filename) {
  if (filename.toLowerCase().match(".*\.jpg$") ||
      filename.toLowerCase().match(".*\.gif$") ||
      filename.toLowerCase().match(".*\.jpeg$")||
      filename.toLowerCase().match(".*\.png$")) {
              
    var elem = this.kupu.document.document.createElement("img");
    elem.setAttribute('src', path);
    try {
      if ( this.kupu.getSelection() ) {
        this.kupu.getSelection().replaceWithNode(elem);
      } else {
        this.kupu.getSelection().insertNodeAtSelection(elem);
      };
    } catch( exception ) {};
  } else {
    var elem = this.kupu.document.document.createElement("a");
    elem.setAttribute('href', path);
    elem.appendChild(this.kupu.document.document.createTextNode(filename));
    try {
      if ( this.kupu.getSelection() ) {
        this.kupu.getSelection().replaceWithNode(elem);
      } else {
        this.kupu.getSelection().insertNodeAtSelection(elem);
      };
    } catch(exception) {};
  }
}

TWikiAttachTool.prototype = new KupuTool;

function TWikiAttachUI(file_id, button_id) {
  this.varFile = document.getElementById(file_id);
  this.varButton = document.getElementById(button_id);
    
  this.initialize = function(tool, editor) {
    /* tool initialization */
    this.tool = tool;
    this.editor = editor;
    addEventHandler(this.varButton, "click", this.attach, this);          
  };
  
  this.attach = function() {
    this.tool.attach(this.varFile.value);
  };
};

TWikiAttachUI.prototype = new KupuToolBox;

/* Tool for inserting TWiki variables. The variables are
 * in a <select> */
function TWikiVarTool(){
  this.initialize = function(editor) {
    /* tool initialization : nothing */
    this.editor = editor;
  };
 
  this.createVar = function(name){
    /* create span classed variable */
    var doc = this.editor.getInnerDocument();
    var span = doc.createElement('span');
    span.className = "TMLVariable";
    this.editor.insertNodeAtSelection(span, 1);
    var tex = doc.createTextNode(name);
    span.appendChild(tex);
  };
    
  this.completeState = function( selNode, evt ) {
    /* cancel EOL effect when pressed in variable span */
    var keyCode = 0;
    if (evt) keyCode = evt.keyCode;
    // EOL special treatment in Mozilla-like browsers
    if (this.editor.getBrowserName() == 'Mozilla' &&
        keyCode == 13 && selNode.className == 'TMLVariable') {
      // Put EOL at the end of the span block
      var nodes = selNode.childNodes;
      var toAdd = new Array(nodes.length);
      var k = 0;
      var i = 0;
      while ( i < nodes.length ) {
        if (nodes[i].nodeType == 3 || nodes[i].className == 'TMLVariable') 
          toAdd[k++] = nodes[i];
        selNode.removeChild(nodes[i]);
      };
      var j = 0;
      while (j < k) {
        selNode.appendChild(toAdd[j++]);
      };
      var selection = this.editor.getDocument().getWindow().getSelection();
      // Create and select text after variable
      var afterNode = selNode.nextSibling;
      var newTextNode = this.editor.getInnerDocument().createTextNode("");
      selNode.parentNode.insertBefore(newTextNode, afterNode);
      selection.selectAllChildren(selNode.nextSibling);
    };
  };
};

TWikiVarTool.prototype = new KupuTool;

function TWikiVarUI(myselect, mybutton, topicbutton, plainclass, activeclass){
  this.varSelect = document.getElementById(myselect);
  this.varButton = document.getElementById(mybutton);
  
  this.initialize = function(tool, editor) {
    this.tool = tool;
    this.editor = editor;
    this.plainclass = plainclass;
    this.activeclass = activeclass;
    addEventHandler(this.varButton, "click", this.createVar, this);          
  };

  this.createVar = function(){
    this.tool.createVar(this.varSelect.options[this.varSelect.selectedIndex].value);
  }
}
  
TWikiVarUI.prototype = new KupuToolBox;

/* Tool for inserting smilies. The smilies are in a div, which is shown and
 * hidden as required to give the effect of a pupup panel  */
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
    this.createImage(target.getAttribute('src'));
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

  this.createImage = function(url) {
    /* insert image in document */
    var doc = this.editor.getInnerDocument();
    if ( url ) {
      var img = doc.createElement('img');
      img.setAttribute('src', url);
      try {
        img = this.editor.insertNodeAtSelection(img);
      } catch( exception ) { this.imwindow.style.display = "none"; };
    }
  }
}

TWikiIconsTool.prototype = new KupuTool;

/* Tool for inserting wikiwords */
function TWikiWikiWordTool(selector_id) {
  
  this.initialize = function(editor) {
    this.editor = editor;
    this.editor.logMessage('WikiWord tool initialized');
  };

  this.wikiWord = function(wikiword) {
    var no_selection;
    // test selection (insert or replace ?)
    if (this.editor.getBrowserName() == 'IE') {
      no_selection = ( this.editor.getInnerDocument().selection.type == "None" );
    } else {
      no_selection = ( this.editor.getSelection() == "" );
    };
    // put focus on editor
    if (this.editor.getBrowserName() == "IE") {
      this.editor._restoreSelection();
    } else {
      this.editor.getDocument().getWindow().focus();
    };
    // test if we are in <a> node
    var linkel = this.editor.getNearestParentOfType(currnode, 'A');
    if (linkel) {
      alert("Can't insert a link here; already linked somewhere else");
      return;
    }
    var link;

    if (no_selection) {
      /* No selection, create a new <A> */
      var doc = this.editor.getInnerDocument();
      link = doc.createElement('A');
      link.setAttribute('href', wikiword);
      link.className = 'TMLWikiWord';
      this.editor.insertNodeAtSelection(link, 1);
      link.appendChild(doc.createTextNode(wikiword));
    } else {
      /* selection, create an <A> spanning the selection */
      this.editor.execCommand("CreateLink", wikiword);
      var currnode = this.editor.getSelectedNode();
      if (this.editor.getBrowserName() == 'IE') {
        link = this.editor.getNearestParentOfType(currnode, 'A');
      } else {
        link = currnode.nextSibling;
      };
      link.className = 'TMLsquab';
    }
    this.editor.logMessage('Link added');
    this.editor.updateState();
  }; 
};

TWikiWikiWordTool.prototype = new KupuTool;

function TWikiWikiWordUI(selector_id, button_id){
  this.varSelect = document.getElementById(selector_id);
  this.varButton = document.getElementById(button_id);
  
  this.initialize = function(tool, editor) {
    /* attach the event handlers */
    this.tool = tool;
    this.editor = editor;
    addEventHandler(this.varButton, "click", this.onClick, this);          
  };

  this.onClick = function(){
    /* Call the tool to create a wikiword */
    this.tool.wikiWord(this.varSelect.options[this.varSelect.selectedIndex].value);
  }
}
  
TWikiWikiWordUI.prototype = new KupuToolBox;
