function toggleValue(fieldName, theValue, selector) {

  var values = $("input#"+fieldName).val() || '';
  values = values.split(/[, ]+/);
  var found = false;
  var newValues = new Array();
  for (var i = 0; i < values.length; i++)  {
    var value = values[i];
    if (!value) 
      continue;
    if (value == theValue) {
      found = true;
    } else {
      var re = new RegExp("^"+value+".*");
      if (!re.test(theValue)) {
        newValues.push(value);
      }
    }
  }

  if (!found) {
    newValues.push(theValue)
  }

  clsSetSelection(fieldName, selector, ""+newValues);
}

function clsSetSelection(fieldName, selector, selection) {
  clsClearSelection(fieldName, selector);
  var values = selection.split(/[, ]+/);
  for (var i = 0; i < values.length; i++) {
    $("#"+selector+" a#"+values[i]).addClass("current");
  }
  $("input#"+fieldName).val(values.sort().join(", "));
}
function clsClearSelection(fieldName, selector) {
  $("#"+selector+" input#"+fieldName).val("");
  $("#"+selector+" a").removeClass('current typed');
}

function handleTaggingKey(fieldName, selector) {
  var selector = $("#"+selector);
  $("a", selector).removeClass('typed current');
  var selection = $("input", selector).val();
  var values = selection.split(/[, ]+/);
  for (var i = 0; i < values.length; i++) {
    $("a#"+values[i],selector).addClass("current");
  }
  var last = values[values.length-1];
  if (last.match(/^ *$/)) {
    return;
  }
  var re = new RegExp("^"+last+".*");
  $("a",selector).each(function() {
    var id = $(this).attr("id");
    if(re.test(id)) {
      $(this).addClass("typed");
    }
  });
}

var prevHiliteElements = new Array();
function hiliteElements (elemNames, className) {
  setClassOfNames(prevHiliteElements,'');
  elemNames = elemNames.split(/[, ]+/);
  prevHiliteElements = elemNames;
  setClassOfNames(elemNames, className);
}

function setClassOfNames(elemNames, className) {
  if (!elemNames)
    return;
  for (var i = 0; i < elemNames.length; i++) {
    if (elemNames[i]) {
      var elems = document.getElementsByName(elemNames[i]);
      if (elems) {
        setClassOfElems(elems, className);
      }
    }
  }
}

function setClassOfElems(elems, className) {
  if (!elems)
    return;
  for (var i = 0; i < elems.length; i++) {
    elems[i].className = className;
  }
}
function pressButton(button) {
  button.blur();

  if ($(button).is("#clsNewCategoryButton")) {
    $("#clsNewTopicButton").removeClass("aquaPillSelected");
    $("#clsNewTopic:visible").hide();
    $("#clsBrowseButton").removeClass("aquaPillSelected");
    $("#clsBrowser:visible").hide();
    $("#clsNewCategoryButton").toggleClass("aquaPillSelected");
    $("#clsNewCategory").slideToggle();
  } else if ($(button).is("#clsNewTopicButton")) {
    $("#clsNewCategoryButton").removeClass("aquaPillSelected");
    $("#clsNewCategory:visible").hide();
    $("#clsBrowseButton").removeClass("aquaPillSelected");
    $("#clsBrowser:visible").hide();
    $("#clsNewTopicButton").toggleClass("aquaPillSelected");
    $("#clsNewTopic").slideToggle();
  } else {
    $("#clsNewCategoryButton").removeClass("aquaPillSelected");
    $("#clsNewCategory:visible").hide();
    $("#clsNewTopicButton").removeClass("aquaPillSelected");
    $("#clsNewTopic:visible").hide();
    $("#clsBrowseButton").toggleClass("aquaPillSelected");
    $("#clsBrowser").slideToggle();
  }
}

