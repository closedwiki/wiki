/*
# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2005-2007 Sven Dowideit - SvenDowideit@wikiring.com
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
                return twiki.JSPopupPlugin.openPopupSectional(null, elements[i].id)
            }
        }
    }
}



//create the TWiki namespace if needed
if ( typeof( twiki ) == "undefined" ) {
    twiki = {};
}

/**********************************************************************************/
//create the twiki.JSPopupPlugin namespace if needed
if ( typeof( twiki.JSPopupPlugin ) == "undefined" ) {
    twiki.JSPopupPlugin = {};
}

twiki.JSPopupPlugin.DelayedOpenPopupSectional = function (event, sectionName) {
    var sectionElem = document.getElementById(sectionName);
    var delay = sectionElem.getAttribute('delay');
    
    //TODO: consider making this an array, indexed by sectionName
    delayedPopup = window.setTimeout("twiki.JSPopupPlugin.openPopupSectional(null, '"+sectionName+"')", delay);
}
 
twiki.JSPopupPlugin.CancelOpenPopup = function() {
    window.clearTimeout(delayedPopup);
}

//returns false to prevent the default action of the anchor..
twiki.JSPopupPlugin.openPopupSectional = function (event, sectionName) {
    var ret = true;
    if ((sectionName) && (sectionName != '')) {
        var sectionElem = document.getElementById(sectionName);
        if (sectionElem.getAttribute('type') == 'rest') {
        
            // use popupurl paramin preference to href in preference to innerHTML
            var url = sectionElem.getAttribute('popupurl');
            if (!url) { url = sectionElem.getAttribute('popupurl'); }
            if (!url) { url = sectionElem.innerHTML; }
            //reset the text to a simple default
            ret = twiki.JSPopupPlugin.openPopup(event, 'Please wait, requesting data from server', sectionElem.getAttribute('location'), sectionElem.getAttribute('border'), sectionElem.getAttribute('title'));
            twiki.JSPopupPlugin.ajaxCall(event, url);
        } else {
            ret = twiki.JSPopupPlugin.openPopup(event, sectionElem.innerHTML, sectionElem.getAttribute('location'), sectionElem.getAttribute('border'), sectionElem.getAttribute('title'));
        }
    } else {
        ret = twiki.JSPopupPlugin.closePopup(event);
    }
    return ret;
}

twiki.JSPopupPlugin.closePopup = function (event) {
    //var showControl = document.getElementById('popupwindow');
    //showControl.style.display = 'none';
    return false;
}

// Define various event handlers for Dialog 
var handleSubmit = function() { 
    this.submit(); 
}; 
var handleCancel = function() { 
    this.cancel(); 
}; 

twiki.JSPopupPlugin.openPopup = function (event, text, popuplocation, border, title) {
alert(popuplocation);
    if ( typeof( popuplocation ) == "undefined" ) {
        popuplocation = 'center';
    }
    if ( typeof( border ) == "undefined" ) {
        border = 'on';
    }
    if ( typeof( title ) == "undefined" ) {
        title = '';
    }
    
    //use popuplocation = 'center' as default
    var fixedcenter = true;
    var context = null;
    if (popuplocation == 'below') {
	    if (!event) event = window.event;
	    alert(event);
	    if (event) {
          	var targ;
    	    if (event.target) targ = event.target;
	        else if (event.srcElement) targ = event.srcElement;
	        if (targ.nodeType == 3) // defeat Safari bug
	        	targ = targ.parentNode;
            context = [targ, 'tl', 'bl'];
            fixedcenter = false;
            alert(context);
        }
    }
    
    //TODO: not sure we _want_ to allow millions of dialogs
//    var myDate = new Date();
//	var dialogDiv = document.createElement('div');
//	dialogDiv.id = 'JSPopup_'+myDate.getTime();
//	document.body.appendChild(dialogDiv);
//ONE dialog only
    var dialogDiv = 'win';
    
    //The second argument passed to the
    //constructor is a configuration object:
    myPanel = new YAHOO.widget.Dialog(dialogDiv, {
//        width:"75%", 
//        height:"75%",
//        width:"600px",
        fixedcenter: fixedcenter, 
        context: context,
        constraintoviewport: true, 
        underlay:"none", 
        close:true, 
        visible:false,
        draggable:true
        } 
    );
//	var myButtons = [ { text:"Submit", handler:handleSubmit, isDefault:true },
//				  { text:"Cancel", handler:handleCancel } ];
//	 myPanel.cfg.queueProperty("buttons", myButtons);
//    postIt.cfg.queueProperty("postmethod", "form");
//    postIt.callback.success = onSuccess;
//    postIt.callback.failure = onFailure;
    
    
    if (title.length > 0) {
        myPanel.setHeader(title);
    }
    myPanel.setBody('<div style="text-align:left;">'+text+'</div>');
    myPanel.render(document.body);
    
    if (border != 'on') {
        myPanel.setHeader('');
        //TODO: this is out of the docco, but has no effect :(
        myPanel.cfg.setProperty("close", false);
        myPanel.cfg.setProperty("draggable", false);

        //add across browser onmouseleave to close
        function fnCallback(e) { 
            if (!e) var e = window.event;
            var tg = (window.event) ? e.srcElement : e.target;
            if (tg.id != this.id) return;
            var reltg = (e.relatedTarget) ? e.relatedTarget : e.toElement;
            while (reltg != tg && reltg.nodeName != 'BODY')
                reltg= reltg.parentNode
            if (reltg== tg) return;
            
            myPanel = new YAHOO.widget.Panel(this.id); 
            myPanel.hide(); 
        } 
        YAHOO.util.Event.addListener(myPanel.id, "mouseout", fnCallback);
    }
    myPanel.show();
    
//    if (!event) var event = window.event;
//	event.cancelBubble = true;
//	if (event.stopPropagation) event.stopPropagation();
    
    return false;
}

twiki.JSPopupPlugin.ajaxCall = function(event, popupUrl, popupParams) {
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
    var callback = 
	{ 
	  success: function(o) {
	            var data = o.responseText;
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
                data = '<div>' + data + '</div>';
                twiki.JSPopupPlugin.openPopup(event, data);

	      }, 
	  failure: function(o) {alert('Error!\nStatusText='+o.statusText+'\nContents='+o.responseText);}
	  //,argument: [argument1, argument2, argument3] 
	};
	var transaction = YAHOO.util.Connect.asyncRequest('GET', popupUrl, callback, null); 
}    
    
/***********************************************************
more generic tools - need to share at some stage
*/
/* http://www.quirksmode.org/blog/archives/2005/10/_and_the_winner_1.html#more */
function addEvent( obj, type, fn )
{
	if (obj.addEventListener)
		obj.addEventListener( type, fn, false );
	else if (obj.attachEvent)
	{
		obj["e"+type+fn] = fn;
		obj[type+fn] = function() { obj["e"+type+fn]( window.event ); }
		obj.attachEvent( "on"+type, obj[type+fn] );
	}
}
function removeEvent( obj, type, fn )
{
	if (obj.removeEventListener)
		obj.removeEventListener( type, fn, false );
	else if (obj.detachEvent)
	{
		obj.detachEvent( "on"+type, obj[type+fn] );
		obj[type+fn] = null;
		obj["e"+type+fn] = null;
	}
}


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
