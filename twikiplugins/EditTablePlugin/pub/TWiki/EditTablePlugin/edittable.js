// edittable.js
//
// By Byron Darrah
//
// This code adds support to the TWiki EditTablesPlugin for dynamically
// manipulating rows within a table.

//-----------------------------------------------------------------------------
// Global variables

// Array of edittables.
var edittable;
var row_operation = 'none';
var row_selection;

//-----------------------------------------------------------------------------
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

//-----------------------------------------------------------------------------

// Build the list of edittables.
function edittable_init(form_name, asset_url) {

  // The form we want is actually the second thing in the
  // document that has the form_name.
  var tableform = document.getElementsByName(form_name)[1];
  
  if(tableform == null) {
    alert("Error: EditTable features cannot be enabled.\n");
    return;
  }
  attach_event(tableform, 'submit', submit_handler);

  var somerow = searchNodeTreeForTagName(tableform, "TR");
  if(somerow != null) {
    var row_container = somerow.parentNode;
    edittable = new edittable_object(tableform, row_container);
    insert_action_buttons(asset_url);
  }
  row_selection = new row_selection_object();
}

//-----------------------------------------------------------------------------
// Create the etrow_id# inputs to tell the server about row changes we made.
function submit_handler(evt) {
  var inp;
  for(i=0; i<edittable.numrows; i++) {
    var inpname = 'etrow_id'+(i+1);
    var row_id  = edittable.revidx[i]+1;
    inp = document.createElement('INPUT');
    inp.setAttribute('type', 'hidden');
    inp.setAttribute('name', inpname);
    inp.setAttribute('value', '' + row_id);
    edittable.tableform.appendChild(inp);
  }
  return true;
}

//-----------------------------------------------------------------------------
function attach_event(obj, evtype, handler) {
  if(window.addEventListener){ // Mozilla, Netscape, Firefox
    obj.addEventListener(evtype, handler, false);
  } else { // IE
    obj.attachEvent('on' + evtype, handler);
  }
}

//-----------------------------------------------------------------------------
function get_event_attr(evt, pname) {
  var e_out;
  var ie_var = "srcElement";
  var moz_var = "target";
  // "target" for Mozilla, Netscape, Firefox et al. ; "srcElement" for IE
  evt[moz_var] ? e_out = evt[moz_var][pname] : e_out = evt[ie_var][pname];
  return e_out;
}

//-----------------------------------------------------------------------------
function insert_action_buttons(asset_url) {

  var rownr=0;
  for(var child = edittable.row_container.firstChild; child != null;
          child = child.nextSibling) {
    if (child.tagName == 'TR') {
      action_cell = document.createElement('TD');
      action_cell.id = 'et_actioncell' + rownr;

      action_butt = document.createElement('IMG');
      action_butt.setAttribute('src', asset_url + '/movebutt.png');
      action_butt.setAttribute('alt', 'Move');
      attach_event(action_butt, 'click', move_handler);
      action_butt.rownr = rownr;
      action_cell.appendChild(action_butt);

      action_butt = document.createElement('IMG');
      action_butt.setAttribute('src', asset_url + '/delbutt.png');
      action_butt.setAttribute('alt', 'Delete');
      attach_event(action_butt, 'click', delete_handler);
      action_butt.rownr = rownr;
      action_cell.appendChild(action_butt);

      child.insertBefore(action_cell, child.firstChild);
      rownr++;
    }
  }
}

//-----------------------------------------------------------------------------

function move_handler(evt) {
  var rownr = get_event_attr(evt, 'rownr');
  if (row_selection.rownum == null) {
    var row_elem             = edittable.rows[rownr];
    var action_cell          = row_elem.firstChild;
    row_selection.row        = row_elem;
    row_selection.rownum     = rownr;
    row_selection.color_node = action_cell;
    row_selection.old_color = row_selection.color_node.style.backgroundColor;
    row_selection.color_node.style.backgroundColor = '#7070ff';
  } else {
    moverow(row_selection.rownum, rownr);
    row_selection.row        = null;
    row_selection.rownum     = null;
    row_selection.color_node.style.backgroundColor = row_selection.old_color;
    row_selection.color_node = null;
    row_selection.old_color  = null;
  }
}

//-----------------------------------------------------------------------------
function delete_handler(evt) {
  var rownr = get_event_attr(evt, 'rownr');

  var from_row_pos = edittable.positions[rownr];

  // Remove the from_row from the table.
  var row_container      = edittable.row_container;
  var from_row_elem      = edittable.rows[rownr];
  row_container.removeChild(from_row_elem);

  // Update all rows after from_row.
  for(var pos=from_row_pos+1; pos < edittable.numrows; pos++) {
    var rownum = edittable.revidx[pos];
    var newpos = pos-1;
    edittable.positions[rownum] = newpos;
    edittable.revidx[newpos]    = rownum;
    update_rowlabels(rownum, -1);
  }

  if (row_selection.rownum == rownr) {
    row_selection.row        = null;
    row_selection.rownum     = null;
    row_selection.color_node = null;
    row_selection.old_color  = null;
  }

  edittable.numrows--;
  edittable.tableform.etrows.value = edittable.numrows;
}


//-----------------------------------------------------------------------------
function moverow(from_row, to_row) {
  var from_row_pos = edittable.positions[from_row];
  var to_row_pos   = edittable.positions[to_row];

  var inc = 1;
  if(to_row_pos == -1 || from_row_pos > to_row_pos) {
    inc=-1;
  }
  if (from_row == to_row) { return; }

  // Remove the from_row from the table.
  var row_container      = edittable.row_container;
  var from_row_elem      = edittable.rows[from_row];
  workaround_ie_checkbox_bug(from_row_elem);
  row_container.removeChild(from_row_elem);

  // Update all rows after from_row up to to_row.
  for(var pos=from_row_pos+inc; pos != to_row_pos+inc; pos+=inc) {
    var rownum = edittable.revidx[pos];
    var newpos = pos-inc;
    edittable.positions[rownum] = newpos;
    edittable.revidx[newpos]    = rownum;
    update_rowlabels(rownum, -inc);
  }

  var insertion_target = edittable.rows[to_row];
  if (inc == 1) {
    insertion_target = insertion_target.nextSibling;
  }
  if(insertion_target == null) {
    row_container.appendChild(from_row_elem);
  } else {
    row_container.insertBefore(from_row_elem, insertion_target);
  }
  edittable.positions[from_row] = to_row_pos;
  edittable.revidx[to_row_pos]  = from_row;
  update_rowlabels(from_row, to_row_pos-from_row_pos);

}

//-----------------------------------------------------------------------------
// IE will reset checkboxes to their default state when they are moved around
// in the DOM tree, so we have to override the default state.

function workaround_ie_checkbox_bug(container) {
  var elems = container.getElementsByTagName('INPUT');
  for(i=0; elems[i] != null; i++) {
    inp=elems[i];
    if(inp['type'] == 'radio') {
      inp['defaultChecked'] = inp['checked'];
    }
  }
}

//-----------------------------------------------------------------------------

function row_selection_object() {
  this.row        = null;
  this.rownum     = null;
  this.color_node = null;
  this.old_color  = null;
  return this;
}

//-----------------------------------------------------------------------------

function edittable_object(tableform, row_container) {
  this.tableform           = tableform;
  this.row_container       = row_container;
  this.rows                = new Array();
  this.positions           = new Array();
  this.rowids              = new Array();
  this.revidx              = new Array();
  this.numrows             = 0;
  row_elem                 = row_container.firstChild;

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

//-----------------------------------------------------------------------------

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

//-----------------------------------------------------------------------------
// Update all row labels in a row by adding a delta amount to each one.

function update_rowlabels(rownum, delta) {
  var row=edittable.rows[rownum];
  var label_nodes = row.getElementsByTagName('DIV');
  for(i=0; label_nodes[i] != null; i++) {
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

//-----------------------------------------------------------------------------
// EOF: edittable.js
