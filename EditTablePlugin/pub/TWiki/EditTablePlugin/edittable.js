// sEditTable.js
//
// By Byron Darrah
//
// This code adds support to the TWiki EditTablesPlugin for dynamically
// manipulating rows within a table.
// 
// Small refactoring by Arthur Clemens

/**

*/
// Global variables

var sEditTable; // array of edittables
var sRowSelection;
var sAlternatingColors = {even:null, odd:null};
var sAlternatingDefaultColors = {even:"#ffffff", odd:"#ffffff"};

/**

*/
// Here's a custom version of getElementByTagName.  I find it easier
// to debug certain problems this way when a script doesn't seem to be
// finding the node we'd expect.

function searchNodeTreeForTagName(node, tag_name) {
  if (node.tagName == tag_name) { return node; }
  for(var child = node.firstChild; child != null; child = child.nextSibling) {
    var r = searchNodeTreeForTagName(child, tag_name);
    if(r != null) { return r;}
  }
}

function hasClass(el, className) {
	var re = new RegExp('(?:^|\\s+)' + className + '(?:\\s+|$)');
	return re.test(el['className']);
}      
function addClass(el, className) {
	if (hasClass(el, className)) { return; } // already present
	el['className'] = [el['className'], className].join(' ');
}
function removeClass(el, className) {
	if (!hasClass(el, className)) { return; } // not present
	var re = new RegExp('(?:^|\\s+)' + className + '(?:\\s+|$)', 'g');
	var c = el['className'];
	el['className'] = c.replace( re, ' ');
}
      
/**

*/

// Build the list of edittables.
function edittableInit(form_name, asset_url) {

  // The form we want is actually the second thing in the
  // document that has the form_name.
  var tableform = document.getElementsByName(form_name)[1];
  
  if(tableform == null) {
    alert("Error: EditTable features cannot be enabled.\n");
    return;
  }
  attachEvent(tableform, 'submit', submitHandler);

  var somerow = searchNodeTreeForTagName(tableform, "TR");
  if(somerow != null) {
    var row_container = somerow.parentNode;
    sEditTable = new EditTableObject(tableform, row_container);
    insertActionButtons(asset_url);
  }
  sRowSelection = new RowSelectionObject();
  retrieveAlternatingRowColors();
  fixStyling();
}

/**

*/
// Create the etrow_id# inputs to tell the server about row changes we made.
function submitHandler(evt) {
  var inp, ilen = sEditTable.numrows;
  for(var i=0; i<ilen; i++) {
    var inpname = 'etrow_id'+(i+1);
    var row_id  = sEditTable.revidx[i]+1;
    inp = document.createElement('INPUT');
    inp.setAttribute('type', 'hidden');
    inp.setAttribute('name', inpname);
    inp.setAttribute('value', '' + row_id);
    sEditTable.tableform.appendChild(inp);
  }
  return true;
}

/**

*/
function attachEvent(obj, evtype, handler) {
  if(window.addEventListener){ // Mozilla, Netscape, Firefox
    obj.addEventListener(evtype, handler, false);
  } else { // IE
    obj.attachEvent('on' + evtype, handler);
  }
}

/**

*/
function detachEvent(obj, evtype, handler) {
  if(window.addEventListener){ // Mozilla, Netscape, Firefox
    obj.removeEventListener(evtype, handler, false);
  } else { // IE
    obj.detachEvent('on' + evtype, handler);
  }
}

/**

*/
function getEventAttr(evt, pname) {
  var e_out;
  var ie_var = "srcElement";
  var moz_var = "target";
  // "target" for Mozilla, Netscape, Firefox et al. ; "srcElement" for IE
  evt[moz_var] ? e_out = evt[moz_var][pname] : e_out = evt[ie_var][pname];
  return e_out;
}

/**

*/
function insertActionButtons(asset_url) {

  var rownr=0;
  var action_cell, action_butt;
  
  for(var child = sEditTable.row_container.firstChild; child != null;
          child = child.nextSibling) {
    if (child.tagName == 'TR') {
		action_cell = document.createElement('TD');
		addClass(action_cell, 'editTableActionCell');
		
		action_cell.id = 'et_actioncell' + rownr;
		{
			action_butt = document.createElement('IMG');
			var objLink = document.createElement("a");
			objLink.href = "#";
			objLink.setAttribute('title', 'Move row');
			objLink.appendChild(action_butt);
			action_butt.moveButtonSrc = asset_url + '/btn_move.gif';
			action_butt.targetButtonSrc = asset_url + '/btn_target.gif';
			action_butt.setAttribute('src', action_butt.moveButtonSrc);
			addClass(action_butt, 'editTableActionButton');
			action_butt.handler = moveHandler;
			attachEvent(action_butt, 'click', action_butt.handler);
			action_butt.rownr = rownr;
			action_cell.moveButton = action_butt;
			action_cell.appendChild(objLink);
		}
		{
			action_butt = document.createElement('IMG');
			var objLink = document.createElement("a");
			objLink.href = "#";
			objLink.setAttribute('title', 'Delete row');
			objLink.appendChild(action_butt);
			action_butt.enableButtonSrc = asset_url + '/btn_delete.gif';
			action_butt.disableButtonSrc = asset_url + '/btn_delete_disabled.gif';
			action_butt.setAttribute('src', asset_url + '/btn_delete.gif');
			addClass(action_butt, 'editTableActionButton');
			action_butt.handler = deleteHandler;
			attachEvent(action_butt, 'click', action_butt.handler);
			action_butt.rownr = rownr;
			action_cell.deleteButton = action_butt;
			action_cell.appendChild(objLink);
		}		
		child.insertBefore(action_cell, child.firstChild);
		rownr++;
    }
  }
  // set styling for the last action_cell to remove the bottom border
  addClass(action_cell, 'twikiLast');

}

/**

*/
function moveHandler(evt) {
	var rownr = getEventAttr(evt, 'rownr');
	if (sRowSelection.rownum == null) {
		var row_elem             = sEditTable.rows[rownr];
		var action_cell          = row_elem.firstChild;
		sRowSelection.row        = row_elem;
		sRowSelection.rownum     = rownr;
		var tableCells = row_elem.getElementsByTagName('TD');
		for (var i=0; i<tableCells.length; ++i) {
			addClass(tableCells[i], 'editTableActionSelectedCell');	
		}
	} else {
		moveRow(sRowSelection.rownum, rownr);
		var row_elem             = sEditTable.rows[sRowSelection.rownum];
		var tableCells = row_elem.getElementsByTagName('TD');
		for (var i=0; i<tableCells.length; ++i) {
			removeClass(tableCells[i], 'editTableActionSelectedCell');	
		}
		sRowSelection.row        = null;
		sRowSelection.rownum     = null;
	}
	switchDeleteButtons(evt);
	switchMoveButtonsToTargetButtons(evt, rownr);
}

/**

*/
function switchDeleteButtons (evt) {
	var rownr = getEventAttr(evt, 'rownr');
	var mode = (sRowSelection.rownum == null) ? 'to_enable' : 'to_disable';
	var ilen = sEditTable.rows.length;
	for (var i=0; i<ilen; ++i) {
		var row_elem = sEditTable.rows[i];
		var action_cell = row_elem.firstChild;
		var deleteButton = action_cell.deleteButton;
		deleteButton.src = (mode == 'to_enable') ? deleteButton['enableButtonSrc'] : deleteButton['disableButtonSrc'];
		if (mode == 'to_enable') {
			attachEvent(deleteButton, 'click', deleteButton.handler);
		} else {
			detachEvent(deleteButton, 'click', deleteButton.handler);
		}
	}
}

/**

*/
function switchMoveButtonsToTargetButtons (evt, selectedRow) {
	var rownr = getEventAttr(evt, 'rownr');
	var mode = (sRowSelection.rownum == null) ? 'to_move' : 'to_target';
	var ilen = sEditTable.rows.length;
	for (var i=0; i<ilen; ++i) {
		if (mode == 'to_target' && i == selectedRow) continue;
		var row_elem = sEditTable.rows[i];
		var action_cell = row_elem.firstChild;
		var moveButton = action_cell.moveButton;
		moveButton.src = (mode == 'to_target') ? moveButton['targetButtonSrc'] : moveButton['moveButtonSrc'];
	}
}


/**

*/
function deleteHandler(evt) {
  var rownr = getEventAttr(evt, 'rownr');

  var from_row_pos = sEditTable.positions[rownr];

  // Remove the from_row from the table.
  var row_container      = sEditTable.row_container;
  var from_row_elem      = sEditTable.rows[rownr];
  row_container.removeChild(from_row_elem);

  // Update all rows after from_row.
  for(var pos=from_row_pos+1; pos < sEditTable.numrows; pos++) {
    var rownum = sEditTable.revidx[pos];
    var newpos = pos-1;
    sEditTable.positions[rownum] = newpos;
    sEditTable.revidx[newpos]    = rownum;
    updateRowlabels(rownum, -1);
  }

  if (sRowSelection.rownum == rownr) {
    sRowSelection.row        = null;
    sRowSelection.rownum     = null;
  }

  sEditTable.numrows--;
  sEditTable.tableform.etrows.value = sEditTable.numrows;
  
  fixStyling();
}

/**

*/
function retrieveAlternatingRowColors () {
	var ilen = sEditTable.numrows;
	for (var i=0; i<ilen; ++i) {
		var tr = sEditTable.rows[i];
		var tableCells = tr.getElementsByTagName('TD');
		var alternate = (i%2 == 0) ? 'even': 'odd';
		for (var j=0; j<tableCells.length; ++j) {
			if (sAlternatingColors.even != null && sAlternatingColors.odd != null) continue;
			sAlternatingColors[alternate] = tableCells[j].getAttribute('bgColor');
		}
		if (sAlternatingColors.even != null && sAlternatingColors.odd != null) {
			return;
		}
	}
	if (!sAlternatingColors.odd) {
		sAlternatingColors.odd = sAlternatingDefaultColors.odd;
	}
	if (!sAlternatingColors.even) {
		sAlternatingColors.even = sAlternatingDefaultColors.even;
	}
}

/**
Style the last row.
*/
function fixStyling () {
	
	// style even/uneven rows
	var ilen = sEditTable.numrows;
	for (var i=0; i<ilen; i++) {
		var num = sEditTable.revidx[i];
		var tr = sEditTable.rows[num];
		var tableCells = tr.getElementsByTagName('TD');
		var alternate = (i%2 == 0) ? 'even': 'odd';
		var className = (i%2 == 0) ? 'twikiTableEven': 'twikiTableOdd';
		
		removeClass(tr, 'twikiTableEven');
		removeClass(tr, 'twikiTableOdd');
		addClass(tr, className);
		
		for (var j=0; j<tableCells.length; ++j) {
			var cell = tableCells[j];
			removeClass(cell, 'twikiLast');
			addClass(cell, className);
			cell.removeAttribute('bgColor');
			cell.setAttribute('bgColor', sAlternatingColors[alternate]);
		}
	}
	
	// style last row
	var lastRowNum = sEditTable.revidx[sEditTable.numrows-1];
	var lastRowElement = sEditTable.rows[lastRowNum];
	var tableCells = lastRowElement.getElementsByTagName('TD');
	for (var i=0; i<tableCells.length; ++i) {
		addClass(tableCells[i], 'twikiLast');
	}
	
}

/**

*/
function moveRow(from_row, to_row) {
  var from_row_pos = sEditTable.positions[from_row];
  var to_row_pos   = sEditTable.positions[to_row];

  var inc = 1;
  if(to_row_pos == -1 || from_row_pos > to_row_pos) {
    inc=-1;
  }
  if (from_row == to_row) { return; }

  // Remove the from_row from the table.
  var row_container      = sEditTable.row_container;
  var from_row_elem      = sEditTable.rows[from_row];
  workaroundIECheckboxBug(from_row_elem);
  row_container.removeChild(from_row_elem);

  // Update all rows after from_row up to to_row.
  for(var pos=from_row_pos+inc; pos != to_row_pos+inc; pos+=inc) {
    var rownum = sEditTable.revidx[pos];
    var newpos = pos-inc;
    sEditTable.positions[rownum] = newpos;
    sEditTable.revidx[newpos]    = rownum;
    updateRowlabels(rownum, -inc);
  }

  var insertion_target = sEditTable.rows[to_row];
  if (inc == 1) {
    insertion_target = insertion_target.nextSibling;
  }
  if(insertion_target == null) {
    row_container.appendChild(from_row_elem);
  } else {
    row_container.insertBefore(from_row_elem, insertion_target);
  }
  sEditTable.positions[from_row] = to_row_pos;
  sEditTable.revidx[to_row_pos]  = from_row;
  updateRowlabels(from_row, to_row_pos-from_row_pos);

	fixStyling();
}

/**

*/
// IE will reset checkboxes to their default state when they are moved around
// in the DOM tree, so we have to override the default state.

function workaroundIECheckboxBug(container) {
  var elems = container.getElementsByTagName('INPUT');
  for(var i=0; elems[i] != null; i++) {
    var inp = elems[i];
    if(inp['type'] == 'radio') {
      inp['defaultChecked'] = inp['checked'];
    }
  }
}

/**

*/

function RowSelectionObject() {
  this.row        = null;
  this.rownum     = null;
  return this;
}

/**

*/

function EditTableObject(tableform, row_container) {
  this.tableform           = tableform;
  this.row_container       = row_container;
  this.rows                = new Array();
  this.positions           = new Array();
  this.rowids              = new Array();
  this.revidx              = new Array();
  this.numrows             = 0;
  var row_elem             = row_container.firstChild;

  while(row_elem != null) {
    if(row_elem.tagName == "TR") {
      this.rows[this.numrows]       = row_elem;
      this.positions[this.numrows]  = this.numrows;
      this.revidx[this.numrows]     = this.numrows;
      this.rowids[this.numrows]     = 'tr' + (this.numrows+1);
      this.numrows++;
    }
    row_elem = row_elem.nextSibling;
  }
  return this;
}

/**

*/

function etsubmit(formid) {
  var form      = document.getElementById(formid);
  var table_num = parseInt(form.tablenum.value);
  var table_obj = edittables[table_num];
  if(table_obj.positions.length < 1) {
    return true;
  }

  var pos_str = table_obj.positions[0] + '';
  for(var i = 1; i < table_obj.numrows; i++) {
    pos_str = pos_str + ',' + table_obj.positions[i];
  }
  form.etrowpos.value = pos_str;
  return true;
}

/**

*/
// Update all row labels in a row by adding a delta amount to each one.

function updateRowlabels(rownum, delta) {
  var row=sEditTable.rows[rownum];
  var label_nodes = row.getElementsByTagName('DIV');
  for(var i=0; label_nodes[i] != null; i++) {
    var lnode = label_nodes[i];
    if (lnode.className == 'et_rowlabel') {
      var input_node = lnode.getElementsByTagName('INPUT').item(0);
      var new_val    = parseInt(input_node.value);
      if(isNaN(new_val)) { new_val  = '????'; }
      else               { new_val  = '' + (new_val+delta);  }
      input_node.value = new_val;
      while(lnode.firstChild != null) {
        lnode.removeChild(lnode.firstChild);
      }
      // Create a new row label span to replace the old one.
      var new_text     = document.createTextNode(new_val);
      lnode.appendChild(new_text);
      lnode.appendChild(input_node);
    }
  }

}

/**

*/
// EOF: sEditTable.js
