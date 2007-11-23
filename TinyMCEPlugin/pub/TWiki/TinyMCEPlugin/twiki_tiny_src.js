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

    twikiVars : null,
    request : null, // Container for HTTP request object
    metaTags : null,

    tml2html : new Array(), // callbacks, attached in plugins
    html2tml : new Array(), // callbacks, attached in plugins

    // Get a TWiki variable from the set passed
    getTWikiVar : function (name) {
        if (TWikiTiny.twikiVars == null) {
            var sets = tinyMCE.getParam("twiki_vars", "");
            TWikiTiny.twikiVars = eval(sets);
        }
        return TWikiTiny.twikiVars[name];
    },

    expandVariables : function(url) {
        for (var i in TWikiTiny.twikiVars) {
            url = url.replace('%' + i + '%', TWikiTiny.twikiVars[i], 'g');
        }
        return url;
    },

    transform : function(editor, handler, text, onReadyToSend, onReply) {
        // Work out the rest URL from the location
        var url = TWikiTiny.getTWikiVar("SCRIPTURL");
        var suffix = TWikiTiny.getTWikiVar("SCRIPTSUFFIX");
        if (suffix == null) suffix = '';
        url += "/rest" + suffix + "/WysiwygPlugin/" + handler;
        var path = TWikiTiny.getTWikiVar("WEB") + '.'
        + TWikiTiny.getTWikiVar("TOPIC");
        TWikiTiny.request = new Object();
        if (tinyMCE.isIE) {
            // branch for IE/Windows ActiveX version
            TWikiTiny.request.req = new ActiveXObject("Microsoft.XMLHTTP");
        } else {
            // branch for native XMLHttpRequest object
            TWikiTiny.request.req = new XMLHttpRequest();
        }
        TWikiTiny.request.editor = editor;
        TWikiTiny.request.req.open("POST", url, true);
        TWikiTiny.request.req.setRequestHeader(
            "Content-type", "application/x-www-form-urlencoded");
        // get the content of the associated textarea
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
                    onReply();
                } else {
                    onFail();
                }
            }
        };
        onReadyToSend();
        TWikiTiny.request.req.send(params);
    },

    // Set up content for the initial edit
    setUpContent : function(editor_id, body, doc) {
        var editor = tinyMCE.getInstanceById(editor_id);
        TWikiTiny.switchToWYSIWYG(editor);
    },

    // Convert HTML content to textarea. Called from the WYSIWYG->raw switch
    switchToRaw : function (inst) {
        var text = inst.getBody().innerHTML;
        // Evaluate post-processors
        for (var i = 0; i < TWikiTiny.html2tml.length; i++) {
            var cb = TWikiTiny.html2tml[i];
            text = cb.apply(inst, [ inst, text ]);
        }
        TWikiTiny.transform(
            inst, "html2tml", text,
            function () {
                var te = TWikiTiny.request.editor.oldTargetElement;
                te.value = "Please wait... retrieving page from server";
            },
            function () {
                var te = TWikiTiny.request.editor.oldTargetElement;
                var text = TWikiTiny.request.req.responseText;
                te.value = text;
            },
            function () {
                var te = TWikiTiny.request.editor.oldTargetElement;
                te.value = "There was a problem retrieving the page: "
                    + TWikiTiny.request.req.statusText;
            });
        // Add the button for the switch back to WYSIWYG mode
        var eid = inst.editorId;
        var id = eid + "_2WYSIWYG";
        var el = document.getElementById(id);
        if (el) {
            // exists, unhide it
            el.style.display = "block";
        } else {
            // does not exist, create it
            el = document.createElement('INPUT');
            el.id = id;
            el.type = "button";
            el.value = "WYSIWYG";
            el.onclick = function () {
                tinyMCE.execCommand("mceToggleEditor", null, inst.editorId);
                return false;
            }
            // Need to insert after to avoid knackering 'back'
            var pel = inst.oldTargetElement.parentNode;
            pel.insertBefore(el, inst.oldTargetElement);
        }
        // SMELL: what if there is already an onchange handler?
        inst.oldTargetElement.onchange = function() {
            var inst = tinyMCE.getInstanceById(eid);
            inst.isNotDirty = false;
            return true;
        }
    },

    // Convert textarea content to HTML. This is invoked from the content
    // setup handler, and also from the raw->WYSIWYG switch
    switchToWYSIWYG : function (editor) {
        // Kill the change handler to avoid excess fires
        editor.oldTargetElement.onchange = null;
        // Need to tinyMCE.execCommand("mceToggleEditor", null, editor_id);
        TWikiTiny.transform(
            editor, "tml2html", editor.oldTargetElement.value,
            function () {
                // Before send
                var editor = TWikiTiny.request.editor;
                tinyMCE.setInnerHTML(
                    TWikiTiny.request.editor.getBody(),
                    "<span class='twikiAlert'>Please wait... retrieving page from server</span>");
            },
            function () {
                // Handle the reply
                var text = TWikiTiny.request.req.responseText;
                // Evaluate any registered pre-processors
                for (var i = 0; i < TWikiTiny.tml2html.length; i++) {
                    var cb = TWikiTiny.tml2html[i];
                    text = cb.apply(editor, [ editor, text ]);
                }
                tinyMCE.setInnerHTML(TWikiTiny.request.editor.getBody(), text);
                TWikiTiny.request.editor.isNotDirty = true;
            },
            function () {
                // Handle a failure
                tinyMCE.setInnerHTML(
                    TWikiTiny.request.editor.getBody(),
                    "<div class='twikiAlert'>"
                    + "There was a problem retrieving the page: "
                    + TWikiTiny.request.req.statusText + "</div>");
            });

        // Hide the conversion button, if it exists
        var id = editor.editorId + "_2WYSIWYG";
        var el = document.getElementById(id);
        if (el) {
            // exists, hide it
            el.style.display = "none";
        }
    },

    // Callback on save. Make sure the WYSIWYG flag ID is there.
    saveCallback : function(editor_id, html, body) {
        // Evaluate any registered post-processors
        var editor = tinyMCE.getInstanceById(editor_id);
        for (var i = 0; i < TWikiTiny.html2tml.length; i++) {
            var cb = TWikiTiny.html2tml[i];
            html = cb.apply(editor, [ editor, html ]);
        }
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
