// Content manipulation on startup
var tinymce_plugin_setUpContent = function(editor_id, body, doc) {
	// content is in body.innerHTML;
}

// onLoad handler that adds the wysiwyg_edit field to the main form in
// an edit page
var tinymce_plugin_addWysiwygTagToForm = function() {
   // SMELL: this really isn't good; the main form should have an ID
    var els = document.getElementsByName('main');
    for (var j = 0; j < els.length;j++) {
        var s = els[j].tagName;
        if (s.toLowerCase() == 'form') {
            var i = document.createElement('INPUT');
            i.type = 'hidden';
            i.name = 'wysiwyg_edit';
            i.value = 'save';
            els[j].appendChild(i);
            return;
        }
    }
};
