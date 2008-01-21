TWikiTiny.install();var IFRAME_ID='mce_editor_0';function changeEditBox(inDirection){return false;}
function setEditBoxHeight(inRowCount){}
function initTextAreaStyles(){var iframe=document.getElementById(IFRAME_ID);if(iframe==null)return;var node=iframe.parentNode;var counter=0;while(node!=document){if(node.nodeName=='TABLE'){node.style.height='auto';var selectboxes=node.getElementsByTagName('SELECT');var i,ilen=selectboxes.length;for(i=0;i<ilen;++i){selectboxes[i].style.marginLeft=selectboxes[i].style.marginRight='2px';selectboxes[i].style.fontSize='94%';}
break;}
node=node.parentNode;}}
function handleKeyDown(e){if(!e)e=window.event;var code;if(e.keyCode)code=e.keyCode;if(code==27)return false;return true;}