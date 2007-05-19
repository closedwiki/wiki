var formPlugin;
formPlugin = {

	getFormElement:function(inFormName, inElementName) {
		return document[inFormName][inElementName];
	},
	
	/**
	
	*/
	setFocus:function(inFormName, inElementName) {
		try {
			formPlugin.getFormElement(inFormName, inElementName).focus();
		} catch (er) {}
	},
	
	/**
	clears default form field value
	*/
	clearBeforeClickText:function(el) {
		if (!el.FP_defaultValue) {
			el.FP_defaultValue = el.value;
		}
		if (el.FP_defaultValue == el.value) {
			el.value = "";
		}
		twiki.CSS.removeClass(el, "twikiInputFieldBeforeClick");
	},
	
	/**
	
	*/
	restoreBeforeClickText:function(el) {
		if (el.value == "" && el.FP_defaultValue) {
			el.value = el.FP_defaultValue;
			twiki.CSS.addClass(el, "twikiInputFieldBeforeClick");
		}
	},
	
	/**
	
	*/
	initBeforeClickText:function(el, inText) {
		el.FP_defaultValue = inText;
		if (el.value == el.FP_defaultValue) {
			twiki.CSS.addClass(el, "twikiInputFieldBeforeClick");
		}
	}
	
}