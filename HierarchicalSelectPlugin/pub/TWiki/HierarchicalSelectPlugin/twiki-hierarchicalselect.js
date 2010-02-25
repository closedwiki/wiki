// JavaScript for TWiki HierarchicalSelectPlugin
// by Ian Kluft
// Copyright 2009-2010 TWiki Inc.
// Released under the GNU General Public License (GPL)

// globals
var ddm = new Object();

// collect hierarchical select data
// scan the divs in the HTML and generate a data structure as follows:
// ddm: top level object
// * _toc: "table of contents", notes about each div/menu, lookup by id
//   * menu = menu name
//   * level = level number
// * entries by menu name: each contain array by level numbers
//   * n=0,1,2,3...: each contain array of div/menu ids for level n
function collectMenuData()
{
	// skip if already done
	if ( ddm._toc ) {
		return;
	}

	// fill ddm object with IDs of divs of class twiki_hierarchicalselect
	var divs = document.getElementsByTagName('div');

	// sort through divs collecting data
	ddm._toc = new Object;
	for ( var i=0; i<divs.length; i++ ) {
		// process class names
		var isTWikiMenu = 0, menuData = new Object;
		var classNames = divs[i].className; // get classes from div
		var c = classNames.split( /\s+/ ); // split classes
		for(var j = 0; j < c.length; j++) { // Loop through classes

			// is it a TWiki HierarchicalSelectPlugin marker?
			if ( c[j] == 'twiki_hierarchicalselect' ) {
				isTWikiMenu = 1;
				continue;
			}

			// is it the name of a menu?
			var menu = c[j].match( /^menu_.*/ );
			if ( menu ) {
				menuData.menu = menu[0].slice(5);
				continue;
			}

			// is it a level number within the menu?
			var level = c[j].match( /^level[0-9]+/ );
			if ( level ) {
				menuData.level = level[0].slice(5);
			}
		}

		// get id of div
		var id = divs[i].getAttribute('id');

		// process divs which are marked as TWiki hierarchicalselect
		if ( isTWikiMenu ) {
			ddm._toc[id] = menuData;
			if ( ! ddm[menuData.menu] ) {
				ddm[menuData.menu] = [];
			}
			if ( ! ddm[menuData.menu][menuData.level]) {
				ddm[menuData.menu][menuData.level] = [];
			}
			ddm[menuData.menu][menuData.level].push(id);
		}
	}
}

// display hierarchicalselect forms
function displayOpts()
{
	// collect data
	collectMenuData();

	// clear out the displayed options until we determine what we want
	for( var menu in ddm ) {
		if ( menu != '_toc' ) {
			clearOpts(ddm[menu][0][0]);
		}
	}

	// find selected items
	var i, sel=document.getElementsByTagName('select');
	for ( i=0; i < sel.length; i++ )
	{
		// parent node should have the id of one of our menu divs
		if ( ! sel[i].parentNode.hasAttribute( 'id' )) {
			continue; // skip selects which are not part of our menus
		}
		var parent_id = sel[i].parentNode.getAttribute( 'id' );
		if (( ! parent_id ) || ( ! ddm._toc[parent_id])) {
			continue; // skip selects which are not part of our menus
		}

		// add an onchange event to redo menu display status when changed
		sel[i].onchange=function()
		{
			// function which reacts to changing an item

			// Hide elements on same menu below level of this menu
			var id = this.parentNode.getAttribute('id');
			clearOpts(id);

			// look up selected option
			var si = this.selectedIndex;
			if ( si >= 0 ) {
				// display the entry
				var option = this.options[si];
				var submenu = option.getAttribute('submenu');
				if ( submenu ) {
					try {
						var el = document.getElementById(submenu);
						var sel = el.getElementsByTagName('select')[0];
						sel.options[0].selected = 1;
						el.style.display='';
					}
					catch(e){} ; // in case submenu is not a valid element ID
				}
			}
		}
	}
}

function clearOpts(id)
{
	// hide menus below the level of the current id
	var level = ddm._toc[id].level;
	var menu = ddm._toc[id].menu;
	for ( var i=level; i<ddm[menu].length; i++ ) {
		var levelMenus = ddm[menu][i];
		if ( ! levelMenus ) {
			continue;
		}
		for ( var j=0; j<levelMenus.length; j++ ) {
			document.getElementById(levelMenus[j]).style.display='none';
		}
	}
	document.getElementById(id).style.display='';
}

// set up menus/events
window.addEventListener
	?window.addEventListener('load',displayOpts,false)
	:window.attachEvent('onload',displayOpts);
