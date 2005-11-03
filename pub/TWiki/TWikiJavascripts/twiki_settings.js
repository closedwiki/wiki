var ns4 = (document.layers) ? true : false;
var ie4 = (document.all) ? true : false;
var dom = (document.getElementById) ? true : false;

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