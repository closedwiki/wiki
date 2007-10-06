var WYSIWYG_secret_id='<!-- WYSIWYG content - do not remove this comment, and never use this identical text in your topics -->';var tinymce_plugin_setUpContent=function(editor_id,body,doc){var request=new Object();request.editor_id=editor_id;request.doc=doc;request.body=body;var url=location.pathname;var match=/^(.*)\/edit(\.[^\/]*)?\/([^?]*).*$/.exec(url);var suffix=match[2];if(suffix==null)suffix='';url=match[1]+"/rest"+suffix+"/WysiwygPlugin/tml2html";var path=match[3];path=path.replace(/\/+/g,'.');if(tinyMCE.isIE){request.req=new ActiveXObject("Microsoft.XMLHTTP");}else{request.req=new XMLHttpRequest();}
request.req.open("POST",url,true);request.req.setRequestHeader("Content-type","application/x-www-form-urlencoded");var editor=tinyMCE.getInstanceById(editor_id);var text=editor.oldTargetElement.value;var params="nocache="+encodeURIComponent((new Date()).getTime())
+"&topic="+encodeURIComponent(path)
+"&text="+encodeURIComponent(escape(text));request.req.setRequestHeader("Content-length",params.length);request.req.setRequestHeader("Connection","close");request.req.onreadystatechange=function(){contentReadCallback(request);};body.innerHTML="<span class='twikiAlert'>Please wait... retrieving page from server</span>";request.req.send(params);}
function contentReadCallback(request){if(request.req.readyState==4){if(request.req.status==200){request.body.innerHTML=request.req.responseText;var editor=tinyMCE.getInstanceById(request.editor_id);editor.isNotDirty=true;}else{request.body.innerHTML="<div class='twikiAlert'>"
+"There was a problem retrieving the page: "
+request.req.statusText+"</div>";}}}
var twikiSaveCallback=function(element_id,html,body){var secret_id=tinyMCE.getParam('twiki_secret_id');if(secret_id!=null&&html.indexOf('<!--'+secret_id+'-->')==-1){html='<!--'+secret_id+'-->'+html;}
return html;}
function twikiConvertLink(url,node,onSave){if(onSave==null)
onSave=false;var orig=url;var vars=tinyMCE.getParam("twiki_vars","");if(vars!=null){var sets=vars.split(',');var vbls=new Object;for(var i=0;i<sets.length;i++){var v=sets[i].split('=');vbls[v[0]]=v[1];url=url.replace('%'+v[0]+'%',v[1],'g');}
if(onSave){if(url.indexOf(vbls['VIEWSCRIPTURL']+'/')==0){url=url.substr(vbls['VIEWSCRIPTURL'].length+1);url=url.replace(/\/+/g,'.');if(url.indexOf(vbls['WEB']+'.')==0){url=url.substr(vbls['WEB'].length+1);}}}else{if(url.indexOf('/')==-1){var match=/^((?:\w+\.)*)(\w+)$/.exec(url);if(match!=null){var web=match[1];var topic=match[2];if(web==null||web.length==0){web=vbls['WEB'];}
web=web.replace(/\.+/g,'/');web=web.replace(/\/+$/,'');url=vbls['VIEWSCRIPTURL']+'/'+web+'/'+topic;}}}}
return url;}
function twikiConvertPubURL(url){var orig=url;var vars=tinyMCE.getParam("twiki_vars","");if(vars!=null){var sets=vars.split(',');var vbls=new Object;for(var i=0;i<sets.length;i++){var v=sets[i].split('=');vbls[v[0]]=v[1];url=url.replace('%'+v[0]+'%',v[1],'g');}
if(url.indexOf('/')==-1){url=vbls['PUBURL']+'/'+vbls['WEB']+'/'+
vbls['TOPIC']+'/'+url;}}
return url;}
var IFRAME_ID='mce_editor_0';function changeEditBox(inDirection){return false;}
function setEditBoxHeight(inRowCount){}
function initTextAreaStyles(){var iframe=document.getElementById(IFRAME_ID);if(iframe==null)return;var node=iframe.parentNode;var counter=0;while(node!=document){if(node.nodeName=='TABLE'){node.style.height='auto';var selectboxes=node.getElementsByTagName('SELECT');var i,ilen=selectboxes.length;for(i=0;i<ilen;++i){selectboxes[i].style.marginLeft=selectboxes[i].style.marginRight='2px';selectboxes[i].style.fontSize='94%';}
break;}
node=node.parentNode;}}
function install_TMCE(){var metatags=document.getElementsByTagName("META");for(var i=0;i<metatags.length;i++){if(metatags[i].name=='TINYMCEPLUGIN_INIT'){var tmce_init=unescape(metatags[i].content);eval("tinyMCE.init({"+tmce_init+"});");return;}}
metatags=metatags[0].parentNode.childNodes;for(var i=0;i<metatags.length;i++){if(metatags[i].name=='TINYMCEPLUGIN_INIT'){var tmce_init=unescape(metatags[i].content);eval("tinyMCE.init({"+tmce_init+"});");return;}}
alert("Unable to install TinyMCE; <META name='TINYMCEPLUGIN_INIT' is missing");}
install_TMCE();