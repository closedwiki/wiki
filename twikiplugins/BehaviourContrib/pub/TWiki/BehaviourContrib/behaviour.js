/*
To compress this file you can use Dojo ShrinkSafe compressor at
http://alex.dojotoolkit.org/shrinksafe/
*/

/*
   Behaviour v1.1 by Ben Nolan, June 2005. Based largely on the work
   of Simon Willison (see comments by Simon below).

   Description:
   	
   	Uses css selectors to apply javascript behaviours to enable
   	unobtrusive javascript in html documents.
   	
   Usage:   
   
	var myrules = {
		'b.someclass' : function(element){
			element.onclick = function(){
				alert(this.innerHTML);
			}
		},
		'#someid u' : function(element){
			element.onmouseover = function(){
				this.innerHTML = "BLAH!";
			}
		}
	};
	
	Behaviour.register(myrules);
	
	// Call Behaviour.apply() to re-apply the rules (if you
	// update the dom, etc).

   License:
   
   	This file is entirely BSD licensed.
   	
   More information:
   	
   	http://ripcord.co.nz/behaviour/
   
*/   

if (!Behaviour) {
	var Behaviour = {
		list : new Array,
		
		register : function(sheet){
			Behaviour.list.push(sheet);
		},
		
		start : function(){
			Behaviour.addLoadEvent(function(){
				Behaviour.apply();
			});
		},
		
		apply : function(){
			for (h=0;sheet=Behaviour.list[h];h++){
				for (selector in sheet){
					list = document.getElementsBySelector(selector);
					
					if (!list){
						continue;
					}
	
					for (i=0;element=list[i];i++){
						sheet[selector](element);
					}
				}
			}
		},
		
		addLoadEvent : function(func){
			var oldonload = window.onload;
			
			if (typeof window.onload != 'function') {
				window.onload = func;
			} else {
				window.onload = function() {
					oldonload();
					func();
				}
			}
		}
	}
	
	Behaviour.start();
}

/*
   The following code is Copyright (C) Simon Willison 2004.

   document.getElementsBySelector(selector)
   - returns an array of element objects from the current document
     matching the CSS selector. Selectors can contain element names, 
     class names and ids and can be nested. For example:
     
       elements = document.getElementsBySelect('div#main p a.external')
     
     Will return an array of all 'a' elements with 'external' in their 
     class attribute that are contained inside 'p' elements that are 
     contained inside the 'div' element which has id="main"

   New in version 0.4: Support for CSS2 and CSS3 attribute selectors:
   See http://www.w3.org/TR/css3-selectors/#attribute-selectors

   Version 0.4 - Simon Willison, March 25th 2003
   -- Works in Phoenix 0.5, Mozilla 1.3, Opera 7, Internet Explorer 6, Internet Explorer 5 on Windows
   -- Opera 7 fails 
*/

function getAllChildren(e) {
  // Returns all children of element. Workaround required for IE5/Windows. Ugh.
  return e.all ? e.all : e.getElementsByTagName('*');
}

document.getElementsBySelector = function(selector) {
  // Attempt to fail gracefully in lesser browsers
  if (!document.getElementsByTagName) {
    return new Array();
  }
  // Split selector in to tokens
  var tokens = selector.split(' ');
  var currentContext = new Array(document);
  for (var i = 0; i < tokens.length; i++) {
    token = tokens[i].replace(/^\s+/,'').replace(/\s+$/,'');;
    if (token.indexOf('#') > -1) {
      // Token is an ID selector
      var bits = token.split('#');
      var tagName = bits[0];
      var id = bits[1];
      var element = document.getElementById(id);
      if (tagName && element.nodeName.toLowerCase() != tagName) {
        // tag with that ID not found, return false
        return new Array();
      }
      // Set currentContext to contain just this element
      currentContext = new Array(element);
      continue; // Skip to next token
    }
    if (token.indexOf('.') > -1) {
      // Token contains a class selector
      var bits = token.split('.');
      var tagName = bits[0];
      var className = bits[1];
      if (!tagName) {
        tagName = '*';
      }
      // Get elements matching tag, filter them for class selector
      var found = new Array;
      var foundCount = 0;
      for (var h = 0; h < currentContext.length; h++) {
        var elements;
        if (tagName == '*') {
            elements = getAllChildren(currentContext[h]);
        } else {
            elements = currentContext[h].getElementsByTagName(tagName);
        }
        for (var j = 0; j < elements.length; j++) {
          found[foundCount++] = elements[j];
        }
      }
      currentContext = new Array;
      var currentContextIndex = 0;
      for (var k = 0; k < found.length; k++) {
        if (found[k].className && found[k].className.match(new RegExp('\\b'+className+'\\b'))) {
          currentContext[currentContextIndex++] = found[k];
        }
      }
      continue; // Skip to next token
    }
    // Code to deal with attribute selectors
    if (token.match(/^(\w*)\[(\w+)([=~\|\^\$\*]?)=?"?([^\]"]*)"?\]$/)) {
      var tagName = RegExp.$1;
      var attrName = RegExp.$2;
      var attrOperator = RegExp.$3;
      var attrValue = RegExp.$4;
      if (!tagName) {
        tagName = '*';
      }
      // Grab all of the tagName elements within current context
      var found = new Array;
      var foundCount = 0;
      for (var h = 0; h < currentContext.length; h++) {
        var elements;
        if (tagName == '*') {
            elements = getAllChildren(currentContext[h]);
        } else {
            elements = currentContext[h].getElementsByTagName(tagName);
        }
        for (var j = 0; j < elements.length; j++) {
          found[foundCount++] = elements[j];
        }
      }
      currentContext = new Array;
      var currentContextIndex = 0;
      var checkFunction; // This function will be used to filter the elements
      switch (attrOperator) {
        case '=': // Equality
          checkFunction = function(e) { return (e.getAttribute(attrName) == attrValue); };
          break;
        case '~': // Match one of space seperated words 
          checkFunction = function(e) { return (e.getAttribute(attrName).match(new RegExp('\\b'+attrValue+'\\b'))); };
          break;
        case '|': // Match start with value followed by optional hyphen
          checkFunction = function(e) { return (e.getAttribute(attrName).match(new RegExp('^'+attrValue+'-?'))); };
          break;
        case '^': // Match starts with value
          checkFunction = function(e) { return (e.getAttribute(attrName).indexOf(attrValue) == 0); };
          break;
        case '$': // Match ends with value - fails with "Warning" in Opera 7
          checkFunction = function(e) { return (e.getAttribute(attrName).lastIndexOf(attrValue) == e.getAttribute(attrName).length - attrValue.length); };
          break;
        case '*': // Match ends with value
          checkFunction = function(e) { return (e.getAttribute(attrName).indexOf(attrValue) > -1); };
          break;
        default :
          // Just test for existence of attribute
          checkFunction = function(e) { return e.getAttribute(attrName); };
      }
      currentContext = new Array;
      var currentContextIndex = 0;
      for (var k = 0; k < found.length; k++) {
        if (checkFunction(found[k])) {
          currentContext[currentContextIndex++] = found[k];
        }
      }
      // alert('Attribute Selector: '+tagName+' '+attrName+' '+attrOperator+' '+attrValue);
      continue; // Skip to next token
    }
    
    if (!currentContext[0]){
    	return;
    }
    
    // If we get here, token is JUST an element (not a class or ID selector)
    tagName = token;
    var found = new Array;
    var foundCount = 0;
    for (var h = 0; h < currentContext.length; h++) {
      var elements = currentContext[h].getElementsByTagName(tagName);
      for (var j = 0; j < elements.length; j++) {
        found[foundCount++] = elements[j];
      }
    }
    currentContext = found;
  }
  return currentContext;
}

/* That revolting regular expression explained 
/^(\w+)\[(\w+)([=~\|\^\$\*]?)=?"?([^\]"]*)"?\]$/
  \---/  \---/\-------------/    \-------/
    |      |         |               |
    |      |         |           The value
    |      |    ~,|,^,$,* or =
    |   Attribute 
   Tag
*/



// Speed up written by Dean Edwards, 2006
// http://dean.edwards.name/weblog/2006/03/faster
// Made code cross-platform by Arthur Clemens, 2007

// this object will manage CSS expressions used to query the DOM
var Selectors;
if (!Selectors) {
	if (document.createStyleSheet) Selectors = {
		styleSheet: document.createStyleSheet(),
		cache: {},
		length: 0,
		
		register: function(sheet) {
			// create the CSS expression and add it to the style sheet
			var cssText = [], index;
			for (var selector in sheet) {
				index = this.length++;
				// have to store by index too as the expression hack does not like
				//  spaces in strings for some strange reason
				this.cache[index] = this.cache[selector] = [];
				cssText.push(selector + "{behavior:expression(Selectors.store(" + index + ",this))}");
			}
			this.styleSheet.cssText = cssText.join("\n");
		},
		
		store: function(index, element) {
			// called from the CSS expression
			// store the matched DOM node
			this.cache[index].push(element);
			element.runtimeStyle.behavior = "none";
		},
		
		tidy: function() {
			// clean up after behaviors have been applied
			delete this.cache;
			this.styleSheet.cssText = "";
		}
	}
	if (Selectors) {
		// override getElementsBySelector
		document._getElementsBySelector = document.getElementsBySelector;
		document.getElementsBySelector = function(selector) {
			if (!Selectors.cache || /\[/.test(selector)) { // attribute selectors not supported by IE5/6
				return document._getElementsBySelector(selector);
			} else { // use the cache
				return Selectors.cache[selector];
			}
		};
		// override Behaviour's register function
		Behaviour._register = Behaviour.register;
		Behaviour.register = function(sheet) {
			Selectors.register(sheet);
			// call the old register function
			this._register(sheet);
		}
	}
}
// Do not wait for onload call
// by Dean Edwards/Matthias Miller/John Resig, 2006

var _behaviourOnloadTimer;
if (!Behaviour._apply) {
	Behaviour._apply = Behaviour.apply;
	Behaviour.apply = function() {
		if (this.applied) return;
		this.applied = true;
		this._apply();
	};
}
if (!Behaviour.init) {
	Behaviour.init = function() {
		// quit if this function has already been called
		if (arguments.callee.done) return;
		
		// flag this function so we don't do the same thing twice
		arguments.callee.done = true;
		
		// kill the timer
		if (_behaviourOnloadTimer) {
			clearInterval(_behaviourOnloadTimer);
			_behaviourOnloadTimer = null;
		}
		
		Behaviour.apply();
	};
}

/* for Mozilla */
if (document.addEventListener) {
	document.addEventListener("DOMContentLoaded", Behaviour.init, false);
}

/* for Internet Explorer */
/*@cc_on @*/
/*@if (@_win32)
	document.write("<script id=__ie_onload defer src=javascript:void(0)><\/script>");
	var script = document.getElementById("__ie_onload");
	script.onreadystatechange = function() {
		if (this.readyState == "complete") {
			Behaviour.init(); // call the onload handler
		}
	};
/*@end @*/

/* for Safari */

if (navigator.vendor && navigator.vendor.match(/Apple/)) { // sniff
	if (!_behaviourOnloadTimer) {
		_behaviourOnloadTimer = setInterval(function() {
			if (/loaded|complete/.test(document.readyState)) {
				Behaviour.init(); // call the onload handler
			}
		}, 10);
	}
}