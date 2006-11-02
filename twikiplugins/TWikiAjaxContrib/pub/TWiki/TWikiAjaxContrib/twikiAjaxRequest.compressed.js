TWiki.AjaxRequest=function(){
this._load=function(_1,_2){
var _3=this._storeResponseProperties(_1,_2);
this._stop(_1);
if(_3.store){
return this._writeHtml(_3.container,_3.store);
}
if(_3.scope==undefined){
alert("TWiki.AjaxRequest._load: no scope given for function "+_3.handler);
return;
}
var _4=null;
if(_3.indicator!=null){
_4=_3.indicator;
}
if(_4==null){
_4=this._defaultIndicatorHtml;
}
var _5=_wrapIndicator(_1,_4);
TWikiAjaxContrib.HTML.updateElementWithId(_3.container,_5);
var _6=(_3.cache!=undefined)?_3.cache:false;
var _7={success:this._handleSuccess,failure:this._handleFailure,argument:{container:_3.container,cache:_3.cache}};
var _8=(_3.method!=undefined)?_3.method:"GET";
var _9=(_3.postData!=undefined)?_3.postData:"";
var _a=YAHOO.util.Connect.asyncRequest(_8,_3.url,_7,_9);
this._storeResponseProperties(_1,{response:_a});
return _a;
};
this._storeResponseProperties=function(_b,_c){
var _d=_storage[_b];
if(!_d){
_d=new Properties(_b);
}
if(!_c){
_storage[_b]=_d;
return _d;
}
_storeProperty(_d,"url",_c.url);
_storeProperty(_d,"response",_c.response);
_storeProperty(_d,"handler",_c.handler);
_storeProperty(_d,"scope",_c.scope);
_storeProperty(_d,"container",_c.container);
_storeProperty(_d,"type",_c.type);
_storeProperty(_d,"cache",_c.cache);
_storeProperty(_d,"method",_c.method);
_storeProperty(_d,"postData",_c.postData);
_storeProperty(_d,"indicator",_c.indicator);
_storeProperty(_d,"failHandler",_c.failHandler);
_storeProperty(_d,"failScope",_c.failScope);
_storage[_b]=_d;
return _d;
};
this._lockProperties=function(_e,_f){
if(!_f||_f.length==0){
return;
}
var ref=_storage[_e];
if(!ref){
return;
}
var i,ilen=_f.length;
for(i=0;i<ilen;i++){
var _12=_f[i];
ref.lockedProperties[_12]=true;
}
};
this._releaseProperties=function(_13,_14){
if(!_14||_14.length==0){
return;
}
var ref=_storage[_13];
if(!ref){
return;
}
var i,ilen=_14.length;
for(i=0;i<ilen;i++){
var _17=_14[i];
delete ref.lockedProperties[_17];
}
};
this._stop=function(_18){
var ref=_storage[_18];
_hideLoadingIndicator(_18);
if(ref&&ref.response){
YAHOO.util.Connect.abort(ref.response);
}
};
this._handleSuccess=function(_1a){
if(_1a.responseText!==undefined){
var ref=_referenceForResponse(_1a);
_hideLoadingIndicator(ref.name);
var _1c=(ref.isXml())?_1a.responseXML:_1a.responseText;
var _1d=ref.scope[ref.handler].apply(ref.scope,[_1a.argument.container,_1c]);
var _1e=false;
if(TWiki.AjaxRequest.cache==true){
_1e=true;
}
if(_1a.argument.cache==true){
_1e=true;
}
if(_1a.argument.cache==false){
_1e=false;
}
if(_1e){
self._storeHtml(ref.name,_1d);
}
}
};
this._handleFailure=function(_1f){
var ref=_referenceForResponse(_1f);
ref.owner._stop(ref.name);
var _21=ref.failScope[ref.failHandler].apply(ref.failScope,[ref.name,_1f.status]);
};
this._defaultFailHandler=function(_22,_23){
alert("Could not load request for "+_22+" because of (error status): "+_23);
};
this._storeHtml=function(_24,_25){
var ref=_storage[_24];
ref.store=_25;
};
this._writeHtml=function(_27,_28){
var _29=TWikiAjaxContrib.HTML.updateElementWithId(_27,_28);
return TWikiAjaxContrib.HTML.getHtmlOfElementWithId(_27);
};
this._defaultIndicatorHtml="<img src='indicator.gif' alt='' />";
this._setDefaultIndicatorHtml=function(_2a){
if(!_2a){
return;
}
this._defaultIndicatorHtml=_2a;
};
var _2b=this;
var _2c={};
var _2d=function(_2e){
this.name=_2e;
this.url;
this.response;
this.lockedProperties={};
this.handler="_writeHtml";
this.scope=TWiki.AjaxRequest.getInstance();
this.container;
this.type="txt";
this.cache=false;
this.method="GET";
this.postData;
this.indicator;
this.failHandler="_defaultFailHandler";
this.failScope=TWiki.AjaxRequest.getInstance();
this.owner=TWiki.AjaxRequest.getInstance();
};
_2d.prototype.isXml=function(){
return this.type=="xml";
};
_2d.prototype.toString=function(){
return "name="+this.name+"; handler="+this.handler+"; scope="+this.scope.toString()+"; container="+this.container+"; url="+this.url+"; type="+this.type+"; cache="+this.cache+"; method="+this.method+"; postData="+this.postData+"; indicator="+this.indicator+"; response="+this.response;
};
function _getIndicatorId(_2f){
return "twikiRequestIndicator"+_2f;
}
function _wrapIndicator(_30,_31){
return "<div style=\"display:inline;\" id=\""+_getIndicatorId(_30)+"\">"+_31+"</div>";
}
function _hideLoadingIndicator(_32){
TWikiAjaxContrib.HTML.clearElementWithId(_getIndicatorId(_32));
}
function _storeProperty(_33,_34,_35){
if(_35==undefined){
return;
}
if(_33.lockedProperties[_34]){
return;
}
_33[_34]=_35;
}
function _referenceForResponse(_36){
for(var i in _2c){
var _38=_2c[i].response;
if(_38&&_38.tId==_36.tId){
return _2c[i];
}
}
return null;
}
};
TWiki.AjaxRequest.__instance__=null;
TWiki.AjaxRequest.getInstance=function(){
if(this.__instance__==null){
this.__instance__=new TWiki.AjaxRequest();
}
return this.__instance__;
};
TWiki.AjaxRequest.setProperties=function(_39,_3a){
TWiki.AjaxRequest.getInstance()._storeResponseProperties(_39,_3a);
};
TWiki.AjaxRequest.lockProperties=function(_3b){
var _3c=TWikiAjaxContrib.Array.convertArgumentsToArray(arguments,1);
if(!_3c){
return;
}
TWiki.AjaxRequest.getInstance()._lockProperties(_3b,_3c);
};
TWiki.AjaxRequest.releaseProperties=function(_3d,_3e){
var _3f=TWikiAjaxContrib.Array.convertArgumentsToArray(arguments,1);
if(!_3f){
return;
}
TWiki.AjaxRequest.getInstance()._releaseProperties(_3d,_3f);
};
TWiki.AjaxRequest.clearCache=function(_40){
TWiki.AjaxRequest.getInstance()._storeHtml(_40,null);
};
TWiki.AjaxRequest.load=function(_41,_42){
return TWiki.AjaxRequest.getInstance()._load(_41,_42);
};
TWiki.AjaxRequest.stop=function(_43){
TWiki.AjaxRequest.getInstance()._stop();
};
TWiki.AjaxRequest.getDefaultIndicatorHtml=function(){
return TWiki.AjaxRequest.getInstance()._defaultIndicatorHtml;
};
TWiki.AjaxRequest.setDefaultIndicatorHtml=function(_44){
return TWiki.AjaxRequest.getInstance()._setDefaultIndicatorHtml(_44);
};
TWiki.AjaxRequest.cache=false;
TWikiAjaxContrib={};
TWikiAjaxContrib.HTML={updateElementWithId:function(_45,_46){
var _47=document.getElementById(_45);
if(_47){
return TWikiAjaxContrib.HTML.updateElement(_47,_46);
}
},updateElement:function(_48,_49){
if(_48){
if(_49==""){
TWikiAjaxContrib.HTML.clearElement(_48);
}else{
_48.innerHTML=_49;
}
return _48;
}
},getHtmlOfElementWithId:function(_4a){
var _4b=document.getElementById(_4a);
if(_4b){
return _4b.innerHTML;
}
},getHtmlOfElement:function(_4c){
if(_4c){
return _4c.innerHTML;
}
},clearElementWithId:function(_4d){
var _4e=document.getElementById(_4d);
if(_4e){
return TWikiAjaxContrib.HTML.clearElement(_4e);
}
},clearElement:function(_4f){
if(_4f){
while(_4f.hasChildNodes()){
_4f.removeChild(_4f.firstChild);
}
return _4f;
}
},setNodeStylesInList:function(_50,_51){
if(!_50){
return;
}
var i,ilen=_50.length;
for(i=0;i<ilen;++i){
var _53=_50[i];
for(var _54 in _51){
_53.style[_54]=_51[_54];
}
}
}};
TWikiAjaxContrib.Array={convertArgumentsToArray:function(_55,_56){
var _57=(_56!=undefined)?_56:0;
var _58=[];
var _59=_55.length;
for(var i=_57;i<_59;i++){
_58.push(_55[i]);
}
return _58;
}};
TWikiAjaxContrib.Form={formData2QueryString:function(_5b,_5c){
var _5d=_5c||{};
var str="";
var _5f;
var _60="";
for(i=0;i<_5b.elements.length;i++){
_5f=_5b.elements[i];
switch(_5f.type){
case "text":
case "hidden":
case "password":
case "textarea":
case "select-one":
str+=_5f.name+"="+encodeURI(_5f.value)+"&";
break;
case "select-multiple":
var _61=false;
for(var j=0;j<_5f.options.length;j++){
var _63=_5f.options[j];
if(_63.selected){
if(_5d.collapseMulti){
if(_61){
str+=","+encodeURI(_63.value);
}else{
str+=_5f.name+"="+encodeURI(_63.value);
_61=true;
}
}else{
str+=_5f.name+"="+encodeURI(_63.value)+"&";
}
}
}
if(_5d.collapseMulti){
str+="&";
}
break;
case "radio":
if(_5f.checked){
str+=_5f.name+"="+encodeURI(_5f.value)+"&";
}
break;
case "checkbox":
if(_5f.checked){
if(_5d.collapseMulti&&(_5f.name==_60)){
if(str.lastIndexOf("&")==str.length-1){
str=str.substr(0,str.length-1);
}
str+=","+encodeURI(_5f.value);
}else{
str+=_5f.name+"="+encodeURI(_5f.value);
}
str+="&";
_60=_5f.name;
}
break;
}
}
str=str.substr(0,str.length-1);
return str;
}};

