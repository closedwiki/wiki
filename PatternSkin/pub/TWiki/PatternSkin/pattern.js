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

var myrules = {
	'.twikiFormStep h3' : function(el) {
		Pattern.createTwikiActionFormStepSign(el);
	}
};
Behaviour.register(myrules);