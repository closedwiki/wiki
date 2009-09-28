/*
  
  Copyright (C) 2009 TWIKI.NET (http:/www.twiki.net) and 
  TWiki Contributors. 

  # Additional copyrights apply to some or all of the code in this
  # file as follows:
 

  Copyright (C) 2007-2009 Crawford Currie http://c-dot.co.uk
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
(function() {
    tinymce.PluginManager.requireLangPack('twikibuttons');

	tinymce.create('tinymce.plugins.TWikiButtons', {
        formats_lb: null, // formats listbox

        init : function(ed, url) {

            ed.fw_formats = ed.getParam("twikibuttons_formats");
            ed.fw_lb = null;

            // Register commands
            ed.addCommand('twikibuttonsTT', function() {
                if (!ed.selection.isCollapsed())
                    ed.execCommand('mceSetCSSClass', false, "WYSIWYG_TT");
            });

			// Register buttons
			ed.addButton('tt', {
                title : 'twikibuttons.tt_desc',
                cmd : 'twikibuttonsTT',
                image: url + '/img/tt.gif'
			});

            ed.addCommand('twikibuttonsColour', function() {
                if (ed.selection.isCollapsed())
                    return;
                ed.windowManager.open({
                    location: false,
                    menubar: false,
                    toolbar: false,
                    status: false,
                    url : url + '/colours.htm',
                    width : 240,
                    height : 140,
                    movable : true,
                    popup_css: false, // not required
                    inline : true
                }, {
                    plugin_url: url
                });
            });

			ed.addButton('colour', {
				title : 'twikibuttons.colour_desc',
				cmd : 'twikibuttonsColour',
                image: url + '/img/colour.gif'
			});

            ed.addCommand('twikibuttonsAttach', function() {
                ed.windowManager.open({
                    location: false,
                    menubar: false,
                    toolbar: false,
                    status: false,
                    url : url + '/attach.htm',
                    width : 350,
                    height : 250,
                    movable : true,
                    inline : true
                }, {
                    plugin_url: url
                });
            });

            ed.addButton('attach', {
				title : 'twikibuttons.attach_desc',
				cmd : 'twikibuttonsAttach',
                image: url + '/img/attach.gif'
			});

            ed.addCommand('twikibuttonsHide', function() {
                if (TWikiTiny.saveEnabled) {
                    tinyMCE.execCommand("mceToggleEditor", true, ed.id);
                    TWikiTiny.switchToRaw(ed);
                }
            });

			ed.addButton('hide', {
				title : 'twikibuttons.hide_desc',
				cmd : 'twikibuttonsHide',
                image: url + '/img/hide.gif'
			});

            ed.addCommand('twikibuttonsFormat', function(ui, fn) {
                var format = null;
                for (var i = 0; i < ed.fw_formats.length; i++) {
                    if (ed.fw_formats[i].name == fn) {
                        format = ed.fw_formats[i];
                        break;
                    }
                }
                if (format.el != null) {
                    var fmt = format.el;
                    if (fmt.length)
                        fmt = '<' + fmt + '>';
                    // SMELL: MIDAS command
                    ed.execCommand('FormatBlock', false, fmt);
                    if (format.el == '') {
                        var elm = ed.selection.getNode();
                        // SMELL: MIDAS command
                        ed.execCommand('removeformat', false, elm);
                    }
                }
                if (format.style != null) {
                    // element is additionally styled
                    ed.execCommand('mceSetCSSClass', false,
                                   format.style);
                }
                ed.nodeChanged();
            });

			ed.onNodeChange.add(this._nodeChange, this);
		},

		getInfo : function() {
			return {
                    longname : 'TWiki Buttons Plugin',
                    author : 'Crawford Currie',
                    authorurl : 'http://c-dot.co.uk',
                    infourl : 'http://c-dot.co.uk',
                    version : 2
			};
        },

		createControl : function(n, cm) {
            if (n == 'twikiformat') {
                var ed = tinyMCE.activeEditor;
                var m = cm.createListBox(ed.id + '_' + n, {
                   title : 'Format',
                   onselect : function(format) {
                       ed.execCommand('twikibuttonsFormat', false, format);
                   }
                });
                var formats = ed.getParam("twikibuttons_formats");
                // Build format select
                for (var i = 0; i < formats.length; i++) {
                    m.add(formats[i].name, formats[i].name);
                }
                m.selectByIndex(0);
                ed.fw_lb = m;
                return m;
            }
			return null;
		},

        _nodeChange : function(ed, cm, n, co) {
    		if (n == null)
    			return;

    		if (co) {
    			// Disable the buttons
    			cm.setDisabled('tt', true);
    			cm.setDisabled('colour', true);
    		} else {
    			// A selection means the buttons should be active.
    			cm.setDisabled('tt', false);
    			cm.setDisabled('colour', false);
    		}
            var elm = ed.dom.getParent(n, '.WYSIWYG_TT');
            if (elm != null)
                cm.setActive('tt', true);
			else
                cm.setActive('tt', false);
            elm = ed.dom.getParent(n, '.WYSIWYG_COLOR');
            if (elm != null)
                cm.setActive('colour', true);
			else
                cm.setActive('colour', false);

            if (ed.fw_lb) {
                var puck = -1;
                var nn = n.nodeName.toLowerCase();
                do {
                    for (var i = 0; i < ed.fw_formats.length; i++) {
                        if ((!ed.fw_formats[i].el
                             || ed.fw_formats[i].el == nn)
                            && (!ed.fw_formats[i].style ||
                                ed.dom.hasClass(ed.fw_formats[i].style))) {
                            // Matched el+style or just el
                            puck = i;
                            // Only break if the format is not Normal
                            // (which always matches, and is at pos 0)
                            if (puck > 0)
                                break;
                        }
                    }
                } while (puck < 0 && (n = n.parentNode) != null);
                if (puck >= 0) {
                    ed.fw_lb.selectByIndex(puck);
                }
            }
    		return true;

    	}
	});

	// Register plugin
	tinymce.PluginManager.add('twikibuttons',
                              tinymce.plugins.TWikiButtons);
})();

/* Tiny MCE 2 version

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

	initInstance : function(inst) {
		//tinyMCE.importCSS(inst.getDoc(),
        //tinyMCE.baseURL + "/plugins/twikibuttons/css/twikibuttons.css");
	},

	getControlHTML : function(cn) {
        var html, formats;
		switch (cn) {
        case "tt":
            return tinyMCE.getButtonHTML(cn, 'lang_twikibuttons_tt_desc',
                                         '{$pluginurl}/images/tt.gif',
                                         'twikiTT', true);
        case "colour":
            return tinyMCE.getButtonHTML(cn, 'lang_twikibuttons_colour_desc',
                                         '{$pluginurl}/images/colour.gif',
                                         'twikiCOLOUR', true);
        case "attach":
            return tinyMCE.getButtonHTML(cn, 'lang_twikibuttons_attach_desc',
                                         '{$pluginurl}/images/attach.gif',
                                         'twikiATTACH', true);
        case "hide":
            return tinyMCE.getButtonHTML(cn, 'lang_twikibuttons_hide_desc',
                                         '{$pluginurl}/images/hide.gif',
                                         'twikiHIDE', true);
        case "twikiformat":
            html = '<select id="{$editor_id}_twikiFormatSelect" name="{$editor
_id}_twikiFormatSelect" onfocus="tinyMCE.addSelectAccessibility(event, this, w
indow);" onchange="tinyMCE.execInstanceCommand(\'{$editor_id}\',\'twikiFORMAT\
',false,this.options[this.selectedIndex].value);" class="mceSelectList">';
            formats = tinyMCE.getParam("twikibuttons_formats");
            // Build format select
            for (var i = 0; i < formats.length; i++) {
                html += '<option value="'+ formats[i].name + '">'
                    + formats[i].name + '</option>';
            }
            html += '</select>';
            
            return html;
		}

		return "";
	},

	execCommand : function(editor_id, element, command,
                           user_interface, value) {
		var em;
        var inst = tinyMCE.getInstanceById(editor_id);

		switch (command) {
        case "twikiCOLOUR":
            var t = inst.selection.getSelectedText();
            if (!(t && t.length > 0 || pe))
                return true;

            template = new Array();
            template['file'] = '../../plugins/twikibuttons/colours.htm';
            template['width'] = 240;
            template['height'] = 140;
            tinyMCE.openWindow(template, {editor_id : editor_id});
            return true;

        case "twikiTT":
            inst = tinyMCE.getInstanceById(editor_id);
            elm = inst.getFocusElement();
            var t = inst.selection.getSelectedText();
            var pe = tinyMCE.getParentElement(elm, 'TT');

            if (!(t && t.length > 0 || pe))
                return true;
            var s = inst.selection.getSelectedHTML();
            if (s.length > 0) {
                tinyMCE.execCommand('mceBeginUndoLevel');
                tinyMCE.execInstanceCommand(
                    editor_id, 'mceSetCSSClass', user_interface,
                    "WYSIWYG_TT");
                tinyMCE.execCommand('mceEndUndoLevel');
            }

            return true;

        case "twikiHIDE":
            tinyMCE.execCommand("mceToggleEditor", user_interface, editor_id);
            return true;

        case "twikiATTACH":
            template = new Array();
            template['file'] = '../../plugins/twikibuttons/attach.htm';
            template['width'] = 350;
            template['height'] = 250;
            tinyMCE.openWindow(template, {editor_id : editor_id});
            return true;

        case "twikiFORMAT":
            var formats = tinyMCE.getParam("twikibuttons_formats");
            var format = null;
            for (var i = 0; i < formats.length; i++) {
                if (formats[i].name == value) {
                    format = formats[i];
                    break;
                }
            }

            if (format != null) {
                // if None, then remove all the styles that are in the
                // formats
                tinyMCE.execCommand('mceBeginUndoLevel');
                if (format.el != null) {
                    var fmt = format.el;
                    if (fmt.length)
                        fmt = '<' + fmt + '>';
                    tinyMCE.execInstanceCommand(
                        editor_id, 'FormatBlock', user_interface, fmt);
                    if (format.el == '') {
                        elm = inst.getFocusElement();
                        tinyMCE.execCommand(
                            'removeformat', user_interface, elm);
                    }
                }
                if (format.style != null) {
                    // element is additionally styled
                    tinyMCE.execInstanceCommand(
                        editor_id, 'mceSetCSSClass', user_interface,
                        format.style);
                }
                tinyMCE.triggerNodeChange();
            }
            tinyMCE.execCommand('mceEndUndoLevel');
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
			tinyMCE.switchClass(editor_id + '_tt', 'mceButtonDisable
d');
			tinyMCE.switchClass(editor_id + '_colour', 'mceButtonDis
abled');
		} else {
			// A selection means the buttons should be active.
			tinyMCE.switchClass(editor_id + '_tt', 'mceButtonNormal'
);
			tinyMCE.switchClass(editor_id + '_colour', 'mceButtonNor
mal');
		}

		switch (node.nodeName) {
			case "TT":
            tinyMCE.switchClass(editor_id + '_tt', 'mceButtonSelected');
            return true;
		}

		var selectElm = document.getElementById(
            editor_id + "_twikiFormatSelect");
        if (selectElm) {
            var formats = tinyMCE.getParam("twikibuttons_formats");
            var puck = -1;
            do {
                for (var i = 0; i < formats.length; i++) {
                    if (!formats[i].el ||
                        formats[i].el == node.nodeName.toLowerCase()) {
                        if (!formats[i].style ||
                            RegExp('\\b' + formats[i].style + '\\b').test(
                                tinyMCE.getAttrib(node, "class"))) {
                            // Matched el+style or just el
                            puck = i;
                            // Only break if the format is not Normal (which
                            // always matches, and is at pos 0)
                            if (puck > 0)
                                break;
                        }
                    }
                }
            } while (puck < 0 && (node = node.parentNode) != null);
            if (puck >= 0) {
                selectElm.selectedIndex = puck;
            }
        }
		return true;
	}
};

tinyMCE.addPlugin("twikibuttons", TWikiButtonsPlugin);
*/
