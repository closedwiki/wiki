// Generally useful JavaScript used by TWiki

var POPUP_WINDOW_WIDTH = 500;
var POPUP_WINDOW_HEIGHT = 480;

// Constants for the browser type
var ns4 = (document.layers) ? true : false;
var ie4 = (document.all) ? true : false;
var dom = (document.getElementById) ? true : false;

// Chain a new load handler onto the existing handler chain
// http://simon.incutio.com/archive/2004/05/26/addLoadEvent
// if prepend is true, adds the function to the head of the handler list
// otherwise it will be added to the end (executed last)
function addLoadEvent(func, prepend) {
	var oldonload = window.onload;
	if (typeof window.onload != 'function') {
		window.onload = function() {
			func();
		};
	} else {
		var prependFunc = function() {
			func(); oldonload();
		};
		var appendFunc = function() {
			oldonload(); func();
		};
		window.onload = prepend ? prependFunc : appendFunc;
	}
}

// Stub
function initForm() {
}

// Launch a fixed-size help window
function launchTheWindow(inPath, inWeb, inTopic, inSkin) {
	var win = open(inPath + inWeb + "/" + inTopic + "?skin=" + inSkin, inTopic, "titlebar=0,width=" + POPUP_WINDOW_WIDTH + ",height=" + POPUP_WINDOW_HEIGHT + ",resizable,scrollbars");
	if (win) win.focus();
	return false;
}

// Remove the given class from an element, if it is there
function removeClass(element, classname) {
	var classes = getClassList(element);
	var index = indexOf(classname,classes);
	if (index >= 0) {
		classes.splice(index,1);
		setClassList(element, classes);
	}
}

// Add the given class to the element, unless it is already there
function addClass(element, classname) {
	var classes = getClassList(element);
	if (indexOf(classname, classes) < 0) {
		classes[classes.length] = classname;
		setClassList(element,classes);
	}
}

// Replace the given class with a different class on the element.
// The new class is added even if the old class is not present.
function replaceClass(element, oldclass, newclass) {
	removeClass(element, oldclass);
	addClass(element, newclass);
}

// Get an array of the classes on the object.
function getClassList(element) {
	if (element.className && element.className != "") {
		return element.className.split(' ');
	}
	return [];
}

// Set the classes on an element from an array of class names
// Cache the list in the 'classes' attribute on the element
function setClassList(element, classlist) {
	element.className = classlist.join(' ');
}

// Determine the first index of a string in an array.
// Return -1 if the string is not found.
function indexOf(element, array) {
	var i = array.length;
	while (i--)	{
		if (array[i] == element) return i;
	}
	return -1;
}

// Applies the given function to all elements in the document of
// the given tag type
function applyToAllElements(fn, type) {
    var c = document.getElementsByTagName(type);
    for (var j = 0; j < c.length; j++) {
        fn(c[j]);
    }
}

// Determine if the element has the given class string somewhere in it's
// className attribute.
function hasClass(node, className) {
    if (node.className) {
        return (indexOf(className, getClassList(node)) >= 0);
    }
}

// Add a cookie. If 'days' is set to a non-zero number of days,
// sets an expiry on the cookie
function writeCookie(name,value,days) {
	var expires = "";
	if (days) {
		var date = new Date();
		date.setTime(date.getTime()+(days*24*60*60*1000));
		expires = "; expires="+date.toGMTString();
	}
	// cumulative
	document.cookie = name + "=" + value + expires + "; path=/";
}

// Reads the named cookie and returns the value
function readCookie(name) { 
	var nameEQ = name + "=";
	var ca = document.cookie.split(';');
	if (ca.length == 0) {
		ca = document.cookie.split(';');
	}
	for (var i=0;i < ca.length;++i) {
		var c = ca[i];
		while (c.charAt(0)==' ')
            c = c.substring(1,c.length);
		if (c.indexOf(nameEQ) == 0)
            return c.substring(nameEQ.length,c.length);
	}
	return null;
}
