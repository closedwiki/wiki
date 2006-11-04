/*
To compress this file you can use Dojo ShrinkSafe compressor at
http://alex.dojotoolkit.org/shrinksafe/
*/

var twiki;
if (twiki == undefined) twiki = {};

/**
twiki.AjaxRequest is a wrapper class around Yahoo's Connection Manager connection.js class: http://developer.yahoo.com/yui/connection/
*/

twiki.AjaxRequest = function () {
	
	// PRIVATE METHODS AND VARIABLES
	// MAY BE CALLED ONLY BY PRIVILEGED METHODS
	
	var self = this;

	/**
	Key-value set of Properties objects. The value is accessed by request identifier name.
	@private
	*/
	var _storage = {};
	
	/**
	Inner property data class.
	*/
	var Properties = function(inName) {
		this.name = inName; // String
		this.url; // String
		this.response; //  Object
		this.lockedProperties = {}; // Value object of properties that cannot be changed
		this.handler = "_writeHtml"; // String
		this.scope = twiki.AjaxRequest.getInstance(); // Object
		this.container; // String; id of HTML container
		this.type = "txt"; // String; possible values: "txt", "xml"
		this.cache = false; // Boolean
		this.method = "GET"; // String
		this.postData; // String
		this.indicator; // HTML String
		this.failHandler = "_defaultFailHandler"; // String
		this.failScope = twiki.AjaxRequest.getInstance(); // Object
		//
		this.owner = twiki.AjaxRequest.getInstance(); // Object
	}
	Properties.prototype.isXml = function() {
		return this.type == "xml";
	}
	/**
	Debug string
	*/
	Properties.prototype.toString = function() {
		return "name=" + this.name
			+ "; handler=" + this.handler
			+ "; scope=" + this.scope.toString()
			+ "; container=" + this.container
			+ "; url=" + this.url
			+ "; type=" + this.type
			+ "; cache=" + this.cache
			+ "; method=" + this.method
			+ "; postData=" + this.postData
			+ "; indicator=" + this.indicator
			+ "; response=" + this.response;
	}
	
	/**
	Creates a unique id for the loading indicator.
	@private
	*/
	function _getIndicatorId (inName) {
		return "twikiRequestIndicator" + inName;
	}
	
	/**
	Wraps indicator HTML inside a div with unique id, so indicator can be removed even when it is located outside of replaceable content.
	@private
	*/
	function _wrapIndicator (inName, inHtml) {
		return "<div style=\"display:inline;\" id=\""
			+ _getIndicatorId(inName)
			+ "\">"
			+ inHtml
			+ "<\/div>";
	}
	
	/**
	Hides (removes) the loading indicator image for request inName.
	@private
	*/
	function _hideLoadingIndicator (inName) {
		twikiajaxcontrib.HTML.clearElementWithId(_getIndicatorId(inName));
	}
	
	/**
	Stores a property key-value pair. If the property is locked the value is not set.
	@param inObject (Properties) : reference to Properties object
	@param inKey (String) : name of property
	@param inValue (Object) : new value of property
	@private
	*/
	function _storeProperty (inObject, inKey, inValue) {
		if (inValue == undefined) return;
		if (inObject.lockedProperties[inKey]) return;
		inObject[inKey] = inValue;
	}

	/**
	Retrieves the response reference for a given response object.
	Compares tIds.
	@private
	*/
	function _referenceForResponse (inResponse) {
		for (var i in _storage) {
			var response = _storage[i].response;
			if (response && response.tId == inResponse.tId) {
				return _storage[i];
			}
		}
		return null;
	}
	
	// PRIVILEGED METHODS
	// MAY BE INVOKED PUBLICLY AND MAY ACCESS PRIVATE ITEMS
	
	/**
	See twiki.AjaxRequest.load
	*/
	this._load = function (inName, inProperties) {
		
		var ref = this._storeResponseProperties(inName, inProperties);
		
		// always stop loading possible previous request
		this._stop(inName);
		
		// check if this data has been retrieved before and stored
		if (ref.store) {
			return this._writeHtml(ref.container, ref.store);
		}
		
		// no stored data was found, so start loading
		if (ref.scope == undefined) {
			alert("twiki.AjaxRequest._load: no scope given for function "
				+ ref.handler);
			return;
		}
		
		// get loading animation
		var indicatorHtml = null;
		if (ref.indicator != null) {
			indicatorHtml = ref.indicator;
		}
		if (indicatorHtml == null) {
			indicatorHtml = this._defaultIndicatorHtml;
		}
		
		var wrappedIndicator = _wrapIndicator(inName, indicatorHtml);
		twikiajaxcontrib.HTML.updateElementWithId(ref.container, wrappedIndicator);
		
		var cache = (ref.cache != undefined) ? ref.cache : false;
		var callback = {
			success: this._handleSuccess,
			failure: this._handleFailure,
			argument:{container:ref.container, cache:ref.cache}
		};
	
		var method = (ref.method != undefined) ? ref.method : "GET";
		var postData = (ref.postData != undefined) ? ref.postData : "";
		var connectRequest = YAHOO.util.Connect.asyncRequest(method, ref.url, callback, postData);
		this._storeResponseProperties(inName, {response:connectRequest});
		return connectRequest;
	}
	
	/**
	@param inName (String) : (required) unique identifier for the request
	@param inProperties (Object) : value object with the properties defined in inner class Properties
	@privileged
	*/
	this._storeResponseProperties = function (inName, inProperties) {
		// check if object with name already exists
		// if so, update only the param values that are not null
		var ref = _storage[inName];
		if (!ref) {
			ref = new Properties(inName);
		}
		
		if (!inProperties) {
			// nothing to store, but keep reference
			_storage[inName] = ref;
			return ref;
		}

		_storeProperty(ref, "url", inProperties.url);
		_storeProperty(ref, "response", inProperties.response);
		_storeProperty(ref, "handler", inProperties.handler);
		_storeProperty(ref, "scope", inProperties.scope);
		_storeProperty(ref, "container", inProperties.container);
		_storeProperty(ref, "type", inProperties.type);
		_storeProperty(ref, "cache", inProperties.cache);
		_storeProperty(ref, "method", inProperties.method);
		_storeProperty(ref, "postData", inProperties.postData);
		_storeProperty(ref, "indicator", inProperties.indicator);
		_storeProperty(ref, "failHandler", inProperties.failHandler);
		_storeProperty(ref, "failScope", inProperties.failScope);
		
		_storage[inName] = ref;
		return ref;
	}
	
	/**
	See twiki.AjaxRequest.lockProperties
	*/
	this._lockProperties = function(inName, inPropertyList) {
		if (!inPropertyList || inPropertyList.length == 0) {
			return;
		}		
		var ref = _storage[inName];
		if (!ref) {
			return;
		}
		var i, ilen = inPropertyList.length;
		for (i=0; i<ilen; i++) {
			var property = inPropertyList[i];
			ref.lockedProperties[property] = true;
		}
	}
	
	/**
	See twiki.AjaxRequest.releaseProperties
	*/
	this._releaseProperties = function(inName, inPropertyList) {
		if (!inPropertyList || inPropertyList.length == 0) {
			return;
		}
		var ref = _storage[inName];
		if (!ref) {
			return;
		}
		var i, ilen = inPropertyList.length;
		for (i=0; i<ilen; i++) {
			var property = inPropertyList[i];
			delete ref.lockedProperties[property];
		}
	}
	
	/**
	See twiki.AjaxRequest.stop
	*/
	this._stop = function (inName) {
		var ref = _storage[inName];
		_hideLoadingIndicator(inName);
		if (ref && ref.response) YAHOO.util.Connect.abort(ref.response);
	}

	/**
	@privileged
	*/
	this._handleSuccess = function(inResponse) {
		if (inResponse.responseText !== undefined) {
			var ref = _referenceForResponse(inResponse);
			_hideLoadingIndicator(ref.name);
			var text = (ref.isXml()) ? inResponse.responseXML : inResponse.responseText;
			var result = ref.scope[ref.handler].apply(ref.scope, [inResponse.argument.container, text]);
			var shouldCache = false;
			if (inResponse.argument.cache == true) shouldCache = true;
			if (inResponse.argument.cache == false) shouldCache = false;
			if (shouldCache) {
				// store response text
				self._storeHtml(ref.name, result);
			}
		}	
	}
	
	/**
	@privileged
	*/
	this._handleFailure = function(inResponse) {
		var ref = _referenceForResponse(inResponse);
		ref.owner._stop(ref.name);
		var result = ref.failScope[ref.failHandler].apply(ref.failScope, [ref.name, inResponse.status]);
	}
	
	/**
	@privileged
	*/
	this._defaultFailHandler = function(inName, inStatus) {
		alert("Could not load request for "
			+ inName
			+ " because of (error status): "
			+ inStatus);
	}
	
	/**
	Stores HTML block inHtml for request name inName so it can be retrieved at a later time (to fetch the stored HTML pass parameter cache as true).
	@param inName (String) : (required) unique identifier for the request
	@param inHtml (String) : HTML to store with this request
	@public
	*/
	this._storeHtml = function(inName, inHtml) {
		var ref = _storage[inName];
		ref.store = inHtml;
	};

	/**
	@privileged
	*/
	this._writeHtml = function(inContainer, inHtml) {
		var element = twikiajaxcontrib.HTML.updateElementWithId(inContainer, inHtml);
		return twikiajaxcontrib.HTML.getHtmlOfElementWithId(inContainer);
	};
	
	this._defaultIndicatorHtml = "<img src='indicator.gif' alt='' />"; // for local testing, as a static url makes no sense for TWiki
	
	/**
	See twiki.AjaxRequest.setDefaultIndicatorHtml
	*/
	this._setDefaultIndicatorHtml = function (inHtml) {
		if (!inHtml) return;
		this._defaultIndicatorHtml = inHtml;
	}

}

// CLASS INSTANCE

twiki.AjaxRequest.__instance__ = null; //define the static property
twiki.AjaxRequest.getInstance = function () {
	if (this.__instance__ == null) {
		this.__instance__ = new twiki.AjaxRequest();
	}
	return this.__instance__;
}

// PUBLIC STATIC MEMBERS

/**
Sets one or more properties of a request.
@param inName (String) : (required) unique identifier for the request
@param inProperties (Object) : (optional) properties to store with this request:
	handler (String) : Name of function to proces response data. Note: a handler must always be given a scope! To clear a previously defined handler, pass an empty string.
	scope (Object) : owner of handler
	container (String) : id of HTML element to load content into
	url (String) : url to fetch HTML from
	type (String) : "txt" (default) the fetched response will be returned as text; "xml": return as XML
	cache (Boolean) : if true, the fetched response text will be cached for subsequent retrieval; default false
	method (String) : either "GET" or "POST"; default "GET"
	postData (String) : data to send
	indicator (String) : loading indicator - HTML that will be displayed while retrieving data; if empty, getDefaultIndicatorHtml() is used
Required properties to load a request:
	if no handler is given (_writeHtml will be used): url, container
	if a handler is given: handler, scope, url
@public static
*/
twiki.AjaxRequest.setProperties = function(inName, inProperties) {
	twiki.AjaxRequest.getInstance()._storeResponseProperties(inName, inProperties);
}

/**
Adds properties to the list of locked properties. Locked properties cannot be changed unless they are freed using twiki.AjaxRequest.releaseProperties.
@param inName (String) : (required) unique identifier for the request
@param ... : (required) comma-separated list of properties to lock
@public static
*/
twiki.AjaxRequest.lockProperties = function(inName) {
	var properties = twiki.Array.convertArgumentsToArray(arguments, 1);
	if (!properties) return;
	twiki.AjaxRequest.getInstance()._lockProperties(inName, properties);
}

/**
Frees properties from the list of locked properties. Freed/unlocked properties can be changed.
@param inName (String) : (required) unique identifier for the request
@param ... : (required) comma-separated list of properties to release
@public static
*/
twiki.AjaxRequest.releaseProperties = function(inName, inPropertyList) {
	var properties = twiki.Array.convertArgumentsToArray(arguments, 1);
	if (!properties) return;
	twiki.AjaxRequest.getInstance()._releaseProperties(inName, properties);
}

/**
Removes the cached response text, if any.
@public static
*/
twiki.AjaxRequest.clearCache = function(inName) {
	twiki.AjaxRequest.getInstance()._storeHtml(inName, null);
}

/**
Convenience method to directly load the HTML contents of inUrl into HTML element with id inContainer.
@param inName (String) : (required) unique identifier for the request
@param inProperties (Object) : (optional) properties to store with this request:
	url (String) : (can be used instead of inUrl) url to fetch HTML from
	cache (Boolean) : if true, the fetched response text will be cached for subsequent retrieval; default false
	method (String) : either "GET" or "POST"; default "GET"
	postData (String) : data to send
	indicator (String) : loading indicator - HTML that will be displayed while retrieving data; if empty, twiki.AjaxRequest.defaultIndicatorHtml is used
@return The new connection request.
@public static
*/
twiki.AjaxRequest.load = function(inName, inProperties) {
	return twiki.AjaxRequest.getInstance()._load(inName, inProperties);
}

/**
Aborts loading of request with name inName.
@param inName (String) : (required) unique identifier for the request
@public static
*/
twiki.AjaxRequest.stop = function(inName) {
	twiki.AjaxRequest.getInstance()._stop();
}

/**
The default indicator HTML string.
@public static
*/
twiki.AjaxRequest.getDefaultIndicatorHtml = function() {
	return twiki.AjaxRequest.getInstance()._defaultIndicatorHtml;
}

/**
Sets the default indicator HTML string.
@param inHtml (String) : HTML string for the loading indicator
@public static
*/
twiki.AjaxRequest.setDefaultIndicatorHtml = function(inHtml) {
	return twiki.AjaxRequest.getInstance()._setDefaultIndicatorHtml(inHtml);
}


twikiajaxcontrib = {};

/**
twikiajaxcontrib.HTML functions will most likely be part of twikiLib.js, so this will be removed at that time. CHANGES ARE TO BE EXPECTED.
*/
twikiajaxcontrib.HTML = {

	/**
	Writes HTML inHtml in element with id inId.
	@param inId : String, element id
	@param inHtml : HTML String
	Calls writeHtmlToElement.
	*/
	updateElementWithId:function(inId, inHtml) {
		var elem = document.getElementById(inId);
		if (elem) return twikiajaxcontrib.HTML.updateElement(elem, inHtml);
	},
	
	/**
	Sets the HTML content of element inElement to inHtml.
	*/
	updateElement:function(inElement, inHtml) {
		if (inElement) {
			if (inHtml == "") {
				twikiajaxcontrib.HTML.clearElement(inElement);
			} else {
				inElement.innerHTML = inHtml;
			}
			return inElement;
		}
	},
	
	/**
	Returns the HTML contents of element with id inId.
	*/
	getHtmlOfElementWithId:function(inId) {
		var elem = document.getElementById(inId);
		if (elem) return elem.innerHTML;
	},
	
	/**
	Returns the HTML contents of element inElement.
	*/
	getHtmlOfElement:function(inElement) {
		if (inElement) return inElement.innerHTML;
	},
	
	/**
	Clears the contents of element inId.
	*/
	clearElementWithId:function(inId) {
		var elem = document.getElementById(inId);
		if (elem) return twikiajaxcontrib.HTML.clearElement(elem);
	},
	
	/**
	Clears and optionally removes an element.
	@param inElement (HTMLElement) : object to clear or remove
	*/
	clearElement:function(inElement) {
		if (inElement) {
			while(inElement.hasChildNodes()) {
				inElement.removeChild(inElement.firstChild);
			}
			return inElement;
		}
	},
	
	/**
	Passes style attributes from value object inStyleObject to all nodes in NodeList inNodeList.
	*/
	setNodeStylesInList:function (inNodeList, inStyleObject) {
		if (!inNodeList) return;
		var i, ilen = inNodeList.length;
		for (i=0; i<ilen; ++i) {
			var node = inNodeList[i];
			for (var style in inStyleObject) {
				node.style[style] = inStyleObject[style];
			}
		}
	}
	
};
