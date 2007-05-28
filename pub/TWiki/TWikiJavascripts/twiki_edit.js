var PREF_NAME = "Edit";
var EDITBOX_ID = "topic";
// edit box rows
var EDITBOX_PREF_ROWS_ID = "TextareaRows";
var EDITBOX_CHANGE_STEP_SIZE = 4;
var EDITBOX_MIN_ROWCOUNT = 4;
// edit box font style
var EDITBOX_PREF_FONTSTYLE_ID = "TextareaFontStyle";
var EDITBOX_FONTSTYLE_MONO = "mono";
var EDITBOX_FONTSTYLE_PROPORTIONAL = "proportional";
var EDITBOX_FONTSTYLE_MONO_STYLE = "twikiEditboxStyleMono";
var EDITBOX_FONTSTYLE_PROPORTIONAL_STYLE = "twikiEditboxStyleProportional";
var textareaInited = false;

function initForm() {
	try { document.main.text.focus(); } catch (er) {}
	initTextArea();
}

/**
Sets the height of the edit box to height read from cookie.
*/
function initTextAreaHeight() {
	var pref = twiki.Pref.getPref(PREF_NAME + EDITBOX_PREF_ROWS_ID);
	if (!pref) return;
	setEditBoxHeight( parseInt(pref) );
}

/**
Also called from template.
*/
function initTextArea () {
	if (textareaInited) return;
	initTextAreaHeight();
	initTextAreaFontStyle();
	textareaInited = true;
}

/**
Sets the font style (monospace or proportional space) of the edit box to style read from cookie.
*/
function initTextAreaFontStyle() {
	var pref  = twiki.Pref.getPref(PREF_NAME + EDITBOX_PREF_FONTSTYLE_ID);
	if (!pref) return;
	setEditBoxFontStyle( pref );
}

/**
Disables the use of ESCAPE in the edit box, because some browsers will interpret this as cancel and will remove all changes.
*/
function handleKeyDown(e) {
	if (!e) e = window.event;
	var code;
	if (e.keyCode) code = e.keyCode;
	if (code==27) return false;
	return true;
}

/**
Changes the height of the editbox textarea.
param inDirection : -1 (decrease) or 1 (increase).
If the new height is smaller than EDITBOX_MIN_ROWCOUNT the height will become EDITBOX_MIN_ROWCOUNT.
Each change is written to a cookie.
*/
function changeEditBox(inDirection) {
	var rowCount = document.getElementById(EDITBOX_ID).rows;
	rowCount += (inDirection * EDITBOX_CHANGE_STEP_SIZE);
	rowCount = (rowCount < EDITBOX_MIN_ROWCOUNT) ? EDITBOX_MIN_ROWCOUNT : rowCount;
	setEditBoxHeight(rowCount);
	twiki.Pref.setPref(PREF_NAME + EDITBOX_PREF_ROWS_ID, rowCount);
	return false;
}

/**
Sets the height of the exit box text area.
param inRowCount: the number of rows
*/
function setEditBoxHeight(inRowCount) {
	document.getElementById(EDITBOX_ID).rows = inRowCount;
}

/**
Sets the font style of the edit box and the signature box. The change is written to a cookie.
param inFontStyle: either EDITBOX_FONTSTYLE_MONO or EDITBOX_FONTSTYLE_PROPORTIONAL
*/
function setEditBoxFontStyle(inFontStyle) {
	if (inFontStyle == EDITBOX_FONTSTYLE_MONO) {
		twiki.CSS.replaceClass(document.getElementById(EDITBOX_ID), EDITBOX_FONTSTYLE_PROPORTIONAL_STYLE, EDITBOX_FONTSTYLE_MONO_STYLE);
		twiki.Pref.setPref(PREF_NAME + EDITBOX_PREF_FONTSTYLE_ID, inFontStyle);
		return;
	}
	if (inFontStyle == EDITBOX_FONTSTYLE_PROPORTIONAL) {
		twiki.CSS.replaceClass(document.getElementById(EDITBOX_ID), EDITBOX_FONTSTYLE_MONO_STYLE, EDITBOX_FONTSTYLE_PROPORTIONAL_STYLE);
		twiki.Pref.setPref(PREF_NAME + EDITBOX_PREF_FONTSTYLE_ID, inFontStyle);
		return;
	}
}