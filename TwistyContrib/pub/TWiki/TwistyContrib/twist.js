
var COOKIE_PREFIX = "TWikiTwistyContrib";
var COOKIE_EXPIRES = 31; // days

// hide straight away instead of waiting for onload
// http://www.quirksmode.org/blog/archives/2005/06/three_javascrip_1.html#link4
// SMELL should this be a <link> to another stylesheet? (probably not worth it)
document.write("<style type='text/css'>");
document.write(".twistyMakeHidden {display:none;}");
document.write("<\/style>");

// Asssume core javascript code is loaded via main template
	
	// Add function initTwist to the head of the functions that are called at onload
	addLoadEvent(initTwist, true);

	// Twisty should degrade gracefully when javascript is off.
	// Then the hidden contents should be visible and the toggle links invisible.
	// To do this, the content is hidden with javascript, while the links are
	// displayed with javascript.
	// Hiding and showing is done by adding and removing style classes to the elements.
	function initTwist () {

		// Twisty can work with spans and with divs
		// Create a collection of these HTML elements, and iterate over these elements only
		var spansAndDivs = getHtmlElements("span", "div");
		
		var e, i;
		var hasClass; // function variable
		
		// Replace all elements with css class "twistyMakeHidden" with "twistyHidden"
		// so these elements will become hidden
		// The Twisty content will most probably have a "twistyMakeHidden" class
		i = spansAndDivs.length;
		hasClass = hasClassName("twistyMakeHidden");
		while (i--) {
			e = spansAndDivs[i];
			if (e && hasClass(e)) {
				replaceClass(e, "twistyMakeHidden", "twistyHidden");
			}
		}
		
		// Remove all classnames "twistyMakeVisible" (set to display:none)
		// so these elements become visible
		// Twisty toggle links will most probably have a "twistyMakeVisible" class
		i = spansAndDivs.length;
		hasClass = hasClassName("twistyMakeVisible");
		while (i--) {
			e = spansAndDivs[i];
			if (e && hasClass(e)) {
				removeClass(e, 'twistyMakeVisible');
			}
		}
	
		// The twistyTrigger are the links or buttons that command the toggling
		// This script assumes that the clickable element is either a link, a button, a span or a div
		var linksAndButtons = getHtmlElements("a", "button", "span", "div");
		i = linksAndButtons.length;
		hasClass = hasClassName("twistyTrigger");
		var twistIds = [];
		while (i--) {
			e = linksAndButtons[i];
			if (e && hasClass(e)) {
				var twistId = e.parentNode.id.slice(0,-4);
				twistIds.push(twistId);
				e.onclick = function() {
					twist(this.parentNode.id.slice(0,-4));
					return false;
				};
				var toggleElem = document.getElementById(twistId + 'toggle');
				var cookie  = readCookie(COOKIE_PREFIX + twistId);
				if (cookie == "1") twistShow(twistId, toggleElem);
				if (cookie == "0") twistHide(twistId, toggleElem);
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
		var hasClass = hasClassName("twistyRememberSetting");
		if (hasClass(toggleElem)) {
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
