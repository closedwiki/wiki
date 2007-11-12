// Functions specific to the actions of the colour-setting dialog
function setColour(colour) {
	var inst = tinyMCE.getInstanceById(tinyMCE.getWindowArg('editor_id'));
    var s = inst.selection.getSelectedHTML();
    if (s.length > 0) {
        tinyMCEPopup.execCommand('mceBeginUndoLevel');
        // Styled spans don't work inside the editor for some reason
        s = '<font class="WYSIWYG_COLOR" color="' +
            colour
            + '">' + s + '</font>';
        tinyMCE.execCommand('mceInsertContent', false, s);
        tinyMCE.triggerNodeChange();
        tinyMCEPopup.execCommand('mceEndUndoLevel');
    }
    tinyMCEPopup.close();
}
