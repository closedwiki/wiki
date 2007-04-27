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
  window.onresize = null; /* disable onresize handler */
  var height = getWindowHeight();
  var offset;
  if (height) {
    offset = txtarea.offsetTop;
    height = height-offset-80;
    txtarea.style.height = height + "px";
  }
  setTimeout("establishOnResize()", 100); /* add a slight timeout not to DoS IE */
}
function establishOnResize() {
  window.onresize = fixHeightOfTheText;
}

function natEditInit() {
  if (document.main) {
    txtarea = document.main.text;
  } else {
    // some alternate form? take the first one we can find
    // var areas = document.getElementsByTagName('textarea');
    txtarea = areas[0];
  }
  fixHeightOfTheText();
  establishOnResize();

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
