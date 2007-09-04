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
            url = url.replace('%'+v[0]+'%', v[1]);
        }
        if (onSave) {
            // Convert site url to wikiword
            if (url.indexOf(vbls['VIEWSCRIPTURL']+'/') == 0) {
                url = url.substr(vbls['VIEWSCRIPTURL'].length + 1);
                url = url.replace('/', '.');
                if (url.indexOf(vbls['WEB']+'.') == 0) {
                    url = url.substr(vbls['WEB'].length + 1);
                }
            }
        } else {
            if (url.indexOf('/') == -1) {
                // Simple wikiword?
                var match = /^(?:([A-Z][a-z0-9A-Z_]+)\.)?([A-Z][a-z0-9A-Z]+[A-Z][a-z0-9A-Z]*)$/.exec(url);
                if (match != null) {
                    var web = match[1];
                    var topic = match[2];
                    if (web == null) {
                        web = vbls['WEB'];
                    }
                    url = vbls['VIEWSCRIPTURL']+'/'+web+'/'+topic;
                } else {
                    // Treat as attachment name
                    url = vbls['PUBURL']+'/'+vbls['WEB']+'/'+
                        vbls['TOPIC']+'/'+url;
                }
            }
        }
    }
    //alert("Convert "+orig+" to"+url);
    return url;
}
