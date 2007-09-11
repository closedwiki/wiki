// Content manipulation on startup
var tinymce_plugin_setUpContent = function(editor_id, body, doc) {
    //body.innerHTML = TML2HTML.convert(body.innerHTML);
};

function pasteWordContentCallback(type, content) {
    return content;
}

// Called on URL insertion, but not on image sources. Expand TWiki variables
// in the url. If the URL is a simple filename, then assume it's an attachment
// on the current topic.
function twikiConvertURL(url, node, onSave) {
    if (onSave == null)
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
            // Convert site url to wikiword
            if (url.indexOf(vbls['VIEWSCRIPTURL']+'/') == 0) {
                url = url.substr(vbls['VIEWSCRIPTURL'].length + 1);
                url = url.replace('/', '.', 'g');
                if (url.indexOf(vbls['WEB'] + '.') == 0) {
                    url = url.substr(vbls['WEB'].length + 1);
                }
            }
        } else {
            if (url.indexOf('/') == -1) {
                // Simple string with possible web prefix? Note we don't
                // support / web separators, as they may be confused
                // with a URL path
                var match = /^((?:\w+\.)*)(\w+)$/.exec(url);
                if (match != null) {
                    var web = match[1];
                    var topic = match[2];
                    if (web == null || web.length == 0) {
                        web = vbls['WEB'];
                    }
                    // Convert to / separated path
                    web = web.replace('.', '/', 'g');
                    // Remove trailing /'s from web
                    web = web.replace(/\/+$/, '');
                    url = vbls['VIEWSCRIPTURL'] + '/' + web + '/' + topic;
                } else {
                    // Treat as attachment name
                    url = vbls['PUBURL'] + '/' + vbls['WEB'] + '/'+
                        vbls['TOPIC'] + '/' + url;
                }
            }
        }
    }
    //alert("Convert "+orig+" to"+url);
    return url;
}

var LINE_HEIGHT = 16;
var IFRAME_ID = 'mce_editor_0';

/**
Overrides changeEditBox in twiki_edit.js.
*/
function changeEditBox(inDirection) {
	var iframe = document.getElementById(IFRAME_ID);
	var rowCount = Math.floor(iframe.clientHeight / LINE_HEIGHT);
	rowCount += (inDirection * EDITBOX_CHANGE_STEP_SIZE);
	rowCount = (rowCount < EDITBOX_MIN_ROWCOUNT) ? EDITBOX_MIN_ROWCOUNT : rowCount;
	setEditBoxHeight(rowCount);
	twiki.Pref.setPref(PREF_NAME + EDITBOX_PREF_ROWS_ID, rowCount);
	return false;
}

/**
Overrides setEditBoxHeight in twiki_edit.js.
*/
function setEditBoxHeight(inRowCount) {
	var iframe = document.getElementById(IFRAME_ID);
	if (iframe == null) return;

	var oldHeight = iframe.clientHeight;
	
	var newHeight = 16 * inRowCount;
	//iframe.style.height = newHeight;
	animateChangeHeight(IFRAME_ID, oldHeight, newHeight, .2);
}

/**
Give the iframe table holder auto-height.
*/
function initTextAreaStyles () {
	
	if (Pattern.Edit != null) Pattern.Edit.initTextAreaStyles(["enlarge", "shrink"]);
	
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

/**
Animates the height of the iframe.
*/
function animateChangeHeight(id, start, end, duration) {
	//speed for each frame
	var speed = Math.round(duration*1000 / 100);
	var timer = 0;

	//determine the direction for the blending, if start and end are the same nothing happens
	if (start > end) {
		for (i = start; i >= end; i--) {
			setTimeout("doSlideHeight(" + i + ",'" + id + "')",(timer * speed));
			timer++;
		}
	} else if(start < end) {
		for (i = start; i <= end; i++) {
			setTimeout("doSlideHeight(" + i + ",'" + id + "')",(timer * speed));
			timer++;
		}
	}
}
function doSlideHeight(inHeight, id) {
	var el = document.getElementById(id);
	el.style.height = inHeight + "px";
}
