var TWikiTiny={twikiVars:null,metaTags:null,tml2html:new Array(),html2tml:new Array(),getTWikiVar:function(name){if(TWikiTiny.twikiVars==null){var sets=tinyMCE.activeEditor.getParam("twiki_vars","");TWikiTiny.twikiVars=eval(sets);}
return TWikiTiny.twikiVars[name];},expandVariables:function(url){for(var i in TWikiTiny.twikiVars){url=url.replace('%'+i+'%',TWikiTiny.twikiVars[i],'g');}
return url;},saveEnabled:0,enableSaveButton:function(enabled){var status=enabled?null:"disabled";TWikiTiny.saveEnabled=enabled?1:0;var elm=document.getElementById("save");if(elm){elm.disabled=status;}
elm=document.getElementById("quietsave");if(elm){elm.disabled=status;}
elm=document.getElementById("checkpoint");if(elm){elm.disabled=status;}
elm=document.getElementById("preview");if(elm){elm.style.display='none';elm.disabled=status;}},transform:function(editor,handler,text,onSuccess,onFail){var url=TWikiTiny.getTWikiVar("SCRIPTURL");var suffix=TWikiTiny.getTWikiVar("SCRIPTSUFFIX");if(suffix==null)suffix='';url+="/rest"+suffix+"/WysiwygPlugin/"+handler;var path=TWikiTiny.getTWikiVar("WEB")+'.'
+TWikiTiny.getTWikiVar("TOPIC");tinymce.util.XHR.send({url:url,content_type:"application/x-www-form-urlencoded",type:"POST",data:"nocache="+encodeURIComponent((new Date()).getTime())
+"&topic="+encodeURIComponent(path)
+"&text="+encodeURIComponent(text),async:true,scope:editor,success:onSuccess,error:onFail})},initialisedFromServer:false,setUpContent:function(editor_id,body,doc){if(TWikiTiny.initialisedFromServer)return;var editor=tinyMCE.getInstanceById(editor_id);TWikiTiny.switchToWYSIWYG(editor);TWikiTiny.initialisedFromServer=true;},cleanBeforeSave:function(eid,buttonId){var el=document.getElementById(buttonId);if(el==null)
return;el.onclick=function(){var editor=tinyMCE.getInstanceById(eid);editor.isNotDirty=true;return true;}},onSubmitHandler:false,switchToRaw:function(editor){var text=editor.getContent();var el=document.getElementById("twikiTinyMcePluginWysiwygEditHelp");if(el){el.style.display='none';}
el=document.getElementById("twikiTinyMcePluginRawEditHelp");if(el){el.style.display='block';}
for(var i=0;i<TWikiTiny.html2tml.length;i++){var cb=TWikiTiny.html2tml[i];text=cb.apply(editor,[editor,text]);}
TWikiTiny.enableSaveButton(false);editor.getElement().value="Please wait... retrieving page from server.";TWikiTiny.transform(editor,"html2tml",text,function(text,req,o){this.getElement().value=text;TWikiTiny.enableSaveButton(true);},function(type,req,o){this.setContent("<div class='twikiAlert'>"
+"There was a problem retrieving "
+o.url+": "
+type+" "+req.status+"</div>");});var eid=editor.id;var id=eid+"_2WYSIWYG";var el=document.getElementById(id);if(el){el.style.display="block";}else{el=document.createElement('INPUT');el.id=id;el.type="button";el.value="WYSIWYG";el.className="twikiButton";el.onclick=function(){var el=document.getElementById("twikiTinyMcePluginWysiwygEditHelp");if(el){el.style.display='block';}
el=document.getElementById("twikiTinyMcePluginRawEditHelp");if(el){el.style.display='none';}
tinyMCE.execCommand("mceToggleEditor",null,eid);TWikiTiny.switchToWYSIWYG(editor);return false;}
var pel=editor.getElement().parentNode;pel.insertBefore(el,editor.getElement());}
editor.getElement().onchange=function(){var editor=tinyMCE.getInstanceById(eid);editor.isNotDirty=false;return true;},this.onSubmitHandler=function(ed,e){editor.initialized=false;};editor.onSubmit.addToTop(this.onSubmitHandler);TWikiTiny.cleanBeforeSave(eid,"save");TWikiTiny.cleanBeforeSave(eid,"quietsave");TWikiTiny.cleanBeforeSave(eid,"checkpoint");TWikiTiny.cleanBeforeSave(eid,"preview");TWikiTiny.cleanBeforeSave(eid,"cancel");},switchToWYSIWYG:function(editor){editor.getElement().onchange=null;var text=editor.getElement().value;if(this.onSubmitHandler){editor.onSubmit.remove(this.onSubmitHandler);this.onSubmitHandler=null;}
TWikiTiny.enableSaveButton(false);editor.setContent("<span class='twikiAlert'>"
+"Please wait... retrieving page from server."
+"</span>");TWikiTiny.transform(editor,"tml2html",text,function(text,req,o){for(var i=0;i<TWikiTiny.tml2html.length;i++){var cb=TWikiTiny.tml2html[i];text=cb.apply(this,[this,text]);}
this.setContent(text);this.isNotDirty=true;TWikiTiny.enableSaveButton(true);},function(type,req,o){this.setContent("<div class='twikiAlert'>"
+"There was a problem retrieving "
+o.url+": "
+type+" "+req.status+"</div>");});var id=editor.id+"_2WYSIWYG";var el=document.getElementById(id);if(el){el.style.display="none";}},saveCallback:function(editor_id,html,body){var editor=tinyMCE.getInstanceById(editor_id);for(var i=0;i<TWikiTiny.html2tml.length;i++){var cb=TWikiTiny.html2tml[i];html=cb.apply(editor,[editor,html]);}
var secret_id=tinyMCE.activeEditor.getParam('twiki_secret_id');if(secret_id!=null&&html.indexOf('<!--'+secret_id+'-->')==-1){html='<!--'+secret_id+'-->'+html;}
return html;},convertLink:function(url,node,onSave){if(onSave==null)
onSave=false;var orig=url;var pubUrl=TWikiTiny.getTWikiVar("PUBURL");var vsu=TWikiTiny.getTWikiVar("VIEWSCRIPTURL");url=TWikiTiny.expandVariables(url);if(onSave){if((url.indexOf(pubUrl+'/')!=0)&&(url.indexOf(vsu+'/')==0)){url=url.substr(vsu.length+1);url=url.replace(/\/+/g,'.');if(url.indexOf(TWikiTiny.getTWikiVar('WEB')+'.')==0){url=url.substr(TWikiTiny.getTWikiVar('WEB').length+1);}}}else{if(url.indexOf('/')==-1){var match=/^((?:\w+\.)*)(\w+)$/.exec(url);if(match!=null){var web=match[1];var topic=match[2];if(web==null||web.length==0){web=TWikiTiny.getTWikiVar("WEB");}
web=web.replace(/\.+/g,'/');web=web.replace(/\/+$/,'');url=vsu+'/'+web+'/'+topic;}}}
return url;},convertPubURL:function(url){url=TWikiTiny.expandVariables(url);if(url.indexOf('/')==-1){var base=TWikiTiny.getTWikiVar("PUBURL")+'/'
+TWikiTiny.getTWikiVar("WEB")+'/'
+TWikiTiny.getTWikiVar("TOPIC")+'/';url=base+url;}
return url;},getMetaTag:function(inKey){if(TWikiTiny.metaTags==null||TWikiTiny.metaTags.length==0){var head=document.getElementsByTagName("META");head=head[0].parentNode.childNodes;TWikiTiny.metaTags=new Array();for(var i=0;i<head.length;i++){if(head[i].tagName!=null&&head[i].tagName.toUpperCase()=='META'){TWikiTiny.metaTags[head[i].name]=head[i].content;}}}
return TWikiTiny.metaTags[inKey];},install:function(){var tmce_init=this.getMetaTag('TINYMCEPLUGIN_INIT');if(tmce_init!=null){eval("tinyMCE.init({"+unescape(tmce_init)+"});");return;}
alert("Unable to install TinyMCE; <META name='TINYMCEPLUGIN_INIT' is missing");},getTopicPath:function(){return this.getTWikiVar("WEB")+'.'+this.getTWikiVar("TOPIC");},getScriptURL:function(script){var scripturl=this.getTWikiVar("SCRIPTURL");var suffix=this.getTWikiVar("SCRIPTSUFFIX");if(suffix==null)suffix='';return scripturl+"/"+script+suffix;},getRESTURL:function(fn){return this.getScriptURL('rest')+"/WysiwygPlugin/"+fn;},getListOfAttachments:function(onSuccess){var url=this.getRESTURL('attachments');var path=this.getTopicPath();var params="nocache="+encodeURIComponent((new Date()).getTime())
+"&topic="+encodeURIComponent(path);tinymce.util.XHR.send({url:url+"?"+params,type:"POST",content_type:"application/x-www-form-urlencoded",data:params,success:function(atts){if(atts!=null){onSuccess(eval(atts));}}});}};
