var ns4 = (document.layers) ? true : false;
var ie4 = (document.all) ? true : false;
var dom = (document.getElementById) ? true : false;

// DON'T overwrite existing onload handlers
// http://simon.incutio.com/archive/2004/05/26/addLoadEvent
// usage: addLoadEvent(my_function_to_perform_on_onload);
function addLoadEvent(func) {
	var oldonload = window.onload;
	if (typeof window.onload != 'function') {
		window.onload = function() {
			func();
		}
	} else {
		window.onload = function() {
			oldonload();
			func();
		}
	}
}

function initForm() {}

function launchTheWindow(inPath, inWeb, inTopic, inSkin) {
	var win = open(inPath + inWeb + "/" + inTopic + "?skin=" + inSkin, inTopic, "titlebar=0,width=500,height=480,resizable,scrollbars");
	if( win ) {
		win.focus();
	}
	return false;
}

function removeClass(element, classname) {
	var classes = getClassList(element);
	var index = indexOf(classname,classes);
	if (index >= 0) {
		classes.splice(index,1);
		setClassList(element,classes);
	}
}

function addClass(element, classname) {
	var classes = getClassList(element);
	if (indexOf(classname, classes)<0) {
		classes[classes.length]=classname;
		setClassList(element,classes);
	}
}

function replaceClass(element, oldclass, newclass) {
	removeClass(element,oldclass);
	addClass(element,newclass);
}

function getClassList(element) {
	if (element.classes) return element.classes; // cached in element property
	if (element.className && element.className!="") {
		element.classes = element.className.split(' ');
		return element.classes;
	}
	return [];
}

function setClassList(element, classlist) {
	element.className=classlist.join(' ');
}

function indexOf(element,array) {
	for (var i = 0; i < array.length; ++i) {
		if (array[i]==element) {
			return i;
		}
	}
	return -1;
}

function getElementsByClassName(className) {

	var elements = [];
	var allObjects = (document.all) ? document.all : document.getElementsByTagName("*");
	
	for (var i = 0; i < allObjects.length; ++i) {
	  if (allObjects.item(i).className.indexOf(className) != -1)
		elements.push(allObjects.item(i));
	}
	return elements;
}

function hasClassName(elem, className) {

	return elem.className.indexOf(className) != -1;
}

function getElementsById(id) {

	var elements = [];
	var allObjects = (document.all) ? document.all : document.getElementsByTagName("*");
	
	for (var i = 0; i < allObjects.length; ++i) {
	  if (allObjects.item(i).id.indexOf(id) != -1)
		elements.push(allObjects.item(i));
	}
	return elements;
}

	function writeCookie(name,value,days) {
	var expires = ""
	if (days) {
		var date = new Date();
		date.setTime(date.getTime()+(days*24*60*60*1000));
		expires = "; expires="+date.toGMTString();
	}
	document.cookie = name + "=" + value + expires + "; path=/";
}

function readCookie(name) { 
	var nameEQ = name + "=";
	var ca = document.cookie.split(';');
	if (ca.length == 0) {
		ca = document.cookie.split(';');
	}
	for (var i=0;i < ca.length;++i) {
		var c = ca[i];
		while (c.charAt(0)==' ') c = c.substring(1,c.length);
		if (c.indexOf(nameEQ) == 0) return c.substring(nameEQ.length,c.length);
	}
	return null;
}