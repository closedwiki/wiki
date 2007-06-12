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
var sAlternatingColors = [];

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

	if (somerow != null) {
		var row_container = somerow.parentNode;
		sEditTable = new EditTableObject(tableform, row_container);
		insertActionButtons(asset_url);
		insertRowSeparators();
	}
	sRowSelection = new RowSelectionObject(asset_url);
	retrieveAlternatingRowColors();
	fixStyling();
  
  	var Behaviour;
	if (Behaviour) {
		var myrules = {
			// catch click on button "Add row"
			'#etaddrow' : function(element) {
				element.onclick = function() {
					addHandler(); // not implemented
					return true;
				}
				element = null;
			}
		};
		Behaviour.register(myrules);
	}
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

  var action_cell, action_butt;

  for(var rowpos = 0; rowpos < sEditTable.numrows; rowpos++) {
    var rownr = sEditTable.revidx[rowpos];
    var child = sEditTable.rows[rownr];
    if (child.tagName == 'TR') {
		action_cell = document.createElement('TD');
		addClass(action_cell, 'editTableActionCell');
		action_cell.id = 'et_actioncell' + rownr;
		{
			action_butt = document.createElement('IMG');
			action_butt.setAttribute('title', 'Move row');
			action_butt.moveButtonSrc = asset_url + '/btn_move.gif';
			action_butt.setAttribute('src', action_butt.moveButtonSrc);
			action_butt.handler = moveHandler;
			attachEvent(action_butt, 'click', action_butt.handler);
			addClass(action_butt, 'editTableActionButton');
			action_butt.rownr = rownr;
			action_cell.moveButton = action_butt;
			action_cell.appendChild(action_butt);
		}
		{
			action_butt = document.createElement('IMG');
			action_butt.setAttribute('title', 'Delete row');
			action_butt.enableButtonSrc = asset_url + '/btn_delete.gif';
			action_butt.disableButtonSrc = asset_url + '/btn_delete_disabled.gif';
			action_butt.setAttribute('src', asset_url + '/btn_delete.gif');
			action_butt.handler = deleteHandler;
			attachEvent(action_butt, 'click', action_butt.handler);
			addClass(action_butt, 'editTableActionButton');
			action_butt.rownr = rownr;
			action_cell.deleteButton = action_butt;
			action_cell.appendChild(action_butt);
		}		
		child.insertBefore(action_cell, child.firstChild);
    }
  }
  // set styling for the last action_cell to remove the bottom border
  addClass(action_cell, 'twikiLast');

}

/**

*/
function insertRowSeparators() {

  var child;
  var sep_row, columns;

  for(var rowpos = 0; rowpos < sEditTable.numrows; rowpos++) {
    var rownr = sEditTable.revidx[rowpos];
    child     = sEditTable.rows[rownr];
    columns = countRowColumns(child);
    sep_row = makeSeparatorRow(rownr, columns);
    child.parentNode.insertBefore(sep_row, child);
  }
  sep_row = makeSeparatorRow(null, columns);
  child.parentNode.appendChild(sep_row);
  sEditTable.last_separator = sep_row;
}


/**

*/
function makeSeparatorRow(rownr, columns) {
	var sep_row      = document.createElement('TR');
	var sep_cell     = document.createElement('TD');
	sep_cell.colSpan = columns;
	sep_cell.style.padding    = '0px';
	sep_cell.style.spacing    = '0px';
	sep_cell.style.border     = '0';
	sep_cell.style.height     = '4px';
	sep_cell.style.background = '#99B';
	sep_cell.rownr            = rownr;

	sep_row.style.padding = '0px';
	sep_row.style.spacing = '0px';
	sep_row.style.border  = '0';
	sep_row.style.height  = '4px';
	sep_row.rownr         = rownr;

	sep_row.appendChild(sep_cell);
	addClass(sep_row, 'editTableRowSeparator');
	sep_row.id       = 'et_rowseparator' + rownr;
	sep_row.ckhandler  = sepClickHandler;
	sep_row.mohandler  = sepMouseOverHandler;
	attachEvent(sep_row, 'click', sep_row.ckhandler);
	attachEvent(sep_row, 'mouseover', sep_row.mohandler);
	return sep_row;
}



/**

*/
function countRowColumns(row_el) {
	var count = 0;
	for(var tcell = row_el.firstChild; tcell != null;
		tcell = tcell.nextSibling) {
		if (tcell.tagName == 'TD' || tcell.tagName == 'TH') {
			count += tcell.colSpan;
		}
	}
	return count;
}

/**

*/
function selectRow(rownr) {
	if (rownr == null && sRowSelection.row == null) {
		return;
	}
	var top_image    = "none";
	var bottom_image = "none";

	if (rownr != null) {
		sRowSelection.row    = sEditTable.rows[rownr];
		sRowSelection.rownum = rownr;
		top_image            = "url(" + sRowSelection.topImage + ")";
		bottom_image         = "url(" + sRowSelection.bottomImage + ")";
		var sep_row = sRowSelection.row.previousSibling;
		sRowSelection.topSep = sep_row;
		
		var next_rowpos = sEditTable.positions[rownr]+1;
		if (next_rowpos < sEditTable.numrows) {
			var next_rownr = sEditTable.revidx[next_rowpos];
			sep_row = sEditTable.rows[next_rownr].previousSibling;
		} else {
			sep_row = sEditTable.last_separator;
		}
		sRowSelection.bottomSep = sep_row;
	}

	/* Set the style class of data cell elements in the selected row */
	var tableCells = sRowSelection.row.getElementsByTagName('TD');
	for (var i=0; i<tableCells.length; ++i) {
		if (rownr != null) {
			addClass(tableCells[i], 'editTableActionSelectedCell');
		} else {
			removeClass(tableCells[i], 'editTableActionSelectedCell');
		}
	}

	/* Place images of moving dashes above and below the selected row */
	if (sRowSelection.topSep != null) {
		var sepCells = sRowSelection.topSep.getElementsByTagName('TD');
		sepCells[0].style.backgroundImage = top_image;
		sepCells[0].style.backgroundRepeat = "repeat-x";
	}
	if (sRowSelection.bottomSep != null) {
		var sepCells = sRowSelection.bottomSep.getElementsByTagName('TD');
		sepCells[0].style.backgroundImage = bottom_image;
		sepCells[0].style.backgroundRepeat = "repeat-x";
	}
	if (rownr == null) {
		sRowSelection.row       = null;
		sRowSelection.rownum    = null;
		sRowSelection.topSep    = null;
		sRowSelection.bottomSep = null;
	}
}

/**

*/
function moveHandler(evt) {
	var rownr = getEventAttr(evt, 'rownr');
	if (sRowSelection.rownum != null) {
		return;
	}
	selectRow(rownr);
	switchDeleteButtons(evt);
}

/**

*/
function sepClickHandler(evt) {
	var rownr = getEventAttr(evt, 'rownr');
	if (sRowSelection.rownum == null) {
		return;
	}
	moveRow(sRowSelection.rownum, rownr);
	selectRow(null);
	switchDeleteButtons(evt);
}

/**

*/
function sepMouseOverHandler(evt) {
	var style = getEventAttr(evt, 'style');
	if (sRowSelection.rownum == null) {
		style.cursor = 'default';
	} else {
		style.cursor = 'move';
        }
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
function deleteHandler(evt) {
  var rownr = getEventAttr(evt, 'rownr');

  var from_row_pos = sEditTable.positions[rownr];

  // Remove the from_row from the table.
  var from_row_elem      = sEditTable.rows[rownr];
  from_row_elem.parentNode.removeChild(from_row_elem.previousSibling);
  from_row_elem.parentNode.removeChild(from_row_elem);

  // Update all rows after from_row.
  for(var pos=from_row_pos+1; pos < sEditTable.numrows; pos++) {
    var rownum = sEditTable.revidx[pos];
    var newpos = pos-1;
    sEditTable.positions[rownum] = newpos;
    sEditTable.revidx[newpos]    = rownum;
    updateRowlabels(rownum, -1);
  }

  if (sRowSelection.rownum == rownr) {
    selectRow(null);
  }

  sEditTable.numrows--;
  sEditTable.tableform.etrows.value = sEditTable.numrows;
  
  fixStyling();
}

/**
to write
*/
function addHandler() {
	//
}

/**

*/
function retrieveAlternatingRowColors () {
	var ilen = sEditTable.numrows;
	for (var i=0; i<ilen; ++i) {
		var tr = sEditTable.rows[i];
		var tableCells = tr.getElementsByTagName('TD');
		var alternate = (i%2 == 0) ? 0: 1;
		for (var j=0; j<tableCells.length; ++j) {
			if (sAlternatingColors[0] != null && sAlternatingColors[1] != null) continue;
			var color = tableCells[j].getAttribute('bgColor');
			if (color) sAlternatingColors[alternate] = color;
		}
		if (sAlternatingColors[0] != null && sAlternatingColors[1] != null) {
			return;
		}
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
		var alternate = (i%2 == 0) ? 0: 1;
		var className = (i%2 == 0) ? 'twikiTableEven': 'twikiTableOdd';
		
		if (!sAlternatingColors[alternate]) {
			continue;
		}
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
  var to_row_pos;


  // If the end separator row was selected, use the last row.
  if (to_row == null) {
    to_row_pos = sEditTable.numrows-1;
    to_row     = sEditTable.revidx[to_row_pos];
  } else {
    to_row_pos = sEditTable.positions[to_row];
    if (to_row_pos > from_row_pos) {
      to_row_pos--;
      to_row = sEditTable.revidx[to_row_pos];
    }
  }
  alert ('Moving row from ' + from_row_pos + ' to ' + to_row_pos);

  var inc = 1;
  if(to_row_pos == -1 || from_row_pos > to_row_pos) {
    inc=-1;
  }
  if (from_row == to_row) { return;   }

  // Remove the from_row from the table.
  var from_row_elem      = sEditTable.rows[from_row];
  var from_row_sep       = from_row_elem.previousSibling;
  workaroundIECheckboxBug(from_row_elem);
  from_row_elem.parentNode.removeChild(from_row_sep);
  from_row_elem.parentNode.removeChild(from_row_elem);

  // Update all rows after from_row up to to_row.
  for(var pos=from_row_pos+inc; pos != to_row_pos+inc; pos+=inc) {
    var rownum = sEditTable.revidx[pos];
    var newpos = pos-inc;
    sEditTable.positions[rownum] = newpos;
    sEditTable.revidx[newpos]    = rownum;
    updateRowlabels(rownum, -inc);
  }

  var insertion_target;
  if (inc == 1) {
    insertion_target = sEditTable.rows[to_row]
    insertAfter(from_row_elem, insertion_target);
    insertAfter(from_row_sep,  insertion_target);
  } else {
    insertion_target = sEditTable.rows[to_row].previousSibling;
    insertBefore(from_row_sep,  insertion_target);
    insertBefore(from_row_elem, insertion_target);
  }
  sEditTable.positions[from_row] = to_row_pos;
  sEditTable.revidx[to_row_pos]  = from_row;
  updateRowlabels(from_row, to_row_pos-from_row_pos);
  fixStyling();
}

/**

*/
function insertAfter(newnode, oldnode) {
  var parent = oldnode.parentNode;
  if(oldnode.nextSibling == null) {
    parent.appendChild(newnode);
  } else {
    parent.insertBefore(newnode, oldnode.nextSibling);
  }
}

/**

*/
function insertBefore(newnode, oldnode) {
  oldnode.parentNode.insertBefore(newnode, oldnode);
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

function RowSelectionObject(asset_url) {
  this.topImage    = asset_url + '/dash_right.gif';
  this.bottomImage = asset_url + '/dash_left.gif';
  this.row         = null;
  this.rownum      = null;
  this.topSep      = null;
  this.bottomSep   = null;
  return this;
}

/**

*/

function EditTableObject(tableform, row_container) {
  this.tableform           = tableform;
  this.row_container       = row_container;
  this.rows                = new Array();
  this.positions           = new Array();
  this.revidx              = new Array();
  this.numrows             = 0;
  this.last_separator      = null;
  var got_thead            = 0;
  var first_head           = 0;

  // If rows are contained in <THEAD> and <TBODY> elements, then we must be
  // sure to iterate over all of them.
  while(row_container != null) {

    // If there was a tbody before the first thead, we'll have to correct
    // our notion of the row positions, because browsers display the header
    // above the body.
    if (row_container.tagName == "THEAD" && got_thead == 0) {
      first_head = this.numrows;
      got_thead  = 1;
    }

    var row_elem = row_container.firstChild;
    while(row_elem != null) {
      if(row_elem.tagName == "TR") {
        this.rows[this.numrows]       = row_elem;
        this.positions[this.numrows]  = this.numrows - first_head;
        this.revidx[this.numrows - first_head] = this.numrows;
        this.numrows++;
      }
      row_elem = row_elem.nextSibling;
    }

    // If we hit a THEAD that was preceded by other rows, make corrections.
    if (first_head > 0) {
      var num_headrows  = this.numrows - first_head;
      for(var body_rownum = 0; body_rownum < first_head; body_rownum++) {
        this.positions[body_rownum] = body_rownum + first_head;
        this.revidx[body_rownum+first_head] = body_rownum;
      }
      first_head = 0;
    }

    row_container = row_container.nextSibling;
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
