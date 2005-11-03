var toShow = new Array();
var toHide = new Array();

function initForm() {
	try { document.main.text.focus(); } catch (er) {}
	var i, ilen = toShow.length;
	for (i = 0; i < ilen; ++i) {
		if (dom) {
			document.getElementById(toShow[i]).style.display="inline";
		} else if (ie4) {
			document.all[toShow[i]].style.display="inline";
		} else if (ns4) {
			document.layers[toShow[i]].style.display="inline";
		}
	}
	ilen = toHide.length;
	for ( i = 0; i < toHide.length; ++i) {
		if (dom) {
			document.getElementById(toHide[i]).style.display="none";
		} else if (ie4) {
			document.all[toHide[i]].style.display="none";
		} else if (ns4) {
			document.layers[toHide[i]].style.display="none";
		}
	}
}

function handleKeyDown(e) {
	if (!e) e = window.event;
	var code;
	if (e.keyCode) code = e.keyCode;
	if (code==27) return false;
	return true;
}

function checkAll( theButton, theButtonOffset, theNum, theCheck ) {
	// find button element index
	var i, j = 0;
	for (i = 0; i <= document.main.length; ++i) {
		if( theButton == document.main.elements[i] ) {
			j = i;
			break;
		}
	}
	// set/clear all checkboxes
	var last = j+theButtonOffset+theNum;
	for(i = last-theNum; i < last; ++i) {
		document.main.elements[i].checked = theCheck;
	}
}

addLoadEvent(initForm);