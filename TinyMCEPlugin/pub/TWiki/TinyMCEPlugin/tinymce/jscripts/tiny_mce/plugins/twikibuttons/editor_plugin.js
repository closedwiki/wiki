(function(){tinymce.PluginManager.requireLangPack('twikibuttons');tinymce.create('tinymce.plugins.TWikiButtons',{formats_lb:null,init:function(ed,url){ed.fw_formats=ed.getParam("twikibuttons_formats");ed.fw_lb=null;ed.addCommand('twikibuttonsTT',function(){if(!ed.selection.isCollapsed())
ed.execCommand('mceSetCSSClass',false,"WYSIWYG_TT");});ed.addButton('tt',{title:'twikibuttons.tt_desc',cmd:'twikibuttonsTT',image:url+'/img/tt.gif'});ed.addCommand('twikibuttonsColour',function(){if(ed.selection.isCollapsed())
return;ed.windowManager.open({location:false,menubar:false,toolbar:false,status:false,url:url+'/colours.htm',width:240,height:140,movable:true,popup_css:false,inline:true},{plugin_url:url});});ed.addButton('colour',{title:'twikibuttons.colour_desc',cmd:'twikibuttonsColour',image:url+'/img/colour.gif'});ed.addCommand('twikibuttonsAttach',function(){ed.windowManager.open({location:false,menubar:false,toolbar:false,status:false,url:url+'/attach.htm',width:350,height:250,movable:true,inline:true},{plugin_url:url});});ed.addButton('attach',{title:'twikibuttons.attach_desc',cmd:'twikibuttonsAttach',image:url+'/img/attach.gif'});ed.addCommand('twikibuttonsHide',function(){if(TWikiTiny.saveEnabled){tinyMCE.execCommand("mceToggleEditor",true,ed.id);TWikiTiny.switchToRaw(ed);}});ed.addButton('hide',{title:'twikibuttons.hide_desc',cmd:'twikibuttonsHide',image:url+'/img/hide.gif'});ed.addCommand('twikibuttonsFormat',function(ui,fn){var format=null;for(var i=0;i<ed.fw_formats.length;i++){if(ed.fw_formats[i].name==fn){format=ed.fw_formats[i];break;}}
if(format.el!=null){var fmt=format.el;if(fmt.length)
fmt='<'+fmt+'>';ed.execCommand('FormatBlock',false,fmt);if(format.el==''){var elm=ed.selection.getNode();ed.execCommand('removeformat',false,elm);}}
if(format.style!=null){ed.execCommand('mceSetCSSClass',false,format.style);}
ed.nodeChanged();});ed.onNodeChange.add(this._nodeChange,this);},getInfo:function(){return{longname:'TWiki Buttons Plugin',author:'Crawford Currie',authorurl:'http://c-dot.co.uk',infourl:'http://c-dot.co.uk',version:2};},createControl:function(n,cm){if(n=='twikiformat'){var ed=tinyMCE.activeEditor;var m=cm.createListBox(ed.id+'_'+n,{title:'Format',onselect:function(format){ed.execCommand('twikibuttonsFormat',false,format);}});var formats=ed.getParam("twikibuttons_formats");for(var i=0;i<formats.length;i++){m.add(formats[i].name,formats[i].name);}
m.selectByIndex(0);ed.fw_lb=m;return m;}
return null;},_nodeChange:function(ed,cm,n,co){if(n==null)
return;if(co){cm.setDisabled('tt',true);cm.setDisabled('colour',true);}else{cm.setDisabled('tt',false);cm.setDisabled('colour',false);}
var elm=ed.dom.getParent(n,'.WYSIWYG_TT');if(elm!=null)
cm.setActive('tt',true);else
cm.setActive('tt',false);elm=ed.dom.getParent(n,'.WYSIWYG_COLOR');if(elm!=null)
cm.setActive('colour',true);else
cm.setActive('colour',false);if(ed.fw_lb){var puck=-1;var nn=n.nodeName.toLowerCase();do{for(var i=0;i<ed.fw_formats.length;i++){if((!ed.fw_formats[i].el||ed.fw_formats[i].el==nn)&&(!ed.fw_formats[i].style||ed.dom.hasClass(ed.fw_formats[i].style))){puck=i;if(puck>0)
break;}}}while(puck<0&&(n=n.parentNode)!=null);if(puck>=0){ed.fw_lb.selectByIndex(puck);}}
return true;}});tinymce.PluginManager.add('twikibuttons',tinymce.plugins.TWikiButtons);})();
