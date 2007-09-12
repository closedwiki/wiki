/*
 Copyright (C) 2007 Crawford Currie http://wikiring.com and Arthur Clemens
 All Rights Reserved.

 This program is free software; you can redistribute it and/or
 modify it under the terms of the GNU General Public License
 as published by the Free Software Foundation; either version 2
 of the License, or (at your option) any later version. For
 more details read LICENSE in the root of the TWiki distribution.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 As per the GPL, removal of this notice is prohibited.
*/

// Asynchronous fetch of the topic content using the Wysiwyg REST handler.
var tinymce_plugin_setUpContent = function(editor_id, body, doc) {
    var request = new Object();
    request.doc = doc;
    request.body = body;
    // Work out the rest URL from the location
    var url = location.pathname;
    var match = /^(.*)\/edit(\.[^\/]*)?\/([^?]*).*$/.exec(url);
    var suffix = match[2]; if (suffix == null) suffix = '';
    url = match[1] + "/rest" + suffix + "/WysiwygPlugin/tml2html";
    var path = match[3];
    path = path.replace('/', '.', 'g');
    if (tinyMCE.isIE) {
        // branch for IE/Windows ActiveX version
        request.req = new ActiveXObject("Microsoft.XMLHTTP");
    } else {
        // branch for native XMLHttpRequest object
        request.req = new XMLHttpRequest();
    }
    request.req.open("POST", url, true);
    request.req.setRequestHeader(
        "Content-type", "application/x-www-form-urlencoded");
    // get the content of the associated textarea
    var editor = tinyMCE.getInstanceById(editor_id);
    var text = editor.oldTargetElement.value;
    var params = "nocache=" + parseInt(Math.random() * 10000000000) +
    "&topic=" + escape(path) + "&text=" + escape(text);
    
    request.req.setRequestHeader("Content-length", params.length);
    request.req.setRequestHeader("Connection", "close");
    request.req.onreadystatechange = function() {
        contentReadCallback(request);
    };
    body.innerHTML = "<span class='twikiAlert'>Please wait... retrieving page from server</span>";
    request.req.send(params);
}

// Callback for XMLHttpRequest
function contentReadCallback(request) {
    // only if request.req shows "complete"
    if (request.req.readyState == 4) {
        // only if "OK"
        if (request.req.status == 200) {
            request.body.innerHTML = request.req.responseText;
        } else {
            request.body.innerHTML =
                "<div class='twikiAlert'>"
                + "There was a problem retrieving the page: "
                + request.req.statusText + "</div>";
        }
    }
}

// Called on URL insertion, but not on image sources. Expand TWiki variables
// in the url. If the URL is a simple filename, then assume it's an attachment
// on the current topic.
function twikiConvertURL(url,node,onSave){
    if(onSave == null)
        onSave = false;
    var orig = url;
    var vars = tinyMCE.getParam("twiki_vars", "");
    if (vars != null) {
        var sets = vars.split(',');
        var vbls = new Object;
        for (var i = 0; i < sets.length; i++) {
            var v = sets[i].split('=');
            vbls[v[0]] = v[1];
            url = url.replace('%' + v[0] + '%', v[1]);
        }
        if (onSave) {
            if (url.indexOf(vbls['VIEWSCRIPTURL'] + '/') == 0) {
                url = url.substr(vbls['VIEWSCRIPTURL'].length + 1);
                url = url.replace('/', '.', 'g');
                if (url.indexOf(vbls['WEB'] + '.') == 0) {
                    url = url.substr(vbls['WEB'].length + 1);
                }
            }
        } else {
            if (url.indexOf('/') == -1) {
                var match = /^((?:[^$-_.+!*'(),\/]*\.)*)([^$-_.+!*'(),\/]+)$/.exec(url);
                if (match != null) {
                    var web = match[1];
                    var topic = match[2];
                    if (web == null || web.length == 0) {
                        web = vbls['WEB'];
                    }
                    web = web.replace('.', '/', 'g');
                    web = web.replace(/\/+$/, '');
                    url = vbls['VIEWSCRIPTURL'] + '/' + web + '/' + topic;
                } else {
                    url = vbls['PUBURL'] + '/' + vbls['WEB'] + '/'+
                        vbls['TOPIC'] + '/' + url;
                }
            }
        }
    }
    return url;
}

var IFRAME_ID = 'mce_editor_0';

/**
Overrides changeEditBox in twiki_edit.js.
*/
function changeEditBox(inDirection) {
	return false;
}

/**
Overrides setEditBoxHeight in twiki_edit.js.
*/
function setEditBoxHeight(inRowCount) {}

/**
Give the iframe table holder auto-height.
*/
function initTextAreaStyles () {
	
	var iframe = document.getElementById(IFRAME_ID);
	if (iframe == null) return;
	
	// walk up to the table
	var node = iframe.parentNode;
	var counter = 0;
	while (node != document) {
		if (node.nodeName == 'TABLE') {
			node.style.height = 'auto';
			
			// get select boxes
			var selectboxes = node.getElementsByTagName('SELECT');
			var i, ilen = selectboxes.length;
			for (i=0; i<ilen; ++i) {
				selectboxes[i].style.marginLeft = selectboxes[i].style.marginRight = '2px';
				selectboxes[i].style.fontSize = '94%';
			}
			
			break;
		}
		node = node.parentNode;
	}
	
}

