var tinymce_plugin_setUpContent = function(editor_id,body,doc) {
};

function pasteWordContentCallback(type,content){
    return content;
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
                var match = /^((?:\w+\.)*)(\w+)$/.exec(url);
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

