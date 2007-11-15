var WYSIWYG_secret_id='<!-- WYSIWYG content - do not remove this comment, and never use this identical text in your topics -->';var TWiki_Vars;function getTWikiVar(name){if(TWiki_Vars==null){var sets=tinyMCE.getParam("twiki_vars","");TWiki_Vars=eval(sets);}
return TWiki_Vars[name];}
var tinymce_plugin_setUpContent=function(editor_id,body,doc){var request=new Object();request.editor_id=editor_id;request.doc=doc;request.body=body;var url=getTWikiVar("SCRIPTURL");var suffix=getTWikiVar("SCRIPTSUFFIX");if(suffix==null)suffix='';url+="/rest"+suffix+"/WysiwygPlugin/tml2html";var path=getTWikiVar("WEB")+'.'+getTWikiVar("TOPIC");if(tinyMCE.isIE){request.req=new ActiveXObject("Microsoft.XMLHTTP");}else{request.req=new XMLHttpRequest();}
request.req.open("POST",url,true);request.req.setRequestHeader("Content-type","application/x-www-form-urlencoded");var editor=tinyMCE.getInstanceById(editor_id);var text=editor.oldTargetElement.value;var params="nocache="+encodeURIComponent((new Date()).getTime())
+"&topic="+encodeURIComponent(path)
+"&text="+encodeURIComponent(escape(text));request.req.setRequestHeader("Content-length",params.length);request.req.setRequestHeader("Connection","close");request.req.onreadystatechange=function(){contentReadCallback(request);};body.innerHTML="<span class='twikiAlert'>Please wait... retrieving page from server</span>";request.req.send(params);}
function contentReadCallback(request){if(request.req.readyState==4){if(request.req.status==200){request.body.innerHTML=request.req.responseText;var editor=tinyMCE.getInstanceById(request.editor_id);editor.isNotDirty=true;}else{request.body.innerHTML="<div class='twikiAlert'>"
+"There was a problem retrieving the page: "
+request.req.statusText+"</div>";}}}
var twikiSaveCallback=function(element_id,html,body){var secret_id=tinyMCE.getParam('twiki_secret_id');if(secret_id!=null&&html.indexOf('<!--'+secret_id+'-->')==-1){html='<!--'+secret_id+'-->'+html;}
return html;}
function twikiConvertLink(url,node,onSave){if(onSave==null)
onSave=false;var orig=url;var vsu=tinyMCE.getTWikiVar("VIEWSCRIPTURL");for(var i in TWiki_Vars){url=url.replace('%'+i+'%',TWiki_Vars[i],'g');}
if(onSave){if(url.indexOf(vsu+'/')==0){url=url.substr(vsu.length+1);url=url.replace(/\/+/g,'.');if(url.indexOf(vbls['WEB']+'.')==0){url=url.substr(vbls['WEB'].length+1);}}}else{if(url.indexOf('/')==-1){var match=/^((?:\w+\.)*)(\w+)$/.exec(url);if(match!=null){var web=match[1];var topic=match[2];if(web==null||web.length==0){web=vbls['WEB'];}
web=web.replace(/\.+/g,'/');web=web.replace(/\/+$/,'');url=vsu+'/'+web+'/'+topic;}}}
return url;}
function twikiConvertPubURL(url){var orig=url;var base=getTWikiVar("PUBURL")+'/'+getTWikiVar("WEB")+'/'+
getTWikiVar("TOPIC")+'/';for(var i in TWiki_Vars){url=url.replace('%'+i+'%',TWiki_Vars[i],'g');}
if(url.indexOf('/')==-1){url=base+url;}
return url;}
var IFRAME_ID='mce_editor_0';function changeEditBox(inDirection){return false;}
function setEditBoxHeight(inRowCount){}
function initTextAreaStyles(){var iframe=document.getElementById(IFRAME_ID);if(iframe==null)return;var node=iframe.parentNode;var counter=0;while(node!=document){if(node.nodeName=='TABLE'){node.style.height='auto';var selectboxes=node.getElementsByTagName('SELECT');var i,ilen=selectboxes.length;for(i=0;i<ilen;++i){selectboxes[i].style.marginLeft=selectboxes[i].style.marginRight='2px';selectboxes[i].style.fontSize='94%';}
break;}
node=node.parentNode;}}
var metaTags;var getMetaTag=function(inKey){if(metaTags==null||metaTags.length==0){var head=document.getElementsByTagName("META");head=head[0].parentNode.childNodes;metaTags=new Array();for(var i=0;i<head.length;i++){if(head[i].tagName!=null&&head[i].tagName.toUpperCase()=='META'){metaTags[head[i].name]=head[i].content;}}}
return metaTags[inKey];};function install_TMCE(){var tmce_init=getMetaTag('TINYMCEPLUGIN_INIT');if(tmce_init!=null){eval("tinyMCE.init({"+unescape(tmce_init)+"});");return;}
alert("Unable to install TinyMCE; <META name='TINYMCEPLUGIN_INIT' is missing");}
install_TMCE();