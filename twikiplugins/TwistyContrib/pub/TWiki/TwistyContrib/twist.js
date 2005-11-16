
var COOKIE_PREFIX = "TWikiTwistyContrib";
var COOKIE_EXPIRES = 31; // days

// hide straight away instead of waiting for onload
// http://www.quirksmode.org/blog/archives/2005/06/three_javascrip_1.html#link4
document.write("<style type='text/css'>");
document.write(".twistyMakeHidden {display:none;}");
document.write("<\/style>");

// SMELL should this be a <link> to another stylesheet? (probably not worth it)

// Asssume core javascript code is loaded via main template
	
	addLoadEvent(initTwist, true);

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
