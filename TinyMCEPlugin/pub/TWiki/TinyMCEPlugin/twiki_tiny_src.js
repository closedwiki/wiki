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

// The TWikiTiny class object
var TWikiTiny = {

    TWiki_Vars : null,

    // Get a TWiki variable from the set passed
    getTWikiVar : function (name) {
        if (TWikiTiny.TWiki_Vars == null) {
            var sets = tinyMCE.getParam("twiki_vars", "");
            TWikiTiny.TWiki_Vars = eval(sets);
        }
        return TWikiTiny.TWiki_Vars[name];
    },

    expandVariables : function(url) {
        for (var i in TWikiTiny.TWiki_Vars) {
            url = url.replace('%' + i + '%', TWikiTiny.TWiki_Vars[i], 'g');
        }
        return url;
    },

    request : new Object(), // HTTP request object

    // Asynchronous fetch of the topic content using the Wysiwyg REST handler.
    setUpContent : function(editor_id, body, doc) {
        TWikiTiny.request.editor_id = editor_id;
        TWikiTiny.request.doc = doc;
        TWikiTiny.request.body = body;
        // Work out the rest URL from the location
        var url = TWikiTiny.getTWikiVar("SCRIPTURL");
        var suffix = TWikiTiny.getTWikiVar("SCRIPTSUFFIX");
        if (suffix == null) suffix = '';
        url += "/rest" + suffix + "/WysiwygPlugin/tml2html";
        var path = TWikiTiny.getTWikiVar("WEB") + '.'
        + TWikiTiny.getTWikiVar("TOPIC");
        if (tinyMCE.isIE) {
            // branch for IE/Windows ActiveX version
            TWikiTiny.request.req = new ActiveXObject("Microsoft.XMLHTTP");
        } else {
            // branch for native XMLHttpRequest object
            TWikiTiny.request.req = new XMLHttpRequest();
        }
        TWikiTiny.request.req.open("POST", url, true);
        TWikiTiny.request.req.setRequestHeader(
            "Content-type", "application/x-www-form-urlencoded");
        // get the content of the associated textarea
        var editor = tinyMCE.getInstanceById(editor_id);
        var text = editor.oldTargetElement.value;
        
        var params = "nocache=" + encodeURIComponent((new Date()).getTime())
        + "&topic=" + encodeURIComponent(path)
        // The double-encoding is to overcome flaws in XMLHttpRequest. It makes
        // the TWikiTiny.request much larger than it needs to be, but at
        // least it works.
        + "&text=" + encodeURIComponent(escape(text));
    
        TWikiTiny.request.req.setRequestHeader(
            "Content-length", params.length);
        TWikiTiny.request.req.setRequestHeader("Connection", "close");
        TWikiTiny.request.req.onreadystatechange = function() {
            // Callback for XMLHttpRequest
            // only if TWikiTiny.request.req shows "complete"
            if (TWikiTiny.request.req.readyState == 4) {
                // only if "OK"
                if (TWikiTiny.request.req.status == 200) {
                    TWikiTiny.request.body.innerHTML =
                    TWikiTiny.request.req.responseText;
                    var editor = tinyMCE.getInstanceById(
                        TWikiTiny.request.editor_id);
                    editor.isNotDirty = true;
                } else {
                    TWikiTiny.request.body.innerHTML =
                    "<div class='twikiAlert'>"
                    + "There was a problem retrieving the page: "
                    + TWikiTiny.request.req.statusText + "</div>";
                }
            }
        };
        body.innerHTML = "<span class='twikiAlert'>Please wait... retrieving page from server</span>";
        TWikiTiny.request.req.send(params);
    },


    // Callback on save. Make sure the WYSIWYG flag ID is there.
    saveCallback : function(element_id, html, body) {
        var secret_id = tinyMCE.getParam('twiki_secret_id');
        if (secret_id != null && html.indexOf(
                '<!--' + secret_id + '-->') == -1) {
            // Something ate the ID. Probably IE. Add it back.
            html = '<!--' + secret_id + '-->' + html;
        }
        return html;
    },

    // Called on URL insertion, but not on image sources. Expand TWiki
    // variables in the url. If the URL is a simple filename, then assume
    // it's an attachment on the current topic.
    convertLink : function(url, node, onSave){
        if(onSave == null)
            onSave = false;
        var orig = url;
        var vsu = TWikiTiny.getTWikiVar("VIEWSCRIPTURL");
        url = TWikiTiny.expandVariables(url);
        if (onSave) {
            if (url.indexOf(vsu + '/') == 0) {
                url = url.substr(vsu.length + 1);
                url = url.replace(/\/+/g, '.');
                if (url.indexOf(vbls['WEB'] + '.') == 0) {
                    url = url.substr(vbls['WEB'].length + 1);
                }
            }
        } else {
            if (url.indexOf('/') == -1) {
                // if it's a wikiword, make a suitable link
                var match = /^((?:\w+\.)*)(\w+)$/.exec(url);
                if (match != null) {
                    var web = match[1];
                    var topic = match[2];
                    if (web == null || web.length == 0) {
                        web = TWikiTiny.getTWikiVar("WEB");
                    }
                    web = web.replace(/\.+/g, '/');
                    web = web.replace(/\/+$/, '');
                    url = vsu + '/' + web + '/' + topic;
                }
            }
        }
        return url;
    },

    // Called on URL insertion, but not on image sources. Expand TWiki
    // variables in the url. If the URL is a simple filename, then assume
    // it's an attachment on the current topic.
    convertPubURL : function(url){
        var orig = url;
        var base = TWikiTiny.getTWikiVar("PUBURL") + '/'
        + TWikiTiny.getTWikiVar("WEB") + '/'
        + TWikiTiny.getTWikiVar("TOPIC") + '/';
        url = TWikiTiny.expandVariables(url);
        if (url.indexOf('/') == -1) {
            url = base + url;
        }
        return url;
    },

    metaTags : null,

    getMetaTag : function(inKey) {
        if (TWikiTiny.metaTags == null || TWikiTiny.metaTags.length == 0) {
            // Do this the brute-force way because of the Firefox problem
            // seen sporadically on Bugs where the DOM appears complete, but
            // the META tags are not all found by getElementsByTagName
            var head = document.getElementsByTagName("META");
            head = head[0].parentNode.childNodes;
            TWikiTiny.metaTags = new Array();
            for (var i = 0; i < head.length; i++) {
                if (head[i].tagName != null &&
                    head[i].tagName.toUpperCase() == 'META') {
                    TWikiTiny.metaTags[head[i].name] = head[i].content;
                }
            }
        }
        return TWikiTiny.metaTags[inKey]; 
    },
    
    install : function() {
        // find the TINYMCEPLUGIN_INIT META
        var tmce_init = TWikiTiny.getMetaTag('TINYMCEPLUGIN_INIT');
        if (tmce_init != null) {
            eval("tinyMCE.init({" + unescape(tmce_init) + "});");
            return;
        }
        alert("Unable to install TinyMCE; <META name='TINYMCEPLUGIN_INIT' is missing"); 
    }
};
