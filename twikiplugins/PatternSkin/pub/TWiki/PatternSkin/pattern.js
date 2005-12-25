
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
/**
Draws a string with the number of attachments after the toggle link 'attachmentsshowlink'.
*/
function renderAttachmentCount (inTableId) {
	var table = document.getElementById(inTableId);
	var count = 0;
	if (table) {
		count = table.getElementsByTagName("tr").length - 1; /* assume that one tr is used for the header */
	}
	new Insertion.Bottom('attachmentsshowlink', " (" + count + ")" );
	new Insertion.Bottom('attachmentshidelink', " (" + count + ")" );
}