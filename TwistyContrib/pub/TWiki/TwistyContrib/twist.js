
var COOKIE_PREFIX = "TWikiTwistyContrib";
var COOKIE_EXPIRES = 31; // days

// hide straight away instead of waiting for onload
// http://www.quirksmode.org/blog/archives/2005/06/three_javascrip_1.html#link4
document.write("<style type='text/css'>");
document.write(".twistyMakeHidden {display:none;}");
document.write("<\/style>");

// SMELL should this be a <link> to another stylesheet? (probably not worth it)

// DON'T overwrite existing onload handlers
// http://simon.incutio.com/archive/2004/05/26/addLoadEvent

	function addLoadEvent(func){
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
	
	addLoadEvent(initTwist);
    
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


	function initTwist () {
		
		var makeHiddenElements = getElementsByClassName('twistyMakeHidden');
		var i;
		for (i = 0; i < makeHiddenElements.length; ++i) {
          replaceClass(makeHiddenElements[i], 'twistyMakeHidden', 'twistyHidden');
		}
		
		var makeVisibleElements = getElementsByClassName('twistyMakeVisible');
		for (i = 0; i < makeVisibleElements.length; ++i) {
          removeClass(makeVisibleElements[i], 'twistyMakeVisible');
		}

		var triggerElements = getElementsByClassName('twistyTrigger');
		var id;
		for (i = 0; i < triggerElements.length; ++i) {
			triggerElements[i].onclick = function() {
            	twist(this.parentNode.id.slice(0,-4));
	            return false;
			};
			var elemid = triggerElements[i].parentNode.id.slice(0,-4);
			if (id != elemid) {
				id = elemid;
				var toggleElem = document.getElementById(id+'toggle');
				var cookie  = readCookie(COOKIE_PREFIX + id);
				if (cookie == "1") {
					twistShow(id, toggleElem);
				}
				if (cookie == "0") {
					twistHide(id, toggleElem);
				}
			}
		}
	}
	
	function twist(id) {
		var toggleElem = document.getElementById(id+'toggle');
		var state;
		if (toggleElem.twisted) {
			twistHide(id, toggleElem);
			state = 0; // hidden
		} else {
			twistShow(id, toggleElem);
			state = 1; // shown
		}
// Use class name 'twistyRememberSetting' to see if a cookie can be set
// This is not illegal, see: http://www.w3.org/TR/REC-html40/struct/global.html#h-7.5.2
// 'For general purpose processing by user agents'
		if (hasClassName(toggleElem, "twistyRememberSetting")) {
			writeCookie(COOKIE_PREFIX + id, state, COOKIE_EXPIRES);
		}
	}
	
	function twistShow(id, toggleElem) {
		var showControl = document.getElementById(id+'show');
		var hideControl = document.getElementById(id+'hide');
		addClass(showControl, 'twistyHidden');	
		removeClass(hideControl, 'twistyHidden');
		removeClass(toggleElem, 'twistyHidden');
		toggleElem.twisted = 1;
	}
	
	function twistHide(id, toggleElem) {
		var showControl = document.getElementById(id+'show');
		var hideControl = document.getElementById(id+'hide');
		removeClass(showControl, 'twistyHidden');
		addClass(hideControl, 'twistyHidden');
		addClass(toggleElem, 'twistyHidden');
		toggleElem.twisted = 0;
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