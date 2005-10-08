// hide straight away instead of waiting for onload
// http://www.quirksmode.org/blog/archives/2005/06/three_javascrip_1.html#link4
	document.write("<style type='text/css'>");
	document.write(".twistyMakeHidden {display:none;}");
	document.write("<\/style>");

// SMELL should this be a <link> to another stylesheet? (probably not worth it)

// DON'T overwrite existing onload handlers
//	http://simon.incutio.com/archive/2004/05/26/addLoadEvent

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
		var i=array.length;
		while (i--)
		{
			if (array[i]==element) {
				return i;
			}
		}
		return -1;
	}
	
	function getElementsByClassName(className) {
	
		var elements = [];
		var allObjects = (document.all) ? document.all : document.getElementsByTagName("*");
		
		var i = allObjects.length;
		
		while (i--)
		{
			if (allObjects.item(i).className.indexOf(className) != -1)
				elements.push(allObjects.item(i));
		}
		return elements;
	}

	function getElementsById(id) {
	
		var elements = [];
		var allObjects = (document.all) ? document.all : document.getElementsByTagName("*");
		
		var i = allObjects.length;
		
		while (i--)
		{
			if (allObjects.item(i).id.indexOf(id) != -1)
				elements.push(allObjects.item(i));
		}
		return elements;
	}


	function initTwist () {
		
		makeHiddenElements = getElementsByClassName('twistyMakeHidden');
		
		var i = makeHiddenElements.length;
		
		while (i--)
		{
			replaceClass(makeHiddenElements[i], 'twistyMakeHidden', 'twistyHidden');
		}
		
		makeVisibleElements = getElementsByClassName('twistyMakeVisible');
		i = makeVisibleElements.length;
		
		while (i--)
		{
			removeClass(makeVisibleElements[i], 'twistyMakeVisible');
		}

		triggerElements = getElementsByClassName('twistyTrigger');
		var i = triggerElements.length;
		while (i--)
		{
			triggerElements[i].onclick = function(){
				twist(this.parentNode.id.slice(0,-4));
				return false;
			};
		}		
	}
	
	function twist(id) {
   	   var showControl = document.getElementById(id+'show');
		var hideControl = document.getElementById(id+'hide');
		var toggleElem = document.getElementById(id+'toggle');
		if (!toggleElem.twisted) {
			addClass(showControl, 'twistyHidden');	
			removeClass(hideControl, 'twistyHidden');
			removeClass(toggleElem, 'twistyHidden');
			toggleElem.twisted = 1;
		} else {
			removeClass(showControl, 'twistyHidden');
			addClass(hideControl, 'twistyHidden');
			addClass(toggleElem, 'twistyHidden');
			toggleElem.twisted = 0;
		}
	}