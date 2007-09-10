var Pattern = {

	createTwikiActionFormStepSign:function(el) {
		var sign = '&#9658;';
		var newEl = twiki.HTML.insertBeforeElement(
			el,
			'span',
			sign
		);
		newEl.className = 'twikiActionFormStepSign';
	}
}

var patternRules = {
	'.twikiFormStep h3' : function(el) {
		Pattern.createTwikiActionFormStepSign(el);
	},
	'#jumpFormField' : function(el) {
		twiki.Form.initBeforeFocusText(el,TEXT_JUMP);
		el.onfocus = function() {
			twiki.Form.clearBeforeFocusText(this);
		}
		el.onblur = function() {
			twiki.Form.restoreBeforeFocusText(this);
		}
	},
	'#quickSearchBox' : function(el) {
		twiki.Form.initBeforeFocusText(el,TEXT_SEARCH);
		el.onfocus = function() {
			twiki.Form.clearBeforeFocusText(this);
		}
		el.onblur = function() {
			twiki.Form.restoreBeforeFocusText(this);
		}
	}
};
Behaviour.register(patternRules);
