/*
# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2005 Sven Dowideit SvenDowideit@wikiring.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at 
# http://www.gnu.org/copyleft/gpl.html
#
*/

InitJSPopups = function() {
//look for PopupSpan's, with anchortype == 'anchorless', and call openPopup on them..
    var elements = document.getElementsByTagName('span');
    for (var i = 0; i < elements.length; i++) {
        //The user viewed HTML
        if ((elements[i].className == 'JSPopupSpan')) {
            var anchor = elements[i].getAttribute('anchortype');
            if (anchor == 'anchorless') {
                TWiki.JSPopupPlugin.openPopupSectional(null, elements[i].id)
            }
        }
    }
}

//create the TWiki namespace if needed
if ( typeof( TWiki ) == "undefined" ) {
    TWiki = {};
}

/**********************************************************************************/
//create the TWiki.JSPopupPlugin namespace if needed
if ( typeof( TWiki.JSPopupPlugin ) == "undefined" ) {
    TWiki.JSPopupPlugin = {};
}
TWiki.JSPopupPlugin.closeButton = '<a style="float:right;display:inline;background-color: LightSteelBlue;" align="rght" onclick="TWiki.JSPopupPlugin.closePopup(event);">X</a>';


TWiki.JSPopupPlugin.openPopupSectional = function (event, sectionName) {
    if ((sectionName) && (sectionName != '')) {
        var sectionElem = document.getElementById(sectionName);
        if (sectionElem.getAttribute('type') == 'rest') {
            //reset the text to a simple default
            TWiki.JSPopupPlugin.openPopup(event, 'Please wait, requesting data from server', sectionElem.getAttribute('location'), sectionElem.getAttribute('border'), sectionElem.getAttribute('title'));
            TWiki.JSPopupPlugin.ajaxCall(event, sectionElem.innerHTML);
        } else {
            TWiki.JSPopupPlugin.openPopup(event, sectionElem.innerHTML, sectionElem.getAttribute('location'), sectionElem.getAttribute('border'), sectionElem.getAttribute('title'));
        }
    } else {
        TWiki.JSPopupPlugin.closePopup(event);
    }
}

TWiki.JSPopupPlugin.closePopup = function (event) {
    var showControl = document.getElementById('popupwindow');
    showControl.style.display = 'none';
}

//where text == the payload, most often in html
TWiki.JSPopupPlugin.openPopup = function (event, text, popuplocation, border, title) {
    if ( typeof( popuplocation ) == "undefined" ) {
        popuplocation = 'center';
    }
    if ( typeof( border ) == "undefined" ) {
        border = 'on';
    }
    if ( typeof( title ) == "undefined" ) {
        title = '';
    }

    var showControl = document.getElementById('popupwindow');
    var popupWrapper = document.getElementById('popupwrapper');
    var popupNoBorder = document.getElementById('popupnoborder');

        //reset the text to a simple default
    popupWrapper.innerHTML = '';
    popupNoBorder.innerHTML = '';

    //from http://www.quirksmode.org/js/events_compinfo.html#prop
    var posx = 200;
    var posy = 50;
    if (typeof( event ) == "undefined") var event = window.event;
    if ((typeof( event ) != "undefined") && (event != null)) {
        if (event.pageX || event.pageY)
        {
            posx = event.pageX;
            posy = event.pageY;
        }
        else if (event.clientX || event.clientY)
        {
            posx = event.clientX + document.body.scrollLeft;
            posy = event.clientY + document.body.scrollTop;
        }
        showControl.target = (event.target) ? event.target : event.srcElement;
    }

    var mousex = posx;
    var mousey = posy//IE..
    showControl.style.top=mousey+"px";
    showControl.style.left=mousex+"px";
    showControl.style.display = 'inline';
    showControl.style.zindex=999;

//        try { showControlText.focus(); } catch (er) {alert(er)}

    if (border == 'on') {
        popupWrapper.innerHTML = text;
        popupNoBorder.innerHTML = TWiki.JSPopupPlugin.closeButton+title;
        popupNoBorder.MouseLeave = 0;
    } else {
        popupNoBorder.innerHTML = text;
        popupWrapper.innerHTML = '';
        popupNoBorder.MouseLeave = 1;
    }
    if (popuplocation == 'center') {
        mousey = mousey - (showControl.clientHeight/2);
        if (mousey < 10) {mousey = 10;}
    } else {
//        mousex = mousex - (showControl.clientWidth/2);
//        if (mousex < 10) {mousex = 10;}
    }
    showControl.style.top=mousey+"px";
    showControl.style.left=mousex+"px";

    return showControl;
}


//hacked version of http://www.quirksmode.org/js/events_mouse.html
//specific to the popupnoborder section
//TODO: somehat buggy, looking forward to finding a nice lightweight GUI library
TWiki.JSPopupPlugin.OnMouseLeave = function (e, sectionName)
{
	if (!e) var e = window.event;
	var tg = (window.event) ? e.srcElement : e.target;
	if (tg.id != 'popuptable') return;     //TODO: make this on popuptable, when we know what anchortype it is
    var popupNoBorder = document.getElementById('popupnoborder');
	if (        popupNoBorder.MouseLeave == 0) return;        //TODO: don't exit if there is a border and a close button
	var reltg = (e.relatedTarget) ? e.relatedTarget : e.toElement;
	while (reltg != tg && reltg.nodeName != 'BODY')
		reltg= reltg.parentNode
	if (reltg== tg) return;
	// Mouseout took place when mouse actually left layer
	// Handle event
	TWiki.JSPopupPlugin.closePopup(e);
}



/********************************************************
http://www.ajaxtoolbox.com/ call
*/
TWiki.JSPopupPlugin.ajaxCall = function(event, popupUrl, popupParams) {
//TODO: redo these as params in the Args
    //make sure there's no popup div in the reply
    if (popupUrl.indexOf('?') != -1) {
        popupUrl = popupUrl+'&fromPopup=1';
    } else {
        popupUrl = popupUrl+'?fromPopup=1';
    }

    if ( typeof( popupParams ) != "undefined" ) {
         popupUrl = popupUrl+';'+popupParams;
    }
    var bindArgs = {
        url:        popupUrl,
        onError:      function(req) {
            // handle error here
            alert('Error!\nStatusText='+req.statusText+'\nContents='+req.responseText);
            },
        onSuccess:      function(req) {
            var data = req.responseText;
            //protect against full html pages by only bringing in the body
            var startBodyTag = data.indexOf('<body');
            if (startBodyTag == -1) {
                startBodyTag = data.indexOf('<BODY');
            }
            if (startBodyTag > -1) {
                startBodyTag = data.indexOf('>', startBodyTag);

                var endBodyTag = data.indexOf('</body');
                if (endBodyTag == -1) {
                    endBodyTag = data.indexOf('</BODY');
                }
                if (endBodyTag > -1) {
                    data = data.substring(startBodyTag+1, endBodyTag-1);
                }
            }
            TWiki.JSPopupPlugin.openPopup(event, data);
        }
    };

    // dispatch the request
    var requestObj = AjaxRequest.get(bindArgs);
}

/***********************************************************
more generic tools - need to share at some stage
*/
//from http://weblogs.asp.net/asmith/archive/2003/10/06/30744.aspx
//add an event handler so they chain, and cross browser
function XBrowserAddHandler(target,eventName,handlerName) { 
  if ( target.addEventListener ) { 
    target.addEventListener(eventName, function(e){target[handlerName](e);}, false);
  } else if ( target.attachEvent ) { 
    target.attachEvent("on" + eventName, function(e){target[handlerName](e);});
  } else { 
    var originalHandler = target["on" + eventName]; 
    if ( originalHandler ) { 
      target["on" + eventName] = function(e){originalHandler(e);target[handlerName](e);}; 
    } else { 
      target["on" + eventName] = target[handlerName]; 
    } 
  } 
}
