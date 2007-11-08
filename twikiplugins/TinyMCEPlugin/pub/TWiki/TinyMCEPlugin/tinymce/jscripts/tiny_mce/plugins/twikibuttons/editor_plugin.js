tinyMCE.importPluginLanguagePack('twikibuttons');var TWikiButtonsPlugin={getInfo:function(){return{longname:'TWiki Buttons Plugin',author:'Crawford Currie',authorurl:'http://c-dot.co.uk',infourl:'http://c-dot.co.uk',version:1};},initInstance:function(inst){},getControlHTML:function(cn){switch(cn){case"tt":return tinyMCE.getButtonHTML(cn,'lang_twikibuttons_tt_desc','{$pluginurl}/images/tt.gif','twikiTT',true);case"colour":return tinyMCE.getButtonHTML(cn,'lang_twikibuttons_colour_desc','{$pluginurl}/images/colour.gif','twikiCOLOUR',true);}
return"";},execCommand:function(editor_id,element,command,user_interface,value){var template,inst,elm;switch(command){case"twikiCOLOUR":var inst=tinyMCE.getInstanceById(editor_id);var t=inst.selection.getSelectedText();if(!(t&&t.length>0||pe))
return true;template=new Array();template['file']='../../plugins/twikibuttons/colours.htm';template['width']=240;template['height']=240;tinyMCE.openWindow(template,{editor_id:editor_id});return true;case"twikiTT":var inst=tinyMCE.getInstanceById(editor_id);var elm=inst.getFocusElement();var t=inst.selection.getSelectedText();var pe=tinyMCE.getParentElement(elm,'TT');if(!(t&&t.length>0||pe))
return true;if(elm&&elm.nodeName=='TT'){tinyMCE.execCommand('mceBeginUndoLevel');tinyMCE.execCommand('removeformat',false,elm);tinyMCE.triggerNodeChange();tinyMCE.execCommand('mceEndUndoLevel');}else{var s=inst.selection.getSelectedHTML();if(s.length>0){tinyMCE.execCommand('mceBeginUndoLevel');s='<tt>'+s+'</tt>';tinyMCE.execCommand('mceInsertContent',false,s);tinyMCE.triggerNodeChange();tinyMCE.execCommand('mceEndUndoLevel');}}
return true;}
return false;},handleNodeChange:function(editor_id,node,undo_index,undo_levels,visual_aid,any_selection){var elm=tinyMCE.getParentElement(node);if(node==null)
return;if(!any_selection){tinyMCE.switchClass(editor_id+'_tt','mceButtonDisabled');tinyMCE.switchClass(editor_id+'_colour','mceButtonDisabled');}else{tinyMCE.switchClass(editor_id+'_tt','mceButtonNormal');tinyMCE.switchClass(editor_id+'_colour','mceButtonNormal');}
switch(node.nodeName){case"TT":tinyMCE.switchClass(editor_id+'_tt','mceButtonSelected');return true;}
return true;}};tinyMCE.addPlugin("twikibuttons",TWikiButtonsPlugin);