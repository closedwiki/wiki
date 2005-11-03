
/**
clears default form field value
*/
function clearDefaultandCSS(el) {
	if (el.defaultValue==el.value) el.value = "";
	// If Dynamic Style is supported, clear the style
	removeClass(el, "patternFormFieldDefaultColor"); /* removeClass is included in TwistyContrib/twist.js */
}
function setDefaultText(el, text) {
	el.value = el.text;
}
