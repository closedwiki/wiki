twiki.CSS = {

	/**
	Remove the given class from an element, if it is there.
	@param inElement : (HTMLElement) element to remove the class of
	@param inClassName : (String) CSS class name to remove
	*/
	removeClass:function(inElement, inClassName) {
		var classes = twiki.CSS.getClassList(inElement);
		if (!classes) return;
		var index = twiki.CSS._indexOf(classes, inClassName);
		if (index >= 0) {
			classes.splice(index,1);
			twiki.CSS.setClassList(inElement, classes);
		}
	},
	
	/**
	Add the given class to the element, unless it is already there.
	@param inElement : (HTMLElement) element to add the class to
	@param inClassName : (String) CSS class name to add
	*/
	addClass:function(inElement, inClassName) {
		var classes = twiki.CSS.getClassList(inElement);
		if (!classes) return;
		if (twiki.CSS._indexOf(classes, inClassName) < 0) {
			classes[classes.length] = inClassName;
			twiki.CSS.setClassList(inElement,classes);
		}
	},
	
	/**
	Replace the given class with a different class on the element.
	The new class is added even if the old class is not present.
	@param inElement : (HTMLElement) element to replace the class of
	@param inOldClass : (String) CSS class name to remove
	@param inNewClass : (String) CSS class name to add
	*/
	replaceClass:function(inElement, inOldClass, inNewClass) {
		twiki.CSS.removeClass(inElement, inOldClass);
		twiki.CSS.addClass(inElement, inNewClass);
	},
	
	/**
	Get an array of the classes on the object.
	@param inElement : (HTMLElement) element to get the class list from
	*/
	getClassList:function(inElement) {
		if (inElement.className && inElement.className != "") {
			return inElement.className.split(' ');
		}
		return [];
	},
	
	/**
	Set the classes on an element from an array of class names.
	@param inElement : (HTMLElement) element to set the class list to
	@param inClassList : (Array) list of CSS class names
	*/
	setClassList:function(inElement, inClassList) {
		inElement.className = inClassList.join(' ');
	},
	
	/**
	Determine if the element has the given class string somewhere in it's
	className attribute.
	@param inElement : (HTMLElement) element to check the class occurrence of
	*/
	hasClass:function(inElement, inClassName) {
		if (inElement.className) {
			var classes = twiki.CSS.getClassList(inElement);
			if (classes) return (twiki.CSS._indexOf(classes, inClassName) >= 0);
			return false;
		}
	},
	
	/* PRIVILIGED METHODS */
	
	/**
	See: twiki.Array.indexOf
	Function copied here to prevent extra dependency on twiki.Array.
	*/
	_indexOf:function(inArray, inElement) {
		if (!inArray || inArray.length == undefined) return null;
		var i, ilen = inArray.length;
		for (i=0; i<ilen; ++i) {
			if (inArray[i] == inElement) return i;
		}
		return -1;
	}

}