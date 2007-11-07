tinyMCE.importPluginLanguagePack('twikibuttons');

var TWikiButtonsPlugin = {
	getInfo : function() {
		return {
			longname : 'TWiki Buttons Plugin',
			author : 'Crawford Currie',
			authorurl : 'http://c-dot.co.uk',
			infourl : 'http://c-dot.co.uk',
			version : 1
		};
	},

	getControlHTML : function(cn) {
		switch (cn) {
			case "tt":
            return tinyMCE.getButtonHTML(cn, 'lang_twikibuttons_tt_desc', '{$pluginurl}/images/tt.gif', 'twikiTT', true);
		}

		return "";
	},

	execCommand : function(editor_id, element, command,
                           user_interface, value) {
		var template, inst, elm;

		switch (command) {
        case "twikiTT":
            if (!this._anySel(editor_id))
                return true;

            // if we are in a TT region, then removeformat
            var inst = tinyMCE.getInstanceById(editor_id);
            var elm = inst.getFocusElement();
            if (elm && elm.nodeName == 'TT'){
                tinyMCE.execCommand('mceBeginUndoLevel');
                tinyMCE.execCommand('removeformat', false, elm);
                tinyMCE.triggerNodeChange();
                tinyMCE.execCommand('mceEndUndoLevel');
            } else {
                var s = inst.selection.getSelectedHTML();
                if (s.length > 0) {
                    tinyMCE.execCommand('mceBeginUndoLevel');
                    s = '<tt>' + s + '</tt>';
                    tinyMCE.execCommand('mceInsertContent', false, s);
                    tinyMCE.triggerNodeChange();
                    tinyMCE.execCommand('mceEndUndoLevel');
                    // How do I restore the selection? Doesn't seem to be
                    // a way :-(
                }
            }

            return true;
		}
		return false;
	},

	handleNodeChange : function(editor_id, node, undo_index,
                                undo_levels, visual_aid, any_selection) {
		var elm = tinyMCE.getParentElement(node);

		if (node == null)
			return;

		if (!any_selection) {
			// Disable the buttons
			tinyMCE.switchClass(editor_id + '_tt', 'mceButtonDisabled');
		} else {
			// A selection means the buttons should be active.
			tinyMCE.switchClass(editor_id + '_tt', 'mceButtonNormal');
		}

		switch (node.nodeName) {
			case "TT":
            tinyMCE.switchClass(editor_id + '_tt', 'mceButtonSelected');
            return true;
		}

		return true;
	},

	_anySel : function(editor_id) {
		var inst = tinyMCE.getInstanceById(editor_id);
        var t = inst.selection.getSelectedText();

		if (t && t.length > 0)
            return true;

		var pe = tinyMCE.getParentElement(inst.getFocusElement(), 'TT');
        return pe;
	}
};

tinyMCE.addPlugin("twikibuttons", TWikiButtonsPlugin);
