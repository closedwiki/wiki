

var Pattern = {

	EDIT_PREF_NAME:"Edit",
	EDITBOX_PREF_FONTSTYLE_ID:"TextareaFontStyle",
	EDITBOX_FONTSTYLE_MONO:"mono",
	EDITBOX_FONTSTYLE_PROPORTIONAL:"proportional",
	EDITBOX_FONTSTYLE_MONO_CLASSNAME:"patternButtonFontSelectorMonospace",
	EDITBOX_FONTSTYLE_PROPORTIONAL_CLASSNAME:"patternButtonFontSelectorProportional",

	createTwikiActionFormStepSign:function(el) {
		var sign = '&#9658;';
		var newEl = twiki.HTML.insertBeforeElement(
			el,
			'span',
			sign
		);
		newEl.className = 'twikiActionFormStepSign';
	},

	setTextAreaFontStyleState:function(el) {			
		var pref  = twiki.Pref.getPref(Pattern.EDIT_PREF_NAME + Pattern.EDITBOX_PREF_FONTSTYLE_ID);
		if (!pref) return;
		Pattern.setEditBoxFontStyle(pref);
	},
	
	setFontStyleState:function(el, inShouldUpdateEditBox, inButtonState) {			
		var pref  = twiki.Pref.getPref(Pattern.EDIT_PREF_NAME + Pattern.EDITBOX_PREF_FONTSTYLE_ID);

		if (!pref || (pref != Pattern.EDITBOX_FONTSTYLE_PROPORTIONAL && pref != Pattern.EDITBOX_FONTSTYLE_MONO)) pref = Pattern.EDITBOX_FONTSTYLE_PROPORTIONAL;
	
		// toggle
		var newPref = (pref == Pattern.EDITBOX_FONTSTYLE_PROPORTIONAL) ? Pattern.EDITBOX_FONTSTYLE_MONO : Pattern.EDITBOX_FONTSTYLE_PROPORTIONAL;
		

		
		var prefCssClassName = (pref == Pattern.EDITBOX_FONTSTYLE_MONO) ? Pattern.EDITBOX_FONTSTYLE_MONO_CLASSNAME : Pattern.EDITBOX_FONTSTYLE_PROPORTIONAL_CLASSNAME;
		
		var toggleCssClassName = (newPref == Pattern.EDITBOX_FONTSTYLE_MONO) ? Pattern.EDITBOX_FONTSTYLE_MONO_CLASSNAME : Pattern.EDITBOX_FONTSTYLE_PROPORTIONAL_CLASSNAME;		
			
		if (inButtonState && inButtonState == 'over') {
			if (twiki.CSS.hasClass(el, prefCssClassName)) twiki.CSS.removeClass(el, prefCssClassName);
			if (!twiki.CSS.hasClass(el, toggleCssClassName)) twiki.CSS.addClass(el, toggleCssClassName);
		} else if (inButtonState && inButtonState == 'out') {
			if (twiki.CSS.hasClass(el, toggleCssClassName)) twiki.CSS.removeClass(el, toggleCssClassName);
			if (!twiki.CSS.hasClass(el, prefCssClassName)) twiki.CSS.addClass(el, prefCssClassName);
		}
		
		if (inShouldUpdateEditBox) {
			Pattern.setEditBoxFontStyle(newPref);
		}
		
		return false;
	},
	
	setEditBoxFontStyle:function(inFontStyle) {
		if (inFontStyle == Pattern.EDITBOX_FONTSTYLE_MONO) {
			twiki.CSS.replaceClass(document.getElementById(EDITBOX_ID), EDITBOX_FONTSTYLE_PROPORTIONAL_STYLE, EDITBOX_FONTSTYLE_MONO_STYLE);
			twiki.Pref.setPref(PREF_NAME + Pattern.EDITBOX_PREF_FONTSTYLE_ID, inFontStyle);
			return;
		}
		if (inFontStyle == Pattern.EDITBOX_FONTSTYLE_PROPORTIONAL) {
			twiki.CSS.replaceClass(document.getElementById(EDITBOX_ID), EDITBOX_FONTSTYLE_MONO_STYLE, EDITBOX_FONTSTYLE_PROPORTIONAL_STYLE);
			twiki.Pref.setPref(PREF_NAME + Pattern.EDITBOX_PREF_FONTSTYLE_ID, inFontStyle);
			return;
		}
	}

}

var myrules = {
	'.twikiFormStep h3' : function(el) {
		Pattern.createTwikiActionFormStepSign(el);
	},
	'.patternEditPage .patternButtonFontSelector' : function(el) {
		Pattern.setFontStyleState(el, false, 'out');
		el.onclick = function(){
			return Pattern.setFontStyleState(el, true);
		}
		el.onmouseover = function() {
			return Pattern.setFontStyleState(el, false, 'over');
		}
		el.onmouseout = function() {
			return Pattern.setFontStyleState(el, false, 'out');
		}
	},
	'.patternEditPage .patternButtonEnlarge' : function(el) {
		el.onclick = function(){
			return changeEditBox(1);
		}
	},
	'.patternEditPage .patternButtonShrink' : function(el) {
		el.onclick = function(){
			return changeEditBox(-1);
		}
	}
};
Behaviour.register(myrules);