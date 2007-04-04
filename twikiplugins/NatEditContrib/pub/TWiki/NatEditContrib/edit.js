// copied and adapted from phpBB
// copied and adapted from MediaWiki

var txtarea;

// apply tagOpen/tagClose to selection in textarea,
// use sampleText instead of selection if there is none
function natInsertTags(tagOpen, sampleText, tagClose) {
  // IE
  if (document.selection) {
    var theSelection = document.selection.createRange().text;

    if (!theSelection) {
      theSelection = sampleText;
    }

    txtarea.focus();

    if (theSelection.charAt(theSelection.length - 1) == " ") { 
      // exclude ending space char, if any
      theSelection = theSelection.substring(0, theSelection.length - 1);
      document.selection.createRange().text = tagOpen + theSelection + tagClose + " ";
    } else {
      document.selection.createRange().text = tagOpen + theSelection + tagClose;
    }

  // Mozilla
  } else if (txtarea.selectionStart || txtarea.selectionStart == '0') {
    var replaced = false;
    var startPos = txtarea.selectionStart;
    var endPos = txtarea.selectionEnd;
    var scrollTop = txtarea.scrollTop;
    var myText = (txtarea.value).substring(startPos, endPos);

    if (endPos - startPos > 0) {
      replaced = true;
    }
    if (!myText) {
      myText = sampleText;
    }
    if (myText.charAt(myText.length - 1) == " ") { 
      // exclude ending space char, if any
      subst = tagOpen + myText.substring(0, (myText.length - 1)) + tagClose + " ";
    } else {
      subst = tagOpen + myText + tagClose;
    }
    txtarea.value = 
      txtarea.value.substring(0, startPos) + subst +
      txtarea.value.substring(endPos, txtarea.value.length);

    txtarea.focus();

    //set new selection
    if (replaced) {
      var cPos = startPos + tagOpen.length + myText.length + tagClose.length;
      txtarea.selectionStart = cPos;
      txtarea.selectionEnd = cPos;
    } else {
      txtarea.selectionStart = startPos + tagOpen.length;
      txtarea.selectionEnd = startPos + tagOpen.length + myText.length;
    }
    txtarea.scrollTop = scrollTop;
  }

  if (txtarea.createTextRange) {
    txtarea.caretPos = document.selection.createRange().duplicate();
  }
}

// button functions
function natEditBoldButtonAction() {
  natInsertTags('*', 'Bold text', '*');
}
function natEditItalicButtonAction() {
  natInsertTags('_', 'Italic text', '_');
}
function natEditUnderlinedButtonAction() {
  natInsertTags('<u>', 'Underlined text', '</u>');
}
function natEditStrikeButtonAction() {
  natInsertTags('<strike>', 'Strike through text', '</strike>');
} 
function natEditSubButtonAction() {
  natInsertTags('<sub>', 'Subscript text', '</sub>');
}
function natEditSupButtonAction() {
  natInsertTags('<sup>', 'Superscript text', '</sup>');
}

function natEditLeftButtonAction() {
  natInsertTags('<div style=\'text-align:left\'>\n','Align left','\n<\/div>\n');
}
function natEditRightButtonAction() {
  natInsertTags('<div style=\'text-align:right\'>\n','Align right','\n<\/div>\n');
}
function natEditJustifyButtonAction() {
  natInsertTags('<div style=\'text-align:justify\'>\n','Justify text','\n<\/div>\n');
}
function natEditCenterButtonAction() {
  natInsertTags('<center>\n','Center text','\n<\/center>\n');
}
function natEditExtButtonAction() {
  natInsertTags('[[http://...][','link text',']]');
}
function natEditIntButtonAction() {
  natInsertTags('[[','web.topic][link text',']]');
}
function natEditHeadlineButtonAction(level) {
  if (level == 2) {
    natInsertTags('\n---++ ','Headline text','\n');
  } else if (level == 3) {
    natInsertTags('\n---+++ ','Headline text','\n');
  } else if (level == 4) {
    natInsertTags('\n---++++ ','Headline text','\n');
  } else if (level == 5) {
    natInsertTags('\n---+++++ ','Headline text','\n');
  } else if (level == 6) {
    natInsertTags('\n---++++++ ','Headline text','\n');
  } else {
    natInsertTags('\n---+ ','Headline text','\n');
  }
}
function natEditImageButtonActionStandard() {
  natInsertTags('<img class=\'border alignleft\' src=\'%ATTACHURLPATH%/','Example.jpg','\' title="Example" />');
}
function natEditImageButtonActionImagePlugin() {
  natInsertTags('%IMAGE{"','Example.jpg','|400px|Caption text|frame|center"}%');
}
function natEditMathButtonAction() {
  natInsertTags('<latex title="Example">\n','\\sum_{x=1}^{n}\frac{1}{x}','\n</latex>'); // inline
}
function natEditVerbatimButtonAction() {
  natInsertTags('<verbatim>','Insert non-formatted text here','<\/verbatim>');
}

function submitEditForm(script, action) {
  document.main.elements['action_preview'].value = '';
  document.main.elements['action_save'].value = '';
  document.main.elements['action_checkpoint'].value = '';
  document.main.elements['action_cancel'].value = '';
  document.main.elements['action_' + action].value = 'foobar';
  document.main.submit();
}

function getWindowHeight () {
  if( typeof( window.innerWidth ) == 'number' ) {
    //Non-IE
    return window.innerHeight;
  } else if( document.documentElement && ( document.documentElement.clientWidth || document.documentElement.clientHeight ) ) {
    //IE 6+ in 'standards compliant mode'
    return document.documentElement.clientHeight;
  } else if( document.body && ( document.body.clientWidth || document.body.clientHeight ) ) {
    //IE 4 compatible
    return document.body.clientHeight;
  }
  return 0; // outch
}

function getWindowWidth () {
  if( typeof( window.innerWidth ) == 'number' ) {
    //Non-IE
    return window.innerWidth;
  } else if( document.documentElement && ( document.documentElement.clientWidth || document.documentElement.clientHeight ) ) {
    //IE 6+ in 'standards compliant mode'
    return document.documentElement.clientWidth;
  } else if( document.body && ( document.body.clientWidth || document.body.clientHeight ) ) {
    //IE 4 compatible
    return document.body.clientWidth;
  }
  return 0; // outch
}

function fixHeightOfTheText() {
  var height = getWindowHeight();
  var offset;
  if (height) {
    offset = txtarea.offsetTop;
    height = height-offset-80;
    txtarea.style.height = height + "px";
  }
  return height;
}

function natEditInit() {
  if (document.main) {
    txtarea = document.main.text;
  } else {
    // some alternate form? take the first one we can find
    var areas = document.getElementsByTagName('textarea');
    txtarea = areas[0];
  }
  window.onresize = fixHeightOfTheText;
  fixHeightOfTheText();

  return true;
}

/* override twiki default one as it generates a null value error because
 * we don't have a signature box 
 */
function setEditBoxFontStyle(inFontStyle) {
  if (inFontStyle == EDITBOX_FONTSTYLE_MONO) {
    replaceClass(document.getElementById(EDITBOX_ID), EDITBOX_FONTSTYLE_PROPORTIONAL_STYLE, EDITBOX_FONTSTYLE_MONO_STYLE);
    writeCookie(COOKIE_PREFIX + EDITBOX_COOKIE_FONTSTYLE_ID, inFontStyle, COOKIE_EXPIRES);
  } else {
    replaceClass(document.getElementById(EDITBOX_ID), EDITBOX_FONTSTYLE_MONO_STYLE, EDITBOX_FONTSTYLE_PROPORTIONAL_STYLE);
    writeCookie(COOKIE_PREFIX + EDITBOX_COOKIE_FONTSTYLE_ID, inFontStyle, COOKIE_EXPIRES);
  }
}

addLoadEvent(natEditInit);
