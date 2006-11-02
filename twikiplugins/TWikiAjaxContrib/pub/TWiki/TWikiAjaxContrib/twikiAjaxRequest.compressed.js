TWiki.AjaxRequest = function () { this._load = function (inName, inProperties) { var ref = this._storeResponseProperties(inName, inProperties); this._stop(inName); if (ref.store) { return this._writeHtml(ref.container, ref.store);}
if (ref.scope == undefined) { alert("TWiki.AjaxRequest._load: no scope given for function " + ref.handler); return;}
var indicatorHtml = null; if (ref.indicator != null) { indicatorHtml = ref.indicator;}
if (indicatorHtml == null) { indicatorHtml = this._defaultIndicatorHtml;}
var wrappedIndicator = _wrapIndicator(inName, indicatorHtml); TWikiAjaxContrib.HTML.updateElementWithId(ref.container, wrappedIndicator); var cache = (ref.cache != undefined) ? ref.cache : false; var callback = { success: this._handleSuccess, failure: this._handleFailure, argument:{container:ref.container, cache:ref.cache}
}; var method = (ref.method != undefined) ? ref.method : "GET"; var postData = (ref.postData != undefined) ? ref.postData : ""; var connectRequest = YAHOO.util.Connect.asyncRequest(method, ref.url, callback, postData); this._storeResponseProperties(inName, {response:connectRequest}); return connectRequest;}
this._storeResponseProperties = function (inName, inProperties) { var ref = _storage[inName]; if (!ref) { ref = new Properties(inName);}
if (!inProperties) { _storage[inName] = ref; return ref;}
_storeProperty(ref, "url", inProperties.url); _storeProperty(ref, "response", inProperties.response); _storeProperty(ref, "handler", inProperties.handler); _storeProperty(ref, "scope", inProperties.scope); _storeProperty(ref, "container", inProperties.container); _storeProperty(ref, "type", inProperties.type); _storeProperty(ref, "cache", inProperties.cache); _storeProperty(ref, "method", inProperties.method); _storeProperty(ref, "postData", inProperties.postData); _storeProperty(ref, "indicator", inProperties.indicator); _storeProperty(ref, "failHandler", inProperties.failHandler); _storeProperty(ref, "failScope", inProperties.failScope); _storage[inName] = ref; return ref;}
this._lockProperties = function(inName, inPropertyList) { if (!inPropertyList || inPropertyList.length == 0) { return;}
var ref = _storage[inName]; if (!ref) { return;}
var i, ilen = inPropertyList.length; for (i=0; i<ilen; i++) { var property = inPropertyList[i]; ref.lockedProperties[property] = true;}
}
this._releaseProperties = function(inName, inPropertyList) { if (!inPropertyList || inPropertyList.length == 0) { return;}
var ref = _storage[inName]; if (!ref) { return;}
var i, ilen = inPropertyList.length; for (i=0; i<ilen; i++) { var property = inPropertyList[i]; delete ref.lockedProperties[property];}
}
this._stop = function (inName) { var ref = _storage[inName]; _hideLoadingIndicator(inName); if (ref && ref.response) YAHOO.util.Connect.abort(ref.response);}
this._handleSuccess = function(inResponse) { if (inResponse.responseText !== undefined) { var ref = _referenceForResponse(inResponse); _hideLoadingIndicator(ref.name); var text = (ref.isXml()) ? inResponse.responseXML : inResponse.responseText; var result = ref.scope[ref.handler].apply(ref.scope, [inResponse.argument.container, text]); var shouldCache = false; if (TWiki.AjaxRequest.cache == true) shouldCache = true; if (inResponse.argument.cache == true) shouldCache = true; if (inResponse.argument.cache == false) shouldCache = false; if (shouldCache) { self._storeHtml(ref.name, result);}
}
}
this._handleFailure = function(inResponse) { var ref = _referenceForResponse(inResponse); ref.owner._stop(ref.name); var result = ref.failScope[ref.failHandler].apply(ref.failScope, [ref.name, inResponse.status]);}
this._defaultFailHandler = function(inName, inStatus) { alert("Could not load request for " + inName + " because of (error status): " + inStatus);}
this._storeHtml = function(inName, inHtml) { var ref = _storage[inName]; ref.store = inHtml;}; this._writeHtml = function(inContainer, inHtml) { var element = TWikiAjaxContrib.HTML.updateElementWithId(inContainer, inHtml); return TWikiAjaxContrib.HTML.getHtmlOfElementWithId(inContainer);}; this._defaultIndicatorHtml = "<img src='indicator.gif' alt='' />"; this._setDefaultIndicatorHtml = function (inSrc) { if (!inSrc) return; this._defaultIndicatorHtml = inSrc;}
var self = this; var _storage = {}; var Properties = function(inName) { this.name = inName; this.url; this.response; this.lockedProperties = {}; this.handler = "_writeHtml"; this.scope = TWiki.AjaxRequest.getInstance(); this.container; this.type = "txt"; this.cache = false; this.method = "GET"; this.postData; this.indicator; this.failHandler = "_defaultFailHandler"; this.failScope = TWiki.AjaxRequest.getInstance(); this.owner = TWiki.AjaxRequest.getInstance();}
Properties.prototype.isXml = function() { return this.type == "xml";}
Properties.prototype.toString = function() { return "name=" + this.name + "; handler=" + this.handler + "; scope=" + this.scope.toString() + "; container=" + this.container + "; url=" + this.url + "; type=" + this.type + "; cache=" + this.cache + "; method=" + this.method + "; postData=" + this.postData + "; indicator=" + this.indicator + "; response=" + this.response;}
function _getIndicatorId (inName) { return "twikiRequestIndicator" + inName;}
function _wrapIndicator (inName, inHtml) { return "<div style=\"display:inline;\" id=\"" + _getIndicatorId(inName) + "\">" + inHtml + "<\/div>";}
function _hideLoadingIndicator (inName) { TWikiAjaxContrib.HTML.clearElementWithId(_getIndicatorId(inName));}
function _storeProperty (inObject, inKey, inValue) { if (inValue == undefined) return; if (inObject.lockedProperties[inKey]) return; inObject[inKey] = inValue;}
function _referenceForResponse (inResponse) { for (var i in _storage) { var response = _storage[i].response; if (response && response.tId == inResponse.tId) { return _storage[i];}
}
return null;}
}
TWiki.AjaxRequest.__instance__ = null; TWiki.AjaxRequest.getInstance = function () { if (this.__instance__ == null) { this.__instance__ = new TWiki.AjaxRequest();}
return this.__instance__;}
TWiki.AjaxRequest.setProperties = function(inName, inProperties) { TWiki.AjaxRequest.getInstance()._storeResponseProperties(inName, inProperties);}
TWiki.AjaxRequest.lockProperties = function(inName) { var properties = TWikiAjaxContrib.Array.convertArgumentsToArray(arguments, 1); if (!properties) return; TWiki.AjaxRequest.getInstance()._lockProperties(inName, properties);}
TWiki.AjaxRequest.releaseProperties = function(inName, inPropertyList) { var properties = TWikiAjaxContrib.Array.convertArgumentsToArray(arguments, 1); if (!properties) return; TWiki.AjaxRequest.getInstance()._releaseProperties(inName, properties);}
TWiki.AjaxRequest.clearCache = function(inName) { TWiki.AjaxRequest.getInstance()._storeHtml(inName, null);}
TWiki.AjaxRequest.load = function(inName, inProperties) { return TWiki.AjaxRequest.getInstance()._load(inName, inProperties);}
TWiki.AjaxRequest.stop = function(inName) { TWiki.AjaxRequest.getInstance()._stop();}
TWiki.AjaxRequest.getDefaultIndicatorHtml = function() { return TWiki.AjaxRequest.getInstance()._defaultIndicatorHtml;}
TWiki.AjaxRequest.setDefaultIndicatorHtml = function(inSrc) { return TWiki.AjaxRequest.getInstance()._setDefaultIndicatorHtml(inSrc);}
TWiki.AjaxRequest.cache = false; TWikiAjaxContrib = {}; TWikiAjaxContrib.HTML = { updateElementWithId:function(inId, inHtml) { var elem = document.getElementById(inId); if (elem) return TWikiAjaxContrib.HTML.updateElement(elem, inHtml);}, updateElement:function(inElement, inHtml) { if (inElement) { if (inHtml == "") { TWikiAjaxContrib.HTML.clearElement(inElement);} else { inElement.innerHTML = inHtml;}
return inElement;}
}, getHtmlOfElementWithId:function(inId) { var elem = document.getElementById(inId); if (elem) return elem.innerHTML;}, getHtmlOfElement:function(inElement) { if (inElement) return inElement.innerHTML;}, clearElementWithId:function(inId) { var elem = document.getElementById(inId); if (elem) return TWikiAjaxContrib.HTML.clearElement(elem);}, clearElement:function(inElement) { if (inElement) { while(inElement.hasChildNodes()) { inElement.removeChild(inElement.firstChild);}
return inElement;}
}, setNodeStylesInList:function (inNodeList, inStyleObject) { if (!inNodeList) return; var i, ilen = inNodeList.length; for (i=0; i<ilen; ++i) { var node = inNodeList[i]; for (var style in inStyleObject) { node.style[style] = inStyleObject[style];}
}
}
}; TWikiAjaxContrib.Array = { convertArgumentsToArray:function (inArguments, inStartIndex) { var start = (inStartIndex != undefined) ? inStartIndex : 0; var list = []; var ilen = inArguments.length; for (var i = start; i < ilen; i++) { list.push(inArguments[i]);}
return list;}
}
TWikiAjaxContrib.Form = { formData2QueryString:function (inForm, inFormatOptions) { var opts = inFormatOptions || {}; var str = ''; var formElem; var lastElemName = ''; for (i = 0; i < inForm.elements.length; i++) { formElem = inForm.elements[i]; switch (formElem.type) { case 'text':
case 'hidden':
case 'password':
case 'textarea':
case 'select-one':
str += formElem.name + '=' + encodeURI(formElem.value) + '&'
break; case 'select-multiple':
var isSet = false; for(var j = 0; j < formElem.options.length; j++) { var currOpt = formElem.options[j]; if(currOpt.selected) { if (opts.collapseMulti) { if (isSet) { str += ',' + encodeURI(currOpt.value);}
else { str += formElem.name + '=' + encodeURI(currOpt.value); isSet = true;}
}
else { str += formElem.name + '=' + encodeURI(currOpt.value) + '&';}
}
}
if (opts.collapseMulti) { str += '&';}
break; case 'radio':
if (formElem.checked) { str += formElem.name + '=' + encodeURI(formElem.value) + '&'
}
break; case 'checkbox':
if (formElem.checked) { if (opts.collapseMulti && (formElem.name == lastElemName)) { if (str.lastIndexOf('&') == str.length-1) { str = str.substr(0, str.length - 1);}
str += ',' + encodeURI(formElem.value);}
else { str += formElem.name + '=' + encodeURI(formElem.value);}
str += '&'; lastElemName = formElem.name;}
break;}
}
str = str.substr(0, str.length - 1); return str;}
}
